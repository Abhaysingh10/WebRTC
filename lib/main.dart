import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';
import 'package:web_socket/Call.dart';
import 'package:web_socket/server_page.dart';
import 'package:web_socket/socket.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => SocketNode(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Websocket",
          theme: ThemeData(primarySwatch: Colors.deepOrange),
          home: MyHomePage(
            title: "WebSocket",
          ),
        ));
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
  late IO.Socket socket;
  @override
  void initState() {
    connect();
    super.initState();
  }

  void connect() {
    //   socket = io(
    //       'http://localhost:5000',
    //       IO.OptionBuilder()
    //           .setTransports(['websocket']) // for Flutter or Dart VM
    //           .disableAutoConnect() // disable auto-connection
    //           .build());
    //   socket.connect();
    //   print("Connected");
    // }
  }

  void _incrementCounter() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (c) => ServerPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
          child: SingleChildScrollView(
        child: Container(
          color: Colors.grey,
          height: MediaQuery.of(context).size.height * 1,
        ),
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
