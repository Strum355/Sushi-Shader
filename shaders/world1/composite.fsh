#version 120

//disabling is done by adding "//" to the beginning of a line.

//***************************ADJUSTABLE VARIABLES//***************************
//***************************ADJUSTABLE VARIABLES//***************************
//***************************ADJUSTABLE VARIABLES//***************************

//***************************LIGHTNING***************************//
	#define DYNAMIC_HANDLIGHT
		#define HANDLIGHT_AMOUNT 1.0

	//Torch Color//
	#define TORCH_COLOR 1.0,0.4,0.1  	//Torch Color RGB - Red, Green, Blue
	#define TORCH_COLOR2 1.0,0.4,0.1  	//Torch Color RGB - Red, Green, Blue

	#define TORCH_ATTEN 5.0					//how much the torch light will be attenuated (decrease if you want the torches to cover a bigger area)
	#define TORCH_INTENSITY 0.15

	//Minecraft lightmap (used for sky)
	#define ATTENUATION 1.0
	#define MIN_LIGHT 0.000

//***************************VISUALS***************************//

	//#define SSAO
	const int nbdir = 6;	           //qualtiy
	const float sampledir = 6;	      //quality
	const float ssaorad = 2.5;	 //strength


//***************************BUILD IN FUNCTIONS***************************//

const float 	wetnessHalflife 		= 70; //[10 20 30 40 50 60 70]	//number of seconds for the wetness to fade out
const float 	drynessHalflife 		= 70;	//[10 20 30 40 50 60 70] //number of seconds for the dryness to fade out

const float 	centerDepthHalflife 	= 4; //[1 2 3 4 5 6 7 8 9 10] //number of seconds for the depth to fade out

const float 	eyeBrightnessHalflife 	= 9; //[1 2 3 4 5 6 7 8 9 10] //number of seconds for being under cover to fade out

const bool 		shadowHardwareFiltering = true;

const float		sunPathRotation			= -40; //[0 10 20 30 40 -40 -30 -20 -10]	//rotation of the sun in degrees

const float		ambientOcclusionLevel	= 1; //[0 0.2 0.4 0.6 0.8 1]	//amount of default minecraft Ambient Occlusion

const int 		noiseTextureResolution  = 256;

//***************************END OF BUILD IN FUNCTIONS***************************//

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

#define SHADOW_MAP_BIAS 0.85 //[0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95] //accuracy of the shadows. higher values give better close range shadows but worse distant shadows

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
uniform sampler2D composite;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D gnormal;
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
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;

#include "lib/colorRange.glsl"

float comp = 1.0-near/far/far;			//distance above that are considered as sky

	float timefract = worldTime;

	float TimeSunrise  = ((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f));
	float TimeNoon     = ((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f);
	float TimeSunset   = ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f);
	float TimeMidnight = ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f);

	//float time = float(worldTime);
	float transition_fading = 1.0-(clamp((timefract-12000.0)/300.0,0.0,1.0)-clamp((timefract-13000.0)/300.0,0.0,1.0) + clamp((timefract-22800.0)/200.0,0.0,1.0)-clamp((timefract-23400.0)/200.0,0.0,1.0));

float rainx = clamp(rainStrength, 0.0, 1.0);

