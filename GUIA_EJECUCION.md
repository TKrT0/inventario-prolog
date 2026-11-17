# Guía rápida de ejecución

Hay dos lugares donde escribir: **la terminal** y **el intérprete de Prolog**, que muestra `?-`. No son lo mismo.

## 1. Abrir la aplicación web

En la **terminal**, desde la carpeta que contiene el proyecto (omite `cd` si ya estás dentro):

```bash
cd inventario-prolog
swipl -q -s servidor.pl
```

Abre **http://127.0.0.1:8080** en el navegador. No abras el HTML directamente. Mantén esa terminal abierta.

**Si aparece `swipl: command not found`:** instala SWI-Prolog siguiendo `README.md` y vuelve a abrir la terminal.

Para detener la web: **Ctrl+C**; si aparece el menú de SWI-Prolog, escribe **e**. Detén el servidor antes del modo consola siguiente.

## 2. Entrar a Prolog y cargar el inventario

Desde la misma carpeta, en la **terminal**:

```bash
swipl
```

Cuando veas **`?-`**, ya estás dentro de Prolog. **No escribas `?-`: lo pone el programa.** Escribe estas instrucciones, una por una:

```prolog
[inventario].
cargar_inventario('data/inventario.json').
```

La primera carga `inventario.pl`; la segunda carga los datos guardados, o crea los iniciales si todavía no hay archivo. Que aparezca `true` significa que la instrucción se completó.

## 3. Hacer consultas

Escribe **una consulta cada vez**. Después de una respuesta, pulsa **`;`** para pedir otra solución o **Enter** para terminar esa consulta.

**¿Qué productos necesitan compra?**

```prolog
requiere_compra(Producto).
```

**¿Qué producto se compra y a qué proveedor?**

```prolog
lista_compras(Producto, Proveedor).
```

**¿Cuántas croquetas faltan?**

```prolog
cantidad_a_comprar(croquetas_perro, Faltante).
```

Con los datos originales devuelve `Faltante = 3`. Si ya cambiaste las existencias, el resultado puede ser otro o `false` si no hace falta comprar.

**Para salir de Prolog:**

```prolog
halt.
```

**Recuerda:** cada instrucción termina en **punto**. `Producto` es una variable porque empieza con mayúscula; `croquetas_perro` es un producto concreto. `false` significa «no hay una solución para esa consulta», no que el programa se haya roto.

Si aparece `|:`, Prolog espera que termines la instrucción: revisa el punto y los paréntesis.
