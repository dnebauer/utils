# NAME

App::Dn::ParentProcess - find a process's parent recursively

# VERSION

This documentation is for module App::Dn::ProcessParent version 1.9.

# SYNOPSIS

    my $parents = App::Dn::ParentProcess->new_with_options;
    $parent->run;

# DESCRIPTION

Find a process's parent process recursively, and print that "ancestry"
information to console in a tabular format.

# CONFIGURATION AND ENVIRONMENT

This module requires no attributes to be set and uses no configuration file or
environment variables.

# OPTIONS

- -p  --pid

    Id of process to investigate. Must be a running PID. Required.

# SUBROUTINES/METHODS

## run()

### Purpose

Analyse the specified pid and print "ancestry" information.

### Parameters

None.

### Prints

The "ancestry" information for the specified pid.

### Returns

Void.

# DIAGNOSTICS

## Multiple parent PIDs found for PID 'PID'

Multiple parents were located for a pid in the chain of parents.
This should not happen and indicates a serious problem.
Fatal (with stack trace).

## No parent PID found for PID 'PID'

No parent pid could be located for a pid in the chain of parents.
This should not happen and indicates a serious problem.
Fatal (with stack trace).

## PID 'PID' is not running

The specified pid must be running. Fatal.

## Terminal is too narrow for display

The terminal must be at least 33 characters wide to display tabular output.
Fatal.

# INCOMPATIBILITIES

None known.

# DEPENDENCIES

## Perl modules

App::Dn::ParentProcess::Dyad, Carp, Const::Fast, English, List::SomeUtils, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Proc::ProcessTable,
strictures, Types::Standard, version.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# AUTHOR

David Nebauer (david at nebauer dot org)

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
