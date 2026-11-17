"use strict";

const $ = (id) => document.getElementById(id);
let productos = [];
let seleccionado = null;
let ocupado = false;

function nombre(producto) {
  const texto = producto.replaceAll("_", " ");
  return texto[0].toUpperCase() + texto.slice(1);
}

function elemento(etiqueta, texto, clase) {
  const nodo = document.createElement(etiqueta);
  if (texto !== undefined) nodo.textContent = texto;
  if (clase) nodo.className = clase;
  return nodo;
}

function mostrarError(id, mensaje = "") {
  $(id).textContent = mensaje;
  $(id).hidden = !mensaje;
}

function establecerOcupado(valor) {
  ocupado = valor;
  $("actualizar").disabled = valor;
  $("campos").disabled = valor;
  document.querySelectorAll("button[data-producto]").forEach((boton) => { boton.disabled = valor; });
  $("inventario-body").setAttribute("aria-busy", String(valor));
}

async function solicitar(ruta, opciones = {}) {
  let respuesta;
  try {
    respuesta = await fetch(ruta, { ...opciones, signal: AbortSignal.timeout(10000) });
  } catch {
    throw new Error("No se pudo confirmar la operación. Comprueba la conexión y pulsa Actualizar antes de repetir.");
  }
  const datos = await respuesta.json();
  if (!respuesta.ok) throw new Error(datos.error || "No se pudo completar la operación.");
  return datos;
}

function pintarInventario() {
  const filas = productos.map((producto) => {
    const fila = elemento("tr");
    fila.classList.toggle("seleccionado", producto.producto === seleccionado);
    const titulo = elemento("th", nombre(producto.producto));
    titulo.scope = "row";
    fila.append(titulo, elemento("td", producto.cantidad, "numero"), elemento("td", producto.minimo, "numero"));
    const estado = elemento("td");
    const falta = producto.faltante > 0;
    estado.append(elemento("span", falta ? `${producto.faltante} por comprar` : "Suficiente",
                          `estado-producto ${falta ? "faltante" : "suficiente"}`));
    const accion = elemento("td");
    const boton = elemento("button", "Editar", "editar");
    boton.type = "button";
    boton.dataset.producto = producto.producto;
    boton.disabled = ocupado;
    boton.setAttribute("aria-label", `Editar ${nombre(producto.producto)}`);
    boton.setAttribute("aria-controls", "editor");
    boton.setAttribute("aria-expanded", String(producto.producto === seleccionado));
    boton.addEventListener("click", () => editar(producto));
    accion.append(boton);
    fila.append(estado, accion);
    return fila;
  });
  $("inventario-body").replaceChildren(...filas);
  $("conteo-productos").textContent = `${productos.length} productos`;
}

function pintarCompras(compras) {
  const filas = compras.map((compra) => {
    const fila = elemento("tr");
    const producto = elemento("th", nombre(compra.producto));
    producto.scope = "row";
    producto.append(elemento("small", compra.proveedor));
    fila.append(producto, elemento("td", compra.cantidad, "numero"));
    return fila;
  });
  $("compras-body").replaceChildren(...filas);
  $("conteo-compras").textContent = `${compras.length} pendientes`;
  $("sin-compras").hidden = compras.length !== 0;
  $("sin-compras").previousElementSibling.hidden = compras.length === 0;
}

async function consultar() {
  const [inventario, compras] = await Promise.all([
    solicitar("/api/inventario"), solicitar("/api/compras"),
  ]);
  productos = inventario;
  pintarInventario();
  pintarCompras(compras);
  mostrarError("error-general");
}

async function cargar() {
  if (ocupado) return;
  establecerOcupado(true);
  $("estado").textContent = "Actualizando inventario…";
  try {
    await consultar();
    $("estado").textContent = "Inventario actualizado.";
  } catch (error) {
    $("estado").textContent = "No se pudo actualizar el inventario.";
    mostrarError("error-general", `${error.message} Pulsa Actualizar para volver a cargar.`);
  } finally {
    establecerOcupado(false);
  }
}

function editar(producto) {
  seleccionado = producto.producto;
  $("titulo-editor").textContent = `Editar ${nombre(seleccionado)}`;
  $("proveedor-editor").textContent = `Proveedor: ${producto.proveedor}`;
  $("cantidad").value = producto.cantidad;
  $("minimo").value = producto.minimo;
  mostrarError("error-formulario");
  $("editor").hidden = false;
  pintarInventario();
  $("cantidad").focus();
}

function cerrarEditor() {
  const anterior = seleccionado;
  seleccionado = null;
  $("editor").hidden = true;
  pintarInventario();
  document.querySelector(`button[data-producto="${anterior}"]`)?.focus();
}

$("formulario").addEventListener("submit", async (evento) => {
  evento.preventDefault();
  if (ocupado || !seleccionado) return;
  const cantidad = Number($("cantidad").value);
  const minimo = Number($("minimo").value);
  if (![cantidad, minimo].every((valor) => Number.isSafeInteger(valor) && valor >= 0)) {
    mostrarError("error-formulario", "Usa cantidades enteras no negativas dentro del rango permitido.");
    return;
  }
  establecerOcupado(true);
  mostrarError("error-formulario");
  $("guardar").textContent = "Guardando…";
  let guardado = false;
  try {
    await solicitar(`/api/inventario/${encodeURIComponent(seleccionado)}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cantidad, minimo }),
    });
    guardado = true;
    await consultar();
    $("estado").textContent = "Cambios guardados. La lista de compras está actualizada.";
  } catch (error) {
    if (guardado) {
      $("estado").textContent = "Cambios guardados; falta volver a cargar la lista.";
      mostrarError("error-general", "El guardado se completó. Pulsa Actualizar para recuperar los datos nuevos.");
    } else {
      mostrarError("error-formulario", error.message);
    }
  } finally {
    establecerOcupado(false);
    $("guardar").textContent = "Guardar cambios";
    if (guardado) cerrarEditor();
    else $("guardar").focus();
  }
});

$("cancelar").addEventListener("click", cerrarEditor);
$("actualizar").addEventListener("click", cargar);
cargar();
