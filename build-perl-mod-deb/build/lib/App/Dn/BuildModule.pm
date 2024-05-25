package App::Dn::BuildModule;

# modules    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use namespace::clean;
use version; our $VERSION = qv('0.10.0');
use App::Dn::BuildModule::Constants;
use App::Dn::BuildModule::DistroArchive;
use App::Dn::BuildModule::DistroFile;
use Carp qw(confess);
use Const::Fast;
use English qw(-no_match_vars);
use File::Basename;
use File::Copy::Recursive;
use File::DirSync;
use File::chdir;    # provides $CWD
use Git::Wrapper;
use Path::Tiny;
use MooX::HandlesVia;
use Try::Tiny;
use Types::Dn;      # custom subtypes
use Types::Path::Tiny;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE              => 1;
const my $FALSE             => 0;
const my $INDEX_FINAL       => -1;
const my $INDEX_PENULTIMATE => -2;
const my $SPACE             => q{ };
const my $TO_READ           => q{<};
const my $TO_WRITE          => q{>};    # }}}1

# attributes - public

# email    {{{1
has 'email' => (
  is       => 'ro',
  isa      => Types::Dn::EmailAddress,
  required => $FALSE,
  default  => 'david@nebauer.org',
  doc      => 'Package maintainer email',
);

# dont_check_builddeps    {{{1
has 'dont_check_builddeps' => (
  is       => 'ro',
  isa      => Types::Standard::Bool,
  required => $FALSE,
  default  => $FALSE,
  doc      => 'Prevent debuild checking build dependencies',

  # debuild's default behaviour is to run dpkg-checkbuilddeps to check
  # build dependencies and conflicts;
  # occasionally this check will declare that a locally installed
  # module is an unmet dependency even if a suitable version of it is
  # correctly installed;
  # this option runs debuild with its '-d' option, which prevents it
  # running dpkg-checkbuilddeps;
  # this solves the immediate problem of the failed dependency check,
  # but be aware it may obscure other build problems
);

# dont_install    {{{1
has 'dont_install' => (
  is       => 'ro',
  isa      => Types::Standard::Bool,
  required => $FALSE,
  default  => $FALSE,
  doc      => 'Suppress installation of debian package',
);    # }}}1

# attributes - private

# _build_dir    {{{1
has '_build_dir_path' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    Types::Standard::InstanceOf ['Path::Tiny'],
  ],
  default => sub {undef},
  doc     => 'Build directory',
);

sub _build_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_build_dir_path->canonpath();
}

# _deb_file    {{{1
has '_deb_file_name' => (
  is       => 'rw',
  isa      => Types::Path::Tiny::File,
  coerce   => $TRUE,
  required => $FALSE,
  doc      => 'Debian package filename',

  # example: libdn-perltidy_0.1-1_all.deb
);

sub _deb_file ($self) {    ## no critic (RequireInterpolationOfMetachars)
  if ($self->_deb_file_name->basename) {
    return $self->_deb_file_name->basename();
  }
  else {
    return $FALSE;
  }
}

# _debian_dir    {{{1
has '_debian_dir_path' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  lazy    => $TRUE,
  coerce  => $TRUE,
  default => sub {
    my $self = shift;
    if (not $self->_distro_name_ver) {
      confess "Cannot construct module debian directory pathname\n";
    }
    my $build = $self->_build_dir;
    return $self->dir_join($build, $self->_distro_name_ver, 'debian');
  },
  doc => 'Module build debian directory',

  # = <base_dir>/build/MODULENAME-VERSION/debian
);

sub _debian_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_debian_dir_path->canonpath();
}

# _distro_file    {{{1
has '_distro_file_name' => (
  is       => 'rw',
  isa      => Types::Path::Tiny::File,
  coerce   => $TRUE,
  required => $FALSE,
  doc      => 'Distribution filename',

  # example: Dn-PerlTidy-v0.1.tar.gz
);

sub _distro_file ($self) {    ## no critic (RequireInterpolationOfMetachars)
  if ($self->_distro_file_name) {
    return $self->_distro_file_name->basename();
  }
  else {
    return $FALSE;
  }
}

# _distro_name_ver    {{{1
has '_distro_name_ver' => (
  is       => 'rw',
  isa      => Types::Standard::Str,
  required => $FALSE,
  doc      => 'Basename of distro gzipped tarball',

  # example: Dn-PerlTidy-v0.1
);

