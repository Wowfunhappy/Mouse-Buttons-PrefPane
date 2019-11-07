#!/usr/bin/osascript

considering numeric strings
    if (path to frontmost application as text) contains "Finder.app" and system version of (system info) < "10.10" then
        tell application "System Events" to tell process "Finder" to click button 1 of group 1 of group 1 of toolbar 1 of front window
    end if
end considering
