require_relative 'ui/clickable.rb'
require_relative 'ui/overlay_text.rb'
require_relative 'particle.rb'

class Spaceobject < Particle
	include Clickable
	
	@@crosshairs = Gosu::Image.new("media/crosshairs.png")	# load them only once (not for every object)
	@@arrow = Gosu::Image.new("media/arrow.png")

	# creation helper
	def self.create_circular_satellite(carrier:, mass:, distance:, radius:0.0, image:nil, caption:"")
		# circular transversal velocity
		v = Math.sqrt(GRAV_CONST * (carrier.mass / distance))
		
		Spaceobject.new(
			window: carrier.window,
			mass: mass,
			radius: radius,
			position: carrier.position + Vector.basis(size: 2, index: 0) * distance / LENGTH_SCALE,
			velocity: carrier.velocity + Vector[0.0, v],
			image: image,
			caption: caption
		)
	end
	
	
	attr_accessor :show_caption, :show_history
	attr_reader :window, :caption
	
	# mass in kg
	# position in grid-units
	# velocity in kg/s
	# radius in km
	def initialize(window:, mass:, position:, velocity:, radius:0.0, image:nil, caption:"")
		super(mass, position, velocity)
		
		@window = window
		
		@caption = OverlayText.new(window, caption)
		@caption.on_mouse_click { |obj, id| trigger_mouse_click(id) }
		@caption.on_mouse_hover { |obj| trigger_mouse_hover } 
		@caption.on_mouse_unhover { |obj| trigger_mouse_unhover }
		
		@crosshairs_position = Vector[0,0]
		@arrow_position = Vector[0,0]
		@arrow_angle = 0.0
		
		@show_caption = false
		
		@radius = radius / LENGTH_SCALE
		
		@image = Gosu::Image.new(image, tileable: true) unless image.nil?
		@image_position = Vector[0,0]

	end

	def update
		@caption.update
		
		d_position = @window.cam.offset + self.position * @window.cam.zoom	# drawing coordinates
		
		# calculate positions of arrows and text
		# and arrow angle
		if @show_caption
			
			if self.visible?
				
				@crosshairs_position = d_position - Vector[@@crosshairs.width,@@crosshairs.height]/4 # 4 because 0.5 scale
				@caption.position = d_position + Vector[0.0, @@crosshairs.height/2]
				
			else
				
				cam_pos = -@window.cam.offset + Vector[@window.width,@window.height]/2
				rel = (self.position * @window.cam.zoom - cam_pos).normalize
				
				@arrow_angle = 90 + Math::acos(rel.dot(Vector[0,-1])) / Math::PI * 180.0
				@arrow_angle = 180-@arrow_angle if Matrix.columns([[0,-1], rel.to_a]).det < 0
				
				# set the arrow to the border of the screen
				#
				rel_scaled = 
					if rel[0].abs/rel[1].abs >= @window.width.to_f/@window.height.to_f
						rel / rel[0].abs * (@window.width/2-50)
					else
						rel / rel[1].abs * (@window.height/2-50)
					end
				
				@arrow_position = Vector[@window.width, @window.height]/2 + rel_scaled
				@caption.position = Vector[@window.width, @window.height]/2 + rel_scaled.normalize * (rel_scaled.norm - 30 - @caption.diameter(@arrow_angle)/2)
			end
		end
		
		unless @image.nil?
			d_height = d_width = @radius*2 * @window.cam.zoom
			@image_position = d_position - Vector[d_width, d_height] / 2
		end
	end
	
	def draw
		
		if @show_caption
			if self.visible? # draw crosshairs
				@@crosshairs.draw(*@crosshairs_position.to_a , ZOrder::IND, 0.5, 0.5)
			else # otherwise draw arrow
				@@arrow.draw_rot(*@arrow_position.to_a, ZOrder::IND, @arrow_angle, 0.5, 0.5, 0.05, 0.05)
			end

			@caption.draw
		end
		
		unless @image.nil?
			d_height = d_width = @radius*2 * @window.cam.zoom
			
			@image.draw(*@image_position.to_a, ZOrder::SOBJECT, d_width/@image.width, d_height/@image.height)
		end

	end
	
	def visible?
		(-window.cam.offset[0]..-@window.cam.offset[0] + @window.width).superset?(self.position[0]*@window.cam.zoom - (@@crosshairs.width/2)..self.position[0]*@window.cam.zoom + (@@crosshairs.width/2)) && (-@window.cam.offset[1]..-@window.cam.offset[1] + @window.height).superset?(self.position[1]*@window.cam.zoom - (@@crosshairs.height/2)..self.position[1]*@window.cam.zoom + (@@crosshairs.height/2))
	end

	def mouse_hover?
		@caption.mouse_hover?
	end
		
	def radius
		@radius * LENGTH_SCALE
	end

end


class Range
	def superset?(range)
		self.min <= range.min && self.max >= range.max
	end
end
