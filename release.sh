#!/bin/bash

set -e

cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

command -v github-release >/dev/null 2>&1 || { echo >&2 "Please install github-release."; exit 1; }

if [[ -z "$GITHUB_TOKEN" ]]; then
    if [[ "$SKIP_UPLOAD" != "true" ]]; then
        echo "GitHub token not set"
        exit 1
    fi
fi

rm -rf build
mkdir -p build

if [[ -z "$(git describe --abbrev=0 --tags 2>/dev/null)" ]]; then
    echo "No tags found"
    export NO_TAGS=true
    export APP_VERSION=v0.0.1
else
    export NO_TAGS=false
    export APP_VERSION="$(git describe --tags --always --dirty)"
fi

echo "APP_VERSION: $APP_VERSION"

echo "## Changelog" | tee -a build/release-notes.md
if [[ -f "./docs/notes/$APP_VERSION.md" ]]; then
    cat "./docs/notes/$APP_VERSION.md" | tee -a build/release-notes.md
fi
if [[ "$NO_TAGS" == "true" ]]; then
    echo "$(git log --oneline)" | tee -a build/release-notes.md
else
    echo "$(git log $(git describe --tags --abbrev=0 HEAD^)..HEAD --oneline)" | tee -a build/release-notes.md
fi

echo "Building kobopatch $APP_VERSION for windows 386"
GOOS=windows GOARCH=386 go build -ldflags "-X main.version=$APP_VERSION" -o "build/kobopatch-windows.exe" github.com/geek1011/kobopatch/kobopatch
echo "Building kobopatch $APP_VERSION for linux amd64"
GOOS=linux GOARCH=amd64 go build -ldflags "-X main.version=$APP_VERSION" -o "build/kobopatch-linux-64bit" github.com/geek1011/kobopatch/kobopatch
echo "Building kobopatch $APP_VERSION for linux 386"
GOOS=linux GOARCH=386 go build -ldflags "-X main.version=$APP_VERSION" -o "build/kobopatch-linux-32bit" github.com/geek1011/kobopatch/kobopatch
echo "Building kobopatch $APP_VERSION for linux arm"
GOOS=linux GOARCH=arm go build -ldflags "-X main.version=$APP_VERSION" -o "build/kobopatch-linux-arm" github.com/geek1011/kobopatch/kobopatch
echo "Building kobopatch $APP_VERSION for darwin amd64"
GOOS=darwin GOARCH=amd64 go build -ldflags "-X main.version=$APP_VERSION" -o "build/kobopatch-darwin-64bit" github.com/geek1011/kobopatch/kobopatch

if [[ "$SKIP_UPLOAD" != "true" ]]; then
    echo "Creating release"
    echo "Deleting old release if it exists"
    GITHUB_TOKEN=$GITHUB_TOKEN github-release delete \
        --user geek1011 \
        --repo kobopatch \
        --tag $APP_VERSION >/dev/null 2>/dev/null || true
    echo "Creating new release"
    GITHUB_TOKEN=$GITHUB_TOKEN github-release release \
        --user geek1011 \
        --repo kobopatch \
        --tag $APP_VERSION \
        --name "kobopatch $APP_VERSION" \
        --description "$(cat build/release-notes.md)"

    for f in build/kobopatch*;do 
        fn="$(basename $f)"
        echo "Uploading $fn"
        GITHUB_TOKEN=$GITHUB_TOKEN github-release upload \
            --user geek1011 \
            --repo kobopatch \
            --tag $APP_VERSION \
            --name "$fn" \
            --file "$f" \
            --replace
    done
fi