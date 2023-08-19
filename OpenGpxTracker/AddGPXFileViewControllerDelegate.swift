import Foundation

protocol AddGPXFileViewControllerDelegate: AnyObject {
    
    /// called when file was successfully downloaded and stored
    func finishedLoadingGPXFile()
    
}
