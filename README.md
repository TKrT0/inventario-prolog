# Inventario y lista de compras

Aplicación web local con reglas y backend en **SWI-Prolog**. La interfaz usa HTML, CSS y JavaScript sin frameworks ni compilación.

Proyecto académico de inventario basado en hechos, reglas e inferencia lógica.

- [Guía rápida de ejecución y consultas](GUIA_EJECUCION.md)
- [Guion completo de exposición](EXPOSICION.md)

## Qué permite hacer

- Consultar los cinco productos, sus existencias, mínimos y proveedores.
- Ver los productos que requieren compra y las unidades faltantes.
- Editar existencias y mínimos; Prolog recalcula las necesidades.
- Conservar los cambios en un archivo local entre ejecuciones.

## Requisitos y arranque

Necesitas SWI-Prolog con sus bibliotecas estándar HTTP/JSON y un navegador moderno. Se ha verificado con SWI-Prolog **10.0.2** y Chromium mediante Playwright.

En CachyOS/Arch puedes instalar SWI-Prolog con:

```bash
sudo pacman -S swi-prolog
```

Para otros sistemas, consulta <https://www.swi-prolog.org/download/stable>.

Desde esta carpeta:

```bash
swipl -q -s servidor.pl
```

Abre **http://127.0.0.1:8080**. No abras `web/index.html` directamente: necesita la API servida por Prolog.

Para cerrar, pulsa Ctrl+C y elige `e` si SWI-Prolog muestra su menú. Si el puerto 8080 está ocupado, cierra primero la instancia que lo use; no ejecutes dos servidores sobre el mismo archivo de datos.

## Archivos

```text
inventario.pl       Datos, reglas, validación y persistencia
servidor.pl         API HTTP, archivos web y punto de entrada
web/                HTML, CSS y JavaScript
tests/              Pruebas de Prolog, HTTP y navegador
data/inventario.json  Datos guardados; se crea al iniciar
GUIA_EJECUCION.md    Arranque y uso básico del intérprete
EXPOSICION.md        Guion de presentación y demostración
```

## Datos y guardado

El primer arranque crea `data/inventario.json` con los datos del documento. Las siguientes ejecuciones leen ese archivo sin reiniciarlo. Su ubicación depende de la carpeta del proyecto, no de dónde ejecutes el comando.

El servidor valida cantidades y mínimos como enteros entre `0` y `9007199254740991`. Un producto desconocido no crea un registro.

Cada actualización escribe una instantánea temporal en el mismo volumen, la cierra y reemplaza el archivo mediante renombrado atómico. La memoria solo cambia después de guardar. Los lectores y escritores del proceso se coordinan con un bloqueo.

Un archivo inválido, incompleto o con productos duplicados produce un error; no se sobrescribe con datos iniciales. No edites el JSON mientras el servidor esté funcionando. Para conservar datos importantes, haz una copia del archivo con el servidor detenido.

## Consultas originales

La lógica se puede cargar sin iniciar el servidor, imprimir una demostración ni cerrar Prolog:

```prolog
?- [inventario].
?- cargar_inventario('data/inventario.json').
?- requiere_compra(Producto).
?- lista_compras(Producto, Proveedor).
?- cantidad_a_comprar(croquetas_perro, Faltante).
?- resumen_inventario(Registros).
?- compras(Lista).
```

`cantidad_a_comprar/2` conserva su significado original: solo devuelve soluciones cuando falta stock. El resumen web representa los demás faltantes como cero.

Con los datos iniciales faltan 6 unidades de `monster_energy`, 3 de `croquetas_perro`, 2 de `lapiceros_pentel` y 5 de `galletas`. El agua no requiere compra. Si ya editaste el inventario, los resultados reflejarán esos cambios.

## API

| Método y ruta | Resultado |
| --- | --- |
| `GET /api/inventario` | Lista con `producto`, `cantidad`, `minimo`, `proveedor`, `faltante` |
| `GET /api/compras` | Lista con `producto`, `proveedor`, `cantidad` a comprar |
| `PUT /api/inventario/<producto>` | Actualiza cantidad y mínimo; devuelve el registro |

Ejemplo de cuerpo para actualizar:

```json
{"cantidad": 5, "minimo": 5}
```

El PUT exige `Content-Type: application/json`, un cuerpo de hasta 4096 bytes y exactamente esos dos campos. Los errores devuelven `{"error":"mensaje"}` con estado 400, 403, 404, 405 o 500 según corresponda.

No existe una ruta que acepte consultas Prolog arbitrarias.

## Pruebas

Desde la carpeta del proyecto:

```bash
swipl -q -s tests/run_tests.pl
node --check web/app.js
```

Node se usa únicamente para una comprobación opcional de sintaxis; **no es necesario para ejecutar la aplicación**. Las pruebas Prolog usan archivos temporales y un puerto libre. El mensaje de almacenamiento durante `fallo_guardado_http` es intencional: comprueba que el servidor responde 500 sin alterar datos.

Para las pruebas de navegador necesitas Python y Playwright en un entorno de pruebas, no en el Python del sistema:

```bash
python -m venv .venv-pruebas
.venv-pruebas/bin/pip install playwright
.venv-pruebas/bin/python -m playwright install chromium
.venv-pruebas/bin/python tests/browser_tests.py
```

El script inicia y detiene su propio servidor con un puerto libre y datos temporales. Comprueba carga, edición, errores de servidor y red, recuperación del formulario, foco, lista vacía y vista móvil. Las capturas quedan en `.impeccable/review/`; no se sirven al navegador desde la aplicación.

## Qué se mejoró

- El código dejó de estar únicamente dentro de Word y quedó organizado en módulos.
- Se separó la lógica del arranque y de la presentación; desapareció el `halt` al importar.
- Un registro coherente por producto evita desincronizar inventario, mínimo y proveedor.
- Las reglas ya no repiten la búsqueda de los mismos hechos para calcular faltantes.
- La consulta de croquetas ya no controla el éxito de toda la aplicación.
- Se añadieron datos estructurados, edición validada, guardado y pruebas.
- La interfaz conserva el formulario si falla un guardado y distingue un guardado exitoso de un fallo posterior al recargar.

## Alternativas y límites

Se eligió web local porque SWI-Prolog puede servir HTTP y JSON directamente. Para escritorio, Python/Tkinter con `swiplserver`/MQI es una alternativa. **XPCE también ofrece GUI en Prolog**; la afirmación del documento sobre su ausencia no es exacta. La eficiencia no depende únicamente de usar paradigma lógico u orientado a objetos.

Esta versión está pensada para una persona y un proceso local. No incluye altas, bajas, cuentas, precios, ventas ni edición de proveedores. No publiques el puerto en Internet: no hay autenticación ni TLS. El servidor solo escucha en loopback y rechaza hosts u orígenes ajenos.

El renombrado evita archivos a medio escribir durante errores normales, pero no promete durabilidad ACID ante un corte eléctrico. Un cierre abrupto puede dejar un directorio temporal huérfano junto al archivo, sin reemplazar la última instantánea válida antes del renombrado.

Si el proyecto crece hacia usuarios simultáneos, catálogo variable o ventas, el siguiente paso sería definir esas operaciones y evaluar una base de datos transaccional. No hace falta añadirla para esta entrega.
