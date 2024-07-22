# NAME

App::TW::Select::Plugins - interactive filter for selecting plugins

# VERSION

This documentation is for `App::TW::Select::Plugins` version 0.5.

# SYNOPSIS

    use App::TW::Select::Plugins;
    App::TW::Select::Plugins->new_with_options->run;

# DESCRIPTION

In client-server [TiddlyWiki](https://tiddlywiki.com/) plugins are referred to
by the subdirectory path to plugin files within a plugins directory. The
customary practice is to use two levels of subdirectory:
`PLUGIN_AUTHOR/PLUGIN_NAME`.

This script is an interactive filter that accepts a newline-separated list of
enabled plugins via standard input. The user is then presented with a list box
containing all plugins in the specified plugins directories (the method of
plugins directory selection is discussed in ["Plugins directory selection"](#plugins-directory-selection)
below). The plugins provided via standard input are pre-selected. The user can
select additional plugins and deselect currently enabled plugins. When the user
presses the `Set!` button a newline-separated list of selected plugins is sent
to standard output.

If the user presses the `Abort` button the list of plugins received via
standard input is sent to standard output.

## Plugins directory selection

The script follows these steps to determine which plugins directories to use.

> - Supplied on command line
>
>     The script tries first to obtain plugins directories from command line options
>     (`-d` or `--plugins_directory`). If directories are provided via this method,
>     and at least one of them is valid, they are used.
>
> - Supplied by an environmental variable
>
>     If no plugins directories are provided on the command line, the script tries to
>     obtain them from the `$TIDDLYWIKI_PLUGIN_PATH` environmental variable. If at
>     least one valid directory is provided by this method, they are used.
>
> - Default directory
>
>     If no plugins directories are provided via either of the previous methods, the
>     script attempts to use the default server plugins directory used by the debian
>     `npm` install, `/usr/local/lib/node_modules/tiddlywiki/plugins/`, if it is
>     valid.

In all the methods above, if an invalid directory is detected but the script
proceeds, the user is warned of the missing directories via a gui message
dialog.

## Vim users

This script is intended for use with [vim](https://www.vim.org/) and vim clones
when editing a `tiddlywiki.info` file. You can follow these steps to change
the list of selected plugins:

- Perform a line-wise selection of the plugin list.
- Press the colon key. This causes the command line to display the selection
marks '<,'> which indicate the following command will apply to the selected
text.
- Type an exclamation point followed by the script name and any necessary
options. The command line will look something like:

        :'<,'>!tw-select-plugins -f "Terminus,18"

- Press Enter.

A listbox widget will be displayed for the user to alter which plugins are
selected. If the "Set!" button is pressed, the selected text in vim is replaced
with a list of the newly selected plugins.

If an error occurs the selected text in vim may be replaced with the error
output. If this occurs the change can be easily reversed with the undo command,
invoked in Normal mode with the `u` key.

## When no standard input is provided

If no standard input is provided when this script is invoked, it waits
indefinitely for standard input. Pressing `Ctrl-d` signals to the script that
standard input is complete and it will continue execution.

# CONFIGURATION AND ENVIRONMENT

## Standard input

This script is an interactive filter that accepts a newline-separated list of
enabled plugins via standard input. See ["DESCRIPTION"](#description) for more details.

## Properties/attributes

None.

## Options

### -d | plugins\_directory PATH

Server plugins directory.

If specifying multiple directories, use a separate `-d` option for each.

If no directories are provided by the user with this option, the script will
attempt to use any directories specified with the environmental variable
`$TIDDLYWIKI_PLUGIN_PATH`. If no directories are provided by command line
option or environmental variable, the script will use the debian default plugin
location of `/usr/local/lib/node_modules/tiddlywiki/plugins/` if it exists.

Path. Optional. Default: \[see discussion above\].

### -f | --font FONT

Font name and size. Format as a single string like "font,size" with a comma
separating the elements and no extra spaces.

Note: the script does not check the validity of this option value. A
non-existent font name is ignored, while a non-numeric size causes a fatal
error.

String. Optional. Default: "LucidaSans,18".

### -i | --indent INDENT

Size of indent used in output.

Integer. Optional. Default: 8. Negative values are silently ignored.

### -h | --help

Display help and exit. Flag. Optional. Default: false.

## Configuration files

None used.

## Environment variables

### TIDDLYWIKI\_PLUGIN\_PATH

If no plugins directories are provided on the command line, the script tries to
obtain them from the `$TIDDLYWIKI_PLUGIN_PATH` environmental variable. If at
least one valid directory is provided by this method, they are used.

# SUBROUTINES/METHODS

## run()

The only public method. It runs an interactive filter for selecting plugins as
described in ["DESCRIPTION"](#description).

# DIAGNOSTICS

## Errors (fatal)

### '...' isn't numeric at /PATH/TO/Tk/Widget.pm line 205

This error occurs when a non-numeric font size is provided. For example,
passing the value "Terminus,JK" to the `--font` option will result in an error
like:

    'JK' isn't numeric at
    /usr/lib/x86_64-linux-gnu/perl5/5.28/Tk/Widget.pm
    line 205

### Cannot locate default plugin directory '...'

This script tries first to obtain plugin directories from command line options.
If none are provided, the script tries to obtain them from the
`$TIDDLYWIKI_PLUGIN_PATH` environmental variable. If no directories are
provided via either of these methods, the script attempts to use the default
server plugin directory used by the debian `npm` install:
`/usr/local/lib/node_modules/tiddlywiki/plugins/`. This error occurs if that
directory is unavailable.

### Directory PATH does not exist

This error occurs when an invalid directory path is supplied to the
`--plugins_directory` option.

### Expected 1 plugin directory, got INT

This error occurs if multiple directory paths are provided using multiple `-d`
(`--plugins_directory`) options.

### Expected 1 font, got INT

This error occurs if multiple fonts are provided using multiple `-f`
(`--font`) options.

### Expected 1 indent, got INT

This error occurs if multiple indent values are provided using multiple `-i`
(`--indent`) options.

### Invalid user-provided plugin directories: PATH\[, PATH...\]

This script tries first to obtain plugin directories from command line option
`-d` (`--plugins_directory`). This error occurs if all directories provided
by this method are invalid.

### Invalid var-provided plugin directories: PATH\[, PATH...\]

This script tries first to obtain plugin directories from command line options.
If none are provided, the script tries to obtain them from the
`$TIDDLYWIKI_PLUGIN_PATH` environmental variable. This error occurs if all
directories in that environmental variable are invalid.

### No plugins found in PATH

This error occurs when no subdirectories are found in the specified (or
default) server plugin directory. This is a fatal error because the server
plugin directory must contain tiddlywiki core plugins.

### Option d requires an argument

This error occurs when no value is provided to the `-d`
(`--plugins_directory`) option.

### Option f requires an argument

This error occurs when no value is provided to the `-f` (`--font`) option.

### Option i requires an argument

This error occurs when no value is provided to the `-i` (`--indent`) option.

### Unable to write to console

This error occurs when the script is unable to write to the terminal.

### Unrecognised OS type '...'

This error occurs if the script is checking the contents of the
`$TIDDLYWIKI_PLUGIN_PATH` (which occurs only if the user provides no plugin
directories via the command line option `-d`). To interpret this variable it
is necessary to know the path delimiter used, which varies by operating system.
The script relies on [Perl::OSType](https://metacpan.org/pod/Perl%3A%3AOSType) to determine the operating system, and
this module can report only whether the operating system is a type of Windows
or a type of Unix (which use semicolons and colons as path delimiters,
respectively). This error occurs if the [Perl::OSType](https://metacpan.org/pod/Perl%3A%3AOSType) module does not report
the operating system as being of either Windows or Unix type.

### Value "..." invalid for option i (number expected)

This error occurs when a non-numeric value is used for the `-i` (`--indent`)
option.

## Warnings (non-fatal)

### Could not locate all plugins directories supplied on the command lines

One or more of the plugins directories provided via the `-d`
(`--plugins_directory`) option is invalid (but at least one valid directory
has been provided). This message is followed by a list of the invalid
directories.

### Could not locate all plugin directories defined in $TIDDLYWIKI\_PLUGIN\_PATH

This warning is displayed when invalid directories are specified in the
$TIDDLYWIKI\_PLUGIN\_PATH variable (but the variable includes at least one valid
directory). The warning message is followed by a list of the invalid
directories.

### Not all currently selected plugins have been found in server directories

This warning is displayed when at least one plugin subdirectory provided via
standard input is not found in any of the specified plugins directories. This
may be caused by a misspelled plugin directory, obsolete plugin name, or
failing to specify the correct plugins directories.

The warning is followed by a list of the plugin subdirectories that could not
be located.

# INCOMPATIBILITIES

There are no known incompatibilities.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

## Perl modules

Carp, Const::Fast, Env, File::Find::Rule, List::SomeUtils, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Perl::OSType, strictures,
Tk, Tk::ErrorDialog, Types::Path::Tiny, Types::Standard, version.

# AUTHOR

David Nebauer <david@nebauer.org>

# LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer <david@nebauer.org>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
