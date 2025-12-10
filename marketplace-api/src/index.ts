import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { widgetsRouter } from './routes/widgets';
import { adminRouter } from './routes/admin';
import { Database } from './db';
import { initializeFirebase } from './firebase';

const app = express();
const port = process.env.PORT || 3000;

// Initialize Firebase Admin SDK
initializeFirebase();

// Initialize database
const db = new Database(process.env.DATABASE_PATH || './data/marketplace.db');

// Middleware
app.use(helmet());
app.use(cors({
  origin: '*', // Configure for production
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(compression());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('combined'));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/widgets', widgetsRouter(db));
app.use('/admin', adminRouter(db));

// Error handling
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Start server
app.listen(port, () => {
  console.log(`🚀 Marketplace API running on port ${port}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  db.close();
  process.exit(0);
});
