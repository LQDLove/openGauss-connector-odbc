<#
.SYNOPSIS
    Run regressin test on Windows.
.DESCRIPTION
    Build test programs and run them.
.PARAMETER Target
    Specify the target of MSBuild. "Build&Go"(default), "Build" or
    "Clean" is available.
.PARAMETER TestList
    Specify the list of test cases. If this parameter isn't specified(default),
    all test cases are executed.
.PARAMETER Ansi
    Specify this switch in case of testing Ansi drivers.
.PARAMETER DeclareFetch
    Specify Use Declare/Fetch mode. "On"(default), "off" or "both" is available.
.PARAMETER VCVersion
    Used Visual Studio version is determined automatically unless this
    option is specified.
.PARAMETER Platform
    Specify platforms to test. "x64"(default), "Win32" or "both" is available.
.PARAMETER Toolset
    MSBuild PlatformToolset is determined automatically unless this
    option is specified. Currently "v100", "Windows7.1SDK", "v110",
    "v110_xp", "v120", "v120_xp", "v140" or "v140_xp" is available.
.PARAMETER MSToolsVersion
    MSBuild ToolsVersion is detemrined automatically unless this
    option is specified.  Currently "4.0", "12.0", "14.0" or "15.0" is
    available.
.PARAMETER Configuration
    Specify "Release"(default) or "Debug".
.PARAMETER BuildConfigPath
    Specify the configuration xml file name if you want to use
    the configuration file other than standard one.
    The relative path is relative to the current directory.
.EXAMPLE
    > .\regress
	Build with default or automatically selected parameters
	and run tests.
.EXAMPLE
    > .\regress Clean
	Clean all generated files.
.EXAMPLE
    > .\regress -TestList connect, deprected
	Build and run connect-test and deprecated-test.
.EXAMPLE
    > .\regress -Ansi
	Build and run with ANSI version of drivers.
.EXAMPLE
    > .\regress -V(CVersion) 14.0
	Build using Visual Studio 14.0 environment and run tests.
.EXAMPLE
    > .\regress -P(latform) x64
	Build 64bit test programs and run them.
.NOTES
    Author: Hiroshi Inoue
    Date:   August 2, 2016
#>

#
#	build 32bit & 64bit dlls for VC10 or later
#
Param(
[ValidateSet("Build&Go", "Build", "Clean")]
[string]$Target="Build&Go",
[string[]]$TestList,
[switch]$Ansi,
[string]$VCVersion,
[ValidateSet("Win32", "x64", "both")]
[string]$Platform="x64",
[string]$Toolset,
[ValidateSet("", "4.0", "12.0", "14.0", "15.0")]
[string]$MSToolsVersion,
[ValidateSet("Debug", "Release")]
[String]$Configuration="Release",
[string]$BuildConfigPath,
[ValidateSet("off", "on", "both")]
[string]$DeclareFetch="on",
[string]$SpecificDsn
)


