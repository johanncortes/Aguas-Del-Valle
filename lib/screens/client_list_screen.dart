import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_meter_record.dart';
import '../providers/client_list_providers.dart';
import '../providers/meter_providers.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/visit_status_style.dart';
import 'meter_reading_screen.dart';

/// Searchable, filterable list of all clients on the route.
class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(filteredClientsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(
          'Clientes',
          style: AppFonts.text(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _buildSearchField(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStatusFilters(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: clients.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: clients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildClientTile(clients[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      style: AppFonts.text(fontSize: 15, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o N° de cliente',
        prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () {
                  _searchController.clear();
                  ref.read(clientSearchQueryProvider.notifier).state = '';
                },
              ),
      ),
      onChanged: (value) =>
          ref.read(clientSearchQueryProvider.notifier).state = value,
    );
  }

  Widget _buildStatusFilters() {
    final selected = ref.watch(clientFilterStatusProvider);
    final progress = ref.watch(routeProgressProvider);

    final options = <(VisitStatus?, String, int)>[
      (null, 'Todos', progress.total),
      (VisitStatus.pending, VisitStatus.pending.label,
          progress.total - progress.visited),
      (VisitStatus.read, VisitStatus.read.label, progress.read),
      (VisitStatus.noReading, VisitStatus.noReading.label,
          progress.noReading),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (status, label, count) in options)
            ChoiceChip(
              label: Text('$label ($count)'),
              selected: selected == status,
              showCheckmark: false,
              avatar: status == null
                  ? null
                  : Icon(status.badgeIcon, size: 16, color: status.color),
              labelStyle: AppFonts.text(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              backgroundColor: AppTheme.surface,
              selectedColor: (status?.color ?? AppTheme.accentCyan)
                  .withValues(alpha: 0.3),
              onSelected: (_) => ref
                  .read(clientFilterStatusProvider.notifier)
                  .state = status,
            ),
        ],
      ),
    );
  }

  Widget _buildClientTile(ClientMeterRecord client) {
    final status = client.visitStatus;
    final detail = switch (status) {
      VisitStatus.pending => 'Pendiente',
      VisitStatus.read => 'Lectura: ${client.currentReading} m³',
      VisitStatus.noReading =>
        'Sin lectura: ${client.nonReadingReason ?? '-'}',
    };

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: status.color,
          child: Icon(status.pinIcon, color: Colors.white, size: 20),
        ),
        title: Text(
          client.ownerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.text(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          [
            'N° ${client.clientNumber}',
            if (client.sector != null) client.sector!,
            detail,
            if (!client.hasLocation) 'Sin ubicación',
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.text(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MeterReadingScreen(clientId: client.id),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off,
                size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No hay clientes que coincidan',
              textAlign: TextAlign.center,
              style: AppFonts.text(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
