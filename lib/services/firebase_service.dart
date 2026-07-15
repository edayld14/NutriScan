import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ALERJİLERİ GÜNCELLEME 
  Future<void> updateUserAllergies(List<String> allergies) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'allergies': allergies,
      });
    }
  }

  // Kullanıcı hassasiyet ve bebek profili ayarlarını güncelleme fonksiyonu
  Future<void> updateUserData(Map<String, dynamic> data) async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update(data);
      }
    } catch (e) {
      debugPrint("Firebase Güncelleme Hatası: $e");
    }
  }

  // 1. Gelişmiş Kullanıcı Kayıt (Ad-Soyad ve Rol eklendi)
  Future<User?> registerWithEmail(String email, String password, String fullName, List<String> initialAllergies) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      User? user = result.user;

      if (user != null) {
        // 'role' alanını varsayılan olarak 'user' yapıyoruz. 
        // Admin yapmak istediğin hesabı Firestore panelinden manuel olarak 'admin' olarak değiştirebilirsin.
        await _firestore.collection('users').doc(user.uid).set({
          'fullName': fullName,
          'email': email,
          'allergies': initialAllergies,
          'role': 'user', 
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } catch (e) {
      debugPrint("Kayıt Hatası: $e");
      return null;
    }
  }

  // 2. Kullanıcı Girişi
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      debugPrint("Giriş Hatası: $e");
      return null;
    }
  }

  // 3. Kullanıcı Bilgilerini Çekme (Rol, İsim ve Alerjiler)
  Future<Map<String, dynamic>?> getUserData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Veri Çekme Hatası: $e");
      return null;
    }
  }

  // 4. Admin'e Mesaj / İstek Gönderme
  Future<bool> sendMessageToAdmin(String message) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      await _firestore.collection('admin_messages').add({
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'message': message,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("Mesaj Gönderme Hatası: $e");
      return false;
    }
  }

  // 5. Admin İçin: Firebase'e Yeni Katkı Maddesi Ekleme
  Future<bool> addNewIngredientAsAdmin(Map<String, dynamic> ingredientData) async {
    try {
      await _firestore.collection('dynamic_ingredients').add(ingredientData);
      return true;
    } catch (e) {
      debugPrint("Madde Ekleme Hatası: $e");
      return false;
    }
  }

  // 6. Firebase'deki Dinamik Katkı Maddelerini Çekme
  Future<List<dynamic>> getDynamicIngredients() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('dynamic_ingredients').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Dinamik Madde Çekme Hatası: $e");
      return [];
    }
  }

  // ENTEGRASYON: Ürünü favorilere veya kara listeye ekleme/çıkarma fonksiyonu
  Future<void> toggleProductInList(String listName, String productText, bool add) async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final docRef = _firestore.collection('users').doc(uid);
      
      if (add) {
        // Eleman zaten yoksa listeye ekle (Dizinin küme gibi davranmasını sağlar)
        await docRef.update({
          listName: FieldValue.arrayUnion([productText])
        });
      } else {
        // Elemanı listeden temizle
        await docRef.update({
          listName: FieldValue.arrayRemove([productText])
        });
      }
    } catch (e) {
      debugPrint("Liste Güncelleme Hatası ($listName): $e");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}