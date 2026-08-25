# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# ECAM32 helper

winctrl["ecam32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        m._device = device;
        m.type = check_family();
        m.path = "/input/winctrl/ecam32";
        m.listeners = [];
        m.leds = {};
        foreach (var l; keys(m._led)) {
            var devs = [m._dev.dev1,m._dev.dev2];
            var prop = m.path~"/leds/"~l;
            m.leds[l] = leddy.new(l,devs,m._led[l],prop);
            append(m.listeners,m.leds[l].autoReport(m._device));
        }
        m.leds.ledBrt.set(255);
        if (m.type == 'A320') {
            m.doAirbus();
        }
        logprint(LOG_INFO,"WINCRL ECAM32 ONLINE");
        return m;
    },
    _buttons: {
        "tocfg": props.globals.getNode("/input/winctrl/ecam32/buttons/tocfg", 1),
        "emer": props.globals.getNode("/input/winctrl/ecam32/buttons/emer", 1),
        "eng":  props.globals.getNode("/input/winctrl/ecam32/buttons/eng", 1),
        "bleed": props.globals.getNode("/input/winctrl/ecam32/buttons/bleed", 1),
        "press": props.globals.getNode("/input/winctrl/ecam32/buttons/press", 1),
        "elec": props.globals.getNode("/input/winctrl/ecam32/buttons/elec", 1),
        "hyd": props.globals.getNode("/input/winctrl/ecam32/buttons/hyd", 1),
        "fuel": props.globals.getNode("/input/winctrl/ecam32/buttons/fuel", 1),
        "apu": props.globals.getNode("/input/winctrl/ecam32/buttons/apu", 1),
        "cond": props.globals.getNode("/input/winctrl/ecam32/buttons/cond", 1),
        "door": props.globals.getNode("/input/winctrl/ecam32/buttons/door", 1),
        "wheel": props.globals.getNode("/input/winctrl/ecam32/buttons/wheel", 1),
        "fctl": props.globals.getNode("/input/winctrl/ecam32/buttons/fctl", 1),
        "lclr": props.globals.getNode("/input/winctrl/ecam32/buttons/clr", 1),
        "sts": props.globals.getNode("/input/winctrl/ecam32/buttons/sts", 1),
        "rclr": props.globals.getNode("/input/winctrl/ecam32/buttons/clr", 1),
    },
    _ledWatchProps: {
        "panel": props.globals.getNode("/controls/lighting/main-panel-norm", 1),
        #"emer": props.globals.getNode("/controls/indicators/ecam-emer", 1),
        "eng":  props.globals.getNode("/controls/indicators/ecam-eng", 1),
        "bleed": props.globals.getNode("/controls/indicators/ecam-bleed", 1),
        "press": props.globals.getNode("/controls/indicators/ecam-press", 1),
        "elec": props.globals.getNode("/controls/indicators/ecam-elec", 1),
        "hyd": props.globals.getNode("/controls/indicators/ecam-hyd", 1),
        "fuel": props.globals.getNode("/controls/indicators/ecam-fuel", 1),
        "apu": props.globals.getNode("/controls/indicators/ecam-apu", 1),
        "cond": props.globals.getNode("/controls/indicators/ecam-cond", 1),
        "door": props.globals.getNode("/controls/indicators/ecam-door", 1),
        "wheel": props.globals.getNode("/controls/indicators/ecam-wheel", 1),
        "fctl": props.globals.getNode("/controls/indicators/ecam-fctl", 1),
        "lclr": props.globals.getNode("/controls/indicators/ecam-clr", 1),
        "sts": props.globals.getNode("/controls/indicators/ecam-sts", 1),
        "rclr": props.globals.getNode("/controls/indicators/ecam-clr", 1),
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
        logprint(LOG_INFO,"WINCTL ECAM32 shutdown");
    },
    _dev: {
        'dev1': 0x70,
        'dev2': 0xBB,
    },
    _led: {
        'panel': 0x00,
        'ledBrt': 0x01,
        'emer': 0x03,
        'eng': 0x04,
        'bleed': 0x05,
        'press': 0x06,
        'elec': 0x07,
        'hyd': 0x08,
        'fuel': 0x09,
        'apu': 0x0A,
        'cond': 0x0B,
        'door': 0x0C,
        'wheel': 0x0D,
        'fctl': 0x0E,
        'lclr': 0x0F,
        'sts': 0x10,
        'rclr': 0x11,
    },
};
