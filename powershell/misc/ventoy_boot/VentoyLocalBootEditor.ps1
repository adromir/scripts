<#
.SYNOPSIS
	Ventoy Local Boot Configurator
.AUTHOR
	Adromir
#>

# 1. Admin-Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
	$scriptPath = $PSCommandPath
	if ([string]::IsNullOrWhiteSpace($scriptPath)) {
		$scriptPath = Join-Path $env:TEMP "VentoyLocalBootEditor_Elevated.ps1"
		[System.IO.File]::WriteAllText($scriptPath, $MyInvocation.MyCommand.ScriptBlock.Ast.Extent.Text, [System.Text.UTF8Encoding]::new($true))
	}
	
	$currentExe = (Get-Process -Id $PID).Path
	if ([string]::IsNullOrWhiteSpace($currentExe) -or -not (Test-Path $currentExe)) {
		$currentExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
	}
	
	Start-Process -FilePath $currentExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
	Exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Pfade ermitteln
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
	$scriptDir = Split-Path -Parent $PSCommandPath
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
	$scriptDir = (Get-Location).Path
}

$xamlPath = Join-Path $scriptDir "MainWindow.xaml"
$langDir  = Join-Path $scriptDir "lang"

if (-not (Test-Path $xamlPath)) {
	[System.Windows.MessageBox]::Show("Die Datei MainWindow.xaml wurde nicht gefunden in:`n$xamlPath", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	Exit
}

# 2. Sprachen laden
$global:langData = @{}
$dePath = Join-Path $langDir "de.json"
$enPath = Join-Path $langDir "en.json"

if (Test-Path $dePath) {
	try { $global:langData['de'] = Get-Content -Path $dePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
if (Test-Path $enPath) {
	try { $global:langData['en'] = Get-Content -Path $enPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

# Systemsprache ermitteln
$systemLang = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName.ToLower()
$global:currentLang = if ($global:langData.ContainsKey($systemLang)) { $systemLang } else { "en" }

function T {
	param([string]$Key, [object[]]$FormatArgs)
	$dict = $global:langData[$global:currentLang]
	if ($null -ne $dict -and $null -ne $dict.$Key) {
		$val = [string]$dict.$Key
		if ($FormatArgs -and $FormatArgs.Count -gt 0) {
			return ($val -f $FormatArgs)
		}
		return $val
	}
	return $Key
}

# 3. XAML laden
try {
	$xamlText = [System.IO.File]::ReadAllText($xamlPath, [System.Text.Encoding]::UTF8)
	$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlText))
	$window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
	[System.Windows.MessageBox]::Show("Fehler beim Laden von MainWindow.xaml:`n$_", "XAML Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	Exit
}

# UI-Elemente referenzieren
$cbVentoyDrive          = $window.FindName("cbVentoyDrive")
$btnLoadVentoy          = $window.FindName("btnLoadVentoy")
$lblVentoyDrive         = $window.FindName("lblVentoyDrive")
$lblLanguage            = $window.FindName("lblLanguage")
$cbLanguage             = $window.FindName("cbLanguage")
$tcMain                 = $window.FindName("tcMain")

# Tab 1: Partitionen
$tabPartitions          = $window.FindName("tabPartitions")
$lblPartitionsHeader    = $window.FindName("lblPartitionsHeader")
$dgVolumes              = $window.FindName("dgVolumes")
$colDisk                = $window.FindName("colDisk")
$colPart                = $window.FindName("colPart")
$colLetter              = $window.FindName("colLetter")
$colLabel               = $window.FindName("colLabel")
$colSize                = $window.FindName("colSize")
$colFs                  = $window.FindName("colFs")
$colType                = $window.FindName("colType")
$colRecommendation      = $window.FindName("colRecommendation")
$colGrubUuid            = $window.FindName("colGrubUuid")
$borderPartitionTip     = $window.FindName("borderPartitionTip")
$txtPartitionTip        = $window.FindName("txtPartitionTip")
$lblMenuNameVolume      = $window.FindName("lblMenuNameVolume")
$txtMenuNameVolume      = $window.FindName("txtMenuNameVolume")
$lblBootloaderType      = $window.FindName("lblBootloaderType")
$cbBootloaderType       = $window.FindName("cbBootloaderType")
$cbiBootWinUefi         = $window.FindName("cbiBootWinUefi")
$cbiBootUbuntu          = $window.FindName("cbiBootUbuntu")
$cbiBootDebian          = $window.FindName("cbiBootDebian")
$cbiBootFedora          = $window.FindName("cbiBootFedora")
$cbiBootArch            = $window.FindName("cbiBootArch")
$cbiBootOpenSuse        = $window.FindName("cbiBootOpenSuse")
$cbiBootSystemd         = $window.FindName("cbiBootSystemd")
$cbiBootGenericUefi     = $window.FindName("cbiBootGenericUefi")
$cbiBootWinBios         = $window.FindName("cbiBootWinBios")
$cbiBootChainload       = $window.FindName("cbiBootChainload")
$chkSetDefaultVolume    = $window.FindName("chkSetDefaultVolume")
$btnAddVolume           = $window.FindName("btnAddVolume")

# Tab 2: Einträge verwalten
$tabManage              = $window.FindName("tabManage")
$lblManageHeader        = $window.FindName("lblManageHeader")
$lblGrubTimeout         = $window.FindName("lblGrubTimeout")
$cbGrubTimeout          = $window.FindName("cbGrubTimeout")
$lbEntries              = $window.FindName("lbEntries")
$btnRefreshEntries      = $window.FindName("btnRefreshEntries")
$btnMoveUp              = $window.FindName("btnMoveUp")
$btnMoveDown            = $window.FindName("btnMoveDown")
$btnDeleteEntry         = $window.FindName("btnDeleteEntry")
$lblEditEntryHeader     = $window.FindName("lblEditEntryHeader")
$lblEditEntryName       = $window.FindName("lblEditEntryName")
$txtEditEntryName       = $window.FindName("txtEditEntryName")
$lblEditBootType        = $window.FindName("lblEditBootType")
$cbEditBootloaderType   = $window.FindName("cbEditBootloaderType")
$cbiEditBootWinUefi     = $window.FindName("cbiEditBootWinUefi")
$cbiEditBootUbuntu      = $window.FindName("cbiEditBootUbuntu")
$cbiEditBootDebian      = $window.FindName("cbiEditBootDebian")
$cbiEditBootFedora      = $window.FindName("cbiEditBootFedora")
$cbiEditBootArch        = $window.FindName("cbiEditBootArch")
$cbiEditBootOpenSuse    = $window.FindName("cbiEditBootOpenSuse")
$cbiEditBootSystemd     = $window.FindName("cbiEditBootSystemd")
$cbiEditBootGenericUefi = $window.FindName("cbiEditBootGenericUefi")
$cbiEditBootWinBios     = $window.FindName("cbiEditBootWinBios")
$cbiEditBootChainload   = $window.FindName("cbiEditBootChainload")
$lblEditUuid            = $window.FindName("lblEditUuid")
$txtEditEntryUuid       = $window.FindName("txtEditEntryUuid")
$btnUpdateEntry         = $window.FindName("btnUpdateEntry")
$btnSetDefault          = $window.FindName("btnSetDefault")

# Tab 3: Ventoy JSON
$tabSettings            = $window.FindName("tabSettings")
$lblJsonHeader          = $window.FindName("lblJsonHeader")
$lblJsonAutoBootTitle   = $window.FindName("lblJsonAutoBootTitle")
$lblJsonThemeTitle      = $window.FindName("lblJsonThemeTitle")
$lblJsonBypassTitle     = $window.FindName("lblJsonBypassTitle")
$txtJsonAutoBootTip     = $window.FindName("txtJsonAutoBootTip")
$lblResolution          = $window.FindName("lblResolution")
$cbResolution           = $window.FindName("cbResolution")
$lblThemePath           = $window.FindName("lblThemePath")
$txtThemePath           = $window.FindName("txtThemePath")
$lblMenuMode            = $window.FindName("lblMenuMode")
$cbMenuMode             = $window.FindName("cbMenuMode")
$cbiMenuModeList        = $window.FindName("cbiMenuModeList")
$cbiMenuModeTree        = $window.FindName("cbiMenuModeTree")
$lblVentoyTimeout       = $window.FindName("lblVentoyTimeout")
$txtVentoyTimeout       = $window.FindName("txtVentoyTimeout")
$lblTimeoutUnit         = $window.FindName("lblTimeoutUnit")
$lblDefaultAction       = $window.FindName("lblDefaultAction")
$cbDefaultAction        = $window.FindName("cbDefaultAction")
$cbiActionNone          = $window.FindName("cbiActionNone")
$cbiActionIso           = $window.FindName("cbiActionIso")
$cbiActionF6            = $window.FindName("cbiActionF6")
$cbiActionF4            = $window.FindName("cbiActionF4")
$cbiActionF5            = $window.FindName("cbiActionF5")
$cbiActionF2            = $window.FindName("cbiActionF2")
$cbiActionExit          = $window.FindName("cbiActionExit")
$lblDefaultIso          = $window.FindName("lblDefaultIso")
$cbDefaultIso           = $window.FindName("cbDefaultIso")
$btnBrowseIso           = $window.FindName("btnBrowseIso")
$btnDownloadIso         = $window.FindName("btnDownloadIso")
$chkWin11Bypass         = $window.FindName("chkWin11Bypass")
$btnSaveJson            = $window.FindName("btnSaveJson")

# Tab 3 Card 2: Persistence
$lblJsonPersistenceTitle = $window.FindName("lblJsonPersistenceTitle")
$txtJsonPersistenceTip   = $window.FindName("txtJsonPersistenceTip")
$lbPersistence           = $window.FindName("lbPersistence")
$btnAddPersistence       = $window.FindName("btnAddPersistence")
$btnRemovePersistence    = $window.FindName("btnRemovePersistence")
$btnTogglePersistCreator = $window.FindName("btnTogglePersistCreator")
$borderPersistCreator    = $window.FindName("borderPersistCreator")
$lblPersistCreatorTitle  = $window.FindName("lblPersistCreatorTitle")
$lblPersistDistro        = $window.FindName("lblPersistDistro")
$cbPersistDistro         = $window.FindName("cbPersistDistro")
$lblPersistSize          = $window.FindName("lblPersistSize")
$cbPersistSize           = $window.FindName("cbPersistSize")
$lblPersistFs            = $window.FindName("lblPersistFs")
$cbPersistFs             = $window.FindName("cbPersistFs")
$lblPersistFileName      = $window.FindName("lblPersistFileName")
$txtPersistFileName      = $window.FindName("txtPersistFileName")
$btnDoCreatePersistFile  = $window.FindName("btnDoCreatePersistFile")
$txtPersistProgress      = $window.FindName("txtPersistProgress")

# Tab 4: Vorschau & Speichern
$tabPreview             = $window.FindName("tabPreview")
$txtPreview             = $window.FindName("txtPreview")
$btnSaveGrub            = $window.FindName("btnSaveGrub")

$global:volList         = @()
$global:persistenceList = @()
$global:availableIsos   = @()
$global:availableDats   = @()

# 4. Lokalisierung anwenden
function Apply-Localization {
	param([string]$LangCode)
	if (-not $global:langData.ContainsKey($LangCode)) { return }
	$global:currentLang = $LangCode

	$window.Title               = T "WindowTitle"
	$lblVentoyDrive.Text        = T "VentoyDriveLabel"
	$btnLoadVentoy.Content      = T "BtnRefreshDrives"
	$lblLanguage.Text           = T "LanguageLabel"

	# Tabs
	$tabPartitions.Header       = T "TabPartitions"
	$tabManage.Header           = T "TabManage"
	$tabSettings.Header         = T "TabSettings"
	$tabPreview.Header          = T "TabPreview"

	# Tab 1: Partitionen
	$lblPartitionsHeader.Text   = T "PartitionsHeader"
	if ($colDisk)            { $colDisk.Header           = T "ColDisk" }
	if ($colPart)            { $colPart.Header           = T "ColPart" }
	if ($colLetter)          { $colLetter.Header         = T "ColLetter" }
	if ($colLabel)          { $colLabel.Header          = T "ColLabel" }
	if ($colSize)           { $colSize.Header           = T "ColSize" }
	if ($colFs)              { $colFs.Header             = T "ColFs" }
	if ($colType)            { $colType.Header           = T "ColType" }
	if ($colRecommendation)  { $colRecommendation.Header = T "ColRecommendation" }
	if ($colGrubUuid)        { $colGrubUuid.Header       = T "ColGrubUuid" }

	$lblMenuNameVolume.Text     = T "MenuNameLabel"
	$lblBootloaderType.Text     = T "BootloaderTypeLabel"
	if ($cbiBootWinUefi)     { $cbiBootWinUefi.Content     = T "BootTypeWinUefi" }
	if ($cbiBootUbuntu)      { $cbiBootUbuntu.Content      = T "BootTypeUbuntu" }
	if ($cbiBootDebian)      { $cbiBootDebian.Content      = T "BootTypeDebian" }
	if ($cbiBootFedora)      { $cbiBootFedora.Content      = T "BootTypeFedora" }
	if ($cbiBootArch)        { $cbiBootArch.Content        = T "BootTypeArch" }
	if ($cbiBootOpenSuse)    { $cbiBootOpenSuse.Content    = T "BootTypeOpenSuse" }
	if ($cbiBootSystemd)     { $cbiBootSystemd.Content     = T "BootTypeSystemd" }
	if ($cbiBootGenericUefi) { $cbiBootGenericUefi.Content = T "BootTypeGenericUefi" }
	if ($cbiBootWinBios)     { $cbiBootWinBios.Content     = T "BootTypeWinBios" }
	if ($cbiBootChainload)   { $cbiBootChainload.Content   = T "BootTypeChainload" }
	$chkSetDefaultVolume.Content = T "SetDefaultLabel"
	$btnAddVolume.Content       = T "BtnAddVolume"

	# Tab 2: Einträge verwalten
	$lblManageHeader.Text       = T "ManageHeader"
	$lblGrubTimeout.Text        = T "GrubTimeoutLabel"
	$btnSetDefault.Content      = T "BtnSetDefault"
	$btnRefreshEntries.Content  = T "BtnRefreshEntries"
	$btnMoveUp.Content          = T "BtnMoveUp"
	$btnMoveDown.Content        = T "BtnMoveDown"
	$btnDeleteEntry.Content     = T "BtnDeleteEntry"
	$lblEditEntryHeader.Text    = T "EditEntryHeader"
	$lblEditEntryName.Text      = T "EditEntryNameLabel"
	$lblEditBootType.Text       = T "EditBootTypeLabel"
	if ($cbiEditBootWinUefi)     { $cbiEditBootWinUefi.Content     = T "BootTypeWinUefi" }
	if ($cbiEditBootUbuntu)      { $cbiEditBootUbuntu.Content      = T "BootTypeUbuntu" }
	if ($cbiEditBootDebian)      { $cbiEditBootDebian.Content      = T "BootTypeDebian" }
	if ($cbiEditBootFedora)      { $cbiEditBootFedora.Content      = T "BootTypeFedora" }
	if ($cbiEditBootArch)        { $cbiEditBootArch.Content        = T "BootTypeArch" }
	if ($cbiEditBootOpenSuse)    { $cbiEditBootOpenSuse.Content    = T "BootTypeOpenSuse" }
	if ($cbiEditBootSystemd)     { $cbiEditBootSystemd.Content     = T "BootTypeSystemd" }
	if ($cbiEditBootGenericUefi) { $cbiEditBootGenericUefi.Content = T "BootTypeGenericUefi" }
	if ($cbiEditBootWinBios)     { $cbiEditBootWinBios.Content     = T "BootTypeWinBios" }
	if ($cbiEditBootChainload)   { $cbiEditBootChainload.Content   = T "BootTypeChainload" }
	$lblEditUuid.Text           = T "EditUuidLabel"
	$btnUpdateEntry.Content     = T "BtnUpdateEntry"

	# Tab 3: Settings
	$lblJsonHeader.Text         = T "JsonHeader"
	if ($lblJsonAutoBootTitle)   { $lblJsonAutoBootTitle.Text   = T "JsonAutoBootTitle" }
	if ($lblJsonThemeTitle)      { $lblJsonThemeTitle.Text      = T "JsonThemeTitle" }
	if ($lblJsonBypassTitle)     { $lblJsonBypassTitle.Text     = T "JsonBypassTitle" }
	if ($lblJsonPersistenceTitle){ $lblJsonPersistenceTitle.Text = T "JsonPersistenceTitle" }
	if ($txtJsonPersistenceTip)  { $txtJsonPersistenceTip.Text  = T "JsonPersistenceTip" }
	if ($btnAddPersistence)      { $btnAddPersistence.Content   = T "BtnAddPersistence" }
	if ($btnRemovePersistence)   { $btnRemovePersistence.Content= T "BtnRemovePersistence" }
	if ($btnTogglePersistCreator){ $btnTogglePersistCreator.Content = T "BtnCreatePersistence" }
	if ($lblPersistDistro)       { $lblPersistDistro.Text       = T "PersistenceDistroLabel" }
	if ($lblPersistSize)         { $lblPersistSize.Text         = T "PersistenceSizeLabel" }
	if ($lblPersistFs)           { $lblPersistFs.Text           = T "PersistenceFsLabel" }
	if ($lblPersistFileName)     { $lblPersistFileName.Text     = T "PersistenceFileNameLabel" }

	$lblResolution.Text          = T "ResolutionLabel"
	$lblThemePath.Text           = T "ThemePathLabel"
	$lblMenuMode.Text            = T "MenuModeLabel"
	if ($cbiMenuModeList)        { $cbiMenuModeList.Content = T "MenuModeList" }
	if ($cbiMenuModeTree)        { $cbiMenuModeTree.Content = T "MenuModeTree" }
	$lblVentoyTimeout.Text       = T "VentoyTimeoutLabel"
	$lblDefaultAction.Text       = T "DefaultActionLabel"
	if ($lblDefaultIso)          { $lblDefaultIso.Text      = T "DefaultIsoLabel" }
	if ($btnBrowseIso)           { $btnBrowseIso.Content    = T "BrowseIsoBtn" }
	if ($btnDownloadIso)         { $btnDownloadIso.Content  = T "BtnDownloadIso" }
	if ($cbiActionNone)          { $cbiActionNone.Content   = T "ActionNone" }
	if ($cbiActionIso)           { $cbiActionIso.Content    = T "ActionIso" }
	if ($cbiActionF6)            { $cbiActionF6.Content     = T "ActionF6" }
	if ($cbiActionF4)            { $cbiActionF4.Content     = T "ActionF4" }
	if ($cbiActionF5)            { $cbiActionF5.Content     = T "ActionF5" }
	if ($cbiActionF2)            { $cbiActionF2.Content     = T "ActionF2" }
	if ($cbiActionExit)          { $cbiActionExit.Content   = T "ActionExit" }
	$chkWin11Bypass.Content      = T "Win11BypassLabel"
	$btnSaveJson.Content         = T "BtnSaveJson"

	# Tab 4: Preview
	$btnSaveGrub.Content         = T "BtnSaveGrub"

	Update-PartitionTip
	Update-TimeoutUiState
}

function Update-PartitionTip {
	$selectedVol = $dgVolumes.SelectedItem
	if ($null -eq $selectedVol) {
		$txtPartitionTip.Text = T "TipDefault"
		$borderPartitionTip.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#eef6fc")
		$borderPartitionTip.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#b8daff")
		return
	}

	$letter = $selectedVol.DriveLetter
	$isEfi = ($selectedVol.PartitionTypeRaw -eq 'System' -or $selectedVol.BootRoleKey -eq 'RoleEfi')
	
	if ($isEfi) {
		$txtPartitionTip.Text = T "TipEfi"
		$borderPartitionTip.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#e8f5e9")
		$borderPartitionTip.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#81c784")
	} elseif ($letter -eq 'C:' -or $selectedVol.BootRoleKey -eq 'RoleWindows') {
		$txtPartitionTip.Text = T "TipWindows"
		$borderPartitionTip.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#fff8e1")
		$borderPartitionTip.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ffe082")
	} elseif ($selectedVol.BootRoleKey -eq 'RoleRecovery') {
		$txtPartitionTip.Text = T "TipRecovery"
		$borderPartitionTip.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#fbe9e7")
		$borderPartitionTip.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ffab91")
	} else {
		$txtPartitionTip.Text = T "TipData"
		$borderPartitionTip.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#eef6fc")
		$borderPartitionTip.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#b8daff")
	}
}

# 5. Core-Logik & Grub-Generierung
function Generate-GrubEntry {
	param(
		[string]$Name,
		[string]$BootType,
		[string]$UUID
	)

	switch ($BootType) {
		'win_uefi' {
			return @"

menuentry "$Name" --class=windows --class=os {
	insmod part_gpt
	insmod fat
	insmod ntfs
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/Microsoft/Boot/bootmgfw.efi ]; then
		chainloader /EFI/Microsoft/Boot/bootmgfw.efi
	elif [ -f /efi/Microsoft/Boot/bootmgfw.efi ]; then
		chainloader /efi/Microsoft/Boot/bootmgfw.efi
	elif [ -f /EFI/BOOT/BOOTX64.EFI ]; then
		chainloader /EFI/BOOT/BOOTX64.EFI
	fi
	boot
}
"@
		}
		'ubuntu_uefi' {
			return @"

menuentry "$Name" --class=ubuntu --class=linux --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/ubuntu/shimx64.efi ]; then
		chainloader /EFI/ubuntu/shimx64.efi
	elif [ -f /EFI/ubuntu/grubx64.efi ]; then
		chainloader /EFI/ubuntu/grubx64.efi
	else
		chainloader /EFI/BOOT/BOOTX64.EFI
	fi
	boot
}
"@
		}
		'debian_uefi' {
			return @"

menuentry "$Name" --class=debian --class=linux --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/debian/shimx64.efi ]; then
		chainloader /EFI/debian/shimx64.efi
	elif [ -f /EFI/debian/grubx64.efi ]; then
		chainloader /EFI/debian/grubx64.efi
	else
		chainloader /EFI/BOOT/BOOTX64.EFI
	fi
	boot
}
"@
		}
		'fedora_uefi' {
			return @"

menuentry "$Name" --class=fedora --class=linux --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/fedora/shimx64.efi ]; then
		chainloader /EFI/fedora/shimx64.efi
	elif [ -f /EFI/fedora/grubx64.efi ]; then
		chainloader /EFI/fedora/grubx64.efi
	else
		chainloader /EFI/BOOT/BOOTX64.EFI
	fi
	boot
}
"@
		}
		'arch_uefi' {
			return @"

menuentry "$Name" --class=arch --class=linux --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/arch/grubx64.efi ]; then
		chainloader /EFI/arch/grubx64.efi
	elif [ -f /EFI/arch/shimx64.efi ]; then
		chainloader /EFI/arch/shimx64.efi
	else
		chainloader /EFI/BOOT/BOOTX64.EFI
	fi
	boot
}
"@
		}
		'opensuse_uefi' {
			return @"

menuentry "$Name" --class=opensuse --class=linux --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/opensuse/shim.efi ]; then
		chainloader /EFI/opensuse/shim.efi
	elif [ -f /EFI/opensuse/grubx64.efi ]; then
		chainloader /EFI/opensuse/grubx64.efi
	else
		chainloader /EFI/BOOT/BOOTX64.EFI
	fi
	boot
}
"@
		}
		'systemd_uefi' {
			return @"

menuentry "$Name" --class=systemd --class=linux --class=os {
	insmod part_gpt
	insmod fat
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/systemd/systemd-bootx64.efi ]; then
		chainloader /EFI/systemd/systemd-bootx64.efi
	elif [ -f /EFI/systemd/shimx64.efi ]; then
		chainloader /EFI/systemd/shimx64.efi
	else
		chainloader /EFI/BOOT/BOOTX64.EFI
	fi
	boot
}
"@
		}
		'generic_uefi' {
			return @"

menuentry "$Name" --class=efi --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	if [ -f /EFI/BOOT/BOOTX64.EFI ]; then
		chainloader /EFI/BOOT/BOOTX64.EFI
	elif [ -f /efi/boot/bootx64.efi ]; then
		chainloader /efi/boot/bootx64.efi
	fi
	boot
}
"@
		}
		'win_bios' {
			return @"

menuentry "$Name" --class=windows --class=os {
	insmod part_msdos
	insmod ntfs
	insmod fat
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	ntldr /bootmgr
	boot
}
"@
		}
		'chainload' {
			return @"

menuentry "$Name" --class=boot_disk {
	insmod part_gpt
	insmod part_msdos
	insmod fat
	insmod ntfs
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	chainloader +1
	boot
}
"@
		}
		default {
			return @"

menuentry "$Name" --class=efi --class=os {
	insmod part_gpt
	insmod fat
	insmod ext2
	insmod chain
	search --no-floppy --fs-uuid --set=root $UUID
	terminal_output console
	chainloader /EFI/BOOT/BOOTX64.EFI
	boot
}
"@
		}
	}
}

