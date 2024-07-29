# NAME

App::Dn::UpdateContextMaillist - updates local copy of ntg-context mailing list

# VERSION

This documentation is for `App::Dn::UpdateContextMaillist` version 0.7.

# SYNOPSIS

    use App::Dn::UpdateContextMaillist;

    App::Dn::UpdateContextMaillist->new_with_options->run;

# DESCRIPTION

Download the ntg\_context mailing list archive for the current year. (If
performing the first update of the year, also do a final update of the previous
year.)

Uses the `Dn::MboxenSplit` module to extract individual emails and writes to
`~/data/computing/text-processing/context/mail-list/` an mbox file for every
email message which is not already captured in the directory.

Displays feedback on screen unless the `-l` option is used, in which case the
result (and any errors or warnings) are written to the system log.

# CONFIGURATION AND ENVIRONMENT

## Options

### -l | --log

Log output rather than display on screen. Note that the Dn::MboxenSplit module
will display some screen output regardless of this option.

Flag. Optional. Default: false.

### -h | --help

Display help and exit.

## Properties/attributes

There are no public attributes.

## Configuration files

Uses a configuration file to save the year of the most recent update. When
running the script looks in turn for the configuration files:

- `~/.config/dn-update-context-maillist.conf`
- `~/.dn-update-context-maillistrc`

and uses the first one it finds.

If neither configuration file exists, it will create
`~/.config/dn-update-context-maillist.conf` if the `~/.config` directory
exists, otherwise it creates `~/.dn-update-context-maillistrc`.

## Environment variables

None used.

# SUBROUTINES/METHODS

## run()

This is the only public method. It updates a local copy of ntg-context mailing
list as described in ["DESCRIPTION"](#description).

# DIAGNOSTICS

## Can't create config file 'FILE'

Occurs when the system is unable to create the configuration file.

## Invalid type 'TYPE'

Occurs when attempting to write a log message with an invalid type.
Valid types are: EMERG ALERT CRIT ERR WARNING NOTICE INFO DEBUG.

# INCOMPATIBILITIES

There are no known incomptibilities.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

Config::Tiny, Const::Fast, Dn::MboxenSplit, English, File::Basename,
File::HomeDir, File::Spec, File::Temp, File::Touch, File::Util,
IO::Interactive, LWP::Simple, Moo, MooX::HandlesVia, MooX::Options,
namespace::clean, Role::Utils::Dn, strictures, Sys::Syslog, Types::Standard,
version.

# AUTHOR

David Nebauer <david@nebauer.org>

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer <david@nebauer.org>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
