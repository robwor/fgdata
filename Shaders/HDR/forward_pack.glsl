$FG_GLSL_VERSION

#pragma import_defines(BLEND_ADDITIVE)
#pragma import_defines(BLEND_PREMULTIPLIED)

/*
 * The back color attachment (the main opaque HDR buffer) is overwritten by
 * clouds, whereas the front color attachment (the transparent HDR buffer) is
 * applied on top of clouds.
 */
layout(location = 0) out vec4 fragColorBack;
layout(location = 1) out vec4 fragColorFront;

const float fade_m = 20.0;

uniform sampler2D clouds_depth_tex;
uniform vec2 fg_PixelSize;

// logarithmic_depth.glsl
float logdepth_decode(float z);

/*
 * Put color only in the back color attachment. Use this for background objects
 * which will never need to be in front of clouds.
 */
void forward_pack_background(vec4 color)
{
    fragColorBack = color;
    fragColorFront = vec4(0.0);
}

/*
 * Step smoothly from all back (0.0) to all front (1.0) as depth decreases past
 * cloud depth.
 */
float forward_front_alpha(float flogz)
{
    float cloudDepth = texture(clouds_depth_tex, gl_FragCoord.xy * fg_PixelSize, 0).r;
    float cloudZ = logdepth_decode(cloudDepth);
    return smoothstep(-cloudZ - fade_m, -cloudZ, -flogz);
}

/*
 * Split the color between the two attachments based on depth relative to clouds.
 *
 * This assumes traditional alpha blending with correct handling of alpha
 * channel.
 * i.e. separate blend func:
 *   <source-rgb>src-alpha</source-rgb>
 *   <destination-rgb>one-minus-src-alpha</destination-rgb>
 *   <source-alpha>one-minus-dst-alpha</source-alpha>
 *   <destination-alpha>one</destination-alpha>
 *
 * Unless BLEND_PREMULTIPLIED is defined, in which case premultiplied source
 * RGB is also assumed:
 *   <source-rgb>one</source-rgb>
 *
 * Or if BLEND_ADDITIVE is defined, in which case additive blending is also
 * assumed:
 *   <destination-rgb>one</destination-rgb>
 *   <source-alpha>zero</source-alpha>
 */
void forward_pack(vec4 color, float flogz)
{
    float frontAlpha = forward_front_alpha(flogz);
#ifdef BLEND_ADDITIVE
    float backAlpha = 1.0f - frontAlpha;
#else
    // Calculate back alpha so that combined alpha matches color.a
    float backAlpha = 1.0;
    if (color.a * frontAlpha < 1.0)
        backAlpha = (1.0f - frontAlpha) / (1.0 - color.a * frontAlpha);
#endif

#ifdef BLEND_PREMULTIPLIED
    // Premultiply RGB
    fragColorBack = color * backAlpha;
    fragColorFront = color * frontAlpha;
#else
    // RGB will be multiplied by alpha
    fragColorBack = vec4(color.rgb, color.a * backAlpha);
    fragColorFront = vec4(color.rgb, color.a * frontAlpha);
#endif
}
