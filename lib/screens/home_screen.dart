import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/client_meter_record.dart';
import '../providers/meter_providers.dart';
import '../services/cached_tile_provider.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'add_client_modal.dart';
import 'meter_reading_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isAddPinMode = false;

  // Sol de las Praderas target coordinates
  static const _mapCenter = LatLng(-30.729639, -70.764389);

  // Temporary marker for pin drop preview
  LatLng? _pendingPinLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await ref.read(clientRecordsProvider.notifier).loadClients();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientRecordsProvider);
    final progress = ref.watch(routeProgressProvider);

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            )
          : Stack(
              children: [
                // Map layer
                _buildMap(clients),

                // Top gradient overlay for status bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: MediaQuery.of(context).padding.top + 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.surfaceDark.withValues(alpha: 0.9),
                          AppTheme.surfaceDark.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top header bar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: _buildHeaderBar(progress),
                ),

                // Add pin mode banner
                if (_isAddPinMode)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 78,
                    left: 16,
                    right: 16,
                    child: _buildAddPinBanner(),
                  ),

                // Bottom progress panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomPanel(progress, clients),
                ),
              ],
            ),
      floatingActionButton: _isLoading
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 160),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Add client pin button
                  FloatingActionButton.small(
                    heroTag: 'add_pin',
                    onPressed: _toggleAddPinMode,
                    backgroundColor: _isAddPinMode
                        ? AppTheme.warningAmber
                        : AppTheme.surfaceCard.withValues(alpha: 0.9),
                    child: Icon(
                      _isAddPinMode ? Icons.close : Icons.add_location_alt,
                      size: 20,
                      color: _isAddPinMode ? Colors.white : AppTheme.accentCyan,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Re-center map button
                  FloatingActionButton.small(
                    heroTag: 'center_map',
                    onPressed: _centerMap,
                    backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.9),
                    child: const Icon(Icons.my_location, size: 20),
                  ),
                  const SizedBox(height: 10),
                  // Export button
                  FloatingActionButton.extended(
                    heroTag: 'export_excel',
                    onPressed: _isExporting ? null : () => _exportToExcel(clients),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.file_download_outlined),
                    label: Text(
                      _isExporting ? 'Exportando...' : 'Exportar Excel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAddPinBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningAmber.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app, size: 20, color: AppTheme.warningAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Toque en el mapa para colocar un nuevo medidor',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.warningAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(({int total, int visited, double percent}) progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo / icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryLight, AppTheme.accentCyan],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.water_drop, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aguas del Valle',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Sol de las Praderas • Ruta del día',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Quick stats badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: progress.percent == 100
                  ? AppTheme.visitedGreen.withValues(alpha: 0.2)
                  : AppTheme.primaryLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: progress.percent == 100
                    ? AppTheme.visitedGreen.withValues(alpha: 0.5)
                    : AppTheme.primaryLight.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '${progress.visited}/${progress.total}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: progress.percent == 100
                    ? AppTheme.visitedGreen
                    : AppTheme.accentCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<ClientMeterRecord> clients) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: 15.5,
        maxZoom: 19.0,
        minZoom: 12.0,
        onTap: _isAddPinMode ? _onMapTappedForPin : null,
        onLongPress: _onMapLongPress,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aguasdelvalle.aguas_monte_patria',
          maxZoom: 19,
          tileProvider: CachedTileProvider(),
        ),
        MarkerLayer(
          markers: [
            ...clients.map((client) => _buildMarker(client)),
            // Pending pin preview marker
            if (_pendingPinLocation != null) _buildPendingMarker(),
          ],
        ),
      ],
    );
  }

  Marker _buildPendingMarker() {
    return Marker(
      point: _pendingPinLocation!,
      width: 48,
      height: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.warningAmber,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warningAmber.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
          CustomPaint(
            size: const Size(12, 10),
            painter: _PinTailPainter(color: AppTheme.warningAmber),
          ),
        ],
      ),
    );
  }

  Marker _buildMarker(ClientMeterRecord client) {
    final isVisited = client.isVisited;
    return Marker(
      point: LatLng(client.latitude, client.longitude),
      width: 48,
      height: 56,
      child: GestureDetector(
        onTap: () => _onMarkerTapped(client),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pin head
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isVisited ? AppTheme.visitedGreen : AppTheme.pendingRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (isVisited
                            ? AppTheme.visitedGreen
                            : AppTheme.pendingRed)
                        .withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isVisited ? Icons.check : Icons.water_drop,
                color: Colors.white,
                size: 20,
              ),
            ),
            // Pin tail
            CustomPaint(
              size: const Size(12, 10),
              painter: _PinTailPainter(
                color: isVisited ? AppTheme.visitedGreen : AppTheme.pendingRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMarkerTapped(ClientMeterRecord client) {
    // If in add-pin mode, ignore marker taps
    if (_isAddPinMode) return;
    _showClientPreview(client);
  }

  void _onMapTappedForPin(TapPosition tapPosition, LatLng point) {
    if (!_isAddPinMode) return;
    setState(() {
      _pendingPinLocation = point;
    });
    _showAddClientModal(point);
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng point) {
    // Long press always opens the add client modal, even outside add-pin mode
    setState(() {
      _pendingPinLocation = point;
      _isAddPinMode = true;
    });
    _showAddClientModal(point);
  }

  void _toggleAddPinMode() {
    setState(() {
      _isAddPinMode = !_isAddPinMode;
      if (!_isAddPinMode) {
        _pendingPinLocation = null;
      }
    });
  }

  void _showAddClientModal(LatLng location) {
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddClientModal(location: location),
    ).then((created) {
      setState(() {
        _pendingPinLocation = null;
        _isAddPinMode = false;
      });
    });
  }

  void _showClientPreview(ClientMeterRecord client) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.accentCyan.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Status badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: client.isVisited
                        ? AppTheme.visitedGreen.withValues(alpha: 0.2)
                        : AppTheme.pendingRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        client.isVisited
                            ? Icons.check_circle
                            : Icons.pending_outlined,
                        size: 14,
                        color: client.isVisited
                            ? AppTheme.visitedGreen
                            : AppTheme.pendingRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        client.isVisited ? 'Visitado' : 'Pendiente',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: client.isVisited
                              ? AppTheme.visitedGreen
                              : AppTheme.pendingRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'N° ${client.clientNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Client name
            Text(
              client.ownerName,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Previous readings summary
            Row(
              children: [
                _buildReadingChip(
                    'Hace 2 meses', '${client.readingTwoMonthsAgo} m³'),
                const SizedBox(width: 12),
                _buildReadingChip(
                    'Hace 1 mes', '${client.readingOneMonthAgo} m³'),
                if (client.currentReading != null) ...[
                  const SizedBox(width: 12),
                  _buildReadingChip(
                    'Actual',
                    '${client.currentReading} m³',
                    highlight: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToReading(client);
                },
                icon: Icon(
                  client.isVisited ? Icons.edit : Icons.speed,
                ),
                label: Text(
                  client.isVisited
                      ? 'Editar Lectura'
                      : 'Registrar Lectura',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: client.isVisited
                      ? AppTheme.surfaceCardLight
                      : AppTheme.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingChip(String label, String value,
      {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? AppTheme.accentCyan.withValues(alpha: 0.15)
              : AppTheme.surfaceCardLight,
          borderRadius: BorderRadius.circular(12),
          border: highlight
              ? Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.accentCyan : AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(
    ({int total, int visited, double percent}) progress,
    List<ClientMeterRecord> clients,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: AppTheme.accentCyan.withValues(alpha: 0.15),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                'Progreso de Ruta',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${progress.percent.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.percent / 100,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceCardLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.percent == 100
                    ? AppTheme.visitedGreen
                    : AppTheme.accentCyan,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.pending_outlined,
                '${progress.total - progress.visited}',
                'Pendientes',
                AppTheme.pendingRed,
              ),
              _buildStatItem(
                Icons.check_circle_outline,
                '${progress.visited}',
                'Visitados',
                AppTheme.visitedGreen,
              ),
              _buildStatItem(
                Icons.group_outlined,
                '${progress.total}',
                'Total',
                AppTheme.accentCyan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  void _navigateToReading(ClientMeterRecord client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeterReadingScreen(clientId: client.id),
      ),
    );
  }

  void _centerMap() {
    _mapController.move(_mapCenter, 15.5);
  }

  Future<void> _exportToExcel(List<ClientMeterRecord> clients) async {
    final visitedCount = clients.where((c) => c.isVisited).length;
    if (visitedCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.warningAmber),
                const SizedBox(width: 12),
                Text(
                  'No hay lecturas registradas para exportar',
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isExporting = true);

    try {
      final exportService = ref.read(excelExportServiceProvider);
      final file = await exportService.generateExcel(clients);
      await exportService.shareFile(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.visitedGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Archivo Excel generado exitosamente',
                    style: GoogleFonts.inter(),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.errorRed),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al exportar: $e',
                    style: GoogleFonts.inter(),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

/// Custom painter for the triangular pin tail
class _PinTailPainter extends CustomPainter {
  final Color color;

  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
