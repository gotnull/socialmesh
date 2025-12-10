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
  createdAt: string;
  updatedAt: string;
  isFeatured: boolean;
}

export interface WidgetSchema {
  name: string;
  description?: string;
  version: string;
  tags?: string[];
  size?: { width: number; height: number };
  root: ElementSchema;
}

export interface ElementSchema {
  type: string;
  properties?: Record<string, unknown>;
  binding?: BindingSchema;
  style?: Record<string, unknown>;
  layout?: Record<string, unknown>;
  children?: ElementSchema[];
}

export interface BindingSchema {
  source: string;
  format?: string;
  suffix?: string;
  defaultValue?: unknown;
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
