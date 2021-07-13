import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web_socket/Call.dart';
import 'package:web_socket/main.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class Session {
  Session({required this.sid, required this.pid});
  String sid;
  String pid;
  late RTCPeerConnection pc;
  late RTCDataChannel dc;
  late RTCVideoRenderer _selfRenderer;
  late TextEditingController fieldController;
  List<RTCIceCandidate> remoteCandidates = [];
}

class _ServerPageState extends State<ServerPage> {
  late CallPage signalling;
  late Session session;
  Map<String, Session> _session = {};
  late String _selfId = getRandomString(8);
  late IO.Socket socket;
  bool broadcast = false;
  RTCVideoRenderer _selfRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _guestRenderer = new RTCVideoRenderer();
  late var braodcastedMessage;
  JsonDecoder _decoder = JsonDecoder();
  JsonEncoder _encoder = new JsonEncoder();
  bool inCalling = false;
  //Random Number Generation for UserID
  var _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random _rnd = Random();
  int? arrayUserLength;
  late MediaStream _localStream;
  // ignore: deprecated_member_use
  List<dynamic>? arrayUser;
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
      */
    ]
  };

  @override
  void initState() {
    connect();
    //refresh();
    initRenders();
    //refresh().whenComplete(() => null);
    super.initState();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };
    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _selfRenderer.srcObject = stream;
    return stream;
  }

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  connect() async {
    print("This is SelfId => " + _selfId);
    socket = IO.io("http://b6ed49d8866c.ngrok.io", <String, dynamic>{
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
    socket.on(
        'broadcast',
        (data) => {
              print("Boradcasting the data"),
              if (data != null)
                {
                  setState(() {
                    broadcast = true;
                    print(
                        "This data is being diplayed over broadcast function " +
                            data.toString());
                  })
                }
            });

    socket.on("givingSdp", (data) => print(data));
  }

  initRenders() async {
    await _selfRenderer.initialize();
    await _guestRenderer.initialize();
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

  invite(String peerId, String media, useScreen) async {
    var sessionId = _selfId + '-' + peerId;
    Session session = await _createSession(
      sessionId: sessionId,
      peerId: peerId,
      media: media,
      screenSharing: useScreen,
    );
    _session[sessionId] = session;
    print("This is sessionId" + sessionId.toString());
    _createOffer(
      session,
      media,
    );
  }

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

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

  call() {
    invite(_selfId, "video", false);
  }

  replying() {
    socket.emit("getMeSdp");
  }

  Future<void> _createOffer(Session session, String media) async {
    try {
      setState(() {
        inCalling = true;
      });
      print("Inside of create offer");
      RTCSessionDescription s =
          await session.pc.createOffer({'offerToReceiveVideo ': 1});
      print(s.toString());
      var sessionn = parse(s.sdp
          .toString()); //   <-----------Generting sdp for debugging readability.
      print(jsonEncode(sessionn));
      await session.pc.setLocalDescription(s);
      _send('offer', {
        'to': session.pid,
        'from': _selfId,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': session.sid,
        'media': media,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<Session> _createSession(
      {required String sessionId,
      required String peerId,
      required String media,
      required bool screenSharing}) async {
    var newSession = Session(sid: sessionId, pid: peerId);
    _localStream = await _getUserMedia();

    print(_iceServers);
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
    }, _config);

    pc.addStream(_localStream);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(e.candidate.toString() +
            e.sdpMid.toString() +
            e.sdpMlineIndex.toString());

        print("This is selfId " + _selfId + " " + socket.connected.toString());
        print("This is peerId" + peerId);
      }
      //  socket.emit("check", "add camdidate "); not working

      _send('candidate', {
        'to': peerId,
        'from': _selfId,
        'candidate': {
          'sdpMLineIndex': e.sdpMlineIndex,
          'sdpMid': e.sdpMid,
          'candidate': e.candidate,
        },
        'session_id': sessionId,
      });
    };
    // print("This is Session Id" + sessionId);
    newSession.pc = pc;
    return newSession;
  }

  _send(event, data) {
    var request = Map();
    request["type"] = event;
    request["data"] = data;
    socket.emit("offer", _encoder.convert(request));
    //print("This is the request form user -> " + _encoder.convert(request));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: AppBar(
        //   title: Text("Server Page"),
        // ),
        body: inCalling
            ? Container(
                child: Stack(children: <Widget>[
                  Positioned(
                    child: Container(
                      //color: Colors.yellow,
                      child: new RTCVideoView(_guestRenderer),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),
                  Positioned(
                    left: 20.0,
                    top: MediaQuery.of(context).size.height * .1,
                    child: Container(
                      child: new RTCVideoView(_selfRenderer),
                      //color: Colors.lightBlue,
                      height: MediaQuery.of(context).size.height * .17,
                      width: MediaQuery.of(context).size.width * .25,
                    ),
                  ),
                  Positioned(
                    bottom: 50.0,
                    left: 120,
                    child: SizedBox(
                      width: 200.0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            FloatingActionButton(
                              child: const Icon(Icons.switch_camera),
                              onPressed: null,
                            ),
                            FloatingActionButton(
                              onPressed: () {
                                setState(() {
                                  inCalling = false;
                                });
                              },
                              tooltip: 'Hangup',
                              child: Icon(Icons.call_end),
                              backgroundColor: Colors.pink,
                            ),
                            FloatingActionButton(
                              child: const Icon(Icons.mic_off),
                              onPressed: null,
                            )
                          ]),
                    ),
                  )
                ]),
              )
            : Scaffold(
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
                            onPressed: () => {replying()},
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
                            onPressed: () => {call()},
                          ),
                        ),
                        onTap: () =>
                            {connectToUser(arrayUser![index].toString())},
                        title: (arrayUser![index].toString() == _selfId)
                            ? Text(arrayUser![index].toString() +
                                "    { Yourself }")
                            : Text(arrayUser![index].toString()),
                      );
                    })));
  }
}
