#version 120

//disabling is done by adding "//" to the beginning of a line.

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

#define WAVING_WATER

//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES



varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 viewVector;
varying vec3 wpos;
varying float mat;
varying float iswater;
varying float viewdistance;
varying float reflectiveObjects;
varying float isIce;
varying vec4 verts;

attribute vec4 mc_Entity;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform int worldTime;
uniform int isEyeInWater;
uniform float frameTimeCounter;
uniform float rainStrength;

const float PI = 3.1415927;

//Raining
float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {


	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	iswater = 0.0f;
	float displacement = 0.0;

	/* un-rotate */
	vec4 viewpos = gbufferModelViewInverse * position;

	vec3 worldpos = viewpos.xyz + cameraPosition;
	wpos = worldpos;

	vec4 viewVertex = gbufferModelView * viewpos; //Re-rotate
    viewdistance = gl_FogFragCoord = sqrt(dot(viewVertex,viewVertex));

	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		iswater = 1.0;
		float speed = 1.0;


        float magnitude = (sin((worldTime * PI / ((28.0) * speed))) * 0.05 + 0.15) * 0.4;
        float d0 = sin(worldTime * PI / (122.0 * speed)) * 3.0 - 1.5;
        float d1 = sin(worldTime * PI / (142.0 * speed)) * 3.0 - 1.5;
        float d2 = sin(worldTime * PI / (162.0 * speed)) * 3.0 - 1.5;
        float d3 = sin(worldTime * PI / (112.0 * speed)) * 3.0 - 1.5;
		displacement = sin((worldTime * PI / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * magnitude;
        position.y += displacement;

		for(int i = 1; i < 1; ++i){

			float octave = i * 1.0;
			float speed = (octave) * 3.0;

			float magnitude = (sin((position.y * octave + position.x * octave + worldTime * octave * PI / ((28.0) * speed))) * 0.15 + 0.15) * 0.2;
			float d0 = sin(position.y * octave * 3.0 + position.x * octave * 0.3 + worldTime * PI / (112.0 * speed)) * 3.0 - 1.5;
			float d1 = sin(position.y * octave * 0.7 - position.x * octave * 10.0 + worldTime * PI / (142.0 * speed)) * 3.0 - 1.5;
			float d2 = sin(worldTime * PI / (132.0 * speed)) * 3.0 - 1.5;
			float d3 = sin(worldTime * PI / (122.0 * speed)) * 3.0 - 1.5;
			displacement += sin((worldTime * PI / (11.0 * speed)) + (position.z * octave + d2) + (position.x * octave + d3)) * (magnitude/2.0);
			displacement -= sin((worldTime * PI / (11.0 * speed)) + (position.z * octave * 0.5 + d1) + (position.x * octave * 2.0 + d0)) * (magnitude/2.0);
			position.y += displacement;
		}


#ifdef WAVING_WATER

		float fy = fract(worldpos.y + 0.001);

	    if (fy > 0.02) {

			float wave = -0.01 *  sin(2 * PI * (frameTimeCounter*0.5 + worldpos.x /  11.0 + worldpos.z / 5.0))
		               + 0.0 +rainx*+0.05 +0.05 * sin(2 * PI * (frameTimeCounter*0.45 + worldpos.x / 11.0 + worldpos.z /  5.0));
			displacement = clamp(wave, -fy, 1.0-fy);
			viewpos.y += displacement;
		}

#endif
}
	mat = 1.0;

	if (iswater < 0.9) {
		mat = 0.41;
	}

	if (iswater > 0.9){
		mat = 0.05;
	}

	/* re-rotate */
	viewpos = gbufferModelView * viewpos;

	/* projectify */
	gl_Position = gl_ProjectionMatrix * viewpos;

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	tangent = vec3(1.0);
	binormal = vec3(1.0);
	normal = normalize(gl_NormalMatrix * normalize(gl_Normal));

	if (gl_Normal.x > 0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  -1.0));
	} else if (gl_Normal.z > 0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		tangent  = normalize(gl_NormalMatrix * vec3( -1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);

		vec3 newnormal = vec3(sin(displacement*PI),1.0-cos(displacement*PI),displacement);

			vec3 bump = newnormal;
			bump = bump;

		float bumpmult = 0.0;

		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

		normal = bump * tbnMatrix;

	verts = gl_Vertex;


	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);

	if(mc_Entity.x == 79){
		mat = 0.95 ;
		isIce = 1.0;
	}
}
