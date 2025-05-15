<#
.SYNOPSIS
Downloads an ambient mix (XML, sound files, and preview image) from ambient-mixer.com using a WPF GUI. Saves XML named after the mix title and adds title/description. Supports a default download folder via config.json.

.DESCRIPTION
This script presents a WPF dialog to the user to input an ambient-mixer.com URL
and select a destination folder. It attempts to determine the mix's name and description
from the page's H1/title and og:description tags.
It creates a dedicated subfolder (named after the mix, sanitized) within the destination.
It then downloads:
1. The mix's XML configuration into the subfolder, named after the mix title (e.g., mix-title.xml).
2. The preview image (from og:image meta tag) into the subfolder (e.g., cover.jpg).
3. Associated sound files into an 'audio' sub-subfolder, renaming them based on the <name_audio> tag.
Finally, it modifies the downloaded XML file to:
- Update the <url_audio> paths to point to the local audio files.
- Remove <id_template>, <id_session_user>, and <id_session_player> tags.
- Add <title> and <description> tags with the fetched mix name and description.

Includes fix for TLS 1.2, improved download error reporting, and default folder configuration via config.json.
Uses XPath for XML parsing.

.NOTES
Author: Adromir (modified based on user request)
Date: 2025-05-03
Requires: .NET Framework (usually included with Windows), PowerShell 3.0+ (for ConvertTo-Json/ConvertFrom-Json)
#>

#region Pre-requisites & Setup

# Explicitly set Security Protocol to TLS 1.2 (and others if needed)
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls
} catch {
    Write-Warning "Could not set TLS 1.2 security protocol. Downloads might fail. Error: $($_.Exception.Message)"
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms # Required for FolderBrowserDialog

# Configuration File Path (same directory as script)
# $PSScriptRoot is an automatic variable containing the directory of the script file
$configFilePath = Join-Path $PSScriptRoot "config.json"
$defaultFolderPathFromConfig = $null

#endregion Pre-requisites & Setup

#region Config Handling Functions

# Loads the default folder path from the config.json file
function Load-DefaultFolderConfig {
    param([string]$Path)
    # Check if the config file exists
    if (Test-Path -Path $Path -PathType Leaf) {
        try {
            # Read the file content and convert from JSON
            $config = Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop
            # Check if the defaultFolderPath property exists and is a valid directory
            if ($config.PSObject.Properties['defaultFolderPath'] -ne $null -and (Test-Path -Path $config.defaultFolderPath -PathType Container)) {
                Write-Verbose "Loaded default folder path: $($config.defaultFolderPath)"
                return $config.defaultFolderPath
            } else {
                Write-Verbose "Config file found but 'defaultFolderPath' is missing, empty, or invalid."
                return $null
            }
        } catch {
            # Handle errors during file reading or JSON parsing
            Write-Warning "Failed to read or parse config file '$Path'. Error: $($_.Exception.Message)"
            return $null
        }
    } else {
        # Config file not found
        Write-Verbose "Config file '$Path' not found."
        return $null
    }
}

# Saves the selected folder path to the config.json file
function Save-DefaultFolderConfig {
    param(
        [string]$Path,
        [string]$FolderPath
    )
    # Create a hashtable for the configuration
    $configObject = @{ defaultFolderPath = $FolderPath }
    try {
        # Convert the hashtable to JSON and write it to the file
        $configObject | ConvertTo-Json -Depth 1 | Set-Content -Path $Path -Encoding UTF8 -Force
        Write-Verbose "Saved default folder path '$FolderPath' to '$Path'."
        return $true
    } catch {
        # Handle errors during file writing
        Write-Warning "Failed to save config file '$Path'. Error: $($_.Exception.Message)"
        return $false
    }
}

#endregion Config Handling Functions


#region WPF GUI Setup
# Try loading default folder before creating GUI elements
$defaultFolderPathFromConfig = Load-DefaultFolderConfig -Path $configFilePath

# Define the XAML structure for the WPF window
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Ambient Mixer Downloader" Height="250" Width="500"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize" ShowInTaskbar="True">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="*"/>    <RowDefinition Height="Auto"/> </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <Label Grid.Row="0" Grid.Column="0" Content="Ambient Mix URL:" VerticalAlignment="Center"/>
        <TextBox Grid.Row="0" Grid.Column="1" Grid.ColumnSpan="2" x:Name="urlTextBox" Margin="5,0,0,0" VerticalAlignment="Center"/>

        <Label Grid.Row="1" Grid.Column="0" Content="Destination Folder:" Margin="0,10,0,0" VerticalAlignment="Center"/>
        <TextBox Grid.Row="1" Grid.Column="1" x:Name="folderTextBox" Margin="5,10,5,0" IsReadOnly="True" VerticalAlignment="Center"/>
        <Button Grid.Row="1" Grid.Column="2" x:Name="browseButton" Content="Browse..." Margin="0,10,0,0" Padding="5,2" VerticalAlignment="Center"/>

        <CheckBox Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2" x:Name="setDefaultCheckBox" Content="Set as Default Folder" Margin="5,5,0,0" VerticalAlignment="Center"/>

        <TextBlock Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="3" x:Name="statusTextBlock" Margin="0,15,0,0" TextWrapping="Wrap"/>

        <StackPanel Grid.Row="5" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button x:Name="okButton" Content="OK" Width="75" Margin="0,0,10,0" Padding="5,2" IsDefault="True"/>
            <Button x:Name="cancelButton" Content="Cancel" Width="75" Padding="5,2" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Create the WPF objects from the XAML definition
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "Failed to load WPF window: $($_.Exception.Message)"
    exit 1 # Exit if GUI cannot be loaded
}