function Set-GrubDefaultEntry {
	param([string]$EntryName)
	$text = $txtPreview.Text
	if ([string]::IsNullOrWhiteSpace($EntryName)) {
		$text = $text -replace '(?m)^\s*set\s+default\s*=\s*["'']?[^"''\r\n]+["'']?\r?\n?', ""
	} else {
		if ($text -match '(?m)^\s*set\s+default\s*=') {
			$text = $text -replace '(?m)^\s*set\s+default\s*=\s*["'']?[^"''\r\n]+["'']?', "set default=`"$EntryName`""
		} else {
			$text = "set default=`"$EntryName`"`r`n" + $text.TrimStart()
		}
	}
	$txtPreview.Text = $text
}

function Set-GrubTimeout {
	param([string]$TimeoutVal)
	$text = $txtPreview.Text
	if ([string]::IsNullOrWhiteSpace($TimeoutVal)) {
		$text = $text -replace '(?m)^\s*set\s+timeout\s*=\s*\S+\r?\n?', ""
	} else {
		if ($text -match '(?m)^\s*set\s+timeout\s*=') {
			$text = $text -replace '(?m)^\s*set\s+timeout\s*=\s*\S+', "set timeout=$TimeoutVal"
		} else {
			if ($text -match '(?m)^\s*set\s+default\s*=') {
				$text = $text -replace '(?m)^(\s*set\s+default\s*=[^\r\n]+)', "`$1`r`nset timeout=$TimeoutVal"
			} else {
				$text = "set timeout=$TimeoutVal`r`n" + $text.TrimStart()
			}
		}
	}
	$txtPreview.Text = $text
}

