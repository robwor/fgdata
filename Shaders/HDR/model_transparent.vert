#version 330 core

#define MODE_OFF 0
#define MODE_DIFFUSE 1
#define MODE_AMBIENT_AND_DIFFUSE 2

layout(location = 0) in vec4 pos;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec4 vertex_color;
layout(location = 3) in vec4 multitexcoord0;

out VS_OUT {
    float flogz;
    vec2 texcoord;
    vec3 vertex_normal;
    vec3 view_vector;
    vec4 material_color;
    vec4 ap_color;
} vs_out;

uniform int color_mode;
uniform vec4 material_diffuse;

uniform mat4 osg_ModelViewMatrix;
uniform mat4 osg_ModelViewProjectionMatrix;
uniform mat3 osg_NormalMatrix;
uniform mat4 fg_TextureMatrix;

// aerial_perspective.glsl
vec4 get_aerial_perspective(vec2 coord, float depth);
// logarithmic_depth.glsl
float logdepth_prepare_vs_depth(float z);

void main()
{
    gl_Position = osg_ModelViewProjectionMatrix * pos;
    vs_out.flogz = logdepth_prepare_vs_depth(gl_Position.w);
    vs_out.vertex_normal = osg_NormalMatrix * normal;
    vs_out.view_vector = (osg_ModelViewMatrix * pos).xyz;
    vs_out.texcoord = vec2(fg_TextureMatrix * multitexcoord0);

    // Legacy material handling
    if (color_mode == MODE_DIFFUSE)
        vs_out.material_color = vertex_color;
    else if (color_mode == MODE_AMBIENT_AND_DIFFUSE)
        vs_out.material_color = vertex_color;
    else
        vs_out.material_color = material_diffuse;
    // Super hack: if diffuse material alpha is less than 1, assume a
    // transparency animation is at work
    if (material_diffuse.a < 1.0)
        vs_out.material_color.a = material_diffuse.a;
    else
        vs_out.material_color.a = vertex_color.a;

    vec2 coord = (gl_Position.xy / gl_Position.w) * 0.5 + 0.5;
    vs_out.ap_color = get_aerial_perspective(coord, length(vs_out.view_vector));
}
