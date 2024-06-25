# NAME

App::Dn::ExeDebPkg - find debian package providing executable

# VERSION

This documentation applies to `App::Dn::ExeDebPkg` version 0.4.

# SYNOPSIS

    use App::Dn::ExeDebPkg;

    App::Dn::ExeDebPkg->new_with_options->run;

# DESCRIPTION

Finds the debian package providing the executable file name and displays
information about the executable file and debian package.

The output of a successful invocation looks like:

    Executable name:     EXE_NAME
    Executable filepath: /EXE/FILE/PATH
    Debian package:      DEBIAN_PACKAGE_NAME

# CONFIGURATION AND ENVIRONMENT

## Properties

None.

## Configuration files

None used.

## Environment variables

None used.

# OPTIONS

## -e | --exe &lt;exe\_name>

The executable to analyse. Scalar string executable file name (must exist).
Required.

## -h | --help

Display help and exit.

# SUBROUTINES/METHODS

## run()

The only public method. It finds the name of the debian package providing the
executable and displays it.

# DIAGNOSTICS

## Command 'CMD' failed

If the `dpkg` command used to find the debian package name fails, one of two
things will happen:

- If the command failed without an error message then this message is displayed
- If the command failed with an error message that error message is displayed.

## Unexpected output 'OUTPUT'

If the `dpkg` command used to find the debian package name succeeds but
produces more than 1 line of standard output, the program display the output
and halts with an error status.

Before displaying the output all newlines in it are converted to vertical bars
("|").

# INCOMPATIBILITIES

There are no known incompatibilities.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

Carp, Const::Fast, Moo, MooX::Options, namespace::clean, Role::Utils::Dn,
strictures, Types::Standard, version.

## Executables

dpkg.

# AUTHOR

David Nebauer &lt;david at nebauer dot org>

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer &lt;david at nebauer dot org>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
