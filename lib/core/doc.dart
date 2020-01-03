import 'dart:io';
import 'package:engagefire/core/firestore.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth.dart';
import 'engagefire.dart';

/*
 * TODO:
 * [ ] Increment multiple values by given Map of values
 * [X] Toggle subcollection
 * [X] add and remove subCollection
 * [ ] get subCollectionList
 * [X] remove sub Collections from this and make it so we set it up in the beginning or model
 * */
class EngageDoc {
  static Map<String, EngageDoc> instances = {};
  // static Map<String, EngageDoc> subCollections = {};
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
  String _path;
  bool $isNew = false;

  EngageDoc({path, Map data, ignoreInit = false}) {
    this._path = path;
    if (!ignoreInit && path != null) $$setupDoc(path, data);
  }

  static Future<EngageDoc> get({String path, Map data, Map defaultData, bool saveDefaults = false}) async {
    EngageDoc doc = EngageDoc(ignoreInit: true);
    await doc.$$setupDoc(path, data);
    String userId = await EngageAuth().currentUserId;
    if (defaultData != null) {
      if (doc.$setDefaults(defaultData, userId: userId)) {
        doc.$publish(doc.$doc);
      }
    }
    if (saveDefaults) {
      await doc.$save();
    }
    return doc;
  }
  
  static Future<EngageDoc> getOrCreate({String path, Map defaultData, Map filter, String id}) async {
    String userId = await EngageAuth().currentUserId;
    path = EngageFirestore.replaceTemplateString(path ?? '', userId: userId);
    EngageFirestore collection = await EngageFirestore.getInstance(path);
    EngageDoc doc = await collection.getOrCreate(defaultData: defaultData, filter: filter, id: id);
    return doc;
  }

  $setId([id]) {
    $id = id ?? $doc['\$id'] ?? $doc['id'] ?? $id;
    $doc['\$id'] = $id;
    if ($engageFireStore != null && $id != null) {
      $path = "${$engageFireStore.path}/${$id}";
    }
  }

  $setCollection([path]) {
    path ??= $path;
    final isDocPath = $$isPathCorrect(path);
    if (isDocPath) {
      path = $$getCollection(path);
      $engageFireStore = EngageFirestore.getInstance(path);
    } else if (path != null) {
      $engageFireStore = EngageFirestore.getInstance(path);
    }
    if ($engageFireStore != null) {
      $ref = $engageFireStore.ref;
      $collection = $ref.path;
      $docRef = $ref.document($id);  
      $doc['\$collection'] = $collection;
      if ($id != null) {
        $path = "${$engageFireStore.path}/${$id}";
      }
    }
  }

  bool $$validateInit(path) {
    path ??=  _path;
    if (path != null && !$$isPathCorrect(path)) {
      throw 'Path is Collection and not Doc';
    } else if (path == null) {
      throw 'Path is Empty';
    }
    return true;
  }

  bool $$isPathCorrect([path]) {
    List pathList = (path ?? _path ?? '').split('/');
    print(pathList);
    return pathList.isNotEmpty && pathList.length % 2 == 0;
  }

  String $$getCollection([path]) {
    List pathList = (path ?? _path ?? '').split('/');
    pathList.removeLast();
    final collectionPath = pathList.join('/');
    return collectionPath;
  }

  String $$parseId([path]) {
    List pathList = (path ?? _path ?? '').split('/');
    final docId = pathList.removeLast();
    return docId;
  }

  $$setupDoc([String path = '', data]) async {
    path ??= $path;
    $$validateInit(path);
    $loading = true;
    var userId = EngageAuth.user.uid ?? await EngageAuth().currentUserId;
    final isDocPath = $$isPathCorrect(path);
    path = EngageFirestore.replaceTemplateString(path ?? '', userId: userId);
    var docId = $$parseId(path);
    $setId(docId);
    $setCollection(path);
    if (isDocPath && data == null) {
      data = await $engageFireStore.get($id, pure: true);
    }
    if (data != null) {
      $doc = {...$doc, ...data, '\$collection': $collection, '\$id': $id};
    } else if ($id != null) {
      $doc = {...$doc, '\$updatedAt': DateTime.now().millisecondsSinceEpoch, '\$id': $id};
    }
    $loading = false;
  }

  // $buildCollections(element, id) {
  //   var commands = element.split('.');
  //   var sub = commands[0];
  //   var preFetch;
  //   if (commands.length > 1) {
  //     preFetch = commands[1];
  //   }
  //   print($$parseId());
  //   // print("${$path}$sub");
  //   $collections['$sub\_'] = EngageFirestore.getInstance("${$path}$sub");
  //   $omitList.add('$sub\_');
  //   if (preFetch == 'list') $collections['$sub\_'].getList();
  // }

