import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketNode with ChangeNotifier {
  // late String _selfId;

  late IO.Socket socket;

  List<dynamic>? arrayUser;
  connect(String _selfId) async {
    print("This is SelfId => " + _selfId);
    socket = IO.io(
        "tp://b85f-2405-201-600c-d806-d8e5-abae-eec2-f431.ngrok.io",
        <String, dynamic>{
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
      arrayUser = users;
    });
    notifyListeners();
    return arrayUser;
  }
}
