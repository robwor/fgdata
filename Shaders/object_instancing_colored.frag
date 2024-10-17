// -*-C++-*-
#version 120

// Based on model-ALS-base.frag, with one-liner addition
// for mixing color with existing color.

varying vec4 instanceColor;

uniform sampler2D texture;

void render_model_ALS_base(in vec4 texel);

void main()
{
    vec4 texel = texture2D(texture, gl_TexCoord[0].st);

    // Mix instance color with default color
    texel.rgb = (1 - instanceColor.a) * texel.rgb + instanceColor.a * instanceColor.rgb;

    render_model_ALS_base(texel);
}

