layout(local_size_x = 1) in;

layout(std140) buffer ResultBlock { vec3 result[]; };
layout(std140) buffer writeonly Basis { vec3 basis[9]; };
uniform float Scale;

void lovrmain() {
  for (uint i = 0; i < 9; i++) {
    vec3 r = vec3(0);
    for (uint j = 0; j < result.length(); j++) {
      r += result[j * 9 + i];
    }
    basis[i] = r * Scale;
  }
}
