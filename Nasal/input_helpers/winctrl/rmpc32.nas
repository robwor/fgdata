# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# helper for Winwing WINCTRL 32 RMP C

winctrl["rmpc32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        m._device = device;
        m.type = check_family();
        m.path = "/input/winctrl/rmpc32";
        m.listeners = [];
        m.leds = {};
        foreach (var l; keys(m._led)) {
            var devs = [m._dev.dev1,m._dev.dev2];
            var prop = m.path~"/leds/"~l;
            m.leds[l] = leddy.new(l,devs,m._led[l],prop);
            append(m.listeners,m.leds[l].autoReport(m._device));
        }
        m.leds.ledBrt.set(255);
        m._rmpcProps.activeMsg.setValue("---.---");
        m._rmpcProps.stbyMsg.setValue("---.---");
        foreach (var k; keys(m._rmpcProps)) {
            append(m.listeners,setlistener(m._rmpcProps[k], func() { m.updateDisplay(); },1,0));
        }
        if (m.type == 'A320') {
            m.doAirbus();
        } else {
            m.doGeneric();
            m.leds.lcd.set(255);
        }
        logprint(LOG_INFO,"WINCRL RMP C 32 ONLINE");
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
        logprint(LOG_INFO,"WINCTL RMP C 32 shutdown");
    },
    watchLEDs: func() {
        foreach(var led; keys(me._ledWatchProps)) {
            append(me.powered,me.leds[led].watch(me._ledWatchProps[led]));
        }
    },
    watchPower: func(node) {
        # function to turn on and off leds if the power is killed
        if (node.getBoolValue()) {
            me.watchLEDs();
            me.watchRadio();
        } else {
            foreach (var id; me.powered) {
                removelistener(id);
            }
            me.powered = [];
            foreach(var led; keys(me._ledWatchProps)) {
                me.leds[led].set(0);
            }
            foreach (var chan; me._chSel) {
                me.leds[chan].set(0);
            }
        }
    },
    doAirbus: func() {
        logprint(LOG_DEBUG,"Adding Airbus listeners");
        me.powered = [];
        append(me.listeners,setlistener(me._rmpcProps.powerOn,func(node) { me.watchPower(node); },1,0));
        append(me.listeners,me.leds.panel.watch(me._panel));
        foreach ( var prop; keys(me._watchProps)) {
            append(me.listeners,setlistener(me._watchProps[prop], func() { me.watchFreq(); },1,0));
        }
    },
    doGeneric: func() {
        logprint(LOG_DEBUG,"Adding generic listeners");
        me.leds.lcd.set(255);
        #foreach ( var prop; keys(me._watchGenProps)) {
        #    append(me.listeners,setlistener(me._watchGenProps[prop], func() { me.watchGenSquawk(); },1,0));
        #}
    },
    _ledWatchProps: {
        #"panel": props.globals.getNode("/controls/lighting/main-panel-norm", 1),
        "lcd": props.globals.getNode("/controls/lighting/main-panel-norm-digital", 1),
        'sel': props.globals.getNode("/systems/radio/rmp[0]/sel-light", 1),
        'am': props.globals.getNode("/systems/radio/rmp[0]/am-active", 1),
        'nav': props.globals.getNode("/systems/radio/rmp[0]/nav", 1),
        # set in watchRadio()
        #'vhf1':
        #'vhf2':
        #'vhf3':
        #'hf1':
        #'hf2':
        #'vor':
        #'ls': # actually ILS
        #'adf':
        # not implemented
        #'load':
        #'gls':
        #'mls':
    },
    _watchProps: {
        "annun": props.globals.getNode("/controls/switches/annun-test",1),
        "active": props.globals.getNode("/controls/radio/rmp[0]/active-display",1),
        "standby": props.globals.getNode("/controls/radio/rmp[0]/standby-display",1),
    },
    _watchGenProps: {
        "active": props.globals.getNode("/instrumentation/comm[0]/frequencies/selected-mhz-fmt",1),
        "standby": props.globals.getNode("/instrumentation/comm[0]/frequencies/standby-mhz-fmt",1),
    },
    _rmpcProps: {
        "activeMsg": props.globals.getNode("/input/winctrl/rmpc32/active",1),
        "stbyMsg": props.globals.getNode("/input/winctrl/rmpc32/stby",1),
        "powerOn": props.globals.getNode("/input/winctrl/rmpc32/buttons/powerOn",1),
    },
    _panel: props.globals.getNode("/controls/lighting/main-panel-norm", 1),
    _selCh: props.globals.getNode("/systems/radio/rmp[0]/sel_chan",1),
    _dev: {
        'dev1': 0x01,
        'dev2': 0x00,
    },
    _led: {
        'panel': 0x00,
        'lcd': 0x01,
        'ledBrt': 0x02,
        'sel': 0x03,
        'vhf1': 0x04,
        'vhf2': 0x05,
        'vhf3': 0x06,
        'load': 0x07,
        'hf1': 0x08,
        'hf2': 0x09,
        'am': 0x0a,
        'nav': 0x0b,
        'vor': 0x0c,
        'ls': 0x0d,
        'gls': 0x0e,
        'mls': 0x0f,
        'adf': 0x10,
    },
    watchFreq: func() {
        if (me._watchProps.annun.getBoolValue()) {
            var msg = "8.8.8.8.8.8";
            me._rmpcProps.activeMsg.setValue(msg);
            me._rmpcProps.stbyMsg.setValue(msg);
        } else {
            #var msg = sprintf("%04d",me._watchProps.squawk.getValue()) or "---.---";
            me._rmpcProps.activeMsg.setValue(me._watchProps.active.getValue() or "---.---");
            me._rmpcProps.stbyMsg.setValue(me._watchProps.standby.getValue() or "---.---");
        }
    },
    _chSel: ['vhf1','vhf2','vhf3','hf1','hf2','vor','ls','gls','mls','adf'],
    setRadioLED: func() {
        if (me._watchProps.annun.getBoolValue()) {
            foreach (var chan; me._chSel) {
                me.leds[chan].set(255);
            }
        } else {
            var val = me._selCh.getValue();
            foreach (var chan; me._chSel) {
                me.leds[chan].set(0);
            }
            if (contains(keys(me.leds),val)) {
                me.leds[val].set(255);
            }
        }
    },
    watchRadio: func() {
        append(me.powered,setlistener(me._selCh, func { me.setRadioLED(); },1,0));
        append(me.powered,setlistener(me._watchProps.annun, func { me.setRadioLED(); },1,0));
    },
    watchGenFreq: func() {
        # TODO make function to switch/handle multiple radios from other inputs
        me._rmpcProps.activeMsg.setValue(me._watchGenProps.active.getValue() or "---.---");
        me._rmpcProps.activeMsg.setValue(me._watchGenProps.standby.getValue() or "---.---");
    },
    updateDisplay: func() {
        var active = me._rmpcProps.activeMsg.getValue();
        var stby = me._rmpcProps.stbyMsg.getValue();
        while (size(string.replace(stby,'.','')) < 6) {
            stby = stby ~ " ";
        }
        while (size(string.replace(active,'.','')) < 6) {
            active = active ~ " ";
        }
        # pad to 6 minus .
        # naive assuming dots are in valid part
        if (size(string.replace(stby,'.','')) > 6) {
            var dots = 6;
            foreach (var c; split(stby,"")) {
                if (c == '.') {
                    dots +=1;
                }
            }
            stby = substr(stby,0,dots);
        }
        var packet = me.freqTrigger(stby~active);
        me._device.sendOutputReport(240,packet);
        var refreshDisplay = [0x00, 0x01, 0x11, me._dev.dev1, me._dev.dev2, 0x00, 0x00, 0x03, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        me._device.sendOutputReport(240,refreshDisplay);
    },
    freqTrigger: func(message) {
        var packet = ['0x0', '0x1', '0x35', me._dev.dev1, me._dev.dev2, '0x0', '0x0', '0x2', '0x1', '0x0', '0x0', '0xff', '0xff', '0x0', '0x0', '0x0', '0x24', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x01', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0'];
        var rowoffs = [24,25,26,27,28,29,30,31,32,33,34,35,];
        var i = 0;
        var j = 0;
        var chars = split("",string.uc(message));
        while (j < 12) {
            var c = chars[i];
            if ( c == '.' and j != 0) {
                packet[rowoffs[j-1]] += 0x80;
                i += 1;
                c = chars[i];
            }
            if (contains(keys(tcasReps),c)) {
                packet[rowoffs[j]] += tcasReps[c];
            }
            i += 1;
            j += 1;
        }
        return packet;
    },
    turnKnob: func(knob,step) {
        # handle all knob functions for the 320
        # sorta an example how to do them for others
        # TODO set limits
        # TODO use hash to figure out limits and props
        # knob (0 outer, 1 inner)
        # step (-1 , +1)
        # figure out what radio is enabled to do the right thing
        if (me._rmpcProps.powerOn.getBoolValue()) {
            var chan = me._rmpStby.chSel.getValue() or 'vhf1';
            var prop = chan~"Stby";
            # TODO check voltage
            # vhf inner knob hack from a320 flightdeck
            # assign comm[0] stby freq
            # update inst ch
            # assign rmp from comm[0] freq
            # fgfs vhf won't let you in put crap, hf vor ils adf will
            if (string.match(chan,"vhf?")) {
                if (knob == 1) {
                    me._rmpStby['stbyMhz'].setValue(me._rmpStby[prop].getValue());
                    me._rmpStby['stbyCh'].adjustValue(step);
                    me._rmpStby[prop].setValue(me._rmpStby['stbyMhz'].getValue());
                } else {
                    me._rmpStby[prop].adjustValue(step);
                }
                checkFreq(me._rmpStby[prop],'vhf');
            } else if (string.match(chan,"hf?")) {
                if (knob == 1) {
                    me._rmpStby[prop].adjustValue(step);
                } else {
                    me._rmpStby[prop].adjustValue(step*100);
                }
                checkFreq(me._rmpStby[prop],'hf');
            } else if (string.match(chan,"adf")) {
                if (knob == 1) {
                    me._rmpStby[prop].adjustValue(step);
                } else {
                    me._rmpStby[prop].adjustValue(step*10);
                }
                checkFreq(me._rmpStby[prop],'adf');
            } else if (string.match(chan,"vor")) {
                if (me._rmpStby['selCrs'].getBoolValue()) {
                    if (knob == 1) {
                        me._rmpStby['vorCrs'].adjustValue(step);
                    } else {
                        me._rmpStby['vorCrs'].adjustValue(step*10);
                    }
                    checkFreq(me._rmpStby['vorCrs'],'crs');
                } else {
                    if (knob == 1) {
                        me._rmpStby[prop].adjustValue(step*0.05);
                    } else {
                        me._rmpStby[prop].adjustValue(step);
                    }
                    checkFreq(me._rmpStby[prop],'vor');
                }
            } else if (string.match(chan,"ls")) {
                if (me._rmpStby['selCrs'].getBoolValue()) {
                    if (knob == 1) {
                        me._rmpStby['lsCrs'].adjustValue(step);
                    } else {
                        me._rmpStby['lsCrs'].adjustValue(step*10);
                    }
                    checkFreq(me._rmpStby['lsCrs'],'crs');
                } else {
                    if (knob == 1) {
                        me._rmpStby[prop].adjustValue(step*0.05);
                    } else {
                        me._rmpStby[prop].adjustValue(step);
                    }
                    checkFreq(me._rmpStby[prop],'ls');
                }
            }
        }
    },
    _rmpStby: {
        'chSel': props.globals.getNode("/systems/radio/rmp[0]/sel_chan",1),
        'vhf1Stby': props.globals.getNode("/systems/radio/rmp[0]/vhf1-standby",1),
        'vhf2Stby': props.globals.getNode("/systems/radio/rmp[0]/vhf2-standby",1),
        'vhf3Stby': props.globals.getNode("/systems/radio/rmp[0]/vhf3-standby",1),
        'stbyMhz': props.globals.getNode("/instrumentation/comm[0]/frequencies/standby-mhz",1),
        'stbyCh': props.globals.getNode("/instrumentation/comm[0]/frequencies/standby-channel",1),
        'hf1Stby': props.globals.getNode("/systems/radio/rmp[0]/hf1-standby",1),
        'hf2Stby': props.globals.getNode("/systems/radio/rmp[0]/hf2-standby",1),
        'vorStby': props.globals.getNode("/instrumentation/nav[2]/frequencies/standby-mhz",1),
        'vorCrs': props.globals.getNode("/instrumentation/nav[2]/radials/selected-deg",1),
        'lsStby': props.globals.getNode("/instrumentation/nav[0]/frequencies/standby-mhz",1),
        'lsCrs': props.globals.getNode("/instrumentation/nav[]/radials/selected-deg",1),
        'adfStby': props.globals.getNode("/instrumentation/adf[0]/frequencies/standby-khz",1),
        'selCrs': props.globals.getNode("/systems/radio/rmp[0]/select-crs",1),
    },
};

