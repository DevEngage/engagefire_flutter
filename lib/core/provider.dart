
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
// TODO:
// [ ] Provider list firestore
// [ ] queryList method for grouped lists
// [ ] Test: queries

class EngageProvider with ChangeNotifier {

  final List<String> collections;
  final List<String> states;
  List _list;

  EngageProvider(this.collections, this.states) {
    // collections.
  }

  getList() => _list;

  $() {

    notifyListeners();
  }

}