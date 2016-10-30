#version 120

/* DRAWBUFFERS:0 */

varying vec2 texcoord;
varying vec4 color;

uniform sampler2D texture;

void main(){

  vec4 getTex = texture2D(texture, texcoord);

  gl_FragData[0] = getTex;


}
