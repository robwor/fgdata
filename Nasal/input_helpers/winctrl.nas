# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 Kent Stevens (timeplt)
#
# Helpers for WINCTRL input devices

var family_patterns = [
    ["A320*","A320"],
    ["*707*","B707"],
    ["*757-*","B757"],
    ["*777-*","B777"],
    ["c172*","C172"],
    ["*pa28*","PA28"],
    ["*PA28*","PA28"],
    ["*MD-11*","MD11"],
];

var check_family = func() {
    var type = getprop('/sim/variant-of');
    var subtype = getprop('/sim/aircraft');
    var family = nil;
    foreach (var pattern; family_patterns) {
        if (string.match(subtype,pattern[0])) {
            family = pattern[1];
            break;
        }
    }
    return family;
};
var winctrl = {
    new: func(name, cmdarg, dev = nil) {
        if (contains(['agp32','mcdu32','joyl32','fcu32','throttle32','ecam32','tcas32'], name)) {
        # check if the winctrl namespace already contains the helper
            if (!contains(winctrl, name))
                io.include("winctrl/"~name~".nas");
                #io.load_nasal("winctrl/"~name~".nas","input_helpers.winctrl");
            return winctrl[name].new(cmdarg,dev);
        }
    },
};

var ledReport = [0x00, 0x00, 0x00, 0x00, 0x03, 0x49, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
var makeLittleEndian = func(val) {
};

var lshift = func(nummer) {
    return math.pow(2,nummer);
};
var rshift = func(left,right) {
    return math.floor(left/math.pow(2,right));
};
var padStr = func(item,len,padder=" ") {
    if (utf8.size(padder)<1) {
        padder = ' ';
    }
    while ( utf8.size(item) < len ) {
        item = item ~ padder;
    }
    return item;
};

# FCU helpers
var representations = [0xfa, 0x60, 0xd6, 0xf4, 0x6c, 0xbc, 0xbe, 0xe0, 0xfe, 0xfc, 0x04];
var fcuReps = {
    '0' : 0xfa,
    '1' : 0x60,
    '2' : 0xd6,
    '3' : 0xf4,
    '4' : 0x6c,
    '5' : 0xbc,
    '6' : 0xbe,
    '7' : 0xe0,
    '8' : 0xfe,
    '9' : 0xfc,
    'A' : 0xee,
    'B' : 0xfe,
    'C' : 0x9a,
    'D' : 0x76,
    'E' : 0x9e,
    'F' : 0x8e,
    'G' : 0xbe,
    'H' : 0x6e,
    'I' : 0x60,
    'J' : 0x70,
    'K' : 0x0e,
    'L' : 0x1a,
    'M' : 0xa6,
    'N' : 0x26,
    'O' : 0xfa,
    'P' : 0xce,
    'Q' : 0xec,
    'R' : 0x06,
    'S' : 0xbc,
    'T' : 0x1e,
    'U' : 0x7a,
    'V' : 0x32,
    'W' : 0x58,
    'X' : 0x6e,
    'Y' : 0x7c,
    'Z' : 0xd6,
    '-' : 0x04,
    '#' : 0x36,
    '/' : 0x60,
    "\\" : 0xa0, # \ untested!
    ' ' : 0x00,
    '.' : 0x10,
};

var lcdReps = {
    '0' : 0x3f,
    '1' : 0x06,
    '2' : 0x5b,
    '3' : 0x4f,
    '4' : 0x66,
    '5' : 0x6d,
    '6' : 0x7d,
    '7' : 0x07,
    '8' : 0x7f,
    '9' : 0x6f,
    'A' : 0x77,
    'B' : 0x7c,
    'C' : 0x39,
    'D' : 0x5e,
    'E' : 0x79,
    'F' : 0x71,
    'G' : 0x3d,
    'H' : 0x76,
    'I' : 0x30,
    'J' : 0x1e,
    'K' : 0x76,
    'L' : 0x38,
    'M' : 0x54,
    'N' : 0x54,
    'O' : 0x3f,
    'P' : 0x73,
    'Q' : 0x67,
    'R' : 0x50,
    'S' : 0x6d,
    'T' : 0x78,
    'U' : 0x3e,
    'V' : 0x1d,
    'W' : 0x2a,
    'X' : 0x76,
    'Y' : 0x6e,
    'Z' : 0x5b,
    '-' : 0x40,
    '_' : 0x08,
    #'#' : 0x,
    #'/' : 0x,
    #'\\' : 0x,
    ' ' : 0x00,
};

var dataFromString = func(num7segments, stringy) {
    var ret = [];
    var comma = false;
    var sign = '';
    var bytes = split("", string.uc(stringy));
    foreach( item; bytes) {
        if (item == ".") {
            comma = true;
        } else if (item == "+") {
            sign = '+';
        } else if (item == "-" and size(stringy) > num7segments) {
            sign = '-';
        } else {
            if (contains(keys(fcuReps),item)) {
                append(ret,fcuReps[item]);
            } else {
                append(ret,0x00);
            }
            if (comma and num7segments == 3) {
                ret[size(ret)-1] += 0x01;
                comma = false;
            }
        }
        if (size(ret) == num7segments) {
            break;
        }
    }
    while (size(ret) < num7segments) {
        append(ret,0x00);
    }
    return [ret,comma,sign];
};

var swapNibbles = func(val) {
    return ((val & 0x0F) * 16 + (val & 0xF0) / 16);
};

var dataFromStringSwapped = func(num7segments, stringy) {
    var treble = dataFromString(num7segments, stringy);
    var ret = treble[0];
    var comma = treble[1];
    var sign = treble[2];
    append(ret, 0x00);
    for (var i = 0; i <= num7segments; i += 1) {
        ret[i] = swapNibbles(ret[i]);
    }
    for (var i = num7segments; i > 0; i -= 1) {
        ret[i] = (ret[i] & 0xf0) + (ret[i - 1] & 0x0f);
        ret[i - 1] = ret[i - 1] & 0xf0;
    }
    return [ret,comma,sign];
};

var leddy = {
    # LED functions class
    # name
    # property tree device
    # listener watch device
    # update method
    name: "",
    devs: [], # device addresses
    addr: 0x00, # led address
    prop: nil, # property assignment
    #watch: nil, # watch assignment

    watch: func(watchProp) {
        # watches and updates from some other property
        # expecting double range 0-1
        return setlistener(watchProp, func(node) { me.set(node.getValue()*255); },1,0);
    },
    set: func(value) {
        # set the prop
        me.prop.setIntValue(value);
    },
    update: func() {
        # update the display
        var report = ledReport;
        report[0] = me.devs[0];
        report[1] = me.devs[1];
        report[6] = me.addr;
        report[7] = me.prop.getIntValue();
        return report;
    },
    autoReport: func(device) {
        # watch the led property and fire the update report
        return setlistener(me.prop, func(node) { device.sendOutputReport(2,me.update()); },1,0);
    },
    new: func(name,devs,addr,prop) {
        var l = {parents:[leddy]};
        l.name = name;
        l.devs = devs;
        l.addr = addr;
        l.prop = props.globals.getNode(prop,1);
        l.set(0);
        return l;
    },
    close: func(device) {
        me.set(0);
        device.sendOutputReport(2,me.update());
    },
};
