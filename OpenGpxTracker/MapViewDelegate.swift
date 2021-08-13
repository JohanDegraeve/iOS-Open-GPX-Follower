//
//  Localized by nitricware on 19/08/19.
//

import MapKit
import CoreGPX

/// Handles all delegate functions of the GPX Mapview
///
class MapViewDelegate: NSObject, MKMapViewDelegate, UIAlertViewDelegate {

    /// The Waypoint is being edited (if there is any)
    var waypointBeingEdited: GPXWaypoint = GPXWaypoint()
    
    /// Displays the line for each segment
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKind(of: MKTileOverlay.self) {
            return mapView.mapCacheRenderer(forOverlay: overlay)
        }
        
        if overlay is MKPolyline {
            let pr = MKPolylineRenderer(overlay: overlay)
            
            pr.alpha = 0.8
            pr.strokeColor = UIColor.blue
            
            if #available(iOS 13, *) {
                pr.shouldRasterize = true
                if mapView.traitCollection.userInterfaceStyle == .dark {
                    pr.alpha = 0.5
                    pr.strokeColor = UIColor.blue
                }
            }
            
            pr.lineWidth = 10
            return pr
        }
        return MKOverlayRenderer()
    }
    
    /// Updates map heading after user interactions end.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        guard let map = mapView as? GPXMapView else {
            return
        }
        
        print("MapView: User interaction has ended")
        
        map.updateHeading()
        
    }
    
}
