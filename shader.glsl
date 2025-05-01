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

int ambient_occlusion_steps = AO_STEPS;
float ambient_occlusion_radius = 0.165;
float ambient_occlusion_darkness = 0.37;

float vignette_strength = 0.8;
float vignette_radius = 0.925;

float glow_intensity = 1.3;
vec3 glow_color = vec3(1.0, 1.0, 1.0);
float glow_threshold = 0.0;
float glow_falloff = 0.9;
bool super_glow = false;
bool glow = true;

vec3 fog_color = vec3(0.5, 0.6, 0.7);
float fog_density = 0.08;
float fog_falloff = 3.0;

// Shadows
float self_shadow_bias = 0.01;
float shadow_darkness = 0.2;
int shadow_steps = SHADOW_STEPS;
float shadow_softness = 64.0;
float min_step_size = 0.0;

// Lighting
float light_intensity = 3.600001;
vec3 light1_position = vec3(10.0);
vec3 light2_position = vec3(-10.0);
vec3 light1_color = vec3(1.0, 1.0, 1.0);
vec3 light2_color = vec3(1.0, 1.0, 1.0);

// Rendering
int iterations; // Set in main image
int max_steps = MAX_STEPS;
float ambient_light = 0.35;
float max_distance = 20.0;
float surface_distance = 0.004; // 0.00001
float raystep_multiplier = 0.6;

// Coloring
bool colors = true;
vec3 palette_color1 = vec3(0.8, 0.3, 0.1);
vec3 palette_color2 = vec3(1.0, 0.4, 0.0);
vec3 bg_color = vec3(0.05, 0.02, 0.01);

// Refraction
float refraction_intensity = 2.611;
float refraction_sharpness = 8.0;

// Fractal
float cube_sdf3d(vec3 p, vec3 s) { vec3 q = abs(p) - s; return length(max(q, 0.0)); }

vec2 vicseksnowflake_sdf(vec3 z) {
    float scale = 3.0;
    vec3 offset = vec3(1.0, 0.0, 0.0);
    float orbit_trap = 100000.0;
    float r;
    float s = 1.0;
    float d = 1000.0;
    
    z /= 2.0;

    for (int i = 0; i < MAX_ITERATIONS; i++) {
        if (i >= iterations) break;
        
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
    
    d = cube_sdf3d(z, vec3(0.5)) * s;
    return vec2(d * 2.0, orbit_trap).yx;
}

vec3 ray_marcher(vec3 ro, vec3 rd) {
    float dfo = 0.0;
    float orbit_trap_distance;
    float total_marches = 0.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        vec2 data = vicseksnowflake_sdf(ro + rd * dfo);
        float point_distance = data.y;
        dfo += point_distance * raystep_multiplier;
        total_marches += 1.0;

        if (abs(point_distance) < surface_distance || dfo > max_distance) {
            orbit_trap_distance = data.x;
            break;
        };
    }

    if (super_glow && dfo < max_distance) { total_marches = float(MAX_STEPS); }

    return vec3(dfo > max_distance ? 0.0 : orbit_trap_distance, dfo, total_marches);
}

float soft_shadow(vec3 p, vec3 light_pos, float k) {
    vec3 rd = normalize(light_pos - p);
    float res = 1.0;
    float ph = 1e20;
    float t = surface_distance + self_shadow_bias;

    for (int i = 0; i < SHADOW_STEPS; i++) {
        float h = vicseksnowflake_sdf(p + rd * t).y;

        if (h < surface_distance) {
            return 0.0;
        }

        float y = h * h / (2.0 * ph);
        float d = sqrt(h * h - y * y);
        res = min(res, k * d / max(0.0, t - y));
        ph = h;

        t += max(h, min_step_size);

        if (t >= max_distance) {
            break;
        }
    }

    return clamp(res, 0.0, 1.0);
}

vec3 get_light(vec3 p, vec3 rd, vec3 ro, vec3 light_pos, vec3 light_color, vec3 normal) {
    vec3 to_light = normalize(light_pos - p);
    float light = light_intensity * clamp(dot(to_light, normal), 0.05, 1.0);

    float shadow = soft_shadow(p, light_pos, shadow_softness);
    light *= max(shadow, shadow_darkness);
    vec3 reflection = reflect(to_light, normal);
    float specular = pow(max(dot(reflection, rd), 0.0), refraction_sharpness);
    light *= max(specular * refraction_intensity, 1.0);

    return max(light_color * light, ambient_light);
}

