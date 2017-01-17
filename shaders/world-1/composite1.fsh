#version 120

//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
#define WATER_QUALITY 5 //[1 2 3 4 5] higher numbers gives better looking water

#define REFLECTIONS
	#define REFLECTION_STRENGTH 0.5 //[0.125 0.25 0.375 0.5 0.625 0.75 0.875 1.0] //Strength
	#define SPECULAR_REFLECTIONS

#define WATER_REFRACT		//Also includes stained glass and ice.
	#define REFRACT_MULT 10.0

#define FOG

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

const bool 		gcolorMipmapEnabled 	= true; //gcolor texture mipmapping
const bool 		gaux1MipmapEnabled 	= true; //gaux1 texture mipmapping


//don't touch these lines if you don't know what you do!
const int maxf = 3;				//number of refinements
const float stp = 1.0;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
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
float rainx = clamp(rainStrength, 0.0, 0.5);
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

vec3 specular = pow(texture2D(gaux3,texcoord.xy).rgb,vec3(2.2));
float specmap = float(aux.a > 0.7 && aux.a < 0.72) + (specular.r+specular.g*(iswet));
vec3 color = texture2D(gcolor,texcoord.xy,ice*8).rgb * MAX_COLOR_RANGE;

vec3 rawAlbedo = texture2D(gdepth,texcoord.st).rgb;



float torchLightmap = aux.b;

float waveZ = mix(mix(3.0,0.25,1-istransparent), 8.0, ice);
float waveM = mix(0.0,2.0,1-istransparent+ice);
float waveS = mix(0.1,1.5,1-istransparent+ice);

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

float getLinearDepth(vec2 coord){
	return (near * far) / (texture2D(depthtex1, coord).x * (near - far) + far);
}

float sunSpecTime(float invert){
		return mix((1-TimeMidnight), (TimeMidnight), invert) * (1-rainx*2.0) * (1-isEyeInWater) * float(pow(sky_lightmap, 50.0) > 0.1);
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
	return mix(color,albedo.rgb*2*( color/divisor),clamp(albedo.a * 2.25,0.0,1.0));
}

float startPixeldepth = texture2D(depthtex1,texcoord.st).x;
float startPixeldepth2 = texture2D(depthtex0,texcoord.st).x;

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

#ifdef WATER_REFRACT

	void waterRefractCoord(out float maskCoord1, out float maskCoord2, out float maskCoord3, out vec2 coord1, out vec2 coord2, out vec2 coord3, out vec3 refraction){

	vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
		fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));

		vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragpos,1.0);

		vec3 posxz = worldposition.xyz + cameraPosition.xyz;


		refraction = waterNormals(posxz.xz - posxz.y, istransparent+ice);

		vec2 depth = vec2(0.0);
			depth.x = getDepth(startPixeldepth);
			depth.y = getDepth(startPixeldepth2);

		float refMult = 1.0;
			refMult = clamp(depth.x - depth.y,0.0,1.0);
			refMult /= depth.y;
			refMult *= REFRACT_MULT / 100.0;
			refMult *= mix(mix(1.0,0.3,istransparent), 0.5, ice);


		coord1 = texcoord.st + refraction.xy * refMult;
		coord2 = texcoord.st + refraction.xy * refMult;
		coord3 = texcoord.st + refraction.xy * refMult;

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

float pixeldepth = texture2D(depthtex1,refractionTC.xy).x;
float pixeldepth2 = texture2D(depthtex0,refractionTC.xy).x;

vec3 AtmosphericScattering(vec3 color, vec3 fragpos, float isRef){
		return vec3(1.0, 0.2, 0.0)*0.3;
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}


float dynamicExposure() {
		return clamp((-eyeBrightnessSmooth.y+230)/100.0,0.0,1.0);
}


#ifdef FOG

