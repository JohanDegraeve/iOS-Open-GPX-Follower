//
//  GPXTrackPointDistance.swift
//  OpenGpxTracker
//
//  Created by Johan Degraeve on 30/08/2021.
//

import Foundation
import CoreGPX

/// struct to hold a gpxTrackPoint + a distance in meters, to be used as distance from start
struct GPXTrackPointDistance {
    
    /// the GPXTrackPoint
    let gpxTrackPoint: GPXTrackPoint
    
    /// distance from start
    let distance: Double
    
}
