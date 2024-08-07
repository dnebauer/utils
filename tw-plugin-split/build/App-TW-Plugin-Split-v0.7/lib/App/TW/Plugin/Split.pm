package App::TW::Plugin::Split;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.7');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Const::Fast;
use English;
use File::Basename;
use File::Copy;
use File::Find::Rule;
use File::Spec;
use File::Which;
use IPC::Cmd;
use List::SomeUtils;
use MooX::HandlesVia;
use MooX::Options protect_argv => 0;
use Path::Tiny;
use Types::Path::Tiny;
use Types::Standard;

const my $TW_MIN_VERSION => '5.1.20';    # for --savewikifolder command

const my $TRUE           => 1;
const my $FALSE          => 0;
const my $COMMA_SPACE    => q{, };
const my $CMD_TIDDLYWIKI => 'tiddlywiki';
const my $PERIOD         => q{.};
const my $SPACE          => q{ };           # }}}1

# options

# format (-f)    {{{1
option 'format' => (
  is         => 'ro',
  format     => 's',
  repeatable => $TRUE,
  default    => sub { [] },
  short      => 'f',
  required   => $FALSE,
  doc        => q{Plugin file format ['tid' (default) or 'json']},
);

# simplify (-s)    {{{1
option 'simplify' => (
  is       => 'ro',
  short    => 's',      ## no critic (ProhibitDuplicateLiteral)
  required => $FALSE,
  doc      => 'Whether to simplify extracted file names',
);                      # }}}1

# attributes

# _cwd    {{{1
has '_cwd' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub { return Path::Tiny->cwd; },
  doc     => 'Current working directory',
);

# _extract_dir    {{{1
has '_extract_dir' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub { return Path::Tiny->tempdir; },
  doc     => 'Directory to which plugin is extracted',
);

# _plugin_dir    {{{1
has '_plugin_dir' => (
  is     => 'rw',
  isa    => Types::Standard::Maybe [Types::Path::Tiny::AbsDir],
  coerce => Types::Path::Tiny::AbsDir->coercion,
  doc    => 'Saved plugins specific plugin directory',
);

# _plugin_input_file    {{{1
has '_plugin_input_file' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsFile,
  coerce  => Types::Path::Tiny::AbsFile->coercion,
  lazy    => $TRUE,
  default => sub {

    # get unique command line arguments
    my @args;
    for my $arg (@ARGV) { push @args, glob "$arg"; }

    # must have only one argument
    my $count = @args;
    die "Error: No file name provided\n" if $count == 0;
    die "Error: Expected 1 command line argument, got $count\n"
        if $count > 1;

    # return value to be coerced
    return $args[0];
  },
  doc => 'Input plugin file path',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check tiddlywiki version (dies if not satisfied)
  $self->_check_tw_version;

  # extract plugin to temporary directory
  $self->_extract_plugin;

  # simplify file names if requested
  if ($self->simplify) { $self->_simplify; }

  # copy files back to current working directory
  $self->_output;

  return;
}

# _check_tw_version()    {{{1
#
# does:   checks that tw meets minimum version requirement
# params: nil
# prints: feedback
# return: n/a, dies on failure
# note:   relies on presence of $TW_MIN_VERSION variable/constant
# note:   assumes semantic versioning, e.g., 'major.minor.patch'
sub _check_tw_version ($self) { ## no critic (RequireInterpolationOfMetachars)
  my $tw = $CMD_TIDDLYWIKI;
  File::Which::which $tw or die "Error: Missing executable '$tw'\n";
  my $cmd = [ $tw, '--version' ];
  my ($success, $err_msg, $full, $stdout, $stderr) =
      IPC::Cmd::run(command => $cmd);
  if (not $success) {
    warn "$err_msg\n";
    my $cmd_str = join $SPACE, @{$cmd};
    warn "Version command: '$cmd_str'\n";
    die "Error: Version command failed\n";
  }
  my @version       = split /[.]/xsm, (@{$stdout})[0];
  my $version_parts = @version;
  my @minimum       = split /[.]/xsm, $TW_MIN_VERSION;
  my $minimum_parts = @minimum;
  if ($version_parts != $minimum_parts) {
    my $version_string = join $PERIOD, @version;
    my $minimum_string = join $PERIOD, @minimum;
    my $err =
          "The $tw version ($version_string) does not have the\n"
        . "same number of elements as the minimum\n"
        . "specified version ($minimum_string)";
    croak $err;
  }
  my $index = 0;
  while ($index <= 2) {
    if (  $version[$index] =~ /\A\d+\Z/xsm
      and $minimum[$index] =~ /\A\d+\Z/xsm)
    {
      # do numerical comparison
      die "tiddlywiki is v$stdout, need at least v$TW_MIN_VERSION\n"
          if $version[$index] < $minimum[$index];
    }
    else {
      # do text comparison
      die "tiddlywiki is v$stdout, need at least v$TW_MIN_VERSION\n"
          if "$version[$index]" lt "$minimum[$index]";
    }
    $index++;
  }
  return;
}

