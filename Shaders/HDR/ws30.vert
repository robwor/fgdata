$FG_GLSL_VERSION

layout(location = 0) in vec4 pos;
layout(location = 3) in vec4 multitexcoord0;

out VS_OUT {
    vec2 p2d_ws;
    vec2 texcoord;
} vs_out;

uniform vec3 fg_modelOffset;
uniform mat4 fg_zUpTransform;

void main()
{
    gl_Position = fg_zUpTransform * pos;
    // XXX: We need a 2D world position here to have a continuous noise function
    // Unfortunately our coordinates are too big so the noise quality suffers.
    // Maybe a 1x1 degree tile is good enough?
    vs_out.p2d_ws = gl_Position.xy;
    vs_out.texcoord = multitexcoord0.xy;
}
