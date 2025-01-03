package App::Dn::QkDeb;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.8');    # }}}1
use namespace::clean -except => [ '_options_data', '_options_config' ];
use autodie qw(open close);
use App::Dn::QkDeb::File;
use App::Dn::QkDeb::Path;
use Archive::Tar;
use Carp qw(croak confess);
use Const::Fast;
use Dpkg::Version;
use English qw(-no_match_vars);
use File::chdir;                          # provides $CWD
use MooX::HandlesVia;
use MooX::Options;
use Pod::Man;
use Types::Dn::Debian;
use Types::Dn;
use Types::Path::Tiny;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE              => 1;
const my $FALSE             => 0;
const my $MODULE_QKDEB_FILE => 'App::Dn::QkDeb::File';
const my $MSG_KEEP_VER      => 'Remaining at current version';
const my $RE_TAR_GZ         => qr{[.]tar[.]gz\Z}xsm;
const my $RE_DEB            => qr{[.]deb\Z}xsm;
const my $RE_DSC            => qr{[.]dsc\Z}xsm;
const my $RE_ORIG_TAR_GZ    => qr{[.]orig[.]tar[.]gz\Z}xsm;
const my $RE_DIFF_GZ        => qr{[.]diff[.]gz\Z}xsm;
const my $EMPTY_STRING      => q{};
const my $SPACE             => q{ };
const my $DASH              => q{-};
const my $DOUBLE_QUOTE      => q{"};
const my $SPACE_DOT         => q{ .};
const my $DOT_IN            => q{.in};
const my $PRINT_WIDTH       => 60;                               # }}}1

# options

# deb_only           (-d)    {{{1
# - default is to save '.diff.gz', '.dsc' and '.orig.tar.gz' as well as '.deb'
option 'deb_only' => (
  is            => 'ro',
  short         => 'd',
  documentation => q{Save generated '.deb' package file only},
);

# autotools_feedback (-f)    {{{1
option 'autotools_feedback' => (
  is            => 'ro',
  short         => 'f',
  documentation => 'Show feedback from autotools commands',
);

# ignore_errors      (-i)    {{{1
option 'ignore_errors' => (
  is            => 'ro',
  short         => 'i',
  documentation => 'Turn all errors into warnings',
);

# keep_version       (-k)    {{{1
option 'keep_version' => (
  is            => 'ro',
  short         => 'k',
  documentation => 'Keep current version number',
);

# library_package    (-l)    {{{1
# - make into a library package
# - this relaxes requirements for script and manpage files
# - this puts files in pkgdatadir or pkglibexecdir
#   • in debian pkgdatadir = /usr/share/$(PACKAGE)
#   • in debian pkglibexecdir = /usr/libexec/$(PACKAGE)
option 'library_package' => (
  is            => 'ro',
  short         => 'l',
  documentation => 'Library package - put in pkgdatadir or pkglibexecdir',
);

# suppress_podman    (-m)    {{{1
option 'suppress_podman' => (
  is            => 'ro',
  short         => 'm',
  documentation => 'Prevent creation of manpage from main script pod',
);

# no_install         (-n)    {{{1
option 'no_install' => (
  is            => 'ro',
  short         => 'n',
  documentation => 'Do not install built debian package',
);

# create_template    (-t) (overrides other options)    {{{1
option 'create_template' => (
  is            => 'ro',
  short         => 't',
  documentation => q{Create template 'deb-resources' file and exit},
);    # }}}1

# attributes

# _author_list    {{{1
has '_author_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _authors     => 'elements',
    _add_author  => 'push',
    _has_authors => 'count',
  },
  documentation => 'Package authors',
);

sub _primary_author ($self) {   ## no critic (RequireInterpolationOfMetachars)
  my @authors = $self->_authors;
  my $primary = shift @authors;
  return $primary;
}

# _bashcomp    {{{1
has '_bashcomp' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _bin_file_list    {{{1
has '_bin_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _bin_files      => 'elements',
    _add_bin_file   => 'push',
    _has_bin_files  => 'count',
    _bin_file_count => 'count',
  },
  documentation => 'Scripts for packaging',
);

# _build_dir    {{{1
has '_build_dir_path' => (
  is       => 'ro',
  isa      => Types::Path::Tiny::AbsDir,
  coerce   => $TRUE,
  required => $TRUE,
  default  => sub {
    my $self = shift;
    $self->dir_temp();
  },
  documentation => 'Build directory (temporary)',
);

sub _build_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_build_dir_path->canonpath();
}

# _conf_file_list    {{{1
has '_conf_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _conf_files    => 'elements',
    _add_conf_file => 'push',
  },
  documentation => 'Configuration files for packaging',
);

# _copyright    {{{1
has '_copyright' => (
  is            => 'rw',
  isa           => Types::Dn::Debian::PackageCopyrightYear,
  required      => $FALSE,
  documentation => 'Package copyright year',
);

# _data_file_list    {{{1
has '_data_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _data_files    => 'elements',
    _add_data_file => 'push',
  },
  documentation => 'Data files for packaging',
);

# _deb_build_dir    {{{1
has '_deb_build_dir_path' => (
  is            => 'rw',
  isa           => Types::Path::Tiny::AbsDir,
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build directory (temporary)',
);

sub _deb_build_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_deb_build_dir_path->canonpath();
}

# _deb_parent_dir    {{{1
has '_deb_parent_dir_path' => (
  is       => 'ro',
  isa      => Types::Path::Tiny::AbsDir,
  coerce   => $TRUE,
  required => $TRUE,
  default  => sub {
    my $self = shift;
    $self->dir_temp();
  },
  documentation => 'Debian parent directory (temporary)',
);

sub _deb_parent_dir ($self) {   ## no critic (RequireInterpolationOfMetachars)
  return $self->_deb_parent_dir_path->canonpath();
}

# _debconf    {{{1
has '_debconf' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _debianise_dir    {{{1
has '_debianise_dir_path' => (
  is            => 'rw',
  isa           => Types::Path::Tiny::AbsDir,
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => q{Debian build directory's "debian" subdir},
);

sub _debianise_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_debianise_dir_path->canonpath();
}

# _desktop_file_list    {{{1
has '_desktop_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _desktop_files    => 'elements',
    _add_desktop_file => 'push',
  },
  documentation => 'Desktop files for packaging',
);

# _depends_list    {{{1
has '_depends_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _depends         => 'elements',
    _add_depends_pkg => 'push',
  },
  documentation => 'Package dependencies',
);

# _description_line_list    {{{1
has '_description_line_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Dn::Debian::PackageControlDescription],
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _description          => 'elements',
    _add_description_line => 'push',
    _has_description      => 'count',
  },
  documentation => 'Control file description field',
);

# _distribution_filepath    {{{1
has '_distribution_filepath' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Name of distribution file',
);

# _email    {{{1
has '_email' => (
  is            => 'rw',
  isa           => Types::Dn::EmailAddress,
  required      => $FALSE,
  documentation => 'Package maintainer email address',
);

# _extra_path_list    {{{1
has '_extra_path_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['Types::Path::Tiny::AbsPath'],
  ],
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _extra_paths      => 'elements',
    _add_extra_path   => 'push',
    _has_extra_paths  => 'count',
    _extra_path_count => 'count',
  },
  documentation => 'Extra files and directories for build tree',
);

# _icon_file_list    {{{1
has '_icon_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _icon_files    => 'elements',
    _add_icon_file => 'push',
  },
  documentation => 'Icon files for packaging',
);

# _install    {{{1
has '_install' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _libdata_file_list    {{{1
has '_libdata_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _libdata_files     => 'elements',
    _add_libdata_file  => 'push',
    _has_libdata_files => 'count',
  },
  documentation => 'Library data files for packaging',
);

# _libexec_file_list    {{{1
has '_libexec_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _libexec_files     => 'elements',
    _add_libexec_file  => 'push',
    _has_libexec_files => 'count',
  },
  documentation => 'Library executables for packaging',
);

# _man_file_list    {{{1
has '_man_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _man_files      => 'elements',
    _add_man_file   => 'push',
    _has_man_files  => 'count',
    _man_file_count => 'count',
  },
  documentation => 'Manpage files for packaging',
);

# _name    {{{1
has '_name' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  required      => $FALSE,
  documentation => 'Package name',
);

