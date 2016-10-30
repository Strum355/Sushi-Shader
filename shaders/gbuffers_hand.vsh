#version 120

const float PI = 3.1415927;

varying vec4 color;
varying vec2 lmcoord;
varying float mat;
varying vec2 texcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;

varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec3 viewVector;
varying float dist;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
	texcoord = (gl_MultiTexCoord0).xy;
	vec2 midcoord = (mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid) * 2.0;
	vtexcoordam.st  = min(texcoord,midcoord-texcoordminusmid);
	vtexcoord.st    = sign(texcoordminusmid) * 0.5 + 0.5;

	/* re-rotate */
	
	
	color = gl_Color;
	
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	
	 tangent = vec3(0.0);
	 binormal = vec3(0.0);
	 normal = normalize(gl_NormalMatrix * gl_Normal);

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, 1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	//vec3 worldpos = position.xyz + cameraPosition;
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
								  tangent.y, binormal.y, normal.y,
						     	  tangent.z, binormal.z, normal.z);
	
	
	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	
	viewVector = normalize(tbnMatrix * viewVector);
	
	
	dist = 0.0;
	dist = sqrt(dot(gl_ModelViewMatrix * gl_Vertex,gl_ModelViewMatrix * gl_Vertex));
}
