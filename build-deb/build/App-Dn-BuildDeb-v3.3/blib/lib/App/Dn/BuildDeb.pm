package App::Dn::BuildDeb;

use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('3.3');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use autodie qw(open close);
use Archive::Tar;
use charnames qw(:full);
use Carp      qw(croak);
use Const::Fast;
use Dpkg::Version;
use Email::Date::Format;
use Email::Valid;
use English;
use Feature::Compat::Try;
use File::Basename;
use File::chdir;    # provides $CWD and @CWD
use File::Copy::Recursive;
use File::Find::Rule;
use File::Spec;
use MooX::HandlesVia;
use MooX::Options protect_argv => 0;
use Path::Tiny;
use Term::Clui;
local $ENV{CLUI_DIR} = 'OFF';
use Term::ReadKey;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE            => 1;
const my $FALSE           => 0;
const my $COMMA_SPACE     => q{, };
const my $FILE_MODE       => '0744';
const my $ERR_SCRIPT_FAIL => 'Script failed';
const my $MSG_RUN_NOW     => 'Running it now...';
const my $SCRIPT => (File::Basename::fileparse($PROGRAM_NAME))[0];    # }}}1

# options

# dist_build  (-d)    {{{1
option 'dist_build' => (
  is    => 'ro',
  short => 'd',
  doc   => 'Build from dist tarzip in debian source dir [optional]',
);

# maint_email (-e)    {{{1
option 'maint_email' => (
  is       => 'ro',
  format   => 's@',
  required => $FALSE,
  default  => sub { [] },
  short    => 'e',
  doc      => 'Email of package maintainer [optional]',
);

# pkg_name    (-p)    {{{1
option 'pkg_name' => (
  is       => 'ro',
  format   => 's@',         ## no critic (ProhibitDuplicateLiteral)
  required => $FALSE,
  default  => sub { [] },
  short    => 'p',
  doc      => 'Name of package [optional]',
);

# root_dir    (-r)    {{{1
option 'root_dir' => (
  is       => 'ro',
  format   => 's@',         ## no critic (ProhibitDuplicateLiteral)
  required => $FALSE,
  default  => sub { [] },
  short    => 'r',
  doc      => 'Root directory of project tree [optional]',
);

# template    (-t)    {{{1
option 'template' => (
  is    => 'ro',
  short => 't',
  doc   => 'Create empty project template [optional]',
);

# update      (-u)    {{{1
option 'update' => (
  is    => 'ro',
  short => 'u',
  doc   => 'Update package versions in debian control file [optional]',
);    # }}}1

# attributes

# _root_dir    {{{1
has '_root_dir' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    Types::Standard::InstanceOf ['Path::Tiny'],
  ],
  default => undef,
  doc     => 'Project root directory',
);

# _maint_email    {{{1
has '_maint_email' => (
  is      => 'rw',
  isa     => Types::Standard::Maybe [Types::Standard::Str],
  default => undef,
  doc     => 'Email address of package maintainer',
);

# _pkg_name    {{{1
has '_pkg_name' => (
  is      => 'rw',
  isa     => Types::Standard::Maybe [Types::Standard::Str],
  default => undef,
  doc     => 'Name of package',
);

# _mode    {{{1
has '_mode' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [Types::Standard::Str],
  doc => 'Calling mode (template|build|update)',
);

# _tar_archive    {{{1
has '_tar_archive' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Archive directory in autotools build tree',
);

# _tar_auto    {{{1
has '_tar_auto' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Autotools directory in autotools build tree',
);

# _tar_build    {{{1
has '_tar_build' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Build directory in autotools build tree',
);

# _tar_source    {{{1
has '_tar_source' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Source directory in autotools build tree',
);

# _deb_debian    {{{1
has '_deb_debian' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Debian files directory in debian build tree',
);

# _deb_scripts    {{{1
has '_deb_scripts' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Scripts directory in debian build tree',
);

# _deb_source    {{{1
has '_deb_source' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Source directory in debian build tree',
);

# _tar_prep    {{{1
has '_tar_prep' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Bash file run to prepare tarbuild directory files',
);

# _deb_prep    {{{1
has '_deb_prep' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Bash file run to prepare debian directory files',
);

# _wrapper    {{{1
has '_wrapper' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Wrapper for this script',
);

# _tar_auto_conf_ac    {{{1
has '_tar_auto_conf_ac' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'configure.ac file in tarball/autotools directory',
);

# _tar_auto_conf_ac_regex    {{{1
has '_tar_auto_conf_ac_regex' => (
  is      => 'rw',
  isa     => Types::Standard::Maybe [Types::Standard::RegexpRef],
  default => undef,
  doc     => 'Regex finding version in configure.ac file',
);

# [_set]_conf_ac_part    {{{1
has '_tar_auto_conf_ac_parts' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Standard::Str],
  lazy        => $TRUE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    _set_conf_ac_part => 'set',    # ($x => 'part')
    _conf_ac_part     => 'get',    # ($x) -> 'part'
  },
  doc => 'Parts of configure.ac file',
);

# _deb_debian_changelog    {{{1
has '_deb_debian_changelog' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'changelog file in debianise/debian directory',
);

# _deb_debian_changelog_regex    {{{1
has '_deb_debian_changelog_regex' => (
  is      => 'rw',
  isa     => Types::Standard::Maybe [Types::Standard::RegexpRef],
  default => undef,
  doc     => 'Regex finding version in changelog file',
);

# [_set]_changelog_part    {{{1
has '_deb_debian_changelog_parts' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Standard::Str],
  lazy        => $TRUE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    _set_changelog_part => 'set',    # ($x => 'part')
    _changelog_part     => 'get',    # ($x) -> 'part'
  },
  doc => 'Parts of changelog file',
);

# _deb_debian_control    {{{1
has '_deb_debian_control' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'control file in debianise/debian directory',
);

# _tar_conf    {{{1
has '_tar_conf' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'configure file in tarball/build directory',
);

# _deb_pkg    {{{1
has '_deb_pkg' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => undef,
  doc     => 'Package (*.deb) file in debianise/source directory',
);

# _project_dirs, _add_project_dirs    {{{1
has '_project_dirs_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _project_dirs     => 'elements',
    _add_project_dirs => 'push',
  },
  doc => 'Directories required for standard autotools projects',
);

# _divider    {{{1
has '_divider' => (
  is      => 'rw',
  isa     => Types::Standard::Maybe [Types::Standard::Str],
  default => undef,
  doc     => 'Divider consisting of dashes',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # process parameters
  $self->_process_params;

  # set attributes
  $self->_set_attributes;

  # handle calling mode
  my $mode = $self->_mode;
  ## no critic (ProhibitDuplicateLiteral)
  if    ($mode eq 'template') { $self->_template_mode; }
  elsif ($mode eq 'update')   { $self->_update_mode; }
  elsif ($mode eq 'build')    { $self->_build_mode; }
  else                        { die "Invalid mode '$mode'\n"; }
  ## use critic

  # install file (currently disabled by design)
  #$self->_install_package;

  return $TRUE;
}

# _attr_string($opt)    {{{1
#
# does:  extract string value for attribute from option
# params: $opt - array reference, should hold one value [required]
# prints: nil
# return: boolean, whether non-empty string extracted
sub _attr_string ($self, $opt)
{    ## no critic (RequireInterpolationOfMetachars)
  my $attr;
  my @attrs = @{$opt};
  if (@attrs) { $attr = $attrs[0]; }

  return $attr;
}

# _attr_dir(@parts)    {{{1
#
# does:   create Path::Tiny object for directory relative to project root
# params: @parts - list of directory parts [required]
# prints: feedback on error
# return: n/a, dies on failure
sub _attr_dir ($self, @parts) { ## no critic (RequireInterpolationOfMetachars)
  my $root    = $self->_root_dir->canonpath;
  my $dir_str = $self->dir_join($root, @parts);
  my $dir     = Path::Tiny::path($dir_str)->absolute;

  return $dir;
}