# _distro_types_details    {{{1
has '_distro_types_details' => (
  is  => 'ro',
  isa => Types::Standard::HashRef [
    Types::Standard::InstanceOf ['App::Dn::BuildModule::DistroArchive'],
  ],
  reader  => '_distro_types_details',  ## no critic (ProhibitDuplicateLiteral)
  default => sub {
    my $self = shift;

    # include '::FILE::' ($FILE_TOKEN) token in
    # each extract command to represent the file name
    return {
      targz => App::Dn::BuildModule::DistroArchive->new(

        #match             => '*.tar.gz',
        match             => qr/[.]tar[.]gz\z/xsm,
        ext_snips         => 2,
        extract_cmd_parts =>
            [ 'tar', 'zxvf', $App::Dn::BuildModule::Constants::FILE_TOKEN ],
      ),
    };
  },
  handles_via => 'Hash',
  handles     => { _distro_types => 'keys', _distro_type => 'get', },
  doc         => 'Details of distribution types',
);

# _git_repo_created    {{{1
has '_git_repo_created' => (
  is      => 'rw',
  isa     => Types::Standard::Bool,
  default => sub {$FALSE},
  doc     => 'Whether git repo created during build process (flag)',
);

# _module_dir    {{{1
has '_module_dir_path' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  lazy    => $TRUE,
  coerce  => $TRUE,
  default => sub {
    my $self = shift;
    if (not $self->_distro_name_ver) {
      confess "Cannot construct module directory pathname\n";
    }
    my $build = $self->_build_dir;
    return $self->dir_join($build, $self->_distro_name_ver);
  },
  doc => 'Module directory',

  # = <base_dir>/build/MODULENAME-VERSION
);

sub _module_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_module_dir_path->canonpath();
}

# _required_dir    {{{1
has '_required_dir_path' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  lazy    => $TRUE,
  coerce  => $TRUE,
  default => sub {
    my $self  = shift;
    my $build = $self->_build_dir;
    return $self->dir_join($build, 'required');
  },
  doc => 'Required directory',
);

sub _required_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_required_dir_path->canonpath();
}

# _source_dir    {{{1
has '_source_dir_path' => (
  is  => 'rw',
  isa => Types::Standard::Maybe [
    ## no critic (ProhibitDuplicateLiteral)
    Types::Standard::InstanceOf ['Path::Tiny'],
    ## use critic
  ],
  default => sub {undef},
  doc     => 'Source directory',
);

sub _source_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_source_dir_path->canonpath();
}

# _this_distro_type    {{{1
has '_this_distro_type' => (
  is       => 'rw',
  isa      => Types::Standard::Str,
  required => $FALSE,
  doc      => 'Distro file archive type',

  # one of the keys from attribute '_distro_types_details'
);                           # }}}1

# methods

# run()  {{{1
#
# does:  builds debian package from module
# params: nil
# prints: nil
# return: n/a
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)
  if (not $self->_tools_available) { return $FALSE; }
  $self->_setup;
  $self->_build_dist;
  $self->_extract_module_name_version_type;
  $self->_extract_distribution;
  $self->_create_debian_build_files;
  $self->_amend_debian_rules;
  $self->_copy_required_files;
  $self->_create_debian_package;
  $self->_retrieve_deb_file_name;
  $self->_install_package;

  return $TRUE;
}

# _tools_available()  {{{1
#
# does:   check that required executables are on system
# params: nil
# prints: messages if required tools are not available
# return: boolean
sub _tools_available ($self) {  ## no critic (RequireInterpolationOfMetachars)
  my @tools = qw(debuild make tar);
  return $self->tools_available(@tools);
}

