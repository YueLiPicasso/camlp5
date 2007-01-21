(* camlp4r *)
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

open Token;;

let no_quotations = ref false;;
let error_on_unknown_keywords = ref false;;

let dollar_for_antiquotation = ref true;;
let specific_space_dot = ref false;;

(* The string buffering machinery *)

module B :
  sig
    type t;;
    val empty : t;;
    val char : char -> t;;
    val string : string -> t;;
    val is_empty : t -> bool;;
    val add : t -> char -> t;;
    val add_str : t -> string -> t;;
    val get : t -> string;;
  end =
  struct
    type t = char list;;
    let empty = [];;
    let is_empty l = l = [];;
    let add l c = c :: l;;
    let add_str l s =
      let rec loop l i =
        if i = String.length s then l
        else loop (String.unsafe_get s i :: l) (i + 1)
      in
      loop l 0
    ;;
    let char c = [c];;
    let string = add_str [];;
    let get l =
      let s = String.create (List.length l) in
      let rec loop i =
        function
          c :: l -> String.unsafe_set s i c; loop (i - 1) l
        | [] -> s
      in
      loop (String.length s - 1) l
    ;;
  end
;;

(* The lexer *)

type context =
  { mutable after_space : bool;
    dollar_for_antiquotation : bool;
    specific_space_dot : bool;
    find_kwd : string -> string;
    line_cnt : int -> char -> char;
    set_line_nb : unit -> unit;
    make_lined_loc : int * int -> Stdpp.location }
;;

let err ctx loc msg =
  Stdpp.raise_with_loc (ctx.make_lined_loc loc) (Token.Error msg)
;;

let keyword_or_error ctx loc s =
  try "", ctx.find_kwd s with
    Not_found ->
      if !error_on_unknown_keywords then err ctx loc ("illegal token: " ^ s)
      else "", s
;;

let stream_peek_nth n strm =
  let rec loop n =
    function
      [] -> None
    | [x] -> if n == 1 then Some x else None
    | _ :: l -> loop (n - 1) l
  in
  loop n (Stream.npeek n strm)
;;

let rec decimal_digits_under buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'9' | '_' as c) ->
      Stream.junk strm__; decimal_digits_under (B.add buf c) strm__
  | _ -> buf
;;

let rec ident buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255' | '0'..'9' | '_' | '\'' as c) ->
      Stream.junk strm__; ident (B.add buf c) strm__
  | _ -> buf
and ident2 buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('!' | '?' | '~' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' |
       '.' | ':' | '<' | '>' | '|' | '$' as c) ->
      Stream.junk strm__; ident2 (B.add buf c) strm__
  | _ -> buf
and ident3 buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('0'..'9' | 'A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255' | '_' | '!' | '%' | '&' | '*' | '+' | '-' | '.' | '/' |
       ':' | '<' | '=' | '>' | '?' | '@' | '^' | '|' | '~' | '\'' | '$' as c
         ) ->
      Stream.junk strm__; ident3 (B.add buf c) strm__
  | _ -> buf
and digits kind buf (strm__ : _ Stream.t) =
  let d =
    try kind strm__ with
      Stream.Failure -> raise (Stream.Error "ill-formed integer constant")
  in
  digits_under kind (B.add buf d) strm__
and digits_under kind buf (strm__ : _ Stream.t) =
  match
    try Some (kind strm__) with
      Stream.Failure -> None
  with
    Some d -> digits_under kind (B.add buf d) strm__
  | _ ->
      match Stream.peek strm__ with
        Some '_' -> Stream.junk strm__; digits_under kind buf strm__
      | Some 'l' -> Stream.junk strm__; "INT_l", B.get buf
      | Some 'L' -> Stream.junk strm__; "INT_L", B.get buf
      | Some 'n' -> Stream.junk strm__; "INT_n", B.get buf
      | _ -> "INT", B.get buf
and octal (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'7' as d) -> Stream.junk strm__; d
  | _ -> raise Stream.Failure
and hexa (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'9' | 'a'..'f' | 'A'..'F' as d) -> Stream.junk strm__; d
  | _ -> raise Stream.Failure