mat2 time = mat2(vec2(
				((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f))*transition_fading,
				((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f))*transition_fading,

				vec2(
				((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f)*transition_fading,
				((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))*transition_fading
);	//time[0].xy = sunrise and noon. time[1].xy = sunset and mindight.

vec3 sunColor = (vec3(1.0,0.65,0.3) * 0.5 * time[0].x * (1.0-rainStrength) +			//Sunrise
								 vec3(1.0,1.0,1.0) * 1.0 * time[0].y * (1.0-rainStrength) +							//Noon
								 vec3(1.0,0.6,0.2) * 0.5 * (time[1].x + time[1].y) * (1.0-rainStrength) +//Sunset
								 vec3(0.1, 0.1, 0.1) * 0.3 * rainStrength);																//Rain

vec3 moonColor = vec3(0.09,0.12,0.15) * (1.0-rainStrength);

vec3 lightColor = mix(sunColor, moonColor*0.01, TimeMidnight);

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
	vec3 shadows1;
	vec3 torchmap;
	vec3 skyGrad;
	vec3 underwaterFog;
	vec3 eGlow;
	vec3 godRays;
	vec3 finalShading;

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
	vec4 fragposition1;
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

float saturate(float value){
		return clamp(value, 0.0, 1.0);
}

vec3 saturate(vec3 value){
	return clamp(value, 0.0, 1.0);
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
		return pow(texture2D(gcolor, texcoord.st).rgb, vec3(2.2));
}

#define DYNAMIC_EXPOSURE_AMOUNT 1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	//Strength


vec3 dynamicExposure(vec3 color) {
		return (color.rgb * clamp((-eyeBrightnessSmooth.y+230)/100.0,0.0,1.0)*2.5*(1-TimeMidnight*0.5)*(1-rainx)*DYNAMIC_EXPOSURE_AMOUNT);
}

vec4 aux = texture2D(gaux1, texcoord.st);
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;
vec3 normal2 = texture2D(composite, texcoord.st).rgb * 2.0 - 1.0;
float pixeldepth = texture2D(depthtex1,texcoord.xy).x;
float pixeldepth1 = texture2D(depthtex0,texcoord.xy).x;

// masks
float land 								= float(aux.g > 0.04);
float oneMinusLand				= 1-land;
bool land2 								= pixeldepth < comp;

float iswater 						= float(aux.g > 0.04 && aux.g < 0.07);
float translucent 				= float(aux.g > 0.3 && aux.g <= 0.4);
float hand 								= float(aux.g > 0.75 && aux.g < 0.85);
float islava 						= float(aux.g > 0.50 && aux.g < 0.55);
float emissive 						= float(aux.g > 0.58 && aux.g < 0.62)+islava;

vec3 texcoordDepth = vec3(texcoord.st, pixeldepth);

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

float torch_lightmap = min(pow(aux.b,TORCH_ATTEN)*TORCH_INTENSITY*20.0, 0.9);
float torch_lightmap2 = min(pow(aux.b,TORCH_ATTEN*5)*TORCH_INTENSITY*65, 0.9);

vec3 torchcolor = vec3(TORCH_COLOR)*.1*TORCH_INTENSITY;
vec3 torchcolor2 = vec3(TORCH_COLOR2)*TORCH_INTENSITY;

vec3 specular = texture2D(gaux3,texcoord.xy).rgb;

float orenNayar(vec3 pos, vec3 lvector, vec3 normal, float spec, float roughness) {

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


vec3 calcExposure(vec3 color, lightMapStruct lightMap) {
         float maxx = 1.0;
         float minx = 0.0;

         float exposure = max(pow(lightMap.skyLightMap, 1.0), 0.0)*maxx + minx;

         color.rgb *= vec3(exposure);

         return color.rgb;
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



vec4 getFpos(){

		vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
			fragposition /= fragposition.w;

		if (isEyeInWater > 0.9)
		fragposition.xy *= 0.831;

		return fragposition;
}

vec4 getFpos1(){

		vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth1 - 1.0f, 1.0f);
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


#ifdef SSAO
float getSSAO() {
	float ao = 0.0;
	if (land > 0.5 && hand < 0.5) {
		vec3 projpos = convertScreenSpaceToWorldSpace(texcoord.xy,pixeldepth);

		float progress = 0.0;

		float dither = find_closest(texcoord.st) * 3.141592653589793;

		float projrad = clamp(distance(convertCameraSpaceToScreenSpace(projpos + vec3(ssaorad,ssaorad,ssaorad)).xy,texcoord.xy),7.5*pw,15.0*pw);

		for (int i = 1; i < nbdir; i++) {
			for (int j = 1; j < sampledir; j++) {
				vec2 samplecoord = vec2(cos(progress), sin(progress)) * (0.5 + dither * 0.5) * (j / sampledir / (ld(pixeldepth) * 5.0)) *projrad * vec2(1.0, aspectRatio) + texcoord.xy;
				float sample = texture2D(depthtex1,samplecoord).x;
				vec3 sprojpos = convertScreenSpaceToWorldSpace(samplecoord,sample);
				float angle = pow(min(1.0-dot(normal,normalize(sprojpos-projpos)),1.0),2.0);
				float dist = pow(min(abs(ld(sample)-ld(pixeldepth)),0.015)/0.015,2.0);
				float temp = min(dist+angle,1.0);
				ao += pow(temp,3.0);
				progress += (1.0-temp)/nbdir*3.14;
			}
			progress = i*1.256;
		}

		ao /= (nbdir-1)*(sampledir-1);
		//ao = noise.x;
	}
	ao = mix(pow(ao, 2.2 * ssaorad / (1.0 + ld(pixeldepth) * 5.0)), 1.0, min(emissive + hand, 1.0));
	return ao;
}
#else
float getSSAO(){
	return 1.0;
}

#endif

#ifdef DYNAMIC_HANDLIGHT
float getHandLight(in float hand, in positionStruct position){

	float handlight = handItemLight*0.5*HANDLIGHT_AMOUNT;

	handlight = (handItemLight*10.0*HANDLIGHT_AMOUNT)*hand;
	handlight += (handItemLight*1.0*HANDLIGHT_AMOUNT);

	handlight = (handlight)/pow(sqrt(dot(position.fragposition.xyz,position.fragposition.xyz)),1.0);

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

	vec3 Torchlight_lightmap = (torch_lightmap+shading.handlight*2.0*pow(max(handlightDistance-sqrt(dot(position.fragposition.xyz,position.fragposition.xyz)),0.0)/handlightDistance,4.0)*max(dot(-position.fragposition.xyz,normal),0.0)) *  torchcolor ;
	Torchlight_lightmap += (torch_lightmap2+shading.handlight*pow(max(handlightDistance2-sqrt(dot(position.fragposition.xyz,position.fragposition.xyz)),0.0)/handlightDistance2,4.0)*max(dot(-position.fragposition.xyz,normal),0.0)) * torchcolor2;

	return Torchlight_lightmap;
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

vec3 getEmessiveGlow(vec3 color, float emissive, float islava){
			color.rgb += (color * ((30)) ) * pow(sqrt(dot(color.rgb,color.rgb)), 5.0 ) * (emissive + (hand * handItemLight));

			return color;
}

vec3 getSaturation(vec3 color, float saturation)
{
	saturation -= 1.0;
	color = mix(color,vec3(dot(color,vec3(1.0/3.0))),vec3(-saturation));

	return color;
}

vec3 getFinalShading(in positionStruct position, in shadingStruct shading, in lightMapStruct lightMap){

			float NdotL = dot(lightVector, normal);
			float NdotUp = dot(upVec, normal);

			float visibility = lightMap.skyLightMap;

		//Apply different lightmaps to image

			float bouncefactor = sqrt((NdotUp*0.4+0.61) * pow(1.01-NdotL*NdotL,2.0)+0.5)*0.66;

			vec3 sky_light = 5.0*pow(ambient_color,vec3(1.0))*(1-rainx*0.3)*visibility*bouncefactor;
			//Add all light elements together
			return (((sky_light+0.001)*0.1 + shading.torchmap)) * shading.ao;
}

vec3 nightDesaturation(vec3 inColor){
	float lightmap =  1*pow(1-torch_lightmap, 3.0)*(1-getHandLight(hand, position)*2);
	vec3 nightColor = mix(vec3(0.25, 0.35, 0.7), vec3(1.0), emissive);
	vec3 desatColor = vec3(dot(inColor, vec3(1.0)));
	float mixAmount = saturate((lightmap));

	return mix(mix(inColor*torchcolor2*20, desatColor*nightColor, mixAmount), inColor, saturate(TimeNoon+TimeSunset+TimeSunrise));
}

///////////////////////////////VOID MAIN///////////////////////////////
///////////////////////////////VOID MAIN///////////////////////////////
///////////////////////////////VOID MAIN///////////////////////////////

void main() {

	//*ADD COLOR------------------------------------------------------------------*//

	vec3 color 								= getColor();
	vec3 passThroughCol				= getColor();
	//color = vec3(1.0);
	//*ADD POSITIONS--------------------------------------------------------------*//

	position.fragposition 		= getFpos();
	position.fragposition1 		= getFpos1();
	position.wpos 						= getWpos(position);

	position.texDepth 				= texcoordDepth;
	position.fragpos 					= getFragpos(position);

	//*ADD LIGHTMAPS--------------------------------------------------------------*//

	lightMap.skyLightMap 			= getSkyLightMap();
	lightMap.isWetness 				= getIsWet(lightMap);
	lightMap.fresnel 					= getFresnelPow(lightMap);

	//*ADD SHADINGS--------------------------------------------------------------*//

	//shading.shadows 					= getShadows(vec3(1.0), position, lightMap, translucent, shading);
	//shading.shadows1 					= getShadows1(vec3(1.0), position, lightMap, translucent, shading);
	shading.ao 								= getSSAO();
	shading.specMap 					= getSpecmap(lightMap);
	//shading.volumeLight 			= getVolumetricRays();
	shading.handlight 				= getHandLight(hand, position);
	shading.torchmap 					= getTorchMap(position,shading);
	shading.roughness 				= getRoughness(lightMap, iswater);
	//shading.sss 							= getSSS(position, translucent);
	//shading.sunLD 						= getSunlightDirect(shading, position, translucent);
	shading.eGlow 						= getEmessiveGlow(color, emissive, islava);
	shading.finalShading 			= getFinalShading(position, shading, lightMap);

	//*SHADINGS--------------------------------------------------------------*//

	float volumeRays	 				= shading.volumeLight;

	vec3 emissive_glow 				= shading.eGlow;
	vec3 finalShading 				= shading.finalShading;

	//*FINALIZING COMPOSITE SHADER--------------------------------------------------------------*//


	if (land2) {
		color = emissive_glow;
		color = finalShading * color;
		#ifdef NIGHT_DESATURATION
		//color = nightDesaturation(color);
		#endif
	} else {
		color = mix(color,vec3(0.0),rainStrength);
	}
	color = pow(color,vec3(1.0 / 2.2));

	//*BAKING COLOR AND VL TO GCOLOR--------------------------------------------------------------*//

/* DRAWBUFFERS:01 */

	gl_FragData[0] = vec4(color/MAX_COLOR_RANGE, 1.0);
	gl_FragData[2] = vec4(passThroughCol, 1.0);
}
