package com.github.taojoe.so_location

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

enum class PermissionResult{
  GRANTED, PERMISSION_DENIED, PERMISSION_DENIED_NEVER_ASK
}

/** SoLocationPlugin */
public class SoLocationPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
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
    val REQUEST_PERMISSIONS_REQUEST_CODE=10
    val instance:SoLocationPlugin by lazy { SoLocationPlugin() }
    private lateinit var methodChannel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private val locationManager: LocationManager? by lazy {
      context.getSystemService(Context.LOCATION_SERVICE) as LocationManager?
    }
    private var activityBinding: ActivityPluginBinding? = null
    private var registrar: Registrar?=null
    private val currentActivity:Activity?
      get() = activityBinding?.activity ?: registrar?.activity()

    private val resultListener=object : PluginRegistry.RequestPermissionsResultListener{
      private var result:Result?=null

      fun setResult(result: Result){
        if(this.result!=null){
          this.result?.error("CANCELLED", null, null)
        }
        this.result=result
      }
      override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {
        if(requestCode == REQUEST_PERMISSIONS_REQUEST_CODE &&permissions?.firstOrNull()==Manifest.permission.ACCESS_FINE_LOCATION){
          if(grantResults?.firstOrNull()==PackageManager.PERMISSION_GRANTED){
            result?.success(PermissionResult.GRANTED.name)
          }else{
            result?.success(if(shouldShowRequestPermissionRationale()) PermissionResult.PERMISSION_DENIED.name else PermissionResult.PERMISSION_DENIED_NEVER_ASK.name)
          }
          result=null
          return true
        }
        return false
      }
    }
    fun shouldShowRequestPermissionRationale(): Boolean {
      return currentActivity?.let { ActivityCompat.shouldShowRequestPermissionRationale(it, Manifest.permission.ACCESS_FINE_LOCATION) } ?: false
    }
    fun init(messenger: BinaryMessenger, context: Context){
      methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME).apply { setMethodCallHandler(instance) }
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
    }

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      this.registrar=registrar
      init(registrar.messenger(), registrar.context())
      registrar.addRequestPermissionsResultListener(resultListener)
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

    fun hasPermission(): Boolean{
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
        return true
      }
      return ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==PackageManager.PERMISSION_GRANTED
    }

    fun requestPermission(result: Result){
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
        result.success(PermissionResult.GRANTED.name)
        return
      }
      val activity= currentActivity
      if(activity==null){
        result.error("FATAL", null, null)
      }else{
        resultListener.setResult(result)
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), REQUEST_PERMISSIONS_REQUEST_CODE)
      }
    }

  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else if(call.method =="listEnabledProvider"){
      result.success(listEnabledProvider())
    } else if(call.method =="hasPermission"){
      result.success(hasPermission())
    } else if(call.method=="requestPermission"){
      requestPermission(result)
    }
    else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }

  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(resultListener)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    binding.addRequestPermissionsResultListener(resultListener)
    activityBinding=binding
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    onReattachedToActivityForConfigChanges(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }
}