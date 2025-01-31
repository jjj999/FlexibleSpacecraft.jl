"""
    module Orbit

Informations about spacecraft orbit
"""
module Orbit

"""
    struct CircularOrbit(_radius::Float64, _gravityconstant::Float64)

Parameters of a circular orbit

## Arguments

* `_radius`: radius of orbit (m)
* `_gravityconstant`: standard gravitational parameter ``μ = GM``

## Initialize

```
# Define circular orbit of Earth
orbit = Orbit.CircularOrbit(6370e+3, 3.986e+14)
```

"""
struct CircularOrbit

    _radius::Float64
    _gravityconstant::Float64

    # Constructor
    CircularOrbit(_radius::Float64, _gravityconstant::Float64) = begin
        # check if the field is appropriatelly configured
        if _radius < 0
            error("Orbit radius should be non-negative.")
        end
        if _gravityconstant < 0
            error("Gravity constant should be non-negative.")
        end

        new(_radius, _gravityconstant)
    end
end

"""
    struct OrbitalElements

Struct of orbital elements (keplerian elements)

# Constructor

`OrbitalElements(Ω, i, a, e, ω, f)`

* `Ω`: right ascention of ascending node (degree)
* `i`: inclination (degree)
* `a`: semimajor axis (m)
* `e`: eccentricity
* `ω`: argument of perigee (degree)
* `f`: true anomaly at epoch(degree)

"""
struct OrbitalElements

    # Orientation of the orbital plane
    ascention
    inclination

    # Shape of the ellipse
    semimajor_axis
    eccentricity

    # Defines the orientation of the ellipse in the orbital plane
    arg_perigee

    # Reference point on orbit
    true_anomaly

    # Constructor
    OrbitalElements(Ω, i, a, e, ω, f) = begin

        # Check if the arguments are appropriate
        if !(0 <= Ω < 360)
            throw(DomainError(Ω, "Argument `Ω` exceeds appropriate domain. (0 <= Ω < 360)"))
        end

        if !(0 <= i < 360)
            throw(DomainError(i, "Argument `i` exceeds appropriate domain. (0 <= i < 360)"))
        end

        if !(a > 0)
            throw(DomainError(a, "Argument `a` should be positive real number."))
        end

        if !(e >= 0)
            throw(DomainError(e, "Argument `e` should be positive real number."))
        end

        if !(0 <= ω < 360)
            throw(DomainError(ω, "Argument `ω` exceeds appropriate domain. (0 <= ω < 360)"))
        end

        if !(0 <= f < 360)
            throw(DomainError(f, "Argument `f` exceeds appropriate domain. (0 <= ω < 360)"))
        end

        new(Ω, i, a, e, ω, f)
    end

end

"""
    function get_angular_velocity(orbit::CircularOrbit)

Calculates orbit angular velocity of a circular orbit
"""
function get_angular_velocity(orbit::CircularOrbit)

    return sqrt(orbit._gravityconstant / orbit._radius^3)

end

"""
    function get_velocity(orbit::CircularOrbit)

Calculates orbit velocity of a circular orbit. This is not angular velocity!
"""
function get_velocity(orbit::CircularOrbit)

    return sqrt(orbit._gravityconstant / orbit._radius)

end

"""
    function get_timeperiod(orbit::CircularOrbit; unit = "second")

Calculates orbit time period (second)

# Arguments

* `orbit::CircularOrbit`: struct of orbit information
* `unit`: keyword argument that defines unit of the return value
    * second
    * minute

"""
function get_timeperiod(orbit::CircularOrbit; unit = "second")

    if unit == "second"

        return 2 * pi / get_angular_velocity(orbit)

    elseif unit == "minute"

        return (2 * pi / get_angular_velocity(orbit))/60

    else
        error("keyword argument `unit` is set improperly.")
    end

end

"""
    function ECI2OrbitalPlaneFrame(elements::OrbitalElements)


"""
function ECI2OrbitalPlaneFrame(elements::OrbitalElements)

    C1 = i -> begin
        i = deg2rad(i)
        [1 0 0
        0 cos(i) sin(i)
        0 -sin(i) cos(i)]
    end

    C3 = Ω -> begin
        Ω = deg2rad(Ω)
        [cos(Ω) sin(Ω) 0
        -sin(Ω) cos(Ω) 0
        0 0 1]
    end

    return C1(elements.inclination) * C3(elements.ascention)

end

"""
    function OrbitalPlaneFrame2RadialAlongTrack(elements::OrbitalElements, angular_velocity, time)

Calculates transformation matrix from OrbitalPlaneFrame to Radial Along Track frame
"""
function OrbitalPlaneFrame2RadialAlongTrack(elements::OrbitalElements, angular_velocity, time)

    C1 = u -> begin
        [cos(u) sin(u) 0
        -sin(u) cos(u) 0
        0 0 1]
    end

    # current angle of spacecraft relative to ascending axis of orbital plane frame
    current_position = deg2rad(elements.true_anomaly) + angular_velocity * time

    return C1(current_position)

end

"""
    function OrbitalPlaneFrame2LVLH(OrbitalPlaneFrame2RadialAlongTrack)

Calculates transformation matrix from OrbitalPlaneFrame frame to LVLH
"""
function OrbitalPlaneFrame2LVLH(C_OrbitalPlaneFrame2RadialAlongTrack)

    C = [  C_OrbitalPlaneFrame2RadialAlongTrack[2,:]';
          -C_OrbitalPlaneFrame2RadialAlongTrack[3,:]';
          -C_OrbitalPlaneFrame2RadialAlongTrack[1,:]']

    return C

end

end
