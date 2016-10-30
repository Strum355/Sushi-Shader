#version 120

/* DRAWBUFFERS:0 */

varying vec4 color;

uniform int worldTime;

	float timefract = worldTime;

	float TimeSunrise  = ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f));
	float TimeNoon     = ((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f);
	float TimeSunset   = ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f);
	float TimeMidnight = ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f);

	float SkyExpNoon = 0.3 * TimeNoon;
	float SkyExpSunrise = 0.3 * TimeSunrise;
	float SkyExpSunset = 0.3 * TimeSunset;
	float SkyExpMidnight = 0.0 * TimeMidnight;

	float SkyExp = (SkyExpNoon + SkyExpSunrise + SkyExpSunset + SkyExpMidnight);

void main() {

	gl_FragData[0] = vec4(vec3(1,1,1.25)*SkyExp,color.a * 1.0);
}
