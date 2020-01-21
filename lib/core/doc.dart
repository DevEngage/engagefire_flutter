import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engagefire/core/firestore.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth.dart';
import 'engagefire.dart';

/*
 * TODO:
 * [X] Increment multiple values by given Map of values
 * [X] Toggle subcollection
 * [X] add and remove subCollection
 * [X] remove sub Collections from this and make it so we set it up in the beginning or model
 * */
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
  Map $relations = {};
  int position;
  Map namedListener = { };
  Map<String, dynamic> $doc = {
    '\$owner': '',
    '\$id': '',
    '\$collection': '',
  };
  String _path;
  bool $isNew = false;

  EngageDoc({path, Map data, id, ignoreInit = false}) {
    if (id != null) $id = id;
    this._path = path;
    if (!ignoreInit && path != null) $$setupDoc(path, data);
  }

  factory EngageDoc.fromMap(Map data, { Map resolve }) {
    data = data ?? { };
    return EngageDoc(data: data);
  }

  factory EngageDoc.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data;
    return EngageDoc(path: doc.reference.path, data: data, id: doc.documentID);
  }

  static Future<EngageDoc> get({String path, Map data, Map defaultData, retrieve = true, bool saveDefaults = false, List resolve}) async {
    EngageDoc doc = EngageDoc(ignoreInit: true);
    await doc.$$setupDoc(path, data);
    if (retrieve) {
      await doc.$get(resolve: resolve);
    }
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
      throw 'Path is a Collection and not a Doc';
    } else if (path == null) {
      throw 'Path is Empty';
    }
    return true;
  }

  bool $$isPathCorrect([path]) {
    List pathList = (path ?? _path ?? '').split('/');
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

  $$setupDoc([String path = '', data]) {
    path ??= $path;
    $$validateInit(path);
    // var userId = EngageAuth.user.uid; // ?? await EngageAuth().currentUserId;
    path = EngageFirestore.replaceTemplateString(path ?? '', userId: EngageAuth.user.uid ?? '');
    var userId = $$parseId(path);
    $setId(userId);
    $setCollection(path);
    if (data != null) {
      $doc = data.cast<String, dynamic>();
    }
  }

  Future $save([data]) async {
    $loading = true;
    if (data != null) $$updateDoc(data);
    try {
      $loading = false;
      return $engageFireStore.save($doc);
    } catch (error) {
      $loading = false;
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

  Future $get({updateDoc = true, List resolve}) async {
    $loading = true;
    final data = await $engageFireStore.get($id, pure: true);
    if (resolve != null) {
      await $resolveAllRelations(resolve);
    }
    if (updateDoc && data != null) {
      $doc = {...$doc, ...data, '\$collection': $collection, '\$id': $id};
    }
    $loading = false;
    return data;
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

  Future<dynamic> $(String key, {dynamic value, dynamic defaultValue, double increment, double decrement, Function done, save = true, recordEvent = false, refreshDoc = true}) async {
    if (refreshDoc) await $get();
    if (increment != null && increment > 0) {
      value ??= $doc[key] ?? 0;
      value += increment;
    }
    if (decrement != null && decrement > 0) {
      value ??= $doc[key] ?? 0;
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

  Future<dynamic> $map(Map doc, {bool increment, bool decrement, Function done, save = true, recordEvent = false, refreshDoc = true}) async {
    if (refreshDoc) await $get();
    doc.forEach((key, value) {
      if (increment) {
        if (value != null && value > 0) {
          $doc[key] ??= $doc[key] ?? 0;
          $doc[key] += value;
        }
      } else if (decrement) {
        if (value != null && value > 0) {
          $doc[key] ??= $doc[key] ?? 0;
          $doc[key] -= value;
        }
      } else {
        $doc[key] = value;
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

  Stream<EngageDoc> $stream() {
    return $docRef
        .snapshots()
        .map((snap) => EngageDoc.fromMap(snap.data));
  }

  Stream<EngageDoc> $streamData() {
    return $docRef
        .snapshots()
        .map((snap) => snap.data);
  }

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
      return false;
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


  /* 
    RELATIONS
  */
  
  // get all the $* fields plus name
  $addRelation(String relation, String relationId, {save = true}) {
      // if (relation && relation[relation.length - 1].toLowerCase() === 's') {
      //     relation = relation.slice(0, -1);
      // }
      var newDoc = {};
      newDoc['${relation}Id'] = relationId;

      this.$$updateDoc();
      if (save) this.$save();
  }

  Future $getRelations({pure = false, String field}) async {
    if ($doc[field] == null) {
      return;
    }
    var resolved;
    if ($doc[field] is String) {
      resolved = await EngageDoc.get(path: $doc[field]);
    } else if ($doc[field] is List) {
      resolved = await Future.wait(List.from(List.from($doc[field]).map((item) => EngageDoc.get(path: item)).toList()));
    } 
    // else if ($doc[field] is List) {
    //   // TODO: resolve object relations
    // }
    $relations[field] = resolved;
    $doc[field] = resolved;
    return $doc[field];
  }

  Future $resolveAllRelations(List resolve) async {
    return Future.wait(resolve.map((item) => $getRelations(field: item)).toList());
  }

  // $getRelations({pure = false, String field}) async {
  //     return 
  // }

  // // https://stackoverflow.com/questions/46568850/what-is-firestore-reference-data-type-good-for
  // $addReference(ref: any, name: string, save = true) {
  //     const newDoc = {};
  //     newDoc[`${name}Ref`] = ref;
  //     _.assign(this, newDoc);
  //     this.$$updateDoc();
  //     if (save) this.$save();
  // }

  // $getReferences(): string[] {
  //     return Object
  //         .keys(this.$doc)
  //         .map(key => (key || '').length > 2 && (key || '').includes('Ref') ? key.replace('Ref', '') : '')
  //         .filter(item => item !== '');
  // }
}