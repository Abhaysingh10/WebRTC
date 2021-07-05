import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web_socket/main.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  late String _selfId = getRandomString(8);
  late IO.Socket socket;
  //Random Number Generation for UserID
  var _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random _rnd = Random();
  int? arrayUserLength;
  late List<dynamic> arrayUser;
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  @override
  void initState() {
    connect();
    //refresh().whenComplete(() => null);
    super.initState();
  }

  connect() async {
    print("This is SelfId => " + _selfId);
    socket = IO.io("http://bcb2fea4c0f0.ngrok.io", <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false
    });
    socket.connect();
    socket.emit("connection", _selfId);
    socket.on("connectionResponse", (data) => {});
    socket.onConnect((data) {
      print("connected");
      socket.on("OnlineUsers", (data) {
        //  print(data);
      });
    });
    print(socket.connected);
  }

  List<dynamic> refresh() {
    socket.emit("refresh");
    socket.on("RefreshResponse", (users) {
      List<dynamic> userID = users;
      return userID;
    });
  }

  update(users) {
    List<dynamic> userId = users;
    print(userId);
  }

  void disconnect() {
    socket.emit("disconnectt");
    //socket.disconnect();
    print(socket.connected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          actionsIconTheme:
              IconThemeData(color: Colors.amber, size: 30, opacity: 10),
          automaticallyImplyLeading: true,
          leading: BackButton(
              color: Colors.black,
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (c) => MyApp()))),
          centerTitle: true,
          title: new Text("Server Page"),
        ),
        // body: FutureBuilder(
        //     future: null,
        //     builder: (context, snapshot) {
        //       if (snapshot.data == null) {
        //         return Container(
        //           child: Center(
        //             child: Text("Loading..."),
        //           ),
        //         );
        //       } else {
        //         return ListView.builder(
        //             itemCount: 5,
        //             itemBuilder: (BuildContext buildContext, int index) {
        //               return ListTile(
        //                 title: Text(snapshot.data.toString()),
        //               );
        //             });
        //       }
        //     })
        //body:
        body: Center(
            child: Column(children: [
          Container(
            height: 50,
            width: 150,
            color: Colors.red[400],
            child: MaterialButton(
              onPressed: () {
                connect();
              },
              child: Text("Connect to Socket"),
            ),
          ),
          SizedBox(
            height: 20.0,
          ),
          Container(
            height: 50,
            width: 150,
            color: Colors.red[400],
            child: MaterialButton(
              onPressed: () => disconnect(),
              child: Text("Disconnect"),
            ),
          ),
          Container(
              child: IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => refresh(),
          )),
        ])));
  }
}
