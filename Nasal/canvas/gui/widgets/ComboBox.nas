# SPDX-FileCopyrightText: (C) 2022 James Turner <james@flightgear.org>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.ComboBox = {
  _CLASS: "ComboBox",

  new: func(parent, style = nil, cfg = nil)
  {
    style = style or canvas.style;
    var cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.ComboBox, cfg);
    m._focus_policy = m.StrongFocus;
#    m._flat = cfg.get("flat", 0);
    m._menu = nil;
    m._setView(style.createWidget(parent, cfg.get("type", "combo-box"), cfg));
    m._items = [];        # items added via createItem, which are always before any model rows
    m._model = nil;
    m._modelListener = nil;
    m._currentIndex = nil;
    m._selectedValue = nil; # value of the current selection, kept so it can be re-found if the items change
    m._style = style; # cache reference to style for creating items
    m._down = 0;

    if (var items = cfg.get("items")) {
      if (typeof(items) == "vector") {
        foreach (var item; items) {
          if (isa(item, gui.MenuItem)) {
            append(m._items, item);
            if (m._currentIndex == nil) {
              # select first item added, if we were previously empty
              m.setSelectedByIndex(0);
            }
          } elsif (ishash(item)) {
            m.createItem(item["text"], item["value"]);
          } elsif (isvec(item) and size(item) == 2) {
            m.createItem(item[0], item[1]);
          } else {
            m.createItem(item, item);
          }
        }
      } elsif (typeof(items) == "hash") {
        foreach (var text; keys(items)) {
          m.createItem(text, items[text]);
        }
      }
    }

    if (var index = cfg.get("selected-index")) {
      m.setSelectedByIndex(index);
    } elsif (var value = cfg.get("selected-value")) {
      m.setSelectedByValue(value);
    } else {
      m.setSelectedByIndex(nil);
    }

    return m;
  },

  setText: func(text)
  {
    if (me._view != nil) {
      me._view.setText(me, text);
    }
    return me;
  },

  show: func()
  {
    # check if enabled
  },

  menu: func()
  {
    if (!me._menu) {
      # a MenuFromModel is a normal menu until a model is set
      me._menu = gui.MenuFromModel.new("combo-box-menu");
    }
    return me._menu;
  },

  addMenuItem: func(text, value) {
    logprint(LOG_WARN, "canvas.gui.Widgets.ComboBox.addMenuItem is deprecated, please use createItem instead");
    return me.createItem(text, value);
  },

# convenience helper to add simple items
  createItem: func(text, value) {
    var index = size(me._items);
    var m = me;
    var item = me.menu().createItem(text, func { m._itemCallback(index);}, {});
    item.menuValue = value;
    append(me._items, item);
    me._view._resetMaxItemWidth();
    me._resolvePendingSelection();
    return item;
  },

# Use the items of an ItemModel (such as gui.PropertyItemModel) as the choices.
# They follow any items already added with createItem, and any other items
# added to menu() (headers, separators, etc.) before this call. Model items
# are selectable and numbered after the createItem items. Pass nil to detach.
  setModel: func(model) {
    me._detachModel();
    if (model == nil) {
      return me;
    }

    var self = me;
    me._model = model;
    # the menu registers its listener first, so its items are up to date
    # by the time our listener runs
    me.menu().setModel(model, func(row, value, label) {
      self._itemCallback(size(self._items) + row);
    });
    me._modelListener = model.addChangeListener(func(type, row, count) {
      self._modelChanged();
    });

    me._modelChanged();
    return me;
  },

  model: func() {
    return me._model;
  },

# Remove all items, including any model.
  clear: func()
  {
    me._detachModel();
    if (me._menu) {
      me._menu.clear();
    }
    me._items = [];
    me._currentIndex = nil;
    me._view._resetMaxItemWidth();
  },

  onRemove: func()
  {
    # the model holds callbacks which refer to us, so break that cycle
    me._detachModel();
    call(gui.Widget.onRemove, [], me);
  },

# number of selectable choices: createItem items, then model rows
  _itemCount: func() {
    return size(me._items) + (me._model != nil ? me._model.count : 0);
  },

  _valueAt: func(index) {
    if (index < size(me._items)) {
      return me._items[index].menuValue;
    }
    return me._model.valueAt(index - size(me._items));
  },

  _textAt: func(index) {
    if (index < size(me._items)) {
      return me._items[index].text();
    }
    return me._model.labelAt(index - size(me._items));
  },

