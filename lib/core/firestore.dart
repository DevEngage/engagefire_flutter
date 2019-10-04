import 'dart:async';

import 'package:engagefire/core/auth.dart';
import 'package:engagefire/core/doc.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'omittedList.dart';

/*
 * TODO:
 * [X] Show upload progress
 * [X] Handle file uploads better
 * [X] Add types (models) to doc in class
 * [X] Change doc methods to doc prototype methods. Maybe make a class?
 * [ ] Test listen
 * [ ] Implement State Manage,
 * [ ] Create query system that can save query models
 * [ ] Fully test everything!
 * [ ] Add Model system
 * [ ] Integrate User name ($getUserName)
 * */
class EngageFirestore {
  static var STATE;
  static Map<String, EngageFirestore> instances = {};
  final Firestore _db = Firestore.instance;
  final EngagePubsub _ps = engagePubsub;
  CollectionReference ref;

  List<String> omitList;
  List<String> subCollections = [];
  List list = [];
  List model = [];

  String sortedBy = '';
  FirebaseUser $user;
  String userId = '';
  var state = {};
  bool $loading = true;
  bool debug = false;
  String path = '';

  EngageFirestore(this.path) {
    omitList = OMIT_LIST;
    init();
  }

  Future<void> init() async {
    EngageFirestore.STATE ??= {};
    if (EngageFirestore.STATE[path] == null) {
      EngageFirestore.STATE[path] = {};
      state = EngageFirestore.STATE[path];
    }
    if (path is String) {
      ref = _db.collection(path);
    }
    $user = await EngageAuth().currentUser;
    publish($user, 'user');
    if ($user != null) {
      userId = $user.uid;
      if (debug) print('userId: $userId');
    }
    // await getModelFromDb();
    $loading = false;
  }

  static getInstance(
    String path,
    {options, }
  ) {
    if (EngageFirestore.instances[path] == null)  {
      EngageFirestore.instances[path] = EngageFirestore(path);
    }
    if (options != null) {
      return EngageFirestore.instances[path].options(options);
    }
    return EngageFirestore.instances[path];
  }

  Future<List> getModelFromDb() async {
    if (path.contains('\$collections')) {
      return this.model = [];
    }
    this.model = await EngageFirestore.getInstance('\$collections/$path/\$models').getList();
    await this.sortModel();
    return this.model;
  }

  List getModel() {
    return this.model;
  }
  
  Future sortModel() async {
    this.sortListByPosition(false, false, this.model);
    return this;
  }

  options([var options ]) {
    options = options ?? { 'loadList': true };
    if (options.loadList) {
      this.getList();
    }
    return this;
  }

  /* 
  field.isEqualTo: 1
  */
  buildQuery(Map filter, [customRef]) {
    customRef ??= ref;
    filter.forEach((key, value) {
      List<String> keys = key.split('.');
      String field = keys[0];
      String type = keys[1];
      switch (type) {
        case 'isEqualTo':
          customRef = customRef.where(field, isEqualTo: value);
          break;
        case 'isLessThan':
          customRef = customRef.where(field, isLessThan: value);
          break;
        case 'isLessThanOrEqualTo':
          customRef = customRef.where(field, isLessThanOrEqualTo: value);
          break;
        case 'isGreaterThan':
          customRef = customRef.where(field, isGreaterThan: value);
          break;
        case 'isGreaterThanOrEqualTo':
          customRef = customRef.where(field, isGreaterThanOrEqualTo: value);
          break;
        case 'isNull':
          customRef = customRef.where(field, isNull: value);
          break;
        case 'isInDay':
          var day = new Duration(days: 1);
          var prev = DateTime.fromMillisecondsSinceEpoch(value).subtract(day);
          var next = DateTime.fromMillisecondsSinceEpoch(value).add(day);
          customRef = customRef.where(field, isNull: value);
          break;
      }
    });
    return customRef;
  }

  getFilterDefaults(Map defaults, Map filter, defaultValue) {
    if (filter != null) {
      defaults ??= {};
      filter.forEach((key, value) {
        if (defaults[key] == null) {
          var keys = key.split('.');
          if (keys[0] != null && keys[2] == 'default') {
            defaults[keys[0]] = getStringVar(value, defaultValue);
          }
        }
      });
    }
    return defaults;
  }

