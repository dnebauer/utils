package App::Dn::Base64Image;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.2');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use autodie qw(open close);
use Carp    qw(croak);
use Const::Fast;
use File::MimeInfo;
use MIME::Base64;
use MooX::Options;
use Path::Tiny;
use Types::Standard;

const my $TRUE => 1;    # }}}1

# options

# image_file (-f)    {{{1
option 'image_file' => (
  is            => 'rw',
  format        => 's',
  short         => 'f',
  required      => $TRUE,
  documentation => 'Path to image to convert',
);

# mimetype   (-m)    {{{1
option 'mime_type' => (
  is            => 'rw',
  format        => 's',    ## no critic (ProhibitDuplicateLiteral)
  short         => 'm',
  documentation => 'Override autodetected mimetype',
);                         # }}}1

# attributes

# _image_obj, _image_fp    {{{1
has _image_obj => (
  is      => 'ro',
  isa     => Types::Standard::InstanceOf ['Path::Tiny'],
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    return Path::Tiny::path($self->image_file);
  },
  doc => 'Path::Tiny object representing image file path',
);

sub _image_fp ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_image_obj->canonpath;
}                          # }}}1

# methods

# run()    {{{1
#
# does:   write html element to standard output
# params: nil
# prints: html img element
# return: n/a (die if error)
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check file exists
  if (not $self->_image_obj->is_file) {
    my $fp = $self->_image_fp;
    die "Invalid file path: $fp\n";
  }

  # get file mimetype
  my $mimetype = $self->_file_mime_type();
  if (not $mimetype) {
    die "Unable to determine image file mime type\n";
  }

  # get file content as base64
  my $data = $self->_encode_image();
  if (not $data) {
    die "Unable to encode image file\n";
  }

  # write img element
  print qq{<img src="data:$mimetype;base64,$data"/>} or croak;

  return;
}

# _file_mimetype()    {{{1
#
# does:   get file mimetype
# params: nil
# prints: nil
# return: scalar string
sub _file_mime_type ($self) {   ## no critic (RequireInterpolationOfMetachars)
  if ($self->mime_type) { return $self->mime_type; }
  return File::MimeInfo->new()->mimetype($self->_image_fp);
}

# _encode_image()    {{{1
#
# does:   encode image as base64
# params: nil
# prints: nil
# return: scalar string (base64 data)
# note:   previously used MIME::Base64::URLSafe>url_b64encode to encode
#         data, but resulting output could not be handled by Firefox
sub _encode_image ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $raw     = $self->_image_obj->slurp_raw;
  my $encoded = MIME::Base64::encode_base64($raw);
  $encoded =~ s/\s+//xsmg;
  return $encoded;
}                              # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Base64Image - provide data uri for an image

=head1 VERSION

This documentation applies to App::Dn::Base64Image version 0.2.

=head1 SYNOPSIS

    use App::Dn::Base64Image;

    App::Dn::Base64Image->new_with_options->run;

=head1 DESCRIPTION

Create html element 'img' for an image using data uri with base64 encoding.
Encoded data is printed to stdout.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None used.

=head3 Environment variables

None used.

=head1 OPTIONS

=over

=item B<-f> | B<--image_file> image_file

Image to convert. Filepath (must exist).

Required.

=item B<-m> | B<--mime_type> mime_type

Override autodetected image mime type.

Optional. Default: false.

=item B<-h>

Display help and exit.

=back

=head1 SUBROUTINES/METHODS

This is the only public method. It writes the html element to stdout.

=head1 DIAGNOSTICS

=head2 Invalid file path: FILEPATH

Occurs when an invalid image file path has been provided.

=head2 Unable to determine image file mime type

Occurs when the module L<File::MimeInfo> is unable to determine the mime type
of the image file.

=head2 Unable to encode image file

Occurs when the module L<MIME::Base64> is unable to encode the raw content of
the image file as S<<base 64>.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Const::Fast, File::MimeInfo, MIME::Base64, Moo, MooX::Options,
namespace::clean, Path::Tiny, strictures, Types::Standard, version.

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer E<lt>david@nebauer.orgE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim: fdm=marker :