# Get references to the named controls in the WPF window
$urlTextBox = $window.FindName("urlTextBox")
$folderTextBox = $window.FindName("folderTextBox")
$browseButton = $window.FindName("browseButton")
$okButton = $window.FindName("okButton")
$cancelButton = $window.FindName("cancelButton")
$statusTextBlock = $window.FindName("statusTextBlock")
$setDefaultCheckBox = $window.FindName("setDefaultCheckBox") # Reference to Checkbox

# --- Pre-populate Folder Text Box with loaded default ---
if (-not [string]::IsNullOrWhiteSpace($defaultFolderPathFromConfig)) {
    $folderTextBox.Text = $defaultFolderPathFromConfig
}

# --- Event Handlers ---

# Event handler for the Browse button click
$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Destination Folder"
    $folderBrowser.ShowNewFolderButton = $true
    # Set initial directory for the browser dialog
    if (-not [string]::IsNullOrWhiteSpace($folderTextBox.Text) -and (Test-Path -Path $folderTextBox.Text -PathType Container)) {
        $folderBrowser.SelectedPath = $folderTextBox.Text
    } elseif (-not [string]::IsNullOrWhiteSpace($defaultFolderPathFromConfig)) { # Fallback to config path if text box empty
         $folderBrowser.SelectedPath = $defaultFolderPathFromConfig
    }
    # Show the dialog
    $result = $folderBrowser.ShowDialog((New-Object System.Windows.Forms.NativeWindow)) # Pass owner window handle

    # If user clicks OK, update the text box
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $folderTextBox.Text = $folderBrowser.SelectedPath
        $statusTextBlock.Text = "" # Clear status on successful selection
    }
    # Dispose the dialog object
    $folderBrowser.Dispose()
})

# Event handler for the OK button click
$okButton.Add_Click({
    # --- Input Validation ---
    $statusTextBlock.Text = "" # Clear previous errors
    $statusTextBlock.Foreground = [System.Windows.Media.Brushes]::Black # Reset color

    if ([string]::IsNullOrWhiteSpace($urlTextBox.Text)) {
        $statusTextBlock.Text = "Error: Please enter an Ambient Mix URL."
        $statusTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
        return
    }
    # Basic URL format check using URI class for better validation
    try {
        [System.Uri]$uri = $urlTextBox.Text
        if (-not ($uri.Scheme -eq [System.Uri]::UriSchemeHttp -or $uri.Scheme -eq [System.Uri]::UriSchemeHttps)) {
            throw "Invalid scheme"
        }
    } catch {
         $statusTextBlock.Text = "Error: Please enter a valid URL (e.g., http://... or https://...)."
         $statusTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
         return
    }
     if ([string]::IsNullOrWhiteSpace($folderTextBox.Text)) {
        $statusTextBlock.Text = "Error: Please select a destination folder."
        $statusTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
        return
    }
     # Check if the selected path is a valid directory
     if (-not (Test-Path -Path $folderTextBox.Text -PathType Container)) {
         $statusTextBlock.Text = "Error: The selected destination folder is not valid or does not exist."
         $statusTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
         return
     }

    # --- Handle Default Folder Save Logic ---
    if ($setDefaultCheckBox.IsChecked -eq $true) {
        # Save the current folder path as the default
        Save-DefaultFolderConfig -Path $configFilePath -FolderPath $folderTextBox.Text
    }
    # Optional: else { # Logic to remove the default if unchecked - currently does nothing }

    # --- Store results in script scope and close the window ---
    $script:UserUrl = $urlTextBox.Text
    $script:DestinationFolder = $folderTextBox.Text
    $window.DialogResult = $true # Set DialogResult to true to indicate OK was clicked
    $window.Close()
})

# Cancel Button Click Event is implicitly handled by IsCancel="True" in XAML, which sets DialogResult to false and closes the window.

# --- Show the Dialog and wait for user interaction ---
# $window.ShowDialog() returns $true if OK was clicked, $false if Cancel/Closed.
$dialogResult = $window.ShowDialog()

#endregion WPF GUI Setup

#region Main Download Logic

# Proceed only if the user clicked OK ($true) and provided valid input
if ($dialogResult -ne $true) {
    Write-Host "Operation cancelled by user."
    exit 0 # Exit the script cleanly
}

# --- Helper Functions ---

# Function to sanitize a string for use as a *folder* name
# Replaces invalid characters with underscores.
function Sanitize-FolderName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    # Get characters invalid for file names
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $regexInvalidChars = [regex]::Escape($invalidChars)
    # Replace invalid characters with an underscore
    $sanitizedName = $Name -replace "[$regexInvalidChars]", '_'
    # Remove leading/trailing whitespace and dots
    $sanitizedName = $sanitizedName.Trim().Trim('.')
    # Replace multiple consecutive underscores with a single one
    $sanitizedName = $sanitizedName -replace '_+', '_'
    # Ensure the name is not empty after sanitization
    if ([string]::IsNullOrWhiteSpace($sanitizedName)) {
        return "Untitled-Mix" # Generic fallback name
    }
    return $sanitizedName
}

# Function to sanitize a string for use as an *XML filename*
# Replaces spaces with hyphens and removes other invalid characters.
function Sanitize-XmlFilename {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    # Replace one or more whitespace characters with a single hyphen
    $sanitizedName = $Name.Trim() -replace '\s+', '-'
    # Get invalid filename characters, but *exclude* the hyphen
    $invalidChars = ([System.IO.Path]::GetInvalidFileNameChars() | Where-Object { $_ -ne '-' }) -join ''
    $regexInvalidChars = [regex]::Escape($invalidChars)
    # Remove other invalid characters entirely
    $sanitizedName = $sanitizedName -replace "[$regexInvalidChars]", ''
    # Remove leading/trailing hyphens and dots
    $sanitizedName = $sanitizedName.Trim('-').Trim('.')
    # Replace multiple consecutive hyphens with a single one
    $sanitizedName = $sanitizedName -replace '-+', '-'
    # Ensure the name is not empty after sanitization
    if ([string]::IsNullOrWhiteSpace($sanitizedName)) {
        return "untitled-mix" # Generic fallback name
    }
    # Convert to lowercase for consistency
    return $sanitizedName.ToLowerInvariant()
}


# Function to download a file from a URL to a specified path
function Download-File {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    $webClient = $null # Initialize to null for finally block
    try {
        Write-Host "Downloading `"$($Url)`" to `"$($OutputPath)`"..."
        $webClient = New-Object System.Net.WebClient
        # Add a user agent header to mimic a browser
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36")

        # Ensure the target directory exists before downloading
        $directory = [System.IO.Path]::GetDirectoryName($OutputPath)
        if (-not (Test-Path -Path $directory -PathType Container)) {
            try {
                # Create the directory if it doesn't exist
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
                Write-Host "Created directory: $directory"
            } catch {
                Write-Error "Failed to create directory '$directory': $($_.Exception.Message)"
                return $false # Cannot download if directory cannot be created
            }
        }

        # Perform the download
        $webClient.DownloadFile($Url, $OutputPath)
        Write-Host "Successfully downloaded `"$($OutputPath)`"."
        return $true
    } catch {
        # --- Enhanced Error Reporting ---
        Write-Warning "Failed to download `"$($Url)`"."
        # Log the full exception details
        Write-Warning ($_.Exception | Format-List * -Force | Out-String)

        # Check if it's a WebException to get more details like HTTP status
        if ($_.Exception -is [System.Net.WebException]) {
            $webException = $_.Exception
            if ($webException.Response -ne $null) {
                $httpResponse = $webException.Response -as [System.Net.HttpWebResponse]
                if ($httpResponse -ne $null) {
                    Write-Warning "HTTP Status Code: $($httpResponse.StatusCode) ($([int]$httpResponse.StatusCode))"
                    Write-Warning "HTTP Status Description: $($httpResponse.StatusDescription)"
                }
                # Attempt to read the response body for server error messages
                try {
                    $responseStream = $webException.Response.GetResponseStream()
                    if ($responseStream -ne $null -and $responseStream.CanRead) {
                        # Use StreamReader with appropriate encoding (try UTF8 first)
                        $streamReader = New-Object System.IO.StreamReader($responseStream, [System.Text.Encoding]::UTF8)
                        $responseBody = $streamReader.ReadToEnd()
                        $streamReader.Dispose() # Dispose reader
                        $responseStream.Dispose() # Dispose stream
                        if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                             Write-Warning "Response Body Snippet: $($responseBody.Substring(0, [System.Math]::Min($responseBody.Length, 500)))..."
                        }
                    }
                } catch {
                     Write-Warning "Could not read error response body: $($_.Exception.Message)"
                } finally {
                     # Ensure response is disposed even if reading body fails
                    if ($webException.Response -ne $null) {
                        try { $webException.Response.Dispose() } catch {}
                    }
                }
            } else {
                 Write-Warning "No HTTP response received (e.g., DNS error, connection refused)."
            }
        }

        # Clean up partially downloaded file if it exists
        if (Test-Path -Path $OutputPath -PathType Leaf) {
            try {
                Remove-Item -Path $OutputPath -Force -ErrorAction SilentlyContinue
                Write-Warning "Removed partially downloaded file: $OutputPath"
            } catch {
                Write-Warning "Could not remove partially downloaded file '$OutputPath': $($_.Exception.Message)"
            }
        }
        return $false
    } finally {
        # Dispose the WebClient object to release resources
        if ($webClient -ne $null) { $webClient.Dispose() }
    }
}

