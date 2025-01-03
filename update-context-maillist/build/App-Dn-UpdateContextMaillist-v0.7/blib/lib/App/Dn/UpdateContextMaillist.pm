package App::Dn::UpdateContextMaillist;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.7');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Config::Tiny;
use Const::Fast;
use Dn::MboxenSplit;
use English qw(-no_match_vars);
use File::Basename;
use File::HomeDir;
use File::Spec;
use File::Temp;
use File::Touch;
use File::Util;
use IO::Interactive;
use LWP::Simple;
use MooX::HandlesVia;
use MooX::Options;
use Sys::Syslog qw(:DEFAULT);
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE  => 1;
const my $FALSE => 0;
Sys::Syslog::openlog(File::Basename::basename($PROGRAM_NAME), 'user');

# }}}1

# options

# log (-l)    {{{1
option 'log' => (
  is    => 'ro',
  short => 'l',
  doc   => 'Whether to log feedback',
);    # }}}1

# attributes

# _add_year, _years    {{{1
has '_years_list' => (
  is      => 'rw',
  isa     => Types::Standard::ArrayRef [Types::Standard::Int],
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    my $year = $self->_current_year;
    return [$year];
  },
  handles_via => 'Array',
  handles     => {
    _years    => 'elements',
    _add_year => 'push',
  },
  doc => 'Years for archives are to be processed',
);

# _conf_file    {{{1
has '_conf_file' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self      = shift;
    my $prog_name = $self->_path_file($PROGRAM_NAME);

    # config file in home directory (second-choice)
    my $home_file = ".${prog_name}rc";
    my $home_dir  = File::HomeDir->my_home;
    my $home_conf = File::Spec->catfile($home_dir, $home_file);

    # config file in ~/.config directory (preferred)
    my $config_file = "$prog_name.conf";
    my $config_dir  = File::Spec->catdir($home_dir, '.config');
    my $config_conf = File::Spec->catfile($config_dir, $config_file);

    # if already exists, return path
    for my $file ($config_conf, $home_conf) {
      if (-e $file) { return $file; }
    }

    # if doesn't exist, create file and return path
    my $conf_new;
    if   (-d $config_dir) { $conf_new = $config_conf; }
    else                  { $conf_new = $home_conf; }
    if (not File::Touch::touch($conf_new)) {
      $self->_fail("Can't create config file '$conf_new'");
    }

    return $conf_new;
  },
  doc => 'Configuration file path',
);

# _is_interactive    {{{1
has '_is_interactive' => (
  is      => 'ro',
  isa     => Types::Standard::Bool,
  default => sub { return IO::Interactive::is_interactive; },
  doc     => 'Whether session is connected to a terminal',
);

# _ntg_context_archives_url    {{{1
has '_ntg_context_archives_url' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  default => 'https://mailman.ntg.nl/pipermail/ntg-context/index.html',
  doc     => 'URL of ntg-context mailing list archive',
);

# _output_dir    {{{1
has '_output_dir' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  default => '/home/david/data/computing/text-processing/context/mail-list/',
  doc     => 'Output directory for email mbox files',
);

# _temp_dir    {{{1
has '_temp_dir' => (
  is      => 'ro',
  isa     => Types::Standard::InstanceOf ['File::Temp::Dir'],
  lazy    => $TRUE,
  default => sub { return File::Temp->newdir(); },
  doc     => 'Temporary directory for retrieved archive file',
);    # }}}1

# }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)
  $self->_handle_year_change;
  $self->_download_archives;
  $self->_write_new_email_files;
  return;
}

