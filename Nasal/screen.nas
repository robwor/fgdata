# on-screen displays
#==============================================================================


##
# convert string for output; replaces tabs by spaces, and skips
# delimiters and the voice part in "{text|voice}" constructions
#
var sanitize = func(s, newline = 0) {
	var r = "";
	var skip = 0;
	s ~= "";
	for (var i = 0; i < size(s); i += 1) {
		var c = s[i];
		if (c == `\t`)
			r ~= ' ';
		elsif (c == `{`)
			nil;
		elsif (c == `|`)
			skip = 1;
		elsif (c == `}`)
			skip = 0;
		elsif (c == `\n` and newline)
			r ~= "\\n";
		elsif (!skip)
			r ~= chr(c);
	}
	return r;
}

# screen.window
#------------------------------------------------------------------------------
# Class that manages a dialog with fixed number of lines, where you can push in
# text at the bottom, which then (optionally) scrolls up after some time.
#
# simple use:
#
#     var window = screen.window.new();
#     window.write("message in the middle of the screen");
#
#
# advanced use:
#
#     var window = screen.window.new(nil, -100, 3, 10);
#     window.fg = [1, 1, 1, 1];    # choose white default color
#     window.align = "left";
#
#     window.write("first line");
#     window.write("second line (red)", 1, 0, 0);
#
#
#
# arguments:
#            x ... x coordinate
#            y ... y coordinate
#                  positive coords position relative to the left/lower corner,
#                  negative coords from the right/upper corner, nil centers
#     maxlines ... max number of displayed lines; if more are pushed into the
#                  screen, then the ones on top fall off
#   autoscroll ... seconds that each line should be shown; can be less if
#                  a message falls off; if 0 then don't scroll at all
#
var Log = {
	new: func(x = nil, y = nil, maxlines = 10, autoscroll = 10) {
		var m = {
			parents: [window],
			_overlay: canvas.gui.Overlay.new([200, 100], "screen.window"),
			maxlines: maxlines,
			autoscroll: autoscroll,
			sticky: 0,
			bg: [0, 0, 0, 0],
			fg: [0.9, 0.4, 0.2, 1],
			_pos: [x, y],
			_align: "center",  # "left", "right", "center"
		};

		if (x == nil) {
			m._overlay.setPosition(nil, nil, nil, nil, 0);
		} elsif (x < 0) {
			m._overlay.setPosition(nil, nil, abs(x));
		} else {
			m._overlay.setPosition(x);
		}
		if (y == nil) {
			m._overlay.setPosition(nil, nil, nil, nil, 1);
		} elsif (y < 0) {
			m._overlay.setPosition(nil, abs(y));
		} else {
			m._overlay.setPosition(nil, nil, nil, y);
		}
		if (x == nil and y == nil) {
			m._overlay.setPosition(nil, nil, nil, nil, 2);
		}

		m._canvas = m._overlay.createCanvas();
		m._root = m._canvas.createGroup();
		m._layout = canvas.VBoxLayout.new();
		m._overlay.setLayout(m._layout);

		m._canvas.set("background", canvas._getColor(m.bg));
		m._canvas.set("blend-source-rgb", "src-color");
		m._canvas.set("blend-destination-rgb", "one-minus-src-color");
		m._canvas.set("blend-source-alpha", "one-minus-dst-alpha");
		m._canvas.set("blend-destination-alpha", "one");
		m._overlay.hide();

		if (m.autoscroll > 0) {
			m._autoscrollTimer = maketimer(1, func { m._autoscrollTimerCallback(); });
			m._autoscrollTimer.simulatedTime = 0;
		}

		return m;
	},
	del: func {
		if (me._autoscrollTimer != nil) {
			me._autoscrollTimer.stop();
			me._autoscrollTimer = nil;
		}
		me._overlay.del();
	},
	setBackgroundColor: func(color) {
		me.bg = color;
		me._canvas.setColorBackground(canvas._getColor(color));
		return me;
	},
	write: func(msg, r = nil, g = nil, b = nil, a = nil) {
		if (!me._overlay.isVisible()) {
			me.show();
		}
		if (r == nil)
			r = me.fg[0];
		if (g == nil)
			g = me.fg[1];
		if (b == nil)
			b = me.fg[2];
		if (a == nil)
			a = me.fg[3];
		var now = systime();
		foreach (var line; split("\n", string.trim(msg ~ ""))) {
			while (me._layout.count() >= me.maxlines) {
				me._layout.takeAt(0);
			}
			line = sanitize(string.trim(line));
			var label = canvas.gui.widgets.Label.new(parent: me._root, cfg: {
				"text": line,
				"color": canvas._getColor([r, g, b, a]),
				"text-align": me._align,
				"alignment": canvas.AlignTop,
				"font": canvas.style.getFont("message-display"),
			});
			me._layout.addItem(label);
			if (me.autoscroll > 0) {
				label._expiryTime = now + me.autoscroll;
			}
		}
		var s = me._layout.minimumSize();
		s[0] += 20;
		s[1] += 20;
		me._overlay.setSize(s);
	},
	clear: func {
		me._layout.clear();
		me.hide();
	},
	hide: func {
		if (me._autoscrollTimer != nil) {
			me._autoscrollTimer.stop();
		}
		me._overlay.hide();
	},
	show: func {
		me.setBackgroundColor(me.bg);
		if (me._autoscrollTimer != nil) {
			me._autoscrollTimer.start();
		}
		me._overlay.show();
	},
	_autoscrollTimerCallback: func {
		var now = systime();
		while (me._layout.count() > 0 and me._layout.itemAt(0)._expiryTime <= now) {
			me._layout.takeAt(0);
		}
		if (me._layout.count() == 0) {
			me.hide();
		}
	},
};
# For backwards compatibility
var window = Log;



