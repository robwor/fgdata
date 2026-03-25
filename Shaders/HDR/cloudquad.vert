$FG_GLSL_VERSION

#pragma import_defines(QUAD_TEXCOORD_RAW)

#ifdef QUAD_TEXCOORD_RAW
out vec2 raw_texcoord;
#endif
out vec2 texcoord;
out vec3 w_pos;

uniform mat4 fg_CameraZUpMatrix;
uniform vec3 fg_CameraPositionCart;

// mvr.vert
vec2 mvr_raw_texcoord_transform_fb(vec2 raw_texcoord);

// pos_from_depth.glsl
vec3 get_world_space_from_depth(vec2 uv, float depth);

void main()
{
    vec2 pos = vec2(gl_VertexID % 2, gl_VertexID / 2) * 4.0 - 1.0;
    vec2 loc_raw_texcoord = pos * 0.5 + 0.5;
#ifdef QUAD_TEXCOORD_RAW
    raw_texcoord = loc_raw_texcoord;
#endif
    texcoord = mvr_raw_texcoord_transform_fb(loc_raw_texcoord);
    w_pos = get_world_space_from_depth(texcoord, 1.0);
    gl_Position = vec4(pos, 0.0, 1.0);
}
