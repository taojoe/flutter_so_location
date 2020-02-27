import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:so_location/so_location.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await SoLocation.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  List<String> _enabledProviders=[];

  void listEnabledProvider()async{
    final list=await SoLocation.listEnabledProvider();
    setState(() {
      _enabledProviders=list;
    });
  }

  bool _hasPermission;

  void hasPermission()async{
    final value=await SoLocation.hasPermission();
    setState(() {
      _hasPermission=value;
    });
  }
  PermissionResult _requestPermission;

  void requestPermission()async{
    final value=await SoLocation.requestPermission();
    setState(() {
      _requestPermission=value;
    });
  }

  LocationData _locationData;

  void getLocation()async{
    final value=await SoLocation.getLocation();
    setState(() {
      _locationData=value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Center(child: Text('Running on: $_platformVersion\n')),
            Center(child: Text('enabledProviders: ${_enabledProviders.join(",")}\n')),
            RaisedButton(
              child: Text('listEnabledProvider'),
              onPressed: listEnabledProvider
            ),
            Center(child: Text('hasPermission: ${_hasPermission}\n')),
            RaisedButton(
              child: Text('hasPermission'),
              onPressed: hasPermission
            ),
            Center(child: Text('requestPermission: ${_requestPermission}\n')),
            RaisedButton(
              child: Text('requestPermission'),
              onPressed: requestPermission
            ),
            Center(child: Text('getLocation: ${_locationData}\n')),
            RaisedButton(
              child: Text('getLocation'),
              onPressed: getLocation
            )
          ],
        ),
      ),
    );
  }
}