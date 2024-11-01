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
    if (var color = m._cfg.get("color")) {
      m.setColor(color);
    }

    return m;
  },
  setColor: func(color) {
    var type = typeof(color);
    if (color == nil or type == "scalar") {
      me._color = color;
    } elsif (type == "vector") {
      me._color = canvas._getColor(color);
    } else {
      die("canvas.gui.widgets.Label.setColor: 'color' is of unsupported type '" ~ type ~ "'");
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
    if (me._view != nil) {
      me._view.setText(me, text);
    }
    return me;
  },
  setImage: func(img)
  {
    if (me._view != nil) {
      me._view.setImage(me, img);
    }
    return me;
  },
  setBackground: func(bg)
  {
    if (me._view != nil) {
      me._view.setBackground(me, bg);
    }
    return me;
  }
};
