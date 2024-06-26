package App::Dn::Mp3LibAnalyse;

# modules   # {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.6');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Const::Fast;
use Cwd;    # provides $CWD
use Encode;
use English;
use Env qw($HOME);
use File::Spec;
use Log::Log4perl qw(get_logger);
use MooX::Options protect_argv => 0;
use Path::Iterator::Rule;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE     => 1;
const my $FALSE    => 0;
const my @ANALYSES => qw(missing_key_tags);
const my $DEFAULT_LOG =>
    File::Spec->catfile($HOME, 'tmp', 'dn-mp3-library-analyse.log');
const my $MAX_DEPTH           => 100;
const my $PREORDER_DEPTHFIRST => -1;    # }}}1

# options

# analysis (-a)    {{{1
option 'analysis' => (
  is      => 'ro',
  format  => 's@',
  default => sub { [] },
  short   => 'a',
  doc     => q{Analysis to perform},
);

# log_file  (-f)    {{{1
option 'log_file' => (
  is      => 'ro',
  format  => 's@',                 ## no critic (ProhibitDuplicateLiteral)
  default => sub { [] },
  short   => 'f',
  doc     => 'Path to log file',
);

# use_logger (-l)    {{{1
option 'use_logger' => (
  is    => 'ro',
  short => 'l',
  doc   => 'Log feedback (default file: ~/tmp/dn-mp3-library-analyse.log)',
);    # }}}1

# attributes

# _analysis    {{{1
has '_analysis' => (
  is      => 'ro',
  isa     => Types::Standard::Maybe [Types::Standard::Str],
  lazy    => $TRUE,
  default => sub {
    my $self     = shift;
    my @analysis = @{ $self->analysis };
    if (not @analysis) { die "No analysis specified\n"; }
    my $analysis       = $analysis[0];
    my %valid_analysis = map { $_ => 1 } @ANALYSES;
    if (exists $valid_analysis{$analysis}) { return $analysis; }
    die "Invalid analysis: $analysis\n";
  },
  doc => 'Specified analysis',
);

# _log_file    {{{1
has '_log_file' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self      = shift;
    my @log_files = @{ $self->log_file };
    return (@log_files) ? $log_files[0] : $DEFAULT_LOG;
  },
  doc => 'Log filepath to use in script',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  $self->_startup;

  const my $CWD => Cwd::getcwd;

  # set appropriate filter for specified analysis
  my $analysis = $self->_analysis;

  my $filter;
  for ($analysis) {
    /\Amissing_key_tags\Z/xsm and do {
      $filter = $self->_filter_on_missing_key_tags;
      last;
    };
    die "Invalid analysis: $analysis\n";
  }

  # analyse all subdirectories for those matching the selected filter
  my $rule = Path::Iterator::Rule->new;
  my $next =
      $rule->dir->and($filter)->iter({ depthfirst => $PREORDER_DEPTHFIRST });
  my @dirpaths;
  while (defined(my $dir = $next->())) { push @dirpaths, $dir; }

  # convert all found (absolute) directory paths into relative paths
  my @dirs = map { $self->_relativise_dirpath($CWD, $_) } @dirpaths;

  # output directories to stdout
  for (sort @dirs) { say or croak; }

  return $TRUE;

}

# _detect_missing_key_tags($fp)    {{{1
#
# does:   find out if any key id3v2 tags are missing from an mp3 file
# params: $fp - path to mp3 file to analyse
# prints: nil
# return: arrayref, dies on failure
sub _detect_missing_key_tags ($self, $fp)
{    ## no critic (RequireInterpolationOfMetachars)

  # get id3v2 tag information
  my @output;
  my $cmd    = [ 'id3v2', '-l', $fp ];
  my $result = $self->shell_command($cmd);    # croaks on failure
  push @output, $result->stdout;

  # set key tags to search for
  my %key_tags = (
    album_art => qr{\AAPIC[ ][(]Attached[ ]picture[)]:[ ]}xsm,
    album     => qr{\ATALB[ ][(]Album/Movie/Show[ ]title[)]:[ ]}xsm,
    genre     => qr{\ATCON[ ][(]Content[ ]type[)]:[ ]}xsm,
    title  => qr{\ATIT2[ ][(]Title/songname/content[ ]description[)]:[ ]}xsm,
    artist =>
        qr{\ATPE1[ ][(]Lead[ ]performer[(]s[)]/Soloist[(]s[)][)]:[ ]}xsm,
    track => qr{\ATRCK[ ][(]Track[ ]number/Position[ ]in[ ]set[)]:[ ]}xsm,
  );

  # find missing tags
  my @missing_tags;

  #while (my ($tag, $tag_re) = each %key_tags) {
  for my $tag (keys %key_tags) {
    my $tag_re   = $key_tags{$tag};
    my @re_match = grep {/$tag_re/xsm} @output;
    if (not @re_match) { push @missing_tags, $tag; }
  }

  return [@missing_tags];
}

# _filter_on_missing_key_tags()    {{{1
#
# does:   return function that filters for missing key tags
# params: nil
# prints: nil
# return: arrayref, dies on failure
sub _filter_on_missing_key_tags ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  my $filter = sub {

    # get current directory path
    # - dir path is Path::Iterator::Rule parameter 1
    my $path = $ARG[0];

    # look for mp3 files
    my $sep       = File::Spec->catfile(q{}, q{});
    my @mp3_fps   = glob "${path}${sep}*.mp3";
    my @mp3_files = map { (File::Spec->splitpath($_))[2] } @mp3_fps;

    # abort if no mp3 files
    if (not @mp3_files) { return $FALSE; }

    # look for mp3 files without key id3v2 tags
    my @missing_tags;
    for my $mp3_fp (@mp3_fps) {
      my @tags = @{ $self->_detect_missing_key_tags($mp3_fp) };
      if (@tags) {
        my $mp3_file = $self->file_name($mp3_fp);
        push @missing_tags, " - $mp3_file";
        my $tag_list = join q{, }, sort @tags;
        push @missing_tags, "   . $tag_list";
      }
    }
    if (@missing_tags) { unshift @missing_tags, q{}, "$path:"; }

    if ($self->use_logger and @missing_tags) {
      $self->_info(join "\n", @missing_tags);
    }

    # return true if any missing tags detected
    return (scalar @missing_tags > 0);

  };

  return $filter;
}

