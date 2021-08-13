import Foundation

protocol AddGPXFileViewControllerDelegate: class {
    
    /// called when file was successfully downloaded and stored
    func finishedLoadingGPXFile()
    
}
