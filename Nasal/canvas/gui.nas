#
# FlightGear canvas gui
# Namespace:    canvas
#
# Classes: 
#   WindowButton
#   Window
#
# see also api.nas


var gui = {
  widgets: {},
  focused_window: nil,
  open_popups: [],
  region_highlight: nil,

  # Window/dialog stacking order
  STACK_INDEX: {
    "default": 0,
    "always-on-top": 1,
    "tooltip": 2
  }
};

var gui_dir = getprop("/sim/fg-root") ~ "/Nasal/canvas/gui/";
var loadGUIFile = func(file) io.load_nasal(gui_dir ~ file, "canvas");
var loadWidget = func(name) loadGUIFile("widgets/" ~ name ~ ".nas");
var loadDialog = func(name) loadGUIFile("dialogs/" ~ name ~ ".nas");

loadGUIFile("Config.nas");
loadGUIFile("Menu.nas");
loadGUIFile("MenuBar.nas");
loadGUIFile("Overlay.nas");
loadGUIFile("Popup.nas");
loadGUIFile("Style.nas");
loadGUIFile("Widget.nas");
loadGUIFile("styles/DefaultStyle.nas");

# widgets
loadWidget("Button");
loadWidget("CheckBox");
loadWidget("Dial");
loadWidget("Label");
loadWidget("LineEdit");
loadWidget("List");
loadWidget("MenuBar");
loadWidget("PropertyTree");
loadWidget("PropertyWidgets");
loadWidget("ScrollArea");
loadWidget("RadioButton");
loadWidget("Rule");
loadWidget("Slider");
loadWidget("Switch");
loadWidget("TabWidget");
loadWidget("ComboBox");

# standard dialogs
loadDialog("InputDialog");
loadDialog("MessageBox");
loadDialog("WidgetsFactoryDialog");
loadDialog("PropertyTreeBrowser");

var style = DefaultStyle.new("AmbianceClassic", "Humanity");
var WindowButton = {
  new: func(parent, name)
  {
    var m = {
      parents: [WindowButton, gui.widgets.Button.new(parent, nil, {"flat": 1})],
      _name: name
    };
    m._focus_policy = m.NoFocus;
    m._setView({_root: parent.createChild("image", "WindowButton-" ~ name)});
    return m;
  },
# protected:
  _onStateChange: func
  {
    var file = style._dir_decoration ~ "/" ~ me._name;
    var window_focus = me._windowFocus();
    file ~= window_focus ? "_focused" : "_unfocused";

    if( me._down )
      file ~= "_pressed";
    else if( me._hover )
      file ~= "_prelight";
    else if( window_focus )
      file ~= "_normal";

    me._view._root.set("src", file ~ ".png");
  }
};

