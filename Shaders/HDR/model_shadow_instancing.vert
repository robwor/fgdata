$FG_GLSL_VERSION

layout(location = 0) in vec4 pos;
layout(location = 6) in vec3 instance_position; // (x,y,z)
layout(location = 7) in vec4 instance_rotation_and_scale; // (heading, pitch, roll, scale)

uniform mat4 osg_ModelViewProjectionMatrix;

// object_instancing.glsl
void apply_instance_transforms(inout vec3 position, inout vec3 normal, in vec3 instance_position, in vec4 instance_rotation_and_scale);


void main()
{
    vec4 new_pos = pos;
    vec4 dummy_normal = vec4(1.0);
    apply_instance_transforms(new_pos, dummy_normal, instance_position, instance_rotation_and_scale);
    gl_Position = osg_ModelViewProjectionMatrix * new_pos;
}
