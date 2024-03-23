package font_renderer 

import "core:fmt"
import "core:time"
import "core:mem"
import glm "core:math/linalg/glsl"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import "core:os"
import tt "vendor:stb/truetype"
import "core:log"
import "vendor:stb/image"

TextVertex :: struct {
	pos: glm.vec2,
	uv: glm.vec2,
}

FontRenderer :: struct {
	program: u32,
	uniforms: gl.Uniforms,
	vao, vbo, ebo: u32,
	vertices: [dynamic]TextVertex,
	indices: [dynamic]u16,
	texture: u32,
	cdata: []tt.bakedchar,
	font_info: FontInfo,
	baked_texture_size: i32
}

FontInfo :: struct {
	filename: string,
	pixel_height: f32,
	first_char, num_chars: i32,
}


FileReadFailed :: struct {
	filename: string
}
BitmapTooSmall :: struct {}
ShaderFailedToLoad :: struct {}

InitError :: union {
	mem.Allocator_Error,
	FileReadFailed,
	BitmapTooSmall,
	ShaderFailedToLoad
}
font_renderer_init :: proc(using fr: ^FontRenderer, info: FontInfo, baked_texture_size_param := i32(512)) -> (error: InitError) {

	font_info = info
	baked_texture_size = baked_texture_size_param
	ttf_buffer, read_ok := os.read_entire_file_from_filename(info.filename)
	if !read_ok {
		return FileReadFailed{info.filename}
	}
	defer delete(ttf_buffer)

	temp_bitmap := make([]u8, baked_texture_size*baked_texture_size) or_return
	defer delete(temp_bitmap)

	cdata = make([]tt.bakedchar, info.num_chars) or_return
	a := tt.BakeFontBitmap(
		data = raw_data(ttf_buffer),
		offset = 0,
		pixel_height = info.pixel_height,
		pixels=raw_data(temp_bitmap),
		pw = baked_texture_size,
		ph = baked_texture_size,
		first_char = info.first_char,
		num_chars = info.num_chars,
		chardata = raw_data(cdata),
	) 
	if a < 1 {
		return BitmapTooSmall{}
	}

	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, baked_texture_size, baked_texture_size, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(temp_bitmap))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

	program_ok: bool;
	program, program_ok = gl.load_shaders_source(vert_glsl, frag_glsl) 
	if !program_ok {
		return ShaderFailedToLoad{}
	}

	gl.UseProgram(program)
	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false,
		size_of(TextVertex), offset_of(TextVertex, pos))
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false,
		size_of(TextVertex), offset_of(TextVertex, uv))

	vertices = make([dynamic]TextVertex) or_return
	indices = make([dynamic]u16) or_return
	return nil
}



font_renderer_draw_text :: proc(using fr: ^FontRenderer, text: string, x,y: f32) {
	left_margin := x
	x, y := x, y
	for c in text {
		if c == '\n' {
			x = left_margin
			y += font_info.pixel_height
		} else if c == '\t' {
			x += 40
			continue;
		} else if i32(c) < font_info.first_char || i32(c) >= font_info.first_char + font_info.num_chars {
			continue;
		}
		q: tt.aligned_quad
		tt.GetBakedQuad(raw_data(cdata), baked_texture_size, baked_texture_size, i32(c)-font_info.first_char, &x, &y, &q, true)
		using q
		tl := TextVertex{ {x0, y0}, {s0, t0} }
		bl := TextVertex{ {x0, y1}, {s0, t1} }
		br := TextVertex{ {x1, y1}, {s1, t1} }
		tr := TextVertex{ {x1, y0}, {s1, t0} }
		i := [?]u16{0, 1, 2, 2, 3, 0} + u16(len(vertices))
		append_elems(&indices, ..i[:])
		append(&vertices, tl, bl, br, tr)
	}
}

font_renderer_render :: proc(using fr: ^FontRenderer, screen_width, screen_height: f32) {
	gl.UseProgram(program)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
	gl.ARRAY_BUFFER,
	len(vertices)*size_of(vertices[0]),
	raw_data(vertices),
	gl.DYNAMIC_DRAW,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)*size_of(indices[0]), 
		raw_data(indices), gl.DYNAMIC_DRAW)
	
	gl.Uniform2f(uniforms["screen_size"].location, screen_width, screen_height)
	
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_SHORT, nil)
	clear(&vertices)
	clear(&indices)
}

font_renderer_draw_baked_bitmap :: proc(using fr: ^FontRenderer, width, height: f32) {
	tl := TextVertex{ {0, 0}, {0, 0} }
	bl := TextVertex{ {0, height}, {0, 1} }
	br := TextVertex{ {width, height}, {1, 1} }
	tr := TextVertex{ {width, 0}, {1, 0} }
	i := [?]u16{0, 1, 2, 2, 3, 0} + u16(len(vertices))
	append_elems(&indices, ..i[:])
	append(&vertices, tl, bl, br, tr)
}

font_renderer_delete :: proc(using fr: ^FontRenderer) {
	gl.DeleteVertexArrays(1, &vao)
	gl.DeleteBuffers(1, &vbo)
	gl.DeleteBuffers(1, &ebo)
	gl.DeleteProgram(program)
	gl.DeleteTextures(1, &texture)
	delete(vertices) 
	delete(indices) 
	delete(uniforms)
	delete(cdata)
}

frag_glsl := `
#version 330 core

out vec4 o_color;
in vec2 uv;
uniform sampler2D tex;

void main() {
	vec4 c = texture(tex, uv);
	o_color = vec4(1.0, 1.0, 1.0, c.r);
}
`

vert_glsl := `
#version 330 core

layout(location=0) in vec2 a_position;
layout(location=1) in vec2 a_uv;

uniform vec2 screen_size;

out vec2 uv;

void main() {
	vec2 pos = a_position / screen_size;
	pos.y = 1.0 - pos.y;
	pos *= 2.0;
	pos -= 1.0;
	gl_Position = vec4(pos, 0.6, 1.0); 
	uv = a_uv;
}
`



