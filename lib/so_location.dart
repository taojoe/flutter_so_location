import 'dart:async';

import 'package:flutter/services.dart';

enum PermissionResult{
  GRANTED, PERMISSION_DENIED, PERMISSION_DENIED_NEVER_ASK
}

class LocationData{
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double speedAccuracy;
  final double heading;
  final DateTime time;

  LocationData._(this.latitude, this.longitude, this.accuracy, this.altitude,
      this.speed, this.speedAccuracy, this.heading, this.time);


  @override
  String toString() {
    return "LocationData<lat: $latitude, long: $longitude>";
  }

  Map<String, dynamic> toJson(){
    return {
      'latitude':latitude,
      'longitude':longitude,
      'altitude':altitude,
      'accuracy':accuracy,
      'speed':speed,
      'speedAccuracy':speedAccuracy,
      'heading':heading,
      'time':time.toIso8601String()
    };
  }
  factory LocationData.fromMap(Map<String, double> dataMap) {
    return LocationData._(
      dataMap['latitude'],
      dataMap['longitude'],
      dataMap['accuracy'],
      dataMap['altitude'],
      dataMap['speed'],
      dataMap['speed_accuracy'],
      dataMap['heading'],
      DateTime.fromMillisecondsSinceEpoch(dataMap['time'].floor()),
    );
  }
}

class SoLocation {
  static const MethodChannel _channel = const MethodChannel('so_location/method');
  static const EventChannel _streamChannel = const EventChannel('so_location/stream');
  static Stream<LocationData> _eventStream;

  static Stream<LocationData> get respEventStream {
    if (_eventStream == null) {
       _eventStream = _streamChannel.receiveBroadcastStream().map<LocationData>((event) => event!=null?LocationData.fromMap((event as Map<dynamic, dynamic>).cast<String, double>()):null);
    }
    return _eventStream;
  }

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  static Future<List<String>> listEnabledProvider() async{
    final List<dynamic> list = await _channel.invokeMethod('listEnabledProvider');
    return list.cast<String>();
  }
  static Future<bool> isLocationEnabled() async{
    final bool result = await _channel.invokeMethod('isLocationEnabled');
    return result;
  }
  static Future<bool> hasPermission() async{
    final bool result = await _channel.invokeMethod('hasPermission');
    return result;
  }
  static Future<PermissionResult> requestPermission() async{
    final String result = await _channel.invokeMethod('requestPermission');
    return PermissionResult.values.firstWhere((item) => item.toString().endsWith(result), orElse: ()=> throw Exception('PermissionResult not match'));
  }
  static Future<LocationData> getLocation({int timeout=1000}) async{
    final result = await _channel.invokeMethod('getLocation', {"timeout":timeout});
    return LocationData.fromMap(result.cast<String, double>());
  }
  static Future<LocationData> getLastKnownLocation(String provider) async{
    final result = await _channel.invokeMethod('getLastKnownLocation', {'provider':provider});
    if(result==null){
      return null;
    }
    return LocationData.fromMap(result.cast<String, double>());
  }
  static Future<void> startLocationUpdates({int interval=30000, double distance=0}) async{
    final result = await _channel.invokeMethod('startLocationUpdates', {'interval':interval, 'distance':distance});
  }
  static Future<void> stopLocationUpdates() async{
    final result = await _channel.invokeMethod('stopLocationUpdates');
  }
}
