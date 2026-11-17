:- use_module(library(plunit)).
:- use_module(library(http/http_open)).
:- use_module(library(http/json)).
:- use_module('../servidor').

:- begin_tests(servidor, [setup(preparar_servidor), cleanup(limpiar_servidor)]).

preparar_servidor :-
    tmp_file(http_test, Archivo),
    iniciar_servidor(Puerto, Archivo),
    nb_setval(http_puerto, Puerto), nb_setval(http_archivo, Archivo).

limpiar_servidor :-
    nb_getval(http_puerto, Puerto), detener_servidor(Puerto),
    nb_getval(http_archivo, Archivo), delete_file(Archivo),
    nb_delete(http_puerto), nb_delete(http_archivo).

peticion(Metodo, Ruta, Cuerpo, Cabeceras, Estado, Datos) :-
    nb_getval(http_puerto, Puerto),
    format(atom(URL), 'http://127.0.0.1:~d~w', [Puerto, Ruta]),
    ( Cuerpo == sin_cuerpo -> Envio = []
    ; Envio = [post(string('application/json', Cuerpo))] ),
    append([method(Metodo), status_code(Estado), timeout(5)|Cabeceras], Envio, Opciones),
    setup_call_cleanup(http_open(URL, Entrada, Opciones),
                       json_read_dict(Entrada, Datos, [value_string_as(atom)]),
                       close(Entrada)).

test(get_inventario) :-
    peticion(get, '/api/inventario', sin_cuerpo, [], Estado, Datos),
    assertion(Estado == 200), assertion(length(Datos, 5)),
    once((member(R, Datos), R.producto == croquetas_perro)),
    assertion(R.cantidad == 2), assertion(R.faltante == 3).

test(get_compras) :-
    peticion(get, '/api/compras', sin_cuerpo, [], Estado, Datos),
    assertion(Estado == 200),
    findall(P-C, (member(R, Datos), P=R.producto, C=R.cantidad), Pares),
    assertion(Pares == [monster_energy-6, croquetas_perro-3,
                       lapiceros_pentel-2, galletas-5]).

test(put_actualiza) :-
    peticion(put, '/api/inventario/croquetas_perro', '{"cantidad":5,"minimo":5}', [], Estado, R),
    assertion(Estado == 200), assertion(R.faltante == 0),
    peticion(get, '/api/compras', sin_cuerpo, [], 200, Lista),
    assertion(length(Lista, 3)),
    nb_getval(http_archivo, Archivo),
    read_file_to_string(Archivo, Guardado, []),
    atom_json_dict(Guardado, Filas, [value_string_as(atom)]),
    once((member(F, Filas), F.producto == croquetas_perro)),
    assertion(F.cantidad == 5),
    peticion(put, '/api/inventario/croquetas_perro', '{"cantidad":2,"minimo":5}', [], 200, _).

test(json_invalido) :- rechazo('{broken', [], 400).
test(json_con_sufijo) :- rechazo('{"cantidad":2,"minimo":5} basura', [], 400).
test(campo_extra) :- rechazo('{"cantidad":2,"minimo":5,"consulta":"halt"}', [], 400).
test(campo_ausente) :- rechazo('{"cantidad":2}', [], 400).
test(numero_negativo) :- rechazo('{"cantidad":-1,"minimo":5}', [], 400).
test(numero_decimal) :- rechazo('{"cantidad":2.5,"minimo":5}', [], 400).
test(origen_ajeno) :-
    rechazo('{"cantidad":2,"minimo":5}', [request_header('Origin'='https://evil.example')], 403).
test(host_ajeno) :-
    rechazo('{"cantidad":2,"minimo":5}', [request_header('Host'='evil.example')], 403).

rechazo(Cuerpo, Cabeceras, EstadoEsperado) :-
    peticion(get, '/api/inventario', sin_cuerpo, [], 200, Antes),
    nb_getval(http_archivo, Archivo), read_file_to_string(Archivo, ArchivoAntes, []),
    peticion(put, '/api/inventario/croquetas_perro', Cuerpo, Cabeceras, Estado, Error),
    assertion(Estado == EstadoEsperado), assertion(get_dict(error, Error, _)),
    peticion(get, '/api/inventario', sin_cuerpo, [], 200, Despues),
    assertion(Antes =@= Despues),
    read_file_to_string(Archivo, ArchivoDespues, []), assertion(ArchivoAntes == ArchivoDespues).

test(producto_desconocido) :-
    peticion(put, '/api/inventario/no_existe', '{"cantidad":1,"minimo":2}', [], Estado, _),
    assertion(Estado == 404).

test(metodo_incorrecto) :-
    peticion(post, '/api/inventario', '{}', [], Estado, _),
    assertion(Estado == 405).

test(cuerpo_excesivo) :-
    length(Codigos, 4100), maplist(=(0'x), Codigos), string_codes(Cuerpo, Codigos),
    rechazo(Cuerpo, [], 400).

test(ruta_privada) :-
    forall(member(Ruta, ['/inventario.pl', '/data/inventario.json', '/web/../inventario.pl']),
           (peticion(get, Ruta, sin_cuerpo, [], Estado, _), assertion(Estado == 404))).

test(origen_local_permitido) :-
    nb_getval(http_puerto, Puerto), format(atom(Origen), 'http://127.0.0.1:~d', [Puerto]),
    peticion(put, '/api/inventario/croquetas_perro', '{"cantidad":2,"minimo":5}',
             [request_header('Origin'=Origen)], Estado, _),
    assertion(Estado == 200).

test(html_no_admite_iframes) :-
    nb_getval(http_puerto, Puerto),
    format(atom(URL), 'http://127.0.0.1:~d/', [Puerto]),
    setup_call_cleanup(
        http_open(URL, Entrada,
                  [header(content_security_policy, CSP), header(x_frame_options, XFO)]),
        read_string(Entrada, _, _),
        close(Entrada)),
    assertion(CSP == 'frame-ancestors \'none\''),
    assertion(XFO == 'DENY').

test(fallo_guardado_http) :-
    nb_getval(http_archivo, Archivo), atom_concat(Archivo, '.backup', Copia),
    rename_file(Archivo, Copia), make_directory(Archivo),
    setup_call_cleanup(
        true,
        ( peticion(get, '/api/inventario', sin_cuerpo, [], 200, Antes),
          peticion(put, '/api/inventario/croquetas_perro', '{"cantidad":100,"minimo":5}', [], Estado, _),
          assertion(Estado == 500),
          peticion(get, '/api/inventario', sin_cuerpo, [], 200, Despues),
          assertion(Antes =@= Despues) ),
        (delete_directory(Archivo), rename_file(Copia, Archivo))).

:- end_tests(servidor).
