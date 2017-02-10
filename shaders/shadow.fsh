#version 120

varying vec4 texcoord;
varying vec4 color;

varying float isTransparent;

uniform sampler2D tex;

float luma(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 colorSaturate(in vec3 base, in float saturation) {
    return vec3(mix(base, vec3(luma(base)), -saturation));
}

void main() {

	vec4 fragcolor = texture2D(tex,texcoord.xy)*color;
	if (isTransparent < 0.9 || fragcolor.a > 0.8) fragcolor.rgb *= 0;
	fragcolor.rgb = colorSaturate(fragcolor.rgb, 1.4);
	//fragcolor.rgb = mix(vec3(0.0), mix(vec3(0.0),fragcolor.rgb, fragcolor.a), isTransparent);

	gl_FragData[0] = vec4(fragcolor);
}