  Future $save([data]) async {
    if (data != null) $$updateDoc(data);
    try {
      return $engageFireStore.save($doc);
    } catch (error) {
      print('EngageDoc.save: $error');
    }
  }
  
  Future $saveAndPublish(data) async {
    await $save(data);
    $publish($doc);
  }

  Future $update([data]) {
    $$updateDoc(data);
    if (data != null) $$updateDoc(data);
    return $engageFireStore.update($doc);
  }

  Future $set([data]) {
    if (data != null) $$updateDoc(data);
    return $engageFireStore.update($doc);
  }

  Future $get({updateDoc = true}) async {
    final _doc = await $engageFireStore.get($id, pure: true);
    if (updateDoc) {
      $doc = {...$doc, ..._doc};
    }
    return _doc;
  }

  Future $attachOwner() async {
    $owner = await EngageAuth().currentUserId;
    $doc['\$owner'] = $owner;
    return $save();
  }

  Future $isOwner([userId]) async {
    userId ??= $doc['\$owner'];
    if (userId == null) {
      await $attachOwner();
    }
    return $doc['\$owner'] == (await EngageAuth().currentUserId);
  }

  Future<dynamic> $(String key, {dynamic value, dynamic defaultValue, double increment, double decrement, Function done, save = true, recordEvent = false}) async {
    await $get();
    if (increment != null && increment > 0) {
      value ??= $doc[key] ?? increment is double ? 0.0 : 0;
      value += increment;
    }
    if (decrement != null && decrement > 0) {
      value ??= $doc[key] ?? increment is double ? 0.0 : 0;
      value -= decrement;
    }
    if (defaultValue != null) {
      value = defaultValue;
    }
    if (value == null) {
      if (done != null) done($doc[key], key);
      return $doc[key];
    }
    $doc[key] = value;
    if(save) await $save();
    if (done != null) done(value, key);
    if (recordEvent) await $$recordEvent({key: $doc[key]});
    return $doc[key];
  }

  Future<dynamic> $map(Map doc, {bool increment, bool decrement, Function done, save = true, recordEvent = false}) async {
    doc.forEach((key, value) {
      if (increment) {
        $(key, increment: value, save: false, recordEvent: false);
      } else if (decrement) {
        $(key, decrement: value, save: false, recordEvent: false );
      } else {
        $(key, value: value, save: false, recordEvent: false );
      }
    });
    if(save) await $save();
    if (done != null) done(doc);
    if (recordEvent) await $$recordEvent(doc);
    return $doc;
  }

  $addFiles({File file, String path, String id}) async {
    dynamic storage = EngageFire.storage;
    await storage.uploadFile(file, $path);
    $uploadTask = await storage.uploadFile(file, path ?? $path);
    Map image = await storage.getFileMeta($uploadTask);
    await EngageFirestore.getInstance("${$path}/\$files").save({'\$id': id, ...image});
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
    image = $addFiles(file: file, id: '\$image', path: "${$path}/\$image");
    $doc['\$image'] = image['url'];
    if (thumbnail != null) {
      String width = thumbnail.width;
      String height = thumbnail.height;
      thumb = $addFiles(file: file, id: '\$thumb', path: "${$path}/\$thumb");
      $doc['\$thumb'] = thumb['url'];
    }
    await $save();
    return {
      'image': image,
      'thumb': thumb,
    }; 
  }

  $removeImage() async {
    await EngageFirestore.getInstance("${$path}/\$files").remove('\$image');
    await EngageFirestore.getInstance("${$path}/\$files").remove('\$thumb');
    $doc['\$image'] = '';
    $doc['\$thumb'] = '';
    await $save();
    return $doc;
  }

  $removeFile(String fileId) async {
    return await EngageFirestore.getInstance("${$path}/\$files").remove(fileId);
  }

  $getFiles() async {
    return (await EngageFirestore.getInstance('${$path}/\$files')).getList();
  }

  $getFile(String fileId) async {
    return (await EngageFirestore.getInstance('${$path}/\$files')).get(fileId);
  }

  $downloadFile(String fileId) async {
    Map fileDoc = await ($getSubCollection('\$files')).get(fileId);
    return await EngageFire.storage.downloadFile(fileDoc['url']);
  }

  
  Future $remove([showConfirm = false]) async {
    // if (showConfirm) {
    //   const r = confirm('Are you sure?');
    //   if (!r) return;
    // }
    dynamic result = $engageFireStore.remove($id);
    $engageFireStore.list = $engageFireStore.list.where((item) => item.$id != $id).toList();
    return result;
  }

