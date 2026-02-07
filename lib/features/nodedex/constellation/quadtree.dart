// SPDX-License-Identifier: GPL-3.0-or-later

// Quadtree spatial index for constellation visualization.
//
// Provides O(log n) hit testing and viewport culling for large node sets.
// Each leaf holds up to [_maxItems] items before splitting into four children.
// The tree is rebuilt per-frame only when data changes (not on pan/zoom).

import 'dart:math' as math;
import 'dart:ui';

/// An item stored in the quadtree with a position and associated data.
class QuadtreeItem<T> {
  /// Position in canvas coordinates.
  final Offset position;

  /// The radius of the item for hit testing purposes.
  final double radius;

  /// The associated data payload.
  final T data;

  const QuadtreeItem({
    required this.position,
    required this.radius,
    required this.data,
  });
}

/// Axis-aligned bounding rectangle for quadtree regions.
class QRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const QRect(this.x, this.y, this.width, this.height);

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;
  double get centerX => x + width * 0.5;
  double get centerY => y + height * 0.5;

  /// Whether this rect contains the given point.
  bool containsPoint(Offset point) {
    return point.dx >= x &&
        point.dx <= right &&
        point.dy >= y &&
        point.dy <= bottom;
  }

  /// Whether this rect intersects another rect.
  bool intersects(QRect other) {
    return !(other.left > right ||
        other.right < left ||
        other.top > bottom ||
        other.bottom < top);
  }

  /// Whether this rect fully contains another rect.
  bool containsRect(QRect other) {
    return other.left >= left &&
        other.right <= right &&
        other.top >= top &&
        other.bottom <= bottom;
  }

  /// Expand this rect by [margin] on all sides.
  QRect expand(double margin) {
    return QRect(
      x - margin,
      y - margin,
      width + margin * 2,
      height + margin * 2,
    );
  }

  /// Create from a Rect.
  factory QRect.fromRect(Rect rect) {
    return QRect(rect.left, rect.top, rect.width, rect.height);
  }

  /// Convert to a dart:ui Rect.
  Rect toRect() => Rect.fromLTWH(x, y, width, height);

  @override
  String toString() => 'QRect($x, $y, $width, $height)';
}

/// A quadtree node — either a leaf holding items, or a branch with four
/// children (NW, NE, SW, SE).
class _QuadNode<T> {
  final QRect bounds;
  final int depth;

  List<QuadtreeItem<T>>? _items;
  _QuadNode<T>? _nw;
  _QuadNode<T>? _ne;
  _QuadNode<T>? _sw;
  _QuadNode<T>? _se;

  bool get _isLeaf => _nw == null;

  _QuadNode(this.bounds, this.depth) : _items = [];

  /// Insert an item into this node or its children.
  void insert(QuadtreeItem<T> item, int maxItems, int maxDepth) {
    if (!bounds.containsPoint(item.position)) return;

    if (_isLeaf) {
      _items!.add(item);

      // Split if over capacity and not at max depth.
      if (_items!.length > maxItems && depth < maxDepth) {
        _split(maxItems, maxDepth);
      }
    } else {
      _insertIntoChild(item, maxItems, maxDepth);
    }
  }

  /// Query all items within the given search rectangle.
  void query(QRect searchRect, List<QuadtreeItem<T>> results) {
    if (!bounds.intersects(searchRect)) return;

    if (_isLeaf) {
      for (final item in _items!) {
        if (searchRect.containsPoint(item.position)) {
          results.add(item);
        }
      }
    } else {
      _nw!.query(searchRect, results);
      _ne!.query(searchRect, results);
      _sw!.query(searchRect, results);
      _se!.query(searchRect, results);
    }
  }

