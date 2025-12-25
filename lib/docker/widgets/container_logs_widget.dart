import 'package:flutter/material.dart';
import 'package:devmate/docker/services/logs.dart';

class ContainerLogsWidget extends StatefulWidget {
  final String containerId;
  const ContainerLogsWidget({Key? key, required this.containerId})
    : super(key: key);

  @override
  State<ContainerLogsWidget> createState() => _ContainerLogsWidgetState();
}

class _ContainerLogsWidgetState extends State<ContainerLogsWidget> {
  final LogsApiService _logsApiService = LogsApiService();
  late Stream<String> _logStream;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _logStream = _streamLogs();
  }

  Stream<String> _streamLogs() async* {
    yield* _logsApiService.streamContainerLogs(widget.containerId);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: StreamBuilder<String>(
          stream: _logStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(height: 8),
                    Text(
                      'Failed to fetch logs',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData) {
              return const Text('No logs available.');
            } else {
              _logs.add(snapshot.data!);
              return SingleChildScrollView(child: SelectableText(_logs.join()));
            }
          },
        ),
      ),
    );
  }
}
