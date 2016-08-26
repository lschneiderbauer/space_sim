require_relative 'clickable.rb'

class OverlayText
	include Clickable
	
	FONT_COLOR = "#3fbf3faa"
	FONT_COLOR_HOVER = "#3fbf3fff"
	BACKGROUND_COLOR = "#232629aa"
	BACKGROUND_COLOR_HOVER = "#232629ff"
	FONT_SIZE = 25
	FONT_NAME = "Oxygen Mono"
	
	MIN_WIDTH = 150
	
	@@font = Gosu::Font.new(FONT_SIZE, name: FONT_NAME)
	
	
	attr_reader :text
	attr_accessor :position
	
	def initialize(window, text)
		@window = window
		@window.on_button_down {|wd, id| button_down(window, id)}
		
		@text = text
		
		@position = Vector[0,0]
		
		@mouse_hovered = false
		
		# build text - image
		# #######################
		img_width = (@@font.text_width(text)+50 < MIN_WIDTH ? MIN_WIDTH : @@font.text_width(text)+50)
		
		rimg = Magick::Image.new(img_width,FONT_SIZE+20) do |img|
			img.background_color = 'transparent'
		end
	
		td = Magick::Draw.new do |td|
			td.stroke = FONT_COLOR
			td.stroke_width = 2
			td.fill = BACKGROUND_COLOR
		end
		td.roundrectangle(1, 1, rimg.columns-2, rimg.rows-2, 5, 5).draw(rimg)
		td.annotate(rimg, rimg.columns, rimg.rows, 0, 2, text) do |td|
			td.stroke = FONT_COLOR
			td.stroke_width = 1
			td.font_family = FONT_NAME
			td.fill = FONT_COLOR
			td.pointsize = FONT_SIZE
			td.gravity = Magick::CenterGravity
		end
		
		@img = Gosu::Image.new(rimg)
		
		
		# hovered img
		rimg = Magick::Image.new(img_width,FONT_SIZE+20) do |img|
			img.background_color = 'transparent'
		end
	
		td = Magick::Draw.new do |td|
			td.stroke = FONT_COLOR_HOVER
			td.stroke_width = 2
			td.fill = BACKGROUND_COLOR_HOVER
		end
		td.roundrectangle(1, 1, rimg.columns-2, rimg.rows-2, 5, 5).draw(rimg)
		td.annotate(rimg, rimg.columns, rimg.rows, 0, 2, text) do |td|
			td.stroke = FONT_COLOR
			td.stroke_width = 1
			td.font_family = FONT_NAME
			td.fill = FONT_COLOR
			td.pointsize = FONT_SIZE
			td.gravity = Magick::CenterGravity
		end
		
		@img_hover = Gosu::Image.new(rimg)
	end
	
	def width
		@img.width.to_f
	end
	
	def height
		@img.height.to_f
	end
	
	def diameter(angle)
		nangle = (angle%180).abs
		if nangle.abs > 90
			nangle = 180 - nangle
		end
		nangle = nangle / 180 * Math::PI
		
		if nangle < Math.atan(self.width/self.height)
			self.width * Math.cos(nangle)
		else
			self.height * Math.sin(nangle)
		end
	end
	
	def update
		if self.mouse_hover?
			trigger_mouse_hover(self) unless @mouse_hovered
			@mouse_hovered = true
		else
			trigger_mouse_unhover(self) if @mouse_hovered
			@mouse_hovered = false
		end
	end
	
	def draw
		text_position = self.position - Vector[@img.width, @img.height]/2
		
		unless self.mouse_focus?
			@img.draw(*text_position.to_a, ZOrder::IND)
		else
			@img_hover.draw(*text_position.to_a, ZOrder::IND+0.1)
		end
	end
	
	def button_down(window, id)
		# todo create event on click
		if id == Gosu::MsLeft || id == Gosu::MsRight || id == Gosu::MsMiddle
			if (self.position[0] - self.width/2..self.position[0]+self.width/2).include?(@window.mouse_x) && (self.position[1] - self.height/2..self.position[1]+self.height/2).include?(@window.mouse_y)
				trigger_mouse_click(id) if self.mouse_focus?
			end
		end
	end
	
	def mouse_hover?
		(@position[0] - self.width/2..@position[0] + self.width/2).include?(@window.mouse_x) && (@position[1] - self.height/2..@position[1] + self.height/2).include?(@window.mouse_y)
	end
	
	def mouse_focus?
		!@window.mouse_focus.nil? && @window.mouse_focus.caption == self
	end
	
end
