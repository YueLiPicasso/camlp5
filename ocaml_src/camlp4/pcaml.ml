(* camlp4r pa_extend.cmo *)
(***********************************************************************)
(*                                                                     *)
(*                             Camlp4                                  *)
(*                                                                     *)
(*                Daniel de Rauglaudre, INRIA Rocquencourt             *)
(*                                                                     *)
(*  Copyright 2007 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* This file has been generated by program: do not edit! *)

let version = "4.02-exp";;
let syntax_name = ref "";;

let gram =
  Grammar.gcreate
    {Token.tok_func = (fun _ -> failwith "no loaded parsing module");
     Token.tok_using = (fun _ -> ()); Token.tok_removing = (fun _ -> ());
     Token.tok_match = (fun _ -> raise (Match_failure ("pcaml.ml", 22, 23)));
     Token.tok_text = (fun _ -> ""); Token.tok_comm = None}
;;

let interf = Grammar.Entry.create gram "interf";;
let implem = Grammar.Entry.create gram "implem";;
let top_phrase = Grammar.Entry.create gram "top_phrase";;
let use_file = Grammar.Entry.create gram "use_file";;
let sig_item = Grammar.Entry.create gram "sig_item";;
let str_item = Grammar.Entry.create gram "str_item";;
let module_type = Grammar.Entry.create gram "module_type";;
let module_expr = Grammar.Entry.create gram "module_expr";;
let expr = Grammar.Entry.create gram "expr";;
let patt = Grammar.Entry.create gram "patt";;
let ctyp = Grammar.Entry.create gram "type";;
let let_binding = Grammar.Entry.create gram "let_binding";;
let type_declaration = Grammar.Entry.create gram "type_declaration";;

let class_sig_item = Grammar.Entry.create gram "class_sig_item";;
let class_str_item = Grammar.Entry.create gram "class_str_item";;
let class_type = Grammar.Entry.create gram "class_type";;
let class_expr = Grammar.Entry.create gram "class_expr";;

let parse_interf = ref (Grammar.Entry.parse interf);;
let parse_implem = ref (Grammar.Entry.parse implem);;

let rec skip_to_eol cs =
  match Stream.peek cs with
    Some '\n' -> ()
  | Some c -> Stream.junk cs; skip_to_eol cs
  | _ -> ()
;;
let sync = ref skip_to_eol;;

let input_file = ref "";;
let output_file = ref None;;

let warning_default_function loc txt =
  let (bp, ep) = Stdpp.first_pos loc, Stdpp.last_pos loc in
  Printf.eprintf "<W> loc %d %d: %s\n" bp ep txt; flush stderr
;;

let warning = ref warning_default_function;;

let apply_with_var v x f =
  let vx = !v in
  try v := x; let r = f () in v := vx; r with
    e -> v := vx; raise e
;;

List.iter (fun (n, f) -> Quotation.add n f)
  ["id", Quotation.ExStr (fun _ s -> "$0:" ^ s ^ "$");
   "string", Quotation.ExStr (fun _ s -> "\"" ^ String.escaped s ^ "\"")];;

let quotation_dump_file = ref (None : string option);;

type err_ctx =
    Finding
  | Expanding
  | ParsingResult of Stdpp.location * string
;;
exception Qerror of string * err_ctx * exn;;

let expand_quotation gloc expander shift name str =
  let new_warning =
    let warn = !warning in
    let shift = Stdpp.first_pos gloc + shift in
    fun loc txt -> warn (Stdpp.shift_loc shift loc) txt
  in
  apply_with_var warning new_warning
    (fun () ->
       try expander str with
         Stdpp.Exc_located (loc, exc) ->
           let exc1 = Qerror (name, Expanding, exc) in
           let shift = Stdpp.first_pos gloc + shift in
           let loc =
             Stdpp.make_lined_loc (Stdpp.line_nb gloc + Stdpp.line_nb loc - 1)
               (if Stdpp.line_nb loc = 1 then Stdpp.bol_pos gloc
                else shift + Stdpp.bol_pos loc)
               (shift + Stdpp.first_pos loc, shift + Stdpp.last_pos loc)
           in
           raise (Stdpp.Exc_located (loc, exc1))
       | exc ->
           let exc1 = Qerror (name, Expanding, exc) in
           Stdpp.raise_with_loc gloc exc1)
