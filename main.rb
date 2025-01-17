#!/usr/bin/env ruby

require 'matrix'
require 'gosu'
require 'rmagick'

require_relative 'constants.rb'
require_relative 'ui/camera.rb'
require_relative 'ui/zoom_indicator.rb'
require_relative 'spaceobject.rb'
require_relative 'spaceship.rb'
# require_relative 'gravcontour.rb'

class Vector
  def normal
    Vector[self[1], -self[0]] if size == 2
  end
end

class GameWindow < Gosu::Window
  attr_reader :cam, :mouse_focus

  def initialize
    # super(Gosu::screen_width,Gosu::screen_height, fullscreen: true)
    super(Gosu.screen_width / 2, Gosu.screen_height / 2, fullscreen: false)
    self.caption = 'Space Sim'
    @bg = Gosu::Image.new('media/space.jpg', tileable: true)
    @font = Gosu::Font.new(30)

    @on_button_down = []	# for registering callbacks
    @on_button_up = []

    @cam = Camera.new(
      window: self,
      offset: Vector[0.0, 0.0],
      zoom: height / (3 * EARTH_RADIUS / LENGTH_SCALE)
    )

    @spaceobjects = []

    @spaceobjects <<
      @sun = Spaceobject.new(
        window: self,
        mass: SUN_MASS,
        radius: SUN_RADIUS,
        position: Vector[0.0, -DISTANCE_E_S / LENGTH_SCALE],
        velocity: Vector[0.0, 0.0],
        image: 'media/sun.png',
        caption: 'Sun'
      )

    @spaceobjects <<
      @mars = Spaceobject.new(
        window: self,
        mass: MARS_MASS,
        radius: MARS_RADIUS,
        position: Vector[DISTANCE_MARS_SUN, -DISTANCE_E_S] / LENGTH_SCALE,
        velocity: Vector[0.0, 24.077],
        image: Magick::Image.read('media/mars.svg') do |img|
                 img.density = '200%'
                 img.background_color = 'transparent'
               end.first,
        caption: 'Mars'
      )

    @spaceobjects << Spaceobject.create_circular_satellite(
      carrier: @mars,
      mass: 10.8 * 10**15,
      radius: 11.1,
      distance: 9377,
      image: 'media/moon.png',
      caption: 'Mars Moon I'
    )

    @spaceobjects << Spaceobject.create_circular_satellite(
      carrier: @mars,
      mass: 2 * 10**15,
      radius: 6.3,
      distance: 23_460,
      image: 'media/moon.png',
      caption: 'Mars Moon II'
    )

    @spaceobjects <<
      @earth = Spaceobject.new(
        window: self,
        mass: EARTH_MASS,
        radius: EARTH_RADIUS,
        position: Vector[0.0, 0.0],
        velocity: Vector[29.78, 0.0],
        image: Magick::Image.read('media/earth.svg') do |img|
                 img.density = '500%'
                 img.background_color = 'transparent'
               end.first,
        caption: 'Earth'
      )

    @spaceobjects <<
      @moon = Spaceobject.create_circular_satellite(
        carrier: @earth,
        mass: MOON_MASS,
        radius: MOON_RADIUS,
        distance: SM_DISTANCE_E_M,
        image: 'media/moon.png',
        caption: 'Moon'
      )

    @spaceobjects <<
      @station = Spaceobject.create_circular_satellite(
        carrier: @earth,
        mass: ISS_MASS,
        radius: ISS_RADIUS,
        distance: EARTH_RADIUS + 410.0,
        image: Magick::Image.read('media/satellite.svg') do |img|
                 img.density = '100%'
                 img.background_color = 'transparent'
               end.first,
        caption: 'ISS'
      )

    @spaceobjects <<
      @geo = Spaceobject.create_circular_satellite(
        carrier: @earth,
        mass: GEO_MASS,
        radius: GEO_RADIUS,
        distance: EARTH_RADIUS + 35_786.0,
        image: Magick::Image.read('media/satellite.svg') do |img|
                 img.density = '100%'
                 img.background_color = 'transparent'
               end.first,
        caption: 'GEO'
      )

    @spaceobjects <<
      @ship = Spaceship.new(
        window: self,
        position: @station.position + Vector[200.0, 200.0] / LENGTH_SCALE,
        velocity: @station.velocity
      )

    @mouse_focus = nil

    # register events
    @spaceobjects.each do |so|
      so.on_mouse_click { |obj, id| spaceobjects_clicked(obj, id) }
      so.on_mouse_hover { |obj| spaceobjects_hovered(obj) }
      so.on_mouse_unhover { |obj| spaceobjects_unhovered(obj) }
    end

    # activate caption
    @spaceobjects.map { |so| so.show_caption = true }

    # cam locked onto earth
    @cam.lock(@earth)

    @zoom_indicator = ZoomIndicator.new(self, Vector[50.0 * UI_SCALE, height - ZoomIndicator.height - 50 * UI_SCALE])
    # @gravcontour = GravContour.new(self)
  end

  def update
    # next step in simulation
    Particle.update_simulation

    # update camera (current view)
    # ! has to be before everything else,
    # because other things rely on cam-info
    @cam.update

    @zoom_indicator.update

    # update all space objects
    @spaceobjects.each(&:update)

    # update gravitational contour-lines
    # @gravcontour.update

    # debug
    puts "#{-@cam.offset[0] / @cam.zoom}," if Gosu.button_down?(Gosu::KbF)
    # puts self.mouse_y
    # puts @cam.view_coords(@cam.current_view[0])
    # puts @cam.view_coords(@cam.current_view[1])
    # puts @cam.view_coords(-@cam.offset/@cam.zoom)
  end

  def draw
    # background tiling
    (width / @bg.width + 1).times do |i|
      (height / @bg.height + 1).times do |j|
        @bg.draw(@bg.width * i, @bg.height * j, ZOrder::BG)
      end
    end

    # after background make gravitational contours
    # @gravcontour.draw

    @spaceobjects.each(&:draw)

    #     @font.draw("Ship Status", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffffff)
    #     #@font.draw("Position: #{@ship.position.to_a.map{|e| e.round(0)}}", 10, 40, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    #
    #     #@font.draw("Angle: #{@ship.angle} degree", 10, 100, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    #     #@font.draw("Offset: #{$offset}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffffff)
    #     @font.draw("Distance ship-earth: #{@earth.distance(@ship).round(0)} km", 10, 40, ZOrder::UI, 1.0, 1.0, 0xff_ffffff)
    #     @font.draw("Radial Velocity ship-earth: #{@ship.velocity(@earth).dot(@ship.distance_v(@earth)).round(1)} km/s", 10, 70, ZOrder::UI, 1.0, 1.0, 0xff_ffffff)
    #     @font.draw("Transversal Velocity ship-earth: #{@ship.velocity(@earth).dot(@ship.distance_v(@earth).normal).round(1).abs} km/s", 10, 100, ZOrder::UI, 1.0, 1.0, 0xff_ffffff)
    #     @font.draw("Escape velocity w.r.t. earth: #{@ship.escape_velocity(@earth).round(1)} km/s", 10, 130, ZOrder::UI, 1.0, 1.0, 0xff_ffffff)
    #
    #     Gosu::translate(0, 200) do
    #       @font.draw("Total Momentum: #{Particle.total_momentum.norm}", 10, 130, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    #       @font.draw("Total Energy: #{Particle.total_energy}", 10, 100, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    #
    #       @font.draw("Zoom: #{@cam.zoom.round(10)}", 10, 160, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    #     end
    #
    #		@font.draw("Velocity Moon: #{@test.real_velocity.norm.round(0)} +- #{@test.error} km/s", 10, 130, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    #
    #
    #     #@font.draw("moon visible: #{@moon.visible?(self)}", 10, 200, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    @zoom_indicator.draw
  end

  def button_down(id)
    @on_button_down.each { |block| block.call(self, id) }	# forward event to registrants

    case id
    when Gosu::KbEscape
      close
    when Gosu::KbSpace
      @spaceobjects.each { |so| so.show_caption ^= true }
    end
  end

  def button_up(id)
    @on_button_up.each { |block| block.call(self, id) }	# forward event to registrants

    @ship.end_boost if id == Gosu::KbUp
  end

  def spaceobjects_clicked(obj, id)
    case id
    when Gosu::MsLeft
      @cam.lock(obj)
    when Gosu::MsRight
      @cam.match_speed(obj)
    when Gosu::MsMiddle
      @cam.lock_and_zoom(obj)
    end
  end

  # control mouse focus
  #
  def spaceobjects_hovered(obj)
    @mouse_focus = obj if @mouse_focus.nil? || (obj != @mouse_focus && !@mouse_focus.mouse_hover?)
  end

  def spaceobjects_unhovered(obj)
    if @mouse_focus == obj
      @mouse_focus = nil
      @spaceobjects.each do |so|
        @mouse_focus = so if so != obj && so.mouse_hover?
      end
    end
  end

  def needs_cursor?
    true
  end

  def on_button_down(&block)
    @on_button_down << block
  end

  def on_button_up(&block)
    @on_button_up << block
  end
end

window = GameWindow.new
window.show
