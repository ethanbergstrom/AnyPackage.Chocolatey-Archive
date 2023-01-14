function Find-ChocoPackage {
	param (
		[Parameter()]
		[PackageRequest]
		$Request = $Request
	)

	[array]$RegisteredPackageSources = Foil\Get-ChocoSource

	$selectedSource = $(
		if ($Request.Source) {
			# Finding the matched package sources from the registered ones
			if ($RegisteredPackageSources.Name -eq $Request.Source) {
				# Found the matched registered source
				$Request.Source
			} else {
				ThrowError -ExceptionName 'System.ArgumentException' `
				-ExceptionMessage ($LocalizedData.PackageSourceNotFound -f ($Request.Source)) `
				-ErrorId 'PackageSourceNotFound' `
				-ErrorCategory InvalidArgument `
				-ExceptionObject $Request.Source
			}
		} else {
			# User did not specify a source. Now what?
			if ($RegisteredPackageSources.Count -eq 1) {
				# If no source name is specified and only one source is available, use that source
				$RegisteredPackageSources[0].Name
			} elseif ($RegisteredPackageSources.Name -eq $DefaultPackageSource) {
				# If multiple sources are avaiable but none specified, use the default package source if present
				$DefaultPackageSource
			} else {
				# If the default assumed source is not present and no source specified, we can't guess what the user wants - throw an exception
				ThrowError -ExceptionName 'System.ArgumentException' `
				-ExceptionMessage $LocalizedData.UnspecifiedSource `
				-ErrorId 'UnspecifiedSource' `
				-ErrorCategory InvalidArgument
			}
		}
	)

	$chocoParams = @{
		Name = $Request.Name
		Source = $selectedSource
	}

    if (-Not [WildcardPattern]::ContainsWildcardCharacters($Request.Name)) {
		# Limit NuGet result set to just the specific package name unless it contains a wildcard
		$chocoParams.Add('Exact',$true)
	}
    
    # Choco does not support searching by min or max version, so if a user is picky we'll need to pull back all versions and filter ourselves
    if ($Request.Version) {
        $chocoParams.Add('AllVersions',$true)
    }

	Foil\Get-ChocoPackage @chocoParams |
        Where-Object {$Request.IsMatch($_.Name)} |
            Where-Object {-Not $Request.Version -Or (([NuGet.Versioning.VersionRange]$Request.Version).Satisfies($_.Version))} | Group-Object Name |
                Select-Object Name,@{
                        Name = 'Version'
                        Expression = {$_.Group | Sort-Object -Descending Version | Select-Object -First 1 -ExpandProperty Version}
                    },@{
                        Name = 'Source'
                        Expression = {$selectedSource}
                    } 
}
