#version 120

varying vec4 texcoord;
varying vec2 lmcoord;

varying vec4 color;

varying vec3 normal;

uniform sampler2D texture;
uniform sampler2D specular;

vec2 encodeColors(in vec3 color) {

	color = clamp(color, 0.0, 1.0);

	vec3 YCoCg = vec3(0.25 * color.r + 0.5 * color.g + 0.25 * color.b, 0.5 * color.r - 0.5 * color.b + 0.5, -0.25 * color.r + 0.5 * color.g - 0.25 * color.b + 0.5);

	YCoCg.g = (mod(gl_FragCoord.x, 2.0) == mod(gl_FragCoord.y, 2.0))? YCoCg.b:YCoCg.g;

	return YCoCg.rg;
}


void main(){

    vec4 frag2 = vec4(normal * 0.5 + 0.5, 1.0);

    vec4 albedo = texture2D(texture, texcoord.st) * color;
    vec4 specularMap = texture2D(specular, texcoord.st);
    vec2 outCol = encodeColors(albedo.rgb);
/* DRAWBUFFERS:0246 */

    gl_FragData[0] = vec4(outCol, 0.0, albedo.a);
    gl_FragData[1] = frag2;
    gl_FragData[2] = vec4(lmcoord.y, 0.4, lmcoord.x, 1.0);
    gl_FragData[3] = specularMap;
}
