var DefaultStyle = {
  _CLASS: "DefaultStyle",

  new: func(name, name_icon_theme)
  {
    return {
      parents: [ gui.Style.new(name, name_icon_theme),
                 DefaultStyle ]
    };
  },
  createWidget: func(parent, type, cfg)
  {
    var factory = me.widgets[type];
    if( factory == nil )
    {
      debug.warn("DefaultStyle: unknown widget type (" ~ type ~ ")");
      return nil;
    }

    var w = {
      parents: [factory],
      _style: me,
      _createElement: func(name, type) {
        var mem = '_' ~ name;
        if (me[mem] == nil) {
          me[ mem ] = me._root.createChild(type, "label-" ~ name);

          if (type == "richtext") {
             me[mem].setFont(me._style.getFont(name))
                      .setAlignment("left-center");
          }
        }
        return me[mem];
      },
      _deleteElement: func(name) {
        name = '_' ~ name;
        if (me[name] != nil) {
          me[name].del();
          me[name] = nil;
        }
        return me;
      }
    };
    call(factory.new, [parent, cfg], w);
    return w;
  },
  widgets: {}
};

# A button
DefaultStyle.widgets.button = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "button");
    me._bg = me._root.createChild("path");
    me._border = me._root.createChild("image", "button")
            .set("slice", "10 12"); #"7")
    me._label = me._root.createChild("richtext")
            .setFont(me._style.getFont("button"))
            .setAlignment("center-center");
    if (cfg.get("flat")) {
      me._border.hide();
      me._bg.hide();
    }
  },
  setSize: func(model, w, h)
  {
    me._bg.reset().rect(0, 0, w, h, {"border-radius": 5});
    me._border.setSize(w, h);
  },
  setText: func(model, text)
  {
    me._label.setText(text);

    var fontSize = me._style.getFont("button").size;
    var padding = me._style.getPadding("button");
    var height =  fontSize + padding * 2;
    var min_width = text ? me._label.width() + padding * 2: height;
    model.setLayoutMinimumSize([min_width, height]);
    model.setLayoutSizeHint([min_width, height]);
    model.setLayoutMaximumSize([MAX_SIZE, height]);

    return me;
  },
  update: func(model)
  {
    var backdrop = !model._windowFocus();
    var (w, h) = model._size;
    var file = me._style._dir_widgets ~ "/";

    # TODO unify color names with image names
    var bg_color_name = "button_bg_color";
    if( backdrop )
      bg_color_name = "button_backdrop_bg_color";
    else if( !model._enabled )
      bg_color_name = "button_bg_color_insensitive";
    else if( model._down )
      bg_color_name = "button_bg_color_down";
    else if( model._hover )
      bg_color_name = "button_bg_color_hover";
    me._bg.set("fill", me._style.getColor(bg_color_name));

    if( backdrop )
    {
      file ~= "backdrop-";
      me._label.setForegroundColor(me._style.getColor("backdrop_fg_color"));
    }
    else
      me._label.setForegroundColor(me._style.getColor("fg_color"));
    file ~= "button";

    if( model._down )
    {
      file ~= "-active";
      me._label.setTranslation(w / 2 + 1, h / 2 + 1);
    }
    else
      me._label.setTranslation(w / 2, h / 2);

    if( model._enabled )
    {
      if( model._focused and !backdrop )
        file ~= "-focused";

      if( model._hover and !model._down )
        file ~= "-hover";
    }
    else
      file ~= "-disabled";

    me._border.set("src", file ~ ".png");
  }
};

DefaultStyle.widgets["window-button"] = {
  new: func(parent, cfg) {
    me._root = parent.createChild("group", "window-button");
    me._icon = me._root.createChild("image", "icon");
  },
  setSize: func(model, w, h) {
    me._icon.setSize(w, h);
  },
  setText: func(model, text) {},
  update: func(model) {
    var file = style._dir_decoration ~ "/" ~ model._cfg.get("name");
    var window_focus = model._windowFocus();
    file ~= window_focus ? "_focused" : "_unfocused";

    if (model._down) {
      file ~= "_pressed";
    } else if (model._hover) {
      file ~= "_prelight";
    } else if (window_focus) {
      file ~= "_normal";
    }

    me._icon.set("src", file ~ ".png");
  }
};

# A checkbox
DefaultStyle.widgets.checkbox = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "checkbox");
    var iconSize = me._style.getSize("checkbox", "icon");
    me._icon =
      me._root.createChild("image", "checkbox-icon")
              .setSize(iconSize, iconSize);
    me._label =
      me._root.createChild("richtext")
              .setFont(me._style.getFont("checkbox"))
              .setAlignment("left-center");
  },
  setSize: func(model, w, h)
  {
    var iconSize = me._style.getSize("checkbox", "icon");
    var fontSize = me._style.getFont("checkbox").size;
    var padding = me._style.getPadding("checkbox");
    me._icon.setTranslation(padding, (h - iconSize) / 2);
    me._label.setTranslation(padding + iconSize + padding, int(h / 2));

    return me;
  },
  setText: func(model, text)
  {
    me._label.setText(text);

    var iconSize = me._style.getSize("checkbox", "icon");
    var fontSize = me._style.getFont("checkbox").size;
    var padding = me._style.getPadding("checkbox");
    var height = math.max(fontSize, iconSize) + padding * 2;
    var min_width = text ? padding + iconSize + padding + me._label.width() + padding: height;
    model.setLayoutMinimumSize([min_width, height]);
    model.setLayoutSizeHint([min_width, height]);
    model.setLayoutMaximumSize([MAX_SIZE, height]);

    return me;
  },
  update: func(model)
  {
    var backdrop = !model._windowFocus();
    var (w, h) = model._size;
    var file = me._style._dir_widgets ~ "/";

    if( backdrop )
    {
      file ~= "backdrop-";
      me._label.setColor(me._style.getColor("backdrop_fg_color"));
    }
    else
      me._label.setColor(me._style.getColor("fg_color"));
    file ~= "check";

    if( model._down )
      file ~= "-selected";
    else
      file ~= "-unselected";

    if( model._enabled )
    {
      if( model._hover )
        file ~= "-hover";
    }
    else
      file ~= "-disabled";

    me._icon.set("src", file ~ ".png");
  }
};

DefaultStyle.widgets.switch = {
        new: func(parent, cfg) {
                me._root = parent.createChild("group", "switch");
                me._bg = me._root.createChild("path", "switch-background");
                me._thumb = me._root.createChild("path", "switch-thumb");
        },

        setText: func {},

        setSize: func(model, w, h) {
                me._bg.reset()
                                                .moveTo(w / 4, 0.5)
                                                .arcSmallCCWTo((w - 1) / 4, (h - 1) / 2, 0, w / 4, h - 0.5)
                                                .horiz(w / 2)
                                                .arcSmallCCWTo((w - 1) / 4, (h - 1) / 2, 0, w / 4 * 3, 0.5)
                                                .close();
                me._thumb.reset()
                                                .ellipse((w - 1) / 4, (h - 1) / 2, w / 4, h / 2);
        },

        update:  func(model) {
                var bg_color = "switch_bg_color";
                if (!model._enabled) {
                        bg_color ~= "_disabled";
                } elsif (model._down) {
                        bg_color ~= "_checked";
                }
                me._bg.set("fill", me._style.getColor(bg_color));
                me._bg.set("stroke", me._style.getColor("switch_bg_border_color"));
                me._thumb.set("fill", me._style.getColor("switch_thumb_color"));
                me._thumb.set("stroke", me._style.getColor("switch_thumb_border_color"));
                me._thumb.setTranslation(model._down * 24, 0);
        },
};

