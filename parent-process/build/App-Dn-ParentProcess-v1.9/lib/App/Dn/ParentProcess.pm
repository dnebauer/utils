package App::Dn::ParentProcess;

# use modules {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('1.9');
use namespace::clean -except => [ '_options_data', '_options_config', ];
use App::Dn::ParentProcess::Dyad;
use Carp qw(croak confess);
use Const::Fast;
use English;
use List::SomeUtils;
use MooX::HandlesVia;
use MooX::Options;
use Proc::ProcessTable;
use Text::Table;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# options (-p)    {{{1

option 'pid' => (
  is       => 'ro',
  format   => 'i',
  required => $TRUE,
  doc      => 'Process ID (pid) to analyse',
);                       # }}}1

# attributes

# _data {{{1
# - structure: [
#     [ parent, child ],
#     ... ,
#   ]
has '_data' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['App::Dn::ParentProcess::Dyad'],
  ],
  required    => $TRUE,
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _add_pair => 'push',
    _pairs    => 'elements',
  },
  documentation => 'Parent and child process details',
);

# _add_process, _clear_processes, _command, _pids    {{{1
has '_processes' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Standard::Str],
  lazy        => $TRUE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    _add_process     => 'set',      # ($pid, $cmd)->void
    _clear_processes => 'clear',    # ()->void
    _command         => 'get',      # ($pid)->$cmd
    _pids            => 'keys',     # ()->@pids
  },
  documentation => q{Running processes},
);                                  # }}}1

# methods

# run() {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: result
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)
  $self->_get_process_data();
  $self->_print_data();
  return;
}

# _get_process_data() {{{1
#
# does:   get data on process parentage
# params: nil
# prints: nil
# return: n/a, dies on failure
sub _get_process_data ($self) { ## no critic (RequireInterpolationOfMetachars)
  my $child = $self->pid;
  while ($child != 0) {         # 0 is kernel, the final parent
    my $parent  = $self->_process_parent($child);
    my $command = $self->_pid_command($child);
    my $pair    = App::Dn::ParentProcess::Dyad->new(
      parent  => $parent,
      child   => $child,
      command => $command,
    );
    $self->_add_pair($pair);
    $child = $parent;
  }
  return;
}

# _load_processes()    {{{1
#
# does:   load '_processes' attribute with pid=>command pairs
# params: nil
# prints: nil
# return: nil
sub _load_processes ($self) {   ## no critic (RequireInterpolationOfMetachars)
  $self->_clear_processes;
  foreach my $process (@{ Proc::ProcessTable->new()->table() }) {
    $self->_add_process($process->pid, $process->cmndline);
  }
  return;
}

# _pid_command($pid)    {{{1
#
# does:   get command for given process id
# params: $pid - process id [required]
# prints: nil, except error messages
# return: scalar string (process command)
sub _pid_command ($self, $pid)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $self->_pid_running($pid)) {
    warn "PID '$pid' is not running\n";
    return q{};
  }
  return $self->_command($pid);
}

# _pid_running($pid)    {{{1
#
# does:   determines whether process id is running
#         reloads processes each time method is called
# params: $pid - pid to look for [required]
# prints: nil
# return: boolean scalar
sub _pid_running ($self, $pid)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitDuplicateLiteral)
  if (not $pid) { return $FALSE; }
  $self->_reload_processes;
  my @pids = $self->_pids();
  return scalar grep {/^$pid$/xsm} @pids;    # force scalar context
}

