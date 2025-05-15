<#
.SYNOPSIS
Provides a WPF GUI to rotate images and MP4 videos based on metadata using exiftool.

.DESCRIPTION
Allows users to select multiple image/video files (JPG, PNG, TIFF, RAW, MP4) via button
or drag-and-drop, previews them, provides controls to rotate each item clockwise or
counter-clockwise, and saves the changes to the metadata (EXIF Orientation for images,
Rotation tag for MP4) using exiftool. Offers an option to overwrite original files or keep backups.

.REQUIREMENTS
- PowerShell 5.1+
- .NET Framework (for WPF)
- exiftool.exe accessible in the system PATH or script modified with the full path.
- Appropriate system video codecs installed for MP4 preview via WPF MediaElement.

.NOTES
Version: 1.12
Author: Adromir
Date: 2025-05-13
Change:
- Increased default window width to better accommodate 4 large previews per row.
- Fixed XAML parsing error by escaping ampersand in TextBlock content (&amp;).
- Moved XAML comment inside Window tag.
- Increased preview item size.
- Added Drag and Drop functionality.
- Refactored file loading logic.
- Fixed ParserError in Get-MetadataOrientation.
- Added support for MP4 files.
#>

#region Prerequisites Check
Write-Host "Checking for exiftool..."
$exiftoolPath = Get-Command exiftool.exe -ErrorAction SilentlyContinue
if (-not $exiftoolPath) {
    Write-Error "exiftool.exe not found. Please ensure it is installed and in your system's PATH."
    Read-Host "Press Enter to exit."
    exit 1
}
Write-Host "Found exiftool at: $($exiftoolPath.Source)"
#endregion

#region WPF Assembly Loading
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms # For OpenFileDialog
#endregion

#region WPF UI Definition (XAML)
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="EXIF/MP4 Metadata Rotator" Height="700" Width="1550" MinWidth="800" MinHeight="400" WindowStartupLocation="CenterScreen"
        AllowDrop="True">
        <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="btnSelectFiles" Content="Select Image/Video Files..." Padding="5" VerticalAlignment="Center"/>
            <TextBlock x:Name="txtStatus" Text="Select files or drag &amp; drop here." VerticalAlignment="Center" Margin="10,0,0,0" FontStyle="Italic"/>
        </StackPanel>

        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <WrapPanel x:Name="itemWrapPanel" Orientation="Horizontal" ItemWidth="360" ItemHeight="460"/>
        </ScrollViewer>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
             <CheckBox x:Name="chkOverwrite" Content="Overwrite original files (no backup)" VerticalAlignment="Center" Margin="0,0,15,0" ToolTip="If unchecked, exiftool will create backups (filename_original)."/>
             <Button x:Name="btnSave" Content="Save Changes" Padding="5" IsEnabled="False"/>
             <Button x:Name="btnClose" Content="Close" Padding="5" Margin="10,0,0,0"/>
        </StackPanel>
    </Grid>
</Window>
"@
#endregion

#region Script Variables and Helper Functions

# Reference to the XAML Reader and created Window/Controls
$reader = New-Object System.Xml.XmlNodeReader $xaml
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "Error loading XAML: $($_.Exception.Message)"
    # Display the problematic XAML for debugging
    Write-Host "--- Problematic XAML ---" -ForegroundColor Yellow
    Write-Host $xaml.OuterXml # Or just $xaml if it didn't cast to [xml]
    Write-Host "------------------------" -ForegroundColor Yellow
    Read-Host "Press Enter to exit."
    exit 1
}

# Get references to the UI elements
$btnSelectFiles = $window.FindName("btnSelectFiles")
$txtStatus = $window.FindName("txtStatus")
$itemWrapPanel = $window.FindName("itemWrapPanel")
$chkOverwrite = $window.FindName("chkOverwrite")
$btnSave = $window.FindName("btnSave")
$btnClose = $window.FindName("btnClose")

# Store information about the items (images or videos)
$itemData = @{} # Hashtable: Key = FilePath, Value = Hashtable { Control, Orientation, OriginalOrientation, IsVideo }

