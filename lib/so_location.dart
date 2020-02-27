import 'dart:async';

import 'package:flutter/services.dart';

enum PermissionResult{
  GRANTED, PERMISSION_DENIED, PERMISSION_DENIED_NEVER_ASK
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
    print(result);
    print(PermissionResult.GRANTED.toString());
    return PermissionResult.values.firstWhere((item) => item.toString().endsWith(result), orElse: ()=> throw Exception('PermissionResult not match'));
  }
}
