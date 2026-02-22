// GLSL fragment shader for organic card dissolve effect.
// Used as a ShaderMask (BlendMode.dstIn) to fade card edges
// into the page background with noise-modulated transitions.

#include <flutter/runtime_effect.glsl>

// Widget size in pixels
uniform vec2 uSize;

out vec4 fragColor;

// Hash-based pseudo-random
float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise
float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // --- border radius in UV space (12px corners) ---
  float rx = 12.0 / uSize.x;
  float ry = 12.0 / uSize.y;

  // --- corner distance: how far inside the rounded rect we are ---
  // Returns 0 inside, >0 outside the rounded rect
  vec2 q = abs(uv - 0.5) - (0.5 - vec2(rx, ry));
  float cornerDist = length(max(q, 0.0)) / max(rx, ry);

  // --- base dissolve: left = solid, right = transparent ---
  float dissolve = uv.x;

  // --- edge acceleration: top/bottom borders dissolve faster ---
  float dy = abs(uv.y - 0.5) * 2.0;
  dissolve += dy * dy * 0.15;

  // --- subtle noise for organic edge (NOT jagged) ---
  float n = vnoise(uv * 5.0)  * 0.6
          + vnoise(uv * 10.0) * 0.3
          + vnoise(uv * 20.0) * 0.1;
  dissolve += (n - 0.5) * 0.035;

  // --- map to alpha: solid until 0.45, fully gone by 0.75 ---
  float alpha = 1.0 - smoothstep(0.45, 0.75, dissolve);

  // --- kill pixels outside rounded rect ---
  alpha *= 1.0 - smoothstep(0.8, 1.0, cornerDist);

  fragColor = vec4(alpha);
}
