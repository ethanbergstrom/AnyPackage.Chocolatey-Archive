function Write-Package {
	param (
		[Parameter(ValueFromPipeline)]
		[object[]]
		$InputObject,

		[Parameter()]
		[PackageRequest]
		$Request = $Request
	)

	process {
		foreach ($package in $InputObject) {
            if ($package.Source) {
                $Request.WritePackage(
                    $package.Name, 
                    $package.Version, 
                    '',
                    (
                        $Request.NewSourceInfo(
                            $package.Source,
                            (Foil\Get-ChocoSource | Where-Object Name -EQ $package.Source | Select-Object -ExpandProperty Location),
                            $true
                        )
                    )
                )
            } else {
                $Request.WritePackage($package.Name, $package.Version)
            }
		}
	}
}