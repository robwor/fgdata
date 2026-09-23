# SPDX-FileCopyrightText: (C) 2022 James Turner <james@flightgear.org>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.Label = {
  _CLASS: "Label",

  new: func(parent, style = nil, cfg = nil)
  {
    style = style or canvas.style;
    cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.Label, cfg);
    m._color = nil;
    m._wrapMode = "none";
    m._focus_policy = m.NoFocus;
    m._setView(style.createWidget(parent, "label", m._cfg));

    m.setText(m._cfg.get("text", ""));
    var markup = m._cfg.get("markup", "");
    if (markup) {
      m.setMarkup(markup);
    }
    m.setTextAlign(m._cfg.get("text-align", "left"));
    m.setFormat(m._cfg.get("format"));
    m.setValue(m._cfg.get("value"));
    m.setColor(m._cfg.get("color"));
    m.setFont(m._cfg.get("font"));
    m.setWrapMode(m._cfg.get("wrap-mode", "none"));
    if (m._cfg.get("wordWrap", 0)) {
      debug.warn("Deprecated usage of wordWrap configuration keyword for canvas.gui.widgets.Label - please use \"wrap-mode\": \"word\" instead");
      m.setWrapMode("word");
    }

    return m;
  },
  setFormat: func(format) {
    me._format = format;
  },
  setValue: func(value...) {
    if (typeof(value) == "vector" and size(value) == 1) {
      value = value[0];
    }
    if (value == nil or !me._format) {
      return;
    }
    me._value = value;
    me.setText(sprintf(me._format, value));
  },
  # @brief Set font for this label
  # @param desc Optional[canvas.FontDescription] A canvas.FontDescription, or nil to use the style's default font
  setFont: func(desc = nil) {
    me._font = desc;
    if (me._view != nil) {
      me._view.setFont(me, desc);
    }
  },
  # @brief Set text wrapping mode
  # @param mode String One of none, word, char, word-char.
  setWrapMode: func(mode) {
    me._wrapMode = mode;
    if (me._view != nil) {
      me._view.setWrapMode(me, mode);
    }
  },
  setColor: func(color) {
    if (color == nil) {
      me._color = nil;
    } else {
      me._color = canvas._getColor(color);
    }
    if (me._view != nil) {
      me._view.setColor(me, me._color);
    }
  },
  setTextAlign: func(align) {
    me._text_align = align;
    if (me._view != nil) {
      me._view.setSize(me, me._size[0], me._size[1]);
    }
  },
  setText: func(text)
  {
    me._text = text;
    if (me._view != nil) {
      me._view.setText(me, text);
    }
    return me;
  },
  setMarkup: func(markup) {
    me._markup = markup;
    if (me._view != nil) {
      me._view.setMarkup(me, markup);
    }
    return me;
  },
  setImage: func(img)
  {
    me._img = img;
    if (me._view != nil) {
      me._view.setImage(me, img);
    }
    return me;
  },
  setBackground: func(bg)
  {
    me._bg = bg;
    if (me._view != nil) {
      me._view.setBackground(me, bg);
    }
    return me;
  }
};
