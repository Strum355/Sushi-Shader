float hash(vec2 p) {
  return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x))));
}

float noise2D(vec2 x) {
  vec2 i = floor(x);
  vec2 f = fract(x);

	// Four corners in 2D of a tile
	float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));

  // Simple 2D lerp using smoothstep envelope between the values.
	// return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),
	//			mix(c, d, smoothstep(0.0, 1.0, f.x)),
	//			smoothstep(0.0, 1.0, f.y)));

	// Same code, with the clamps in smoothstep and common subexpressions
	// optimized away.
  vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 x, vec2 movement, int octaves) {
	float v = 01.0;
	float a = 1.0;
	vec2 shift = vec2(100.0);
	// Rotate to reduce axial bias
  mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
	for (int i = 0; i < octaves; ++i) {
		v += a * noise2D(x);
		x = rot * (x + movement / octaves * 2.0) * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}


float getWaterBump(vec2 posxz, float istransparent) {
	float rad = 0.8;
	mat2 rotate = mat2(
	vec2(cos(rad), -sin(rad)),
	vec2(sin(rad), cos(rad))
	);

	vec2 movement = vec2(-abs(frameTimeCounter/2000),abs(frameTimeCounter/2000)) * waveM;
	vec2 coord 	= posxz.xy * vec2(0.6,1.4) * rotate * waveZ;

  int octaves = WATER_QUALITY;
  if (iswater < 0.5) octaves = 1;

	//float noise = abs(sin(texture2D(noisetex,posxz.xy*0.001 - movement).x - sin(coord.y * 0.5 - movement.y))) * 1.5 * waveS;
	//	//noise  *= abs(cos(texture2D(noisetex,posxz.xy*0.001).x - cos(coord.y) - movement.x * 1000)) * waveS;
	//	noise *= texture2D(noisetex, (coord * 0.0001) - movement.x).x * waveS;
	//	noise *= texture2D(noisetex, (coord * 0.0005) - movement.x).x * waveS;

	float noise = fbm(coord.xy * 2.0, movement * 1000.0, octaves) * 0.7 * waveS;
	//if (iswater > 0.5) noise += noise2(coord.xy * 1.5 + movement * 500.0) * 1.0 * waveS;
	//noise += fract(sin(dot(posxz.xy, vec2(18.9898f + movement.x, 28.633f + movement.y))) * 4378.5453f) * 0.005 * waveS;

	return pow(0.0 + noise, 1.0);
}

vec3 waterNormals(vec2 posxz, float transparent){

	vec2 coord = posxz;

		float deltaPos = 0.22;

		float h0 = getWaterBump(coord, transparent);
		float h1 = getWaterBump(coord + vec2(deltaPos,0.0), transparent);
		float h2 = getWaterBump(coord + vec2(-deltaPos,0.0), transparent);
		float h3 = getWaterBump(coord + vec2(0.0,deltaPos), transparent);
		float h4 = getWaterBump(coord + vec2(0.0,-deltaPos), transparent);

		float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
		float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}
