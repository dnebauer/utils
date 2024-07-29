package App::Dn::PkgUpdate;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Const::Fast;
use Env qw($USER);
use MooX::HandlesVia;
use MooX::Options;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE     => 1;
const my $FALSE    => 0;
const my $APTITUDE => 'aptitude';

# }}}1

# options

# ignore_failure (-i)    {{{1
option 'ignore_failure' => (
  is            => 'ro',
  required      => $FALSE,
  short         => 'i',
  documentation => 'Continue after failed command',
);

# final_prompt   (-p)    {{{1
option 'final_prompt' => (
  is            => 'ro',
  required      => $FALSE,
  short         => 'p',
  documentation => 'Prompt when finished',
);    # }}}1

# attributes

# _cmds    {{{1
has '_cmd_list' => (
  is  => 'ro',
  isa => Types::Standard::ArrayRef [
    Types::Standard::ArrayRef [Types::Standard::Str],
  ],
  required    => $TRUE,
  builder     => '_build_cmd_list',
  handles_via => 'Array',
  handles     => { _cmds => 'elements', },
  default     => sub {
    my $self = shift;
    my $cmds = [
      ['dn-local-apt-repository-update-all-dirs'],
      [ $APTITUDE, 'update' ],
      [ $APTITUDE, '--autoclean-on-startup' ],
      [ $APTITUDE, 'install' ],
    ];
    if ($USER ne 'root') {
      foreach my $cmd (@{$cmds}) {
        unshift @{$cmd}, 'sudo';
      }
    }
    return $cmds;
  },
  documentation => q{Aptitude commands},
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check for defined apps
  if (not $self->_cmds) { die "No apps defined\n"; }
  my @cmds = $self->_cmds;

  # check for internet connection
  if (not $self->internet_connection()) {
    die "No internet connection detected\n";
  }
  foreach my $cmd_parts (@cmds) {
    my @cmd     = @{$cmd_parts};
    my $cmd_str = join q{ }, @cmd;
    my $msg     = sprintf "\nRunning [%s]...\n", $cmd_str;
    say $msg or croak;
    if (!eval { system @cmd; 1 }) {
      if (not $self->ignore_failure) {
        die "Command failed, aborting...\n";
      }
    }
  }
  if ($self->final_prompt) { $self->interact_prompt(); }
  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::PkgUpdate - update existing, and install new, debian packages

=head1 VERSION

This documentation refers to C<App::Dn::PkgUpdate> version 0.5.

=head1 SYNOPSIS

    use App::Dn::PkgUpdate;

    App::Dn::PkgUpdate->new_with_options->run;

=head1 DESCRIPTION

Gives user an opportunity to update existing packages and potentially install
additional packages.

This script runs the following commands in sequence:

=over

=item C<dn-local-apt-repository-update-all-dirs>

=item C<aptitude update>

=item C<aptitude --autoclean-on-startup>

=item C<aptitude install>

=back

Package management is a superuser activity. If the user is not root the package
management commands are run with C<sudo>.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Arguments

None.

=head2 Options

=head3 -f | --final_prompt

Display a prompt when finished. Designed for use when called inside a new
terminal, to allow for the user to see feedback before the terminal closes.
Flag. Optional. Default: false.

=head3 -i | --ignore_failure

Whether to continue with further commands after a command fails. Flag.
Optional. Default: false.

=head3 -h | --help

Display help and exit. Flag. Optional. Default: false.

=head2 Properties/attributes

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only public method. It updates existing, and installs new, debian
packages as described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Command failed, aborting...

This error occurs if a package update command exits with an error status.

=head2 No apps defined

This error means no package update commands have been defined.
It is an internal script error which requires script modification.

=head2 No internet connection detected

This script requires an internet connection and will die with this error
message if no such connection is found.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, Env, Moo, MooX::HandlesVia, MooX::Options, namespace::clean,
Role::Utils::Dn, strictures, Types::Standard, version.

=head2 Executables

aptitude, dn-local-apt-repository-update-all-dirs, perl, sudo.

=head1 AUTHOR

David Nebauer S<< <david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker
