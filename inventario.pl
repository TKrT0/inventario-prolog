:- module(inventario,
          [ inventario/2,
            stock_minimo/2,
            proveedor/2,
            requiere_compra/1,
            lista_compras/2,
            cantidad_a_comprar/2,
            cargar_inventario/1,
            resumen_inventario/1,
            compras/1,
            actualizar_producto/4
          ]).

:- use_module(library(error)).
:- use_module(library(filesex)).
:- use_module(library(http/json)).
:- use_module(library(pairs)).
:- use_module(library(uuid)).

:- dynamic producto/4, archivo_datos/1.

% Los datos iniciales conservan los valores del proyecto académico.
inicial(monster_energy, 4, 10, 'Distribuidora Bebidas').
inicial(croquetas_perro, 2, 5, 'Veterinaria Central').
inicial(lapiceros_pentel, 1, 3, 'Papelería Local').
inicial(agua_embotellada, 20, 15, 'Distribuidora Bebidas').
inicial(galletas, 5, 10, 'Gamesa').

inventario(Producto, Cantidad) :- producto(Producto, Cantidad, _, _).
stock_minimo(Producto, Minimo) :- producto(Producto, _, Minimo, _).
proveedor(Producto, Proveedor) :- producto(Producto, _, _, Proveedor).

cantidad_a_comprar(Producto, Faltante) :-
    producto(Producto, Cantidad, Minimo, _),
    Cantidad < Minimo,
    Faltante is Minimo - Cantidad.

requiere_compra(Producto) :- cantidad_a_comprar(Producto, _).

lista_compras(Producto, Proveedor) :-
    producto(Producto, Cantidad, Minimo, Proveedor),
    Cantidad < Minimo.

%% cargar_inventario(+Archivo) is det.
% Un archivo inválido nunca reemplaza los datos ni el estado activo.
cargar_inventario(Archivo) :-
    must_be(atom, Archivo),
    absolute_file_name(Archivo, Absoluto, [access(none)]),
    with_mutex(inventario,
               ( ( exists_file(Absoluto)
                 -> leer_datos(Absoluto, Productos)
                 ;  findall(producto(P, C, M, V), inicial(P, C, M, V), Productos),
                    file_directory_name(Absoluto, Directorio),
                    make_directory_path(Directorio),
                    guardar_datos(Absoluto, Productos)
                 ),
                 transaction((retractall(producto(_, _, _, _)),
                              maplist(assertz, Productos),
                              retractall(archivo_datos(_)),
                              assertz(archivo_datos(Absoluto)))) )).

resumen_inventario(Registros) :-
    with_mutex(inventario,
               findall(Registro,
                       (producto(P, C, M, V), registro(P, C, M, V, Registro)),
                       Registros)).

compras(Registros) :-
    with_mutex(inventario,
               findall(_{producto:P, proveedor:V, cantidad:F},
                       (producto(P, C, M, V), C < M, F is M - C),
                       Registros)).

actualizar_producto(Producto, Cantidad, Minimo, Registro) :-
    must_be(atom, Producto),
    validar_cantidad(Cantidad),
    validar_cantidad(Minimo),
    with_mutex(inventario,
               ( ( producto(Producto, _, _, Proveedor)
                 -> true
                 ;  existence_error(producto, Producto)
                 ),
                 findall(producto(P, C, M, V), producto(P, C, M, V), Antes),
                 maplist(reemplazar(Producto, Cantidad, Minimo), Antes, Despues),
                 archivo_datos(Archivo),
                 guardar_datos(Archivo, Despues),
                 transaction((retractall(producto(_, _, _, _)),
                              maplist(assertz, Despues))),
                 registro(Producto, Cantidad, Minimo, Proveedor, Registro) )).

registro(P, C, M, V, _{producto:P, cantidad:C, minimo:M, proveedor:V, faltante:F}) :-
    F is max(0, M - C).

reemplazar(P, C, M, producto(P0, C0, M0, V), producto(P0, C1, M1, V)) :-
    ( P == P0 -> C1 = C, M1 = M ; C1 = C0, M1 = M0 ).

validar_cantidad(Cantidad) :-
    must_be(integer, Cantidad),
    ( between(0, 9007199254740991, Cantidad)
    -> true
    ;  domain_error(cantidad_no_negativa_segura, Cantidad)
    ).

leer_datos(Archivo, Productos) :-
    setup_call_cleanup(
        open(Archivo, read, Entrada, [encoding(utf8)]),
        ( json_read_dict(Entrada, Datos),
          read_string(Entrada, _, Resto),
          ( normalize_space(string(""), Resto)
          -> true
          ;  domain_error(inventario_json, Resto)
          ) ),
        close(Entrada)),
    must_be(list, Datos),
    maplist(validar_registro, Datos, Productos),
    findall(P, member(producto(P, _, _, _), Productos), Ids),
    findall(P, inicial(P, _, _, _), Esperados),
    msort(Ids, Ordenados), msort(Esperados, OrdenEsperado),
    ( Ordenados == OrdenEsperado -> true ; domain_error(productos_del_inventario, Ids) ).

validar_registro(Dato, producto(P, C, M, V)) :-
    must_be(dict, Dato),
    dict_pairs(Dato, _, Pares),
    pairs_keys(Pares, Claves),
    ( Claves == [cantidad, minimo, producto, proveedor]
    -> true
    ;  domain_error(registro_inventario, Dato)
    ),
    C = Dato.cantidad, M = Dato.minimo,
    validar_cantidad(C), validar_cantidad(M),
    texto_no_vacio(Dato.producto, P),
    texto_no_vacio(Dato.proveedor, V).

texto_no_vacio(Texto, Atomo) :-
    must_be(string, Texto),
    string_length(Texto, Longitud),
    ( between(1, 120, Longitud) -> atom_string(Atomo, Texto) ; domain_error(texto, Texto) ).

guardar_datos(Archivo, Productos) :-
    file_directory_name(Archivo, Directorio),
    uuid(Id), directory_file_path(Directorio, Id, TemporalDir),
    directory_file_path(TemporalDir, 'inventario.json', Temporal),
    % Crear el directorio es exclusivo y mantiene el renombrado en el mismo volumen.
    setup_call_cleanup(
        make_directory(TemporalDir),
        ( maplist(dato_json, Productos, Datos),
          setup_call_cleanup(
              open(Temporal, write, Salida, [encoding(utf8)]),
              (json_write_dict(Salida, Datos, [width(0)]), nl(Salida)),
              close(Salida)),
          rename_file(Temporal, Archivo) ),
        ( ( exists_file(Temporal) -> delete_file(Temporal) ; true ),
          delete_directory(TemporalDir) )).

dato_json(producto(P, C, M, V), _{producto:P, cantidad:C, minimo:M, proveedor:V}).
