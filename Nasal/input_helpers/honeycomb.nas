#
# Helpers for Honeycomb input devices
#

# namespace
var honeycomb = {};

# Helper for the Honeycomb Alpha Yoke
honeycomb["alpha"] = {
    new: func(cfgnode) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        m.magneto_switch = props.getNode(m.prefix~"/magneto_switch", 1);
        m.magneto_switch.alias("/controls/switches/magnetos");
        m.starter = props.getNode(m.prefix~"/starter", 1);
        m.starter.alias("/controls/switches/starter");
        return m;
    },

    setMagnetos: func(value) {
        me.magneto_switch.setIntValue(value);
        props.setAll("/controls/engines/engine", "magnetos", value);
    },

    setStarter: func(value) {
        (value) ?  me.starter.setBoolValue(1) : me.starter.setBoolValue(0);
        props.setAll("/controls/engines/engine", "starter", value);
    },

    # handle the hat button on the yoke
    adjustView: func(binding) {
        var delta = 0.2;
        var settingN = binding.getNode("setting", 1);
        var value = settingN.getValue();
        var timer = maketimer(0.02, me, func(){
            # 1 = up, 3 = right, 5 = down, 7 = left
            setting = settingN.getValue();
            if (!setting or setting != value) {
                timer.stop();
                return;
            }
            if (setting == 1 or setting == 2 or setting == 8) {
                view.panViewPitch(delta);
            }
            if (2 <= setting and setting <= 4) {
                view.panViewDir(-delta);
            }
            if (4 <= setting and setting <= 6) {
                view.panViewPitch(-delta);
            }
            if (6 <= setting and setting <= 8) {
                view.panViewDir(delta);
            }
        });
        timer.start();
    },
};

# Helper for the Honeycomb Bravo throttle quadrant
honeycomb["bravo"] = {
    annunciators: props.getNode("/instrumentation/annunciators/serviceable", 1),
    _target_values: {
        "alt": props.getNode("/autopilot/settings/target-altitude-ft", 1),
        "vs":  props.getNode("/autopilot/settings/vertical-speed-fpm", 1),
        "hdg": props.getNode("/autopilot/settings/heading-bug-deg", 1),
        "crs": props.getNode("/instrumentation/nav/radials/selected-deg", 1),
        "ias": props.getNode("/autopilot/settings/target-speed-kt", 1),
    },

    new: func(cfgnode) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        m['_ap_input_selector'] = props.getNode(m.prefix~"/ap-setting-selector", 1);
        m.enableAnnunciators();
        return m;
    },

    close: func(cfgnode) {
        print("Honeycomb Bravo shutdown");
        me.disableAnnunciators();
        me.parents[1].close(cfgnode);
    },

    enableAnnunciators: func() {
        me.annunciators.setValue(1);
    },

    disableAnnunciators: func() {
        me.annunciators.setValue(0);
    },

    setIncDecSelector: func(name) {
        if (contains(me._target_values, name))
            me._ap_input_selector.setValue(name);
    },

    incAPSetting: func() {
        setting = me._ap_input_selector.getValue();
        target = me._target_values[setting];
        if (setting == "ias" ) {
            val = target.add(1, 500);
            gui.popupTip(sprintf("Target airspeed set to: %d kts", val));
        }
        elsif (setting == "crs" ) {
            val = target.add(1, 360, 360);
            gui.popupTip(sprintf("Selected course: %d deg", val));
        }
        elsif (setting == "hdg" ) {
            val = target.add(1, 359, 360);
            gui.popupTip(sprintf("Selected heading: %d deg", val));
        }
        elsif (setting == "vs" ) {
            val = target.add(50, 3000);
            gui.popupTip(sprintf("Target vertical speed set to: %d fpm", val));
        }
        elsif (setting == "alt" ) {
            val = target.add(100, 50000);
            gui.popupTip(sprintf("Target target altitude set to: %d ft", val));
        }
    },

    decAPSetting: func() {
        setting = me._ap_input_selector.getValue();
        target = me._target_values[setting];
        if (setting == "ias" ) {
            val = target.sub(1, 50);
            gui.popupTip(sprintf("Target airspeed set to: %d kts", val));
        }
        elsif (setting == "crs" ) {
            val = target.sub(1, 0, 360);
            gui.popupTip(sprintf("Selected course: %d deg", val));
        }
        elsif (setting == "hdg" ) {
            val = target.sub(1, 0, 360);
            gui.popupTip(sprintf("Selected heading: %d deg", val));
        }
        elsif (setting == "vs" ) {
            val = target.sub(50, -3000);
            gui.popupTip(sprintf("Target vertical speed set to: %d fpm", val));
        }
        elsif (setting == "alt" ) {
            val = target.sub(100, 300);
            gui.popupTip(sprintf("Target target altitude set to: %d ft", val));
        }
    },

};