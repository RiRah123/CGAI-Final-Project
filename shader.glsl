precision highp float;

// Uniforms
uniform vec2 iResolution;
uniform float iTime;
uniform vec3 iMouse;
uniform sampler2D radiance_field_weights;  // New uniform for neural network weights
uniform float radiance_field_scale;        // Scale factor for the radiance field

// Constants
#define PHI 1.6180339887498948482
#define TAU 6.28318530717958647692
#define PI 3.14159265358979323846
#define MAX_ITERATIONS 12
#define MAX_STEPS 150
#define SHADOW_STEPS 20
#define AO_STEPS 8
#define NUM_SPLATS 8
#define SPLAT_SIZE 0.15

// Radiance Field Constants
#define RADIANCE_FIELD_STEPS 64
#define RADIANCE_FIELD_MIN_DIST 0.1
#define RADIANCE_FIELD_MAX_DIST 20.0
#define RADIANCE_FIELD_DENSITY_SCALE 1.0
#define RADIANCE_FIELD_COLOR_SCALE 1.0

// Global Variables
int fractal_iterations;
float ray_step_scale = 0.6;
float surface_threshold = 0.004;
float max_ray_distance = 20.0;
float vignette_radius = 0.925;
float vignette_strength = 0.8;

// Material Properties
vec3 material_color1 = vec3(0.2, 0.8, 1.0);  // Keep vibrant colors
vec3 material_color2 = vec3(0.3, 0.9, 1.0);
vec3 material_color3 = vec3(1.0, 0.2, 0.5);
vec3 material_color4 = vec3(1.0, 0.3, 0.6);
vec3 material_background = vec3(0.02, 0.05, 0.1);  // Darker background
float material_refraction = 1.8;  // Reduced refraction
float material_sharpness = 6.0;   // Reduced sharpness

// Lighting Properties
float light_strength = 2.2;       // Significantly reduced light strength
vec3 light_pos1 = vec3(10.0);
vec3 light_pos2 = vec3(-10.0);
vec3 light_tint1 = vec3(0.8);    // Reduced tint intensity
vec3 light_tint2 = vec3(0.8);    // Reduced tint intensity
float ambient_strength = 0.25;    // Reduced ambient light

// Effect Properties
float glow_strength = 0.8;        // Reduced glow
vec3 glow_color = vec3(0.8);     // Reduced glow intensity
float glow_min = 0.0;
float glow_decay = 1.2;          // Increased decay for less glow
bool super_glow = false;         // Disable super glow
bool enable_glow = true;
vec3 fog_color = vec3(0.4, 0.5, 0.6);  // Darker fog
float fog_strength = 0.1;        // Slightly increased fog
float fog_decay = 2.8;

// Shadow Properties
float shadow_bias = 0.01;
float shadow_strength = 0.2;
int shadow_steps = SHADOW_STEPS;
float shadow_softness = 64.0;
float shadow_min_step = 0.0;

// Ambient Occlusion Properties
int ao_steps = AO_STEPS;
float ao_radius = 0.165;
float ao_darkness = 0.37;

// Camera Properties
struct Camera {
    vec3 position;
    vec3 target;
    float rotation;
};

// Neural Network Parameters
const float WEIGHT_1 = 0.5;
const float WEIGHT_2 = 0.7;
const float WEIGHT_3 = 0.3;
const float WEIGHT_4 = 0.6;

const float MAX_REFLECTION_BOUNCES = 3.0;
const float REFLECTION_STRENGTH = 0.5;
const float FRESNEL_BIAS = 0.1;
const float FRESNEL_SCALE = 0.4;
const float FRESNEL_POWER = 2.0;

// Gaussian Splat Parameters
vec3 splat_colors[NUM_SPLATS];
vec2 splat_positions[NUM_SPLATS];
float splat_intensities[NUM_SPLATS];

// Custom tanh implementation
float custom_tanh(float x) {
    float exp2x = exp(2.0 * x);
    return (exp2x - 1.0) / (exp2x + 1.0);
}

// Utility Functions
float box_distance(vec3 p, vec3 s) {
    vec3 q = abs(p) - s;
    return length(max(q, 0.0));
}

mat3 setup_camera(vec3 ro, vec3 ta, float cr) {
    vec3 cw = normalize(ta-ro);
    vec3 cp = vec3(sin(cr), cos(cr),0.0);
    vec3 cu = normalize(cross(cw,cp));
    vec3 cv = cross(cu,cw);
    return mat3(cu, cv, cw);
}

// Core Functions
vec2 fractal_distance_single(vec3 z, float offset_x) {
    float scale = 3.0;
    vec3 offset = vec3(1.0 + offset_x, 0.0, 0.0);
    float orbit_trap = 100000.0;
    float s = 1.0;
    float d = 1000.0;
    
    z /= 2.0;

    for (int i = 0; i < MAX_ITERATIONS; i++) {
        if (i >= fractal_iterations) break;
        
        z = abs(z);
        if (z.x - z.y < 0.0) z.xy = z.yx;
        if (z.x - z.z < 0.0) z.xz = z.zx;
        if (z.y - z.z < 0.0) z.yz = z.zy;

        z = z * scale - offset * (scale - 1.0);
        s /= scale;

        if (z.y > 0.5) z.y -= 1.0;
        z.x += 1.0;
        
        orbit_trap = min(orbit_trap, dot(z, z));
    }
    
    d = box_distance(z, vec3(0.5)) * s;
    return vec2(d * 2.0, orbit_trap).yx;
}

vec3 get_animated_color(vec3 base_color, float time_offset) {
    float t = iTime * 0.5 + time_offset;
    float r = base_color.r * (0.8 + 0.2 * sin(t));
    float g = base_color.g * (0.8 + 0.2 * sin(t + 2.094));
    float b = base_color.b * (0.8 + 0.2 * sin(t + 4.189));
    return vec3(r, g, b);
}

vec4 activate_neuron(vec4 neuron_data, float time) {
    // Simple activation function using sine waves with different frequencies
    return vec4(
        sin(neuron_data.x * WEIGHT_1 + time) * 0.5 + 0.5,
        sin(neuron_data.y * WEIGHT_2 + time * 1.3) * 0.5 + 0.5,
        sin(neuron_data.z * WEIGHT_3 + time * 0.7) * 0.5 + 0.5,
        sin(neuron_data.w * WEIGHT_4 + time * 0.9) * 0.5 + 0.5
    );
}

vec3 neural_color_transform(vec3 color, float time) {
    vec4 neural_data = vec4(color, time * 0.1);
    vec4 activated = activate_neuron(neural_data, time);
    return mix(color, vec3(activated.xyz), 0.3);
}

float neural_distance_modify(float dist, vec3 p, float time) {
    vec4 neural_data = vec4(p * 0.1, time * 0.1);
    vec4 activated = activate_neuron(neural_data, time);
    return dist * (1.0 + 0.1 * (activated.x - 0.5));
}

vec2 fractal_distance(vec3 z) {
    float time = iTime * 0.5;
    
    vec3 offset2 = vec3(8.0, 0.0, 0.0);
    
    // Apply neural network influence to the position
    vec4 pos_influence = activate_neuron(vec4(z * 0.1, time), time);
    z += (pos_influence.xyz - 0.5) * 0.5;
    
    vec2 d1 = fractal_distance_single(z, 0.0);
    vec2 d2 = fractal_distance_single(z - offset2, 2.0);
    
    // Modify distances using neural network
    d1.y = neural_distance_modify(d1.y, z, time);
    d2.y = neural_distance_modify(d2.y, z - offset2, time);
    
    if (d1.y < d2.y) {
        return vec2(0.0, d1.y);
    }
    return vec2(1.0, d2.y);
}

vec3 trace_ray(vec3 ray_origin, vec3 ray_dir) {
    float distance = 0.0;
    float orbit_trap;
    float steps = 0.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        vec2 data = fractal_distance(ray_origin + ray_dir * distance);
        float point_distance = data.y;
        distance += point_distance * ray_step_scale;
        steps += 1.0;

        if (abs(point_distance) < surface_threshold || distance > max_ray_distance) {
            orbit_trap = data.x;
            break;
        }
    }

    if (super_glow && distance < max_ray_distance) {
        steps = float(MAX_STEPS);
    }

    return vec3(distance > max_ray_distance ? 0.0 : orbit_trap, distance, steps);
}

float compute_shadow(vec3 p, vec3 light_pos) {
    vec3 ray_dir = normalize(light_pos - p);
    float shadow = 1.0;
    float ph = 1e20;
    float t = surface_threshold + shadow_bias;

    for (int i = 0; i < SHADOW_STEPS; i++) {
        float h = fractal_distance(p + ray_dir * t).y;

        if (h < surface_threshold) return 0.0;

        float y = h * h / (2.0 * ph);
        float d = sqrt(h * h - y * y);
        shadow = min(shadow, shadow_softness * d / max(0.0, t - y));
        ph = h;
        t += max(h, shadow_min_step);

        if (t >= max_ray_distance) break;
    }

    return clamp(shadow, 0.0, 1.0);
}

vec3 compute_lighting(vec3 p, vec3 ray_dir, vec3 ray_origin, vec3 light_pos, vec3 light_tint, vec3 normal) {
    vec3 to_light = normalize(light_pos - p);
    float light = light_strength * clamp(dot(to_light, normal), 0.05, 1.0);

    float shadow = compute_shadow(p, light_pos);
    light *= max(shadow, shadow_strength);
    
    vec3 reflection = reflect(to_light, normal);
    float specular = pow(max(dot(reflection, ray_dir), 0.0), material_sharpness);
    light *= max(specular * material_refraction, 1.0);

    return max(light_tint * light, ambient_strength);
}

vec3 compute_normal(vec3 p) {
    float h = 0.000001;
    return normalize(vec3(
        fractal_distance(p + vec3(h, 0.0, 0.0)).y - fractal_distance(p - vec3(h, 0.0, 0.0)).y,
        fractal_distance(p + vec3(0.0, h, 0.0)).y - fractal_distance(p - vec3(0.0, h, 0.0)).y,
        fractal_distance(p + vec3(0.0, 0.0, h)).y - fractal_distance(p - vec3(0.0, 0.0, h)).y
    ));
}

float compute_ao(vec3 p, vec3 normal) {
    float occlusion = 0.0;
    float weight = 1.0 / float(ao_steps);

    for (int i = 0; i < AO_STEPS; i++) {
        float ao_scale = float(i + 1) / float(AO_STEPS);
        vec3 sample_point = p + normal * ao_scale * ao_radius;
        float d = fractal_distance(sample_point).y;
        occlusion += max(ao_radius - d, 0.0) * weight / ao_radius;
    }

    return 1.0 - clamp(occlusion, 0.0, 1.0);
}

// Compute fresnel reflection factor
float compute_fresnel(vec3 normal, vec3 ray_dir) {
    float fresnel = FRESNEL_BIAS + FRESNEL_SCALE * pow(1.0 + dot(normal, ray_dir), FRESNEL_POWER);
    return clamp(fresnel, 0.0, 1.0);
}

// Get reflection color with neural influence - non-recursive version
vec3 get_reflection_color(vec3 pos, vec3 normal, vec3 ray_dir, float time) {
    vec3 total_reflection = vec3(0.0);
    vec3 current_pos = pos;
    vec3 current_dir = ray_dir;
    vec3 current_normal = normal;
    float reflection_factor = 1.0;
    
    for (int bounce = 0; bounce < 3; bounce++) {
        // Calculate reflection ray
        vec3 reflected = reflect(current_dir, current_normal);
        
        // Add some neural-influenced variation to reflection
        vec4 reflection_influence = activate_neuron(vec4(reflected, time), time);
        reflected = normalize(reflected + (reflection_influence.xyz - 0.5) * 0.1);
        
        // Trace reflection ray
        vec3 reflection_data = trace_ray(current_pos + current_normal * surface_threshold * 2.0, reflected);
        float reflection_dist = reflection_data.y;
        
        if (reflection_dist >= max_ray_distance) {
            total_reflection += reflection_factor * material_background;
            break;
        }
        
        vec3 reflection_pos = current_pos + reflected * reflection_dist;
        vec3 reflection_normal = compute_normal(reflection_pos);
        
        // Get base color at reflection point
        vec3 reflection_color;
        if (reflection_data.x < 0.5) {
            vec3 c1 = get_animated_color(material_color1, 0.0);
            vec3 c2 = get_animated_color(material_color2, 1.047);
            reflection_color = mix(c1, c2, 0.5 + 0.5 * sin(time));
        } else {
            vec3 c3 = get_animated_color(material_color3, 2.094);
            vec3 c4 = get_animated_color(material_color4, 3.142);
            reflection_color = mix(c3, c4, 0.5 + 0.5 * sin(time + 3.14));
        }
        
        // Apply neural color transformation
        reflection_color = neural_color_transform(reflection_color, time);
        
        // Calculate lighting for reflection
        float reflection_ao = compute_ao(reflection_pos, reflection_normal);
        vec3 reflection_light1 = compute_lighting(reflection_pos, reflected, current_pos, light_pos1, light_tint1, reflection_normal);
        vec3 reflection_light2 = compute_lighting(reflection_pos, reflected, current_pos, light_pos2, light_tint2, reflection_normal);
        
        reflection_color *= reflection_ao * (reflection_light1 + reflection_light2);
        
        // Add to total reflection
        total_reflection += reflection_factor * reflection_color;
        
        // Update for next bounce
        reflection_factor *= compute_fresnel(reflection_normal, reflected) * REFLECTION_STRENGTH;
        if (reflection_factor < 0.1) break;
        
        current_pos = reflection_pos;
        current_dir = reflected;
        current_normal = reflection_normal;
    }
    
    return total_reflection;
}

float gaussian(vec2 p, vec2 center, float size) {
    vec2 d = p - center;
    return exp(-dot(d, d) / size);
}

vec3 apply_splats(vec2 uv, vec3 base_color, float time) {
    vec3 splat_contribution = vec3(0.0);
    
    // Initialize splat properties with animation
    for(int i = 0; i < NUM_SPLATS; i++) {
        float t = time + float(i) * PHI;
        splat_positions[i] = vec2(
            0.5 + 0.3 * cos(t * 0.5 + float(i)),
            0.5 + 0.3 * sin(t * 0.7 + float(i))
        );
        splat_intensities[i] = 0.15 + 0.1 * sin(t * 0.3);
        splat_colors[i] = get_animated_color(
            mix(material_color1, material_color3, float(i) / float(NUM_SPLATS)),
            float(i) * 0.5
        );
    }
    
    // Apply splats
    for(int i = 0; i < NUM_SPLATS; i++) {
        float intensity = gaussian(uv, splat_positions[i], SPLAT_SIZE) * splat_intensities[i];
        splat_contribution += splat_colors[i] * intensity;
    }
    
    return base_color + splat_contribution;
}

// Radiance Field Functions
vec4 query_radiance_field(vec3 pos, vec3 dir) {
    // Simple MLP implementation for radiance field
    // Input: position (3D) and view direction (3D)
    // Output: RGB color and density
    
    // Position encoding
    vec3 pos_encoded = sin(pos * 2.0 * PI);
    vec3 dir_encoded = sin(dir * 2.0 * PI);
    
    // First layer
    vec4 hidden = vec4(0.0);
    for(int i = 0; i < 3; i++) {
        hidden += vec4(pos_encoded[i], dir_encoded[i], 1.0, 0.0);
    }
    hidden = vec4(
        custom_tanh(hidden.x),
        custom_tanh(hidden.y),
        custom_tanh(hidden.z),
        custom_tanh(hidden.w)
    );
    
    // Second layer
    vec4 layer_output = vec4(0.0);
    for(int i = 0; i < 4; i++) {
        layer_output += hidden[i] * vec4(0.5, 0.5, 0.5, 1.0);
    }
    
    // Output: RGB color and density
    return vec4(
        vec3(
            custom_tanh(layer_output.x),
            custom_tanh(layer_output.y),
            custom_tanh(layer_output.z)
        ) * 0.7 + 0.5,  // Increased color scaling
        exp(layer_output.w) * RADIANCE_FIELD_DENSITY_SCALE * 1.5  // Increased density
    );
}

vec3 render_radiance_field(vec3 ray_origin, vec3 ray_dir) {
    vec3 color = vec3(0.0);
    float transmittance = 1.0;
    
    float step_size = (RADIANCE_FIELD_MAX_DIST - RADIANCE_FIELD_MIN_DIST) / float(RADIANCE_FIELD_STEPS);
    float t = RADIANCE_FIELD_MIN_DIST;
    
    for(int i = 0; i < RADIANCE_FIELD_STEPS; i++) {
        vec3 pos = ray_origin + ray_dir * t;
        vec4 radiance = query_radiance_field(pos, ray_dir);
        
        // Volume rendering integration
        float alpha = 1.0 - exp(-radiance.w * step_size);
        color += transmittance * radiance.xyz * alpha;
        transmittance *= (1.0 - alpha);
        
        if(transmittance < 0.01) break;
        
        t += step_size;
        if(t > RADIANCE_FIELD_MAX_DIST) break;
    }
    
    return color;
}

