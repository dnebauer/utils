#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.71])
AC_INIT([Regenerate local mc configuration files],
        [1.4],
        [david@nebauer.org],
        [dn-mc-conf],
)
AM_INIT_AUTOMAKE([foreign])

# Checks for programs.
# - mc
AC_PATH_PROG(mymc, mc)
test -z "${mymc}" && AC_MSG_ERROR([mc not installed])
# - geeqie
AC_PATH_PROG(mygeeqie, geeqie)
test -z "${mygeeqie}" && AC_MSG_ERROR([geeqie not installed])
# - smplayer
AC_PATH_PROG(mysmplayer, smplayer)
test -z "${mysmplayer}" && AC_MSG_ERROR([smplayer not installed])
# - planner
AC_PATH_PROG(myplanner, planner)
test -z "${myplanner}" && AC_MSG_ERROR([planner not installed])
# - fbreader
AC_PATH_PROG(myfbreader, fbreader)
test -z "${myfbreader}" && AC_MSG_ERROR([fbreader not installed])
# - gramps
AC_PATH_PROG(mygramps, gramps)
test -z "${mygramps}" && AC_MSG_ERROR([gramps not installed])
# - tellico
AC_PATH_PROG(mytellico, tellico)
test -z "${mytellico}" && AC_MSG_ERROR([tellico not installed])
# - makensis
AC_PATH_PROG(mymakensis, makensis)
test -z "${mymakensis}" && AC_MSG_ERROR([makensis not installed - package is nsis])
## - dn-build-repository
#AC_PATH_PROG(mydn_build_repository, dn-build-repository)
#test -z "${mydn_build_repository}" && AC_MSG_ERROR([dn-build-repository not installed])
# - 7z
AC_PATH_PROG(my7z, 7z)
test -z "${my7z}" && AC_MSG_ERROR([7z (p7zip) not installed])

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

# pkglibexec_dir
# - package executables run by other executables, not user,
#   and package libraries
# - default value in built deb package: /usr/libexec/${PACKAGE}
#   but occasionally overridden to /libexec/${PACKAGE}
#   in important packages, e.g., udev
pkglibexec_dir="${prefix}/libexec/${PACKAGE}"
AC_SUBST(pkglibexec_dir)

# mclib_dir
# - mc (midnight commander) package executables run by other
#   executables, not user, and package libraries
# - default value in built deb package: /usr/lib/mc
mclib_dir="${prefix}/lib/mc"
AC_SUBST(mclib_dir)

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

# Output
AC_CONFIG_FILES([
    Makefile
    dn-mc-conf
    dn-mc-conf.1
    dn-mc-conf-error.png
    dn-urar
    mc.ext
    menu
    neomutt_my-attach-wrapper
])
AC_OUTPUT
