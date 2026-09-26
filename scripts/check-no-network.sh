#!/bin/sh
# Enforces REQ-G-01 / REQ-G-03: app code makes no network calls, no third-party packages.
# Only GameKit and SwiftData/CloudKit may touch the network.
cd "$(dirname "$0")/.." || exit 1
fail=0

hits=$(grep -rnE 'URLSession|NSURLConnection|import Network|import WebKit|WKWebView|SFSafariViewController|CFNetwork|CFStream|nw_connection' \
  --include='*.swift' GetSmarter GetSmarterTests)
[ -n "$hits" ] && { echo "Forbidden networking API:"; echo "$hits"; fail=1; }

urls=$(grep -rnE 'https?://' --include='*.swift' GetSmarter | grep -v '^GetSmarter/Services/Links.swift:')
[ -n "$urls" ] && { echo "URL literal outside Services/Links.swift:"; echo "$urls"; fail=1; }

if grep -q 'XCRemoteSwiftPackageReference\|XCLocalSwiftPackageReference' GetSmarter.xcodeproj/project.pbxproj ||
  find . -name Package.resolved -not -path './.build/*' | grep -q .; then
  echo "Swift packages are not allowed"; fail=1
fi

[ $fail -eq 0 ] && echo "no-network check passed"
exit $fail
