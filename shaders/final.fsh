#version 120
#extension GL_ARB_shader_texture_lod : enable

#define MAX_COLOR_RANGE 24.0 //[1.0 2.0 4.0 6.0 12.0 24.0 48.0 96.0]

//disabling is done by adding "//" to the beginning of a line.

//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
//***************************ADJUSTABLE VARIABLES***************************//
//***************************BLOOM***************************//

#define BLOOM
	#define B_INTENSITY 5.0		//basic multiplier

//***************************DOF***************************//

//#define DOF
	#define DOF_MULT 3.0
//#define TILT_SHIFT 					//to let everything look small. more for cinematic purposes
	#define TILT_SHIFT_MULT 1.0		//simple multiplier
//#define FRINGE_DOF						//to give the dof a rainbow look
	#define FRINGE_AMOUNT 1.0		//the amound of fringe
//#define DISTANCE_BLUR					//to let the background fade out
	#define DISTANCE_BLUR_MULT 1.0	//simple multiplier
	#define DISTANCE_BLUR_DIST 1.0	//distance

//***************************COLORS***************************//

#define BRIGHTNESS 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]
#define GAMMA 2.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define CONTRAST 1.0 //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]
#define SATURATION 1.25 //[1.0 1.1 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]

//***************************EFFECTS***************************//
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
uniform sampler2D depthtex1;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;

float pw = 1.0/ viewWidth;
float timefract = worldTime;

float comp = 1.0-near/far/far;			//distance above that are considered as sky
 float transparent = float(texture2D(depthtex0, texcoord.st).x < texture2D(depthtex1, texcoord.st).x);
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

vec4 getTpos(){

	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	return vec4(tpos.xyz/tpos.w,1.0);

}

float 	ExpToLinearDepth(in float depth)
{
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

vec2 getLightPos(){
		vec2 pos1 = getTpos().xy/getTpos().z;
		return pos1*0.5+0.5;

}

float subSurfaceScattering(vec3 vec,vec3 pos, float N) {

return pow(max(dot(vec,normalize(pos))*0.5+0.5,0.0),N)*(N+1)/6.28;

}

float distratio(vec2 pos, vec2 pos2) {
	float xvect = pos.x*aspectRatio-pos2.x*aspectRatio;
	float yvect = pos.y-pos2.y;
	return sqrt(xvect*xvect + yvect*yvect);
}

vec2 noisepattern(vec2 pos) {
	return vec2(abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f)),abs(fract(sin(dot(pos.yx ,vec2(18.9898f,28.633f))) * 4378.5453f)));
}

float gen_circular_lens(vec2 center, float size) {
	float dist=distratio(center,texcoord.xy)/size;
	return exp(-dist*dist);
}

#ifdef RAIN_DROP
float waterDrop (vec2 tc) {
	const float lifetime = 15.0;		//water drop lifetime in seconds

	float ftime = frameTimeCounter*2.0/lifetime;
	vec2 drop = vec2(0.0,fract(frameTimeCounter/20.0));

	float gen = 1.0-fract((ftime+0.5)*0.1);
	vec2 pos = (noisepattern(vec2(-0.94386347*floor(ftime*0.5+0.25),floor(ftime*0.5+0.25))))*0.8+0.1 - drop;
  float rainlens = gen_circular_lens(fract(pos),0.04)*gen*rainStrength;
	gen = 1.0-fract((ftime+1.0)*0.5);
	pos = (noisepattern(vec2(0.9347*floor(ftime*0.5+0.5),-0.2533282*floor(ftime*0.5+0.5))))*0.8+0.1- drop;

	rainlens += gen_circular_lens(fract(pos),0.023)*gen*rainStrength;
	gen = 1.0-fract((ftime+1.5)*0.5);
	pos = (noisepattern(vec2(0.785282*floor(ftime*0.5+0.75),-0.285282*floor(ftime*0.5+0.75))))*0.8+0.1- drop;

	rainlens += gen_circular_lens(fract(pos),0.03)*gen*rainStrength;
	gen =  1.0-fract(ftime*0.5);
	pos = (noisepattern(vec2(-0.347*floor(ftime*0.5),0.6847*floor(ftime*0.5))))*0.8+0.1- drop;

	rainlens += gen_circular_lens(fract(pos),0.05)*gen*rainStrength;

	rainlens *= clamp((eyeBrightnessSmooth.y-220)/15.0,0.0,1.0);

	return rainlens*5;
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
		fake_refract2 = vec2(sin(frameTimeCounter*1.0 + texC.x*0.0 + texC.y*100.0),cos(frameTimeCounter*1.0 + texC.y*0.0 + texC.x*200.0))*waterDrop(texC.xy/300)*6 ;
	#endif

	vec2 refracts = (fake_refract + fake_refract2) / 500.0;

	custom = refracts;

	return texC.st + custom;
}

