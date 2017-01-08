#version 120
#extension GL_ARB_shader_texture_lod : enable

#define MAX_COLOR_RANGE 24.0 //[1.0 2.0 4.0 6.0 12.0 24.0 48.0 96.0]
//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//

//***************************GODRAYS***************************//

//#define GODRAYS
	const float exposure = 0.25;
	const float density = 1;
	const int NUM_SAMPLES = 10;			//increase this for better quality at the cost of performance
	const float grnoise = 1.0;		//amount of noise /0.0 is default

//***************************REFLECTIONS***************************//

#define REFLECTIONS
	#define WATER_REFLECTIONS
	#define REFLECTION_STRENGTH 0.5 //[0.125 0.25 0.375 0.5 0.625 0.75 0.875 1.0] //Strength
	#define RAIN_REFLECTIONS
	#define SPECULAR_REFLECTIONS

//***************************VISUALS***************************//

#define WATER_REFRACT		//Also includes stained glass and ice.
	#define REFRACT_MULT 10.0

#define WATER_CAUSTIC
	#define CAUSTIC_STRENGHT 3.0

#define FOG

#define WATER_DEPTH_FOG

//***************************CLOUDS***************************//

#define Clouds	//2d clouds

//#define VOLUMETRIC_CLOUDS //3d clouds. WARNING!!! VERY FPS INTENSIVE. Might also bug a little bit.

//***************************VISUALS***************************//

#define Stars

//***************************VOLUMETRIC LIGHT***************************//
#define VOLUMETRIC_LIGHT
	#define VL_MULT 					1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	// Simple multiplier
	#define VL_STRENGTH_DAY 			1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	// Strength of day time
	#define VL_STRENGTH_NIGHT 			1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0] // Strength of night time
	#define VL_STRENGTH_SUNSET_SUNRISE 	1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0] // Strength of sunset and sunrise time
	#define VL_STRENGTH_INSIDE 			1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	// Strength inside buildings

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

const bool 		gcolorMipmapEnabled 	= true; //gcolor texture mipmapping
const bool 		gaux1MipmapEnabled 	= true; //gaux1 texture mipmapping
const bool 		gaux4MipmapEnabled 	= true; //gaux4 texture mipmapping


//don't touch these lines if you don't know what you do!
const int maxf = 3;				//number of refinements
const float stp = 1.0;			//size of one step for raytracing algorithm
const float ref = 0.9;			//refinement multiplier
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
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux3;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform sampler2D gaux4;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 sunPosition;
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
float rainx = clamp(rainStrength, 0.0f, 0.5f);
float wetx  = clamp(wetness, 0.0f, 1.0f);

//Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float transition_fading = 1.0-(clamp((timefract-12000.0)/300.0,0.0,1.0)-clamp((timefract-13000.0)/300.0,0.0,1.0) + clamp((timefract-22800.0)/200.0,0.0,1.0)-clamp((timefract-23400.0)/200.0,0.0,1.0));

