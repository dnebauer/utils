---
title:  "Building App::Uni"
author: "David Nebauer"
date:   "20 November 2018"
style:  [Standard, Latex10pt]
        # Latex8-12|14|17|20pt; PaginateSections; IncludeFiles
---

Follow the instructions in `man dn-build-perl-mod-deb` with the following
exceptions.

# Remove `dist.ini` #

This is to prevent a milla-based build. Using `milla` is problematic because it
requires the `Dist::Zilla::PluginBundle::RJBS` bundle, and even with it
installed the build fails because of some incompatibility between the source
structure and the `RJBS` bundle.

Remove references to `dist.ini` in the `META.json`, `META.yml` and `MANIFEST` files.
When editing `META.json` make sure not to leave a trailing comma on final list
items.

# Rename debian package #

Default package name is `libapp-uni-perl` but this causes a build-time
`libapp-perl-package-name` lintian error. This error occurs when the upstream
project is under the `App::` namespace for applications (executables). The
custom is to name these packages for the contained executable since that is
what most people will search for.

Edit the required file `control` to change the "Source" and "Package" fields
from `libapp-uni-perl` to `uni`. Edit the required file `changelog` to change
the package name on the first line from `libapp-uni-perl` to `uni`.

# Edit required files to prevent lintian errors #

During the build process set `changelog` to something like:

```
uni (9.003-1) unstable; urgency=low

  * Local package
  * Initial release
  * Closes: 500001

 -- David Nebauer <david@hezmana.cogito.loc>  Tue, 20 Nov 2018 19:11:17 +0930
```

During the build process edit `changelog` so the module files are under the
CC0 license:

```
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Source: https://metacpan.org/release/App-Uni
Upstream-Contact: Ricardo Signes <rjbs@cpan.org>
Upstream-Name: App-Uni

Files: *
Copyright: Ricardo Signes <rjbs@cpan.org>
License: CC0_1_0

Files: debian/*
Copyright: 2018, David Nebauer <david@hezmana.cogito.loc>
License: Artistic or GPL-1+

License: Artistic
 This program is free software; you can redistribute it and/or modify
 it under the terms of the Artistic License, which comes with Perl.
 .
 On Debian systems, the complete text of the Artistic License can be
 found in `/usr/share/common-licenses/Artistic'.

