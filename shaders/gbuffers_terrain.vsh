#version 120

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

#define ENTITY_LEAVES        18.0
#define ENTITY_VINES        106.0
#define ENTITY_TALLGRASS     31.0
#define ENTITY_DANDELION     37.0
#define ENTITY_ROSE          38.0
#define ENTITY_WHEAT         59.0
#define ENTITY_LILYPAD      111.0
#define ENTITY_FIRE          51.0
#define ENTITY_LAVAFLOWING   10.0
#define ENTITY_LAVASTILL     11.0
#define ENTITY_LEAVES2		161.0
#define ENTITY_NEWFLOWERS	175.0
#define ENTITY_NETHER_WART	115.0
#define ENTITY_DEAD_BUSH	 32.0
#define ENTITY_CARROT		141.0
#define ENTITY_POTATO		142.0
#define ENTITY_COBWEB		 30.0

//#define TRANSLUCENT_BLOCKS


//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES

const float PI = 3.1415927;

varying vec4 color;
varying vec2 lmcoord;
varying float mat;
varying vec4 texcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;
varying vec4 vertexPos;
varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec3 viewVector;
varying vec3 wpos;
varying float dist;

varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 lightVector;
varying vec3 ambient_color;
varying float SdotU;
varying float MdotU;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;
varying float sunVisibility;
varying float moonVisibility;
varying float islava;
varying mat3 tbnMatrix;
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform ivec2 eyeBrightness;
uniform int isEyeInWater;

uniform float far;
uniform float near;
uniform float aspectRatio;

uniform int worldTime;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
float timefract = worldTime;



float pi2wt = PI*2*(frameTimeCounter*24)*0;

//Raining
float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;
float wetx  = clamp(wetness, 0.0f, 1.0f);

//Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {
    vec3 ret;
    float magnitude,d0,d1,d2,d3;
    magnitude = sin(pi2wt*fm + pos.x*0.5 + pos.z*0.5 + pos.y*0.5) * mm + ma;
    d0 = sin(pi2wt*f0);
    d1 = sin(pi2wt*f1);
    d2 = sin(pi2wt*f2);
    ret.x = sin(pi2wt*f3 + d0 + d1 - pos.x + pos.z + pos.y) * magnitude;
    ret.z = sin(pi2wt*f4 + d1 + d2 + pos.x - pos.z + pos.y) * magnitude;
	ret.y = sin(pi2wt*f5 + d2 + d0 + pos.z + pos.y - pos.y) * magnitude;
    return ret;
}