# _attr_fp(@parts)    {{{1
#
# does:   create Path::Tiny object for filepath relative to project root
# params: @parts - list of filepath parts [required]
# prints: feedback on error
# return: n/a, dies on failure
sub _attr_fp ($self, @parts)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitDuplicateLiteral)
  my $root   = $self->_root_dir->canonpath;
  my $fp_str = $self->path_join($root, @parts);
  my $fp     = Path::Tiny::path($fp_str)->absolute;

  return $fp;
}

# _build_mode()    {{{1
#
# does:   build autotools project and debianise it
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _build_mode ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # build distribution tarball
  if ($self->dist_build) {
    say 'Got -d flag: skipping build step, expect single tarball'
        or croak;
  }
  else {
    $self->_build_tarball;
  }

  # debianise source
  $self->_debianise;

  return;
}

# _build_tarball()    {{{1
#
# does:   build distribution tarball in tarball/build
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _build_tarball ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # change package version if desired    {{{2
  $self->_bump_package_version;

  # delete contents of build directory    {{{2
  my $tar_build = $self->_tar_build;
  $self->dir_clean($tar_build->canonpath);

  # copy contents of autotools and source to build    {{{2
  my @dirs = ($self->_tar_auto, $self->_tar_source);
  for my $dir (@dirs) {
    File::Copy::Recursive::dircopy($dir->canonpath, $tar_build->canonpath)
        or die "Unable to copy into build directory: $ERRNO\n";
  }

  # from now on, all commands are run in 'tarball/build'    {{{2
  # - Perl::Critic does not realise that $CWD is a package variable
  ## no critic (Variables::ProhibitLocalVars)
  local $CWD = $self->_tar_build->canonpath;
  ## use critic

  # run project-specific changes to project source    {{{2
  my $tar_prep = $self->_tar_prep;
  if ($tar_prep->is_file) {
    say q{Located a 'tar_dir_prepare' script} or croak;
    say $MSG_RUN_NOW                          or croak;
    {
      my @cmd = ($tar_prep->canonpath);
      $self->run_command($ERR_SCRIPT_FAIL, @cmd);
    }
  }

  # run 'autoreconf'    {{{2
  say 'Building distribution tarball' or croak;
  say q{..running 'autoreconf':}      or croak;
  {
    my @cmd = qw(autoreconf --install);
    my $err = 'autoreconf failed';
    $self->run_command($err, @cmd);
  }

  # escape special filename chars in configure    {{{2
  say q{..escape special filename characters in './configure'} or croak;

  my $conf = $self->_tar_conf;
  die "Cannot locate 'build/configure' file\n" if not $conf->is_file;
  $self->_escape_fname_chars_in_conf;

  # run './configure'    {{{2
  say q{..running './configure':} or croak;
  $conf->chmod($FILE_MODE);
  {
    my @cmd = qw(./configure);
    my $err = './configure failed';
    $self->run_command($err, @cmd);
  }

  # run 'make dist'    {{{2
  say q{..running 'make dist':} or croak;
  {
    my @cmd = qw(make dist);
    my $err = 'make dist failed';
    $self->run_command($err, @cmd);
  }

  # copy tarball to tar/archive directory    {{{2
  say 'Archiving tarball' or croak;
  my $dist;
  {
    my @children  = $tar_build->children(qr/[.]tar[.]gz\z/xsm);
    my $kid_count = @children;
    die "Expected 1 '.tar.gz' file, got $kid_count\n"
        if $kid_count != 1;
    $dist = $children[0];
    my $tar_archive = $self->_tar_archive;
    File::Copy::Recursive::fcopy($dist->canonpath, $tar_archive->canonpath)
        or croak "Unable to archive tarball: $ERRNO";
  }

  # copy tarball to deb/source directory    {{{2
  say 'Copying tarball to debianise/source directory' or croak;
  {
    my $deb_source = $self->_deb_source;
    $self->dir_clean($deb_source->canonpath);
    File::Copy::Recursive::fcopy($dist->canonpath, $deb_source->canonpath)
        or croak "Unable to copy tarball to deb source dir: $ERRNO";
  }

  return;    # }}}2

}

# _bump_package_version()    {{{1
#
# does:   update package version in tar_auto/configure.ac and
#         deb_debian/changelog
#
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _bump_package_version ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # check existing version details    {{{2
  # - changelog version includes debian revision, but
  #   configure.ac version does not include debian revision
  ## no critic (ProhibitDuplicateLiteral)
  my $conf_version   = $self->_conf_ac_part('version');
  my $change_version = $self->_changelog_part('version');
  ## use critic
  if ($conf_version and $change_version) {
    if ($conf_version ne (split /-/xsm, $change_version)[0]) {
      die "Version mismatch between configure.ac and changelog\n";
    }
  }
  else {
    if (not $conf_version and not $change_version) {
      die 'Unable to extract version from ' . "configure.ac and changelog\n";
    }
    elsif (not $conf_version) {
      die "Extracted version '$change_version' from changelog, "
          . "but unable to extract version from configure.ac\n";
    }
    else {
      die "Extracted version '$conf_version' from configure.ac, "
          . "but unable to extract version from changelog\n";
    }
  }
  my $version_current = Dpkg::Version->new($change_version);
  if (not $version_current->is_valid) {
    die "Help! Current version $conf_version is invalid!\n";
  }

  # get new version from user    {{{2
  say "Current package version: $version_current" or croak;
  my $prompt = 'Enter package version:';
  my $input  = Term::Clui::ask($prompt);
  if (not $input) {
    say 'Remaining at current version' or croak;
    return;
  }
  if (not $input =~ /-/xsm) { $input .= '-1'; }
  my $version_new = Dpkg::Version->new($input);
  if (not $version_new->is_valid) {
    die "Invalid version: $input\n";
  }
  if ($version_new < $version_current) {
    die "New version cannot be lower than current version\n";
  }
  if (not($version_new > $version_current)) {    # equal
    ## no critic (ProhibitDuplicateLiteral)
    say 'Remaining at current version' or croak;
    ## use critic
    return;
  }

  # bump version in configure.ac    {{{2
  my $conf_data =
        $self->_conf_ac_part('pre')
      . (split /-/xsm, $version_new->as_string)[0]
      . $self->_conf_ac_part('post');
  my $conf = $self->_tar_auto_conf_ac;
  $conf->spew_utf8($conf_data);

  # bump version in changelog    {{{2
  my $date      = Email::Date::Format::email_date;
  my $changelog = $self->_deb_debian_changelog;
  my $changelog_data =
        $self->_changelog_part('pkg') . ' ('
      . $version_new->as_string . ') '
      . $self->_changelog_part('release') . '; '
      . $self->_changelog_part('urgency')
      . "\n\n  * \n\n"
      . $self->_changelog_part('maint') . q{  }
      . $date . "\n\n"
      . $changelog->slurp_utf8;
  $changelog->spew_utf8($changelog_data);
  say 'Press any key to enter release notes...' or croak;
  Term::ReadKey::ReadMode 'cbreak';
  Term::ReadKey::ReadKey(0);
  Term::ReadKey::ReadMode 'normal';
  Term::Clui::edit($changelog->canonpath);    # }}}2

  return;
}

