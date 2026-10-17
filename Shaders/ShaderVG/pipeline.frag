#version 330 core

#define PAINT_TYPE_COLOR            0x1B00
#define PAINT_TYPE_LINEAR_GRADIENT  0x1B01
#define PAINT_TYPE_RADIAL_GRADIENT  0x1B02
#define PAINT_TYPE_PATTERN          0x1B03

#define DRAW_IMAGE_NORMAL           0x1F00
#define DRAW_IMAGE_MULTIPLY         0x1F01

#define DRAW_MODE_PATH              0
#define DRAW_MODE_IMAGE             1

// Output is NOT clamped or premultiplied here. The blend function and render
// target format set by the host code must match the intended OpenVG semantics.
out vec4 fragColor;

in vec2 texImageCoord;
in vec2 paintCoord;

uniform int drawMode;
uniform int imageMode;
uniform int paintType;
uniform vec4 paintColor;
uniform vec2 paintParams[3];
uniform vec4 scaleFactorBias[2];

// Texture units are assigned by the host (GLSL 330 has no layout(binding=...)):
// rampSampler and patternSampler both use unit 1 (only one is read per draw,
// and both are sampler2D, so sharing a unit is legal). imageSampler is
// currently unused because vgDrawImage() is compiled out in FlightGear.
uniform sampler2D imageSampler;
uniform sampler2D rampSampler;
uniform sampler2D patternSampler;

float linear_gradient(vec2 fragCoord, vec2 p0, vec2 p1)
{
    vec2  d     = p1 - p0;
    float denom = dot(d, d);

    // Degenerate gradient vector: avoid division by zero and resolve to the
    // end of the ramp. (With a REPEAT/MIRROR ramp wrap mode, 1.0 may alias to
    // the start; handle on the host side if exact behavior matters.)
    if (denom <= 0.0)
        return 1.0;

    return dot(d, fragCoord - p0) / denom;
}

float radial_gradient(vec2 fragCoord, vec2 centerCoord, vec2 focalCoord, float r)
{
    // Degenerate radius.
    if (r <= 0.0)
        return 1.0;

    // OpenVG requires the focal point to lie inside the circle. Clamp it to
    // just inside, which keeps the denominator below strictly positive.
    vec2  df    = focalCoord - centerCoord;
    float dfLen = length(df);
    float dfMax = r * 0.999;
    if (dfLen > dfMax)
        df *= dfMax / dfLen;
    vec2 focal = centerCoord + df;

    vec2  d     = fragCoord - focal;
    float cross = d.x * df.y - d.y * df.x;     // 2D cross product, may be < 0
    float r2    = r * r;

    // cross*cross instead of pow(cross, 2.0): pow() is undefined for x < 0.
    // max(): guard against tiny negative values from rounding.
    float disc  = max(r2 * dot(d, d) - cross * cross, 0.0);

    return (dot(d, df) + sqrt(disc)) / (r2 - dot(df, df));
}

void main()
{
    vec4 col;

    switch (paintType) {
    case PAINT_TYPE_LINEAR_GRADIENT:
    {
        float factor = linear_gradient(paintCoord, paintParams[0], paintParams[1]);
        col = texture(rampSampler, vec2(factor, 0.5));
    }
    break;
    case PAINT_TYPE_RADIAL_GRADIENT:
    {
        float factor = radial_gradient(paintCoord, paintParams[0], paintParams[1],
                                       paintParams[2].x);
        col = texture(rampSampler, vec2(factor, 0.5));
    }
    break;
    case PAINT_TYPE_PATTERN:
    {
        vec2 texCoord = paintCoord / paintParams[0];   // (width, height)
        col = texture(patternSampler, texCoord);
    }
    break;
    case PAINT_TYPE_COLOR:
    default:
        col = paintColor;
        break;
    }

    if (drawMode == DRAW_MODE_IMAGE) {
        col = texture(imageSampler, texImageCoord)
            * (imageMode == DRAW_IMAGE_MULTIPLY ? col : vec4(1.0));
    }

    fragColor = col * scaleFactorBias[0] + scaleFactorBias[1];
}
