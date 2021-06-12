#version 450
#extension GL_ARB_separate_shader_objects:enable

layout (location=0) in vec3 inPos;

layout(binding = 0) uniform SceneParams {
    mat4 viewMatrix;
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
    gl_Position = viewMatrix * vec4(inPos, 1);
}