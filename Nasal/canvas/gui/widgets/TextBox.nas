# SPDX-FileCopyrightText: (C) 2025 James Turner <james@flightgear.org>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.TextBox = {
  _CLASS: "TextBox",

  new: func(parent, style = nil, cfg = nil)
  {
    style = style or canvas.style;
    cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.TextBox, cfg);
    m._color = nil;
    m._focus_policy = m.NoFocus;
    m._setView( style.createWidget(parent, "text-box", m._cfg) );

    m.setText(m._cfg.get("text", ""));
    m.setTextAlign(m._cfg.get("text-align", "left"));
    m.setColor(m._cfg.get("color"));
    m.setFont(m._cfg.get("font"));

    return m;
  },

  # @description Set font for this label
  # @param path Optional[str] Path to font file relative to $FGDATA/Fonts, or nil to use the style's default font
  setFont: func(path = nil) {
    me._font = path;
    if (me._view != nil) {
      me._view.setFont(me, path);
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
  setBackground: func(bg)
  {
    me._bg = bg;
    if (me._view != nil) {
      me._view.setBackground(me, bg);
    }
    return me;
  }
};
