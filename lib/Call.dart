import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class CallPage extends StatefulWidget {
  late String _selfId;
  late String peerId;
  CallPage(this._selfId, this.peerId, {Key? key}) : super(key: key);

  @override
  _CallPageState createState() => _CallPageState();
}

class Session {
  Session({required this.sid, required this.pid});
  String sid;
  String pid;
  late SharedPreferences sharedPrefrences;
  late RTCPeerConnection pc;
  late RTCDataChannel dc;
  late RTCVideoRenderer _selfRenderer;
  late TextEditingController fieldController;
  List<RTCIceCandidate> remoteCandidates = [];
}

class _CallPageState extends State<CallPage> {
  late Session session;
  late Map<String, dynamic> description;
  //MediaStream _localStream ;
  RTCVideoRenderer _selfRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _guestRenderer = new RTCVideoRenderer();
  JsonDecoder _decoder = JsonDecoder();
  // RTCPeerConnection _peerConnection;
  // MediaStream _localStream;
  TextEditingController _fieldController = new TextEditingController();
//  TextEditingController _selfID = new TextEditingController();
  bool useScreen = false;
  late IO.Socket socket;
  late MediaStream _localStream;
  JsonEncoder _encoder = new JsonEncoder();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  Map<String, Session> _session = {};
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

  //------------------------------------------------------------------------
  // Server Section

  void connect() {
    socket = IO.io("https://db29d4b8b315.ngrok.io", <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false
    });
    socket.connect();
    socket.onConnect((data) => print("connected"));
    print(socket.connected);
    //socket.on("offerReply", (data) => onMessage(data));
    socket.on("answer", (desc) {
      description = desc;
      print("This is answer " + description.length.toString());
    });
  }

  answer() {}

  //-----------------------------------------------------------------------

  // void onMessage(message) async {
  //   Map<String, dynamic> mapData = message;
  //   var data = mapData["data"];
  //   switch (mapData["type"]) {
  //     case "offer":
  //       {
  //         var peerId = data['from'];
  //         var description = data['description'];
  //         var media = data['media'];
  //         var sessionId = data['session_id'];
  //         var session = _session[sessionId];
  //         var newSession = await _createSession(
  //             peerId: peerId,
  //             sessionId: sessionId,
  //             media: media,
  //             screenSharing: false);
  //         _session[sessionId] = newSession;
  //         await newSession.pc.setRemoteDescription(
  //             RTCSessionDescription(description['sdp'], description['type']));
  //         await _createAnswer(newSession, media);
  //         if (newSession.remoteCandidates.length > 0) {
  //           newSession.remoteCandidates.forEach((candidate) async {
  //             await newSession.pc.addCandidate(candidate);
  //           });
  //           newSession.remoteCandidates.clear();
  //         }
  //       }
  //       break;
  //     case 'answer':
  //       break;
  //     case "candidate":
  //       break;
  //     default:
  //   }
  // }

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
  // createStream(String mediaStream, bool screenSharing) {}

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    connect();
    initRenders();
    if (widget.peerId == "nothing") {
      reply();
    } else {
      invite(widget.peerId, 'video', false);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _selfRenderer.dispose();
    _localRenderer.dispose();
  }

  void reply() {
    print("This is reply section");
    socket.emit("reply");
  }

  initRenders() async {
    await _selfRenderer.initialize();
    await _guestRenderer.initialize();
  }

  getId() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    widget._selfId = preferences.getString("selfId")!;
  }

  invite(String peerId, String media, useScreen) async {
    var sessionId = widget._selfId + '-' + peerId;
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

  Future<void> _createOffer(Session session, String media) async {
    try {
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
        'from': widget._selfId,
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
        print("This is selfId" + widget._selfId);
        print("This is peerId" + peerId);
      }
      _send('candidate', {
        'to': peerId,
        'from': widget._selfId,
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
    // _webSocket.send(_encoder.convert(request));
    socket.emit("offer", _encoder.convert(request));
    print("This is the request form user -> " + (_encoder.convert(request)));
  }

  Future<void> _reply(String media, var value) async {
    var message = await _decoder.convert(value);
    print("This is dynamic message->> " + message.toString());
    Map<String, dynamic> mapData = message;
    var data = mapData["data"];
    try {
      var peerId = data['from'];
      var description = data['description'];
      var media = data = data["media"];
      var sessionId = data['session_id'];
      var session = _session[sessionId];
      var newSession = await _createSession(
          sessionId: sessionId,
          peerId: peerId,
          media: media,
          screenSharing: false);
      _session[sessionId] = newSession;
      await newSession.pc.setRemoteDescription(
          RTCSessionDescription(description["sdp"], description["type"]));
      _createAnswer(newSession, media);
      if (newSession.remoteCandidates.length > 0) {
        newSession.remoteCandidates.forEach((candidate) async {
          await newSession.pc.addCandidate(candidate);
        });
        newSession.remoteCandidates.clear();
      }
    } catch (e) {}
  }

  Future<void> _createAnswer(Session session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc.createAnswer(media == "media" ? _dcConstraints : {});
      await session.pc.setRemoteDescription(s);
      // _send('answer', {
      //   'to': session.pid,
      //   'from': _selfId,
      //   'description': {'sdp': s.sdp, 'type': s.type},
      //   'session_id': session.sid,
      // });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        )
      ]),
    );
  }
}