  /// Query all items within [radius] of [point].
  void queryRadius(Offset point, double radius, List<QuadtreeItem<T>> results) {
    // Quick reject: check if the circle intersects this node's bounds.
    final searchRect = QRect(
      point.dx - radius,
      point.dy - radius,
      radius * 2,
      radius * 2,
    );
    if (!bounds.intersects(searchRect)) return;

    if (_isLeaf) {
      final radiusSq = radius * radius;
      for (final item in _items!) {
        final dx = item.position.dx - point.dx;
        final dy = item.position.dy - point.dy;
        if (dx * dx + dy * dy <= radiusSq) {
          results.add(item);
        }
      }
    } else {
      _nw!.queryRadius(point, radius, results);
      _ne!.queryRadius(point, radius, results);
      _sw!.queryRadius(point, radius, results);
      _se!.queryRadius(point, radius, results);
    }
  }

  /// Find the nearest item to [point], considering item radius for hit testing.
  /// Returns null if nothing is within [maxDistance].
  (QuadtreeItem<T>, double)? findNearest(Offset point, double maxDistance) {
    if (!bounds.intersects(
      QRect(
        point.dx - maxDistance,
        point.dy - maxDistance,
        maxDistance * 2,
        maxDistance * 2,
      ),
    )) {
      return null;
    }

    QuadtreeItem<T>? best;
    double bestDist = maxDistance;

    if (_isLeaf) {
      for (final item in _items!) {
        final dx = item.position.dx - point.dx;
        final dy = item.position.dy - point.dy;
        final dist = math.sqrt(dx * dx + dy * dy) - item.radius;
        if (dist < bestDist) {
          bestDist = dist;
          best = item;
        }
      }
    } else {
      // Search children in order of distance to point for early pruning.
      final children = [_nw!, _ne!, _sw!, _se!];
      children.sort((a, b) {
        final aDist = _distToRect(point, a.bounds);
        final bDist = _distToRect(point, b.bounds);
        return aDist.compareTo(bDist);
      });

      for (final child in children) {
        if (_distToRect(point, child.bounds) > bestDist) continue;
        final result = child.findNearest(point, bestDist);
        if (result != null && result.$2 < bestDist) {
          best = result.$1;
          bestDist = result.$2;
        }
      }
    }

    if (best == null) return null;
    return (best, bestDist);
  }

  /// Count total items in this subtree.
  int get totalItems {
    if (_isLeaf) return _items!.length;
    return _nw!.totalItems +
        _ne!.totalItems +
        _sw!.totalItems +
        _se!.totalItems;
  }

  /// Get all items in this subtree.
  void allItems(List<QuadtreeItem<T>> results) {
    if (_isLeaf) {
      results.addAll(_items!);
    } else {
      _nw!.allItems(results);
      _ne!.allItems(results);
      _sw!.allItems(results);
      _se!.allItems(results);
    }
  }

  // -- Private ----------------------------------------------------------------

  void _split(int maxItems, int maxDepth) {
    final halfW = bounds.width * 0.5;
    final halfH = bounds.height * 0.5;
    final x = bounds.x;
    final y = bounds.y;
    final nextDepth = depth + 1;

    _nw = _QuadNode(QRect(x, y, halfW, halfH), nextDepth);
    _ne = _QuadNode(QRect(x + halfW, y, halfW, halfH), nextDepth);
    _sw = _QuadNode(QRect(x, y + halfH, halfW, halfH), nextDepth);
    _se = _QuadNode(QRect(x + halfW, y + halfH, halfW, halfH), nextDepth);

    // Redistribute items into children.
    final items = _items!;
    _items = null;

    for (final item in items) {
      _insertIntoChild(item, maxItems, maxDepth);
    }
  }

  void _insertIntoChild(QuadtreeItem<T> item, int maxItems, int maxDepth) {
    if (item.position.dx <= bounds.centerX) {
      if (item.position.dy <= bounds.centerY) {
        _nw!.insert(item, maxItems, maxDepth);
      } else {
        _sw!.insert(item, maxItems, maxDepth);
      }
    } else {
      if (item.position.dy <= bounds.centerY) {
        _ne!.insert(item, maxItems, maxDepth);
      } else {
        _se!.insert(item, maxItems, maxDepth);
      }
    }
  }