vec2 Tc = customTexcoord();

vec4 aux = texture2D(gaux1, Tc.xy);
float depth = texture2D(gdepthtex, Tc.xy).x;

float sky_lightmap = aux.r;

#ifdef TILT_SHIFT
const float focal = 2.0;
float aperture = 0.6;
const float sizemult = 0.25*TILT_SHIFT_MULT;
#else
const float focal = 0.05;
float aperture = 0.002;
const float sizemult = 50.0*DOF_MULT;
#endif

	//hexagon pattern
	const vec2 hex_offsets[60] = vec2[60] (	vec2(  0.2165,  0.1250 ),
											vec2(  0.0000,  0.2500 ),
											vec2( -0.2165,  0.1250 ),
											vec2( -0.2165, -0.1250 ),
											vec2( -0.0000, -0.2500 ),
											vec2(  0.2165, -0.1250 ),
											vec2(  0.4330,  0.2500 ),
											vec2(  0.0000,  0.5000 ),
											vec2( -0.4330,  0.2500 ),
											vec2( -0.4330, -0.2500 ),
											vec2( -0.0000, -0.5000 ),
											vec2(  0.4330, -0.2500 ),
											vec2(  0.6495,  0.3750 ),
											vec2(  0.0000,  0.7500 ),
											vec2( -0.6495,  0.3750 ),
											vec2( -0.6495, -0.3750 ),
											vec2( -0.0000, -0.7500 ),
											vec2(  0.6495, -0.3750 ),
											vec2(  0.8660,  0.5000 ),
											vec2(  0.0000,  1.0000 ),
											vec2( -0.8660,  0.5000 ),
											vec2( -0.8660, -0.5000 ),
											vec2( -0.0000, -1.0000 ),
											vec2(  0.8660, -0.5000 ),
											vec2(  0.2163,  0.3754 ),
											vec2( -0.2170,  0.3750 ),
											vec2( -0.4333, -0.0004 ),
											vec2( -0.2163, -0.3754 ),
											vec2(  0.2170, -0.3750 ),
											vec2(  0.4333,  0.0004 ),
											vec2(  0.4328,  0.5004 ),
											vec2( -0.2170,  0.6250 ),
											vec2( -0.6498,  0.1246 ),
											vec2( -0.4328, -0.5004 ),
											vec2(  0.2170, -0.6250 ),
											vec2(  0.6498, -0.1246 ),
											vec2(  0.6493,  0.6254 ),
											vec2( -0.2170,  0.8750 ),
											vec2( -0.8663,  0.2496 ),
											vec2( -0.6493, -0.6254 ),
											vec2(  0.2170, -0.8750 ),
											vec2(  0.8663, -0.2496 ),
											vec2(  0.2160,  0.6259 ),
											vec2( -0.4340,  0.5000 ),
											vec2( -0.6500, -0.1259 ),
											vec2( -0.2160, -0.6259 ),
											vec2(  0.4340, -0.5000 ),
											vec2(  0.6500,  0.1259 ),
											vec2(  0.4325,  0.7509 ),
											vec2( -0.4340,  0.7500 ),
											vec2( -0.8665, -0.0009 ),
											vec2( -0.4325, -0.7509 ),
											vec2(  0.4340, -0.7500 ),
											vec2(  0.8665,  0.0009 ),
											vec2(  0.2158,  0.8763 ),
											vec2( -0.6510,  0.6250 ),
											vec2( -0.8668, -0.2513 ),
											vec2( -0.2158, -0.8763 ),
											vec2(  0.6510, -0.6250 ),
											vec2(  0.8668,  0.2513 ));

int iswater = int(aux.g > 0.04 && aux.g < 0.07);
int land = int(aux.g < 0.03);
bool land2 = depth < comp;

float hand = float(aux.g > 0.75 && aux.g < 0.85);

float islava = float(aux.a > 0.50 && aux.a < 0.55);

float distratio(vec2 pos, vec2 pos2, float ratio) {
	float xvect = pos.x*ratio-pos2.x*ratio;
	float yvect = pos.y-pos2.y;

	return sqrt(xvect*xvect + yvect*yvect);
}


	float smoothCircleDist (in float lensDist) {

		vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
			 tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 lightPos = tpos.xy/tpos.z*lensDist;
			 lightPos = (lightPos + 1.0f)/2.0f;

		return distratio(lightPos.xy, Tc.xy, aspectRatio);

	}


