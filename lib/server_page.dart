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
  late TextEditingController fieldController;
  List<RTCIceCandidate> remoteCandidates = [];
}

class _ServerPageState extends State<ServerPage> {
  late CallPage signalling;
  late Session session;
  late String peerId;
  var x;
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
  String? sdpData;
  int? arrayUserLength;
  late MediaStream _localStream;
  List<MediaStream> _remoteStreams = <MediaStream>[];
  // ignore: deprecated_member_use
  List<dynamic>? arrayUser;
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  //{ for webcall
  late RTCPeerConnection _peerConnection;
  late RTCPeerConnection _remotePeerConnection;

  bool _offer = false;
  //}

  @override
  void initState() {
    connect();
    initRenders();

    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
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

  @override
  void dispose() {
    // TODO: implement dispose
    _guestRenderer.dispose();
    _selfRenderer.dispose();
    socket.dispose();
    super.dispose();
  }

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  void connect() {
    socket = IO.io(
        'http://4caa-2405-201-600c-d806-5f2-73bb-4040-5c0f.ngrok.io',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build());
    socket.connect();

    if (socket.connected) {
      //  print("Connected in call page " + socket.id.toString());
    } else {
      print("Not connected");
    }
    socket.emit('connection', _selfId);
    socket.on('broadcastingMessage', (data) => {refresh()});
    socket.on(
        "broadcastingMessagesdp",
        (data) => {
              x = data,
              print("This is type of data "),
              // refresh(),
              if (data != null) {broadcastMessage(), checkTheOffer(data)}
            });
    socket.on('recCandy', (candy) => {_addCandidate(candy.toString())});
    socket.on('answer', (data) => print(json.decode(data)));
  }

  void broadcastMessage() {
    setState(() {
      broadcast = true;
    });
  }

  void checkTheOffer(var values) {
    _setRemoteDescription(values.toString());
  }

  void onMessage(convert) {}

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {"OfferToReceiveAudio": true, "OfferToReceiveVideo": true},
      "optional": [],
    };

    _localStream = await _getUserMedia();
    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);
    pc.addStream(_localStream);
    var limit = 0;
    pc.onIceCandidate = (e) {
      if (limit == 0) {
        if (e.candidate != null) {
          print(json.encode({
            'candidate': e.candidate.toString(),
            'sdpMid': e.sdpMid.toString(),
            'sdpMlineIndex': e.sdpMlineIndex
          }));
        }
        var candy = (json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex
        }));
        socket.emit("sendingCandidate", candy);
        limit = 1;
      }
    };
    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      // <---------- Getting the remote stream here
      print('addStream: ' + stream.id);
      _guestRenderer.srcObject = stream;
    };
    print("At the end of peerconnection");
    return pc;
  }

  _send(event, data, peerid) {
    var request = Map();
    request["type"] = event;
    request["data"] = data;
    var datas = new List.filled(2, [], growable: false);
    datas[0].add(event);
    datas[1].add(data);
    socket.emit(event, data);
    socket.emit("rec", peerid);
    print("This is the request form user -> " + data);
  }

  _sendAns(event, data, peerid) {
    var request = Map();
    request["type"] = event;
    request["data"] = data;
    var datas = new List.filled(2, [], growable: false);
    datas[0].add(event);
    datas[1].add(data);
    socket.emit(event, data);
    socket.emit("recAns", peerid);
    print("This is the request form user -> " + data);

    //socket.emit("sendingCandidate", candy);
  }

  _createOffer(String peerId) async {
    RTCSessionDescription description = await _peerConnection.createOffer({
      'offerToReceiveVideo': 1
    }); //      <------------ createOffer()  initiates the creation of an SDP offer for the purpose of starting a new WebRTC connection to a remote peer.
    var session = parse(description.sdp!.toString());
    _offer = true;
    _peerConnection.setLocalDescription(description);
    debugPrint("Printing before Sending sdp -> " + json.encode(session));
    _send("offer", json.encode(session), peerId);
  }

  _createAnswer(String peerId) async {
    setState(() {
      inCalling = true;
    });
    RTCSessionDescription description =
        await _peerConnection.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());
    print(json.encode(session));
    _peerConnection.setLocalDescription(description);
    _sendAns("answer", json.encode(session), peerId);
  }

  void _setRemoteDescription(_sdp) async {
    String data = _sdp.toString();
    dynamic session = await jsonDecode("$_sdp");
    print(" This is session " + session.toString());
    String sdp = write(session, null);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    await _peerConnection.setRemoteDescription(description);
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

  replying() {
    socket.emit('reply');
  }

  call(String string) async {
    String peerId = string;
    setState(() {
      inCalling = true;
    });

    _createOffer(peerId);
  }

  void _addCandidate(String candy) async {
    dynamic session = await jsonDecode('$candy');
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }

  connectToUser(String string) {}

  void initRenders() async {
    await _selfRenderer.initialize();
    await _guestRenderer.initialize();
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
                            onPressed: () =>
                                {_createAnswer(arrayUser![index].toString())},
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
                            onPressed: () =>
                                {call(arrayUser![index].toString())},
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
