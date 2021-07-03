import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
    title: "Websocket",
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: MyHomePage(title: "WebSocket",),
    );

  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  late IO.Socket socket ;

  void connect(){
      socket = IO.io("http://192.168.29.230:8080",<String, dynamic>{
      "transports" : ["websocket"],
      "autoconnect" : false
    } );
    socket.connect();
    socket.onConnect((data) => print("connected"));
    if(socket.connected){
      print("Connected");
    }else{
      print("Not Connected");

    }
  }

  void _incrementCounter() {
    setState(() {
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    connect();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(color: Colors.grey, height: MediaQuery.of(context).size.height * 1,),
        )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
