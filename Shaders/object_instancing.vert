// -*-C++-*-
#version 120

#extension GL_EXT_draw_instanced : enable

attribute vec3 instance_position; // (x,y,z)
attribute vec4 instance_rotation_and_scale; // (heading, pitch, roll, scale)

varying vec3 normal;
varying vec4 ecPosition;

void setupShadows(vec4 eyeSpacePos);
void render_ALS_base(in vec3 position);
void apply_instance_transforms(inout vec3 position, inout vec3 normal, in vec3 instance_position, in vec4 instance_rotation_and_scale);

void main()
{
    vec3 position = gl_Vertex.xyz;
    apply_instance_transforms(position, normal, instance_position, instance_rotation_and_scale);
    render_ALS_base(position);
    setupShadows(ecPosition);
}
