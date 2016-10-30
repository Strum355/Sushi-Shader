#version 120

#define MAX_COLOR_RANGE 48.0 //[1.0 2.0 4.0 6.0 12.0 24.0 48.0 96.0]

//disabling is done by adding "//" to the beginning of a line.

//***************************ADJUSTABLE VARIABLES//***************************
//***************************ADJUSTABLE VARIABLES//***************************
//***************************ADJUSTABLE VARIABLES//***************************

//***************************SHADOWS***************************//
	const int 		shadowMapResolution 	= 2048;		//[512 1024 2048 4096]	//shadowmap resolution
	const float 	shadowDistance 				= 180;		//[50 120 180 250] //draw distance of shadows

	#define SHADOW_DARKNESS 0.1 //[0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]	//shadow darkness levels, lower values mean darker shadows, see .vsh for colors
	#define COLOURED_SHADOWS //Makes shadows from transparent blocks coloured by it's source.

	#define SHADOW_FILTER						//smooth shadows

//***************************LIGHTNING***************************//
	#define DYNAMIC_HANDLIGHT
		#define HANDLIGHT_AMOUNT 1.0

	#define SUNLIGHTAMOUNT 3.2	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0]	//change sunlight strength , see .vsh for colors.

	//Torch Color//
	#define TORCH_COLOR 1.0,0.38,0.1 	//Torch Color RGB - Red, Green, Blue
	#define TORCH_COLOR2 1.0,0.38,0.1 	//Torch Color RGB - Red, Green, Blue

	#define TORCH_ATTEN 8.0					//how much the torch light will be attenuated (decrease if you want the torches to cover a bigger area)
	#define TORCH_INTENSITY 4.55

	//Minecraft lightmap (used for sky)
	#define ATTENUATION 3.0
	#define MIN_LIGHT 0.000

//***************************VISUALS***************************//

	//#define SSAO
	const int nbdir = 6;	           //qualtiy
	const float sampledir = 6;	      //quality
	const float ssaorad = 0.5;	 //strength

//***************************VOLUMETRIC LIGHT***************************//
	#define VOLUMETRIC_LIGHT
		#define VL_QUALITY 	1.0	//[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0]	  		// Quality of the Volumetric Light. 1.0 is default, 10.0 recommended for quality, 20.0 best quality you can get. But eats a lot of FPS.
		#define VL_DISTANCE 32.0 //[16.0 32.0 64.0 128.0 256.0 512.0]		// The draw distance of Volumetric Light

//***************************BUILD IN FUNCTIONS***************************//

const float 	wetnessHalflife 		= 70; //[10 20 30 40 50 60 70]	//number of seconds for the wetness to fade out
const float 	drynessHalflife 		= 70;	//[10 20 30 40 50 60 70] //number of seconds for the dryness to fade out

const float 	centerDepthHalflife 	= 4; //[1 2 3 4 5 6 7 8 9 10] //number of seconds for the depth to fade out

const float 	eyeBrightnessHalflife 	= 7; //[1 2 3 4 5 6 7 8 9 10] //number of seconds for being under cover to fade out

const bool 		shadowHardwareFiltering = true;

const float		sunPathRotation			= -40; //[0 10 20 30 40 -40 -30 -20 -10]	//rotation of the sun in degrees

const float		ambientOcclusionLevel	= 1; //[0 0.2 0.4 0.6 0.8 1]	//amount of default minecraft Ambient Occlusion

const int 		noiseTextureResolution  = 1024;

const int		RGBA16 					= 1;
const int		RGB16 					= 1;

const int		gnormalFormat			= RGB16;
const int		gcolorFormat			= RGBA16;
const int		gaux1Format			    = RGBA16;
const int 		compositeFormat			= RGBA16;

//***************************END OF BUILD IN FUNCTIONS***************************//

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

#define SHADOW_MAP_BIAS 0.85 //[0.6 0.65 0.7 0.75 0.8 0.85] //accuracy of the shadows

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;
varying vec3 sunlight_color;
varying vec3 ambient_color;
varying vec3 moonlight;
varying float handItemLight;
varying float eyeAdapt;
varying float moonVisibility;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2DShadow shadowcolor;
uniform sampler2D gcolor;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux3;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;


float comp = 1.0-near/far/far;			//distance above that are considered as sky

	float timefract = worldTime;

	float TimeSunrise  = ((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f));
	float TimeNoon     = ((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f);
	float TimeSunset   = ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f);
	float TimeMidnight = ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f);

	float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13000.0)/300.0,0.0,1.0) + clamp((time-22000.0)/200.0,0.0,1.0)-clamp((time-23400.0)/200.0,0.0,1.0));

float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;


struct shadingStruct
{
	float ao;
	float specMap;
	float volumeLight;
	float handlight;
	float roughness;
	float sss;
	float sunLD;

	vec3 shadows;
	float shadows1;
	vec3 torchmap;
	vec3 skyGrad;
	vec3 underwaterFog;
	vec3 eGlow;
	vec3 godRays;
	vec3 finalShading;
	vec3 nightDesaturation;

} shading;


struct lightMapStruct
{
	float skyLightMap;
	float shadowLightMap;
	float isWetness;
	float fresnel;

} lightMap;


struct positionStruct
{
	vec4 fragposition;
	vec4 wpos;
	vec4 sworldposition;
	vec4 sworldposition1;

	vec3 fragpos;
	vec3 texDepth;

} position;


