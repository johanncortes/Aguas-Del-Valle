import 'package:hive/hive.dart';

class ClientMeterRecord {
  final String id;
  final String clientNumber;
  final String ownerName;
  final int readingTwoMonthsAgo;
  final int readingOneMonthAgo;
  int? currentReading;
  bool isVisited;
  final double latitude;
  final double longitude;
  DateTime? updatedAt;

  ClientMeterRecord({
    required this.id,
    required this.clientNumber,
    required this.ownerName,
    required this.readingTwoMonthsAgo,
    required this.readingOneMonthAgo,
    this.currentReading,
    this.isVisited = false,
    required this.latitude,
    required this.longitude,
    this.updatedAt,
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
    );
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
      latitude: fields[7] as double,
      longitude: fields[8] as double,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ClientMeterRecord obj) {
    writer.writeByte(10); // number of fields
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
  }
}
