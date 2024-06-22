# NAME

App::Dn::QkDeb - quick and dirty debianisation of files

# VERSION

This is documentation for App::Dn::QkDeb version 0.8.

# SYNOPSIS

    use App::Dn::QkDeb;

    App::Dn::QkDeb->new_with_options->run;

# DESCRIPTION

This script takes files and packages them into a deb. It will package script,
manpage, data, icon, desktop and configuration files. Only script and manpage
files are required. (Note: a manpage file is not required for a perl script --
the manpage file is generated from perlscript pod.)

By default all the package files created by the build process will be saved:
`deb`, `diff.gz`, `dsc` and `orig.tar.gz`. Neither source
package nor `.changes` file will be cryptographically signed. Use of
the '-d' option will result in only the `deb` file being saved.

For a script library package the requirements for script and manpages files are
relaxed -- specify the library scripts as data files. They will be installed to
`pkgdatadir`, e.g., on Debian systems `/usr/share/foo/`.

A script may need to reference the package name and files in certain standard
directories. The following aututools-style variables will be converted at
build-time:

> - _@__bin\_dir__@_
>
>     Directory for user executables. Default value in built deb package: `/usr/bin`.
>
> - _@__data\_dir__@_
>
>     Directory for read-only architecture-independent data files. Default value in
>     built deb package: `/usr/share`.
>
> - _@__desktop\_dir__@_
>
>     Directory for generic debian desktop files. Default value in built deb package:
>     `/usr/share/applications`. Note desktop files are not put into
>     application subdirectory -- be careful of filename clashes.
>
> - _@__icons\_dir__@_
>
>     Directory for generic debian icons. Default value in built deb package: `/usr/share/icons`. Note icons are not put into application subdirectory --
>     be careful of filename clashes.
>
> - _@__lib\_dir__@_
>
>     Root directory for hierarchy of libraries. Default value in built deb package:
>     `/usr/lib`.
>
> - _@__libexec\_dir__@_
>
>     Root directory for hierarchy of executables run by other executables, not
>     user. Default value in built deb package:
>     `/usr/libexec`.
>
> - _@__pkg__@_
>
>     Package name.
>
> - _@__pkgconf\_dir__@_
>
>     Directory for package configuration files. Default value in built deb package:
>     `/etc/foo`.
>
> - _@__pkgdata\_dir__@_
>
>     Directory for package read-only architecture-independent data files. Default
>     value in built deb package: `/usr/share/foo`.
>
> - _@__pkglib\_dir__@_
>
>     Directory for package executables run by other executables, not user, and
>     package libraries. Default value in built deb package:
>     `/usr/lib`.
>
> - _@__sbin\_dir__@_
>
>     Directory for superuser executables. Default value in built deb package: `/usr/sbin`.
>
> - _@__sysconf\_dir__@_
>
>     Directory for system configuration files. Default value in built deb package:
>     `/etc`.

# CONFIGURATION AND ENVIRONMENT

## Properties

None.

## Configuration files

A resources file in the build directory, called `deb-resources` by
default, provides details about the package to be built.

Each line of this file consists of a key-value pair. Only keys listed here will
be utilised. Any unrecognised key will halt processing. Some keys can be used
only once while others can be used multiple times.

Empty lines and comment lines (start with hash '#') will be ignored.

An annotated template resources file can be created by running this script with
the '-t' option.

What follows is a list of valid keys and descriptions of the values that can be
used with them.

