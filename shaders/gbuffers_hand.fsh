#version 120
#extension GL_ARB_shader_texture_lod : enable

#define NORMAL_MAP_MAX_ANGLE 0.5
#define PARALLAX
#define POM_MAP_RES 256.0
#define POM_DEPTH 1.0 //[0.1 0.25 0.5 1.0 1.5 2.0 2.5 3.0] Depth of terrain parallax. Higher values may look bad with some resource packs
#define OCCLUSION_POINTS 128 //[8 16 32 64 128 256 512 1024]

/* Here, intervalMult might need to be tweaked per texture pack.
   The first two numbers determine how many samples are taken per fragment.  They should always be the equal to eachother.
   The third number divided by one of the first two numbers is inversely proportional to the range of the height-map. */
	 const vec3 intervalMult = vec3(1.0, 1.0, 1.0/(POM_DEPTH))/ OCCLUSION_POINTS;

const float MAX_OCCLUSION_DISTANCE = 22.0;
const float MIX_OCCLUSION_DISTANCE = 18.0;
const int   MAX_OCCLUSION_POINTS   = OCCLUSION_POINTS;

const int GL_EXP = 2048;
const int GL_LINEAR = 9729;
const float bump_distance = 32.0;		//bump render distance: tiny = 32, short = 64, normal = 128, far = 256
const float pom_distance = 32.0;		//POM render distance: tiny = 32, short = 64, normal = 128, far = 256
const float fademult = 0.1;

varying vec2 lmcoord;
varying vec4 color;
varying float mat;
varying float dist;
varying vec2 texcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;

varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec3 viewVector;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float wetness;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq);

vec4 readTexture(in vec2 coord)
{
	return texture2DGradARB(texture,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

vec4 readNormal(in vec2 coord)
{
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

vec2 encodeColors(in vec3 color) {

	color = clamp(color, 0.0, 1.0);

	vec3 YCoCg = vec3(0.25 * color.r + 0.5 * color.g + 0.25 * color.b, 0.5 * color.r - 0.5 * color.b + 0.5, -0.25 * color.r + 0.5 * color.g - 0.25 * color.b + 0.5);

	YCoCg.g = (mod(gl_FragCoord.x, 2.0) == mod(gl_FragCoord.y, 2.0))? YCoCg.b:YCoCg.g;

	return YCoCg.rg;
}


void main() {
	vec2 adjustedTexCoord;
	adjustedTexCoord = texcoord.st;

	#ifdef PARALLAX
	if (dist < MAX_OCCLUSION_DISTANCE) {
		if ( viewVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.99 && readNormal(vtexcoord.st).a > 0.01)
	{
		vec3 interval = viewVector.xyz * intervalMult;
		vec3 coord = vec3(vtexcoord.st, 1.0);
		for (int loopCount = 0;
				(loopCount < MAX_OCCLUSION_POINTS) && (readNormal(coord.st).a < coord.p);
				++loopCount) {
			coord = coord+interval;
		}
		adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st , adjustedTexCoord , max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));
	}

	}
	#endif
	vec3 lightVector;

	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	}

	else {
		lightVector = normalize(moonPosition);
	}



		vec3 specularity = texture2DGradARB(specular, adjustedTexCoord, dcdx, dcdy).rgb;
	float atten = 1.0-(specularity.b)*0.0;

	vec3 getNormal = normal;
	vec4 frag2 = vec4(getNormal, 1.0f);

		vec3 bump = texture2DGradARB(normals, adjustedTexCoord, dcdx, dcdy).rgb;

		float bumpmult = NORMAL_MAP_MAX_ANGLE*(1.0-wetness*lmcoord.t*0.8)*atten;

		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, getNormal.x,
								  tangent.y, binormal.y, getNormal.y,
						     	  tangent.z, binormal.z, getNormal.z);

			frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
    vec4 col = texture2D(texture, adjustedTexCoord)*color;
	vec2 outCol = encodeColors(col.rgb);

/* DRAWBUFFERS:0246 */

	gl_FragData[0] = vec4(outCol, 0.0, col.a);
	gl_FragData[1] = frag2;
	gl_FragData[2] = vec4((lmcoord.t), 0.8, lmcoord.s, 1.0);
	gl_FragData[3] = vec4(texture2DGradARB(specular, adjustedTexCoord, dcdx, dcdy).rgb,1.0);
}
