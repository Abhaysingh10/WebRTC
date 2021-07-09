import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web_socket/Call.dart';
import 'package:web_socket/main.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  // CallPage signalling = new CallPage();
  late String _selfId;
  late IO.Socket socket;
  var _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random _rnd = Random();
  int? arrayUserLength;
  late SharedPreferences sharedPreferences;
  // ignore: deprecated_member_use
  List<dynamic>? arrayUser;
  bool screenSharing = false;
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  @override
  initState() {
    _selfId = getRandomString(8);
    //setPrefs(_selfId);
    connect();
    refresh();
    //refresh().whenComplete(() => null);
    super.initState();
  }

  // setPrefs(String id) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   prefs.setString("selfId", _selfId);
  // }

  connect() async {
    print("This is SelfId => " + _selfId);
    socket = IO.io("http://43b120781438.ngrok.io", <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false
    });
    socket.connect();
    socket.emit("connection", _selfId);
    socket.onConnect((data) {
      print("connected");
    });
    print(socket.connected);
  }

  refresh() {
    socket.emit("refresh");
    socket.on("RefreshResponse", (users) {
      setState(() {
        arrayUser = users;
      });
    });
    print("This is array of users----> $arrayUser");
    return arrayUser;
  }

  void disconnect() {
    // socket.emit("disconnectt");
    //socket.disconnect();
    print(socket.connected);
  }

  @override
  void dispose() {
//    disconnect();
    arrayUser!.clear();
    socket.disconnect();
    // TODO: implement dispose
    super.dispose();
  }

  connectToUser(String peerId) {
    print("This is peerID $peerId");
  }

  // _invitePeer(
  //     BuildContext context, String _peerId, bool useScreen, String selfId) {
  //   signalling.createState().invite(_peerId, 'video', useScreen, selfId);
  // }

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
          actions: [
            GestureDetector(
              // onTap: () => Navigator.pushReplacement(
              //     context, MaterialPageRoute(builder: (c) => CallPage())),
              child: Icon(Icons.refresh),
            )
          ],
        ),
        body: ListView.builder(
            itemCount: arrayUser != null ? arrayUser!.length : 0,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(
                  Icons.person,
                ),
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: IconButton(
                    icon: Icon(Icons.video_call),
                    iconSize: 32,
                    onPressed: () => {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (c) => CallPage(
                                  arrayUser![index].toString(), _selfId))),
                    },
                  ),
                ),
                onTap: () => {connectToUser(arrayUser![index].toString())},
                title: ((arrayUser![index].toString() == _selfId)
                    ? Text(arrayUser![index].toString() + "    { Yourself }")
                    : Text(arrayUser![index].toString())),
              );
            }));
  }
}
