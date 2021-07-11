import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  //MediaStream _localStream ;
  RTCVideoRenderer _selfRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _guestRenderer = new RTCVideoRenderer();
  JsonDecoder _decoder = JsonDecoder();
  // RTCPeerConnection _peerConnection;
  // MediaStream _localStream;
  TextEditingController _fieldController = new TextEditingController();
//  TextEditingController _selfID = new TextEditingController();
  bool useScreen = false;
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
    initRenders();
    invite(widget.peerId, 'video', false);
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
      RTCSessionDescription s =
          await session.pc.createOffer({'offerToReceiveVideo ': 1});
      print(s.toString());
      // var sddp = parse(s.sdp);//   <-----------Generting sdp for debugging readability.
      // print(jsonEncode(session));
      await session.pc.setLocalDescription(s);
      // _send('offer', {
      //   'to' : session.pid,
      //   'from' : _selfId,
      //   'description' : {'sdp' :s.sdp, 'type' : s.type},
      //   'session_id' : session.sid,
      //   'media' : media,
      // });
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
