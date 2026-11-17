# Exposición: sistema de inventario y lista de compras

Guion desde el problema original hasta la aplicación web. Duración orientativa: **10–15 minutos**, más preguntas. Las frases entre comillas pueden usarse como explicación oral.

## 1. Presentación y objetivo

**Mostrar:** título del proyecto y aplicación abierta.

> Nuestro proyecto es un sistema de inventario y lista de compras basado en Prolog. Su objetivo es responder tres preguntas: qué productos necesitamos comprar, cuántas unidades faltan y a qué proveedor debemos pedirlas.
>
> Comenzamos con hechos y reglas que se consultaban en consola. Después conectamos esa lógica con una interfaz web para consultar y editar el inventario sin escribir instrucciones de Prolog.

## 2. El problema que queremos resolver

**Mostrar:** una fila del inventario, por ejemplo las croquetas.

> Llevar el inventario manualmente facilita que se nos termine un producto sin darnos cuenta. Para evitarlo, cada producto tiene una cantidad disponible y un stock mínimo. Si las existencias están por debajo de ese mínimo, el sistema deduce que necesitamos comprar.

Ejemplo inicial: hay **2** unidades de croquetas y el mínimo es **5**. Por tanto, faltan **3**. El sistema repone hasta el mínimo; no calcula una compra óptima según precios, demanda o descuentos.

## 3. Por qué utilizamos Prolog

> Prolog pertenece al paradigma lógico. En vez de indicar paso por paso cómo recorrer el inventario, declaramos los datos y las condiciones que debe cumplir una respuesta. El motor de Prolog busca las soluciones que satisfacen esas condiciones.

Tres conceptos importantes:

- **Hechos:** información que conocemos, como las existencias y el proveedor.
- **Reglas:** condiciones con las que deducimos información nueva.
- **Consultas:** preguntas que hacemos a la base de conocimiento.

Prolog utiliza **unificación** para relacionar términos y variables, y **retroceso** o *backtracking* para buscar otras soluciones.

> La palabra «inteligente» se refiere aquí a la inferencia mediante reglas. No estamos entrenando un modelo de aprendizaje automático.

## 4. De qué datos parte el sistema

**Mostrar:** esta tabla o los hechos de `inventario.pl`.

| Producto | Existencias | Mínimo | Proveedor | Faltante inicial |
| --- | ---: | ---: | --- | ---: |
| `monster_energy` | 4 | 10 | Distribuidora Bebidas | 6 |
| `croquetas_perro` | 2 | 5 | Veterinaria Central | 3 |
| `lapiceros_pentel` | 1 | 3 | Papelería Local | 2 |
| `agua_embotellada` | 20 | 15 | Distribuidora Bebidas | 0 |
| `galletas` | 5 | 10 | Gamesa | 5 |

> En el programa original, cada producto se describía con tres hechos: inventario, mínimo y proveedor. En la versión final agrupamos sus datos en un registro coherente, pero conservamos los predicados originales para poder consultarlos igual.

Ejemplo real de un hecho inicial:

```prolog
inicial(croquetas_perro, 2, 5, 'Veterinaria Central').
```

Al cargar los datos, el estado de trabajo se representa mediante `producto/4`. La notación `/4` significa que el predicado tiene **cuatro argumentos**, no que estemos realizando una división.

Los predicados `inventario/2`, `stock_minimo/2` y `proveedor/2` permiten acceder a ese registro manteniendo las consultas del proyecto original.

## 5. Cómo funcionan las reglas

**Mostrar:** estas reglas de `inventario.pl`.

```prolog
cantidad_a_comprar(Producto, Faltante) :-
    producto(Producto, Cantidad, Minimo, _),
    Cantidad < Minimo,
    Faltante is Minimo - Cantidad.

requiere_compra(Producto) :-
    cantidad_a_comprar(Producto, _).
```

> La primera regla busca los datos del producto y comprueba si la cantidad es menor que el mínimo. Solo entonces calcula la diferencia. La segunda utiliza ese resultado para identificar los productos que requieren compra.

Cómo leer la sintaxis:

- `:-` se interpreta como «se cumple si».
- Las comas enlazan condiciones: todas deben cumplirse.
- Las variables empiezan con mayúscula.
- `_` indica un valor que no necesitamos utilizar.
- `is` evalúa una expresión aritmética.
- El punto termina la regla o la consulta.

