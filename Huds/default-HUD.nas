

var nasal_dir = getprop("/sim/fg-root") ~ "/Huds/";
io.load_nasal(nasal_dir ~ 'PhysicalController.nas', "hud");
io.load_nasal(nasal_dir ~ 'HUDInterface.nas', "hud");

# main wrapper object
var HUD = {

pitchLadderDegreeSpacing: 8,
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

    var xsize = getprop("/sim/startup/xsize");
    var ysize = getprop("/sim/startup/ysize");
    HUD.halfSize = math.min(xsize, ysize) * 0.5;
    HUD.hsiWidth = HUD.halfSize;
    HUD.hsiHeight = HUD.halfSize;
    HUD.speedTapeWidth = HUD.halfSize*0.17;
    HUD.altTapeWidth = HUD.halfSize*0.17;
    HUD.roseRadius = math.min(xsize, ysize);
    HUD.rollBaseRadius = HUD.hsiWidth -120;

    HUD.hsiLeft = HUD.speedTapeWidth - HUD.halfSize;
    HUD.hsiXCenter = HUD.hsiLeft + HUD.hsiWidth/2;
    HUD.hsiRight = HUD.halfSize - HUD.altTapeWidth;
    HUD.hsiBottom = HUD.hsiHeight/2;
    HUD.hsiTop = - HUD.hsiHeight/2;

    HUD.elevatorIndicatorHeight = HUD.hsiHeight;
    HUD.elevatorIndicatorPos = HUD.hsiLeft - HUD.speedTapeWidth - 50;

    HUD.rudderIndicatorWidth = HUD.hsiWidth;
    HUD.rudderIndicatorPos = ysize * 0.5 - 100;

    HUD.aileronIndicatorWidth = HUD.hsiWidth;
    HUD.aileronIndicatorPos = - ysize * 0.5 + 50;

    var controllerClass = (controller == nil) ? PhysicalController : controller; 
    obj._controller = controllerClass.new(obj);
    obj.createContents();

    obj._updateTimer = maketimer(0.05, func obj.update(); );
    obj._updateTimer.start();
    
    return obj;
},

createContents : func() 
{
    me.createPitchLadder();
    me.createRollTicks();
    me.createCompassRose();
    me.createAltitudeTape();
    me.createSpeedTape();

    me.createSpeedBox();
    me.createAltitudeBox();

    me.createAirplaneMarker();

    me.createElevatorIndicator();
    me.createRudderIndicator();
    me.createAileronIndicator();
   
},

del: func()
{
    me._updateTimer.stop();
    me.root.removeAllChildren();
},