# _archive_url($year)    {{{1
#
# does:   get url of archive file for given year
#
# params: year - year of archive [scalar integer, required]
# prints: error if fails
# return: scalar string, url
#         dies on failure
# note:   we could use HTML::TableExtract to extract the table
#         from the archives page, walk its structure and retrieve
#         the file name of the most recent archive, relying on the
#         ntg-context archive page having a single table:
#           <table xxxxx>
#             <tr>
#               <td>Archive</td>
#               <td>View by:</td>
#               <td>Downloadable version</td>
#             </tr>
#             <tr>
#               <td>2020:</td>
#               <td>
#                 <a href="2020/thread.html">[ Thread ]</a>
#                 <a href="2020/subject.html">[ Subject ]</a>
#                 <a href="2020/author.html">[ Author ]</a>
#                 <a href="2020/date.html">[ Date ]</a>
#               </td>
#               <td><a href="2020.txt.gz">[ Gzip'd Text xxxxx KB ]</a></td>
#               <!--    ==>  ^^^^^^^^^^^  <== datum to extract -->
#             </tr>
#             <tr>
#               <td>2019:</td>
#               <td>
#                 <a href="2019/thread.html">[ Thread ]</a>
#                 <a href="2019/subject.html">[ Subject ]</a>
#                 <a href="2019/author.html">[ Author ]</a>
#                 <a href="2019/date.html">[ Date ]</a>
#               </td>
#               <td><a href="2019.txt.gz">[ Gzip'd Text xxxxx KB ]</a></td>
#             </tr>
#             ...
#             <tr>
#               <td>2002:</td>
#               <td>
#                 <a href="2002/thread.html">[ Thread ]</a>
#                 <a href="2002/subject.html">[ Subject ]</a>
#                 <a href="2002/author.html">[ Author ]</a>
#                 <a href="2002/date.html">[ Date ]</a>
#               </td>
#               <td><a href="2002.txt.gz">[ Gzip'd Text xxxxx KB ]</a></td>
#             </tr>
#           </table>
#         but instead do quick and dirty url munging by assuming the
#         file is in the same directory as the archives table, and is
#         named '<year>.txt.gz'
sub _archive_url ($self, $year)
{    ## no critic (RequireInterpolationOfMetachars)

  # get url path
  my $page = $self->_ntg_context_archives_url;
  my $path = $self->_path_dir($page);

  # construct url
  my $url  = "$path/$year.txt.gz";
  my $seen = 0;
  $url =~ s{(/+)}{$seen++?'/':$1}gexsm;    # change all but first '//' to '/'

  return $url;
}

# _config_year([$year])    {{{1
#
# does:   read or write year value in configuration file
#
# params: $year - if provided, write year value [optional]
# prints: error if fails
# return: n/a, dies on failure
sub _config_year ($self, $year = undef)
{    ## no critic (RequireInterpolationOfMetachars)

  # get current configuration
  my $conf_file = $self->_conf_file;
  my $conf      = Config::Tiny->read($conf_file);
  if (not $conf) { $self->_fail("Could not read '$conf_file'"); }

  # setter (year provided)
  # - '_' is the "root section" before the first named section
  if ($year) {
    $conf->{_}->{'year'} = $year;
    $conf->write($conf_file)
        or $self->_fail('Unable to write config year');
    return;    ## no critic (EmptyReturn)
  }

  # getter (year not provided)
  # - '_' is the "root section" before the first named section
  $year = $conf->{_}->{'year'};    ## no critic (ProhibitDuplicateLiteral)
  if (not $year) {                 # no value in conf file, so add it
    $year                = $self->_current_year;
    $conf->{_}->{'year'} = $year;    ## no critic (ProhibitDuplicateLiteral)
    $conf->write($conf_file);
  }
  return $year;
}

# _current_year()    {{{1
#
# does:   get the current year
#
# params: nil
# prints: nil
# return: scalar integer
sub _current_year ($self) {    ## no critic (RequireInterpolationOfMetachars)
  const my $LOCALTIME_YEAR_INDEX  = 5;
  const my $LOCALTIME_YEAR_ADJUST = 1900;
  return (localtime)[$LOCALTIME_YEAR_INDEX] + $LOCALTIME_YEAR_ADJUST;
}

# _dir_files($dir)    {{{1
#
# does:   get files in directory
#
# params: $dir - directory to examine [scalar string, required]
# prints: error if fails
# return: list, file names
#         exits on failure
sub _dir_files ($self, $dir) {  ## no critic (RequireInterpolationOfMetachars)

  # check params
  if (not $dir)    { $self->_fail('No directory provided'); }
  if (not -d $dir) { $self->_fail("Invalid directory '$dir'"); }

  # get list of files in directory
  return File::Util->new()->list_dir($dir, { files_only => $TRUE });
}

