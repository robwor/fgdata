gui.Widget = {
  _CLASS: "gui.Widget",

  new: func(derived, cfg = nil)
  {
    cfg = Config.new(cfg);
    var m = canvas.Widget.new({
      parents: [derived, gui.Widget],
      _focused: 0,
      _focus_policy: cfg.get("focus-policy", gui.Widget.NoFocus),
      _hover: 0,
      _enabled: 1,
      _expanding: cfg.get("expanding", gui.Widget.ExpandingDisabled),
      _view: nil,
      _pos: [0, 0],
      _size: [32, 32],
      _bindings: cfg.get("bindings", []),
      _cfg: cfg,
    });

    m.setLayoutMinimumSize([16, 16]);
    m.setLayoutSizeHint([32, 32]);
    m.setLayoutMaximumSize([m._MAX_SIZE, m._MAX_SIZE]);

    m.setSetGeometryFunc(m._impl.setGeometry);

    if ((var alignment = m._cfg.get("alignment")) != nil) {
      m.setAlignment(alignment);
    }
    if ((var fixedSize = m._cfg.get("fixed-size")) != nil) {
      m.setFixedSize(fixedSize[0], fixedSize[1]);
    }
    m.setEnabled(m._cfg.get("enabled", 1));
    m.setExpanding(m._expanding);

    return m;
  },

  # @description Set expanding flag
  # @param expanding gui.Widget.ExpandingFlag
  # @return canvas.gui.Widget Return me to enable method chaining
  setExpanding: func(expanding) {
    me._expanding = expanding;
    if (me._expanding == gui.Widget.ExpandingDisabled) {
      me.setSizeHint([0, 0]);
      return me;
    }
    if (me._expanding & gui.Widget.ExpandingHorizontal) {
      me.setSizeHint([me._MAX_SIZE, me.sizeHint()[1]]);
    }
    if (me._expanding & gui.Widget.ExpandingVertical) {
      me.setSizeHint([me.sizeHint()[0], me._MAX_SIZE]);
    }
  },
  setFixedSize: func
  {
    var (x, y) = (nil, nil);
    if (size(arg) == 2) {
      (x, y) = arg;
    } elsif (size(arg) == 1 and isvec(arg[0]) and size(arg[0]) == 2) {
      (x, y) = arg[0];
    } else {
      die("setFixedSize must be passed two numbers or one vector containing two numbers");
    }
    me._expanding = me.ExpandingDisabled;
    me.setMinimumSize([x, y]);
    me.setSizeHint([x, y]);
    me.setMaximumSize([x, y]);
    return me;
  },
  setEnabled: func(enabled)
  {
    if( me._enabled == enabled )
      return me;

    me._enabled = enabled;
    me.clearFocus();

    me._onStateChange();
    return me;
  },
  # Move the widget to the given position (relative to its parent)
  move: func(x, y)
  {
    me._pos[0] = x;
    me._pos[1] = y;

    if( me._view != nil )
      me._view._root.setTranslation(x, y);
    return me;
  },
  #
  setSize: func(w, h)
  {
    me._size[0] = w;
    me._size[1] = h;

    if( me._view != nil )
      me._view.setSize(me, w, h);
    return me;
  },
  # Set geometry of widget (usually used by layouting system)
  #
  # @param geom [<x>, <y>, <width>, <height>]
  setGeometry: func(geom)
  {
    me.move(geom[0], geom[1]);
    me.setSize(geom[2], geom[3]);
    me._onStateChange();
    return me;
  },
  #
  setFocus: func
  {
    if( me._focused )
      return me;

    var canvas = me.getCanvas();
    if( canvas._impl['_focused_widget'] != nil )
      canvas._focused_widget.clearFocus();

    if( !me._enabled )
      return me;

    me._focused = 1;
    canvas._focused_widget = me;

    if( me._view != nil )
      me._view._root.setFocus();

    me._trigger("focus-in");
    me._onStateChange();

    return me;
  },
  #
  clearFocus: func
  {
    if( !me._focused )
      return me;

    me._focused = 0;
    me.getCanvas()._focused_widget = nil;
    me.getCanvas().clearFocusElement();

    me._trigger("focus-out");
    me._onStateChange();

    return me;
  },
  #
  hasActiveFocus:func
  {
      return me.getCanvas()._focused_widget == me;
  },
  #
  listen: func(type, cb)
  {
    me._view._root.addEventListener("cb." ~ type, cb);
    return me;
  },
  onRemove: func
  {
    if( me._view != nil )
    {
      me._view._root.del();
      me._view = nil;
    }

    if( me._focused and me.getCanvas() )
      me.getCanvas()._focused_widget = nil;
  },
  view: func 
  {
    return me._view;
  },
# protected:
  _MAX_SIZE: 32768, # size for "no size-limit"
  _onStateChange: func
  {
    if( me._view != nil and me._view.update != nil )
      me._view.update(me);
  },
  visibilityChanged: func(visible)
  {
    if (me._view != nil) {
      me._view._root.setVisible(visible);
    }
  },

  _setView: func(view)
  {
    me._view = view;

    var root = view._root;
    var canvas = root.getCanvas();
    me.setCanvas(canvas);

    canvas.addEventListener("wm.focus-in", func {
      me._onStateChange();
    });
    canvas.addEventListener("wm.focus-out", func {
      me._onStateChange();
    });

    root.addEventListener("mouseenter", func {
      me._hover = 1;
      me._trigger("mouse-enter");
      me._onStateChange();
    });
    root.addEventListener("mousedown", func {
      if( me._focus_policy & me.ClickFocus )
        me.setFocus();
    });
    root.addEventListener("mouseleave", func {
      me._hover = 0;
      me._trigger("mouse-leave");
      me._onStateChange();
    });

    # if we have keyboard bindings defined, add the listener for them
    if (size(me._bindings)) {
      root.addEventListener("keydown", func(e) me._onKeyPressed(e));
    }
  },
  _trigger: func(type, data = nil)
  {
    if( me._view != nil )
      me._view._root.dispatchEvent(
        canvas.CustomEvent.new("cb." ~ type, {detail: data})
      );
    return me;
  },
  _windowFocus: func
  {
    var canvas = me.getCanvas();
    return canvas != nil ? canvas.data("focused") : 0;
  }
};

# enum FocusPolicy:
gui.Widget.NoFocus = 0;
gui.Widget.TabFocus = 1;
gui.Widget.ClickFocus = 2;
gui.Widget.StrongFocus = gui.Widget.TabFocus
                       | gui.Widget.ClickFocus;

# enum ExpandingFlag:
# Do not expand
gui.Widget.ExpandingDisabled = 0;
# Expand horizontally
gui.Widget.ExpandingHorizontal = 1;
# Expand vertically
gui.Widget.ExpandingVertical = 2;
# Expand in both directions
gui.Widget.Expanding = gui.Widget.ExpandingHorizontal | gui.Widget.ExpandingVertical;
