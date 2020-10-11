# Describes a particle and their gravitational interactions at long distances,
# while behaving like a billiard ball at short distances
class Particle
  @@particles = []	# list of particles which are aware of each other
  @@total_energy_start = nil
  @@total_momentum_start = nil
  @@total_energy_current = nil
  @@total_momentum_current = nil

  def self.update_simulation
    # create of snapshot of particle data
    particles_snapshot = @@particles.clone

    # IMPORTANT
    # Since the acceleration computation does depend on the velocities of the particles,
    # we cannot update the individual velocities before the acceleration of all particles has been computed
    # So we have to FIRST only compute the accelerations
    # THEN compute all velocity updates,
    # and THEN do all position updates
    particles_snapshot.each do |particle|
      particle.update_acceleration(particles_snapshot - [particle])
    end

    particles_snapshot.each do |particle|
      particle.update_velocity(particles_snapshot - [particle])
    end

    particles_snapshot.each do |particle|
      # pass list of particles without itself
      particle.update_position(particles_snapshot - [particle])
    end

    # calculate energies&momentum for check
    #
    @@total_energy_start ||= Particle.total_energy
    @@total_momentum_start ||= Particle.total_momentum

    @@total_energy_current = Particle.total_energy
    @@total_momentum_current = Particle.total_momentum
  end

  # @return [Array<Particle>] A list of all created particles
  def self.particles
    @@particles.clone
  end

  # @return [Float] The total momentum of all particles
  def self.total_momentum
    @@particles.map(&:momentum).reduce(:+)
  end

  # @return [Float] The total kinetic and potential energy of all particles
  def self.total_energy
    total_kin = @@particles.map(&:kinetic_energy).reduce(:+)
    pot = @@particles.combination(2).inject(0) do |pot, p_ar|
      p1, p2 = *p_ar
      if p1 != p2
        pot - p1.mass * p2.mass * GRAV_CONST / ((p2.position - p1.position).norm * LENGTH_SCALE)
      else
        pot
      end
    end

    total_kin + pot
  end

  # @return [Vector] Center of mass vector
  def self.center_of_mass
    @@particles.map { |p| p.position * p.mass }.reduce(:+) / @particles.map(&:mass).reduce(:+)
  end

  attr_reader :mass, :position, :radius
  attr_reader :position_history

  # we add a radius here due to regularization reasons
  def initialize(mass, position, velocity, radius)
    @mass = mass

    @position = position
    @velocity = velocity / LENGTH_SCALE
    @radius = radius
    @acc = nil

    @position_history = []
    @position_history << @position

    # @ind = @@particles.size
    @@particles << self
  end

  def update_position(_particles)
    @position += @velocity * DT
    @position_history << @position
  end

  def update_velocity(_particles)
    @velocity += @acc * DT / 2

    # a posteriori addition of particle box
    # strategy: if outside the 2D box, just change direction of velocity towards box
    return if @box.nil?

    @velocity = Vector[-@velocity[0].abs, @velocity[1]] if @position[0] > @box[1][0]
    @velocity = Vector[@velocity[0].abs, @velocity[1]] if @position[0] < @box[0][0]
    @velocity = Vector[@velocity[0], @velocity[1].abs] if @position[1] < @box[0][1]
    @velocity = Vector[@velocity[0], -@velocity[1].abs] if @position[1] > @box[1][1]
  end

  def update_acceleration(particles)
    @acc = recalc_acc(particles)
  end

  # in km /s
  # absolute velocity without argument
  # relative velocity with argument
  def velocity(*particle)
    if particle.size.zero?
      @velocity * LENGTH_SCALE
    else
      velocity - particle[0].velocity
    end
  end

  def kinetic_energy
    mass * velocity.norm**2 / 2
  end

  def momentum
    mass * velocity
  end

  # the escape velocity of self w.r.t to particle
  def escape_velocity(particle)
    Math.sqrt(2 * GRAV_CONST * particle.mass / distance(particle))
  end

  def distance(particle)
    (position - particle.position).norm * LENGTH_SCALE
  end

  def distance_v(particle) # relative-vector
    (position - particle.position).normalize
  end

  # some error estimation
  def self.error
    if @@total_energy_current.nil?
      0
    else
      (@@total_energy_current - @@total_energy_start).abs / @@total_energy_start
    end
  end

  # this is a messy implementation (a posteriori addition)
  # of a box around the particle in which it is supposed to be trapped
  def set_box(left_bottom, right_top)
    @box = [left_bottom, right_top]
  end

  private

  def recalc_acc(particles)
    particles.inject(Vector[0, 0]) do |force, particle|
      displacement = particle.position - @position
      distance = displacement.norm * LENGTH_SCALE

      if distance > (radius + particle.radius)	# usual gravitational force

        # Note that we don't multiply here with the LENGTH_SCALE since this is the acceleration not in physical units
        # but the acceleration w.r.t. to our global coordinate system in units of LENGTH_SCALE
        force + GRAV_CONST * mass * particle.mass / (distance**3) * displacement

      elsif velocity(particle).dot(displacement).positive?
        # only initiate elastic collision if the relative velocity is such that they approach each other
        # (there could be numerical artefacts that brings you in the other condition)

        # in this case we create a repulsive force (which models an elastic collision)
        normal_v1 = velocity.dot(displacement) / LENGTH_SCALE
        normal_v2 = particle.velocity.dot(displacement) / LENGTH_SCALE

        # elastic collision: if masses are equal, then
        # v1_n = v2_n
        # v2_n = v1_n

        # at first subtract the normal velocity of the original particle
        # and add the normal velocity of the other particle
        force - 2.0 * displacement * (normal_v1 - normal_v2) / (DT * displacement.norm**2)
      else
        force
      end
    end
  end
end
