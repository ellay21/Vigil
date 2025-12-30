class Device {
  final String id;
  final String lastSeen;
  final String currentState;

  Device({
    required this.id,
    required this.lastSeen,
    required this.currentState,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? 'Unknown',
      lastSeen: json['last_seen'] ?? '',
      currentState: json['current_state'] ?? 'Unknown',
    );
  }
}

class DeviceData {
  final String deviceId;
  final double temperature;
  final double voltage;
  final bool motionDetected;
  final bool vibrationDetected;
  final bool gasDetected;
  final String state;
  final String timestamp;

  DeviceData({
    required this.deviceId,
    required this.temperature,
    required this.voltage,
    required this.motionDetected,
    required this.vibrationDetected,
    required this.gasDetected,
    required this.state,
    required this.timestamp,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    return DeviceData(
      deviceId: json['device_id'] ?? 'Unknown',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      motionDetected: json['motionDetected'] == 1 || json['motionDetected'] == true,
      vibrationDetected: json['vibrationDetected'] == 1 || json['vibrationDetected'] == true,
      gasDetected: json['gasDetected'] == 1 || json['gasDetected'] == true,
      state: json['state'] ?? 'Unknown',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class SystemSummary {
  final String overallStatus;
  final int devicesAtRisk;
  final String summary;

  SystemSummary({
    required this.overallStatus,
    required this.devicesAtRisk,
    required this.summary,
  });

  factory SystemSummary.fromJson(Map<String, dynamic> json) {
    return SystemSummary(
      overallStatus: json['overall_status'] ?? 'Unknown',
      devicesAtRisk: json['devices_at_risk'] ?? 0,
      summary: json['summary'] ?? 'No summary available.',
    );
  }
}

class RiskAssessment {
  final String riskLevel;
  final double confidence;
  final String reason;

  RiskAssessment({
    required this.riskLevel,
    required this.confidence,
    required this.reason,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      riskLevel: json['risk_level'] ?? 'UNKNOWN',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] ?? 'No reason provided.',
    );
  }
}

class Explanation {
  final String explanation;

  Explanation({required this.explanation});

  factory Explanation.fromJson(Map<String, dynamic> json) {
    return Explanation(
      explanation: json['explanation'] ?? 'No explanation available.',
    );
  }
}

class VoiceAlert {
  final String text;
  final String audioUrl;

  VoiceAlert({required this.text, required this.audioUrl});

  factory VoiceAlert.fromJson(Map<String, dynamic> json) {
    return VoiceAlert(
      text: json['text'] ?? '',
      audioUrl: json['audio_url'] ?? '',
    );
  }
}

class MaintenanceInsight {
  final bool maintenanceRequired;
  final String suggestedAction;

  MaintenanceInsight({required this.maintenanceRequired, required this.suggestedAction});

  factory MaintenanceInsight.fromJson(Map<String, dynamic> json) {
    return MaintenanceInsight(
      maintenanceRequired: json['maintenance_required'] ?? false,
      suggestedAction: json['suggested_action'] ?? 'No action suggested.',
    );
  }
}
