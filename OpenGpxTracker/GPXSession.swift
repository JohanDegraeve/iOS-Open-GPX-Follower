//
//  GPXSession.swift
//  OpenGpxFollower
//
//    Based on Open GPX Tracker. Orignal source created by Vincent Neo on 13/6/19.
//

import Foundation
import CoreGPX
import CoreLocation

/// GPX creator identifier. Used on generated files identify this app created them.
let kGPXCreatorString = "Open GPX Tracker for iOS"


///
/// Handles the actual logging of waypoints and trackpoints.
///
/// Addition of waypoints, trackpoints, and the handling of adding trackpoints to tracksegments and tracks all happens here.
/// Exporting the data as a GPX string is also done here as well.
///
/// Should not be used directly on iOS, as code origins from `GPXMapView`.
///
class GPXSession {
    
    /// List of waypoints currently displayed on the map.
    var waypoints: [GPXWaypoint] = []
    
    /// List of tracks currently displayed on the map.
    var tracks: [GPXTrack] = []
    
    /// Current track segments
    var trackSegments: [GPXTrackSegment] = []
    
    /// Segment in which device locations are added.
    var currentSegment: GPXTrackSegment =  GPXTrackSegment()
    
    /// Total tracked distance in meters
    var totalTrackedDistance = 0.00
    
    /// Distance in meters of current track (track in which new user positions are being added)
    var currentTrackDistance = 0.00
    
    /// Current segment distance in meters
    var currentSegmentDistance = 0.00
    
    ///
    /// Adds a waypoint to the map.
    ///
    /// - Parameters: The waypoint to add to the map.
    ///
    func addWaypoint(_ waypoint: GPXWaypoint) {
        self.waypoints.append(waypoint)
    }
    
    ///
    /// Removes a Waypoint from current session
    ///
    /// - Parameters: The waypoint to remove from the session.
    ///
    func removeWaypoint(_ waypoint: GPXWaypoint) {
        let index = waypoints.firstIndex(of: waypoint)
        if index == nil {
            print("Waypoint not found")
            return
        }
        waypoints.remove(at: index!)
    }
    
    ///
    /// Appends currentSegment to trackSegments and initializes currentSegment to a new one.
    ///
    func startNewTrackSegment() {
        if self.currentSegment.trackpoints.count > 0 {
            self.trackSegments.append(self.currentSegment)
            self.currentSegment = GPXTrackSegment()
            self.currentSegmentDistance = 0.00
        }
    }
    
    ///
    /// Clears all data held in this object.
    ///
    func reset() {
        self.trackSegments = []
        self.tracks = []
        self.currentSegment = GPXTrackSegment()
        self.waypoints = []
        
        self.totalTrackedDistance = 0.00
        self.currentTrackDistance = 0.00
        self.currentSegmentDistance = 0.00
        
    }
    
    ///
    ///
    /// Converts current sessionn into a GPX String
    ///
    ///
    func exportToGPXString() -> String {
        print("Exporting session data into GPX String")
        //Create the gpx structure
        let gpx = GPXRoot(creator: kGPXCreatorString)
        gpx.add(waypoints: self.waypoints)
        let track = GPXTrack()
        track.add(trackSegments: self.trackSegments)
        //add current segment if not empty
        if self.currentSegment.trackpoints.count > 0 {
            track.add(trackSegment: self.currentSegment)
        }
        //add existing tracks
        gpx.add(tracks: self.tracks)
        //add current track
        gpx.add(track: track)
        return gpx.gpx()
    }
    
    func continueFromGPXRoot(_ gpx: GPXRoot) {
        
        let lastTrack = gpx.tracks.last ?? GPXTrack()
        totalTrackedDistance += lastTrack.length
        
        //add track segments
        self.tracks = gpx.tracks
        self.trackSegments = lastTrack.tracksegments
        
        // remove last track as that track is packaged by Core Data, but should its tracksegments should be seperated, into self.tracksegments.
        self.tracks.removeLast()
        
    }
    
}
