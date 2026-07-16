# Interfaz Hito 3 BDD

Guía rápida de configuración local de la base de datos y ejecución del proyecto para todos los miembros del equipo.

---

## Paso 1: Descargar e Instalar PostgreSQL
1. Descarga el instalador oficial de PostgreSQL (las pruebas se hicieron con la versión 16):
   👉 [Descargar PostgreSQL](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads)
2. Abre el instalador de Windows y haz clic en **Siguiente (Next)** a todo, dejando los directorios de instalación y el puerto (`5432`) por defecto.
3. **Casillas de componentes:** Deja marcados todos los componentes (incluyendo pgAdmin 4, Stack Builder y Command Line Tools).
4. **Contraseña:** Elige una contraseña de administrador muy sencilla y fácil de recordar (por ejemplo: `12345`). La necesitarás más adelante.
5. Al terminar de instalar, desmarca la casilla de abrir *Stack Builder* y haz clic en **Finalizar (Finish)**.

---

## Paso 2: Configurar credenciales en el proyecto
1. Ve a la carpeta raíz de este proyecto, copia el archivo `db_config.example.json` y renómbralo como **`db_config.json`**.
2. Abre tu nuevo archivo `db_config.json` y escribe en la línea de la contraseña la clave que definiste en el Paso 1:
   ```json
   {
       "DB_HOST": "localhost",
       "DB_PORT": 5432,
       "DB_NAME": "postgres",
       "DB_USER": "postgres",
       "DB_PASSWORD": "tu_contraseña_del_paso_1"
   }
   ```
   *(Este archivo `db_config.json` está en `.gitignore`, por lo que tus contraseñas locales nunca se subirán a Git).*

---

## Paso 3: Importar base de datos y correr el Servidor Puente
Abre tu terminal en la raíz del proyecto y realiza lo siguiente:

1. **Cargar la base de datos (se ejecuta solo la primera vez):**
   ```bash
   dart lib/import_db.dart
   ```
   *(Este comando leerá de inmediato tu archivo `bd/iniciar_bd.sql` y cargará todo el esquema `registro_costos_marginales` y datos de prueba a tu PostgreSQL local en tan solo ~20 segundos).*

2. **Iniciar el Servidor Puente (debe mantenerse corriendo en segundo plano):**
   ```bash
   dart lib/server.dart
   ```
   *(Este servidor actúa de puente HTTP para permitir que la aplicación en versión Web pueda comunicarse con tu PostgreSQL local saltándose las restricciones de red del navegador).*

---

## Paso 4: Ejecutar la aplicación de Flutter Web
Abre una **segunda terminal** (sin cerrar la terminal donde iniciaste `server.dart`) y ejecuta el siguiente comando:

```bash
flutter run -d web-server --dart-define-from-file=db_config.json
```
*(Una vez que cargue, abre la dirección que te entrega en la terminal en tu navegador favorito como Firefox, Chrome o Edge).*

### Datos de Inicio de Sesión de Prueba:
Una vez abierta la aplicación, inicia sesión con el RUT de encargados que sí tienen cargados costos marginales en la base de datos de pruebas (escríbelos con puntos y guion):
*   **Daniela Arriagada:** `15.444.333-2` (Administra la Barra 321 con datos históricos cargados).
*   **Darwin Núñez:** `33.333.333-3` (Administra la Barra 325).
*   **Nicolás Jackson:** `44.444.444-4` (Administra la Barra 326).
*   **Harry Maguire:** `11.111.111-1` (Administra la Barra 331).

---

💡 *Tip: Para apagar el servidor puente de forma limpia cuando termines de probar el proyecto, ve a su terminal, escribe `q` o `exit` y presiona Enter.*
