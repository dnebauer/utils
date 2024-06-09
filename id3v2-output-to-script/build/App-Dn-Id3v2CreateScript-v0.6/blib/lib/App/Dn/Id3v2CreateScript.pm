package App::Dn::Id3v2CreateScript;

# TODO: BUGFIX: outputs empty template if no tags found, instead print
#               warning message and abort before writing output

use Moo;                 # {{{1
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.6');
use namespace::clean;    # }}}1
use App::Dn::Id3v2CreateScript::FileProperties;
use App::Dn::Id3v2CreateScript::TagProperties;
use autodie   qw(open close);
use Carp      qw(croak);
use charnames qw(:full);
use Const::Fast;
use English;
use File::Basename;
use List::SomeUtils;
use MooX::HandlesVia;
use MP3::Tag;
use Path::Tiny;
use Types::Standard;

const my $TRUE       => 1;
const my $FALSE      => 0;
const my $EXECUTABLE => oct 755;
const my $RE_TAG_MATCH => qr{\A [TCA] [\p{Upper}\p{Digit}]{3}
                                 \N{SPACE} \N{LEFT PARENTHESIS}}xsm;
const my $RE_TAG_GET => qr{\A ( [TCA] [\p{Upper}\p{Digit}]{3} )
                               \N{SPACE} \N{LEFT PARENTHESIS}}xsm;

# }}}1

# options

# id3v2_output_file    {{{1
has 'id3v2_output_file' => (
  is  => 'ro',
  isa =>
      Types::Standard::Maybe [ Types::Standard::InstanceOf ['Path::Tiny'] ],
  required => $FALSE,
  default  => undef,
  doc      => 'Input file containing id3v2 output (empty if stdin)',
);

# bash_script    {{{1
has 'bash_script' => (
  is => 'ro',
  ## no critic (ProhibitDuplicateLiteral)
  isa =>
      Types::Standard::Maybe [ Types::Standard::InstanceOf ['Path::Tiny'] ],
  ## use critic
  required => $FALSE,
  default  => undef,
  doc      => 'Bash script output file (empty if stdout)',
);

# attributes

# _file_properties, _add_file_properties    {{{1
has '_file_object_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [
      'App::Dn::Id3v2CreateScript::FileProperties'],
  ],
  lazy        => $TRUE,
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _file_properties     => 'elements',
    _add_file_properties => 'push',
  },
  doc => 'Array of objects representing files',
);

