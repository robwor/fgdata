$FG_GLSL_VERSION

out vec4 fragColor;

in VS_OUT {
	vec2 texcoord;
	vec4 vertex_color;
	flat int renderPart;
	flat bool selected;
} fs_in;

const int RENDER_PART_FOREGROUND = 0;
const int RENDER_PART_BACKGROUND = 1;
const int RENDER_PART_UNDERLINE = 2;
const int RENDER_PART_STRIKETHROUGH = 3;
const int RENDER_PART_OVERLINE = 4;

uniform sampler2D glyphTexture;
uniform vec4 selectionColor;

bool colorIsLight(vec3 c) {
	// Perceptive luminance
	// The human eye favors green color
	float a = 1 - (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);
	return (a < 0.5);
}

void main() {
	if (fs_in.renderPart == RENDER_PART_FOREGROUND) {
		float alpha = texture(glyphTexture, fs_in.texcoord).r;
		fragColor.a = fs_in.vertex_color.a * alpha;
		if (fs_in.selected) {
			if (colorIsLight(selectionColor.rgb)) {
				fragColor.rgb = vec3(0, 0, 0) * fragColor.a;
			} else {
				fragColor.rgb = vec3(1, 1, 1) * fragColor.a;
			}
		} else {
			fragColor.rgb = fs_in.vertex_color.rgb * fragColor.a;
		}
	} else if (fs_in.renderPart == RENDER_PART_BACKGROUND) {
		if (fs_in.selected) {
			fragColor.rgb = selectionColor.rgb;
			fragColor.a = 1;
		} else {
			fragColor = fs_in.vertex_color;
		}
	} else {
		fragColor = fs_in.vertex_color;
		if (fs_in.selected) {
			if (colorIsLight(selectionColor.rgb)) {
				fragColor.rgb = vec3(0, 0, 0);
			} else {
				fragColor.rgb = vec3(1, 1, 1);
			}
		}
		fragColor.a = 1;
	}
	if (fragColor.a == 0) {
		discard;
	}
}
