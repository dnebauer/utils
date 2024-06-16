package App::Dn::BuildModule::DistroArchive;

# modules {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.036_001;
use namespace::clean;
use version; our $VERSION = '0.10.0';
use App::Dn::BuildModule::Constants;
use Const::Fast;
use Types::Standard;

const my $TRUE => 1;

#const my $FILE_TOKEN => '::FILE::';    # }}}1

# attributes

# match    {{{1
has 'match' => (
  is       => 'rw',
  isa      => Types::Standard::RegexpRef,
  required => $TRUE,
  doc      => 'Regular expression for matching file name',
);

# ext_snips    {{{1
has 'ext_snips' => (
  is       => 'rw',
  isa      => Types::Standard::Int,
  required => $TRUE,
  doc      => 'Number of filetype extensions',
);

# extract_cmd_parts    {{{1
has 'extract_cmd_parts' => (
  is       => 'rw',
  isa      => Types::Standard::ArrayRef [Types::Standard::Str],
  traits   => ['Array'],
  required => $TRUE,
  handles  => { extract_command => 'elements', },
  doc      => 'Command to extract archive',
);    # }}}1

# methods

# extract_cmd($file)    {{{1
#
# does:   provide shell command used to extract archive
# params: $file - name of archive file [scalar, required]
# prints: nil
# return: list of shell command parts
# note:   replace command parts matching $FILE_TOKEN with $file
sub extract_cmd ($self, $file)
{    ## no critic (RequireInterpolationOfMetachars)
  my @cmd = @{ $self->extract_cmd_parts };
  foreach my $part (@cmd) {
    if ($part eq $App::Dn::BuildModule::Constants::FILE_TOKEN) {
      $part = $file;
    }
  }
  return @cmd;
}    # }}}1

1;

# Pod    {{{1

__END__

=head1 NAME

App::Dn::BuildModule::DistroArchive - utility module for App::Dn::BuildModule

=head1 VERSION

This documentation refers to App::Dn::BuildModule::DistroArchive version 0.10.0.

=head1 SYNOPSIS

    use App::Dn::BuildModule::Constants;
    my $targz = App::Dn::BuildModule::DistroArchive->new(
      match             => qr/[.]tar[.]gz\z/xsm,
      ext_snips         => 2,
      extract_cmd_parts => [
        'tar',
        'zxvf',
        $App::Dn::BuildModule::Constants::FILE_TOKEN ],
    );

=head1 DESCRIPTION

This is a utility module used by L<App::Dn::BuildModule>. It models the
behaviour of a particular format for a perl distribution archive, for example,
a F<tar.gz> distribution archive.

For each archive format this module provides:

=over

=item a regular expression that matches the archive file name

=item the number of elements in the suffix

=item a shell command to extract the archive.

=back

=head1 SUBROUTINES/METHODS

=head2 extract_cmd($file)

=head3 Purpose

Provide a shell command that will extract an specific archive in place.

More specifically, it takes the command elements from the module attribute
C<extract_cmd_parts>, replaces any elements matching C<$FILE_TOKEN> with the
provided file name, and returns the command elements.

=head3 Parameters

=over

=item $file

Name of archive file. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

List of command elements.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 match

A regular expression that matches the archive file name.
It usually matches on a distinctive suffix and is expressed as a
regular expression (regex).

For example, the regular expression for targz (F<tar.gz>) archives is
C<qr/[.]tar[.]gz\z/xsm>.

Scalar regex. Required.

=head3 ext_snips

Number of elements in the file name suffix.
This value is useful for snipping the suffix elements off filenames.

For example, for targz (F<tar.gz>) archives the number is 2.

Scalar integer. Required.

=head3 extract_cmd_parts

A shell command to extract the archive contents in place.
The command is broken into words.
One of those words must be C<$FILE_TOKEN>, which represents the
archive file name.

For example, with C<$FILE_TOKEN> set to I<::FILE::>, for targz (F<tar.gz>)
archives the value would be S<< C<[ 'tar', 'zxvf', '::FILE::' ]> >>.

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
