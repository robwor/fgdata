# PropertyWidgets.nas - subclassed canvas widgets that are synced with a property node

# SPDX-FileCopyrightText: (C) 2022 Frederic Croix <thefgfseagle@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.widgets.PropertyWidget = {
	_CLASS: "PropertyWidget",

	new: func(propertybase, base, parent, style = nil, cfg = nil) {
		style = style or canvas.style;
		cfg = Config.new(cfg);
		var m = base.new(parent, style, cfg);
		m.parents = [propertybase, gui.widgets.PropertyWidget] ~ m.parents;
		m._nodeListener = nil;
		m._node = nil;
		m._propertySynced = 1;

		m._configure();
		m.setNode(cfg.get("node"));

		return m;
	},

	setPropertySynced: func(synced = 1) {
		me._propertySynced = synced;
		return me;
	},

	setNode: func(n) {
		if (n == nil) {
			if (me._node != nil) {
				if (isfunc(me._cleanup)) {
					me._cleanup();
				}
				me._node = nil;
				return me;
			}
		} elsif (isscalar(n)) {
			n = props.globals.getNode(n);
		} elsif (!isa(n, props.Node)) {
			if (ishash(n)) {
				n = props.Node.new(n);
			} else {
				die("Invalid node argument of type " ~ typeof(n) ~ "to canvas.gui.widgets.PropertyWidget.setNode !");
			}
		}
		me._cleanup();
		me._node = n;
		if (isfunc(me._nodeChanged)) {
			me._nodeChanged();
		}

		return me;
	},
	_nodeChanged: func,
	_cleanup: func {
		if (me._nodeListener != nil) {
			removelistener(me._nodeListener);
			me._nodeListener = nil;
		}
	},
	_configure: func,
	del: func {
		if (isfunc(me._cleanup)) {
			me._cleanup();
		}
		if (isfunc(me.parents[2]["del"])) {
			me.parents[2].del();
		}
	}
};

gui.widgets.PropertySwitch = {
	_CLASS: "PropertySwitch",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertySwitch, gui.widgets.Switch, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		me.setChecked(me._node.getBoolValue());
		me.listen("toggled", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setBoolValue(int(e.detail.checked));
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			me.setChecked(n.getBoolValue());
		}, 1, 0);
	},
};

gui.widgets.PropertyButton = {
	_CLASS: "PropertyButton",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyButton, gui.widgets.Button, parent, style, cfg);
		m._checkable = 1;

		return m;
	},
	_nodeChanged: func {
		me.setChecked(me._node.getBoolValue());
		me.listen("toggled", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setBoolValue(int(e.detail.checked));
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			me.setChecked(n.getBoolValue());
		}, 1, 0);
	},
};

gui.widgets.PropertyRadioButtonsGroup = {
	_CLASS: "PropertyRadioButtonsGroup",

	new: func(node, name = "unnamed") {
		var m = gui.widgets.RadioButtonsGroup.new(name);
		m.parents = [gui.widgets.PropertyRadioButtonsGroup] ~ m.parents;
		m._propertySynced = 1;
		m._nodeListener = nil;
		m.setNode(node);

		return m;
	},

	_nodeChanged: func {
		me._propertySynced = 1;
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			var value = me._node.getValue();
			foreach (var radio; me.radios) {
				if (value == radio.getData("property-value")) {
					radio.setChecked(1);
				} else {
					radio.setChecked(0);
				}
			}
		});
	},

	setNode: func(n) {
		call(gui.widgets.PropertyWidget.setNode, [n], me);
		return me;
	},

	setPropertySynced: func(synced = 1) {
		me._propertySynced = synced;
		return me;
	},

	_onRadioToggled: func {
		if (!me._propertySynced) {
			return;
		}
		var checked = me.getCheckedRadio();
		foreach (var radio; me.radios) {
			radio._trigger("group-checked-radio-changed", {checkedRadio: checked});
		}
		me._propertySynced = 0;
		me._node.setValue(checked != nil ? checked.getData("property-value") : "");
		me._propertySynced = 1;
	},
	_cleanup: func {
		call(gui.widgets.PropertyWidget._cleanup, nil, me);
	},

	del: func {
		call(gui.widgets.PropertyWidget.del, nil, me);
	},
};