# A radio button
DefaultStyle.widgets["radio-button"] = {
  new: func(parent, cfg) {
    me._root = parent.createChild("group", "radio-button");
    me._icon = me._root.createChild("group", "radio-button-icon");
    var iconSize = me._style.getSize("radio-button", "icon");
    me._icon_background = me._icon.createChild("path", "radio-button-icon-border")
            .circle(iconSize / 2);
    me._icon_border = me._icon.createChild("path", "radio-button-icon-border")
            .circle(iconSize / 2 * 0.9)
            .set("stroke-width", 1);
    me._icon_selected_indicator = me._icon.createChild("path", "radio-button-icon-selected-indicator")
            .circle(iconSize / 2 * 0.7)
            .set("stroke-width", 5);
    me._label = me._root.createChild("richtext")
            .setFont(me._style.getFont("radio-button"))
            .setAlignment("left-center");
  },
  setSize: func(model, w, h) {
    var iconSize = me._style.getSize("radio-button", "icon");
    var fontSize = me._style.getFont("radio-button").size;
    var padding = me._style.getPadding("radio-button");
    me._icon.setTranslation(padding + iconSize / 2, padding + int(h / 2));
    me._label.setTranslation(padding + iconSize + padding, padding + int(h / 2));

    return me;
  },
  setText: func(model, text) {
    me._label.setText(text);

    var iconSize = me._style.getSize("radio-button", "icon");
    var fontSize = me._style.getFont("radio-button").size;
    var padding = me._style.getPadding("radio-button");
    var height = math.max(fontSize, iconSize) + padding * 2;
    var min_width = padding + iconSize + padding + (text ? me._label.width() : 0) + padding;
    model.setLayoutMinimumSize([min_width, height]);
    model.setLayoutSizeHint([min_width, height]);
    model.setLayoutMaximumSize([MAX_SIZE, height]);

    return me;
  },
  update: func(model) {
    var backdrop = !model._windowFocus();

    me._icon_border.set("stroke", me._style.getColor("radio_button_selected_indicator_border_color"));
    if (backdrop) {
      me._label.setColor(me._style.getColor("backdrop_fg_color"));
    } else {
      me._label.setColor(me._style.getColor("fg_color"));
    }

    if (model._checked) {
      me._icon_selected_indicator.show();
    } else {
      me._icon_selected_indicator.hide();
    }

    if (model._enabled) {
      if (model._hover) {
        me._icon_background.set("fill", me._style.getColor("radio_button_selected_indicator_bg_color_hovered"));
      } else {
        me._icon_background.set("fill", me._style.getColor("radio_button_selected_indicator_bg_color"));
      }
      me._icon_selected_indicator.set("stroke", me._style.getColor("radio_button_selected_indicator_color"));
    } else {
      me._icon_background.set("fill", me._style.getColor("radio_button_selected_indicator_bg_color_disabled"));
      me._icon_selected_indicator.set("stroke", me._style.getColor("radio_button_selected_indicator_color_disabled"));
    }
  }
};

# A label
DefaultStyle.widgets.label = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "label");
    me._bg = me._root.createChild("path", "bg")
            .setVisible(0);
    me._img = me._root.createChild("image", "image")
            .set("preserveAspectRatio", "xMidYMid slice")
            .setVisible(0);
    me._text = me._root.createChild("richtext", "text")
            .setFont(me._style.getFont("label"))
            .setAlignment("left-center")
            .setVisible(0);
  },
  setSize: func(model, w, h)
  {
    var fontSize = me._style.getFont("label").size;
    var padding = me._style.getPadding("label");

    me._bg.reset().rect(0, 0, w, h);
    me._img.set("size[0]", w)
             .set("size[1]", h);
    if (model._text_align == "left") {
      me._text.setAlignment("left-center");
      me._text.setTranslation(padding, h / 2);
    } elsif (model._text_align == "center") {
      me._text.setAlignment("center-center");
      me._text.setTranslation(w / 2, h / 2)
    } elsif (model._text_align == "right") {
      me._text.setAlignment("right-center");
      me._text.setTranslation(w - padding, h / 2);
    }
    me._text.setMaxWidth(model._cfg.get("wordWrap", 0) ? (w - padding * 2) : -1);
    return me;
  },
  setText: func(model, text)
  {
    if (!isstr(text) or size(text) == 0) {
      model.setHeightForWidthFunc(nil);
      me._text.setVisible(0);
      return me;
    }

    me._text.setText(text);
    me._text.setVisible(1);

    var hfw_func = nil;

    var fontSize = me._style.getFont("label").size;
    var padding = me._style.getPadding("label");
    var height = fontSize + padding * 2;
    # this implies no clipping of long strings, 
    # which breaks BoxLayout when we overflow.
    # might need to consider an different algorithm in BoxLayout 
    # when min-width is too big
    var min_width = me._text.width() + padding * 2;
    var width_hint = min_width;

    if (model._cfg.get("wordWrap", 0)) {
      var m = me;
      hfw_func = func(w) m.heightForWidth(w);

      # prefer approximately quadratic text blocks
      if( width_hint > 24 )
        width_hint = int(math.sqrt(width_hint * 24));
    }

    model.setHeightForWidthFunc(hfw_func);
    model.setLayoutMinimumSize([min_width, height]);
    model.setLayoutSizeHint([width_hint, height]);
    model.setLayoutMaximumSize([MAX_SIZE, model._cfg.get("wordWrap", 0) ? MAX_SIZE : height]);

    return me.update(model);
  },
  setImage: func(model, img)
  {
    if (img == nil or size(img) == 0) {
      me._img.setVisible(0);
      me._img.clear();
      return me;
    }

    me._img.setVisible(1);
    me._img.set("src", img);
    return me;
  },
  # @description Set or clear the background color == 0 ) of the label
  # @param bg scalar CSS color or 'none'
  setBackground: func(model, bg)
  {
    if (bg == nil or bg == "none") {
      me._bg.setVisible(0);
      return me;
    }

    me._bg.setVisible(1);
    me._bg.set("fill", bg);
    return me;
  },
  setFont: func(model, desc) {
    if (isa(desc, FontDescription)) {
      me._text.setFont(desc);
    } else {
      me._text.setFont(me._style.getFont("default"));
    }
  },
  setColor: func(model, color) {
    if (color == nil) {
      color = me._style.getColor("fg_color");
    }
    me._text.setColor(color);
  },
  heightForWidth: func(w)
  {
    if (!me._text.getVisible()) {
      return -1;
    }

    var fontSize = me._style.getFont("label").size;
    var padding = me._style.getPadding("label");
    if (me._text.lineCount() == 1) {
      return fontSize + 2 * padding;
    }
    return me._text.heightForWidth(w - padding * 2) + padding * 2;
  },
  update: func(model)
  {
    if (me._text.getVisible() and model._color == nil) {
      var color_name = model._windowFocus() ? "fg_color" : "backdrop_fg_color";
      me._text.setColor(me._style.getColor(color_name));
    }
  },
};

