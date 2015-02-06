#version 410

in vec2 coordinateV;

out vec4 outColor;

void main() {
    if (coordinateV.x * coordinateV.x - coordinateV.y < 0)
        outColor = vec4(1.0, 0.0, 0.0, 1.0);
    else
        outColor = vec4(0.0, 0.0, 0.0, 1.0);
}