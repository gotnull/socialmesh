import '../../core/logging.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/mesh_map_widget.dart';
import '../../providers/help_providers.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/loading_indicator.dart';

/// Screen for downloading and managing offline map regions
class OfflineMapsScreen extends ConsumerStatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  ConsumerState<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends ConsumerState<OfflineMapsScreen> {
  final MapController _mapController = MapController();
  final List<OfflineMapRegion> _regions = [];
  bool _isSelecting = false;
  LatLng? _selectionStart;
  LatLng? _selectionEnd;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  int _downloadedTiles = 0;
  int _totalTiles = 0;
  String? _currentDownloadRegion;

  @override
  void initState() {
    super.initState();
    _loadSavedRegions();
  }

  Future<void> _loadSavedRegions() async {
    setState(() => _isLoading = true);
    try {
      final directory = await _getOfflineTilesDirectory();
      if (await directory.exists()) {
        // List saved regions by scanning directories
        final regionDirs = await directory.list().toList();
        final regions = <OfflineMapRegion>[];

        for (final dir in regionDirs) {
          if (dir is Directory) {
            final name = dir.path.split('/').last;
            final tileFiles = await dir
                .list(recursive: true)
                .where((f) => f is File && f.path.endsWith('.png'))
                .length;
            if (tileFiles > 0) {
              regions.add(
                OfflineMapRegion(
                  name: name,
                  tileCount: tileFiles,
                  downloadDate: (await dir.stat()).modified,
                  path: dir.path,
                ),
              );
            }
          }
        }

        setState(() => _regions.addAll(regions));
      }
    } catch (e) {
      AppLogging.maps('Error loading offline regions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Directory> _getOfflineTilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/offline_tiles');
  }

  void _startSelection() {
    setState(() {
      _isSelecting = true;
      _selectionStart = null;
      _selectionEnd = null;
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelecting = false;
      _selectionStart = null;
      _selectionEnd = null;
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isSelecting) return;

    if (_selectionStart == null) {
      setState(() => _selectionStart = point);
    } else if (_selectionEnd == null) {
      setState(() => _selectionEnd = point);
    }
  }

  int _estimateTileCount() {
    if (_selectionStart == null || _selectionEnd == null) return 0;

    int totalTiles = 0;
    // Count tiles for zoom levels 10-16
    for (int zoom = 10; zoom <= 16; zoom++) {
      final bounds = _getBoundsForSelection();
      final tilesX = _getTileCountForAxis(bounds.west, bounds.east, zoom, true);
      final tilesY = _getTileCountForAxis(
        bounds.south,
        bounds.north,
        zoom,
        false,
      );
      totalTiles += tilesX * tilesY;
    }
    return totalTiles;
  }

  LatLngBounds _getBoundsForSelection() {
    final minLat = math.min(_selectionStart!.latitude, _selectionEnd!.latitude);
    final maxLat = math.max(_selectionStart!.latitude, _selectionEnd!.latitude);
    final minLon = math.min(
      _selectionStart!.longitude,
      _selectionEnd!.longitude,
    );
    final maxLon = math.max(
      _selectionStart!.longitude,
      _selectionEnd!.longitude,
    );
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  int _getTileCountForAxis(double min, double max, int zoom, bool isLongitude) {
    final n = math.pow(2, zoom).toInt();

    int minTile;
    int maxTile;

    if (isLongitude) {
      minTile = ((min + 180.0) / 360.0 * n).floor();
      maxTile = ((max + 180.0) / 360.0 * n).floor();
    } else {
      minTile =
          ((1 -
                      math.log(
                            math.tan(min * math.pi / 180) +
                                1 / math.cos(min * math.pi / 180),
                          ) /
                          math.pi) /
                  2 *
                  n)
              .floor();
      maxTile =
          ((1 -
                      math.log(
                            math.tan(max * math.pi / 180) +
                                1 / math.cos(max * math.pi / 180),
                          ) /
                          math.pi) /
                  2 *
                  n)
              .floor();
    }

    return (maxTile - minTile).abs() + 1;
  }

  Future<void> _downloadRegion(String name) async {
    if (_selectionStart == null || _selectionEnd == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadedTiles = 0;
      _totalTiles = _estimateTileCount();
      _currentDownloadRegion = name;
    });

    try {
      final baseDir = await _getOfflineTilesDirectory();
      final regionDir = Directory('${baseDir.path}/$name');
      if (!await regionDir.exists()) {
        await regionDir.create(recursive: true);
      }

      final bounds = _getBoundsForSelection();
      final client = http.Client();

      // Download tiles for zoom levels 10-16
      for (int zoom = 10; zoom <= 16; zoom++) {
        await _downloadTilesForZoom(client, regionDir, bounds, zoom);
      }

      client.close();

      // Add to regions list
      final tileCount = await regionDir
          .list(recursive: true)
          .where((f) => f is File && f.path.endsWith('.png'))
          .length;

      setState(() {
        _regions.add(
          OfflineMapRegion(
            name: name,
            tileCount: tileCount,
            downloadDate: DateTime.now(),
            path: regionDir.path,
          ),
        );
        _isSelecting = false;
        _selectionStart = null;
        _selectionEnd = null;
      });

      if (mounted) {
        showSuccessSnackBar(context, 'Downloaded $tileCount tiles for "$name"');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Download failed: $e');
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _currentDownloadRegion = null;
      });
    }
  }

  Future<void> _downloadTilesForZoom(
    http.Client client,
    Directory regionDir,
    LatLngBounds bounds,
    int zoom,
  ) async {
    final n = math.pow(2, zoom).toInt();

    // Calculate tile bounds
    final minTileX = ((bounds.west + 180.0) / 360.0 * n).floor();
    final maxTileX = ((bounds.east + 180.0) / 360.0 * n).floor();
    final minTileY =
        ((1 -
                    math.log(
                          math.tan(bounds.north * math.pi / 180) +
                              1 / math.cos(bounds.north * math.pi / 180),
                        ) /
                        math.pi) /
                2 *
                n)
            .floor();
    final maxTileY =
        ((1 -
                    math.log(
                          math.tan(bounds.south * math.pi / 180) +
                              1 / math.cos(bounds.south * math.pi / 180),
                        ) /
                        math.pi) /
                2 *
                n)
            .floor();

    final zoomDir = Directory('${regionDir.path}/$zoom');
    if (!await zoomDir.exists()) {
      await zoomDir.create(recursive: true);
    }

    for (int x = minTileX; x <= maxTileX; x++) {
      for (int y = minTileY; y <= maxTileY; y++) {
        final tilePath = '${zoomDir.path}/${x}_$y.png';
        final tileFile = File(tilePath);

        if (!await tileFile.exists()) {
          try {
            // Use dark style tiles
            final url =
                'https://a.basemaps.cartocdn.com/dark_all/$zoom/$x/$y.png';
            final response = await client.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await tileFile.writeAsBytes(response.bodyBytes);
            }
          } catch (e) {
            // Skip failed tiles
            AppLogging.maps('Failed to download tile $zoom/$x/$y: $e');
          }
        }

        setState(() {
          _downloadedTiles++;
          _downloadProgress = _downloadedTiles / _totalTiles;
        });

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> _deleteRegion(OfflineMapRegion region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: Text(
          'Delete Region',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'Delete "${region.name}" and all its tiles? This cannot be undone.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dir = Directory(region.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        setState(() => _regions.remove(region));

        if (mounted) {
          showSuccessSnackBar(context, 'Deleted "${region.name}"');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to delete: $e');
        }
      }
    }
  }

  void _showDownloadDialog() {
    final tileCount = _estimateTileCount();
    final estimatedSize = (tileCount * 15 / 1024).toStringAsFixed(
      1,
    ); // ~15KB per tile

    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Download Region',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Region Name',
                labelStyle: TextStyle(color: context.textSecondary),
                hintText: 'e.g., Sydney Area',
                hintStyle: TextStyle(
                  color: context.textTertiary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: context.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiles to download:',
                        style: TextStyle(color: context.textSecondary),
                      ),
                      Text(
                        '$tileCount',
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated size:',
                        style: TextStyle(color: context.textSecondary),
                      ),
                      Text(
                        '~$estimatedSize MB',
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Zoom levels:',
                        style: TextStyle(color: context.textSecondary),
                      ),
                      Text(
                        '10-16',
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                showWarningSnackBar(context, 'Please enter a name');
                return;
              }
              Navigator.pop(context);
              _downloadRegion(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HelpTourController(
      topicId: 'offline_maps_overview',
      stepKeys: const {},
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.surface,
          title: Text(_isSelecting ? 'Select Region' : 'Offline Maps'),
          actions: [
            if (_isSelecting)
              IconButton(
                onPressed: _cancelSelection,
                icon: Icon(Icons.close),
                tooltip: 'Cancel',
              )
            else ...[
              IconButton(
                onPressed: _startSelection,
                icon: const Icon(Icons.add_location_alt),
                tooltip: 'Download New Region',
              ),
              IconButton(
                onPressed: () => ref
                    .read(helpProvider.notifier)
                    .startTour('offline_maps_overview'),
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help',
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            // Map for selection using shared MeshMapWidget
            if (_isSelecting || _regions.isEmpty)
              Expanded(
                flex: _isSelecting ? 2 : 1,
                child: Stack(
                  children: [
                    MeshMapWidget(
                      mapController: _mapController,
                      initialCenter: const LatLng(-33.8688, 151.2093),
                      initialZoom: 10,
                      onTap: _onMapTap,
                      additionalLayers: [
                        // Selection rectangle
                        if (_selectionStart != null && _selectionEnd != null)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: [
                                  _selectionStart!,
                                  LatLng(
                                    _selectionStart!.latitude,
                                    _selectionEnd!.longitude,
                                  ),
                                  _selectionEnd!,
                                  LatLng(
                                    _selectionEnd!.latitude,
                                    _selectionStart!.longitude,
                                  ),
                                ],
                                color: context.accentColor.withValues(
                                  alpha: 0.2,
                                ),
                                borderColor: context.accentColor,
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                        // Selection start marker
                        if (_selectionStart != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectionStart!,
                                width: 20,
                                height: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Selection instructions
                    if (_isSelecting)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectionStart == null
                                    ? 'Tap to set first corner'
                                    : _selectionEnd == null
                                    ? 'Tap to set second corner'
                                    : '${_estimateTileCount()} tiles selected',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_selectionEnd != null) ...[
                                SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _showDownloadDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.accentColor,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size(
                                      double.infinity,
                                      44,
                                    ),
                                  ),
                                  child: Text('Download Region'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Download progress
            if (_isDownloading)
              Container(
                padding: const EdgeInsets.all(16),
                color: context.surface,
                child: Column(
                  children: [
                    Row(
                      children: [
                        LoadingIndicator(size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Downloading "$_currentDownloadRegion"...',
                            style: TextStyle(color: context.textPrimary),
                          ),
                        ),
                        Text(
                          '$_downloadedTiles / $_totalTiles',
                          style: TextStyle(color: context.textTertiary),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: context.background,
                      valueColor: AlwaysStoppedAnimation(context.accentColor),
                    ),
                  ],
                ),
              ),

            // Saved regions list
            if (!_isSelecting && _regions.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _regions.length,
                  itemBuilder: (context, index) {
                    final region = _regions[index];
                    return _buildRegionCard(region);
                  },
                ),
              ),

            // Empty state
            if (!_isSelecting && _regions.isEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 64,
                        color: context.textTertiary.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Offline Regions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to download map regions',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionCard(OfflineMapRegion region) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.map, color: context.accentColor),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${region.tileCount} tiles • ${_formatDate(region.downloadDate)}',
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteRegion(region),
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Model for a downloaded offline map region
class OfflineMapRegion {
  final String name;
  final int tileCount;
  final DateTime downloadDate;
  final String path;

  OfflineMapRegion({
    required this.name,
    required this.tileCount,
    required this.downloadDate,
    required this.path,
  });
}
