--- === BingSpotlightDaily ===
---
--- Unified Bing + Windows Spotlight wallpaper rotation for macOS via Hammerspoon.
---
--- Choose Bing, Spotlight, or both; fetch one, many, or all configured locales;
--- and rotate through all retrieved wallpapers automatically.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "BingSpotlightDaily"
obj.version = "1.1"
obj.author = "nabekhan"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT"

--- BingSpotlightDaily.sources
--- Variable
--- Wallpaper sources to use. Accepts "bing", "spotlight", "both", or a table such as {"bing", "spotlight"}. Defaults to {"bing", "spotlight"}.
obj.sources = {"bing", "spotlight"}

--- BingSpotlightDaily.bing_locales
--- Variable
--- Bing locales/markets to check. Accepts a single locale string, a table of locales, or the string "all" to use the built-in locale list. Defaults to {"en-US"}.
obj.bing_locales = {"en-US"}

--- BingSpotlightDaily.spotlight_locales
--- Variable
--- Windows Spotlight locales to check. Accepts a single locale string, a table of locales, or the string "all" to use the built-in locale list. Defaults to {"en-US"}.
obj.spotlight_locales = {"en-US"}

--- BingSpotlightDaily.all_locales
--- Variable
--- Built-in locale list used when bing_locales or spotlight_locales is set to "all". You can replace or extend this table if you want a larger or smaller carousel. Defaults to a broad curated list of common markets.
obj.all_locales = {
    "ar-SA", "bg-BG", "cs-CZ", "da-DK", "de-DE", "el-GR", "en-AU", "en-CA",
    "en-GB", "en-IE", "en-IN", "en-NZ", "en-SG", "en-US", "es-ES", "es-MX",
    "fi-FI", "fr-BE", "fr-CA", "fr-FR", "he-IL", "hr-HR", "hu-HU", "id-ID",
    "it-IT", "ja-JP", "ko-KR", "lt-LT", "lv-LV", "nb-NO", "nl-NL", "pl-PL",
    "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sk-SK", "sl-SI", "sv-SE", "th-TH",
    "tr-TR", "uk-UA", "zh-CN", "zh-HK", "zh-TW"
}

--- BingSpotlightDaily.uhd_resolution
--- Variable
--- If true, request Bing wallpapers in UHD when available. Defaults to true.
obj.uhd_resolution = true

--- BingSpotlightDaily.spotlight_image_count
--- Variable
--- Number of Spotlight images to request per locale. Spotlight API v4 allows 1 to 4. Defaults to 4.
obj.spotlight_image_count = 4

--- BingSpotlightDaily.spotlight_portrait
--- Variable
--- If true, request Spotlight portrait images; if false, request landscape images; if nil, infer from the main screen. Defaults to nil.
obj.spotlight_portrait = nil

--- BingSpotlightDaily.spotlight_v3_fallback
--- Variable
--- If true, fall back to the older Spotlight v3 API when v4 returns no images for a locale. Defaults to true.
obj.spotlight_v3_fallback = true

--- BingSpotlightDaily.interval
--- Variable
--- How often to refresh feeds, in seconds. Defaults to 24 hours.
obj.interval = 24 * 60 * 60

--- BingSpotlightDaily.rotate_within_cycle
--- Variable
--- If true, rotate evenly across cycle_seconds when rotate_every_minutes is nil or 0. Defaults to true.
obj.rotate_within_cycle = true

--- BingSpotlightDaily.cycle_seconds
--- Variable
--- Length of one full rotation cycle, in seconds, when using cycle-based rotation. Defaults to 24 hours.
obj.cycle_seconds = 24 * 60 * 60

--- BingSpotlightDaily.rotate_every_minutes
--- Variable
--- If set to a positive number, rotate wallpapers every X minutes instead of using cycle_seconds. Defaults to nil.
obj.rotate_every_minutes = nil

--- BingSpotlightDaily.randomize
--- Variable
--- If true, shuffle the roster whenever a new feed is downloaded. Defaults to false.
obj.randomize = false

--- BingSpotlightDaily.save_dir
--- Variable
--- Directory where downloaded images are stored. Defaults to ~/.Trash/BingSpotlightDaily so they behave like temporary files.
obj.save_dir = nil

--- BingSpotlightDaily.cleanup_old_images
--- Variable
--- If true, delete old Spoon-managed files from save_dir that are no longer part of the active roster. Defaults to true.
obj.cleanup_old_images = true

--- BingSpotlightDaily.dedupe_images
--- Variable
--- If true, detect exact duplicate downloaded image files by checksum, delete duplicate files, and keep only one roster item per unique image before rotation starts. Defaults to true.
obj.dedupe_images = true

