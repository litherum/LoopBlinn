#version 410

in vec3 coordinateV;

out vec4 outColor;

void main() {
    float k = coordinateV.x;
    float l = coordinateV.y;
    float m = coordinateV.z;
    float f = k * k * k - l * m;
    vec2 grad = vec2(dFdx(f), dFdy(f));
    float signedDistance = f / length(grad);
    outColor = vec4(smoothstep(0.5, -0.5, signedDistance), 0.0, 0.0, 1.0);
}