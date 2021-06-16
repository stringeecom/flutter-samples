import UIKit
import Flutter
import PushKit
import flutter_voip_push_notification

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
        
    // Handle updated push credentials
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void){
//        print("Payload: \(payload.dictionaryPayload)")
        guard let payloadDataDic = (payload.dictionaryPayload as NSDictionary).value(forKeyPath: "data.map.data.map") as? [String: Any] else {
            return
        }
        
//        print("payloadDataDic: \(payloadDataDic)")
        
        let callId: String = payloadDataDic["callId"] as? String ?? ""
        let serial: Int = payloadDataDic["serial"] as? Int ?? 0
        let callStatus: String = payloadDataDic["callStatus"] as? String ?? ""
        let fromAlias: String = (payloadDataDic as NSDictionary).value(forKeyPath: "from.map.alias") as? String ?? ""
        let fromNumber: String = (payloadDataDic as NSDictionary).value(forKeyPath: "from.map.number") as? String ?? ""
        let callerName: String = fromAlias != "" ? fromAlias : (fromNumber != "" ? fromNumber : "Connecting...")
        print("callId: \(callId), serial: \(serial), callStatus: \(callStatus), fromAlias: \(fromAlias), fromNumber: \(fromNumber), callerName: \(callerName)")
        
        let uuid = NSUUID().uuidString.lowercased()
        FlutterCallKitPlugin.reportNewIncomingCall(uuid, handle: fromNumber, handleType: "generic", hasVideo: false, localizedCallerName: callerName, fromPushKit: true)
        
        var parsedData = [String: Any]()
        parsedData["callId"] = callId
        parsedData["serial"] = serial
        parsedData["callStatus"] = callStatus
        parsedData["uuid"] = uuid

        // Register VoIP push token (a property of PKPushCredentials) with server
//        FlutterVoipPushNotificationPlugin.didReceiveIncomingPush(with: payload, forType: type.rawValue)
        NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "voipRemoteNotificationReceived"), object: self, userInfo: parsedData)
    }

    // Handle incoming pushes
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        // Process the received push
        FlutterVoipPushNotificationPlugin.didUpdate(pushCredentials, forType: type.rawValue);
    }
    
}
