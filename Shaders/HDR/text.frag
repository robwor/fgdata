#version 330 core

layout(location = 0) out vec4 fragColor;

in VS_OUT {
    float flogz;
    vec2 texcoord;
    vec3 vertex_normal;
    vec3 view_vector;
    vec4 ap_color;
} fs_in;

uniform sampler2D glyph_tex;

uniform mat4 osg_ViewMatrixInverse;
uniform vec4 fg_Viewport;

// XXX: We should be able to modify these through material animations
const vec3  TEXT_BASE_COLOR = vec3(1.0);
const float TEXT_METALLIC   = 0.0;
const float TEXT_ROUGHNESS  = 1.0;
const vec3  TEXT_EMISSION   = vec3(0.0);

// color.glsl
vec3 eotf_inverse_sRGB(vec3 srgb);
// shading_transparent.glsl
vec3 eval_lights_transparent(
    vec3 base_color, float metallic, float roughness, float occlusion,
    vec3 emissive, vec3 P, vec3 N, vec3 V, vec2 uv, vec4 ap,
    mat4 view_matrix_inverse);
// logarithmic_depth.glsl
float logdepth_encode(float z);

void main()
{
    float alpha = texture(glyph_tex, fs_in.texcoord).a;

    vec3 N = normalize(fs_in.vertex_normal);
    vec3 V = normalize(-fs_in.view_vector);
    vec2 uv = (gl_FragCoord.xy - fg_Viewport.xy) / fg_Viewport.zw;

    vec3 color = eval_lights_transparent(
        TEXT_BASE_COLOR, TEXT_METALLIC, TEXT_ROUGHNESS, 1.0, TEXT_EMISSION,
        fs_in.view_vector, N, V, uv, fs_in.ap_color, osg_ViewMatrixInverse);

    fragColor = vec4(color, alpha);
    gl_FragDepth = logdepth_encode(fs_in.flogz);
}
