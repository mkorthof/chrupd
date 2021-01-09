# Really Simple Syndication

RSS feeds use the XML format. It contains elements like title, link and description. Chrupd parses this information to try and find get the version you specify in the  configuration. To see how it looks, here's an mocked example of a 'stable' release by editor 'Hibbiki'.

## RSS

*This is how a rendered item looks:*

Chromium 64-bit on Windows (Hibbiki)

Chromium • Windows (64-bit only) By: Woolyss

**Stable version:**

- Editor: Hibbiki
- Architecture: 64-bit
- Channel: stable
- Version: 99.0.1234.321
- Revision: 987654
- Codecs: all audio/video formats
- Date: 2021-01-01

Download from Github repository:

- [mini_installer.sync.exe](ttps://github.com/Hibbiki/chromium-win64/releases/download/v99.0.1234.321-r987654/mini_installer.sync.exe)

  sha1: abcdef123456789abcdef123456789abcdef1234

- [chrome.sync.7z](https://github.com/Hibbiki/chromium-win64/releases/download/v99.0.1234.321-r987654/chrome.sync.7z)

  sha1: 0987654321fedcba0987654321fedcba09876543

Source: https://chromium.woolyss.com/

## XML

*And here's the same item in XML*

``` xml

<item>
  <title>Chromium 64-bit on Windows (Hibbiki)</title>
  <link>https://chromium.woolyss.com/#win64-stable-sync-hibbiki</link>
  <description>
    <![CDATA[ <strong>Stable version</strong>: <ul><li>Editor: <a href="https://chromium.woolyss.com/">Hibbiki</a></li><li>Architecture: 64-bit</li><li>Channel: stable</li><li>Version: 99.0.1234.321</li><li>Revision: 987654</li><li>Codecs: all audio/video formats</li><li>Date: <abbr title="Date format: YYYY-MM-DD">2021-01-01</abbr></li></ul> Download from Github repository: <ul><li><a href="https://github.com/Hibbiki/chromium-win64/releases/download/v99.0.1234.321-r987654/mini_installer.sync.exe">mini_installer.sync.exe</a><br />sha1: abcdef123456789abcdef123456789abcdef1234</li><li><a href="https://github.com/Hibbiki/chromium-win64/releases/download/v99.0.1234.321-r987654/chrome.sync.7z">chrome.sync.7z</a><br />sha1: 0987654321fedcba0987654321fedcba09876543</li></ul><small>Source: <a href="https://chromium.woolyss.com/">https://chromium.woolyss.com/</a></small> ]]>
 </description>
  <pubDate>Wed, 01 Jan 2021 01:12:11 +0100</pubDate>
  <dc:creator>Woolyss</dc:creator>
  <dc:rights>Creative Commons Attribution-ShareAlike (CC BY-SA)</dc:rights>
</item>

```
