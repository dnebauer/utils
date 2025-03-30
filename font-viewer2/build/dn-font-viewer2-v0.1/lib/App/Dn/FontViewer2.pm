package App::Dn::FontViewer2;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.1');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Const::Fast;
use Tk;
use Tk::FontDialog;
use MooX::Options (
  authors      => 'David Nebauer <david at nebauer dot org>',
  description  => 'View font appearance',
  protect_argv => 0,
);    #     }}}1

# constants    {{{1
const my $INITFONT => 'Times New Roman';    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {

  # top level widget
  my $mw = MainWindow->new(
    -title => 'Font Viewer',
    -class => 'Perl/Tk widget',
  );

  # actions

  # • Escape, q, Q
  for my $key ('Escape', 'q', 'Q') {
    $mw->bind(
      "<KeyRelease-$key>" => sub {
        if (Tk::Exists($mw)) { $mw->destroy; }
        return;
      }
    );
  }

  # interface elements

  my %opts = (-initfont => "{$INITFONT} 24");
  my $font = $mw->FontDialog(%opts)->Show;
  if (defined $font) {
    my $font_descriptive = $mw->GetDescriptiveFontName($font);
    say $font_descriptive or croak;
  }

  # activate interface
  MainLoop;

  return;
}

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::FontViewer2 - view font appearance

=head1 VERSION

This documentation applies to L<App::Dn::FontViewer2> version 0.1.

=head1 SYNOPSIS

  use App::Dn::FontViewer2;
  App::Dn::FontViewer2->new_with_options->run;

=head1 DESCRIPTION

Invokes a font viewer that enables the user to view the effect of changing the
following font attributes:

=over

=item *

family

=item *

size

=item *

bolding

=item *

italicising

=item *

underlining

=item *

overstriking (aka strikethough).

=back

but noting that at the time of writing the underlining and overstriking
attributes have no effect on font appearance.

Two widgets are displayed: an empty MainWindow and a Tk::FontDialog.
The font dialog is closed by pressing the C<OK> or C<Cancel> buttons.
The main window is closed by pressing the C<Escape> or C<q> keys.

The class part of the X11 WM_CLASS property for the displayed main window is
set to "Perl/Tk widget".
For the font dialog the X11 WM_CLASS property is set to "FontDialog" while the
WM_INSTANCE property is set to "fontdialog".

For a viewer that does not use a pre-defined font dialog see the
S<< F<dn-font-viewer> >> app.

When the font viewer is dismissed, the attributes of the last viewed font are
printed to stdout.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. This method enables font viewing as described in
L</DESCRIPTION>.

=head1 DIAGNOSTICS

No warning or error messages are emitted by this module.

Subsidiary modules may do so.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Moo, MooX::Options, namespace::clean, strictures, Tk, Tk::BrowseEntry,
version.

=head1 AUTHOR

L<David Nebauer|mailto:david@nebauer.org>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2025 L<David Nebauer|mailto:david@nebauer.org>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
