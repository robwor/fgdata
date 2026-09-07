var FontViewer = {
	new: func() {
		var m = canvas.Window.new([400, 100], "dialog")
						.setTitle("Font viewer");
		m.parents = [FontViewer] ~ m.parents;

		var cv = m.getCanvas(1);
		cv.setColorBackground(style.getColor("bg_color"));
		m.root = cv.createGroup();

		m.layout = HBoxLayout.new();
		m.setLayout(m.layout);

		m.fontPreview = gui.widgets.Label.new(m.root, canvas.style, {});
		m.fontPreview.setText("abcdefghijklkmnopqrstuvwxyz\nABCDEFGHIJKLMNOPQRSTUWVXYZ\n0123456789\n!?.,;:-_#+*'§$%&/()=\"");
		m.layout.addItem(m.fontPreview);

		m.chooserButton = gui.widgets.Button.new(m.root, canvas.style, {})
						.setText("Choose font …")
						.listen("clicked", func (e) {
							var font = InputDialog.getText(
								"Choose font", "Font file path relative to $FGDATA/Fonts:",
								func (button_id, text) {
									if (text != nil) {
										m.fontPreview._view._text.setFont(text);
									}
								}
							);
						});
		m.layout.addItem(m.chooserButton);
	},
};

