# SteamScreenshotUtils

PowerShell utilities for managing steam screenshots.

## Installation and Usage

See the [steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3341300704).

## Related Projects

* The [steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1753474173)
  by Wirdjos.

* The [SteaScree](https://github.com/awthwathje/SteaScree) project
  has inspired and influenced SteamScreenshotUtils in many ways.
  Differences:

  - SteaScree has a convenient user interface, unlike SteamScreenshotUtils.
    You need to be know a little bit about PowerShell to use SteamScreenshotUtils,
    which may not be so obvious for many users.

  - SteaScree works on all platforms.
    SteamScreenshotUtils currently only works on Windows.

  - SteaScree always installs progressive jpeg files which is the most optimal format.
    SteamScreenshotUtils can only write baseline jpeg files, due to .NET limitations.
    (Note that steam natively does not create progressive jpeg files either
    though will convert and re-encode them upon upload.)

  - SteamScreenshotUtils will not touch your screenshot database,
    thus lessen the risk of database corruption.

  - SteamScreenshotUtils will stop steam before installing screenshots,
    thus lessen the risk of database corruption.

  - SteamScreenshotUtils gives you a huge amount of control over the process,
    more so than SteaScree.
    Every aspect can be configured through numerous parameters.
    Being PowerShell, users can integrate SteamScreenshotUtils into their own scripts.