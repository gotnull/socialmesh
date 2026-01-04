#!/usr/bin/env node

/**
 * Comprehensive seed script for Device Shop
 * Seeds all mock data (sellers, products, reviews) to Firebase Firestore
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require(path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Mock data converted to JS
const sellers = [
  {
    id: 'lilygo',
    name: 'LilyGO',
    description: 'Official LilyGO store - Premium Meshtastic-compatible devices with cutting-edge LoRa technology.',
    logoUrl: 'https://picsum.photos/seed/lilygo/200/200',
    websiteUrl: 'https://lilygo.cc',
    contactEmail: 'support@lilygo.cc',
    isVerified: true,
    isOfficialPartner: true,
    rating: 4.8,
    reviewCount: 1250,
    productCount: 15,
    salesCount: 8500,
    joinedAt: admin.firestore.Timestamp.fromDate(new Date('2021-03-15')),
    countries: ['US', 'CA', 'UK', 'DE', 'AU', 'JP'],
    isActive: true,
  },
  {
    id: 'rak',
    name: 'RAK Wireless',
    description: 'RAK Wireless - Leading IoT solutions provider with professional-grade Meshtastic hardware.',
    logoUrl: 'https://picsum.photos/seed/rakwireless/200/200',
    websiteUrl: 'https://rakwireless.com',
    contactEmail: 'support@rakwireless.com',
    isVerified: true,
    isOfficialPartner: true,
    rating: 4.9,
    reviewCount: 890,
    productCount: 12,
    salesCount: 6200,
    joinedAt: admin.firestore.Timestamp.fromDate(new Date('2020-08-01')),
    countries: ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'NZ'],
    isActive: true,
  },
  {
    id: 'heltec',
    name: 'Heltec Automation',
    description: 'Heltec - Innovative LoRa solutions with integrated displays and WiFi connectivity.',
    logoUrl: 'https://picsum.photos/seed/heltec/200/200',
    websiteUrl: 'https://heltec.org',
    contactEmail: 'support@heltec.org',
    isVerified: true,
    isOfficialPartner: true,
    rating: 4.7,
    reviewCount: 720,
    productCount: 10,
    salesCount: 4800,
    joinedAt: admin.firestore.Timestamp.fromDate(new Date('2021-01-20')),
    countries: ['US', 'CA', 'UK', 'DE', 'AU'],
    isActive: true,
  },
  {
    id: 'sensecap',
    name: 'SenseCAP',
    description: 'SenseCAP by Seeed Studio - Enterprise-grade sensors and Meshtastic devices.',
    logoUrl: 'https://picsum.photos/seed/sensecap/200/200',
    websiteUrl: 'https://sensecap.seeedstudio.com',
    contactEmail: 'support@seeedstudio.com',
    isVerified: true,
    isOfficialPartner: true,
    rating: 4.8,
    reviewCount: 560,
    productCount: 8,
    salesCount: 3500,
    joinedAt: admin.firestore.Timestamp.fromDate(new Date('2022-02-10')),
    countries: ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'JP', 'KR'],
    isActive: true,
  },
  {
    id: 'rokland',
    name: 'Rokland Technologies',
    description: 'Rokland - Premium antennas and accessories for optimal Meshtastic range.',
    logoUrl: 'https://picsum.photos/seed/rokland/200/200',
    websiteUrl: 'https://rokland.com',
    contactEmail: 'support@rokland.com',
    isVerified: true,
    isOfficialPartner: true,
    rating: 4.6,
    reviewCount: 380,
    productCount: 20,
    salesCount: 2800,
    joinedAt: admin.firestore.Timestamp.fromDate(new Date('2021-06-05')),
    countries: ['US', 'CA'],
    isActive: true,
  },
  {
    id: 'muzi',
    name: 'Muzi Works',
    description: 'Custom 3D printed enclosures and cases for Meshtastic devices.',
    logoUrl: 'https://picsum.photos/seed/muzi/200/200',
    websiteUrl: 'https://muzi.works',
    contactEmail: 'hello@muzi.works',
    isVerified: true,
    isOfficialPartner: false,
    rating: 4.5,
    reviewCount: 245,
    productCount: 30,
    salesCount: 1800,
    joinedAt: admin.firestore.Timestamp.fromDate(new Date('2022-09-01')),
    countries: ['US', 'CA', 'UK', 'DE'],
    isActive: true,
  },
];

const products = [
  {
    id: 'tbeam-supreme',
    sellerId: 'lilygo',
    sellerName: 'LilyGO',
    name: 'T-Beam Supreme',
    description: `The T-Beam Supreme is LilyGO's flagship Meshtastic device, featuring the powerful ESP32-S3 processor with 16MB flash and 8MB PSRAM. 

Built with the latest SX1262 LoRa chip for excellent range and battery efficiency. Includes an integrated GPS module, 1.3" OLED display, and support for 18650 battery.

Perfect for outdoor enthusiasts, emergency preparedness, and off-grid communication.`,
    shortDescription: 'Flagship ESP32-S3 Meshtastic node with GPS and display',
    category: 'node',
    tags: ['ESP32-S3', 'SX1262', 'GPS', 'Display', 'Premium'],
    imageUrls: [
      'https://picsum.photos/seed/tbeam1/800/600',
      'https://picsum.photos/seed/tbeam2/800/600',
      'https://picsum.photos/seed/tbeam3/800/600',
    ],
    price: 54.99,
    currency: 'USD',
    compareAtPrice: 64.99,
    stockQuantity: 150,
    isInStock: true,
    isActive: true,
    isFeatured: true,
    frequencyBands: ['us915', 'eu868'],
    chipset: 'ESP32-S3',
    loraChip: 'SX1262',
    hasGps: true,
    hasDisplay: true,
    hasBluetooth: true,
    hasWifi: true,
    batteryCapacity: '18650 (not included)',
    dimensions: '100 x 35 x 20 mm',
    weight: '45g',
    includedAccessories: ['USB-C Cable', 'Antenna', 'Quick Start Guide'],
    rating: 4.8,
    reviewCount: 324,
    salesCount: 2150,
    viewCount: 15600,
    favoriteCount: 890,
    shippingCost: 5.99,
    shippingInfo: 'Ships within 1-2 business days',
    estimatedDeliveryDays: 7,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'AU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-01-15')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-12-01')),
    isMeshtasticCompatible: true,
    firmwareVersion: '2.3.x',
    hardwareVersion: '1.2',
    purchaseUrl: 'https://lilygo.cc/products/t-beam-supreme',
  },
  {
    id: 'rak-wisblock',
    sellerId: 'rak',
    sellerName: 'RAK Wireless',
    name: 'RAK WisBlock Meshtastic Kit',
    description: `Complete modular Meshtastic solution with the powerful nRF52840 processor.

The WisBlock system allows you to customize your node with various sensor modules. Kit includes base board, core module, and LoRa module.

Ultra-low power consumption makes it ideal for solar-powered installations.`,
    shortDescription: 'Modular nRF52840 kit with ultra-low power consumption',
    category: 'kit',
    tags: ['nRF52840', 'Modular', 'Low Power', 'Professional'],
    imageUrls: [
      'https://picsum.photos/seed/wisblock1/800/600',
      'https://picsum.photos/seed/wisblock2/800/600',
      'https://picsum.photos/seed/wisblock3/800/600',
      'https://picsum.photos/seed/wisblock4/800/600',
    ],
    price: 79.99,
    currency: 'USD',
    stockQuantity: 85,
    isInStock: true,
    isActive: true,
    isFeatured: true,
    frequencyBands: ['us915', 'eu868', 'au915'],
    chipset: 'nRF52840',
    loraChip: 'SX1262',
    hasGps: false,
    hasDisplay: false,
    hasBluetooth: true,
    hasWifi: false,
    batteryCapacity: '3.7V LiPo support',
    dimensions: '30 x 60 x 15 mm',
    weight: '25g',
    includedAccessories: ['Base Board', 'Core Module', 'LoRa Module', 'Antenna'],
    rating: 4.9,
    reviewCount: 186,
    salesCount: 1420,
    viewCount: 9800,
    favoriteCount: 560,
    shippingCost: 4.99,
    shippingInfo: 'Ships within 1-3 business days',
    estimatedDeliveryDays: 10,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'NZ'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-03-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-11-15')),
    isMeshtasticCompatible: true,
    firmwareVersion: '2.3.x',
    hardwareVersion: '2.0',
    purchaseUrl: 'https://store.rakwireless.com/products/wisblock-meshtastic-kit',
  },
  {
    id: 'heltec-v3',
    sellerId: 'heltec',
    sellerName: 'Heltec Automation',
    name: 'Heltec LoRa 32 V3',
    description: `The Heltec LoRa 32 V3 is an affordable yet capable Meshtastic node.

Features ESP32-S3, built-in 0.96" OLED display, and SX1262 LoRa chip. Compact design perfect for portable use.

Great entry-level device for those new to Meshtastic.`,
    shortDescription: 'Affordable ESP32-S3 node with built-in display',
    category: 'node',
    tags: ['ESP32-S3', 'SX1262', 'Display', 'Budget', 'Beginner'],
    imageUrls: [
      'https://picsum.photos/seed/heltecv3a/800/600',
      'https://picsum.photos/seed/heltecv3b/800/600',
    ],
    price: 19.99,
    currency: 'USD',
    stockQuantity: 280,
    isInStock: true,
    isActive: true,
    isFeatured: true,
    frequencyBands: ['us915', 'eu868'],
    chipset: 'ESP32-S3',
    loraChip: 'SX1262',
    hasGps: false,
    hasDisplay: true,
    hasBluetooth: true,
    hasWifi: true,
    dimensions: '50 x 25 x 10 mm',
    weight: '15g',
    includedAccessories: ['Antenna', 'Pin Headers'],
    rating: 4.6,
    reviewCount: 512,
    salesCount: 3800,
    viewCount: 22000,
    favoriteCount: 1200,
    shippingCost: 3.99,
    shippingInfo: 'Ships within 1-2 business days',
    estimatedDeliveryDays: 8,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'AU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2023-09-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-20')),
    isMeshtasticCompatible: true,
    firmwareVersion: '2.3.x',
    hardwareVersion: '3.0',
    purchaseUrl: 'https://heltec.org/project/wifi-lora-32-v3/',
  },
  {
    id: 'sensecap-card',
    sellerId: 'sensecap',
    sellerName: 'SenseCAP',
    name: 'SenseCAP Card Tracker T1000-E',
    description: `Ultra-compact credit card sized Meshtastic tracker.

Perfect for asset tracking, pet tracking, or personal safety. Features GPS, temperature sensor, and up to 2 weeks battery life.

Waterproof IP65 rated for outdoor use.`,
    shortDescription: 'Credit card sized GPS tracker with 2-week battery',
    category: 'node',
    tags: ['Tracker', 'GPS', 'Compact', 'Waterproof', 'Battery'],
    imageUrls: [
      'https://picsum.photos/seed/sensecap1/800/600',
      'https://picsum.photos/seed/sensecap2/800/600',
      'https://picsum.photos/seed/sensecap3/800/600',
    ],
    price: 39.99,
    currency: 'USD',
    stockQuantity: 120,
    isInStock: true,
    isActive: true,
    isFeatured: true,
    frequencyBands: ['us915', 'eu868'],
    chipset: 'nRF52840',
    loraChip: 'LR1110',
    hasGps: true,
    hasDisplay: false,
    hasBluetooth: true,
    hasWifi: false,
    batteryCapacity: '700mAh',
    dimensions: '85 x 55 x 6.5 mm',
    weight: '32g',
    includedAccessories: ['USB-C Cable', 'Lanyard'],
    rating: 4.7,
    reviewCount: 89,
    salesCount: 650,
    viewCount: 8500,
    favoriteCount: 420,
    shippingCost: 4.99,
    estimatedDeliveryDays: 7,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'JP'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-06-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-11-28')),
    isMeshtasticCompatible: true,
    firmwareVersion: '2.3.x',
    hardwareVersion: '1.0',
    purchaseUrl: 'https://sensecap.seeedstudio.com/product/sensecap-t1000-e',
  },
  {
    id: 'rokland-5dbi',
    sellerId: 'rokland',
    sellerName: 'Rokland Technologies',
    name: '915MHz 5.8dBi Fiberglass Antenna',
    description: `Professional-grade fiberglass antenna for maximum range.

5.8dBi gain provides excellent range for base station setups. UV-resistant fiberglass construction for outdoor durability.

Includes mounting bracket and N-type to SMA adapter.`,
    shortDescription: 'High-gain 5.8dBi outdoor fiberglass antenna',
    category: 'antenna',
    tags: ['High Gain', 'Outdoor', 'Fiberglass', '915MHz'],
    imageUrls: [
      'https://picsum.photos/seed/antenna1/800/600',
      'https://picsum.photos/seed/antenna2/800/600',
    ],
    price: 34.99,
    currency: 'USD',
    stockQuantity: 200,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    frequencyBands: ['us915'],
    rating: 4.8,
    reviewCount: 156,
    salesCount: 890,
    viewCount: 5600,
    favoriteCount: 280,
    shippingCost: 6.99,
    estimatedDeliveryDays: 5,
    shipsTo: ['US', 'CA'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2023-05-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-08-15')),
    dimensions: '400 x 25 mm',
    weight: '180g',
    includedAccessories: ['Mounting Bracket', 'N-SMA Adapter'],
  },
  {
    id: 'rokland-868',
    sellerId: 'rokland',
    sellerName: 'Rokland Technologies',
    name: '868MHz 6dBi Omni Antenna',
    description: `European frequency band outdoor antenna.

6dBi omnidirectional gain for 360° coverage. Perfect for rooftop or balcony installations.`,
    shortDescription: 'EU 868MHz 6dBi omnidirectional antenna',
    category: 'antenna',
    tags: ['High Gain', 'Outdoor', '868MHz', 'EU'],
    imageUrls: [
      'https://picsum.photos/seed/antenna868a/800/600',
      'https://picsum.photos/seed/antenna868b/800/600',
    ],
    price: 39.99,
    currency: 'USD',
    stockQuantity: 85,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    frequencyBands: ['eu868'],
    rating: 4.7,
    reviewCount: 78,
    salesCount: 420,
    viewCount: 3200,
    favoriteCount: 150,
    shippingCost: 7.99,
    estimatedDeliveryDays: 10,
    shipsTo: ['UK', 'DE', 'FR', 'EU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2023-07-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-20')),
    dimensions: '450 x 28 mm',
    weight: '210g',
    includedAccessories: ['Mounting Hardware', 'Adapter Cable'],
  },
  {
    id: 'stubby-antenna',
    sellerId: 'lilygo',
    sellerName: 'LilyGO',
    name: 'Compact Stubby Antenna 915MHz',
    description: `Compact rubber duck antenna for portable use.

2dBi gain in a small form factor. Perfect for handheld devices and mobile setups.`,
    shortDescription: 'Small 2dBi antenna for portable nodes',
    category: 'antenna',
    tags: ['Compact', 'Portable', '915MHz', 'Budget'],
    imageUrls: ['https://picsum.photos/seed/stubby1/800/600'],
    price: 4.99,
    currency: 'USD',
    stockQuantity: 500,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    frequencyBands: ['us915'],
    rating: 4.3,
    reviewCount: 245,
    salesCount: 2100,
    viewCount: 8900,
    favoriteCount: 380,
    shippingCost: 2.99,
    estimatedDeliveryDays: 7,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'AU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2023-01-15')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-06-01')),
    dimensions: '50 x 10 mm',
    weight: '8g',
  },
  {
    id: 'muzi-tbeam-case',
    sellerId: 'muzi',
    sellerName: 'Muzi Works',
    name: 'T-Beam Rugged Outdoor Case',
    description: `Weatherproof 3D printed case for T-Beam devices.

IP67 rated with cable gland for antenna. Includes belt clip and lanyard attachment points.

Available in multiple colors. Made from UV-resistant PETG.`,
    shortDescription: 'IP67 weatherproof case for T-Beam',
    category: 'enclosure',
    tags: ['Weatherproof', 'T-Beam', 'Outdoor', '3D Printed'],
    imageUrls: [
      'https://picsum.photos/seed/case1/800/600',
      'https://picsum.photos/seed/case2/800/600',
      'https://picsum.photos/seed/case3/800/600',
    ],
    price: 24.99,
    currency: 'USD',
    stockQuantity: 75,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    rating: 4.6,
    reviewCount: 89,
    salesCount: 340,
    viewCount: 4200,
    favoriteCount: 180,
    shippingCost: 4.99,
    estimatedDeliveryDays: 7,
    shipsTo: ['US', 'CA', 'UK', 'DE'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-02-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-11-10')),
    dimensions: '120 x 80 x 35 mm',
    weight: '65g',
    includedAccessories: ['Cable Gland', 'Mounting Screws', 'Belt Clip'],
  },
  {
    id: 'muzi-heltec-case',
    sellerId: 'muzi',
    sellerName: 'Muzi Works',
    name: 'Heltec V3 Pocket Case',
    description: `Compact protective case for Heltec V3 nodes.

Slim design fits in your pocket. Clear window for display visibility. Includes wrist strap.`,
    shortDescription: 'Slim pocket case for Heltec V3',
    category: 'enclosure',
    tags: ['Heltec', 'Compact', 'Protective', 'Portable'],
    imageUrls: [
      'https://picsum.photos/seed/hcase1/800/600',
      'https://picsum.photos/seed/hcase2/800/600',
    ],
    price: 14.99,
    currency: 'USD',
    stockQuantity: 120,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    rating: 4.4,
    reviewCount: 67,
    salesCount: 280,
    viewCount: 3100,
    favoriteCount: 120,
    shippingCost: 3.99,
    estimatedDeliveryDays: 7,
    shipsTo: ['US', 'CA', 'UK', 'DE'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-04-15')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-01')),
    dimensions: '65 x 35 x 18 mm',
    weight: '25g',
    includedAccessories: ['Wrist Strap'],
  },
  {
    id: 'usb-cable',
    sellerId: 'lilygo',
    sellerName: 'LilyGO',
    name: 'USB-C Data Cable 1m',
    description: `High-quality USB-C cable for programming and charging.

Supports data transfer up to 480Mbps. Durable braided nylon construction.`,
    shortDescription: 'Premium USB-C cable for Meshtastic devices',
    category: 'accessory',
    tags: ['USB-C', 'Cable', 'Charging', 'Data'],
    imageUrls: ['https://picsum.photos/seed/cable1/800/600'],
    price: 6.99,
    currency: 'USD',
    stockQuantity: 350,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    rating: 4.5,
    reviewCount: 189,
    salesCount: 1450,
    viewCount: 5600,
    favoriteCount: 220,
    shippingCost: 2.99,
    estimatedDeliveryDays: 5,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'AU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2023-03-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-05-15')),
    dimensions: '1000 x 5 mm',
    weight: '35g',
  },
  {
    id: 'battery-18650',
    sellerId: 'lilygo',
    sellerName: 'LilyGO',
    name: '18650 Battery 3400mAh',
    description: `High-capacity protected 18650 battery.

3400mAh capacity with built-in protection circuit. Perfect for T-Beam devices.

Note: Cannot ship via air freight.`,
    shortDescription: 'High-capacity 18650 battery for T-Beam',
    category: 'accessory',
    tags: ['Battery', '18650', 'Power', 'Protected'],
    imageUrls: ['https://picsum.photos/seed/battery1/800/600'],
    price: 8.99,
    currency: 'USD',
    compareAtPrice: 12.99,
    stockQuantity: 180,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    batteryCapacity: '3400mAh',
    rating: 4.7,
    reviewCount: 234,
    salesCount: 1890,
    viewCount: 7800,
    favoriteCount: 450,
    shippingCost: 4.99,
    shippingInfo: 'Ground shipping only - no air freight',
    estimatedDeliveryDays: 10,
    shipsTo: ['US'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2023-02-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-07-20')),
    dimensions: '65 x 18 mm',
    weight: '48g',
  },
  {
    id: 'solar-panel-6w',
    sellerId: 'rak',
    sellerName: 'RAK Wireless',
    name: 'Solar Panel 6W with Controller',
    description: `6W solar panel kit for off-grid Meshtastic nodes.

Includes MPPT charge controller optimized for LiPo batteries. Weather-resistant design for permanent outdoor installation.`,
    shortDescription: '6W solar kit with MPPT controller',
    category: 'solar',
    tags: ['Solar', 'Off-grid', 'MPPT', 'Outdoor'],
    imageUrls: [
      'https://picsum.photos/seed/solar1/800/600',
      'https://picsum.photos/seed/solar2/800/600',
    ],
    price: 45.99,
    currency: 'USD',
    stockQuantity: 60,
    isInStock: true,
    isActive: true,
    isFeatured: true,
    rating: 4.8,
    reviewCount: 56,
    salesCount: 280,
    viewCount: 4500,
    favoriteCount: 190,
    shippingCost: 8.99,
    estimatedDeliveryDays: 10,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'AU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-05-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-11-05')),
    dimensions: '280 x 180 x 25 mm',
    weight: '450g',
    includedAccessories: ['MPPT Controller', 'Mounting Bracket', 'Cables'],
  },
  {
    id: 'gps-module',
    sellerId: 'lilygo',
    sellerName: 'LilyGO',
    name: 'GPS Module L76K',
    description: `High-sensitivity GPS module for position tracking.

Compatible with T-Beam and other ESP32 boards. Includes ceramic antenna for reliable reception.`,
    shortDescription: 'Add GPS capability to your node',
    category: 'module',
    tags: ['GPS', 'Module', 'L76K', 'Add-on'],
    imageUrls: ['https://picsum.photos/seed/gps1/800/600'],
    price: 12.99,
    currency: 'USD',
    stockQuantity: 95,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    hasGps: true,
    rating: 4.5,
    reviewCount: 78,
    salesCount: 420,
    viewCount: 3400,
    favoriteCount: 150,
    shippingCost: 3.99,
    estimatedDeliveryDays: 7,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'AU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2023-08-01')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-04-15')),
    dimensions: '25 x 25 x 8 mm',
    weight: '12g',
    includedAccessories: ['Ceramic Antenna', 'Connector Cable'],
  },
  {
    id: 'display-module',
    sellerId: 'heltec',
    sellerName: 'Heltec Automation',
    name: 'E-Ink Display Module 2.13"',
    description: `Low-power e-ink display for always-on status.

Perfect for solar-powered nodes. Excellent visibility in direct sunlight.`,
    shortDescription: 'E-Ink display for low-power nodes',
    category: 'module',
    tags: ['E-Ink', 'Display', 'Low Power', 'Module'],
    imageUrls: [
      'https://picsum.photos/seed/eink1/800/600',
      'https://picsum.photos/seed/eink2/800/600',
    ],
    price: 18.99,
    currency: 'USD',
    compareAtPrice: 24.99,
    stockQuantity: 45,
    isInStock: true,
    isActive: true,
    isFeatured: false,
    hasDisplay: true,
    rating: 4.4,
    reviewCount: 34,
    salesCount: 180,
    viewCount: 2800,
    favoriteCount: 95,
    shippingCost: 4.99,
    estimatedDeliveryDays: 8,
    shipsTo: ['US', 'CA', 'UK', 'DE', 'AU'],
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-01-10')),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-01')),
    dimensions: '60 x 30 x 5 mm',
    weight: '18g',
    includedAccessories: ['FPC Cable'],
  },
];

const reviews = [
  {
    id: 'review-1',
    productId: 'tbeam-supreme',
    userId: 'user-1',
    userName: 'MeshEnthusiast',
    rating: 5,
    title: "Best Meshtastic device I've owned!",
    body: 'The T-Beam Supreme exceeded my expectations. GPS lock is fast, display is crisp, and battery life is excellent. Setup was straightforward with the Meshtastic app.',
    isVerifiedPurchase: true,
    helpfulCount: 45,
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-11-15')),
  },
  {
    id: 'review-2',
    productId: 'tbeam-supreme',
    userId: 'user-2',
    userName: 'HikerJoe',
    rating: 5,
    title: 'Perfect for hiking trips',
    body: 'Used this on a 3-day hiking trip. Battery lasted the entire time with GPS on. Could communicate with my group even when we were several km apart in the mountains.',
    isVerifiedPurchase: true,
    helpfulCount: 32,
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-28')),
  },
  {
    id: 'review-3',
    productId: 'tbeam-supreme',
    userId: 'user-3',
    userName: 'TechReviewer42',
    rating: 4,
    title: 'Great device, minor issues',
    body: "Overall a great device. The only reason I'm giving 4 stars is the plastic case feels a bit flimsy. Consider getting a protective case. Performance-wise, it's excellent.",
    isVerifiedPurchase: true,
    helpfulCount: 18,
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-09-05')),
  },
  {
    id: 'review-4',
    productId: 'heltec-v3',
    userId: 'user-4',
    userName: 'BudgetMesher',
    rating: 5,
    title: 'Amazing value for money',
    body: "For $20, you can't beat this! Yes, it doesn't have GPS, but for a home base station or testing, it's perfect. Works great with Meshtastic.",
    isVerifiedPurchase: true,
    helpfulCount: 67,
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-11-01')),
  },
  {
    id: 'review-5',
    productId: 'heltec-v3',
    userId: 'user-5',
    userName: 'RadioHam',
    rating: 4,
    title: 'Good starter device',
    body: 'Perfect for beginners. Easy to flash and configure. Display is small but readable. Would recommend adding an external antenna for better range.',
    isVerifiedPurchase: true,
    helpfulCount: 28,
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-10-15')),
  },
  {
    id: 'review-6',
    productId: 'rak-wisblock',
    userId: 'user-6',
    userName: 'ProMaker',
    rating: 5,
    title: 'Professional quality',
    body: "The modular design is fantastic. I've added GPS, environmental sensors, and a larger battery. Battery life is incredible - my solar node has been running for months without issues.",
    isVerifiedPurchase: true,
    helpfulCount: 54,
    createdAt: admin.firestore.Timestamp.fromDate(new Date('2024-08-20')),
  },
];

async function seedAllData() {
  console.log('🚀 Starting comprehensive Device Shop seed...');

  try {
    const batch = db.batch();
    let batchCount = 0;

    // Seed sellers
    console.log(`\n📦 Seeding ${sellers.length} sellers...`);
    for (const seller of sellers) {
      const ref = db.collection('shopSellers').doc(seller.id);
      batch.set(ref, seller);
      batchCount++;
      console.log(`  ✓ ${seller.name}`);
    }

    // Seed products
    console.log(`\n📦 Seeding ${products.length} products...`);
    for (const product of products) {
      const ref = db.collection('shopProducts').doc(product.id);
      batch.set(ref, product);
      batchCount++;
      console.log(`  ✓ ${product.name} (${product.category})`);
    }

    // Commit batch (sellers + products)
    if (batchCount > 0) {
      await batch.commit();
      console.log(`\n✅ Committed batch with ${batchCount} documents`);
    }

    // Seed reviews (top-level collection for easier querying)
    console.log(`\n📦 Seeding ${reviews.length} reviews...`);
    const reviewBatch = db.batch();
    for (const review of reviews) {
      // Reviews go in top-level collection
      const ref = db.collection('productReviews').doc(review.id);
      reviewBatch.set(ref, review);
      console.log(`  ✓ Review for ${review.productId} by ${review.userName}`);
    }

    await reviewBatch.commit();
    console.log('\n✅ Reviews committed');

    console.log('\n🎉 ALL DATA SEEDED SUCCESSFULLY!');
    console.log(`   - ${sellers.length} sellers`);
    console.log(`   - ${products.length} products`);
    console.log(`   - ${reviews.length} reviews`);
    console.log('\n💡 You can now edit this data in Firebase Console before going live.');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error seeding data:', error);
    process.exit(1);
  }
}

seedAllData();
