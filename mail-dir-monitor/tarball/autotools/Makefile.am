# Makefile.am for package: mail-dir-monitor

# Since the multi-architecture implementation in late 2013
# the layout of /lib and /usr/lib has changed -- in each case
# an architecture specific subdirectory is added
# The name of this subdirectory is often referred to as the
# 'triplet' or 'arch-triplet'
# The triplet value can be obtained manually using:
#       dpkg-architecture -qDEB_HOST_MULTIARCH
# Note: It is not clear what directories and variables are
#       to be used for architecture-independent data
#       under multiarch

# According to the automake manual (for version 1.14):
# "Scripts can be installed in bindir, sbindir, libexecdir,
#  pkglibexecdir, or pkgdatadir." (9.1: Executable scripts)
# "Automake supports the installation of miscellaneous data
#  files using the DATA family of variables. Such data can be
#  installed in the directories datadir, sysconfdir,
#  sharedstatedir, localstatedir, or pkgdatadir."
#  (9.3: Architecture-independent data files)

# Here are some useful GNU directory variables,
# their default values after deb packaging, and
# the primaries they can be used with:
#   bindir         = /usr/bin                       SCRIPTS
#   sbindir        = /usr/sbin                      SCRIPTS
#   pkgdatadir     = /usr/share/$(PACKAGE)          SCRIPTS DATA
#   libexecdir     = /usr/lib/<triplet>             SCRIPTS
#   pkglibexecdir  = /usr/lib/<triplet>/$(PACKAGE)  SCRIPTS
#   datadir        = /usr/share                     DATA
#   localstatedir  = /var                           DATA
#   sharedstatedir = /usr/com                       DATA
#   sysconfdir     = /etc                           DATA
#   mandir         = /usr/share/man/manX            MANS
# 
# 'libdir' is not included -- it cannot be used for
# SCRIPTS or DATA
#
# 'sharedstatedir' defaults to /usr/com which is not used
# by debian -- override to /var/lib which can be done by
# adding the following rule to the defaut debian rules
# file:
# 	override_dh_auto_configure:
#		dh_auto_configure -- --sharedstatedir=/var/lib
#
# Now we define some additional useful directory variables
# apparently overlooked by GNU, their default values after
# deb packaging, and the primaries they are commonly used
# with:
#   pkgconfdir     = /etc/$(PACKAGE)            DATA
#   pkgdocdir      = /usr/share/doc/$(PACKAGE)  DATA
#   pkgvardoc      = /var/lib/$(PACKAGE)        DATA
pkglibdir = ${prefix}/lib/x86_64-linux-gnu/$(PACKAGE)
pkgconfdir = /etc/$(PACKAGE)
pkgdocdir = ${prefix}/share/doc/${PACKAGE_TARNAME}
pkgvardir = /var/lib/$(PACKAGE)
#
# Some other useful variables are:
#   prefix         = /usr
#   docdir         = /usr/share/doc/$(PACKAGE)


# Now let us assign some install locations
# [comment out unused directory targets or they
#  will be added, empty, to the deb package]

# Scripts
# -------

# User-executable scripts generally go in /usr/bin
##bin_SCRIPTS = 

# Superuser-only scripts live in /usr/sbin
sbin_SCRIPTS = mail-dir-monitor mail-dir-launcher

# Scripts run by other scripts, including libraries,
# go in /usr/lib/<triplet>/$(PACKAGE)
##pkglibexec_SCRIPTS = 

# Packaging tools will let you put scripts in
# /usr/share/$(PACKAGE) but this seems a very bad idea --
# according to the FHS </usr/share/doc/debian-policy/fhs/>
# this directory is intended for read-only architecture-
# independent data files
##pkgdata_SCRIPTS = 


# Data
# ----

# The root directory for read-only architecture-independent
# data files is /usr/share, but you should never use this
# directory -- use a package subdirectory instead
##data_DATA = 

# You put read-only architecture-independent data files
# for the package in /usr/share/$(PACKAGE)
#pkgdata_DATA = icon-error.xpm icon-info.xpm icon-question.xpm icon-warn.xpm

# Architecture-dependent data exclusively used by an 
# application can be placed in /usr/lib/<triplet>/$(PACKAGE)
# (as can libraries and executables -- see
# pkglibexec_SCRIPTS above)
##pkglibexec_DATA = 


# Configuration
# -------------

# The system wide configuration directory is /etc and a
# single configuration file can be put here
##sysconf_DATA = 

# A package's config files can be put in their own
# subdirectory: /etc/$(PACKAGE)
# ** defined in this Makefile, not by autoconf **
##pkgconf_DATA = 

# Note that some applications store their rules files
# under /lib/$(PACKAGE), such as udev which stores them in
# /lib/udev/rules.d -- in such cases it may be necessary
# to override libdir to /lib


# Documentation
# -------------

# Package documentation is stored under
# /usr/share/doc/$(PACKAGE)
# ** defined in this Makefile, not by autoconf **
##pkgdoc_DATA = 

# Man files are stored in the hierarchy under
# /usr/share/man
man_MANS = mail-dir-monitor.1 mail-dir-launcher.1


# Variable data
# -------------

# Machine-specific data files modified while running go in
# the /var hierarchy
##localstate_DATA = 

# Architecture-independent data files modified while
# running go in the directory designated by the variable
# sharedstatedir which defaults to /usr/com -- this is not
# a valid debian directory so override it to /var/lib
# (see notes at top on directory variables)
##sharedstate_DATA = 

# Package-specific data files modified while running do in
# /var/lib/$(PACKAGE)
# ** defined in this Makefile, not by autoconf **
##pkgvar_DATA = 


# References
# ----------
# GNU Coding Standards 7.2.5 (Variables for Installation Directories)
# - package <gnu-standards>
# - file </usr/share/doc/gnu-standards/standards.html#Directory-Variables>
# - also listed in package <autoconf-doc> which is based on package <gnu-standards>
# - file </usr/share/doc/autoconf-doc/autoconf.html#Installation-Directory-Variables>
# - note that GNU CS and FHS use different concepts and at points
#   conflict with each other
# Filesystem Hierarchy Standard
# - package <debian-policy>
# - at </usr/share/doc/debian-policy/fhs/>
# - note that GNU CS and FHS use different concepts and at points
#   conflict with each other
# Autobook 14.1 (Where files are installed)
# - online at <http://www.sourceware.org/autobook/>
# - WARNING: when checked on 2013-11-23 this book had not been updated
#            since 2006-02-08
# - WARNING: is becoming obsolete, e.g, does not include 'pkglibexecdir' 
#            as a possible script directory variable
# - file </usr/share/doc/autobook/html/>

