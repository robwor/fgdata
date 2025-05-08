# XML Dialog - XML dialog object without using PUI
# SPDX-FileCopyrightText: (C) 2022 James Turner <james@flightgear.org>
# SPDX-License-Identifier: GPL-2.0-or-later

# alias this module to keep things somewhat readable
var cwidgets = canvas.gui.widgets;

# This is the Nasal peer of a dialog defined by XML
# it manages creating some top level Canvas (eg a Window) according
# to the XML data
var XMLDialog = {
    init: func(dialogProps)
    {
        var d = me.dialog();
        var sz = [d.width, d.height];
        me._sizeToContents = 0;

        if ((d.width <= 0) or (d.height <= 0)) {
            logprint(LOG_INFO, "Dialog will resize to fit contents");
            me._sizeToContents = 1;
            sz = [100, 100]; # canvas.Window.new doesn't like size of 0
        } else {
            logprint(LOG_INFO, "Dialog size is:", d.width, "x", d.height);
        }

        me._window = canvas.Window.new(sz, "dialog", d.name);
        # FIXME: lookup translated dialog name, this is the
        # key string here
        me._window.setTitle(d.title);
        me._window.set("resize", d.resizeable);

        var m = me;
        me._window.del = func {
            m.onWindowClosed();
        }
    },

    didBuild: func()
    {
        var ourCanvas = me._window.getCanvas(1); # create, probably
        ourCanvas.set("background", canvas.style.getColor("bg_color"));
        var rootCanvasGroup = ourCanvas.createGroup();
        # get the root XMLObject, almost certainly a container of
        # some kind. (eg frame / group / scroll area)
        var rootObject = me.dialog().root;

        if (me._sizeToContents) {
            var rootLayout = rootObject.layoutItem();
            if (rootLayout) {
                var szh = rootLayout.sizeHint();
                logprint(LOG_INFO, "Setting window size to hint:", szh[0], szh[1]);
                me._window.setSize(szh);
            }
        }

        # show the root object inside our Canvas group. We could delay this
        # until we are made visible to make things more efficient/lazy
        rootObject.show(rootCanvasGroup);
        ourCanvas.setLayout(rootObject.layoutItem());
    },

    # this is the callback from the canvas.Window: we request a close of
    # the dialog, which will end up with us in 'onClosed'
    onWindowClosed: func
    {
        logprint(LOG_WARN, "XMLDialog window was requested to closed");
        me.dialog().close();

        # hack: manually trigger onClose for now. This should happen automatically
        # in response to dialog().close().
        me.onClose();
    },

    onWindowHelp: func
    {
        logprint(LOG_INFO, "Dialog help requested");
        me.dialog().requestHelp();
    },

    onBringToFront: func()
    {
        me._window.raise();
    },

    onGeometryChanged: func()
    {
        var d = me.dialog();
        var rootLayout = d.root.layoutItem();

        logprint(LOG_INFO, "Dialog geometry is now:" ~ d.x ~ ", " ~ d.y ~ " w:" ~ d.width ~ ", h:" ~ d.height);
        me._window.setPosition(d.x, d.y);

        var width = d.width;
        var height = d.height;
        if (width <= 0) {
            width = rootLayout.sizeHint()[0];
        }

        if (height <= 0) {
            height = rootLayout.sizeHint()[1];
        }
        
        logprint(LOG_INFO, "Setting window size to:", width, ",", height);
        me._window.setSize(width, height);
    },

    onClose: func
    {
        logprint(LOG_INFO, "XMLDialog closed");

        # call the base canvas.Window delete method, not
        # our wrapper above.
        call(canvas.Window.del, [], me._window);
        return true;
    }

};

# this is the callback function which C++ invokes, to create a peer
# for an XML dialog (and its C++ class). In the future, different kinds
# of dialog could be created if necessary (eg, with different window frame
# styles or frameless / non-draggable)
var _createDialogPeer = func(type)
{
    logprint(LOG_INFO, "Creating dialog of type:" ~ type);
    var z = gui.xml.Dialog.new({
        parents: [XMLDialog]
    });

    return z;
};

var _getProp = func(objectProps, name, def)
{
    var node = objectProps.getNode(name);
    if (node == nil)
        return def;
    return node.getValue();
}

var _getBoolProp = func(objectProps, name, def)
{
    var node = objectProps.getNode(name);
    if (node == nil)
        return def;
    return node.getBoolValue();
}

