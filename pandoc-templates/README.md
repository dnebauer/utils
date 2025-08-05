---
title: "Pandoc templates"
author: "David Nebauer"
date: "4 August 2025"
style: [Standard, Latex14pt]
---

The pandoc templates in `~/.local/share/pandoc/templates` are sourced from this
directory tree. Each subdirectory is a set of template files:

## `forked-customised-jgm-pandoc-templates/`

This is a forked version of the pandoc project's [standard templates][jgm]. The
fork has the following customisations:

* added local template files, all starting with `my-`
* added commands in the standard templates to call up the local template files.

## `eisvogel/`

This holds the most recent release of the template files that are consistent
with the installed `pandoc` version.

The template files are _not_ available from the [Eisvogel repository][eisvogel]
itself, but must be obtained from a [project release][release] asset.

The files are:

* `eisvogel.latex`
* `beamer.latex`

[comment]: # (URLs)

   [eisvogel]: https://github.com/Wandmalfarbe/pandoc-latex-template

   [forked]: https://github.com/dnebauer/pandoc-templates

   [jgm]: https://github.com/jgm/pandoc-templates

   [release]: https://github.com/Wandmalfarbe/pandoc-latex-template/releases
