#version 460
#extension GL_ARB_separate_shader_objects:enable
#extension GL_EXT_nonuniform_qualifier:enable

layout (local_size_x = 256) in;

layout(set = 0, binding = 0) uniform writeonly image2D frameImage;
layout(set = 1, binding = 0) buffer TestData {
  float cR;
  float cG;
  float cB;
};
/*
struct Material {
  uint textureIndex;
};

struct ObjectInfo {
    mat4 transformationMatrix;
    uint materialIndex;
};

layout(location=0) in vec3 fragNormal;
layout(location=1) in flat uint instanceIndex;

layout(set = 0, binding = 0) uniform SceneParams {
  mat4 viewMatrix;
  mat4 projectionMatrix;
  vec3 ambientLightColor;
  float ambientLightIntensity;
  vec3 directionalLightDirection;
  vec3 directionalLightColor;
  float directionalLightIntensity;
};
layout(binding = 1) readonly buffer ObjectInfoBuffer{
    ObjectInfo objectInfos[];
};
layout(set = 0, binding = 2) uniform texture2D textures[];
layout(set = 0, binding = 3) uniform sampler texSampler;
layout(set = 0, binding = 4) readonly buffer MaterialBuffer{
  Material materials[];
};

layout(location=0) out vec4 outColor;*/

void main() {
  ivec2 frameImageSize = imageSize(frameImage);

  for (int x = 0; x < frameImageSize.x; x += 1) {
    for (int y = 0; y < frameImageSize.y; y += 1) {
      imageStore(frameImage, ivec2(x, y), vec4(cR, cG, cB, 1.0));
    }
  }
}