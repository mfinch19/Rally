/**
 * Rally -- Let's get together.
 * Copyright (C) 2021 - Sean Murphy, Matt Finch, Joey Lane, & Will Hayward
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'src/auth.dart';
import 'src/classes/eventclass.dart';
import 'src/widgets.dart';
import 'src/home.dart';
import 'src/classes/messageclass.dart';
import 'src/classes/userclass.dart';
import 'src/classes/memberclass.dart';
import 'src/classes/inviteclass.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ApplicationState(),
      builder: (context, _) => App(),
    ),
  );
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Event Chat',
      theme: ThemeData(
        buttonTheme: Theme.of(context).buttonTheme.copyWith(
              highlightColor: Colors.deepPurple,
            ),
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.openSansTextTheme(
          Theme.of(context).textTheme,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: NavMenu(), //const HomePage(),
    );
  }
}

//STATE
class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  Future<void> init() async {
    await Firebase.initializeApp();

    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _loginState = ApplicationLoginState.loggedIn;

        // test subscription

        //events subscription
        _eventsSubscription = FirebaseFirestore.instance
            .collection('events')
            .where("members", arrayContains: user.uid)
            //.orderBy('timestamp', descending: true)
            .snapshots()
            .listen((snapshot) {
          _events = [];
          for (final document in snapshot.docs) {
            _events.add(
              EventClass(
                id: document.id,
                name: document.data()['name'] as String,
                title: document.data()['title'] as String,
                desc: document.data()['desc'] as String,
                date: document.data()['date'] as String,
                date_time: document.data()['date_time'].toDate() as DateTime,
                location: document.data()['location'] as String,
                participants: document.data()['participants'] as int,
                thumbnail: document.data()['thumbnail'] as String,
                //invited: document.data()['invited'] as List,
                //members: document.data()['members'] as List,
              ),
            );
          }
          notifyListeners();
        });

        _invitedeventsSubscription = FirebaseFirestore.instance
            .collection('events')
            .where("invited", arrayContains: user.uid)
            //.orderBy('timestamp', descending: true)
            .snapshots()
            .listen((snapshot) {
          _invitedevents = [];
          for (final document in snapshot.docs) {
            _invitedevents.add(
              EventClass(
                id: document.id,
                name: document.data()['name'] as String,
                title: document.data()['title'] as String,
                desc: document.data()['desc'] as String,
                date: document.data()['date'] as String,
                date_time: document.data()['date_time'].toDate() as DateTime,
                location: document.data()['location'] as String,
                participants: document.data()['participants'] as int,
                thumbnail: document.data()['thumbnail'] as String,
                //invited: document.data()['invited'] as List,
                //members: document.data()['members'] as List,
              ),
            );
          }
          notifyListeners();
        });

        _usersSubscription = FirebaseFirestore.instance
            .collection('users')
            //.orderBy('timestamp', descending: true)
            .snapshots()
            .listen((snapshot) {
          _users = [];
          for (final document in snapshot.docs) {
            _users.add(
              UserClass(
                userId: document.id,
                name: document.data()['name'] as String,
                bio: document.data()['bio'] as String,
              ),
            );
          }
          notifyListeners();
        });

        //ELSE CONDITION
      } else {
        _loginState = ApplicationLoginState.loggedOut;

        //events subscription
        _events = [];
        _eventsSubscription?.cancel;

        //messages subscription???
      }
      notifyListeners();
    });
  }

  ApplicationLoginState _loginState = ApplicationLoginState.loggedOut;
  ApplicationLoginState get loginState => _loginState;

  String? _email;
  String? get email => _email;

// Events
  StreamSubscription<QuerySnapshot>? _eventsSubscription;
  //FIXME guestbook message to event
  List<EventClass> _events = [];
  List<EventClass> get events => _events;

  StreamSubscription<QuerySnapshot>? _invitedeventsSubscription;
  //FIXME guestbook message to event
  List<EventClass> _invitedevents = [];
  List<EventClass> get invitedevents => _invitedevents;

  //Users
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  List<UserClass> _users = [];
  List<UserClass> get users => _users;

  List<UserClass> _notinvitedlist = [];
  List<UserClass> get notinvitedlist => _notinvitedlist;

  List<InviteClass> _invitedlist = [];
  List<InviteClass> get invitedlist => _invitedlist;

  List<InviteClass> _userinvites = [];
  List<InviteClass> get userInvites => _userinvites;

  //StreamSubscription<QuerySnapshot>? _messagesSubscription;
  List<MessageClass> _messages = [];
  List<MessageClass> get messages => _messages;

  //Members
  List<MemberClass> _members = [];
  List<MemberClass> get members => _members;

///////////////// LOGIN FLOW ///////////////////////////
  void startLoginFlow() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  Future<void> verifyEmail(
    String email,
    void Function(FirebaseAuthException e) errorCallback,
  ) async {
    try {
      var methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.contains('password')) {
        _loginState = ApplicationLoginState.password;
      } else {
        _loginState = ApplicationLoginState.register;
      }
      _email = email;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
    void Function(FirebaseAuthException e) errorCallback,
  ) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  //Auth!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  void cancelRegistration() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  Future<void> registerAccount(
      String email,
      String displayName,
      String password,
      void Function(FirebaseAuthException e) errorCallback) async {
    try {
      var credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.updateDisplayName(displayName);
      await FirebaseFirestore.instance
          .collection("users")
          .doc(credential.user!.uid)
          .set(<String, dynamic>{
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'name': FirebaseAuth.instance.currentUser!.displayName,
        'bio': "new rally user",
      });
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void signOut() {
    FirebaseAuth.instance.signOut();
  }

  //Events !!!!!!!!!! add other fields
  Future<DocumentReference> addEvent(
      String title,
      String desc,
      DateTime date_time,
      String date,
      String location,
      int participants,
      String thumbnail) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance
        .collection('events')
        .add(<String, dynamic>{
      'title': title,
      'desc': desc,
      'date_time': date_time,
      'date': date,
      'participants': participants,
      'location': location,
      'thumbnail': thumbnail,
      'name': FirebaseAuth.instance.currentUser!.displayName,
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'members': [FirebaseAuth.instance.currentUser!.uid],
    }).then(
      (eventref) => FirebaseFirestore.instance
          .collection('events/' + eventref.id + "/members")
          .add(<String, dynamic>{
        'userId': eventref.id,
        'name':
            FirebaseAuth.instance.currentUser!.displayName ?? "No Display Name",
        'role': "Owner",
      }),
    );
  }

  //add Messages
  //FIX me add timestamp
  Future<DocumentReference> addMessage(String text, String eventid) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance
        .collection('events/' + eventid + "/messages")
        .add(<String, dynamic>{
      'text': text,
      'name': FirebaseAuth.instance.currentUser!.displayName,
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  List addmemberlist = [];
  //int addparticipantint = 0;
  Future<DocumentReference> addMember(
      String userId, String name, String role, String eventid) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    FirebaseFirestore.instance
        .collection("events")
        .doc(eventid)
        .update(<String, dynamic>{
      'participants': FieldValue.increment(1),
      'members': FieldValue.arrayUnion([userId]),
    });

    return FirebaseFirestore.instance
        .collection('events/' + eventid + "/members")
        .add(<String, dynamic>{
      'userId': userId,
      'name': name,
      'role': role,
    });
  }

  List addinvitelist = [];
  Future<void> addInvite(String userId, String eventname, String eventid) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }
    //add to array too?
    FirebaseFirestore.instance
        .collection("events")
        .doc(eventid)
        .get()
        .then((value) => {addinvitelist = value["invited"]});
    addinvitelist.add(userId);
    FirebaseFirestore.instance
        .collection('events')
        .doc(eventid)
        .update(<String, dynamic>{
      //'userId': userId,
      'invited': addinvitelist,
    });

    return FirebaseFirestore.instance
        .collection('users/' + userId + "/invited")
        .doc(eventid)
        .set(<String, dynamic>{
      //'userId': userId,
      'eventname': eventname,
      'eventId': eventid,
    });
  }

  //get messages
  List<MessageClass> getMessages(String eventid) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    FirebaseFirestore.instance
        .collection('events/' + eventid + '/messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _messages = [];
      for (final document in snapshot.docs) {
        _messages.add(
          MessageClass(
            id: document.id,
            userId: document.data()['userId'] as String,
            name: document.data()['name'] as String,
            text: document.data()['text'] as String,
            timestamp: document.data()['timestamp'] as Timestamp,
          ),
        );
      }
      notifyListeners();
    });
    return _messages;
  }

  DocumentReference getUser(String userid) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }
    return FirebaseFirestore.instance.doc('users/' + userid);
  }

  List<MemberClass> getMembers(String eventid) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    FirebaseFirestore.instance
        .collection('events/' + eventid + '/members')
        .snapshots()
        .listen((snapshot) {
      _members = [];
      for (final document in snapshot.docs) {
        _members.add(
          MemberClass(
            //id: document.id,
            userId: document.data()['userId'] as String,
            name: document.data()['name'] as String,
            role: document.data()['role'] as String,
          ),
        );
      }
      notifyListeners();
    });
    return _members;
  }

  List<InviteClass> getUserInvites(String userid) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }
    //NEED WHERE IN INVITES FIXME
    FirebaseFirestore.instance
        .collection('users/' + userid + "/invited")
        .snapshots()
        .listen(
      (snapshot) {
        _invitedlist = [];
        for (final document in snapshot.docs) {
          _invitedlist.add(
            InviteClass(
              //id: document.id,
              eventId: document.data()['eventId'] as String,
              eventname: document.data()['eventname'] as String,
            ),
          );
        }
        notifyListeners();
      },
    );

    return _invitedlist;
  }

  // Delete invite
  Future<void> deleteInvite(String eventid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('invited')
        .doc(eventid)
        .delete();
  }

  Future<void> editEvent(
      String eventid,
      String title,
      String desc,
      DateTime date_time,
      String date,
      String location,
      int participants,
      String thumbnail) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance
        .collection('events')
        .doc(eventid)
        .update(<String, dynamic>{
      'title': title,
      'desc': desc,
      'date_time': date_time,
      'date': date,
      'location': location,
      'participants': participants,
      'thumbnail': thumbnail,
      // 'name': FirebaseAuth.instance.currentUser!.displayName,
      // 'userId': eventid,
    });
  }
}