# _info()    {{{1
#
# does:   log informational message
# params: nil
# prints: feedback
# return: n/a, dies on failure
# note:   relies on Log::Log4perl being configured elsewhere
sub _info ($self, $msg) {    ## no critic (RequireInterpolationOfMetachars)
  my $logger   = get_logger();
  my $msg_utf8 = $self->_make_utf8($msg);
  $logger->info($msg_utf8);
  return $TRUE;
}

# _make_utf8($string)    {{{1
#
# does:   encode as utf8
# params: $string - scalar string to encode [required]
# prints: feedback
# return: scalar string, dies on failure
sub _make_utf8 ($self, $string)
{    ## no critic (RequireInterpolationOfMetachars)
  return Encode::encode('UTF-8', $string);
}

# _relativise_dirpath()    {{{1
#
# does:   convert all found(absolute) directory paths into relative paths
# params: $cwd     - current working directory [scalar, required]
#         $dirpath - directory path to analyse [scalar, required]
# prints: nil
# return: scalar (altered directory path)
sub _relativise_dirpath ($self, $cwd, $dirpath)
{    ## no critic (RequireInterpolationOfMetachars)
  my $sep = File::Spec->catfile(q{}, q{});
  $dirpath =~ s/\A${cwd}${sep}//xsm;
  return $dirpath;
}

# _startup()    {{{1
#
# does:   startup tasks
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _startup ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check options    {{{2
  $self->_log_file;
  $self->_analysis;

  # initialise logger    {{{2
  # - if requested by user
  # - only echo info and above to screen
  # - echo everything to file
  if ($self->use_logger) {
    my $log_fp = $self->_log_file;
    my $conf =
          "log4perl.logger = DEBUG, File\n"
        . "log4perl.appender.File = Log::Log4perl::Appender::File\n"
        . "log4perl.appender.File.filename = $log_fp\n"
        . "log4perl.appender.File.mode = write\n"
        . "log4perl.appender.File.layout = PatternLayout\n"
        . 'log4perl.appender.File.layout.ConversionPattern = %m%n';
    Log::Log4perl->init_once(\$conf);
  }    # }}}2

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Mp3LibAnalyse - analyse mp3 files recursively

=head1 VERSION

This documentation is for C<App::Dn::Mp3LibAnalyse> version 0.6.

=head1 SYNOPSIS

    use App::Dn::Mp3LibAnalyse;

    App::Dn::Mp3LibAnalyse->new_with_options->run;

=head1 DESCRIPTION

Search the current directory recursively for subdirectories that contain mp3
audio files. For each of those (sub)directories perform an analysis determined
by the C<-a> option. All subdirectories meeting the criteria of the analysis
are printed to stdout, one per line.

If the C<-l> flag is used then feedback is logged to a log file. A file path to
the log file can be specified with the C<-f> option. If no file path is
provided, the default log file path S<< F<~/tmp/dn-mp3-library-analyse.log> >>
is used. If the directory component of the log file path is not present, the
script exits with a fatal error.

The exact feedback written to the log file depends on the analysis performed.

=head2 Analysis: missing_key_tags

If this analysis is selected each (sub)directory is scanned for mp3 audio files
missing any of the following id3v2 tags: album art (APIC), album (TALB), genre
(TCON), title (TIT2), artist (TPE1), and track (TRCK). Directories meeting this
criteria are output to stdout. The feedback written to the log file is of the
form:

    /full/path/to/directory:
      - d1_01_audio-file-name.mp3
        . album_art, album, artist, genre, title, track
      - d2_11_audio-file-name.mp3
        . genre, track

=head1 OPTIONS

=head2 -a | --analyse S<< <ANALYSIS> >>

The analysis to perform on the mp3 audio files. Valid analysis types:
'missing_key_tags'. Required.

=head2 -f | --log_file S<< <LOG_FILE_PATH> >>

Path to log file. Directory part of path must exist. Optional. Default:
S<< F<~/tmp/dn-mp3-library-analyse.log> >>

=head2 -l | --use_logger

Output feedback to a log file. Optional. Default:
S<< F<~/tmp/dn-mp3-library-analyse.log> >>.

=head2 -h | --help

Display help and exit. Optional.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only public method. It analyses F<.mp3> files as described in
L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Invalid analysis: ANALYSIS

Occurs when an invalid analysis keyword is provided to the C<-a> option.

=head2 No analysis specified

Occurs when no analysis keyword is provided.

=head2 Option I<x> requires and argument

Occurs when no argument is provided to an option that requires one.

=head2 Unknown option: I<x>

Occurs when an invalid option is supplied.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, Cwd, Encode, English, Env, File::Spec, Log::Log4perl, Moo,
MooX::Options, namespace::clean, Path::Iterator::Rule, Role::Utils::Dn,
strictures, Types::Standard, version.

=head2 Executables

id3v2.

=head1 AUTHOR

David Nebauer S<< <david at nebauer dot org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david at nebauer dot org> >>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
