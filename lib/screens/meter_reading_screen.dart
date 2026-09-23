import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_meter_record.dart';
import '../providers/meter_providers.dart';
import '../services/photo_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

class MeterReadingScreen extends ConsumerStatefulWidget {
  final String clientId;

  const MeterReadingScreen({super.key, required this.clientId});

  @override
  ConsumerState<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends ConsumerState<MeterReadingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _readingController = TextEditingController();
  final _readingFocusNode = FocusNode();
  final _observationsController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isSaving = false;
  int? _liveReading;

  /// When set, the meter could not be read and the reading input is hidden.
  NonReadingReason? _nonReadingReason;

  late final PhotoService _photoService;
  bool _isTakingPhoto = false;
  bool _isFixingLocation = false;

  /// Evidence photo shown on screen (saved with the visit).
  String? _photoPath;

  /// Photo stored with the visit when the screen opened.
  String? _initialPhotoPath;

  /// Photos taken on this screen; the ones not saved are deleted on exit.
  final _takenPhotos = <String>{};

  /// Photo actually saved with the visit, once saving succeeds.
  String? _savedPhotoPath;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();

    // Pre-fill once with the existing reading (edit mode). Done before the
    // listener is attached so it never triggers setState during build, and
    // never runs again, so the user can clear the field to type a new value.
    final client = ref
        .read(clientRecordsProvider)
        .where((c) => c.id == widget.clientId)
        .firstOrNull;
    final existingReading = client?.currentReading;
    if (existingReading != null) {
      _readingController.text = existingReading.toString();
      _liveReading = existingReading;
    }
    _nonReadingReason = NonReadingReason.fromLabel(client?.nonReadingReason);
    _observationsController.text = client?.observations ?? '';
    _photoPath = _initialPhotoPath = client?.photoPath;
    _photoService = ref.read(photoServiceProvider);

