$FG_GLSL_VERSION

layout(location = 0) out vec4 fragColor;

in vec2 texcoord;

uniform sampler2D cloud_tex;

void main()
{
    vec3 color = texture(cloud_tex, texcoord).xyz;
    fragColor = vec4(color, 1.0);
}