# all the menu items we created, for sizing
  _allMenuItems: func() {
    if (me._model == nil) {
      return me._items;
    }
    return me._items ~ me.menu().modelItems();
  },

# helper to set the current item by passing in
# a value of an item
  setSelectedByValue: func(value) {
    var count = me._itemCount();
    if (!count or (me._currentIndex != nil and me._currentIndex < count and me._valueAt(me._currentIndex) == value)) {
      return me;
    }
    if (value == nil) {
      return me.setSelectedByIndex(nil);
    }

    var index = me.findByValue(value);
    if (index >= 0) {
      return me.setSelectedByIndex(index);
    }

    # remember the value, in case it appears later (eg the model is updated)
    me._selectedValue = value;
    logprint(DEV_WARN, "Canvas.Gui ComboBox: no such value in menu: " ~ debug.string(value));
    return me;
  },

  setSelectedByIndex: func(index) {
    if (me._currentIndex == index) {
      return;
    }
    me._currentIndex = index;

    if (index == nil) {
      me._selectedValue = nil;
      me._view.setText(nil);
      me._trigger("selected-item-changed", {"index": nil, "text": nil, "value": nil});
      return me;
    }

    if (index >= me._itemCount() or index < 0) {
      logprint(DEV_WARN, "Canvas.Gui ComboBox: invalid index " ~ index ~ " passed to setSelectedByIndex");
      return me;
    }

    me._currentIndex = index;
    var text = me._textAt(index);
    var value = me._valueAt(index);
    me._selectedValue = value;
    me._view.setText(me, text);
    me._trigger("selected-item-changed", {"index": index, "text": text, "value": value});
    return me;
  },

  findByValue: func(value) {
    for (var i = 0; i < me._itemCount(); i += 1) {
      if (me._valueAt(i) == value) {
        return i;
      }
    }
    return -1;
  },

  findByText: func(text) {
    for (var i = 0; i < me._itemCount(); i += 1) {
      if (me._textAt(i) == text) {
        return i;
      }
    }
    return -1;
  },

  setDown: func(down = 1)
  {
    if (me._down == down )
      return me;

    me._down = down;
    me._onStateChange();
    return me;
  },

# protected:

# Re-find the selected value after the choices changed. This is silent (no
# selected-item-changed): the selection is the same value, and during a
# model update it may be briefly absent. If the value isn't there, we keep
# showing it and remember it, in case it comes back.
  _resolvePendingSelection: func()
  {
    if (me._currentIndex != nil or me._selectedValue == nil) {
      return;
    }

    var index = me.findByValue(me._selectedValue);
    if (index >= 0) {
      me._currentIndex = index;
      me._view.setText(me, me._textAt(index));
    }
  },

  _modelChanged: func()
  {
    me._view._resetMaxItemWidth();
    if (me._currentIndex != nil) {
      if (me._selectedValue == nil) {
        # selected item has no value to track it by, so just ensure it exists
        if (me._currentIndex >= me._itemCount()) {
          me._currentIndex = nil;
        }
        return;
      }
      # rows may have moved, so look it up again
      me._currentIndex = nil;
    }
    me._resolvePendingSelection();
  },

  _detachModel: func()
  {
    if (me._model == nil) {
      return;
    }

    me._model.removeChangeListener(me._modelListener);
    me._modelListener = nil;
    me._model = nil;
    if (me._menu) {
      me._menu.setModel(nil);
    }
  },

  _itemCallback: func(index)
  {
    me._hideMenu();
    me.setSelectedByIndex(index);
  },

  setSize: func {
    if (size(arg) == 1) {
      var arg = arg[0];
    }
    var (x, y) = arg;
    me._size = [x, y];
    if (me._view != nil) {
      me._view.setSize(me, x, y);
    }
    return me;
  },

  _setView: func(view)
  {
    call(gui.Widget._setView, [view], me);

    var el = view._root;
    el.addEventListener("click", func(e) {
      if (me._enabled) {
        me.setDown(!me._down);
        if (me._down) {
          me._openMenu(e.screenX - e.localX, e.screenY - e.localY + me._size[1]);
        }
      }
    });
  },

  _openMenu: func(x, y)
  {
    me.menu().setPosition(x, y);
    me.menu().show();
    me.menu().setSize(math.max(me._size[0], me.menu().getSize()[0]), me.menu().getSize()[1]);
  },

  _hideMenu: func
  {
    if (me._menu) {
      me._menu.hide();
      me.setDown(0);
    }
  }
};