;;

let parse_quotation_result entry loc shift name str =
  let cs = Stream.of_string str in
  try Grammar.Entry.parse entry cs with
    Stdpp.Exc_located (iloc, Qerror (_, Expanding, exc)) ->
      let ctx = ParsingResult (iloc, str) in
      let exc1 = Qerror (name, ctx, exc) in Stdpp.raise_with_loc loc exc1
  | Stdpp.Exc_located (_, (Qerror (_, _, _) as exc)) ->
      Stdpp.raise_with_loc loc exc
  | Stdpp.Exc_located (iloc, exc) ->
      let ctx = ParsingResult (iloc, str) in
      let exc1 = Qerror (name, ctx, exc) in Stdpp.raise_with_loc loc exc1
;;

let handle_quotation loc proj in_expr entry reloc (name, str) =
  let shift =
    match name with
      "" -> String.length "<<"
    | _ -> String.length "<:" + String.length name + String.length "<"
  in
  let expander =
    try Quotation.find name with
      exc ->
        let exc1 = Qerror (name, Finding, exc) in
        raise (Stdpp.Exc_located (Stdpp.sub_loc loc 0 shift, exc1))
  in
  let ast =
    match expander with
      Quotation.ExStr f ->
        let new_str = expand_quotation loc (f in_expr) shift name str in
        parse_quotation_result entry loc shift name new_str
    | Quotation.ExAst fe_fp ->
        expand_quotation loc (proj fe_fp) shift name str
  in
  reloc (fun _ -> loc) shift ast
;;

let expr_anti loc e = MLast.ExAnt (loc, e);;
let patt_anti loc p = MLast.PaAnt (loc, p);;
let expr_eoi = Grammar.Entry.create gram "expression";;
let patt_eoi = Grammar.Entry.create gram "pattern";;
Grammar.extend
  [Grammar.Entry.obj (expr_eoi : 'expr_eoi Grammar.Entry.e), None,
   [None, None,
    [[Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
      Gramext.Stoken ("EOI", "")],
     Gramext.action
       (fun _ (x : 'expr) (loc : Token.location) -> (x : 'expr_eoi))]];
   Grammar.Entry.obj (patt_eoi : 'patt_eoi Grammar.Entry.e), None,
   [None, None,
    [[Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e));
      Gramext.Stoken ("EOI", "")],
     Gramext.action
       (fun _ (x : 'patt) (loc : Token.location) -> (x : 'patt_eoi))]]];;

let handle_expr_quotation loc x =
  handle_quotation loc fst true expr_eoi Reloc.expr x
;;

let handle_patt_quotation loc x =
  handle_quotation loc snd false patt_eoi Reloc.patt x
;;

let expr_reloc = Reloc.expr;;
let patt_reloc = Reloc.patt;;

let rename_id = ref (fun x -> x);;

let find_line loc str =
  let (bp, ep) = Stdpp.first_pos loc, Stdpp.last_pos loc in
  let rec find i line col =
    if i == String.length str then line, 0, col
    else if i == bp then line, col, col + ep - bp
    else if str.[i] == '\n' then find (succ i) (succ line) 0
    else find (succ i) line (succ col)
  in
  find 0 1 0
;;

let loc_fmt =
  match Sys.os_type with
    "MacOS" ->
      format_of_string "File \"%s\"; line %d; characters %d to %d\n### "
  | _ -> format_of_string "File \"%s\", line %d, characters %d-%d:\n"
;;

