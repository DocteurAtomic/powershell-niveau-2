# Clip 7.3: a background job, in its own process, loads what the session cannot. Pester 6.2.0
# is loaded here; Pester 5.9.1, the version dbachecks needs (module 10), does not load in the
# same process, so neither in a thread job.
Import-Module -Name Pester -RequiredVersion 6.2.0
try {
    Start-ThreadJob -ScriptBlock { Import-Module -Name Pester -RequiredVersion 5.9.1 -PassThru } |
        Receive-Job -Wait -AutoRemoveJob -ErrorAction Stop
}
catch {
    "Thread job: $($_.Exception.Message)"
}
$module = Start-Job -ScriptBlock { Import-Module -Name Pester -RequiredVersion 5.9.1 -PassThru } |
    Receive-Job -Wait -AutoRemoveJob
"Background job: Pester $($module.Version), returned as $($module.PSObject.TypeNames[0])"
"This session: Pester $((Get-Module -Name Pester).Version)"
