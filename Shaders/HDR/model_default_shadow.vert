$FG_GLSL_VERSION

layout(location = 0) in vec4 pos;

uniform mat4 osg_ModelViewProjectionMatrix;

void main()
{
    gl_Position = osg_ModelViewProjectionMatrix * pos;
}
