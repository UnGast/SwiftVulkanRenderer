#version 450
#extension GL_ARB_separate_shader_objects:enable

layout(location=0) in vec3 inPos;
layout(location=1) in vec3 inNormal;

struct ObjectInfo {
    mat4 transformationMatrix;
};

layout(binding = 0) uniform SceneParams {
    mat4 viewMatrix;
    mat4 projectionMatrix;
};
layout(binding = 1) readonly buffer ObjectInfoBuffer{
    ObjectInfo objectInfo[];
};

layout(location=0) out vec3 fragNormal;

void main() {
    gl_Position = projectionMatrix * viewMatrix * objectInfo[gl_InstanceIndex].transformationMatrix * vec4(inPos, 1);
    fragNormal = inNormal;
}