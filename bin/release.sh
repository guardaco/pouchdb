#!/bin/bash

set -e

if [ ! -z $DRY_RUN ]; then
  echo "Doing a dry run release..."
elif [ ! -z $BETA ]; then
  echo "Doing a beta release to npm..."
else
  echo "Doing a real release! Use DRY_RUN=1 for a dry run instead."
fi

if [ ! -z $PACK ]; then
  echo "Will npm pack instead of npm publish..."
fi

#make sure deps are up to date
rm -fr node_modules
npm install

# get current version
VERSION=$(node --eval "console.log(require('./packages/node_modules/pouchdb/package.json').version);")

# Create a temporary build directory
SOURCE_DIR=$(git name-rev --name-only HEAD)
BUILD_DIR=build_"${RANDOM}"
git checkout -b $BUILD_DIR

# Update dependency versions inside each package.json (replace the "*")
node bin/update-package-json-for-publish.js

# Publish all modules with Lerna
for pkg in $(ls packages/node_modules); do
  if [ ! -d "packages/node_modules/$pkg" ]; then
    continue
  elif [ "true" = $(node --eval "console.log(require('./packages/node_modules/$pkg/package.json').private);") ]; then
    continue
  fi
  cd packages/node_modules/$pkg
  echo "Publishing $pkg..."
  if [ ! -z $DRY_RUN ]; then
    echo "Dry run, not publishing"
    if [ ! -z $PACK ]; then
        npm pack
    fi
  elif [ ! -z $BETA ]; then
    if [ ! -z $PACK ]; then
        npm pack
    elif [ ! -z $OTP ]; then
        npm publish --otp $OTP --tag beta
    else
        npm publish --tag beta
    fi
  else
    if [ ! -z $PACK ]; then
        npm pack
    elif [ ! -z $OTP ]; then
        npm publish --otp $OTP
    else
        npm publish
    fi
  fi
  cd -
done

# Create git tag, which is also the Bower/Github release
rm -fr lib src dist bower.json component.json package.json
cp -r packages/node_modules/pouchdb/{src,lib,dist,bower.json,component.json,package.json} .
git add -f lib src dist *.json
git rm -fr packages bin docs scripts tests

git commit -m "build $VERSION"

# Only "publish" to GitHub/Bower if this is a non-beta non-dry run
if [ -z $DRY_RUN ]; then
 if [ -z $BETA ]; then
    # Tag and push
    git tag $VERSION
    git push --tags git@github.com:guardaco/pouchdb.git $VERSION

    # Cleanup
    git checkout $SOURCE_DIR
    git branch -D $BUILD_DIR
  fi
fi
