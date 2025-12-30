import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'api_service.dart';

class ReportService {
  static Future<void> generateSystemReport({String lang = 'en'}) async {
    final pdf = pw.Document();
    final api = ApiService();
    
    // Fetch data for report
    final devices = await api.getAllDevices();
    final summary = await api.getSystemSummary(lang: lang);
    
    // Load Font
    final font = await PdfGoogleFonts.notoSansEthiopicRegular();
    final boldFont = await PdfGoogleFonts.notoSansEthiopicBold();

    // Translations
    final isAm = lang == 'am';
    final title = isAm ? 'Vigil - የኢንዱስትሪ IoT ስርዓት ሪፖርት' : 'Vigil - Industrial IoT System Report';
    final generated = isAm ? 'የተዘጋጀው: ${DateTime.now().toString()}' : 'Generated: ${DateTime.now().toString()}';
    final execSummary = isAm ? 'አጠቃላይ ማጠቃለያ' : 'Executive Summary';
    final overallStatus = isAm ? 'አጠቃላይ ሁኔታ:' : 'Overall Status:';
    final devicesAtRisk = isAm ? 'አደጋ ላይ ያሉ መሳሪያዎች:' : 'Devices at Risk:';
    final deviceOverview = isAm ? 'የመሳሪያዎች ሁኔታ አጠቃላይ እይታ' : 'Device Status Overview';
    final tableHeaders = isAm ? ['የመሳሪያ መታወቂያ', 'ሁኔታ', 'መጨረሻ የታየው'] : ['Device ID', 'Status', 'Last Seen'];
    final alertsLog = isAm ? 'ወሳኝ ማስጠንቀቂያዎች' : 'Critical Alerts Log';
    final alertsDesc = isAm ? 'በሁሉም መሳሪያዎች ላይ ያሉ የቅርብ ጊዜ ወሳኝ ክስተቶችን በማሳየት ላይ።' : 'Showing recent critical events across all devices.';
    final footerText = isAm ? 'Vigil AI መቆጣጠሪያ' : 'Vigil AI Monitor';
    final pageText = isAm ? 'ገጽ' : 'Page';

    // Helper for status translation
    String translateStatus(String status) {
      if (!isAm) return status;
      switch (status.toUpperCase()) {
        case 'SAFE': return 'ደህንነቱ የተጠበቀ';
        case 'WARNING': return 'ማስጠንቀቂያ';
        case 'DANGER': return 'አደጋ';
        case 'OFFLINE': return 'ከመስመር ውጭ';
        default: return status;
      }
    }

    // Create a dense report
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 24))),
            pw.Text(generated, style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 20),
            
            // Executive Summary
            pw.Header(level: 1, child: pw.Text(execSummary, style: pw.TextStyle(font: boldFont))),
            pw.Text(summary.summary, style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('$overallStatus ${translateStatus(summary.overallStatus)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont)),
                pw.Text('$devicesAtRisk ${summary.devicesAtRisk}', style: pw.TextStyle(color: PdfColors.red, font: font)),
              ],
            ),
            pw.SizedBox(height: 20),

            // Device Status Table
            pw.Header(level: 1, child: pw.Text(deviceOverview, style: pw.TextStyle(font: boldFont))),
            pw.TableHelper.fromTextArray(
              context: context,
              cellStyle: pw.TextStyle(font: font),
              headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold),
              data: <List<String>>[
                tableHeaders,
                ...devices.map((d) => [d.id, translateStatus(d.currentState), d.lastSeen]),
              ],
            ),
            pw.SizedBox(height: 20),

            // Detailed Alerts Log
            pw.Header(level: 1, child: pw.Text(alertsLog, style: pw.TextStyle(font: boldFont))),
            pw.Text(alertsDesc, style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 10),
            ...devices.where((d) => d.currentState == 'DANGER' || d.currentState == 'WARNING').map((d) {
              final msg = isAm 
                ? 'መሳሪያ ${d.id} በ ${translateStatus(d.currentState)} ሁኔታ ላይ ነው።' 
                : 'Device ${d.id} is in ${d.currentState} state.';
              return pw.Bullet(text: msg, style: pw.TextStyle(font: font));
            }),
            
            pw.SizedBox(height: 30),
            pw.Footer(
              leading: pw.Text(footerText, style: pw.TextStyle(font: font)),
              trailing: pw.Text('$pageText 1', style: pw.TextStyle(font: font)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
