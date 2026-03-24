import 'package:flutter/material.dart';
import '../services/plugins/plugin_system.dart';
import 'package:launcher_theme/launcher_theme.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key});

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  bool _isLoading = true;
  List<PluginManifest> _plugins = [];

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    await PluginSystem.initialize();
    if (mounted) {
      setState(() {
        _plugins = PluginSystem.plugins;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Top bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Plugins', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text('${_plugins.where((p) => p.enabled).length} active',
                    style: AppTypography.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddPluginInfo(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Plugin'),
                  style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.extension_rounded, size: 22, color: AppColors.accent),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Plugin System',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                'Plugins add quick actions and status indicators to your projects. '
                                'They auto-detect based on project files.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Built-in plugins
                  Text('Built-in Plugins',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  ..._plugins
                      .where((p) => p.id.startsWith('builtin.'))
                      .map((plugin) => _PluginCard(
                        plugin: plugin,
                        onToggle: (enabled) async {
                          await PluginSystem.togglePlugin(plugin.id, enabled);
                          _loadPlugins();
                        },
                      )),

                  // User plugins
                  if (_plugins.any((p) => !p.id.startsWith('builtin.'))) ...[
                    const SizedBox(height: 24),
                    Text('Custom Plugins',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ..._plugins
                        .where((p) => !p.id.startsWith('builtin.'))
                        .map((plugin) => _PluginCard(
                          plugin: plugin,
                          onToggle: (enabled) async {
                            await PluginSystem.togglePlugin(plugin.id, enabled);
                            _loadPlugins();
                          },
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddPluginInfo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: const Text('Add Custom Plugin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a JSON file in the plugins directory:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(
                '~/.project_launcher/plugins/my-plugin.json',
                style: AppTypography.mono(fontSize: 12, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Example plugin format:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(
                '{\n'
                '  "id": "custom.my-tool",\n'
                '  "name": "My Tool",\n'
                '  "description": "Run my custom tool",\n'
                '  "detectFile": "Makefile",\n'
                '  "actions": [{\n'
                '    "id": "run",\n'
                '    "label": "Run",\n'
                '    "type": "button",\n'
                '    "command": "make",\n'
                '    "args": ["build"]\n'
                '  }]\n'
                '}',
                style: AppTypography.mono(fontSize: 11, color: cs.onSurface),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _PluginCard extends StatelessWidget {
  final PluginManifest plugin;
  final ValueChanged<bool> onToggle;

  const _PluginCard({required this.plugin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: plugin.enabled
              ? AppColors.accent.withValues(alpha: 0.25)
              : cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _pluginColor(plugin.id).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_pluginIcon(plugin.id), size: 20,
              color: _pluginColor(plugin.id)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plugin.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('v${plugin.version}',
                      style: AppTypography.mono(
                        fontSize: 10, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(plugin.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                // Actions preview
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: plugin.actions.map((action) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(action.label,
                        style: AppTypography.inter(
                          fontSize: 10,
                          color: cs.onSurfaceVariant)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Toggle
          Switch(
            value: plugin.enabled,
            onChanged: onToggle,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  IconData _pluginIcon(String id) {
    if (id.contains('docker')) return Icons.widgets_rounded;
    if (id.contains('github')) return Icons.code_rounded;
    if (id.contains('ci')) return Icons.sync_rounded;
    if (id.contains('npm')) return Icons.javascript_rounded;
    if (id.contains('flutter')) return Icons.flutter_dash_rounded;
    return Icons.extension_rounded;
  }

  Color _pluginColor(String id) {
    if (id.contains('docker')) return const Color(0xFF2496ED);
    if (id.contains('github')) return const Color(0xFF8B5CF6);
    if (id.contains('ci')) return AppColors.success;
    if (id.contains('npm')) return const Color(0xFFCB3837);
    if (id.contains('flutter')) return const Color(0xFF02569B);
    return AppColors.accent;
  }
}
