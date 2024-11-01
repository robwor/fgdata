gui.widgets.Switch = {
        _CLASS: "Switch",

        new: func(parent, style = nil, cfg = nil) {
                cfg = Config.new(cfg);
                cfg.set("type", "switch");
                var m = gui.widgets.Button.new(parent, style, cfg);
                m._checkable = 1;

                append(m.parents, gui.widgets.Switch);

                m.setFixedSize(48, 24);
                return m;
        },
        setCheckable: nil,
        setText: nil,
};
