#version 120

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

#define PARALLAX_WATER //Gives water waves a 3D look
	#define PARALLAX_WATER_DEPTH 2 //[2 3 4 5] defines how deep parallax water looks
#define WATER_QUALITY 5 //[2 3 4 5] higher numbers gives better looking water

	vec4 watercolor = vec4(0.05, 0.5, 0.9, 0.25); 	//water color and opacity (r,g,b,opacity)

//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 viewVector;
varying vec3 wpos;
varying float mat;
varying float iswater;
varying float viewdistance;
varying vec4 verts;
varying float distance;

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform float frameTimeCounter;

float istransparent = float(mat > 0.4 && mat < 0.42);
float ice = float(mat > 0.09 && mat < 0.11);

float waveZ = mix(mix(3.0,0.25,1-istransparent), 8.0, ice);
float waveM = mix(0.0,2.0,1-istransparent+ice);
float waveS = mix(0.1,1.5,1-istransparent+ice);

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
	vec2 resolution = vec2(256);

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

#include "lib/waterBump.glsl"

vec3 stokes(in float ka, in vec3 k, in vec3 g) {
    // ka = wave steepness, k = displacements, g = gradients / wave number
    float theta = k.x + k.z + k.t;
    float s = ka * (sin(theta) + ka * sin(2.0f * theta));
    return vec3(s * g.x, s * g.z, g.t);  // (-deta/dx, -deta/dz, scale)
}

vec3 waves1(in float bumpmult) {
    float scale = 8.0f / (viewdistance * viewdistance);
    vec3 gg = vec3(scale, 3600.0f, scale);
    vec3 gk = vec3(viewdistance * 6.0f, frameTimeCounter * -6.0f, 0.0f);
    vec3 gwave = stokes(10.0f*bumpmult*10.0, gk, gg);
    return normalize(gwave);
}

float smoothStep(in float edge0, in float edge1, in float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}


vec2 parallaxCoord(vec2 pos, vec3 viewVector, float waterQuality){
	vec2 parallaxCoord = pos;
	vec3 stepSize = vec3(0.5);
	float waveHeight = getWaterBump(pos, max(waterQuality, 2.0));
	float depth = PARALLAX_WATER_DEPTH;
	vec2 pCoord = vec2(0.0);

	vec3 step = viewVector * stepSize;

	for(int i = 0; waveHeight < depth && i < 120; ++i){
		pCoord.xy = mix(pCoord, pCoord + step.xy, clamp((depth - waveHeight) / (stepSize.z * 0.2f / (-viewVector.z + 0.05f)), 0.0f, 1.0f));
		depth += step.z;
		waveHeight = getWaterBump(pos + pCoord, max(waterQuality, 2.0));
	}

	return parallaxCoord = pos + pCoord;
}

vec2 encodeColors(in vec3 color) {

	color = clamp(color, 0.0, 1.0);

	vec3 YCoCg = vec3(0.25 * color.r + 0.5 * color.g + 0.25 * color.b, 0.5 * color.r - 0.5 * color.b + 0.5, -0.25 * color.r + 0.5 * color.g - 0.25 * color.b + 0.5);

	YCoCg.g = (mod(gl_FragCoord.x, 2.0) == mod(gl_FragCoord.y, 2.0))? YCoCg.b:YCoCg.g;

	return YCoCg.rg;
}

vec2 encode(vec3 n){
	float p = sqrt(n.z*8+8);
	return n.xy/p+0.5;
}

void main() {

	vec4 albedo = texture2D(texture, texcoord.st) * color;
		albedo = mix(albedo, watercolor, iswater);

	#ifdef USE_WATER_TEXTURE
	albedo = texture2D(texture, texcoord.xy)*color;
	#endif

	vec3 posxz = wpos.xyz;

	float bumpmult = 0.1;

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
					      tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);

	#ifdef PARALLAX_WATER
		vec4 modelView = normalize(gl_ModelViewMatrix * verts);
		vec3 tangentVector = normalize(tbnMatrix * modelView.xyz);
		if(iswater>0.9) posxz.xz = parallaxCoord(posxz.xz, tangentVector, 2);
	#endif

	vec3 bump = waterNormals(posxz.xz - posxz.y);
		 bump = bump * vec3(bumpmult) + vec3(0.0f, 0.0f, 1.0f-bumpmult);
	//bump.b = 1.0;
	vec4 frag2 = vec4(normalize(bump * tbnMatrix), 1.0);
	//frag3 = vec4(normalize(waves1(0.05) * tbnMatrix) * 0.5 + 0.5, 1.0);

	vec2 outNorm = encode(frag2.xyz);
/* DRAWBUFFERS:543 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(lmcoord.t, mat, lmcoord.s, 1.0);
	gl_FragData[2] = vec4(outNorm, 0.0, 1.0);
}
