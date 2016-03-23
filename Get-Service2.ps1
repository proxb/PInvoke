Function Get-Service2 {
    <#
        .SYNOPSIS
            Returns information about a single or multiple services on a local or remote system.

        .DESCRIPTION
            Returns information about a single or multiple services on a local or remote system.

        .PARAMETER Computername
            Name of the computer to query. Default is the local computer.
            Accepts multiple values.

        .PARAMETER Name
            Name of the service to query. Accepts multiple values.

        .PARAMETER ServiceType
            The type of service to query. Default is Win32. Accepts multiple values.

        .NOTES
            Name: Get-Service2
            Author: Boe Prox
            Version History:
                1.4 //Boe Prox - 22 March 2016
                    - Added 32 bit support
                    - Added custom type formatting
                1.3 // Boe Prox - 26 Feb 2016
                    - Added support for multiple Computername and Service Names
                1.2 // Boe Prox - 24 Feb 2016
                    - Expanded to list all services if -Name not used
                    - Expanded data being collected on each service
                    - Added Verbose/Debugging lines
                1.0 // Boe Prox - 19 Feb 2016
                    - Initial build

        .OUTPUT
            System.Service

        .EXAMPLE
            Get-Service2

              State Name            DisplayName                        StartMode
              ----- ----            -----------                        ---------
            Running ac.sharedstore  ActivIdentity Shared Store Service      Auto
            Running ACCMService     ACCM Service                            Auto
            Running AdobeARMservice Adobe Acrobat Update Service            Auto
            Running AeLookupSvc     Application Experience                Manual
            Stopped ALG             Application Layer Gateway Service     Manual

            Description
            -----------
            Lists all services on the local system

        .EXAMPLE
            Get-Service2 -ServiceType Interactive

              State Name      DisplayName                    StartMode
              ----- ----      -----------                    ---------
            Running Spooler   Print Spooler                       Auto
            Stopped UI0Detect Interactive Services Detection    Manual

            Description
            -----------
            Lists all services which have a type of Interactive.

        .EXAMPLE
            Get-Service2 -Name WebClient

            Name               : WebClient
            DisplayName        : WebClient
            Description        : Enables Windows-based programs to create, access, and 
                                 modify Internet-based files. If this service is stopped, 
                                 these functions will not be available. If this service is 
                                 disabled, any services that explicitly depend on it will 
                                 fail to start.
            Triggers           : TRIGGER
            IsDelayedAutoStart : False
            SIDType            : Unrestricted
            Privileges         : {SeImpersonatePrivilege, SeCreateGlobalPrivilege, 
                                 SeAssignPrimaryTokenPrivilege, SeIncreaseQuotaPrivilege}
            ShutdownTimeout    : 180000
            PreferredNode      : 
            FailureActionsFlag : False
            FailureActions     : FAILURE_ACTIONS
            Type               : Win32ShareProcess
            State              : Running
            Controls           : AcceptStop
            Win32ExitCode      : 0
            ServiceExitCode    : 0
            CheckPoint         : 0
            WaitHint           : 0
            ProcessID          : 1168
            ServiceFlags       : NotProcessOrNotRunning
            StartMode          : Auto
            ErrorControl       : Normal
            FilePath           : C:\WINDOWS\system32\svchost.exe -k LocalService
            LoadOrderGroup     : NetworkProvider
            TagID              : 0
            Dependancies       : MRxDAV
            StartName          : NT AUTHORITY\LocalService
            DependantServices  : {}
            Computername       : System1

            Description
            -----------
            Displays extra information about the WebClient service.
    #>
    [OutputType('System.Service')]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$Name,
        [parameter(ValueFromPipelineByPropertyName=$True)]
        [Alias('CN','__Server','PSComputername')]
        [string[]]$Computername = $env:COMPUTERNAME,
        [parameter()]
        [ValidateSet('Win32','Win32OwnProcess','Win32ShareProcess','FileSystemDriver','KernelDriver','All','Interactive')]
        [string]$ServiceType = 'Win32'
    )
    Begin {
        If ($PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = 'Continue'
        }
        #region Reflection
        Try {
            [void][Service.Trigger]
        } 
        Catch {
            Write-Verbose 'Building pinvoke via reflection'
            #region Module Builder
            $Domain = [AppDomain]::CurrentDomain
            $DynAssembly = New-Object System.Reflection.AssemblyName('ServiceTrigger')
            $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run) # Only run in memory
            $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('ServiceTrigger', $False)
            #endregion Module Builder

            #region Enums

            #region SC_ENUM_TYPE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SC_ENUM_TYPE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('SC_ENUM_PROCESS_INFO', [uint32] 0x00000000)
            [void]$EnumBuilder.CreateType()
            #endregion SC_ENUM_TYPE

            #region ERROR_CONTROL 
            $EnumBuilder = $ModuleBuilder.DefineEnum('ERROR_CONTROL', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('Ignore', [uint32] 0x00000000)
            [void]$EnumBuilder.DefineLiteral('Normal', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('Severe', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('Critical', [uint32] 0x00000003)
            [void]$EnumBuilder.CreateType()
            #endregion ERROR_CONTROL

            #region SERVICE_START_TYPE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_START_TYPE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('BootStart', [uint32] 0x00000000)
            [void]$EnumBuilder.DefineLiteral('SystemStart', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('Auto', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('Manual', [uint32] 0x00000003)
            [void]$EnumBuilder.DefineLiteral('Disabled', [uint32] 0x00000004)
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_START_TYPE

            #region SERVICE_CONTROL_CODE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_CONTROL_CODE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('Unknown', [uint32] 0x00000000)
            [void]$EnumBuilder.DefineLiteral('AcceptStop', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('AcceptPauseContinue', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('AcceptShutdown', [uint32] 0x00000004)
            [void]$EnumBuilder.DefineLiteral('AcceptParamChange', [uint32] 0x00000008)
            [void]$EnumBuilder.DefineLiteral('AcceptNetBindingChange', [uint32] 0x00000010)
            [void]$EnumBuilder.DefineLiteral('AcceptHardwareProfileChange', [uint32] 0x00000020)
            [void]$EnumBuilder.DefineLiteral('AcceptPowerEvent', [uint32] 0x00000040)
            [void]$EnumBuilder.DefineLiteral('AcceptSessionChange', [uint32] 0x00000080)
            [void]$EnumBuilder.DefineLiteral('AcceptPreShutdown', [uint32] 0x00000100)
            [void]$EnumBuilder.DefineLiteral('AcceptTimeChange', [uint32] 0x00000200)
            [void]$EnumBuilder.DefineLiteral('AcceptTriggerEvent', [uint32] 0x00000400)
            [void]$EnumBuilder.DefineLiteral('AcceptUserModeReboot', [uint32] 0x00000800)
            $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_CONTROL_CODE

            #region SERVICE_FLAGS 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_FLAGS', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('NotProcessOrNotRunning', [uint32] 0x00000000)
            [void]$EnumBuilder.DefineLiteral('ServiceRunsInSystemProcess', [uint32] 0x00000001)
            $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_FLAGS

            #region SERVICE_STATES 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_STATES', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('SERVICE_ACTIVE', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('SERVICE_INACTIVE', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('SERVICE_ALL', [uint32] 0x00000003)
            $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_STATES

            #region SERVICE_STATE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_STATE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('Stopped', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('StartPending', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('StopPending', [uint32] 0x00000003)
            [void]$EnumBuilder.DefineLiteral('Running', [uint32] 0x00000004)
            [void]$EnumBuilder.DefineLiteral('ContinuePending', [uint32] 0x00000005)
            [void]$EnumBuilder.DefineLiteral('PausePending', [uint32] 0x00000006)
            [void]$EnumBuilder.DefineLiteral('Paused', [uint32] 0x00000007)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_STATE

            #region SERVICE_TYPE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_TYPE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('KernelDriver', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('FileSystemDriver', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('Driver', [uint32] 0x0000000B)
            [void]$EnumBuilder.DefineLiteral('Win32OwnProcess', [uint32] 0x00000010)
            [void]$EnumBuilder.DefineLiteral('Win32ShareProcess', [uint32] 0x00000020)
            [void]$EnumBuilder.DefineLiteral('Win32', [uint32] 0x00000030)
            [void]$EnumBuilder.DefineLiteral('Interactive', [uint32] 0x00000100)
            [void]$EnumBuilder.DefineLiteral('All', [uint32] 0x0000013B)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_TYPE

            #region SERVICE_SID_TYPE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_SID_TYPE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('None', [uint32] 0x00000000)
            [void]$EnumBuilder.DefineLiteral('Unrestricted', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('Restricted', [uint32] 0x00000003)            
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_SID_TYPE

            #region SCM_ACCESS 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SCM_ACCESS', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('STANDARD_RIGHTS_REQUIRED', [uint32] 0x000F0000)
            [void]$EnumBuilder.DefineLiteral('SC_MANAGER_CONNECT', [uint32] 0x00001)
            [void]$EnumBuilder.DefineLiteral('SC_MANAGER_CREATE_SERVICE', [uint32] 0x00002)
            [void]$EnumBuilder.DefineLiteral('SC_MANAGER_ENUMERATE_SERVICE', [uint32] 0x00004)
            [void]$EnumBuilder.DefineLiteral('SC_MANAGER_LOCK', [uint32] 0x00008)
            [void]$EnumBuilder.DefineLiteral('SC_MANAGER_QUERY_LOCK_STATUS', [uint32] 0x00010)
            [void]$EnumBuilder.DefineLiteral('SC_MANAGER_MODIFY_BOOT_CONFIG', [uint32] 0x00020)
            [void]$EnumBuilder.DefineLiteral('SC_MANAGER_ALL_ACCESS', [uint32] 0xf003f)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SCM_ACCESS

            #region SERVICE_ACCESS 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_ACCESS', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('STANDARD_RIGHTS_REQUIRED', [uint32] 0x000F0000)
            [void]$EnumBuilder.DefineLiteral('SERVICE_QUERY_CONFIG', [uint32] 0x00001)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CHANGE_CONFIG', [uint32] 0x00002)
            [void]$EnumBuilder.DefineLiteral('SERVICE_QUERY_STATUS', [uint32] 0x00004)
            [void]$EnumBuilder.DefineLiteral('SERVICE_ENUMERATE_DEPENDENTS', [uint32] 0x00008)
            [void]$EnumBuilder.DefineLiteral('SERVICE_START', [uint32] 0x00010)
            [void]$EnumBuilder.DefineLiteral('SERVICE_STOP', [uint32] 0x00020)
            [void]$EnumBuilder.DefineLiteral('SERVICE_PAUSE_CONTINUE', [uint32] 0x00040)
            [void]$EnumBuilder.DefineLiteral('SERVICE_INTERROGATE', [uint32] 0x00080)
            [void]$EnumBuilder.DefineLiteral('SERVICE_USER_DEFINED_CONTROL', [uint32] 0x00100)
            [void]$EnumBuilder.DefineLiteral('SERVICE_ALL_ACCESS', [uint32] 0xf01ff)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_ACCESS

            #region SERVICE_INFO_LEVEL 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SERVICE_INFO_LEVEL', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_DELAYED_AUTO_START_INFO', [uint32] 0x00000003)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_DESCRIPTION', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_FAILURE_ACTIONS', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_FAILURE_ACTIONS_FLAG', [uint32] 0x00000004)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_PREFERRED_NODE', [uint32] 0x00000009)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_PRESHUTDOWN_INFO', [uint32] 0x00000007)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO', [uint32] 0x00000006)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_SERVICE_SID_INFO', [uint32] 0x00000005)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_TRIGGER_INFO', [uint32] 0x00000008)
            [void]$EnumBuilder.DefineLiteral('SERVICE_CONFIG_LAUNCH_PROTECTED', [uint32] 0x0000000c)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SERVICE_INFO_LEVEL

            #region TRIGGER_DATA_TYPE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('TRIGGER_DATA_TYPE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('BINARY', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('STRING', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('LEVEL', [uint32] 0x00000003)
            [void]$EnumBuilder.DefineLiteral('KEYWORD_ANY', [uint32] 0x00000004)
            [void]$EnumBuilder.DefineLiteral('KEYWORD_ALL', [uint32] 0x00000005)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion TRIGGER_DATA_TYPE

            #region TRIGGER_TYPE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('TRIGGER_TYPE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('DeviceInterfaceArrival', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('IPAddressAvailability', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('DomainJoin', [uint32] 0x00000003)
            [void]$EnumBuilder.DefineLiteral('FirewallPortEvent', [uint32] 0x00000004)
            [void]$EnumBuilder.DefineLiteral('GroupPolicy', [uint32] 0x00000005)
            [void]$EnumBuilder.DefineLiteral('NetworkEndpoint', [uint32] 0x00000006)
            [void]$EnumBuilder.DefineLiteral('Custom', [uint32] 0x00000014)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion TRIGGER_TYPE

            #region TRIGGER_ACTION 
            $EnumBuilder = $ModuleBuilder.DefineEnum('TRIGGER_ACTION', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('ServiceStart', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('ServiceStop', [uint32] 0x00000002)
            [void]$EnumBuilder.CreateType()
            #endregion TRIGGER_ACTION

            #region SC_ACTION_TYPE 
            $EnumBuilder = $ModuleBuilder.DefineEnum('SC_ACTION_TYPE', 'Public', [uint32])
            [void]$EnumBuilder.DefineLiteral('None', [uint32] 0x00000000)
            [void]$EnumBuilder.DefineLiteral('Restart', [uint32] 0x00000001)
            [void]$EnumBuilder.DefineLiteral('Reboot', [uint32] 0x00000002)
            [void]$EnumBuilder.DefineLiteral('RunCommand', [uint32] 0x00000003)
                        $EnumBuilder.SetCustomAttribute(
                [FlagsAttribute].GetConstructor([Type]::EmptyTypes),
                @()
            )
            [void]$EnumBuilder.CreateType()
            #endregion SC_ACTION_TYPE

            #endregion Enums

            #region Struct

            #region SERVICE_STATUS_PROCESS
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_STATUS_PROCESS', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwServiceType', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwCurrentState', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwControlsAccepted', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwWin32ExitCode', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwServiceSpecificExitCode', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwCheckPoint', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwWaitHint', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwProcessId', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwServiceFlags', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_STATUS_PROCESS

            #region SERVICE_STATUS
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_STATUS', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwServiceType', [SERVICE_TYPE], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwCurrentState', [SERVICE_STATE], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwControlsAccepted', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwWin32ExitCode', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwServiceSpecificExitCode', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwCheckPoint', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwWaitHint', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_STATUS

            #region QUERY_SERVICE_CONFIG
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('QUERY_SERVICE_CONFIG', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwServiceType', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwStartType', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwErrorControl', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpBinaryPathName', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpLoadOrderGroup', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwTagId', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpDependencies', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpServiceStartName', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpDisplayName', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion QUERY_SERVICE_CONFIG

            If ([intptr]::Size -eq 8) {
                #region ENUM_SERVICE_STATUS_PROCESS
                $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
                $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('ENUM_SERVICE_STATUS_PROCESS', $Attributes, [System.ValueType], 8, 0x0)
                [void]$STRUCT_TypeBuilder.DefineField('lpServiceName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('lpDisplayName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('ServiceStatusProcess', [SERVICE_STATUS_PROCESS], @('Public'))
                [void]$STRUCT_TypeBuilder.CreateType()
                #endregion ENUM_SERVICE_STATUS_PROCESS
            } 
            Else {
                #region ENUM_SERVICE_STATUS_PROCESS
                $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
                $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('ENUM_SERVICE_STATUS_PROCESS', $Attributes, [System.ValueType], 4, 0x0)
                [void]$STRUCT_TypeBuilder.DefineField('lpServiceName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('lpDisplayName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('ServiceStatusProcess', [SERVICE_STATUS_PROCESS], @('Public'))
                [void]$STRUCT_TypeBuilder.CreateType()
                #endregion ENUM_SERVICE_STATUS_PROCESS            
            }

            If ([intptr]::Size -eq 8) {
                #region ENUM_SERVICE_STATUS
                $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
                $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('ENUM_SERVICE_STATUS', $Attributes, [System.ValueType], 8, 0x0)
                [void]$STRUCT_TypeBuilder.DefineField('lpServiceName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('lpDisplayName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('ServiceStatus', [SERVICE_STATUS], @('Public'))
                [void]$STRUCT_TypeBuilder.CreateType()
                #endregion ENUM_SERVICE_STATUS
            }
            Else {
                #region ENUM_SERVICE_STATUS
                $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
                $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('ENUM_SERVICE_STATUS', $Attributes, [System.ValueType], 4, 0x0)
                [void]$STRUCT_TypeBuilder.DefineField('lpServiceName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('lpDisplayName', [string], @('Public'))
                [void]$STRUCT_TypeBuilder.DefineField('ServiceStatus', [SERVICE_STATUS], @('Public'))
                [void]$STRUCT_TypeBuilder.CreateType()
                #endregion ENUM_SERVICE_STATUS
            } 

            #region TRIGGER
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('TRIGGER', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('TriggerType', [TRIGGER_TYPE], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('Action', [TRIGGER_ACTION], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('SubType', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion TRIGGER

            #region SERVICE_REQUIRED_PRIVILEGES_INFO
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_REQUIRED_PRIVILEGES_INFO', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('pmszRequiredPrivileges', [intptr], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_REQUIRED_PRIVILEGES_INFO        

            #region SC_ACTION
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SC_ACTION', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('type', [SC_ACTION_TYPE], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('delay', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SC_ACTION

            #region SERVICE_FAILURE_ACTIONS
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_FAILURE_ACTIONS', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwResetPeriod', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpRebootMsg', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpCommand', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('cActions', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('lpsaActions', [intptr], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_FAILURE_ACTIONS

            #region SERVICE_FAILURE_ACTIONS_FLAG
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_FAILURE_ACTIONS_FLAG', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('fFailureActionsOnNonCrashFailures', [bool], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_FAILURE_ACTIONS_FLAG

            #region FAILURE_ACTIONS
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('FAILURE_ACTIONS', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('ResetPeriod', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('RebootMessage', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('Command', [string], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('Actions', [SC_ACTION[]], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion FAILURE_ACTIONS

            #region SERVICE_PREFERRED_NODE_INFO
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_PREFERRED_NODE_INFO', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('usPreferredNode', [int16], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('fDelete', [bool], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_PREFERRED_NODE_INFO

            #region SERVICE_PRESHUTDOWN_INFO
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_PRESHUTDOWN_INFO', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwPreshutdownTimeout', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_PRESHUTDOWN_INFO

            #region SERVICE_SID_INFO
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_SID_INFO', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwServiceSidType', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_SID_INFO

            #region SERVICE_DELAYED_AUTO_START_INFO
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_DELAYED_AUTO_START_INFO', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('fDelayedAutostart', [bool], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_DELAYED_AUTO_START_INFO

            #region SERVICE_DESCRIPTION
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_DESCRIPTION', $Attributes, [System.ValueType], 8, 0x0)
            $ctor = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructor(@([System.Runtime.InteropServices.UnmanagedType]))
            $CustomAttribute = [System.Runtime.InteropServices.UnmanagedType]::LPStr
            $CustomAttributeBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder -ArgumentList $ctor, $CustomAttribute 
            $Field = $STRUCT_TypeBuilder.DefineField('lpDescription', [string], @('Public'))
            $Field.SetCustomAttribute($CustomAttributeBuilder)
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_DESCRIPTION

            #region SERVICE_TRIGGER_SPECIFIC_DATA_ITEM
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_TRIGGER_SPECIFIC_DATA_ITEM', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwDataType', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('cbData', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('pData', [intptr], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_TRIGGER_SPECIFIC_DATA_ITEM

            #region SERVICE_TRIGGER
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_TRIGGER', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('dwTriggerType', [TRIGGER_TYPE], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('dwAction', [TRIGGER_ACTION], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('pTriggerSubType', [IntPtr], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('cDataItems', [uint32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('pDataItems', [IntPtr], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_TRIGGER

            #region SERVICE_TRIGGER_INFO
            $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
            $STRUCT_TypeBuilder = $ModuleBuilder.DefineType('SERVICE_TRIGGER_INFO', $Attributes, [System.ValueType], 8, 0x0)
            [void]$STRUCT_TypeBuilder.DefineField('cTriggers', [int32], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('pTriggers', [Intptr], @('Public'))
            [void]$STRUCT_TypeBuilder.DefineField('pReserved', [intptr], @('Public'))
            [void]$STRUCT_TypeBuilder.CreateType()
            #endregion SERVICE_TRIGGER_INFO

            #endregion Struct

            $TypeBuilder = $ModuleBuilder.DefineType('Service.Trigger', 'Public, Class')

            #region Methods

            #region OpenSCManager Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'OpenSCManager', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [intptr], #Method Return Type
                [Type[]] @(
                    [string],
                    [string],  
                    [uint32]   
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
                'OpenSCManagerA', #CASE SENSITIVE!!
                $True,
                $True,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion OpenSCManager Method

            #region OpenService Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'OpenService', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [intptr], #Method Return Type
                [Type[]] @(
                    [intptr],
                    [string],  
                    [SERVICE_ACCESS]   
                ) #Method Parameters
            )

            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
                [Runtime.InteropServices.DllImportAttribute].GetField('ExactSpelling')
                [Runtime.InteropServices.DllImportAttribute].GetField('PreserveSig')
                [Runtime.InteropServices.DllImportAttribute].GetField('CharSet')
            )

            $FieldValueArray = [Object[]] @(
                'OpenService', #CASE SENSITIVE!!
                $True,
                $False,
                $True,
                [System.Runtime.InteropServices.CharSet]::Auto
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion OpenService Method

            #region QueryServiceConfig2 Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'QueryServiceConfig2', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
                [Type[]] @(
                    [intptr],
                    [uint32],  
                    [intptr] ,
                    [uint32],
                    [uint32].MakeByRefType()  
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
                'QueryServiceConfig2A', #CASE SENSITIVE!!
                $True,
                $False,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion QueryServiceConfig2 Method

            #region QueryServiceConfig Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'QueryServiceConfig', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
                [Type[]] @(
                    [intptr],
                    [intptr],  
                    [uint32] ,
                    [uint32].MakeByRefType()  
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
                'QueryServiceConfigA', #CASE SENSITIVE!!
                $True,
                $False,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion QueryServiceConfig Method

            #region CloseServiceHandle Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'CloseServiceHandle', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
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
                'CloseServiceHandle', #CASE SENSITIVE!!
                $True,
                $False,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion CloseServiceHandle Method

            #region EnumServicesStatusEx Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'EnumServicesStatusEx', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
                [Type[]] @(
                    [intptr],
                    [uint32],  
                    [uint32],
                    [uint32],
                    [intptr],
                    [uint32],
                    [uint32].MakeByRefType(),
                    [int].MakeByRefType(),
                    [uint32].MakeByRefType(),
                    [string]
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
                'EnumServicesStatusExA', #CASE SENSITIVE!!
                $True,
                $True,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion EnumServicesStatusEx Method

            #region QueryServiceStatusEx Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'QueryServiceStatusEx', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
                [Type[]] @(
                    [intptr],
                    [uint32],  
                    [intptr],
                    [uint32],
                    [uint32].MakeByRefType()
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
                'QueryServiceStatusEx', #CASE SENSITIVE!!
                $True,
                $True,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion QueryServiceStatusEx Method

            #region EnumDependentServices Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'EnumDependentServices', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [bool], #Method Return Type
                [Type[]] @(
                    [intptr],
                    [uint32],  
                    [intptr],
                    [uint32],
                    [uint32].MakeByRefType(),
                    [uint32].MakeByRefType()
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
                'EnumDependentServicesA', #CASE SENSITIVE!!
                $True,
                $True,
                $True
            )

            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )

            $PInvokeMethod.SetCustomAttribute($CustomAttribute)
            #endregion EnumDependentServices Method

            #endregion Methods

            [void]$TypeBuilder.CreateType()
        }
        #endregion Reflection

        #region Lookups
        $TRIGGER_SUBTYPE = @{
            NAMED_PIPE_EVENT_GUID = [guid]'1F81D131-3FAC-4537-9E0C-7E7B0C2F4B55'
            RPC_INTERFACE_EVENT_GUID = [guid]'BC90D167-9470-4139-A9BA-BE0BBBF5B74D'
            DOMAIN_JOIN_GUID = [guid]'1ce20aba-9851-4421-9430-1ddeb766e809'
            DOMAIN_LEAVE_GUID = [guid]'ddaf516e-58c2-4866-9574-c3b615d42ea1'
            FIREWALL_PORT_OPEN_GUID = [guid]'b7569e07-8421-4ee0-ad10-86915afdad09'
            FIREWALL_PORT_CLOSE_GUID = [guid]'a144ed38-8e12-4de4-9d96-e64740b1a524'
            MACHINE_POLICY_PRESENT_GUID = [guid]'659FCAE6-5BDB-4DA9-B1FF-CA2A178D46E0'
            NETWORK_MANAGER_FIRST_IP_ADDRESS_ARRIVAL_GUID = [guid]'4f27f2de-14e2-430b-a549-7cd48cbc8245'
            NETWORK_MANAGER_LAST_IP_ADDRESS_REMOVAL_GUID = [guid]'cc4ba62a-162e-4648-847a-b6bdf993e335'
            USER_POLICY_PRESENT_GUID = [guid]'54FB46C8-F089-464C-B1FD-59D1B62C3B50'
            ETW_PROVIDER_UUID = [guid]'d02a9c27-79b8-40d6-9b97-cf3f8b7b5d60'
            [guid]'1F81D131-3FAC-4537-9E0C-7E7B0C2F4B55' = 'NAMED_PIPE_EVENT'
            [guid]'BC90D167-9470-4139-A9BA-BE0BBBF5B74D' = 'RPC_INTERFACE_EVENT'
            [guid]'1ce20aba-9851-4421-9430-1ddeb766e809' = 'DOMAIN_JOIN'
            [guid]'ddaf516e-58c2-4866-9574-c3b615d42ea1' = 'DOMAIN_LEAVE'
            [guid]'b7569e07-8421-4ee0-ad10-86915afdad09' = 'FIREWALL_PORT_OPEN'
            [guid]'a144ed38-8e12-4de4-9d96-e64740b1a524' = 'FIREWALL_PORT_CLOSE'
            [guid]'659FCAE6-5BDB-4DA9-B1FF-CA2A178D46E0' = 'MACHINE_POLICY_PRESENT'
            [guid]'4f27f2de-14e2-430b-a549-7cd48cbc8245' = 'NETWORK_MANAGER_FIRST_IP_ADDRESS_ARRIVAL'
            [guid]'cc4ba62a-162e-4648-847a-b6bdf993e335' = 'NETWORK_MANAGER_LAST_IP_ADDRESS_REMOVAL'
            [guid]'54FB46C8-F089-464C-B1FD-59D1B62C3B50' = 'USER_POLICY_PRESENT'
            [guid]'d02a9c27-79b8-40d6-9b97-cf3f8b7b5d60' = 'ETW_PROVIDER'
        }
        #endregion Lookups
    }
    Process {
        If (-NOT $PSBoundParameters.ContainsKey('Computername')) {
            $Computername = $env:COMPUTERNAME            
        } 
        $Computername | ForEach {
            $Computer = $_
            #region Open SCManager
            Write-Verbose 'Opening Service Manager'
            $SCMHandle = [Service.Trigger]::OpenSCManager(
                $Computer, 
                [NullString]::Value, 
                ([SCM_ACCESS]::SC_MANAGER_CONNECT -BOR [SCM_ACCESS]::SC_MANAGER_ENUMERATE_SERVICE -BOR [SCM_ACCESS]::SC_MANAGER_QUERY_LOCK_STATUS)
            )
            $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
            If ($SCMHandle -eq [intptr]::Zero) {
                Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                Break    
            }
            Write-Debug "SCManager Handle: $SCMHandle"
            #endregion Open SCManager

            $List = New-Object System.Collections.ArrayList

            If (-NOT $PSBoundParameters.ContainsKey('Name')) {
                #region Enum Services
                Write-Verbose 'Get all services'
                $BytesNeeded = 0
                $ServicesReturned = 0
                $ResumeHandle = 0
                $Return = [Service.Trigger]::EnumServicesStatusEx(
                    $SCMHandle,
                    [SC_ENUM_TYPE]::SC_ENUM_PROCESS_INFO,
                    [SERVICE_TYPE]$ServiceType,
                    [SERVICE_STATES]::SERVICE_ALL,
                    [IntPtr]::Zero,
                    0, # Current Buffer
                    [ref]$BytesNeeded,
                    [ref]$ServicesReturned,
                    [ref]$ResumeHandle,
                    [NullString]::Value
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                Write-Debug "BytesNeeded: $BytesNeeded"
                If ($LastError.NativeErrorCode -eq 234) { #More data is available - Expected result
                    $Buffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)
                    $Return = [Service.Trigger]::EnumServicesStatusEx(
                        $SCMHandle,
                        [SC_ENUM_TYPE]::SC_ENUM_PROCESS_INFO,
                        [SERVICE_TYPE]$ServiceType,
                        [SERVICE_STATES]::SERVICE_ALL,
                        $Buffer,
                        $BytesNeeded, # Current Buffer
                        [ref]$BytesNeeded,
                        [ref]$ServicesReturned,
                        [ref]$ResumeHandle,
                        [NullString]::Value
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error() 
                    Write-Debug "ServicesReturned: $ServicesReturned"
                    If ($Return) {                    
                        $tempPointer = $Buffer
                        For ($i=0;$i -lt $ServicesReturned;$i++) {
                            #Write-Progress -Status 'Gathering Services' -PercentComplete (($i/$ServicesReturned)*100) -Activity "Pointer: $tempPointer"
                            If ([intptr]::Size -eq 8) {
                                # 64 bit
                                $Object = ([System.Runtime.InteropServices.Marshal]::PtrToStructure($tempPointer,[type][ENUM_SERVICE_STATUS_PROCESS]))
                                [intptr]$tempPointer = $tempPointer.ToInt64() + [System.Runtime.InteropServices.Marshal]::SizeOf([type][ENUM_SERVICE_STATUS_PROCESS])
                            } 
                            Else {
                                #32 bit
                                $Object = ([System.Runtime.InteropServices.Marshal]::PtrToStructure($tempPointer,[type][ENUM_SERVICE_STATUS_PROCESS]))
                                [intptr]$tempPointer = $tempPointer.ToInt32() + [System.Runtime.InteropServices.Marshal]::SizeOf([type][ENUM_SERVICE_STATUS_PROCESS])
                            }
                            Try {
                                $Controls = [SERVICE_CONTROL_CODE]$Object.ServiceStatusProcess.dwControlsAccepted
                            } 
                            Catch {
                                $Controls = $Object.ServiceStatusProcess.dwControlsAccepted
                            }
                            Try {
                                $Service_Type = [SERVICE_TYPE]$Object.ServiceStatusProcess.dwServiceType
                            } 
                            Catch {
                                $Service_Type = $Object.ServiceStatusProcess.dwServiceType
                            }
                            [void]$List.Add([pscustomobject]@{
                                Name = $Object.lpServiceName
                                Type = $Service_Type
                                State = [SERVICE_STATE]$Object.ServiceStatusProcess.dwCurrentState
                                Controls = $Controls
                                Win32ExitCode = $Object.ServiceStatusProcess.dwWin32ExitCode
                                ServiceExitCode = $Object.ServiceStatusProcess.dwServiceSpecificExitCode
                                CheckPoint = $Object.ServiceStatusProcess.dwCheckPoint
                                WaitHint = $Object.ServiceStatusProcess.dwWaitHint
                                ProcessID = $Object.ServiceStatusProcess.dwProcessId
                                ServiceFlags = [SERVICE_FLAGS]$Object.ServiceStatusProcess.dwServiceFlags
                            })
                        }
                    }         
                }
                #endregion Enum Services
            } 
            Else {
                $Name | ForEach {
                    $_Name = $_
                    Write-Verbose "Query single service: $_Name"

                    #region Open Service
                    $ServiceHandle = [Service.Trigger]::OpenService(
                        $SCMHandle,
                        $_Name,
                        [SERVICE_ACCESS]::SERVICE_QUERY_STATUS
                    )
                    #endregion Open Service

                    Write-Debug "Service Handle: $ServiceHandle"

                    #region Query Service
                    $BytesNeeded = 0
                    $Return = [Service.Trigger]::QueryServiceStatusEx(
                        $ServiceHandle,
                        0,
                        [intptr]::Zero,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    Write-Debug "Bytes Needed: $BytesNeeded"
                    If ($LastError.NativeErrorCode -eq 122) { #The data area passed to a system call is too small - This is expected!
                        Write-Verbose "Querying service"
                        $Buffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)
                        $Return = [Service.Trigger]::QueryServiceStatusEx(
                            $ServiceHandle,
                            0,
                            $Buffer,
                            $BytesNeeded,
                            [ref]$BytesNeeded
                        )
                        $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    } 
                    #endregion Query Service
                    If ($Return) {
                        $Object = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Buffer, [type][SERVICE_STATUS_PROCESS])
                        Try {
                            $Controls = [SERVICE_CONTROL_CODE]$Object.dwControlsAccepted
                        } 
                        Catch {
                            $Controls = $Object.dwControlsAccepted
                        }
                        Try {
                            $Service_Type = [SERVICE_TYPE]$Object.dwServiceType
                        } 
                        Catch {
                            $Service_Type = $Object.dwServiceType
                        }
                        [void]$List.Add([pscustomobject]@{
                            Name = $_Name
                            Type = $Service_Type
                            State = [SERVICE_STATE]$Object.dwCurrentState
                            Controls = $Controls
                            Win32ExitCode = $Object.dwWin32ExitCode
                            ServiceExitCode = $Object.dwServiceSpecificExitCode
                            CheckPoint = $Object.dwCheckPoint
                            WaitHint = $Object.dwWaitHint
                            ProcessID = $Object.dwProcessId
                            ServiceFlags = [SERVICE_FLAGS]$Object.dwServiceFlags
                        })
                    }
                    [void][Service.Trigger]::CloseServiceHandle($ServiceHandle)
                }
            }
            Write-Verbose "Beginning iteration through services for more data"
            ForEach ($Service in $List) {
                #region Open Service
                $ServiceHandle = [Service.Trigger]::OpenService(
                    $SCMHandle,
                    $Service.Name,
                    [SERVICE_ACCESS]::SERVICE_QUERY_CONFIG
                )
                Write-Debug "ServiceHandle: $ServiceHandle"
                #endregion Open Service

                #region Query Service Required Privileges
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $ServicePrivileges = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_REQUIRED_PRIVILEGES_INFO])
                    $P_Pointer = $ServicePrivileges.pmszRequiredPrivileges
                    $Remaining = $BytesNeeded
                    $Privileges = New-Object System.Collections.ArrayList
                    While ($Remaining -gt 0) {
                        $string = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($P_Pointer)
                        If ($string.Length -gt 1) {
                            [void]$Privileges.Add($String)
                        } 
                        Else {
                            BREAK
                        } 
                        [intptr]$P_Pointer = $P_Pointer.ToInt64() + ($string.Length + 1) * ([System.Runtime.InteropServices.Marshal]::SizeOf([type][char]))
                        $Remaining = $Remaining = $string.Length
                    }

                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Required Privileges

                #region Query Service Failure Actions
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_FAILURE_ACTIONS,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_FAILURE_ACTIONS,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }

                    #Build Struct from Pointer
                    $FailureActions = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_FAILURE_ACTIONS])
                    $TPointer = $FailureActions.lpsaActions
                    $Actions = For ($i=0; $i -lt $FailureActions.cActions; $i++) {    
                        [System.Runtime.InteropServices.Marshal]::PtrToStructure($TPointer,[type][SC_ACTION])
                        [IntPtr]$TPointer = $TPointer.ToInt64() + [System.Runtime.InteropServices.Marshal]::SizeOf([type][SC_ACTION])
                    }        
                    $_FailureAction = New-Object FAILURE_ACTIONS 
                    $_FailureAction.ResetPeriod = $FailureActions.dwResetPeriod
                    $_FailureAction.RebootMessage = $FailureActions.lpRebootMsg
                    $_FailureAction.Command = $FailureActions.lpCommand
                    $_FailureAction.Actions = [SC_ACTION[]]$Actions
                    
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Failure Actions

                #region Query Service Failure Actions Flag
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_FAILURE_ACTIONS_FLAG,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_FAILURE_ACTIONS_FLAG,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $FailureActionsFlag = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_FAILURE_ACTIONS_FLAG])
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Failure Actions Flag

                #region Query Service Preferred Node
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_PREFERRED_NODE,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_PREFERRED_NODE,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $PreferredNode = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_PREFERRED_NODE_INFO])
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Preferred Node

                #region Query Service Pre-Shutdown Timeout
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_PRESHUTDOWN_INFO,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_PRESHUTDOWN_INFO,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $ShutdownTimeout = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_PRESHUTDOWN_INFO])
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Pre-Shutdown Timeout

                #region Query Service SID Type
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_SERVICE_SID_INFO,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_SERVICE_SID_INFO,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $ServiceSID = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_SID_INFO])
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service SID Type

                #region Query Service Description
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_DESCRIPTION,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_DESCRIPTION,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $Description = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_DESCRIPTION])
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Description

                #region Query Service Configuration
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig(
                    $ServiceHandle,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig(
                        $ServiceHandle,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $ServiceConfiguration = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][QUERY_SERVICE_CONFIG])
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Configuration

                #region Query Service Delayed AutoStart
                #Determine bytes needed
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_DELAYED_AUTO_START_INFO,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_DELAYED_AUTO_START_INFO,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $AutoStart = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_DELAYED_AUTO_START_INFO])
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($Pointer)  
                }
                #endregion Query Service Delayed AutoStart

                #region Query Service Triggers
                [uint32]$BytesNeeded = $Null
                $Return = [Service.Trigger]::QueryServiceConfig2(
                    $ServiceHandle,
                    [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_TRIGGER_INFO,
                    [intptr]::Zero,
                    0,
                    [ref]$BytesNeeded
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                If ($LastError.NativeErrorCode -eq 122) { 
                    #Buffer too small which is expected so we rerun this again with the expected buffer
                    $Pointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)    
                    $Return = [Service.Trigger]::QueryServiceConfig2(
                        $ServiceHandle,
                        [SERVICE_INFO_LEVEL]::SERVICE_CONFIG_TRIGGER_INFO,
                        $Pointer,
                        $BytesNeeded,
                        [ref]$BytesNeeded
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    If (-NOT $Return) {
                        Write-Warning ("{0} ({1})" -f $LastError.Message,$LastError.NativeErrorCode)
                        Break    
                    }
                    #Build Struct from Pointer
                    $TriggerInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($Pointer,[type][SERVICE_TRIGGER_INFO])
                    $TPointer = $TriggerInfo.pTriggers
                    $Triggers = For ($i=0; $i -lt $TriggerInfo.cTriggers; $i++) {    
                        $ServiceTrigger = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TPointer,[type][SERVICE_TRIGGER])
                        [IntPtr]$TPointer = $TPointer.ToInt64() + [System.Runtime.InteropServices.Marshal]::SizeOf([type][SERVICE_TRIGGER])
                        $GUID = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ServiceTrigger.pTriggerSubType,[type][guid])
                        $Trigger = New-Object TRIGGER
                        $Trigger.TriggerType = $ServiceTrigger.dwTriggerType
                        $Trigger.Action = $ServiceTrigger.dwAction
                        $Trigger.SubType = $TRIGGER_SUBTYPE[$GUID]     
                        $Trigger
                    }
                }
                #endregion Query Service Triggers

                [void][Service.Trigger]::CloseServiceHandle($ServiceHandle)

                #region Open Service
                $ServiceHandle = [Service.Trigger]::OpenService(
                    $SCMHandle,
                    $Service.Name,
                    [SERVICE_ACCESS]::SERVICE_ENUMERATE_DEPENDENTS
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                # TODO - Determine why certain services will not let you open handle with this access type without being admin; ie: RpcEptMapper
                Write-Debug "ServiceHandle: $ServiceHandle"
                #endregion Open Service

                #region Enum Dependant Services
                $D_Services = New-Object System.Collections.ArrayList
                Write-Verbose 'Get all dependant services'
                $BytesNeeded = 0
                $ServicesReturned = 0
                $Return = [Service.Trigger]::EnumDependentServices(
                    $ServiceHandle,
                    [SERVICE_STATES]::SERVICE_ALL,
                    [IntPtr]::Zero,
                    0, # Current Buffer
                    [ref]$BytesNeeded,
                    [ref]$ServicesReturned
                )
                $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
                Write-Debug "BytesNeeded<Dependant Services>: $BytesNeeded"
                Write-Debug "<Dependant Services>: $($LastError|select *|out-string)"
                If ($LastError.NativeErrorCode -eq 234) {
                    $Buffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BytesNeeded)
                    $Return = [Service.Trigger]::EnumDependentServices(
                        $ServiceHandle,
                        [SERVICE_STATES]::SERVICE_ALL,
                        $Buffer,
                        $BytesNeeded, # Current Buffer
                        [ref]$BytesNeeded,
                        [ref]$ServicesReturned
                    )
                    $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error() 
                    Write-Debug "ServicesReturned: $ServicesReturned"
                    If ($Return) {                    
                        $tempPointer = $Buffer
                        For ($i=0;$i -lt $ServicesReturned;$i++) {
                            If ([intptr]::Size -eq 8) {
                                # 64 bit
                                $Object = ([System.Runtime.InteropServices.Marshal]::PtrToStructure($tempPointer,[type][ENUM_SERVICE_STATUS]))
                                [intptr]$tempPointer = $tempPointer.ToInt64() + [System.Runtime.InteropServices.Marshal]::SizeOf([type][ENUM_SERVICE_STATUS])
                                [void]$D_Services.Add($Object)
                            } 
                            Else {
                                #32 bit
                                $Object = ([System.Runtime.InteropServices.Marshal]::PtrToStructure($tempPointer,[type][ENUM_SERVICE_STATUS]))
                                [intptr]$tempPointer = $tempPointer.ToInt32() + [System.Runtime.InteropServices.Marshal]::SizeOf([type][ENUM_SERVICE_STATUS])
                                [void]$D_Services.Add($Object)
                            }
                        }
                    }         
                }
                #endregion Enum Dependant Services

                #region Display Object and Perform Cleanup
                Try {
                    $ServiceSIDType = [SERVICE_SID_TYPE]$ServiceSID.dwServiceSidType
                } 
                Catch {
                    $ServiceSIDType = $Null
                }
                Try {
                    $ServiceStartType = [SERVICE_START_TYPE]$ServiceConfiguration.dwStartType
                } 
                Catch {
                    $ServiceStartType = $Null
                }
                Try {
                    $ErrorControl = [ERROR_CONTROL]$ServiceConfiguration.dwErrorControl
                } 
                Catch {
                    $ErrorControl = $Null
                }
                $Object = [pscustomobject]@{
                    Name = $Service.Name
                    DisplayName = $ServiceConfiguration.lpDisplayName
                    Description = $Description.lpDescription
                    Triggers = $Triggers
                    IsDelayedAutoStart = $AutoStart.fDelayedAutostart
                    SIDType = $ServiceSIDType
                    Privileges = $Privileges
                    ShutdownTimeout = $ShutdownTimeout.dwPreshutdownTimeout
                    PreferredNode = $PreferredNode
                    FailureActionsFlag = $FailureActionsFlag.fFailureActionsOnNonCrashFailures
                    FailureActions = $_FailureAction
                    Type = $Service.Type
                    State = $Service.State
                    Controls = $Service.Controls
                    Win32ExitCode = $Service.Win32ExitCode
                    ServiceExitCode = $Service.ServiceExitCode
                    CheckPoint = $Service.CheckPoint
                    WaitHint = $Service.WaitHint
                    ProcessID = $Service.ProcessID
                    ServiceFlags = $Service.ServiceFlags
                    StartMode = $ServiceStartType
                    ErrorControl = $ErrorControl
                    FilePath = $ServiceConfiguration.lpBinaryPathName
                    LoadOrderGroup = $ServiceConfiguration.lpLoadOrderGroup
                    TagID = $ServiceConfiguration.dwTagId
                    Dependancies = $ServiceConfiguration.lpDependencies
                    StartName = $ServiceConfiguration.lpServiceStartName
                    DependantServices = $D_Services
                    Computername = $Computer
                }
                $Object.pstypenames.insert(0,'System.Service')
                $Object
                [void][Service.Trigger]::CloseServiceHandle($ServiceHandle)
                #endregion Display Object and Perform Cleanup
            }
        }
    }
}

#region Type Display Formatting
Update-TypeData -TypeName System.Service -Force -DefaultDisplayPropertySet State, Name, DisplayName, StartMode
#endregion Type Display Formatting

#region Custom Argument Completors
#region Service Name
$completion_ServiceName = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    Get-Service2 -ServiceType All | Sort-Object -Property Name | Where-Object { $_.Name -like "$wordToComplete*" } |ForEach-Object {
        New-Object System.Management.Automation.CompletionResult $_.Name, $_.Name, 'ParameterValue', ('{0} ({1})' -f $_.Description, $_.ID) 
    }
}
#endregion Service Name
If (-not $global:options) { 
    $global:options = @{
        CustomArgumentCompleters = @{}
        NativeArgumentCompleters = @{}
    }
}
$global:options['CustomArgumentCompleters']['Get-Service2:Name'] = $completion_ServiceName

$function:tabexpansion2 = $function:tabexpansion2 -replace 'End\r\n{','End { if ($null -ne $options) { $options += $global:options} else {$options = $global:options}'
#endregion Custom Argument Completors

#region Alias
Set-Alias -Name gsv2 -Value Get-Service2
#endregion Alias