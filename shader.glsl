precision highp float;

// Uniforms
uniform vec2 iResolution;
uniform float iTime;
uniform vec3 iMouse;

// Constants
#define PHI 1.6180339887498948482
#define TAU 6.28318530717958647692
#define MAX_ITERATIONS 12
#define MAX_STEPS 150
#define SHADOW_STEPS 20
#define AO_STEPS 8

// Global Variables
int fractal_iterations;
float ray_step_scale = 0.6;
float surface_threshold = 0.004;
float max_ray_distance = 20.0;
float vignette_radius = 0.925;
float vignette_strength = 0.8;

// Material Properties
vec3 material_color1 = vec3(0.2, 0.6, 0.9);
vec3 material_color2 = vec3(0.1, 0.3, 0.8);
vec3 material_color3 = vec3(0.9, 0.3, 0.2);
vec3 material_color4 = vec3(0.8, 0.2, 0.1);
vec3 material_background = vec3(0.02, 0.05, 0.1);
float material_refraction = 2.611;
float material_sharpness = 8.0;

// Lighting Properties
float light_strength = 3.600001;
vec3 light_pos1 = vec3(10.0);
vec3 light_pos2 = vec3(-10.0);
vec3 light_tint1 = vec3(1.0);
vec3 light_tint2 = vec3(1.0);
float ambient_strength = 0.35;

// Effect Properties
float glow_strength = 1.3;
vec3 glow_color = vec3(1.0);
float glow_min = 0.0;
float glow_decay = 0.9;
bool super_glow = false;
bool enable_glow = true;
vec3 fog_color = vec3(0.5, 0.6, 0.7);
float fog_strength = 0.08;
float fog_decay = 3.0;

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

vec2 fractal_distance(vec3 z) {
    float time = iTime * 0.5;
    float mouse_influence = iMouse.x / iResolution.x * 2.0;
    
    // Dynamic positioning based on time and mouse
    vec3 offset2 = vec3(4.0 * (1.0 + 0.2 * sin(time)), 
                        2.0 * sin(time * 0.7) * mouse_influence,
                        2.0 * cos(time * 0.5) * mouse_influence);
    
    vec2 d1 = fractal_distance_single(z, 0.0);
    vec2 d2 = fractal_distance_single(z - offset2, 2.0);
    
    // Smooth blend between the two objects
    float blend = smoothstep(-1.0, 1.0, sin(time));
    float d = mix(d1.y, d2.y, blend);
    
    if (d1.y < d2.y) {
        return d1;
    }
    return d2;
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

vec3 shade_pixel(vec3 ray_origin, vec3 ray_dir, vec2 screen_uv) {
    vec3 data = trace_ray(ray_origin, ray_dir);
    float orbit_trap = data.x;
    float distance = data.y;
    float steps = data.z;
    
    vec3 p = ray_origin + ray_dir * distance;
    vec3 pixel_color;
    if (p.x < 2.0) {
        vec3 c1 = get_animated_color(material_color1, 0.0);
        vec3 c2 = get_animated_color(material_color2, 1.047);
        pixel_color = mix(c1, c2, orbit_trap);
    } else {
        vec3 c3 = get_animated_color(material_color3, 2.094);
        vec3 c4 = get_animated_color(material_color4, 3.142);
        pixel_color = mix(c3, c4, orbit_trap);
    }
    vec3 final_color;

    if (distance >= max_ray_distance) {
        float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
        final_color = material_background * vignette;
    } else {
        vec3 normal = compute_normal(p);

        float ao = max(compute_ao(p, normal), 0.0);
        vec3 light1 = compute_lighting(p, ray_dir, ray_origin, light_pos1, light_tint1, normal);
        vec3 light2 = compute_lighting(p, ray_dir, ray_origin, light_pos2, light_tint2, normal);

        float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
        final_color = pixel_color * ao * (light1 + light2) * vignette;
    }

    if (enable_glow && float(steps) * ray_step_scale > glow_min) {
        float glow = (glow_strength - 0.2) * smoothstep(glow_min, 100.0, float(steps) * ray_step_scale);
        vec3 glow_color = glow_color * 3.0;
        final_color += glow_color * pow(glow, glow_decay);
    }

    float fog_distance = distance < max_ray_distance ? distance : max_ray_distance;
    float fog = 1.0 - exp(-fog_strength * fog_distance);
    final_color = mix(final_color, fog_color, pow(fog, fog_decay));

    return final_color;
}

// Main Functions
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 mo = iMouse.xy/iResolution.xy;
    float time = iTime*0.8;

    float cycle = sin(time * 2.0) * 0.5 + 0.5;
    cycle = pow(cycle, 0.7);
    fractal_iterations = 1 + int(7.0 * cycle);
    
    // Dynamic camera movement
    float camera_radius = 7.0 + sin(time * 0.5) * 2.0;
    float camera_height = 3.0 + cos(time * 0.3) * 2.0;
    float camera_speed = 0.5;
    
    vec3 target = vec3(2.0 * sin(time * 0.2), 0.0, 0.0);
    vec3 camera_pos = target + vec3(
        camera_radius * cos(time * camera_speed),
        camera_height,
        camera_radius * sin(time * camera_speed)
    );
    
    // Mouse influence on camera
    if (iMouse.z > 0.0) {
        camera_pos.xz += mo * 5.0 - 2.5;
        camera_pos.y += (mo.y - 0.5) * 5.0;
    }
    
    float camera_rotation = sin(time * 0.3) * 0.2;
    
    // Dynamic lighting
    light_pos1 = vec3(
        10.0 * cos(time * 0.7),
        8.0 + 4.0 * sin(time * 0.5),
        10.0 * sin(time * 0.7)
    );
    
    light_pos2 = vec3(
        -10.0 * cos(time * 0.5),
        6.0 + 4.0 * sin(time * 0.6),
        -10.0 * sin(time * 0.5)
    );
    
    // Color cycling for lights
    light_tint1 = vec3(0.8 + 0.2 * sin(time), 0.8 + 0.2 * sin(time + 2.094), 1.0);
    light_tint2 = vec3(1.0, 0.8 + 0.2 * sin(time + 4.189), 0.8 + 0.2 * sin(time));
    
    mat3 camera = setup_camera(camera_pos, target, camera_rotation);
    
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec3 ray_dir = camera * normalize(vec3(p, 4.5));
    vec3 color = shade_pixel(camera_pos, ray_dir, uv);
    
    // Enhanced color grading
    color = color * 3.0 / (2.5 + color);
    color = pow(color, vec3(0.4545));
    color += 0.05 * vec3(sin(uv.x * 50.0 + time) * sin(uv.y * 50.0 + time)); // Subtle sparkle effect
    
    fragColor = vec4(color, 1.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
} 