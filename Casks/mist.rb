cask "mist" do
  version "1.0.10"
  sha256 "c8d9ed412f76a207a7587c3074025b25fc73caf2502b1a2d235ac9e04fb0cfb2"

  url "https://cdn.uid.si/Mist-#{version}.dmg", verified: "uid.si/"
  name "Mist"
  desc "Lightweight S3 image uploader for macOS"
  homepage "https://github.com/missuo/Mist"

  app "Mist.app"

  postflight do
    require "fileutils"

    services_dir = File.expand_path("~/Library/Services")
    workflow_path = File.join(services_dir, "Upload to Mist.workflow")
    contents_dir = File.join(workflow_path, "Contents")

    FileUtils.mkdir_p(services_dir)
    FileUtils.rm_rf(workflow_path) if File.directory?(workflow_path)
    FileUtils.mkdir_p(contents_dir)

    File.write(File.join(contents_dir, "Info.plist"), <<~'PLIST')
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleIdentifier</key>
          <string>com.apple.Automator.UploadToMist</string>
          <key>CFBundleName</key>
          <string>Upload to Mist</string>
          <key>CFBundleVersion</key>
          <string>1.2</string>
          <key>NSServices</key>
          <array>
              <dict>
                  <key>NSMenuItem</key>
                  <dict>
                      <key>default</key>
                      <string>Upload to Mist</string>
                  </dict>
                  <key>NSMessage</key>
                  <string>runWorkflowAsService</string>
                  <key>NSSendFileTypes</key>
                  <array>
                      <string>public.item</string>
                  </array>
              </dict>
          </array>
      </dict>
      </plist>
    PLIST

    File.write(File.join(contents_dir, "document.wflow"), <<~'WFLOW')
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>AMApplicationBuild</key>
          <string>523</string>
          <key>AMApplicationVersion</key>
          <string>2.10</string>
          <key>AMDocumentVersion</key>
          <string>2</string>
          <key>actions</key>
          <array>
              <dict>
                  <key>action</key>
                  <dict>
                      <key>AMAccepts</key>
                      <dict>
                          <key>Container</key>
                          <string>List</string>
                          <key>Optional</key>
                          <false/>
                          <key>Types</key>
                          <array>
                              <string>com.apple.cocoa.path</string>
                          </array>
                      </dict>
                      <key>AMActionVersion</key>
                      <string>1.1.2</string>
                      <key>AMApplication</key>
                      <array>
                          <string>Automator</string>
                      </array>
                      <key>AMProvides</key>
                      <dict>
                          <key>Container</key>
                          <string>List</string>
                          <key>Types</key>
                          <array>
                              <string>com.apple.cocoa.path</string>
                          </array>
                      </dict>
                      <key>ActionBundlePath</key>
                      <string>/System/Library/Automator/Run Shell Script.action</string>
                      <key>ActionName</key>
                      <string>Run Shell Script</string>
                      <key>ActionParameters</key>
                      <dict>
                          <key>COMMAND_STRING</key>
                          <string>LOG="/tmp/mist-service.log"
{
echo "=== Debug Info ==="
echo "Date: $(date)"
echo "PWD: $PWD"
echo "USER: $USER"
echo "Arg count: $#"
echo "Args: $@"
echo "Arg1: $1"
echo "Arg2: $2"
echo "All args:"
for arg in "$@"; do
  echo "  - $arg"
done
echo ""

if [ $# -eq 0 ]; then
  echo "ERROR: No arguments received!"
  echo "This means Automator is not passing file paths."
  exit 1
fi

paths=""
for f in "$@"; do
  echo "Processing: $f"
  encoded=$(/usr/bin/python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))" "$f")
  [ -z "$paths" ] &amp;&amp; paths="$encoded" || paths="$paths,$encoded"
done

if [ -n "$paths" ]; then
  url="mist://files?$paths"
  echo "Opening URL: $url"
  /usr/bin/open "$url" &amp;
  echo "Command sent"
fi
} >> "$LOG" 2&gt;&amp;1
exit 0
</string>
                          <key>CheckedForUserDefaultShell</key>
                          <true/>
                          <key>inputMethod</key>
                          <integer>1</integer>
                          <key>shell</key>
                          <string>/bin/bash</string>
                      </dict>
                      <key>BundleIdentifier</key>
                      <string>com.apple.RunShellScript</string>
                  </dict>
              </dict>
          </array>
          <key>connectors</key>
          <dict/>
          <key>workflowMetaData</key>
          <dict>
              <key>serviceInputTypeIdentifier</key>
              <string>com.apple.Automator.fileSystemObject</string>
              <key>serviceOutputTypeIdentifier</key>
              <string>com.apple.Automator.nothing</string>
              <key>workflowTypeIdentifier</key>
              <string>com.apple.Automator.servicesMenu</string>
          </dict>
      </dict>
      </plist>
    WFLOW

    FileUtils.chmod(0o755, workflow_path)
    FileUtils.chmod(0o644, File.join(contents_dir, "Info.plist"))
    FileUtils.chmod(0o644, File.join(contents_dir, "document.wflow"))

    system "/System/Library/CoreServices/pbs", "-flush"
  end

  uninstall_postflight do
    require "fileutils"

    FileUtils.rm_rf(File.expand_path("~/Library/Services/Upload to Mist.workflow"))
  end

  zap trash: [
    "/tmp/mist-service.log",
  ]
end
