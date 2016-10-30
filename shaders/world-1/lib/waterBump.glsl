float waterH(vec2 posxz, float waveM, float waveZ, float istransparent) {

		float rotMult = -0.5;
	mat2 rotation = mat2(
	vec2(cos(rotMult), -sin(rotMult)),
	vec2(sin(rotMult), cos(rotMult))
	);

	posxz = posxz * mix(vec2(0.5,1.5),vec2(1.0), istransparent) * rotation;

	vec2 movement = vec2(abs(frameTimeCounter/2000),abs(frameTimeCounter/2000)) * waveM;

	vec2 coord = (posxz / 600 * waveZ)- movement;
	vec2 coord1 = (posxz / 599 * waveZ)- movement / 2.0;
	vec2 coord2 = (posxz / 598 * waveZ)- movement / 4.0;
	vec2 coord3 = (posxz / 597 * waveZ)- movement / 8.0;

	float noise = texture2D(noisetex,fract(coord.xy)).x;
		  noise += texture2D(noisetex,fract(coord1.xy*2.0)).x/2.0;
		  noise += texture2D(noisetex,fract(coord2.xy*4.0)).x/4.0;

	return pow(noise, 2.0) / 4.0;
}

vec3 getWaveHeight(vec2 posxz, float iswater, float istransparent){

	vec2 coord = posxz;

		float deltaPos = 0.22;

		float waveZ = mix(0.25,2.0,istransparent);
		float waveM = mix(2.0,0.0,istransparent);

		float h0 = waterH(coord, waveM, waveZ, istransparent);
		float h1 = waterH(coord + vec2(deltaPos,0.0), waveM, waveZ, istransparent);
		float h2 = waterH(coord + vec2(-deltaPos,0.0), waveM, waveZ, istransparent);
		float h3 = waterH(coord + vec2(0.0,deltaPos), waveM, waveZ, istransparent);
		float h4 = waterH(coord + vec2(0.0,-deltaPos), waveM, waveZ, istransparent);

		float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
		float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}
