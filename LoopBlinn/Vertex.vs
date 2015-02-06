#version 410

in vec2 position;
in vec2 coordinate;

out vec2 coordinateV;

uniform vec2 size;

void main() {
    gl_Position = vec4(position / size * 2.0 - 1.0, 0.0, 1.0);
    coordinateV = coordinate;
}