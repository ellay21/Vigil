import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/api_service.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _sentryMode = false;
  TimeOfDay _armTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _disarmTime = const TimeOfDay(hour: 6, minute: 0);

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final api = ApiService();
    
    // Fetch data for report
    final devices = await api.getAllDevices();
    final summary = await api.getSystemSummary();
    
    // Create a dense report
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text('Industrial IoT System Report')),
            pw.Text('Generated: ${DateTime.now().toString()}'),
            pw.SizedBox(height: 20),
            
            // Executive Summary
            pw.Header(level: 1, child: pw.Text('Executive Summary')),
            pw.Text(summary.summary),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Overall Status: ${summary.overallStatus}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Devices at Risk: ${summary.devicesAtRisk}', style: pw.TextStyle(color: PdfColors.red)),
              ],
            ),
            pw.SizedBox(height: 20),

            // Device Status Table
            pw.Header(level: 1, child: pw.Text('Device Status Overview')),
            pw.TableHelper.fromTextArray(
              context: context,
              data: <List<String>>[
                <String>['Device ID', 'Status', 'Last Seen'],
                ...devices.map((d) => [d.id, d.currentState, d.lastSeen]),
              ],
            ),
            pw.SizedBox(height: 20),

            // Detailed Alerts Log
            pw.Header(level: 1, child: pw.Text('Critical Alerts Log')),
            pw.Text('Showing recent critical events across all devices.'),
            pw.SizedBox(height: 10),
            // We would ideally fetch alerts for all devices here, but for now let's list the risky ones
            ...devices.where((d) => d.currentState == 'DANGER' || d.currentState == 'WARNING').map((d) {
              return pw.Bullet(text: 'Device ${d.id} is in ${d.currentState} state.');
            }),
            
            pw.SizedBox(height: 30),
            pw.Footer(
              leading: pw.Text('GSM Industrial Monitor'),
              trailing: pw.Text('Page 1'),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
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
              child: ListTile(
                title: const Text('Generate Safety PDF', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Download full history report', style: TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.download, color: Colors.white),
                onTap: _generatePdf,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({required String title, required IconData icon, required Widget child}) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: _sentryMode && title == 'Smart Sentry Mode' ? 250 : 150,
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
