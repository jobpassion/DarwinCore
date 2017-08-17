//
//  ViewController.swift
//  macOSTest
//
//  Created by yarshure on 2016/11/19.
//  Copyright © 2016年 Kong XiangBo. All rights reserved.
//
import Foundation
import Cocoa
import DarwinCore

class ViewController: NSViewController,ClientDelegate {
    let r = DNSResolver()
    var clients:[Client] = []
    let que = DispatchQueue.init(label: "server")
    var clientTree:AVLTree = AVLTree<Int32,Client>()
    override func viewDidLoad() {
        super.viewDidLoad()
        test()
        testServer()
        // Do any additional setup after loading the view.
    }
    func clientDead(c:Client){
        let fd = c.fd
        close(fd)
        
        
    }

    func testServer(){
        if let server = GCDSocketServer.shared(){
            server.accept = { fd,addr,port in
                let c = Client.init(sfd: fd, delegate: self, q: DispatchQueue.main)
                //self.clients.append(c);
                self.clientTree.insert(key: fd, payload: c)
                c.connect()
                print("\(fd) \(String(describing: addr)) \(port)")
            }
            server.colse = { fd in
                print("\(fd) close")
                //self.clientTree.delete(key: fd)
                if let c = self.clientTree.search(input: fd){
                    c.forceClose()
                    self.clientTree.delete(key: fd)
                }
            }
            server.incoming  = { fd ,data in
                print("\(fd) \(String(describing: data))")
//                for c in self.clients {
//                    if c.fd == fd {
//                        c.incoming(data: data!)
//                    }
//                }
                if let c = self.clientTree.search(input: fd){
                    c.incoming(data: data!)
                }
                //server.server_write_request(fd, buffer: "wello come\n", total: 11);
            }
            //let q = DispatchQueue.init(label: "dispatch queue")
            server.start(10081, queue: DispatchQueue.main)
        }
    }
    func test()  {
        DNS.loadSystemDNSServer()
       
        testReolover(host: "www.freebsdchina.org")
        
    }
    func testReolover(host:String) {
        r.hostname = "www.freebsdchina.org"
        r.querey(host) { (record) in
            
            if let record = record {
                print(record.ipaddress)
            }else {
                print("error")
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

