import 'package:flutter/material.dart';
import 'package:devmate/docker/widgets/container_inspect_tab.dart';
import 'package:devmate/docker/models/container.dart';

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
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // First tab: Inspect container JSON
            ContainerInspectTab(container: container),
            // Placeholder widgets for other tabs
            Center(child: Text('Details')),
            Center(child: Text('Terminal')),
            Center(child: Text('Files')),
          ],
        ),
      ),
    );
  }
}
