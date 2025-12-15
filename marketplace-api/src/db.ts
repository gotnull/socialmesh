import BetterSqlite3 from 'better-sqlite3';
import { v4 as uuidv4 } from 'uuid';
import type { Widget, WidgetSchema, MarketplaceResponse, Report } from './types';

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
        status TEXT NOT NULL DEFAULT 'approved',
        rejection_reason TEXT,
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

      CREATE TABLE IF NOT EXISTS reports (
        id TEXT PRIMARY KEY,
        widget_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        resolved_at TEXT,
        FOREIGN KEY (widget_id) REFERENCES widgets(id)
      );

      CREATE INDEX IF NOT EXISTS idx_widgets_category ON widgets(category);
      CREATE INDEX IF NOT EXISTS idx_widgets_downloads ON widgets(downloads DESC);
      CREATE INDEX IF NOT EXISTS idx_widgets_rating ON widgets(rating DESC);
      CREATE INDEX IF NOT EXISTS idx_widgets_created ON widgets(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_widgets_featured ON widgets(is_featured);
      CREATE INDEX IF NOT EXISTS idx_widgets_status ON widgets(status);
      CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
    `);

    // Add status column if it doesn't exist (migration for existing DBs)
    try {
      this.db.prepare('SELECT status FROM widgets LIMIT 1').get();
    } catch {
      this.db.exec("ALTER TABLE widgets ADD COLUMN status TEXT NOT NULL DEFAULT 'approved'");
      this.db.exec('ALTER TABLE widgets ADD COLUMN rejection_reason TEXT');
    }
  }

  private seedSampleWidgets() {
    const count = this.db.prepare('SELECT COUNT(*) as count FROM widgets').get() as { count: number };
    if (count.count > 0) return;

    // Widget schemas matching the Flutter app's WidgetTemplates exactly
    const sampleWidgets: Array<Omit<Widget, 'id' | 'createdAt' | 'updatedAt'> & { schema: WidgetSchema }> = [
      // 1. Battery Status - matches WidgetTemplates.batteryWidget()
      {
        name: 'Battery Status',
        description: 'Display battery level with gauge',
        author: 'Socialmesh',
        authorId: 'official',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 1250,
        rating: 4.8,
        ratingCount: 156,
        tags: ['battery', 'power', 'status'],
        category: 'status',
        status: 'approved',
        isFeatured: true,
        schema: {
          name: 'Battery Status',
          description: 'Display battery level with gauge',
          version: '1.0.0',
          tags: ['battery', 'power', 'status'],
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
                  { type: 'text', binding: { path: 'node.displayName', defaultValue: 'My Device' }, style: { textColor: '#FFFFFF', fontSize: 14, fontWeight: 'w600' } },
                ],
              },
              {
                type: 'text',
                binding: { path: 'node.batteryLevel', format: '{value}%', defaultValue: '--' },
                style: { textColor: '#FFFFFF', fontSize: 32, fontWeight: 'bold' },
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
      // 2. Signal Strength - matches WidgetTemplates.signalWidget()
      {
        name: 'Signal Strength',
        description: 'Display SNR and RSSI',
        author: 'Socialmesh',
        authorId: 'official',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 890,
        rating: 4.5,
        ratingCount: 89,
        tags: ['signal', 'snr', 'rssi', 'connectivity'],
        category: 'connectivity',
        status: 'approved',
        isFeatured: true,
        schema: {
          name: 'Signal Strength',
          description: 'Display SNR and RSSI',
          version: '1.0.0',
          tags: ['signal', 'snr', 'rssi', 'connectivity'],
          size: 'medium',
          root: {
            type: 'row',
            style: { padding: 16, mainAxisAlignment: 'spaceAround' },
            children: [
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'signal_cellular_alt', iconSize: 24, style: { textColor: '#4F6AF6' } },
                  { type: 'text', binding: { path: 'device.snr', format: '{value} dB', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'SNR', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
              { type: 'shape', shapeType: 'dividerVertical', style: { height: 50, width: 1 } },
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'network_check', iconSize: 24, style: { textColor: '#22C55E' } },
                  { type: 'text', binding: { path: 'device.rssi', format: '{value} dBm', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'RSSI', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
            ],
          },
        },
      },
      // 3. Environment - matches WidgetTemplates.environmentWidget()
      {
        name: 'Environment',
        description: 'Temperature, humidity, and pressure display',
        author: 'Socialmesh',
        authorId: 'official',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 567,
        rating: 4.6,
        ratingCount: 67,
        tags: ['environment', 'temperature', 'humidity', 'pressure', 'sensors'],
        category: 'sensors',
        status: 'approved',
        isFeatured: true,
        schema: {
          name: 'Environment',
          description: 'Temperature, humidity, and pressure display',
          version: '1.0.0',
          tags: ['environment', 'temperature', 'humidity', 'pressure', 'sensors'],
          size: 'medium',
          root: {
            type: 'row',
            style: { padding: 16, mainAxisAlignment: 'spaceAround' },
            children: [
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'thermostat', iconSize: 24, style: { textColor: '#EF4444' } },
                  { type: 'text', binding: { path: 'node.temperature', format: '{value}°', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Temp', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
              { type: 'shape', shapeType: 'dividerVertical', style: { height: 50, width: 1 } },
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'water_drop', iconSize: 24, style: { textColor: '#06B6D4' } },
                  { type: 'text', binding: { path: 'node.humidity', format: '{value}%', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Humidity', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
              { type: 'shape', shapeType: 'dividerVertical', style: { height: 50, width: 1 } },
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'speed', iconSize: 24, style: { textColor: '#8B5CF6' } },
                  { type: 'text', binding: { path: 'node.pressure', format: '{value}', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'hPa', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
            ],
          },
        },
      },
      // 4. Node Info - matches WidgetTemplates.nodeInfoWidget()
      {
        name: 'Node Info',
        description: 'Basic node information card',
        author: 'Socialmesh',
        authorId: 'official',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 432,
        rating: 4.3,
        ratingCount: 45,
        tags: ['node', 'info', 'status'],
        category: 'status',
        status: 'approved',
        isFeatured: true,
        schema: {
          name: 'Node Info',
          description: 'Basic node information card',
          version: '1.0.0',
          tags: ['node', 'info', 'status'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 10 },
            children: [
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'hub', iconSize: 20, style: { textColor: '#E91E8C' } },
                  { type: 'spacer', style: { width: 8 } },
                  { type: 'text', binding: { path: 'node.displayName', defaultValue: 'Unknown Node' }, style: { textColor: '#FFFFFF', fontSize: 16, fontWeight: 'w600' } },
                ],
              },
              {
                type: 'row',
                children: [
                  { type: 'text', text: 'Role: ', style: { textColor: '#666666', fontSize: 12 } },
                  { type: 'text', binding: { path: 'node.role', defaultValue: '--' }, style: { textColor: '#AAAAAA', fontSize: 12 } },
                ],
              },
              {
                type: 'row',
                children: [
                  { type: 'text', text: 'Device: ', style: { textColor: '#666666', fontSize: 12 } },
                  { type: 'text', binding: { path: 'node.hardwareModel', defaultValue: '--' }, style: { textColor: '#AAAAAA', fontSize: 12 } },
                ],
              },
              {
                type: 'row',
                children: [
                  { type: 'icon', iconName: 'schedule', iconSize: 12, style: { textColor: '#555555' } },
                  { type: 'spacer', style: { width: 4 } },
                  { type: 'text', binding: { path: 'node.lastHeard', defaultValue: 'Never' }, style: { textColor: '#555555', fontSize: 11 } },
                ],
              },
            ],
          },
        },
      },
      // 5. GPS Position - matches WidgetTemplates.gpsWidget()
      {
        name: 'GPS Position',
        description: 'Show GPS coordinates and satellites',
        author: 'Socialmesh',
        authorId: 'official',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 345,
        rating: 4.4,
        ratingCount: 38,
        tags: ['gps', 'position', 'location', 'coordinates'],
        category: 'navigation',
        status: 'approved',
        isFeatured: true,
        schema: {
          name: 'GPS Position',
          description: 'Show GPS coordinates and satellites',
          version: '1.0.0',
          tags: ['gps', 'position', 'location', 'coordinates'],
          size: 'medium',
          root: {
            type: 'row',
            style: { padding: 16, mainAxisAlignment: 'spaceAround' },
            children: [
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'gps_fixed', iconSize: 24, style: { textColor: '#22C55E' } },
                  { type: 'text', binding: { path: 'node.latitude', format: '{value}°', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Lat', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
              { type: 'shape', shapeType: 'dividerVertical', style: { height: 50, width: 1 } },
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'explore', iconSize: 24, style: { textColor: '#4F6AF6' } },
                  { type: 'text', binding: { path: 'node.longitude', format: '{value}°', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Lon', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
              { type: 'shape', shapeType: 'dividerVertical', style: { height: 50, width: 1 } },
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'satellite_alt', iconSize: 24, style: { textColor: '#F59E0B' } },
                  { type: 'text', binding: { path: 'node.satsInView', defaultValue: '--' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Sats', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
            ],
          },
        },
      },
      // 6. Network Overview - matches WidgetTemplates.networkOverviewWidget()
      {
        name: 'Network Overview',
        description: 'Mesh network status at a glance',
        author: 'Socialmesh',
        authorId: 'official',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 789,
        rating: 4.7,
        ratingCount: 112,
        tags: ['network', 'mesh', 'nodes', 'status'],
        category: 'network',
        status: 'approved',
        isFeatured: true,
        schema: {
          name: 'Network Overview',
          description: 'Mesh network status at a glance',
          version: '1.0.0',
          tags: ['network', 'mesh', 'nodes', 'status'],
          size: 'medium',
          root: {
            type: 'row',
            style: { padding: 16, mainAxisAlignment: 'spaceAround' },
            children: [
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'check_circle', iconSize: 24, style: { textColor: '#4ADE80' }, condition: { bindingPath: 'node.isOnline', operator: 'equals', value: true } },
                  { type: 'text', text: 'Online', style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Status', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
              { type: 'shape', shapeType: 'dividerVertical', style: { height: 50, width: 1 } },
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'people_outline', iconSize: 24, style: { textColor: '#4F6AF6' } },
                  { type: 'text', binding: { path: 'network.totalNodes', defaultValue: '0' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Nodes', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
              { type: 'shape', shapeType: 'dividerVertical', style: { height: 50, width: 1 } },
              {
                type: 'column',
                style: { alignment: 'center' },
                children: [
                  { type: 'icon', iconName: 'chat_bubble_outline', iconSize: 24, style: { textColor: '#4F6AF6' } },
                  { type: 'text', binding: { path: 'messaging.recentCount', defaultValue: '0' }, style: { fontSize: 16, fontWeight: 'w600', textColor: '#FFFFFF' } },
                  { type: 'text', text: 'Messages', style: { fontSize: 11, textColor: '#888888' } },
                ],
              },
            ],
          },
        },
      },
      // 7. Quick Actions - matches WidgetTemplates.quickActionsWidget()
      {
        name: 'Quick Actions',
        description: 'Common mesh actions at a glance',
        author: 'Socialmesh',
        authorId: 'official',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 567,
        rating: 4.5,
        ratingCount: 52,
        tags: ['actions', 'quick', 'compose', 'send'],
        category: 'actions',
        status: 'approved',
        isFeatured: true,
        schema: {
          name: 'Quick Actions',
          description: 'Common mesh actions at a glance',
          version: '1.0.0',
          tags: ['actions', 'quick', 'compose', 'send'],
          size: 'medium',
          root: {
            type: 'column',
            style: { padding: 12, spacing: 8 },
            children: [
              {
                type: 'row',
                style: { spacing: 8 },
                children: [
                  {
                    type: 'container',
                    style: {
                      flex: 1,
                      padding: 8,
                      borderRadius: 12,
                      backgroundColor: 'accent:0.08',
                      borderColor: 'accent:0.2',
                      borderWidth: 1,
                      alignment: 'center',
                    },
                    action: { type: 'sendMessage', requiresNodeSelection: true, requiresChannelSelection: true, label: 'Quick Message' },
                    children: [
                      { type: 'icon', iconName: 'send', iconSize: 22, style: { textColor: 'accent' } },
                      { type: 'spacer', style: { height: 4 } },
                      { type: 'text', text: 'Quick\nMessage', style: { textColor: 'accent', fontSize: 9, fontWeight: 'w600', textAlign: 'center' } },
                    ],
                  },
                  {
                    type: 'container',
                    style: {
                      flex: 1,
                      padding: 8,
                      borderRadius: 12,
                      backgroundColor: 'accent:0.08',
                      borderColor: 'accent:0.2',
                      borderWidth: 1,
                      alignment: 'center',
                    },
                    action: { type: 'shareLocation', label: 'Share Location' },
                    children: [
                      { type: 'icon', iconName: 'location_on', iconSize: 22, style: { textColor: 'accent' } },
                      { type: 'spacer', style: { height: 4 } },
                      { type: 'text', text: 'Share\nLocation', style: { textColor: 'accent', fontSize: 9, fontWeight: 'w600', textAlign: 'center' } },
                    ],
                  },
                  {
                    type: 'container',
                    style: {
                      flex: 1,
                      padding: 8,
                      borderRadius: 12,
                      backgroundColor: 'accent:0.08',
                      borderColor: 'accent:0.2',
                      borderWidth: 1,
                      alignment: 'center',
                    },
                    action: { type: 'traceroute', requiresNodeSelection: true, label: 'Traceroute' },
                    children: [
                      { type: 'icon', iconName: 'route', iconSize: 22, style: { textColor: 'accent' } },
                      { type: 'spacer', style: { height: 4 } },
                      { type: 'text', text: 'Traceroute', style: { textColor: 'accent', fontSize: 9, fontWeight: 'w600', textAlign: 'center' } },
                    ],
                  },
                  {
                    type: 'container',
                    style: {
                      flex: 1,
                      padding: 8,
                      borderRadius: 12,
                      backgroundColor: 'accent:0.08',
                      borderColor: 'accent:0.2',
                      borderWidth: 1,
                      alignment: 'center',
                    },
                    action: { type: 'requestPositions', label: 'Request Positions' },
                    children: [
                      { type: 'icon', iconName: 'refresh', iconSize: 22, style: { textColor: 'accent' } },
                      { type: 'spacer', style: { height: 4 } },
                      { type: 'text', text: 'Request\nPositions', style: { textColor: 'accent', fontSize: 9, fontWeight: 'w600', textAlign: 'center' } },
                    ],
                  },
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
    status?: string;
  } = {}): MarketplaceResponse {
    const { page = 1, limit = 20, category, sortBy = 'downloads', search, status = 'approved' } = options;
    const offset = (page - 1) * limit;

    let whereClause = 'status = ?';
    const params: (string | number)[] = [status];

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
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, status, created_at, updated_at, is_featured
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
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, status, created_at, updated_at, is_featured
      FROM widgets
      WHERE is_featured = 1 AND status = 'approved'
      ORDER BY downloads DESC
      LIMIT 10
    `).all() as WidgetRow[];

    return rows.map(this.rowToWidget);
  }

  getWidget(id: string): Widget | null {
    const row = this.db.prepare(`
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, status, created_at, updated_at, is_featured
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
    status?: 'pending' | 'approved' | 'rejected';
  }): Widget {
    const id = uuidv4();
    const now = new Date().toISOString();
    const status = widget.status || 'pending'; // Default to pending for user submissions

    this.db.prepare(`
      INSERT INTO widgets (id, name, description, author, author_id, version, tags, category, schema, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      status,
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
      status: row.status,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      isFeatured: row.is_featured === 1,
    };
  }

  // Report methods
  reportWidget(widgetId: string, userId: string, reason: string): void {
    this.db.prepare(`
      INSERT INTO reports (id, widget_id, user_id, reason, created_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(uuidv4(), widgetId, userId, reason, new Date().toISOString());
  }

  getReports(status: string = 'pending'): Report[] {
    const rows = this.db.prepare(`
      SELECT r.*, w.name as widget_name
      FROM reports r
      JOIN widgets w ON r.widget_id = w.id
      WHERE r.status = ?
      ORDER BY r.created_at DESC
    `).all(status) as ReportRow[];

    return rows.map(row => ({
      id: row.id,
      widgetId: row.widget_id,
      widgetName: row.widget_name,
      userId: row.user_id,
      reason: row.reason,
      status: row.status,
      createdAt: row.created_at,
      resolvedAt: row.resolved_at,
    }));
  }

  resolveReport(reportId: string, status: 'resolved' | 'dismissed'): void {
    this.db.prepare(`
      UPDATE reports SET status = ?, resolved_at = ? WHERE id = ?
    `).run(status, new Date().toISOString(), reportId);
  }

  // Admin methods
  getPendingWidgets(): Widget[] {
    const rows = this.db.prepare(`
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, status, created_at, updated_at, is_featured
      FROM widgets
      WHERE status = 'pending'
      ORDER BY created_at ASC
    `).all() as WidgetRow[];

    return rows.map(this.rowToWidget);
  }

  approveWidget(id: string): boolean {
    const result = this.db.prepare(`
      UPDATE widgets SET status = 'approved', updated_at = ? WHERE id = ? AND status = 'pending'
    `).run(new Date().toISOString(), id);

    return result.changes > 0;
  }

  rejectWidget(id: string, reason: string): boolean {
    const result = this.db.prepare(`
      UPDATE widgets SET status = 'rejected', rejection_reason = ?, updated_at = ? WHERE id = ? AND status = 'pending'
    `).run(reason, new Date().toISOString(), id);

    return result.changes > 0;
  }

  deleteWidget(id: string): boolean {
    const result = this.db.prepare('DELETE FROM widgets WHERE id = ?').run(id);
    return result.changes > 0;
  }

  setFeatured(id: string, featured: boolean): boolean {
    const result = this.db.prepare(`
      UPDATE widgets SET is_featured = ?, updated_at = ? WHERE id = ?
    `).run(featured ? 1 : 0, new Date().toISOString(), id);

    return result.changes > 0;
  }

  getUserWidgets(userId: string): Widget[] {
    const rows = this.db.prepare(`
      SELECT id, name, description, author, author_id, version, thumbnail_url, downloads, rating, rating_count, tags, category, status, created_at, updated_at, is_featured
      FROM widgets
      WHERE author_id = ?
      ORDER BY created_at DESC
    `).all(userId) as WidgetRow[];

    return rows.map(this.rowToWidget);
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
  status: string;
  created_at: string;
  updated_at: string;
  is_featured: number;
}

interface ReportRow {
  id: string;
  widget_id: string;
  widget_name: string;
  user_id: string;
  reason: string;
  status: string;
  created_at: string;
  resolved_at: string | null;
}
