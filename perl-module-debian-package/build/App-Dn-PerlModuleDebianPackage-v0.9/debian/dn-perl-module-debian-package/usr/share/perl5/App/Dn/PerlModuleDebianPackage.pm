package App::Dn::PerlModuleDebianPackage;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.9');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak confess);
use Const::Fast;
use English;
use List::SomeUtils;
use MooX::Options;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# options

# additional_modules (-a) {{{1
option 'additional_modules' => (
  is        => 'ro',
  format    => 's@',
  required  => $FALSE,
  default   => sub { [] },
  autosplit => q{,},
  short     => 'a',
  doc       => 'Perl modules required for perl command',
);

# no_copy            (-n) {{{1
option 'no_copy' => (
  is       => 'ro',
  required => $FALSE,
  short    => 'n',
  doc      => q{Don't copy package name to clipboard},
);    # }}}1

# attributes

# _debian_package    {{{1
has '_debian_package' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  required      => $FALSE,
  documentation => 'Debian package providing module',
);

# _module {{{1
has '_module' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    my @args = List::SomeUtils::uniq @ARGV;

    # must have one argument only
    die "No argument provided\n"                  if not @args;
    die "Too many module names (need one only)\n" if scalar @args > 1;

    return $args[0];
  },
  doc => 'Perl module name',
);

# _module_file    {{{1
has '_module_file' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  required      => $FALSE,
  documentation => 'File from which module loaded',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: result
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)
  $self->_get_module_file();
  $self->_get_debian_package();
  $self->_provide_feedback();
  $self->_copy_to_clipboard();
  return;
}

# _copy_to_clipboard()    {{{1
#
# does:   copy package name to clipboard
# params: nil
# prints: feedback if error
# return: n/a
sub _copy_to_clipboard ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  return if $self->no_copy;

  my $pkg = $self->_debian_package;

  $self->copy_to_clipboard($pkg);

  return;

}

# _get_cmd_output($cmd)    {{{1
#
# does:   get output from shell command
# params: $cmd - shell command [arrayref, required]
# prints: nil
# return: array
sub _get_cmd_output ($self, $cmd)
{    ## no critic (RequireInterpolationOfMetachars)
  my @output;
  my $result = $self->shell_command($cmd);    # croaks on failure
  push @output, $result->stdout;
  if (not @output) { exit; }                  # error already displayed
  if (scalar @output != 1) {
    my $msg = q{Unexpected output '} . join q{|}, @output . q{'};
    confess $msg;
  }
  return @output;
}

# _get_debian_package()    {{{1
#
# does:   get file loaded for module
# params: nil
# prints: nil
# return: scalar file path
sub _get_debian_package ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $module_file    = $self->_module_file;
  my $cmd            = [ 'dpkg', '-S', $module_file ];
  my @output         = $self->_get_cmd_output($cmd);
  my $debian_package = (split /:/xsm, $output[0])[0];
  $self->_debian_package($debian_package);
  return;
}

# _get_module_file()    {{{1
#
# does:   get file loaded for module
# params: nil
# prints: nil
# return: scalar file path
sub _get_module_file ($self) {  ## no critic (RequireInterpolationOfMetachars)
  my $module = $self->_module;
  my $file   = $module =~ s{::}{/}grxsm;
  my $cmd;
  $cmd .= q[perl];
  my @additional_modules = @{ $self->additional_modules };
  foreach my $additional_module (@additional_modules) {
    $cmd .= qq[ -M'$additional_module'];
  }
  $cmd .= qq[ -M'$module' -E 'say ] . q[$] . qq[INC{"${file}.pm"}'];
  my @output      = $self->_get_cmd_output($cmd);
  my $module_file = $output[0];
  $self->_module_file($self->path_true($module_file));
  return;
}

# _provide_feedback()    {{{1
#
# does:   provide feedback to user
# params: nil
# prints: feedback
# return: n/a
sub _provide_feedback ($self) { ## no critic (RequireInterpolationOfMetachars)
  say 'Module name:    ' . $self->_module         or croak;
  say 'Module file:    ' . $self->_module_file    or croak;
  say 'Debian package: ' . $self->_debian_package or croak;
  return;
}                               # }}}1

1;

# POD {{{1

__END__

=head1 NAME

App::Dn::PerlModuleDebianPackage - find debian package providing perl module

=head1 VERSION

This documantation is for C<App::Dn::PerlModuleDebianPackage> version 0.9.

=head1 SYNOPSIS

    use App::Dn::PerlModuleDebianPackage;

    App::Dn::PerlModuleDebianPackage->new_with_script->run;

=head1 DESCRIPTION

Finds the file loaded when a specified module is loaded, and finds the debian
package providing that file.

It may be necessary to provide additional module names. See the notes for the
S<< C<--additional_modules> >> option for more details.

The debian package name is also copied to the system clipboard unless this is
suppressed by the S<< C<--no_copy> >> option. On X-windows systems such as
linux there are three I<selections> (the term for copied or cut text):
I<primary>, I<secondary> and I<clipboard>. This script copies the package name
to the I<primary> and I<clipboard> selections. These selections are pasted
using the middle mouse button and ctrl+v keys, respectively. In terminals it
may be necessary to paste with shift key + middle mouse button, and
shift+ctrl+v keys, respectively.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Arguments

=head3 module

The perl module to analyse. String. Required.

=head2 Options

=head3 -a | --additional_modules MODULE ...

Additional perl module(s) required to run perl command that discovers module
file.

To specify multiple additional modules:

=over

=item *

Use the C<-a> option for each additional module, or

=item *

Provide multiple modules to C<-a> as a comma-delimited string (with no spaces),
or

=item *

A combination of both approaches.

=back

The need for an additional module may suggested by an error message when
running the script. For example, when analysing module C<MooX::Options> the
script returns the following error message:

    Can't find the method <with> in <main> ! Ensure to load a Role::Tiny \
    compatible module like Moo or Moose before using MooX::Options.\
    at -e line 0.

While the message is somewhat opaque, it is clearly asking for C<Moo> or
C<Moose>. Providing either of these as an additional module results in
successful execution.

=head3 -n | --no_copy

Do not copy the debian package name to the clipboard. Flag. Optional.
Default: false.

=head3 -h | --help

Display help and exit. Flag. Optional. Default: false.

=head2 Properties/attributes

There are no public attributes.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only public method. It finds the debian package providing a perl
module, as described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Can't find the method <with> in <main> ! Ensure to load ...

While the message is somewhat opaque, it is clearly asking for C<Moo> or
C<Moose>. Providing either of these as an additional module results in
successful execution.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, English, List::SomeUtils, Moo, MooX::Options,
namespace::clean, Role::Utils::Dn, strictures, Types::Standard, version.

=head1 AUTHOR

David Nebauer S<< <david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker:
