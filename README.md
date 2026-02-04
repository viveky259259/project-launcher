# Project Launcher

A macOS app to quickly access and launch your development projects in Terminal or VS Code.

## Features

- **Quick project access** - See all your projects in one place
- **One-click launch** - Open projects in Terminal, VS Code, or Finder
- **Terminal integration** - Add projects from command line with `addproject`
- **Smart sorting** - Sort by last opened or alphabetically
- **Folder grouping** - Group projects by parent directory
- **Auto-refresh** - Automatically detects new projects added from terminal

## Installation

### Option 1: Download Release

1. Download the latest `.dmg` from [Releases](https://github.com/user/project-launcher/releases)
2. Open the DMG and drag "Project Launcher" to Applications
3. Run the included `Install CLI.command` to install the `addproject` command

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/user/project-launcher.git
cd project-launcher

# Install dependencies
flutter pub get

# Build the app
flutter build macos

# Run the installer
./install.sh
```

## Usage

### Adding Projects

**From Terminal:**
```bash
# Add current directory
addproject

# Add a specific path
addproject /path/to/project
addproject ~/Projects/my-app
```

**From the App:**
- Click the `+` button in the top right
- Enter the full path to your project

### Opening Projects

Each project card has four action buttons:

| Button | Action |
|--------|--------|
| Terminal (orange) | Opens project in Terminal.app |
| Code (blue) | Opens project in VS Code |
| Folder (gray) | Opens project in Finder |
| Delete (red) | Removes project from list |

### View Options

**Show by:**
- **List** - Flat list of all projects
- **Folder** - Grouped by parent directory

**Sort by:**
- **Recent** - Last opened first (default)
- **Name** - Alphabetical order

## Configuration

Projects are stored in `~/.project_launcher/projects.json`

## Requirements

- macOS 10.14 or later
- VS Code (optional, for "Open in VS Code" feature)

## Building for Release

```bash
# Build the app
flutter build macos

# Create DMG for distribution
./scripts/build-dmg.sh
```

## License

MIT License - see [LICENSE](LICENSE) for details.
