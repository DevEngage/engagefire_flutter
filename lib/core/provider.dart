
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Map defaultData = {};

  EngageProvider(this.path, [this.defaultData]):  super(path);

  $notifyListeners() {
    notifyListeners();
  }

  @override
  publish(data, String what) {
    // TODO: implement publish
    notifyListeners();
    return super.publish(data, what);
  }
  
  Future<dynamic> saveAndNotifiy(newDoc, {CollectionReference listRef}) async {
    final doc = await super.save(newDoc, listRef: listRef);
    notifyListeners();
    return doc;
  }
  
  Future<dynamic> addAndNotifiy(Map<String, dynamic> newDoc, {dynamic docRef, ignoreInit = false}) async {
    final doc = await super.add(newDoc, docRef: docRef, ignoreInit: ignoreInit);
    notifyListeners();
    return doc;
  }



}