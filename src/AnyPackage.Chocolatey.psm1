using module AnyPackage
using namespace AnyPackage.Provider

# Current script path
[string]$ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.MyCommand.Definition -Parent

# Dot sourcing private script files
Get-ChildItem $ScriptPath/private -Recurse -Filter '*.ps1' -File | ForEach-Object {
	. $_.FullName
}

[PackageProvider("Chocolatey")]
class ChocolateyProvider : PackageProvider, IGetSource, ISetSource, IGetPackage, IFindPackage, IInstallPackage, IUninstallPackage {
	ChocolateyProvider() : base('070f2b8f-c7db-4566-9296-2f7cc9146bf0') { }

	[void] GetSource([SourceRequest] $Request) {
		# $Request.WriteVerbose('Filter is '+$Request.Name)
		Foil\Get-ChocoSource | Where-Object {$_.Disabled -eq 'False'} | Where-Object {$_.Name -Like $Request.Name} | Write-Source
	}

	[void] RegisterSource([SourceRequest] $Request) {
		Foil\Register-ChocoSource -Name $Request.Name -Location $Request.Location
		$Request.WriteSource($Request.Name, $Request.Location.TrimEnd("\"), $Request.Trusted)
	}

	[void] UnregisterSource([SourceRequest] $Request) {
		Foil\Unregister-ChocoSource -Name $Request.Name
		$Request.WriteSource($Request.Name, '')
	}

	[void] SetSource([SourceRequest] $Request) {
		$this.RegisterSource($Request)
	}

	[void] GetPackage([PackageRequest] $Request) {
		Get-ChocoPackage | Write-Package
	}

	[void] FindPackage([PackageRequest] $Request) {
		Find-ChocoPackage | Write-Package
	}

	[void] InstallPackage([PackageRequest] $Request) {
		Find-ChocoPackage | Foil\Install-ChocoPackage | Write-Package
	}

	[void] UninstallPackage([PackageRequest] $Request) {
		Get-ChocoPackage | Foil\Uninstall-ChocoPackage | Write-Package
	}
}

[PackageProviderManager]::RegisterProvider([ChocolateyProvider], $MyInvocation.MyCommand.ScriptBlock.Module)

Export-ModuleMember -Cmdlet *
