# enjoy · Proyecto completo

Esta carpeta contiene la interfaz, fuentes, video real de 28 segundos, licencias, base de datos, control de acceso y procesador de recordatorios. No necesita el servidor Python de las entregas anteriores. La interfaz conserva el diseño azul y plomo y el crédito a Neodat Consultores; no muestra nombres de proveedores técnicos.

## 1. Extraer todo

Extraiga el ZIP completo. Debe tener esta estructura:

```text
index.html
crm.css
crm.js
connection.js
config.js
favicon.svg
CONFIGURAR.ps1
VERIFICAR.ps1
ARCHIVOS.json
assets/                 fuentes, video y portada
supabase/               instalación de datos y funciones
docs/                   instrucciones técnicas
tests/                  comprobaciones automatizadas
```

No copie solo los archivos sueltos. La carpeta `assets` es indispensable para que se vea igual que la versión anterior. No suba el ZIP como único archivo del repositorio.

## 2. Crear su proyecto

Cree un proyecto de Supabase. En su SQL Editor abra y ejecute **supabase/INSTALAR.sql** completo, una sola vez y en un proyecto nuevo. Si ya existe un esquema `enjoy`, no lo borre ni repita la instalación: revise primero su versión y respaldos. El archivo usa una transacción para evitar una instalación parcial.

Mantenga `enjoy` como esquema interno, no expuesto en Data API. `public` debe seguir expuesto para las funciones controladas. No otorgue permisos de tablas a visitantes o usuarios: las operaciones pasan por la función autorizada.

En Authentication active registro por correo, confirmación de correo y contraseña mínima de 10 caracteres. Configure la URL y las redirecciones autorizadas de su interfaz. Para pruebas locales puede autorizar http://localhost:8772/. Para cuentas reales configure un servicio de correo de producción, límites de acceso y protecciones antiabuso.

## 3. Configurar la conexión

Desde PowerShell, en esta carpeta, ejecute:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\CONFIGURAR.ps1
```

La opción Bypass se aplica solo a ese proceso para ejecutar este archivo local; no cambia la política permanente del equipo. También puede editar `config.js` manualmente y evitar ejecutar el script.

El script solicita únicamente la URL y la **clave publicable** del proyecto. Nunca utilice una clave secreta, `service_role`, contraseña de base de datos ni token de WhatsApp. La clave publicable es inspeccionable en el navegador por diseño; los permisos de la base de datos son los que protegen los registros.

## 4. Crear el administrador

Abra la interfaz y solicite una cuenta con SU correo, confirme ese correo y copie su UUID desde Authentication → Users. Abra **supabase/ADMINISTRADOR.sql**, sustituya el UUID de ceros por el de su cuenta y ejecútelo en SQL Editor. Este paso solo se hace una vez. Conserve la plantilla original sin datos personales en el repositorio.

Ingrese con esa cuenta para aceptar o rechazar talleres. Cada propietario debe solicitar su propia cuenta y confirmar su correo. La aprobación es obligatoria: registrarse no concede acceso automático. El administrador también habilita la edición del catálogo de cada taller.

## 5. Cargar el proyecto completo

Para el repositorio público, cargue el contenido de esta carpeta con Add file → Upload files. Arrastre también las carpetas completas `assets`, `supabase`, `docs` y `tests`. Confirme con Commit changes. En el listado del repositorio debe verse `assets` como carpeta, no únicamente los archivos principales.

El repositorio guarda el código; subirlo no instala la base de datos ni configura una cuenta. El alojamiento HTTPS de la interfaz debe resolverse por separado. GitHub Pages excluye alojar una plataforma comercial SaaS según sus condiciones; no se incluye una automatización para desplegar allí este CRM. Véase docs/IMPLEMENTACION.md.

## 6. Recordatorios

Al crear una cita futura se guardan dos avisos para una hora antes, con zona America/Guayaquil. La vista previa funciona en modo de prueba. Para ejecutar automáticamente la revisión debe desplegar la función y activar el programador según **docs/WHATSAPP.md**. No se enviará ningún mensaje real sin activar explícitamente el modo live y configurar Meta.

## Comprobar los archivos

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\VERIFICAR.ps1
```

El verificador detecta archivos ausentes o modificados; `config.js` puede cambiar al configurar su proyecto. No sustituye una prueba de acceso con dos talleres distintos.

## Qué queda a cargo de su cuenta

Crear el proyecto, configurar sus valores publicables, ejecutar los SQL, definir su administrador, contratar/configurar el alojamiento HTTPS permitido y, más adelante, configurar WhatsApp. No se incluyen cuentas reales ni servicios contratados. La entrega no está conectada ni desplegada en su cuenta.