# Function to:
# 1. Determine the XML URL, mix name, description, and image URL from the input page URL.
# 2. Create the mix-specific destination folder.
# 3. Download the initial XML file to that folder.
# Returns a PSCustomObject with the gathered data or $null on failure.
function Get-MixDataAndXmlFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputUrl,
        [Parameter(Mandatory=$true)]
        [string]$BaseDestinationFolder # The root folder selected by the user
    )

    $templateUrlBase = "http://xml.ambient-mixer.com/audio-template?player=html5&id_template="
    $xmlUrl = $null
    $templateId = $null
    $mixName = $null
    $imageUrl = $null
    $description = $null # Added description variable
    $pageUrl = $InputUrl

    # Check if the provided URL is the direct XML URL (less common use case)
    if ($InputUrl -like "$($templateUrlBase)*") {
        Write-Host "Input URL appears to be a direct XML link."
        $xmlUrl = $InputUrl
        # Extract template ID from the URL
        $templateId = ($InputUrl -split 'id_template=')[-1]
        # Use ID for name/desc as fallback since we can't get them from the XML URL
        $mixName = $templateId
        $description = "Description not available from direct XML link."
        Write-Host "Using Template ID '$templateId' as mix name."
        Write-Warning "Cannot fetch mix name, description, or preview image when provided with a direct XML URL."
    } else {
        # Input is likely the HTML page URL, proceed to scrape data
        Write-Host "Input URL is not a direct XML link. Attempting to find template ID, mix name, description, and image URL..."
        $webClient = $null
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36")
            # Specify UTF8 encoding for downloading the page content
            $webClient.Encoding = [System.Text.Encoding]::UTF8
            $pageContent = $webClient.DownloadString($pageUrl)

            # --- Extract Template ID ---
            # Use regex to find "AmbientMixer.setup(ID);" in the page source
            $regexSetup = [regex]'AmbientMixer\.setup\(([0-9]+)\);'
            $matchSetup = $regexSetup.Match($pageContent)

            if ($matchSetup.Success) {
                $templateId = $matchSetup.Groups[1].Value
                $xmlUrl = $templateUrlBase + $templateId
                Write-Host "Found Template ID: $templateId. XML URL: $xmlUrl"
            } else {
                # Critical error if template ID cannot be found
                Write-Error "Could not find AmbientMixer.setup() call with template ID on the page: $pageUrl"
                return $null # Cannot proceed without template ID
            }

            # --- Extract Mix Name ---
            # Prioritize H1 tag for the name
            $regexH1 = [regex]::Match($pageContent, '<h1.*?>(.*?)</h1>', 'IgnoreCase')
            if ($regexH1.Success -and (-not [string]::IsNullOrWhiteSpace($regexH1.Groups[1].Value))) {
                # Decode HTML entities (like &amp;) and trim whitespace
                $mixName = [System.Net.WebUtility]::HtmlDecode($regexH1.Groups[1].Value.Trim())
                Write-Host "Found Mix Name from H1: $mixName"
            } else {
                # Fallback to Title tag if H1 is missing or empty
                Write-Host "H1 tag not found or empty. Falling back to Title tag..."
                $regexTitle = [regex]::Match($pageContent, '<title>(.*?)</title>', 'IgnoreCase')
                if ($regexTitle.Success) {
                    $rawTitle = [System.Net.WebUtility]::HtmlDecode($regexTitle.Groups[1].Value.Trim())
                    # Clean up common title format "Mix Name - Ambient Mixer"
                    $mixName = ($rawTitle -split ' - Ambient Mixer')[0].Trim()
                    # If split fails or results in empty string, use the raw title
                    if ([string]::IsNullOrWhiteSpace($mixName)) { $mixName = $rawTitle }
                    Write-Host "Found Mix Name from Title: $mixName"
                } else {
                    # Final fallback to Template ID if both H1 and Title fail
                    Write-Warning "Could not find H1 or Title tag. Using Template ID '$templateId' for name."
                    $mixName = $templateId
                }
            }

            # --- Extract Description ---
            # Use regex to find og:description meta tag
            $regexDesc = [regex]::Match($pageContent, '<meta\s+property=["'']og:description["'']\s+content=["''](.*?)["'']', 'IgnoreCase')
            if ($regexDesc.Success) {
                 # Decode HTML entities and trim
                 $description = [System.Net.WebUtility]::HtmlDecode($regexDesc.Groups[1].Value.Trim())
                 Write-Host "Found Description: $($description.Substring(0,[System.Math]::Min($description.Length, 100)))..." # Log snippet
            } else {
                 # If tag not found, set a default message
                 Write-Warning "Could not find og:description meta tag on the page."
                 $description = "No description found."
            }

            # --- Extract Image URL ---
            # Use regex to find og:image meta tag
            $regexImage = [regex]::Match($pageContent, '<meta\s+property=["'']og:image["'']\s+content=["''](.*?)["'']', 'IgnoreCase')
            if ($regexImage.Success) {
                # Decode HTML entities (less common in URLs but possible) and trim
                $imageUrl = [System.Net.WebUtility]::HtmlDecode($regexImage.Groups[1].Value.Trim())
                Write-Host "Found Image URL: $imageUrl"
            } else {
                # Image is optional, just warn if not found
                Write-Warning "Could not find og:image meta tag on the page."
            }

        } catch {
            # Handle errors during page download or parsing
            Write-Error "Failed to download or parse the HTML page `"$($pageUrl)`": $($_.Exception.Message)"
            # If page download fails but we already had a direct XML URL (unlikely scenario)
            if ($xmlUrl -ne $null -and $templateId -ne $null) {
                Write-Warning "Using Template ID '$templateId' for name/folder due to page download error."
                $mixName = $templateId # Fallback name
                $description = "Description fetch failed due to page download error." # Fallback description
                # Image URL cannot be determined in this case
            } else {
                return $null # Critical failure if we couldn't get template ID
            }
        } finally {
             # Ensure WebClient is disposed
             if ($webClient -ne $null) { $webClient.Dispose() }
        }
    }

    # --- Create Destination Folder ---
    # Sanitize the mix name for use as the *folder* name
    $mixFolderName = Sanitize-FolderName -Name $mixName
    if ([string]::IsNullOrWhiteSpace($mixFolderName)) {
        # If sanitization results in an empty string, use a fallback with the ID
        Write-Warning "Folder name became empty after sanitization, using fallback 'mix-$templateId'."
        $mixFolderName = "mix-$templateId"
    }

    # Define the full path for the mix-specific folder
    $mixFolderPath = Join-Path -Path $BaseDestinationFolder -ChildPath $mixFolderName
    Write-Host "Target Mix Folder: $mixFolderPath"

    # Create the mix-specific folder if it doesn't exist
    if (-not (Test-Path -Path $mixFolderPath -PathType Container)) {
        try {
            New-Item -Path $mixFolderPath -ItemType Directory -Force | Out-Null
            Write-Host "Created mix folder: $mixFolderPath"
        } catch {
            Write-Error "Failed to create mix folder '$mixFolderPath': $($_.Exception.Message)"
            return $null # Cannot proceed if folder creation fails
        }
    }

    # --- Download XML File ---
    # Define the *XML filename* using the sanitized *title*
    $xmlBaseFilename = Sanitize-XmlFilename -Name $mixName
    if ([string]::IsNullOrWhiteSpace($xmlBaseFilename)) {
        # Fallback to template ID if title sanitization fails
        Write-Warning "XML base filename became empty after sanitization, using template ID '$templateId'."
        $xmlBaseFilename = $templateId
    }
    $xmlFilename = "$($xmlBaseFilename).xml"
    $xmlFilePath = Join-Path -Path $mixFolderPath -ChildPath $xmlFilename

    # Download the XML file using the helper function
    if (Download-File -Url $xmlUrl -OutputPath $xmlFilePath) {
        # Return an object containing all gathered paths and data
        return [PSCustomObject]@{
            XmlFilePath     = $xmlFilePath      # Full path to the downloaded XML
            MixFolderPath   = $mixFolderPath    # Full path to the created mix folder
            MixName         = $mixName          # Original mix name (before sanitization)
            MixDescription  = $description      # Fetched description
            ImageUrl        = $imageUrl         # Fetched image URL (can be $null)
        }
    } else {
        # If XML download fails, report error and return null
        Write-Error "Failed to download the XML file from '$xmlUrl' to '$xmlFilePath'"
        # Optional: Clean up the created folder if the XML download fails
        # if (Test-Path -Path $mixFolderPath -PathType Container) {
        #    try { Remove-Item $mixFolderPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        # }
        return $null
    }
}

# Function to:
# 1. Parse the downloaded XML file.
# 2. Create the 'audio' subfolder.
# 3. Iterate through channels, extract sound URL and name.
# 4. Download each sound file into the 'audio' subfolder, renaming it based on the sanitized sound name.
# Returns an object with download status and a mapping of original URLs to new relative paths.
function Download-SoundsFromXml {
    param(
        [Parameter(Mandatory=$true)]
        [string]$XmlFilePath,       # Path to the downloaded XML file
        [Parameter(Mandatory=$true)]
        [string]$TargetMixFolder    # Path to the specific folder for this mix
    )

    # --- Create Audio Subfolder ---
    $audioFolderPath = Join-Path -Path $TargetMixFolder -ChildPath "audio"
    if (-not (Test-Path -Path $audioFolderPath -PathType Container)) {
        try {
            New-Item -Path $audioFolderPath -ItemType Directory -Force | Out-Null
            Write-Host "Created audio subfolder: $audioFolderPath"
        } catch {
            Write-Error "Failed to create audio subfolder '$audioFolderPath': $($_.Exception.Message)"
            # Return failure object if audio folder cannot be created
            return [PSCustomObject]@{ SuccessStatus = $false; FileMapping = @{} }
        }
    }

    # --- Load XML Document ---
    try {
        # Load XML content, specifying UTF8 encoding
        [xml]$xmlDoc = Get-Content -Path $XmlFilePath -Raw -Encoding UTF8
    } catch {
        Write-Error "Failed to read or parse XML file '$XmlFilePath': $($_.Exception.Message)"
        return [PSCustomObject]@{ SuccessStatus = $false; FileMapping = @{} } # Indicate failure
    }

    # Check if the XML was loaded and parsed correctly
    if ($xmlDoc -eq $null -or $xmlDoc.DocumentElement -eq $null) {
        Write-Error "XML file '$XmlFilePath' could not be parsed correctly or is empty."
        return [PSCustomObject]@{ SuccessStatus = $false; FileMapping = @{} } # Indicate failure
    }

    # --- Initialize Counters and Mapping ---
    $downloadSuccessCount = 0
    $downloadFailCount = 0
    $alreadyExistsCount = 0
    # Hashtable to store mapping: @{ OriginalURL = "NewRelativePath" }
    $fileMapping = @{}

    # --- Iterate Through Channels (1 to 8) ---
    for ($i = 1; $i -le 8; $i++) {
        # Initialize variables for each channel iteration
        $channelNode = $null; $idNode = $null; $urlNode = $null; $nameNode = $null
        $soundId = $null; $soundUrl = $null; $soundName = $null
        try {
            # Use XPath to select the node for the current channel
            $channelXPath = "/audio_template/channel$i"
            $channelNode = $xmlDoc.SelectSingleNode($channelXPath)

            # Proceed only if the channel node exists
            if ($channelNode -ne $null) {
                # Use XPath relative to the channel node to find child elements
                $idNode = $channelNode.SelectSingleNode("id_audio")     # Still needed for uniqueness fallback if name is empty
                $urlNode = $channelNode.SelectSingleNode("url_audio")
                $nameNode = $channelNode.SelectSingleNode("name_audio") # Node containing the sound's name

                # Check if essential nodes were found AND their InnerText content is not empty/whitespace
                if ($idNode -ne $null -and $urlNode -ne $null -and $nameNode -ne $null `
                   -and (-not [string]::IsNullOrWhiteSpace($idNode.InnerText)) `
                   -and (-not [string]::IsNullOrWhiteSpace($urlNode.InnerText)) `
                   -and (-not [string]::IsNullOrWhiteSpace($nameNode.InnerText)) )
                {
                    # Access InnerText directly and trim whitespace
                    $soundId = $idNode.InnerText.Trim()     # Keep ID for fallback/logging
                    $soundUrl = $urlNode.InnerText.Trim()
                    $soundName = $nameNode.InnerText.Trim() # Get sound name

                    # Re-check after trimming, just in case InnerText was only whitespace
                    # Ensure both URL and Name are valid before proceeding
                    if (-not ([string]::IsNullOrWhiteSpace($soundUrl) -or [string]::IsNullOrWhiteSpace($soundName))) {

                        # --- Determine Filename and Path ---
                        # Extract file extension from URL
                        $extension = [System.IO.Path]::GetExtension($soundUrl)
                        if ([string]::IsNullOrWhiteSpace($extension)) {
                            # Cannot save without an extension
                            Write-Warning "Could not determine file extension for URL in Channel ${i}: $soundUrl. Skipping download."
                            $downloadFailCount++; continue # Skip to next channel
                        }

                        # Construct filename using sanitized *sound name*
                        # Use Sanitize-FolderName for audio files as they might have various chars
                        $baseFilename = Sanitize-FolderName -Name $soundName
                        # Fallback to sanitized ID if name sanitization results in empty string
                        if ([string]::IsNullOrWhiteSpace($baseFilename)) {
                             Write-Warning "Sound name '$soundName' sanitized to empty string for Channel ${i}. Falling back to sanitized ID '$soundId'."
                             $baseFilename = Sanitize-FolderName -Name $soundId
                             # Final fallback if both are empty after sanitization
                             if ([string]::IsNullOrWhiteSpace($baseFilename)) {
                                 Write-Warning "Both Name and ID sanitized to empty string for Channel ${i}. Using 'channel_${i}_sound'."
                                 $baseFilename = "channel_${i}_sound"
                             }
                        }
                        $targetFilename = "$($baseFilename)$($extension)"
                        # Full path for the target audio file
                        $targetFilePath = Join-Path -Path $audioFolderPath -ChildPath $targetFilename
                        # Define the new relative path for the XML update (use forward slashes for better cross-platform compatibility if XML is used elsewhere)
                        $newRelativePath = "audio/$targetFilename"

                        # --- Download or Skip File ---
                        # Check if the specific target file already exists
                        if (Test-Path -Path $targetFilePath -PathType Leaf) {
                            Write-Host "Sound file '$targetFilename' for Channel ${i} already exists. Skipping download."
                            $alreadyExistsCount++
                            # Add mapping even if skipped, as the file exists at the target location and path needs update in XML
                            $fileMapping[$soundUrl] = $newRelativePath
                        } else {
                            # Download the sound file using the helper function
                            if (Download-File -Url $soundUrl -OutputPath $targetFilePath) {
                                $downloadSuccessCount++
                                # Add mapping only on successful download
                                $fileMapping[$soundUrl] = $newRelativePath
                            } else {
                                # Error message is handled within Download-File
                                $downloadFailCount++
                            }
                        }
                    } else {
                        # Log if skipping due to empty URL or Name after trimming
                        Write-Warning "Channel ${i}: Skipping due to empty SoundName ('$soundName') or SoundURL ('$soundUrl') after trimming InnerText."
                        $downloadFailCount++
                    }
                } else {
                    # Log if essential child nodes (id, url, name) are missing or empty within the channel node
                    # Write-Verbose "[Debug] Channel ${i}: Skipping channel - id_audio, url_audio, or name_audio node missing or empty."
                }
            } else {
                # Log if the channel node itself is not found (e.g., mix uses fewer than 8 channels)
                # Write-Verbose "[Debug] Channel ${i}: Channel node not found in XML."
            }
        } catch {
            # Catch potential errors during node access or processing for a specific channel
             Write-Warning "[Error] Error processing Channel ${i}: $($_.Exception.Message)"
             $downloadFailCount++ # Count this as a failure for the summary
        }
    } # End for loop (channels 1-8)

    # --- Report Summary ---
    Write-Host "-----------------------------------------"
    Write-Host "Sound Download Summary:"
    Write-Host "Successfully downloaded: $downloadSuccessCount"
    Write-Host "Already existed:       $alreadyExistsCount"
    Write-Host "Failed to download:    $downloadFailCount"
    Write-Host "-----------------------------------------"

    # --- Return Result Object ---
    # Return object containing overall success status and the URL mapping
    return [PSCustomObject]@{
        SuccessStatus = ($downloadFailCount -eq 0) # True only if NO failures occurred
        FileMapping   = $fileMapping              # Hashtable of OriginalUrl -> NewRelativePath
    }
}

