﻿[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='PSSA does not understand Pester scopes well')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCmdletCorrectly', '', Justification='PSSA does not like explicitly using InputObject')]
param()

BeforeAll {
	$AnyPackageProvider = 'AnyPackage.Chocolatey'
	Import-Module $AnyPackageProvider -Force
}

Describe 'basic package search operations' {
	Context 'without additional arguments' {
		BeforeAll {
			$package = 'cpu-z'
		}

		It 'gets a list of latest installed packages' {
			Get-Package | Where-Object {$_.Name -contains 'chocolatey'} | Should -Not -BeNullOrEmpty
		}
		It 'searches for the latest version of a package' {
			Find-Package -Name $package | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
		It 'searches for all versions of a package' {
			Find-Package -Name $package -Version $([NuGet.Versioning.VersionRange]'[0,]') | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
		It 'searches for the latest version of a package with a wildcard pattern' {
			Find-Package -Name "$package*" | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
	}
}

Describe 'pipeline-based package installation and uninstallation' {
	Context 'without additional arguments' {
		BeforeAll {
			$package = 'cpu-z'
		}

		It 'searches for and silently installs the latest version of a package' {
			Find-Package -Name $package | ForEach-Object {Install-Package -PassThru -InputObject $_} | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
		It 'finds and silently uninstalls the locally installed package just installed' {
			Get-Package -Name $package | Uninstall-Package -PassThru | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
	}

	Context 'with dependencies' {
		BeforeAll {
			$package = 'keepass-plugin-winhello'
		}

		It 'searches for and silently installs the latest version of a package' {
			Find-Package -Name $package | ForEach-Object {Install-Package -PassThru -InputObject $_} | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
		It 'finds and silently uninstalls the locally installed package just installed, along with its dependencies' {
			Get-Package -Name $package | Uninstall-Package -Provider Chocolatey -RemoveDependencies -PassThru | Should -HaveCount 3
		}
	}

	Context 'with package parameters' {
		BeforeAll {
			$package = 'sysinternals'
			$installDir = Join-Path -Path $env:ProgramFiles -ChildPath $package
			$parameters = "/InstallDir:$installDir /QuickLaunchShortcut:false"
			Remove-Item -Force -Recurse -Path $installDir -ErrorAction SilentlyContinue
		}

		It 'silently installs the latest version of a package with explicit parameters' {
			Find-Package -Name $package | ForEach-Object {Install-Package -PassThru -InputObject $_ -Provider Chocolatey -ParamsGlobal -Parameters $parameters} | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
		It 'correctly passed parameters to the package' {
			Get-ChildItem -Path $installDir -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
		}
		It 'silently uninstalls the locally installed package just installed' {
			Get-Package -Name $package | Uninstall-Package -Provider Chocolatey -PassThru | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
		}
	}
}

Describe 'multi-source support' {
	BeforeAll {
		$altSource = 'LocalChocoSource'
		$altLocation = $PSScriptRoot
		$package = 'cpu-z'

		PackageManagement\Save-Package $package -Source 'http://chocolatey.org/api/v2' -Path $altLocation
		Remove-Module PackageManagement
		Unregister-PackageSource -Name $altSource -ErrorAction SilentlyContinue
	}
	AfterAll {
		Remove-Item "$altLocation\*.nupkg" -Force -ErrorAction SilentlyContinue
		Unregister-PackageSource -Name $altSource -ErrorAction SilentlyContinue
	}

	It 'registers an alternative package source' {
		Register-PackageSource -Name $altSource -Location $altLocation -Provider Chocolatey -PassThru | Where-Object {$_.Name -eq $altSource} | Should -Not -BeNullOrEmpty
		Get-PackageSource | Where-Object {$_.Name -eq $altSource} | Should -Not -BeNullOrEmpty
	}
	It 'searches for and installs the latest version of a package from an alternate source' {
		Find-Package -Name $package -source $altSource | ForEach-Object {Install-Package -PassThru -InputObject $_} | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
	}
	It 'finds and uninstalls a package installed from an alternate source' {
		Get-Package -Name $package | Uninstall-Package -PassThru | Where-Object {$_.Name -contains $package} | Should -Not -BeNullOrEmpty
	}
	It 'unregisters an alternative package source' {
		Unregister-PackageSource -Name $altSource -PassThru | Where-Object {$_.Name -eq $altSource} | Should -Not -BeNullOrEmpty
		Get-PackageSource | Where-Object {$_.Name -eq $altSource} | Should -BeNullOrEmpty
	}
}

Describe 'version filters' {
	BeforeAll {
		$package = 'ninja'
		# Keep at least one version back, to test the 'latest' feature
		$version = '1.10.1'
	}
	AfterAll {
		Uninstall-Package -Name $package -ErrorAction SilentlyContinue
	}

	Context 'required version' {
		It 'searches for and silently installs a specific package version' {
			Find-Package -Name $package -Version $([NuGet.Versioning.VersionRange]"[$version]") | ForEach-Object {Install-Package -PassThru -InputObject $_} | Where-Object {$_.Name -contains $package -And $_.Version -eq $version} | Should -Not -BeNullOrEmpty
		}
		It 'finds and silently uninstalls a specific package version' {
			Get-Package -Name $package -Version "[$version]" | UnInstall-Package -PassThru | Where-Object {$_.Name -contains $package -And $_.Version -eq $version} | Should -Not -BeNullOrEmpty
		}
	}

	Context 'minimum version' {
		It 'searches for and silently installs a minimum package version' {
			Find-Package -Name $package -Version $version | ForEach-Object {Install-Package -PassThru -InputObject $_} | Where-Object {$_.Name -contains $package -And $_.Version -ge $version} | Should -Not -BeNullOrEmpty
		}
		It 'finds and silently uninstalls a minimum package version' {
			Get-Package -Name $package -Version $version | UnInstall-Package -PassThru | Where-Object {$_.Name -contains $package -And $_.Version -ge $version} | Should -Not -BeNullOrEmpty
		}
	}

	Context 'maximum version' {
		It 'searches for and silently installs a maximum package version' {
			Find-Package -Name $package -Version $([NuGet.Versioning.VersionRange]"[,$version]") | ForEach-Object {Install-Package -PassThru -InputObject $_} | Where-Object {$_.Name -contains $package -And $_.Version -le $version} | Should -Not -BeNullOrEmpty
		}
		It 'finds and silently uninstalls a maximum package version' {
			Get-Package -Name $package -Version $([NuGet.Versioning.VersionRange]"[,$version]") | UnInstall-Package -PassThru | Where-Object {$_.Name -contains $package -And $_.Version -le $version} | Should -Not -BeNullOrEmpty
		}
	}
}

Describe "error handling on Chocolatey failures" {
	Context 'package installation' {
		BeforeAll {
			$package = 'googlechrome'
			# This version is known to be broken, per https://github.com/chocolatey-community/chocolatey-coreteampackages/issues/1608
			$version = '87.0.4280.141'
		}
		AfterAll {
			Uninstall-Package -Name $package -ErrorAction SilentlyContinue
		}

		It 'fails to silently install a package that cannot be installed' {
			{Install-Package -Name $package -Version "[$version]" -ErrorAction Stop -WarningAction SilentlyContinue} | Should -Throw
		}
	}

	Context 'package uninstallation' {
		BeforeAll {
			$package = 'chromium'
			# This version is known to be broken, per https://github.com/chocolatey-community/chocolatey-coreteampackages/issues/341
			$version = '56.0.2897.0'
			Install-Package -Name $package -Version "[$version]"
		}

		It 'fails to silently uninstall a package that cannot be uninstalled' {
			{Uninstall-Package -Name $package -ErrorAction Stop -WarningAction SilentlyContinue} | Should -Throw
		}
	}
}
