# based on https://stackoverflow.com/a/46214261
@(
    "test.bmp",
    "test.gif",
    "test.jpg",
    "test.tif",
    "PNG8:test8.png",
    "PNG24:test24.png",
    "PNG32:test32.png",
    "PNG48:test48.png",
    "PNG64:test64.png"
) `
| ForEach-Object {
    & ./magick "xc:red" "xc:lime" +append "(" "xc:blue" "xc:magenta" +append ")" -append -resize 8x8 -strip "$_"
}
