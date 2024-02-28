# Multiplayer
# ===========
#
# 1) Display chat messages from other aircraft to
#    the screen using screen.nas
#
# 2) Display a complete history of chat via dialog.
#
# 3) Allow chat messages to be written by the user.

var lastmsg = {};
var msg_loop_id = 0;
var msg_timeout = 0;
var log_file = nil;
var log_listeners = [];

var check_messages = func(loop_id) {
    if (loop_id != msg_loop_id) return;
    foreach (var mp; values(model.callsign)) {
        var msg = mp.node.getNode("sim/multiplay/chat", 1).getValue();
        if (msg and msg != lastmsg[mp.callsign]) {
            if (!mp.node.getBoolValue("controls/invisible", 0))
                echo_message(mp.callsign, msg);
            lastmsg[mp.callsign] = msg;
        }
    }
    settimer(func check_messages(loop_id), 1);
}

var echo_message = func(callsign, msg) {
    msg = string.trim(string.replace(msg, "\n", " "));

    # Only prefix with the callsign if the message doesn't already include it.
    if (find(callsign, msg) < 0)
        msg = callsign ~ ": " ~ msg;

    setprop("/sim/messages/mp-plane", msg);

    # Add the chat to the chat history.
    if (var history = getprop("/sim/multiplay/chat-history"))
        msg = history ~ "\n" ~ msg;

    setprop("/sim/multiplay/chat-history", msg);
}

var timeout_handler = func()
{
    var t = props.globals.getNode("/sim/time/elapsed-sec").getValue();
    if (t >= msg_timeout)
    {
        msg_timeout = 0;
        setprop("/sim/multiplay/chat", "");
    }
    else
        settimer(timeout_handler, msg_timeout - t);
}

var chat_listener = func(n)
{
    var msg = n.getValue();
    if (msg)
    {
        # ensure we see our own messages.
        echo_message(getprop("/sim/multiplay/callsign"), msg);

        # set expiry time
        if (msg_timeout == 0)
            settimer(timeout_handler, 10); # need new timer
        msg_timeout = 10 + props.globals.getNode("/sim/time/elapsed-sec").getValue();
    }
}



# Message composition function, activated using the - key.
var prefix = "Chat Message:";
var input = "";
var kbdlistener = nil;

var my_kbd_listener = func(event)
{
  var key = event.getNode("key");

  # Only check the key when pressed.
  if (!event.getNode("pressed").getValue())
    return;

  if (handle_key(key.getValue()))
    key.setValue(-1);           # drop key event
}

var capture_kbd = func()
{
  if (kbdlistener == nil) {
    kbdlistener = setlistener("/devices/status/keyboard/event", my_kbd_listener);
  }
}

var release_kbd = func()
{
  if (kbdlistener != nil) {
    removelistener(kbdlistener);
    kbdlistener = nil;
  }
}
var compose_message = func(msg = "")
{
  input = prefix ~ msg;
  gui.popupTip(input, 1000000);
  capture_kbd();
}

var end_compose_message = func()
{
  gui.popdown();
  release_kbd();
}

var view_select = func(callsign)
{
    view.model_view_handler.select(callsign, 1);
}

var handle_key = func(key)
{
  if (key == `\n` or key == `\r` or key == `~`)
  {
    # CR/LF -> send the message

    # Trim off the prefix
    input = substr(input, size(prefix));
    # Send the message and switch off the listener.
    setprop("/sim/multiplay/chat", input);
    end_compose_message();
    return 1;
  }
  elsif (key == 8)
  {
    # backspace -> remove a character

    if (size(input) > size(prefix))
    {
      input = substr(input, 0, size(input) - 1);
      gui.popupTip(input, 1000000);
    }

    # Always handle key so excessive backspacing doesn't toggle the heading autopilot
    return 1;
  }
  elsif (key == 27)
  {
    # escape -> cancel
    end_compose_message();
    return 1;
  }
  elsif ((key > 31) and (key < 128))
  {
    # Normal character - add it to the input
    input ~= chr(key);
    gui.popupTip(input, 1000000);
    return 1;
  }
  else
  {
    # Unknown character - pass through
    return 0;
  }
}



# @description Dialog for viewing and managing multiplayer pilots (allows viewing other pilot's aircraft models, ignoring aircraft etc.)

