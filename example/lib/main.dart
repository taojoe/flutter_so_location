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
  LocationData _currentLocation;
  StreamSubscription location_subscription;
  @override
  void initState() {
    super.initState();
    initPlatformState();
    location_subscription=SoLocation.respEventStream.listen((event) {
      setState(() {
        print(event.toString()+":"+DateTime.now().toString());
        _currentLocation=event;
      });
    });
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

  String _getLastKnownLocation;

  void getLastKnownLocation()async{
    final list=await SoLocation.listEnabledProvider();
    final value=await SoLocation.getLastKnownLocation(list.first);
    setState(() {
      _getLastKnownLocation='${value?.toJson()}';
    });
  }
  void startLocationUpdates()async{
    await SoLocation.startLocationUpdates(interval: 5000);
  }

  void stopLocationUpdates()async{
    await SoLocation.stopLocationUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SingleChildScrollView(
          child: Column(
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
              Center(child: Text('getLocation: ${_locationData?.toJson()}\n')),
              RaisedButton(
                child: Text('getLocation'),
                onPressed: getLocation
              ),
              Center(child: Text('getLastKnownLocation: ${_getLastKnownLocation}\n')),
              RaisedButton(
                child: Text('getLastKnownLocation'),
                onPressed: getLastKnownLocation
              ),
              Center(child: Text('startLocationUpdates: ${_currentLocation?.toJson()}\n')),
              RaisedButton(
                child: Text('startLocationUpdates'),
                onPressed: startLocationUpdates
              ),
              RaisedButton(
                child: Text('stopLocationUpdates'),
                onPressed: stopLocationUpdates
              )
            ],
          ),
        ),
      ),
    );
  }
}