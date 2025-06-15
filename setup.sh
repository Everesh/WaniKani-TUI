#!/usr/bin/env bash
set -e

echo "Bootstrapping environment..."

if ! command -v ruby &> /dev/null; then
  echo "Ruby not found. Please install Ruby before running this script!"
  exit 1
fi

if ! gem list bundler -i > /dev/null; then
  echo "Installing bundler..."
  gem install bundler
fi

if ! gem list rake -i > /dev/null; then
  echo "Installing rake..."
  gem install rake
fi

if ! command -v python3 &> /dev/null; then
  echo "Python 3 not found. Please install it before continuing!"
  exit 1
fi

echo "Running Rake setup task..."
rake setup