License: CC0_1_0
 CC0 1.0 Universal
 .
 Statement of Purpose
 .
 The laws of most jurisdictions throughout the world automatically confer
 exclusive Copyright and Related Rights (defined below) upon the creator and
 subsequent owner(s) (each and all, an "owner") of an original work of
 authorship and/or a database (each, a "Work").
 .
 Certain owners wish to permanently relinquish those rights to a Work for the
 purpose of contributing to a commons of creative, cultural and scientific
 works ("Commons") that the public can reliably and without fear of later
 claims of infringement build upon, modify, incorporate in other works, reuse
 and redistribute as freely as possible in any form whatsoever and for any
 purposes, including without limitation commercial purposes. These owners may
 contribute to the Commons to promote the ideal of a free culture and the
 further production of creative, cultural and scientific works, or to gain
 reputation or greater distribution for their Work in part through the use and
 efforts of others.
 .
 For these and/or other purposes and motivations, and without any expectation
 of additional consideration or compensation, the person associating CC0 with a
 Work (the "Affirmer"), to the extent that he or she is an owner of Copyright
 and Related Rights in the Work, voluntarily elects to apply CC0 to the Work
 and publicly distribute the Work under its terms, with knowledge of his or her
 Copyright and Related Rights in the Work and the meaning and intended legal
 effect of CC0 on those rights.
 .
 1. Copyright and Related Rights. A Work made available under CC0 may be
 protected by copyright and related or neighboring rights ("Copyright and
 Related Rights"). Copyright and Related Rights include, but are not limited
 to, the following:
 .
   i. the right to reproduce, adapt, distribute, perform, display, communicate,
      and translate a Work;
  ii. moral rights retained by the original author(s) and/or performer(s);
 iii. publicity and privacy rights pertaining to a person's image or likeness
      depicted in a Work;
  iv. rights protecting against unfair competition in regards to a Work,
      subject to the limitations in paragraph 4(a), below;
   v. rights protecting the extraction, dissemination, use and reuse of data in
      a Work;
  vi. database rights (such as those arising under Directive 96/9/EC of the
      European Parliament and of the Council of 11 March 1996 on the legal
      protection of databases, and under any national implementation thereof,
      including any amended or successor version of such directive); and
 vii. other similar, equivalent or corresponding rights throughout the world
      based on applicable law or treaty, and any national implementations
      thereof.
 .
 2. Waiver. To the greatest extent permitted by, but not in contravention of,
 applicable law, Affirmer hereby overtly, fully, permanently, irrevocably and
 unconditionally waives, abandons, and surrenders all of Affirmer's Copyright
 and Related Rights and associated claims and causes of action, whether now
 known or unknown (including existing as well as future claims and causes of
 action), in the Work (i) in all territories worldwide, (ii) for the maximum
 duration provided by applicable law or treaty (including future time
 extensions), (iii) in any current or future medium and for any number of
 copies, and (iv) for any purpose whatsoever, including without limitation
 commercial, advertising or promotional purposes (the "Waiver"). Affirmer makes
 the Waiver for the benefit of each member of the public at large and to the
 detriment of Affirmer's heirs and successors, fully intending that such Waiver
 shall not be subject to revocation, rescission, cancellation, termination, or
 any other legal or equitable action to disrupt the quiet enjoyment of the Work
 by the public as contemplated by Affirmer's express Statement of Purpose.
 .
 3. Public License Fallback. Should any part of the Waiver for any reason be
 judged legally invalid or ineffective under applicable law, then the Waiver
 shall be preserved to the maximum extent permitted taking into account
 Affirmer's express Statement of Purpose. In addition, to the extent the Waiver
 is so judged Affirmer hereby grants to each affected person a royalty-free,
 non transferable, non sublicensable, non exclusive, irrevocable and
 unconditional license to exercise Affirmer's Copyright and Related Rights in
 the Work (i) in all territories worldwide, (ii) for the maximum duration
 provided by applicable law or treaty (including future time extensions), (iii)
 in any current or future medium and for any number of copies, and (iv) for any
 purpose whatsoever, including without limitation commercial, advertising or
 promotional purposes (the "License"). The License shall be deemed effective as
 of the date CC0 was applied by Affirmer to the Work. Should any part of the
 License for any reason be judged legally invalid or ineffective under
 applicable law, such partial invalidity or ineffectiveness shall not
 invalidate the remainder of the License, and in such case Affirmer hereby
 affirms that he or she will not (i) exercise any of his or her remaining
 Copyright and Related Rights in the Work or (ii) assert any associated claims
 and causes of action with respect to the Work, in either case contrary to
 Affirmer's express Statement of Purpose.
 .
 4. Limitations and Disclaimers.
 .
 a. No trademark or patent rights held by Affirmer are waived, abandoned,
    surrendered, licensed or otherwise affected by this document.
 b. Affirmer offers the Work as-is and makes no representations or warranties
    of any kind concerning the Work, express, implied, statutory or otherwise,
    including without limitation warranties of title, merchantability, fitness
    for a particular purpose, non infringement, or the absence of latent or
    other defects, accuracy, or the present or absence of errors, whether or
    not discoverable, all to the greatest extent permissible under applicable
    law.
 c. Affirmer disclaims responsibility for clearing rights of other persons that
    may apply to the Work or any use thereof, including without limitation any
    person's Copyright and Related Rights in the Work. Further, Affirmer
    disclaims responsibility for obtaining any necessary consents, permissions
    or other rights required for any use of the Work.
 d. Affirmer understands and acknowledges that Creative Commons is not a party
    to this document and has no duty or obligation with respect to this CC0 or
    use of the Work.

License: GPL-1+
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 1, or (at your option)
 any later version.
 .
 On Debian systems, the complete text of version 1 of the GNU General
 Public License can be found in `/usr/share/common-licenses/GPL-1'.
```