vec3 calculate_normal(vec3 p) {
    float h = 0.000001;
    return normalize(vec3(
        vicseksnowflake_sdf(p + vec3(h, 0.0, 0.0)).y - vicseksnowflake_sdf(p - vec3(h, 0.0, 0.0)).y,
        vicseksnowflake_sdf(p + vec3(0.0, h, 0.0)).y - vicseksnowflake_sdf(p - vec3(0.0, h, 0.0)).y,
        vicseksnowflake_sdf(p + vec3(0.0, 0.0, h)).y - vicseksnowflake_sdf(p - vec3(0.0, 0.0, h)).y
    ));
}

float calculate_ambient_occlusion(vec3 p, vec3 normal) {
    float occlusion = 0.0;
    float weight = 1.0 / float(AO_STEPS);

    for (int i = 0; i < AO_STEPS; i++) {
        float ao_scale = float(i + 1) / float(AO_STEPS);
        vec3 sample_point = p + normal * ao_scale * ambient_occlusion_radius;
        float d = vicseksnowflake_sdf(sample_point).y;
        occlusion += max(ambient_occlusion_radius - d, 0.0) * weight / ambient_occlusion_radius;
    }

    return 1.0 - clamp(occlusion, 0.0, 1.0);
}

vec3 render(vec3 ray_origin, vec3 ray_dir, vec2 screen_uv) {
    vec3 data = ray_marcher(ray_origin, ray_dir);
    float orbit_trap = data.x;
    float dfo = data.y;
    float total_marches = data.z;
    vec3 palette_color = mix(palette_color1, palette_color2, mix(0.0, orbit_trap, float(int(colors))));
    vec3 final_color;

    if (dfo >= max_distance) {
        float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
        final_color = bg_color * vignette;
    } else {
        vec3 p = ray_origin + ray_dir * dfo;
        vec3 normal = calculate_normal(p);

        float ao = max(calculate_ambient_occlusion(p, normal), 0.0);
        vec3 light1 = get_light(p, ray_dir, ray_origin, light1_position, light1_color, normal);
        vec3 light2 = get_light(p, ray_dir, ray_origin, light2_position, light2_color, normal);

        float vignette = smoothstep(vignette_radius, vignette_radius - vignette_strength, length(screen_uv - vec2(0.5)));
        final_color = palette_color * ao * (light1 + light2) * vignette;
    }

    if (glow && float(total_marches) * raystep_multiplier > glow_threshold) {
        float final_glow_intensity = (glow_intensity - 0.2) * smoothstep(glow_threshold, 100.0, float(total_marches) * raystep_multiplier);
        vec3 final_glow_color = glow_color * 3.0;
        final_color += final_glow_color * pow(final_glow_intensity, glow_falloff);
    }

    float fog_distance = dfo < max_distance ? dfo : max_distance;
    float fog_amount = 1.0 - exp(-fog_density * fog_distance);
    final_color = mix(final_color, fog_color, pow(fog_amount, fog_falloff));

    return final_color;
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
    vec3 cw = normalize(ta-ro);
    vec3 cp = vec3(sin(cr), cos(cr),0.0);
    vec3 cu = normalize( cross(cw,cp) );
    vec3 cv =          ( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 mo = iMouse.xy/iResolution.xy;
    float time = iTime*0.8;

    iterations = iMouse.z >= 0.0001 ? 1 + int(7. * iMouse.x / iResolution.x) : 6; 
    
    vec3 ta = vec3( 0.0, 0.0, 0.0 );
    vec3 ro = ta + vec3(5.0 * cos(iTime), 5.0 * sin(time), 5.0 * cos(time));
    mat3 ca = setCamera( ro, ta, 0.0 );

    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec3 rd = ca * normalize(vec3(p, 4.5));
    vec3 col = render(ro, rd, uv);

    col = col * 3.0 / (2.5 + col);
    col = pow( col, vec3(0.4545) );
    
    fragColor = vec4(col, 1.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
} 