var _getDoubleProp = func(objectProps, name, def)
{
    var node = objectProps.getNode(name);
    if (node == nil)
        return def;
    return node.getDoubleValue();
}


#################################################################################################

var XMLObjectBase =
{
    _new: func()
    {
        var m = {
            parents: [XMLObjectBase],
            _localValue: nil,
            _layout: nil
        };
        return m;
    },
    
    _configValue: func(name, def = nil)
    {
        var node = me.config.getNode(name);
        if (node == nil)
            return def;
        return node.getValue();
    },

    _configDouble: func(name, def = 0.0)
    {
        var node = me.config.getNode(name);
        if (node == nil)
            return def;
        return node.getDoubleValue();
    },

    _configBool: func(name, def = 0)
    {
        var node = me.config.getNode(name);
        if (node == nil)
            return def;
        return node.getBoolValue();
    },

    _applyLayoutConfig: func(compatWidgetSizeHint = false)
    {
        var halign = me._configValue("halign");
        var valign = me._configValue("valign");
        var l = me.layoutItem();
        if (!l)
            return;

        if (halign or valign) {
            var ha = 0;
            if (halign == "left") {
                ha = canvas.AlignLeft;
            } elsif (halign == "center") {
                ha = canvas.AlignHCenter;
            } elsif (halign == "right") {
                ha = canvas.AlignRight;
            }

            var va = 0;
            if (valign == "top") {
                va = canvas.AlignTop;
            } elsif (valign == "center") {
                va = canvas.AlignVCenter;
            } elsif (valign == "bottom") {
                va = canvas.AlignBottom;
            }

            l.setAlignment(ha + va);
        }

        if (ghosttype(l) == "canvas.Widget") {
            # if (compatWidgetSizeHint) {
            #     logprint(LOG_INFO, me.name, ": Compat widget: setting hint to min size:", debug.string(l.minimumSize()));
            #     # old PUI layout code uses minimum size as the hint for many simple
            #     # widgets such as buttons and labels
            #     l.setLayoutSizeHint(l.minimumSize());
            # }

            var fixedWidth = me._configValue("width");
            var fixedHeight = me._configValue("height");
            if (fixedWidth or fixedHeight) {
                # query existing values in case we only write to
                # one axis, instead of both
                var minSize = l.minimumSize();
                var maxSize = l.maximumSize();
                if (fixedWidth) {
                    minSize[0] = fixedWidth;
                    maxSize[0] = fixedWidth;
                }
                if (fixedHeight) {
                    minSize[1] = fixedHeight;
                    maxSize[1] = fixedHeight;
                }
                l.setMaximumSize(maxSize);
                l.setMinimumSize(minSize);
                logprint(LOG_INFO, me.name, ": Fixed size widget,", debug.string(minSize));
            }

            var prefWidth = me._configValue("pref-width");
            var prefHeight = me._configValue("pref-height");
            if (prefWidth or prefHeight) {
                var hint = l.sizeHint();
                var maxSize = l.maximumSize();
                if (prefWidth) {
                    hint[0] = prefWidth;
                    maxSize[0] = prefWidth;
                }
                if (prefHeight) {
                    hint[1] = prefHeight;
                    maxSize[1] = prefHeight;
                }

                l.setSizeHint(hint);
                l.setMaximumSize(maxSize);

                #logprint(LOG_INFO, me.name, ": Setting widget size hint to:", debug.string(hint));
                #logprint(LOG_INFO, me.name, ": Setting widget max size to:", debug.string(maxSize));
            }
        } else {
            # layout item is not a NasalWidget, so lacks public
            # setters for these. Could extend the API if we need to
            # cover these cases where XML dialogs specify sizes on
            # layouts
        }

    },

    _changeLocalValue: func(newValue)
    {
        me._localValue = newValue;
        if (me.live and me.property) {
            me.property.setValue(newValue);
        }
    },

    valueChanged: func
    {
        # if (me._localValue == me.value)
        #     return;

        if (me.property) {
            me._localValue = me.value;
        }

        me.update();
    },

    _activateBindings: func
    {
        me.activateBindings();
    },

    _roleWeights: {
        "help":     -100,       # help is strange, moves
        # spacer goes in at 0
        "cancel":   1,
        "revert":   20,
        "reset":    50,
        # default weight for no role
        "apply":    150,
        "accept":   200
    },

        # return the ordering value based on the role and other datta
    _orderInButtonBox: func()
    {
        # TODO: make platform specific
        var baseWeight = 100;
        var r = me.role();
        if (contains(me._roleWeights, r)) {
            baseWeight = me._roleWeights[r];
        } else {
            logprint(LOG_DEBUG, "Unknown GUI button role:", r);
        }

        # bias default button to the right
        # (maybe platform specific)
        if (me._configValue("default")) {
            baseWeight += 100;
        }

        return baseWeight;
    },

    apply: func()
    {
        # we must not apply() on live properties, since me.value is
        # already in sync, but _localValue might not be, if a binding calls dialog-apply 
        if (!me.property or me.live) {
            return;
        }

        if (me._localValue == me.value)
            return;

        if (me._localValue == nil) {
            debug.bt();
            return;
        }

        me.property.setValue(me._localValue);
    },

    visibleChanged: func() 
    {
        me._view.setVisible(me.visible);
    },

    view: func { return me._view; },
    layoutItem : func { return me._layout; }
};

