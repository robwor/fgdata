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

var Config = std.Hash;

var gui_dir = getprop("/sim/fg-root") ~ "/Nasal/canvas/gui/";
var loadGUIFile = func(file) io.load_nasal(gui_dir ~ file, "canvas");
var loadWidget = func(name) loadGUIFile("widgets/" ~ name ~ ".nas");
var loadDialog = func(name) loadGUIFile("dialogs/" ~ name ~ ".nas");

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
loadWidget("ComboBox");
loadWidget("Dial");
loadWidget("Label");
loadWidget("LineEdit");
loadWidget("List");
loadWidget("MenuBar");
loadWidget("PropertyTree");
loadWidget("PropertyWidgets");
loadWidget("RadioButton");
loadWidget("Rule");
loadWidget("ScrollArea");
loadWidget("Slider");
loadWidget("Switch");
loadWidget("TabWidget");
loadWidget("TextBox");
loadWidget("WindowButton");

# standard dialogs
loadDialog("InputDialog");
loadDialog("MessageBox");
loadDialog("WidgetsFactoryDialog");
loadDialog("PropertyTreeBrowser");

var style = DefaultStyle.new("AmbianceClassic", "Humanity");

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
