#version 120

//disabling is done by adding "//" to the beginning of a line.

//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//

//***************************BLOOM***************************//

#define BLOOM
	#define BLOOM_STRENGTH 0.5		//[0.1 0.5 1.0] basic multiplier
	#define FOG_SCATTER 3.0 //[0.1 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0] how much fog scattering occurs during rain

#define CALCULATE_EXPOSURE					//Makes darker spots in the water darker. How deeper, the darker it gets.

#define RAIN_DROP

//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//
//***************************END OF ADJUSTABLE VARIABLES***************************//

const bool		gcolorMipmapEnabled		= 	true; //gcolor texture mipmapping

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D composite;
uniform sampler2D noisetex;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gaux1;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
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

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

float saturate(float value){
		return clamp(value, 0.0, 1.0);
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
vec3 saturate(vec3 value){
	return clamp(value, 0.0, 1.0);
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

//	fake_refract = vec2(sin(frameTimeCounter*2.0 + texC.x*0.0 + texC.y*25.0),cos(frameTimeCounter*2.0 + texC.y*0.0 + texC.x*50.0)) * 2.5 *isEyeInWater;
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

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
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
	float b = 2.2;

	vec3 x = color;
	vec3 cout = ((4.3 * x + 0.0 ) / (4.3 * x + 0.6));
		cout = pow(cout, vec3(b));

	return cout;
}

void main() {
	vec3 color = texture2D(gcolor,Tc.st).rgb * MAX_COLOR_RANGE;

	vec3 pos1 = vec3(Tc.st, texture2D(depthtex1, Tc.st).r);
	pos1 = nvec3(gbufferProjectionInverse * nvec4(pos1 * 2.0 - 1.0));
	float fogDensity = 1-saturate(exp(-pow(length(pos1)/100, FOG_SCATTER)));
	float bloomMix = mix(0.1, 0.05+fogDensity, rainStrength);
	#ifdef BLOOM
		color.rgb = mix(color,getBloom(Tc.st, bloom)*MAX_COLOR_RANGE*BLOOM_STRENGTH,saturate(.1));
	#endif

		if (isEyeInWater > 0.9){
			color *= vec3(1.0, 3.0, 4.0)/2;
		}

	color.r -= 0.01*TimeMidnight;
	color += find_closest(texcoord.st)/255; //some dithering to help with banding
	color = robobo1221sTonemap(color);

	//color = getBloom(Tc.st, bloom)*MAX_COLOR_RANGE;
	//TODO fix rain sky. final and composite1 problematic

	gl_FragColor = vec4(color.rgb, 1.0);

}
