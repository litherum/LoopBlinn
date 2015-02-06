#version 410

in vec2 position;
in vec2 coordinate;
in float orientation;

out vec2 coordinateV;
flat out uint orientationV;

uniform vec2 size;

void main() {
    gl_Position = vec4(position / size * 2.0 - 1.0, 0.0, 1.0);
    coordinateV = coordinate;
    orientationV = uint(orientation);
}