var PilotsListDialog = {
    PilotColor: {
        AircraftNotInstalled: [1, 0.7, 0, 1],
        AircraftFallbackProvided: [0.557, 0.847, 0.463, 1],
        AircraftInstalled: [0.9, 0.9, 0.2, 1],
    },
    UpdateInterval: 0.5,
    _position: [-1, -1],
    _defaultSize: [500, 100],
    _size: [-1, -1],
    _instance: nil,

    open: func {
        if (PilotsListDialog._instance == nil) {
            PilotsListDialog._instance = PilotsListDialog.new();
        } else {
            if (PilotsListDialog._instance.window == nil) {
                PilotsListDialog._instance.del();
                PilotsListDialog._instance = PilotsListDialog.new();
            }
            PilotsListDialog._instance.window.raise();
        }
    },

    toggle: func {
        if (PilotsListDialog._instance == nil) {
            PilotsListDialog.open();
        } else {
            PilotsListDialog._instance.del();
        }
    },

    new: func {
        var m = {
            parents: [PilotsListDialog],
            mode: nil,
            cs_warnings: {},
            listeners: [],
            distNodePath: "",
            altNodePath: "",
            distText: "",
            altText: "",
            lockPositionAndSize: 0,
        };

        m.window = canvas.Window.new([500, 100], "dialog")
                        .setTitle("Multiplayer aircraft")
                        .set("resize", 1);
        m.window.onClose = func m.del();
        m.root = m.window.getCanvas(1)
                        .set("background", canvas.style.getColor("bg_color"))
                        .set("opacity", 0.6)
                        .createGroup();
        m.layout = canvas.VBoxLayout.new();
        m.window.setLayout(m.layout);

        m.build();
        m.select_mode("imperial");

        globals.MainWindow.addSizeChangedCallback(func m._mainwindowSizeChangedCallback());
        m._mainwindowSizeChangedCallback();
        m.updateTimer = maketimer(PilotsListDialog.UpdateInterval, func { m.update(); });
        m.updateTimer.simulatedTime = 1;
        m.updateTimer.start();

        m.update();
        m.update_view();

        append(m.listeners, setlistener("/sim/signals/multiplayer-updated", func m._redraw()));
        #append(m.listeners, setlistener("/sim/signals/reinit-gui", func m._redraw()));
        append(m.listeners, setlistener("/sim/current-view/model-view", func m.update_view()));

        return m;
    },
    _mainwindowSizeChangedCallback: func {
            me.resize(me._size);
            me.move(me._position);
    },
    move: func {
        if (size(arg) == 0 or arg[0] == nil) {
            var (x, y) = [-1, -1];
        } elsif (size(arg) == 1) {
            var (x, y) = arg[0];
        } else {
            var (x, y) = arg;
        }

        me._pos = [x, y];
        if (x < 0) {
            x = globals.MainWindow.getWidth() - (me._size[0] > 0 ? me._size[0] : me.window.getSize()[0]);
        }
        if (y < 0) {
            y = 0;
        }
        me.window.setPosition(x, y);
    },
    resize: func {
        if (size(arg) == 0 or arg[0] == nil) {
            var (w, h) = [-1, -1];
        } elsif (size(arg) == 1) {
            var (w, h) = arg[0];
        } else {
            var (w, h) = arg;
        }

        me._size = [w, h];
        if (w < 0) {
            w = math.min(me._size[0] > 0 ? me._size[0] : me.window.getSize()[0], globals.MainWindow.getWidth());
        }
        if (h < 0) {
            h = math.min(me._size[1] > 0 ? me._size[0] : me.window.getSize()[1], globals.MainWindow.getHeight());
        }
        me.window.setSize(w, h)
    },
    build: func {
        me.controlsLayout = canvas.HBoxLayout.new();
        me.controlsLayout.setAlignment(canvas.AlignTop);
        me.layout.addItem(me.controlsLayout);

        me.viewSelfButton = canvas.gui.widgets.Button.new(parent: me.root, cfg: {
            "text": "View self",
            "alignment": canvas.AlignLeft,
        })
                        .listen("clicked", func {
                            view.model_view_handler.select(props.globals.getValue("/sim/multiplayer/callsign"), 1);
                        });
        me.controlsLayout.addItem(me.viewSelfButton);

        me.modeLabel = canvas.gui.widgets.Label.new(parent: me.root, cfg: {
            "text": "Mode:",
        });
        me.controlsLayout.addItem(me.modeLabel);
        me.modeBox = canvas.gui.widgets.ComboBox.new(parent: me.root, cfg: {
            "items": {
                "Imperial units": "imperial",
                "Metric units": "metric",
                "Lag": "lag",
            },
        })
                        .listen("selected-item-changed", func(e) {
                            me.select_mode(e.detail.value);
                        });
        me.controlsLayout.addItem(me.modeBox);

        me.pilotsOnlineLabel = canvas.gui.widgets.PropertyLabel.new(parent: me.root, cfg: {
            "text": "%d pilots online",
            "node": props.globals.getNode("/ai/models/num-players"),
        });
        me.controlsLayout.addItem(me.pilotsOnlineLabel);

        me.lockPositionAndSizeButton = canvas.gui.widgets.Button.new(parent: me.root, cfg: {
            "text": "Lock",
            "alignment": canvas.AlignRight,
            "checkable": 1,
        })
                        .listen("toggled", func(e) {
                            me.lockPositionAndSize = e.detail.checked;
                        });
        me.controlsLayout.addItem(me.lockPositionAndSizeButton);

        me.closeButton = canvas.gui.widgets.Button.new(parent: me.root, cfg: {
        	"text": "Close",
        	"alignment": canvas.AlignRight,
        })
                        .listen("toggled", func(e) {
                            PilotsListDialog._instance.del();
                        });
        me.controlsLayout.addItem(me.closeButton);

        me.scroll = canvas.gui.widgets.ScrollArea.new(parent: me.root);
        me.layout.addItem(me.scroll);

        me.scrollLayout = canvas.GridLayout.new();
        me.scrollLayout.setSpacing(3);
        me.scroll.setLayout(me.scrollLayout);

        me.buildPilotsList();
    },
    buildPilotsList: func {
        var row = 0;
        var col = 0;
        # First row is column headers.
        var headers = ["See", "Callsign", "Model", me.distText, nil, me.altText, nil, "Brg", "Chat", "Ign", "XPDR", "Ver", "Apt", "Set"];
        me.headerLabels = {};
        foreach (var h; headers) {
            if (!h) {
                col += 1;
                continue;
            }
            me.headerLabels[string.lc(h)] = canvas.gui.widgets.Label.new(parent: me.scroll.getContent(), cfg: {
                "text": h,
            });
            var colspan = 1;
            if (col < size(headers) - 1 and headers[col + 1] == nil) {
                colspan = 2;
            }
            me.scrollLayout.addItem(me.headerLabels[string.lc(h)], col, row, colspan, 1);
            #me.scrollLayout.addItem(
            #    canvas.gui.widgets.HorizontalRule.new(parent: me.scroll.getContent()),
            #    col, row + 1,
            #);
            col += 1;
        }
        row += 2;
        me.columns = [
            {type: "radio", property: "view", callback: func(callsign) {
                multiplayer.view_select(callsign);
            }},
            {type: "text", property: "callsign", format: "%s"},
            {type: "text", property: "model-short", format: "%s"},
            {type: "text", property: me.distNodePath, format:"%8.2f"},
            {type: "text", property: "distance_delta", format: "%s"},
            {type: "text", property: me.altNodePath, format: "%7.0f"},
            {type: "text", property: "ascent_descent", format: "%s"},
            {type: "text", property: "bearing-to", format: "%3.0f"},
            {type: "button", callback: func(callsign) {
                multiplayer.compose_message(callsign);
            }},
            {type: "checkbox", property: "controls/invisible", enabled: 1, callback: func},
            {type: "text", property: "id-code", format: "%s"},
            {type: "text", property: "sim/multiplay/protocol-version", format: "%s"},
            {type: "text", property: "airport-id", format: "%s"},
            {type: "checkbox", property: "set-loaded", enabled: 0, callback: func},
        ];

        var viewingRadioButtonsGroup = canvas.gui.widgets.RadioButtonsGroup.new();
        # Add a row for each multiplayer aircraft.
        foreach (var mp; model.list) {
            var col = 0;
            var color = PilotsListDialog.PilotColor.AircraftNotInstalled;
            if (mp.node.getNode("model-installed").getValue()) {
                color = PilotsListDialog.PilotColor.AircraftInstalled;
            } else {
                if (var fbn = mp.node.getNode("sim/model/fallback-model-index")) {
                    if (fbn.getValue() > 0) {
                        color = PilotsListDialog.PilotColor.AircraftFallbackProvided;
                    }
                }
            }
            foreach (var column; me.columns) {
                var w = nil;
                if (column.type == "button") {
                    (func {
                        var callsign = mp.callsign;
                        var callback = column.callback;
                        w = canvas.gui.widgets.Button.new(parent: me.scroll.getContent(), cfg: {"fixed-size": [20, 20]})
                                        .listen("clicked", func(e) {
                                            callback(callsign);
                                        });
                    })();
                } else {
                    var p = column.property;
                    if (column.type == "text") {
                        w = canvas.gui.widgets.PropertyLabel.new(parent: me.scroll.getContent(), cfg: {
                            "node": mp.node.getNode(p, 1),
                            "text": column.format,
                            "alignment": canvas.AlignRight,
                        });
                       w._view._text.setColor([color[0], color[1], color[2], color[3]]);
                    } elsif (column.type == "radio") {
                        (func {
                            var callsign = mp.callsign;
                            var callback = column.callback;
                            w = canvas.gui.widgets.PropertyRadioButton.new(parent: me.scroll.getContent(), cfg: {
                                "node": mp.node.getNode(p, 1),
                                "radio-button-group": viewingRadioButtonsGroup,
                                "fixed-size": [20, 20],
                            })
                                            .listen("checked", func {
                                                callback(callsign);
                                            });
                        })();
                    } elsif (column.type == "checkbox") {
                        (func {
                            var callsign = mp.callsign;
                            var callback = column.callback;
                            w = canvas.gui.widgets.PropertyCheckBox.new(parent: me.scroll.getContent(), cfg: {
                                "node": mp.node.getNode(p, 1),
                                "enabled": column.enabled,
                                "fixed-size": [20, 20],
                            })
                                            .listen("toggled", func(e) {
                                                callback(callsign);
                                            });
                        })();
                    }
                }

                me.scrollLayout.addItem(w, col, row);
                col += 1;
            }
            row += 1;
        }
    },
    update_view: func() {
        # We are called when the aircraft being viewed has changed. We update
        # the boxes in the 'view' column so that only the one for the aircraft
        # being viewed is checked. If the user's aircraft is being viewed, none
        # of these boxes will be checked.
        var callsign = getprop("/sim/current-view/model-view");
        
        # Update Pilot View checkboxes.
        foreach (var mp; model.list) {
            mp.node.setValues({'view': mp.callsign == callsign});
        }
        
        # Update actual view.
        view.model_view_handler.select(callsign, 1);
    },
    update: func {
        var self = geo.aircraft_position();
        foreach (var mp; model.list) {
            var n = mp.node;
            var x = n.getNode("position/global-x").getValue();
            var y = n.getNode("position/global-y").getValue();
            var z = n.getNode("position/global-z").getValue();
            var ac = geo.Coord.new().set_xyz(x, y, z);
            var distance = nil;
            var idcode = n.getNode("instrumentation/transponder/transmitted-id").getValue();

            if (idcode == nil or idcode < 0) {
                idcode = "----";
            } else {
                idcode = sprintf("%04d", idcode);
            }

            call(func distance = self.distance_to(ac), nil, var err = []);

            if ((size(err))or(distance==nil)) {
                # Oops, have errors. Bogus position data (and distance==nil).
                if (me.cs_warnings[mp.callsign]!=1) {
                    # report each callsign once only (avoid cluttering)
                    me.cs_warnings[mp.callsign] = 1;
                    logprint(LOG_WARN, "Received invalid position data: " ~ debug._error(mp.callsign));
                }
                #    debug.printerror(err);
                #    debug.dump(self, ac, mp);
                #    debug.tree(mp.node);
            }
            else
            {
                # Node with valid position data (and "distance!=nil").
                
                # For 'set-loaded' column, we find whether the 'set' has more
                # than just the 'sim' child (which we always create even if
                # we couldn't load the -set.xml, in order to provide default
                # values for views' config/z-offset-m values).
                var set_loaded = 0;
                if (var set_node = n.getNode("set")) {
                    set_loaded = (size(set_node.getChildren()) >= 2);
                }
                
                var airport_id = "----";
                if (var airport_id_node = n.getNode("sim/tower/airport-id")) {
                    airport_id = airport_id_node.getValue();
                }
                
                var ascent_descent = "";
                if (var ascent_descent_node = n.getNode("velocities/vertical-speed-fps")) {
                    ascent_descent = ascent_descent_node.getValue();
                    ascent_descent = sprintf("%+4d", ascent_descent);
                }
                
                var distance_delta_text = "";
                if (var distance_km_old_node = n.getNode("distance-to-km")) {
                    var distance_delta = distance - distance_km_old_node.getValue() * 1000;
                    distance_delta_text = sprintf("%+6.2f", distance_delta);
                }
                n.setValues({
                    "model-short": mp.modelInstallNode.getValue() ? mp.model : "[" ~ mp.model ~ "]",
                    "set-loaded": set_loaded,
                    "bearing-to": self.course_to(ac),
                    "distance-to-km": distance / 1000.0,
                    "distance-to-nm": distance * M2NM,
                    "distance_delta": me.mode != "lag" ? distance_delta_text : "",
                    "position/altitude-m": mp.altitudeNode.getValue() * FT2M,
                    "ascent_descent": me.mode != "lag" ? ascent_descent : "",
                    "id-code": idcode,
                    "airport-id": airport_id,
                    "lag/lag-mod-averaged-ms": (mp.lagModAveragedNode.getDoubleValue() or 0) * 1000,
                });
            }
        }
        if (!me.lockPositionAndSize) {
            me.scroll.setSizeHint(me.scrollLayout.sizeHint());
            me.window.setSize(me.layout.sizeHint());
            me.move(me._position);
        }
    },
    _redraw: func {
        if (me.window != nil) {
            me.scrollLayout.clear();
            me.buildPilotsList();
        }
    },
    select_mode: func(mode) {
        if (mode == me.mode) {
            return;
        }
        if (mode == "metric") {
            me.altNodePath = "position/altitude-m";
            me.distNodePath = "distance-to-km";
            me.altText = "Altitude (m)";
            me.distText = "Distance (km)";
        } elsif (mode == "imperial") {
            me.altNodePath = "position/altitude-ft";
            me.distNodePath = "distance-to-nm";
            me.altText = "Altitude (ft)";
            me.distText = "Distance (nm)";
        } else {
            me.altNodePath = "lag/lag-mod-averaged-ms";
            me.distNodePath = "lag/pps-averaged";
            me.altText = "Lag (ms)";
            me.distText = "Lag (pps)";
        }
        me.mode = mode;
        me.modeBox.setSelectedByValue(mode);
        me._redraw();
    },
    del: func {
        if (me.window != nil) {
            var pos = me.window.getPosition();
            me.x = pos[0];
            me.y = pos[1];
            for (var i = 0; i < me.scrollLayout.count(); i += 1) {
                me.scrollLayout.takeAt(i);
            }
            me.window.del();
            me.window = nil;
        }
        globals.MainWindow.removeSizeChangedCallback(me._mainwindowSizeChangedCallback);
        me.updateTimer.stop();
        foreach (var l; me.listeners) {
            removelistener(l);
        }
        PilotsListDialog._instance = nil;
    },
};



