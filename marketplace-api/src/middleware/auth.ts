import { Request, Response, NextFunction } from 'express';
import { verifyIdToken, DecodedUser } from '../firebase';

// Extend Express Request to include user info
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: DecodedUser;
    }
  }
}

/**
 * Middleware that requires authentication.
 * Returns 401 if no valid token is provided.
 */
export function requireAuth() {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const idToken = authHeader.slice(7);

    if (!idToken) {
      res.status(401).json({ error: 'Invalid authorization header' });
      return;
    }

    const user = await verifyIdToken(idToken);

    if (!user) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    req.user = user;
    next();
  };
}

/**
 * Middleware that optionally extracts user info if a token is provided.
 * Does not fail if no token is present.
 */
export function optionalAuth() {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const idToken = authHeader.slice(7);

      if (idToken) {
        const user = await verifyIdToken(idToken);
        if (user) {
          req.user = user;
        }
      }
    }

    next();
  };
}

/**
 * Middleware that requires admin privileges.
 * Checks if user email is in ADMIN_EMAILS environment variable.
 */
export function requireAdmin() {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    // First ensure user is authenticated
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const idToken = authHeader.slice(7);
    const user = await verifyIdToken(idToken);

    if (!user) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    // Check if user is admin
    const adminEmails = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase());

    if (!user.email || !adminEmails.includes(user.email.toLowerCase())) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    req.user = user;
    next();
  };
}