# _setup()  {{{1
#
# does:   setup attributes that cannot be "lazy built" (because it requires
#         a method from $self, including from Role::Utils::Dn)
# params: nil
# prints: messages if errors encountered
# return: nil
sub _setup ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # base dir    {{{2
  my $base;
  {
    my $cwd = Path::Tiny::path($self->cwd);
    $base = $cwd->parent;
  }

  # build dir    {{{2
  {
    # Path::Tiny requires regex for 'children' method
    ## no critic (ProhibitFixedStringMatches)
    my @children = $base->children(qr/\Abuild\z/xsm);
    ## use critic
    if (scalar @children == 1 and $children[0]->is_dir) {
      $self->_build_dir_path($children[0]);
    }
    else {
      die "Cannot find build directory\n";
    }
  }

  # source dir    {{{2
  {
    # Path::Tiny requires regex for 'children' method
    ## no critic (ProhibitFixedStringMatches)
    my @children = $base->children(qr/\Asource\z/xsm);
    ## use critic
    if (scalar @children == 1 and $children[0]->is_dir) {
      $self->_source_dir_path($children[0]);
    }
    else {
      die "Cannot find source directory\n";
    }
  }

  # }}}2

  return;
}

# _build_dist()  {{{1
#
# does:   build module distribution (.tar.gz)
# params: nil
# prints: nil
# return: nil, die on error
sub _build_dist ($self) {    ## no critic (RequireInterpolationOfMetachars)
  $self->_copy_source_to_build;
  if ($self->_has_dist_ini) {
    $self->_build_dist_using_milla;
    return;
  }
  if ($self->_has_makefile_pl) {
    $self->_build_dist_using_extutils_makemaker;
    return;
  }
  if ($self->_has_build_pl) {
    $self->_build_dist_using_module_build;
    return;
  }
  die "No Makefile.PL, Build.PL or dist.ini found\n";
}

# _copy_source_to_build    {{{1
#
# does:   recursive copy of contents of source directory
#         to build directory
# params: nil
# prints: nil
# return: nil, die on error
sub _copy_source_to_build ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $source = $self->_source_dir;
  my $build  = $self->_build_dir;
  if (not -e $source) {
    die "Cannot locate source directory '$source'\n";
  }
  if (not -e $build) {
    die "Cannot locate build directory '$build'\n";
  }
  try {    # ensure nocache so does full copy each time
    my $dirsync = File::DirSync->new(
      { src => $source, dst => $build, nocache => $TRUE });
    $dirsync->dirsync();
    say 'Copied source to build directory' or confess;
  }
  catch {
    confess "Copy of source to build directory failed: $_";
  };
  return $TRUE;
}

# _has_dist_ini()  {{{1
#
# does:   check whether build directory contains file 'dist.ini'
# params: nil
# prints: nil
# return: boolean
sub _has_dist_ini ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $build_dir = $self->_build_dir;
  return $self->file_list($build_dir, qr/\Adist[.]ini\z/xsm);
}

# _announce_cmd_run($cmd_ref)  {{{1
#
# does:   announce command to be run
# params: $cmd_ref - command to run [arrayref, required]
# prints: announcement
# return: nil, die on error
sub _announce_cmd_run ($self, $cmd_ref)
{    ## no critic (RequireInterpolationOfMetachars)
  my @cmd = @{$cmd_ref};
  say q{Running '} . join($SPACE, @cmd) . q{':} or confess;
  return $TRUE;
}

# _build_dist_using_milla()  {{{1
#
# does:   build distribution using milla
# params: nil
# prints: nil
# return: nil, die on error
sub _build_dist_using_milla ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # change to build directory
  my $build = $self->_build_dir;
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $build;

  # milla requires git repository
  my $git_dirpath = $self->dir_join($build, '.git');
  my $git_dir     = Path::Tiny::path($git_dirpath);
  if ($git_dir->is_dir) { $self->path_remove($git_dirpath); }
  my $git = Git::Wrapper->new($build) or confess;
  try {
    $git->init;
    $git->add({ all => $TRUE });
    $git->commit({ message => 'Initial commit' });
  }
  catch {
    confess "git command failed: $_";
  };

  # build using milla
  my @cmds = ([qw( prove -l t )], [qw( milla test )], [qw( milla build )],);
  for my $cmd (@cmds) {
    $self->_announce_cmd_run($cmd);
    $self->run_command(undef, @{$cmd});
  }

  # remove git repo (because of higher level git repo)
  $self->path_remove($git_dirpath);

  return;
}

# _has_makefile_pl()  {{{1
#
# does:   check whether build directory contains file 'Makefile.PL'
# params: nil
# prints: nil
# return: boolean
sub _has_makefile_pl ($self) {  ## no critic (RequireInterpolationOfMetachars)
  my $build_dir = $self->_build_dir;
  return $self->file_list($build_dir, qr/\AMakefile[.]PL\z/xsm);
}

