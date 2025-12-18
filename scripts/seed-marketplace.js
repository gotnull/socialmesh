/**
 * Seed script to populate Firestore with wizard-style marketplace widgets
 * These widgets match the format created by the Widget Wizard
 * Run with: node scripts/seed-marketplace-v2.js
 */

const admin = require('firebase-admin');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// Initialize Firebase Admin with service account
const serviceAccountPath = path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Colors matching the wizard defaults
const COLORS = {
  accent: '#E91E8C',
  blue: '#4F6AF6',
  green: '#4ADE80',
  yellow: '#FBBF24',
  pink: '#F472B6',
  purple: '#A78BFA',
  cyan: '#22D3EE',
  red: '#EF4444',
  orange: '#FF9F43',
  textSecondary: '#9CA3AF',
  textTertiary: '#6B7280',
  white: '#FFFFFF',
};

// Helper to generate UUID
function uuid() {
  return uuidv4();
}

// ============================================================================
// WIZARD-STYLE WIDGET TEMPLATES
// ============================================================================

/**
 * Signal Monitor - Graph widget with RSSI & SNR (like the wizard creates)
 */
function signalMonitorWidget() {
  const now = new Date().toISOString();
  return {
    id: uuid(),
    name: 'Signal Monitor',
    description: 'Live RSSI & SNR charts with merged overlay',
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
    size: 'medium',
    tags: ['signal', 'rssi', 'snr', 'chart', 'graph'],
    root: {
      id: uuid(),
      type: 'column',
      style: { padding: 12, spacing: 8 },
      children: [
        // Legend row
        {
          id: uuid(),
          type: 'row',
          style: {
            mainAxisAlignment: 'center',
            crossAxisAlignment: 'center',
            padding: 4,
            spacing: 16,
          },
          children: [
            // RSSI legend
            {
              id: uuid(),
              type: 'row',
              style: { spacing: 4, crossAxisAlignment: 'center' },
              children: [
                {
                  id: uuid(),
                  type: 'container',
                  style: { width: 8, height: 8, borderRadius: 4, backgroundColor: COLORS.blue },
                },
                {
                  id: uuid(),
                  type: 'text',
                  text: 'RSSI',
                  style: { textColor: COLORS.textSecondary, fontSize: 10 },
                },
              ],
            },
            // SNR legend
            {
              id: uuid(),
              type: 'row',
              style: { spacing: 4, crossAxisAlignment: 'center' },
              children: [
                {
                  id: uuid(),
                  type: 'container',
                  style: { width: 8, height: 8, borderRadius: 4, backgroundColor: COLORS.green },
                },
                {
                  id: uuid(),
                  type: 'text',
                  text: 'SNR',
                  style: { textColor: COLORS.textSecondary, fontSize: 10 },
                },
              ],
            },
          ],
        },
        // Spacer
        { id: uuid(), type: 'spacer', style: { height: 8 } },
        // Multi-line chart
        {
          id: uuid(),
          type: 'chart',
          chartType: 'multiLine',
          chartShowGrid: true,
          chartShowDots: true,
          chartCurved: true,
          chartMaxPoints: 30,
          chartBindingPaths: ['device.rssi', 'device.snr'],
          chartLegendLabels: ['RSSI', 'SNR'],
          chartLegendColors: [COLORS.blue, COLORS.green],
          chartMergeMode: 'overlay',
          chartNormalization: 'raw',
          chartBaseline: 'zero',
          chartGradientFill: true,
          chartGradientLowColor: '#1E293B',
          chartGradientHighColor: COLORS.blue,
          style: { height: 120, textColor: COLORS.accent },
        },
      ],
    },
  };
}

/**
 * Battery & Power Status - Status display with progress bars
 */
function batteryStatusWidget() {
  const now = new Date().toISOString();
  return {
    id: uuid(),
    name: 'Battery & Power',
    description: 'Battery level and voltage with progress bars',
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
    size: 'medium',
    tags: ['battery', 'power', 'status', 'voltage'],
    root: {
      id: uuid(),
      type: 'column',
      style: { padding: 12, spacing: 8 },
      children: [
        // Battery Level row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Battery Level',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.batteryLevel', format: '{value}%', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Battery gauge
        {
          id: uuid(),
          type: 'gauge',
          gaugeType: 'linear',
          gaugeMin: 0,
          gaugeMax: 100,
          gaugeColor: COLORS.green,
          binding: { path: 'node.batteryLevel' },
          style: { height: 6 },
        },
        // Voltage row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Voltage',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.voltage', format: '{value} V', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Voltage gauge
        {
          id: uuid(),
          type: 'gauge',
          gaugeType: 'linear',
          gaugeMin: 3.0,
          gaugeMax: 4.2,
          gaugeColor: COLORS.yellow,
          binding: { path: 'node.voltage' },
          style: { height: 6 },
        },
      ],
    },
  };
}

