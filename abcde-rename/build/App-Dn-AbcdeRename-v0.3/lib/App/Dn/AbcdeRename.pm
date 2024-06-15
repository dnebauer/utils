package App::Dn::AbcdeRename;

# modules    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use version; our $VERSION = qv('0.3');
use Carp qw(croak confess);
use Const::Fast;
use App::Dn::AbcdeRename::Pair;
use English;
use File::Copy;
use MooX::HandlesVia;
use MooX::Options;
use Text::Unaccent;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE               => 1;
const my $FALSE              => 0;
const my $ERR_NO_FNAME_PAIRS => 'No file name pairs';
const my $STAR               => q{*};
const my $UNDERSCORE         => q{_};                   #     }}}1

# options

# artist (-a)   {{{1
option 'artist' => (
  is            => 'ro',
  format        => 's',
  required      => $TRUE,
  short         => 'a',
  documentation => 'Artist name',
);    # }}}1

# attributes

# _name_pairs, _add_name_pair    {{{1
has '_new_names_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['App::Dn::AbcdeRename::Pair'],
  ],
  lazy        => $TRUE,
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _name_pairs    => 'elements',
    _add_name_pair => 'push',
  },
  doc => 'Old name - new name pairs',
);    #     }}}1

# methods

# main()    {{{1
#
#   does:   main method
#   params: nil
#   prints: feedback
#   return: result
sub rename ($self)
{    ## no critic (RequireInterpolationOfMetachars ProhibitBuiltinHomonyms)

  # get mp3 file names
  my @files = sort glob '*.mp3';
  if (not @files) { die "No mp3 files\n"; }

  # create new file names
  $self->_create_new_file_names([@files]);

  # display new file names
  $self->_display_file_names();

  # user can edit new names
  if ($self->input_confirm('Edit file names?')) {
    $self->_edit_file_names();
  }

  # user can abort
  if (not $self->input_confirm('Rename files?')) {
    say 'Ok' or croak;
    exit;
  }

  # rename files
  $self->_do_file_renames();

  say 'Done' or croak;

  return;
}

# _create_new_file_names($files_ref)    {{{1
#
#   does:   creates new file names
#   params: $files - array reference of file names
#   prints: warning if fail
#   return: n/a, dies on failure
sub _create_new_file_names ($self, $files_ref)
{    ## no critic (RequireInterpolationOfMetachars)

  # check files list
  if (not $files_ref)            { confess 'No files reference provided'; }
  if (ref $files_ref ne 'ARRAY') { confess 'Not an arrayref'; }
  my @files = @{$files_ref};
  if (not @files) { confess 'No files in reference'; }

  # need artist
  if (not $self->artist) { confess 'No artist found'; }
  my $artist = $self->artist;

  # get new names
  foreach my $file (@files) {
    my $new = $self->_convert_filename($artist, $file);
    if (not $new) { die "Unable to convert '$file'\n"; }
    my $pair =
        App::Dn::AbcdeRename::Pair->new(current => $file, rename => $new);
    $self->_add_name_pair($pair);
  }

  return $TRUE;
}

# _convert_filename($artist, $file)    {{{1
#
# does:   convert filename to new format
# params: $artist - artist name [required]
#         $file   - name of file to be renamed [required]
# return: scalar string
# note:   assumes all files have extension 'mp3'
# detail: converts artist and track name, then constructs:
#         'ARTIST_XX_TRACKNAME.mp3' where 'XX' is the track number
sub _convert_filename ($self, $artist, $file)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not($artist and $file)) {
    confess 'Did not get both artist and file';
  }

  my $original_file = $file;

  #say $original_file;

  # escape problematic characters
  #$file =~ s/\(/\(/gxsm;
  #$file =~ s/\)/\)/gxsm;
  #$file =~ s/\+/\+/gxsm;
  #$file =~ s/\,/\,/gxsm;

  my $ext = '.mp3';

  # extract parts of file name
  my ($number, $name) = $file =~ /\A ( \d+ ) [.] ( \p{Any}+? ) $ext \z/xsm;
  if (not($number and $name)) {
    say 'Error extracting name and number '
        . "from file name '$original_file'"
        or croak;
    if   ($name) { say "Name: $name"            or croak; }
    else         { say 'Could not extract name' or croak; }
    if   ($number) { say "Number $number"           or croak; }
    else           { say 'Could not extract number' or croak; }
    die "Aborting\n";
  }

  # build new file name
  my $converted_artist = $self->_convert_string($artist);
  if (not $converted_artist) {
    die "Unable to convert artist '$artist'\n";
  }
  my $converted_name = $self->_convert_string($name);
  if (not $converted_name) {
    die "Unable to convert track name part '$name' "
        . "of file name '$original_file'\n";
  }
  my $rename =
        $converted_artist
      . $UNDERSCORE
      . $number
      . $UNDERSCORE
      . $converted_name
      . $ext;

  return $rename;
}

