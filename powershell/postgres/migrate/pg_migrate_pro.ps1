<#
.SYNOPSIS
	Professional PostgreSQL Migration GUI
.DESCRIPTION
	Supports Direct Migration, Staged Export/Import, Role Migration, templates, secure password storage, automated downloads, multi-DB select, asynchronous runspaces, multi-threading, and robust logging.
.AUTHOR
	Adromir
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Helper Functions (Security) ---
function Protect-String([string]$PlainText) {
	if ([string]::IsNullOrEmpty($PlainText)) { return "" }
	$Secure = ConvertTo-SecureString -String $PlainText -AsPlainText -Force
	return ConvertFrom-SecureString -SecureString $Secure
}

function Unprotect-String([string]$EncryptedText) {
	if ([string]::IsNullOrEmpty($EncryptedText)) { return "" }
	try {
		$Secure = ConvertTo-SecureString -String $EncryptedText
		$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
		$PlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
		[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
		return $PlainText
	} catch {
		return ""
	}
}

# --- Constants & Pathing ---
$ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$BaseDir = $PSScriptRoot
$LogDir = Join-Path -Path $BaseDir -ChildPath "logs"
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
$DumpDir = Join-Path -Path $BaseDir -ChildPath "dumps"
if (-not (Test-Path $DumpDir)) { New-Item -Path $DumpDir -ItemType Directory -Force | Out-Null }

$PgDownloads = [ordered]@{
	"18.4"  = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1260197"
	"17.10" = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1260201"
	"16.14" = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1260202"
	"15.18" = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1260205"
	"14.23" = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1260210"
	"13.23" = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1259854"
}
$PgVersions = $PgDownloads.Keys | ForEach-Object { $_ }

# --- i18n Localization ---
$Lang = (Get-Culture).TwoLetterISOLanguageName
if ($Lang -ne 'de') { $Lang = 'en' }

$LangFile = Join-Path -Path $BaseDir -ChildPath "lang\$Lang.json"
if (-not (Test-Path $LangFile)) {
	$LangFile = Join-Path -Path $BaseDir -ChildPath "lang\en.json"
}
$JsonText = Get-Content -Path $LangFile -Raw
$L_Obj = ConvertFrom-Json $JsonText
$L = @{}
foreach ($prop in $L_Obj.psobject.properties) {
	$L[$prop.Name] = $prop.Value
}

# --- Default Configuration ---
$Config = @{
	SelectedVersion = "18.4"
	SelectedMode = 0
	DumpFile = ""
	MigrateRoles = $true
	SchemaOnly = $false
	DataOnly = $false
	SelectedFormat = 0
	Jobs = 1
	VerifyMode = 0
	SavePasswords = $false
	Templates = @{}
	SrcHost = "localhost"; SrcPort = "5432"; SrcUser = "postgres"; SrcPassEnc = ""
	TgtHost = "central-server"; TgtPort = "5432"; TgtUser = "postgres"; TgtMaintDb = "postgres"; TgtPassEnc = ""
	CheckedDbs = @()
}

# --- Load Persistence ---
if (Test-Path -Path $ConfigPath) {
	$SavedConfig = Get-Content -Path $ConfigPath | ConvertFrom-Json
	foreach ($Key in $SavedConfig.psobject.Properties.Name) {
		if ($Key -eq 'Templates') {
			foreach ($TplKey in $SavedConfig.Templates.psobject.Properties.Name) {
				$Config.Templates[$TplKey] = @{
					Host = $SavedConfig.Templates.$TplKey.Host
					Port = $SavedConfig.Templates.$TplKey.Port
					User = $SavedConfig.Templates.$TplKey.User
					Pass = $SavedConfig.Templates.$TplKey.Pass
                    Type = $SavedConfig.Templates.$TplKey.Type
                    Engine = $SavedConfig.Templates.$TplKey.Engine
                    MaintDb = $SavedConfig.Templates.$TplKey.MaintDb
				}
			}
		} else {
			$Config[$Key] = $SavedConfig.$Key
		}
	}
}

# --- GUI Creation (WPF) ---
$XamlPath = Join-Path -Path $BaseDir -ChildPath "MainWindow.xaml"
$XamlRaw = [System.IO.File]::ReadAllText($XamlPath, [System.Text.Encoding]::UTF8)
foreach ($Key in $L.Keys) {
    $ValEscaped = [System.Security.SecurityElement]::Escape($L[$Key])
    $XamlRaw = $XamlRaw.Replace("{L_$Key}", $ValEscaped)
}
$XmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($XamlRaw))
$Window = [System.Windows.Markup.XamlReader]::Load($XmlReader)

$Status = $Window.FindName("Status")
$ProgressBar = $Window.FindName("ProgressBar")

$ComboVersion = $Window.FindName("ComboVersion")
$PgVersions | ForEach-Object { [void]$ComboVersion.Items.Add($_) }
$ComboVersion.Text = $Config.SelectedVersion
$BtnDl = $Window.FindName("BtnDl")

$ComboMode = $Window.FindName("ComboMode")
[void]$ComboMode.Items.Add($L['ModeDir'])
[void]$ComboMode.Items.Add($L['ModeExp'])
[void]$ComboMode.Items.Add($L['ModeImp'])
[void]$ComboMode.Items.Add($L['ModeMysql'])
if ($Config.SelectedMode -lt $ComboMode.Items.Count) { $ComboMode.SelectedIndex = $Config.SelectedMode } else { $ComboMode.SelectedIndex = 0 }

$InFile = $Window.FindName("InFile")
$InFile.Text = $Config.DumpFile
$BtnBrowse = $Window.FindName("BtnBrowse")

$BtnBrowse = $Window.FindName("BtnBrowse")

$ChkRoles = $Window.FindName("ChkRoles")
$ChkRoles.IsChecked = $Config.MigrateRoles
$ChkSchemaOnly = $Window.FindName("ChkSchemaOnly")
$ChkSchemaOnly.IsChecked = $Config.SchemaOnly
$ChkDataOnly = $Window.FindName("ChkDataOnly")
$ChkDataOnly.IsChecked = $Config.DataOnly

$ComboFormat = $Window.FindName("ComboFormat")
[void]$ComboFormat.Items.Add($L['FmtCustom'])
[void]$ComboFormat.Items.Add($L['FmtDir'])
if ($Config.SelectedFormat -lt $ComboFormat.Items.Count) { $ComboFormat.SelectedIndex = $Config.SelectedFormat } else { $ComboFormat.SelectedIndex = 0 }

$InJobs = $Window.FindName("InJobs")
$InJobs.Text = $Config.Jobs

