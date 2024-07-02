package App::Dn::NumericPrefix;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.6');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use autodie qw(open close);
use Carp    qw(croak);
use Const::Fast;
use English;
use List::SomeUtils;
use MooX::HandlesVia;
use MooX::Options protect_argv => 0;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# options

# current (-c)    {{{1
option 'current' => (
  is    => 'ro',
  short => 'c',
  doc   => 'List current paths of specified files',
);

# force   (-f)    {{{1
option 'force' => (
  is    => 'ro',
  short => 'f',
  doc   => 'Overwrite existing files without warning',
);

# renamed (-r)    {{{1
option 'renamed' => (
  is    => 'ro',
  short => 'r',
  doc   => 'List paths that specified files will have after renaming',
);    # }}}1

# attributes

# _fps, _set_new_fp, _new_fp, _new_fps, _fp_pairs    {{{1
has '_fp_hash' => (
  is  => 'ro',
  isa => Types::Standard::HashRef [
    Types::Standard::Maybe [Types::Standard::Str],
  ],
  lazy        => $TRUE,
  handles_via => 'Hash',
  handles     => {
    _fps        => 'keys',
    _set_new_fp => 'set',
    _new_fp     => 'get',
    _new_fps    => 'values',
    _fp_pairs   => 'elements',
  },
  default => sub {
    my $self = shift;
    my @matches;    # get unique file names
    for my $arg (@ARGV) { push @matches, glob "$arg"; }
    my @unique_matches = List::SomeUtils::uniq @matches;
    my @fps            = grep { $self->file_readable($_) } @unique_matches;

    my %fp_hash;
    %fp_hash = map { $_ => undef } @fps;
    return {%fp_hash};
  },
  doc => 'File paths',
);

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check args
  $self->_check_args;

  # display filepaths if that's requested
  if ($self->current) {
    $self->_list_current_file_paths;
    return;
  }

  # determine new file names
  $self->_derive_new_paths;

  # show new filepaths if that's requested
  if ($self->renamed) {
    $self->_list_renamed_file_paths;
    return;
  }

  # if here, then user wants to rename files
  $self->_add_numeric_prefixes;

  return;
}

# _add_numeric_prefixes()    {{{1
#
# does:   rename files with numeric prefixes
#
# params: nil
# prints: error message on failure
# return: n/a, exits on failure
sub _add_numeric_prefixes ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  my @fps = sort $self->_fps;

  # check whether overwriting existing files
  my %fp_pairs = $self->_fp_pairs;
  my @exists;

  for my $fp (keys %fp_pairs) {
    my $new_fp = $fp_pairs{$fp};
    if (-e $new_fp) {
      push @exists, $fp;
    }
  }
  if (@exists and not $self->force) {
    warn "The following renaming would overwrite existing files:\n";
    for my $fp (@exists) { warn "  $fp -> $fp_pairs{$fp}\n"; }
    warn "Use '--force' to overwrite existing files\n";
    return;
  }

  # rename files
  for my $fp (keys %fp_pairs) {
    my $new_fp = $fp_pairs{$fp};
    rename $fp, $new_fp
        or die "Unable to rename '$fp' to '$new_fp': $OS_ERROR\n";
  }

  return;
}    # }}}1

# _check_args()    {{{1
#
# does:   check arguments
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _check_args ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # need at least one file path
  my @fps   = $self->_fps;
  my $count = @fps;
  if (not $count) {
    warn "No file paths specified\n";
    exit 1;
  }

  return;
}

# _derive_new_paths()    {{{1
#
# does:   determine new file names
# params: nil
# prints: nil, except error messages
# return: n/a, dies on failure
sub _derive_new_paths ($self) { ## no critic (RequireInterpolationOfMetachars)

  my @fps    = sort $self->_fps;
  my $width  = length scalar @fps;
  my $format = '%0' . $width . 's';
  my $count  = 1;

  for my $fp (@fps) {
    my ($dir, $file) = $self->path_parts($fp);
    my $prefix = sprintf($format, $count) . q{_};
    my $new_fp = $dir . $prefix . $file;
    $self->_set_new_fp($fp => $new_fp);
    $count++;
  }

  return;
}

# _list_current_file_paths()    {{{1
#
# does:   list current paths of specified files
#
# params: nil
# prints: file paths
# return: n/a, exits on failure
sub _list_current_file_paths ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  my @fps = sort $self->_fps;
  for my $fp (@fps) { say $fp or croak; }

  return;
}

# _list_renamed_file_paths()    {{{1
#
# does:   list paths that specified files will have after renaming
#
# params: nil
# prints: new file paths
# return: n/a, exits on failure
sub _list_renamed_file_paths ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  my @fps = sort $self->_new_fps;
  for my $fp (@fps) { say $fp or croak; }

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::NumericPrefix - add numeric prefix to file names

=head1 VERSION

This documentation is for C<App::Dn::NumericPrefix> version 0.6.

=head1 SYNOPSIS

    use App::Dn::NumericPrefix;

    App::Dn::NumericPrefix->new_with_options->run;

=head1 DESCRIPTION

Add an incrementing numeric prefix to the file names of a group of files. For
example, files F<a> and F<b> are renamed to F<1_a> and F<2_b>. File order is
standard shell ascii order.

If there are more than nine files to be processed, the numeric prefixes are
left zero-padded. For example, if there were over a hundred files, files F<a>
and F<b> may be renamed F<001_a> and F<002_b>.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 OPTIONS

=head3 -c | --current

List paths of files to which numeric prefixes will be added. No files are
actually renamed when this option is used. Flag. Optional. Default: false.

=head3 -r | --renamed

Show paths of files that will result after numeric prefixes are added. No files
are actually renamed when this option is used. Flag. Optional. Default:
false.

=head3 -f | --force

Proceed with file renaming even if existing files will be overwritten. Flag.
Optional. Default: false.

=head3 -h | --help

Display help and exit.

=head2 ARGUMENTS

=head3 glob

Glob specifying paths of files to which numeric prefixes will be added.
String. Required.

=head2 Attributes

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It renames files as described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Unable to rename 'FILE_NAME' to 'NEW_FILE_NAME': ERROR

Occurs when the operating system is unable to rename a file. Fatal.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Const::Fast, English, List::SomeUtils, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, strictures, Types::Standard, version.

=head1 AUTHOR

David Nebauer S<< L<mailto:david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< L<mailto:david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker
