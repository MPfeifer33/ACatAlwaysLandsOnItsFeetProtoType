shader_type canvas_item;
// v2 - wave removed

// ===== COLORS =====
uniform vec4 color_top : source_color = vec4(0.1, 0.05, 0.2, 1.0);
uniform vec4 color_middle : source_color = vec4(0.2, 0.1, 0.3, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.05, 0.15, 0.2, 1.0);

// ===== BASIC EFFECTS =====
uniform bool enable_shimmer = false;
uniform float shimmer_intensity : hint_range(0.0, 0.5) = 0.05;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform bool enable_noise = true;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.02;

// ===== STARS =====
uniform bool enable_stars = false;
uniform float star_density : hint_range(0.0, 0.01) = 0.003;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float star_twinkle_speed : hint_range(0.0, 5.0) = 2.0;
uniform bool star_colored = false;

// ===== DEPTH LAYERS (fake 3D) =====
uniform bool enable_depth_layers = false;
uniform int depth_layer_count : hint_range(1, 5) = 3;
uniform float depth_intensity : hint_range(0.0, 0.5) = 0.15;
uniform float depth_scroll_speed : hint_range(0.0, 1.0) = 0.1;
uniform vec4 depth_color : source_color = vec4(0.0, 0.0, 0.0, 0.3);

// ===== FLOATING PARTICLES =====
uniform bool enable_particles = false;
uniform float particle_density : hint_range(0.0, 0.02) = 0.005;
uniform float particle_speed : hint_range(0.0, 2.0) = 0.5;
uniform float particle_size : hint_range(0.5, 3.0) = 1.0;
uniform vec4 particle_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);

// ===== PULSING GLOW =====
uniform bool enable_pulse = false;
uniform float pulse_speed : hint_range(0.0, 3.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 0.3) = 0.1;
uniform vec4 pulse_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);

// ===== AURORA / NORTHERN LIGHTS =====
uniform bool enable_aurora = false;
uniform float aurora_speed : hint_range(0.0, 2.0) = 0.3;
uniform float aurora_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 aurora_color1 : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform vec4 aurora_color2 : source_color = vec4(0.3, 0.5, 1.0, 1.0);

// ===== FOG WISPS =====
uniform bool enable_fog = false;
uniform float fog_speed : hint_range(0.0, 1.0) = 0.2;
uniform float fog_density : hint_range(0.0, 1.0) = 0.3;
uniform vec4 fog_color : source_color = vec4(0.8, 0.8, 0.9, 0.3);

// ===== PLAYER MOTION (passed from script) =====
uniform vec2 player_velocity = vec2(0.0, 0.0);
uniform float player_speed_normalized = 0.0;
uniform bool enable_motion_effects = true;
uniform float motion_influence : hint_range(0.0, 2.0) = 1.0;
uniform bool pause_auto_animation = false;

// ===== UTILITY FUNCTIONS =====

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

