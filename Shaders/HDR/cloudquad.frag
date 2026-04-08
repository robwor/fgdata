$FG_GLSL_VERSION

layout(location = 0) out vec4 fragColor;

in vec2 texcoord;
in vec2 raw_texcoord; // QUAD_TEXCOORD_RAW
in vec3 w_pos;

uniform sampler3D detailed_tex;
uniform sampler3D rough_tex;
uniform sampler3D shade_tex;
uniform sampler2D depth_tex;
uniform sampler3D cloud_noise_tex;
uniform sampler1D wind_offset_tex;

uniform vec3 fg_SunDirectionWorld;
uniform vec3 fg_CameraPositionCart;
uniform float fg_AspectRatio;
uniform mat4 fg_CameraZUpMatrix;
uniform mat4 fg_ViewMatrix[FG_NUM_VIEWS];

FG_VIEW_GLOBAL
uniform mat4 fg_ViewMatrixInverse[FG_NUM_VIEWS];
uniform vec4 fg_Viewport[FG_NUM_VIEWS];
uniform uint osg_FrameNumber;

uniform vec3 cloud_field_center;
uniform bool cloud_field_repeating;
uniform bool cloud_field_mirror_u;
uniform bool cloud_field_mirror_v;
uniform float cloud_base_z_norm;
uniform float voxel_resolution_m;
uniform int voxel_field_width;
uniform int voxel_field_height;
uniform float active_voxel_field_height_norm;
uniform int rough_field_factor;
uniform int rough_size_factor;
uniform float ambient_intensity_scale;
uniform float direct_intensity_scale;

uniform vec4 ground_albedo;

// math.glsl
float M_1_4PI();
float safe_sqrt(float x);
mat3 getRotateRollPitchYaw(vec3 rpw);

// exposure.glsl
vec3 apply_exposure(vec3 color);

// logarithmic_depth.glsl
float logdepth_prepare_vs_depth(float z);
float logdepth_decode(float z);
float logdepth_encode(float z);

// sun.glsl
vec3 get_sun_radiance_sea_level();

// pos_from_depth.glsl
vec3 get_view_space_from_depth(vec2 uv, float depth);

// aerial_perspective.glsl
vec3 add_aerial_perspective(vec3 color, vec2 raw_coord, vec3 P);

const float MIN_DIST = 0.0001;
const float MAX_DIST = 4.0;
const float EPSILON = 0.000001;
const float NOISE_SCALE = 48.0;
const float NOISE_SKIP_THRESHOLD = 0.95;
const int MAX_LIGHT_STEPS = 5;

int MAX_MARCHING_STEPS = 4 * voxel_field_width;
float IN_CLOUD_STEP_SIZE = 0.1f / float(voxel_field_width);
float IN_CLOUD_SUN_RAY_STEP_SIZE = 1.0 / float(voxel_field_width);
float VOXEL_FIELD_WIDTH_M = float(voxel_field_width * voxel_resolution_m);
float VOXEL_FIELD_HEIGHT_M = float(voxel_field_height * voxel_resolution_m);

// Scaling factor to account for the voxel space not being a cube.
vec3 VOXEL_SCALE = vec3(1.0, 1.0, float(voxel_field_width) / float(voxel_field_height));
vec3 EYE_SCALE = vec3(VOXEL_FIELD_WIDTH_M, VOXEL_FIELD_WIDTH_M, VOXEL_FIELD_HEIGHT_M);

// Boundary where we use the detailed voxel space rather than the rough voxel space in UV coordinates
float DETAILED_X_Y_BOUNDARY = 0.5 / float(rough_field_factor);

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

//
// Function to erode a value given an erosion amount. A simplified version of SetRange.
//
float ValueErosion(float inValue, float inOldMin)
{
	float old_min_max_range = (1.0 - inOldMin);
	return clamp((inValue - inOldMin) / old_min_max_range, 0.0, 1.0);
}

// HenyeyGreenstein forward phase scattering
float HenyeyGreenstein(float inCosAngle, float inG)
{
    float num = 1.0 - inG * inG;
    float denom = 1.0 + inG * inG - 2.0 * inG * inCosAngle;
    float rsqrt_denom = safe_sqrt(denom);
    return num * rsqrt_denom * rsqrt_denom * rsqrt_denom * M_1_4PI();
}

/**
 * Get cloud information for a given sample point, using either the detailed
 * or rough data as appropriate
 */