# _valid_tag, _valid_tags, _tag_properties {{{1
has '_tag_properties_hash' => (
  is  => 'ro',
  isa => Types::Standard::HashRef [
    Types::Standard::InstanceOf [
      'App::Dn::Id3v2CreateScript::TagProperties'],
  ],
  default => sub {
    my $self = shift;

    my $tags = {};

    # those tags which are *not* preferred

    # - original year (id3v2.3)
    $tags->{'TORY'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TYER',
    );

    # - original year (ID3v2.4)
    $tags->{'TDOR'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TYER',    ## no critic (ProhibitDuplicateLiteral)
    );

    # - year (ID3v2.4)
    $tags->{'TDRC'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TYER',    ## no critic (ProhibitDuplicateLiteral)
    );

    # this tag does not have a value extracted

    # - picture
    $tags->{'APIC'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'APIC',    ## no critic (ProhibitDuplicateLiteral)
    );

    # tag lines with simple pattern: 'FRAME (...): VALUE'
    my $re_simple = qr{$RE_TAG_MATCH [^:]+? : \N{SPACE} (\p{Any}+) \Z}xsm;

    # - album name (id3v2.3, id3v2.4)
    $tags->{'TALB'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TALB',       ## no critic (ProhibitDuplicateLiteral)
      value_regex     => $re_simple,
    );

    # - track title (id3v2.3, id3v2.4)
    $tags->{'TIT2'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TIT2',       ## no critic (ProhibitDuplicateLiteral)
      value_regex     => $re_simple,
    );

    # - track artist/performer (id3v2.3, id3v2.4)
    $tags->{'TPE1'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TPE1',       ## no critic (ProhibitDuplicateLiteral)
      value_regex     => $re_simple,
    );

    # - track number (id3v2.3, id3v2.4)
    $tags->{'TRCK'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TRCK',       ## no critic (ProhibitDuplicateLiteral)
      value_regex     => $re_simple,
    );

    # - album artist/performer (id3v2.3, id3v2.4)
    $tags->{'TPE2'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TPE2',       ## no critic (ProhibitDuplicateLiteral)
      value_regex     => $re_simple,
    );

    # - year (id3v2.3)
    ## no critic (ProhibitDuplicateLiteral)
    $tags->{'TYER'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TYER',
      value_regex     => $re_simple,
    );
    ## use critic

    # tag lines with complex patterns

    # - comment (id3v2.3, id3v2.4)
    my $re_comment = qr{$RE_TAG_MATCH [^:]+? : [^:]+? : \N{SPACE}
                            (\p{Any}+)\Z}xsm;
    $tags->{'COMM'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'COMM',       ## no critic (ProhibitDuplicateLiteral)
      value_regex     => $re_comment,
    );

    # - genre (id3v2.3, id3v2.4)
    my $re_genre = qr{$RE_TAG_MATCH [^:]+? : [^\N{LEFT PARENTHESIS}]+?
                          \N{LEFT PARENTHESIS} (\p{Digit}+)
                          \N{RIGHT PARENTHESIS} \Z}xsm;
    $tags->{'TCON'} = App::Dn::Id3v2CreateScript::TagProperties->new(
      common_value    => undef,
      preferred_frame => 'TCON',       ## no critic (ProhibitDuplicateLiteral)
      value_regex     => $re_genre,
    );

    return $tags;
  },
  handles_via => 'Hash',
  handles     => {
    _valid_tag      => 'exists',
    _valid_tags     => 'keys',
    _tag_properties => 'get',
  },
  doc => 'Array of objects representing file tag properties',
);    # }}}1

# methods

# run($self)    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # process input to extract tag data
  $self->_extract_input_tag_data;

  # check for common tag values
  $self->_common_tag_values;

  # output script file
  $self->_write_script;

  return;
}

# _extract_input_tag_data()    {{{1
#
# does:   process input to extract tag data
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _extract_input_tag_data ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # get input
  my @input = @{ $self->_get_input };

  # process input
  my $file_properties;
  for my $line (@input) {

    # start new file
    my $re_start_v2_tags = qr{\Aid3v2 \N{SPACE} tag \N{SPACE}
                                      info \N{SPACE} for \N{SPACE}
                                      ([^:]+) : \Z}xsm;
    if ($line =~ $re_start_v2_tags) {
      my $fp = $1;
      if (not $fp) { croak 'Unable to extract file path'; }
      if ($file_properties) {
        $self->_add_file_properties($file_properties);
        $file_properties = undef;
      }
      $file_properties = App::Dn::Id3v2CreateScript::FileProperties->new;
      $file_properties->file_path(Path::Tiny::path($fp));
    }

    # look for lines with id3v2 tags
    if (not($line =~ $RE_TAG_GET)) { next; }
    my $frame = $1;
    my $fp    = $file_properties->file_path;
    if (not $self->_valid_tag($frame)) { next; }
    my $tag = $self->_tag_properties($frame)->preferred_frame;
    for ($tag) {
      if (/\AAPIC\Z/xsm) {
        if (my $image_fp = $self->_extract_image($fp)) {
          $file_properties->set_tag(APIC => $image_fp);
        }
      }
      elsif (/\ACOMM\Z/xsm) {
        my $len_now = 0;
        ## no critic (ProhibitDuplicateLiteral)
        my $comment_now =
            ($file_properties->has_tag('COMM'))
            ? $file_properties->tag_value('COMM')
            : q{};
        if ($comment_now) { $len_now = length $comment_now; }
        my $re = $self->_tag_properties('COMM')->value_regex;
        ## use critic
        if (not $line =~ $re) {
          croak "Cannot extract COMM value from: $fp";
        }
        my $comment_new = $1;
        my $len_new     = length $comment_new;
        if ($len_new > $len_now) {
          $file_properties->set_tag(COMM => $comment_new);
        }
      }
      else {
        # must be valid tag other than APIC or COMM
        # - i.e., "simple" tags
        my $re = $self->_tag_properties($tag)->value_regex;
        if (not $line =~ $re) {
          croak "Cannot extract $tag value from: $fp";
        }
        my $value = $1;
        $file_properties->set_tag($tag => $value);
      }
    }    # for ($tag)
  }    # for my $line (@input)

  # process last file output
  if ($file_properties) {
    $self->_add_file_properties($file_properties);
  }

  return;
}

