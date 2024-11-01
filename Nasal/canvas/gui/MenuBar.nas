gui.MenuBar = {
	_CLASS: "gui.MenuBar",

	new: func() {
		var obj = {
			parents: [gui.MenuBar, canvas.gui.Overlay.new([24, 24], "global-menu-bar")],
		};

                obj._canvas = obj.createCanvas().setColorBackground(canvas.style.getColor("bg_color"));
		obj._root = obj._canvas.createGroup();
		obj._layout = canvas.VBoxLayout.new();
		obj._canvas.setLayout(obj._layout);
		obj._menuBar = canvas.gui.widgets.MenuBar.new(obj._root, canvas.style, {});
		obj._layout.addItem(obj._menuBar);

		var wrapSizeChangingWidgetFunc = func(sizeChangingWidgetFuncName) {
			var sizeChangingWidgetFunc = gui.widgets.MenuBar[sizeChangingWidgetFuncName];
			var wrapperFunc = func {
				var result = call(sizeChangingWidgetFunc, arg, obj._menuBar);
				obj.updateSize();
				return result;
			}
			obj[sizeChangingWidgetFuncName] = wrapperFunc;
		}
		var wrapWidgetFunc = func(widgetFuncName) {
			var widgetFunc = gui.widgets.MenuBar[widgetFuncName];
			var wrapperFunc = func {
				return call(widgetFunc, arg, obj._menuBar);
			}
			obj[widgetFuncName] = wrapperFunc;
		}

		wrapSizeChangingWidgetFunc("addMenu");
		wrapSizeChangingWidgetFunc("createMenu");
		wrapSizeChangingWidgetFunc("clear");
		wrapSizeChangingWidgetFunc("removeMenu");
		wrapSizeChangingWidgetFunc("takeAt");
		wrapWidgetFunc("count");
		wrapWidgetFunc("getItem");
		wrapWidgetFunc("getMenu");

		return obj;
	},

	setSize: func(s) {
		call(me.parents[1].setSize, [s], me);
		me._menuBar.setSize(s);
		return me;
	},

	updateSize: func {
		me.setSize(me._menuBar._size);
	},

	update: func {
		me._menuBar.update();
		return me;
	},
};
