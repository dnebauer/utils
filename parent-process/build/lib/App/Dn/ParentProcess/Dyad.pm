package App::Dn::ParentProcess::Dyad;

# use modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('1.9');
use namespace::clean;
use Const::Fast;
use Types::Standard;

const my $TRUE => 1;

has 'parent' => (    # {{{1
  is            => 'ro',
  isa           => Types::Standard::Int,
  required      => $TRUE,
  documentation => 'Parent process id',
);

has 'child' => (     # {{{1
  is            => 'ro',
  isa           => Types::Standard::Int,
  required      => $TRUE,
  documentation => 'Child process id',
);

has 'command' => (    # {{{1
  is            => 'ro',
  isa           => Types::Standard::Str,
  required      => $TRUE,
  documentation => 'Child process command',
);                    # }}}1

1;

# POD {{{1

__END__

=head1 NAME

App::Dn::ParentProcess::Dyad - model a parent-child process pair

=head1 VERSION

This documentation is for App::Dn::ParentProcess::Dyad version 1.9.

=head1 SYNOPSIS

    use App::Dn::ParentProcess::Dyad;

    my $pair = App::Dn::ParentProcess::Dyad->new(
      parent  => $parent,
      child   => $child,
      command => $command,
    );

=head1 DESCRIPTION

A helper module for module L<App::Dn::ParentProcess>.

This module models a parent-child process id pair.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 parent

Parent process id. Scalar integer. Required.

=head3 child

Child process id. Scalar integer. Required.

=head3 command

Child process command. Scalar string. Required.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

None.

=head1 DIAGNOSTICS

This module does not emit any custom warning or error messages.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, Moo, namespace::clean, strictures, Types::Standard, version.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker
