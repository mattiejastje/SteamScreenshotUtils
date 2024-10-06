# SteamScreenshotUtils

PowerShell utilities for managing steam screenshots.

## Installation and Usage

See the [steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3341300704).

## Warning

Steam does not officially support installing custom screenshots into
your steam screenshot folders.
Though every effort has been done to avoid corrupting the steam screenshots database,
even though unlikely, there's always a chance that something breaks.

**Make a backup of your steam userdata folder before running any scripts.**

## Features

- Installs screenshots in the expected locations for steam to find them.
  Will not touch your screenshot database, lessening the risk of database corruption.

- Automatically stops steam before installing screenshots, lessening the risk of database corruption.

- Support for "what if" and "confirm" modes:
  you can do a dry run, and every action can be individually confirmed if so desired.

- Highly configurable.

- Can be integrated into other scripts.

## Related Projects

* The [steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1753474173)
  by Wirdjos.

* The [SteaScree](https://github.com/awthwathje/SteaScree) project
  has inspired and influenced SteamScreenshotUtils in many ways.
  There are several features of SteaScree lacking in this project:

  - SteaScree has a convenient user interface, unlike SteamScreenshotUtils.
    You need to be know a little bit about PowerShell to use SteamScreenshotUtils,
    which may not be so obvious for many users.

  - SteaScree works on all platforms.
    SteamScreenshotUtils currently only works on Windows.

  - SteaScree always installs progressive jpeg files which is the most optimal format.
    SteamScreenshotUtils can only write baseline jpeg files, due to .NET limitations.
    (Note that steam natively does not create progressive jpeg files either
    though will convert and re-encode them upon upload.)

  - SteaScree modifies the screenshots database directly
    i.e. it edits the ``screenshots.vdf`` file.
    SteamScreenshotUtils never touches this file,
    and instead leaves it to steam itself to recognize the new files
    and update its database.
    Consequently, with SteamScreenshotUtils
    the screenshots may take some time to show up in the screenshot manager.
    The upside is that SteamScreenshotUtils
    has less chance of accidentally corrupting the ``screenshots.vdf`` file.