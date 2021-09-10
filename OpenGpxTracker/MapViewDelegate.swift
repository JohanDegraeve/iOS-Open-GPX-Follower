//
//  Localized by nitricware on 19/08/19.
//

import MapKit
import CoreGPX

/// Handles all delegate functions of the GPX Mapview
///
class MapViewDelegate: NSObject, MKMapViewDelegate, UIAlertViewDelegate {

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
            
            if overlay is FatMKPolyline {
                pr.lineWidth = 12
            } else {
                pr.lineWidth = 4
            }
            return pr
        }
        return MKOverlayRenderer()
    }
    
    /// Adds the pin to the map with an animation (comes from the top of the screen)
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {

        var i = 0

        let gpxMapView = mapView as! GPXMapView
        var hasImpacted = false
        
        //adds the pins with an animation
        for object in views {
            i += 1
            let annotationView = object as MKAnnotationView
            
            //The only exception is the user location, we add to this the heading icon.
            if annotationView.annotation!.isKind(of: MKUserLocation.self) {
                if gpxMapView.headingImageView == nil {
                    let image = UIImage(named: "heading")!
                    gpxMapView.headingImageView = UIImageView(image: image)
                    gpxMapView.headingImageView!.frame = CGRect(x: (annotationView.frame.size.width - image.size.width)/2,
                                                                y: (annotationView.frame.size.height - image.size.height)/2,
                                                                width: image.size.width,
                                                                height: image.size.height)
                    annotationView.insertSubview(gpxMapView.headingImageView!, at: 0)
                    gpxMapView.headingImageView!.isHidden = true
                }
                continue
            }
            
            let point: MKMapPoint = MKMapPoint.init(annotationView.annotation!.coordinate)
            if !mapView.visibleMapRect.contains(point) { continue }
            
            let endFrame: CGRect = annotationView.frame
            annotationView.frame = CGRect(x: annotationView.frame.origin.x, y: annotationView.frame.origin.y - mapView.superview!.frame.size.height,
                                          width: annotationView.frame.size.width, height: annotationView.frame.size.height)
            let interval: TimeInterval = 0.04 * 1.1
            UIView.animate(withDuration: 0.5, delay: interval, options: UIView.AnimationOptions.curveLinear, animations: { () -> Void in
                annotationView.frame = endFrame
            }, completion: { (finished) -> Void in
                if finished {
                    UIView.animate(withDuration: 0.05, animations: { () -> Void in
                        //aV.transform = CGAffineTransformMakeScale(1.0, 0.8)
                        annotationView.transform = CGAffineTransform(a: 1.0, b: 0, c: 0, d: 0.8, tx: 0, ty: annotationView.frame.size.height*0.1)
                        
                    }, completion: { _ -> Void in
                        UIView.animate(withDuration: 0.1, animations: { () -> Void in
                            annotationView.transform = CGAffineTransform.identity
                        })
                        if #available(iOS 10.0, *), !hasImpacted {
                            hasImpacted = true
                            UIImpactFeedbackGenerator(style: i > 2 ? .heavy : .medium).impactOccurred()
                        }
                    })
                }
            })
        }
    }
    

}