gui.widgets.PropertyRadioButton = {
	_CLASS: "PropertyRadioButton",

	new: func(parent, style = nil, cfg = nil) {
		cfg = Config.new(cfg);
		if (!cfg.get("parent-radio") and !cfg.get("radio-button-group")) {
			cfg.set("radio-button-group", gui.widgets.PropertyRadioButtonsGroup.new(cfg.get("node")));
		}

		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyRadioButton, gui.widgets.RadioButton, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		me.setChecked(me._node.getBoolValue());
		me.listen("toggled", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setBoolValue(int(e.detail.checked));
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			me.setChecked(n.getBoolValue());
		}, 1, 0);
	},
};

gui.widgets.PropertyList = {
	_CLASS: "PropertyList",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyList, gui.widgets.List, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		if (var value = str(me.findItemByData("property-value", me._node.getValue()))) {
			me.setItemSelection(value);
		}
		me.listen("selection-changed", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			var selectedItems = me.getSelectedItems();
			if (size(selectedItems)) {
				me._node.setValue(selectedItems[0].getData("property-value"));
			} else {
				me._node.setValue("");
			}
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			if (str(me.findItemByData("property-value", n.getValue()))) {
				me.setItemSelection(me.findItemByData("property-value", n.getValue()));
			}
		}, 1, 0);
	},
};

gui.widgets.PropertyComboBox = {
	_CLASS: "PropertyComboBox",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyComboBox, gui.widgets.ComboBox, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		me.setSelectedByValue(me._node.getValue());
		me.listen("selected-item-changed", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setValue(e.detail.value);
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			if (n.getValue() != me._items[m._currentIndex].menuValue) {
				me.setSelectedByValue(n.getValue());
			}
		}, 1, 0);
	},
};

gui.widgets.PropertyLabel = {
	_CLASS: "PropertyLabel",

	new: func(parent, style = nil, cfg = nil) {
		cfg = Config.new(cfg);
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyLabel, gui.widgets.Label, parent, style, cfg);

		return m;
	},

	_configure: func {
		me._format = me._cfg.get("text", "%s");
		me._default = me._cfg.get("default");
	},

	_nodeChanged: func {
		me.setText(sprintf(me._format, me._node.getValue()));
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			var value = n.getValue();
			if (value == nil) {
				value = me._default;
			}
			me.setText(sprintf(me._format, value));
		}, 1, 0);
	},
};


gui.widgets.PropertyLineEdit = {
	_CLASS: "PropertyLineEdit",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyLineEdit, gui.widgets.LineEdit, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		me.setText(me._node.getValue());
		me.listen("text-changed", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setValue(me.getText());
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			me.setText(n.getValue());
		}, 1, 0);
	},
};

gui.widgets.PropertyCheckBox = {
	_CLASS: "PropertyCheckBox",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyCheckBox, gui.widgets.CheckBox, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		me.setChecked(me._node.getBoolValue());
		me.listen("toggled", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setBoolValue(int(e.detail.checked));
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			me.setChecked(n.getBoolValue());
		}, 1, 0);
	},
};

gui.widgets.PropertySlider = {
	_CLASS: "PropertySlider",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertySlider, gui.widgets.Slider, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		me.setValue(me._node.getValue());
		me.listen("value-changed", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setValue(num(e.detail.value));
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			me.setValue(n.getValue());
		}, 1, 0);
	},
};

gui.widgets.PropertyDial = {
	_CLASS: "PropertyDial",

	new: func(parent, style = nil, cfg = nil) {
		var m = gui.widgets.PropertyWidget.new(gui.widgets.PropertyDial, gui.widgets.Dial, parent, style, cfg);

		return m;
	},

	_nodeChanged: func {
		me.setValue(me._node.getValue());
		me.listen("value-changed", func(e) {
			if (!me._propertySynced) {
				return;
			}
			me._propertySynced = 0;
			me._node.setValue(num(e.detail.value));
			me._propertySynced = 1;
		});
		me._nodeListener = setlistener(me._node, func(n) {
			if (!me._propertySynced) {
				return;
			}
			me.setValue(n.getValue());
		}, 1, 0);
	},
};
