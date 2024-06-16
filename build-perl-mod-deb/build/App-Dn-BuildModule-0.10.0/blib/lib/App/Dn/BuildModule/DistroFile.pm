package App::Dn::BuildModule::DistroFile;

# modules {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.036_001;
use namespace::clean;
use version; our $VERSION = '0.10.0';
use Const::Fast;
use Types::Standard;

const my $TRUE => 1;

#const my $FILE_TOKEN => '::FILE::';    # }}}1

# attributes

# name    {{{1
has 'name' => (
  is       => 'rw',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Distribution file name',
);

# module_ver   {{{1
has 'module_ver' => (
  is       => 'rw',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Module version',
);

# distro_type    {{{1
# - this keyword is one of the keys of the Dn::BuildModule
#   hash attribute 'distro_types_details'
has 'distro_type' => (
  is       => 'rw',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Distribution type keyword',
);    # }}}1

1;

# Pod    {{{1

__END__

=head1 NAME

App::Dn::BuildModule::DistroFile - utility module for App::Dn::BuildModule

=head1 VERSION

This documentation refers to App::Dn::BuildModule::DistroFile version 0.10.0.

=head1 SYNOPSIS

    my $result = Dn::Distro::File->new(
      name        => $distro_file,
      module_ver  => $module_ver,
      distro_type => $type,
    );

=head1 DESCRIPTION

This is a utility module used by L<App::Dn::BuildModule>.
It models certain attributes about a perl distribution file: file name,
module version, distribution type (file format).

=head1 SUBROUTINES/METHODS

None provided.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 name

Name of distribution file. Scalar string. Required.

=head3 module_ver

The part of the file name representing module name and version.
Scalar string. Required.

=head3 distro_type

Key token indicating the distribution type.
It is derived from the key values used in the L<App::Dn::BuildModule>
attribute C<distro_types_details>.
Scalar string. Required.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 DIAGNOSTICS

This module emits no custom warning or error messages.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None reported.

=head1 DEPENDENCIES

Const::Fast, Moo, strictures, Types::Standard, version.

=head1 LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Copyright 2024, David Nebauer

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=cut
# }}}1

# vim:fdm=marker
