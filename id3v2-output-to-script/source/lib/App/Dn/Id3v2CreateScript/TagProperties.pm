package App::Dn::Id3v2CreateScript::TagProperties;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.6');
use namespace::clean;
use Types::Standard;    # }}}1

# attributes

# common_value   {{{1
has 'common_value' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [Types::Standard::Str],
  doc => 'Set if tag value common to all mp3 files',
);

# preferred frame   {{{1
has 'preferred_frame' => (
  is  => 'ro',
  isa => Types::Standard::Str,
  doc => 'Preferred frame name to use',
);

# value regex   {{{1
has 'value_regex' => (
  is  => 'ro',
  isa => Types::Standard::Maybe [Types::Standard::RegexpRef],
  doc => 'Regex for extracting tag value from id3v2 output',
);    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Id3v2CreateScript::TagProperties - models properties of an mp3 tag

=head1 VERSION

This documentation is for App::Dn::Id3v2CreateScript::TagProperties version
0.6.

=head1 SYNOPSIS

    use App::Dn::Id3v2CreateScript::TagProperties;

=head1 DESCRIPTION

This module models the properties of an mp3 tag.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 common_value

Set if tag value common to all mp3 files. Can be a string or undef.
Acts as a boolean: true if defined, false if undefined.

=head3 preferred_frame

Preferred frame name to use for tag. Scalar string.

=head3 value_regex

Regex for extracting tag value from id3v2 output. Regex.

=head1 SUBROUTINES/METHODS

None.

=head1 DIAGNOSTICS

This module emits no custom error messages.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Moo, namespace::clean, strictures, Types::Standard, version.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2021 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
