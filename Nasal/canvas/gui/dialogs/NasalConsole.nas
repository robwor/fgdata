var NasalConsole = {
	new: func() {
		var m = canvas.Window.new([1000, 1000], "dialog")
			.set("resize", 1)
			.setTitle("Nasal console");
		m.parents = [NasalConsole] ~ m.parents;

		var cv = m.getCanvas(1);
		cv.setColorBackground(style.getColor("bg_color"));
		m.root = cv.createGroup();

		m.layout = VBoxLayout.new();
		m.setLayout(m.layout);

		m.textedit = canvas.gui.widgets.TextEdit.new(parent: m.root, cfg: {"placeholder": "Enter Nasal code"});
		m.layout.addItem(m.textedit);

		m.buttonsLayout = HBoxLayout.new();
		m.layout.addItem(m.buttonsLayout);

		m.pasteButton = canvas.gui.widgets.Button.new(parent: m.root, cfg: {"text": "Paste"})
			.listen("clicked", func(e) {
				m.textedit.setText(clipboard.getText(clipboard.CLIPBOARD));
			});
		m.buttonsLayout.addItem(m.pasteButton);

		m.executeButton = canvas.gui.widgets.Button.new(parent: m.root, cfg: {"text": "Execute"})
			.listen("clicked", func(e) {
				var code = call(func {
					compile(m.textedit.text(), "<nasal-console>");
				}, nil, nil, var compilation_errors = []);

				if(size(compilation_errors)){
					logprint(LOG_ALERT, "Error compiling code from Nasal console");
					debug.printerror(compilation_errors);
					return;
				}

				# Invoke the compiled script, equivalent to code(); 
				# We're using call() here to detect errors:
				call(code, [], nil, nil, var runtime_errors = []);

				if(size(runtime_errors)){
					logprint(LOG_ALERT, "Error calling code compiled from Nasal console");
					debug.printerror(runtime_errors);
					return;
				}
			});
		m.buttonsLayout.addItem(m.executeButton);

		return m;
	},
};