> - _author_
>
>     Author of script.
>
>     Required. Multiple allowed.
>
> - _bash-completion_
>
>     Bash completion file. Results in build file
>     `source/PACKAGE.bash-completion`.
>
>     Optional. One only.
>
> - _bin-file_
>
>     User scripts and binary executables to package.
>
>     Required. Multiple allowed.
>
> - _conf-file_
>
>     Configuration files.
>
>     Optional. Multiple allowed.
>
> - _control-description_
>
>     Description of script. This is a longer description than the one line summary
>     and can stretch over multiple lines. Each line can be no longer than 60
>     characters. Each line must be the value in a separate name-value pair.
>     Paragraphs can be separated by a line consisting of a single period ('.'). This
>     description will be included in the package `control` file. This, in turn, is
>     displayed by many package managers.
>
>     Required. Multiple allowed.
>
>     \[Note: Knowledgable users may know the `control` file format requires all
>     descriptions lines be indented by one space. This space will be automatically
>     inserted when writing to the `control` file and does not need to be included
>     in the `deb-resources` file.\]
>
> - _control-summary_
>
>     One line summary of script for inclusion in the package <`control` file. This,
>     in turn, is displayed by many package managers.
>
>     Must be no longer than 60 characters.
>
>     Required. One only.
>
> - _data-file_
>
>     Data files to package.
>
>     Optional. Multiple allowed.
>
> - _debconf_
>
>     Debconf debian build file. In debian package is called
>     `PACKAGE.config`.
>
>     Optional. One only.
>
> - _depends-on_
>
>     The name of a single package this package depends on. Can include minimum
>     version.
>
>     Optional. Multiple allowed.
>
> - _desktop-file_
>
>     Desktop files to package.
>
>     Optional. Multiple allowed.
>
> - _email_
>
>     Email address of package maintainer.
>
>     Required. One only.
>
> - _extra-path_
>
>     Extra files and directories to be copied directly into the root of the
>     distribution. Directories are copied recursively. Used with key 'install-file'
>     to package files for arbitrary filesystem locations. See 'install-file' for an
>     example.
>
>     Optional. Multiple allowed.
>
> - _icon-file_
>
>     Icon files to package.
>
>     Optional. Multiple allowed.
>
> - _install-file_
>
>     Debian build install file. Results in build file `debian/PACKAGE.install`. On debian systems try `man dh_install` for more information on this file.
>
>     The install file can be used with the 'extra-path' key to install files to
>     arbitrary filesystem locations.
>
>     For example, assume the z-shell completion file is present in the build
>     directory as `contrib/completion/zsh/_my_script` and that it needs to
>     be installed into filesystems at `/usr/share/zsh/vendor-completions/`.
>     First, ensure it is copied into the intermediary autotools distribution with
>     the following entry in the resources file:
>
>         extra-path contrib
>
>     Next ensure it is packaged correctly by creating a file in the build directory
>     called, say, `my-install-file`, containing the following line:
>
>         contrib/completion/zsh/_my_script /usr/share/zsh/vendor-completions
>
>     Finally, add the following entry to the resources file:
>
>         install-file my-install-file
>
>     Optional. One only.
>
> - _libdata-file_
>
>     Data file used by other programs.
>
>     Optional. Multiple allowed.
>
> - _libexec-file_
>
>     Executable programs run by other programs.
>
>     Optional. Multiple allowed.
>
> - _man-file_
>
>     Man pages files to package.
>
>     Required. Multiple allowed.
>
> - _package-name_
>
>     Name of deb package to created. Usually the same as the primary script name.
>     Must not contain whitespace.
>
>     Required. One only.
>
> - _preinstall_
>
>     Preinstall debian build file. In final package is called
>     `PACKAGE.preinst`.
>
>     Optional. One only.
>
> - _prerm_
>
>     Preremove debian build file. In final package is called
>     `PACKAGE.prerm`.
>
>     Optional. One only.
>
> - _postinstall_
>
>     Postinstall debian build file. In final package is called
>     `PACKAGE.postinst`.
>
>     Optional. One only.
>
> - _postrm_
>
>     Postremove debian build file. In final package is called
>     `PACKAGE.postrm`.
>
>     Optional. One only.
>
> - _sbin-file_
>
>     Superuser scripts and binary executables to package.
>
>     Required. Multiple allowed.
>
> - _templates_
>
>     Templates debian build file. In final package is called
>     `PACKAGE.templates`.
>
>     Optional. One only.
>
> - _version_
>
>     Version number for package. Remember to increment it when rebuilding your
>     package. If your new package has the same version as the previous (installed)
>     version your package manager will not like it. An ugly hack would be to keep
>     the same version but always remove the existing package before installing the
>     new... but it sure is ugly.
>
>     Required. One only.
>
> - _year_
>
>     Year of copyright. Can be any year from 2000 to the current year.
>
>     Required. One only.