let report_quotation_error name ctx =
  let name = if name = "" then !(Quotation.default) else name in
  Format.print_flush ();
  Format.open_hovbox 2;
  Printf.eprintf "While %s \"%s\":"
    (match ctx with
       Finding -> "finding quotation"
     | Expanding -> "expanding quotation"
     | ParsingResult (_, _) -> "parsing result of quotation")
    name;
  match ctx with
    ParsingResult (loc, str) ->
      begin match !quotation_dump_file with
        Some dump_file ->
          Printf.eprintf " dumping result...\n";
          flush stderr;
          begin try
            let (line, c1, c2) = find_line loc str in
            let oc = open_out_bin dump_file in
            output_string oc str;
            output_string oc "\n";
            flush oc;
            close_out oc;
            Printf.eprintf loc_fmt dump_file line c1 c2;
            flush stderr
          with
            _ ->
              Printf.eprintf "Error while dumping result in file \"%s\""
                dump_file;
              Printf.eprintf "; dump aborted.\n";
              flush stderr
          end
      | None ->
          if !input_file = "" then
            Printf.eprintf
              "\n(consider setting variable Pcaml.quotation_dump_file)\n"
          else Printf.eprintf " (consider using option -QD)\n";
          flush stderr
      end
  | _ -> Printf.eprintf "\n"; flush stderr
;;

let print_format str =
  let rec flush ini cnt =
    if cnt > ini then Format.print_string (String.sub str ini (cnt - ini))
  in
  let rec loop ini cnt =
    if cnt == String.length str then flush ini cnt
    else
      match str.[cnt] with
        '\n' ->
          flush ini cnt;
          Format.close_box ();
          Format.force_newline ();
          Format.open_box 2;
          loop (cnt + 1) (cnt + 1)
      | ' ' -> flush ini cnt; Format.print_space (); loop (cnt + 1) (cnt + 1)
      | _ -> loop ini (cnt + 1)
  in
  Format.open_box 2; loop 0 0; Format.close_box ()
;;

let print_file_failed file line char =
  Format.print_string ", file \"";
  Format.print_string file;
  Format.print_string "\", line ";
  Format.print_int line;
  Format.print_string ", char ";
  Format.print_int char
;;

let print_exn =
  function
    Out_of_memory -> Format.print_string "Out of memory\n"
  | Assert_failure (file, line, char) ->
      Format.print_string "Assertion failed"; print_file_failed file line char
  | Match_failure (file, line, char) ->
      Format.print_string "Pattern matching failed";
      print_file_failed file line char
  | Stream.Error str -> print_format ("Parse error: " ^ str)
  | Stream.Failure -> Format.print_string "Parse failure"
  | Token.Error str ->
      Format.print_string "Lexing error: "; Format.print_string str
  | Failure str -> Format.print_string "Failure: "; Format.print_string str
  | Invalid_argument str ->
      Format.print_string "Invalid argument: "; Format.print_string str
  | Sys_error msg ->
      Format.print_string "I/O error: "; Format.print_string msg
  | x ->
      Format.print_string "Uncaught exception: ";
      Format.print_string
        (Obj.magic (Obj.field (Obj.field (Obj.repr x) 0) 0));
      if Obj.size (Obj.repr x) > 1 then
        begin
          Format.print_string " (";
          for i = 1 to Obj.size (Obj.repr x) - 1 do
            if i > 1 then Format.print_string ", ";
            let arg = Obj.field (Obj.repr x) i in
            if not (Obj.is_block arg) then
              Format.print_int (Obj.magic arg : int)
            else if Obj.tag arg = Obj.tag (Obj.repr "a") then
              begin
                Format.print_char '\"';
                Format.print_string (Obj.magic arg : string);
                Format.print_char '\"'
              end
            else Format.print_char '_'
          done;
          Format.print_char ')'
        end
;;

