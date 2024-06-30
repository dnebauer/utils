# NAME

App::Dn::NeedAlbumArt - find directories needing album cover art

# VERSION

This documentation is for `App::Dn::NeedAlbumArt` version 0.4.

# SYNOPSIS

    use App::Dn::NeedAlbumArt;
    App::Dn::NeedAlbumArt->new_with_options->run;

# DESCRIPTION

Search a directory recursively for subdirectories that need album
cover art. More specifically, it searches for subdirectories containing mp3
files but no album cover art file. An album cover art file is one named
`album.png`, `album.jpg`, `cover.png`, or `cover.png`.

If a directory is not specified, the current directory is searched.

The subdirectories matching these conditions are printed to stdout, one per
line.

# CONFIGURATION AND ENVIRONMENT

There is no configuration for this script.

# OPTIONS

## -d | --dir DIRPATH

Root directory of directory tree to analyse.
Scalar string directory path (must exist).
Optional. Default: current directory.

## -h | --help

Display help and exit.

# SUBROUTINES/METHODS

## run()

This is the only public method. It conducts the subdirectory search described
in [DESCRIPTION](https://metacpan.org/pod/DESCRIPTION).

# DIAGNOSTICS

## Invalid directory path: DIR

The specified directory cannot be located. Fatal.

# INCOMPATIBILITIES

There are no known incompatibilities.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

Carp, Const::Fast, English, File::Find::Rule, File::Spec, File::chdir,
List::SomeUtils, Moo, MooX::Options, namespace::clean, Path::Tiny, strictures,
Types::Path::Tiny, version.

# AUTHOR

David Nebauer [mailto:david@nebauer.org](mailto:david@nebauer.org)

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer [mailto:david@nebauer.org](mailto:david@nebauer.org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