# _build_dist_using_extutils_makemaker    {{{1
#
# does:   build distribution using Makefile.PL
# params: nil
# prints: nil
# return: nil, die on error
sub _build_dist_using_extutils_makemaker ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;

  my @cmds =
      ([qw( perl Makefile.PL )], [qw( make test )], [qw( make dist )],);
  for my $cmd (@cmds) {
    $self->_announce_cmd_run($cmd);
    $self->run_command(undef, @{$cmd});
  }
  return $TRUE;
}

# _has_build_pl()  {{{1
#
# does:   check whether build directory contains file 'Build.PL'
# params: nil
# prints: nil
# return: boolean
sub _has_build_pl ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $build_dir = $self->_build_dir;
  return $self->file_list($build_dir, qr/\ABuild[.]PL\z/xsm);
}

# _build_dist_using_module_build    {{{1
#
# does:   build distribution using Build.PL
# params: nil
# prints: nil
# return: nil, die on error
sub _build_dist_using_module_build ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;
  my @cmds = (
    [qw ( perl Build.PL )], [qw ( ./Build )],
    [qw ( ./Build test )],  [qw ( ./Build dist )],
  );
  for my $cmd (@cmds) {
    $self->_announce_cmd_run($cmd);
    $self->run_command(undef, @{$cmd});
  }
  return $TRUE;
}

# _extract_module_name_version_type()  {{{1
#
# does:   locates distribution file and gets name
#         extracts module name-version from distribution file name
#         assigns archive type of distribution file
#         sets attributes for file name and type, and module-version
# params: nil
# prints: nil
# return: nil, die on error
sub _extract_module_name_version_type ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # extract module name and version for each distro type    {{{2
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;
  my @distro_types = $self->_distro_types;
  my @results;
  foreach my $type (@distro_types) {    # cycle through distro types
    my $num_snips    = $self->_distro_type($type)->ext_snips;
    my $pattern      = $self->_distro_type($type)->match;
    my @file_matches = $self->file_list($CWD, $pattern);
    foreach my $file_match (@file_matches) {    # expect 0 or 1 matches
      my $distro_file = $self->file_name($file_match);
      my $module_ver  = $distro_file;                    # get module-ver
      for (1 .. $num_snips) {
        my ($file, $dir, $suffix) =
            File::Basename::fileparse($module_ver, qr/[.][^.]*/xsm);
        $module_ver = $file;
      }
      my $result = App::Dn::BuildModule::DistroFile->new(
        name        => $distro_file,
        module_ver  => $module_ver,
        distro_type => $type,
      );
      push @results, $result;
    }
  }

  # success if only one matching distribution file found    {{{2
  for (scalar @results) {
    if ($_ == 0) {    # error
      my $msg = 'Unable to extract module name and version ';
      $msg .= 'from distribution file';
      confess $msg;
    }
    elsif ($_ > 1) {    # error
      my @msg = ("Multiple distribution files detected:\n");
      foreach my $result (@results) {
        my $file = $result->name;
        push @msg, "  $file\n";
      }
      confess @msg;
    }
    else {              # success
      my $result = $results[0];
      $self->_distro_file_name($result->name);
      $self->_distro_name_ver($result->module_ver);
      $self->_this_distro_type($result->distro_type);
    }
  }    # }}}2
  return;
}

# _extract_distribution()  {{{1
#
# does:   extracts distribution file in build directory
# params: nil
# prints: nil
# return: nil, die on error
sub _extract_distribution ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # assemble extraction command
  my $type = $self->_this_distro_type;
  my $file = $self->_distro_file;
  my @cmd  = $self->_distro_type($type)->extract_cmd($file);

  # run command
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;
  $self->_announce_cmd_run([@cmd]);
  $self->run_command(undef, @cmd);

  return $TRUE;
}

# _create_debian_build_files()  {{{1
#
# does:   run dh-make-perl to create debian package files
# params: nil
# prints: nil
# return: nil, die on error
sub _create_debian_build_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $email     = $self->email;
  my @cmd       = ('dh-make-perl', '--vcs', q{''});
  my $connected = $self->internet_connection($TRUE);
  if (not $connected) {
    say "\nRunning dh-make-perl with '--no-network'" or confess;
    push @cmd, '--no-network';
  }
  push @cmd, '--email', $email, $self->_distro_name_ver;
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;
  $self->_announce_cmd_run([@cmd]);
  $self->run_command(undef, @cmd);

  return $TRUE;
}