# A one line text input field
DefaultStyle.widgets["line-edit"] = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "line-edit");
    me._border = me._root.createChild("image", "border")
            .set("slice", "10 12"); #"7")
    me._placeholder = me._root.createChild("richtext", "placeholder")
            .setFont(me._style.getFont("line-edit-placeholder", me._style.getFont("line-edit")))
            .setAlignment("left-center")
            .set("clip-frame", Element.PARENT);
    me._text = me._root.createChild("richtext", "input")
            .setFont(me._style.getFont("line-edit-text", me._style.getFont("line-edit")))
            .setAlignment("left-center")
            .set("clip-frame", Element.PARENT);

    me._cursor = me._root.createChild("path", "cursor")
            .set("stroke", "#333")
            .set("stroke-width", me._style.getSize("line-edit", "text-cursor-width"));
    me._hscroll = 0;
    me._cursor_blink = 1;
    me._cursor_visible = 0;
    me._cursor_blink_timer = maketimer(0.5, func {
      me._cursor_blink = !me._cursor_blink;
      me._cursor.setVisible(me._cursor_visible and me._cursor_blink);
    });
    me._cursor_blink_timer.simulatedTime = 0;
    me._cursor_blink_timer.start();
  },
  setSize: func(model, w, h)
  {
    var fontSize = me._style.getFont("line-edit-text", me._style.getFont("line-edit")).size;
    var padding = me._style.getPadding("line-edit");

    me._border.setSize(w, h);
    me._placeholder.set(
      "clip",
      "rect(0, " ~ (w - padding) ~ ", " ~ h ~ ", " ~ padding ~ ")"
    );
    me._text.set(
      "clip",
      "rect(0, " ~ (w - padding) ~ ", " ~ h ~ ", " ~ padding ~ ")"
    );
    me._cursor.reset()
            .moveTo(padding, 0)
            .vert(fontSize);
    me._cursor.setDouble("coord[1]", padding);

    return me.update(model);
  },
  setText: func(model, text)
  {
    me._placeholder.setVisible(text or me._cursor_visible ? 0 : 1);
    me._text.setText(text);
    model._onStateChange();
  },
  setPlaceholder: func(model, placeholder)
  {
    me._placeholder.setText(placeholder);
    model._onStateChange();
  },
  _updateLayoutSizes: func(model) {
    var fontSize = me._style.getFont("line-edit-text", me._style.getFont("line-edit")).size;
    var padding = me._style.getPadding("line-edit");
    var height = fontSize + padding * 2;
    model.setLayoutMinimumSize([fontSize * 3 + padding * 2, height]);
    model.setLayoutSizeHint([math.max(me._text.width(), me._placeholder.width()) + padding * 2, height]);
    model.setLayoutMaximumSize([MAX_SIZE, height]);
  },
  update: func(model)
  {
    var fontSize = me._style.getFont("line-edit-text", me._style.getFont("line-edit")).size;
    var padding = me._style.getPadding("line-edit");
    var backdrop = !model._windowFocus();
    var file = me._style._dir_widgets ~ "/";

    if( backdrop )
      file ~= "backdrop-";

    file ~= "entry";

    if( !model._enabled )
      file ~= "-disabled";
    else if( model._focused and !backdrop )
      file ~= "-focused";

    me._border.set("src", file ~ ".png");

    var color_name = backdrop ? "backdrop_fg_color" : "fg_color";
    me._placeholder.setForegroundColor(me._style.getColor((backdrop ? "backdrop_" : "") ~ "placeholder_color"));
    me._text.setForegroundColor(me._style.getColor(color_name));

    me._cursor_visible = model._enabled and model._focused and !backdrop and me._cursor_visible;
    me._cursor.setVisible(me._cursor_visible and me._cursor_blink);

    me._placeholder.setVisible(model._text or me._cursor_visible ? 0 : 1);

    var width = model._size[0] - 2 * padding;
    var cursor_pos = me._text.cursorRect()[0];
    var text_width = me._text.width();

    if( text_width <= width )
      # fit -> align left (TODO handle different alignment)
      me._hscroll = 0;
    else if( me._hscroll + cursor_pos > width )
      # does not fit, cursor to the right
      me._hscroll = width - cursor_pos;
    else if( me._hscroll + cursor_pos < 0 )
      # does not fit, cursor to the left
      me._hscroll = -cursor_pos;
    else if( me._hscroll + text_width < width )
      # does not fit, limit scroll to align with right side
      me._hscroll = width - text_width;

    var text_pos = me._hscroll + padding;

    me._placeholder
      .setTranslation(text_pos, model._size[1] / 2)
      .update();
    me._text
      .setTranslation(text_pos, model._size[1] / 2)
      .update();
    me._cursor
      .setDouble("coord[0]", text_pos + cursor_pos)
      .update();
  }
};

# ScrollArea
DefaultStyle.widgets["scroll-area"] = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "scroll-area");

    me._bg     = me._root.createChild("path", "background")
                         .set("fill", "#e0e0e0");
    me.content = me._root.createChild("group", "scroll-content")
                         .set("clip-frame", Element.PARENT);
    me.vert  = me._newScroll(me._root, "vert");
    me.horiz = me._newScroll(me._root, "horiz");
  },
  setColorBackground: func
  {
    if( size(arg) == 1 )
    	  var arg = arg[0];
    	me._bg.setColorFill(arg);
  },
  update: func(model)
  {
    me.horiz.reset();
    if( model._max_scroll[0] > 1 )
      # only show scroll bar if horizontally scrollable
      me.horiz.moveTo( model._scroller_offset[0] + model._scroller_pos[0],
                       model._size[1] - 2 )
              .horiz(model._scroller_size[0]);

    me.vert.reset();
    if( model._max_scroll[1] > 1 )
      # only show scroll bar if vertically scrollable
      me.vert.moveTo( model._size[0] - 2,
                      model._scroller_offset[1] + model._scroller_pos[1] )
             .vert(model._scroller_size[1]);

    me._bg.reset()
          .rect(0, 0, model._size[0], model._size[1]);
    me.content.set(
      "clip",
      "rect(0, " ~ model._size[0] ~ ", " ~ model._size[1] ~ ", 0)"
    );
  },
# private:
  _newScroll: func(el, orient)
  {
    return el.createChild("path", "scroll-" ~ orient)
             .set("stroke", "#f07845")
             .set("stroke-width", 4);
  },
  # Calculate size and limits of scroller
  #
  # @param model
  # @param dir 0 for horizontal, 1 for vertical
  # @return [scroller_size, min_pos, max_pos]
  _updateScrollMetrics: func(model, dir)
  {
    if( model._content_size[dir] <= model._size[dir] )
      return;

    model._scroller_size[dir] =
      math.max(
        12,
        model._size[dir] * (model._size[dir] / model._content_size[dir])
      );
    model._scroller_offset[dir] = 0;
    model._scroller_delta[dir] = model._size[dir] - model._scroller_size[dir];
  }
};

DefaultStyle.widgets["tab-widget"] = {
	new: func(parent, cfg) {
		me._root = parent.createChild("group", "tab-widget");
		me.bg = me._root.createChild("path", "background")
					.set("fill", "#e0e0e0");
		me.tabBar = me._root.createChild("group", "tab-widget-tabbar");
		me.content = me._root.createChild("group", "tab-widget-content");
	},
	
	update: func(model) {
		me.bg.set("fill", me._style.getColor("bg_color"));
		me.content.setTranslation(0, model._tabBar.minimumSize()[1]);
		me.tabBar.update();
		me.content.update();
	},
	
	setSize: func(model, w, h) {
		me.bg.reset().rect(0, w, h, 0);
	},
};

