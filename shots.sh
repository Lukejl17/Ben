#!/bin/zsh
# Visual QA loop: run the screenshot walk, export renamed PNGs to screenshots/<variant>/
set -e
variant=${1:-light}
darkflag=""
[[ "$variant" == "dark" ]] && darkflag="TEST_RUNNER_SCREENSHOT_DARK=1"
rm -rf "screenshots/$variant.xcresult" "screenshots/$variant"
env TEST_RUNNER_SCREENSHOTS=1 $darkflag xcodebuild -project Ben.xcodeproj -scheme Ben \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:BenUITests/ScreenshotTests -resultBundlePath "screenshots/$variant.xcresult" 2>&1 \
  | grep -E "Test Case.*(passed|failed)" | tail -1
mkdir -p "screenshots/$variant"
xcrun xcresulttool export attachments --path "screenshots/$variant.xcresult" --output-path "screenshots/$variant" > /dev/null
python3 - "$variant" << 'PY'
import json, shutil, sys
d = f"screenshots/{sys.argv[1]}"
m = json.load(open(f"{d}/manifest.json"))
for t in m:
    for a in t["attachments"]:
        shutil.move(f"{d}/{a['exportedFileName']}", f"{d}/{a['suggestedHumanReadableName'].split('_0_')[0]}.png")
PY
rm -f "screenshots/$variant/manifest.json"; rm -rf "screenshots/$variant.xcresult"
echo "→ screenshots/$variant/"
