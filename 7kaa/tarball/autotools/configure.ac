#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.67])
AC_INIT([Seven Kingdoms: Ancient Adversaries], [1.0], [david@nebauer.org], [dn-7kaa])
AM_INIT_AUTOMAKE

# Checks for programs.

# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

# Variable substitution
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

# sysgame_dir
# - game files
# - default value in built deb package: /usr/games
sysgame_dir="${prefix}/games"
AC_SUBST(sysgame_dir)

# pkggame_dir
# - package game files
# - default value in built deb package: /usr/games/${PACKAGE}
pkggame_dir="${prefix}/games/${PACKAGE}"
AC_SUBST(pkggame_dir)

# output files
AC_CONFIG_FILES([
	Makefile
	bin/Makefile
	docs/Makefile
	encyc/Makefile  encyc/firm/Makefile    encyc/god/Makefile
					encyc/monster/Makefile encyc/seat/Makefile
					encyc/unit/Makefile
	encyc2/Makefile encyc2/god/Makefile    encyc2/seat/Makefile
					encyc2/unit/Makefile
	image/Makefile
	misc/Makefile
	music/Makefile
	resource/Makefile
	scenario/Makefile
	scenari2/Makefile
	sound/Makefile
	sprite/Makefile
	tutorial/Makefile

	bin/7kaa
	bin/7kaa.1
	bin/7kaa-dn
	bin/7kaa-dn.1

	docs/seven-kingdoms-manual.pdf
	
	encyc/firm/factory.col
	encyc/firm/factory.icn
	encyc/firm/fort.col
	encyc/firm/fort.icn
	encyc/firm/harbor.col
	encyc/firm/harbor.icn
	encyc/firm/inn.col
	encyc/firm/inn.icn
	encyc/firm/market.col
	encyc/firm/market.icn
	encyc/firm/mine.col
	encyc/firm/mine.icn
	encyc/firm/science.col
	encyc/firm/science.icn
	encyc/firm/warfact.col
	encyc/firm/warfact.icn
	
	encyc/god/chinese.col
	encyc/god/chinese.icn
	encyc/god/greek.col
	encyc/god/greek.icn
	encyc/god/japanese.col
	encyc/god/japanese.icn
	encyc/god/maya.col
	encyc/god/maya.icn
	encyc/god/norman.col
	encyc/god/norman.icn
	encyc/god/persian.col
	encyc/god/persian.icn
	encyc/god/viking.col
	encyc/god/viking.icn
	
	encyc/monster/firekin.col
	encyc/monster/firekin.icn
	encyc/monster/giantet.col
	encyc/monster/giantet.icn
	encyc/monster/gith.col
	encyc/monster/gith.icn
	encyc/monster/gnoll.col
	encyc/monster/gnoll.icn
	encyc/monster/goblin.col
	encyc/monster/goblin.icn
	encyc/monster/gremjerm.col
	encyc/monster/gremjerm.icn
	encyc/monster/headless.col
	encyc/monster/headless.icn
	encyc/monster/hobglob.col
	encyc/monster/hobglob.icn
	encyc/monster/lizard.col
	encyc/monster/lizard.icn
	encyc/monster/lyw.col
	encyc/monster/lyw.icn
	encyc/monster/man.col
	encyc/monster/man.icn
	encyc/monster/rockman.col
	encyc/monster/rockman.icn
	encyc/monster/skeleton.col
	encyc/monster/skeleton.icn
	encyc/monster/struct_1.col
	encyc/monster/struct_1.icn
	encyc/monster/struct_2.col
	encyc/monster/struct_2.icn
	encyc/monster/struct_3.col
	encyc/monster/struct_3.icn
	encyc/monster/struct_4.col
	encyc/monster/struct_4.icn
	
	encyc/seat/chinese.col
	encyc/seat/chinese.icn
	encyc/seat/greek.col
	encyc/seat/greek.icn
	encyc/seat/japanese.col
	encyc/seat/japanese.icn
	encyc/seat/maya.col
	encyc/seat/maya.icn
	encyc/seat/norman.col
	encyc/seat/norman.icn
	encyc/seat/persian.col
	encyc/seat/persian.icn
	encyc/seat/viking.col
	encyc/seat/viking.icn
	
	encyc/unit/ballista.col
	encyc/unit/ballista.icn
	encyc/unit/cannon.col
	encyc/unit/cannon.icn
	encyc/unit/caravel.col
	encyc/unit/caravel.icn
	encyc/unit/catapult.col
	encyc/unit/catapult.icn
	encyc/unit/chinese.col
	encyc/unit/chinese.icn
	encyc/unit/expcart.col
	encyc/unit/expcart.icn
	encyc/unit/flamethr.col
	encyc/unit/flamethr.icn
	encyc/unit/galleon.col
	encyc/unit/galleon.icn
	encyc/unit/greek.col
	encyc/unit/greek.icn
	encyc/unit/japanese.col
	encyc/unit/japanese.icn
	encyc/unit/maya.col
	encyc/unit/maya.icn
	encyc/unit/norman.col
	encyc/unit/norman.icn
	encyc/unit/persian.col
	encyc/unit/persian.icn
	encyc/unit/transpor.col
	encyc/unit/transpor.icn
	encyc/unit/vessel.col
	encyc/unit/vessel.icn
	encyc/unit/viking.col
	encyc/unit/viking.icn
	
	encyc2/god/egyptian.col
	encyc2/god/egyptian.icn
	encyc2/god/indian.col
	encyc2/god/indian.icn
	encyc2/god/zulu.col
	encyc2/god/zulu.icn
	
	encyc2/seat/egyptian.col
	encyc2/seat/egyptian.icn
	encyc2/seat/indian.col
	encyc2/seat/indian.icn
	encyc2/seat/zulu.col
	encyc2/seat/zulu.icn
	
	encyc2/unit/egyptian.col
	encyc2/unit/egyptian.icn
	encyc2/unit/f_ballis.col
	encyc2/unit/f_ballis.icn
	encyc2/unit/indian.col
	encyc2/unit/indian.icn
	encyc2/unit/zulu.col
	encyc2/unit/zulu.icn
	
	image/chinese.col
	image/chinese.icn
	image/credits1.col
	image/credits1.icn
	image/credits2.col
	image/credits2.icn
	image/credits3.col
	image/credits3.icn
	image/credits4.col
	image/credits4.icn
	image/egyptian.col
	image/egyptian.icn
	image/greek.col
	image/greek.icn
	image/hallfame.col
	image/hallfame.icn
	image/indian.col
	image/indian.icn
	image/japanese.col
	image/japanese.icn
	image/losegame.col
	image/losegame.icn
	image/mainmenu.col
	image/mainmenu.icn
	image/maya.col
	image/maya.icn
	image/norman.col
	image/norman.icn
	image/persian.col
	image/persian.icn
	image/results.col
	image/results.icn
	image/viking.col
	image/viking.icn
	image/zulu.col
	image/zulu.icn
	
	misc/7kaa-dn.xpm
	misc/7kaa-dn.desktop
	
	music/chinese.wav
	music/greek.wav
	music/japanese.wav
	music/lose.wav
	music/maya.wav
	music/norman.wav
	music/persian.wav
	music/viking.wav
	music/war.wav
	music/win.wav
	
	resource/a_wave1.res
	resource/a_wave2.res
	resource/cursor.res
	resource/explmask.bin
	resource/expremap.bin
	resource/fnt_bard.res
	resource/fnt_casa.res
	resource/fnt_hitp.res
	resource/fnt_mid.res
	resource/fnt_news.res
	resource/fnt_san.res
	resource/fnt_smal.res
	resource/fnt_std.res
	resource/help.res
	resource/hill1.res
	resource/hill2.res
	resource/hill3.res
	resource/i_button.res
	resource/i_cursor.res
	resource/i_encyc.res
	resource/i_firmdi.res
	resource/i_firm.res
	resource/i_hill1.res
	resource/i_hill2.res
	resource/i_hill3.res
	resource/i_icon.res
	resource/i_if.res
	resource/i_menu2.res
	resource/i_menu.res
	resource/i_plant1.res
	resource/i_plant2.res
	resource/i_plant3.res
	resource/i_race.res
	resource/i_raw.res
	resource/i_rock1.res
	resource/i_rock2.res
	resource/i_rock3.res
	resource/i_snow.res
	resource/i_spict.res
	resource/i_tech.res
	resource/i_tera1.res
	resource/i_tera2.res
	resource/i_tera3.res
	resource/i_tern1.res
	resource/i_tern2.res
	resource/i_tern3.res
	resource/i_town.res
	resource/i_tpict1.res
	resource/i_tpict2.res
	resource/i_tpict3.res
	resource/i_unitgi.res
	resource/i_unitki.res
	resource/i_unitli.res
	resource/i_unitsi.res
	resource/i_unitti.res
	resource/i_unitui.res
	resource/i_wall.res
	resource/pal_enc.res
	resource/pal_menu.res
	resource/pal_std.res
	resource/pal_win.res
	resource/plant1.res
	resource/plant2.res
	resource/plant3.res
	resource/plantbm1.res
	resource/plantbm2.res
	resource/plantbm3.res
	resource/rock1.res
	resource/rock2.res
	resource/rock3.res
	resource/rockani1.res
	resource/rockani2.res
	resource/rockani3.res
	resource/rockblk1.res
	resource/rockblk2.res
	resource/rockblk3.res
	resource/rockbmp1.res
	resource/rockbmp2.res
	resource/rockbmp3.res
	resource/std.set
	resource/teranm1.res
	resource/teranm2.res
	resource/teranm3.res
	resource/terrain1.res
	resource/terrain2.res
	resource/terrain3.res
	resource/tersub.res
	resource/tut_intr.res
	resource/tut_list.res
	resource/tut_pict.res
	resource/tut_text.res
	
	scenario/7for7.scn
	scenario/7for7.scp
	scenario/7for7.sct
	scenario/c&d.scn
	scenario/c&d.scp
	scenario/c&d.sct
	scenario/desbow.scn
	scenario/desbow.scp
	scenario/desbow.sct
	scenario/desperdo.scn
	scenario/desperdo.scp
	scenario/desperdo.sct
	scenario/eradicat.scn
	scenario/eradicat.scp
	scenario/eradicat.sct
	scenario/ftfrautn.scn
	scenario/ftfrautn.scp
	scenario/ftfrautn.sct
	scenario/h&m.scn
	scenario/h&m.scp
	scenario/h&m.sct
	scenario/insulpos.scn
	scenario/insulpos.scp
	scenario/insulpos.sct
	scenario/ironfist.scn
	scenario/ironfist.scp
	scenario/ironfist.sct
	scenario/kukulcns.scn
	scenario/kukulcns.scp
	scenario/kukulcns.sct
	scenario/makebrek.scn
	scenario/makebrek.scp
	scenario/makebrek.sct
	scenario/meltpot.scn
	scenario/meltpot.scp
	scenario/meltpot.sct
	scenario/monorwar.scn
	scenario/monorwar.scp
	scenario/monorwar.sct
	scenario/newworld.scn
	scenario/newworld.scp
	scenario/newworld.sct
	scenario/norman.scn
	scenario/norman.scp
	scenario/norman.sct
	scenario/notlost.scn
	scenario/notlost.scp
	scenario/notlost.sct
	scenario/pirates.scn
	scenario/pirates.scp
	scenario/pirates.sct
	scenario/prnctkao.scn
	scenario/prnctkao.scp
	scenario/prnctkao.sct
	scenario/quesuccn.scn
	scenario/quesuccn.scp
	scenario/quesuccn.sct
	scenario/resdep.scn
	scenario/resdep.scp
	scenario/resdep.sct
	scenario/treadcar.scn
	scenario/treadcar.scp
	scenario/treadcar.sct
	scenario/vikblitz.scn
	scenario/vikblitz.scp
	scenario/vikblitz.sct
	scenario/weakened.scn
	scenario/weakened.scp
	scenario/weakened.sct
	
	scenari2/scn_01.scn
	scenari2/scn_01.scp
	scenari2/scn_01.sct
	scenari2/scn_02.scn
	scenari2/scn_02.scp
	scenari2/scn_02.sct
	scenari2/scn_03.scn
	scenari2/scn_03.scp
	scenari2/scn_03.sct
	scenari2/scn_04.scn
	scenari2/scn_04.scp
	scenari2/scn_04.sct
	scenari2/scn_05.scn
	scenari2/scn_05.scp
	scenari2/scn_05.sct
	scenari2/scn_06.scn
	scenari2/scn_06.scp
	scenari2/scn_06.sct
	scenari2/scn_07.scn
	scenari2/scn_07.scp
	scenari2/scn_07.sct
	scenari2/scn_08.scn
	scenari2/scn_08.scp
	scenari2/scn_08.sct
	scenari2/scn_09.scn
	scenari2/scn_09.scp
	scenari2/scn_09.sct
	scenari2/scn_10.scn
	scenari2/scn_10.scp
	scenari2/scn_10.sct
	scenari2/scn_11.scn
	scenari2/scn_11.scp
	scenari2/scn_11.sct
	scenari2/scn_12.scn
	scenari2/scn_12.scp
	scenari2/scn_12.sct
	scenari2/scn_13.scn
	scenari2/scn_13.scp
	scenari2/scn_13.sct
	scenari2/scn_14.scn
	scenari2/scn_14.scp
	scenari2/scn_14.sct
	scenari2/scn_15.scn
	scenari2/scn_15.scp
	scenari2/scn_15.sct
	
	sound/fire.wav
	sound/quake.wav
	sound/rain.wav
	sound/thunder.wav
	sound/wind.wav
	
	sprite/baatezu.spr
	sprite/ballista.spr
	sprite/canballa.spr
	sprite/canball.spr
	sprite/canballs.spr
	sprite/cannon.spr
	sprite/cansmoke.spr
	sprite/caravan.spr
	sprite/caravel.spr
	sprite/carave_s.spr
	sprite/catapult.spr
	sprite/catfirea.spr
	sprite/catfire.spr
	sprite/catfires.spr
	sprite/catstona.spr
	sprite/catstone.spr
	sprite/catstons.spr
	sprite/ch_arrow.spr
	sprite/chdragon.spr
	sprite/chinese.spr
	sprite/dragon.spr
	sprite/dr_arrow.spr
	sprite/eg_arrow.spr
	sprite/eg_god.spr
	sprite/eg_powar.spr
	sprite/egyptian.spr
	sprite/expcart.spr
	sprite/f_ballis.spr
	sprite/fb_arra0.spr
	sprite/fb_arrow.spr
	sprite/fb_arrs0.spr
	sprite/fcatapul.spr
	sprite/firekin.spr
	sprite/flamethr.spr
	sprite/fl_arrow.spr
	sprite/fpersian.spr
	sprite/galleon.spr
	sprite/galleo_s.spr
	sprite/gc_arrow.spr
	sprite/ge_star.spr
	sprite/giantet.spr
	sprite/gi_star.spr
	sprite/gith.spr
	sprite/gj_star.spr
	sprite/gnoll.spr
	sprite/goblin.spr
	sprite/gp_star.spr
	sprite/greek.spr
	sprite/gremjerm.spr
	sprite/gz_star.spr
	sprite/headless.spr
	sprite/hitspar2.spr
	sprite/hitspark.spr
	sprite/hobglob.spr
	sprite/indian.spr
	sprite/in_god.spr
	sprite/ja_god.spr
	sprite/japanese.spr
	sprite/ja_power.spr
	sprite/kukulcan.spr
	sprite/lizard.spr
	sprite/lyw.spr
	sprite/man.spr
	sprite/maya.spr
	sprite/moldman.spr
	sprite/no_arrow.spr
	sprite/norman.spr
	sprite/pe_arrow.spr
	sprite/pehealer.spr
	sprite/pe_powar.spr
	sprite/persian.spr
	sprite/pheonix.spr
	sprite/rm_arrow.spr
	sprite/rockman.spr
	sprite/skeleton.spr
	sprite/steam.spr
	sprite/tc_arr00.spr
	sprite/tc_arr01.spr
	sprite/tc_arr02.spr
	sprite/tc_arra0.spr
	sprite/tc_arra1.spr
	sprite/tc_arra2.spr
	sprite/tc_arrs0.spr
	sprite/tc_arrs1.spr
	sprite/tc_arrs2.spr
	sprite/tornado.spr
	sprite/transpor.spr
	sprite/transp_s.spr
	sprite/v_arrow.spr
	sprite/vessel.spr
	sprite/vessel_s.spr
	sprite/vi_god.spr
	sprite/viking.spr
	sprite/v_splash.spr
	sprite/zu_arrow.spr
	sprite/zu_god.spr
	sprite/zulu.spr
	
	tutorial/10captur.tut
	tutorial/1bas_mil.tut
	tutorial/2bas_eco.tut
	tutorial/2b_trade.tut
	tutorial/3researc.tut
	tutorial/4weapons.tut
	tutorial/5bas_nav.tut
	tutorial/6seatrad.tut
	tutorial/7mercena.tut
	tutorial/8fryhtan.tut
	tutorial/9seatpow.tut
	tutorial/loyalty.tut
	tutorial/spying.tut
])
AC_OUTPUT
