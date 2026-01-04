package App::Dn::QkDeb::Path;

# modules    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use version; our $VERSION = qv('0.8');
use namespace::clean;
use Const::Fast;
use Types::Path::Tiny;

const my $TRUE => 1;    #}}}1

# attribute

# path    {{{1
has 'path' => (
  is            => 'ro',
  isa           => Types::Path::Tiny::AbsPath,
  coerce        => $TRUE,
  required      => $TRUE,
  documentation => 'File or directory as Path::Tiny::AbsPath',
);    # }}}1

# methods

# name()    {{{1
#
# does:   provide supplied/original file/directory path
# params: nil
# prints: nil
# return: string
sub name ($self) {
  return $self->path->basename();
}

# real()    {{{1
#
# does:   provide real (fully resolved) path
# params: nil
# prints: nil
# return: string
sub real ($self) {
  return $self->path->realpath()->canonpath();
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::QkDeb::Path - supply provided and true paths

=head1 VERSION

This is documentation for App::Dn::QkDeb::Path version 0.8.

=head1 SYNOPSIS

    # ...
    elsif ($type eq 'extra') {
      my $qkdeb = App::Dn::QkDeb::Path->new(path => $path);
      $self->_add_extra_path($qkdeb);
    }
    # ...

=head1 DESCRIPTION

This package was introduced to handle directory names in order to solve a
problem: the parent module (L<App::Dn::QkDeb>) uses the real ("true") path of
a directory which, in the case of symlinks, may have a different directory name
to the original (symlink) directory. This matters for the project paths
because, while it is the real directories that are copied to the build
directory, they must retain their original names.

When creating an object the directory is supplied (attribute 'dir'). It is
coerced into an absolute path which is stored internally as a
L<Path::Tiny> object.

This package enables the original directory names (method C<name>) and real
paths (method C<real>) to be retrieved.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head2 dir

Directory name. Stored as an absolute path (L<Path::Tiny::AbsFile>) but will
coerce a string value. Required.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 name()

=head3 Purpose

Provide the supplied/original directory name.

=head3 Parameters

None.

=head3 Prints

Nothing.

=head3 Returns

Scalar string.

=head2 real()

=head3 Purpose

Provide the real (fully resolved) directory name.

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

Copyright (c) 2024 David Nebauer E<lt>david@nebauer.orgE<gt>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
