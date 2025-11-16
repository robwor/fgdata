# WARNING: *.model files will be deprecated, see: http://wiki.flightgear.org/MapStructure
var RunwayNDModel = {};
 RunwayNDModel.new = func make( LayerModel, RunwayNDModel );

 RunwayNDModel.init = func {
 me._view.reset();

 # check if RM is active and bail out if not
if (!getprop("/autopilot/route-manager/active")) 
	print("runway-nd.model: Cannot access flight plan, route manager inactive!") and return;

 var desRwy = flightplan().destination_runway;
 var depRwy = flightplan().departure_runway;

 if (depRwy != nil)
	me.push(depRwy);
 if (desRwy != nil)
	me.push(desRwy);

 me.notifyView();
}
