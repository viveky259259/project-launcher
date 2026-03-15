"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const os = __importStar(require("os"));
const child_process_1 = require("child_process");
// ---------------------------------------------------------------------------
// Data loading
// ---------------------------------------------------------------------------
const DATA_DIR = path.join(os.homedir(), '.project_launcher');
function loadProjects() {
    const filePath = path.join(DATA_DIR, 'projects.json');
    if (!fs.existsSync(filePath)) {
        return [];
    }
    try {
        const data = fs.readFileSync(filePath, 'utf-8');
        return JSON.parse(data);
    }
    catch {
        return [];
    }
}
function loadHealthScores() {
    const filePath = path.join(DATA_DIR, 'health_cache.json');
    if (!fs.existsSync(filePath)) {
        return {};
    }
    try {
        const data = fs.readFileSync(filePath, 'utf-8');
        return JSON.parse(data);
    }
    catch {
        return {};
    }
}
// ---------------------------------------------------------------------------
// Tree data provider
// ---------------------------------------------------------------------------
class ProjectItem extends vscode.TreeItem {
    project;
    healthScore;
    category;
    constructor(project, healthScore, category) {
        super(project.name, vscode.TreeItemCollapsibleState.None);
        this.project = project;
        this.healthScore = healthScore;
        this.category = category;
        // Description: health score + tags
        const parts = [];
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
        }
        else if (healthScore !== undefined) {
            if (healthScore >= 80) {
                this.iconPath = new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.green'));
            }
            else if (healthScore >= 50) {
                this.iconPath = new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.yellow'));
            }
            else {
                this.iconPath = new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.red'));
            }
        }
        else {
            this.iconPath = new vscode.ThemeIcon('folder');
        }
        this.contextValue = 'project';
    }
}
class ProjectTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    projects = [];
    healthScores = {};
    refresh() {
        this.projects = loadProjects();
        this.healthScores = loadHealthScores();
        this._onDidChangeTreeData.fire(undefined);
    }
    getTreeItem(element) {
        return element;
    }
    getChildren() {
        if (this.projects.length === 0) {
            this.refresh();
        }
        // Sort: pinned first, then by name
        const sorted = [...this.projects].sort((a, b) => {
            if (a.isPinned !== b.isPinned) {
                return a.isPinned ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        });
        return sorted.map(project => {
            const health = this.healthScores[project.path];
            return new ProjectItem(project, health?.details?.totalScore, health?.details?.category);
        });
    }
}
// ---------------------------------------------------------------------------
// Health summary provider
// ---------------------------------------------------------------------------
class HealthSummaryItem extends vscode.TreeItem {
    constructor(label, description, icon) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = description;
        this.iconPath = icon;
    }
}
class HealthSummaryProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    refresh() {
        this._onDidChangeTreeData.fire(undefined);
    }
    getTreeItem(element) {
        return element;
    }
    getChildren() {
        const projects = loadProjects();
        const scores = loadHealthScores();
        let healthy = 0, attention = 0, critical = 0, unscored = 0;
        for (const project of projects) {
            const health = scores[project.path];
            if (!health?.details?.totalScore) {
                unscored++;
            }
            else if (health.details.totalScore >= 80) {
                healthy++;
            }
            else if (health.details.totalScore >= 50) {
                attention++;
            }
            else {
                critical++;
            }
        }
        const items = [
            new HealthSummaryItem('Total Projects', `${projects.length}`, new vscode.ThemeIcon('folder')),
            new HealthSummaryItem('Healthy', `${healthy}`, new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.green'))),
            new HealthSummaryItem('Needs Attention', `${attention}`, new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.yellow'))),
            new HealthSummaryItem('Critical', `${critical}`, new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('charts.red'))),
        ];
        if (unscored > 0) {
            items.push(new HealthSummaryItem('Not Scored', `${unscored}`, new vscode.ThemeIcon('circle-outline')));
        }
        return items;
    }
}
// ---------------------------------------------------------------------------
// Extension activation
// ---------------------------------------------------------------------------
function activate(context) {
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
    context.subscriptions.push(vscode.commands.registerCommand('projectLauncher.refresh', () => {
        projectProvider.refresh();
        healthProvider.refresh();
    }), vscode.commands.registerCommand('projectLauncher.openInVSCode', (item) => {
        const uri = vscode.Uri.file(item.project.path);
        vscode.commands.executeCommand('vscode.openFolder', uri, { forceNewWindow: true });
    }), vscode.commands.registerCommand('projectLauncher.openInTerminal', (item) => {
        const terminal = vscode.window.createTerminal({
            name: item.project.name,
            cwd: item.project.path,
        });
        terminal.show();
    }), vscode.commands.registerCommand('projectLauncher.openInFinder', (item) => {
        (0, child_process_1.exec)(`open "${item.project.path}"`);
    }), vscode.commands.registerCommand('projectLauncher.copyPath', (item) => {
        vscode.env.clipboard.writeText(item.project.path);
        vscode.window.showInformationMessage(`Copied: ${item.project.path}`);
    }), vscode.commands.registerCommand('projectLauncher.openApp', () => {
        (0, child_process_1.exec)('open "/Applications/Project Launcher.app"');
    }));
    // Initial load
    projectProvider.refresh();
}
function deactivate() { }
//# sourceMappingURL=extension.js.map