/*
 * This is a library of noise functions, taking a coordinate vector and
 * a wavelength as input and returning a number [0:1] as output.

 * - Noise2D() is 2d Perlin noise.
 * - Noise3D() is 3d Perlin noise.
 * - DotNoise2D() is sparse dot noise and takes a dot density parameter.
 * - DropletNoise2D() is sparse dot noise modified to look like liquid and
 *   takes a dot density parameter.
 * - VoronoiNoise2D() is a function mapping the terrain into random domains,
 *   based on Voronoi tiling of a regular grid distorted with xrand and yrand.
 * - SlopeLines2D() computes a semi-random set of lines along the direction of
 *   steepest descent, allowing to simulate e.g. water erosion patterns.
 * - Strata3D() computes a vertically stratified random pattern, appropriate
 *   e.g. for rock textures
 *
 * Thorsten Renk 2014
 */

#version 330 core

float rand_1d(float n)
{
    return fract(sin(n) * 43758.5453123);
}

float rand_2d(vec2 co)
{
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

float rand_3d(vec3 co)
{
    return fract(sin(dot(co.xyz, vec3(12.9898,78.233,144.7272))) * 43758.5453);
}

float cosine_interpolate(float a, float b, float x)
{
    float ft = x * 3.1415927;
    float f = (1.0 - cos(ft)) * 0.5;
    return a * (1.0 - f) + b * f;
}

float simple_interpolate(float a, float b, float x)
{
    return a + smoothstep(0.0, 1.0, x) * (b - a);
}

float interpolated_noise_2d(vec2 coord)
{
    float x = coord.x;
    float y = coord.y;

    float integer_x    = x - fract(x);
    float fractional_x = x - integer_x;

    float integer_y    = y - fract(y);
    float fractional_y = y - integer_y;

    float v1 = rand_2d(vec2(integer_x,       integer_y));
    float v2 = rand_2d(vec2(integer_x + 1.0, integer_y));
    float v3 = rand_2d(vec2(integer_x,       integer_y + 1.0));
    float v4 = rand_2d(vec2(integer_x + 1.0, integer_y + 1.0));

    float i1 = simple_interpolate(v1, v2, fractional_x);
    float i2 = simple_interpolate(v3, v4, fractional_x);

    return simple_interpolate(i1, i2, fractional_y);
}

float interpolated_noise_3d(vec3 coord)
{
    float x = coord.x;
    float y = coord.y;
    float z = coord.z;

    float integer_x    = x - fract(x);
    float fractional_x = x - integer_x;

    float integer_y    = y - fract(y);
    float fractional_y = y - integer_y;

    float integer_z    = z - fract(z);
    float fractional_z = z - integer_z;

    float v1 = rand_3d(vec3(integer_x,       integer_y,       integer_z));
    float v2 = rand_3d(vec3(integer_x + 1.0, integer_y,       integer_z));
    float v3 = rand_3d(vec3(integer_x,       integer_y + 1.0, integer_z));
    float v4 = rand_3d(vec3(integer_x + 1.0, integer_y + 1.0, integer_z));

    float v5 = rand_3d(vec3(integer_x,       integer_y,       integer_z + 1.0));
    float v6 = rand_3d(vec3(integer_x + 1.0, integer_y,       integer_z + 1.0));
    float v7 = rand_3d(vec3(integer_x,       integer_y + 1.0, integer_z + 1.0));
    float v8 = rand_3d(vec3(integer_x + 1.0, integer_y + 1.0, integer_z + 1.0));

    float i1 = simple_interpolate(v1, v5, fractional_z);
    float i2 = simple_interpolate(v2, v6, fractional_z);
    float i3 = simple_interpolate(v3, v7, fractional_z);
    float i4 = simple_interpolate(v4, v8, fractional_z);

    float ii1 = simple_interpolate(i1, i2, fractional_x);
    float ii2 = simple_interpolate(i3, i4, fractional_x);

    return simple_interpolate(ii1, ii2, fractional_y);
}

float noise_2d(vec2 coord, float wavelength)
{
    return interpolated_noise_2d(coord / wavelength);
}

float noise_3d(vec3 coord, float wavelength)
{
    return interpolated_noise_3d(coord / wavelength);
}

float voronoi_noise_2d(vec2 coord, float xrand, float yrand)
{
    float x = coord.x;
    float y = coord.y;

    float integer_x    = x - fract(x);
    float fractional_x = x - integer_x;

    float integer_y    = y - fract(y);
    float fractional_y = y - integer_y;

    float val[4];
    val[0] = rand_2d(vec2(integer_x, integer_y));
    val[1] = rand_2d(vec2(integer_x+1.0, integer_y));
    val[2] = rand_2d(vec2(integer_x, integer_y+1.0));
    val[3] = rand_2d(vec2(integer_x+1.0, integer_y+1.0));

    float xshift[4];
    xshift[0] = xrand * (rand_2d(vec2(integer_x+0.5, integer_y)) - 0.5);
    xshift[1] = xrand * (rand_2d(vec2(integer_x+1.5, integer_y)) -0.5);
    xshift[2] = xrand * (rand_2d(vec2(integer_x+0.5, integer_y+1.0))-0.5);
    xshift[3] = xrand * (rand_2d(vec2(integer_x+1.5, integer_y+1.0))-0.5);

    float yshift[4];
    yshift[0] = yrand * (rand_2d(vec2(integer_x, integer_y +0.5)) - 0.5);
    yshift[1] = yrand * (rand_2d(vec2(integer_x+1.0, integer_y+0.5)) -0.5);
    yshift[2] = yrand * (rand_2d(vec2(integer_x, integer_y+1.5))-0.5);
    yshift[3] = yrand * (rand_2d(vec2(integer_x+1.5, integer_y+1.5))-0.5);

    float dist[4];
    dist[0] = sqrt((fractional_x + xshift[0]) * (fractional_x + xshift[0]) + (fractional_y + yshift[0]) * (fractional_y + yshift[0]));
    dist[1] = sqrt((1.0 -fractional_x + xshift[1]) * (1.0-fractional_x+xshift[1]) + (fractional_y +yshift[1]) * (fractional_y+yshift[1]));
    dist[2] = sqrt((fractional_x + xshift[2]) * (fractional_x + xshift[2]) + (1.0-fractional_y +yshift[2]) * (1.0-fractional_y + yshift[2]));
    dist[3] = sqrt((1.0-fractional_x + xshift[3]) * (1.0-fractional_x + xshift[3]) + (1.0-fractional_y +yshift[3]) * (1.0-fractional_y + yshift[3]));

    int i_min;
    float dist_min = 100.0;
    for (int i = 0; i < 4; ++i) {
        if (dist[i] < dist_min) {
            dist_min = dist[i];
            i_min = i;
        }
    }
    return val[i_min];
}

float voronoi_noise_2d(vec2 coord, float wavelength, float xrand, float yrand)
{
    return voronoi_noise_2d(coord / wavelength, xrand, yrand);
}

/*
 * 3D Simplex noise by Ian McEwan, Ashima Arts.
 * Copyright (C) 2011 Ashima Arts. All rights reserved.
 * Distributed under the MIT License.
 * https://github.com/ashima/webgl-noise
 */

vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289(((x*34.0)+10.0)*x);
}