# List of supported extensions (lowercase) for filtering drag/drop
$supportedExtensions = @(
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', # Common Images
    '.cr2', '.nef', '.arw', '.dng', '.orf', '.raf', '.pef', '.rw2', # Common RAW
    '.mp4' # Video
)

# --- Metadata Helper Functions ---

# Map MP4 Rotation (0, 90, 180, 270) to EXIF Orientation (1, 6, 3, 8)
function Convert-Mp4RotationToExifOrientation {
    param([int]$Rotation)
    switch ($Rotation) {
        0   { return 1 } # Normal
        90  { return 6 } # Rotated 90 CW
        180 { return 3 } # Rotated 180
        270 { return 8 } # Rotated 270 CW (90 CCW)
        default {
            Write-Warning "Unexpected MP4 rotation value [$Rotation]. Assuming 0 degrees (Orientation 1)."
            return 1
        }
    }
}

# Map EXIF Orientation (1, 6, 3, 8) back to MP4 Rotation (0, 90, 180, 270)
function Convert-ExifOrientationToMp4Rotation {
    param([int]$Orientation)
    switch ($Orientation) {
        1 { return 0 }   # Normal
        6 { return 90 }  # Rotated 90 CW
        3 { return 180 } # Rotated 180
        8 { return 270 } # Rotated 270 CW
        # Handle other EXIF values (flips) - map them to nearest rotation for MP4
        2 { return 0 }   # Flipped H -> Normal
        4 { return 180 } # Flipped V -> Rotated 180
        5 { return 90 }  # Flipped H + Rot 270 -> Rotated 90 CW
        7 { return 270 } # Flipped V + Rot 90 -> Rotated 270 CW
        default {
             Write-Warning "Unexpected EXIF orientation value [$Orientation] for MP4 conversion. Assuming 0 degrees."
            return 0
        }
    }
}

# Helper function to get metadata orientation (EXIF or MP4 Rotation)
function Get-MetadataOrientation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    $isVideo = $FilePath.ToLower().EndsWith(".mp4")
    $tagToRead = if ($isVideo) { "Rotation" } else { "Orientation" }

    try {
        Write-Verbose "Getting metadata orientation ($tagToRead) for: $FilePath"
        $result = & exiftool -n "-$tagToRead" -S -G0 -fast "$FilePath" 2>&1
        $exitCode = $LASTEXITCODE

        if ($result -match "Warning:.*Tag '$tagToRead' is not defined") {
             Write-Verbose "$tagToRead tag not found for [$FilePath]. Assuming default (Orientation 1 / Rotation 0)."
             return 1
        }
        if ($exitCode -ne 0) {
            Write-Warning "Exiftool error getting $tagToRead for [$FilePath]: $result"
            return $null
        }

        $orientationLine = $result | Select-String -Pattern "$($tagToRead):"
        if ($orientationLine) {
            $valueString = ($orientationLine -split ": ")[1].Trim()
            if ($isVideo) {
                if ($valueString -match '^(0|90|180|270)$') {
                    $mp4Rotation = [int]$valueString
                    Write-Verbose "Found MP4 Rotation: $mp4Rotation"
                    return Convert-Mp4RotationToExifOrientation -Rotation $mp4Rotation
                } else {
                    Write-Warning "Unexpected MP4 rotation value '[$valueString]' for [$FilePath]. Assuming 0 degrees (Orientation 1)."
                    return 1
                }
            } else { # Is Image
                if ($valueString -match '^[1-8]$') {
                    Write-Verbose "Found EXIF Orientation: $valueString"
                    return [int]$valueString
                } else {
                    Write-Warning "Unexpected EXIF orientation value '[$valueString]' for [$FilePath]. Treating as '1' (Normal)."
                    return 1
                }
            }
        } else {
            Write-Verbose "$tagToRead tag not found for [$FilePath] (exiftool success, no tag output). Assuming default."
            return 1
        }
    } catch {
        Write-Warning "Exception getting $tagToRead for [$FilePath]: $($_.Exception.Message)"
        return $null
    }
}