# Tab button for the tab widget
DefaultStyle.widgets["tab-widget-tab-button"] = {
	new: func(parent, cfg) {
		me._root = parent.createChild("group", "tab-widget-tab-button");
		me._bg = me._root.createChild("path")
						.set("fill", me._style.getColor("tab_widget_tab_button_bg_focused"))
						.set("stroke", me._style.getColor("tab_widget_tab_button_border"))
						.set("stroke-width", 1);
		me._selected_indicator = me._root.createChild("path")
						.set("stroke-width", me._style.getSize("tab-button-selected-indicator-thickness"));
		me._label = me._root.createChild("richtext")
						.setFont(me._style.getFont("tab-widget-tab-button"))
						.setAlignment("center-center");
	},
	
	setSize: func(model, w, h) {
    var closeButtonSize = model._close_button._size;
    var selectedIndicatorThickness = me._style.getSize("tab-button-selected-indicator-thickness");
    var fontSize = me._style.getFont("tab-widget-tab-button").size;
    var padding = me._style.getPadding("tab-widget-tab-button");
 		me._bg.reset().rect(0, 0, w, h);
		me._selected_indicator.reset().moveTo(0, h - selectedIndicatorThickness / 2).horiz(w);
    if (model._tab_closeable) {
  		me._label.setTranslation((w - closeButtonSize[0] - padding) / 2, h / 2);
	  	model._close_button.move(w - closeButtonSize[0] - padding, (h - closeButtonSize[1]) / 2);
    } else {
      me._label.setTranslation(w / 2, h / 2);
    }
	},
	
	setText: func(model, text) {
		me._label.setText(text);

    var closeButtonSize = model._close_button._size;
    var selectedIndicatorThickness = me._style.getSize("tab-button-selected-indicator-thickness");
    var fontSize = me._style.getFont("tab-widget-tab-button").size;
    var padding = me._style.getPadding("tab-widget-tab-button");
    var height = padding * 2;
		var min_width = padding + me._label.width() + padding;
    if (model._tab_closeable) {
      height += math.max(closeButtonSize[1], fontSize);
      min_width += closeButtonSize[0] + padding;
    } else {
      height += fontSize;
    }
		model.setLayoutMinimumSize([min_width, height]);
		model.setLayoutSizeHint([min_width, height]);
    model.setLayoutMaximumSize([min_width, height]);

		return me;
	},
	
	update: func(model) {
		var backdrop = !model._windowFocus();
		var (w, h) = model._size;
		
		var bg_color_name = "tab_widget_tab_button_bg_focused";
		if (backdrop) {
			bg_color_name = "tab_widget_tab_button_bg_unfocused";
		} else if (model._selected) {
			bg_color_name = "tab_widget_tab_button_bg_selected";
		} else if (model._hover) {
			bg_color_name = "tab_widget_tab_button_bg_hovered";
		}
		me._bg.set("fill", me._style.getColor(bg_color_name));
		
		me._selected_indicator.setVisible(model._selected or model._hover);
		var selected_indicator_color_name = "tab_widget_tab_button_selected_indicator_selected";
		if (!model._selected and model._hover) {
			selected_indicator_color_name = "tab_widget_tab_button_selected_indicator_unselected_hovered";
		}
		me._selected_indicator.set("stroke", me._style.getColor(selected_indicator_color_name));

		me._label.setColor(me._style.getColor((backdrop ? "backdrop_" : "") ~ "fg_color"));
	}
};

DefaultStyle.widgets["tab-close-button"] = {
	new: func(parent, cfg) {
    var iconSize = me._style.getSize("tab-close-button", "icon") / 2;
    
		me._root = parent.createChild("group", "tab-close-button");
		me._bg = me._root.createChild("path", "bg");
		me._border = me._root.createChild("image", "button")
						.set("slice", "10 12"); #"7")
		me._cross = me._root.createChild("path", "button-icon")
            .setStrokeLineWidth(me._style.getSize("tab-close-button-cross-thickness"))
            .moveTo(iconSize, iconSize)
            .line(-iconSize, -iconSize)
            .moveTo(iconSize, iconSize)
            .line(iconSize, -iconSize)
            .moveTo(iconSize, iconSize)
            .line(iconSize, iconSize)
            .moveTo(iconSize, iconSize)
            .line(-iconSize, iconSize);
	},
	setText: func {},
	setSize: func(model, w, h) {
    var iconSize = me._style.getSize("tab-close-button", "icon");

		me._bg.reset().rect(0, 0, w, h, {"border-radius": 5});
		me._border.setSize(w, h);
		me._cross.setTranslation((w - iconSize) / 2, (h - iconSize) / 2);
	},
	update: func(model) {
		var backdrop = !model._windowFocus();
		var file = me._style._dir_widgets ~ "/";

		# TODO unify color names with image names
		var bg_color_name = "button_bg_color";
		if (backdrop) {
			bg_color_name = "button_backdrop_bg_color";
		} elsif (model._down) {
			bg_color_name = "button_bg_color_down";
		} elsif (model._hover) {
			bg_color_name = "button_bg_color_hover";
		}
		me._bg.set("fill", me._style.getColor(bg_color_name));

		if (model._hover or model._down) {
			me._cross.set("stroke", me._style.getColor("fg_color"));
			me._border.show();
			me._bg.show();
		} else {
			me._cross.set("stroke", me._style.getColor("backdrop_fg_color"));
			me._border.hide();
			me._bg.hide();
		}
		if (backdrop) {
			file ~= "backdrop-";
		}
		file ~= "button";

		if (model._down) {
			file ~= "-active";
		}

		if (model._focused and !backdrop) {
			file ~= "-focused";
		}
		if (model._hover and !model._down) {
			file ~= "-hover";
		}
		me._border.set("src", file ~ ".png");

    var iconSize = me._style.getSize("tab-close-button", "icon");
    var padding = me._style.getPadding("tab-close-button");
    var size = iconSize + padding * 2;
    model.setLayoutMinimumSize([size, size]);
    model.setLayoutSizeHint([size, size]);
    model.setLayoutMaximumSize([size, size]);
	}
};

