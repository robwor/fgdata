$FG_GLSL_VERSION

layout(location = 0) in vec4 pos;
layout(location = 2) in vec4 vertex_color;
layout(location = 3) in vec4 multitexcoord0;

out VS_OUT {
    vec2 texcoord;
    float material_alpha;
} vs_out;

uniform mat4 osg_ModelViewProjectionMatrix;
uniform mat4 fg_TextureMatrix;

void main()
{
    gl_Position = osg_ModelViewProjectionMatrix * pos;
    vs_out.texcoord = vec2(fg_TextureMatrix * multitexcoord0);
    vs_out.material_alpha = vertex_color.a;
}
