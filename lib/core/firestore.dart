import 'dart:async';
import 'package:engagefire/core/auth.dart';
import 'package:engagefire/core/doc.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engagefire/core/state.dart';
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
 * [ ] Increment multiple values by given Map of values
 * */
class EngageFirestore {
  static var STATE;
  static Map<String, EngageFirestore> instances = {};
  final Firestore _db = Firestore.instance;
  final EngagePubsub _ps = engagePubsub;
  CollectionReference ref;

  // State System for lists
  Map<String, EngageState> streams = {};

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

  init() {
    _updateUser(EngageAuth.user);
    path = this.getStringVar(path);

    EngageFirestore.STATE ??= {};
    if (EngageFirestore.STATE[path] == null) {
      EngageFirestore.STATE[path] = {};
      state = EngageFirestore.STATE[path];
    }
    if (path is String) {
      ref = _db.collection(path);
    }
    // await getModelFromDb();
    $loading = false;
    _ps.subscribe('_user', _updateUser);
  }

  _updateUser(user) {
    $user = user;
    if ($user != null) {
      userId = $user.uid;
      path = this.getStringVar(path);
      if (debug) print('userId: $userId');
    }
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

  static getInstanceItem(
    String path, String id
  ) {
    return EngageFirestore.instances[path].list.firstWhere((item) => item.$id == id || item.id == id);
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

  options([var _options ]) {
    _options = _options ?? { 'loadList': true };
    if (_options['loadList']) {
      this.getList();
    }
    return this;
  }

  /* 
  field.isEqualTo: 1
  */
  buildQuery(Map filter, [CollectionReference customRef]) {
    dynamic queryRef = customRef ?? ref;
    filter.forEach((key, value) {
      List<String> keys = key.split('.');
      String field = keys[0];
      String type = keys[1];
      switch (type) {
        case 'isEqualTo':
          queryRef = queryRef.where(field, isEqualTo: value);
          break;
        case 'isLessThan':
          queryRef = queryRef.where(field, isLessThan: value);
          break;
        case 'isLessThanOrEqualTo':
          queryRef = queryRef.where(field, isLessThanOrEqualTo: value);
          break;
        case 'isGreaterThan':
          queryRef = queryRef.where(field, isGreaterThan: value);
          break;
        case 'isGreaterThanOrEqualTo':
          queryRef = queryRef.where(field, isGreaterThanOrEqualTo: value);
          break;
        case 'arrayContains':
          queryRef = queryRef.where(field, arrayContains: value);
          break;
        case 'arrayContainsAny':
          queryRef = queryRef.where(field, arrayContains: value);
          break;
        case 'whereIn':
          queryRef = queryRef.where(field, arrayContains: value);
          break;
        case 'isNull':
          queryRef = queryRef.where(field, isNull: value);
          break;
        case 'orderBy':
          queryRef = queryRef.orderBy(field, descending: value ?? false);
          break;
      }
    });
    return queryRef;
  }

  getFilterDefaults(Map defaults, Map filter, {userId, dateDMY}) {
    if (filter != null) {
      defaults ??= {};
      filter.forEach((key, value) {
        if (defaults[key] == null) {
          var keys = key.split('.');
          if (keys[0] != null && keys.length > 2 && keys[2] == 'default') {
            defaults[keys[0]] = getStringVar(value, userId: userId, dateDMY: dateDMY);
          }
        }
      });
    }
    return defaults;
  }

  Future<dynamic> buildTemplateQuery({dynamic query, Map filter}) async {
    if (filter != null) {
      var userId = await EngageAuth().currentUserId;
      filter.forEach((key, value) => filter[key] = getStringVar(value, userId: userId));
    }
    if (filter != null) {
      query = buildQuery(filter, query);
    }
    return query;
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

  buildQueryStateString(Map filter) {
    List<String> list;
    filter.forEach((key, value) {
      List<String> keys = key.split('.');
      var field = keys[0] ?? '';
      var type = keys[1] ?? '';
      list.add('$field.$type.$value');
    });
    list.sort();
    return list.toString();
  }

  setStream([value, name = 'all']) {
    getStream(name).repalce(value);
    return getStream(name);
  }

  getStream([name = 'all']) {
    streams[name] = EngageState.getState(path: '$path.$name', stateValue: []);
    return streams[name];
  }

  Future<EngageDoc> getFirst({CollectionReference listRef, Map filter}) async {
    var item = await getList(listRef: listRef, filter: filter, limit: 1);
    return item.isEmpty ? null : item[0];
  }

  Future<List> getList({CollectionReference listRef, Map filter, limit, updateStream = false, List resolve, wrapper}) async {
    $loading = true;
    dynamic query = await buildTemplateQuery(query: listRef ?? ref, filter: filter);
    if (limit != null) query.limit(limit);
    QuerySnapshot collection;
    collection = await query.getDocuments();
    list = await addFireList(collection, resolve: resolve);
    if (updateStream && filter != null) {
      setStream(List<dynamic>.from(list), buildQueryStateString(filter));
    } else if (updateStream) {
      setStream(List<dynamic>.from(list));
    }
    $loading = false;
    return list;
  }

  Future<List> addFireList(QuerySnapshot collection, {List resolve}) async {
    List<Future> list = [];
    if (collection != null && collection.documents != null) {
      collection.documents.forEach((DocumentSnapshot doc) => doc.exists ? list.add(addFire(doc.data, doc.documentID, resolve: resolve)) : null);
    }
    return list is List<Future> ? Future.wait(list) : null;
  }

  Future addFire(data, String id, {ignoreInit = false, List resolve}) async {
    if (data == null && id != null && data is EngageDoc) {
      data.$setId(id);
    }
    if (EngageDoc != null && data is Map) {
      var doc = EngageDoc(data: data, path: '$path/$id', ignoreInit: ignoreInit);
      if (resolve != null)  {
        await Future.wait(resolve.map((item) => doc.$getRelations(field: item)).toList());
      }
      return doc;
    }
    return data;
  }

  omitFireList(List list) {
    return list.map(omitFire);
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
    if (value != null && value['\$id'] != null) {
      return { 
        '\$id': value['\$id'], 
        '\$collection': value['\$collection'],
        '\$thumb': value['\$thumb'],
        '\$image': value['\$image'],
        'name': value['\$name'] ?? '', 
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

  getStringVar(dynamic what, {userId, dateDMY}) {
    return EngageFirestore.replaceTemplateString(what, userId: userId ?? this.userId, dateDMY: dateDMY);
  }

  static replaceTemplateString(dynamic what, {userId, dateDMY}) {
    if (what is String && what != null) {
      if (userId != null && (what.contains('{userId}') || what.contains('{\$userId}'))) {
        what = what.replaceAll(new RegExp(r'{userId}'), userId);
      }
      if (what.contains('{date.d-m-y}')) {
        final date = DateTime.now();
        String dmy = "${date.day}-${date.month}-${date.year}";
        what = what.replaceAll(new RegExp(r'{date.d-m-y}'), dateDMY ?? dmy);
      }
    }
    return what;
  }

  Future<dynamic> get(String docId, {CollectionReference listRef, createIfNull = false, blank = true, pure = false}) async {
    $loading = true;
    listRef ??= ref;
    docId = getStringVar(docId);
    if (pure) {
      dynamic doc = await listRef.document(docId).get();
      return doc.exists ? doc.data : null;
    }
    try {
      DocumentSnapshot doc;
      doc = await listRef.document(docId).get();
      $loading = false;
      if (doc.exists) {
        dynamic fireDoc = await this.addFire(doc.data, docId);
        num index = this.list.indexOf(fireDoc);
        if (index > -1) this.list[index] = fireDoc;
        else this.list.add(fireDoc);
        return fireDoc;
      }
      if (!createIfNull) {
        return null;
      }
      return setDoc({
        '\$updatedAt': DateTime.now().millisecondsSinceEpoch, 
        '\$id': docId
        }, 
        docRef: listRef.document(docId)
      );
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<EngageDoc> getOrCreate({dynamic defaultData, Map filter, String id}) async {
    String userId = await EngageAuth().currentUserId;
    defaultData = getFilterDefaults(defaultData, filter, userId: userId);
    if (defaultData != null && defaultData['\$id'] != null && id == null) {
      id = defaultData['\$id'];
    }
    EngageDoc doc;
    EngageDoc found;
    if (id != null) {
      found = await get(id, createIfNull: false);
    } else {
      found = await getFirst(filter: filter);
    }
    if (found == null) {
      Map<dynamic, dynamic> newMap = {...defaultData};
      doc = await add(newMap);
      doc.$isNew = true;
    } else {
      doc = found;
      if (doc.$setDefaults(defaultData, userId: userId)) {
        await doc.$save();
      }
    }
    return doc;
  }

  Future<dynamic> add(dynamic newDoc, {dynamic docRef, ignoreInit = false}) async {
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
    await blank.setData(newDoc.cast<String, dynamic>());
    return await this.addFire(newDoc, blank.documentID, ignoreInit: ignoreInit);
  }

  Future<dynamic> setDoc(dynamic newDoc, {dynamic docRef}) async {
    if (debug) {
      print('set $newDoc');
    }
    if (newDoc is EngageDoc) {
      newDoc.$doc = omitFire(newDoc.$doc);
      newDoc.$doc['\$createdAt'] = DateTime.now().millisecondsSinceEpoch;
      newDoc.$doc['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      newDoc.$doc['\$timezoneOffset'] = DateTime.now().timeZoneOffset.toString();
      docRef ??= newDoc.$docRef;
      await docRef.setData(newDoc.$doc.cast<String, dynamic>());
    } else {
      newDoc = omitFire(newDoc);
      newDoc['\$createdAt'] = DateTime.now().millisecondsSinceEpoch;
      newDoc['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      newDoc['\$timezoneOffset'] = DateTime.now().timeZoneOffset.toString();
      await docRef.setData(newDoc.cast<String, dynamic>());
    }
    return await addFire(newDoc, newDoc['\$id'] ?? newDoc['id'] ?? docRef.documentID);
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
        documentRef = await doc.$docRef.setData(doc.$doc.cast<String, dynamic>(), merge: true);
      } else {
        documentRef = docRef.document(doc['\$id']);
        await documentRef.setData(doc.cast<String, dynamic>(), merge: true);
      }
      return await addFire(doc, documentRef.documentID);
    } catch (error) {
      print('update error: $error');
      return doc;
    }
  }

  Future<dynamic> save(dynamic newDoc, {CollectionReference listRef}) async {
    newDoc = omitFire(newDoc);
    if (newDoc is EngageDoc) {
      newDoc.$loading = true;
      newDoc.$doc['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    } 
    // else {
    //   newDoc['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    // }
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
    }
    return doc;
  }

  remove(String id, [CollectionReference listRef]) {
    listRef ??= ref;
    if (debug) print('removing: $id');
    return listRef.document(id).delete();
  }

  // watch(String id, cb, [CollectionReference listRef]) {
  //   listRef ??= ref;
  //   listRef
  //     .document(id)
  //     .snapshots()
  //     .listen((doc) => doc.exists ? cb(addFire(doc.data, doc.documentID), doc) : cb(null, doc));
  // }

  // watchList(cb, [CollectionReference listRef]) {
  //   listRef ??= ref;
  //   listRef
  //     .snapshots()
  //     .listen((snapshot) => cb is List ? cb = addFireList(snapshot) : cb(addFireList(snapshot)));
  // }

  Stream listen(cb, [CollectionReference listRef]) {
    listRef ??= ref;
    var transformer = StreamTransformer.fromHandlers(handleData: (value, sink) {
      value = addFireList(value);
    });
    return listRef.snapshots().transform(transformer);
  }

  Stream<dynamic> stream({filter, listRef, pure = false, limit, wrapper}) {
    dynamic query = listRef ?? ref;
    if (filter != null) {
      filter.forEach((key, value) => filter[key] = getStringVar(value, userId: EngageAuth.user.uid));
    }
    if (filter != null) {
      query = buildQuery(filter, query);
    }
    if (limit != null) query.limit(limit);
    if (pure) {
      return query.snapshots().map((list) =>
        list.documents.map((doc) => doc.data).toList());
    }
    return query.snapshots().map((list) =>
      list.documents.map((doc) => wrapper != null ? wrapper(doc) : EngageDoc.fromFirestore(doc)).toList());
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
    data = await this.addFire(data, newId);
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
    data = await this.addFire(data, newId);
    await this.save(data, listRef: subRef);
    return await this.remove(oldId, subRef);
  }
  
  Future moveRecord(oldPath, newPath) async {
    if (this._db == null) return null;
    DocumentSnapshot data;
    data = await this._db.document(oldPath).get();
    Map record = data.data;
    print('record move $record');
    await this._db.document(newPath).setData(record.cast<String, dynamic>());
    return this._db.document(oldPath).delete();
  }

  Future copyRecord(oldPath, newPath, [updateTimestamp = false]) async {
    if (this._db == null) return null;
    DocumentSnapshot data;
    data = await this._db.document(oldPath).get();
    Map record = data.data;
    if (updateTimestamp) record['\$updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    print('record move $record');
    return this._db.document(newPath).setData(record.cast<String, dynamic>());
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
