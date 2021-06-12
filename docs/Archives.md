# Archives

Usually Chromium installation is automatically taken care of by running the downloaded Installer ('mini_installer.exe'). But if the Editor releases Chromium as an zip or 7z archive, the script will to try to extract it to these paths:

| Path                                   | Example                                   |
|:---------------------------------------|:------------------------------------------|
| %LocalAppData%\Chromium\Application    | C:\Users\\<User\>\Appdata\Local\Chromium  |
| Desktop                                | C:\Users\\<User\>\Desktop                 |
| %TEMP%                                 | C:\Users\\\<User\>\TEMP                   |

( _in that order, top to bottom_ )

The folder that was used will be shown and a shortcut will be created on the Desktop called 'Chromium', which links to chrome.exe.

Related [advanced options](/docs/Options.md) are: `-appDir` and `-linkArgs`

If '7z.exe' from 7-Zip cannot be found the script will try to automatically download '7za.exe' which is a standalone version of 7-Zip.
The file will be downloaded from: 7zip.org, github-chromium, googlesource.com or chocolatey.org.

More information about 7zip:

- [https://www.7-zip.org/history.txt](https://www.7-zip.org/history.txt)
- [https://sourceforge.net/p/sevenzip/discussion/45798/thread/b599cf02/?limit=25](https://sourceforge.net/p/sevenzip/discussion/45798/thread/b599cf02/?limit=25)