# _get_input()    {{{1
#
# does:   get input, i.e., the output from id3v2
# params: nil
# prints: feedback
# return: array reference, dies on failure
sub _get_input ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # get input source (stdin or file)
  my $source;
  my $file = $self->id3v2_output_file;
  if ($file) {
    if (-e $file) { $source = 'file'; }
    else          { croak "Cannot find file '$file'"; }
  }
  else { $source = 'stdin'; }

  # get input
  my @input;

  for ($source) {

    # file
    if (/\Afile\Z/xsm) {
      push @input, $file->lines_utf8;
    }

    # stdin
    elsif (/\Astdin\Z/xsm) {
      while (defined(my $line = <>)) { push @input, $line; }
    }

    else { croak "Invalid source '$source'"; }
  }
  chomp @input;

  return [@input];

}

# _extract_image($fp)    {{{1
#
# does:   extract image from mp3 file
# params: $fp - path to mp3 file
# prints: feedback
# return: image filepath, dies on failure
sub _extract_image ($self, $fp)
{    ## no critic (RequireInterpolationOfMetachars)

  # extract id3v2 tag data
  if (not -e $fp) { croak "Invalid mp3 file path: $fp"; }
  my $mp3 = MP3::Tag->new($fp);
  if (not $mp3) { croak "Couldn't read tags: $fp"; }
  $mp3->get_tags();
  if (not exists($mp3->{ID3v2})) {
    warn "No ID3v2 tags: $fp\n";
    return $FALSE;
  }

  # read APIC frame
  my $id3v2_tagdata = $mp3->{ID3v2};
  ## no critic (ProhibitDuplicateLiteral)
  my $info = $id3v2_tagdata->get_frame('APIC');
  ## use critic
  my $imgdata  = $info->{'_Data'};
  my $mimetype = $info->{'MIME type'};

  $mp3->close();

  if (not $imgdata) {
    warn "No artwork data found: $fp\n";
    return $FALSE;
  }

  # write image
  # - create destination path with image mimetype suffix
  my ($m1, $m2) = split /\//xsm, $mimetype;
  my ($fname, $dirs, $suffix) = File::Basename::fileparse($fp, '.mp3');
  my $dest = $dirs . "_img_$fname" . ".$m2";

  # - write image data to file
  Path::Tiny::path($dest)->spew({ binmode => ':raw' }, $imgdata)
      or croak "Cannot write '$dest': $OS_ERROR";

  return $dest;

}

