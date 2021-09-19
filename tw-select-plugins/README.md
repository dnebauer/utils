# tw-select-plugins #

The `tw-select-plugins` script changes which server tiddlywiki plugins are
selected for a client wiki.

It accepts as command line input the plugin list from a client wiki
`tiddlywiki.info` file. The user is then able to select and de-select plugins
from a listbox widget. Finally, the script outputs the new selection of plugins
in the same format used by `tiddlywiki.info`.

The `tw-select-plugins` script can be used as a filter when editing a
`tiddlywiki.info` file with vim.
