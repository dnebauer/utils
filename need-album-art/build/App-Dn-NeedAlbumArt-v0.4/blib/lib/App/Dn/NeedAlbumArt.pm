package App::Dn::NeedAlbumArt;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.4');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Const::Fast;
use English;
use File::chdir;    # provides $CWD and @CWD
use File::Find::Rule;
use File::Spec;
use List::SomeUtils;
use MooX::Options protect_argv => 0;
use Path::Tiny;
use Types::Path::Tiny;

const my $TRUE     => 1;
const my $FALSE    => 0;
const my $CURR_DIR => Path::Tiny->cwd;    # }}}1

# options

# dir (-d)    {{{1
option 'dir' => (
  is       => 'ro',
  format   => 's',
  short    => 'd',
  required => $FALSE,
  default  => sub {undef},
  doc      => 'Directory to search',
);    # }}}1

# attributes

# _dir    {{{1
has '_dir_obj' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  lazy    => $TRUE,
  default => sub {
    my $self       = shift;
    my $dir_option = $self->dir;
    if (defined $dir_option) {
      if   (-d $dir_option) { return Path::Tiny::path($dir_option); }
      else                  { die "Invalid directory path: $dir_option\n"; }
    }
    else { return Path::Tiny::path($CURR_DIR); }
  },
  doc => 'Root of directory tree to search',
);

sub _dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_dir_obj->canonpath;
}                     # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # get directories with mp3 files but no album cover art
  # - File::Find::Rule->exec($filter) invokes $filter with $_ (aka $ARG)
  #   set to:
  #   (short name, name parameters, current path, full relative filename)
  my $filter = sub {

    # get current directory path
    my $path = $ARG[2];    # third parameter = current path

    # look for mp3 files
    my $glob_mp3 = File::Spec->catfile($path, '*.mp3');
    my @mp3s     = glob $glob_mp3;

    # look for album cover art
    my $glob_art  = File::Spec->catfile($path, '{cover,album}.{png,jpg}');
    my @art_files = glob $glob_art;
    my $has_art   = List::SomeUtils::any {-e} @art_files;

    # return true if has mp3 files but no album cover art
    return (@mp3s and not $has_art);
  };

  my $root = $self->_dir;
  my @dirpaths;
  {
    # need to override File::chdir's $CWD variable
    # File::chdir recommends use of 'local $CWD'
    local $CWD = $root;    ## no critic (ProhibitLocalVars)
    @dirpaths = File::Find::Rule->directory->exec($filter)->in($root);
  }

  # convert all found (absolute) directory paths into relative paths
  my @dirs = map { File::Spec->abs2rel($_, $root) } @dirpaths;

  # output directories to stdout
  foreach (sort @dirs) { say or croak; }

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::NeedAlbumArt - find directories needing album cover art

=head1 VERSION

This documentation is for C<App::Dn::NeedAlbumArt> version 0.4.

=head1 SYNOPSIS

    use App::Dn::NeedAlbumArt;
    App::Dn::NeedAlbumArt->new_with_options->run;

=head1 DESCRIPTION

Search a directory recursively for subdirectories that need album
cover art. More specifically, it searches for subdirectories containing mp3
files but no album cover art file. An album cover art file is one named
F<album.png>, F<album.jpg>, F<cover.png>, or F<cover.png>.

If a directory is not specified, the current directory is searched.

The subdirectories matching these conditions are printed to stdout, one per
line.

=head1 CONFIGURATION AND ENVIRONMENT

There is no configuration for this script.

=head1 OPTIONS

=head2 -d | --dir DIRPATH

Root directory of directory tree to analyse.
Scalar string directory path (must exist).
Optional. Default: current directory.

=head2 -h | --help

Display help and exit.

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only public method. It conducts the subdirectory search described
in L<DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Invalid directory path: DIR

The specified directory cannot be located. Fatal.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, English, File::Find::Rule, File::Spec, File::chdir,
List::SomeUtils, Moo, MooX::Options, namespace::clean, Path::Tiny, strictures,
Types::Path::Tiny, version.

=head1 AUTHOR

David Nebauer S<< L<mailto:david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< L<mailto:david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
