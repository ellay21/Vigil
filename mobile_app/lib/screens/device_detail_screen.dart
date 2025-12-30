import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/device_data.dart';
import '../providers/app_provider.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Future<RiskAssessment>? _riskFuture;
  Future<Explanation>? _explanationFuture;
  Future<MaintenanceInsight>? _maintenanceFuture;
  Future<List<DeviceData>>? _historyFuture;
  
  final bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Defer loading until we have context for provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final lang = appProvider.isAmharic ? 'am' : 'en';
    setState(() {
      _riskFuture = _apiService.getDeviceRisk(widget.deviceId, lang: lang);
      _explanationFuture = _apiService.getDeviceExplanation(widget.deviceId, lang: lang);
      _maintenanceFuture = _apiService.getDeviceMaintenance(widget.deviceId, lang: lang);
      _historyFuture = _apiService.getDeviceHistory(widget.deviceId, limit: 20);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playVoiceAlert() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final voiceAlert = await _apiService.getDeviceVoice(widget.deviceId, lang: appProvider.isAmharic ? 'am' : 'en');
      await _audioPlayer.play(UrlSource(voiceAlert.audioUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${appProvider.isAmharic ? "መሳሪያ" : "Device"}: ${widget.deviceId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRiskCard(appProvider),
            const SizedBox(height: 16),
            _buildExplanationCard(appProvider),
            const SizedBox(height: 16),
            _buildMaintenanceCard(appProvider),
            const SizedBox(height: 24),
            _buildCharts(appProvider),
            const SizedBox(height: 24),
            _buildVoiceButton(appProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(AppProvider appProvider) {
    // Check if _riskFuture is initialized

    if (_riskFuture == null) return const SizedBox.shrink();

    return FutureBuilder<RiskAssessment>(
      future: _riskFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
        } else if (snapshot.hasError) {
          return Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Error: ${snapshot.error}')));
        } else if (snapshot.hasData) {
          final risk = snapshot.data!;
          Color riskColor;
          // Simple check for Amharic or English high risk keywords
          if (risk.riskLevel.toUpperCase().contains('HIGH') || risk.riskLevel.contains('ከፍተኛ')) {
            riskColor = Colors.redAccent;
          } else if (risk.riskLevel.toUpperCase().contains('MEDIUM') || risk.riskLevel.contains('መካከለኛ')) {
            riskColor = Colors.orangeAccent;
          } else {
            riskColor = Colors.greenAccent;
          }

          return Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    appProvider.isAmharic ? 'የአደጋ ደረጃ' : 'Risk Level',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    risk.riskLevel,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: risk.confidence,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${appProvider.isAmharic ? "እርግጠኝነት" : "Confidence"}: ${(risk.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    risk.reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: -0.1);
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildExplanationCard(AppProvider appProvider) {
    // ignore: unnecessary_null_comparison
    if (_explanationFuture == null) return const SizedBox.shrink();

    return FutureBuilder<Explanation>(
      future: _explanationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Text('Error loading explanation: ${snapshot.error}');
        } else if (snapshot.hasData) {
          return Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(appProvider.isAmharic ? 'AI ትንታኔ' : 'AI Analysis', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.data!.explanation,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildVoiceButton(AppProvider appProvider) {
    return ElevatedButton.icon(
      onPressed: _isPlaying ? null : _playVoiceAlert,
      icon: Icon(_isPlaying ? Icons.volume_up : Icons.play_arrow),
      label: Text(_isPlaying 
        ? (appProvider.isAmharic ? 'እየተጫወተ ነው...' : 'Playing Alert...') 
        : (appProvider.isAmharic ? 'የድምጽ ማስጠንቀቂያ አጫውት' : 'Play Voice Alert')),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    ).animate().fadeIn(delay: 400.ms).scale();
  }

  Widget _buildMaintenanceCard(AppProvider appProvider) {
    // ignore: unnecessary_null_comparison
    if (_maintenanceFuture == null) return const SizedBox.shrink();

    return FutureBuilder<MaintenanceInsight>(
      future: _maintenanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          return Card(
            color: data.maintenanceRequired ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: data.maintenanceRequired ? Colors.orange : Colors.green, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build, color: data.maintenanceRequired ? Colors.orange : Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        appProvider.isAmharic ? 'የጥገና ምክር' : 'Maintenance Insight',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: data.maintenanceRequired ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.suggestedAction,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1);
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildCharts(AppProvider appProvider) {
    // ignore: unnecessary_null_comparison
    if (_historyFuture == null) return const SizedBox.shrink();

    return FutureBuilder<List<DeviceData>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error loading charts: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final history = snapshot.data!;
          return Column(
            children: [
              _buildGenericChart(
                title: appProvider.isAmharic ? 'ቮልቴጅ (V)' : 'Voltage (V)',
                data: history,
                getValue: (d) => d.voltage,
                color: Colors.purpleAccent,
                minY: 0,
                maxY: 250, // Assuming mains voltage or similar
                interval: 50,
              ),
              const SizedBox(height: 16),
              _buildGenericChart(
                title: appProvider.isAmharic ? 'ንዝረት' : 'Vibration',
                data: history,
                getValue: (d) => d.vibrationDetected ? 1.0 : 0.0,
                color: Colors.orangeAccent,
                minY: 0,
                maxY: 1.1,
                interval: 1,
                isBoolean: true,
              ),
              const SizedBox(height: 16),
              _buildGenericChart(
                title: appProvider.isAmharic ? 'ጋዝ' : 'Gas',
                data: history,
                getValue: (d) => d.gasDetected ? 1.0 : 0.0,
                color: Colors.redAccent,
                minY: 0,
                maxY: 1.1,
                interval: 1,
                isBoolean: true,
              ),
            ],
          );
        } else {
          return const Text('No history data available.');
        }
      },
    );
  }

  Widget _buildGenericChart({
    required String title,
    required List<DeviceData> data,
    required double Function(DeviceData) getValue,
    required Color color,
    required double minY,
    required double maxY,
    required double interval,
    bool isBoolean = false,
  }) {
    final sortedHistory = data.reversed.toList();
    final spots = sortedHistory.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), getValue(e.value));
    }).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedHistory.length) {
                           final date = DateTime.parse(sortedHistory[value.toInt()].timestamp);
                           return Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(
                               DateFormat('HH:mm').format(date),
                               style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                             ),
                           );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (isBoolean) {
                          if (value == 0) return const Text('OFF', style: TextStyle(color: Colors.white38, fontSize: 10));
                          if (value == 1) return const Text('ON', style: TextStyle(color: Colors.white38, fontSize: 10));
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: !isBoolean,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF2A2E3E),
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorder: const BorderSide(color: Colors.white10),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        String val = touchedSpot.y.toString();
                        if (isBoolean) val = touchedSpot.y == 1.0 ? 'ON' : 'OFF';
                        return LineTooltipItem(
                          val,
                          TextStyle(color: color, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
