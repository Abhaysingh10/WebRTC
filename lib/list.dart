// import 'package:flutter/material.dart';
// import 'package:web_socket/Call.dart';

// class List extends StatefulWidget {
//   const List({ Key? key }) : super(key: key);

//   @override
//   _ListState createState() => _ListState();
// }

// class _ListState extends State<List> {

//   Map<String, Session> _sessions = {};
//   // String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
//   //    // length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))
//   //    ));
//   Map<String, dynamic> _iceServers = {
//     'iceServers': [
//       {'url': 'stun:stun.l.google.com:19302'},
//       /*
//        * turn server configuration example.
//       {
//         'url': 'turn:123.45.67.89:3478',
//         'username': 'change_to_real_user',
//         'credential': 'change_to_real_secret'
//       },
//       */
//     ]
//   };

//   get socket => null;

  
//   void onMessage(message) async {
//     Map<String, dynamic> mapData = message;
//     var data = mapData['data'];
//     // print("Mapped Data" + data.toString());
//     print("This is map data just before switch case " +
//         mapData["type"].toString());
//     switch (mapData["type"]) {
//       case "offer":
//         {
//           print("Inside offer");
//           var peerId = data['from'];
//           var description = data['description'];
//           var media = data['media'];
//           var sessionId = data['session_id'];
//           print("This is session in offer case sessionId-> " + sessionId);
//           print("This is session in offer case -> _sessions " +
//               _sessions.entries.toString());
//           var session = _sessions[sessionId];
//           print("This is session in offer case -> " + session!.pid.toString());
//           print("This is session in offer case -> " + session.toString());
//           var newSession = await _createSession(
//               //session: session,
//               peerId: peerId,
//               sessionId: sessionId,
//               media: media,
//               screenSharing: false);
//           _sessions[sessionId] = newSession;
//           await newSession.pc.setRemoteDescription(
//               RTCSessionDescription(description['sdp'], description['type']));
//           await _createAnswer(newSession, media);
//         }
//         break;
//       case 'answer':
//         {
//           print("In answer case");
//           var description = data['description'];
//           var sessionId = data['session_id'];
//           //print("This is description from answer " + description.toString());
//           print("This is session in answer case" + sessionId.toString());
//           print("This is session in answer case description['sdp'] => " +
//               description['sdp'].toString());
//           print("This is session in answer case description['type'] => " +
//               description['type'].toString());
//           var session = _sessions[sessionId];
//           print("TThis is session in answer case" + session.toString());
//           print("This is session in answer case" + session!.pid.toString());
//           session.pc.setRemoteDescription(
//               RTCSessionDescription(description['sdp'], description['type']));
//           print("Remote description done right");
//         }
//         break;
//       case 'candidate':
//         {
//           var peerId = data['from'];
//           var candidateMap = data['candidate'];
//           var sessionId = data['session_id'];
//           var session = _sessions[sessionId];
//           RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'],
//               candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
//           print(session!.pc.toString());
//           // ignore: unnecessary_null_comparison
//           if (session != null) {
//             // ignore: unnecessary_null_comparison
//             if (session.pc != null) {
//               await session.pc.addCandidate(candidate);
//             } else {
//               session.remoteCandidates.add(candidate);
//             }
//           } else {
//             _sessions[sessionId] = Session(pid: peerId, sid: sessionId)
//               ..remoteCandidates.add(candidate);
//           }
//         }
//         break;

//       default:
//     }
//   }

//   Future<void> _createAnswer(Session session, String media) async {
//     try {
//       RTCSessionDescription s =
//           await session.pc.createAnswer(media == "data" ? _dcConstraints : {});
//       // print("This is session description -> " + s.sdp.toString());
//       await session.pc.setLocalDescription(s);
//       print("Got here till sending answer");
//       _sendAnswer('answer', {
//         'to': session.pid,
//         'from': _selfId,
//         'description': {'sdp': s.sdp, 'type': s.type},
//         'session_id': session.sid,
//       });
//     } catch (e) {}
//   }

//   initRenders() async {
//     await _selfRenderer.initialize();
//     await _guestRenderer.initialize();
//   }

//   refresh() {
//     socket.emit("refresh");
//     socket.on("RefreshResponse", (users) {
//       setState(() {
//         arrayUser = users;
//       });
//     });
//     print("This is array of users----> $arrayUser");
//     return arrayUser;
//   }

