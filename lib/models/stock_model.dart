// lib/models/stock_models.dart (update or add this)

import 'package:lpg_station/models/stock_item_model.dart';

class StationStockDto {
  final int stationID;
  final String? stationName;
  final List<CylinderTypeDto> cylinders;
  final List<AccessoryDto> accessories;

  StationStockDto({
    required this.stationID,
    this.stationName,
    required this.cylinders,
    required this.accessories,
  });

  factory StationStockDto.fromJson(Map<String, dynamic> json) {
    return StationStockDto(
      stationID: json['stationID'] ?? 0,
      stationName: json['stationName'],
      cylinders:
          (json['cylinders'] as List<dynamic>?)
              ?.map((c) => CylinderTypeDto.fromJson(c))
              .toList() ??
          [],
      accessories:
          (json['accessories'] as List<dynamic>?)
              ?.map((a) => AccessoryDto.fromJson(a))
              .toList() ??
          [],
    );
  }
}