$GridSrcDbPg = $Window.FindName("GridSrcDbPg")

$ComboVerify = $Window.FindName("ComboVerify")
[void]$ComboVerify.Items.Add($L['VNone'])
[void]$ComboVerify.Items.Add($L['VQuick'])
[void]$ComboVerify.Items.Add($L['VPrecise'])
if ($Config.VerifyMode -lt $ComboVerify.Items.Count) { $ComboVerify.SelectedIndex = $Config.VerifyMode } else { $ComboVerify.SelectedIndex = 0 }

$ComboSrcTpl = $Window.FindName("ComboSrcTpl")

$BtnTestSrc = $Window.FindName("BtnTestSrc")
$ListSrcDb = $Window.FindName("ListSrcDb")
$ChkToggleDbs = $Window.FindName("ChkToggleDbs")
$ComboTgtTpl = $Window.FindName("ComboTgtTpl")
$ComboTgtTpl = $Window.FindName("ComboTgtTpl")
$ComboManageTpl = $Window.FindName("ComboManageTpl")
$InTplHost = $Window.FindName("InTplHost")
$InTplPort = $Window.FindName("InTplPort")
$InTplUser = $Window.FindName("InTplUser")
$InTplPass = $Window.FindName("InTplPass")
$BtnSaveTpl = $Window.FindName("BtnSaveTpl")
$ComboTplType = $Window.FindName("ComboTplType")
$ComboTplEngine = $Window.FindName("ComboTplEngine")
$InTplMaintDb = $Window.FindName("InTplMaintDb")
$BtnTestTgt = $Window.FindName("BtnTestTgt")

$ChkSavePass = $Window.FindName("ChkSavePass")
$ChkSavePass.IsChecked = $Config.SavePasswords
$BtnDl = $Window.FindName("BtnDl")
$BtnDlPgloader = $Window.FindName("BtnDlPgloader")
$Status = $Window.FindName("Status")
$BtnSave = $Window.FindName("BtnSave")
	$BtnRun = $Window.FindName("BtnRun")
	
	$TxtLog = $Window.FindName("TxtLog")
	$BtnClearLogs = $Window.FindName("BtnClearLogs")
	$BtnClearLogs.add_Click({ $TxtLog.Text = "" })
	$BtnDelTpl = $Window.FindName("BtnDelTpl")

# --- Helper Functions ---
function DoEvents {
	$frame = New-Object System.Windows.Threading.DispatcherFrame
	[System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action]{ $frame.Continue = $false }) | Out-Null
	[System.Windows.Threading.Dispatcher]::PushFrame($frame)
}
function Log-Message([string]$Msg) {
	$time = Get-Date -Format "HH:mm:ss"
	$line = "[$time] $Msg
"
	$TxtLog.AppendText($line)
	$TxtLog.ScrollToEnd()
	DoEvents
}
function Ensure-PgBinaries([string]$Ver) {
	$ToolsDir = Join-Path -Path $BaseDir -ChildPath "tools"
	if (-not (Test-Path -Path $ToolsDir)) { New-Item -Path $ToolsDir -ItemType Directory -Force | Out-Null }
	
	$PgDir = Join-Path -Path $ToolsDir -ChildPath "pgsql_$Ver"
	$BinDir = Join-Path -Path $PgDir -ChildPath "bin"
	
	if (-not (Test-Path -Path $BinDir)) {
		$Status.Text = $L['Downloading'] -f $Ver
		try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#f8fafc") } catch {}
		DoEvents
		
		if (-not $PgDownloads.Contains($Ver)) {
			throw ($L['ErrDownload'] -f $Ver)
		}
		$Url = $PgDownloads[$Ver]
		$Zip = Join-Path -Path $BaseDir -ChildPath "temp_pg.zip"
		
		try {
			Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing -ErrorAction Stop
		} catch {
			throw ($L['ErrDownload'] -f $Ver)
		}
		
		$Status.Text = $L['Extracting']
		DoEvents
		
		$TempExt = Join-Path -Path $BaseDir -ChildPath "temp_pg_ext"
		Expand-Archive -Path $Zip -DestinationPath $TempExt -Force		
		
		New-Item -Path $BinDir -ItemType Directory -Force | Out-Null
		$ExtractedBin = Join-Path -Path (Join-Path -Path $TempExt -ChildPath "pgsql") -ChildPath "bin"
		
		$NeededFiles = @("psql.exe", "pg_dump.exe", "pg_restore.exe", "pg_dumpall.exe")
		foreach ($File in $NeededFiles) {
			$SourcePath = Join-Path -Path $ExtractedBin -ChildPath $File
			if (Test-Path -Path $SourcePath) {
				Copy-Item -Path $SourcePath -Destination $BinDir -Force
			}
		}
		Copy-Item -Path (Join-Path -Path $ExtractedBin -ChildPath "*.dll") -Destination $BinDir -Force
		
		Remove-Item -Path $TempExt -Recurse -Force
		Remove-Item -Path $Zip -Force
	}
	return $BinDir
}

