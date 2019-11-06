#!/usr/bin/osascript

considering numeric strings
    if (path to frontmost application as text) contains "Finder.app" and system version of (system info) < "10.10" then
        tell application "System Events" to tell process "Finder" to click menu item "Forward" of menu "Go" of menu bar 1
    end if
end considering
