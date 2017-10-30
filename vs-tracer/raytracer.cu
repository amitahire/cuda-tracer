#include <iostream>
#include <float.h>
#include <fstream>
#include <algorithm>
#include <ctime>
#include <SDL.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

// For the CUDA runtime routines (prefixed with "cuda_")
//#include <cuda_runtime.h>
//#include <cuda_profiler_api.h>
//#include <helper_cuda.h>

#include "sphere.h"
#include "hitable_list.h"
#include "renderer.h"
#include "utils.h"
#include "material.h"

using namespace std;

struct window {
	SDL_Window* w_screen;
	SDL_Renderer* w_renderer;
	SDL_Texture* w_texture;
	unsigned int *w_pixels;
	int w_nx;
	int w_ny;

	bool quit;
	bool mouse_drag;

	float theta = 80 * M_PI / 180;
	float phi = 45 * M_PI / 180;
	const float delta = 1 * M_PI / 180;

	renderer& w_r;
	camera *w_cam;

	window(int nx, int ny, float t, float p, renderer &r, camera *cam): w_nx(nx), w_ny(ny), w_r(r), w_cam(cam), theta(t), phi(p) {
		SDL_Init(SDL_INIT_VIDEO);

		w_screen = SDL_CreateWindow("Voxel Tracer (rendering)", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, nx, ny, 0);
		w_renderer = SDL_CreateRenderer(w_screen, -1, 0);
		w_texture = SDL_CreateTexture(w_renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STATIC, nx, ny);
		w_pixels = new unsigned int[nx*ny];

		cam->look_from(theta, phi);
		w_r.update_camera();
	}

	void destroy() {
		SDL_DestroyTexture(w_texture);
		SDL_DestroyRenderer(w_renderer);
		SDL_DestroyWindow(w_screen);
		delete[] w_pixels;

		SDL_Quit();
	}

	void update_pixels() {
		for (int x = 0; x < w_nx; x++)
		{
			for (int y = 0; y < w_ny; y++)
			{
				float3 col = w_r.get_pixel_color(x, y);
				col = make_float3(sqrtf(col.x), sqrtf(col.y), sqrtf(col.z));
				int ir = min(255, int(255.99*col.x));
				int ig = min(255, int(255.99*col.y));
				int ib = min(255, int(255.99*col.z));
				w_pixels[(w_ny - 1 - y)*w_nx + x] = (ir << 16) + (ig << 8) + ib;
			}
		}
		SDL_UpdateTexture(w_texture, NULL, w_pixels, w_nx * sizeof(unsigned int));
		//SDL_RenderClear(w_renderer);
		SDL_RenderCopy(w_renderer, w_texture, NULL, NULL);
		SDL_RenderPresent(w_renderer);
	}

	void poll_events() {
		SDL_Event event;
		while (SDL_PollEvent(&event)) {
			switch (event.type) {
			case SDL_QUIT:
				quit = true;
				break;
			case SDL_MOUSEMOTION:
				if (mouse_drag) {
					int mx = event.motion.xrel;
					int my = event.motion.yrel;
					theta += -my*delta;
					if (theta < delta) theta = delta;
					if (theta >(M_PI_2 - delta)) theta = M_PI_2 - delta;
					phi += -mx*delta;
					w_cam->look_from(theta, phi);
					printf("look_from(%f, %f)\n", theta, phi);
					w_r.update_camera();
				}
				break;
			case SDL_MOUSEBUTTONDOWN:
				mouse_drag = true;
				break;
			case SDL_MOUSEBUTTONUP:
				mouse_drag = false;
				break;
			}
		}
	}

	void set_title(char *title) {
		SDL_SetWindowTitle(w_screen, title);
	}

	void wait_to_quit() {
		SDL_Event event;
		while (!quit) {
			SDL_WaitEvent(&event);
			quit = event.type == SDL_QUIT;
		}
	}
};

void only_lambertians(hitable_list **scene, camera **cam, sphere **light_shape, float aspect)
{
	const int palette[] = { 0xe65d3e, 0xf1a26d, 0xfeda4b, 0xfefba8 };
	const int palette_size = 5;
	int n = 500;
	sphere **list = new sphere*[n + 1];
	int i = 0;
	list[i++] = new sphere(make_float3(0, -1000, 0), 1000, make_lambertian(hex2float3(0x5b180c)));
	for (int a = -11; a < 11; a++) {
		for (int b = -11; b < 11; b++) {
			float choose_mat = drand48();
			float3 center = make_float3(a + 0.9*drand48(), 0.2, b + 0.9*drand48());
			if (length(center - make_float3(4, 0.2, 0)) > 0.9) {
				list[i++] = new sphere(center, 0.2, make_lambertian(hex2float3(palette[int(drand48()*(palette_size - 1))])));
			}
		}
	}

	list[i++] = new sphere(make_float3(-4, 1, 0), 1.0, make_lambertian(hex2float3(palette[int(drand48()*palette_size)])));
	list[i++] = new sphere(make_float3(0, 1, 0), 1.0, make_lambertian(hex2float3(palette[int(drand48()*palette_size)])));
	//sphere *glass = new sphere(float3(0, 1, 0), 1.0, make_dielectric(1.5));
	//list[i++] = glass;
	list[i++] = new sphere(make_float3(4, 1, 0), 1.0, make_lambertian(hex2float3(palette[int(drand48()*palette_size)])));
	sphere *light = new sphere(make_float3(10, 10, 10), .5, make_diffuse_light(make_float3(100, 100, 100)));
	list[i++] = light;

	//sphere *a[2];
	//a[0] = light;
	//a[1] = glass;
	//*light_shape = new hitable_list(a, 2);
	*light_shape = light;

	*scene = new hitable_list(list, i);
	*cam = new camera(make_float3(13, 2, 3), make_float3(0, 0, 0), make_float3(0, 1, 0), 20, aspect, 0.1, 10.0);
}