let report_error exn =
  match exn with
    Qerror (name, Finding, Not_found) ->
      let name = if name = "" then !(Quotation.default) else name in
      Format.print_flush ();
      Format.open_hovbox 2;
      Format.printf "Unbound quotation: \"%s\"" name;
      Format.close_box ()
  | Qerror (name, ctx, exn) -> report_quotation_error name ctx; print_exn exn
  | e -> print_exn exn
;;

let no_constructors_arity = Ast2pt.no_constructors_arity;;

let arg_spec_list_ref = ref [];;
let arg_spec_list () = !arg_spec_list_ref;;
let add_option name spec descr =
  arg_spec_list_ref := !arg_spec_list_ref @ [name, spec, descr]
;;

(* Printers *)

module NewPrinter =
  struct
    type 'a printer_t =
      { mutable pr_fun : string -> 'a pr_fun;
        mutable pr_levels : 'a pr_level list }
    and 'a pr_level = { pr_label : string; mutable pr_rules : 'a pr_rule }
    and 'a pr_rule =
      ('a, ('a pr_fun -> 'a pr_fun -> pr_ctx -> string -> string -> string))
       Extfun.t
    and 'a pr_fun = pr_ctx -> string -> 'a -> string -> string
    and pr_ctx = { ind : int }
    ;;
    let printer loc_of name =
      let pr_fun name pr lab =
        let rec loop app =
          function
            [] ->
              (fun ind b z k ->
                 failwith
                   (Printf.sprintf "unable to print %s%s" name
                      (if lab = "" then "" else " \"" ^ lab ^ "\"")))
          | lev :: levl ->
              if app || lev.pr_label = lab then
                let next = loop true levl in
                let rec curr ind b z k =
                  Extfun.apply lev.pr_rules z curr next ind b k
                in
                curr
              else loop app levl
        in
        loop false pr.pr_levels
      in
      let pr =
        {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 378, 25)));
         pr_levels = []}
      in
      pr.pr_fun <- pr_fun name pr; pr
    ;;
    let pr_expr = printer MLast.loc_of_expr "expr";;
    let pr_patt = printer MLast.loc_of_patt "patt";;
    let pr_ctyp = printer MLast.loc_of_ctyp "type";;
    let pr_str_item = printer MLast.loc_of_str_item "str_item";;
    let pr_sig_item = printer MLast.loc_of_sig_item "sig_item";;
    let pr_module_expr = printer MLast.loc_of_module_expr "module_expr";;
    let pr_module_type = printer MLast.loc_of_module_type "module_type";;
    let pr_class_sig_item =
      printer MLast.loc_of_class_sig_item "class_sig_item"
    ;;
    let pr_class_str_item =
      printer MLast.loc_of_class_str_item "class_str_item"
    ;;
    let pr_class_expr = printer MLast.loc_of_class_expr "class_expr";;
    let pr_class_type = printer MLast.loc_of_class_type "class_type";;
    let rec find_pr_level lab =
      function
        [] -> failwith ("level " ^ lab ^ " not found")
      | lev :: levl ->
          if lev.pr_label = lab then lev else find_pr_level lab levl
    ;;
    let pr_expr_fun_args = ref Extfun.empty;;
  end
;;