# Autonomous singleton class that monitors multiplayer aircraft,
# maintains data in various structures, and raises signal
# "/sim/signals/multiplayer-updated" whenever an aircraft
# joined or left. Available data containers are:
#
#   multiplayer.model.data:        hash, key := /ai/models/~ path
#   multiplayer.model.callsign     hash, key := callsign
#   multiplayer.model.list         vector, sorted alphabetically (ASCII, case insensitive)
#
# All of them contain hash entries of this form:
#
# {
#    callsign: "BiMaus",
#    path: "Aircraft/bo105/Models/bo105.xml",      # relative file path
#    root: "/ai/models/multiplayer[4]",            # root property
#    node: {...},        # root property as props.Node hash
#    model: "bo105",     # model name (extracted from path)
#    sort: "bimaus",     # callsign in lower case (for sorting)
# }
#
var model = {
    init: func {
        me.L = [];
        append(me.L, setlistener("ai/models/model-added", func(n) {
            # Defer update() to the next convenient time to allow the
            # new MP entry to become fully initialized.
            settimer(func me.update(n.getValue()), 0);
        }));
        append(me.L, setlistener("ai/models/model-removed", func(n) {
            # Defer update() to the next convenient time to allow the
            # old MP entry to become fully deactivated.
            settimer(func me.update(n.getValue()), 0);
        }));
        me.update();
    },
    update: func(n = nil) {
        var changedNode = props.globals.getNode( n, 1 );
        if (n != nil and changedNode.getName() != "multiplayer")
            return;

        me.data = {};
        me.callsign = {};

        foreach (var n; props.globals.getNode("ai/models", 1).getChildren("multiplayer")) {
            if ((var valid = n.getNode("valid")) == nil or (!valid.getValue()))
                continue;
            if ((var callsign = n.getNode("callsign")) == nil or !(callsign = callsign.getValue()))
                continue;
            if (!(callsign = string.trim(callsign)))
                continue;

            var path = n.getNode("sim/model/path").getValue();
            var model = split(".", split("/", path)[-1])[0];
            model = me.remove_suffix(model, "-model");
            model = me.remove_suffix(model, "-anim");

            var root = n.getPath();
            var data = {
                        node: n,
                        callsign: callsign,
                        model: model,
                        root: root,
                        sort: string.lc(callsign),
                        modelInstallNode : n.getNode("model-installed",1),
                        altitudeNode : n.getNode("position/altitude-ft",1),
                        lagModAveragedNode: n.getNode("lag/lag-mod-averaged",1),
                        };

            me.data[root] = data;
            me.callsign[callsign] = data;
        }

        me.list = sort(values(me.data), func(a, b) cmp(a.sort, b.sort));

        setprop("ai/models/num-players", size(me.list));
        setprop("sim/signals/multiplayer-updated", 1);
    },
    remove_suffix: func(s, x) {
        var len = size(x);
        if (substr(s, -len) == x)
            return substr(s, 0, size(s) - len);
        return s;
    },
};

