
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engagefire/core/firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'doc.dart';
 
// TODO:
// [ ] Provider list firestore
// [ ] queryList method for grouped lists
// [ ] Test: queries

class EngageProvider extends EngageFirestore with ChangeNotifier {

  // final List<String> collections;
  // final List<String> states;
  final String path;
  Map defaultData = {};

  EngageProvider(this.path, [this.defaultData]): super(path);

  $notifyListeners() {
    notifyListeners();
  }

  @override
  publish(data, String what) {
    notifyListeners();
    return super.publish(data, what);
  }
  
  Future<dynamic> saveAndNotifiy(newDoc, {CollectionReference listRef}) async {
    final doc = await super.save(newDoc, listRef: listRef);
    notifyListeners();
    return doc;
  }

  removeAndNotifiy(id, [CollectionReference listRef]) {
    final result = super.remove(id, listRef);
    notifyListeners();
    return result;
  }

  // @override
  // watchList(cb, [CollectionReference listRef]) {
  //   return  super.watchList((snapshot) {
  //     cb(snapshot);
  //     notifyListeners();
  //   }, listRef);
  // }

  // @override
  // watch(id, cb, [CollectionReference listRef]) {
  //   return  super.watch(id, (doc, snapshot) {
  //     cb(doc, snapshot);
  //     notifyListeners();
  //   }, listRef);
  // }
  
  @override
  Future<EngageDoc> getOrCreate({dynamic defaultData, Map filter, String id}) async {
    return super.getOrCreate(defaultData: defaultData ?? this.defaultData, filter: filter, id: id);
  }

}

class EngageProviderDoc extends EngageDoc with ChangeNotifier {

  EngageProviderDoc({String path, Map data, bool ignoreInit = false}): 
    super(path: path, data: data, ignoreInit: ignoreInit);

  @override
  $publish([data]) {
    super.$publish(data);
    notifyListeners();
  }

}