# _common_tag_values()    {{{1
#
# does:   check for tag values common to all mp3 files
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _common_tag_values ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # get preferred frame values
  my @prefer = List::SomeUtils::uniq
      map { $self->_tag_properties($_)->preferred_frame }
      $self->_valid_tags();

  # cycle through possible tags looking for common values
  for my $frame (@prefer) {
    my @values;
    foreach my $file_properties ($self->_file_properties) {
      next if not $file_properties->has_tag($frame);
      push @values, $file_properties->tag_value($frame);
    }
    my @unique = List::SomeUtils::uniq @values;
    if (scalar @unique == 1) {
      my $common = $unique[0];
      $common =~ s/"/'/gxsm;
      $self->_tag_properties($frame)->common_value($common);
    }
  }
  return $TRUE;
}

# _write_script()    {{{1
#
# does:   write output script
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _write_script ($self)
{    ## no critic (RequireInterpolationOfMetachars,ProhibitExcessComplexity)

  my @fps = map { $_->file_path } $self->_file_properties;

  # create output
  my @output;
  push @output, '#!/usr/bin/env bash';

  # common values, if any
  my @lines;
  for my $tag ($self->_valid_tags) {
    my $tag_properties = $self->_tag_properties($tag);
    if (defined($tag_properties->common_value)) {
      my $line = sprintf '%s="%s"', $tag, $tag_properties->common_value;
      push @lines, $line;
    }
  }
  if (@lines) {
    push @output, q{}, '# common tag values', q{}, @lines;
  }

  # delete all tags
  push @output, q{}, '# delete existing tags', q{};
  for my $fp (@fps) { push @output, "id3v2 --delete-all \"$fp\""; }

  # cycle through files deriving tag commands
  for my $file_properties ($self->_file_properties) {
    my $fp = $file_properties->file_path;
    push @output, q{}, "# $fp", q{};

    # id3v2 command
    push @output, 'id3v2 \\';
    for my $tag (sort $file_properties->tags) {
      next if $tag eq 'APIC';    ## no critic (ProhibitDuplicateLiteral)

      # genre is special because the --TCON option requires the text
      # value, e.g., 'country', rather than integer code, e.g., '2';
      # while '-g' takes the integer code
      my $option = ($tag eq 'TCON')    ## no critic (ProhibitDuplicateLiteral)
          ? '-g    '
          : "--$tag";
      if (defined($self->_tag_properties($tag)->common_value)) {
        ## no critic (ProhibitUnknownBackslash)
        push @output, "    $option \"\$\{$tag\}\" \\";
        ## use critic
      }
      else {
        my $value = $file_properties->tag_value($tag);
        $value =~ s/"/'/gxsm;
        push @output, "    $option \"$value\" \\";
      }
    }
    push @output, "    \"$fp\"";

    # eyeD3 command
    ## no critic (ProhibitDuplicateLiteral)
    if ($file_properties->has_tag('APIC')) {
      my $img_fp = $file_properties->tag_value('APIC');
      push @output, q{};
      push @output, 'eyeD3 \\';
      push @output, "    --add-image \"${img_fp}:FRONT_COVER\" \\";
      push @output, "    \"${fp}\"";
    }
    ## use critic
  }

  # delete id3v1 tags
  push @output, q{}, '# delete id3v1 tags', q{};
  for my $fp (@fps) { push @output, "id3v2 --delete-v1 \"$fp\""; }

  # get output destination (stdin or file)
  my $file = $self->bash_script;
  my $dest =
      ($file) ? 'file' : 'stdin';    ## no critic (ProhibitDuplicateLiteral)

  # write to output destination
  for ($dest) {

    # file
    if (/\Afile\Z/xsm) {
      $file->spew_utf8(map {"$_\n"} @output);
      my $changed = chmod $EXECUTABLE, $file;
      if ($changed < 1) {
        croak "Unable to set '$file' executable";
      }
    }

    # stdin
    elsif (/\Astdin\Z/xsm) {
      for (@output) { say or croak; }
    }

    else { croak "Invalid destination '$dest'"; }
  }

  return;

}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Id3v2CreateScript - converts id3v2 output to a script

=head1 VERSION

This documentation is for App::Dn::Id3v2CreateScript version 0.6.