# _changelog_version_regex()    {{{1
#
# does:   provide regex for finding version in the
#         debianise/debian-files/changelog file
#
# params: nil
# prints: nil
# return: scalar regex
sub _changelog_version_regex ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # assume first line of changelog file is well-formed, i.e., like:
  #   dn-cronsudo (2.1-2) UNRELEASED; urgency=low
  # so just assume first pair of parentheses encloses:
  #   package_version-debian_revision

  # building blocks
  my $any = qr/.*?/xsm;

  # in $any can't enclose '.' in a character class ('[.]')
  # because then it wouldn't match newlines
  # (see 'Metacharacters' section in 'perlre' manpage)
  # so need to disable related Perl::Critic warnings

  # first capture: package name

  my $pkg = qr{
            (?<pkg>    # first capture is package name
            \A\S+      # package name
            )          # close capture
            \s+        # followed by space
        }xsm;

  # second capture: version+revision

  ## no critic (ProhibitEscapedMetacharacters)
  my $version = qr{
            \(             # enclosed in parentheses
            (?<version>    # commence capture of version+revision
            [^\)]+         # version+revision
            )              # close second capture
            \)             # enclosed in parentheses
            \s+            # followed by space
        }xsm;
  ## use critic

  # third capture: release

  my $release = qr{
            (?<release>    # commence capture of release
            [^;]+          # release
            )              # close third capture
            ;\s+           # followed by semicolon and space
        }xsm;

  # fourth capture: urgency

  my $urgency = qr{
            (?<urgency>    # commence capture of urgency
            .*?$           # remainder of line
            )              # close fourth capture
            $any           # followed by any content
        }xsm;

  # fifth capture: maintainer

  my $maint = qr{
            (?<maint>    # commence capture of maintainer
            ^[ ]+--\s+   # leading double hyphen
            [^\>]+>      # maintainer name and then <email_address>
            )            # close fifth capture
        }xsm;

  return qr{ $pkg $version $release $urgency $maint }xsm;
}

# _configure_ac_version_regex()    {{{1
#
# does:   provide regex for finding version in the
#         tarball/autotools/configure.ac file
#
# params: nil
# prints: nil
# return: scalar regex
sub _configure_ac_version_regex ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # building blocks
  my $any = qr/.*?/xsm;
  my $arg = qr{
            \[.*?\]    # argument, enclosed in square brackets
            $any  # interargument characters, may include newline
        }xsm;

  # in $any can't enclose '.' in a character class ('[.]')
  # because then it wouldn't match newlines
  # (see 'Metacharacters' section in 'perlre' manpage)
  # so need to disable related Perl::Critic warnings

  # first capture: all of file before version

  ## no critic (ProhibitEscapedMetacharacters)
  my $pre_version = qr{
            (?<pre>    # first capture is all of file before version
            \A$any     # capture from beginning of file
            AC_INIT    # version is an argument to the AC_INIT macro
            $any       # chars between macro name and opening '('
            \(         # open arguments for AC_INIT macro
            $arg       # first AC_INIT argument: description
            \[         # opening brace of second argument
            )          # close first capture
        }xsm;
  ## use critic

  # second capture: version

  my $version = qr{
            (?<version>    # second capture is version
            $any           # second AC_INIT argument: version
            )              # close second capture
        }xsm;

  # third capture: all of file after version

  ## no critic (ProhibitEscapedMetacharacters)
  my $post_version = qr{
            (?<post>     # third capture is all of file after version no.
            \]           # closing brace of second argument
            $any         # interargument chars, may include newline
            $arg         # third AC_INIT argument: maintainer email
            $arg         # fourth AC_INIT argument: distribution name
            \)           # close AC_INIT macro
            $any\z       # include remainder of file
            )
        }xsm;
  ## use critic

  return qr{ $pre_version $version $post_version }xsm;
}

# _debianise()    {{{1
#
# does:   debianise distribution source
#
# params: nil
# prints: feedback on error
# return: n/a, dies on failure
sub _debianise ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # note that Perl::Critic does not see that $CWD is a package variable

  # extract tarball    {{{2
  my $deb_source = $self->_deb_source;
  ## no critic (Variables::ProhibitLocalVars)
  local $CWD = $deb_source->canonpath;
  ## use critic
  my $tarball;
  {
    my @children   = $deb_source->children;
    my $kids_count = @children;
    croak "Expected 1 file in debianise/source, got $kids_count"
        if $kids_count != 1;
    $tarball = $children[0];
    say 'Extracting source from distribution archive' or croak;
    my $extract   = Archive::Tar->new($tarball->canonpath);
    my $extracted = $extract->extract;
    croak "Unable to extract source: $ERRNO" if not $extracted;
  }
  my $source_base;
  {
    my @dir_children = $self->dir_list($deb_source->canonpath);
    my $kids_count   = @dir_children;
    croak "Expected 1 directory, got $kids_count" if $kids_count != 1;
    $source_base = Path::Tiny::path($dir_children[0])->absolute;
  }

  # initial debianisation with dh_make    {{{2
  say q{Initial debianisation using 'dh_make':} or croak;
  ## no critic (Variables::ProhibitLocalVars)
  local $CWD = $source_base->canonpath;
  ## use critic
  {
    my @cmd = (
      'dh_make', '--single', '--email', $self->_maint_email,
      '--file',  $tarball->canonpath,
    );
    my $err = 'dh_make failed';
    $self->run_command($err, @cmd);
  }

  # copy customised files to debian subdirectory    {{{2
  say 'Copying customised files to debian subdirectory' or croak;
  my $debian;
  {
    # Path::Tiny::children() requires qr// even for fixed string match
    ## no critic (RegularExpressions::ProhibitFixedStringMatches)
    my @children = $source_base->children(qr/\Adebian\z/xsm);
    ## use critic
    my $kids_count = @children;
    croak "Expected 1 'debian' child, got $kids_count"
        if $kids_count != 1;
    $debian = $children[0];
    croak q{'debian' is not a directory} if not $debian->is_dir;
    $self->dir_clean($debian);
    my $custom = $self->_deb_debian;
    File::Copy::Recursive::dircopy($custom->canonpath, $debian->canonpath)
        or die "Unable to copy custom debian files: $ERRNO\n";
  }

  # replace package name placeholder in control files    {{{2
  # - placeholder is '@pkg_name@'
  say 'Replacing package name placeholder in debian control files'
      or croak;
  {
    my $pkg      = $self->pkg_name;
    my @children = grep { $_->is_file } $debian->children;
    for my $child (@children) {
      my $content = $child->slurp_utf8;
      $content =~ s/\@pkg_name\@/$pkg/xsmg;
      my @new_content = split /\n/xsm, $content;
      $self->file_write([@new_content], $child);
    }
  }

  # run project-specific changes to project source    {{{2
  my $deb_prep = $self->_deb_prep;
  if ($deb_prep->is_file) {
    say q{Located a 'deb_dir_prepare' script} or croak;
    say $MSG_RUN_NOW                          or croak;
    {
      my @cmd = ($deb_prep->canonpath);
      $self->run_command($ERR_SCRIPT_FAIL, @cmd);
    }
  }

  # build package    {{{2
  say q{Build package ['dpkg-buildpackage -rfakeroot -us -uc']:}
      or croak;
  {
    my @cmd = qw(dpkg-buildpackage -rfakeroot -us -uc);
    my $err = 'Package build failed';
    $self->run_command($err, @cmd);
  }

  # check for package file    {{{2
  {
    my @children   = $deb_source->children(qr/[.]deb\z/xsm);
    my $kids_count = @children;
    croak "Expected 1 package file, got $kids_count"
        if $kids_count != 1;
    my $pkg = $children[0];
    croak "$pkg is not a file" if not $pkg->is_file;
    $self->_deb_pkg($pkg);
    say 'Debian package build is complete' or croak;
  }    # }}}2

  return;
}

