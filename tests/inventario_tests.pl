:- use_module(library(plunit)).
:- use_module(library(http/json)).
:- use_module(library(filesex)).
:- use_module(library(process)).
:- use_module('../inventario').

:- begin_tests(inventario,
               [setup((preparar(Archivo), nb_setval(inventario_base, Archivo))),
                cleanup((limpiar(Archivo), nb_delete(inventario_base)))]).

preparar(Archivo) :-
    tmp_file(inventario_test, Archivo),
    cargar_inventario(Archivo).

limpiar(Archivo) :-
    ( exists_file(Archivo) -> delete_file(Archivo) ; true ).

volver_base :-
    nb_getval(inventario_base, Archivo),
    cargar_inventario(Archivo).

test(faltantes_originales) :-
    findall(P-F, cantidad_a_comprar(P, F), Faltantes),
    assertion(Faltantes == [monster_energy-6, croquetas_perro-3,
                           lapiceros_pentel-2, galletas-5]).

test(agua_no_requiere_compra, [fail]) :-
    requiere_compra(agua_embotellada).

test(resumen_completo) :-
    resumen_inventario(Registros),
    length(Registros, 5),
    once((member(Agua, Registros), Agua.producto == agua_embotellada)),
    assertion(Agua.cantidad == 20),
    assertion(Agua.minimo == 15),
    assertion(Agua.faltante == 0),
    assertion(Agua.proveedor == 'Distribuidora Bebidas').

test(minimo_igual_sin_compra) :-
    actualizar_producto(croquetas_perro, 5, 5, Registro),
    assertion(Registro.faltante == 0),
    assertion(\+ requiere_compra(croquetas_perro)),
    actualizar_producto(croquetas_perro, 2, 5, _).

test(actualizacion_persistente) :-
    tmp_file(persistencia_test, Archivo),
    setup_call_cleanup(
        cargar_inventario(Archivo),
        ( actualizar_producto(croquetas_perro, 8, 9, _),
          current_prolog_flag(executable, Ejecutable),
          term_to_atom((cargar_inventario(Archivo),
                        inventario(croquetas_perro, 8),
                        stock_minimo(croquetas_perro, 9), writeln(recuperado)), Objetivo),
          process_create(Ejecutable, ['-q', '-l', 'inventario.pl', '-g', Objetivo, '-t', 'halt'],
                         [stdout(pipe(Salida)), process(Pid)]),
          read_string(Salida, _, Texto), close(Salida), process_wait(Pid, Estado),
          assertion(Estado == exit(0)), assertion(Texto == "recuperado\n") ),
        ( limpiar(Archivo), volver_base )).

test(rechaza_negativo) :- rechazo_sin_cambios(-1, 5).
test(rechaza_decimal) :- rechazo_sin_cambios(1.5, 5).
test(rechaza_entero_inseguro) :- rechazo_sin_cambios(9007199254740992, 5).
test(rechaza_minimo_negativo) :- rechazo_sin_cambios(2, -1).

rechazo_sin_cambios(Cantidad, Minimo) :-
    resumen_inventario(Antes),
    nb_getval(inventario_base, Archivo),
    read_file_to_string(Archivo, DatosAntes, []),
    catch(actualizar_producto(croquetas_perro, Cantidad, Minimo, _), Error, true),
    assertion(nonvar(Error)),
    resumen_inventario(Despues), assertion(Antes =@= Despues),
    read_file_to_string(Archivo, DatosDespues, []),
    assertion(DatosAntes == DatosDespues).

test(producto_desconocido_no_se_crea) :-
    catch(actualizar_producto(no_existe, 1, 2, _), Error, true),
    assertion(Error = error(existence_error(producto, no_existe), _)),
    assertion(\+ inventario(no_existe, _)).

test(lista_agregada) :-
    compras(Lista),
    findall(P-C, (member(R, Lista), P = R.producto, C = R.cantidad), Pares),
    assertion(Pares == [monster_energy-6, croquetas_perro-3,
                       lapiceros_pentel-2, galletas-5]),
    assertion(lista_compras(galletas, 'Gamesa')).

test(carga_corrupta_no_sobrescribe) :- carga_rechazada("{invalid").
test(carga_incompleta_no_sobrescribe) :- carga_rechazada("[]").
test(carga_duplicada_no_sobrescribe) :-
    carga_rechazada("[{\"producto\":\"x\",\"cantidad\":1,\"minimo\":2,\"proveedor\":\"A\"},{\"producto\":\"x\",\"cantidad\":1,\"minimo\":2,\"proveedor\":\"A\"}]").

carga_rechazada(Texto) :-
    resumen_inventario(Antes),
    tmp_file(carga_test, Archivo),
    setup_call_cleanup(
        open(Archivo, write, Salida, [encoding(utf8)]),
        write(Salida, Texto), close(Salida)),
    setup_call_cleanup(
        true,
        ( catch(cargar_inventario(Archivo), Error, true),
          assertion(nonvar(Error)),
          read_file_to_string(Archivo, Conservado, []),
          assertion(Conservado == Texto),
          resumen_inventario(Despues), assertion(Antes =@= Despues) ),
        limpiar(Archivo)).

test(fallo_escritura_conserva_estado) :-
    tmp_file(escritura_test, Directorio),
    make_directory(Directorio),
    directory_file_path(Directorio, 'datos.json', Archivo),
    setup_call_cleanup(
        cargar_inventario(Archivo),
        ( resumen_inventario(Antes),
          delete_file(Archivo), delete_directory(Directorio),
          catch(actualizar_producto(croquetas_perro, 100, 5, _), Error, true),
          assertion(nonvar(Error)),
          resumen_inventario(Despues), assertion(Antes =@= Despues) ),
        ( ( exists_directory(Directorio) -> delete_directory_and_contents(Directorio) ; true ),
          volver_base )).

test(importar_no_ejecuta_demo_ni_termina) :-
    current_prolog_flag(executable, Ejecutable),
    process_create(Ejecutable,
                   ['-q', '-s', 'inventario.pl', '-g', 'writeln(importado)', '-t', 'halt'],
                   [stdout(pipe(Salida)), process(Pid)]),
    read_string(Salida, _, Texto), close(Salida),
    process_wait(Pid, Estado),
    assertion(Estado == exit(0)),
    assertion(Texto == "importado\n").

:- end_tests(inventario).
