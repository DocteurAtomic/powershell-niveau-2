# Clip 2.4: the tests of the team, run by a configuration, and their result read as an object.
# Run it from the root of the clone, or type the lines one after the other.
$configuration = New-PesterConfiguration
$configuration.Run.Path = 'tests'
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration

# Out-Host shows the summary at once: a script that returns two kinds of objects mixes them
# in one table (level 1, clip 2.4). At the console, each line has its own display.
$result | Select-Object -Property Result, TotalCount, PassedCount, FailedCount | Out-Host
$result.Failed | Select-Object -Property ExpandedName, @{ Name = 'Message'; Expression = { $_.ErrorRecord.Exception.Message } }
