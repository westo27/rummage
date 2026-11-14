// The pixel filter's colour limit, shared by the screen filter and the
// marble bag so both band and dither the same way.

// A 4x4 Bayer matrix: an ordered pattern of thresholds from 0 to 15/16, the
// classic "checkered" dither of old hardware. `cell` is a chunky pixel.
float bayer(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	const float m[16] = float[](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	return m[y * 4 + x] / 16.0;
}

// Rounds each channel to one of `levels` shades. `spread` is how much of each
// band the dither covers: 1 dithers everywhere, lower keeps it to a strip
// where one band meets the next, with flat colour between.
vec3 dither_quantise(vec3 col, vec2 cell, float levels, float spread) {
	float steps = levels - 1.0;
	return floor(col * steps + 0.5 + (bayer(cell) - 0.5) * spread) / steps;
}
