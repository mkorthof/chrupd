# Simple Chromium Updater (chrupd.cmd)

*_Self executable PowerShell script to auto update Chromium for Windows_*

---

**Latest version: 20210109 ([CHANGES.md](CHANGES.md))**

---

This script uses the feed from <https://chromium.woolyss.com> to download and install the latest Chromium version, if a newer version is available.

When you run the script it does the following:

- by default it'll get the "stable" 64-bit Installer by "Hibbiki"
- verifies SHA1/MD5 hash and runs installer

Options can be set in script or by using command line arguments.

Download and run `chrupd.cmd` or see below for details.

## Configuration

Make sure the combination of editor and channel is correct. You can also use `chrupd.cmd -list`. For more information about versions check [chromium.woolyss.com](https://chromium.woolyss.com/?cut=1&ago=1), it's [feed](https://chromium.woolyss.com/feed/windows-64-bit) and [chromium.org](https://www.chromium.org).

| Editor               | Channel         |
|:---------------------|:----------------|
| Marmaduke            | stable, dev     |
| Marmaduke-Ungoogled  | stable          |
| RobRich              | dev             |
| The Chromium Authors | dev             |
| ThumbApps            | dev             |
| **Hibbiki**          | **stable**, dev |

( _defaults in **bold**_  )

## Scheduled Task

Optionally you can add a Scheduled Task by using `chrupd.cmd -crTask`. A VBS wrapper will be written to **chrupd.vbs** which is used to hide it's window. Option `noVbs` disables the wrapper, this will however cause a flashing window when the task runs.

## Updating

The script auto updates (since v20210109). 

To manually update to a newer version just replace "chrupd.cmd". Copy "editor" and "channel" if set. If you have Scheduled Task setup you do not need to change the task.

## File Formats

For easy execution this PowerShell script is embedded in a Batch .CMD file, which can be renamed to .PS1.

See [docs/Formats.md](docs/Formats.md) for details  .

> *Note: this script has no connection to the preexisting [ChrUpdWin.cmd](https://gist.github.com/mikhaelkh/>12dec36d4a1c4136628b#file-chrupdwin-cmd) Batch file by [Michael Kharitonov](https://github.com/mikhaelkh)*

## Command Line Options

`chrupd.cmd -h`

```text

Simple Chromium Updater (chrupd.cmd)
------------------------------------

Uses RSS feed from "chromium.woolyss.com" to install latest Chromium version

USAGE: chrupd.cmd -[editor|arch|channel|force]
                  -[crTask|rmTask|shTask] or [-list]

         -editor  option must be set to one of:
                  <Official|Hibbiki|Marmaduke|Ungoogled|RobRich>
         -arch    option must be set to <64bit|32bit>
         -channel option must be set to <stable|dev>
         -force   always (re)install, even if latest ver is installed

         -list    show version, editors and rss feeds from woolyss.com

         -crTask  create a daily scheduled task
         -shTask  show scheduled task details

EXAMPLE: ".\chrupd.cmd -editor Marmaduke -arch 64bit -channel stable [-crTask]"

NOTES:   Options "editor" and "channel" need an argument (CasE Sensive)
         See ".\chrupd.cmd -advhelp" for 'advanced' options

```
