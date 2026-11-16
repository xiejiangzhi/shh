#define RGBA8 0
#define RGBA16F 1
#define RGBA32F 2
#define RG11B10F 3

layout(constant_id = 0) const uint FORMAT = RGBA32F;

layout(rgba8) uniform readonly image2D TextureRGBA8;
layout(rgba16f) uniform readonly image2D TextureRGBA16F;
layout(rgba32f) uniform readonly image2D TextureRGBA32F;
layout(r11f_g11f_b10f) uniform readonly image2D TextureRG11B10F;

// layout(std140) buffer writeonly Basis { vec3 basis[9]; };
layout(std140) buffer writeonly ResultBlock { vec3 OutResult[]; };

layout(local_size_x = 16, local_size_y = 16) in;

shared vec3 result[256][9];

void lovrmain() {
  ivec2 size;
  if (FORMAT == RGBA8) size = imageSize(TextureRGBA8);
  if (FORMAT == RGBA16F) size = imageSize(TextureRGBA16F);
  if (FORMAT == RGBA32F) size = imageSize(TextureRGBA32F);
  if (FORMAT == RG11B10F) size = imageSize(TextureRG11B10F);
  float width = size.x;
  float height = size.y;
  ivec2 origin = ivec2(GlobalThreadID.xy) * ivec2(4u);

  uint lid = LocalThreadIndex;

  for (int i = 0; i < 9; i++) {
    result[lid][i] = vec3(0.);
  }

  for (uint y = 0; y < 4; y++) {
    if (origin.y + y >= size.y) break;
    float phi = (origin.y + y) / height * PI;
    float sinphi = sin(phi);
    float cosphi = cos(phi);

    for (uint x = 0; x < 4; x++) {
      if (origin.x + x >= size.x) break;
      float theta = (.75 - (origin.x + x) / width) * 2. * PI;
      float solidAngle = (2. * PI / width) * (PI / height) * abs(sinphi);

      vec3 color;
      ivec2 texel = origin + ivec2(x, y);
      if (FORMAT == RGBA8) color = gammaToLinear(imageLoad(TextureRGBA8, texel).rgb);
      if (FORMAT == RGBA16F) color = imageLoad(TextureRGBA16F, texel).rgb;
      if (FORMAT == RGBA32F) color = imageLoad(TextureRGBA32F, texel).rgb;
      if (FORMAT == RG11B10F) color = imageLoad(TextureRG11B10F, texel).rgb;
      color *= solidAngle;

      vec3 dir = normalize(vec3(cos(theta) * sinphi, cosphi, -sin(theta) * sinphi));
      result[lid][0] += color * .28209479177388;
      result[lid][1] += color * .48860251190292 * dir.y;
      result[lid][2] += color * .48860251190292 * dir.z;
      result[lid][3] += color * .48860251190292 * dir.x;
      result[lid][4] += color * 1.0925484305921 * dir.x * dir.y;
      result[lid][5] += color * 1.0925484305921 * dir.y * dir.z;
      result[lid][6] += color * .31539156525252 * (3. * dir.z * dir.z - 1.);
      result[lid][7] += color * 1.0925484305921 * dir.x * dir.z;
      result[lid][8] += color * .54627421529604 * (dir.x * dir.x - dir.y * dir.y);
    }
  }

  barrier();
  if (lid < 64) {
    for (uint i = 0; i < 9; i++) {
      result[lid][i] += result[lid + 64][i] + result[lid + 128][i] + result[lid + 192][i];
    }
  }

  barrier();
  if (lid == 0u) {
    for (uint t = 1; t < 64; t++) {
      for (uint i = 0; i < 9; i++) {
        result[0][i] += result[t][i];
      }
    }

    uint gid = WorkgroupID.x + WorkgroupID.y * WorkgroupCount.x;
    uint gidx = gid * 9u;
    for (uint i = 0; i < 9; i++) {
      OutResult[gidx + i] = result[0][i];
    }
  }
}
