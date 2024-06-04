package App::Dn::DlPodcastFiles;

# modules    # {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.4');
use namespace::clean;
use autodie qw(open close);
binmode STDOUT, ':encoding(UTF-8)';
use App::Dn::DlPodcastFiles::Constants;
use Carp qw(croak);
use Const::Fast;
use English;
use File::Copy;
use File::Fetch;
use MooX::HandlesVia;
use MooX::Options;
use Types::Standard;
use YAML;

with qw(Role::Utils::Dn);

const my $TRUE      => 1;
const my $FALSE     => 0;
const my $DIV_WIDTH => 20;    # }}}1

# attributes

# file    {{{1
has 'import_file' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'YAML import file',
);

# _episodes, _add_episode[s], _has_episode    {{{1
has '_episode_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['Dn::Episode'],
  ],
  lazy        => $TRUE,
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _episodes     => 'elements',
    _add_episode  => 'push',
    _add_episodes => 'push',
    _has_episode  => 'count',
  },
  doc => 'Array of episodes',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)
  $self->_import();    # dies on failure
  $self->_download_files();
  return $TRUE;
}

# _import    {{{1
#
# does:   imports YAML data file
#
# params: nil
# prints: feedback on success or failure
# return: n/a, dies on import failure
sub _import ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # import file must be valid
  if (not $self->import_file) { die "No import file specified\n"; }
  my $file = $self->import_file;
  if (not -e $file) { die "Cannot find '$file'\n"; }

  # import the file
  my @imported = YAML::LoadFile($file);
  my $count    = @imported;
  if (not $count) { croak "No episodes were imported from file $file"; }

  # extract episode details
  my @episodes;
  for my $details (@imported) {
    my $episode = Dn::Episode->new(
      url   => $details->{'url'},
      title => $details->{'title'},
      date  => $details->{'date'},
      time  => $details->{'time'},
    );
    push @episodes, $episode;
  }
  $count = @episodes;
  if ($count) {
    say $self->pluralise("Obtained download details for $count (file|files)",
      $count)
        or croak;
  }
  else {
    die "No episode details were extracted from file '$file' data\n";
  }

  # save episode details
  $self->_add_episodes(@episodes);

  return $TRUE;
}    # }}}1

# _download_files()    {{{1
#
# does:   download files
# params: nil
# prints: nil, except error messages
# return: n/a, dies on failure
sub _download_files ($self) {   ## no critic (RequireInterpolationOfMetachars)
  for my $episode ($self->_episodes) {

    # set details
    my $title = $episode->title;

    # give feedback
    my $div = $App::Dn::DlPodcastFiles::Constants::DASH x $DIV_WIDTH;
    say "Downloading episode '$title'" or croak;
    say $div                           or croak;

    # perform download
    my $ff    = File::Fetch->new(uri => $episode->url);
    my $where = $ff->fetch;
    if (not $where) { die "Download failed\n"; }

    # rename file
    my $old = $self->file_name($where);
    my $new = $episode->ep_filename;
    File::Copy::move($old, $new)
        or die "Unable to rename '$old' to '$new'\n";
  }
  return $TRUE;
}    # }}}1

1;
__END__

=head1 NAME

App::Dn::DlPodcastFiles - download podcast files

=head1 VERSION

This documentation is for App::Dn::DlPodcastFiles version 0.4.

=head1 SYNOPSIS

  use App::Dn::DlPodcastFiles;

=head1 DESCRIPTION

App::Dn::DlPodcastFiles was developed for downloading podcast files that are
too old to appear in a podcast feed but that are still included in the rss feed
file online. Details of the files are obtained and a yaml import file created.

The import file lists the following for each download file:

    url, title, date, time

Date and time are the date and time the file was published.

Required values are url, title and time. Date is optional.

Here is an example import file. It lists episodes from the "Fear the Boot"
podcast.

    ---
    url: http://media.libsyn.com/media/feartheboot/feartheboot_0001.mp3
    title: Episode 1 - when player abilities eclipse character abilities
    date: 2006-05-15
    time: 2230
    ---
    url: http://media.libsyn.com/media/feartheboot/feartheboot_0002.mp3
    title: Episode 2 - creating a group template
    date: 2006-05-23
    time: 0611
    ---
    url: http://media.libsyn.com/media/feartheboot/feartheboot_0003.mp3
    title: Episode 3 - character creation
    date: 2006-05-30
    time: 0836

The downloaded file name consists of the url filename with a prefix constructed
from the episode's date and, if provided, time. Here are the download files
corresponding to the import file shown above:

    20060515-2230_feartheboot_0001.mp3
    20060523-0611_feartheboot_0002.mp3
    20060530-0836_feartheboot_0003.mp3

=head1 SUBROUTINES/METHODS

=head2 run()

The module's main (and only) method. It reads the import file and downloads
podcast files.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 import_file

YAML import file. See L</DESCRIPTION> for the file format.

=head2 Configuration

This module does not use a configuration file.

=head2 Environment

This module does not use environment variables.

=head1 DIAGNOSTICS

=head2 Cannot find 'FILE'

Occurs when the specified YAML import file cannot be found.

=head2 Download failed

A podcast file could not be downloaded from the internet.

=head2 No episode details were extracted from file 'FILE' data

No podcast episode details could be extracted from the data extracted from the
YAML import file.

=head2 No episodes were imported from file FILE

After parsing the YAML import file no data could be extracted.

=head2 No import file specified

Occurs when no YAML import file is specified.

=head2 Unable to rename 'OLD' to 'NEW'

After downloading a podcast file it could not be renamed.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Please report any to the module author.

=head1 DEPENDENCIES

autodie, Carp, Const::Fast, English, File::Copy, File::Fetch, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Role::Utils::Dn, strictures,
Types::Standard, version, YAML.

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=head1 COPYRIGHT

Copyright 2024- David Nebauer

=head1 LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
