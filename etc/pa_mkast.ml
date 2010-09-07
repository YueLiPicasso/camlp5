(* camlp5r *)
(* $Id: pa_mkast.ml,v 1.2 2010/09/07 20:27:39 deraugla Exp $ *)

(*
   meta/camlp5r etc/pa_mkast.cmo etc/pr_r.cmo -impl main/mLast.mli
*)

#load "pa_extend.cmo";
#load "q_MLast.cmo";

value rec prefix_of_type t =
  let t =
    match t with
    [ <:ctyp< Ploc.vala $t$ >> -> t
    | t -> t ]
  in
  match t with
  [ <:ctyp< loc >> -> "l"
  | <:ctyp< bool >> -> "b"
  | <:ctyp< expr >> -> "e"
  | <:ctyp< module_type >> -> "mt"
  | <:ctyp< patt >> -> "p"
  | <:ctyp< string >> -> "s"
  | <:ctyp< ctyp >> -> "t"
  | <:ctyp< list $t$ >> -> "l" ^ prefix_of_type t
  | <:ctyp< option $t$ >> -> "o" ^ prefix_of_type t
  | <:ctyp< ($list:tl$) >> -> String.concat "" (List.map prefix_of_type tl)
  | _ -> "x" ]
;

value name_of_vars tl =
  let (rev_tnl, env) =
    List.fold_left
      (fun (rev_tnl, env) t ->
         let pt = prefix_of_type t in
         let (n, env) =
           loop env where rec loop =
             fun
             [ [(n1, cnt1) :: env] ->
                 if n1 = pt then (cnt1, [(n1, cnt1 + 1) :: env])
                 else
                   let (n, env) = loop env in
                   (n, [(n1, cnt1) :: env])
             | [] -> (1, [(pt, 2)]) ]
         in
         ([(t, (pt, n)) :: rev_tnl], env))
       ([], []) tl
  in
  List.rev_map
    (fun (t, (pt, n)) ->
       let name =
         if List.assoc pt env = 2 then pt
         else pt ^ string_of_int n
       in
       (t, name))
    rev_tnl
;

value rec expr_of_type loc t =
  match t with
  [ <:ctyp< $lid:tn$ >> ->
      match tn with
      [ "bool" | "string" -> <:expr< C.$lid:tn$ >>
      | _ -> <:expr< $lid:tn$ >> ]
  | <:ctyp< ($list:tl$) >> ->
      let tnl = name_of_vars tl in
      let rev_pl =
        List.fold_left
          (fun rev_pl (t, name) ->
             let p = <:patt< $lid:name$ >> in
             [p :: rev_pl])
          [] tnl
      in
      let rev_el =
        List.fold_left
          (fun rev_el (t, name) ->
             let e =
               match t with
               [ <:ctyp< loc >> -> <:expr< floc loc >>
               | _ ->
                   let e = <:expr< $lid:name$ >> in
                   <:expr< $expr_of_type loc t$ $e$ >> ]
             in
             [e :: rev_el])
          [] tnl
      in
      let p = <:patt< ($list:List.rev rev_pl$) >> in
      let e =
        List.fold_left (fun e e1 -> <:expr< [$e1$ :: $e$] >>) <:expr< [] >>
          rev_el
      in
      <:expr< fun $p$ -> C.tuple $e$ >>
  | <:ctyp< $t1$ $t2$ >> ->
      let e = expr_of_type loc t2 in
      let f =
        match t1 with
        [ <:ctyp< list >> -> <:expr< C.list >>
        | <:ctyp< option >> -> <:expr< C.option >>
        | <:ctyp< Ploc.vala >> -> <:expr< C.vala >>
        | <:ctyp< $lid:n$ >> -> <:expr< $lid:n^"_map"$ floc >>
        | _ -> <:expr< error >> ]
      in
      <:expr< $f$ $e$ >>
  | _ ->
      <:expr< error >> ]
;

value expr_of_cons_decl (loc, c, tl) =
  let tl = Pcaml.unvala tl in
  let tnl = name_of_vars tl in
  let p =
    let p = <:patt< $_uid:c$ >> in
    List.fold_left
      (fun p1 (t, name) ->
         let p2 =
           match t with
           [ <:ctyp< loc >> -> <:patt< _ >>
           | _ -> <:patt< $lid:name$ >> ]
         in
         <:patt< $p1$ $p2$ >>)
      p tnl
  in
  let c = Pcaml.unvala c in
  let f = <:expr< C.node $str:c$ >> in
  let (rev_el, _) =
    List.fold_left
      (fun (rev_el, n) (t, name) ->
         let e = <:expr< $lid:name$ >> in
         match t with
         [ <:ctyp< loc >> -> (rev_el, n)
         | _ ->
             let e =
               let f = expr_of_type loc t in
               <:expr< $f$ $e$ >>
             in
             ([e :: rev_el], n + 1) ])
      ([], 1) tnl
  in
  let e =
    List.fold_left (fun el e -> <:expr< [$e$ :: $el$] >>) <:expr< [] >> rev_el
  in
  (p, <:vala< None >>, <:expr< $f$ $e$ >>)
;

value apply loc f e =
  match f with
  [ <:expr< fun $p1$ -> $e1$ >> -> <:expr< let $p1$ = $e$ in $e1$ >>
  | _ -> <:expr< $f$ $e$ >> ]
;

value expr_of_type_decl loc td =
  match td.MLast.tdDef with
  [ <:ctyp< [ $list:cdl$ ] >> ->
      let pwel =
        List.fold_right
          (fun cd pwel ->
             let pwe = expr_of_cons_decl cd in
             [pwe :: pwel])
          cdl []
      in
      <:expr< fun [ $list:pwel$ ] >>
  | <:ctyp< { $list:ldl$ } >> ->
      let lel =
        List.map
          (fun (loc, l, mf, t) ->
             let e = <:expr< x.$lid:l$ >> in
             let e =
               let f = expr_of_type loc t in
               apply loc f e
             in
             (<:patt< $lid:l$ >>, e))
          ldl
      in
      <:expr< fun x -> {$list:lel$} >>
  | _ -> <:expr< 0 >> ]
;

value gen_ast loc tdl =
  match tdl with
  [ [{MLast.tdNam = (_, <:vala< "ctyp" >>)} :: _] ->
      let pel =
        List.map
          (fun td ->
             let tn = Pcaml.unvala (snd td.MLast.tdNam) in
             let e = expr_of_type_decl loc td in
             (<:patt< $lid:tn$ >>, e))
          tdl
      in
      <:str_item<
        module Meta_make (C : MetaSig) =
          struct
            value rec $list:pel$;
          end >>
  | _ -> <:str_item< type $list:tdl$ >> ]
;

EXTEND
  Pcaml.str_item:
    [ [ "type"; tdl = LIST1 Pcaml.type_declaration SEP "and" ->
          gen_ast loc tdl ] ]
  ;
END;