# Function to:
# 1. Reload the XML file.
# 2. Update the <url_audio> paths based on the provided mapping.
# 3. Remove the <id_template>, <id_session_user>, <id_session_player> elements.
# 4. Add <title> and <description> elements using data from MixData object.
# 5. Save the modified XML file with pretty printing.
function Finalize-XmlFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$XmlFilePath,           # Path to the XML file to modify
        [Parameter(Mandatory=$true)]
        [hashtable]$FileMapping,        # Hashtable @{ OriginalUrl = "NewRelativePath" }
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$MixData        # Object containing MixName and MixDescription
    )

    Write-Host "Finalizing XML file '$XmlFilePath'..."
    $xmlWriter = $null # Initialize XmlWriter variable for the finally block

    try {
        # --- Load XML Document ---
        [xml]$xmlDoc = Get-Content -Path $XmlFilePath -Raw -Encoding UTF8
        if ($xmlDoc -eq $null -or $xmlDoc.DocumentElement -eq $null) {
            Write-Error "XML file '$XmlFilePath' could not be re-parsed correctly for finalization."
            return $false
        }
        # Get the root element (should be <audio_template>)
        $rootNode = $xmlDoc.DocumentElement

        # --- 1. Update Sound File Paths ---
        $updateCount = 0
        if ($FileMapping.Count -gt 0) {
            Write-Host "Updating sound file paths..."
            for ($i = 1; $i -le 8; $i++) {
                $urlNode = $null
                try {
                    # Select the url_audio node for the current channel using absolute XPath
                    $urlNode = $xmlDoc.SelectSingleNode("/audio_template/channel$i/url_audio")
                    if ($urlNode -ne $null) {
                        $originalUrl = $urlNode.InnerText.Trim() # Get the current URL
                        # Check if this original URL is in our mapping (meaning it was downloaded/found)
                        if (-not [string]::IsNullOrWhiteSpace($originalUrl) -and $FileMapping.ContainsKey($originalUrl)) {
                            $newRelativePath = $FileMapping[$originalUrl]
                            # Update the node's content with the new relative path
                            $urlNode.InnerText = $newRelativePath
                            Write-Verbose "  Updated Channel ${i}: '$originalUrl' -> '$newRelativePath'"
                            $updateCount++
                        } elseif (-not [string]::IsNullOrWhiteSpace($originalUrl)) {
                            # Log if a URL was found but not in the map (e.g., download failed for it)
                            Write-Verbose "  Skipping Channel ${i}: Original URL '$originalUrl' not found in successful download map."
                        }
                    }
                } catch { Write-Warning "Error processing URL node for Channel ${i} during update: $($_.Exception.Message)" }
            } # End for loop (channels)
             Write-Host "Updated $updateCount URL(s)."
        } else {
            Write-Host "No file mappings provided; skipping path update."
        }

        # --- 2. Remove Unwanted Elements ---
        Write-Host "Removing unwanted elements..."
        $elementsToRemove = @("id_template", "id_session_user", "id_session_player")
        $removedCount = 0
        foreach ($elementName in $elementsToRemove) {
            # Select the node to remove using absolute XPath
            $nodeToRemove = $xmlDoc.SelectSingleNode("/audio_template/$elementName")
            if ($nodeToRemove -ne $null) {
                try {
                    # Remove the node from its parent
                    $nodeToRemove.ParentNode.RemoveChild($nodeToRemove) | Out-Null
                    Write-Verbose "  Removed element: <$elementName>"
                    $removedCount++
                } catch {
                    Write-Warning "Could not remove element '$elementName': $($_.Exception.Message)"
                }
            } else {
                # Log if the element wasn't found anyway
                Write-Verbose "  Element not found, skipping removal: <$elementName>"
            }
        }
        Write-Host "Removed $removedCount element(s)."

        # --- 3. Add/Update Title and Description Elements ---
        Write-Host "Adding/Updating <title> and <description> elements..."
        try {
            # --- Title Element ---
            $titleNode = $xmlDoc.SelectSingleNode("/audio_template/title")
            if ($titleNode -eq $null) {
                # Create and append if it doesn't exist
                $titleElement = $xmlDoc.CreateElement("title")
                $titleElement.InnerText = $MixData.MixName
                $rootNode.AppendChild($titleElement) | Out-Null
                Write-Verbose "  Added <title>: $($MixData.MixName)"
            } else {
                # Update the existing node's text
                $titleNode.InnerText = $MixData.MixName
                 Write-Verbose "  Updated <title>: $($MixData.MixName)"
            }

            # --- Description Element ---
            $descNode = $xmlDoc.SelectSingleNode("/audio_template/description")
             if ($descNode -eq $null) {
                # Create and append if it doesn't exist
                $descElement = $xmlDoc.CreateElement("description")
                # Using InnerText is usually fine, but CDATA is safer if description might contain XML special chars
                # $cdataDesc = $xmlDoc.CreateCDataSection($MixData.MixDescription)
                # $descElement.AppendChild($cdataDesc) | Out-Null
                $descElement.InnerText = $MixData.MixDescription
                $rootNode.AppendChild($descElement) | Out-Null
                Write-Verbose "  Added <description>: $($MixData.MixDescription.Substring(0,[System.Math]::Min($MixData.MixDescription.Length, 50)))..."
             } else {
                 # Update the existing node's text
                 $descNode.InnerText = $MixData.MixDescription
                 Write-Verbose "  Updated <description>: $($MixData.MixDescription.Substring(0,[System.Math]::Min($MixData.MixDescription.Length, 50)))..."
             }

            Write-Host "Added/Updated title and description."
        } catch {
            Write-Warning "Failed to add/update title or description elements: $($_.Exception.Message)"
        }

        # --- 4. Save the Modified XML Document ---
        # Configure XML writer settings for pretty printing
        $xmlWriterSettings = New-Object System.Xml.XmlWriterSettings
        $xmlWriterSettings.Indent = $true             # Enable indentation
        $xmlWriterSettings.IndentChars = "  "         # Use 2 spaces for indentation
        $xmlWriterSettings.NewLineChars = "`r`n"      # Use Windows line endings (CRLF)
        # Use UTF8 encoding *without* the Byte Order Mark (BOM) for better compatibility
        $xmlWriterSettings.Encoding = [System.Text.UTF8Encoding]::new($false)

        # Create the XmlWriter using the specified path and settings
        $xmlWriter = [System.Xml.XmlWriter]::Create($XmlFilePath, $xmlWriterSettings)
        # Save the XML document using the writer
        $xmlDoc.Save($xmlWriter)
        # XmlWriter is closed in the 'finally' block

        Write-Host "Successfully finalized and saved XML file '$XmlFilePath'."
        return $true

    } catch {
        # Catch any errors during the finalization process
        Write-Error "Failed during XML finalization process for '$XmlFilePath': $($_.Exception.Message)"
        return $false
    } finally {
         # Ensure the XmlWriter is closed to flush content and release the file lock
         if ($xmlWriter -ne $null) {
             try { $xmlWriter.Close() } catch { Write-Warning "Error closing XML writer for '$XmlFilePath'." }
         }
    }
}


