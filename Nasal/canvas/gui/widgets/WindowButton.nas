# WindowButton.nas - implementation for various window title bar buttons
# Copyright 2025 - 2025 Frederic Türpe
# SPDX-License-Identifier: GPL-3.0-or-later

gui.widgets.WindowButton = {
  _CLASS: "WindowButton",

  new: func(parent, style = nil, cfg = nil)
  {
    cfg = Config.new(cfg);
    cfg.set("flat", 1);
    cfg.set("type", "window-button");
    cfg.set("fixed-size", [19, 19]);
    var m = gui.widgets.Button.new(parent, style, cfg);
    m.parents = [gui.widgets.WindowButton] ~ m.parents;
    m._focus_policy = m.NoFocus;

    return m;
  },
};

