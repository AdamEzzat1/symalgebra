% M0 smoke test: run with swipl from the repository root.

:- use_module('../hello').
:- use_module(library(plunit)).

:- begin_tests(hello).

test(greets, [true(X == hello(1))]) :-
    hello(X).

test(rationals_stay_off) :-
    current_prolog_flag(prefer_rationals, false).

:- end_tests(hello).

main :-
    findall(N, clause(plunit_hello:'unit body'(N, _), _), Ids),
    length(Ids, Ran),
    (   run_tests
    ->  format("COUNT prolog ran=~d passed=~d~n", [Ran, Ran]),
        halt(0)
    ;   format("COUNT prolog ran=~d passed=0~n", [Ran]),
        halt(1)
    ).

:- initialization(main, main).
