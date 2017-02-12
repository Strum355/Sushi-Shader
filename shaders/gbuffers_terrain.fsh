#version 120
#extension GL_ARB_shader_texture_lod : enable

#define NORMAL_MAP_MAX_ANGLE 1.0
#define PARALLAX
#define POM_MAP_RES 256.0
#define POM_DEPTH 1.0 //[0.1 0.25 0.5 0.75 1.0 1.5 2.0] Depth of terrain parallax. Higher values may look bad with some resource packs
#define OCCLUSION_POINTS 128 //[8 16 32 64 128 256 512 1024]


const int		RGBA16 					= 1;
const int		RGB16 					= 1;
const int		RGBA32F 				= 3;
const int		RGB8 						= 1;

const int		gnormalFormat			= RGBA32F;
const int		gcolorFormat			= RGBA32F;
const int		gaux1Format			    = RGBA16;
const int 	compositeFormat			= RGBA16;
const int		gaux2Format			    = RGBA16;
const int		gdepthFormat			    = RGBA16;
const int		gaux3Format			    = RGBA16;
const int		gaux4Format			    = RGB8;

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
varying float islava;
varying vec3 wpos;
varying vec4 vertexPos;
varying vec4 texcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;
varying mat3 tbnMatrix;

varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec3 viewVector;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform float wetness;
uniform float rainStrength;

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq);

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

vec2 encodeColors(in vec3 color) {

	color = clamp(color, 0.0, 1.0);

	vec3 YCoCg = vec3(0.25 * color.r + 0.5 * color.g + 0.25 * color.b, 0.5 * color.r - 0.5 * color.b + 0.5, -0.25 * color.r + 0.5 * color.g - 0.25 * color.b + 0.5);

	YCoCg.g = (mod(gl_FragCoord.x, 2.0) == mod(gl_FragCoord.y, 2.0))? YCoCg.b:YCoCg.g;

	return YCoCg.rg;
}

vec2 encodeNormal (vec3 normal)
{
    vec2 p = normal.xy / (abs (normal.z) + 1.0);
    float d = abs (p.x) + abs (p.y) + 0.00001;
    float r = length (p);
    vec2 q = p * r / d;
    float z_is_negative = max (-sign (normal.z), 0.0);
    vec2 q_sign = sign (q);
    q_sign = sign (q_sign + vec2 (0.5, 0.5));
    q -= z_is_negative * (dot (q, q_sign) - 1.0) * q_sign;
    return q;
}

vec2 encode (vec3 n)
{

    float p = sqrt(n.z*8+8);
    return vec2(n.xy/p + 0.5);
}


void main() {
	vec4 modelView = (gl_ModelViewMatrix * vertexPos);
	vec3 viewVector = normalize(tbnMatrix * modelView.xyz);
	vec2 adjustedTexCoord = texcoord.st;

	#ifdef PARALLAX
	if (dist < MAX_OCCLUSION_DISTANCE) {
		if ( viewVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.99 && readNormal(vtexcoord.st).a > 0.01)
	{
		vec3 interval = viewVector.xyz * intervalMult;
		vec3 coord = vec3(vtexcoord.st, 1.0);
		if(coord .x > 1.0 || coord .y > 1.0 || coord .x < 0.0 || coord .y < 0.0)
				discard;
		for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (readNormal(coord.st).a < coord.p); ++loopCount) {
			coord = coord+interval;
		}
		if (coord.t < mincoord) {
			if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
				coord.t = mincoord;
				discard;
			}
		}
		adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st , adjustedTexCoord , max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));
	}

	}
	#endif


		vec3 specularity = texture2DGradARB(specular, adjustedTexCoord, dcdx, dcdy).rgb;

		vec3 frag2 = normal;

		vec3 bump2 = vec3((terrainH(wpos.xz + wpos.y)) * 0.2 * (rainStrength + float(mat > 0.22 && mat < 0.24) * 2.0));

		vec3 bump = texture2DGradARB(normals, adjustedTexCoord, dcdx, dcdy).rgb*2.0-1.0 * (1+ bump2);
		float bumpmult = NORMAL_MAP_MAX_ANGLE*(1.0-wetness*lmcoord.t*0.25);

		bump = bump * vec3(bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
						      tangent.z, binormal.z, normal.z);

			frag2 = normalize(bump * tbnMatrix) ;
	vec4 c = mix(color,vec4(1.0),float(mat > 0.58 && mat < 0.62));		//fix weird lightmap bug on emissive blocks
	vec4 colorAlbedo = texture2DGradARB(texture, adjustedTexCoord, dcdx, dcdy);

	if(islava > 0.9){
	float albedo = dot(colorAlbedo.rgb, vec3(1.0))/1.3;
		colorAlbedo.rgb = albedo*vec3(1, 0.87647058823, 0.66078431372);
	}

	vec2 outCol = encodeColors(colorAlbedo.rgb*c.rgb);
    vec2 outSpec = encodeColors(specularity);
	vec2 outNorm = encode(frag2.xyz);
/* DRAWBUFFERS:0246 */
	gl_FragData[0] = vec4(outCol, 0.0, colorAlbedo.a);
	gl_FragData[1] = vec4(outNorm, 0.0, 1.0);
	gl_FragData[2] = vec4(lmcoord.t, mat, lmcoord.s, 1.0);
	gl_FragData[3] = vec4(outSpec, 0.0,1.0);
}
