$FG_GLSL_VERSION

/*
 * Currently clouds aren't rendered to envmap so only stubs are required that
 * write to the one color attachment.
 */
layout(location = 0) out vec4 fragColor;

void forward_pack_background(vec4 color)
{
    fragColor = color;
}

void forward_pack(vec4 color, float flogz)
{
    fragColor = color;
}
