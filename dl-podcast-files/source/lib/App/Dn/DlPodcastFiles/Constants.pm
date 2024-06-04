package App::Dn::DlPodcastFiles::Constants;

# modules
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use namespace::clean;
use version; our $VERSION = qv('0.4');

# constants

our $DASH = q{-};

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::DlPodcastFiles::Constants - provide constants to parent/sibling modules

=head1 VERSION

This documentation is for App::Dn::DlPodcastFiles::Constants version 0.4.

=head1 SYNOPSIS

    use App::Dn::DlPodcastFiles::Constants;
    ...
    my $var = $self->method($App::Dn::DlPodcastFiles::Constants::DASH);

=head1 DESCRIPTION

Provides constants for the App::Dn::DlPodcastFiles module and its child
modules.

=head1 SUBROUTINES/METHODS

None used.

=head1 DIAGNOSTICS

This module emits no custom error messages.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

This module has no properties/attributes.

=head2 Configuration

This module uses no configuration files.

=head2 Environment

This module uses no environmental veriables.

=head1 DEPENDENCIES

=head2 Perl modules

Moo, namespace::clean, strictures, version.

=head1 INCOMPATIBILITIES

There are no known incompatibilities with other modules.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:

