#!/bin/sh
set -e
brew install node@20 || brew install node
export PATH="/opt/homebrew/opt/node@20/bin:/usr/local/opt/node@20/bin:$PATH"
node -v
cd "$CI_PRIMARY_REPOSITORY_PATH"
npm ci || npm install
npx cap sync ios
