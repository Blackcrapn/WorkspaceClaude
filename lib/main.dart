import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const FocusFlowApp());

enum Priority { low, medium, high }

extension PriorityMeta on Priority {
  String get label => switch (this) {
        Priority.low => 'Low',
        Priority.medium => 'Medium',
        Priority.high => 'High',
      };

  Color get color => switch (this) {
        Priority.low => const Color(0xFF3BB273),
        Priority.medium => const Color(0xFFF2A63B),
        Priority.high => const Color(0xFFE5484D),
      };
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.priority = Priority.medium,
    this.done = false,
  });

  final String id;
  String title;
  Priority priority;
  bool done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority.index,
        'done': done,
      };

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        priority: Priority.values[(j['priority'] as int?) ?? 1],
        done: (j['done'] as bool?) ?? false,
      );
}

class TaskStore extends ChangeNotifier {
  static const _key = 'focus_flow_tasks_v1';
  final List<Task> _tasks = [];

  List<Task> get all => List.unmodifiable(_tasks);
  List<Task> get open => _tasks.where((t) => !t.done).toList();
  List<Task> get done => _tasks.where((t) => t.done).toList();
  int get total => _tasks.length;
  double get progress => _tasks.isEmpty ? 0 : done.length / _tasks.length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _tasks.clear();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
    } else {
      _tasks.addAll([
        Task(id: _id(), title: 'Swipe a task to delete it', priority: Priority.low),
        Task(id: _id(), title: 'Tap the circle to complete a task'),
        Task(id: _id(), title: 'Add your first real task', priority: Priority.high),
      ]);
      await _persist(prefs);
    }
    _sort();
    notifyListeners();
  }

  Future<void> _persist([SharedPreferences? p]) async {
    final prefs = p ?? await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  void _sort() {
    _tasks.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return b.priority.index.compareTo(a.priority.index);
    });
  }

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> add(String title, Priority priority) async {
    _tasks.add(Task(id: _id(), title: title.trim(), priority: priority));
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> toggle(Task task) async {
    task.done = !task.done;
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> remove(Task task) async {
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.done);
    notifyListeners();
    await _persist();
  }
}

class FocusFlowApp extends StatefulWidget {
  const FocusFlowApp({super.key});

  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  final store = TaskStore();
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7B61FF);
    return MaterialApp(
      title: 'Focus Flow',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: HomePage(
        store: store,
        onToggleTheme: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, required this.onToggleTheme});

  final TaskStore store;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final tasks = store.all;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Header(store: store, onToggleTheme: onToggleTheme),
                Expanded(
                  child: tasks.isEmpty
                      ? _EmptyState(cs: cs)
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96, top: 4),
                          itemCount: tasks.length,
                          itemBuilder: (context, i) => _TaskTile(
                            task: tasks[i],
                            onToggle: () => store.toggle(tasks[i]),
                            onDismissed: () => store.remove(tasks[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddSheet(context, store),
            icon: const Icon(Icons.add),
            label: const Text('New task'),
          ),
        );
      },
    );
  }

  void _openAddSheet(BuildContext context, TaskStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddTaskSheet(onSubmit: store.add),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store, required this.onToggleTheme});

  final TaskStore store;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Focus Flow',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            )),
                    const SizedBox(height: 4),
                    Text(
                      '${store.open.length} open · ${store.done.length} done',
                      style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.75)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Toggle theme',
                onPressed: onToggleTheme,
                icon: Icon(Icons.brightness_6_outlined, color: cs.onPrimaryContainer),
              ),
              IconButton(
                tooltip: 'Clear completed',
                onPressed: store.done.isEmpty ? null : store.clearCompleted,
                icon: Icon(Icons.cleaning_services_outlined, color: cs.onPrimaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: store.progress,
              minHeight: 8,
              backgroundColor: cs.onPrimaryContainer.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle, required this.onDismissed});

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          onTap: onToggle,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: IconButton(
            onPressed: onToggle,
            icon: Icon(
              task.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.done ? task.priority.color : Theme.of(context).hintColor,
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.done ? TextDecoration.lineThrough : null,
              color: task.done ? Theme.of(context).hintColor : null,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: task.priority.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              task.priority.label,
              style: TextStyle(
                color: task.priority.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 72, color: cs.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          const Text('Nothing left. Go touch grass.'),
        ],
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.onSubmit});
  final Future<void> Function(String, Priority) onSubmit;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _controller = TextEditingController();
  Priority _priority = Priority.medium;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text, _priority);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New task', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'What needs doing?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: Priority.values
                .map((p) => ChoiceChip(
                      label: Text(p.label),
                      selected: _priority == p,
                      onSelected: (_) => setState(() => _priority = p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ),
        ],
      ),
    );
  }
}
