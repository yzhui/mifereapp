
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:todo_app/domain/repository/UserRepository.dart';

class UserRepositoryImpl implements UserRepository {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<String> getUserDisplayName() async {
    final user = await _auth.currentUser();
    return user == null ? '' : user.displayName;
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      //final googleUser = await _googleSignIn.signIn();
      //final googleAuth = await googleUser.authentication;
      //final credential = GoogleAuthProvider.getCredential(idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);

      //await _auth.signInWithCredential(credential);
      print('##################sign in with google yes###############33');
      return true;
    } catch (e) {
      await signOut();
      return false;
    }
  }

    @override
  Future<bool> signInWithLocal() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.getCredential(idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);

      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      await signOut();
      return false;
    }
  }

  @override
  Future<bool> signInWithFacebook() async {
    return false;
  }

  @override
  Future<bool> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();

      final userId = await getUserId();
      if (userId.isEmpty) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getUserId() async {
    final user = await _auth.currentUser();
    return user == null ? '' : user.uid;
  }

  @override
  Future<bool> setUserDisplayName(String uid, String name) async {
    try {
      final user = await _auth.currentUser();
      final updateInfo = UserUpdateInfo()..displayName = name;
      await user.updateProfile(updateInfo);
      return true;
    } catch (e) {
      return false;
    }
  }
}