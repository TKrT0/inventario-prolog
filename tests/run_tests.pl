:- use_module(library(plunit)).
:- ensure_loaded(inventario_tests).
:- ensure_loaded(servidor_tests).

:- initialization(main, main).

main :-
    ( run_tests -> halt(0) ; halt(1) ).