vec2 hash22(vec2 p) {
    return vec2(hash(p), hash2(p));
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// ===== STAR FIELD =====

float stars(vec2 uv, float time, vec2 motion_offset) {
    float star_field = 0.0;
    
    for (int layer = 0; layer < 3; layer++) {
        float scale = 100.0 + float(layer) * 50.0;
        
        // Parallax - distant stars move less
        float parallax = 0.3 / (float(layer) + 1.0);
        vec2 parallax_uv = uv + motion_offset * parallax * 0.0003;
        
        vec2 grid = floor(parallax_uv * scale);
        vec2 local_uv = fract(parallax_uv * scale);
        
        float rand = hash(grid + float(layer) * 100.0);
        
        if (rand < star_density * (3.0 - float(layer))) {
            vec2 star_pos = hash22(grid + float(layer) * 100.0) * 0.8 + 0.1;
            float dist = length(local_uv - star_pos);
            
            float size = 0.03 / (float(layer) + 1.0);
            float star = smoothstep(size, 0.0, dist);
            
            float twinkle = sin(time * star_twinkle_speed + rand * 6.28) * 0.5 + 0.5;
            twinkle = mix(0.5, 1.0, twinkle);
            
            star_field += star * twinkle * star_brightness / (float(layer) + 1.0);
        }
    }
    
    return star_field;
}

// ===== DEPTH LAYERS =====

float depth_layer_value(vec2 uv, float time, int layer, vec2 motion_offset) {
    float layer_f = float(layer);
    float speed = depth_scroll_speed * (0.5 + layer_f * 0.3);
    
    // Base scrolling (only when not paused)
    vec2 offset = vec2(time * speed * 0.1, time * speed * 0.05);
    
    // Add parallax from player movement - closer layers move more
    float parallax_strength = (float(depth_layer_count) - layer_f) / float(depth_layer_count);
    offset += motion_offset * parallax_strength * 0.001;
    
    vec2 scaled_uv = uv * (2.0 + layer_f * 1.5) + offset;
    
    float n = fbm(scaled_uv, 3);
    
    float threshold = 0.4 + layer_f * 0.1;
    float softness = 0.2;
    return smoothstep(threshold - softness, threshold + softness, n);
}

// ===== FLOATING PARTICLES =====

float particles(vec2 uv, float time, vec2 motion_offset, float speed_factor) {
    float result = 0.0;
    
    for (int i = 0; i < 4; i++) {
        float scale = 20.0 + float(i) * 10.0;
        
        // Parallax offset based on layer depth
        float parallax = 1.0 / (float(i) + 1.0);
        vec2 parallax_uv = uv + motion_offset * parallax * 0.0005;
        
        vec2 grid = floor(parallax_uv * scale);
        vec2 local_uv = fract(parallax_uv * scale);
        
        float rand = hash(grid + float(i) * 50.0);
        
        if (rand < particle_density) {
            vec2 particle_pos = hash22(grid + float(i) * 50.0);
            
            float speed_var = hash(grid + float(i) * 100.0 + 7.0);
            float effective_speed = particle_speed * (0.5 + speed_var * 0.5) * (1.0 + speed_factor * 0.5);
            particle_pos.y = fract(particle_pos.y - time * effective_speed);
            
            float sway_amount = 0.1 + speed_factor * 0.1;
            particle_pos.x += sin(time * 2.0 + rand * 6.28) * sway_amount;
            
            float dist = length(local_uv - particle_pos);
            float size = (0.02 + rand * 0.02) * particle_size;
            
            float p = smoothstep(size, size * 0.3, dist);
            p *= smoothstep(0.0, 0.2, particle_pos.y) * smoothstep(1.0, 0.8, particle_pos.y);
            
            result += p;
        }
    }
    
    return clamp(result, 0.0, 1.0);
}

// ===== AURORA =====

float aurora(vec2 uv, float time) {
    float result = 0.0;
    float height_mask = smoothstep(0.7, 0.2, uv.y);
    
    for (int i = 0; i < 3; i++) {
        float layer_f = float(i);
        vec2 aurora_uv = uv;
        aurora_uv.x += time * aurora_speed * (0.3 + layer_f * 0.2);
        aurora_uv *= vec2(2.0, 1.0) * (1.0 + layer_f * 0.5);
        
        float n = fbm(aurora_uv, 4);
        
        float ribbon = sin(uv.x * 10.0 + time * aurora_speed + n * 5.0 + layer_f * 2.0);
        ribbon = ribbon * 0.5 + 0.5;
        ribbon = pow(ribbon, 3.0);
        
        result += ribbon * height_mask * (1.0 / (layer_f + 1.0));
    }
    
    return result * aurora_intensity;
}

// ===== FOG WISPS =====

float fog_wisps(vec2 uv, float time, vec2 motion_offset) {
    vec2 fog_uv = uv * 3.0;
    fog_uv.x += time * fog_speed;
    fog_uv.y += sin(time * fog_speed * 0.5) * 0.2;
    fog_uv += motion_offset * 0.0008;
    
    float f = fbm(fog_uv, 5);
    f = smoothstep(0.3, 0.7, f);
    
    vec2 fog_uv2 = uv * 2.0;
    fog_uv2.x -= time * fog_speed * 0.7;
    fog_uv2 += motion_offset * 0.0004;
    float f2 = fbm(fog_uv2 + 100.0, 4);
    f2 = smoothstep(0.4, 0.7, f2);
    
    return (f * 0.6 + f2 * 0.4) * fog_density;
}

// ===== MAIN =====

void fragment() {
    vec2 uv = UV;
    float time = pause_auto_animation ? 0.0 : TIME;
    
    // Calculate motion offset for parallax effects
    vec2 motion_offset = vec2(0.0);
    float speed_factor = 0.0;
    if (enable_motion_effects) {
        motion_offset = player_velocity * motion_influence;
        speed_factor = player_speed_normalized * motion_influence;
    }
    
    // ===== BASE GRADIENT (static, no wave) =====
    vec4 final_color;
    if (uv.y < 0.5) {
        float t = uv.y / 0.5;
        final_color = mix(color_top, color_middle, t);
    } else {
        float t = (uv.y - 0.5) / 0.5;
        final_color = mix(color_middle, color_bottom, t);
    }
    
    // ===== DEPTH LAYERS =====
    if (enable_depth_layers) {
        for (int i = 0; i < depth_layer_count; i++) {
            float layer_val = depth_layer_value(uv, time, i, motion_offset);
            float layer_alpha = depth_intensity * (1.0 - float(i) / float(depth_layer_count));
            final_color.rgb = mix(final_color.rgb, depth_color.rgb, layer_val * layer_alpha);
        }
    }
    
    // ===== FOG WISPS =====
    if (enable_fog) {
        float fog = fog_wisps(uv, time, motion_offset);
        final_color.rgb = mix(final_color.rgb, fog_color.rgb, fog * fog_color.a);
    }
    
    // ===== AURORA =====
    if (enable_aurora) {
        float a = aurora(uv, time);
        vec3 aurora_col = mix(aurora_color1.rgb, aurora_color2.rgb, sin(uv.x * 5.0 + time) * 0.5 + 0.5);
        final_color.rgb += aurora_col * a;
    }
    
    // ===== SHIMMER =====
    if (enable_shimmer) {
        float effective_shimmer = shimmer_intensity * (1.0 + speed_factor * 0.5);
        float shimmer = sin(uv.x * 10.0 + time * 2.0) * sin(uv.y * 8.0 - time * 1.5);
        final_color.rgb += shimmer * effective_shimmer;
    }
    
    // ===== NOISE TEXTURE =====
    if (enable_noise) {
        float n = noise(uv * 100.0 + time * 0.5) * noise_intensity;
        final_color.rgb += n - noise_intensity * 0.5;
    }
    
    // ===== PULSING GLOW =====
    if (enable_pulse) {
        float pulse = sin(time * pulse_speed) * 0.5 + 0.5;
        pulse = pow(pulse, 2.0);
        
        vec2 glow_center = vec2(0.5, 1.2);
        float glow_dist = length(uv - glow_center);
        float glow = smoothstep(1.0, 0.0, glow_dist) * pulse * pulse_intensity;
        
        final_color.rgb += pulse_color.rgb * glow;
    }
    
    // ===== STARS =====
    if (enable_stars) {
        float star_field = stars(uv, time, motion_offset);
        
        if (star_colored) {
            vec3 star_col = vec3(
                0.8 + hash(floor(uv * 150.0)) * 0.4,
                0.8 + hash(floor(uv * 150.0) + 50.0) * 0.4,
                0.8 + hash(floor(uv * 150.0) + 100.0) * 0.4
            );
            final_color.rgb += star_field * star_col;
        } else {
            final_color.rgb += star_field;
        }
    }
    
    // ===== FLOATING PARTICLES =====
    if (enable_particles) {
        float p = particles(uv, time, motion_offset, speed_factor);
        final_color.rgb = mix(final_color.rgb, particle_color.rgb, p * particle_color.a);
    }
    
    // ===== VIGNETTE (apply last) =====
    if (vignette_strength > 0.0) {
        vec2 center = uv - 0.5;
        float vignette = 1.0 - dot(center, center) * vignette_strength * 2.0;
        final_color.rgb *= vignette;
    }
    
    COLOR = final_color;
}
