"""
    module RigidBody

module that consists variables and functions needed for the simulation of rigid body spacecraft attitude dynamics

# Usage
```
# Include module `RigidBody.jl`
include("RigidBody.jl")
using .RigidBody

"""
module RigidBody

using ..TimeLine
using ..Disturbance

export runsimulation

"""
    struct RigidBodyModel

Struct of rigid body spacecraft model
"""
struct RigidBodyModel
    # Inertia Matrix
    inertia::Matrix
end

# Equation of dynamics
"""
    calc_differential_dynamics(model::RigidBodyModel, currentTime, angular_velocity, current_body_frame)

Get the differential of equation of dynamics.

# Arguments
- model::RigidBodyModel
- currentTime: current time of system [s]
- angular_velocity: angular velocity of body frame with respect to ECI frame [rad/s]
- current_body_frame: current body frame [b1 b2 b3]

# return
- differential: differential of equation of motion
"""
function calc_differential_dynamics(model::RigidBodyModel, currentTime, angular_velocity, current_body_frame, disturbance)

    # skew matrix of angular velocity vector
    skewOmega = [
        0 -angular_velocity[3] angular_velocity[2]
        angular_velocity[3] 0 -angular_velocity[1]
        -angular_velocity[2] angular_velocity[1] 0]

    # calculate differential of equation of motion
    differential = inv(model.inertia) * (disturbance - current_body_frame' * model.inertia * skewOmega * current_body_frame * current_body_frame' * angular_velocity)

    return differential
end


# Equation of Quaternion
"""
    calc_differential_kinematics(omega::Vector, quaterion::Vector)

Get differential of quaternion from equation of kinematics

# Arguments
- omega: angular velocity of system
- quaterion: current value of quaternion

# Return
- differential: differential of equation of kinematics
"""
function calc_differential_kinematics(angular_velocity, quaternion)

    OMEGA = [
        0 angular_velocity[3] -angular_velocity[2] angular_velocity[1]
        -angular_velocity[3] 0 angular_velocity[1] angular_velocity[2]
        angular_velocity[2] -angular_velocity[1] 0 angular_velocity[3]
        -angular_velocity[1] -angular_velocity[2] -angular_velocity[3] 0
    ]

    differential = 1/2 * OMEGA * quaternion

    return differential
end

"""
    function calc_angular_velocity(model::RigidBodyModel, currentTime, angular_velocity::Vector, Tsampling, currentbodyframe::Frame, disturbance::Vector)

calculate angular velocity at next time step using 4th order Runge-Kutta method
"""
function calc_angular_velocity(model::RigidBodyModel, currentTime, angular_velocity::Vector, Tsampling, currentbodyframe::TimeLine.Frame, disturbance::Vector)

    # define body frame matrix from struct `TimeLine.Frame`
    bodyframematrix = hcat(currentbodyframe.x, currentbodyframe.y, currentbodyframe.z)

    k1 = calc_differential_dynamics(model, currentTime              , angular_velocity                   , bodyframematrix, disturbance)
    k2 = calc_differential_dynamics(model, currentTime + Tsampling/2, angular_velocity + Tsampling/2 * k1, bodyframematrix, disturbance)
    k3 = calc_differential_dynamics(model, currentTime + Tsampling/2, angular_velocity + Tsampling/2 * k2, bodyframematrix, disturbance)
    k4 = calc_differential_dynamics(model, currentTime + Tsampling  , angular_velocity + Tsampling   * k3, bodyframematrix, disturbance)

    nextOmega = angular_velocity + Tsampling/6 * (k1 + 2*k2 + 2*k3 + k4)

    return nextOmega
end

"""
    function calc_angular_velocity(model::RigidBodyModel, currentTime, angular_velocity::Vector, Tsampling, currentbodyframe::Tuple{Vector, Vector, Vector}, disturbance::Vector)

calculate angular velocity at next time step using 4th order Runge-Kutta method
"""
function calc_angular_velocity(model::RigidBodyModel, currentTime, angular_velocity::Vector, Tsampling, currentbodyframe::Tuple{Vector, Vector, Vector}, disturbance::Vector)

    # define body coordinate frame matrix
    bodyframematrix = hcat(currentbodyframe[1], currentbodyframe[2], currentbodyframe[3])

    k1 = calc_differential_dynamics(model, currentTime              , angular_velocity                   , bodyframematrix, disturbance)
    k2 = calc_differential_dynamics(model, currentTime + Tsampling/2, angular_velocity + Tsampling/2 * k1, bodyframematrix, disturbance)
    k3 = calc_differential_dynamics(model, currentTime + Tsampling/2, angular_velocity + Tsampling/2 * k2, bodyframematrix, disturbance)
    k4 = calc_differential_dynamics(model, currentTime + Tsampling  , angular_velocity + Tsampling   * k3, bodyframematrix, disturbance)

    nextOmega = angular_velocity + Tsampling/6 * (k1 + 2*k2 + 2*k3 + k4)

    return nextOmega
