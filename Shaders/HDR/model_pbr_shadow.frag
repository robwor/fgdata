$FG_GLSL_VERSION

layout(location = 0) out vec4 fragColor;

in VS_OUT {
    vec2 texcoord;
} fs_in;

uniform sampler2D color_tex;

uniform vec4 base_color_factor;
uniform float alpha_cutoff;

void main()
{
    if (alpha_cutoff > 0.0) {
        vec4 base_color_texel = texture(color_tex, fs_in.texcoord);
        if (base_color_texel.a * base_color_factor.a < alpha_cutoff)
            discard;
    }

    fragColor = vec4(1.0);
}
