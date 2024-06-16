package App::Dn::Html2Ebooks;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.036_001;
use version; our $VERSION = qv('0.6');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use App::Dn::Html2Ebooks::Format;
use Carp qw(croak);
use Const::Fast;
use MooX::HandlesVia;
use MooX::Options;
use Path::Tiny;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# options

# base_name (-b)    {{{1
option 'base_name' => (
  is       => 'ro',
  format   => 's',
  required => $TRUE,
  short    => 'b',
  doc      => 'Basename of input and output files',
);

# title     (-t)    {{{1
option 'title' => (
  is       => 'ro',
  format   => 's',               ## no critic (ProhibitDuplicateLiteral)
  required => $TRUE,
  short    => 't',
  doc      => 'Title of book',
);

# author    (-a)    {{{1
option 'author' => (
  is       => 'ro',
  format   => 's',                   ## no critic (ProhibitDuplicateLiteral)
  required => $TRUE,
  short    => 'a',
  doc      => 'Author(s) of book',
);                                   # }}}1

# attributes

# _converter    {{{1
has '_converter' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {

    # abort if ebook-convert is not available
    my $self      = shift;
    my $converter = 'ebook-convert';
    if (not $self->path_executable($converter)) {
      die "Cannot locate ebook converter '$converter'\n";
    }
    return $converter;
  },
  doc => 'Shown in usage',
);

# _source    {{{1
has '_source' => (
  is      => 'ro',
  isa     => Types::Standard::InstanceOf ['Path::Tiny'],
  lazy    => $TRUE,
  default => sub {

    # abort if no source file
    my $self     = shift;
    my $basename = $self->base_name;
    my $source;
    for my $ext (qw(html htm)) {
      my $filename = $basename . q[.] . $ext;
      my $file     = Path::Tiny::path($filename);
      if ($file->is_file) {
        $source = $file;
      }
    }
    if (not $source) {
      die "Can't find source file '$basename.htm[l]'\n";
    }
    return $source;
  },
  doc => 'Source html file',
);

# _cover    {{{1
has '_cover' => (
  is => 'ro',
  ## no critic (ProhibitDuplicateLiteral)
  isa =>
      Types::Standard::Maybe [ Types::Standard::InstanceOf ['Path::Tiny'] ],
  ## use critic
  lazy    => $TRUE,
  default => sub {
    my $self     = shift;
    my $filename = $self->base_name . '.png';
    my $file     = Path::Tiny::path($filename);
    return $file->is_file ? $file : undef;
  },
  doc => 'Cover png file',
);

# _today    {{{1
has '_today' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    return $self->date_current_iso();
  },
  doc => q[ Today's date in ISO 8601 format ],
);

# _formats    {{{1
has '_formats_list' => (
  is  => 'ro',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['App::Dn::Html2Ebooks::Format'],
  ],
  lazy    => $TRUE,
  default => sub {
    my $self = shift;

    # variables    {{{2
    my $converter = $self->_converter;
    my $source    = $self->_source->stringify;
    my $base      = $self->file_base($source);
    my $cover     = $self->_cover ? $self->_cover->stringify : undef;
    my $date      = $self->_today;
    my $title     = $self->title;
    my $author    = $self->author;                                      # }}}2

    my @formats;

    # Electronic publication (epub)    {{{2
    my $epub =
        App::Dn::Html2Ebooks::Format->new(name => 'Electronic publication',);
    $epub->add_args(
      $converter,              $source,
      $base . '.epub',         '--pretty-print',
      '--smarten-punctuation', '--insert-blank-line',
      '--keep-ligatures',      '--title=' . $title,
      '--authors=' . $author,  '--language=en_AU',
      '--pubdate=' . $date,
    );
    if ($cover) {
      $epub->add_args('--cover=' . $cover);
    }
    push @formats, $epub;

    # Kindle Format 8 (azw3)    {{{2
    my $azw3 = App::Dn::Html2Ebooks::Format->new(name => 'Kindle Format 8',);
    ## no critic (ProhibitDuplicateLiteral)
    $azw3->add_args(
      $converter,            $source,
      $base . '.azw3',       '--no-inline-toc',
      '--pretty-print',      '--smarten-punctuation',
      '--insert-blank-line', '--keep-ligatures',
      '--title=' . $title,   '--authors=' . $author,
      '--language=en_AU',    '--pubdate=' . $date,
    );
    if ($cover) {
      $azw3->add_args('--cover=' . $cover);
    }
    ## use critic
    push @formats, $azw3;    # }}}2

    return [@formats];
  },
  handles_via => 'Array',
  handles     => { _formats => 'elements', },
  doc         => 'Array of format objects',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # produce ebooks
  for my $format ($self->_formats) {
    my $name = $format->name;
    my @args = $format->args;
    say "\nConverting to $name" or croak;
    $self->run_command("Conversion to $name failed", @args);
  }
  say 'Completed conversion to ebooks' or croak;

  return $TRUE;
}                    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Html2Ebooks - convert html file to ebook formats

=head1 VERSION

This documentation is for App::Dn::Html2Ebooks version 0.6.

=head1 SYNOPSIS

B<dn-html2ebooks> B<-b> I<--base_name> B<-t> I<title> B<-a> I<author>

B<dn-html2ebooks -h>

=head1 DESCRIPTION

Converts an html file in the current directory named F<basename.html> or
F<basename.htm> where "basename" is the option provided to the C<-b> option.
This source file is converted to the following format and output file:

=over

=item Electronic publication (F<basename.epub>)

=item Kindle Format 8 (F<basename.epub>)

=back

Output files are written to the current directory and silently overwrite any
existing output files of the same name.

If there is a png image file in the current directory called F<basename.png> it
will be used as a cover image for the ebooks.

The conversions are performed by F<ebook-convert>, part of the Calibre suite on
debian systems.

=head1 OPTIONS

All options are scalar strings and required.
Enclose options values in quotes if they contains spaces.

=over

=item base_name

Basename (file name without extension) of source html file.

item title

Book title.

item author

Book author (or authors).

=back

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only module method. It converts the specified html file as
described in L</DESCRIPTION>.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration

This module does not use configuration files.

=head2 Environment

This module does not use environmental variables.

=head1 INCOMPATIBILITIES

There are no known incompatibilities with other modules.

=head1 DIAGNOSTICS

=head2 Can't find source file 'BASENAME.htm[l]'

Occurs when an invalid file base name has been provided.

=head2 Cannot locate ebook converter 'CONVERTER'

Occurs when the script is unable to locate F<ebook-convert> on the system.

=head1 DEPENDENCIES

=head2 Perl modules

App::Dn::Html2Ebooks::Format, Carp, Const::Fast, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, Path::Tiny, strictures, Types::Standard,
version.

=head2 Executables

ebook-convert.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
