package App::Dn::FontViewer;

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
use Tk::BrowseEntry;
use MooX::Options (
  authors      => 'David Nebauer <david at nebauer dot org>',
  description  => 'View font appearance',
  protect_argv => 0,
);    #     }}}1

# constants    {{{1
const my $TRUE                    => 1;
const my $FALSE                   => 0;
const my $ARG_BOLD                => 'bold';
const my $ARG_END                 => 'end';
const my $ARG_ITALIC              => 'italic';
const my $ARG_LEFT                => 'left';
const my $ARG_NORMAL              => 'normal';
const my $ARG_OVERSTRIKE          => 'overstrike';
const my $ARG_ROMAN               => 'roman';
const my $ARG_UNDERLINE           => 'underline';
const my $ARG_X                   => 'x';
const my $FONT_DEFAULT_FAMILY     => 'Courier';
const my $FONT_DEFAULT_SIZE       => 24;
const my $FONT_DEFAULT_WEIGHT     => $ARG_NORMAL;
const my $FONT_DEFAULT_SLANT      => $ARG_ROMAN;
const my $FONT_DEFAULT_UNDERLINE  => $FALSE;
const my $FONT_DEFAULT_OVERSTRIKE => $FALSE;
const my $SIZE_RANGE_BOUND_LOWER  => 3;
const my $SIZE_RANGE_BOUND_UPPER  => 32;             # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {

  # top level widgets    {{{2
  my $mw =
      MainWindow->new(-title => 'Font Viewer', -class => 'Perl/Tk widget');
  my $f = $mw->Frame->pack(-side => 'top');

  # font   {{{2
  my $font = $mw->fontCreate(
    -family     => $FONT_DEFAULT_FAMILY,
    -size       => $FONT_DEFAULT_SIZE,
    -weight     => $FONT_DEFAULT_WEIGHT,
    -slant      => $FONT_DEFAULT_SLANT,
    -underline  => $FONT_DEFAULT_UNDERLINE,
    -overstrike => $FONT_DEFAULT_OVERSTRIKE,
  );

  # interface elements    {{{2

  # • font family dropdown    {{{3
  my $family = $FONT_DEFAULT_FAMILY;
  my $be     = $f->BrowseEntry(
    -label         => 'Family:',
    -variable      => \$family,
    -autolistwidth => $TRUE,
    -browsecmd     => sub { $mw->fontConfigure($font, -family => $family) },
  )->pack(-fill => $ARG_X, -side => $ARG_LEFT);
  $be->insert($ARG_END, sort $mw->fontFamilies);

  # • font size dropdown    {{{3
  my $size   = $FONT_DEFAULT_SIZE;
  my $bentry = $f->BrowseEntry(
    -label     => 'Size:',
    -variable  => \$size,
    -browsecmd => sub { $mw->fontConfigure($font, -size => $size) },
  )->pack(-side => $ARG_LEFT);
  $bentry->insert($ARG_END,
    ($SIZE_RANGE_BOUND_LOWER .. $SIZE_RANGE_BOUND_UPPER));

  # • font weight checkbox    {{{3
  my $weight = $FONT_DEFAULT_WEIGHT;
  $f->Checkbutton(
    -onvalue  => $ARG_BOLD,
    -offvalue => $ARG_NORMAL,
    -text     => 'Weight',
    -variable => \$weight,
    -command  => sub { $mw->fontConfigure($font, -weight => $weight) },
  )->pack(-side => $ARG_LEFT);

  # • font slant checkbox    {{{3
  my $slant = $FONT_DEFAULT_SLANT;
  $f->Checkbutton(
    -onvalue  => $ARG_ITALIC,
    -offvalue => $ARG_ROMAN,
    -text     => 'Slant',
    -variable => \$slant,
    -command  => sub { $mw->fontConfigure($font, -slant => $slant) },
  )->pack(-side => $ARG_LEFT);

  # • font underline checkbox    {{{3
  my $underline = $FONT_DEFAULT_UNDERLINE;
  $f->Checkbutton(
    -text     => 'Underline',
    -variable => \$underline,
    -command  => sub { $mw->fontConfigure($font, -underline => $underline) },
  )->pack(-side => $ARG_LEFT);

  # • font overstrike checkbox    {{{3
  my $overstrike = $FONT_DEFAULT_OVERSTRIKE;
  $f->Checkbutton(
    -text     => 'Overstrike',
    -variable => \$overstrike,
    -command => sub { $mw->fontConfigure($font, -overstrike => $overstrike) },
  )->pack(-side => $ARG_LEFT);

  # • font sample label (lowercase)    {{{3
  my $sample_text_lc = 'The quick brown fox jumped over the lazy dog';
  my $sample_lc =
      $mw->Label(-textvariable => \$sample_text_lc, -font => $font)
      ->pack(-fill => $ARG_X);

  # • font sample label (uppercase)    {{{3
  my $sample_text_uc = uc $sample_text_lc;
  my $sample_uc =
      $mw->Label(-textvariable => \$sample_text_uc, -font => $font)
      ->pack(-fill => $ARG_X);    # }}}3

  # actions    {{{2

  # • Escape    {{{3
  $mw->bind(
    '<KeyRelease-Escape>' => sub {
      if (Tk::Exists($mw)) { $mw->destroy; }
      return;
    }
  );    # }}}3

  # activate display    {{{2
  MainLoop;

  # display final font details    {{{2
  my @font_attributes;
  push @font_attributes, "{$family}", $size;
  if ($weight eq $ARG_BOLD)  { push @font_attributes, $ARG_BOLD; }
  if ($slant eq $ARG_ITALIC) { push @font_attributes, $ARG_ITALIC; }
  if ($underline)            { push @font_attributes, $ARG_UNDERLINE; }
  if ($overstrike)           { push @font_attributes, $ARG_OVERSTRIKE; }
  my $font_description = join q{ }, @font_attributes;
  say $font_description or croak;
  return;    # }}}2

  # }}}1
}

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::FontViewer - view font appearance

=head1 VERSION

This documentation applies to L<App::Dn::FontViewer> version 0.1.

=head1 SYNOPSIS

  use App::Dn::FontViewer;
  App::Dn::FontViewer->new_with_options->run;

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

The font viewer is closed by pressing the C<Escape> key.

The viewer interface is constructed directly inside a top level widget.
The class part of the X11 WM_CLASS property for the displayed widget is set to
"Perl/Tk widget".
For a viewer that uses a pre-defined font dialog see the
S<< F<dn-font-viewer2> >> app.

When the font viewer is dismissed, the sttributes of the last viewed font are
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
