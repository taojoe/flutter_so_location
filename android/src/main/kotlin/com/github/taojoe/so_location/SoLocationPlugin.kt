package com.github.taojoe.so_location

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Criteria
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
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

fun Location.toMap():Map<String, Double>{
  return mapOf<String, Double>("latitude" to this.latitude, "longitude" to this.longitude, "altitude" to this.altitude, "accuracy" to this.accuracy.toDouble(), "speed" to this.speed.toDouble(), "heading" to this.bearing.toDouble(), "time" to this.time.toDouble())
}

interface EmptyLocationListener: LocationListener{
  override fun onLocationChanged(location: Location?) {}

  override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

  override fun onProviderEnabled(provider: String?) {}

  override fun onProviderDisabled(provider: String?) {}
}

/** SoLocationPlugin */
public class SoLocationPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
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
    val REQUEST_PERMISSIONS_REQUEST_CODE="so_location".hashCode()
    val instance:SoLocationPlugin by lazy { SoLocationPlugin() }
    private lateinit var methodChannel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private lateinit var applicationContext: Context
    private var activityBinding: ActivityPluginBinding? = null
    private var registrar: Registrar?=null
    private val currentActivity:Activity?
      get() = activityBinding?.activity ?: registrar?.activity()

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
      applicationContext=context
    }

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      this.registrar=registrar
      init(registrar.messenger(), registrar.context())
      registrar.addRequestPermissionsResultListener(instance)
    }
  }


  private val locationManager: LocationManager? by lazy {
    applicationContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager?
  }

  private var currentResult: Result?=null

  private val locationListener = object :EmptyLocationListener{
    override fun onLocationChanged(location: Location?) {
      if(location==null){
        eventSink?.success(null)
      }else{
        eventSink?.success(location.toMap())
      }
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if(call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else if(call.method =="listEnabledProvider"){
      result.success(listEnabledProvider())
    } else if(call.method =="hasPermission"){
      result.success(hasPermission())
    } else if(call.method=="requestPermission"){
      requestPermission(result)
    } else if(call.method=="getLocation"){
      getLocation(result)
    } else if(call.method=="getLastKnownLocation"){
      val provider:String?=call.argument("provider")
      result.success(provider?.let(::getLastKnownLocation)?.toMap())
    }else if(call.method=="startLocationUpdates"){
      val interval:Int?=call.argument("interval")
      val distance:Double?=call.argument("distance")
      startLocationUpdates(interval?:0, distance?:0.0)
      result.success(null)
    } else if(call.method=="stopLocationUpdates"){
      stopLocationUpdates()
      result.success(null)
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }

  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(this)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    binding.addRequestPermissionsResultListener(this)
    activityBinding=binding
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    onReattachedToActivityForConfigChanges(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {
    if(requestCode == REQUEST_PERMISSIONS_REQUEST_CODE &&permissions?.firstOrNull()==Manifest.permission.ACCESS_FINE_LOCATION){
      if(grantResults?.firstOrNull()==PackageManager.PERMISSION_GRANTED){
        currentResult?.success(PermissionResult.GRANTED.name)
      }else{
        currentResult?.success(if(shouldShowRequestPermissionRationale()) PermissionResult.PERMISSION_DENIED.name else PermissionResult.PERMISSION_DENIED_NEVER_ASK.name)
      }
      currentResult=null
      return true
    }
    return false
  }

  //---
  fun shouldShowRequestPermissionRationale(): Boolean {
    return currentActivity!!.let { ActivityCompat.shouldShowRequestPermissionRationale(it, Manifest.permission.ACCESS_FINE_LOCATION) }
  }
  fun setResult(result: Result){
    if(this.currentResult!=null){
      this.currentResult?.error("CANCELLED", null, null)
    }
    this.currentResult=result
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
    return ActivityCompat.checkSelfPermission(applicationContext, Manifest.permission.ACCESS_FINE_LOCATION) ==PackageManager.PERMISSION_GRANTED
  }

  fun requestPermission(result: Result){
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      result.success(PermissionResult.GRANTED.name)
      return
    }
    if(hasPermission()){
      result.success(PermissionResult.GRANTED.name)
      return
    }
    val activity= currentActivity
    if(activity==null){
      result.error("FATAL", null, null)
    }else{
      setResult(result)
      ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), REQUEST_PERMISSIONS_REQUEST_CODE)
    }
  }

  fun getLocation(result: Result){
    if(!hasPermission()){
      result.error("PERMISSION_NOT_GRANTED", if(shouldShowRequestPermissionRationale()) PermissionResult.PERMISSION_DENIED.name else PermissionResult.PERMISSION_DENIED_NEVER_ASK.name, null)
    }
    val criteria = Criteria().apply { accuracy = Criteria.ACCURACY_FINE }
    locationManager!!.requestSingleUpdate(criteria, object : EmptyLocationListener {
      override fun onLocationChanged(location: Location?) {
        if(location==null){
          result.error("EMPTY", null, null)
        }else{
          result.success(location.toMap())
        }
      }

      override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        println("--- method call: onStatusChanged")
      }

      override fun onProviderEnabled(provider: String?) {
        println("--- method call: onProviderEnabled")
      }

      override fun onProviderDisabled(provider: String?) {
        println("--- method call: onProviderDisabled")
      }
    }, Looper.myLooper())
  }

  fun getLastKnownLocation(provider:String):Location?{
    return locationManager!!.getLastKnownLocation(provider)
  }

  fun startLocationUpdates(interval:Int, distance:Double){
    locationManager!!.removeUpdates(locationListener)
    val criteria = Criteria().apply { accuracy = Criteria.ACCURACY_FINE }
    locationManager!!.requestLocationUpdates(interval.toLong(), distance.toFloat(), criteria, locationListener, Looper.myLooper())
  }

  fun stopLocationUpdates(){
    locationManager!!.removeUpdates(locationListener)
  }
}