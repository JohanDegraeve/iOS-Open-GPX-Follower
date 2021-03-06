//
//  GPXTrack+length.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 30/09/15.
//

import Foundation
import MapKit
import CoreGPX

/// Extension to support getting the distance of a track in meters.
extension GPXTrack {
    
    /// Calculates length in meters of the track
    /// - parameters:
    ///     - actualDistanceFromStart : during calculation of the track length, every GPXTrackPoint will get the distance from the start of the session. actualDistanceFromStart will be added to this length, so after having call the length function, every GPXTrackPoint in each segment in the track will know the distance from the start of the session
    ///     - trackPointDistances : array of GPXTrackPointDistance to which new instance of GPXTrackPointDistance will be appended based on new list of GPXTrackPoints in this track, each with distance from start
    func length(actualDistanceFromStart: CLLocationDistance, trackPointDistances:inout [GPXTrackPointDistance]) -> CLLocationDistance {
        var trackLength: CLLocationDistance = 0.0
        for segment in tracksegments {
            trackLength += segment.length(actualDistanceFromStart: actualDistanceFromStart + trackLength, trackPointDistances: &trackPointDistances)
        }
        return trackLength
    }    
}