void random_scene(hitable_list **scene, camera **cam, sphere **light_shape, float aspect)
{
    int n = 500;
    sphere **list = new sphere*[n+1];
    list[0] =  new sphere(make_float3(0,-1000,0), 1000, make_lambertian(make_float3(0.5, 0.5, 0.5)));
    int i = 1;
    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            float choose_mat = drand48();
            float3 center = make_float3(a+0.9*drand48(),0.2,b+0.9*drand48());
            if (length(center- make_float3(4,0.2,0)) > 0.9) {
                if (choose_mat < 0.8) {  // diffuse
                    list[i++] = new sphere(center, 0.2, make_lambertian(make_float3(drand48()*drand48(), drand48()*drand48(), drand48()*drand48())));
                }
                else if (choose_mat < 0.95) { // metal
                    list[i++] = new sphere(center, 0.2,
                            make_metal(make_float3(0.5*(1 + drand48()), 0.5*(1 + drand48()), 0.5*(1 + drand48())),  0.5*drand48()));
                }
                else {  // glass
                    list[i++] = new sphere(center, 0.2, make_dielectric(1.5));
                }
            }
        }
    }

    list[i++] = new sphere(make_float3(0, 1, 0), 1.0, make_dielectric(1.5));
    list[i++] = new sphere(make_float3(-4, 1, 0), 1.0, make_lambertian(make_float3(0.4, 0.2, 0.1)));
    list[i++] = new sphere(make_float3(4, 1, 0), 1.0, make_metal(make_float3(0.7, 0.6, 0.5), 0.0));

	*light_shape = new sphere(make_float3(10, 10, 10), .5, make_diffuse_light(make_float3(200, 200, 100)));
		list[i++] = *light_shape;

	*scene = new hitable_list(list, i);
	*cam = new camera(make_float3(13, 2, 3), make_float3(0, 0, 0), make_float3(0, 1, 0), 20, aspect, 0.1, 10.0);
}

/**
 * Host main routine
 */
int main(int argc, char** argv)
{
	bool print_progress = false;
	bool write_image = true;
	bool show_window = false;

	const unsigned int scene_size = 500;
	const int nx = 600;
	const int ny = 300;
	const int ns = 100;
	hitable_list *world;
	camera *cam;
	sphere *light_shape;
	only_lambertians(&world, &cam, &light_shape, float(nx) / float(ny));

	const float theta = 1.221730;
	const float phi = 1.832596;
	cam->look_from(theta, phi);

	renderer r(cam, world, light_shape, nx, ny, ns, 50, 0.001);
	r.prepare_kernel();

	window *w;
	if (show_window) {
		w = new window(nx, ny, theta, phi, r, cam);
	}

    clock_t begin = clock();

	unsigned int iteration = 0;
	unsigned int total_rays = 0;
	bool rendering = true;
	while ((show_window && !w->quit) || (!show_window && r.numrays() > 0))
	{
		if (r.numrays() > 0) {
			total_rays += r.numrays();
			if (print_progress && iteration % 100 == 0)
			{
				cout << "iteration " << iteration << "(" << r.numrays() << " rays)\r";
				cout.flush();
			}

			// compute ray-world intersections
			r.run_kernel();
			// compact active rays
			r.compact_rays();
		} else if (rendering) {
			rendering = false;
			w->set_title("Voxel Tracer");
		}

		if (show_window) {
			w->update_pixels();
			w->poll_events();
			if (!rendering && r.numrays() > 0) {
				rendering = true;
				w->set_title("Voxel Tracer (rendering)");
			}
		}

		++iteration;

	}

    clock_t end = clock();
	printf("rendering %d rays, duration %.2f seconds\nkernel %.2f seconds\ngenerate %.2f seconds\ncompact %.2f seconds\n",
		total_rays,
		double(end - begin) / CLOCKS_PER_SEC,
		double(r.kernel) / CLOCKS_PER_SEC,
		double(r.generate) / CLOCKS_PER_SEC,
		double(r.compact) / CLOCKS_PER_SEC);
	cout.flush();

	if (show_window) {
		w->set_title("Voxel Tracer");
		w->wait_to_quit();
		w->destroy();
	}
  
	if (write_image) {
		// generate final image
/*
		ofstream image;
		image.open("picture.ppm");
		image << "P3\n" << nx << " " << ny << "\n255\n";
		unsigned int sample_idx = 0;
		for (int j = ny - 1; j >= 0; j--)
		{
			for (int i = 0; i < nx; ++i, sample_idx++)
			{
				float3 col = r.get_pixel_color(i, j);
				col = float3(sqrtf(col[0]), sqrtf(col[1]), sqrtf(col[2]));
				int ir = min(255, int(255.99*col.r()));
				int ig = min(255, int(255.99*col.g()));
				int ib = min(255, int(255.99*col.b()));

				image << ir << " " << ig << " " << ib << "\n";
			}
		}
*/
		char *data = new char[nx*ny * 3];
		int idx = 0;
		for (int y = ny-1; y >= 0; y--) {
			for (int x = 0; x < nx; x++) {
				float3 col = r.get_pixel_color(x, y);
				data[idx++] = min(255, int(255.99*col.x));
				data[idx++] = min(255, int(255.99*col.y));
				data[idx++] = min(255, int(255.99*col.z));
			}
		}
		stbi_write_png("picture.png", nx, ny, 3, (void*)data, nx * 3);
		delete[] data;
	}
	
	r.destroy();

    return 0;
}