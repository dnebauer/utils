package App::Dn::ExeDebPkg;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.4');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak confess);
use Const::Fast;
use MooX::Options;
use Types::Standard qw(Str);

with qw(Role::Utils::Dn);

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# options

# exe    {{{1
option 'exe' => (
  is            => 'ro',
  format        => 's',
  required      => $TRUE,
  short         => 'e',
  order         => 1,
  documentation => 'Executable name',
);    # }}}1

# attributes

# _debian_package    {{{1
has '_debian_package' => (
  is            => 'rw',
  isa           => Str,
  required      => $FALSE,
  documentation => 'Debian package providing module',
);

# _exe_filepath    {{{1
has '_exe_filepath' => (
  is            => 'rw',
  isa           => Str,
  required      => $FALSE,
  documentation => 'File from which module loaded',
);    # }}}1

# methods

#   run()
#
#   does:   main method
#   params: nil
#   prints: feedback
#   return: result
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)
  $self->_get_exe_filepath();
  $self->_get_debian_package();
  $self->_provide_feedback();

  return $TRUE;
}

# _get_debian_package()    {{{1
#
# does:   get file loaded for module
# params: nil
# prints: nil
# return: scalar file path
sub _get_debian_package ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # assemble dpkg command
  my $exe_path = $self->_exe_filepath;
  my $cmd      = [ 'dpkg', '-S', $exe_path ];

  # run dpkg command
  my $result = $self->shell_command($cmd);

  # croak if command fails...
  if (not $result->success) {
    my $err_msg;
    if ($result->has_stderr) {
      my $stderr = join "\n", $result->stderr;
      $err_msg = $stderr;
    }
    else {
      my $cmd_str = join q{ }, @{$cmd};
      $err_msg = "Command '$cmd_str' failed";
    }
    confess $err_msg;
  }

  # ...or output is invalid
  my @output = $result->stdout;
  if (not @output) { exit; }    # error already displayed
  if (scalar @output != 1) {
    my $msg = q{Unexpected output '} . join q{|}, @output . q{'};
    croak $msg;
  }

  # provide deb package name
  my $debian_package = (split /:/xsm, $output[0])[0];
  return $self->_debian_package($debian_package);
}

# _get_exe_filepath()    {{{1
#
# does:   get path of file
# params: nil
# prints: nil
# return: scalar file path
sub _get_exe_filepath ($self) { ## no critic (RequireInterpolationOfMetachars)
  my $exe  = $self->exe;
  my $path = $self->path_executable($exe);
  return $self->_exe_filepath($self->path_true($path));
}

# _provide_feedback()    {{{1
#
# does:   provide feedback to user
# params: nil
# prints: feedback
# return: n/a
sub _provide_feedback ($self) { ## no critic (RequireInterpolationOfMetachars)
  say 'Executable name:     ' . $self->exe             or croak;
  say 'Executable filepath: ' . $self->_exe_filepath   or croak;
  say 'Debian package:      ' . $self->_debian_package or croak;

  return $TRUE;
}                               # }}}1

1;

# POD

__END__

=head1 NAME

App::Dn::ExeDebPkg - find debian package providing executable

=head1 VERSION

This documentation applies to C<App::Dn::ExeDebPkg> version 0.4.

=head1 SYNOPSIS

    use App::Dn::ExeDebPkg;

    App::Dn::ExeDebPkg->new_with_options->run;

=head1 DESCRIPTION

Finds the debian package providing the executable file name and displays
information about the executable file and debian package.

The output of a successful invocation looks like:

    Executable name:     EXE_NAME
    Executable filepath: /EXE/FILE/PATH
    Debian package:      DEBIAN_PACKAGE_NAME

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 OPTIONS

=head2 -e | --exe S<< <exe_name> >>

The executable to analyse. Scalar string executable file name (must exist).
Required.

=head2 -h | --help

Display help and exit.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It finds the name of the debian package providing the
executable and displays it.

=head1 DIAGNOSTICS

=head2 Command 'CMD' failed

If the C<dpkg> command used to find the debian package name fails, one of two
things will happen:

=over

=item *

If the command failed without an error message then this message is displayed

=item *

If the command failed with an error message that error message is displayed.

=back

=head2 Unexpected output 'OUTPUT'

If the C<dpkg> command used to find the debian package name succeeds but
produces more than 1 line of standard output, the program display the output
and halts with an error status.

Before displaying the output all newlines in it are converted to vertical bars
("|").

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, Moo, MooX::Options, namespace::clean, Role::Utils::Dn,
strictures, Types::Standard, version.

=head2 Executables

dpkg.

=head1 AUTHOR

David Nebauer S<< <david at nebauer dot org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer E<lt>david at nebauer dot orgE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
