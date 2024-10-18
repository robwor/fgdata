# SPDX-FileCopyrightText: (C) 2022 Frederic Croix <thefgfseagle@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

gui.Overlay = {
	# @description Constructor
	# @param size Optional[Tuple[int, int]] Two-item vector containing width and height of the overlay
	new: func(size, id = nil) {
		var m = canvas.Window.new(size, "overlay", id, 0);
		m.parents = [gui.Overlay] ~ m.parents;

		return m;
	},
	setFocus: func {},
	clearFocus: func {},
	_handleResize: func {},
	_updateDecoration: func {},
	_resizeDecoration: func {},
};