mat2 time = mat2(vec2(
				((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f)),
				((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),

				vec2(
				((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))

);
vec3 sunColor = vec3(1.0,0.7,0.3) * 0.7 * time[0].x * (1.0-rainStrength) +		//Sunrise
								vec3(1.0,1.0,1.0) * 1.0 * time[0].y * (1.0-rainStrength) +		//Noon
								vec3(1.0,0.5,0.2) * 0.7 * (time[1].x + time[1].y) * (1.0-rainStrength) +		//Sunset
								//vec3(0.1,0.11,0.15) * 1.0 * (1.0-rainStrength) +	//Midnight
								vec3(0.1, 0.1, 0.1) * 0.3 * rainStrength;						//Rain

vec3 skyColor = vec3(0.3,0.4,0.8) * 0.2 * time[0].x * (1.0-rainStrength) +		//Sunrise
								vec3(0.25,0.5,0.80) * 0.3 * time[0].y * (1.0-rainStrength) +		//Noon
								vec3(0.3,0.4,0.8) * 0.2 * time[1].x * (1.0-rainStrength) +		//Sunset
								vec3(0.13,0.15,0.2) * 0.01 * time[1].y * (1.0-rainStrength) +	//Midnight
								vec3(0.3,0.3,0.3) * 0.1 * rainStrength;							//Rain

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

vec4 aux = texture2D(gaux1, texcoord.st);

vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
vec3 normal2 = (texture2D(composite, texcoord.st).rgb * 2.0 - 1.0);


float sky_lightmap = aux.r;
float reflectionSkyLight = clamp(pow(sky_lightmap, 4.0) * 2.0, 0.0, 1.0);

float iswet = wetness*pow(sky_lightmap,10.0);

vec3 specular = pow(texture2D(gaux3,texcoord.xy).rgb,vec3(2.2));
float specmap = float(aux.a > 0.7 && aux.a < 0.72) + (specular.r+specular.g*(iswet));

// Coloured volumetric light
vec4 colsample = texture2D(gcolor,texcoord.xy,0);
vec3 color = colsample.rgb * MAX_COLOR_RANGE;

int iswater = int(aux.g > 0.04 && aux.g < 0.07);
int land2 = int(aux.g < 0.03);
int hand  = int(aux.g > 0.75 && aux.g < 0.85);
int isIce = int(aux.g > 0.94 && aux.g < 0.96);
int portal = int(aux.g > 0.97 && aux.g < 0.99);
float istransparent = float(aux.g > 0.4 && aux.g < 0.42)+isIce+portal;
float islava = float(aux.g > 0.50 && aux.g < 0.55);



float torchLightmap = aux.b;

float saturate(float inValue){
	float outValue =	clamp(inValue, 0.0, 1.0);
return outValue;
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
	int resolution = 2048;

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


float saturationValue(){
	float satValue;
	if(isIce > 0.9){
		satValue = 1.0;
	}else if(iswater > 0.9){
		satValue = 1.0;
	}else if(hand > 0.9){
		satValue = 2.0;
		}else{
		satValue = 2;
	}
	return satValue;
}

vec3 renderGaux2(vec3 color, vec2 pos){
	vec4 stainedColor = texture2D(gaux2, pos.st).rgba;

	float saturation = 1.2;
	float avg = (stainedColor.r + stainedColor.g + stainedColor.b);
	stainedColor.rgb = (((stainedColor.rgb - avg )*saturation)+avg);

	float satValue = saturationValue();
	float mixAmount = mix(stainedColor.a*satValue, 1.0, float(isIce));
	vec3 divisionAmount = mix(vec3(1.0),mix(color.rgb, vec3(1.0), TimeMidnight), saturate(isIce));

	return mix(color,stainedColor.rgb*(color/divisionAmount),saturate(mixAmount*satValue));
//return mix(color,stainedColor.rgb * 1.5 * color,clamp(stainedColor.a * 1.25,0.0,1.0));

}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.x-0.5),abs(coord.y-0.5))*2.0;
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
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

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
    return screenSpace;
}

float subSurfaceScattering(vec3 vec,vec3 pos, float N) {

return pow(max(dot(vec,normalize(pos))*0.5+0.5,0.0),N)*(N+1)/6.28;

}

const float pi = 3.141592653589793238462643383279502884197169;

float RayleighPhase(float cosViewSunAngle)
{
return (3.0 / (16.0*pi)) * (1.0 + pow(clamp(cosViewSunAngle, 0.0, 1.0), 2.0));
}

vec3 totalMie(vec3 primaryWavelengths, vec3 K, float T, float v)
{
float c = (0.2 * T ) * 10E-18;
return 0.434 * c * pi * pow((2.0 * pi) / primaryWavelengths, vec3(v - 2.0)) * K;
}

float hgPhase(float cosViewSunAngle, float g)
{
return (1.0 / (4.0*pi)) * ((1.0 - pow(g, 2.0)) / pow(1.0 - 2.0*g*cosViewSunAngle + pow(g, 2.0), 1.5));
}

float SunIntensity(float zenithAngleCos, float sunIntensity, float cutoffAngle, float steepness)
{
return sunIntensity * max(0.0, 1.0 - exp(-((cutoffAngle - acos(zenithAngleCos))/steepness)));
}

float A = 0.80;
float B = 0.20;
float C = 0.10;
float D = 0.20;
float E = 0.03;
float F = 0.30;
float W = 1000.0;

vec3 Uncharted2Tonemap(vec3 x)
{
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

const float sunAngularDiameterCos = 0.99733194915;

float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
float sundisk = smoothstep(sunAngularDiameterCos,sunAngularDiameterCos+0.0002,cosViewSunAngle);

return 1200.0 * sundisk * (1.0 - rainStrength);

}

float calcMoon(vec3 fragpos, vec3 moonVec){

const float moonAngularDiameterCos = 0.99833194915;

float cosViewSunAngle = dot(normalize(fragpos.rgb), moonVec);
float moondisk = smoothstep(moonAngularDiameterCos,moonAngularDiameterCos+0.001,cosViewSunAngle);

return clamp(10.0 * moondisk, 0.0, 15.0) * (1.0 - rainStrength);

}

vec3 getAtmosphericScattering(vec3 color, vec3 fragpos, float sunMoonMult, vec3 fogColor, out vec3 sunMax, out float moonMax){

	float turbidity = 1.5;
	float rayleighCoefficient = 2.0;

	// constants for mie scattering
	const float mieCoefficient = 0.005;
	const float mieDirectionalG = 0.86;

	// wavelength of used primaries, according to preetham
	const vec3 primaryWavelengths = vec3(680E-9, 550E-9, 450E-9);
	vec3 totalRayleigh =  vec3( 0.00000580453, 0.00001178534, 0.00002853075);

	const float v = 4.0;

	// optical length at zenith for molecules
	float rayleighZenithLength = 8.4E3 ;
	float mieZenithLength = 1.25E3;

	float sunIntensity = 1000.0;

	// earth shadow hack
	float cutoffAngle = pi/1.95;
	float steepness = 1.5;

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	vec3 upVec = normalize(upPosition);
	vec3 sunVec = normalize(sunPosition);
	vec3 moonVec = normalize(-sunPosition);

	// Cos Angles
	float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
	float cosSunUpAngle = dot(sunVec, upVec) * 0.95 + 0.05; //Has a lower offset making it scatter when sun is below the horizon.
	float cosUpViewAngle = dot(upVec, normalize(fragpos.rgb));

	float sunE = SunIntensity(cosSunUpAngle, sunIntensity, cutoffAngle, steepness);  // Get sun intensity based on how high in the sky it is

	vec3 rayleighAtX = totalRayleigh * rayleighCoefficient;

	vec3 mieAtX = totalMie(primaryWavelengths, sunColor, turbidity, v) * mieCoefficient;

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

	sunMax = sunE * pow(mix(Fexsun, Fex, clamp(pow(1.0-cosUpViewAngle,4.0),0.0,1.0)), vec3(0.4545))
	* mix(0.000005, 0.00003, clamp(pow(1.0-cosSunUpAngle,3.0),0.0,1.0)) * (1.0 - rainStrength);

	moonMax = pow(clamp(cosUpViewAngle,0.0,1.0), 0.8) * (1.0 - rainStrength);

	sky = ToneMap(sky, sunVec) + (sun * sunMax + moon * moonMax) * sunMoonMult;
	sky = max(sky,0.0);

	float nightLightScattering = pow(max(1.0 - max(cosUpViewAngle, 0.0 ),0.0), 2.0);

	sky += pow(skyColor, vec3(0.4545)) * ((nightLightScattering + 0.25 * (1.0 - nightLightScattering)) * clamp(pow(1.0-cosSunUpAngle,75.0),0.0,1.0) );

	color = mix(sky, pow(skyColor, vec3(0.4545)), rainStrength);

	return color;
}


float waterH(vec2 posxz, float speed, float size, float iswater) {

	vec2 movement = vec2(abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement2 = vec2(-abs(frameTimeCounter/1000.-0.5),abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement3 = vec2(-abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement4 = vec2(abs(frameTimeCounter/1000.-0.5),-abs(frameTimeCounter/1000.-0.5))*speed;

	vec2 coord = (posxz/600)+(movement);
	vec2 coord1 = (posxz/599.9)+(movement2/5);
	vec2 coord2 = (posxz/599.8)+(movement3/5);
	vec2 coord3 = (posxz/599.7)+(movement4);
	vec2 coord4 = (posxz/1600)+(movement/1.5);
	vec2 coord5 = (posxz/1599)+(movement2/1.5);
	vec2 coord6 = (posxz/1598)+(movement3/1.5);
	vec2 coord7 = (posxz/1597)+(movement4/1.5);
	vec2 coord8 = (posxz/600);



	float noise = texture2DLod(noisetex, vec2(coord.x, -coord.y*2),4).x;
	noise += texture2DLod(noisetex, vec2(-coord2.x, coord2.y),4).x;
	noise += texture2DLod(noisetex, vec2(coord3.x, -coord3.y*3),4).x;
	noise += texture2DLod(noisetex, vec2(-coord6.x*2, coord4.y),4).x;
	noise += texture2DLod(noisetex, vec2(coord7.x, -coord5.y),4).x;

	return noise/10;
}

vec3 getWaveHeight(vec2 posxz, float iswater, float istransparent){

	vec2 coord = posxz;

		float deltaPos = 0.22;

		float waveZ = mix(0.200,1,iswater);
		float waveM = mix(0.0,1.0,iswater+portal);

		float h0 = waterH(coord, waveM, waveZ, istransparent);
		float h1 = waterH(coord + vec2(deltaPos,0.0), waveM, waveZ, iswater);
		float h2 = waterH(coord + vec2(-deltaPos,0.0), waveM, waveZ, iswater);
		float h3 = waterH(coord + vec2(0.0,deltaPos), waveM, waveZ, iswater);
		float h4 = waterH(coord + vec2(0.0,-deltaPos), waveM, waveZ, iswater);

		float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
		float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}


float noisepattern(vec2 pos, float sample) {
	float noise = abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));

	noise *= sample;
	return noise;
}

float startPixeldepth = texture2D(depthtex1,texcoord.st).x;
float startPixeldepth2 = texture2D(depthtex0,texcoord.st).x;
float refractionMult = mix(100.0, 15.0, float(istransparent));

float refractmask(vec2 coord, float lod){

	float mask = texture2D(gaux1, coord.st, lod).g;

	if (iswater > 0.9){
		mask = float(mask > 0.04 && mask < 0.07);
	}

	if (istransparent > 0.9){
		mask = float(mask > 0.4 && mask < 0.42)+float(mask > 0.94 && mask < 0.96)+float(mask > 0.97 && mask < 0.99);
	}

	return mask;

}

#ifdef WATER_REFRACT

	void waterRefractCoord(out float maskCoord1, out float maskCoord2, out float maskCoord3, out vec2 coord1, out vec2 coord2, out vec2 coord3, out vec3 refraction){

	vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
		fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));

		vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragpos,1.0);

		vec3 posxz = worldposition.xyz + cameraPosition.xyz;

		float getAngle = dot(normal2, normalize(fragpos));
		float dispersionMult = clamp(pow(1.0 + getAngle, 1.0),0.0,1.0);
		dispersionMult = pow(dispersionMult,1.0 - getAngle);

		float dispersion = 0.25 * dispersionMult;

		refraction = getWaveHeight(posxz.xz - posxz.y, iswater, istransparent);

		vec2 depth = vec2(0.0);
			depth.x = getDepth(startPixeldepth);
			depth.y = getDepth(startPixeldepth2);

		float refMult = 1.0;
			refMult = clamp(depth.x - depth.y,0.0,1.0);
			refMult /= depth.y;
			refMult *= REFRACT_MULT / refractionMult;
			refMult *= mix(1.0,0.1,istransparent);

		dispersion *= refMult;

		coord1 = texcoord.st + refraction.xy * refMult;
		coord2 = texcoord.st + refraction.xy * (refMult + dispersion);
		coord3 = texcoord.st + refraction.xy * (refMult + dispersion * 2.0);

		refraction.xy *= refMult;

		maskCoord1 = refractmask(coord1, 0.0);
		maskCoord2 = refractmask(coord2, 0.0);
		maskCoord3 = refractmask(coord3, 0.0);
	}

