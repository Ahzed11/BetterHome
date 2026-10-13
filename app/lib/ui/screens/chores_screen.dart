import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({
    super.key,
    required this.session,
    required this.householdId,
  });

  final AppSession session;
  final String householdId;

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<ChoreTask>> _future;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    final mine = _tabs.index == 1;
    _future = widget.session.tasksRepository.listTasks(
      widget.householdId,
      mine: mine,
    );
  }

  Future<void> _quickLog() async {
    final l10n = AppLocalizations.of(context);
    final templates = await widget.session.tasksRepository.listTemplates(
      widget.householdId,
    );
    if (!mounted) {
      return;
    }
    if (templates.isEmpty) {
      final titleController = TextEditingController(text: 'Chore');
      final created = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.createTemplate),
          content: TextField(
            controller: titleController,
            decoration: InputDecoration(labelText: l10n.templateTitle),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      );
      if (created != true || !mounted) {
        return;
      }
      await widget.session.tasksRepository.createTemplate(
        householdId: widget.householdId,
        title: titleController.text.trim(),
        points: 5,
        latePoints: 2,
      );
    }
    final latest = await widget.session.tasksRepository.listTemplates(
      widget.householdId,
    );
    if (!mounted || latest.isEmpty) {
      return;
    }
    final templateId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.quickLog),
        children: latest
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, t.id),
                child: Text('${t.emoji ?? ''} ${t.title}'.trim()),
              ),
            )
            .toList(),
      ),
    );
    if (templateId == null || !mounted) {
      return;
    }
    await widget.session.tasksRepository.quickLog(
      householdId: widget.householdId,
      templateId: templateId,
    );
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.choresTitle),
        bottom: TabBar(
          controller: _tabs,
          onTap: (_) => setState(_reload),
          tabs: [
            Tab(text: l10n.allChores),
            Tab(text: l10n.myChores),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickLog,
        icon: const Icon(Icons.bolt),
        label: Text(l10n.quickLog),
      ),
      body: FutureBuilder<List<ChoreTask>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: Text(l10n.loading));
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.errorGeneric));
          }
          final tasks = snapshot.data ?? const [];
          if (tasks.isEmpty) {
            return Center(child: Text(l10n.choresEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            itemCount: tasks.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTokens.spaceSm),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                tileColor: Colors.white,
                title: Text('${task.emoji ?? ''} ${task.title}'.trim()),
                subtitle: Text(
                  '${task.status.name} · ${task.pointsAwarded ?? task.points} pts',
                ),
                trailing: task.status == TaskStatus.open
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: l10n.completeTask,
                            onPressed: () async {
                              await widget.session.tasksRepository.complete(
                                widget.householdId,
                                task.id,
                              );
                              setState(_reload);
                            },
                            icon: const Icon(Icons.check_circle_outline),
                          ),
                          IconButton(
                            tooltip: l10n.dismissTask,
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.dismissConfirmTitle),
                                  content: Text(l10n.dismissConfirmBody),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(l10n.dismissTask),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await widget.session.tasksRepository.dismiss(
                                  widget.householdId,
                                  task.id,
                                );
                                setState(_reload);
                              }
                            },
                            icon: const Icon(Icons.cancel_outlined),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
