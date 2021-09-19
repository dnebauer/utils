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