vec4 getCloud(vec3 samplePoint, vec3 dir)  {
    // If outside the voxel space then calculate an SDF directly.  This is basically the
    // z coordinate - 1.0, plus a little bit to ensure it ends up within the voxel space.
    if (samplePoint.z < 0.0) return vec4(0.0,0.0,0.0, -samplePoint.z / length(dir));
    if (samplePoint.z > 1.0) return vec4(0.0,0.0,0.0, (samplePoint.z - 1.0) / length(dir));

    if (cloud_field_repeating) {
        // The repeating cloud field uses mirrored repeating textures to ensure the SDF is valid
        // at the edges.  We also shift the cloud center by integer UV values to handle the curvature 
        // We need to compensate for that mirroring here.
        if (cloud_field_mirror_u) samplePoint.x = (1.0 - samplePoint.x);
        if (cloud_field_mirror_v) samplePoint.y = (1.0 - samplePoint.y);
        return texture(detailed_tex, samplePoint);
    }

    if ((abs(samplePoint.x - 0.5) < DETAILED_X_Y_BOUNDARY) && (abs(samplePoint.y - 0.5) < DETAILED_X_Y_BOUNDARY)) {
        // We're in the detailed space.  Scale the xy UV to the detailed voxel space
        vec3 uv = vec3((samplePoint.x - DETAILED_X_Y_BOUNDARY) * float(rough_field_factor),
                       (samplePoint.y - DETAILED_X_Y_BOUNDARY) * float(rough_field_factor),
                        samplePoint.z);
        return texture(detailed_tex, uv);
    } else {
        // We're in the rough space, so just use it as-is
        return texture(rough_tex, samplePoint);
    }
}

/**
 * Calculate the density of a given samplePoint
 */
float calculateDensity(vec3 samplePoint, vec3 dir, vec4 cloud) {
    float cloudDimension = cloud.x;
    float cloudType = cloud.y;
    float cloudDensity = cloud.z;

    if (cloudDimension > NOISE_SKIP_THRESHOLD) return cloudDensity * cloudDimension; // Skip expensive noise if we're deep inside cloud

    if (cloudDimension > 0.0) {
        vec4 noise = texture(cloud_noise_tex, samplePoint * NOISE_SCALE / VOXEL_SCALE);
        float wispy_noise = mix(noise.r, noise.g, cloudDimension);

        // Define billowy noise 
        float billowy_type_gradient = sqrt(sqrt(cloudDimension));
        float billowy_noise = mix(noise.b * 0.3, noise.a * 0.3, billowy_type_gradient);

        // Define Noise composite: blend to wispy depending on the cloud type
        float noise_composite = mix(wispy_noise, billowy_noise, cloudType);        

        // Ultra-HF noise.
        //float hhf_wisps = 1.0 - pow(abs(abs(noise.g * 2.0 - 1.0) * 2.0 - 1.0), 4.0);
        //float hhf_billows = pow(abs(abs(noise.a * 2.0 - 1.0) * 2.0 - 1.0), 2.0);        
        //float hhf_noise_composite = mix(hhf_wisps, hhf_billows, cloudType);        
        //noise_composite = mix(hhf_noise_composite, noise_composite, depth * 10.0);

        float uprezzed_density = noise_composite;        

        // Composite Noises and use as a Value Erosion
        float dim = cloudDimension;
        dim = smoothstep(0.0, 1.0, dim);
        uprezzed_density = ValueErosion(dim * dim, noise_composite);        

        // Apply User Density Scale Data to Result
        uprezzed_density *= cloudDensity; 
            
        // Sharpen result
        float powered_density_scale = pow(clamp(cloudDensity, 0.0, 1.0), 4.0);
        uprezzed_density = pow(uprezzed_density, mix(0.3, 0.6, max(EPSILON, powered_density_scale)));

        return uprezzed_density;
    } else {
        // This is an error case, and shouldn't happen.
        return 0.0;
    }
}

float getRayDensity(vec3 eye, vec3 marchingDirection, float start, float end) {
    float density = 0.0;
    float distance = start;
    vec3 p = eye + distance * marchingDirection;
    vec3 windOffset = texture(wind_offset_tex, p.z).xyz;

    float storedTransmittance = texture(shade_tex, p + windOffset).r;

    // If already heavily shadowed, skip local march
    if (storedTransmittance < 0.15)
    {
        return -log(max(storedTransmittance, 0.0001));
    }

    //return texture(shade_tex, p).r;

    for (int i = 0; i < MAX_LIGHT_STEPS; i++) {
        p = eye + distance * marchingDirection;
        windOffset = texture(wind_offset_tex, p.z).xyz;

        if (p.z > active_voxel_field_height_norm) return density; // Reached the top of the actual cloud space

        vec4 t = getCloud(p + windOffset, marchingDirection);

        if (t.a < EPSILON) {
            // Inside a cloud, so add density
            density  += calculateDensity(p + windOffset, marchingDirection, t);
            distance += IN_CLOUD_SUN_RAY_STEP_SIZE;
        } else {
            distance += t.a;
        }

        if (density > 0.99) {
            // Reached maximum density, so no point in marching further.
			return 1.0;
        }
        if (distance > end) {
            // Reached the end of the raymarch.
            return density;
        }
    }

    // At this point just look up the pre-calculated shade texture
    p = eye + (distance + IN_CLOUD_SUN_RAY_STEP_SIZE) * marchingDirection;

    density = clamp(1.0 - storedTransmittance + density, 0.0, 1.0);    
    return density;
}