# _postinst    {{{1
has '_postinst' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _postrm    {{{1
has '_postrm' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _preinst    {{{1
has '_preinst' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _prerm    {{{1
has '_prerm' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _project_dir    {{{1
has '_project_dir_path' => (
  is       => 'rw',
  isa      => Types::Path::Tiny::AbsDir,
  coerce   => $TRUE,
  required => $TRUE,
  default  => sub {
    my $self = shift;
    $self->cwd();
  },
  documentation => 'Project directory',
);

sub _project_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return $self->_project_dir_path->canonpath();
}

# _resources_file    {{{1
has '_resources_file' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  required      => $TRUE,
  default       => 'deb-resources',
  documentation => 'Name of resource file',
);

# _sbin_file_list    {{{1
has '_sbin_file_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  ],
  coerce      => $TRUE,
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    _sbin_files      => 'elements',
    _add_sbin_file   => 'push',
    _has_sbin_files  => 'count',
    _sbin_file_count => 'count',
  },
  documentation => 'Superuser scripts for packaging',
);

# _summary    {{{1
has '_summary' => (
  is            => 'rw',
  isa           => Types::Dn::Debian::PackageControlDescription,
  required      => $FALSE,
  documentation => 'Control summary',
);

# _templates    {{{1
has '_templates' => (
  is            => 'rw',
  isa           => Types::Standard::InstanceOf [$MODULE_QKDEB_FILE],
  coerce        => $TRUE,
  required      => $FALSE,
  documentation => 'Debian build file',
);

# _version    {{{1
has '_version' => (
  is            => 'rw',
  isa           => Types::Dn::Debian::PackageVersion,
  required      => $FALSE,
  documentation => 'Version of package',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: result
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # create template flag overrides all other flags
  if ($self->create_template) {
    $self->_write_project_files();
    return;
  }

  # some project checks
  return if not $self->_project_checks();

  # process resource file
  $self->_process_resource_file();

  # user can increment version unless keeping current version
  if (not $self->keep_version) { $self->_bump_version(); }

  # create manpage file from pod if script is perl
  if (not $self->suppress_podman) {
    $self->_create_man_from_pod();
  }

  # create autotools project
  $self->_create_autotools_project();

  # delete current package files
  $self->_delete_existing_package();

  # debianise project
  $self->_debianise_project();

  # install package if requested
  if ($self->no_install) {
    say "\nNot installing package at your request" or croak;
  }
  else {
    $self->_install_deb();
  }
  return;
}

# _write_project_files()    {{{1
#
# does:   write resources file and git ignore file
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _write_project_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  $self->_write_resources_file();
  $self->_write_git_ignore_file();
  return;
}

# _write_resources_file()    {{{1
#
# does:   write deb-resources file
# params: nil
# prints: feedback and user interaction
# return: boolean
sub _write_resources_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # check whether overwriting existing file
  my $resource    = $self->_resources_file;
  my $project_dir = $self->_project_dir;
  my $resource_fp = $self->file_cat_dir($resource, $project_dir);
  if ($resource_fp and -r $resource_fp) {
    say "Resources file '$resource' is already present" or croak;
    if ($self->interact_confirm('Overwrite with new template file?')) {
      if (not(unlink $resource_fp)) {
        die "Unable to delete existing resource file\n";
      }
    }
    else {
      die "OK, aborting now\n";
    }
    return;
  }

  # set vars
  my $date = $self->date_current_iso();
  my $year = (split $DASH, $date)[0];
  my $time = $self->time_now();
  my $div  = $DASH x $PRINT_WIDTH;
  my @c;

  # create content
  ## no critic (ProhibitDuplicateLiteral RequireInterpolationOfMetachars)
  push @c,
      (
    q{# dn-qk-deb resources file},
    "# [generated by dn-qk-deb on $date at $time]",
    "# $div",
    q{# Each line consists of key-value pairs},
    q{# separated by whitespace. If any key or value contains},
    q{# whitespace it must be enclosed by double quotation marks.},
    q{# Empty lines and comment lines (beginning with hashes)},
    q{# are ignored.},
    q{# Any unrecognised key will generate a fatal error},
    q{# Any key without a value will generate a fatal error},
    q{# Some names can be used only once while others can},
    q{# be used multiple times.},
    "# $div",
    $SPACE,
    q{# Package name},
    q{# Name of the package to be generated.},
    q{# Must not contain whitespace.},
    q{# Required. One only.},
    q{package-name foo},
    $SPACE,
    q{# Package version},
    q{# Version number for package.},
    q{# Required. One only.},
    q{version 0.1},
    $SPACE,
    q{# Script and binary files},
    q{# Executable files to be packaged.},
    q{# Can be standard ('bin-file') or superuser-only ('sbin-file').},
    q{# Default value of 'bin-file' in built deb package: /usr/bin},
    q{# Default value of 'sbin-file' in built deb package: /usr/sbin},
    q{# Required (unless a library package). Multiple allowed},
    q{#bin-file },
    q{#sbin-file },
    $SPACE,
    q{# Manpages},
    q{# Man pages to package.},
    q{# Default location in built deb package: /usr/share/man/man1},
    q{# Required (unless a library package). Multiple allowed.},
    q{#man-file },
    $SPACE,
    q{# Data files},
    q{# Data files to package.},
    q{# Default location in built deb package: /usr/share/\$(PACKAGE).},
    q{# Optional. Multiple allowed.},
    q{#data-file },
    $SPACE,
    q{# Icon file},
    q{# Icon file to package.},
    q{# Must be xpm format no larger than 32x32.},
    q{# Useful command is: 'convert icon.png }
        . q{-geometry 32x32 icon.xpm'.},
    q{# Default location in built deb package: /usr/share/icons.},
    q{# Note icons are not put into an application subdirectory},
    q{# -- be careful of filename clashes.},
    q{# Optional. Multiple allowed.},
    q{#icon-file },
    $SPACE,
    q{# Desktop file},
    q{# Desktop file to package.},
    q{# Must conform to freedesktop.org Desktop Entry Specification},
    q{# (see http://standards.freedesktop.org/desktop-entry-spec/)},
    q{# Default location in built deb package: /usr/share/applications.},
    q{# Note desktop files are not put into an application subdirectory},
    q{# -- be careful of filename clashes.},
    q{# Optional. Multiple allowed.},
    q{#desktop-file },
    $SPACE,
    q{# Configuration files},
    q{# Configuration files to package.},
    q{# Default location in built deb package: /etc/\$(PACKAGE).},
    q{# Optional. Multiple allowed.},
    q{#conf-file },
    $SPACE,
    q{# Executable library files},
    q{# Executable programs run by other programs.},
    q{# Default value in built deb package: } . q{/usr/libexec/\$(PACKAGE).},
    q{# Optional. Multiple allowed.},
    q{#libexec-file },
    $SPACE,
    q{# Library data files},
    q{# Data files used by other programs.},
    q{# Default value in built deb package: } . q{/usr/lib/\$(PACKAGE).},
    q{# Optional. Multiple allowed.},
    q{#libdata-file },
    $SPACE,
    q{# Debconf file},
    q{# Debian build system debconf file},
    q{# In final package is named 'PACKAGE.config'},
    q{# Optional. One only},
    q{#debconf-file },
    $SPACE,
    q{# Templates file},
    q{# Debian build system templates file},
    q{# In final package is named 'PACKAGE.templates'},
    q{# Optional. One only},
    q{#templates-file },
    $SPACE,
    q{# Pre-install file},
    q{# Debian build system pre-install file},
    q{# In final package is named 'PACKAGE.preinst'},
    q{# Optional. One only},
    q{#preinstall-file },
    $SPACE,
    q{# Post-install file},
    q{# Debian build system post-install file},
    q{# In final package is named 'PACKAGE.postint'},
    q{# Optional. One only},
    q{#postinstall-file },
    $SPACE,
    q{# Pre-remove file},
    q{# Debian build system pre-remove file},
    q{# In final package is named 'PACKAGE.prerm'},
    q{# Optional. One only},
    q{#preremove-file },
    $SPACE,
    q{# Post-remove file},
    q{# Debian build system post-remove file},
    q{# In final package is named 'PACKAGE.postrm'},
    q{# Optional. One only},
    q{#postremove-file },
    $SPACE,
    q{# Bash completion file},
    q{# Debian build system bash completion file},
    q{# In final package is named 'PACKAGE.bash-completion'},
    q{# Optional. One only},
    q{#bash-completion-file },
    $SPACE,
    q{# Install file},
    q{# Debian build system install file},
    q{# In final package is named 'PACKAGE.install'},
    q{# Can be used in conjunction with 'extra-path' key},
    q{# Optional. One only},
    q{#install-file },
    $SPACE,
    q{# Extra files and directories},
    q{# Extra distribution files and directories},
    q{# Copied recursively into root of distribution},
    q{# Not added to deb package unless in combination},
    q{# with an install file (see 'install-file' key)},
    q{# Optional. Multiple allowed},
    q{#extra-path },
    $SPACE,
    q{# Control summary},
    q{# One line summary of script for inclusion in the},
    q{# package 'control' file.},
    q{# This, in turn, is displayed by many package managers.},
    q{# Must be no longer than 60 characters.},
    q{# Required. One only.},
    q{control-summary foo is used in widget generation},
    $SPACE,
    q{# Control description},
    q{# Description of script. This is a longer description},
    q{# than the one line summary and can stretch over},
    q{# multiple lines. Each line can be no longer than},
    q{# 60 characters. Paragraphs can be separated by a line},
    q{# consisting of a single period ('.'). This description},
    q{# will be included in the package 'control' file. This,},
    q{# in turn, is displayed by many package managers.},
    q{# Required. Multiple allowed.},
    q{control-description foo is experimental software},
    q{control-description used in the production of widgets},
    $SPACE,
    q{# Dependency},
    q{# The name of a single package this package depends on.},
    q{# Can include minimum version.},
    q{# Optional. Multiple allowed.},
    $SPACE,
    q{### Perl modules},
    $SPACE,
    q{#   perl, Carp, Env, English, experimental, Moo},
    q{depends-on libmoo-perl (>= 2.005005-1)},
    $SPACE,
    q{#   Const::Fast},
    q{depends-on libconst-fast-perl (>= 0.014-2)},
    $SPACE,
    q{#   MooX::HandlesVia},
    q{depends-on libmoox-handlesvia-perl (>= 0.001008-2)},
    $SPACE,
    q{#   MooX::Options},
    q{depends-on libmoox-options-perl (>= 4.018-1)},
    $SPACE,
    q{#   namespace::clean},
    q{depends-on libnamespace-clean-perl (>= 0.25-1)},
    $SPACE,
    q{#   Path::Tiny},
    q{depends-on libpath-tiny-perl (>= 0.072-1)},
    $SPACE,
    q{#   strictures},
    q{depends-on libstrictures-perl (>= 2.000001-2)},
    $SPACE,
    q{#   Try::Tiny},
    q{depends-on libtry-tiny-perl (>= 0.22-1)},
    $SPACE,
    q{#   Types::Common::Numeric, Types::Common::String, }
        . q{Types::Standard},
    q{depends-on libtype-tiny-perl (>= 1.000005-1)},
    $SPACE,
    q{#   Types::Path::Tiny},
    q{depends-on libtypes-path-tiny-perl (>= 0.005-1)},
    $SPACE,
    q{#   version},
    q{depends-on libversion-perl (>= 1:0.9912-1)},
    $SPACE,
    q{##   },
    q{#depends-on  (>= },
    q{#)},
    $SPACE,
    q{### Executables},
    $SPACE,
    q{##   },
    q{#depends-on  (>= },
    q{#)},
    $SPACE,
    q{# Copyright year},
    q{# Year of copyright},
    q{# Required. One only.},
    "year $year",
    $SPACE,
    q{# Email},
    q{# Email address of package maintainer},
    q{# Required. One only.},
    q{email maintainer@user.org},
    $SPACE,
    q{# Author},
    q{# Author of script},
    q{# Required. Multiple allowed.},
    q{author John Citizen},
      );
  ## use critic

  # write file
  $self->file_write([@c], $resource_fp);
  say "Wrote resources file '$resource'" or croak;

  return;
}

# _write_git_ignore_file()
#
# does:   write .gitignore file
# params: nil
# prints: nil
# return: n/a
sub _write_git_ignore_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  #  do not overwrite existing file
  my $ignore      = '.gitignore';
  my $project_dir = $self->_project_dir;
  my $ignore_fp   = $self->file_cat_dir($ignore, $project_dir);
  if (-r $ignore_fp) { return; }

  # set vars
  my @c;

  # create content
  push @c,
      (
    q{*.deb}, q{*.diff.gz}, q{*.dsc}, q{*.orig},
    q{*.tar}, q{*.gz},      q{*.1},   q{tags},
      );

  # write file
  $self->file_write([@c], $ignore_fp);
  say "Wrote git ignore file '$ignore'" or croak;

  return;
}

# _project_checks()    {{{1
#
# does:   checks for resource file and needed tools
# params: nil
# prints: message if error detected
# return: boolean
sub _project_checks ($self) {   ## no critic (RequireInterpolationOfMetachars)
  my $sane = $TRUE;

  # resource file
  my $resource = $self->path_true($self->_resources_file);
  if (not $resource) {
    say "Unable to find resource file '$resource'" or croak;
    $sane = $FALSE;
  }

  # tools
  my @tools = qw(aclocal automake autoconf make
      dh_make dpkg-buildpackage);
  for my $tool (@tools) {
    if (not $self->path_executable($tool)) {
      say "Unable to locate required tool '$tool'" or croak;
      $sane = $FALSE;
    }
  }

  # return
  return $sane;
}

# _process_resource_file()    {{{1
#
# does:   extracts details from resource file
# params: nil
# prints: nil
# return: boolean
sub _process_resource_file ($self)
{    ## no critic (RequireInterpolationOfMetachars ProhibitExcessComplexity)
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_project_dir;
  my $resource    = $self->_resources_file;
  my $content_ref = $self->file_read($resource);
  my @content     = @{$content_ref};
  for my $index (0 .. $#content) {
    my $line = $content[$index];
    next if $line =~ /^\s*\z/xsm;    # skip empty lines
    next if $line =~ /^\s*\#/xsm;    # skip comment lines
    my ($key, @values) = split /\s/xsm, $line;
    my $value = join $SPACE, @values;
    if ($value =~ /^\s*\z/xsm) {
      warn "Key '$key' has no value\n";
      warn "This may result in a fatal error\n";
    }
    for ($key) {
      ## no critic (ProhibitCascadingIfElse)
      if    (/^author\z/xsm) { $self->_add_author($value); }
      elsif (/^bash-completion-file\z/xsm) {
        $self->_qkpath($value, 'bashcomp');
      }
      elsif (/^bin-file\z/xsm) { $self->_qkpath($value, 'bin'); }
      elsif (/^conf-file\z/xsm) {
        $self->_qkpath($value, 'conf');
      }
      elsif (/^control-description\z/xsm) {
        $self->_add_description_line($value);
      }
      elsif (/^control-summary\z/xsm) {
        $self->_summary($value);
      }
      elsif (/^data-file\z/xsm) {
        $self->_qkpath($value, 'data');
      }
      elsif (/^debconf-file\z/xsm) {
        $self->_qkpath($value, 'debconf');
      }
      elsif (/^desktop-file\z/xsm) {
        $self->_qkpath($value, 'desktop');
      }
      elsif (/^depends-on\z/xsm) {
        $self->_add_depends_pkg($value);
      }
      elsif (/^email\z/xsm) { $self->_email($value); }
      elsif (/^extra-path\z/xsm) {
        $self->_qkpath($value, 'extra');
      }
      elsif (/^icon-file\z/xsm) {
        $self->_qkpath($value, 'icon');
      }
      elsif (/^install-file\z/xsm) {
        $self->_qkpath($value, 'install');
      }
      elsif (/^libdata-file\z/xsm) {
        $self->_qkpath($value, 'libdata');
      }
      elsif (/^libexec-file\z/xsm) {
        $self->_qkpath($value, 'libexec');
      }
      elsif (/^man-file\z/xsm)     { $self->_qkpath($value, 'man'); }
      elsif (/^package-name\z/xsm) { $self->_name($value); }
      elsif (/^postinstall-file\z/xsm) {
        $self->_qkpath($value, 'postinst');
      }
      elsif (/^postremove-file\z/xsm) {
        $self->_qkpath($value, 'postrm');
      }
      elsif (/^preinstall-file\z/xsm) {
        $self->_qkpath($value, 'preinst');
      }
      elsif (/^preremove-file\z/xsm) {
        $self->_qkpath($value, 'prerm');
      }
      elsif (/^sbin-file\z/xsm) {
        $self->_qkpath($value, 'sbin');
      }
      elsif (/^templates-file\z/xsm) {
        $self->_qkpath($value, 'templates');
      }
      elsif (/^version\z/xsm) {
        $self->_version(Dpkg::Version->new($value));
      }
      elsif (/^year\z/xsm) { $self->_copyright($value); }
      else {
        my $line_num = $index + 1;
        my @err      = (
          "Error processing resources file '$resource'\n",
          "Unrecognised keyword '$key' at line $line_num\n",
        );
        croak @err;
      }
      ## use critic
    }
  }
  $self->_check_resources();

  return;
}

# _qkpath($path, $type)    {{{1
#
# does:   makes an appropriate file or path object
# params: $path - path name
#                 [required; can be any relative or absolute
#                  filepath or dirpath for 'extra',
#                  otherwise must be a file name]
#         $type - file type
#                 [required, must be one of 'bashcomp', 'bin',
#                  'conf', 'data', 'desktop', 'distro', 'icon',
#                  'extra', 'install', 'libdata', 'libexec',
#                  'man', 'postinst', 'postrm', 'preinst',
#                  'prerm', 'sbin', 'templates']
# prints: nil, except error messages
# return: n/a, dies on failure
sub _qkpath ($self, $path, $type)
{    ## no critic (RequireInterpolationOfMetachars ProhibitExcessComplexity)
  ## no critic (ProhibitCascadingIfElse ProhibitDuplicateLiteral)
  if ($type eq 'bashcomp') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_bashcomp($qkdeb);
  }
  elsif ($type eq 'bin') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_bin_file($qkdeb);
  }
  elsif ($type eq 'conf') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_conf_file($qkdeb);
  }
  elsif ($type eq 'data') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_data_file($qkdeb);
  }
  elsif ($type eq 'debconf') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_debconf($qkdeb);
  }
  elsif ($type eq 'desktop') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_desktop_file($qkdeb);
  }
  elsif ($type eq 'distro') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_distribution_filepath($qkdeb);
  }
  elsif ($type eq 'extra') {
    my $qkdeb = App::Dn::QkDeb::Path->new(path => $path);
    $self->_add_extra_path($qkdeb);
  }
  elsif ($type eq 'icon') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_icon_file($qkdeb);
  }
  elsif ($type eq 'install') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_install($qkdeb);
  }
  elsif ($type eq 'libdata') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_libdata_file($qkdeb);
  }
  elsif ($type eq 'libexec') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_libexec_file($qkdeb);
  }
  elsif ($type eq 'man') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_man_file($qkdeb);
  }
  elsif ($type eq 'postinst') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_postinst($qkdeb);
  }
  elsif ($type eq 'postrm') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_postrm($qkdeb);
  }
  elsif ($type eq 'preinst') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_preinst($qkdeb);
  }
  elsif ($type eq 'prerm') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_prerm($qkdeb);
  }
  elsif ($type eq 'sbin') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_add_sbin_file($qkdeb);
  }
  elsif ($type eq 'templates') {
    my $qkdeb = App::Dn::QkDeb::File->new(file => $path);
    $self->_templates($qkdeb);
  }
  else {
    confess "Invalid path type '$type'";
  }
  ## use critic
  return;
}

# _check_resources()    {{{1
#
# does:   checks data retrieved from resources file
# params: nil
# prints: feedback if fails
# return: n/a, dies on failure
sub _check_resources ($self) {  ## no critic (RequireInterpolationOfMetachars)
  my @errors;

  # standard and library packages have different requirements
  if ($self->library_package) {

    # need library files, not scripts or man files
    if (
      not( $self->_has_libexec_files
        or $self->_has_libdata_files)
        )
    {
      push @errors, "No library files specified in library package\n";
    }
  }
  else {
    # standard package requires scripts and man files
    if (not($self->_has_bin_files or $self->_has_sbin_files)) {
      push @errors, "No script files specified\n";
    }
    if (not $self->_has_man_files) {
      push @errors, "No man files specified\n";
    }
  }
  if (not $self->_has_authors) {
    push @errors, "No package author names specified\n";
  }
  if (not $self->_summary) {
    push @errors, "No control control summary specified\n";
  }
  if (not $self->_has_description) {
    push @errors, "No package control description specified\n";
  }
  if (not $self->_email) {
    push @errors, "No package maintainer email address specified\n";
  }
  if (not $self->_name) {
    push @errors, "No package name specified\n";
  }
  if (not $self->_version) {
    push @errors, "No package version specified\n";
  }
  if (not $self->_copyright) {
    push @errors, "No package copyright year specified\n";
  }
  if (@errors) {
    warn @errors;    ## no critic (RequireCarping)
    my $start = ($self->ignore_errors) ? q{E} : q{Fatal e};
    my $msg   = "(${start}rror|${start}rrors) detected\n";
    $msg = $self->pluralise($msg, scalar @errors);
    warn "$msg\n";
    if ($self->ignore_errors) {
      warn "Proceeding anyway, as requested\n";
    }
    else {
      die "Aborting\n";
    }
  }
  return;
}

# _bump_version()    {{{1
#
# does:   increment version number if user wishes to
# params: nil
# prints: user interaction
# return: n/a - die if error
sub _bump_version ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # user has option to enter new version
  my $current;
  if ($self->_version()) {
    $current = $self->_version();
  }
  my $prompt = 'Enter package version:';
  my $default;
  if ($current) { $default = $current->as_string(); }
  my $new_string = $self->interact_ask($prompt, $default);
  if (not $new_string) {
    if ($current) {
      say $MSG_KEEP_VER or croak;
      return;
    }
    else {
      die "Cannot build package without version number\n";
    }
  }

  # check validity
  my $new = Dpkg::Version->new($new_string);
  if (not $new->is_valid()) {
    die "Invalid version\n";
  }
  if ($current) {
    if ($new == $current) {
      say $MSG_KEEP_VER or croak;
      return;
    }
    if ($new < $current) {
      die "New version cannot be lower than current version\n";
    }
  }

  # okay, set new version
  $self->_version($new);
  $self->_update_resources_version();

  return;
}

# _update_resources_version()    {{{1
#
# does:   update resources file with new version
# params: nil
# prints: nil
# return: n/a, die on failure
sub _update_resources_version ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $resource    = $self->_resources_file;
  my $project_dir = $self->_project_dir;
  my $resource_fp = $self->file_cat_dir($resource, $project_dir);
  my $version     = $self->_version->as_string();
  my $fh;

  # read in resources file
  my $resources_ref = $self->file_read($resource_fp);
  my @resources     = @{$resources_ref};

  # adjust version
  for my $line (@resources) {
    if ($line =~ /^\s*version\s+([\S+])/xsm) {
      $line = "version $version";
    }
  }

  # write back resources file
  $self->file_write([@resources], $resource_fp);

  return;
}

# _create_man_from_pod()    {{{1
#
# does:   create man file from pod if perl
# params: nil
# prints: feedback
# return: nil
sub _create_man_from_pod ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # only create man from pod if:
  # - one perl script file (user or superuser), and
  # - one man file
  my @scripts;
  if ($self->_bin_file_count == 1) {
    push @scripts, ($self->_bin_files)[0];
  }
  if ($self->_sbin_file_count == 1) {
    push @scripts, ($self->_sbin_files)[0];
  }
  if (scalar @scripts != 1) { return; }
  my $script = $scripts[0]->real;
  if (not $self->file_is_perl($script)) { return; }
  if ($self->_man_file_count != 1)      { return; }
  my $man = ($self->_man_files)[0]->real;

  # create manpage file
  say 'Writing man page from script pod' or croak;
  my $parser = Pod::Man->new();
  $parser->parse_from_file($script, $man);

  return;
}

# _create_autotools_project()    {{{1
#
# does:   create autotools project
# params: nil
# prints: feedback
# return: n/a - die on failure
sub _create_autotools_project ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $cmd;

  # copy project files to build directory
  $self->_copy_project();

  # write autotools files
  $self->_write_build_files();

  # run aclocal, automake and autoconf
  my $silent = $TRUE;    # default
  if ($self->autotools_feedback) { $silent = $FALSE; }
  my @autoreconf;
  push @autoreconf, ['aclocal'];
  push @autoreconf, [ 'automake', '--gnu', '--add-missing' ];
  push @autoreconf, ['autoconf'];
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;

  foreach my $cmd (@autoreconf) {
    $self->shell_command($cmd, { silent => $silent, fatal => $TRUE });
  }

  # run configure and make dist
  $cmd = [ './configure', '--prefix=/usr' ];
  $self->shell_command($cmd, { silent => $FALSE, fatal => $TRUE });
  $cmd = [ 'make', 'dist' ];
  $self->shell_command($cmd, { silent => $TRUE, fatal => $TRUE });
  system 'ls';

  return;
}

# _copy_project()    {{{1
#
# does:   copy project files to build directory
# params: nil
# prints: feedback
# return: n/a - die on failure
sub _copy_project ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # cannot simply copy true paths to build directory because
  # for symlinked files the file name in the true path may differ
  # from the symlink name -- the method used below ensures the
  # name of the original symlink is used in the build directory

  # copy project files
  my @filepaths;
  push @filepaths, $self->_bin_files, $self->_sbin_files,
      $self->_man_files,     $self->_data_files,    $self->_conf_files,
      $self->_icon_files,    $self->_desktop_files, $self->_libexec_files,
      $self->_libdata_files, $self->_debconf,       $self->_templates,
      $self->_preinst,       $self->_postinst, $self->_prerm, $self->_postrm,
      $self->_bashcomp,      $self->_install;

  # get true paths for files
  my %files;
  foreach my $filepath (@filepaths) {
    if ($filepath) {
      my $filename = $filepath->name;
      $files{$filename} = $filepath->real;
    }
  }

  # copy files to build directory
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;
  for my $file (keys %files) {
    my $true_path   = $files{$file};
    my $source      = $true_path;
    my $destination = $self->file_cat_dir("$file.in", $File::chdir::CWD);
    $self->path_copy($source, $destination)
        or confess "Copy failed: $OS_ERROR";
  }

  # finally, copy extra files and directories
  # - these care copied without the '.in' suffix
  $self->_copy_extras;

  return;
}

# _copy_extras()    {{{1
#
# does:   copy extra files and directories to build directory
# params: nil
# prints: feedback
# return: n/a - die on failure
# note:   these files and directories are copied with their
#         names unchanged, i.e., without '.in' suffix
sub _copy_extras ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # cannot simply copy true paths to build directory because
  # for symlinked files the file name in the true path may differ
  # from the symlink name -- the method used below ensures the
  # name of the original symlink is used in the build directory

  # extra files and directories
  my @extras;
  push @extras, $self->_extra_paths;

  # get true paths
  my %truepaths;
  foreach my $extra (@extras) {
    if ($extra) {
      my $base = $extra->name;
      $truepaths{$base} = $extra->real;
    }
  }

  # copy extra paths to build directory
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $self->_build_dir;
  for my $basename (keys %truepaths) {
    my $truepath = $truepaths{$basename};
    my $source   = $truepath;
    my $destination;
    for ($source) {
      if (-f) {    ## no critic (ProhibitFiletest_f)
        $destination = $self->file_cat_dir($basename, $File::chdir::CWD);
        $destination = $self->file_cat_dir($basename, $File::chdir::CWD);
      }
      elsif (-d) {
        $destination = $self->dir_join($File::chdir::CWD, $basename);
      }
      else { confess "Error processing extra path '$source'"; }
    }
    $self->path_copy($source, $destination)
        or confess "Copy failed: $OS_ERROR";
  }
  return;
}

# _write_build_files()    {{{1
#
# does: write build files to build directory
# params: nil
# prints: nil
# return: n/a
sub _write_build_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  $self->_write_configure_file();
  $self->_write_makefile_file();

  #$self->_write_news_file();
  #$self->_write_readme_file();
  #$self->_write_authors_file();
  #$self->_write_changelog_file();

  return;
}

# _write_configure_file()    {{{1
#
# does:   write configure.ac file
# params: nil
# prints: nil
# return: n/a
sub _write_configure_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $name          = $self->_name;
  my $prereq        = $self->autoconf_version();
  my $summary       = $self->_summary;
  my $version       = $self->_version->as_string();
  my $email         = $self->_email;
  my @bin_files     = $self->_bin_files;
  my @sbin_files    = $self->_sbin_files;
  my @man_files     = $self->_man_files;
  my @data_files    = $self->_data_files;
  my @conf_files    = $self->_conf_files;
  my @icon_files    = $self->_icon_files;
  my @desktop_files = $self->_desktop_files;
  my @libexec_files = $self->_libexec_files;
  my @libdata_files = $self->_libdata_files;
  my @c;

  # create content
  ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)
  push @c,
      (
    qq{# configure.ac for $name project},
    $SPACE,
    q{# Initialise project},
    qq{AC_PREREQ([$prereq])},
    q{AC_INIT(},
    qq{[$summary],},
    qq{[$version],},
    qq{[$email],},
    qq{[$name],},
    q{)},
    q{AM_INIT_AUTOMAKE([foreign])},
    $EMPTY_STRING,
    q{# Checks for programs/files},
    q{mypath="/usr:/usr/bin:/usr/local/bin"},
    $EMPTY_STRING,
    q{# Checks for libraries},
    $EMPTY_STRING,
    q{# Variable replacement},
    q{# [not all currently implemented in dn-qk-deb]},
    $EMPTY_STRING,
    q{# pkg},
    q{# - package name},
    qq{pkg="$name"},
    q{AC_SUBST(pkg)},
    $EMPTY_STRING,
    q{# bin_dir},
    q{# - user executables},
    q{# - default value in built deb package: /usr/bin},
    q{bin_dir="${prefix}/bin"},
    q{AC_SUBST(bin_dir)},
    $EMPTY_STRING,
    q{# sbin},
    q{# - superuser executables},
    q{# - default value in built deb package: /usr/sbin},
    q{sbin_dir="${prefix}/sbin"},
    q{AC_SUBST(sbin_dir)},
    $EMPTY_STRING,
    q{# data_dir},
    q{# - read-only architecture-independent data files},
    q{# - default value in built deb package: /usr/share},
    q{data_dir="${prefix}/share"},
    q{AC_SUBST(data_dir)},
    $EMPTY_STRING,
    q{# pkgdata_dir},
    q{# - package read-only architecture-independent data files},
    qq{# - default value in built deb package: /usr/share/$name},
    q{pkgdata_dir="${prefix}/share/} . $name . $DOUBLE_QUOTE,
    q{AC_SUBST(pkgdata_dir)},
    $EMPTY_STRING,
    q{# lib_dir},
    q{# - root for hierarchy of libraries},
    q{# - default value in built deb package: } . q{/usr/lib},
    q{#   but occasionally overridden to /lib }
        . q{in important packages, e.g., udev},
    q{lib_dir="${prefix}/lib"},
    q{AC_SUBST(lib_dir)},
    $EMPTY_STRING,
    q{# pkglib_dir},
    q{# - package libraries},
    qq{# - default value in built deb package: /usr/lib/$name},
    qq{#   but occasionally overridden to /lib/$name},
    q{#   in important packages, e.g., udev},
    q{pkglib_dir="${prefix}/lib/} . $name . $DOUBLE_QUOTE,
    q{AC_SUBST(pkglib_dir)},
    $EMPTY_STRING,
    q{# libexec_dir},
    q{# - root for hierarchy of executables run by other},
    q{#   executables, not user},
    q{# - default value in built deb package: } . q{/usr/lib},
    q{libexec_dir="${prefix}/libexec"},
    q{AC_SUBST(libexec_dir)},
    $EMPTY_STRING,
    q{# pkglibexec_dir},
    q{# - package executables run by } . q{other executables, not user},
    qq{# - default value in built deb package: /usr/lib/$name},
    qq{#   but occasionally overridden to /lib/$name},
    q{#   in important packages, e.g., udev},
    q{pkglib_dir="${prefix}/libexec/} . $name . $DOUBLE_QUOTE,
    q{AC_SUBST(pkglibexec_dir)},
    $EMPTY_STRING,
    q{# icons_dir},
    q{# - debian main icon directory},
    q{# - default value in built deb package: /usr/share/icons},
    q{# - note no app subdirectory in icons directory},
    q{icons_dir="${prefix}/share/icons"},
    q{AC_SUBST(icons_dir)},
    $EMPTY_STRING,
    q{# desktop_dir},
    q{# - debian directory for application desktop files},
    q{# - default value in built deb package: /usr/share/applications},
    q{# - note no app subdirectory in applications directory},
    q{desktop_dir="${prefix}/share/applications"},
    q{AC_SUBST(desktop_dir)},
    $EMPTY_STRING,
    q{# localstate_dir},
    q{# - arch-independent data files modified while running},
    q{# - default value in built deb package: /var},
    q{#localstate_dir="${localstatedir}"},
    q{#AC_SUBST(localstate_dir)},
    $EMPTY_STRING,
    q{# sharedstate_dir},
    q{# - machine-specific data files modified while running},
    q{# - default value in built deb package: /usr/com},
    q{#   but this is not a valid debian directory so }
        . q{commonly overriden to},
    q{#   /var/lib in debian rules file},
    q{#sharedstate_dir="${sharedstatedir}"},
    q{#AC_SUBST(sharedstate_dir)},
    $EMPTY_STRING,
    q{# pkgvar_dir},
    q{# - package-specific data files modified while running},
    qq{# - default value in built deb package: /var/lib/$name},
    q{#pkgvar_lib="${localstatedir}/lib/} . $name,
    q{#AC_SUBST(pkgvar_lib)},
    $EMPTY_STRING,
    q{# sysconf_dir},
    q{# - system configuration files},
    q{# - default value in built deb package: /etc},
    q{sysconf_dir="${sysconfdir}"},
    q{AC_SUBST(sysconf_dir)},
    $EMPTY_STRING,
    q{# pkgconf_dir},
    q{# - package configuration files},
    qq{# - default value in built deb package: /etc/$name},
    q{pkgconf_dir="${sysconf_dir}/} . $name . $DOUBLE_QUOTE,
    q{AC_SUBST(pkgconf_dir)},
    $EMPTY_STRING,
    q{# pkgdoc_dir},
    q{# - package documentation},
    q{# - default value in built deb package: } . q{/usr/share/doc/$name},
    q{#pkgdoc_dir="${data_dir}/doc/} . $name . $DOUBLE_QUOTE,
    q{#AC_SUBST(pkgdoc_dir)},
    $EMPTY_STRING,
    q{# man_dir},
    q{# - manpage files},
    q{# - default value in built deb package: /usr/share/man},
    q{#man_dir="${prefix}/share/man"},
    q{#AC_SUBST(man_dir)},
    $EMPTY_STRING,
    q{# Create files},
    q{AC_CONFIG_FILES([},
    q{Makefile},
      );
  ## use critic

  if (@bin_files) {
    push @c, $self->_concat_filenames(@bin_files);
  }
  if (@sbin_files) {
    push @c, $self->_concat_filenames(@sbin_files);
  }
  if (@man_files) {
    push @c, $self->_concat_filenames(@man_files);
  }
  if (@data_files) {
    push @c, $self->_concat_filenames(@data_files);
  }
  if (@conf_files) {
    push @c, $self->_concat_filenames(@conf_files);
  }
  if (@icon_files) {
    push @c, $self->_concat_filenames(@icon_files);
  }
  if (@desktop_files) {
    push @c, $self->_concat_filenames(@desktop_files);
  }
  if (@libexec_files) {
    push @c, $self->_concat_filenames(@libexec_files);
  }
  if (@libdata_files) {
    push @c, $self->_concat_filenames(@libdata_files);
  }
  push @c, (q{])}, q{AC_OUTPUT});

  # write file
  my $write_dir = $self->_build_dir;
  my $file      = $self->file_cat_dir('configure.ac', $write_dir);
  $self->file_write([@c], $file);

  return;
}

# _concat_filenames(@files)    {{{1
#
# does:   takes App::Dn::QkDeb::File objects and concatenates file names
# params: @files - App::Dn::QkDeb::File objects [required]
# prints: nil, except error messages
# return: scalar string, dies on failure
sub _concat_filenames ($self, @files)
{    ## no critic (RequireInterpolationOfMetachars)
  my @names;
  foreach my $file (@files) {
    push @names, $file->name;
  }
  my $concat = join $SPACE, @names;
  return $concat;
}

# _write_makefile_file()
#
# does:   write Makefile.am file
# params: nil
# prints: nil
# return: n/a
sub _write_makefile_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $name          = $self->_name;
  my @bin_files     = $self->_bin_files;
  my @sbin_files    = $self->_sbin_files;
  my @man_files     = $self->_man_files;
  my @data_files    = $self->_data_files;
  my @conf_files    = $self->_conf_files;
  my @icon_files    = $self->_icon_files;
  my @desktop_files = $self->_desktop_files;
  my @libexec_files = $self->_libexec_files;
  my @libdata_files = $self->_libdata_files;
  my @extra_paths   = $self->_extra_paths;
  my @c;

  # create content
  push @c, (qq{# Makefile.am for $name project}, $SPACE, q{# Directories});

  # - directories if required
  # - using directory variables defined in configure.ac
  ## no critic (RequireInterpolationOfMetachars)
  if (@conf_files) {
    push @c, q{pkgconfdir = @sysconfdir@/} . $name;
  }
  if (@libdata_files) {
    push @c, q{pkglibdir = @prefix@/lib/} . $name;
  }
  if (@icon_files) {
    push @c, q{icondir = @data_dir@/icons};
  }
  if (@desktop_files) {
    push @c, q{desktopdir = @data_dir@/applications};
  }
  ## use critic

  # - binary scripts
  my @script_lines;
  if (@bin_files) {
    my $files = $self->_concat_filenames(@bin_files);
    push @script_lines, qq{bin_SCRIPTS = $files};
  }
  if (@sbin_files) {
    my $files = $self->_concat_filenames(@sbin_files);
    push @script_lines, qq{sbin_SCRIPTS = $files};
  }
  if (@script_lines) {
    push @c, $SPACE;
    push @c, q{# Binary (script) files};
    foreach my $line (@script_lines) {
      push @c, $line;
    }
  }

  # - manpages
  if (@man_files) {
    my $files = $self->_concat_filenames(@man_files);
    ## no critic (ProhibitDuplicateLiteral)
    push @c, ($SPACE, q{# Manpages}, qq{man_MANS = $files});
    ## use critic
  }

  # - data files
  if (@data_files) {
    my $files = $self->_concat_filenames(@data_files);
    ## no critic (ProhibitDuplicateLiteral)
    push @c, ($SPACE, q{# Data files}, qq{pkgdata_DATA = $files});
    ## use critic
  }

  # - conf files
  if (@conf_files) {
    my $files = $self->_concat_filenames(@conf_files);
    ## no critic (ProhibitDuplicateLiteral)
    push @c, ($SPACE, q{# Configuration files}, qq{pkgconf_DATA = $files});
    ## use critic
  }

  # - icon files
  if (@icon_files) {
    my $files = $self->_concat_filenames(@icon_files);
    push @c, ($SPACE, q{# Icon files}, qq{icon_DATA = $files});
  }

  # - desktop files
  if (@desktop_files) {
    my $files = $self->_concat_filenames(@desktop_files);
    push @c, ($SPACE, q{# Desktop files}, qq{desktop_DATA = $files});
  }

  # - library files
  my @lib_lines;
  if (@libexec_files) {
    my $files = $self->_concat_filenames(@libexec_files);
    push @lib_lines, qq{pkglibexec_SCRIPTS = $files};
  }
  if (@libdata_files) {
    my $files = $self->_concat_filenames(@libdata_files);
    push @lib_lines, qq{pkglib_DATA = $files};
  }
  if (@lib_lines) {
    push @c, ($SPACE, q{# Library files});
    foreach my $line (@lib_lines) {
      push @c, $line;
    }
  }

  # - extra files and directories
  if (@extra_paths) {
    my @extra_bases = map { $_->name } @extra_paths;
    my $extras      = join $SPACE, @extra_bases;
    push @c, ($SPACE, q{# Extras}, qq{EXTRA_DIST = $extras});
  }

  # write file
  my $write_dir = $self->_build_dir;
  my $file      = $self->file_cat_dir('Makefile.am', $write_dir);
  $self->file_write([@c], $file);

  return;
}

# _write_news_file()    {{{1
#
# does:   write news file
# params: nil
# prints: nil
# return: n/a
# note:   currently unused but keep legacy subroutine
sub _write_news_file ($self)
{ ## no critic (RequireInterpolationOfMetachars ProhibitUnusedPrivateSubroutines)

  # set vars
  my $name = $self->_name;
  my $date = $self->date_email();
  my @c;
  my $divider = q{--------------------------------------------};

  # create content
  push @c,
      (
    qq{$name NEWS}, q{====================}, $SPACE, $divider, $date,
    $SPACE,         q{- Automatically packaged by dn-qk-deb},
    $divider,       $SPACE,
      );

  # write file
  my $write_dir = $self->_build_dir;
  my $file      = $self->file_cat_dir('NEWS', $write_dir);
  $self->file_write([@c], $file);

  return;
}

# _write_readme_file()    {{{1
#
# does:   write README file
# params: nil
# prints: nil
# return: n/a
# note:   currently unused but keep legacy subroutine
sub _write_readme_file ($self)
{ ## no critic (RequireInterpolationOfMetachars ProhibitUnusedPrivateSubroutines)

  # set vars
  my $name        = $self->_name;
  my @description = $self->_description;
  my @c;

  # get file content
  push @c, (qq{$name README}, q{======================}, $SPACE);
  foreach my $line (@description) {
    if ($line =~ /^\s*[.]\s*\z/xsm) {    # blank line
      push @c, $SPACE;
    }
    else {
      push @c, $line;
    }
  }
  push @c, ($SPACE, q{See manpage for further information.});

  # write file
  my $write_dir = $self->_build_dir;
  my $file      = $self->file_cat_dir('README', $write_dir);
  $self->file_write([@c], $file);

  return;
}

# _write_authors_file()    {{{1
#
# does:   write AUTHORS file
# params: nil
# prints: nil
# return: n/a
# note:   currently unused but keep legacy subroutine
sub _write_authors_file ($self)
{ ## no critic (RequireInterpolationOfMetachars ProhibitUnusedPrivateSubroutines)

  # set vars
  my $name    = $self->_name;
  my $authors = join q{, }, $self->_authors;
  my @c;

  # create content
  push @c, (qq{$name AUTHORS}, q{=======================}, $SPACE, $authors);

  # write file
  my $write_dir = $self->_build_dir;
  my $file      = $self->file_cat_dir('AUTHORS', $write_dir);
  $self->file_write([@c], $file);

  return;
}

# _write_changelog_file()    {{{1
#
# does:   write ChangeLog file
# params: nil
# prints: nil
# return: n/a
# note:   currently unused but keep legacy subroutine
sub _write_changelog_file ($self)
{ ## no critic (RequireInterpolationOfMetachars ProhibitUnusedPrivateSubroutines)

  # set vars
  my $name   = $self->_name;
  my $dir    = $self->_project_dir;
  my $gitdir = $dir . '/.git';
  my $date   = $self->date_current_iso();
  my $author = $self->_primary_author;
  my $email  = $self->_email;
  my @c;

  # create content
  if (-d $gitdir) {

    # can use git
    push @c, $self->changelog_from_git($dir);
  }
  if (not @c) {

    # can't use git, so have minimal default
    push @c,
        (
      "$date  $author <$email>",
      q{    * Automatically packaged by dn-qk-deb},
        );
  }

  # write file
  my $write_dir = $self->_build_dir;
  my $file      = $self->file_cat_dir('ChangeLog', $write_dir);
  $self->file_write([@c], $file);

  return;
}

# _delete_existing_package()    {{{1
#
# does:   delete *.deb, *.diff.gz, *.dsc and *.orig.tar.gz
# params: nil
# prints: nil
# return: n/a, die on failure
sub _delete_existing_package ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my @patterns;
  push @patterns, qr{[.]deb\Z}xsm;                # *.deb
  push @patterns, qr{[.]diff[.]gz\Z}xsm;          # *.diff.gz
  push @patterns, qr{[.]dsc\Z}xsm;                # *.dsc
  push @patterns, qr{[.]orig[.]tar[.]gz\Z}xsm;    # *.orig.tar.gz
  my $dir = $self->_project_dir;
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $dir;

  foreach my $pattern (@patterns) {
    my @files = $self->file_list($dir, $pattern);
    for my $file (@files) {
      if (not(unlink $file)) {
        confess "Unable to delete '$file'";
      }
    }
  }
  return;
}

# _debianise_project()    {{{1
#
# does:   create debian package files and copy to project dir
# params: nil
# prints: feedback
# return: n/a, die on failure
sub _debianise_project ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  $self->_extract_distro();
  $self->_initial_debianisation();
  $self->_configure_debian_subdir();
  $self->_build_package();

  return;
}

# _extract_distro()    {{{1
#
# does:   extract distribution file in deb parent directory
# params: nil
# prints: feedback
# return: n/a, die on failure
sub _extract_distro ($self) {   ## no critic (RequireInterpolationOfMetachars)
  my $build_dir      = $self->_build_dir;
  my $deb_parent_dir = $self->_deb_parent_dir;

  # copy distribution file to debian parent directory
  my @distros = $self->file_list($build_dir, $RE_TAR_GZ);
  if (scalar @distros < 1) { confess 'No distro file'; }
  if (scalar @distros > 1) { confess 'Multiple distro files'; }
  my $distro = $distros[0];
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $build_dir;
  if (not($self->path_copy($distro, $deb_parent_dir))) {
    confess "Failed to copy '$distro' to deb parent dir";
  }

  # extract distribution
  $distro = ($self->file_list($deb_parent_dir, $RE_TAR_GZ))[0];
  if (not -e $distro) {
    confess 'Cannot find distro in deb parent directory';
  }
  my $archive = Archive::Tar->new($distro);
  if (not $archive) { confess "Unable to parse '$distro'"; }
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $deb_parent_dir;
  if (not $archive->extract()) {
    confess "Could not extract '$distro'";
  }

  # save name of debian build directory created by extraction
  my $deb_build_dir_name = ($self->dir_list($deb_parent_dir))[0];
  my $deb_build_dir = $self->dir_join($deb_parent_dir, $deb_build_dir_name);
  if (not -d $deb_build_dir) {
    confess 'Could not find debian build directory';
  }
  $self->_deb_build_dir_path($deb_build_dir);

  # save name of distribution filename
  $self->_qkpath($distro, 'distro');   ## no critic (ProhibitDuplicateLiteral)

  return;
}

# _initial_debianisation($distro_filename)    {{{1
#
# does:   run dh_make
#         set debian build directory attribute
# params: nil
# prints: feedback
# return: n/a, die on failure
sub _initial_debianisation ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $distro_filename = $self->_distribution_filepath->name;
  if (not $distro_filename) { confess 'No filename provided'; }
  my $email         = $self->_email;
  my $deb_build_dir = $self->_deb_build_dir;
  my $cmd           = [
    'dh_make', '--yes',  '--single', '--email',
    ${email},  '--file', "../${distro_filename}",
  ];
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $deb_build_dir;
  $self->shell_command($cmd, { silent => $FALSE, fatal => $TRUE });

  return;
}

# _configure_debian_subdir()    {{{1
#
# does:   delete unneeded files, add rules, write debian files
# params: nil
# prints: feedback
# return: n/a, die on failure
sub _configure_debian_subdir ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # get debian subdirectory
  my $deb_build_dir = $self->_deb_build_dir;
  my $debianise_dir = $self->dir_join($deb_build_dir, 'debian');
  if (not -d $debianise_dir) {
    confess 'Cannot find debian subdirectory';
  }
  $self->_debianise_dir_path($debianise_dir);

  # delete all but 'dirs' and 'rules'
  my %is_keep_file        = map { ($_ => 1) } qw(dirs rules);
  my @debianise_dir_files = $self->file_list($debianise_dir);
  my @debianise_dir_dirs  = $self->dir_list($debianise_dir);
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $debianise_dir;
  foreach my $file (@debianise_dir_files) {
    if (not $is_keep_file{$file}) {
      unlink $file or confess "Unable to delete '$file'";
    }
  }
  foreach my $dir (@debianise_dir_dirs) {
    $self->path_remove($dir) or confess "Unable to delete '$dir'";
  }

  # amend rules file
  $self->_amend_debian_rules();

  # write debianise files
  $self->_write_debian_files();

  return;
}

# _amend_debian_rules()    {{{1
#
# does:   make changes to debian rules file
# params: nil
# prints: nil
# return: n/a, die on failure
sub _amend_debian_rules ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # reused variables
  my ($fh, @new_rule);

  # get debian subdirectory
  my $debianise_dir = $self->_debianise_dir;
  my $rules_fp      = $self->file_cat_dir('rules', $debianise_dir);
  if (not -e $rules_fp) { confess 'Cannot find rules file'; }

  # read in default rules file
  my $rules_ref = $self->file_read($rules_fp);
  my @rules     = @{$rules_ref};

  # remove empty lines at end of file
  while (1) {
    my $last_line    = $rules[-1];
    my $next_to_last = $rules[-2];    ## no critic (ProhibitMagicNumbers)
    last if (not(not $last_line and not $next_to_last));
    pop @rules;
  }

  # add bash completion if necessary
  if ($self->_bashcomp) {
    foreach my $line (@rules) {
      if ($line =~ /^\s*dh\s+/xsm) {
        $line .= ' --with bash-completion';
      }
    }
  }

  # new rule: set sharedstatedir
  ## no critic (ProhibitHardTabs)
  @new_rule = (
    q{# Make directory variable sharedstatedir debian compliant},
    q{override_dh_auto_configure:},
    q{	dh_auto_configure -- --sharedstatedir=/var/lib},
    $EMPTY_STRING,
  );
  ## use critic
  push @rules, @new_rule;

  # new rule: do not sign package
  @new_rule = (
    q{# Suppress digital signing of package},
    q{override_dh_md5sums:}, $EMPTY_STRING,
  );
  push @rules, @new_rule;

  # new rule: prevent stripping of information from files
  @new_rule = (
    q{# Suppress stripping of information from files},
    q{override_dh_strip_nondeterminism:},
    $EMPTY_STRING,
  );
  push @rules, @new_rule;

  # write back amended file
  $self->file_write([@rules], $rules_fp);

  return;
}

# _write_debconf_file()    {{{1
#
# does:   write debconf file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_debconf_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need templates file to proceed
  if (not $self->_debconf) { return; }
  my $debconf = $self->_debconf->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $debconf_fp    = $self->file_cat_dir($debconf, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.config";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($debconf_fp, $deb_fp)
      or confess "Unable to copy '$debconf'";

  return;
}

# _write_debian_files()    {{{1
#
# does: write build files to denianise directory
# params: nil
# prints: nil
# return: n/a
sub _write_debian_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  $self->_write_control_file();
  $self->_write_deb_changelog_file();
  $self->_write_debconf_file();
  $self->_write_templates_file();
  $self->_write_pre_install_file();
  $self->_write_post_install_file();
  $self->_write_pre_remove_file();
  $self->_write_post_remove_file();
  $self->_write_bash_completion_file();
  $self->_write_install_file();
  $self->_write_copyright_file();

  #$self->_write_docs_file();

  return;
}

# _write_control_file()    {{{1
#
# does:   write debian control file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_control_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $compat    = $self->debhelper_compat;
  my $name      = $self->_name;
  my $author    = $self->_primary_author;
  my $email     = $self->_email;
  my $standards = $self->debian_standards_version;
  my $summary   = $self->_summary;
  my @depends;

  for my $type ('shlibs', 'misc', 'perl') {
    ## no critic (RequireInterpolationOfMetachars)
    push @depends, q[${] . $type . q[:Depends}];    # ${XXXX:Depends}
    ## use critic
  }
  push @depends, $self->_depends;
  my @descriptions_raw = $self->_description;

  foreach my $description (@descriptions_raw) {
    if (length $description == 0) { $description = q{.}; }
  }
  my @descriptions  = map {" $_"} @descriptions_raw;  # prepend space
  my $last_depend   = pop @depends;                   # so do not append comma
  my $deb_dir       = $self->_debianise_dir;
  my $deb_file_name = 'control';
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);
  my @c;

  # create content
  push @c, (
    qq[Source: $name],
    q[Section: utils],
    q[Priority: optional],
    qq[Maintainer: $author <$email>],
    q[Build-Depends: ],
    qq[ debhelper-compat (= $compat), ],
    q[ autotools-dev],
    qq[Standards-Version: $standards,],

    q[],
    qq[Package: $name],
    q[Architecture: all],
    q[Depends: ],
  );
  foreach my $depend (@depends) {
    push @c, " $depend,";
  }
  push @c, (" $last_depend", qq[Description: $summary]);
  foreach my $description (@descriptions) {
    push @c, $description;
  }

  # write file
  $self->file_write([@c], $deb_fp);

  return;
}

# _write_deb_changelog_file()    {{{1
#
# does:   write debian changelog file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_deb_changelog_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $deb_dir = $self->_debianise_dir;
  my $file    = $self->file_cat_dir('changelog', $deb_dir);
  my $name    = $self->_name;
  my $version = $self->_version->as_string();
  my $email   = $self->_email;
  my $author  = $self->_primary_author;
  my $date    = $self->date_email();
  my @c;

  # create output
  push @c,
      (
    qq{$name ($version-1) UNRELEASED; urgency=low},
    $EMPTY_STRING,
    q{  * Local package},
    q{  * Closes: #500099)},
    q{  * Automatically packaged by dn-qk-deb},
    $EMPTY_STRING,
    qq{ -- $author <$email>  $date},
      );

  # write file
  $self->file_write([@c], $file);

  return;
}

# _write_templates_file()    {{{1
#
# does:   write debian templates file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_templates_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need templates file to proceed
  if (not $self->_templates) { return; }
  my $templates = $self->_templates->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $templates_fp  = $self->file_cat_dir($templates, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.templates";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($templates_fp, $deb_fp)
      or confess "Unable to copy '$templates'";

  return;
}

# _write_pre_install_file()    {{{1
#
# does:   write debian preinst file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_pre_install_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need preinstall file to proceed
  if (not $self->_preinst) { return; }
  my $preinst = $self->_preinst->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $preinst_fp    = $self->file_cat_dir($preinst, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.preinst";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($preinst_fp, $deb_fp)
      or confess "Unable to copy '$preinst'";

  return;
}

# _write_post_install_file()    {{{1
#
# does:   write debian postinst  file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_post_install_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need postinstall file to proceed
  if (not $self->_postinst) { return; }
  my $postinst = $self->_postinst->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $postinst_fp   = $self->file_cat_dir($postinst, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.postinst";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($postinst_fp, $deb_fp)
      or confess "Unable to copy '$postinst'";

  return;
}

# _write_pre_remove_file()    {{{1
#
# does:   write debian prerm file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_pre_remove_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need preremoval file to proceed
  if (not $self->_prerm) { return; }
  my $prerm = $self->_prerm->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $prerm_fp      = $self->file_cat_dir($prerm, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.prerm";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($prerm_fp, $deb_fp)
      or confess "Unable to copy '$prerm'";

  return;
}

# _write_post_remove_file()    {{{1
#
# does:   write debian postrm file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_post_remove_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need postremoval file to proceed
  if (not $self->_postrm) { return; }
  my $postrm = $self->_postrm->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $postrm_fp     = $self->file_cat_dir($postrm, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.postrm";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($postrm_fp, $deb_fp)
      or confess "Unable to copy '$postrm'";

  return;
}

# _write_bash_completion_file()    {{{1
#
# does:   write debian bash completion file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_bash_completion_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need bash completion file to proceed
  if (not $self->_bashcomp) { return; }
  my $bashcomp = $self->_bashcomp->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $bashcomp_fp   = $self->file_cat_dir($bashcomp, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.bash-completion";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($bashcomp_fp, $deb_fp)
      or confess "Unable to copy '$bashcomp'";

  return;
}

# _write_install_file()    {{{1
#
# does:   write debian install file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_install_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need install file to proceed
  if (not $self->_install) { return; }
  my $install = $self->_install->name() . $DOT_IN;

  # set vars
  my $build_dir     = $self->_build_dir;
  my $install_fp    = $self->file_cat_dir($install, $build_dir);
  my $deb_dir       = $self->_debianise_dir;
  my $name          = $self->_name;
  my $deb_file_name = "$name.install";
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);

  # copy file
  $self->path_copy($install_fp, $deb_fp)
      or confess "Unable to copy '$install'";

  return;
}

# _write_copyright_file()    {{{1
#
# does:   write debian copyright file
# params: nil
# prints: nil
# return: boolean, dies on failure
sub _write_copyright_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $name          = $self->_name;
  my $author        = $self->_primary_author;
  my $email         = $self->_email;
  my $year          = $self->_copyright;
  my $date          = $self->date_email();
  my $deb_dir       = $self->_debianise_dir;
  my $deb_file_name = 'copyright';
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);
  my @c;

  # create content
  ## no critic (ProhibitDuplicateLiteral)
  push @c,
      (
    q{Format: http://www.debian.org/doc/}
        . q{packaging-manuals/copyright-format/1.0/},
    qq{Upstream-Name: $name},
    $EMPTY_STRING,
    q{Files: *},
    qq{Copyright: $year, $author <$email>},
    q{License: GPL-2+ or LGPL-2.1+ or Artistic},
    $EMPTY_STRING,
    q{License: Artistic},
    q{ This program is free software; you can redistribute it},
    q{ and/or modify it under the terms of the Artistic License,},
    q{ which comes with Perl.},
    $SPACE_DOT,
    q{ On Debian systems, the complete text of the Artistic},
    q{ License can be found in the file},
    q{ `/usr/share/common-licenses/Artistic'.},
    $EMPTY_STRING,
    q{License: GPL-2},
    q{ This library is free software; you can redistribute it},
    q{ and/or modify it under the terms of the GNU General Public},
    q{ License as published by the Free Software Foundation; either},
    q{ version 2 of the License, or (at your option) any later},
    q{ version.},
    $SPACE_DOT,
    q{ This library is distributed in the hope that it will be},
    q{ useful, but WITHOUT ANY WARRANTY; without even the implied},
    q{ warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR},
    q{ PURPOSE. See the GNU Lesser General Public License for more},
    q{ details.},
    $SPACE_DOT,
    q{ You should have received a copy of the GNU General Public},
    q{ License along with this library; if not, write to the Free},
    q{ Software Foundation, Inc., 51 Franklin Street, Fifth Floor,},
    q{ Boston, MA 02110-1301 USA.},
    $SPACE_DOT,
    q{ On Debian systems, the full text of the GNU General Public},
    q{ License version 2 can be found in the file},
    q{ `/usr/share/common-licenses/GPL-2'.},
    $EMPTY_STRING,
    q{License: LGPL-2.1},
    q{ This library is free software; you can redistribute it},
    q{ and/or modify it under the terms of the GNU Lesser General},
    q{ Public License as published by the Free Software Foundation;},
    q{ either version 2.1 of the License, or (at your option) any},
    q{ later version.},
    $SPACE_DOT,
    q{ This library is distributed in the hope that it will be},
    q{ useful, but WITHOUT ANY WARRANTY; without even the implied},
    q{ warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR},
    q{ PURPOSE. See the GNU Lesser General Public License for more},
    q{ details.},
    $SPACE_DOT,
    q{ You should have received a copy of the GNU Lesser General},
    q{ Public License along with this library; if not, write to},
    q{ the Free Software Foundation, Inc., 51 Franklin Street,},
    q{ Fifth Floor, Boston, MA 02110-1301 USA.},
    $SPACE_DOT,
    q{ On Debian systems, the full text of the GNU Lesser General},
    q{ Public License version 2.1 can be found in the file},
    q{ `/usr/share/common-licenses/LGPL-2.1'.},
      );
  ## use critic

  # write file
  $self->file_write([@c], $deb_fp);

  return;
}

# _write_docs_file()    {{{1
#
# does:   write debian docs file
# params: nil
# prints: nil
# return: boolean, dies on failure
# note:   currently unused but keep legacy subroutine
sub _write_docs_file ($self)
{ ## no critic (RequireInterpolationOfMetachars ProhibitUnusedPrivateSubroutines)

  #set vars
  my $deb_dir       = $self->_debianise_dir;
  my $deb_file_name = 'docs';
  my $deb_fp        = $self->file_cat_dir($deb_file_name, $deb_dir);
  my @c;

  # create content
  push @c, qw(NEWS README AUTHORS);

  # write file
  $self->file_write([@c], $deb_fp);

  return;
}

# _build_package()    {{{1
#
# does:   build package and copy to project dir
# params: nil
# prints: feedback
# return: n/a, die on failure
sub _build_package ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # build package
  my $deb_build_dir = $self->_deb_build_dir;
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $deb_build_dir;
  my $cmd = [ 'dpkg-buildpackage', '-rfakeroot', '-us', '-uc' ];
  $self->shell_command($cmd, { silent => $FALSE, fatal => $TRUE });

  # copy package files to project directory
  # - at times dpkg-buildpackage has not generated .diff.gz files
  my $project_dir = $self->_project_dir;
  my @patterns    = ([ $RE_DEB, $TRUE ]);
  if (not $self->deb_only) {
    push @patterns, [ $RE_DSC,         $TRUE ];
    push @patterns, [ $RE_ORIG_TAR_GZ, $TRUE ];
    push @patterns, [ $RE_DIFF_GZ,     $FALSE ];
  }
  my $deb_parent_dir = $self->_deb_parent_dir;
  $File::chdir::CWD = $deb_parent_dir;
  foreach my $ext (@patterns) {
    my ($pattern, $required) = @{$ext};
    my @matches = $self->file_list($deb_parent_dir, $pattern);
    my $count   = @matches;
    if ($count > 1) {
      confess "Multiple '$pattern' files generated";
    }
    if ($required and $count == 0) {
      confess "Did not generate '$pattern' file";
    }
    foreach my $match (@matches) {
      $self->path_copy($match, $project_dir)
          or confess "Unable to copy '$match'";
    }
  }
  return;
}

# _install_deb()    {{{1
#
# does:   install generated debian package file
# params: nil
# prints: feedback
# return: boolean, but dies on failure
sub _install_deb ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  my $project_dir = $self->_project_dir;

  # check for package
  my @debs  = $self->file_list($project_dir, $RE_DEB);
  my $found = @debs;
  if ($found == 0) { confess "No debs found in '$project_dir'"; }
  if ($found > 1) {
    confess "Multiple debs found in '$project_dir'";
  }

  # install
  my $deb = $debs[0];
  return $self->debian_install_deb($deb);
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::QkDeb - quick and dirty debianisation of files

=head1 VERSION

This is documentation for App::Dn::QkDeb version 0.8.

=head1 SYNOPSIS

    use App::Dn::QkDeb;

    App::Dn::QkDeb->new_with_options->run;

=head1 DESCRIPTION

This script takes files and packages them into a deb. It will package script,
manpage, data, icon, desktop and configuration files. Only script and manpage
files are required. (Note: a manpage file is not required for a perl script --
the manpage file is generated from perlscript pod.)

By default all the package files created by the build process will be saved:
F<deb>, S<< F<diff.gz> >>, F<dsc> and S<< F<orig.tar.gz> >>. Neither source
package nor S<< F<.changes> >> file will be cryptographically signed. Use of
the '-d' option will result in only the F<deb> file being saved.

For a script library package the requirements for script and manpages files are
relaxed -- specify the library scripts as data files. They will be installed to
F<pkgdatadir>, e.g., on Debian systems S<< F</usr/share/foo/> >>.

A script may need to reference the package name and files in certain standard
directories. The following aututools-style variables will be converted at
build-time:

=over

=over

=item I<@>I<bin_dir>I<@>

Directory for user executables. Default value in built deb package: S<<
F</usr/bin> >>.

=item I<@>I<data_dir>I<@>

Directory for read-only architecture-independent data files. Default value in
built deb package: S<< F</usr/share> >>.

=item I<@>I<desktop_dir>I<@>

Directory for generic debian desktop files. Default value in built deb package:
S<< F</usr/share/applications> >>. Note desktop files are not put into
application subdirectory -- be careful of filename clashes.

=item I<@>I<icons_dir>I<@>

Directory for generic debian icons. Default value in built deb package: S<<
F</usr/share/icons> >>. Note icons are not put into application subdirectory --
be careful of filename clashes.

=item I<@>I<lib_dir>I<@>

Root directory for hierarchy of libraries. Default value in built deb package:
S<< F</usr/lib> >>.

=item I<@>I<libexec_dir>I<@>

Root directory for hierarchy of executables run by other executables, not
user. Default value in built deb package:
S<< F</usr/libexec> >>.

=item I<@>I<pkg>I<@>

Package name.

=item I<@>I<pkgconf_dir>I<@>

Directory for package configuration files. Default value in built deb package:
S<< F</etc/foo> >>.

=item I<@>I<pkgdata_dir>I<@>

Directory for package read-only architecture-independent data files. Default
value in built deb package: S<< F</usr/share/foo> >>.

=item I<@>I<pkglib_dir>I<@>

Directory for package executables run by other executables, not user, and
package libraries. Default value in built deb package:
S<< F</usr/lib> >>.

=item I<@>I<sbin_dir>I<@>

Directory for superuser executables. Default value in built deb package: S<<
F</usr/sbin> >>.

=item I<@>I<sysconf_dir>I<@>

Directory for system configuration files. Default value in built deb package:
S<< F</etc> >>.

=back

=back

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

A resources file in the build directory, called S<< F<deb-resources> >> by
default, provides details about the package to be built.

Each line of this file consists of a key-value pair. Only keys listed here will
be utilised. Any unrecognised key will halt processing. Some keys can be used
only once while others can be used multiple times.

Empty lines and comment lines (start with hash '#') will be ignored.

An annotated template resources file can be created by running this script with
the '-t' option.

What follows is a list of valid keys and descriptions of the values that can be
used with them.

=over

=over

=item I<author>

Author of script.

Required. Multiple allowed.

=item I<bash-completion>

Bash completion file. Results in build file
S<< F<source/PACKAGE.bash-completion> >>.

Optional. One only.

=item I<bin-file>

User scripts and binary executables to package.

Required. Multiple allowed.

=item I<conf-file>

Configuration files.

Optional. Multiple allowed.

=item I<control-description>

Description of script. This is a longer description than the one line summary
and can stretch over multiple lines. Each line can be no longer than 60
characters. Each line must be the value in a separate name-value pair.
Paragraphs can be separated by a line consisting of a single period ('.'). This
description will be included in the package F<control> file. This, in turn, is
displayed by many package managers.

Required. Multiple allowed.

[Note: Knowledgable users may know the F<control> file format requires all
descriptions lines be indented by one space. This space will be automatically
inserted when writing to the F<control> file and does not need to be included
in the S<< F<deb-resources> >> file.]

=item I<control-summary>

One line summary of script for inclusion in the package <F<control> file. This,
in turn, is displayed by many package managers.

Must be no longer than 60 characters.

Required. One only.

=item I<data-file>

Data files to package.

Optional. Multiple allowed.

=item I<debconf>

Debconf debian build file. In debian package is called
S<< F<PACKAGE.config> >>.

Optional. One only.

=item I<depends-on>

The name of a single package this package depends on. Can include minimum
version.

Optional. Multiple allowed.

=item I<desktop-file>

Desktop files to package.

Optional. Multiple allowed.

=item I<email>

Email address of package maintainer.

Required. One only.

=item I<extra-path>

Extra files and directories to be copied directly into the root of the
distribution. Directories are copied recursively. Used with key 'install-file'
to package files for arbitrary filesystem locations. See 'install-file' for an
example.

Optional. Multiple allowed.

=item I<icon-file>

Icon files to package.

Optional. Multiple allowed.

=item I<install-file>

Debian build install file. Results in build file S<< F<debian/PACKAGE.install>
>>. On debian systems try C<man dh_install> for more information on this file.

The install file can be used with the 'extra-path' key to install files to
arbitrary filesystem locations.

For example, assume the z-shell completion file is present in the build
directory as S<< F<contrib/completion/zsh/_my_script> >> and that it needs to
be installed into filesystems at S<< F</usr/share/zsh/vendor-completions/> >>.
First, ensure it is copied into the intermediary autotools distribution with
the following entry in the resources file:

    extra-path contrib

Next ensure it is packaged correctly by creating a file in the build directory
called, say, S<< F<my-install-file> >>, containing the following line:

    contrib/completion/zsh/_my_script /usr/share/zsh/vendor-completions

Finally, add the following entry to the resources file:

    install-file my-install-file

Optional. One only.

=item I<libdata-file>

Data file used by other programs.

Optional. Multiple allowed.

=item I<libexec-file>

Executable programs run by other programs.

Optional. Multiple allowed.

=item I<man-file>

Man pages files to package.

Required. Multiple allowed.

=item I<package-name>

Name of deb package to created. Usually the same as the primary script name.
Must not contain whitespace.

Required. One only.

=item I<preinstall>

Preinstall debian build file. In final package is called
S<< F<PACKAGE.preinst> >>.

Optional. One only.

=item I<prerm>

Preremove debian build file. In final package is called
S<< F<PACKAGE.prerm> >>.

Optional. One only.

=item I<postinstall>

Postinstall debian build file. In final package is called
S<< F<PACKAGE.postinst> >>.

Optional. One only.

=item I<postrm>

Postremove debian build file. In final package is called
S<< F<PACKAGE.postrm> >>.

Optional. One only.

=item I<sbin-file>

Superuser scripts and binary executables to package.

Required. Multiple allowed.

=item I<templates>

Templates debian build file. In final package is called
S<< F<PACKAGE.templates> >>.

Optional. One only.

=item I<version>

Version number for package. Remember to increment it when rebuilding your
package. If your new package has the same version as the previous (installed)
version your package manager will not like it. An ugly hack would be to keep
the same version but always remove the existing package before installing the
new... but it sure is ugly.

Required. One only.

=item I<year>

Year of copyright. Can be any year from 2000 to the current year.

Required. One only.

=back

=back

=head2 Environment variables

None used.

=head1 OPTIONS

=over

=item I<-d>

Produce a debian package (S<< F<.deb> >>) file only. Prevents creation of S<<
F<diff.gz> >>, F<dsc> and S<< F<orig.tar.gz> >> package files.

Optional. Default: produce all package creation files.

=item I<-f>

Show feedback from autotools commands. The default behaviour is to suppress
this feedback.

Optional. Default: false.

=item I<-i>

Turn all errors arising from the contents of the resources file into warnings.
That is, these errors will not halt package creation.  Warning: use this option
with caution!

Optional. Default: false.

=item I<-k>

Keep the package's current version number. The user is not given an opportunity
to enter a new version number.

Optional. Default: false.

=item I<-l>

Indicates the package is a library (specifically, executable scripts called by
other scripts). Unlike "standard" packages, script and manpages files are not
required while library script(s) are.

Optional. Default: false.

=item I<-m>

Prevent creation of manpage from main script pod, which normally occurs when
there is a single script file that is perl script, and a single manpage file.

=item I<-n>

Do not install built debian package.

=item I<-t>

Create template resources file in the current directory. Will also create a
simple git ignore file if one does not already exist.

Optional. Default: false.

=item I<-h>

Display help and exit.

=back

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It performs the package build.

=head1 DIAGNOSTICS

=head2 Unrecognised keyword 'WORD' at line number

Occurs when an unrecognised keyword is encountered in the
S<< F<deb-resources> >> file.

=head2 Invalid path type '$type'

This is an internal script error. Contact the script author.

=head2 Copy failed: ERROR
=head2 Unable to copy 'FILE'

Occurs when a system error prevents a file copy operation.

=head2 Error processing extra path 'PATH'

An extra path is neither a file nor a directory.

=head2 Unable to delete 'FILE/DIR'

A file or directory deletion operation failed.

=head2 No distro file
=head2 Multiple distro files
=head2 Failed to copy 'DISTRO_FILE' to deb parent dir
=head2 Cannot find distro in deb parent directory
=head2 Unable to parse 'DISTRO_FILE'
=head2 Could not extract 'DISTRO_FILE'

These errors can occur during processing of an intermediary distribution file.

=head2 Could not find debian build directory
=head2 No filename provided
=head2 Cannot find debian subdirectory
=head2 Cannot find rules file

This are errors of debianisation.

=head2 Multiple 'PATTERN' files generated
=head2 Did not generate 'PATTERN' file
=head2 Unable to copy 'FILE'

Errors that can occur when moving package files to the project directory.

=head2 No debs found in 'PROJECT_DIR'
=head2 Multiple debs found in 'PROJECT_DIR'

Errors that can occur during installation of the built debian package.

=head2 Unable to delete existing resource file

Occurs when a deletion operation on an existing S<< F<deb-resources> >> file
fails.

=head2 Cannot build package without version number
=head2 Invalid version
=head2 New version cannot be lower than current version

Errors that can occur when the user is prompted to enter a new version number.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

App::Dn::QkDeb::File, App::Dn::QkDeb::Path, Archive::Tar, autodie, Carp,
Const::Fast, Dpkg::Version, English, File::chdir, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, Pod::Man, strictures, Types::Dn::Debian,
Types::Dn, Types::Path::Tiny, Types::Standard, version.

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer E<lt>david@nebauer.orgE<gt>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
