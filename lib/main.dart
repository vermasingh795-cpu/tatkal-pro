import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TatkalProApp());

class TatkalProApp extends StatelessWidget {
  const TatkalProApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF172B43);
    return MaterialApp(
      title: 'Tatkal Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: navy),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Passenger {
  final String name;
  final int age;
  final String gender;
  const Passenger(this.name, this.age, this.gender);

  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'gender': gender};
  factory Passenger.fromJson(Map<String, dynamic> j) =>
      Passenger(j['name'] as String, j['age'] as int, j['gender'] as String);
}

class PassengerStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'saved_passengers_v1';

  static Future<List<Passenger>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Passenger.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> write(List<Passenger> passengers) async {
    await _storage.write(
      key: _key,
      value: jsonEncode(passengers.map((p) => p.toJson()).toList()),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _from = TextEditingController(text: 'Patna Junction (PNBE)');
  final _to = TextEditingController(text: 'Lokmanya Tilak Terminus (LTT)');
  final _date = TextEditingController(
    text: DateFormat('dd-MM-yyyy').format(DateTime.now()),
  );
  final _pnr = TextEditingController();
  final List<String> _tasks = [
    'Passenger names and ages checked',
    'Journey date and boarding station checked',
    'IRCTC account login tested',
    'Aadhaar authentication status checked',
    'UPI app opened and working',
    'Phone battery and internet checked',
  ];
  final Set<int> _done = {};
  List<Passenger> _passengers = [];
  Timer? _ticker;
  DateTime _now = DateTime.now();
  String _network = 'Checking connection…';
  bool _internetReachable = false;
  bool _checkingNetwork = false;
  String _networkDetail = 'Please wait';
  String _pnrMessage = 'Enter a PNR to open the official enquiry page.';
  String _travelClass = '3A';
  String _quota = 'Tatkal';

  static const _irctcSearch = 'https://www.irctc.co.in/nget/train-search';
  static const _pnrUrl = 'https://www.indianrail.gov.in/enquiry/PNR/PnrEnquiry.html?locale=en';

  @override
  void initState() {
    super.initState();
    _loadPassengers();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    checkNetwork();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _from.dispose();
    _to.dispose();
    _date.dispose();
    _pnr.dispose();
    super.dispose();
  }

  Future<void> _loadPassengers() async {
    final p = await PassengerStore.read();
    if (mounted) setState(() => _passengers = p);
  }

  Future<void> checkNetwork() async {
    if (_checkingNetwork) return;
    setState(() {
      _checkingNetwork = true;
      _network = 'Checking…';
    });
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final connected = connectivity.any((r) => r != ConnectivityResult.none);
      if (!connected) {
        setState(() {
          _network = 'No network';
          _internetReachable = false;
          _networkDetail = 'Wi-Fi or mobile data is disconnected.';
        });
        return;
      }
      // This tests general internet reachability, not IRCTC server availability.
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 6));
      final ok = response.statusCode == 204 || response.statusCode == 200;
      setState(() {
        _internetReachable = ok;
        _network = ok ? 'Internet available' : 'Network limited';
        _networkDetail = ok
            ? 'Internet connection is responding. IRCTC may still be busy.'
            : 'Connected to a network, but internet access may be limited.';
      });
    } catch (_) {
      setState(() {
        _network = 'Could not verify internet';
        _internetReachable = false;
        _networkDetail = 'Try switching between Wi-Fi and mobile data.';
      });
    } finally {
      if (mounted) setState(() => _checkingNetwork = false);
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  Future<void> _copyJourneyDetails() async {
    final details = [
      'From: ${_from.text.trim()}',
      'To: ${_to.text.trim()}',
      'Journey date: ${_date.text.trim()}',
      'Class: $_travelClass',
      'Quota: $_quota',
      'Passengers saved in Tatkal Pro: ${_passengers.length}',
      '',
      'Please verify all details on the official IRCTC website before booking.'
    ].join('\\n');
    await Clipboard.setData(ClipboardData(text: details));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey details copied. Paste/check them on IRCTC.')),
      );
    }
  }

  DateTime? _parseJourneyDate() {
    try {
      return DateFormat('dd-MM-yyyy').parseStrict(_date.text.trim());
    } catch (_) {
      return null;
    }
  }

  DateTime? _nextAcTatkalOpening() {
    final journey = _parseJourneyDate();
    if (journey == null) return null;
    // Tatkal date is one day before the train's originating-station departure date.
    // User must verify the origin date for the selected train in IRCTC.
    final openingDay = DateTime(journey.year, journey.month, journey.day)
        .subtract(const Duration(days: 1));
    return DateTime(openingDay.year, openingDay.month, openingDay.day, 10);
  }

  String _countdown() {
    final opening = _nextAcTatkalOpening();
    if (opening == null) return 'Enter date as DD-MM-YYYY';
    final diff = opening.difference(_now);
    if (diff.isNegative) return 'Opening time has passed';
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _addPassenger() async {
    final name = TextEditingController();
    final age = TextEditingController();
    String gender = 'Male';
    final result = await showDialog<Passenger>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add passenger'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name')),
              TextField(controller: age, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age')),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const ['Male', 'Female', 'Transgender']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setDialogState(() => gender = v ?? 'Male'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final a = int.tryParse(age.text.trim());
                if (name.text.trim().isEmpty || a == null || a < 0 || a > 120) return;
                Navigator.pop(dialogContext, Passenger(name.text.trim(), a, gender));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final updated = [..._passengers, result];
      await PassengerStore.write(updated);
      if (mounted) setState(() => _passengers = updated);
    }
  }

  Future<void> _deletePassenger(int index) async {
    final updated = [..._passengers]..removeAt(index);
    await PassengerStore.write(updated);
    if (mounted) setState(() => _passengers = updated);
  }

  Future<void> _openPnr() async {
    final pnr = _pnr.text.trim();
    if (pnr.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(pnr)) {
      setState(() => _pnrMessage = 'PNR must contain exactly 10 digits.');
      return;
    }
    setState(() => _pnrMessage = pnr.isEmpty
        ? 'Opening official PNR enquiry. Enter your PNR there.'
        : 'Opening official PNR enquiry. Enter or verify your PNR there.');
    await _openUrl(_pnrUrl);
  }

  Widget _section(String title, IconData icon, Widget child) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: const Color(0xFF172B43)), const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 14),
        child,
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final opening = _nextAcTatkalOpening();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tatkal Pro'),
        actions: [IconButton(tooltip: 'Check network', onPressed: checkNetwork,
          icon: const Icon(Icons.wifi_find))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFF172B43), Color(0xFF294B70)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AC TATKAL COUNTDOWN', style: TextStyle(color: Colors.white70, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(_countdown(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(opening == null ? 'Check journey date format.' :
                'Indicative opening: ${DateFormat('dd MMM yyyy, hh:mm a').format(opening)}',
                style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const Text('Verify the train origin date and quota rules on IRCTC before relying on this countdown.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),
          _section('Journey details', Icons.train, Column(children: [
            TextField(controller: _from, textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'From station / code')),
            TextField(controller: _to, textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'To station / code')),
            TextField(controller: _date, decoration: const InputDecoration(labelText: 'Journey date (DD-MM-YYYY)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _travelClass,
              decoration: const InputDecoration(labelText: 'Travel class'),
              items: const [
                DropdownMenuItem(value: '1A', child: Text('1A – First AC')),
                DropdownMenuItem(value: '2A', child: Text('2A – Second AC')),
                DropdownMenuItem(value: '3A', child: Text('3A – Third AC')),
                DropdownMenuItem(value: 'SL', child: Text('SL – Sleeper')),
                DropdownMenuItem(value: 'CC', child: Text('CC – Chair Car')),
              ],
              onChanged: (v) => setState(() => _travelClass = v ?? '3A'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _quota,
              decoration: const InputDecoration(labelText: 'Quota'),
              items: const [
                DropdownMenuItem(value: 'Tatkal', child: Text('Tatkal')),
                DropdownMenuItem(value: 'General', child: Text('General')),
                DropdownMenuItem(value: 'Premium Tatkal', child: Text('Premium Tatkal')),
              ],
              onChanged: (v) => setState(() => _quota = v ?? 'Tatkal'),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _copyJourneyDetails,
              icon: const Icon(Icons.copy), label: const Text('Copy journey details'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () => _openUrl(_irctcSearch),
              icon: const Icon(Icons.open_in_new), label: const Text('Open official IRCTC search'))),
            const SizedBox(height: 6),
            const Text(
              'Tatkal Pro prepares and copies your search details. For safety, it does not auto-fill IRCTC forms or automate booking. Confirm station codes, train origin date and availability on IRCTC.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ])),
          _section('Saved passengers', Icons.people, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_passengers.isEmpty) const Text('No passenger details saved yet.'),
              ..._passengers.asMap().entries.map((entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value.name),
                subtitle: Text('${entry.value.age} years • ${entry.value.gender}'),
                trailing: IconButton(icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deletePassenger(entry.key)),
              )),
              OutlinedButton.icon(onPressed: _addPassenger,
                icon: const Icon(Icons.person_add_alt_1), label: const Text('Add passenger')),
              const Text('Stored securely on this device. Not uploaded to IRCTC.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          )),
          _section('Network checker', Icons.wifi, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_internetReachable ? Icons.check_circle : Icons.info_outline,
                  color: _internetReachable ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(_network, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (_checkingNetwork) const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 6),
              Text(_networkDetail, style: const TextStyle(color: Colors.black54)),
              TextButton.icon(onPressed: checkNetwork, icon: const Icon(Icons.refresh), label: const Text('Test again')),
            ],
          )),
          _section('Payment preparation checklist', Icons.checklist, Column(
            children: _tasks.asMap().entries.map((e) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _done.contains(e.key),
              title: Text(e.value),
              onChanged: (v) => setState(() {
                if (v == true) { _done.add(e.key); } else { _done.remove(e.key); }
              }),
            )).toList(),
          )),
          _section('PNR tracking shortcut', Icons.confirmation_number, Column(
            children: [
              TextField(controller: _pnr, keyboardType: TextInputType.number,
                maxLength: 10, decoration: const InputDecoration(labelText: '10-digit PNR (optional)')),
              Align(alignment: Alignment.centerLeft, child: Text(_pnrMessage,
                style: const TextStyle(fontSize: 12, color: Colors.black54))),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _openPnr, icon: const Icon(Icons.search),
                label: const Text('Open official PNR enquiry'))),
            ],
          )),
          _section('Train availability shortcut', Icons.event_seat, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Check live availability and complete booking on IRCTC. This app does not reserve seats.'),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => _openUrl(_irctcSearch),
                icon: const Icon(Icons.open_in_new), label: const Text('Check train availability'))),
            ],
          )),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Safety: Tatkal Pro is an independent preparation assistant, not an IRCTC app. It does not automate booking, solve CAPTCHA, store passwords/OTPs/UPI PINs, or guarantee a ticket.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
