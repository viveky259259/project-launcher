import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { exec } from 'child_process';

// ---------------------------------------------------------------------------
// Data models (matching Flutter's JSON format)
// ---------------------------------------------------------------------------

interface Project {
  name: string;
  path: string;
  tags: string[];
  isPinned: boolean;
  addedAt?: string;
  notes?: string;
}

interface HealthDetails {
  totalScore: number;
  gitScore: number;
  depsScore: number;
  testsScore: number;
  category: string;
  hasRecentCommits: boolean;
  noUncommittedChanges: boolean;
  noUnpushedCommits: boolean;
  hasDependencyFile: boolean;
  hasLockFile: boolean;
  hasTestFolder: boolean;
  hasTestFiles: boolean;
}

interface CachedHealth {
  details: HealthDetails;
  cachedAt: string;
}

// ---------------------------------------------------------------------------
// Data loading
// ---------------------------------------------------------------------------

const DATA_DIR = path.join(os.homedir(), '.project_launcher');

function loadProjects(): Project[] {
  const filePath = path.join(DATA_DIR, 'projects.json');
  if (!fs.existsSync(filePath)) { return []; }
  try {
    const data = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(data) as Project[];
  } catch {
    return [];
  }
}

function loadHealthScores(): Record<string, CachedHealth> {
  const filePath = path.join(DATA_DIR, 'health_cache.json');
  if (!fs.existsSync(filePath)) { return {}; }
  try {
    const data = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(data) as Record<string, CachedHealth>;
  } catch {
    return {};
  }
}

// ---------------------------------------------------------------------------
// Tree data provider
// ---------------------------------------------------------------------------

class ProjectItem extends vscode.TreeItem {
  constructor(
    public readonly project: Project,
    public readonly healthScore?: number,
    public readonly category?: string,
  ) {
    super(project.name, vscode.TreeItemCollapsibleState.None);

    // Description: health score + tags
    const parts: string[] = [];
    if (healthScore !== undefined) {
      parts.push(`${healthScore}/100`);
    }
    if (project.tags.length > 0) {
      parts.push(project.tags.slice(0, 2).join(', '));
    }
    this.description = parts.join(' · ');

    // Tooltip
    const tooltipLines = [`**${project.name}**`, `\`${project.path}\``];
    if (healthScore !== undefined) {
      tooltipLines.push(`Health: ${healthScore}/100 (${category})`);
    }
    if (project.tags.length > 0) {
      tooltipLines.push(`Tags: ${project.tags.join(', ')}`);
    }
    if (project.notes) {
      tooltipLines.push(`Notes: ${project.notes}`);
    }
    this.tooltip = new vscode.MarkdownString(tooltipLines.join('\n\n'));

    // Icon
    if (project.isPinned) {
      this.iconPath = new vscode.ThemeIcon('star-full', new vscode.ThemeColor('charts.yellow'));
    } else if (healthScore !== undefined) {
      if (healthScore >= 80) {
        this.iconPath = new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.green'));
      } else if (healthScore >= 50) {
        this.iconPath = new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.yellow'));
      } else {
        this.iconPath = new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.red'));
      }
    } else {
      this.iconPath = new vscode.ThemeIcon('folder');
    }

    this.contextValue = 'project';
  }
}