# --- Main Execution Block ---

Write-Host "Starting Ambient Mixer Download..."
Write-Host "User URL: $script:UserUrl"
Write-Host "Selected Destination Folder: $script:DestinationFolder"
Write-Host "-----------------------------------------"

# Step 1: Get Mix Data (Name, Folder Path, Image URL, Description) and download the initial XML file
# This function handles finding the XML URL, scraping the page, creating the folder, and downloading the raw XML.
$mixData = Get-MixDataAndXmlFile -InputUrl $script:UserUrl -BaseDestinationFolder $script:DestinationFolder

# Step 2: Proceed only if Mix Data was obtained and the initial XML file exists
if ($mixData -ne $null -and (-not [string]::IsNullOrWhiteSpace($mixData.XmlFilePath)) -and (Test-Path $mixData.XmlFilePath -PathType Leaf)) {
    Write-Host "Successfully obtained initial XML file: $($mixData.XmlFilePath)"
    Write-Host "Mix Name: $($mixData.MixName)"
    Write-Host "Mix Folder: $($mixData.MixFolderPath)"
    Write-Host "Mix Description: $($mixData.MixDescription.Substring(0,[System.Math]::Min($mixData.MixDescription.Length, 100)))..." # Log snippet

    # Step 3: Download the preview image if a URL was found
    if (-not [string]::IsNullOrWhiteSpace($mixData.ImageUrl)) {
        Write-Host "-----------------------------------------"
        Write-Host "Starting preview image download..."
        # Determine image filename (e.g., cover.jpg)
        $imageExtension = [System.IO.Path]::GetExtension($mixData.ImageUrl)
        # Basic sanity check for extension, default to .jpg if missing or weird
        if ([string]::IsNullOrWhiteSpace($imageExtension) -or $imageExtension.Length -gt 5) { $imageExtension = ".jpg" }
        $imageFilename = "cover$($imageExtension)"
        $imageOutputPath = Join-Path -Path $mixData.MixFolderPath -ChildPath $imageFilename
        # Attempt download using the helper function
        if (Download-File -Url $mixData.ImageUrl -OutputPath $imageOutputPath) {
             Write-Host "Successfully downloaded preview image."
        } else {
             Write-Warning "Failed to download preview image from $($mixData.ImageUrl)."
        }
    } else {
         # Log if no image URL was found during scraping
         Write-Host "No preview image URL found to download."
    }

    # Step 4: Download the sound files based on the initial XML
    # This function parses the XML, downloads sounds to the 'audio' subfolder, and returns status/mapping.
    Write-Host "-----------------------------------------"
    Write-Host "Starting sound file download..."
    $downloadResult = Download-SoundsFromXml -XmlFilePath $mixData.XmlFilePath -TargetMixFolder $mixData.MixFolderPath

    # Report overall sound download status
    if ($downloadResult.SuccessStatus) {
         Write-Host "Sound download process completed successfully (or all files already existed)."
    } else {
         Write-Warning "Sound download process completed with one or more errors."
    }

    # Step 5: Finalize the XML file (Update paths, cleanup elements, add title/desc)
    # Ensure mixData is still valid before proceeding (should be, but good practice)
    if($mixData -ne $null) {
        Write-Host "-----------------------------------------"
        # This function modifies the XML in place.
        if (Finalize-XmlFile -XmlFilePath $mixData.XmlFilePath -FileMapping $downloadResult.FileMapping -MixData $mixData) {
            Write-Host "XML finalization process completed successfully."
        } else {
            Write-Warning "XML finalization process encountered errors."
        }
    } else {
        # This case should ideally not happen if Step 1 succeeded
        Write-Error "Mix data became invalid before XML finalization step. Aborting finalization."
    }


    Write-Host "-----------------------------------------"
    Write-Host "Overall download process completed for mix '$($mixData.MixName)'."
    Write-Host "Files saved in: $($mixData.MixFolderPath)"

} else {
    # This block executes if Get-MixDataAndXmlFile failed (returned $null or XML path invalid)
    Write-Error "Could not obtain the initial XML file or determine mix folder. Aborting download process."
}

Write-Host "Script finished."

# Optional: Pause at the end if running directly from explorer double-click (ConsoleHost)
# Check if running in a console window before pausing
# if ($Host.Name -eq "ConsoleHost") {
#    Read-Host -Prompt "Press Enter to exit"
# }

#endregion Main Download Logic

