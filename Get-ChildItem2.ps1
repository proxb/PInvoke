Function Get-ChildItem2 {
    <#
        .SYNOPSIS
            Gets the files and folders in a file system drive beyond the 256 character limitation

        .DESCRIPTION
            Gets the files and folders in a file system drive beyond the 256 character limitation

        .PARAMETER Path
            Path to a folder/file

        .PARAMETER Filter
            Filter object by name. Accepts wildcard (*)

        .PARAMETER Recurse
            Perform a recursive scan

        .PARAMETER Depth
            Limit the depth of a recursive scan

        .PARAMETER Directory
            Only show directories

        .PARAMETER File
            Only show files

        .NOTES
            Name: Get-ChildItem2
            Author: Boe Prox
            Version History:
                1.4 //Boe Prox <21 OCt 2015>
                    - Bug fixes in output
                    - Auto conversion of path to UNC for bypassing 260 character limit w/o user input
                1.2 //Boe Prox <20 Oct 2015>
                    - Added additional parameters (File, Directory and Filter)
                    - Made output mirror Get-ChildItem
                    - Added Mode property
                1.0 //Boe Prox
                    - Initial version

        .OUTPUT
            System.Io.DirectoryInfo
            System.Io.FileInfo

        .EXAMPLE
            Get-ChildItem2 -Recurse -Depth 3 -Directory

            Description
            -----------
            Performs a scan from the current directory and recursively displays all
            directories down to 3 folder levels.
    #>
    [OutputType('System.Io.DirectoryInfo','System.Io.FileInfo')]
    [cmdletbinding(
        DefaultParameterSetName = '__DefaultParameterSet'
    )]
    Param (
        [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        [Alias('FullName','PSPath')]
        [string[]]$Path = $PWD.ToString(),
        [parameter()]
        [string]$Filter,
        [parameter()]
        [switch]$Recurse,
        [parameter()]
        [int]$Depth,
        [parameter()]
        [switch]$Directory,
        [parameter()]
        [switch]$File
    )
    Begin {
        Try{
            [void][PoshFile]
        } Catch {
            #region Module Builder
            $Domain = [AppDomain]::CurrentDomain
            $DynAssembly = New-Object System.Reflection.AssemblyName('SomeAssembly')
            $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run) # Only run in memory
            $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('SomeModule', $False)
            #endregion Module Builder
 
            #region Structs            
            $Attributes = 'AutoLayout,AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            #region WIN32_FIND_DATA STRUCT
            $UNICODEAttributes = 'AutoLayout,AnsiClass, UnicodeClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('WIN32_FIND_DATA', $UNICODEAttributes, [System.ValueType], [System.Reflection.Emit.PackingSize]::Size4)
            [void]$STRUCT_TypeBuilder.DefineField('dwFileAttributes', [int32], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('ftCreationTime', [long], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('ftLastAccessTime', [long], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('ftLastWriteTime', [long], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('nFileSizeHigh', [int32], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('nFileSizeLow', [int32], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('dwReserved0', [int32], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('dwReserved1', [int32], 'Public')
 
            $ctor = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructor(@([System.Runtime.InteropServices.UnmanagedType]))
            $CustomAttribute = [System.Runtime.InteropServices.UnmanagedType]::ByValTStr
            $SizeConstField = [System.Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst')
            $CustomAttributeBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder -ArgumentList $ctor, $CustomAttribute, $SizeConstField, @(260)
            $cFileNameField = $STRUCT_TypeBuilder.DefineField('cFileName', [string], 'Public')
            $cFileNameField.SetCustomAttribute($CustomAttributeBuilder)
 
            $CustomAttributeBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder -ArgumentList $ctor, $CustomAttribute, $SizeConstField, @(14)
            $cAlternateFileName = $STRUCT_TypeBuilder.DefineField('cAlternateFileName', [string], 'Public')
            $cAlternateFileName.SetCustomAttribute($CustomAttributeBuilder)
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion WIN32_FIND_DATA STRUCT
            #endregion Structs
 
            #region Initialize Type Builder
            $TypeBuilder = $ModuleBuilder.DefineType('PoshFile', 'Public, Class')
            #endregion Initialize Type Builder
 
            #region Methods
            #region FindFirstFile METHOD
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'FindFirstFile', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [IntPtr], #Method Return Type
                [Type[]] @(
                    [string],
                    [WIN32_FIND_DATA].MakeByRefType()
                ) #Method Parameters
            )
            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
                [Runtime.InteropServices.DllImportAttribute].GetField('ExactSpelling')
                [Runtime.InteropServices.DllImportAttribute].GetField('CharSet')
            )
 
            $FieldValueArray = [Object[]] @(
                'FindFirstFile', #CASE SENSITIVE!!
                $True,
                $False,
                [System.Runtime.InteropServices.CharSet]::Unicode
            )
 
            $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('kernel32.dll'),
                $FieldArray,
                $FieldValueArray
            )
 
            $PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
            #endregion FindFirstFile METHOD
 
            #region FindNextFile METHOD
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'FindNextFile', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
                [Type[]] @(
                    [IntPtr],
                    [WIN32_FIND_DATA].MakeByRefType()
                ) #Method Parameters
            )
            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
                [Runtime.InteropServices.DllImportAttribute].GetField('ExactSpelling')
                [Runtime.InteropServices.DllImportAttribute].GetField('CharSet')
            )
 
            $FieldValueArray = [Object[]] @(
                'FindNextFile', #CASE SENSITIVE!!
                $True,
                $False,
                [System.Runtime.InteropServices.CharSet]::Unicode
            )
 
            $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('kernel32.dll'),
                $FieldArray,
                $FieldValueArray
            )
 
            $PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
            #endregion FindNextFile METHOD

            #region FindClose METHOD
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'FindClose', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
                [Type[]] @(
                    [IntPtr]
                ) #Method Parameters
            )
            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
                [Runtime.InteropServices.DllImportAttribute].GetField('ExactSpelling')
            )
 
            $FieldValueArray = [Object[]] @(
                'FindClose', #CASE SENSITIVE!!
                $True,
                $True
            )
 
            $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('kernel32.dll'),
                $FieldArray,
                $FieldValueArray
            )
 
            $PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
            #endregion FindClose METHOD
            #endregion Methods
 
            #region Create Type
            [void]$TypeBuilder.CreateType()
            #endregion Create Type    
        }
    }
    Process {
            ForEach ($Item in $Path ) {
            #region Inititalize Data
            $Found = $True    
            $findData = New-Object WIN32_FIND_DATA 
            #endregion Inititalize Data
            If ($Item -notmatch '^[a-z]:|^\\\\') {
                $Item = Convert-Path $Item
            }
            If ($Item.Endswith('\')) {
                $SearchPath = "$($Item)*"
            } ElseIf ($Item.EndsWith(':')) {
                $SearchPath = "$($Item)\*"
                $Item = "$($Item)\"
            } ElseIf ($Item.Endswith('*')) {
                $SearchPath = $Item
            } Else {
                $SearchPath = "$($Item)\*"
                $Item = "$($Item)\"
            }
            If (-NOT $Item.StartsWith('\\')) {
                $Item = "\\?\$($Item)"
                $SearchPath = "\\?\$($SearchPath)"
            }
            If ($PSBoundParameters.ContainsKey('Recurse') -AND (-NOT $PSBoundParameters.ContainsKey('Depth'))) {
                $PSBoundParameters.Depth = [int]::MaxValue
                $Depth = [int]::MaxValue
            }
            If (-NOT $PSBoundParameters.ContainsKey('Recurse') -AND ($PSBoundParameters.ContainsKey('Depth'))) {
                Throw "Cannot set Depth without Recurse parameter!"
            }
            Write-Verbose "Search: $($SearchPath)"
            Write-Verbose "Depth: $($Script:Count)"
            $Handle = [poshfile]::FindFirstFile("$SearchPath",[ref]$findData)
            If ($Handle -ne -1) {
                While ($Found) {
                    If ($findData.cFileName -notmatch '^(\.){1,2}$') {
                        $IsDirectory =  [bool]($findData.dwFileAttributes -BAND 16)  
                        $FullName = "$($Item)$($findData.cFileName)"
                        $Mode = New-Object System.Text.StringBuilder                    
                        If ($findData.dwFileAttributes -BAND [System.IO.FileAttributes]::Directory) {
                            [void]$Mode.Append('d')
                        } Else {
                            [void]$Mode.Append('-')
                        }
                        If ($findData.dwFileAttributes -BAND [System.IO.FileAttributes]::Archive) {
                            [void]$Mode.Append('a')
                        } Else {
                            [void]$Mode.Append('-')
                        }
                        If ($findData.dwFileAttributes -BAND [System.IO.FileAttributes]::ReadOnly) {
                            [void]$Mode.Append('r')
                        } Else {
                            [void]$Mode.Append('-')
                        }
                        If ($findData.dwFileAttributes -BAND [System.IO.FileAttributes]::Hidden) {
                            [void]$Mode.Append('h')
                        } Else {
                            [void]$Mode.Append('-')
                        }
                        If ($findData.dwFileAttributes -BAND [System.IO.FileAttributes]::System) {
                            [void]$Mode.Append('s')
                        } Else {
                            [void]$Mode.Append('-')
                        }
                        If ($findData.dwFileAttributes -BAND [System.IO.FileAttributes]::ReparsePoint) {
                            [void]$Mode.Append('l')
                        } Else {
                            [void]$Mode.Append('-')
                        }
                        $Fullname = ([string]$FullName).replace('\\?\','')
                        $Object = New-Object PSObject -Property @{
                            Name = [string]$findData.cFileName
                            FullName = $Fullname
                            Length = $Null                       
                            Attributes = [System.IO.FileAttributes]$findData.dwFileAttributes
                            LastWriteTime = [datetime]::FromFileTime($findData.ftLastWriteTime)
                            LastAccessTime = [datetime]::FromFileTime($findData.ftLastAccessTime)
                            CreationTime = [datetime]::FromFileTime($findData.ftCreationTime)
                            PSIsContainer = [bool]$IsDirectory
                            Mode = $Mode.ToString()
                        }    
                        If ($Object.PSIsContainer) {
                            $Object.pstypenames.insert(0,'System.Io.DirectoryInfo')
                        } Else {
                            $Object.Length = [int64]("0x{0:x}" -f $findData.nFileSizeLow)
                            $Object.pstypenames.insert(0,'System.Io.FileInfo')
                        }
                        If ($PSBoundParameters.ContainsKey('Directory') -AND $Object.PSIsContainer) {                            
                            $ToOutPut = $Object
                        } ElseIf ($PSBoundParameters.ContainsKey('File') -AND (-NOT $Object.PSIsContainer)) {
                            $ToOutPut = $Object
                        }
                        If (-Not ($PSBoundParameters.ContainsKey('Directory') -OR $PSBoundParameters.ContainsKey('File'))) {
                            $ToOutPut = $Object
                        } 
                        If ($PSBoundParameters.ContainsKey('Filter')) {
                            If (-NOT ($ToOutPut.Name -like $Filter)) {
                                $ToOutPut = $Null
                            }
                        }
                        If ($ToOutPut) {
                            $ToOutPut
                            $ToOutPut = $Null
                        }
                        If ($Recurse -AND $IsDirectory -AND ($PSBoundParameters.ContainsKey('Depth') -AND [int]$Script:Count -lt $Depth)) {                        
                            #Dive deeper
                            Write-Verbose "Recursive"
                            $Script:Count++
                            $PSBoundParameters.Path = $FullName
                            Get-ChildItem2 @PSBoundParameters
                            $Script:Count--
                        }
                    }
                    $Found = [poshfile]::FindNextFile($Handle,[ref]$findData)
                }
                [void][PoshFile]::FindClose($Handle)
            }
        }
    }
} 

Set-Alias GCI2 Get-ChildItem2