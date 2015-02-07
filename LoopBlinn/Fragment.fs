#version 410

in vec3 coordinateV;
flat in uint orientationV;

out vec4 outColor;

void main() {
    //if ((coordinateV.x * coordinateV.x - coordinateV.y < 0) ^^ bool(orientationV))
    float k = coordinateV.x;
    float l = coordinateV.y;
    float m = coordinateV.z;
    if ((k * k * k - l * m < 0) ^^ bool(orientationV))
        outColor = vec4(1.0, 0.0, 0.0, 1.0);
    else
        outColor = vec4(0.0, 1.0, 0.0, 1.0);
}