# A horizontal or vertical rule line
# possibly with a text label embedded
DefaultStyle.widgets.rule = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "rule");

    me._rule = me._root.createChild("path")
						.set("stroke-width", me._style.getSize("rule-thickness"));
    me._label = me._root.createChild("richtext", "label")
            .setFont(me._style.getFont("rule"))
            .setAlignment("left-center");

    me._isVertical = cfg.get("isVertical", 0);
    if (me._isVertical) {
      me._label.setRotation(90);
    }
  },
  setSize: func(model, w, h)
  {
    var fontSize = me._style.getFont("rule").size;
    var padding = me._style.getPadding("rule");
    var labelOffset = me._style.getSize("rule-label-offset");
    var labelWidth = me._label.width();

    if (me._isVertical ) {
      if (model._text) {
        me._label.setTranslation(w / 2, h - padding - labelOffset - padding);
        me._rule.reset().moveTo(w / 2, h - padding)
                .vert(-labelOffset)
                .move(-labelWidth - padding * 2)
                .vertTo(padding);
      } else {
        me._rule.reset().moveTo(w / 2, h - padding)
                .vertTo(padding);
      }
    } else {
      if (model._text) {
        me._label.setTranslation(padding + labelOffset + padding, h / 2);
        me._rule.reset().moveTo(padding, h / 2)
                .horiz(labelOffset)
                .move(labelWidth + padding * 2, 0)
                .horizTo(w - padding);
      } else {
        me._rule.reset().moveTo(padding, h / 2)
                .horizTo(w - padding);
      }
    }

    return me;
  },

  _updateLayout: func(model)
  {
    var fontSize = me._style.getFont("rule").size;
    var lineThickness = me._style.getSize("rule-thickness");
    var padding = me._style.getPadding("rule");
    var labelOffset = me._style.getSize("rule-label-offset") + padding;
    var labelWidth = me._label.width();

    var width = padding + labelOffset + labelWidth + padding;
    var height = fontSize + padding * 2;
    if (!model._text) {
      height = lineThickness + padding * 2;
    }

    if (me._isVertical) {
      model.setLayoutMinimumSize([height, width]);
      model.setLayoutSizeHint([height, width]);
      model.setLayoutMaximumSize([height, MAX_SIZE]);
    } else {
      model.setLayoutMinimumSize([width, height]);
      model.setLayoutSizeHint([width, height]);
      model.setLayoutMaximumSize([MAX_SIZE, height]);
    }
  },

  setText: func(model, text)
  {
    if (!text) {
      me._label.hide();
    } else {
      me._label.show();
      me._label.setText(text);
    }

    # TODO handle sliding for translations ?
    var maxW = model._cfg.get("maxTextWidth", -1);
    if (maxW > 0) {
      me._label.setMaxWidth(maxW);
    }

    me._updateLayout(model);

    return me.update(model);
  },

  update: func(model)
  {
    # different color if disabled?
    var color_name = model._windowFocus() ? "fg_color" : "backdrop_fg_color";
    me._label.setColor(me._style.getColor(color_name));
    me._rule.setColor(me._style.getColor(color_name));
  },
};

# a frame (sometimes called a group box), with optional label
# and enable/disable checkbox
DefaultStyle.widgets.frame = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "frame-box");
    me._bg = me._root.createChild("bg", "image")
       .set("slice", "8 8");
    me.content = me._root.createChild("group", "frame-content");

    # handle label + checkable flag
  },

  update: func(model)
  {
    var file = me._style._dir_widgets ~ "/";
    file ~= "frame";

#    if( !model._enabled )
 #     file ~= "-disabled";

    me._bg.set("src", file ~ ".png");
    
    me._bg.setSize(model._size[0], model._size[1]);
  },
};

# a horizontal or vertical slider, for selecting /
# dragging over a numerical range
DefaultStyle.widgets.slider = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "slider");
    me._bg = me._root.createChild("image", "bg")
       .set("slice", "2 6");

    me._fill = me._root.createChild("image", "fill")
       .set("slice", "2 6");

    me._ticks = me._root.createChild("path")
            .set("stroke-width", me._style.getSize("slider-ticks-width"));

    me._fillHeight = me._fill.imageSize()[1];
    me._thumb = me._root.createChild("image", "thumb");
    me._thumbSize = me._thumb.imageSize();

    me._value = me._root.createChild("richtext")
            .setFont(me._style.getFont("slider"))
            .setAlignment("center-top");
  },

  _updateLayoutSizes: func(model) 
  {
    var fontSize = me._style.getFont("slider").size;
    var padding = me._style.getPadding("slider");

    # TODO handle vertical sliders in the future

    var h = me._thumbSize[1] + padding * 2;
    if (model._showValue) {
      h += me._style.getFont("slider").size +
               me._style.getSize("slider-thumb-value-margin");
    }
    if (model._showTicks) {
      h += me._style.getSize("slider-fill-ticks-margin") + me._style.getSize("slider-ticks-length");
    } 

    # value of 80 here is based off PUI slider min width in old layout.cxx
    var minSz = [85, h];
    model.setLayoutMinimumSize(minSz);

    # calculate preferred size 
    # disabled becuase using the numerical range for the preferred size works super badly,
    # we have sliders with ranges of eg [-450, 7000]

    model.setLayoutSizeHint([240, h]);
    model.setLayoutMaximumSize([MAX_SIZE, h]);
  },

  setNormValue: func(model, normValue)
  {
    var valueFontSize = me._style.getFont("slider").size;
    var padding = me._style.getPadding("slider");
    var w = model._size[0];
    var halfThumbWidth = me._thumbSize[0] * 0.5;
    var availWidthPos = w - me._thumbSize[0] - padding * 2;
    var thumbX = padding + math.round(availWidthPos * normValue);

    var valueX = 0;
    if (model._showValue) {
      var startPos = padding + me._value.width() / 2;
      var thumbPos = thumbX + me._thumbSize[0] * 0.5;
      var endPos = w - startPos;
      valueX = math.clamp(thumbPos, startPos, endPos);
    }
    me._value.setTranslation(valueX, me._value.getTranslation()[1]);
    me._thumb.setTranslation(thumbX, me._thumb.getTranslation()[1]);
    me._fill.setSize(thumbX, me._fillHeight);
    me._value.setText(model._value);
  },

  update: func(model)
  {
    var direction = "horizontal";
  # set background state
    var file = me._style._dir_widgets ~ "/";
    file ~= "scale-" ~ direction ~ "-trough";
    if( !model._enabled )
      file ~= "-disabled";

    me._bg.set("src", file ~ ".png");
    
  # fill state
    var file = me._style._dir_widgets ~ "/";
    file ~= "scale-" ~ direction ~ "-fill";
    if( !model._enabled ) {
      file ~= "-disabled";
    } else {
 
    }

    me._fill.set("src", file ~ ".png");
    me._fillHeight = me._fill.imageSize()[1];

  # set thumb state
    file = me._style._dir_widgets ~ "/";
    file ~= "slider-" ~ direction;  
    if( !model._enabled ) {
      file ~= "-disabled";
    } else {
      if (model._thumbDown)
        file ~= "-focused";
      if (model._hover)
        file ~= "-hover";
    }

    me._thumb.set("src", file ~ ".png");
    me._thumbSize = me._thumb.imageSize();
    
    var color_name = model._windowFocus() ? "fg_color" : "backdrop_fg_color";
    me._value.setColor(me._style.getColor(color_name));
    if (model._showValue) {
      me._value.show();
    } else {
      me._value.hide();
    }
    
    me._ticks.set("stroke", me._style.getColor("slider_ticks"));
    if (model._showTicks) {
      me._ticks.show();
    } else {
      me._ticks.hide();
    }

    # update the position as well, since other stuff
    # may have changed
    me.setNormValue(model, model._normValue());
  },

  setSize: func(model, w, h)
  {
    var valueFontSize = me._style.getFont("slider").size;
    var padding = me._style.getPadding("slider");
    var thumbValueMargin = me._style.getSize("slider-thumb-value-margin");
    var fillTicksMargin = me._style.getSize("slider-fill-ticks-margin");
    var ticksOffset = fillTicksMargin + me._style.getSize("slider-ticks-length");

    var thumbY = padding;
    var valueY = thumbY;
    if (model._showValue) {
      thumbY += valueFontSize + thumbValueMargin;
    }

    var fillY = thumbY + (me._thumbSize[1] - me._fillHeight) * 0.5;

    var ticksY = fillY;
    if (model._showTicks) {
      ticksY += me._fillHeight + fillTicksMargin;
    }

    me._bg.setTranslation(padding + me._thumbSize[0] / 2, fillY);
    me._fill.setTranslation(padding + me._thumbSize[0] / 2, fillY);
    me._ticks.setTranslation(padding + me._thumbSize[0] / 2, ticksY);
    me._thumb.setTranslation(me._thumb.getTranslation()[0], thumbY);
    me._value.setTranslation(me._value.getTranslation()[0], valueY);
    me._bg.setSize(w - me._thumbSize[0] - padding * 2, me._fillHeight);
    me.setNormValue(model, model._normValue());
    me._drawTicks(model);
  },

  _drawTicks: func(model) {
    if (!model._showTicks) {
      return;
    }
    me._ticks.reset();
    var range = model._maxValue - model._minValue;
    if (range <= 0 or model._tickStep <= 0) {
      return;
    }
    var availWidthPos = model._size[0] - me._thumbSize[0];
    var pixelsPerUnit = availWidthPos / range;
    var remainder = math.mod(range, model._tickStep);
    var numTicks = int((range - remainder) / model._tickStep);
    if (remainder == 0) {
      numTicks -= 1;
    }
    for (var i = 1; i <= numTicks; i += 1) {
      me._ticks.moveTo(i * pixelsPerUnit * model._tickStep, 0)
                       .vert(me._style.getSize("slider-ticks-length"));
    }
  },
};

