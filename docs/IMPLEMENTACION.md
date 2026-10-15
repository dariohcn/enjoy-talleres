# Implementación y acceso

## Separación de datos

El esquema interno enjoy tiene RLS habilitado y no concede acceso directo de tablas a anon ni authenticated. La función pública enjoy_api comprueba auth.uid(), el perfil y la aprobación del taller en cada operación. El navegador no decide el taller ni el perfil efectivo. El registro crea siempre un propietario pendiente y no acepta privilegios desde metadatos. Existe una restricción que impide dos administradores.

Los propietarios reciben únicamente sus registros. El administrador recibe talleres, propietarios, estados y conteos; no recibe las fichas de los clientes de todos los talleres. Solo el administrador cambia aprobaciones o permisos del catálogo. Las escrituras del taller se serializan para impedir reservas incompatibles. Los identificadores y vínculos se validan en el servidor.

Los tokens de sesión están en sessionStorage por pestaña y se renuevan con Auth. El servicio gestiona los intentos y el correo según la configuración de su cuenta. La recuperación de contraseña se administra inicialmente desde el proyecto; no hay formulario de recuperación integrado en esta entrega.

## Repositorio y alojamiento

Puede almacenar públicamente el código y la clave publicable. No publique contraseñas, claves secretas, service_role ni tokens de Meta. Si una clave privada se publica, revóquela; eliminarla del último archivo no la retira del historial.

GitHub Pages no admite como alojamiento gratuito una plataforma comercial SaaS: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits . Supabase cubre autenticación, datos y funciones. El alojamiento HTTPS de la interfaz no está contratado ni configurado por esta entrega. Con solo el repositorio y un proyecto de datos no hay todavía un despliegue comercial completo de la interfaz.

Para visualizar sin alojamiento, puede servir esta carpeta localmente con `python -m http.server 8772 --bind 127.0.0.1` y abrir http://localhost:8772/. Python solo sirve archivos en esta prueba; no es el servidor de la aplicación. El acceso a datos requiere la conexión configurada.

## Aceptación antes de datos reales

Verifique confirmación de correo, administrador único, aprobación y rechazo. Con dos propietarios compruebe que no puedan leer ni modificar registros ajenos, incluso por API. Pruebe el catálogo bloqueado y habilitado, citas superpuestas, cambios de horario y cancelaciones. Ensaye correo y recuperación, exportaciones y restauración de copias.

La descarga JSON no es un respaldo completo de Auth ni reemplaza los respaldos de PostgreSQL. Configure retención, copias automáticas y pruebas de restauración según el plan de su cuenta. No hay migración automática desde la antigua SQLite, facturación, portal de consumidores ni publicación en tiendas. Los criterios contractuales deben validarse antes de aceptación definitiva.
