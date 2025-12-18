/**
 * Seed script to populate Firestore with sample marketplace widgets
 * Run with: node scripts/seed-marketplace.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccountPath = path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Widget templates to seed
const widgetTemplates = [
  {
    file: 'battery_widget.json',
    category: 'device-status',
    featured: true,
  },
  {
    file: 'environment_widget.json',
    category: 'metrics',
    featured: true,
  },
  {
    file: 'gps_widget.json',
    category: 'location',
    featured: true,
  },
  {
    file: 'network_overview_widget.json',
    category: 'mesh',
    featured: true,
  },
  {
    file: 'node_info_widget.json',
    category: 'device-status',
    featured: true,
  },
  {
    file: 'quick_actions_widget.json',
    category: 'utility',
    featured: false,
  },
  {
    file: 'signal_widget.json',
    category: 'metrics',
    featured: true,
  },
];

async function seedCategories() {
  console.log('Seeding categories...');

  const categories = [
    { id: 'device-status', name: 'Device Status', icon: 'phone_android', order: 1 },
    { id: 'metrics', name: 'Metrics', icon: 'analytics', order: 2 },
    { id: 'charts', name: 'Charts', icon: 'bar_chart', order: 3 },
    { id: 'mesh', name: 'Mesh Network', icon: 'hub', order: 4 },
    { id: 'location', name: 'Location', icon: 'location_on', order: 5 },
    { id: 'weather', name: 'Weather', icon: 'cloud', order: 6 },
    { id: 'utility', name: 'Utility', icon: 'build', order: 7 },
    { id: 'other', name: 'Other', icon: 'category', order: 99 },
  ];

  const batch = db.batch();
  for (const cat of categories) {
    const ref = db.collection('categories').doc(cat.id);
    batch.set(ref, cat);
  }
  await batch.commit();
  console.log(`✓ Created ${categories.length} categories`);
}

async function seedWidgets() {
  console.log('Seeding widgets...');

  const templatesDir = path.join(__dirname, '..', 'assets', 'widget_templates');
  let created = 0;

  for (const template of widgetTemplates) {
    const filePath = path.join(templatesDir, template.file);

    if (!fs.existsSync(filePath)) {
      console.log(`  ⚠ File not found: ${template.file}`);
      continue;
    }

    const content = fs.readFileSync(filePath, 'utf8');
    const widgetSchema = JSON.parse(content);

    const widget = {
      name: widgetSchema.name,
      description: widgetSchema.description || '',
      author: 'Socialmesh',
      authorId: 'system',
      version: widgetSchema.version || '1.0.0',
      tags: widgetSchema.tags || [],
      category: template.category,
      schema: widgetSchema,
      status: 'published',
      featured: template.featured,
      downloads: Math.floor(Math.random() * 500) + 100, // Random downloads 100-600
      ratingSum: Math.floor(Math.random() * 20) + 20, // Sum for ~4-5 star average
      ratingCount: Math.floor(Math.random() * 5) + 5, // 5-10 ratings
      averageRating: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Calculate average rating
    widget.averageRating = widget.ratingSum / widget.ratingCount;

    // Use the widget's original ID or generate from name
    const docId = widgetSchema.id || widgetSchema.name.toLowerCase().replace(/\s+/g, '-');

    await db.collection('widgets').doc(docId).set(widget);
    console.log(`  ✓ Created: ${widget.name}`);
    created++;
  }

  console.log(`✓ Created ${created} widgets`);
}

async function main() {
  try {
    console.log('🚀 Seeding Socialmesh Marketplace...\n');

    await seedCategories();
    await seedWidgets();

    console.log('\n✅ Marketplace seeded successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error seeding marketplace:', error);
    process.exit(1);
  }
}

main();
