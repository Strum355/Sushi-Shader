#version 120

//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
#define DYNAMIC_EXPOSURE					//Makes brighter inside and turned off outside
	#define DYNAMIC_EXPOSURE_AMOUNT 1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	//Strength

#define WATER_QUALITY 5 //[1 2 3 4 5] higher numbers gives better looking water

#define REFLECTIONS
	#define WATER_REFLECTIONS
	#define REFLECTION_STRENGTH 0.5 //[0.125 0.25 0.375 0.5 0.625 0.75 0.875 1.0] //Strength
	#define RAIN_REFLECTIONS
	#define SPECULAR_REFLECTIONS
	#define PBR_SUPPORT //if using a PBR resourcepack or addon, enable this

#define WATER_REFRACT		//Also includes stained glass and ice.
	#define REFRACT_MULT 10.0

#define FOG

#define WATER_DEPTH_FOG

#define CLOUDS	//2D clouds

//#define VOLUMETRIC_CLOUDS //3d clouds. WARNING!!! VERY FPS INTENSIVE. Might also bug a little bit.

#define STARS

//***************************VOLUMETRIC LIGHT***************************//
#define VOLUMETRIC_LIGHT
	#define VL_MULT 					2.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	// Simple multiplier
	#define VL_STRENGTH_DAY 			1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	// Strength of day time
	#define VL_STRENGTH_NIGHT 			1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0] // Strength of night time
	#define VL_STRENGTH_SUNSET_SUNRISE 	1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0] // Strength of sunset and sunrise time
	#define VL_STRENGTH_INSIDE 			1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	// Strength inside buildings

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

const bool 		gcolorMipmapEnabled 	= true; //gcolor texture mipmapping
const bool 		gaux1MipmapEnabled 	= true; //gaux1 texture mipmapping
const bool 		gaux4MipmapEnabled 	= true; //gaux1 texture mipmapping

//don't touch these lines if you don't know what you do!
const int maxf = 3;				//number of refinements
const float stp = 1.0;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
const float inc = 2.0;			//increasement factor at each step

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 moonVec;
varying vec3 sunVec;
varying vec3 upVec;
varying vec3 ambient_color;
varying vec3 moonlight;
varying vec3 cloudColor;
varying float moonVisibility;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux4;
uniform sampler2D gaux3;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float far;
uniform float near;
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

//Raining
float rainx = clamp(rainStrength, 0.0, 0.7);
float wetx  = clamp(wetness, 0.0f, 1.0f);

//Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float transition_fading = 1.0-(clamp((timefract-12000.0)/300.0,0.0,1.0)-clamp((timefract-13000.0)/300.0,0.0,1.0) + clamp((timefract-22800.0)/200.0,0.0,1.0)-clamp((timefract-23400.0)/200.0,0.0,1.0));

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

vec3 decode (vec2 enc)
{
    vec2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4.0);
    vec3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}

vec4 aux = texture2D(gaux1, texcoord.st);

vec3 normal = decode(texture2D(gnormal, texcoord.st).rg);
vec3 normal2 = decode(texture2D(composite, texcoord.st).rg);

vec3 color;

float sky_lightmap = aux.r;
float reflectionSkyLight = clamp(pow(sky_lightmap, 4.0) * 2.0, 0.0, 1.0);

float iswet = wetness*pow(sky_lightmap,10.0);

#include "lib/colorRange.glsl"

int iswater = int(aux.g > 0.04 && aux.g < 0.07);
int land2 = int(aux.g < 0.03);
int hand  = int(aux.g > 0.75 && aux.g < 0.85);
float istransparent = float(aux.g > 0.4 && aux.g < 0.42);
float islava = float(aux.g > 0.52 && aux.g < 0.54);
float translucent = float(aux.g > 0.39 && aux.g < 0.41);
float gold = float(aux.g > 0.69 && aux.g < 0.71);
float ice = float(aux.g > 0.09 && aux.g < 0.11);
float emissive = float(aux.g > 0.58 && aux.g < 0.62);

vec2 inverseTexel = 1.0 / vec2(viewWidth, viewHeight);

vec3 decodeColortex1(sampler2D sampler) {

	vec3 color = vec3(texture2D(sampler, texcoord.st).rg, 0.0);

	vec2 offset = texture2D(sampler, texcoord.st + vec2(inverseTexel.s, 0.0)).rg;
	vec2 offset1 = texture2D(sampler, texcoord.st - vec2(inverseTexel.s, 0.0)).rg;
	vec2 offset2 = texture2D(sampler, texcoord.st + vec2(0.0, inverseTexel.t)).rg;
	vec2 offset3 = texture2D(sampler, texcoord.st - vec2(0.0, inverseTexel.t)).rg;

	vec4 white = 1.0 - abs(vec4(offset.r, offset1.r, offset2.r, offset3.r) - color.r);

	color.b = dot(white, vec4(offset.g, offset1.g, offset2.g, offset3.g)) / dot(white, vec4(1.0));

	color = (mod(gl_FragCoord.x, 2.0) == mod(gl_FragCoord.y, 2.0))? color.rbg:color;

	color.gb -= 0.5;

	return max(pow(vec3(color.r + color.g - color.b, color.r + color.b, color.r - color.g - color.b), vec3(2.2)), 0.0);
}


vec3 specular = decodeColortex1(gaux3);
float specmap = float(aux.a > 0.7 && aux.a < 0.72) + (specular.r+specular.g*(iswet));
vec3 shadowColor = texture2DLod(gaux4, texcoord.st,1).rgb;
vec3 rawAlbedo = texture2D(gdepth,texcoord.st).rgb;

#ifdef PBR_SUPPORT
	float metallic = specular.g;
#else
	float metallic = specular.b;
#endif

float torchLightmap = aux.b;

float waveZ = mix(mix(3.0,0.25,1-istransparent), 8.0, ice);
float waveM = mix(0.0,2.0,1-istransparent+ice);
float waveS = mix(0.1,1.0,1-istransparent+ice);

mat2 time = mat2(vec2(
				((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f)),
				((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),

				vec2(
				((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))
);	//time[0].xy = sunrise and noon. time[1].xy = sunset and mindight.

vec3 sunColor = vec3(1.0,0.5,0.2) * 0.5 * time[0].x
			  + vec3(1.0,1.0,1.0) * 1.0 * time[0].y
			  + vec3(1.0,0.6,0.2) * 1.0 * (time[1].x + time[1].y);

vec3 moonColor = vec3(0.1,0.1,0.1) * 2.0 * (1.0-rainStrength);

vec3 lightColor = mix(sunColor, moonColor, TimeMidnight);

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.x-0.5),abs(coord.y-0.5))*2.0;
}

float getLinearDepth(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}