createAirplaneMarker : func()
{
    var markerGroup = me.root.createChild("group", "airplane-indicator-group");
    #markerGroup.setTranslation(HUD.hsiXCenter, 0);

	var m = markerGroup.createChild("path", "airplane-indicator");
    m.setColorFill(1.0, 0.0, 0.0, 0.0);

    m.setStrokeLineWidth(1);
    m.setColor(1, 1, 1);
    

    var markerWidth = 8;
    var hw = markerWidth / 2;
    var horWidth = 80;
    var vertExtension = markerWidth * 1.5;

    m.moveTo(-hw, -hw);
    m.line(markerWidth, 0);
    m.line(0, markerWidth);
    m.line(-markerWidth, 0);
    m.close();

    # left L
    m.moveTo(-hw - markerWidth, -hw);
    m.line(-horWidth, 0);
    m.line(0, markerWidth);
    m.line(horWidth - markerWidth, 0);
    m.line(0, vertExtension);
    m.line(markerWidth, 0);
    m.close();


    # right L
    m.moveTo(hw + markerWidth, -hw);
    m.line(horWidth, 0);
    m.line(0, markerWidth);
    m.line(markerWidth - horWidth, 0);
    m.line(0, vertExtension);
    m.line(-markerWidth, 0);
    m.close();
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

createRollTicks : func()
{
    # these don't move!
    # center filled white arrow pointing down
    # large tick at 30 deg
    # minor tick at 10, 20 deg
    # minor tick at 45?

    me._rollGroup = me.root.createChild("group", "roll-group");
    me._rollGroup.set("clip-frame", canvas.Element.PARENT);
    me.setClip(me._rollGroup, -HUD.halfSize, HUD.hsiRight, HUD.hsiTop, HUD.hsiLeft);

	var rollScale = me.root.createChild("path", "roll-scale");

    rollScale.setStrokeLineWidth(2);
    rollScale.setColor(1, 1, 1);
    var baseR = HUD.rollBaseRadius;
    var minorTick = 16;
    var majorTick = 30;

    me.addHorizontalSymmetricPolarTick(rollScale, 10, baseR, baseR + minorTick);
    me.addHorizontalSymmetricPolarTick(rollScale, 20, baseR, baseR + minorTick);
    me.addHorizontalSymmetricPolarTick(rollScale, 30, baseR, baseR + majorTick);
    me.addHorizontalSymmetricPolarTick(rollScale, 45, baseR, baseR + minorTick);

    rollScale.close();

    # add filled path for the zero arrow
    rollZeroArrow = me.root.createChild("path", "roll-zero-mark");
    rollZeroArrow.setColorFill(1, 1, 1);
    
    # arrow extends from the roll radius to the top of HSI
    var arrowHeight = 20;
    var arrowHWidth = arrowHeight * (2/3);

    rollZeroArrow.moveTo(0, -baseR);
    rollZeroArrow.line(arrowHWidth, -arrowHeight);
    rollZeroArrow.line(-arrowHWidth * 2, 0);
    rollZeroArrow.close();

    # and the moving arrow
	var rollMarker = me._rollGroup.createChild("path", "roll-indicator");
    rollMarker.setColorFill(0, 0, 0);    
    rollMarker.setStrokeLineWidth(2);
    rollMarker.setColor(1, 1, 1);
    rollMarker.moveTo(0, -baseR);
    rollMarker.line(arrowHWidth, arrowHeight);
    rollMarker.line(-arrowHWidth * 2, 0);
    rollMarker.close();
},

createPitchLadder : func()
{
    me._pitchRotation = me.root.createChild("group", "pitch-rotation");
    me._pitchRotation.set("clip-frame", canvas.Element.PARENT);
    me.setClip(me._pitchRotation, HUD.hsiTop, HUD.hsiRight, HUD.hsiBottom, HUD.hsiLeft);
    me._pitchRotation.set('z-index', 2);

    me.pitchGroup = me._pitchRotation.createChild("group", "pitch-group");
    var ladderGroup = me.pitchGroup.createChild("group", "pitch-ladder");

	var pitchLadder = ladderGroup.createChild("path", "pitch-ladder-ticks");
    pitchLadder.setStrokeLineWidth(2);
    pitchLadder.setColor(1, 1, 1);

    var sp = HUD.pitchLadderDegreeSpacing; # shorthand
    var tenDegreeWidth = 64;
    var fiveDegreeWidth = 32;
    var twoFiveDegreeWidth = 24;

    # add line at zero
    me.addHorizontalSymmetricLine(pitchLadder, HUD.halfSize, 0);

    for (var i=1; i<=9; i+=1) 
    {
        var d = i * 10;
        me.addHorizontalSymmetricLine(pitchLadder, tenDegreeWidth, d * sp);
        me.addHorizontalSymmetricLine(pitchLadder, tenDegreeWidth, -d * sp);

        me.addHorizontalSymmetricLine(pitchLadder, fiveDegreeWidth, (d - 5) * sp);
        me.addHorizontalSymmetricLine(pitchLadder, fiveDegreeWidth, (5 - d) * sp);

        # 2.5 and 7.5 degree lines
        #me.addHorizontalSymmetricLine(pitchLadder, twoFiveDegreeWidth, (d - 2.5) * sp);
        #me.addHorizontalSymmetricLine(pitchLadder, twoFiveDegreeWidth, (2.5 - d) * sp);
        #me.addHorizontalSymmetricLine(pitchLadder, twoFiveDegreeWidth, (d - 7.5) * sp);
        #me.addHorizontalSymmetricLine(pitchLadder, twoFiveDegreeWidth, (7.5 - d) * sp);

        # add text as well
        var textUp = ladderGroup.createChild("text", "pitch-ladder-legend-" ~ d);
        textUp.setText(d);
        textUp.setAlignment("right-center");
        textUp.setTranslation(-tenDegreeWidth, d * sp);
        textUp.setFontSize(HUD.fontSizeSmall);
        textUp.setFont(HUD.fontBold);

        var textDown = ladderGroup.createChild("text", "pitch-ladder-legend-" ~ d);
        textDown.setText(d);
        textDown.setAlignment("right-center");
        textDown.setTranslation(-tenDegreeWidth, -d * sp);
        textDown.setFontSize(HUD.fontSizeSmall);
        textDown.setFont(HUD.fontBold);
    }
},

createSpeedTape : func()
{
    # short lines for text
    # long lines for 'odd' tens
    # 3 digit monospace text fits exactly between left side and short tick
    # maximum 5 (6?) visible text pieces

    me._speedTapeGroup = me.root.createChild("group", "speed-tape-group");
    me._speedTapeGroup.setTranslation(HUD.hsiLeft, 0);
    me._speedTapeGroup.set('z-index', 2);
    me._speedTapeGroup.set("clip-frame", canvas.Element.PARENT);
    me.setClip(me._speedTapeGroup, HUD.hsiTop, HUD.hsiLeft, HUD.hsiBottom, HUD.hsiLeft - HUD.speedTapeWidth);
    me._speedTapeGroup.set('z-index', 2);

	var tapePath = me._speedTapeGroup.createChild("path", "speed-tape");
    tapePath.setStrokeLineWidth(2);
    tapePath.setColor(1, 1, 1);

    var knotSpacing = 4;
    var tenKnotWidth = 16;
    var twentyKnotWidth = 8;

    for (var i=0; i<=100; i+=1)
    {
        var tenKnotY = ((i * 20) + 10) * knotSpacing;
        var twentyKnot = ((i+1) * 20);

        tapePath.moveTo(0, -tenKnotY).line(-tenKnotWidth, 0);
        tapePath.moveTo(0, -twentyKnot * knotSpacing).line(-twentyKnotWidth, 0);

        var text = me._speedTapeGroup.createChild("text", "speed-tape-legend-" ~ twentyKnot);
        text.setText(twentyKnot);
        text.setAlignment("right-center");
        text.setFont(HUD.fontBold);
        text.setFontSize(HUD.fontSizeMedium);
        text.setTranslation(-twentyKnotWidth-2, -twentyKnot * knotSpacing);
    }
},

updateSpeedTape : func()
{
    # special case when speed is close to zero (show 'bottom' only)
    # translate based on start value
    # update digits in text

    # given it's a 100kt range, maybe fixed graphic for the tape reduces updates?

    var yOffset = 4 * me._controller.getIndicatedAirspeedKnots();
    me._speedTapeGroup.setTranslation(HUD.hsiLeft, yOffset);
},

createAltitudeTape : func()
{
    # tick every 50' interval
    # text, monospace, 5 digits, ever 100'

    me._altTapeGroup = me.root.createChild("group", "altitude-tape-group");
    me._altTapeGroup.setTranslation(HUD.hsiRight, 0);
    me._altTapeGroup.set("background", [0.0,0.0,0.0,0.0]);
    me._altTapeGroup.set("clip-frame", canvas.Element.PARENT);
    me.setClip(me._altTapeGroup, HUD.hsiTop, HUD.hsiRight + HUD.altTapeWidth, HUD.hsiBottom, HUD.hsiRight);
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

createCompassRose : func()
{
    # clip group for numerals
    var clipGroup = me.root.createChild("group", "rose-clip-group");
    clipGroup.set("clip-frame", canvas.Element.PARENT);
    me.setClip(clipGroup, HUD.hsiBottom, HUD.hsiRight, HUD.hsiBottom + HUD.roseRadius, HUD.hsiLeft);    
    clipGroup.set('z-index', 2);
    clipGroup.setTranslation(0, 10);

    var arrowHeight = 20;

    # background of the compass
    var p = clipGroup.createChild('path', 'rose-background');
    #p.moveTo(HUD.hsiXCenter - HUD.roseRadius, HUD.hsiBottom + 12 + HUD.roseRadius);
    p.moveTo(- HUD.roseRadius, HUD.hsiBottom + arrowHeight + HUD.roseRadius);
    p.arcSmallCW(HUD.roseRadius, HUD.roseRadius, 0, 
                 HUD.roseRadius * 2, 0);
    p.close();
    p.setColor('#FFFFFF'); 
    #p.setColorFill('#738A7E'); 

    # add path for the heading arrow
    var arrow = clipGroup.createChild("path", "rose-arrow");
    arrow.setTranslation(0, HUD.hsiBottom);
    arrow.setStrokeLineWidth(2);
    arrow.setColor(1, 1, 1);

    # same size as the roll arrow
    var arrowHWidth = arrowHeight * (2/3);

    arrow.moveTo(0, arrowHeight);
    arrow.line(arrowHWidth, -arrowHeight);
    arrow.line(-arrowHWidth * 2, 0);
    arrow.close();
    arrow.set('z-index', 4);

    me._roseGroup = clipGroup.createChild('group', 'rose-group');
    me._roseGroup.setTranslation(0, HUD.hsiBottom + arrowHeight + HUD.roseRadius);

    var roseTicks = me._roseGroup.createChild('path', 'rose-ticks');
    roseTicks.setStrokeLineWidth(2);
    roseTicks.setColor(1, 1, 1);
    roseTicks.set('z-index', 2);

    var textR = (HUD.roseRadius) - 16;
    for (var i=0; i<36; i+=1) {
        # create ten degree text
        # TODO: 30 degree sizes should be bigger

        var text = me._roseGroup.createChild("text", "compass-rose-" ~ i);
        text.setText(i*10);
        text.setFontSize(HUD.fontSizeMedium);
        text.setAlignment("center-top");
        text.setFont(HUD.fontBold);

        var horAngle = 90 - (i * 10); # angle from +ve X axis
        var sa = math.sin(horAngle * D2R);
        var ca = math.cos(horAngle * D2R);
        text.setTranslation(ca * textR, -sa * textR);
        text.setRotation(i * 10 * D2R);

        me.addPolarTick(roseTicks, i * 10, HUD.roseRadius, HUD.roseRadius - 8);
        me.addPolarTick(roseTicks, (i * 10) + 5, HUD.roseRadius, HUD.roseRadius - 16);
    }

    roseTicks.close();
},

createAltitudeBox : func()
{
    var halfBoxHeight = HUD.boxHeight / 2;
    var box = me.root.rect(HUD.hsiRight, -halfBoxHeight, 
                          HUD.altTapeWidth + 10, HUD.boxHeight);
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

    text.setText('888 ');
    text.setFontSize(HUD.fontSizeLarge);
    text.setAlignment("left-center");
    text.setFont(HUD.fontRegular);

    me._speedDigit0 = me.createDigitTape(clipGroup, 'speed-digit0');
    me._speedDigit0.set('z-index', 4);
},

createElevatorIndicator : func()
{
    # Vertical line and arrow showing elevator input

    me._elevatorGroup = me.root.createChild("group", "elevator-group");
    me._elevatorGroup.setTranslation(HUD.elevatorIndicatorPos, 0);
    me._elevatorGroup.set('z-index', 2);
    me._elevatorGroup.set("clip-frame", canvas.Element.PARENT);
    var border = 22;
    me.setClip(me._elevatorGroup, - HUD.elevatorIndicatorHeight * 0.5 - border, HUD.elevatorIndicatorPos + border, HUD.elevatorIndicatorHeight * 0.5 + border, HUD.elevatorIndicatorPos - border);
    me._elevatorGroup.set('z-index', 2);

	var elevatorPath = me._elevatorGroup.createChild("path", "elevator-guage");
    elevatorPath.setStrokeLineWidth(2);
    elevatorPath.setColor(1, 1, 1);
    elevatorPath.moveTo(-5,-HUD.elevatorIndicatorHeight * 0.5);
    elevatorPath.line(5,0);
    elevatorPath.line(0, HUD.elevatorIndicatorHeight * 0.5);
    elevatorPath.line(-5,0);
    elevatorPath.line(5,0);
    elevatorPath.line(0, HUD.elevatorIndicatorHeight * 0.5);
    elevatorPath.line(-5,0);

    me.elevatorIndicator = me._elevatorGroup.createChild("path", "elevator-indicator");
    me.elevatorIndicator.setStrokeLineWidth(2);
    me.elevatorIndicator.setColor(1, 1, 1);

    var arrowWidth = 20;
    var arrowHHeight = arrowWidth * (2/3);

    me.elevatorIndicator.moveTo(-arrowWidth, -arrowHHeight);
    me.elevatorIndicator.line(arrowWidth, arrowHHeight);
    me.elevatorIndicator.line(-arrowWidth, arrowHHeight);
    me.elevatorIndicator.close();
    me.elevatorIndicator.set('z-index', 4);

    me.elevatorTrimIndicator = me._elevatorGroup.createChild("path", "elevator-trim-indicator");
    me.elevatorTrimIndicator.setStrokeLineWidth(2);
    me.elevatorTrimIndicator.setColor(1, 1, 1);

    # same size as the roll arrow
    var arrowWidth = 20;
    var arrowHHeight = arrowWidth * (2/3);

    me.elevatorTrimIndicator.moveTo(arrowWidth, -arrowHHeight);
    me.elevatorTrimIndicator.line(-arrowWidth, arrowHHeight);
    me.elevatorTrimIndicator.line(arrowWidth, arrowHHeight);
    me.elevatorTrimIndicator.close();
    me.elevatorTrimIndicator.set('z-index', 4);
},

createRudderIndicator : func()
{
    # Horizontal line and arrow showing rudder input
    me._rudderGroup = me.root.createChild("group", "rudder-group");
    me._rudderGroup.setTranslation(0, HUD.rudderIndicatorPos);
    # me._rudderGroup.set("clip-frame", canvas.Element.PARENT);
    var border = 22;
    #me.setClip(me._rudderGroup, HUD.rudderIndicatorPos - border, HUD.rudderIndicatorWidth * 0.5 + border, HUD.rudderIndicatorPos + border, -HUD.rudderIndicatorWidth * 0.5 - border);
    me._rudderGroup.set('z-index', 2);

	var rudderPath = me._rudderGroup.createChild("path", "rudder-guage");
    rudderPath.setStrokeLineWidth(2);
    rudderPath.setColor(1, 1, 1);
    rudderPath.moveTo(-HUD.rudderIndicatorWidth * 0.5, 25);
    rudderPath.line(0, -5);
    rudderPath.line(HUD.rudderIndicatorWidth * 0.5, 0);
    rudderPath.line(0, 5);
    rudderPath.line(0, -5);
    rudderPath.line(HUD.rudderIndicatorWidth * 0.5, 0);
    rudderPath.line(0, 5);

    me.rudderIndicator = me._rudderGroup.createChild("path", "rudder-indicator");
    me.rudderIndicator.setStrokeLineWidth(2);
    me.rudderIndicator.setColor(1, 1, 1);

    var arrowHeight = 20;
    var arrowHWidth = arrowHeight * (2/3);

    me.rudderIndicator.moveTo(0, arrowHeight);
    me.rudderIndicator.line(arrowHWidth, arrowHeight);
    me.rudderIndicator.line(-arrowHWidth * 2, 0);
    me.rudderIndicator.close();
    me.rudderIndicator.set('z-index', 4);

    me.rudderTrimIndicator = me._rudderGroup.createChild("path", "rudder-trim-indicator");
    me.rudderTrimIndicator.setStrokeLineWidth(2);
    me.rudderTrimIndicator.setColor(1, 1, 1);

    var arrowHeight = 20;
    var arrowHWidth = arrowHeight * (2/3);

    me.rudderTrimIndicator.moveTo(0, arrowHeight);
    me.rudderTrimIndicator.line(arrowHWidth, -arrowHeight);
    me.rudderTrimIndicator.line(-arrowHWidth * 2, 0);
    me.rudderTrimIndicator.close();
    me.rudderTrimIndicator.set('z-index', 4);
},

createAileronIndicator : func()
{
    # Horizontal line and arrow showing aileron input
    me._aileronGroup = me.root.createChild("group", "aileron-group");
    me._aileronGroup.setTranslation(0, HUD.aileronIndicatorPos);
    # me._aileronGroup.set("clip-frame", canvas.Element.PARENT);
    var border = 22;
    #me.setClip(me._aileronGroup, HUD.aileronIndicatorPos - border, HUD.aileronIndicatorWidth * 0.5 + border, HUD.aileronIndicatorPos + border, -HUD.aileronIndicatorWidth * 0.5 - border);
    me._aileronGroup.set('z-index', 2);

	var aileronPath = me._aileronGroup.createChild("path", "aileron-guage");
    aileronPath.setStrokeLineWidth(2);
    aileronPath.setColor(1, 1, 1);
    aileronPath.moveTo(-HUD.aileronIndicatorWidth * 0.5, 15);
    aileronPath.line(0, 5);
    aileronPath.line(HUD.aileronIndicatorWidth * 0.5, 0);
    aileronPath.line(0, -5);
    aileronPath.line(0, 5);
    aileronPath.line(HUD.aileronIndicatorWidth * 0.5, 0);
    aileronPath.line(0, -5);

    me.aileronIndicator = me._aileronGroup.createChild("path", "aileron-indicator");
    me.aileronIndicator.setStrokeLineWidth(2);
    me.aileronIndicator.setColor(1, 1, 1);

    var arrowHeight = 20;
    var arrowHWidth = arrowHeight * (2/3);

    me.aileronIndicator.moveTo(0, arrowHeight);
    me.aileronIndicator.line(arrowHWidth, -arrowHeight);
    me.aileronIndicator.line(-arrowHWidth * 2, 0);
    me.aileronIndicator.close();
    me.aileronIndicator.set('z-index', 4);

    me.aileronTrimIndicator = me._aileronGroup.createChild("path", "aileron-trim-indicator");
    me.aileronTrimIndicator.setStrokeLineWidth(2);
    me.aileronTrimIndicator.setColor(1, 1, 1);

    var arrowHeight = 20;
    var arrowHWidth = arrowHeight * (2/3);

    me.aileronTrimIndicator.moveTo(0, arrowHeight);
    me.aileronTrimIndicator.line(arrowHWidth, arrowHeight);
    me.aileronTrimIndicator.line(-arrowHWidth * 2, 0);
    me.aileronTrimIndicator.close();
    me.aileronTrimIndicator.set('z-index', 4);
},
updateControlPositions : func()
{
    me.elevatorIndicator.setTranslation(0, me._controller.getElevatorPos() * HUD.elevatorIndicatorHeight * 0.5);
    me.elevatorTrimIndicator.setTranslation(0, me._controller.getElevatorTrimPos() * HUD.elevatorIndicatorHeight * 0.5);
    me.rudderIndicator.setTranslation(me._controller.getRudderPos() * HUD.rudderIndicatorWidth * 0.5, 0);
    me.rudderTrimIndicator.setTranslation(me._controller.getRudderTrimPos() * HUD.rudderIndicatorWidth * 0.5, 0);
    me.aileronIndicator.setTranslation(me._controller.getAileronPos() * HUD.aileronIndicatorWidth * 0.5, 0);
    me.aileronTrimIndicator.setTranslation(me._controller.getAileronTrimPos() * HUD.aileronIndicatorWidth * 0.5, 0);

},

update : func()
{
    # read LOC/GS deviation
    # read Mach for some options  
    me._controller.update();

# pitch and roll 
    var roll = me._controller.getBankAngleDeg() * D2R;
    var pitch = me._controller.getPitchDeg();
    #me.pitchGroup.setTranslation(HUD.hsiXCenter, pitch * me.pitchLadderDegreeSpacing);
    me.pitchGroup.setTranslation(0, pitch * me.pitchLadderDegreeSpacing);
    me._pitchRotation.setRotation(-roll);
    me._rollGroup.setRotation(-roll);

# heading
    me._roseGroup.setRotation(-me._controller.getHeadingDeg() * D2R);

    me.updateAltitudeTape();
    me.updateSpeedTape();

# speed box
    var spd = me._controller.getIndicatedAirspeedKnots();
    var spdDigit0 = math.mod(spd, 10);
    me._speedDigit0.setTranslation(76, 15 + spdDigit0 * 44);
    var s = sprintf("%03i ", math.floor(spd / 10));
    me._speedBoxText.setText(s);

# altitude box
    var alt = me._controller.getAltitudeFt();
    var altDigits00 = math.mod(alt / 10, 10);
    me._altitudeDigits00.setTranslation(80, 16 + altDigits00 * 32);
    var s = sprintf("%03i ", math.floor(alt / 100));
    me._altitudeBoxText.setText(s);

# flight controls
    me.updateControlPositions();
},  

};