module Printer =
  struct
    open Spretty;;
    type 'a printer_t =
      { mutable pr_fun : string -> 'a -> string -> kont -> pretty;
        mutable pr_levels : 'a pr_level list }
    and 'a pr_level =
      { pr_label : string;
        pr_box : 'a -> pretty Stream.t -> pretty;
        mutable pr_rules : 'a pr_rule }
    and 'a pr_rule =
      ('a, ('a curr -> 'a next -> string -> kont -> pretty Stream.t)) Extfun.t
    and 'a curr = 'a -> string -> kont -> pretty Stream.t
    and 'a next = 'a -> string -> kont -> pretty
    and kont = pretty Stream.t
    ;;
    let pr_str_item =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 422, 34)));
       pr_levels = []}
    ;;
    let pr_sig_item =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 423, 34)));
       pr_levels = []}
    ;;
    let pr_module_type =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 424, 37)));
       pr_levels = []}
    ;;
    let pr_module_expr =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 425, 37)));
       pr_levels = []}
    ;;
    let pr_expr =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 426, 30)));
       pr_levels = []}
    ;;
    let pr_patt =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 427, 30)));
       pr_levels = []}
    ;;
    let pr_ctyp =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 428, 30)));
       pr_levels = []}
    ;;
    let pr_class_sig_item =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 429, 40)));
       pr_levels = []}
    ;;
    let pr_class_str_item =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 430, 40)));
       pr_levels = []}
    ;;
    let pr_class_type =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 431, 36)));
       pr_levels = []}
    ;;
    let pr_class_expr =
      {pr_fun = (fun _ -> raise (Match_failure ("pcaml.ml", 432, 36)));
       pr_levels = []}
    ;;
    let pr_expr_fun_args = ref Extfun.empty;;
    let pr_fun name pr lab =
      let rec loop app =
        function
          [] -> (fun x dg k -> failwith ("unable to print " ^ name))
        | lev :: levl ->
            if app || lev.pr_label = lab then
              let next = loop true levl in
              let rec curr x dg k =
                Extfun.apply lev.pr_rules x curr next dg k
              in
              fun x dg k -> lev.pr_box x (curr x dg k)
            else loop app levl
      in
      loop false pr.pr_levels
    ;;
    pr_str_item.pr_fun <- pr_fun "str_item" pr_str_item;;
    pr_sig_item.pr_fun <- pr_fun "sig_item" pr_sig_item;;
    pr_module_type.pr_fun <- pr_fun "module_type" pr_module_type;;
    pr_module_expr.pr_fun <- pr_fun "module_expr" pr_module_expr;;
    pr_expr.pr_fun <- pr_fun "expr" pr_expr;;
    pr_patt.pr_fun <- pr_fun "patt" pr_patt;;
    pr_ctyp.pr_fun <- pr_fun "ctyp" pr_ctyp;;
    pr_class_sig_item.pr_fun <- pr_fun "class_sig_item" pr_class_sig_item;;
    pr_class_str_item.pr_fun <- pr_fun "class_str_item" pr_class_str_item;;
    pr_class_type.pr_fun <- pr_fun "class_type" pr_class_type;;
    pr_class_expr.pr_fun <- pr_fun "class_expr" pr_class_expr;;
    let rec find_pr_level lab =
      function
        [] -> failwith ("level " ^ lab ^ " not found")
      | lev :: levl ->
          if lev.pr_label = lab then lev else find_pr_level lab levl
    ;;
    let top_printer pr x =
      Format.force_newline ();
      Spretty.print_pretty Format.print_char Format.print_string
        Format.print_newline "<< " "   " 78 (fun _ _ _ -> "", 0, 0, 0) 0
        (pr.pr_fun "top" x "" Stream.sempty);
      Format.print_string " >>"
    ;;
    let buff = Buffer.create 73;;
    let buffer_char = Buffer.add_char buff;;
    let buffer_string = Buffer.add_string buff;;
    let buffer_newline () = Buffer.add_char buff '\n';;
    let string_of pr x =
      Buffer.clear buff;
      Spretty.print_pretty buffer_char buffer_string buffer_newline "" "" 78
        (fun _ _ _ -> "", 0, 0, 0) 0 (pr.pr_fun "top" x "" Stream.sempty);
      Buffer.contents buff
    ;;
    let inter_phrases = ref None;;
  end
;;

let undef x = ref (fun _ -> failwith x);;
let print_interf = undef "no printer";;
let print_implem = undef "no printer";;

(* Directives *)

type directive_fun = MLast.expr option -> unit;;
let directives = ref [];;
let add_directive d f = directives := (d, f) :: !directives;;
let find_directive d = List.assoc d !directives;;
