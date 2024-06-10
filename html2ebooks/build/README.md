# NAME

App::Dn::Html2Ebooks - convert html file to ebook formats

# VERSION

This documentation is for App::Dn::Html2Ebooks version 0.6.

# SYNOPSIS

**dn-html2ebooks** **-b** _--file\_base\_name_ **-t** _book\_title_ **-a** _book\_author_

**dn-html2ebooks -h**

# DESCRIPTION

Converts an html file in the current directory named `basename.html` or
`basename.htm` where "basename" is the option provided to the `-b` option.
This source file is converted to the following format and output file:

- Electronic publication (`basename.epub`)
- Kindle Format 8 (`basename.epub`)

Output files are written to the current directory and silently overwrite any
existing output files of the same name.

If there is a png image file in the current directory called `basename.png` it
will be used as a cover image for the ebooks.

The conversions are performed by `ebook-convert`, part of the Calibre suite on
debian systems.

# SUBROUTINES/METHODS

## run()

This is the only module method. It converts the specified html file as
described in ["DESCRIPTION"](#description).

# CONFIGURATION AND ENVIRONMENT

## Properties

### file\_base\_name

Basename (file name without extension) of source html file.

### book\_title

Title of book. Enclose in quotes if it contains spaces.

### book\_author

Author (or authors) of book. Enclose in quotes if it contains spaces.

## Configuration

This module does not use configuration files.

## Environment

This module does not use environmental variables.

# INCOMPATIBILITIES

There are no known incompatibilities with other modules.

# DIAGNOSTICS

## Can't find source file 'BASENAME.htm\[l\]'

Occurs when an invalid file base name has been provided.

## Cannot locate ebook converter 'CONVERTER'

Occurs when the script is unable to locate `ebook-convert` on the system.

# DEPENDENCIES

## Perl modules

App::Dn::Html2Ebooks::Format, Carp, Const::Fast, Moo, MooX::HandlesVia,
namespace::clean, Path::Tiny, strictures, Types::Standard, version.

## Executables

ebook-convert.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# AUTHOR

David Nebauer (david at nebauer dot org)

# LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
