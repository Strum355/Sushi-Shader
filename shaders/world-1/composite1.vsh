#version 120

varying vec4 texcoord;
varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 lightVector;
varying vec3 ambient_color;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;
varying vec3 cloudColor;

varying float sunVisibility;
varying float moonVisibility;

uniform int worldTime;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

//raining
float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;

////////////////////sunlight color////////////////////
////////////////////sunlight color////////////////////
////////////////////sunlight color////////////////////
const ivec4 ToD[25] = ivec4[25](ivec4(0,160,90,44), //hour,r,g,b
								ivec4(1,160,90,44),
								ivec4(2,160,90,44),
								ivec4(3,160,90,44),
								ivec4(4,160,90,44),
								ivec4(5,160,90,44),
								ivec4(6,160,117,85),
								ivec4(7,190,140,120),
								ivec4(8,190,150,150),
								ivec4(9,190,150,150),
								ivec4(10,190,150,150),
								ivec4(11,190,150,150),
								ivec4(12,190,150,150),
								ivec4(13,190,150,150),
								ivec4(14,190,150,150),
								ivec4(15,190,150,150),
								ivec4(16,190,150,150),
								ivec4(17,190,140,120),
								ivec4(18,160,117,85),
								ivec4(19,160,90,44),
								ivec4(20,160,90,44),
								ivec4(21,160,90,44),
								ivec4(22,160,90,44),
								ivec4(23,160,90,44),
								ivec4(24,160,90,44));



	////////////////////ambient color////////////////////
	////////////////////ambient color////////////////////
	////////////////////ambient color////////////////////
	const ivec4 ToD2[25] = ivec4[25](ivec4(0,75,90,100), //hour,r,g,b
							ivec4(1,75,90,100),
							ivec4(2,75,90,100),
							ivec4(3,75,90,100),
							ivec4(4,75,90,100),
							ivec4(5,37.5,45,50),
							ivec4(6,100,110,180),
							ivec4(7,100,110,180),
							ivec4(8,100,120,180),
							ivec4(9,100,130,160),
							ivec4(10,100,130,160),
							ivec4(11,100,130,160),
							ivec4(12,100,130,160),
							ivec4(13,100,130,160),
							ivec4(14,100,130,160),
							ivec4(15,100,130,160),
							ivec4(16,100,120,180),
							ivec4(17,100,110,180),
							ivec4(18,100,110,180),
							ivec4(19,37.5,45,50),
							ivec4(20,75,90,100),
							ivec4(21,75,90,100),
							ivec4(22,75,90,100),
							ivec4(23,75,90,100),
							ivec4(24,75,90,100));

/*--------------------------------*/


//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {

		if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	}

	else {
		lightVector = normalize(moonPosition);
	}

	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);

	float SdotU = dot(sunVec,upVec);
	float MdotU = dot(moonVec,upVec);
	sunVisibility = pow(clamp(SdotU+0.1,0.0,0.1)/0.1,2.0);
	moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);

	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

	//sunlight color
	float hour = worldTime/1000.0+6.0;
	if (hour > 24.0) hour = hour - 24.0;


	ivec4 temp = ToD[int(floor(hour))];
	ivec4 temp2 = ToD[int(floor(hour)) + 1];

	sunlight = mix(vec3(temp.yzw),vec3(temp2.yzw),(hour-float(temp.x))/float(temp2.x-temp.x))/255.0f;

	sunlight.b *= 0.95;

	moonlight =  vec3(0.7,0.7,1.0)/2.0 * 0.012;

	ivec4 tempa = ToD2[int(floor(hour))];
	ivec4 tempa2 = ToD2[int(floor(hour)) + 1];

	ambient_color = mix(vec3(tempa.yzw),vec3(tempa2.yzw),(hour-float(tempa.x))/float(tempa2.x-tempa.x))/255.0f;

	vec3 sky_color = vec3(0.1, 0.35, 1.);

	vec3 ambient_color2 = (sky_color)*2.;
	ambient_color2 = pow(normalize(ambient_color),vec3(1./2.2))*sqrt(dot(ambient_color,ambient_color));

	cloudColor = sunlight*sunVisibility*sqrt(dot(ambient_color2,ambient_color2)) + ambient_color2*(1-moonVisibility*0.8) + 2.0*moonlight*moonVisibility;
}
