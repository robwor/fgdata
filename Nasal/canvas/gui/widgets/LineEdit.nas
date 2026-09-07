gui.widgets.LineEdit = {
  _CLASS: "LineEdit",

  new: func(parent, style = nil, cfg = nil) {
    style = style or canvas.style;
    cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.LineEdit, cfg);
    m._focus_policy = m.StrongFocus;
    m._setView(style.createWidget(parent, "line-edit", cfg));

    m._view._updateLayoutSizes(m);

    m._text = "";
    m._placeholder = "";
    m._max_length = 32767;
    me._ignoreDrag = 0;

    m.context_menu = gui.Menu.new();
    m.context_menu.createItem(text: "Copy", cb: func() { m.copy(); }, shortcut: "<Ctrl>+C");
    m.context_menu.createItem(text: "Cut", cb: func() { m.cut(); }, shortcut: "<Ctrl>+X");
    m.context_menu.createItem(text: "Paste", cb: func() { m.paste(); }, shortcut: "<Ctrl>+V");
    m.context_menu.createItem(text: "Clear", cb: func() { m.clear(); }, shortcut: "<Ctrl>+D");
    m.context_menu.createItem(text: "Select all", cb: func() { m.selectAll(); }, shortcut: "<Ctrl>+A");
    m.context_menu.setCanvasItem(m);

    m.setText(cfg.get("text", ""));
    m.setPlaceholder(cfg.get("placeholder", ""));
    m.setMaxLength(cfg.get("max-length", m._max_length));

    return m;
  },
  setText: func(text) {
    if (text == nil or text == "") {
      me.clear();
      return me;
    }

    me._text = utf8.substr(text, 0, me._max_length);
    me._clearSelection();

    me._view.setText(me, me._text);
    me._moveCursorToByteIndex(size(me._text));
    me._trigger("text-changed", {"text": me._text});
    me._onStateChange();

    return me;
  },
  setPlaceholder: func(placeholder) {
    me._placeholder = placeholder;
    me._view.setPlaceholder(me, me._placeholder);

    return me;
  },
  clear: func {
    me._text = "";
    me._moveCursorToByteIndex(0);
    me._clearSelection();

    me._view.setText(me, "");
    me._trigger("text-changed", {"text": me._text});
    me._onStateChange();
  },
  text: func() {
    return me._text;
  },
  selectedText: func() {
    if (me._view != nil) {
      return me._view._text.selectedText();
    }
  },
  setMaxLength: func(len) {
    me._max_length = len;

    if (utf8.size(me._text) <= len) {
      return me;
    }

    me._text = utf8.substr(me._text, 0, me._max_length);
    me._view.setText(me, me._text);
    me._trigger("text-changed", {"text": me._text});
    me._moveCursorToByteIndex(size(me._text));
    return me;
  },
  getSelection: func {
    var selection = me._view._text.selection();
    return selection;
    return nil;
  },
  copy: func() {
    clipboard.setText(me.selectedText());
  },
  cut: func() {
    clipboard.setText(me.selectedText());
    me._removeSelection();
  },
  paste: func(mode = nil) {
    me._insert(clipboard.getText(mode != nil ? mode : clipboard.CLIPBOARD));
  },
  selectAll: func() {
    me._setSelection(0, size(me._text));
  },
  _showContextMenu: func(e) {
    me.context_menu.show(e.screenX, e.screenY);
  },
  # Remove selected text
  _moveCursorToByteIndex: func(pos) {
    me._view._text.moveCursorToByteIndex(pos);
    me._view._cursor_blink = 1;
    me._view._cursor_blink_timer.stop();
    me._view._cursor_blink_timer.start();

    me._onStateChange();
    return me;
  },
  _moveCursorToPosition: func(x, y) {
    me._view._text.moveCursorToPosition([x, y]);
    me._view._cursor_blink = 1;
    me._view._cursor_blink_timer.stop();
    me._view._cursor_blink_timer.start();
    
    me._onStateChange();
    return me;
  },
  _moveCursor: func(direction) {
    me._view._text.moveCursor(direction);
    me._view._cursor_blink = 1;
    me._view._cursor_blink_timer.stop();
    me._view._cursor_blink_timer.start();

    me._onStateChange();
    return me;
  },
  _home: func() {
    me._moveCursorToByteIndex(0);
    me._clearSelection();
  },
  _end: func() {
    me._moveCursorToByteIndex(size(me._text));
    me._clearSelection();
  },
  # Insert given text after cursor (and first remove selection if set)
  _insert: func(text) {
    me._removeSelection();
    me._view._text.insertAtCursor(text);
    me._text = me._view._text.text();
    me._trigger("text-changed", {"text": me._text});

    me._onStateChange();
    return me;
  },
  _clearSelection: func {
    me._view._text.clearSelection();
    me._view._cursor_visible = 1;
    me._view._cursor_blink = 1;
    me._view._cursor_blink_timer.stop();
    me._view._cursor_blink_timer.start();
    me._onStateChange();
  },
  _setSelection: func(anchor, index) {
    me._view._text.setSelection(anchor, index);
    if (anchor == index) {
      me._view._cursor_visible = 1;
    } else {
      me._view._cursor_visible = 0;
    }
    me._view._cursor_blink = 1;
    me._view._cursor_blink_timer.stop();
    me._view._cursor_blink_timer.start();
    me._onStateChange();
  },
  _removeSelection: func() {
    me._view._text.removeSelection();
    me._text = me._view._text.text();
    me._clearSelection();
    me._trigger("text-changed", {"text": me._text});

    me._onStateChange();
    return me;
  },
  _removeAtCursor: func(beforeOrAfter) {
    me._view._text.removeAtCursor(beforeOrAfter);
    me._text = me._view._text.text();
    me._trigger("text-changed", {"text": me._text});
    me._onStateChange();
    return me;
  },
  # Remove selection or if nothing is selected the character before the cursor
  _backspace: func() {
    if (me.getSelection()[0] >= 0) {
      me._removeSelection();
    } else {
      me._removeAtCursor(-1);
    }
    return me;
  },
  # Remove selection or if nothing is selected the character after the cursor
  _delete: func() {
    if (me.getSelection()[0] >= 0) {
      me._removeSelection();
    } else {
      me._removeAtCursor(1);
    }
    return me;
  },