   $$updateDoc([Map data]) {
     if (data != null) {
        $doc = $engageFireStore.omitFire(data);
     }
    return $doc;
  }

  EngageFirestore $getSubCollection(String _collection, [options]) {
    return EngageFirestore.getInstance("${$path}/$_collection", options: options);
  }

  // Future $watch(cb) async {
  //   return $engageFireStore.watch($id, cb);
  // }

  
  // $listen() {
  //   ref
  //     .document($id)
  //     .snapshots()
  //     .listen((doc) => doc.exists ? cb(addFire(doc.data, doc.documentID), doc) : cb(null, doc));
  // }

  Future $backup(bool deep, String backupPath) async {
    return $engageFireStore.backupDoc($doc, deep, backupPath);
  }

  $exists() {
    return $doc != null;
  }

  $getModel() {
    return $engageFireStore.getModel();
  }

  Future $changeId(String newId) async {
    await $engageFireStore.replaceIdOnCollection($id, newId);
    $id = newId;
    $$updateDoc();
  }

  Future $swapPosition(x, y, [List list]) async {
    list = list ?? $$getSortedParentList();
    if (list.every((item) => item.$doc['position'] != null)) {
      await $engageFireStore.buildListPositions();
    }
    var itemX = list[x];
    var itemY = list[y];
    var itemXPos = itemX.$doc['position'] || x + 1;
    var itemYPos = itemY.$doc['position'] || y + 1;
    itemX.$doc['position'] = itemYPos;
    itemY.$doc['position'] = itemXPos;
    $engageFireStore.list[y] = itemX;
    $engageFireStore.list[x] = itemY;
    await itemX.$save();
    await itemY.$save();
  }

  Future $moveUp() async {
    var list = $$getSortedParentList();
    int index = list.findIndex((item) => item.$doc['position'] == $doc['position']);
    if (index <= 0) {
      return;
    }
    await $swapPosition(index, index-1, list);
  }

  Future $moveDown() async {
    var list = $$getSortedParentList();
    int index = list.findIndex((item) => item['position'] == $doc['position']);
    if (index >= list.length - 1) {
      return;
    }
    await $swapPosition(index, index + 1, list);
  }

  Future $setPosition(index) {
    $doc['position'] = index;
    position = index;
    return $save($doc);
  }

  bool $setDefaults(Map data, {userId, dateDMY, doc}) {
    doc ??= $doc;
    if ($engageFireStore == null) {
      $setCollection();
    }
    var changed = false;
    data.forEach((key, value) {
      if ($doc[key] == null && value != null && $engageFireStore != null) {
        $doc[key] = $engageFireStore.getStringVar(value, userId: userId, dateDMY: dateDMY);
        changed = true;
      }
      if ($engageFireStore == null) {
        print('$_path missing collection (\$engageFireStore)');
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
    return $engageFireStore.sortListByPosition().list;
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

  Future $$recordEvent(dynamic doc) async {
    dynamic result;
    if (doc != null) {
      result = await EngageFirestore.getInstance("${$path}/events").save(doc);
    }
    return result;
  }

  Future<bool> $subExists(collection, id) async {
    EngageFirestore ref = $getSubCollection(collection);
    var doc = await ref.get(id, pure: true);
    return doc != null;
  }

  Future $toggleSub(String collection, dynamic data) async {
    EngageFirestore ref = $getSubCollection(collection);
    EngageDoc doc = await ref.getOrCreate(
      id: data['\$id'] ?? data['id'], 
      defaultData: data
    );
    if (doc.$isNew) {
      return true;
    } else {
      await doc.$remove();
      return true;
    }
  }

  Future $sub(String collection, data) async {
    EngageFirestore ref = $getSubCollection(collection);
    if (data is String) {
      return ref.get(data);
    } else if (data != null) {
      return ref.save(data);
    }
    return null;
  }

  Future $subRemove(String collection, data) async {
    EngageFirestore ref = $getSubCollection(collection);
    if (data is String) {
      return ref.remove(data);
    } else if (data != null && data['\$id'] != null) {
      return await ref.remove(data['\$id']);
    }
    return null;
  }

  EngageFirestore $getSub(String collection, [options]) {
    return $getSubCollection(collection, options);
  }

  // static getInstance(
  //   String path,
  //   {options, }
  // ) {
  //   if (EngageDoc.instances[path] == null)  {
  //     EngageDoc.instances[path] = EngageDoc(path: path);
  //   }
  //   // if (options != null) {
  //   //   return EngageDoc.instances[path].options(options);
  //   // }
  //   return EngageDoc.instances[path];
  // }
}