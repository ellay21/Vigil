import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../services/report_service.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _sentryMode = false;
  TimeOfDay _armTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _disarmTime = const TimeOfDay(hour: 6, minute: 0);
  String _reportLang = 'en';

  Future<void> _generatePdf() async {
    await ReportService.generateSystemReport(lang: _reportLang);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Tools & Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildToolCard(
              title: 'Smart Sentry Mode',
              icon: Icons.security,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Sentry Mode', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Alerts on motion during off-hours', style: TextStyle(color: Colors.white54)),
                    value: _sentryMode,
                    onChanged: (val) => setState(() => _sentryMode = val),
                    activeTrackColor: Colors.redAccent,
                  ),
                  if (_sentryMode) ...[
                    ListTile(
                      title: const Text('Arm Time', style: TextStyle(color: Colors.white)),
                      trailing: Text(_armTime.format(context), style: const TextStyle(color: Colors.blueAccent)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _armTime);
                        if (t != null) setState(() => _armTime = t);
                      },
                    ),
                    ListTile(
                      title: const Text('Disarm Time', style: TextStyle(color: Colors.white)),
                      trailing: Text(_disarmTime.format(context), style: const TextStyle(color: Colors.blueAccent)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _disarmTime);
                        if (t != null) setState(() => _disarmTime = t);
                      },
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildToolCard(
              title: 'Reports',
              icon: Icons.picture_as_pdf,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Report Language', style: TextStyle(color: Colors.white)),
                    trailing: DropdownButton<String>(
                      value: _reportLang,
                      dropdownColor: const Color(0xFF2A2E3E),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'am', child: Text('Amharic')),
                      ],
                      onChanged: (val) => setState(() => _reportLang = val!),
                    ),
                  ),
                  ListTile(
                    title: const Text('Generate Safety PDF', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Download full history report', style: TextStyle(color: Colors.white54)),
                    trailing: const Icon(Icons.download, color: Colors.white),
                    onTap: _generatePdf,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({required String title, required IconData icon, required Widget child}) {
    double height = 150;
    if (title == 'Smart Sentry Mode' && _sentryMode) height = 250;
    if (title == 'Reports') height = 200;

    return GlassmorphicContainer(
      width: double.infinity,
      height: height,
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(child: child),
        ],
      ),
    );
  }
}
