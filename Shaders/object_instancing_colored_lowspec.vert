// -*-C++-*-
#version 120

#extension GL_EXT_draw_instanced : enable

// Based on object-instancing-lowspec.vert, with minor additions for instance color

#define MODE_OFF 0
#define MODE_DIFFUSE 1
#define MODE_AMBIENT_AND_DIFFUSE 2

attribute vec3 instance_position; // (x,y,z)
attribute vec4 instance_rotation_and_scale; // (heading, pitch, roll, scale)
attribute vec4 instance_custom_attrib; // (r,g,b,a)

varying vec4 diffuse_term;
varying vec3 normal;
varying vec4 ecPosition;

varying vec4 instanceColor;

uniform int colorMode;

void setupShadows(vec4 eyeSpacePos);
void apply_instance_transforms(inout vec3 position, inout vec3 normal, in vec3 instance_position, in vec4 instance_rotation_and_scale);

void main()
{
    vec3 position = gl_Vertex.xyz;
    apply_instance_transforms(position, normal, instance_position, instance_rotation_and_scale);

    gl_Position = gl_ModelViewProjectionMatrix * vec4(position, gl_Vertex.w);

    // Pass instance color to fragment shader from custom attribute
    instanceColor = instance_custom_attrib;

    /************* The following is copied from default.vert *************/
    ecPosition = gl_ModelViewMatrix * gl_Vertex;
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    gl_TexCoord[2] = gl_TextureMatrix[2] * gl_MultiTexCoord2;

    vec4 ambient_color, diffuse_color;
    if (colorMode == MODE_DIFFUSE) {
        diffuse_color = gl_Color;
        ambient_color = gl_FrontMaterial.ambient;
    } else if (colorMode == MODE_AMBIENT_AND_DIFFUSE) {
        diffuse_color = gl_Color;
        ambient_color = gl_Color;
    } else {
        diffuse_color = gl_FrontMaterial.diffuse;
        ambient_color = gl_FrontMaterial.ambient;
    }
    diffuse_term = diffuse_color * gl_LightSource[0].diffuse;
    vec4 constant_term = gl_FrontMaterial.emission + ambient_color *
        (gl_LightModel.ambient +  gl_LightSource[0].ambient);
    // Super hack: if diffuse material alpha is less than 1, assume a
    // transparency animation is at work
    if (gl_FrontMaterial.diffuse.a < 1.0)
        diffuse_term.a = gl_FrontMaterial.diffuse.a;
    else
        diffuse_term.a = gl_Color.a;
    // Another hack for supporting two-sided lighting without using
    // gl_FrontFacing in the fragment shader.
    gl_FrontColor.rgb = constant_term.rgb;  gl_FrontColor.a = 1.0;
    gl_BackColor.rgb = constant_term.rgb; gl_BackColor.a = 0.0;

    setupShadows(ecPosition);
}
