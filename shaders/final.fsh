#version 120

//disabling is done by adding "//" to the beginning of a line.

//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//

//***************************BLOOM***************************//

#define BLOOM
	#define BLOOM_STRENGTH 5.0		//basic multiplier
	#define FOG_SCATTER 3.0 //[1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0] how much fog scattering occurs during rain

#define DYNAMIC_EXPOSURE					//Makes brighter inside and turned off outside
	#define DYNAMIC_EXPOSURE_AMOUNT 1.0	//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]	//Strength


#define CALCULATE_EXPOSURE					//Makes darker spots in the water darker. How deeper, the darker it gets.

#define RAIN_DROP

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

const bool		gcolorMipmapEnabled		= 	true; //gcolor texture mipmapping

varying vec4 texcoord;
varying vec3 sunlight;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
varying vec3 ambient_color;
varying vec3 lightVector;

uniform sampler2D gcolor;
uniform sampler2D composite;
uniform sampler2D noisetex;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex0;
uniform sampler2D gaux1;
uniform mat4 gbufferProjection;
uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;

#include "lib/colorRange.glsl"

float pw = 1.0/ viewWidth;
float timefract = worldTime;

float comp = 1.0-near/far/far;			//distance above that are considered as sky

//Raining
float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;

//Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float distx(float dist){
	return (far * (dist - near)) / (dist * (far - near));
}

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float saturate(float value){
		return clamp(value, 0.0, 1.0);
}

vec3 saturate(vec3 value){
	return clamp(value, 0.0, 1.0);
}


vec4 getTpos(){

	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	return vec4(tpos.xyz/tpos.w,1.0);

}

vec2 getLightPos(){
		vec2 pos1 = getTpos().xy/getTpos().z;
		return pos1*0.5+0.5;

}

#ifdef RAIN_DROP
float waterDrop (vec2 tc) {
	vec2 drop = vec2(0.0,fract(frameTimeCounter/750.0));
	tc.x *= 10;
	float noise = texture2D(noisetex,(tc+drop)/2).x;
	noise += texture2D(noisetex,(tc+drop)).x/2;
	noise += texture2D(noisetex,(tc+drop)*2).x/4;
	noise += texture2D(noisetex,(tc+drop)*4).x/8;
	noise += texture2D(noisetex,(tc+drop*0.5)).x/2;
	noise += texture2D(noisetex,(tc+drop*0.5)*2).x/4;
	noise += texture2D(noisetex,(tc+drop*0.5)*4).x/8;
	float dropstrength = max(noise-1.8,0.0);
	float wdrop = 0.1;
	float waterD = (1.0 - (pow(wdrop,dropstrength)));
	waterD *= clamp((eyeBrightnessSmooth.y-220)/15.0,0.0,1.0)*rainStrength;
	return waterD;
}
#endif

vec2 customTexcoord(){
	vec2 fake_refract;
	vec2 fake_refract2;

	vec2 texC = texcoord.st;

	//texC = texC * 0.5 + 0.5;									// Inverting texcoord
	//texC = mix(texC,floor(texC * 2.0) / 2.0,2.0) * 2.0;		//

	//float pixelSize = 20.0;													// Pixelizing shader
	//																			//
	//texC = floor(texC * pixelSize) / pixelSize + (1.0 / pow(pixelSize,1.4));	//

	//texC = mix(texC, (texC * 2.0 - getLightPos() * 2.0) * 0.0 * 0.5 + getLightPos(), (1.0 / (distance((texC * 2.0 - getLightPos() * 2.0) * 10.0 * 0.5 + getLightPos(), getLightPos()) - 0.35))); //Black hole shader
	//texC = mix(texC, (texC * 2.0 - 1.0) * 0.0 * 0.5 + 0.5, (1.0 / (distance((texC * 2.0 - 1.0) * 10.0 * 0.5 + 0.5, vec2(0.5)) - 0.35))); //Black hole shader

	//texC = mix(texC, vec2(0.5), pow(distance(texC, vec2(0.5)),3.0) * 5.0); //Warp Drive Shader

	//texC = mix(texC, normalize(texC - vec2(0.5)) * 0.5 + 0.5, clamp(pow(distance(texC, vec2(0.5)),10.0) * 50.0,0.0,1.0));

	vec2 custom;

	fake_refract = vec2(sin(frameTimeCounter*2.0 + texC.x*0.0 + texC.y*25.0),cos(frameTimeCounter*2.0 + texC.y*0.0 + texC.x*50.0)) * 2.5 *isEyeInWater;
	#ifdef RAIN_DROP
		fake_refract2 = vec2(sin(frameTimeCounter*1.0 + texC.x*0.0 + texC.y*100.0),cos(frameTimeCounter*1.0 + texC.y*0.0 + texC.x*200.0))*waterDrop(texC.xy/300)*5 ;
	#endif

	vec2 refracts = (fake_refract + fake_refract2) / 500.0;

	custom = refracts;

	return texC.st + custom;
}

