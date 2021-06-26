#version 460
#extension GL_ARB_separate_shader_objects:enable
#extension GL_EXT_nonuniform_qualifier:enable

struct Material {
  uint textureIndex;
};

struct ObjectInfo {
    mat4 transformationMatrix;
    uint materialIndex;
};

layout(location=0) in vec3 fragNormal;
layout(location=1) in flat uint instanceIndex;

/*
layout(set = 1, binding = 0) uniform sampler2D texSampler;

layout(location=0) in vec4 fragColor;
layout(location=2) in vec2 fragTexCoord;
*/
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

layout(location=0) out vec4 outColor;

void main() {
  vec4 textureColor = vec4(texture(sampler2D(textures[nonuniformEXT(objectInfos[instanceIndex].materialIndex)], texSampler), vec2(0.5, 0.5)).xyz, 1);
  //vec4 tmpOutColor = texture(texSampler, fragTexCoord) + fragColor;
  /*if (tmpOutColor[3] == 0) {
    discard;
  }*/

  float directionalLightFactor = max(dot(fragNormal, -directionalLightDirection), 0);
  vec3 directionalLightComponent = directionalLightColor * directionalLightIntensity * directionalLightFactor;

  vec3 ambientLightComponent = ambientLightIntensity * ambientLightColor;

  outColor = textureColor * vec4((ambientLightComponent + directionalLightComponent), 1);
}