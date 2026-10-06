// 沿用本项目天空的昼夜色盘；云的远景雾色与海面反射一致。
uniform vec4 cloud_sky_zenith : source_color = vec4(0.18, 0.43, 0.78, 1.0);
uniform vec4 cloud_sky_horizon : source_color = vec4(0.68, 0.82, 0.94, 1.0);
uniform vec4 cloud_sky_sun_color : source_color = vec4(1.0, 0.97, 0.90, 1.0);
uniform float cloud_sky_daylight = 1.0;
uniform float cloud_sky_twilight = 0.0;
uniform float cloud_sky_sun_visibility = 1.0;

vec3 cloud_sky_background(vec3 direction, vec3 position, vec3 direction_to_sun, int style) {
    float elevation = pow(clamp(direction.y, 0.0, 1.0), 0.45);
    vec3 background = mix(cloud_sky_horizon.rgb, cloud_sky_zenith.rgb, elevation);
    float haze = exp(-max(direction.y, 0.0) * 7.0);
    float sunward = pow(max(dot(normalize(vec3(direction.x, 0.001, direction.z)),
        normalize(vec3(direction_to_sun.x, 0.001, direction_to_sun.z))), 0.0), 2.0);
    vec3 warm = mix(vec3(1.0, 0.25, 0.08), vec3(1.0, 0.54, 0.22), cloud_sky_daylight);
    background += warm * cloud_sky_twilight * haze * sunward * 0.45;
    background += vec3(0.20, 0.07, 0.18) * cloud_sky_twilight * haze * (1.0 - sunward) * 0.35;
    float sun_dot = max(dot(direction, direction_to_sun), 0.0);
    background += cloud_sky_sun_color.rgb * (pow(sun_dot, 24.0) * 0.16 + pow(sun_dot, 256.0) * 0.35) * cloud_sky_sun_visibility;
    return background * mix(0.35, 1.0, smoothstep(-0.30, 0.0, direction.y));
}