#################################################################################################
# XML object peers
#
# For each object defined in XML, we create a C++ object (PUICompatObject) and invoke
# the callback below (_createCompatObject) to create a corresponding Nasal peer. There is
# no requirement for a 1:1 mapping from XML types to the classes below.
#
# The Nasal peer class responds to callbacks from C++, especially showing and hiding, to
# create some visual representation of the object. It's important that this view of the
# object is only created on demand, so that invisible GUI elements do not create Canvas
# objects, which have a rendering cost.

var XMLButton =
{
    show: func(viewParent)
    {
        me._view = cwidgets.Button.new(viewParent, canvas.style, {
            "text": me._configValue("legend"),
            "default": me._configBool("default"),
        });
        me._layout = me._view;

        # copy initial visiblity
        me._view.visible = me.visible;

        # hook up the button to our bindings
        me._view.listen("clicked", func  me._activateBindings(); );
        me._applyLayoutConfig(true);

        return me._view;
    },

    role: func()
    {
        return me._configValue("button-role");
    },

    isDefault: func()
    {
        return me._configBool("default");
    }
};

var XMLStandardButton =
{
    init: func(objectProps)
    {
        me._action = nil;
        var ws = me.buttonType();
        if (ws == "okay") {
            me._role = "accept";
            me._action = func { 
                me.dialog().apply();
                me.dialog().requestClose(); 
            };
        } elsif (ws == "cancel") {
            me._role = ws;
            me._action = func { me.dialog().requestClose(); };
        } elsif (ws == "revert") {
            me._role = ws;
            me._action = func { me.dialog().revert(); };
        } else if (ws == "apply") {
            me._role = "apply";
            me._action = func { me.dialog().apply(); };
        } else if (ws == "close") {
            me._role = "cancel";
            me._action = func { me.dialog().requestClose(); };
        } else if (ws == "use-defaults") {
            me._role = "apply";
            # no action: should we make this standard?
        } else {
            logprint(LOG_WARN, "Unknown standard button type:", ws);
            me._role = "";
        }

        # we use the type as the translation key
        me._label = me.tr(ws, "gui");
    },

    buttonType: func()
    {
        return me._configValue("button-type");
    },

    show: func(viewParent)
    {
        var isDefault = me._configBool("default");
        me._view = cwidgets.Button.new(viewParent, canvas.style, {
            "text": me._label,
            "default": isDefault,
        });
        me._layout = me._view;

        # copy initial visiblity
        me._view.visible = me.visible;

        # hook up the button to our bindings
        me._view.listen("clicked", func  me._onClicked(); );
        me._applyLayoutConfig(true);

        return me._view;
    },

    _onClicked: func() {
        if (me.hasBindings) {
            # should we activate the standard binding as well?
            # seems better not to, and give the UI designer the choice
            me.activateBindings();
        } else {
            logprint(LOG_INFO, "Standard button: invoking built-in action");
            me._action();
        }
    },

    role: func()
    {
        return me._role;
    }
};

var XMLCheckbox =
{
    show: func(viewParent)
    {
        me._view = cwidgets.CheckBox.new(viewParent, canvas.style, {
            "text": me._configValue("label"),
            "checked": me.value     # avoid toggled event on setting value
        });

         # copy initial visiblity
        me._view.visible = me.visible;
        me._layout = me._view;
        me._applyLayoutConfig(true);
        me.valueChanged();

        me._view.listen("toggled", func(e) {
            me._changeLocalValue(e.detail.checked);
            me._activateBindings();
        });

        return me._view;
    },

    update: func()
    {
        if (me.view == nil) {
            return;
        }

        me._view.setChecked(me._localValue);
    }
};


