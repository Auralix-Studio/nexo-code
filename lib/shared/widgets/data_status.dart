import 'package:flutter/material.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/l10n/app_localizations.dart';

/// The parent already listens to AppStore. No timer or network work on rebuild.
class DataStatus extends StatelessWidget {
  const DataStatus({super.key, required this.store, required this.operations});
  final AppStore store;
  final Map<String, String> operations;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in operations.entries)
          if (store.freshnessOf(entry.key) case final state?)
            if (state.refreshing || state.failed || state.fromCache)
              Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${entry.value}: '
                '${state.refreshing
                    ? l.dataRefreshing
                    : state.failed
                    ? l.dataRefreshFailed
                    : state.fromCache
                    ? l.dataSaved
                    : l.dataServer}'
                ' · ${state.updatedAt == null ? l.dataUnknownDate : l.dataUpdatedAt('${material.formatShortDate(state.updatedAt!.toLocal())} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(state.updatedAt!.toLocal()))}')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
      ],
    );
  }
}
