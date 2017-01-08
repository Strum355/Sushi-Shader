#version 120

	#define BLOOM									//Makes glow effect on bright stuffs.

	const float nightBloom = 3;
	const float dayBloom = 10;

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D gaux4;

uniform float aspectRatio;
uniform float viewWidth;
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;

float timefract = worldTime;

float pw = 1.0/ viewWidth;
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 makeBloom(float lod,vec2 offset){

	vec3 bloom = vec3(0.0);
	float scale = pow(2.0,lod);
	vec2 coord = (texcoord.xy-offset)*scale;
	if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1){
		for (int i = -7; i < 7; i++) {
			for (int j = -7; j < 7; j++) {
			vec2 bcoord = (texcoord.xy-offset+vec2(i,j)*pw*vec2(1.0,aspectRatio))*scale;

			float wg = pow((1.0-length(vec2(i,j))/8.0),3)*pow(0.5,0.5)*20.0;

			if (wg > 0) bloom +=(pow(texture2D(gcolor,bcoord).rgb,vec3(2.2))*wg)*4;
			}
		}
		bloom /= 49;
	}

	return bloom;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
vec3 blur = vec3(0);
	#ifdef BLOOM
	 blur += makeBloom(2,vec2(0,0));
	 blur += makeBloom(3,vec2(0.3,0));
	 blur += makeBloom(4,vec2(0,0.3));
	 blur += makeBloom(5,vec2(0.1,0.3));
	 blur += makeBloom(6,vec2(0.2,0.3));
	#endif
blur = clamp(pow(blur,vec3(1.0/2.2)),0.0,1.0);
/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(blur,1.0);
}