var Window = {
  # Constructor
  #
  # @param size ([width, height])
  new: func(size = nil, type = nil, id = nil, allowfocus = 1, destroy_on_close = 1)
  {
    if (size == nil) {
      die("canvas.Window.new: size argument is null");
    }
    var ghost = _newWindowGhost(id);
    var m = {
      parents: [Window, PropertyElement, ghost],
      _allowfocus: allowfocus,
      _destroy_on_close: destroy_on_close,
      _ghost: ghost,
      _node: props.wrapNode(ghost._node_ghost),
      _focused: 0,
      _widgets: [],
      _frame_width: 4,
      _title_bar_height: 25,
      _title: nil,
    };

    m.setInt("content-size[0]", size[0]);
    m.setInt("content-size[1]", size[1]);
    m.setDouble("aspect-ratio", size[0]/size[1]);
    m.setBool("lock-aspect-ratio", 0);
    if (type == "window" or type == "dialog") {
      m.centerOnScreen();
    }
    
    if (destroy_on_close) {
      m.setFocus();
    } else {
      m._ghost.hide();
    }

    # arg = [child, listener_node, mode, is_child_event]
    setlistener(m._node, func m._propCallback(arg[0], arg[2]), 0, 2);
    m.set("type", type or "window");

    return m;
  },
  # Destructor
  del: func
  {
    if (me["_title"] != nil)
        me._title.del();
    me.clearFocus();

    if( me["_canvas"] != nil )
    {
      var placements = me._canvas._node.getChildren("placement");
      # Do not remove canvas if other placements exist
      if( size(placements) > 1 ) {
        foreach(var p; placements)
        {
          if(     p.getValue("type") == "window"
              and p.getValue("id") == me.get("id") )
            p.remove();
        }
      }
      else {
        me._canvas.del();
      }
      me._canvas = nil;
    }
    if (me._node != nil) {
      me._node.remove();
      me._node = nil;
    }
  },
  setTitle: func(title)
  {
    return me.set("title", title);
  },
  # Create the canvas to be used for this Window
  #
  # @return The new canvas
  createCanvas: func()
  {
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
    me._canvas.addEventListener("mousedown", func me.raise());

    return me._canvas;
  },
  # Set an existing canvas to be used for this Window
  setCanvas: func(canvas_)
  {
    if( ghosttype(canvas_) != "Canvas" )
      return debug.warn("Not a Canvas");

    canvas_.addPlacement({type: "window", "id": me.get("id")});
    me['_canvas'] = canvas_;

    canvas_._focused_widget = nil;
    canvas_.data("focused", me._focused);

    # prevent resizing if canvas is placed from somewhere else
    me.onResize = nil;
    return me;
  },
  # Get the displayed canvas
  getCanvas: func(create = 0)
  {
    if( me['_canvas'] == nil and create )
      me.createCanvas();

    return me['_canvas'];
  },
  getCanvasDecoration: func()
  {
    return wrapCanvas(me._getCanvasDecoration());
  },
  setLayout: func(l)
  {
    if( me['_canvas'] == nil )
      me.createCanvas();

    me._canvas.update(); # Ensure placement is applied
    me._ghost.setLayout(l);
    return me;
  },
  #
  setFocus: func
  {
    if( me._focused )
      return me;

    if( gui.focused_window != nil )
      gui.focused_window.clearFocus();

    if (!me._allowfocus) return me; # Make the window not take focus, so focus returns to FGFS

    me._focused = 1;
#    me.onFocusIn();
    me._onStateChange();
    gui.focused_window = me;
    setInputFocus(me);
    return me;
  },
  #
  clearFocus: func
  {
    if( !me._focused )
      return me;

    me._focused = 0;
#    me.onFocusOut();
    me._onStateChange();
    gui.focused_window = nil;
    setInputFocus(nil);
    return me;
  },
  setPosition: func(left=nil, top=nil, right=nil, bottom=nil, center=nil)
  {
    if (typeof(left) == "vector") {
     if (size(left) == 2) {
        var (left, top) = left;
      } elsif (size(left) == 4) {
        var (left, top, right, bottom) = left;
      } else {
        die("canvas.Window.setPosition called with a vector as first argument, which is of unsupported length " ~ size(left));
      }
    }
    if (typeof(top) == "vector") {
      if (size(top) == 2) {
        var (right, bottom) = top;
      } else {
        die("canvas.Window.setPosition called with a vector as second argument, which is of unsupported length " ~ size(top));
      }
    }

    if (left != nil) {
      me.setInt("tf/t[0]", left);
      me._node.removeChild("right");
    }
    if (top != nil) {
      me.setInt("tf/t[1]", top);
      me._node.removeChild("bottom");
    }
    if (right != nil) {
      me.setInt("right", right);
    }
    if (bottom != nil) {
      me.setInt("bottom", bottom);
    }
    if (center != nil) {
      me.set("center", center);
    } else {
      me._node.removeChild("center");
    }
    return me;
  },
  getPosition:  func {
    return [me.get("tf/t[0]"), me.get("tf/t[1]")];
  },
  getCSSPosition: func {
    var top = me.get("tf/t[0]");
    var left = me.get("tf/t[1]");
    var right = me.get("right");
    var bottom = me.get("bottom");
    return [top, left, bottom, right];
  },

  # @description Center window on screen
  # @param direction Optional[int] Flag to specify direction in which centering should happen
  #                                                         Valid values are:
  #                                                         * 0 = Center horizontally
  #                                                         * 1 = Center vertically
  #                                                         * 2 = Center in both directions
  # @return canvas.gui.Window This window to support method chaining
  centerOnScreen: func(direction=2) {
    var desktopSize = globals.MainWindow.getSize();
    var center = [(desktopSize[0] - me.getSize()[0]) / 2 - me._frame_width, (desktopSize[1] - me.getSize()[1] - me._title_bar_height) / 2];
    var pos = me.getPosition();
    if (direction == 0 or direction == 2) {
      pos[0] = center[0];
    }
    if (direction == 1 or direction == 2) {
      pos[1] = center[1];
    }
    me.setPosition(pos);

    return me;
  },
  setSize: func
  {
    if( size(arg) == 1 )
      var arg = arg[0];
    var (w, h) = arg;

    me.set("content-size[0]", w);
    me.set("content-size[1]", h);

    if( me.onResize != nil )
      me.onResize();

    me.setPosition(me.getCSSPosition(), me.get("center"));

    return me;
  },
  getSize: func
  {
    var w = me.get("content-size[0]");
    var h = me.get("content-size[1]");
    return [w,h];
  },
  move: func
  {
    if( size(arg) == 1 )
      var arg = arg[0];
    var (x, y) = arg;

    me.setInt("tf/t[0]", me.get("tf/t[0]", 10) + x);
    me.setInt("tf/t[1]", me.get("tf/t[1]", 30) + y);
    return me;
  },
  # Raise to top of window stack
  raise: func()
  {
    # on writing the z-index the window always is moved to the top of all other
    # windows with the same z-index.
    me.setInt("z-index", me.get("z-index", gui.STACK_INDEX["default"]));

    me.setFocus();
    
    foreach(var p; gui.open_popups) {
      p.hide();
    }
  },
  hide: func()
  {
    me.clearFocus();
    me._ghost.hide();
  },
  show: func()
  {
    me._ghost.show();
    me.raise();
    me._canvas.update();
  },
  # Hide / show the window based on whether it's currently visible
  toggle: func()
  {
    if (me.isVisible()) {
      me.hide();
    } else {
      me.show();
      me.raise();
    }
  },
  # function to be executed when the close button is pressed
  onClose: func()
  {
    if (me._destroy_on_close)
    {
      me.del();
    } else {
      me.hide();
    }
  },
  onResize: func()
  {
    if( me['_canvas'] == nil )
      return;

    for(var i = 0; i < 2; i += 1)
    {
      var size = me.get("content-size[" ~ i ~ "]");
      me._canvas.set("size[" ~ i ~ "]", size);
      me._canvas.set("view[" ~ i ~ "]", size);
    }
  },
  lockAspectRatio: func (lock=1) {
    me.setBool("lock-aspect-ratio", lock);
  },
# protected:
  _onStateChange: func
  {
    var event = canvas.CustomEvent.new("wm.focus-" ~ (me._focused ? "in" : "out"));

    if( me._getCanvasDecoration() != nil )
    {
      # Stronger shadow for focused windows
      me.getCanvasDecoration()
        .set("image[1]/fill", me._focused ? "#000000" : "rgba(0,0,0,0.5)");

      var suffix = me._focused ? "" : "-unfocused";
      me._title_bar_bg.set("fill", style.getColor("title" ~ suffix));
      me._frame.setStroke(style.getColor("title" ~ suffix));
      me._title.setColor(style.getColor("title-text" ~ suffix));
      me._top_line.setStroke(style.getColor("title-highlight" ~ suffix));

      me.getCanvasDecoration()
        .data("focused", me._focused)
        .dispatchEvent(event);
    }

    if( me.getCanvas() != nil )
      me.getCanvas()
        .data("focused", me._focused)
        .dispatchEvent(event);
  },
# private:
  #mode 0 = value changed, +-1 add/remove node
  _propCallback: func(child, mode)
  {
    if( !me._node.equals(child.getParent()) )
      return;
    var name = child.getName();

    # support for CSS like position: absolute; with right and/or bottom margin
    if( name == "right" )
      me._handlePositionAbsolute(child, mode, name, 0);
    elsif( name == "bottom" )
      me._handlePositionAbsolute(child, mode, name, 1);

    if (name == "center") {
      if (mode == 0 or mode == 1 and (var direction = child.getValue()) != -1) {
        me.centerOnScreen(direction);
      }
    }

    if (mode == 0) {
        if (name == "type") {
          me._updateDecoration();
        } elsif (name.starts_with("resize-")) {
          me._handleResize(child, name);
        } elsif (name == "size") {
          me._resizeDecoration();
        }
    }
  },
  _handlePositionAbsolute: func(child, mode, name, index)
  {
    # mode
    #   -1 child removed
    #    0 value changed
    #    1 child added

    if( mode == 0 )
      me._updatePos(index, name);
    else if( mode == 1 )
      me["_listener_" ~ name] = [
        setlistener
        (
          "/sim/gui/canvas/size[" ~ index ~ "]",
          func me._updatePos(index, name)
        ),
        setlistener
        (
          me._node.getNode("content-size[" ~ index ~ "]"),
          func me._updatePos(index, name)
        )
      ];
    else if( mode == -1 )
      for(var i = 0; i < 2; i += 1)
        removelistener(me["_listener_" ~ name][i]);
  },
  _updatePos: func(index, name)
  {
    me.setInt
    (
      "tf/t[" ~ index ~ "]",
      getprop("/sim/gui/canvas/size[" ~ index ~ "]")
      - me.get(name)
      - me.get("content-size[" ~ index ~ "]")
    );
  },
  _handleResize: func(child, name)
  {
    if (me.get("type") == "window" or me.get("type") == "dialog") {
      var is_status = name == "resize-status";
      if( !is_status and !me["_resize"] )
        return;

      var min_size = [75, 100];

      var x = me.get("tf/t[0]");
      var y = me.get("tf/t[1]");
      var old_size = [me.get("size[0]"), me.get("size[1]")];
      if (me.get("lock-aspect-ratio")) 
      {
        var old_csize = [me.get("content-size[0]"), me.get("content-size[1]")];
        var dx = old_size[0] - old_csize[0];
        var dy = old_size[1] - old_csize[1];
        var ar = me.get("aspect-ratio");

        if (name == "resize-right") 
          me.set("resize-bottom", (me.get("resize-right") - dx) / ar + dy);
        if (name == "resize-bottom") 
          me.set("resize-right", (me.get("resize-bottom") - dy)* ar + dx);

        if (name == "resize-left") 
          me.set("resize-top", (me.get("resize-left"))/ ar );
        if (name == "resize-top") 
          me.set("resize-left", (me.get("resize-top"))* ar );
      }

      var l = x + math.min(me.get("resize-left"), old_size[0] - min_size[0]);
      var t = y + math.min(me.get("resize-top"), old_size[1] - min_size[1]);
      var r = x + math.max(me.get("resize-right"), min_size[0]);
      var b = y + math.max(me.get("resize-bottom"), min_size[1]);
      if( is_status )
      {
        me._resize = child.getValue();

        if( me._resize and gui.region_highlight == nil )
          gui.region_highlight =
            getDesktop().createChild("path", "highlight")
                        .set("stroke", "#ffa500")
                        .set("stroke-width", 2)
                        .set("fill", "rgba(255, 165, 0, 0.15)")
                        .set("z-index", 100);
        else if( !me._resize and gui.region_highlight != nil )
        {
          gui.region_highlight.hide();
          me.setPosition(l, t);
          me.setSize
          (
            me.get("content-size[0]") + (r - l) - old_size[0],
            me.get("content-size[1]") + (b - t) - old_size[1],
          );
          if( me.onResize != nil )
            me.onResize();
          return;
        }
      }
      else if( !me["_resize"] )
        return;

      gui.region_highlight.reset()
                          .moveTo(l, t)
                          .horizTo(r)
                          .vertTo(b)
                          .horizTo(l)
                          .close()
                          .update()
                          .show();
    }
  },
  _updateDecoration: func()
  {
    if (me.get("type") == "window" or me.get("type") == "dialog") {
      var border_radius = 9;
      me.set("decoration-border", "25 1 1");
      me.set("shadow-inset", int((1 - math.cos(45 * D2R)) * border_radius + 0.5));
      me.set("shadow-radius", 5);
      me.setBool("update", 1);

      var canvas_deco = me.getCanvasDecoration();
      canvas_deco.addEventListener("mousedown", func me.raise());
      canvas_deco.set("blend-source-rgb", "src-alpha");
      canvas_deco.set("blend-destination-rgb", "one-minus-src-alpha");
      canvas_deco.set("blend-source-alpha", "one");
      canvas_deco.set("blend-destination-alpha", "one");

      var group_deco = canvas_deco.getGroup("decoration");
      var title_bar = group_deco.createChild("group", "title_bar");
      me._title_bar_bg = title_bar.createChild("path");
      me._top_line = title_bar.createChild("path", "top-line");
      me._frame = title_bar.createChild("path");
      me._frame.set("fill", "none");
      me._frame.set("stroke-width", me._frame_width);

      # close icon
      var x = 10;
      var y = 3;
      var w = 19;
      var h = 19;

      var button_close = WindowButton.new(title_bar, "close")
                                     .move(x, y);
      button_close.listen("clicked", func me.onClose());

      # title
      var title = me.get("title", "Canvas Dialog");
      me._title = title_bar.createChild("text", "title")
          .setText(title)
          .setAlignment("left-center")
          .set("character-size", 14)
          .setFont("LiberationFonts/LiberationSans-Bold.ttf")
          .setTranslation(int(x + 1.5 * w + 0.5), int(y + 0.5 * h + 0.5));
     
      me._node.getNode("title", 1).alias(me._title._node.getPath() ~ "/text");
      title_bar.addEventListener("drag", func(e) me.move(e.deltaX, e.deltaY));

      me._resizeDecoration();
      me._onStateChange();
    }
  },
  _resizeDecoration: func()
  {
    if (me.get("type") == "window" or me.get("type") == "dialog") {
      if( me["_title_bar_bg"] == nil )
        return;

      var border_radius = 9;
      me._title_bar_bg
          .reset()
          .rect( 0, 0,
                 me.get("size[0]"), me._title_bar_height, 
                 {"border-top-radius": border_radius} );
      me._frame
          .reset()
          .rect( 0, 0,
                 me.get("size[0]"), me.get("size[1]"),
                 {"border-top-radius": border_radius} );

      me._top_line
          .reset()
          .moveTo(border_radius - 2, 2)
          .lineTo(me.get("size[0]") - border_radius + 2, 2);
    }
  }
}; #Window

