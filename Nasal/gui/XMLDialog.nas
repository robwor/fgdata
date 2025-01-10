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

    onBringToFront: func()
    {
        me._window.raise();
    },

    onGeometryChanged: func()
    {
        var d = me.dialog();
        logprint(LOG_INFO, "Dialog geometry is now:" ~ d.x ~ ", " ~ d.y ~ " w:" ~ d.width ~ ", h:" ~ d.height);
        me._window.setPosition(d.x, d.y);
        me._window.setSize(d.width, d.height);
    },

    onClose: func
    {
        logprint(LOG_WARN, "XMLDialog closed");

        # call the base canvas.Window delete method, not
        # our wrapper above.
        call(canvas.Window.del, [], me._window);
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
            }

            var prefWidth = me._configValue("pref-width");
            var prefHeight = me._configValue("pref-height");
            if (prefWidth or prefHeight) {
                var hint = l.sizeHint();
                if (prefWidth) {
                    hint[0] = prefWidth;
                }
                if (prefHeight) {
                    hint[1] = prefHeight;
                }

                l.setSizeHint(hint);
            }

            if (compatWidgetSizeHint) {
                # old PUI layout code uses minimum size as the hint for many simple
                # widgets such as buttons and labels
                l.setSizeHint(l.minimumSize());
            }
        } else {
            # layout item is not a NasalWidget, so lacks public
            # setters for these. Could extend the API if we need to
            # cover these cases where XML dialogs specify sizes on
            # layouts
        }

    },

    visibleChanged: func() 
    {
        logprint(LOG_INFO, "Updating widget visiblity");
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
        me._view.listen("clicked", func  me.activateBindings(); );
        me._applyLayoutConfig(true);

        return me._view;
    }



};

var XMLCheckbox =
{
    show: func(viewParent)
    {
        me._view = cwidgets.CheckBox.new(viewParent, canvas.style, {"text": me._configValue("label")});

         # copy initial visiblity
        me._view.visible = me.visible;

        me._layout = me._view;
        me._applyLayoutConfig(true);
        me.update();

        return me._view;
    },

    update: func()
    {
        me.valueChanged();
    },

    valueChanged: func()
    {
        if (me.view == nil) {
            return;
        }

        me._view.setChecked(me.value);
    },
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

        foreach (var c; me.children) {
            # create view for each child
            c.show(me._view);

            if (layout != nil) {
                var childItem = c.layoutItem();

                if (me._layoutType == "table") {
                    var gpos = c.gridLocation();
                    layout.addItem(childItem, gpos.column, gpos.row, gpos.columnSpan, gpos.rowSpan);
                } else {
                    layout.addItem(childItem);

                    # TODO: support 'equal' configBool here, set
                    # stretch factor as well?

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
        });

        # copy initial visiblity
        me._view.visible = me.visible;

        me._view.listen("value-changed", func(e) {
            if (me.property) {
                me.property.setValue(e.detail.value);
            }
            me.activateBindings();
        });
        me._layout = me._view;
        me._applyLayoutConfig();
        me.update();

        return me._view;
    },

    update: func()
    {
        me.valueChanged();
    },

    valueChanged: func()
    {
        if (me._view == nil) {
            return;
        }

        me._view.setValue(me.value);
    }
};

var XMLDial =
{
    show: func(viewParent)
    {
        me._view = cwidgets.Dial.new(viewParent, canvas.style, {
            "min-value": me._configDouble("min", 0),
            "max-value": me._configDouble("max", 1),
            "wrap": me._configBool("wrap", 0),
        });
        me._view.listen("value-changed", func(e) {
            if (me.property) {
                me.property.setValue(e.detail.value);
            }
            me.activateBindings();
        });
        me._layout = me._view;
        me._applyLayoutConfig();
        me.update();

        return me._view;
    },

    update: func()
    {
        me.valueChanged();
    },

    valueChanged: func()
    {
        if (me._view == nil) {
            return;
        }

        me._view.setValue(me.value);
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
        me._view.listen("text-changed", func(e) {
            if (me.property) {
                me.property.setValue(e.detail.text);
            }
            me.activateBindings();
        });
        me._layout = me._view;
        me._applyLayoutConfig();
        me.update();

        return me._view;
    },

    update: func()
    {
        me.valueChanged();
    },

    valueChanged: func()
    {
        # don't overwrite if it has focus
        if (me._view and !me._view.hasActiveFocus()) {
            me._view.setText(str(me.value));
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
        me.update();

        return me._view;
    },

    update: func()
    {
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

var XMLVRule =
{
    show: func(viewParent)
    {
        me._view = cwidgets.VerticalRule.new(viewParent, canvas.style, {});
        me._layout = me._view;
        me._applyLayoutConfig();
        me.update();

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
        me._view.listen("selected-item-changed", func(e) {
            if (me.property) {
                me.property.setValue(e.detail.value);
            }
            me.activateBindings();
        });

        me._layout = me._view;
        me._applyLayoutConfig();
        me.update();

        return me._view;
    },

    update: func()
    {
        me.valueChanged();
    },

    valueChanged: func()
    {
        if (me._view and !me._view.hasActiveFocus()) {
            me._view.setSelectedByValue(me.value);
        }
    }
};

var XMLList = {
    show: func(viewParent) {
        me._view = canvas.gui.widgets.List.new(viewParent);

        foreach (var valueNode; me.config.getChildren("value")) {
            me._view.createItem(valueNode);
        }
        me._view.listen("selection-changed", func {
            var selection = me._view.getSelectedItems();
            if (me.property and size(selection)) {
                me.property.setValue(selection[0].getData("text"));
            }
            me.activateBindings();
        });

        me._layout = me._view;
        me._applyLayoutConfig();
        me.update();

        return me._view;
    },

    update: func() {
        me.valueChanged();
    },

    valueChanged: func() {
        me._view.filter(me.value);
    }
};

var _createCompatObjectLookupHash = {
    "button": XMLButton,
    "checkbox": XMLCheckbox,
    "slider": XMLSlider,
    "dial": XMLDial,
    "group": XMLGroup,
    "input": XMLTextEdit,
    "empty": XMLEmpty,
    "hrule": XMLHRule,
    "vrule": XMLVRule,
    "combo": XMLComboBox,
    "list": XMLList,
    "text": XMLLabel,
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

    return gui.xml.Object.new({
        parents: [widgetClass, XMLObjectBase]
    }, type);
};

logprint(LOG_INFO, "Loaded gui.XMLDialog");