# _deserializer()    {{{1
#
# does:   decides on deserializer based on plugin file format
# params: nil
# prints: feedback
# return: scalar string - deserializer
sub _deserializer ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # variables    {{{2
  my $default = 'tid';
  my $format;
  my %deserializers =
      (tid => 'application/x-tiddler', json => 'application/json',);

  # get plugin format    {{{2
  my @formats = @{ $self->format };
  if (@formats) {

    # user provided format
    my $count = @formats;
    die "Expected 1 plugin file format, got $count\n" if $count > 1;
    $format = $formats[0];
    my %valid = map { $_ => $TRUE } keys %deserializers;
    die "Error: Invalid plugin file format '$format'\n"
        if not exists $valid{$format};
  }
  else {
    # format not specified by user
    # - assume json if file has 'json' extension, otherwise tid file
    my $plugin = $self->_plugin_input_file->canonpath;
    my $ext_re = qr/[.][^.]+\Z/xsm;
    my $ext    = (File::Basename::fileparse($plugin, $ext_re))[2];
    $format = ($ext =~ /\A[.]json\Z/xsm) ? 'json' : $default;
  }

  # return deserializer for plugin file format    {{{2
  croak "Missing plugin file format '$format'"
      if not exists $deserializers{$format};

  return $deserializers{$format};    # }}}2
}

# _dir_contents($dir)    {{{1
#
# does:   gets list of immediate files and subdirectories in a directory
# params: $dir - directory [scalar string]
# prints: feedback
# return: list of absolute paths, dies on failure
sub _dir_contents ($self, $dir)
{    ## no critic (RequireInterpolationOfMetachars)
  my $finder = File::Find::Rule->new;
  $finder->mindepth(1);
  $finder->maxdepth(1);
  my @contents = $finder->in($dir);
  return @contents;
}

# _dir_files($dir)    {{{1
#
# does:   gets list of files in a directory
# params: $dir - directory [scalar string]
# prints: feedback
# return: list of absolute filepaths, dies on failure
sub _dir_files ($self, $dir) {  ## no critic (RequireInterpolationOfMetachars)
  my $finder = File::Find::Rule->new;
  $finder->file;
  my @files = $finder->in($dir);
  return @files;
}

# _dir_subdirs($dir)    {{{1
#
# does:   gets list of immediate subdirectories in a directory
# params: $dir - directory [scalar string]
# prints: feedback
# return: list of absolute dirpaths, dies on failure
sub _dir_subdirs ($self, $dir)
{    ## no critic (RequireInterpolationOfMetachars)
  my $finder = File::Find::Rule->new;
  $finder->directory;
  $finder->mindepth(1);
  $finder->maxdepth(1);
  my @subdirs = $finder->in($dir);
  return @subdirs;
}