  static double _distToRect(Offset point, QRect rect) {
    final dx = math.max(
      rect.left - point.dx,
      math.max(0, point.dx - rect.right),
    );
    final dy = math.max(
      rect.top - point.dy,
      math.max(0, point.dy - rect.bottom),
    );
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// A quadtree for spatial indexing of 2D point items.
///
/// Supports:
/// - Rectangular range queries (viewport culling)
/// - Radius queries (proximity search)
/// - Nearest-neighbor search (hit testing)
///
/// Typical usage:
/// ```dart
/// final tree = Quadtree<int>(bounds: QRect(0, 0, 1000, 1000));
/// tree.insert(QuadtreeItem(position: Offset(50, 50), radius: 5, data: 1));
/// final visible = tree.queryRect(viewportRect);
/// final nearest = tree.findNearest(tapPoint, maxDistance: 30);
/// ```
class Quadtree<T> {
  /// Maximum items per leaf before splitting.
  static const int _maxItems = 8;

  /// Maximum tree depth to prevent degenerate splitting.
  static const int _maxDepth = 12;

  final _QuadNode<T> _root;

  /// The bounding rectangle of the entire tree.
  final QRect bounds;

  /// Total number of items in the tree.
  int _count = 0;
  int get count => _count;

  /// Creates a quadtree with the given spatial bounds.
  Quadtree({required this.bounds}) : _root = _QuadNode(bounds, 0);

  /// Insert an item into the tree.
  ///
  /// Items outside [bounds] are silently ignored.
  void insert(QuadtreeItem<T> item) {
    _root.insert(item, _maxItems, _maxDepth);
    _count++;
  }

  /// Bulk insert a list of items.
  void insertAll(List<QuadtreeItem<T>> items) {
    for (final item in items) {
      insert(item);
    }
  }

  /// Query all items within [searchRect].
  ///
  /// Used for viewport culling — pass the visible canvas rect to get
  /// only the nodes that need rendering.
  List<QuadtreeItem<T>> queryRect(QRect searchRect) {
    final results = <QuadtreeItem<T>>[];
    _root.query(searchRect, results);
    return results;
  }

  /// Query all items within [radius] of [center].
  ///
  /// Used for proximity-based interactions (e.g., showing nearby labels).
  List<QuadtreeItem<T>> queryRadius(Offset center, double radius) {
    final results = <QuadtreeItem<T>>[];
    _root.queryRadius(center, radius, results);
    return results;
  }

  /// Find the nearest item to [point] within [maxDistance].
  ///
  /// Takes item radius into account — an item is "hit" if the point
  /// is within (center distance - item radius). Returns null if nothing
  /// is close enough.
  ///
  /// Used for tap/click hit testing.
  (QuadtreeItem<T> item, double distance)? findNearest(
    Offset point, {
    double maxDistance = 30.0,
  }) {
    return _root.findNearest(point, maxDistance);
  }

  /// Get all items in the tree.
  List<QuadtreeItem<T>> get allItems {
    final results = <QuadtreeItem<T>>[];
    _root.allItems(results);
    return results;
  }

  /// Build a quadtree from a list of items.
  ///
  /// Computes bounds automatically from the items with [padding] margin.
  factory Quadtree.fromItems(
    List<QuadtreeItem<T>> items, {
    double padding = 50.0,
  }) {
    if (items.isEmpty) {
      return Quadtree(bounds: const QRect(0, 0, 1, 1));
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final item in items) {
      if (item.position.dx < minX) minX = item.position.dx;
      if (item.position.dx > maxX) maxX = item.position.dx;
      if (item.position.dy < minY) minY = item.position.dy;
      if (item.position.dy > maxY) maxY = item.position.dy;
    }

    // Ensure minimum size to avoid degenerate trees.
    final width = math.max(maxX - minX + padding * 2, 1.0);
    final height = math.max(maxY - minY + padding * 2, 1.0);

    final tree = Quadtree<T>(
      bounds: QRect(minX - padding, minY - padding, width, height),
    );
    tree.insertAll(items);
    return tree;
  }
}
