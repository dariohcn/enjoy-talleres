# Validación de la entrega

Comprobaciones ejecutadas en esta entrega:

- 41 casos PostgreSQL con PGlite: instalación SQL, registro sin elevación de perfil, administrador único, aprobación/rechazo, bloqueo de tablas directas, separación de talleres, permisos del catálogo, placa duplicada, descuento inválido, creación de registros sin identificador, fecha/hora, superposición de citas, anticipación de una hora, dos destinatarios, idempotencia, reprogramación, cancelación, consentimiento, solicitudes confirmadas e indicadores administrativos.
- 6 casos del adaptador: autenticación, autorización, cierre de sesión, aprobación y rechazo de claves privilegiadas en el navegador.
- 8 casos del procesador: autenticación del programador, método HTTP, modo de prueba sin envío externo, configuración incompleta, aceptación y tratamiento de resultados rechazados o inciertos.
- Revisión sintáctica del JavaScript y transpilación del procesador TypeScript.
- Verificación de los recursos referenciados y manifiesto SHA256 de los archivos del paquete.

Los ensayos usan datos ficticios, dobles de auth.uid()/auth.role()/auth.users y transporte simulado. No se enviaron mensajes reales ni se accedió a un proyecto del usuario. No prueban la entrega de correo, los JWT reales, Vault, el cron alojado ni los cargos del proveedor. No equivalen a aceptación de producción.

Puede repetirlos con Node.js 24 o posterior:

```text
npm ci --ignore-scripts
npm run check
npm test
```

Complete las pruebas de integración y de restauración en su cuenta antes de usar datos reales.

## Verificación del proyecto configurado — 15 de octubre de 2026

Se verificaron en el proyecto enjoy los ingresos reales de administrador y taller, el rechazo de operaciones administrativas desde el propietario, la persistencia de un cliente, un vehículo y una cita ficticios, y la generación de dos recordatorios. El programador está activo cada minuto y la función devolvió HTTP 200 en modo test. Los dos destinatarios quedaron en modo de prueba y no se enviaron mensajes reales.

Las cuentas de prueba y sus contraseñas se entregan por separado; no están en este repositorio. La clave publicable de config.js está conectada al proyecto. Las contraseñas y los secretos del programador no se incluyen en el código público.
