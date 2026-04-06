#-------------------------------------------------------------------------------
# SPDX-License-Identifier: GPL-2.0-or-later
#-------------------------------------------------------------------------------
# test_props.nas - Nasal Unit Test for props.Node.nas
# created: 06/2020
# Copyright (C) 2020 by Henning Stahlke
#-------------------------------------------------------------------------------

var setUp = func {
    print("setUp "~caller(0)[2]~" ");
};

var tearDown = func {

};

var test_isValidPropName = func() {
    # test valid names
    unitTest.assert(props.Node.isValidPropName("abc123") == 1, "isValidPropName()");
    unitTest.assert(props.Node.isValidPropName("_abc123") == 1, "isValidPropName()");
    unitTest.assert(props.Node.isValidPropName("_1a") == 1, "isValidPropName()");
    unitTest.assert(props.Node.isValidPropName("_1a.-") == 1, "isValidPropName()");
    # test invalid names
    unitTest.assert(props.Node.isValidPropName("1a") == 0, "isValidPropName()");
    unitTest.assert(props.Node.isValidPropName("abä") == 0, "isValidPropName()");
    unitTest.assert(props.Node.isValidPropName("foo:bar") == 0, "isValidPropName()");
    unitTest.assert(props.Node.isValidPropName("foo<bar") == 0, "isValidPropName()");
    unitTest.assert(props.Node.isValidPropName("") == 0, "isValidPropName()");
}

var test_makeValidPropName = func() {
    # test valid names
    unitTest.assert(props.Node.makeValidPropName("abc123") == "abc123", "makeValidPropName()");
    unitTest.assert(props.Node.makeValidPropName("_abc123") == "_abc123", "makeValidPropName()");
    unitTest.assert(props.Node.makeValidPropName("_1a") == "_1a", "makeValidPropName()");
    unitTest.assert(props.Node.makeValidPropName("_1a.-") == "_1a.-", "makeValidPropName()");
    # test invalid names
    unitTest.assert(props.Node.makeValidPropName("1a") == "_a", "makeValidPropName()");
    unitTest.assert(props.Node.makeValidPropName("foo:bar") == "foo_bar", "makeValidPropName()");
    unitTest.assert(props.Node.makeValidPropName("foo<bar") == "foo_bar", "makeValidPropName()");
    unitTest.assert(props.Node.makeValidPropName("") == nil, "makeValidPropName('')");
    unitTest.assert(props.Node.makeValidPropName("aäb") == "a__b", props.Node.makeValidPropName('aäb'));
}

var test_add = func() {
    myProp = props.Node.new();
    unitTest.assert(myProp.setIntValue(1) == 1);
    # positive tests
    unitTest.assert(myProp.add(1) == 2, "add()");
    unitTest.assert(myProp.add(8) == 10, "add()");
    #clamp to 12
    unitTest.assert(myProp.add(8, 12) == 12, "add()");
    # clamp to 12 with wrap around starting at 0
    unitTest.assert(myProp.add(3, 12, 12) == 3, "add()");
    unitTest.assert(myProp.add(48, 12, 12) == 3, "add()");

    myProp.setValue(136);
    unitTest.assert(myProp.add(2, 137, 20) == 118, "add(2, 137, 20)");

    # test integer prop with float increments - decimals will be cut off, not rounded
    unitTest.assert(myProp.add(0.1) == 118, "add(0.1)");
    unitTest.assert(myProp.add(0.6) == 118, "add(0.6)");
    print(myProp.getValue());

    # test floating point
    myProp.initNode(nil, nil, "DOUBLE", "force");
    myProp.setValue(0);
    unitTest.assert(myProp.add(2.5) == 2.5, "add(2.5)");

    # negative tests (tbd)
}

var test_sub = func() {
    myProp = props.Node.new();
    unitTest.assert(myProp.setIntValue(10) == 1);
    # positive tests
    unitTest.assert(myProp.sub(1) == 9, "sub(1)");
    unitTest.assert(myProp.sub(7) == 2, "sub(7)");
    #clamp to 12
    unitTest.assert(myProp.sub(8, 0) == 0, "sub(8, 0)");
    # clamp to 12 with wrap around starting at 0
    unitTest.assert(myProp.sub(3, 0, 12) == 9, "sub(3, 0, 12)");
    unitTest.assert(myProp.sub(48, 0, 12) == 9, "sub(48, 0, 12)");

    myProp.setValue(118);
    unitTest.assert(myProp.sub(1, 118, 20) == 137, "sub(1, 118, 20)");

    # test integer prop with float increments - decimals will be cut off, not rounded
    unitTest.assert(myProp.sub(0.1) == 136, "sub(0.1)");
    unitTest.assert(myProp.sub(0.6) == 135, "sub(0.6)");
    print(myProp.getValue());

    # test floating point
    myProp.initNode(nil, nil, "DOUBLE", "force");
    myProp.setValue(0);
    unitTest.assert(myProp.sub(2.5) == -2.5, "sub(2.5)");

    # negative tests (tbd)
}