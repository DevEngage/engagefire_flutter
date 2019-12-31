import 'package:engagefire/core/doc.dart';
import 'package:engagefire/core/firestore.dart';
import 'package:flutter/material.dart';
// import 'package:engage_admin/utils/color_constants.dart';

class FirestoreSandbox extends StatefulWidget {
  FirestoreSandbox({
    Key key, 
  }) : super(key: key);

  @override
  _FirestoreSandboxState createState() => _FirestoreSandboxState();
}

class _FirestoreSandboxState extends State<FirestoreSandbox> {
  final _formKey = GlobalKey<FormState>();
  EngageFirestore users;
  EngageDoc user;
  _FirestoreSandboxState() {
    users = EngageFirestore.getInstance('users');
    user = EngageDoc(path: 'testing/{userId}', subCollections: ['favorites']);
    Future.delayed(Duration(seconds: 4), () async {
      // print(user.$collections);
      EngageFirestore favorites = user.$collections['favorites_'];
      await favorites.save(<String, dynamic>{'name': 'test', 'age': 12});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: FutureBuilder(
      future: users.getOrCreate(defaultData: { 'name': 'James', }, filter: {'userId.isEqualTo.default': '{userId}'}),
      builder: (BuildContext context, AsyncSnapshot<EngageDoc> snapshot) {
        return ListView(children: <Widget>[
          if (snapshot.hasData) Text('Name: ' + snapshot.data.$doc['name']),
          if (snapshot.error != null) Text(snapshot.error),
          if (!snapshot.hasData) Text('Loading'),
        ],);
      }, 
    ),);
  }
}