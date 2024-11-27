$FG_GLSL_VERSION

layout(location = 0) out vec4 fragColor;

in vec2 texcoord;

uniform sampler3D aerial_perspective_tex;

uniform vec4 fg_Viewport;

// exposure.glsl
vec3 apply_exposure(vec3 color);

void main()
{
    vec2 pixel_size = (5.0*8.0) / fg_Viewport.zw;
    float col = texcoord.x * 8.0;
    float row = texcoord.y * 8.0;
    float row2 = texcoord.y * 4.0;
    float slice = (3.0 - floor(row2)) * 8.0 + floor(col);
    vec3 coords = vec3(fract(col), fract(row), slice / 32.0);

    vec3 color;
    if (fract(row2) < 0.5) {
        // Transmittance
        color = vec3(texture(aerial_perspective_tex, coords).a);
    } else {
        // In-scattering
        color = texture(aerial_perspective_tex, coords).rgb;
        // Pre-expose
        color = apply_exposure(color);
    }

    // Cell borders
    vec2 redline = step(pixel_size, vec2(fract(col), fract(row2)));
    color = mix(vec3(1.0, 0.0, 0.0), vec3(color), redline.x * redline.y);

    fragColor = vec4(color, 1.0);
}
