<#
.SYNOPSIS
    Parses an ExifTool error log OR scans a folder, validates images, and attempts to fix
    metadata errors using specific strategies based on the identified errors.
    Attempts to fix ALL files with any detected error/warning (except MP4s).
    Provides GUI prompts for user choices.

.DESCRIPTION
    This script performs the following actions:
    1. Prompts the user via GUI to load an ExifTool error log file or scan a folder.
    2. IF LOADING LOG FILE:
        a. Displays a file selection dialog.
        b. Parses the log file to identify files and their associated errors.
        c. **Excludes any `.mp4` files found in the log.**
    3. IF SCANNING FOLDER:
        a. Displays a folder selection dialog.
        b. Prompts the user via GUI whether to include subdirectories.
        c. Scans the selected folder (and optionally subfolders) for common image file types.
        d. Runs `exiftool -m -validate -warning -error -a` on each found file.
        e. Parses the validation output to identify files with errors and their specific error messages.
    4. Creates a unified list of non-MP4 files needing fixes and their associated errors (from log or validation). Files passing validation are skipped.
    5. Checks if any files require processing.
    6. Prompts the user via GUI to choose between automatic fixing for all files or per-file confirmation.
    7. Prompts the user via GUI to choose whether to overwrite original files or create backups.
    8. Iterates through each file identified for fixing.
    9. Determines the appropriate fix command(s) based on error types:
        - General Rebuild (`-all= -tagsfromfile @ -all -unsafe`) is performed FIRST if OtherStructural errors OR MissingRequired errors exist.
        - MakerNote Removal (`-makernotes:all=`) is performed SECOND only if MakerNote errors exist (depends on General Rebuild success if applicable).
        - IPTCDigest Update (`-IPTCDigest=new`) is performed LAST only if IPTCDigest errors exist (depends on the success of the preceding step).
        - If ONLY MakerNote errors exist, only MakerNote removal is run.
        - If ONLY IPTCDigest errors exist, only IPTCDigest update is run.
   10. Executes the determined ExifTool command(s).
   11. Displays a progress bar and status updates.
   12. Outputs a final summary, including files skipped due to successful validation or being MP4.

.NOTES
    Author: Adromir
    Date: 2025-05-02
    Requires:
        - Windows PowerShell 5.1+
        - ExifTool (exiftool.exe) must be installed and accessible in the system's PATH.
        - .NET Framework (for GUI elements)
    Image Types Scanned (if not using log): .jpg, .jpeg, .png, .dng, .cr2, .nef, .arw, .orf, .rw2, .tiff, .tif

.LINK
    ExifTool Website: https://exiftool.org/

.EXAMPLE
    .\fix-metadata.ps1
    (Starts the script and GUI prompts)
#>

#Requires -Version 5.1

# --- Configuration ---
$ErrorActionPreference = 'Stop' # Stop on critical errors unless handled locally
$LogFileNamePattern = "exif_errors.log"
$ExifToolPath = "exiftool" # Assumes exiftool is in PATH. Change if necessary (e.g., "C:\path\to\exiftool.exe")
# Common image file extensions to scan if not using a log file (MP4 explicitly excluded)
$ImageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.dng", "*.cr2", "*.nef", "*.arw", "*.orf", "*.rw2", "*.tiff", "*.tif")

# Patterns for errors considered "MakerNote issues"
$MakerNoteErrorPatterns = @(
    '*Unrecognized MakerNotes*',
    '*Not decoding some large array*',
    '*MakerNote*unknown*',
    '*Invalid MakerNote*entry*'
)
# Pattern for IPTC Digest error
$IPTCDigestErrorPattern = '*IPTCDigest is not current*'

# Patterns for "Missing Required" tags - These will trigger General Rebuild if they are the ONLY error type found.
$MissingRequiredPatterns = @(
    '*Missing required*tag 0x9101 ComponentsConfiguration*',
    '*Missing required*tag 0xa002 ExifImageWidth*',
    '*Missing required*tag 0xa003 ExifImageHeight*',
    '*Missing required*tag 0x0213 YCbCrPositioning*'
)

# Patterns for other significant structural or formatting errors that DO trigger the general rebuild command FIRST.
$OtherStructuralErrorPatterns = @(
    '*Wrong IFD*',
    '*Invalid*value*', # Catches various invalid value errors including GPSProcessingMethod
    '*Bad*offset*',
    '*Directory*out of sequence*',
    '*Tag*not defined*',
    '*Error reading*directory*',
    '*Format error*',
    '*Boolean value for XMP*should be capitalized*',
    '*Non-standard ExifIFD tag*', # Broadened to catch any non-standard tag warning like TimeZoneOffset
    '*requires ExifVersion*'      # Catches all ExifVersion requirement warnings
)


# --- Function Definitions ---

# Function to display GUI message boxes
function Show-GuiMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    # Assembly should be loaded globally now, but keep for function portability
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

