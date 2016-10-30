#version 120

varying vec4 texcoord;
varying vec2 lmcoord;

varying vec4 color;

varying vec3 normal;

void main(){

	texcoord = (gl_MultiTexCoord0);
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	
	color = gl_Color;

	gl_Position = ftransform();

}