DefaultStyle.widgets.dial = {
  new: func(parent, cfg) {
    me._root = parent.createChild("group", "dial");
    me._knob = me._root.createChild("path", "dial-knob");
    me._handle = me._root.createChild("image", "dial-handle");
    me._handleTranslateTransform = me._handle.createTransform();
    me._value = me._root.createChild("richtext", "dial-value")
            .setFont(me._style.getFont("dial"))
            .setAlignment("center-center")
            .setText(0);
    me._ticks = me._root.createChild("path", "dial-ticks");

    me._maxValueWidth = 20;
  },

  _updateLayoutSizes: func(model) {
    var handleSize = me._handle.imageSize()[1];
    var borderHandleMargin = math.clamp(
      math.min(model._size[0], model._size[1]) * 0.0625,
      2,
      me._style.getSize("dial-border-handle-margin"),
    );
    var valueSize = [0, 0];
    var valueHandleMargin = me._style.getSize("dial-value-handle-margin");
    if (model._showValue) {
      valueSize = [
        me._maxValueWidth + valueHandleMargin * 2,
        me._style.getFont("dial").size + valueHandleMargin * 2
      ];
    } else {
      valueSize = me._style.getSize("dial-center-handle-margin") * 2;
      valueSize = [valueSize, valueSize];
    }
    var minW = borderHandleMargin * 2 + valueSize[0] + handleSize * 2;
    var minH = borderHandleMargin * 2 + valueSize[1] + handleSize * 2;
    var length = math.max(minW, minH);
    if (model._showTicks) {
      length += me._style.getSize("dial-knob-ticks-margin") + me._style.getSize("dial-ticks-length");
    }
    model.setLayoutMinimumSize([length, length]);
  },

  setSize: func(model, length) {
    var knobTicksMargin = me._style.getSize("dial-knob-ticks-margin");
    var ticksLength = me._style.getSize("dial-ticks-length");
    var knobRadius = (length - me._style.getSize("dial-knob-border-width")) / 2;
    var halfLength = length / 2;
    if (model._showTicks) {
      knobRadius -= knobTicksMargin + ticksLength;
    }
    me._knob.reset()
            .circle(knobRadius, halfLength, halfLength);
    me._value.setTranslation(
      halfLength,
      halfLength
    );
    var handleOffset = [
      halfLength - me._handle.imageSize()[0] / 2,
      math.clamp(knobRadius * 0.125, 2, me._style.getSize("dial-border-handle-margin"))
    ];
    if (model._showTicks) {
      handleOffset[1] += knobTicksMargin + ticksLength;
    }
    me._handleTranslateTransform.setTranslation(handleOffset[0], handleOffset[1]);
    me._handle.setCenter(
      me._handle.imageSize()[0] / 2,
      halfLength - handleOffset[1]
    );
    var degreesRange = 360;
    var nowrapMargin = me._style.getSize("dial-nowrap-margin-deg"); 
    var offset = 0;
    if (!model._wraps) {
      degreesRange -= nowrapMargin;
      offset = nowrapMargin / 2;
    }
    me._handle.setRotation((model._normValue() * degreesRange + offset) * D2R); 
    me._drawTicks(model);
  },

  _drawTicks: func(model) {
    var length = math.min(model._size[0], model._size[1]);
    var halfLength = length / 2;
    var knobTicksMargin = me._style.getSize("dial-knob-ticks-margin");
    var ticksLength = me._style.getSize("dial-ticks-length");
    var knobRadius = (length - me._style.getSize("dial-knob-border-width")) / 2 - knobTicksMargin - ticksLength;
    
    var degreesRange = 360;
    var nowrapMargin = me._style.getSize("dial-nowrap-margin-deg");
    var offset = 0;
    if (!model._wraps) {
      degreesRange -= nowrapMargin;
      offset = nowrapMargin / 2;
    }
    var range = model._maxValue - model._minValue;
    var center = [halfLength, halfLength];
    var degreesPerTickStep = (degreesRange / range) * model._tickStep;
    var lengthBegin = knobRadius + knobTicksMargin;
    var lengthEnd = lengthBegin + ticksLength;
    me._ticks.reset();

    for (var i = 0; i < degreesRange / degreesPerTickStep; i += 1) {
      var radians = (i * degreesPerTickStep + offset) * D2R;
      var sin = math.sin(radians);
      var cos = -math.cos(radians);
      var start = [center[0] + sin * lengthBegin, center[1] + cos * lengthBegin];
      var tick = [center[0] + sin * lengthEnd, center[1] + cos * lengthEnd];
      me._ticks.moveTo(start[0], start[1]).lineTo(tick[0], tick[1]);
    }
  },

  _updateMaxValueWidth: func(model) {
    if (model._valueFormat != nil) {
      me._value.setText(sprintf(model._valueFormat, model._minValue));
      var min = me._value.width();
      me._value.setText(sprintf(model._valueFormat, model._maxValue));
      var max = me._value.width();
      me._value.setText(sprintf(model._valueFormat, model._minValue + model._stepSize));
      var minStep = me._value.width();
      me._value.setText(sprintf(model._valueFormat, model._value));
    } else {
      me._value.setText(model._minValue);
      var min = me._value.width();
      me._value.setText(model._maxValue);
      var max = me._value.width();
      me._value.setText(model._minValue + model._stepSize);
      var minStep = me._value.width();
      me._value.setText(model._value);
    }
    me._maxValueWidth = math.max(min, max, minStep);
  },

  setValue: func(model, value) {
    var degreesRange = 360;
    var nowrapMargin = me._style.getSize("dial-nowrap-margin-deg"); 
    var offset = 0;
    if (!model._wraps) {
      degreesRange -= nowrapMargin;
      offset = nowrapMargin / 2;
    }
    me._handle.setRotation((model._normValue() * degreesRange + offset) * D2R);
    if (model._valueFormat != nil) {
      me._value.setText(sprintf(model._valueFormat, value));
    } else {
      me._value.setText(value);
    }
  },

  update: func(model) {
    var color_name = model._windowFocus() ? "fg_color" : "backdrop_fg_color";
    me._value.setColor(me._style.getColor(color_name));

    color_name = "dial_knob_bg";
    if (!model._enabled) {
      color_name ~= "_disabled";
    } elsif (model._focused and model._windowFocus()) {
      color_name ~= "_focused";
    } elsif (!model._windowFocus()) {
      color_name ~= "_backdrop";
    }
    if (model._hover and model._enabled and model._windowFocus()) {
      color_name ~= "_hovered";
    }
    me._knob.set("fill", me._style.getColor(color_name));
    
    color_name = "dial_knob_border";
    if (!model._enabled) {
      color_name ~= "_disabled";
    } elsif (model._focused and model._windowFocus()) {
      color_name ~= "_focused";
    }
    if (model._hover and model._enabled and model._windowFocus()) {
      color_name ~= "_hovered";
    }
    me._knob.set("stroke", me._style.getColor(color_name));
    
    var file = me._style._dir_widgets ~ "/dial-handle";
    if (!model._enabled) {
      file ~= "-disabled";
    } elsif (model._handleDown) {
      file ~= "-down";
    }
    me._handle.set("src", file ~ ".png");

    me._ticks.set("stroke", me._style.getColor("dial_ticks"));

    if (model._showValue) {
      me._value.show();
    } else {
      me._value.hide();
    }
    if (model._showTicks) {
      me._ticks.show();
    } else {
      me._ticks.hide();
    }
  }
};

