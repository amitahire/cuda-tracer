#pragma once

#include <ctime>

#include "camera.h"
#include "hitable_list.h"

struct cu_hit {
	int hit_idx;
	float hit_t;
};

struct pixel {
	//TODO pixel should know it's coordinates and it's id should be a computed field
	unsigned int id;
	unsigned int samples;
	unsigned int done;

	pixel() { id = 0; samples = 0; }
};

class renderer {
public:
	renderer(camera* _cam, hitable_list* w, sphere *ls, unsigned int _nx, unsigned int _ny, unsigned int _ns, unsigned int _max_depth, float _min_attenuation) { 
		cam = _cam;
		world = w;
		nx = _nx; 
		ny = _ny; 
		ns = _ns;
		max_depth = _max_depth;
		min_attenuation = _min_attenuation;
		light_shape = ls;
	}

	unsigned int numpixels() const { return nx*ny; }
	unsigned int numrays() const { return num_rays; }
	unsigned int get_pixelId(int x, int y) const { return (ny - y - 1)*nx + x; }
	float3 get_pixel_color(int x, int y) const {
		const unsigned int pixelId = get_pixelId(x, y);
		if (pixels[pixelId].done == 0) return make_float3(0, 0, 0);
		return h_colors[pixelId] / float(pixels[pixelId].done);
	}

	void prepare_kernel();
	void update_camera();

	bool color(int ray_idx);
	ray* generate_rays(ray* rays);
	void run_kernel();
	void compact_rays();

	void destroy();

	camera* cam;
	hitable_list *world;
	unsigned int nx;
	unsigned int ny;
	unsigned int ns;
	unsigned int max_depth;
	float min_attenuation;

	ray* h_rays;
	ray* d_rays;
	cu_hit* h_hits;
	cu_hit* d_hits;
	sphere* d_scene;
	unsigned int scene_size;

	pixel* pixels;
	float3* h_colors;

	clock_t kernel = 0;
	clock_t generate = 0;
	clock_t compact = 0;

	unsigned int num_rays;
private:
	sphere *light_shape;
	int* pixel_idx;
	sample* samples;
	inline void generate_ray(int ray_idx, int x, int y);
};