#endif

vec2 refractionTexcoord(){

	float maskCoord1 = 0.0;
	float maskCoord2 = 0.0;
	float maskCoord3 = 0.0;

	vec2 coord1 = vec2(0.0);
	vec2 coord2 = vec2(0.0);
	vec2 coord3 = vec2(0.0);

	vec3 refraction = vec3(0.0);

	#ifdef WATER_REFRACT
		waterRefractCoord(maskCoord1, maskCoord2, maskCoord3, coord1, coord2, coord3, refraction);
		vec2 getCustomTc = texcoord.st + refraction.st;
		float refractMask = refractmask(getCustomTc, 0.0);

		getCustomTc -= refraction.st * (1-refractMask);
		getCustomTc = mix(getCustomTc, texcoord.st, hand);
	#else
		vec2 getCustomTc = texcoord.st;
	#endif

	return getCustomTc;

}

vec2 refractionTC = refractionTexcoord();
float pixeldepth = texture2D(depthtex1,refractionTC.xy,0).x;
float pixeldepth2 = texture2D(depthtex0,refractionTC.xy,0).x;

#ifdef Clouds

vec3 drawCloud(vec3 fposition,vec3 color, float mult) {
			float Size = 1.0;
			vec3 sVector = normalize(fposition);
			float cosT = max(dot(normalize(sVector),upVec),0.0);
			vec3 tpos = vec3(gbufferModelViewInverse * vec4(sVector,0.0));
			vec3 wvec = normalize(tpos);
			vec3 wVector = normalize(tpos);

			vec3 cloudCol = pow(sunColor * 2.4,vec3(3.4))*(TimeSunrise+TimeSunset);
				cloudCol += (cloudColor * 2.0)*(TimeNoon);
				cloudCol += (moonlight * 1000.0)*(TimeMidnight);
				cloudCol +=	pow(sunColor * 1.5,vec3(3.0)) * (1-transition_fading);

			float totalcloud = 0.0;

			float height = (700.0)/(wVector.y);
			vec2 wind = vec2(abs(frameTimeCounter/20000.-0.5),abs(frameTimeCounter/20000.-0.5))+vec2(0.5);

			vec3 intersection;
			float density;

			int Steps = 5;
			float weight;

			for (int i = 0; i < 5; i++) {
				intersection = wVector * (height - i * 150 * Size / Steps); 			//curved cloud plane

				vec2 coord1 = (intersection.xz+cameraPosition.xz*2.5)/200000;
				coord1 += (wind);
				vec2 coord = (coord1/Size);

				float noise = texture2D(noisetex,coord - wind * 0.5).x;
				noise += texture2D(noisetex,coord*3.5).x/3.5;
				noise += texture2D(noisetex,coord*6.125).x/6.125;
				noise += texture2D(noisetex,coord*12.25).x/12.25;
			//	noise /= saturate(texture2D(noisetex,coord / 3.1 - wind * 0.5).x * 1.3);

				noise *= mix(1.0,pow(noise, pow(2.0,-0.5)),noise);

				noise *= 10;

				float cl = max(noise-0.7,0.0);
				cl = max(cl,0.)*0.05 * (1.0 - rainx * 0.9);
				density = pow(max(1-cl*2.5,0.),2.0) / 11.0 / 3.0;
				density *= 2.0;

				totalcloud += density;
				if (totalcloud > (1.0 - 1.0 / Steps + 0.1)) break;
				weight ++;

			}

			cloudCol = mix(cloudCol*pow(1-density, 2.0),vec3(cloudCol*0.125),pow(density, 2.0)) * 2.0;

			cloudCol += pow(sunColor * mix(3.0,2.4,TimeSunset + TimeSunrise),vec3(mix(3.4 * (1.0 - (1.0 - transition_fading) * 0.3),1.0,TimeNoon)))* 80*pow(1-density, 50.0) * mix(1.0,0.3,1.0 - transition_fading) * 1.5 * (1-(TimeMidnight * transition_fading)) * (1-rainx);
			cloudCol += pow(sunColor * mix(3.0,2.4,TimeSunset + TimeSunrise),vec3(mix(3.4,1.0,TimeNoon))) * 25 * (1- TimeMidnight);
			cloudCol += moonlight * (50*(pow(1-density, 14.0))) * 500 * transition_fading * (1-rainx);

			cloudCol += (cloudCol) * subSurfaceScattering(sunVec, fposition, 60.0)*3.0*pow(1-density, 150.0) * (1.0 - moonVisibility * 0.5) * (TimeNoon + TimeSunrise + TimeSunset + (1.0 - transition_fading));
			cloudCol += cloudCol * subSurfaceScattering(moonVec, fposition, 60.0)*3.0*pow(1-density, 150.0) * moonVisibility;

			cloudCol *= (1- (0.8 * TimeMidnight * transition_fading));
			cloudCol *= (1+ TimeNoon);
			cloudCol = mix(cloudCol,vec3(0.0),pow(1-density, 100.0));

			totalcloud = min(totalcloud / weight,1.0);

			totalcloud = mix(totalcloud,0.0,pow(1-density, 100.0));

			return pow(mix(pow(color.rgb, vec3(2.2)),pow(cloudCol * mult * 0.175 * 0.5 / 45.0, vec3(2.2)),clamp(totalcloud * 15.0, 0.0, 1.0) * (1.0 - rainx * 0.8) * pow(cosT,1.0)), vec3(0.4545));
	}
