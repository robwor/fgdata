#version 330 core

layout(location = 0) out vec4 fragColor;

in VS_OUT {
    vec4 color;
    vec3 view_vector;
} fs_in;

uniform sampler2D transmittance_tex;

uniform float max_radiance;

uniform float fg_CameraDistanceToEarthCenter;
uniform float fg_EarthRadius;
uniform vec3 fg_CameraViewUp;

const float ATMOSPHERE_RADIUS = 6471e3;

// exposure.glsl
vec3 apply_exposure(vec3 color);

void main()
{
    vec3 color = fs_in.color.rgb * fs_in.color.a * max_radiance;

    vec3 V = normalize(fs_in.view_vector);

    // Apply aerial perspective
    float normalized_altitude =
        (fg_CameraDistanceToEarthCenter - fg_EarthRadius)
        / (ATMOSPHERE_RADIUS - fg_EarthRadius);
    float cos_theta = dot(-V, fg_CameraViewUp);

    vec2 uv = vec2(cos_theta * 0.5 + 0.5, clamp(normalized_altitude, 0.0, 1.0));
    vec4 transmittance = texture(transmittance_tex, uv);

    // The proper thing would be to have spectral data for the stars' radiance.
    // This could be approximated by taking the star's temperature and using
    // Plank's law to obtain the spectral radiance for our 4 wavelengths.
    // That's too complicated for now, so instead we just average the four
    // spectral samples from the atmospheric transmittance.
    color *= dot(transmittance, vec4(0.25));

    // Pre-expose
    color = apply_exposure(color);

    // Final color = transmittance * star radiance + sky inscattering
    // In this frag shader we output the multiplication part, and the sky
    // in-scattering is added by doing additive blending on top of the skydome.
    fragColor = vec4(color, 1.0);
}
