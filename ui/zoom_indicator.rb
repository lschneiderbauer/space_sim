 class ZoomIndicator
	
	FONT_COLOR = "#3fbf3fff"
	FONT_COLOR_HOVER = "#3fbf3fff"
	BACKGROUND_COLOR = "#232629ff"
	FONT_SIZE = 22
	FONT_NAME = "Hack"

	@@scale = Gosu::Image.new("media/scale.png")
	
	WIDTH = 200.0
	PADDING = 10.0
	SCALE_WIDTH = WIDTH - 2*PADDING
	SCALE_HEIGHT = @@scale.height * SCALE_WIDTH/@@scale.width
	

	@@font = Gosu::Font.new(FONT_SIZE, name: FONT_NAME)
	
	
	# create bg once
	rimg = Magick::Image.new(WIDTH, SCALE_HEIGHT + @@font.height + 2*PADDING) do |img|
		img.background_color = 'transparent'
	end
		
	td = Magick::Draw.new do |td|
		#td.stroke = "#ffffffff"
		td.stroke = BACKGROUND_COLOR
		td.stroke_width = 2
		td.fill = "#000000ff"
	end
	td.roundrectangle(1,1, rimg.columns-2, rimg.rows-2, 5, 5).draw(rimg)
	
	@@bg = Gosu::Image.new(rimg)

	
	
	
	attr_accessor :position
	
	def initialize(window, position)
		
		@window = window
		@position = position
		@text = ""

	end
	
	def update
		@text = "#{(SCALE_WIDTH / @window.cam.zoom * LENGTH_SCALE).to_i.spaceify} km"
	end
	
	def draw
		bg_pos = @position
		scale_pos = bg_pos + Vector[PADDING,PADDING]
		font_pos = scale_pos + Vector[0,PADDING/2] + Vector[(WIDTH-2*PADDING - @@font.text_width(@text))/2, SCALE_HEIGHT]
		
		@@bg.draw(*bg_pos.to_a, ZOrder::UI-0.1)
		@@scale.draw(*scale_pos.to_a ,ZOrder::UI, (WIDTH-2*PADDING).to_f/@@scale.width, (WIDTH-2*PADDING).to_f/@@scale.width, 0xaa_ffffff)
		
		@@font.draw(@text, *font_pos.to_a, ZOrder::UI, 1.0, 1.0, 0xaa_ffffff)
	end
	
	def self.width
		@@bg.width.to_f
	end
	
	def self.height
		@@bg.height.to_f
	end
	
end

class Fixnum
	def spaceify
		self.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
	end
end