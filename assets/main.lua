-- lines demo

local draw = require("draw")
local mouse = require("input.mouse")
local text = require("text")
local graphics = require("graphics")
local app = require("delve.platform.App")
local Vec2 = require("delve.math.Vec2")

local title = "Delve Framework Lua!"

-- Lifecycle functions
-- The simple Lua module implements a Pico8 like API

-- Test some builtin types
local test_vec = Vec2.new(0.5, 110)
print("test_vec.x: " .. test_vec.x)
print("test_vec.y: " .. test_vec.y)
print("Vec2.one.x: " .. Vec2.one.x)
print("Vec2.one.y: " .. Vec2.one.y)

function _init()
	-- initial resolution
	display.set_resolution(256, 128)
	display.set_size(256, 128)

	black = 0
	dark_blue = 1
	dark_purple = 2
	dark_green = 3
	brown = 4
	dark_gray = 5
	light_gray = 6
	white = 7
	red = 8
	orange = 9
	yellow = 10
	green = 11
	blue = 12
	indigo = 13
	pink = 14
	peach = 15

	draw.clear(black)

	color = 0
	size = 0

	points = {}

	ramp = { 0, 5, 4, 9, 10, 15, 7, 7 }

	textures = assets.get_texture("assets/sprites/cat-anim-sheet.png")

	clear_color = white
end

function _update()
	local delta_time = app:getCurrentDeltaTime()

	local mouse_pos = mouse.position()
	table.insert(points, { x = mouse_pos[1], y = mouse_pos[2] })

	if #points > 200 then
		table.remove(points, 1)
	end
end

function _draw()
	local mouse_pos = mouse.position()
	local x = mouse_pos[1]
	local y = mouse_pos[2]

	draw.clear(white)

	local border = 5
	local box_x = 270
	local box_y = 225
	local box_width = 410
	local box_height = 48

	draw.filled_rectangle(box_x, box_y, box_width, box_height, dark_gray)
	draw.filled_rectangle(box_x + border, box_y + border, box_width - border * 2, box_height - border * 2, white)

	text.draw(title, (box_x + 48), (box_y + 17), black)
	graphics.blit(textures, 64, 0, 32, 32, x + 24, y + 24, 100, 100)

	draw.filled_circle(270, 400, 50, black)
	draw.circle(260, 380, 20, 4, white)

	if #points < 11 then
		return
	end

	for i = 1, #points - 10, 1 do
		local p0 = points[i]
		local p1 = points[i + 10]
		local c = i / (#points - 10)
		draw.line(p0.x, p0.y, p1.x, p1.y, 2.0, shade(c))
	end
end

function shade(t)
	local i = t * (#ramp - 1) + 1
	return ramp[i // 1]
end
