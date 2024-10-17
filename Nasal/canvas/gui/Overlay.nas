# SPDX-FileCopyrightText: (C) 2022 Frederic Croix <thefgfseagle@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.Overlay = {
	# Constructor
	#
	# @param size ([width, height])
	new: func(size_, id = nil) {
		var ghost = _newWindowGhost(id);
		var m = {
			parents: [gui.Overlay, PropertyElement, ghost],
			_ghost: ghost,
			_node: props.wrapNode(ghost._node_ghost),
			_widgets: [],
			_canvas: nil,
			_focused: 1,
		};

		m.setSize(size_);
		m._updateDecoration();

		# arg = [child, listener_node, mode, is_child_event]
		setlistener(m._node, func m._propCallback(arg[0], arg[2]), 0, 2);
		
		return m;
	},
	# Destructor
	del: func {
		if (me["_canvas"] != nil) {
			var placements = me._canvas._node.getChildren("placement");
			# Do not remove canvas if other placements exist
			if (size(placements) > 1) {
				foreach (var p; placements) {
					if (p.getValue("type") == "window" and p.getValue("id") == me.get("id")) {
						p.remove();
					}
				}
			} else {
				me._canvas.del();
			}
			me._canvas = nil;
		}
		if (me._node != nil) {
			me._node.remove();
			me._node = nil;
		}
	},
	# Create the canvas to be used for this Window
	#
	# @return The new canvas
	createCanvas: func() {
		var size = [
			me.get("content-size[0]"),
			me.get("content-size[1]")
		];
		
		me._canvas = new({
			size: [size[0], size[1]],
			view: size,
			placement: {
				type: "window",
				id: me.get("id")
			},
			
			# Standard alpha blending
			"blend-source-rgb": "src-alpha",
			"blend-destination-rgb": "one-minus-src-alpha",
			
			# Just keep current alpha (TODO allow using rgb textures instead of rgba?)
			"blend-source-alpha": "zero",
			"blend-destination-alpha": "one"
		});
		
		me._canvas._focused_widget = nil;
		me._canvas.data("focused", me._focused);
		
		return me._canvas;
	},
	# Set an existing canvas to be used for this Window
	setCanvas: func(canvas_) {
		if (ghosttype(canvas_) != "Canvas") {
			return debug.warn("Not a Canvas");
		}
		
		canvas_.addPlacement({type: "window", "id": me.get("id")});
		me['_canvas'] = canvas_;
		
		canvas_._focused_widget = nil;
		canvas_.data("focused", me._focused);
		
		return me;
	},
	# Get the displayed canvas
	getCanvas: func(create = 0) {
		if (me['_canvas'] == nil and create) {
			me.createCanvas();
		}
		
		return me['_canvas'];
	},
	setLayout: func(l) {
		if (me['_canvas'] == nil) {
			me.createCanvas();
		}
		
		me._canvas.update(); # Ensure placement is applied
		me._ghost.setLayout(l);
		return me;
	},
	setPosition: func {
		if (size(arg) == 1) {
			var arg = arg[0];
		}
		var (x, y) = arg;
		
		me.setInt("tf/t[0]", x);
		me.setInt("tf/t[1]", y);
		return me;
	},
	setSize: func {
		if (size(arg) == 1) {
			var arg = arg[0];
		}
		var (w, h) = arg;
		
		me.set("content-size[0]", w);
		me.set("content-size[1]", h);
		
		if (me["_canvas"] == nil) {
			print("canvas is nil");
			return;
		}

		for (var i = 0; i < 2; i += 1) {
			var size = me.get("content-size[" ~ i ~ "]");
			me._canvas.set("size[" ~ i ~ "]", size);
			me._canvas.set("view[" ~ i ~ "]", size);
		}
		
		return me;
	},
	getSize: func {
		var w = me.get("content-size[0]");
		var h = me.get("content-size[1]");
		return [w,h];
	},
	# Raise to top of window stack
	raise: func() {
		# on writing the z-index the window always is moved to the top of all other
		# windows with the same z-index.
		me.setInt("z-index", me.get("z-index", gui.STACK_INDEX["always-on-top"]));
	},
	hide: func(parents = 0) {
		me._ghost.hide();
	},
	show: func() {
		me._ghost.show();
		me.raise();
		if (me._canvas != nil) {
			me._canvas.update();
		}
	},
	# Hide / show the window based on whether it's currently visible
	toggle: func() {
		if (me.isVisible()) {
			me.hide();
		} else {
			me.show();
		}
	},
	_onStateChange: func {
		var event = canvas.CustomEvent.new("wm.focus-" ~ (me._focused ? "in" : "out"));
		
		if (me.getCanvas() != nil) {
			me.getCanvas().data("focused", me._focused).dispatchEvent(event);
		}
	},
	#mode 0 = value changed, +-1 add/remove node
	_propCallback: func(child, mode) {
		if (!me._node.equals(child.getParent())) {
			return;
		}
		var name = child.getName();
		
		# support for CSS like position: absolute; with right and/or bottom margin
		if (name == "right") {
			me._handlePositionAbsolute(child, mode, name, 0);
		} elsif (name == "bottom") {
			me._handlePositionAbsolute(child, mode, name, 1);
		}

		if (mode == 0) {
			if (name == "size") {
				me._resizeDecoration();
			}
		}
	},
	_handlePositionAbsolute: func(child, mode, name, index) {
		# mode
		#	 -1 child removed
		#		0 value changed
		#		1 child added

		if (mode == 0) {
			me._updatePos(index, name);
		} elsif (mode == 1) {
			me["_listener_" ~ name] = [
				setlistener(
					"/sim/gui/canvas/size[" ~ index ~ "]",
					func me._updatePos(index, name)
				),
				setlistener(
					me._node.getNode("content-size[" ~ index ~ "]"),
					func me._updatePos(index, name)
				)
			];
		} elsif (mode == -1) {
			for (var i = 0; i < 2; i += 1) {
				removelistener(me["_listener_" ~ name][i]);
			}
		}
	},
	_updatePos: func(index, name) {
		me.setInt(
			"tf/t[" ~ index ~ "]",
			getprop("/sim/gui/canvas/size[" ~ index ~ "]") - me.get(name) - me.get("content-size[" ~ index ~ "]")
		);
	},
	getCanvasDecoration: func() {
		return wrapCanvas(me._getCanvasDecoration());
	},
	_updateDecoration: func() {
		me.setBool("update", 1);

		#var canvas_deco = me.getCanvasDecoration();
		#var group_deco = canvas_deco.getGroup("decoration");

		me._resizeDecoration();
		me._onStateChange();
	},
	_resizeDecoration: func() {
	}
};


