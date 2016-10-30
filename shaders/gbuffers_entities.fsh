#version 120

const int GL_EXP = 2048;
const int GL_LINEAR = 9729;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 normal;

uniform sampler2D texture;
uniform sampler2D specular;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform int worldTime;
uniform int entityHurt;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	vec2 adjustedTexCoord = texcoord.st;
	vec3 lightVector;
	vec4 albedo = texture2D(texture,adjustedTexCoord)*color;
	albedo.rgb = mix(albedo.rgb,vec3(1,0,0),float(entityHurt) * 0.003);
	vec4 frag2 = vec4(normal*0.5+0.5, 1.0f);

	float dirtest = 1.0;

	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	}

	else {
		lightVector = normalize(moonPosition);
	}

	dirtest = 1.0-0.8*step(dot(frag2.xyz*2.0-1.0,lightVector),-0.02);

/* DRAWBUFFERS:0246 */
	gl_FragData[0] = albedo;
	gl_FragData[1] = frag2;
	gl_FragData[2] = vec4(lmcoord.t, dirtest, lmcoord.s, 1.0);
	gl_FragData[3] = vec4(texture2D(specular, adjustedTexCoord).rgb,1.0);
}
