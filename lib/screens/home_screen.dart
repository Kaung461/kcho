import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../app_scope.dart';
import '../models/entry.dart';
import '../theme/app_colors.dart';
import '../widgets/entry_tile.dart';
import '../widgets/type_segmented_control.dart';
import 'add_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EntryType _type = EntryType.tango;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // The segmented control's custom TextStyle isn't compatible with the
        // nav bar's automatic title Hero transition (mismatched
        // TextStyle.inherit crashes on mount) — turn that transition off.
        transitionBetweenRoutes: false,
        middle: SizedBox(
          width: 220,
          child: TypeSegmentedControl(
            value: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => AddEntryScreen(initialType: _type),
            ),
          ),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<Box<Entry>>(
          valueListenable: repo.listenable(),
          builder: (context, _, __) {
            final entries = repo.byType(_type);
            if (entries.isEmpty) {
              return const _EmptyState();
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => Container(
                margin: const EdgeInsets.only(left: 16),
                height: 0.5,
                color: AppColors.borderLine,
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return EntryTile(
                  entry: entry,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => AddEntryScreen(existing: entry),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'まだ登録がありません。\n右上の + から追加してください。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.inkSecondary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