# _download_archives()    {{{1
#
# does:   download email archives
#
# params: nil
# prints: feedback
# return: n/a, exits on failure
sub _download_archives ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # loop through years
  my @years = $self->_years;
  for my $year (@years) {

    # get archive url
    my $url = $self->_archive_url($year);

    # get filepath of download file
    my $file = $self->_path_file($url);
    my $fp   = File::Spec->catfile($self->_temp_dir, $file);

    # download archive file to temporary directory
    say {IO::Interactive::interactive} "Downloading '$file'..." or croak;
    my $status = LWP::Simple::getstore($url, $fp);
    if (LWP::Simple::is_success($status)) {
      say {IO::Interactive::interactive} 'Retrieved OK' or croak;
    }
    else { $self->_fail("Retrieval of $url failed"); }
  }

  return;
}

# _fail($msg)    {{{1
#
# does:   exit with error message (display on stderr and logged)
# params: $msg  - message [scalar string, required]
# prints: message if not logging
# return: n/a, exits when done
sub _fail ($self, $msg) {    ## no critic (RequireInterpolationOfMetachars)

  if ($msg) {                # display message to stderr and log message
    say { IO::Interactive::interactive(*STDERR) } $msg or croak;
    $self->_log($msg, 'ERR');
  }

  exit 1;                    # error/failure
}

# _handle_year_change()    {{{1
#
# does:   deal with year changing since previous update
#
# params: nil
# prints: error if fails
# return: n/a, dies on failure
# note:   main issue is that if year has changed need to do
#         final update of previous year, as well as update
#         for current year
# note:   use year value stored in configuration file
sub _handle_year_change ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $current_year = $self->_current_year;
  my $config_year  = $self->_config_year;

  # if have moved into new year since previous update
  if ($current_year gt $config_year) {

    # add previous year to list of year archives to download
    my $last_year = $self->_current_year - 1;
    $self->_add_year($last_year);

    # update year value in config file
    $self->_config_year($current_year);
  }

  return;
}

# _log($msg, $type)    {{{1
#
# does:   log message if logging
# params: $msg  - message [scalar string, required]
#         $type - message type [scalar string]
#                 can be EMERG|ALERT|CRIT|ERR|WARNING|NOTICE|INFO|DEBUG
# prints: nil
# return: n/a, dies on failure
# note:   appends most recent system error message for message types
#         EMERG, ALERT, CRIT and ERR
sub _log ($self, $msg, $type) { ## no critic (RequireInterpolationOfMetachars)

  # only log if logging
  return if not $self->log;

  # check parameters
  return if not $type;
  my %valid_type = map { ($_ => $TRUE) }
      qw(EMERG ALERT CRIT ERR WARNING NOTICE INFO DEBUG);
  if (not $valid_type{$type}) {
    $self->_fail("Invalid type '$type'");
  }
  return if not $msg;

  # display system error message for serious message types
  my %error_type = map { ($_ => $TRUE) } qw(EMERG ALERT CRIT ERR);
  if ($error_type{$type}) { $msg .= ': %m'; }

  # log message
  Sys::Syslog::syslog($type, $msg);

  return;
}

# _mbox_paths()    {{{1
#
# does:   get paths of downloaded mailbox files
#
# params: nil
# prints: feedback
# return: list, paths
#         exits on failure
sub _mbox_paths ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # get list of files from temporary download directory
  my $temp  = $self->_temp_dir;
  my @files = $self->_dir_files($temp);
  my $count = @files;
  if ($count == 0) {
    $self->_fail("Could not find downloaded files\n");
  }

  # prepend with file transport protocol handler
  my @prepended = map { File::Spec->catfile('file:/', $temp, $_) } @files;

  return @prepended;
}

# _output_file_count()    {{{1
#
# does:   count files in output directory
#
# params: nil
# prints: feedback
# return: scalar integer
#         exits on failure
sub _output_file_count ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # get list of files from output directory
  my $dir   = $self->_output_dir;
  my $opts  = { files_only => $TRUE };
  my @files = $self->_dir_files($dir);

  # return file count
  return scalar @files;
}

