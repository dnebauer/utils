# NAME

App::Dn::PkgUpdate - update existing, and install new, debian packages

# VERSION

This documentation refers to `App::Dn::PkgUpdate` version 0.5.

# SYNOPSIS

    use App::Dn::PkgUpdate;

    App::Dn::PkgUpdate->new_with_options->run;

# DESCRIPTION

Gives user an opportunity to update existing packages and potentially install
additional packages.

This script runs the following commands in sequence:

- `dn-local-apt-repository-update-all-dirs`
- `aptitude update`
- `aptitude --autoclean-on-startup`
- `aptitude install`

Package management is a superuser activity. If the user is not root the package
management commands are run with `sudo`.

# CONFIGURATION AND ENVIRONMENT

## Arguments

None.

## Options

### -f | --final\_prompt

Display a prompt when finished. Designed for use when called inside a new
terminal, to allow for the user to see feedback before the terminal closes.
Flag. Optional. Default: false.

### -i | --ignore\_failure

Whether to continue with further commands after a command fails. Flag.
Optional. Default: false.

### -h | --help

Display help and exit. Flag. Optional. Default: false.

## Properties/attributes

None.

## Configuration files

None used.

## Environment variables

None used.

# SUBROUTINES/METHODS

## run()

This is the only public method. It updates existing, and installs new, debian
packages as described in ["DESCRIPTION"](#description).

# DIAGNOSTICS

## Command failed, aborting...

This error occurs if a package update command exits with an error status.

## No apps defined

This error means no package update commands have been defined.
It is an internal script error which requires script modification.

## No internet connection detected

This script requires an internet connection and will die with this error
message if no such connection is found.

# INCOMPATIBILITIES

There are no known incompatibilities.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

Carp, Const::Fast, Env, Moo, MooX::HandlesVia, MooX::Options, namespace::clean,
Role::Utils::Dn, strictures, Types::Standard, version.

## Executables

aptitude, dn-local-apt-repository-update-all-dirs, perl, sudo.

# AUTHOR

David Nebauer <david@nebauer.org>

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer <david@nebauer.org>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
