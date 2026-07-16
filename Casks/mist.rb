cask "mist" do
  version "1.0.15"
  sha256 "99c8f0983d44f313dca93bfb882ac18be813bf70a99ea900a575100ef5973454" # auto-updated by the release workflow

  url "https://github.com/missuo/Mist/releases/download/v#{version}/Mist-#{version}.zip"
  name "Mist"
  desc "Native menu bar uploader for S3-compatible storage and S.EE"
  homepage "https://mist.ws/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma

  app "Mist.app"

  postflight do
    # Remove the legacy Automator service replaced by the Finder extension.
    require "fileutils"
    FileUtils.rm_rf(File.expand_path("~/Library/Services/Upload to Mist.workflow"))
  end

  uninstall quit: "nz.owo.Mist"

  zap trash: [
    "~/Library/Group Containers/group.nz.owo.Mist",
    "~/Library/Preferences/nz.owo.Mist.plist",
    "/tmp/mist-service.log",
  ]
end