# _extract_plugin()    {{{1
#
# does:   extracts plugin file to temporary plugins directory
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _extract_plugin ($self) {   ## no critic (RequireInterpolationOfMetachars)

  # variables for cmdline command    {{{2
  my $tw         = $CMD_TIDDLYWIKI;
  my $deserial   = $self->_deserializer;
  my $opt_import = '--import';
  my $plugin     = $self->_plugin_input_file->canonpath;
  my $opt_save   = '--savewikifolder';
  my $dir        = $self->_extract_dir->canonpath;

  # run extraction command    {{{2
  my $cmd = [ $tw, $opt_import, $plugin, $deserial, $opt_save, $dir ];
  my ($success, $err_msg, $full, $stdout, $stderr) =
      IPC::Cmd::run(command => $cmd);

  if (not $success) {
    warn "$err_msg\n";
    my $extract = join $SPACE, @{$cmd};
    warn "Extraction command: '$extract'\n";
    die "Error: Plugin extraction command failed\n";
  }

  # check for plugins subdirectory    {{{2
  my $plugins_dir = File::Spec->catdir($dir, 'plugins');
  die "Error: No 'plugins' directory in extracted plugin\n"
      if not -d $plugins_dir;

  # set extracted plugin subdirectory name    {{{2
  my @plugin_dirs  = $self->_dir_subdirs($plugins_dir);
  my $subdir_count = @plugin_dirs;
  if ($subdir_count == 0) {
    die "Error: No plugin directories in extracted content\n";
  }
  if ($subdir_count > 1) {
    my $dirs = join $COMMA_SPACE, @plugin_dirs;
    my $err =
        'Error: Expected 1 plugin directory, ' . "got $subdir_count: $dirs\n";
    die "$err\n";
  }
  $self->_plugin_dir($plugin_dirs[0]);

  # need to have files in plugin directory    {{{2
  my @contents = $self->_dir_contents($self->_plugin_dir->canonpath);
  die "Error: No plugin files extracted\n" if not @contents;    # }}}2

  return;
}

# _output()    {{{1
#
# does:   copies extracted files back to current directory
# params: nil
# prints: feedback
# return: n/a, dies on failure
# notes:  current directory has to be empty
sub _output ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # can't be anything in current directory
  my $cwd          = $self->_cwd->canonpath;
  my @cwd_contents = $self->_dir_contents($cwd);
  die "Error: Output directory must be empty\n" if @cwd_contents;

  # move plugin files to current directory
  my $plugin_dir = $self->_plugin_dir->canonpath;
  my @froms      = $self->_dir_files($plugin_dir);
  for my $from (@froms) {
    File::Copy::move($from, $cwd)
        or croak "Unable to copy '$from' to '$cwd': $OS_ERROR";
  }

  return;
}

# _simplify()    {{{1
#
# does:   simplifies extracted plugin names
# params: nil
# prints: feedback
# return: n/a, dies on failure
# notes:  specifically, if stem '$__plugins_' present in at least one
#         file name, trim longest common stem starting with this from
#         those files; *unless* doing so results in duplicate
#         file names
sub _simplify ($self)
{    ## no critic (RequireInterpolationOfMetachars ProhibitExcessComplexity)

  # get file list    {{{2
  my $dir       = $self->_plugin_dir->canonpath;
  my @fps       = $self->_dir_files($dir);
  my @all_files = sort map { (File::Basename::fileparse($_))[0] } @fps;

  # only interested if start with '$__plugins_'    {{{2
  my $plug_re = qr/\A\$__plugins_/xsm;
  return if not List::SomeUtils::any {/$plug_re/xsm} @all_files;
  my @files = grep {/$plug_re/xsm} @all_files;
  return if scalar @files == 1;

  # find longest matching stem    {{{2
  const my $MIN_STEM_LENGTH = 12;    # '$__plugins_X'
  my $len = $MIN_STEM_LENGTH;
  while ($TRUE) {
    my @stems = map { substr $_, 0, $len } @files;
    my %stem_counts;
    for my $stem (@stems) { $stem_counts{$stem}++; }
    if (scalar keys %stem_counts > 1) {    # no longer all share stem
      $len--;
      last;
    }
    $len++;
  }
  my $full_stem = substr $files[0], 0, $len;
  $full_stem =~ s/(\$)/\\$1/xsm;    # escape leading '$'
  my $matches_full_stem = grep {/\A$full_stem/xsm} @files;
  if ($matches_full_stem != scalar @files) {
    my $err = "Stem = $full_stem, files = " . join $COMMA_SPACE, @files;
    croak $err;
  }

  # check new file names    {{{2
  # - no duplicates
  my %rename    = map  { $_ => $self->_snip($_, $len) } @files;
  my @new_files = grep { !/$plug_re/xsm } @all_files;
  push @new_files, values %rename;
  my %count;
  for my $file (@new_files) { $count{$file}++; }
  my @duplicates = grep { $count{$_} > 1 } keys %count;
  if (@duplicates) {
    say 'Intended to simplify these extracted files:' or croak;
    for (sort @files) {
      say "- $_" or croak;
    }
    say 'Simplification resulted in duplicate files:' or croak;
    for (sort @duplicates) {
      say "- $_" or croak;
    }
    warn "Simplification NOT performed\n";
    return;
  }

  # - check none start with period (i.e., extension only left)
  my @exts = grep {/\A[.]/xsm} values %rename;
  if (@exts) {
    say 'Simplification would have resulted in:' or croak;
    for my $source (sort keys %rename) {
      say "  $source\n  -> $rename{$source}" or croak;
    }
    say 'but these target filename(s) appear to be file extensions:'
        or croak;
    for (sort @exts) {
      say "- $_" or croak;
    }
    ## no critic (ProhibitDuplicateLiteral)
    warn "Simplification NOT performed\n";
    ## use critic
    return;
  }

  # rename files    {{{2
  for my $source_file (keys %rename) {
    my $target_file = $rename{$source_file};
    my $from        = File::Spec->catfile($dir, $source_file);
    my $to          = File::Spec->catfile($dir, $target_file);
    File::Copy::move($from, $to)
        or croak "Unable to rename '$from' to '$to': $OS_ERROR";
  }    # }}}2

  return;
}

