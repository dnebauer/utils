package App::Dn::Id3v2CreateScript::FileProperties;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.6');
use namespace::clean;
use Const::Fast;
use MooX::HandlesVia;
use Types::Standard;

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# attributes

# mp3 file path    {{{1
has 'file_path' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    Types::Standard::InstanceOf ['Path::Tiny'],
  ],
  default => undef,
  doc     => 'Mp3 file path',
);

# has_tag, set_tag, tag_value, tags    {{{1
has '_tag_values_hash' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Standard::Str],
  lazy        => $TRUE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    has_tag   => 'exists',    # has_tag(TAG) --> BOOL
    set_tag   => 'set',       # set_tag(TAG => VAL) --> VAL
    tag_value => 'get',       # get_tag(TAG) --> VAL
    tags      => 'keys',      # tags() --> TAGS_LIST
  },
  doc => 'Array of tag values',
);                            # }}}1

# methods

# canon_path()    {{{1
#
# does:   get canonical file path
# params: nil
# prints: feedback
# return: scalar string file path (success) or undef (failure)
sub canon_path ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $mp3      = $self->file_path;
  my $mp3_path = (defined $mp3) ? $mp3->realpath->canonpath : undef;
  return $mp3_path;
}

# frame_value($tag)    {{{1
#
# does:   get frame/tag value (empty string if no frame)
# params: $frame - frame id
# prints: feedback
# return: scalar string tag value or empty string, dies on failure
sub frame_value ($self, $frame)
{    ## no critic (RequireInterpolationOfMetachars)
  return ($self->has_tag($frame)) ? $self->tag_value($frame) : q{};
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Id3v2CreateScript::FileProperties - models properties of an mp3 file

=head1 VERSION

This documentation is for App::Dn::Id3v2CreateScript::FileProperties version
0.6.

=head1 SYNOPSIS

    use App::Dn::Id3v2CreateScript::FileProperties;

=head1 DESCRIPTION

This module models the properties of an mp3 file: its file path and tag
properties.

=head1 SUBROUTINES/METHODS

=head2 canon_path()

Gets the canonical path for the mp3 file. Returns a scalar string.

=head2 frame_value($tag)

Gets frame/tag value from the mp3 file.
Returns an empty string if there is no frame value.

=head2 has_tag($tag)

Determines whether a tag is defined for the module object. Returns a boolean.

=head2 set_tag($tag => $value)

Set a tag value for the module object. Ignore the return value.

=head2 tag_value($tag)

Gets the value for a specified tag in the module object.
Returns a scalar string.

=head2 tags()

Gets the names of all defined tags in the module object. Returns a list.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 file_path

Mp3 file path.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 DIAGNOSTICS

This module emits no custom error messages.

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, Moo, MooX::HandlesVia, namespace::clean, strictures,
Types::Standard, version.

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

Copyright (c) 2021 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
