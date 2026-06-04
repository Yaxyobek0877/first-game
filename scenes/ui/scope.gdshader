shader_type canvas_item;
// Snayper durbin overlay: doira ichi ko'rinadi, tashqarisi qora (vignette) +
// chekkada qora halqa + markazda ingichka nishon chiziqlari.

uniform float aspect = 1.777;   // ekran nisbati (skriptdan beriladi)
uniform float radius = 0.33;    // durbin doirasi radiusi (UV birligida)

void fragment() {
	vec2 c = UV - vec2(0.5);
	c.x *= aspect;               // doira aylana bo'lishi uchun x'ni nisbatga moslaymiz
	float d = length(c);

	// Doiradan tashqarisi qora
	float outside = smoothstep(radius, radius + 0.008, d);
	vec4 col = vec4(0.0, 0.0, 0.0, outside);

	// Chekkadagi qora halqa (durbin ramkasi)
	float ring = smoothstep(radius - 0.020, radius - 0.007, d) - smoothstep(radius - 0.007, radius, d);
	col.a = max(col.a, clamp(ring, 0.0, 1.0));

	// Nishon chiziqlari (faqat doira ichida)
	if (d < radius) {
		float lw = 0.0016;
		float vline = 1.0 - smoothstep(lw, lw + 0.0008, abs(c.x));
		float hline = 1.0 - smoothstep(lw, lw + 0.0008, abs(c.y));
		float cross = max(vline, hline);
		col = mix(col, vec4(0.02, 0.02, 0.02, 0.9), cross);
	}

	COLOR = col;
}
