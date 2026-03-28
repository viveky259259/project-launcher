Project Launcher Flutter App — Comprehensive Exploration Report

       I've thoroughly analyzed the Project Launcher Flutter app to understand its architecture, distribution, and how it interacts with the system. Here's what I found:

       ---
       1. APP STARTUP FLOW (lib/main.dart)

       Initialization Sequence:
       - Lines 13-40: main() function orchestrates startup in this order:
         a. WidgetsFlutterBinding.ensureInitialized() — Flutter initialization
         b. PremiumService.configure() — Subscription/premium setup
         c. Optional API Server — Started from SharedPreferences config (port 9847)
         d. NotificationService.initialize() — Loads notification rules from persistent storage
         e. NotificationService.start() — Begins background monitoring (if enabled in prefs)
         f. BackgroundMonitor.start() — Checks project health & git status
         g. runApp(ProjectLauncherApp) — Launches UI

       Key Insight for CLI Install Prompt: The startup is clean and modular. A CLI install check could be added after NotificationService initialization (line 28), since by that point preferences are loaded.
       This is before the UI renders, allowing for a blocking prompt if needed.

       ---
       2. NOTIFICATION/DIALOG PATTERNS

       NotificationService (lib/services/notification_service.dart, 430 lines):
       - Native notifications use platform-specific commands:
         - macOS: osascript with display notification (lines 335-341)
         - Linux: notify-send command (lines 342-346)
         - Windows: PowerShell toast (commented, line 348)
       - Notifications are stored in memory with 4-hour cooldown per type per project (line 147)
       - History persists to SharedPreferences as JSON (lines 410-429)
       - Notifications are user-configurable with enable/disable and thresholds (lines 351-360)

       OnboardingScreen (lib/screens/onboarding_screen.dart, lines 1-100):
       - Shows a clean dialog-style interface with icon, headline, description
       - Two action cards with Material Design (lines 65-93)
       - Uses AppColors.accent and theme colors from launcher_theme package
       - Callbacks: onStartScan() and onAddManually() (lines 6-7)

       HomeScreen (lib/screens/home_screen.dart, lines 1-100):
       - Initializes with _checkFirstRun() (line 93) — suggests onboarding detection
       - Uses BackgroundMonitor.addListener() to react to system changes (line 95)
       - Theme switching capability built-in (line 67: _showThemeSwitcher)

       Key Dialog Pattern: The app uses Material Design dialogs and native notifications. For a CLI install prompt, a Flutter showDialog() with custom content would fit the aesthetic.

       ---
       3. PLATFORM HELPER (lib/services/platform_helper.dart)

       Shell Command Execution:
       - Lines 68-92: openInTerminal(path) — Opens system terminal using:
         - macOS: open -a Terminal <path> (line 70)
         - Linux: Tries gnome-terminal, konsole, xfce4-terminal, xterm (lines 75-88)
         - Windows: cmd /k cd /d "<path>" (lines 71-72)
       - Lines 94-105: openInVSCode(path) — Launches VS Code via code <path> or macOS app launch
       - Lines 34-54: openUrl(), openFile(), openInFileManager() — Various OS interactions using Process.run()

       Key Insight: The app uses dart:io Process.run() to execute shell commands. This pattern can be extended to run a CLI installer script.

       ---
       4. LAUNCHER SERVICE (lib/services/launcher_service.dart)

       Simple wrapper (31 lines) around PlatformHelper:
       - openInTerminal(), openInVSCode(), openInFinder() — project-specific launches
       - openTerminal(), openVSCode() — home directory launches
       - Each logs to AppLogger with the _tag = 'Launcher'

       No direct CLI management — it's just for launching external apps. But the pattern shows how the app invokes external tools.

       ---
       5. CLI TOOL (cli/Cargo.toml and cli/src/main.rs)

       Binary Name & Metadata:
       - Package name: plauncher (line 2)
       - Binary name: plauncher (line 9)
       - Version: 0.1.0 (line 3)
       - Dependencies: serde, serde_json, chrono, anyhow, colored
       - Release profile: LTO enabled, single codegen unit, stripped binary (lines 19-23)

       CLI Source (cli/src/main.rs, 523 lines):
       - Loads projects from ~/.project_launcher/projects.json (lines 37-45)
       - Loads health scores from ~/.project_launcher/health_cache.json (lines 47-57)
       - Git helpers: branch name, uncommitted changes, unpushed count (lines 71-100+)
       - Command structure suggests listing, filtering, and displaying projects

       Deployment Method:
       - Currently installed via scripts/addproject bash script (not the Rust CLI yet)
       - The Rust binary would need to be compiled and distributed

       ---
       6. HOMEBREW CASK

       File: /Users/vivekyadav/Documents/Projects/claude/project_launcher/homebrew/project-launcher.rb (19 lines)

       cask "project-launcher" do
         version "2.0.0"
         sha256 "PLACEHOLDER_SHA256"

         url "https://github.com/nickvivek/project-launcher/releases/download/v#{version}/ProjectLauncher-#{version}-macos.dmg"
         name "Project Launcher"
         desc "Developer project dashboard with health scores, git status, and instant launch"
         homepage "https://projectlauncher.dev"

         depends_on macos: ">= :big_sur"
         app "Project Launcher.app"

         zap trash: [
           "~/.project_launcher",
           "~/Library/Preferences/com.stringswaytech.projectbrowser.plist",
           "~/Library/Caches/com.stringswaytech.projectbrowser",
         ]
       end

       Key Points:
       - DMG is downloaded from GitHub releases
       - SHA256 and version are placeholders (updated by release pipeline)
       - Custom tap: viveky259259/project-launcher (referenced in release.sh, line 338)
       - App installed to /Applications/Project Launcher.app
       - Cleanup on uninstall includes ~/.project_launcher directory

       ---
       7. GITHUB RELEASES & DISTRIBUTION

       Release Pipeline (release.sh, 369 lines):

       8-Phase Release Process:
       1. PREPARE (lines 47-103): Load secrets, validate env vars, check tools, verify git state
       2. VERSION (lines 105-150): Bump version in pubspec.yaml, generate changelog
       3. BUILD (lines 194-231):
         - Build Rust library as universal binary (x86_64 + aarch64)
         - flutter build macos --release
         - Bundle dylib into app
       4. SIGN (lines 233-253): Code sign with Developer ID
       5. VERIFY (lines 255-263): Verify signature with codesign and spctl
       6. NOTARIZE (lines 265-284): Submit to Apple, wait for approval, staple ticket
       7. PACKAGE (lines 286-312): Create DMG, sign and notarize it
       8. PUBLISH (lines 317-348):
         - Git push commit and tag
         - Create GitHub Release with DMG attached
         - Update Homebrew tap at viveky259259/homebrew-project-launcher

       Secrets: Loads from ~/.project-launcher-secrets or .env (lines 54-70)
       - Required: APPLE_ID, TEAM_ID, APP_SPECIFIC_PASSWORD, PADDLE_API_KEY, PADDLE_IS_SANDBOX

       GitHub Release URL Format:
       https://github.com/viveky259259/project-launcher/releases/download/v{version}/ProjectLauncher-{version}-macos.dmg

       Homebrew Tap Update (lines 336-348):
       - Clones viveky259259/homebrew-project-launcher
       - Updates version and SHA256 in cask file
       - Commits and pushes to tap repo

       ---
       8. INSTALLATION SCRIPTS

       install.sh (root, 49 lines):
       - Copies shell script scripts/addproject to /usr/local/bin/addproject
       - Uses sudo if /usr/local/bin is not writable
       - Copies built app to /Applications/Project Launcher.app

       scripts/install.sh (90 lines):
       - Builds Rust FFI library if needed
       - Builds Flutter macOS release
       - Bundles dylib into app
       - Code signs with entitlements
       - Kills running instance
       - Installs to /Applications
       - Launches the app

       scripts/addproject (bash, 84 lines):
       - Accepts optional path argument or uses current directory
       - Resolves to absolute path
       - Reads ~/.project_launcher/projects.json
       - Uses Python3 to safely manipulate JSON
       - Adds new project entry with timestamp
       - Prevents duplicates

       ---
       9. DATA DIRECTORY & PERSISTENCE

       Location: ~/.project_launcher/ (defined in PlatformHelper line 22)

       Files:
       - projects.json — List of projects with metadata
       - health_cache.json — Cached health scores for each project
       - notificationRules — Stored in SharedPreferences (not a file)
       - notificationHistory — Stored in SharedPreferences (not a file)

       SharedPreferences Keys (from code):
       - apiServerEnabled, apiServerPort
       - notificationsEnabled
       - appTheme, notificationRules, notificationHistory

       ---
       10. SUMMARY: HOW THE ECOSYSTEM WORKS

       Distribution Flow:
       Code commit → release.sh → Build + Sign + Notarize → GitHub Release (DMG)
                                                          ↓
                                           Homebrew tap updated automatically
                                           $ brew tap viveky259259/project-launcher
                                           $ brew install project-launcher

       CLI Integration:
       - Currently: addproject bash script in scripts/ directory
       - Rust CLI (plauncher) is built but not yet integrated into distribution
       - addproject modifies ~/.project_launcher/projects.json directly
       - App automatically detects changes (HomeScreen watches file, line 94)

       Shell Command Execution:
       - App uses dart:io Process.run() for all OS interactions
       - Pattern: check platform, build appropriate command, execute
       - Can be extended to run CLI installers or setup scripts

       Notification Pattern:
       - Native OS notifications via platform-specific commands
       - History stored in SharedPreferences
       - Configurable rules with enable/disable and thresholds

       ---
       11. KEY FILES & ABSOLUTE PATHS

       ┌──────────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────┐
       │      Component       │                                                Path                                                 │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ App startup          │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/lib/main.dart                          │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Notifications        │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/lib/services/notification_service.dart │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Platform helpers     │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/lib/services/platform_helper.dart      │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Launcher service     │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/lib/services/launcher_service.dart     │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Home screen          │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/lib/screens/home_screen.dart           │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Onboarding screen    │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/lib/screens/onboarding_screen.dart     │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ CLI Cargo.toml       │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/cli/Cargo.toml                         │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ CLI main.rs          │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/cli/src/main.rs                        │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Homebrew formula     │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/homebrew/project-launcher.rb           │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Release pipeline     │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/release.sh                             │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Install script       │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/install.sh                             │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ Build install script │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/scripts/install.sh                     │
       ├──────────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
       │ addproject script    │ /Users/vivekyadav/Documents/Projects/claude/project_launcher/scripts/addproject                     │
       └──────────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────┘

       This comprehensive exploration reveals a well-architected macOS app with modular services, clean startup sequencing, native platform integration, and a robust release pipeline integrated with Homebrew.
        The project is production-ready and follows Apple's code signing and notarization best practices.
