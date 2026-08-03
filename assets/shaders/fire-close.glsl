vec4 close_color(vec3 coords_geo, vec3 size_geo) {
    vec3 coords_tex = niri_geo_to_tex * coords_geo;
    vec4 color = texture2D(niri_tex, coords_tex.st);

    float p = niri_clamped_progress;
    float seed = niri_random_seed;

    vec2 uv = coords_geo.xy;
    float burn_line = p * 1.4 - 0.2;

    float noise = fract(sin(dot(uv * vec2(8.0, 20.0) + seed * 10.0, vec2(12.9898, 78.233))) * 43758.5453);
    float heat = noise * 0.3 + sin(uv.x * 30.0 + seed * 6.28 + p * 15.0) * 0.15;
    float front = burn_line + heat * 0.08;

    vec3 ember = vec3(0.953, 0.514, 0.467);
    vec3 flame2 = vec3(0.918, 0.627, 0.494);
    vec3 flame3 = vec3(0.976, 0.886, 0.686);
    vec3 spark = vec3(0.776, 0.745, 1.0);

    vec3 flame_col = mix(ember, flame2, smoothstep(0.0, 0.3, front - uv.y));
    flame_col = mix(flame_col, flame3, smoothstep(0.15, 0.4, front - uv.y));
    flame_col = mix(flame_col, spark, smoothstep(0.35, 0.6, front - uv.y));

    float band = smoothstep(0.0, 0.06, front - uv.y)
               * (1.0 - smoothstep(0.06, 0.25, front - uv.y));

    float dissolve = 1.0 - smoothstep(front - 0.02, front + 0.02, uv.y);

    vec3 final_col = mix(color.rgb, flame_col, band * 0.85);
    float final_alpha = color.a * dissolve;

    if (uv.y > front + 0.25) {
        final_col = vec3(0.0);
        final_alpha = 0.0;
    }

    return vec4(final_col * final_alpha, final_alpha);
}
