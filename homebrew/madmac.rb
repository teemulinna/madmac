cask "madmac" do
  version "0.1.1"
  sha256 :no_check # Updated per release

  url "https://github.com/teemulinna/madmac/releases/download/v#{version}/madmac-#{version}.zip"
  name "MadMac"
  desc "Native macOS markdown reader and editor"
  homepage "https://github.com/teemulinna/madmac"

  app "MadMac.app"

  zap trash: [
    "~/Library/Preferences/com.madmac.app.plist",
    "~/Library/Saved Application State/com.madmac.app.savedState",
  ]
end