## Environment variables

None used.

# OPTIONS

- _-d_

    Produce a debian package (`.deb`) file only. Prevents creation of `diff.gz`, `dsc` and `orig.tar.gz` package files.

    Optional. Default: produce all package creation files.

- _-f_

    Show feedback from autotools commands. The default behaviour is to suppress
    this feedback.

    Optional. Default: false.

- _-i_

    Turn all errors arising from the contents of the resources file into warnings.
    That is, these errors will not halt package creation.  Warning: use this option
    with caution!

    Optional. Default: false.

- _-k_

    Keep the package's current version number. The user is not given an opportunity
    to enter a new version number.

    Optional. Default: false.

- _-l_

    Indicates the package is a library (specifically, executable scripts called by
    other scripts). Unlike "standard" packages, script and manpages files are not
    required while library script(s) are.

    Optional. Default: false.

- _-m_

    Prevent creation of manpage from main script pod, which normally occurs when
    there is a single script file that is perl script, and a single manpage file.

- _-n_

    Do not install built debian package.

- _-t_

    Create template resources file in the current directory. Will also create a
    simple git ignore file if one does not already exist.

    Optional. Default: false.

- _-h_

    Display help and exit.

# SUBROUTINES/METHODS

## run()

The only public method. It performs the package build.

# DIAGNOSTICS

## Unrecognised keyword 'WORD' at line number

Occurs when an unrecognised keyword is encountered in the
`deb-resources` file.

## Invalid path type '$type'

This is an internal script error. Contact the script author.

## Copy failed: ERROR
=head2 Unable to copy 'FILE'

Occurs when a system error prevents a file copy operation.

## Error processing extra path 'PATH'

An extra path is neither a file nor a directory.

## Unable to delete 'FILE/DIR'

A file or directory deletion operation failed.

## No distro file
=head2 Multiple distro files
=head2 Failed to copy 'DISTRO\_FILE' to deb parent dir
=head2 Cannot find distro in deb parent directory
=head2 Unable to parse 'DISTRO\_FILE'
=head2 Could not extract 'DISTRO\_FILE'

These errors can occur during processing of an intermediary distribution file.

## Could not find debian build directory
=head2 No filename provided
=head2 Cannot find debian subdirectory
=head2 Cannot find rules file

This are errors of debianisation.

## Multiple 'PATTERN' files generated
=head2 Did not generate 'PATTERN' file
=head2 Unable to copy 'FILE'

Errors that can occur when moving package files to the project directory.

## No debs found in 'PROJECT\_DIR'
=head2 Multiple debs found in 'PROJECT\_DIR'

Errors that can occur during installation of the built debian package.

## Unable to delete existing resource file

Occurs when a deletion operation on an existing `deb-resources` file
fails.

## Cannot build package without version number
=head2 Invalid version
=head2 New version cannot be lower than current version

Errors that can occur when the user is prompted to enter a new version number.

# INCOMPATIBILITIES

None reported.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

App::Dn::QkDeb::File, App::Dn::QkDeb::Path, Archive::Tar, autodie, Carp,
Const::Fast, Dpkg::Version, English, File::chdir, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, Pod::Man, strictures, Types::Dn::Debian,
Types::Dn, Types::Path::Tiny, Types::Standard, version.

# AUTHOR

David Nebauer <david@nebauer.org>

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer <david@nebauer.org>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
