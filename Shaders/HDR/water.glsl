// SPDX-FileCopyrightText: (C) 2024 Stuart Buchanan stuart13@gmail.com
// SPDX-License-Identifier: GPL-2.0-or-later

// Helper functions for WS30 HDR water implementation

#version 330 core

// Hardcoded indexes into the texture atlas
const int ATLAS_INDEX_WATER                 = 0;
const int ATLAS_INDEX_WATER_REFLECTION      = 1;
const int ATLAS_INDEX_WAVES_VERT10_NM       = 2;
const int ATLAS_INDEX_WATER_SINE_NMAP       = 3;
const int ATLAS_INDEX_WATER_REFLECTION_GREY = 4;
const int ATLAS_INDEX_SEA_FOAM              = 5;
const int ATLAS_INDEX_PERLIN_NOISE_NM       = 6;
const int ATLAS_INDEX_OCEAN_DEPTH           = 7;
const int ATLAS_INDEX_GLOBAL_COLORS         = 8;
const int ATLAS_INDEX_PACKICE_OVERLAY       = 9;

// WS30 uniforms
uniform sampler2DArray atlas;
uniform float fg_tileWidth;
uniform float fg_tileHeight;

// Water.eff uniforms
uniform float osg_SimulationTime;
uniform float WindN;
uniform float WindE;
uniform float WaveFreq;
uniform float WaveAmp;
uniform float WaveSharp;
uniform float WaveAngle;
uniform float WaveFactor;

/////// functions /////////

void rotationmatrix(in float angle, out mat4 rotmat)
{
  rotmat = mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
  sin( angle ),  cos( angle ), 0.0, 0.0,
  0.0         ,  0.0         , 1.0, 0.0,
  0.0         ,  0.0         , 0.0, 1.0 );
}

// wave functions ///////////////////////
struct Wave {
  float freq;  // 2*PI / wavelength
  float amp;   // amplitude
  float phase; // speed * 2*PI / wavelength
  vec2 dir;
};

Wave wave0 = Wave(1.0, 1.0, 0.5, vec2(0.97, 0.25));
Wave wave1 = Wave(2.0, 0.5, 1.3, vec2(0.97, -0.25));
Wave wave2 = Wave(1.0, 1.0, 0.6, vec2(0.95, -0.3));
Wave wave3 = Wave(2.0, 0.5, 1.4, vec2(0.99, 0.1));

float evaluateWave(in Wave w, in vec2 pos, in float t) {
  return w.amp * sin( dot(w.dir, pos) * w.freq + t * w.phase);
}

// derivative of wave function
float evaluateWaveDeriv(in Wave w, in vec2 pos, in float t) {
  return w.freq * w.amp * cos( dot(w.dir, pos)*w.freq + t*w.phase);
}

// sharp wave functions
float evaluateWaveSharp(in Wave w, in vec2 pos, in float t, in float k) {
  return w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k);
}

float evaluateWaveDerivSharp(in Wave w, in vec2 pos, in float t, in float k) {
  return k*w.freq*w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k - 1) * cos( dot(w.dir, pos)*w.freq + t*w.phase);
}

void sumWaves(in float angle, in float dangle, in float windScale, in float factor, in vec4 waterTex1,  out float ddx, float ddy) {
  mat4 RotationMatrix;
  float deriv;
  vec4 P = waterTex1 * 1024;

  rotationmatrix(radians(angle + dangle * windScale + 0.6 * sin(P.x * factor)), RotationMatrix);
  P *= RotationMatrix;

  P.y += evaluateWave(wave0, P.xz, osg_SimulationTime);
  deriv = evaluateWaveDeriv(wave0, P.xz, osg_SimulationTime );
  ddx = deriv * wave0.dir.x;
  ddy = deriv * wave0.dir.y;

  P.y += evaluateWaveSharp(wave2, P.xz, osg_SimulationTime, WaveSharp);
  deriv = evaluateWaveDerivSharp(wave2, P.xz, osg_SimulationTime, WaveSharp);
  ddx += deriv * wave2.dir.x;
  ddy += deriv * wave2.dir.y;

}

