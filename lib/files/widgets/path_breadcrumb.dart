import 'package:flutter/material.dart';

/// A breadcrumb widget for displaying and navigating the current path.
class PathBreadcrumb extends StatelessWidget {
  final String currentPath;
  final Function(String) onPathTap;

  const PathBreadcrumb({
    super.key,
    required this.currentPath,
    required this.onPathTap,
  });

  List<String> get _pathParts {
    if (currentPath.isEmpty || currentPath == '/') {
      return [''];
    }

    final parts = currentPath.split('/').where((p) => p.isNotEmpty).toList();
    return ['', ...parts];
  }

  String _buildPath(int index) {
    if (index == 0) return '/';

    final parts = _pathParts.sublist(1, index + 1);
    return '/${parts.join('/')}';
  }

  @override
  Widget build(BuildContext context) {
    final parts = _pathParts;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < parts.length; i++) ...[
              if (i > 0)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              InkWell(
                onTap: () => onPathTap(_buildPath(i)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i == 0)
                        Icon(
                          Icons.home,
                          size: 18,
                          color: i == parts.length - 1
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      if (i > 0)
                        Text(
                          parts[i],
                          style: TextStyle(
                            color: i == parts.length - 1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: i == parts.length - 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