# _derive_pkg_name_from_changelog()  {{{1
#
# does:   extract debian package name from changelog
# params: nil
# prints: nil
# return: scalar string, die on error
sub _derive_pkg_name_from_changelog ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # get content of changelog
  my $debian_dir = $self->_debian_dir;
  my $changelog  = $self->path_join($debian_dir, 'changelog');
  if (not(-e $changelog)) {
    confess "Cannot locate changelog '$changelog'";
  }
  open my $fh, $TO_READ, $changelog
      or die "Unable to open $changelog: $ERRNO\n";
  my @log = <$fh>;
  close $fh or die "Unable to close $changelog: $ERRNO\n";
  chomp @log;

  # get package name from first line
  my $line = $log[0];
  my $pkg  = (split /\s+/xsm, $line)[0];
  if (not $pkg) { confess 'Unable to extract package name'; }

  return $pkg;
}

# _amend_debian_rules()  {{{1
#
# does:   make changes to debian rules file
# params: nil
# prints: nil
# return: n/a, die on failure
sub _amend_debian_rules ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # reused variables    {{{2
  my ($fh, @new_rule);

  # get debian subdirectory    {{{2
  my $debian_dir = $self->_debian_dir;
  my $rules_fp   = $self->path_join($debian_dir, 'rules');
  if (not -e $rules_fp) { confess 'Cannot find rules file'; }

  # read in default rules file    {{{2
  open $fh, $TO_READ, $rules_fp
      or confess "Unable to open $rules_fp: $ERRNO";
  my @rules = <$fh>;
  close $fh or confess "Unable to close $rules_fp: $ERRNO";
  chomp @rules;

  # remove empty lines at end of file    {{{2
  while (1) {
    my $final_line       = $rules[$INDEX_FINAL];
    my $penultimate_line = $rules[$INDEX_PENULTIMATE];
    last if (not(not $final_line and not $penultimate_line));
    pop @rules;
  }

  # add bash completion if bash completion file provided    {{{2
  # - is in 'required' directory
  # - must have form: 'PKG_NAME.bash-completion'
  my $pkg_name = $self->_derive_pkg_name_from_changelog;
  my $required = $self->_required_dir;
  my $bashcomp = $self->path_join($required, $pkg_name) . '.bash-completion';
  if (-e $bashcomp) {
    foreach my $line (@rules) {
      if ($line =~ /^\s*dh\s+/xsm) {
        $line .= ' --with bash-completion';
      }
    }
  }

  # new rule: set sharedstatedir    {{{2
  # - hard tab required by rules file format
  @new_rule = (    ## no critic (ProhibitHardTabs)
    q{},
    q{# Make directory variable sharedstatedir debian compliant},
    q{override_dh_auto_configure:},
    q{	dh_auto_configure -- --sharedstatedir=/var/lib},
    q{},
  );
  push @rules, @new_rule;

  # new rule: do not sign package    {{{2
  #@new_rule = (
  #    q{# Suppress digital signing of package},
  #    q{override_dh_md5sums:}, q{},
  #);
  #push @rules, @new_rule;

  # new rule: prevent stripping of information from files    {{{2
  @new_rule = (
    q{# Suppress stripping of information from files},
    q{override_dh_strip_nondeterminism:},
    q{},
  );
  push @rules, @new_rule;

  # write back amended file    {{{2
  open $fh, $TO_WRITE, $rules_fp    ## no critic (RequireBriefOpen)
      or confess "Unable to open $rules_fp: $ERRNO";
  foreach my $line (@rules) {
    say {$fh} $line
        or confess "Unable to write to $rules_fp: $OS_ERROR";
  }
  close $fh or confess "Unable to close $rules_fp: $ERRNO";    # }}}2

  return;
}

# _copy_required_files()  {{{1
#
# does:   copy any required files to debian subdirectory
# params: nil
# prints: number of files copied
# return: nil, die on error
sub _copy_required_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # set source and target directories
  my $src = $self->_required_dir;
  my $dst = $self->_debian_dir;

  # remove target file before copy, and copy top level directory only
  # - localised as per PBP, so ignore package variable warning
  ## no critic (ProhibitPackageVars)
  local $File::Copy::Recursive::RMTrgFil = $TRUE;
  local $File::Copy::Recursive::MaxDepth = 1;
  ## use critic
  my ($files_and_dirs_num, $dirs_num, $depth) =
      File::Copy::Recursive::dircopy($src, $dst)
      or confess "Copy of required debian files failed\n";

  # report outcome
  if ($files_and_dirs_num > 0) {
    my $files_num = $files_and_dirs_num - $dirs_num;
    say $SPACE or confess;
    say "Copied $files_num required debian files to build tree"
        or confess;
  }

  return $TRUE;
}

