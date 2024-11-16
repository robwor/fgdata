#version 330 core

const float num_bins = 254.0; // 256 - 2
const float inv_num_bins = 1.0 / num_bins;

// Human eye can see around 10-14 stops
// https://www.cambridgeincolour.com/tutorials/cameras-vs-human-eye.htm
const float log_lum_range = 12.0;

const float min_log_lum_offset = -log_lum_range * 0.5;
const float inv_log_lum_range = 1.0 / log_lum_range;

/*
 * Get the log2 luminance that corresponds to the 0th bin. We do a sliding
 * histogram, i.e. the minimum and maximum luminance in the histogram vary
 * depending on the adapted luminance.
 */
float get_min_log_lum(float adapted_luminance)
{
    return log2(adapted_luminance) + min_log_lum_offset;
}

uint luminance_to_bin_index(float luminance, float adapted_luminance)
{
    float min_log_lum = get_min_log_lum(adapted_luminance);
    // Avoid taking the log of zero
    if (luminance < 1e-6) {
        return 0u;
    }
    // Normalized logarithmic luminance, 0 being the minimum log luminance
    // handled by the histogram, and 1 being the maximum.
    float norm_log_lum = (log2(luminance) - min_log_lum) * inv_log_lum_range;
    norm_log_lum = clamp(norm_log_lum, 0.0, 1.0);
    // From [0, 1] to [1, 255]. The 0th bin is handled by the near-zero check
    return uint(norm_log_lum * num_bins + 1.0);
}

float bin_index_to_luminance(float bin, float adapted_luminance)
{
    float min_log_lum = get_min_log_lum(adapted_luminance);
    return exp2(((bin * inv_num_bins) * log_lum_range) + min_log_lum);
}
