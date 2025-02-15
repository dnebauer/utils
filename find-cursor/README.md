# find-cursor set up

This project was set up to create a debian package containing the `find-cursor`
utility.

This process involved the following subdirectories:

## `1_repo-fork`

This is a local copy of the github [dnebauer/find-cursor][dnebauer-repo]
repository -- note it is a fork of [arp242/find-cursor][arp242-repo].

Delete "git" files and subdirectories in this directory to avoid submodule
warnings when updating the "utils" repository.

## `2_build`

The repository files are copied here and `make` is run to create the
`find-cursor` executable file.

## `3_deb-pkg`

The following build files are copied here:

* `find-cursor`
* `find-cursor.1`
* `_find-cursor`

Note the zsh completion file `_find-cursor` is copied to the subdirectory `contrib/completion/zsh`.

The package is built using `dn-qk-deb`.

---

This installation method for `find-cursor` was superseded by installing it as a
local dotfile (stow) package which included the executable, manpage and zsh
completion files.

[comment]: # (URLs)

   [arp242-repo]: https://github.com/arp242/find-cursor

   [dnebauer-repo]: https://github.com/dnebauer/find-cursor
