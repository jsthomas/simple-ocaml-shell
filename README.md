# simple-ocaml-shell

This repo implements a simple shell (`osh`) in OCaml. I wrote it in
June of 2021, while I was at the [Recurse
Center](https://www.recurse.com/), in order to learn more about
systems programming in a strongly-typed functional programming
language.

## How do I build and test the project?

Assuming you have `dune` [installed](https://dune.build/install), you
should be able to build the shell by running

```
dune build
mv _build/default/osh.exe osh
```

I built this project using version 4.11.1 of the compiler.


The second command isn't strictly necessary, I just prefer to use the
program without it's default `.exe` extension.

After building, you can run the tests like this: `./test-osh.sh`.

## Example Run

`osh` has both an interactive and a batch mode. Here is an example of the interactive mode:
```
jthomas@raven:~/repos/simple-ocaml-shell$ ./osh
osh> ls
 _build   dune	 dune-project   example.sh   LICENSE   osh   osh.ml  '#README.md#'   README.md	 test-osh.sh   tests
osh> echo "Hello World!" > world.txt
osh> cat world.txt
"Hello World!"
osh> pwd & echo "That's the working directory, alright."
/home/jthomas/repos/simple-ocaml-shell
"That's the working directory, alright."
osh>
```

As with more full-featured shells, `osh` supports the ability to
redirect output (using `>`) and run several commands in parallel
(using `&`). For simplicity, `>` redirects both `stdout` and `stderr`
to the same file.

`osh` can be run in batch mode like this `osh <my file of shell commands>`.

Because `osh` doesn't support environment variables, it has some
peculiar builtins. The `path` builtin allows you to set one or more
locations where executables can be found. For example:

```
osh> ls
_build	dune  dune-project  example.sh	LICENSE  osh  osh.ml  README.md  test-osh.sh  tests  world.txt
osh> path
osh> ls
An error has occurred
osh> path /usr/bin /bin
osh> ls
 _build   dune	 dune-project   example.sh   LICENSE   osh   osh.ml  '#README.md#'   README.md	 test-osh.sh   tests   world.txt
```

This example illustrates another simplification: `osh` does not show
detailed output when an error occurs (in this case, `ls` was not
found).

## Background

The design and tests for this project come from the book [Operating
Systems: Three Easy Pieces](https://pages.cs.wisc.edu/~remzi/OSTEP/)
by Remzi H. Arpaci-Dusseau and Andrea C. Arpaci-Dusseau. You can find
the original project description
[here](https://github.com/remzi-arpacidusseau/ostep-projects/tree/master/processes-shell).

Normally, I wouldn't post solutions to exercises from a
class. However, that most classes will use C for this type of project,
I don't think I'm creating much of an opportunity for cheating by
posting an OCaml implementation.