function Ensure-ExternalTools {
    $ToolsDir = Join-Path -Path $BaseDir -ChildPath "tools"
    if (-not (Test-Path -Path $ToolsDir)) { New-Item -Path $ToolsDir -ItemType Directory -Force | Out-Null }
    
    $PgLoaderPath = Join-Path $ToolsDir "pgloader.jar"
    if (-not (Test-Path $PgLoaderPath)) {
        $Status.Text = "Lade pgloader.jar..."
        DoEvents
        try {
            Invoke-WebRequest -Uri "https://github.com/dimitri/pgloader/releases/download/v4.1.2/pgloader.jar" -OutFile $PgLoaderPath -UseBasicParsing -ErrorAction Stop
        } catch {
            try {
                Invoke-WebRequest -Uri "https://github.com/dimitri/pgloader/releases/download/v4-dev/pgloader.jar" -OutFile $PgLoaderPath -UseBasicParsing -ErrorAction Stop
            } catch {
                [System.Windows.MessageBox]::Show("Fehler beim Herunterladen von pgloader.jar.", "Warnung", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            }
        }
    }
    
    $MysqlExe = Join-Path $ToolsDir "mysql.exe"
    if (-not (Test-Path $MysqlExe)) {
        $Status.Text = "Lade mysql-client..."
        DoEvents
        try {
            $Zip = Join-Path $BaseDir "temp_mariadb.zip"
            Invoke-WebRequest -Uri "https://archive.mariadb.org/mariadb-10.11.8/winx64-packages/mariadb-10.11.8-winx64.zip" -OutFile $Zip -UseBasicParsing -ErrorAction Stop
            Expand-Archive -Path $Zip -DestinationPath $ToolsDir -Force
            $Extracted = Join-Path $ToolsDir "mariadb-10.11.8-winx64"
            Copy-Item -Path (Join-Path $Extracted "bin\mysql.exe") -Destination $ToolsDir -Force
            Copy-Item -Path (Join-Path $Extracted "lib\libmariadb.dll") -Destination $ToolsDir -Force
            Remove-Item -Path $Extracted -Recurse -Force
            Remove-Item -Path $Zip -Force
        } catch {
            [System.Windows.MessageBox]::Show("Fehler beim Herunterladen von mysql-client.", "Warnung", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    }
}

function Update-TemplateUI {
	$Tpls = $Config.Templates.Keys | Sort-Object
	
	$ComboSrcTpl.Items.Clear()
	$ComboTgtTpl.Items.Clear()
	$ComboManageTpl.Items.Clear()
	foreach ($T in $Tpls) {
        $Type = $Config.Templates[$T].Type
        if (-not $Type) { $Type = "Beides" }
        
        if ($Type -eq "Beides" -or $Type -eq "Quelle") {
		    [void]$ComboSrcTpl.Items.Add($T)
        }
        if ($Type -eq "Beides" -or $Type -eq "Ziel") {
		    [void]$ComboTgtTpl.Items.Add($T)
        }
		[void]$ComboManageTpl.Items.Add($T)
	}
    
    if ($ComboSrcTpl.Items.Count -gt 0 -and [string]::IsNullOrEmpty($ComboSrcTpl.Text)) { $ComboSrcTpl.SelectedIndex = 0 }
    if ($ComboTgtTpl.Items.Count -gt 0 -and [string]::IsNullOrEmpty($ComboTgtTpl.Text)) { $ComboTgtTpl.SelectedIndex = 0 }
    if ($ComboManageTpl.Items.Count -gt 0 -and [string]::IsNullOrEmpty($ComboManageTpl.Text)) { $ComboManageTpl.SelectedIndex = 0; Load-Template $ComboManageTpl }
}

function Save-Template() {
	$TplName = $ComboManageTpl.Text
	if ([string]::IsNullOrWhiteSpace($TplName)) { return }
	
	$PassData = ""
	if ($ChkSavePass.IsChecked) {
		$PassData = Protect-String $InTplPass.Password
	}
	
	$TypeVal = if ($ComboTplType.SelectedItem) { $ComboTplType.SelectedItem.Content } else { $ComboTplType.Text }
    $EngineVal = if ($ComboTplEngine.SelectedItem) { $ComboTplEngine.SelectedItem.Content } else { $ComboTplEngine.Text }
	$Config.Templates[$TplName] = @{
		Host = $InTplHost.Text
		Port = $InTplPort.Text
		User = $InTplUser.Text
		Pass = $PassData
        Type = "$TypeVal"
        Engine = "$EngineVal"
        MaintDb = $InTplMaintDb.Text
	}
	Update-TemplateUI
	$ComboManageTpl.Text = $TplName
    Save-Config
	[System.Windows.MessageBox]::Show("Vorlage gespeichert: $TplName", "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

function Load-Template($Combo) {
	$TplName = if ($Combo.SelectedItem) { $Combo.SelectedItem } else { $Combo.Text }
	if ($Config.Templates.Contains($TplName)) {
		$Tpl = $Config.Templates[$TplName]
		$InTplHost.Text = $Tpl.Host
		$InTplPort.Text = $Tpl.Port
		$InTplUser.Text = $Tpl.User
        $t = if ($Tpl.Type) { $Tpl.Type } else { "Beides" }
        foreach ($item in $ComboTplType.Items) {
            if ($item.Content -eq $t) {
                $ComboTplType.SelectedItem = $item
                break
            }
        }
        $e = if ($Tpl.Engine) { $Tpl.Engine } else { "PostgreSQL" }
        foreach ($item in $ComboTplEngine.Items) {
            if ($item.Content -eq $e) {
                $ComboTplEngine.SelectedItem = $item
                break
            }
        }
        $InTplMaintDb.Text = if ($Tpl.MaintDb) { $Tpl.MaintDb } else { "postgres" }
		if (-not [string]::IsNullOrEmpty($Tpl.Pass)) {
			$InTplPass.Password = Unprotect-String $Tpl.Pass
		} else {
			$InTplPass.Password = ""
		}
	} else {
		$InTplHost.Text = ""
		$InTplPort.Text = ""
		$InTplUser.Text = ""
		$InTplPass.Password = ""
        $ComboTplType.SelectedIndex = 0
        $ComboTplEngine.SelectedIndex = 0
        $InTplMaintDb.Text = "postgres"
	}
}

# --- Actions ---
$ComboMode.add_SelectionChanged({
	$Mode = $ComboMode.SelectedIndex
	$IsDirect = ($Mode -eq 0)
	$IsExport = ($Mode -eq 1)
	$IsImport = ($Mode -eq 2)
    $IsMysql = ($Mode -eq 3)

	$InFile.IsEnabled = (-not $IsDirect -and -not $IsMysql)
	$BtnBrowse.IsEnabled = (-not $IsDirect -and -not $IsMysql)

	$SrcEnabled = ($IsDirect -or $IsExport -or $IsMysql)
	$ComboSrcTpl.IsEnabled = $SrcEnabled
    $BtnTestSrc.IsEnabled = $SrcEnabled

	$TgtEnabled = ($IsDirect -or $IsImport -or $IsMysql)
	$ComboTgtTpl.IsEnabled = $TgtEnabled
    $BtnTestTgt.IsEnabled = $TgtEnabled

    $GridSrcDbPg.Visibility = 'Visible'
})
# Init UI data
$ComboMode.SelectedIndex = $ComboMode.SelectedIndex
Update-TemplateUI
$ComboManageTpl.add_SelectionChanged({ Load-Template $ComboManageTpl })
$BtnSaveTpl.add_Click({ Save-Template })

	$ChkToggleDbs.add_Click({
		if ($ListSrcDb.Items.Count -eq 0) { return }
		$newChecked = $ChkToggleDbs.IsChecked -eq $true
		foreach ($Item in $ListSrcDb.Items) {
			$Item.IsChecked = $newChecked
		}
		$ListSrcDb.Items.Refresh()
	})

	$BtnDl.add_Click({
	$BtnDl.IsEnabled = $false
	try {
		[void](Ensure-PgBinaries $ComboVersion.Text)
		[System.Windows.MessageBox]::Show($L['DlSuccess'], "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
		$Status.Text = $L['Ready']
	} catch {
		[System.Windows.MessageBox]::Show($_.Exception.Message, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	} finally {
		$BtnDl.IsEnabled = $true
	}
})

$BtnDlPgloader.add_Click({
	$BtnDlPgloader.IsEnabled = $false
	try {
        Ensure-ExternalTools
		[System.Windows.MessageBox]::Show("Zusatztools erfolgreich heruntergeladen.", "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
		$Status.Text = $L['Ready']
	} catch {
		[System.Windows.MessageBox]::Show($_.Exception.Message, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	} finally {
		$BtnDlPgloader.IsEnabled = $true
	}
})

$BtnBrowse.add_Click({
	$Mode = $ComboMode.SelectedIndex
	$Fmt = $ComboFormat.SelectedIndex # 0:Custom, 1:Dir
	
	if ($Mode -eq 1) { # Export
		if ($Fmt -eq 1) {
			# Folder Browser
			$Dialog = New-Object System.Windows.Forms.FolderBrowserDialog
			$Dialog.Description = "Select target directory for Dump"
			if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$InFile.Text = $Dialog.SelectedPath
			}
		} else {
			$Dialog = New-Object System.Windows.Forms.SaveFileDialog
			$Dialog.Filter = "Dump (*.dump)|*.dump|All Files (*.*)|*.*"
			$Dialog.Title = "Select base filename for export (e.g. C:\backup\myexport)"
			if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$InFile.Text = $Dialog.FileName
			}
		}
	} elseif ($Mode -eq 2) { # Import
		if ($Fmt -eq 1) {
			$Dialog = New-Object System.Windows.Forms.FolderBrowserDialog
			$Dialog.Description = "Select source directory of Dump"
			if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$InFile.Text = $Dialog.SelectedPath
			}
		} else {
			$Dialog = New-Object System.Windows.Forms.OpenFileDialog
			$Dialog.Filter = "Dump Files (*.dump)|*.dump|All Files (*.*)|*.*"
			$Dialog.Multiselect = $true
			if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$InFile.Text = ($Dialog.FileNames -join "|")
			}
		}
	}
})

function Get-Tpl($Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or -not $Config.Templates.Contains($Name)) {
        throw "Bitte eine gÃ¼ltige Vorlage auswÃ¤hlen!"
    }
    $T = $Config.Templates[$Name]
    return @{
        Host = $T.Host
        Port = $T.Port
        User = $T.User
        Pass = if (-not [string]::IsNullOrEmpty($T.Pass)) { Unprotect-String $T.Pass } else { "" }
        MaintDb = if ($T.MaintDb) { $T.MaintDb } else { "postgres" }
        Engine = if ($T.Engine) { $T.Engine } else { "PostgreSQL" }
    }
}

$BtnTestSrc.add_Click({
	$BtnTestSrc.IsEnabled = $false
	$S = Get-Tpl $ComboSrcTpl.Text; $env:PGPASSWORD = $S.Pass
	
	try {
        if ($S.Engine -eq "MySQL") {
            $MysqlExe = Join-Path $BaseDir "tools\mysql.exe"
            if (-not (Test-Path $MysqlExe)) { throw "mysql.exe nicht gefunden. Bitte 'Tools laden' ausführen." }
            
            $Status.Text = $L['Fetching']
            try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#f8fafc") } catch {}
            DoEvents

            $Query = "SHOW DATABASES;"
            $Output = & $MysqlExe -h $S.Host -P $S.Port -u $S.User -p$($S.Pass) -s -e $Query
            
            if ($LASTEXITCODE -ne 0) { throw "MySQL Connection failed or access denied." }

            $ListSrcDb.Items.Clear()
            $Dbs = $Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch 'information_schema|performance_schema|mysql|sys' }
            foreach ($Db in $Dbs) {
                [void]$ListSrcDb.Items.Add([PSCustomObject]@{ Name = $Db; IsChecked = $false })
            }
        } else {
            $BinDir = Ensure-PgBinaries $ComboVersion.Text
            $PsqlExe = Join-Path -Path $BinDir -ChildPath "psql.exe"
            
            $Status.Text = $L['Fetching']
            try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#f8fafc") } catch {}
            DoEvents

            # Exclude EnterpriseDB edb database as well
            $Query = "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'rdsadmin', 'azure_maintenance', 'edb') AND datname NOT ILIKE 'template%' AND has_database_privilege('$($S.User)', datname, 'CONNECT');"
            $Output = & $PsqlExe -h $S.Host -p $S.Port -U $S.User -d "postgres" -t -A -c $Query
            
            if ($LASTEXITCODE -ne 0) { throw "PostgreSQL Connection failed or access denied." }

            $ListSrcDb.Items.Clear()
            $Dbs = $Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            foreach ($Db in $Dbs) {
                [void]$ListSrcDb.Items.Add([PSCustomObject]@{ Name = $Db; IsChecked = $false })
            }
        }

		$Status.Text = $L['ConnSuccess']
		try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#10b981") } catch {}
	} catch {
		[System.Windows.MessageBox]::Show($_.Exception.Message, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		$Status.Text = $L['ErrGeneral']
		try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#ef4444") } catch {}
	} finally {
		$env:PGPASSWORD = ""
		$BtnTestSrc.IsEnabled = $true
	}
})

$BtnTestTgt.add_Click({
	$BtnTestTgt.IsEnabled = $false
	$T = Get-Tpl $ComboTgtTpl.Text; $env:PGPASSWORD = $T.Pass
	
	try {
        if ($T.Engine -eq "MySQL") {
            $MysqlExe = Join-Path $BaseDir "tools\mysql.exe"
            if (-not (Test-Path $MysqlExe)) { throw "mysql.exe nicht gefunden. Bitte 'Tools laden' ausführen." }
            
            $Status.Text = $L['TestingTgt']
            try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#f8fafc") } catch {}
            DoEvents

            $Output = & $MysqlExe -h $T.Host -P $T.Port -u $T.User -p$($T.Pass) -s -e "SELECT 1;"
            
            if ($LASTEXITCODE -ne 0 -or $Output -ne "1") { throw "Connection to Target MySQL failed." }
        } else {
            $BinDir = Ensure-PgBinaries $ComboVersion.Text
            $PsqlExe = Join-Path -Path $BinDir -ChildPath "psql.exe"
            
            $Status.Text = $L['TestingTgt']
            try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#f8fafc") } catch {}
            DoEvents

            $Output = & $PsqlExe -h $T.Host -p $T.Port -U $T.User -d $T.MaintDb -t -A -c "SELECT 1;"
            
            if ($LASTEXITCODE -ne 0 -or $Output -ne "1") { throw "Connection to Target Maintenance DB failed." }
        }

		$Status.Text = $L['ConnSuccess']
		try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#10b981") } catch {}
	} catch {
		[System.Windows.MessageBox]::Show($_.Exception.Message, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		$Status.Text = $L['ErrGeneral']
		try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#ef4444") } catch {}
	} finally {
		$env:PGPASSWORD = ""
		$BtnTestTgt.IsEnabled = $true
	}
})

	function Load-TemplateList {
		$ComboManageTpl.Items.Clear()
		foreach ($Key in $Config.Templates.Keys | Sort-Object) {
			[void]$ComboManageTpl.Items.Add($Key)
		}
	}
	Load-TemplateList
	
	$BtnDelTpl.add_Click({
		$Sel = $ComboManageTpl.Text
		if ($Sel) {
			$Config.Templates.Remove($Sel)
			Save-Config
			Load-TemplateList
			Load-ComboTpl
		Load-TemplateList
		}
	})
function Save-Config {
    $CheckedArr = @()
    foreach ($Item in ($ListSrcDb.Items | Where-Object { $_.IsChecked })) { $CheckedArr += $Item.Name }

	$CurrentConfig = @{
		SelectedVersion = $ComboVersion.Text
		SelectedMode = $ComboMode.SelectedIndex
		DumpFile = $InFile.Text
		MigrateRoles = $ChkRoles.IsChecked
		SchemaOnly = $ChkSchemaOnly.IsChecked
		DataOnly = $ChkDataOnly.IsChecked
		SelectedFormat = $ComboFormat.SelectedIndex
		Jobs = $InJobs.Value
		VerifyMode = $ComboVerify.SelectedIndex
		SavePasswords = $ChkSavePass.IsChecked
		Templates = $Config.Templates
        CheckedDbs = $CheckedArr
	}
	$CurrentConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath
}

$BtnSave.add_Click({
	Save-Config
	[System.Windows.MessageBox]::Show($L['Saved'], "Info")
})

# --- Async Execution with Runspaces ---
$BtnRun.add_Click({
	$BtnRun.IsEnabled = $false
	
	try {
		$BinDir = Ensure-PgBinaries $ComboVersion.Text
	} catch {
		[System.Windows.MessageBox]::Show($_.Exception.Message, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		$BtnRun.IsEnabled = $true
		return
	}

	$Mode = $ComboMode.SelectedIndex
	$IsDirect = ($Mode -eq 0)
	$IsExport = ($Mode -eq 1)
	$IsImport = ($Mode -eq 2)
    $IsMysql = ($Mode -eq 3)

	$TargetFiles = @()
	$SourceDbs = @()
	
	if ($IsDirect -or $IsExport -or $IsMysql) {
		foreach ($Item in ($ListSrcDb.Items | Where-Object { $_.IsChecked })) { $SourceDbs += $Item.Name }
		if ($SourceDbs.Count -eq 0) { 
			[System.Windows.MessageBox]::Show($L['SelectDbs'], "Warning", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
			$BtnRun.IsEnabled = $true
			return 
		}
	}
    
    if ((-not $IsDirect) -and (-not $IsMysql) -and ([string]::IsNullOrWhiteSpace($InFile.Text))) {
			[System.Windows.MessageBox]::Show($L['SelectFiles'], "Warning", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
			$BtnRun.IsEnabled = $true
			return
		}

	if ($IsImport) {
		if ([string]::IsNullOrWhiteSpace($InFile.Text)) { 
			[System.Windows.MessageBox]::Show($L['SelectFiles'], "Warning", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
			$BtnRun.IsEnabled = $true
			return 
		}
		$TargetFiles = $InFile.Text -split "\|"
	}

    if ($IsMysql) {
        if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
            [System.Windows.MessageBox]::Show("Java (JRE) ist nicht installiert oder nicht im PATH. pgloader benötigt Java.", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            $BtnRun.IsEnabled = $true
            return
        }
    }

	$script:State = [hashtable]::Synchronized(@{
		Status = "Starting..."
		Progress = 0
		Color = "White"
		IsRunning = $true
	})

	$S = Get-Tpl $ComboSrcTpl.Text
    $T = Get-Tpl $ComboTgtTpl.Text
    
	$RunArgs = @{
		Mode = $Mode
		IsDirect = $IsDirect
		IsExport = $IsExport
		IsImport = $IsImport
        IsMysql = $IsMysql
        PgLoaderFile = Join-Path -Path $BaseDir -ChildPath "tools\pgloader.jar"
		BinDir = $BinDir
		BaseDumpPath = $InFile.Text
		SourceDbs = $SourceDbs
		TargetFiles = $TargetFiles
		RolesChecked = $ChkRoles.IsChecked
		SchemaOnly = $ChkSchemaOnly.IsChecked
		DataOnly = $ChkDataOnly.IsChecked
		Format = $ComboFormat.SelectedIndex
		Jobs = $InJobs.Value
		VerifyMode = $ComboVerify.SelectedIndex
				SrcHost = $S.Host
		SrcPort = $S.Port
		SrcUser = $S.User
		SrcPass = $S.Pass
		TgtHost = $T.Host
		TgtPort = $T.Port
		TgtUser = $T.User
		TgtPass = $T.Pass
		TgtMaintDb = $T.MaintDb
		State = $script:State
		L = $L
		LogDir = $LogDir
		DumpDir = $DumpDir
		Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
		LogBox = $TxtLog
	}

	$script:Runspace = [runspacefactory]::CreateRunspace()
	$script:Runspace.ThreadOptions = "ReuseThread"
	$script:Runspace.Open()
	$script:PS = [System.Management.Automation.PowerShell]::Create()
	$script:PS.Runspace = $script:Runspace

	[void]$script:PS.AddScript({
		param($A)
		try {
			$A.State.IsRunning = $true
			$A.State.Progress = 0
			$A.State.Color = "White"
			
			$PgDumpExe = Join-Path -Path $A.BinDir -ChildPath "pg_dump.exe"
			$PgRestoreExe = Join-Path -Path $A.BinDir -ChildPath "pg_restore.exe"
			$PgDumpAllExe = Join-Path -Path $A.BinDir -ChildPath "pg_dumpall.exe"
			$PsqlExe = Join-Path -Path $A.BinDir -ChildPath "psql.exe"

			$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

			function Run-Tool {
				param([string]$Exe, [string]$CmdArgs, [string]$LogFile, [hashtable]$EnvVars)
				$Si = New-Object System.Diagnostics.ProcessStartInfo
				$Si.FileName = $Exe
				$Si.Arguments = $CmdArgs
				$Si.UseShellExecute = $false
				$Si.RedirectStandardOutput = $true
				$Si.RedirectStandardError = $true
				$Si.CreateNoWindow = $true
				foreach ($Key in $EnvVars.Keys) { $Si.EnvironmentVariables[$Key] = $EnvVars[$Key] }

				$A.Dispatcher.Invoke([System.Action]{
					$A.LogBox.AppendText("`r`n>>> STARTE SCHRITT: $($A.State.Status)`r`nCOMMAND: $Exe $CmdArgs`r`n... (Bitte warten, dies kann je nach Datenmenge dauern) ...`r`n")
					$A.LogBox.ScrollToEnd()
				})

				$Proc = [System.Diagnostics.Process]::Start($Si)
				$OutTask = $Proc.StandardOutput.ReadToEndAsync()
				$ErrTask = $Proc.StandardError.ReadToEndAsync()
				[System.Threading.Tasks.Task]::WaitAll($OutTask, $ErrTask)
				$Out = $OutTask.Result
				$Err = $ErrTask.Result
				$Proc.WaitForExit()
				
				$FullLog = "--- COMMAND ---`r`n$Exe $CmdArgs`r`n`r`n--- STDOUT ---`r`n$Out`r`n--- STDERR ---`r`n$Err"
				Set-Content -Path $LogFile -Value $FullLog
				$A.Dispatcher.Invoke([System.Action]{
					$A.LogBox.AppendText("$FullLog`r`n`r`n")
					$A.LogBox.ScrollToEnd()
				})
				return $Proc.ExitCode
			}

			# Handle Roles
			$RolesFile = ""
			if ($A.IsImport) {
				if ($A.TargetFiles.Count -gt 0) {
					$FirstFile = $A.TargetFiles[0]
					$BaseDirForRoles = if (Test-Path -Path $FirstFile -PathType Container) { $FirstFile } else { Split-Path $FirstFile -Parent }
					$FoundRoles = Get-ChildItem -Path $BaseDirForRoles -Filter "*roles*.sql" | Select-Object -First 1
					if ($FoundRoles) { $RolesFile = $FoundRoles.FullName }
				}
			} else {
				$BaseDirForRoles = if ($A.IsDirect) { $A.DumpDir } else { 
					if ($A.Format -eq 1) { $A.BaseDumpPath } else { Split-Path $A.BaseDumpPath -Parent }
				}
				if ([string]::IsNullOrWhiteSpace($BaseDirForRoles)) { $BaseDirForRoles = $A.DumpDir }
				$RolesFile = Join-Path $BaseDirForRoles -ChildPath "roles_$Timestamp.sql"
			}

			if ($A.RolesChecked -and ($A.IsDirect -or $A.IsExport)) {
				$A.State.Status = $A.L['Roles']
				$ArgsStr = "-h `"$($A.SrcHost)`" -p $($A.SrcPort) -U `"$($A.SrcUser)`" --roles-only -f `"$RolesFile`""
				$Log = Join-Path $A.LogDir "pg_dumpall_roles_$Timestamp.log"
				$Code = Run-Tool -Exe $PgDumpAllExe -CmdArgs $ArgsStr -LogFile $Log -EnvVars @{"PGPASSWORD"=$A.SrcPass}
				if ($Code -ne 0) { throw "Roles export failed. See log: $Log" }
			}

			if ($A.RolesChecked -and ($A.IsDirect -or $A.IsImport)) {
				if (-not [string]::IsNullOrEmpty($RolesFile) -and (Test-Path $RolesFile)) {
					$A.State.Status = $A.L['Roles']
					$ArgsStr = "-h `"$($A.TgtHost)`" -p $($A.TgtPort) -U `"$($A.TgtUser)`" -d `"$($A.TgtMaintDb)`" -f `"$RolesFile`""
					$Log = Join-Path $A.LogDir "psql_roles_$Timestamp.log"
					$Code = Run-Tool -Exe $PsqlExe -CmdArgs $ArgsStr -LogFile $Log -EnvVars @{"PGPASSWORD"=$A.TgtPass}
				}
			}

			$TotalSteps = if ($A.IsDirect) { $A.SourceDbs.Count * 2 } elseif ($A.IsExport -or $A.IsMysql) { $A.SourceDbs.Count } else { $A.TargetFiles.Count }
			if ($TotalSteps -eq 0) { $TotalSteps = 1 }
			$CurrentStep = 0

			if ($A.IsDirect -or $A.IsExport) {
				foreach ($Db in $A.SourceDbs) {
					$A.State.Status = ($A.L['Dumping'] -f $Db)
					$FmtSwitch = if ($A.Format -eq 1) { "d" } else { "c" }
					$BaseP = $A.BaseDumpPath
					
					$DumpTarget = ""
					if ($A.IsDirect) {
						$DumpTarget = Join-Path $A.DumpDir "temp_${Db}_$Timestamp"
						if ($A.Format -eq 0) { $DumpTarget += ".dump" }
					} else {
						if ($A.Format -eq 1) {
							if ($A.SourceDbs.Count -gt 1) { $DumpTarget = Join-Path $BaseP $Db } else { $DumpTarget = $BaseP }
						} else {
							if ($A.SourceDbs.Count -gt 1) {
								if ($BaseP.EndsWith(".dump")) { $BaseP = $BaseP.Substring(0, $BaseP.Length - 5) }
								$DumpTarget = "${BaseP}_${Db}.dump"
							} else {
								$DumpTarget = $BaseP
								if (-not $DumpTarget.EndsWith(".dump")) { $DumpTarget += ".dump" }
							}
						}
					}
					
					$ArgsStr = "-h `"$($A.SrcHost)`" -p $($A.SrcPort) -U `"$($A.SrcUser)`" -F$FmtSwitch -f `"$DumpTarget`""
					if ($A.Format -eq 1 -and $A.Jobs -gt 1) { $ArgsStr += " -j $($A.Jobs)" }
					if ($A.SchemaOnly) { $ArgsStr += " --schema-only" }
					if ($A.DataOnly) { $ArgsStr += " --data-only" }
					$ArgsStr += " `"$Db`""
					
					$Log = Join-Path $A.LogDir "pg_dump_${Db}_$Timestamp.log"
					$Code = Run-Tool -Exe $PgDumpExe -CmdArgs $ArgsStr -LogFile $Log -EnvVars @{"PGPASSWORD"=$A.SrcPass}
					if ($Code -ne 0) { throw "pg_dump failed for $Db. See log: $Log" }
					
					$CurrentStep++
					$A.State.Progress = [math]::Min(100, [math]::Floor(($CurrentStep / $TotalSteps) * 100))

					if ($A.IsDirect) {
						$A.State.Status = ($A.L['Restoring'] -f $Db)
						$ArgsStr = "-h `"$($A.TgtHost)`" -p $($A.TgtPort) -U `"$($A.TgtUser)`" -d `"$($A.TgtMaintDb)`""
						if (-not $A.DataOnly) { $ArgsStr += " --clean --if-exists --create" }
						if ($A.Jobs -gt 1) { $ArgsStr += " -j $($A.Jobs)" }
						$ArgsStr += " `"$DumpTarget`""
						
						$Log = Join-Path $A.LogDir "pg_restore_${Db}_$Timestamp.log"
						$Code = Run-Tool -Exe $PgRestoreExe -CmdArgs $ArgsStr -LogFile $Log -EnvVars @{"PGPASSWORD"=$A.TgtPass}
						if ($Code -ne 0) { 
							$A.Dispatcher.Invoke([System.Action]{
								$A.LogBox.AppendText("`r`n[WARNING] pg_restore finished with warnings for $Db. Migration continued.`r`n`r`n")
								$A.LogBox.ScrollToEnd()
							})
						}
						
						$CurrentStep++
						$A.State.Progress = [math]::Min(100, [math]::Floor(($CurrentStep / $TotalSteps) * 100))
						
						Remove-Item -Path $DumpTarget -Recurse -Force -ErrorAction SilentlyContinue
					}
				}
			}

			if ($A.IsImport) {
				foreach ($File in $A.TargetFiles) {
					$FileName = Split-Path -Path $File -Leaf
					$A.State.Status = ($A.L['Restoring'] -f $FileName)
					
					$ArgsStr = "-h `"$($A.TgtHost)`" -p $($A.TgtPort) -U `"$($A.TgtUser)`" -d `"$($A.TgtMaintDb)`""
					if (-not $A.DataOnly) { $ArgsStr += " --clean --if-exists --create" }
					if ($A.Jobs -gt 1) { $ArgsStr += " -j $($A.Jobs)" }
					$ArgsStr += " `"$File`""
					
					$Log = Join-Path $A.LogDir "pg_restore_${FileName}_$Timestamp.log"
					$Code = Run-Tool -Exe $PgRestoreExe -CmdArgs $ArgsStr -LogFile $Log -EnvVars @{"PGPASSWORD"=$A.TgtPass}
					if ($Code -ne 0) { 
						$A.Dispatcher.Invoke([System.Action]{
							$A.LogBox.AppendText("`r`n[WARNING] pg_restore finished with warnings for $FileName. Migration continued.`r`n`r`n")
							$A.LogBox.ScrollToEnd()
						})
					}
					
					$CurrentStep++
					$A.State.Progress = [math]::Min(100, [math]::Floor(($CurrentStep / $TotalSteps) * 100))
				}
			}

            if ($A.IsMysql) {
				if (-not (Test-Path $A.PgLoaderFile)) { throw "pgloader.jar nicht gefunden unter: $($A.PgLoaderFile)" }
				
				foreach ($Db in $A.SourceDbs) {
					$A.State.Status = "Migriere MySQL Datenbank: $Db"
					$Log = Join-Path $A.LogDir "pgloader_${Db}_$Timestamp.log"
					
                    # Escape passwords for URIs
                    $escSrcPass = [System.Uri]::EscapeDataString($A.SrcPass)
                    $escTgtPass = [System.Uri]::EscapeDataString($A.TgtPass)
                    
					$SrcUri = "mysql://$($A.SrcUser):${escSrcPass}@$($A.SrcHost):$($A.SrcPort)/$Db"
					$TgtUri = "postgresql://$($A.TgtUser):${escTgtPass}@$($A.TgtHost):$($A.TgtPort)/$Db"
					
					$ArgsStr = "-jar `"$($A.PgLoaderFile)`" `"$SrcUri`" `"$TgtUri`""
					$Code = Run-Tool -Exe "java" -CmdArgs $ArgsStr -LogFile $Log -EnvVars @{}
					if ($Code -ne 0) { 
                        $A.Dispatcher.Invoke([System.Action]{
							$A.LogBox.AppendText("`r`n[WARNING] pgloader finished with warnings for $Db. See log.`r`n`r`n")
							$A.LogBox.ScrollToEnd()
						})
                    }
					
					$CurrentStep++
					$A.State.Progress = [math]::Min(100, [math]::Floor(($CurrentStep / $TotalSteps) * 100))
				}
            }

			if ($A.VerifyMode -gt 0) {
				$A.State.Status = ($A.L['Verifying'] -f "Roles")
				
				$VerifyLog = Join-Path $A.LogDir "verify_report_$Timestamp.txt"
				$VOut = @("--- PostgreSQL Migration Verification Report ---", "Date: $(Get-Date)", "Mode: $(if ($A.VerifyMode -eq 1) {'Schnellcheck'} else {'Präzise'})", "")
				$Errors = 0

				# 1. Verify Roles
				if ($A.RolesChecked -and ($A.IsDirect -or $A.IsExport)) {
					$VOut += ">>> VERIFYING ROLES"
					$Q = "SELECT rolname FROM pg_roles;"
					$env:PGPASSWORD = $A.SrcPass
					$SrcRoles = & $PsqlExe -h $A.SrcHost -p $A.SrcPort -U $A.SrcUser -d "postgres" -t -A -c $Q | Where-Object { $_.Trim() -ne "" }
					
					$env:PGPASSWORD = $A.TgtPass
					$TgtRoles = & $PsqlExe -h $A.TgtHost -p $A.TgtPort -U $A.TgtUser -d $A.TgtMaintDb -t -A -c $Q | Where-Object { $_.Trim() -ne "" }
					$env:PGPASSWORD = ""
					
					$MissingRoles = @()
					foreach ($R in $SrcRoles) {
						if ($TgtRoles -notcontains $R) { $MissingRoles += $R }
					}
					
					if ($MissingRoles.Count -eq 0) {
						$VOut += "[OK] All source roles exist on target."
					} else {
						$VOut += "[FAIL] Missing roles on target: $($MissingRoles -join ', ')"
						$Errors++
					}
					$VOut += ""
				}

				# 2. Verify Databases & Tables
				$VOut += ">>> VERIFYING DATABASES AND TABLES"
				$QDb = "SELECT datname FROM pg_database;"
				$env:PGPASSWORD = $A.TgtPass
				$TgtDbs = & $PsqlExe -h $A.TgtHost -p $A.TgtPort -U $A.TgtUser -d $A.TgtMaintDb -t -A -c $QDb | Where-Object { $_.Trim() -ne "" }
				$env:PGPASSWORD = ""
				
				$DbsToCheck = if ($A.IsDirect -or $A.IsExport) { $A.SourceDbs } else { @() }
				
				foreach ($Db in $DbsToCheck) {
					$A.State.Status = ($A.L['Verifying'] -f $Db)
					$VOut += ">> Database: $Db"
					if ($TgtDbs -notcontains $Db) {
						$VOut += "[FAIL] Database $Db does not exist on target!"
						$Errors++
						continue
					}
					
					$VOut += "[OK] Database $Db exists."
					
					if ($A.VerifyMode -eq 1) {
						$QT = "SELECT schemaname || '.' || relname || '|' || n_live_tup FROM pg_stat_user_tables;"
					} else {
						$QT = "DO `$X`$ DECLARE r RECORD; c BIGINT; cols TEXT; BEGIN FOR r IN SELECT table_schema, table_name FROM information_schema.tables WHERE table_type='BASE TABLE' AND table_schema NOT IN ('pg_catalog', 'information_schema') LOOP EXECUTE 'SELECT COUNT(*) FROM ' || quote_ident(r.table_schema) || '.' || quote_ident(r.table_name) INTO c; SELECT string_agg(column_name::text, ',' ORDER BY ordinal_position) INTO cols FROM information_schema.columns WHERE table_schema=r.table_schema AND table_name=r.table_name; RAISE NOTICE 'TBL:%|%|%', r.table_schema || '.' || r.table_name, c, cols; END LOOP; END`$X`$;"
					}

					function Get-DbStats($HostName, $Port, $User, $DbName, $Pass, $Query, $Mode) {
						$Si = New-Object System.Diagnostics.ProcessStartInfo
						$Si.FileName = $PsqlExe
						$Si.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d `"$DbName`" -t -A -c `"$Query`""
						$Si.UseShellExecute = $false
						$Si.RedirectStandardOutput = $true
						$Si.RedirectStandardError = $true
						$Si.CreateNoWindow = $true
						$Si.EnvironmentVariables["PGPASSWORD"] = $Pass
						$Proc = [System.Diagnostics.Process]::Start($Si)
						$OutTask = $Proc.StandardOutput.ReadToEndAsync()
						$ErrTask = $Proc.StandardError.ReadToEndAsync()
						[System.Threading.Tasks.Task]::WaitAll($OutTask, $ErrTask)
						$Out = $OutTask.Result
						$Err = $ErrTask.Result
						$Proc.WaitForExit()
						
						$Map = @{}
						if ($Mode -eq 1) {
							$Lines = $Out -split "`n" | Where-Object { $_.Trim() -ne "" }
							foreach ($L in $Lines) {
								$Parts = $L.Trim() -split "\|"
								if ($Parts.Length -ge 2) { $Map[$Parts[0]] = $Parts[1] }
							}
						} else {
							$Lines = $Err -split "`n" | Where-Object { $_.StartsWith("NOTICE:  TBL:") }
							foreach ($L in $Lines) {
								$Clean = $L.Substring(13).Trim()
								$Parts = $Clean -split "\|"
								if ($Parts.Length -ge 3) {
									$Map[$Parts[0]] = @{ Count = $Parts[1]; Cols = $Parts[2] }
								}
							}
						}
						return $Map
					}
					
					$SrcStats = Get-DbStats $A.SrcHost $A.SrcPort $A.SrcUser $Db $A.SrcPass $QT $A.VerifyMode
					$TgtStats = Get-DbStats $A.TgtHost $A.TgtPort $A.TgtUser $Db $A.TgtPass $QT $A.VerifyMode
					
					$TableErrors = 0
					foreach ($T in $SrcStats.Keys) {
						if (-not $TgtStats.ContainsKey($T)) {
							$VOut += "[FAIL] Table $T is missing on target."
							$TableErrors++
						} else {
							if ($A.VerifyMode -eq 1) {
								$SC = $SrcStats[$T]; $TC = $TgtStats[$T]
								if ($SC -ne $TC) {
									$VOut += "[WARN] Table $T row count mismatch (Est. Src: $SC, Tgt: $TC)."
									$TableErrors++
								}
							} else {
								$SC = $SrcStats[$T].Count; $TC = $TgtStats[$T].Count
								$SCols = $SrcStats[$T].Cols; $TCols = $TgtStats[$T].Cols
								if ($SCols -ne $TCols) {
									$VOut += "[FAIL] Table $T column structure mismatch."
									$TableErrors++
								} elseif ($SC -ne $TC) {
									$VOut += "[FAIL] Table $T row count mismatch (Exact Src: $SC, Tgt: $TC)."
									$TableErrors++
								}
							}
						}
					}
					if ($TableErrors -eq 0) {
						$VOut += "[OK] All $($SrcStats.Count) tables match."
					} else {
						$Errors += $TableErrors
					}
					$VOut += ""
				}
				
				Set-Content -Path $VerifyLog -Value ($VOut -join "`r`n")
				
				if ($Errors -gt 0) {
					throw ($A.L['VerifyFail'] + " ($Errors errors)")
				}
			}

			$A.State.Progress = 100
			$A.State.Status = $A.L['Ready']
			$A.State.Color = "LimeGreen"

		} catch {
			$A.State.Status = $_.Exception.Message
			$A.State.Color = "Red"
		} finally {
			$A.State.IsRunning = $false
			if ($A.IsDirect -and -not [string]::IsNullOrEmpty($RolesFile)) {
				Remove-Item -Path $RolesFile -Force -ErrorAction SilentlyContinue
			}
		}
	})

	[void]$script:PS.AddArgument($RunArgs)
	$script:AsyncResult = $script:PS.BeginInvoke()

	$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
	$script:Timer.Interval = [TimeSpan]::FromMilliseconds(200)
	$script:Timer.add_Tick({
		$Status.Text = $script:State.Status
		try { $Status.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString([System.Drawing.Color]::FromName($script:State.Color)) } catch {}
		$ProgressBar.Value = $script:State.Progress
		
		if (-not $script:State.IsRunning) {
			$script:Timer.Stop()
			$BtnRun.IsEnabled = $true
			if ($script:State.Color -eq "LimeGreen") {
				[System.Windows.MessageBox]::Show($L['Success'], "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
			}
			if ($null -ne $script:PS) {
				try { [void]$script:PS.EndInvoke($script:AsyncResult) } catch {}
				$script:PS.Dispose()
			}
			if ($null -ne $script:Runspace) {
				$script:Runspace.Close()
				$script:Runspace.Dispose()
			}
		}
	})
	$script:Timer.Start()
})

$Window.ShowDialog() | Out-Null

