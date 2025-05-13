## AISHELL2

---

# 🚀 ¿Qué es `aishell2`?

aishell2 es un comando personalizable que permite enviar historial de terminal, archivos relevantes, errores recientes y contexto manual a un modelo de lenguaje (LLM) alojado en Groq.

Puede ayudarte a:

Diagnosticar errores en terminales Bash/PowerShell.

Sugerir correcciones de comandos.

Interpretar archivos como Dockerfile, docker-compose.yml, .env, .json, .yml, etc.

Recibir instrucciones prácticas y coloreadas para ejecución directa en tu terminal.



## Modos de Uso

| Modo | Descripción |
|:--|:--|
| `-f archivo1,archivo2` | Incluye uno o varios archivos en el contexto enviado. |
| `-d directorio` | Incluye todos los archivos especiales (.yml, .json, Dockerfile, etc.) de un directorio. |
| -p N	| Añade los últimos N comandos de PowerShell al contexto. |
| -b N	| Añade los últimos N comandos de Bash al contexto. |
| -e pN,bM	| Añade errores recientes: pN para PowerShell y bM para Bash. Ej: -e p3,b5. |
| `-full` | Envía archivos completos, ignorando el límite de 500 líneas o 32 KB. |
| `-h` | Muestra la ayuda de uso rápida. |

---

## 🎨 Comandos coloreados

Las instrucciones de la IA están coloreadas según su contexto:

💜 Bash: líneas que comienzan con Bash: $> se muestran en magenta.

💙 PowerShell: líneas que comienzan con Powershell: $> se muestran en cyan.

💛 Explicaciones y notas se muestran en amarillo.

Ejemplo:
![Salida de ejemplo con colores](EjemploAISHELL2.png)

---

# ⚠️ Riesgos y Precauciones

**IMPORTANTE:**  
Cuando usas `aishell2`, **los datos (historiales, archivos, errores y contexto adicional) son enviados a los servidores de Groq** a través de la API, **como si los escribieras en un navegador en servicios como ChatGPT, Gemini o similares**.

**Precauciones recomendadas:**

- **No uses `aishell2` en entornos profesionales/confidenciales** sin aprobación.
- **Nunca envíes información sensible, contraseñas, secretos, archivos confidenciales**.
 - Considera redactar manualmente el contexto y limitar el uso de flags -p, -b o -e si el entorno es delicado.

✅ Recuerda: aunque Groq tiene políticas de privacidad, **al usar un LLM público, los datos salen de tu máquina**.

---

# ⚙️ Configuración paso a paso

## 1️⃣ Obtener API Key de Groq

- Regístrate en [Groq Cloud](https://console.groq.com/).
- Copia tu **API Key**.
- Guarda la API Key cifrada en un archivo ejecutando:

```powershell
"TU_API_KEY_AQUI" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Path "$env:USERPROFILE\.groq_api_key"
```

✅ Así aishell2 podrá leer tu clave de forma segura.

---

## 2️⃣ Configurar alias en PowerShell7

En PowerShell 7:

1. Abre tu perfil:

```powershell
notepad $PROFILE
```

2. Añade esta línea al final:

```powershell
Set-Alias aishell2 "C:\Users\<YOURUSERNAME>\grokAIshell\aishell2.ps1"
```

✅ Ahora podrás usar `aishell2` directamente en PowerShell7.

* Recuerda que el historial de Bash/WSL2 que reciba será el último guardado, de modo que si tienes ambos terminales abiertos deberás cerrar bash o hacer history -a para que aishell2 pueda verlo actualizado.

---

## 3️⃣ Configurar función en Bash (WSL2)

En tu terminal Bash:

1. Abre tu `.bashrc`:

```bash
nano ~/.bashrc
```

2. Pega la función completa (y, si usaste mis rutas, sustituye YOURUSERNAME por el tuyo):

```bash
function aishell2() {
    local bash_dir
    bash_dir=$(pwd)
    history -a

    local distro_name
    distro_name=$(wsl.exe -l --quiet --running | grep '*' | sed 's/\*//g' | awk '{$1=$1};1')

    if [[ "$bash_dir" == /mnt/* ]]; then
        drive_letter=$(echo "$bash_dir" | cut -d'/' -f3)
        path_rest=$(echo "$bash_dir" | cut -d'/' -f4-)
        windows_dir="${drive_letter^^}:\\"$(echo "$path_rest" | sed 's|/|\\|g')
        pwsh.exe -NoLogo -WorkingDirectory "$windows_dir" -ExecutionPolicy Bypass -File C:\\Users\\<YOURUSERNAME>\\grokAIshell\\aishell2.ps1 "$@"
    else
        windows_dir="\\\\wsl$\\${distro_name}${bash_dir}"
        pwsh.exe -NoLogo -WorkingDirectory "$windows_dir" -ExecutionPolicy Bypass -File C:\\Users\\<YOURUSERNAME>\\grokAIshell\\aishell2.ps1 "$@"
    fi
}
```

3. Guarda y aplica:

```bash
source ~/.bashrc
```

✅ Ahora podrás usar `aishell2` también desde Bash/WSL2.

* Debido a que WSL2 no tiene acceso al historial de PowerShell por defecto (y a que guardarlo en otro archivo accesible sería una pérdida de recursos y seguridad significativa), ejecutar aishell2 desde bash en tu WSL solo recibirá comandos lanzados desde bash. Si fuesen necesarios ambos, se recomienda lanzarlo desde PowerShell o añadirlo como CONTEXTO:

---

# 🔧 Personalizaciones posibles

## 1️⃣ Cambiar el modelo LLM usado

En `aishell2.ps1`, busca la sección donde está el modelo:

```powershell
"model" = "llama3-70b-8192"
```

🔸 Puedes cambiarlo por cualquier modelo disponible en Groq, como `gemma-7b-it`, etc. 
También se pueden usar otros modelos no-gratuitos o ilimitados modificando en aishell2.ps1 la $uri = "https://..."

---

## 2️⃣ Cambiar el alias `aishell2` y/o el nombre del archivo aishell2.ps1

           PARA EL ALIAS:
           
```
- En PowerShell7: cambia el alias en tu `$PROFILE`.
- En Bash: cambia el nombre de la función `function aishell2()`.
```
            PARA EL NOMBRE DEL ARCHIVO:
            
```
- Deberas modificar también tu ~/.bashrc y tu notepad $PROFILE para corregir con el nuevo path.
```
  
**Importante:**
             SI CAMBIAS CUALQUIERA:
```
* Revisa también `aishell2.ps1` para sustituir las alusiones del nombre de comando o de archivo.

```
---

# 🏁 Final

✨ Disfruta de tu `aishell2` — diseñado para ser potente, profesional y adaptado tanto a Bash como a PowerShell7.

---