function Backup-File {
	param([string]$filePath)
	if (Test-Path -Path $filePath) {
		$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
		$backupPath = "${filePath}.backup_${timestamp}"
		try {
			Copy-Item -Path $filePath -Destination $backupPath -Force
			Write-Host "Backup erstellt: $backupPath"
			return $true
		} catch {
			Write-Host "Backup-Erstellung fehlgeschlagen: $_"
			return $false
		}
	}
	return $true
}

function Get-GrubUUID {
	param(
		[string]$RawDevicePath,
		[string]$FileSystem
	)

	if ([string]::IsNullOrWhiteSpace($RawDevicePath)) { return "" }

	try {
		$stream = [System.IO.FileStream]::new(
			$RawDevicePath,
			[System.IO.FileMode]::Open,
			[System.IO.FileAccess]::Read,
			[System.IO.FileShare]::ReadWrite
		)
		$buffer = New-Object byte[] 2048
		$bytesRead = $stream.Read($buffer, 0, 2048)
		$stream.Close()
		$stream.Dispose()

		if ($FileSystem -eq 'NTFS') {
			$serial = [BitConverter]::ToUInt64($buffer, 0x48)
			return ('{0:X16}' -f $serial)
		}
		elseif ($FileSystem -eq 'FAT32') {
			$serial = [BitConverter]::ToUInt32($buffer, 0x43)
			return ('{0:X4}-{1:X4}' -f (($serial -shr 16) -band 0xFFFF), ($serial -band 0xFFFF))
		}
		elseif ($FileSystem -eq 'exFAT') {
			$serial = [BitConverter]::ToUInt32($buffer, 0x64)
			return ('{0:X4}-{1:X4}' -f (($serial -shr 16) -band 0xFFFF), ($serial -band 0xFFFF))
		}
		elseif ($FileSystem -match '^FAT') {
			$serial = [BitConverter]::ToUInt32($buffer, 0x27)
			return ('{0:X4}-{1:X4}' -f (($serial -shr 16) -band 0xFFFF), ($serial -band 0xFFFF))
		}

		if ($bytesRead -ge 1144) {
			$magic = [BitConverter]::ToUInt16($buffer, 1080)
			if ($magic -eq 0xEF53) {
				$uuidBytes = New-Object byte[] 16
				[Array]::Copy($buffer, 1128, $uuidBytes, 0, 16)
				return ([guid]::new($uuidBytes)).ToString()
			}
		}
	}
	catch {
		Write-Host "UUID-Erkennung fehlgeschlagen für ${RawDevicePath}: $_"
	}

	return ""
}

