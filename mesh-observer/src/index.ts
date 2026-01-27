/**
 * Mesh Observer - Meshtastic MQTT Node Collector
 * 
 * This service connects to the Meshtastic public MQTT broker,
 * collects node position and telemetry data, and serves it via REST API.
 * 
 * Part of Socialmesh
 */

import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import * as admin from 'firebase-admin';
import { MqttObserver } from './mqtt-observer';
import { NodeStore } from './node-store';
import { generateMapPage } from './map-page';

const PORT = parseInt(process.env.PORT || '3001', 10);
const MQTT_BROKER = process.env.MQTT_BROKER || 'mqtt://mqtt.meshtastic.org';
// Subscribe ONLY to map topics to reduce volume - these contain pre-processed node data
// The 'e/' (encrypted) topics are extremely high volume and would overwhelm the service
const MQTT_TOPICS = (process.env.MQTT_TOPICS || [
  // Map reports contain node position and info already decoded
  'msh/+/2/map/#',
  'msh/+/+/2/map/#',
  'msh/+/+/+/2/map/#',
  'msh/+/+/+/+/2/map/#',
  // JSON topics have decoded data (lower volume than encrypted)
  'msh/+/2/json/+/+',
  'msh/+/+/2/json/+/+',
].join(',')).split(',');
const MQTT_USERNAME = process.env.MQTT_USERNAME || 'meshdev';
const MQTT_PASSWORD = process.env.MQTT_PASSWORD || 'large4cats';
const NODE_EXPIRY_HOURS = parseInt(process.env.NODE_EXPIRY_HOURS || '24', 10);
const NODE_PURGE_DAYS = parseInt(process.env.NODE_PURGE_DAYS || '30', 10);
const MAP_ALLOWED_HOSTS = (process.env.MAP_ALLOWED_HOSTS ||
  'map.socialmesh.app')
  .split(',')
  .map((host) => host.trim())
  .filter(Boolean);

// Firebase Admin initialization
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'social-mesh-app';
const FIREBASE_CLIENT_EMAIL = process.env.FIREBASE_CLIENT_EMAIL;
const FIREBASE_PRIVATE_KEY = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

let firebaseInitialized = false;

if (FIREBASE_CLIENT_EMAIL && FIREBASE_PRIVATE_KEY) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: FIREBASE_PROJECT_ID,
        clientEmail: FIREBASE_CLIENT_EMAIL,
        privateKey: FIREBASE_PRIVATE_KEY,
      }),
    });
    firebaseInitialized = true;
    console.log('Firebase Admin SDK initialized successfully');
  } catch (error) {
    console.error('Firebase Admin SDK initialization failed:', error);
  }
} else {
  console.warn('Firebase credentials not provided - API auth disabled (development mode)');
}

// Extended request type with user info
interface AuthenticatedRequest extends Request {
  user?: admin.auth.DecodedIdToken;
}

// Firebase Auth middleware for protected routes
const requireAuth = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  // Skip auth in development mode if Firebase not configured
  if (!firebaseInitialized) {
    return next();
  }

  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid Authorization header. Use: Bearer <firebase_id_token>'
    });
  }

  const idToken = authHeader.split('Bearer ')[1];

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('Token verification failed:', error);
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid or expired token'
    });
  }
};

const app = express();

// Security headers
app.use(helmet({
  contentSecurityPolicy: false, // Allow API responses
  crossOriginEmbedderPolicy: false,
}));

// Gzip compression for responses
app.use(compression());

// Trust proxy (Railway runs behind proxy)
app.set('trust proxy', 1);

app.use(cors());
app.use(express.json({ limit: '1mb' })); // Limit body size

// Rate limiting - 100 requests per minute per IP
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100, // 100 requests per minute
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
});
app.use(limiter);

