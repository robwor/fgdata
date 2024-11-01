# Rule.nas : horizontal or vertical dividing line,
# optionally with a text label, eg to name a section
# SPDX-FileCopyrightText: (C) 2022 James Turner <james@flightgear.org>
# SPDX-License-Identifier: GPL-2.0-or-later


gui.widgets.HorizontalRule = {
  _CLASS: "HorizontalRule",

  new: func(parent, style = nil, cfg = nil)
  {
    style = style or canvas.style;
    cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.HorizontalRule, cfg);
    m._focus_policy = m.NoFocus;
    m._setView( style.createWidget(parent, "rule", m._cfg) );

# should ask Style the rule height, not hard-code 1px
    m.setLayoutMinimumSize([16, 2]);
    m.setLayoutSizeHint([m._MAX_SIZE, 2]); # expand to fill
    m.setLayoutMaximumSize([m._MAX_SIZE, 2]);

    m.setText(m._cfg.get("text", ""));
    return m;
  },
  setText: func(text)
  {
    me._view.setText(me, text);
    return me;
  }
};

gui.widgets.VerticalRule = {
  _CLASS: "VerticalRule",

  new: func(parent, style = nil, cfg = nil)
  {
    style = style or canvas.style;
    cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.VerticalRule, cfg);
    m._focus_policy = m.NoFocus;
    m._setView( style.createWidget(parent, "rule", m._cfg) );

# should ask Style the rule height, not hard-code 1px
    m.setLayoutMinimumSize([2, 16]);
    m.setLayoutSizeHint([2, m._MAX_SIZE]); # expand to fill
    m.setLayoutMaximumSize([2, m._MAX_SIZE]);

    m.setText(m._cfg.get("text", ""));
    return m;
  },
  setText: func(text)
  {
    me._view.setText(me, text);
    return me;
  }
};
