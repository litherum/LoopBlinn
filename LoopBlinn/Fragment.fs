#version 410

in vec3 coordinateV;

out vec4 outColor;

void main() {
    vec3 dcoorddx = dFdx(coordinateV);
    vec3 dcoorddy = dFdy(coordinateV);

    float k = coordinateV.x;
    float l = coordinateV.y;
    float m = coordinateV.z;

    vec2 grad = transpose(mat2x3(dcoorddx, dcoorddy)) * vec3(3 * k * k, -m, -l);
    float signedDistance = (k * k * k - l * m) / length(grad);
    outColor = vec4(1.0, 0.0, 0.0, smoothstep(0.5, -0.5, signedDistance));
}