/**
 * Absolute value of the SDF value indicates the distance to the surface.
 * Sign indicates whether the point is inside or outside the surface,
 * negative indicating inside.
 */

struct sample_information {
    float sdf;
    float density;
    float direct_scattering;
    float ambient_scattering;
};

struct ray_data {
    float light_absorption;
    float direct_intensity;
    float ambient_intensity;
    float first_hit;
};

ray_data cloudRayMarch(vec3 eye, vec3 marchingDirection, float start, float end) {
    
    ray_data lreturn;
    lreturn.light_absorption = 0.0;
    lreturn.direct_intensity = 0.0;
    lreturn.ambient_intensity = 0.0;
    lreturn.first_hit = -1.0;
    
    float dirZ = marchingDirection.z;

    // -------------------------------------------------------
    // Intersect ray with Z slab [0, active_voxel_field_height_norm]
    // -------------------------------------------------------
    float tEnter = start;
    float tExit  = end;

    if (abs(dirZ) > EPSILON) {
        float t0 = (0.0 - eye.z) / dirZ;
        float t1 = (active_voxel_field_height_norm - eye.z) / dirZ;

        float slabEnter = min(t0, t1);
        float slabExit  = max(t0, t1);

        tEnter = max(start, slabEnter);
        tExit  = min(end, slabExit);
    } else {
        if (eye.z < 0.0 || eye.z > active_voxel_field_height_norm)
            return lreturn;
    }

    if (tExit <= tEnter)
        return lreturn;

    // -------------------------------------------------------
    // Standard raymarch, now guaranteed inside slab.
    // Calculate some dynamic limits and step sizes.
    // -------------------------------------------------------        

    // Stable per-pixel jitter (screen-space stable)
    float jitter = hash12(gl_FragCoord.xy);
    float stepSize = IN_CLOUD_STEP_SIZE;
    // Offset initial march position slightly
    float distance = tEnter + jitter * stepSize;

    float maxTravel = tExit - tEnter;

    int dynamicMaxSteps = int(maxTravel / IN_CLOUD_STEP_SIZE) + 1;
    dynamicMaxSteps = min(dynamicMaxSteps, MAX_MARCHING_STEPS);

    float cachedSunDensity = -1.0;
    float cachedDensity = -1.0;

    for (int i = 0; i < dynamicMaxSteps; i++) {

        if (distance >= tExit) return lreturn; // Reached the end of the raymarch

        vec3 p = eye + distance * marchingDirection;
        vec3 windOffset = texture(wind_offset_tex, p.z).xyz;

        sample_information s;

        vec4 cloud = getCloud(p + windOffset, marchingDirection);

        s.sdf = cloud.a;
        s.density = 0.0;
        s.direct_scattering = 0.0;
        s.ambient_scattering = 0.0;

        if (s.sdf < EPSILON)
        {
            s.density = calculateDensity(p + windOffset, marchingDirection, cloud);
            s.sdf = IN_CLOUD_STEP_SIZE;

            mat3 zup = mat3(fg_CameraZUpMatrix);

            // sample -> camera
            vec3 V = normalize(eye - p);

            // fg_SunDirectionWorld points FROM sun TOWARD world (incident direction)
            // Negate to get FROM sample TOWARD sun
            vec3 toSunDir = normalize(zup * -fg_SunDirectionWorld);
            float sunElevation = clamp(-toSunDir.z, 0.0, 1.0);

            // Smooth transition through twilight
            float dayFactor = smoothstep(0.0, 0.1, sunElevation);

            // cosTheta > 0 = looking toward sun (forward scatter)
            // cosTheta < 0 = looking away from sun (back scatter)
            float cosTheta = clamp(dot(V, toSunDir), -1.0, 1.0);

            // March from sample toward sun
            vec3 sunDirMarch = -normalize(toSunDir / EYE_SCALE) * VOXEL_SCALE;
            float densityToSun;

            // Cache density information and save on expensive ray cast when the cloud density hasn't
            // changed much.  This is a major performance bottleneck.
            if (cachedSunDensity < 0.0 || abs(s.density - cachedDensity) > 0.02) {
                densityToSun = getRayDensity(p, sunDirMarch,
                                            IN_CLOUD_SUN_RAY_STEP_SIZE,
                                            1.0);

                cachedSunDensity = densityToSun;
                cachedDensity = s.density;            
            } else {
                densityToSun = cachedSunDensity;
            }

            float transmittance = exp(-densityToSun);

            float phaseForward  = HenyeyGreenstein(cosTheta,  0.7);
            float phaseBackward = HenyeyGreenstein(cosTheta, -0.4);
            float phase = mix(phaseBackward, phaseForward, 0.6);

            // Silver lining
            float rim = pow(clamp(1.0 + cosTheta, 0.0, 1.0), 6.0);
            phase += rim * 0.15;            

            // Raise transmittance to a power to increase contrast between lit and shadowed faces
            float contrastTransmittance = pow(transmittance, 2.0);
            float singleScatter = contrastTransmittance * phase * s.density;
            //float singleScatter = transmittance * phase * s.density;

            // multiScatter is indirect/diffuse - should be ambient colored, not sun colored
            float multiScatter =
                (1.0 - transmittance) *
                0.20 *
                (0.3 + 0.7 * s.density) *
                s.density;

            s.direct_scattering = singleScatter;  // sun colored - only direct scatter

            float skyTransmittance = texture(shade_tex, p).g;
            float dimensionalProfile = cloud.r;

            // ambient gets both sky terms AND the indirect multiple scatter
            float skyAmbient = pow(1.0 - dimensionalProfile, 0.5) * skyTransmittance;
            float groundBounce = (1.0 - skyTransmittance) * (1.0 - p.z) * 0.2;
            float multiScatterAmbient = 0.05 * dimensionalProfile;
            s.ambient_scattering = (skyAmbient + groundBounce + multiScatterAmbient + multiScatter) * dayFactor;
        }

        if (s.density > 0.0) {
            float occlusion = (1.0 - clamp(lreturn.light_absorption, 0.0, 1.0));
            lreturn.light_absorption  += s.density * occlusion;
            lreturn.direct_intensity  += s.direct_scattering * occlusion;  // density already in singleScatter
            lreturn.ambient_intensity += s.ambient_scattering * s.density;
            if (lreturn.first_hit < 0.0) lreturn.first_hit = distance;
        }

        if (lreturn.light_absorption > 0.98) {
            // Reached maximum density or end of ray so no point in marching further.
            lreturn.light_absorption = 1.0;
			return lreturn;
        }

        distance += s.sdf;
    }

	return lreturn;
}

