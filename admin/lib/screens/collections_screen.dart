import 'package:flutter/material.dart';

class CollectionsScreen extends StatefulWidget {
  @override
  CollectionsScreenState createState() {
    return CollectionsScreenState();
  }
}

class CollectionsScreenState extends State<CollectionsScreen> {
  CollectionsScreenState();

  @override
  void initState() {
    super.initState();
    this._load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('Error'),
          Padding(
            padding: const EdgeInsets.only(top: 32.0),
            child: RaisedButton(
              color: Colors.blue,
              child: Text('reload'),
              onPressed: () => this._load(),
            ),
          ),
        ],
    ));
  }

  void _load([bool isError = false]) {
  }
}
