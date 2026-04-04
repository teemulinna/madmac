cask "macmd" do
  version "0.1.0"
  sha256 :no_check # Updated per release

  url "https://github.com/teemulinna/macmd/releases/download/v#{version}/macmd-#{version}.zip"
  name "macmd"
  desc "Native macOS markdown reader and editor"
  homepage "https://github.com/teemulinna/macmd"

  app "macmd.app"

  zap trash: [
    "~/Library/Preferences/com.macmd.app.plist",
    "~/Library/Saved Application State/com.macmd.app.savedState",
  ]
end
