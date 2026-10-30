#!/bin/sh
# Starts Sanskrit Composer Studio and opens it in the browser.
# Needs Ruby and the sqlite3 command-line tool, e.g.:  sudo apt install ruby sqlite3
cd "$(dirname "$0")/app" || exit 1
for tool in ruby sqlite3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Please install $tool first (for example: sudo apt install ruby sqlite3)."
    exit 1
  fi
done
OPEN_BROWSER=1 exec ruby lib/server.rb