vec3 getFog(vec3 color, bool land, bool land2, vec2 pos, vec3 fragpos){

	vec3 fragposFog = vec3(pos.st, texture2D(depthtex0, pos.st).r);
	fragposFog = nvec3(gbufferProjectionInverse * nvec4(fragposFog * 2.0 - 1.0));
	vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragposFog,1.0);
	float horizon = (worldposition.y - (pos.y-cameraPosition.y));

	float calcHeight = (max(pow(max(1.5 - horizon/100.0, 0.0), 1.0)-0.0, 0.0));

		float fog = exp(-pow(sqrt(dot(fragposFog,fragposFog))/100* 0.7 ,2.0));
		float fogfactor =  clamp(fog + hand,0.0,1.0);

		color = pow(color, vec3(2.2));
		vec3 fogclr = AtmosphericScattering(color, fragpos, 1.0);

		color.rgb = mix(color.rgb,pow(fogclr, vec3(2.2)),(1-fogfactor)*(clamp(calcHeight,0.0,1.0)));

	return pow(color, vec3(0.4545));
}
#endif

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
        if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0){
					break;
				}
        vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
        spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
        float err = distance(fragpos.xyz,spos.xyz);
        if(err < pow(sqrt(dot(vector,vector))*pow(sqrt(dot(vector,vector)),0.11),1.1)*1.1){

                sr++;
                if(sr >= maxf){

					bool land = texture2D(depthtex0, pos.st).r < comp;
                    float border = clamp(1.0 - pow(cdist(pos.st), 10.0), 0.0, 1.0);
                    color = (texture2D(gcolor, pos.st)) * MAX_COLOR_RANGE;

						color.a = 1.0;

						#ifdef FOG
							color.rgb = getFog(color.rgb, land, land, pos.st, fragpos);
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
	vec3 sclr = AtmosphericScattering(color.rgb, reflectedVector, 0.0)*3;

	return sclr;
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

	if (iswater > 0.9 || istransparent > 0.9 || ice > 0.9)	color = refraction;

	return color;
}

#endif

vec3 getColorCorrection(vec3 color, bool land){

	//Color changes depends on time//

	color.b += color.b*0.1*TimeNoon*(1-rainx)*(1-islava);
	color.r -= color.r*0.15*TimeNoon*(1-rainx)*(1-islava);

	color.bg += color.bg*.1*(1-islava*(1-rainx));

	return color.rgb;
}

bool getLand(sampler2D depth){
	return texture2D(depth, refractionTC.st).r < comp;
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

	bool land = getLand(depthtex1);
	bool land2 = getLand(depthtex0);

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

	vec3 fragpos = vec3(texcoord.st, pixeldepth2);
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));

	vec3 fragpos2 = vec3(refractionTC.st, pixeldepth);
	fragpos2 = nvec3(gbufferProjectionInverse * nvec4(fragpos2 * 2.0 - 1.0));

	vec4 sPos = gbufferProjectionInverse * (vec4(texcoord.st,startPixeldepth2,1.0) * 2.0 - 1.0);
	sPos /= sPos.w;

	vec4 worldposition = vec4(0.0);
		 worldposition = gbufferModelViewInverse * vec4(fragpos,1.0);


	#ifdef WATER_REFRACT
		color = waterRefraction(color);
	#endif


	if(!land) color = AtmosphericScattering(color, fragpos.rgb, 1.0);

	// setting up light color
	//	vec3 light_col = mix(pow(sunlight * (transition_fading * (1.0 - TimeMidnight)),vec3(4.4)), moonlight*50, moonVisibility * transition_fading * TimeMidnight * (1.0 - (TimeSunrise + TimeSunset)));
	//	light_col = mix(light_col,vec3(sqrt(dot(light_col,light_col)))*vec3(0.25,0.32,0.4),rainx);
	//	light_col = pow(light_col,mix(vec3(1.0 / 5.0),vec3(0.5), pow(TimeSunrise + TimeSunset,3.0) + TimeMidnight));
	//	light_col = mix(light_col, vec3(0.5), rainStrength);

		float normalDotEye = dot(normal2, normalize(fragpos));

		vec3 fresnel = vec3(saturate(pow(1.0 + normalDotEye, 1.0)));
		fresnel.y = clamp(pow(1.0 + normalDotEye, 0.75),0.0,1.0);

		normalDotEye = dot(normal, normalize(fragpos));

		fresnel.z = clamp(pow(1.0 + normalDotEye, 1.0),0.0,1.0);
		fresnel.xz = pow(fresnel.xz,vec2(2.0));


		vec3 npos = normalize(fragpos2);
		vec3 reflectedVector = normalize(reflect(npos, normalize(normal2)));
		vec3 reflectedVector2 = normalize(reflect(npos, normalize(normal)));

	#ifdef REFLECTIONS
			vec4 reflection = vec4(0.0);
			vec3 specColor = mix(vec3(1.0), rawAlbedo, specular.g);

			vec3 getSky = getSkyReflection(mix(reflectedVector2, reflectedVector, istransparent + iswater + ice), color.rgb)*float(land2);
			getSky *= fresnel.x;

			getSky *= specColor;
			getSky *= specmap+istransparent+ice;

			if(float(land) > 0.9) {
				reflection = raytrace(fragpos, normal, getSky, reflectedVector2, fresnel.x);
				reflection.rgb = mix(getSky * reflectionSkyLight, reflection.rgb, reflection.a)*(1-translucent);
				reflection.a = 1.0;

				#ifdef SPECULAR_REFLECTIONS
					color.rgb += (pow(reflection.rgb, vec3(1))*fresnel.x*reflection.a)*specmap*(1-iswater);
				#endif
			}

	#endif

	vec3 forwardRenderingAlbedo = renderGaux2(color, texcoord.st);
	color = forwardRenderingAlbedo;

	#ifdef FOG
		color.rgb = getFog(color, land2, land, refractionTC.st, fragpos);
	#endif

	//	color.rgb = getColorCorrection(color,land);

	//color = mix(color, vec3(1.0),vec3(clamp(exp(-depth * 5.0),0.0,1.0)) * iswater * pow(getRainPuddles(20.0, frameTimeCounter / 2000.0),1.0));
/* DRAWBUFFERS:0 */

	gl_FragData[0] = vec4(color / MAX_COLOR_RANGE,1.0);

}