vec3 convertScreenSpaceToWorldSpace(vec2 co, float depth) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, depth) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
    return screenSpace;
}

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float distx(float dist){
	return (far * (dist - near)) / (dist * (far - near));
}

float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

vec3 getColor(){
	vec3 color 								= texture2D(gcolor, texcoord.st).rgb;

		color = pow(color,vec3(2.2));

	return color;
}

vec4 aux = texture2D(gaux1, texcoord.st);
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;
vec3 normal2 = texture2D(composite, texcoord.st).rgb * 2.0f - 1.0f;
float pixeldepth = texture2D(depthtex1,texcoord.xy).x;
float pixeldepth1 = texture2D(depthtex0,texcoord.xy).x;

// masks

float land 								= float(aux.g > 0.04);
bool land2 								= pixeldepth < comp;

float iswater 						= float(aux.g > 0.04 && aux.g < 0.07);
float translucent 				= float(aux.g > 0.3 && aux.g <= 0.4);
float hand 								= float(aux.g > 0.75 && aux.g < 0.85);

float emissive 						= float(aux.g > 0.58 && aux.g < 0.62);
float islava 						= float(aux.g > 0.50 && aux.g < 0.55);

// end of masks

vec3 texcoordDepth = vec3(texcoord.st, pixeldepth);
vec3 texcoordDepth1 = vec3(texcoord.st, pixeldepth1);

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

float altAux = 1-aux.b;
const float speed = 2.5;
float light_jitter = 1.0-sin(frameTimeCounter*1.4*speed+cos(frameTimeCounter*1.9*speed))*0.05;			//little light variations
//float torch_lightmap = min(pow(altAux,TORCH_ATTEN)*TORCH_INTENSITY*20.0, 0.9)*light_jitter;
//float torch_lightmap2 = min(pow(altAux,TORCH_ATTEN*5)*TORCH_INTENSITY*65, 0.9)*light_jitter;

float modlmap = min(aux.b, 0.9);
float torch_lightmap1 = max(((1.0/pow((1-modlmap)*10, 2.0)-(1.5*1.5)/(16.0*18.0))*TORCH_INTENSITY)-0.02, 0.0);

vec3 torchcolor = vec3(TORCH_COLOR)*eyeAdapt*0.1*TORCH_INTENSITY;
vec3 torchcolor2 = vec3(TORCH_COLOR2)*eyeAdapt*TORCH_INTENSITY;

vec3 specular = texture2D(gaux3,texcoord.xy).rgb;

const vec2 shadow_offsets[60] = vec2[60]  (  vec2(0.06120777f, -0.8370339f),
vec2(0.09790099f, -0.5829314f),
vec2(0.247741f, -0.7406831f),
vec2(-0.09391049f, -0.9929391f),
vec2(0.4241214f, -0.8359816f),
vec2(-0.2032944f, -0.70053f),
vec2(0.2894208f, -0.5542058f),
vec2(0.2610383f, -0.957112f),
vec2(0.4597653f, -0.4111754f),
vec2(0.1003582f, -0.2941186f),
vec2(0.3248212f, -0.2205462f),
vec2(0.4968775f, -0.6096044f),
vec2(0.770794f, -0.5416877f),
vec2(0.6429226f, -0.261653f),
vec2(0.6138752f, -0.7684944f),
vec2(-0.06001971f, -0.4079638f),
vec2(0.08106154f, -0.07295965f),
vec2(-0.1657472f, -0.2334092f),
vec2(-0.321569f, -0.4737087f),
vec2(-0.3698382f, -0.2639024f),
vec2(-0.2490126f, -0.02925519f),
vec2(-0.4394466f, -0.06632736f),
vec2(-0.6763983f, -0.1978866f),
vec2(-0.5428631f, -0.3784158f),
vec2(-0.3475675f, -0.9118061f),
vec2(-0.1321516f, 0.2153706f),
vec2(-0.3601919f, 0.2372792f),
vec2(-0.604758f, 0.07382818f),
vec2(-0.4872904f, 0.4500539f),
vec2(-0.149702f, 0.5208581f),
vec2(-0.6243932f, 0.2776862f),
vec2(0.4688022f, 0.04856517f),
vec2(0.2485694f, 0.07422727f),
vec2(0.08987152f, 0.4031576f),
vec2(-0.353086f, 0.7864715f),
vec2(-0.6643087f, 0.5534591f),
vec2(-0.8378839f, 0.335448f),
vec2(-0.5260508f, -0.7477183f),
vec2(0.4387909f, 0.3283032f),
vec2(-0.9115909f, -0.3228836f),
vec2(-0.7318214f, -0.5675083f),
vec2(-0.9060445f, -0.09217478f),
vec2(0.9074517f, -0.2449507f),
vec2(0.7957709f, -0.05181496f),
vec2(-0.1518791f, 0.8637156f),
vec2(0.03656881f, 0.8387206f),
vec2(0.02989202f, 0.6311651f),
vec2(0.7933047f, 0.4345242f),
vec2(0.3411767f, 0.5917205f),
vec2(0.7432346f, 0.204537f),
vec2(0.5403291f, 0.6852565f),
vec2(0.6021095f, 0.4647908f),
vec2(-0.5826641f, 0.7287358f),
vec2(-0.9144157f, 0.1417691f),
vec2(0.08989539f, 0.2006399f),
vec2(0.2432684f, 0.8076362f),
vec2(0.4476317f, 0.8603768f),
vec2(0.9842657f, 0.03520538f),
vec2(0.9567313f, 0.280978f),
vec2(0.755792f, 0.6508092f));