#endif

#ifdef Stars
	vec3 drawStar(vec3 fposition,vec3 color) {
		float volumetric_cone = pow(max(dot(normalize(fposition),moonVec),0.0),200.0);
		vec3 sVector = normalize(fposition);
		float cosT = dot(sVector,upVec);

		//star generation

		vec3 tpos = vec3(gbufferModelViewInverse * vec4(fposition,1.0));
		vec3 wVector = normalize(tpos);
		vec3 intersection = wVector*(50.0/(wVector.y));
		vec2 coord = (intersection.xz)/256.0 + 0.1;
		float noise = texture2D(noisetex,fract(coord.xy/2.0)).x;
		noise += texture2D(noisetex,fract(coord.xy)).x/2.0;
		float star = max(noise-1.3,0.0);
		star = star * max(cosT,0.0) * 2.0 * TimeMidnight * (1-rainx);

		vec3 sum = vec3(1.0, 1.0, 1.0)*(1-rainx) * (1-volumetric_cone);

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

	float rainPuddles = texture2D(noisetex, fract(coord.xy) + addTime * 2.0).x;
	rainPuddles += texture2D(noisetex, fract(coord.xy*2) - addTime).x;
	rainPuddles += texture2D(noisetex, fract(coord.xy*4) + addTime).x;
	rainPuddles += texture2D(noisetex, fract(coord.xy*8) - addTime * 2.0).x;

	float strength = max(rainPuddles-1.9,0.0);
	float dL = 0.5;
	float L = (1.0 - (pow(dL,strength)));

	return L;
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}

#ifdef VOLUMETRIC_LIGHT
	vec3 vlColor(vec3 fogcolor,vec3 color, vec2 pos, vec3 fragpos) {

		float VolumeSample = 0.0;
		float vlWeight = 0.0;

		// Coloured volumetric light
		vec3 VolumeColour = vec3(1.0);

		float depth = ld(pixeldepth);

		for (float i = -1.0; i < 1.0; i++){
			for (float j = -1.0; j < 1.0; j++){

				vec2 offset = vec2(i,j) / vec2(viewWidth, viewHeight);

				float depth2 = ld(texture2D(depthtex1, texcoord.st + offset * 8.0).x);

				float weight = pow(1.0 - abs(depth - depth2) * 10.0, 32.0);
					weight = max(0.1e-8, weight);

				vec4 sample = texture2D(gaux4, pos.xy + offset * 4.0, 2.0)*2*(1-rainx);

				VolumeSample += sample.a * weight;
				VolumeColour = sample.rgb;

				vlWeight += weight;
			}
		}

		VolumeSample /= vlWeight;

		float eBS = mix(1.0,0.0,(pow(eyeBrightnessSmooth.y / 240.0f, 1.0f)));

		float Glow = pow(max(dot(normalize(fragpos),lightVector),0.0),2.5*15);
		float vlGlow = (Glow*-(2.5*(1+TimeNoon * 5.0)*(1+(TimeSunrise + TimeSunset)*15.)*(1-eBS))) * 0.1;

		float atmosphere = pow(max(dot(normalize(fragpos),lightVector),0.0),2.0);

		float vlInside = ((eBS * 12.5 * 0.15 * VL_STRENGTH_INSIDE * (1.0 - moonVisibility)));
		float vlInsideNight = ((eBS * 12.5 * 0.2 * VL_STRENGTH_INSIDE * (moonVisibility)));
		float vlFinalInside = (vlInside + vlInsideNight);

		vec3 vlDay = vec3(sunColor) * VL_STRENGTH_DAY * TimeNoon;
		vec3 vlNight = vec3(moonlight)  * (VL_STRENGTH_NIGHT * moonVisibility);
		vec3 vlSSSR = pow(vec3(sunColor), vec3(1.0)) * (VL_STRENGTH_SUNSET_SUNRISE * (1 - TimeNoon) * (1 - moonVisibility));
		vec3 combined = (vlDay + vlNight + vlSSSR);

		vec3 atmosphereColor = fogcolor * (1.0 - atmosphere);

		vec3 vlcolor = combined;
			vlcolor = mix(vlcolor,pow(vlcolor,vec3(1.5)) * 2.2,(TimeSunrise + TimeSunset));

			atmosphereColor = mix(atmosphereColor, vlcolor,eBS);
			vlcolor *= mix(1.0, atmosphere, 1.0);
			vlcolor += mix(atmosphereColor, vec3(0.0), 0.0);
			vlcolor *= (1 + (vlFinalInside));
			vlcolor *= (1 + (vlGlow));

			// Coloured volumetric light
			if(any(greaterThan(VolumeColour, vec3(0.0)))) vlcolor *= VolumeColour * 4.0;

			vlcolor = pow(mix(pow(max(color,0.0), vec3(2.2)), pow(vlcolor, vec3(2.2)), VolumeSample * 0.2 * 0.1 * 0.5 * VL_MULT * (1.0 - isEyeInWater) * (1.0 - rainx) * transition_fading),vec3(0.4545));
			return vec3(1.0);
	}
#endif


float dynamicExposure() {
		return saturate((-eyeBrightnessSmooth.y+230)/100.0);
}

vec3 getRainFogColor(){
		vec3 rainfogclr = vec3(0.1,0.095,0.1)* 0.75 *rainx*mix(1-TimeMidnight,1.0,(1-transition_fading) * pow(TimeSunrise + TimeSunset, 0.5));

		rainfogclr = rainfogclr*16.0*rainx;
		rainfogclr += vec3(0.1,0.095,0.1) * 0.75 * moonlight * 300.0*rainx*(TimeMidnight + (1-transition_fading));
		rainfogclr -= rainfogclr*0.8*rainx;

		return rainfogclr;
}

#ifdef FOG

vec3 getFog(vec3 color, bool land, bool land2, vec2 pos){

	vec3 fragposFog = vec3(pos.st, texture2D(depthtex0, pos.st).r);
	fragposFog = nvec3(gbufferProjectionInverse * nvec4(fragposFog * 2.0 - 1.0));

	vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragposFog,1.0);
	float horizon = (worldposition.y - (pos.y-cameraPosition.y));

	float calcHeight = (max(pow(max(1.5 - horizon/100.0, 0.0), 1.0)-0.0, 0.0));

	float volumetric_cone = pow(max(dot(normalize(fragposFog),lightVector),0.0),2.5)*transition_fading;

		float fog = exp(-pow(sqrt(dot(fragposFog,fragposFog))/400* 0.4 *(1- dynamicExposure())*(1-(TimeSunrise+TimeSunset)*0.4) ,2.0));
		float fog2 = exp(-pow(sqrt(dot(fragposFog,fragposFog))/150*(1-dynamicExposure()*.8) ,2.0));
		float fog3 = exp(-pow(sqrt(dot(fragposFog,fragposFog))/140*(1-dynamicExposure()) ,2.0));
		float fogfactor =  clamp(fog + hand,0.0,1.0);
		float fogfactor2 =  clamp(fog2 + hand,0.0,1.0);
		float fogfactor3 =  clamp(fog3 + hand,0.0,1.0);

		color = pow(color, vec3(1));

		vec3 fogclr = mix(color.rgb,ambient_color,0.06 + clamp((20000*TimeMidnight), 0.0, 0.25))*(1.0-rainx)*(1.0-TimeMidnight*0.87);
		fogclr = clamp(mix(fogclr, ambient_color * pow(1.0 - fogfactor,1.0 / 8.0), (1-TimeMidnight)*(1+TimeSunrise*.25)*(1+TimeNoon*.5)),0.0,1.0);
		fogclr.g -= fogclr.g*0.15;
		fogclr.rb -= fogclr.rb*0.1*(TimeSunrise+TimeSunset);

		vec3 fogclr2 = getRainFogColor();

		//glow

		fogclr = mix(fogclr, pow(sunColor,vec3(1)) * 2.0 + fogclr, volumetric_cone*transition_fading*(1.0-TimeMidnight)*(1.0-TimeNoon)*(1.0-rainx*0.4) * 1.5);
		fogclr += fogclr * 0.05 * volumetric_cone*2*transition_fading*TimeMidnight*(1.0-rainx)*1.0;

		fogclr = mix(fogclr,sunColor,volumetric_cone*TimeNoon*(1.0-rainx));

		if (isEyeInWater > .9) {
			} else {

		if (land) {
			color.rgb = mix(color.rgb,pow(fogclr, vec3(1)),(1-fogfactor)*0.5*(1-clamp(calcHeight,0.0,1.0))*.5*(1- dynamicExposure()));
		}

		color.rgb = mix(color.rgb,pow(fogclr2, vec3(1)),(1-fogfactor2)*rainx);


		//altitude fog

				color.rgb = mix(color.rgb,pow(fogclr, vec3(1)),clamp((1-fogfactor)*(1-rainx)*(1-TimeMidnight)*(clamp((calcHeight) * 0.6, 0.0, 1.0)),0.0,1.0));

				calcHeight = (max(pow(max(0.76 - horizon/300.0, 0.0), 8.0)-0.0, 0.0));
				color.rgb  = mix(color.rgb,pow(clamp(fogclr * 1.5, 0.0, 1.0), vec3(1)),clamp(3.0*(clamp((calcHeight) * 100, 0.0, 1.0))*(TimeMidnight)*(1- rainx)*(1-TimeSunrise)*(transition_fading)*(1-fogfactor3),0.0,1.0));


	}
	return pow(color, vec3(1));
}
#endif

vec3 getSkyColor() {

	////////////////////////////////////////////////////////////////////////////////

	vec3 sclr = vec3(70.0,85,150)/1100*TimeNoon*(1.0-rainx);
		 sclr += vec3(70.0,85,150)/1100*(TimeSunrise+TimeSunset)*transition_fading*(1.0-rainx);
		 sclr += vec3(70.0,85,150)/1100*(1-transition_fading)*(TimeSunrise + TimeSunset)*(1.0-rainx);
		 sclr += vec3(ambient_color.r/5.0,ambient_color.g/5.0 -
		 (ambient_color.g * 0.03),ambient_color.b/5.0)/3.4*moonVisibility*transition_fading*(1.0-rainx);

		 sclr += vec3((moonlight*0.5)*7.5)*(1-transition_fading)*(1-(TimeSunrise + TimeSunset))*(1.0-rainx);
		 sclr *= 2.0;
		 sclr /= 2.5;
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
	float spec = pow(clamp(dot(r,l),0.0,1.0),1250.0 / size) * 4.0;
	if(spec < 0.2){
		spec = 0;
	}
	return spec;
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

					bool land = texture2D(depthtex0, pos.st).r < comp;
                    float border = clamp(1.0 - pow(cdist(pos.st), 10.0), 0.0, 1.0);
                    color = texture2D(gcolor, pos.st) * MAX_COLOR_RANGE;

						color.a = 1.0;

				/*		#ifdef FOG
							color.rgb = getFog(color.rgb, land, land, pos.st);
						#endif*/

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

vec3 getSkyReflection(vec3 reflectedVector){

	vec2 cone12 = vec2(0.0);
		cone12.x = pow(max(dot(normalize(reflectedVector),sunVec),0.0),2.5);
		cone12.y = pow(1-max(dot(normalize(reflectedVector),upVec),0.0),3.5);

	vec3 sclr = skyColor;

	sclr = mix(sclr,vec3(25,15,10)/100,(TimeSunrise+TimeSunset)*transition_fading* 0.5 *cone12.x*(1.0-rainx));
	sclr = mix(sclr,(vec3(88,30,20))/200/12.5,cone12.x*(1-transition_fading)*(1.0-rainx));
	sclr += sclr * 1.5 *cone12.y * (1.0 - ((rainStrength * 1.6 * (1.0 - TimeMidnight * 0.3 * 1.6)) + TimeMidnight) * 0.75)
	* (1.0 + (TimeSunrise + TimeSunset) * (1.0 - rainStrength) * 0.5);

	float skyBrightness = mix(3.0, 0.1, TimeMidnight);
	sclr *= skyBrightness;

	#ifdef Clouds
		sclr = drawCloud(reflectedVector.xyz,sclr.rgb,1.0) * (1.0 - isEyeInWater);
	#else
		sclr = sclr * (1.0 - isEyeInWater);
	#endif

	#ifdef Stars
		sclr = drawStar(reflectedVector.xyz,sclr.rgb) * (1.0 - isEyeInWater);
	#else
		sclr = sclr * (1.0 - isEyeInWater);
	#endif

	return sclr;

}

#endif

#ifdef GODRAYS
	vec3 getGodrays(vec3 fragpos) {

	  vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
				 tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 pos1 = tpos.xy/tpos.z;
		vec2 lightPos = pos1*0.5+0.5;

		vec4 grWeight = vec4(0.0);
			grWeight.x = pow(float(NUM_SAMPLES),(1.0));
			grWeight.y = 0.9/grWeight.x;
			grWeight.z = (grWeight.x-1) * 0.5;
			grWeight.w = 0.0;

		const float sigma = 0.5;

		float truepos = sunPosition.z/abs(sunPosition.z);

		vec3 rainc = mix(vec3(1.),fogclr2*1.5,rainx);
		vec3 lightColor = mix(sunColor*(1-moonVisibility)*rainc,moonlight*25*moonVisibility,(truepos));

		if (isEyeInWater < 0.9) {
		vec2 deltaTextCoord = (texcoord.st - lightPos.xy)*grWeight.y*density;
		vec2 textCoord = texcoord.st;
		float illuminationDecay = 1.0;
		float noise = noisepattern(textCoord,1.0);
		float gr = 0.0;
		float avgdecay = 0.0;

		float Visibility = pow(max(dot(normalize(fragpos),lightVector),0.0),4.5);

		for(int i=0; i < grWeight.x ; i++)
		{

							textCoord -= deltaTextCoord;

					float dist = (i-float(grWeight.z))/grWeight.z;
					float weight = exp(-(dist*dist)/(2.0*sigma));

					float sample = step(texture2D(gaux1, textCoord +deltaTextCoord * noise * grnoise).r,0.0)*weight;

					grWeight.w += weight;
					gr += sample;

		}
		vec3 grC = mix(lightColor.rgb,fogclr2.rgb,rainx)*exposure*(gr/grWeight.w)*(1.0 - rainx*0.8)*Visibility * transition_fading * (1-isEyeInWater);
		grC = pow(grC.rgb, vec3(2.2));
		color.rgb = pow(color.rgb, vec3(2.2));
		color.xyz = pow((1-(1-color.xyz/48.0)*(1-grC.xyz/48.0))*48.0, vec3(0.4545));
		}
	return color.rgb;
	}
#endif

#ifdef WATER_CAUSTIC

	vec3 waterCaustic(vec3 color, float visibility, in float land, vec3 fragpos) {

		vec4 worldpositionuw = gbufferModelViewInverse * vec4(fragpos,1.0);
		vec3 wpos = (worldpositionuw.xyz + cameraPosition.xyz);

		vec2 coord = vec2(wpos.xz - wpos.y);

		vec3 caustics = getWaveHeight(coord, iswater, istransparent);

		float getcaustic = convertVec3ToFloat(caustics);

		float wca = (CAUSTIC_STRENGHT * 2.5);
		float caustic = pow(pow(0.02,clamp(getcaustic,0.0,5.0)*.20),6.0);

		vec3 wc = clamp(mix(vec3(0),color * visibility * wca,caustic),0.0,1.0);

	if (land > 0.9)
		return wc;
		//return -0.1+caustics;
	}

	#endif

#ifdef WATER_REFRACT

vec3 waterRefraction(vec3 color) {

	float maskCoord1 = 0.0;
	float maskCoord2 = 0.0;
	float maskCoord3 = 0.0;

	vec2 coord1 = vec2(0.0);
	vec2 coord2 = vec2(0.0);
	vec2 coord3 = vec2(0.0);

	vec3 refraction = vec3(0.0);

	waterRefractCoord(maskCoord1, maskCoord2, maskCoord3, coord1, coord2, coord3, refraction);

	vec3 rA;
		rA.x = texture2D(gcolor, (coord1)).x * MAX_COLOR_RANGE;
		rA.y = texture2D(gcolor, (coord2)).y * MAX_COLOR_RANGE;
		rA.z = texture2D(gcolor, (coord3)).z * MAX_COLOR_RANGE;

	refraction.r = bool(maskCoord1) ? rA.r : color.r;
	refraction.g = bool(maskCoord2) ? rA.g : color.g;
	refraction.b = bool(maskCoord3) ? rA.b : color.b;

	if (iswater > 0.9 || istransparent > 0.9 || isIce > 0.9 || portal > 0.9)	color = refraction;

	return color;
}

#endif

vec3 getColorCorrection(vec3 color, bool land){

	//Color changes depends on time//
	color.g -= color.g*0.1*TimeMidnight;
	color.b += color.b*0.1*(1-rainx)*(1-islava);
	color.r -= color.r*0.25*(1-rainx)*(1-islava);

	/////////////////////////////////////////////////////////////////

	color.bg += color.bg*.1*(1-islava*(1-rainx));

	return color.rgb;
}

float getWaterDepth(vec3 fragpos, vec3 fragpos2){

	vec3 uVec = fragpos-fragpos2;

	float UNdotUP = abs(dot(normalize(uVec),normal2));
	float depth = sqrt(dot(uVec,uVec))*UNdotUP;

	return depth;
}

bool getLand(sampler2D depth){
	return texture2D(depth, refractionTC.st).r < comp;
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

			vec3 lightColor = mix(sunColor, moonlight * 10.0, TimeMidnight) * 1.5;
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

vec3 dynamicExposure1(vec3 color) {
		return color.rgb * clamp((-eyeBrightnessSmooth.y+230)/100.0,0.0,1.0)*2.5*(1-TimeMidnight)*(1-rainx);
}

float schlickFresnel(float VoH, float F0) {
	return F0 + (1.0 - F0) * max(pow(1.0 - VoH, 5.0), 0.0);
}

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////



void main() {

	bool land = getLand(depthtex1);
	bool land2 = getLand(depthtex0);
	// Coloured volumetric light
	//vec3 stuff = texture2D(gaux4, texcoord.st).rgb;
	bool waterShadow = bool(colsample.a);
	vec3 fragpos = vec3(texcoord.st, pixeldepth2);
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));

	vec3 fragpos2 = vec3(refractionTC.st, pixeldepth);
	fragpos2 = nvec3(gbufferProjectionInverse * nvec4(fragpos2 * 2.0 - 1.0));

	if (isEyeInWater > 0.9) {
		fragpos.xy *= 0.831;
		fragpos2.xy *= 0.831;
	}


	vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragpos,1.0);

		 vec4 worldposition1 = vec4(0.0);
				worldposition1 = gbufferModelViewInverse * vec4(fragpos2,1.0);
		 vec3 posxz = worldposition1.xyz + cameraPosition.xyz;

		 vec3 viewSpacePos = normalize(convertCameraSpaceToScreenSpace(fragpos));
		 vec3 halfVector2 = normalize(lightVector + viewSpacePos);

	#ifdef WATER_REFRACT
		color = waterRefraction(color);
	#endif


	float depth = getWaterDepth(fragpos, fragpos2);

	#ifdef WATER_CAUSTIC
		color += waterCaustic(color.rgb, exp(-depth / 4.0), float(land)+float(waterShadow), fragpos2) * pow(sky_lightmap,1.0) * (1 - TimeMidnight * 0.5) * (1 - rainx * 0.75) * (iswater + isEyeInWater) * (1 - iswater * isEyeInWater) * (1.0 - istransparent * isEyeInWater);
	#endif

	vec3 sunMult = vec3(0.0);
	float moonMult = 0.0;
	vec3 skyGradient = pow(getAtmosphericScattering(pow(color, vec3(0.4545)), fragpos2.xyz, 1.0, ambient_color, sunMult, moonMult), vec3(2.2));

	if(!land){
		color = skyGradient;
	}
		#ifdef Stars
			if (!land)	color.rgb = drawStar(fragpos2.xyz,color.rgb);
		#endif

	#ifdef Clouds
		if (!land)	color.rgb = drawCloud(fragpos2.xyz,color.rgb,1.0);
	#endif


	// setting up light color
		vec3 light_col = mix(pow(sunColor * (transition_fading * (1.0 - TimeMidnight)),vec3(4.4)),
		moonlight*50,
		moonVisibility * transition_fading * TimeMidnight * (1.0 - (TimeSunrise + TimeSunset)));

		light_col = mix(light_col,vec3(sqrt(dot(light_col,light_col)))*vec3(0.25,0.32,0.4),rainx);
		light_col = pow(light_col,mix(vec3(1.0 / 5.0),vec3(0.5), pow(TimeSunrise + TimeSunset,3.0) + TimeMidnight));
		light_col = mix(light_col, vec3(0.5), rainStrength);

	//

		float normalDotEye = dot(normal2, normalize(fragpos));
		vec3 fresnel = vec3(clamp((1.0 + normalDotEye),0.0,1.0));
		fresnel.y = clamp(pow(1.0 + normalDotEye, 0.75),0.0,1.0);

		normalDotEye = dot(normal, normalize(fragpos));

		float fresnelPow = mix(2, 5, istransparent);
		fresnel.z = clamp((1.0 - normalDotEye),0.0,1.0);
		fresnel.xz = pow(fresnel.xz,vec2(fresnelPow));

		float trueFresnel = schlickFresnel(dot(halfVector2, viewSpacePos), 0.3);

		float depthMap = clamp(exp(-depth / 3.0),0.0,1.0);

		vec3 npos = normalize(fragpos2);
		vec3 reflectedVector = normalize(reflect(npos, normalize(normal2)));
		vec3 reflectedVector2 = normalize(reflect(npos, normalize(normal)));

		#ifdef WATER_DEPTH_FOG
		fresnel.y = pow(fresnel.y, 2.2);
			fresnel.y += pow(1-depthMap, 2.2);
			fresnel.y = pow(min(fresnel.y,1.0), 0.4545);

		fresnel.y *= iswater;

			vec3 waterFogClr = skyColor;

			waterFogClr = mix(waterFogClr + mix(vec3(0.0,waterFogClr.g * 0.5 * pow(depthMap, 0.2),0.0),vec3(0.0), pow(rainStrength, 0.75)),
			(waterFogClr + mix(vec3(0.0,waterFogClr.g,0.0) * 0.75 * light_col, vec3(0.0), pow(rainStrength, 0.75))) * light_col * 3.0,
			vec3(calcWaterSSS(normal2)) * transition_fading) * 0.75 * mix(0.5,1.0,pow(depthMap, 0.2));

			color.rgb = pow(mix(pow(color, vec3(0.4545)), pow(waterFogClr, vec3(0.4545)) * sky_lightmap,pow(fresnel.y,1.0)*iswater*(1-isEyeInWater)), vec3(2.2));

		#endif


	#ifdef REFLECTIONS
		float depthMap1 = depthMap / depthMap + 1;
		light_col = light_col * mix(4.0,10.0,(TimeSunrise + TimeSunset) * transition_fading);

		vec4 reflection;

		vec3 getSky = getSkyReflection(mix(reflectedVector2, reflectedVector, istransparent + iswater));
		getSky *= mix(fresnel.z, fresnel.x, istransparent + iswater);
//	getSky *= fresnel1;
		float spec = sunSpec(sunVec, fragpos, normal2, 3.0) * (1.0 - TimeMidnight) * (1.0 - isEyeInWater) * (1.0 - rainStrength) * float(pow(sky_lightmap, 50.0) > 0.1) * (istransparent + iswater);
		spec += sunSpec(sunVec, fragpos, normal2, 3.0) * (1.0 - TimeMidnight) * (1.0 - isEyeInWater) * (1.0 - rainStrength) * float(pow(sky_lightmap, 50.0) > 0.1) * (1.0 - (istransparent + iswater));

		spec += sunSpec(moonVec, fragpos, normal2, 100.0) * (TimeMidnight) * (1.0 - isEyeInWater) * (1.0 - rainStrength) * float(pow(sky_lightmap, 50.0) > 0.1) * (istransparent + iswater) * 0.001;
		spec += sunSpec(moonVec, fragpos, normal2, 1.0) * (TimeMidnight) * (1.0 - isEyeInWater) * (1.0 - rainStrength) * float(pow(sky_lightmap, 50.0) > 0.1) * (istransparent + iswater) * 0.01;

		vec3 forwardRenderingAlbedo = renderGaux2(color, refractionTC);
		color = forwardRenderingAlbedo;

		vec3 reflColor = mix(color*100, light_col, iswater);

		spec *= (1-portal);
		getSky += ((spec)*colsample.a)*reflColor;


		if (iswater > 0.9 || istransparent > 0.9) {
			#ifdef WATER_REFLECTIONS
				reflection = raytrace(fragpos, normal2, getSky, reflectedVector, trueFresnel);
				reflection.rgb = mix(getSky * reflectionSkyLight, reflection.rgb, reflection.a);
				reflection.a = 1.0;
				color.rgb += reflection.rgb;
			#endif
		} else {
/*	reflection = raytrace(fragpos, normal, getSky, reflectedVector2, fresnel.z);
			reflection.rgb = mix(getSky * reflectionSkyLight, reflection.rgb, reflection.a);
			reflection.a = 1.0;
*/
			#ifdef RAIN_REFLECTIONS

				float rainPuddles = getRainPuddles(1.0, 0.0);

				color.rgb = pow(color.rgb, vec3(2.2));
				color.rgb += pow(reflection.rgb, vec3(2.2))*reflection.a*clamp(pow(iswet, 10.0), 0.0, 1.0)*(1.0-specmap) * (rainPuddles + .05*(1-(rainPuddles)))* 15.0 *(1-iswater)*(1-isEyeInWater);
				color = pow(color, vec3(0.4545));
			#endif

			#ifdef SPECULAR_REFLECTIONS
				color.rgb = pow(color.rgb, vec3(2.2));
				color.rgb += (pow(reflection.rgb, vec3(2.2))*fresnel.x*reflection.a)*specmap*(1-iswater);
				color = pow(color, vec3(0.4545));
			#endif
		}

	#endif


	if (!land)color.rgb = mix(color,getRainFogColor(),pow(rainx,4.0));



		vec3 vlFogColor = ambient_color;
	vlFogColor.g -= vlFogColor.g * 0.2;

	#ifdef GODRAYS
		color.rgb = getGodrays(fragpos);
	#endif

	#ifdef FOG
		color.rgb = getFog(color, land2, land, refractionTC.st);
	#endif

	#ifdef VOLUMETRIC_CLOUDS
		vec3 threeDimClouds = rayMarching(color, land, fragpos2, worldposition.xyz);
		threeDimClouds = renderGaux2(threeDimClouds, refractionTC);

		color = color.rgb = (threeDimClouds - forwardRenderingAlbedo) + color;
	#endif

	#ifdef VOLUMETRIC_LIGHT
	//	color.rgb = vlColor(vlFogColor, color.rgb, refractionTC.st, fragpos2);
	#endif

	float depth_diff = pow(clamp(sqrt(dot(fragpos,fragpos)) * 0.01,0.0,1.0), 0.05);
	color.rgb = pow(mix(pow(color.rgb, vec3(2.2)),pow(clamp(skyColor + mix(vec3(0.0,skyColor.g * 0.3, 0.0),vec3(0.0), pow(rainStrength, 0.75)),0.0,1.0) * 0.25, vec3(2.2)),depth_diff*isEyeInWater),vec3(0.4545));

	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		 tpos = vec4(tpos.xyz/tpos.w,1.0);

	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;

	float visiblesun = 0.0;
	float temp;
	int nb = 0;

	//calculate sun occlusion (only on one pixel)
	if (texcoord.x < pw && texcoord.x < ph) {
		for (int i = 0; i < 2;i++) {
			for (int j = 0; j < 3 ;j++) {
			temp = texture2D(gaux1,lightPos + vec2(pw*(i-1.0)*7.0,ph*(j-1.0)*7.0)).g;
			visiblesun +=  1.0-float(temp > 0.04) ;
			nb += 1;
			}
		}
		visiblesun /= nb;

	}

		color.rgb = getColorCorrection(color,land);

	//color = mix(color, vec3(1.0),vec3(clamp(exp(-depth * 5.0),0.0,1.0)) * iswater * pow(getRainPuddles(20.0, frameTimeCounter / 2000.0),1.0));

	//color.rgb += dynamicExposure1(color.rgb);

/* DRAWBUFFERS:0 */

	gl_FragData[0] = vec4(color.rgb / MAX_COLOR_RANGE,visiblesun);

}
