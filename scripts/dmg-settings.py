# Finder layout for build/Closetalk.dmg, read by dmgbuild (see scripts/package.sh, which passes
# app, background and icon with -D). Icon spots match the arrow in assets/src/dmg-background.html.
import os.path

app = defines["app"]  # noqa: F821, dmgbuild provides defines
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]  # noqa: F821
background = defines["background"]  # noqa: F821
format = "UDZO"

# 452 = the 420pt background plus the title bar. A path bar, if someone has it on, covers the bottom 28pt.
window_rect = ((200, 160), (660, 452))
default_view = "icon-view"
show_toolbar = False
show_status_bar = False
show_pathbar = False
show_sidebar = False
show_tab_view = False
icon_size = 128
text_size = 13
icon_locations = {os.path.basename(app): (170, 210), "Applications": (490, 210)}
hide_extensions = [os.path.basename(app)]
