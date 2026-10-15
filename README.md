# enjoy · Gestión automotriz

Proyecto completo para gestión de talleres. Comience en **[LEAME-PRIMERO.md](LEAME-PRIMERO.md)**.

- Un administrador, aprobación de talleres y permisos de catálogo.
- Clientes y vehículos separados por taller.
- Agenda diaria, semanal y mensual; duración, recepción y estados de citas.
- Historial del cliente y plan de mantenimiento por fecha o kilometraje.
- Insumos, mano de obra, iconos y descuentos.
- Solicitudes editables antes de confirmar, alertas e indicadores calculados.
- Exportación JSON de los registros disponibles para la cuenta y actividad reciente.
- Dos avisos de WhatsApp una hora antes, en modo de prueba por defecto.
- Diseño institucional azul/plomo y recursos locales completos.

Interfaz HTML/CSS/JavaScript; autenticación y PostgreSQL en Supabase; función TypeScript para mensajería. Repositorio público compatible, sin datos reales ni credenciales privadas.

Crédito visible: [Desarrollado por Neodat Consultores](https://neodat.net).

Para desarrollo: Node.js 24 o posterior, `npm ci --ignore-scripts`, `npm run check`, `npm test`. La dependencia de pruebas no se necesita para servir la aplicación. La validación local usa usuarios ficticios y no sustituye las comprobaciones de Auth, correo, funciones y programador en su proyecto.

Fuentes e iconos con sus licencias en assets. El código propio no incluye una licencia abierta de redistribución por el mero hecho de publicar el repositorio.
