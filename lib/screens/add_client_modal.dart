import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/meter_providers.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet form for adding a new client at a dropped pin location
class AddClientModal extends ConsumerStatefulWidget {
  final LatLng location;

  const AddClientModal({super.key, required this.location});

  @override
  ConsumerState<AddClientModal> createState() => _AddClientModalState();
}

class _AddClientModalState extends ConsumerState<AddClientModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _clientNumberController = TextEditingController();
  final _reading2MonthsController = TextEditingController(text: '0');
  final _reading1MonthController = TextEditingController(text: '0');
  final _currentReadingController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _clientNumberController.dispose();
    _reading2MonthsController.dispose();
    _reading1MonthController.dispose();
    _currentReadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title row
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentCyan, AppTheme.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Añadir Nuevo Cliente',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lat: ${widget.location.latitude.toStringAsFixed(6)}, '
                            'Lng: ${widget.location.longitude.toStringAsFixed(6)}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Location badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.visitedGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.visitedGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: AppTheme.visitedGreen),
                      const SizedBox(width: 6),
                      Text(
                        'Ubicación seleccionada en el mapa',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.visitedGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Owner Name
                _buildLabel('Nombre Propietario *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ej: Juan Pérez Soto',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingrese el nombre del propietario';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Client Number
                _buildLabel('N° Cliente *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _clientNumberController,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ej: 40225011',
                    prefixIcon: Icon(Icons.tag, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingrese el número de cliente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Previous readings row
                _buildLabel('Lecturas Anteriores'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _reading2MonthsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Hace 2 meses',
                          labelStyle: GoogleFonts.inter(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reading1MonthController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Hace 1 mes',
                          labelStyle: GoogleFonts.inter(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Current reading (optional)
                _buildLabel('Lectura Actual del Medidor (opcional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _currentReadingController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Dejar vacío si no hay lectura',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    ),
                    suffixText: 'm³',
                    suffixStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(
                              color: AppTheme.surfaceCardLight),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveNewClient,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_location_alt, size: 20),
                        label: Text(
                          _isSaving ? 'Guardando...' : 'Crear Cliente',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Future<void> _saveNewClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentReadingText = _currentReadingController.text.trim();
      final currentReading =
          currentReadingText.isEmpty ? null : int.tryParse(currentReadingText);

      await ref.read(clientRecordsProvider.notifier).addClient(
            ownerName: _nameController.text.trim(),
            clientNumber: _clientNumberController.text.trim(),
            latitude: widget.location.latitude,
            longitude: widget.location.longitude,
            readingTwoMonthsAgo:
                int.tryParse(_reading2MonthsController.text) ?? 0,
            readingOneMonthAgo:
                int.tryParse(_reading1MonthController.text) ?? 0,
            currentReading: currentReading,
          );

      if (mounted) {
        Navigator.pop(context, true); // true = client was created
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.visitedGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cliente "${_nameController.text.trim()}" añadido al mapa',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
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
            content: Text(
              'Error al crear cliente: $e',
              style: GoogleFonts.inter(),
            ),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
