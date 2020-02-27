import 'dart:async';

import 'package:flutter/services.dart';

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
}
