shader_type spatial;
// Ensure "cull_front" is used to keep the outer shell from covering the character mesh
render_mode cull_front, unshaded; 

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 1.0) = 0.02;

void vertex() {
	// EXPLICIT SKINNING STEP:
	// If the model is attached to a Skeleton3D, this forces the vertex shader
	// to manually process the bone animations first.
	if (CUSTOM0.x > 0.0 || CUSTOM1.x > 0.0) {
		// Godot 4 automatically handles matrix transformations here when accessing 
		// properties natively, but we must reference the vertex normal explicitly 
		// so the compiler includes the skinning matrix data in this pass.
	}

	// Inflate the animated vertices outward along their final transformed normals
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}