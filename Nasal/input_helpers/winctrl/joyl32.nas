# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# ursa-minor 32L joystick

winctrl["joyl32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        me._device = device;
        me.type = check_family();
        me.path = "/input/winctrl/joyl32";
        me.listeners = [];
        me.leds = {};
        foreach (var l; keys(me._led)) {
            if (l == "vib") {
                var devs = [me._dev.vibdev1,me._dev.vibdev2];
            } else {
                var devs = [me._dev.dev1,me._dev.dev2];
            }
            var prop = m.path~"/leds/"~l;
            me.leds[l] = leddy.new(l,devs,me._led[l],prop);
            append(me.listeners,me.leds[l].autoReport(me._device));
        }
        if (me.type == 'A320') {
            me.doAirbus();
        }
        foreach ( var prop; keys(me._vibProps)) {
            append(me.listeners,setlistener(me._vibProps[prop], func() { me.shaker(); },0,0));
        }
        logprint(LOG_INFO,"WINCRL JOYSTICK-L ONLINE");
        return me;
    },
    close: func(cfgnode) {
        logprint(LOG_DEBUG,"removing "~size(me.listeners)~" listeners");
        foreach (var id; me.listeners) {
            removelistener(id);
        }
        if (contains(keys(me),'_device')) {
            foreach (var led; keys(me.leds)) {
                me.leds[led].close(me._device);
            }
        }
        logprint(LOG_INFO,"WINCTRL JOYSTICK-L shutdown");
    },
    _ledWatchProps: {
        "panel": props.globals.getNode("/controls/lighting/main-panel-norm", 1),
    },
    watchLEDs: func() {
        foreach(var led; keys(me._ledWatchProps)) {
            append(me.listeners,me.leds[led].watch(me._ledWatchProps[led]));
        }
    },
    doAirbus: func() {
        logprint(LOG_DEBUG,"Adding Airbus listeners");
        me.watchLEDs();
    },
    _dev: {
        'dev1': 0x20,
        'dev2': 0xBB,
        'vibdev1': 0x07,
        'vibdev2': 0xBF,
    },
    _led: {
        'panel': 0x00,
        'vib': 0x00,
    },
    _viewProps: {
        "hat": props.globals.getNode("/input/winctrl/joyl32/hat",1),
        "pitch": props.globals.getNode("/sim/current-view/goal-pitch-offset-deg",1),
        "heading": props.globals.getNode("/sim/current-view/goal-heading-offset-deg",1),
    },
    _vibProps: {
        "wow0": props.globals.getNode("/gear/gear[0]/wow",1),
        "wow1": props.globals.getNode("/gear/gear[1]/wow",1),
        "wow2": props.globals.getNode("/gear/gear[2]/wow",1),
        # only registers inside cockpit
        "cockRoll": props.globals.getNode("/sim/sound/other/cockpit-roll-v",1),
    },
    _vibs: [ "vib",],
    shaker: func() {
        if (me._vibProps.wow0.getBoolValue() or me._vibProps.wow1.getBoolValue() or me._vibProps.wow2.getBoolValue()) {
            var shake = (me._vibProps.cockRoll.getValue() or 0);
            # starts to vibrate around 22kt with ^2
            shake = int(math.pow(shake,2)*255);
            me.leds.vib.set(shake);
        } else {
            foreach (var vib; me._vibs) {
                me.leds.vib.set(0);
            }
        }
    },
};
