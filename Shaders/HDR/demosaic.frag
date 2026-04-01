$FG_GLSL_VERSION

layout(location = 0) out vec3 fragColor;

in vec2 texcoord;

uniform sampler2D hdr_tex;
uniform sampler2D gbuffer1_tex;
uniform sampler2D depth_tex;
uniform sampler2D clouds;
uniform sampler2D clouds_depth_tex;

vec3 addClouds(vec3 color, float depth, vec4 cloud_color, float cloud_depth)
{
    // Mix in the cloud texture
    if (cloud_depth <= depth)
        color = mix(color, cloud_color.rgb, cloud_color.a);

    return color;
}

void main()
{
    float neighbor_alpha = 0.0;
    // Check if we are dealing with a discarded pixel or an opaque pixel
    float test = fract(dot(gl_FragCoord.xy, vec2(0.5)));
    if (test < 0.5) {
        // This is a discarded (background) pixel. Bilinearly interpolate
        // between its (foreground) neighbors to obtain an alpha value for the
        // neighboring (foreground) pixel.
        neighbor_alpha += textureOffset(gbuffer1_tex, texcoord, ivec2(+1,  0)).a;
        neighbor_alpha += textureOffset(gbuffer1_tex, texcoord, ivec2( 0, +1)).a;
        neighbor_alpha += textureOffset(gbuffer1_tex, texcoord, ivec2(-1,  0)).a;
        neighbor_alpha += textureOffset(gbuffer1_tex, texcoord, ivec2( 0, -1)).a;
        neighbor_alpha *= 0.25;
    } else {
        // This is an "opaque" (foreground) pixel, with its own alpha. Invert
        // it to get an alpha value for the neighboring (background) pixel.
        neighbor_alpha = 1.0 - texture(gbuffer1_tex, texcoord).a;
        // However a foreground alpha value of 0.0, i.e. neighbor_alpha == 1.0
        // represents opaque (see gbuffer_pack.glsl). Force 1.0 to 0.0 so
        // opaque edges don't get dithered.
        neighbor_alpha = fract(neighbor_alpha);
    }

    // Calculate this pixel's color
    vec3 color = texture(hdr_tex, texcoord).rgb;
    float depth = texture(depth_tex, texcoord).r;
    vec4 cloud_color = texture(clouds, texcoord);
    float cloud_depth = texture(clouds_depth_tex, texcoord).r;
    color = addClouds(color, depth, cloud_color, cloud_depth);

    // Calculate the neighboring pixel's color
    vec3 neighbor_color = textureOffset(hdr_tex, texcoord, ivec2(1, 0)).rgb;
    float neighbor_depth = textureOffset(depth_tex, texcoord, ivec2(1, 0)).r;
    vec4 neighbor_cloud_color = textureOffset(clouds, texcoord, ivec2(1, 0));
    float neighbor_cloud_depth = textureOffset(clouds_depth_tex, texcoord, ivec2(1, 0)).r;
    neighbor_color = addClouds(neighbor_color, neighbor_depth, neighbor_cloud_color, neighbor_cloud_depth);

    // Linearly interpolate between this pixel's color and the neighbor's color
    // according to the alpha value.
    fragColor = mix(color, neighbor_color, neighbor_alpha);
}
