# Interface class for full screen canvas HUDs.
var HUDInterface = {

new : func() {
    var obj = {
        parents : [HUDInterface],
        root: nil,
    };

    # Locate the HUD
    var xsize = getprop("/sim/startup/xsize");
    var ysize = getprop("/sim/startup/ysize");

    var desktop = canvas.getDesktop();
    var hudGroup = desktop.getElementById("HudGroup");

    if (hudGroup == nil) {
        hudGroup = desktop.createChild("group", "HudGroup");
    } 

    hudGroup.removeAllChildren();

    # The nested Groups is to work around an issue where setTranslation is
    # additive to any existing translation on the Group.  So we simply delete
    # the group and recreate it.
    var hudRoot = hudGroup.createChild("group", "HUDRoot");
    hudRoot.setTranslation(xsize * 0.5, ysize * 0.5);
    obj.root = hudRoot;

    return obj;
},

del: func()
{
    # To be implemented by implementation classes.  Clean up an timers and delete HUD (e.g me.root.removeAllChildren())
},

set_visibility : func(visible)
{
    me.root.setVisible(visible);
},

get_visible : func() 
{ 
    return me.root.getVisible(); 
},

cycle_color : func()
{
    # To be implemented by implementation classes.  Cycle through HUD color options (if any).
},

cycle_brightness : func()
{
    # To be implemented by implementation classes.  Cycle through HUD brightness options (if any).
},

# Below are helper functions for creating HUD elements in canvas

# add a single radially aligned tick mark between radiui one and two
addPolarTick : func(path, angle, r1, r2)
{
    var horAngle = angle + 90; # angle from +ve X axis
    var sa = math.sin(horAngle * D2R);
    var ca = math.cos(horAngle * D2R);

    path.moveTo(ca * r1, sa * r1);
    path.lineTo(ca * r2, sa * r2);
    return path;
},

addHorizontalSymmetricPolarTick : func(path, angle, r1, r2)
{
    var horAngle = angle + 90; # angle from +ve X axis
    var sa = -math.sin(horAngle * D2R);
    var ca = math.cos(horAngle * D2R);

    path.moveTo(ca * r1, sa * r1);
    path.lineTo(ca * r2, sa * r2);
    path.moveTo(-ca * r1, sa * r1);
    path.lineTo(-ca * r2, sa * r2);
    return path;
},

addHorizontalSymmetricLine : func(path, positiveLength, y)
{
    path.moveTo(-positiveLength, y);
    path.lineTo(positiveLength, y);
    return path;
},

addVerticalSymmetricLine : func(path, positiveLength, x)
{
    path.moveTo(x, -positiveLength);
    path.lineTo(x, positiveLength);
    return path;
},


addDiamond : func(path, radius)
{
    path.move(-radius, 0);
    path.line(radius, -radius); # top
    path.line(radius, radius); # right
    path.line(-radius, radius); # bottom
    path.close();
},

# Convenience function to set the clip frame of an element
setClip : func(element, top, right, bottom, left) 
{
    element.set("clip", "rect(" ~ top ~ ", " ~ right ~ " ," ~ bottom ~ ", " ~ left ~ ")");
},

};
