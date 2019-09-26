import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore.dart';

class EngageAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static FirebaseUser user;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/contacts.readonly',
    ],
  );

  EngageAuth() {}

  static init() async {
    EngageAuth.user = await FirebaseAuth.instance.currentUser();
    return EngageAuth();
  }
  
   /* 
    auth
   */

  Future<FirebaseUser> get currentUser => EngageAuth.user ?? _auth.currentUser();
  Future<String> get currentUserId async => user != null ? EngageAuth.user.uid : (await currentUser).uid;
  Stream<FirebaseUser> get streamUser => _auth.onAuthStateChanged;

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
    init();
    return EngageFirestore.getInstance('reports').save({
      '\$id': user.uid,
      'lastActivity': DateTime.now()
    });

  }

  Future<void> updateProfile({firstName, lastName, email}) async {
    var user = await currentUser;
    DocumentReference reportRef = EngageFirestore.getInstance('profile').get(user.uid);

    return reportRef.setData({
      'firstName': firstName, 
      'lastName': lastName, 
      'email': email,
      '\$updatedAt': DateTime.now()
    }, merge: true);

  }

  Future<void> getProfile() async {
    var user = await currentUser;
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
    user = null;
    return _auth.signOut();
  }
}