var freqInfo = {
    'vhf': {'min':118.0,'max':137.0,'sInc':0.05,'bInc':1},
    'hf': {'min':2000,'max':29999,'sInc':1,'bInc':100},
    'adf': {'min':190,'max':1751,'sInc':1,'bInc':10},
    'ls': {'min':108.00,'max':112.00,'sInc':0.05,'bInc':1},
    'vor': {'min':108.00,'max':118.00,'sInc':0.05,'bInc':1},
    'crs': {'min':1,'max':360,'sInc':1,'bInc':10},
};
# wraparound frequency helper
var checkFreq = func(prop,carr) {
    var freq = prop.getValue();
    if (freq < freqInfo[carr]['min']) {
        prop.setValue(freqInfo[carr]['max']);
    } else if (freq > freqInfo[carr]['max']) {
        prop.setValue(freqInfo[carr]['min']);
    }
};

var tcasReps = {
    #      A
    #      ---
    #   F | G | B
    #      ---
    #   E |   | C
    #      ---
    #       D
    # segment test address
    #'a': 0x01,
    #'b': 0x02,
    #'c': 0x04,
    #'d': 0x08,
    #'e': 0x10,
    #'f': 0x20,
    #'g': 0x40,
    '0': 0x3f,
    '1': 0x06,
    '2': 0x5b,
    '3': 0x4f,
    '4': 0x66,
    '5': 0x6d,
    '6': 0x7d,
    '7': 0x07,
    '8': 0x7f,
    '9': 0x6f,
    ' ': 0x00,
    '-': 0x40,
    '_': 0x08,
    '[': 0x39,
    ']': 0x0f,
    'A': 0x77,
    'B': 0x7c,
    'C': 0x39,
    'D': 0x5e,
    'E': 0x79,
    'F': 0x71,
    'G': 0x6f,
    'H': 0x76,
    'I': 0x06,
    'J': 0x0e,
    'K': 0x7a,
    'L': 0x38,
    'M': 0x55,
    'N': 0x54,
    'O': 0x3f,
    'P': 0x73,
    'Q': 0x67,
    'R': 0x50,
    'S': 0x6d,
    'T': 0x78,
    'U': 0x3e,
    'V': 0x1c,
    'W': 0x6a,
    'X': 0x14,
    'Y': 0x6e,
    'Z': 0x5b,
};
