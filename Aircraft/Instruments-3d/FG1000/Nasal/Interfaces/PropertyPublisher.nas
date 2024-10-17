# Copyright 2018 Stuart Buchanan
# This file is part of FlightGear.
#
# FlightGear is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# FlightGear is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FlightGear.  If not, see <http://www.gnu.org/licenses/>.
#
# Generic PropertyPublisher classes for the FG1000 MFD using Emesary
# Publishes property values to Emesary for consumption by the MFD
#
#  Two variants:
#  - PeriodicPropertyPublisher which publishes on a periodic basis
#  - TriggeredPropertyPublisher which publishes based on listening to properties
#    but also publishes all properties on a periodic basis to ensure new clients
#    receive property state.
#

var PropMap = {
  new : func(name, property, epsilon)
  {
    var obj = { parents : [ PropMap ] };
    obj._name = name;
    obj._prop = globals.props.getNode(property, 1);
    obj._epsilon = epsilon;
    obj._lastValue = nil;
    return obj;
  },

  getName : func() { return me._name; },
  getPropPath : func() { return me._prop.getPath(); },
  getValue : func() {
    var val = me._prop.getValue();
    if (val == nil) val = 0;
    return val;
  },
  hasChanged : func() {
    var val = me._prop.getValue();
    if (me._epsilon == nil) return 1;
    if ((me._lastValue == nil) and (val != nil)) return 1;
    if (! isnum(val) and val != me._lastValue) return 1;
    if (isnum(val) and abs(val - me._lastValue) > me._epsilon) return 1;
    return 0;
  }, 
  updateValue : func() { me._lastValue = me.getValue(); },
  getProp: func() { return me._prop; },
};

var PeriodicPropertyPublisher =
{
  new : func (notification, period=0.25) {
    var obj = {
      parents : [ PeriodicPropertyPublisher ],
      _notification : notification,
      _period : period,
      _propmaps : [],
    };

    obj._transmitter = emesary.GlobalTransmitter;

    return obj;
  },

  addPropMap : func(name, prop, epsilon=nil) {
    append(me._propmaps, PropMap.new(name, prop, epsilon));
  },

  publish : func() {
    var data = {};
    var names = "";

    foreach (var propmap; me._propmaps) {
      var name = propmap.getName();
      if (propmap.hasChanged()) {
        data[name] = propmap.getValue();
        propmap.updateValue();
        names = sprintf("%s %s", names, name);
      }
    }

    if (size(data) > 0) {
      var notification = notifications.PFDEventNotification.new(
        "MFD",
        1,
        me._notification,
        data);

      me._transmitter.NotifyAll(notification);
      #print(sprintf("NOTIFY total of %i properties changed out of %i: %s", size(data), size(me._propmaps), names));
    }
  },

  start : func() {
    me._timer = maketimer(me._period, me, me.publish);
    me._timer.start();
  },
  stop : func() {
    if(me._timer != nil) me._timer.stop();
    me._timer = nil;
  },
};

var TriggeredPropertyPublisher =
{
  new : func (notification, period=5) {
    var obj = {
      parents : [ TriggeredPropertyPublisher ],
      _notification : notification,
      _period : period,
      _propmaps : {},
      _listeners : [],
      _timer: nil,
    };

    obj._transmitter = emesary.GlobalTransmitter;

    return obj;
  },

  addPropMap : func(name, prop, epsilon=nil) {
    me._propmaps[prop] = PropMap.new(name, prop, epsilon);
  },

  publish : func(propNode) {
    var data = {};
    var propmap = me._propmaps[propNode.getPath()];
    assert(propmap != nil, "Unable to find property map for " ~ propNode.getPath());
    if (propmap.hasChanged()) {
      data[propmap._name] = propNode.getValue();
      propmap.updateValue();

      var notification = notifications.PFDEventNotification.new(
        "MFD",
        1,
        me._notification,
        data);

      me._transmitter.NotifyAll(notification);
    }
  },

  publishAll : func() {
    var data = {};

    foreach (var prop; keys(me._propmaps)) {
      var propmap = me._propmaps[prop];
      data[propmap._name] = propmap.getValue();
      propmap.updateValue();
    }

    var notification = notifications.PFDEventNotification.new(
      "MFD",
      1,
      me._notification,
      data);

    me._transmitter.NotifyAll(notification);
  },


  start : func() {
    foreach (var prop; keys(me._propmaps)) {
      # Set up a listener triggering on create (to ensure all values are set at
      # start of day) and only on changed values.  These are the last two
      # arguments to the setlistener call.
      var propmap = me._propmaps[prop];
      var listener = setlistener(propmap.getPropPath(), func(p) { me.publish(p); }, 1, 1);
      append(me._listeners, listener);
    }

    me._timer = maketimer(me._period, me, me.publishAll);
    me._timer.start();
  },

  stop : func() {
    foreach (var l; me._listeners) {
      # In some circumstances we may not have a valid listener ID, so we
      # just ignore the problem.
      var err = [];
      call( func removelistener(l), nil, err);
      if (size(err)) print("Ignoring error : " ~ err[0]);
    }

    if(me._timer != nil) me._timer.stop();
    me._timer = nil;
  },
};
