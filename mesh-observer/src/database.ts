/**
 * SQLite Database for persistent node storage
 * 
 * Stores mesh nodes so they survive service restarts.
 * Uses better-sqlite3 for synchronous, fast SQLite access.
 */

import Database from 'better-sqlite3';
import * as path from 'path';
import { MeshNode } from './node-store';

const DB_PATH = process.env.DB_PATH || path.join(__dirname, '..', 'data', 'mesh-nodes.db');

export class MeshDatabase {
  private db: Database.Database;

  constructor(dbPath: string = DB_PATH) {
    // Ensure data directory exists
    const dir = path.dirname(dbPath);
    const fs = require('fs');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    this.db = new Database(dbPath);
    this.db.pragma('journal_mode = WAL'); // Better performance
    this.initSchema();
    console.log(`Database initialized at ${dbPath}`);
  }

  /**
   * Initialize database schema
   */
  private initSchema(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS nodes (
        node_num INTEGER PRIMARY KEY,
        long_name TEXT,
        short_name TEXT,
        hw_model TEXT,
        role TEXT,
        latitude INTEGER,
        longitude INTEGER,
        altitude INTEGER,
        precision INTEGER,
        battery_level INTEGER,
        voltage REAL,
        ch_util REAL,
        air_util_tx REAL,
        uptime INTEGER,
        temperature REAL,
        relative_humidity REAL,
        barometric_pressure REAL,
        lux REAL,
        wind_direction REAL,
        wind_speed REAL,
        wind_gust REAL,
        radiation REAL,
        rainfall_1h REAL,
        rainfall_24h REAL,
        fw_version TEXT,
        region TEXT,
        modem_preset TEXT,
        has_default_ch INTEGER,
        online_local_nodes INTEGER,
        num_online_local_nodes INTEGER,
        neighbors TEXT,
        seen_by TEXT,
        last_heard INTEGER,
        last_device_metrics INTEGER,
        last_environment_metrics INTEGER,
        last_map_report INTEGER,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      );

      CREATE INDEX IF NOT EXISTS idx_nodes_last_heard ON nodes(last_heard);
      CREATE INDEX IF NOT EXISTS idx_nodes_latitude ON nodes(latitude);
      CREATE INDEX IF NOT EXISTS idx_nodes_longitude ON nodes(longitude);
    `);
  }

  /**
   * Save or update a node
   */
  upsertNode(node: MeshNode): void {
    const stmt = this.db.prepare(`
      INSERT INTO nodes (
        node_num, long_name, short_name, hw_model, role,
        latitude, longitude, altitude, precision,
        battery_level, voltage, ch_util, air_util_tx, uptime,
        temperature, relative_humidity, barometric_pressure, lux,
        wind_direction, wind_speed, wind_gust, radiation,
        rainfall_1h, rainfall_24h,
        fw_version, region, modem_preset, has_default_ch,
        online_local_nodes, num_online_local_nodes,
        neighbors, seen_by, last_heard,
        last_device_metrics, last_environment_metrics, last_map_report,
        updated_at
      ) VALUES (
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?,
        ?, ?, ?, ?,
        ?, ?,
        ?, ?, ?,
        ?, ?, ?,
        strftime('%s', 'now')
      )
      ON CONFLICT(node_num) DO UPDATE SET
        long_name = COALESCE(excluded.long_name, long_name),
        short_name = COALESCE(excluded.short_name, short_name),
        hw_model = COALESCE(excluded.hw_model, hw_model),
        role = COALESCE(excluded.role, role),
        latitude = COALESCE(excluded.latitude, latitude),
        longitude = COALESCE(excluded.longitude, longitude),
        altitude = COALESCE(excluded.altitude, altitude),
        precision = COALESCE(excluded.precision, precision),
        battery_level = COALESCE(excluded.battery_level, battery_level),
        voltage = COALESCE(excluded.voltage, voltage),
        ch_util = COALESCE(excluded.ch_util, ch_util),
        air_util_tx = COALESCE(excluded.air_util_tx, air_util_tx),
        uptime = COALESCE(excluded.uptime, uptime),
        temperature = COALESCE(excluded.temperature, temperature),
        relative_humidity = COALESCE(excluded.relative_humidity, relative_humidity),
        barometric_pressure = COALESCE(excluded.barometric_pressure, barometric_pressure),
        lux = COALESCE(excluded.lux, lux),
        wind_direction = COALESCE(excluded.wind_direction, wind_direction),
        wind_speed = COALESCE(excluded.wind_speed, wind_speed),
        wind_gust = COALESCE(excluded.wind_gust, wind_gust),
        radiation = COALESCE(excluded.radiation, radiation),
        rainfall_1h = COALESCE(excluded.rainfall_1h, rainfall_1h),
        rainfall_24h = COALESCE(excluded.rainfall_24h, rainfall_24h),
        fw_version = COALESCE(excluded.fw_version, fw_version),
        region = COALESCE(excluded.region, region),
        modem_preset = COALESCE(excluded.modem_preset, modem_preset),
        has_default_ch = COALESCE(excluded.has_default_ch, has_default_ch),
        online_local_nodes = COALESCE(excluded.online_local_nodes, online_local_nodes),
        num_online_local_nodes = COALESCE(excluded.num_online_local_nodes, num_online_local_nodes),
        neighbors = COALESCE(excluded.neighbors, neighbors),
        seen_by = COALESCE(excluded.seen_by, seen_by),
        last_heard = COALESCE(excluded.last_heard, last_heard),
        last_device_metrics = COALESCE(excluded.last_device_metrics, last_device_metrics),
        last_environment_metrics = COALESCE(excluded.last_environment_metrics, last_environment_metrics),
        last_map_report = COALESCE(excluded.last_map_report, last_map_report),
        updated_at = strftime('%s', 'now')
    `);

    stmt.run(
      node.nodeNum,
      node.longName || null,
      node.shortName || null,
      node.hwModel || null,
      node.role || null,
      node.latitude || null,
      node.longitude || null,
      node.altitude || null,
      node.precision || null,
      node.batteryLevel || null,
      node.voltage || null,
      node.chUtil || null,
      node.airUtilTx || null,
      node.uptime || null,
      node.temperature || null,
      node.relativeHumidity || null,
      node.barometricPressure || null,
      node.lux || null,
      node.windDirection || null,
      node.windSpeed || null,
      node.windGust || null,
      node.radiation || null,
      node.rainfall1 || null,
      node.rainfall24 || null,
      node.fwVersion || null,
      node.region || null,
      node.modemPreset || null,
      node.hasDefaultCh ? 1 : null,
      node.onlineLocalNodes || null,
      node.numOnlineLocalNodes || null,
      node.neighbors ? JSON.stringify(node.neighbors) : null,
      node.seenBy ? JSON.stringify(node.seenBy) : null,
      node.lastHeard || null,
      node.lastDeviceMetrics || null,
      node.lastEnvironmentMetrics || null,
      node.lastMapReport || null
    );
  }

  /**
   * Get all nodes
   */
  getAllNodes(): Map<number, MeshNode> {
    const rows = this.db.prepare('SELECT * FROM nodes').all() as any[];
    const nodes = new Map<number, MeshNode>();

    for (const row of rows) {
      nodes.set(row.node_num, this.rowToNode(row));
    }

    return nodes;
  }

  /**
   * Get nodes updated within the last N hours
   */
  getRecentNodes(hours: number = 24): Map<number, MeshNode> {
    const cutoff = Math.floor(Date.now() / 1000) - (hours * 3600);
    const rows = this.db.prepare(
      'SELECT * FROM nodes WHERE last_heard > ? OR updated_at > ?'
    ).all(cutoff, cutoff) as any[];

    const nodes = new Map<number, MeshNode>();
    for (const row of rows) {
      nodes.set(row.node_num, this.rowToNode(row));
    }
    return nodes;
  }

  /**
   * Get a single node
   */
  getNode(nodeNum: number): MeshNode | null {
    const row = this.db.prepare('SELECT * FROM nodes WHERE node_num = ?').get(nodeNum) as any;
    return row ? this.rowToNode(row) : null;
  }

  /**
   * Get node count
   */
  getNodeCount(): number {
    const result = this.db.prepare('SELECT COUNT(*) as count FROM nodes').get() as { count: number };
    return result.count;
  }

  /**
   * Get count of nodes with valid position
   */
  getNodesWithPositionCount(): number {
    const result = this.db.prepare(
      'SELECT COUNT(*) as count FROM nodes WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND latitude != 0 AND longitude != 0'
    ).get() as { count: number };
    return result.count;
  }

  /**
   * Get count of recently active nodes (last 1 hour)
   */
  getOnlineNodeCount(): number {
    const cutoff = Math.floor(Date.now() / 1000) - 3600; // 1 hour
    const result = this.db.prepare(
      'SELECT COUNT(*) as count FROM nodes WHERE last_heard > ?'
    ).get(cutoff) as { count: number };
    return result.count;
  }

  /**
   * Convert database row to MeshNode
   */
  private rowToNode(row: any): MeshNode {
    return {
      nodeNum: row.node_num,
      longName: row.long_name || '',
      shortName: row.short_name || '',
      hwModel: row.hw_model || 'UNKNOWN',
      role: row.role || 'UNKNOWN',
      latitude: row.latitude,
      longitude: row.longitude,
      altitude: row.altitude,
      precision: row.precision,
      batteryLevel: row.battery_level,
      voltage: row.voltage,
      chUtil: row.ch_util,
      airUtilTx: row.air_util_tx,
      uptime: row.uptime,
      temperature: row.temperature,
      relativeHumidity: row.relative_humidity,
      barometricPressure: row.barometric_pressure,
      lux: row.lux,
      windDirection: row.wind_direction,
      windSpeed: row.wind_speed,
      windGust: row.wind_gust,
      radiation: row.radiation,
      rainfall1: row.rainfall_1h,
      rainfall24: row.rainfall_24h,
      fwVersion: row.fw_version,
      region: row.region,
      modemPreset: row.modem_preset,
      hasDefaultCh: row.has_default_ch === 1,
      onlineLocalNodes: row.online_local_nodes,
      numOnlineLocalNodes: row.num_online_local_nodes,
      neighbors: row.neighbors ? JSON.parse(row.neighbors) : undefined,
      seenBy: row.seen_by ? JSON.parse(row.seen_by) : {},
      lastHeard: row.last_heard,
      lastDeviceMetrics: row.last_device_metrics,
      lastEnvironmentMetrics: row.last_environment_metrics,
      lastMapReport: row.last_map_report,
    };
  }

  /**
   * Purge old nodes that haven't been heard from
   */
  purgeOldNodes(maxAgeDays: number = 30): number {
    const cutoff = Math.floor(Date.now() / 1000) - (maxAgeDays * 24 * 3600);
    const result = this.db.prepare(
      'DELETE FROM nodes WHERE last_heard < ? AND last_heard IS NOT NULL'
    ).run(cutoff);
    return result.changes;
  }

  /**
   * Close database connection
   */
  close(): void {
    this.db.close();
  }
}