# _create_debian_package()  {{{1
#
# does:   runs debuild to build package
# params: nil
# prints: nil
# return: nil, die on error
sub _create_debian_package ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  say $SPACE                    or confess;
  say 'Building debian package' or confess;

  # debuild options: -i  = filter out revision control system files
  #                  -us = do not sign source package
  #                  -uc = do not sign .changes file
  #                  -b  = binary build only - no source files
  #                  -d  = do not check building dependencies
  my @cmd = qw(debuild -i -us -uc -b);
  if ($self->dont_check_builddeps) { push @cmd, '-d'; }
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_module_dir;
  $self->_announce_cmd_run([@cmd]);
  $self->run_command(undef, @cmd);

  return $TRUE;
}

# _retrieve_deb_file_name()  {{{1
#
# does:   locates distribution file and gets name
#         extracts module name-version from distribution file name
#         assigns archive type of distribution file
#         sets attributes for file name and type, and module-version
# params: nil
# prints: name of deb file
# return: nil, die on error
sub _retrieve_deb_file_name ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;
  my @debs = $self->file_list($CWD, qr/[.]deb\z/xsm);
  if (scalar @debs == 0) {    # error
    confess "Unable to find built deb file\n";
  }
  elsif (scalar @debs > 1) {    # error
    ## no critic (ProhibitDuplicateLiteral)
    my @msg = ("Multiple distribution files detected:\n");
    ## use critic
    foreach my $deb (@debs) {
      push @msg, "  $deb\n";
    }
    confess @msg;
  }
  else {                        # success
    my $deb_path = $debs[0];
    my $deb_name = $self->file_name($deb_path);
    say $SPACE                                or confess;
    say "Built deb file '../build/$deb_name'" or confess;
    $self->_deb_file_name($deb_name);
  }

  return $TRUE;
}

