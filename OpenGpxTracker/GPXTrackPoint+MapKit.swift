//
//  GPXPoint+MapKit.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 20/09/14.
//

import Foundation
import UIKit
import MapKit
import CoreGPX

/// Extends the GPXTrackPoint to be able to be initialized with a `CLLocation` object.
extension GPXTrackPoint {

    /// to be able to add var in extension
    struct Holder {
        
        /// distance form start in meters
        static var _distanceFromStart: CLLocationDistance?
        
    }
    
    /// distance form start in meters
    var distanceFromStart: CLLocationDistance? {
        get {
            return Holder._distanceFromStart
        }
        set(newValue) {
            Holder._distanceFromStart = newValue
        }
    }

    /// Initializes a trackpoint with the CLLocation data
    convenience init(location: CLLocation) {
        self.init()
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.time = Date()
        self.elevation = location.altitude
    }
}
