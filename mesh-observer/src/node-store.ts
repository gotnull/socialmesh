/**
 * Node Store - Persistent storage for mesh node data
 * Uses SQLite for persistence, with in-memory cache for fast access
 */

import { MeshDatabase } from './database';

export interface NodeNeighbor {
  snr?: number;
  updated: number;
}

export interface MeshNode {
  nodeNum: number;
  longName: string;
  shortName: string;
  hwModel: string;
  role: string;
  latitude: number;
  longitude: number;
  altitude?: number;
  precision?: number;
  fwVersion?: string;
  region?: string;
  modemPreset?: string;
  hasDefaultCh?: boolean;
  onlineLocalNodes?: number;
  numOnlineLocalNodes?: number;
  lastMapReport?: number;
  batteryLevel?: number;
  voltage?: number;
  chUtil?: number;
  airUtilTx?: number;
  uptime?: number;
  lastDeviceMetrics?: number;
  temperature?: number;
  relativeHumidity?: number;
  barometricPressure?: number;
  lux?: number;
  windDirection?: number;
  windSpeed?: number;
  windGust?: number;
  radiation?: number;
  rainfall1?: number;
  rainfall24?: number;
  lastEnvironmentMetrics?: number;
  neighbors?: Record<string, NodeNeighbor>;
  seenBy: Record<string, number>;
  lastHeard?: number;
}

export class NodeStore {
  private nodes: Map<number, MeshNode> = new Map();
  private db: MeshDatabase;
  private lastUpdate: Date = new Date();
  private saveInterval: NodeJS.Timeout;
  private pendingSaves: Set<number> = new Set();

  constructor(expiryHours: number = 24, dbPath?: string) {
    // Initialize database
    this.db = new MeshDatabase(dbPath);

    // Load existing nodes from database
    this.loadFromDatabase();

    // Batch save to database every 10 seconds
    this.saveInterval = setInterval(() => this.savePendingNodes(), 10000);
  }

  /**
   * Load nodes from database on startup
   */
  private loadFromDatabase(): void {
    console.log('Loading nodes from database...');
    this.nodes = this.db.getAllNodes();
    console.log(`Loaded ${this.nodes.size} nodes from database`);
  }

  /**
   * Save pending node updates to database
   */
  private savePendingNodes(): void {
    if (this.pendingSaves.size === 0) return;

    const toSave = Array.from(this.pendingSaves);
    this.pendingSaves.clear();

    let saved = 0;
    for (const nodeNum of toSave) {
      const node = this.nodes.get(nodeNum);
      if (node) {
        this.db.upsertNode(node);
        saved++;
      }
    }

    if (saved > 0) {
      console.log(`💾 Saved ${saved} nodes to database (total: ${this.db.getNodeCount()})`);
    }
  }

  /**
   * Update or create a node
   */
  updateNode(nodeNum: number, data: Partial<MeshNode>, topic: string): void {
    const existing = this.nodes.get(nodeNum);
    const now = Math.floor(Date.now() / 1000);

    if (existing) {
      // Merge with existing data
      const updated: MeshNode = {
        ...existing,
        ...data,
        lastHeard: now,
        seenBy: {
          ...existing.seenBy,
          [topic]: now,
        },
      };

      // Merge neighbors if both exist
      if (data.neighbors && existing.neighbors) {
        updated.neighbors = { ...existing.neighbors, ...data.neighbors };
      }

      this.nodes.set(nodeNum, updated);
    } else {
      // Create new node
      const newNode: MeshNode = {
        nodeNum,
        longName: '',
        shortName: '',
        hwModel: 'UNKNOWN',
        role: 'UNKNOWN',
        latitude: 0,
        longitude: 0,
        lastHeard: now,
        seenBy: { [topic]: now },
        ...data,
      };
      this.nodes.set(nodeNum, newNode);
    }

    // Mark for database save
    this.pendingSaves.add(nodeNum);
    this.lastUpdate = new Date();
  }

  /**
   * Get a single node
   */
  getNode(nodeNum: number): MeshNode | undefined {
    return this.nodes.get(nodeNum);
  }

  /**
   * Get all nodes as object
   */
  getAllNodes(): Record<string, MeshNode> {
    const result: Record<string, MeshNode> = {};
    for (const [nodeNum, node] of this.nodes) {
      result[nodeNum.toString()] = node;
    }
    return result;
  }

  /**
   * Get total node count
   */
  getNodeCount(): number {
    return this.nodes.size;
  }

  /**
   * Get count of nodes with valid position
   */
  getNodesWithPositionCount(): number {
    let count = 0;
    for (const node of this.nodes.values()) {
      if (node.latitude !== 0 || node.longitude !== 0) {
        count++;
      }
    }
    return count;
  }

  /**
   * Get count of online nodes (seen within 2 hours)
   */
  getOnlineNodeCount(): number {
    const twoHoursAgo = Math.floor(Date.now() / 1000) - 7200;
    let count = 0;

    for (const node of this.nodes.values()) {
      if (node.lastHeard && node.lastHeard > twoHoursAgo) {
        count++;
      }
    }
    return count;
  }

  /**
   * Get last update timestamp
   */
  getLastUpdateTime(): string {
    return this.lastUpdate.toISOString();
  }

  /**
   * Purge old nodes from database
   */
  purgeOldNodes(maxAgeDays: number = 30): number {
    const purged = this.db.purgeOldNodes(maxAgeDays);
    if (purged > 0) {
      // Reload from database after purge
      this.loadFromDatabase();
      console.log(`Purged ${purged} old nodes`);
    }
    return purged;
  }

  /**
   * Get database stats
   */
  getDatabaseStats(): { totalInDb: number; withPosition: number; online: number } {
    return {
      totalInDb: this.db.getNodeCount(),
      withPosition: this.db.getNodesWithPositionCount(),
      online: this.db.getOnlineNodeCount(),
    };
  }

  /**
   * Stop intervals and close database
   */
  dispose(): void {
    clearInterval(this.saveInterval);
    // Final save of pending nodes
    this.savePendingNodes();
    this.db.close();
  }
}
