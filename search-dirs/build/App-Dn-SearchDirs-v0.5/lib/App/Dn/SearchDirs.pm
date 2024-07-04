package App::Dn::SearchDirs;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use autodie qw(open close);
use Carp    qw(croak);
use Const::Fast;
use File::HomeDir;
use File::Path;
use MooX::HandlesVia;
use MooX::Options;
use Term::Clui;
local $ENV{CLUI_DIR} = 'OFF';    # do not remember responses
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE    => 1;
const my $FALSE   => 0;
const my $NEWLINE => "\n";       # }}}1

# options

# edit_dirs (-e)    {{{1
option 'edit_dirs' => (
  is       => 'ro',
  required => $FALSE,
  short    => 'e',
  doc      => 'Edit directory list',
);

# list_dirs (-l)    {{{1
option 'list_dirs' => (
  is       => 'ro',
  required => $FALSE,
  short    => 'l',
  doc      => 'List search directories',
);    # }}}1

# attributes

# _config_dir    {{{1
has '_config_dir' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    my $dir  = File::HomeDir->my_home;
    $dir = $self->dir_join($dir, '.config');
    $dir = $self->dir_join($dir, 'dn-search-dirs');
    return $dir;
  },
  doc => 'Directory containing the configuration file',
);

# _config_file    {{{1
has '_config_file' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    my $path = $self->_config_dir;
    $path = $self->file_cat_dir('dir-list', $path);
    return $path;
  },
  documentation => 'Configuration file containing directory listing',
);

# _add_dirs, _dirs, _has_dirs    {{{1
has '_directory_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  lazy        => $TRUE,
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _dirs     => 'elements',
    _add_dirs => 'push',
    _has_dir  => 'count',
  },
  documentation => 'List of directories',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)
  $self->_load_dirs;

  # list or edit directories if requested (edit takes precedence)
  if ($self->list_dirs and not $self->edit_dirs) { $self->_list_dirs; }
  if ($self->edit_dirs)                          { $self->_edit_dirs; }

  $self->_search_dirs;

  return;
}

# _edit_dirs()    {{{1
#
# does:   edit directory list
#
# params: nil
# prints: user feedback
# return: n/a, exits at conclusion
sub _edit_dirs ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $conf = $self->_config_file;

  # deal with case of missing configuration file
  if (not -e $conf) {
    my $conf_dir = $self->_config_dir;
    File::Path::make_path($conf_dir)
        or die "Unable to create directory '$conf_dir'\n";
    open my $fh, '>', $conf;
    say {$fh} '# dn-search-dirs configuration file' or croak;
    say {$fh} '# add one directory per line'        or croak;
    close $fh;
  }

  Term::Clui::edit($conf);
  exit;
}

# _list_dirs()    {{{1
#
# does:   print directory names
#
# params: nil
# prints: directory names
# return: n/a, exits at conclusion
sub _list_dirs ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my @dirs = $self->_dirs;
  if (@dirs) {
    for my $dir (@dirs) { say $dir or croak; }
  }
  else {
    warn "No directories are configured\n";
  }
  exit;
}

# _load_dirs()    {{{1
#
# does:   read config file and get directory names
#
# params: nil
# prints: error messages
# return: n/a, ignores errors
sub _load_dirs ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $conf = $self->_config_file;
  if (not -e $conf) {
    warn "WARNING: Configuration file '$conf' is missing\n";
    return;
  }
  my @dirs;
  open my $fh, '<', $conf;
  chomp(my @lines = <$fh>);
  close $fh;
  for my $line (@lines) {
    next if $line =~ /^\#/xsm;
    next if $line eq q{};
    $line =~ s/ # .* $//xsm;
    if (-d $line) { push @dirs, $line; }
    else          { warn "Invalid directory: $line\n"; }
  }
  if (@dirs) { $self->_add_dirs(@dirs); }
  return;
}

# _search_dirs()    {{{1
#
# does:   repeatedly search directories
#
# params: nil
# prints: user feedback
# return: n/a
sub _search_dirs ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my @dirs = $self->_dirs;
  if (not @dirs) { die "No directories configured\n"; }
  print $NEWLINE                             or croak;
  say 'Searching the following directories:' or croak;
  for my $dir (@dirs) { say "- $dir" or croak; }
  print $NEWLINE                             or croak;
  say 'Enter an empty search string to exit' or croak;
  while ($TRUE) {
    my @results;
    print $NEWLINE or croak;
    my $frag = $self->interact_ask('Enter part of file name:');
    last if not $frag;
    my $pattern = qr{$frag}xsm;
    for my $dir (@dirs) {
      my @matches = $self->file_list($dir, $pattern);
      push @results, @matches;
    }
    my $count = @results;
    say "MATCHES: $count" or croak;
    for my $result (@results) { say $result or croak; }
  }
  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::SearchDirs - repeatedly search a set of directories

=head1 VERSION

This documentation is for C<App::Dn::SearchDirs> version 0.5.

=head1 SYNOPSIS

    use App::Dn::SearchDirs;

    App::Dn::SearchDirs->new_with_options->run;

=head1 DESCRIPTION

A list of directories is kept in a configuration file
(F<~/.config/dn-search-dirs/dir-list>) that can be listed on screen (option
C<-l>) and edited (option C<-e>).

When run without an option the user is prompted for a file name fragment. All
configured directories are then searched for matching files. Note that these
directory searches are not recursive. When the search is complete a total match
count and all matching file paths are displayed. The user is then prompted for
another file name fragment.

To exit the user presses enter without entering a search fragment, i.e., an
empty search string.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Options

=head2 -e | --edit_dirs

Edit configured directories. Flag. Optional. Default: false.

=head2 -l | --list_dirs

List configured directories. Flag. Optional. Default: false.

=head2 -h | --help

Display help and exit. Flag. Optional. Default: false.

=head2 Attributes

None.

=head2 Configuration files

A list of directories is kept in a configuration file
(F<~/.config/dn-search-dirs/dir-list>) that can be listed on screen (option
C<-l>) and edited (option C<-e>).

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It searches predefined directories as described in
L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Unable to create directory 'DIR'

Occurs when system is unable to create the specified directory.

=head2 No directories configured

Occurs when no search directories are configured.

=head1 INCOMPATIBILITIES

There are no known significant incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Const::Fast, File::HomeDir, File::Path, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, Role::Utils::Dn, strictures, Term::Clui,
Types::Standard, version.

=head1 AUTHOR

David Nebauer S<< <david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker
