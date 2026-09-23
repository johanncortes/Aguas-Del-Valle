import 'package:hive/hive.dart';

class ClientMeterRecord {
  final String id;
  final String clientNumber;
  final String ownerName;
  final int readingTwoMonthsAgo;
  final int readingOneMonthAgo;
  int? currentReading;
  bool isVisited;
  /// Official meter location. Null until it is fixed in the field (e.g.
  /// clients from the preloaded list); such clients have no map pin.
  final double? latitude;
  final double? longitude;
  DateTime? updatedAt;

  /// Why the meter could not be read this cycle (see [NonReadingReason]).
  final String? nonReadingReason;

  /// Free-text notes from the reader.
  final String? observations;

  /// Device position when the visit was recorded (GPS audit). Null when
  /// the location was unavailable (permission denied, GPS off, no fix).
  final double? readingLatitude;
  final double? readingLongitude;

  /// Local path of the evidence photo taken during the visit, if any.
  final String? photoPath;

  /// Locality the client belongs to (e.g. "Angostura"). Master data: kept
  /// across cycles, unlike the per-visit fields.
  final String? sector;

  ClientMeterRecord({
    required this.id,
    required this.clientNumber,
    required this.ownerName,
    required this.readingTwoMonthsAgo,
    required this.readingOneMonthAgo,
    this.currentReading,
    this.isVisited = false,
    this.latitude,
    this.longitude,
    this.updatedAt,
    this.nonReadingReason,
    this.observations,
    this.readingLatitude,
    this.readingLongitude,
    this.photoPath,
    this.sector,
  });

  /// Calculated consumption in M3
  int get consumptionM3 {
    if (currentReading == null) return 0;
    return currentReading! - readingOneMonthAgo;
  }

  /// Whether the current reading is suspicious (lower than previous)
  bool get hasReadingWarning {
    if (currentReading == null) return false;
    return currentReading! < readingOneMonthAgo;
  }

  /// Whether the client has an official location (and so a map pin).
  bool get hasLocation => latitude != null && longitude != null;

  /// True when the reader visited the client but could not take a reading.
  bool get hasNonReading => nonReadingReason != null && currentReading == null;

  /// Visit outcome for the current cycle, used to color map pins.
  VisitStatus get visitStatus {
    if (!isVisited) return VisitStatus.pending;
    return currentReading != null ? VisitStatus.read : VisitStatus.noReading;
  }

  /// Returns this record prepared for the next billing cycle.
  ///
  /// With a new reading the history shifts one month back. Without one
  /// (not visited, or visited with a non-reading reason) the history is
  /// kept intact so no month is lost; only the cycle state is cleared.
  ClientMeterRecord startNewCycle() {
    final reading = currentReading;
    return ClientMeterRecord(
      id: id,
      clientNumber: clientNumber,
      ownerName: ownerName,
      readingTwoMonthsAgo:
          reading != null ? readingOneMonthAgo : readingTwoMonthsAgo,
      readingOneMonthAgo: reading ?? readingOneMonthAgo,
      currentReading: null,
      isVisited: false,
      latitude: latitude,
      longitude: longitude,
      updatedAt: null,
      nonReadingReason: null,
      observations: null,
      readingLatitude: null,
      readingLongitude: null,
      photoPath: null,
      sector: sector,
    );
  }

  ClientMeterRecord copyWith({
    String? id,
    String? clientNumber,
    String? ownerName,
    int? readingTwoMonthsAgo,
    int? readingOneMonthAgo,
    int? currentReading,
    bool? isVisited,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    String? nonReadingReason,
    String? observations,
    double? readingLatitude,
    double? readingLongitude,
    String? photoPath,
    String? sector,
  }) {
    return ClientMeterRecord(
      id: id ?? this.id,
      clientNumber: clientNumber ?? this.clientNumber,
      ownerName: ownerName ?? this.ownerName,
      readingTwoMonthsAgo: readingTwoMonthsAgo ?? this.readingTwoMonthsAgo,
      readingOneMonthAgo: readingOneMonthAgo ?? this.readingOneMonthAgo,
      currentReading: currentReading ?? this.currentReading,
      isVisited: isVisited ?? this.isVisited,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
      nonReadingReason: nonReadingReason ?? this.nonReadingReason,
      observations: observations ?? this.observations,
      readingLatitude: readingLatitude ?? this.readingLatitude,
      readingLongitude: readingLongitude ?? this.readingLongitude,
      photoPath: photoPath ?? this.photoPath,
      sector: sector ?? this.sector,
    );
  }
}

enum VisitStatus {
  /// Not visited yet this cycle.
  pending,

  /// Visited and the meter was read.
  read,

  /// Visited but the meter could not be read (see [NonReadingReason]).
  noReading,
}

/// Reasons a meter could not be read. Stored as their [label] in Hive.
enum NonReadingReason {
  noAccess('Sin acceso'),
  damagedMeter('Medidor dañado'),
  dog('Perro'),
  houseClosed('Casa cerrada'),
  other('Otro');

  const NonReadingReason(this.label);
  final String label;

  /// Parses a stored [label]; returns null for null or unknown values.
  static NonReadingReason? fromLabel(String? label) {
    for (final reason in values) {
      if (reason.label == label) return reason;
    }
    return null;
  }
}

/// Manual Hive TypeAdapter for ClientMeterRecord (avoids code generation)
class ClientMeterRecordAdapter extends TypeAdapter<ClientMeterRecord> {
  @override
  final int typeId = 0;

  @override
  ClientMeterRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ClientMeterRecord(
      id: fields[0] as String,
      clientNumber: fields[1] as String,
      ownerName: fields[2] as String,
      readingTwoMonthsAgo: fields[3] as int,
      readingOneMonthAgo: fields[4] as int,
      currentReading: fields[5] as int?,
      isVisited: fields[6] as bool,
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
      updatedAt: fields[9] as DateTime?,
      // Fields 10+ were added later; records saved by older versions
      // don't contain them and read back as null.
      nonReadingReason: fields[10] as String?,
      observations: fields[11] as String?,
      readingLatitude: fields[12] as double?,
      readingLongitude: fields[13] as double?,
      photoPath: fields[14] as String?,
      sector: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClientMeterRecord obj) {
    writer.writeByte(16); // number of fields
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.clientNumber);
    writer.writeByte(2);
    writer.write(obj.ownerName);
    writer.writeByte(3);
    writer.write(obj.readingTwoMonthsAgo);
    writer.writeByte(4);
    writer.write(obj.readingOneMonthAgo);
    writer.writeByte(5);
    writer.write(obj.currentReading);
    writer.writeByte(6);
    writer.write(obj.isVisited);
    writer.writeByte(7);
    writer.write(obj.latitude);
    writer.writeByte(8);
    writer.write(obj.longitude);
    writer.writeByte(9);
    writer.write(obj.updatedAt);
    writer.writeByte(10);
    writer.write(obj.nonReadingReason);
    writer.writeByte(11);
    writer.write(obj.observations);
    writer.writeByte(12);
    writer.write(obj.readingLatitude);
    writer.writeByte(13);
    writer.write(obj.readingLongitude);
    writer.writeByte(14);
    writer.write(obj.photoPath);
    writer.writeByte(15);
    writer.write(obj.sector);
  }
}