/**
 * Environment Gauges - Radial gauges for temp, humidity, pressure
 */
function environmentGaugesWidget() {
  const now = new Date().toISOString();
  return {
    id: uuid(),
    name: 'Environment Gauges',
    description: 'Temperature, humidity & pressure with radial gauges',
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
    size: 'medium',
    tags: ['environment', 'temperature', 'humidity', 'pressure', 'gauge'],
    root: {
      id: uuid(),
      type: 'column',
      style: { padding: 12, spacing: 8 },
      children: [
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceEvenly' },
          children: [
            // Temperature gauge
            {
              id: uuid(),
              type: 'column',
              style: { alignment: 'center' },
              children: [
                {
                  id: uuid(),
                  type: 'text',
                  binding: { path: 'node.temperature', format: '{value}°', defaultValue: '--' },
                  style: { textColor: COLORS.red, fontSize: 20, fontWeight: 'w700' },
                },
                { id: uuid(), type: 'spacer', style: { height: 8 } },
                {
                  id: uuid(),
                  type: 'gauge',
                  gaugeType: 'radial',
                  gaugeMin: -20,
                  gaugeMax: 50,
                  gaugeColor: COLORS.red,
                  binding: { path: 'node.temperature' },
                  style: { width: 70, height: 70 },
                },
                { id: uuid(), type: 'spacer', style: { height: 8 } },
                {
                  id: uuid(),
                  type: 'text',
                  text: 'Temp',
                  style: { textColor: COLORS.textSecondary, fontSize: 11, fontWeight: 'w500' },
                },
              ],
            },
            // Humidity gauge
            {
              id: uuid(),
              type: 'column',
              style: { alignment: 'center' },
              children: [
                {
                  id: uuid(),
                  type: 'text',
                  binding: { path: 'node.humidity', format: '{value}%', defaultValue: '--' },
                  style: { textColor: COLORS.cyan, fontSize: 20, fontWeight: 'w700' },
                },
                { id: uuid(), type: 'spacer', style: { height: 8 } },
                {
                  id: uuid(),
                  type: 'gauge',
                  gaugeType: 'radial',
                  gaugeMin: 0,
                  gaugeMax: 100,
                  gaugeColor: COLORS.cyan,
                  binding: { path: 'node.humidity' },
                  style: { width: 70, height: 70 },
                },
                { id: uuid(), type: 'spacer', style: { height: 8 } },
                {
                  id: uuid(),
                  type: 'text',
                  text: 'Humidity',
                  style: { textColor: COLORS.textSecondary, fontSize: 11, fontWeight: 'w500' },
                },
              ],
            },
            // Pressure gauge
            {
              id: uuid(),
              type: 'column',
              style: { alignment: 'center' },
              children: [
                {
                  id: uuid(),
                  type: 'text',
                  binding: { path: 'node.pressure', format: '{value}', defaultValue: '--' },
                  style: { textColor: COLORS.purple, fontSize: 20, fontWeight: 'w700' },
                },
                { id: uuid(), type: 'spacer', style: { height: 8 } },
                {
                  id: uuid(),
                  type: 'gauge',
                  gaugeType: 'radial',
                  gaugeMin: 900,
                  gaugeMax: 1100,
                  gaugeColor: COLORS.purple,
                  binding: { path: 'node.pressure' },
                  style: { width: 70, height: 70 },
                },
                { id: uuid(), type: 'spacer', style: { height: 8 } },
                {
                  id: uuid(),
                  type: 'text',
                  text: 'hPa',
                  style: { textColor: COLORS.textSecondary, fontSize: 11, fontWeight: 'w500' },
                },
              ],
            },
          ],
        },
      ],
    },
  };
}

/**
 * Network Stats - Status display with node count, messages, etc.
 */
function networkStatsWidget() {
  const now = new Date().toISOString();
  return {
    id: uuid(),
    name: 'Network Stats',
    description: 'Mesh network statistics with progress indicators',
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
    size: 'medium',
    tags: ['network', 'mesh', 'nodes', 'stats'],
    root: {
      id: uuid(),
      type: 'column',
      style: { padding: 12, spacing: 8 },
      children: [
        // Total Nodes row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Total Nodes',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'network.totalNodes', defaultValue: '0' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        {
          id: uuid(),
          type: 'gauge',
          gaugeType: 'linear',
          gaugeMin: 0,
          gaugeMax: 100,
          gaugeColor: COLORS.blue,
          binding: { path: 'network.totalNodes' },
          style: { height: 6 },
        },
        // Online Nodes row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Online Nodes',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'network.onlineNodes', defaultValue: '0' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        {
          id: uuid(),
          type: 'gauge',
          gaugeType: 'linear',
          gaugeMin: 0,
          gaugeMax: 100,
          gaugeColor: COLORS.green,
          binding: { path: 'network.onlineNodes' },
          style: { height: 6 },
        },
        // Messages row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Messages Today',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'messaging.recentCount', defaultValue: '0' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        {
          id: uuid(),
          type: 'gauge',
          gaugeType: 'linear',
          gaugeMin: 0,
          gaugeMax: 100,
          gaugeColor: COLORS.pink,
          binding: { path: 'messaging.recentCount' },
          style: { height: 6 },
        },
      ],
    },
  };
}

