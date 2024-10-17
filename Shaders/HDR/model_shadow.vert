#version 330 core

#pragma import_defines(USE_CHUTE_DEFORMATION)

layout(location = 0) in vec4 pos;

uniform mat4 osg_ModelViewProjectionMatrix;

#ifdef USE_CHUTE_DEFORMATION
// chute.glsl
vec3 chute_apply_deformation(vec3 pos);
#endif

void main()
{
    vec4 new_pos = pos;
#ifdef USE_CHUTE_DEFORMATION
    new_pos.xyz = chute_apply_deformation(new_pos.xyz);
#endif
    gl_Position = osg_ModelViewProjectionMatrix * new_pos;
}
