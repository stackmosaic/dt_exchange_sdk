package com.stackmosaic.dt_exchange_sdk

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.NonNull
import com.fyber.inneractive.sdk.external.*
import com.fyber.inneractive.sdk.external.InneractiveUnitController.AdDisplayError
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class DtExchangeSdkPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel : EventChannel
  private var eventSink: EventChannel.EventSink? = null
  
  private lateinit var context: Context
  private var activity: Activity? = null
  
  // Spots
  private var rewardedSpot: InneractiveAdSpot? = null
  private var interstitialSpot: InneractiveAdSpot? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    
    // 1. Method Channel
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dt_exchange_sdk")
    channel.setMethodCallHandler(this)

    // 2. Event Channel
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "dt_exchange_sdk_events")
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
      }
      override fun onCancel(arguments: Any?) {
        eventSink = null
      }
    })

    flutterPluginBinding.platformViewRegistry.registerViewFactory(
      "dt_exchange_banner_view",
      DtExchangeBannerFactory(flutterPluginBinding.binaryMessenger)
    )
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "initialize" -> {
        val appId = call.argument<String>("appId")
        InneractiveAdManager.setLogLevel(Log.VERBOSE)
        if (appId != null) {
          InneractiveAdManager.initialize(context, appId) { status ->
             sendEvent("onInitialized", mapOf("status" to status.toString()))
          }
          result.success(true)
        } else {
          result.error("MISSING_ARG", "App ID is required", null)
        }
      }
      // --- Rewarded Video ---
      "loadRewardedVideo" -> {
        val spotId = call.argument<String>("spotId")
        loadRewardedAd(spotId)
        result.success(true)
      }
      "showRewardedVideo" -> {
        showRewardedAd(result)
      }
      // --- Interstitial ---
      "loadInterstitial" -> {
        val spotId = call.argument<String>("spotId")
        loadInterstitialAd(spotId)
        result.success(true)
      }
      "showInterstitial" -> {
        showInterstitialAd(result)
      }
      else -> result.notImplemented()
    }
  }

  // =========================================================================
  // Rewarded Video Logic
  // =========================================================================
  private fun loadRewardedAd(spotId: String?) {
      rewardedSpot?.destroy()
      rewardedSpot = InneractiveAdSpotManager.get().createSpot()
      
      val unitController = InneractiveFullscreenUnitController()
      rewardedSpot?.addUnitController(unitController)

      rewardedSpot?.setRequestListener(object : InneractiveAdSpot.RequestListener {
          override fun onInneractiveSuccessfulAdRequest(adSpot: InneractiveAdSpot?) {
              sendEvent("onAdLoaded", mapOf("adType" to "rewarded"))
          }
          override fun onInneractiveFailedAdRequest(adSpot: InneractiveAdSpot?, errorCode: InneractiveErrorCode?) {
              sendEvent("onAdLoadFailed", mapOf("adType" to "rewarded", "errorCode" to errorCode.toString()))
          }
      })
      rewardedSpot?.requestAd(InneractiveAdRequest(spotId))
  }

  private fun showRewardedAd(result: Result) {
      if (activity == null) {
          result.error("NO_ACTIVITY", "Activity is null", null)
          return
      }
      if (rewardedSpot?.isReady == true) {
          val controller = rewardedSpot?.selectedUnitController as? InneractiveFullscreenUnitController
          controller?.setEventsListener(createFullscreenListener())
          controller?.setRewardedListener { sendEvent("onAdRewarded", null) }
          controller?.show(activity)
          result.success(true)
      } else {
          result.error("NOT_READY", "Rewarded Ad not ready", null)
      }
  }

  // =========================================================================
  // Interstitial Logic
  // =========================================================================
  private fun loadInterstitialAd(spotId: String?) {
      interstitialSpot?.destroy()
      interstitialSpot = InneractiveAdSpotManager.get().createSpot()
      
      val unitController = InneractiveFullscreenUnitController()
      interstitialSpot?.addUnitController(unitController)

      interstitialSpot?.setRequestListener(object : InneractiveAdSpot.RequestListener {
          override fun onInneractiveSuccessfulAdRequest(adSpot: InneractiveAdSpot?) {
              sendEvent("onAdLoaded", mapOf("adType" to "interstitial"))
          }
          override fun onInneractiveFailedAdRequest(adSpot: InneractiveAdSpot?, errorCode: InneractiveErrorCode?) {
              sendEvent("onAdLoadFailed", mapOf("adType" to "interstitial", "errorCode" to errorCode.toString()))
          }
      })
      interstitialSpot?.requestAd(InneractiveAdRequest(spotId))
  }

  private fun showInterstitialAd(result: Result) {
      if (activity == null) {
          result.error("NO_ACTIVITY", "Activity is null", null)
          return
      }
      if (interstitialSpot?.isReady == true) {
          val controller = interstitialSpot?.selectedUnitController as? InneractiveFullscreenUnitController
          controller?.setEventsListener(createFullscreenListener())
          controller?.show(activity)
          result.success(true)
      } else {
          result.error("NOT_READY", "Interstitial Ad not ready", null)
      }
  }

  private fun createFullscreenListener(): InneractiveFullscreenAdEventsListener {
      return object : InneractiveFullscreenAdEventsListener {
          override fun onAdImpression(adSpot: InneractiveAdSpot?) { sendEvent("onAdImpression", null) }
          override fun onAdClicked(adSpot: InneractiveAdSpot?) { sendEvent("onAdClicked", null) }
          override fun onAdWillOpenExternalApp(adSpot: InneractiveAdSpot?) {}
          override fun onAdEnteredErrorState(adSpot: InneractiveAdSpot?, error: AdDisplayError?) {
               sendEvent("onAdShowFailed", mapOf("error" to error.toString()))
          }
          override fun onAdWillCloseInternalBrowser(adSpot: InneractiveAdSpot?) {}
          override fun onAdDismissed(adSpot: InneractiveAdSpot?) { sendEvent("onAdDismissed", null) }
      }
  }

  private fun sendEvent(type: String, data: Map<String, Any?>?) {
      Handler(Looper.getMainLooper()).post {
          val eventMap = mutableMapOf<String, Any?>("type" to type)
          if (data != null) eventMap.putAll(data)
          eventSink?.success(eventMap)
      }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
  override fun onDetachedFromActivityForConfigChanges() { activity = null }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
  override fun onDetachedFromActivity() { activity = null }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }
}

