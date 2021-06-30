#version 460
#extension GL_ARB_separate_shader_objects:enable
#extension GL_EXT_nonuniform_qualifier:enable

layout (local_size_x = 24) in;
layout (local_size_y = 24) in;

struct Vertex{
  vec3 position;
  float t1;
  vec3 normal;
  float t2;
};

layout(push_constant) uniform PushConstants{
  vec3 cameraPosition;
  vec3 cameraForwardDirection;
  vec3 cameraRightDirection;
  uint unusedPlaceholder; // only used because for last value, packing is different? uint will be put directly after vec3 not like other vec3 which are stored like vec4
  uint triangleCount;
};
layout(set = 0, binding = 0) uniform writeonly image2D frameImage;
layout(set = 1, binding = 0) buffer VertexBuffer{
  Vertex vertices[];
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

float getAreaOfTriangle(vec3 vertex1Position, vec3 vertex2Position, vec3 vertex3Position) {
  vec3 edge1 = vertex2Position - vertex1Position;
  vec3 edge2 = vertex3Position - vertex1Position; 
  return length(cross(edge1, edge2));
}

vec3 getBarycentricCoordinates(vec3 point, vec3 vertex1Position, vec3 vertex2Position, vec3 vertex3Position) {
  float primaryArea = getAreaOfTriangle(vertex1Position, vertex2Position, vertex3Position);
  float secondaryArea1 = getAreaOfTriangle(vertex1Position, point, vertex2Position);
  float secondaryArea2 = getAreaOfTriangle(vertex2Position, point, vertex3Position);
  float secondaryArea3 = getAreaOfTriangle(vertex3Position, point, vertex1Position);
  float u = secondaryArea1 / primaryArea;
  float v = secondaryArea2 / primaryArea;
  float w = secondaryArea3 / primaryArea;
  return vec3(u, v, w);
}

vec3 getClosestHit(vec3 rayOrigin, vec3 rayDirection) {
  vec3 normalizedRayDirection = normalize(rayDirection);

  bool firstHit = true;
  float closestIntersectionScale = 0;
  vec3 closestIntersection = vec3(0, 0, 0); // this value signifies no intersection
  for (int faceIndex = 0; faceIndex < triangleCount; faceIndex++) {
    int baseVertexIndex = faceIndex * 3;

    Vertex vertex1 = vertices[baseVertexIndex];
    Vertex vertex2 = vertices[baseVertexIndex + 1];
    Vertex vertex3 = vertices[baseVertexIndex + 2];

    vec3 edge1 = vertex2.position - vertex1.position;
    vec3 edge2 = vertex3.position - vertex2.position;
    vec3 edge3 = vertex1.position - vertex3.position;

    vec3 faceOrigin = vertex1.position;
    vec3 computedFaceNormal = normalize(cross(edge1, edge2));

    float faceNormalRayDot = dot(computedFaceNormal, normalizedRayDirection);
    if (faceNormalRayDot == 0) {
      continue;
    }

    float intersectionScale = (dot(computedFaceNormal, faceOrigin) - dot(computedFaceNormal, rayOrigin)) / dot(computedFaceNormal, normalizedRayDirection);

    if (intersectionScale < 0.001) {
      continue;
    }

    if (intersectionScale < closestIntersectionScale || firstHit) {
      vec3 intersection = rayOrigin + normalizedRayDirection * intersectionScale;

      vec3 barycentricIntersection = getBarycentricCoordinates(intersection, vertex1.position, vertex2.position, vertex3.position);

      float barycentricSum = dot(barycentricIntersection, vec3(1, 1, 1));
      if (abs(barycentricSum - 1) <= 0.01) {
        closestIntersectionScale = intersectionScale;
        closestIntersection = vec3(0, float(faceIndex), 1);
        firstHit = false;
      }
    }
  }

  return closestIntersection; // signifies no intersection
}

void main() {
  uvec2 frameImageSize = imageSize(frameImage);
  uint xRangeStep = frameImageSize.x / gl_WorkGroupSize.x;
  uint yRangeStep = frameImageSize.y / gl_WorkGroupSize.y;
  uint startX = xRangeStep * gl_LocalInvocationID.x;
  uint endX = min(frameImageSize.x, startX + xRangeStep);
  uint startY = yRangeStep * gl_LocalInvocationID.y;
  uint endY = min(frameImageSize.y, startY + yRangeStep);

  vec3 normalizedCameraForwardDirection = normalize(cameraForwardDirection);
  vec3 surfaceOrigin = cameraPosition + normalizedCameraForwardDirection * 0.1;
  vec3 surfaceRight = normalize(cameraRightDirection);
  vec3 surfaceUp = normalize(cross(surfaceRight, normalizedCameraForwardDirection));
  vec2 surfaceSize = vec2(1, float(frameImageSize.y) / float(frameImageSize.x));

  for (uint x = startX; x < endX; x += 1) {
    for (uint y = startY; y < endY; y += 1) {
      imageStore(frameImage, ivec2(x, y), vec4(0.2, 0.4, 1, 1));

      vec2 relativePositionOnSurface = vec2(float(x) / float(frameImageSize.x), float(y) / float(frameImageSize.y));
      vec2 positionOnSurface = relativePositionOnSurface * surfaceSize;
      vec2 centeredPositionOnSurface = positionOnSurface - surfaceSize / 2;
      vec3 lookAtPoint = surfaceOrigin + centeredPositionOnSurface.x * surfaceRight + centeredPositionOnSurface.y * surfaceUp;

      vec3 rayDirection = lookAtPoint - cameraPosition;

      vec3 closestHitPoint = getClosestHit(cameraPosition, rayDirection);

      imageStore(frameImage, ivec2(x, y), vec4(closestHitPoint, 1));
    }
  }
}