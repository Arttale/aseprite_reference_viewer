-- Reference image viewer extension for Aseprite.
--
-- Copyright (c) 2024 enmarimo MIT License

local allowed_filetypes = {"png", "jpg", "jpeg", "bmp"}
isPlugin = false
debug_value = "test"

function init(plugin)
	isPlugin = true
	plugin:newMenuSeparator{
		group="view_controls"
	}
	plugin:newCommand{
		id="reference_viewer",
		title="Reference Viewer",
		group="view_controls",
		onclick=function()
			createViewer()
		end
	}
end
function exit(plugin)
end

-- Computes the scale factor that is needed to fit the Image into the GraphicsContext.
function getFittingScale(gc, image)
	local factor = gc.width / image.width
	local scaled_height = image.height * factor

	if(scaled_height > gc.height) then
		factor = gc.height / image.height
	end

	return factor
end

-- check if file is valid
function isValidFile(path)
	if not app.fs.isFile(path) then
		return false
	end
	local ext = string.lower(app.fs.fileExtension(path))
	for _, filetype in ipairs(allowed_filetypes) do
		if ext == filetype then
			return true
		end
	end
	return false
end

function createViewer()
	local dlg = Dialog("Reference viewer - v1.2")

	-- Active image, by default empty.
	-- We could try to store and restore the last opened image.
	local active_image = nil
	local active_image_filename = nil

	local fit_image = false

	local scale_factor = 1.0
	local inv_scale_factor = 1.0

	local image_pos = { x = 0.0, y = 0.0 }
	local image_origin = { x = 0.0, y = 0.0 }
	local mouse_origin = Point(0,0)
	local mouse_drag = false

	local function drawBackground(gc)
		local docPref = app.preferences.document(app.sprite)
		-- transparent background color
		local color_a = docPref.bg.color1
		local color_b = docPref.bg.color2

		local inner_border_color = app.theme.color.background
		local outer_border_color = app.theme.color.editor_sprite_border
		local inner_accent_color = app.theme.color.editor_face
		local outer_accent_color = app.theme.color.face

		local size = scale_factor*32

		--draw border function
		local function fillBorder(borderColor,offsetBorder,edge_roundness,thickness)
			local canvas_round_rect = Rectangle(offsetBorder, offsetBorder, gc.width-thickness-offsetBorder*2, gc.height-thickness-offsetBorder*2)

			gc:beginPath()
			gc.color = borderColor
			gc.strokeWidth = thickness
			gc:roundedRect(canvas_round_rect, edge_roundness, edge_roundness)
			gc:stroke()
		end
		local function fillPixel(x,y)
			gc:fillRect(Rectangle(x, y, 1, 1))
		end
		-- Draw RoundRect Zone
		local offset_clipping_border = 2
		local canvas_round_rect_small = Rectangle(offset_clipping_border, offset_clipping_border, gc.width-2-offset_clipping_border*2, gc.height-2-offset_clipping_border*2)

		local pass_threshold_zoom = size<3
		gc.color = docPref.bg.color1
		if pass_threshold_zoom then
			local c1 = Color(docPref.bg.color1)
			local c2 = Color(docPref.bg.color2)

			local R1, G1, B1 = c1.red, c1.green, c1.blue
			local R2, G2, B2 = c2.red, c2.green, c2.blue

			local avgColor = Color{
			r = math.sqrt((R1^2 + R2^2) / 2),
			g = math.sqrt((G1^2 + G2^2) / 2),
			b = math.sqrt((B1^2 + B2^2) / 2)
			}

			gc.color = avgColor
		end
		-- Draw filled rounded rect
		gc:beginPath()
		gc:roundedRect(canvas_round_rect_small, 0, 0)
		gc:fill()
		-- Draw fill Border
		fillBorder(inner_border_color,1,0,2)
		-- Draw outer Border
		fillBorder(outer_border_color,0,2,1)
		-- Draw inner Border
		fillBorder(outer_border_color,2,2,1)
		-- draw accents
		gc.color = inner_accent_color
		fillPixel(2,2)
		fillPixel(gc.width-3,2)
		fillPixel(2,gc.height-3)
		fillPixel(gc.width-3,gc.height-3)
		gc.color = outer_accent_color
		fillPixel(1,1)
		fillPixel(gc.width-2,1)
		fillPixel(1,gc.height-2)
		fillPixel(gc.width-2,gc.height-2)

		-- Now rebuild the path for clipping
		gc:beginPath()
		gc:roundedRect(canvas_round_rect_small, 0, 0)
		gc:clip()

		-- Background Grid
		if not pass_threshold_zoom then
			local offsetx = (image_pos.x*scale_factor)%(size*2)
			local offsety = (image_pos.y*scale_factor)%(size*2)
			gc.color = color_b
			for i=0, (gc.width/size)+2, 1 do
				for j=0, (gc.height/size)+2, 1 do
					if((i+j) % 2 == 1) then
						gc:fillRect(Rectangle(i * size - offsetx, j*size - offsety, size, size))
					end
				end
			end
		end
		gc.color = Color(255, 255, 255, 255)
	end

	dlg:canvas{
		id="img_canvas",
		width=256,
		height=256,
		onpaint=function(ev)
			drawBackground(ev.context)
			if active_image ~= nil then
				local gc = ev.context
				gc.antialias = true

				local fit_scale = getFittingScale(gc, active_image)

				if fit_image then
					-- Fit the image into the canvas: update scale_factor and restore
					-- the image position.
					-- Once done disable fit_image to make sure it is only called when
					-- requested.
					scale_factor = fit_scale

					if scale_factor < 0.01 then
						scale_factor = 0.01
					end

					inv_scale_factor = 1 / scale_factor

					image_pos = { x = 0.0, y = 0.0 }
					--reset background
					drawBackground(ev.context)
					fit_image = false
				end

				-- Updates the value of the slider with the actual value of scale_factor.
				dlg:modify{id="scale_slider", value=scale_factor*100}

				local image

				-- When we zoom-in (scale_factor > fit_scale) we only
				-- see a part of the image. We only copy what is visible
				-- and scale it to fit the window. This is so that we don't have tons of lag.
				-- We also scale and translate the final result so that we can get subpixel zoom.
				-- When we zoom-out the image is fully visible, so
				-- we copy the whole image and scale it to the desired
				-- scale.
				if scale_factor > fit_scale then
					--crop - get pixel crop position
					local crop_x = math.floor(image_pos.x)
					local crop_y = math.floor(image_pos.y)
					local crop_w = math.ceil(gc.width * inv_scale_factor)+1
					local crop_h = math.ceil(gc.height * inv_scale_factor)+1
					
					-- get pixel offset for zoom and translate
					local crop_x_dif= image_pos.x - crop_x
					local crop_y_dif= image_pos.y - crop_y
					
					local crop_w_dif= crop_w / (gc.width * inv_scale_factor)
					local crop_h_dif= crop_h / (gc.height * inv_scale_factor)
					image = Image(
						active_image,
						Rectangle(crop_x, crop_y, crop_w, crop_h)
					)
					if image ~= nil then
						--resize crop image adjusted for subpixel zoom
						--set to nearest so that we can see actual pixels, since this is a pixel art application afterall
						image:resize{
							width = gc.width * crop_w_dif,
							height = gc.height * crop_h_dif,
							method = 'nearest'
						}
						--draw content with translated subpixel offset offset
						gc:drawImage(
							image, 0, 0, image.width, image.height,
							-crop_x_dif * scale_factor,
							-crop_y_dif * scale_factor,
							image.width, image.height
						)
					end
				else
					image = Image(active_image)
					if image ~= nil then
						--bilinear when we zoom out
						image:resize{
							width=active_image.width * scale_factor,
							height=active_image.height * scale_factor,
							method='nearest'
						}

						-- Position has to be negative or it doesn't work as
						-- expected.
						-- TODO: Check why position is negative.
						--       This might need a refactor to make code
						--       easier to understand.
						gc:drawImage(
							image, 0, 0, image.width, image.height,
							-image_pos.x * scale_factor,
							-image_pos.y * scale_factor,
							image.width, image.height
						)
					end
				end
			end
		end,
		onwheel=function(ev)
			-- Update the scale_factor when using the mouse wheel.
			-- Tested on a laptop it works with deltaY, it should be tested on actual mouse.
			local wheel_factor = 0.05
			-- Get the relative position of mouse respect to the image.
			-- I would expect dx should be (ev.x - image_pos.x), but image_pos.x seems inverted
			-- (positive values when image goes to the left and negative to the right) so it has
			-- to be inverted here to work as expected.
			local dx = ev.x * inv_scale_factor + image_pos.x
			local dy = ev.y * inv_scale_factor + image_pos.y

			if ev.deltaY > 0 then
				scale_factor = scale_factor * (1 - wheel_factor)
			else
				scale_factor = scale_factor * (1 + wheel_factor)
			end

			-- Keep the relative position between the mouse and image. This way, when we zoom the
			-- image it will keep centered at the point we are zooming.
			inv_scale_factor = 1 / scale_factor
			image_pos.x = -ev.x * inv_scale_factor + dx
			image_pos.y = -ev.y * inv_scale_factor + dy

			-- Redraw the canvas with the updated scale_factor.
			dlg:repaint()
		end,
		-- touch works weird, for now disable it.
		--ontouchmagnify=function(ev)
		--	scale_factor = zoom(scale_factor, ev.magnification)
		--	dlg:repaint()
		--end,
		onmousedown=function(ev)
			-- When using the eyedropper (color-picker) get the color of the
			-- clicked pixel on the image.
			-- Otherwise, prepare to move the image.
			if app.tool.id == "eyedropper" then
				if active_image ~= nil then
					if scale_factor >= 0.01 then

						local pixel = active_image:getPixel(
							ev.x * inv_scale_factor + image_pos.x,
							ev.y * inv_scale_factor + image_pos.y
						);

						if ev.button == MouseButton.LEFT then
							app.fgColor = Color(pixel)
						elseif ev.button == MouseButton.RIGHT then
							app.bgColor = Color(pixel)
						end
					end
				end
			else
				mouse_drag = true
				mouse_origin = Point(ev.x, ev.y)
				image_origin = image_pos
			end
		end,
		onmouseup=function(ev)
			mouse_drag = false
		end,
		onmousemove=function(ev)
			if mouse_drag then
				local mouse = Point(ev.x, ev.y)
				local dpos = {
					x = (mouse.x - mouse_origin.x) * inv_scale_factor,
					y = (mouse.y - mouse_origin.y) * inv_scale_factor
				}
				image_pos = {
					x = image_origin.x - dpos.x,
					y = image_origin.y - dpos.y
				}
				dlg:repaint()
			end
		end,
		onkeydown=function(ev)
			if ev.ctrlKey then
				-- When Ctrl-V, load the clipboard image.
				-- Stop propagation of the event to prevent the image
				-- being pasted on the main canvas.
				ev:stopPropagation()

				if ev.code == "KeyV" then
					if app.apiVersion >= 32 and app.clipboard.image ~= nil then
						active_image = app.clipboard.image

						-- When an image is loaded, show the hidden controls
						dlg:modify{id="scale_slider", visible=true}
						dlg:modify{id="fit_button", visible=true}

						-- redraw the canvas
						dlg:repaint()
					end
				end
			end
		end
	}
	--for debugging purposes
	dlg:label{
		id="debug_text",
		label="debug: ",
		text="test",
		visible=false
	}
	dlg:slider{
		id="scale_slider",
		min=0,
		max=1000,
		value=100,
		visible=false,
		onchange=function()
			scale_factor = dlg.data.scale_slider / 100

			if scale_factor < 0.01 then
				scale_factor = 0.01
			end

			inv_scale_factor = 1 / scale_factor

			dlg:repaint()
		end
	}
	dlg:button{
		id="fit_button",
		text="Fit image to view",
		visible=false,
		onclick=function()
			fit_image = true
			dlg:repaint()
		end
	}
	dlg:file{
		id="img_file",
		open=true,
		save=false,
		filetypes=allowed_filetypes,
		onchange=function()
			-- When the file widget changes we want to open the selected image and draw it on
			-- the canvas.

			local image_filename = dlg.data.img_file
			-- check if file is valid, this is to check if the file path has been swapped out in the menu

			if isValidFile(image_filename) then
				active_image_filename = image_filename
				active_image = Image{fromFile=active_image_filename}

				-- When an image is loaded, show the hidden controls
				dlg:modify{id="scale_slider", visible=true}
				dlg:modify{id="fit_button", visible=true}

				-- redraw the canvas
				dlg:repaint()
			end
		end
	}

	dlg:show{wait=false}
	dlg:repaint()
end

--run after 0.05 second delay if not extension
local scriptTimer = Timer{
  interval = 0.05,
  ontick = function()
    if not isPlugin then
      createViewer()
    end
    stopTimer()
  end
}
function stopTimer()
	scriptTimer:stop()
end
scriptTimer:start()
