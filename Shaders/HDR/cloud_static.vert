#version 330 core

out float flogz;
out vec4 ap_color;

// cloud_static_common.vert
void cloud_static_common_vert(out vec4 vs_pos, out vec4 ws_pos);
// aerial_perspective.glsl
vec4 get_aerial_perspective(vec2 coord, float depth);
// logarithmic_depth.glsl
float logdepth_prepare_vs_depth(float z);

void main()
{
    vec4 vs_pos, ws_pos;
    cloud_static_common_vert(vs_pos, ws_pos);

    flogz = logdepth_prepare_vs_depth(gl_Position.w);

    // Perspective division and scale to [0, 1] to get the screen position
    // of the vertex.
    vec2 coord = (gl_Position.xy / gl_Position.w) * 0.5 + 0.5;
    ap_color = get_aerial_perspective(coord, length(vs_pos.xyz));
}