/**
 * GPS Tracker - Location info with coordinates
 */
function gpsTrackerWidget() {
  const now = new Date().toISOString();
  return {
    id: uuid(),
    name: 'GPS Tracker',
    description: 'Location coordinates and satellite count',
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
    size: 'medium',
    tags: ['gps', 'location', 'coordinates', 'satellite'],
    root: {
      id: uuid(),
      type: 'column',
      style: { padding: 12, spacing: 8 },
      children: [
        // Latitude row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Latitude',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.latitude', format: '{value}°', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Longitude row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Longitude',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.longitude', format: '{value}°', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Altitude row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Altitude',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.altitude', format: '{value} m', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Satellites row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Satellites',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.satsInView', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        {
          id: uuid(),
          type: 'gauge',
          gaugeType: 'linear',
          gaugeMin: 0,
          gaugeMax: 12,
          gaugeColor: COLORS.green,
          binding: { path: 'node.satsInView' },
          style: { height: 6 },
        },
      ],
    },
  };
}

/**
 * Device Info - Node name, role, hardware info
 */
function deviceInfoWidget() {
  const now = new Date().toISOString();
  return {
    id: uuid(),
    name: 'Device Info',
    description: 'Node identity and hardware details',
    version: '1.0.0',
    createdAt: now,
    updatedAt: now,
    size: 'medium',
    tags: ['device', 'node', 'info', 'hardware'],
    root: {
      id: uuid(),
      type: 'column',
      style: { padding: 12, spacing: 8 },
      children: [
        // Node Name row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Node Name',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.displayName', defaultValue: 'Unknown' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Role row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Role',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.role', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Hardware Model row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Hardware',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.hardwareModel', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
        // Firmware row
        {
          id: uuid(),
          type: 'row',
          style: { mainAxisAlignment: 'spaceBetween' },
          children: [
            {
              id: uuid(),
              type: 'text',
              text: 'Firmware',
              style: { textColor: COLORS.textSecondary, fontSize: 13 },
            },
            {
              id: uuid(),
              type: 'text',
              binding: { path: 'node.firmwareVersion', defaultValue: '--' },
              style: { textColor: COLORS.white, fontSize: 14, fontWeight: 'w600' },
            },
          ],
        },
      ],
    },
  };
}

// ============================================================================
// SEED FUNCTIONS
// ============================================================================

async function clearWidgets() {
  console.log('Clearing existing widgets...');
  const snapshot = await db.collection('widgets').get();
  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`✓ Deleted ${snapshot.size} widgets`);
}

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
  console.log('Seeding wizard-style widgets...');

  const widgets = [
    { schema: signalMonitorWidget(), category: 'charts', featured: true },
    { schema: batteryStatusWidget(), category: 'device-status', featured: true },
    { schema: environmentGaugesWidget(), category: 'metrics', featured: true },
    { schema: networkStatsWidget(), category: 'mesh', featured: true },
    { schema: gpsTrackerWidget(), category: 'location', featured: true },
    { schema: deviceInfoWidget(), category: 'device-status', featured: true },
  ];

  for (const { schema, category, featured } of widgets) {
    const widget = {
      name: schema.name,
      description: schema.description,
      author: 'Socialmesh',
      authorId: 'system',
      version: schema.version,
      tags: schema.tags,
      category,
      schema,
      status: 'published',
      featured,
      downloads: Math.floor(Math.random() * 500) + 100,
      ratingSum: Math.floor(Math.random() * 20) + 20,
      ratingCount: Math.floor(Math.random() * 5) + 5,
      averageRating: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    widget.averageRating = widget.ratingSum / widget.ratingCount;

    await db.collection('widgets').doc(schema.id).set(widget);
    console.log(`  ✓ Created: ${widget.name}`);
  }

  console.log(`✓ Created ${widgets.length} widgets`);
}

async function main() {
  try {
    console.log('🚀 Seeding Socialmesh Marketplace (v2 - Wizard Style)...\n');

    await clearWidgets();
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
