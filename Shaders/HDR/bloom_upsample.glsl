/*
 * Bloom - upsampling function
 * "Next Generation Post Processing in Call of Duty Advanced Warfare"
 *      ACM Siggraph (2014)
 * Based on the implementation by Alexander Christensen
 * https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom
 */

#version 330 core

uniform sampler2D prev_bloom_tex;
uniform float filter_radius;

uniform float fg_AspectRatio;

vec3 bloom_upsample(vec2 uv)
{
    // The filter does not map to pixels, has "holes" in it. Its radius also
    // varies across mip resolutions.
    float x = filter_radius;
    float y = filter_radius * fg_AspectRatio;

    // Take 9 samples around current texel:
    // a - b - c
    // d - e - f
    // g - h - i
    // === ('e' is the current texel) ===
    vec3 a = texture(prev_bloom_tex, vec2(uv.x - x, uv.y + y)).rgb;
    vec3 b = texture(prev_bloom_tex, vec2(uv.x,     uv.y + y)).rgb;
    vec3 c = texture(prev_bloom_tex, vec2(uv.x + x, uv.y + y)).rgb;

    vec3 d = texture(prev_bloom_tex, vec2(uv.x - x, uv.y)).rgb;
    vec3 e = texture(prev_bloom_tex, vec2(uv.x,     uv.y)).rgb;
    vec3 f = texture(prev_bloom_tex, vec2(uv.x + x, uv.y)).rgb;

    vec3 g = texture(prev_bloom_tex, vec2(uv.x - x, uv.y - y)).rgb;
    vec3 h = texture(prev_bloom_tex, vec2(uv.x,     uv.y - y)).rgb;
    vec3 i = texture(prev_bloom_tex, vec2(uv.x + x, uv.y - y)).rgb;

    // Apply weighted distribution, by using a 3x3 tent filter:
    //  1   | 1 2 1 |
    // -- * | 2 4 2 |
    // 16   | 1 2 1 |
    vec3 upsample = e * 4.0;
    upsample += (b+d+f+h) * 2.0;
    upsample += (a+c+g+i);
    upsample /= 16.0;

    return upsample;
}
