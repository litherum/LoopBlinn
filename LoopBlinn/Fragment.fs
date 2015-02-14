#version 410

in vec3 coordinateV;

out vec4 outColor;

void main() {
    vec3 dcoorddx = dFdx(coordinateV);
    vec3 dcoorddy = dFdy(coordinateV);

    float k = coordinateV.x;
    float l = coordinateV.y;
    float m = coordinateV.z;

    float dkdx = dcoorddx.x;
    float dldx = dcoorddx.y;
    float dmdx = dcoorddx.z;

    float dkdy = dcoorddy.x;
    float dldy = dcoorddy.y;
    float dmdy = dcoorddy.z;

    vec2 grad = vec2(3 * k * k * dkdx - m * dldx - l * dmdx, 3 * k * k * dkdy - m * dldy - l * dmdy);
    float signedDistance = (k * k * k - l * m) / length(grad);
    outColor = vec4(1.0, 0.0, 0.0, smoothstep(0.5, -0.5, signedDistance));
}