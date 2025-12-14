import { NodeStore, MeshNode } from './node-store';

describe('NodeStore', () => {
  let store: NodeStore;

  beforeEach(() => {
    store = new NodeStore(24); // 24 hour expiry
  });

  afterEach(() => {
    store.dispose();
  });

  describe('updateNode', () => {
    it('should create a new node when it does not exist', () => {
      store.updateNode(123456789, {
        longName: 'Test Node',
        shortName: 'TN',
        latitude: 37.7749,
        longitude: -122.4194,
      }, 'msh/US/2/e/LongFast/!abcd1234');

      const node = store.getNode(123456789);
      expect(node).toBeDefined();
      expect(node?.longName).toBe('Test Node');
      expect(node?.shortName).toBe('TN');
      expect(node?.latitude).toBe(37.7749);
      expect(node?.longitude).toBe(-122.4194);
    });

    it('should merge data when updating existing node', () => {
      // First update with position
      store.updateNode(123456789, {
        latitude: 37.7749,
        longitude: -122.4194,
      }, 'topic1');

      // Second update with telemetry
      store.updateNode(123456789, {
        batteryLevel: 85,
        voltage: 3.9,
      }, 'topic2');

      const node = store.getNode(123456789);
      expect(node?.latitude).toBe(37.7749);
      expect(node?.longitude).toBe(-122.4194);
      expect(node?.batteryLevel).toBe(85);
      expect(node?.voltage).toBe(3.9);
    });

    it('should track seenBy topics', () => {
      store.updateNode(123456789, { longName: 'Node1' }, 'gateway1');
      store.updateNode(123456789, { shortName: 'N1' }, 'gateway2');

      const node = store.getNode(123456789);
      expect(Object.keys(node?.seenBy || {})).toContain('gateway1');
      expect(Object.keys(node?.seenBy || {})).toContain('gateway2');
    });

    it('should merge neighbors correctly', () => {
      store.updateNode(123456789, {
        neighbors: {
          'abc123': { snr: 5.5, updated: 1000 },
        },
      }, 'topic1');

      store.updateNode(123456789, {
        neighbors: {
          'def456': { snr: 3.2, updated: 1001 },
        },
      }, 'topic1');

      const node = store.getNode(123456789);
      expect(node?.neighbors?.['abc123']).toBeDefined();
      expect(node?.neighbors?.['def456']).toBeDefined();
    });
  });

  describe('getNode', () => {
    it('should return undefined for non-existent node', () => {
      const node = store.getNode(999999999);
      expect(node).toBeUndefined();
    });

    it('should return the node when it exists', () => {
      store.updateNode(123456789, { longName: 'Existing Node' }, 'topic');
      const node = store.getNode(123456789);
      expect(node).toBeDefined();
      expect(node?.longName).toBe('Existing Node');
    });
  });

  describe('getAllNodes', () => {
    it('should return empty object when no nodes', () => {
      const nodes = store.getAllNodes();
      expect(Object.keys(nodes)).toHaveLength(0);
    });

    it('should return all nodes as object with string keys', () => {
      store.updateNode(111111111, { longName: 'Node 1' }, 'topic');
      store.updateNode(222222222, { longName: 'Node 2' }, 'topic');
      store.updateNode(333333333, { longName: 'Node 3' }, 'topic');

      const nodes = store.getAllNodes();
      expect(Object.keys(nodes)).toHaveLength(3);
      expect(nodes['111111111']).toBeDefined();
      expect(nodes['222222222']).toBeDefined();
      expect(nodes['333333333']).toBeDefined();
    });
  });

  describe('getNodeCount', () => {
    it('should return 0 when no nodes', () => {
      expect(store.getNodeCount()).toBe(0);
    });

    it('should return correct count', () => {
      store.updateNode(111111111, {}, 'topic');
      store.updateNode(222222222, {}, 'topic');
      expect(store.getNodeCount()).toBe(2);
    });
  });

  describe('getNodesWithPositionCount', () => {
    it('should return 0 when no nodes have position', () => {
      store.updateNode(111111111, { longName: 'No Position' }, 'topic');
      expect(store.getNodesWithPositionCount()).toBe(0);
    });

    it('should count only nodes with non-zero position', () => {
      store.updateNode(111111111, { latitude: 0, longitude: 0 }, 'topic');
      store.updateNode(222222222, { latitude: 37.7749, longitude: -122.4194 }, 'topic');
      store.updateNode(333333333, { latitude: 40.7128, longitude: -74.0060 }, 'topic');

      expect(store.getNodesWithPositionCount()).toBe(2);
    });
  });

  describe('getOnlineNodeCount', () => {
    it('should count nodes seen within 1 hour', () => {
      const now = Math.floor(Date.now() / 1000);

      // This node will be counted (just added)
      store.updateNode(111111111, {}, 'topic');

      expect(store.getOnlineNodeCount()).toBe(1);
    });
  });

  describe('getLastUpdateTime', () => {
    it('should return ISO string', () => {
      store.updateNode(111111111, {}, 'topic');
      const lastUpdate = store.getLastUpdateTime();
      expect(lastUpdate).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
    });
  });

  describe('default values', () => {
    it('should set default values for new nodes', () => {
      store.updateNode(123456789, {}, 'topic');
      const node = store.getNode(123456789);

      expect(node?.nodeNum).toBe(123456789);
      expect(node?.longName).toBe('');
      expect(node?.shortName).toBe('');
      expect(node?.hwModel).toBe('UNKNOWN');
      expect(node?.role).toBe('UNKNOWN');
      expect(node?.latitude).toBe(0);
      expect(node?.longitude).toBe(0);
    });
  });
});
