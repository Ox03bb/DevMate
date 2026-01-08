import 'package:flutter/material.dart';
import 'package:devmate/files/models/file_item.dart';

/// A widget for displaying file transfer progress.
class TransferProgressWidget extends StatelessWidget {
  final List<FileTransfer> transfers;
  final VoidCallback? onClear;
  final Function(String)? onCancel;

  const TransferProgressWidget({
    super.key,
    required this.transfers,
    this.onClear,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.swap_vert),
                const SizedBox(width: 8),
                const Text(
                  'Transfers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                if (transfers.every(
                  (t) =>
                      t.status == TransferStatus.completed ||
                      t.status == TransferStatus.failed ||
                      t.status == TransferStatus.cancelled,
                ))
                  TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final transfer = transfers[index];
              return _TransferItem(
                transfer: transfer,
                onCancel: () => onCancel?.call(transfer.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransferItem extends StatelessWidget {
  final FileTransfer transfer;
  final VoidCallback? onCancel;

  const _TransferItem({required this.transfer, this.onCancel});

  IconData get _icon {
    switch (transfer.status) {
      case TransferStatus.pending:
        return Icons.hourglass_empty;
      case TransferStatus.inProgress:
        return transfer.type == TransferType.upload
            ? Icons.upload
            : Icons.download;
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (transfer.status) {
      case TransferStatus.pending:
        return Colors.grey;
      case TransferStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.cancelled:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icon, color: _iconColor(context)),
      title: Text(
        transfer.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transfer.status == TransferStatus.inProgress) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: transfer.progress,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
            ),
            const SizedBox(height: 4),
            Text(
              '${(transfer.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (transfer.status == TransferStatus.failed &&
              transfer.error != null)
            Text(
              transfer.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
        ],
      ),
      trailing: transfer.status == TransferStatus.inProgress
          ? IconButton(icon: const Icon(Icons.close), onPressed: onCancel)
          : null,
    );
  }
}