# _escape_fname_chars_in_conf()    {{{1
#
# does:   backslash-escape filenames in 'tarball/build/configure' file
#
# params: nil
# prints: feedback on error
# return: n/a, dies on failure
# note:   only character currently escaped in ampersand ('&')
sub _escape_fname_chars_in_conf ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # characters to escape    {{{2
  my @chars = qw(&);

  # filenames to escape    {{{2
  my $tar_build = $self->_tar_build;
  my @fps       = File::Find::Rule->file()->in($tar_build->canonpath);
  my @fnames;
  {
    # - strip directory path
    my $sep          = File::Spec->catfile(q{}, q{});
    my $base_dirpath = $tar_build->canonpath . $sep;
    my @fnames_in    = map {s/\A$base_dirpath//xsmr} @fps;

    # - strip '.in' suffix
    push @fnames, map {s/[.]in\z//xsmr} @fnames_in;
  }

  # get content of configure file    {{{2
  my $conf    = $self->_tar_conf;
  my $content = $conf->slurp_utf8;

  # escape filenames in configure file content    {{{2
  for my $char (@chars) {
    my $escaped_char = q{\\} . $char;
    for my $fname (@fnames) {
      my $escaped_fname = $fname =~ s/$char/$escaped_char/xsmgr;

      # - put '.' in 1-char character class so is not wildcard
      $fname   =~ s/[.]/\[.\]/xsmg;
      $content =~ s/$fname/$escaped_fname/xsmg;
    }
  }

  # write edited content back to configure file    {{{2
  my @new_content = split /\n/xsm, $content;
  $self->file_write([@new_content], $conf);    # }}}2

  return;
}

# _install_package()    {{{1
#
# does:   install debian package
#
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _install_package ($self)
{ ## no critic (RequireInterpolationOfMetachars, ProhibitUnusedPrivateSubroutines)

  my $pkg_fp  = $self->_deb_pkg->canonpath;
  my $divider = $self->_divider;

  # first, try 'sudo dpkg'
  say q{Installing package using 'sudo dpkg':} or croak;
  my @cmd     = ('sudo', 'dpkg', '-i', $pkg_fp);
  my $success = $TRUE;
  say $divider or croak;
  if (system @cmd) { $success = $FALSE; }
  say $divider or croak;
  if ($success) {
    say 'Install complete' or croak;
    return;
  }

  # second, try 'su -c dpkg'
  say q{Okay, that failed - let's try as superuser} or croak;
  say 'Enter root password'                         or croak;
  @cmd     = ('su', '-c', "dpkg -i $pkg_fp");
  $success = $TRUE;
  say $divider or croak;
  if (system @cmd) { $success = $FALSE; }
  say $divider or croak;
  ## no critic (ProhibitDuplicateLiteral)
  if ($success) { say 'Install complete' or croak; }
  else          { warn "Install failed\n"; }
  ## use critic

  return;
}

# _process_params()    {{{1
#
# does:   process params checking for conflicting or missing options
#
# params: nil
# prints: feedback on error
# return: n/a, dies on failure
sub _process_params ($self) {   ## no critic (RequireInterpolationOfMetachars)

  # set primary derived option parameters    {{{2
  # - project root directory (default: cwd)
  {
    my $root_dir = $self->_attr_string($self->root_dir);
    if (not $root_dir) { $root_dir = $self->dir_current; }
    my $dir = Path::Tiny::path($root_dir)->realpath;
    die "Project root '$root_dir' is not a directory\n"
        if not $dir->is_dir;
    $self->_root_dir($dir);
  }

  # - maintainer email
  {
    my $maint_email = $self->_attr_string($self->maint_email);
    if ($maint_email) {
      die "Invalid maintainer email address: $maint_email\n"
          if not Email::Valid->address($maint_email);
      $self->_maint_email($maint_email);
    }
  }

  # - package name
  {
    my $pkg_name = $self->_attr_string($self->pkg_name);
    if ($pkg_name) { $self->_pkg_name($pkg_name); }
  }

  # cannot be in template and update modes simultaneously    {{{2
  if ($self->template and $self->update) {
    die "Cannot use both -t and -u\n";
  }

  # template mode requirements    {{{2
  # - must have maint_email and pkg_name
  if ($self->template) {
    my @missing;
    if (not $self->_maint_email) { push @missing, '-e'; }
    if (not $self->_pkg_name)    { push @missing, '-p'; }
    if (@missing) {
      my $frag = join $COMMA_SPACE, @missing;
      die "-t option requires $frag\n";
    }
  }

  # update mode requirements    {{{2
  # - no required options

  # build mode requirements    {{{2
  # - must have maint_email and pkg_name
  if ($self->template) {
    my @missing;
    ## no critic (ProhibitDuplicateLiteral)
    if (not $self->_maint_email) { push @missing, '-e'; }
    if (not $self->_pkg_name)    { push @missing, '-p'; }
    ## use critic
    if (@missing) {
      my $frag = join $COMMA_SPACE, @missing;
      die "Building debian package requires $frag\n";
    }
  }    # }}}2

  return;
}

# _set_attributes()    {{{1
#
# does:   set attributes
# params: nil
# prints: feedback on error
# return: n/a, dies on failure
sub _set_attributes ($self)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitExcessComplexity)

  # track project directory locations    {{{2
  my @project_dirs;

  # set mode    {{{2
  # - assume params checked for conflicts and completeness
  #   (in '_process_params' method)
  {
    ## no critic (ProhibitDuplicateLiteral)
    if    ($self->template) { $self->_mode('template'); }
    elsif ($self->update)   { $self->_mode('update'); }
    else                    { $self->_mode('build'); }
    ## use critic
  }
  my $mode = $self->_mode;

  # set tarball archive directory path    {{{2
  # - must exist in build mode
  {
    my $tar_archive = $self->_attr_dir('tarball', 'archive');
    my %modes       = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $tar_archive->is_dir) {
      my $msg =
          'Missing tarball/archive directory' . q{, perhaps '-t' is missing?};
      die "$msg\n";
    }
    $self->_tar_archive($tar_archive);
    push @project_dirs, $tar_archive;
  }

  # set tarball autotools directory path    {{{2
  # - must exist in build mode
  {
    ## no critic (ProhibitDuplicateLiteral)
    my $tar_auto = $self->_attr_dir('tarball', 'autotools');
    ## use critic
    my %modes = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $tar_auto->is_dir) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg = 'Missing tarball/autotools directory'
          . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_tar_auto($tar_auto);
    push @project_dirs, $tar_auto;
  }

  # set tarball build directory path    {{{2
  # - must exist in build mode
  {
    ## no critic (ProhibitDuplicateLiteral)
    my $tar_build = $self->_attr_dir('tarball', 'build');
    ## use critic
    my %modes = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $tar_build->is_dir) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg =
          'Missing tarball/build directory' . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_tar_build($tar_build);
    push @project_dirs, $tar_build;
  }

  # set tarball source directory path    {{{2
  # - must exist in build mode
  {
    ## no critic (ProhibitDuplicateLiteral)
    my $tar_source = $self->_attr_dir('tarball', 'source');
    ## use critic
    my %modes = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $tar_source->is_dir) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg =
          'Missing tarball/source directory' . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_tar_source($tar_source);
    push @project_dirs, $tar_source;
  }

  # set debianise debian files directory path    {{{2
  # - must exist in build and update modes
  {
    my $deb_debian = $self->_attr_dir('debianise', 'debian-files');
    my %modes      = map { $_ => $TRUE } qw(build update);
    if ($modes{$mode} and not $deb_debian->is_dir) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg = 'Missing debianise/debian-files directory'
          . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_deb_debian($deb_debian);
    push @project_dirs, $deb_debian;
  }

  # set debianise scripts directory path    {{{2
  # - must exist in build mode
  {
    ## no critic (ProhibitDuplicateLiteral)
    my $deb_scripts = $self->_attr_dir('debianise', 'scripts');
    ## use critic
    my %modes = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $deb_scripts->is_dir) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg = 'Missing debianise/scripts directory'
          . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_deb_scripts($deb_scripts);
    push @project_dirs, $deb_scripts;
  }

  # set debianise source directory path    {{{2
  # - must exist in build mode
  {
    ## no critic (ProhibitDuplicateLiteral)
    my $deb_source = $self->_attr_dir('debianise', 'source');
    ## use critic
    my %modes = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $deb_source->is_dir) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg = 'Missing debianise/source directory'
          . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_deb_source($deb_source);
    push @project_dirs, $deb_source;
  }

  # set list of project directories    {{{2
  if (@project_dirs) { $self->_add_project_dirs(@project_dirs); }

  # set file path to tarball directory preparation script    {{{2
  # - must exist in no mode
  {
    my @dir_parts = qw( debianise scripts tar-dir-prepare );
    my $tar_prep  = $self->_attr_fp(@dir_parts);
    $self->_tar_prep($tar_prep);
  }

  # set file path to debianise directory preparation script    {{{2
  # - must exist in no mode
  {
    my @dir_parts = qw( debianise scripts deb-dir-prepare );
    my $deb_prep  = $self->_attr_fp(@dir_parts);
    $self->_deb_prep($deb_prep);
  }

  # set file path to wrapper for this script    {{{2
  # - must exist in build mode
  {
    my @dir_parts = qw( debianise scripts build-deb );
    my $wrapper   = $self->_attr_fp(@dir_parts);
    my %modes     = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $wrapper->is_file) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg = 'Missing debianise/scripts/build-deb'
          . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_wrapper($wrapper);
  }

  # set file path to configure.ac file    {{{2
  # - must exist in build mode
  {
    my @dir_parts        = qw( tarball autotools configure.ac );
    my $tar_auto_conf_ac = $self->_attr_fp(@dir_parts);
    my %modes            = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $tar_auto_conf_ac->is_file) {
      die "Missing $tar_auto_conf_ac, perhaps '-t' is missing?\n";
    }
    $self->_tar_auto_conf_ac($tar_auto_conf_ac);
  }

  # set file path to changelog file    {{{2
  # - must exist in build mode
  {
    my @dir_parts            = qw( debianise debian-files changelog );
    my $deb_debian_changelog = $self->_attr_fp(@dir_parts);
    my %modes                = map { $_ => $TRUE } qw(build);
    if ($modes{$mode} and not $deb_debian_changelog->is_file) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg =
          "Missing $deb_debian_changelog" . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_deb_debian_changelog($deb_debian_changelog);
  }

  # set file path to control file    {{{2
  # - must exist in build and update modes
  {
    my @dir_parts          = qw( debianise debian-files control );
    my $deb_debian_control = $self->_attr_fp(@dir_parts);
    my %modes              = map { $_ => $TRUE } qw(build update);
    if ($modes{$mode} and not $deb_debian_control->is_file) {
      ## no critic (ProhibitDuplicateLiteral)
      my $msg = "Missing $deb_debian_control" . q{, perhaps '-t' is missing?};
      ## use critic
      die "$msg\n";
    }
    $self->_deb_debian_control($deb_debian_control);
  }

  # set file path to configure file    {{{2
  # - must exist in no mode
  {
    my @dir_parts = qw( tarball build configure );
    my $tar_conf  = $self->_attr_fp(@dir_parts);
    $self->_tar_conf($tar_conf);
  }

  # set regex and file parts for configure.ac file    {{{2
  # - used in build mode
  {
    my %modes = map { $_ => $TRUE } qw(build);
    if ($modes{$mode}) {
      my $re = $self->_configure_ac_version_regex;
      $self->_tar_auto_conf_ac_regex($re);
      my $tar_auto_conf_ac = $self->_tar_auto_conf_ac;
      my $data             = $tar_auto_conf_ac->slurp_utf8;
      if ($data =~ $re) {
        ## no critic (ProhibitDuplicateLiteral)
        $self->_set_conf_ac_part(pre     => $LAST_PAREN_MATCH{'pre'});
        $self->_set_conf_ac_part(version => $LAST_PAREN_MATCH{'version'});
        $self->_set_conf_ac_part(post    => $LAST_PAREN_MATCH{'post'});
        ## use critic
      }
      else {
        die "Unable to extract version from configure.ac\n";
      }
    }
  }

  # set regex and file parts for changelog file    {{{2
  # - used in build mode
  {
    my %modes = map { $_ => $TRUE } qw(build);
    if ($modes{$mode}) {
      my $re = $self->_changelog_version_regex;
      $self->_deb_debian_changelog_regex($re);
      my $deb_debian_changelog = $self->_deb_debian_changelog;
      my $data                 = $deb_debian_changelog->slurp_utf8;
      if ($data =~ $re) {
        ## no critic (ProhibitDuplicateLiteral)
        $self->_set_changelog_part(pkg     => $LAST_PAREN_MATCH{'pkg'});
        $self->_set_changelog_part(version => $LAST_PAREN_MATCH{'version'});
        $self->_set_changelog_part(release => $LAST_PAREN_MATCH{'release'});
        $self->_set_changelog_part(urgency => $LAST_PAREN_MATCH{'urgency'});
        $self->_set_changelog_part(maint   => $LAST_PAREN_MATCH{'maint'});
        ## use critic
      }
      else {
        die "Unable to extract version from changelog\n";
      }
    }
  }

  # set divider    {{{2
  {
    $self->_divider($self->divider);
  }    # }}}2

  return;
}

