# Changes

**2021-01-22** Fix Ungoogled filename (#12)

**2021-01-09** Added auto script updater (or manually: `-cUpdate`)

**2020-12-02** Pretty big update:

- new and improved method to parse RSS (old regex method as fallback)
- auto download 7zip if missing (fixes issue [#6](https://github.com/mkorthof/chrupd/issues/6))
- improved user messages (err, warnings and info)
- cleaned up code
- added 'docs' dir

**2020-10-17** Fixed regex matching Zip/7z url's (Ungoogled, Marmaduke), new options: `eDir` and `lnkArgs`(issue [#7](https://github.com/mkorthof/chrupd/issues/7)), added advanced help (`chrupd -ah`)

**2020-10-07** Typos/small fixes (issue [#10](https://github.com/mkorthof/chrupd/issues/10))

**2020-06-26** Small change to regex for matching hash (issue [#8](https://github.com/mkorthof/chrupd/issues/8))

**2020-03-20** Changed Revision to also match 3 digits

**2020-01-22** Changed default Editor to "Hibbiki"

**2019-09-27** Changed default Editor to "Marmaduke", added support for "Ungoogled" version, added arch(itecture) option, added proxy server option

**2019-08-19** Fixed issue [#5](https://github.com/mkorthof/chrupd/issues/5) (spaces in path)

**2019-01-26** Added `UseBasicParsing` parameter to `Invoke-Webrequest` (fixes issue [#4](https://github.com/mkorthof/chrupd/issues/4))

**2018-10-12** Added 2 alternative modes to add Scheduled Tasks

- OS version should be detected and correct mode automatically selected, but `tsMode` can be used to force it. If the script is still unable to add a New Task it will display instructions on how to do it manually. It can also export to Task XML file. This takes care of issue [#3](https://github.com/mkorthof/chrupd/issues/3).

  - 1 - Normal: Windows 8+ and 2012+, PowerShell 3.0+ (ScheduledTasks module)
  - 2 - Legacy: Windows 7 and 2008, PowerShell 2.0+ (COMObject Schedule.Service)
  - 3 - Command: Windows XP and 2003 (schtasks.exe)

**2018-08-09** Nik's nosync builds are no longer available ([more info](https://chromium.woolyss.com/#news)). Removed related getFile option as it is no longer needed.

**2018-07-29** FIXED: _There seems to be an mismatch between the Version and Revision listed in the RSS feed and URL of Nik's dev "sync" Installer (issue [#1](https://github.com/mkorthof/chrupd/issues/1)). Added option `-ignVer` to ignore this and skip checking version, be sure to manually check correct version when using this option._
