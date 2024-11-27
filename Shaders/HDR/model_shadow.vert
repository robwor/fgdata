$FG_GLSL_VERSION

#pragma import_defines(USE_WINGFLEX_DEFORMATION USE_CHUTE_DEFORMATION)

layout(location = 0) in vec4 pos;

uniform mat4 osg_ModelViewProjectionMatrix;

#ifdef USE_WINGFLEX_DEFORMATION
// wingflex.glsl
vec3 wingflex_apply_deformation(vec3 pos);
#endif
#ifdef USE_CHUTE_DEFORMATION
// chute.glsl
vec3 chute_apply_deformation(vec3 pos);
#endif

void main()
{
    vec4 new_pos = pos;
#ifdef USE_WINGFLEX_DEFORMATION
    new_pos.xyz = wingflex_apply_deformation(new_pos.xyz);
#endif
#ifdef USE_CHUTE_DEFORMATION
    new_pos.xyz = chute_apply_deformation(new_pos.xyz);
#endif
    gl_Position = osg_ModelViewProjectionMatrix * new_pos;
}
