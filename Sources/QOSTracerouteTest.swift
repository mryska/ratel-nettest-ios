/*********************************************************************************
* Copyright 2014-2015 SPECURE GmbH
* 
* Redistribution and use of the RMBT code or any derivative works are 
* permitted provided that the following conditions are met:
* 
*   - Redistributions may not be sold, nor may they be used in a commercial 
*     product or activity.
*   - Redistributions that are modified from the original source must include 
*     the complete source code, including the source code for all components
*     used by a binary built from the modified sources. However, as a special 
*     exception, the source code distributed need not include anything that is 
*     normally distributed (in either source or binary form) with the major 
*     components (compiler, kernel, and so on) of the operating system on which 
*     the executable runs, unless that component itself accompanies the executable.
*   - Redistributions must reproduce the above copyright notice, this list of 
*     conditions and the following disclaimer in the documentation and/or
*     other materials provided with the distribution.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
* BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
* DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
* LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
* OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
* OF THE POSSIBILITY OF SUCH DAMAGE.
*********************************************************************************/

//
//  QOSTracerouteTest.swift
//  RMBT
//
//  Created by Benjamin Pucher on 05.12.14.
//  Copyright (c) 2014 Specure GmbH. All rights reserved.
//

import Foundation

///
class QOSTracerouteTest : QOSTest {
    
    let PARAM_HOST = "host"
    let PARAM_MAX_HOPS = "max_hops"
    
    //
    
    var host: String?
    var maxHops: UInt8 = 64
    
    /// config values not configured on server
    var noResponseTimeout: NSTimeInterval = 1 // x seconds
    var bytesPerPackage: UInt16 = 72 // 72 bytes
    var triesPerTTL: UInt8 = 1 // x tries per ttl
    ///
    
    //
    
    ///
    override var description: String {
        return super.description + ", [host: \(host), maxHops: \(maxHops), noResponseTimeout: \(noResponseTimeout), bytesPerPackage: \(bytesPerPackage), triesPerTTL: \(triesPerTTL)]"
    }
    
    //
    
    ///
    override init(testParameters: QOSTestParameters) {
        if let host = testParameters[PARAM_HOST] as? String {
            // TODO: length check on host?
            self.host = host
        }
        
        // max hops
        if let maxHopsString = testParameters[PARAM_MAX_HOPS] as? String {
            if let maxHops = maxHopsString.toInt() {
                self.maxHops = UInt8(maxHops)
            }
        }
        
        super.init(testParameters: testParameters)
    }
    
    ///
    override func getType() -> QOSTestType! {
        return .TRACEROUTE
    }
}