--- BingSpotlightDaily.show_notifications
--- Variable
--- If true, show a notification whenever the wallpaper changes. Defaults to false.
obj.show_notifications = false

--- BingSpotlightDaily.user_agent
--- Variable
--- User-Agent string used for API requests and image downloads. Defaults to "Mozilla/5.0".
obj.user_agent = "Mozilla/5.0"

--- BingSpotlightDaily.min_rotation_seconds
--- Variable
--- Minimum time each wallpaper should stay on screen. Defaults to 60 seconds.
obj.min_rotation_seconds = 60

local SETTINGS_PREFIX = "BingSpotlightDaily."
local FILE_PREFIX = "bsd-"

local function log(message)
    print(obj.name .. ": " .. tostring(message))
end

local function settingsKey(key)
    return SETTINGS_PREFIX .. key
end

local function shellQuote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function pathJoin(dir, name)
    dir = tostring(dir or "")
    name = tostring(name or "")
    if dir:sub(-1) == "/" then
        return dir .. name
    end
    return dir .. "/" .. name
end

local function ensureDir(path)
    if not path or path == "" then return end
    if not hs.fs.attributes(path, "mode") then
        os.execute("/bin/mkdir -p " .. shellQuote(path))
    end
end

local function defaultSaveDir()
    return pathJoin(os.getenv("HOME") or "", ".Trash/BingSpotlightDaily")
end

local function saveDir()
    return obj.save_dir or defaultSaveDir()
end

