gui.Style = {
  _CLASS: "gui.Style",
  new: func(name, name_icon_theme)
  {
    var root_node = props.globals.getNode("/canvas/desktop", 1)
                                 .addChild("style");
    var gui_path = getprop("/sim/fg-root") ~ "/gui";
    var style_path = gui_path ~ "/styles/" ~ name;

    var m = {
      parents: [gui.Style],
      _path: style_path,
      _dir_icons: gui_path ~ "/icons/" ~ name_icon_theme,
      _node: io.read_properties(style_path ~ "/style.xml", root_node),
      _colors: {},
      _sizes: {},
      _fonts: {}
    };

    # parse theme colors
    var colors = m._node.getChild("colors");
    if( colors != nil )
    {
      foreach(var color; colors.getChildren())
      {
        var tintNode = color.getChild("tint");
        var shadeNode = color.getChild("shade");
        var baseNode = color.getChild("base");

        if (tintNode and baseNode) {

        } elsif (shadeNode and baseNode) {

        } else {
          # todo : support a CSS style color as a direct text child,
          # instead of seperate RGBA components
          m._colors[ color.getName() ] = m._parseRGBANodes(color);
        }
      }
    }

    var sizes = m._node.getChild("sizes");
    if (sizes) {
      foreach(var sizeNode; sizes.getChildren()) {
          var factorNode = sizeNode.getChild("factor");
          var baseNode = sizeNode.getChild("base");
          if (factorNode or baseNode) {
            var f = factorNode.getValue() or 1.0;
            m._sizes[sizeNode.getName()] = f * m.getSize(baseNode.getValue(), 1.0);
          } else {
            # simple literal value, easy
            m._sizes[sizeNode.getName()] = sizeNode.getValue();
          }
      } # of sizes iteration
    }

    var fonts = m._node.getChild("fonts");
    var defaultFont = fonts.getChild("default");
    if (!defaultFont) {
      logprint(LOG_DEV_WARN, "GUI style " ~ name ~ " does not provide default font, using hardcoded fallback");
      m._fonts["default"] = FontDescription.new(
        family: "Liberation Sans",
        size: 14
      );
    } else {
        var family = defaultFont.getValue("family");
        var weight = defaultFont.getValue("weight");
        var style = defaultFont.getValue("style");
        var size = defaultFont.getValue("size");
        if (!family) {
          logprint(LOG_DEV_WARN, "GUI style " ~ name ~ ": missing default font family, using hardcoded fallback");
          family = "Liberation Sans";
        }
        if (!isnum(size) or size < 1) {
          logprint(LOG_DEV_WARN, "GUI style " ~ name ~ ": missing / malformed default font size, using hardcoded fallback");
          size = 14;
        }
        m._fonts["default"] = FontDescription.new(family: family, weight: weight, style: style, size: size);
    }

    if (fonts) {
      foreach (var fontNode; fonts.getChildren()) {
        var family = fontNode.getValue("family") or m._fonts["default"].family;
        var weight = fontNode.getValue("weight") or m._fonts["default"].weight;
        var style = fontNode.getValue("style") or m._fonts["default"].style;
        var size = fontNode.getValue("size");
        if (!isnum(size) or size < 1) {
          size = m._fonts["default"].size;
        }
        m._fonts[fontNode.getName()] = FontDescription.new(family: family, weight: weight, style: style, size: size);
      }
    }

    m._dir_decoration =
      m._path ~ "/" ~ (m._node.getValue("folders/decoration") or "decoration");
    m._dir_widgets =
      m._path ~ "/" ~ (m._node.getValue("folders/widgets") or "widgets");

    return m;
  },
  _parseRGBANodes: func(color)
  {
    var comp_names = ["red", "green", "blue", "alpha"];
    var str = "rgba(";
    for(var i = 0; i < size(comp_names); i += 1)
    {
      if( i > 0 )
        str ~= ",";
      var val = color.getValue(comp_names[i]);
      if( val == nil )
        val = 1;
      if( i < 3 )
        str ~= int(val * 255 + 0.5);
      else
        str ~= int(val * 100) / 100;
    }
    return str ~ ")";
  },

  getColor: func(name, def = "#00ffff")
  {
    return me._colors[name] or def;
  },
  getSize: func(name, def = 1.0)
  {
    return me._sizes[name] or def;
  },
  getFont: func(name, def = nil) {
    def = isa(def, FontDescription) ? def : me._fonts["default"];
    return me._fonts[name] or def;
  }
};
