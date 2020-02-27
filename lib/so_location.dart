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
  static const MethodChannel _channel =
      const MethodChannel('so_location/method');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  static Future<List<String>> listEnabledProvider() async{
    final List<dynamic> list = await _channel.invokeMethod('listEnabledProvider');
    return list.cast<String>();
  }
  static Future<bool> hasPermission() async{
    final bool result = await _channel.invokeMethod('hasPermission');
    return result;
  }
  static Future<PermissionResult> requestPermission() async{
    final String result = await _channel.invokeMethod('requestPermission');
    return PermissionResult.values.firstWhere((item) => item.toString().endsWith(result), orElse: ()=> throw Exception('PermissionResult not match'));
  }
  static Future<LocationData> getLocation() async{
    final result = await _channel.invokeMethod('getLocation');
    return LocationData.fromMap(result.cast<String, double>());
  }
}
