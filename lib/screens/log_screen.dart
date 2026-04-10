import 'package:flutter/material.dart';
import 'package:launcher_native/launcher_native.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  @override
  void initState() {
    super.initState();
    AppLogger.addListener(_updateLogs);
  }

  @override
  void dispose() {
    AppLogger.removeListener(_updateLogs);
    super.dispose();
  }

  void _updateLogs() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              AppLogger.clear();
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: AppLogger.count,
        itemBuilder: (context, index) {
          final log = AppLogger.logs[index];
          return Text(log.toString());
        },
      ),
    );
  }
}
