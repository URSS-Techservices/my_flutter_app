#!/bin/bash
set -e

echo "Cleaning old Flutter SDK"
rm -rf flutter

echo "Cloning Flutter SDK"
git clone https://github.com/flutter/flutter.git -b stable

export PATH="$PWD/flutter/bin:$PATH"

flutter doctor
flutter pub get
flutter build web