# Function to display GUI file open dialog
function Get-GuiOpenFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Filter
    )
    # Assembly should be loaded globally now, but keep for function portability
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = $Title
    $openFileDialog.Filter = $Filter
    $openFileDialog.Multiselect = $false
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $openFileDialog.FileName
    } else {
        return $null
    }
}

# Function to display GUI folder browser dialog
function Get-GuiFolder {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    # Assembly should be loaded globally now, but keep for function portability
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowserDialog.Description = $Description
    if ($folderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderBrowserDialog.SelectedPath
    } else {
        return $null
    }
}


# Function to check if ExifTool is available
function Test-ExifTool {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ToolPath
    )
    $process = $null # Ensure $process is defined for finally block
    try {
        Write-Verbose "Checking for ExifTool at '$ToolPath'..."
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $ToolPath
        $processInfo.Arguments = "-ver"
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        $process.WaitForExit(5000) # Wait max 5 seconds

        if (-not $process.HasExited) {
             $process.Kill()
             throw "ExifTool process timed out."
        }

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()

        if ($process.ExitCode -eq 0 -and $stdout) {
            Write-Host "ExifTool found: Version $($stdout.Trim())" -ForegroundColor Green
            return $true
        } else {
            $errorMessage = "ExifTool command '$ToolPath -ver' failed or did not return a version.`nEnsure it's installed and in your PATH."
            if ($stderr) { $errorMessage += "`nError Output: $stderr" }
            if ($stdout) { $errorMessage += "`nStandard Output: $stdout" }
            # Use Write-Error for console, GUI message might not load if Forms assembly failed
            Write-Error $errorMessage
            # Show-GuiMessage $errorMessage "ExifTool Error" ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error)
            return $false
        }
    } catch {
        $errMsg = "Could not execute ExifTool command '$ToolPath'.`nPlease ensure ExifTool is installed and its location is correctly specified in the script or added to your system's PATH environment variable.`n`nError details: $($_.Exception.Message)"
        Write-Error $errMsg
        # Show-GuiMessage $errMsg "ExifTool Not Found" ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    } finally {
        # Ensure process object is disposed
        if ($process -ne $null) { $process.Dispose() }
    }
}

# Function to parse the ExifTool log file
function Parse-ExifLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogFilePath
    )
    Write-Host "Parsing log file: $LogFilePath"
    $fileErrors = @{} # Hashtable to store file paths and their list of errors
    $currentFile = $null
    $reader = $null # Initialize reader outside try
    $skippedMp4Count = 0
    try {
        # Using a StreamReader for potentially better memory usage on very large logs
        $reader = [System.IO.StreamReader]::new($LogFilePath)
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line -match '^\s*File:\s*(.+)') {
                $potentialPath = $matches[1].Trim()
                # Validate path format and existence (more robust check)
                $isValidPath = $false
                $isMp4 = $false
                try {
                    # Check if it looks like a drive path or UNC path and exists as a file
                    if (($potentialPath -match '^[a-zA-Z]:\\' -or $potentialPath -match '^\\\\') -and (Test-Path -Path $potentialPath -PathType Leaf -ErrorAction Stop)) {
                       $isValidPath = $true
                       # Check if it's an MP4 file
                       if ($potentialPath -like '*.mp4') {
                           $isMp4 = $true
                       }
                    }
                } catch {
                    # Test-Path threw an error (e.g., invalid characters, path too long), so path is invalid or inaccessible
                    $isValidPath = $false
                    Write-Verbose "Path validation failed for '$potentialPath': $($_.Exception.Message)"
                }

                if ($isValidPath -and -not $isMp4) {
                    $currentFile = $potentialPath
                    # Initialize the list only if the file path is valid and not MP4
                    $fileErrors[$currentFile] = [System.Collections.Generic.List[string]]::new()
                    Write-Verbose "Found valid image file in log: $currentFile"
                } elseif ($isValidPath -and $isMp4) {
                    Write-Warning "Skipping MP4 file found in log: '$potentialPath'."
                    $skippedMp4Count++
                    $currentFile = $null # Invalidate current file so errors aren't added
                } else {
                    Write-Warning "Invalid, non-existent, or inaccessible file path found in log: '$potentialPath'. Skipping this entry."
                    $currentFile = $null # Invalidate current file for subsequent error lines
                }
            }
            # Add error description only if currentFile is valid (not null, meaning not skipped MP4 or invalid path) and the key exists
            elseif ($currentFile -ne $null -and $fileErrors.ContainsKey($currentFile) -and $line -match '^\s+-\s+(.+)') {
                $errorDesc = $matches[1].Trim()
                # Clean up the error description slightly (remove leading/trailing brackets/spaces)
                $cleanedErrorDesc = $errorDesc -replace '^\[[^\]]+\]\s*|\s*\[x\d+\]$'
                $fileErrors[$currentFile].Add($cleanedErrorDesc.Trim())
                Write-Verbose "  Found error for '$currentFile': $($cleanedErrorDesc.Trim())"
            }
        }
    } catch {
         Show-GuiMessage "Error reading or parsing log file '$LogFilePath'.`nError: $($_.Exception.Message)" "Log File Error" ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error)
         return $null # Indicate failure
    } finally {
         # Ensure reader is closed/disposed
         if ($reader -ne $null) { $reader.Close(); $reader.Dispose() }
    }

    # --- Filtering: Keep only files that actually had error lines associated ---
    $filesWithReportedErrors = @{}
    foreach ($file in $fileErrors.Keys) {
        if ($fileErrors[$file].Count -gt 0) {
             $filesWithReportedErrors[$file] = $fileErrors[$file]
        } else {
            Write-Verbose "File '$file' was listed in log but had no subsequent error lines."
        }
    }

    if ($skippedMp4Count -gt 0) {
        Write-Host "`nSkipped $skippedMp4Count MP4 files listed in the log." -ForegroundColor Yellow
    }
    if ($filesWithReportedErrors.Count -eq 0) {
         Write-Warning "No non-MP4 files with associated error descriptions found in the log file."
    } else {
         Write-Host "`nFound $($filesWithReportedErrors.Count) non-MP4 files with reported errors in the log." -ForegroundColor Cyan
    }

    return $filesWithReportedErrors # Return hashtable {FilePath -> List<ErrorString>} for all files with errors
}