  /* 
  where('grower', isEqualTo: 1)
    String field, {
    dynamic isEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    bool isNull,
     */

  Future<EngageDoc> getFirst({CollectionReference listRef, Map filter}) async {
    var item = await getList(listRef: listRef, filter: filter, limit: 1);
    return item.isEmpty ? null : item[0];
  }

  Future<List> getList({CollectionReference listRef, Map filter, limit}) async {
    $loading = true;
    if (filter != null) {
      var userId = await EngageAuth().currentUserId;
      filter.forEach((key, value) => filter[key] = getStringVar(value, userId));
    }
    dynamic query = listRef ?? ref;
    if (filter != null) {
      query = buildQuery(filter, query);
    }
    if (limit != null) query.limit(limit);
    QuerySnapshot collection;
    collection = await query.getDocuments();
    list = await this.addFireList(collection);
    $loading = false;
    return list;
  }

  Future<List> addFireList(QuerySnapshot collection) async {
    list = [];
    if (collection != null && collection.documents.length != null) {
      collection.documents.map((DocumentSnapshot doc) => doc.exists ? list.add(this.addFire(doc.data, doc.documentID)) : null);
    }
    return list;
  }

  addFire(data, String id, {ignoreInit = false}) {
    if (data == null && id != null) {
      if (data is EngageDoc) {
        data.$id = id;
        data.$doc['\$id'] = id;
      } else {
        data['\$id'] = id;
      }
    }
    if (EngageDoc != null && data is Map) {
      return EngageDoc(data: data, path: path, subCollections: subCollections, ignoreInit: ignoreInit);
    }
    return data;
  }

  omitFireList(List list) {
    return list.map(this.omitFire);
  }

  omitFire(dynamic payload) {
    // if (payload != null && payload['\$omitList'] != null) {
    //   omitList.forEach((item) => payload.remove(item));
    // }
    // omitList.forEach((item) => payload.remove(item));
    if (payload is EngageDoc) {
      payload.$doc.forEach((key, value) => payload.$doc[key] = omitDepth(payload.$doc[key]));
    } else if (payload != null) {
      payload.forEach((key, value) => payload[key] = omitDepth(payload[key]));
    }
    return payload;
  }
  
  omitDepth(dynamic value) {
    // if (value is List) {
    //   value = value.map((item) => item is Map ? this.omitFire(item) : item);
    // }
    if (value is Map) {
      // value = this.omitFire(value);
      // value = value.map((item) => item is Map ? this.omitFire(item) : item);
      value = linkFireCollection(value);
    }
    return value;
  }

  linkFireCollection(value) {
    if (value != null && value['\&id'] != null) {
      return { 
        '\$id': value['\&id'], 
        '\$collection': value['\&collection'],
        '\$thumb': value['\&thumb'],
        '\$image': value['\&image'],
        'name': value['\&name'] ?? '', 
      };
    }
    return value;
  }

  addSubCollections(List<String> collections) {
    this.subCollections = [...this.subCollections, ...collections];
    return this;
  }

  toggleDebug() {
    this.debug = !this.debug;
  }

  canSub() {
    return _ps != null;
  }

  publish(var data, String what) {
    return this._ps.publish(data, what);
  }

  subscribe(String what, listener) {
    return _ps.subscribe(what, listener);
  }

  /* 
    LIST
   */
  sortList([var sortFunc, var _list]) {
    (_list ?? list).compareTo(sortFunc);
  }

  sortListByPosition([fresh = false, reverse = false, var list]) {
    this.sortedBy = 'position';
    if (fresh) {
      this.getListByPosition(reverse);
    } else {
      this.sortList((var x, var y) => reverse ? y.position - x.position : x.position - y.position, list);
    }
    return this;
  }

  Future getListByPosition([bool direction = false]) async {
    var ref = this.ref.orderBy('position', descending: direction);
    return this.getList(listRef: ref);
  }

  Future buildListPositions() async {
    await this.getList();
    print('Started Building positions...');
    this.sortListByPosition();
    var index = 0;
    this.list.map((item) async => await item.$setPosition(index++));
    print('Finished Building positions...');
  }

  /* DOC AND LIST */

  Future<dynamic> getChildDocs(Map doc) async {
    return doc.map((item, key) => 
      item != null && item['\$id'] != null && item['\$collection'] != null ? EngageFirestore.getInstance("$item['\$collection']/$item['\$id']") : null 
    );
  }

