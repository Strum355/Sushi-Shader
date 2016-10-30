#version 120
#extension GL_ARB_shader_texture_lod : enable


/*
!! DO NOT REMOVE !! !! DO NOT REMOVE !!

This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !! !! DO NOT REMOVE !!


Sharing and modification rules

Sharing a modified version of my shaders:
-You are not allowed to claim any of the code included in "Chocapic13' shaders" as your own
-You can share a modified version of my shaders if you respect the following title scheme : " -Name of the shaderpack- (Chocapic13' Shaders edit) "
-You cannot use any monetizing links
-The rules of modification and sharing have to be same as the one here (copy paste all these rules in your post), you cannot make your own rules
-I have to be clearly credited
-You cannot use any version older than "Chocapic13' Shaders V4" as a base, however you can modify older versions for personal use
-Common sense : if you want a feature from another shaderpack or want to use a piece of code found on the web, make sure the code is open source. In doubt ask the creator.
-Common sense #2 : share your modification only if you think it adds something really useful to the shaderpack(not only 2-3 constants changed)


Special level of permission; with written permission from Chocapic13, if you think your shaderpack is an huge modification from the original (code wise, the look/performance is not taken in account):
-Allows to use monetizing links
-Allows to create your own sharing rules
-Shaderpack name can be chosen
-Listed on Chocapic13' shaders official thread
-Chocapic13 still have to be clearly credited


Using this shaderpack in a video or a picture:
-You are allowed to use this shaderpack for screenshots and videos if you give the shaderpack name in the description/message
-You are allowed to use this shaderpack in monetized videos if you respect the rule above.


Minecraft website:
-The download link must redirect to the link given in the shaderpack's official thread
-You are not allowed to add any monetizing link to the shaderpack download

If you are not sure about what you are allowed to do or not, PM Chocapic13 on http://www.minecraftforum.net/
Not respecting these rules can and will result in a request of thread/download shutdown to the host/administrator, with or without warning. Intellectual property stealing is punished by law.
*/
//disabling is done by adding "//" to the beginning of a line.
/*--------------------------------*/
const bool gaux2MipmapEnabled = true;

#define BLOOM
#define BLOOM_STRENGTH 1
/*--------------------------------*/
varying vec4 texcoord;
varying vec3 sunlight;
varying vec3 ambient_color;

uniform sampler2D gcolor;
uniform vec3 sunPosition;
uniform int worldTime;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

vec3 sunPos = sunPosition;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float timefract = worldTime;
/*--------------------------------*/
float timeMidnight = ((clamp(timefract, 13000.0, 13750.0) - 13000.0) / 750.0) - ((clamp(timefract, 24000.0, 24000.0) - 24000.0) / 1000.0);

vec3 makeBloom(float lod,vec2 offset){
	vec3 bloom = vec3(0.0);
	float scale = pow(2.0,lod);
	vec2 coord = (texcoord.xy-offset)*scale;
	if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1){
	for (int i = 0; i < 7; i++) {
		for (int j = 0; j < 7; j++) {
		float wg = exp(3.0-length(vec2(i-3.5,j-3.5)));
		vec2 bcoord = (texcoord.xy-offset+vec2(i-3.5,j-3.5)*pw*vec2(1.0,aspectRatio))*scale;
		if (wg > 0) bloom += pow(texture2DLod(gcolor,bcoord,0).rgb,vec3(2.2))*wg;
		}
	}
	bloom /= 49;
}

return bloom*BLOOM_STRENGTH;
}

void main() {
vec3 blur = vec3(0);
#ifdef BLOOM
 blur += makeBloom(2,vec2(0,0));
 blur += makeBloom(3,vec2(0.3,0));
 blur += makeBloom(4,vec2(0,0.3));
 blur += makeBloom(5,vec2(0.1,0.3));
 blur += makeBloom(6,vec2(0.2,0.3));
// blur += makeBloom(7,vec2(0.3,0.3));
#endif
blur = clamp(pow(blur,vec3(1.0/2.2)),0.0,1.0);
/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(blur,1.0);
}
