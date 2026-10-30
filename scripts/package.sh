#!/bin/sh
# Builds the download everyone installs: dist/SanskritComposerStudio-<version>.zip
#
#   scripts/package.sh <version> <data zip>
#
# The zip holds the launchers, the app, the databases, a copy of WEBrick (Ruby 3 no longer ships it)
# and, for Windows, a portable Ruby and sqlite3.exe. Needs curl, unzip, zip, 7z and gem (the GitHub
# Actions Ubuntu runner has them all). SKIP_DOWNLOADS=1 leaves out WEBrick and the Windows runtime,
# for a quick local build that runs only on macOS (whose Ruby includes WEBrick).
set -eu

VERSION=$1
DATA_ZIP=$2

RUBY_WIN=3.3.6-1                                     # RubyInstaller portable archive (oneclick/rubyinstaller2)
SQLITE_WIN=2024/sqlite-tools-win-x64-3470200.zip     # sqlite.org command-line tools, 3.47.2
WEBRICK=1.9.1

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
NAME=SanskritComposerStudio-$VERSION
PKG=$WORK/$NAME
APP=$PKG/app

mkdir -p "$APP/data" "$APP/lib/vendor" "$APP/runtime/sqlite"
cp -R "$ROOT/lib" "$ROOT/public" "$APP/"
cp "$ROOT/launchers/"* "$PKG/"
cp "$ROOT/README.md" "$PKG/README.md"
cp "$ROOT/data/README.md" "$ROOT/data/LICENSE-Cologne.txt" "$APP/data/"

echo "Data: $DATA_ZIP"
unzip -q "$DATA_ZIP" -d "$APP/data"
if command -v sha256sum >/dev/null; then (cd "$APP/data" && sha256sum -c SHA256SUMS)
else (cd "$APP/data" && shasum -a 256 -c SHA256SUMS); fi
cmp "$APP/data/SHA256SUMS" "$ROOT/data/SHA256SUMS"   # the release data is the version this code expects

if [ "${SKIP_DOWNLOADS:-}" != 1 ]; then
echo "WEBrick $WEBRICK"
(cd "$WORK" && gem fetch webrick -v "$WEBRICK" >/dev/null && gem unpack "webrick-$WEBRICK.gem" >/dev/null)
mv "$WORK/webrick-$WEBRICK" "$APP/lib/vendor/webrick"

echo "Ruby $RUBY_WIN for Windows"
curl -fsSL -o "$WORK/ruby.7z" \
  "https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-$RUBY_WIN/rubyinstaller-$RUBY_WIN-x64.7z"
7z x -o"$WORK" "$WORK/ruby.7z" >/dev/null
mv "$WORK/rubyinstaller-$RUBY_WIN-x64" "$APP/runtime/ruby"
rm -rf "$APP/runtime/ruby/share/doc" "$APP/runtime/ruby/include"

echo "sqlite3 for Windows"
curl -fsSL -o "$WORK/sqlite.zip" "https://www.sqlite.org/$SQLITE_WIN"
unzip -q -j "$WORK/sqlite.zip" sqlite3.exe -d "$APP/runtime/sqlite"
fi

mkdir -p "$ROOT/dist"
rm -f "$ROOT/dist/$NAME.zip"
(cd "$WORK" && zip -q -r -9 "$ROOT/dist/$NAME.zip" "$NAME")
rm -rf "$WORK"
ls -l "$ROOT/dist/$NAME.zip"
