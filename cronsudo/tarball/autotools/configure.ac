#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.71])
AC_INIT([Cron tasks and sudoers files],
        [2.3],
        [david@nebauer.org],
        [dn-cronsudo],
)
AM_INIT_AUTOMAKE([foreign])

# Checks for programs.
# - get_iplayer
AC_PATH_PROG(myget_iplayer, get_iplayer)
test -z "${myget_iplayer}" && AC_MSG_ERROR([get_iplayer not installed])
# no longer test for rdate as it is in /sbin and not founf when build as user
## - rdate
#AC_PATH_PROG(myrdate, rdate)
#test -z "${myrdate}" && AC_MSG_ERROR([rdate not installed])
# - logger
AC_PATH_PROG(mylogger, logger)
test -z "${mylogger}" && AC_MSG_ERROR([logger not installed])
# - updatedb
AC_PATH_PROG(myupdatedb, updatedb)
test -z "${myupdatedb}" && AC_MSG_ERROR([updatedb not installed])
# - logrotate
#   . can't check because logrotate is a superuser program
#AC_PATH_PROG(mylogrotate, logrotate)
#test -z "${mylogrotate}" && AC_MSG_ERROR([logrotate not installed])
# - vim
AC_PATH_PROG(myvim, vim)
test -z "${myvim}" && AC_MSG_ERROR([vim not installed])
# - mount
AC_PATH_PROG(mymount, mount)
test -z "${mymount}" && AC_MSG_ERROR([mount not installed])

# Variable substitution

# pkg
# - package name
pkg="${PACKAGE}"
AC_SUBST(pkg)

# bin_dir
# - user executables
# - default value in built deb package: /usr/bin
bin_dir="${prefix}/bin"
AC_SUBST(bin_dir)

# sbin
# - superuser executables
# - default value in built deb package: /usr/sbin
sbin_dir="${prefix}/sbin"
AC_SUBST(sbin_dir)

# data_dir
# - read-only architecture-independent data files
# - default value in built deb package: /usr/share
data_dir="${prefix}/share"
AC_SUBST(data_dir)

# pkgdata_dir
# - package read-only architecture-independent data files
# - default value in built deb package: /usr/share/${PACKAGE}
pkgdata_dir="${prefix}/share/${PACKAGE}"
AC_SUBST(pkgdata_dir)

# lib_dir
# - root for hierarchy of (a) executables run by other
#   executables, not user, and (b) libraries
# - default value in built deb package: /usr/lib
#   but occasionally overridden to /lib in important packages, e.g., udev
lib_dir="${prefix}/lib"
AC_SUBST(lib_dir)

# pkglib_dir
# - package executables run by other executables, not user,
#   and package libraries
# - default value in built deb package: /usr/lib/${PACKAGE}
#   but occasionally overridden to /lib/${PACKAGE}
#   in important packages, e.g., udev
pkglib_dir="${prefix}/lib/${PACKAGE}"
AC_SUBST(pkglib_dir)

# localstate_dir
# - arch-independent data files modified while running
# - default value in built deb package: /var
localstate_dir="${localstatedir}"
AC_SUBST(localstate_dir)

# sharedstate_dir
# - machine-specific data files modified while running
# - default value in built deb package: /usr/com
#   but this is not a valid debian directory so commonly overriden to
#   /var/lib in debian rules file
sharedstate_dir="${sharedstatedir}"
AC_SUBST(sharedstate_dir)

# pkgvar_dir
# - package-specific data files modified while running
# - default value in built deb package: /var/lib/${PACKAGE}
pkgvar_dir="${localstatedir}/lib/${PACKAGE}"
AC_SUBST(pkgvar_dir)

# sysconf_dir
# - system configuration files
# - default value in built deb package: /etc
sysconf_dir="${sysconfdir}"
AC_SUBST(sysconf_dir)

# pkgconf_dir
# - package configuration files
# - default value in built deb package: /etc/${PACKAGE}
pkgconf_dir="${sysconfdir}/${PACKAGE}"
AC_SUBST(pkgconf_dir)

# pkgdoc_dir
# - package documentation
# - default value in built deb package: /usr/share/doc/${PACKAGE}
pkgdoc_dir="${prefix}/share/doc/${PACKAGE}"
AC_SUBST(pkgdoc_dir)

# man_dir
# - manpage files
# - default value in built deb package: /usr/share/man
man_dir="${prefix}/share/man"
AC_SUBST(man_dir)

# Ouptut
AC_CONFIG_FILES([
    Makefile
    dn-cronsudo.1
    dn-edit.sudoers
    dn-filesys.sudoers
    dn-logging.sudoers
    dn-network.sudoers
    dn-pkg-manage.sudoers
    dn-wireless.sudoers
])
AC_OUTPUT