# _convert_string($string)    {{{1
#
# does:   convert string to new format
# detail: converts to lower case, converts spaces and underscores
#         to dashes, and removes anything but alphanumerics and dashes
# params: $string - string to be altered [required]
# return: scalar string
# note:   why 'a-z' is used in substitution:
sub _convert_string ($self, $string)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $string) { return q{}; }
  $string = lc $string;         # to lower case
  $string =~ s/[_ ]/-/gxsmg;    # spaces and underscores to dashes
  $string =~ s/&/and/gxsmg;     # will lose ampersands, so convert

 # must use 'a-z' in next operation to strip all *fancy* characters:
 # - although use of 'a-z' in regular expression is frowned upon by PBP,
 #   replacing with '\p{Lowercase}', '\p{Lowercase_Letter}' or '[:lower:]'
 #   results in strange behaviour with input string 'Ah,_non_più!'
 # - after stripping the fancy characters the string has an invisible final
 #   character that "swallows" any character that is appended to it, and which
 #   is reported by the 'ord' function as having an ascii or unicode numeric
 #   value of 227, and which is fatal to the 'unac_string' function, causing
 #   it to report an error and return 'undef'
  $string =~ s/[^a-z\d-]//gxsmg; ## no critic (ProhibitEnumeratedClasses)
  $string =~ s/-+/-/gxsmg;       # stripping can cause multiple dash sequences
  $string = Text::Unaccent::unac_string('UTF-8', $string);
  return $string;
}

# _display_file_names()    {{{1
#
#   does:   display current file names with new names
#   params: nil
#   prints: warning if fail
#   return: n/a, dies on failure
sub _display_file_names ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # must have file name pairs
  if (not $self->_name_pairs) { confess $ERR_NO_FNAME_PAIRS; }

  # give user feedback
  my @unwrapped;
  push @unwrapped, 'Listing files with proposed new names:';
  push @unwrapped, $STAR;

  # cycle through pairs creating (unwrapped) output
  foreach my $pair ($self->_name_pairs) {
    push @unwrapped, $pair->current;
    push @unwrapped, '  --> ' . $pair->rename;
  }
  push @unwrapped, $STAR;

  # wrap output
  my @output = $self->wrap_text(
    [@unwrapped],
    hang  => 6,
    break => [ q{-}, $UNDERSCORE ],
  );

  # display wrapped output
  $self->pager([@output], 'more');

  return;
}

# _do_file_renames()    {{{1
#
#   does:   rename files
#   params: nil
#   prints: warning if fail
#   return: n/a, dies on failure
sub _do_file_renames ($self) {  ## no critic (RequireInterpolationOfMetachars)

  # must have file name pairs
  if (not $self->_name_pairs) { confess $ERR_NO_FNAME_PAIRS; }

  # cycle through pairs renaming the files
  foreach my $pair ($self->_name_pairs) {
    my $file = $pair->current;
    my $new  = $pair->rename;

    if (not($file and -e $file)) {
      warn "Invalid file '$file'\n";
      return;
    }

    if (!eval { File::Copy::mv($file, $new); 1 }) {
      warn "Failed renaming '$file' to '$new':\n";
      warn "  $EVAL_ERROR\n";
    }
  }
  return;
}

