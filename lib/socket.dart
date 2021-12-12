import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketNode with ChangeNotifier {
  // late String _selfId;

  late IO.Socket socket;

  List<dynamic>? arrayUser;
  connect(String _selfId) async {
    print("This is SelfId => " + _selfId);
    socket = IO.io("http://localhost:5000", <String, dynamic>{
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
