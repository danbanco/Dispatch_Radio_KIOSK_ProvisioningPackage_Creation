Param([Parameter(Mandatory = $true)][string] $source,
									[string] $outputFile,
									[string] $destination)

function compress-directory()
{
    $ddf = ".OPTION EXPLICIT
.Set CabinetNameTemplate=$outputFile
.Set DiskDirectoryTemplate=$destination
.Set CompressionType=MSZIP
.Set Cabinet=on
.Set Compress=on
.Set CabinetFileCountThreshold=0
.Set FolderFileCountThreshold=0
.Set FolderSizeThreshold=0
.Set MaxCabinetSize=0
.Set MaxDiskFileCount=0
.Set MaxDiskSize=0
"
#.Set DiskDirectory1=.

    $dirfullname = (get-item $source).fullname
    $ddfpath = ($env:TEMP+"\temp.ddf")
    $ddf += (ls -recurse $source | where { !$_.PSIsContainer } | select -ExpandProperty FullName | foreach { '"' + $_ + '" "' + $_.SubString($dirfullname.length+1) + '"' }) -join "`r`n"
    $ddf
    $ddf | Out-File -Encoding UTF8 $ddfpath
    makecab.exe /F $ddfpath
    rm $ddfpath
    rm setup.rpt
	rm setup.inf
}

compress-directory