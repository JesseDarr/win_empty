#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"     # so we can catch errors and fail the module without any code continuing on the remote system
Set-StrictMode -Version 2.0         # this can be removed after testing

$spec = @{
    options = @{
        age = @{  type = "int"; default = "0" }
        ageStamp = @{  type = "str"; default = "mtime"; choices = "atime", "ctime", "mtime"}

        keepFolders = @{ type = "bool"; default = $false }

        patterns = @{ type = "list"; elements = "str"; default=@('*') }                        
        
        path = @{  type = "str"; required = $true}
        state = @{  type = "str"; choices = "delete", "empty"; required = $true}
    }
    supports_check_mode = $true 
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$age = $module.Params.age
$ageStamp = $module.Params.ageStamp
$checkMode = $Module.CheckMode
$keepFolders = $module.Params.keepFolders
$patterns = $module.Params.patterns
$path = $module.Params.path
$state = $module.Params.state

Function Empty-Folder {
    Param (
        [System.String]
        $Age,

        [System.String]
        $AgeStamp,
        
        [System.Boolean]
        $CheckMode,

        [System.Boolean]
        $KeepFolders,

        [System.String[]]
        $Patterns,

        [Parameter(Mandatory=$true)]
        [System.String[]]
        $Path,

        [Parameter(Mandatory=$true)]
        [System.String]
        $State
    )

    switch ($State) {
        # attempting to delete entire directory
        # if only some items can be deleted it will return a skip and return a list of deleted files
        "delete" {
            if (Test-Path -path $Path) {
                $beforeChildList = Get-ChildItem -path $Path -recurse -force
                $error.clear()
                try {
                    Remove-Item -path $Path -recurse -force -confirm:$false -whatif:$CheckMode # force is needed to delete read-only and hidden files
                }
                catch {
                    if ($CheckMode){
                        $module.Result.msg = "Check Mode: Failure: $_.Exception.Message"
                        $module.Result.skipped = $true
                    } else {
                        $afterChildList = Get-ChildItem -path $Path -recurse -force
                        $resultChildList = $beforeChildList | Where-Object { $afterChildList.FullName -notcontains $_.FullName }
                        # check if no files were deleted and write different output based on that
                        if ($null -eq $resultChildList){
                            $module.Result.msg = "Directory $Path was not deleted.  No sub-items were deleted."
                            $module.Result.skipped = $true
                        } else {
                            $resultPathList = $resultChildList.FullName
                            $totalDeletedCount = ($resultPathList | Measure-Object).Count
                            $module.Result.msg = "Directory $Path was not deleted.  The following $totalDeletedCount sub-items were deleted: $resultPathList"
                            $module.Result.skipped = $true
                        }
                    }
                }
                if (!$error){
                    if ($CheckMode) {
                        $module.Result.msg = "Check Mode: Directory $Path would have been successfully deleted."
                        $module.Result.skipped = $true
                    } else {
                        $module.Result.msg = "Directory $Path was successfully deleted."
                        $module.Result.changed = $true
                    }
                }
            } else {
                $module.Result.msg = "Directory $Path does not exist."
                $module.Result.skipped = $true
            }
        }

        "empty" {
            # attempting to delete sub-items in a directory but preserve the directory itself
            # if only some items can be deleted it will return a skip and return a list of deleted files
            #
            # output is based on what you asked it to delete - i.e. removing files over 100 days when there are no files that old
            # would result in a 'Directory $Path was successfully emptied' message.
            if ((Test-Path -path $Path) -or ($Path -eq "c:\`$recycle.bin")) { 
                $beforeChildList = Get-ChildItem -path $Path -recurse -force
                if (($beforeChildList | Measure-Object).Count -gt 0) { 
                    
                    $actualAgeStamp = switch ($AgeStamp) {
                        mtime { "LastWriteTime" }
                        ctime { "CreationTime" }
                        atime { "LastAccessTime" }
                    }
                    $dateToDelete = (Get-Date).AddDays(-$Age)

                    $error.clear()
                    try {                        
                        foreach ($pattern in $Patterns) {
                            if ($KeepFolders -eq $true) {
                                Get-ChildItem -path $Path -include $pattern -recurse -force | Where-Object { ! $_.PSIsContainer } | Where-Object { $_.$actualAgeStamp -lt $dateToDelete } | Remove-Item -recurse -force -confirm:$false -whatif:$CheckMode
                            } else {
                                Get-ChildItem -path $Path -include $pattern -recurse -force | Where-Object { $_.$actualAgeStamp -lt $dateToDelete } | Remove-Item -recurse -force -confirm:$false -whatif:$CheckMode
                            }                            
                        }
                    }
                    catch {
                        if ($CheckMode){
                            $module.Result.msg = "Check Mode: Failure: $_.Exception.Message"
                            $module.Result.skipped = $true
                        } else {
                            $afterChildList = Get-ChildItem -path $Path -recurse -force
                            if ($null -eq $afterChildList) { # this is needed because of a special case regarding the recycle bin
                                $module.Result.msg = "Directory $Path was successfully emptied."
                                $module.Result.changed = $true
                            } else {
                                $resultChildList = $beforeChildList | Where-Object { $afterChildList.FullName -notcontains $_.FullName }
                                # check if no files were deleted and write different output based on that
                                if ($null -eq $resultChildList){
                                    #$module.Result.msg = "Error: $_.Exception"
                                    $module.Result.msg = "Directory $Path was not emptied.  No sub-items were deleted."
                                    $module.Result.skipped = $true
                                } else {
                                    $resultPathList = $resultChildList.FullName
                                    $totalDeletedCount = ($resultPathList | Measure-Object).Count
                                    $module.Result.msg = "Directory $Path was not completely emptied.  The following $totalDeletedCount sub-items were deleted: $resultPathList"
                                    $module.Result.skipped = $true
                                }
                            }
                        }
                    }
                    if (!$error){
                        if ($CheckMode) {
                            $module.Result.msg = "Check Mode: Directory $Path would have been successfully emptied."
                            $module.Result.skipped = $true
                        } else {
                            $module.Result.msg = "Directory $Path was successfully emptied."
                            $module.Result.changed = $true
                        }
                    }
                } else {
                    $module.Result.msg = "Directory $Path is already empty."
                    $module.Result.skipped = $true
                }
            } else {
                $module.Result.msg = "Directory $Path does not exist."
                $module.Result.skipped = $true
            }
        }
    }
}

Empty-Folder -age $age -agestamp $ageStamp -checkmode $checkMode -keepFolders $keepFolders -patterns $patterns -path $path -state $state

$module.ExitJson()