## Build a Release Version

```
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Release clean build
```

## Creating a DMG

```
brew install create-dmg
rm -rf Flux.dmg
APP_PATH=$(xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Release \
  -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR" | awk '{print $3}')/Flux.app
create-dmg \
  --volname "Flux" \
  --window-pos 200 120 \
  --window-size 600 360 \
  --icon-size 100 \
  --icon "Flux.app" 150 125 \
  --app-drop-link 450 125 \
  Flux.dmg \
  "$APP_PATH"
```

## GitHub Release

```
gh release create v1.1.0 Flux.dmg \
  --title "Flux v1.1.0"
```