and binary (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'1' as d) -> Stream.junk strm__; d
  | _ -> raise Stream.Failure
;;

let exponent_part buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('e' | 'E' as c) ->
      Stream.junk strm__;
      let buf =
        match Stream.peek strm__ with
          Some ('+' | '-' as c1) -> Stream.junk strm__; B.add (B.add buf c) c1
        | _ -> B.add buf c
      in
      begin match Stream.peek strm__ with
        Some ('0'..'9' as c) ->
          Stream.junk strm__; decimal_digits_under (B.add buf c) strm__
      | _ -> raise (Stream.Error "ill-formed floating-point constant")
      end
  | _ -> raise Stream.Failure
;;

let number buf (strm__ : _ Stream.t) =
  let buf = decimal_digits_under buf strm__ in
  match Stream.peek strm__ with
    Some '.' ->
      Stream.junk strm__;
      let buf = decimal_digits_under (B.add buf '.') strm__ in
      let buf =
        try exponent_part buf strm__ with
          Stream.Failure -> buf
      in
      "FLOAT", B.get buf
  | _ ->
      match
        try Some (exponent_part buf strm__) with
          Stream.Failure -> None
      with
        Some buf -> "FLOAT", B.get buf
      | _ ->
          match Stream.peek strm__ with
            Some 'l' -> Stream.junk strm__; "INT_l", B.get buf
          | Some 'L' -> Stream.junk strm__; "INT_L", B.get buf
          | Some 'n' -> Stream.junk strm__; "INT_n", B.get buf
          | _ -> "INT", B.get buf
;;

let rec char ctx bp buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some '\'' ->
      Stream.junk strm__;
      let s = strm__ in
      if B.is_empty buf then char ctx bp (B.add buf '\'') s else buf
  | Some '\\' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some c ->
          Stream.junk strm__; char ctx bp (B.add (B.add buf '\\') c) strm__
      | _ -> raise (Stream.Error "")
      end
  | Some c -> Stream.junk strm__; char ctx bp (B.add buf c) strm__
  | _ ->
      let ep = Stream.count strm__ in err ctx (bp, ep) "char not terminated"
;;

let rec string ctx bp buf (strm__ : _ Stream.t) =
  let bp1 = Stream.count strm__ in
  match Stream.peek strm__ with
    Some '\"' -> Stream.junk strm__; buf
  | Some '\\' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some c ->
          Stream.junk strm__;
          string ctx bp (B.add (B.add buf '\\') (ctx.line_cnt (bp1 + 1) c))
            strm__
      | _ -> raise (Stream.Error "")
      end
  | Some c ->
      Stream.junk strm__;
      string ctx bp (B.add buf (ctx.line_cnt bp1 c)) strm__
  | _ ->
      let ep = Stream.count strm__ in err ctx (bp, ep) "string not terminated"
;;

let incr_line_nb buf _ = incr !(Token.line_nb); buf;;

