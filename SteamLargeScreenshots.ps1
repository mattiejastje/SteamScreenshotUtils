Add-Type -AssemblyName System.Drawing

$date = Get-Date
[String]$datestr = $date.ToString("yyyyMMddHHmmss")
[Int32]$num = 1

ForEach ($resolution In 26210175..26210225) {
  [Int64]$minwidth = [Math]::Sqrt($resolution) - 1
  [Int64]$maxwidth = 16000
  ForEach ($width In $minwidth..$maxwidth) {
    [Int64]$rem = -1
    $height = [Math]::DivRem($resolution, $width, [ref] $rem)
    If ($rem -eq 0) {
      Write-Host "$num -- $width x $height = $resolution"
      $image = New-Object System.Drawing.Bitmap $width,$height
      $filename = "{0}_{1}.jpg" -f $datestr,$num
      Write-Host "  $filename"
      [Int32]$fontsize = [Math]::Min($width, $height) / 2
      $font = new-object System.Drawing.Font "Ariel",$fontsize
      $brushBg = [System.Drawing.Brushes]::Yellow 
      $brushFg = [System.Drawing.Brushes]::Black 
      $graphics = [System.Drawing.Graphics]::FromImage($image) 
      $graphics.FillRectangle($brushBg,0,0,$image.Width,$image.Height) 
      $graphics.DrawString("$num",$font,$brushFg,($image.Width - 2 * $fontsize) / 2,($image.Height - 2 * $fontsize) / 2) 
      $graphics.Dispose()
      $jpegcodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
      $encparams = New-Object System.Drawing.Imaging.EncoderParameters(1)
      $encquality = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 90)
      $encparams.Param[0] = $encquality
      $image.Save($filename, $jpegcodec, $encparams)
      $num += 1
      Break
    }
  }
}