vec4 taylor_inv_sqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise_3d(vec3 v)
{
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i  = floor(v + dot(v, C.yyy) );
    vec3 x0 =   v - i + dot(i, C.xxx) ;

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min( g.xyz, l.zxy );
    vec3 i2 = max( g.xyz, l.zxy );

    //   x0 = x0 - 0.0 + 0.0 * C.xxx;
    //   x1 = x0 - i1  + 1.0 * C.xxx;
    //   x2 = x0 - i2  + 2.0 * C.xxx;
    //   x3 = x0 - 1.0 + 3.0 * C.xxx;
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
    vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

    // Permutations
    i = mod289(i);
    vec4 p = permute( permute( permute(
                                   i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
                               + i.y + vec4(0.0, i1.y, i2.y, 1.0 ))
                      + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float n_ = 0.142857142857; // 1.0/7.0
    vec3  ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4( x.xy, y.xy );
    vec4 b1 = vec4( x.zw, y.zw );

    //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
    //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

    vec3 p0 = vec3(a0.xy,h.x);
    vec3 p1 = vec3(a0.zw,h.y);
    vec3 p2 = vec3(a1.xy,h.z);
    vec3 p3 = vec3(a1.zw,h.w);

    //Normalise gradients
    vec4 norm = taylor_inv_sqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.5 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 105.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1),
                                   dot(p2,x2), dot(p3,x3) ) );
}
