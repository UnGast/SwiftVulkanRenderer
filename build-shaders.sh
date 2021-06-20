export DIR=Sources/SwiftVulkanRenderer/Resources
glslc --target-spv=spv1.3 -fshader-stage=vert ${DIR}/vertex.glsl -o ${DIR}/vertex.spv
glslc --target-spv=spv1.3 -fshader-stage=frag ${DIR}/fragment.glsl -o ${DIR}/fragment.spv