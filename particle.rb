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
		# FIRST do all position updates,
		# THEN do all velocity updates
		particles_snapshot.each do |particle|
			# pass list of particles without itself
			particle.update_position(particles_snapshot - [particle])
		end
		
		particles_snapshot.each do |particle|
			particle.update_velocity(particles_snapshot - [particle])
		end
		
		# calculate energies&momentum for check
		#		
		@@total_energy_start ||= Particle.total_energy
		@@total_momentum_start ||= Particle.total_momentum

		@@total_energy_current = Particle.total_energy
		@@total_momentum_current = Particle.total_momentum

	end
	
	# total momentum of all particles
	def self.total_momentum
		@@particles.map{|p| p.momentum}.reduce(:+)
	end
	
	# kinetic and potential energy of all particles
	def self.total_energy
		total_kin = @@particles.map{|p| p.kinetic_energy}.reduce(:+)
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
	
	# center of mass vector
	def self.center_of_mass
		@@particles.map {|p| p.position * p.mass}.reduce(:+) / @@particles.map{ |p| p.mass }.reduce(:+)
	end
	

	attr_reader :mass, :position
	attr_reader :position_history
	
	def initialize(mass, position, velocity)
		@mass = mass
		
		@position = position
		@velocity = velocity / LENGTH_SCALE
		@acc = nil
		
		@position_history = Array.new
		@position_history << @position
		
		#@ind = @@particles.size
		@@particles << self
	end
	
	def update_position(particles)
		
		if @acc.nil?	# only calculate the first time
			@acc = recalc_acc(particles)
		end
		
		@position += @velocity * DT + @acc * (DT**2) / 2
		@position_history << @position
	end
	
	def update_velocity(particles)
		acc_old = @acc.clone
		@acc = recalc_acc(particles)
		
		@velocity += (acc_old + @acc) * DT / 2
	end
	
	# in km /s
	# absolute velocity without argument
	# relative velocity with argument
	def velocity(*particle)	
		if particle.size == 0
			@velocity * LENGTH_SCALE
		else
			self.velocity - particle[0].velocity
		end
	end
	
	def kinetic_energy
		self.mass * self.velocity.norm**2 / 2
	end
	
	def momentum
		self.mass * self.velocity
	end
	
	# the escape velocity of self w.r.t to particle
	def escape_velocity(particle)
		Math.sqrt( 2 * GRAV_CONST * particle.mass / self.distance(particle) )
	end
	
	def distance(particle)
		(self.position - particle.position).norm * LENGTH_SCALE
	end
	def distance_v(particle) # relative-vector
		(self.position - particle.position).normalize
	end
	
	# some error estimation
	def error # TODO
		(@@total_momentum_current - @@total_momentum_start).norm / self.mass
		
		#2* Math.sqrt((@@total_energy_current - @@total_energy_start).abs) / self.mass
	end
	
	private
	
	def recalc_acc(particles)
		particles.inject(Vector[0,0]) do |force, particle|
			displacement = particle.position - @position
			distance = displacement.norm * LENGTH_SCALE
			
			### TODO ?
			#if distance > 10
			force + GRAV_CONST * particle.mass / (distance**3) * displacement
			#else
			#	force
			#end
		end
	end
	
end
