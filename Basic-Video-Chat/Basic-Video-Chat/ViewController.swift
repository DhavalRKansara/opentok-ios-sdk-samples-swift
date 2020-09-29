//
//  ViewController.swift
//  Hello-World
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok
import MLKit

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
let kApiKey = "46716702"
let kSessionId = "2_MX40NjcxNjcwMn5-MTYwMTI3OTQxMDIxOX5qL0prOXhoWS9ZeTVJTk9EMDlVNzB1alR-fg"
let kToken = "T1==cGFydG5lcl9pZD00NjcxNjcwMiZzaWc9Njk5OWIzNDQ0ZmIwYWUzYTc2OGE4ODgxNzNjMjk3ZTIyYzJjZmVmYjpzZXNzaW9uX2lkPTJfTVg0ME5qY3hOamN3TW41LU1UWXdNVEkzT1RReE1ESXhPWDVxTDBwck9YaG9XUzlaZVRWSlRrOUVNRGxWTnpCMWFsUi1mZyZjcmVhdGVfdGltZT0xNjAxMzgxMzQzJm5vbmNlPTAuNjcxNzIwODQ4OTM2MTEyNiZyb2xlPXB1Ymxpc2hlciZleHBpcmVfdGltZT0xNjAxNDAyOTQxJmluaXRpYWxfbGF5b3V0X2NsYXNzX2xpc3Q9"

let kWidgetHeight = 240
let kWidgetWidth = 320
var options = FaceDetectorOptions()


class ViewController: UIViewController {
        
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    lazy var publisher1: OTPublisher = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        settings.cameraFrameRate = .rate30FPS
        settings.cameraResolution = .high
        return OTPublisher(delegate: self, settings: settings)!
    }()
    
    var subscriber1: OTSubscriber?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // High-accuracy landmark detection and face classification
        let options = FaceDetectorOptions()
        options.performanceMode = .accurate
        options.landmarkMode = .all
        options.classificationMode = .all
        
        // Real-time contour detection of multiple faces
         options.contourMode = .all
        
        doConnect()
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    fileprivate func doConnect() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.connect(withToken: kToken, error: &error)
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session. OTPubilsher
     * binds to the device camera and microphone, and will provide A/V streams
     * to the OpenTok session.
     */
    fileprivate func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.publish(publisher1, error: &error)
        
        if let pubView = publisher1.view {
            pubView.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(pubView)
        }
        
    }
    
    /**
     * Instantiates a subscriber for the given stream and asynchronously begins the
     * process to begin receiving A/V content for this stream. Unlike doPublish,
     * this method does not add the subscriber to the view hierarchy. Instead, we
     * add the subscriber only after it has connected and begins receiving data.
     */
    fileprivate func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            processError(error)
        }
        subscriber1 = OTSubscriber(stream: stream, delegate: self)
        
        session.subscribe(subscriber1!, error: &error)
        
    }
    
    fileprivate func cleanupSubscriber() {
        subscriber1?.view?.removeFromSuperview()
        subscriber1 = nil
    }
    
    fileprivate func cleanupPublisher() {
        publisher1.view?.removeFromSuperview()
    }
    
    fileprivate func processError(_ error: OTError?) {
        if let err = error {
            DispatchQueue.main.async {
                let controller = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(controller, animated: true, completion: nil)
            }
        }
    }
}

// MARK: - OTSession delegate callbacks
extension ViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        if subscriber1 == nil {
            doSubscribe(stream)
        }
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        if let subStream = subscriber1?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
    
    
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        
        print("Publishing")
        if let pubView = publisher1.view {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                
                let myImage = pubView.screenshot()
                let imageView = UIImageView(image: myImage)
                imageView.frame = CGRect(x: 0, y: kWidgetHeight, width: kWidgetWidth, height: kWidgetHeight)
                self.view.addSubview(imageView)
                
                self.faceDetection(myImage: myImage)

            }
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        cleanupPublisher()
        if let subStream = subscriber1?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
    
}

// MARK: - OTSubscriber delegate callbacks
extension ViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        if let subsView = subscriber1?.view {
            subsView.frame = CGRect(x: 0, y: kWidgetHeight, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(subsView)
        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
        
        let myImage = self.subscriber1?.view?.takeScreenshot()
        
//        let imageView = UIImageView(image: myImage)
//        imageView.frame = CGRect(x: 0, y: kWidgetHeight*2, width: kWidgetWidth, height: kWidgetHeight)
//        imageView.backgroundColor = UIColor.yellow
//        imageView.contentMode = .scaleToFill
//        self.view.addSubview(imageView)
        
        faceDetection(myImage: myImage)
    }
    
    func faceDetection(myImage : UIImage?){
        if let image = myImage {
            let visionImage = VisionImage(image: image)
            visionImage.orientation = image.imageOrientation
            
            let faceDetector = FaceDetector.faceDetector(options: options)
            
            faceDetector.process(visionImage) { faces, error in
                if error == nil, let detectedFaces: [Face] = faces, !detectedFaces.isEmpty {
                    print(" ********************** No Face Found ************************")
                    
                    if (detectedFaces.first?.smilingProbability ?? 0) > 0.6 {
                        print("====================== smiling ================================")
                    }
                }else{
                    print("No Face Found")
                }
            }
            
        }
    }
}

extension UIView {
    
    func screenshot() -> UIImage {
        return UIGraphicsImageRenderer(size: bounds.size).image { _ in
            drawHierarchy(in: CGRect(origin: .zero, size: bounds.size), afterScreenUpdates: true)
        }
    }
    
    func takeScreenshot() -> UIImage {
        
        // Begin context
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale)
        
        // Draw view in that context
        drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        
        // And finally, get image
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if (image != nil)
        {
            return image!
        }
        return UIImage()
    }
}
