function stoppingDistance {
    return ((ship:verticalspeed^2)/(2 * ((ship:availableThrust / ship:mass) - (constant():g * (body:mass / body:radius^2))))).
}
function distanceToGround {
    return altitude - body:geoPositionOf(ship:position):terrainHeight - 22.
}
function getImpactPosition {
    if ADDONS:TR:AVAILABLE {
        if ADDONS:TR:HASIMPACT {
            LOCAL impactPos is ADDONS:TR:IMPACTPOS.
            set coordinates to list(impactPos:LAT, impactPos:LNG).
            return coordinates.
        }
        else {
            PRINT "Impact position is not available".
        }
    }
    else {
        PRINT "Trajectories is not available.".
    }
}

function ascent {
    parameter desiredApoapsis.
    print "[BEGINNING ASCENT]".
    sas off.
    rcs on.
    ag1 on.
    lock throttle to 1.
    stage.
    set targetAngle to 0.
    set turnStartAltitude to 1000.
    set turnEndAltitude to 45000.
    until ship:apoapsis >= desiredApoapsis {
        set currentAltitude to ship:altitude.
        if currentAltitude > turnStartAltitude {
            set targetAngle to min(70, (currentAltitude - turnStartAltitude) / (turnEndAltitude - turnStartAltitude) * 70).
        }
        lock steering to Up + R(0, -targetAngle, 180).
        if ship:apoapsis >= desiredApoapsis - 2500 {
            lock throttle to 0.1.
        }
    }
    lock throttle to 0.
    lock steering to prograde * R(0,0,-90).
    wait until alt:radar >= 50000.
    ag3 on.
    lock steering to "kill".
    stage.
    wait 10.
    ag4 on.
    print "[ASCENT COMPLETE]".
}
function flip {
    print "[BEGINNING FLIP]".
    lock targetHeading to heading(retrograde:pitch + 90, 180, -90).
    lock steering to targetHeading.
    brakes on.
    wait until round(ship:facing:pitch, 0) = round(targetHeading:pitch, 0) and round(ship:facing:yaw, 0) = round(targetHeading:yaw, 0) and round(ship:facing:roll, 0) = round(targetHeading:roll, 0).
    wait 2.
    lock steering to "kill".
    print "[FLIP COMPLETE]".
}
function boostBackBurn {
    parameter lat.
    parameter lng.

    print "[BEGINNING BOOST BACK BURN]".
    lock throttle to 0.35.

    //wait until getImpactPosition()[0] <= lat and getImpactPosition()[1] <= lng.
    wait until getImpactPosition()[1] <= lng.

    lock throttle to 0.
    lock steering to srfRetrograde * R(0,0,-90).
    print "[BOOST BACK BURN COMPLETE]".
}
function entryBurn {
    print "[BEGINNING ENTRY BURN]".
    wait until alt:radar <= 25000.
    lock throttle to 1.

    wait until ship:velocity:surface:mag <= 400.
    lock throttle to 0.
    print "[ENTRY BURN COMPLETE]".
}
function aeroGuide {
    parameter lat.
    parameter lng.
    print "[BEGINNING AERO GUIDE]".
    until alt:radar <= 2000{
        set pitchError to round(abs(getImpactPosition()[0] - lat) * 200, 2).
        set yawError to round(abs(getImpactPosition()[1] - lng) * 200, 2).

        if round(getImpactPosition()[0], 3) > round(lat, 3){
            set pitch to (3 + pitchError).
            if pitch > 15 {
                set pitch to 15.
            }
        }
        else if round(getImpactPosition()[0], 3) < round(lat, 3){
            set pitch to (-3 - pitchError).
            if pitch < -15 {
                set pitch to -15.
            }
        }
        else{
            set pitch to 0.
        }

        if round(getImpactPosition()[1], 3) > round(lng, 3){
            set yaw to (3 + yawError).
            if yaw > 15 {
                set yaw to 15.
            }
        }
        else if round(getImpactPosition()[1], 3) < round(lng, 3){
            set yaw to (-3 - yawError).
            if yaw < -15 {
                set yaw to -15.
            }
        }
        else{
            set yaw to 0.
        }
        lock steering to R(srfRetrograde:pitch, srfRetrograde:yaw, (Up:roll + 180)) * R(pitch, yaw, 0).
    }
    lock steering to R(srfRetrograde:pitch, srfRetrograde:yaw, (Up:roll + 180)).
    print "[AERO GUIDE COMPLETE]".
}
function suicideBurn {
    parameter vehicleHeightOffset.
    print "[BEGINNING SUICIDE BURN / LANDING]".
    wait until alt:radar <= 1500.
    toggle gear.
    lock pct to (stoppingDistance() / (alt:radar - vehicleHeightOffset)).
    wait until pct > 1.
    lock throttle to pct.
    wait until round(ship:groundspeed, 1) = 0.
    lock steering to Up + R(0,0,180).
    wait until ship:verticalspeed > 0.
    lock throttle to 0.
    print "[SUICIDE BURN / LANDING COMPLETE]".
    wait 1.
    rcs off.
    sas off.
    brakes off.
}

set targetApoapsis to 85000.
set targetLat to ship:geoPosition:lat.
set targetLng to ship:geoPosition:lng.
set heightOffset to round((alt:radar + 1.4), 2).

clearscreen.
print "Target Apopapsis: " + round((targetApoapsis/1000), 1) + "km".
print "Target Coordinates: " + round(targetLat, 4) + " " + round(targetLng, 4).
print "Height Offset: " + heightOffset + "m".

wait 10.

ascent(targetApoapsis).
flip().
boostBackBurn(targetLat, targetLng).
entryBurn().
aeroGuide(targetLat, targetLng).
suicideBurn(heightOffset).

print "Landing Coordinates: " + round(ship:geoPosition:lat, 4) + " " + round(ship:geoPosition:lng, 4).
print "Distance From Target: " + round(latlng(targetLat, targetLng):distance - ship:geoPosition:distance, 0) + "m".