# Helper function to set metadata orientation (EXIF or MP4 Rotation)
function Set-MetadataOrientation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [int]$ExifOrientation, # Always use EXIF orientation internally
        [Parameter(Mandatory=$true)]
        [bool]$Overwrite
    )
    $isVideo = $FilePath.ToLower().EndsWith(".mp4")
    $tagToWrite = if ($isVideo) { "Rotation" } else { "Orientation" }
    $valueToWrite = if ($isVideo) { Convert-ExifOrientationToMp4Rotation -Orientation $ExifOrientation } else { $ExifOrientation }

    try {
        $arguments = @("-fast", "-$tagToWrite=$valueToWrite")
        if ($Overwrite) {
            $arguments += "-overwrite_original"
            Write-Verbose "Overwrite checked. Using -overwrite_original (no backup)."
        } else {
             Write-Verbose "Overwrite unchecked. Using default exiftool behavior (creates backup)."
        }

        Write-Verbose "Executing: exiftool $arguments `"$FilePath`""
        $result = & exiftool $arguments "$FilePath" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Exiftool error setting $tagToWrite for [$FilePath]: $result"
            return $false
        }
        if ($result -match '1 image files updated' -or $result -match '1 video files updated') {
             Write-Verbose "Successfully set $tagToWrite [$valueToWrite] for [$FilePath]"
             return $true
        } elseif ($result -match '1 image files unchanged' -or $result -match '1 video files unchanged') {
             Write-Verbose "$tagToWrite already set to [$valueToWrite] for [$FilePath]. No change needed."
             return $true
        } else {
             Write-Warning "Exiftool may not have updated $tagToWrite for [$FilePath] (ExitCode 0, no 'updated' message). Output: $result"
             return $true
        }
    } catch {
        Write-Warning "Exception setting $tagToWrite for [$FilePath]: $($_.Exception.Message)"
        return $false
    }
}

# --- WPF Visual Helper Functions ---

function Get-RotationAngleFromExif { param([int]$Orientation) switch ($Orientation) { 1 { return 0 } 2 { return 0 } 3 { return 180 } 4 { return 180 } 5 { return 90 } 6 { return 90 } 7 { return 270 } 8 { return 270 } default { return 0 } } }
function Get-ScaleTransformFromExif { param([int]$Orientation) $scaleX = 1.0; $scaleY = 1.0; switch ($Orientation) { 2 { $scaleX = -1.0 } 4 { $scaleY = -1.0 } 5 { $scaleY = -1.0 } 7 { $scaleX = -1.0 } }; return New-Object System.Windows.Media.ScaleTransform($scaleX, $scaleY) }

function Update-VisualRotation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [int]$NewExifOrientation
    )
    if (-not $itemData.ContainsKey($FilePath)) { return }
    $itemInfo = $itemData[$FilePath]
    $control = $itemInfo.Control
    $itemInfo.Orientation = $NewExifOrientation
    if ($null -eq $control) { Write-Verbose "Skipping visual rotation update for [$FilePath] as preview failed."; return }
    $rotationAngle = Get-RotationAngleFromExif -Orientation $NewExifOrientation
    $scaleTransform = Get-ScaleTransformFromExif -Orientation $NewExifOrientation
    $transformGroup = New-Object System.Windows.Media.TransformGroup
    $transformGroup.Children.Add((New-Object System.Windows.Media.RotateTransform($rotationAngle)))
    $transformGroup.Children.Add($scaleTransform)
    $control.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
    $control.RenderTransform = $transformGroup
}

function Calculate-NewOrientation {
    param(
        [Parameter(Mandatory=$true)]
        [int]$CurrentOrientation,
        [Parameter(Mandatory=$true)]
        [ValidateSet('CW', 'CCW')]
        [string]$Direction
    )
    if ($null -eq $CurrentOrientation -or $CurrentOrientation -lt 1 -or $CurrentOrientation -gt 8) { Write-Warning "Invalid current orientation [$CurrentOrientation]. Defaulting to 1."; $CurrentOrientation = 1 }
    $cwMap = @{ 1=6; 6=3; 3=8; 8=1; 2=7; 7=4; 4=5; 5=2 }
    $ccwMap = @{ 1=8; 8=3; 3=6; 6=1; 2=5; 5=4; 4=7; 7=2 }
    if ($Direction -eq 'CW') { return $cwMap[$CurrentOrientation] } else { return $ccwMap[$CurrentOrientation] }
}

# --- File Loading Function (Refactored) ---
function Load-Files {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$FilePaths
    )

    # Filter for supported extensions first
    $filteredPaths = $FilePaths | Where-Object { $supportedExtensions -contains [System.IO.Path]::GetExtension($_).ToLower() }

    if ($filteredPaths.Count -eq 0) {
        $txtStatus.Text = "No supported files found in selection."
        Return
    }

    $txtStatus.Text = "Loading $($filteredPaths.Count) files..."
    $window.UpdateLayout()

    # Clear existing items before loading new ones
    $itemWrapPanel.Children.Clear()
    $itemData.Clear()
    $btnSave.IsEnabled = $false

    $loadedCount = 0
    $previewErrorCount = 0
    foreach ($filePath in $filteredPaths) {
        # This outer try/catch handles unexpected errors during the whole process for one file
        try {
            if (-not (Test-Path -Path $filePath -PathType Leaf)) {
                 Write-Warning "File not found or is a directory: [$filePath]"
                 continue
            }

            # 1. Get Current Metadata Orientation
            $currentOrientation = Get-MetadataOrientation -FilePath $filePath
            if ($null -eq $currentOrientation) {
                Write-Warning "Could not reliably read orientation for [$filePath], skipping."
                continue
            }

            # 2. Create WPF Elements
            $grid = New-Object System.Windows.Controls.Grid
            $grid.Margin = New-Object System.Windows.Thickness(5)
            $grid.Tag = $filePath
            $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }))
            $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = [System.Windows.GridLength]::Auto }))

            $control = $null
            $placeholder = $null
            $isVideo = $filePath.ToLower().EndsWith(".mp4")

            # Attempt to create preview control
            try {
                $fileUri = New-Object System.Uri($filePath, [System.UriKind]::Absolute)
                if ($isVideo) {
                    $mediaElement = New-Object System.Windows.Controls.MediaElement
                    $mediaElement.Source = $fileUri
                    $mediaElement.LoadedBehavior = [System.Windows.Controls.MediaState]::Manual
                    $mediaElement.ScrubbingEnabled = $true
                    $mediaElement.Volume = 0
                    $mediaElement.Stretch = [System.Windows.Media.Stretch]::Uniform
                    $mediaElement.Margin = New-Object System.Windows.Thickness(0,0,0,5)
                    $mediaElement.ToolTip = $filePath
                    $mediaElement.Add_Loaded({ $this.Stop() })
                    $mediaElement.Add_MediaFailed({param($sender,$e) Write-Warning "MediaFailed event for [$($sender.Source)]: $($e.ErrorException.Message)" })
                    $mediaElement.Add_MediaOpened({param($sender,$e) $sender.Stop() })
                    $control = $mediaElement
                    $placeholder = $control
                } else {
                    $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
                    $bitmapImage.BeginInit()
                    $bitmapImage.UriSource = $fileUri
                    $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    # Consider DecodePixelWidth for performance with large images/previews
                    # $bitmapImage.DecodePixelWidth = 340 # Slightly less than ItemWidth
                    $bitmapImage.EndInit()
                    $bitmapImage.Freeze()
                    $image = New-Object System.Windows.Controls.Image
                    $image.Stretch = [System.Windows.Media.Stretch]::Uniform
                    $image.Margin = New-Object System.Windows.Thickness(0,0,0,5)
                    $image.ToolTip = $filePath
                    $image.Source = $bitmapImage
                    $control = $image
                    $placeholder = $control
                }
            } catch {
                $errMsg = if ($isVideo) { "WPF MediaElement failed" } else { "WPF Image failed" }
                Write-Warning "$errMsg to create preview for [$filePath]: $($_.Exception.Message). Rotation may still work via ExifTool."
                $previewErrorCount++
                $textBlock = New-Object System.Windows.Controls.TextBlock
                $textBlock.Text = "[Preview N/A]" + "`n" + "(Codec missing?)"
                $textBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
                $textBlock.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
                $textBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $textBlock.FontStyle = [System.Windows.FontStyles]::Italic
                $textBlock.ToolTip = "$errMsg. Rotation based on metadata is still possible."
                $placeholder = $textBlock
                $control = $null
            }

            # Add placeholder (Control or TextBlock) to grid
            [System.Windows.Controls.Grid]::SetRow($placeholder, 0)
            $grid.Children.Add($placeholder)

            # Button Panel
            $buttonPanel = New-Object System.Windows.Controls.StackPanel
            $buttonPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $buttonPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            [System.Windows.Controls.Grid]::SetRow($buttonPanel, 1)
            $grid.Children.Add($buttonPanel)

            # Rotate CCW Button
            $btnCCW = New-Object System.Windows.Controls.Button
            $btnCCW.Content = "↶"; $btnCCW.FontWeight = [System.Windows.FontWeights]::Bold; $btnCCW.Width = 30; $btnCCW.Margin = New-Object System.Windows.Thickness(0,0,5,0); $btnCCW.Tag = $filePath
            $btnCCW.Add_Click({ param($sender, $e); $path = $sender.Tag; if (-not $itemData.ContainsKey($path)) { return }; $currentOrient = $itemData[$path].Orientation; $newOrient = Calculate-NewOrientation -CurrentOrientation $currentOrient -Direction 'CCW'; Update-VisualRotation -FilePath $path -NewExifOrientation $newOrient })
            $buttonPanel.Children.Add($btnCCW)

            # Rotate CW Button
            $btnCW = New-Object System.Windows.Controls.Button
            $btnCW.Content = "↷"; $btnCW.FontWeight = [System.Windows.FontWeights]::Bold; $btnCW.Width = 30; $btnCW.Tag = $filePath
            $btnCW.Add_Click({ param($sender, $e); $path = $sender.Tag; if (-not $itemData.ContainsKey($path)) { return }; $currentOrient = $itemData[$path].Orientation; $newOrient = Calculate-NewOrientation -CurrentOrientation $currentOrient -Direction 'CW'; Update-VisualRotation -FilePath $path -NewExifOrientation $newOrient })
            $buttonPanel.Children.Add($btnCW)

            # 3. Add to WrapPanel and Store Data
            $itemWrapPanel.Children.Add($grid)
            $itemData[$filePath] = @{
                Control = $control
                Orientation = $currentOrientation
                OriginalOrientation = $currentOrientation
                IsVideo = $isVideo
            }

            # 4. Apply Initial Rotation
            if ($control -ne $null) {
                Update-VisualRotation -FilePath $filePath -NewExifOrientation $currentOrientation
            }
            $loadedCount++

        } catch {
            Write-Warning "Unexpected error processing file [$filePath]: $($_.Exception.Message)"
        }
    } # End foreach file

    $statusText = "Loaded $loadedCount file(s)."
    if ($previewErrorCount -gt 0) {
        $statusText += " ($previewErrorCount preview(s) failed - check codecs)."
    }
    $txtStatus.Text = $statusText

    if ($loadedCount -gt 0) {
        $btnSave.IsEnabled = $true
    } else {
        # If filtering resulted in 0 supported files, update status
        if ($FilePaths.Count -gt 0 -and $filteredPaths.Count -eq 0) {
             $txtStatus.Text = "No supported files found in selection."
        } else {
             # Keep the "Loading..." status briefly if something unexpected happened
        }
        $btnSave.IsEnabled = $false
    }
}
#endregion

