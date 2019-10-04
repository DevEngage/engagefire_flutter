

import 'dart:io';
import 'package:engagefire/core/firestore.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth.dart';
import 'engagefire.dart';

class EngageDoc {
  static Map<String, EngageDoc> instances = {};
  final EngagePubsub _ps = engagePubsub;
  dynamic $ref;
  dynamic $docRef;
  dynamic $collectionRef;
  EngageFirestore $engageFireStore;
  String $path;
  String $owner;
  String $id;
  String $collection;
  StorageUploadTask $uploadTask;
  bool $loading = true;
  Map $collections = {};
  List<String> $collectionsList = [];
  List<String> $omitList = [];
  List relations = [];
  int position;
  Map namedListener = { };
  Map<String, dynamic> $doc = {
    '\$owner': '',
    '\$id': '',
    '\$collection': '',
  };

  EngageDoc({String path, Map data, List<String> subCollections, ignoreInit = false}) {
    if (!ignoreInit && path != null) this.$$setupDoc(path, data, subCollections);
  }
  
  static Future<EngageDoc> get({String path, Map data, List<String> subCollections, Map defaultData, bool saveDefaults = false}) async {
    EngageDoc doc = EngageDoc(ignoreInit: true);
    await doc.$$setupDoc(path, data, subCollections);
    String userId = await EngageAuth().currentUserId;
    if (defaultData != null) {
      if (doc.$setDefaults(defaultData, userId)) {
        doc.$publish(doc.$doc);
      }
    }
    if (saveDefaults) {
      await doc.$save();
    }
    return doc;
  }
  
  static Future<EngageDoc> getOrCreate({String path, List<String> subCollections, Map defaultData, Map filter}) async {
    EngageFirestore collection = await EngageFirestore.getInstance(path);
    collection.subCollections = subCollections ?? [];
    EngageDoc doc = await collection.getOrCreate(defaultData: defaultData, filter: filter);
    return doc;
  }

  Future<void> $$init() async {
    this.$id = this.$doc['\$id'] ?? this.$doc['id'] ?? this.$id;
    this.$ref = this.$engageFireStore.ref;
    String tmpPath;
    tmpPath = this.$engageFireStore.path;
    this.$path = "$tmpPath/$this['\$id']";
    this.$collection = this.$ref.path;
    this.$doc['\$collection'] = this.$collection;
    this.$doc['\$id'] = this.$id; 
    this.$docRef = this.$ref.document(this.$id);

    (this.$collectionsList ?? []).forEach($buildCollections);
    this.$loading = false;
  }

  $$setupDoc([String path = '', data, subCollections]) async {
    path ??= $path;
    List pathList = (path ?? '').split('/');
    bool isDocPath = pathList.length > 0 && pathList.length % 2 == 0;
    String docId;
    if (isDocPath) {
      docId = pathList.removeLast();
      path = pathList.join('/');
      this.$path = path;
      this.$engageFireStore = EngageFirestore.getInstance(path);
      data = await this.$engageFireStore.get(docId, pure: true);
    } else if (path != null) {
      this.$path = path;
      this.$engageFireStore = EngageFirestore.getInstance(path);
    }
    if (data != null) {
      this.$doc = {...$doc, ...data};
    } else if (docId != null) {
      this.$doc = {...$doc, '\$updatedAt': DateTime.now().millisecondsSinceEpoch, '\$id': this.$engageFireStore.getStringVar(docId)};
    }
    if (subCollections != null) {
      this.$collectionsList = subCollections;
    }
    await this.$$init();
  }

  $buildCollections(element) {
    var sub = element.split('.')[0];
    var preFetch = element.split('.')[1];
    this.$collections['$sub\_'] = EngageFirestore.getInstance("$this['\$path']/$sub");
    this.$omitList.add('$sub\_');
    if (preFetch == 'list') this.$collections['$sub\_'].getList();
  }

