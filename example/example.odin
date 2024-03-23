package example 

import "core:fmt"
import "core:time"
import glm "core:math/linalg/glsl"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import "core:os"
import tt "vendor:stb/truetype"
import "core:log"
import "vendor:stb/image"
import fr "../text-renderer"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 500
GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

main :: proc() {

	// SDL and OpenGL initialization
	SDL.Init({.VIDEO})
	defer SDL.Quit()
	
	window := SDL.CreateWindow( "Font Renderer Demo", SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, {.OPENGL},)
	assert(window != nil)
	defer SDL.DestroyWindow(window)

	SDL.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(SDL.GLprofile.CORE))
	SDL.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, GL_VERSION_MAJOR)
	SDL.GL_SetAttribute(.CONTEXT_MINOR_VERSION, GL_VERSION_MINOR)

	gl_context := SDL.GL_CreateContext(window)
	defer SDL.GL_DeleteContext(gl_context)

	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, SDL.gl_set_proc_address)

	gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
	gl.ClearColor(0.5, 0.7, 1.0, 1.0)

	info := fr.FontInfo{"LiberationSans-Regular.ttf", 32, 32, 96}

	/* Other possible font options
	//info := FontInfo{"Virgil.ttf", 32, 32, 200}
	//info := FontInfo{"ShlomoStam.ttf", 16, '\u0590', 200}
	*/

	font_renderer: fr.FontRenderer 
	font_error := fr.font_renderer_init(&font_renderer, info)
	if font_error != nil {
		fmt.eprintln(font_error)
		return
	}
	defer fr.font_renderer_delete(&font_renderer)

	event: SDL.Event
	start_tick := time.tick_now()
	key_down : map[SDL.Keycode] bool

	fs := #load("example.odin", string)
	loop: for {
		duration := time.tick_since(start_tick)
		t := f32(time.duration_seconds(duration))
		for SDL.PollEvent(&event) {
			#partial switch event.type {
			case .KEYDOWN:
				key_down[event.key.keysym.sym] = true
				#partial switch event.key.keysym.sym {
				case .ESCAPE:
					break loop
				}
			case .KEYUP:
				key_down[event.key.keysym.sym] = false
			case .QUIT:
				break loop
			}	
		}
		vary :: proc(t, a, b: f32) -> f32 {
			return a + (glm.sin(t) + 1)/2 * (b-a) 
		}

		//font_renderer_draw_text(&font_renderer, "שדגשד גשדשדג גדכעגכעקדכ", 400, vary(t, 200, 300))
		fr.font_renderer_draw_text(&font_renderer, "Lorem ipsum dolor sit amet", 400, vary(t, 200, 300))
		fr.font_renderer_draw_text(&font_renderer, "Quid omnibus", vary(t, 200,300), vary(t, 300, 200))
		fr.font_renderer_draw_text(&font_renderer, string(fs), 400, vary(t,0, 200) )
		fr.font_renderer_draw_baked_bitmap(&font_renderer, WINDOW_WIDTH, WINDOW_HEIGHT)
		x := vary(t, 100,0)
		y := vary(t, 0, WINDOW_HEIGHT)
		fr.font_renderer_draw_text(&font_renderer, fmt.tprint("y =", y), x, y )

		gl.Clear(gl.COLOR_BUFFER_BIT)
		fr.font_renderer_render(&font_renderer, WINDOW_WIDTH, WINDOW_HEIGHT)
		SDL.GL_SwapWindow(window)
		free_all(context.temp_allocator)
	}


}