DefaultStyle.widgets["menu-item"] = {
	new: func(parent, cfg) {
		me._root = parent.createChild("group", "menu-item");
		me._bg = me._root.createChild("path");
		
		me._icon = me._root.createChild("image");
		
    me._label = me._root.createChild("richtext")
						.setFont(me._style.getFont("menu-item"))
						.setAlignment("left-center");
		
		me._shortcut = me._root.createChild("richtext")
						.setFont(me._style.getFont("menu-item-shortcut"))
						.setAlignment("right-center");
		
    var iconSize = me._style.getSize("menu-item-submenu", "icon");
		me._submenu_indicator = me._root.createChild("path")
						.moveTo(iconSize * 0.25, 0)
            .line(iconSize * 0.75, iconSize * 0.5)
            .line(iconSize * 0.25, iconSize);
	},
	
	setSize: func(model, w, h) {
		me._bg.reset().rect(0, 0, w, h);
    # allow different font for the shortcut (e.g. bold) but inherit from the menu-item font if defined instead of the global default font directly
    var fontSize = math.max(me._style.getFont("menu-item").size, me._style.getFont("menu-item-shortcut", me._style.getFont("menu-item")).size);
    var padding = me._style.getPadding("menu-item");
    var iconSize = me._style.getSize("menu-item", "icon");
    var submenuIconSize = me._style.getSize("menu-item-submenu", "icon");
		var offset = padding;
		if (!model._is_menubar_item) {
			offset += iconSize + padding;
		}
		me._icon.setTranslation(padding, int((h - iconSize) / 2));
		me._label.setTranslation(offset, int(h / 2));
		me._shortcut.setTranslation(w - padding - submenuIconSize - padding, int(h / 2));
		me._submenu_indicator.setTranslation(w - padding, int((h - 12) / 2));
		return me;
	},
	
	_updateLayoutSizes: func(model) {
    # allow different font for the shortcut (e.g. bold) but inherit from the menu-item font if defined instead of the global default font directly
    var fontSize = math.max(me._style.getFont("menu-item").size, me._style.getFont("menu-item-shortcut", me._style.getFont("menu-item")).size);
    var padding = me._style.getPadding("menu-item");
    var iconSize = me._style.getSize("menu-item", "icon");
    var submenuIconSize = me._style.getSize("menu-item-submenu", "icon");
    var height = math.max(fontSize, iconSize, submenuIconSize) + padding * 2;

		var min_width = padding + me._label.width() + padding;
		if (!model._is_menubar_item) {
			# add icon space
			min_width += iconSize + padding;
			# add shortcut space
			min_width += me._shortcut.width() + padding;
      # add submenu indicator space
      min_width += submenuIconSize + padding;
		}
		model.setLayoutMinimumSize([min_width, height]);
		model.setLayoutSizeHint([min_width, height]);
    model.setLayoutMaximumSize([MAX_SIZE, height]);
		
		return me;
	},
	
	setText: func(model, text) {
		me._label.setText(text);
		return me._updateLayoutSizes(model);
	},

	setShortcut: func(model, shortcut) {
		if (shortcut != nil) {
			me._shortcut.setText(shortcut);
		}
		return me._updateLayoutSizes(model);
	},
	
	setIcon: func(model, icon) {
		if (!icon) {
			me._icon.hide();
		} else {
			me._icon.show();
			var file = me._style._dir_widgets ~ "/" ~ icon;
			me._icon.set("src", file);
		}
		return me;
	},
	
	update: func(model) {
		me._bg.set("fill", me._style.getColor("menu_item_bg" ~ (model._hovered ? "_hovered" : "")));
		var text_color_name = "menu_item_fg";
		if (model._hovered) {
			text_color_name ~= "_hovered";
		} else if (!model._enabled) {
			text_color_name ~= "_disabled";
		}
		me._label.setColor(me._style.getColor(text_color_name));
		me._shortcut.setColor(me._style.getColor(text_color_name));
		me._submenu_indicator.setStroke(me._style.getColor("menu_item_submenu_indicator" ~ (model._hovered ? "_hovered" : "")));
		if (model._menu != nil) {
			if (!model._is_menubar_item) {
				me._submenu_indicator.show();
			}
			me._shortcut.hide();
		} else {
			me._submenu_indicator.hide();
			me._shortcut.show();
		}
		
		return me;
	}
};

DefaultStyle.widgets["menu-bar"] = {
	new: func(parent, cfg) {
		me._root = parent.createChild("group", "menu-bar");
		me._bg = me._root.createChild("path");
		me._items = me._root.createChild("group", "menu-bar-items");
	},
	
	setSize: func(model, w, h) {
		me._bg.reset().rect(0, 0, w, h);
		me._items.setTranslation(0, 0);
		return me;
	},
	
	update: func(model) {
		me._bg.set("fill", me._style.getColor("bg_color"));
		
		return me;
	}
};

