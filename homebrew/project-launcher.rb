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
