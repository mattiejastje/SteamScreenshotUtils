# SteamScreenshotUtils

Utilities for managing steam screenshots.

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

- Automatically generates thumbnails required for steam.
  For screenshots with extreme aspect ratios,
  the thumbnail generation is better than steam's own algorithm
  resulting in thumbnails that are less pixelated.

- Automatically stops steam before installing screenshots to avoid database corruption.

- Automatically scales images if they exceed steam's upload limits.

- Automatically converts images to jpeg if they are in a different format.
  Supported formats are bmp, gif, tif, and png.

- Support for "what if" and "confirm" modes:
  you can do a dry run, and every action can be individually confirmed if so desired.

- Highly configurable.

- Can be integrated into other scripts.

## Limitations

- Will *not* edit the screenshots database file, ``screenshots.vdf``,
  to avoid corrupting this file by accident.
  Steam is able to update this file by itself when it notices the new files,
  although this may take a few seconds after starting up steam's screenshot manager.

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

  - SteaScree modifies the screenshots database file, ``screenshots.vdf``.
