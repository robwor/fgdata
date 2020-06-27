#version 330 core

in VS_OUT {
    float flogz;
    vec3 vertex_normal;
} fs_in;

const float CHROME_METALLIC  = 1.0;
const float CHROME_ROUGHNESS = 0.1;

// gbuffer_pack.glsl
void gbuffer_pack_pbr_opaque(vec3 normal,
                             vec3 base_color,
                             float metallic,
                             float roughness,
                             float occlusion,
                             vec3 emissive);
// logarithmic_depth.glsl
float logdepth_encode(float z);

void main()
{
    vec3 N = normalize(fs_in.vertex_normal);
    gbuffer_pack_pbr_opaque(N, vec3(1.0), CHROME_METALLIC, CHROME_ROUGHNESS, 1.0, vec3(0.0));
    gl_FragDepth = logdepth_encode(fs_in.flogz);
}