local function urlencode(s)
    return tostring(s):gsub("([^%w%-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

local function decodeJson(s)
    local ok, decoded = pcall(function()
        return hs.json.decode(s)
    end)
    if not ok then return nil, decoded end
    return decoded, nil
end

local function cleanOneLine(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("[\r\n].*$", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    return s
end

local function normalizeUrl(url)
    if type(url) ~= "string" or url == "" then return nil end
    if url:sub(1, 2) == "//" then
        return "https:" .. url
    elseif url:sub(1, 1) == "/" then
        return "https://arc.msn.com" .. url
    elseif url:match("^https?://") then
        return url
    end
    return nil
end

local function wantsSpotlightPortrait()
    if obj.spotlight_portrait ~= nil then return obj.spotlight_portrait end
    local screen = hs.screen.mainScreen()
    if not screen then return false end
    local frame = screen:frame()
    return frame.h > frame.w
end

local function countryFromLocale(locale)
    local c = tostring(locale or "en-US"):match("%-([A-Za-z][A-Za-z])$")
    return string.upper(c or "US")
end

local function boundedSpotlightImageCount()
    local n = tonumber(obj.spotlight_image_count) or 4
    if n < 1 then n = 1 end
    if n > 4 then n = 4 end
    return math.floor(n)
end

local function urlHash(s)
    local h = 5381
    s = tostring(s or "")
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 4294967296
    end
    return string.format("%08x", h)
end

local function fileUrl(path)
    return "file://" .. tostring(path):gsub(" ", "%%20")
end

local function wallpaperText(item)
    local bits = {}
    if item.source then table.insert(bits, string.upper(item.source)) end
    if item.locale then table.insert(bits, item.locale) end
    if item.title then table.insert(bits, item.title) end
    if item.copyright then table.insert(bits, item.copyright) end
    if #bits == 0 then return "Wallpaper updated" end
    return table.concat(bits, " — ")
end

local function formatDuration(seconds)
    seconds = math.floor((tonumber(seconds) or 0) + 0.5)
    if seconds >= 3600 then
        local hours = seconds / 3600
        if seconds % 3600 == 0 then
            return string.format("%d hour%s", hours, hours == 1 and "" or "s")
        end
        return string.format("%.1f hours", hours)
    elseif seconds >= 60 then
        local minutes = seconds / 60
        if seconds % 60 == 0 then
            return string.format("%d minute%s", minutes, minutes == 1 and "" or "s")
        end
        return string.format("%.1f minutes", minutes)
    end
    return string.format("%d second%s", seconds, seconds == 1 and "" or "s")
end

local function setWallpaper(path)
    local url = fileUrl(path)
    local screens = hs.screen.allScreens() or {}
    for _, screen in ipairs(screens) do
        screen:desktopImageURL(url)
    end
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function listCopy(t)
    local out = {}
    for _, v in ipairs(t or {}) do
        table.insert(out, v)
    end
    return out
end

local function normalizeSources(sources)
    if type(sources) == "string" then
        sources = string.lower(sources)
        if sources == "both" or sources == "all" then
            return {"bing", "spotlight"}
        elseif sources == "bing" or sources == "spotlight" then
            return {sources}
        else
            return {"bing", "spotlight"}
        end
    end

    local seen = {}
    local out = {}
    for _, source in ipairs(type(sources) == "table" and sources or {"bing", "spotlight"}) do
        source = string.lower(tostring(source))
        if (source == "bing" or source == "spotlight") and not seen[source] then
            seen[source] = true
            table.insert(out, source)
        end
    end

    if #out == 0 then
        out = {"bing", "spotlight"}
    end
    return out
end

local function normalizeLocales(setting)
    if setting == nil then return {"en-US"} end
    if type(setting) == "string" then
        if string.lower(setting) == "all" then
            return listCopy(obj.all_locales)
        else
            return {setting}
        end
    end

    local out, seen = {}, {}
    for _, locale in ipairs(type(setting) == "table" and setting or {}) do
        locale = tostring(locale)
        if string.lower(locale) == "all" then
            for _, v in ipairs(obj.all_locales) do
                if not seen[v] then
                    seen[v] = true
                    table.insert(out, v)
                end
            end
        elseif not seen[locale] then
            seen[locale] = true
            table.insert(out, locale)
        end
    end

    if #out == 0 then out = {"en-US"} end
    return out
end

local function feedHash(images)
    local keys = {}
    for _, item in ipairs(images or {}) do
        local key = table.concat({
            tostring(item.source or ""),
            tostring(item.locale or ""),
            tostring(item.url or "")
        }, "|")
        table.insert(keys, key)
    end
    table.sort(keys)
    return urlHash(table.concat(keys, "\n"))
end

local function addUnique(images, seen, item)
    if not item or not item.url then return end
    local key = table.concat({
        tostring(item.source or ""),
        tostring(item.locale or ""),
        tostring(item.url or "")
    }, "|")
    if seen[key] then return end
    seen[key] = true
    table.insert(images, item)
end

local function imageFileName(item)
    local source = tostring(item.source or "img")
    local locale = tostring(item.locale or "xx-XX"):gsub("[^%w%-]", "_")
    local base = tostring(item.url or ""):gsub("[?#].*$", ""):match("([^/]+)$")
    if not base or base == "" then base = "image" end
    base = base:gsub("[^%w%._%-]", "_")
    base = base:gsub("^%.+", "")
    if base == "" then base = "image" end
    local name = string.format("%s%s-%s-%s-%s", FILE_PREFIX, source, locale, urlHash(item.url), base)
    name = name:sub(1, 180)
    local lower = name:lower()
    if not lower:match("%.jpe?g$") and not lower:match("%.png$") and not lower:match("%.webp$") then
        name = name .. ".jpg"
    end
    return name
end

local function rotationSeconds(count)
    count = tonumber(count) or 0
    if count <= 1 then return nil end

    local fixed = tonumber(obj.rotate_every_minutes)
    if fixed and fixed > 0 then
        local seconds = fixed * 60
        local minSeconds = tonumber(obj.min_rotation_seconds) or 60
        if seconds < minSeconds then seconds = minSeconds end
        return seconds
    end

    if not obj.rotate_within_cycle then return nil end

    local cycle = tonumber(obj.cycle_seconds) or (24 * 60 * 60)
    local minSeconds = tonumber(obj.min_rotation_seconds) or 60
    if cycle < minSeconds then cycle = minSeconds end

    local seconds = cycle / count
    if seconds < minSeconds then seconds = minSeconds end
    return seconds
end

local function currentRotationSlot()
    local roster = obj.roster or {}
    local count = #roster
    if count == 0 then return nil, nil, nil end

    local secondsPerImage = rotationSeconds(count)
    if not secondsPerImage then return 1, nil, nil end

    local start = tonumber(obj.cycle_start) or os.time()
    local elapsed = os.time() - start
    if elapsed < 0 then elapsed = 0 end

    local effectiveCycle = secondsPerImage * count
    elapsed = elapsed % effectiveCycle

    local index = math.floor(elapsed / secondsPerImage) + 1
    local nextIn = secondsPerImage - (elapsed % secondsPerImage)
    if nextIn < 1 then nextIn = secondsPerImage end

    return index, nextIn, secondsPerImage
end

local scheduleNextRotation
local applyCurrentSlot

scheduleNextRotation = function(nextIn)
    if obj.rotationTimer then
        obj.rotationTimer:stop()
        obj.rotationTimer = nil
    end

    local roster = obj.roster or {}
    if #roster <= 1 then return end
    if not rotationSeconds(#roster) then return end

    nextIn = tonumber(nextIn) or rotationSeconds(#roster) or obj.min_rotation_seconds
    if nextIn < 1 then nextIn = 1 end

    obj.rotationTimer = hs.timer.doAfter(nextIn, function()
        obj.rotationTimer = nil
        applyCurrentSlot()
    end)
end

applyCurrentSlot = function()
    local roster = obj.roster or {}
    if #roster == 0 then
        log("no downloaded wallpapers are available to rotate")
        return
    end

    local index, nextIn, secondsPerImage = currentRotationSlot()
    local item = index and roster[index] or nil
    if not item or not item.path then
        log("could not select a wallpaper for the current rotation slot")
        return
    end

    if not hs.fs.attributes(item.path, "mode") then
        log("selected wallpaper is missing from disk: " .. tostring(item.path))
        return
    end

    setWallpaper(item.path)
    obj.rotation_index = index
    obj.last_url = item.url
    obj.last_file = item.path
    hs.settings.set(settingsKey("last_url"), obj.last_url)
    hs.settings.set(settingsKey("last_file"), obj.last_file)

    if secondsPerImage then
        log("set image " .. tostring(index) .. "/" .. tostring(#roster) .. " (" .. tostring(item.source) .. ", " .. tostring(item.locale) .. "); next rotation in " .. formatDuration(nextIn))
    else
        log("set image " .. tostring(index) .. "/" .. tostring(#roster) .. " (" .. tostring(item.source) .. ", " .. tostring(item.locale) .. ")")
    end

    if obj.show_notifications then
        hs.notify.new({
            title = obj.name,
            informativeText = wallpaperText(item),
        }):send()
    end

    scheduleNextRotation(nextIn)
end

local function cleanupOldFiles(roster)
    if not obj.cleanup_old_images then return end

    local dir = saveDir()
    local keep = {}
    for _, item in ipairs(roster or {}) do
        if item.path then keep[item.path] = true end
    end

    local ok, iter, dirObj = pcall(hs.fs.dir, dir)
    if not ok or type(iter) ~= "function" then return end

    for filename in iter, dirObj do
        if filename ~= "." and filename ~= ".." and filename:match("^" .. FILE_PREFIX) then
            local path = pathJoin(dir, filename)
            if not keep[path] then
                os.remove(path)
            end
        end
    end
end

local function buildRoster(images)
    local dir = saveDir()
    ensureDir(dir)

    local roster = {}
    for _, item in ipairs(images or {}) do
        table.insert(roster, {
            source = item.source,
            locale = item.locale,
            url = item.url,
            path = pathJoin(dir, imageFileName(item)),
            title = item.title,
            copyright = item.copyright,
            api = item.api,
        })
    end

    table.sort(roster, function(a, b)
        local ka = table.concat({a.source or "", a.locale or "", a.url or ""}, "|")
        local kb = table.concat({b.source or "", b.locale or "", b.url or ""}, "|")
        return ka < kb
    end)

    return roster
end

local function existingRosterForSameFeed(candidateRoster)
    if not obj.roster or #obj.roster == 0 then return nil end

    -- When dedupe_images is enabled, the active roster may be a subset of the
    -- raw feed because duplicate downloaded files were removed. For an unchanged
    -- raw feed, re-use the active roster so duplicates are not downloaded again
    -- during every refresh.
    if not obj.dedupe_images and #obj.roster ~= #candidateRoster then return nil end

    local candidateKeys = {}
    for _, item in ipairs(candidateRoster) do
        candidateKeys[table.concat({item.source or "", item.locale or "", item.url or ""}, "|")] = true
    end

    for _, item in ipairs(obj.roster) do
        local key = table.concat({item.source or "", item.locale or "", item.url or ""}, "|")
        if not candidateKeys[key] then return nil end
    end

    return obj.roster
end

local function allRosterFilesExist(roster)
    if not roster or #roster == 0 then return false end
    for _, item in ipairs(roster) do
        if not item.path or not hs.fs.attributes(item.path, "mode") then
            return false
        end
    end
    return true
end

local function commandFirstLine(command)
    local output = hs.execute(command)
    if type(output) ~= "string" then return nil end
    return output:match("([^\r\n]+)")
end

local function fileFingerprint(path)
    if not path or not hs.fs.attributes(path, "mode") then return nil end

    local size = tostring(hs.fs.attributes(path, "size") or "?")

    -- /usr/bin/shasum is present on stock macOS. Use exact file checksums so
    -- we only remove byte-for-byte duplicates, not merely similar pictures.
    local line = commandFirstLine("/usr/bin/shasum -a 256 " .. shellQuote(path) .. " 2>/dev/null")
    local digest = type(line) == "string" and line:match("^(%x+)") or nil

    if not digest then
        line = commandFirstLine("/sbin/md5 -q " .. shellQuote(path) .. " 2>/dev/null")
        digest = type(line) == "string" and line:match("^(%x+)") or nil
    end

    if not digest then return nil end
    return size .. ":" .. digest
end

local function dedupeDownloadedRoster(roster)
    if not obj.dedupe_images then return roster end
    if not roster or #roster <= 1 then return roster end

    local unique = {}
    local seen = {}
    local duplicates = 0

    for _, item in ipairs(roster) do
        local fingerprint = fileFingerprint(item.path)

        -- If hashing fails, keep the item. It is safer to rotate an extra image
        -- than to delete something we could not verify as a duplicate.
        if not fingerprint or not seen[fingerprint] then
            if fingerprint then seen[fingerprint] = item end
            table.insert(unique, item)
        else
            duplicates = duplicates + 1
            if obj.cleanup_old_images and item.path and item.path ~= seen[fingerprint].path then
                os.remove(item.path)
            end
        end
    end

    if duplicates > 0 then
        log("removed " .. tostring(duplicates) .. " exact duplicate wallpaper file(s); " .. tostring(#unique) .. " unique image(s) remain")
    end

    return unique
end

local function completeRosterUpdate(roster, hash, sameFeed)
    roster = dedupeDownloadedRoster(roster)

    if not roster or #roster == 0 then
        log("no wallpapers were downloaded successfully")
        return
    end

    obj.roster = roster
    obj.retrieved_count = #roster
    obj.roster_hash = hash
    hs.settings.set(settingsKey("roster_hash"), obj.roster_hash)

    if not sameFeed or not obj.cycle_start then
        obj.cycle_start = os.time()
        hs.settings.set(settingsKey("cycle_start"), obj.cycle_start)
    end

    cleanupOldFiles(roster)

    local secondsPerImage = rotationSeconds(#roster)
    if secondsPerImage then
        if tonumber(obj.rotate_every_minutes) and tonumber(obj.rotate_every_minutes) > 0 then
            log("retrieved " .. tostring(#roster) .. " wallpaper(s); rotating every " .. formatDuration(secondsPerImage))
        else
            log("retrieved " .. tostring(#roster) .. " wallpaper(s); rotating every " .. formatDuration(secondsPerImage) .. " across a " .. formatDuration(secondsPerImage * #roster) .. " cycle")
        end
    else
        log("retrieved " .. tostring(#roster) .. " wallpaper(s); using one image until the feed changes")
    end

    applyCurrentSlot()
end

local function curlRosterCallback(exitCode, stdOut, stdErr)
    local pending = obj.pending
    obj.task = nil
    obj.pending = nil

    if not pending then return end

    local available = {}
    for _, item in ipairs(pending.roster or {}) do
        if item.path and hs.fs.attributes(item.path, "mode") then
            table.insert(available, item)
        end
    end

    if #available > 0 then
        if exitCode ~= 0 then
            log("curl exited with " .. tostring(exitCode) .. "; using " .. tostring(#available) .. "/" .. tostring(#pending.roster) .. " downloaded wallpaper(s): " .. tostring(stdErr or stdOut or ""))
        end
        completeRosterUpdate(available, pending.hash, pending.sameFeed)
    else
        log("curl failed; no wallpapers were downloaded: " .. tostring(stdErr or stdOut or exitCode))
    end
end

local function downloadMissingImages(roster, hash, sameFeed)
    local toDownload = {}
    for _, item in ipairs(roster or {}) do
        if not item.path or not hs.fs.attributes(item.path, "mode") then
            table.insert(toDownload, item)
        end
    end

    if #toDownload == 0 then
        completeRosterUpdate(roster, hash, sameFeed)
        return
    end

    if obj.task then
        obj.task:terminate()
        obj.task = nil
    end

    obj.pending = {
        roster = roster,
        hash = hash,
        sameFeed = sameFeed,
    }

    local args = {
        "--fail",
        "--location",
        "--silent",
        "--show-error",
        "-A", obj.user_agent,
    }

    for _, item in ipairs(toDownload) do
        table.insert(args, item.url)
        table.insert(args, "-o")
        table.insert(args, item.path)
    end

    log("downloading " .. tostring(#toDownload) .. "/" .. tostring(#roster) .. " wallpaper(s) to " .. saveDir())

    obj.task = hs.task.new("/usr/bin/curl", curlRosterCallback, args)
    obj.task:start()
end

local function activateImages(images)
    local hash = feedHash(images)
    local sameFeed = hash == obj.roster_hash
    local roster = buildRoster(images)

    if sameFeed then
        local existing = existingRosterForSameFeed(roster)
        if existing then roster = existing end
    elseif obj.randomize then
        shuffle(roster)
    end

    if sameFeed and allRosterFilesExist(roster) then
        log("feed unchanged; " .. tostring(#roster) .. " wallpaper(s) still active")
        completeRosterUpdate(roster, hash, true)
        return
    end

    if sameFeed then
        log("feed unchanged, but one or more cached files are missing; re-downloading")
    else
        log("feed changed; starting a new rotation cycle")
    end

    downloadMissingImages(roster, hash, sameFeed)
end

local function spotlightApiErrorMessage(root)
    local batchrsp = type(root) == "table" and root.batchrsp or nil
    local errors = type(batchrsp) == "table" and batchrsp.errors or nil
    local first = type(errors) == "table" and errors[1] or nil
    if type(first) == "table" then
        return tostring(first.msg or first.code or "unknown API error")
    end
    return "Spotlight API returned no images"
end

local function parseSpotlightV4Images(body, locale)
    local root, err = decodeJson(body)
    if not root then return {}, "Invalid JSON: " .. tostring(err) end

    local items = root.batchrsp and root.batchrsp.items
    if type(items) ~= "table" then
        return {}, spotlightApiErrorMessage(root)
    end

    local images, seen = {}, {}
    local imageField = wantsSpotlightPortrait() and "portraitImage" or "landscapeImage"

    for _, wrapper in ipairs(items) do
        local item = wrapper.item
        if type(item) == "string" then
            item = decodeJson(item)
        end

        local ad = type(item) == "table" and item.ad or nil
        if type(ad) == "table" then
            local imageObj = ad[imageField] or ad.landscapeImage or ad.portraitImage
            local url = type(imageObj) == "table" and normalizeUrl(imageObj.asset) or nil
            if url then
                addUnique(images, seen, {
                    source = "spotlight",
                    locale = locale,
                    url = url,
                    title = cleanOneLine(ad.iconHoverText) or cleanOneLine(ad.title),
                    copyright = cleanOneLine(ad.copyright),
                    api = "spotlight-v4",
                })
            end
        end
    end

    if #images == 0 then
        return images, spotlightApiErrorMessage(root)
    end
    return images, nil
end

local function parseSpotlightV3Images(body, locale)
    local root, err = decodeJson(body)
    if not root then return {}, "Invalid JSON: " .. tostring(err) end

    local items = root.batchrsp and root.batchrsp.items
    if type(items) ~= "table" then
        return {}, spotlightApiErrorMessage(root)
    end

    local images, seen = {}, {}
    local imageField = wantsSpotlightPortrait() and "image_fullscreen_001_portrait" or "image_fullscreen_001_landscape"

    for _, wrapper in ipairs(items) do
        local item = wrapper.item
        if type(item) == "string" then
            item = decodeJson(item)
        end

        local ad = type(item) == "table" and item.ad or nil
        if type(ad) == "table" then
            local imageObj = ad[imageField]
            local url = type(imageObj) == "table" and normalizeUrl(imageObj.u) or nil
            if url then
                addUnique(images, seen, {
                    source = "spotlight",
                    locale = locale,
                    url = url,
                    title = cleanOneLine(ad.title_text and ad.title_text.tx),
                    copyright = cleanOneLine(ad.copyright_text and ad.copyright_text.tx),
                    api = "spotlight-v3",
                })
            end
        end
    end

    if #images == 0 then
        return images, spotlightApiErrorMessage(root)
    end
    return images, nil
end

local function spotlightV4Url(locale)
    return string.format(
        "https://fd.api.iris.microsoft.com/v4/api/selection?placement=88000820&bcnt=%d&country=%s&locale=%s&fmt=json",
        boundedSpotlightImageCount(),
        urlencode(countryFromLocale(locale)),
        urlencode(locale or "en-US")
    )
end

local function spotlightV3Url(locale)
    locale = locale or "en-US"
    return string.format(
        "https://arc.msn.com/v3/Delivery/Placement?pid=209567&fmt=json&ua=WindowsShellClient%%2F0&cdm=1&disphorzres=9999&dispvertres=9999&pl=%s&lc=%s&ctry=%s&time=%s",
        urlencode(locale),
        urlencode(locale),
        urlencode(countryFromLocale(locale)),
        urlencode(os.date("!%Y-%m-%dT%H:%M:%SZ"))
    )
end

local function parseBingImages(body, locale)
    local root, err = decodeJson(body)
    if not root then return {}, "Invalid JSON: " .. tostring(err) end
    if type(root.images) ~= "table" then return {}, "Bing response contained no images" end

    local images, seen = {}, {}
    for _, entry in ipairs(root.images) do
        local picUrl = entry.url
        if type(picUrl) == "string" and picUrl ~= "" then
            if obj.uhd_resolution then
                picUrl = picUrl:gsub("1920x1080", "UHD")
            end
            if picUrl:sub(1, 1) == "/" then
                picUrl = "https://www.bing.com" .. picUrl
            end

            addUnique(images, seen, {
                source = "bing",
                locale = locale,
                url = picUrl,
                title = cleanOneLine(entry.title),
                copyright = cleanOneLine(entry.copyright),
                api = "bing",
            })
        end
    end

    if #images == 0 then
        return images, "Bing response contained no usable image URLs"
    end
    return images, nil
end

local function bingUrl(locale)
    locale = locale or "en-US"
    return string.format(
        "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=%s",
        urlencode(locale)
    )
end

local function finalizeCollectedImages(token)
    if token ~= obj.update_token then return end
    local job = obj.collectJob
    if not job then return end
    obj.collectJob = nil

    if #job.images == 0 then
        log("no wallpapers retrieved from any enabled source")
        if #job.errors > 0 then
            log("errors: " .. table.concat(job.errors, " | "))
        end
        return
    end

    log("retrieved " .. tostring(#job.images) .. " candidate wallpaper(s) from " .. tostring(job.completed_requests) .. " request(s)")
    activateImages(job.images)
end

local function requestFinished(token)
    if token ~= obj.update_token then return end
    local job = obj.collectJob
    if not job then return end
    job.pending = job.pending - 1
    if job.pending <= 0 then
        finalizeCollectedImages(token)
    end
end

local function collectError(token, source, locale, message)
    if token ~= obj.update_token then return end
    local job = obj.collectJob
    if not job then return end
    table.insert(job.errors, string.format("%s %s: %s", tostring(source), tostring(locale), tostring(message)))
end

local function collectImages(token, items)
    if token ~= obj.update_token then return end
    local job = obj.collectJob
    if not job then return end
    for _, item in ipairs(items or {}) do
        addUnique(job.images, job.seen, item)
    end
end

local function requestBingLocale(locale, token)
    hs.http.asyncGet(bingUrl(locale), { ["User-Agent"] = obj.user_agent }, function(status, body, headers)
        local job = obj.collectJob
        if token == obj.update_token and job then
            job.completed_requests = job.completed_requests + 1
        end

        if status ~= 200 or type(body) ~= "string" then
            collectError(token, "bing", locale, "HTTP " .. tostring(status))
            requestFinished(token)
            return
        end

        local images, err = parseBingImages(body, locale)
        if #images > 0 then
            collectImages(token, images)
        else
            collectError(token, "bing", locale, err)
        end
        requestFinished(token)
    end)
end

local function requestSpotlightLocale(locale, token, apiVersion)
    local url = apiVersion == "v3" and spotlightV3Url(locale) or spotlightV4Url(locale)
    local headers = {
        ["User-Agent"] = obj.user_agent,
        ["Accept"] = "application/json",
    }

    hs.http.asyncGet(url, headers, function(status, body, responseHeaders)
        if status ~= 200 or type(body) ~= "string" then
            if apiVersion ~= "v3" and obj.spotlight_v3_fallback then
                requestSpotlightLocale(locale, token, "v3")
                return
            end
            local job = obj.collectJob
            if token == obj.update_token and job then
                job.completed_requests = job.completed_requests + 1
            end
            collectError(token, "spotlight", locale, "HTTP " .. tostring(status))
            requestFinished(token)
            return
        end

        local images, err
        if apiVersion == "v3" then
            images, err = parseSpotlightV3Images(body, locale)
        else
            images, err = parseSpotlightV4Images(body, locale)
        end

        if #images > 0 then
            local job = obj.collectJob
            if token == obj.update_token and job then
                job.completed_requests = job.completed_requests + 1
            end
            collectImages(token, images)
            requestFinished(token)
        elseif apiVersion ~= "v3" and obj.spotlight_v3_fallback then
            requestSpotlightLocale(locale, token, "v3")
        else
            local job = obj.collectJob
            if token == obj.update_token and job then
                job.completed_requests = job.completed_requests + 1
            end
            collectError(token, "spotlight", locale, err)
            requestFinished(token)
        end
    end)
end

--- BingSpotlightDaily:update()
--- Method
--- Immediately refresh all enabled sources/locales. Aggregates Bing and/or Spotlight images into one roster, downloads any new files, and restarts rotation when the feed changes.
function obj:update()
    local sources = normalizeSources(obj.sources)
    local bingLocales = normalizeLocales(obj.bing_locales)
    local spotlightLocales = normalizeLocales(obj.spotlight_locales)

    local requests = {}
    for _, source in ipairs(sources) do
        if source == "bing" then
            for _, locale in ipairs(bingLocales) do
                table.insert(requests, {source = source, locale = locale})
            end
        elseif source == "spotlight" then
            for _, locale in ipairs(spotlightLocales) do
                table.insert(requests, {source = source, locale = locale})
            end
        end
    end

    if #requests == 0 then
        log("no sources/locales enabled; nothing to update")
        return self
    end

    obj.update_token = (tonumber(obj.update_token) or 0) + 1
    local token = obj.update_token
    obj.collectJob = {
        pending = #requests,
        completed_requests = 0,
        images = {},
        seen = {},
        errors = {},
    }

    log("refreshing " .. tostring(#requests) .. " source/locale request(s)")

    for _, req in ipairs(requests) do
        if req.source == "bing" then
            requestBingLocale(req.locale, token)
        else
            requestSpotlightLocale(req.locale, token, "v4")
        end
    end

    return self
end

--- BingSpotlightDaily:rotateNow([index])
--- Method
--- Immediately rotate the wallpaper. If index is supplied, switch to that 1-based item in the current roster; otherwise switch to the next item.
function obj:rotateNow(index)
    local roster = obj.roster or {}
    if #roster == 0 then
        log("no wallpaper roster is available yet; run BingSpotlightDaily:update() first")
        return self
    end

    local secondsPerImage = rotationSeconds(#roster) or (tonumber(obj.rotate_every_minutes) and tonumber(obj.rotate_every_minutes) * 60) or (tonumber(obj.cycle_seconds) or 24 * 60 * 60)
    local target = tonumber(index)
    if target then
        target = math.floor(target)
        if target < 1 then target = 1 end
        if target > #roster then target = #roster end
    else
        target = ((tonumber(obj.rotation_index) or 0) % #roster) + 1
    end

    obj.cycle_start = os.time() - ((target - 1) * secondsPerImage)
    hs.settings.set(settingsKey("cycle_start"), obj.cycle_start)
    applyCurrentSlot()
    return self
end

--- BingSpotlightDaily:status()
--- Method
--- Print and return current source, locale, file, and rotation status for debugging.
function obj:status()
    local roster = obj.roster or {}
    local index, nextIn, secondsPerImage = currentRotationSlot()
    local status = {
        sources = normalizeSources(obj.sources),
        bing_locales = normalizeLocales(obj.bing_locales),
        spotlight_locales = normalizeLocales(obj.spotlight_locales),
        image_count = #roster,
        current_index = index,
        retrieved_count = obj.retrieved_count,
        roster_hash = obj.roster_hash,
        cycle_start = obj.cycle_start,
        save_dir = saveDir(),
        last_file = obj.last_file,
        last_url = obj.last_url,
        seconds_per_image = secondsPerImage,
        next_rotation_in = nextIn,
        rotate_every_minutes = obj.rotate_every_minutes,
    }

    log(string.format(
        "status: %d image(s), current=%s, seconds_per_image=%s, next_rotation_in=%s, save_dir=%s",
        #roster,
        tostring(index),
        secondsPerImage and formatDuration(secondsPerImage) or "n/a",
        nextIn and formatDuration(nextIn) or "n/a",
        status.save_dir
    ))

    return status
end

--- BingSpotlightDaily:downloadedCount()
--- Method
--- Return the number of downloaded wallpapers in the current active roster.
function obj:downloadedCount()
    return #(obj.roster or {})
end

--- BingSpotlightDaily:start()
--- Method
--- Start periodic feed refreshes and wallpaper rotation.
function obj:start()
    math.randomseed(os.time())

    if obj.timer then
        obj.timer:stop()
        obj.timer = nil
    end

    if obj.rotationTimer then
        obj.rotationTimer:stop()
        obj.rotationTimer = nil
    end

    obj.timer = hs.timer.doEvery(obj.interval, function()
        obj:update()
    end)
    obj.timer:setNextTrigger(5)

    return self
end

--- BingSpotlightDaily:stop()
--- Method
--- Stop periodic refreshes, stop wallpaper rotation, and cancel any active download.
function obj:stop()
    if obj.timer then
        obj.timer:stop()
        obj.timer = nil
    end

    if obj.rotationTimer then
        obj.rotationTimer:stop()
        obj.rotationTimer = nil
    end

    if obj.task then
        obj.task:terminate()
        obj.task = nil
    end

    obj.pending = nil
    obj.collectJob = nil
    return self
end

function obj:init()
    obj.last_url = hs.settings.get(settingsKey("last_url"))
    obj.last_file = hs.settings.get(settingsKey("last_file"))
    obj.roster_hash = hs.settings.get(settingsKey("roster_hash"))
    obj.cycle_start = hs.settings.get(settingsKey("cycle_start"))
    return self
end

return obj
