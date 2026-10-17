#version 330 core

layout(location = 0) in vec2 pos;
layout(location = 1) in vec2 textureUV;

out vec2 texImageCoord;
out vec2 paintCoord;

uniform mat4 sh_Mvp;
uniform mat3 paintInverted;

void main()
{
    gl_Position = sh_Mvp * vec4(pos, 0.0, 1.0);
    texImageCoord = textureUV;
    paintCoord = (paintInverted * vec3(pos, 1.0)).xy;
}
