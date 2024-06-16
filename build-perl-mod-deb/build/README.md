# NAME

App::Dn::BuildModule - build a debian package

# VERSION

This documentation describes App::Dn::BuildModule version 0.10.0.

# SYNOPSIS

    my $app = App::Dn::BuildModule->new(email => $maint_email);
    $app->run;

# DESCRIPTION

## Preparation

This script assumes the following directory structure:

    |
    `-- project-directory
        |-- build
        `-- source
            `-- required

The modules's source files and subdirectories are in the `source` directory.
In addition to the module files the `source` directory has an additional
subdirectory: `required`.

This script assumes the following build process has been followed at least
once:

- Install module source in the `source` directory. This may invove a command
sequence like:

        $ cd path/to/project-directory/source

        $ cpan -g The::Module
        Checking The::Module
        CPAN: Storable loaded ok (v2.49_01)
        Reading '/home/david/.cpan/Metadata'
          Database was generated on Sat, 09 May 2015 12:29:02 GMT

        $ dir
        TheModule-1.23.tar.gz

        $ tar zxvf TheModule-1.23.tar.gz
        TheModule-1.23/
        TheModule-1.23/META.yml
        ...

        $ mv TheModule-1.23/* ./

        $ rmdir TheModule-1.23

        $ rm TheModule-1.23.tar.gz

- Create `required` subdirectory:

        $ cd path/to/source
        $ mkdir required

- Add executable scripts

    Scripts to be installed to `/usr/bin/` are put in
    `source/script`. This directory needs to be created. The scripts are
    not set as executable in this directory; that is handled during packaging.

- Add bash completion script

    `dn-build-perl-mod-deb` provides support for a single bash completion
    file. The file must be called `PACKAGE.bash-completion` where 'PACKAGE'
    is the name of the debian package to be created. For example, the perl module
    `My::Module` may be packaged as `libmy-module-perl`. If
    executable scripts are included in the package, the accompanying bash
    completion file in the source tree would be
    `source/required/libmy-module-perl.bash-completion`, and would install
    to `/usr/share/bash-completion/completions/libmy-module-perl`.

- Add files for installation to other directories

    There is a mechanism for installing files to any system location. The files
    must be installed under the `source` directory in any subdirectory path. It is
    a convention to install files under `source/contrib`. For example, a
    zsh completion script may be located at `source/contrib/completion/zsh/_my-script` in the source tree. The install
    destination is specified in `source/required/PACKAGE.install` where
    PACKAGE is the debian package name. Each file to be installed must be listed in
    this file with a destination directory. Here is the line that might be used for
    the zsh completion file mentioned above:

        contrib/completion/zsh/_my-script /usr/share/zsh/vendor-completions

    The location of the source file, relative to the `source` directory, is given
    first, followed by the destination directory. Note that the destination does
    not include the file name as it uses the name of the source file.

- Copy all source files to `build` directory:

        $ cd ../build
        $ cp -r ../source/. ./

    Note the use of `../source/.` rather than the more usual `../source/*`. This ensures hidden files and directories are copied as
    well. This is important in some cases where failure to copy hidden files
    results in `milla test` and `milla build` failing because it
    cannot find the distribution.

- Build distribution file. Supported build methods are:
    - Dist::Milla (relies on detecting a `dist.ini` file in the project root
    directory)

            $ prove -l t
            $ milla test
            $ milla build

    - ExtUtils::MakeMaker (relies on detecting a `Makefile.PL` file in the
    project root directory)

            $ perl Makefile.PL
            $ make test
            $ make dist

    - Module::Build (relies on detecting a `Build.PL` file in the root
    directory)

            $ perl Build.PL
            $ ./Build
            $ ./Build test
            $ ./Build dist

    - Extract the distribution file, creating a subdirectory containing a copy of the
    distribution files:

            $ tar zxvf TheModule-1.23.tar.gz

        Note: the Dist::Milla build process results in the creation of a subdirectory
        of this name being built, so that subdirectory must be deleted before
        `tar zxvf` is run.

    - Create debian package build files using `dh-make-perl`:

            $ dh-make-perl TheModule-1.23

        This command may fail if module dependencies are not met. Install any required
        modules before proceeding.

    - Perform initial build of debian package using `debuild`:

            $ cd TheModule-1.23
            $ debuild

        Note that this operation is performed from the module directory.

    - The initial buld operation will generate a number of lintian warnings. These
    require changes to the `control`, `copyright` and `changelog` files in the
    debian subdirectory. These are copied to the `build` directory's `required`
    subdirectory:

            $ for x in control copyright changelog ; do \
              cp debian/${x} ../required/ ; done

        or use `mc` to copy them manually:

            $ mc debian/ ../required/

        These files are then edited to remove the warnings.

        The commonest warnings are fixed with the following:

        - The last two lines of the `control` file are autogenerated content and need to
        be removed
        - The `copyright` file contains an autogenerated disclaimer, usually beginning
        around line 5, that needs to be removed.
        - The `changelog` file needs the details of the initial change altered to
        something like:

                * Local package
                * Initial release
                * Closes: 2001

        Of course, make any additional alterations to these files to fix additional
        lintian warnings and to ensure they are correct and complete.

        When these files have been fixed, copy them back to the debian subdirectory:

            cp ../required/* debian/

        Also copy them to the `source/required` subdirectory so they are
        included in the next build sequence.

    - Repeat the previous step until no lintian warnings appear during the package
    build.

## Use of this script

Once the initial build has been performed, this script is run from the
`source` directory. It performs the following tasks:

- Copies the directory contents to sibling directory `build`
- Builds a distribution
- Extracts the distribution into its subdirectory
- Runs `dh-make-perl` on the extracted module source
- Changes to the extracted module directory and runs `debuild`
- Copies all files in the `build/required` directory to the module's
`debian` directory
- Installs the created package.

# SUBROUTINES/METHODS

## run()

Builds a debian package from a module (or set of modules) in a build
environment as specified in ["DESCRIPTION"](#description).

# CONFIGURATION AND ENVIRONMENT

## Properties

### email

Debian package maintainer email.

Scalar. Optional. Default: <david@nebauer.org>.

### no\_builddeps

`debuild` default behaviour is to run `dpkg-checkbuilddeps` to check
build dependencies and conflicts. Sometimes this check will declare that a
locally installed module is an unmet dependency even if a suitable version of
it is correctly installed.

If this attribute is set to true then this script runs `debuild` with its
`-d` option, which prevents it running `dpkg-checkbuilddeps`.
This solves the immediate problem of the failed dependency check, but be aware
it may obscure other build problems.

Boolean. Optional. Default: false.

### no\_install

Suppress installation of debian package after it is built.

Boolean. Optional. Default: false.

## Configuration files

None used.

## Environment variables

None used.

# DIAGNOSTICS

## No Makefile.PL, Build.PL or dist.ini found

Occurs if script cannot find evidence of a supported build system.

## Cannot locate source directory 'DIR'

## Cannot locate build directory 'DIR'

## Copy of source to build directory failed with error: ERROR

These errors occur when the script is unable to recursively copy the contents
of the `source` directory to the `build` directory.

## Cannot locate changelog 'PATH'

Occurs when the script is unable to locate the `changelog` file in the
`debian` subdirectory of the source distribution base directory.

## Unable to open FILE: ERROR

## Unable to close FILE: ERROR

These errors occur when the script is unable to open or close a disk file. The
files this script attempts to access in this way are the `changelog` and
`rules` debian control files.

## No file provided

## Unable to extract module name and version from distribution file

## Multiple distribution files detected ...

Occurs when the script attempts to locate a source distribution file after the
initial build process. It indicate that no file matching the supported build
processes was found, or that multiple matching files were found.

## Cannot construct module debian directory pathname

## Cannot construct module directory pathname

Occurs when the script is unable to derive the name of the extracted source
distribution base directory.

## Unable to extract package name

Occurs when the script is unable to extract the package name from the
`changelog` debian control file.

## Cannot find rules file

Occurs when the script is unable to locate the `rules` debian control file.

## Unable to write to FILE: ERROR

Occurs if the script is unable to write to a disk file. This can occur with the
`rules` debian control file.

## Copy of required debian files failed

Occurs when attempting to copy required debian control files from
`build/required/` to `build/DIST_SOURCE_BASE/debian`.

## Unable to find built deb file

## Multiple distribution files detected: ...

These errors occur when attempting to locate the debian package file built by
the script.

# INCOMPATIBILITIES

None known.

# BUGS AND LIMITATIONS

No bugs have been reported.

# DEPENDENCIES

## Perl modules

App::Dn::BuildModule::Constants, App::Dn::BuildModule::DistroArchive,
App::Dn::BuildModule::DistroFile, Carp, Const::Fast, English, File::Basename,
File::chdir, File::Copy::Recursive, File::DirSync, Git::Wrapper, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Path::Tiny,
Role::Utils::Dn, strictures, Types::Dn, Types::Path::Tiny, Types::Standard,
version.

## Executables

debuild, dh-make-perl, make, milla, prove, tar.

## Debian packaging

The executable 'milla' is part of the Dist::Milla perl module, but that module
is not available from standard debian repositories.

# LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Copyright 2024, David Nebauer

# AUTHOR

David Nebauer <david@nebauer.org>
