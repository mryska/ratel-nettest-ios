/*********************************************************************************
* Copyright 2013 appscape gmbh
* Copyright 2014-2015 SPECURE GmbH
* 
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
* 
*   http://www.apache.org/licenses/LICENSE-2.0
* 
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*********************************************************************************/

//
//  ControlServer.swift
//  RMBT
//
//  Created by Benjamin Pucher on 04.02.15.
//  Copyright (c) 2015 Specure GmbH. All rights reserved.
//

import Foundation

///
typealias EmptyCallback = () -> ()

///
typealias SuccessCallback = (response: AnyObject/*TODO*/) -> ()

///
typealias ErrorCallback = (error: NSError, info: NSDictionary?/*TODO*/) -> ()

///
@objc class ControlServer {

    ///
    let LAST_NEWS_UID_PREFERENCE_KEY = "last_news_uid"

    //

    ///
    var uuidKey: String!

    ///
    var uuidQueue: dispatch_queue_t = dispatch_queue_create("at.rtr.rmbt.controlserver.uuid", DISPATCH_QUEUE_SERIAL)

    ///
    var historyFilters: [String:[String]]!

    ///
    var openTestBaseURL: String?

    //

    ///
    private var defaultMapServerURL: NSURL!
    var mapServerURL: NSURL {
        var _mapServerURL: NSURL!

        let settings = RMBTSettings.sharedSettings()

        if (settings.debugUnlocked && settings.debugMapServerCustomizationEnabled) {
            // use provided custom map server

            let urlComponents = NSURLComponents()
            urlComponents.host = settings.debugMapServerHostname
            urlComponents.port = settings.debugMapServerPort > 0 ? settings.debugMapServerPort : ((settings.debugMapServerUseSSL) ? 443 : 80)
            urlComponents.scheme = (settings.debugMapServerUseSSL) ? "https" : "http"
            urlComponents.path = RMBT_MAP_SERVER_PATH

            logger.debug("try to use custom map server url: \(urlComponents.URL)")

            _mapServerURL = urlComponents.URL // can be nil if user provided wrong arguments, no problem, because of following if
        }

        return (_mapServerURL != nil) ? _mapServerURL : defaultMapServerURL
    }

    //

    ///
    var ipv4RequestUrl: String = RMBT_CONTROL_SERVER_IPV4_URL + "/ip"

    ///
    var ipv6RequestUrl: String = RMBT_CONTROL_SERVER_IPV6_URL + "/ip"

    //

    ///
    private var manager: AFHTTPRequestOperationManager!

