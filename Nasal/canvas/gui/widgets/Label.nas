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
    m._focus_policy = m.NoFocus;
    m._setView( style.createWidget(parent, "label", m._cfg) );

    m.setText(m._cfg.get("text", ""));
    m.setTextAlign(m._cfg.get("text-align", "left"));
    m.setFormat(m._cfg.get("format"));
    m.setValue(m._cfg.get("value"));
    m.setColor(m._cfg.get("color"));
    m.setFont(m._cfg.get("font"));

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
