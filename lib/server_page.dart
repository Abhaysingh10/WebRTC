import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web_socket/Call.dart';
import 'package:web_socket/main.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  late CallPage signalling;
  late String _selfId = getRandomString(8);
  late IO.Socket socket;
  bool broadcast = false;
  late var braodcastedMessage;
  //Random Number Generation for UserID
  var _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random _rnd = Random();
  int? arrayUserLength;
  // ignore: deprecated_member_use
  List<dynamic>? arrayUser;
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  @override
  void initState() {
    connect();
    refresh();
    //refresh().whenComplete(() => null);
    super.initState();
  }

  connect() async {
    print("This is SelfId => " + _selfId);
    socket = IO.io("https://db29d4b8b315.ngrok.io", <String, dynamic>{
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
    socket.on('broadcast', (data) {
      if (data != null) {
        setState(() {
          broadcast = true;
        });
      }
    });
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
  void dispose() {
    socket.destroy();
    disconnect();
    super.dispose();
  }

  connectToUser(String peerId) {
    print("This is peerID $peerId");
  }

  _invitePeer(
      BuildContext context, String _peerId, bool useScreen, String selfId) {
    signalling.createState().invite(_peerId, 'video', selfId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          actionsIconTheme:
              IconThemeData(color: Colors.amber, size: 40, opacity: 10),
          automaticallyImplyLeading: true,
          leading: BackButton(
              color: Colors.black,
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (c) => MyApp()))),
          centerTitle: true,
          title: new Text("Server Page"),
          actions: [
            GestureDetector(
              onTap: () => refresh(),
              child: Icon(Icons.refresh),
            )
          ],
        ),
        body: ListView.builder(
            itemCount: arrayUser != null ? arrayUser!.length : 0,
            itemBuilder: (context, index) {
              return ListTile(
                subtitle: Container(
                  child: MaterialButton(
                    color: (arrayUser![index].toString() != _selfId)
                        ? (broadcast ? Colors.blue : Colors.grey)
                        : Colors.grey,
                    disabledColor: Colors.red,
                    child: Text("Answer"),
                    onPressed: () => {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (c) => CallPage(_selfId, "nothing")))
                    },
                  ),
                ),
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
                title: (arrayUser![index].toString() == _selfId)
                    ? Text(arrayUser![index].toString() + "    { Yourself }")
                    : Text(arrayUser![index].toString()),
              );
            }));
  }
}
