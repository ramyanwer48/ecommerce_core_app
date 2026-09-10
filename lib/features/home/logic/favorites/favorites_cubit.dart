// lib/features/home/logic/favorites/favorites_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/product_model.dart';
import '../../data/models/favorite_model.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit() : super(FavoritesInitial());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔄 جلب المفضلة مع مزامنة البيانات الحية من المخزن
  Future<void> fetchFavorites() async {
    final user = _auth.currentUser;
    if (user == null) {
      emit(FavoritesError('يجب تسجيل الدخول لعرض المفضلة'));
      return;
    }

    emit(FavoritesLoading());
    try {
      // 1. جلب المستندات من مفضلة العميل
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .get();

      List<FavoriteModel> freshFavorites = [];

      // 2. فحص كل منتج في المخزن الرئيسي لمعرفة حالته وسعره الجديد
      for (var doc in snapshot.docs) {
        final favoriteData = doc.data();
        final productId = doc.id;

        // جلب الداتا الحية للمنتج من كوليكشن products
        final productDoc = await _firestore.collection('products').doc(productId).get();

        if (productDoc.exists) {
          final productData = productDoc.data()!;
          freshFavorites.add(
              FavoriteModel(
                productId: productId,
                name: productData['name'] ?? favoriteData['name'], // أحدث اسم
                price: (productData['price'] ?? favoriteData['price']).toDouble(), // 👈 تحديث السعر لو الأدمن غيره
                imageUrl: favoriteData['imageUrl'],
                isActive: productData['isActive'] ?? true, // 👈 السر هنا: قراءة حالة الإخفاء الحالية
              )
          );
        } else {
          // لو المنتج تم حذفه نهائياً (Hard Delete) عن طريق الخطأ
          freshFavorites.add(
              FavoriteModel(
                productId: productId,
                name: favoriteData['name'],
                price: favoriteData['price'].toDouble(),
                imageUrl: favoriteData['imageUrl'],
                isActive: false, // 👈 نعتبره غير متاح
              )
          );
        }
      }

      final favoriteIds = freshFavorites.map((e) => e.productId).toList();

      emit(FavoritesLoaded(freshFavorites, favoriteIds));
    } catch (e) {
      emit(FavoritesError('حدث خطأ أثناء جلب المفضلة: $e'));
    }
  }

  // إضافة أو إزالة منتج من المفضلة (Toggle)
  Future<void> toggleFavorite(ProductModel product) async {
    final user = _auth.currentUser;
    if (user == null) {
      emit(FavoritesError('يجب تسجيل الدخول لإضافة المنتجات للمفضلة'));
      if (state is FavoritesLoaded) {
        emit(FavoritesLoaded((state as FavoritesLoaded).favoriteProducts, (state as FavoritesLoaded).favoriteIds));
      }
      return;
    }

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(product.id);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.delete();
      } else {
        final imageUrl = product.images.isNotEmpty ? product.images.first : product.imageUrl;
        final favoriteItem = FavoriteModel(
          productId: product.id,
          name: product.name,
          price: product.price,
          imageUrl: imageUrl,
          isActive: true, // الافتراضي عند الإضافة
        );
        await docRef.set(favoriteItem.toJson());
      }

      // جلب البيانات مجدداً لتحديث الواجهة
      await fetchFavorites();

    } catch (e) {
      emit(FavoritesError('حدث خطأ أثناء التحديث: $e'));
      await fetchFavorites();
    }
  }
}