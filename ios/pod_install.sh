#!/bin/bash
# Workaround for CocoaPods not supporting Xcode 26's object version 70
# This script temporarily downgrades the project, runs pod install, then restores it

cd "$(dirname "$0")"

# Temporarily downgrade object version for CocoaPods compatibility
sed -i '' 's/objectVersion = 70;/objectVersion = 56;/' Runner.xcodeproj/project.pbxproj

# Run pod install
bundle exec pod install "$@"
EXIT_CODE=$?

# Restore object version for Xcode 26
sed -i '' 's/objectVersion = 56;/objectVersion = 70;/' Runner.xcodeproj/project.pbxproj

exit $EXIT_CODE
