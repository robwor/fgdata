# annunciators.nas
# Created: 10/2024

var system = nil;
# alias for the property rules enabled prop
var rules_enabledN = props.getNode("/instrumentation/annunciators/property-rules-enabled", 1);

# find the annunciators property-rules
foreach (var sys; props.getNode("/sim/systems", 1).getChildren("property-rule")) {
    if (sys.getNode("name").getValue() == "annunciators") {
        system = sys;
        rules_enabledN.alias(sys.getNode("serviceable", 1));
    }
}