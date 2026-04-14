gui.widgets.PropertyTree = {
        _CLASS: "PropertyTree",
        AttributeMapping: {
                "archive": "A",
                #"alias": "L",
                "preserve": "P",
                "readable": "R",
                "tied": "T",
                "trace-read": "Tr",
                "trace-write": "Tw",
                "userarchive": "U",
                "writable": "W",
        },

        # In verbose mode we lookup certain child nodes to aid easy
        # identification of sub-trees.
        _defautLookupChildNames: ["name", "id"],

        new: func(parent, style = nil, cfg = nil) {
                cfg = Config.new(cfg);
                var m = gui.widgets.List.new(parent, style, cfg);
                m.parents = [gui.widgets.PropertyTree] ~ m.parents;
                m._lookupChildName = "";
                m._verbose = 0;
                m._node = cfg.get("node", props.globals);
                m._old_children_count = 0;
                m.rebuildList();
                m.listen("selection-changed", func {
                        var selected = m.getSelectedItems();
                        if (!size(selected)) {
                                return;
                        }
                        var node = selected[0].getData("node");
                        if (size(node.getChildren()) > 0) {
                                m.setNode(node);
                        }
                });
                m.updateTimer = maketimer(0.1, func m.update());
                m.updateTimer.simulatedTime = 0;
                m.updateTimer.start();
                m._attrkeys = sort(keys(me.AttributeMapping), func(a, b) cmp(a, b));
                return m;
        },

        show: func {
                call(me.parents[1].show, [], me);
                me.updateTimer.start();
        },

        hide: func {
                call(me.parents[1].hide, [], me);
                me.updateTimer.stop();
        },

        getNode: func {
                return me._node;
        },

        setNode: func(node) {
                if (isscalar(node)) {
                        me._node = props.globals.getNode(node);
                } elsif (ishash(node)) {
                        me._node = props.Node.new(node);
                } elsif (isa(node, props.Node)) {
                        me._node = node;
                } else {
                        die("Cannot set node to object of type '" ~ typeof(node) ~ "'");
                }
                me._node = node;
                me.rebuildList();
                me._trigger("node-changed", {"node": me._node, "path": me._node.getPath()});

                return me;
        },

        getLookupChild: func() {
                return me._lookupChildName;
        },

        setLookupChild: func(name) {
                me._lookupChildName = name;
        },

        setVerbose: func(value) {
                me._verbose = value;
        },

        rebuildList: func {
                me.clear();
                if (me._node.getParent()) {
                        var item = me.createItem("../")
                                                        .setData("node", me._node.getParent());
                }
                var children = sort(
                        me._node.getChildren(),
                        func(a, b) { cmp(
                                sprintf("%s[%010d]", a.getName(), a.getIndex()),
                                sprintf("%s[%010d]", b.getName(), b.getIndex())
                        ); }
                );
                foreach (var c; children) {
                        var item = nil;
                        if (c.getAttribute("children")) {
                                var index = c.getIndex();
                                var name = c.getName() ~ (index > 0 ? "[" ~ index ~ "]" : "");

                                item = me.createItem(name ~ "/");
                        } else {
                                item = me.createItem("");
                        }
                        item._view._root.addEventListener("click", func(e) me.itemClicked(e));
                        item.setData("node", c);
                }
                me._old_children_count = me._node.getAttribute("children");
        },

        itemClicked: func(e) {
                var selected = me.getSelectedItems();
                if (!size(selected)) {
                        return;
                }
                var node = selected[0].getData("node");
                if (e.ctrlKey) {
                        if (e.shiftKey) {
                                screen.property_display.reset();
                        } elsif (node.getType() == "BOOL") {
                                node.toggleBoolValue();
                        }
                } elsif (e.shiftKey) {
                        if (node.getAttribute("children")) {
                                screen.property_display.add(node.getChildren());
                        } else {
                                screen.property_display.add(node);
                        }
                }
        },

        update: func {
                if (me._old_children_count != me._node.getAttribute("children")) {
                        me.rebuildList();
                }
                var nameCountMapping = {};
                for (var i = 0; i < me.count(); i += 1) {
                        var node = me.getItem(i).getData("node");
                        var name = node.getName();
                        if (!contains(nameCountMapping, name)) {
                                nameCountMapping[name] = 1;
                        } else {
                                nameCountMapping[name] += 1;
                        }
                }
                for (var i = 0; i < me.count(); i += 1) {
                        var item = me.getItem(i);
                        # ignore "go up" entry
                        if (item.getText() == "../") {
                                continue;
                        }

                        var node = item.getData("node");
                        var type = string.lc(node.getType());
                        var index = node.getIndex();
                        var numChildren = node.getAttribute("children");
                        var details = "";
                        if (me._verbose) {
                                details = " (";
                                if (node.getAttribute("alias")) {
                                        details ~= node.getAliasTarget().getPath() ~ " ";
                                } elsif (type != "none") {
                                        details ~= type ~ " ";
                                } else {
                                        # sub-tree (node with children) usually are type none
                                        if (me._lookupChildName) {
                                                var v = node.getValue(me._lookupChildName);
                                                details ~= (v != nil ? v~" " : "");
                                        }
                                        else foreach(var childName; me._defautLookupChildNames) {
                                                var v = node.getValue(childName);
                                                if (v != nil) {
                                                        details ~= v~" ";
                                                        break;
                                                }
                                        }
                                }

                                foreach (var attr; me._attrkeys) {
                                        if (node.getAttribute(attr)) {
                                                details ~= me.AttributeMapping[attr];
                                        }
                                }
                                details ~= " L" ~ node.getAttribute("listeners") ~ ")";
                        } elsif (type != "none") {
                                details = " (" ~ type ~ ")";
                        }

                        var name = node.getDisplayName((nameCountMapping[node.getName()] > 1)) ~ (numChildren ? "/" : "");
                        var value = nil;
                        if (type == "bool") {
                                value = node.getBoolValue() ? "true" : "false";
                        } elsif (type == "string" or type == "unspecified") {
                                value = "'" ~ string.replace(node.getValue(), "\n", "\\n") ~ "'";
                        } elsif (type != "alias" and type != "none") {
                                value = node.getValue() ~ "";
                        }
                        if (value != nil) {
                                item.setText(name ~ " = " ~ value ~ details);
                        } else {
                               item.setText(name ~ details);
                        }
                }
                call(me.parents[1].update, [], me);
        },

        del: func {
                me.updateTimer.stop();
        },
};
