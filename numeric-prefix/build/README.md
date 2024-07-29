# NAME

App::Dn::NumericPrefix - add numeric prefix to file names

# VERSION

This documentation is for `App::Dn::NumericPrefix` version 0.6.

# SYNOPSIS

    use App::Dn::NumericPrefix;

    App::Dn::NumericPrefix->new_with_options->run;

# DESCRIPTION

Add an incrementing numeric prefix to the file names of a group of files. For
example, files `a` and `b` are renamed to `1_a` and `2_b`. File order is
standard shell ascii order.

If there are more than nine files to be processed, the numeric prefixes are
left zero-padded. For example, if there were over a hundred files, files `a`
and `b` may be renamed `001_a` and `002_b`.

# CONFIGURATION AND ENVIRONMENT

## OPTIONS

### -c | --current

List paths of files to which numeric prefixes will be added. No files are
actually renamed when this option is used. Flag. Optional. Default: false.

### -r | --renamed

Show paths of files that will result after numeric prefixes are added. No files
are actually renamed when this option is used. Flag. Optional. Default:
false.

### -f | --force

Proceed with file renaming even if existing files will be overwritten. Flag.
Optional. Default: false.

### -h | --help

Display help and exit.

## ARGUMENTS

### glob

Glob specifying paths of files to which numeric prefixes will be added.
String. Required.

## Attributes

None.

## Configuration files

None used.

## Environment variables

None used.

# SUBROUTINES/METHODS

## run()

The only public method. It renames files as described in ["DESCRIPTION"](#description).

# DIAGNOSTICS

## Unable to rename 'FILE\_NAME' to 'NEW\_FILE\_NAME': ERROR

Occurs when the operating system is unable to rename a file. Fatal.

# INCOMPATIBILITIES

There are no known incompatibilities.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

autodie, Carp, Const::Fast, English, List::SomeUtils, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, Role::Utils::Dn, strictures, Types::Standard,
version.

# AUTHOR

David Nebauer [mailto:david@nebauer.org](mailto:david@nebauer.org)

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer [mailto:david@nebauer.org](mailto:david@nebauer.org)

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
