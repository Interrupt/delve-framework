-- lines demo

local draw = require("draw")
local mouse = require("input.mouse")
local text = require("text")
local graphics = require("graphics")

function _init()
    -- initial resolution
    display.set_resolution(256, 128)
    display.set_size(256, 128);

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

    textures = assets.get_texture("font.gif")

    clear_color = white
end

function _update()
    local x, y = mouse.position()
    table.insert(points, { x = x, y = y })

    if #points > 200 then
        table.remove(points, 1)
    end
end

function _draw()
    local x, y = mouse.position()
    mouse.button(0)
    mouse.button(2)
    draw.clear(white)

    local border = 5
    local box_x = 270
    local box_y = 225
    local box_width = 410
    local box_height = 48

    draw.filled_rectangle(box_x, box_y, box_width, box_height, grey)
    draw.filled_rectangle(box_x + border, box_y + border, box_width - border * 2, box_height - border * 2, white)

    text.draw("hello zig, from lua!", (box_x + 48) / 2, (box_y + 17) / 2, black)
    graphics.blit(textures, 8, 0, 8, 8, x + 8, y + 8)
    graphics.blit(textures, 16, 0, 16, 16, x + 24, y + 24)

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