    ///
    var lastNewsUid: UInt? {
        didSet {
            NSUserDefaults.standardUserDefaults().setObject(lastNewsUid, forKey: LAST_NEWS_UID_PREFERENCE_KEY)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }

    ///
    var uuid: String?

    //

    ///
    class var sharedControlServer : ControlServer {
        struct Static {
            static let instance = ControlServer()
        }
        return Static.instance
    }

    ///
    init() {
        updateWithCurrentSettings()
    }

    ///
    func updateWithCurrentSettings() {
        let settings: RMBTSettings = RMBTSettings.sharedSettings()

        var urlString: String = RMBT_CONTROL_SERVER_URL

        if (settings.debugUnlocked && settings.debugForceIPv6) {
            assert(!settings.forceIPv4, "Force IPv4 and IPv6 should be mutually exclusive")
            urlString = RMBT_CONTROL_SERVER_IPV6_URL
        } else if (settings.forceIPv4) {
            urlString = RMBT_CONTROL_SERVER_IPV4_URL
        }

        var baseURL = NSURL(string: urlString)! // !

        // control server url
        if (settings.debugUnlocked && settings.debugControlServerCustomizationEnabled) { // TODO: check for host and port not nil
            let scheme: String = settings.debugControlServerUseSSL ? "https" : "http"
            var hostname: String = settings.debugControlServerHostname

            if (settings.debugControlServerPort != 0 && settings.debugControlServerPort != 80) {
                hostname = hostname.stringByAppendingFormat(":%lu", UInt64(settings.debugControlServerPort))
            }

            baseURL = NSURL(scheme:scheme, host: hostname, path: RMBT_CONTROL_SERVER_PATH)!
            uuidKey = String(format: "uuid_%@", baseURL.host!) // !
        } else {
            // For UUID storage key, always take the default hostname to avoid getting 2 different UUIDs for
            // ipv4-only and regular control server URLs
            uuidKey = String(format: "uuid_%@", NSURL(string: RMBT_CONTROL_SERVER_URL)!.host!) // !
        }

        // map server url
        defaultMapServerURL = NSURL(string: RMBT_MAP_SERVER_URL)!

        //

        manager = AFHTTPRequestOperationManager(baseURL: baseURL)

        manager.requestSerializer = AFJSONRequestSerializer() as AFHTTPRequestSerializer // cast as workaround for strange error
        manager.responseSerializer = AFJSONResponseSerializer()

        uuid = NSUserDefaults.standardUserDefaults().objectForKey(uuidKey) as? String // ?correct?

        if let lastNewsUidNumber: NSNumber = NSUserDefaults.standardUserDefaults().objectForKey(LAST_NEWS_UID_PREFERENCE_KEY) as? NSNumber { // ?correct?
            lastNewsUid = lastNewsUidNumber.unsignedLongValue
        } else {
            lastNewsUid = 0
        }

        // also get settings (TODO: WHEN TO GET SETTINGS REALLY?)
        getSettings({
            // do nothing
        }, error: { error, info in
            // do nothing
        })
    }

    ///
    func getSettings(success: EmptyCallback, error failure: ErrorCallback) {
        //logger.debug("REQUESTING SETTINGS FROM CONTROL SERVER: \(baseURL())")

        requestWithMethod("POST", path: "settings", params: ["terms_and_conditions_accepted": true], success: { (response: AnyObject/*TODO*/) in

            logger.debug("\(response)")

            let res = response as! NSDictionary

            // TODO: check "error" in json
            if let error = res["error"] as? [String] {
                if (error.count > 0) {
                    // TODO: there was an error, TODO: improve
                    let nserror = NSError(domain: "controlServer", code: 10000, userInfo: ["err": error[0]])
                    failure(error: nserror, info: ["err": error[0]])
                }
            }

            let resSettings = res["settings"] as! NSArray // TODO: EXC_BAD_INSTRUCTION, fatal error: unexpectedly found nil while unwrapping an Optional value
            let s = resSettings[0] as! NSDictionary

            // If we didn't have UUID yet and server is sending us one, save it for future requests
            if (self.uuid == nil && s["uuid"] != nil) {
                self.uuid = s["uuid"] as? String

                NSUserDefaults.standardUserDefaults().setObject(self.uuid!, forKey: self.uuidKey)
                NSUserDefaults.standardUserDefaults().synchronize()
                //logger.debug("Got new uuid \(self.uuid)")
            }

            self.historyFilters = s["history"] as? [String:[String]]

            if let urls = s["urls"] as? [String:String] {
                self.openTestBaseURL = urls["open_data_prefix"]

                self.ipv4RequestUrl = urls["url_ipv4_check"] ?? self.ipv4RequestUrl
                self.ipv6RequestUrl = urls["url_ipv6_check"] ?? self.ipv6RequestUrl
            }

            // check for map server from settings
            if let mapServer = s["map_server"] as? [String:AnyObject] {
                let host = mapServer["host"] as! String
                let scheme = ((mapServer["ssl"] as! NSNumber).integerValue == 1) ? "https" : "http"

                var port = (mapServer["port"] as! NSNumber).stringValue // TOOD: improve this logic...
                if (port == "80" || port == "443") {
                    port = ""
                } else {
                    port = ":\(port)"
                }

                self.defaultMapServerURL = NSURL(string: "\(scheme)://\(host)\(port)\(RMBT_MAP_SERVER_PATH)")!
                logger.debug("setting map server url to \(self.defaultMapServerURL) from settings request")
            }

            // TODO

            // get names for QOSTestType
            if let qostesttypeDesc = s["qostesttype_desc"] as? [[String:String]] {
                for testType in qostesttypeDesc {
                    if let t = QOSTestType(rawValue: testType["test_type"]!.lowercaseString) {
                        QOSTestType.localizedNameDict[t] = testType["name"]!
                    }
                }

                //logger.debug("found localized test type names: \(QOSTestType.localizedNameDict)")
            }

            success()

        }) { error, info in
            //RMBTLog("Error getting settings (error=%@, response=%@)", error, info)
            failure(error: error, info: info)
        }
    }

    ///
    func getNews(success: SuccessCallback) {
        //RMBTLog("Getting news (lastNewsUid=%ld)...", lastNewsUid)

        requestWithMethod("POST", path: "result", params: ["lastNewsUid": "\(lastNewsUid)"], success: { (response: AnyObject/*TODO*/) in

            // TODO: check "error" in json

            let res = response as! [String:[AnyObject]]

            if let news = res["news"] as? [[String:AnyObject]] {
                var maxNewsUid: UInt = 0

                var result = [RMBTNews]()
                for subresponse in news {
                    var n: RMBTNews = RMBTNews(response: subresponse)
                    result.append(n)

                    if (n.uid > maxNewsUid) {
                        maxNewsUid = n.uid
                    }
                }

                if (maxNewsUid > 0) {
                    self.lastNewsUid = maxNewsUid
                }

                success(response: result)
            } else {
                // error
            }

        }) { error, info in
            // error
            //failure(error: error, info: info)
        }
    }

    ///
    func getRoamingStatusWithParams(params: NSDictionary, success: SuccessCallback) {
        logger.debug("Checking roaming status (params = \(params))")

        performWithUUID({

            self.requestWithMethod("POST", path: "status", params: params, success: { response in

                // TODO: check "error" in json

//                if let homeCountry = response["home_country"] as? NSNumber {
//                    if (!homeCountry.boolValue) {
//                        success(response: true)
//                    }
//                }
//
//                success(response: false)

                let roaming = (response["home_country"] as? NSNumber)?.boolValue == false ?? false
                success(response: roaming)

            }, error: { error, info in

            })

        }, error: { error, info in

        })
    }

    ///
    func getTestParamsWithParams(params: NSDictionary, success: SuccessCallback, error errorCallback: EmptyCallback) {
        var requestParams: NSMutableDictionary = NSMutableDictionary(dictionary:[
            "ndt": false,
            "time": RMBTTimestampWithNSDate(NSDate())
        ])

        requestParams.addEntriesFromDictionary(params as [NSObject : AnyObject])

        performWithUUID({

            self.requestWithMethod("POST", path: "", params: requestParams, success: { response in

                // TODO: check "error" in json

                let tp = RMBTTestParams(response: response as! [NSObject : AnyObject])
                success(response: tp)

            }, error: { error, info in
                //RMBTLog("Fetching test parameters failed with err=%@, response=%@", error, info)
                errorCallback()
            })

        }, error: { error, info in
            errorCallback()
        })
    }

    ///
    func submitResult(result: NSDictionary, success: SuccessCallback, error failure: EmptyCallback) {
        var mergedParams = NSMutableDictionary()
        mergedParams.addEntriesFromDictionary(result as [NSObject : AnyObject])

        var systemInfo = systemInfoParams()

        // Note:
        // Unlike /settings, the /result resource expects "name" and "version" params
        // to be prefixed as "client_"

        // can't cast [String:AnyObject] to NSDictionary...
        //let c = [
        //    "client_name":              systemInfo["client"],
        //    "client_version":           systemInfo["version"],
        //    "client_language":          systemInfo["language"],
        //    "client_software_version":  systemInfo["softwareVersion"]
        //]
        var clientParams = NSMutableDictionary()

        clientParams.setObject(systemInfo["client"]!,           forKey: "client_name")
        clientParams.setObject(systemInfo["version"]!,          forKey: "client_version")
        clientParams.setObject(systemInfo["language"]!,         forKey: "client_language")
        clientParams.setObject(systemInfo["softwareVersion"]!,  forKey: "client_software_version")

        mergedParams.addEntriesFromDictionary(clientParams as [NSObject : AnyObject])

        //logger.debug("Submit \(mergedParams)")

        requestWithMethod("POST", path: "result", params: mergedParams, success: { (response: AnyObject/*TODO*/) in

            // TODO: check "error" in json
            if let res = response as? NSDictionary {
                if let resErr = res["error"] as? NSArray {

                    if (resErr.count == 0) {
                        //RMBTLog(@"Test result submitted")
                        success(response: NSArray()) /*TODO, empty array instead of nil*/
                        return
                    }
                }
            }

            //RMBTLog("Error subitting rest result: %@", response["error"])
            failure()

        }) { error, info in
            //RMBTLog("Error submitting result err=%@, response=%@", error, info)
            failure()
        }
    }

    ///
    func getHistoryWithFilters(filters: NSDictionary?, length: UInt, offset: UInt, success: SuccessCallback, error errorCallback: ErrorCallback) {
        var params: NSMutableDictionary = NSMutableDictionary(dictionary: [
            "result_offset": NSNumber(unsignedLong: offset),
            "result_limit": NSNumber(unsignedLong: length)
        ])

        if (filters != nil) {
            params.addEntriesFromDictionary(filters! as [NSObject : AnyObject])
        }

        performWithUUID({

            self.requestWithMethod("POST", path: "history", params: params, success: { response in

                // TODO: check "error" in json

                // TODO: check for errors
                success(response: (response as! NSDictionary)["history"] as! NSArray) /*TODO*/

            }, error: { error, info in
                //RMBTLog("Error fetching history with filters (error=%@, info=%@)", error, info)
                errorCallback(error: error, info: info)
            })

        }, error: { error, info in
            errorCallback(error: error, info: info)
        })
    }

    ///
    func getHistoryResultWithUUID(uuid: String, fullDetails: Bool, success: SuccessCallback, error errorCallback: ErrorCallback) {
        let key = fullDetails ? "testresultdetail" : "testresult"

        performWithUUID({

            self.requestWithMethod("POST", path: key, params: ["test_uuid": uuid], success: { response in

                //logger.debug("wfewfwfwef")
                //logger.debug("\(response)")

                // TODO: check "error" in json

                let res = response as! NSDictionary

                if let r: AnyObject = res[key] {

                    if (fullDetails) {
                        success(response: r as! NSObject) /*TODO*/
                    } else {
                        success(response: (r as! NSArray).objectAtIndex(0) as! NSObject) /*TODO*/
                    }
                }

            }, error: { error, info in
                //RMBTLog("Error fetching history result (uuid=%@, error=%@, info=%@)", uuid, error, info)

                logger.debug("wfewfwfwef2")
                logger.debug("\(error), \(info)")

                errorCallback(error: error, info: info)
            })

        }, error: { error, info in
            logger.debug("wfewfwfwef3")
            logger.debug("\(error), \(info)")

            errorCallback(error: error, info: info)
        })
    }

    ///////////////////////////
    // QOS
    ///////////////////////////

    ///
    func getQOSObjectives(success: SuccessCallback, error errorCallback: ErrorCallback) {
        self.requestWithMethod("POST", path: "qosTestRequest", params: ["a": "b"] /*TODO*/, success: { response in
            // TODO: check "error" in json

            success(response: response)
        }, error: { error, info in
            errorCallback(error: error, info: info)
        })
    }

    ///
    func submitQOSTestResult(result: [String:AnyObject], success: EmptyCallback, error errorCallback: ErrorCallback) {
        var mergedParams = NSMutableDictionary()
        mergedParams.addEntriesFromDictionary(result)

        var systemInfo = systemInfoParams()

        var clientParams = NSMutableDictionary()
        clientParams.setObject(systemInfo["client"]!,           forKey: "client_name")
        clientParams.setObject(systemInfo["version"]!,          forKey: "client_version")
        clientParams.setObject(systemInfo["language"]!,         forKey: "client_language")
        clientParams.setObject(systemInfo["softwareVersion"]!,  forKey: "client_software_version")

        mergedParams.addEntriesFromDictionary(clientParams as [NSObject : AnyObject])

        performWithUUID({

            self.requestWithMethod("POST", path: "resultQoS", params: mergedParams, success: { response in

                // TODO: check "error" in json

                success()

            }, error: { error, info in
                errorCallback(error: error, info: info)
            })

        }, error: { error, info in
            errorCallback(error: error, info: info)
        })
    }

    ///
    func getQOSHistoryResultWithUUID(testUuid: String, success: SuccessCallback, error errorCallback: ErrorCallback) {
        performWithUUID({

            self.requestWithMethod("POST", path: "qosTestResult", params: ["test_uuid": testUuid], success: { response in

                // TODO: check "error" in json

                success(response: response)

            }, error: { error, info in
                //RMBTLog("Error fetching qos hstory result (uuid=%@, error=%@, info=%@)", uuid, error, info)
                errorCallback(error: error, info: info)
            })

        }, error: { error, info in
            errorCallback(error: error, info: info)
        })
    }

    ///////////////////////////

    ///
    func getSyncCode(success: SuccessCallback, error errorCallback: ErrorCallback) {
        performWithUUID({

            self.requestWithMethod("POST", path: "sync", params: [:], success: { response in

                // TODO: check "error" in json

                logger.debug("get sync code: \(response)")

                if let res = (response as! NSDictionary)["sync"] as? NSArray { /*TODO*/
                    let syncDictionary: NSDictionary = res.objectAtIndex(0) as! NSDictionary /*TODO*/
                    success(response: syncDictionary["sync_code"]! as! NSObject) /*TODO*/
                }

            }, error: { error, info in
                //RMBTLog("Error fetching sync code (error=%@, info=%@)", error, info)
                //errorCallback(error: error, info: info) //?
            })

        }, error: { error, info in
            errorCallback(error: error, info: info)
        })
    }

    ///
    func syncWithCode(code: String, success: EmptyCallback, error errorCallback: ErrorCallback) {
        performWithUUID({

            self.requestWithMethod("POST", path: "sync", params: ["sync_code": code], success: { response in

                logger.debug("sync code response: \(response)")

                // TODO: check "error" in json

                if let res = (response as! NSDictionary)["sync"] as? NSArray { /*TODO*/
                    let syncDictionary: NSDictionary = res.objectAtIndex(0) as! NSDictionary /*TODO*/

                    if (syncDictionary["success"] != nil && (syncDictionary["success"] as! NSNumber).unsignedIntegerValue > 0) {
                        success()
                    } else {
                        // TODO title and text extract here
                        errorCallback(error: NSError(domain: "RMBTControlServer", code: 0, userInfo: syncDictionary as [NSObject : AnyObject]), info: (response as! NSDictionary)) /*TODO*/
                    }
                }

            }, error: { error, info in
                //RMBTLog("Error syncing (code=%@, error=@, info=%@)", code, error, info)
                errorCallback(error: error, info: info)
            })

        }, error: { error, info in
            errorCallback(error: error, info: info)
        })
    }

// MARK: logs

    ///
    func submitLogFile(logFileJson: [String:AnyObject], success: EmptyCallback, error errorCallback: ErrorCallback) {
        performWithUUID({

            self.requestWithMethod("POST", path: "log", params: logFileJson, success: { response in

                // TODO: check "error" in json

                success()

            }, error: { error, info in
                errorCallback(error: error, info: info)
            })

        }, error: { error, info in
            errorCallback(error: error, info: info)
        })
    }

// MARK: convenience methods

    ///
    func performWithUUID(callback: EmptyCallback, error errorCallback: ErrorCallback) {
        dispatch_async(uuidQueue) {
            if let uuid = self.uuid {
                callback()
            } else {
                dispatch_suspend(self.uuidQueue)

                self.getSettings({

                    dispatch_resume(self.uuidQueue)
                    if let uuid = self.uuid {
                        callback()
                    } else {
                        assert(false, "Couldn't obtain UUID from control server")
                    }

                }, error: { error, info in
                    dispatch_resume(self.uuidQueue)
                    errorCallback(error: error, info: info)
                })
            }
        }
    }

    ///
    func requestWithMethod(method: String, path: String, params: NSDictionary/*TODO*/, success: SuccessCallback, error failure: ErrorCallback) {
        var mergedParams = NSMutableDictionary()

        if let uuid = self.uuid {
            mergedParams.setObject(uuid, forKey: "uuid")
        }

        mergedParams.addEntriesFromDictionary(systemInfoParams())
        mergedParams.addEntriesFromDictionary(params as [NSObject : AnyObject])

        //logger.debug("Requesting \(mergedParams)")

        manager.requestSerializer = AFJSONRequestSerializer() as AFHTTPRequestSerializer // cast as workaround for strange error

        var requestError: NSError?
        // TODO: check requestError

        let urlString: String = baseURL().absoluteString!.stringByAppendingString(path)

        let request: NSMutableURLRequest = self.manager.requestSerializer.requestWithMethod(method, URLString: urlString, parameters: mergedParams, error: &requestError)

        let operation = self.manager.HTTPRequestOperationWithRequest(request, success: { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) in

            // TODO: improve
            if (operation.response.statusCode < 400) {
                success(response: responseObject as! NSObject)
            } else {
                let error = NSError()
                failure(error: error, info: nil)
            }

        }, failure: { (operation: AFHTTPRequestOperation!, error: NSError!) in

            if (error != nil && error.code == Int(CFNetworkErrors.CFURLErrorCancelled.rawValue)) {
                return  // Ignore cancelled requests
            }

            failure(error: error, info: nil/*operation.responseString*/) // TODO: no response object?
        })

        operation.start()
    }

// MARK: - System Info

