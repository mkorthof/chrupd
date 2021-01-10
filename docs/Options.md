# Advanced Options

Besides the normal options (`chrupd.cmd -h`), there's some extra options you'll normally won't need but are available in case you need them.

For example if you use proxy or are having issues with scheduled tasks.

There also options `appDir` and `linkArgs` which are related to [archive installs](/docs/Archives.md).

`chrupd.cmd -ah`

``` text

Simple Chromium Updater (chrupd.cmd)

USAGE: chrupd.cmd -[tsMode|rmTask|noVbs|confirm]
                  -[proxy|cAutoUp|appDir|linkArgs|ignVer] or [-cUpdate]

         -tsMode    *see NOTES below* set option to <1|2|3> or "auto"
         -rmTask    remove scheduled task
         -noVbs     do not use vbs wrapper to hide window when creating task
         -confirm   answer 'Y' on prompt about removing scheduled task

         -proxy     use a http proxy server, set option to <uri>
         -cAutoUp   auto update this script, set option to <0|1> (default=1)
         -appDir    extract archives to %AppData%\Chromium\Application\$editor
         -linkArgs  option sets <arguments> for chrome.exe in Chromium shortcut
         -ignVer    ignore version mismatch between feed and filename

         -cUpdate   manually update this script

NOTES: Option "tsMode" supports these task scheduler modes:
         - Unset: OS will be auto detected (Default)
         - Or set: 1=Normal (Windows8+), 2=Legacy (Win7), 3=Command (WinXP)
       Flags "xxTask" can also be used without other settings
       All options can be set permanently using variables inside script

```
