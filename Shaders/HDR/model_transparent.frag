#version 330 core

layout(location = 0) out vec4 fragColor;

in VS_OUT {
    float flogz;
    vec2 texcoord;
    vec3 vertex_normal;
    vec3 view_vector;
    vec4 material_color;
    vec4 ap_color;
} fs_in;

uniform sampler2D color_tex;

uniform float pbr_metallic;
uniform float pbr_roughness;

uniform mat4 osg_ViewMatrixInverse;
uniform vec4 fg_Viewport;

// color.glsl
vec3 eotf_inverse_sRGB(vec3 srgb);
// shading_transparent.glsl
vec3 eval_lights_transparent(vec3 base_color,
                             float metallic,
                             float roughness,
                             float occlusion,
                             vec3 emissive,
                             vec3 P, vec3 N, vec3 V,
                             vec4 ap,
                             mat4 view_matrix_inverse);
// logarithmic_depth.glsl
float logdepth_encode(float z);

void main()
{
    vec4 texel = texture(color_tex, fs_in.texcoord);
    vec3 base_color = eotf_inverse_sRGB(texel.rgb) * fs_in.material_color.rgb;
    float alpha = texel.a * fs_in.material_color.a;

    vec3 N = normalize(fs_in.vertex_normal);
    vec3 V = normalize(-fs_in.view_vector);

    vec3 color = eval_lights_transparent(base_color,
                                         pbr_metallic,
                                         pbr_roughness,
                                         1.0,
                                         vec3(0.0),
                                         fs_in.view_vector, N, V,
                                         fs_in.ap_color,
                                         osg_ViewMatrixInverse);

    fragColor = vec4(color, alpha);
    gl_FragDepth = logdepth_encode(fs_in.flogz);
}
