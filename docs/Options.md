# Options

For standard options see help (`chrupd.cmd -h`) and [README.md](/README.md).

All options can also be set as permanent defaults using variables inside script under `CONFIGURATION` and `SCRIPT VARIABLES`.

## Advanced Options

Additionally there's some extra options you'll normally won't need but are available for special cases where you *do* need them. Other options were add for particular user requests.

### Proxy

If you need to use a web proxy use: `-proxy http://myproxy.example.org:3128`

### Task scheduler

Set option `tsMode` to change task scheduler modes. If unset, OS and mode will be auto detected (Default). The script also supports setting mode 1-3 manually:

- 1: Normal (Windows 8+)
- 2: Legacy (Windows 7)
- 3: Command (schtasks.exe)

Try `-tsMode 2` (or 3) when  you're having isses creating a task.

### Archive Installs

There's also options `appDir` and `linkArgs` which are related to installing [Archives](/docs/Files.md#archives).

- `-appDir foo` installs to %AppData%\Chromium\Application\foo
- `-linkArgs myargs` changes the Chromium shortcut on Desktop from 'chrome.exe' to 'chrome.exe myargs'

### Install for all users

Instead of the default "user-level", this option does a chromium "system-level" install: `-sysLvl`.

## Advanced help

Run `chrupd.cmd -advhelp` to show help specifically for these options.

``` text

Simple Chromium Updater - Advanced options
----------------------------------------------------------------

USAGE: chrupd.cmd -[tsMode|rmTask|noVbs|confirm|proxy|cAutoUp|cUpdate]
                  -[appDir|linkArgs|sysLvl|ignVer]

         -tsMode    task scheduler mode, set option to <1|2|3> (default=auto)
                    where 1=normal:win8+ 2=legacy:win7 3=cmd:schtasks
         -rmTask    remove scheduled task and exit
         -noVbs     do not use vbs wrapper to hide window when creating task
         -confirm   answer 'Y' on prompt about removing scheduled task
         -proxy     use a http proxy server, set option to <uri>

         -cAutoUp   auto update this script, set option to <0|1> (default=1)
         -cUpdate   manually update this script to latest version and exit

         -appDir    extract archives to %AppData%\Chromium\Application\$name
         -linkArgs  option sets chrome.exe <arguments> in Chromium shortcut
         -sysLvl    system-level install, install for all users on machine
         -ignVer    ignore version mismatch between rss feed and filename

```
