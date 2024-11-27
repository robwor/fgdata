#version 410 core

layout (quads, fractional_odd_spacing, ccw) in;

in TCS_OUT {
    vec2 p2d_ls;
    vec2 p2d_ws;
    vec2 texcoord;
} tes_in[];

patch in mat4 patch_heights;

out TES_OUT {
    float flogz;
    vec2 texcoord;
    vec2 p2d_ls;
    vec3 view_vector;
    vec3 vertex_normal;
    float steepness;
} tes_out;

uniform mat4 osg_ModelViewMatrix;
uniform mat4 osg_ModelViewProjectionMatrix;
uniform mat3 osg_NormalMatrix;
uniform mat4 fg_zUpTransform;

// XXX: This should be passed as an uniform and depend on the landclass
const vec4 noise_amplitudes = vec4(5.0, 2.0, 1.0, 0.5) * 3.0;

// noise.glsl
float noise_2d(vec2 coord, float wavelength);
// logarithmic_depth.glsl
float logdepth_prepare_vs_depth(float z);

/*
 * Bilinearly interpolate between four 2D points according to a weight 'uv'.
 * When uv = [0,0], the bottom left corner p00 is returned. When uv = [1,1],
 * the top right corner p11 is returned.
 */
vec2 bilinear_interp_2d(vec2 p00, vec2 p01, vec2 p10, vec2 p11, vec2 uv)
{
    vec2 a = mix(p00, p10, uv.x);
    vec2 b = mix(p01, p11, uv.x);
    return mix(a, b, uv.y);
}

/*
 * Return the Catmull-Rom basis vector for a parameter 't' (0 <= t <= 1).
 */
vec4 catmull_rom_interp_basis(float t)
{
    // Catmull-Rom basis matrix for tau=0.5
    const mat4 catmull_rom_basis_M = mat4(0.0, -0.5,  1.0, -0.5,
                                          1.0,  0.0, -2.5,  1.5,
                                          0.0,  0.5,  2.0, -1.5,
                                          0.0,  0.0, -0.5,  0.5);
    float tt = t*t;
    return vec4(1.0, t, tt, tt*t) * catmull_rom_basis_M;
}

/*
 * Do cubic interpolation using a Catmull-Rom spline defined by four control
 * points (components of 'p') and a basis vector.
 * The basis vector can be obtained with catmull_rom_interp_basis().
 */
float catmull_rom_interp(vec4 p, vec4 basis)
{
    return dot(p, basis);
}

vec2 local_point_at_uv(vec2 uv)
{
    vec2 p00 = tes_in[0].p2d_ls;
    vec2 p01 = tes_in[1].p2d_ls;
    vec2 p10 = tes_in[2].p2d_ls;
    vec2 p11 = tes_in[3].p2d_ls;
    return bilinear_interp_2d(p00, p01, p10, p11, uv);
}

vec2 world_point_at_uv(vec2 uv)
{
    vec2 p00 = tes_in[0].p2d_ws;
    vec2 p01 = tes_in[1].p2d_ws;
    vec2 p10 = tes_in[2].p2d_ws;
    vec2 p11 = tes_in[3].p2d_ws;
    return bilinear_interp_2d(p00, p01, p10, p11, uv);
}

vec2 texcoord_at_uv(vec2 uv)
{
    vec2 t00 = tes_in[0].texcoord;
    vec2 t01 = tes_in[1].texcoord;
    vec2 t10 = tes_in[2].texcoord;
    vec2 t11 = tes_in[3].texcoord;
    return bilinear_interp_2d(t00, t01, t10, t11, uv);
}

float apply_noise(float h, vec2 p)
{
    vec4 noise_vec = vec4(noise_2d(p, 50.0),
                          noise_2d(p, 20.0),
                          noise_2d(p, 10.0),
                          noise_2d(p, 5.0));
    noise_vec -= 0.5; // So the average height is still the same
    noise_vec *= noise_amplitudes;
    return h + noise_vec.x + noise_vec.y + noise_vec.z + noise_vec.w;
}

float height_at_uv(vec2 uv, vec2 p)
{
    vec4 u_basis = catmull_rom_interp_basis(uv.x);
    vec4 v_basis = catmull_rom_interp_basis(uv.y);
    vec4 hu;
    hu.x = catmull_rom_interp(patch_heights[0], u_basis);
    hu.y = catmull_rom_interp(patch_heights[1], u_basis);
    hu.z = catmull_rom_interp(patch_heights[2], u_basis);
    hu.w = catmull_rom_interp(patch_heights[3], u_basis);
    float h = catmull_rom_interp(hu, v_basis);
    return apply_noise(h, p);
}

void main()
{
    vec2 uv    = vec2(gl_TessCoord.xy);
    vec2 uv_dx = vec2(gl_TessCoord.xy + vec2(0.001, 0.0));
    vec2 uv_dy = vec2(gl_TessCoord.xy + vec2(0.0, 0.001));

    vec2 texcoord = texcoord_at_uv(uv);

    vec2 p2d_ls    = local_point_at_uv(uv);
    vec2 p2d_ls_dx = local_point_at_uv(uv_dx);
    vec2 p2d_ls_dy = local_point_at_uv(uv_dy);

    vec2 p2d_ws    = world_point_at_uv(uv);
    vec2 p2d_ws_dx = world_point_at_uv(uv_dx);
    vec2 p2d_ws_dy = world_point_at_uv(uv_dy);

    float h    = height_at_uv(uv,    p2d_ws);
    float h_dx = height_at_uv(uv_dx, p2d_ws_dx);
    float h_dy = height_at_uv(uv_dy, p2d_ws_dy);

    vec3 p    = vec3(p2d_ls,    h);
    vec3 p_dx = vec3(p2d_ls_dx, h_dx);
    vec3 p_dy = vec3(p2d_ls_dy, h_dy);

    vec3 bitangent = normalize(p_dx - p);
    vec3 tangent = normalize(p_dy - p);
    vec3 normal = normalize(cross(bitangent, tangent));

    float steepness = dot(vec3(0.0, 0.0, 1.0), normal);

    // TODO: Get rid of the Z-Up transforms
    gl_Position = osg_ModelViewProjectionMatrix * inverse(fg_zUpTransform) * vec4(p, 1.0);
    tes_out.flogz = logdepth_prepare_vs_depth(gl_Position.w);
    tes_out.texcoord = texcoord;
    tes_out.p2d_ls = p2d_ls;
    tes_out.view_vector = vec3(osg_ModelViewMatrix * inverse(fg_zUpTransform) * vec4(p, 1.0));
    tes_out.vertex_normal = osg_NormalMatrix * vec3(inverse(fg_zUpTransform) * vec4(normal, 0.0));
    tes_out.steepness = steepness;
}
