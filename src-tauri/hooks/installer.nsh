; Tauri-react-template — NSIS hooks personalizados
; Inyectado via bundle.windows.nsis.installerHooks en tauri.windows.conf.json
; Requiere NSIS 3.x + MUI2 (Unicode)
; 4 macros obligatorias: PREINSTALL / POSTINSTALL / PREUNINSTALL / POSTUNINSTALL

!macro NSIS_HOOK_PREINSTALL
  DetailPrint "Tauri-react-template: verificando instancia en ejecucion..."
  ; Cierra el proceso si quedo abierto (evita "file in use" en upgrade)
  ExecWait 'taskkill /f /im tauri-react-template.exe' $0
  Sleep 600
  ; Limpia posible lock de actualizador
  Delete "$TEMP\tauri-react-template*.tmp" 
  DetailPrint "Tauri-react-template: pre-instalacion OK"
!macroend

!macro NSIS_HOOK_POSTINSTALL
  DetailPrint "Tauri-react-template: configurando accesos directos..."
  ; El instalador base ya crea Start Menu / Desktop segun opcion del usuario.
  ; Aqui se podria registrar protocolo o asociacion si se anade deep-link.
!macroend

!macro NSIS_HOOK_PREUNINSTALL
  DetailPrint "Tauri-react-template: cerrando antes de desinstalar..."
  ExecWait 'taskkill /f /im tauri-react-template.exe' $0
  Sleep 600
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  DetailPrint "Tauri-react-template: limpieza completada"
  ; Opcional: borrar datos de usuario si el usuario eligio "remove app data"
  ; RMDir /r "$APPDATA\com.tauri-react-template.app"  ; descomentar si se desea
!macroend
