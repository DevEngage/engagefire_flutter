
import 'package:engagefire/core/firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
// TODO:
// [ ] Provider list firestore
// [ ] queryList method for grouped lists
// [ ] Test: queries

class EngageProvider extends EngageFirestore with ChangeNotifier {

  // final List<String> collections;
  // final List<String> states;
  final String path;
  List _list;

  EngageProvider(this.path):  super(path);

  // getList() => _list;

  $() {

    notifyListeners();
  }

}