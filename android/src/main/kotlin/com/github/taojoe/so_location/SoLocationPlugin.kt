package com.github.taojoe.so_location

import android.content.Context
import android.location.LocationManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar


/** SoLocationPlugin */
public class SoLocationPlugin: FlutterPlugin, MethodCallHandler {
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    init(flutterPluginBinding.binaryMessenger, flutterPluginBinding.applicationContext)
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  companion object {
    val METHOD_CHANNEL_NAME="so_location/method"
    val STREAM_CHANNEL_NAME="so_location/stream"
    private lateinit var methodChannel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private var locationManager: LocationManager?=null

    fun init(messenger: BinaryMessenger, context: Context){
      methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME).apply { setMethodCallHandler(SoLocationPlugin()) }
      eventChannel = EventChannel(messenger, STREAM_CHANNEL_NAME).apply {
        setStreamHandler(object :EventChannel.StreamHandler{
          override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink= events
          }

          override fun onCancel(arguments: Any?) {
            eventSink=null
          }
        })
      }
      this.context=context
      locationManager=context.getSystemService(Context.LOCATION_SERVICE) as LocationManager?
    }

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      init(registrar.messenger(), registrar.context())
    }
    fun listEnabledProvider(): List<String> {
      return listOf<String>(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).filter {
        try{
          locationManager?.isProviderEnabled(it) ?: false
        }catch (e: Exception){
          false
        }
      }
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else if(call.method =="listEnabledProvider"){
      result.success(listEnabledProvider())
    }
    else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }
}