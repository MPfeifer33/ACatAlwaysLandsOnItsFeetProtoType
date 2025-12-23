shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float offset_amount : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    vec2 uv = UV;
    
    // Horizontal offset based on intensity
    float offset = glitch_intensity * offset_amount * 0.01;
    
    // Add some variation based on vertical position for that scanline feel
    float line_offset = sin(uv.y * 50.0 + TIME * 10.0) * offset;
    
    // Sample with offset
    vec4 color = texture(TEXTURE, vec2(uv.x + line_offset, uv.y));
    
    // Slight color channel separation for extra glitch
    float r = texture(TEXTURE, vec2(uv.x + line_offset + offset * 0.5, uv.y)).r;
    float g = color.g;
    float b = texture(TEXTURE, vec2(uv.x + line_offset - offset * 0.5, uv.y)).b;
    
    COLOR = vec4(r, g, b, color.a);
}