# Clear focus on click outside any window
getDesktop().addEventListener("mousedown", func {
  if (gui.focused_window != nil) {
    gui.focused_window.clearFocus();
  }
  
  foreach (var p; gui.open_popups) {
    p.hide();
  }
});

var frameLatencyDisplay = getDesktop().createChild("text", "frame-latency-display")
    .set("font", "accid.txf")
    .set("character-size", 16)
    .set("fill", "rgba(230, 100 50, 1)")
    .set("alignment", "left-bottom")
    .setText("0 ms");
var frameLatencyNode = props.globals.getNode("/sim/frame-latency-max-ms", 1);
var frameLatencyListener = setlistener(frameLatencyNode, func(n) {
    frameLatencyDisplay.setText(sprintf("%4.0f ms", n.getValue()));
});

var fpsDisplay = getDesktop().createChild("text", "fps-display")
    .set("font", "accid.txf")
    .set("character-size", 16)
    .set("fill", "rgba(230, 100, 50, 1)")
    .set("alignment", "right-bottom")
    .setText("0 fps");
var fpsNode = props.globals.getNode("/sim/frame-rate", 1);
var fpsListener = setlistener(fpsNode, func(n) {
    fpsDisplay.setText(sprintf("%3.0f fps", n.getValue()));
});

