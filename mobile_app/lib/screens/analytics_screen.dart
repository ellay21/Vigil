import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:glassmorphism/glassmorphism.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final devices = await _apiService.getAllDevices();
      final deviceId = devices.isNotEmpty ? devices.first.id : 'IND-MACHINE-01';
      final data = await _apiService.getDeviceAnalytics(deviceId);
      setState(() {
        _analytics = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Analytics & Health'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('No data available', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildScoreCard(
                        'Health Score',
                        _analytics!['health_score'],
                        Colors.greenAccent,
                        'Based on recent warnings/dangers',
                      ),
                      const SizedBox(height: 20),
                      _buildScoreCard(
                        'Efficiency (Uptime)',
                        _analytics!['efficiency'],
                        Colors.blueAccent,
                        'Active runtime in last 24h',
                      ),
                      const SizedBox(height: 20),
                      _buildStatRow('Total Readings', '${_analytics!['total_readings']}'),
                      _buildStatRow('Warnings', '${_analytics!['warnings']}', color: Colors.orange),
                      _buildStatRow('Critical Errors', '${_analytics!['dangers']}', color: Colors.red),
                      const SizedBox(height: 20),
                      _buildPredictionCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPredictionCard() {
    // Simple mock prediction logic based on health score
    final health = _analytics!['health_score'];
    String prediction = "System is stable. Next maintenance recommended in 30 days.";
    Color color = Colors.greenAccent;
    
    if (health < 80) {
      prediction = "Warning signs detected. Maintenance recommended within 7 days.";
      color = Colors.orangeAccent;
    }
    if (health < 50) {
      prediction = "Critical failure likely within 24 hours. Immediate inspection required.";
      color = Colors.redAccent;
    }

    return GlassmorphicContainer(
      width: double.infinity,
      height: 150,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.1)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph, color: color),
                const SizedBox(width: 10),
                const Text('AI Predictive Maintenance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(prediction, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String title, int score, Color color, String subtitle) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 200,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.1)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: Colors.white10,
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
