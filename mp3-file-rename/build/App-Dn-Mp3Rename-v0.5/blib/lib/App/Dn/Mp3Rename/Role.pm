package App::Dn::Mp3Rename::Role;

# use modules    {{{1
use Moo::Role;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean;
use charnames qw(:full);
use Const::Fast;
use Text::Unidecode;

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# methods

# _make_ascii($string)    {{{1
#
# does:   convert to pure ascii, i.e., decimal 0-127 and hex 00-7F
# params: $string - scalar string to encode [required]
# prints: feedback
# return: scalar string, dies on failure
sub _make_ascii ($self, $string)
{ ## no critic (RequireInterpolationOfMetachars ProhibitUnusedPrivateSubroutines)
  my $ascii = Text::Unidecode::unidecode($string);
  return $ascii;
}

# _simplify($name)    {{{1
#
# does:   simplify name by performing these steps
#         - convert to lower case
#         - remove unnecessary characters: "',()[]
#         - convert spaces to dashes
#         - convert multiple dashes to single dashes
#         - remove leading and trailing dashes (originally spaces)
#         - remove insignificant prefixes 'a', 'an' and 'the'
#         - replace '&' with 'and'
# params: $name - name to be simplifed [scalar string, required]
# prints: feedback
# return: scalar string, dies on failure
sub _simplify ($self, $name)
{ ## no critic (RequireInterpolationOfMetachars ProhibitUnusedPrivateSubroutines)

  # - ignore three perlcritic 'string *may* require interpolation'
  #   warnings triggered by use of this variable
  # - for an unknown reason using '\N{DIVISION SLASH}\N{REVERSE SOLIDUS}'
  #   instead of '\\\/' does not work in practice on all track titles
  # - is safe to convert dots to dashes in this script because this method
  #   is only ever carried out on parts of a file basename, and will never
  #   interfere with dots preceding file extensions
  ## no critic (RequireInterpolationOfMetachars)
  my $extraneous_chars =
        q{["'`,;:?!\\\/}
      . '\N{LEFT PARENTHESIS}\N{RIGHT PARENTHESIS}'
      . '\N{LEFT SQUARE BRACKET}\N{RIGHT SQUARE BRACKET}'
      . '\N{LEFT CURLY BRACKET}\N{RIGHT CURLY BRACKET}]';
  ## use critic
  my $string = lc $name;                          # lower case
  $string =~ s{$extraneous_chars}{}gxsm;          # remove extra chars
  $string =~ s/ /-/gsm;                           # spaces to dashes
  $string =~ s/[.]/-/gxsm;                        # dots to dashes
  $string =~ s/-+/-/gxsm;                         # collapse dashes
  $string =~ s/\A-+//xsm;                         #\ remove dashes from
  $string =~ s/-+\Z//xsm;                         #/ both ends
  $string =~ s/\A^(a-|an-|the-)?(.*)\Z/$2/xsm;    # remove prefixes
  $string =~ s/&/and/gxsm;                        # expand '&' to 'and'

  # - special cases
  $string =~ s/[.]-/-/gxsm;                       # dot-dash to dash

  return $string;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Mp3Rename::Role - provide methods to multiple modules

=head1 VERSION

This documentation refers to dn-mp3file-rename version 0.5.

=head1 SYNOPSIS

    # ...
    with qw(App::Dn::Mp3Rename::Role);
    # ...
    my $ascii = $self->_make_ascii($album);
    return $self->_simplify($ascii);

=head1 DESCRIPTION

Role providing methods to L<App::Dn::Mp3Rename> and
L<App::Dn::Mp3Rename::AudioFile> modules.

=head1 SUBROUTINES/METHODS

=head2 _make_ascii($string)

=head3 Purpose

Convert string to pure ascii, i.e., decimal 0-127 and hex 00-7F.

=head3 Parameters

=over

=item $string

Scalar string to encode. Required.

=back

=head3 Prints

Nothing.

=head3 Returns

Scalar string.

=head2 _simplify($name)

=head3 Purpose

Simplify name by performing these steps:

=over

=item *

convert to lower case

=item *

remove unnecessary characters: "',()[]

=item *

convert spaces to dashes

=item *

convert multiple dashes to single dashes

=item *

remove leading and trailing dashes (originally spaces)

=item *

remove insignificant prefixes 'a', 'an' and 'the'

=item *

replace '&' with 'and'.

=back

=head3 Parameters

=over

=item $name

Name to be simplifed. Scalar string. Required.

=back

=head3 Prints

Nothing.

=head3 Returns

Scalar string.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 DIAGNOSTICS

This module emits no custom errors or warnings.

=head1 DEPENDENCIES

=head2 Perl modules

charnames, Const::Fast, Moo::Role, namespace::clean, strictures,
Text::Unidecode, version.

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
