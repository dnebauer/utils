---
title: "Building nvimpager"
author: "David Nebauer"
date: "30 October 2025"
style: [Standard, Latex14pt]
---

Follow these steps.

## Required tools

Ensure the `scdoc` tool is available. (Supplied by debian package 'scdoc'.)

## Get source

From the `repo` subdirectory clone the [lucc/nvimpager][gitrepo] github
repository with the command:

```bash
git clone https://github.com/lucc/nvimpager.git ./
```

[gitrepo]: https://github.com/lucc/nvimpager

## Build

Run the command:

```bash
make --prefix=/usr
```

Run the command:

```bash
checkinstall -D \
  --pkgname=nvimpager \
  --pkgversion=99c273c \
  --pkglicense='custom - see LICENSE file' \
  --pkggroup=text \
  --pkgsource='https://github.com/lucc/nvimpager' \
  --pakdir='/home/david/data/computing/projects/utils/nvimpager/build' \
  --maintainer='David Nebauer <david@nebauer.org>' \
  --provides='nvimpager' \
  --requires='neovim (>= 0.9.0),bash' \
  make install PREFIX=/usr
```

and follow the `checkinstall` instructions.

In particular, note:

- The debian package is built in the `../build` subdirectory (which is
  specified in the above command by an absolute path, but which might work as a
  relative path)
- The 'maintainer' value did not appear to be picked up by `checkinstall` -- it
  may be that it accepts only an email address
- The version used is the current git revision from the project repository main
  page
- Uses the standard debian 'prefix' of `/usr`.

## Install

Use your preferred installer to install the built debian package.

Options include `dpkg` and `gdebi`.
