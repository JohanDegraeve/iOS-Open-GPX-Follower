//
//  CLLocationCoordinate2D+BoundingBox.swift
//  OpenGpxTracker
//
//  Created by Raymond Pendergraph, 25/05/2017
//  https://gist.github.com/raypendergraph/0d053f2667313c16dcea9e961a533d06

import CoreLocation

extension CLLocationCoordinate2D {
    /**
     Calculates a bbox around this CLLocationCoordinat2D by describing a distance that is roughly analagous to
     the radius of a circle with a center at this coordinate and the radius is the distance and inscribes the circle
     to the bbox created.
     
     This tangential point method of calculating the box is described in Handbook of Mathematics By I.N. Bronshtein,
     K.A. Semendyayev, Gerhard Musiol, Heiner Mühlig
     
     - Remark: If you are using these coordinates to create a boolean based query you will need to take special note to check
     for the hemisphere of the corners.
     
     - Remark: Please email me at ray.pendergraph@gmx.com if you find issues with this implementation.
     
     - parameters:
     - distance: The radius of an inscribed circle on the desired bounding box centered on this coordinate.
     
     - returns: A tuple containing the southwest/bottomLeft and northeast/topRight corners of the bbox respectively.
     */
    func calculateBoundingCoordinates(withDistance distance: Double) -> (CLLocationCoordinate2D, CLLocationCoordinate2D) {
        
        let minimumLatitude = -90.0 * Double.pi / 180.0
        let maximumLatitude = 90.0 * Double.pi / 180.0
        let minimumLongitude = -180.0 * Double.pi / 180.0
        let maximumLongitude = 180.0 * Double.pi / 180.0
        
        let latitudeInRadians = latitude * Double.pi / 180.0
        let longitudeInRadians = longitude * Double.pi / 180.0
        let radiusMeters = 6371010.0
        
        
        let angularDistance = distance / radiusMeters
        var minLat = latitudeInRadians - angularDistance
        var maxLat = latitudeInRadians + angularDistance
        var minLon = 0.0
        var maxLon = 0.0
        if minLat > minimumLatitude && maxLat < maximumLatitude {
            let deltaLongitude = asin( sin(angularDistance) ) / cos(latitudeInRadians)
            minLon = longitudeInRadians - deltaLongitude
            
            if (minLon < minimumLongitude) {
                minLon += 2.0 * Double.pi
            }
            
            maxLon = longitudeInRadians + deltaLongitude
            
            if maxLon > maximumLongitude {
                maxLon -= 2.0 * Double.pi
            }
        }
        else {
            minLat = max(minLat, minimumLatitude)
            maxLat = min(maxLat, maximumLatitude)
            minLon = minimumLongitude
            maxLon = maximumLongitude
        }
        
        let coordinateFromRadians : (Double, Double) -> CLLocationCoordinate2D = {
            (latRadians, lonRadians) in
            
            let latDegrees = CLLocationDegrees(latRadians * 180.0 / Double.pi)
            let lonDegrees = CLLocationDegrees(lonRadians * 180.0 / Double.pi)
            return CLLocationCoordinate2D(latitude: latDegrees, longitude: lonDegrees)
        }
        
        return (coordinateFromRadians(minLat, minLon), coordinateFromRadians(maxLat, maxLon))
    }
    
    func formatAsLatLonString(withDecimalPlaces places: Int = 5) -> (String, String) {
        
        let latitudeString: String = {
            if latitude > 0.0 {
                return String(format: "lat %.\(places)fN", fabs(latitude))
            }
            else {
                return String(format: "lat %.\(places)fS", fabs(latitude))
            }
        }()
        
        let longitudeString: String = {
            if latitude > 0.0 {
                return String(format: "lon %.\(places)fE", fabs(longitude))
            }
            else {
                return String(format: "lon %.\(places)fW", fabs(longitude))
            }
        }()
        
        return (latitudeString, longitudeString)
        
        
    }
}
