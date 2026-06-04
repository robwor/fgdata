# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# AGP helper

winctrl["agp32"] = {
    new: func(cfgnode,device) {
        var m = {
            parents: [me, input_helpers.config_manager.new(cfgnode)],
        };
        me._device = device;
        me.type = check_family();
        me.path = "/input/winctrl/agp32";
        me.listeners = [];
        me.leds = {};
        foreach (var l; keys(me._led)) {
            var devs = [me._dev.dev1,me._dev.dev2];
            var prop = m.path~"/leds/"~l;
            me.leds[l] = leddy.new(l,devs,me._led[l],prop);
            append(me.listeners,me.leds[l].autoReport(me._device));
        }
        me.leds.ledBrt.set(255);
        me.leds.lcd.set(255);
        # init some props
        me._agpProps.chrono.setValue("");
        me._agpProps.utc.setValue("--:--:--");
        me._agpProps.et.setValue("");
        # these should be set elsewhere but we init them anyways
        foreach (var k; keys(me._clockProps)) {
            if (contains(['setKnob','utcSelector','setCont'],k)) {
                me._clockProps[k].setIntValue(0);
            } else if (contains(['chrStarted','intBlinkYear','intBlinkMonth','intBlinkDay','intBlinkHH','intBlinkMM'],k)) {
                me._clockProps[k].setBoolValue(false);
            } else if (contains(['utcTime','utcDate','intDate'],k)) {
                me._clockProps[k].setValue("        ");
            } else if (contains(['intHH','intMM','intSS','intYear','intMonth','intDay'],k)) {
                me._clockProps[k].setValue("  ");
            }
        }
        me._chronoProps.chrStarted.setBoolValue(false);
        # 5 values __:__
        me._chronoProps.chrEt.setValue("     ");
        me._elapsedProps.elapsed.setValue("     ");
        # add some listeners
        foreach (var k; keys(me._agpProps)) {
            append(me.listeners,setlistener(me._agpProps[k], func() { me.updateDisplay(); },0,0));
        }
        foreach ( var prop; keys(me._clockProps)) {
            append(me.listeners,setlistener(me._clockProps[prop], func() { me.setUtcDisp(); },0,0));
        }
        foreach ( var prop; keys(me._chronoProps)) {
            append(me.listeners,setlistener(me._chronoProps[prop], func() { me.setChronoDisp(); },0,0));
        }
        foreach ( var prop; keys(me._elapsedProps)) {
            append(me.listeners,setlistener(me._elapsedProps[prop], func() { me.setElapsedDisp(); },0,0));
        }
        if (me.type == 'A320') {
            me.doAirbus();
        } else {
            me.watchAnnunLEDs();
        }
        logprint(LOG_INFO,"WINCRL AGP32 ONLINE");
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
        logprint(LOG_INFO,"WINCTL AGP32 shutdown");
    },
    _ledWatchProps: {
        "panel": props.globals.getNode("/controls/lighting/main-panel-norm", 1),
        "lcd": props.globals.getNode("/controls/lighting/main-panel-norm-digital", 1),
        "gearLU": props.globals.getNode("/controls/indicators/gear-left-unlocked", 1),
        "gearNU": props.globals.getNode("/controls/indicators/gear-nose-unlocked", 1),
        "gearRU": props.globals.getNode("/controls/indicators/gear-right-unlocked", 1),
        "brakeHot": props.globals.getNode("/controls/indicators/brake-hot", 1),
        "gearLD": props.globals.getNode("/controls/indicators/gear-left-down", 1),
        "gearND": props.globals.getNode("/controls/indicators/gear-nose-down", 1),
        "gearRD": props.globals.getNode("/controls/indicators/gear-right-down", 1),
        "brakeFan": props.globals.getNode("/controls/indicators/brake-fan-on", 1),
        "brakeALD": props.globals.getNode("/controls/indicators/autobrake-low-decel", 1),
        "brakeAMD": props.globals.getNode("/controls/indicators/autobrake-med-decel", 1),
        "brakeAXD": props.globals.getNode("/controls/indicators/autobrake-max-decel", 1),
        "brakeALO": props.globals.getNode("/controls/indicators/autobrake-low-on", 1),
        "brakeAMO": props.globals.getNode("/controls/indicators/autobrake-med-on", 1),
        "brakeAXO": props.globals.getNode("/controls/indicators/autobrake-max-on", 1),
        "terrFO": props.globals.getNode("/controls/indicators/terr-on-nd-fo", 1),
        "gearWarn": props.globals.getNode("/controls/indicators/gear-warning-arrow", 1),
    },
    _ledAnnunProps: {
        "gearLU": props.globals.getNode("/instrumentation/annunciators/gear/left/in-transition", 1),
        "gearNU": props.globals.getNode("/instrumentation/annunciators/gear/nose/in-transition", 1),
        "gearRU": props.globals.getNode("/instrumentation/annunciators/gear/right/in-transition", 1),
        "gearLD": props.globals.getNode("/instrumentation/annunciators/gear/left/down", 1),
        "gearND": props.globals.getNode("/instrumentation/annunciators/gear/nose/down", 1),
        "gearRD": props.globals.getNode("/instrumentation/annunciators/gear/right/down", 1),
    },
    _clockProps: {
        "setKnob": props.globals.getNode("/instrumentation/clock/set-knob", 1),
        "utcSelector": props.globals.getNode("/instrumentation/clock/utc-selector", 1),
        "utcTime": props.globals.getNode("/instrumentation/clock/indicated-string", 1),
        "utcDate": props.globals.getNode("/instrumentation/clock/date", 1),
        "intDate": props.globals.getNode("/instrumentation/clock/internal/date", 1),
        "intHH": props.globals.getNode("/instrumentation/clock/internal/indicated-hours", 1),
        "intMM": props.globals.getNode("/instrumentation/clock/internal/indicated-minutes", 1),
        "intSS": props.globals.getNode("/instrumentation/clock/internal/indicated-seconds", 1),
        "intYear": props.globals.getNode("/instrumentation/clock/internal/date-year", 1),
        "intMonth": props.globals.getNode("/instrumentation/clock/internal/date-month", 1),
        "intDay": props.globals.getNode("/instrumentation/clock/internal/date-day", 1),
        "setCont": props.globals.getNode("/instrumentation/clock/internal/set-cont", 1),
        "intBlinkHH": props.globals.getNode("/instrumentation/clock/internal/blink-hh", 1),
        "intBlinkMM": props.globals.getNode("/instrumentation/clock/internal/blink-mm", 1),
        "intBlinkYear": props.globals.getNode("/instrumentation/clock/internal/blink-year", 1),
        "intBlinkMonth": props.globals.getNode("/instrumentation/clock/internal/blink-month", 1),
        "intBlinkDay": props.globals.getNode("/instrumentation/clock/internal/blink-day", 1),
        "annun": props.globals.getNode("/controls/switches/annun-test", 1),
    },
    _chronoProps: {
        # chrono
        "chrStarted": props.globals.getNode("/instrumentation/clock/chrono/started", 1),
        "chrEt": props.globals.getNode("/instrumentation/clock/chrono/chr-et-string", 1),
        "annun": props.globals.getNode("/controls/switches/annun-test", 1),
    },
    _elapsedProps: {
        # elapsed time
        "elapsed": props.globals.getNode("/instrumentation/clock/et/elapsed-string", 1),
        "annun": props.globals.getNode("/controls/switches/annun-test", 1),
    },
    _agpProps: {
        "chrono": props.globals.getNode("/input/winctrl/agp32/chr-message", 1),
        "utc": props.globals.getNode("/input/winctrl/agp32/utc-message", 1),
        "et": props.globals.getNode("/input/winctrl/agp32/et-message", 1),
    },
    _dev: {
        'dev1': 0x80,
        'dev2': 0xBB,
    },
    _led: {
        'panel': 0x00,
        'lcd': 0x01,
        'ledBrt': 0x02,
        'gearLU': 0x03,
        'gearNU': 0x04,
        'gearRU': 0x05,
        'brakeHot': 0x06,
        'gearLD': 0x07,
        'gearND': 0x08,
        'gearRD': 0x09,
        'brakeFan': 0x0A,
        'brakeALD': 0x0B,
        'brakeAMD': 0x0C,
        'brakeAXD': 0x0D,
        'brakeALO': 0x0E,
        'brakeAMO': 0x0F,
        'brakeAXO': 0x10,
        'terrFO': 0x11,
        'gearWarn': 0x12,
    },
    chronoTrigger: func(ct,time,et) {
        var packet = ['0x0', '0x1', '0x35', me._dev.dev1, me._dev.dev2, '0x0', '0x0', '0x2', '0x1', '0x0', '0x0', '0xff', '0xff', '0x0', '0x0', '0x0', '0x24', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x01', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0'];
        # shift by -1 for python values
        var row_offsets = [24, 28, 32, 36, 40, 44, 48, 52];
        var colon = func(digis) {
            var mask = 0;
            var position = 0;
            var colons = [2, 7, 10, 15];
            var digits = "";
            foreach (var i; split("", digis)) {
                if (vecindex(colons,position) != nil) {
                    if (i == ':' or i == ".") {
                        var len_digits = size(digits);
                        if (len_digits < 10 and len_digits > 4) {
                            if (i == ':') {
                                mask = mask | lshift(len_digits - 1);
                            }
                            mask = mask | lshift(len_digits);
                        } else {
                            if (i == ':') {
                                mask = mask | lshift(len_digits);
                            }
                            mask = mask | lshift(len_digits + 1);
                        }
                    }
                } else {
                    digits = digits ~ i;
                }
                position += 1;
            }
            return [digits, mask];
        };
        # fix values first 5, 8, 5 chars
        var fixClock = func(time,dim) {
            var newtime = "";
            var mark = [2,5];
            var didx = 0;
            foreach (var digit; split("",time)) {
                if (vecindex(mark,didx) != nil and !contains(['.',':',' '],digit)) {
                    newtime = newtime ~ " ";
                }
                newtime = newtime ~ digit;
                didx = utf8.size(newtime);
            }
            while (utf8.size(newtime) < dim) {
                newtime = newtime ~ " ";
            }
            if (utf8.size(newtime) > dim) {
                newtime = utf8.substr(newtime,0,dim);
            }
            return newtime;
        }
        var fulldigits = fixClock(ct,5) ~ fixClock(time,8) ~ fixClock(et,5);
        var result = colon(fulldigits);
        var all_digits = result[0];
        var colon_mask = result[1];
        #print(fulldigits, all_digits, colon_mask);
        var all_split = split("",string.uc(all_digits));
        for (var digit_index = 0; digit_index < 14; digit_index += 1) {
            var c = all_split[digit_index];
            if (contains(keys(lcdReps),c)) {
                var char_mask = lcdReps[c];
            } else {
                var char_mask = lcdReps[" "];
            }
            for (var seg_index = 0; seg_index < 7; seg_index += 1) {
                if (char_mask & lshift(seg_index)) {
                    var byte_offset = row_offsets[seg_index] + int(digit_index / 8);
                    var bit_pos = math.mod(digit_index, 8);
                    packet[byte_offset] = packet[byte_offset] | lshift(bit_pos);
                }
            }
            if (colon_mask & lshift(digit_index)) {
                var byte_offset = row_offsets[7] + int(digit_index / 8);
                var bit_pos = math.mod(digit_index, 8);
                packet[byte_offset] = packet[byte_offset] | lshift(bit_pos);
            }
        }
        return packet;
    },
    clocky: func() {
        # clock/internal/ has a lot more properties than GPS
        # utc-selector decision tree
        if (me._clockProps.setKnob.getIntValue() == 0) {
            if (me._clockProps.utcSelector.getIntValue() == 0) {
                return me._clockProps.utcTime.getValue();
            } else if (me._clockProps.utcSelector.getIntValue() == 1) {
                var hh = me._clockProps.intHH.getValue();
                var mm = me._clockProps.intMM.getValue();
                var ss = me._clockProps.intSS.getValue();
                return hh~":"~mm~" "~ss;
            } else if (me._clockProps.utcSelector.getIntValue() == 2) {
                var setting = me._clockProps.setCont.getIntValue();
                if (setting <= 2) {
                    if (me._clockProps.intBlinkHH.getBoolValue() != true) {
                        var hh = "  ";
                    } else {
                        var hh = me._clockProps.intHH.getValue();
                    }
                    if (me._clockProps.intBlinkMM.getBoolValue() != true) {
                        var mm = "  ";
                    } else {
                        var mm = me._clockProps.intMM.getValue();
                    }
                    var ss = "  ";
                    return hh~":"~mm~" "~ss;
                } else {
                    if (me._clockProps.intBlinkYear.getBoolValue() != true) {
                        var iy = "  ";
                    } else {
                        var iy = me._clockProps.intYear.getValue();
                    }
                    if (me._clockProps.intBlinkMonth.getBoolValue() != true) {
                        var im = "  ";
                    } else {
                        var im = me._clockProps.intMonth.getValue();
                    }
                    if (me._clockProps.intBlinkDay.getBoolValue() != true) {
                        var id = "  ";
                    } else {
                        var id = me._clockProps.intDay.getValue();
                    }
                    return im~" "~id~" "~iy;
                }
            }
        } else if (me._clockProps.setKnob.getIntValue() == 1) {
            if (me._clockProps.utcSelector.getIntValue() == 0) {
                return me._clockProps.utcDate.getValue();
            } else {
                return me._clockProps.intDate.getValue();
            }
        }
        return "88:88:88";
    },
    #setDisplay: func() {
    setChronoDisp: func() {
        if (me._clockProps.annun.getBoolValue()) {
            var chrono = "88:88";
        } else {
            # chrono is exactly 100:00 for one frame then other logic fixes
            # /me thinks this should roll to hh:mm at this point
            if ( me._chronoProps.chrStarted.getBoolValue()) {
                var chrono = me._chronoProps.chrEt.getValue();
                if ( utf8.size(chrono) > 5 ) {
                    chrono = "88:88";
                }
            } else {
                var chrono = "     ";
            }
        }
        me._agpProps.chrono.setValue(chrono);
    },
    setElapsedDisp: func() {
        if (me._clockProps.annun.getBoolValue()) {
            var elapsed = "88:88";
        } else {
            var elapsed = (me._elapsedProps.elapsed.getValue() or "     ");
            if ( utf8.size(elapsed) > 5 ) {
                elapsed = "88:88";
            }
        }
        me._agpProps.et.setValue(elapsed);
    },
    setUtcDisp: func() {
        if (me._clockProps.annun.getBoolValue()) {
            var clock = "88:88:88";
        } else {
            var clock = me.clocky();
        }
        me._agpProps.utc.setValue(clock);
    },
    updateDisplay: func() {
        var chrono = me._agpProps.chrono.getValue();
        var clock = me._agpProps.utc.getValue();
        var elapsed = me._agpProps.et.getValue();
        var packet = me.chronoTrigger(chrono,clock,elapsed);
        me._device.sendOutputReport(240,packet);
        var refreshReport = [0x00, 0x01, 0x11, me._dev.dev1, me._dev.dev2, 0x00, 0x00, 0x03, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        me._device.sendOutputReport(240,refreshReport);
    },
    watchAirbusLEDs: func() {
        foreach(var led; keys(me._ledWatchProps)) {
            append(me.listeners,me.leds[led].watch(me._ledWatchProps[led]));
        }
    },
    watchAnnunLEDs: func() {
        foreach(var led; keys(me._ledAnnunProps)) {
            append(me.listeners,me.leds[led].watch(me._ledAnnunProps[led]));
        }
    },
    doAirbus: func() {
        me.watchAirbusLEDs();
    },
    doGeneric: func() {
        me.watchAnnunLEDs();
    },
};
