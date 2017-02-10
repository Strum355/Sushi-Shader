#version 120

#define BLOOM	 //Makes glow effect on bright stuffs.

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;

uniform float aspectRatio;
uniform float viewWidth;

float pw = 1.0/ viewWidth;

vec3 makeBloom(float lod,vec2 offset){

	vec3 bloom = vec3(0.0);
	float scale = pow(2.0,lod);
	vec2 coord = (texcoord.xy-offset)*scale;
	if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1){
		for (int i = -7; i < 7; i++) {
			for (int j = -7; j < 7; j++) {
			vec2 bcoord = (texcoord.xy-offset+vec2(i,j)*pw*vec2(1.0,aspectRatio))*scale;

			float wg = pow((1.0-length(vec2(i,j))/10.0),3)*pow(0.5,0.5)*60.0;

			if (wg > 0) bloom +=(pow(texture2D(gcolor,bcoord).rgb,vec3(2.2))*wg);
			}
		}
		bloom /= 225;
	}

	return bloom;
}

void main() {
vec3 blur = vec3(0);
	#ifdef BLOOM
	 blur += makeBloom(2,vec2(0,0));
	 blur += makeBloom(3,vec2(0.3,0));
	 blur += makeBloom(4,vec2(0,0.3));
	 blur += makeBloom(5,vec2(0.1,0.3));
	 blur += makeBloom(6,vec2(0.2,0.3));
	#endif
	blur = pow(blur,vec3(1.0/2.2));
/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(blur,1.0);
}
