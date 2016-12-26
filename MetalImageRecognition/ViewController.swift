//
//  ViewController.swift
//  MetalImageRecognition
//
//  Created by Jeffrey Jiahai Luo on 25/12/2016.
//  Copyright © 2016 El Root. All rights reserved.
//

import UIKit
import MetalKit
import MetalPerformanceShaders
import Accelerate
import AVFoundation


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // some properties used to control the app and store appropriate values
    var Net: Inception3Net? = nil
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var textureLoader : MTKTextureLoader!
    var ciContext : CIContext!
    var sourceTexture : MTLTexture? = nil
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        
        // Load default device.
        device = MTLCreateSystemDefaultDevice()
        
        // Make sure the current device supports MetalPerformanceShaders.
        guard MPSSupportsMTLDevice(device) else {
            print("Metal Performance Shaders not Supported on current Device")
            return
        }
        
        // Load any resources required for rendering.
        
        // Create new command queue.
        commandQueue = device!.makeCommandQueue()
        
        // make a textureLoader to get our input images as MTLTextures
        textureLoader = MTKTextureLoader(device: device!)
        
        // Load the appropriate Network
        Net = Inception3Net(withCommandQueue: commandQueue)
        
        // we use this CIContext as one of the steps to get a MTLTexture
        ciContext = CIContext.init(mtlDevice: device)
        
    }
    
    /**
     This function is to conform to UIImagePickerControllerDelegate protocol,
     contents are executed after the user selects a picture he took via camera
     */
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        // get taken picture as UIImage
        let uiImg = info[UIImagePickerControllerEditedImage] as! UIImage
        
        // display the image in UIImage View
        predictView.image = uiImg
        
        // use CGImage property of UIImage
        var cgImg = uiImg.cgImage
        
        // check to see if cgImg is valid if nil, UIImg is CIImage based and we need to go through that
        // this shouldn't be the case with our example
        if cgImg == nil {
            // our underlying format was CIImage
            var ciImg = uiImg.ciImage
            if ciImg == nil {
                // this should never be needed but if for some reason both formats fail, we create a CIImage
                // change UIImage to CIImage
                ciImg = CIImage(image: uiImg)
            }
            // use CIContext to get a CGImage
            cgImg = ciContext.createCGImage(ciImg!, from: ciImg!.extent)
        }
        
        // get a texture from this CGImage
        do {
            sourceTexture = try textureLoader.newTexture(with: cgImg!, options: [:])
        }
        catch let error as NSError {
            fatalError("Unexpected error ocurred: \(error.localizedDescription).")
        }
        
        infoTextLabel.isHidden = true
        
        // to keep track of which image is being displayed
        dismiss(animated: true, completion: nil)
        
    }
    
    /**
     This function gets a commanBuffer and encodes layers in it. It follows that by commiting the commandBuffer and getting labels
     
     
     - Returns:
     Void
     */
    func runNetwork(){
        
        // to deliver optimal performance we leave some resources used in MPSCNN to be released at next call of autoreleasepool,
        // so the user can decide the appropriate time to release this
        autoreleasepool{
            // encoding command buffer
            let commandBuffer = commandQueue.makeCommandBuffer()
            
            // encode all layers of network on present commandBuffer, pass in the input image MTLTexture
            Net!.forward(commandBuffer: commandBuffer, sourceTexture: sourceTexture)
            
            // commit the commandBuffer and wait for completion on CPU
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // display top-5 predictions for what the object should be labelled
            let label = Net!.getLabel()
            predictText.text = label
            predictText.isHidden = false
        }
        
    }
    
    func setupViews() {
        navigationController?.navigationBar.backgroundColor = .white
        navigationController?.navigationBar.isTranslucent = false
        navigationItem.title = "MetalImageRecognition"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(handleReset))
        
        view.backgroundColor = .white
        
        view.addSubview(predictView)
        predictView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8).isActive = true
        predictView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        predictView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -16).isActive = true
        predictView.heightAnchor.constraint(equalTo: predictView.widthAnchor).isActive = true
        predictView.addSubview(infoTextLabel)
        infoTextLabel.centerXAnchor.constraint(equalTo: predictView.centerXAnchor).isActive = true
        infoTextLabel.centerYAnchor.constraint(equalTo: predictView.centerYAnchor).isActive = true
        infoTextLabel.widthAnchor.constraint(equalTo: predictView.widthAnchor, constant: -16).isActive = true
        infoTextLabel.heightAnchor.constraint(equalTo: predictView.heightAnchor, constant: -16).isActive = true
        
        view.addSubview(runButton)
        runButton.topAnchor.constraint(equalTo: predictView.bottomAnchor, constant: 8).isActive = true
        runButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8).isActive = true
        runButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1/2 ,constant: -12).isActive = true
        runButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        view.addSubview(chooseButton)
        chooseButton.topAnchor.constraint(equalTo: predictView.bottomAnchor, constant: 8).isActive = true
        chooseButton.leftAnchor.constraint(equalTo: runButton.rightAnchor, constant: 8).isActive = true
        chooseButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1/2 ,constant: -12).isActive = true
        chooseButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        view.addSubview(predictText)
        predictText.topAnchor.constraint(equalTo: runButton.bottomAnchor, constant: 8).isActive = true
        predictText.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8).isActive = true
        predictText.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -16).isActive = true
        predictText.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8).isActive = true
        
    }
    
    func handleRun() {
        if predictView.image != nil {
            // run the neural network to get predictions
            runNetwork()
        }
        
    }
    
    func handleChoose() {
        let alert = UIAlertController(title: "Choose Image", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { (UIAlertAction) in self.openCamera() })
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { (UIAlertAction) in self.openPhotoLibrary() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        
    }
    
    func openCamera() {
        let picker = UIImagePickerController()
        
        picker.delegate = self
        picker.sourceType = UIImagePickerControllerSourceType.camera
        picker.allowsEditing = true
    
        present(picker, animated: true, completion: nil)
        
    }
    
    func openPhotoLibrary() {
        let picker = UIImagePickerController()
        
        picker.delegate = self
        picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        picker.allowsEditing = true
        
        present(picker, animated: true, completion: nil)
        
    }
    
    func handleReset() {
        predictText.text = nil
        predictView.image = nil
        infoTextLabel.isHidden = false
        
    }
    
    let predictText: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.backgroundColor = .white
        textView.font = UIFont.preferredFont(forTextStyle: .callout)
        textView.layer.borderColor = UIColor.black.cgColor
        textView.layer.borderWidth = 1 / UIScreen.main.scale
        return textView
    }()
    
    let predictView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.layer.borderColor = UIColor.black.cgColor
        imageView.layer.borderWidth = 1 / UIScreen.main.scale
        return imageView
    }()
    
    let infoTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.text = "MetalImageRecognition: \nPerforming Image Recognition with Inception_v3 Network using Metal Performance Shaders Convolutional Neural Network routines\n\nThis sample demonstrates how to perform runtime inference for image recognition using a Convolutional Neural Network (CNN) built with Metal Performance Shaders. This sample is a port of the TensorFlow-trained Inception_v3 network, which was trained offline using the ImageNet dataset. The CNN creates, encodes, and submits different layers to the GPU. It then performs image recognition using trained parameters (weights and biases) that have been acquired and saved from the pre-trained network."
        label.textColor = .lightGray
        label.textAlignment = NSTextAlignment.left
        label.numberOfLines = 0
        label.sizeToFit()
        return label
    }()
    
    lazy var runButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.setTitle("Run Network", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 1 / UIScreen.main.scale
        button.addTarget(self, action: #selector(handleRun), for: .touchUpInside)
        return button
    }()
    
    lazy var chooseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.setTitle("Choose Image", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 1 / UIScreen.main.scale
        button.addTarget(self, action: #selector(handleChoose), for: .touchUpInside)
        return button
    }()
    
}

