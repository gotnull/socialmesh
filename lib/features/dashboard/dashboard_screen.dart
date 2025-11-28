import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final nodes = ref.watch(nodesProvider);
    final messages = ref.watch(messagesProvider);

    final connectionState = connectionStateAsync.when(
      data: (state) => state,
      loading: () => transport.DeviceConnectionState.connecting,
      error: (error, stackTrace) => transport.DeviceConnectionState.error,
    );

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Meshtastic',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bluetooth,
              color:
                  connectionState == transport.DeviceConnectionState.connected
                  ? AppTheme.primaryGreen
                  : AppTheme.textTertiary,
            ),
            onPressed: () {
              _showConnectionInfo(context, connectedDevice, connectionState);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: connectionState != transport.DeviceConnectionState.connected
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _getConnectionStateText(connectionState),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Device card matching scanner design
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.router,
                              color: AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connectedDevice?.name ?? 'Unknown Device',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  connectedDevice?.type ==
                                          transport.TransportType.ble
                                      ? 'Bluetooth'
                                      : 'USB',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textTertiary,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppTheme.textTertiary,
                            ),
                            onPressed: () => _disconnect(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.group_outlined,
                        label: 'Nodes',
                        value: nodes.length,
                        onTap: () => Navigator.of(context).pushNamed('/nodes'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Messages',
                        value: messages.length,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/messages'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Quick Actions Section
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                _ActionCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Messages',
                  subtitle: 'Send and receive messages',
                  onTap: () => Navigator.of(context).pushNamed('/messages'),
                ),

                _ActionCard(
                  icon: Icons.map_outlined,
                  title: 'Node Map',
                  subtitle: 'View nodes on a map',
                  onTap: () => Navigator.of(context).pushNamed('/map'),
                ),

                _ActionCard(
                  icon: Icons.group_outlined,
                  title: 'Nodes',
                  subtitle: 'View all discovered nodes',
                  onTap: () => Navigator.of(context).pushNamed('/nodes'),
                ),

                _ActionCard(
                  icon: Icons.wifi_tethering_outlined,
                  title: 'Channels',
                  subtitle: 'Manage communication channels',
                  onTap: () => Navigator.of(context).pushNamed('/channels'),
                ),

                const SizedBox(height: 32),

                // Signal Strength Live
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Signal Strength Live',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const _SignalStrengthChart(),
              ],
            ),
    );
  }

  String _getConnectionStateText(transport.DeviceConnectionState state) {
    switch (state) {
      case transport.DeviceConnectionState.connecting:
        return 'Connecting...';
      case transport.DeviceConnectionState.connected:
        return 'Connected';
      case transport.DeviceConnectionState.disconnecting:
        return 'Disconnecting...';
      case transport.DeviceConnectionState.error:
        return 'Connection Error';
      case transport.DeviceConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  void _showConnectionInfo(
    BuildContext context,
    transport.DeviceInfo? device,
    transport.DeviceConnectionState state,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device: ${device?.name ?? 'None'}'),
            Text('Status: ${_getConnectionStateText(state)}'),
            if (device?.rssi != null) Text('Signal: ${device!.rssi} dBm'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Are you sure you want to disconnect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final protocol = ref.read(protocolServiceProvider);
      protocol.stop();

      final transport = ref.read(transportProvider);
      await transport.disconnect();

      ref.read(connectedDeviceProvider.notifier).state = null;

      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/scanner');
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalStrengthChart extends ConsumerStatefulWidget {
  const _SignalStrengthChart();

  @override
  ConsumerState<_SignalStrengthChart> createState() =>
      _SignalStrengthChartState();
}

class _SignalStrengthChartState extends ConsumerState<_SignalStrengthChart> {
  final List<_SignalData> _signalHistory = [];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Add initial data point
    _addDataPoint();

    // Update chart every 2 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _addDataPoint();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _addDataPoint() {
    final rssiAsync = ref.read(currentRssiProvider);
    final now = DateTime.now();

    // Add new data point with actual RSSI from protocol stream
    final rssiValue = rssiAsync.valueOrNull?.toDouble() ?? -90.0;
    _signalHistory.add(_SignalData(time: now, rssi: rssiValue));

    // Keep last 30 data points (60 seconds at 2s intervals)
    if (_signalHistory.length > 30) {
      _signalHistory.removeAt(0);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _signalHistory.isNotEmpty;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: hasData
          ? CustomPaint(
              painter: _SignalChartPainter(_signalHistory),
              child: Container(),
            )
          : const Center(
              child: Text(
                'Waiting for signal data...',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
            ),
    );
  }
}

class _SignalData {
  final DateTime time;
  final double rssi;

  _SignalData({required this.time, required this.rssi});
}

class _SignalChartPainter extends CustomPainter {
  final List<_SignalData> data;

  _SignalChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Define insets for labels
    const leftInset = 50.0;
    const bottomInset = 20.0;
    const topInset = 8.0;
    const rightInset = 8.0;

    final chartWidth = size.width - leftInset - rightInset;
    final chartHeight = size.height - topInset - bottomInset;

    final Paint linePaint = Paint()
      ..color = AppTheme.primaryGreen
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint dottedPaint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw dotted horizontal grid lines and Y-axis labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    double minRssi = -90;
    double maxRssi = -30;

    for (int i = 0; i <= 4; i++) {
      final y = topInset + (chartHeight * (i / 4));

      // Draw dotted line
      for (double x = leftInset; x < leftInset + chartWidth; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 4).clamp(leftInset, leftInset + chartWidth), y),
          dottedPaint,
        );
      }

      // Draw Y-axis label (RSSI values)
      final rssiValue = maxRssi - (i * (maxRssi - minRssi) / 4);
      textPainter.text = TextSpan(
        text: '${rssiValue.toInt()}',
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 11,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(8, y - 7));
    }

    // Draw X-axis time labels
    final stepX = chartWidth / (data.length - 1);
    for (int i = 0; i < data.length; i += 5) {
      final x = leftInset + (i * stepX);
      final timeStr =
          '${data[i].time.hour.toString().padLeft(2, '0')}:${data[i].time.minute.toString().padLeft(2, '0')}';
      textPainter.text = TextSpan(
        text: timeStr,
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 10,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 15, size.height - bottomInset + 4));
    }

    Path path = Path();
    Path fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = leftInset + (i * stepX);
      final rssi = data[i].rssi.clamp(minRssi, maxRssi);
      final y =
          topInset +
          chartHeight -
          ((rssi - minRssi) / (maxRssi - minRssi)) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topInset + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(leftInset + chartWidth, topInset + chartHeight);
    fillPath.close();

    // Draw gradient fill
    final Paint fillPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.2),
              AppTheme.primaryGreen.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTWH(leftInset, topInset, chartWidth, chartHeight),
          );

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
