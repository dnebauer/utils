# NAME

App::Dn::DlPodcastFiles - download podcast files

# VERSION

This documentation is for App::Dn::DlPodcastFiles version 0.4.

# SYNOPSIS

    use App::Dn::DlPodcastFiles;

# DESCRIPTION

App::Dn::DlPodcastFiles was developed for downloading podcast files that are
too old to appear in a podcast feed but that are still included in the rss feed
file online. Details of the files are obtained and a yaml import file created.

The import file lists the following for each download file:

    url, title, date, time

Date and time are the date and time the file was published.

Required values are url, title and time. Date is optional.

Here is an example import file. It lists episodes from the "Fear the Boot"
podcast.

    ---
    url: http://media.libsyn.com/media/feartheboot/feartheboot_0001.mp3
    title: Episode 1 - when player abilities eclipse character abilities
    date: 2006-05-15
    time: 2230
    ---
    url: http://media.libsyn.com/media/feartheboot/feartheboot_0002.mp3
    title: Episode 2 - creating a group template
    date: 2006-05-23
    time: 0611
    ---
    url: http://media.libsyn.com/media/feartheboot/feartheboot_0003.mp3
    title: Episode 3 - character creation
    date: 2006-05-30
    time: 0836

The downloaded file name consists of the url filename with a prefix constructed
from the episode's date and, if provided, time. Here are the download files
corresponding to the import file shown above:

    20060515-2230_feartheboot_0001.mp3
    20060523-0611_feartheboot_0002.mp3
    20060530-0836_feartheboot_0003.mp3

# SUBROUTINES/METHODS

## run()

The module's main (and only) method. It reads the import file and downloads
podcast files.

# CONFIGURATION AND ENVIRONMENT

## Properties

### import\_file

YAML import file. See ["DESCRIPTION"](#description) for the file format.

## Configuration

This module does not use a configuration file.

## Environment

This module does not use environment variables.

# DIAGNOSTICS

## Cannot find 'FILE'

Occurs when the specified YAML import file cannot be found.

## Download failed

A podcast file could not be downloaded from the internet.

## No episode details were extracted from file 'FILE' data

No podcast episode details could be extracted from the data extracted from the
YAML import file.

## No episodes were imported from file FILE

After parsing the YAML import file no data could be extracted.

## No import file specified

Occurs when no YAML import file is specified.

## Unable to rename 'OLD' to 'NEW'

After downloading a podcast file it could not be renamed.

# INCOMPATIBILITIES

None known.

# BUGS AND LIMITATIONS

None known. Please report any to the module author.

# DEPENDENCIES

autodie, Carp, Const::Fast, English, File::Copy, File::Fetch, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Role::Utils::Dn, strictures,
Types::Standard, version, YAML.

# AUTHOR

David Nebauer <david@nebauer.org>

# COPYRIGHT

Copyright 2024- David Nebauer

# LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