var XMLRadioButton =
{
    show: func(viewParent)
    {
        me._view = cwidgets.RadioButton.new(viewParent, canvas.style, {"text": me._configValue("label")});

         # copy initial visiblity
        me._view.visible = me.visible;

        me._layout = me._view;
        me._applyLayoutConfig(true);
        me.valueChanged();

        me._view.listen("toggled", func(e) {
            me._changeLocalValue(e.detail.checked);
            me._activateBindings();
        });

        return me._view;
    },

    update: func()
    {
        if (me.view == nil) {
            return;
        }

        me._view.setChecked(me._localValue);
    }
};

var XMLLabel =
{
    show: func(viewParent)
    {
        me._view = cwidgets.Label.new(viewParent, canvas.style, {});
        
        # copy initial visiblity
        me._view.visible = me.visible;

        me._label = me._configValue("label");
        me._format = me._configValue("format");
        me._layout = me._view;
        me._applyLayoutConfig(true);
        me.valueChanged();

        return me._view;
    },

    update: func() {
        if (me._view == nil) {
            return;
        }

        var v = me._localValue;
        if (v == nil) {
            v = me._label;
        }

        if (me._format) {
            me._view.setText(sprintf(me._format, v));
        } else {
            me._view.setText(v);
        }
    }
};

var XMLGroup =
{
    init: func(objectProps)
    {
        me._layoutType = me.configValue("layout");
        me._padding = me._configDouble("default-padding");
    },

    show: func(viewParent)
    {
        me._view = viewParent.createChild("group");
        # copy initial visiblity
        me._view.visible = me.visible;

        # check for layout on us
        var layout = nil;
        if (me._layoutType == "hbox") {
            layout = canvas.HBoxLayout.new();
        } elsif (me._layoutType == "vbox") {
            layout =  canvas.VBoxLayout.new();
        } elsif (me._layoutType == "table") {
            layout = canvas.GridLayout.new();
        } else {
            logprint(LOG_WARN, "Unknown layout type:" ~ me._layoutType);
        }

        if (layout != nil) {
            me._layout = layout;
            layout.setSpacing(me._padding);
            me._applyLayoutConfig();
        }

        var radioButtonsGroup = nil;
        foreach (var c; me.children) {
            # create view for each child
            c.show(me._view);
            if (c.type == "radio") {
                var radioButton = c.layoutItem(); 
                if (!radioButtonsGroup) {
                    radioButtonsGroup = radioButton.getRadioButtonsGroup();
                } else {
                    radioButton.radioGroup = radioButtonsGroup;
                    radioButtonsGroup.addRadioButton(radioButton);
                }
            }

            if (layout != nil) {
                var childItem = c.layoutItem();

                if (me._layoutType == "table") {
                    var gpos = c.gridLocation();
                    layout.addItem(childItem, gpos.column, gpos.row, gpos.columnSpan, gpos.rowSpan);
                } else {
                    layout.addItem(childItem);

                    if (c._configBool("equal")) {
                        layout.setEquals(childItem);
                    }

                    # old layout.cxx code only implements stretch on
                    # hbox and vbox, so this is the correct equivalent place
                    # for compatability
                    if (c._configBool("stretch")) {
                        layout.setStretchFactor(childItem, 1.0);
                    }
                }
            } # of children show+layout iteration
            # record the childView elsewhere?
        }
        me.update();

        return me._view;
    },

    update: func()
    {
        # re-create children if we are visible?
    }
};

var XMLSlider =
{
    init: func(objectProps)
    {
        # TODO: support vertical sliders
    },

    show: func(viewParent)
    {
        me._view = cwidgets.Slider.new(viewParent, canvas.style, {
            "min-value": me._configDouble("min", 0),
            "max-value": me._configDouble("max", 1),
            "step-size": me._configDouble("step", 0),
            "page-size": me._configDouble("page", 0),
            "value":     me.value   # essential to avoid triggering our value-changed callback on init
        });

        # copy initial visiblity
        me._view.visible = me.visible;
        me._layout = me._view;
        me._applyLayoutConfig();
        me.valueChanged();

        me._view.listen("value-changed", func(e) {
            me._changeLocalValue(e.detail.value);
            me._activateBindings();
        });

        return me._view;
    },

    update: func()
    {
        if (me._view == nil) {
            return;
        }

        me._view.setValue(me._localValue);
    }
};