float diffuseorennayar(vec3 pos, vec3 lvector, vec3 normal, float spec, float roughness) {

    vec3 v = normalize(pos);
	vec3 l = normalize(lvector);
	vec3 n = normalize(normal);

	float vdotn = dot(v,n);
	float ldotn = dot(l,n);
	float cos_theta_r = vdotn;
	float cos_theta_i = ldotn;
	float cos_phi_diff = dot(normalize(v-n*vdotn),normalize(l-n*ldotn));
	float cos_alpha = min(cos_theta_i,cos_theta_r); // alpha=max(theta_i,theta_r);
	float cos_beta = max(cos_theta_i,cos_theta_r); // beta=min(theta_i,theta_r)

	float r2 = roughness*roughness;
	float a = 1.0 - r2;
	float b_term;

	if(cos_phi_diff>=0.0) {
		float b = r2;
		b_term = b*sqrt((1.0-cos_alpha*cos_alpha)*(1.0-cos_beta*cos_beta))/cos_beta*cos_phi_diff;
		b_term = b*sin(cos_alpha)*tan(cos_beta)*cos_phi_diff;
	}
	else b_term = 0.0;

	return clamp(cos_theta_i*(a+b_term),0.0,1.0);
}

float getWaterDepth(inout positionStruct position){

	vec3 uPos = vec3(.0);

	float uDepth = texture2D(depthtex0,texcoord.xy).x;
	uPos = nvec3(gbufferProjectionInverse * vec4(vec3(texcoord.xy,uDepth) * 2.0 - 1.0, 1.0));

	vec3 uVec = position.fragposition.xyz-uPos;
	float UNdotUP = abs(dot(normalize(uVec),normal));
	float depth = sqrt(dot(uVec,uVec))*UNdotUP;

	return depth;

}

vec3 calcExposure(vec3 color, lightMapStruct lightMap) {
         float maxx = 1.0;
         float minx = 0.0;

         float exposure = max(pow(lightMap.skyLightMap, 1.0), 0.0)*maxx + minx;

         color.rgb *= vec3(exposure);

         return color.rgb;
}


// dirived from: http://devlog-martinsh.blogspot.nl/2011/03/glsl-8x8-bayer-matrix-dithering.html
float find_closest(vec2 pos)
{
	const int ditherPattern[64] = int[64](
		0, 32, 8, 40, 2, 34, 10, 42,
		48, 16, 56, 24, 50, 18, 58, 26,
		12, 44, 4, 36, 14, 46, 6, 38,
		60, 28, 52, 20, 62, 30, 54, 22,
		3, 35, 11, 43, 1, 33, 9, 41,
		51, 19, 59, 27, 49, 17, 57, 25,
		15, 47, 7, 39, 13, 45, 5, 37,
		63, 31, 55, 23, 61, 29, 53, 21);

    vec2 positon = floor(mod(vec2(texcoord.s * viewWidth,texcoord.t * viewHeight), 8.0f));

	int dither = ditherPattern[int(positon.x) + int(positon.y) * 8];

	return float(dither) / 64.0f;
}


float noisepattern(vec2 pos, float sample) {
	float noise = abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));

	noise *= sample;
	return noise;
}

vec2 lightposition() {

	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		 tpos = vec4(tpos.xyz/tpos.w,1.0);

	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lp = pos1*0.5+0.5;

	return lp;
}


float dynamicExposure()
{
		return mix(1.0,0.0,(pow(eyeBrightnessSmooth.y / 240.0f, 3.0f)));
}

float dynamicExposure1()
{
		return mix(.70,0.0,(pow(eyeBrightnessSmooth.y / 240.0f, 3.0f)));
}


float getSkyLightMap()
{
	return pow(aux.r,ATTENUATION);
}

float getIsWet(lightMapStruct lightmap)
{
	return wetness*pow(lightmap.skyLightMap,5.0)*sqrt(0.5+max(dot(normal,upVec),0.0));
}

float getShadowLightMap(in lightMapStruct lightmap)
{
	return lightmap.skyLightMap;
}

float getSpecmap(in lightMapStruct lightmap)
{
		return specular.r*(1.0-specular.b)+specular.g*lightmap.isWetness+specular.b*0.85;
}

float getFresnelPow(in lightMapStruct lightmap)
{
	return pow(1.0-(specular.b+specular.g)/2.0,1.25+lightmap.isWetness*0.75)*3.5;
}

