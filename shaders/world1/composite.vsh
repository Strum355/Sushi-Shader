#version 120

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 sunlight_color;
varying vec3 ambient_color;
varying float handItemLight;
varying float eyeAdapt;
varying vec3 moonlight;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying float moonVisibility;

uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform int heldItemId;
uniform int heldItemId2;
uniform float rainStrength;

uniform ivec2 eyeBrightnessSmooth;
uniform mat4 gbufferModelView;

	float timefract = worldTime;

	float TimeSunrise  = ((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f));
	float TimeNoon     = ((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f);
	float TimeSunset   = ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f);
	float TimeMidnight = ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f);

	////////////////////sunlight color////////////////////
	////////////////////sunlight color////////////////////
	////////////////////sunlight color////////////////////
	const ivec4 ToD[25] = ivec4[25](ivec4(0,1.0,1.0,2.5), //hour,r,g,b
							ivec4(1,1.0,1.0,2.5),
							ivec4(2,1.0,1.0,2.5),
							ivec4(3,1.0,1.0,2.5),
							ivec4(4,1.0,1.0,2.5),
							ivec4(5,1.0,1.0,2.5),
							ivec4(6,180,50,10),
							ivec4(7,200,60,30),
							ivec4(8,100,100,100),
							ivec4(9,100,100,100),
							ivec4(10,100,100,100),
							ivec4(11,100,100,100),
							ivec4(12,100,100,100),
							ivec4(13,100,100,100),
							ivec4(14,100,100,100),
							ivec4(15,100,100,100),
							ivec4(16,100,100,100),
							ivec4(17,100,60,30),
							ivec4(18,100,50,10),
							ivec4(19,1.0,1.0,2.5),
							ivec4(20,1.0,1.0,2.5),
							ivec4(21,1.0,1.0,2.5),
							ivec4(22,1.0,1.0,2.5),
							ivec4(23,1.0,1.0,2.5),
							ivec4(24,1.0,1.0,2.5));

	////////////////////ambient color////////////////////
	////////////////////ambient color////////////////////
	////////////////////ambient color////////////////////
	const ivec4 ToD2[25] = ivec4[25](ivec4(0,30.0,25,80), //hour,r,g,b
							ivec4(1,30.0,25,80),
							ivec4(2,30.0,25,80),
							ivec4(3,30.0,25,80),
							ivec4(4,30.0,25,80),
							ivec4(5,30.0,25,80),
							ivec4(6,40,25.0,40.25),
							ivec4(7,45,25.0,40.25),
							ivec4(8,30,30.0,40.25),
							ivec4(9,30,30.0,40.25),
							ivec4(10,30,30.0,40.25),
							ivec4(11,30,30.0,40.25),
							ivec4(12,30,30.0,40.25),
							ivec4(13,30,30.0,40.25),
							ivec4(14,30,30.0,40.25),
							ivec4(15,30,30.0,40.25),
							ivec4(16,30,30.0,40.25),
							ivec4(17,30,25.0,40.25),
							ivec4(18,30,25.0,40.25),
							ivec4(19,30.0,25,80),
							ivec4(20,30.0,25,80),
							ivec4(21,30.0,25,80),
							ivec4(22,30.0,25,80),
							ivec4(23,30.0,25,80),
							ivec4(24,30.0,25,80));

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
void main() {

	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy);

	texcoord = gl_MultiTexCoord0;

	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}

	handItemLight = 0.0;

	float heldItemIdCombined = heldItemId + heldItemId2;

	if (heldItemId == 50 || heldItemId2 == 50 ) {
		// torch
		handItemLight = 0.5;
	}

	else if (heldItemId == 76 || heldItemId == 94 || heldItemId2 == 76 || heldItemId2 == 94) {
		// active redstone torch / redstone repeater
		handItemLight = 0.1;
	}

	else if (heldItemId == 89 || heldItemId2 == 89) {
		// lightstone
		handItemLight = 1.0;
	}

	else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51 || heldItemId2 == 10 || heldItemId2 == 11 || heldItemId2 == 51) {
		// lava / lava / fire
		handItemLight = 0.5;
	}

	else if (heldItemId == 91 || heldItemId2 == 91) {
		// jack-o-lantern
		handItemLight = 0.7;
	}

	else if (heldItemId == 327 || heldItemId2 == 327) {
		//lava bucket
		handItemLight = 1.5;
	}

		else if (heldItemId == 385 || heldItemId2 == 385) {
		//fire charger
		handItemLight = 0.2;
	}

		else if (heldItemId == 138 || heldItemId2 == 138) {
		//Beacon
		handItemLight = 1.0;
	}

		else if (heldItemId == 169 || heldItemId2 == 169) {
		//Sea lantern
		handItemLight = 1.0;
	}

	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);

	float MdotU = dot(moonVec,upVec);
	moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);

	vec3 wUp = (gbufferModelView * vec4(vec3(0.0,1.0,0.0),0.0)).rgb;
	vec3 wS1 = (gbufferModelView * vec4(normalize(vec3(3.5,1.0,3.5)),0.0)).rgb;
	vec3 wS2 = (gbufferModelView * vec4(normalize(vec3(-3.5,1.0,3.5)),0.0)).rgb;
	vec3 wS3 = (gbufferModelView * vec4(normalize(vec3(3.5,1.0,-3.5)),0.0)).rgb;
	vec3 wS4 = (gbufferModelView * vec4(normalize(vec3(-3.5,1.0,-3.5)),0.0)).rgb;

	eyeAdapt = 1.;
	eyeAdapt = (2.0-min(sqrt(dot(((wUp) + (wS1) + (wS2) + (wS3) + (wS4))*2.,((wUp) + (wS1) + (wS2) + (wS3) + (wS4))*2.))/sqrt(3.)*2.,eyeBrightnessSmooth.y/255.0*0.2))*(1-rainStrength*0.5);

	moonlight =  vec3(0.7,0.7,1.0)/2.0 * 0.012;

	float hour = worldTime/1000.0+6.0;
	if (hour > 24.0) hour = hour - 24.0;


	ivec4 temp = ToD[int(floor(hour))];
	ivec4 temp2 = ToD[int(floor(hour)) + 1];

	sunlight_color = mix(vec3(temp.yzw),vec3(temp2.yzw),(hour-float(temp.x))/float(temp2.x-temp.x))/255.0f;

	ivec4 tempa = ToD2[int(floor(hour))];
	ivec4 tempa2 = ToD2[int(floor(hour)) + 1];

	ambient_color = mix(vec3(tempa.yzw),vec3(tempa2.yzw),(hour-float(tempa.x))/float(tempa2.x-tempa.x))/255.0f;

}
