#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.68])
AC_INIT([Podcast tools],
        [1.0],
        [david@nebauer.org],
        [dn-podcasts-rss],
)
AM_INIT_AUTOMAKE

# Checks for programs.
AC_PATH_PROG(myperl, perl)
test -z "${myperl}" && AC_MSG_ERROR([Perl is required])

# Checks for libraries.

# Checks for perl modules.
DN_PERL_MODULE([XML::Dumper],[0.81])
DN_PERL_MODULE([XML::RSS],[1.49])
DN_PERL_MODULE([XML::OPML],[0.26])
DN_PERL_MODULE([Dn::PodcastsRss],[1.00])

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

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

# stored_state
# - name of file storing current state of object
# - default value in built deb package: ${PACKAGE}-STORE-state.xml
stored_state="${PACKAGE}-STORE-state.xml"
AC_SUBST(stored_state)

# initial_state
# - name of file storing initial (default) state of object
# - default value in built deb package: ${PACKAGE}-STORE-initial.xml
initial_state="${PACKAGE}-STORE-initial.xml"
AC_SUBST(initial_state)


# Output
AC_CONFIG_FILES([
	Makefile
	dn-podcasts-rss
	dn-podcasts-rss.1
	dn-podcasts-rssrc
	dn-podcasts-rss-STORE-initial.xml
])
AC_OUTPUT