float sunSpecTime(float invert){
		return mix((1-TimeMidnight), (TimeMidnight), invert) * (1-rainStrength) * (1-isEyeInWater);
}

float convertVec3ToFloat(in vec3 invec){

	float mixing;
		mixing += invec.x;
		mixing += invec.y;
		mixing += invec.z;
		mixing /= 3.0;

	return mixing;
}

vec3 convertScreenSpaceToWorldSpace(vec2 co, float depth) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, depth) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

float saturate(float inValue){
	return clamp(inValue, 0.0, 1.0);
}

vec3 saturate(vec3 inValue){
	return clamp(inValue, 0.0, 1.0);
}

float subSurfaceScattering(vec3 vec,vec3 pos, float N) {

return (pow(max(dot(vec,normalize(pos))*0.5+0.5,0.0),N)*(N+1)/6.28)*(1-rainStrength);

}

float noisepattern(vec2 pos, float sample) {
	float noise = abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));

	noise *= sample;
	return noise;
}

vec4 cubic(float x)
{
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord)
{
	vec2 resolution = vec2(256);

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec4 BicubicTexture1(in sampler2D tex, in vec2 coord)
{
	vec2 resolution = vec2(viewWidth, viewHeight);

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2DLod(tex, vec2(offset.x, offset.z) / resolution,1);
    vec4 sample1 = texture2DLod(tex, vec2(offset.y, offset.z) / resolution,1);
    vec4 sample2 = texture2DLod(tex, vec2(offset.x, offset.w) / resolution,1);
    vec4 sample3 = texture2DLod(tex, vec2(offset.y, offset.w) / resolution,1);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

#include "lib/waterBump.glsl"

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
    return screenSpace;
}

vec3 renderGaux2(vec3 color, vec2 pos){
	vec4 albedo = texture2D(gaux2, pos.st);
	vec3 divisor = mix(vec3(1.0), color, albedo.a);
	float blend = mix(3.0, 1.25, float(iswater));
	return mix(color,albedo.rgb*( color/divisor),clamp(albedo.a * blend,0.0,1.0));
}

float startPixeldepth = texture2D(depthtex1,texcoord.st).x;
float startPixeldepth2 = texture2D(depthtex0,texcoord.st).x;

#ifdef WATER_REFRACT
float refractmask(vec2 coord, float lod){
	float mask = texture2D(gaux1, coord.st, lod).g;
	if (iswater > 0.9){
		mask = float(mask > 0.04 && mask < 0.07);
	}
	if (istransparent > 0.9){
		mask = float(mask > 0.4 && mask < 0.42);
	}
	if (ice > 0.9){
		mask = float(mask > 0.09 && mask < 0.11);
	}
	return mask;
}


	void waterRefractCoord(out vec3 refraction){
		vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
		fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));

		vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragpos,1.0);

		vec3 posxz = worldposition.xyz + cameraPosition.xyz;

		refraction = waterNormals(posxz.xz - posxz.y);

		vec2 depth = vec2(0.0);
			depth.x = getDepth(startPixeldepth);
			depth.y = getDepth(startPixeldepth2);

		float refMult = 1.0;
			refMult = clamp(depth.x - depth.y,0.0,1.0);
			refMult /= depth.y;
			refMult *= REFRACT_MULT / 100.0;
			refMult *= mix(mix(1.0,0.3,istransparent), 0.5, ice);

		refraction.xy *= refMult;
	}

vec2 refractionTexcoord(){
	vec3 refraction = vec3(0.0);

		waterRefractCoord(refraction);
		vec2 getCustomTc = texcoord.st + refraction.st;
		float refractMask = refractmask(getCustomTc, 0.0);

		getCustomTc -= refraction.st * (1-refractMask);
		//getCustomTc = mix(getCustomTc, texcoord.st, hand);

	return getCustomTc;

}

vec2 refractionTC = refractionTexcoord();
#else
vec2 refractionTC = texcoord.st;
#endif

float pixeldepth = texture2D(depthtex1,refractionTC.xy).x;
float pixeldepth2 = texture2D(depthtex0,refractionTC.xy).x;

const float pi = 3.141592653589793238462643383279502884197169;

float RayleighPhase(float cosViewSunAngle)
{
	/*
	Rayleigh phase function.
			   3
	p(θ) =	________   [1 + cos(θ)^2]
			   16π
	*/

	return (3.0 / (16.0*pi)) * (1.0 + pow(max(cosViewSunAngle, 0.0), 2.0));
}

float hgPhase(float cosViewSunAngle, float g)
{

	/*
	Henyey-Greenstein phase function.
			   1		 		1 − g^2
	p(θ) =	________   ____________________________
			   4π		[1 + g^2 − 2g cos(θ)]^(3/2)
	*/


	return (1.0 / (4.0 * pi)) * ((1.0 - pow(g, 2.0)) / pow(1.0 + pow(g, 2.0) - 2.0*g * cosViewSunAngle, 1.5));
}

vec3 totalMie(vec3 lambda, vec3 K, float T, float v)
{
	float c = (0.2 * T ) * 10E-18;
	return 0.434 * c * pi * pow((2.0 * pi) / lambda, vec3(v - 2.0)) * K;
}

vec3 totalRayleigh(vec3 lambda, float n, float N, float pn){
	return (24.0 * pow(pi, 3.0) * pow(pow(n, 2.0) - 1.0, 2.0) * (6.0 + 3.0 * pn))
	/ (N * pow(lambda, vec3(4.0)) * pow(pow(n, 2.0) + 2.0, 2.0) * (6.0 - 7.0 * pn));
}

float SunIntensity(float zenithAngleCos, float sunIntensity, float cutoffAngle, float steepness)
{
	return sunIntensity * max(0.0, 1.0 - exp(-((cutoffAngle - acos(zenithAngleCos))/steepness)));
}

