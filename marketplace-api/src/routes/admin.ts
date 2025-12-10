import { Router, Request, Response } from 'express';
import { z } from 'zod';
import type { Database } from '../db';
import { requireAdmin } from '../middleware/auth';

const RejectSchema = z.object({
  reason: z.string().min(1).max(500),
});

export function adminRouter(db: Database): Router {
  const router = Router();

  // All admin routes require admin authentication
  router.use(requireAdmin());

  // Get pending widgets for review
  router.get('/pending', (_req: Request, res: Response) => {
    const widgets = db.getPendingWidgets();
    res.json(widgets);
  });

  // Approve a widget
  router.post('/widgets/:id/approve', (req: Request, res: Response) => {
    const success = db.approveWidget(req.params.id);
    if (!success) {
      res.status(404).json({ error: 'Widget not found or already processed' });
      return;
    }
    res.json({ success: true });
  });

  // Reject a widget
  router.post('/widgets/:id/reject', (req: Request, res: Response) => {
    try {
      const body = RejectSchema.parse(req.body);
      const success = db.rejectWidget(req.params.id, body.reason);
      if (!success) {
        res.status(404).json({ error: 'Widget not found or already processed' });
        return;
      }
      res.json({ success: true });
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: 'Invalid request', details: error.errors });
      } else {
        throw error;
      }
    }
  });

  // Delete a widget
  router.delete('/widgets/:id', (req: Request, res: Response) => {
    const success = db.deleteWidget(req.params.id);
    if (!success) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }
    res.json({ success: true });
  });

  // Set widget as featured
  router.post('/widgets/:id/feature', (req: Request, res: Response) => {
    const success = db.setFeatured(req.params.id, true);
    if (!success) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }
    res.json({ success: true });
  });

  // Remove widget from featured
  router.delete('/widgets/:id/feature', (req: Request, res: Response) => {
    const success = db.setFeatured(req.params.id, false);
    if (!success) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }
    res.json({ success: true });
  });

  // Get reports for review
  router.get('/reports', (req: Request, res: Response) => {
    const status = (req.query.status as string) || 'pending';
    const reports = db.getReports(status);
    res.json(reports);
  });

  // Resolve a report
  router.post('/reports/:id/resolve', (req: Request, res: Response) => {
    db.resolveReport(req.params.id, 'resolved');
    res.json({ success: true });
  });

  // Dismiss a report
  router.post('/reports/:id/dismiss', (req: Request, res: Response) => {
    db.resolveReport(req.params.id, 'dismissed');
    res.json({ success: true });
  });

  return router;
}