# screen.display
#------------------------------------------------------------------------------
# Class that manages a dialog, which displays an arbitrary number of properties
# periodically updating the values. Property names are abbreviated to the
# shortest possible unique part.
#
# Example:
#
#     var dpy = screen.display.new(20, 10);    # x/y coordinate
#     dpy.setcolor(1, 0, 1);                   # magenta (default: white)
#     dpy.setfont("SANS_12B",12);              # see $FG_ROOT/gui/styles/*.xml
#
#     dpy.add("/position/latitude-deg", "/position/longitude-deg");
#     dpy.add(props.globals.getNode("/orientation").getChildren());
#
#
# The add() method takes one or more property paths or props.Nodes, or a vector
# containing those, or a hash with properties, or vectors with properties, etc.
# Internal "public" parameters may be set directly:
#
#     dpy.interval = 0;                        # update every frame
#     dpy.format = "%.3g";                     # max. 3 digits fractional part
#     dpy.tagformat = "%-12s";                 # align prop names to 12 spaces
#     dpy.redraw();                            # pick up new settings
#
#
# The open() method should only be used to undo a close() call. In all other
# cases this is done implicitly. redraw() is automatically called by an add(),
# but can be used to let the dialog pick up new settings of internal variables.
#
#
# Methods add(), setfont() and setcolor() can be appended to the new()
# constructor (-> show big yellow frame rate counter in upper right corner):
#
#     screen.display.new(-15, -5, 0).setfont("TIMES_24").setcolor(1, 0.9, 0).add("/sim/frame-rate");
#
var PropertyDisplay = {
	id: 0,
	new : func(x = nil, y = nil, show_tags = 1) {
		var m = {
			parents: [display],
			_overlay: canvas.gui.Overlay.new([200, 50]),
			tags: show_tags,
			fg: [1, 1, 1, 1],
			bg: [0, 0, 0, 0],
			tagformat: "%s",
			format: "%.12g",
			interval: 0,
			base: props.globals.getNode("/sim/gui/dialogs/property-display-" ~ (display.id += 1), 1),
			_pos: [x, y],
			_lines: [],
			entries: [],
		};

		if (x == nil) {
			m._overlay.setPosition(nil, nil, nil, nil, 0);
		} elsif (x < 0) {
			m._overlay.setPosition(nil, nil, abs(x));
		} else {
			m._overlay.setPosition(x);
		}
		if (y == nil) {
			m._overlay.setPosition(nil, nil, nil, nil, 1);
		} elsif (y < 0) {
			m._overlay.setPosition(nil, abs(y));
		} else {
			m._overlay.setPosition(nil, nil, nil, y);
		}
		if (x == nil and y == nil) {
			m._overlay.setPosition(nil, nil, nil, nil, 2);
		}

		m._canvas = m._overlay.createCanvas();
		m._root = m._canvas.createGroup();
		m._layout = canvas.VBoxLayout.new();
		m._overlay.setLayout(m._layout);

		m._canvas.set("background", canvas._getColor(m.bg));
		m._canvas.set("blend-source-rgb", "src-color");
		m._canvas.set("blend-destination-rgb", "one-minus-src-color");
		m._canvas.set("blend-source-alpha", "one-minus-dst-alpha");
		m._canvas.set("blend-destination-alpha", "one");
		m._overlay.hide();

		m._updateTimer = maketimer(m.interval, func { m.update(); });
		m._updateTimer.simulatedTime = 0;

		return m;
	},
	del: func {
		me._updateTimer.stop();
		me._overlay.del();
	},
	setBackgroundColor: func(color) {
		me.bg = color;
		me._canvas.setColorBackground(canvas._getColor(color));
		return me;
	},
	clear: func {
		me._layout.clear();
		me.hide();
	},
	hide: func {
		me._updateTimer.stop();
		me._overlay.hide();
	},
	show : func {
		me.setBackgroundColor(me.bg);
		me._updateTimerCallback.start();
		me._overlay.show();
	},
	setcolor: func(r, g, b, a = 1) {
		me.color = [r, g, b, a];
		me.redraw();
		return me;
	},
	setfont: func(font, size=14) {
		me.font = font;
		me.fontsize = size;
		return me;
	},
	# add() opens already, so call open() explicitly only after close()!
	open: func {
		me._overlay.show();
		me._updateTimer.start();
	},
	close: func {
		me._overlay.hide();
		me._updateTimer.stop();
	},
	toggle: func {
		if (!me._overlay.isVisible()) {
			me.open()
		} else {
			me.close();
		}
	},
	reset: func {
		me.close();
		me._layout.clear();
		me.entries = [];
	},
	redraw: func {
		me._updateTimer.stop();
		me._layout.clear();
		
		foreach (var entry; me.entries) {
			var type = entry.node.getType();
			var format = "%s";
			if (type == "DOUBLE" or type == "INT") {
				format = me.format;
			}
			if (me.tags) {
				format = entry.tag ~ " = " ~ format;
			}
			var label = canvas.gui.widgets.Label.new(parent: me._root, cfg: {
				"format": format,
				"color": me.fg,
				"text-align": "left",
				"alignment": canvas.AlignTop,
				"font": canvas.style.getFont("property-display"),
			});
			me._layout.addItem(label);
			entry["widget"] = label;
		}
		
		me._updateTimer.start();
	},
	add: func(p...) {
		foreach (nextprop; var n; props.nodeList(p)) {
			var path = n.getPath();
			foreach (var e; me.entries) {
				if (e.node.getPath() == path) {
					continue nextprop;
				}
				e.parent = e.node;
				e.tag = sprintf(me.tagformat, me.nameof(e.node));
			}
			append(me.entries, {
				node: n,
				parent: n,
				tag: sprintf(me.tagformat, me.nameof(n)),
				widget: nil
			});
		}

		# extend names to the left until they are unique
		while (me.tags) {
			var uniq = {};
			foreach (var e; me.entries) {
				if (contains(uniq, e.tag)) {
					append(uniq[e.tag], e);
				} else {
					uniq[e.tag] = [e];
				}
			}

			var done = 1;
			foreach (var u; keys(uniq)) {
				if (size(uniq[u]) == 1)
					continue;
				done = 0;
				foreach (var e; uniq[u]) {
					e.parent = e.parent.getParent();
					if (e.parent != nil) {
						e.tag = me.nameof(e.parent) ~ '/' ~ e.tag;
					}
				}
			}
			if (done) {
				break;
			}
		}
		me.redraw();
		me.open();
		
		return me;
	},
	update: func {
		foreach (var entry; me.entries) {
			var type = entry.node.getType();
			var val = entry.node.getValue();
			if (type == "NONE") {
				val = "nil";
			} elsif (type == "BOOL") {
				val = entry.node.getBoolValue() ? "true" : "false";
			} elsif (type == "STRING" or type == "UNSPECIFIED") {
				val = "'" ~ sanitize(entry.node.getValue(), 1) ~ "'";
			}
			entry["widget"].setValue(val);
		}
		var s = me._layout.minimumSize();
		s[0] += 20;
		s[1] += 20;
		me._overlay.setSize(s);
	},
	nameof: func(n) {
		var name = n.getName();
		if (var i = n.getIndex())
			name ~= '[' ~ i ~ ']';
		return name;
	},
};
# For backwards compatibility
var display = PropertyDisplay;

