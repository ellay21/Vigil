import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
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
            const SizedBox(height: 24),
            _buildVoiceButton(appProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(AppProvider appProvider) {
    // Check if _riskFuture is initialized
    // ignore: unnecessary_null_comparison
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
}
