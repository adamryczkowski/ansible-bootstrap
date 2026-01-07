# Slack Compatibility Issue Report: Sway Window Manager

**Date:** January 7, 2026  
**Reporter:** System Administrator  
**Severity:** High - Application Unusable  
**Status:** Resolved

---

## Executive Summary

Slack Desktop application fails to display its window when running on Sway (Wayland compositor), preventing users from accessing the application. This issue occurs specifically after migrating from i3wm (X11) to Sway (Wayland). A workaround has been implemented and tested successfully.

---

## Problem Description

### Symptoms

- Slack launches but no window appears on screen
- Application process runs in background but is not visible
- No error dialogs or user-facing error messages

### Technical Details

When launching Slack on Sway, the application fails during GPU/graphics initialization with the following errors:

```text
[ERROR:ui/gl/angle_platform_impl.cc:42] Display.cpp:1093 (initialize):
  ANGLE Display::initialize error 12289: Failed to get system egl display
[ERROR:ui/gl/gl_display.cc:674] Initialization of all EGL display types failed.
[ERROR:ui/ozone/common/gl_ozone_egl.cc:26] GLDisplayEGL::Initialize failed.
[ERROR:components/viz/service/main/viz_main_impl.cc:189]
  Exiting GPU process due to errors during initialization
```

### Root Cause

1. **Electron/Wayland Incompatibility**: Slack uses a bundled Electron framework that has issues with EGL (OpenGL ES) initialization on Wayland
2. **GPU Acceleration Conflict**: The default GPU acceleration settings are incompatible with the Sway/Wayland graphics stack
3. **Missing Wayland Flags**: Slack doesn't automatically detect and configure itself for Wayland environments

---

## Environment Details

- **OS:** Ubuntu 24.04 LTS
- **Kernel:** Linux 6.14.0-37-generic
- **Window Manager:** Sway (Wayland compositor)
- **Previous WM:** i3wm (X11)
- **Slack Version:** 4.47.69
- **Display Server:** Wayland (WAYLAND_DISPLAY: wayland-1)

---

## Solution

### Implementation

The fix requires launching Slack with specific command-line flags that disable GPU acceleration and enable proper Wayland support. Since Slack bundles its own Electron build and doesn't read standard configuration files, a desktop entry override is required.

### Required Flags

```bash
--disable-gpu
--enable-features=UseOzonePlatform,WaylandWindowDecorations
--ozone-platform=wayland
```

### Files to Deploy

#### 1. Desktop Entry Override

**Location:** `~/.local/share/applications/slack.desktop`

```desktop
[Desktop Entry]
Name=Slack
StartupWMClass=Slack
Comment=Slack Desktop
GenericName=Slack Client for Linux
Exec=/usr/lib/slack/slack --disable-gpu --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland %U
Icon=/usr/share/pixmaps/slack.png
Type=Application
StartupNotify=true
Categories=GNOME;GTK;Network;InstantMessaging;
MimeType=x-scheme-handler/slack;
```

**Purpose:** This overrides the system desktop file and is used by application launchers (dmenu, rofi, application menus).

#### 2. Wrapper Script (Optional)

**Location:** `~/.local/bin/slack`

```bash
#!/bin/bash
# Slack wrapper script to enable Wayland support and fix GPU issues
# This wrapper ensures Slack works on both Sway (Wayland) and i3wm (X11)

exec /usr/lib/slack/slack \
    --disable-gpu \
    --enable-features=UseOzonePlatform,WaylandWindowDecorations \
    --ozone-platform=wayland \
    "$@"
```

**Permissions:** Must be executable (`chmod +x ~/.local/bin/slack`)

**Purpose:** Provides command-line compatibility, though PATH ordering may prevent automatic override.

#### 3. Configuration File (Reference Only)

**Location:** `~/.config/slack-flags.conf`

```text
--disable-gpu
--enable-features=UseOzonePlatform,WaylandWindowDecorations
--ozone-platform=wayland
```

**Note:** This file is NOT read by Slack (bundled Electron limitation) but serves as documentation.

---

## Deployment Instructions

### For Laptop Provisioning Team