Si cantidad y mínimo son iguales, **no** hay compra. El agua tampoco aparece en la lista inicial porque tiene más unidades que su mínimo.

`lista_compras/2` relaciona cada producto faltante con su proveedor. La consulta agregada `compras/1` reúne producto, proveedor y cantidad para entregarlos a la interfaz.

## 6. Qué se corrigió respecto al programa original

> El código original servía como demostración de consola, pero no como un backend que permaneciera funcionando. Ejecutaba `main` al cargar el archivo y terminaba con `halt`. Además, una consulta fija de croquetas podía hacer fallar toda la demostración cuando ese producto ya no necesitaba compra.

Las mejoras principales fueron:

1. Extraer el código del Word y organizarlo en archivos Prolog.
2. Separar las reglas del arranque del servidor y de la presentación.
3. Conservar las consultas originales sin cerrar Prolog al importarlas.
4. Evitar búsquedas repetidas de los mismos datos al calcular faltantes.
5. Añadir actualización validada, almacenamiento y respuestas estructuradas.
6. Conectar una interfaz web y comprobar el funcionamiento con pruebas.

El Word original se conserva sin cambios.

## 7. Cómo está construido el producto final

**Mostrar:** el esquema y los archivos principales.

```text
Usuario en el navegador
        |
        | HTTP y JSON
        v
servidor.pl: API y archivos web
        |
        v
inventario.pl: datos, reglas y actualizaciones
        |
        v
data/inventario.json: estado guardado
```

- `inventario.pl` contiene la lógica del inventario.
- `servidor.pl` recibe peticiones HTTP y devuelve respuestas.
- `web/index.html` define la pantalla.
- `web/styles.css` define su presentación y adaptación móvil.
- `web/app.js` consulta la API y controla los formularios.

> Prolog sigue siendo el backend y el responsable de decidir qué comprar. JavaScript no vuelve a calcular las reglas: presenta las respuestas del servidor. Por eso no son dos inventarios independientes.

Se eligió web local porque SWI-Prolog ya dispone de bibliotecas HTTP y JSON. No necesitamos añadir un backend en Python o Node. Las alternativas consideradas fueron una aplicación de escritorio con Python/Tkinter y MQI, o una GUI mediante XPCE en Prolog.

## 8. Cómo se comunican la interfaz y Prolog

**Mostrar:** las rutas, sin necesidad de explicar todos los detalles de HTTP.

| Operación | Petición |
| --- | --- |
| Consultar existencias y faltantes | `GET /api/inventario` |
| Consultar la lista de compras | `GET /api/compras` |
| Cambiar cantidad y mínimo | `PUT /api/inventario/<producto>` |

Ejemplo de datos enviados al actualizar croquetas:

```json
{"cantidad": 5, "minimo": 5}
```

> Cuando guardamos, la interfaz envía esos datos. Prolog valida la actualización, la guarda y permite consultar nuevamente los resultados. Al alcanzar el mínimo, el producto deja de aparecer como compra pendiente.

Se rechazan cantidades negativas, decimales, valores fuera del rango permitido y campos desconocidos. Tampoco se crean productos mediante un identificador inexistente. No se permite enviar código Prolog arbitrario desde el navegador.

## 9. Cómo se conservan los cambios

> Declarar datos dinámicos permite modificarlos mientras Prolog está abierto, pero eso no basta para conservarlos al cerrar el programa. Por eso añadimos un archivo JSON con el estado del inventario.

La actualización sigue este orden:

1. Validar los datos nuevos.
2. Escribir y cerrar una instantánea temporal en el mismo volumen.
3. Reemplazar el archivo de datos mediante renombrado atómico.
4. Publicar el estado nuevo en memoria.

Si el guardado falla antes del reemplazo, no se publica la actualización en memoria. Los archivos corruptos no se sustituyen silenciosamente por valores iniciales. Las necesidades de compra se deducen de los datos: no se guardan como resultados independientes que puedan quedar desactualizados.

## 10. Demostración en vivo

**Preparación:** usar la [guía rápida](GUIA_EJECUCION.md). Si hay datos importantes, hacer la demostración en una copia de la carpeta y mantener una sola instancia del servidor.

