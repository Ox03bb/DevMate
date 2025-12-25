import 'package:flutter/material.dart';
import 'package:devmate/docker/widgets/container_inspect_tab.dart';
import 'package:devmate/docker/models/container.dart';
import 'package:devmate/docker/widgets/container_logs_widget.dart';

class ContainerDetails extends StatelessWidget {
  final ContainerModel container;

  const ContainerDetails({super.key, required this.container});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            container.name,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Icon(
                  Icons.receipt_long_sharp,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),

              Tab(
                icon: Icon(
                  Icons.terminal,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              Tab(
                icon: Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              Tab(
                icon: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Logs Tab
            ContainerLogsWidget(containerId: container.id),
            // Details Tab
            Center(child: Text('Details')),
            // Files Tab
            Center(child: Text('Files')),
            // Inspect Tab
            ContainerInspectTab(container: container),
          ],
        ),
      ),
    );
  }
}