# _path_dir($path)    {{{1
#
# does:   get directory part of path
#
# params: $path - file path [scalar string, required]
# prints: error on failure
# return: scalar string, directory
sub _path_dir ($self, $path)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check params
  if (not $path) {
    $self->_fail('No path provided');
  }

  return (File::Spec->splitpath($path))[1];
}

# _path_file($path)    {{{1
#
# does:   get file name part of path
#
# params: $path - file path [scalar string, required]
# prints: error on failure
# return: scalar string, file name
sub _path_file ($self, $path)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check params
  if (not $path) {
    $self->_fail('No path provided');  ## no critic (ProhibitDuplicateLiteral)
  }

  return (File::Spec->splitpath($path))[2];
}

# _write_new_email_files()    {{{1
#
# does:   write new email files to output directory
#
# params: nil
# prints: feedback
# return: n/a, exits on failure
sub _write_new_email_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # get parameters for Dn::MboxenSplit module
  my @mboxes = $self->_mbox_paths;    # downloaded mbox files
  my $dir    = $self->_output_dir;

  # count files before writing
  my $before = $self->_output_file_count;

  # write files
  my $ms = Dn::MboxenSplit->new(
    mbox_uris  => [@mboxes],
    output_dir => $dir,
  );
  my $succeed = $TRUE;
  $ms->split or $succeed = $FALSE;

  # count files after writing
  my $after = $self->_output_file_count;

  # log result
  my $written = $after - $before;
  my $msg;
  for ($written) {
    if    ($_ == 0) { $msg = 'No new message files to write'; }
    elsif ($_ == 1) { $msg = 'Wrote one new message file'; }
    elsif ($_ >= 2) { $msg = "Wrote $written new message files"; }
  }

  # module reports if no files
  if ($written > 0) {
    say {IO::Interactive::interactive} $msg or croak;
  }
  $self->_log($msg, 'INFO');

  # handle failure
  if (not $succeed) { $self->_fail('Module Dn::MboxenSplit failed'); }

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::UpdateContextMaillist - updates local copy of ntg-context mailing list

=head1 VERSION

This documentation is for C<App::Dn::UpdateContextMaillist> version 0.7.

=head1 SYNOPSIS

    use App::Dn::UpdateContextMaillist;

    App::Dn::UpdateContextMaillist->new_with_options->run;

=head1 DESCRIPTION

Download the ntg_context mailing list archive for the current year. (If
performing the first update of the year, also do a final update of the previous
year.)

Uses the C<Dn::MboxenSplit> module to extract individual emails and writes to
F<~/data/computing/text-processing/context/mail-list/> an mbox file for every
email message which is not already captured in the directory.

Displays feedback on screen unless the C<-l> option is used, in which case the
result (and any errors or warnings) are written to the system log.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Options

=head3 -l | --log

Log output rather than display on screen. Note that the Dn::MboxenSplit module
will display some screen output regardless of this option.

Flag. Optional. Default: false.

=head3 -h | --help

Display help and exit.

=head2 Properties/attributes

There are no public attributes.

=head2 Configuration files

Uses a configuration file to save the year of the most recent update. When
running the script looks in turn for the configuration files:

=over

=item *

F<~/.config/dn-update-context-maillist.conf>

=item *

F<~/.dn-update-context-maillistrc>

=back

and uses the first one it finds.

If neither configuration file exists, it will create
F<~/.config/dn-update-context-maillist.conf> if the F<~/.config> directory
exists, otherwise it creates F<~/.dn-update-context-maillistrc>.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only public method. It updates a local copy of ntg-context mailing
list as described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Can't create config file 'FILE'

Occurs when the system is unable to create the configuration file.

=head2 Invalid type 'TYPE'

Occurs when attempting to write a log message with an invalid type.
Valid types are: EMERG ALERT CRIT ERR WARNING NOTICE INFO DEBUG.

=head1 INCOMPATIBILITIES

There are no known incomptibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Config::Tiny, Const::Fast, Dn::MboxenSplit, English, File::Basename,
File::HomeDir, File::Spec, File::Temp, File::Touch, File::Util,
IO::Interactive, LWP::Simple, Moo, MooX::HandlesVia, MooX::Options,
namespace::clean, Role::Utils::Dn, strictures, Sys::Syslog, Types::Standard,
version.

=head1 AUTHOR

David Nebauer S<< <david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker
