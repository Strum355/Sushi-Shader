#version 120

#define MAX_COLOR_RANGE 48.0 //[1.0 2.0 4.0 6.0 12.0 24.0 48.0 96.0]
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
	#define VL_STRENGTH_NIGHT 			4.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0] // Strength of night time
	#define VL_STRENGTH_SUNSET_SUNRISE 	1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0] // Strength of sunset and sunrise time
	#define VL_STRENGTH_INSIDE 			1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	// Strength inside buildings

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

const bool 		gcolorMipmapEnabled 	= true; //gcolor texture mipmapping
const bool 		gaux1MipmapEnabled 	= true; //gaux1 texture mipmapping

//don't touch these lines if you don't know what you do!
const int maxf = 3;				//number of refinements
const float stp = 1.0;			//size of one step for raytracing algorithm
const float ref = 0.9;			//refinement multiplier
const float inc = 2.0;			//increasement factor at each step

varying vec4 texcoord;
varying vec3 sunlight;
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
float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;
float wetx  = clamp(wetness, 0.0f, 1.0f);

//Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float transition_fading = 1.0-(clamp((timefract-12000.0)/300.0,0.0,1.0)-clamp((timefract-13000.0)/300.0,0.0,1.0) + clamp((timefract-22800.0)/200.0,0.0,1.0)-clamp((timefract-23400.0)/200.0,0.0,1.0));

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
vec3 color = texture2D(gcolor,texcoord.xy,0).rgb * MAX_COLOR_RANGE;

int iswater = int(aux.g > 0.04 && aux.g < 0.07);
int land2 = int(aux.g < 0.03);
int hand  = int(aux.g > 0.75 && aux.g < 0.85);
int isIce = int(aux.g > 0.94 && aux.g < 0.96);
float istransparent = float(aux.g > 0.4 && aux.g < 0.42)+isIce;
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

float subSurfaceScattering(vec3 vec,vec3 pos, float N) {

return pow(max(dot(vec,normalize(pos))*0.5+0.5,0.0),N)*(N+1)/6.28;

}

float waterH(vec2 posxz,float speed, float y,float iswater) {

	vec2 movement = vec2(abs(frameTimeCounter/1000.-0.5),abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement2 = vec2(-abs(frameTimeCounter/1000.-0.5),abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement3 = vec2(-abs(frameTimeCounter/1000.-0.5),-abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement4 = vec2(abs(frameTimeCounter/1000.-0.5),-abs(frameTimeCounter/1000.-0.5))*speed;

	vec2 coord = (posxz/600)+(movement/5);
	vec2 coord2 = (posxz/599.8)+(movement3/5);
	vec2 coord3 = (posxz/599.7)+(movement4);
	vec2 coord4 = (posxz/1600)+(movement/1.5);
	vec2 coord5 = (posxz/1599)+(movement2/1.5);
	vec2 coord6 = (posxz/1598)+(movement3/1.5);
	vec2 coord7 = (posxz/1597)+(movement4/1.5);

	float noise = BicubicTexture(noisetex, vec2(coord.x, -coord.y*3)).x*y;
	noise += BicubicTexture(noisetex, vec2(-coord2.x*3, coord2.y)).x*y;
	noise += BicubicTexture(noisetex, vec2(coord3.x, -coord3.y*3)).x*y;
	noise += BicubicTexture(noisetex, vec2(-coord6.x*3, coord4.y)).x*y;
	noise += BicubicTexture(noisetex, vec2(coord7.x*3, -coord5.y)).x*y;

	return noise/7;
}

vec3 getWaveHeight(vec2 posxz, float iswater, float istransparent){

	vec2 coord = posxz;

		float deltaPos = 0.22;

		float waveZ = mix(0.200,1,iswater);
		float waveM = mix(0.0,1.0,iswater);

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

float refractmask(vec2 coord, float lod){

	float mask = texture2D(gaux1, coord.st, lod).g;

	if (iswater > 0.9){
		mask = float(mask > 0.04 && mask < 0.07);
	}

	if (istransparent > 0.9){
		mask = float(mask > 0.4 && mask < 0.42)+float(mask > 0.94 && mask < 0.96);
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
		float dispersionMult = saturate(pow(1.0 + getAngle, 1.0));
		dispersionMult = pow(dispersionMult,1.0 - getAngle);

		float dispersion = 0.25 * dispersionMult;

		refraction = getWaveHeight(posxz.xz - posxz.y, iswater, istransparent);
		vec2 depth = vec2(0.0);
			depth.x = getDepth(startPixeldepth);
			depth.y = getDepth(startPixeldepth2);

			float refractionMult = mix(100.0, 5.0, float(istransparent));
		float refMult = 1.0;
			refMult = saturate(depth.x - depth.y);
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

		color = pow(color, vec3(2.2));

		vec3 fogclr = mix(color.rgb,ambient_color,0.06 + clamp((20000*TimeMidnight), 0.0, 0.25))*(1.0-rainx)*(1.0-TimeMidnight*0.87);
		fogclr = clamp(mix(fogclr, ambient_color * pow(1.0 - fogfactor,1.0 / 8.0), (1-TimeMidnight)*(1+TimeSunrise*.25)*(1+TimeNoon*.5)),0.0,1.0);
		fogclr.g -= fogclr.g*0.15;
		fogclr.rb -= fogclr.rb*0.1*(TimeSunrise+TimeSunset);

		vec3 fogclr2 = getRainFogColor();

		//glow

		fogclr = mix(fogclr, pow(sunlight,vec3(2.2)) * 2.0 + fogclr, volumetric_cone*transition_fading*(1.0-TimeMidnight)*(1.0-TimeNoon)*(1.0-rainx*0.4) * 1.5);
		fogclr += fogclr * 0.05 * volumetric_cone*2*transition_fading*TimeMidnight*(1.0-rainx)*1.0;

		fogclr = mix(fogclr,sunlight,volumetric_cone*TimeNoon*(1.0-rainx));

		if (isEyeInWater > .9) {
			} else {

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

	}
	return pow(color, vec3(0.4545));
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

						#ifdef FOG
							color.rgb = getFog(color.rgb, land, land, pos.st);
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

vec3 getSkyReflection(vec3 reflectedVector){

	vec2 cone12 = vec2(0.0);
		cone12.x = pow(max(dot(normalize(reflectedVector),sunVec),0.0),2.5);
		cone12.y = pow(1-max(dot(normalize(reflectedVector),upVec),0.0),3.5);

	vec3 sclr = getSkyColor();

	sclr = mix(sclr,vec3(25,15,10)/100,(TimeSunrise+TimeSunset)*transition_fading* 0.5 *cone12.x*(1.0-rainx));
	sclr = mix(sclr,(vec3(88,30,20))/200/12.5,cone12.x*(1-transition_fading)*(1.0-rainx));
	sclr += sclr * 1.5 *cone12.y * (1.0 - ((rainStrength * 1.6 * (1.0 - TimeMidnight * 0.3 * 1.6)) + TimeMidnight) * 0.75)
	* (1.0 + (TimeSunrise + TimeSunset) * (1.0 - rainStrength) * 0.5);

	float skyBrightness = mix(3.0, 0.1, TimeMidnight);
	sclr *= skyBrightness;

		sclr = sclr * (1.0 - isEyeInWater);

	return sclr;

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

	if (iswater > 0.9 || istransparent > 0.9 || isIce > 0.9)	color = refraction;

	return color;
}

#endif

vec3 getColorCorrection(vec3 color, bool land){

	//Color changes depends on time//

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


//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////



void main() {

	bool land = getLand(depthtex1);
	bool land2 = getLand(depthtex0);
	vec3 stuff = texture2D(gaux4, texcoord.st).rgb;
	bool waterShadow = bool(stuff.r);
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


	#ifdef WATER_REFRACT
		color = waterRefraction(color);
	#endif


	float depth = getWaterDepth(fragpos, fragpos2);

	#ifdef WATER_CAUSTIC
		color += waterCaustic(color.rgb, exp(-depth / 4.0), float(land)+float(waterShadow), fragpos2) * pow(sky_lightmap,1.0) * (1 - TimeMidnight * 0.5) * (1 - rainx * 0.75) * (iswater + isEyeInWater) * (1 - iswater * isEyeInWater) * (1.0 - istransparent * isEyeInWater);
	#endif


	// setting up light color
		vec3 light_col = mix(pow(sunlight * (transition_fading * (1.0 - TimeMidnight)),vec3(4.4)),
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

		float depthMap = clamp(exp(-depth / 3.0),0.0,1.0);

		vec3 npos = normalize(fragpos2);
		vec3 reflectedVector = normalize(reflect(npos, normalize(normal2)));
		vec3 reflectedVector2 = normalize(reflect(npos, normalize(normal)));

		#ifdef WATER_DEPTH_FOG
		fresnel.y = pow(fresnel.y, 2.2);
			fresnel.y += pow(1-depthMap, 2.2);
			fresnel.y = pow(min(fresnel.y,1.0), 0.4545);

		fresnel.y *= iswater;

			vec3 waterFogClr = getSkyColor();

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

		vec3 forwardRenderingAlbedo = renderGaux2(color, refractionTC);
		color = forwardRenderingAlbedo;

		vec3 reflColor = mix(color*100, light_col, iswater);



		if (iswater > 0.9 || istransparent > 0.9) {
			#ifdef WATER_REFLECTIONS
				reflection = raytrace(fragpos, normal2, getSky, reflectedVector, fresnel.x);
				reflection.rgb = mix(getSky * reflectionSkyLight, reflection.rgb, reflection.a);
				reflection.a = 1.0;
				color.rgb += reflection.rgb;
			#endif
		} else {

			reflection = raytrace(fragpos, normal, getSky, reflectedVector2, fresnel.z);
			reflection.rgb = mix(getSky * reflectionSkyLight, reflection.rgb, reflection.a);
			reflection.a = 1.0;


			#ifdef SPECULAR_REFLECTIONS
				color.rgb = pow(color.rgb, vec3(2.2));
				color.rgb += (pow(reflection.rgb, vec3(2.2))*fresnel.x*reflection.a)*specmap*(1-iswater);
				color = pow(color, vec3(0.4545));
			#endif
		}

	#endif


	#ifdef FOG
		color.rgb = getFog(color, land2, land, refractionTC.st);
	#endif


	float depth_diff = pow(clamp(sqrt(dot(fragpos,fragpos)) * 0.01,0.0,1.0), 0.05);
	color.rgb = pow(mix(pow(color.rgb, vec3(2.2)),pow(clamp(getSkyColor() + mix(vec3(0.0,getSkyColor().g * 0.3, 0.0),vec3(0.0), pow(rainStrength, 0.75)),0.0,1.0) * 0.25, vec3(2.2)),depth_diff*isEyeInWater),vec3(0.4545));

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

	if(isIce > 0.9){
		vec3 waterFogColor = vec3(0.1, 0.95, 1.0);
	 		color.rgb *= waterFogColor;
	}
		color.rgb = getColorCorrection(color,land);

	//color = mix(color, vec3(1.0),vec3(clamp(exp(-depth * 5.0),0.0,1.0)) * iswater * pow(getRainPuddles(20.0, frameTimeCounter / 2000.0),1.0));

	//color.rgb += dynamicExposure1(color.rgb);

/* DRAWBUFFERS:0 */

	gl_FragData[0] = vec4(color.rgb / MAX_COLOR_RANGE,visiblesun);

}