// Request logging
app.use((req: Request, _res: Response, next: NextFunction) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Initialize node store
const nodeStore = new NodeStore(NODE_EXPIRY_HOURS);

// Initialize MQTT observer with credentials (multiple topics)
const mqttObserver = new MqttObserver(
  MQTT_BROKER,
  MQTT_TOPICS,
  nodeStore,
  MQTT_USERNAME,
  MQTT_PASSWORD
);

// API Documentation (root endpoint)
app.get('/', (req, res) => {
  const host = req.headers.host || '';
  if (MAP_ALLOWED_HOSTS.some((allowedHost) => host.includes(allowedHost))) {
    const mapHtml = generateMapPage();
    return res.type('html').send(mapHtml);
  }
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Socialmesh API — Real-time Meshtastic Mesh Data</title>
  <meta name="description" content="Real-time Meshtastic mesh network data API. Access global node positions, telemetry, and network statistics.">
  
  <!-- Smart App Banner (iOS Safari) -->
  <meta name="apple-itunes-app" content="app-id=6742694642">
  
  <!-- Favicon -->
  <link rel="icon" type="image/png" href="https://socialmesh.app/favicon.png">
  
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
  <style>
    :root {
      --bg-primary: #1F2633;
      --bg-secondary: #29303D;
      --bg-card: #29303D;
      --border-color: #414A5A;
      --accent-magenta: #E91E8C;
      --accent-purple: #8B5CF6;
      --accent-blue: #4F6AF6;
      --success: #4ADE80;
      --text-primary: #FFFFFF;
      --text-secondary: #D1D5DB;
      --text-muted: #9CA3AF;
      --gradient-brand: linear-gradient(135deg, #E91E8C 0%, #8B5CF6 50%, #4F6AF6 100%);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { 
      font-family: 'JetBrains Mono', 'Inter', -apple-system, BlinkMacSystemFont, monospace;
      background: var(--bg-primary);
      color: var(--text-primary);
      min-height: 100vh;
      line-height: 1.6;
    }
    /* Animated mesh background */
    .mesh-bg {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: -1;
      overflow: hidden;
      background: var(--bg-primary);
    }
    .mesh-bg::before {
      content: '';
      position: absolute;
      top: -50%; left: -50%;
      width: 200%; height: 200%;
      background:
        radial-gradient(circle at 20% 20%, rgba(233, 30, 140, 0.15) 0%, transparent 40%),
        radial-gradient(circle at 80% 80%, rgba(139, 92, 246, 0.12) 0%, transparent 40%),
        radial-gradient(circle at 60% 30%, rgba(79, 106, 246, 0.1) 0%, transparent 35%);
      animation: meshFloat 25s ease-in-out infinite;
    }
    @keyframes meshFloat {
      0%, 100% { transform: translate(0, 0) rotate(0deg); }
      25% { transform: translate(3%, 2%) rotate(2deg); }
      50% { transform: translate(1%, -2%) rotate(-1deg); }
      75% { transform: translate(-2%, 1%) rotate(1deg); }
    }
    .grid-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: -1;
      background-image:
        linear-gradient(rgba(233, 30, 140, 0.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(233, 30, 140, 0.03) 1px, transparent 1px);
      background-size: 80px 80px;
      mask-image: radial-gradient(ellipse at center, black 0%, transparent 75%);
    }
    /* Navigation */
    nav {
      position: fixed;
      top: 0; left: 0; right: 0;
      z-index: 1000;
      padding: 16px 0;
      background: rgba(10, 10, 15, 0.8);
      backdrop-filter: blur(20px);
      border-bottom: 1px solid rgba(42, 42, 58, 0.5);
    }
    nav .container {
      display: flex;
      justify-content: space-between;
      align-items: center;
      max-width: 1200px;
      margin: 0 auto;
      padding: 0 24px;
    }
    .logo {
      display: flex;
      align-items: center;
      gap: 12px;
      text-decoration: none;
    }
    .logo-img {
      width: 40px; height: 40px;
      border-radius: 10px;
      box-shadow: 0 4px 20px rgba(233, 30, 140, 0.3);
      animation: logoGlow 3s ease-in-out infinite alternate;
    }
    @keyframes logoGlow {
      0% { box-shadow: 0 4px 20px rgba(233, 30, 140, 0.3); }
      100% { box-shadow: 0 4px 30px rgba(233, 30, 140, 0.5); }
    }
    .logo-text {
      font-size: 22px;
      font-weight: 700;
      color: var(--text-primary);
      letter-spacing: -0.5px;
    }
    .nav-links {
      display: flex;
      gap: 32px;
      list-style: none;
      margin: 0; padding: 0;
    }
    .nav-links a {
      color: var(--text-secondary);
      text-decoration: none;
      font-size: 14px;
      font-weight: 500;
      transition: color 0.2s;
    }
    .nav-links a:hover { color: var(--text-primary); }
    .nav-cta { display: flex; gap: 12px; }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 12px 24px;
      border-radius: 12px;
      font-size: 14px;
      font-weight: 600;
      text-decoration: none;
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      cursor: pointer;
      border: none;
      position: relative;
      overflow: hidden;
    }
    .btn-icon { width: 18px; height: 18px; fill: currentColor; flex-shrink: 0; vertical-align: middle; display: inline-block; margin-top: -2px; margin-left: 8px; }
    .btn-primary {
      background: var(--gradient-brand);
      color: white;
      box-shadow: 0 4px 20px rgba(233, 30, 140, 0.3);
    }
    .btn-primary::before {
      content: '';
      position: absolute;
      top: 0; left: -100%;
      width: 100%; height: 100%;
      background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
      transition: left 0.5s;
    }
    .btn-primary:hover {
      transform: translateY(-3px);
      box-shadow: 0 8px 35px rgba(233, 30, 140, 0.4);
    }
    .btn-primary:hover::before { left: 100%; }
    
    /* Mobile menu */
    .menu-toggle {
      display: none;
      background: none;
      border: none;
      cursor: pointer;
      padding: 8px;
      z-index: 1001;
    }
    .menu-toggle svg {
      width: 24px; height: 24px;
      fill: var(--text-primary);
    }
    
    .mobile-menu {
      position: fixed;
      top: 73px; left: 0; right: 0;
      background: var(--bg-primary);
      border-bottom: 1px solid rgba(42, 42, 58, 0.5);
      padding: 24px;
      z-index: 999;
      display: none;
    }
    .mobile-menu ul {
      list-style: none;
      margin: 0; padding: 0;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .mobile-menu a {
      color: var(--text-secondary);
      text-decoration: none;
      font-size: 16px;
      font-weight: 500;
      display: block;
      padding: 12px 0;
      transition: color 0.2s;
      border-bottom: 1px solid var(--border-color);
    }
    .mobile-menu a:hover { color: var(--text-primary); }
    .mobile-menu .btn {
      margin-top: 16px;
      justify-content: center;
      width: 100%;
    }
    
    /* Mobile responsive */
    @media (max-width: 768px) {
      .nav-links, .nav-cta { display: none; }
      .menu-toggle { display: block; }
    }
    
    .main-container { max-width: 900px; margin: 0 auto; padding: 120px 24px 60px; }
    .header { text-align: center; margin-bottom: 60px; }
    h1 { 
      font-size: 3rem; 
      font-weight: 700;
      margin-bottom: 16px;
      letter-spacing: -1px;
    }
    .gradient-text {
      background: var(--gradient-brand);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .subtitle { 
      color: var(--text-secondary); 
      font-size: 1.1rem;
      max-width: 600px;
      margin: 0 auto 32px;
    }
    .status { 
      display: inline-flex; 
      align-items: center; 
      gap: 10px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      padding: 12px 24px;
      border-radius: 100px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 14px;
    }
    .status-dot { 
      width: 10px; height: 10px; 
      background: var(--success); 
      border-radius: 50%;
      box-shadow: 0 0 12px var(--success);
      animation: pulse 2s infinite;
    }
    @keyframes pulse { 
      0%, 100% { opacity: 1; box-shadow: 0 0 12px var(--success); } 
      50% { opacity: 0.7; box-shadow: 0 0 20px var(--success); } 
    }
    .endpoints { margin-bottom: 48px; }
    .section-title {
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 2px;
      color: var(--accent-magenta);
      margin-bottom: 24px;
    }
    .endpoint { 
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 16px;
      transition: all 0.3s ease;
    }
    .endpoint:hover {
      border-color: var(--accent-purple);
      box-shadow: 0 8px 32px rgba(139, 92, 246, 0.15);
      transform: translateY(-2px);
    }
    .endpoint-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
    .method { 
      background: var(--gradient-brand);
      color: white;
      font-family: 'JetBrains Mono', monospace;
      font-weight: 600;
      padding: 6px 14px;
      border-radius: 8px;
      font-size: 12px;
    }
    .path { 
      font-family: 'JetBrains Mono', monospace;
      color: var(--text-primary);
      font-size: 1rem;
      font-weight: 500;
    }
    .path a { 
      color: var(--text-primary); 
      text-decoration: none;
      transition: color 0.2s;
    }
    .path a:hover { color: var(--accent-magenta); }
    .desc { color: var(--text-secondary); font-size: 14px; line-height: 1.7; }
    .example { 
      background: var(--bg-primary);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 16px;
      margin-top: 16px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      overflow-x: auto;
    }
    .example-label { 
      color: var(--text-muted); 
      font-size: 11px; 
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 8px; 
    }
    .example code { color: var(--text-secondary); }
    .example pre { margin: 0; white-space: pre; line-height: 1.6; }
    .example .key { color: var(--accent-magenta); }
    .example .value { color: var(--accent-purple); }
    .example .number { color: var(--accent-blue); }
    .example .method-text { color: var(--accent-magenta); font-weight: 600; }
    .schema-section { margin-top: 48px; }
    .schema-code {
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 24px;
    }
    .schema-code pre {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      color: var(--text-secondary);
      line-height: 1.8;
      white-space: pre;
      overflow-x: auto;
    }
    .schema-code .comment { color: var(--text-muted); }
    .schema-code .key { color: var(--accent-magenta); }
    .schema-code .value { color: var(--accent-purple); }
    .schema-code .number { color: var(--accent-blue); }
    .footer { 
      text-align: center; 
      padding-top: 48px;
      border-top: 1px solid var(--border-color);
      color: var(--text-muted);
      font-size: 14px;
    }
    .footer a { 
      color: var(--accent-magenta); 
      text-decoration: none;
      transition: color 0.2s;
    }
    .footer a:hover { color: var(--accent-purple); }
    .footer-links { 
      display: flex; 
      justify-content: center; 
      gap: 24px; 
      margin-bottom: 16px;
    }
    .rate-limit {
      display: inline-block;
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      padding: 8px 16px;
      border-radius: 8px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      margin-top: 16px;
    }
  </style>
</head>
<body>
  <div class="mesh-bg"></div>
  <div class="grid-overlay"></div>
  
  <!-- Navigation -->
  <nav>
    <div class="container">
      <a href="https://socialmesh.app" class="logo">
        <img src="https://socialmesh.app/images/app-icon.png" alt="Socialmesh" class="logo-img">
        <span class="logo-text">Socialmesh</span>
      </a>
      
      <ul class="nav-links">
        <li><a href="https://socialmesh.app#features">Features</a></li>
        <li><a href="https://socialmesh.app#premium">Extras</a></li>
        <li><a href="https://socialmesh.app#screenshots">Screenshots</a></li>
        <li><a href="https://socialmesh.app#comparison">Compare</a></li>
        <li><a href="https://socialmesh.app/docs">Docs</a></li>
        <li><a href="https://socialmesh.app/faq">FAQ</a></li>
      </ul>
      
      <div class="nav-cta">
        <a href="https://socialmesh.app#download" class="btn btn-primary">
          <svg class="btn-icon" viewBox="0 0 24 24">
            <path d="M5 20h14v-2H5v2zM19 9h-4V3H9v6H5l7 7 7-7z" />
          </svg>
          Download
        </a>
      </div>
      
      <button class="menu-toggle" onclick="toggleMenu()" aria-label="Toggle menu">
        <svg viewBox="0 0 24 24"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/></svg>
      </button>
    </div>
  </nav>
  
  <!-- Mobile Menu -->
  <div class="mobile-menu" id="mobileMenu" style="display: none;">
    <ul>
      <li><a href="https://socialmesh.app#features" onclick="toggleMenu()">Features</a></li>
      <li><a href="https://socialmesh.app#premium" onclick="toggleMenu()">Extras</a></li>
      <li><a href="https://socialmesh.app#screenshots" onclick="toggleMenu()">Screenshots</a></li>
      <li><a href="https://socialmesh.app#comparison" onclick="toggleMenu()">Compare</a></li>
      <li><a href="https://socialmesh.app/docs" onclick="toggleMenu()">Docs</a></li>
      <li><a href="https://socialmesh.app/faq" onclick="toggleMenu()">FAQ</a></li>
    </ul>
    <a href="https://socialmesh.app#download" class="btn btn-primary" onclick="toggleMenu()">
      <svg class="btn-icon" viewBox="0 0 24 24"><path d="M5 20h14v-2H5v2zM19 9h-4V3H9v6H5l7 7 7-7z"/></svg>
      Download
    </a>
  </div>
  
  <script>
    function toggleMenu() {
      var menu = document.getElementById('mobileMenu');
      var isOpen = menu.style.display === 'block';
      menu.style.display = isOpen ? 'none' : 'block';
    }
  </script>
  
  <div class="main-container">
    <header class="header">
      <h1>Mesh Network <span class="gradient-text">Backend</span></h1>
      <p class="subtitle">This is the backend service powering the <a href="https://socialmesh.app" style="color: var(--accent-magenta);">Socialmesh app</a>. It collects real-time Meshtastic mesh network data from the global MQTT feed.</p>
      
      <div class="status">
        <span class="status-dot"></span>
        <span>Live • ${nodeStore.getValidNodeCount()} nodes • ${nodeStore.getOnlineNodeCount()} online</span>
      </div>
    </header>

    <section class="endpoints">
      <div class="section-title" style="margin-bottom: 16px;"><span class="material-icons" style="font-size: 20px; vertical-align: middle; margin-right: 8px;">public</span>Public Access</div>
      
      <div class="endpoint" style="border-left: 3px solid var(--success);">
        <div class="endpoint-header">
          <span class="method" style="background: var(--success);">GET</span>
          <span class="path"><a href="/map">/map</a></span>
          <span style="color: var(--success); font-size: 12px; margin-left: auto; display: flex; align-items: center; gap: 4px;"><span class="material-icons" style="font-size: 14px;">check_circle</span>No auth required</span>
        </div>
        <p class="desc">Interactive world map showing all tracked mesh nodes. Explore the global Meshtastic network in real-time!</p>
      </div>

      <div class="endpoint" style="border-left: 3px solid var(--success);">
        <div class="endpoint-header">
          <span class="method" style="background: var(--success);">GET</span>
          <span class="path"><a href="/health">/health</a></span>
          <span style="color: var(--success); font-size: 12px; margin-left: auto; display: flex; align-items: center; gap: 4px;"><span class="material-icons" style="font-size: 14px;">check_circle</span>No auth required</span>
        </div>
        <p class="desc">Health check endpoint. Returns service status, MQTT connection state, and node count.</p>
      </div>
    </section>

    <section class="endpoints">
      <div class="section-title" style="margin-bottom: 16px;"><span class="material-icons" style="font-size: 20px; vertical-align: middle; margin-right: 8px;">lock</span>App-Only Endpoints</div>
      <p style="color: var(--text-muted); font-size: 14px; margin-bottom: 24px;">
        These endpoints require authentication via the Socialmesh app. 
        <a href="https://socialmesh.app#download" style="color: var(--accent-magenta);">Download the app</a> to access the World Mesh feature.
      </p>
      
      <div class="endpoint" style="border-left: 3px solid var(--accent-magenta); opacity: 0.8;">
        <div class="endpoint-header">
          <span class="method">GET</span>
          <span class="path">/api/nodes</span>
          <span style="color: var(--accent-magenta); font-size: 12px; margin-left: auto; display: flex; align-items: center; gap: 4px;"><span class="material-icons" style="font-size: 14px;">vpn_key</span>Auth required</span>
        </div>
        <p class="desc">Get all tracked mesh nodes with position, telemetry, battery level, and hardware info.</p>
      </div>

      <div class="endpoint" style="border-left: 3px solid var(--accent-magenta); opacity: 0.8;">
        <div class="endpoint-header">
          <span class="method">GET</span>
          <span class="path">/api/node/:nodeNum</span>
          <span style="color: var(--accent-magenta); font-size: 12px; margin-left: auto; display: flex; align-items: center; gap: 4px;"><span class="material-icons" style="font-size: 14px;">vpn_key</span>Auth required</span>
        </div>
        <p class="desc">Get a single node by its numeric ID.</p>
      </div>

      <div class="endpoint" style="border-left: 3px solid var(--accent-magenta); opacity: 0.8;">
        <div class="endpoint-header">
          <span class="method">GET</span>
          <span class="path">/api/stats</span>
          <span style="color: var(--accent-magenta); font-size: 12px; margin-left: auto; display: flex; align-items: center; gap: 4px;"><span class="material-icons" style="font-size: 14px;">vpn_key</span>Auth required</span>
        </div>
        <p class="desc">Get detailed statistics about MQTT processing and node updates.</p>
      </div>
    </section>

    <section class="endpoints">
      <div class="section-title">How Authentication Works</div>
      <div class="example">
        <div class="example-label">For Developers</div>
        <pre><code><span class="comment">// The Socialmesh app handles authentication automatically.</span>
<span class="comment">// When you sign in to the app, it obtains a Firebase ID token</span>
<span class="comment">// and includes it with API requests:</span>

Authorization: Bearer &lt;firebase_id_token&gt;

<span class="comment">// This API is not intended for third-party use.</span>
<span class="comment">// If you're building a Meshtastic project, consider running</span>
<span class="comment">// your own mesh-observer instance:</span>
<span class="comment">// https://github.com/gotnull/socialmesh/tree/main/mesh-observer</span></code></pre>
      </div>
    </section>

    <section class="endpoints" style="display: none;">
      <div class="section-title">Legacy Endpoint Docs</div>
      
      <div class="endpoint">
      <div class="schema-code">
        <pre>{
  <span class="key">"nodeNum"</span>: <span class="number">3677891234</span>,       <span class="comment">// Unique node ID (from hardware)</span>
  <span class="key">"longName"</span>: <span class="value">"Base Station"</span>,  <span class="comment">// User-configured name</span>
  <span class="key">"shortName"</span>: <span class="value">"BASE"</span>,         <span class="comment">// 4-character identifier</span>
  <span class="key">"hwModel"</span>: <span class="value">"TBEAM"</span>,          <span class="comment">// Hardware model</span>
  <span class="key">"role"</span>: <span class="value">"ROUTER"</span>,            <span class="comment">// Node role (CLIENT, ROUTER, etc)</span>
  <span class="key">"latitude"</span>: <span class="number">37.7749</span>,         <span class="comment">// GPS latitude</span>
  <span class="key">"longitude"</span>: <span class="number">-122.4194</span>,      <span class="comment">// GPS longitude</span>
  <span class="key">"altitude"</span>: <span class="number">15</span>,              <span class="comment">// Altitude in meters</span>
  <span class="key">"batteryLevel"</span>: <span class="number">87</span>,          <span class="comment">// Battery percentage (0-100)</span>
  <span class="key">"voltage"</span>: <span class="number">4.1</span>,              <span class="comment">// Battery voltage</span>
  <span class="key">"chUtil"</span>: <span class="number">12.5</span>,              <span class="comment">// Channel utilization %</span>
  <span class="key">"airUtilTx"</span>: <span class="number">2.3</span>,            <span class="comment">// TX air time %</span>
  <span class="key">"temperature"</span>: <span class="number">23.5</span>,         <span class="comment">// Environment temperature °C</span>
  <span class="key">"region"</span>: <span class="value">"US"</span>,              <span class="comment">// LoRa region code</span>
  <span class="key">"modemPreset"</span>: <span class="value">"LongFast"</span>,   <span class="comment">// Modem configuration</span>
  <span class="key">"lastHeard"</span>: <span class="number">1735489234</span>,     <span class="comment">// Unix timestamp of last contact</span>
  <span class="key">"seenBy"</span>: { ... },           <span class="comment">// Gateways that received this node</span>
  <span class="key">"neighbors"</span>: { ... }         <span class="comment">// Nearby nodes with SNR values</span>
}</pre>
      </div>
    </section>

    <footer class="footer">
      <div class="footer-links">
        <a href="https://socialmesh.app">Socialmesh</a>
        <a href="https://meshtastic.org">Meshtastic</a>
      </div>
      <p>Powered by the global Meshtastic MQTT network</p>
      <div class="rate-limit">Rate limit: 100 requests/minute per IP</div>
    </footer>
  </div>
</body>
</html>`;

  res.type('html').send(html);
});

// Admin endpoints removed temporarily


// Health check endpoint (detailed)
app.get('/health', (req, res) => {
  const memUsage = process.memoryUsage();
  const mqttConnected = mqttObserver.isConnected();
  const nodeCount = nodeStore.getNodeCount();
  const uptimeSeconds = process.uptime();

  // Allow 60 seconds for MQTT to connect on startup
  // After that, consider unhealthy if MQTT disconnected or memory > 500MB
  const stillStarting = uptimeSeconds < 60;
  const isHealthy = stillStarting || (mqttConnected && memUsage.heapUsed < 500 * 1024 * 1024);

  res.status(isHealthy ? 200 : 503).json({
    status: stillStarting ? 'starting' : (mqttConnected ? 'ok' : 'degraded'),
    mqttConnected,
    nodeCount,
    uptime: process.uptime(),
    memory: {
      heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB',
      heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024) + 'MB',
      rss: Math.round(memUsage.rss / 1024 / 1024) + 'MB',
    },
    version: process.env.npm_package_version || '1.0.0',
  });
});

// World Mesh Map - Interactive web map
app.get('/map', (_req, res) => {
  const mapHtml = generateMapPage();
  res.type('html').send(mapHtml);
});

// Internal endpoint for map page (no auth, same-origin only via referer check)
app.get('/internal/nodes', (req, res) => {
  // Only allow requests from our own map page
  const referer = req.headers.referer || '';
  const host = req.headers.host || '';
  const origin = req.headers.origin || '';

  // Allow if referer is from same host or localhost (for development)
  const isInternalRequest = referer.includes(host) ||
    referer.includes('localhost') ||
    referer.includes('127.0.0.1') ||
    MAP_ALLOWED_HOSTS.some(
      (allowedHost) =>
        referer.includes(allowedHost) || origin.includes(allowedHost)
    ) ||
    !referer; // Allow direct requests for now (map page initial load)

  if (!isInternalRequest) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  res.json(nodeStore.getValidNodes());
});

// ============================================
// PROTECTED API ROUTES (require Firebase Auth)
// ============================================

// Get all nodes (filtered to valid nodes by default, ?all=true for raw)
app.get('/api/nodes', requireAuth, (req: AuthenticatedRequest, res) => {
  const includeAll = req.query.all === 'true';
  if (includeAll) {
    res.json(nodeStore.getAllNodes());
  } else {
    res.json(nodeStore.getValidNodes());
  }
});

// Get single node by nodeNum
app.get('/api/node/:nodeNum', requireAuth, (req: AuthenticatedRequest, res) => {
  const nodeNum = parseInt(req.params.nodeNum, 10);
  if (isNaN(nodeNum)) {
    return res.status(400).json({ error: 'Invalid node number' });
  }

  const node = nodeStore.getNode(nodeNum);
  if (!node) {
    return res.status(404).json({ error: 'Node not found' });
  }

  res.json(node);
});

// Get statistics
app.get('/api/stats', requireAuth, (req: AuthenticatedRequest, res) => {
  const decodeStats = mqttObserver.getStats();
  res.json({
    totalNodes: nodeStore.getNodeCount(),
    validNodes: nodeStore.getValidNodeCount(),
    nodesWithPosition: nodeStore.getNodesWithPositionCount(),
    onlineNodes: nodeStore.getOnlineNodeCount(),
    messagesReceived: decodeStats.totalMessages,
    lastUpdate: nodeStore.getLastUpdateTime(),
    decode: {
      envelopesDecoded: decodeStats.envelopesDecoded,
      packetsWithFrom: decodeStats.packetsWithFrom,
      decryptedSuccess: decodeStats.decryptedSuccess,
      decryptedFailed: decodeStats.decryptedFailed,
      jsonMessages: decodeStats.jsonMessages,
    },
    updates: {
      position: decodeStats.positionUpdates,
      nodeinfo: decodeStats.nodeinfoUpdates,
      telemetry: decodeStats.telemetryUpdates,
      neighborinfo: decodeStats.neighborinfoUpdates,
      mapreport: decodeStats.mapreportUpdates,
      nodesCreated: decodeStats.nodesCreated,
    },
    rateLimit: {
      droppedByQueue: decodeStats.queueDropped,
      droppedByNodeLimit: decodeStats.nodeRateLimited || 0,
    },
  });
});

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found' });
});

// Global error handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`Mesh Observer API listening on port ${PORT}`);
  console.log(`Connecting to MQTT broker: ${MQTT_BROKER}`);
  console.log(`Subscribing to topics: ${MQTT_TOPICS.join(', ')}`);

  // Start MQTT observer
  mqttObserver.connect();
});

// Periodic node purge (every 6 hours)
const purgeInterval = setInterval(() => {
  console.log(`Running node purge (removing nodes older than ${NODE_PURGE_DAYS} days)...`);
  const purged = nodeStore.purgeOldNodes(NODE_PURGE_DAYS);
  if (purged > 0) {
    console.log(`Purged ${purged} stale nodes`);
  }
}, 6 * 60 * 60 * 1000);

// Graceful shutdown
const shutdown = (signal: string) => {
  console.log(`Received ${signal}, shutting down gracefully...`);

  // Stop accepting new connections
  server.close(() => {
    console.log('HTTP server closed');
  });

  // Clear purge interval
  clearInterval(purgeInterval);

  // Disconnect MQTT and flush database
  mqttObserver.disconnect();
  nodeStore.dispose();

  console.log('Cleanup complete, exiting');
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Handle uncaught errors
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  shutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled rejection at:', promise, 'reason:', reason);
});