function Get-AllVolumes {
	$driveObjects = @()

	try {
		$disks = @(Get-Disk -ErrorAction Stop)
		$partitions = @(Get-Partition -ErrorAction Stop | Sort-Object DiskNumber, PartitionNumber)

		foreach ($part in $partitions) {
			if ($part.Type -eq 'Reserved') { continue }

			$disk = $disks | Where-Object { $_.Number -eq $part.DiskNumber } | Select-Object -First 1

			$diskModel = if ($disk.FriendlyName) { $disk.FriendlyName } else { T "Unknown" }
			$diskBus = if ($disk.BusType) { $disk.BusType } else { "?" }
			$diskSizeGB = if ($disk.Size) { "{0:N0}" -f ($disk.Size / 1GB) } else { "?" }
			$diskInfo = "Disk $($part.DiskNumber): $diskModel ($diskBus, $diskSizeGB GB)"
			$diskShortName = "Disk $($part.DiskNumber): $diskModel"

			$letter = T "Unmounted"
			$isMounted = $false
			if ($part.DriveLetter) {
				$letter = "$($part.DriveLetter):"
				$isMounted = $true
			}

			$vol = $null
			try { $vol = $part | Get-Volume -ErrorAction SilentlyContinue } catch {}

			$label = if ($vol -and $vol.FileSystemLabel) { $vol.FileSystemLabel } else { T "LocalVolume" }
			$fs = if ($vol -and $vol.FileSystem) { $vol.FileSystem } else { "" }
			$cap = "{0:N2}" -f ($part.Size / 1GB)

			$rawType = [string]$part.Type
			$partType = T "TypeData"
			switch ($rawType) {
				'Basic'    { $partType = T "TypeData" }
				'System'   { $partType = T "TypeEfi" }
				'Recovery' { $partType = T "TypeRecovery" }
				'IFS'      { $partType = T "TypeData" }
				'Unknown'  { $partType = T "TypeUnknown" }
			}

			$bootRoleKey = "RoleData"
			if ($rawType -eq 'System' -or $part.IsSystem) {
				$bootRoleKey = "RoleEfi"
			} elseif ($part.IsBoot -or $letter -eq 'C:' -or ($isMounted -and (Test-Path "$letter\Windows\System32"))) {
				$bootRoleKey = "RoleWindows"
			} elseif ($rawType -eq 'Recovery' -or $label -match 'Recovery|Wiederherstellung') {
				$bootRoleKey = "RoleRecovery"
			} elseif ($label -match 'Ventoy|VTOYEFI') {
				$bootRoleKey = "RoleVentoy"
			} elseif ($fs -match 'ext[234]|btrfs|xfs') {
				$bootRoleKey = "RoleLinux"
			}

			$bootRole = T $bootRoleKey

			$rawPath = ""
			if ($part.AccessPaths) {
				foreach ($ap in @($part.AccessPaths)) {
					if ($ap -and $ap.StartsWith('\\?\Volume')) {
						$rawPath = $ap.TrimEnd('\').Replace('\\?\', '\\.\') 
						break
					}
				}
			}
			if ([string]::IsNullOrWhiteSpace($rawPath) -and $isMounted) {
				$rawPath = "\\.\$letter"
			}

			$uuid = Get-GrubUUID -RawDevicePath $rawPath -FileSystem $fs

			$driveObjects += [PSCustomObject]@{
				DiskInfo          = $diskInfo
				DiskShortName     = $diskShortName
				DiskNumber        = $part.DiskNumber
				PartitionNumber   = $part.PartitionNumber
				DriveLetter       = $letter
				Label             = $label
				CapacityGB        = $cap
				FileSystem        = $fs
				GrubUUID          = $uuid
				PartitionType     = $partType
				PartitionTypeRaw  = $rawType
				BootRole          = $bootRole
				BootRoleKey       = $bootRoleKey
				IsMounted         = $isMounted
			}
		}
	} catch {
		[System.Windows.MessageBox]::Show((T "AdminRequired" @($_)), (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	}

	return $driveObjects
}

function Load-VentoyDrives {
	try {
		$ventoyList = @()

		foreach ($drive in ($global:volList | Where-Object { $_.IsMounted })) {
			$driveLetter = $drive.DriveLetter
			$rootPath = "$driveLetter\"
			$ventoyPath = Join-Path -Path $rootPath -ChildPath "ventoy"
			$isVentoy = Test-Path -Path $ventoyPath -ErrorAction SilentlyContinue

			$volLabel = $drive.Label
			if ($volLabel -match "Ventoy" -or $volLabel -match "VTOYEFI") {
				$isVentoy = $true
			}

			$dispName = "$driveLetter - $volLabel"
			if ($isVentoy) {
				$dispName += " (" + (T "VentoyDetected") + ")"
			}

			$ventoyList += [PSCustomObject]@{
				Display  = $dispName
				Path     = $rootPath
				IsVentoy = $isVentoy
			}
		}

		$cbVentoyDrive.ItemsSource = $ventoyList

		$ventoyMatch = $ventoyList | Where-Object { $_.IsVentoy } | Select-Object -First 1
		if ($ventoyMatch) {
			$cbVentoyDrive.SelectedItem = $ventoyMatch
		} elseif ($ventoyList.Count -gt 0) {
			$cbVentoyDrive.SelectedIndex = 0
		}
	} catch {
		[System.Windows.MessageBox]::Show("Fehler beim Laden der Ventoy-Laufwerke: $_", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	}
}

function Load-Volumes {
	try {
		$global:volList = Get-AllVolumes
		$dgVolumes.ItemsSource = $global:volList
	} catch {
		[System.Windows.MessageBox]::Show("Fehler beim Laden der Datenträger: $_", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	}
}

function Update-TimeoutUiState {
	$actTag = ""
	if ($cbDefaultAction.SelectedItem) {
		$actTag = [string]$cbDefaultAction.SelectedItem.Tag
	} elseif (-not [string]::IsNullOrWhiteSpace($cbDefaultAction.Text)) {
		$actTag = $cbDefaultAction.Text.Trim()
	}

	$isHotkey = ($actTag -in @('F6>', 'F4>', 'F5>', 'F2>', 'VTOY_EXIT'))
	$isIso = ($actTag -eq 'ISO' -or ($actTag -ne '' -and -not $isHotkey))

	if ($isHotkey) {
		$txtVentoyTimeout.IsEnabled = $false
		$cbDefaultIso.IsEnabled = $false
		$btnBrowseIso.IsEnabled = $false
		if ($txtJsonAutoBootTip) {
			if ($actTag -eq 'F6>') {
				$txtJsonAutoBootTip.Text = T "JsonAutoBootTipF6"
			} else {
				$txtJsonAutoBootTip.Text = T "JsonAutoBootTipHotkey"
			}
		}
	} elseif ($isIso) {
		$txtVentoyTimeout.IsEnabled = $true
		$cbDefaultIso.IsEnabled = $true
		$btnBrowseIso.IsEnabled = $true
		if ($txtJsonAutoBootTip) {
			$tVal = $txtVentoyTimeout.Text.Trim()
			if ([string]::IsNullOrWhiteSpace($tVal) -or $tVal -eq "0") { $tVal = "10" }
			$txtJsonAutoBootTip.Text = T "JsonAutoBootTipIso" @($tVal)
		}
	} else {
		$txtVentoyTimeout.IsEnabled = $true
		$cbDefaultIso.IsEnabled = $false
		$btnBrowseIso.IsEnabled = $false
		if ($txtJsonAutoBootTip) {
			$txtJsonAutoBootTip.Text = T "JsonAutoBootTipNone"
		}
	}
}

function Scan-VentoyDriveFiles {
	param([string]$ventoyDrive)
	$global:availableIsos = @()
	$global:availableDats = @()

	if ([string]::IsNullOrWhiteSpace($ventoyDrive) -or -not (Test-Path $ventoyDrive)) { return }

	try {
		$files = Get-ChildItem -Path $ventoyDrive -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
			$_.FullName -notmatch '\\System Volume Information' -and $_.FullName -notmatch '\\\$RECYCLE\.BIN'
		}

		foreach ($f in $files) {
			$rel = $f.FullName.Substring($ventoyDrive.TrimEnd('\').Length).Replace('\', '/')
			if ($f.Extension -match '^\.(iso|img|vhd|vhdx|wim)$') {
				$global:availableIsos += $rel
			} elseif ($f.Extension -eq '.dat') {
				$global:availableDats += $rel
			}
		}
	} catch {}

	$cbDefaultIso.ItemsSource = $global:availableIsos
}

function Sync-PersistenceList {
	$ventoyDrive = if ($cbVentoyDrive.SelectedItem) { $cbVentoyDrive.SelectedItem.Path } else { "" }
	$items = @()

	foreach ($p in $global:persistenceList) {
		$img = $p.image
		$backend = if ($p.backend -is [array]) { $p.backend[0] } else { [string]$p.backend }
		
		$status = ""
		if (-not [string]::IsNullOrWhiteSpace($ventoyDrive)) {
			$localDat = Join-Path $ventoyDrive ($backend.TrimStart('/').Replace('/', '\'))
			if (Test-Path $localDat) {
				$len = (Get-Item $localDat).Length
				$szMB = [math]::Round($len / 1MB, 0)
				if ($szMB -ge 1024) {
					$status = " (Vorhanden: {0:N1} GB)" -f ($szMB / 1024)
				} else {
					$status = " (Vorhanden: $szMB MB)"
				}
			} else {
				$status = " (Datei nicht gefunden)"
			}
		}

		$disp = "💿 $img  ➔  💾 $backend$status"
		$items += [PSCustomObject]@{
			Image    = $img
			Backend  = $backend
			Display  = $disp
		}
	}

	$lbPersistence.ItemsSource = $items
}

function Create-VentoyPersistenceDat {
	param(
		[string]$ventoyDrive,
		[string]$DistroLabel,
		[string]$SizeTag,
		[string]$FsTag,
		[string]$RelFileName
	)

	if ([string]::IsNullOrWhiteSpace($ventoyDrive) -or -not (Test-Path $ventoyDrive)) {
		[System.Windows.MessageBox]::Show((T "SelectVentoyWarning"), (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	$txtPersistProgress.Text = "⏳ Download von Ventoy-Backend Templates..."
	$window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

	# Cache images.zip in LocalAppData / Temp
	$cacheDir = Join-Path $env:TEMP "VentoyBootEditor"
	if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir | Out-Null }
	$zipPath = Join-Path $cacheDir "images_v5.zip"

	try {
		if (-not (Test-Path $zipPath) -or ((Get-Item $zipPath).Length -lt 100000)) {
			Invoke-WebRequest -Uri "https://github.com/ventoy/backend/releases/download/v5.0/images.zip" -OutFile $zipPath -UseBasicParsing
		}
	} catch {
		$txtPersistProgress.Text = "❌ Download fehlgeschlagen"
		[System.Windows.MessageBox]::Show("Fehler beim Herunterladen von images.zip: $_", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	$target7zName = "persistence_${FsTag}_${SizeTag}_${DistroLabel}.dat.7z"
	$txtPersistProgress.Text = "⏳ Entpacke $target7zName..."
	$window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

	$temp7zPath = Join-Path $cacheDir $target7zName
	$foundEntry = $false

	try {
		$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
		$entry = $zip.Entries | Where-Object { $_.Name -eq $target7zName } | Select-Object -First 1
		if ($entry) {
			[System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $temp7zPath, $true)
			$foundEntry = $true
		}
		$zip.Dispose()
	} catch {
		$txtPersistProgress.Text = "❌ Fehler beim Extrahieren"
		return
	}

	if (-not $foundEntry -or -not (Test-Path $temp7zPath)) {
		$txtPersistProgress.Text = "❌ Template $target7zName nicht gefunden."
		[System.Windows.MessageBox]::Show("Template $target7zName wurde in images.zip nicht gefunden.", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	# Zielverzeichnis auf USB-Stick vorbereiten
	$cleanRel = "/" + $RelFileName.TrimStart('/ \').Replace('\', '/')
	$destFullPath = Join-Path $ventoyDrive ($cleanRel.TrimStart('/').Replace('/', '\'))
	$destDir = [System.IO.Path]::GetDirectoryName($destFullPath)
	if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }

	$txtPersistProgress.Text = "⏳ Schreibe auf USB..."
	$window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)

	# In Cache entpacken via built-in tar.exe
	$tempExtractedDat = Join-Path $cacheDir "persistence_${FsTag}_${SizeTag}_${DistroLabel}.dat"
	if (Test-Path $tempExtractedDat) { Remove-Item -Path $tempExtractedDat -Force -ErrorAction SilentlyContinue }

	try {
		$tarOutput = tar -xf $temp7zPath -C $cacheDir 2>&1
		if (Test-Path $tempExtractedDat) {
			Move-Item -Path $tempExtractedDat -Destination $destFullPath -Force
			$txtPersistProgress.Text = "✅ Fertig!"
		} else {
			$txtPersistProgress.Text = "❌ tar Entpacken fehlgeschlagen."
			[System.Windows.MessageBox]::Show("tar-Befehl konnte die Persistenzdatei nicht entpacken: $tarOutput", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
			return
		}
	} catch {
		$txtPersistProgress.Text = "❌ Fehler: $_"
		[System.Windows.MessageBox]::Show("Fehler beim Erstellen der Persistenzdatei: $_", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	# Automatisch verknüpfen falls passende ISO im Dropdown
	$suggestIso = if ($cbDefaultIso.Text) { $cbDefaultIso.Text } elseif ($global:availableIsos.Count -gt 0) { $global:availableIsos[0] } else { "/isos/linux.iso" }
	
	$alreadyMapped = $global:persistenceList | Where-Object { $_.backend -contains $cleanRel -or $_.backend -eq $cleanRel }
	if (-not $alreadyMapped) {
		$global:persistenceList += [PSCustomObject]@{
			image   = $suggestIso
			backend = @($cleanRel)
		}
	}

	Sync-PersistenceList
	Scan-VentoyDriveFiles -ventoyDrive $ventoyDrive

	[System.Windows.MessageBox]::Show((T "PersistenceCreatedSuccess" @($cleanRel)), (T "Success"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

function Download-VentoyLocalBootIso {
	param([string]$ventoyDrive)

	if ([string]::IsNullOrWhiteSpace($ventoyDrive) -or -not (Test-Path $ventoyDrive)) {
		[System.Windows.MessageBox]::Show((T "SelectVentoyWarning"), (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	# Determine initial/suggested directory based on VTOY_DEFAULT_SEARCH_ROOT, existing ISO directories, or USB root
	$initialDir = $ventoyDrive
	if (-not [string]::IsNullOrWhiteSpace($global:currentSearchRoot)) {
		$customDir = Join-Path $ventoyDrive ($global:currentSearchRoot.TrimStart('/\').Replace('/', '\'))
		if (Test-Path $customDir) {
			$initialDir = $customDir
		}
	} elseif ($global:availableIsos.Count -gt 0) {
		$firstIsoRel = $global:availableIsos[0]
		$firstIsoDir = [System.IO.Path]::GetDirectoryName($firstIsoRel.TrimStart('/\').Replace('/', '\'))
		if (-not [string]::IsNullOrWhiteSpace($firstIsoDir)) {
			$candDir = Join-Path $ventoyDrive $firstIsoDir
			if (Test-Path $candDir) {
				$initialDir = $candDir
			}
		}
	}

	# User selects exact destination file path and name on the USB drive
	$dlg = [Microsoft.Win32.SaveFileDialog]::new()
	$dlg.Title = T "SaveIsoDialogTitle"
	$dlg.FileName = "ventoy_localboot.iso"
	$dlg.Filter = "ISO Image (*.iso)|*.iso|All Files (*.*)|*.*"
	$dlg.InitialDirectory = $initialDir

	if ($dlg.ShowDialog() -ne $true) {
		return
	}

	$destFullPath = $dlg.FileName
	if ([string]::IsNullOrWhiteSpace($destFullPath)) { return }

	# Calculate relative path from the Ventoy USB drive root
	$relIsoPath = if ($destFullPath.StartsWith($ventoyDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
		$destFullPath.Substring($ventoyDrive.TrimEnd('\').Length).Replace('\', '/')
	} else {
		$destFullPath.Replace('\', '/')
	}
	if (-not $relIsoPath.StartsWith('/')) {
		$relIsoPath = "/" + $relIsoPath
	}

	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

	$downloadUrl = $null
	try {
		$apiUrl = "https://api.github.com/repos/adromir/powershell-scripts/releases/latest"
		$headers = @{ "User-Agent" = "VentoyLocalBootEditor" }
		$relJson = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10 -ErrorAction Stop
		if ($relJson -and $relJson.assets) {
			$asset = $relJson.assets | Where-Object { $_.name -like "*ventoy_localboot*.iso" -or $_.name -like "*.iso" } | Select-Object -First 1
			if ($asset -and $asset.browser_download_url) {
				$downloadUrl = $asset.browser_download_url
			}
		}
	} catch {
		$downloadUrl = $null
	}

	if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
		$downloadUrl = "https://github.com/adromir/powershell-scripts/releases/latest/download/ventoy_localboot.iso"
	}

	try {
		$destDir = [System.IO.Path]::GetDirectoryName($destFullPath)
		if (-not [string]::IsNullOrWhiteSpace($destDir) -and -not (Test-Path $destDir)) {
			New-Item -ItemType Directory -Path $destDir -Force | Out-Null
		}
		Invoke-WebRequest -Uri $downloadUrl -OutFile $destFullPath -UseBasicParsing
	} catch {
		[System.Windows.MessageBox]::Show((T "DownloadIsoFailed" @($_.Exception.Message)), (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	Scan-VentoyDriveFiles -ventoyDrive $ventoyDrive

	[System.Windows.MessageBox]::Show(
		(T "DownloadIsoSuccess" @($destFullPath)),
		(T "Success"),
		[System.Windows.MessageBoxButton]::OK,
		[System.Windows.MessageBoxImage]::Information
	)
}

function Load-VentoyJson {
	param([string]$ventoyDrive)
	$jsonPath = Join-Path -Path $ventoyDrive -ChildPath "ventoy\ventoy.json"
	
	Scan-VentoyDriveFiles -ventoyDrive $ventoyDrive

	$cbResolution.Text = ""
	$txtThemePath.Text = ""
	$cbMenuMode.SelectedIndex = -1
	$txtVentoyTimeout.Text = ""
	$cbDefaultAction.SelectedItem = $cbiActionNone
	$cbDefaultIso.Text = ""
	$chkWin11Bypass.IsChecked = $false
	$global:persistenceList = @()
	$global:currentSearchRoot = ""

	if (Test-Path -Path $jsonPath) {
		try {
			$jsonContent = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
			
			if ($null -ne $jsonContent.theme) {
				if ($null -ne $jsonContent.theme.gfxmode) {
					$cbResolution.Text = $jsonContent.theme.gfxmode
				}
				if ($null -ne $jsonContent.theme.file) {
					$txtThemePath.Text = $jsonContent.theme.file
				}
			}
			
			if ($null -ne $jsonContent.control) {
				foreach ($ctrl in $jsonContent.control) {
					if ($null -ne $ctrl.VTOY_DEFAULT_SEARCH_ROOT) {
						$global:currentSearchRoot = [string]$ctrl.VTOY_DEFAULT_SEARCH_ROOT
					}
					if ($null -ne $ctrl.VTOY_DEFAULT_MENU_MODE) {
						$modeVal = [string]$ctrl.VTOY_DEFAULT_MENU_MODE
						foreach ($item in $cbMenuMode.Items) {
							if ($item.Tag -eq $modeVal) {
								$cbMenuMode.SelectedItem = $item
								break
							}
						}
					}
					if ($null -ne $ctrl.VTOY_MENU_TIMEOUT) {
						$txtVentoyTimeout.Text = [string]$ctrl.VTOY_MENU_TIMEOUT
					}
					if ($null -ne $ctrl.VTOY_DEFAULT_IMAGE) {
						$actVal = [string]$ctrl.VTOY_DEFAULT_IMAGE
						$matchedAct = $false
						foreach ($item in $cbDefaultAction.Items) {
							if ($item.Tag -and $item.Tag -eq $actVal) {
								$cbDefaultAction.SelectedItem = $item
								$matchedAct = $true
								break
							}
						}
						if (-not $matchedAct) {
							$cbDefaultAction.SelectedItem = $cbiActionIso
							$cbDefaultIso.Text = $actVal
						}
					}
					if ($null -ne $ctrl.VTOY_WIN11_BYPASS_CHECK) {
						$chkWin11Bypass.IsChecked = ([string]$ctrl.VTOY_WIN11_BYPASS_CHECK -eq "1")
					}
				}
			}

			if ($null -ne $jsonContent.persistence) {
				foreach ($p in @($jsonContent.persistence)) {
					$global:persistenceList += $p
				}
			}
		} catch {
			Write-Host "Konnte ventoy.json nicht parsen: $_"
		}
	}

	Sync-PersistenceList
	Update-TimeoutUiState
}

function Sync-GrubEntries {
	$text = $txtPreview.Text
	$defaultMatch = [regex]::Match($text, '(?m)^\s*set\s+default\s*=\s*["'']?([^"''\r\n]+)["'']?')
	$defaultName = if ($defaultMatch.Success) { $defaultMatch.Groups[1].Value.Trim() } else { "" }

	$timeoutMatch = [regex]::Match($text, '(?m)^\s*set\s+timeout\s*=\s*(\S+)')
	if ($timeoutMatch.Success) {
		$cbGrubTimeout.Text = $timeoutMatch.Groups[1].Value
	}

	$menuMatches = [regex]::Matches($text, "(?s)menuentry\s+[`"']([^`"']+)[`"']\s*(?:--[a-z]+=\S+\s*)*\{")
	$entries = @()
	$index = 0
	foreach ($m in $menuMatches) {
		$name = $m.Groups[1].Value
		$startIndex = $m.Index
		
		$openBraces = 1
		$i = $startIndex + $m.Length
		while ($i -lt $text.Length -and $openBraces -gt 0) {
			if ($text[$i] -eq '{') { $openBraces++ }
			elseif ($text[$i] -eq '}') { $openBraces-- }
			$i++
		}
		$fullBlock = $text.Substring($startIndex, $i - $startIndex)
		
		# Spezifischen Bootloader-Typ erkennen
		$typeTag = "generic_uefi"
		if ($fullBlock -match 'bootmgfw\.efi') {
			$typeTag = "win_uefi"
		} elseif ($fullBlock -match 'ubuntu/(?:shim|grub)') {
			$typeTag = "ubuntu_uefi"
		} elseif ($fullBlock -match 'debian/(?:shim|grub)') {
			$typeTag = "debian_uefi"
		} elseif ($fullBlock -match 'fedora/(?:shim|grub)') {
			$typeTag = "fedora_uefi"
		} elseif ($fullBlock -match 'arch/(?:shim|grub)') {
			$typeTag = "arch_uefi"
		} elseif ($fullBlock -match 'opensuse/(?:shim|grub)') {
			$typeTag = "opensuse_uefi"
		} elseif ($fullBlock -match 'systemd-boot') {
			$typeTag = "systemd_uefi"
		} elseif ($fullBlock -match '/bootmgr' -or $fullBlock -match 'ntldr') {
			$typeTag = "win_bios"
		} elseif ($fullBlock -match 'chainloader\s+\+1') {
			$typeTag = "chainload"
		} elseif ($fullBlock -match 'BOOTX64\.EFI' -or $fullBlock -match 'bootx64\.efi') {
			$typeTag = "generic_uefi"
		}

		# UUID erkennen
		$uuidMatch = [regex]::Match($fullBlock, '--fs-uuid\s+(?:--set=root\s+)?([A-Za-z0-9\-]+)')
		if (-not $uuidMatch.Success) {
			$uuidMatch = [regex]::Match($fullBlock, '--set=root\s+--fs-uuid\s+([A-Za-z0-9\-]+)')
		}
		$uuid = if ($uuidMatch.Success) { $uuidMatch.Groups[1].Value } else { "" }

		$isDefault = ($name -eq $defaultName -or ([string]$index -eq $defaultName))

		$badge = if ($isDefault) { (T "DefaultBadge") + " " } else { "    " }
		$dispTitle = "$badge$name"
		if ($uuid) { $dispTitle += " ($uuid)" }

		$entries += [PSCustomObject]@{
			Index       = $index
			Name        = $name
			Display     = $dispTitle
			Content     = $fullBlock
			BootType    = $typeTag
			GrubUUID    = $uuid
			IsDefault   = $isDefault
		}
		$index++
	}
	$lbEntries.ItemsSource = $entries

	# Edit-Felder zurücksetzen, falls nichts ausgewählt ist
	if (-not $lbEntries.SelectedItem) {
		$txtEditEntryName.Text = ""
		$txtEditEntryUuid.Text = ""
		$cbEditBootloaderType.SelectedIndex = 0
	}
}

# 6. Event Handlers
$cbLanguage.Add_SelectionChanged({
	if ($cbLanguage.SelectedItem) {
		$selectedTag = $cbLanguage.SelectedItem.Tag
		if ($selectedTag -and $selectedTag -ne $global:currentLang) {
			Apply-Localization -LangCode $selectedTag
			Load-Volumes
			Load-VentoyDrives
			Sync-GrubEntries
		}
	}
})

# Auswahl im Partitionen-DataGrid: Automatische Empfehlung, Namens- und Bootloadervorschlag
$dgVolumes.Add_SelectionChanged({
	$selectedVol = $dgVolumes.SelectedItem
	if ($selectedVol) {
		$partNum = $selectedVol.PartitionNumber
		$letter = $selectedVol.DriveLetter
		$label = $selectedVol.Label
		$isEfi = ($selectedVol.PartitionTypeRaw -eq 'System' -or $selectedVol.BootRoleKey -eq 'RoleEfi')
		
		if ($isEfi) {
			$txtMenuNameVolume.Text = "Windows Boot Manager ($($selectedVol.DiskShortName) - Part $partNum)"
			foreach ($item in $cbBootloaderType.Items) {
				if ($item.Tag -eq 'win_uefi') { $cbBootloaderType.SelectedItem = $item; break }
			}
		} elseif ($selectedVol.BootRoleKey -eq 'RoleLinux') {
			$txtMenuNameVolume.Text = "Linux ($($selectedVol.DiskShortName) - Part $partNum)"
			foreach ($item in $cbBootloaderType.Items) {
				if ($item.Tag -eq 'ubuntu_uefi') { $cbBootloaderType.SelectedItem = $item; break }
			}
		} elseif ($letter -eq 'C:' -or $selectedVol.BootRoleKey -eq 'RoleWindows') {
			$txtMenuNameVolume.Text = "Windows System ($letter $label - Part $partNum)"
			foreach ($item in $cbBootloaderType.Items) {
				if ($item.Tag -eq 'win_uefi') { $cbBootloaderType.SelectedItem = $item; break }
			}
		} elseif ($selectedVol.BootRoleKey -eq 'RoleRecovery') {
			$txtMenuNameVolume.Text = "Windows Recovery ($($selectedVol.DiskShortName) - Part $partNum)"
			foreach ($item in $cbBootloaderType.Items) {
				if ($item.Tag -eq 'generic_uefi') { $cbBootloaderType.SelectedItem = $item; break }
			}
		} else {
			$nameBase = if ($label -and $label -ne (T "LocalVolume")) { "$label ($letter)" } elseif ($letter -ne (T "Unmounted")) { "Partition $letter" } else { "Partition $partNum" }
			$txtMenuNameVolume.Text = "Boot $nameBase ($($selectedVol.DiskShortName))"
			foreach ($item in $cbBootloaderType.Items) {
				if ($item.Tag -eq 'generic_uefi') { $cbBootloaderType.SelectedItem = $item; break }
			}
		}
		Update-PartitionTip
	}
})

$tcMain.Add_SelectionChanged({
	param($sender, $e)
	if ($e.Source -eq $tcMain) {
		$selectedTab = $tcMain.SelectedItem
		if ($selectedTab -and $selectedTab.Name -eq "tabManage") {
			Sync-GrubEntries
		}
	}
})

# Tab 2: Grub Timeout ändern
$cbGrubTimeout.Add_SelectionChanged({
	if ($cbGrubTimeout.SelectedItem) {
		$to = [string]$cbGrubTimeout.SelectedItem.Content
		Set-GrubTimeout -TimeoutVal $to
	}
})
$cbGrubTimeout.Add_KeyUp({
	Set-GrubTimeout -TimeoutVal $cbGrubTimeout.Text
})

# Tab 1: Zum Menü hinzufügen
$btnAddVolume.Add_Click({
	$selectedVol = $dgVolumes.SelectedItem
	if (-not $selectedVol) {
		[System.Windows.MessageBox]::Show((T "SelectPartitionWarning"), (T "SelectionRequired"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
		return
	}

	$menuName = $txtMenuNameVolume.Text
	if ([string]::IsNullOrWhiteSpace($menuName)) {
		$menuName = T "DefaultVolumeMenuName" @($selectedVol.GrubUUID)
	}

	$uuid = $selectedVol.GrubUUID
	$bootType = "generic_uefi"
	if ($cbBootloaderType.SelectedItem) {
		$bootType = $cbBootloaderType.SelectedItem.Tag
	}

	$entryBlock = Generate-GrubEntry -Name $menuName -BootType $bootType -UUID $uuid
	$txtPreview.Text += $entryBlock

	if ($chkSetDefaultVolume.IsChecked) {
		Set-GrubDefaultEntry -EntryName $menuName
	}

	$txtMenuNameVolume.Text = ""
	$chkSetDefaultVolume.IsChecked = $false
	[System.Windows.MessageBox]::Show((T "VolumeAddedSuccess"), (T "Success"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Tab 2: Einträge verwalten - Auswahl im ListBox
$lbEntries.Add_SelectionChanged({
	$selected = $lbEntries.SelectedItem
	if ($selected) {
		$txtEditEntryName.Text = $selected.Name
		$txtEditEntryUuid.Text = $selected.GrubUUID

		foreach ($item in $cbEditBootloaderType.Items) {
			if ($item.Tag -eq $selected.BootType) {
				$cbEditBootloaderType.SelectedItem = $item
				break
			}
		}
	}
})

# Tab 2: Änderungen am Eintrag speichern
$btnUpdateEntry.Add_Click({
	$selected = $lbEntries.SelectedItem
	if (-not $selected) {
		[System.Windows.MessageBox]::Show((T "SelectEntryWarning"), (T "SelectionRequired"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
		return
	}

	$newName = $txtEditEntryName.Text.Trim()
	if ([string]::IsNullOrWhiteSpace($newName)) {
		$newName = $selected.Name
	}

	$newUuid = $txtEditEntryUuid.Text.Trim()
	$newBootType = "generic_uefi"
	if ($cbEditBootloaderType.SelectedItem) {
		$newBootType = $cbEditBootloaderType.SelectedItem.Tag
	}

	$newBlock = Generate-GrubEntry -Name $newName -BootType $newBootType -UUID $newUuid
	
	$previewText = $txtPreview.Text
	$previewText = $previewText.Replace($selected.Content, $newBlock.TrimEnd())
	$txtPreview.Text = $previewText

	if ($selected.IsDefault -and ($newName -ne $selected.Name)) {
		Set-GrubDefaultEntry -EntryName $newName
	}

	Sync-GrubEntries
	[System.Windows.MessageBox]::Show((T "EntryUpdatedSuccess"), (T "Success"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Tab 2: Als Standard festlegen (1-Klick)
$btnSetDefault.Add_Click({
	$selected = $lbEntries.SelectedItem
	if (-not $selected) {
		[System.Windows.MessageBox]::Show((T "SelectEntryWarning"), (T "SelectionRequired"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
		return
	}

	Set-GrubDefaultEntry -EntryName $selected.Name
	Sync-GrubEntries
	[System.Windows.MessageBox]::Show((T "DefaultSetSuccess" @($selected.Name)), (T "Success"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Tab 2: Nach oben verschieben
$btnMoveUp.Add_Click({
	$selectedIndex = $lbEntries.SelectedIndex
	if ($selectedIndex -le 0) { return }

	$entries = @($lbEntries.ItemsSource)
	$current = $entries[$selectedIndex]
	$prev = $entries[$selectedIndex - 1]

	$text = $txtPreview.Text
	$currContent = $current.Content
	$prevContent = $prev.Content

	$guidPlaceholder = "___SWAP_PLACEHOLDER___"
	$text = $text.Replace($currContent, $guidPlaceholder)
	$text = $text.Replace($prevContent, $currContent)
	$text = $text.Replace($guidPlaceholder, $prevContent)

	$txtPreview.Text = $text
	Sync-GrubEntries
	$lbEntries.SelectedIndex = $selectedIndex - 1
})

# Tab 2: Nach unten verschieben
$btnMoveDown.Add_Click({
	$selectedIndex = $lbEntries.SelectedIndex
	$entries = @($lbEntries.ItemsSource)
	if ($selectedIndex -lt 0 -or $selectedIndex -ge ($entries.Count - 1)) { return }

	$current = $entries[$selectedIndex]
	$next = $entries[$selectedIndex + 1]

	$text = $txtPreview.Text
	$currContent = $current.Content
	$nextContent = $next.Content

	$guidPlaceholder = "___SWAP_PLACEHOLDER___"
	$text = $text.Replace($currContent, $guidPlaceholder)
	$text = $text.Replace($nextContent, $currContent)
	$text = $text.Replace($guidPlaceholder, $nextContent)

	$txtPreview.Text = $text
	Sync-GrubEntries
	$lbEntries.SelectedIndex = $selectedIndex + 1
})

# Tab 2: Eintrag löschen
$btnDeleteEntry.Add_Click({
	$selected = $lbEntries.SelectedItem
	if ($selected) {
		$previewText = $txtPreview.Text
		$newText = $previewText.Replace($selected.Content, "")
		$newText = $newText -replace '(?m)^\s*\r?\n\s*\r?\n', "`r`n"
		
		if ($selected.IsDefault) {
			$newText = $newText -replace '(?m)^\s*set\s+default\s*=\s*["'']?[^"''\r\n]+["'']?\r?\n?', ""
		}

		$txtPreview.Text = $newText
		Sync-GrubEntries
		[System.Windows.MessageBox]::Show((T "EntryDeletedInfo"), (T "Info"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
	} else {
		[System.Windows.MessageBox]::Show((T "SelectEntryWarning"), (T "SelectionRequired"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
	}
})

$btnRefreshEntries.Add_Click({
	Sync-GrubEntries
})

# Laufwerke aktualisieren
$btnLoadVentoy.Add_Click({
	Load-Volumes
	Load-VentoyDrives
})

$cbVentoyDrive.Add_SelectionChanged({
	if ($cbVentoyDrive.SelectedItem) {
		$ventoyDrive = $cbVentoyDrive.SelectedItem.Path
		$grubCfgPath = Join-Path -Path $ventoyDrive -ChildPath "ventoy\ventoy_grub.cfg"
		
		if (Test-Path $grubCfgPath) {
			$txtPreview.Text = Get-Content -Path $grubCfgPath -Raw
		} else {
			$txtPreview.Text = ""
		}

		Load-VentoyJson -ventoyDrive $ventoyDrive
	}
})

# Tab 4: Grub Konfiguration speichern
$btnSaveGrub.Add_Click({
	if (-not $cbVentoyDrive.SelectedItem) {
		[System.Windows.MessageBox]::Show((T "SelectVentoyWarning"), (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	$text = $txtPreview.Text
	$timeoutMatch = [regex]::Match($text, '(?m)^\s*set\s+timeout\s*=\s*(\d+)')
	$hasDefault = $text -match '(?m)^\s*set\s+default\s*='
	if ($timeoutMatch.Success -and [int]$timeoutMatch.Groups[1].Value -gt 0 -and -not $hasDefault) {
		$res = [System.Windows.MessageBox]::Show(
			(T "GrubTimeoutNoDefaultWarning" @($timeoutMatch.Groups[1].Value)),
			(T "Warning"),
			[System.Windows.MessageBoxButton]::YesNo,
			[System.Windows.MessageBoxImage]::Warning
		)
		if ($res -ne [System.Windows.MessageBoxResult]::Yes) {
			$tabManage.IsSelected = $true
			return
		}
	}

	$ventoyDrive = $cbVentoyDrive.SelectedItem.Path
	$ventoyFolder = Join-Path -Path $ventoyDrive -ChildPath "ventoy"
	$grubCfgPath = Join-Path -Path $ventoyFolder -ChildPath "ventoy_grub.cfg"

	if (-not (Test-Path $ventoyFolder)) {
		New-Item -ItemType Directory -Path $ventoyFolder | Out-Null
	}

	$backupOk = Backup-File -filePath $grubCfgPath
	if (-not $backupOk) {
		$confirm = [System.Windows.MessageBox]::Show((T "BackupFailedConfirm"), (T "Warning"), [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
		if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
	}

	try {
		[System.IO.File]::WriteAllText($grubCfgPath, $txtPreview.Text, [System.Text.UTF8Encoding]::new($false))
		[System.Windows.MessageBox]::Show((T "GrubSavedSuccess" @($grubCfgPath)), (T "Success"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
	} catch {
		[System.Windows.MessageBox]::Show("Fehler beim Speichern: $_", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	}
})

# Tab 3: Default Action & Timeout Event Handlers
$cbDefaultAction.Add_SelectionChanged({
	Update-TimeoutUiState
})

$cbDefaultIso.Add_SelectionChanged({
	Update-TimeoutUiState
})

$txtVentoyTimeout.Add_TextChanged({
	Update-TimeoutUiState
})

# Tab 3: Browse ISO Button
$btnBrowseIso.Add_Click({
	$ventoyDrive = if ($cbVentoyDrive.SelectedItem) { $cbVentoyDrive.SelectedItem.Path } else { "" }
	$dlg = [Microsoft.Win32.OpenFileDialog]::new()
	$dlg.Filter = "Disk Images (*.iso;*.img;*.vhd;*.vhdx;*.wim)|*.iso;*.img;*.vhd;*.vhdx;*.wim|All Files (*.*)|*.*"
	$dlg.Title = "ISO-Abbild für Ventoy auswählen"
	if (-not [string]::IsNullOrWhiteSpace($ventoyDrive) -and (Test-Path $ventoyDrive)) {
		$dlg.InitialDirectory = $ventoyDrive
	}

	if ($dlg.ShowDialog() -eq $true) {
		$selFile = $dlg.FileName
		if (-not [string]::IsNullOrWhiteSpace($ventoyDrive) -and $selFile.StartsWith($ventoyDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
			$rel = $selFile.Substring($ventoyDrive.TrimEnd('\').Length).Replace('\', '/')
			$cbDefaultIso.Text = $rel
		} else {
			$cbDefaultIso.Text = $selFile
		}
		$cbDefaultAction.SelectedItem = $cbiActionIso
		Update-TimeoutUiState
	}
})

# Tab 3: Download Minimal ISO Button
$btnDownloadIso.Add_Click({
	$ventoyDrive = if ($cbVentoyDrive.SelectedItem) { $cbVentoyDrive.SelectedItem.Path } else { "" }
	Download-VentoyLocalBootIso -ventoyDrive $ventoyDrive
})

# Tab 3: Persistence Management Handlers
$btnTogglePersistCreator.Add_Click({
	if ($borderPersistCreator.Visibility -eq [System.Windows.Visibility]::Visible) {
		$borderPersistCreator.Visibility = [System.Windows.Visibility]::Collapsed
	} else {
		$borderPersistCreator.Visibility = [System.Windows.Visibility]::Visible
	}
})

$btnAddPersistence.Add_Click({
	$ventoyDrive = if ($cbVentoyDrive.SelectedItem) { $cbVentoyDrive.SelectedItem.Path } else { "" }
	$suggestIso = if ($cbDefaultIso.Text) { $cbDefaultIso.Text } elseif ($global:availableIsos.Count -gt 0) { $global:availableIsos[0] } else { "/isos/ubuntu.iso" }
	$suggestDat = if ($global:availableDats.Count -gt 0) { $global:availableDats[0] } else { "/persistence/ubuntu.dat" }

	$dlg = [Microsoft.Win32.OpenFileDialog]::new()
	$dlg.Filter = "Persistence Backend (*.dat)|*.dat|All Files (*.*)|*.*"
	$dlg.Title = "Persistenz-Datei (.dat) auswählen"
	if (-not [string]::IsNullOrWhiteSpace($ventoyDrive) -and (Test-Path $ventoyDrive)) {
		$dlg.InitialDirectory = $ventoyDrive
	}

	if ($dlg.ShowDialog() -eq $true) {
		$selFile = $dlg.FileName
		$relDat = if (-not [string]::IsNullOrWhiteSpace($ventoyDrive) -and $selFile.StartsWith($ventoyDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
			$selFile.Substring($ventoyDrive.TrimEnd('\').Length).Replace('\', '/')
		} else {
			$selFile
		}

		$global:persistenceList += [PSCustomObject]@{
			image   = $suggestIso
			backend = @($relDat)
		}
		Sync-PersistenceList
	} else {
		$borderPersistCreator.Visibility = [System.Windows.Visibility]::Visible
	}
})

$btnRemovePersistence.Add_Click({
	$sel = $lbPersistence.SelectedItem
	if ($sel) {
		$res = [System.Windows.MessageBox]::Show(
			(T "PersistenceDeleteConfirm" @($sel.Image)),
			(T "Warning"),
			[System.Windows.MessageBoxButton]::YesNo,
			[System.Windows.MessageBoxImage]::Question
		)
		if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
			$global:persistenceList = @($global:persistenceList | Where-Object {
				$b = if ($_.backend -is [array]) { $_.backend[0] } else { [string]$_.backend }
				-not ($_.image -eq $sel.Image -and $b -eq $sel.Backend)
			})
			Sync-PersistenceList
		}
	} else {
		[System.Windows.MessageBox]::Show((T "SelectEntryWarning"), (T "SelectionRequired"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
	}
})

$btnDoCreatePersistFile.Add_Click({
	$ventoyDrive = if ($cbVentoyDrive.SelectedItem) { $cbVentoyDrive.SelectedItem.Path } else { "" }
	$distroLabel = if ($cbPersistDistro.SelectedItem) { [string]$cbPersistDistro.SelectedItem.Tag } else { "casper-rw" }
	$sizeTag     = if ($cbPersistSize.SelectedItem) { [string]$cbPersistSize.SelectedItem.Tag } else { "1GB" }
	$fsTag       = if ($cbPersistFs.SelectedItem) { [string]$cbPersistFs.SelectedItem.Tag } else { "ext4" }
	$relFileName = $txtPersistFileName.Text.Trim()
	if ([string]::IsNullOrWhiteSpace($relFileName)) { $relFileName = "/persistence/ubuntu.dat" }

	Create-VentoyPersistenceDat -ventoyDrive $ventoyDrive -DistroLabel $distroLabel -SizeTag $sizeTag -FsTag $fsTag -RelFileName $relFileName
})

# Tab 3: Ventoy JSON speichern
$btnSaveJson.Add_Click({
	if (-not $cbVentoyDrive.SelectedItem) {
		[System.Windows.MessageBox]::Show((T "SelectVentoyWarning"), (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	$ventoyTimeoutVal = $txtVentoyTimeout.Text.Trim()
	$defaultActionTag = if ($cbDefaultAction.SelectedItem) { [string]$cbDefaultAction.SelectedItem.Tag } else { "" }
	
	$defaultImageVal = ""
	if ($defaultActionTag -eq "ISO") {
		$defaultImageVal = $cbDefaultIso.Text.Trim()
		if ([string]::IsNullOrWhiteSpace($defaultImageVal)) {
			[System.Windows.MessageBox]::Show("Bitte wähle oder gib den Pfad zur Standard-ISO an.", (T "Warning"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
			$cbDefaultIso.Focus()
			return
		}
	} elseif (-not [string]::IsNullOrWhiteSpace($defaultActionTag)) {
		$defaultImageVal = $defaultActionTag
	}

	# Validierung: Wenn Timeout gesetzt ist, aber weder Default-Action noch Default-ISO gewählt ist
	if (-not [string]::IsNullOrWhiteSpace($ventoyTimeoutVal) -and $ventoyTimeoutVal -ne "0" -and $ventoyTimeoutVal -ne "-1") {
		if ([string]::IsNullOrWhiteSpace($defaultImageVal)) {
			[System.Windows.MessageBox]::Show(
				(T "TimeoutRequiresDefaultActionWarning" @($ventoyTimeoutVal)),
				(T "Warning"),
				[System.Windows.MessageBoxButton]::OK,
				[System.Windows.MessageBoxImage]::Warning
			)
			$cbDefaultAction.Focus()
			return
		}
	}

	$ventoyDrive = $cbVentoyDrive.SelectedItem.Path
	$ventoyFolder = Join-Path -Path $ventoyDrive -ChildPath "ventoy"
	$jsonCfgPath = Join-Path -Path $ventoyFolder -ChildPath "ventoy.json"

	if (-not (Test-Path $ventoyFolder)) {
		New-Item -ItemType Directory -Path $ventoyFolder | Out-Null
	}

	$backupOk = Backup-File -filePath $jsonCfgPath
	if (-not $backupOk) {
		$confirm = [System.Windows.MessageBox]::Show((T "BackupFailedConfirm"), (T "Warning"), [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
		if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
	}

	$menuModeTag = "0"
	if ($cbMenuMode.SelectedItem) {
		$menuModeTag = $cbMenuMode.SelectedItem.Tag
	}

	$win11BypassVal = "0"
	if ($chkWin11Bypass.IsChecked) {
		$win11BypassVal = "1"
	}

	# Bestehende JSON laden und nur UI-relevante Felder aktualisieren
	$jsonObj = $null
	if (Test-Path $jsonCfgPath) {
		try { $jsonObj = Get-Content -Path $jsonCfgPath -Raw | ConvertFrom-Json } catch {}
	}
	if ($null -eq $jsonObj) {
		$jsonObj = [PSCustomObject]@{}
	}

	# Theme aktualisieren (unbekannte Properties beibehalten)
	$themeObj = [PSCustomObject]@{ gfxmode = $cbResolution.Text; file = $txtThemePath.Text }
	if ($jsonObj.PSObject.Properties['theme']) {
		foreach ($prop in $jsonObj.theme.PSObject.Properties) {
			if ($prop.Name -notin 'gfxmode', 'file') {
				$themeObj | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
			}
		}
		$jsonObj.theme = $themeObj
	} else {
		$jsonObj | Add-Member -NotePropertyName 'theme' -NotePropertyValue $themeObj -Force
	}

	# Control aktualisieren (unbekannte Einträge beibehalten)
	$managedKeys = @('VTOY_DEFAULT_MENU_MODE', 'VTOY_WIN11_BYPASS_CHECK', 'VTOY_MENU_TIMEOUT', 'VTOY_DEFAULT_IMAGE')
	$controlList = @(
		[PSCustomObject]@{ VTOY_DEFAULT_MENU_MODE = $menuModeTag },
		[PSCustomObject]@{ VTOY_WIN11_BYPASS_CHECK = $win11BypassVal }
	)

	# Timeout nur schreiben wenn keine Hotkey-Aktion und Timeout-Wert angegeben
	if ($txtVentoyTimeout.IsEnabled -and -not [string]::IsNullOrWhiteSpace($ventoyTimeoutVal)) {
		$controlList += [PSCustomObject]@{ VTOY_MENU_TIMEOUT = $ventoyTimeoutVal }
	}

	if (-not [string]::IsNullOrWhiteSpace($defaultImageVal)) {
		$controlList += [PSCustomObject]@{ VTOY_DEFAULT_IMAGE = $defaultImageVal }
	}

	if ($jsonObj.PSObject.Properties['control']) {
		foreach ($ctrl in @($jsonObj.control)) {
			$keys = @($ctrl.PSObject.Properties.Name)
			$isManaged = $false
			foreach ($k in $keys) { if ($k -in $managedKeys) { $isManaged = $true; break } }
			if (-not $isManaged) { $controlList += $ctrl }
		}
		$jsonObj.control = $controlList
	} else {
		$jsonObj | Add-Member -NotePropertyName 'control' -NotePropertyValue $controlList -Force
	}

	# Persistence aktualisieren
	if ($global:persistenceList.Count -gt 0) {
		$pArr = @()
		foreach ($p in $global:persistenceList) {
			$bk = if ($p.backend -is [array]) { $p.backend } else { @([string]$p.backend) }
			$pArr += [PSCustomObject]@{
				image   = $p.image
				backend = $bk
			}
		}
		if ($jsonObj.PSObject.Properties['persistence']) {
			$jsonObj.persistence = $pArr
		} else {
			$jsonObj | Add-Member -NotePropertyName 'persistence' -NotePropertyValue $pArr -Force
		}
	} else {
		if ($jsonObj.PSObject.Properties['persistence']) {
			$jsonObj.persistence = @()
		}
	}

	try {
		$jsonString = $jsonObj | ConvertTo-Json -Depth 10
		[System.IO.File]::WriteAllText($jsonCfgPath, $jsonString, [System.Text.UTF8Encoding]::new($false))
		[System.Windows.MessageBox]::Show((T "JsonSavedSuccess"), (T "Success"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
	} catch {
		[System.Windows.MessageBox]::Show("Fehler beim Speichern der JSON-Datei: $_", (T "Error"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
	}
})

# 7. Initiales Setup
# Sprache im Dropdown auswählen
for ($i = 0; $i -lt $cbLanguage.Items.Count; $i++) {
	if ($cbLanguage.Items[$i].Tag -eq $global:currentLang) {
		$cbLanguage.SelectedIndex = $i
		break
	}
}

Apply-Localization -LangCode $global:currentLang
Load-Volumes
Load-VentoyDrives

$window.ShowDialog() | Out-Null