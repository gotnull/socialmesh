#!/usr/bin/env node

/**
 * Fix Product Ratings Script
 * 
 * This script recalculates all product ratings and review counts based on
 * actual approved reviews in Firestore. The seed script had hardcoded fake
 * ratings (like 4.7, 145 reviews) which need to be replaced with real data.
 * 
 * Usage: node scripts/fix-product-ratings.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require(path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function recalculateProductRatings() {
  console.log('🔄 Recalculating product ratings from actual reviews...\n');

  try {
    // Get all products
    const productsSnapshot = await db.collection('shopProducts').get();
    console.log(`📦 Found ${productsSnapshot.size} products\n`);

    let updatedCount = 0;
    let unchangedCount = 0;

    for (const productDoc of productsSnapshot.docs) {
      const productId = productDoc.id;
      const productName = productDoc.data().name;

      // Get all approved reviews for this product
      const reviewsSnapshot = await db.collection('productReviews')
        .where('productId', '==', productId)
        .where('status', '==', 'approved')
        .get();

      if (reviewsSnapshot.empty) {
        // No approved reviews - reset to defaults
        await db.collection('shopProducts').doc(productId).update({
          rating: 0.0,
          reviewCount: 0,
        });
        console.log(`✅ ${productName}: Reset to 0 rating (no reviews)`);
        updatedCount++;
      } else {
        // Calculate average rating from approved reviews
        const totalRating = reviewsSnapshot.docs.reduce(
          (sum, doc) => sum + (doc.data().rating || 0),
          0
        );
        const avgRating = totalRating / reviewsSnapshot.size;
        const reviewCount = reviewsSnapshot.size;

        // Update product
        await db.collection('shopProducts').doc(productId).update({
          rating: avgRating,
          reviewCount: reviewCount,
        });

        console.log(`✅ ${productName}: ${avgRating.toFixed(1)} stars (${reviewCount} reviews)`);
        updatedCount++;
      }
    }

    console.log(`\n✨ Done! Updated ${updatedCount} products`);
    console.log(`📊 Summary:`);
    console.log(`   - Updated: ${updatedCount}`);
    console.log(`   - Unchanged: ${unchangedCount}`);

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }

  process.exit(0);
}

recalculateProductRatings();
