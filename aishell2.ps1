[CmdletBinding()]
param(
    [string[]]$f,
    [string]$d,
    [switch]$full,
    [string[]]$e,
    [switch]$h,
    [int]$p,
    [int]$b
)

# Función para mostrar ayuda
function Show-Help {
    Write-Host @"
Uso de aishell2:

  -f archivo1 archivo2   Incluye uno o más archivos específicos en el contexto.
  -d directorio          Incluye archivos especiales (.json, .yml, Dockerfile, etc.) dentro del directorio indicado.
  -full                  Leer archivos completos sin límite de líneas o peso.
  -e bN,pN               Incluir errores recientes. Usa bN para Bash y pN para PowerShell (ej. -e b5,p3).
  -p N                   Incluir los últimos N comandos de PowerShell.
  -b N                   Incluir los últimos N comandos de Bash/WSL.
  -h                     Mostrar esta ayuda y salir.

Notas:
  - Si no usas -p ni -b, no se incluirá historial de comandos.
  - El contenido de archivos grandes puede truncarse a 500 líneas o 32KB si no se usa -full.
  - El directorio actual se envía como parte del contexto para ayudar a la IA.
"@ -ForegroundColor Cyan
}

# Función para obtener API Key
function Get-GroqApiKey {
    $KeyPath = "$env:USERPROFILE\.groq_api_key"
    if (Test-Path $KeyPath) {
        return (Get-Content $KeyPath | ConvertTo-SecureString | ConvertFrom-SecureString -AsPlainText)
    } else {
        throw "No se encontró el archivo de la API Key. Por favor guárdalo primero."
    }
}

# Función para leer archivos con límite o completo
function Get-LimitedFileContent {
    param (
        [string]$FilePath,
        [switch]$FullMode
    )

    $maxLines = 500
    $maxBytes = 32KB

    if (Test-Path $FilePath) {
        if ($FullMode) {
            return (Get-Content -Path $FilePath -Raw)
        }

        $lines = Get-Content -Path $FilePath -TotalCount $maxLines
        $text = ($lines -join "`n")

        if ([Text.Encoding]::UTF8.GetByteCount($text) -gt $maxBytes) {
            $truncatedText = [Text.Encoding]::UTF8.GetString(
                [Text.Encoding]::UTF8.GetBytes($text)[0..($maxBytes-1)]
            )
            return "$truncatedText`n[Contenido truncado: superó 32KB]"
        }
        if ($lines.Count -eq $maxLines) {
            return "$text`n[Contenido truncado: superó 500 líneas]"
        }
        return $text
    } else {
        return "[Archivo no encontrado]"
    }
}

