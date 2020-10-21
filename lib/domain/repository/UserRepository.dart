
abstract class UserRepository {
  Future<String> getUserDisplayName();
  Future<bool> signInWithGoogle();
  Future<bool> signInWithFacebook();
  Future<bool> signInWithLocal();
  Future<bool> signOut();
  Future<String> getUserId();
  Future<bool> setUserDisplayName(String uid, String name);
}