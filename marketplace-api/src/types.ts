export interface Widget {
  id: string;
  name: string;
  description: string | null;
  author: string;
  authorId: string;
  version: string;
  thumbnailUrl: string | null;
  downloads: number;
  rating: number;
  ratingCount: number;
  tags: string[];
  category: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
  isFeatured: boolean;
}

export interface Report {
  id: string;
  widgetId: string;
  widgetName: string;
  userId: string;
  reason: string;
  status: string;
  createdAt: string;
  resolvedAt: string | null;
}

export interface WidgetSchema {
  name: string;
  description?: string;
  version?: string;
  tags?: string[];
  size?: string | { width: number; height: number };
  root: ElementSchema;
  [key: string]: unknown;
}

export interface ElementSchema {
  type: string;
  // Allow any properties for flexibility with Flutter app schema
  [key: string]: unknown;
}

export interface BindingSchema {
  path?: string;
  source?: string;
  format?: string;
  defaultValue?: unknown;
  [key: string]: unknown;
}

export interface MarketplaceResponse {
  widgets: Widget[];
  total: number;
  page: number;
  hasMore: boolean;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}
