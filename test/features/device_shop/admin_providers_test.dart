import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/features/device_shop/providers/admin_shop_providers.dart';

void main() {
  group('Admin Shop Providers', () {
    test('pendingReviewCountProvider is a StreamProvider', () {
      expect(pendingReviewCountProvider, isA<StreamProvider<int>>());
    });

    test('isShopAdminProvider is a FutureProvider', () {
      expect(isShopAdminProvider, isA<FutureProvider<bool>>());
    });

    test('adminShopStatisticsProvider is a FutureProvider', () {
      expect(adminShopStatisticsProvider, isA<FutureProvider>());
    });

    test('adminAllProductsProvider is a StreamProvider', () {
      expect(adminAllProductsProvider, isA<StreamProvider>());
    });

    test('adminAllSellersProvider is a StreamProvider', () {
      expect(adminAllSellersProvider, isA<StreamProvider>());
    });
  });

  group('ProductFormNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with empty product', () {
      final form = container.read(productFormProvider);

      expect(form.id, '');
      expect(form.name, '');
      expect(form.description, '');
      expect(form.price, 0);
      expect(form.isActive, true);
      expect(form.isInStock, true);
      expect(form.isFeatured, false);
    });

    test('updateName changes product name', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateName('Test Product');
      final form = container.read(productFormProvider);

      expect(form.name, 'Test Product');
    });

    test('updateDescription changes description', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateDescription('Test description');
      final form = container.read(productFormProvider);

      expect(form.description, 'Test description');
    });

    test('updatePrice changes price', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updatePrice(99.99);
      final form = container.read(productFormProvider);

      expect(form.price, 99.99);
    });

    test('updateCompareAtPrice changes compareAtPrice', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateCompareAtPrice(129.99);
      final form = container.read(productFormProvider);

      expect(form.compareAtPrice, 129.99);
    });

    test('updateIsInStock toggles stock status', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateIsInStock(false);
      var form = container.read(productFormProvider);
      expect(form.isInStock, false);

      notifier.updateIsInStock(true);
      form = container.read(productFormProvider);
      expect(form.isInStock, true);
    });

    test('updateIsFeatured toggles featured status', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateIsFeatured(true);
      var form = container.read(productFormProvider);
      expect(form.isFeatured, true);

      notifier.updateIsFeatured(false);
      form = container.read(productFormProvider);
      expect(form.isFeatured, false);
    });

    test('addImageUrl adds image to list', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.addImageUrl('https://example.com/image1.jpg');
      notifier.addImageUrl('https://example.com/image2.jpg');

      final form = container.read(productFormProvider);
      expect(form.imageUrls.length, 2);
      expect(form.imageUrls[0], 'https://example.com/image1.jpg');
      expect(form.imageUrls[1], 'https://example.com/image2.jpg');
    });

    test('removeImageUrl removes image at index', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateImageUrls([
        'https://example.com/image1.jpg',
        'https://example.com/image2.jpg',
        'https://example.com/image3.jpg',
      ]);

      notifier.removeImageUrl(1);

      final form = container.read(productFormProvider);
      expect(form.imageUrls.length, 2);
      expect(form.imageUrls, [
        'https://example.com/image1.jpg',
        'https://example.com/image3.jpg',
      ]);
    });

    test('reorderImages changes image order', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateImageUrls([
        'https://example.com/image1.jpg',
        'https://example.com/image2.jpg',
        'https://example.com/image3.jpg',
      ]);

      // Move first image to end
      notifier.reorderImages(0, 3);

      final form = container.read(productFormProvider);
      expect(form.imageUrls, [
        'https://example.com/image2.jpg',
        'https://example.com/image3.jpg',
        'https://example.com/image1.jpg',
      ]);
    });

    test('reset clears form to initial state', () {
      final notifier = container.read(productFormProvider.notifier);

      notifier.updateName('Test Product');
      notifier.updatePrice(99.99);
      notifier.updateIsFeatured(true);

      notifier.reset();

      final form = container.read(productFormProvider);
      expect(form.name, '');
      expect(form.price, 0);
      expect(form.isFeatured, false);
    });
  });

  group('SellerFormNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with empty seller', () {
      final form = container.read(sellerFormProvider);

      expect(form.id, '');
      expect(form.name, '');
      expect(form.description, '');
      expect(form.isActive, true);
      expect(form.isVerified, false);
      expect(form.isOfficialPartner, false);
    });

    test('updateName changes seller name', () {
      final notifier = container.read(sellerFormProvider.notifier);

      notifier.updateName('Test Seller');
      final form = container.read(sellerFormProvider);

      expect(form.name, 'Test Seller');
    });

    test('updateIsVerified toggles verification', () {
      final notifier = container.read(sellerFormProvider.notifier);

      notifier.updateIsVerified(true);
      var form = container.read(sellerFormProvider);
      expect(form.isVerified, true);

      notifier.updateIsVerified(false);
      form = container.read(sellerFormProvider);
      expect(form.isVerified, false);
    });

    test('updateIsOfficialPartner toggles partner status', () {
      final notifier = container.read(sellerFormProvider.notifier);

      notifier.updateIsOfficialPartner(true);
      var form = container.read(sellerFormProvider);
      expect(form.isOfficialPartner, true);

      notifier.updateIsOfficialPartner(false);
      form = container.read(sellerFormProvider);
      expect(form.isOfficialPartner, false);
    });

    test('updateCountries changes country list', () {
      final notifier = container.read(sellerFormProvider.notifier);

      notifier.updateCountries(['US', 'CA', 'UK']);
      final form = container.read(sellerFormProvider);

      expect(form.countries, ['US', 'CA', 'UK']);
    });

    test('reset clears form to initial state', () {
      final notifier = container.read(sellerFormProvider.notifier);

      notifier.updateName('Test Seller');
      notifier.updateIsVerified(true);
      notifier.updateCountries(['US', 'CA']);

      notifier.reset();

      final form = container.read(sellerFormProvider);
      expect(form.name, '');
      expect(form.isVerified, false);
      expect(form.countries, []);
    });
  });
}
