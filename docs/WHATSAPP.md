# Recordatorios

Destinatarios: propietario del taller y propietario del vehículo. Hora prevista: una hora antes de la cita, en America/Guayaquil. La cola persistente se crea al guardar una cita futura. Cambiar el horario cancela los avisos pendientes anteriores; cancelar o completar cancela los pendientes. Los mensajes ya aceptados no pueden retirarse del teléfono.

## Modo de prueba

La vista Recordatorios permite revisar el texto sin Meta. El procesamiento automático requiere instalar la función incluida. En prueba no se realizan llamadas a WhatsApp.

1. Vincule el proyecto con la CLI oficial de Supabase. Desde esta carpeta despliegue `supabase functions deploy appointment-reminders`.
2. En los secretos de Edge Functions configure `REMINDER_JOB_SECRET` con un valor aleatorio de al menos 32 caracteres y `WHATSAPP_MODE=test`. Las variables SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY deben estar disponibles como variables de servidor de la función; nunca en config.js.
3. En Vault cree `enjoy_reminder_url` con la URL HTTPS de appointment-reminders y `enjoy_reminder_job_secret` con el mismo secreto del paso anterior. Introduzca valores en el panel, no en archivos públicos.
4. Ejecute **supabase/PROGRAMAR.sql** en SQL Editor. Crea una comprobación cada minuto y evita duplicar la programación.

La validación JWT de esta función está desactivada en config.toml porque utiliza el secreto propio del programador. El código rechaza cualquier petición sin ese secreto. Las funciones de base de datos para reclamar avisos solo permiten service_role, no visitantes ni propietarios.

Pruebe una cita para dentro de 30 minutos: el aviso ya estará dentro de la hora prevista y debe pasar a Modo de prueba sin ningún envío real.

## Activar después

Configure secretos WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_TEMPLATE_NAME, WHATSAPP_API_VERSION (versión vigente habilitada, formato vNN.N) y WHATSAPP_TEMPLATE_LANGUAGE (por defecto es). Necesita una plantilla aprobada con seis parámetros: taller, cliente, placa, fecha DD/MM/AAAA, hora y servicio.

```text
{{1}}: Recordatorio de cita para {{2}}. Vehículo: {{3}}. Fecha: {{4}}. Hora: {{5}}. Servicio: {{6}}.
```

Registre los dos números reales con código de país y sus autorizaciones. Solo entonces establezca WHATSAPP_MODE=live. Revise los pendientes: los avisos ya dentro de la hora anterior pueden enviarse en la siguiente revisión. El procesador reclama hasta 20 por ejecución; supervise la cola si crece. La revisión por minuto y la disponibilidad del proveedor no garantizan un segundo exacto de entrega.

Un identificador de la API significa aceptación, no entrega o lectura. No hay webhook de entrega. Una respuesta incierta no se reenvía automáticamente; requiere revisión manual. Las ejecuciones interrumpidas pasan a revisión después de cinco minutos. Los avisos aceptados no se repiten automáticamente. Los costos del proveedor no están incluidos.

Documentación: https://supabase.com/docs/guides/functions/schedule-functions y https://developers.facebook.com/docs/whatsapp/cloud-api/ .

El despliegue configurado consulta el secreto del programador desde Vault mediante una función exclusiva del servidor. REMINDER_JOB_SECRET puede utilizarse como alternativa en el entorno. El modo predeterminado es test; el programador está configurado y no requiere credenciales de Meta para comprobar horarios y destinatarios.
