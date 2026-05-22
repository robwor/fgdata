$FG_GLSL_VERSION

layout(location = 0) in vec4 pos;
layout(location = 3) in vec4 multitexcoord0;

out VS_OUT {
    float flogz;
    vec2 texcoord;
} vs_out;

uniform bool flip_vertically;

uniform mat4 osg_ModelViewProjectionMatrix;
uniform mat4 fg_TextureMatrix;

// logarithmic_depth.glsl
float logdepth_prepare_vs_depth(float z);

void main()
{
    gl_Position = osg_ModelViewProjectionMatrix * pos;
    vs_out.flogz = logdepth_prepare_vs_depth(gl_Position.w);
    vs_out.texcoord = vec2(fg_TextureMatrix * multitexcoord0);
    if (flip_vertically)
        vs_out.texcoord.y = 1.0 - vs_out.texcoord.y;
}
