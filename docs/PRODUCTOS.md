# Productos e imágenes

El administrador gestiona el catálogo de la plataforma y puede asignar productos a un taller activo. Los propietarios ven el catálogo general y sus propios productos.

Permisos por taller, establecidos únicamente por el administrador:
- Solo consultar: sin publicaciones ni modificaciones.
- Publicar y editar: crea y modifica productos propios.
- Gestionar y retirar: incluye retirar productos propios; se conserva el registro y puede reactivarse.

El registro del taller admite una imagen opcional. Al aprobarse, su propietario puede cambiarla desde Cuenta y respaldo. Las imágenes se convierten a JPEG con un máximo de 400 píxeles y 75.000 caracteres codificados. Los archivos originales deben ser JPG, PNG o WebP de hasta 5 MB. Se guardan miniaturas privadas en PostgreSQL; no se publican buckets ni direcciones externas. La imagen inicial se copia al taller y se retira de los metadatos de autenticación para no aumentar los JWT.

El catálogo devuelve los 200 productos más recientes autorizados. Un proyecto con catálogos mayores debe incorporar paginación y almacenamiento privado de imágenes antes de aumentar ese límite.

Instalación nueva: INSTALAR.sql incluye la estructura completa. Proyecto existente: ejecutar PRODUCTOS-IMAGENES.sql después de PANEL-ADMIN.sql y RETIRAR-TALLER.sql. Los scripts son recuperables en el repositorio y no contienen credenciales privadas.
