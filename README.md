# Linux Loader for PS5

A homescreen app for exploited PS5 consoles that runs the WebKit exploit and then
loads a Linux loader payload, with one tap and no PC or internet needed after install.

This is a fork of [itsPLK/ps5-webkit-autoloader](https://github.com/itsPLK/ps5-webkit-autoloader)
by PLK. All of the exploit chain, the on-console web server and the installer come from
that project. This fork changes the look, the app identity and (optionally) bakes your own
payload into the page.

## Supported firmware

**13.00, 13.20 and 13.60, with M.2 support.**

## The Linux loader payload

This repository does not contain the Linux loader ELF itself. The payload comes from
[Ouroboroshen/ps5-linux-loader](https://github.com/Ouroboroshen/ps5-linux-loader), a fork of
[ps5-linux/ps5-linux-loader](https://github.com/ps5-linux/ps5-linux-loader). Get
`ps5-linux-loader.elf` from that project (its README points to the releases page, or you can
build it yourself with `make`) and place it in the `custom` folder of this repository as
`custom/Linuxloader.elf`. The build then embeds it. See the loader's own README for its
features and the full list of firmware versions it covers.

## What is different from upstream

| | Upstream | This fork |
|---|---|---|
| Homescreen name | WebKit Autoloader vX.Y.Z | **Linux Loader** |
| Theme | blue | dark terminal look with a penguin header and orange accents |
| Homescreen icon | sphere | penguin on a dark disc |
| Payload that is loaded | unified autoloader (Payload Manager or `autoload.txt`) | **your ELF, baked into the page** (if `custom/Linuxloader.elf` exists) |
| Title ID | `WKAL00001` | `LNXL00001` |
| Local port | `18181` | `18182` |
| Installer process name | `wkali.elf` | `lnxli.elf` |

Because the title ID, port and process name differ, **this app installs next to the original
WebKit Autoloader** without replacing it.

If you build without a custom ELF, the page falls back to upstream behaviour (unified
autoloader, Payload Manager, `autoload.txt`), only with the new look and identity.

## Build

Requirements: Linux with `git`, `docker` (with `docker-buildx`), `make`, `python3` and
`rsvg-convert` (package `librsvg2-bin` on Debian/Ubuntu, `librsvg` on Arch).

```bash
git clone --recursive https://github.com/Wawapun/ps5-linux-autoloader
cd ps5-linux-autoloader

# put the loader payload here (this folder is git-ignored)
# the file must be named Linuxloader.elf inside custom/
mkdir -p custom
cp /path/to/ps5-linux-loader.elf custom/Linuxloader.elf

make icons
./build_release.sh
```

Use `--recursive`: a plain ZIP download or a clone without submodules fails during the build.

Watch the build output for this line to confirm your payload is used:

```
autoload payload: custom/Linuxloader.elf
```

If it says `build/deps/autoload.elf` instead, the file was not found or is named differently.

The result is `webkit-autoloader-installer_v<version>.elf` in the repository root.
You can rename it, the name does not matter.

## Install

1. Jailbreak your console as usual, with `elfldr` listening on port 9021.
2. Send the installer ELF to the console, for example:
   ```bash
   nc -w 1 <PS5-IP> 9021 < webkit-autoloader-installer_v<version>.elf
   ```
   or launch it from Payload Manager.
3. The installer opens the browser once to cache the page and creates the **Linux Loader**
   app on the homescreen. Do not close the browser while it runs.
4. Reboot the console once, then start **Linux Loader**.

## Check that it worked

- The browser title bar shows only "Linux Loader".
- The log contains `Autoload: sent <n> bytes`, where `<n>` is the size of your ELF.
- The progress bar ends on "Autoload finished. Linux Loader should start now."

## Updating

Build again and send the new installer ELF. It re-creates the homescreen app and refreshes
the cached page.

## Troubleshooting

| Problem | Cause / fix |
|---|---|
| `docker: command not found` | Install Docker and add your user to the `docker` group, then log in again. |
| `Dockerfile.sdk: no such file or directory` | Submodules are missing. Clone again with `--recursive`. |
| `no SVG renderer found` | Install `rsvg-convert` (see requirements). |
| Build says `build/deps/autoload.elf` | `custom/Linuxloader.elf` is missing or misnamed. |
| `dubious ownership` from git inside the container | Pass `-e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*'` to `docker run` in `build_release.sh`. |
| `ELF loader already accepting connections` | A previous session left `elfldr` running. Reboot fully and start the app again. |

## Notes on sharing builds

The installer you build contains your payload. Do not publish the installer ELF or put it
in a release unless you are allowed to redistribute that payload.

## Credits

This project is only a thin layer on top of other people's work.

- [**itsPLK**](https://github.com/itsPLK): [ps5-webkit-autoloader](https://github.com/itsPLK/ps5-webkit-autoloader), the project this is forked from
- [**jordyidk**](https://github.com/jordyidk) and contributors: [slopkit (Poops)](https://github.com/jordyidk/slopkit)
- [**soniciso1**](https://github.com/soniciso1), [**ntfargo**](https://github.com/ntfargo) and contributors: [Relapse](https://github.com/soniciso1/relapse)
- [**john-tornblom**](https://github.com/john-tornblom): [ps5-payload-sdk](https://github.com/ps5-payload-dev/sdk/) and [elfldr](https://github.com/ps5-payload-dev/elfldr)
- See [ps5-webkit-remote-loader](https://github.com/itsPLK/ps5-webkit-remote-loader) for runtime and toolchain credits
- Everyone else contributing to the PS5 homebrew scene

## Disclaimer

This tool is provided as-is for research and development purposes only. Use at your own
risk. The developers are not responsible for any damage, data loss, or consequences
resulting from the use of this software.

## License

GPL-3.0, the same as upstream. See `LICENSE`.
