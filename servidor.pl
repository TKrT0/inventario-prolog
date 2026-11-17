:- module(servidor, [iniciar_servidor/2, detener_servidor/1]).

:- use_module(inventario).
:- use_module(library(error)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_client), [http_read_data/3]).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_json)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(option)).
:- use_module(library(pairs)).

:- dynamic puerto_servidor/1.
:- http_handler(root(.), manejar, [prefix]).
:- initialization(main, main).

iniciar_servidor(Puerto, Archivo) :-
    cargar_inventario(Archivo),
    http_server(http_dispatch, [port('127.0.0.1':Puerto), silent(true)]),
    assertz(puerto_servidor(Puerto)).

detener_servidor(Puerto) :-
    http_stop_server(Puerto, []),
    retractall(puerto_servidor(Puerto)).

main :-
    source_file(iniciar_servidor(_, _), Fuente),
    file_directory_name(Fuente, Directorio),
    directory_file_path(Directorio, 'data/inventario.json', Archivo),
    iniciar_servidor(8080, Archivo),
    format('Inventario disponible en http://127.0.0.1:8080~n'),
    thread_get_message(_).

manejar(Request) :-
    catch((validar_acceso(Request), responder(Request)), Error, responder_error(Error)).

validar_acceso(Request) :-
    ( findall(H, member(host(H), Request), [Host]),
      memberchk(Host, ['127.0.0.1', localhost]),
      option(port(Puerto), Request, 80),
      puerto_servidor(Puerto)
    -> true
    ;  error_api(403, 'Host no permitido.')
    ),
    findall(O, member(origin(O), Request), Origenes),
    format(atom(Esperado), 'http://~w:~d', [Host, Puerto]),
    ( ( Origenes == [] ; Origenes == [Esperado] )
    -> true
    ;  error_api(403, 'Origen no permitido.')
    ).

responder(Request) :-
    memberchk(path(Ruta), Request),
    ( Ruta == '/api/inventario'
    -> exigir_metodo(get, Request), resumen_inventario(Datos), json(Datos)
    ; Ruta == '/api/compras'
    -> exigir_metodo(get, Request), compras(Datos), json(Datos)
    ; atom_concat('/api/inventario/', Producto, Ruta)
    -> exigir_metodo(put, Request), leer_actualizacion(Request, Cantidad, Minimo),
       actualizar_producto(Producto, Cantidad, Minimo, Registro), json(Registro)
    ; archivo_web(Ruta, Nombre)
    -> exigir_metodo(get, Request),
       source_file(iniciar_servidor(_, _), Fuente),
       file_directory_name(Fuente, Directorio),
       directory_file_path(Directorio, web, Web),
       directory_file_path(Web, Nombre, Archivo),
       http_reply_file(Archivo,
                       [unsafe(true),
                        headers([content_security_policy('frame-ancestors \'none\''),
                                 x_frame_options('DENY')])], Request)
    ; error_api(404, 'Recurso no encontrado.')
    ).

archivo_web('/', 'index.html').
archivo_web('/styles.css', 'styles.css').
archivo_web('/app.js', 'app.js').

exigir_metodo(Metodo, Request) :-
    ( memberchk(method(Metodo), Request)
    -> true
    ; throw(error(metodo_no_permitido(Metodo), _))
    ).

leer_actualizacion(Request, Cantidad, Minimo) :-
    ( memberchk(content_length(Longitud), Request),
      integer(Longitud), between(1, 4096, Longitud),
      \+ memberchk(transfer_encoding(_), Request)
    -> true
    ;  error_api(400, 'El cuerpo JSON debe tener entre 1 y 4096 bytes.')
    ),
    ( memberchk(content_type(Tipo), Request),
      atomic_list_concat([Base|_], ';', Tipo),
      normalize_space(atom(Normalizado), Base),
      downcase_atom(Normalizado, 'application/json')
    -> true
    ;  error_api(400, 'Se requiere Content-Type: application/json.')
    ),
    http_read_data(Request, Texto, [to(atom)]),
    atom_string(Texto, Cadena),
    setup_call_cleanup(
        open_string(Cadena, Entrada),
        ( json_read_dict(Entrada, Datos),
          read_string(Entrada, _, Resto),
          ( normalize_space(string(""), Resto)
          -> true
          ;  error_api(400, 'El cuerpo debe contener un único objeto JSON.')
          ) ),
        close(Entrada)),
    must_be(dict, Datos),
    dict_pairs(Datos, _, Pares), pairs_keys(Pares, Claves),
    ( Claves == [cantidad, minimo]
    -> Cantidad = Datos.cantidad, Minimo = Datos.minimo
    ;  error_api(400, 'Envía únicamente cantidad y minimo.')
    ).

json(Datos) :-
    format('Cache-Control: no-store~n'),
    reply_json_dict(Datos).

error_api(Estado, Mensaje) :- throw(error(api(Estado, Mensaje), _)).

responder_error(Error) :-
    ( compound(Error), compound_name_arity(Error, http_reply, _)
    -> throw(Error)
    ; Error = error(api(Estado, Mensaje), _)
    -> reply_json_dict(_{error:Mensaje}, [status(Estado)])
    ; Error = error(metodo_no_permitido(Metodo), _)
    -> upcase_atom(Metodo, Permitido), format('Allow: ~w~n', [Permitido]),
       reply_json_dict(_{error:'Método no permitido.'}, [status(405)])
    ; Error = error(existence_error(producto, _), _)
    -> reply_json_dict(_{error:'Producto no encontrado.'}, [status(404)])
    ; error_de_entrada(Error)
    -> reply_json_dict(_{error:'Datos inválidos: usa enteros no negativos.'}, [status(400)])
    ; format(user_error, 'Inventario: ~p~n', [Error]),
      reply_json_dict(_{error:'No se pudo completar la operación. Los datos no se han actualizado.'},
                      [status(500)])
    ).

error_de_entrada(error(type_error(_, _), _)).
error_de_entrada(error(domain_error(_, _), _)).
error_de_entrada(error(syntax_error(_), _)).
error_de_entrada(error(instantiation_error, _)).