var listener = {};
var property_display = {
	add: func {
		logprint("screen.property_display.add: Property display was not initialized yet !");
	},
};
var log = {
	write: func {
		logprint("screen.log.write: Log was not initialized yet !");
	},
};
var controls = nil;

var search_name_in_msg = func(msg, call) {
	var matching = 0;
	var found = 0;
	for(var i = 0; i < size(msg); i = i + 1) {
		if (msg[i] == ` ` or msg[i] == `,` or msg[i] == `.` or msg[i] == `;` or msg[i] == `:` or msg[i] == `>`) {
			if (matching == size(call)) {
				found = 1;
				break;
			}
			matching = 0;
			continue;
		}
		if (matching >= size(call)) {
			matching = matching + 1;
			continue;
		}
		if (call[matching] == msg[i]) {
			matching = matching + 1;
		} else {
			matching = 0;
		}
	}
	if (found == 1 or matching == size(call))
		return 1;
	else
		return 0;
}
##############################################################################
# functions that make use of the window class (and don't belong anywhere else)
##############################################################################

# highlights messages with the multiplayer callsign in the text
var msg_mp = func (n) {
	if (!getprop("/sim/multiplay/chat-display"))
		return;
	var msg = string.lc(n.getValue());
	var call = string.lc(getprop("/sim/multiplay/callsign"));
	var highlight = getprop("/sim/multiplay/chat_highlight");
	if (search_name_in_msg(msg, call) or (highlight != nil and search_name_in_msg(msg, string.lc(highlight))))
		screen.log.write(n.getValue(), 1.0, 0.5, 0.5);
	else
		screen.log.write(n.getValue(), 0.82, 1, 0.59);
}

