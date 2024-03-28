# Simple Chromium Updater (chrupd.cmd)

" _Self executable PowerShell script to auto update Chromium for Windows_ "

✅ Runs on all Windows versions

✅ One file download, no need to install and no other software required

✅ Needs little to no configuration, but (advanced) options are available

This script uses the RSS feed from <https://chromium.woolyss.com> or GitHub API to download and install the latest Chromium version, if a newer version is available.

Download and run `chrupd.cmd` or read below for more details.

When you run the script it does the following:

- by default it'll get the Chromium "stable" 64-bit Installer by "Hibbiki"
- verifies SHA1/MD5 file hash and runs installer
- chrupd auto updates itself

Options can be set in script or by using command line arguments.

---

**🗓 Latest version: 20240327 ([CHANGES.md](CHANGES.md))**

---

## ⚙ Chromium versions

| Source    | Name*                              | Channel         |
|:----------|:-----------------------------------|:----------------|
|||
| _[Woolyss](https://chromium.woolyss.com)_ |                                               |                 |
|           |  **[Hibbiki](https://github.com/Hibbiki)**                                    | **stable**, dev |
|           |  [Marmaduke](https://github.com/macchrome/winchrome/)                         | stable, dev     |
|           |  [Ungoogled-Marmaduke](https://github.com/macchrome/winchrome/)               | stable          |
|           |  [Ungoogled](https://github.com/portapps/)-Portable                           | stable          |
|           |  `Official` ([The Chromium Authors](https://www.chromium.org))                | dev             |
|||
|||
| _GitHub_  |                                                                                           |                 |
|           |  [justclueless](https://github.com/justclueless/chromium-win64)                           | dev             |
|           |  [Ungoogled-Eloston](https://github.com/ungoogled-software/ungoogled-chromium-windows)    | dev             |
|           |  [RobRich](https://github.com/RobRich999/Chromium_Clang)                                  | dev             |

\* _Name used be called "Editor" in previous versions_

\* _Defaults in **bold**_

Make sure the combination of name and channel you pick is correct. You can also use `chrupd.cmd -list`. For more information about versions check [chromium.woolyss.com](https://chromium.woolyss.com/?cut=1&ago=1), it's [feed](https://chromium.woolyss.com/feed/windows-64-bit) and [chromium.org](https://www.chromium.org).

- using `-name Ungoogled` still works (now done by Marmaduke)
- for the builds from chromium.org use `Official`
- some authors release archive files instead of installers, more info: [docs/Files.md](/docs/Files.md#archives)

## ⏰ Scheduled Task

To make sure Chromium is always automatically updated to the latest version you can optionally add a Scheduled Task by using `chrupd.cmd -crTask`. A VBS wrapper will be written to **chrupd.vbs** which is used to hide it's window. Option `noVbs` disables the wrapper, this will however cause a flashing window when the task runs. Specifed settings for 'name' and 'channel' are used to run the script every day.

## 🔃 Updating Script

The script auto updates itself (since v20210109).

(**!**) If you keep getting an error about "Unable to get new script, skipped update", this means a new version was detected but the script was unable to get the new version from GitHub. Try again later or manually update.

To manually update to a newer script version just replace "chrupd.cmd". Copy "name" and "channel" if set. If you have Scheduled Task setup you do not need to change the task.

## 📁 Files

For easy execution this PowerShell script is embedded in a Batch .CMD file 'chrupd.cmd' which is all you need to run.

See [docs/Files.md](/docs/Files.md) for details about other repository files.

## 💻 Command Line Options

`chrupd.cmd -h`

```text

Simple Chromium Updater (chrupd.cmd:20230811)
---------------------------------------------

Installs latest available Chromium version
Checks RSS feed from "chromium.woolyss.com" and GitHub API

USAGE: chrupd.cmd -[name|arch|channel|force] or -[list|crTask|shTask]

         -name    option must be set to a release name:   (default=Hibbiki)
                  <Official|Hibbiki|Marmaduke|Ungoogled|justclueless|Eloston|RobRich>
         -channel can be set to [stable|dev] (default=stable)
         -arch    can be set to [64bit|32bit] (default=64bit)

         -list    show available releases and exit
         -crTask  create a daily scheduled task and exit
         -shTask  show scheduled task details and exit
         -force   always (re)install, even if latest version is installed

EXAMPLE: ".\chrupd.cmd -name Marmaduke -arch 64bit -channel stable [-crTask]"

NOTES:   Options "name" and "channel" need an argument (CasE Sensive)
         Try 'chrupd.cmd -advhelp' for "advanced" options

```

More info about advanced options can be found here: [docs/Options.md](/docs/Options.md)

> _chrupd uses modified code from [http://www.mobzystems.com/code/7-zip-powershell-module/](www.mobzystems.com/code/7-zip-powershell-module)_
