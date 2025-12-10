import BetterSqlite3 from 'better-sqlite3';
import { v4 as uuidv4 } from 'uuid';
import type { Widget, WidgetSchema, MarketplaceResponse } from './types';

export class Database {
  private db: BetterSqlite3.Database;

  constructor(dbPath: string) {
    this.db = new BetterSqlite3(dbPath);
    this.db.pragma('journal_mode = WAL');
    this.init();
    this.seedSampleWidgets();
  }

  private init() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS widgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        author TEXT NOT NULL,
        author_id TEXT NOT NULL,
        version TEXT NOT NULL DEFAULT '1.0.0',
        thumbnail_url TEXT,
        downloads INTEGER DEFAULT 0,
        rating REAL DEFAULT 0,
        rating_count INTEGER DEFAULT 0,
        rating_sum INTEGER DEFAULT 0,
        tags TEXT,
        category TEXT,
        schema TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_featured INTEGER DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS ratings (
        id TEXT PRIMARY KEY,
        widget_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        rating INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (widget_id) REFERENCES widgets(id),
        UNIQUE(widget_id, user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_widgets_category ON widgets(category);
      CREATE INDEX IF NOT EXISTS idx_widgets_downloads ON widgets(downloads DESC);
      CREATE INDEX IF NOT EXISTS idx_widgets_rating ON widgets(rating DESC);
      CREATE INDEX IF NOT EXISTS idx_widgets_created ON widgets(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_widgets_featured ON widgets(is_featured);
    `);
  }

  private seedSampleWidgets() {
    const count = this.db.prepare('SELECT COUNT(*) as count FROM widgets').get() as { count: number };
    if (count.count > 0) return;

    // Widget schemas matching the Flutter app's WidgetSchema format
    const sampleWidgets: Array<Omit<Widget, 'id' | 'createdAt' | 'updatedAt'> & { schema: WidgetSchema }> = [
      {
        name: 'Battery Gauge Pro',
        description: 'Beautiful animated battery indicator with low power warnings and color-coded status',
        author: 'MeshMaster',
        authorId: 'user-001',
        version: '1.2.0',
        thumbnailUrl: null,
        downloads: 1250,
        rating: 4.8,
        ratingCount: 156,
        tags: ['battery', 'gauge', 'animated', 'status'],
        category: 'status',
        isFeatured: true,
        schema: {
          name: 'Battery Gauge Pro',
          description: 'Beautiful animated battery indicator',
          version: '1.2.0',
          tags: ['battery', 'gauge', 'animated'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 8 },
            children: [
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'icon', iconName: 'battery_full', iconSize: 20, style: { textColor: '#4ADE80' } },
                  { type: 'text', text: 'Battery', style: { fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'text',
                binding: { path: 'node.batteryLevel', format: '{value}%', defaultValue: '--' },
                style: { fontSize: 32, fontWeight: 'bold', textColor: '#FFFFFF' },
              },
              {
                type: 'gauge',
                gaugeType: 'linear',
                gaugeMin: 0,
                gaugeMax: 100,
                gaugeColor: '#4ADE80',
                binding: { path: 'node.batteryLevel' },
                style: { height: 6 },
              },
            ],
          },
        },
      },
      {
        name: 'Weather Station',
        description: 'Complete weather display with temperature, humidity, and barometric pressure readings',
        author: 'WeatherWizard',
        authorId: 'user-002',
        version: '2.0.0',
        thumbnailUrl: null,
        downloads: 890,
        rating: 4.5,
        ratingCount: 89,
        tags: ['weather', 'temperature', 'humidity', 'environment'],
        category: 'sensors',
        isFeatured: true,
        schema: {
          name: 'Weather Station',
          description: 'Complete weather display',
          version: '2.0.0',
          tags: ['weather', 'temperature', 'environment'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 12 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'thermostat', iconSize: 20, style: { textColor: '#F97316' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', text: 'Environment', style: { fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceAround' },
                children: [
                  {
                    type: 'column',
                    style: { alignment: 'center' },
                    children: [
                      { type: 'icon', iconName: 'thermostat', iconSize: 24, style: { textColor: '#EF4444' } },
                      { type: 'text', binding: { path: 'node.temperature', format: '{value}°C', defaultValue: '--' }, style: { fontSize: 20, fontWeight: 'w600', textColor: '#FFFFFF' } },
                    ],
                  },
                  {
                    type: 'column',
                    style: { alignment: 'center' },
                    children: [
                      { type: 'icon', iconName: 'water_drop', iconSize: 24, style: { textColor: '#06B6D4' } },
                      { type: 'text', binding: { path: 'node.humidity', format: '{value}%', defaultValue: '--' }, style: { fontSize: 20, fontWeight: 'w600', textColor: '#FFFFFF' } },
                    ],
                  },
                ],
              },
            ],
          },
        },
      },
      {
        name: 'Signal Radar',
        description: 'Animated radar-style signal strength visualization',
        author: 'RadioRanger',
        authorId: 'user-003',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 567,
        rating: 4.3,
        ratingCount: 45,
        tags: ['signal', 'radar', 'animated', 'snr'],
        category: 'connectivity',
        isFeatured: false,
        schema: {
          name: 'Signal Radar',
          description: 'Signal strength visualization',
          version: '1.0.0',
          tags: ['signal', 'snr', 'rssi'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 8 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'signal_cellular_alt', iconSize: 20, style: { textColor: '#4F6AF6' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', text: 'Signal', style: { fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  {
                    type: 'column',
                    children: [
                      { type: 'text', text: 'SNR', style: { textColor: '#888888', fontSize: 11 } },
                      { type: 'text', binding: { path: 'device.snr', format: '{value} dB', defaultValue: '--' }, style: { textColor: '#FFFFFF', fontSize: 18, fontWeight: 'w600' } },
                    ],
                  },
                  {
                    type: 'column',
                    children: [
                      { type: 'text', text: 'RSSI', style: { textColor: '#888888', fontSize: 11 } },
                      { type: 'text', binding: { path: 'device.rssi', format: '{value} dBm', defaultValue: '--' }, style: { textColor: '#FFFFFF', fontSize: 18, fontWeight: 'w600' } },
                    ],
                  },
                ],
              },
            ],
          },
        },
      },
      {
        name: 'Node Compass',
        description: 'Shows direction and distance to selected node with compass visualization',
        author: 'NavigatorNick',
        authorId: 'user-004',
        version: '1.1.0',
        thumbnailUrl: null,
        downloads: 432,
        rating: 4.6,
        ratingCount: 67,
        tags: ['navigation', 'compass', 'direction', 'distance'],
        category: 'navigation',
        isFeatured: true,
        schema: {
          name: 'Node Compass',
          description: 'Shows direction and distance to node',
          version: '1.1.0',
          tags: ['navigation', 'compass', 'direction'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 8 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'explore', iconSize: 20, style: { textColor: '#22C55E' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', text: 'Compass', style: { fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'navigation', iconSize: 48, style: { textColor: '#22C55E' } },
                ],
              },
              {
                type: 'text',
                binding: { path: 'node.bearing', format: '{value}°', defaultValue: '--' },
                style: { fontSize: 24, fontWeight: 'bold', textColor: '#FFFFFF' },
              },
            ],
          },
        },
      },
      {
        name: 'Mesh Network Map',
        description: 'Mini map showing nearby nodes in your mesh network',
        author: 'MapMaven',
        authorId: 'user-005',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 789,
        rating: 4.7,
        ratingCount: 112,
        tags: ['map', 'mesh', 'network', 'nodes'],
        category: 'navigation',
        isFeatured: true,
        schema: {
          name: 'Mesh Network Map',
          description: 'Mini map showing nearby nodes',
          version: '1.0.0',
          tags: ['map', 'mesh', 'network'],
          size: 'large',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 8 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'map', iconSize: 20, style: { textColor: '#4F6AF6' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', text: 'Mesh Map', style: { fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceAround' },
                children: [
                  {
                    type: 'column',
                    style: { alignment: 'center' },
                    children: [
                      { type: 'text', binding: { path: 'network.totalNodes', defaultValue: '0' }, style: { fontSize: 24, fontWeight: 'bold', textColor: '#FFFFFF' } },
                      { type: 'text', text: 'Nodes', style: { fontSize: 11, textColor: '#888888' } },
                    ],
                  },
                  {
                    type: 'column',
                    style: { alignment: 'center' },
                    children: [
                      { type: 'text', binding: { path: 'network.onlineNodes', defaultValue: '0' }, style: { fontSize: 24, fontWeight: 'bold', textColor: '#4ADE80' } },
                      { type: 'text', text: 'Online', style: { fontSize: 11, textColor: '#888888' } },
                    ],
                  },
                ],
              },
            ],
          },
        },
      },
      {
        name: 'Power Monitor',
        description: 'Detailed power metrics including voltage, current, and consumption',
        author: 'PowerPro',
        authorId: 'user-006',
        version: '1.3.0',
        thumbnailUrl: null,
        downloads: 345,
        rating: 4.4,
        ratingCount: 38,
        tags: ['power', 'voltage', 'current', 'metrics'],
        category: 'power',
        isFeatured: false,
        schema: {
          name: 'Power Monitor',
          description: 'Detailed power metrics',
          version: '1.3.0',
          tags: ['power', 'voltage', 'current'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 8 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'electric_bolt', iconSize: 20, style: { textColor: '#FBBF24' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', text: 'Power', style: { fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'text', text: 'Voltage', style: { fontSize: 12, textColor: '#888888' } },
                  { type: 'text', binding: { path: 'power.voltage', format: '{value}V', defaultValue: '--' }, style: { fontSize: 12, textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'text', text: 'Current', style: { fontSize: 12, textColor: '#888888' } },
                  { type: 'text', binding: { path: 'power.current', format: '{value}mA', defaultValue: '--' }, style: { fontSize: 12, textColor: '#FFFFFF' } },
                ],
              },
            ],
          },
        },
      },
      {
        name: 'Air Quality Index',
        description: 'Air quality monitoring with IAQ, PM2.5, and CO2 levels',
        author: 'AirAware',
        authorId: 'user-007',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 234,
        rating: 4.2,
        ratingCount: 28,
        tags: ['air', 'quality', 'iaq', 'pm25', 'co2'],
        category: 'sensors',
        isFeatured: false,
        schema: {
          name: 'Air Quality Index',
          description: 'Air quality monitoring',
          version: '1.0.0',
          tags: ['air', 'quality', 'iaq'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 12 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'air', iconSize: 20, style: { textColor: '#22C55E' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', text: 'Air Quality', style: { fontSize: 14, fontWeight: 'w600', textColor: '#FFFFFF' } },
                ],
              },
              {
                type: 'gauge',
                gaugeType: 'linear',
                gaugeMin: 0,
                gaugeMax: 500,
                gaugeColor: '#22C55E',
                binding: { path: 'airQuality.iaq' },
                style: { height: 8 },
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'text', text: 'PM2.5', style: { fontSize: 12, textColor: '#888888' } },
                  { type: 'text', binding: { path: 'airQuality.pm25', defaultValue: '--' }, style: { fontSize: 12, textColor: '#FFFFFF' } },
                ],
              },
            ],
          },
        },
      },
      {
        name: 'Message Counter',
        description: 'Real-time message statistics with activity chart',
        author: 'ChatChamp',
        authorId: 'user-008',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 567,
        rating: 4.1,
        ratingCount: 52,
        tags: ['messages', 'stats', 'counter', 'chart'],
        category: 'messaging',
        isFeatured: false,
        schema: {
          name: 'Message Counter',
          description: 'Real-time message statistics',
          version: '1.0.0',
          tags: ['messages', 'stats', 'counter'],
          size: 'medium',
          root: {
            type: 'row',
            style: { padding: 16, mainAxisAlignment: 'spaceBetween' },
            children: [
              {
                type: 'column',
                style: { spacing: 4 },
                children: [
                  { type: 'icon', iconName: 'chat_bubble_outline', iconSize: 24, style: { textColor: '#4F6AF6' } },
                  { type: 'text', binding: { path: 'messaging.recentCount', defaultValue: '0' }, style: { fontSize: 28, fontWeight: 'bold', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Messages', style: { fontSize: 12, textColor: '#888888' } },
                ],
              },
              {
                type: 'column',
                style: { spacing: 4 },
                children: [
                  { type: 'icon', iconName: 'group', iconSize: 24, style: { textColor: '#22C55E' } },
                  { type: 'text', binding: { path: 'messaging.channelCount', defaultValue: '0' }, style: { fontSize: 28, fontWeight: 'bold', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Channels', style: { fontSize: 12, textColor: '#888888' } },
                ],
              },
            ],
          },
        },
      },
    ];

    const insert = this.db.prepare(`
      INSERT INTO widgets (id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, schema, created_at, updated_at, is_featured)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const now = new Date().toISOString();
    for (const widget of sampleWidgets) {
      insert.run(
        uuidv4(),
        widget.name,
        widget.description,
        widget.author,
        widget.authorId,
        widget.version,
        widget.thumbnailUrl,
        widget.downloads,
        widget.rating,
        widget.ratingCount,
        JSON.stringify(widget.tags),
        widget.category,
        JSON.stringify(widget.schema),
        now,
        now,
        widget.isFeatured ? 1 : 0
      );
    }

    console.log(`Seeded ${sampleWidgets.length} sample widgets`);
  }

  // Widget CRUD operations
  getWidgets(options: {
    page?: number;
    limit?: number;
    category?: string;
    sortBy?: string;
    search?: string;
  } = {}): MarketplaceResponse {
    const { page = 1, limit = 20, category, sortBy = 'downloads', search } = options;
    const offset = (page - 1) * limit;

    let whereClause = '1=1';
    const params: (string | number)[] = [];

    if (category) {
      whereClause += ' AND category = ?';
      params.push(category);
    }

    if (search) {
      whereClause += ' AND (name LIKE ? OR description LIKE ? OR tags LIKE ?)';
      const searchTerm = `%${search}%`;
      params.push(searchTerm, searchTerm, searchTerm);
    }

    let orderClause = 'downloads DESC';
    switch (sortBy) {
      case 'rating':
        orderClause = 'rating DESC';
        break;
      case 'newest':
        orderClause = 'created_at DESC';
        break;
      case 'name':
        orderClause = 'name ASC';
        break;
    }

    const countResult = this.db.prepare(`SELECT COUNT(*) as total FROM widgets WHERE ${whereClause}`).get(...params) as { total: number };
    const total = countResult.total;

    const rows = this.db.prepare(`
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, created_at, updated_at, is_featured
      FROM widgets
      WHERE ${whereClause}
      ORDER BY ${orderClause}
      LIMIT ? OFFSET ?
    `).all(...params, limit, offset) as WidgetRow[];

    const widgets = rows.map(this.rowToWidget);

    return {
      widgets,
      total,
      page,
      hasMore: offset + widgets.length < total,
    };
  }

  getFeatured(): Widget[] {
    const rows = this.db.prepare(`
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, created_at, updated_at, is_featured
      FROM widgets
      WHERE is_featured = 1
      ORDER BY downloads DESC
      LIMIT 10
    `).all() as WidgetRow[];

    return rows.map(this.rowToWidget);
  }

  getWidget(id: string): Widget | null {
    const row = this.db.prepare(`
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, created_at, updated_at, is_featured
      FROM widgets
      WHERE id = ?
    `).get(id) as WidgetRow | undefined;

    return row ? this.rowToWidget(row) : null;
  }

  getWidgetSchema(id: string): WidgetSchema | null {
    const row = this.db.prepare('SELECT schema FROM widgets WHERE id = ?').get(id) as { schema: string } | undefined;
    return row ? JSON.parse(row.schema) : null;
  }

  incrementDownloads(id: string): void {
    this.db.prepare('UPDATE widgets SET downloads = downloads + 1 WHERE id = ?').run(id);
  }

  createWidget(widget: {
    name: string;
    description?: string;
    author: string;
    authorId: string;
    version: string;
    tags?: string[];
    category?: string;
    schema: WidgetSchema;
  }): Widget {
    const id = uuidv4();
    const now = new Date().toISOString();

    this.db.prepare(`
      INSERT INTO widgets (id, name, description, author, author_id, version, tags, category, schema, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      widget.name,
      widget.description || null,
      widget.author,
      widget.authorId,
      widget.version,
      JSON.stringify(widget.tags || []),
      widget.category || null,
      JSON.stringify(widget.schema),
      now,
      now
    );

    return this.getWidget(id)!;
  }

  rateWidget(widgetId: string, userId: string, rating: number): void {
    const existing = this.db.prepare('SELECT id, rating FROM ratings WHERE widget_id = ? AND user_id = ?').get(widgetId, userId) as { id: string; rating: number } | undefined;

    if (existing) {
      // Update existing rating
      this.db.prepare('UPDATE ratings SET rating = ? WHERE id = ?').run(rating, existing.id);
      this.db.prepare(`
        UPDATE widgets
        SET rating_sum = rating_sum - ? + ?,
            rating = CAST(rating_sum - ? + ? AS REAL) / rating_count
        WHERE id = ?
      `).run(existing.rating, rating, existing.rating, rating, widgetId);
    } else {
      // New rating
      this.db.prepare('INSERT INTO ratings (id, widget_id, user_id, rating, created_at) VALUES (?, ?, ?, ?, ?)').run(
        uuidv4(),
        widgetId,
        userId,
        rating,
        new Date().toISOString()
      );
      this.db.prepare(`
        UPDATE widgets
        SET rating_count = rating_count + 1,
            rating_sum = rating_sum + ?,
            rating = CAST(rating_sum + ? AS REAL) / (rating_count + 1)
        WHERE id = ?
      `).run(rating, rating, widgetId);
    }
  }

  getCategories(): string[] {
    const rows = this.db.prepare('SELECT DISTINCT category FROM widgets WHERE category IS NOT NULL ORDER BY category').all() as { category: string }[];
    return rows.map(r => r.category);
  }

  private rowToWidget(row: WidgetRow): Widget {
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      author: row.author,
      authorId: row.author_id,
      version: row.version,
      thumbnailUrl: row.thumbnail_url,
      downloads: row.downloads,
      rating: row.rating,
      ratingCount: row.rating_count,
      tags: JSON.parse(row.tags || '[]'),
      category: row.category,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      isFeatured: row.is_featured === 1,
    };
  }

  close(): void {
    this.db.close();
  }
}

interface WidgetRow {
  id: string;
  name: string;
  description: string | null;
  author: string;
  author_id: string;
  version: string;
  thumbnail_url: string | null;
  downloads: number;
  rating: number;
  rating_count: number;
  tags: string | null;
  category: string | null;
  created_at: string;
  updated_at: string;
  is_featured: number;
}
