#version 120

varying vec4 texcoord;
varying vec3 sunlight;
varying vec3 lightVector;

uniform int worldTime;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

const ivec4 ToD[25] = ivec4[25](ivec4(0,5.0,7.0,10.0), //hour,r,g,b
								ivec4(1,5.0,7.0,10.0),
								ivec4(2,5.0,7.0,10.0),
								ivec4(3,5.0,7.0,10.0),
								ivec4(4,5.0,7.0,10.0),
								ivec4(5,5.0,7.0,10.0),
								ivec4(6,140,100,70),
								ivec4(7,150,110,90),
								ivec4(8,190,129,102),
								ivec4(9,190,150,150),
								ivec4(10,190,150,150),
								ivec4(11,190,150,150),
								ivec4(12,190,150,150),
								ivec4(13,190,150,150),
								ivec4(14,190,150,150),
								ivec4(15,190,150,150),
								ivec4(16,170,129,102),
								ivec4(17,150,110,90),
								ivec4(18,140,100,70),
								ivec4(19,5.0,7.0,10.0),
								ivec4(20,5.0,7.0,10.0),
								ivec4(21,5.0,7.0,10.0),
								ivec4(22,5.0,7.0,10.0),
								ivec4(23,5.0,7.0,10.0),
								ivec4(24,5.0,7.0,10.0));

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {

	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

	if (worldTime < 12700 || worldTime > 23250) {
	lightVector = normalize(sunPosition);
}

else {
	lightVector = normalize(moonPosition);
}

	//sunlight color
	float hour = worldTime/1000.0+6.0;
	if (hour > 24.0) hour = hour - 24.0;


	ivec4 temp = ToD[int(floor(hour))];
	ivec4 temp2 = ToD[int(floor(hour)) + 1];

	sunlight = mix(vec3(temp.yzw),vec3(temp2.yzw),(hour-float(temp.x))/float(temp2.x-temp.x))/255.0f;
}
