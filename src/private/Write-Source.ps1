function Write-Source {
	param (
		[Parameter(ValueFromPipeline)]
		[object[]]
		$InputObject,

		[Parameter()]
		[SourceRequest]
		$Request = $Request
	)

	process {
		foreach ($source in $InputObject) {
			$Request.WriteSource($source.Name, $source.Location, $true)
		}
	}
}