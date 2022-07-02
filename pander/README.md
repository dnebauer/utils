# Pander — a pandoc wrapper script #

Pander is a replacement for [msprev/panzer](https://github.com/msprev/panzer).
Like that project, pander keeps the concept of style keywords added to the
document's metadata, and these keywords have associated pandoc metadata
settings and pandoc command-line options. Like panzer, pander constructs a
pandoc command using the style keywords and options passed to it on the command
line, executes the pandoc command, and carries out necessary post-processing.

In panzer the style behaviour of keywords was defined in a configuration file.
In pander, the behaviour of style keywords is defined in the
[pander](https://github.com/dnebauer/pander/blob/main/pander) script itself. In
fact, it is defined in four style keyword data tables. To ensure these tables
are kept properly synchronised, a utility script called
[keyword-table](https://github.com/dnebauer/pander/blob/main/keyword-table) is
provided as part of pander. This utility script contains a master keyword data
table containing the complete definitions of all style keywords. The script can
output constructors for all four of the style keyword data tables in the
[pander](https://github.com/dnebauer/pander/blob/main/pander) script. See the
manpage for
[keyword-table](https://github.com/dnebauer/pander/blob/main/keyword-table)
for details on how to define the style keywords in that script.

Pander executes the following steps:

* Extract style keywords by running pandoc on the input file. This relies on
  the existence of a `<data_dir>/templates/metajson.tpl` file having as its
  sole content the line "\$meta-json\$".

* Assemble metadata settings associated with the style keywords and write them
  to a temporary json file.

* Assemble pandoc command line options associated with the style keywords.

* Add to the pandoc command a `--metadata-file` option to load the temporary
  json metadata file generated earlier.

* Add to the pandoc command all options passed to pander.

* Execute the pandoc command.

* Perform any post-execution tasks associated with the style keywords.

Note in the sequence above that options provided to pander on the command line
are added after options defined by style keywords. Because in pandoc later
options in the pandoc command override earlier ones, options provided to pander
on the command line will override options defined by style keywords.

Pander takes some shortcuts because it is intended to be run in a specific
environment: called by vim's [vim-pandoc
plugin](https://github.com/vim-pandoc/vim-pandoc). That plugin ensures the
parameters passed to pander include the `--output` and `--to` options, in the
format `--name=value`, and the markdown input file is the last argument. Pander
will fail if those conditions are not met, so any user-defined modifications to
the parameters passed by vim-pandoc should be in the same format.

Unlike panzer, pander does not maintain its own data directory for pandoc to
use. Pandoc is left to determine its own data directory.

Both the [pander](https://github.com/dnebauer/pander/blob/main/pander) and
[keyword-table](https://github.com/dnebauer/pander/blob/main/keyword-table)
scripts contain [perlpod](https://perldoc.perl.org/perlpod) which, when
extracted using a tool like [pod2man](https://perldoc.perl.org/pod2man),
generate manpages for each script.

The styles currently defined have the following dependencies:

* lua (v5.3 or greater)
* pandoc (v2.12 or greater)
* pandoc templates (all available from github repository
  dnebauer/dotfiles-pandoc): `metajson.tpl`, `UoE-letter.latex`, and
  `tufte-jez.latex`
* pandoc filters: `heading2bold.py`, `paginatesects.py`,
  `include-code-files.lua`, `include-files.lua`, and `pagebreak.lua` (available
  from github repository dnebauer/dotfiles-pandoc); and `pandoc-eqnos`,
  `pandoc-fignos`, `pandoc-secnos`, and `pandoc-tablenos` (available from github
  repository tomduck/pandoc-xnos)
* latex packages: extsizes, fontspec, microtype, placeins, ucharclasses, and
  xcolor
* latex fonts: IPAexMincho, Inconsolata, Junicode Two Beta, Linux Biolinum O,
  and Linux Libertine O.

This is free software. See the
[LICENSE](https://github.com/dnebauer/pander/blob/main/LICENSE) file for more
details.