# _edit_file_names()    {{{1
#
#   does:   user can edit new file names
#   params: nil
#   prints: warning if fail
#   return: n/a, dies on failure
sub _edit_file_names ($self) {  ## no critic (RequireInterpolationOfMetachars)

  # must have file name pairs
  if (not $self->_name_pairs) { confess $ERR_NO_FNAME_PAIRS; }

  # cycle through pairs asking user for new file names
  foreach my $pair ($self->_name_pairs) {
    my $current = $pair->current;
    my $new     = $pair->rename;
    say "\nCurrent file name: $current" or croak;
    my $edit = $self->interact_ask('New file name:', $new);
    if (not $edit) { die "Cannot have empty file name\n"; }
    if ($edit eq $new) {
      say 'Not changed' or croak;
    }
    else {
      say 'Changed new file name' or croak;
      $pair->rename($edit);
    }
  }
  say q{} or croak;

  return;
}    #     }}}1

1;
__END__

=head1 NAME

App::Dn::AbcdeRename - rename abcde output files

=head1 VERSION

This documentation applies to App::Dn::AbcdeRename version 0.3.

=head1 SYNOPSIS

  App::Dn::AbcdeRename->new(artist => $artist)->rename;

=head1 DESCRIPTION

The utility C<abcde> rips cds to disc with each track output to an F<mp3> file.
The default output file naming format produces files named like:

	  01.Song_Name.mp3

App::Dn::AbcdeRename provides the C<rename> method which attempts to rename all
F<mp3> files in the current directory to:

	  artist-name_track-number_song-name.mp3

Note conversion to lowercase. All characters that are not alphanumerics, spaces
or dashes are removed.

A fatal error occurs if any F<mp3> file in the current directory is not named
according to the default C<abcde> output format.

The artist name must be provided during object instantiation.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 OPTIONS

=over

=item artist

This property holds the artist name which is used in the generation of new
file names. Scalar string. Required.

=back

=head1 SUBROUTINES/METHODS

=head2 rename()

Renames all F<mp3> files in the current directory from naming format:

	  01.Song_Name.mp3

to naming format:

	  artist-name_track-number_song-name.mp3

See L</DESCRIPTION> for further details.

=head1 DIAGNOSTICS

=head2 No mp3 files

Occurs when there are no F<mp3> files in the current directory.
Fatal error.

=head2 No artist found

Was a valid value passed to the C<artist> property at object instantiation?
Fatal error.

=head2 Could not extract name
=head2 Could not extract number
=head2 Error extracting name and number from file name 'FILE'
=head2 Unable to convert 'FILE'
=head2 Unable to convert artist 'ARTIST'
=head2 Unable to convert track name part 'NAME' of file name 'FILE'

These errors are triggered by problems converting a F<mp3> file to the format:

	  artist-name_track-number_song-name.mp3

Perhaps it was not named according to the default C<abcde> output file format?
Fatal errors.

=head2 Cannot have empty file name

This occurs when the user is editing file names and sets a file name to an
empty string.
Fatal error.

=head2 Failed renaming 'FILE' to 'FILE': ERROR"
=head2 Invalid file 'FILE'

These warnings indicate problems with the renaming operation, possibly a system
error.
Non-fatal warnings.

=head2 Did not get both artist and file
=head2 No file name pairs
=head2 No files in reference
=head2 No files reference provided
=head2 Not an arrayref

These are internal programming error messages.
If one of them occurs it indicates a logic error in the module that needs to be
fixed.
Please report the error to the module maintainer.
Fatal errors.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 DEPENDENCIES

Carp, Const::Fast, App::Dn::AbcdeRename::Pair, English, File::Copy, Moo,
MooX::HandlesVia, MooX::Options, Role::Utils::Dn, strictures, Text::Unaccent,
Types::Standard, version.

=head1 LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Copyright 2024, David Nebauer

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=cut
