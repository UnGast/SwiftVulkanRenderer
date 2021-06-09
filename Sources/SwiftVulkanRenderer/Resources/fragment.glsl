#version 450
#extension GL_ARB_separate_shader_objects:enable
/*
layout(set = 1, binding = 0) uniform sampler2D texSampler;

layout(location=0) in vec4 fragColor;
layout(location=1) in vec3 fragNormal;
layout(location=2) in vec2 fragTexCoord;*/

layout(location=0) out vec4 outColor;

void main() {
  //vec4 tmpOutColor = texture(texSampler, fragTexCoord) + fragColor;
  /*if (tmpOutColor[3] == 0) {
    discard;
  }*/

  /*float directionalLightFactor = max(dot(fragNormal, normalize(vec3(1, 1, 0))), 0);
  vec3 directionalLightColor = vec3(1, 1, 1);
  float directionalLightIntensity = 1;
  vec3 directionalLightComponent = directionalLightColor * directionalLightIntensity * directionalLightFactor;

  vec3 ambientLightColor = vec3(1, 1, 1);
  float ambientLightIntensity = 0.1;
  vec3 ambientLightComponent = ambientLightIntensity * ambientLightColor;

  tmpOutColor = tmpOutColor * vec4((ambientLightComponent + directionalLightComponent), 1);

  outColor = tmpOutColor;*/

  outColor = vec4(1, 0, 0, 1);
}