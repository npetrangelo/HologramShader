//
//  ViewController.swift
//  HologramShader
//
//  Created by qe on 4/14/22.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {
    var mtkView: MTKView!
    var renderer: Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        mtkView = MTKView()
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView!]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView!]))
        
        let device = getMTLDevice()
        print(device.name)
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        
        renderer = Renderer(view: mtkView, device: device)
        mtkView.delegate = renderer
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func getMTLDevice() -> MTLDevice {
//        let devices = MTLCopyAllDevices()
//        for device in devices {
//            if device.isRemovable {
//                return device
//            }
//        }
        
        return MTLCreateSystemDefaultDevice()!
    }
}

