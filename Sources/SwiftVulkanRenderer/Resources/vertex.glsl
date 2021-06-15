#version 450
#extension GL_ARB_separate_shader_objects:enable

layout (location=0) in vec3 inPos;

struct ObjectInfo {
    mat4 transformationMatrix;
};

layout(binding = 0) uniform SceneParams {
    mat4 viewMatrix;
    mat4 projectionMatrix;
};
layout(binding = 1) buffer ObjectInfoBuffer{
    ObjectInfo objectInfo[];
};

vec2 positions[3] = vec2[](
    vec2(0.0, -0.5),
    vec2(0.5, 0.5),
    vec2(-0.5, 0.5)
);

vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void main() {
    gl_Position = projectionMatrix * viewMatrix * objectInfo[0].transformationMatrix * vec4(inPos, 1);
}