var msg_repeat = func {
	if (getprop("/sim/tutorials/running")) {
		var last = getprop("/sim/tutorials/last-message");
		if (last == nil)
			return;

		setprop("/sim/messages/pilot", "Say again ...");
		settimer(func setprop("/sim/messages/copilot", last), 1.5);

	} else {
		var last = atc.getValue();
		if (last == nil)
			return;

		setprop("/sim/messages/pilot", "This is " ~ callsign.getValue() ~ ". Say again, over.");
		settimer(func atc.setValue(atclast.getValue()), 6);
	}
}


var atc = nil;
var callsign = nil;
var atclast = nil;

_setlistener("/sim/signals/nasal-dir-initialized", func {
	_setlistener("/nasal/canvas/loaded", func(n) {
		# set /sim/screen/nomap=true to prevent default message mapping
		var nomap = getprop("/sim/screen/nomap");
		if (nomap != nil and nomap)
			return;

		callsign = props.globals.getNode("/sim/user/callsign", 1);
		atc = props.globals.getNode("/sim/messages/atc", 1);
		atclast = props.globals.getNode("/sim/messages/atc-last", 1);
		atclast.setValue("");

		# let ATC tell which runway was automatically chosen after startup/teleportation
		settimer(func {
			setlistener("/sim/atc/runway", func(n) { # set in src/Main/fg_init.cxx
				var rwy = n.getValue();
				if ((rwy == nil) or (rwy == ""))
					return;
				if ((var agl = getprop("/position/altitude-agl-ft")) != nil and agl > 100)
					return;
				screen.log.write("You are on runway " ~ rwy, 0.7, 1.0, 0.7);
			}, 1);
		}, 5);

		setlistener("/gear/launchbar/state", func(n) {
			if (n.getValue() == "Engaged")
				setprop("/sim/messages/copilot", "Engaged!");
		}, 0, 0);

		# map ATC messages to the screen log and to the voice subsystem
		var map = func(type, msg, r, g, b, cond = nil) {
			logprint(LOG_INFO, "{", type, "} ", msg);
			setprop("/sim/sound/voices/" ~ type, msg);

			if (cond == nil or cond())
				screen.log.write(msg, r, g, b);

			# save last ATC message for user callsign, unless this was already
			# a repetition; insert "I say again" appropriately
			if (type == "atc") {
				var cs = callsign.getValue();
				if (find(", I say again: ", atc.getValue()) < 0
						and (var pos = find(cs, msg)) >= 0) {
					var m = substr(msg, 0, pos + size(cs));
					msg = substr(msg, pos + size(cs));

					if ((pos = find("Tower, ", msg)) >= 0) {
						m ~= substr(msg, 0, pos + 7);
						msg = substr(msg, pos + 7);
					} else {
						m ~= ", ";
					}
					m ~= "I say again: " ~ msg;
					atclast.setValue(m);
					logprint(LOG_DEBUG, "ATC_LAST_MESSAGE: ", m);
				}
			}
		}

		var m = "/sim/messages/";
		listener.atc = setlistener(m ~ "atc",
				func(n) map("atc",      n.getValue(), 0.7, 1.0, 0.7));
		listener.approach = setlistener(m ~ "approach",
				func(n) map("approach", n.getValue(), 0.7, 1.0, 0.7));
		listener.ground = setlistener(m ~ "ground",
				func(n) map("ground",   n.getValue(), 0.7, 1.0, 0.7));

		listener.pilot = setlistener(m ~ "pilot",
				func(n) map("pilot",    n.getValue(), 1.0, 0.8, 0.0));
		listener.copilot = setlistener(m ~ "copilot",
				func(n) map("copilot",  n.getValue(), 1.0, 1.0, 1.0));
		listener.ai_plane = setlistener(m ~ "ai-plane",
				func(n) map("ai-plane", n.getValue(), 0.9, 0.4, 0.2));
		listener.mp_plane = setlistener(m ~ "mp-plane", msg_mp);
		#-- Init -----------------------------------------------------------------------
		if (getprop("/sim/gui/chat-box-location") == "left") {
		    property_display = display.new(5, -50);
		} else {
		    property_display = display.new(5, -50);
		}

		if (getprop("/sim/gui/chat-box-location") == "left") {
		    log = window.new(5, -30, 10, 10);
		    log._align = "left";
		} else {
		    log = window.new(nil, -30, 10, 10);
		}
		log.sticky = 0;  # do not turn on; makes scrolling up messages jump left and right
	});
});