# Function to get files from folder scan
function Get-FilesFromFolder {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderPath,
        [Parameter(Mandatory=$true)]
        [bool]$Recurse,
        [Parameter(Mandatory=$true)]
        [string[]]$IncludeExtensions # Should already exclude MP4 based on config
    )

    Write-Host "Scanning folder: $FolderPath"
    Write-Host "Include subfolders: $Recurse"
    Write-Host "Including extensions: $($IncludeExtensions -join ', ')"

    $filePaths = [System.Collections.Generic.List[string]]::new()
    $gciParams = @{
        Path = $FolderPath
        Include = $IncludeExtensions
        File = $true # Ensure only files are returned
        ErrorAction = 'SilentlyContinue' # Continue if some folders are inaccessible
        Force = $true # Include hidden/system files if they match extension
    }
    if ($Recurse) {
        $gciParams.Recurse = $true
    }

    try {
        # Get-ChildItem can be slow on huge directories, especially recursive
        $items = Get-ChildItem @gciParams
        if ($null -ne $items) {
            foreach ($item in $items) {
                 $filePaths.Add($item.FullName)
            }
        }

        if ($filePaths.Count -eq 0) {
            Write-Warning "No image files matching the specified extensions found in '$FolderPath' (Recurse=$Recurse)."
        } else {
             Write-Host "Found $($filePaths.Count) image files to initially check."
        }
        return $filePaths # Return the List<string>
    } catch {
         Show-GuiMessage "Error scanning folder '$FolderPath'.`nError: $($_.Exception.Message)" "Folder Scan Error" ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error)
         return $null # Indicate failure
    }
}


# Function to run ExifTool command and capture results
function Invoke-ExifToolCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExifToolPath,
        [Parameter(Mandatory=$true)]
        [string[]]$Arguments # Array of arguments including file path
    )
    $process = $null
    Write-Host "Executing: $ExifToolPath $($Arguments -join ' ')"
    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $ExifToolPath
        foreach($arg in $Arguments) { $processInfo.ArgumentList.Add($arg) }
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        $process.WaitForExit() # Wait indefinitely
        [System.Threading.Tasks.Task]::WaitAll($stdoutTask, $stderrTask)

        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        $exitCode = $process.ExitCode

        # Return results object
        return [PSCustomObject]@{
            ExitCode = $exitCode
            StdOut   = $stdout
            StdErr   = $stderr
            Success  = ($exitCode -eq 0) # Basic success check based on exit code
        }

    } catch {
        Write-Error "CRITICAL FAILURE: Error launching ExifTool process for arguments '$($Arguments -join ' ')'. Details: $($_.Exception.Message)"
        # Return an object indicating failure
        return [PSCustomObject]@{
            ExitCode = -1 # Indicate script-level failure
            StdOut   = ''
            StdErr   = "PowerShell Error: $($_.Exception.Message)"
            Success  = $false
        }
    } finally {
        if ($process -ne $null) { $process.Dispose() }
    }
}