end

# Update the quaternion vector (time evolution)
"""
    update_quaternion(angular_velocity, currentQuaternion, Tsampling)

calculate quaternion at next time step using 4th order Runge-Kutta method.
"""
function calc_quaternion(angular_velocity, quaternion, Tsampling)
    # Update the quaterion vector using 4th order runge kutta method

    k1 = calc_differential_kinematics(angular_velocity, quaternion                   );
    k2 = calc_differential_kinematics(angular_velocity, quaternion + Tsampling/2 * k1);
    k3 = calc_differential_kinematics(angular_velocity, quaternion + Tsampling/2 * k2);
    k4 = calc_differential_kinematics(angular_velocity, quaternion + Tsampling   * k3);

    nextQuaternion = quaternion + Tsampling/6 * (k1 + 2*k2 + 2*k3 + k4);

    return nextQuaternion
end

"""
    ECI2BodyFrame(q)

Calculate the transformation matrix from ECI frame to spacecraft body-fixed frame.

# Arguments
- `q`: quaternion

# Return
- `transformation_matrix`: transformation matrix
"""
function ECI2BodyFrame(q)

    # Check if the quaterion satisfies its constraint
    try
        constraint = q[1]^2 + q[2]^2 + q[3]^2 + q[4]^2

    catch constraint

        if constraint < 0.995
            error("Quaternion does not satisfy constraint")
        elseif constraint > 1.005
            error("Quaternion does not satisfy constraint")
        end
    end

    transformation_matrix = [
        q[1]^2 - q[2]^2 - q[3]^2 + q[4]^2  2*(q[1]*q[2] + q[3]*q[4])          2*(q[1]*q[3] - q[2]*q[4])
        2*(q[2]*q[1] - q[3]*q[4])          q[2]^2 - q[3]^2 - q[1]^2 + q[4]^2  2*(q[2]*q[3] + q[1]*q[4])
        2*(q[3]*q[1] + q[2]*q[4])          2*(q[3]*q[2] - q[1]*q[4])          q[3]^2 - q[1]^2 - q[2]^2 + q[4]^2
    ]

    return transformation_matrix
end

"""
    function runsimulation(model::RigidBodyModel, ECI_frame::TimeLine.Frame, initvalue::TimeLine.InitData, simulation_time::Real, Tsampling::Real)::TimeLine.DataTimeLine

Run simulation of spacecraft attitude dynamics with rigid body modeling

```
"""
function runsimulation(model::RigidBodyModel, ECI_frame::TimeLine.Frame, initvalue::TimeLine.InitData, distconfig::DisturbanceConfig, simulation_time::Real, Tsampling::Real)::TimeLine.DataTimeLine

    # Numbers of simulation data
    datanum = floor(Int, simulation_time/Tsampling) + 1;

    # Initialize data array
    simdata = TimeLine.DataTimeLine(initvalue, Tsampling, datanum)

    for loopCounter = 0:datanum - 1

        # Update current time (second)
        currenttime = simdata.time[loopCounter + 1]

        # Update current attitude
        C = ECI2BodyFrame(simdata.quaternion[:, loopCounter + 1])
        currentbodyframe = (C * ECI_frame.x, C * ECI_frame.y, C * ECI_frame.z)

        simdata.bodyframes[loopCounter + 1] = currentbodyframe

        # Disturbance torque
        disturbance = disturbanceinput(distconfig)

        # Time evolution of the system
        if loopCounter != datanum - 1

            # Update angular velocity
            simdata.angularvelocity[:, loopCounter + 2] = calc_angular_velocity(model, simdata.time[loopCounter + 1], simdata.angularvelocity[:, loopCounter + 1], Tsampling, currentbodyframe, disturbance)

            # Update quaternion
            simdata.quaternion[:, loopCounter + 2] = calc_quaternion(simdata.angularvelocity[:,loopCounter + 1], simdata.quaternion[:, loopCounter + 1], Tsampling)

        end

    end

    return simdata
end

end
