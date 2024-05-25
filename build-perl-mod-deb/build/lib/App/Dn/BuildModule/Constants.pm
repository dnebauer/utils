package App::Dn::BuildModule::Constants;

# modules
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use namespace::clean;
use version; our $VERSION = qv('0.10.0');

# constants

our $FILE_TOKEN = '::FILE::';

1;

# POD

__END__

=head1 NAME

App::Dn::BuildModule::Constants - utility module for App::Dn::BuildModule

=head1 VERSION

This documentation refers to App::Dn::BuildModule::Constants version 0.10.0.

=head1 SYNOPSIS

    package My::Module;
    use Moo;
    use App::Dn::BuildModule::Constants;
    # ...
    if ($part eq $App::Dn::BuildModule::Constants::FILE_TOKEN) {
    # ...


=head1 DESCRIPTION

Utility module providing constant values to ensure uniformity across
multiple modules.

Currently available constant values:

=over

=item $FILE_TOKEN

=back

=head1 ATTRIBUTES

None provided.

=head1 SUBROUTINES/METHODS

None provided.

=head1 DIAGNOSTICS

This module does not emit custom warning or error messages.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

Moo, namespace::clean, strictures, version.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.
If you discover any, please report them to the author.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
