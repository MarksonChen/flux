## Build a Release Version

```
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Release clean build
```

## Creating a DMG

```
brew install create-dmg
create-dmg \
  --volname "Flux" \
  --window-pos 200 120 \
  --window-size 600 360 \
  --icon-size 100 \
  --icon "Flux.app" 150 125 \
  --app-drop-link 450 125 \
  Flux.dmg \
  build/Release/Flux.app
```

## GitHub Release

```
gh release create v1.0.0 Flux.dmg \
  --title "Flux v1.0.0" \
  --notes "Initial release - drag Flux.app to Applications to install"
```