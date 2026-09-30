import 'package:flutter/material.dart';
import 'package:nexo/data/app_store.dart';

/// Status widget — currently silent (renders nothing).
/// Kept for API compatibility; re-enable body when needed.
class DataStatus extends StatelessWidget {
  const DataStatus({super.key, required this.store, required this.operations});
  final AppStore store;
  final Map<String, String> operations;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