    _readingController.addListener(_onReadingChanged);
  }

  void _onReadingChanged() {
    final text = _readingController.text;
    final parsed = text.isEmpty ? null : int.tryParse(text);
    if (parsed == _liveReading) return;
    setState(() => _liveReading = parsed);
  }

  @override
  void dispose() {
    // Photos taken here but not saved (replaced, removed, or the reader
    // left without saving) would only waste storage.
    for (final path in _takenPhotos) {
      if (path != _savedPhotoPath) _photoService.deletePhoto(path);
    }
    _readingController.removeListener(_onReadingChanged);
    _readingController.dispose();
    _readingFocusNode.dispose();
    _observationsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientRecordsProvider);
    final client = clients.where((c) => c.id == widget.clientId).firstOrNull;

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Cliente no encontrado')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lectura de Medidor',
          style: AppFonts.text(fontWeight: FontWeight.w700),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client info card
                _buildClientInfoCard(client),

                // Clients without an official location have no map pin
                if (!client.hasLocation) ...[
                  const SizedBox(height: 12),
                  _buildFixLocationCard(client),
                ],
                const SizedBox(height: 20),

                // Previous readings
                _buildPreviousReadingsCard(client),
                const SizedBox(height: 20),

                // Reading taken or reason why it could not be taken
                _buildNonReadingReasonSelector(),
                const SizedBox(height: 20),

                if (_nonReadingReason == null) ...[
                  // Current reading input
                  _buildCurrentReadingInput(client),
                  const SizedBox(height: 20),

                  // Consumption summary
                  _buildConsumptionSummary(client),
                  const SizedBox(height: 20),
                ],

                // Free-text notes
                _buildObservationsInput(),
                const SizedBox(height: 12),

                // Optional evidence photo
                _buildPhotoEvidence(client),
                const SizedBox(height: 32),

                // Save button
                _buildSaveButton(client),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixLocationCard(ClientMeterRecord client) {
    return Container(
      key: const Key('fixLocationCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningAmber, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off_outlined,
                  color: AppTheme.warningAmber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Este cliente aún no tiene ubicación en el mapa. Párese '
                  'junto al medidor y fíjela con el GPS.',
                  style: AppFonts.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isFixingLocation ? null : () => _fixLocation(client),
            icon: _isFixingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _isFixingLocation
                  ? 'Obteniendo ubicación...'
                  : 'Fijar Ubicación en el Mapa (GPS)',
              style: AppFonts.text(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningAmber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fixLocation(ClientMeterRecord client) async {
    setState(() => _isFixingLocation = true);
    try {
      final position = await ref
          .read(clientRecordsProvider.notifier)
          .fixLocationFromGps(client.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            position != null
                ? 'Ubicación fijada: ${position.latitude.toStringAsFixed(5)}, '
                    '${position.longitude.toStringAsFixed(5)}'
                : 'No se pudo obtener la ubicación. Active el GPS y el '
                    'permiso de ubicación, e intente de nuevo.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al fijar la ubicación: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFixingLocation = false);
    }
  }

  Widget _buildClientInfoCard(ClientMeterRecord client) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.4),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryLight.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppTheme.accentCyan,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombre Propietario',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.ownerName,
                      style: AppFonts.text(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                Text(
                  'N° Cliente: ',
                  style: AppFonts.text(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  client.clientNumber,
                  style: AppFonts.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentCyan,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousReadingsCard(ClientMeterRecord client) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Lecturas Anteriores',
                style: AppFonts.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildReadingTile(
                  'Hace 2 Meses',
                  '${client.readingTwoMonthsAgo}',
                  'm³',
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              // Arrow
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildReadingTile(
                  'Hace 1 Mes',
                  '${client.readingOneMonthAgo}',
                  'm³',
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Historical consumption
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Consumo mes anterior: ',
                  style: AppFonts.text(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '${client.readingOneMonthAgo - client.readingTwoMonthsAgo} m³',
                  style: AppFonts.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingTile(
      String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppFonts.text(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppFonts.text(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            unit,
            style: AppFonts.text(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonReadingReasonSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _nonReadingReason != null
              ? AppTheme.warningAmber.withValues(alpha: 0.5)
              : AppTheme.surfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_gmailerrorred,
                  size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Resultado de la visita',
                style: AppFonts.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<NonReadingReason?>(
            key: const Key('nonReadingReasonDropdown'),
            initialValue: _nonReadingReason,
            isExpanded: true,
            dropdownColor: AppTheme.surface,
            style: AppFonts.text(fontSize: 15, color: AppTheme.textPrimary),
            items: [
              DropdownMenuItem<NonReadingReason?>(
                value: null,
                child: Text(
                  'Se tomó la lectura',
                  style: AppFonts.text(color: AppTheme.textPrimary),
                ),
              ),
              for (final reason in NonReadingReason.values)
                DropdownMenuItem<NonReadingReason?>(
                  value: reason,
                  child: Text(
                    'No se pudo leer: ${reason.label}',
                    style: AppFonts.text(color: AppTheme.textPrimary),
                  ),
                ),
            ],
            onChanged: (reason) {
              setState(() => _nonReadingReason = reason);
              // Re-validate observations, which are required for "Otro"
              _formKey.currentState?.validate();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsInput() {
    return TextFormField(
      key: const Key('observationsField'),
      controller: _observationsController,
      maxLines: 3,
      maxLength: 250,
      textCapitalization: TextCapitalization.sentences,
      style: AppFonts.text(fontSize: 15, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: _nonReadingReason == NonReadingReason.other
            ? 'Observaciones (obligatorio)'
            : 'Observaciones (opcional)',
        alignLabelWithHint: true,
        prefixIcon: const Icon(Icons.notes, color: AppTheme.textSecondary),
      ),
      validator: (value) {
        if (_nonReadingReason == NonReadingReason.other &&
            (value == null || value.trim().isEmpty)) {
          return 'Describa el motivo en observaciones';
        }
        return null;
      },
    );
  }

  Widget _buildPhotoEvidence(ClientMeterRecord client) {
    final photoPath = _photoPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photoPath != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(photoPath),
                  key: const Key('evidencePhotoThumbnail'),
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  cacheWidth: 420,
                  errorBuilder: (_, _, _) => Container(
                    width: 140,
                    height: 140,
                    color: AppTheme.surfaceVariant,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppTheme.textSecondary, size: 36),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: AppTheme.textPrimary.withValues(alpha: 0.8),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Eliminar foto',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => setState(() => _photoPath = null),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isTakingPhoto || _isSaving
                ? null
                : () => _takePhoto(client),
            icon: _isTakingPhoto
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined),
            label: Text(
              photoPath == null
                  ? 'Tomar foto de evidencia (Opcional)'
                  : 'Volver a tomar foto',
              style: AppFonts.text(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryLight,
              side: const BorderSide(color: AppTheme.primaryLight, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _takePhoto(ClientMeterRecord client) async {
    setState(() => _isTakingPhoto = true);
    try {
      final path = await _photoService.takePhoto(client.id);
      if (path == null) return; // cancelled
      _takenPhotos.add(path);
      if (mounted) setState(() => _photoPath = path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la cámara. Revise el permiso de '
                'cámara en los ajustes del teléfono.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Widget _buildCurrentReadingInput(ClientMeterRecord client) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentCyan.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speed,
                  size: 20,
                  color: AppTheme.accentCyan,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Lectura Actual del Medidor',
                style: AppFonts.text(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _readingController,
            focusNode: _readingFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppFonts.text(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0000',
              hintStyle: AppFonts.text(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                letterSpacing: 2,
              ),
              suffixText: 'm³',
              suffixStyle: AppFonts.text(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese la lectura del medidor';
              }
              final reading = int.tryParse(value);
              if (reading == null) {
                return 'Ingrese un número válido';
              }
              return null;
            },
          ),
          // Warning if reading is lower than previous
          if (_liveReading != null &&
              _liveReading! < client.readingOneMonthAgo)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warningAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'La lectura actual es menor que la lectura anterior (${client.readingOneMonthAgo} m³). Verifique el medidor.',
                        style: AppFonts.text(
                          fontSize: 12,
                          color: AppTheme.warningAmber,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConsumptionSummary(ClientMeterRecord client) {
    final consumption = _liveReading != null
        ? _liveReading! - client.readingOneMonthAgo
        : null;
    final isNegative = consumption != null && consumption < 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: consumption != null
            ? LinearGradient(
                colors: isNegative
                    ? [
                        AppTheme.warningAmber.withValues(alpha: 0.15),
                        AppTheme.surface,
                      ]
                    : [
                        AppTheme.visitedGreen.withValues(alpha: 0.15),
                        AppTheme.surface,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: consumption == null ? AppTheme.surface : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.water_drop_outlined,
                size: 20,
                color: consumption == null
                    ? AppTheme.textSecondary
                    : isNegative
                        ? AppTheme.warningAmber
                        : AppTheme.visitedGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Consumo Calculado',
                style: AppFonts.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            consumption != null ? '$consumption' : '—',
            style: AppFonts.text(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: consumption == null
                  ? AppTheme.textSecondary.withValues(alpha: 0.3)
                  : isNegative
                      ? AppTheme.warningAmber
                      : AppTheme.visitedGreen,
            ),
          ),
          Text(
            'metros cúbicos (m³)',
            style: AppFonts.text(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ClientMeterRecord client) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveReading(client),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.visitedGreen,
          disabledBackgroundColor: AppTheme.visitedGreen.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppTheme.visitedGreen.withValues(alpha: 0.4),
        ),
        child: _isSaving
            // Saving waits for a GPS fix (up to a few seconds)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Obteniendo ubicación...',
                    style: AppFonts.text(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_outlined, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Guardar Información',
                    style: AppFonts.text(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveReading(ClientMeterRecord client) async {
    if (!_formKey.currentState!.validate()) return;

    final reason = _nonReadingReason;
    final reading = reason == null ? int.parse(_readingController.text) : null;

    if (reading != null && !await _confirmUnusualConsumption(client, reading)) {
      _readingFocusNode.requestFocus();
      return;
    }
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      final saved = await ref.read(clientRecordsProvider.notifier).saveReading(
            client.id,
            reading: reading,
            nonReadingReason: reason?.label,
            observations: _observationsController.text,
            photoPath: _photoPath,
          );
      _savedPhotoPath = _photoPath;
      // The previously saved photo was replaced or removed
      final initial = _initialPhotoPath;
      if (initial != null && initial != _photoPath) {
        _photoService.deletePhoto(initial);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.visitedGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (reason == null
                            ? 'Lectura guardada para ${client.ownerName}'
                            : 'Visita registrada sin lectura: ${reason.label}') +
                        (saved != null && saved.readingLatitude == null
                            ? ' (sin ubicación GPS)'
                            : ''),
                    style: AppFonts.text(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: $e',
              style: AppFonts.text(),
            ),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  /// Asks the reader to confirm a negative or abnormally high consumption.
  /// Returns true when the reading should be saved.
  Future<bool> _confirmUnusualConsumption(
      ClientMeterRecord client, int reading) async {
    final consumption = reading - client.readingOneMonthAgo;
    final previousConsumption =
        client.readingOneMonthAgo - client.readingTwoMonthsAgo;

    if (consumption < 0) {
      return _showConsumptionWarning(
        title: 'Consumo negativo',
        message: 'La lectura ingresada ($reading m³) es menor que la anterior '
            '(${client.readingOneMonthAgo} m³), lo que da un consumo de '
            '$consumption m³.\n\n'
            'Puede ser un error de digitación o que el medidor dio la vuelta '
            '(por ejemplo, de 9999 a 0). Verifique el medidor.',
      );
    }

    if (previousConsumption > 0 && consumption > previousConsumption * 3) {
      return _showConsumptionWarning(
        title: 'Consumo anormal',
        message: 'El consumo calculado ($consumption m³) es más del triple '
            'del consumo del mes anterior ($previousConsumption m³).\n\n'
            'Verifique la lectura o si hay una posible fuga.',
      );
    }

    return true;
  }

  Future<bool> _showConsumptionWarning({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.warningAmber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppFonts.text(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppFonts.text(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Corregir',
              style: AppFonts.text(
                fontWeight: FontWeight.w600,
                color: AppTheme.accentCyan,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningAmber,
            ),
            child: Text(
              'Guardar de todos modos',
              style: AppFonts.text(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