   Future<dynamic> getWithChildern(docId, {CollectionReference listRef}) async {
    var doc = await get(docId, listRef: listRef);
    if (doc) {
      doc = await this.getChildDocs(doc);
    }
    return doc;
  }

  getStringVar(dynamic what, [replaceWith]) {
    if (what is String && (what.contains('{userId}') || what.contains('{\$userId}'))) {
      return replaceWith ?? userId;
    }
    return what;
  }

  Future<dynamic> get(String docId, {CollectionReference listRef, blank = true, pure}) async {
    $loading = true;
    listRef ??= ref;
    if (docId.contains('{userId}') || docId.contains('{\$userId}')) {
      docId = await EngageAuth().currentUserId;
    }
    if (pure) {
      dynamic doc = await listRef.document(docId).get();
      return doc.exists ? doc.data : {};
    }
    try {
      DocumentSnapshot doc;
      doc = await listRef.document(docId).get();
      $loading = false;
      if (doc.exists) {
        dynamic fireDoc = this.addFire(doc.data, docId);
        num index = this.list.indexOf(fireDoc);
        if (index > -1) this.list[index] = fireDoc;
        else this.list.add(fireDoc);
        return fireDoc;
      }
      return setDoc({'\$updatedAt': DateTime.now().millisecondsSinceEpoch, '\$id': docId}, docRef: listRef);
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<EngageDoc> getOrCreate({Map defaultData, Map filter}) async {
    String userId = await EngageAuth().currentUserId;
    defaultData = getFilterDefaults(defaultData, filter, userId);
    EngageDoc doc;
    EngageDoc found = await getFirst(filter: filter);
    if (found == null) {
      Map<String, dynamic> newMap = {...defaultData};
      doc = await add(newMap);
    } else {
      doc = found;
      if (doc.$setDefaults(defaultData, userId)) {
        await doc.$save();
      }
    }
    return doc;
  }

  Future<dynamic> add(Map<String, dynamic> newDoc, {dynamic docRef, ignoreInit = false}) async {
    docRef ??= ref;
    if (newDoc != null && newDoc['\$id'] != null) {
      return this.update(newDoc, docRef: docRef);
    }
    if (debug) {
      print('add $newDoc');
    }
    newDoc = this.omitFire(newDoc);
    DocumentReference blank = docRef.document();
    newDoc['\$createdAt'] = DateTime.now().millisecondsSinceEpoch;
    newDoc['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    newDoc['\$timezoneOffset'] = DateTime.now().timeZoneOffset.toString();
    newDoc['\$id'] = blank.documentID;
    await blank.setData(newDoc);
    return this.addFire(newDoc, blank.documentID, ignoreInit: ignoreInit);
  }

  Future<dynamic> setDoc(dynamic newDoc, {dynamic docRef}) async {
    if (debug) {
      print('set $newDoc');
    }
    newDoc = omitFire(newDoc);
    newDoc['\$createdAt'] = DateTime.now().millisecondsSinceEpoch;
    newDoc['\$timezoneOffset'] = DateTime.now().timeZoneOffset.toString();
    if (newDoc is EngageDoc) {
      docRef ??= newDoc.$docRef;
      await docRef.setData(newDoc.$doc);
    } else {
      await docRef.document(newDoc).setData(newDoc as Map<String, dynamic>);
    }
    return addFire(newDoc, docRef.documentID);
  }

  Future<dynamic> setWithId(String id, {dynamic newDoc}) async {
    return setDoc(newDoc, docRef: ref.document(id));
  }

  Future<dynamic> update(dynamic doc, {dynamic docRef}) async {
    docRef ??= ref;
    DocumentReference documentRef;
    if (!(doc is EngageDoc) && doc['\$id'] != null) {
      documentRef = docRef.document(doc['\$id']);
      try {
        if ((await documentRef.get()).exists == false) {
          return setDoc(doc, docRef: documentRef);
        }
      } catch (error) {
        // print(error)
        return setDoc(doc, docRef: documentRef);
      }
    } else if (!(doc is EngageDoc) && docRef.id == null && doc['\$id'] == null) {
      print('no id');
    }
    if (debug) {
      print('updated $doc');
    }
    try {
      doc = omitFire(doc);
      if (doc is EngageDoc) {
        documentRef ??= doc.$docRef;
        documentRef = await doc.$docRef.setData(doc.$doc, merge: true);
      } else {
        documentRef = docRef.document(doc['\$id']);
        await documentRef.setData(doc as Map<String, dynamic>, merge: true);
      }
      return addFire(doc, documentRef.documentID);
    } catch (error) {
      print('update error: $error');
      return doc;
    }
  }

  Future<dynamic> save(newDoc, {CollectionReference listRef}) async {
    newDoc = omitFire(newDoc);
    if (newDoc is EngageDoc) {
      newDoc.$loading = true;
      newDoc.$doc['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    } else {
      newDoc['\$loading'] = true;
      newDoc['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    dynamic doc;
    try {
      if ((newDoc is EngageDoc && newDoc.$id != null) || (newDoc != null && newDoc['\$id'] != null)) {
        doc = await update(newDoc, docRef: listRef);
      } else if (listRef != null && listRef.id != null) {
        doc = await setDoc(newDoc, docRef: listRef);
      } else {
        doc = await add(newDoc, docRef: listRef);
        list = [...list, doc];
      }
    } catch (error) {
      print(error);

    }
    if (doc is EngageDoc) {
      doc.$loading = false;
    } else if (doc != null) {
      doc['\$loading'] = false;
    }
    return doc;
  }

  remove(String id, [CollectionReference listRef]) {
    listRef ??= ref;
    if (debug) print('removing: $id');
    return listRef.document(id).delete();
  }

  watch(String id, cb, [CollectionReference listRef]) {
    listRef ??= ref;
    listRef
      .document(id)
      .snapshots()
      .listen((doc) => doc.exists ? cb(addFire(doc.data, doc.documentID), doc) : cb(null, doc));
  }

  watchList(cb, [CollectionReference listRef]) {
    listRef ??= ref;
    listRef
      .snapshots()
      .listen((snapshot) => cb is List ? cb = addFireList(snapshot) : cb(addFireList(snapshot)));
  }


  Stream listen(cb, [CollectionReference listRef]) {
    listRef ??= ref;
    var transformer = StreamTransformer.fromHandlers(handleData: (value, sink) {
      value = addFireList(value);
    });
    return listRef.snapshots().transform(transformer);
  }


  /*
   * UTILITIES
   */

  Future replaceId(String oldId, newId, [ref]) async {
    ref ??= this.ref;
    Map data;
    data = await this.get(oldId, listRef: ref);
    if (data == null) {
      print('cant find record for: $oldId');
      return 'cant find record';
    }
    data = this.addFire(data, newId);
    await this.save(data);
    return await this.remove(oldId, ref);
  }

  Future replaceIdOnCollection(String oldId, newId, [subRef]) async {
    subRef ??= this.ref;
    Map data;
    data = await this.get(oldId, listRef: subRef);
    if (data == null) {
      print('cant find record for: $oldId');
      return 'cant find record';
    }
    data = this.addFire(data, newId);
    await this.save(data, listRef: subRef);
    return await this.remove(oldId, subRef);
  }
  
  Future moveRecord(oldPath, newPath) async {
    if (this._db == null) return null;
    DocumentSnapshot data;
    data = await this._db.document(oldPath).get();
    Map record = data.data;
    print('record move $record');
    await this._db.document(newPath).setData(record);
    return this._db.document(oldPath).delete();
  }

  Future copyRecord(oldPath, newPath, [updateTimestamp = false]) async {
    if (this._db == null) return null;
    DocumentSnapshot data;
    data = await this._db.document(oldPath).get();
    Map record = data.data;
    if (updateTimestamp) record['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    print('record move $record');
    return this._db.document(newPath).setData(record);
  }

  Future backupDoc(doc, [deep = true, backupPath = '_backups']) async {
    print('deep: $deep');
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    if (doc == null) return 'Missing Doc';
    var ef = EngageFirestore.getInstance("$backupPath/$timestamp/$doc['\$path']");
    doc.$backupAt = timestamp;
    await doc.$save();
    return await ef.save({
      ...doc,
      '\$updatedAt': timestamp
    });
    // if (deep) {
    //   return await doc.$subCollections.map(collection = this.backupCollection()
    // }
  }

}