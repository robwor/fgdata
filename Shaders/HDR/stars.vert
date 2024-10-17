#version 330 core

layout(location = 0) in vec4 pos;
layout(location = 2) in vec4 vertex_color;

out VS_OUT {
    vec4 color;
    vec3 view_vector;
} vs_out;

uniform mat4 osg_ModelViewMatrix;
uniform mat4 osg_ModelViewProjectionMatrix;

void main()
{
    gl_Position = osg_ModelViewProjectionMatrix * pos;
    vs_out.color = vertex_color;
    vs_out.view_vector = (osg_ModelViewMatrix * pos).xyz;
}
