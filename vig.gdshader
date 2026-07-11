shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.8, 0.0, 0.0, 0.6);
uniform float intensity : hint_range(0.0, 2.0) = 0.4;
uniform float smoothness : hint_range(0.0, 2.0) = 0.8;

void fragment() {
    // Get distance from the center of the screen (0.5, 0.5)
    float uv_dist = distance(UV, vec2(0.5));
    
    // Calculate vignette power using smoothstep
    float vignette = smoothstep(intensity, intensity + smoothness, uv_dist);
    
    // Apply the color and mix it using the calculated vignette alpha
    COLOR = vec4(vignette_color.rgb, vignette * vignette_color.a);
}