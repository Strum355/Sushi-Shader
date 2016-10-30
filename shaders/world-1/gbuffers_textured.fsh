#version 120

varying vec4 texcoord;
varying vec2 lmcoord;

varying vec4 color;

varying vec3 normal;

uniform sampler2D texture;
uniform sampler2D specular;

void main(){

vec4 frag2 = vec4(normal * 0.5 + 0.5, 1.0);

vec4 albedo = texture2D(texture, texcoord.st) * color;
vec4 specularMap = texture2D(specular, texcoord.st);

/* DRAWBUFFERS:0246 */

gl_FragData[0] = albedo;
gl_FragData[1] = frag2;
gl_FragData[2] = vec4(lmcoord.y, 0.4, lmcoord.x, 1.0);
gl_FragData[3] = specularMap;
}