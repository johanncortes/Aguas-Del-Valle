import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_meter_record.dart';
import '../providers/meter_providers.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Bottom sheet to edit an existing client's master data: name, sector and
/// reading history. The client number is fixed. The current cycle
/// (reading, visit state, photo...) is not touched.
class EditClientModal extends ConsumerStatefulWidget {
  final ClientMeterRecord client;

  const EditClientModal({super.key, required this.client});

  @override
  ConsumerState<EditClientModal> createState() => _EditClientModalState();
}

class _EditClientModalState extends ConsumerState<EditClientModal> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.client.ownerName);
  late final _sectorController =
      TextEditingController(text: widget.client.sector ?? '');
  late final _reading2MonthsController = TextEditingController(
      text: '${widget.client.readingTwoMonthsAgo}');
  late final _reading1MonthController =
      TextEditingController(text: '${widget.client.readingOneMonthAgo}');
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sectorController.dispose();
    _reading2MonthsController.dispose();
    _reading1MonthController.dispose();
    super.dispose();
  }

  /// Empty history fields are saved as 0.
  int _parseReading(String? text) => int.tryParse(text?.trim() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit, color: AppTheme.accentCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Editar Cliente',
                        style: AppFonts.text(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // The client number identifies the client: read only
                    Text(
                      'N° ${widget.client.clientNumber}',
                      key: const Key('editClientNumber'),
                      style: AppFonts.text(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Propietario',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingrese el nombre del propietario'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _sectorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Sector',
                    prefixIcon: Icon(Icons.place_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _reading2MonthsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Hace 2 meses',
                          suffixText: 'm³',
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
                        decoration: const InputDecoration(
                          labelText: 'Hace 1 mes',
                          suffixText: 'm³',
                          errorMaxLines: 3,
                        ),
                        validator: (value) {
                          // A meter only counts up
                          if (_parseReading(value) <
                              _parseReading(_reading2MonthsController.text)) {
                            return 'No puede ser menor que la de hace 2 meses';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side:
                              const BorderSide(color: AppTheme.textSecondary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.client.hasLocation) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _confirmClearLocation,
                    icon: const Icon(Icons.location_off_outlined),
                    label: const Text('Borrar ubicación del mapa'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(clientRecordsProvider.notifier).updateClientData(
            widget.client.id,
            ownerName: _nameController.text,
            sector: _sectorController.text,
            readingOneMonthAgo: _parseReading(_reading1MonthController.text),
            readingTwoMonthsAgo: _parseReading(_reading2MonthsController.text),
          );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Datos del cliente actualizados.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  /// A pin placed by the office is easy to lose with a stray tap, so this
  /// asks once before removing it.
  Future<void> _confirmClearLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Borrar ubicación'),
        content: Text(
          'El pin de ${widget.client.ownerName} se quitará del mapa y el '
          'cliente quedará "Sin ubicación".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Borrar ubicación'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(clientRecordsProvider.notifier)
          .clearClientLocation(widget.client.id);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Ubicación borrada del mapa.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error al borrar la ubicación: $e')),
      );
    }
  }
}