# Función para enviar pregunta a Groq
function Ask-Groq {
    param(
        [string]$Prompt,
        [string]$Groq_API_Key
    )

    $uri = "https://api.groq.com/openai/v1/chat/completions"
    $headers = @{
        "Authorization" = "Bearer $Groq_API_Key"
        "Content-Type"  = "application/json"
    }
    $body = @{
        "model" = "llama3-70b-8192"
        "messages" = @(
            @{
                "role"    = "system"
                "content" = @"
Eres un asistente de terminal llamado 'aishell2'. No eres un comando del sistema operativo ni ejecutas acciones directamente. 
Tu única función es analizar historial, archivos proporcionados, errores detectados y contexto adicional para ofrecer soluciones técnicas claras y específicas.
Cuando propongas comandos o instrucciones para Bash/WSL, precede cada línea de instrucción con "Bash: $> ".
Cuando propongas comandos o instrucciones para PowerShell, precede cada línea de instrucción con "Powershell: $> ".
El resto de tu respuesta debe ser explicaciones normales en texto plano, en Español.
"@
            },
            @{
                "role"    = "user"
                "content" = $Prompt
            }
        )
        "temperature" = 0.2
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
        return $response.choices[0].message.content
    } catch {
        Write-Host "Error al consultar la IA: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# --- MAIN ---

if ($h) {
    Show-Help
    exit
}

try {
    $Groq_API_Key = Get-GroqApiKey
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
}

# Historiales
$combinedHistory = ""

if ($p) {
    function Get-RecentPSCommands {
        param($count)
        (Get-History | Select-Object -Last $count | ForEach-Object { $_.CommandLine }) -join "`n"
    }
    $psHistory = Get-RecentPSCommands -count $p
    $combinedHistory += "=== Historial de PowerShell (últimos $p) ===`n$psHistory`n"
}

if ($b) {
    function Get-RecentBashCommands {
        param($count)
        try {
            wsl bash -c "history -a" | Out-Null
            $bashHistoryRaw = wsl cat ~/.bash_history
            $bashHistory = $bashHistoryRaw -split "`n"
            return ($bashHistory | Select-Object -Last $count) -join "`n"
        } catch {
            return "[No se pudo leer el historial de Bash]"
        }
    }
    $bashHistory = Get-RecentBashCommands -count $b
    $combinedHistory += "`n=== Historial de Bash (últimos $b) ===`n$bashHistory"
}

if (-not $p -and -not $b) {
    $combinedHistory = "=== No se especificaron flags -p ni -b: no se ha incluido historial ==="
}

# Errores
$errorContent = ""

$includePSErrors = $false
$includeBashErrors = $false
$psErrorCount = 0
$bashErrorCount = 0

# Parsear los valores de -e
if ($e) {
    foreach ($item in $e) {
        $splitItems = $item -split ','
        foreach ($token in $splitItems) {
            if ($token -match '^p(\d+)$') {
                $includePSErrors = $true
                $psErrorCount = [int]$Matches[1]
            } elseif ($token -match '^b(\d+)$') {
                $includeBashErrors = $true
                $bashErrorCount = [int]$Matches[1]
            } else {
                Write-Host "Error: Formato inválido en -e. Usa pN para PowerShell o bN para Bash (ej: -e p3,b5)." -ForegroundColor Red
                exit 1
            }
        }
    }
}

# Recoger errores de PowerShell
if ($includePSErrors -and $psErrorCount -gt 0) {
    if ($Error.Count -gt 0) {
        $psErrors = ($Error | Select-Object -Last $psErrorCount | ForEach-Object { $_.ToString() }) -join "`n"
        $errorContent += "`n=== Últimos $psErrorCount errores de PowerShell ===`n$psErrors"
    } else {
        $errorContent += "`n=== No hay errores recientes de PowerShell registrados ==="
    }
}

# Recoger errores de Bash
if ($includeBashErrors -and $bashErrorCount -gt 0) {
    try {
        wsl bash -c "history -a" | Out-Null
        $bashErrorHistoryRaw = wsl cat ~/.bash_history
        $bashErrorHistory = $bashErrorHistoryRaw -split "`n"
        $bashCommands = ($bashErrorHistory | Select-Object -Last $bashErrorCount) -join "`n"
        $errorContent += "`n=== Últimos $bashErrorCount comandos en Bash tras errores ===`n$bashCommands"
    } catch {
        $errorContent += "`n(No se pudo determinar el estado de errores en Bash)"
    }
}

# Archivos/directorios
$fileContent = ""
if ($f) {
    foreach ($fileItem in $f) {
        $resolvedFile = Resolve-Path -Path $fileItem -ErrorAction SilentlyContinue
        if ($resolvedFile) {
            $ext = [System.IO.Path]::GetExtension($resolvedFile)
            $specialFile = $false

            if ($ext -in ".json", ".yaml", ".yml" -or (Split-Path $resolvedFile -Leaf) -like "Dockerfile") {
                $specialFile = $true
            }

            if ($specialFile) {
                $fileContent += "`n=== Contenido de archivo especial '$fileItem' ===`n" + (Get-LimitedFileContent -FilePath $resolvedFile -FullMode:$full)
            } else {
                $fileContent += "`n=== Contenido de archivo '$fileItem' ===`n" + (Get-LimitedFileContent -FilePath $resolvedFile -FullMode:$full)
            }
        } else {
            $fileContent += "`n(No se encontró el archivo especificado '$fileItem')"
        }
    }
}

$directoryContent = ""
if ($d) {
    $resolvedDir = Resolve-Path -Path $d -ErrorAction SilentlyContinue
    if ($resolvedDir) {
        $directoryContent = "`n=== Listado del directorio '$d' ===`n" + (Get-ChildItem -Path $resolvedDir | Select-Object Name, Length | Out-String)

        $specialFiles = Get-ChildItem -Path $resolvedDir -Recurse -Include *.json,*.yml,*.yaml,Dockerfile,*.env,*.conf,*.ini -ErrorAction SilentlyContinue
        foreach ($special in $specialFiles) {
            $directoryContent += "`n=== Contenido de archivo especial encontrado '$($special.Name)' ===`n" + (Get-LimitedFileContent -FilePath $special.FullName -FullMode:$full)
        }
    } else {
        $directoryContent = "`n(No se encontró el directorio especificado '$d')"
    }
}

# Directorio actual
$currentDirectory = (Get-Location).Path

# CONTEXTO ADICIONAL
Write-Host "CONTEXTO ADICIONAL (puedes copiar y pegar errores, fragmentos de archivos, etc):" -ForegroundColor Yellow
$userInput = Read-Host

# Aclaracíon de errores
$ACLARACION = ""

if ($e) {
    $ACLARACION = "`nACLARACIÓN SOBRE ERRORES A IGNORAR: Si los errores están relacionados con parámetros no válidos e incluyen exactamente el término 'aishell2.ps1' corresponderán al propio uso de la llamada mediante la que se está pidiendo ayuda, y NUNCA deberán tenerse en cuenta."
}

# Preparar prompt
$prompt = "Historial combinado:`n$combinedHistory`n$fileContent`n$directoryContent`n$errorContent$ACLARACION`n`nContexto adicional:`n$userInput`n`nNOTA: El comando 'aishell2' fue ejecutado desde el directorio: '$currentDirectory'."


# Consultar IA
$response = Ask-Groq -Prompt $prompt -Groq_API_Key $Groq_API_Key

if ($response) {
    Write-Host "`nRespuesta de AI Shell (comandos en colores, texto explicativo en amarillo):" -ForegroundColor Green
        $response -split "`n" | ForEach-Object {
        if ($_ -match "^\s*Bash:\s*\$\>\s*(.+)$") {
            $command = $Matches[1]
            Write-Host "$> $command" -ForegroundColor Magenta
        } elseif ($_ -match "^\s*Powershell:\s*\$\>\s*(.+)$") {
            $command = $Matches[1]
            Write-Host "$> $command" -ForegroundColor Cyan
        } else {
            Write-Host $_ -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No se recibió respuesta de la IA." -ForegroundColor DarkRed
}