var XMLDial =
{
    show: func(viewParent)
    {
        me._view = cwidgets.Dial.new(viewParent, canvas.style, {
            "min-value": me._configDouble("min", 0),
            "max-value": me._configDouble("max", 1),
            "wrap":      me._configBool("wrap", 0),
            "value":     me.value   # essential to avoid triggering our value-changed callback on init
        });
  
        me._layout = me._view;
        me._applyLayoutConfig();
        me.valueChanged();
      
        me._view.listen("value-changed", func(e) {
            me._changeLocalValue(e.detail.value);
            me._activateBindings();
        });

        return me._view;
    },

    update: func()
    {
         if (me._view == nil) {
            return;
        }

        me._view.setValue(me._localValue);
    }
};

var XMLTextEdit =
{
    init: func(objectProps)
    {
        # TODO: config to restrict to numerical / decimal input, etc
    },

    show: func(viewParent)
    {
        me._view = cwidgets.LineEdit.new(viewParent, canvas.style, {});
        me._layout = me._view;
        me._applyLayoutConfig();
        me.valueChanged();

        me._view.listen("text-changed", func(e) {
            me._changeLocalValue(e.detail.text);
            me._activateBindings();
        });

        return me._view;
    },

    update: func()
    {
        # don't overwrite if it has focus
        if (me._view and !me._view.hasActiveFocus()) {
            me._view.setText(str(me._localValue));
        }
    }
};

var XMLEmpty =
{
    show: func(viewParent)
    {
        # TODO: add Nasal-Canvas API to create spacer items
        # explicitly
        me._view = canvas.createChild("empty", "group");
        me._layout = canvas.Spacer.new();
        me._applyLayoutConfig();
        me.update();

        return me._view;
    },

    update: func()
    {
    }
};

var XMLHRule =
{
    show: func(viewParent)
    {
        me._view = cwidgets.HorizontalRule.new(viewParent, canvas.style, {});
        me._layout = me._view;
        me._applyLayoutConfig();
        me.valueChanged();

        return me._view;
    },

    update: func()
    {
        # allow label to be updated live
        if (me._localValue) {
            me._view.setText(_localValue);
        }
    }
};

var XMLVRule =
{
    show: func(viewParent)
    {
        me._view = cwidgets.VerticalRule.new(viewParent, canvas.style, {});
        me._layout = me._view;
        me._applyLayoutConfig();
        me.valueChanged();

        return me._view;
    },

    update: func() {
        me.valueChanged();
    },

    valueChanged: func()
    {
        # allow label to be updated live
        var l = me.value;
        if (l) {
            me._view.setText(l);
        }
    }
};


var XMLComboBox =
{
    show: func(viewParent)
    {
        me._view = cwidgets.ComboBox.new(viewParent, canvas.style, {});

        # copy initial visiblity
        me._view.visible = me.visible;

        # do we support a label or is that a seperate widget?
        foreach (var valueNode; me.config.getChildren("value")) {
            me._view.createItem(valueNode.getValue(), valueNode.getValue());
        }
 
        me._layout = me._view;
        me._applyLayoutConfig();
        me.valueChanged();

       me._view.listen("selected-item-changed", func(e) {
            me._changeLocalValue(e.detail.value);
            me._activateBindings();
        });

        return me._view;
    },

    update: func()
    {
        if (me._view and !me._view.hasActiveFocus()) {
            me._view.setSelectedByValue(me._localValue);
        }
    }
};

var XMLList = {
    show: func(viewParent) {
        me._view = canvas.gui.widgets.List.new(viewParent);

        foreach (var valueNode; me.config.getChildren("value")) {
            me._view.createItem(valueNode);
        }

        me._layout = me._view;
        me._applyLayoutConfig();
        me.valueChanged();

        me._view.listen("selection-changed", func {
            var selection = me._view.getSelectedItems();
            if (size(selection)) {
                me._changeLocalValue(selection[0].getData("text"));
            }
            me._activateBindings();
        });

        return me._view;
    },

    update: func() {
       me._view.filter(me._localValue);
    },
};

var XMLText =
{
    show: func(viewParent)
    {
        me._view = cwidgets.TextBox.new(viewParent, canvas.style, {});
        
        # copy initial visiblity
        me._view.visible = me.visible;

        me._label = me._configValue("label");
        me._format = me._configValue("format");
        me._layout = me._view;
        me._applyLayoutConfig(true);
        me.update();

        return me._view;
    },

    update: func() {
        me.valueChanged();
    },

    valueChanged: func()
    {
        if (me._view == nil) {
            return;
        }

        var v = me.value;
        if (v == nil) {
            v = me._label;
        }
        if (me._format) {
            me._view.setText(sprintf(me._format, v));
        } else {
            me._view.setText(v);
        }
    }
};