//   update(users) {
//     List<dynamic> userId = users;
//     print(userId);
//   }

//   invite(String peerId, String media, useScreen) async {
//     var sessionId = _selfId + '-' + peerId;
//     Session session = await _createSession(
//       sessionId: sessionId,
//       peerId: peerId,
//       media: media,
//       screenSharing: useScreen,
//     );
//     _session[sessionId] = session;
//     print("This is sessionId" + sessionId.toString());
//     _createOffer(
//       session,
//       media,
//     );
//   }

//   final Map<String, dynamic> _dcConstraints = {
//     'mandatory': {
//       'OfferToReceiveAudio': false,
//       'OfferToReceiveVideo': false,
//     },
//     'optional': [],
//   };

//   void disconnect() {
//     socket.emit("disconnectt");
//     //socket.disconnect();
//     print(socket.connected);
//   }

//   @override
//   void dispose() {
//     socket.destroy();
//     disconnect();
//     super.dispose();
//   }

//   connectToUser(String peerID) {
//     peerId = peerID;
//   }

//   call(String _peerId) {
//     invite(_peerId, "video", false);
//   }

//   replying() {
//     socket.emit("getMeSdp");
//   }

//   Future<void> _createOffer(Session session, String media) async {
//     try {
//       // setState(() {
//       //   inCalling = true;
//       // });
//       print("This is session in _createOffer-> " + session.pid.toString());
//       print(("This is session pc in _createOffer-> " + session.pc.toString()));
//       RTCSessionDescription s =
//           await session.pc.createOffer({'offerToReceiveVideo ': 1});
//       print(s.toString());
//       // var sessionn = parse(s.sdp
//       //     .toString()); //   <-----------Generting sdp for debugging readability.
//       // print(jsonEncode(sessionn));
//       await session.pc.setLocalDescription(s);
//       _send('offer', {
//         'to': session.pid,
//         'from': _selfId,
//         'description': {'sdp': s.sdp, 'type': s.type},
//         'session_id': session.sid,
//         'media': media,
//       });
//     } catch (e) {
//       print(e.toString());
//     }
//   }

//   Future<Session> _createSession(
//       {required String sessionId,
//       required String peerId,
//       required String media,
//       required bool screenSharing}) async {
//     var newSession = Session(sid: sessionId, pid: peerId);
//     _localStream = await _getUserMedia();

//     print(_iceServers);
//     RTCPeerConnection pc = await createPeerConnection({
//       ..._iceServers,
//     }, _config);

//     pc.addStream(_localStream);
//     pc.onAddStream = (MediaStream stream) {
//       _remoteStreams.add(stream);
//       _guestRenderer.srcObject = stream;
//       setState(() {
//         inCalling = true;
//       });
//     };
//     pc.onIceCandidate = (e) {
//       if (e.candidate != null) {
//         print(e.candidate.toString() +
//             e.sdpMid.toString() +
//             e.sdpMlineIndex.toString());

//         //    print("This is selfId " + _selfId + " " + socket.connected.toString());
//         //    print("This is peerId" + peerId);
//       }
//       //  socket.emit("check", "add camdidate "); not working

//       _send('candidate', {
//         'to': peerId,
//         'from': _selfId,
//         'candidate': {
//           'sdpMLineIndex': e.sdpMlineIndex,
//           'sdpMid': e.sdpMid,
//           'candidate': e.candidate,
//         },
//         'session_id': sessionId,
//       });
//     };
//     // print("This is Session Id" + sessionId);
//     newSession.pc = pc;
//     return newSession;
//   }

//   _send(event, data) {
//     var request = Map();
//     request["type"] = event;
//     request["data"] = data;
//     // /socket.emit("SendingpeerID", peerId);
//     socket.emit("offer", _encoder.convert(request));
//     //print("This is the request form user -> " + _encoder.convert(request));
//   }

//   _sendAnswer(event, data) {
//     var request = Map();
//     request["type"] = event;
//     request["data"] = data;
//     socket.emit("ans", _encoder.convert(request));
//     //print("This is the request form user -> " + _encoder.convert(request));
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Container(
      
//     );
//   }
// }

// mixin _guestRenderer {
// }

// mixin _chars {
// }