# _template_mode()    {{{1
#
# does:   create empty project template
#
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _template_mode ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # project root directory must be empty
  my $root     = $self->_root_dir->canonpath;
  my @contents = $self->_root_dir->children;
  die "Project root directory is not empty: $root\n" if @contents;

  # create project directories
  # - 'dir_make' method prints system errors if dir creation fails
  my @dirs = $self->_project_dirs;
  if (not $self->dir_make(@dirs)) { die "Aborting...\n"; }

  # create scripts
  $self->_write_tar_prep;
  $self->_write_deb_prep;
  $self->_write_wrapper;

  say "Created template in: $root" or croak;
  return;
}

# _update_mode()    {{{1
#
# does:   update version values in debian control file
#
# params: nil
# prints: nil
# return: n/a, dies on failure
sub _update_mode ($self)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitExcessComplexity)

  # method variables    {{{2
  my (%update, %keep, @manual);
  my $compat_key  = 'Compatibility level';
  my $stndver_key = 'Standards version';

  # get file content    {{{2
  my $deb_control = $self->_deb_debian_control;
  my $content     = $deb_control->slurp_utf8;

  # check debhelper compatibility value    {{{2
  {
    my $re      = qr{ debhelper-compat [ ]+ [(] [ ]* = [ ]* (\d+) [)] }xsm;
    my @matches = $content =~ $re;
    if (scalar @matches == 1) {
      my $existing = $matches[0];
      my $current  = $self->debhelper_compat;
      if ($current > $existing) {
        $update{$compat_key} = { exist => $existing, current => $current };
      }
      else { $keep{$compat_key} = $current; }
    }
    else { push @manual, $compat_key; }
  }

  # check standards version value    {{{2
  {
    my $re      = qr{ ^ Standards-Version: [ ]+ (.*?) [ ]* $ }xsm;
    my @matches = $content =~ $re;
    if (scalar @matches == 1) {
      my $existing = Dpkg::Version->new($matches[0]);
      die "Invalid existing standards version: $existing\n"
          if not $existing->is_valid;
      my $current = Dpkg::Version->new($self->debian_standards_version());
      die "Invalid current standards version: $current\n"
          if not $current->is_valid;
      if ($current > $existing) {
        $update{$stndver_key} = {
          exist   => $existing->as_string,
          current => $current->as_string,
        };
      }
      else { $keep{$stndver_key} = $current->as_string; }
    }
    else { push @manual, $stndver_key; }
  }

  # extract package names and versions {{{2
  my %pkg_version;
  {
    # extract 'Build-Depends' field from control file
    my $re_build_depends      = qr{ ^ Build-Depends: [ ]+ (.*?) \n \S }xsm;
    my @matches_build_depends = $content =~ $re_build_depends;
    croak q{Unable to extract 'Build-Depends' field value}
        if scalar @matches_build_depends != 1;

    # extract 'Depends' field from control file
    my $re_depends      = qr{ ^ Depends: [ ]+ (.*?) \n \S }xsm;
    my @matches_depends = $content =~ $re_depends;
    croak q{Unable to extract 'Depends' field value}
        if scalar @matches_depends != 1;

    # get package versions from extracted fields
    my $extract =
        $matches_build_depends[0] . $COMMA_SPACE . $matches_depends[0];
    my $re_extract      = qr{ (\S+ [ ]+ [(] >? = [ ]* \S+ [)]) }xsm;
    my @matches_extract = $extract =~ /$re_extract/xsmg;
    for my $match (@matches_extract) {
      my $any      = qr/.*?/xsm;
      my $re_match = qr{ \A (?<pkg>\S+) [ ]+ [(] [ ]* (?<op> >? =)
                                   [ ]* (?<ver>\S+) [)] \z }xsm;
      $match =~ $re_match;
      my $pkg =
          $LAST_PAREN_MATCH{'pkg'};    ## no critic (ProhibitDuplicateLiteral)
      my $op  = $LAST_PAREN_MATCH{'op'};
      my $ver = $LAST_PAREN_MATCH{'ver'};
      if (not $pkg or not $op or not $ver) {
        my @msg = (
          'Unable to extract package name and version',
          " from control file data fragment: $match\n",
        );
        croak @msg;
      }
      $pkg_version{$pkg} = {
        ver => Dpkg::Version->new($ver),
        op  => $op,
      };
    }
    ## no critic (ProhibitDuplicateLiteral)
    if (exists $pkg_version{'debhelper-compat'}) {
      delete $pkg_version{'debhelper-compat'};
    }
    ## use critic
  }

  # check package version values    {{{2
  {
    for my $pkg (keys %pkg_version) {
      my $val = $pkg_version{$pkg};
      ## no critic (ProhibitDuplicateLiteral)
      my $op       = $val->{'op'};
      my $existing = $val->{'ver'};
      ## use critic
      my $current_val = $self->debian_package_version($pkg);
      if (not $current_val) {
        warn "Unable to get version of package: $pkg\n";
        push @manual, $pkg;
        next;
      }
      my $current = Dpkg::Version->new($current_val);
      die "Package $pkg has invalid version: $current\n"
          if not $current->is_valid;
      if ($current > $existing) {
        $update{$pkg} = {
          exist   => $existing->as_string,
          current => $current->as_string,
          op      => $op,
        };
      }
      else { $keep{$pkg} = $current->as_string; }
    }
  }

  # keep these packages at their current level    {{{2
  {
    if (%keep) {
      say 'Keeping at current version:' or croak;
      for my $pkg (sort keys %keep) {
        my $ver = say "- $pkg ($keep{$pkg})" or croak;
      }
    }
  }

  # update these packages    {{{2
  {
    if (%update) {
      $content = $self->_update_pkg_versions($content, {%update},
        $compat_key, $stndver_key);
    }
  }

  # check these packages manually    {{{2
  {
    if (@manual) {
      say 'WARNING: check manually:' or croak;
      for my $pkg (@manual) { say "- $pkg" or croak; }
    }
  }

  # write updated content to file    {{{2
  {
    my @new_content = split /\n/xsm, $content;
    $self->file_write([@new_content], $deb_control);
    say 'Update complete' or croak;
  }    # }}}2

  return;
}

