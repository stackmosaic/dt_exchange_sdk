import Flutter
import UIKit
import IASDKCore

public class DtExchangeSdkPlugin: NSObject, FlutterPlugin, IAUnitDelegate, IAVideoContentDelegate, IAMRAIDContentDelegate, FlutterStreamHandler, DTXNativeImageContentDelegate {
    
    private var eventSink: FlutterEventSink?
    
    // Properties
    private var rewardedSpot: IAAdSpot?
    private var rewardedUnitController: IAFullscreenUnitController?
    
    // Content Controllers (Strong Reference to prevent deallocation)
    private var rewardedVideoContentController: IAVideoContentController?
    private var rewardedMRAIDContentController: IAMRAIDContentController?
    private var rewardedNativeImageContentController: DTXNativeImageContentController?
    
    private var interstitialSpot: IAAdSpot?
    private var interstitialUnitController: IAFullscreenUnitController?
    
    // Content Controllers (Strong Reference to prevent deallocation)
    private var interstitialVideoContentController: IAVideoContentController?
    private var interstitialMRAIDContentController: IAMRAIDContentController?
    private var interstitialNativeImageContentController: DTXNativeImageContentController?
    
    // MARK: - Flutter Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dt_exchange_sdk", binaryMessenger: registrar.messenger())
        let instance = DtExchangeSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "dt_exchange_sdk_events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        
        let factory = DtExchangeBannerFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "dt_exchange_banner_view")
    }
    
    // MARK: - Method Handling
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            if let args = call.arguments as? [String: Any],
               let appId = args["appId"] as? String {
                initializeSdk(appId: appId, result: result)
            } else {
                result(FlutterError(code: "MISSING_ARG", message: "App ID is required", details: nil))
            }
            
        case "loadRewardedVideo":
            if let args = call.arguments as? [String: Any],
               let spotId = args["spotId"] as? String {
                loadRewardedAd(spotId: spotId, result: result)
            } else {
                result(FlutterError(code: "MISSING_ARG", message: "Spot ID is required", details: nil))
            }
            
        case "showRewardedVideo":
            showRewardedAd(result: result)
            
        case "loadInterstitial":
            if let args = call.arguments as? [String: Any],
               let spotId = args["spotId"] as? String {
                loadInterstitialAd(spotId: spotId, result: result)
            } else {
                result(FlutterError(code: "MISSING_ARG", message: "Spot ID is required", details: nil))
            }
            
        case "showInterstitial":
            showInterstitialAd(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - SDK Logic: Initialization
    private func initializeSdk(appId: String, result: @escaping FlutterResult) {
        IASDKCore.sharedInstance().initWithAppID(appId, completionBlock: { [weak self] (success, error) in
            let statusStr = success ? "Success" : "Failed: \(error?.localizedDescription ?? "Unknown")"
            self?.sendEvent(type: "onInitialized", data: ["status": statusStr])
        }, completionQueue: nil)
        result(true)
    }
    
    // MARK: - SDK Logic: Rewarded Video
    private func loadRewardedAd(spotId: String, result: @escaping FlutterResult) {
        guard let adRequest = IAAdRequest.build({ builder in
            builder.spotID = spotId
            builder.timeout = 15
        }) else {
            result(FlutterError(code: "BUILD_ERROR", message: "Failed to build AdRequest", details: nil))
            return
        }
        
        self.rewardedVideoContentController = IAVideoContentController.build { [weak self] builder in
            builder.videoContentDelegate = self
        }
        
        self.rewardedMRAIDContentController = IAMRAIDContentController.build { [weak self] builder in
            builder.mraidContentDelegate = self
        }

        self.rewardedNativeImageContentController = DTXNativeImageContentController.build { [weak self] builder in
            builder.nativeImageContentDelegate = self
        }
        
        guard let unitController = IAFullscreenUnitController.build({ [weak self] builder in
            guard let self = self else { return }
            builder.unitDelegate = self
            if let video = self.rewardedVideoContentController {
                builder.addSupportedContentController(video)
            }
            if let mraid = self.rewardedMRAIDContentController {
                builder.addSupportedContentController(mraid)
            }
            if let native = self.rewardedNativeImageContentController {
                builder.addSupportedContentController(native)
            }
        }) else {
            result(FlutterError(code: "BUILD_ERROR", message: "Failed to build FullscreenUnitController", details: nil))
            return
        }
        
        self.rewardedUnitController = unitController
        
        self.rewardedSpot = IAAdSpot.build({ builder in
            builder.adRequest = adRequest
            builder.addSupportedUnitController(unitController)
        })
        
        self.rewardedSpot?.fetchAd { [weak self] (adSpot, model, error) in
             if let error = error {
                 print("❌ [SWIFT DEBUG] Rewarded Ad Load Failed! Error: \(error.localizedDescription)")
                 self?.sendEvent(type: "onAdLoadFailed", data: ["adType": "rewarded", "error": error.localizedDescription])
             } else {
                 print("✅ [SWIFT DEBUG] Rewarded Ad Loaded! Model: \(String(describing: model))")
                 self?.sendEvent(type: "onAdLoaded", data: ["adType": "rewarded"])
             }
        }
        
        result(true)
    }
    
    private func showRewardedAd(result: @escaping FlutterResult) {
        guard let controller = self.rewardedUnitController, let spot = self.rewardedSpot else {
             result(FlutterError(code: "NOT_READY", message: "Rewarded Ad not loaded", details: nil))
             return
        }
        
        print("🔍 [SWIFT DEBUG] Attempting to show Rewarded Ad. Spot Active Controller: \(String(describing: spot.activeUnitController))")
        
        if (spot.activeUnitController == controller) {
            controller.showAd(animated: true)
            result(true)
        } else {
             print("❌ [SWIFT DEBUG] Rewarded Ad mismatch or not ready.")
             result(FlutterError(code: "NOT_READY", message: "Rewarded Ad is not ready to show", details: nil))
        }
    }

    // MARK: - SDK Logic: Interstitial
    private func loadInterstitialAd(spotId: String, result: @escaping FlutterResult) {
        guard let adRequest = IAAdRequest.build({ builder in
            builder.spotID = spotId
            builder.timeout = 15
        }) else {
            result(FlutterError(code: "BUILD_ERROR", message: "Failed to build AdRequest", details: nil))
            return
        }
        
        self.interstitialVideoContentController = IAVideoContentController.build { [weak self] builder in
            builder.videoContentDelegate = self
        }
        
        self.interstitialMRAIDContentController = IAMRAIDContentController.build { [weak self] builder in
            builder.mraidContentDelegate = self
        }

        self.interstitialNativeImageContentController = DTXNativeImageContentController.build { [weak self] builder in
            builder.nativeImageContentDelegate = self
        }
        
        guard let unitController = IAFullscreenUnitController.build({ [weak self] builder in
            guard let self = self else { return }
            builder.unitDelegate = self
            if let video = self.interstitialVideoContentController {
                builder.addSupportedContentController(video)
            }
            if let mraid = self.interstitialMRAIDContentController {
                builder.addSupportedContentController(mraid)
            }
            if let native = self.interstitialNativeImageContentController {
                builder.addSupportedContentController(native)
            }
        }) else {
            result(FlutterError(code: "BUILD_ERROR", message: "Failed to build Interstitial Controller", details: nil))
            return
        }
        
        self.interstitialUnitController = unitController
        
        self.interstitialSpot = IAAdSpot.build({ builder in
            builder.adRequest = adRequest
            builder.addSupportedUnitController(unitController)
        })
        
        self.interstitialSpot?.fetchAd { [weak self] (adSpot, model, error) in
            if let error = error {
                print("❌ [SWIFT DEBUG] Interstitial Ad Load Failed! Error: \(error.localizedDescription)")
                self?.sendEvent(type: "onAdLoadFailed", data: ["adType": "interstitial", "error": error.localizedDescription])
            } else {
                print("✅ [SWIFT DEBUG] Interstitial Ad Loaded! Model: \(String(describing: model))")
                self?.sendEvent(type: "onAdLoaded", data: ["adType": "interstitial"])
            }
        }
        
        result(true)
    }
    
    private func showInterstitialAd(result: @escaping FlutterResult) {
        guard let controller = self.interstitialUnitController, let spot = self.interstitialSpot else {
            result(FlutterError(code: "NOT_READY", message: "Interstitial Ad not loaded", details: nil))
            return
        }
        
        print("🔍 [SWIFT DEBUG] Attempting to show Interstitial Ad. Spot Active Controller: \(String(describing: spot.activeUnitController))")
        
        if (spot.activeUnitController == controller) {
            controller.showAd(animated: true)
            result(true)
        } else {
            print("❌ [SWIFT DEBUG] Interstitial Ad mismatch or not ready.")
            result(FlutterError(code: "NOT_READY", message: "Interstitial Ad is not ready", details: nil))
        }
    }
    
    public func iaParentViewController(for unitController: IAUnitController?) -> UIViewController {
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if window.isKeyWindow, let rootVC = window.rootViewController {
                            return findTopViewController(rootVC)
                        }
                    }
                }
            }
            
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if let rootVC = window.rootViewController {
                            return findTopViewController(rootVC)
                        }
                    }
                }
            }
        } else {
            if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                return findTopViewController(rootVC)
            }
        }
        
        if let appDelegate = UIApplication.shared.delegate,
           let window = appDelegate.window,
           let rootVC = window?.rootViewController {
            return findTopViewController(rootVC)
        }

        print("❌ [DtExchangeSdkPlugin] FATAL: Could not find any root view controller! Returning detached VC.")
        return UIViewController() // Fallback
    }
    
    private func findTopViewController(_ vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return findTopViewController(presented)
        }
        return vc
    }
    
    public func iaAdDidReceiveClick(_ unitController: IAUnitController?) {
        sendEvent(type: "onAdClicked", data: nil)
    }
    
    public func iaAdWillLogImpression(_ unitController: IAUnitController?) {
        sendEvent(type: "onAdImpression", data: nil)
    }
    
    public func iaAdDidDismiss(_ unitController: IAUnitController?) {
        sendEvent(type: "onAdDismissed", data: nil)
    }
    
    public func iaUnitController(_ unitController: IAUnitController?, didFailToPresentAdWithError error: Error?) {
         sendEvent(type: "onAdShowFailed", data: ["error": error?.localizedDescription ?? "Unknown Error"])
    }
    
    // MARK: - IAVideoContentDelegate (Reward)
    
    public func iaVideoCompleted(_ contentController: IAVideoContentController?) {
        sendEvent(type: "onAdRewarded", data: nil)
    }
    
    public func iaVideoContentController(_ contentController: IAVideoContentController?, videoInterruptedWithError error: Error) {
    }

    public func iaVideoContentController(_ contentController: IAVideoContentController?, videoProgressUpdatedWithCurrentTime currentTime: TimeInterval, totalTime: TimeInterval) {
    }

    // MARK: - DTXNativeImageContentDelegate

    public func nativeImage(_ nativeImageContentController: DTXNativeImageContentController?, loadedImageFrom url: URL) {
        print("✅ [SWIFT DEBUG] Native Image Loaded: \(url)")
    }

    public func nativeImage(_ nativeImageContentController: DTXNativeImageContentController?, failedToLoadImageFrom url: URL, error: Error) {
        print("❌ [SWIFT DEBUG] Native Image Failed: \(error.localizedDescription)")
    }
    
    // MARK: - FlutterStreamHandler
    
    private func sendEvent(type: String, data: [String: Any]?) {
        var eventMap: [String: Any] = ["type": type]
        if let data = data {
            eventMap.merge(data) { (_, new) in new }
        }
        eventSink?(eventMap)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// ==========================================
// MARK: - Banner Implementation (Platform View)
// ==========================================

class DtExchangeBannerFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return DtExchangeBannerView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            messenger: messenger
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class DtExchangeBannerView: NSObject, FlutterPlatformView, IAUnitDelegate, IAMRAIDContentDelegate, IAVideoContentDelegate, DTXNativeImageContentDelegate {
    private var _view: UIView
    private var bannerSpot: IAAdSpot?
    private var viewUnitController: IAViewUnitController?
    
    // Content Controllers (Strong Reference)
    private var videoContentController: IAVideoContentController?
    private var mraidContentController: IAMRAIDContentController?
    private var nativeImageContentController: DTXNativeImageContentController?
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)
        super.init()
        
        if let params = args as? [String: Any],
           let spotId = params["spotId"] as? String {
            loadBanner(spotId: spotId)
        }
    }

    func view() -> UIView {
        return _view
    }

    private func loadBanner(spotId: String) {
        guard let adRequest = IAAdRequest.build({ builder in
            builder.spotID = spotId
            builder.timeout = 15
        }) else {
            return
        }
        
        // 1. Build Content Controllers (Assign to Class Properties)
        self.videoContentController = IAVideoContentController.build { [weak self] builder in
            builder.videoContentDelegate = self
        }
        
        self.mraidContentController = IAMRAIDContentController.build { [weak self] builder in
            builder.mraidContentDelegate = self
        }
        
        self.nativeImageContentController = DTXNativeImageContentController.build { [weak self] builder in
            builder.nativeImageContentDelegate = self
        }
        
        // 2. Build Unit Controller
        guard let unitController = IAViewUnitController.build({ [weak self] builder in
            guard let self = self else { return }
            builder.unitDelegate = self
            if let video = self.videoContentController {
                builder.addSupportedContentController(video)
            }
            if let mraid = self.mraidContentController {
                builder.addSupportedContentController(mraid)
            }
            if let native = self.nativeImageContentController {
                builder.addSupportedContentController(native)
            }
        }) else {
            return
        }
        
        self.viewUnitController = unitController
        
        // 3. Build Ad Spot
        self.bannerSpot = IAAdSpot.build({ builder in
            builder.adRequest = adRequest
            builder.addSupportedUnitController(unitController)
        })
        
        self.bannerSpot?.fetchAd { [weak self] (adSpot, adModel, error) in
            guard let self = self else { return }
            if let error = error {
                 print("❌ [SWIFT DEBUG] Banner Load Failed: \(error.localizedDescription)")
            } else {
                print("✅ [SWIFT DEBUG] Banner Loaded! Model: \(String(describing: adModel))")
                if let spot = self.bannerSpot, spot.activeUnitController == self.viewUnitController {
                    self.viewUnitController?.showAd(inParentView: self._view)
                }
            }
        }
    }
    
    // Banner Delegates
    func iaParentViewController(for unitController: IAUnitController?) -> UIViewController {
        // 1. Try finding the key window in connected scenes (iOS 13+)
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if window.isKeyWindow, let rootVC = window.rootViewController {
                            return rootVC
                        }
                    }
                }
            }
             
            // 2. Fallback to any window with rootVC
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if let rootVC = window.rootViewController {
                            return rootVC
                        }
                    }
                }
            }
        } else {
            // 3. Legacy Fallback
            if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                return rootVC
            }
        }
        
        // 4. Delegate Fallback
        if let appDelegate = UIApplication.shared.delegate,
           let window = appDelegate.window,
           let rootVC = window?.rootViewController {
            return rootVC
        }
        
        return UIViewController()
    }
    
    func iaAdDidReceiveClick(_ unitController: IAUnitController?) {}
    func iaAdWillLogImpression(_ unitController: IAUnitController?) {}
    func iaAdDidDismiss(_ unitController: IAUnitController?) {}
    func iaUnitController(_ unitController: IAUnitController?, didFailToPresentAdWithError error: Error?) {}
    
    func iaMRAIDContentController(_ contentController: IAMRAIDContentController?, mraidPageWillOpen url: URL?) {}
    func iaMRAIDContentController(_ contentController: IAMRAIDContentController?, mraidPageDidFailToLoadWithError error: Error?) {}
    func iaMRAIDContentControllerMRAIDPageDidLoad(_ contentController: IAMRAIDContentController?) {}
    
    // MARK: - IAVideoContentDelegate
    func iaVideoCompleted(_ contentController: IAVideoContentController?) {}
    func iaVideoContentController(_ contentController: IAVideoContentController?, videoInterruptedWithError error: Error) {}
    func iaVideoContentController(_ contentController: IAVideoContentController?, videoProgressUpdatedWithCurrentTime currentTime: TimeInterval, totalTime: TimeInterval) {}

    // MARK: - DTXNativeImageContentDelegate
    func nativeImage(_ nativeImageContentController: DTXNativeImageContentController?, loadedImageFrom url: URL) {
         print("✅ [SWIFT DEBUG] Banner Native Image Loaded: \(url)")
    }

    func nativeImage(_ nativeImageContentController: DTXNativeImageContentController?, failedToLoadImageFrom url: URL, error: Error) {
         print("❌ [SWIFT DEBUG] Banner Native Image Failed: \(error.localizedDescription)")
    }
}
