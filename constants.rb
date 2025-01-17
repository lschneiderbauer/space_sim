UI_SCALE = 1.0

ZOOM_FACTOR = 1.1
# TIME_DILATION = 60.0 # 60.0 # 3600.0
TIME_DILATION = 1 # 60.0 # 3600.0
DT = 1.0 / 60 * TIME_DILATION	# 60 frames per second

LENGTH_SCALE = 50	# 1 grid-unit =: <scale> km

# constants of nature
# used units: kg, km, s

GRAV_CONST = 6.67408 * (10**-20)	# km^3 kg^-1 s^-2

EARTH_RADIUS = 6371.0	# km
EARTH_MASS = 5.97237 * (10**24) # kg

MARS_RADIUS = 3389.5
MARS_MASS = 0.107 * EARTH_MASS

SUN_RADIUS = 109 * EARTH_RADIUS
SUN_MASS = 1.98855 * (10**30)

MOON_RADIUS = 1737.1
MOON_MASS = 7.342 * (10**22)

ISS_MASS = 419_455
ISS_RADIUS = 100.0 # 0.1

GEO_RADIUS = 100.0 # ?
GEO_MASS = 700

SM_DISTANCE_E_M = 380_000.0
DISTANCE_E_S = 149.6 * (10**6)
DISTANCE_MARS_SUN = 149_597_870.7 * 1.6

module ZOrder
  BG, SOBJECT, SHIP, UI, IND = *0..4
end
