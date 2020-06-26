# Changes

**2020-06-26** Small change to regex for matching hash (#8)

**2020-03-20** Changed Revision to also match 3 digits

**2020-01-22** Changed default Editor to "Hibbiki"

**2019-09-27** Changed default Editor to "Marmaduke", added support for "Ungoogled" version, added arch(itecture) option, added proxy server option

**2019-08-19** Fixed issue [#5](https://github.com/mkorthof/chrupd/issues/5) (spaces in path)

**2019-01-26** Added `UseBasicParsing` parameter to `Invoke-Webrequest` (fixes issue [#4](https://github.com/mkorthof/chrupd/issues/4))

**2018-10-12** Added 2 alternative modes to add Scheduled Tasks

* OS version should be detected and correct mode automatically selected, but `tsMode` can be used to force it. If the script is still unable to add a New Task it will display instructions on how to do it manually. It can also export to Task XML file. This takes care of issue [#3](https://github.com/mkorthof/chrupd/issues/3).
  * <small>1 - Normal: Windows 8+ and 2012+, PowerShell 3.0+ (ScheduledTasks module)</small>
  * <small>2 - Legacy: Windows 7 and 2008, PowerShell 2.0+ (COMObject Schedule.Service)</small>
  * <small>3 - Command: Windows XP and 2003 (schtasks.exe)</small>

**2018-08-09** Nik's nosync builds are no longer available ([more info](https://chromium.woolyss.com/#news)). Removed related getFile option as it is no longer needed.

**2018-07-29** FIXED: *There seems to be an mismatch between the Version and Revision listed in the RSS feed and URL of Nik's dev "sync" Installer (issue [#1](https://github.com/mkorthof/chrupd/issues/1)). Added option `-ignVer` to ignore this and skip checking version, be sure to manually check correct version when using this option.*
