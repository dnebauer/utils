# NAME

App::Dn::Id3v2CreateScript - converts id3v2 output to a script

# VERSION

This documentation is for App::Dn::Id3v2CreateScript version 0.6.

# SYNOPSIS

    my app = App::Dn::Id3v2CreateScript->new(
        id3v2_output_file => $input_file,
        bash_script => $output_file,
    );

# DESCRIPTION

Convert id3v2 output (created using the `--list` option) to a bash script. The
bash script contains an `id3v2` command for each mp3 file which sets its tags
to those present in the initial output. Any id3v1 tag information in the input
is ignored. The id3v2 output can be provided to this script as stdin (default)
or as a file. The bash script output produced can be sent to stdout (default)
or to a file. If output is sent to a file the created file is set to executable
(permissions 0755).

This may seem to be a pointless script: when would it ever be necessary to set
mp3 file tags to the values they already have? One applicable scenario, and the
impetus for this script, is that on some occasions the id3v2 utility is unable
to modify existing tags on some mp3 files. In those cases it is necessary to
remove all tags and set them anew.

Warning: for any mp3 files containing an album image the image is extracted to
the same directory as the mp3 file.  The image file has the same base name as
the mp3 file, with an extension determined by the image format (e.g.,
`.jpeg`).  Existing image files with the same name and extensions are silently
overwritten. An extra `eyeD3` command is added to the script file for each
image file generated. This command adds the image to the mp3 file.

# CONFIGURATION AND ENVIRONMENT

## Properties

### id3v2\_output\_file

Path to input file containing id3v2 output. Scalar string.

### bash\_script

Path to bash script output file. Scalar string.

## Configuration files

None used.

## Environment variables

None used.

# SUBROUTINES/METHODS

## run()

Main method. Creates bash script output file from input file containing id3v2
output.

# DIAGNOSTICS

## Cannot extract COMM value from: FILEPATH

This error occurs when a comment (COMM tag) line is detected but the regular
expression matcher is unable to match the comment text.

## Cannot extract TAG value from: FILEPATH

This error occurs when a id3v2 tag line (a tag other than APIC or COMM) is
detected but the regular expression matcher is unable to match the tag content.

## Cannot find file 'FILEPATH'

This error occurs when an invalid input filepath is provided.

## Cannot write 'FILEPATH': OS\_ERROR

This error occurs when the script is unable to write its script output to a
file.

## Couldn't read tags: FILEPATH

This error occurs when attempting to extract an image from an mp3 file. It
occurs because the [MP3::Tag](https://metacpan.org/pod/MP3%3A%3ATag) module does not extract any tags from the mp3
file.

## Invalid mp3 file path: FILEPATH

This error occurs when attempting to extract an image from an mp3 file. It
occurs because the derived file path is invalid. If this error occurs it
indicates problem with the script design.

## No artwork data found: FILEPATH

This warning is issued if the script detects an APIC tag but is unable to
extract image data using the [MP3::Tag](https://metacpan.org/pod/MP3%3A%3ATag) module.

## No ID3v2 tags: FILEPATH

This error occurs when attempting to extract an image from an mp3 file. It
occurs because the [MP3::Tag](https://metacpan.org/pod/MP3%3A%3ATag) module does not extract any id3v2 tags from the
mp3 file.

## Unable to extract file path

The id3v2 output line signifying the start of id3v2 tag data has the format:

    id3v2 tag info for FILEPATH:

This script extracts the filepath from this line. It generates this error if
the regular expression matcher is unable to match the filepath.

## Unable to set 'FILEPATH' executable

After the script file is generated (if the `-o` option is used) it is set to
the permissions 0755, i.e., executable. This error occurs if that operation
fails.

# DEPENDENCIES

## Perl modules

App::Dn::Id3v2CreateScript::FileProperties,
App::Dn::Id3v2CreateScript::TagProperties, autodie, Carp, charnames,
Const::Fast, English, File::Basename, List::SomeUtils, MP3::Tag, Moo,
MooX::HandlesVia, Path::Tiny, namespace::clean, strictures, Types::Standard,
version.

## Executables

eyeD3, id3v2.

# CONFIGURATION

There is no configuration file and no configuration settings.

# INCOMPATIBILITIES

There are no known incompatibilities.

# EXIT STATUS

The script exits with a zero value if successful and a non-zero value if a
fatal error occurs.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# AUTHOR

David Nebauer (david at nebauer dot org)

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