# _update_pkg_versions($content, $update, $comp_key, $stnd_key)    {{{1
#
# does:   update version values in content string
#
# params: $content     - debian control file content [scalar string]
#         $update      - update details [hashref]
#         $compat_key  - key term for compatibility level [string]
#         $stndver_key - key term for standards version [string]
# prints: feedback on error
# return: scalar string - edited content string
sub _update_pkg_versions ($self, $c, $u, $ck, $sk)
{    ## no critic (RequireInterpolationOfMetachars)

  # method variables
  my ($content, $compat_key, $stndver_key) = ($c, $ck, $sk);
  my %update = %{$u};
  my @failed;

  # cycle through updatable packages
  say 'Updating:' or croak;
  for my $pkg (sort keys %update) {
    my $existing = $update{$pkg}->{'exist'};
    my $current  = $update{$pkg}->{'current'};
    say "- $pkg ($existing -> $current)" or croak;
    if ($pkg eq $compat_key) {

      # Compatibility level
      my $re = qr{ debhelper-compat [ ]+ [(] [ ]* =
                             [ ]* \d+ [)] }xsm;
      my $replace = "debhelper-compat (= $current)";

      if (not $content =~ s/$re/$replace/xsm) {
        push @failed, $compat_key;
      }
    }
    elsif ($pkg eq $stndver_key) {

      # Standards version
      my $re      = qr{ ^ Standards-Version: [ ]+ .*? [ ]* $ }xsm;
      my $replace = "Standards-Version: $current";
      if (not $content =~ s/$re/$replace/xsm) {
        push @failed, $stndver_key;
      }
    }
    else {
      # package
      my $op = $update{$pkg}->{'op'};  ## no critic (ProhibitDuplicateLiteral)
      my $re = qr{ $pkg [ ]+ [(] $op [ ]*
                             $existing [ ]* [)] }xsm;
      my $replace = "$pkg ($op $current)";
      if (not $content =~ s/$re/$replace/xsmg) {
        push @failed, $pkg;
      }
    }
  }

  # provide feedback on failed updates
  if (@failed) {
    warn "WARNING: Unable to update versions for:\n";
    for my $fail (@failed) { warn "- $fail\n"; }
  }

  # return updated content
  return $content;
}

