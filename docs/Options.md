# Options

When you run the script it does the following by default:

- get Chromium "stable" 64-bit Installer by "Hibbiki"
- verifies file hash and run installer (sha1/md5)

For standard options see help (`chrupd.cmd -h`) and [README.md](/README.md).

All options can also be set as permanent defaults using variables inside script under `CONFIGURATION` and `SCRIPT VARIABLES`.

## Advanced Options

Additionally there's some extra options you'll normally won't need but are available for special cases where you *do* need them. Other options were added for particular [user requests](https://github.com/mkorthof/chrupd/issues?q=is%3Aissue+label%3Aenhancement).

### Proxy

If you need to use a web proxy use: `-proxy http://myproxy.example.org:3128`

### Task scheduler

Set option `tsMode` to change task scheduler modes. If unset, OS and mode will be auto detected (Default). The script also supports setting mode 1-3 manually:

- 1: Normal (Windows 8+)
- 2: Legacy (Windows 7)
- 3: Command (schtasks.exe)

Try `-tsMode 2` (or 3) when  you're having issues creating a task.

### Archive Installs

There's also options `appDir` and `linkArgs` which are related to installing [Archives](/docs/Files.md#archives).

- `-appDir foo` installs to %AppData%\Chromium\Application\foo
- `-linkArgs myargs` changes the Chromium shortcut on Desktop from 'chrome.exe' to 'chrome.exe myargs'

### Install for all users

Instead of the default "user-level", this option does a chromium "system-level" install: `-sysLvl`.

### Tags

Set [regular expression](https://en.wikipedia.org/wiki/Regular_expression) matching for filtering GitHub releases on [tag](https://docs.github.com/en/repositories/releasing-projects-on-github/viewing-your-repositorys-releases-and-tags).

Use double quotation marks around the regex, single quotes might return parser error.

For example:

- if you only want AVX2 releases: `-tag ".*avx2"`
- or, for AVX: `-tag "avx$"`.

## Advanced help

Run `chrupd.cmd -advhelp` to show help specifically for these options.

``` text

Simple Chromium Updater: Advanced Options
-----------------------------------------

USAGE: chrupd.cmd -[cAutoUp|cUpdate|appDir|linkArgs|proxy|sysLvl|ignVer|tag]
                  -[tsMode|rmTask|noVbs|confirm]

         -cAutoUp   auto update this script, set option to <0|1> (default=1)
         -cUpdate   manually update this script to latest version and exit
         -proxy     use a http proxy server, set option to <uri>

         -appDir    (archives) extract to %AppData%\Chromium\Application\$name
         -linkArgs  (archives) sets Chromion shortcut to chrome.exe <arguments>

         -sysLvl    system-level, install for all users on machine
         -ignVer    ignore version mismatch between rss feed and filename
         -tag       can be set to filter releases on matching "<regex>"
                    e.g. "avx$" note: use double quotes around regex

         -tsMode    (task) scheduler mode, set to <1|2|3> (default=auto)
                           option 1=normal:win8+ 2=legacy:win7 3=cmd:schtasks
         -rmTask    (task) remove scheduled task and exit
         -noVbs     (task) do not use vbs wrapper to hide tasks window
         -confirm   (task) answer 'Y' on prompt about removing scheduled task

```

## Virus Scanner

_**TEST** feature (unsupported), might or not not work_

Call Virus Total API to check downloaded file "id" i.e. hash:

- requires API key: <https://www.virustotal.com/gui/join-us>
- set `$vtApiKey` to try
