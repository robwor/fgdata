# ListView.nas - a virtual list view backed by C++ NasalItemView

# SPDX-FileCopyrightText: (C) 2025 James Turner
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.ListView = {
    _CLASS: "ListView",

    new: func(parent, style = nil, cfg = nil) {
        style = style or canvas.style;
        cfg = Config.new(cfg);
        var m = gui.Widget.new(gui.widgets.ListView, cfg);
        m._focus_policy = m.NoFocus;
        m._style = style;
        m._viewOffset = 0;
        m._selectedIndex = -1;
        m._delegateHeight = cfg.get("delegate-height", 28);
        m._activeDelegates = [];   # all-time list; entries with _model==nil are unbound

        m._setView(style.createWidget(parent, "list", m._cfg));

        m._scroll = gui.widgets.ScrollArea.new(m._view._root, style, {});
        m._contentGroup = m._scroll.getContent();

        # Peer object passed to C++ NasalItemView.  C++ calls its methods for
        # delegate lifecycle and model change notifications.
        var controller = { parents: [] };
        controller.createDelegate     = func() { return m._createDelegate(); };
        controller.modelReset         = func() { m._onModelReset(); };
        controller.visibleRowsChanged = func() { m._onVisibleRowsChanged(); };
        controller.scrollBarChanged   = func() { m._onScrollBarChanged(); };

        # Create the C++ NasalItemView ghost; peer is 'controller'.
        m._itemView = globals.gui.ItemView.new(controller, nil);
        m._itemView.delegateHeight = m._delegateHeight;
        m._itemView.cacheHeight    = 256;

        m.setLayoutMinimumSize([80, 48]);
        m.setExpanding(gui.Widget.Expanding);

        return m;
    },

    # Set or replace the data model.
    setModel: func(model) {
        me._itemView.model = model;
        return me;
    },

    # Widget sizing called by the layout engine.
    setSize: func {
        if (size(arg) == 1) var arg = arg[0];
        var (w,h) = arg;

        logprint(LOG_INFO, "List view size:" ~ w ~ "," ~ h );
        me._size = [w, h];
        me._view.setSize(me, w, h);
        me._scroll.setSize(w,h);
        if (me._itemView != nil) {
            me._itemView.viewHeight = h;
        }

        return me;
    },

    # Internal: allocate a new canvas delegate group with a basic text delegate.
    _createDelegate: func() {
        var w  = me;
        var dh = me._delegateHeight;
        var grp = me._contentGroup.createChild("group", "lv-row");
        var bg  = grp.createChild("path", "lv-row-bg");
        var txt = grp.createChild("text", "lv-row-text")
                     .set("font", "LiberationFonts/LiberationSans-Regular.ttf")
                     .set("character-size", 14)
                     .set("alignment", "left-center")
                     .set("clip-frame", canvas.Element.PARENT);

        var delegate = {
            parents: [],
            _group:  grp,
            _bg:     bg,
            _text:   txt,
            _model:  nil,
            _widget: w,

            # Called by C++ when this delegate is assigned to a model row.
            bind: func(index, modelData) {
                me._model = modelData;
                me._group.setTranslation(0, modelData.yPosition);
                me._group.show();
                me._updateContent();
                logprint(LOG_INFO, "ListView delegate bound:" ~ modelData.label ~ " to index " ~ index);
            },

            # Called by C++ when this delegate is recycled.
            unbind: func() {
                me._group.hide();
                me._model = nil;
            },

            # Called by C++ when underlying model data for this row changed.
            dataChanged: func() {
                if (me._model != nil) me._updateContent();
            },

            # Called by C++ when this row's index shifts (insert/remove above).
            moved: func() {
                if (me._model != nil) {
                    me._group.setTranslation(0, me._model.yPosition);
                }
            },

            # Rebuild the visual content from current model data.
            _updateContent: func() {
                var lbl  = me._model.label;
                var w_px = me._widget._size[0];
                var dh   = me._widget._delegateHeight;
                var sel  = (me._widget._selectedIndex == me._model.index);

                me._bg.reset()
                      .rect(0, 0, w_px, dh)
                      .set("fill", sel ? "#4477bb80" : "#00000010");
                me._text.setText(lbl)
                        .set("max-width", w_px - 12)
                        .setTranslation(6, dh * 0.5);
            },

            # Refresh the selection highlight without fetching new model data.
            _refreshVisual: func() {
                if (me._model != nil) me._updateContent();
            },
        };

        # Clicking a row selects it and notifies the widget.
        grp.addEventListener("click", func {
            if (delegate._model != nil) {
                delegate._widget._onDelegateClicked(
                    delegate._model.index, delegate._model);
            }
        });

        logprint(LOG_INFO, "ListView created delegate");
        append(w._activeDelegates, delegate);
        return delegate;
    },

    # A row was clicked: update selection and emit "selection-changed".
    _onDelegateClicked: func(index, modelData) {
        me._selectedIndex = index;
        foreach (var d; me._activeDelegates) {
            if (d._model != nil) d._refreshVisual();
        }
        me._trigger("selection-changed", { index: index, modelData: modelData });
    },

    # C++ callback: model was completely replaced.
    _onModelReset: func() {
        me._selectedIndex = -1;
        me._setViewOffset(0);
    },

    # C++ callback: the set of visible rows has changed (scroll or resize).
    _onVisibleRowsChanged: func() {
        me._scroll.update();
    },

    # C++ callback: scrollbar metrics have changed.
    _onScrollBarChanged: func() {
    },

    # Apply a clamped scroll offset to both Nasal state and the C++ view.
    _setViewOffset: func(offset) {
        if (offset < 0) offset = 0;
        me._itemView.viewOffset = offset;
        me._scroll.scrollTo(0, offset);
    },

    update: func {
        me._view.update(me);
        return me;
    },
}