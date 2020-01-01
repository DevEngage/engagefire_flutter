import 'dart:io';
import 'package:engagefire/core/firestore.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth.dart';
import 'engagefire.dart';

/*
 * TODO:
 * [ ] Increment multiple values by given Map of values
 * [ ] Toggle subcollection
 * [ ] add and remove subCollection
 * [ ] add event to subCollection
 * [ ] get subCollectionList
 * [ ] remove sub Collections from this and make it so we set it up in the beginning or model
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

  EngageDoc({path, Map data, ignoreInit = false}) {
    this._path = path;
    if (!ignoreInit && path != null) this.$$setupDoc(path, data);
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
  
  static Future<EngageDoc> getOrCreate({String path, Map defaultData, Map filter}) async {
    String userId = await EngageAuth().currentUserId;
    path = EngageFirestore.replaceTemplateString(path ?? '', userId: userId);
    EngageFirestore collection = await EngageFirestore.getInstance(path);
    EngageDoc doc = await collection.getOrCreate(defaultData: defaultData, filter: filter);
    return doc;
  }

  validateInit(path) {
    path ??=  _path;
    if (path != null) {
      List pathList = (path ?? '').split('/');
      if (pathList.isEmpty && pathList.length % 2 == 0)  {
        throw 'Path is Collection and not Doc';
      }
    }
    return true;
  }

  bool $$isPathCorrect([path]) {
    List pathList = (path ?? _path ?? '').split('/');
    return pathList.length > 0 && pathList.length % 2 == 0;
  }

  String $$getCollection([path]) {
    List pathList = (path ?? _path ?? '').split('/');
    final collectionPath = pathList.join('/');
    return collectionPath;
  }

  String $$parseId([path]) {
    List pathList = (path ?? _path ?? '').split('/');
    final docId = pathList.removeLast();
    return docId;
  }

  Future<void> $$init() async {
    this.$id = this.$doc['\$id'] ?? this.$doc['id'] ?? this.$id;
    this.$ref = this.$engageFireStore.ref;
    String tmpPath;
    tmpPath = this.$engageFireStore.path;
    this.$path = "$tmpPath/${$id}";
    this.$collection = this.$ref.path;
    this.$doc['\$collection'] = this.$collection;
    this.$doc['\$id'] = this.$id;
    this.$docRef = this.$ref.document(this.$id);
    this.$loading = false;
  }

  $$setupParentCollection([path]) {
    path ??= $path;
    final isDocPath = $$isPathCorrect(path);
    if (isDocPath) {
      path = $$getCollection(path);
      this.$engageFireStore = EngageFirestore.getInstance(path);
    } else if (path != null) {
      this.$engageFireStore = EngageFirestore.getInstance(path);
    }
  }

  $$setupDoc([String path = '', data]) async {
    if (validateInit(path)) {
      return false;
    }
    path ??= $path;
    final userId = await EngageAuth().currentUserId;
    final isDocPath = $$isPathCorrect(path);
    path = EngageFirestore.replaceTemplateString(path ?? '', userId: userId);
    $$setupParentCollection(path);
    var docId = $$parseId(path);
    if (isDocPath) {
      data = await this.$engageFireStore.get(docId, pure: true);
    }
    if (data != null) {
      this.$doc = {...$doc, ...data};
    } else if (docId != null) {
      this.$doc = {...$doc, '\$updatedAt': DateTime.now().millisecondsSinceEpoch, '\$id': this.$engageFireStore.getStringVar(docId)};
    }
    await this.$$init();
  }

  $buildCollections(element, id) {
    var commands = element.split('.');
    var sub = commands[0];
    var preFetch;
    if (commands.length > 1) {
      preFetch = commands[1];
    }
    print($$parseId());
    // print("${$path}$sub");
    this.$collections['$sub\_'] = EngageFirestore.getInstance("${$path}$sub");
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

  Future<dynamic> $(String key, {dynamic value, dynamic defaultValue, int increment, int decrement, Function done, save = true, recordEvent = false}) async {
    if (increment != null && increment > 0) {
      value ??= this.$doc[key] ?? increment is double ? 0.0 : 0;
      value += increment;
    }
    if (decrement != null && decrement > 0) {
      value ??= this.$doc[key] ?? increment is double ? 0.0 : 0;
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
    if (recordEvent) await $$recordEvent({key: this.$doc[key]});
    return this.$doc[key];
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
    if(save) await this.$save();
    if (done != null) done(doc);
    if (recordEvent) await $$recordEvent(doc);
    return this.$doc;
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
    Map fileDoc = await (this.$getSubCollection('\$files')).get(fileId);
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

  EngageFirestore $getSubCollection(String collection, [options]) {
    return EngageFirestore.getInstance("${this.$path}/$collection", options: options);
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

  bool $setDefaults(Map data, {userId, dateDMY, doc}) {
    doc ??= $doc;
    $engageFireStore ??= $$setupParentCollection();
    var changed = false;
    data.forEach((key, value) {
      if ($doc[key] == null && value != null && this.$engageFireStore != null) {
        $doc[key] = this.$engageFireStore.getStringVar(value, userId: userId, dateDMY: dateDMY);
        changed = true;
      }
      if (this.$engageFireStore == null) {
        print('$_path missing collection (this.\$engageFireStore)');
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

  Future $$recordEvent(Map doc) async {
    dynamic result;
    if (doc != null) {
      result = await EngageFirestore.getInstance("${this.$path}/events").save(doc);
    }
    return result;
  }

  Future $toggleSub(String collection, data) async {
    EngageFirestore ref = $getSubCollection(collection);
    String id = data is String ? data : data['\$id'];
    EngageDoc doc = await ref.get(id);
    if (doc == null && data is String) {
      await ref.save({
        $id: id,
      });
      return true;
    } else if (doc == null) {
      await ref.save(data);
      return true;
    }
    await ref.remove(id);
    return false;
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

  Future<EngageFirestore> $getSub(String collection, [options]) async {
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