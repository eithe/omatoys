# Omatoys

Omatoys is a shareable collection of small productivity tools for Omarchy.
The first tool is **Cleaning Mode**, available from an Omatoys icon in the
Omarchy top bar.

## Installation

Clone the project and run the installer:

```bash
git clone <repository-url> omatoys
cd omatoys
./install.sh
```

The installer:

- Installs the Omatoys shell plugin as a symlink under
  `~/.config/omarchy/plugins/local.omatoys/`.
- Installs `python-evdev` with the Arch package manager.
- Installs the privileged Key Filter and Click Filter systemd services.
- Reloads the Omarchy shell.

The installer may show a graphical authentication prompt through `pkexec`
when installing the privileged input helpers. The helpers are disabled by
default. Enable a filter from the Omatoys menu to start it immediately and
persist it across reboots; disabling it stops the service and removes its
boot-time enablement.

To remove the project-managed installation, disable the services and remove
the plugin symlink:

```bash
pkexec systemctl disable --now omatoys-key-filter.service
pkexec systemctl disable --now omatoys-click-filter.service
rm ~/.config/omarchy/plugins/local.omatoys
```

## Development

The plugin source lives in `plugin/local.omatoys/`. Install it into the
current user's Omarchy configuration with:

```bash
./install.sh
```

The installer creates a symlink, so edits in this project are picked up by
the running Omarchy shell after a plugin rescan or shell restart.

The installer also installs the optional privileged Key Filter service. It
uses `python-evdev` and `/dev/uinput` to re-emit keyboard events while
suppressing accidental same-key presses within 100 ms. The Omatoys menu
switch starts and stops the service through the system authentication dialog.

The installer also installs Click Filter, which independently filters rapid
left, right, and middle mouse clicks.

## Cleaning Mode

Click the Omatoys bar icon, choose **Cleaning Mode**, and press Escape five
times to exit. While active, keyboard and pointer input are captured and a
theme-aware dialog explains how to unlock it.