#region Event Handlers

# --- Button: Select Files ---
$btnSelectFiles.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Supported Files|*.jpg;*.jpeg;*.png;*.gif;*.bmp;*.tiff;*.tif;*.cr2;*.nef;*.arw;*.dng;*.orf;*.raf;*.pef;*.rw2;*.mp4|Image Files|*.jpg;*.jpeg;*.png;*.gif;*.bmp;*.tiff;*.tif;*.cr2;*.nef;*.arw;*.dng;*.orf;*.raf;*.pef;*.rw2|Video Files (*.mp4)|*.mp4|All files (*.*)|*.*"
    $openFileDialog.FilterIndex = 1
    $openFileDialog.Multiselect = $true
    $openFileDialog.Title = "Select Images/Videos to Rotate"

    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        # Call the refactored loading function
        Load-Files -FilePaths $openFileDialog.FileNames
    } else {
         if ($itemData.Keys.Count -eq 0) {
            $txtStatus.Text = "File selection cancelled."
         }
    }
})

# --- Drag and Drop Handlers ---
$window.Add_DragEnter({
    param($sender, $e)
    # Check if the dragged data contains files
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        # Indicate that dropping is allowed (shows the copy cursor)
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    } else {
        # Indicate that dropping is not allowed
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    # Mark the event as handled
    $e.Handled = $true
})

