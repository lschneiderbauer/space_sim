# tmp
# require 'opengl'
# require 'gl'
# require 'glu'
# require 'benchmark'

require_relative 'ui/clickable.rb'
require_relative 'ui/overlay_text.rb'
require_relative 'particle.rb'

class Spaceobject < Particle
  include Clickable
  # include Gl

  CROSSHAIRS_DIAMETER = (50 * UI_SCALE).to_i
  ARROW_WIDTH = (30 * UI_SCALE).to_i

  @@crosshairs = Gosu::Image.new(Magick::Image.read('media/crosshairs.svg') do |img|
                                   img.density = CROSSHAIRS_DIAMETER.to_s
                                   img.background_color = 'transparent'
                                 end.first)

  # @@arrow = Gosu::Image.new("media/arrow.png")
  @@arrow = Gosu::Image.new(Magick::Image.read('media/arrow.svg') do |img|
                              img.density = ARROW_WIDTH.to_s
                              img.background_color = 'transparent'
                            end.first)

  # creation helper
  def self.create_circular_satellite(carrier:, mass:, distance:, radius: 0.0, image: nil, caption: '')
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
  def initialize(window:, mass:, position:, velocity:, radius: 0.0, image: nil, caption: '')
    super(mass, position, velocity, radius)
    puts "Loading #{caption} ..."

    @window = window

    @caption = OverlayText.new(window, caption)
    @caption.on_mouse_click { |_obj, id| trigger_mouse_click(id) }
    @caption.on_mouse_hover { |_obj| trigger_mouse_hover }
    @caption.on_mouse_unhover { |_obj| trigger_mouse_unhover }

    @crosshairs_position = Vector[0, 0]
    @arrow_position = Vector[0, 0]
    @arrow_angle = 0.0

    @show_caption = false

    @radius = radius.to_f / LENGTH_SCALE

    @image = Gosu::Image.new(image, tileable: true) unless image.nil?
    @image_position = Vector[0, 0]

    # 		@window.cam.on_zoom_changed { |old, new| recalc_trail(@window.cam.locked, new) }
    # 		@window.cam.on_lock_changed { |old, new| recalc_trail(new, @window.cam.zoom) }
  end

  def update
    @caption.update

    d_position = @window.cam.view_coords(position)	# drawing coordinates

    # calculate positions of arrows and text
    # and arrow angle
    if @show_caption

      if visible?

        @crosshairs_position = d_position - Vector[CROSSHAIRS_DIAMETER, CROSSHAIRS_DIAMETER] / 2 # 4 because 0.5 scale
        @caption.position = d_position + Vector[0.0, @@crosshairs.height]

      else

        cam_pos = -@window.cam.offset + Vector[@window.width.to_f, @window.height.to_f] / 2
        rel = (position * @window.cam.zoom - cam_pos).normalize

        @arrow_angle = 90 + Math.acos(rel.dot(Vector[0, -1])) / Math::PI * 180.0
        @arrow_angle = 180 - @arrow_angle if Matrix.columns([[0, -1], rel.to_a]).det < 0

        # set the arrow to the border of the screen
        #
        rel_scaled =
          if rel[0].abs / rel[1].abs >= @window.width.to_f / @window.height.to_f
            rel / rel[0].abs * (@window.width / 2 - (50 * UI_SCALE).to_i)
          else
            rel / rel[1].abs * (@window.height / 2 - (50 * UI_SCALE).to_i)
           end

        @arrow_position = Vector[@window.width.to_f, @window.height.to_f] / 2 + rel_scaled
        @caption.position = Vector[@window.width.to_f, @window.height.to_f] / 2 + rel_scaled.normalize * (rel_scaled.norm - (30 * UI_SCALE).to_i - @caption.diameter(@arrow_angle) / 2)
      end
    end

    unless @image.nil?
      d_height = d_width = @radius * 2 * @window.cam.zoom
      @image_position = d_position - Vector[d_width, d_height] / 2
    end
  end

  def draw
    if @show_caption
      if visible? # draw crosshairs
        @@crosshairs.draw(*@crosshairs_position.to_a, ZOrder::IND)
      else # otherwise draw arrow
        @@arrow.draw_rot(*@arrow_position.to_a, ZOrder::IND, @arrow_angle)
      end

      @caption.draw
    end

    unless @image.nil?
      d_height = d_width = @radius * 2 * @window.cam.zoom

      @image.draw(*@image_position.to_a, ZOrder::SOBJECT, d_width / @image.width, d_height / @image.height)
    end
    #     # draw history
    #     if !@window.cam.locked.nil? && @window.cam.locked != self && self.visible?
    #
    #       @window.gl do
    #
    #
    #         #Initialize clear color
    #         #glClearColor( 255, 255, 255, 000 )
    #
    #         #Enable texturing
    #         #glEnable( GL_TEXTURE_2D )
    #
    #         #Set blending
    #         glEnable( GL_BLEND )
    #         #glDisable( GL_DEPTH_TEST )
    #         glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA )
    #
    #         #Set antialiasing/multisampling
    #         glHint( GL_LINE_SMOOTH_HINT, GL_NICEST )
    #         glHint( GL_POLYGON_SMOOTH_HINT, GL_NICEST )
    #         glEnable( GL_LINE_SMOOTH )
    #         glEnable( GL_POLYGON_SMOOTH )
    #         #glEnable( GL_MULTISAMPLE )
    #
    #         glLineWidth(1.5)
    #
    #         glEnableClientState(GL_VERTEX_ARRAY)
    #
    #         glVertexPointer(3, GL_FLOAT, 0, @trail)
    #         glDrawArrays(GL_LINE_STRIP, 0, @trail.size/3)
    #
    # 				puts "drawarray #{time1}"
    # 				puts "arraymanip #{time2}"
    # 				puts "arraymanip2 #{time3}"
    #
    #         glDisableClientState(GL_VERTEX_ARRAY)
    #
    #				Gl::glBegin(Gl::GL_LINE_STRIP)
    # 				self.position_history.each_with_index do |pos, i|
    # 					coords = @window.cam.view_coordinates(locked.position + self.position_history[i] - locked.position_history[i])
    # 					Gl::glVertex3f(*coords.to_a, ZOrder::SOBJECT-0.1)
    # 				end
    #				Gl::glEnd
    #
    #         glDisable( GL_LINE_SMOOTH )
    #         glDisable( GL_POLYGON_SMOOTH )
    #       end
    #
    #
    #     end
  end

  def visible?
    (-window.cam.offset[0]..-@window.cam.offset[0] + @window.width).superset?(position[0] * @window.cam.zoom - (@@crosshairs.width / 2)..position[0] * @window.cam.zoom + (@@crosshairs.width / 2)) && (-@window.cam.offset[1]..-@window.cam.offset[1] + @window.height).superset?(position[1] * @window.cam.zoom - (@@crosshairs.height / 2)..position[1] * @window.cam.zoom + (@@crosshairs.height / 2))
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
    min <= range.min && max >= range.max
  end
end
