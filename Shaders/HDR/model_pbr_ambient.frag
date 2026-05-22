$FG_GLSL_VERSION

in VS_OUT {
    float flogz;
    vec2 texcoord;
} fs_in;

uniform sampler2D base_color_tex;
uniform sampler2D emissive_tex;

uniform vec4 base_color_factor;
uniform vec3 emissive_factor;
uniform float alpha_cutoff;

// color.glsl
vec3 eotf_inverse_sRGB(vec3 srgb);
// logarithmic_depth.glsl
float logdepth_encode(float z);
// forward_pack.glsl
void forward_pack_background(vec4 color);

void main()
{
    vec4 base_color_texel = texture(base_color_tex, fs_in.texcoord);
    float base_alpha = base_color_texel.a * base_color_factor.a;
    // Only use alpha for discarding based on a threshold
    // Otherwise we assume this is a completely opaque object
    if (base_alpha < alpha_cutoff)
        discard;

    vec3 emissive_texel = texture(emissive_tex, fs_in.texcoord).rgb;
    vec3 emissive = eotf_inverse_sRGB(emissive_texel) * emissive_factor;

    forward_pack_background(vec4(emissive, base_alpha));
    gl_FragDepth = logdepth_encode(fs_in.flogz);
}