vec3 shade_pixel(vec3 ray_origin, vec3 ray_dir, vec2 screen_uv) {
    vec3 data = trace_ray(ray_origin, ray_dir);
    float fractal_id = data.x;
    float distance = data.y;
    float steps = data.z;
    
    // Get radiance field contribution
    vec3 radiance_color = render_radiance_field(ray_origin, ray_dir);
    
    if (distance >= max_ray_distance) {
        float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
        return mix(material_background * vignette, radiance_color, 0.4);  // Reduced radiance influence
    }
    
    vec3 p = ray_origin + ray_dir * distance;
    vec3 normal = compute_normal(p);
    float time = iTime * 0.5;
    
    // Neural network influenced colors
    vec3 pixel_color;
    if (fractal_id < 0.5) {
        vec3 c1 = get_animated_color(material_color1, 0.0);
        vec3 c2 = get_animated_color(material_color2, 1.047);
        pixel_color = mix(c1, c2, 0.5 + 0.5 * sin(time));
        pixel_color = neural_color_transform(pixel_color, time);
    } else {
        vec3 c3 = get_animated_color(material_color3, 2.094);
        vec3 c4 = get_animated_color(material_color4, 3.142);
        pixel_color = mix(c3, c4, 0.5 + 0.5 * sin(time + 3.14));
        pixel_color = neural_color_transform(pixel_color, time);
    }
    
    // Calculate base lighting
    float ao = max(compute_ao(p, normal), 0.0);
    
    // Neural network influenced lighting
    vec4 light_influence = activate_neuron(vec4(p * 0.1, time), time);
    light_pos1 = mix(light_pos1, 10.0 * (light_influence.xyz - 0.5), 0.3);
    light_pos2 = mix(light_pos2, -10.0 * (light_influence.wzx - 0.5), 0.3);
    
    vec3 light1 = compute_lighting(p, ray_dir, ray_origin, light_pos1, light_tint1, normal);
    vec3 light2 = compute_lighting(p, ray_dir, ray_origin, light_pos2, light_tint2, normal);
    
    // Calculate reflection
    float fresnel = compute_fresnel(normal, ray_dir);
    vec3 reflection = get_reflection_color(p, normal, ray_dir, time);
    
    // Combine everything
    vec3 final_color = pixel_color * ao * (light1 + light2);
    final_color = mix(final_color, reflection, fresnel * REFLECTION_STRENGTH);
    
    // Blend with radiance field
    final_color = mix(final_color, radiance_color, 0.25);
    
    float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
    final_color *= vignette;

    // Add glow
    if (enable_glow && float(steps) * ray_step_scale > glow_min) {
        vec4 glow_influence = activate_neuron(vec4(p * 0.1, time), time);
        float glow = (glow_strength - 0.2) * smoothstep(glow_min, 100.0, float(steps) * ray_step_scale);
        vec3 neural_glow = mix(glow_color, vec3(glow_influence.xyz), 0.4);
        final_color += neural_glow * pow(glow, glow_decay);
    }

    // Add fog
    float fog_distance = distance < max_ray_distance ? distance : max_ray_distance;
    float fog = 1.0 - exp(-fog_strength * fog_distance);
    vec4 fog_influence = activate_neuron(vec4(ray_dir * 0.1, time), time);
    vec3 neural_fog = mix(fog_color, vec3(fog_influence.xyz), 0.3);
    final_color = mix(final_color, neural_fog, pow(fog, fog_decay));

    return final_color;
}

// Main Functions
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float time = iTime*0.8;

    float cycle = sin(time * 2.0) * 0.5 + 0.5;
    cycle = pow(cycle, 0.7);
    fractal_iterations = 1 + int(7.0 * cycle);
    
    float camera_radius = 12.0;
    float camera_height = 4.0;
    float camera_speed = 0.2;
    
    vec3 target = vec3(4.0, 0.0, 0.0);
    vec3 camera_pos = target + vec3(
        camera_radius * cos(time * camera_speed),
        camera_height,
        camera_radius * sin(time * camera_speed)
    );
    
    float camera_rotation = time * 0.1;
    
    // Dynamic lighting
    light_pos1 = vec3(
        10.0 * cos(time * 0.5),
        8.0 + 2.0 * sin(time * 0.3),
        10.0 * sin(time * 0.5)
    );
    
    light_pos2 = vec3(
        -10.0 * cos(time * 0.4),
        6.0 + 2.0 * sin(time * 0.2),
        -10.0 * sin(time * 0.4)
    );
    
    // Color cycling for lights
    light_tint1 = vec3(0.8 + 0.2 * sin(time), 0.8 + 0.2 * sin(time + 2.094), 1.0);
    light_tint2 = vec3(1.0, 0.8 + 0.2 * sin(time + 4.189), 0.8 + 0.2 * sin(time));
    
    mat3 camera = setup_camera(camera_pos, target, camera_rotation);
    
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec3 ray_dir = camera * normalize(vec3(p, 4.5));
    vec3 color = shade_pixel(camera_pos, ray_dir, uv);
    
    // Enhanced color grading with splats
    color = color * 3.0 / (2.5 + color);
    color = apply_splats(uv, color, time);
    color = pow(color, vec3(0.4545));
    color += 0.05 * vec3(sin(uv.x * 50.0 + time) * sin(uv.y * 50.0 + time)); // Subtle sparkle effect
    
    fragColor = vec4(color, 1.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
} 