vec3 Uncharted2Tonemap(vec3 x)
{

	float A = 1.2;
	float B = 0.0;
	float C = 0.6;
	float D = 1.2;
	float E = 0.1;
	float F = 1.4;

   return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 ToneMap(vec3 color, vec3 sunPos) {
    vec3 toneMappedColor;

    toneMappedColor = color * 0.04;
    toneMappedColor = Uncharted2Tonemap(toneMappedColor);

    float sunfade = 1.0-clamp(1.0-exp(-(sunPos.z/500.0)),0.0,1.0);
    toneMappedColor = pow(toneMappedColor,vec3(1.0/(1.2+(1.2*sunfade))));

    return toneMappedColor;
}

float calcSun(vec3 fragpos, vec3 sunVec){

	const float sunAngularDiameterCos = 0.99773194915;

	float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
	float sundisk = smoothstep(sunAngularDiameterCos-0.005,sunAngularDiameterCos+0.1,cosViewSunAngle);

	return 1000000.0 * sundisk * (1.0 - rainStrength);
}

float calcMoon(vec3 fragpos, vec3 moonVec){

	const float moonAngularDiameterCos = 0.99863194915;

	float cosViewSunAngle = dot(normalize(fragpos.rgb), moonVec);
	float moondisk = smoothstep(moonAngularDiameterCos,moonAngularDiameterCos+0.0005,cosViewSunAngle);

	return 70.0 * moondisk * (1.0 - rainStrength);

}

//isRef = 0 for reflections, 1 for sky
vec3 AtmosphericScattering(vec3 color, vec3 fragpos, float isRef){

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	float turbidity = 1.5;
	float rayleighCoefficient = 2.0;

	// constants for mie scattering
	const float mieCoefficient = 0.005;
	const float mieDirectionalG = 0.76;
	const float v = 4.0;

	// Wavelength of the primary colors RGB in nanometers.
	const vec3 primaryWavelengths = vec3(680, 550, 450) * 1.0E-9;

	float n = 1.00029; // refractive index of air
	float N = 2.54743E25; // number of molecules per unit volume for air at 288.15K and 1013mb (sea level -45 celsius)
	float pn = 0.03;	// depolarization factor for standard air

	// optical length at zenith for molecules
	float rayleighZenithLength = 8.4E3 ;
	float mieZenithLength = 1.25E3;

	const vec3 K = vec3(0.686, 0.678, 0.666);

	float sunIntensity = 1000.0;

	// earth shadow hack
	float cutoffAngle = pi * 0.5128205128205128;
	float steepness = 1.5;

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// Cos Angles
	float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
	float cosSunUpAngle = dot(sunVec, upVec) * 0.95 + 0.05; //Has a lower offset making it scatter when sun is below the horizon.
	float cosUpViewAngle = dot(upVec, normalize(fragpos.rgb));

	float sunE = SunIntensity(cosSunUpAngle, sunIntensity, cutoffAngle, steepness);  // Get sun intensity based on how high in the sky it is

	vec3 totalRayleigh = totalRayleigh(primaryWavelengths, n, N, pn);

	vec3 rayleighAtX = totalRayleigh * rayleighCoefficient;

	vec3 mieAtX = totalMie(primaryWavelengths, K, turbidity, v) * mieCoefficient;

	float zenithAngle = max(0.0, cosUpViewAngle);

	float rayleighOpticalLength = rayleighZenithLength / zenithAngle;
	float mieOpticalLength = mieZenithLength / zenithAngle;

	vec3 Fex = exp(-(rayleighAtX * rayleighOpticalLength + mieAtX * mieOpticalLength));
	vec3 Fexsun = vec3(exp(-(rayleighCoefficient * 0.00002853075 * rayleighOpticalLength + mieAtX * mieOpticalLength)));

	vec3 rayleighXtoEye = rayleighAtX * RayleighPhase(cosViewSunAngle);
	vec3 mieXtoEye = mieAtX *  hgPhase(cosViewSunAngle , mieDirectionalG);

	vec3 totalLightAtX = rayleighAtX + mieAtX;
	vec3 lightFromXtoEye = rayleighXtoEye + mieXtoEye;

	vec3 scattering = sunE * (lightFromXtoEye / totalLightAtX);

	vec3 sky = scattering * (1.0 - Fex);
	sky *= mix(vec3(1.0),pow(scattering * Fex,vec3(0.5)),clamp(pow(1.0-cosSunUpAngle,5.0),0.0,1.0));

	vec3 sun = sunColor * calcSun(fragpos, sunVec);
	vec3 moon = pow(moonlight, vec3(0.4545)) * calcMoon(fragpos, moonVec);

	vec3 sunMax = sunE * pow(mix(Fexsun, Fex, clamp(pow(1.0-cosUpViewAngle,4.0),0.0,1.0)), vec3(0.4545))
	* mix(0.000005, 0.00003, clamp(pow(1.0-cosSunUpAngle,3.0),0.0,1.0)) * (1.0 - rainStrength);

	float moonMax = pow(clamp(cosUpViewAngle,0.0,1.0), 0.8) * (1.0 - rainStrength);

	sky = max(ToneMap(sky, sunVec), 0.0) + (sun * sunMax + moon * moonMax)*isRef;

	float nightLightScattering = pow(max(1.0 - max(cosUpViewAngle, 0.0 ),0.0), 2.0);
	vec3 fogColor = vec3(0.2);
	sky += pow(fogColor * 0.5, vec3(2.2)) * ((nightLightScattering + 0.5 * (1.0 - nightLightScattering)) * clamp(pow(1.0-cosSunUpAngle,35.0),0.0,1.0));

	color = mix(sky, pow(fogColor, vec3(2.2)), rainStrength);

	return color;
}

vec3 getColorCorrection(vec3 color, bool land){

	//Color changes depends on time//

	color.b += color.b*0.1*TimeNoon;
	color.r -= color.r*0.17*TimeMidnight*(TimeNoon*0.4);
	color.g -= color.g*0.08*TimeMidnight;

	color.bg += color.bg*.1*(1-islava*(1-rainx));

	return color.rgb;
}

#ifdef CLOUDS
vec3 drawCloud(vec3 fposition,vec3 color, float mult, float isRef) {
		float Size = 1.0;
		vec3 sVector = normalize(fposition);
		float cosT = max(dot(normalize(sVector),upVec),0.0);
		vec3 tpos = vec3(gbufferModelViewInverse * vec4(sVector,0.0));
		vec3 wvec = normalize(tpos);
		vec3 wVector = normalize(tpos);

		vec3 cloudCol = mix(pow(sunColor, vec3(1.3)) * 2.4, vec3(0.5), rainx*isRef);
		//	cloudCol += (cloudColor*sunColor * 2.0)*(TimeNoon);
			//cloudCol += (moonlight * 1000.0)*(TimeMidnight);
			//cloudCol +=	pow(lightColor * 1.5,vec3(3.0)) * (1-transition_fading);

		float totalcloud = 0.0;

		float height = (900.0)/(wVector.y);
		vec2 wind = vec2(abs(frameTimeCounter/20000.-0.5),abs(frameTimeCounter/20000.-0.5))+vec2(0.5);

		vec3 intersection;
		float density;

		int Steps = 5;
		float weight;

		for (int i = 0; i < Steps; i++) {
			intersection = wVector * (height - i * 150 * Size / Steps); 			//curved cloud plane

			vec2 coord1 = (intersection.xz+cameraPosition.xz*2.5)/70000;
			coord1 += (wind);
			vec2 coord = (coord1/Size);

			float noise = BicubicTexture(noisetex,coord - wind * 0.5).x;
			noise += BicubicTexture(noisetex,coord*3.5).x/3.5;
			noise += BicubicTexture(noisetex,coord*6.125).x/6.125;
			//noise += BicubicTexture(noisetex,coord*12.25).x/12.25;
			noise /= clamp(texture2D(noisetex,coord / 3.1 - wind * 0.5).x * 1.3,0.0,1.0);

			noise *= mix(1.0,pow(noise, pow(2.0,-0.5)),noise);

			noise *= 7;

			float cl = max(noise-0.7,0.0);
			cl = max(cl,0.)*0.05 * (1.0 - rainx );
			density = pow(max(1-cl*2.5,0.),2.0) / 11.0 / 3.0;
			density *= 2.0;

			totalcloud += density;
			if (totalcloud > (1.0 - 1.0 / Steps + 0.1)) break;
			weight ++;

		}

		cloudCol = mix(cloudCol,cloudCol*0.1,saturate(density*15)) * 5.0;

		//cloudCol += pow(sunlight * mix(3.0,2.4,TimeSunset + TimeSunrise),vec3(mix(3.4 * (1.0 - (1.0 - transition_fading) * 0.3),1.0,TimeNoon)))* 80*pow(1-density, 50.0) * mix(1.0,0.3,1.0 - transition_fading) * 1.5 * (1-(TimeMidnight * transition_fading)) * (1-rainx);
		//cloudCol += pow(sunlight * mix(3.0,2.4,TimeSunset + TimeSunrise),vec3(mix(3.4,1.0,TimeNoon))) * 25 * (1- TimeMidnight);
		//cloudCol += moonlight * (50*(pow(1-density, 14.0))) * 500 * transition_fading * (1-rainx);
		cloudCol *= 200.0;
		cloudCol *= (1-(TimeSunrise+TimeSunset)*0.7);
		cloudCol += cloudCol * subSurfaceScattering(sunVec, fposition, 60.0)*3.0*pow(1-density, 150.0) * (1.0 - moonVisibility * 0.5) * (TimeNoon + TimeSunrise + TimeSunset + (1.0 - transition_fading));
		cloudCol += cloudCol * subSurfaceScattering(moonVec, fposition, 60.0)*3.0*pow(1-density, 150.0) * moonVisibility;

		cloudCol *= (1- (0.95 * TimeMidnight * transition_fading));
		cloudCol *= (1+ TimeNoon);
		cloudCol = mix(cloudCol,vec3(0.0),pow(1-density, 100.0));
		cloudCol *= (1-rainx);
		totalcloud = min(totalcloud / weight,1.0);

		totalcloud = mix(totalcloud,0.0,pow(1-density, 100.0));

		return mix(color.rgb,cloudCol * mult * 0.175 * 0.5 / 45.0,clamp(totalcloud * 15.0, 0.0, 1.0) * (1.0 - rainx * 0.8) * pow(cosT,2.0));
}
#endif

float luma(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 colorSaturate(in vec3 base, in float saturation) {
    return vec3(mix(base, vec3(luma(base)), -saturation));
}

#ifdef STARS
	vec3 drawStar(vec3 fposition,vec3 color) {
		float volumetric_cone = pow(max(dot(normalize(fposition),moonVec),0.0),200.0);
		vec3 sVector = normalize(fposition);
		float cosT = dot(sVector,upVec);

		//star generation

		vec3 tpos = vec3(gbufferModelViewInverse * vec4(fposition,1.0));
		vec3 wVector = normalize(tpos);
		vec3 intersection = wVector*(50.0/(wVector.y));
		vec2 coord = (intersection.xz)/146.0 + 0.1;
		float noise = texture2D(noisetex,fract(coord.xy/2.0)).r;
		noise += texture2D(noisetex,fract(coord.xy)).r/2.0;
		float star = max(noise-1.3,0.0);
		star = star * max(cosT,0.0) * 2.0 * TimeMidnight * (1-rainx);

		vec3 sum = vec3(1.0)*(1-rainx) * (1-volumetric_cone);
		vec3 s = mix(color,sum,star);
		return s;
	}
#endif



float getRainPuddles(float sizeMult, float addTime){


	vec3 pPos = vec3(refractionTC.st, pixeldepth2);
	pPos = nvec3(gbufferProjectionInverse * nvec4(pPos * 2.0 - 1.0));
	vec4 pUw = gbufferModelViewInverse * vec4(pPos,1.0);
	vec3 worldPos = (pUw.xyz + cameraPosition.xyz);

	vec2 coord = (worldPos.xz/10000 * sizeMult);

	float rainPuddles = BicubicTexture(noisetex, fract(coord.xy*8) + addTime * 2.0).x*2;
	rainPuddles += BicubicTexture(noisetex, fract(coord.xy*6) - addTime).x*3;
	//rainPuddles += BicubicTexture(noisetex, fract(coord.xy*4) + addTime).x;
//	rainPuddles += BicubicTexture(noisetex, fract(coord.xy*8) - addTime * 2.0).x;

	float strength = max(rainPuddles-1.6,0.20);
	float dL = 0.5;
	float L = (1.0 - (pow(dL,strength)));

	return L;
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}


float fastBlur (sampler2D tex,vec2 position,float res,vec2 pixelSize){
	float pixSize=pow(2.0,res);
    float blurred=
        texture2D(tex,(position+vec2(pixSize*-1.5,pixSize*-0.5))*pixelSize,res+1.0).a*4.0+
        texture2D(tex,(position+vec2(pixSize* 0.5,pixSize*-1.5))*pixelSize,res+1.0).a*4.0+
        texture2D(tex,(position+vec2(pixSize* 1.5,pixSize* 0.5))*pixelSize,res+1.0).a*4.0+
        texture2D(tex,(position+vec2(pixSize*-0.5,pixSize* 1.5))*pixelSize,res+1.0).a*4.0+
        texture2D(tex,position*pixelSize,res+1.0).a;
    blurred*=.058823529;
    return blurred;
}


#ifdef VOLUMETRIC_LIGHT
	vec3 vlColor(vec3 fogcolor,vec3 color, vec2 pos, vec3 fragpos) {

		float VolumeSample = 0.0;
		float vlWeight = 0.0;

		float depth = getLinearDepth(pixeldepth);

		for (float i = -1.0; i < 1.0; i++){
			for (float j = -1.0; j < 1.0; j++){

				vec2 offset = vec2(i,j) / vec2(viewWidth, viewHeight);

				float depth2 = getLinearDepth(texture2D(depthtex1, texcoord.st + offset * 8.0).x);

				float weight = pow(1.0 - abs(depth - depth2) * 10.0, 32.0);
					weight = max(0.1e-8, weight);

				VolumeSample += BicubicTexture1(gcolor, pos.xy + offset * 4.0).a * weight;

				vlWeight += weight;
			}
		}

		VolumeSample /= vlWeight;


		float eBS = mix(1.0,0.0,(pow(eyeBrightnessSmooth.y / 240.0f, 1.0f)));

		float Glow = pow(max(dot(normalize(fragpos),lightVector),0.0),2.5*15);
		float vlGlow = (1-Glow*-(2.5*(1+TimeNoon * 5.0)*(1+(TimeSunrise + TimeSunset)*15.)*(1-eBS))) * 0.1;

		float atmosphere = pow(max(dot(normalize(fragpos),lightVector),0.0),2.0);

		float vlInside = ((eBS * 12.5 * 0.05 * VL_STRENGTH_INSIDE * (1.0 - moonVisibility)));
		float vlInsideNight = ((eBS * 12.5 * 0.05 * VL_STRENGTH_INSIDE * (moonVisibility)));
		float vlFinalInside = (vlInside + vlInsideNight);

		vec3 vlDay = vec3(lightColor) * VL_STRENGTH_DAY * TimeNoon;
		vec3 vlNight = vec3(moonlight) * 60 * (VL_STRENGTH_NIGHT * moonVisibility);
		vec3 vlSSSR = pow(vec3(lightColor), vec3(1.0)) * (VL_STRENGTH_SUNSET_SUNRISE*2.0 * (1 - TimeNoon) * (1 - moonVisibility));
		vec3 combined = (vlDay + vlNight + vlSSSR);

		vec3 atmosphereColor = fogcolor * (1.0 - atmosphere);

		vec3 vlcolor = combined;
			vlcolor = mix(vlcolor,pow(vlcolor,vec3(1.5)) * 2.2,(TimeSunrise + TimeSunset));

			atmosphereColor = mix(atmosphereColor, vlcolor,eBS);
			vlcolor *= mix(1.0, atmosphere, 1.0);
			vlcolor += mix(atmosphereColor, vec3(0.0), 0.0);
			vlcolor *= (1 + (vlFinalInside));
			vlcolor *= (1 + (vlGlow));

			vlcolor = pow(mix(pow(max(color,0.0), vec3(2.2)), pow(vlcolor, vec3(2.2)), VolumeSample * 0.2 * VL_MULT * (1.0 - isEyeInWater) * (1.0 - rainx) * transition_fading),vec3(0.4545));
			return vlcolor;
	}
#endif


float dynamicExposure() {
		return clamp((-eyeBrightnessSmooth.y+230)/100.0,0.0,1.0);
}

vec3 dynamicExposure(vec3 color) {
		return color.rgb * clamp((-eyeBrightnessSmooth.y+230)/100.0,0.0,1.0)*2.5*(1-TimeMidnight)*(1-rainx)*DYNAMIC_EXPOSURE_AMOUNT;
}


vec3 getRainFogColor(){
		vec3 rainfogclr = vec3(0.1,0.095,0.1)* 0.75 *rainx*mix(1-TimeMidnight,1.0,(1-transition_fading) * pow(TimeSunrise + TimeSunset, 0.5));

		rainfogclr = rainfogclr*16.0*rainx;
		rainfogclr += vec3(0.1,0.095,0.1) * 0.75 * moonlight * 300.0*rainx*(TimeMidnight + (1-transition_fading));
		rainfogclr -= rainfogclr*0.9*rainx;

		return rainfogclr;
}

#ifdef FOG

vec3 getFog(vec3 color, bool land, bool land2, vec2 pos, vec3 fragpos, float depth){

	vec3 fragposFog = vec3(pos.st,depth);
	fragposFog = nvec3(gbufferProjectionInverse * nvec4(fragposFog * 2.0 - 1.0));

	vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragposFog,1.0);
	float horizon = (worldposition.y - (pos.y-cameraPosition.y));

	float calcHeight = (max(pow(max(1.5 - horizon/100.0, 0.0), 1.0)-0.0, 0.0));

	float volumetric_cone = pow(max(dot(normalize(fragposFog),lightVector),0.0),2.5)*transition_fading;

		float fog = exp(-pow(sqrt(dot(fragposFog,fragposFog))/far* 0.6 *(1-(TimeSunrise+TimeSunset)*0.4) ,2.0));
		float fog2 = exp(-pow(sqrt(dot(fragposFog,fragposFog))/250 ,2.0));
		float fog3 = exp(-pow(sqrt(dot(fragposFog,fragposFog))/140 ,2.0));
		float fogfactor =  clamp(fog + hand,0.0,1.0);
		float fogfactor2 =  clamp(fog2 + hand,0.0,1.0);
		float fogfactor3 =  clamp(fog3 + hand,0.0,1.0);

		color = pow(color, vec3(2.2));

		vec3 fogclr = AtmosphericScattering(color, upPosition, 1.0);
		vec3 fogclr2 = getRainFogColor();

		//glow

		//fogclr = mix(fogclr, pow(lightColor,vec3(2.2)) * 2.0 + fogclr, volumetric_cone*transition_fading*(1.0-TimeMidnight)*(1.0-TimeNoon)*(1.0-rainx*0.4) * 1.5);
		//fogclr += fogclr * 0.05 * volumetric_cone*2*transition_fading*TimeMidnight*(1.0-rainx)*1.0;

	//	fogclr = mix(fogclr,lightColor,volumetric_cone*TimeNoon*(1.0-rainx));

		if (land) {
			color.rgb = mix(color.rgb,pow(fogclr, vec3(2.2)),(1-fogfactor)*0.5*(1-clamp(calcHeight,0.0,1.0))*.5*(1- dynamicExposure()));
		}

		color.rgb = mix(color.rgb,pow(fogclr2, vec3(2.2)),(1-fogfactor2)*rainx);


		//altitude fog
		if (land) {
				color.rgb = mix(color.rgb,pow(fogclr, vec3(2.2)),clamp((1-fogfactor)*(1-rainx)*(1-TimeMidnight)*(clamp((calcHeight) * 0.6, 0.0, 1.0)),0.0,1.0));

				calcHeight = (max(pow(max(0.76 - horizon/300.0, 0.0), 8.0)-0.0, 0.0));
				color.rgb  = mix(color.rgb,pow(clamp(fogclr * 1.5, 0.0, 1.0), vec3(2.2)),clamp(3.0*(clamp((calcHeight) * 100, 0.0, 1.0))*(TimeMidnight)*(1- rainx)*(1-TimeSunrise)*(transition_fading)*(1-fogfactor3),0.0,1.0));
			}


	return pow(color, vec3(0.4545));
}
#endif

vec3 getSkyColor() {

	////////////////////////////////////////////////////////////////////////////////

	vec3 sclr = vec3(70.0,75,150)/1100*TimeNoon*(1.0-rainx);
		 sclr += vec3(70.0,75,150)/1100*(TimeSunrise+TimeSunset)*transition_fading*(1.0-rainx);
		 sclr += vec3(70.0,75,150)/1100*(1-transition_fading)*(TimeSunrise + TimeSunset)*(1.0-rainx);
		// sclr += vec3(ambient_color.r/5.0,ambient_color.g/5.0 - (ambient_color.g * 0.03),ambient_color.b/5.0)/3.4*moonVisibility*transition_fading*(1.0-rainx);

		 sclr += vec3((moonlight*0.5)*7.5)*(1-transition_fading)*(1-(TimeSunrise + TimeSunset))*(1.0-rainx);
		// sclr *= 2.0;
		// sclr /= 2.5;
		 sclr *= (1.0-TimeSunrise*0.35)*(1.0-TimeSunset*0.35);
		 sclr += vec3(0.1,0.095,0.1)*1.5*rainx*(1-moonVisibility);
		 sclr = mix(sclr, vec3(0.1,0.095,0.1)* 0.75 * moonlight * 20.0, rainx * (TimeMidnight + (1.0 - transition_fading)));

	return sclr;
}

#ifdef REFLECTIONS

float sunSpec(vec3 lvector, vec3 fpos, vec3 normal, float size){

	vec3 l = lvector;
	vec3 n = normal;
	vec3 p = fpos;

	vec3 r = normalize(reflect(p, n));

	return pow(clamp(dot(r,l),0.0,1.0),1250.0 / size) * 10.0;
}

vec4 raytrace(vec3 fragpos, vec3 normal, vec3 fogclr, vec3 rvector, float fresnel) {
    vec4 color = vec4(0.0);
    vec3 start = fragpos;
    vec3 vector = stp * rvector;
    vec3 oldpos = fragpos;

    fragpos += vector;
		vec3 tvector = vector;
    int sr = 0;


	    for(int i=0;i<18;i++){
        vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
        if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
        vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
        spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
        float err = distance(fragpos.xyz,spos.xyz);
        if(err < pow(sqrt(dot(vector,vector))*pow(sqrt(dot(vector,vector)),0.11),1.1)*1.1){
      			sr++;
						if(sr >= maxf){
          		float depth = texture2D(depthtex0, pos.st).r;
							bool land = depth < comp;
          		float border = clamp(1.0 - pow(cdist(pos.st), 10.0), 0.0, 1.0);
          		color = texture2D(gcolor, pos.st) * MAX_COLOR_RANGE;
				color.rgb += renderGaux2(color.rgb, pos.st);

							color.a = 1.0;

							#ifdef FOG
							color.rgb = getFog(color.rgb, land, land, pos.st, fragpos, depth);
							#endif

							color.rgb *= fresnel;

							color.rgb = land ? color.rgb : fogclr*(1.0-isEyeInWater);

							color.a *= border;
                    break;
          	}
					tvector -=vector;
                vector *=ref;


				}
        vector *= inc;
        oldpos = fragpos;
        tvector += vector;
		fragpos = start + tvector;
    }

    return color;
}

vec3 getSkyReflection(vec3 reflectedVector, vec3 color){
	vec3 sclr = AtmosphericScattering(color.rgb, reflectedVector, 0.0);
	#ifdef CLOUDS
		sclr = drawCloud(reflectedVector.xyz,sclr.rgb,2.0, 1.0) * (1.0 - isEyeInWater);
	#endif

	#ifdef STARS
		sclr = drawStar(reflectedVector.xyz,sclr.rgb) * (1.0 - isEyeInWater);
	#endif

	return sclr;
}

#endif

float getWaterDepth(vec3 fragpos, vec3 fragpos2){

	vec3 uVec = fragpos-fragpos2;

	float UNdotUP = abs(dot(normalize(uVec),normal2));
	float depth = sqrt(dot(uVec,uVec))*UNdotUP;

	return depth;
}


#ifdef VOLUMETRIC_CLOUDS

// dirived from: http://devlog-martinsh.blogspot.nl/2011/03/glsl-8x8-bayer-matrix-dithering.html
float find_closest(vec2 pos)
{
 const int ditherPattern[64] = int[64](
  0, 32, 8, 40, 2, 34, 10, 42, /* 8x8 Bayer ordered dithering */
  48, 16, 56, 24, 50, 18, 58, 26, /* pattern. Each input pixel */
  12, 44, 4, 36, 14, 46, 6, 38, /* is scaled to the 0..63 range */
  60, 28, 52, 20, 62, 30, 54, 22, /* before looking in this table */
  3, 35, 11, 43, 1, 33, 9, 41, /* to determine the action. */
  51, 19, 59, 27, 49, 17, 57, 25,
  15, 47, 7, 39, 13, 45, 5, 37,
  63, 31, 55, 23, 61, 29, 53, 21);

 vec2 positon = vec2(0.0f);
      positon.x = floor(mod(texcoord.s * viewWidth, 8.0f));
	  positon.y = floor(mod(texcoord.t * viewHeight, 8.0f));

	int dither = ditherPattern[int(positon.x) + int(positon.y) * 8];

	return float(dither) / 64.0f;
}

float distx(float dist)
{
	return (far * (dist - near)) / (dist * (far - near));
}

float mod289(float x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 perm(vec4 x)
{
	return mod289(((x * 34.0) + 1.0) * x);
}

float noise(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return max(((o4.y * d.y + o4.x * (1.0 - d.y))),0.0);
}

float fbm(vec3 pos, float time){

	pos += time / 8.0;

	float f = 0.33, frq = 1.0, ap = 0.4;

    f += noise(pos*frq)*ap; frq *= 5.0; ap *= 0.05;
    f += noise(pos*frq)*ap; frq *= 1.0; ap *= 1.5;
    f += noise(pos*frq)*ap; frq *= 2.0; ap *= 1.5;
    f += noise(pos*frq)*ap;

	return f;

}

vec4 getClouds(in vec3 rayworldposition, float steps, vec3 fragpos, vec3 color){

	float height = 325.0;
	float cloudShapeMult = 2.0;

	float alhpa;
	vec3 cloudCol;

	cloudShapeMult = cloudShapeMult * (1.0 + (rayworldposition.y * 0.5));
			float cloudy = height + cloudShapeMult;
			float cloudy2 = height - cloudShapeMult;

			if (rayworldposition.y < cloudy2 || rayworldposition.y > cloudy)
				return vec4(0.0f);
			else {

			vec3 uv = rayworldposition.xyz / 100.0;
			float time = frameTimeCounter / 5.0;
			uv.x -= time * 0.02;

			float noise1  = fbm(uv, time);

			float alt = 1.0 - clamp(sqrt(pow(rayworldposition.y - height,2.0)) / cloudShapeMult, 0.0, 1.0);

			float coverage = 0.93 - rainStrength * 0.93;

			noise1 *= pow(alt * 1.7 * coverage,1.2);
			noise1 = pow(noise1, 50.0);

			if (noise1 < 0.001)
			{
				return vec4(0.0);
			}

			alhpa = noise1;

			float sunGlow = pow(max(dot(normalize(fragpos),lightVector),0.0),50.0) * transition_fading;

			vec3 lightColor = mix(lightColor, moonlight * 10.0, TimeMidnight) * 1.5;
				lightColor = mix(lightColor, pow(lightColor, vec3(2.2)),TimeSunrise + TimeSunset);
				lightColor = mix(lightColor,lightColor * 0.1, 0.1 * (min(1.0, noise1)));
				lightColor *= 1.0 + sunGlow;

			cloudCol = lightColor;

			return vec4(cloudCol * 0.01 * steps, alhpa);
		}

}

vec3 CloudRaymarch(float minDist){

			vec4 rayworldposition;

			vec4 rayfragposition = nvec4(convertScreenSpaceToWorldSpace(texcoord.st,distx(minDist)));

			rayworldposition = gbufferModelViewInverse * rayfragposition;
			rayworldposition /= rayworldposition.w;

			rayworldposition.xyz += cameraPosition.xyz;

			return rayworldposition.rgb;
}

vec3 rayMarching(vec3 color, bool land, vec3 fragpos, vec3 worldposition){

		vec3 wpos = worldposition;
		float worldDistance = sqrt(dot(wpos,wpos));

		float worldPositionSize = 500.0 / (16*16);

		vec4 cloudColor;
		vec4 clouds;

		float steps = far / 10.0;

		float ditherPattern = find_closest(texcoord.st);
		ditherPattern *= steps;

		float minDist = far - 10.0;
			minDist += ditherPattern;

		float weight = (minDist / steps);

		while (minDist > 0.0) {

			vec3 rayworldposition = CloudRaymarch(minDist);

			clouds += getClouds(rayworldposition.rgb * worldPositionSize, steps, fragpos, color);

			float marchDist = sqrt(dot((rayworldposition - cameraPosition) / worldPositionSize,(rayworldposition - cameraPosition) / worldPositionSize));

			if (worldDistance < marchDist * worldPositionSize  && land)
				clouds.a *= 0.0;

			minDist = minDist - steps;

			cloudColor.rgb = clouds.rgb;
			cloudColor.a = clouds.a;

		}

		cloudColor.a /= weight;

		color.rgb = pow(mix(pow(color.rgb, vec3(2.2)), pow(cloudColor.rgb * 2.0, vec3(2.2)), min(1.0, cloudColor.a)), vec3(0.4545));

		return color;
}

#endif


float calcWaterSSS(vec3 normal){

	const float wrap = 0.2;
	const float scatterWidth = 0.5;

	float NdotL = dot(normal, lightVector);
	float NdotLWrap = (NdotL + wrap) / (1.0 + wrap);
	float scatter = smoothstep(0.0, scatterWidth, NdotLWrap) * smoothstep(scatterWidth * 2.0, scatterWidth, NdotLWrap);

	return scatter;
}

float pow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

float Fresnel(float f0, float VoH) {
	return f0 + (1.0 - f0) * pow5(1.0 - VoH);
}

vec2 random(vec2 p)
{
	p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx+19.19);
    return fract((p.xx+p.yx)*p.xy)*2.-1.;

}


//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {

	bool land = pixeldepth < comp;
	bool land2 = pixeldepth2 < comp;

	vec4 currentPosition = vec4(refractionTC.x * 2.0 - 1.0, refractionTC.y * 2.0 - 1.0, 2.0 * pixeldepth - 1.0, 1.0);

	vec4 fragposition = gbufferProjectionInverse * currentPosition;
		 fragposition = gbufferModelViewInverse * fragposition;
		 fragposition /= fragposition.w;
		 fragposition.xyz += cameraPosition;

	vec4 previousPosition = fragposition;
		 previousPosition.xyz -= previousCameraPosition;
		 previousPosition = gbufferPreviousModelView * previousPosition;
		 previousPosition = gbufferPreviousProjection * previousPosition;
		 previousPosition /= previousPosition.w;

	vec3 fragpos = vec3(texcoord.st, startPixeldepth2);
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));

	vec3 fragpos2 = vec3(refractionTC.st, pixeldepth);
	fragpos2 = nvec3(gbufferProjectionInverse * nvec4(fragpos2 * 2.0 - 1.0));

	vec3 normal3;
	if(iswater + istransparent+ice > 0.9){
		normal3 = normal2;
	}else{
		normal3 = normal;
	}

	vec4 sPos = gbufferProjectionInverse * (vec4(texcoord.st,startPixeldepth2,1.0) * 2.0 - 1.0);
	sPos /= sPos.w;

	vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragpos,1.0);



	#ifdef WATER_REFRACT
		color = mix(texture2D(gcolor, texcoord.st).rgb*MAX_COLOR_RANGE,texture2D(gcolor,refractionTC.xy).rgb * MAX_COLOR_RANGE, iswater+ice+istransparent);
	#else
		color = texture2D(gcolor, texcoord.st).rgb * MAX_COLOR_RANGE;
	#endif

	float depth = getWaterDepth(fragpos, fragpos2);

	if(!land) color = AtmosphericScattering(color, fragpos.rgb, 1.0);

	#ifdef CLOUDS
		if (!land)	color.rgb = drawCloud(fragpos2.xyz,color.rgb,3.0, 0.0);
	#endif

	#ifdef STARS
		if (!land)	color.rgb = drawStar(fragpos2.xyz,color.rgb);
	#endif

	// setting up light color
	//	vec3 light_col = mix(pow(sunlight * (transition_fading * (1.0 - TimeMidnight)),vec3(4.4)), moonlight*50, moonVisibility * transition_fading * TimeMidnight * (1.0 - (TimeSunrise + TimeSunset)));
		vec3 light_col = lightColor;
	//	light_col = mix(light_col,vec3(sqrt(dot(light_col,light_col)))*vec3(0.25,0.32,0.4),rainx);
	//	light_col = pow(light_col,mix(vec3(1.0 / 5.0),vec3(0.5), pow(TimeSunrise + TimeSunset,3.0) + TimeMidnight));
	//	light_col = mix(light_col, vec3(0.5), rainStrength);

		float normalDotEye = dot(normal2, normalize(fragpos));

		vec3 fresnel = vec3(saturate(pow(1.0 + normalDotEye, 1.0)));
		fresnel.y = clamp(pow(1.0 + normalDotEye, 0.75),0.0,1.0);

		normalDotEye = dot(normal, normalize(fragpos));

		fresnel.z = clamp(pow(1.0 + normalDotEye, 1.0),0.0,1.0);
		fresnel.xz = pow(fresnel.xz,vec2(2.0));
	//	fresnel.x = mix(fresnel.x, 1.0, specular.g);


		vec3 reflectedVector1 = reflect(normalize(fragpos.xyz), normal2);
		vec3 hV= normalize(normalize(reflectedVector1) + normalize(-fragpos.xyz));
		float NdotE = dot(hV, normalize(fragpos.xyz));
		float F0 = mix(bool(iswater)? 0.1 : 0.1, 0.8, metallic);
		float fresnel1 = pow(clamp(1.0 + NdotE,0.0,1.0), 4.0) ;
		fresnel1 = fresnel1+F0*(1.0-fresnel1);


		float depthMap = clamp(exp(-depth / 2.0),0.0,1.0);

		vec3 npos = normalize(fragpos);

		vec3 reflectedVector2 = normalize(reflect(npos, normalize(normal2)));
		vec3 reflectedVector = normalize(reflect(npos, normalize(normal)));
		vec3 reflectedVector3 = normalize(reflect(npos, normalize(normal3)));

		#ifdef WATER_DEPTH_FOG
		fresnel.y = pow(fresnel.y, 2.2);
			fresnel.y += pow(1-depthMap, 2.2);
			fresnel.y = pow(min(fresnel.y,1.0), 0.4545);

			fresnel.y *= iswater;

			vec3 waterFogClr = max(getSkyColor(), vec3(0.02));

			waterFogClr = mix(waterFogClr + mix(vec3(0.0,waterFogClr.g * 0.5 * pow(depthMap, 0.2),0.0),vec3(0.0), pow(rainStrength, 0.75)), (waterFogClr + mix(vec3(0.0,waterFogClr.g,0.0) * 0.75 * light_col, vec3(0.0), pow(rainStrength, 0.75))) * light_col * 3.0, vec3(calcWaterSSS(normal2)) * transition_fading) * 0.75 * mix(0.5,1.0,pow(depthMap, 0.2));

			color.rgb = pow(mix(pow(color, vec3(0.4545)), pow(waterFogClr, vec3(0.4545)) * sky_lightmap,pow(fresnel.y,1.0)*iswater*(1-isEyeInWater)), vec3(2.2));
		#endif

	#ifdef REFLECTIONS
			vec4 reflection = vec4(0.0);
			vec3 specColor = mix(vec3(1.0), pow(rawAlbedo*1.5, vec3(2.2)), metallic);
			color = mix(color, vec3(0.0), metallic);
			vec3 getSky = getSkyReflection(reflectedVector3, color.rgb)*float(land2);
			getSky *= fresnel1;
			float specularTime = sunSpecTime(0.0);
			float specularTime1 = sunSpecTime(1.0);
			float spec = sunSpec(sunVec, fragpos, normal3, 1.0) * specularTime*3;

						spec += sunSpec(moonVec, fragpos, normal2, 50.0) * specularTime1 * (istransparent + iswater) * 0.001;
						spec += sunSpec(moonVec, fragpos, normal2, 1.0) * specularTime1 * (istransparent + iswater) * 0.7;

			getSky += spec* (light_col*2.0+iswater)*shadowColor;
			getSky *= specColor;
			getSky *= specmap+iswater+istransparent+ice;

			reflection = raytrace(fragpos, normal3, getSky, reflectedVector3, fresnel1);
		//	reflection.rgb = saturate(reflection);

			if (iswater > 0.9 || istransparent > 0.9 || ice > 0.9) {
				#ifdef WATER_REFLECTIONS
					reflection.rgb = mix(getSky , reflection.rgb, reflection.a);
					reflection.a = 1.0;
					color.rgb += reflection.rgb;
				#endif
			} else if(float(land) > 0.9) {

			//	reflection = raytrace(fragpos, normal2, getSky, reflectedVector, fresnel1);
				reflection.rgb = mix(getSky * reflectionSkyLight, reflection.rgb, reflection.a);
				reflection.a = 1.0;
				reflection.rgb *= specColor;

				#ifdef RAIN_REFLECTIONS

				float rainPuddles = getRainPuddles(1.0, 0.0);
					color.rgb += pow(reflection.rgb, vec3(2.2))*reflection.a*saturate(pow(iswet, 10.0))*(1.0-specmap) * (rainPuddles + .05*(1-(rainPuddles)))* 15.0*(1-isEyeInWater);
				#endif

				#ifdef SPECULAR_REFLECTIONS
					vec3 specCol = mix(vec3(0.0), shadowColor, metallic);
					color.rgb += clamp((reflection.rgb*reflection.a)*specmap, vec3(0.0), vec3(1.0));
				#endif
			}

	#endif

	#ifdef FOG
		if (!land && land2)color.rgb = mix(color,getRainFogColor(),pow(rainx,4.0));
	#else
		if (!land)color.rgb = mix(color,getRainFogColor(),pow(rainx,4.0));
	#endif

	vec3 forwardRenderingAlbedo = renderGaux2(color, texcoord.st);

	color = forwardRenderingAlbedo;

		vec3 vlFogColor = ambient_color;
	vlFogColor.g -= vlFogColor.g * 0.2;

	#ifdef GODRAYS
		color.rgb = getGodrays(fragpos);
	#endif

	#ifdef FOG
		color.rgb = getFog(color, land2, land, refractionTC.st, fragpos, pixeldepth2);
	#endif

	#ifdef VOLUMETRIC_CLOUDS
		vec3 threeDimClouds = rayMarching(color, land, fragpos2, worldposition.xyz);
		threeDimClouds = renderGaux2(threeDimClouds, refractionTC);

		color = color.rgb = (threeDimClouds - forwardRenderingAlbedo) + color;
	#endif

	#ifdef VOLUMETRIC_LIGHT
		color.rgb = vlColor(vlFogColor, color.rgb, refractionTC.st, fragpos2);;
	#endif

	float depth_diff = pow(clamp(sqrt(dot(fragpos,fragpos)) * 0.01,0.0,1.0), 0.05);
	color.rgb = pow(mix(pow(color.rgb, vec3(2.2)),pow(clamp(getSkyColor() + mix(vec3(0.0,getSkyColor().g * 0.3, 0.0),vec3(0.0), pow(rainStrength, 0.75)),0.0,1.0) * 0.25, vec3(2.2)),depth_diff*isEyeInWater),vec3(0.4545));
	//	color = normal2;
	  color += dynamicExposure(color);
	  //color.rgb = getColorCorrection(color,land);
	//color = vec3(shadowColor);
	//color = mix(color, vec3(1.0),vec3(clamp(exp(-depth * 5.0),0.0,1.0)) * iswater * pow(getRainPuddles(20.0, frameTimeCounter / 2000.0),1.0));
/* DRAWBUFFERS:0 */

	gl_FragData[0] = vec4(color / MAX_COLOR_RANGE,1.0);

}
