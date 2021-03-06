//
//  GPXTrackSegment+MapKit.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 20/09/14.
//

import Foundation
import UIKit
import MapKit
import CoreGPX

///
/// This extension adds some methods to work with MapKit
///
#if os(iOS)
extension GPXTrackSegment {
    
    /// Returns a MapKit polyline with the points of the segment.
    /// This polyline can be directly plotted on the map as an overlay
    public var overlay: MKPolyline {
        var coords: [CLLocationCoordinate2D] = self.trackPointsToCoordinates()
        let pl = MKPolyline(coordinates: &coords, count: coords.count)
        return pl
    }
}
#endif

extension GPXTrackSegment {
  
    /// Helper method to create the polyline. Returns the array of coordinates of the points
    /// that belong to this segment
    func trackPointsToCoordinates() -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        for point in self.trackpoints {
            coords.append(point.coordinate)
        }
        return coords
    }
    
    /// Calculates length in meters of the segment
    /// - parameters:
    ///     - actualDistanceFromStart : the function will iterate through each GPXTrackPoint and set in each GPXTrackPoint the distance from the start of the session. actualDistanceFromStart will be added to this length, so after having finished the function, every GPXTrackPoint in the segment will know the distance from the start of the session
    ///     - trackPointDistances : array of GPXTrackPointDistance to which new instance of GPXTrackPointDistance will be appended based on new list of GPXTrackPoints in this segment, each with distance from start
    func length(actualDistanceFromStart: CLLocationDistance, trackPointDistances:inout [GPXTrackPointDistance]) -> CLLocationDistance {
        var length: CLLocationDistance = 0.0
        var distanceTwoPoints: CLLocationDistance
        //we need at least two points
        if self.trackpoints.count < 2 {
            return length
        }
        var prev: CLLocation? //previous
        for point in self.trackpoints {
            let pt: CLLocation = CLLocation(latitude: Double(point.latitude!), longitude: Double(point.longitude!) )
            if prev == nil { //if first point => set it as previous and go for next
                prev = pt

                // add the first point to trackPointDistances
                trackPointDistances.append(GPXTrackPointDistance(gpxTrackPoint: point, distance: length + actualDistanceFromStart))
                
                continue
            }
            
            distanceTwoPoints = pt.distance(from: prev!)
            length += distanceTwoPoints
            //set current point as previous point
            prev = pt

            // append GPXTrackPointDistance to trackPointDistances
            trackPointDistances.append(GPXTrackPointDistance(gpxTrackPoint: point, distance: length + actualDistanceFromStart))
            
        }
        return length
    }    
}
