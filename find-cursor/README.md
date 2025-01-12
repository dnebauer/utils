---
title: "find-cursor set up"
author: "David Nebauer"
date: "12 January 2025"
style: [Standard, Latex14pt]
---

This project was set up to create a debian package containing the `find-cursor`
utility. This involved the following subdirectories:

## `repo-fork`

This is a local copy of the github [dnebauer/find-cursor][dnebauer-repo]
repository -- note it is a fork of [arp242/find-cursor][arp242-repo].

## build

The repository files are copied here and `make` is run to create the
`find-cursor` executable file.

## deb-pkg

The following build files are copied here:

* `find-cursor`
* `find-cursor.1`
* `_find-cursor`

Note the zsh completion file `_find-cursor` is copied to the subdirectory:

| `contrib/completion/zsh`.

The package is built using `dn-qk-deb`.

---

This installation method for `find-cursor` was superseded by installing it as a
local dotfile (stow) package which included the executable, manpage and zsh
completion files.

[comment]: # (URLs)

   [arp242-repo]: https://github.com/arp242/find-cursor

   [dnebauer-repo]: https://github.com/dnebauer/find-cursor
