#!/usr/bin/env bash
# Export the Web preset and publish it to the gh-pages branch via a worktree.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
pages="$(dirname "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")/.worktrees/gh-pages"
cd "$root"

if [ ! -d "$pages" ]; then
	git fetch -q origin gh-pages
	git worktree add -q "$pages" gh-pages
fi

rm -rf build/web && mkdir -p build/web
godot --headless --import
godot --headless --export-release "Web" build/web/index.html

git -C "$pages" rm -rqf --ignore-unmatch .
cp -R build/web/. "$pages/"
touch "$pages/.nojekyll"
git -C "$pages" add -A
git -C "$pages" commit -qm "Deploy $(git rev-parse --short HEAD)" || { echo "No changes to deploy"; exit 0; }
git -C "$pages" push -q origin gh-pages
