Function Get-NetSession {
    <#
        .SYNOPSIS
            Queries the remote system for all net sessions

        .DESCRIPTION
            Queries the remote system for all net sessions

        .PARAMETER Computername
            Computer to query for net sessions

        .PARAMETER Username
            Specifies a user to look for in the net sessions

        .PARAMETER IncludeSelf
            Includes the current user session used to run this command

        .NOTES
            Name: Get-NetSession
            Author: Boe Prox
            Version History:
                1.1 //Boe Prox - 1 August 2016
                    - Added IncludeSelf parameter to include displaying the session created from command otherwise
                    this data is not presented
                    - Bug fixes

                1.0 //Boe Prox - 28 July 2016
                    - Initial build

        .EXAMPLE
            Get-NetSession -Computername Server1

            Computername    : Server1
            SourceComputer  : Workstation1
            SourceIPAddress : 192.168.2.56
            Username        : bobsmith
            SessionTime     : 0
            IdleTime        : 0

            Computername    : Server1
            SourceComputer  : Workstation2
            SourceIPAddress : 192.168.2.110
            Username        : joeuser
            SessionTime     : 348607
            IdleTime        : 345850

            Description
            -----------
            Returns all net sessions on Server1
    #>
    [cmdletbinding()]
    Param (
        [parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [string[]]$Computername,
        [parameter()]
        [string]$Username = '',
        [parameter()]
        [switch]$IncludeSelf
    )
    Begin {
        If ($PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = 'Continue'
        }
        If (-NOT $PSBoundParameters.ContainsKey('IncludeSelf')) {
            $Hostname = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
            Write-Verbose "Excluding $Hostname and $($env:USERNAME)"
        }
        #region Reflection
        Try {
            [void][Net.Session]
        } 
        Catch {
            Write-Verbose "Building pinvoke via reflection"
            #region Module Builder
            $Domain = [AppDomain]::CurrentDomain
            $DynAssembly = New-Object System.Reflection.AssemblyName('NetSession')
            $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run) # Only run in memory
            $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('NetSessionModule', $False)
            #endregion Module Builder

            #region Custom Attribute Builder
            $ctor = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructor(@([System.Runtime.InteropServices.UnmanagedType]))
            $CustomAttribute = [System.Runtime.InteropServices.UnmanagedType]::LPWStr
            $CustomAttributeBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder -ArgumentList $ctor, $CustomAttribute
            #endregion Custom Attribute Builder

            #region Struct
            #region SESSION_INFO_10
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SESSION_INFO_10', $Attributes, [System.ValueType], 8, 0x0)
            $Field = $STRUCT_TypeBuilder.DefineField('OriginatingHost', [string], 'Public')
            $Field.SetCustomAttribute($CustomAttributeBuilder)
            $Field = $STRUCT_TypeBuilder.DefineField('DomainUser', [string], 'Public')
            $Field.SetCustomAttribute($CustomAttributeBuilder)
            [void]$STRUCT_TypeBuilder.DefineField('SessionTime', [uint32], 'Public')
            [void]$STRUCT_TypeBuilder.DefineField('IdleTime', [uint32], 'Public')
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SESSION_INFO_10
            #endregion Struct

            $TypeBuilder = $ModuleBuilder.DefineType('Net.Session', 'Public, Class')

            #region Methods
            #region NetSessionEnum Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'NetSessionEnum', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [int32], #Method Return Type
                [Type[]] @(
                    [string],
                    [string],
                    [string],
                    [int32],
                    [intptr].MakeByRefType(),
                    [int],
                    [int32].MakeByRefType(),
                    [int32].MakeByRefType(),
                    [int32].MakeByRefType()
                ) #Method Parameters
            )

            #Define first three parameters with custom attributes
            1..3 | ForEach {
                $Parameter = $PInvokeMethod.DefineParameter(
                    $_,
                    [System.Reflection.ParameterAttributes]::In,
                    $Null
                )
                $Parameter.SetCustomAttribute(
                    $CustomAttributeBuilder
                )
            }

            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
                [Runtime.InteropServices.DllImportAttribute].GetField('ExactSpelling')
                [Runtime.InteropServices.DllImportAttribute].GetField('PreserveSig')
            )

            $FieldValueArray = [Object[]] @(
                'NetSessionEnum', #CASE SENSITIVE!!
                $True,
                $True,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('Netapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion NetSessionEnum Method
            #region NetApiBufferFree Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'NetApiBufferFree', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [int], #Method Return Type
                [Type[]] @(
                    [intptr]
                ) #Method Parameters
            )

            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
                [Runtime.InteropServices.DllImportAttribute].GetField('ExactSpelling')
                [Runtime.InteropServices.DllImportAttribute].GetField('PreserveSig')
            )

            $FieldValueArray = [Object[]] @(
                'NetApiBufferFree', #CASE SENSITIVE!!
                $True,
                $True,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('Netapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion NetApiBufferFree Method
            #endregion Methods

            [void]$TypeBuilder.CreateType()
        }
        #endregion Reflection
        
    }
    Process {
        ForEach ($Computer in $Computername) {
            Write-Verbose "Scanning $Computer"
            $SessionInfo10 = New-Object -TypeName SESSION_INFO_10
            $SessionInfo10Size = [System.Runtime.InteropServices.Marshal]::SizeOf($SessionInfo10)
            $Buffer = [IntPtr]::Zero
            [int32]$EntriesRead = 0
            [int32]$TotalEntries = 0
            [int32]$ResumeHandle = 0
            $Return = [Net.Session]::NetSessionEnum(
                $Computer, 
                "", 
                $Username, 
                10, 
                [ref]$Buffer, 
                -1, 
                [ref]$EntriesRead, 
                [ref]$TotalEntries, 
                [ref]$ResumeHandle
            )
            $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()

            If ([System.IntPtr]::Size -eq 4) {
                $BufferOffset = $Buffer.ToInt32()
            }
            Else {
                $BufferOffset = $Buffer.ToInt64()
            }
                                          
            For ($Count = 0; ($Count -lt $EntriesRead); $Count++){
                $NewBuffer = New-Object System.Intptr -ArgumentList $BufferOffset
                $Info = [System.Runtime.Interopservices.Marshal]::PtrToStructure($NewBuffer,[type]$SessionInfo10.GetType())
                $Info | ForEach {                    
                    $IP = $_.OriginatingHost.Trim('\\')
                    Try {
                        $ResolvedName = [Net.DNS]::GetHostByAddress($IP).HostName
                    }
                    Catch {
                        $ResolvedName = 'N/A'
                    }
                    $Object = [pscustomobject]@{
                        Computername = $Computer
                        SourceComputer = $ResolvedName
                        SourceIPAddress = $IP
                        Username = $_.DomainUser
                        SessionTime = $_.SessionTime
                        IdleTime = $_.IdleTime
                    }
                    $Object.pstypenames.insert(0,'Net.SessionInformation')
                    If (($PSBoundParameters.ContainsKey('IncludeSelf'))) { 
                        $Object

                    } 
                    ElseIf (-NOT ((($ResolvedName -eq $Hostname) -OR ($IP -eq $env:COMPUTERNAME)) -AND ($_.DomainUser -eq $env:USERNAME))) {
                        $Object
                    }
                }
                $BufferOffset = $BufferOffset + $SessionInfo10Size
            }
         
            [void][Net.Session]::NetApiBufferFree($Buffer)
        }
    }
    End {}
}