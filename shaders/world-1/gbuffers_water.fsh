#version 120

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES


	//#define USE_WATER_TEXTURE
	vec4 watercolor = vec4(0.0,0.186,0.275,.2); 	//water color and opacity (r,g,b,opacity)

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
varying float isIce;
varying float viewdistance;
varying vec4 verts;

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform float frameTimeCounter;


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
	int resolution = 1024;

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


float waterH(vec2 posxz, float speed, float size, float iswater) {

	vec2 movement = vec2(abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement2 = vec2(-abs(frameTimeCounter/1000.-0.5),abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement3 = vec2(-abs(frameTimeCounter/1000.-0.5))*speed;
	vec2 movement4 = vec2(abs(frameTimeCounter/1000.-0.5),-abs(frameTimeCounter/1000.-0.5))*speed;

	vec2 coord = (posxz/600)+(movement/5);
	vec2 coord1 = (posxz/599.9)+(movement2/5);
	vec2 coord2 = (posxz/599.8)+(movement3/5);
	vec2 coord3 = (posxz/599.7)+(movement4);
	vec2 coord4 = (posxz/1600)+(movement/1.5);
	vec2 coord5 = (posxz/1599)+(movement2/1.5);
	vec2 coord6 = (posxz/1598)+(movement3/1.5);
	vec2 coord7 = (posxz/1597)+(movement4/1.5);
	vec2 coord8 = (posxz/600);



	float noise = BicubicTexture(noisetex, vec2(coord.x, -coord.y*5)).x/2;
	noise += BicubicTexture(noisetex, vec2(-coord2.x, coord2.y)).x/2;
	noise += BicubicTexture(noisetex, vec2(coord3.x, -coord3.y*3)).x/2;
	noise += BicubicTexture(noisetex, vec2(-coord6.x*2, coord4.y)).x/2;
	noise += BicubicTexture(noisetex, vec2(coord7.x, -coord5.y)).x/2;

	return noise;
}

vec3 getWaveHeight(vec2 posxz, float iswater, float istransparent){

	vec2 coord = posxz/1.5;

		float deltaPos = 0.42;

		float waveY = mix(1.0,6.0,isIce);
		float speed = mix(0.0,1.0,iswater);

		float h0 = waterH(coord, speed, waveY, iswater);
		float h1 = waterH(coord + vec2(deltaPos,0.0), speed, waveY, iswater);
		float h2 = waterH(coord + vec2(-deltaPos,0.0), speed, waveY, iswater);
		float h3 = waterH(coord + vec2(0.0,deltaPos), speed, waveY, iswater);
		float h4 = waterH(coord + vec2(0.0,-deltaPos), speed, waveY, iswater);

		float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
		float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}




//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	vec4 tex;

	if (iswater < 0.9)
		tex = normalize(texture2D(texture, vec2(texcoord.st))*color);
	else
	tex = vec4((watercolor).rgb,watercolor.a);

	#ifdef USE_WATER_TEXTURE
	tex = texture2D(texture, texcoord.xy)*color;
	#endif

	float istransparent = float(mat > 0.4 && mat < 0.42);

	vec3 posxz = wpos.xyz;

	vec4 frag2;
		frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);
	vec4 frag3;
		frag3 = vec4((normal) * 0.5f + 0.5f, 1.0f);


	float bumpmult = 0.1;

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						tangent.y, binormal.y, normal.y,
						tangent.z, binormal.z, normal.z);

	vec3 bump;
	bump = getWaveHeight(posxz.xz - posxz.y, iswater, istransparent);

	bump = bump * vec3(bumpmult, bumpmult, 0.0) + vec3(0.0f, 0.0f, 1.0f);

	frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	frag3 = vec4(normalize(waves1(0.05) * tbnMatrix) * 0.5 + 0.5, 1.0);


/* DRAWBUFFERS:543 */

	gl_FragData[0] = tex;
	gl_FragData[1] = vec4(lmcoord.t, mat, lmcoord.s, 1.0);
	gl_FragData[2] = vec4(frag2);
}