# Function to process a list of files using ExifTool
function Process-Files {
    param(
        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.List[string]]$FilePaths, # List of files confirmed to need fixing
        [Parameter(Mandatory=$true)]
        [hashtable]$FileErrorDetails, # MUST contain {FilePath -> List<ErrorString>} for all files in FilePaths
        [Parameter(Mandatory=$true)]
        [string]$ExifToolExecutable,
        [Parameter(Mandatory=$true)]
        [string[]]$GeneralFixArguments,  # Base args for general fix (-m -all= -tagsfromfile @ -all -unsafe)
        [Parameter(Mandatory=$true)]
        [string[]]$MakerNoteFixArguments, # Base args for MakerNote fix (-m -makernotes:all=)
        [Parameter(Mandatory=$true)]
        [string[]]$IPTCDigestFixArguments, # Base args for IPTC Digest fix (-m -IPTCDigest=new)
        [Parameter(Mandatory=$true)]
        [string[]]$ExtraArguments,      # Extra args like -overwrite_original
        [Parameter(Mandatory=$true)]
        [bool]$PromptForEachFile
    )

    $totalFiles = $FilePaths.Count
    if ($totalFiles -eq 0) {
        Write-Warning "Process-Files called with zero files. Nothing to do."
        return @{ SuccessCount = 0; FailureList = [System.Collections.Generic.List[string]]::new(); SkippedList = [System.Collections.Generic.List[string]]::new() }
    }

    $processedCount = 0
    $overallSuccessCount = 0
    $overallFailureList = [System.Collections.Generic.List[string]]::new()
    $overallSkippedList = [System.Collections.Generic.List[string]]::new() # For user skips during this phase

    # Sort the list before processing for consistent order
    $sortedFilePaths = $FilePaths | Sort-Object

    foreach ($filePath in $sortedFilePaths) {
        $processedCount++
        $statusString = 'File {0} of {1}: {2}' -f $processedCount, $totalFiles, $filePath
        Write-Progress -Activity "Attempting Fixes" -Status $statusString -PercentComplete (($processedCount / $totalFiles) * 100)

        Write-Host "`nProcessing file ($processedCount/$totalFiles): $filePath"

        $attemptFix = $true # Assume we attempt fix since file is in this list
        $fixSteps = [System.Collections.Generic.List[object]]::new() # List to hold steps {Args, Type, DependsOnSuccessOfStep}
        $fileFailed = $false # Track failure for this specific file

        # --- Determine Fix Steps based on errors found for THIS file ---
        if ($FileErrorDetails.ContainsKey($filePath)) {
            $errorsForFile = $FileErrorDetails[$filePath]
            Write-Host "Errors identified for this file:" -ForegroundColor Cyan
            $errorsForFile | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }

            # Classify errors for this file
            $hasMakerNoteError = $false
            $hasIPTCDigestError = $false
            $hasMissingRequiredError = $false # Track this
            $hasOtherStructuralError = $false

            foreach ($err in $errorsForFile) {
                $errorClassified = $false
                # Check MakerNote Patterns
                foreach ($pattern in $MakerNoteErrorPatterns) {
                    if ($err -like $pattern) { $hasMakerNoteError = $true; $errorClassified = $true; break }
                }
                if ($errorClassified) { continue }

                # Check IPTC Digest Pattern
                if ($err -like $IPTCDigestErrorPattern) { $hasIPTCDigestError = $true; $errorClassified = $true; continue }

                # Check Missing Required Patterns
                foreach ($pattern in $MissingRequiredPatterns) {
                    if ($err -like $pattern) { $hasMissingRequiredError = $true; $errorClassified = $true; break }
                }
                if ($errorClassified) { continue }

                # Check Other Structural Error Patterns
                foreach ($pattern in $OtherStructuralErrorPatterns) {
                    if ($err -like $pattern) { $hasOtherStructuralError = $true; $errorClassified = $true; break }
                }
                # If we have found at least one of each actionable type, we can stop classifying
                if ($hasMakerNoteError -and $hasIPTCDigestError -and $hasOtherStructuralError) { break }
            }

            # --- Build the fix steps sequence based on actionable errors ---
            $stepCounter = 0
            $lastSuccessfulStep = 0

            # Step 1: General Rebuild (if OtherStructural errors OR if *any* error exists - this handles the "Missing Required only" case implicitly now)
            # We run General Rebuild if there's any reason to rewrite the file structure or potentially fix derived tags.
            if ($hasOtherStructuralError -or $hasMissingRequiredError -or $hasMakerNoteError -or $hasIPTCDigestError) {
                 # Check if ONLY MakerNote or ONLY IPTC Digest errors exist - these have specific single steps
                 if (($hasMakerNoteError -and -not $hasOtherStructuralError -and -not $hasIPTCDigestError -and -not $hasMissingRequiredError) `
                     -or ($hasIPTCDigestError -and -not $hasOtherStructuralError -and -not $hasMakerNoteError -and -not $hasMissingRequiredError)) {
                     # Skip adding General Rebuild here, specific steps below will handle it
                 } else {
                     # Add General Rebuild for OtherStructural, MissingRequired (even if alone), or combinations involving them
                     $stepCounter++
                     $reason = "structural/format/missing tag errors" # Simplified reason
                     Write-Host "Action Plan: Step $stepCounter - General Rebuild (Due to $reason)" -ForegroundColor Yellow
                     $fixSteps.Add(@{ Step = $stepCounter; Args = @($GeneralFixArguments) + @($ExtraArguments) + @($filePath); Type = "General Rebuild"; DependsOn = 0 })
                     $lastSuccessfulStep = $stepCounter
                 }
            }


            # Step 2: MakerNote Removal (ONLY if MakerNote errors exist)
            if ($hasMakerNoteError) {
                 # If General Rebuild wasn't added (i.e., ONLY MakerNote errors), this is Step 1
                 if ($fixSteps.Count -eq 0) {
                     $stepCounter++
                     $dependsOn = 0
                     Write-Host "Action Plan: Step $stepCounter - MakerNote Removal (Only MakerNote errors found)" -ForegroundColor Magenta
                 } else {
                 # If General Rebuild WAS added, this is Step 2
                     $stepCounter++
                     $dependsOn = $lastSuccessfulStep # Depends on previous step if it exists
                     Write-Host "Action Plan: Step $stepCounter - MakerNote Removal (Depends on Step $dependsOn success)" -ForegroundColor Magenta
                 }
                 $fixSteps.Add(@{ Step = $stepCounter; Args = @($MakerNoteFixArguments) + @($ExtraArguments) + @($filePath); Type = "MakerNote Removal"; DependsOn = $dependsOn })
                 $lastSuccessfulStep = $stepCounter
            }

            # Step 3: IPTC Digest Update (ONLY if IPTCDigest errors exist)
            if ($hasIPTCDigestError) {
                 # If neither General nor MakerNote steps were added, this is Step 1
                 if ($fixSteps.Count -eq 0) {
                     $stepCounter++
                     $dependsOn = 0
                     Write-Host "Action Plan: Step $stepCounter - IPTC Digest Update (Only IPTC Digest error found)" -ForegroundColor Cyan
                 } else {
                 # If previous steps were added, this depends on the last one
                     $stepCounter++
                     $dependsOn = $lastSuccessfulStep # Always depends on the immediately preceding step
                     Write-Host "Action Plan: Step $stepCounter - IPTC Digest Update (Depends on Step $dependsOn success)" -ForegroundColor Cyan
                 }
                 $fixSteps.Add(@{ Step = $stepCounter; Args = @($IPTCDigestFixArguments) + @($ExtraArguments) + @($filePath); Type = "IPTCDigest Update"; DependsOn = $dependsOn })
                 # $lastSuccessfulStep = $stepCounter # Not needed as it's the last potential step
            }

            # Check if any steps were added (This condition should now only be met if errors existed but matched no patterns at all)
            if ($fixSteps.Count -eq 0) {
                 Write-Warning "File '$filePath' has error details but none matched known patterns requiring action. Skipping."
                 $overallSkippedList.Add("$filePath (No actionable errors found)")
                 $attemptFix = $false # Ensure we don't proceed
                 continue # Skip to next file
            }

        } else {
            # FilePath provided to function, but no error details? Should not happen.
            Write-Error "Internal Error: File '$filePath' is in processing list but lacks error details. Skipping."
            $overallSkippedList.Add("$filePath (Internal Error - Missing Details)")
            continue # Skip to next file
        }

        # --- User Confirmation (if needed and steps exist) ---
        if ($attemptFix -and $PromptForEachFile) {
            $fixTypesDesc = ($fixSteps | ForEach-Object { $_.Type }) -join ', '
            $promptMessage = "Attempt fix(es) ($fixTypesDesc) for this file?`n`nFile: $filePath"
            $promptResult = Show-GuiMessage $promptMessage "Confirm Fix" ([System.Windows.Forms.MessageBoxButtons]::YesNo) ([System.Windows.Forms.MessageBoxIcon]::Question)
            if ($promptResult -ne [System.Windows.Forms.DialogResult]::Yes) {
                $attemptFix = $false # Don't proceed with execution
                $overallSkippedList.Add("$filePath (User skipped)")
                Write-Host "Skipped file by user request." -ForegroundColor Yellow
            }
        }

        # --- Execute Fix Command(s) ---
        if ($attemptFix) {
            $stepSuccessStatus = @{} # Track success of each step number: $stepSuccessStatus[1] = $true

            foreach ($step in $fixSteps) {
                $currentStepNum = $step.Step
                $currentArgs = $step.Args
                $currentFixType = $step.Type
                $dependsOnStep = $step.DependsOn

                # Check dependency
                # Step should run if DependsOn is 0 OR if the dependent step exists and was successful
                if ($dependsOnStep -gt 0 -and (-not $stepSuccessStatus.ContainsKey($dependsOnStep) -or -not $stepSuccessStatus[$dependsOnStep])) {
                    Write-Host "Skipping Step $currentStepNum ($currentFixType) because dependent Step $dependsOnStep failed or was not run." -ForegroundColor Yellow
                    # Mark this step as failed for subsequent dependencies, even though it wasn't run
                    $stepSuccessStatus[$currentStepNum] = $false
                    # Ensure the overall file is marked as failed if a dependent step is skipped
                    $fileFailed = $true
                    continue # Skip to next step in the list for this file
                }

                # Execute the command for this step
                $fixResult = Invoke-ExifToolCommand -ExifToolPath $ExifToolExecutable -Arguments $currentArgs

                # Check step result
                if ($fixResult.Success) {
                    # Check StdOut for confirmation
                    if ($fixResult.StdOut -match '1 image files updated') {
                        Write-Host "SUCCESS (Step $currentStepNum): ExifTool reported update for '$filePath' (Fix: $currentFixType)." -ForegroundColor Green
                    } elseif ($fixResult.StdOut -match 'Nothing changed') {
                        Write-Host "INFO (Step $currentStepNum): ExifTool reported nothing changed for '$filePath' (Fix: $currentFixType)." -ForegroundColor Cyan
                    } else {
                        # Exit code 0 but unexpected output? Treat as info/success for this step.
                        Write-Warning "INFO (Step $currentStepNum): ExifTool exited successfully (Code 0) but output was unexpected for '$filePath' (Fix: $currentFixType). Check manually if needed."
                        if ($fixResult.StdOut) { Write-Warning "Stdout: $($fixResult.StdOut)" }
                        if ($fixResult.StdErr) { Write-Warning "Stderr: $($fixResult.StdErr)" } # Should ideally be empty
                    }
                    # Mark step success
                    $stepSuccessStatus[$currentStepNum] = $true
                } else {
                    # Step failed
                    Write-Error "FAILURE (Step $currentStepNum): ExifTool fix command failed for '$filePath' (Fix: $currentFixType, Exit Code: $($fixResult.ExitCode))."
                    if ($fixResult.StdErr) { Write-Error "Error Output: $($fixResult.StdErr)" }
                    if ($fixResult.StdOut) { Write-Error "Standard Output (may contain clues): $($fixResult.StdOut)" }
                    $overallFailureList.Add("$filePath (Fix: $currentFixType, Exit Code: $($fixResult.ExitCode))")
                    $fileFailed = $true
                    $stepSuccessStatus[$currentStepNum] = $false # Mark step failure
                    break # Stop processing further steps for this file if one fails
                }
            } # End foreach step

            # Update overall success count if the file didn't fail any step
            if (-not $fileFailed) {
                $overallSuccessCount++
            }
        } # End if ($attemptFix)
    } # End foreach file

    Write-Progress -Activity "Attempting Fixes" -Completed

    # Return results as a hashtable
    return @{
        SuccessCount = $overallSuccessCount
        FailureList = $overallFailureList
        SkippedList = $overallSkippedList # Only user skips from this function
    }
}


# --- Main Script ---

# *** Load Forms Assembly Globally ***
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
} catch {
     Write-Error "Failed to load System.Windows.Forms assembly. GUI elements will not work. Error: $($_.Exception.Message)"
     if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to exit..." }
     exit 1
}


# 0. Check for ExifTool
if (-not (Test-ExifTool -ToolPath $ExifToolPath)) {
    Write-Error "ExifTool check failed. Please install ExifTool and ensure it's in your PATH."
    if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to exit..." }
    exit 1
}

# Initialize variables
$allIdentifiedFiles = [System.Collections.Generic.List[string]]::new()
$filesRequiringFixList = [System.Collections.Generic.List[string]]::new() # Files needing actionable fixes
$filesValidationOKList = [System.Collections.Generic.List[string]]::new()
#$filesSkippedOnlyMissingTags = [System.Collections.Generic.List[string]]::new() # No longer needed - handled by Process-Files logic
$filesWithErrorDetails = @{} # {FilePath -> List<ErrorString>} for files needing fixes OR having only missing tags
$sourceDescription = ""
# $inputMode = $null # No longer needed as logic is unified after validation/parsing

# 1. Ask to load log file OR scan folder
$loadChoice = Show-GuiMessage "Do you want to load an ExifTool error log file (`'$($LogFileNamePattern)`') to process files listed with errors?`n`n(Choosing 'No' will let you select a folder to scan, validate, and attempt to fix images with errors)." "Select Input Method" ([System.Windows.Forms.MessageBoxButtons]::YesNo) ([System.Windows.Forms.MessageBoxIcon]::Question)

if ($loadChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
    # --- Load and Parse Log File Path ---
    $sourceDescription = "Log File"
    $logFilePath = Get-GuiOpenFile -Title "Select ExifTool Error Log File" -Filter "Log files (*.log)|*.log|All files (*.*)|*.*"
    if (-not $logFilePath) { Show-GuiMessage "No log file selected. Exiting script." "Operation Cancelled"; exit 0 }
    if (-not (Test-Path -Path $logFilePath -PathType Leaf)) {
         Show-GuiMessage "Selected file does not exist or is not a file: '$logFilePath'. Exiting script." "File Error" ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error)
         if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to exit..." }; exit 1
    }
    Write-Host "Selected log file: $logFilePath"
    $sourceDescription = "Log File: $logFilePath"

    # Parse the log file. Returns a hashtable {FilePath -> List<ErrorString>} of files with errors
    # Includes MP4 exclusion logic within the function
    $filesWithErrorDetails = Parse-ExifLog -LogFilePath $logFilePath
    if ($null -eq $filesWithErrorDetails) { # Check if parsing failed
        if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to exit..." }; exit 1
    }
    # Get the list of file paths (keys) that have errors
    $allIdentifiedFiles.AddRange([string[]]$filesWithErrorDetails.Keys) # All non-MP4 files from log initially considered
    $filesRequiringFixList.AddRange([string[]]$filesWithErrorDetails.Keys) # Start with all non-MP4 files from log

} else {
    # --- Scan Folder Path ---
    Write-Host "Proceeding with folder scan."
    $selectedFolder = Get-GuiFolder -Description "Select the folder containing images to process"
    if (-not $selectedFolder) { Show-GuiMessage "No folder selected. Exiting script." "Operation Cancelled"; exit 0 }
    if (-not (Test-Path -Path $selectedFolder -PathType Container)) {
         Show-GuiMessage "Selected path is not a valid folder: '$selectedFolder'. Exiting script." "Folder Error" ([System.Windows.Forms.MessageBoxButtons]::OK) ([System.Windows.Forms.MessageBoxIcon]::Error)
         if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to exit..." }; exit 1
    }

    # Ask about recursion
    $recurseChoice = Show-GuiMessage "Do you want to include images in subfolders of '$selectedFolder'?" "Include Subfolders?" ([System.Windows.Forms.MessageBoxButtons]::YesNo) ([System.Windows.Forms.MessageBoxIcon]::Question)
    $shouldRecurse = ($recurseChoice -eq [System.Windows.Forms.DialogResult]::Yes)
    $sourceDescription = "Folder Scan: $selectedFolder (Recurse=$shouldRecurse)"

    # Get initial list of files from folder (already excludes MP4 via $ImageExtensions)
    $allIdentifiedFiles = Get-FilesFromFolder -FolderPath $selectedFolder -Recurse $shouldRecurse -IncludeExtensions $ImageExtensions
    if ($null -eq $allIdentifiedFiles) { # Check if scan failed
         if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to exit..." }; exit 1
    }

    if ($allIdentifiedFiles.Count -gt 0) {
        Write-Host "`nValidating $($allIdentifiedFiles.Count) found files..."
        $validationCount = 0
        foreach ($filePath in $allIdentifiedFiles | Sort-Object) {
             $validationCount++
             $statusString = 'Validating {0} of {1}: {2}' -f $validationCount, $allIdentifiedFiles.Count, $filePath
             Write-Progress -Activity "Validating Files" -Status $statusString -PercentComplete (($validationCount / $allIdentifiedFiles.Count) * 100)
             Write-Host "`nValidating file ($validationCount/$($allIdentifiedFiles.Count)): $filePath" -ForegroundColor Cyan

             # Use validation command similar to log generation
             $validationArgs = @("-m", "-validate", "-warning", "-error", "-a", $filePath)
             $validationResult = Invoke-ExifToolCommand -ExifToolPath $ExifToolPath -Arguments $validationArgs

             # Combine StdOut and StdErr for error checking
             # Focus on lines starting with Warning: or Error: as primary indicators
             $outputLines = ($validationResult.StdOut + $validationResult.StdErr) -split '(\r?\n)' | Where-Object { $_ -match '^(Error|Warning):\s' }

             if ($outputLines.Count -gt 0) {
                  Write-Warning "Validation found issues for '$filePath':"
                  # Extract just the message part after "Warning: " or "Error: "
                  $errorMessages = $outputLines | ForEach-Object { $_ -replace '^(Error|Warning):\s*', '' }
                  $errorMessages | ForEach-Object { Write-Warning "  - $_" }
                  # Add to the central error details hashtable
                  $filesWithErrorDetails[$filePath] = [System.Collections.Generic.List[string]]::new()
                  $filesWithErrorDetails[$filePath].AddRange($errorMessages)
                  # Add to the list requiring potential fix
                  $filesRequiringFixList.Add($filePath)
             } else {
                 Write-Host "Validation successful for '$filePath'." -ForegroundColor Green
                 $filesValidationOKList.Add($filePath)
             }
        }
        Write-Progress -Activity "Validating Files" -Completed
    }
}


# 3. Check if any files require fixing *after initial identification*
if ($filesRequiringFixList.Count -eq 0) {
    Show-GuiMessage "No files with errors or warnings were identified based on your selection ($($sourceDescription.Split(':')[0])). Exiting." "No Work To Do"
    if ($filesValidationOKList.Count -gt 0) {
        Write-Host "`n$($filesValidationOKList.Count) files passed validation and were skipped." -ForegroundColor Green
    }
    if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter to exit..." }
    exit 0
}

Write-Host "`nIdentified $($filesRequiringFixList.Count) files with errors/warnings requiring processing." -ForegroundColor Green
if ($filesValidationOKList.Count -gt 0) { Write-Host "$($filesValidationOKList.Count) files passed validation and will be skipped." -ForegroundColor Yellow }
# Note: Skipping based on only non-actionable errors now happens inside Process-Files


# 4. Ask for automatic fixing mode (Common Logic)
$autoFixChoice = Show-GuiMessage "Do you want to attempt to fix metadata for all $($filesRequiringFixList.Count) applicable files automatically?`n(Files with only certain non-critical errors might be skipped)`n`n(Choosing 'No' will prompt you for each applicable file)." "Fixing Mode" ([System.Windows.Forms.MessageBoxButtons]::YesNo) ([System.Windows.Forms.MessageBoxIcon]::Question)
$promptForEach = ($autoFixChoice -eq [System.Windows.Forms.DialogResult]::No) # True if user wants to be prompted
Write-Host ("Prompt for each applicable file: " + $promptForEach)

# 5. Ask about overwriting originals (Common Logic)
$backupChoice = Show-GuiMessage "Do you want to OVERWRITE the original files?`n`nChoosing 'Yes' uses ExifTool's '-overwrite_original' flag (NO BACKUP).`nChoosing 'No' lets ExifTool create backups (filename + '_original')." "Backup Options" ([System.Windows.Forms.MessageBoxButtons]::YesNoCancel) ([System.Windows.Forms.MessageBoxIcon]::Warning)

# Define base arguments for different fix types
$generalFixBaseArgs = @("-m", "-all=", "-tagsfromfile", "@", "-all", "-unsafe") # Use -all
$makerNoteFixBaseArgs = @("-m", "-makernotes:all=")
$iptcDigestFixBaseArgs = @("-m", "-IPTCDigest=new") # Base args for IPTC Digest fix
$extraFixArgs = @() # Arguments specific to this run (like overwrite)
$overwriteOriginal = $false

if ($backupChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
    $extraFixArgs += "-overwrite_original"
    $overwriteOriginal = $true
    Write-Host "Option selected: Overwrite original files (NO BACKUPS)." -ForegroundColor Yellow
} elseif ($backupChoice -eq [System.Windows.Forms.DialogResult]::No) {
    Write-Host "Option selected: Create backups of original files (files ending in '_original')."
} else {
    Show-GuiMessage "Operation cancelled by user at backup prompt." "Operation Cancelled"
    exit 0
}

# --- Processing ---
Write-Host "`nStarting ExifTool fix attempts..."

# Call the processing function with the list of files identified with errors/warnings
# Process-Files will internally determine if the errors are actionable and skip if needed
$processingResults = Process-Files `
    -FilePaths $filesRequiringFixList `
    -FileErrorDetails $filesWithErrorDetails `
    -ExifToolExecutable $ExifToolPath `
    -GeneralFixArguments $generalFixBaseArgs `
    -MakerNoteFixArguments $makerNoteFixBaseArgs `
    -IPTCDigestFixArguments $iptcDigestFixBaseArgs `
    -ExtraArguments $extraFixArgs `
    -PromptForEachFile $promptForEach

# --- Final Summary ---
$allSkippedFiles = [System.Collections.Generic.List[string]]::new()
$allSkippedFiles.AddRange($filesValidationOKList) # Add validation skips
$allSkippedFiles.AddRange($processingResults.SkippedList) # Add user skips & non-actionable skips from fixing phase

Write-Host "`n=============================="
Write-Host "Processing Summary"
Write-Host "=============================="
Write-Host "Input Source: $sourceDescription"
Write-Host "Total Files Identified/Scanned: $($allIdentifiedFiles.Count)"
if ($loadChoice -ne [System.Windows.Forms.DialogResult]::Yes) { # Check if folder scan was chosen
    Write-Host "Files Passed Validation (Skipped): $($filesValidationOKList.Count)" -ForegroundColor Green
}
Write-Host "Files with Errors/Warnings Found: $($filesWithErrorDetails.Count)"


# Calculate attempted count from results
$attemptedCount = $processingResults.SuccessCount + $processingResults.FailureList.Count
Write-Host "Files Attempted Fix: $attemptedCount"
Write-Host "Successful Fix Operations (File Level): $($processingResults.SuccessCount)" -ForegroundColor Green
Write-Host "Failed Fix Operations (File Level): $($processingResults.FailureList.Count)" -ForegroundColor Red

if ($processingResults.FailureList.Count -gt 0) {
    Write-Host "`nFiles with Failures during Fix (Details in parentheses):" -ForegroundColor Red
    $processingResults.FailureList | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

# Combine all skipped files for the final report
if ($allSkippedFiles.Count -gt 0) {
     Write-Host "`nFiles Skipped (Reason: Validation OK / User Skip / No Actionable Errors / Other):" -ForegroundColor Yellow
     $allSkippedFiles | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}


Write-Host "`nBackup Option Chosen: " -NoNewline
if ($overwriteOriginal) {
    Write-Host "Overwrite originals (No backups created)." -ForegroundColor Yellow
} else {
    Write-Host "Create backups (Files ending with '_original')."
}
Write-Host "=============================="
Write-Host "Script finished."

# Keep console window open if run directly from explorer, etc.
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "`nPress Enter to exit..." -NoNewline
    Read-Host | Out-Null
}