vec3 genlens(vec3 lenscolor, float dist, float size, vec4 tpos, float sun, float smoothness) {

	vec2 lightPos = tpos.xy/tpos.z*dist; lightPos = (lightPos + 1.0f)/2.0f;
    float lensFlare = max(pow(max(1 - pow(min(distratio(lightPos.xy, Tc.xy, aspectRatio),size)/size,smoothness),0.0),5.0),0.0);
    return clamp(lensFlare, 0.0, 1.0) * lenscolor * 0.5 * sun * (1.0-rainStrength);
}

vec3 genRingLens(vec3 lenscolor, float dist, float size, float size2, vec4 tpos, float sun, float smoothness) {

	vec2 lightPos = tpos.xy/tpos.z*dist; lightPos = (lightPos + 1.0f)/2.0f;
    float lensFlare = max(pow(max(1 - pow(min(distratio(lightPos.xy, Tc.xy, aspectRatio),size)/size,smoothness),0.0),5.0),0.0);
	float lensFlare2 = max(pow(max(1 - pow(min(distratio(lightPos.xy, Tc.xy, aspectRatio),size2)/size2,smoothness),0.0),5.0),0.0);

    return clamp(lensFlare - lensFlare2, 0.0, 1.0) * lenscolor * 0.5 * sun * (1.0-rainStrength);
}


vec3 genlensFloatingAna(vec3 lenscolor, float dist, float size, float stretch, vec4 tpos, float sun) {

	vec2 lightPos = tpos.xy/tpos.z*dist; lightPos = (lightPos + 1.0f)/2.0f;
    float lensFlare = max(pow(max(1 - pow(min(distratio(lightPos.xy, Tc.xy, aspectRatio/(stretch/size)),size)/size,10.0),0.),5.0),0.0);
    return clamp(lensFlare, 0.0, 1.0) * lenscolor * 0.5 * sun * (1.0-rainStrength);
}


vec3 calcExposure(vec3 color) {
         float maxx = 0.1;
         float minx = 1.0;

         float exposure = max(pow(sky_lightmap, 1.0), 0.0)*maxx + minx;

         color.rgb /= vec3(exposure);

         return color.rgb;
}


/*
float getShine(vec2 Pos, vec2 lP) {

	vec2 movement = vec2(0.0,fract(frameTimeCounter/1000.0));
	movement += lP;

	vec2 coord = (Pos.xy/60);

	float Lens = texture2D(noisetex,(coord+movement)/2).x;

	float strength = max(Lens-0.5,0.0);
	float dL = 0.5;
	float L = (1.0 - (pow(dL,strength)));

	return L;
}
*/

