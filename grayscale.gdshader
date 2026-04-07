shader_type canvas_item;
uniform bool is_active = true;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    if (!is_active) {
        float avg = (color.r + color.g + color.b) / 3.0;
        COLOR = vec4(vec3(avg), color.a); // 保持透明度，颜色变灰
    } else {
        COLOR = color;
    }
}
