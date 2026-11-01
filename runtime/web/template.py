# SCons profile for Kindly's browser-only interpreter. React owns the UI.
threads = False
dlink_enabled = False
lto = "full"
debug_symbols = False
opengl3 = False
vulkan = False
disable_3d = True
disable_advanced_gui = True
disable_physics_2d = True
disable_navigation_2d = True
disable_xr = True
modules_enabled_by_default = False
module_gdscript_enabled = True
module_text_server_fb_enabled = True
module_freetype_enabled = True
# JavaScriptBridge is required for communication with the React playground.
javascript_eval = True
