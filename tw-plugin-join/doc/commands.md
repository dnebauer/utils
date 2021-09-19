---
title:  "Convert server plugin to single-file plugin"
author: "David Nebauer"
date:   "19 October 2019"
style:  [Standard, Latex14pt]
        # Latex8-12|14|17|20pt; PaginateSections; IncludeFiles
---

# Step 1: Need specialised macro #

The macro `plugintiddlerstext` outputs a set of tiddlers in a format suitable
for use in a parent plugin file's _text_ field.

In this case the macro is provided in file `plugintiddlerstext.js`.

This is the file's contents:

```js
/*\
title: $:/.dtn/modules/macros/plugintiddlerstext.js
type: application/javascript
module-type: macro

Macro to output tiddlers matching a filter to JSON in a format
usable for plugin tiddler 'text' fields

\*/
(function(){

/*jslint node: true, browser: true */
/*global $tw: false */
"use strict";

/*
Information about this macro
*/

exports.name = "plugintiddlerstext";

exports.params = [
	{name: "filter"}
];

/*
Run the macro
*/
exports.run = function(filter) {
	var tiddlers = this.wiki.filterTiddlers(filter),
        tiddlers_data = new Object(),
        data = new Object();
	for(var t=0;t<tiddlers.length; t++) {
		var tiddler = this.wiki.getTiddler(tiddlers[t]);
		if(tiddler) {
			var fields = new Object();
			for(var field in tiddler.fields) {
				fields[field] = tiddler.getFieldString(field);
			}
            var title = tiddler.getFieldString('title');
            tiddlers_data[title] = fields;
		}
	}
    data['tiddlers'] = tiddlers_data;
	return JSON.stringify(data,null,$tw.config.preferences.jsonSpaces);
};

})();
```

# Step 2: Customised templates for setfield commands #

Thes templates are used by the `--setfield` command to create _type_ and _text_
fields in the plugin tiddler file.

One template is standard for all conversions: adding a _type_ field set to
_application/json_. This template is called
`$:/core/templates/.dtn/plugin-tiddlers-type`. In this particular conversion it
is provided by the file `plugintiddlerstext.tid` and has the content:

```tid
title: $:/core/templates/.dtn/plugin-tiddlers-type

<!--

This template is for setting plugin field 'type' to 'application/json'

--><$text text='application/json'/>
```

Another template needs to be customised for each conversion project. This
template is called `$:/core/templates/.dtn/plugin-tiddlers-text`. In this
particular conversion it is provided by the file `plugintiddlerstext.tid` and
has the content:

```tid
title: $:/core/templates/.dtn/plugin-tiddlers-text

<!--

This template is for saving tiddlers for use in a plugin tiddler's text field

--><$text text=<<plugintiddlerstext "[prefix[$:/plugins/.dtn/insert-table/]] =[[$:/config/plugin/.dtn/insert-table/style-sets]]">>/>
```

Note the use of the `=` filter prefix to add a tiddler title to the filter.

# Step 3: Import server plugin files #

The server plugin files are imported into a new wiki.

Note that the `--load` or `--import` command can be used to import each file.
The `--load` command infers the needed deserializer based on the file
extension, while the `--import` command needs the deserializer to be explicitly
specified. The `--load` command cannot import a `plugin.info` and would
presumable struggle with files lacking extensions.

It does not appear possible to use the macro/template loaded in this command
_within_ this command. For that reason the wiki is saved to disk after the
files are imported -- the macro is utilised in the following `tiddlywiki`
command.

This is the command used for the test conversion.

```bash
DIR=/usr/local/lib/node_modules/tiddlywiki/plugins/dtn/insert-table/ ; \
    tiddlywiki \
        --load ~/Downloads/plugintiddlerstext.tid \
        --import ~/Downloads/plugintiddlerstext.js application/javascript \
        --load $DIR/macros-helper.tid \
        --load $DIR/macros.tid \
        --import $DIR/style-sets.tid application/x-tiddler \
        --import $DIR/plugin.info application/json \
        --import $DIR/doc/credits.tid application/x-tiddler \
        --import $DIR/doc/dependencies.tid application/x-tiddler \
        --import $DIR/doc/license.tid application/x-tiddler \
        --import $DIR/doc/readme.tid application/x-tiddler \
        --import $DIR/doc/usage.tid application/x-tiddler \
        --import $DIR/js/enlist-operator.js application/javascript \
        --import $DIR/js/uuid-macro.js application/javascript \
        --savewikifolder ~/tmp/tw-unpack1
```

# Step 4: Add plugin file contents to parent plugin file #

This step uses the specialised macro from step 1 and the customised templates
from step 2.

Experience shows it is necessary to write the wiki to a new folder for the
changes to the parent plugin file to be successfully exported by the subsequent
command.

```bash
tiddlywiki ~/tmp/tw-unpack1 \
    --setfield \
        "[[$:/plugins/.dtn/insert-table]]" \
        "text" \
        "$:/core/templates/.dtn/plugin-tiddlers-text" \
        "text/plain" \
    --setfield \
        "[[$:/plugins/.dtn/insert-table]]" \
        "type" \
        "$:/core/templates/.dtn/plugin-tiddlers-type" \
        "text/plain" \
    --savewikifolder \
        ~/tmp/tw-unpack2
```

# Step 5: Write plugin file to disk #

The parent plugin altered in step 4 is exported to disk.

This is the command to get this conversion's plugin file in `tid` format:

```bash
tiddlywiki ~/tmp/tw-unpack2 \
    --render \
        "[[$:/plugins/.dtn/insert-table]]" \
        "\$__plugins_.dtn_insert-table.tid" \
        "text/plain" \
        "$:/core/templates/tid-tiddler"
```

This is the command to get this conversion's plugin file in `json` format:

```bash
tiddlywiki ~/tmp/tw-unpack2 \
    --render \
        "[[$:/plugins/.dtn/insert-table]]" \
        '$__plugins_.dtn_insert-table.json' \
        "text/plain" \
        "$:/core/templates/json-tiddler"
```

Note the filename given as the second parameter to the `--render` command. The
`$` requires special care -- if using double quotes it must be
backslash-escaped, but escaping is unnecessary if using single quotes.
