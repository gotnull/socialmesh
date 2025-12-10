import { Router, Request, Response } from 'express';
import { z } from 'zod';
import type { Database } from '../db';

const BrowseQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  category: z.string().optional(),
  sort: z.enum(['downloads', 'rating', 'newest', 'name']).default('downloads'),
  q: z.string().optional(),
});

const RatingSchema = z.object({
  rating: z.number().int().min(1).max(5),
});

const UploadSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  version: z.string().default('1.0.0'),
  tags: z.array(z.string()).max(10).optional(),
  category: z.string().optional(),
  root: z.record(z.unknown()),
});

export function widgetsRouter(db: Database): Router {
  const router = Router();

  // Browse widgets
  router.get('/browse', (req: Request, res: Response) => {
    try {
      const query = BrowseQuerySchema.parse(req.query);
      const result = db.getWidgets({
        page: query.page,
        limit: query.limit,
        category: query.category,
        sortBy: query.sort,
        search: query.q,
      });
      res.json(result);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: 'Invalid query parameters', details: error.errors });
      } else {
        throw error;
      }
    }
  });

  // Get featured widgets
  router.get('/featured', (_req: Request, res: Response) => {
    const widgets = db.getFeatured();
    res.json(widgets);
  });

  // Get categories
  router.get('/categories', (_req: Request, res: Response) => {
    const categories = db.getCategories();
    res.json(categories);
  });

  // Get widget details
  router.get('/:id', (req: Request, res: Response) => {
    const widget = db.getWidget(req.params.id);
    if (!widget) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }
    res.json(widget);
  });

  // Download widget schema
  router.get('/:id/download', (req: Request, res: Response) => {
    const schema = db.getWidgetSchema(req.params.id);
    if (!schema) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }
    db.incrementDownloads(req.params.id);
    res.json(schema);
  });

  // Upload widget (requires auth header for user identification)
  router.post('/upload', (req: Request, res: Response) => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Authentication required' });
        return;
      }

      // In production, validate the token and extract user info
      // For now, use a simple user ID from the token
      const token = authHeader.slice(7);
      const userId = `user-${token.slice(0, 8)}`;
      const userName = 'Anonymous'; // Would come from auth system

      const body = UploadSchema.parse(req.body);
      const widget = db.createWidget({
        name: body.name,
        description: body.description,
        author: userName,
        authorId: userId,
        version: body.version,
        tags: body.tags,
        category: body.category,
        schema: {
          name: body.name,
          description: body.description,
          version: body.version,
          tags: body.tags,
          root: body.root as never,
        },
      });

      res.status(201).json(widget);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: 'Invalid widget data', details: error.errors });
      } else {
        throw error;
      }
    }
  });

  // Rate widget
  router.post('/:id/rate', (req: Request, res: Response) => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Authentication required' });
        return;
      }

      const widget = db.getWidget(req.params.id);
      if (!widget) {
        res.status(404).json({ error: 'Widget not found' });
        return;
      }

      const token = authHeader.slice(7);
      const userId = `user-${token.slice(0, 8)}`;

      const body = RatingSchema.parse(req.body);
      db.rateWidget(req.params.id, userId, body.rating);

      res.json({ success: true });
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: 'Invalid rating', details: error.errors });
      } else {
        throw error;
      }
    }
  });

  // Report widget (placeholder)
  router.post('/:id/report', (req: Request, res: Response) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const widget = db.getWidget(req.params.id);
    if (!widget) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }

    // In production, store the report for review
    console.log(`Widget ${req.params.id} reported: ${req.body.reason}`);
    res.json({ success: true });
  });

  return router;
}