vec2 Tc = customTexcoord();

vec4 aux = texture2D(gaux1, Tc.xy);
float depth = texture2D(gdepthtex, Tc.xy).x;

float sky_lightmap = aux.r;

int iswater = int(aux.g > 0.04 && aux.g < 0.07);
int land = int(aux.g < 0.03);
bool land2 = depth < comp;
float ice = float(aux.g > 0.09 && aux.g < 0.11);

float hand = float(aux.g > 0.75 && aux.g < 0.85);

float islava = float(aux.a > 0.50 && aux.a < 0.55);

struct Bloom {
	vec3 blur1;
	vec3 blur2;
	vec3 blur3;
	vec3 blur4;
	vec3 blur5;
} bloom;

float distratio(vec2 pos, vec2 pos2, float ratio) {
	float xvect = pos.x*ratio-pos2.x*ratio;
	float yvect = pos.y-pos2.y;

	return sqrt(xvect*xvect + yvect*yvect);
}

vec2 noisepattern(vec2 pos) {
	return vec2(abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f)),abs(fract(sin(dot(pos.yx ,vec2(18.9898f,28.633f))) * 4378.5453f)));
}

vec3 calcExposure(vec3 color) {
         float maxx = 0.1;
         float minx = 1.0;

         float exposure = max(pow(sky_lightmap, 1.0), 0.0)*maxx + minx;

         color.rgb /= vec3(exposure);

         return color.rgb;
}

vec3 dynamicExposure(vec3 color) {
		return color.rgb * clamp((-eyeBrightnessSmooth.y+230)/100.0,0.0,1.0)*2.5*(1-TimeMidnight)*(1-rainx)*DYNAMIC_EXPOSURE_AMOUNT;
}

vec3 alphablend(vec3 c, vec3 ac, float a) {

	vec3 n_ac = normalize(ac)*(1/sqrt(3.));
	vec3 nc = sqrt(c*n_ac);
	return mix(c,nc,a);
}

vec3 getExposure(vec3 color){

	color *= 2.0;

	return color;
}

vec3 getSaturation(vec3 color, float saturation)
{
	saturation -= 1.0;
	color = mix(color,vec3(dot(color,vec3(1.0/3.0))),vec3(-saturation));

	return color;
}

#ifdef BLOOM

	vec3 getBloom(in vec2 bCoord, Bloom b){

		vec3 blur = vec3(0);

		b.blur1 = pow(texture2D(composite,bCoord/pow(2.0,2.0) + vec2(0.0,0.0)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*3.0;
		b.blur2 = pow(texture2D(composite,bCoord/pow(2.0,3.0) + vec2(0.3,0.0)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*4.0;
		b.blur3 = pow(texture2D(composite,bCoord/pow(2.0,4.0) + vec2(0.0,0.3)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*5.0;
		b.blur4 = pow(texture2D(composite,bCoord/pow(2.0,5.0) + vec2(0.1,0.3)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*6.0;
		b.blur5 = pow(texture2D(composite,bCoord/pow(2.0,6.0) + vec2(0.2,0.3)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*7.0;

		blur = b.blur1 + b.blur2 + b.blur3 + b.blur4 + b.blur5;

		return blur;
	}

#endif

void NJTonemap(inout vec3 color){
    //color *= 1.2;
    // a b g c d
    color = color/((color+0.5)+(0.06-color+0.1)/(0.13+color)+0.75);
    color = pow(color, vec3(1.0/2.2));
    //color = 1-color;
}

vec3 robobo1221sTonemap(vec3 color){

	float a = 1;
	float b = 2;
	float c = 1;

	vec3 x = color - 0.04;
	vec3 cout = ((3.8 * x + 0.2 * a) / (3.7 * x + 0.6));
		cout = pow(cout, vec3(b * c)) * c;

	return cout;
}

//VOID MAIN//

void main() {

	const float lifetime = 3.0;
	float ftime = frameTimeCounter*2.0/lifetime;

	vec2 pos = (noisepattern(vec2(-0.94386347*floor(ftime*0.5+0.25),floor(ftime*0.5+0.25)))-0.5)*0.85+0.5;


	vec3 color = texture2D(gcolor,Tc.st).rgb * MAX_COLOR_RANGE;

	float fogDensity = saturate(pow(exp(ld(texture2D(depthtex0, Tc.st).r)), 3.0)-2.0);
	#ifdef BLOOM
		color.rgb = mix(color,getBloom(Tc.st, bloom)*MAX_COLOR_RANGE*0.2,saturate(0.3+fogDensity*rainStrength));
	#endif

	#ifdef CALCULATE_EXPOSURE
		if (isEyeInWater > 0.9){
		//	color.rgb = calcExposure(color);
			color *= vec3(1.0, 3.0, 4.0)/2;
		}
	#endif
	
	color = getExposure(color);
	color = robobo1221sTonemap(color);

/////////////////////////////////////////////////////////////////////////////////////

	gl_FragColor = vec4(color.rgb, 1.0);

}