var mp_mode_changed = func(n) {
    var is_online = getprop("/sim/multiplay/online");
    var is_replaying = getprop("/sim/replay/replay-state");
    
    # Always activate multiplayer items if we are replaying, in case the
    # recording contains MP info.
    #
    foreach (var menuitem; ["mp-chat","mp-chat-menu","mp-list","mp-carrier"])
    {
        gui.menuEnable(menuitem, is_online or is_replaying);
    }

    if (is_online or is_replaying) {
        if (getprop("/sim/multiplay/write-message-log") and (log_file == nil)) {
            var t = props.globals.getNode("/sim/time/real");
            if (t == nil)
            {
                # not ready yet, delay...
                settimer(func mp_mode_changed(n), 0.1);
            }
            else
            {
                t = t.getValues();
                var ac = getprop("/sim/aircraft");
                var cs = getprop("/sim/multiplay/callsign");
                var apt = airportinfo().id;
                var file = string.normpath(getprop("/sim/fg-home") ~ "/mp-message.log");

                log_file = io.open(file, "a");
                io.write(log_file, sprintf("\n=====  %s %04d/%02d/%02d\t%s\t%s\t%s\n",
                    ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][t.weekday],
                    t.year, t.month, t.day, apt, ac, cs));
                io.flush(log_file);

                append(log_listeners, setlistener("/sim/signals/exit", func io.write(log_file, "=====  EXIT\n") and io.close(log_file)));
                append(log_listeners, setlistener("/sim/messages/mp-plane", func(n) {
                    io.write(log_file, sprintf("%02d:%02d  %s\n",
                        getprop("/sim/time/real/hour"),
                        getprop("/sim/time/real/minute"),
                        n.getValue()));
                    io.flush(log_file);
                }));
            }
        }
        check_messages(msg_loop_id += 1);
    }
    else
    {
        # stop message loop
        msg_loop_id += 1;
        if (log_file != nil)
        {
            io.write(log_file, "=====  DISCONNECT\n");
            io.flush(log_file);
            io.close(log_file);
            log_listeners = [];
            log_file = nil;
            foreach (var l; log_listeners)
                removelistener(l);
        }
    }
}

model.init();
setlistener("/sim/multiplay/online", mp_mode_changed, 1, 1);
setlistener("/sim/replay/replay-state", mp_mode_changed, 1, 1);

# Call-back to ensure we see our own messages.
setlistener("/sim/multiplay/chat", chat_listener);

if (getprop("/sim/presets/avoided-mp-runway")) {
    setlistener("/sim/sceneryloaded", func {
      gui.popupTip("Multi-player enabled, start moved to runway hold short position.");
    });
}
