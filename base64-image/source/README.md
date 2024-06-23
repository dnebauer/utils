# NAME

App::Dn::Base64Image - provide data uri for an image

# VERSION

This documentation applies to App::Dn::Base64Image version 0.2.

# SYNOPSIS

    use App::Dn::Base64Image;

    App::Dn::Base64Image->new_with_options->run;

# DESCRIPTION

Create html element 'img' for an image using data uri with base64 encoding.
Encoded data is printed to stdout.

# CONFIGURATION AND ENVIRONMENT

## Properties

None.

## Configuration files

None used.

### Environment variables

None used.

# OPTIONS

- **-f** | **--image\_file** image\_file

    Image to convert. Filepath (must exist).

    Required.

- **-m** | **--mime\_type** mime\_type

    Override autodetected image mime type.

    Optional. Default: false.

- **-h**

    Display help and exit.

# SUBROUTINES/METHODS

This is the only public method. It writes the html element to stdout.

# DIAGNOSTICS

## Invalid file path: FILEPATH

Occurs when an invalid image file path has been provided.

## Unable to determine image file mime type

Occurs when the module [File::MimeInfo](https://metacpan.org/pod/File%3A%3AMimeInfo) is unable to determine the mime type
of the image file.

## Unable to encode image file

Occurs when the module [MIME::Base64](https://metacpan.org/pod/MIME%3A%3ABase64) is unable to encode the raw content of
the image file as &lt;base 64.

# INCOMPATIBILITIES

None known.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

autodie, Carp, Const::Fast, File::MimeInfo, MIME::Base64, Moo, MooX::Options,
namespace::clean, Path::Tiny, strictures, Types::Standard, version.

# AUTHOR

David Nebauer <david@nebauer.org>

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer <david@nebauer.org>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