# A combo-box
DefaultStyle.widgets["combo-box"] = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "combo-box");
    me._bg = me._root.createChild("path");
    me._border = me._root.createChild("image", "border")
              .set("slice", "10 6"); #"7")
    me._buttonBorder = me._root.createChild("image", "border-button")
              .set("slice", "10 6"); #"7")
    me._arrowIcon = me._root.createChild("image", "arrow");
    me._label = me._root.createChild("richtext")
              .setFont(me._style.getFont("combo-box"))
              .setAlignment("left-center");

    me._maxItemWidth = nil;
  },
  setSize: func(model, w, h)
  {
    var halfWidth = int(w * 0.5);
    var fontSize = me._style.getFont("combo-box").size;
    var padding = me._style.getPadding("combo-box");
    var iconSize = me._style.getSize("combo-box", "icon");

    me._bg.reset()
            .rect(0, 0, w, h, {"border-radius": me._style.getSize("frame-radius")});

    # we split the two pieces
    me._border.setSize(halfWidth, h);
    me._buttonBorder.setTranslation(halfWidth, 0);
    me._buttonBorder.setSize(w - halfWidth, h);

    me._arrowIcon.setSize(iconSize, iconSize);
    me._arrowIcon.setTranslation(w - (iconSize + padding), (h - iconSize) * 0.5);

    me._label.setTranslation(padding, h * 0.5);
  },
  setText: func(model, text)
  {
    me._label.setText(text);

    var fontSize = me._style.getFont("combo-box").size;
    var padding = me._style.getPadding("combo-box");
    var iconSize = me._style.getSize("combo-box", "icon");
    var textWidth = me._label.width();
    if (me._maxItemWidth == nil) {
      me._maxItemWidth = me._getMaxWidthItem(model);
    }
    var width = math.max(
      me._maxItemWidth,
      padding + textWidth + padding + iconSize + padding
    );
    var height = math.max(fontSize, iconSize) + padding * 2;
    model.setLayoutMinimumSize([width, height]);
    model.setLayoutSizeHint([width, height]);
    model.setLayoutMaximumSize([MAX_SIZE, height]);

    return me;
  },
  update: func(model)
  {
    var backdrop = !model._windowFocus();
    var file = me._style._dir_widgets ~ "/";

    # TODO unify color names with image names
    var bg_color_name = "button_bg_color";
    if( backdrop )
      bg_color_name = "button_backdrop_bg_color";
    else if( !model._enabled )
      bg_color_name = "button_bg_color_insensitive";
    else if( model._down )
      bg_color_name = "button_bg_color_down";
    else if( model._hover )
      bg_color_name = "button_bg_color_hover";
    me._bg.set("fill", me._style.getColor(bg_color_name));

    var arrowIconFile = file ~ "combobox-arrow";

    if( backdrop )
    {
      file ~= "backdrop-";
      me._label.setColor(me._style.getColor("backdrop_fg_color"));
    }
    else
      me._label.setColor(me._style.getColor("fg_color"));
    file ~= "combobox";

    var buttonFile = file ~ "-button";
    file ~= "-entry";

    var suffix = "";
    if( model._down )
    { # no pressed image for the left half
      buttonFile ~= "-pressed";
    }

    if( model._enabled ) {
      if( model._focused and !backdrop )
        suffix ~= "-focused";
    } else {
      suffix ~= "-disabled";
      arrowIconFile ~= "-disabled";
    }

    me._border.set("src", file ~ suffix ~ ".png");
    me._buttonBorder.set("src", buttonFile ~ suffix ~ ".png");
    me._arrowIcon.set("src", arrowIconFile ~ ".png");
  },

  # Calculate how many pixels the longest text in the list has.
  _getMaxWidthItem: func(model) {
    var maxItemWidth = 0;
    foreach (var menuItem; model._items) {
      var itemWidth = menuItem.minimumSize()[0];
      if (itemWidth > maxItemWidth) {
        maxItemWidth = itemWidth;
      }
    }

    return maxItemWidth;
  },

  # Set me._maxItemWidth to nil for recalculate it.
  _resetMaxItemWidth: func() {
    me._maxItemWidth = nil;
  },
};

DefaultStyle.widgets["list-item"] = {
	new: func(parent, cfg) {
		me._root = parent.createChild("group", "list-item");
		me._bg = me._root.createChild("path");

		me._label = me._root.createChild("richtext")
						.setFont(me._style.getFont("list-item"))
						.setAlignment("left-center");
	},
	
	setSize: func(model, w, h) {
    var fontSize = me._style.getFont("list-item").size;
    var padding = me._style.getPadding("list-item");
		me._bg.reset().rect(0, 0, w, h);
		me._label.setTranslation(padding, h / 2);
		return me;
	},
	
	_updateLayoutSizes: func(model) {
    var fontSize = me._style.getFont("list-item").size;
    var padding = me._style.getPadding("list-item");
		var min_width = padding + me._label.width() + padding;
    var height = fontSize + padding * 2;
		model.setLayoutMinimumSize([min_width, height]);
		model.setLayoutSizeHint([min_width, height]);
    model.setLayoutMaximumSize([MAX_SIZE, height]);
		
		return me;
	},
	
	setText: func(model, text) {
		me._label.setText(text);
		return me._updateLayoutSizes(model);
	},
	
	update: func(model) {
		me._bg.set("fill", me._style.getColor("list_item_bg" ~ (model._selected ? "_selected" : "")));
		var text_color_name = "list_item_fg";
		if (model._selected) {
			text_color_name ~= "_selected";
		}
		me._label.setColor(me._style.getColor(text_color_name));
		
		return me;
	}
};

DefaultStyle.widgets.list = {
	new: func(parent, cfg) {
		me._root = parent.createChild("group", "list");
		me._bg = me._root.createChild("path");
	},
	
	setSize: func(model, w, h) {
		me._bg.reset().rect(0, 0, w, h);
		return me;
	},
	
	update: func(model) {
		me._bg.set("fill", me._style.getColor("bg_color"));
		
		return me;
	},
};

# A label
DefaultStyle.widgets["text-box"] = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "label");
    me._bg = me._root.createChild("path", "bg")
            .setVisible(0);
    me._text = me._root.createChild("richtext", "text")
            .setFont(me._style.getFont("text-box"));
  },
  setSize: func(model, w, h)
  {
    var fontSize = me._style.getFont("text-box").size;
    var padding = me._style.getPadding("text-box");
    me._bg.reset().rect(0, 0, w, h);
    if (model._text_align == "left") {
      me._text.setAlignment("left-top");
      me._text.setTranslation(padding, padding);
    } elsif (model._text_align == "center") {
      me._text.setAlignment("center-top");
      me._text.setTranslation(w / 2, padding)
    } elsif (model._text_align == "right") {
      me._text.setAlignment("right-top");
      me._text.setTranslation(w - padding, padding);
    }

    # always word-wrap
    me._text.setMaxWidth(w - padding * 2);
    return me;
  },
  setText: func(model, text)
  {
    if (!isstr(text) or size(text) == 0) {
      model.setHeightForWidthFunc(nil);
      me._text.setVisible(0);
      return me;
    }

    me._text.setText(text);
    me._text.setVisible(1);

    var m = me;
    var hfw_func = func(w) m.heightForWidth(w);
    var min_width = 32;

    var fontSize = me._style.getFont("text-box").size;
    var padding = me._style.getPadding("text-box");
    var height = fontSize + padding * 2;

    # prefer approximately quadratic text blocks
    var width_hint = me._text.width() + padding * 2;
    width_hint = int(math.sqrt(width_hint * 24));

    model.setHeightForWidthFunc(hfw_func);
    model.setLayoutMinimumSize([min_width, height]);
    model.setLayoutSizeHint([width_hint, height]);

    return me.update(model);
  },
  # @description Set or clear the background color
  # @param bg scalar CSS color or 'none'
  setBackground: func(model, bg)
  {
    if (bg == nil or bg == "none") {
      me._bg.setVisible(0);
      return me;
    }

    me._bg.setVisible(1);
    me._bg.set("fill", bg);
    return me;
  },
  setFont: func(model, desc) {
    if (desc != nil) {
      me._text.setFont(path);
    } else {
      me._text.setFont(me._style.getFont("default"));
    }
  },
  setColor: func(model, color) {
    if (color == nil) {
      color = me._style.getColor("fg_color");
    }
    me._text.setColor(color);
  },
  heightForWidth: func(w)
  {
    if (!me._text.getVisible()) {
      return -1;
    }

    var fontSize = me._style.getFont("text-box").size;
    var padding = me._style.getPadding("text-box");
    return me._text.heightForWidth(w - padding * 2);
  },
  update: func(model)
  {
    if (me._text.getVisible() and model._color == nil) {
      var color_name = model._windowFocus() ? "fg_color" : "backdrop_fg_color";
      me._text.setColor(me._style.getColor(color_name));
    }
  },
};
