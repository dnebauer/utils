package App::Dn::PrintKeysyms;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.1');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Tk;
use MooX::Options (
  authors      => 'David Nebauer <david at nebauer dot org>',
  description  => 'Print keysyms to the terminal',
  protect_argv => 0,
);    #     }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {

  my $mw = MainWindow->new(-class => 'Perl/Tk widget');

  # tk implicitly passes the bound widget reference as the first argument
  # to the anonymous sub in the binding
  $mw->bind(
    '<KeyPress>' => [
      sub {
        my ($widget) = @_;
        my $e = $widget->XEvent;           # get event object
        my ($keysym_text, $keysym_decimal) = ($e->K, $e->N);
        print "keysym=$keysym_text, numeric=$keysym_decimal\n" or croak;
        return;
      }
    ]
  );

  MainLoop;

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::PrintKeysyms - print keysyms in terminal

=head1 VERSION

This documentation applies to L<App::Dn::PrintKeysyms> version 0.1.

=head1 SYNOPSIS

  use App::Dn::PrintKeysyms;
  App::Dn::PrintKeysyms->new_with_options->run;

=head1 DESCRIPTION

When invoked in a terminal the user can press keys and their corresponding
keysyms are printed to the terminal.

To close it give focus to the terminal and press C<Ctrl+c>.

The class part of the X11 WM_CLASS property for the displayed widget is set to
"Perl/Tk widget".

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. This method enables printing keysyms as described in
L</DESCRIPTION>.

=head1 DIAGNOSTICS

No warning or error messages are emitted by this module.

I<Subsidiary modules may do so.>

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Moo, MooX::Options, namespace::clean, strictures, Tk, version.

=head1 AUTHOR

L<David Nebauer|mailto:david@nebauer.org>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2025 L<David Nebauer|mailto:david@nebauer.org>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