$window.Add_Drop({
    param($sender, $e)
    # Check if the dropped data contains files
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        # Get the array of file paths
        $droppedFiles = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        if ($droppedFiles -ne $null -and $droppedFiles.Count -gt 0) {
            Write-Host "Processing $($droppedFiles.Count) dropped files..."
            # Call the refactored loading function
            Load-Files -FilePaths $droppedFiles
        }
    }
    # Mark the event as handled
    $e.Handled = $true
})


# --- Button: Save Changes ---
$btnSave.Add_Click({
    $overwrite = $chkOverwrite.IsChecked -eq $true
    $saveCount = 0
    $errorCount = 0
    $noChangeCount = 0

    $txtStatus.Text = "Saving changes..."
    $window.IsEnabled = $false
    $window.Cursor = [System.Windows.Input.Cursors]::Wait

    $i = 0
    foreach ($filePath in $itemData.Keys) {
        $i++
        $itemInfo = $itemData[$filePath]
        $currentOrientation = $itemInfo.Orientation
        $originalOrientation = $itemInfo.OriginalOrientation

        if ($currentOrientation -ne $originalOrientation) {
            Write-Host "Saving changes for [$filePath] (Original: $originalOrientation, New: $currentOrientation)"
            if (Set-MetadataOrientation -FilePath $filePath -ExifOrientation $currentOrientation -Overwrite $overwrite) {
                $saveCount++
                $itemInfo.OriginalOrientation = $currentOrientation
            } else {
                $errorCount++
                Write-Warning "Failed to save changes for [$filePath]"
            }
        } else {
            $noChangeCount++
        }
    }

    $window.IsEnabled = $true
    $window.Cursor = [System.Windows.Input.Cursors]::Arrow

    $statusMsg = "Save complete. $saveCount file(s) updated."
    if ($errorCount -gt 0) { $statusMsg += " $errorCount failed." }
    if ($noChangeCount -gt 0) { $statusMsg += " $noChangeCount required no changes." }
    if ($saveCount -eq 0 -and $errorCount -eq 0 -and $noChangeCount -gt 0) {
         $statusMsg = "No changes needed saving ($noChangeCount file(s) checked)."
    } elseif ($saveCount -eq 0 -and $errorCount -eq 0) {
        $statusMsg = "No changes were made."
    }
    $txtStatus.Text = $statusMsg
    [System.Windows.Forms.MessageBox]::Show($statusMsg, "Save Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# --- Button: Close ---
$btnClose.Add_Click({
    foreach($itemInfo in $itemData.Values) {
        if ($itemInfo.IsVideo -and $itemInfo.Control -ne $null) {
            try { $itemInfo.Control.Close(); $itemInfo.Control.Source = $null } catch {} # Best effort cleanup
        }
    }
    $window.Close()
})

#endregion

#region Show Window
Write-Host "Showing WPF window..."
$VerbosePreference = 'Continue'
$window.ShowDialog() | Out-Null
Write-Host "Window closed."
#endregion
