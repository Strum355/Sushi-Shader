#version 120

varying vec4 color;

varying vec4 texcoord;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform float frameTimeCounter;
const float PI48 = 150.796447372;
float pi2wt = PI48*(frameTimeCounter/2);


vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {

    float magnitude = sin(dot(vec4(pi2wt*fm, pos.x, pos.z, pos.y),vec4(0.5))) * mm + ma;
	vec3 d012 = sin(pi2wt*vec3(f0,f1,f2)*3.0);
	vec3 ret = sin(pi2wt*vec3(f3,f4,f5) + vec3(d012.x + d012.y,d012.y + d012.z,d012.z + d012.x) - pos) * magnitude;

    return ret;
}

vec3 calcMove(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWave(pos      , 0.00054, 0.0400, 0.00400, 0.00127, 0.0089, 0.00114, 0.0063, 0.00224, 0.0015) * amp1;
	vec3 move2 = calcWave(pos+move1, 0.07, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
    return move1+move2;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
		vec3 worldpos = position.xyz + cameraPosition;
	position.xyz += calcMove(worldpos.xyz, 0.00010,  0.000014, 0.0000018, 0.00022, 0.000026, 0.00030, vec3(0.8,0.2,1.75)*4, vec3(0.8,0.2,1.75)*4);

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	color = gl_Color;


	//gl_Position = ftransform();

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;


}
