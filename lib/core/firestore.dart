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

  publish(var data, String what) {
    return this._ps.publish(data, what);
  }

  Future<List> getModelFromDb() async {
    if (path.contains('\$collections')) {
      return this.model = [];
    }
    this.model = await EngageFirestore.getInstance('\$collections/$path/\$models').getList();
    await this.sortModel();
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
    const list = await listRef.get();
    this.list = this.addFireList(list);
    this.$loading = false;
    return this.list;
  }

  Future<List> addFireList(collection: any) async {
    list = [];
    if (collection && collection.size) {
      collection.forEach((DocumentSnapshot doc) => doc.exists ? list.add(this.addFire(doc.data, doc.documentID)) : null);
    }
    return list;
  }

  addFire(data, String id) {
    if (EngageDoc != null) {
      data.$id = id;
      return EngageDoc(data, path, subCollections);
    }
    return data;
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

  save() {
    reportRef.setData({
      'userid': user.uid,
      'lastActivity': DateTime.now()
    }, merge: true);
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
      await updateUserData(user);

      return user;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<FirebaseUser> emailSignIn({String email, String password}) async {
    try {
      var user = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
      await updateUserData(user);
      return user;
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
      await updateUserData(user);
      return user;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<FirebaseUser> emailLinkSignIn({String email, String link}) async {
    try {
      var user = await _auth.signInWithEmailAndLink(email: email.trim(), link: link);
      await updateUserData(user);
      return user;
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
    await updateUserData(user);
    return user;
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
    return _auth.verifyPhoneNumber({
      phoneNumber,
      timeout,
      forceResendingToken,
      verificationCompleted,
      verificationFailed,
      codeSent,
      codeAutoRetrievalTimeout,
    });
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

}