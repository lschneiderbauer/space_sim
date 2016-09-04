require_relative 'spaceobject.rb'

class Spaceship < Spaceobject
	
	EMPTY_ROCKET_MASS = 2970000 # kg
	#GROSS_ROCKET_MASS = 2290000 # kg
	
	FUEL_LOSS_RATE = 500.0 / 60 * 1000 # kg/s
	EXHAUST_VELOCITY = 2500.0 / 1000	# km/s		# for solid rocket, see https://en.wikipedia.org/wiki/Specific_impulse
	
	@@image = Gosu::Image.new(Magick::Image.read("media/spaceship.svg") do |img|
		img.density = "300%"
		img.background_color = 'transparent'
	end.first)
	@@image_boost= Gosu::Image.new(Magick::Image.read("media/spaceship_boost.svg") do |img|
		img.density = "300%"
		img.background_color = 'transparent'
	end.first)
	
	attr_accessor :angle
	
	def	initialize(window:, position:, velocity:)
		super(
			window: window,
			mass: EMPTY_ROCKET_MASS + FUEL_LOSS_RATE * 120,	# normal first stage lasts about 2 minutes
			radius: 10.0,
			position: position,
			velocity: velocity,
			caption: "shipsal")
		
		@angle = 0
		@boost = false
	end
	
	def turn_left
		@angle -= 4.5
		@angle %= 360
	end
	
	def turn_right
		@angle += 4.5
		@angle %= 360
	end
	
	def boost
		direction = Vector[Math.sin(Math::PI * (@angle)/180), -Math.cos(Math::PI * (@angle)/180)]

		@velocity += FUEL_LOSS_RATE / @mass * EXHAUST_VELOCITY * DT * direction
		@boost = true
	end
	
	def end_boost
		@boost = false
	end
	
	def update
		super
		
		self.turn_left if Gosu::button_down?(Gosu::KbLeft)
		self.turn_right if Gosu::button_down?(Gosu::KbRight)
		self.boost if Gosu::button_down?(Gosu::KbUp)
	end
	
	def draw
		super
		d_position = @window.cam.view_coords(self.position)
		d_height = @radius*2 * @window.cam.zoom
		d_width = @radius*2 * @window.cam.zoom * @@image.width/@@image.height

		if @boost
			@@image_boost.draw_rot(*d_position.to_a, ZOrder::SHIP, @angle, 0.5, 0.5, d_width/@@image.width, d_height/@@image.height)
		else
			@@image.draw_rot(*d_position.to_a, ZOrder::SHIP, @angle, 0.5, 0.5, d_width/@@image.width, d_height/@@image.height)
		end
	end
	
	
end
