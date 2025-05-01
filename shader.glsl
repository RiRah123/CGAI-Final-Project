precision highp float;
uniform vec2 iResolution;
uniform float iTime;
uniform vec3 iMouse;

#define GOLDEN_RATIO 1.6180339887498948482
#define PI 3.14159265358979323846
#define MAX_ITERATIONS 8
#define MAX_STEPS 120
#define SHADOW_STEPS 15
#define AO_STEPS 6

int ao_steps = AO_STEPS;
float ao_radius = 0.165;
float ao_darkness = 0.37;

float vignette_strength = 0.8;
float vignette_radius = 0.925;

float glow_strength = 1.3;
vec3 glow_tint = vec3(1.0, 1.0, 1.0);
float glow_min = 0.0;
float glow_decay = 0.9;
bool enable_super_glow = false;
bool enable_glow = true;

vec3 fog_tint = vec3(0.5, 0.6, 0.7);
float fog_strength = 0.08;
float fog_decay = 3.0;

float shadow_bias = 0.01;
float shadow_strength = 0.2;
int shadow_iterations = SHADOW_STEPS;
float shadow_softness = 64.0;
float min_step = 0.0;

float light_strength = 3.600001;
vec3 light1_pos = vec3(10.0);
vec3 light2_pos = vec3(-10.0);
vec3 light1_tint = vec3(1.0, 1.0, 1.0);
vec3 light2_tint = vec3(1.0, 1.0, 1.0);

int fractal_iterations;
int max_ray_steps = MAX_STEPS;
float ambient_strength = 0.35;
float max_ray_distance = 20.0;
float surface_threshold = 0.004;
float ray_step_scale = 0.6;

bool enable_colors = true;
vec3 color1 = vec3(0.8, 0.3, 0.1);
vec3 color2 = vec3(1.0, 0.4, 0.0);
vec3 background_tint = vec3(0.05, 0.02, 0.01);

float refraction_strength = 2.611;
float refraction_sharpness = 8.0;

float box_distance(vec3 p, vec3 s) { vec3 q = abs(p) - s; return length(max(q, 0.0)); }

vec2 fractal_distance(vec3 z) {
    float scale = 3.0;
    vec3 offset = vec3(1.0, 0.0, 0.0);
    float orbit_trap = 100000.0;
    float r;
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
        
        r = dot(z, z);
        orbit_trap = min(orbit_trap, r);
    }
    
    d = box_distance(z, vec3(0.5)) * s;
    return vec2(d * 2.0, orbit_trap).yx;
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
        };
    }

    if (enable_super_glow && distance < max_ray_distance) { steps = float(MAX_STEPS); }

    return vec3(distance > max_ray_distance ? 0.0 : orbit_trap, distance, steps);
}

float compute_shadow(vec3 p, vec3 light_pos, float k) {
    vec3 ray_dir = normalize(light_pos - p);
    float shadow = 1.0;
    float ph = 1e20;
    float t = surface_threshold + shadow_bias;

    for (int i = 0; i < SHADOW_STEPS; i++) {
        float h = fractal_distance(p + ray_dir * t).y;

        if (h < surface_threshold) {
            return 0.0;
        }

        float y = h * h / (2.0 * ph);
        float d = sqrt(h * h - y * y);
        shadow = min(shadow, k * d / max(0.0, t - y));
        ph = h;

        t += max(h, min_step);

        if (t >= max_ray_distance) {
            break;
        }
    }

    return clamp(shadow, 0.0, 1.0);
}

vec3 compute_lighting(vec3 p, vec3 ray_dir, vec3 ray_origin, vec3 light_pos, vec3 light_tint, vec3 normal) {
    vec3 to_light = normalize(light_pos - p);
    float light = light_strength * clamp(dot(to_light, normal), 0.05, 1.0);

    float shadow = compute_shadow(p, light_pos, shadow_softness);
    light *= max(shadow, shadow_strength);
    vec3 reflection = reflect(to_light, normal);
    float specular = pow(max(dot(reflection, ray_dir), 0.0), refraction_sharpness);
    light *= max(specular * refraction_strength, 1.0);

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
    float weight = 1.0 / float(AO_STEPS);

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
    vec3 pixel_color = mix(color1, color2, mix(0.0, orbit_trap, float(int(enable_colors))));
    vec3 final_color;

    if (distance >= max_ray_distance) {
        float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
        final_color = background_tint * vignette;
    } else {
        vec3 p = ray_origin + ray_dir * distance;
        vec3 normal = compute_normal(p);

        float ao = max(compute_ao(p, normal), 0.0);
        vec3 light1 = compute_lighting(p, ray_dir, ray_origin, light1_pos, light1_tint, normal);
        vec3 light2 = compute_lighting(p, ray_dir, ray_origin, light2_pos, light2_tint, normal);

        float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
        final_color = pixel_color * ao * (light1 + light2) * vignette;
    }

    if (enable_glow && float(steps) * ray_step_scale > glow_min) {
        float glow = (glow_strength - 0.2) * smoothstep(glow_min, 100.0, float(steps) * ray_step_scale);
        vec3 glow_color = glow_tint * 3.0;
        final_color += glow_color * pow(glow, glow_decay);
    }

    float fog_distance = distance < max_ray_distance ? distance : max_ray_distance;
    float fog = 1.0 - exp(-fog_strength * fog_distance);
    final_color = mix(final_color, fog_tint, pow(fog, fog_decay));

    return final_color;
}

mat3 setup_camera(vec3 ro, vec3 ta, float cr) {
    vec3 cw = normalize(ta-ro);
    vec3 cp = vec3(sin(cr), cos(cr),0.0);
    vec3 cu = normalize(cross(cw,cp));
    vec3 cv = cross(cu,cw);
    return mat3(cu, cv, cw);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 mo = iMouse.xy/iResolution.xy;
    float time = iTime*0.8;

    fractal_iterations = iMouse.z >= 0.0001 ? 1 + int(7. * iMouse.x / iResolution.x) : 6; 
    
    vec3 target = vec3(0.0, 0.0, 0.0);
    vec3 camera_pos = target + vec3(5.0 * cos(iTime), 5.0 * sin(time), 5.0 * cos(time));
    mat3 camera = setup_camera(camera_pos, target, 0.0);

    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec3 ray_dir = camera * normalize(vec3(p, 4.5));
    vec3 color = shade_pixel(camera_pos, ray_dir, uv);

    color = color * 3.0 / (2.5 + color);
    color = pow(color, vec3(0.4545));
    
    fragColor = vec4(color, 1.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
} 