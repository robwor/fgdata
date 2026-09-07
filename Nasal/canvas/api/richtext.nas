#-------------------------------------------------------------------------------
# canvas.Text
#-------------------------------------------------------------------------------
# Class for a text element on a canvas, with markup support through Pango
#
var FontMapper = func(family = nil, weight = nil, style = nil, options = nil)
{
    var defaults = {
        "default-font-family": "Liberation Sans",
        "default-font-weight": nil,
        "default-font-style": nil,
    };

    # setup defaults if no options are given
    if (options == nil) {
        options = defaults;
    }
    if (!ishash(options)) {
        logprint(LOG_ALERT, "font_mapper: options must be a hash!")
    }

    # use defaults for missing arguments
    if (family == nil) {
        family = options["default-font-family"] or defaults["default-font-family"];
    }
    if (weight == nil) {
        weight = options["default-font-weight"] or defaults["default-font-weight"];
    }
    if (style == nil) {
        style = options["default-font-style"] or defaults["default-font-style"];
    }

    if (isfunc(options["font-mapper"])) {
        var font = options["font-mapper"](family, weight, style);
        if (isa(font, FontDescription)) {
            return font;
        }
    }

    # Remove '' that Inkscape puts around font names containing spaces
    if (left(family, 1) == "'") family = substr(family, 1);
    if (right(family, 1) == "'") family = substr(family, 0, size(family) - 1);

    # map generic Inkscape sans serif to our default font
    if (string.lc(family) == "sans" or string.lc(family) == "sans-serif") {
        family = "Liberation Sans";
    }
    if (left(family, 10) == "Liberation") {
        style = style == "italic" or style == "Italic" ? "Italic" : nil;
        weight = weight == "bold" or weight == "Bold" ? "Bold" : nil;

        return FontDescription.new(family: family, weight: weight, style: style);
    }

    return FontDescription.default();
};

var FontDescription = {
    new: func(family = nil, weight = nil, style = nil, size = nil) {
        var obj = {
            parents: [FontDescription],
            family: family,
            weight: weight,
            style: style,
            size: size,
        };

        return obj;
    },

    setFamily: func(family) {
        if (isstr(family)) {
            me.family = family;
        } else {
            me.family = nil;
        }
        return me;
    },
    setWeight: func(weight) {
        if (isstr(weight)) {
            me.weight = weight;
        } else {
            me.weight = nil;
        }
        return me;
    },
    setStyle: func(style) {
        if (isstr(style)) {
            me.style = style;
        } else {
            me.style = nil;
        }
        return me;
    },
    setSize: func (size) {
        if (isnum(size) and size > 0) {
            me.size = size;
        } else {
            me.size = nil;
        }
        return me;
    },

    default: func() {
        return FontDescription.new(family: "Liberation Sans", size: 14);
    },

    isEmpty: func() {
        return family == nil and weight == nil and style == nil and size == nil;
    },

    fromString: func(str) {
        if (!str) {
            return FontDescription.new();
        }
        var family = nil;
        var weight = nil;
        var style = nil;
        var size = nil;
        var fontStringParts = split(" ", str);
        foreach (var part; fontStringParts) {
			var scannedSize = [];
            if (string.scanf(part, "%dpx", scannedSize)) {
               size = scannedSize[0];
            } elsif (contains(["Normal", "Italic"], part)) {
                style = part;
            } elsif (contains(["Thin", "Light", "Normal", "Medium", "Bold"], part)) {
                weight = part;
            } else {
				if (family == nil) {
					family = part;
				} else {
					family = string.join(" ", [family, part]);
				}
			}
        }
        return FontDescription.new(family, weight, style, size);
    },

    toString: func() {
        var parts = [];
        if (isstr(me.family)) {
            append(parts, me.family);
        }
        if (isstr(me.weight)) {
            append(parts, me.weight);
        }
        if (isstr(me.style)) {
            append(parts, me.style);
        }
        if (isnum(me.size) and me.size > 0) {
            append(parts, sprintf("%dpx", me.size));
        }
        return string.join(" ", parts);
    },

    copy: func() {
        return FontDescription.new(family: me.family, weight: me.weight, style: me.style, size: me.size);
    }
};

var RichText = {
    new: func(ghost) {
        var obj = {
            parents: [RichText, Element.new(ghost)],
        };
        obj.setFont(FontDescription.default());

        return obj;
    },

    setMarkup: func(markup) {
        me.set("markup", typeof(markup) == "scalar" ? markup : "");
    },

    # Set the text
    setText: func(text) {
        return me.set("text", typeof(text) == "scalar" ? text : "");
    },

    getText: func() {
        return me.text();
    },
    getMarkup: func() {
        return me.markup();
    },

    # Set alignment
    #
    #    @param align String, one of:
    #     left-top
    #     left-center
    #     left-bottom
    #     center-top
    #     center-center
    #     center-bottom
    #     right-top
    #     right-center
    #     right-bottom
    #     left-baseline
    #     center-baseline
    #     right-baseline
    setAlignment: func(align) {
        return me.set("alignment", align);
    },

    # Set font family, weight, style and size
	# Any unset arguments will be reused from the currently applied font, or if no font is applied yet, a default font of 
	# Liberation Sans Normal Normal 14px will be used.
    setFont: func(family = nil, weight = nil, style = nil, size = nil) {
        var currentFont = FontDescription.fromString(me.get("font", ""));
		if (!currentFont.family) {
			currentFont.family = FontDescription.default().family;
        }
        if (!isnum(currentFont.size) or currentFont.size < 1) {
            currentFont.size = FontDescription.default().size;
        }

        var newFont = nil;
        if (isa(family, FontDescription)) {
            newFont = family.copy();
        } else {
            newFont = FontDescription.new(family: family, weight: weight, style: style, size: size);
        }

        if (!isstr(newFont.family) or !newFont.family) {
            newFont.family = currentFont.family;
        }
        if (!isstr(newFont.weight) or !newFont.weight) {
            newFont.weight = currentFont.weight;
        }
        if (!isstr(newFont.style) or !newFont.style) {
            newFont.style = currentFont.style;
        }
        if (!isnum(newFont.size) or newFont.size < 1) {
            newFont.size = currentFont.size;
        }

        return me.set("font", newFont.toString());
    },

    setMaxWidth: func(w) {
        if (!isnum(w) or w < 0) {
            w = -1;
        }
        return me.setInt("max-width", w);
    },
    
    setMaxHeight: func(h) {
        if (!isnum(h) or h < 0) {
            h = -1;
        }
        return me.setInt("max-height", h);
    },

    setColor: func {
        return me.set("foreground-color", _getColor(arg));
    },

    setForegroundColor: func {
        return me.set("foreground-color", _getColor(arg));
    },

    foregroundColor: func {
        return me.get("foreground-color");
    },

    setBackgroundColor: func {
        return me.set("background-color", _getColor(arg));
    },

    backgroundColor: func {
        return me.get("background-color");
    },

    setLineColor: func {
        return me.set("line-color", _getColor(arg));
    },
    lineColor: func {
        return me.get("line-color");
    },

    setSelectionColor: func {
        return me.set("selection-color", _getColor(arg));
    },
    selectionColor: func {
        return me.get("selection-color");
    },

    setLineSpacing: func(spacing) {
        return me.setDouble("line-spacing", spacing);
    },

    lineSpacing: func {
        return me.get("line-spacing");
    },
    setPadding: func(padding) {
        return me.setInt("padding", padding);
    },
    padding: func {
        return me.get("padding");
    }
};