float getDistordFactor(vec4 worldposition){
	vec2 pos1 = abs(worldposition.xy * 1.165);

	float distb = pow(pow(pos1.x, 8.) + pow(pos1.y, 8.), 1.0 / 8.0);
	return (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
}

vec4 biasedShadows(vec4 worldposition){

	float distortFactor = getDistordFactor(worldposition);

	worldposition.xy /= distortFactor*0.97;
	worldposition = worldposition * vec4(0.5,0.5,0.2,0.5) + vec4(0.5,0.5,0.5,0.5);

	return worldposition;
}

vec4 getShadowWorldPos(in float shadowdepth, vec2 texcoord){

	vec4 sfragposition = nvec4(convertScreenSpaceToWorldSpace(texcoord.st,shadowdepth));

  if (isEyeInWater > 0.9)
   sfragposition.xy *= 0.817;

	vec4 sworldposition = vec4(0.0);
		sworldposition = gbufferModelViewInverse * sfragposition;

		sworldposition = shadowModelView * sworldposition;
		sworldposition = shadowProjection * sworldposition;
		sworldposition /= sworldposition.w;

	return sworldposition;

}

#ifdef VOLUMETRIC_LIGHT

float getVolumetricRays() {

	///////////////////////Setting up functions///////////////////////

		vec3 rSD = vec3(0.0);
			rSD.x = 0.0;
			rSD.y = 6.0 / VL_QUALITY;
			rSD.z = find_closest(texcoord.st);


		rSD.z *= rSD.y;

		float maxDist = (VL_DISTANCE);
		float minDist = (0.01);
			minDist += rSD.z;

		float weight = (maxDist / rSD.y);

		vec2 diffthresh = vec2(0.0005, -0.001);	// Fixes light leakage from walls

		vec4 worldposition = vec4(0.0);

		for (minDist; minDist < maxDist;) {

		///////////////////////MAKING VL NOT GO THROUGH WALLS///////////////////////

			if (getDepth(pixeldepth) < minDist){
				break;
			}

		///////////////////////Getting worldpositon///////////////////////

			worldposition = getShadowWorldPos(distx(minDist),texcoord.st);

		///////////////////////Rescaling ShadowMaps///////////////////////

			worldposition = biasedShadows(worldposition);

		///////////////////////Projecting shadowmaps on a linear depth plane///////////////////////

			rSD.x += (shadow2D(shadowtex1, vec3(worldposition.rg, worldposition.b + diffthresh.x )).z);


			minDist = minDist + rSD.y;
	}

	///////////////////////Returning the program///////////////////////

		rSD.x /= weight;
		rSD.x *= 0.15 * maxDist / 32;

		rSD.x = mix(rSD.x, clamp(rSD.x, 0.0, 0.1), dynamicExposure());

		return rSD.x;
}

#else
float getVolumetricRays(){

	return 0.0;
}
#endif

vec4 getFpos(float pixeldepth){

		vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
			fragposition /= fragposition.w;

		if (isEyeInWater > 0.9)
		fragposition.xy *= 0.831;

		return fragposition;
}

vec4 getWpos(in positionStruct position){

		vec4 worldposition = vec4(0.0);
			worldposition = gbufferModelViewInverse * position.fragposition;

		return worldposition;

}

vec3 getFragpos(in positionStruct position){

	return nvec3(gbufferProjectionInverse * nvec4(position.texDepth * 2.0 - 1.0));
}

vec3 getShadows(vec3 shading, in positionStruct position, in lightMapStruct lightMap, float translucent){

		vec4 sworldposition = biasedShadows(position.sworldposition);

		float distortFactor = getDistordFactor(sworldposition);

		float step = 3.0/shadowMapResolution*(1.0+rainx*5.0);
		float NdotL = clamp(dot(normal,lightVector),0.0,1.0);

		vec3 colorShading = vec3(0.0);
		vec3 shading2 = vec3(0.0);

		float diffthresh = pow(distortFactor, 4.0)/(4096 * 0.75) * tan(acos(max(NdotL,0.0))) + pow(max(length(position.fragposition),0.0),0.25) / 2048 * 0.5;
		diffthresh = mix(diffthresh , 0.0003, translucent);
		if (max(abs(sworldposition.x),abs(sworldposition.y)) < 0.99) {

			if (NdotL > 0.0 || translucent > 0.9) {
				shading *= 0.0;
				shading2 *= 0.0;
				colorShading *= 0.0;
			}

				int weight;
				step = 5.625/shadowMapResolution*(1.0+rainx*5.0);

				#ifdef SHADOW_FILTER

					for (int i = 0; i < 60; i++){

						shading += shadow2D(shadowtex0,vec3(sworldposition.st + shadow_offsets[i] * step, sworldposition.z - diffthresh)).x;
						shading2 += shadow2D(shadowtex1,vec3(sworldposition.st + shadow_offsets[i] * step, sworldposition.z - diffthresh)).r;

					#ifdef COLOURED_SHADOWS

						colorShading += shadow2D(shadowcolor,vec3(sworldposition.st + shadow_offsets[i] * step, sworldposition.z - diffthresh)).rgb;
					#endif

					weight++;
					}

					#ifdef COLOURED_SHADOWS
						colorShading /= weight;
					#endif

					shading /= weight;
					shading2 /= weight;

				#endif


				#ifndef SHADOW_FILTER
						shading += shadow2D(shadowtex0,vec3(sworldposition.st, sworldposition.z - diffthresh)).x;

						shading2 += shadow2D(shadowtex1,vec3(sworldposition.st, sworldposition.z - diffthresh)).r;

				#ifdef COLOURED_SHADOWS
						colorShading += shadow2D(shadowcolor,vec3(sworldposition.st, sworldposition.z - diffthresh)).rgb;
						#endif
				#endif

				shading = clamp(shading, 0.0, 1.0);
				shading2 = clamp(shading2, 0.0, 1.0);
				colorShading = clamp(colorShading * 1.4, 0.0, 1.0);

				#ifdef COLOURED_SHADOWS
					colorShading *= shading2;
					shading = mix(colorShading,vec3(1),shading);
				#else
					shading = shading2;
				#endif

			shading *= mix(clamp(pow(NdotL,1.0),0.0,1.0),1.0,translucent);

			if (isEyeInWater > 0.9)
				shading = calcExposure(shading, lightMap);

		}

		return shading;

}

vec3 getShadows1(vec3 shading, in positionStruct position, in lightMapStruct lightMap, float translucent){

		vec4 sworldposition = biasedShadows(position.sworldposition1);

		float distortFactor = getDistordFactor(sworldposition);

		float step = 3.0/shadowMapResolution*(1.0+rainx*5.0);
		float NdotL = clamp(dot(normal2,lightVector),0.0,1.0);

		vec3 colorShading = vec3(0.0);
		vec3 shading2 = vec3(0.0);

		float diffthresh = pow(distortFactor, 4.0)/shadowMapResolution * tan(acos(max(NdotL,0.0))) + pow(max(length(position.fragposition),0.0),0.25) / shadowMapResolution * 0.5;
		diffthresh = mix(diffthresh , 0.0003, translucent);
		if (max(abs(sworldposition.x),abs(sworldposition.y)) < 0.99) {

			if (NdotL > 0.0 || translucent > 0.9) {
				shading *= 0.0;
				shading2 *= 0.0;
				colorShading *= 0.0;
			}


						shading += shadow2D(shadowtex0,vec3(sworldposition.st, sworldposition.z - diffthresh)).x;

						shading2 += shadow2D(shadowtex1,vec3(sworldposition.st, sworldposition.z - diffthresh)).r;

		/*		#ifdef COLOURED_SHADOWS
						colorShading += shadow2D(shadowcolor,vec3(sworldposition.st, sworldposition.z - diffthresh)).rgb;
						#endif*/

				shading = clamp(shading, 0.0, 1.0);
				shading2 = clamp(shading2, 0.0, 1.0);
				colorShading = clamp(colorShading * 1.4, 0.0, 1.0);

			/*	#ifdef COLOURED_SHADOWS
					colorShading *= shading2;
					shading = mix(colorShading,vec3(1),shading);
				#else
					shading = shading2;
				#endif */

				shading = shading2;

			shading *= mix(clamp(pow(NdotL,1.0),0.0,1.0),1.0,translucent);

			if (isEyeInWater > 0.9)
				shading = calcExposure(shading, lightMap);

		}

		return shading;

}

#ifdef SSAO

	float getSSAO(in float ao, bool land, float hand){

			if (land && hand < 0.9) {


				vec3 norm = normal;
				vec3 projpos = convertScreenSpaceToWorldSpace(texcoord.xy,pixeldepth);

				float progress = 0.0;
				ao = 0.0;

				float projrad = clamp(distance(convertCameraSpaceToScreenSpace(projpos + vec3(ssaorad,ssaorad,ssaorad)).xy,texcoord.xy),7.5*pw,60.0*pw);

				for (int i = 1; i < nbdir; i++) {
					for (int j = 1; j < sampledir; j++) {
						vec2 samplecoord = vec2(cos(progress),sin(progress))*(j/sampledir/(ld(pixeldepth) * 20.0))*projrad + texcoord.xy;
						float sample = texture2D(depthtex1,samplecoord).x;
						vec3 sprojpos = convertScreenSpaceToWorldSpace(samplecoord,sample);
						float angle = pow(min(1.0-dot(norm,normalize(sprojpos-projpos)),1.0),2.0);
						float dist = pow(min(abs(ld(sample)-ld(pixeldepth)),0.015)/0.015,2.0);
						float temp = min(dist+angle,1.0);
						ao += pow(temp,3.0);
						//progress += (1.0-temp)/nbdir*3.14;
					}
					progress = i*1.256;
				}

				ao /= (nbdir-1)*(sampledir-1);

				ao = pow(ao, 2.2 * ssaorad);

			}
			return ao;
	}
#else
float getSSAO(in float ao, bool land, float hand){
	return 1.0;
}

#endif

#ifdef DYNAMIC_HANDLIGHT
float getHandLight(in float hand, in positionStruct position){

		float handlight = handItemLight*0.5*HANDLIGHT_AMOUNT;

		handlight = (handItemLight*10.0*HANDLIGHT_AMOUNT)*hand;
		handlight += (handItemLight*1.0*HANDLIGHT_AMOUNT);

		handlight = (handlight)/pow(sqrt(dot(position.fragposition.xyz,position.fragposition.xyz)),2.0);

		return handlight;
}
#else
float getHandLight(in float hand, in positionStruct position){
	return 0.0;
}
#endif

vec3 getTorchMap(in positionStruct position, in shadingStruct shading){


		float handlightDistance = 13.0f;
		float handlightDistance2 = 5.0f;

	vec3 Torchlight_lightmap = (torch_lightmap1+shading.handlight*2.0*pow(max(handlightDistance-sqrt(dot(position.fragposition.xyz,position.fragposition.xyz)),0.0)/handlightDistance,4.0)*max(dot(-position.fragposition.xyz,normal),0.0)) *  torchcolor * max(1.0, TimeMidnight*2) ;
	//Torchlight_lightmap += (torch_lightmap+shading.handlight*pow(max(handlightDistance2-sqrt(dot(position.fragposition.xyz,position.fragposition.xyz)),0.0)/handlightDistance2,4.0)*max(dot(-position.fragposition.xyz,normal),0.0)) * torchcolor2;

	return Torchlight_lightmap*(1-dynamicExposure1());
}

float getRoughness(in lightMapStruct lightMap, in float iswater){


		float roughness = mix(1.0-(pow(specular.g,2.0))+specular.b+lightMap.isWetness*specular.g*0.5,0.05,iswater);
		if (specular.r+specular.g+specular.b > 1.0/255.0) {
			} else if (iswater > 0.09) {
				} else {
					roughness = 0.0;
				}

		return roughness;
}

float getSSS(in positionStruct position, in float translucent){

			float sss_transparency = mix(0,1,translucent);		//subsurface scattering amount

			float sss = 0.0;
			vec3 npos = normalize(position.fragposition.xyz);

			sss += pow(max(dot(npos, lightVector),0.0),25.0)*sss_transparency*translucent*10.0;

			return sss;
}

float getSunlightDirect(in shadingStruct shading, in positionStruct position, in float translucent){

			float sunlight_direct = 1.0;

				sunlight_direct = diffuseorennayar(position.fragposition.xyz, lightVector, normal, shading.specMap, shading.roughness * 0.2);
				sunlight_direct = mix(sunlight_direct,0.5,translucent);

		return sunlight_direct;
}

vec3 getEmessiveGlow(vec3 color, float emissive, float islava){

			color.rgb += color * (emissive + islava + (hand * handItemLight));

			return color;
}

float saturate(float v1){
	return clamp(v1, 0.0, 1.0);
}

vec3 getSaturation(vec3 color, float saturation)
{
	saturation -= 1.0;
	color = mix(color,vec3(dot(color,vec3(1.0/3.0))),vec3(-saturation));

	return color;
}

vec3 nightDesaturation(vec3 inColor){
	float amount =  1*pow(1-torch_lightmap1, 50.0)*1-getHandLight(hand, position)*20;
	vec3 nightColor = vec3(0.25, 0.35, 0.7)/2;

	float saturation = 0.0;
	vec3 desatColor = inColor;
	float avg = (desatColor.r + desatColor.g + desatColor.b);
	desatColor = (((desatColor - avg )*saturation)+avg);

	vec3 retColor = mix(inColor, desatColor*nightColor, saturate(TimeMidnight*amount));
	return retColor;
}


vec3 getSkyGrad(vec3 color, bool land,in positionStruct position) {

		if (!land) {
			float horizon = max(dot(normalize(position.fragpos), upVec) * 400.0,0.0);
			float horizon2 = max(abs(dot(normalize(position.fragpos), upVec) * 400.0),0.0);

			//////////////////////////////////////////////////////////////////////////////////////////////////////

			float limit = max(pow(max(1.0 - horizon/600.0, 0.0), 8.0), 0.0);
			float limit_ss_sr = max(pow(max(1.0 - horizon/500.0, 0.0), 8.0), 0.0)*(1.0-TimeNoon)*(1.0-TimeMidnight);
			float limit_ss_sr2 = max(pow(max(1.0 - horizon/600.0, 0.0), 8.0), 0.0)*(1.0-TimeNoon)*(1.0-TimeMidnight);
			float limit_ss_sr3 = (max(pow(max(1.0 - horizon/300.0, 0.0), 8.0), 0.0));

			float limit_tf = max(pow(max(1.0 - horizon/500.0, 0.0), 8.0), 0.0);
			float limit_tf2 = max(pow(max(1.0 - horizon/650.0, 0.0), 8.0), 0.0);

			float scatterLim = max(pow(max(1.0 - horizon2/400.0, 0.0), 8.0), 0.0);

			mat3 volumetricCone = mat3(	vec3(pow(max(dot(normalize(position.fragpos),sunVec),0.0),10.0),
									pow(max(dot(normalize(position.fragpos),sunVec),0.0),2.0),
									pow(max(dot(normalize(position.fragpos),sunVec),0.0),10.0*400.0)),

									vec3(pow(max(dot(normalize(position.fragpos),moonVec),0.0),10.0*1000.0),
									pow(max(dot(normalize(position.fragpos),sunVec),0.0),10.0*5.0),
									pow(max(dot(normalize(position.fragpos),moonVec),0.0),10.0)),

									vec3(0.0,
									0.0,
									0.0));


			//Get Positions in sky//
			float upsky = pow(max(dot(normalize(position.fragpos),upVec),0.0),1.5);

			vec3 pos = vec3(1.0);
				pos = mix(pos.rgb, vec3(.0), upsky * (1- (TimeNoon + TimeSunset + TimeSunrise) * 0.25));

			float SkyGradient = max(pow(max(1.0 - horizon/1500.0, 0.01), 8.0), 0.0)*(1.0-limit_ss_sr2);
				SkyGradient = clamp(SkyGradient, 0.05, 1.0);
				SkyGradient = pow(SkyGradient, 0.8);

			//////////////////////////////////////////////////////////////////////////////////////////////////////

			vec3 limitcsssr = vec3(88,10,0)/(120);
				 limitcsssr.r = limitcsssr.r + ((limitcsssr.g + limitcsssr.b)/2.0)*-(0.1);
				 limitcsssr.g = limitcsssr.g + ((limitcsssr.r + limitcsssr.b)/2.0)*-(0.1);
				 limitcsssr.b = limitcsssr.b + ((limitcsssr.r + limitcsssr.g)/2.0)*-(0.1);

			vec3 limitcsssr2 = vec3(5,10,0)/(50);
				limitcsssr2.r = limitcsssr2.r + ((limitcsssr2.g + limitcsssr2.b)/2.0)*-(0.1);
				limitcsssr2.g = limitcsssr2.g + ((limitcsssr2.r + limitcsssr2.b)/2.0)*-(0.1);
				limitcsssr2.b = limitcsssr2.b + ((limitcsssr2.r + limitcsssr2.g)/2.0)*-(0.1);

			vec3 skycolor = vec3(ambient_color + 1.3);
				 skycolor.g += (skycolor.g*0.25);
				 skycolor.r -= (skycolor.r*0.15)*(TimeNoon);
				 skycolor.r -= (skycolor.r*0.05)*(1-TimeMidnight);
				 skycolor.rgb *= (vec3(0.8,1.25,1.5) * (1-TimeMidnight));
				 skycolor = getSaturation(skycolor,1.5);
				 skycolor = mix(skycolor,getSaturation(skycolor,1.2),TimeSunrise + TimeSunset);
				 skycolor /= (1.0 + (TimeSunrise + TimeSunset) * 0.5 );


			vec3 limitcn = vec3(0.8,0.8,1.25)/12;
			limitcn = getSaturation(limitcn,1.3);
			vec3 limitcnoon = vec3(getSaturation(skycolor,0.7)) * 0.1;

			vec3 sclrtf = vec3(limitcsssr)/5*(1-transition_fading)*limit_tf*volumetricCone[0].x*(1-limit_ss_sr3);
				 sclrtf += vec3(limitcsssr)/11.5*(1-transition_fading)*limit_tf*(1-limit_ss_sr3);
				 sclrtf += vec3(limitcsssr2)/4*(1-transition_fading)*limit_tf2*(1-limit_tf)*(1-limit_ss_sr3);
				 sclrtf += vec3(limitcsssr)/5*(1-transition_fading)*volumetricCone[0].x*(1-limit_ss_sr3)*(limit);
				 sclrtf += pow(limitcn,vec3(1.5))*(1-limit_tf)*TimeMidnight*(1-transition_fading);

				 sclrtf += color.rgb*0.8*(1-transition_fading);
				 sclrtf -= color.rgb*0.5*(1-limit_ss_sr3)*(1-transition_fading);
				 sclrtf *= 1-rainx;

			vec3 scatter = ((sunlight_color * (TimeSunrise + TimeSunset) * 1.0) + (vec3(limitcnoon * 5.0) * TimeNoon)) * mix(scatterLim*0.0,scatterLim*0.5,TimeNoon) * (1.0 - TimeMidnight) * 0.5;
				scatter = mix(scatter * 0.25, scatter, volumetricCone[0].y * 5.0);

			//////////////////////////////////////////////////////////////////////////////////////////////////////

			//sun
			vec3 sunmoon = mix(sunlight_color * 200,sunlight_color,TimeMidnight)*clamp(volumetricCone[0].z*100.0, 0.0, 10.0)*(1.0-rainx)*(1-max(limit_ss_sr3, 0.0));
				 sunmoon += max(sunlight_color, 0.0)*volumetricCone[1].y*0.005*(1.0-rainx)*(1-max(limit_ss_sr3, 0.0));

			//moon
				 sunmoon += (moonlight*1*clamp(volumetricCone[1].x*1000*100, 0.0, 10.0)*(1-max(limit_ss_sr3, 0.0)))*moonVisibility*(1-rainx)*7;

			//glow
				sunmoon += max(vec3(1), 0.0)*volumetricCone[0].x*0.01*(1.0-rainx)*TimeNoon*(1-moonVisibility)*(1-max(limit_ss_sr3, 0.0));
				sunmoon += max(vec3(sunlight_color), 0.0)*volumetricCone[0].x*0.1*(1.0-rainx)*(TimeSunset + TimeSunrise)*(1-moonVisibility)*(1-max(limit_ss_sr3, 0.0));

				sunmoon += max(vec3(moonlight), 0.0)*volumetricCone[1].z*moonVisibility*(1.0-rainx)*(1-max(limit_ss_sr3, 0.0))/5;

			//////////////////////////////////////////////////////////////////////////////////////////////////////

			color.rgb *= (skycolor * 0.6 * SkyGradient);
			color.rgb = mix(color.rgb, skycolor * 0.04*(5*TimeMidnight), limit);

			//fake atmospheric scattering/////////////////////////////////////////////////////////////////////////////////

			color += scatter;
			color += sclrtf;

			//////////////////////////////////////////////////////////////////////////////////////////////////////

			color.rgb += ((limitcn*0.017)*limit)*TimeMidnight;
			color.rgb -= ((skycolor*0.02)*limit)*TimeMidnight;
			color.rgb -= ((limitcn*0.012)*limit_ss_sr3)*TimeMidnight;

			color.rgb += (vec3(limitcn)*0.00)*TimeMidnight;

			color.rgb = mix(color,(limitcnoon),limit*(1-TimeMidnight)*transition_fading);
			color += getSaturation(pow(sunlight_color,vec3(1.0)),1.5)* min(limit * volumetricCone[0].y,1.0) * min( TimeSunrise + TimeSunset + ((1-transition_fading) * 0.1),1.0) * (1-limit_ss_sr3 * 0.5);

			color.rgb -= (color.rgb)*(1-TimeMidnight)*0.1*(limit_ss_sr3);
			color.rgb += vec3(0.4,0.5,0.4)*(1-TimeMidnight)*0.1*(limit);

			//////////////////////////////////////////////////////////////////////////////////////////////////////////////

			//ToneMapping For Sky//

			color.g -= color.g*0.55*(1-TimeMidnight);
			color.rgb -= color.rgb*0.3*(1-TimeMidnight)*(1-limit);
			color.rgb -= color.rgb*0.75*TimeMidnight;

			//////////////////////////////////////////////////////////////////////////////////////////////////////////////

			color *= mix(mix(1.5,1.0,TimeMidnight),0.5,1.0 - transition_fading);

			//color *= pos;
			color += sunmoon;


			//End of Tone For Sky//

		}

	return color.rgb;

}


float getRainSky(in positionStruct position){

	float wpos = max(position.wpos.y - texcoord.y , 1.0);
	float horizon = (max(pow(max(1.0 - wpos/700.0, 0.01), 8.0), 0.0));

	return horizon;
}

vec3 getFinalShading(in positionStruct position, in shadingStruct shading, in lightMapStruct lightMap){

			float NdotL = dot(lightVector, normal);
			float NdotUp = dot(upVec, normal);

			float visibility = lightMap.skyLightMap;

		//Apply different lightmaps to image

		vec3 light_col =  mix(pow(sunlight_color,vec3(2.2)),moonlight,moonVisibility)*(1-rainx);

			vec3 Sunlight_lightmap = sunlight_color * shading.shadows * SUNLIGHTAMOUNT * (1.0 - rainx) * shading.sunLD * transition_fading;

			float bouncefactor = sqrt((NdotUp*0.4+0.61) * pow(1.01-NdotL*NdotL,2.0)+0.5)*0.66;

			vec3 sky_light = SHADOW_DARKNESS*pow(ambient_color*(1-TimeMidnight*0.75)*(1+3*(1-TimeMidnight)),vec3(1.0))*(1-rainx*0.8)*visibility*bouncefactor;

			//Add all light elements together
			return (((sky_light + MIN_LIGHT) * (0.1) + shading.torchmap) + Sunlight_lightmap +  shading.sss * Sunlight_lightmap * 0.5) * shading.ao;
}

float Blinn_Phong(vec3 ppos, vec3 lvector, vec3 normal, float gloss, float visibility, float glossmult)  {
	vec3 lightDir = vec3(lvector);

	vec3 surfaceNormal = normal;
	float cosAngIncidence = dot(surfaceNormal, lightDir);
	cosAngIncidence = clamp(cosAngIncidence, 0.0, 1.0);

	vec3 viewDirection = normalize(-ppos);

	vec3 halfAngle = normalize(lightDir + viewDirection);
	float blinnTerm = dot(surfaceNormal, halfAngle);

	float normalDotEye = dot(normal, normalize(ppos));
	float fresnel = clamp(pow(1.0 + normalDotEye, 5.0),0.0,1.0);
	fresnel = fresnel*0.85 + 0.15 * (1.0-fresnel);
	float pi = 3.1415927;
	float n =  pow(2.0,gloss*glossmult);
	float blinn = (pow(blinnTerm, n )*((n+8.0)/(8*pi)))*visibility;
	if(blinn < 0.2){
		blinn = 0;
	}
	return blinn;
}



///////////////////////////////VOID MAIN///////////////////////////////
///////////////////////////////VOID MAIN///////////////////////////////
///////////////////////////////VOID MAIN///////////////////////////////

void main() {

	//*ADD COLOR------------------------------------------------------------------*//

	vec3 color 								= getColor();

	//*ADD POSITIONS--------------------------------------------------------------*//

	position.fragposition 		= getFpos(pixeldepth);

	position.wpos 						= getWpos(position);
	position.sworldposition 	= getShadowWorldPos(pixeldepth, texcoord.st);
	position.sworldposition1 	= getShadowWorldPos(pixeldepth1, texcoord.st);

	position.texDepth 				= texcoordDepth;
	position.fragpos 					= getFragpos(position);

	//*ADD LIGHTMAPS--------------------------------------------------------------*//

	lightMap.skyLightMap 			= getSkyLightMap();
	lightMap.shadowLightMap 	= getShadowLightMap(lightMap);
	lightMap.isWetness 				= getIsWet(lightMap);
	lightMap.fresnel 					= getFresnelPow(lightMap);

	//*ADD SHADINGS--------------------------------------------------------------*//

	shading.shadows 					= getShadows(vec3(1.0), position, lightMap, translucent);
	shading.shadows1 					= getShadows1(vec3(1.0), position, lightMap, translucent).r;
	shading.ao 								= getSSAO(1.0, land2, hand);
	shading.specMap 					= getSpecmap(lightMap);
	shading.volumeLight 			= getVolumetricRays();
	shading.handlight 				= getHandLight(hand, position);
	shading.torchmap 					= getTorchMap(position,shading);
	shading.skyGrad 					= getSkyGrad(color.rgb, land2, position);
	shading.roughness 				= getRoughness(lightMap, iswater);
	shading.sss 							= getSSS(position, translucent);
	shading.sunLD 						= getSunlightDirect(shading, position, translucent);
	shading.eGlow 						= getEmessiveGlow(color, emissive, islava);
	shading.finalShading 			= getFinalShading(position, shading, lightMap);

	//*SHADINGS--------------------------------------------------------------*//

	float volumeRays	 				= shading.volumeLight;

	vec3 skyGradient 					= shading.skyGrad;
	vec3 emissive_glow 				= shading.eGlow;
	vec3 finalShading 				= shading.finalShading;

	//*FINALIZING COMPOSITE SHADER--------------------------------------------------------------*//

	color 										= skyGradient;

	if (land2) {
		color	= emissive_glow;
		color	= finalShading * color;
	//	color = nightDesaturation*color;
	} else {
		color = mix(color,vec3(0.0),rainStrength);
	}

	shading.nightDesaturation = nightDesaturation(color);
	vec3 nightDesaturation 		= shading.nightDesaturation;

	if(land2) color = nightDesaturation;
	color 										= pow(color,vec3(1.0 / 2.2));

/* DRAWBUFFERS:07 */

	gl_FragData[0] 						= vec4(color / MAX_COLOR_RANGE, volumeRays);
	gl_FragData[1]						= vec4(shading.shadows1, vec3(0.0));
}