class ProjectTreeProvider implements vscode.TreeDataProvider<ProjectItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<ProjectItem | undefined>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  private projects: Project[] = [];
  private healthScores: Record<string, CachedHealth> = {};

  refresh(): void {
    this.projects = loadProjects();
    this.healthScores = loadHealthScores();
    this._onDidChangeTreeData.fire(undefined);
  }

  getTreeItem(element: ProjectItem): vscode.TreeItem {
    return element;
  }

  getChildren(): ProjectItem[] {
    if (this.projects.length === 0) {
      this.refresh();
    }

    // Sort: pinned first, then by name
    const sorted = [...this.projects].sort((a, b) => {
      if (a.isPinned !== b.isPinned) { return a.isPinned ? -1 : 1; }
      return a.name.localeCompare(b.name);
    });

    return sorted.map(project => {
      const health = this.healthScores[project.path];
      return new ProjectItem(
        project,
        health?.details?.totalScore,
        health?.details?.category,
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Health summary provider
// ---------------------------------------------------------------------------

class HealthSummaryItem extends vscode.TreeItem {
  constructor(label: string, description: string, icon: vscode.ThemeIcon) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    this.iconPath = icon;
  }
}

class HealthSummaryProvider implements vscode.TreeDataProvider<HealthSummaryItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<HealthSummaryItem | undefined>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire(undefined);
  }

  getTreeItem(element: HealthSummaryItem): vscode.TreeItem {
    return element;
  }

  getChildren(): HealthSummaryItem[] {
    const projects = loadProjects();
    const scores = loadHealthScores();

    let healthy = 0, attention = 0, critical = 0, unscored = 0;

    for (const project of projects) {
      const health = scores[project.path];
      if (!health?.details?.totalScore) {
        unscored++;
      } else if (health.details.totalScore >= 80) {
        healthy++;
      } else if (health.details.totalScore >= 50) {
        attention++;
      } else {
        critical++;
      }
    }

    const items: HealthSummaryItem[] = [
      new HealthSummaryItem(
        'Total Projects',
        `${projects.length}`,
        new vscode.ThemeIcon('folder'),
      ),
      new HealthSummaryItem(
        'Healthy',
        `${healthy}`,
        new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.green')),
      ),
      new HealthSummaryItem(
        'Needs Attention',
        `${attention}`,
        new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.yellow')),
      ),
      new HealthSummaryItem(
        'Critical',
        `${critical}`,
        new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.red')),
      ),
    ];

    if (unscored > 0) {
      items.push(new HealthSummaryItem(
        'Not Scored',
        `${unscored}`,
        new vscode.ThemeIcon('circle-outline'),
      ));
    }

    return items;
  }
}

// ---------------------------------------------------------------------------
// Extension activation
// ---------------------------------------------------------------------------

export function activate(context: vscode.ExtensionContext) {
  const projectProvider = new ProjectTreeProvider();
  const healthProvider = new HealthSummaryProvider();

  vscode.window.registerTreeDataProvider('projectLauncher.projects', projectProvider);
  vscode.window.registerTreeDataProvider('projectLauncher.health', healthProvider);

  // Watch for file changes to auto-refresh
  const watcher = fs.watch(DATA_DIR, (_, filename) => {
    if (filename === 'projects.json' || filename === 'health_cache.json') {
      projectProvider.refresh();
      healthProvider.refresh();
    }
  });
  context.subscriptions.push({ dispose: () => watcher.close() });

  // Commands
  context.subscriptions.push(
    vscode.commands.registerCommand('projectLauncher.refresh', () => {
      projectProvider.refresh();
      healthProvider.refresh();
    }),

    vscode.commands.registerCommand('projectLauncher.openInVSCode', (item: ProjectItem) => {
      const uri = vscode.Uri.file(item.project.path);
      vscode.commands.executeCommand('vscode.openFolder', uri, { forceNewWindow: true });
    }),

    vscode.commands.registerCommand('projectLauncher.openInTerminal', (item: ProjectItem) => {
      const terminal = vscode.window.createTerminal({
        name: item.project.name,
        cwd: item.project.path,
      });
      terminal.show();
    }),

    vscode.commands.registerCommand('projectLauncher.openInFinder', (item: ProjectItem) => {
      exec(`open "${item.project.path}"`);
    }),

    vscode.commands.registerCommand('projectLauncher.copyPath', (item: ProjectItem) => {
      vscode.env.clipboard.writeText(item.project.path);
      vscode.window.showInformationMessage(`Copied: ${item.project.path}`);
    }),

    vscode.commands.registerCommand('projectLauncher.openApp', () => {
      exec('open "/Applications/Project Launcher.app"');
    }),
  );

  // Initial load
  projectProvider.refresh();
}

export function deactivate() {}
