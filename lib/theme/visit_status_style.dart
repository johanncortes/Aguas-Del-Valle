import 'package:flutter/material.dart';
import '../models/client_meter_record.dart';
import 'app_theme.dart';

/// Colors, icons and labels for each visit outcome.
extension VisitStatusStyle on VisitStatus {
  Color get color => switch (this) {
        VisitStatus.pending => AppTheme.pendingRed,
        VisitStatus.read => AppTheme.visitedGreen,
        VisitStatus.noReading => AppTheme.noReadingOrange,
      };

  IconData get pinIcon => switch (this) {
        VisitStatus.pending => Icons.water_drop,
        VisitStatus.read => Icons.check,
        VisitStatus.noReading => Icons.priority_high,
      };

  IconData get badgeIcon => switch (this) {
        VisitStatus.pending => Icons.pending_outlined,
        VisitStatus.read => Icons.check_circle,
        VisitStatus.noReading => Icons.report_problem_outlined,
      };

  String get label => switch (this) {
        VisitStatus.pending => 'Pendiente',
        VisitStatus.read => 'Leído',
        VisitStatus.noReading => 'Sin lectura',
      };
}