=head1 SYNOPSIS

    my app = App::Dn::Id3v2CreateScript->new(
        id3v2_output_file => $input_file,
        bash_script => $output_file,
    );

=head1 DESCRIPTION

Convert id3v2 output (created using the C<--list> option) to a bash script. The
bash script contains an C<id3v2> command for each mp3 file which sets its tags
to those present in the initial output. Any id3v1 tag information in the input
is ignored. The id3v2 output can be provided to this script as stdin (default)
or as a file. The bash script output produced can be sent to stdout (default)
or to a file. If output is sent to a file the created file is set to executable
(permissions 0755).

This may seem to be a pointless script: when would it ever be necessary to set
mp3 file tags to the values they already have? One applicable scenario, and the
impetus for this script, is that on some occasions the id3v2 utility is unable
to modify existing tags on some mp3 files. In those cases it is necessary to
remove all tags and set them anew.

Warning: for any mp3 files containing an album image the image is extracted to
the same directory as the mp3 file.  The image file has the same base name as
the mp3 file, with an extension determined by the image format (e.g.,
F<.jpeg>).  Existing image files with the same name and extensions are silently
overwritten. An extra C<eyeD3> command is added to the script file for each
image file generated. This command adds the image to the mp3 file.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 id3v2_output_file

Path to input file containing id3v2 output. Scalar string.

=head3 bash_script

Path to bash script output file. Scalar string.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

Main method. Creates bash script output file from input file containing id3v2
output.

=head1 DIAGNOSTICS

=head2 Cannot extract COMM value from: FILEPATH

This error occurs when a comment (COMM tag) line is detected but the regular
expression matcher is unable to match the comment text.

=head2 Cannot extract TAG value from: FILEPATH

This error occurs when a id3v2 tag line (a tag other than APIC or COMM) is
detected but the regular expression matcher is unable to match the tag content.

=head2 Cannot find file 'FILEPATH'

This error occurs when an invalid input filepath is provided.

=head2 Cannot write 'FILEPATH': OS_ERROR

This error occurs when the script is unable to write its script output to a
file.

=head2 Couldn't read tags: FILEPATH

This error occurs when attempting to extract an image from an mp3 file. It
occurs because the L<MP3::Tag> module does not extract any tags from the mp3
file.

=head2 Invalid mp3 file path: FILEPATH

This error occurs when attempting to extract an image from an mp3 file. It
occurs because the derived file path is invalid. If this error occurs it
indicates problem with the script design.

=head2 No artwork data found: FILEPATH

This warning is issued if the script detects an APIC tag but is unable to
extract image data using the L<MP3::Tag> module.

=head2 No ID3v2 tags: FILEPATH

This error occurs when attempting to extract an image from an mp3 file. It
occurs because the L<MP3::Tag> module does not extract any id3v2 tags from the
mp3 file.

=head2 Unable to extract file path

The id3v2 output line signifying the start of id3v2 tag data has the format:

    id3v2 tag info for FILEPATH:

This script extracts the filepath from this line. It generates this error if
the regular expression matcher is unable to match the filepath.

=head2 Unable to set 'FILEPATH' executable

After the script file is generated (if the C<-o> option is used) it is set to
the permissions 0755, i.e., executable. This error occurs if that operation
fails.

=head1 DEPENDENCIES

=head2 Perl modules

App::Dn::Id3v2CreateScript::FileProperties,
App::Dn::Id3v2CreateScript::TagProperties, autodie, Carp, charnames,
Const::Fast, English, File::Basename, List::SomeUtils, MP3::Tag, Moo,
MooX::HandlesVia, Path::Tiny, namespace::clean, strictures, Types::Standard,
version.

=head2 Executables

eyeD3, id3v2.

=head1 CONFIGURATION

There is no configuration file and no configuration settings.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 EXIT STATUS

The script exits with a zero value if successful and a non-zero value if a
fatal error occurs.

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
