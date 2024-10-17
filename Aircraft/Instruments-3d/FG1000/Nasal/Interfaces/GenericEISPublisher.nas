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
# EIS Driver using Emesary for a single engined aircraft, e.g. Cessna 172.
var GenericEISPublisher =
{

  new : func (period=0.25) {
    var obj = {
      parents : [
        GenericEISPublisher,
        PeriodicPropertyPublisher.new(notifications.PFDEventNotification.EngineData, period)
      ],
    };

    # Hack to handle most aircraft not having proper engine hours
    if (getprop("/engines/engine[0]/hours") == nil) setprop("/engines/engine[0]/hours", 157.0);

    obj.addPropMap("RPM", "/engines/engine[0]/rpm", 10);
    obj.addPropMap("Man", "/engines/engine[0]/mp-osi", 10);
    obj.addPropMap("MBusVolts", "/systems/electrical/volts", 1);
    obj.addPropMap("EBusVolts", "/systems/electrical/volts", 1);
    obj.addPropMap("MBattAmps", "/systems/electrical/amps", 1);
    obj.addPropMap("SBattAmps", "/systems/electrical/amps", 1);
    obj.addPropMap("EngineHours", "/engines/engine[0]/hours", 1);
    obj.addPropMap("FuelFlowGPH", "/engines/engine[0]/fuel-flow-gph", 0.25);
    obj.addPropMap("OilPressurePSI", "/engines/engine[0]/oil-pressure-psi", 0.1);
    obj.addPropMap("OilTemperatureF", "/engines/engine[0]/oil-temperature-degf", 1);
    obj.addPropMap("EGTNorm", "/engines/engine[0]/egt-norm", 0.5);
    obj.addPropMap("VacuumSuctionInHG", "/systems/vacuum/suction-inhg", 1);

    return obj;
  },

  # Custom publish method as we package the values into an array of engines,
  # in this case, only one!
  publish : func() {
    var engineData0 = {};

    foreach (var propmap; me._propmaps) {
      var name = propmap.getName();
      engineData0[name] = propmap.getValue();
    }

    var engineData = [];
    append(engineData, engineData0);

    var notification = notifications.PFDEventNotification.new(
      "MFD",
      1,
      notifications.PFDEventNotification.EngineData,
      { Id: "EngineData", Value: engineData } );

    me._transmitter.NotifyAll(notification);
  },
};
