package App::Dn::Mp3Rename;

# use modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean;
use autodie qw(open close);
use Const::Fast;
use Cwd;
use English;
use Log::Log4perl qw(get_logger);
use MooX::HandlesVia;
use Term::ProgressBar::Simple;
use Types::Standard;

with qw(
    App::Dn::Mp3Rename::Role
    Role::Utils::Dn
);

const my $TRUE      => 1;
const my $FALSE     => 0;
const my $MINUS_ONE => -1;    # }}}1

# attributes

# format    {{{1
has 'format' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Filename format template',
);

# _number_width    {{{1
has '_number_width' => (
  is       => 'rw',
  isa      => Types::Standard::Maybe [Types::Standard::Int],
  required => $TRUE,
  default  => sub {undef},
  doc      => 'Width of the largest track number',
);

# _disk_width    {{{1
has '_disk_width' => (
  is       => 'rw',
  isa      => Types::Standard::Maybe [Types::Standard::Int],
  required => $TRUE,
  default  => sub {undef},
  doc      => 'Width of the largest disk number',
);

# _cwd    {{{1
has '_cwd' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $TRUE,
  default  => sub {Cwd::getcwd},
  doc      => 'Current working directory',
);

# _add_audio_file, _audio_files, _audio_file_count    {{{1
has '_audio_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['Dn::MP3Rename::AudioFile'],
  ],
  required    => $TRUE,
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _add_audio_file   => 'push',
    _audio_files      => 'elements',
    _audio_file_count => 'count',
  },
  doc => 'Array of audio files',
);

# _set_filename, _filename, _has_filename, _filenames    {{{1
has '_audio_filename_hash' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Standard::Str],
  required    => $TRUE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    _set_filename => 'set',       # $key => $value
    _filename     => 'get',       # $key
    _has_filename => 'exists',    # $key
    _filenames    => 'keys',
  },
  doc => 'Hash of audio file names: new => original',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  $self->_start_logging;

  $self->_read_audio_files;

  $self->_set_number_width;    # pad width of track number

  $self->_set_disk_width;      # pad width of disk number

  $self->_set_new_filenames;

  if ($self->_confirm_renaming) { $self->_rename_files; }

  return;
}

# _abort()    {{{1
#
# does:   log error message and exit script
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _abort ($self, $msg) {    ## no critic (RequireInterpolationOfMetachars)
  my $logger = get_logger();
  $logger->logdie("$msg\n");
  return;
}

# _info()    {{{1
#
# does:   log informational message
# params: nil
# prints: feedback
# return: n/a, dies on failure
# note:   relies on Log::Log4perl being configured elsewhere
sub _info ($self, $msg)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitDuplicateLiteral)
  my $logger    = get_logger();
  my $msg_ascii = $self->_make_ascii($msg);
  $logger->info($msg_ascii);
  return;
}

# _start_logging()    {{{1
#
# does:   initialise logger
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _start_logging ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # initialise logger to screen    {{{2
  my $conf =
        "log4perl.logger = DEBUG, Screen\n"
      . "log4perl.appender.Screen = Log::Log4perl::Appender::Screen\n"
      . "log4perl.appender.Screen.layout = SimpleLayout\n" . "\n";
  Log::Log4perl->init_once(\$conf);

  return;
}

# _read_audio_files()    {{{1
#
# does:   builds internal list of audio files in current directory
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _read_audio_files ($self) { ## no critic (RequireInterpolationOfMetachars)

  # get list of files in current directory
  my @files = glob '*.mp3';
  if (not scalar @files) { $self->_abort('No *.mp3 files found'); }
  my $count = @files;
  $self->_info("Found $count audio (mp3) files");
  $self->_info('Initial processing of audio files');
  my $progress = Term::ProgressBar::Simple->new($count);

  # cycle through files
  for my $file (@files) {

    # create audiofile object
    my $audiofile = Dn::MP3Rename::AudioFile->new(filepath => $file);
    $audiofile->initialise;

    # add audiofile object to internal array
    $self->_add_audio_file($audiofile);

    $progress++;
  }
  undef $progress;    # ensure final messages displayed

  return;
}

# _set_number_width()    {{{1
#
# does:   set width of highest track number
#         - can obtain from either track count or track numbers
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _set_number_width ($self) { ## no critic (RequireInterpolationOfMetachars)

  # get track numbers from audio files
  my @numbers = map { $_->number } $self->_audio_files;

  # get track count
  push @numbers, $self->_audio_file_count;

  # get maximum value from list
  my $max_num = List::Util::max @numbers;

  # set width of maximum number
  my $width = length $max_num;
  $self->_number_width($width);

  return;
}

# _set_disk_width()    {{{1
#
# does:   set width of highest disk number
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _set_disk_width ($self) {   ## no critic (RequireInterpolationOfMetachars)

  # get disk numbers from audio files
  my @disks = map { $_->disk } $self->_audio_files;

  # get maximum value from list
  my $max_disk = List::Util::max @disks;

  # set width of maximum disk
  my $width = length $max_disk;
  if (not $width) { $width = 1; }
  $self->_disk_width($width);

  return;
}

