let print_error () =
  Printf.fprintf stderr "An error has occurred\n";
  flush stderr


type exec = {
  executable: string;
  arguments: string list;
  output: string option;
}


type line =
  | NoOp
  | ChangeDirectory of string
  | PathChange of string list
  | Executable of exec list
  | Quit


module Parser = struct
  open Angstrom

  let is_whitespace = function
  | '\x20' | '\x0a' | '\x0d' | '\x09' -> true
  | _ -> false

  let is_token_char = function
    | '&' | '>' -> false
    | x -> not @@ is_whitespace x

  let ws = take_while is_whitespace
  let token = take_while1 is_token_char  <* ws
    >>= (fun tok ->
        if tok = "cd" then fail "cd is not a valid token"
        else return tok
      )

  let amp = char '&' <* ws
  let redir = char '>' <* ws
  let quit = string "exit" <* ws
  let cd = string "cd" <* ws
  let path = string "path" <* ws

  let exec_parser =
    many token >>= (fun tokens -> match tokens with
        | [] -> return @@ None
        | executable::arguments ->
          choice [
            redir *> token >>= (fun filename ->
                return @@ Some {executable; arguments; output=Some filename});
            return @@ Some {executable; arguments; output=None}
          ]
        )

  let shell_parser =
    choice [
      quit *> return Quit;
      cd *> token >>= (fun dir -> return @@ ChangeDirectory dir);
      path *> many token >>= (fun paths -> return @@ PathChange paths);
      sep_by amp exec_parser >>= (
        fun execs ->
          let notnulls = List.filter Option.is_some execs in
          let values = List.map Option.get notnulls in
          return @@ Executable values
      )
    ]

  let parse_line l =
    match String.trim l with
    | "" -> Result.Ok NoOp
    | trimmed -> Angstrom.parse_string ~consume:All shell_parser trimmed
end


let prompt_stream =
  let f _ =
    Printf.printf "osh> ";
    try
      Some (read_line ())
    with End_of_file -> exit 0
  in
  Stream.from f


let file_stream filename =
  let in_channel =
    try
      open_in filename
    with Sys_error _ ->
      (* If the batch file isn't present, bail. *)
      print_error ();
      exit 1
  in
  let f _ =
    try
      Some (input_line in_channel)
    with End_of_file -> close_in in_channel; None
  in
  Stream.from f


let change_directory dirname =
  try
    Unix.chdir dirname
  with _ ->
    print_error ()


let executable_present full_path =
  try
    Unix.access full_path [Unix.X_OK];
    true
  with _ ->
    false


let run_executable path {executable; arguments; output} =
  let full_paths = List.map (fun p -> p ^ "/" ^ executable) path in
  let executables = List.append full_paths [executable] in
  let present = List.filter executable_present executables in

  match present with
  | [] -> print_error (); None
  | x :: _ ->
    match Unix.fork () with
    | 0 -> (* Child *)
       (* Printf.printf "Launching %s, Arguments: %s, Output: %s\n"
          x (String.concat ", " (executable::arguments)) (Option.value ~default:"None" output);
          flush stdout;
       *)
       let out = match output with
         | Some filename -> Unix.openfile filename [Unix.O_TRUNC; Unix.O_WRONLY; Unix.O_CREAT ] 0o640
         | None -> Unix.stdout
       in
       let err = match output with
         | None -> Unix.stderr
         | _ -> out
       in
       Unix.dup2 out Unix.stdout;
       Unix.dup2 err Unix.stderr;
       Unix.execv x @@ Array.of_list @@ executable::arguments;
    | child_pid -> (* Parent *)
      Some child_pid


let run_executables path execs =
  let wait p = match p with
    | None -> ()
    | Some pid ->
      (* Printf.printf "Waiting on %d." pid;
       * flush stdout; *)
      let _ = Unix.waitpid [] pid in
      ()
  in
  List.iter wait @@ List.map (run_executable path) execs


let amend_path cwd p =
  if '/' == String.get p 0
  then p
  else cwd ^ "/" ^ p


let main stream =
  let path = ref ["/bin"] in
  let process text =
    match Parser.parse_line text with
    | Error _ -> print_error ()
    | Ok (NoOp) -> () (* Empty lines should just be treated as no-ops. *)
    | Ok (Quit) -> exit 0
    | Ok (ChangeDirectory x) -> change_directory x
    | Ok (PathChange paths) ->
      let cwd = Unix.getcwd () in
      path := List.map (amend_path cwd) paths
    | Ok (Executable execs) -> run_executables !path execs
  in
  Stream.iter process stream


let () =
  match Array.to_list Sys.argv with
  | _ :: [] -> main prompt_stream
  | _ :: filename :: [] -> main @@ file_stream filename
  | _ -> print_error ();
    exit 1