function testlist_make($testsf)
{
	$testbins=@()
	$testnames=@()
	$dirnames=@()
	$testexes=@()
	$f = (Get-Content -Path $testsf) -as [string[]]
	$nstart=$false
	foreach ($l in $f) {
		if ($l[0] -eq "#") {
			continue
		}
		$sary=-split $l
		if ($sary[0] -eq "#") {
			continue
		}
		if ($sary[0] -eq "TESTBINS") {
			$nstart=$true
			$sary[0]=$null
			if ($sary[1] -eq "=") {
				$sary[1]=$null
			}
		}
		if ($nstart) {
			if ($sary[$sary.length - 1] -eq "\") {
				$sary[$sary.length - 1] = $null
			} else {
				$nstart=$false
			}
			$testbins+=$sary
			if (-not $nstart) {
				break
			}
		}
	}
	for ($i=0; $i -lt $testbins.length; $i++) {
		Write-Debug "$i : $testbins[$i]"
	}

	foreach ($testbin in $testbins) {
		if ("$testbin" -eq "") {
			continue
		}
		$sary=$testbin.split("/")
		$testname=$sary[$sary.length -1]
		$dirname=""
		for ($i=0;$i -lt $sary.length - 1;$i++) {
			$dirname+=($sary[$i]+"`\")
		}
		Write-Debug "testbin=$testbin => testname=$testname dirname=$dirname"
		$dirnames += $dirname
		$testexes+=($dirname+$testname+".exe")
		$testnames+=$testname.Replace("-test","")
	}

	return $testexes, $testnames, $dirnames
}

function vcxfile_make($testnames, $dirnames, $vcxfile)
{
# here-string
	@'
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <!--
	 This file is automatically generated by regress.ps1
	 and used by MSBuild.
    -->
    <PropertyGroup>
	<Configuration>Release</Configuration>
	<srcPath>..\test\src\</srcPath>
    </PropertyGroup>
    <Target Name="Build">
        <MSBuild Projects="regress_one.vcxproj"
	  Targets="ClCompile"
	  Properties="TestName=common;Configuration=$(Configuration);srcPath=$(srcPath)"/>
'@ > $vcxfile

	for ($i=0; $i -lt $testnames.length; $i++) {
		$testname=$testnames[$i]
		$dirname=$dirnames[$i]
		$testname+="-test"
# here-string
		@"
        <MSBuild Projects="regress_one.vcxproj"
	  Targets="Build"
	  Properties="TestName=$testname;Configuration=`$(Configuration);srcPath=`$(srcPath);SubDir=$dirname"/>
"@ >> $vcxfile
	}
# here-string
	@'
        <MSBuild Projects="regress_one.vcxproj"
	  Targets="Build"
	  Properties="TestName=runsuite;Configuration=$(Configuration);srcPath=$(srcPath)..\"/>
        <MSBuild Projects="regress_one.vcxproj"
	  Targets="Build"
	  Properties="TestName=RegisterRegdsn;Configuration=$(Configuration);srcPath=$(srcPath)..\"/>
        <!-- MSBuild Projects="regress_one.vcxproj"
	  Targets="Build"
	  Properties="TestName=ConfigDsn;Configuration=$(Configuration);srcPath=$(srcPath)..\"/-->
        <MSBuild Projects="regress_one.vcxproj"
	  Targets="Build"
	  Properties="TestName=reset-db;Configuration=$(Configuration);srcPath=$(srcPath)..\"/>
    </Target>
    <Target Name="Clean">
        <MSBuild Projects="regress_one.vcxproj"
	  Targets="Clean"
	  Properties="Configuration=$(Configuration);srcPath=$(srcPath)"/>
    </Target>
</Project>
'@ >> $vcxfile

}

function RunTest($scriptPath, $Platform, $testexes)
{
	# Run regression tests
	if ($Platform -eq "x64") {
		$targetdir="test_x64"
	} else {
		$targetdir="test_x86"
	}
	$revsdir="..\"
	$origdir="${revsdir}..\test"

	pushd $scriptPath\$targetdir

	try {
		$regdiff="regression.diffs"
		$RESDIR="results"
		if (Test-Path $regdiff) {
			Remove-Item $regdiff
		}
		New-Item $RESDIR -ItemType Directory -Force > $null
		Get-Content "${origdir}\sampletables.sql" | .\reset-db
		if ($LASTEXITCODE -ne 0) {
			throw "`treset_db error"
		}
		$cnstr = @()
		switch ($DeclareFetch) {
			"off"	{ $cnstr += "UseDeclareFetch=0" }
			"on"	{ $cnstr += "UseDeclareFetch=1" }
			"both"	{ $cnstr += "UseDeclareFetch=0"
				  $cnstr += "UseDeclareFetch=1" }
		}
		if ($cnstr.length -eq 0) {
			$cnstr += $null;
		}
		for ($i = 0; $i -lt $cnstr.length; $i++)
		{
			$env:COMMON_CONNECTION_STRING_FOR_REGRESSION_TEST = $cnstr[$i]
			if ("$SpecificDsn" -ne "") {
				$env:COMMON_CONNECTION_STRING_FOR_REGRESSION_TEST += ";Database=contrib_regression;ConnSettings={set lc_messages='C'}"
			}
			write-host "`n`tSetting by env variable:$env:COMMON_CONNECTION_STRING_FOR_REGRESSION_TEST"
			.\runsuite $testexes --inputdir=$origdir
		}
	} catch [Exception] {
		throw $error[0]
	} finally {
		popd
		$env:COMMON_CONNECTION_STRING_FOR_REGRESSION_TEST = $null
	}
}

function SpecialDsn($testdsn, $testdriver)
{
	function input-dsninfo($server="localhost", $uid="postgres", $passwd="postgres", $port="5432", $database="contrib_regression")
	{
		$in = read-host "Server [$server]"
		if ("$in" -ne "") {
			$server = $in
		}
		$in = read-host "Port [$port]"
		if ("$in" -ne "") {
			$port = $in
		}
		$in = read-host "Username [$uid]"
		if ("$in" -ne "") {
			$uid = $in
		}
		$in = read-host -assecurestring "Password [$passwd]"
		if ("$in" -ne "") {
			$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($in)
			$passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
		}
		return "SERVER=${server}|DATABASE=${database}|PORT=${port}|UID=${uid}|PWD=${passwd}"
	}

	$regProgram = "./RegisterRegdsn.exe"
	& $regProgram "existCheck" $testdsn
	if ($LastExitCode -eq -1) {
		Write-Host "`tAdding System DSN=$testdsn Driver=$testdriver"
		$prop = input-dsninfo
		$prop += "|Debug=0|Commlog=0|ConnSettings=set+lc_messages='C'"
		$proc = Start-Process $regProgram -Verb runas -Wait -PassThru -ArgumentList "register_dsn $testdriver $testdsn $prop `"$dlldir`" Driver=${dllname}|Setup=${setup}"
		if ($proc.ExitCode -ne 0) {
			throw "`tAddDsn $testdsn error"
		}
	}
	elseif ($LastExitCode -ne 0) {
		throw "$regProgram error"
	}
}

