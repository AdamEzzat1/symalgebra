% Must fail. Proves a failing Prolog test reddens the run.

:- use_module(library(plunit)).

:- begin_tests(sabotage).

test(deliberate) :-
    1 =:= 2.

:- end_tests(sabotage).

main :-
    (   run_tests
    ->  halt(0)
    ;   halt(1)
    ).

:- initialization(main, main).