vec3 generateWaterNormal(in vec2 texCoords)
{
  float tileScale = 1 / (fg_tileHeight + fg_tileWidth) / 2.0;

  vec4 sca = vec4(0.005, 0.005, 0.005, 0.005) * tileScale;
  vec4 sca2 = vec4(0.02, 0.02, 0.02, 0.02) * tileScale;
  vec4 tscale = vec4(0.25, 0.25, 0.25, 0.25) / 10000.0 * tileScale;

  vec3 Normal = vec3 (0.0, 0.0, 1.0);

  const float water_shininess = 240.0;

  float windEffect = sqrt( WindE*WindE + WindN*WindN ) * 0.6; //wind speed in kt
  float windScale =  15.0/(3.0 + windEffect);                 //wave scale
  float windEffect_low = 0.3 + 0.7 * smoothstep(0.0, 5.0, windEffect);    //low windspeed wave filter
  float waveRoughness = 0.01 + smoothstep(0.0, 40.0, windEffect);         //wave roughness filter

  vec4 t1 = vec4(0.0, osg_SimulationTime * 0.005217, 0.0, 0.0);
  vec4 t2 = vec4(0.0, osg_SimulationTime * -0.0012, 0.0, 0.0);

  float Angle;

  float windFactor = sqrt(WindE * WindE + WindN * WindN) * 0.05;
  if (WindN == 0.0 && WindE == 0.0) {
      Angle = 0.0;
  } else {
      Angle = atan(-WindN, WindE) - atan(1.0);
  }

  mat4 RotationMatrix;
  rotationmatrix(Angle, RotationMatrix);
  vec4 waterTex1 = vec4(texCoords.s, texCoords.t, 0.0, 0.0) * RotationMatrix - t1 * windFactor;
  rotationmatrix(Angle, RotationMatrix);
  vec4 waterTex2 = vec4(texCoords.s, texCoords.t, 0.0, 0.0) * RotationMatrix - t2 * windFactor;

  float mixFactor = 0.2 + 0.02 * smoothstep(0.0, 50.0, windEffect);
  mixFactor = clamp(mixFactor, 0.3, 0.8);

  // sine waves
  float ddx, ddx1, ddx2, ddx3, ddy, ddy1, ddy2, ddy3;
  float angle;

  ddx = 0.0, ddy = 0.0;
  ddx1 = 0.0, ddy1 = 0.0;
  ddx2 = 0.0, ddy2 = 0.0;
  ddx3 = 0.0, ddy3 = 0.0;

  angle = 0.0;

  wave0.freq = WaveFreq ;
  wave0.amp = WaveAmp;
  wave0.dir =  vec2 (0.0, 1.0); //vec2(cos(radians(angle)), sin(radians(angle)));

  angle -= 45;
  wave1.freq = WaveFreq * 2.0 ;
  wave1.amp = WaveAmp * 1.25;
  wave1.dir =  vec2(0.70710, -0.7071); //vec2(cos(radians(angle)), sin(radians(angle)));

  angle += 30;
  wave2.freq = WaveFreq * 3.5;
  wave2.amp = WaveAmp * 0.75;
  wave2.dir =  vec2(0.96592, -0.2588);// vec2(cos(radians(angle)), sin(radians(angle)));

  angle -= 50;
  wave3.freq = WaveFreq * 3.0 ;
  wave3.amp = WaveAmp * 0.75;
  wave3.dir =  vec2(0.42261, -0.9063); //vec2(cos(radians(angle)), sin(radians(angle)));

  // sum waves
  sumWaves(WaveAngle, -1.5, windScale, WaveFactor, waterTex1, ddx, ddy);
  sumWaves(WaveAngle, 1.5, windScale, WaveFactor, waterTex1, ddx1, ddy1);

  //reset the waves
  angle = 0.0;
  float waveamp = WaveAmp * 0.75;

  wave0.freq = WaveFreq ;
  wave0.amp = waveamp;
  wave0.dir =  vec2 (0.0, 1.0); //vec2(cos(radians(angle)), sin(radians(angle)));

  angle -= 20;
  wave1.freq = WaveFreq * 2.0 ;
  wave1.amp = waveamp * 1.25;
  wave1.dir =  vec2(0.93969, -0.34202);// vec2(cos(radians(angle)), sin(radians(angle)));

  angle += 35;
  wave2.freq = WaveFreq * 3.5;
  wave2.amp = waveamp * 0.75;
  wave2.dir =  vec2(0.965925, 0.25881);  //vec2(cos(radians(angle)), sin(radians(angle)));

  angle -= 45;
  wave3.freq = WaveFreq * 3.0 ;
  wave3.amp = waveamp * 0.75;
  wave3.dir =  vec2(0.866025, -0.5); //vec2(cos(radians(angle)), sin(radians(angle)));
  // end sine stuff

  vec2 st = vec2(waterTex2 * tscale * windScale);
  vec4 disdis = texture(atlas, vec3(st, ATLAS_INDEX_WATER_SINE_NMAP)) * 2.0 - 1.0;

  //normalmaps
  st = vec2(waterTex1 + disdis * sca2) * windScale;
  vec4 nmap   = texture(atlas, vec3(st, ATLAS_INDEX_WAVES_VERT10_NM)) * 2.0 - 1.0;
  vec4 nmap1  = texture(atlas, vec3(st, ATLAS_INDEX_PERLIN_NOISE_NM)) * 2.0 - 1.0;

  rotationmatrix(radians(3.0 * sin(osg_SimulationTime * 0.0075)), RotationMatrix);
  st = vec2(waterTex2 * RotationMatrix * tscale) * windScale;
  nmap  += texture(atlas, vec3(st, ATLAS_INDEX_WAVES_VERT10_NM)) * 2.0 - 1.0;

  nmap  *= windEffect_low;
  nmap1 *= windEffect_low;

  // mix water and noise, modulated by factor
  vec4 vNorm = normalize(mix(nmap, nmap1, mixFactor) * waveRoughness);
  vNorm.r += ddx + ddx1 + ddx2 + ddx3;

  st = vec2(waterTex1 + disdis * sca2) * windScale;
  vec3 N0 = vec3(texture(atlas, vec3(st, ATLAS_INDEX_WAVES_VERT10_NM))) * 2.0 - 1.0;
  st = vec2(waterTex1 + disdis * sca) * windScale;
  vec3 N1 = vec3(texture(atlas, vec3(st, ATLAS_INDEX_PERLIN_NOISE_NM))) * 2.0 - 1.0;

  st = vec2(waterTex1 * tscale) * windScale;
  N0 += vec3(texture(atlas, vec3(st, ATLAS_INDEX_WAVES_VERT10_NM))) * 2.0 - 1.0;
  N1 += vec3(texture(atlas, vec3(st, ATLAS_INDEX_PERLIN_NOISE_NM))) * 2.0 - 1.0;
    
  rotationmatrix(radians(2.0 * sin(osg_SimulationTime * 0.005)), RotationMatrix);
  st = vec2(waterTex2 * RotationMatrix * (tscale + sca2)) * windScale;
  N0 += vec3(texture(atlas, vec3(st, ATLAS_INDEX_WAVES_VERT10_NM))) * 2.0 - 1.0;
  N1 += vec3(texture(atlas, vec3(st, ATLAS_INDEX_PERLIN_NOISE_NM))) * 2.0 - 1.0;

  rotationmatrix(radians(-4.0 * sin(osg_SimulationTime * 0.003)), RotationMatrix);
  st = vec2(waterTex1 * RotationMatrix + disdis * sca2) * windScale;
  N0 += vec3(texture(atlas, vec3(st, ATLAS_INDEX_WAVES_VERT10_NM))) * 2.0 - 1.0;
  st = vec2(waterTex1 * RotationMatrix + disdis * sca) * windScale;
  N1 += vec3(texture(atlas, vec3(st, ATLAS_INDEX_PERLIN_NOISE_NM))) * 2.0 - 1.0;
    
  N0 *= windEffect_low;
  N1 *= windEffect_low;

  N0.r += (ddx + ddx1 + ddx2 + ddx3);
  N0.g += (ddy + ddy1 + ddy2 + ddy3);

  vec3 N = normalize(mix(Normal + N0, Normal + N1, mixFactor) * waveRoughness);

  // From observation, the normal is generated in the wrong direction, resulting
  // in specular highlights facing away from the Sun.  This  matrix attempts to correct it
  
  mat3 rotMat = mat3(0.0, 0.0, 1.0,
                     0.0, 1.0, 0.0,
                     1.0, 0.0, 0.0);
  N = N * rotMat;
  return N;
}