# _write_tar_prep()    {{{1
#
# does:   write tarball directory preparation script
#
# params: nil
# prints: nil
# return: n/a, dies on failure
sub _write_tar_prep ($self) {   ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $file      = File::Basename::fileparse($self->_tar_prep->canonpath);
  my $pkg       = $self->_pkg_name;
  my $tar_build = $self->_tar_build->canonpath;
  my @c;

  # create content
  # - causes multiple Perl::Critic warnings that strings *may* require
  #   interpolation because includes uninterpolated variables and shell
  #   commands
  push @c,
      (
    q[#!/bin/sh],
    q[],
    qq[# File: $file],
    q[],
    qq[# Package: $pkg],
    q[],
    qq[# This script will be run by $SCRIPT just prior to],
    q[# building the source distribution in 'tarball/build'.],
    q[],
    q[# This script is run from the directory],
    qq[# '$tar_build'.],
    q[],
    q[#############################################################],
    q[],
      );

  # write file
  $self->file_write([@c], $self->_tar_prep, $FILE_MODE);

  return;
}

# _write_deb_prep()    {{{1
#
# does:   write debianise directory preparation script
#
# params: nil
# prints: nil
# return: n/a, dies on failure
sub _write_deb_prep ($self) {   ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $file       = File::Basename::fileparse($self->_deb_prep->canonpath);
  my $pkg        = $self->_pkg_name;
  my $deb_source = $self->_deb_source->canonpath;
  my @c;

  # create content
  # - causes multiple Perl::Critic warnings that strings *may* require
  #   interpolation because includes uninterpolated variables and shell
  #   commands
  ## no critic (ProhibitDuplicateLiteral)
  push @c,
      (
    q[#!/bin/sh],
    q[],
    qq[# File: $file],
    q[],
    qq[# Package: $pkg],
    q[],
    qq[# This script is run by $SCRIPT after copying],
    q[# customised debian control files to the debian package],
    q[# source and just prior to building the package.],
    q[],
    q[# This script is run from the directory],
    qq[# '$deb_source/<archive>'.],
    q[# where <archive> is the top-level directory in the source],
    q[# project tarzipped distribution built in 'tarball/build'.],
    q[],
    q[#############################################################],
    q[],
      );
  ## use critic

  # write file
  $self->file_write([@c], $self->_deb_prep, $FILE_MODE);

  return;
}

# _write_wrapper()    {{{1
#
# does:   write wrapper script for this script
#
# params: nil
# prints: nil
# return: n/a, dies on failure
sub _write_wrapper ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $file  = File::Basename::fileparse($self->_wrapper->canonpath);
  my $root  = $self->_root_dir;
  my $pkg   = $self->_pkg_name;
  my $email = $self->_maint_email;
  my @c;

  # create content
  ## no critic (ProhibitDuplicateLiteral)
  push @c,
      (
    q[#!/bin/sh],
    q[],
    qq[# File: $file  [wrapper for '$SCRIPT']],
    q[],
    q[],
    q[# PARAMETERS],
    q[],
    q[# root directory of project],
    qq[root="$root"],
    q[],
    q[# package name],
    qq[pkg="$pkg"],
    q[],
    q[# package maintainer's email address],
    qq[email="$email"],
    q[],
    q[],
    q[# RUN SCRIPT],
    q[],
    qq[$SCRIPT -r "\$root" -p "\$pkg" -e "\$email"],
      );
  ## use critic

  # write file
  $self->file_write([@c], $self->_wrapper, $FILE_MODE);

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::BuildDeb - generate deb package for project

=head1 VERSION

This documentation is for C<App::Dn::BuildDeb> version 3.3.

=head1 SYNOPSIS

    use App::Dn::BuildDeb;

    App::Dn::BuildDeb->new_with_options->run;

=head1 DESCRIPTION

This script builds a standard autotools project and then debianises it to
produce a F<.deb> package file. It relies on the autotools project files and
debianisation files structured in a particular way (see L</Source Project> for
details).

=head2 Calling modes

This script can be called in three 'modes':

=over

=item build

The default mode builds the project and debianises it. The C<-e> and C<-p>
options are required for this mode. The C<-r> option is required unless the
script is run from the project's root directory, in which case it can be
omitted.

=item template

The template mode is activated by the C<-t> option. In this mode a project
skeleton is created in the specified root directory. The C<-e> and C<-p>
options are required for this mode. The C<-r> option is required unless the
script is run from the project's root directory, in which case it can be
omitted. The root directory must be empty.

=item update

The update mode is activated by the C<-u> option. In this mode the following
versions in the F<debian-files/control> file are updated to the current
versions:

=over

=item *

debian compatibility level (debhelper-compat), which is derived from the
current version of the F<debhelper> package

=item *

debian standards version, which is derived from the current version of the
F<debian-policy> package

=item *

any package versions in the F<Build-Depends> and F<Depends> fields.

=back

=back

=head2 Source Project

This script is intended to work with standard autotools-compliant projects. The
following directory structure is required:

    <root>
     |
     |-- debianise
     |   |
     |   |-- debian-files
     |   |
     |   |-- scripts
     |   |
     |   `-- source
     |
     `-- tarball
         |
         |-- autotools
         |
         |-- build
         |
         |-- archive
         |
         `-- source

=over

=item debianise

The debian build files.

=item debian

Debian control files to be copied in to the debian project file tree when it is
created. Some common files copied include F<changelog>, F<control>,
F<copyright> and F<rules>.

=item scripts

Any scripts required by the build process.

Traditionally contains a script called F<build-deb> which invokes this
utility with the appropriate arguments.

Can also contain either or both of two customisation files that this script
will look for during the build process (see L</Customising the build process>).

=item source

The source project is copied here, suitably altered and then the debian package
is built. The final debian package will be created in this directory.

=item tarball

The source project files.

=item autotools

Files required by autotools.

These files are copied or symlinked to the F<build> directory.

Some common autotools files include F<ChangeLog>, F<Makefile.am> and
F<configure.ac>.

=item build

Where the distribution tarball is built.

This directory is emptied at the start of the debian build process. Autotools
files and source files are copied or symlinked from their respective
directories. Then the autotools are used to build the tarball.

=item archive

Each time a distribution tarball is built a copy is stored in this directory.
The idea is to keep an archive of all versions of the project.

=item source

Here the project source files are kept.

=back

=head2 Build Process

=head3 Default build process

In the default build process the following steps are followed:

=over

=item *

Build a targzipped project distribution in the F<tarball/build> directory with
the commands C<autoreconf>, C<./configure>, and C<make dist>.

=item *

Copy the newly-created tarball to the F<debianise/source> directory and extract
it in place.

=item *

Perform initial initial debianisation with the command C<< dh_make --single
--email <email> --file ../<targzip> >>.

where C<< <email> >> is the email address provided as an argument to this
script and C<< <targzip> >> is the project distribution file.

=item *

The default debian control files in the F<debian> subdirectory are deleted and
any customised debian control files in the F<debianise/debian-files> are copied
into the F<debian> subdirectory.

=item *

The final package is built with the command F<dpkg-buildpackage -rfakeroot -us
-uc>.

=back

=head3 Customising the build process

The default build process provides no opportunities for performing
project-specific actions on the initial project source or debian package source
aside from controlling what control files are present in a project's
F<debianise/debian-files> directory.

To enable this sort of customisation this script looks in the
F<debianise/scripts> directory for the files F<tar-dir-prepare> and
F<deb-dir-prepare>:

=over

=item *

F<tar-dir-prepare>: if this script is found and executable it will be executed
just before the C<autoreconf> command is executed. The script is executed in
the F<tarball/build> directory.

=item *

F<deb-dir-prepare>: if this script is found and executable it will be executed
immediately after any customised debian control files are copied into the
package source. The script is executed in the F<< debianise/source/<archive> >>
directory, where F<< <archive> >> is the top level directory of the extracted
tarball source distribution.

=back

=head1 CONFIGURATION AND ENVIRONMENT

There is no configuration of this script.

There are ways to customise the build process for a given project. See
L</Customising the build process> for further details.

=head1 OPTIONS

=over

=item B<-d>|B<--dist_build>

Skip building of the targzipped project distribution and copying it to the
F<debianise/source> directory (see L</Build Process>). Instead assume there is
a single such file in that directory.

This option is designed for use when building a previous version of a project
from an archived distribution targzip file. If reverting to an earlier version
of the project, make sure debian control files such as
F<debian-files/changelog> are consistent.

This option is ignored if the C<-t> or C<-u> options are used.

Boolean. Optional. Default: false.

=item B<-e>|B<--maint_email> I<val>

Email address of the package maintainer.

Scalar string. Ignored if called with '-u' option, otherwise required. No
default.

=item B<-p>|B<--pkg_name> I<val>

Package name.

Scalar string. Ignored if called with '-u' option, otherwise required. No
default.

=item B<-r>|B<--root_dir> I<val>

The root directory of the source project.

Scalar string. Optional. Default: current working directory.

=item B<-t>|B<--template>

Create empty project template consisting of the required directories (see
L</Source Project>).

Also creates empty customisation files and a wrapper for this script.

Note the root directory must be empty if a project template is to be created in
it.

This option cannot be used with the C<-u> option.

Boolean. Optional. Default: false.

=item B<-u>|B<--update>

Update package versions in the F<debian-files/control> file.

This option cannot be used with the C<-t> option.

Boolean. Optional. Default: false.

=item B<-h>

Display help and exit.

=back

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only public method. It builds the debian package.

=head1 DIAGNOSTICS

=head2 Unable to archive tarball: ERROR

Occurs when an attempt to copy the distribution targzip archive to the
F<tarball/archive> directory fails.

=head2 Unable to copy tarball to deb source dir: ERROR

Occurs when an attempt to copy the distribution targzip archive to the
F<debianise/source> directory fails.

=head2 Expected 1 file in debianise/source, got X

Occurs when the script attempts to locate the distribution targzip archive in
the F<debianise/source> directory. Because the directory was cleared before the
archive file was copied to it, it should contain only one file.

=head2 Unable to extract source: ERROR

Occurs when an attempt to unarchive the targzip distribution archive fails.

=head2 Expected 1 directory, got X

After extracting the targzip distribution archive there should be a single
project directory in F<debianise/source> containing the extracted project
files. This error occurs if F<debianise/source> contains more than one
subdirectory or contains no subdirectories.

=head2 Expected 1 'debian' child, got X

=head2 'debian' is not a directory

=head2 Unable to copy custom debian files: ERROR

These errors occur during the script's attempt to copy custom control files
from the F<debianise/debian> directory to the F<debian> subdirectory of the
project files extracted into the F<debianise/source> directory. An error can
occur if no F<debian> subdirectory is located (or is a file instead of a
directory). An error can also occur if the copying operation fails.

=head2 Expected 1 package file, got X

=head2 PKG_NAME is not a file

After building the debian package there should be a single F<.deb> file in the
F<debianise/source> directory. An error occurs if there is no such file or
there are multiple such files. An error also occurs if the file is present but
it is not a regular/plain file.

=head2 Invalid directory: is OBJECT_TYPE

=head2 Invalid directory: is REF_TYPE

=head2 Unable to determine directory path

During the build process the script deletes the contents of both the
F<tarball/build> and F<debianise/source> directories. These errors occur if the
parameter passed to the method performing the deletion cannot be interpreted as
a valid directory. These errors occur because of programming mistakes rather
than system errors.

=head2 Tried to delete X items, deleted Y

During the build process the script deletes the contents of both the
F<tarball/build> and F<debianise/source> directories. This error occurs if, in
either case, the number of files and subdirectories deleted is less than the
total number of files and subdirectories initially detected.

=head2 No command provided

Occurs if the role method that runs shell commands, C<run_command>, is called
without a command parameter. This reflects a programming mistake rather than a
system error.

=head2 Terminal < TERM_MIN_WIDTH chars(X)

Occurs if the terminal width is less than ten columns.

=head2 No content provided

=head2 Content not an array

=head2 No file provided

=head2 Invalid file: is OBJECT_TYPE

=head2 Invalid file: is REF_TYPE

=head2 Unable to determine destination file path

There are numerous occasions when this script writes a file to permanent
storage. All such tasks are delegated to a single method. These errors occur
when the parameters passed to the method are invalid. They are most likely cause
by programming mistakes rather than system errors or data malformation.

=head2 Unable to write to 'FILEPATH': ERROR

=head2 Unable to modify permissions of 'FILEPATH': ERROR

There are numerous occasions when this script writes a file to permanent
storage. These errors occur when the file write or permission change operations
fail.

=head2 Unable to copy into build directory: ERROR

Occurs when an attempt to copy the contents of the F<tarball/source> and
F<tarball/autotools> directories into the F<tarball/build> directory fails.

=head2 Cannot locate 'build/configure' file

During the project build a F<configure> file should be created in the
F<tarball/build> directory. This error occurs if that file cannot be located.

=head2 Expected 1 '.tar.gz' file, got X

The autotools project build process should create a single F<.tar.gz>
distribution archive in the F<tarball/build> directory. This error occurs if
more than one such file is found, or if no such file is found.

=head2 Version mismatch between configure.ac and changelog

=head2 Unable to extract version from configure.ac and changelog

=head2 Extracted version 'VERSION' from changelog, but unable...

=head2 Extracted version 'VERSION' from configure.ac, but unable...

=head2 Help! Current version VERSION is invalid!

=head2 Unable to extract version from configure.ac

=head2 Unable to extract version from changelog

When the script 'bumps' the package version number it must be changed in the
F<tarball/autotools/configure.ac> and F<debianise/debian-files-changelog>
files. This involves extracting the existing versions from both files before
changing them in place. These errors occur when extracting and comparing the
existing package versions in these files.

=head2 Invalid version: VERSION

=head2 New version cannot be lower than current version

When the script 'bumps' the package version number the user enters the new
version number. These errors occur if the new version is invalid, or less than
or equal to the current version.

=head2 Project root directory is not empty: DIR

Occurs if the script is called in template mode but the specified project root
directory is not empty.

=head2 Project root 'DIR' is not a directory

Occurs if an invalid project root directory is specified.

=head2 Invalid maintainer email address: EMAIL

Occurs if no maintainer email value is provided or if an invalid email address
is provided.

=head2 Cannot use both -t and -u

Occurs if both C<-t> and C<-u> options are used. Only one of these options can
be used when calling this script.

=head2 -t option requires OPTS

If the C<-t> option is used then both the C<-e> and C<-p> options must be used
as well. This error occurs if either or both options are omitted.

=head2 Building debian package requires OPTS

If the script is called in 'build' mode it requires both the C<-e> and C<-p>
options be used. This error occurs if either or both options are omitted.

=head2 Missing tarball/archive directory, perhaps '-t' is missing?

=head2 Missing tarball/autotools directory, perhaps '-t' is missing?

=head2 Missing tarball/build directory, perhaps '-t' is missing?

=head2 Missing tarball/source directory, perhaps '-t' is missing?

=head2 Missing debianise/debian-files directory, perhaps '-t' is missing?

=head2 Missing debianise/scripts directory, perhaps '-t' is missing?

=head2 Missing debianise/source directory, perhaps '-t' is missing?

Occurs if this directory cannot be located and the script was called in 'build'
or 'update' mode.

=head2 Missing BUILD-DEB_PATH, perhaps '-t' is missing?

=head2 Missing CHANGELOG_PATH, perhaps '-t' is missing?

=head2 Missing CONFIGURE.AC_PATH, perhaps '-t' is missing?

Occurs if this file cannot be located and the script was called in 'build' or
'update' mode.

=head2 Unable to get version of package: PKG

=head2 Unable to get version of package PKG: ERROR

=head2 Unable to extract version information for package PKG

=head2 Unable to extract PKG version from OUTPUT

=head2 Package PKG has invalid version: VERSION

These errors can occur when attempting to extract package version number from
C<dpkg> output.

=head2 Unable to extract debhelper major version number from version: VERSION

Occurs if the major version number of the F<debhelper> debian package cannot be
extracted from its full version number.

=head2 Unable to extract 3-part version from VERSION

Occurs if a 3-part version (X.Y.Z) cannot be extracted from the full version of
the F<debian-policy> debian package.

=head2 Unable to extract 'Build-Depends' field value

=head2 Unable to extract 'Depends' field value

Occurs when the script is unable to extract data fields from the debian
F<control> file using regular expression matching.

=head2 Unable to extract package name and version from control file data...

Occurs when the script is unable to parse extracted data fields from the debian
F<control> file in order to extract package names and versions.

=head2 Invalid existing standards version: VERSION

=head2 Invalid current standards version: VERSION

These errors occur when the debian standards version extracted from the debian
F<control> file or the F<debian-policy> package are found to be invalid.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Archive::Tar, autodie, Carp, charnames, Const::Fast, Dpkg::Version,
Email::Date::Format, Email::Valid, English, Feature::Compat::Try,
File::Basename, File::Copy::Recursive, File::Find::Rule, File::Spec,
File::chdir, Moo, MooX::HandlesVia, MooX::Options, namespace::clean,
Path::Tiny, Role::Utils::Dn, strictures, Term::Clui, Term::ReadKey,
Types::Standard, version.

=head2 Executables

autoreconf, dh_make, dpkg, dpkg-buildpackage, make, su, sudo.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
