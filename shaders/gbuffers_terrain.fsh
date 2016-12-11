#version 120
#extension GL_ARB_shader_texture_lod : enable

#define NORMAL_MAP_MAX_ANGLE 0.5
#define POM
#define POM_MAP_RES 512
#define POM_DEPTH 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
#define OCCLUSION_POINTS 512 //[8 16 32 64 128 256 512 1024]

/* Here, intervalMult might need to be tweaked per texture pack.
   The first two numbers determine how many samples are taken per fragment.  They should always be the equal to eachother.
   The third number divided by one of the first two numbers is inversely proportional to the range of the height-map. */
const vec3 intervalMult = vec3(1.0, 1.0, 1.0/(POM_DEPTH))/POM_MAP_RES;

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
varying float islava;
varying float mat;
varying float distance;
varying float dist;
varying vec3 wpos;
varying vec4 texcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;
varying mat3 tbnMatrix;
varying vec3 fragposition;
varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec4 vertexPos;
varying vec3 viewDir;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform sampler2D depthtex1;
uniform float wetness;
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq);
float pixeldepth = texture2D(depthtex1,texcoord.xy).x;

vec4 readTexture(in vec2 coord)
{
	return texture2DGradARB(texture,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

float terrainH(vec2 posxz) {


	vec2 coord = (posxz);

	float noise = texture2DGradARB(noisetex,fract(coord.xy/50.0), dcdx, dcdy).x / 2;

return noise;
}

vec4 readNormal(in vec2 coord)
{
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

vec4 getFpos(float pixeldepth){

		vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
			fragposition /= fragposition.w;

		return fragposition;
}

vec2 ParallaxMapping(vec2 texCoords, vec3 viewDir)
{
    const float minLayers = 10;
	const float maxLayers = 15;
	float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0,0,1), viewDir)));

	float layerHeight = 1.0 / numLayers;
	float curLayerHeight = 0;
	vec2 dtex = 1 * viewDir.xy / viewDir.z / numLayers;

	vec2 currTexCoords = texCoords;

	float heightMap = readNormal(currTexCoords).a;

	while(heightMap > curLayerHeight){
		curLayerHeight += layerHeight;
		currTexCoords -= dtex;
		heightMap = readNormal(currTexCoords).a;
	}

	return currTexCoords;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	vec4 modelView = (gl_ModelViewMatrix * vertexPos);
	vec3 viewVector = normalize(tbnMatrix * modelView.xyz);
	vec2 adjustedTexCoord = texcoord.st;
	#ifdef POM
	if (dist < MAX_OCCLUSION_DISTANCE) {
		if ( readNormal(vtexcoord.st).a < 0.99 && readNormal(vtexcoord.st).a > 0.01)
		{
			vec3 interval = viewVector.xyz * intervalMult;
			vec3 coord = vec3(vtexcoord.st, 1.0);
			for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (readNormal(coord.st).a < coord.p); ++loopCount)
			{
				coord = coord+interval;
			}
			if (coord.t < mincoord) {
				if (readTexture(vec2(coord.s,mincoord)).a == 0.0)
				{
					coord.t = mincoord;
					discard;
				}
			}
			adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st , adjustedTexCoord , max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));
		}
	}
	#endif


		vec3 specularity = texture2D(specular, adjustedTexCoord).rgb;
	float atten = 1.0-(specularity.g);

	vec4 frag2 = vec4(normal, 1.0f);

		vec3 bump2 = vec3((terrainH(wpos.xz + wpos.y)) * 0.2 * (rainStrength + float(mat > 0.22 && mat < 0.24) * 2.0));

		vec3 bump = texture2D(normals, adjustedTexCoord).rgb*2.0-1.0 * (1+ bump2);

		float bumpmult = NORMAL_MAP_MAX_ANGLE*(1.0-wetness*lmcoord.t*0.25)*atten;

		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
								  tangent.y, binormal.y, normal.y,
						     	  tangent.z, binormal.z, normal.z);

			frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	vec4 c = mix(color,vec4(1.0),float(mat > 0.58 && mat < 0.62));		//fix weird lightmap bug on emissive blocks
	vec4 colorAlbedo = texture2D(texture, adjustedTexCoord);


		if(islava > 0.9){
		float albedo = dot(colorAlbedo.rgb, vec3(1.0))/1.3;
			colorAlbedo.rgb = albedo*vec3(1, 0.87647058823, 0.66078431372);
		}

/* DRAWBUFFERS:0246 */

	gl_FragData[0] = colorAlbedo * c;
	gl_FragData[1] = frag2;
	gl_FragData[2] = vec4((lmcoord.t), mat, lmcoord.s, 1.0);
	gl_FragData[3] = vec4(specularity,1.0);
}
