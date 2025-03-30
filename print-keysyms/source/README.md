# NAME

App::Dn::PrintKeysyms - print keysyms in terminal

# VERSION

This documentation applies to App::Dn::PrintKeysyms version 0.1.

# SYNOPSIS

    use App::Dn::PrintKeysyms;
    App::Dn::PrintKeysyms->new_with_options->run;

# DESCRIPTION

When invoked in a terminal the user can press keys and their corresponding
keysyms are printed to the terminal.

To close it give focus to the terminal and press `Ctrl+c`.

The class part of the X11 WM\_CLASS property for the displayed widget is set to
"Perl/Tk widget".

# SUBROUTINES/METHODS

## run()

The only public method. This method enables printing keysyms as described in
"DESCRIPTION".

# DIAGNOSTICS

No warning or error messages are emitted by this script.

_Subsidiary modules may do so._

# INCOMPATIBILITIES

There are no known incompatibilities.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# DEPENDENCIES

Carp, Moo, MooX::Options, namespace::clean, strictures, Tk, version.

# AUTHOR

[David Nebauer](mailto:david@nebauer.org)

# LICENSE AND COPYRIGHT

Copyright (c) 2025 [David Nebauer](mailto:david@nebauer.org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