let comment ctx bp =
  let rec comment (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '(' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some '*' ->
            Stream.junk strm__; let _ = comment strm__ in comment strm__
        | _ -> comment strm__
        end
    | Some '*' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some ')' -> Stream.junk strm__; ()
        | _ -> comment strm__
        end
    | Some '\"' ->
        Stream.junk strm__;
        let _ =
          try string ctx bp B.empty strm__ with
            Stream.Failure -> raise (Stream.Error "")
        in
        comment strm__
    | Some '\'' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some '\'' -> Stream.junk strm__; comment strm__
        | Some '\\' ->
            Stream.junk strm__;
            begin match Stream.peek strm__ with
              Some '\'' -> Stream.junk strm__; comment strm__
            | Some ('\\' | '\"' | 'n' | 't' | 'b' | 'r') ->
                Stream.junk strm__;
                begin match Stream.peek strm__ with
                  Some '\'' -> Stream.junk strm__; comment strm__
                | _ -> comment strm__
                end
            | Some ('0'..'9') ->
                Stream.junk strm__;
                begin match Stream.peek strm__ with
                  Some ('0'..'9') ->
                    Stream.junk strm__;
                    begin match Stream.peek strm__ with
                      Some ('0'..'9') ->
                        Stream.junk strm__;
                        begin match Stream.peek strm__ with
                          Some '\'' -> Stream.junk strm__; comment strm__
                        | _ -> comment strm__
                        end
                    | _ -> comment strm__
                    end
                | _ -> comment strm__
                end
            | _ -> comment strm__
            end
        | _ ->
            match Stream.npeek 2 strm__ with
              [_; '\''] ->
                let _ = Stream.junk strm__ in
                let _ = Stream.junk strm__ in comment strm__
            | _ -> comment strm__
        end
    | Some ('\n' | '\r') ->
        Stream.junk strm__; let () = incr_line_nb () strm__ in comment strm__
    | Some c -> Stream.junk strm__; comment strm__
    | _ ->
        let ep = Stream.count strm__ in
        err ctx (bp, ep) "comment not terminated"
  in
  comment
;;

let rec quotation ctx bp buf (strm__ : _ Stream.t) =
  let bp1 = Stream.count strm__ in
  match Stream.peek strm__ with
    Some '>' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some '>' -> Stream.junk strm__; buf
      | _ -> quotation ctx bp (B.add buf '>') strm__
      end
  | Some '<' ->
      Stream.junk strm__;
      let buf =
        match Stream.peek strm__ with
          Some '<' ->
            Stream.junk strm__;
            let buf = quotation ctx bp (B.add_str buf "<<") strm__ in
            B.add_str buf ">>"
        | Some ':' ->
            Stream.junk strm__;
            let buf = ident (B.add_str buf "<:") strm__ in
            begin match Stream.peek strm__ with
              Some '<' ->
                Stream.junk strm__;
                let buf = quotation ctx bp (B.add buf '<') strm__ in
                B.add_str buf ">>"
            | _ -> buf
            end
        | _ -> B.add buf '<'
      in
      quotation ctx bp buf strm__
  | Some '\\' ->
      Stream.junk strm__;
      let buf =
        match Stream.peek strm__ with
          Some ('>' | '<' | '\\' as c) -> Stream.junk strm__; B.add buf c
        | _ -> B.add buf '\\'
      in
      quotation ctx bp buf strm__
  | Some c ->
      Stream.junk strm__;
      quotation ctx bp (B.add buf (ctx.line_cnt bp1 c)) strm__
  | _ ->
      let ep = Stream.count strm__ in
      err ctx (bp, ep) "quotation not terminated"
;;

let less ctx bp strm =
  if !no_quotations then
    let (strm__ : _ Stream.t) = strm in
    let buf = ident2 (B.char '<') strm__ in
    let ep = Stream.count strm__ in keyword_or_error ctx (bp, ep) (B.get buf)
  else
    let (strm__ : _ Stream.t) = strm in
    match Stream.peek strm__ with
      Some '<' ->
        Stream.junk strm__;
        let buf =
          try quotation ctx bp B.empty strm__ with
            Stream.Failure -> raise (Stream.Error "")
        in
        "QUOTATION", ":" ^ B.get buf
    | Some ':' ->
        Stream.junk strm__;
        let i =
          try let buf = ident B.empty strm__ in B.get buf with
            Stream.Failure -> raise (Stream.Error "")
        in
        begin match Stream.peek strm__ with
          Some '<' ->
            Stream.junk strm__;
            let buf =
              try quotation ctx bp B.empty strm__ with
                Stream.Failure -> raise (Stream.Error "")
            in
            "QUOTATION", i ^ ":" ^ B.get buf
        | _ -> raise (Stream.Error "character '<' expected")
        end
    | _ ->
        let buf = ident2 (B.char '<') strm__ in
        let ep = Stream.count strm__ in
        keyword_or_error ctx (bp, ep) (B.get buf)
;;

let rec antiquot ctx bp buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some '$' -> Stream.junk strm__; "ANTIQUOT", ":" ^ B.get buf
  | Some ('a'..'z' | 'A'..'Z' | '0'..'9' as c) ->
      Stream.junk strm__; antiquot ctx bp (B.add buf c) strm__
  | Some ':' ->
      Stream.junk strm__;
      let k = B.get buf in
      "ANTIQUOT", k ^ ":" ^ locate_or_antiquot_rest ctx bp B.empty strm__
  | Some '\\' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some c ->
          Stream.junk strm__;
          "ANTIQUOT",
          ":" ^ locate_or_antiquot_rest ctx bp (B.add buf c) strm__
      | _ -> raise (Stream.Error "")
      end
  | Some c ->
      Stream.junk strm__;
      "ANTIQUOT", ":" ^ locate_or_antiquot_rest ctx bp (B.add buf c) strm__
  | _ ->
      let ep = Stream.count strm__ in
      err ctx (bp, ep) "antiquotation not terminated"
and locate_or_antiquot_rest ctx bp buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some '$' -> Stream.junk strm__; B.get buf
  | Some '\\' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some c ->
          Stream.junk strm__;
          locate_or_antiquot_rest ctx bp (B.add buf c) strm__
      | _ -> raise (Stream.Error "")
      end
  | Some c ->
      Stream.junk strm__; locate_or_antiquot_rest ctx bp (B.add buf c) strm__
  | _ ->
      let ep = Stream.count strm__ in
      err ctx (bp, ep) "antiquotation not terminated"
;;

let rec maybe_locate ctx bp buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some '$' -> Stream.junk strm__; "ANTIQUOT", ":" ^ B.get buf
  | Some ('0'..'9' as c) ->
      Stream.junk strm__; maybe_locate ctx bp (B.add buf c) strm__
  | Some ':' ->
      Stream.junk strm__;
      "LOCATE",
      B.get buf ^ ":" ^ locate_or_antiquot_rest ctx bp B.empty strm__
  | Some '\\' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some c ->
          Stream.junk strm__;
          "ANTIQUOT",
          ":" ^ locate_or_antiquot_rest ctx bp (B.add buf c) strm__
      | _ -> raise (Stream.Error "")
      end
  | Some c ->
      Stream.junk strm__;
      "ANTIQUOT", ":" ^ locate_or_antiquot_rest ctx bp (B.add buf c) strm__
  | _ ->
      let ep = Stream.count strm__ in
      err ctx (bp, ep) "antiquotation not terminated"
;;

let dollar ctx bp buf (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some '$' -> Stream.junk strm__; "ANTIQUOT", ":" ^ B.get buf
  | Some ('a'..'z' | 'A'..'Z' as c) ->
      Stream.junk strm__; antiquot ctx bp (B.add buf c) strm__
  | Some ('0'..'9' as c) ->
      Stream.junk strm__; maybe_locate ctx bp (B.add buf c) strm__
  | Some ':' ->
      Stream.junk strm__;
      let k = B.get buf in
      "ANTIQUOT", k ^ ":" ^ locate_or_antiquot_rest ctx bp B.empty strm__
  | Some '\\' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some c ->
          Stream.junk strm__;
          "ANTIQUOT",
          ":" ^ locate_or_antiquot_rest ctx bp (B.add buf c) strm__
      | _ -> raise (Stream.Error "")
      end
  | _ ->
      let s = strm__ in
      if ctx.dollar_for_antiquotation then
        let (strm__ : _ Stream.t) = s in
        match Stream.peek strm__ with
          Some c ->
            Stream.junk strm__;
            "ANTIQUOT", ":" ^ locate_or_antiquot_rest ctx bp (B.add buf c) s
        | _ ->
            let ep = Stream.count strm__ in
            err ctx (bp, ep) "antiquotation not terminated"
      else "", B.get (ident2 (B.char '$') s)
;;

let rec linedir n s =
  match stream_peek_nth n s with
    Some (' ' | '\t') -> linedir (n + 1) s
  | Some ('0'..'9') -> linedir_digits (n + 1) s
  | _ -> false
and linedir_digits n s =
  match stream_peek_nth n s with
    Some ('0'..'9') -> linedir_digits (n + 1) s
  | _ -> linedir_quote n s
and linedir_quote n s =
  match stream_peek_nth n s with
    Some (' ' | '\t') -> linedir_quote (n + 1) s
  | Some '\"' -> true
  | _ -> false
;;

let rec any_to_nl (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('\r' | '\n') ->
      Stream.junk strm__;
      let ep = Stream.count strm__ in
      incr !(Token.line_nb); !(Token.bol_pos) := ep
  | Some _ -> Stream.junk strm__; any_to_nl strm__
  | _ -> ()
;;

let rec next_token ctx (strm__ : _ Stream.t) =
  let bp = Stream.count strm__ in
  match Stream.peek strm__ with
    Some ('\n' | '\r') ->
      Stream.junk strm__;
      let s = strm__ in
      let ep = Stream.count strm__ in
      incr !(Token.line_nb);
      !(Token.bol_pos) := ep;
      ctx.set_line_nb ();
      ctx.after_space <- true;
      next_token ctx s
  | Some (' ' | '\t' | '\026' | '\012') ->
      Stream.junk strm__;
      let s = strm__ in ctx.after_space <- true; next_token ctx s
  | Some '#' when bp = !(!(Token.bol_pos)) ->
      Stream.junk strm__;
      let s = strm__ in
      if linedir 1 s then
        begin
          any_to_nl s;
          ctx.set_line_nb ();
          ctx.after_space <- true;
          next_token ctx s
        end
      else
        let loc = ctx.make_lined_loc (bp, bp + 1) in
        keyword_or_error ctx (bp, bp + 1) "#", loc
  | Some '(' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some '*' ->
          Stream.junk strm__;
          let _ = comment ctx bp strm__ in
          let s = strm__ in
          ctx.set_line_nb (); ctx.after_space <- true; next_token ctx s
      | _ ->
          let ep = Stream.count strm__ in
          let loc = ctx.make_lined_loc (bp, ep) in
          keyword_or_error ctx (bp, ep) "(", loc
      end
  | _ ->
      let tok = next_token_kont ctx strm__ in
      let ep = Stream.count strm__ in
      let loc = ctx.make_lined_loc (bp, max (bp + 1) ep) in tok, loc
and next_token_kont ctx (strm__ : _ Stream.t) =
  let bp = Stream.count strm__ in
  match Stream.peek strm__ with
    Some ('A'..'Z' | '\192'..'\214' | '\216'..'\222' as c) ->
      Stream.junk strm__;
      let buf = ident (B.char c) strm__ in
      let id = B.get buf in
      begin try "", ctx.find_kwd id with
        Not_found -> "UIDENT", id
      end
  | Some ('a'..'z' | '\223'..'\246' | '\248'..'\255' | '_' as c) ->
      Stream.junk strm__;
      let buf = ident (B.char c) strm__ in
      let id = B.get buf in
      begin try "", ctx.find_kwd id with
        Not_found -> "LIDENT", id
      end
  | Some ('1'..'9' as c) -> Stream.junk strm__; number (B.char c) strm__
  | Some '0' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some ('o' | 'O') ->
          Stream.junk strm__; digits octal (B.string "0o") strm__
      | Some ('x' | 'X') ->
          Stream.junk strm__; digits hexa (B.string "0x") strm__
      | Some ('b' | 'B') ->
          Stream.junk strm__; digits binary (B.string "0b") strm__
      | _ -> number (B.char '0') strm__
      end
  | Some '\'' ->
      Stream.junk strm__;
      begin match Stream.npeek 2 strm__ with
        [_; '\''] | ['\\'; _] ->
          let buf = char ctx bp B.empty strm__ in "CHAR", B.get buf
      | _ -> let ep = Stream.count strm__ in keyword_or_error ctx (bp, ep) "'"
      end
  | Some '\"' ->
      Stream.junk strm__;
      let buf = string ctx bp B.empty strm__ in "STRING", B.get buf
  | Some '$' -> Stream.junk strm__; dollar ctx bp B.empty strm__
  | Some ('!' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' as c) ->
      Stream.junk strm__;
      let buf = ident2 (B.char c) strm__ in
      let ep = Stream.count strm__ in
      keyword_or_error ctx (bp, ep) (B.get buf)
  | Some ('~' as c) ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some ('a'..'z' as c) ->
          Stream.junk strm__;
          let buf = ident (B.char c) strm__ in "TILDEIDENT", B.get buf
      | _ ->
          let buf = ident2 (B.char c) strm__ in
          let ep = Stream.count strm__ in
          keyword_or_error ctx (bp, ep) (B.get buf)
      end
  | Some ('?' as c) ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some ('a'..'z' as c) ->
          Stream.junk strm__;
          let buf = ident (B.char c) strm__ in "QUESTIONIDENT", B.get buf
      | _ ->
          let buf = ident2 (B.char c) strm__ in
          let ep = Stream.count strm__ in
          keyword_or_error ctx (bp, ep) (B.get buf)
      end
  | Some '<' -> Stream.junk strm__; less ctx bp strm__
  | Some (':' as c1) ->
      Stream.junk strm__;
      let buf =
        match Stream.peek strm__ with
          Some (']' | ':' | '=' | '>' as c2) ->
            Stream.junk strm__; B.add (B.char c1) c2
        | _ -> B.char c1
      in
      let ep = Stream.count strm__ in
      keyword_or_error ctx (bp, ep) (B.get buf)
  | Some ('>' | '|' as c1) ->
      Stream.junk strm__;
      let buf =
        match Stream.peek strm__ with
          Some (']' | '}' as c2) -> Stream.junk strm__; B.add (B.char c1) c2
        | _ -> ident2 (B.char c1) strm__
      in
      let ep = Stream.count strm__ in
      keyword_or_error ctx (bp, ep) (B.get buf)
  | Some ('[' | '{' as c1) ->
      Stream.junk strm__;
      let buf =
        match Stream.npeek 2 strm__ with
          ['<'; '<' | ':'] -> B.char c1
        | _ ->
            match Stream.peek strm__ with
              Some ('|' | '<' | ':' as c2) ->
                Stream.junk strm__; B.add (B.char c1) c2
            | _ -> B.char c1
      in
      let ep = Stream.count strm__ in
      keyword_or_error ctx (bp, ep) (B.get buf)
  | Some '.' ->
      Stream.junk strm__;
      let id =
        match Stream.peek strm__ with
          Some '.' -> Stream.junk strm__; ".."
        | _ -> if ctx.specific_space_dot && ctx.after_space then " ." else "."
      in
      let ep = Stream.count strm__ in keyword_or_error ctx (bp, ep) id
  | Some ';' ->
      Stream.junk strm__;
      let id =
        match Stream.peek strm__ with
          Some ';' -> Stream.junk strm__; ";;"
        | _ -> ";"
      in
      let ep = Stream.count strm__ in keyword_or_error ctx (bp, ep) id
  | Some '\\' ->
      Stream.junk strm__;
      let buf = ident3 B.empty strm__ in "LIDENT", B.get buf
  | Some c ->
      Stream.junk strm__;
      let ep = Stream.count strm__ in
      keyword_or_error ctx (bp, ep) (String.make 1 c)
  | _ -> let _ = Stream.empty strm__ in "EOI", ""
;;

let next_token_fun ctx glexr (cstrm, s_line_nb, s_bol_pos) =
  try
    begin match !(Token.restore_lexing_info) with
      Some (line_nb, bol_pos) ->
        s_line_nb := line_nb;
        s_bol_pos := bol_pos;
        Token.restore_lexing_info := None
    | None -> ()
    end;
    Token.line_nb := s_line_nb;
    Token.bol_pos := s_bol_pos;
    let comm_bp = Stream.count cstrm in
    ctx.set_line_nb ();
    ctx.after_space <- false;
    let (r, loc) = next_token ctx cstrm in
    begin match !glexr.tok_comm with
      Some list ->
        if Stdpp.first_pos loc > comm_bp then
          let comm_loc = Stdpp.make_loc (comm_bp, Stdpp.last_pos loc) in
          !glexr.tok_comm <- Some (comm_loc :: list)
    | None -> ()
    end;
    r, loc
  with
    Stream.Error str ->
      err ctx (Stream.count cstrm, Stream.count cstrm + 1) str
;;

let func kwd_table glexr =
  let ctx =
    let line_nb = ref 0 in
    let bol_pos = ref 0 in
    {after_space = false;
     dollar_for_antiquotation = !dollar_for_antiquotation;
     specific_space_dot = !specific_space_dot;
     find_kwd = Hashtbl.find kwd_table;
     line_cnt =
       (fun bp1 c ->
          match c with
            '\n' | '\r' ->
              incr !(Token.line_nb); !(Token.bol_pos) := bp1 + 1; c
          | c -> c);
     set_line_nb =
       (fun () ->
          line_nb := !(!(Token.line_nb)); bol_pos := !(!(Token.bol_pos)));
     make_lined_loc = fun loc -> Stdpp.make_lined_loc !line_nb !bol_pos loc}
  in
  Token.lexer_func_of_parser (next_token_fun ctx glexr)
;;

let rec check_keyword_stream (strm__ : _ Stream.t) =
  let _ = check strm__ in
  let _ =
    try Stream.empty strm__ with
      Stream.Failure -> raise (Stream.Error "")
  in
  true
and check (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255') ->
      Stream.junk strm__; check_ident strm__
  | Some
      ('!' | '?' | '~' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' |
       '.') ->
      Stream.junk strm__; check_ident2 strm__
  | Some '<' ->
      Stream.junk strm__;
      begin match Stream.npeek 1 strm__ with
        [':' | '<'] -> ()
      | _ -> check_ident2 strm__
      end
  | Some ':' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some (']' | ':' | '=' | '>') -> Stream.junk strm__; ()
      | _ -> ()
      end
  | Some ('>' | '|') ->
      Stream.junk strm__;
      begin try
        match Stream.peek strm__ with
          Some (']' | '}') -> Stream.junk strm__; ()
        | _ -> check_ident2 strm__
      with
        Stream.Failure -> raise (Stream.Error "")
      end
  | Some ('[' | '{') ->
      Stream.junk strm__;
      begin match Stream.npeek 2 strm__ with
        ['<'; '<' | ':'] -> ()
      | _ ->
          match Stream.peek strm__ with
            Some ('|' | '<' | ':') -> Stream.junk strm__; ()
          | _ -> ()
      end
  | Some ';' ->
      Stream.junk strm__;
      begin match Stream.peek strm__ with
        Some ';' -> Stream.junk strm__; ()
      | _ -> ()
      end
  | Some _ -> Stream.junk strm__; ()
  | _ -> raise Stream.Failure
and check_ident (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255' | '0'..'9' | '_' | '\'') ->
      Stream.junk strm__; check_ident strm__
  | _ -> ()
and check_ident2 (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('!' | '?' | '~' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' |
       '.' | ':' | '<' | '>' | '|') ->
      Stream.junk strm__; check_ident2 strm__
  | _ -> ()
;;

let check_keyword s =
  try check_keyword_stream (Stream.of_string s) with
    _ -> false
;;

let error_no_respect_rules p_con p_prm =
  raise
    (Token.Error
       ("the token " ^
          (if p_con = "" then "\"" ^ p_prm ^ "\""
           else if p_prm = "" then p_con
           else p_con ^ " \"" ^ p_prm ^ "\"") ^
          " does not respect Plexer rules"))
;;

let error_ident_and_keyword p_con p_prm =
  raise
    (Token.Error
       ("the token \"" ^ p_prm ^ "\" is used as " ^ p_con ^
          " and as keyword"))
;;

let using_token kwd_table ident_table (p_con, p_prm) =
  match p_con with
    "" ->
      if not (Hashtbl.mem kwd_table p_prm) then
        if check_keyword p_prm then
          if Hashtbl.mem ident_table p_prm then
            error_ident_and_keyword (Hashtbl.find ident_table p_prm) p_prm
          else Hashtbl.add kwd_table p_prm p_prm
        else error_no_respect_rules p_con p_prm
  | "LIDENT" ->
      if p_prm = "" then ()
      else
        begin match p_prm.[0] with
          'A'..'Z' -> error_no_respect_rules p_con p_prm
        | _ ->
            if Hashtbl.mem kwd_table p_prm then
              error_ident_and_keyword p_con p_prm
            else Hashtbl.add ident_table p_prm p_con
        end
  | "UIDENT" ->
      if p_prm = "" then ()
      else
        begin match p_prm.[0] with
          'a'..'z' -> error_no_respect_rules p_con p_prm
        | _ ->
            if Hashtbl.mem kwd_table p_prm then
              error_ident_and_keyword p_con p_prm
            else Hashtbl.add ident_table p_prm p_con
        end
  | "TILDEIDENT" | "QUESTIONIDENT" | "INT" | "INT_l" | "INT_L" | "INT_n" |
    "FLOAT" | "CHAR" | "STRING" | "QUOTATION" | "ANTIQUOT" | "LOCATE" |
    "EOI" ->
      ()
  | _ ->
      raise
        (Token.Error
           ("the constructor \"" ^ p_con ^ "\" is not recognized by Plexer"))
;;

let removing_token kwd_table ident_table (p_con, p_prm) =
  match p_con with
    "" -> Hashtbl.remove kwd_table p_prm
  | "LIDENT" | "UIDENT" ->
      if p_prm <> "" then Hashtbl.remove ident_table p_prm
  | _ -> ()
;;

let text =
  function
    "", t -> "'" ^ t ^ "'"
  | "LIDENT", "" -> "lowercase identifier"
  | "LIDENT", t -> "'" ^ t ^ "'"
  | "UIDENT", "" -> "uppercase identifier"
  | "UIDENT", t -> "'" ^ t ^ "'"
  | "INT", "" -> "integer"
  | "INT", s -> "'" ^ s ^ "'"
  | "FLOAT", "" -> "float"
  | "STRING", "" -> "string"
  | "CHAR", "" -> "char"
  | "QUOTATION", "" -> "quotation"
  | "ANTIQUOT", k -> "antiquot \"" ^ k ^ "\""
  | "LOCATE", "" -> "locate"
  | "EOI", "" -> "end of input"
  | con, "" -> con
  | con, prm -> con ^ " \"" ^ prm ^ "\""
;;

let eq_before_colon p e =
  let rec loop i =
    if i == String.length e then
      failwith "Internal error in Plexer: incorrect ANTIQUOT"
    else if i == String.length p then e.[i] == ':'
    else if p.[i] == e.[i] then loop (i + 1)
    else false
  in
  loop 0
;;

let after_colon e =
  try
    let i = String.index e ':' in
    String.sub e (i + 1) (String.length e - i - 1)
  with
    Not_found -> ""
;;

let tok_match =
  function
    "ANTIQUOT", p_prm ->
      begin function
        "ANTIQUOT", prm when eq_before_colon p_prm prm -> after_colon prm
      | _ -> raise Stream.Failure
      end
  | tok -> Token.default_match tok
;;

let gmake () =
  let kwd_table = Hashtbl.create 301 in
  let id_table = Hashtbl.create 301 in
  let glexr =
    ref
      {tok_func = (fun _ -> raise (Match_failure ("plexer.ml", 721, 17)));
       tok_using = (fun _ -> raise (Match_failure ("plexer.ml", 721, 37)));
       tok_removing = (fun _ -> raise (Match_failure ("plexer.ml", 721, 60)));
       tok_match = (fun _ -> raise (Match_failure ("plexer.ml", 722, 18)));
       tok_text = (fun _ -> raise (Match_failure ("plexer.ml", 722, 37)));
       tok_comm = None}
  in
  let glex =
    {tok_func = func kwd_table glexr;
     tok_using = using_token kwd_table id_table;
     tok_removing = removing_token kwd_table id_table; tok_match = tok_match;
     tok_text = text; tok_comm = None}
  in
  glexr := glex; glex
;;
