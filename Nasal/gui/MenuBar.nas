# SPDX-FileCopyrightText: (C) 2023 TheFGFSEagle <thefgfseagle@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

var menubar = nil;

var _addItem = func(parent, itemGhost) {
	var item = parent.createItem(
		text: itemGhost.label,
		cb: itemGhost.fire,
		cb_me: itemGhost,
		shortcut: itemGhost.shortcut,
		enabled: itemGhost.enabled,
	);

	itemGhost.addChangedCallback(func { 
		item.setEnabled(itemGhost.enabled);
		item.setText(itemGhost.label);
		item.update(); 
	});
}

var _addMenu = func(parent, menuGhost) {
	var menu = parent.createMenu(menuGhost.label);
	foreach (var item; menuGhost.items) {
		if (var submenu = item.submenu) {
			_addMenu(menu, submenu);
		} else {
			_addItem(menu, item);
		}
	}
}

var _createMenuBar = func(menubarGhost) {
	if (menubar != nil) {
		menubar.del();
		menubar = nil;
	}
	menubar = canvas.gui.MenuBar.new();
	foreach (var menu; menubarGhost.menus) {
		_addMenu(menubar, menu);
	}
	menubar.show();
}

var _destroyMenuBar = func(menubarGhost) {
	if (menubar != nil) {
		return;
	}
	menubar.del();
	menubar = nil;
}

var _showMenuBar = func(menubarGhost) {
	if (menubar == nil) {
		return;
	}
	menubar.show();
}

var _hideMenuBar = func(menubarGhost) {
	if (menubar == nil) {
		return;
	}
	menubar.hide();
}