float getShine2(vec2 Pos, float density, float power) {

	vec2 coord = (Pos.xy/3);

	float Lens = min(pow(texture2D(noisetex,(coord)/2).x*density,power),1.0);

	return Lens;
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


#ifdef BLOOM

	vec3 getBloom(in vec2 bCoord){

		vec3 blur = vec3(0);

		vec3 blur1 = pow(texture2D(composite,bCoord/pow(2.0,2.0) + vec2(0.0,0.0)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*pow(7.0,1.0);
		vec3 blur2 = pow(texture2D(composite,bCoord/pow(2.0,3.0) + vec2(0.3,0.0)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*pow(6.0,1.0);
		vec3 blur3 = pow(texture2D(composite,bCoord/pow(2.0,4.0) + vec2(0.0,0.3)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*pow(5.0,1.0);
		vec3 blur4 = pow(texture2D(composite,bCoord/pow(2.0,5.0) + vec2(0.1,0.3)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*pow(4.0,1.0);
		vec3 blur5 = pow(texture2D(composite,bCoord/pow(2.0,6.0) + vec2(0.2,0.3)).rgb,vec3(mix(2.2, 1.5, rainStrength)))*pow(3.0,1.0);

		blur = blur1 + blur2 + blur3 + blur4 + blur5;

		return blur;
	}

#endif


vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

//collab tonemap between noah (me) and joey (dotmodded)
void NJTonemap(inout vec3 color){
	//color *= 1.2;
	// a b g c d
	color = color/((color+0.5)+(0.06-color+0.1)/(0.13+color)+0.75);
	color = pow(color, vec3(1.0/2.2));
	//color = 1-color;
}

//VOID MAIN//

void main() {
	float pixeldepth2 = texture2D(depthtex0,texcoord.xy).x;

	vec3 fragpos = vec3(texcoord.st, pixeldepth2);
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));

	vec2 lightPos = getLightPos();

	float distof = min(min(1.0-lightPos.x,lightPos.x),min(1.0-lightPos.y,lightPos.y));
	float fading = clamp(1.0-step(distof,0.1)+pow(distof*10.0,5.0),0.0,1.0);

	float sunvisibility = min(texture2D(gcolor,vec2(0.0)).a*2.5,1.0) * (1.0-rainStrength*0.9) * fading;


	const float lifetime = 3.0;
	float ftime = frameTimeCounter*2.0/lifetime;
	vec4 aux = texture2D(gaux1, texcoord.st);
	int iswater = int(aux.g > 0.04 && aux.g < 0.07);
	int isIce = int(aux.g > 0.94 && aux.g < 0.96);
	float istransparent = float(aux.g > 0.4 && aux.g < 0.42)+isIce;

	vec2 pos = (noisepattern(vec2(-0.94386347*floor(ftime*0.5+0.25),floor(ftime*0.5+0.25)))-0.5)*0.85+0.5;
	float opaqueDepth = ExpToLinearDepth(texture2D(depthtex1, texcoord.st).x);
	float linearDepth = ExpToLinearDepth(texture2D(gdepthtex, texcoord.st).x);
	float waterDepth = (opaqueDepth) - linearDepth;
	float fogDensity = 10.0;
	float visibility = 1.0f / (pow(exp(waterDepth * fogDensity), 1.0f));


vec3 color;

/*if(isIce>0.9 ){
		 vec4 blendWeights = vec4(1.0, 0.5, 0.25, 0.125);
		 blendWeights = pow(blendWeights, vec4(visibility));

		 float blendWeightsTotal = dot(blendWeights, vec4(1.0));

		 color = texture2DLod(gcolor,Tc.st,0).rgb  * blendWeights.x * MAX_COLOR_RANGE;
		 color += texture2DLod(gcolor,Tc.st,1).rgb  * blendWeights.y * MAX_COLOR_RANGE;
		 color += texture2DLod(gcolor,Tc.st,2).rgb  * blendWeights.z * MAX_COLOR_RANGE;
		 color += texture2DLod(gcolor,Tc.st,2).rgb  * blendWeights.w * MAX_COLOR_RANGE;
		 color /= blendWeightsTotal;
} else {*/
	color = texture2D(gcolor,Tc.st).rgb  * MAX_COLOR_RANGE;
//}



	#ifdef DOF
		float DoFGamma = 2.2;
				//Calculate pixel Circle of Confusion that will be used for bokeh depth of field
				float z = ld(depth)*far;
				float focus = ld(texture2D(gdepthtex, vec2(0.5)).r)*far;
				float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,pw*10.0);
				vec4 sample = vec4(0.0);
				vec3 bcolor = vec3(0.0);
				float nb = 0.0;
				vec2 bcoord = vec2(0.0);
				float disblur = 1-(exp(-pow(ld(depth)/(256.0*DISTANCE_BLUR_DIST)*far,4.0)*4.0));
				#ifdef DISTANCE_BLUR
				pcoc += min(disblur*pw*20.0*DISTANCE_BLUR_MULT,pw*20.0*DISTANCE_BLUR_MULT);
				#endif

				for ( int i = 0; i < 60; i++) {
					#ifdef FRINGE_DOF

					sample.r = texture2D(gcolor, Tc.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio) + vec2(0.5*FRINGE_AMOUNT*pcoc),abs(pcoc * 150.0)).r * MAX_COLOR_RANGE;
					sample.g = texture2D(gcolor, Tc.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio),abs(pcoc * 150.0)).g * MAX_COLOR_RANGE;
					sample.b = texture2D(gcolor, Tc.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio) - vec2(0.5*FRINGE_AMOUNT*pcoc),abs(pcoc * 150.0)).b * MAX_COLOR_RANGE;
					#else
					sample = texture2D(gcolor, Tc.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio),abs(pcoc * 150.0)) * MAX_COLOR_RANGE;

					#endif

					bcolor += pow(sample.rgb, vec3(DoFGamma));
				}
			if (hand < 0.9) {
				color.rgb = pow(bcolor/60.0, vec3(1.0/DoFGamma));
			}
	#endif

	#ifdef BLOOM
		color.rgb += getBloom(Tc.st) * 0.03 * B_INTENSITY * MAX_COLOR_RANGE;
	#endif

	if (isEyeInWater > 0.9) color.rgb = calcExposure(color);

	NJTonemap(color);

	//color = texture2D(composite, texcoord.st/2).rgb*48;

	gl_FragColor = vec4(color, 1.0);
}
