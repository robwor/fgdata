# Slider.nas : show a user-draggable slider
# with optional tick marks and value display
# SPDX-FileCopyrightText: (C) 2022 James Turner <james@flightgear.org>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.Slider = {
  _CLASS: "Slider",
  new: func(parent, style = nil, cfg = nil)
  {
    style = style or canvas.style;
    var cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.Slider, cfg);
    m._focus_policy = m.StrongFocus;
    m._thumbDown = 0;
    m._minValue = cfg.get("min-value", 0);
    m._maxValue = cfg.get("max-value", 100);
    m._value = cfg.get("value", 50);
    m._stepSize = cfg.get("step-size", 1);
    m._pageSize = cfg.get("page-size", 10);
    m._tickStep = cfg.get("tick-step", m._pageSize);

    m._showValue = cfg.get("show-value", 1);
    m._showTicks = cfg.get("show-ticks", 1);

    m._setView(style.createWidget(parent, cfg.get("type", "slider"), cfg));
    m.setValue(m._value);
    
    # not sure why we need this here again since we already call _onStateChange in setValue, but the slider doesnt display correctly without this until you click on it.
    m._onStateChange();
    m._view._updateLayoutSizes(m);

    return m;
  },

  setValue: func(val)
  {
    if (!isnum(val)) {
      return me;
    }
    value = math.clamp(val, me._minValue, me._maxValue);
    if (value == me._value) {
      return me;
    }
    me._value = value;
    me._trigger("value-changed", {"value": value});
    if (me._view != nil) {
      me._view.setNormValue(me, me._normValue());
    }
    me._onStateChange();

    return me;
  },

  setShowValue: func(show) {
    me._showValue = show;
    me._view._updateLayoutSizes(me);
    return me;
  },

  setShowTicks: func(show) {
    me._showTicks = show;
    me._view._updateLayoutSizes(me);
    return me;
  },

# protected:
  _setView: func(view)
  {
    call(gui.Widget._setView, [view], me);

    var el = view._root;
    el.addEventListener("click", func(e) {
      me._dragThumb(e);
    });

    view._thumb.addEventListener("drag", func(e) {
      me._dragThumb(e);
      e.stopPropagation();
    });
    view._thumb.addEventListener("mousedown", func(e) {
      me._thumbDown = 1;
      me._onStateChange();
    });
    view._thumb.addEventListener("mouseup", func(e) {
      me._thumbDown = 0;
      me._onStateChange();
    });
    view._root.addEventListener("wheel", func(e) {
      if (!me._enabled) {
        return;
      }

      me.setValue(me._value + e.deltaY * me._stepSize);
      e.stopPropagation();
    });
    view._root.addEventListener("keydown", func(e) {
      var value = me._value;
      if (contains([
        FunctionKeys.Left, FunctionKeys.KP_Left,
        FunctionKeys.Down, FunctionKeys.KP_Down,
        PrintableKeys.Minus, FunctionKeys.KP_Subtract,
      ], e.keyCode)) {
        value -= me._stepSize;
      } elsif (contains([
        FunctionKeys.Right, FunctionKeys.KP_Right,
        FunctionKeys.Up, FunctionKeys.KP_Up,
        PrintableKeys.Plus, FunctionKeys.KP_Add,
      ], e.keyCode)) {
        value += me._stepSize;
      } elsif (contains([FunctionKeys.Page_Down, FunctionKeys.KP_Page_Down], e.keyCode)) {
        value -= me._pageSize;
      } elsif (contains([FunctionKeys.Page_Up, FunctionKeys.KP_Page_Up], e.keyCode)) {
        value += me._pageSize;
      } elsif (contains([FunctionKeys.Home, FunctionKeys.KP_Home], e.keyCode)) {
        value = me._minValue;
      } elsif (contains([FunctionKeys.End, FunctionKeys.KP_End], e.keyCode)) {
        value = me._maxValue;
      }
      me.setValue(value);
    });
  },

  _dragThumb: func(event)
  {
    if (!me._enabled) {
      return;
    }
    var vr =  me._view._root;
    var padding = me._view._style.getFont("slider").size * me._view._style.getSize("slider", "padding");
    var viewPosX = vr.canvasToLocal([event.clientX, event.clientY])[0] - padding - me._view._thumbSize[0] / 2;
    var width = me._size[0] - padding * 2 - me._view._thumbSize[0];

    if (viewPosX < 0) {
      me.setValue(me._minValue);
    } elsif (viewPosX > width) {
      me.setValue(me._maxValue);
    } else {
      var norm = viewPosX / width;
      var mouseValue = me._minValue + norm * ( me._maxValue - me._minValue);
      if (me._stepSize != 0) {
        mouseValue = math.round(mouseValue / me._stepSize) * me._stepSize;
      }
      me.setValue(mouseValue);
    }
  },

  # return value as its normalised equivalent
  _normValue: func
  {
    var range = me._maxValue - me._minValue;
    var v = math.clamp(me._value, me._minValue, me._maxValue) - me._minValue;
    return v / range;
  }
};
