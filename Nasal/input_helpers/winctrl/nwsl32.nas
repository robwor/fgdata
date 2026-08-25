# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# WINCTRL NWS L 32

winctrl["nwsl32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        m._device = device;
        m.type = check_family();
        m.path = "/input/winctrl/nwsl32";
        m.listeners = [];
        m.leds = {};
        foreach (var l; keys(m._led)) {
            var devs = [m._dev.dev1,m._dev.dev2];
            var prop = m.path~"/leds/"~l;
            m.leds[l] = leddy.new(l,devs,m._led[l],prop);
            append(m.listeners,m.leds[l].autoReport(m._device));
        }
        if (m.type == 'A320') {
            m.doAirbus();
        }
        logprint(LOG_INFO,"WINCRL NWS-L ONLINE");
        return m;
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
        logprint(LOG_INFO,"WINCTRL NWSL-L shutdown");
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
        'dev1': 0x60,
        'dev2': 0xB9,
    },
    _led: {
        'panel': 0x00,
    },
};
