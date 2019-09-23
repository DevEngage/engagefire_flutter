

import 'package:engagefire/core/firestore.dart';

class EngageDoc {
  static Map<String, EngageDoc> instances = {};
  dynamic $ref;
  dynamic $docRef;
  dynamic $collectionRef;
  EngageFirestore $engageFireStore;
  String $path;
  String $owner;
  String $id;
  String $collection;
  bool $loading = true;
  Map $collections = {};
  List<String> $collectionsList = [];
  List<String> $omitList = [];
  List relations = [];
  int position;
  Map<String, dynamic> $doc = {
    '\$owner': '',
    '\$id': '',
    '\$collection': '',
  };

  EngageDoc({String path, Map data, List<String> subCollections}) {
    if (path != null) {
      this.$path = path;
      this.$engageFireStore = EngageFirestore.getInstance(path);
    }
    if (data != null) {
      this.$doc = {...$doc, ...data};
    }
    if (subCollections != null) {
      this.$collectionsList = subCollections;
    }
    this.$$init();
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
      return this.$engageFireStore.save(this);
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
    this.$owner = await this.$engageFireStore.getUserId;
    this.$doc['\$owner'] = this.$owner;
    return this.$save();
  }

  Future $isOwner([userId]) async {
    userId ??= this.$doc['\$owner'];
    if (userId == null) {
      await this.$attachOwner();
    }
    return this.$doc['\$owner'] == (await this.$engageFireStore.getUserId);
  }

  Future<dynamic> $(String key, {dynamic value, int increment, int decrement, save = true, done}) async {
    if (increment != null && increment > 0) {
      value ??= this.$doc[key] ?? 0;
      value += increment;
    }
    if (decrement != null && decrement > 0) {
      value ??= this.$doc[key] ?? 0;
      value -= decrement;
    }
    if (value == null) {
      if (done != null) done(this.$doc[key]);
      return this.$doc[key];
    }
    this.$doc[key] = value;
    if(save) await this.$save();
    if (done != null) done(value);
    return this.$doc[key];
  }

  setState(value, cb) {
    // cb({})    
  }


  // async $addFiles(elements?: never[] | undefined, inputId?: string | undefined) {
  //   this.$$updateDoc();
  //   return await this.$engageFireStore.uploadFiles(this, elements, inputId);
  // }

  // async $setImage(options?: { width: string; height: string; thumbnail: { width: string; height: string; }; } | undefined, inputId?: any, file?: any) {
  //   this.$$updateDoc();
  //   return await this.$engageFireStore.uploadImage(this, inputId, file);
  // }

  // async $removeImage() {
  //   this.$$updateDoc();
  //   await this.$engageFireStore.deleteImage(this.$doc);
  //   await this.$save();
  //   return this.$doc;
  // }

  // async $removeFile(fileId: any) {
  //   this.$$updateDoc();
  //   await this.$engageFireStore.deleteFile(this.$doc, fileId);
  //   return this.$doc;
  // }

  // async $getFiles() {
  //   return (await this.$getSubCollection('$files')).getList();
  // }

  // async $getFile(fileId: any) {
  //   return (await this.$getSubCollection('$files')).get(fileId);
  // }

  // async $downloadFile(fileId: any) {
  //   const fileDoc: any = (await this.$getSubCollection('$files')).get(fileId);
  //   return await this.$engageFireStore.downloadFile(fileDoc.url);
  // }

  
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

  // Future $backup(bool deep, String backupPath) async {
  //   this.$$updateDoc();
  //   return await this.$engageFireStore.backupDoc(this.$doc, deep, backupPath);
  // }

  $exists() {
    this.$$updateDoc();
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
    if (list.every((item) => item.position != null)) {
      await this.$engageFireStore.buildListPositions();
    }
    var itemX = list[x];
    var itemY = list[y];
    var itemXPos = itemX.position || x + 1;
    var itemYPos = itemY.position || y + 1;
    itemX.position = itemYPos;
    itemY.position = itemXPos;
    this.$engageFireStore.list[y] = itemX;
    this.$engageFireStore.list[x] = itemY;
    await itemX.$save();
    await itemY.$save();
  }

  Future $moveUp() async {
    var list = $$getSortedParentList();
    int index = list.findIndex((item) => item.position == this.position);
    if (index <= 0) {
      return;
    }
    await this.$swapPosition(index, index-1, list);
  }

  Future $moveDown() async {
    var list = $$getSortedParentList();
    int index = list.findIndex((item) => item.position == this.position);
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

  $$getSortedParentList() {
    return this.$engageFireStore.sortListByPosition().list;
  }

  $$difference(Map object, base) {
    return object == base;
  }
}