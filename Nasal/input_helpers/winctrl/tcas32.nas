# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# helper for tcas32

winctrl["tcas32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        me._device = device;
        me.type = check_family();
        me.path = "/input/winctrl/tcas32";
        me.listeners = [];
        me.leds = {};
        foreach (var l; keys(me._led)) {
            var devs = [me._dev.dev1,me._dev.dev2];
            var prop = m.path~"/leds/"~l;
            me.leds[l] = leddy.new(l,devs,me._led[l],prop);
            append(me.listeners,me.leds[l].autoReport(me._device));
        }
        me.leds.ledBrt.set(255);
        me._tcasProps.squawkMsg.setValue("----");
        foreach (var k; keys(me._tcasProps)) {
            append(me.listeners,setlistener(me._tcasProps[k], func() { me.updateDisplay(); },1,0));
        }
        if (me.type == 'A320') {
            me.doAirbus();
        } else {
            me.doGeneric();
            me.leds.lcd.set(255);
        }
        logprint(LOG_INFO,"WINCRL TCAS32 ONLINE");
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
        logprint(LOG_INFO,"WINCTL TCAS32 shutdown");
    },
    watchLEDs: func() {
        foreach(var led; keys(me._ledWatchProps)) {
            append(me.listeners,me.leds[led].watch(me._ledWatchProps[led]));
        }
    },
    doAirbus: func() {
        logprint(LOG_DEBUG,"Adding Airbus listeners");
        me.watchLEDs();
        foreach ( var prop; keys(me._watchProps)) {
            append(me.listeners,setlistener(me._watchProps[prop], func() { me.watchSquawk(); },1,0));
        }
    },
    doGeneric: func() {
        logprint(LOG_DEBUG,"Adding generic listeners");
        me.leds.lcd.set(255);
        foreach ( var prop; keys(me._watchGenProps)) {
            append(me.listeners,setlistener(me._watchGenProps[prop], func() { me.watchGenSquawk(); },1,0));
        }
    },
    _ledWatchProps: {
        "panel": props.globals.getNode("/controls/lighting/main-panel-norm", 1),
        "lcd": props.globals.getNode("/controls/lighting/main-panel-norm-digital", 1),
        "atcFail": props.globals.getNode("/systems/atc/failed", 1),
    },
    _watchProps: {
        "annun": props.globals.getNode("/controls/switches/annun-test",1),
        "squawk": props.globals.getNode("/systems/atc/transponder-code",1),
    },
    _watchGenProps: {
        "squawk": props.globals.getNode("/instrumentation/transponder/id-code",1),
    },
    _tcasProps: {
        "squawkMsg": props.globals.getNode("/input/winctrl/tcas32/squawk",1),
    },
    _dev: {
        'dev1': 0x81,
        'dev2': 0xBB,
    },
    _led: {
        'panel': 0x00,
        'lcd': 0x01,
        'ledBrt': 0x02,
        'atcFail': 0x03,
    },
    # squawk LCD stuff below
    watchSquawk: func() {
        if (me._watchProps.annun.getBoolValue()) {
            var msg = "8888";
        } else {
            var msg = sprintf("%04d",me._watchProps.squawk.getValue()) or "----";
        }
        me._tcasProps.squawkMsg.setValue(msg);
    },
    watchGenSquawk: func() {
        var msg = sprintf("%04d",me._watchProps.squawk.getValue()) or "----";
        me._tcasProps.squawkMsg.setValue(msg);
    },
    updateDisplay: func() {
        var packet = me.squawkTrigger(me._tcasProps.squawkMsg.getValue());
        me._device.sendOutputReport(240,packet);
        var refreshDisplay = [0x00, 0x01, 0x11, me._dev.dev1, me._dev.dev2, 0x00, 0x00, 0x03, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        me._device.sendOutputReport(240,refreshDisplay);
    },
    squawkTrigger: func(message) {
        var packet = ['0x0', '0x1', '0x35', me._dev.dev1, me._dev.dev2, '0x0', '0x0', '0x2', '0x1', '0x0', '0x0', '0xff', '0xff', '0x0', '0x0', '0x0', '0x24', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x01', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0'];
        var rowoffs = [24, 28, 32, 36, 40, 44, 48, 52];
        var chars = "";
        var dotmask = 0;
        foreach (var i; split("", message)) {
            chars = chars ~ i;
        }
        if (utf8.size(chars)> 4) {
            chars = utf8.substr(chars,0,4);
        }
        var cidx = 0;
        foreach (var c; split("", string.uc(chars))) {
            if (contains(keys(tcasReps),c)) {
                var mask = tcasReps[c];
            } else {
                var mask = tcasReps[" "];
            }
            for (var segidx = 0; segidx < 8; segidx += 1) {
                var turn_on = false;
                if ( rshift(mask,segidx) & 1 ) {
                    turn_on = true;
                }
                if (turn_on) {
                    var byte_offset = rowoffs[segidx];
                    var bit_pos = math.mod(cidx,8);
                    packet[byte_offset] = packet[byte_offset] | lshift(bit_pos);
                }
            }
            cidx += 1;
        }
        return packet;
    },
};

var tcasReps = {
    #      A
    #      ---
    #   F | G | B
    #      ---
    #   E |   | C
    #      ---
    #       D
    #'g': 0x10,
    #'f': 0x20,
    #'e': 0x40,
    #'d': 0x01,
    #'c': 0x02,
    #'b': 0x04,
    #'a': 0x08,
    #           A,  B,  C,  D,  E,  F,  G,  ., unk
    #rowoffs = [25, 29, 33, 37, 41, 45, 49, 53]
    '0': 0x6f,
    '1': 0x06,
    '2': 0x5d,
    '3': 0x1f,
    '4': 0x36,
    '5': 0x3b,
    '6': 0x7b,
    '7': 0x0e,
    '8': 0x7f,
    '9': 0x3f,
    ' ': 0x00,
    '-': 0x10,
    '_': 0x01,
};
