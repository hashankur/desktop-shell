# Desktop Shell

![screenshot](./assets/screen_1.png)
![screenshot](./assets/screen_2.png)

## Dependencies

```sh
# CLI for astal
ags

# Clipboard
wl-clipboard
cliphist
imagemagick

# OSD
brightnessctl

# Color generation (optional)
matugen
```

## Prerequisities

Install npm packages (use preferred package manager):

```sh
bun install
```

Generate types:

```sh
ags types
```

## Start Desktop Shell

```sh
ags run --gtk4
```

> [!NOTE]
> Contains code specific to niri (workspaces, window title)
>
> Experimental config for Tailwind CSS v4 in `tw4` branch