### Parte A: interfaz web

1. Arrancar el servidor y abrir `http://127.0.0.1:8080`.
2. Mostrar las existencias y la lista de compras. Los resultados dependen de los datos guardados; la tabla de esta exposición describe los valores iniciales.
3. Usar croquetas con cantidad **2** y mínimo **5** para mostrar el faltante de **3**.
4. Editar la cantidad a **5** y guardar. Mostrar que desaparece de compras.
5. Detener y volver a abrir el servidor. Comprobar que la cantidad **5** se conserva.
6. Devolver croquetas a **2** si se desea continuar con el ejemplo original.

### Parte B: consultas dentro de Prolog

Detener el servidor. Abrir `swipl` desde la carpeta del proyecto y cargar:

```prolog
[inventario].
cargar_inventario('data/inventario.json').
```

Después ejecutar estas consultas **por separado**:

```prolog
requiere_compra(Producto).
```

```prolog
lista_compras(Producto, Proveedor).
```

```prolog
cantidad_a_comprar(croquetas_perro, Faltante).
```

> El indicador `?-` lo muestra Prolog; no lo escribimos. Cada consulta termina en punto. Con punto y coma pedimos otra solución; con Enter terminamos esa consulta. `false` indica que no existe una solución, por ejemplo, si preguntamos por una compra que no hace falta.

Salir con `halt.`.

## 11. Pruebas, alcance y límites

> No comprobamos únicamente que la pantalla se viera bien. La batería de pruebas cubre lógica, HTTP, recuperación de datos desde otro proceso y el flujo de navegador con edición, errores, foco y estado sin compras pendientes.

Se probó con SWI-Prolog 10.0.2 y Chromium. Las pruebas emplean datos temporales, no el inventario real. Antes de exponer, vuelve a ejecutarlas con las instrucciones del `README.md`; no presentes resultados antiguos como una comprobación de la versión actual.

El alcance actual es local: una persona y un proceso servidor. No incluye cuentas, altas o bajas, edición de proveedores, ventas, precios ni historial. No se ha validado en todos los navegadores ni en dispositivos físicos. El guardado no promete durabilidad transaccional ante cortes eléctricos y no permite varios servidores escribiendo el mismo archivo.

> El producto es un prototipo funcional para demostrar el paradigma lógico y su integración con una interfaz. No lo presentamos como un sistema comercial listo para publicarse en Internet.

## 12. Conclusión y trabajo futuro

> Partimos de hechos y reglas que respondían preguntas en consola. Después separamos responsabilidades, corregimos el arranque, añadimos validación y almacenamiento, y conectamos una interfaz web. El resultado conserva la inferencia en Prolog y permite utilizarla sin conocer su sintaxis.
>
> La principal aportación es mostrar que un programa lógico puede formar parte de una aplicación completa: Prolog resuelve las reglas y otras tecnologías facilitan la interacción.

Como trabajo futuro se pueden definir altas y bajas, registrar movimientos y evaluar una base de datos transaccional si se necesitan ventas o usuarios simultáneos. No son funciones incluidas en esta versión.

## Preguntas que podrían hacernos

**¿Por qué no calcular todo en JavaScript?** Porque el objetivo académico es mantener las reglas y la inferencia en Prolog. Duplicarlas complicaría su mantenimiento.

**¿JSON es el motor del sistema?** No. Es el formato de intercambio y almacenamiento; Prolog sigue ejecutando las reglas.

**¿Qué pasa si un producto tiene exactamente el mínimo?** No requiere compra: la condición es `<`, no `<=`.

**¿Qué pasa si sobran unidades?** No hay una solución de compra para ese producto; el resumen de la interfaz muestra faltante cero.

**¿Prolog solo sirve para consola?** No. SWI-Prolog ofrece bibliotecas web y herramientas gráficas como XPCE. La consola es una forma de consultar el sistema, no su único destino.

**¿Por qué no usamos React o una base de datos externa?** Para este alcance no son necesarios. Una interfaz pequeña y un servidor Prolog cubren la función principal con menos componentes.

**¿Qué cambia al añadir usuarios simultáneos?** Se deben revisar autenticación, conflictos entre actualizaciones, almacenamiento transaccional y despliegue. Esta versión no ofrece esas garantías.