vec3 calcMove(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWave(pos      , 0.0027, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
	vec3 move2 = calcWave(pos+move1, 0.0348, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
    return move1+move2;
}

vec3 calcWaterMove(in vec3 pos)
{
	float fy = fract(pos.y + 0.001);
	if (fy > 0.002)
	{
			float wave = 0.025 *  sin(2 * PI * (frameTimeCounter*0.5 + pos.x /  11.0 + pos.z / 5.0))
		               + -0.0 * sin(2 * PI * (frameTimeCounter*0.6 + pos.x / 11.0 + pos.z /  5.0));
		return vec3(0, clamp(wave, -fy, 1.0-fy), 0);
	}
	else
	{
		return vec3(0);
	}
}

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	texcoord = (gl_MultiTexCoord0);
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vec2 midcoord = (mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.st-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid) * 2.0;
	vtexcoordam.st  = min(texcoord.st,midcoord-texcoordminusmid);
	vtexcoord.st    = sign(texcoordminusmid) * 0.5 + 0.5;
	mat = 1.0f;
  islava = 0.0;
	float istopv = 0.0;

	float underCover = lmcoord.t;

	float dnrsMult = (1.0 + rainStrength * 0.5) * (1.0 - TimeMidnight * 0.5) * 2.0;

	if (gl_MultiTexCoord0.t < mc_midTexCoord.t) istopv = 1.0;
	/* un-rotate */
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec3 worldpos = position.xyz + cameraPosition;

	underCover = clamp(pow(underCover, 15.0) * 2.0,0.0,1.0);


		if ( mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == ENTITY_LEAVES2) {
				position.xyz += calcMove(worldpos.xyz, 0.0030, 0.0054, 0.0033, 0.0025, 0.0017, 0.0031,vec3(0.75,0.15,0.75+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.375,0.075,0.375))*underCover * dnrsMult;
				}

		if (mc_Entity.x == ENTITY_NEWFLOWERS ) {
				position.xyz += calcMove(worldpos.xyz, 0.0030, 0.0054, 0.0033, 0.0025, 0.0017, 0.0031,vec3(0.75,0.15,0.75+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.375,0.075,0.375))*underCover * dnrsMult;
		}

		if ( mc_Entity.x == ENTITY_VINES ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		if ( mc_Entity.x == ENTITY_COBWEB ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * 0.1 * dnrsMult;
				}

		if (istopv > 0.9) {

		if ( mc_Entity.x == ENTITY_TALLGRASS) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		if ((mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_ROSE)) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		if ( mc_Entity.x == ENTITY_WHEAT) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		if ( mc_Entity.x == ENTITY_FIRE) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		if ( mc_Entity.x == ENTITY_NETHER_WART ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		if ( mc_Entity.x == ENTITY_DEAD_BUSH ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		if ( mc_Entity.x == ENTITY_CARROT || mc_Entity.x == ENTITY_POTATO) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5))*underCover * dnrsMult;
				}

		}



	float movemult = 0.0;

	if ( mc_Entity.x == ENTITY_LAVAFLOWING || mc_Entity.x == ENTITY_LAVASTILL ) {
	//		mat = 0.4;
      islava = 1.0;
			position.xyz += calcWaterMove(worldpos.xyz) * 0.25;
			}
	if ( mc_Entity.x == ENTITY_LILYPAD ) {
			position.xyz += calcWaterMove(worldpos.xyz);
		//	mat = 0.4;
			}



	if (mc_Entity.x == ENTITY_CARROT || mc_Entity.x == ENTITY_COBWEB || mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_DEAD_BUSH || mc_Entity.x == ENTITY_FIRE || mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == ENTITY_LEAVES2
	 || mc_Entity.x == ENTITY_LILYPAD || mc_Entity.x == ENTITY_NETHER_WART || mc_Entity.x == ENTITY_NEWFLOWERS || mc_Entity.x == ENTITY_POTATO || mc_Entity.x == ENTITY_ROSE || mc_Entity.x == ENTITY_TALLGRASS || mc_Entity.x == ENTITY_VINES
	 || mc_Entity.x == ENTITY_WHEAT || mc_Entity.x == 83.0 || mc_Entity.x == 39.0 || mc_Entity.x == 40.0)mat = 0.4;

	if (mc_Entity.x == 174.0) {
	mat = 0.23;
	}

	if (mc_Entity.x == 50.0 || mc_Entity.x == 62.0 || mc_Entity.x == 91.0 || mc_Entity.x == 89.0 || mc_Entity.x == 124.0 || mc_Entity.x == 138.0 || mc_Entity.x == 169.0 || mc_Entity.x == ENTITY_FIRE) mat = 0.6;

	if (mc_Entity.x == ENTITY_LAVAFLOWING || mc_Entity.x == ENTITY_LAVASTILL) mat = 0.53;
    if (mc_Entity.x == 41) mat = 0.7;
	/* re-rotate */

	/* projectify */
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	color = gl_Color;

	 tangent = vec3(0.0);
	 binormal = vec3(0.0);
	 normal = normalize(gl_NormalMatrix * gl_Normal);

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

 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
								  tangent.y, binormal.y, normal.y,
						     	  tangent.z, binormal.z, normal.z);

    vertexPos = gl_Vertex;
	wpos = worldpos;

	dist = sqrt(dot(gl_ModelViewMatrix * gl_Vertex,gl_ModelViewMatrix * gl_Vertex));
}