var b = "/sim/screen/";
setlistener(b ~ "black",   func(n) log.write(n.getValue(), 0,   0,   0));
setlistener(b ~ "white",   func(n) log.write(n.getValue(), 1,   1,   1));
setlistener(b ~ "red",     func(n) log.write(n.getValue(), 0.8, 0,   0));
setlistener(b ~ "green",   func(n) log.write(n.getValue(), 0,   0.6, 0));
setlistener(b ~ "blue",    func(n) log.write(n.getValue(), 0,   0,   0.8));
setlistener(b ~ "yellow",  func(n) log.write(n.getValue(), 0.8, 0.8, 0));
setlistener(b ~ "magenta", func(n) log.write(n.getValue(), 0.7, 0,   0.7));
setlistener(b ~ "cyan",    func(n) log.write(n.getValue(), 0,   0.6, 0.6));

setlistener("/sim/gui/current-style", func {
    theme_font = getprop("/sim/gui/selected-style/fonts/message-display/name");
}, 1);

# --prop:display=sim/frame-rate         ... adds this property to the property display
# --prop:display=position/              ... adds all properties under /position/  (ends with slash!)
# --prop:display=position/,orientation/ ... separate multiple properties with comma
#
var fdm_init_listener = _setlistener("/sim/signals/fdm-initialized", func {
	removelistener(fdm_init_listener); # uninstall, so we are only called once
	foreach (var n; props.globals.getChildren("display")) {
		foreach (var p; split(",", n.getValue())) {
			if (!size(p))
				continue;
			if (find('%', p) >= 0)
				property_display.format = p;
			elsif (p[-1] == `/`)
				property_display.add(props.globals.getNode(p, 1).getChildren());
			else
				property_display.add(p);
		}
	}
	props.globals.removeChildren("display");
});