$scriptPath = (Split-Path $MyInvocation.MyCommand.Path)
$usingExe=$true
$testsf="$scriptPath\..\test\tests"
Write-Debug testsf=$testsf
$vcxfile="$scriptPath\generated_regress.vcxproj"

$arrays=testlist_make $testsf
if ($null -eq $TestList) {
	$TESTEXES=$arrays[0]
	$TESTNAMES=$arrays[1]
	$DIRNAMES=$arrays[2]
} else {
	$err=$false
	$TESTNAMES=$TestList
	$TESTEXES=@()
	$DIRNAMES=@()
	foreach ($l in $TestList) {
		for ($i=0;$i -lt $arrays[1].length;$i++) {
			if ($l -eq $arrays[1][$i]) {
				$TESTEXES+=$arrays[0][$i]
				$DIRNAMES+=$arrays[2][$i]
				break
			}
		}
<#		if ($i -ge $arrays[1].length) {
			Write-Host "!! test case $l doesn't exist"
			$err=$true
		} #>
	}
	if ($err) {
		return
	}
}
vcxfile_make $TESTNAMES $DIRNAMES $vcxfile

Import-Module "$scriptPath\Psqlodbc-config.psm1"
$configInfo = LoadConfiguration $BuildConfigPath $scriptPath
Import-Module ${scriptPath}\MSProgram-Get.psm1
$msbuildexe=Find-MSBuild ([ref]$VCVersion) ([ref]$MSToolsVersion) ([ref]$Toolset) $configInfo
write-host "vcversion=$VCVersion toolset=$Toolset"
Remove-Module MSProgram-Get
Remove-Module Psqlodbc-config

if ($Platform -ieq "both") {
	$pary = @("Win32", "x64")
} else {
	$pary = @($Platform)
}

$vcx_target=$target
if ($target -ieq "Build&Go") {
	$vcx_target="Build"
}
if ($Ansi) {
	write-host ** testing Ansi driver **
	$testdriver="postgres_deva"
	$testdsn="psqlodbc_test_dsn_ansi"
	$ansi_dir_part="ANSI"
	$dllname="psqlsetupa.dll"
	$setup="psqlsetupa.dll"
} else {
	write-host ** testing unicode driver **
	$testdriver="postgres_devw"
	$testdsn="psqlodbc_test_dsn"
	$ansi_dir_part="Unicode"
	$dllname="psqlsetup.dll"
	$setup="psqlsetup.dll"
}
if ("$SpecificDsn" -ne "") {
	Write-Host "`tSpecific DSN=$SpecificDsn"
	$testdsn=$SpecificDsn
}
foreach ($pl in $pary) {
	cd $scriptPath
	& ${msbuildexe} ${vcxfile} /tv:$MSToolsVersion "/p:Platform=$pl;Configuration=$Configuration;PlatformToolset=${Toolset}" /t:$vcx_target /p:VisualStudioVersion=${VCVersion} /Verbosity:minimal
	if ($LASTEXITCODE -ne 0) {
		throw "`nCompile error"
	}

	if (($target -ieq "Clean") -or ($target -ieq "Build")) {
		continue
	}

	switch ($pl) {
	 "Win32" {
			$targetdir="test_x86"
			$bit="32-bit"
			$dlldir="$scriptPath\..\x86_${ansi_dir_part}_Release"
		}
	 default {
			$targetdir="test_x64"
			$bit="64-bit"
			$dlldir="$scriptPath\..\x64_${ansi_dir_part}_Release"
		}
	}
	pushd $scriptPath\$targetdir

	$env:PSQLODBC_TEST_DSN = $testdsn
	try {
		SpecialDsn $testdsn $testdriver
		RunTest $scriptPath $pl $TESTEXES
	} catch [Exception] {
		throw $error[0]
	} finally {
		popd
		$env:PSQLODBC_TEST_DSN = $null
	}
}
