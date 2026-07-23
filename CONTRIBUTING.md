# Contributing Guidelines

## Module Organization

Each Nix module should be **self-contained** and **concern-oriented**. Configuration for a specific application or feature belongs in its own module file.

### Rule: One Concern Per File

- `quickshell.nix` contains all quickshell-related configuration
- `hyprland.nix` contains all hyprland-related configuration
- `discord.nix` contains all discord-related configuration

### Example: Wrong vs Right

**Wrong:** Adding Hyprland layer rules for quickshell to a shared rules file in the hyprland module:

```lua
-- home/modules/hyprland/rules.lua
hl.layer_rule({ match = { namespace = "quickshell" }, blur = true })
```

**Right:** Keeping them in a Lua file next to `quickshell.nix`, wired from that module:

```nix
# quickshell.nix
wayland.windowManager.hyprland.extraLuaFiles."quickshell-layerrules".content = ./layerrules.lua;
```

```lua
-- layerrules.lua
hl.layer_rule({ match = { namespace = "quickshell" }, blur = true })
```

### When Multiple Files Are Needed

Sometimes a concern requires both Home Manager and system-level configuration. In this case:

1. Create the primary module in the appropriate location
2. Add a comment explaining the split

```nix
# Note: System-level configuration for this feature is in modules/example.nix
```

## Structure

```
home/modules/     # Home Manager modules (user-level config)
modules/          # NixOS system modules (system-level config)
hosts/            # Host-specific configuration
```
