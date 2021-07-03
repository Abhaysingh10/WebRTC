import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web_socket/main.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  @override
  void initState() {
    connect();
    // TODO: implement initState
    super.initState();
  }

  void connect() {
    IO.Socket socket = IO.io("http://192.168.29.230:5000", <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false
    });
    socket.connect();
    socket.emit("/test", "Hello world");
    socket.onConnect((data) => print("connected"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
      automaticallyImplyLeading: true,
      leading: BackButton(
          color: Colors.black,
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (c) => MyApp()))),
      centerTitle: true,
      title: new Text("Server Page"),
    ));
  }
}
