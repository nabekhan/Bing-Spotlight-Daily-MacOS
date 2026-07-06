# BingSpotlightDaily For Hammerspoon (MacOS)

Hammerspoon wallpaper Spoon for Bing daily images and Windows Spotlight.

## Install

```bash
unzip BingSpotlightDaily.spoon.zip -d ~/.hammerspoon/Spoons
```

```lua
hs.loadSpoon("BingSpotlightDaily")
spoon.BingSpotlightDaily:start()
```

## Config

```lua
spoon.BingSpotlightDaily.sources = {"bing", "spotlight"} -- "bing", "spotlight", or both
spoon.BingSpotlightDaily.bing_locales = {"en-US", "en-CA"} -- or "all"
spoon.BingSpotlightDaily.spotlight_locales = {"en-US", "en-GB"} -- or "all"
spoon.BingSpotlightDaily.rotate_every_minutes = 15 -- fixed interval
spoon.BingSpotlightDaily.randomize = true
spoon.BingSpotlightDaily:start()
```

Daily cycle instead of fixed minutes:

```lua
spoon.BingSpotlightDaily.rotate_every_minutes = nil
spoon.BingSpotlightDaily.rotate_within_cycle = true
spoon.BingSpotlightDaily.cycle_seconds = 24 * 60 * 60
```

## Storage

Default download folder:

```text
~/.Trash/BingSpotlightDaily
```

```lua
spoon.BingSpotlightDaily.cleanup_old_images = true
spoon.BingSpotlightDaily.dedupe_images = true
```

## Debug

```lua
spoon.BingSpotlightDaily:update()
spoon.BingSpotlightDaily:status()
spoon.BingSpotlightDaily:downloadedCount()
spoon.BingSpotlightDaily:rotateNow()
```

## GitHub release

Repository layout:

```text
.github/workflows/release.yml
BingSpotlightDaily.spoon/init.lua
BingSpotlightDaily.spoon/docs.json
BingSpotlightDaily.spoon/README.md
README.md
```

Release by pushing a tag:

```bash
git tag v1.1.0
git push origin v1.1.0
```

Or run **Actions → Release Spoon → Run workflow** and enter a tag.
