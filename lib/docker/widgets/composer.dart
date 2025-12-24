import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:devmate/docker/widgets/containers_list.dart';

class ComposerW extends StatefulWidget {
  final String name;
  final List<ContainersList> container;

  const ComposerW({super.key, required this.name, required this.container});

  @override
  State<ComposerW> createState() => _ComposerWState();
}

class _ComposerWState extends State<ComposerW> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isExpanded = isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (context, isExpanded) {
              return ListTile(
                leading: SvgPicture.asset(
                  'images/docker/icons/composer.svg',
                  width: 24,
                  height: 24,
                ),
                title: Text('${widget.name}'),
              );
            },
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [...widget.container],
              ),
            ),
            isExpanded: _isExpanded,
          ),
        ],
      ),
    );
  }
}