  Future $save([data]) {
    if (data != null) this.$$updateDoc(data);
    try {
      dynamic saved = this.$engageFireStore.save(this);
      $publish($doc);
      return saved;
    } catch (error) {
      print('EngageDoc.save: $error');
    }
  }

  Future $update([data]) {
    this.$$updateDoc(data);
    if (data != null) this.$$updateDoc(data);
    return this.$engageFireStore.update(this);
  }

  Future $set([data]) {
    if (data != null) this.$$updateDoc(data);
    return this.$engageFireStore.update(this);
  }

  Future $get() async {
    this.$doc = await this.$engageFireStore.get(this.$id);
    return this.$doc;
  }

  Future $attachOwner() async {
    this.$owner = await EngageAuth().currentUserId;
    this.$doc['\$owner'] = this.$owner;
    return this.$save();
  }

  Future $isOwner([userId]) async {
    userId ??= this.$doc['\$owner'];
    if (userId == null) {
      await this.$attachOwner();
    }
    return this.$doc['\$owner'] == (await EngageAuth().currentUserId);
  }

  Future<dynamic> $(String key, {dynamic value, dynamic defaultValue, int increment, int decrement, Function done, save = true}) async {
    if (increment != null && increment > 0) {
      value ??= this.$doc[key] ?? 0;
      value += increment;
    }
    if (decrement != null && decrement > 0) {
      value ??= this.$doc[key] ?? 0;
      value -= decrement;
    }
    if (defaultValue != null) {
      value = defaultValue;
    }
    if (value == null) {
      if (done != null) done(this.$doc[key], key);
      return this.$doc[key];
    }
    this.$doc[key] = value;
    if(save) await this.$save();
    if (done != null) done(value, key);
    return this.$doc[key];
  }

  $addFiles({File file, String path, String id}) async {
    dynamic storage = EngageFire.storage;
    await storage.uploadFile(file, this.$path);
    this.$uploadTask = await storage.uploadFile(file, path ?? this.$path);
    Map image = await storage.getFileMeta(this.$uploadTask);
    await EngageFirestore.getInstance("${this.$path}/\$files").save({'\$id': id, ...image});
    return image;
  }

  $setImage({String type, dynamic thumbnail, String width, String height, File file}) async {
    dynamic storage = EngageFire.storage;
    Map image;
    Map thumb;
    if (type == 'take') {
      file = storage.takePic();
    } else {
      file ??= storage.pickImage();
    }
    image = $addFiles(file: file, id: '\$image', path: "${this.$path}/\$image");
    $doc['\$image'] = image['url'];
    if (thumbnail != null) {
      String width = thumbnail.width;
      String height = thumbnail.height;
      thumb = $addFiles(file: file, id: '\$thumb', path: "${this.$path}/\$thumb");
      $doc['\$thumb'] = thumb['url'];
    }
    await this.$save();
    return {
      'image': image,
      'thumb': thumb,
    }; 
  }

  $removeImage() async {
    await EngageFirestore.getInstance("${this.$path}/\$files").remove('\$image');
    await EngageFirestore.getInstance("${this.$path}/\$files").remove('\$thumb');
    $doc['\$image'] = '';
    $doc['\$thumb'] = '';
    await this.$save();
    return this.$doc;
  }

  $removeFile(String fileId) async {
    return await EngageFirestore.getInstance("${this.$path}/\$files").remove(fileId);
  }

  $getFiles() async {
    return (await EngageFirestore.getInstance('${this.$path}/\$files')).getList();
  }

  $getFile(String fileId) async {
    return (await EngageFirestore.getInstance('${this.$path}/\$files')).get(fileId);
  }

  $downloadFile(String fileId) async {
    Map fileDoc = (await this.$getSubCollection('\$files')).get(fileId);
    return await EngageFire.storage.downloadFile(fileDoc['url']);
  }

  
  Future $remove([showConfirm = false]) async {
    // if (showConfirm) {
    //   const r = confirm('Are you sure?');
    //   if (!r) return;
    // }
    dynamic result = this.$engageFireStore.remove(this.$id);
    this.$engageFireStore.list = this.$engageFireStore.list.where((item) => item.$id != this.$id);
    return result;
  }

