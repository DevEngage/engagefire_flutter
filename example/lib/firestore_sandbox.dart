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
    user = EngageDoc(path: 'testing/{userId}');
    user.$toggleSub('favorites', {'\$id': 'group'});
    Future.delayed(Duration(seconds: 4), () async {
      print(await user.$subExists('favorites', 'group'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: streamTest()
    );
  }

  streamTest() {
    return StreamBuilder<dynamic>(
      stream: EngageFirestore.getInstance('testing').stream(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasError) {
          return new Text("Error!");
        } else if (snapshot.data == null) {
          return Text('test');
        } else {
          return Column(children: <Widget>[
            ...snapshot.data.map((item) => Text(item.$doc['name']))
          ],);
          // print(snapshot.data);
        }

        return Text('test');
    });
  }

  futureTest() {
    return FutureBuilder(
      future: users.getOrCreate(defaultData: { 'name': 'James', }, filter: {'userId.isEqualTo.default': '{userId}'}),
      builder: (BuildContext context, AsyncSnapshot<EngageDoc> snapshot) {
        return ListView(children: <Widget>[
          if (snapshot.hasData) Text('Name: ' + snapshot.data.$doc['name']),
          if (snapshot.error != null) Text(snapshot.error),
          if (!snapshot.hasData) Text('Loading'),
        ],);
      }, 
    );
  }
}