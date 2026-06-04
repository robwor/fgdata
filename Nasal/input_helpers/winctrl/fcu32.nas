# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2025 nia
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# FCU32 Helper

winctrl["fcu32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        me._device = device;
        me.type = check_family();
        me.path = "/input/winctrl/fcu32";
        me.listeners = [];
        me.leds = {};
        foreach (var l; keys(me._led)) {
            if (chr(l[size(l)-1]) == 'L') {
                var devs = [me._dev.dev1L,me._dev.dev2L];
            } else if (chr(l[size(l)-1]) == 'R') {
                var devs = [me._dev.dev1R,me._dev.dev2R];
            } else {
                var devs = [me._dev.dev1,me._dev.dev2];
            }
            var prop = me.path~"/leds/"~l;
            me.leds[l] = leddy.new(l,devs,me._led[l],prop);
            append(me.listeners,me.leds[l].autoReport(me._device));
        }
        # annun brightness not implmeneted so ensure leds illuminate
        me.leds.ledBrt.set(255);
        me.leds.ledBrtL.set(255);
        me.leds.ledBrtR.set(255);
        foreach (var k; keys(me._fcuProps)) {
            if(!contains(['spd','hdg','alt','vs','efisL','efisR'],k)) {
                me._fcuProps[k].setIntValue(0);
            }
        }
        me._fcuProps.spd.setValue('---');
        me._fcuProps.hdg.setValue('---');
        me._fcuProps.alt.setValue('-----');
        me._fcuProps.vs.setValue('----');
        me._fcuProps.efisL.setValue('----');
        me._fcuProps.efisR.setValue('----');
        foreach (var k; keys(me._fcuProps)) {
            if(!contains(['efisL','efisR','qnh','qfe'],k)) {
                append(me.listeners,setlistener(me._fcuProps[k], func() { me.updateFCUDisplay(); },1,0));
            } else {
                append(me.listeners,setlistener(me._fcuProps[k], func() { me.updateEFISDisplay('L'); me.updateEFISDisplay('R'); },1,0));
            }
        }
        if (me.type == 'A320') {
            me.doAirbus();
        } else {
            me.doBasic();
        }
        logprint(LOG_INFO,"WINCRL FCU32 ONLINE");
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
        logprint(LOG_INFO,"WINCTL FCU32 shutdown");
    },
    _lcdWatchProps: {
        "altStd": props.globals.getNode("/instrumentation/altimeter/std", 1),
        "inHgLeft": props.globals.getNode("/instrumentation/altimeter/inhg-left", 1),
        "inHgRight": props.globals.getNode("/instrumentation/altimeter/inhg-right", 1),
        "setInHg": props.globals.getNode("/instrumentation/altimeter/setting-inhg", 1),
        "setHpa": props.globals.getNode("/instrumentation/altimeter/setting-hpa", 1),
        "apKtsMach": props.globals.getNode("/it-autoflight/input/kts-mach", 1),
        "apMach": props.globals.getNode("/it-autoflight/input/mach", 1),
        "apKts": props.globals.getNode("/it-autoflight/input/kts", 1),
        "apHdg": props.globals.getNode("/it-autoflight/input/hdg", 1),
        "apTrk": props.globals.getNode("/it-autoflight/input/trk", 1),
        "apAlt": props.globals.getNode("/it-autoflight/input/alt", 1),
        "apFpa": props.globals.getNode("/it-autoflight/input/fpa", 1),
        "apVs": props.globals.getNode("/it-autoflight/input/vs", 1),
        "apVsAbs": props.globals.getNode("/it-autoflight/input/vs-abs", 1),
        "apVsFcu": props.globals.getNode("/it-autoflight/output/vs-fcu", 1),
        "spdDash": props.globals.getNode("/controls/indicators/fcu-spd-dash", 1),
        "spd": props.globals.getNode("/controls/indicators/fcu-spd", 1),
        "mach": props.globals.getNode("/controls/indicators/fcu-mach", 1),
        "spdMgt": props.globals.getNode("/controls/indicators/fcu-spd-mgt", 1),
        "latDash": props.globals.getNode("/controls/indicators/fcu-lat-dash", 1),
        "hdgVs": props.globals.getNode("/controls/indicators/fcu-hdg-vs", 1),
        "trkFpa": props.globals.getNode("/controls/indicators/fcu-trk-fpa", 1),
        # missing?
        #"hdgMgt": props.globals.getNode("/controls/indicators/fcu-hdg-mgt", 1),
        #"hdg": props.globals.getNode("/controls/indicators/fcu-hdg", 1),
        #"trk": props.globals.getNode("/controls/indicators/fcu-trk", 1),
        #"vs": props.globals.getNode("/controls/indicators/fcu-vs", 1),
        "lat": props.globals.getNode("/controls/indicators/fcu-lat", 1),
        "alt": props.globals.getNode("/controls/indicators/fcu-alt", 1),
        "altMgt": props.globals.getNode("/controls/indicators/fcu-alt-mgt", 1),
        "lvlCh": props.globals.getNode("/controls/indicators/fcu-lvlch", 1),
        "vsDash": props.globals.getNode("/controls/indicators/fcu-vs-dash", 1),
        "annun": props.globals.getNode("/controls/switches/annun-test", 1),
    },
    _fcuGenericProps: {
        "targSpdKt": props.globals.getNode("/autopilot/settings/target-speed-kt", 1),
        #"targSpdMach": props.globals.getNode("/autopilot/settings/target-speed-mach", 1),
        "targAltFt": props.globals.getNode("/autopilot/settings/target-altitude-ft", 1),
        "targVsFpm": props.globals.getNode("/autopilot/settings/vertical-speed-fpm", 1),
        "targHdg": props.globals.getNode("/autopilot/settings/heading-bug-deg", 1),
        "apAlt": props.globals.getNode("/instrumentation/annunciators/autoflight/ap/mode/alt",1),
        "apHdg": props.globals.getNode("/instrumentation/annunciators/autoflight/ap/mode/hdg",1),
        "apKts": props.globals.getNode("/instrumentation/annunciators/autoflight/ap/mode/ias",1),
        #: props.globals.getNode("/instrumentation/annunciators/autoflight/ap/mode/nav",1),
        #: props.globals.getNode("/instrumentation/annunciators/autoflight/ap/mode/rev",1),
        "apVS": props.globals.getNode("/instrumentation/annunciators/autoflight/ap/mode/vs",1),
    },
    _annunLEDProps: {
        "ap1": props.globals.getNode("/instrumentation/annunciators/autoflight/ap/enabled",1),
        "appr": props.globals.getNode("/instrumentation/annunciators/autoflight/ap/mode/apr",1),
        "fdL": props.globals.getNode("/instrumentation/annunciators/autoflight/flightdirector/enabled",1),
    },
    _ledWatchProps: {
        "panel": props.globals.getNode("/controls/lighting/fcu-panel-norm", 1),
        "panelL": props.globals.getNode("/controls/lighting/fcu-panel-norm", 1),
        "panelR": props.globals.getNode("/controls/lighting/fcu-panel-norm", 1),
        "expedBack": props.globals.getNode("/controls/lighting/fcu-panel-norm", 1),
        "lcd": props.globals.getNode("/controls/lighting/fcu-digit-norm", 1),
        "lcdL": props.globals.getNode("/controls/lighting/fcu-digit-norm", 1),
        "lcdR": props.globals.getNode("/controls/lighting/fcu-digit-norm", 1),
        "ap1": props.globals.getNode("/controls/indicators/fcu-ap1", 1),
        "ap2": props.globals.getNode("/controls/indicators/fcu-ap2", 1),
        "athr": props.globals.getNode("/controls/indicators/fcu-athr", 1),
        "exped": props.globals.getNode("/controls/indicators/fcu-exped", 1),
        "appr": props.globals.getNode("/controls/indicators/fcu-appr", 1),
        "loc": props.globals.getNode("/controls/indicators/fcu-loc", 1),
        "cstrL": props.globals.getNode("/controls/indicators/efis-capt-cstr", 1),
        "wptL": props.globals.getNode("/controls/indicators/efis-capt-wpt", 1),
        "vordL": props.globals.getNode("/controls/indicators/efis-capt-vord", 1),
        "ndbL": props.globals.getNode("/controls/indicators/efis-capt-ndb", 1),
        "arptL": props.globals.getNode("/controls/indicators/efis-capt-arpt", 1),
        "fdL": props.globals.getNode("/controls/indicators/efis-capt-fd", 1),
        "lsL": props.globals.getNode("/controls/indicators/efis-capt-ls", 1),
        "cstrR": props.globals.getNode("/controls/indicators/efis-fo-cstr", 1),
        "wptR": props.globals.getNode("/controls/indicators/efis-fo-wpt", 1),
        "vordR": props.globals.getNode("/controls/indicators/efis-fo-vord", 1),
        "ndbR": props.globals.getNode("/controls/indicators/efis-fo-ndb", 1),
        "arptR": props.globals.getNode("/controls/indicators/efis-fo-arpt", 1),
        "fdR": props.globals.getNode("/controls/indicators/efis-fo-fd", 1),
        "lsR": props.globals.getNode("/controls/indicators/efis-fo-ls", 1),
    },
    _dev: {
        'dev1': 0x10,
        'dev2': 0xBB,
        'dev1L': 0x0D, # CAPT
        'dev2L': 0xBF,
        'dev1R': 0x0E, # FO
        'dev2R': 0xBF,
    },
    _led: {
        'panel': 0x00,
        'panelL': 0x00,
        'panelR': 0x00,
        'lcd': 0x01,
        'lcdL': 0x01,
        'lcdR': 0x01,
        'ledBrt': 0x02,
        'ledBrtL': 0x02,
        'ledBrtR': 0x02,
        'expedBack': 0x1E,
        'ap1': 0x05,
        'ap2': 0x07,
        'athr': 0x09,
        'exped': 0x0B,
        'appr': 0x0D,
        'loc': 0x03,
        'cstrL': 0x05,
        'wptL': 0x06,
        'vordL': 0x07,
        'ndbL': 0x08,
        'arptL': 0x09,
        'fdL': 0x03,
        'lsL': 0x04,
        'cstrR': 0x05,
        'wptR': 0x06,
        'vordR': 0x07,
        'ndbR': 0x08,
        'arptR': 0x09,
        'fdR': 0x03,
        'lsR': 0x04,
    },
    _fcuProps: {
        "spd": props.globals.getNode("/input/winctrl/fcu32/lcd/spd", 1),
        "hdg": props.globals.getNode("/input/winctrl/fcu32/lcd/hdg", 1),
        "alt": props.globals.getNode("/input/winctrl/fcu32/lcd/alt", 1),
        "vs": props.globals.getNode("/input/winctrl/fcu32/lcd/vs", 1),
        "efisL": props.globals.getNode("/input/winctrl/fcu32/lcd/efisL", 1),
        "efisR": props.globals.getNode("/input/winctrl/fcu32/lcd/efisR", 1),
        # FCU LCD display bits
        # these are the raw values the device expects to be added to other bytes
        # TODO consider making them just binary flags and handle it during update
        "qnh": props.globals.getNode("/input/winctrl/fcu32/lcd/qnh", 1),
        "qfe": props.globals.getNode("/input/winctrl/fcu32/lcd/qfe", 1),
        "flgSpd": props.globals.getNode("/input/winctrl/fcu32/lcd/flgSpd", 1),
        "flgMach": props.globals.getNode("/input/winctrl/fcu32/lcd/flgMach", 1),
        "flgSpdMgt": props.globals.getNode("/input/winctrl/fcu32/lcd/flgSpdMgt", 1),
        "flgHdg": props.globals.getNode("/input/winctrl/fcu32/lcd/flgHdg", 1),
        "flgTrk": props.globals.getNode("/input/winctrl/fcu32/lcd/flgTrk", 1),
        "flgLat": props.globals.getNode("/input/winctrl/fcu32/lcd/flgLat", 1),
        "flgHdgVs": props.globals.getNode("/input/winctrl/fcu32/lcd/flgHdgVs", 1),
        "flgTrkFpa": props.globals.getNode("/input/winctrl/fcu32/lcd/flgHdgFpa", 1),
        "flgAlt": props.globals.getNode("/input/winctrl/fcu32/lcd/flgAlt", 1),
        "flgAltMgt": props.globals.getNode("/input/winctrl/fcu32/lcd/flgAltMgt", 1),
        "flgVs": props.globals.getNode("/input/winctrl/fcu32/lcd/flgVs", 1),
        "flgFpa": props.globals.getNode("/input/winctrl/fcu32/lcd/flgFpa", 1),
        "flgLvlch": props.globals.getNode("/input/winctrl/fcu32/lcd/flgLvlch", 1),
    },
    doBasic: func() {
        me.leds.ledBrt.set(255);
        me.leds.lcd.set(255);
        me.leds.lcdL.set(255);
        me.leds.lcdR.set(255);
        # these have to be set for the knob bindings to function
        me._lcdWatchProps.altStd.setIntValue(0);
        setprop("systems/electrical/bus/dc-ess",27);
        append(me.listeners,setlistener(me._lcdWatchProps.inHgRight, func() { me.setEFISDisplay('R'); },1,0));
        append(me.listeners,setlistener(me._lcdWatchProps.inHgLeft, func() { me.setEFISDisplay('L'); },1,0));
        append(me.listeners,setlistener(me._lcdWatchProps.setInHg, func() { me.setEFISDisplay('L'); me.setEFISDisplay('R'); },1,0));
        append(me.listeners,setlistener(me._lcdWatchProps.setHpa, func() { me.setEFISDisplay('L'); me.setEFISDisplay('R'); },1,0));
        #append(me.listeners,setlistener(me._lcdWatchProps.altStd, func() { me.setEFISDisplay('L'); me.setEFISDisplay('R'); },0,0));
        me.watchGenericFCU();
    },
    watchAirbusLEDs: func() {
        foreach(var led; keys(me._ledWatchProps)) {
            append(me.listeners,me.leds[led].watch(me._ledWatchProps[led]));
        }
    },
    doAirbus: func() {
        me.watchEFIS();
        me.watchAirbusLEDs();
        me.watchFCU();
    },
    #       A
    #      ---
    #   F | G | B
    #      ---
    #   E |   | C
    #      ---
    #       D
    # A=0x80, B=0x40, C=0x20, D=0x10, E=0x02, F=0x08, G=0x04
    # Bits are valid for Speed display only, all other share bits in 2 databyte per lcd 7-segment display.
    # Use function dataFromStringSwapped to recalculate values
    # Map from decimal digit to hex representation needed for the device, special character "-" at index 10
    setFCUDisplay: func() {
        var speed = "";
        var hdg = "";
        var alt = "";
        var vs = "";
        if (me._ledWatchProps.lcd.getValue() != 0) {
            # SPD window
            if (me._lcdWatchProps.annun.getIntValue()) {
                me._fcuProps.spd.setValue(".8.8.8");
                me._fcuProps.flgSpd.setIntValue(1);
                me._fcuProps.flgMach.setIntValue(1);
                me._fcuProps.flgSpdMgt.setIntValue(1);
                me._fcuProps.hdg.setValue(".8.8.8");
                me._fcuProps.flgHdg.setIntValue(1);
                me._fcuProps.flgTrk.setIntValue(1);
                me._fcuProps.flgFpa.setIntValue(1);
                me._fcuProps.flgHdgVs.setIntValue(1);
                me._fcuProps.flgTrkFpa.setIntValue(1);
                me._fcuProps.flgLat.setIntValue(1);
                me._fcuProps.alt.setValue("88888");
                me._fcuProps.flgAlt.setIntValue(1);
                me._fcuProps.flgAltMgt.setIntValue(1);
                me._fcuProps.flgLvlch.setIntValue(1);
                me._fcuProps.vs.setValue("+8.888");
                me._fcuProps.flgVs.setIntValue(1);
                me._fcuProps.flgFpa.setIntValue(1);
            } else {
                if (me._lcdWatchProps.spdDash.getValue()) {
                    speed = "---";
                } else if (me._lcdWatchProps.apKtsMach.getValue()) {
                    speed = sprintf("%3.3f", me._lcdWatchProps.apMach.getValue());
                    speed = utf8.substr(speed,1,4);
                } else {
                    speed = sprintf("%03.0f", me._lcdWatchProps.apKts.getValue());
                }
                me._fcuProps.spd.setValue(speed);

                # SPD flags
                me._fcuProps.flgSpd.setIntValue(me._lcdWatchProps.spd.getIntValue());
                me._fcuProps.flgMach.setIntValue(me._lcdWatchProps.mach.getIntValue());
                me._fcuProps.flgSpdMgt.setIntValue(me._lcdWatchProps.spdMgt.getIntValue());

                # HDG window
                if (me._lcdWatchProps.latDash.getValue()) {
                    hdg = "---";
                } else {
                    hdg = sprintf("%03.0f", (me._lcdWatchProps.apHdg.getValue() or 888));
                }
                me._fcuProps.hdg.setValue(hdg);

                # HDG flags
                # FIXME - some of these aren't exposed in FCU
                if (me._lcdWatchProps.hdgVs.getIntValue()) {
                    me._fcuProps.flgHdg.setIntValue(1);
                    me._fcuProps.flgVs.setIntValue(1);
                    me._fcuProps.flgTrk.setIntValue(0);
                    me._fcuProps.flgFpa.setIntValue(0);
                } else if (me._lcdWatchProps.trkFpa.getIntValue()) {
                    me._fcuProps.flgHdg.setIntValue(0);
                    me._fcuProps.flgVs.setIntValue(0);
                    me._fcuProps.flgTrk.setIntValue(1);
                    me._fcuProps.flgFpa.setIntValue(1);
                }
                me._fcuProps.flgHdgVs.setIntValue(me._lcdWatchProps.hdgVs.getIntValue());
                me._fcuProps.flgTrkFpa.setIntValue(me._lcdWatchProps.trkFpa.getIntValue());
                me._fcuProps.flgLat.setIntValue(me._lcdWatchProps.lat.getIntValue());

                # ALT window
                alt = sprintf("%05.0f", (me._lcdWatchProps.apAlt.getValue() or 88888));
                me._fcuProps.alt.setValue(alt);

                # ALT flags
                me._fcuProps.flgAlt.setIntValue(me._lcdWatchProps.alt.getIntValue());
                me._fcuProps.flgAltMgt.setIntValue(me._lcdWatchProps.altMgt.getIntValue());

                # LVL CH flags
                me._fcuProps.flgLvlch.setIntValue(me._lcdWatchProps.lvlCh.getIntValue());

                # VS window
                if (me._lcdWatchProps.vsDash.getValue()) {
                    vs = "----";
                } else {
                    if (me._lcdWatchProps.apTrk.getValue()) {
                        vs = sprintf("%+03.1f", me._lcdWatchProps.apFpa.getValue())~"  ";
                    } else {
                        vs = sprintf("%+05.0f", (me._lcdWatchProps.apVs.getValue()));
                    }
                }
                me._fcuProps.vs.setValue(vs);
            }
        }
    },
    setGenericFCU: func() {
        me._fcuProps.spd.setValue(sprintf("%03.0f", me._fcuGenericProps.targSpdKt.getValue()) or "---");
        me._fcuProps.hdg.setValue(sprintf("%03.0f", me._fcuGenericProps.targHdg.getValue()) or "---");
        me._fcuProps.alt.setValue(sprintf("%05.0f", me._fcuGenericProps.targAltFt.getValue()) or "-----");
        me._fcuProps.vs.setValue(sprintf("%+05.0f", me._fcuGenericProps.targVsFpm.getValue()) or "----");
        me._fcuProps.flgAltMgt.setValue(me._fcuGenericProps.apAlt.getIntValue() or 0);
        me._fcuProps.flgHdg.setValue(me._fcuGenericProps.apHdg.getIntValue() or 0);
        me._fcuProps.flgSpdMgt.setValue(me._fcuGenericProps.apKts.getIntValue() or 0);
        me._fcuProps.flgVs.setValue(me._fcuGenericProps.apVS.getIntValue() or 0);
    },
    watchGenericFCU: func() {
        me._fcuProps.flgSpd.setIntValue(1);
        me._fcuProps.flgHdg.setIntValue(1);
        me._fcuProps.flgAlt.setIntValue(1);
        me._fcuProps.flgVs.setIntValue(1);
        foreach(var prop; keys(me._fcuGenericProps)) {
            append(me.listeners,setlistener(me._fcuGenericProps[prop], func() { me.setGenericFCU(); },1,0));
        }
        foreach (var led; keys(me._annunLEDProps)) {
            append(me.listeners,me.leds[led].watch(me._annunLEDProps[led]));
        }
    },

    updateFCUDisplay: func() {
        var aspeed = dataFromString(3, me._fcuProps.spd.getValue());
        var ahdg = dataFromStringSwapped(3, me._fcuProps.hdg.getValue());
        var aalt = dataFromStringSwapped(5, me._fcuProps.alt.getValue());
        var avs = dataFromStringSwapped(4, me._fcuProps.vs.getValue());
        var speed = aspeed[0];
        var hdg = ahdg[0];
        var alt = aalt[0];
        var vs = avs[0];
        var spdFlags = 0x00;
        if (me._fcuProps.flgSpd.getIntValue()) {
            spdFlags += 0x08;
        }
        if (me._fcuProps.flgMach.getIntValue()) {
            spdFlags += 0x04;
        }
        if (me._fcuProps.flgSpdMgt.getIntValue()) {
            spdFlags += 0x02;
        }
        var hdgFlags = 0x00;
        var hdgTrkFlags = 0x00;
        var vsFlags = 0x00;
        if (me._fcuProps.flgHdg.getIntValue()) {
            hdgFlags += 0x80;
        }
        if (me._fcuProps.flgHdgVs.getIntValue()) {
            hdgTrkFlags += 0x0C;
        }
        if (me._fcuProps.flgVs.getIntValue()) {
            vsFlags += 0x40;
        }
        if (me._fcuProps.flgTrk.getIntValue()) {
            hdgFlags += 0x40;
        }
        if (me._fcuProps.flgTrkFpa.getIntValue()) {
            hdgTrkFlags += 0x03;
        }
        if (me._fcuProps.flgFpa.getIntValue()) {
            vsFlags += 0x80;
        }
        if (me._fcuProps.flgLat.getIntValue()) {
            hdgFlags += 0x30;
        }
        var altFlags = 0x00;
        var altMgtFlags = 0x00;
        if (me._fcuProps.flgAlt.getIntValue()) {
            altFlags += 0x10;
        }
        if (me._fcuProps.flgAltMgt.getIntValue()) {
            altMgtFlags += 0x10;
        }
        var lvlchFlags1 = 0x00;
        var lvlchFlags2 = 0x00;
        var lvlchFlags3 = 0x00;
        if (me._fcuProps.flgLvlch.getIntValue()) {
            lvlchFlags1 += 0x10;
            lvlchFlags2 += 0x10;
            lvlchFlags3 += 0x10;
        }
        var vsComma = 0x00;
        if (avs[1]) {
            vsComma += 0x10;
        }
        var minus = 0x00;
        var plus = 0x00;
        if (avs[2] == "-") {
            minus += 0x10;
        } else if (avs[2] == "+") {
            plus += 0x10;
            minus += 0x10;
        }
        var report = [0x0, 0xab, 0x31, me._dev.dev1, me._dev.dev2, 0x0, 0x0, 0x2, 0x1, 0x0, 0x0, 0xff, 0xff, 0x2, 0x0, 0x0, 0x20, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, speed[0], speed[1], speed[2], hdg[0] + spdFlags, hdg[1], hdg[2], hdg[3] + hdgFlags, alt[0] + hdgTrkFlags, alt[1] + altFlags, alt[2] + lvlchFlags1, alt[3] + lvlchFlags2, alt[4] + lvlchFlags3, alt[5] + minus + vs[0], vs[1] + vsComma, vs[2] + plus, vs[3] + altMgtFlags, vs[4] + vsFlags, 0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0];
        me._device.sendOutputReport(240,report);
        var refreshReport = [0x0, 0xab, 0x11, me._dev.dev1, me._dev.dev2, 0x0, 0x0, 0x3, 0x1, 0x0, 0x0, 0xff, 0xff, 0x2, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0];
        me._device.sendOutputReport(240,refreshReport);
    },
    watchFCU: func() {
        foreach ( var k; keys(me._lcdWatchProps)) {
            if (!contains(['inHgRight','inHgLeft','setInHg','setHpa','altStd'],k)) {
                append(me.listeners,setlistener(me._lcdWatchProps[k], func() { me.setFCUDisplay(); },1,0));
            }
        }
    },
    watchEFIS: func() {
        foreach ( var k; ['setInHg','setHpa','altStd','annun']) {
            append(me.listeners,setlistener(me._lcdWatchProps[k], func() { me.setEFISDisplay('L'); me.setEFISDisplay('R'); },1,0));
        }
        append(me.listeners,setlistener(me._lcdWatchProps.inHgRight, func() { me.setEFISDisplay('R'); },1,0));
        append(me.listeners,setlistener(me._lcdWatchProps.inHgLeft, func() { me.setEFISDisplay('L'); },1,0));
    },
    # do both EFIS devices in one function
    setEFISDisplay: func(side) {
        if ( side == "R" ) {
            var node = me._lcdWatchProps.inHgRight;
            var prop = me._fcuProps.efisR;
        }
        else {
            var node = me._lcdWatchProps.inHgLeft;
            var prop = me._fcuProps.efisL;
        }
        if (me._ledWatchProps.lcd.getValue() != 0) {
            if (me._lcdWatchProps.annun.getValue()) {
                prop.setValue("8.8.8.8.");
                me._fcuProps.qnh.setIntValue(1); # Change this being hard coded when the A320 implements QFE
                me._fcuProps.qfe.setIntValue(1);
            } else {
                me._fcuProps.qnh.setIntValue(1);
                me._fcuProps.qfe.setIntValue(0);
                if (me._lcdWatchProps.altStd.getValue() == 1)
                {
                    prop.setValue("std ");
                } else if (node.getIntValue() == 1) {
                    prop.setValue(sprintf("%04.2f", (me._lcdWatchProps.setInHg.getValue() or 88.88)));
                } else {
                    prop.setValue(sprintf("%4.0f", (me._lcdWatchProps.setHpa.getValue() or 8888)));
                }
            }
        }
    },
    # Capt EFIS
    #       A
    #      ---
    #   F | G | B
    #      ---
    #   E |   | C
    #      ---
    #       D
    # A=0x10, B=0x20, C=0x40, D=0x08, E=0x04, F=0x01, G=0x02
    # Map from decimal digit to hex representation needed for the device
    efisReps: {
        '0': 0x7d,
        '1': 0x60,
        '2': 0x3e,
        '3': 0x7a,
        '4': 0x63,
        '5': 0x5b,
        '6': 0x5f,
        '7': 0x70,
        '8': 0x7f,
        '9': 0x7b,
        'a': 0x77,
        'b': 0x4f,
        'c': 0x0e,
        'd': 0x6e,
        'e': 0x1f,
        'f': 0x17,
        'g': 0x7b,
        'h': 0x47,
        'i': 0x40,
        'j': 0x6c,
        'l': 0x0d,
        'n': 0x46,
        'o': 0x4e,
        'p': 0x37,
        'q': 0x73,
        'r': 0x06,
        's': 0x5b,
        't': 0x0f,
        'u': 0x4c,
        'y': 0x6b,
        '-': 0x02,
        '_': 0x08,
    },
    dataFromStringEFIS: func(stringy) {
        var ret = [];
        foreach( item; split("",stringy)) {
            if (item == "." and size(ret) > 0) {
                ret[size(ret)-1] += 0x80;
            } else {
                if (contains(keys(me.efisReps),string.lc(item))) {
                    append(ret,me.efisReps[string.lc(item)]);
                }
                else {
                    append(ret,0x00);
                }
            }
            if (size(ret) == 4) {
                break;
            }
        }
        while (size(ret) < 4) {
            append(ret,0x00);
        }
        return ret;
    },
    updateEFISDisplay: func(side) {
        if ( side == "R" ) {
            var devs = [ me._dev.dev1R, me._dev.dev2R ];
            var node = me._fcuProps.efisR;
        }
        else {
            var devs = [ me._dev.dev1L, me._dev.dev2L ];
            var node = me._fcuProps.efisL;
        }
        var qnhQfe = 0x00;
        if (me._fcuProps.qfe.getIntValue()) {
            qnhQfe += 0x01;
        }
        if (me._fcuProps.qnh.getIntValue()) {
            qnhQfe += 0x02;
        }
        var digits = me.dataFromStringEFIS(node.getValue());
        var report = [0x00, 0xab, 0x1a, devs[0], devs[1], 0x00, 0x00, 0x2, 0x1, 0x00, 0x00, 0xff, 0xff, 0x1d, 0x00, 0x00, 0x9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, digits[0], digits[1], digits[2], digits[3], qnhQfe, 0x0e, 0xbf, 0x00, 0x00, 0x3, 0x1, 0x00, 0x00, 0x4c, 0xc, 0x1d, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        me._device.sendOutputReport(240,report);
    },
};