// Banner Logic for Android
class DtExchangeBannerFactory(private val messenger: io.flutter.plugin.common.BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any?>
        return DtExchangeBannerView(context, viewId, creationParams)
    }
}

class DtExchangeBannerView(
    private val context: Context,
    viewId: Int,
    creationParams: Map<String, Any?>?
) : PlatformView {

    private val bannerContainer: FrameLayout = FrameLayout(context)
    private var bannerSpot: InneractiveAdSpot? = null
    private var unitController: InneractiveAdViewUnitController? = null

    init {
        val spotId = creationParams?.get("spotId") as? String
        if (spotId != null) {
            loadBanner(spotId)
        }
    }

    override fun getView(): View {
        return bannerContainer
    }

    override fun dispose() {
        bannerSpot?.destroy()
        bannerSpot = null
        unitController = null
    }

    private fun loadBanner(spotId: String) {
        bannerSpot = InneractiveAdSpotManager.get().createSpot()
        unitController = InneractiveAdViewUnitController()
        bannerSpot?.addUnitController(unitController)

        // Events Listener
        unitController?.setEventsListener(object : InneractiveAdViewEventsListener {
            override fun onAdImpression(adSpot: InneractiveAdSpot?) {}
            override fun onAdClicked(adSpot: InneractiveAdSpot?) {}
            override fun onAdWillCloseInternalBrowser(adSpot: InneractiveAdSpot?) {}
            override fun onAdWillOpenExternalApp(adSpot: InneractiveAdSpot?) {}
            override fun onAdEnteredErrorState(adSpot: InneractiveAdSpot?, error: AdDisplayError?) {}
            override fun onAdExpanded(adSpot: InneractiveAdSpot?) {}
            override fun onAdResized(adSpot: InneractiveAdSpot?) {}
            override fun onAdCollapsed(adSpot: InneractiveAdSpot?) {}
        })

        bannerSpot?.setRequestListener(object : InneractiveAdSpot.RequestListener {
            override fun onInneractiveSuccessfulAdRequest(adSpot: InneractiveAdSpot?) {
                android.util.Log.d("DT_BANNER", "Banner Load Success!") 
                if (unitController != null && bannerContainer != null) {
                    unitController?.bindView(bannerContainer)
                }
            }

            override fun onInneractiveFailedAdRequest(adSpot: InneractiveAdSpot?, errorCode: InneractiveErrorCode?) {
                android.util.Log.e("DT_BANNER", "Banner Load Failed: $errorCode")
            }
        })

        bannerSpot?.requestAd(InneractiveAdRequest(spotId))
    }
}