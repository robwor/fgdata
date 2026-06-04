# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# helper for throttle + pac

winctrl["throttle32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        me._device = device;
        me.type = check_family();
        me.path = "/input/winctrl/throttle32";
        me.listeners = [];
        me.leds = {};
        foreach (var l; keys(me._led)) {
            var devs = [me._dev.dev1,me._dev.dev2];
            #if (l=="lcd" or  l=="panel2") {
            if (contains(["lcd","panel2"],l)) {
                devs[0] = me._dev.devB;
            }
            var prop = m.path~"/leds/"~l;
            me.leds[l] = leddy.new(l,devs,me._led[l],prop);
            append(me.listeners,me.leds[l].autoReport(me._device));
        }
        # may not actually work on the throttle
        me.leds.ledBrt.set(255);
        me._thrProps.rudderMsg.setValue("----");
        foreach (var k; keys(me._thrProps)) {
            append(me.listeners,setlistener(me._thrProps[k], func() { me.updateDisplay(); },1,0));
        }
        if (me.type == 'A320') {
            me.doAirbus();
        } else {
            me.doGeneric();
        }
        logprint(LOG_INFO,"WINCRL THROTTLE32 ONLINE");
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
        logprint(LOG_INFO,"WINCTL THROTTLE32 shutdown");
    },
    watchLEDs: func() {
        foreach(var led; keys(me._ledWatchProps)) {
            append(me.listeners,me.leds[led].watch(me._ledWatchProps[led]));
        }
    },
    doAirbus: func() {
        logprint(LOG_DEBUG,"Adding Airbus listeners");
        me.watchLEDs();
        me._watchProps.rudderLR.setValue(" ");
        me._watchProps.rudderTrim.setValue("0.0");
        foreach ( var prop; keys(me._watchProps)) {
            append(me.listeners,setlistener(me._watchProps[prop], func() { me.watchRudder(); },1,0));
        }
        foreach ( var prop; keys(me._vibProps)) {
            append(me.listeners,setlistener(me._vibProps[prop], func() { me.shaker(); },1,0));
        }
    },
    doGeneric: func() {
        logprint(LOG_DEBUG,"Adding generic listeners");
        me.leds.lcd.set(255);
        foreach ( var prop; keys(me._watchGenProps)) {
            append(me.listeners,setlistener(me._watchGenProps[prop], func() { me.watchGenRudder(); },1,0));
        }
    },
    _ledWatchProps: {
        "panel": props.globals.getNode("/controls/lighting/main-panel-norm", 1),
        "panel2": props.globals.getNode("/controls/lighting/main-panel-norm", 1),
        "lcd": props.globals.getNode("/controls/lighting/main-panel-norm-digital", 1),
        "fault1": props.globals.getNode("/controls/indicators/engine-1-fault", 1),
        "fire1": props.globals.getNode("/controls/indicators/engine-1-fire", 1),
        "fault2": props.globals.getNode("/controls/indicators/engine-2-fault", 1),
        "fire2": props.globals.getNode("/controls/indicators/engine-2-fire", 1),
    },
    _watchProps: {
        "annun": props.globals.getNode("/controls/switches/annun-test",1),
        "rudderLR": props.globals.getNode("/controls/flight/rudder-trim-letter-display",1),
        "rudderTrim": props.globals.getNode("/controls/flight/rudder-trim-display",1),
    },
    _watchGenProps: {
        "rudderTrim": props.globals.getNode("/controls/flight/rudder-trim",1),
    },
    _thrProps: {
        "rudderMsg": props.globals.getNode("/input/winctrl/throttle32/rudder-message",1),
    },
    _vibProps: {
        "wow0": props.globals.getNode("/gear/gear[0]/wow",1),
        "wow1": props.globals.getNode("/gear/gear[1]/wow",1),
        "wow2": props.globals.getNode("/gear/gear[2]/wow",1),
        "cockRoll": props.globals.getNode("/sim/sound/other/cockpit-roll-v",1),
    },
    _vibs: [ "vibL1", "vibR1", "vibL2", "vibR2" ],
    _dev: {
        'dev1': 0x10,
        'devB': 0x01, # PAC
        'dev2': 0xB9,
    },
    _led: {
        'panel': 0x00,
        'panel2': 0x00,
        'ledBrt': 0x01,
        'lcd': 0x02,
        'fault1': 0x03,
        'fire1': 0x04,
        'fault2': 0x05,
        'fire2': 0x06,
        'vibR1': 0x10,
        'vibR2': 0x11,
        'vibL1': 0x12,
        'vibL2': 0x13,
    },
    # rudder LCD stuff below
    watchRudder: func() {
        if (me._watchProps.annun.getBoolValue()) {
            var msg = "8.8.8.8";
        } else {
            var msg = (me._watchProps.rudderLR.getValue() or ' ');
            var trim = me._watchProps.rudderTrim.getValue();
            if (size(trim) <4) {
                    msg = msg ~' '~ trim;
            } else {
                    msg = msg ~ trim;
            }
        }
        me._thrProps.rudderMsg.setValue(msg);
    },
    watchGenRudder: func() {
        # normalizes to +/- 20
        # most trim settings just deflect rudder
        var trim = me._watchGenProps.rudderTrim.getValue();
        if (trim > 0) {
            var msg = "R"~sprintf("%4.1f",trim*20);
        } else  if (trim < 0 ) {
            var msg = "L"~sprintf("%4.1f",math.abs(trim*20));
        } else {
            var msg = "  0.0";
        }
        me._thrProps.rudderMsg.setValue(msg);
    },
    updateDisplay: func() {
        var packet = me.rudderTrigger(me._thrProps.rudderMsg.getValue());
        me._device.sendOutputReport(240,packet);
        var refreshDisplay = [0x00, 0x01, 0x11, me._dev.devB, me._dev.dev2, 0x00, 0x00, 0x03, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        me._device.sendOutputReport(240,refreshDisplay);
    },
    rudderTrigger: func(message) {
        var packet = ['0x0', '0x1', '0x35', me._dev.devB, me._dev.dev2, '0x0', '0x0', '0x2', '0x1', '0x0', '0x0', '0xff', '0xff', '0x0', '0x0', '0x0', '0x24', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x01', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0'];
        var row_offsets = [52, 48, 44, 40, 36, 32, 28, 24, 56];
        var chars = "";
        var dotmask = 0;
        foreach (var i; split("", message)) {
            if (i == ".") {
                    dotmask = dotmask | lshift(size(chars)-1);
            } else {
                    chars = chars ~ i;
            }
        }
        var cidx = 0;
        foreach (var c; split("", string.uc(chars))) {
            if (contains(keys(lcdReps),c)) {
                if ( cidx == 0 and c == "R" ) {
                    var mask = lcdReps["A"];
                } else {
                    var mask = lcdReps[c];
                }
            } else {
                var mask = lcdReps[" "];
            }
            for (var segidx = 0; segidx < 9; segidx += 1) {
                var turn_on = false;
                if ( segidx == 7 ) {
                    if ( rshift(dotmask,cidx) & 1 ) {
                        turn_on = true;
                    }
                } else {
                    if ( rshift(mask,segidx) & 1 ) {
                        turn_on = true;
                    }
                }
                if (turn_on) {
                    var byte_offset = row_offsets[segidx];
                    var bit_pos = math.mod(cidx,8);
                    packet[byte_offset] = packet[byte_offset] | lshift(bit_pos);
                }
            }
            cidx += 1;
        }
        return packet;
    },
    shaker: func() {
        if (me._vibProps.wow0.getBoolValue() or me._vibProps.wow1.getBoolValue() or me._vibProps.wow2.getBoolValue()) {
            var shake = (me._vibProps.cockRoll.getValue() or 0);
            # starts to vibrate around 22kt with ^2
            shake = int(math.pow(shake,2)*255);
            me.leds['vibL1'].set(shake);
            #foreach (var vib; me._vibs) {
            #    me.leds[vib].set(shake);
            #}
        } else {
            foreach (var vib; me._vibs) {
                me.leds[vib].set(0);
            }
        }
    },
};
