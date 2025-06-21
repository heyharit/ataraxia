attribute vec4 a_Position;
attribute vec2 a_TexCoord;
uniform vec2 u_UvScale; // The Aspect Ratio Math
varying vec2 v_TexCoord;

void main() {
    gl_Position = a_Position;
    // Mathematically scales the UV to achieve a perfect CenterCrop
    v_TexCoord = (a_TexCoord - 0.5) * u_UvScale + 0.5;
}