# _install_package()  {{{1
#
# does:   installs debian package
# prints: question and feedback
# params: nil
# return: n/a
sub _install_package ($self) {  ## no critic (RequireInterpolationOfMetachars)

  # shall we install?
  if ($self->dont_install) {
    say $SPACE                                   or confess;
    say 'Not installing package at your request' or confess;
    return $FALSE;
  }

  # okay, let's install
  my $deb = '../build/' . $self->_deb_file;
  $self->debian_install_deb($deb);

  return $TRUE;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::BuildModule - build a debian package

=head1 VERSION

This documentation describes App::Dn::BuildModule version 0.10.0.

=head1 SYNOPSIS

    my $app = App::Dn::BuildModule->new(email => $maint_email);
    $app->run;

=head1 DESCRIPTION

=head2 Preparation

This script assumes the following directory structure:

    |
    `-- project-directory
        |-- build
        `-- source
            `-- required

The modules's source files and subdirectories are in the F<source> directory.
In addition to the module files the F<source> directory has an additional
subdirectory: F<required>.

This script assumes the following build process has been followed at least
once:

=over

=item

Install module source in the F<source> directory. This may invove a command
sequence like:

    $ cd path/to/project-directory/source

    $ cpan -g The::Module
    Checking The::Module
    CPAN: Storable loaded ok (v2.49_01)
    Reading '/home/david/.cpan/Metadata'
      Database was generated on Sat, 09 May 2015 12:29:02 GMT

    $ dir
    TheModule-1.23.tar.gz

    $ tar zxvf TheModule-1.23.tar.gz
    TheModule-1.23/
    TheModule-1.23/META.yml
    ...

    $ mv TheModule-1.23/* ./

    $ rmdir TheModule-1.23

    $ rm TheModule-1.23.tar.gz

=item

Create F<required> subdirectory:

    $ cd path/to/source
    $ mkdir required

=item

Add executable scripts

Scripts to be installed to S<< F</usr/bin/> >> are put in
S<< F<source/script> >>. This directory needs to be created. The scripts are
not set as executable in this directory; that is handled during packaging.

=item

Add bash completion script

S<< C<dn-build-perl-mod-deb> >> provides support for a single bash completion
file. The file must be called S<< F<PACKAGE.bash-completion> >> where 'PACKAGE'
is the name of the debian package to be created. For example, the perl module
S<< F<My::Module> >> may be packaged as S<< F<libmy-module-perl> >>. If
executable scripts are included in the package, the accompanying bash
completion file in the source tree would be
S<< F<source/required/libmy-module-perl.bash-completion> >>, and would install
to S<< F</usr/share/bash-completion/completions/libmy-module-perl> >>.

=item

Add files for installation to other directories

There is a mechanism for installing files to any system location. The files
must be installed under the F<source> directory in any subdirectory path. It is
a convention to install files under S<< F<source/contrib> >>. For example, a
zsh completion script may be located at S<<
F<source/contrib/completion/zsh/_my-script> >> in the source tree. The install
destination is specified in S<< F<source/required/PACKAGE.install> >> where
PACKAGE is the debian package name. Each file to be installed must be listed in
this file with a destination directory. Here is the line that might be used for
the zsh completion file mentioned above:

    contrib/completion/zsh/_my-script /usr/share/zsh/vendor-completions

The location of the source file, relative to the F<source> directory, is given
first, followed by the destination directory. Note that the destination does
not include the file name as it uses the name of the source file.

=item

Copy all source files to F<build> directory:

    $ cd ../build
    $ cp -r ../source/. ./

Note the use of S<< C<../source/.> >> rather than the more usual S<<
C<../source/*> >>. This ensures hidden files and directories are copied as
well. This is important in some cases where failure to copy hidden files
results in S<< C<milla test> >> and S<< C<milla build> >> failing because it
cannot find the distribution.

=item

Build distribution file. Supported build methods are:

=over

=item

Dist::Milla (relies on detecting a S<< F<dist.ini> >> file in the project root
directory)

    $ prove -l t
    $ milla test
    $ milla build

=item

ExtUtils::MakeMaker (relies on detecting a S<< F<Makefile.PL> >> file in the
project root directory)

    $ perl Makefile.PL
    $ make test
    $ make dist

=item

Module::Build (relies on detecting a S<< F<Build.PL> >> file in the root
directory)

    $ perl Build.PL
    $ ./Build
    $ ./Build test
    $ ./Build dist

=item

Extract the distribution file, creating a subdirectory containing a copy of the
distribution files:

    $ tar zxvf TheModule-1.23.tar.gz

Note: the Dist::Milla build process results in the creation of a subdirectory
of this name being built, so that subdirectory must be deleted before
S<< C<tar zxvf> >> is run.

=item

Create debian package build files using S<< C<dh-make-perl> >>:

    $ dh-make-perl TheModule-1.23

This command may fail if module dependencies are not met. Install any required
modules before proceeding.

=item

Perform initial build of debian package using C<debuild>:

    $ cd TheModule-1.23
    $ debuild

Note that this operation is performed from the module directory.

=item

The initial buld operation will generate a number of lintian warnings. These
require changes to the F<control>, F<copyright> and F<changelog> files in the
debian subdirectory. These are copied to the F<build> directory's F<required>
subdirectory:

    $ for x in control copyright changelog ; do \
      cp debian/${x} ../required/ ; done

or use C<mc> to copy them manually:

    $ mc debian/ ../required/

These files are then edited to remove the warnings.

The commonest warnings are fixed with the following:

=over

=item

The last two lines of the F<control> file are autogenerated content and need to
be removed

=item

The F<copyright> file contains an autogenerated disclaimer, usually beginning
around line 5, that needs to be removed.

=item

The F<changelog> file needs the details of the initial change altered to
something like:

    * Local package
    * Initial release
    * Closes: 2001

=back

Of course, make any additional alterations to these files to fix additional
lintian warnings and to ensure they are correct and complete.

When these files have been fixed, copy them back to the debian subdirectory:

    cp ../required/* debian/

Also copy them to the S<< F<source/required> >> subdirectory so they are
included in the next build sequence.

=item

Repeat the previous step until no lintian warnings appear during the package
build.

=back

=back

=head2 Use of this script

Once the initial build has been performed, this script is run from the
F<source> directory. It performs the following tasks:

=over

=item

Copies the directory contents to sibling directory F<build>

=item

Builds a distribution

=item

Extracts the distribution into its subdirectory

=item

Runs S<< C<dh-make-perl> >> on the extracted module source

=item

Changes to the extracted module directory and runs C<debuild>

=item

Copies all files in the S<< F<build/required> >> directory to the module's
F<debian> directory

=item

Installs the created package.

=back

=head1 SUBROUTINES/METHODS

=head2 run()

Builds a debian package from a module (or set of modules) in a build
environment as specified in L</DESCRIPTION>.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 email

Debian package maintainer email.

Scalar. Optional. Default: E<lt>david@nebauer.orgE<gt>.

=head3 dont_check_builddeps

C<debuild> default behaviour is to run S<< C<dpkg-checkbuilddeps> >> to check
build dependencies and conflicts. Sometimes this check will declare that a
locally installed module is an unmet dependency even if a suitable version of
it is correctly installed.

If this attribute is set to true then this script runs C<debuild> with its
C<-d> option, which prevents it running S<< C<dpkg-checkbuilddeps> >>.
This solves the immediate problem of the failed dependency check, but be aware
it may obscure other build problems.

Boolean. Optional. Default: false.

=head3 dont_install

Suppress installation of debian package after it is built.

Boolean. Optional. Default: false.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 DIAGNOSTICS

=head2 No Makefile.PL, Build.PL or dist.ini found

Occurs if script cannot find evidence of a supported build system.

=head2 Cannot locate source directory 'DIR'

=head2 Cannot locate build directory 'DIR'

=head2 Copy of source to build directory failed with error: ERROR

These errors occur when the script is unable to recursively copy the contents
of the F<source> directory to the F<build> directory.

=head2 Cannot locate changelog 'PATH'

Occurs when the script is unable to locate the F<changelog> file in the
F<debian> subdirectory of the source distribution base directory.

=head2 Unable to open FILE: ERROR

=head2 Unable to close FILE: ERROR

These errors occur when the script is unable to open or close a disk file. The
files this script attempts to access in this way are the F<changelog> and
F<rules> debian control files.

=head2 No file provided

=head2 Unable to extract module name and version from distribution file

=head2 Multiple distribution files detected ...

Occurs when the script attempts to locate a source distribution file after the
initial build process. It indicate that no file matching the supported build
processes was found, or that multiple matching files were found.

=head2 Cannot construct module debian directory pathname

=head2 Cannot construct module directory pathname

Occurs when the script is unable to derive the name of the extracted source
distribution base directory.

=head2 Unable to extract package name

Occurs when the script is unable to extract the package name from the
F<changelog> debian control file.

=head2 Cannot find rules file

Occurs when the script is unable to locate the F<rules> debian control file.

=head2 Unable to write to FILE: ERROR

Occurs if the script is unable to write to a disk file. This can occur with the
F<rules> debian control file.

=head2 Copy of required debian files failed

Occurs when attempting to copy required debian control files from
F<build/required/> to F<build/DIST_SOURCE_BASE/debian>.

=head2 Unable to find built deb file

=head2 Multiple distribution files detected: ...

These errors occur when attempting to locate the debian package file built by
the script.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 DEPENDENCIES

=head2 Perl modules

App::Dn::BuildModule::Constants, App::Dn::BuildModule::DistroArchive,
App::Dn::BuildModule::DistroFile, Carp, Const::Fast, English, File::Basename,
File::chdir, File::Copy::Recursive, File::DirSync, Git::Wrapper, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Path::Tiny,
Role::Utils::Dn, strictures, Types::Dn, Types::Path::Tiny, Types::Standard,
version.

=head2 Executables

debuild, dh-make-perl, make, milla, prove, tar.

=head2 Debian packaging

The executable 'milla' is part of the Dist::Milla perl module, but that module
is not available from standard debian repositories.

=head1 LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Copyright 2024, David Nebauer

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=cut

# vim:fdm=marker
