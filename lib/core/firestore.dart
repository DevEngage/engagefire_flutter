import 'dart:async';

import 'package:engagefire/core/doc.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/contacts.readonly',
    ],
  );

  EngageFirestore(String path) {
    path = path;
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
    $user = await _auth.currentUser();
    publish($user, 'user');
    if ($user != null) {
      userId = $user.uid;
      if (debug) print('userId: $userId');
    }
    await getModelFromDb();
    $loading = false;
  }

  static getInstance(
    String path,
    [var options]
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

  Future<List> getList([CollectionReference listRef]) async {
    $loading = true;
    listRef ??= ref;
    QuerySnapshot collection;
    collection = await listRef.getDocuments();
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

  addFire(data, String id) {
    if (EngageDoc != null) {
      data.$id = id;
      return EngageDoc(data: data, path: path, subCollections: subCollections);
    }
    return data;
  }

  omitFireList(List list) {
    return list.map(this.omitFire);
  }

  omitFire(Map<String, dynamic> payload) {
    if (payload != null && payload['\$omitList'] != null) {
      omitList.map((item) => payload.remove(item));
    }
    omitList.map((item) => payload.remove(item));

    return payload.map(omitDepth);
  }
  
  MapEntry<dynamic, dynamic> omitDepth(dynamic value, dynamic index) {
    if (value is List) {
      value = value.map((item) => item is Map ? this.omitFire(item) : null);
    }
    if (value is Map) {
      value = this.omitFire(value);
      value = value.map((item) => item is Map<dynamic, dynamic> ? this.omitFire(item) : null);
      if (value != null && value['\&id']) {
        value = { 
          '\$id': value['\&id'], 
          '\$collection': value['\&collection'],
          '\$collection': value['\&collection'],
          '\$image': value['\&image'],
          'name': value['\&name'] ?? '', 
        };
      }
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
    return this.getList(ref);
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

   Future<dynamic> getWithChildern(docId, [CollectionReference listRef]) async {
    var doc = await get(docId, listRef);
    if (doc) {
      doc = await this.getChildDocs(doc);
    }
    return doc;
  }

  Future<dynamic> get(docId, [CollectionReference listRef]) async {
    $loading = true;
    listRef ??= ref;
    try {
      DocumentSnapshot doc;
      doc = await listRef.document(docId).get();
      this.$loading = false;
      if (doc.exists) {
        dynamic fireDoc = this.addFire(doc.data, docId);
        num index = this.list.indexOf(fireDoc);
        if (index > -1) this.list[index] = fireDoc;
        else this.list.add(fireDoc);
        return fireDoc;
      }
      return null;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<dynamic> add(dynamic newDoc, dynamic docRef) async {
    newDoc.$loading = true;
    docRef ??= ref;
    if (newDoc != null && (newDoc.$key != null || newDoc.$id != null)) {
      newDoc.$loading = false;
      return this.update(newDoc, docRef);
    }
    if (debug) {
      print('add');
      print(newDoc);
    }
    newDoc = this.omitFire(newDoc);
    DocumentReference blank = docRef.document();
    await blank.setData(newDoc);
    return this.addFire(newDoc, blank.documentID);
  }

  Future<dynamic> setDoc(dynamic newDoc, [dynamic docRef]) async {
    newDoc.$loading = true;
    if (debug) {
      print('set');
      print(newDoc);
    }
    newDoc = omitFire(newDoc);
    await docRef.setData(newDoc);
    return addFire(newDoc, docRef.id);
  }

  Future<dynamic> setWithId(String id, [dynamic newDoc]) async {
    return setDoc(newDoc, ref.document(id));
  }

  Future<dynamic> update(dynamic doc, [dynamic docRef]) async {
    doc.$loading = true;
    docRef ??= ref;
    DocumentReference documentRef;
    if (doc.$id) {
      documentRef = docRef.document(doc.$id);
      doc.$loading = false;
      if (!(await documentRef.get()).exists) return setDoc(doc, documentRef);
    } else if (doc.$key) {
      documentRef = docRef.document(doc.$key);
      doc.$loading = false;
      if (!(await documentRef.get()).exists) return setDoc(doc, documentRef);
    } else if (docRef.id == null) {
      doc.$loading = false;
      print('no id');
    }
    if (debug) {
      print('updated');
      print(doc);
    }
    doc = omitFire(doc);
    await documentRef.updateData(doc);
    return addFire(doc, documentRef.documentID);
  }

  Future<dynamic> save(newDoc, [CollectionReference listRef]) async {
    newDoc = omitFire(newDoc);
    newDoc.$updatedAt = DateTime.now().millisecondsSinceEpoch;
    dynamic doc;
    try {
      if (newDoc != null && (newDoc.$key != null || newDoc.$id != null)) {
        doc = await update(newDoc, listRef);
      } else if (listRef != null && listRef.id != null) {
        newDoc.$createdAt = DateTime.now().millisecondsSinceEpoch;
        newDoc.$timezoneOffset = DateTime.now().timeZoneOffset;
        doc = await setDoc(newDoc, listRef);
      } else {
        newDoc.$createdAt = DateTime.now().millisecondsSinceEpoch;
        newDoc.$timezoneOffset = DateTime.now().timeZoneOffset;
        doc = await add(newDoc, listRef);
        list = [...list, doc];
      }
    } catch (error) {
      print(error);

    }
    doc.$loading = false;
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
    auth
   */

  Future<FirebaseUser> get getUser => _auth.currentUser();
  Future<String> get getUserId async => (await getUser).uid;

  Stream<FirebaseUser> get user => _auth.onAuthStateChanged;

  Future<FirebaseUser> googleSignIn() async {
    try {
      var googleSignInAccount = await _googleSignIn.signIn();
      var googleAuth =
          await googleSignInAccount.authentication;

      final credential = GoogleAuthProvider.getCredential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      var user = await _auth.signInWithCredential(credential);
      
      await updateUserData(user.user);

      return user.user;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<FirebaseUser> emailSignIn({String email, String password}) async {
    try {
      var user = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
      await updateUserData(user.user);
      return user.user;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<FirebaseUser> emailSignUp({String email, String password, String passwordAgain}) async {
    if (password != passwordAgain) {
      return null;
    }
    try {
      var user = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
      await updateUserData(user.user);
      return user.user;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<FirebaseUser> emailLinkSignIn({String email, String link}) async {
    try {
      var user = await _auth.signInWithEmailAndLink(email: email.trim(), link: link);
      await updateUserData(user.user);
      return user.user;
    } catch (error) {
      print(error);
      return null;
    }
  }

  // Future<FirebaseUser> facebookSignIn() async {
  //   try {
  //     GoogleSignInAccount googleSignInAccount = await _googleSignIn.signIn();
  //     GoogleSignInAuthentication googleAuth =
  //         await googleSignInAccount.authentication;

  //     final AuthCredential credential = GoogleAuthProvider.getCredential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );

  //     FirebaseUser user = await _auth.signInWithCredential(credential);
  //     updateUserData(user);

  //     return user;
  //   } catch (error) {
  //     print(error);
  //     return null;
  //   }
  // }

  Future<FirebaseUser> anonLogin() async {
    var user = await _auth.signInAnonymously();
    await updateUserData(user.user);
    return user.user;
  }

  Future<void> updateUserData(FirebaseUser user) {
    return EngageFirestore.getInstance('reports').save({
      '\$id': user.uid,
      'lastActivity': DateTime.now()
    });

  }

  Future<void> updateProfile({firstName, lastName, email}) async {
    var user = await getUser;
    DocumentReference reportRef = EngageFirestore.getInstance('profile').get(user.uid);

    return reportRef.setData({
      'firstName': firstName, 
      'lastName': lastName, 
      'email': email,
      'updatedAt': DateTime.now()
    }, merge: true);

  }

  Future<void> getProfile() async {
    var user = await getUser;
    return EngageFirestore.getInstance('profile').get(user.uid);
  }

    Future<void> forgotPassword(String email) async {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> emailSignInMethods(String email) async {
    return _auth.fetchSignInMethodsForEmail(email: email);
  }

  Future<void> verifyPhoneNumber({
    String phoneNumber,
    Duration timeout,
    int forceResendingToken,
    PhoneVerificationCompleted verificationCompleted,
    PhoneVerificationFailed verificationFailed,
    PhoneCodeSent codeSent,
    PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) async {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      forceResendingToken: forceResendingToken,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  /*
   * UTILITIES
   */

  Future replaceId(String oldId, newId, [ref]) async {
    ref ??= this.ref;
    Map data;
    data = await this.get(oldId, ref);
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
    data = await this.get(oldId, subRef);
    if (data == null) {
      print('cant find record for: $oldId');
      return 'cant find record';
    }
    data = this.addFire(data, newId);
    await this.save(data, subRef);
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