1. **Create the desktop entry override:**

    ```bash
    mkdir -p ~/.local/share/applications
    cat > ~/.local/share/applications/slack.desktop << 'EOF'
    [Desktop Entry]
    Name=Slack
    StartupWMClass=Slack
    Comment=Slack Desktop
    GenericName=Slack Client for Linux
    Exec=/usr/lib/slack/slack --disable-gpu --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland %U
    Icon=/usr/share/pixmaps/slack.png
    Type=Application
    StartupNotify=true
    Categories=GNOME;GTK;Network;InstantMessaging;
    MimeType=x-scheme-handler/slack;
    EOF
    ```

2. **Update desktop database:**

    ```bash
    update-desktop-database ~/.local/share/applications
    ```

3. **Verification:**

    ```bash
    # Test launch from command line
    /usr/lib/slack/slack --disable-gpu --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland
    ```

### Automation Recommendation

For automated provisioning, consider:

- Adding the desktop file to your dotfiles repository
- Including it in user profile setup scripts
- Creating an Ansible/Chef/Puppet task for Sway users

---

## Compatibility Matrix

| Environment | Status | Notes |
|-------------|--------|-------|
| Sway (Wayland) | ✅ Working | Primary use case, fully tested |
| i3wm (X11) | ✅ Working | Flags are compatible with X11 |
| GNOME (Wayland) | ✅ Expected to work | Same Wayland stack |
| KDE Plasma (Wayland) | ✅ Expected to work | Same Wayland stack |
| Other X11 WMs | ✅ Expected to work | Flags don't interfere with X11 |

---

## Known Limitations

1. **GPU Acceleration Disabled**: The `--disable-gpu` flag disables hardware acceleration, which may result in:
    - Slightly higher CPU usage
    - Reduced performance for video calls or screen sharing
    - Acceptable trade-off for basic functionality

2. **Bundled Electron**: Slack bundles its own Electron version, so:
    - Standard Electron configuration files are ignored
    - Updates to system Electron don't affect Slack
    - Each Electron app may require similar workarounds

3. **Command-line Override**: The wrapper script in `~/.local/bin/` may not override `/usr/bin/slack` due to PATH ordering

---

## Alternative Solutions Considered

1. **System-wide wrapper**: Modifying `/usr/bin/slack` - Rejected (package manager would overwrite)
2. **Environment variables**: Setting `ELECTRON_OZONE_PLATFORM_HINT` - Insufficient, doesn't address GPU issues
3. **Flatpak/Snap version**: Alternative packaging - Not tested, may have different issues

---

## Technical References

- [Arch Wiki: Electron Configuration](https://wiki.archlinux.org/title/Electron) - Confirms bundled Electron apps don't read flags files
- [Stack Overflow: Electron Apps on Wayland](https://stackoverflow.com/questions/63187542/how-to-run-electron-apps-like-slack-etc-for-wayland) - Wayland flag documentation
- [Arch Forums: Sway EGL Issues](https://bbs.archlinux.org/viewtopic.php?id=282803) - Similar EGL initialization problems

---

## Recommendations for Provisioning Team

### Immediate Actions

1. ✅ Deploy the desktop file override to all Sway users
2. ✅ Add to standard laptop provisioning scripts
3. ✅ Document in internal wiki/knowledge base

### Long-term Considerations

1. **Monitor Slack Updates**: Future versions may fix Wayland support natively
2. **Test Other Electron Apps**: VSCode, Discord, Teams may need similar fixes
3. **Consider Wayland-Native Alternatives**: Evaluate if available
4. **Upstream Bug Report**: Consider reporting to Slack if not already known

### User Communication

Inform users that:

- Slack will work but without GPU acceleration
- Performance impact is minimal for typical usage
- Video calls and screen sharing still function
- This is a known limitation of current Slack/Electron/Wayland integration

---

## Testing Checklist

- [x] Slack launches and displays window
- [x] Can log in to workspace
- [x] Can send/receive messages
- [x] Notifications work
- [x] Compatible with i3wm (X11) fallback
- [x] Desktop launcher integration works
- [x] No regression on X11 systems

---

## Contact

For questions or issues with this workaround, contact the system administration team.

**Last Updated:** January 7, 2026
