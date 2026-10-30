#!/bin/sh
# Starts Sanskrit Composer Studio with macOS's own Ruby and sqlite3 and opens it in the browser.
cd "$(dirname "$0")/app" || exit 1
OPEN_BROWSER=1 exec /usr/bin/ruby lib/server.rb