var XMLButtonBox =
{
    init: func(objectProps)
    {
        
    },

    show: func(viewParent)
    {
        me._view = viewParent.createChild("group");
        # copy initial visiblity
        me._view.visible = me.visible;

        var layout  = canvas.HBoxLayout.new();
        me._layout = layout;
        #layout.setSpacing(me._padding);
        #me._applyLayoutConfig();

        var orderedButtons = [];
        foreach (var c; me.children) {
            var cty = c.type;
            if ((cty != 'button') and (cty != 'standard-button')) {
                logprint(LOG_WARN, "XMLButtonBox: child is not a button or standard button");
                continue;
            }

            append(orderedButtons, c);
        }

        # sort function
        var by_order = func(a, b) {
            a._orderInButtonBox() < b._orderInButtonBox();
        };

        # sort now
        orderedButtons = sort(orderedButtons, by_order);
        var lastOrder = -1000;
    
        foreach (var b; orderedButtons) {
            b.show(me._view);
            var childItem = b.layoutItem();

        # insert the expanding space 
            var order = b._orderInButtonBox();
            if (lastOrder < 0 and order >= 0) {
                layout.addStretch(1);
            }
            lastOrder = order;
            
            # TODO: respect platform ordering based on role
            layout.addItem(childItem);
            layout.setEquals(childItem);
        }
        me.update();

        return me._view;
    },

    update: func()
    {
        # re-create children if we are visible?
    }
};


var XMLTabs =
{
    init: func(objectProps)
    {
    },

    show: func(viewParent)
    {
        me._view = cwidgets.TabWidget.new(viewParent, canvas.style, {});
        # copy initial visiblity
        me._view.visible = me.visible;

        foreach (var c; me.children) {
            # create tab for each child
            c.show(me._view.getContent());

            var pageId = c.configValue("tab-id");
            var pageLabel = c.configValue("tab-label");

            if (!pageId or !pageLabel) {
                logprint(LOG_WARN, "XMLTabs: child widget has missing tab-id / tab-label")
            } else {
                me._view.addTab(pageId, pageLabel, c.layoutItem());
            }
        }

        me._layout = me._view;
        me._applyLayoutConfig(true);
        valueChanged();

        me._view.listen("selected-item-changed", func(e) {
            me.property.setValue(e.detail.value);
            me._activateBindings();
        });

        return me._view;
    },

    valueChanged: func()
    {
        if (me._view == nil) {
            return;
        }

        if (me.value == nil) {
            return;
        }

        me._view.setCurrentTab(me.value);
    },

    apply: func
    {
        # apply is a no-op for us, because we always update immediately
        # (i.e live is effectively always true)
    }
};

var _createCompatObjectLookupHash = {
    "button": XMLButton,
    "standard-button": XMLStandardButton,
    "checkbox": XMLCheckbox,
    "slider": XMLSlider,
    "dial": XMLDial,
    "group": XMLGroup,
    "frame", XMLFrame,
    "input": XMLTextEdit,
    "empty": XMLEmpty,
    "hrule": XMLHRule,
    "vrule": XMLVRule,
    "combo": XMLComboBox,
    "list": XMLList,
    "text": XMLLabel,
    "radio": XMLRadioButton,
    "textbox": XMLText,
    "button-box": XMLButtonBox,
    "tabs": XMLTabs
};

# this is the callback function invoked by C++ to build Nasal peers
# for the C++ objects defined by XML (PUICompatObject). It's primarly
# a factory method: once the peer object is created, all other behaviour
# is passed to it.
var _createCompatObject = func(type)
{
    var widgetClass = XMLLabel;
    if (contains(_createCompatObjectLookupHash, type)) {
        widgetClass = _createCompatObjectLookupHash[type];
    } else {
        logprint(LOG_WARN, "Unknown widget type '" ~ type ~ "' - using label as placeholder");
    }

    # base class constructor
    var w = XMLObjectBase._new();
    # prepend the derived type to parents so it's found first
    w.parents = [widgetClass] ~ w.parents;
    return gui.xml.Object.new(w, type);
};

logprint(LOG_INFO, "Loaded gui.XMLDialog");
