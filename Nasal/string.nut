#-------------------------------------------------------------------------------
# SPDX-License-Identifier: GPL-2.0-or-later
#-------------------------------------------------------------------------------
# string.nut - Nasal Unit Test for string.nas
# author:  Henning Stahlke
# created: 01/2026
#-------------------------------------------------------------------------------

var setUp = func {
};

var tearDown = func {
};

var test_string_squeeze = func {
    var s = "";
    for (var i = 1; i < 15; i += 1) {
        s ~= chr(64 + i);
        unitTest.assert(size(s) == i, "string.nut is broken");

        # string should be unchanged for max < 7 (see implementation)
        for (var max = 1; max < 7; max += 1) {
            unitTest.assert(string.squeeze(s, max) == s, "squeeze("~s~", "~max~")");
        }

        # check result has correct length
        for (; max < i; max += 1) {
            #print(size(s), " squeeze("~s~", "~max~") =", string.squeeze(s, max));
            unitTest.assert(size(string.squeeze(s, max)) == max, "squeeze("~s~", "~max~")");
        }

        #test that string is not changed if lenght == max
        max = i;
        unitTest.assert(string.squeeze(s, max) == s, "squeeze("~s~", "~max~")");
    }
}
