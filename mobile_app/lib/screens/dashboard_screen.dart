import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/api_service.dart';
import '../models/device_data.dart';
import '../providers/app_provider.dart';
import 'device_list_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<Map<String, dynamic>> _dataFuture;
  
  // Notifications
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _refreshData();
  }

  void _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id', 'Critical Alerts',
      importance: Importance.max, priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(0, title, body, details);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          if (val.hasConfidenceRating && val.confidence > 0) {
            // Simple command parsing
            if (val.recognizedWords.toLowerCase().contains('status')) {
              _speakStatus();
            }
          }
          setState(() => _isListening = false);
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _speakStatus() async {
    // Speak the summary
    // We need the data first, but let's assume we have it or fetch it
    try {
      final summary = await _apiService.getSystemSummary();
      await _flutterTts.speak("System status is ${summary.overallStatus}. ${summary.summary}");
    } catch (e) {
      await _flutterTts.speak("I cannot check the status right now.");
    }
  }

  void _refreshData() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    setState(() {
      _dataFuture = _fetchDashboardData(appProvider.isAmharic ? 'am' : 'en');
    });
  }

  Future<Map<String, dynamic>> _fetchDashboardData(String lang) async {
    try {
      final summary = await _apiService.getSystemSummary(lang: lang);
      
      // Check for critical alerts and notify
      if (summary.overallStatus == 'DANGER' || summary.overallStatus == 'WARNING') {
        _showNotification('System Alert', 'System is in ${summary.overallStatus} state!');
      }

      final devices = await _apiService.getAllDevices();
      List<DeviceData> history = [];
      
      if (devices.isNotEmpty) {
        // Fetch history for the first device (Main Dashboard Device)
        // Ideally, user selects this, but for now we default to the first one.
        try {
          history = await _apiService.getDeviceHistory(devices.first.id, limit: 20);
        } catch (e) {
          debugPrint("Error fetching history: $e");
        }
      }

      return {
        'summary': summary,
        'devices': devices,
        'history': history,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appProvider.isAmharic ? 'የስርዓት አጠቃላይ እይታ' : 'System Overview'),
        actions: [
          IconButton(
            icon: Icon(appProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => appProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              appProvider.toggleLanguage();
              _refreshData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              appProvider.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: Stack(
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('No Data'));
                }

                final summary = snapshot.data!['summary'] as SystemSummary;
                final devices = snapshot.data!['devices'] as List<Device>;
                final history = snapshot.data!['history'] as List<DeviceData>;
                final mainDevice = devices.isNotEmpty ? devices.first : null;
                final latestReading = history.isNotEmpty ? history.first : null;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSystemStatusCard(summary, appProvider),
                      const SizedBox(height: 24),
                      if (mainDevice != null && latestReading != null) ...[
                        Text(
                          "${appProvider.isAmharic ? 'ዋና መሳሪያ' : 'Main Device'}: ${mainDevice.id}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        _buildSensorGrid(latestReading, appProvider),
                        const SizedBox(height: 24),
                        _buildLiveChart(history, appProvider),
                        const SizedBox(height: 24),
                        _buildRecentAlerts(history, appProvider),
                      ] else
                        const Center(child: Text("No active devices found.")),
                      const SizedBox(height: 24),
                      _buildActionButtons(appProvider),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: _listen,
                backgroundColor: _isListening ? Colors.redAccent : Colors.blueAccent,
                child: Icon(_isListening ? Icons.mic : Icons.mic_none),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard(SystemSummary summary, AppProvider appProvider) {
    final isSafe = summary.overallStatus.toUpperCase().contains('SAFE') || summary.overallStatus.contains('ደህንነቱ የተጠበቀ');
    final statusColor = isSafe ? const Color(0xFF69F0AE) : const Color(0xFFFFAB40); // GreenAccent400 vs OrangeAccent400

    return GlassmorphicContainer(
      width: double.infinity,
      height: 180, // Increased height to prevent overflow
      borderRadius: 24,
      blur: 30,
      alignment: Alignment.center,
      border: 0,
      linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2E3E).withValues(alpha: 0.6),
            const Color(0xFF1E2230).withValues(alpha: 0.6),
          ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Use min size
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: Colors.white.withValues(alpha: 0.5), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        appProvider.isAmharic ? 'የስርዓት ሁኔታ' : 'SYSTEM STATUS',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1.2, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8), // Reduced spacing
                  Flexible( // Make text flexible
                    child: Text(
                      summary.overallStatus,
                      style: TextStyle(
                        fontSize: 24, // Slightly reduced font size
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 1,
                        shadows: [Shadow(color: statusColor.withValues(alpha: 0.3), blurRadius: 20)],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${summary.devicesAtRisk} ${appProvider.isAmharic ? 'መሳሪያዎች አደጋ ላይ' : 'Devices at Risk'}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  ),
                  child: Icon(
                    isSafe ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 32,
                    color: statusColor,
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(duration: 2000.ms, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildSensorGrid(DeviceData data, AppProvider appProvider) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.6, // Increased aspect ratio to make cards shorter/wider relative to height
      children: [
        _buildSensorCard(
          appProvider.isAmharic ? 'ሙቀት' : 'Temperature',
          '${data.temperature}°C',
          Icons.thermostat,
          data.temperature > 50 ? Colors.redAccent : Colors.cyanAccent,
        ),
        _buildSensorCard(
          appProvider.isAmharic ? 'ቮልቴጅ' : 'Voltage',
          '${data.voltage}V',
          Icons.electric_bolt,
          (data.voltage > 230 || data.voltage < 210) ? Colors.orangeAccent : Colors.greenAccent,
        ),
        _buildSensorCard(
          appProvider.isAmharic ? 'ንዝረት' : 'Vibration',
          data.vibrationDetected ? (appProvider.isAmharic ? 'ተገኝቷል' : 'DETECTED') : (appProvider.isAmharic ? 'መደበኛ' : 'NORMAL'),
          Icons.vibration,
          data.vibrationDetected ? Colors.redAccent : Colors.blueGrey,
        ),
        _buildSensorCard(
          appProvider.isAmharic ? 'ጋዝ' : 'Gas',
          data.gasDetected ? (appProvider.isAmharic ? 'ተገኝቷል' : 'DETECTED') : (appProvider.isAmharic ? 'ግልጽ' : 'CLEAR'),
          Icons.cloud,
          data.gasDetected ? Colors.red : Colors.green,
        ),
      ],
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Flexible( // Make content flexible
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox( // Scale text down if it's too big
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildLiveChart(List<DeviceData> history, AppProvider appProvider) {
    if (history.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text("No Data Available")));
    }

    // Prepare data points
    // Reverse history so oldest is left, newest is right
    final sortedHistory = history.reversed.toList();
    
    double minTemp = sortedHistory.map((e) => e.temperature).reduce(math.min);
    double maxTemp = sortedHistory.map((e) => e.temperature).reduce(math.max);
    
    // Dynamic Range Calculation
    double range = maxTemp - minTemp;
    double interval = 5; // Default interval
    
    if (range <= 10) {
      interval = 2;
    } else if (range <= 30) {
      interval = 5;
    } else if (range <= 100) {
      interval = 10;
    } else {
      interval = 20;
    }

    // Add padding based on interval
    double minY = (minTemp / interval).floor() * interval - interval;
    double maxY = (maxTemp / interval).ceil() * interval + interval;

    final tempSpots = sortedHistory.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.temperature);
    }).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230), // Slightly lighter dark
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appProvider.isAmharic ? 'የሙቀት ታሪክ' : 'Temperature History',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    appProvider.isAmharic ? 'ባለፉት 20 ንባቦች' : 'Last 20 readings',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.thermostat, color: Colors.cyanAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "${sortedHistory.last.temperature}°C",
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                           // Show time for every 5th point
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
                        return Text(
                          '${value.toInt()}°',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (history.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: tempSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.cyanAccent],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF1E2230),
                          strokeWidth: 2,
                          strokeColor: Colors.cyanAccent,
                        );
                      },
                      checkToShowDot: (spot, barData) {
                        return spot.x == 0 || spot.x == history.length - 1; // Only show first and last
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyanAccent.withValues(alpha: 0.2),
                          Colors.blueAccent.withValues(alpha: 0.0),
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
                        return LineTooltipItem(
                          '${touchedSpot.y}°C',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildRecentAlerts(List<DeviceData> history, AppProvider appProvider) {
    // Filter for "interesting" events
    final alerts = history.where((d) => d.state != 'ACTIVE' && d.state != 'Unknown').take(5).toList();

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appProvider.isAmharic ? 'የቅርብ ጊዜ ማስጠንቀቂያዎች' : 'Recent Alerts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Icon(Icons.notifications_active_outlined, color: Colors.white.withValues(alpha: 0.5), size: 18),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...alerts.map((alert) {
          Color color = alert.state == 'DANGER' ? const Color(0xFFFF5252) : const Color(0xFFFFAB40);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2230),
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: color, width: 4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.state,
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, HH:mm:ss').format(DateTime.parse(alert.timestamp)),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (alert.gasDetected) 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Text('GAS', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons(AppProvider appProvider) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DeviceListScreen()),
        );
      },
      icon: const Icon(Icons.grid_view),
      label: Text(appProvider.isAmharic ? 'ሁሉንም መሳሪያዎች ይመልከቱ' : 'View All Devices'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
        foregroundColor: Colors.blueAccent,
        side: const BorderSide(color: Colors.blueAccent),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }
}