# _snip($name, $start)    {{{1
#
# does:   snip stem from file name
# params: $name  - file name [scalar string]
#         $start - where new file name is to start [scalar integer]
# prints: feedback
# return: scalar string, dies on failure
sub _snip ($self, $name, $start)
{    ## no critic (RequireInterpolationOfMetachars)
  my $pruned = substr $name, $start;
  return $pruned;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::TW::Plugin::Split - convert single json or tid TiddlyWiki plugin file

=head1 VERSION

This documentation is for C<App::TW::Plugin::Split> version 0.7.

=head1 SYNOPSIS

    use App::TW::Plugin::Split;
    App::TW::Plugin::Split->new_with_options->run;

B<tw-plugin-split -h>

=head1 DESCRIPTION

This script converts a single C<tid> or C<json> plugin file for
L<TiddlyWiki|https://tiddlywiki.com/> into a group of files which can be used
with a node.js server installation of TiddlyWiki. Each plugin tiddler is output
into one or two files (depending on whether the metadata is contained in the
main tiddler file or split out into a F<meta> file), and the plugin also has a
F<plugin.info> file.

The main work of plugin extraction is done by the node.js version of tiddlywiki
which must be installed on the system. More specifically, the executable
F<tiddlywiki> must be available.

The plugin extraction command is:

    tiddlywiki --import PLUGIN_FILE DESERIALIZER --savewikifolder ./

where DESERIALIZER is C<application/x-tiddler> or C<application/json> for
C<tid> or C<json> plugin files, respectively

=head2 Output file names

All files are output to the current working directory.

Default tiddler file names are derived from tiddler title fields. Most plugin
authors use the title schema F<$:/plugins/AUTHOR/PLUGIN/name>, where AUTHOR is
the plugin author's handle and PLUGIN is the plugin's name. After conversion to
file names, this becomes F<$__plugin_AUTHOR_PLUGIN_name>. For example, the
files extracted from the plugin ContextSeach by danielo515 are:
    $__plugins_danielo515_ContextPlugin_Caption.tid
    $__plugins_danielo515_ContextPlugin_readme.tid
    $__plugins_danielo515_ContextPlugin_Stylesheet_results.css
    $__plugins_danielo515_ContextPlugin_Stylesheet_results.css.meta
    $__plugins_danielo515_ContextPlugin_visualizer.tid
    $__plugins_danielo515_ContextPlugin_widgets_context.js
    $__plugins_danielo515_ContextPlugin_widgets_context.js.meta
    Context Search.tid
    plugin.info

If the C<-s> (C<--simplify>) option is used, plugin files of the form
F<$__plugin_AUTHOR_PLUGIN_name> are changed to F<name>. For the plugin above
the extracted files become:
    Caption.tid
    readme.tid
    Stylesheet_results.css
    Stylesheet_results.css.meta
    visualizer.tid
    widgets_context.js
    widgets_context.js.meta
    Context Search.tid
    plugin.info

In order for the file names to be simplified at least two of the extracted
files must begin with F<$__plugins_>. The longest file stem shared by all files
beginning with F<$__plugins_> is then determined. This stem will be removed
from these file names unless doing so would:

=over

=item

Result in duplicate file names, or

=item

Leave only a file extension remaining. (Actually, the test is just whether the
resulting file name begins with a period - C<.>.)

=back

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties/attributes

None used.

=head2 Required arguments

=head3 plugin_file

Path of the json plugin file to be converted. File path. Required.

=head2 Options

=head3 -f | --format FORMAT

Plugin file format. Optional. Valid values: 'json', 'tid'.

Default: C<json> for files with a F<.json> extension,
C<tid> for all other files.

=head3 -s | --simplify

Whether to simplify the extracted plugin file names.

Flag. Optional. Default: false.

=head3 -h | --help

Display help and exit. Flag. Optional. Default: false.

There are no configuration options for this script.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It converts a single F<tid> or F<json> plugin file for
L<TiddlyWiki|https://tiddlywiki.com/> into a group of files which can be used
with a node.js server installation of TiddlyWiki as described in
L</DESCRIPTION>.

=head1 DIAGNOSTICS

=over

=item Cannot read file 'FILE'

The specified file could not be read. This is usually because the wrong file
path is given, but could possibly occur if the file exists but the user does
not have permission to read it.

=item Expected 1 command line argument, got X

This occurs when too many command line arguments are provided. Be wary of using
wildcards which may inadvertently match more than one file.

=item Expected 1 plugin directory, got X: ...

If the extraction command is successful it should create a F<plugins>
subdirectory which itself contains exactly one plugin-specific subdirectory. If
there are multiple plugin-specific subdirectories then something has gone wrong
with the plugin file extraction process.

=item Expected 1 plugin file format, got X

This error occurs if more than one plugin file format is specified using the
C<-f> (C<--format>) option.

=item Invalid plugin file format '...'

The only valid plugin file formats are "tid" and "json". Supplying any other
option to the C<-f> (C<--format>) option causes this error.

=item Missing executable 'tiddlywiki'

This script requires the node.js version of tiddlywiki which includes an
executable called F<tiddlywiki>.

=item Missing plugin file format '...'

This indicates an internal logic error while determining the plugin file format
and matching deserializer. It should not occur during normal operation.

=item No 'plugins' directory in extracted plugin

If the extraction command is successful it should create a F<plugins>
subdirectory which itself contains a plugin-specific subdirectory. If the
F<plugins> subdirectory is not present then something has gone wrong with the
plugin file extraction process.

=item No file name provided

This occurs when no file name is provided on the command line.

=item No plugin directories in extracted content

If the extraction command is successful it should create a F<plugins>
subdirectory which itself contains a plugin-specific subdirectory. If the
plugin-specific subdirectory is missing then something has gone wrong with the
plugin file extraction process.

=item No plugin files extracted

If the extraction command is successful it should create a F<plugins>
subdirectory which itself contains a plugin-specific subdirectory. The
plugin-specific subdirectory should contains one or more plugin files - if it
does not then something has gone wrong with the plugin file extraction process.

=item Output directory must be empty

This script will abort if the current directory contains any files or
directories.

=item Plugin extraction command failed

If this command fails, the above error message is displayed along with the
system error message that was generated.

=item Stem = STEM, files = FILES at ...

This is a debugging error message that indicates something thought to be
impossible has occurred while analysing the extracted file names. Please report
the full content of this error to the script's author.

=item Unable to copy 'FROM' to 'CWD': ERROR

This error occurs if the operating system is unable to copy the extracted
plugin files from their temporary directory to the current directory. The error
message includes any error message generated by the operating system.

=item Unable to rename FROM to TO: ERROR

This error occurs if the operating system is unable to rename the extracted
plugin files in their temporary directory. The error message includes any error
message generated by the operating system.

=item Unable to write 'FILE'

This occurs when the file system is unable to write to the current directory.

=item Unable to write to console

The script has tried to write a warning or error message to the console but was
unable to do so.

=back

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, English, File::Basename, File::Copy, File::Find::Rule,
File::Spec, File::Which, IPC::Cmd, List::SomeUtils, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, Path::Tiny, strictures, Types::Path::Tiny,
Types::Standard, version.

=head1 AUTHOR

David Nebauer S<< <david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
