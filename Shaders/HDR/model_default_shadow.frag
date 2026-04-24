$FG_GLSL_VERSION

layout(location = 0) out vec4 fragColor;

in VS_OUT {
    vec2 texcoord;
    float material_alpha;
} fs_in;

uniform sampler2D color_tex;

uniform float alpha_cutoff;

void main()
{
    if (alpha_cutoff > 0.0) {
        vec4 texel = texture(color_tex, fs_in.texcoord);
        if (texel.a * fs_in.material_alpha < alpha_cutoff)
            discard;
    }

    fragColor = vec4(1.0);
}
