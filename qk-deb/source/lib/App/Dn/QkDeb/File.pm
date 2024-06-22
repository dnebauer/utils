package App::Dn::QkDeb::File;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.8');
use namespace::clean;
use Const::Fast;
use Types::Path::Tiny;

const my $TRUE => 1;    # }}}1

# attribute

# file    {{{1
has 'file' => (
  is            => 'ro',
  isa           => Types::Path::Tiny::AbsFile,
  coerce        => $TRUE,
  required      => $TRUE,
  documentation => 'File as Path::Tiny::AbsFile',
);    # }}}1

# methods

# name()    {{{1
#
# does:   provide supplied/original file name
# params: nil
# prints: nil
# return: string
sub name ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->file->basename();
}

# real()    {{{1
#
# does:   provide real (fully resolved) file name
# params: nil
# prints: nil
# return: string
sub real ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->file->realpath()->canonpath();
}                     # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::QkDeb::File - supply provided and true file names

=head1 VERSION

This is documentation for App::Dn::QkDeb::File version 0.8.

=head1 SYNOPSIS

    has '_distribution_filepath' => (
        is     => 'rw',
        isa    => Types::Standard::InstanceOf ['App::Dn::QkDeb::File'],
        coerce => $TRUE,
    );

    # later

    my $file  = 'My-Distro-v1.0.tar.gz'
    my $qkdeb = App::Dn::QkDeb::File->new( file => $file );
    $self->_distribution_filepath($qkdeb);

    # later

    my $distro_name = $self->_distribution_filepath->name;
    my $distro_path = $self->_distribution_filepath->real;

=head1 DESCRIPTION

This package was introduced to handle file names in order to solve a problem:
the parent module (L<App::Dn::QkDeb>) uses the real ("true") path of a file
which, in the case of symlinks, may have a different file name to the original
(symlink) file. This matters for the project files because, while it is the
real files that are copied to the build directory, they must retain their
original file names.

When creating an object the file is supplied (attribute 'file'). It is coerced
into an absolute path which is stored internally as a L<Path::Tiny> object.

This package enables the original file names (method C<name>) and real paths
(method C<real>) to be retrieved.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head2 file

File name. Stored as an absolute path (L<Path::Tiny::AbsFile>) but will coerce
a string value. Required.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 name()

=head3 Purpose

Provide the supplied/original file name.

=head3 Parameters

None.

=head3 Prints

Nothing.

=head3 Returns

Scalar string.

=head2 real()

=head3 Purpose

Provide the real (fully resolved) file name.

=head3 Parameters

None.

=head3 Prints

Nothing.

=head3 Returns

Scalar string.

=head1 DIAGNOSTICS

This module does not emit any custom error or warning messages.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

Const::Fast, Moo, namespace::clean, strictures, Types::Path::Tiny, version.

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 Nebauer E<lt>david@nebauer.orgE<gt>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
