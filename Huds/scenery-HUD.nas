# HUD intended for scenery developers.

var nasal_dir = getprop("/sim/fg-root") ~ "/Huds/";
io.load_nasal(nasal_dir ~ 'PhysicalController.nas', "hud");
io.load_nasal(nasal_dir ~ 'HUDInterface.nas', "hud");

# main wrapper object
var HUD = {

boxHeight: 48,
fontBold: "LiberationFonts/LiberationMono-Bold.ttf",
fontRegular: "LiberationFonts/LiberationMono-Regular.ttf",
fontSizeSmall: 24,
fontSizeMedium: 36,
fontSizeLarge: 44,

new : func(controller = nil) {
    var obj = {
        parents : [HUD, HUDInterface.new()],
        _mode : ''
    };

    # Define the key dimensions of the HUD based on the screen size.
    HUD.xsize = getprop("/sim/startup/xsize");
    HUD.ysize = getprop("/sim/startup/ysize");

    HUD.halfSize = math.min(HUD.xsize, HUD.ysize) * 0.5;
    HUD.speedTapeWidth = HUD.halfSize * 0.15;
    HUD.altTapeWidth = HUD.halfSize * 0.15;

    HUD.hsiLeft = HUD.speedTapeWidth - HUD.halfSize;
    HUD.hsiRight = HUD.halfSize - HUD.altTapeWidth;

    HUD.elevationBoxPos = HUD.halfSize + 100;
  
    var controllerClass = (controller == nil) ? PhysicalController : controller; 
    obj._controller = controllerClass.new(obj);
    obj.createContents();

    obj._updateTimer = maketimer(0.05, func obj.update(); );
    obj._updateTimer.start();
    
    return obj;
},

createContents : func() 
{
    me.createAltitudeTape();
    me.createSpeedBox();
    me.createAltitudeBox();
    me.createCompassTape();
    me.createLatLonElevationBoxes();
},

del: func()
{
    me._updateTimer.stop();
    me.root.removeAllChildren();
},

createDigitTape : func(parent, name, suffix = nil)
{
    var t = parent.createChild('text', name);
    # 'top' zero (above 9)
    var s = '0' ~ chr(10);
    if (suffix != nil) {
        s = '0' ~ suffix ~ chr(10);
    }

    for (var i=9; i>=0; i-=1) {
        if (suffix != nil) {
            s = s ~ i ~ suffix ~ chr(10);
        } else {
            s = s ~ i ~ chr(10);
        }
    }
    t.setText(s);
    t.setFont(HUD.fontRegular);
    t.setFontSize(HUD.fontSizeLarge);
    # t.set('line-height', 0.9);
    t.setAlignment("left-bottom");
    return t;
},

createCompassTape : func()
{
    # Determine the total screen width based on FOV.
    # Note that we are scaled from a base size, and the HUD is scaled to 75% of the width or height of screen
    var hud_fov = getprop("/sim/current-view/field-of-view") * 0.75;

    # We will make marks every 5 degrees and label every 10 degrees.  So ensure that 5 degrees is an integer number
    # of pixels.
    me._pxPer5Degrees = math.round(HUD.xsize / hud_fov * 5);
    me._pxPerDegree = me._pxPer5Degrees / 5.0;

    # So that it wraps, we will create a tape of 720 degrees and use the middle 360.  That should allow everying to a 180+ degree 
    # FoV
    me._compassGroup = me.root.createChild("group", "compass-group");
    me._compassGroup.setTranslation(0, -HUD.halfSize + 150);
    me._compassGroup.set("background", [0.0,0.0,0.0,0.0]);
    me._compassGroup.set("clip-frame", canvas.Element.PARENT);
    me._compassGroup.set("clip", "rect(-" ~ HUD.halfSize ~ ", " ~ HUD.halfSize ~ ", " ~ HUD.halfSize ~ ", -" ~ HUD.halfSize ~ ")");
    me._compassGroup.set('z-index', 2);

    me._compassTapeGroup = me._compassGroup.createChild("group", "compass-tape-group");

	var tapePath = me._compassTapeGroup.createChild("path", "compass-tape");
    tapePath.setStrokeLineWidth(2);
    tapePath.setColor(1, 1, 1);

    for (var s = -360; s < 720; s = s + 5) {
        var x = s * me._pxPerDegree;
        if (math.mod(s, 10) == 0) {
            tapePath.moveTo(x, 0).line(0, 25);

            #Include numbering
            var text = me._compassTapeGroup.createChild("text", "compass-tape-legend-" ~ s);
            text.setText(math.mod(s, 360));
            text.setFontSize(HUD.fontSizeSmall);
            text.setAlignment("center-top");
            text.setFont(HUD.fontRegular);
            text.setTranslation(x, 32);
        } else {
            tapePath.moveTo(x, 0).line(0, 50);
        }
    }

    # add path for the heading arrow
    var arrow = me.root.createChild("path", "compass-arrow");
    arrow.setTranslation(0, -HUD.halfSize + 130);
    arrow.setStrokeLineWidth(2);
    arrow.setColor(1, 1, 1);

    # same size as the roll arrow
    var arrowHeight = 20;
    var arrowHWidth = arrowHeight * (2/3);

    arrow.moveTo(0, arrowHeight);
    arrow.line(arrowHWidth, -arrowHeight);
    arrow.line(-arrowHWidth * 2, 0);
    arrow.close();
    arrow.set('z-index', 4);

    # Add text box for heading
    me._compassHeading = me._compassGroup.createChild("text", "compass-heading");
    me._compassHeading.setTranslation(0,-30);
    me._compassHeading.setText('888');
    me._compassHeading.setFontSize(HUD.fontSizeLarge);
    me._compassHeading.setAlignment("center-bottom");
    me._compassHeading.setFont(HUD.fontRegular);
},

updateCompassTape : func()
{
    var hdg = me._controller.getHeadingDeg();
    var shift = - (me._pxPerDegree * hdg);
    me._compassTapeGroup.setTranslation( shift, 0);

    var s = sprintf("%03i", math.round(hdg));
    me._compassHeading.setText(s);
},

createAltitudeTape : func()
{
    # tick every 50' interval
    # text, monospace, 5 digits, ever 100'

    me._altTapeGroup = me.root.createChild("group", "altitude-tape-group");
    me._altTapeGroup.setTranslation(HUD.hsiRight, 0);
    me._altTapeGroup.set("background", [0.0,0.0,0.0,0.0]);
    me._altTapeGroup.set("clip-frame", canvas.Element.LOCAL);
    me._altTapeGroup.set("clip", "rect(-" ~ (HUD.halfSize - 200) ~ ", " ~ HUD.halfSize ~ ", " ~ (HUD.halfSize - 200) ~ ", -" ~ HUD.halfSize ~ ")");
    me._altTapeGroup.set('z-index', 2);

	var tapePath = me._altTapeGroup.createChild("path", "altitude-tape");
    tapePath.setStrokeLineWidth(2);
    tapePath.setColor(1, 1, 1);
    
    var hundredFtSpacing = 64;
    var twoHundredFtSpacing = hundredFtSpacing * 2;
    var twoHundredFtWidth = 20;

    # empty array to hold altitude tape texts for easy updating
    me._altitudeTapeTexts = [];

    for (var i=0; i<=12; i+=1)
    {
        var y = (i - 6) * twoHundredFtSpacing;
        var tickY = y + hundredFtSpacing;

        tapePath.moveTo(0, -tickY).line(twoHundredFtWidth, 0);

        var text = me._altTapeGroup.createChild("text", "altitude-tape-legend-" ~ i);
        text.setText(text);
        text.setFontSize(HUD.fontSizeMedium);
        text.setAlignment("left-center");
        text.setFont(HUD.fontRegular);
        text.setTranslation(2, -y);
        
        # we will update the text very often, ensure we only do
        # real work if it actually changes
        text.enableUpdate();

    # save for later updating
        append(me._altitudeTapeTexts, text);
    } 
},

updateAltitudeTape : func()
{
    var altFt = me._controller.getAltitudeFt();
    var alt200 = int(altFt/200);
    var altMod200 = altFt - (alt200 * 200);

    var offset = 128 * (altMod200 / 200.0);
    me._altTapeGroup.setTranslation(HUD.hsiRight, offset);

    # compute this as current alt - half altitude range
    var lowestAlt = (alt200 - 6) * 200;

    for (var i=0; i<=12; i+=1)
    {
        var alt = lowestAlt + (i * 200);
        # printf with 5 digits
        var s = sprintf("%05i", alt);
        me._altitudeTapeTexts[i].updateText(s);
    }

    # compute transform on group to put the actual altitude on centre
},

createAltitudeBox : func()
{
    var halfBoxHeight = HUD.boxHeight / 2;
    var box = me.root.rect(HUD.hsiRight, -halfBoxHeight, 
                          HUD.altTapeWidth + 20, HUD.boxHeight);
    box.setColorFill('#000000'); 
    box.setColor('#ffffff');
    box.setStrokeLineWidth(2);
    box.set('z-index', 2);

    var clipGroup = me.root.createChild('group', 'altitude-box-clip');
    clipGroup.set("clip-frame", canvas.Element.LOCAL);
    clipGroup.set("clip", "rect(-24px," ~ (HUD.altTapeWidth + 20) ~ "px, 24px, 0px)");
    clipGroup.setTranslation(HUD.hsiRight, 0);
    clipGroup.set('z-index', 3);

    var text = clipGroup.createChild('text', 'altitude-box-text');
    me._altitudeBoxText = text;

    text.setText('888 ');
    text.setFontSize(HUD.fontSizeLarge);
    text.setAlignment("left-center");
    text.setFont(HUD.fontRegular);

    me._altitudeDigits00 = me.createDigitTape(clipGroup, 'altitude-digits00', '0');
    me._altitudeDigits00.setFontSize(32);
    me._altitudeDigits00.set('z-index', 4);
},

createSpeedBox : func()
{
    var halfBoxHeight = HUD.boxHeight / 2;
    var box = me.root.rect(-HUD.halfSize - 2, -halfBoxHeight, 
                           HUD.speedTapeWidth + 4, HUD.boxHeight);
    box.setColorFill('#000000'); 
    box.setColor('#ffffff');
    box.setStrokeLineWidth(2);
    box.set('z-index', 2);

    var clipGroup = me.root.createChild('group', 'speed-box-clip');
    clipGroup.set("clip-frame", canvas.Element.LOCAL);
    clipGroup.set("clip", "rect(-24px," ~ (HUD.speedTapeWidth + 4) ~ "px, 24px, 0px)");
    clipGroup.setTranslation(-HUD.halfSize, 0);
    clipGroup.set('z-index', 3);

    var text = clipGroup.createChild('text', 'speed-box-text');
    me._speedBoxText = text;

    text.setText('88888');
    text.setFontSize(32);
    text.setAlignment("left-center");
    text.setFont(HUD.fontRegular);
},

createLatLonElevationBoxes : func()
{
    var halfBoxHeight = HUD.boxHeight / 2;
    me._latLonGroup = me.root.createChild('group', 'lat-lon-group');
    me._latLonGroup.setTranslation(0, HUD.halfSize - 150);

    me._latText = me._latLonGroup.createChild('text', 'lat-text');
    me._latText.setTranslation(HUD.hsiLeft, 0);
    me._latText.setText('90.000000');
    me._latText.setFontSize(HUD.fontSizeLarge);
    me._latText.setAlignment("left-center");
    me._latText.setFont(HUD.fontRegular);

    me._lonText = me._latLonGroup.createChild('text', 'lat-text');
    me._lonText.setTranslation(HUD.hsiRight, 0);
    me._lonText.setText('90.000000');
    me._lonText.setFontSize(HUD.fontSizeLarge);
    me._lonText.setAlignment("right-center");
    me._lonText.setFont(HUD.fontRegular);

    me._tilePathText = me._latLonGroup.createChild('text', 'tile-path-text');
    me._tilePathText.setTranslation(0, 50);
    me._tilePathText.setText('w010n00/w001n00/987654.stg');
    me._tilePathText.setFontSize(HUD.fontSizeSmall);
    me._tilePathText.setAlignment("center-center");
    me._tilePathText.setFont(HUD.fontRegular);

    me._groundElevationText = me._latLonGroup.createChild('text', 'ground-elevation-text');
    me._groundElevationText.setTranslation(0, 20);
    me._groundElevationText.setText('Ground elevation: ');
    me._groundElevationText.setFontSize(HUD.fontSizeSmall);
    me._groundElevationText.setAlignment("center-center");
    me._groundElevationText.setFont(HUD.fontRegular);

},

update : func()
{
    me._controller.update();

# heading

    me.updateCompassTape();
    me.updateAltitudeTape();

# speed box
    var spd = me._controller.getIndicatedAirspeedKnots();
    var s = sprintf("%05i", math.round(spd));
    me._speedBoxText.setText(s);

# altitude box
    var alt = me._controller.getAltitudeFt();
    var altDigits00 = math.mod(alt / 10, 10);
    me._altitudeDigits00.setTranslation(80, 16 + altDigits00 * 32);
    var s = sprintf("%03i ", math.floor(alt / 100));
    me._altitudeBoxText.setText(s);


# Lat/Lon and tile.
    me._latText.setText(getprop("/position/latitude-string"));
    me._lonText.setText(getprop("/position/longitude-string"));
    me._tilePathText.setText(geo.tile_path(getprop("/position/latitude-deg"), getprop("/position/longitude-deg")));
    var s = sprintf("Ground elevation: %05.1f ft", getprop("/position/ground-elev-ft"));
    me._groundElevationText.setText(s);
}  

};
