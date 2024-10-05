# SPDX-FileCopyrightText: (C) 2022 James Turner <james@flightgear.org>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.ComboBox = {
  new: func(parent, style = nil, cfg = nil)
  {
    style = style or canvas.style;
    var cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.ComboBox, cfg);
    m._focus_policy = m.StrongFocus;
#    m._flat = cfg.get("flat", 0);
    m._menu = gui.Menu.new();
    m._setView( style.createWidget(parent, cfg.get("type", "combo-box"), cfg) );
    m._items = [];
    m._currentIndex = nil;
    m._style = style; # cache reference to style for creating items
    m._down = 0;

    if (var items = cfg.get("items")) {
      if (typeof(items) == "vector") {
        foreach (var item; items) {
          if (isa(item, gui.MenuItem)) {
            var index = size(me._items);
            append(me._items, item);
            if (me._currentIndex == nil) {
              # select first item added, if we were previously empty
              me.setSelectedByIndex(0);
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
      m.setCurrentByIndex(index);
    }
    if (var value = cfg.get("selected-value")) {
      m.setCurrentByValue(value);
    }

    return m;
  },

  setText: func(text)
  {
    if( me._view != nil )
      me._view.setText(me, text);
    return me;
  },

  show: func()
  {
    # check if enabled
  },

  menu: func()
  {
    return me._menu;
  },

  addMenuItem: func(text, value) {
    logprint(LOG_WARN, "canvas.gui.Widgets.ComboBox.addMenuItem is deprecated, please use createItem instead");
    me.createItem(text, value)
  },

# convenience helper to add simple items
  createItem: func(text, value) {
    var index = size(me._items);
    var m = me;
    var item = me.menu().createItem(text, func { m._itemCallback(index);}, {});
    item.menuValue = value;
    append(me._items, item);
    if (me._currentIndex == nil) {
      # select first item added, if we were previously empty
      me.setSelectedByIndex(0);
    }
  },

# helper to set the current item by passing in
# a value of an item
  setSelectedByValue: func(value) {
    if (!size(me._items) or me._currentIndex == nil or me._items[me._currentIndex].menuValue == value) {
      return;
    }

    var index = 0;
    foreach(var i; me._items) {
      if (i.menuValue == value) {
        me.setSelectedByIndex(index);
        return;
      }

      index+=1;
    }

    logprint(DEV_WARN, "Canvas.Gui ComboBox: no such value in menu: " ~ value);
  },

  setSelectedByIndex: func(index) {
    if (me._currentIndex == index)
      return;

    if (index >= size(me._items) or index < 0) {
      logprint(DEV_WARN, "Canvas.Gui ComboBox: invalid index " ~ index ~ " passed to setCurrentByIndex");
      return;
    }

    me._currentIndex = index;
    me._view.setText(me, me._items[index].text());
    me._trigger("selected-item-changed", {"index": index, "text": me._items[index].text(), "value": me._items[index].menuValue});
  },

  findByValue: func(value) {
    for (var i = 0; i < size(me._items); i += 1) {
      if (me._items[i].menuValue == value) {
        return i;
      }
    }
    return -1;
  },

  findByText: func(text) {
    for (var i = 0; i < size(me._items); i += 1) {
      if (me._items[i].text() == text) {
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
  },
  
  _hideMenu: func {
    me._menu.hide();
    me.setDown(0);
  }
};