    ///
    func systemInfoParams() -> [String:AnyObject] {
        let infoDictionary = NSBundle.mainBundle().infoDictionary! // !
        let currentDevice = UIDevice.currentDevice()

        return [
            "plattform":            "iOS",
            "os_version":           RMBTValueOrNull(currentDevice.systemVersion),
            "model":                RMBTValueOrNull(systemInfoDeviceInternalModel()),
            "device":               RMBTValueOrNull(currentDevice.model),
            "language":             RMBTValueOrNull(RMBTPreferredLanguage()),
            "timezone":             RMBTValueOrNull(NSTimeZone.systemTimeZone().name),
            "product":              RMBTValueOrNull(nil), // always null...
            "api_level":            RMBTValueOrNull(nil), // always null...
            "type":                 "MOBILE",
            "name":                 "RMBT",
            "client":               "RMBT",
            "version":              "0.3",
            "softwareVersion":      RMBTValueOrNull(infoDictionary["CFBundleShortVersionString"]),
            "softwareVersionCode":  RMBTValueOrNull(infoDictionary["CFBundleVersion"]),
            "softwareRevision":     RMBTValueOrNull(RMBTBuildInfoString())
        ]
    }

    ///
    func systemInfoDeviceInternalModel() -> String {
        return UIDeviceHardware.platform()
    }

    ///
    func baseURL() -> NSURL {
        return self.manager.baseURL
    }

    ///
    func baseURLString() -> String {
        return self.manager.baseURL!.absoluteString!
    }

    ///
    func cancelAllRequests() {
        self.manager.operationQueue.cancelAllOperations()
    }
}
