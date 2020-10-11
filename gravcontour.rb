require 'inline'
require 'opengl'
require 'gl'
# require 'glu'

class GravContour
  include Gl

  def initialize(window)
    @window = window

    @contours = []
  end

  def update
    bottomleft, topright = @window.cam.current_view
    pixelsize = (topright[0] - bottomleft[0]) / @window.width

    puts "range #{topright[0] - bottomleft[0]}"

    # we have to initialize those before calling self.contour
    @masses = Particle.particles.map { |p| p.mass * GRAV_CONST }
    @positions_x = Particle.particles.map { |p| p.position[0] }
    @positions_y = Particle.particles.map { |p| p.position[1] }

    puts @masses.inspect

    @contours = generate_contours(pixelsize, bottomleft[0], bottomleft[1], topright[0], topright[1])

    # puts (Particle.particles[4].position - Vector[*@contours[0]]).norm

    # IO.write("ar.txt", ar.join("\n"))
  end

  def draw
    @window.gl do
      # Initialize clear color
      # glClearColor( 255, 255, 255, 000 )

      # Enable texturing
      # glEnable( GL_TEXTURE_2D )

      # Set blending
      glEnable(GL_BLEND)
      # glDisable( GL_DEPTH_TEST )
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

      # Set antialiasing/multisampling
      glHint(GL_LINE_SMOOTH_HINT, GL_NICEST)
      glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST)
      glEnable(GL_LINE_SMOOTH) # smooth line
      # glEnable( GL_LINE_STIPPLE ) # dashed line
      glEnable(GL_POLYGON_SMOOTH)
      # glEnable( GL_MULTISAMPLE )

      glLineWidth(2.0)

      @contours.each do |cont|
        Gl.glBegin(Gl::GL_LINE_STRIP)

        cont.each do |position|
          coords = @window.cam.view_coords(Vector[*position])
          Gl.glVertex3f(*coords.to_a, ZOrder::SOBJECT - 0.1)
        end

        Gl.glEnd
      end

      glDisable(GL_LINE_SMOOTH)
      glDisable(GL_POLYGON_SMOOTH)
    end
  end

  inline do |builder|
    builder.add_compile_flags '-lruby24 -lm'
    builder.include '<math.h>'
    builder.include '<float.h>'
    builder.prefix "
			double pot(VALUE self, double pot_pos_x, double pot_pos_y) {

				/* IMPORTANT
				Note that in order to avoid huge numbers, we need the masses already multiplied by the gravitational constant!
				*/

				VALUE *positions_x;
				VALUE *positions_y;
				VALUE *masses;

				int n_particles;
				double sum=0.0;
				int i=0;

				const int LENGTH_SCALE = 50;	// just temporary, want to use the ruby one in the long term

				masses = RARRAY_PTR( rb_iv_get(self, \"@masses\") );
				positions_x = RARRAY_PTR(rb_iv_get(self, \"@positions_x\"));
				positions_y = RARRAY_PTR(rb_iv_get(self, \"@positions_y\"));
				n_particles = sizeof(masses);

				for(i = 0; i < n_particles; i++) {
					sum += NUM2LONG(masses[i]) /
						(LENGTH_SCALE *
							sqrt(
								pow( NUM2DBL(positions_x[i]) - pot_pos_x , 2.0) +
								pow( NUM2DBL(positions_y[i]) - pot_pos_y , 2.0)
							)
						);
				}

				return sum;
			}
			double* gradient(VALUE self, double pot_pos_x, double pot_pos_y) {
				double h_x = 1.0E-8 * pot_pos_x;
				double h_y = 1.0E-8 * pot_pos_y;

				static double grad[2];

				grad[0] = ( pot(self, pot_pos_x + h_x, pot_pos_y) - pot(self, pot_pos_x - h_x, pot_pos_y) )/(2*h_x);
				grad[1] = ( pot(self, pot_pos_x, pot_pos_y + h_y) - pot(self, pot_pos_x, pot_pos_y - h_y) )/(2*h_y);

				return grad;
			}
			double* perp(double* vec) {
				static double perped[2];

				perped[0] = vec[1];
				perped[1] = -vec[0];

				return perped;
			}
			double* normed(double* vec) {
				static double normed[2];
				double norm = sqrt(pow(vec[0],2)+pow(vec[1],2));

				normed[0] = vec[0]/norm;
				normed[1] = vec[1]/norm;

				return normed;
			}
			double norm(double* vec) {
				return sqrt(pow(vec[0],2)+pow(vec[1],2));
			}
			double distance(double x1, double y1, double x2, double y2) {
				return sqrt(pow(x1-x2,2)+pow(y1-y2,2));
			}
			double* strongest_sing_dist(VALUE self, double pos_x, double pos_y) {
				static double strongest[2];

				VALUE* obj_positions_x = RARRAY_PTR(rb_iv_get(self, \"@positions_x\"));
				VALUE* obj_positions_y = RARRAY_PTR(rb_iv_get(self, \"@positions_y\"));
				VALUE* obj_masses = RARRAY_PTR(rb_iv_get(self, \"@masses\"));

				int len = sizeof(obj_positions_x);

				int strongest_ind;
				double strongest_pot = DBL_MIN;
				double pot;
				int i;

				for (i=0; i<len; i++) {
					pot = NUM2DBL( obj_masses[i] )/distance( NUM2DBL(obj_positions_x[i]), NUM2DBL(obj_positions_y[i]), pos_x, pos_y );
					if (pot > strongest_pot) {
						strongest_pot = pot;
						strongest_ind = i;
					}
				}
				printf(\"strongest_ind: %d\\n\", strongest_ind);
				strongest[0] = strongest_pot;								// distance
				strongest[1] = NUM2DBL( obj_masses[strongest_ind] );	// mass
				return strongest;
			}



			VALUE contour(VALUE self, double pixelsize, double start_x, double start_y,
				double bottomleft_x, double bottomleft_y, double topright_x, double topright_y) {
				float step = pixelsize * 5;
				double* step_vec;
				double* grad;
				double* ngrad;

				double value = pot(self, start_x, start_y);


				/* for debug reasons look for starting value 940 */
	/*
				while (fabs(value-940.0) > 0.1) {
					grad = gradient(self, start_x, start_y);
					ngrad = normed(grad);
					start_x -= ngrad[0] * 0.1 * fabs(value-940)/(value-940);
					start_y -= ngrad[1] * 0.1 * fabs(value-940)/(value-940);
					value = pot(self, start_x, start_y);
					//printf(\"value: %f\\n\", value);
				}
				//printf(\"---\\n\");
	*/
				/* debug end */


				double cur_point_x = start_x;
				double cur_point_y = start_y;


				VALUE cont = rb_ary_new();
				rb_ary_push(cont, rb_ary_new3(2, DBL2NUM(cur_point_x), DBL2NUM(cur_point_y) ));

				int loopct = 0; // just in case something unexpected happens we do a cutoff
				int direction = 1; // in case we hit the wall we reverse
				do {
					// if outside of view reverse direction
					if (!(cur_point_x >= bottomleft_x && cur_point_x <= topright_x && cur_point_y >= bottomleft_y && cur_point_y <= topright_y)) {
						direction = -1;
						cur_point_x = start_x;
						cur_point_y = start_y;
					}

					grad = gradient(self, cur_point_x, cur_point_y);
					ngrad = normed(grad);
					//printf(\"grad: %f\\n\", sqrt(pow(grad[0],2)+pow(grad[1],2)));
					step_vec = perp(ngrad);
					step_vec[0] *= step * direction;
					step_vec[1] *= step * direction;

					cur_point_x += step_vec[0];
					cur_point_y += step_vec[1];


					// error correction (make better...) ( do the same as in the gradient follow-approach)
					int ct = 0;
					while ( (pot(self, cur_point_x, cur_point_y)-value) < -0.001 * norm(grad) && ct < 10) {
						cur_point_x += ngrad[0] * step * 0.01;
						cur_point_y += ngrad[1] * step * 0.01;
						ct++;
					}
					ct = 0;
					while ( (pot(self, cur_point_x, cur_point_y)-value) > 0.001 * norm(grad) && ct < 10) {
						cur_point_x -= ngrad[0] * step * 0.01;
						cur_point_y -= ngrad[1] * step * 0.01;
						ct++;
					}
					//printf(\"%d\\n\", ct);
					//printf(\"value: %f || error: %f\\n\", value, (pot(self, cur_point_x, cur_point_y)-value));

					if (direction == 1) {
						rb_ary_push(cont, rb_ary_new3(2, DBL2NUM(cur_point_x), DBL2NUM(cur_point_y) ));
					} else if (direction == -1) {
						rb_ary_unshift(cont, rb_ary_new3(2, DBL2NUM(cur_point_x), DBL2NUM(cur_point_y) ));
					}

					loopct++;

				} while (distance(start_x,start_y, cur_point_x,cur_point_y) > step*0.5
					&& (cur_point_x >= bottomleft_x && cur_point_x <= topright_x && cur_point_y >= bottomleft_y && cur_point_y <= topright_y || direction == 1)
					&& loopct < 1000);

				return cont;
			}
			"

    builder.c "
			VALUE generate_contours(double pixelsize,
				double bottomleft_x, double bottomleft_y, double topright_x, double topright_y) {

				/* STRATEGY:
					-> make a very crude map of the potential
					-> determine minimum and maximum
					-> decide on contour-levels (equidistant)
					-> Is there a cheap method to not forget any lines? Probably, if we take into account the singularities.
					-> In the case of one singularity, we have just to start at the global minimum and follow the gradient, let's follow this recipe for now.
				*/

				VALUE contours = rb_ary_new();

				double width = topright_x - bottomleft_x;
				double height = topright_y - bottomleft_y;
				double grid[100];

				double min=INT_MAX;
				double max=INT_MIN;
				int min_i, max_i;

				// make crude map and find minimum and maximum
				int i=0;
				for (i=0; i<100; i++) {
					grid[i] = pot(self, bottomleft_x + width/10*(i%10), bottomleft_y + height/10*(i/10));
					if (grid[i] > max) { max = grid[i]; max_i = i;}
					if (grid[i] < min) { min = grid[i]; min_i = i;}
				}

				printf(\"min: %f\\n\", min);
				printf(\"max: %f\\n\", max);

				double range = (max-min);

				double start_x = bottomleft_x + width/10*(min_i%10);
				double start_y = bottomleft_y + height/10*(min_i/10);
				double cur_value, opt_value;
				double* sing_dist;
				double* grad;
				double* ngrad;

				for (i=0; i<5; i++) {
					// follow gradient path
					cur_value = min;
					opt_value = min + range/6 * (i+1);


					printf(\"start_x: %f\\n\", start_x);
					printf(\"start_y: %f\\n\", start_y);
					printf(\"width: %f\\n\", width);
					printf(\"pixelsize: %f\\n\", pixelsize);
					printf(\"cur_value: %f\\n\", cur_value);
					printf(\"opt_value: %f\\n\", opt_value);

					// i implemented kind of a newton-method.
					// but (for 1/r this will overshoot for (r-rsing) > 2/opt_value))
					// and seems therefore pretty useless for my purposes, because the initial guess has to be good

					/*
					if we assume that the 1/r potential of the nearest object dominates, then we get
					a formula for the guess

						r[n+1] = r[n] + (r[n]-r_sing)^2 * delta[n]/A

					when delta/A is small. where A is the coefficient in the A/r potential, and
					delta is the change of the potential (f[r[n]]-f[r[n+1]]) we want to achieve.

					If the formula is used while delta[n]/A is too big, then we run the risk shoot over the singularity.
					The full formula is:

						r[n+1] = r[n] + (r[n]-r_sing)^2 / (A/delta - (r_sing - r[n]))

					which for large A/delta brings you close the the singularity
					*/

					while (fabs(cur_value-opt_value) > range/50) {
						grad = gradient(self, start_x, start_y);
						ngrad = normed(grad);

						sing_dist = strongest_sing_dist(self, start_x, start_y);
						printf(\"strongest_sing_dist_dist: %f\\n\", sing_dist[0]);
						printf(\"strongest_sing_dist_mass: %f\\n\", sing_dist[1]);

						double factor = pow(sing_dist[0],2) * (cur_value - opt_value)/sing_dist[1];

						printf(\"factor: %f\\n\", factor);
						printf(\"delta/A: %f\\n\", (cur_value - opt_value)/sing_dist[1]);
						start_x += ngrad[0] * factor;
						start_y += ngrad[1] * factor;
						cur_value = pot(self, start_x, start_y);

						printf(\"start_x: %f\\n\", start_x);
						printf(\"start_y: %f\\n\", start_y);
						printf(\"cur_value: %f\\n\", cur_value);
						abort();

					}

					rb_ary_push(contours,contour(self, pixelsize, start_x, start_y, bottomleft_x, bottomleft_y, topright_x, topright_y));
				}

				return contours;
			}
		"
  end
end