# _set_new_filenames()    {{{1
#
# does:   create new file names and add to internal hash
# params: nil
# prints: feedback
# return: n/a, dies on failure
# note:   new names must all be unique
sub _set_new_filenames ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  $self->_info('Create new filenames');
  my @args = ($self->format, $self->_number_width, $self->_disk_width);
  for my $audio_file ($self->_audio_files) {

    # get old (existing) file name
    my $old_filepath = $audio_file->filepath->canonpath;
    my $old_filename = $self->file_name($old_filepath);

    # create new file name
    my $new_filename = $audio_file->new_filename(@args);
    if ($self->_has_filename($new_filename)) {
      my $previous_filename = $self->_filename($new_filename);
      my $msg               = 'These files both generate the new file name '
          . "$new_filename: $previous_filename, $old_filename";
      $self->_abort($msg);
    }
    $self->_set_filename($new_filename, $old_filename);
  }

  return;
}

# _confirm_renaming()    {{{1
#
# does:   display renaming details and get user confirmation to proceed
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _confirm_renaming ($self) { ## no critic (RequireInterpolationOfMetachars)

  my @new_filenames = sort $self->_filenames;

  # get maximum widths of new and old/current filenames
  my $new_width = List::Util::max map {length} @new_filenames;
  my $old_width =
      List::Util::max map { length $self->_filename($_) } @new_filenames;

  # display details of renaming operation
  $self->_info('Proposed file renaming:');
  for my $new_filename (@new_filenames) {
    my $old_filename = $self->_filename($new_filename);
    my $msg          = q{  }
        . $self->pad($old_filename, $old_width, q{ }, 'right') . ' -> '
        . $new_filename;
    $self->_info($msg);
  }

  # get confirmation to proceed
  my $msg     = 'QUERY - Proceed with renaming?';
  my $proceed = $self->interact_confirm($msg);
  if (not $proceed) { $self->_info('Okay, aborting'); }

  return $proceed;
}

# _rename_files()    {{{1
#
# does:   rename audio files
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _rename_files ($self) {    ## no critic (RequireInterpolationOfMetachars)

  my @new_filenames = sort $self->_filenames;
  my $count         = @new_filenames;
  my $progress      = Term::ProgressBar::Simple->new($count);

  for my $new_filename (@new_filenames) {
    my $old_filename = $self->_filename($new_filename);
    $self->file_move($old_filename, $new_filename);
    $progress++;
  }
  undef $progress;    # ensure final messages displayed

  $self->_info('Files renamed');

  return;
}    # }}}1

1;

__END__

=head1 NAME

App::Dn::Mp3Rename - rename mp3 files according to user formatting template

=head1 VERSION

This documentation refers to dn-mp3file-rename version 0.5.

=head1 SYNOPSIS

    my $mp3rename = App::Dn::Mp3Rename->new(format => $format);
    $mp3rename->run;

=head1 DESCRIPTION

Renames all audio mp3 files in the current directory. The names given to the
files are determined by a format template provided by the user. This template
actually determines the base name of the new file; all files automatically
retain the F<.mp3> extension.

=head2 Placeholders in the format template

The format template can contain any of the following placeholders:

=over

=item *

C<%t> = track title

=item *

C<%a> = track artist

=item *

C<%l> = album name

=item *

C<%y> = track year

=item *

C<%n> = track number

=item *

C<%d> = disk number.

=back

All placeholder values are 'simplified':

=over

=item *

converted to lower case

=item *

spaces changed to dashes

=item *

multiple dashes collapsed to single dashes

=item *

leading and trailing dashes removed

=item *

punctuations marks such as commas, semicolons, colons, apostrophes,
question marks and exclamation points removed

=item *

words like 'a', 'an' and 'the' removed from the beginning.

=back

=head2 Numeric tags

Both "number" and "disk" are positive non-zero integers. Their raw tag values
may be a simple integer indicating track number, e.g., '6', or two integers
indicating track number and total number of tracks, e.g., '6/12'. A simple
algorithm is used to extract the track number: the initial sequence of digits
in the tag is extracted.

It is a fatal error if a valid track number cannot be extracted from a file's
tags. In contrast, if a valid disk number cannot be extracted it defaults to
'1'.

=head2 User confirmation

The proposed renaming operation is shown to the user, who must give
confirmation before files are renamed.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 format

Formatting template used to create file base names. Is a string that can
contain the following placeholders: C<%t> (title), C<%a> (artist), C<%l>
(album), C<%y> (year), C<%n> (track number), and C<%d> (disk number). The
template needs to result in unique file base names for each track file. The
F<.mp3> extension does not need to be included in the format template.

Required.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. Performs file renaming as described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 No valid track number in file 'FILE'

The audio mp3 track number tag is empty or does not contain a valid track
number. A valid track number is either:

=over

=item *

a single positive non-zero integer, e.g., '6', or

=item *

two positive non-zero integers separated by a slash, e.g., '6/10'.

=back

=head2 Format is an empty string

An empty format string was provided.

=head2 No *.mp3 files found

The current directory contains no files with an F<.mp3> extension.

=head2 These files both generate the new file name FILE: FILE, FILE

The format template, when applied to two audio mp3 files, generates the same
new file name. This error can be artificially generated by using a format
template (C<-f>) with no placeholders.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Const::Fast, Cwd, English, Log::Log4perl, Moo, MooX::HandlesVia,
Term::ProgressBar::Simple, Types::Standard, namespace::clean, strictures,
version.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
