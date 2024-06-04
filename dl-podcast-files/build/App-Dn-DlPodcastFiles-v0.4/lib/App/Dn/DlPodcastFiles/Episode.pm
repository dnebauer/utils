package App::Dn::DlPodcastFiles::Episode;

use Moo;    # {{{1
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.4');
use namespace::clean;

use App::Dn::DlPodcastFiles::Constants;
use Carp qw(croak);
use Const::Fast;
use MooX::HandlesVia;
use Time::Simple;
use Types::URI -all;
use Types::DateTime -all;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# attributes

# url    {{{2
has 'url' => (
  is            => 'ro',
  isa           => Types::URI::Uri,
  coerce        => $TRUE,
  required      => $TRUE,
  documentation => 'URL of mp3 file',
);

# title    {{{2
has 'title' => (
  is            => 'ro',
  isa           => Types::Standard::Str,
  required      => $TRUE,
  documentation => 'Title of mp3 file',
);

# date    {{{2
has 'date' => (
  is       => 'ro',
  isa      => Types::DateTime::DateTime->plus_coercions(Format ['ISO8601']),
  coerce   => $TRUE,
  required => $TRUE,
  documentation => 'Date of release of mp3 file (ISO format)',
);

# time    {{{2
has 'time' => (
  is            => 'ro',
  isa           => Types::Standard::Str,
  required      => $TRUE,
  documentation => 'Time of day on which mp3 file was released',
);

# validated_time    {{{2
has 'validated_time' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $FALSE,
  lazy     => $TRUE,
  default  => sub {
    my $self = shift;
    return if not $self->time;
    my $time = $self->time;

    # "colonify" 4-digit time value
    if ($time =~ /^ ( \d{2} ) ( \d{2} ) \z/xsm) { $time = "$1:$2"; }

    # evaluate time value
    my $valid = eval { Time::Simple->new($time); 1 };
    if (not $valid) {
      my $url = $self->url;
      croak "Invalid time value '$time' for url '$url'";
    }
    return $self->time;
  },
  documentation => 'Validated time of mp3 file release',
);

# ep_filename    {{{2
has 'ep_filename' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $FALSE,
  lazy     => $TRUE,
  default  => sub {
    my $self = shift;

    # prefix with date (and time if provided)
    my $name = $self->date->ymd(q{});
    if ($self->validated_time) {
      $name .= $App::Dn::DlPodcastFiles::Constants::DASH
          . $self->validated_time;
    }

    # add original url filename
    my $url          = $self->file_name($self->url);
    my $url_filename = $self->file_name($url);
    if (not $url_filename) {
      die "Unable to extract filename from url '$url'\n";
    }
    $name .= '_' . $url_filename;
    return $name;
  },
  documentation => 'Name of downloaded file',
);    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::DlPodcastFiles::Episode - capture podcast episode details


=head1 VERSION

This documentation is for App::Dn::DlPodcastFiles::Episode version 0.4.

=head1 SYNOPSIS

    use App::Dn::DlPodcastFiles::Episode;
    ...

=head1 DESCRIPTION

Used by L<App::Dn::DlPodcastFiles> to capture details of individual podcast
episodes.

=head1 SUBROUTINES/METHODS

This module has now subroutines or methods.

=head1 DIAGNOSTICS

=head2 Invalid time value 'TIME' for url 'URL'

Unable to parse the provided time value.

=head2 Unable to extract filename from url 'URL'

The url could not be parsed to extract a file name.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 url

URL of mp3 file.

=head3 title

Title of mp3 file.

=head3 date

Date of release of mp3 file in ISO format.

=head3 time

Time of day on which mp3 file was released.

=head3 validated_time

Validated time of mp3 file release. It is derived from the 'time' property.

=head3 ep_filename

Name given to downloaded episode file. It is derived from the file date, time
and url.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 DEPENDENCIES

Carp, Const::Fast, Moo, MooX::HandlesVia, namespace::clean, Role::Utils::Dn,
strictures, Time::Simple, Types::URI, Types::DateTime, Types::Standard,
version.

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
