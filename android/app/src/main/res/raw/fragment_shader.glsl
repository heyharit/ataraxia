precision highp float;

varying vec2 v_TexCoord;

uniform sampler2D u_ColorTexture;
uniform sampler2D u_DepthTexture;
uniform vec2 u_Tilt;

void main() {
    // 1. Read the depth map (0.0 is Black/Sky, 1.0 is White/Snoopy)
    float depth = texture2D(u_DepthTexture, v_TexCoord).r;

    // 2. THE BALANCED FOCAL POINT
    // By subtracting 0.5, the mid-ground (gray) stays perfectly still.
    // The background (-0.5) moves one way, and the foreground (+0.5) moves the opposite way.
    float z = depth - 0.5; 

    // 3. THE SAFE DISPLACEMENT ZONE
    // 0.035 is the magic number. It provides deep, highly noticeable 3D volume 
    // without crossing the threshold that causes edge tearing / melting.
    vec2 parallaxCoord = v_TexCoord - (u_Tilt * z * 0.035);

    // 4. Extract the color
    vec4 baseColor = texture2D(u_ColorTexture, parallaxCoord);

    // 5. Softer, Premium Specular Shine
    float light = max(0.0, 1.0 - distance(parallaxCoord, vec2(0.5) - u_Tilt));
    vec3 shine = vec3(0.1, 0.2, 0.3) * light * depth * length(u_Tilt) * 1.5;

    gl_FragColor = vec4(baseColor.rgb + shine, baseColor.a);
}