# Changes

See [commits](https://github.com/mkorthof/chrupd/commits/master) or `git log`

**2025-09-22** Fix Hibbiki installer filemask, add `ignHashWait`, warn about missing Tlsv1.3 support

**2024-05-27** Added thorium and Supermium (github) ([#31](https://github.com/mkorthof/chrupd/issues/30))

**2024-05-26** Added `tag` option to match on github tags, e.g. for "avx": `-tag ".*avx$"` ([#31](https://github.com/mkorthof/chrupd/issues/31))

**2024-03-37** Readded Editor RobRich999 (github api) ([#29](https://github.com/mkorthof/chrupd/issues/29))

**2023-08-12** Refactor parts of script: 7z func, test-path checks, easier to change script vars for user, updated help and docs

**2023-08-06** Fix system level install paths and regkeys to detect chromium version ([#26](https://github.com/mkorthof/chrupd/issues/26))

**2023-06-23** Detect chromium install when using `sysLvl` ([#25](https://github.com/mkorthof/chrupd/issues/25))

**2023-06-16** Added `sysLvl` option for system wide installs ([#20](https://github.com/mkorthof/chrupd/issues/20))

**2022-11-03** Cleaned up and refactored script

**2022-08-25** Renamed "editor" to "name" (**config change**)

**2022-08-13** If channel setting is missing, fall back to "stable" as default

**2022-07-13** Added extra version check: compares to be installed version number to current

**2022-07-11** Added authors: justclueless, Ungoogled-Eloston (GitHub) ([#21](https://github.com/mkorthof/chrupd/issues/21))

**2022-07-10** Readded GitHub as 'feed' using JSON from repo api

**2022-04-15** Removed Editor RobRich

**2021-06-16** Fixed task & vbs wrapper ([#16](https://github.com/mkorthof/chrupd/issues/16))

**2021-06-16** Added tests (wip)

**2021-06-01** Fixed `-appDir` ([#14](https://github.com/mkorthof/chrupd/issues/14))

**2021-05-26** Cosmetic: "title" and "editor" are shown differently in `-list` and in current settings ([#13](https://github.com/mkorthof/chrupd/issues/13))

**2021-05-25** Architecture 64bit is now default

**2021-01-22** Fix Ungoogled filename ([#12](https://github.com/mkorthof/chrupd/issues/12))

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
