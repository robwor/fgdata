#version 330 core

layout(location = 0) out vec4 fragColor;

in VS_OUT {
    vec2 texcoord;
    vec3 vertex_normal;
    vec3 view_vector;
} fs_in;

uniform sampler2D color_tex;
uniform sampler2D normal_tex;
uniform sampler2D transmittance_tex;

uniform vec3 fg_SunDirection;
uniform float fg_CameraDistanceToEarthCenter;
uniform float fg_EarthRadius;
uniform vec3 fg_CameraViewUp;

const float ATMOSPHERE_RADIUS = 6471e3;

// math.glsl
float M_1_PI();
// color.glsl
vec3 eotf_inverse_sRGB(vec3 srgb);
// normalmap.glsl
vec3 perturb_normal(vec3 N, vec3 V, vec2 texcoord, sampler2D tex);
// atmos_spectral.glsl
vec4 get_sun_spectral_irradiance();
vec3 linear_srgb_from_spectral_samples(vec4 L);
// exposure.glsl
vec3 apply_exposure(vec3 color);

void main()
{
    vec3 albedo = eotf_inverse_sRGB(texture(color_tex, fs_in.texcoord).rgb);

    vec3 N = normalize(fs_in.vertex_normal);
    N = perturb_normal(N, fs_in.view_vector, fs_in.texcoord, normal_tex);

    float NdotL = max(dot(N, fg_SunDirection), 0.0);

    vec3 V = normalize(fs_in.view_vector);

    // Simple Lambertian BRDF
    vec3 color = albedo * M_1_PI() * NdotL
        * linear_srgb_from_spectral_samples(get_sun_spectral_irradiance());

    // Apply aerial perspective
    float normalized_altitude =
        (fg_CameraDistanceToEarthCenter - fg_EarthRadius)
        / (ATMOSPHERE_RADIUS - fg_EarthRadius);
    float cos_theta = dot(-V, fg_CameraViewUp);

    vec2 uv = vec2(cos_theta * 0.5 + 0.5, clamp(normalized_altitude, 0.0, 1.0));
    vec4 transmittance = texture(transmittance_tex, uv);

    // The proper thing would be to have spectral albedo data for the moon,
    // but that's too much work for little return. Just approximate the
    // transmittance by taking the average of the four spectral samples.
    color *= dot(transmittance, vec4(0.25));

    // Pre-expose
    color = apply_exposure(color);

    // Final color = transmittance * moon color + sky inscattering
    // In this frag shader we output the multiplication part, and the sky
    // in-scattering is added by doing additive blending on top of the skydome.
    fragColor = vec4(color, 1.0);
}