void main()
{
    mat3 zup = mat3(fg_CameraZUpMatrix);
    vec3 wdir = w_pos - fg_CameraPositionCart;
    vec3 dir = normalize(zup * wdir) * VOXEL_SCALE; // Take into account that the voxel space is not a cube by increasing the Z-factor
    float zscaleFactor = length(dir);

    // Get a Z-up eyepoint relative to the center of the cloud field in the X-Y plane, and offset to place the bottom of the field at the cloudbase.
    vec3 eye = (zup * (fg_CameraPositionCart - cloud_field_center)) / EYE_SCALE + vec3(0.5, 0.5, - cloud_base_z_norm);
    vec4 color = vec4(0.0, 0.0, 0.0, 0.0);

    // Convert the logarithmic depth value into metres, and then scale to the voxel resolution 
    // so we know how far to search before we reach something solid.  This needs to take into account that the voxel space is not a cube by adjusting for the
    // actual length of the "normalized" direction.
    float max_depth_m = logdepth_decode(texture(depth_tex, texcoord).r);
    float max_depth_vx = min(max_depth_m / VOXEL_FIELD_WIDTH_M, MAX_DIST) * zscaleFactor;

    ray_data ray = cloudRayMarch(eye, dir, MIN_DIST, max_depth_vx);
    
    if (ray.light_absorption > 0.01) {
        color.rgb = get_sun_radiance_sea_level() * ray.direct_intensity * direct_intensity_scale
                                     + vec3(1.0) * ray.ambient_intensity * ambient_intensity_scale;
        color.a = ray.light_absorption;

        float z = logdepth_prepare_vs_depth(ray.first_hit * VOXEL_FIELD_WIDTH_M / zscaleFactor);
        gl_FragDepth = logdepth_encode(z);

        // Add aerial perspective
        vec3 P = get_view_space_from_depth(texcoord, gl_FragDepth);
        color.rgb = add_aerial_perspective(color.rgb, raw_texcoord, P);
    } else {
        gl_FragDepth = 1.0;
    }
    
    // Only pre-expose when not rendering to the environment map.
    // We want the non-exposed radiance values for IBL.
    color.rgb = apply_exposure(color.rgb);
    fragColor = color;
}