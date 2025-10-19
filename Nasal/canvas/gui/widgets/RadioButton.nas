# RadioButton.nas : radio button, and group helper
# to manage updating checked state conherently
# SPDX-FileCopyrightText: (C) 2022 James Turner <james@flightgear.org>, Frederic Croix <thefgfseagle@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.RadioButton = {
  _CLASS: "RadioButton",

  new: func(parent, style = nil, cfg = nil) {
    style = style or canvas.style;
    cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.RadioButton, cfg);
    m._focus_policy = m.StrongFocus;
    m._checked = 0;
    m._text = "";
    m.radioGroup = nil;
    m._data = cfg.get("data", {});

    m._setView( style.createWidget(parent, cfg.get("type", "radio-button"), cfg) );

    m.setChecked(m._cfg.get("checked", 0));
    var radioButtonsGroup = cfg.get("radio-buttons-group");
    var parentRadio = cfg.get("parent-radio", nil);
    var radioButtonsGroupClass = cfg.get("radio-buttons-group-class");
    if (radioButtonsGroup != nil) {
      m.radioGroup = radioButtonsGroup;
    } elsif (parentRadio != nil) {
      m.radioGroup = parentRadio.radioGroup;
    } elsif (radioButtonsGroupClass != nil) {
      m.radioGroup = radioButtonsGroupClass.new();
    } else {
      m.radioGroup = gui.widgets.RadioButtonsGroup.new();
    }
    m.radioGroup.addRadioButton(m);

    m.setText(m._cfg.get("text", ""));

    return m;
  },
  # @description Get the radio button group this radio button is in
  # @return gui.widgets.RadioButtonsGroup
  getRadioButtonsGroup: func {
  	return me.radioGroup;
  },
  # @description Add this radio button to the given radio buttons group.
  # 	Also removes this radio button from the radio buttons group it was in before, if it was in one.
  # @param group RadioButtonsGroup Radio buttons group to add this radio button to.
  setRadioButtonsGroup: func(group) {
    if (me.radioGroup) {
      me.radioGroup.removeRadio(me);
    }
    group.addRadio(me);
    me.radioGroup = group;
  },
  # @description Set the data for this radio button.
  # @param key Union[scalar, hash] required If @param key is a hash, this item's data is replaced with that hash.
  #                                                                           If @param key is a scalar, the data field with that name will be set to value.
  #                                                                           If @param key is anything else, an error will be raised.
  # @param value Any optional The value to set the data field with key @param key to, if @param key is a scalar;
  #                                                    otherwise, this argument is ignored.
  # @return canvas.gui.widgets.RadioButton This radio button to support method chaining.
  setData: func(key, value = nil) {
    if (isscalar(key)) {
      me._data[key] = value;
    } elsif (ishash(key)) {
      me._data = key;
    } else {
      die("cannot set data field with non-scalar key !");
    }
    return me;
  },

  # @description Get the data of this radio button.
  # @param key Union[scalar, nil] The scalar key of the data field to return the value of, or nil to return the whole data.
  # @return Any If @param key is a scalar, the value of the field with key @param key, else the whole data as a hash.
  getData: func(key = nil) {
    if (key != nil) {
      if (!isscalar(key)) {
        die("cannot get data field with non-scalar key !")
      }
      return me._data[key];
    } else {
      return me._data;
    }
  },

  # @description Clear data
  # @return canvas.gui.widgets.RadioButton This radio button to support method chaining.
  clearData: func {
    me._data = {};
    return me;
  },

  getText: func {
    return me._text;
  },

  setText: func(text) {
    me._text = text;
    me._view.setText(me, text);
    return me;
  },

  getChecked: func {
    return me._checked;
  },

  setChecked: func(checked = 1) {
    if (me._checked == checked) {
      return me;
    }

    me._setRadioButtonsGroupSiblingsUnchecked();
    me._setChecked(checked);
  },
  
  _setChecked: func(checked = 1) {
    me._checked = checked;
    me._trigger("toggled", {checked: checked});
    if (checked) {
    	me._trigger("checked");
    } else {
    	me._trigger("unchecked");
    }
    me._onStateChange();
    return me;
  },

  _setRadioButtonsGroupSiblingsUnchecked: func {
    me.radioGroup._updateChecked(me);
  },

  toggle: func {
    me.setChecked(!me._checked);
    return me;
  },

  _setView: func(view) {
    call(gui.Widget._setView, [view], me);

    var el = view._root;
    el.addEventListener("click", func {
      if (me._enabled) {
        me.setChecked()
      }
    });

    el.addEventListener("drag", func(e) e.stopPropagation());
  },
};

# auto manage radio-button checked state
gui.widgets.RadioButtonsGroup = {
  new: func(name = "unnamed")
  {
    var m = {
      parents: [gui.widgets.RadioButtonsGroup],
      name: name,
      radios: [],
    };
    return m;
  },

  _onRadioButtonToggled: func {
    var checked = me.getCheckedRadioButton();
    foreach (var radio; me.radios) {
      radio._trigger("group-checked-radio-changed", {checkedRadio: checked});
    }
  },

  addRadioButton: func(r)
  {
    r.listen("toggled", func me._onRadioButtonToggled());
    if (size(me.radios) == 0) {
      r.setChecked();
    }
    append(me.radios, r);
  },

  removeRadioButton: func(r)
  {
    if ((var index = find(r, me.radios)) > -1) {
      var radio = removeat(me.radios, index);
      if (index < size(me.radios)) {
        me.radios[index].setChecked();
      } elsif (size(me.radios) > 0) {
        me.radios[-1].setChecked();
      }
      return radio;
    }
  },

  setEnabled: func(enabled = 1)
  {
    foreach (var r; me.radios) {
      r.setEnabled(enabled);
    }
    return me;
  },

  getCheckedRadioButton: func {
    foreach (var radio; me.radios) {
      if (radio._checked) {
        return radio;
      }
    }
    return nil;
  },

  # update check state of all radios in the group
  _updateChecked: func(active)
  {
    foreach (var r; me.radios) {
      if (r != active) {
        r._setChecked(0);
      }
    }
    return me;
  },
};
