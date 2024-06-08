package App::Dn::Html2Ebooks::Format;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.6');
use namespace::clean;
use MooX::HandlesVia;
use Types::Standard;    # }}}1

# attributes

# name    {{{1
has 'name' => (
  is  => 'ro',
  isa => Types::Standard::Str,
  doc => 'Format name',
);

# args, add_args    {{{1
has '_arguments_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    args     => 'elements',
    add_args => 'push',
  },
  doc => 'Arguments for conversion command',
);    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Html2Ebooks::Format - helper module for App::Dn::Html2Ebooks

=head1 VERSION

This documentation is for App::Dn::Html2Ebooks::Format version 0.4.

=head1 SYNOPSIS

    has '_formats_list' => (
      is  => 'ro',
      isa => Types::Standard::ArrayRef [
        Types::Standard::InstanceOf ['Dn::Html2Ebooks::Format'],
      ],
      ...

=head1 SUBROUTINES/METHODS

=head2 add_args(arg)

Add an argument to the conversion command for the format.

=head2 args()

Retrieve the arguments for the conversion command for the format.

=head1 DESCRIPTION

This is a helper module for L<App::Dn::Html2Ebooks>. It stores the name and
conversion command for a file format the html source file is to be converted
to.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 name

Format name.

=head2 Configuration

This modules does not use configuration files.

=head2 Environment

This module does not use environmental variables.

=head1 INCOMPATIBILITIES

There are no known incompatibilities with other modules.

=head1 DIAGNOSTICS

This module does not emit custom error or warning messages.

=head1 DEPENDENCIES

=head2 Perl modules

Moo, MooX::HandlesVia, namespace::clean, strictures, Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
