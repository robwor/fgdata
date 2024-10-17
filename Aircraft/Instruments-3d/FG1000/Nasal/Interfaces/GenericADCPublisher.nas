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
# Air Data Computer Driver using Emesary to publish data such as
#
# Airspeed
# Orientation
# Rate of turn
# Heading
# Air Temperature
#
#
#  For the moment these are just taken directly from the raw properties.  They
# should probably come from aircraft-specific instrumentation.

var GenericADCPublisher =
{
  new : func () {

    # Update frequency can be controlled by a property.
    var frequency = getprop("/instrumentation/FG1000/adc-update-frequency");
    if (frequency == nil) frequency = 10;

    var obj = {
      parents : [
        GenericADCPublisher,
        PeriodicPropertyPublisher.new(notifications.PFDEventNotification.ADCData, 1.0/frequency)
      ],
    };

    # Air data comes from the airspeed indicator as for a non-glass panel aircraft.
    obj.addPropMap("ADCTrueAirspeed", "/instrumentation/airspeed-indicator/true-speed-kt", 1);
    obj.addPropMap("ADCIndicatedAirspeed", "/instrumentation/airspeed-indicator/indicated-speed-kt", 0.2);

    # Assume an accurate solid-state magnetometer
    obj.addPropMap("ADCPitchDeg", "/orientation/pitch-deg", 0.2);
    obj.addPropMap("ADCRollDeg",  "/orientation/roll-deg", 0.2);

    # TODO: Replace these with real values - shouldn't rely on steam-powered gauges.
    obj.addPropMap("ADCTurnRate", "/instrumentation/turn-indicator/indicated-turn-rate", 1);
    obj.addPropMap("ADCSlipSkid", "/instrumentation/slip-skid-ball/indicated-slip-skid", 0.1);

    # Assume an accurate solid-state magnetometer
    obj.addPropMap("ADCHeadingMagneticDeg", "/orientation/heading-magnetic-deg", 1);
    obj.addPropMap("ADCMagneticVariationDeg", "/environment/magnetic-variation-deg", 0.1);

    obj.addPropMap("ADCAltitudeFT", "/instrumentation/altimeter/indicated-altitude-ft", 1);
    obj.addPropMap("ADCPressureSettingInHG", "/instrumentation/altimeter/setting-inhg", 0.0);

    obj.addPropMap("ADCVerticalSpeedFPM", "/instrumentation/vertical-speed-indicator/indicated-speed-fpm", 10);

    obj.addPropMap("ADCOutsideAirTemperatureC", "/environment/temperature-degc", 1);
    obj.addPropMap("ADCWindHeadingDeg", "/environment/wind-from-heading-deg", 1);
    obj.addPropMap("ADCWindSpeedKt", "/environment/wind-speed-kt", 1);
    obj.addPropMap("ADCTimeLocalSec", "/sim/time/local-day-seconds", 1);
    obj.addPropMap("ADCTimeUTCSec", "/sim/time/utc/day-seconds", 1);
    return obj;
  },
};
