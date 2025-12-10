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
          size: { width: 2, height: 2 },
          root: {
            type: 'column',
            style: { padding: 16, spacing: 8, backgroundColor: '#1E1E1E', borderRadius: 12 },
            children: [
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'icon', properties: { iconName: 'battery_full' }, style: { iconSize: 24, color: '#4ADE80' } },
                  { type: 'text', properties: { text: 'Battery' }, style: { fontSize: 14, fontWeight: 'w600', color: '#FFFFFF' } },
                ],
              },
              {
                type: 'gauge',
                binding: { source: 'node.batteryLevel' },
                properties: { gaugeType: 'radial', min: 0, max: 100 },
                style: { gaugeColor: '#4ADE80' },
                layout: { width: 80, height: 80 },
              },
              {
                type: 'text',
                binding: { source: 'node.batteryLevel', format: 'percent' },
                style: { fontSize: 28, fontWeight: 'bold', color: '#FFFFFF' },
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
          size: { width: 2, height: 2 },
          root: {
            type: 'column',
            style: { padding: 16, spacing: 12, backgroundColor: '#1E1E1E', borderRadius: 12 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', properties: { iconName: 'thermostat' }, style: { iconSize: 20, color: '#F97316' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', properties: { text: 'Weather' }, style: { fontSize: 14, fontWeight: 'w600', color: '#FFFFFF' } },
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
                      { type: 'text', binding: { source: 'environment.temperature', format: 'suffix', suffix: '°' }, style: { fontSize: 24, fontWeight: 'bold', color: '#EF4444' } },
                      { type: 'text', properties: { text: 'Temp' }, style: { fontSize: 10, color: '#808080' } },
                    ],
                  },
                  {
                    type: 'column',
                    style: { alignment: 'center' },
                    children: [
                      { type: 'text', binding: { source: 'environment.relativeHumidity', format: 'percent' }, style: { fontSize: 24, fontWeight: 'bold', color: '#06B6D4' } },
                      { type: 'text', properties: { text: 'Humidity' }, style: { fontSize: 10, color: '#808080' } },
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
          description: 'Animated radar-style signal strength visualization',
          version: '1.0.0',
          tags: ['signal', 'radar', 'animated'],
          size: { width: 2, height: 2 },
          root: {
            type: 'column',
            style: { padding: 16, spacing: 12, backgroundColor: '#1E1E1E', borderRadius: 12 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', properties: { iconName: 'radar' }, style: { iconSize: 20, color: '#8B5CF6' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', properties: { text: 'Signal' }, style: { fontSize: 14, fontWeight: 'w600', color: '#FFFFFF' } },
                ],
              },
              {
                type: 'gauge',
                binding: { source: 'node.snr' },
                properties: { gaugeType: 'radial', min: -20, max: 15 },
                style: { gaugeColor: '#8B5CF6' },
                layout: { width: 80, height: 80 },
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'text', binding: { source: 'node.snr', format: 'suffix', suffix: ' dB' }, style: { fontSize: 14, color: '#FFFFFF' } },
                  { type: 'text', binding: { source: 'node.rssi', format: 'suffix', suffix: ' dBm' }, style: { fontSize: 14, color: '#808080' } },
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
          size: { width: 2, height: 2 },
          root: {
            type: 'column',
            style: { padding: 16, spacing: 8, backgroundColor: '#1E1E1E', borderRadius: 12 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', properties: { iconName: 'explore' }, style: { iconSize: 20, color: '#22C55E' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', properties: { text: 'Compass' }, style: { fontSize: 14, fontWeight: 'w600', color: '#FFFFFF' } },
                ],
              },
              { type: 'icon', properties: { iconName: 'navigation' }, style: { iconSize: 64, color: '#22C55E' } },
              {
                type: 'text',
                binding: { source: 'node.distanceKm', format: 'suffix', suffix: ' km' },
                style: { fontSize: 20, fontWeight: 'bold', color: '#FFFFFF' },
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
          size: { width: 2, height: 2 },
          root: {
            type: 'container',
            style: { backgroundColor: '#1E1E1E', borderRadius: 12 },
            children: [
              {
                type: 'map',
                binding: { source: 'position.latitude' },
                properties: { showMarkers: true, zoomLevel: 14 },
                layout: { width: null, height: 150 },
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
          size: { width: 2, height: 2 },
          root: {
            type: 'column',
            style: { padding: 16, spacing: 8, backgroundColor: '#1E1E1E', borderRadius: 12 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', properties: { iconName: 'electric_bolt' }, style: { iconSize: 20, color: '#FBBF24' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', properties: { text: 'Power' }, style: { fontSize: 14, fontWeight: 'w600', color: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'text', properties: { text: 'Voltage' }, style: { fontSize: 12, color: '#808080' } },
                  { type: 'text', binding: { source: 'power.voltage', format: 'suffix', suffix: 'V' }, style: { fontSize: 12, color: '#FFFFFF' } },
                ],
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'text', properties: { text: 'Current' }, style: { fontSize: 12, color: '#808080' } },
                  { type: 'text', binding: { source: 'power.current', format: 'suffix', suffix: 'mA' }, style: { fontSize: 12, color: '#FFFFFF' } },
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
          size: { width: 2, height: 2 },
          root: {
            type: 'column',
            style: { padding: 16, spacing: 12, backgroundColor: '#1E1E1E', borderRadius: 12 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', properties: { iconName: 'air' }, style: { iconSize: 20, color: '#67C23A' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', properties: { text: 'Air Quality' }, style: { fontSize: 14, fontWeight: 'w600', color: '#FFFFFF' } },
                ],
              },
              {
                type: 'gauge',
                binding: { source: 'airQuality.iaq' },
                properties: { gaugeType: 'radial', min: 0, max: 500 },
                style: { gaugeColor: '#67C23A' },
                layout: { width: 60, height: 60 },
              },
              {
                type: 'row',
                style: { mainAxisAlignment: 'spaceBetween' },
                children: [
                  { type: 'text', properties: { text: 'PM2.5' }, style: { fontSize: 12, color: '#808080' } },
                  { type: 'text', binding: { source: 'airQuality.pm25' }, style: { fontSize: 12, color: '#FFFFFF' } },
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
          size: { width: 2, height: 1 },
          root: {
            type: 'row',
            style: { padding: 16, backgroundColor: '#1E1E1E', borderRadius: 12, mainAxisAlignment: 'spaceBetween' },
            children: [
              {
                type: 'column',
                style: { spacing: 4 },
                children: [
                  { type: 'text', binding: { source: 'messages.totalCount' }, style: { fontSize: 28, fontWeight: 'bold', color: '#FFFFFF' } },
                  { type: 'text', properties: { text: 'Messages' }, style: { fontSize: 12, color: '#808080' } },
                ],
              },
              {
                type: 'chart',
                binding: { source: 'messages.hourlyCount' },
                properties: { chartType: 'sparkline' },
                style: { chartColor: '#67C23A' },
                layout: { width: 80, height: 40 },
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
