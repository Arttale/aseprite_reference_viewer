-- Reference image viewer extension for Aseprite.
--
-- Copyright (c) 2024 enmarimo
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software
-- and associated documentation files (the “Software”), to deal in the Software without
-- restriction, including without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
-- BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

function init(plugin)
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

-- Updates the scale factor with the given delta taking into account lower and upper limits.
function updateZoom(scale_factor, delta)
	scale_factor = scale_factor + delta
	if scale_factor < 0 then
		scale_factor = 0
	elseif scale_factor > 2 then
		scale_factor = 2
	end

	return scale_factor
end

function createViewer()
	local dlg = Dialog("Reference viewer")
	
	-- Active image, by default empty.
	-- We could try to store and restore the last opened image.
	local active_image = nil
	local active_image_filename = nil
	
	local fit_image = false
	
	local scale_factor = 1
	
	local image_pos = Point(0,0)
	local image_origin = Point(0,0)
	local mouse_origin = Point(0,0)
	local mouse_drag = false
	
	dlg:canvas{
		id="img_canvas",
		width=256,
		height=256,
		onpaint=function(ev)	
			if active_image ~= nil then
				local gc = ev.context
				gc.antialias = true
	
				if fit_image then
					-- Fit the image into the canvas: update scale_factor and restore
					-- the image position.
					-- Once done disable fit_image to make sure it is only called when
					-- requested.
					scale_factor = getFittingScale(gc, active_image)
					image_pos = Point(0,0)
					fit_image = false
				end
	
				-- Updates the value of the slider with the actual value of scale_factor.
				dlg:modify{id="scale_slider", value=scale_factor*100}

				local scaled_width = active_image.width * scale_factor
				local scaled_height = active_image.height * scale_factor
	
				local inverse_scale_factor = 1 / scale_factor

				local offset_x = image_pos.x + (gc.width - scaled_width) / 2
				local offset_y = image_pos.y + (gc.height - scaled_height) / 2

				local image = Image(gc.width, gc.height)	
				for i=1,gc.width do
					for j=1,gc.height do
						local image_x = offset_x + i * inverse_scale_factor
						local image_y = offset_y + j * inverse_scale_factor
						if image_x < active_image.width and image_y < active_image.height and
						   image_x > 0 and image_y > 0 then
							image:drawPixel(i, j, active_image:getPixel(image_x, image_y))
						end
					end
				
				gc:drawImage(
					image, 0, 0, image.width, image.height,
					0, 0, image.width, image.height
				)
				end
			end
		end,
		onwheel=function(ev)
			-- Update the scale_factor when using the mouse wheel.
			-- Tested on a laptop it works with deltaY, it should be tested on actual mouse.
			local wheel_factor = 0.05
			if ev.deltaY > 0 then
				scale_factor = updateZoom(scale_factor, -wheel_factor)
			else
				scale_factor = updateZoom(scale_factor, wheel_factor)
			end
	
			-- Redraw the canvas with the updated scale_factor.
			dlg:repaint()
		end,
		-- touch works weird, for now disable it.
		--ontouchmagnify=function(ev)
		--	scale_factor = zoom(scale_factor, ev.magnification)
		--	dlg:repaint()
		--end,
		onmousedown=function(ev)
			mouse_drag = true
			mouse_origin = Point(ev.x, ev.y)
			image_origin = image_pos
		end,
		onmouseup=function(ev)
			mouse_drag = false
		end,
		onmousemove=function(ev)
			if mouse_drag then
				local mouse = Point(ev.x, ev.y)
				local dpos = Point((mouse.x - mouse_origin.x) / scale_factor, (mouse.y - mouse_origin.y) / scale_factor)
				image_pos = image_origin - dpos
				dlg:repaint()
			end
		end
	}
	dlg:slider{
		id="scale_slider",
		min=0,
		max=200,
		value=100,
		visible=false,
		onchange=function()
			scale_factor = dlg.data.scale_slider / 100
			dlg:repaint()
		end
	}
	dlg:button{
		id="fit_button",
		text="Fit",
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
		onchange=function()
			-- When the file widget changes we want to open the selected image and draw it on
			-- the canvas.
			-- TODO: Check the file is actually an image.
	
			local image_filename = dlg.data.img_file
			-- Print used for testing.
			-- print("Image: " .. image_file)
	
			-- If the image changed, update it.
			-- TODO: Is this check really needed?
			if image_filename ~= active_image_filename then
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
end
