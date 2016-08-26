class Camera
	
	attr_reader :zoom, :offset
	#attr_accessor :offset
	
	def initialize(window:, offset:, zoom:)
		@window = window
		@offset = offset
		@zoom = zoom
		
		@window.on_button_down {|obj,id| button_down(id)}
		@window.on_button_up {|obj,id| button_up(id)}
		
		@offset_speed = Vector[0.0,0.0]
		@animations = []
	end
	
	def update
		
		if @animations.empty?
			
			# drag and drop
			unless @mouse_pressed.nil?
				mouse = Vector[@window.mouse_x, @window.mouse_y]		
				if mouse != @mouse_pressed
					unlock
					@offset += mouse - @mouse_pressed
					@mouse_pressed = mouse
				end
			end
			
			@offset -= @zoom * @offset_speed * DT
			
			if @locked
				@offset = - @locked.position * @zoom + Vector[@window.width, @window.height]/2
			end
			
		else
			
			@animations.first.update
			@offset = @animations.first.offset
			@zoom = @animations.first.zoom
			
			@animations.shift if @animations.first.finished?

		end
	end
	
	def lock_and_zoom(spaceobject)
		@locked = spaceobject
		@offset_speed = spaceobject.velocity / LENGTH_SCALE
		
		next_offset_speed = spaceobject.velocity / LENGTH_SCALE
		end_zoom = @window.height / (3 * @locked.radius / LENGTH_SCALE)
		end_offset = (- @locked.position * @zoom + Vector[@window.width, @window.height]/2 - @zoom * @offset_speed * DT * 30) * end_zoom/@zoom - Vector[@window.width, @window.height]/2 * (end_zoom/@zoom - 1.0)
		
		unless @animations.empty?
			# for now only support one animation, because: for now a click on overlaying buttons triggers locks to all of them (= ugly result)
			@animations = []
		end
		
		@animations << MoveAnimation.new(
			duration: 30,
			start_offset: @offset,
			end_offset: end_offset,
			start_zoom: @zoom,
			end_zoom: end_zoom,
			start_offset_velocity: @offset_speed,
			end_offset_velocity: next_offset_speed)
				
		@zoom = end_zoom
	end
	
	def lock(spaceobject)
		@locked = spaceobject
		
		next_offset_speed = spaceobject.velocity / LENGTH_SCALE
		end_offset = - @locked.position * @zoom + Vector[@window.width, @window.height]/2 - @zoom * next_offset_speed * DT * 30
		
		unless @animations.empty?
			# for now only support one animation, because: for now a click on overlaying buttons triggers locks to all of them (= ugly result)
			@animations = []
		end
		
		@animations << MoveAnimation.new(
			duration: 30,
			start_offset: @offset,
			end_offset: end_offset,
			start_zoom: @zoom,
			end_zoom: @zoom,
			start_offset_velocity: @offset_speed,
			end_offset_velocity: next_offset_speed)
		
		@offset_speed = next_offset_speed
	end
	
	def unlock
		@offset_speed = @locked.velocity / LENGTH_SCALE unless @locked.nil?
		@locked = nil
	end
	
	def match_speed(obj)
		unlock
		@offset_speed = obj.velocity / LENGTH_SCALE
	end
	
	def zoom_relative(zoom_factor)
		if (10**(-7)..1800).include? @zoom * zoom_factor
			@zoom *= zoom_factor
			@offset = @offset * zoom_factor - Vector[@window.width * (@window.mouse_x / @window.width),@window.height * (@window.mouse_y / @window.height)] * (zoom_factor - 1.0)

=begin
			end_offset = @offset * zoom_factor - Vector[@window.width * (@window.mouse_x / @window.width),@window.height * (@window.mouse_y / @window.height)] * (zoom_factor - 1.0)
			
			@animations << MoveAnimation.new(
				duration: 10,
				start_offset: @offset,
				end_offset: end_offset,
				start_zoom: @zoom,
				end_zoom: @zoom *= zoom_factor,
				start_offset_velocity: @offset_speed,
				end_offset_velocity: @offset_speed)
=end # still problems with it
			
		end
	end
	
	def button_down(id)
		case id
		when Gosu::MsWheelUp
			self.zoom_relative(ZOOM_FACTOR)
		when Gosu::MsWheelDown
			self.zoom_relative(1.0/ZOOM_FACTOR)
		when Gosu::MsLeft
			@mouse_pressed = Vector[@window.mouse_x, @window.mouse_y]
		end if @animations.empty?	# block input during animations
	end
	
	def button_up(id)
		case id
		when Gosu::MsLeft
			@mouse_pressed = nil
		end if @animations.empty? # block input during animations
	end
	
end



class MoveAnimation

	attr_reader :offset, :start_offset, :end_offset
	attr_reader :zoom, :start_zoom, :end_zoom
	
	def initialize(duration:, start_offset:, end_offset:, start_zoom:, end_zoom:, start_offset_velocity: Vector[0,0], end_offset_velocity: Vector[0,0])
		@duration = duration
		
		@offset = @start_offset = start_offset
		@end_offset = end_offset
		
		@zoom = @start_zoom = start_zoom
		@end_zoom = end_zoom
		
		@start_offset_velocity = start_offset_velocity
		@end_offset_velocity = end_offset_velocity
		
		@counter = 0
	end
		
	def update
		@counter += 1
		t = @counter.to_f/@duration
		
		# offset animation
		#@offset = @start_offset + (@end_offset - @start_offset) * Math.exp(1-1/(1-(t-1)**2))
		moved_start_offset = @start_offset - @end_zoom * @start_offset_velocity * @duration * DT
		
		@offset = @start_offset + (@end_offset - moved_start_offset) * Math.exp(1-1/(1-(t-1)**2)) - @start_offset_velocity * @zoom * @duration * DT * t
		
		#		+ @start_offset_velocity * t * (t-1) + @end_offset_velocity * (t**2-1)/2
		#@offset = @start_offset * (1-t) + @end_offset * t + @start_offset_velocity * t*(1-t) + @end_offset_velocity * ( t**2 - 1)/2
		
		# zoom animation
		@zoom = @start_zoom + (@end_zoom - @start_zoom) * Math.exp(1-1/(1-(t-1)**2))
	end
	
	def finished?
		@counter >= @duration
	end
end