var displayFrameLatencyNode = props.globals.getNode("/sim/rendering/frame-latency-display", 1);
var displayFrameLatencyListener = setlistener(displayFrameLatencyNode, func(n) {
    frameLatencyDisplay.setVisible(n.getBoolValue());
}, 1);
var displayFPSNode = props.globals.getNode("/sim/rendering/fps-display", 1);
var displayFPSListener = setlistener(displayFPSNode, func(n) {
    fpsDisplay.setVisible(n.getBoolValue());
}, 1);

var mainwindowResizeCallbackFrameLatencyFPSDisplay = func(w, h) {
    frameLatencyDisplay.setTranslation(5, h - 5);
    fpsDisplay.setTranslation(w - 5, h - 5);
};

MainWindow.addSizeChangedCallback(mainwindowResizeCallbackFrameLatencyFPSDisplay);


# Provide old 'Dialog' for backwards compatiblity (should be removed for 3.0)
var Dialog = {
  new: func(size, type = nil, id = nil)
  {
    debug.warn("'canvas.Dialog' is deprecated! (use canvas.Window instead)");
    return Window.new(size, type, id);
  }
};

var unloadGUI = func() {
    MainWindow.removeSizeChangedCallback(mainwindowResizeCallbackFrameLatencyFPSDisplay);
    removelistener(frameLatencyListener);
    removelistener(fpsListener);
    removelistener(displayFPSListener);
    removelistener(displayFrameLatencyListener);
    getDesktop().getElementById("frame-latency-display").del();
    getDesktop().getElementById("fps-display").del();
}