# protected:
  _setView: func(view) {
    call(gui.Widget._setView, [view], me);

    var el = view._root;
    el.addEventListener("keypress", func (e) {
      if (!e.ctrlKey and !e.altKey and !e.metaKey) {
        me._insert(e.key);
      }
    });
    el.addEventListener("keydown", func (e)
    {
      if( me._view == nil )
        return;

      if (e.key == "Enter") {
        me._trigger("editingFinished", {text: me.text()}); # TODO validator/etc.
      } elsif (e.key == "Backspace") {
        me._backspace();
      } elsif (e.key == "Delete") {
        me._delete();
      } elsif (e.key == "Left") {
        var cursor = me._view._text.cursorByteIndex();
        var selection = me._view._text.selection();
        if (e.shiftKey) {
          var anchor = selection[0];
          var index = selection[1];
          if (anchor < 0 and index < 0) {
            anchor = cursor;
            index = cursor;
          }
          if (index > 0) {
            me._moveCursorToByteIndex(index);
            me._moveCursor(-1);
            index = me._view._text.cursorByteIndex();
            me._setSelection(anchor, index);
          }
        } else {
          if (selection[0] >= 0 and selection[1] >= 0) {
            me._moveCursorToByteIndex(math.min(selection[0], selection[1]));
          } else {
            me._moveCursor(-1);
          }
          me._clearSelection();
        }
      } elsif (e.key == "Right") {
        var cursor = me._view._text.cursorByteIndex();
        var selection = me._view._text.selection();
        if (e.shiftKey) {
          var anchor = selection[0];
          var index = selection[1];
          if (anchor < 0 and index < 0) {
            anchor = cursor;
            index = cursor;
          }
          if (index < size(me._text)) {
            me._moveCursorToByteIndex(index);
            me._moveCursor(1);
            index = me._view._text.cursorByteIndex();
            me._setSelection(anchor, index);
          }
        } else {
          if (selection[0] >= 0 and selection[1] >= 0) {
            me._moveCursorToByteIndex(math.max(selection[0], selection[1]));
          } else {
            me._moveCursor(1);
          }
          me._clearSelection();
        }
      } elsif (e.key == "Home") {
        if (e.shiftKey) {
          var s = me.getSelection();
          if (s[0] < 0) {
            s[0] = me._view._text.cursorByteIndex();
          }
          me._moveCursorToByteIndex(0);
          s[1] = 0;
          me._setSelection(s[0], s[1]);
        } else {
          me._home();
        }
      } elsif (e.key == "End") {
        if (e.shiftKey) {
          var s = me.getSelection();
          if (s[0] < 0) {
            s[0] = me._view._text.cursorByteIndex();
          }
          var newCursor = size(me._text);
          me._moveCursorToByteIndex(newCursor);
          s[1] = newCursor;
          me._setSelection(s[0], s[1]);
        } else {
          me._end();
        }
      }
    });
    el.addEventListener("click", func(e) {
      if (e.button == 2) {
        me._showContextMenu(e);
      } elsif (e.button == 0) {
        me._moveCursorToPosition(e.localX - view._text.getTranslation()[0], e.localY - view._text.getTranslation()[1]);
      	me._clearSelection();
      }
    });
    el.addEventListener("dblclick", func(e) {
      me._selectAll();
    });
    el.addEventListener("mousedown", func(e) {
      me._moveCursorToPosition(e.localX - view._text.getTranslation()[0], e.localY - view._text.getTranslation()[1]);
      var selection = view._text.selection();
      var cursor = view._text.cursorByteIndex();
      if (math.min(selection[0], selection[1]) <= cursor and math.max(selection[0], selection[1]) >= cursor) { # dragging within existing selection
        # TODO: full drag / drop support
        me._ignoreDrag = 1;
      } else {
        me._setSelection(cursor, cursor);
      }
    });
    el.addEventListener("drag", func(e) {
      if (me._ignoreDrag or math.abs(e.deltaX) < 1) {
        return;
      }
      me._moveCursorToPosition(e.localX - view._text.getTranslation()[0], e.localY - view._text.getTranslation()[1]);
      var selection = view._text.selection();
      var cursor = view._text.cursorByteIndex();
      me._setSelection(selection[0], cursor);
    });
    el.addEventListener("mouseup", func(e) {
      me._ignoreDrag = 0;
    });
  },
  del: func() {
    me.context_menu.del();
    if (me._view != nil) {
      me._view._cursor_blink_timer.stop();
    }
  }
};
