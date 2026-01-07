# GTK Theme Switching for Sway

This document describes how automatic dark/light theme switching works for GTK applications (including PCManFM) in the Sway window manager environment.

## Overview

The Sway role configures GTK applications to follow the system theme via gsettings. This enables automatic theme switching at runtime using scripts, without requiring application restarts.

## How It Works

### Theme Control Hierarchy

GTK3 applications determine their theme from multiple sources, in order of precedence:

1. **gsettings (dconf)** - Highest priority when `xdg-desktop-portal-gtk` is running
2. **`~/.config/gtk-3.0/settings.ini`** - Fallback when gsettings is not available
3. **System defaults** - `/etc/gtk-3.0/settings.ini`

For Wayland sessions with Sway, gsettings takes precedence because `xdg-desktop-portal-gtk` is installed and running.

### Key Components

1. **xdg-desktop-portal-gtk** - GTK portal backend that enables gsettings to work on Wayland
2. **dconf/gsettings** - GNOME settings database that stores theme preferences
3. **Theme switching scripts** - Located in `~/.config/i3-config/sway/scripts/`

### gsettings Keys Used

| Key | Description |
|-----|-------------|
| `org.gnome.desktop.interface color-scheme` | Color scheme preference (`prefer-dark`, `prefer-light`, `default`) |
| `org.gnome.desktop.interface gtk-theme` | GTK theme name (e.g., `Adwaita`, `Adwaita-dark`) |
| `org.gnome.desktop.interface icon-theme` | Icon theme name |
| `org.gnome.desktop.interface cursor-theme` | Cursor theme name |
| `org.gnome.desktop.interface font-name` | Default font |

## Theme Switching Scripts

The i3-config repository contains scripts for switching themes at runtime:

### `~/.config/i3-config/sway/scripts/set-dark-mode`

Switches to dark theme:

- Sets `color-scheme` to `prefer-dark`
- Sets `gtk-theme` to `Adwaita-dark`
- Sends SIGUSR1 to foot terminals for dark theme

### `~/.config/i3-config/sway/scripts/set-light-mode`

Switches to light theme:

- Sets `color-scheme` to `prefer-light`
- Sets `gtk-theme` to `Adwaita`
- Sends SIGUSR2 to foot terminals for light theme

## Ansible Configuration

The Sway role configures GTK theme settings via the `gtk_theme.yml` task:

### Default Variables

```yaml
# Enable GTK theme configuration
sway_configure_gtk_theme: true

# Initial theme settings
sway_gtk_theme_name: "Adwaita"
sway_gtk_icon_theme_name: "Adwaita"
sway_gtk_cursor_theme_name: "Adwaita"
sway_gtk_font_name: "Sans 10"

# Color scheme preference
sway_gtk_color_scheme: "prefer-dark"
```

### What the Role Does

1. Creates `~/.config/gtk-3.0/settings.ini` **without hardcoding the theme name**
2. Configures initial theme via dconf/gsettings
3. Installs `xdg-desktop-portal-gtk` for gsettings support on Wayland
4. Installs `pcmanfm` as a lightweight file manager

## How settings.ini Works with Theme Switching

The `~/.config/gtk-3.0/settings.ini` file includes `gtk-theme-name` and `gtk-application-prefer-dark-theme` settings that are updated by the theme switching scripts. This dual approach ensures compatibility:

1. **gsettings is the primary mechanism** - takes precedence when `xdg-desktop-portal-gtk` is running
2. **settings.ini is the fallback** - for apps that don't read gsettings or when the portal is not available
3. **Scripts update both** - the `set-dark-mode` and `set-light-mode` scripts update gsettings AND use `sed` to update settings.ini

## Troubleshooting

### Theme not switching

**Step 1:** Verify `xdg-desktop-portal-gtk` is running:

```bash
systemctl --user status xdg-desktop-portal-gtk
```

**Step 2:** Check current gsettings values:

```bash
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface color-scheme
```

**Step 3:** Manually test theme switching:

```bash
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

### PCManFM not following theme

**Step 1:** Ensure PCManFM is using GTK3 (not GTK2):

```bash
ldd $(which pcmanfm) | grep gtk
```

**Step 2:** Restart PCManFM after changing the theme (some GTK3 apps may need a restart)

## References

- [ArchWiki: Dark mode switching](https://wiki.archlinux.org/title/Dark_mode_switching)
- [GTK3 Settings Documentation](https://docs.gtk.org/gtk3/class.Settings.html)
- [XDG Desktop Portal](https://flatpak.github.io/xdg-desktop-portal/)