   $$updateDoc([Map data]) {
     if (data != null) {
        this.$doc = this.$engageFireStore.omitFire(data);
     }
    return this.$doc;
  }

  Future $getSubCollection(String collection, [db]) async {
    return EngageFirestore.getInstance("$this['\$path']/$collection");
  }

  // Future $watch(cb) async {
  //   return this.$engageFireStore.watch(this.$id, cb);
  // }

  
  // $listen() {
  //   ref
  //     .document($id)
  //     .snapshots()
  //     .listen((doc) => doc.exists ? cb(this.addFire(doc.data, doc.documentID), doc) : cb(null, doc));
  // }

  Future $backup(bool deep, String backupPath) async {
    return this.$engageFireStore.backupDoc(this.$doc, deep, backupPath);
  }

  $exists() {
    return this.$doc != null;
  }

  $getModel() {
    return this.$engageFireStore.getModel();
  }

  Future $changeId(String newId) async {
    await this.$engageFireStore.replaceIdOnCollection(this.$id, newId);
    this.$id = newId;
    this.$$updateDoc();
  }

  Future $swapPosition(x, y, [List list]) async {
    list = list ?? this.$$getSortedParentList();
    if (list.every((item) => item.$doc['position'] != null)) {
      await this.$engageFireStore.buildListPositions();
    }
    var itemX = list[x];
    var itemY = list[y];
    var itemXPos = itemX.$doc['position'] || x + 1;
    var itemYPos = itemY.$doc['position'] || y + 1;
    itemX.$doc['position'] = itemYPos;
    itemY.$doc['position'] = itemXPos;
    this.$engageFireStore.list[y] = itemX;
    this.$engageFireStore.list[x] = itemY;
    await itemX.$save();
    await itemY.$save();
  }

  Future $moveUp() async {
    var list = $$getSortedParentList();
    int index = list.findIndex((item) => item.$doc['position'] == this.$doc['position']);
    if (index <= 0) {
      return;
    }
    await this.$swapPosition(index, index-1, list);
  }

  Future $moveDown() async {
    var list = $$getSortedParentList();
    int index = list.findIndex((item) => item['position'] == this.$doc['position']);
    if (index >= list.length - 1) {
      return;
    }
    await this.$swapPosition(index, index + 1, list);
  }

  Future $setPosition(index) {
    $doc['position'] = index;
    position = index;
    return $save($doc);
  }

  bool $setDefaults(Map data, [stringVarDefault, doc]) {
    doc ??= $doc;
    var changed = false;
    data.forEach((key, value) {
      if ($doc[key] == null && value != null) {
        $doc[key] = this.$engageFireStore.getStringVar(value, stringVarDefault);
        changed = true;
      }
    });
    return changed;
  }

  $subscribe(Function listener, {String name, bool listen}) {
    if (name != null) {
      namedListener[name] = listener;
    }
    _ps.subscribe($path, listener);
  }

  $publish([data]) {
    data ??= $doc;
    _ps.publish(data, $path);
  }

  $unsubscribe({String name, Function listener}) {
    if (name != null && namedListener[name] != null) {
      _ps.unsubscribe($path, namedListener[name]);
      namedListener.remove(name);
    } else if (listener != null) {
      _ps.unsubscribe($path, listener);
    }
    
  }

  $$getSortedParentList() {
    return this.$engageFireStore.sortListByPosition().list;
  }

  $$difference(Map object, base) {
    return object == base;
  }

  static $$mapDefaultsFromFilter(Map defaults, Map filter) {
    if (filter != null) {
      defaults ??= {};
      filter.forEach((key, value) {
        if (defaults[key] == null) {
          var keys = key.split('.');
          if (keys[0] != null && keys[2] == 'default') {
            defaults[keys[0]] = value;
          }
        }
      });
    }
    return defaults;
  }
}