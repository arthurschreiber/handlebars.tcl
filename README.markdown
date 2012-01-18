handlebars.tcl is port of handlebars.js (http://handlebarsjs.com/), a logicless templating language.

handlebars.js itself is an extension of the [Mustache templating language](http://mustache.github.com/).

Unfortunately, due to limitations of Tcl, handlebars.tcl templates ARE NOT compliant with the Mustache spec,
and there is no easy way to fix this. But, handlebars.tcl templates are fully compatible with handlebars.js,
but compatibility does not go the other way around.