# WindowManager.nas - window manager implementation
# Copyright 2025 - 2025 Frederic Türpe
# SPDX-License-Identifier: GPL-3.0-or-later

var WindowManager = {
	# TODO: Hardcoded layout for now, will be made user-configurable later
	# @description Get layout information for window's buttons.
	# @return Tuple[Vector[String], Vector[String]]
	#	Two-item tuple: contains one vector for the left and one for the right side of the titlebar,
	#	each containing the names of the window buttons to appear on that side.
	getWindowButtonsLayoutInfo: func() {
		return [[], ["close"]]
	},
	
	# @description Get a callback that performs the required action
	#	on a window for the given window button name.
	# @param name String Name of the window button to return a callback for.
	# @param window canvas.Window Window that the callback should perform the action on.
	# @return Callable Callback that performs the action on the @param window.
	getWindowButtonCallback: func(name, window) {
		if (name == "close") {
			return func() {
				window.onClose();
			}
		}
	},
};

