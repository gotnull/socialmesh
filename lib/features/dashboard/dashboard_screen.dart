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
                // Device card matching design
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.router,
                          color: Colors.white,
                          size: 28,
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
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              connectedDevice?.type ==
                                      transport.TransportType.ble
                                  ? 'Bluetooth'
                                  : 'USB Serial',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => _disconnect(context, ref),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

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
                    const SizedBox(width: 16),
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
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

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
                const Text(
                  'Signal Strength Live',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
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
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textTertiary,
                  size: 24,
                ),
              ],
            ),
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

  @override
  void initState() {
    super.initState();
    // Initialize with some sample data
    final now = DateTime.now();
    for (int i = 8; i >= 0; i--) {
      _signalHistory.add(
        _SignalData(
          time: now.subtract(Duration(minutes: i)),
          rssi1: -40 - (i % 3) * 5,
          rssi2: -50 - (i % 4) * 4,
          rssi3: -60 - (i % 2) * 3,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder, width: 1),
      ),
      child: CustomPaint(
        painter: _SignalChartPainter(_signalHistory),
        child: Container(),
      ),
    );
  }
}

class _SignalData {
  final DateTime time;
  final double rssi1;
  final double rssi2;
  final double rssi3;

  _SignalData({
    required this.time,
    required this.rssi1,
    required this.rssi2,
    required this.rssi3,
  });
}

class _SignalChartPainter extends CustomPainter {
  final List<_SignalData> data;

  _SignalChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final Paint gridPaint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    final Paint line1Paint = Paint()
      ..color =
          const Color(0xFF8B5CF6) // Purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint line2Paint = Paint()
      ..color =
          const Color(0xFF3B82F6) // Blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint line3Paint = Paint()
      ..color =
          const Color(0xFFFBBF24) // Yellow
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw grid
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Calculate min/max for scaling
    double minRssi = -90;
    double maxRssi = -30;

    // Draw lines
    final stepX = size.width / (data.length - 1);

    Path path1 = Path();
    Path path2 = Path();
    Path path3 = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y1 =
          size.height -
          ((data[i].rssi1 - minRssi) / (maxRssi - minRssi)) * size.height;
      final y2 =
          size.height -
          ((data[i].rssi2 - minRssi) / (maxRssi - minRssi)) * size.height;
      final y3 =
          size.height -
          ((data[i].rssi3 - minRssi) / (maxRssi - minRssi)) * size.height;

      if (i == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
        path3.moveTo(x, y3);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
        path3.lineTo(x, y3);
      }
    }

    canvas.drawPath(path1, line1Paint);
    canvas.drawPath(path2, line2Paint);
    canvas.drawPath(path3, line3Paint);

    // Draw time labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // First timestamp
    if (data.isNotEmpty) {
      final firstTime =
          '${data.first.time.hour.toString().padLeft(2, '0')}:${data.first.time.minute.toString().padLeft(2, '0')}';
      textPainter.text = TextSpan(
        text: firstTime,
        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, size.height + 8));

      // Last timestamp
      final lastTime =
          '${data.last.time.hour.toString().padLeft(2, '0')}:${data.last.time.minute.toString().padLeft(2, '0')}';
      textPainter.text = TextSpan(
        text: lastTime,
        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width, size.height + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
