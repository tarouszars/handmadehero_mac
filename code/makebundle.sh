#!/bin/bash
# make a basic bundle / folder structure for macosx.
# public domain (by filip wanstrom)

if [ -z "$1" ]; then
  echo "usage: `basename $0` <name-of-bundle>"
  exit 1
fi

bundleName="$1"

bundleShort=${bundleName##*/} 

rm -rf "${bundleName}.app/"

if [ ! -d "${bundleName}.app/Contents/MacOS" ]; then
  mkdir -p "${bundleName}.app/Contents/MacOS"
fi

if [ ! -d "${bundleName}.app/Contents/Resources" ]; then
  mkdir -p "${bundleName}.app/Contents/Resources"
fi

if [ ! -d "${bundleName}.app/Contents/Resources" ]; then
  mkdir -p "${bundleName}.app/Contents/Framework"
fi

if [ ! -d "${bundleName}.app/Contents/Resources" ]; then
  mkdir -p "${bundleName}.app/Contents/Resources/data"
fi

if [ ! -d "${bundleName}.app/Contents/Resources/Base.lproj" ]; then
  mkdir -p "${bundleName}.app/Contents/Resources/Base.lproj" 
fi

if [ ! -f "${bundleName}.app/Contents/PkgInfo" ]; then
  echo "APPL????\c" > "${bundleName}.app/Contents/PkgInfo"
fi

if [ ! -f "${bundleName}.app/Contents/Info.plist" ]; then
  cat > "${bundleName}.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
		<key>CFBundleDevelopmentRegion</key>
		<string>en</string>
        <key>CFBundleExecutable</key>
        <string>${bundleShort}</string>
		<key>CFBundleIconFile</key>
		<string></string>
		<key>CFBundleInfoDictionaryVersion</key>
		<string>6.0</string>
		<key>CFBundleName</key>
		<string>${bundleShort}</string>
		<key>CFBundlePackageType</key>
		<string>APPL</string>
		<key>CFBundleShortVersionString</key>
		<string>1.0</string>
		<key>CFBundleSignature</key>
		<string>????</string>
		<key>CFBundleVersion</key>
		<string>1</string>
	    <key>NSPrincipalClass</key>
	    <string>NSApplication</string>
</dict>
</plist>
EOF
fi