# _print_data() {{{1
#
# does:   print process data in pretty table
# params: nil
# prints: nil
# return: n/a, dies on failure
sub _print_data ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # create table and header
  my $sep = \' | ';
  my $t   = Text::Table->new("Parent\nPID", $sep, "Child\nPID", $sep,
    "Child\nprocess");

  # get width of last column
  # - localise package variable as per Perl Best Practice (pp. 77-79)
  const my $LAST_COL_MIN_WIDTH => 15;
  const my $OTHER_COLS_WIDTH   => 18;
  my $term_width     = $self->term_width;
  my $last_col_width = $term_width - $OTHER_COLS_WIDTH;
  if ($last_col_width < $LAST_COL_MIN_WIDTH) {
    die "Terminal is too narrow for display\n";
  }
  local $Text::Wrap::columns = $Text::Wrap::columns;
  $Text::Wrap::columns = $last_col_width;

  # add data rows (wrapping long commands)
  for my $pair (reverse $self->_pairs) {
    my $parent  = $pair->parent;
    my $child   = $pair->child;
    my $command = Text::Wrap::wrap(q{}, q{}, $pair->command);
    $t->add($parent, $child, $command);
  }

  # print table
  my @output;
  my $rule = $t->rule(q{-}, q{+});    # horizontal divider
  push @output, $t->title();
  my @body = $t->body();
  foreach my $line (@body) {
    if ($line !~ /^ \s{7} [|] \s{7} [|]/xsm) {
      push @output, $rule;    # because NOT a wrapped continuation
    }
    push @output, $line;
  }
  foreach my $line (@output) { $line = q{ } . $line; }    # prepend space
  foreach my $line (@output) { print $line or croak; }

  return;
}

# _process_parent($pid)    {{{1
#
# does:   gets parent process of a specified pid
# params: $pid - pid to analyse [required]
# prints: nil, except errors
# return: scalar int (pid)
sub _process_parent ($self, $pid)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitDuplicateLiteral)

  # check arg
  if (not $self->_pid_running($pid)) {
    die "PID '$pid' is not running\n";
  }

  # get parent process
  my $t = Proc::ProcessTable->new();
  my @parents =
      map { $_->ppid() } grep { $_->pid() == $pid } @{ $t->table() };
  my $parent_count = @parents;
  if ($parent_count == 0) { confess "No parent PID found for PID '$pid'"; }
  if ($parent_count > 1) {
    confess "Multiple parent PIDs found for PID '$pid'";
  }
  return $parents[0];
}

# _reload_processes()    {{{1
#
# does:   reload '_processes' attribute with pid=>command pairs
# params: nil
# prints: nil
# return: nil
sub _reload_processes ($self) { ## no critic (RequireInterpolationOfMetachars)
  $self->_load_processes;
  return;
}                               # }}}1

1;

# POD {{{1

__END__

=head1 NAME

App::Dn::ParentProcess - find a process's parent recursively

=head1 VERSION

This documentation is for module App::Dn::ProcessParent version 1.9.

=head1 SYNOPSIS

    my $parents = App::Dn::ParentProcess->new_with_options;
    $parent->run;

=head1 DESCRIPTION

Find a process's parent process recursively, and print that "ancestry"
information to console in a tabular format.

=head1 CONFIGURATION AND ENVIRONMENT

This module requires no attributes to be set and uses no configuration file or
environment variables.

=head1 OPTIONS

=over

=item -p  --pid

Id of process to investigate. Must be a running PID. Required.

=back

=head1 SUBROUTINES/METHODS

=head2 run()

=head3 Purpose

Analyse the specified pid and print "ancestry" information.

=head3 Parameters

None.

=head3 Prints

The "ancestry" information for the specified pid.

=head3 Returns

Void.

=head1 DIAGNOSTICS

=head2 Multiple parent PIDs found for PID 'PID'

Multiple parents were located for a pid in the chain of parents.
This should not happen and indicates a serious problem.
Fatal (with stack trace).

=head2 No parent PID found for PID 'PID'

No parent pid could be located for a pid in the chain of parents.
This should not happen and indicates a serious problem.
Fatal (with stack trace).

=head2 PID 'PID' is not running

The specified pid must be running. Fatal.

=head2 Terminal is too narrow for display

The terminal must be at least 33 characters wide to display tabular output.
Fatal.

=head1 INCOMPATIBILITIES

None known.

=head1 DEPENDENCIES

=head2 Perl modules

App::Dn::ParentProcess::Dyad, Carp, Const::Fast, English, List::SomeUtils, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Proc::ProcessTable,
strictures, Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker
