[@@@ocaml.warning "-23"]

[@@@ocaml.warning "-37"]

[@@@ocaml.warning "-32"]

let print_list f sep ppf l =
  Format.pp_print_list
    ~pp_sep:(fun ppf () -> Format.fprintf ppf "%s@ " sep)
    f ppf l

module MSet (M : Set.OrderedType) = struct
  include Set.Make (M)

  let ( += ) r v = r := add v !r
end

module Arity = struct
  type t = int

  module Set = MSet (Int)
end

module Closure_type = struct
  module M = struct
    type t =
      { arity : int
      ; fields : int
      }

    let compare = compare
  end

  include M
  module Set = MSet (M)
end

module C_import = struct
  module M = struct
    type t = Primitive.description

    let compare = compare
  end

  include M
  module Set = MSet (M)
end

module State = struct
  let arities = ref Arity.Set.empty

  let caml_applies = ref Arity.Set.empty

  let block_sizes = ref Arity.Set.empty

  let block_float_sizes = ref Arity.Set.empty

  let closure_types = ref Closure_type.Set.empty

  let c_imports = ref C_import.Set.empty

  let add_arity (i : Arity.t) = Arity.Set.(arities += i)

  let add_caml_apply (i : Arity.t) = Arity.Set.(caml_applies += i)

  let add_block_size i = Arity.Set.(block_sizes += i)

  let add_block_float_size i = Arity.Set.(block_float_sizes += i)

  let add_closure_type ~arity ~fields =
    Closure_type.Set.(closure_types += { arity; fields })

  let add_c_import description = C_import.Set.(c_imports += description)

  let reset () =
    arities := Arity.Set.empty;
    caml_applies := Arity.Set.empty;
    block_sizes := Arity.Set.singleton 0;
    block_float_sizes := Arity.Set.singleton 0;
    closure_types := Closure_type.Set.empty;
    c_imports := C_import.Set.empty
end

module Type = struct
  module Var = struct
    type t =
      | V of string * int
      | Partial_closure of int * int
      | Func of { arity : int }
      | Closure of
          { arity : int
          ; fields : int
          }
      | Gen_closure of { arity : int }
      | Env
      | Block of { size : int }
      | BlockFloat of { size : int }
      | Set_of_closures of Set_of_closures_id.t
      | Gen_block
      | I31
      | Float
      | Int32
      | Int64
      | Nativeint
      | String
      | Array
      | FloatArray

    let name = function
      | V (name, n) -> Format.asprintf "$%s_%i" name n
      | Partial_closure (n, m) -> Format.asprintf "$Partial_closure_%i_%i" n m
      | Env -> Format.asprintf "$Env"
      | Func { arity } -> Format.asprintf "$Func_%i" arity
      | Block { size } -> Format.asprintf "$Block_%i" size
      | BlockFloat { size } -> Format.asprintf "$BlockFloat_%i" size
      | Gen_block -> Format.asprintf "$Gen_block"
      | Closure { arity; fields } ->
        Format.asprintf "$Closure_%i_%i" arity fields
      | Gen_closure { arity } -> Format.asprintf "$Gen_closure_%i" arity
      | Set_of_closures set ->
        Format.asprintf "$Set_of_closures_%a" Set_of_closures_id.print set
      | Float -> "$Float"
      | Int32 -> "$Int32"
      | Int64 -> "$Int64"
      | Nativeint -> "$Nativeint"
      | String -> "$String"
      | Array -> "$Array"
      | FloatArray -> "$FloatArray"
      | I31 -> "i31"

    let print ppf v = Format.pp_print_string ppf (name v)
  end

  type atom =
    | I8
    | I16
    | I32
    | I64
    | F64
    | Any
    | Rvar of Var.t

  type descr =
    | Struct of
        { sub : Var.t option
        ; fields : atom list
        }
    | Array of
        { sub : Var.t option
        ; fields : atom
        }
    | Func of
        { params : atom list
        ; result : atom option
        }

  let print_atom ppf = function
    | I8 -> Format.fprintf ppf "i8"
    | I16 -> Format.fprintf ppf "i16"
    | I32 -> Format.fprintf ppf "i32"
    | I64 -> Format.fprintf ppf "i64"
    | F64 -> Format.fprintf ppf "f64"
    | Any -> Format.fprintf ppf "ref_any"
    | Rvar v -> Format.fprintf ppf "ref_%a" Var.print v

  let print_descr ppf = function
    | Struct { sub; fields = atoms } ->
      let pp_sub ppf = function
        | None -> ()
        | Some sub -> Format.fprintf ppf "sub: %a;@ " Var.print sub
      in
      Format.fprintf ppf "@[<hov 2>Struct {%a%a}@]" pp_sub sub
        (print_list print_atom ";")
        atoms
    | Array { sub; fields = atom } ->
      let pp_sub ppf = function
        | None -> ()
        | Some sub -> Format.fprintf ppf "sub: %a;@ " Var.print sub
      in
      Format.fprintf ppf "@[<hov 2>Array {%a%a}@]" pp_sub sub print_atom atom
    | Func { params; result = None } ->
      Format.fprintf ppf "@[<hov 2>Func {%a}@]"
        (print_list print_atom ",")
        params
    | Func { params; result = Some result } ->
      Format.fprintf ppf "@[<hov 2>Func {%a} ->@ %a@]"
        (print_list print_atom ",")
        params print_atom result
end

module Func_id = struct
  type t =
    | V of string * int
    | Symbol of Symbol.t
    | Caml_curry of int * int
    | Caml_apply of int
    | C_import of string
    | Start

  let name = function
    | V (name, n) -> Format.asprintf "%s_%i" name n
    | Symbol s -> Format.asprintf "%a" Symbol.print s
    | Caml_curry (n, m) ->
      if m = 0 then Format.asprintf "Caml_curry_%i" n
      else Format.asprintf "Caml_curry_%i_%i" n m
    | Caml_apply n -> Format.asprintf "Caml_apply_%i" n
    | C_import s -> Format.asprintf "C_%s" s
    | Start -> "Start"

  let print ppf = function
    | V (name, n) -> Format.fprintf ppf "%s_%i" name n
    | Symbol s -> Symbol.print ppf s
    | Caml_curry (n, m) ->
      if m = 0 then Format.fprintf ppf "Caml_curry_%i" n
      else Format.fprintf ppf "Caml_curry_%i_%i" n m
    | Caml_apply n -> Format.fprintf ppf "Caml_apply_%i" n
    | C_import s -> Format.fprintf ppf "C_%s" s
    | Start -> Format.pp_print_string ppf "Start"

  let of_var_closure_id var =
    let name, id = Variable.unique_name_id var in
    V (name, id)

  let of_closure_id closure_id =
    let var = Closure_id.unwrap closure_id in
    of_var_closure_id var

  let prim_func_name ({ prim_native_name; prim_name } : Primitive.description) =
    if prim_native_name <> "" then prim_native_name else prim_name

  let prim_name descr = C_import (prim_func_name descr)
end

module Param = struct
  type t =
    | P of string * int
    | Env

  let print ppf = function
    | P (name, n) -> Format.fprintf ppf "P(%s_%i)" name n
    | Env -> Format.fprintf ppf "Env"

  let name = function
    | P (name, n) -> Format.asprintf "P_%s_%i" name n
    | Env -> "Env"

  let of_var v =
    let n, i = Variable.unique_name_id v in
    P (n, i)
end

module Global = struct
  type t =
    | S of string
    | Module_block
    | Closure of Variable.t

  let name = function
    | S name -> Format.asprintf "%s" name
    | Module_block -> Format.asprintf "Module_block"
    | Closure v -> Format.asprintf "Closure_%s" (Variable.unique_name v)

  let print ppf = function
    | S name -> Format.fprintf ppf "G(%s)" name
    | Module_block -> Format.fprintf ppf "Module_block"
    | Closure v -> Format.fprintf ppf "Closure %a" Variable.print v

  let of_symbol s =
    let linkage_name = Symbol.label s in
    let name = Linkage_name.to_string linkage_name in
    S name
end

module Expr = struct
  module Local = struct
    type var =
      | Variable of Variable.t
      | Mutable of Mutable_variable.t
      | Fresh of string * int
      | Partial_closure
      | Closure
      | Indirec_call_closure of { arity : int }

    let var_name = function
      | Variable v ->
        let name, id = Variable.unique_name_id v in
        Format.asprintf "%s_%i" name id
      | Mutable v ->
        let name, id = Mutable_variable.unique_name_id v in
        Format.asprintf "%s@%i" name id
      | Fresh (name, n) -> Format.asprintf "%s#%i" name n
      | Partial_closure -> "Partial_closure"
      | Closure -> "Closure"
      | Indirec_call_closure { arity } ->
        Format.asprintf "Indirec_call_closure_%i" arity

    let print_var ppf var = Format.pp_print_string ppf (var_name var)

    type t =
      | V of var
      | Param of Param.t

    let print ppf = function
      | V v -> print_var ppf v
      | Param p -> Param.print ppf p

    let var_of_var v = Variable v

    let var_of_mut_var v = Mutable v

    let of_var v = V (Variable v)

    let name = function V v -> var_name v | Param p -> Param.name p

    module M = struct
      type nonrec t = var

      let compare = compare
    end

    module Map = Map.Make (M)
  end

  type binop =
    | I32_add
    | I32_sub
    | I32_mul
    | F64_add
    | F64_sub
    | F64_mul
    | F64_div
    | Struct_set of
        { typ : Type.Var.t
        ; field : int
        }

  type unop =
    | I31_get_s
    | I31_new
    | Drop
    | Struct_get of
        { typ : Type.Var.t
        ; field : int
        }

  type t =
    | Var of Local.t
    | I32 of int32
    | I64 of int64
    | F64 of float
    | Ref_func of Func_id.t
    | Let of
        { var : Local.var
        ; typ : Type.atom
        ; defining_expr : t
        ; body : t
        }
    | Binop of binop * (t * t)
    | Unop of unop * t
    | Struct_new of Type.Var.t * t list
    | Array_new_fixed of
        { typ : Type.Var.t
        ; fields : t list
        }
    | Call_ref of
        { typ : Type.Var.t
        ; args : t list
        ; func : t
        }
    | Call of
        { args : t list
        ; func : Func_id.t
        }
    | Ref_cast of
        { typ : Type.Var.t
        ; r : t
        }
    | Global_get of Global.t
    | Seq of t list
    | Assign of
        { being_assigned : Local.var
        ; new_value : t
        }

  let print_binop ppf = function
    | I32_add -> Format.fprintf ppf "I32_add"
    | I32_sub -> Format.fprintf ppf "I32_sub"
    | I32_mul -> Format.fprintf ppf "I32_mul"
    | F64_add -> Format.fprintf ppf "F64_add"
    | F64_sub -> Format.fprintf ppf "F64_sub"
    | F64_mul -> Format.fprintf ppf "F64_mul"
    | F64_div -> Format.fprintf ppf "F64_div"
    | Struct_set { typ; field } ->
      Format.fprintf ppf "@[<hov 2>Struct_set(%a).(%i)@]" Type.Var.print typ
        field

  let print_unop ppf = function
    | I31_get_s -> Format.fprintf ppf "I31_get_s"
    | I31_new -> Format.fprintf ppf "I31_new"
    | Drop -> Format.fprintf ppf "Drop"
    | Struct_get { typ; field } ->
      Format.fprintf ppf "@[<hov 2>Struct_get(%a).(%i)@]" Type.Var.print typ
        field

  let rec print ppf = function
    | Var l -> Local.print ppf l
    | I32 i -> Format.fprintf ppf "%li" i
    | I64 i -> Format.fprintf ppf "%Li" i
    | F64 f -> Format.fprintf ppf "%g" f
    | Ref_func f -> Format.fprintf ppf "Ref_func %a" Func_id.print f
    | Let { var; defining_expr; body } ->
      Format.fprintf ppf "@[<hov 2>Let %a =@ %a@]@ in@ %a" Local.print_var var
        print defining_expr print body
    | Binop (binop, (arg1, arg2)) ->
      Format.fprintf ppf "@[<hov 2>Binop(%a:@ %a,@ %a)@]" print_binop binop
        print arg1 print arg2
    | Unop (unop, arg) ->
      Format.fprintf ppf "@[<hov 2>Unop(%a:@ %a)@]" print_unop unop print arg
    | Struct_new (typ, args) ->
      Format.fprintf ppf "@[<hov 2>Struct_new(%a:@ %a)@]" Type.Var.print typ
        (print_list print ",") args
    | Array_new_fixed { typ; fields } ->
      Format.fprintf ppf "@[<hov 2>Array_new_fixed(%a:@ %a)@]" Type.Var.print
        typ (print_list print ",") fields
    | Call_ref { typ; args; func } ->
      Format.fprintf ppf "@[<hov 2>Call_ref(%a:@ %a(%a))@]" Type.Var.print typ
        print func (print_list print ",") args
    | Call { args; func } ->
      Format.fprintf ppf "@[<hov 2>Call(%a(%a))@]" Func_id.print func
        (print_list print ",") args
    | Ref_cast { typ; r } ->
      Format.fprintf ppf "@[<hov 2>Ref_cast(%a:@ %a)@]" Type.Var.print typ print
        r
    | Global_get g ->
      Format.fprintf ppf "@[<hov 2>Global_get(%a)@]" Global.print g
    | Seq l -> Format.fprintf ppf "@[<v 2>Seq(%a)@]" (print_list print ";") l
    | Assign { being_assigned; new_value } ->
      Format.fprintf ppf "@[<v 2>Assign(%a <- %a)@]" Local.print_var
        being_assigned print new_value

  let let_ var typ defining_expr body = Let { var; typ; defining_expr; body }

  let required_locals expr =
    let add var typ acc =
      match Local.Map.find var acc with
      | prev_typ ->
        assert (typ = prev_typ);
        acc
      | exception Not_found -> Local.Map.add var typ acc
    in
    let rec loop acc = function
      | Var _ | I32 _ | I64 _ | F64 _ | Ref_func _ -> acc
      | Let { var; typ; defining_expr; body } ->
        let acc = add var typ acc in
        let acc = loop acc defining_expr in
        loop acc body
      | Binop (_op, (arg1, arg2)) ->
        let acc = loop acc arg1 in
        loop acc arg2
      | Unop (_op, arg) -> loop acc arg
      | Struct_new (_typ, args) ->
        List.fold_left (fun acc arg -> loop acc arg) acc args
      | Array_new_fixed { typ = _; fields } ->
        List.fold_left (fun acc arg -> loop acc arg) acc fields
      | Call_ref { typ = _; args; func } ->
        List.fold_left (fun acc arg -> loop acc arg) (loop acc func) args
      | Call { args; func = _ } ->
        List.fold_left (fun acc arg -> loop acc arg) acc args
      | Ref_cast { typ = _; r } -> loop acc r
      | Global_get _ -> acc
      | Seq l -> List.fold_left (fun acc arg -> loop acc arg) acc l
      | Assign { being_assigned = _; new_value } -> loop acc new_value
    in
    loop Local.Map.empty expr
end

module Func = struct
  type t =
    | Decl of
        { params : (Param.t * Type.atom) list
        ; result : Type.atom option
        ; body : Expr.t
        }
    | Import of
        { params : Type.atom list
        ; result : Type.atom list
        ; module_ : string
        ; name : string
        }

  let print ppf = function
    | Decl { params; result; body } ->
      let pr_result ppf = function
        | None -> ()
        | Some result -> Format.fprintf ppf " -> %a" Type.print_atom result
      in
      let param ppf (p, typ) =
        Format.fprintf ppf "(%a: %a)" Param.print p Type.print_atom typ
      in
      Format.fprintf ppf "@[<hov 2>Func (%a)%a@ {@ %a@ }@]"
        (print_list param ",") params pr_result result Expr.print body
    | Import { params; result; module_; name } ->
      Format.fprintf ppf "@[<hov 2>Import %s %s : (%a) -> %a @]" module_ name
        (print_list Type.print_atom ",")
        params
        (print_list Type.print_atom ",")
        result
end

module Const = struct
  type field =
    | I8 of int
    | I16 of int
    | Ref_func of Func_id.t
    | Global of Global.t
    | I31 of int

  type t =
    | Struct of
        { typ : Type.Var.t
        ; fields : field list
        }
    | Expr of
        { typ : Type.atom
        ; e : Expr.t
        }

  let print_field ppf = function
    | I8 i -> Format.fprintf ppf "i8(%i)" i
    | I16 i -> Format.fprintf ppf "i16(%i)" i
    | I31 i -> Format.fprintf ppf "i31(%i)" i
    | Ref_func f -> Format.fprintf ppf "Ref_func %a" Func_id.print f
    | Global g -> Format.fprintf ppf "%a" Global.print g
end

module Decl = struct
  type t =
    | Type of Type.Var.t * Type.descr
    | Type_rec of (Type.Var.t * Type.descr) list
    | Func of
        { name : Func_id.t
        ; descr : Func.t
        }
    | Const of
        { name : Global.t
        ; descr : Const.t
        }

  let print ppf = function
    | Type (var, descr) ->
      Format.fprintf ppf "type %a = %a" Type.Var.print var Type.print_descr
        descr
    | Type_rec l ->
      let pp ppf (var, descr) =
        Format.fprintf ppf "(%a = %a)" Type.Var.print var Type.print_descr descr
      in
      Format.fprintf ppf "type_rec %a" (print_list pp "") l
    | Func { name; descr } ->
      Format.fprintf ppf "@[<hov 2>func %a =@ %a@]" Func_id.print name
        Func.print descr
    | Const { name; descr = Struct { typ; fields } } ->
      Format.fprintf ppf "@[<hov 2>const %a : %a =@ {%a}@]" Global.print name
        Type.Var.print typ
        (print_list Const.print_field ";")
        fields
    | Const { name; descr = Expr { typ; e } } ->
      Format.fprintf ppf "@[<hov 2>const %a : %a =@ {%a}@]" Global.print name
        Type.print_atom typ Expr.print e
end

module Module = struct
  type t = Decl.t list

  let print ppf l =
    Format.fprintf ppf "@[<v 2>Module {@ %a@ }@]"
      (Format.pp_print_list
         ~pp_sep:(fun ppf () -> Format.fprintf ppf "@ ")
         Decl.print )
      l
end

module Conv = struct
  type top_env = { offsets : Wasm_closure_offsets.result }

  type env =
    { bound_vars : Variable.Set.t
    ; params : Variable.Set.t
    ; closure_vars : Variable.Set.t
    ; mutables : Mutable_variable.Set.t
    ; current_function : Closure_id.t option
    ; top_env : top_env
    }

  let empty_env ~top_env =
    { bound_vars = Variable.Set.empty
    ; params = Variable.Set.empty
    ; closure_vars = Variable.Set.empty
    ; mutables = Mutable_variable.Set.empty
    ; current_function = None
    ; top_env
    }

  let enter_function ~top_env ~closure_id ~params ~free_vars =
    let params =
      List.fold_left
        (fun params p -> Variable.Set.add (Parameter.var p) params)
        Variable.Set.empty params
    in
    let closure_vars = Variable.Set.diff free_vars params in
    { bound_vars = Variable.Set.empty
    ; params
    ; closure_vars
    ; mutables = Mutable_variable.Set.empty
    ; current_function = Some closure_id
    ; top_env
    }

  module Closure = struct
    let cast r : Expr.t = Ref_cast { typ = Env; r }

    let get_arity e : Expr.t = Unop (Struct_get { typ = Env; field = 0 }, e)

    let get_gen_func e : Expr.t = Unop (Struct_get { typ = Env; field = 1 }, e)

    let get_direct_func e ~arity : Expr.t =
      if arity = 1 then get_gen_func e
      else Unop (Struct_get { typ = Gen_closure { arity }; field = 2 }, e)

    let project_closure (top_env : top_env) closure_id set_of_closures : Expr.t
        =
      let accessor =
        Closure_id.Map.find closure_id top_env.offsets.function_accessors
      in
      if not accessor.recursive_set then set_of_closures
      else
        let typ : Type.Var.t = Set_of_closures accessor.set in
        Unop (Struct_get { typ; field = accessor.field }, set_of_closures)

    let project_var ?(cast : unit option) (top_env : top_env) closure_id var
        closure : Expr.t =
      let accessor =
        Var_within_closure.Map.find var top_env.offsets.free_variable_accessors
      in
      let closure_info =
        Closure_id.Map.find closure_id top_env.offsets.function_accessors
      in
      if not accessor.recursive_set then begin
        let typ : Type.Var.t =
          Closure { arity = closure_info.arity; fields = accessor.closure_size }
        in
        let closure : Expr.t =
          match cast with
          | None -> closure
          | Some () -> Ref_cast { typ; r = closure }
        in
        State.add_closure_type ~arity:closure_info.arity
          ~fields:accessor.closure_size;
        Unop (Struct_get { typ; field = accessor.field }, closure)
      end
      else
        let closure_typ : Type.Var.t =
          Closure { arity = closure_info.arity; fields = 1 }
        in
        let closure : Expr.t =
          match cast with
          | None -> closure
          | Some () -> Ref_cast { typ = closure_typ; r = closure }
        in
        State.add_closure_type ~arity:closure_info.arity ~fields:1;
        let set_typ : Type.Var.t = Set_of_closures closure_info.set in
        let set_of_closures : Expr.t =
          Ref_cast
            { typ = set_typ
            ; r = Unop (Struct_get { typ = closure_typ; field = 1 }, closure)
            }
        in
        Unop
          (Struct_get { typ = set_typ; field = accessor.field }, set_of_closures)
  end

  module Block = struct
    let get_field ?(cast : unit option) e ~field : Expr.t =
      let size = field + 1 in
      State.add_block_size size;
      let typ : Type.Var.t = Block { size } in
      let e =
        match cast with None -> e | Some () -> Expr.(Ref_cast { typ; r = e })
      in
      Unop (Struct_get { typ; field = field + 2 }, e)

    let set_field ?(cast : unit option) ~block value ~field : Expr.t =
      let size = field + 1 in
      State.add_block_size size;
      let typ : Type.Var.t = Block { size } in
      let block =
        match cast with
        | None -> block
        | Some () -> Expr.(Ref_cast { typ; r = block })
      in
      Binop (Struct_set { typ; field = field + 2 }, (block, value))
  end

  let const_float f : Expr.t = Struct_new (Float, [ F64 f ])

  let const_int32 i : Expr.t = Struct_new (Int32, [ I32 i ])

  let const_int64 i : Expr.t = Struct_new (Int64, [ I64 i ])

  let const_nativeint i : Expr.t =
    Struct_new (Nativeint, [ I32 (Nativeint.to_int32 i) ])

  let const_string s : Expr.t =
    let fields =
      String.fold_right
        (fun c l -> Expr.I32 (Int32.of_int (Char.code c)) :: l)
        s []
    in
    Array_new_fixed { typ = String; fields }

  let bind_var env var =
    { env with bound_vars = Variable.Set.add var env.bound_vars }

  let bind_mutable_var env var =
    { env with mutables = Mutable_variable.Set.add var env.mutables }

  let conv_var (env : env) (var : Variable.t) : Expr.t =
    begin
      if Variable.Set.mem var env.params then
        Var (Expr.Local.Param (Param.of_var var))
      else if Variable.Set.mem var env.bound_vars then
        Var (Expr.Local.of_var var)
      else if Variable.Set.mem var env.closure_vars then
        match env.current_function with
        | None -> assert false
        | Some closure_id ->
          Closure.project_var ~cast:() env.top_env closure_id
            (Var_within_closure.wrap var)
            (Var (Param Env))
      else Misc.fatal_errorf "Unbound variable %a" Variable.print var
    end

  let dummy_const = 123456789

  let unit_value : Expr.t = Unop (I31_new, I32 0l)

  let rec expr_is_pure (e : Expr.t) =
    match e with
    | Var _ | I32 _ | I64 _ | F64 _ | Global_get _ -> true
    | Unop (I31_new, e) -> expr_is_pure e
    | Let { defining_expr; body } ->
      expr_is_pure defining_expr && expr_is_pure body
    | _ -> false

  let seq l : Expr.t = match l with [ e ] -> e | _ -> Seq l

  let rec drop (expr : Expr.t) : Expr.t =
    match expr with
    | Seq l -> seq (drop_list l)
    | Let { typ; var; defining_expr; body } ->
      Let { typ; var; defining_expr; body = drop body }
    | _ -> Unop (Drop, expr)

  and drop_list (l : Expr.t list) =
    match l with
    | [] -> []
    | [ e ] -> if expr_is_pure e then [] else [ drop e ]
    | h :: t -> h :: drop_list t

  let const_block ~symbols_being_bound tag fields :
      Const.t * (int * Symbol.t) list =
    let size = List.length fields in
    State.add_block_size size;
    let fields_to_update = ref [] in
    let field i (f : Flambda.constant_defining_value_block_field) : Const.field
        =
      match f with
      | Symbol s ->
        if Symbol.Set.mem s symbols_being_bound then begin
          fields_to_update := (i, s) :: !fields_to_update;
          I31 dummy_const
        end
        else Global (Global.of_symbol s)
      | Const (Int i) -> I31 i
      | Const (Char c) -> I31 (Char.code c)
    in
    let fields =
      [ Const.I8 (Tag.to_int tag); Const.I16 size ] @ List.mapi field fields
    in
    (Struct { typ = Type.Var.Block { size }; fields }, !fields_to_update)

  let box_float x : Expr.t = Struct_new (Type.Var.Float, [ x ])

  let unbox_float x : Expr.t =
    let typ = Type.Var.Float in
    Unop (Struct_get { typ; field = 0 }, Ref_cast { typ; r = x })

  let box_int (kind : Primitive.boxed_integer) x : Expr.t =
    let typ : Type.Var.t =
      match kind with
      | Pint32 -> Int32
      | Pint64 -> Int64
      | Pnativeint -> Nativeint
    in
    Struct_new (typ, [ x ])

  let unbox_int (kind : Primitive.boxed_integer) x : Expr.t =
    let typ : Type.Var.t =
      match kind with
      | Pint32 -> Int32
      | Pint64 -> Int64
      | Pnativeint -> Nativeint
    in
    Unop (Struct_get { typ; field = 0 }, Ref_cast { typ; r = x })

  let conv_apply env (apply : Flambda.apply) : Expr.t =
    match apply.kind with
    | Indirect -> begin
      match apply.args with
      | [] -> assert false
      | [ arg ] ->
        let func_typ = Type.Var.Func { arity = 1 } in
        let var : Expr.Local.var = Indirec_call_closure { arity = 1 } in
        let closure : Expr.t = Closure.cast (conv_var env apply.func) in
        let func : Expr.t = Closure.get_gen_func (Var (V var)) in
        let args : Expr.t list = [ conv_var env arg; Var (V var) ] in
        Let
          { var
          ; typ = Rvar Env
          ; defining_expr = closure
          ; body = Call_ref { typ = func_typ; func; args }
          }
      | _ :: _ :: _ ->
        let arity = List.length apply.args in
        let args =
          Closure.cast (conv_var env apply.func)
          :: List.map (conv_var env) apply.args
        in
        State.add_caml_apply arity;
        Call { func = Caml_apply arity; args }
    end
    | Direct closure_id ->
      let func = Func_id.of_closure_id closure_id in
      let args =
        List.map (conv_var env) apply.args
        @ [ Closure.cast (conv_var env apply.func) ]
      in
      Call { func; args }

  let conv_allocated_const (const : Allocated_const.t) : Const.t =
    match const with
    | Float f -> Expr { typ = Rvar Float; e = const_float f }
    | Int32 i -> Expr { typ = Rvar Int32; e = const_int32 i }
    | Int64 i -> Expr { typ = Rvar Int64; e = const_int64 i }
    | Nativeint i -> Expr { typ = Rvar Nativeint; e = const_nativeint i }
    | Immutable_string s | String s ->
      Expr { typ = Rvar String; e = const_string s }
    | Float_array _ | Immutable_float_array _ ->
      failwith
        (Format.asprintf "TODO allocated const %a" Allocated_const.print const)

  let closure_type (set_of_closures : Flambda.set_of_closures) =
    let Flambda.{ function_decls; free_vars } = set_of_closures in
    let is_recursive = Variable.Map.cardinal function_decls.funs > 1 in
    if not is_recursive then None
    else begin
      let func_types =
        Variable.Map.fold
          (fun _id (function_decl : Flambda.function_declaration) acc ->
            let arity = Flambda_utils.function_arity function_decl in
            let typ : Type.atom = Rvar (Closure { arity; fields = 1 }) in
            typ :: acc )
          function_decls.funs []
      in
      let rev_fields =
        Variable.Map.fold
          (fun _id _var acc ->
            let typ : Type.atom = Any in
            typ :: acc )
          free_vars func_types
      in
      let descr : Type.descr =
        Struct { sub = None; fields = List.rev rev_fields }
      in
      let name : Type.Var.t =
        Set_of_closures function_decls.set_of_closures_id
      in
      Some (Decl.Type (name, descr))
    end

  let closure_types (program : Flambda.program) =
    List.filter_map closure_type (Flambda_utils.all_sets_of_closures program)

  let rec conv_body (env : top_env) (expr : Flambda.program_body) effects :
      Module.t =
    match expr with
    | Let_symbol (symbol, Set_of_closures set, body) ->
      let decl = closed_function_declarations symbol set.function_decls in
      let body = conv_body env body effects in
      decl @ body
    | Let_symbol (symbol, const, body) ->
      let decls, new_effects =
        conv_symbol ~symbols_being_bound:Symbol.Set.empty symbol const
      in
      assert (new_effects = []);
      let body = conv_body env body effects in
      decls @ body
    | Let_rec_symbol (decls, body) ->
      let symbols_being_bound =
        List.fold_left
          (fun set (symbol, _) -> Symbol.Set.add symbol set)
          Symbol.Set.empty decls
      in
      let decls, effects =
        List.fold_left
          (fun (decls, effects) (symbol, const) ->
            let decl, new_effecs =
              conv_symbol ~symbols_being_bound symbol const
            in
            (decl @ decls, new_effecs @ effects) )
          ([], effects) decls
      in
      let body = conv_body env body effects in
      decls @ body
    | Initialize_symbol (symbol, tag, fields, body) ->
      let decl, effect = conv_initialize_symbol env symbol tag fields in
      decl :: conv_body env body (effect @ effects)
    | Effect (expr, body) ->
      let expr_env = empty_env ~top_env:env in
      let effect : Expr.t = drop (conv_expr expr_env expr) in
      conv_body env body (effect :: effects)
    | End _end_symbol ->
      [ Decl.Func
          { name = Start
          ; descr =
              Decl { params = []; result = None; body = Seq (List.rev effects) }
          }
      ]

  and conv_initialize_symbol env symbol tag fields =
    let size = List.length fields in
    let fields =
      List.mapi
        (fun i field ->
          (i, field, Initialize_symbol_to_let_symbol.constant_field field) )
        fields
    in
    let fields_to_update = ref [] in
    let predefined_fields =
      List.map
        (fun (i, expr, field) : Const.field ->
          match field with
          | None ->
            let expr_env = empty_env ~top_env:env in
            let expr = conv_expr expr_env expr in
            fields_to_update := (i, expr) :: !fields_to_update;
            I31 dummy_const
          | Some (field : Flambda.constant_defining_value_block_field) -> (
            match field with
            | Symbol s -> Global (Global.of_symbol s)
            | Const (Int i) -> I31 i
            | Const (Char c) -> I31 (Char.code c) ) )
        fields
    in
    let name = Global.of_symbol symbol in
    let descr : Const.t =
      let fields =
        [ Const.I8 (Tag.to_int tag); Const.I16 size ] @ predefined_fields
      in
      Struct { typ = Type.Var.Block { size }; fields }
    in
    let decl = Decl.Const { name; descr } in
    let size = List.length fields in
    State.add_block_size size;
    let effect (field, expr) : Expr.t =
      Block.set_field ~field
        ~block:(Expr.Global_get (Global.of_symbol symbol))
        expr
    in
    let effect = List.map effect !fields_to_update in
    (decl, effect)

  and conv_symbol ~symbols_being_bound symbol
      (const : Flambda.constant_defining_value) : Decl.t list * Expr.t list =
    match const with
    | Block (tag, fields) ->
      let name = Global.of_symbol symbol in
      let descr, fields_to_update =
        const_block ~symbols_being_bound tag fields
      in
      let new_effects =
        List.map
          (fun (field_to_update, field_contents) : Expr.t ->
            Block.set_field ~field:field_to_update
              ~block:(Expr.Global_get (Global.of_symbol symbol))
              (Expr.Global_get (Global.of_symbol field_contents)) )
          fields_to_update
      in
      ([ Const { name; descr } ], new_effects)
    | Project_closure (_sym, _closure_id) -> ([], [])
    | Set_of_closures set ->
      let decl = closed_function_declarations symbol set.function_decls in
      (decl, [])
    | Allocated_const const ->
      let name = Global.of_symbol symbol in
      let descr = conv_allocated_const const in
      ([ Const { name; descr } ], [])

  and closed_function_declarations _symbol
      (declarations : Flambda.function_declarations) : Decl.t list =
    Variable.Map.fold
      (fun name (declaration : Flambda.function_declaration) declarations ->
        let function_name = Func_id.of_var_closure_id name in
        let arity = List.length declaration.params in
        let closure =
          let fields : Const.field list =
            State.add_arity arity;
            State.add_closure_type ~arity ~fields:0;
            if arity = 1 then [ I8 1; Ref_func function_name ]
            else
              [ I8 arity
              ; Ref_func (Func_id.Caml_curry (arity, 0))
              ; Ref_func function_name
              ]
          in
          Const.Struct { typ = Type.Var.Closure { arity; fields = 0 }; fields }
        in
        let closure_name =
          let closure_symbol =
            Compilenv.closure_symbol (Closure_id.wrap name)
          in
          Global.of_symbol closure_symbol
        in
        Decl.Const { name = closure_name; descr = closure } :: declarations )
      declarations.funs []

  and conv_set_of_closures env (set_of_closures : Flambda.set_of_closures) :
      Expr.t =
    let function_decls = set_of_closures.function_decls in
    let is_recursive = Variable.Map.cardinal function_decls.funs > 1 in
    if not is_recursive then begin
      let func_var, function_decl = Variable.Map.choose function_decls.funs in
      let arity = Flambda_utils.function_arity function_decl in
      let fields = Variable.Map.cardinal set_of_closures.free_vars in
      State.add_closure_type ~arity ~fields;
      let typ : Type.Var.t = Closure { arity; fields } in
      let rev_value_fields =
        Variable.Map.fold
          (fun _id (var : Flambda.specialised_to) acc ->
            conv_var env var.var :: acc )
          set_of_closures.free_vars []
      in
      let func_id = Func_id.of_var_closure_id func_var in
      let head_fields =
        if arity = 1 then Expr.[ I32 1l; Ref_func func_id ]
        else
          Expr.
            [ I32 (Int32.of_int arity)
            ; Ref_func (Func_id.Caml_curry (arity, 0))
            ; Ref_func func_id
            ]
      in
      Expr.Struct_new (typ, head_fields @ List.rev rev_value_fields)
    end
    else begin
      failwith "Recursive set of closures"
    end

  and conv_function_declaration ~top_env function_name
      (declaration : Flambda.function_declaration) : Decl.t =
    let arity = List.length declaration.params in
    let closure_id = Closure_id.wrap function_name in
    State.add_arity arity;
    let params =
      List.map
        (fun p -> (Param.of_var (Parameter.var p), Type.Any))
        declaration.params
    in
    let env =
      enter_function ~closure_id ~params:declaration.params
        ~free_vars:declaration.free_variables ~top_env
    in
    let body = conv_expr env declaration.body in
    let func =
      Func.Decl
        { params = params @ [ (Param.Env, Type.Rvar Type.Var.Env) ]
        ; result = Some Type.Any
        ; body
        }
    in
    let name = Func_id.of_var_closure_id function_name in
    Decl.Func { name; descr = func }

  and conv_expr (env : env) (expr : Flambda.t) : Expr.t =
    match expr with
    | Let { var; defining_expr; body = Var v; _ } when Variable.equal var v ->
      conv_named env defining_expr
    | Let { var; defining_expr; body; _ } ->
      let local = Expr.Local.var_of_var var in
      let defining_expr = conv_named env defining_expr in
      let body = conv_expr (bind_var env var) body in
      Let { var = local; typ = Type.Any; defining_expr; body }
    | Var var -> conv_var env var
    | Apply apply -> conv_apply env apply
    | Let_mutable { var; initial_value; contents_kind = _; body } ->
      let local = Expr.Local.var_of_mut_var var in
      let defining_expr = conv_var env initial_value in
      let body = conv_expr (bind_mutable_var env var) body in
      Let { var = local; typ = Type.Any; defining_expr; body }
    | Assign { being_assigned; new_value } ->
      assert (Mutable_variable.Set.mem being_assigned env.mutables);
      let being_assigned = Expr.Local.var_of_mut_var being_assigned in
      let new_value = conv_var env new_value in
      Seq [ Assign { being_assigned; new_value }; unit_value ]
    (* | If _ -> I *)
    | _ ->
      let msg = Format.asprintf "TODO (conv_expr) %a" Flambda.print expr in
      failwith msg

  and conv_named (env : env) (named : Flambda.named) : Expr.t =
    match named with
    | Prim (prim, args, _dbg) -> conv_prim env ~prim ~args
    | Symbol s -> Global_get (Global.of_symbol s)
    | Expr (Var var) -> conv_var env var
    | Const c ->
      let c = match c with Int i -> i | Char c -> Char.code c in
      Unop (I31_new, I32 (Int32.of_int c))
    | Expr e -> conv_expr env e
    | Read_symbol_field (symbol, field) ->
      Block.get_field ~field Expr.(Global_get (Global.of_symbol symbol))
    | Read_mutable mut_var -> Var (V (Expr.Local.var_of_mut_var mut_var))
    | Project_var project_var ->
      let closure = conv_var env project_var.closure in
      Closure.project_var env.top_env project_var.closure_id project_var.var
        closure
    | Project_closure project_closure ->
      let set_of_closures = conv_var env project_closure.set_of_closures in
      Closure.project_closure env.top_env project_closure.closure_id
        set_of_closures
    | Set_of_closures set -> conv_set_of_closures env set
    | _ ->
      let msg = Format.asprintf "TODO named %a" Flambda.print_named named in
      failwith msg

  and conv_prim env ~(prim : Clambda_primitives.primitive) ~args : Expr.t =
    let args = List.map (conv_var env) args in
    let arg1 args =
      match args with
      | [ a ] -> a
      | _ -> Misc.fatal_errorf "Wrong number of primitive arguments"
    in
    let args2 args =
      match args with
      | [ a; b ] -> (a, b)
      | _ -> Misc.fatal_errorf "Wrong number of primitive arguments"
    in
    let i32 v = Expr.Unop (I31_get_s, Ref_cast { typ = I31; r = v }) in
    let i31 v = Expr.Unop (I31_new, v) in
    match prim with
    | Paddint -> i31 (Expr.Binop (I32_add, args2 (List.map i32 args)))
    | Psubint -> i31 (Expr.Binop (I32_sub, args2 (List.map i32 args)))
    | Pmulint -> i31 (Expr.Binop (I32_mul, args2 (List.map i32 args)))
    | Paddfloat ->
      box_float (Expr.Binop (F64_add, args2 (List.map unbox_float args)))
    | Psubfloat ->
      box_float (Expr.Binop (F64_sub, args2 (List.map unbox_float args)))
    | Pmulfloat ->
      box_float (Expr.Binop (F64_mul, args2 (List.map unbox_float args)))
    | Pdivfloat ->
      box_float (Expr.Binop (F64_div, args2 (List.map unbox_float args)))
    | Pccall descr ->
      let unbox_arg (t : Primitive.native_repr) arg =
        match t with
        | Same_as_ocaml_repr -> arg
        | Unboxed_float -> unbox_float arg
        | Unboxed_integer kind -> unbox_int kind arg
        | Untagged_int -> i32 arg
      in
      let box_result (t : Primitive.native_repr) res =
        match t with
        | Same_as_ocaml_repr -> res
        | Unboxed_float -> box_float res
        | Unboxed_integer kind -> box_int kind res
        | Untagged_int -> i31 res
      in
      State.add_c_import descr;
      let args = List.map2 unbox_arg descr.prim_native_repr_args args in
      box_result descr.prim_native_repr_res
        (Call { args; func = Func_id.prim_name descr })
    | Pmakeblock (tag, _mut, _shape) ->
      let size = List.length args in
      Struct_new
        ( Block { size }
        , I32 (Int32.of_int tag) :: I32 (Int32.of_int size) :: args )
    | Pfield field ->
      let arg = arg1 args in
      Block.get_field ~field ~cast:() arg
    | Psetfield (field, _kind, _init) ->
      let block, value = args2 args in
      Seq [ Block.set_field ~cast:() ~field ~block value; unit_value ]
    | Popaque -> arg1 args
    | _ ->
      let msg =
        Format.asprintf "TODO prim %a" Printclambda_primitives.primitive prim
      in
      failwith msg

  let conv_functions ~top_env (flambda : Flambda.program) =
    List.fold_left
      (fun decls (set_of_closures : Flambda.set_of_closures) ->
        let function_decls = set_of_closures.function_decls in
        Variable.Map.fold
          (fun var function_declaration decls ->
            let decl =
              conv_function_declaration ~top_env var function_declaration
            in
            decl :: decls )
          function_decls.funs decls )
      []
      (Flambda_utils.all_sets_of_closures flambda)

  let block_type size : Type.descr =
    let fields = List.init size (fun _ -> Type.Any) in
    let sub : Type.Var.t =
      if size = 1 then Gen_block else Block { size = size - 1 }
    in
    Struct { sub = Some sub; fields = (* Tag *)
                                      I8 :: (* size *)
                                            I16 :: fields }

  let block_float_type size : Type.descr =
    let fields = List.init size (fun _ -> Type.F64) in
    let sub : Type.Var.t option =
      if size = 0 then None else Some (BlockFloat { size = size - 1 })
    in
    Struct { sub; fields = (* size *) I16 :: fields }

  let gen_closure_type ~arity : Type.descr =
    let head : Type.atom list =
      if arity = 1 then
        [ I8 (* arity *); Rvar (Func { arity = 1 }) (* generic func *) ]
      else
        [ I8 (* arity *)
        ; Rvar (Func { arity = 1 }) (* generic func *)
        ; Rvar (Func { arity }) (* direct call func *)
        ]
    in
    Struct { sub = Some Env; fields = head }

  let closure_type ~arity ~fields : Type.descr =
    let head : Type.atom list =
      if arity = 1 then
        [ I8 (* arity *); Rvar (Func { arity = 1 }) (* generic func *) ]
      else
        [ I8 (* arity *)
        ; Rvar (Func { arity = 1 }) (* generic func *)
        ; Rvar (Func { arity }) (* direct call func *)
        ]
    in
    let fields = List.init fields (fun _ -> Type.Any) in
    Struct { sub = Some (Gen_closure { arity }); fields = head @ fields }

  let partial_closure_type ~arity ~applied : Type.descr =
    let args = List.init applied (fun _ -> Type.Any) in
    let fields : Type.atom list =
      [ Type.I8 (* arity *)
      ; Type.Rvar (Func { arity = 1 }) (* generic func *)
      ; Type.Rvar (Gen_closure { arity })
      ]
      @ args
    in
    Struct { sub = Some Env; fields }

  let func_type size : Type.descr =
    let params = List.init size (fun _ -> Type.Any) in
    Func { params = params @ [ Type.Rvar Env ]; result = Some Any }

  let caml_curry_apply ~param_arg ~env_arg n =
    assert (n > 1);
    let partial_closure_arg_typ = Type.Var.Partial_closure (n, n - 1) in
    let partial_closure_var : Expr.Local.var = Partial_closure in
    let closure_arg_typ = Type.Var.Gen_closure { arity = n } in
    let closure_var : Expr.Local.var = Closure in
    let closure_args =
      let first_arg_field = 3 in
      List.init (n - 1) (fun i : Expr.t ->
          let field = first_arg_field + i in
          Unop
            ( Struct_get { typ = partial_closure_arg_typ; field }
            , Expr.Var (Expr.Local.V partial_closure_var) ) )
    in
    let args = closure_args @ [ Expr.Var param_arg; Expr.Var (V closure_var) ] in
    let func : Expr.t =
      Closure.get_direct_func (Expr.Var (Expr.Local.V closure_var)) ~arity:n
    in
    Expr.let_ partial_closure_var (Type.Rvar partial_closure_arg_typ)
      (Ref_cast { typ = partial_closure_arg_typ; r = Var env_arg })
      (Expr.let_ closure_var (Type.Rvar closure_arg_typ)
         (Unop
            ( Struct_get { typ = partial_closure_arg_typ; field = 2 }
            , Expr.Var (Expr.Local.V partial_closure_var) ) )
         (Expr.Call_ref { typ = Type.Var.Func { arity = n }; args; func }) )

  let caml_curry_alloc ~param_arg ~env_arg n m : Expr.t =
    (* arity, func, env, arg1..., argn-1, argn *)
    let closure_arg_typ = Type.Var.Partial_closure (n, m) in
    let closure_var : Expr.Local.var = Closure in
    let closure_local = Expr.Local.V closure_var in
    let closure_args =
      let first_arg_field = 3 in
      List.init m (fun i : Expr.t ->
          let field = first_arg_field + i in
          Unop
            (Struct_get { typ = closure_arg_typ; field }, Expr.Var closure_local) )
    in
    let closure_field =
      if m = 0 then
        Expr.Ref_cast
          { typ = Type.Var.Gen_closure { arity = n }; r = Var env_arg }
      else
        Expr.Unop
          ( Struct_get { typ = closure_arg_typ; field = 2 }
          , Expr.Var closure_local )
    in
    let fields =
      [ Expr.I32 1l; Expr.Ref_func (Caml_curry (n, m + 1)); closure_field ]
      @ closure_args @ [ Expr.Var param_arg ]
    in
    let body : Expr.t =
      Struct_new (Type.Var.Partial_closure (n, m + 1), fields)
    in
    if m = 0 then body
    else
      Expr.let_ closure_var (Type.Rvar closure_arg_typ)
        (Ref_cast { typ = closure_arg_typ; r = Var env_arg })
        body

  let caml_curry n m =
    let param_arg = Param.P ("arg", 0) in
    let env_arg = Param.Env in
    let body =
      if m = n - 1 then
        caml_curry_apply ~param_arg:(Expr.Local.Param param_arg)
          ~env_arg:(Expr.Local.Param env_arg) n
      else
        caml_curry_alloc ~param_arg:(Expr.Local.Param param_arg)
          ~env_arg:(Expr.Local.Param env_arg) n m
    in
    Func.Decl
      { params = [ (param_arg, Type.Any); (env_arg, Type.Rvar Type.Var.Env) ]
      ; result = Some Type.Any
      ; body
      }

  let caml_apply n =
    (* TODO apply direct if right number of arguments *)
    let closure_param = Param.P ("closure", 0) in
    let param_i i = Param.P ("param", i) in
    let params = List.init n (fun i -> (param_i i, Type.Any)) in
    let rec build closure_var n params : Expr.t =
      let mk_call param =
        Expr.Call_ref
          { typ = Func { arity = 1 }
          ; args = [ Var (Param param); Var closure_var ]
          ; func = Closure.get_gen_func (Var closure_var)
          }
      in
      match params with
      | [] -> assert false
      | [ (param, _typ) ] -> mk_call param
      | (param, _typ) :: params ->
        let var : Expr.Local.var = Fresh ("partial_closure", n) in
        let call : Expr.t = Closure.cast (mk_call param) in
        let body = build (Expr.Local.V var) (n + 1) params in
        Let { var; typ = Rvar Env; defining_expr = call; body }
    in
    let body = build (Param closure_param) 0 params in
    Func.Decl
      { params = (closure_param, Type.Rvar Env) :: params
      ; result = Some Type.Any
      ; body
      }

  let c_import (descr : Primitive.description) =
    let repr_type (t : Primitive.native_repr) : Type.atom =
      if descr.prim_native_name = "" then
        assert (t = Primitive.Same_as_ocaml_repr);
      match t with
      | Same_as_ocaml_repr -> Type.Any
      | Unboxed_float -> Type.F64
      | Unboxed_integer Pnativeint -> Type.I32
      | Unboxed_integer Pint32 -> Type.I32
      | Unboxed_integer Pint64 -> Type.I64
      | Untagged_int -> Type.I32
    in
    let params = List.map repr_type descr.prim_native_repr_args in
    let result = [ repr_type descr.prim_native_repr_res ] in
    Func.Import
      { params
      ; result
      ; module_ = "import"
      ; name = Func_id.prim_func_name descr
      }

  let func_1_and_env =
    let env =
      let fields : Type.atom list =
        [ I8 (* arity *); Rvar (Func { arity = 1 }) (* generic func *) ]
      in
      (Type.Var.Env, Type.Struct { sub = None; fields })
    in
    let func_1 =
      let name = Type.Var.Func { arity = 1 } in
      let descr = func_type 1 in
      (name, descr)
    in
    Decl.Type_rec [ func_1; env ]

  let float_type =
    Decl.Type (Type.Var.Float, Type.Struct { sub = None; fields = [ F64 ] })

  let int32_type =
    Decl.Type (Type.Var.Int32, Type.Struct { sub = None; fields = [ I32 ] })

  let int64_type =
    Decl.Type (Type.Var.Int64, Type.Struct { sub = None; fields = [ I64 ] })

  let nativeint_type =
    Decl.Type (Type.Var.Nativeint, Type.Struct { sub = None; fields = [ I32 ] })

  let string_type =
    Decl.Type (Type.Var.String, Type.Array { sub = None; fields = I8 })

  let array_type =
    Decl.Type (Type.Var.Array, Type.Array { sub = None; fields = Any })

  let floatarray_type =
    Decl.Type (Type.Var.FloatArray, Type.Array { sub = None; fields = F64 })

  let gen_block =
    let fields : Type.atom list = [ I8 (* tag *); I16 (* size *) ] in
    Decl.Type (Gen_block, Struct { sub = None; fields })

  let define_types_smaller ~max_size ~name ~descr ~decls =
    let sizes = List.init max_size (fun i -> i + 1) in
    List.fold_left
      (fun decls size ->
        let name = name size in
        let descr = descr size in
        Decl.Type (name, descr) :: decls )
      decls (List.rev sizes)

  let make_common () =
    let decls = [] in
    let decls =
      Arity.Set.fold
        (fun arity decls ->
          let ms = List.init arity (fun i -> i) in
          List.fold_left
            (fun decls applied_args ->
              let decl =
                Decl.Func
                  { name = Func_id.Caml_curry (arity, applied_args)
                  ; descr = caml_curry arity applied_args
                  }
              in
              decl :: decls )
            decls ms )
        (Arity.Set.remove 1 !State.arities)
        decls
    in
    let decls =
      Arity.Set.fold
        (fun arity decls ->
          let decl =
            Decl.Func
              { name = Func_id.Caml_apply arity; descr = caml_apply arity }
          in
          decl :: decls )
        !State.caml_applies decls
    in
    let decls =
      C_import.Set.fold
        (fun (descr : Primitive.description) decls ->
          let name = Func_id.prim_name descr in
          let descr = c_import descr in
          Decl.Func { name; descr } :: decls )
        !State.c_imports decls
    in
    let decls =
      define_types_smaller
        ~max_size:(Arity.Set.max_elt !State.block_sizes)
        ~name:(fun size -> Type.Var.Block { size })
        ~descr:block_type ~decls
    in
    let decls =
      define_types_smaller
        ~max_size:(Arity.Set.max_elt !State.block_float_sizes)
        ~name:(fun size -> Type.Var.BlockFloat { size })
        ~descr:block_float_type ~decls
    in
    let decls =
      Arity.Set.fold
        (fun arity decls ->
          let ms = List.init arity (fun i -> i) in
          List.fold_left
            (fun decls applied_args ->
              let decl =
                Decl.Type
                  ( Type.Var.Partial_closure (arity, applied_args)
                  , partial_closure_type ~arity ~applied:applied_args )
              in
              decl :: decls )
            decls ms )
        (Arity.Set.remove 1 !State.arities)
        decls
    in
    let decls =
      Closure_type.Set.fold
        (fun { arity; fields } decls ->
          let name = Type.Var.Closure { arity; fields } in
          let descr = closure_type ~arity ~fields in
          Decl.Type (name, descr) :: decls )
        !State.closure_types decls
    in
    let decls =
      Arity.Set.fold
        (fun arity decls ->
          let name = Type.Var.Gen_closure { arity } in
          let descr = gen_closure_type ~arity in
          Decl.Type (name, descr) :: decls )
        !State.arities decls
    in
    let decls = gen_block :: decls in
    let decls =
      Arity.Set.fold
        (fun arity decls ->
          let name = Type.Var.Func { arity } in
          let descr = func_type arity in
          Decl.Type (name, descr) :: decls )
        (Arity.Set.remove 1 !State.arities)
        decls
    in
    let decls =
      float_type :: int32_type :: int64_type :: nativeint_type :: string_type
      :: array_type :: floatarray_type :: func_1_and_env :: decls
    in
    decls
end

module ToWasm = struct
  module Cst = struct
    type t =
      | Int of int64
      | Float of float
      | String of string
      | Atom of string
      | Node of
          { name : string
          ; args_h : t list
          ; args_v : t list
          ; force_paren : bool
          }

    let print_lst f ppf l =
      Format.pp_print_list
        ~pp_sep:(fun ppf () -> Format.fprintf ppf "@ ")
        f ppf l

    let rec emit ppf = function
      | Int i -> Format.fprintf ppf "%Li" i
      | Float f -> Format.fprintf ppf "%h" f
      | String s -> Format.fprintf ppf "\"%s\"" s
      | Atom s -> Format.pp_print_string ppf s
      | Node { name; args_h; args_v; force_paren } -> begin
        match (args_h, args_v) with
        | [], [] ->
          if force_paren then Format.fprintf ppf "(%s)" name
          else Format.pp_print_string ppf name
        | _ ->
          Format.fprintf ppf "@[<v 2>@[<hov 2>";
          Format.fprintf ppf "(%s@ %a@]" name (print_lst emit) args_h;
          ( match args_v with
          | [] -> ()
          | _ -> Format.fprintf ppf "@ %a" (print_lst emit) args_v );
          Format.fprintf ppf ")@]"
      end

    let nodev name args =
      Node { name; args_h = []; args_v = args; force_paren = false }

    let nodehv name args_h args_v =
      Node { name; args_h; args_v; force_paren = false }

    let node name args =
      Node { name; args_h = args; args_v = []; force_paren = false }

    let node_p name args =
      Node { name; args_h = args; args_v = []; force_paren = true }

    let atom name = Atom name
  end

  module C = struct
    open Cst

    let ( !$ ) v = atom (Printf.sprintf "$%s" v)

    let type_name v = atom (Type.Var.name v)

    let global name typ descr = node "global" ([ !$name; typ ] @ descr)

    let reft name = node "ref" [ type_name name ]

    let struct_new_canon typ fields =
      node "struct.new_canon" (type_name typ :: fields)

    let array_new_canon_fixed typ size =
      node "array.new_canon_fixed" [ type_name typ; Int (Int64.of_int size) ]

    let int i = Int (Int64.of_int i)

    let string s = String s

    let i32_ i = node "i32.const" [ int i ]

    let i32 i = node "i32.const" [ Int (Int64.of_int32 i) ]

    let i64 i = node "i64.const" [ Int i ]

    let f64 f = node "f64.const" [ Float f ]

    let i31_new i = node "i31.new" [ i ]

    let ref_func f = node "ref.func" [ !$(Func_id.name f) ]

    let global_get g = node "global.get" [ !$(Global.name g) ]

    let local_get l = node "local.get" [ !$(Expr.Local.name l) ]

    let local_set l = node "local.set" [ !$(Expr.Local.name l) ]

    let struct_get typ field = node "struct.get" [ type_name typ; int field ]

    let struct_set typ field = node "struct.set" [ type_name typ; int field ]

    let call_ref typ = node "call_ref" [ type_name typ ]

    let call func = node "call" [ !$(Func_id.name func) ]

    let ref_cast typ = node "ref.cast" [ type_name typ ]

    let declare_func f =
      node "elem" [ atom "declare"; atom "func"; !$(Func_id.name f) ]

    let type_atom (t : Type.atom) =
      match t with
      | I8 -> atom "i8"
      | I16 -> atom "i16"
      | I32 -> atom "i32"
      | I64 -> atom "i64"
      | F64 -> atom "f64"
      | Any -> node "ref" [ atom "any" ]
      | Rvar v -> reft v

    let local l t = node "local" [ !$(Expr.Local.var_name l); type_atom t ]

    let param p t = node "param" [ !$(Param.name p); type_atom t ]

    let param_t t = node "param" [ type_atom t ]

    let result t = node "result" [ type_atom t ]

    let func ~name ~params ~result ~locals ~body =
      let fields = [ !$(Func_id.name name) ] @ params @ result @ locals in
      nodehv "func" fields body

    let field f = node "field" [ node "mut" [ type_atom f ] ]

    let struct_type fields = node "struct" (List.map field fields)

    let array_type f = node "array" [ node "mut" [ type_atom f ] ]

    let func_type ?name params res =
      let name =
        match name with None -> [] | Some name -> [ !$(Func_id.name name) ]
      in
      let res = List.map result res in
      node "func" (name @ List.map param_t params @ res)

    let type_ name descr = node "type" [ type_name name; descr ]

    let sub name descr = node "sub" [ type_name name; descr ]

    let rec_ l = node "rec" l

    let import module_ name e = node "import" [ String module_; String name; e ]

    let start f = node "start" [ !$(Func_id.name f) ]

    let module_ m = nodev "module" m
  end

  let option_to_list = function None -> [] | Some v -> [ v ]

  let tvar v = Type.Var.name v

  let gvar v = Global.name v

  let conv_binop = function
    | Expr.I32_add -> Cst.atom "i32.add"
    | Expr.I32_sub -> Cst.atom "i32.sub"
    | Expr.I32_mul -> Cst.atom "i32.mul"
    | Expr.F64_add -> Cst.atom "f64.add"
    | Expr.F64_sub -> Cst.atom "f64.sub"
    | Expr.F64_mul -> Cst.atom "f64.mul"
    | Expr.F64_div -> Cst.atom "f64.div"
    | Expr.Struct_set { typ; field } -> C.struct_set typ field

  let conv_unop = function
    | Expr.I31_get_s -> Cst.atom "i31.get_s"
    | Expr.I31_new -> Cst.atom "i31.new"
    | Expr.Drop -> Cst.atom "drop"
    | Expr.Struct_get { typ; field } -> C.struct_get typ field

  let rec conv_expr (expr : Expr.t) =
    match expr with
    | Var v -> [ C.local_get v ]
    | Binop (op, (arg1, arg2)) ->
      conv_expr arg1 @ conv_expr arg2 @ [ conv_binop op ]
    | Unop (op, arg) -> conv_expr arg @ [ conv_unop op ]
    | Let { var; typ = _; defining_expr; body } ->
      conv_expr defining_expr
      @ (C.local_set (Expr.Local.V var) :: conv_expr body)
    | I32 i -> [ C.i32 i ]
    | I64 i -> [ C.i64 i ]
    | F64 f -> [ C.f64 f ]
    | Struct_new (typ, fields) ->
      let fields = List.map conv_expr fields in
      List.flatten fields @ [ C.struct_new_canon typ [] ]
    | Array_new_fixed { typ; fields } ->
      let size = List.length fields in
      let fields = List.map conv_expr fields in
      List.flatten fields @ [ C.array_new_canon_fixed typ size ]
    | Ref_func fid -> [ C.ref_func fid ]
    | Call_ref { typ; args; func } ->
      List.flatten (List.map conv_expr args)
      @ conv_expr func
      @ [ C.call_ref typ ]
    | Call { args; func } ->
      List.flatten (List.map conv_expr args) @ [ C.call func ]
    | Ref_cast { typ; r } -> conv_expr r @ [ C.ref_cast typ ]
    | Global_get g -> [ C.global_get g ]
    | Seq l -> List.flatten (List.map conv_expr l)
    | Assign { being_assigned; new_value } ->
      conv_expr new_value @ [ C.local_set (Expr.Local.V being_assigned) ]

  let conv_const name (const : Const.t) =
    match const with
    | Struct { typ; fields } ->
      let field (field : Const.field) : Cst.t =
        match field with
        | I8 i | I16 i -> C.i32_ i
        | I31 i -> C.i31_new (C.i32_ i)
        | Ref_func f -> C.ref_func f
        | Global g -> C.global_get g
      in
      C.global (Global.name name) (C.reft typ)
        [ C.struct_new_canon typ (List.map field fields) ]
    | Expr { typ; e } ->
      C.global (Global.name name) (C.type_atom typ) (conv_expr e)

  let conv_func name (func : Func.t) =
    match func with
    | Import { module_; name = prim_name; params; result } ->
      let typ = C.func_type ~name params result in
      [ C.import module_ prim_name typ ]
    | Decl { params; result; body } ->
      let func =
        let locals = Expr.required_locals body in
        let params = List.map (fun (p, t) -> C.param p t) params in
        let locals =
          Expr.Local.Map.fold (fun v t l -> C.local v t :: l) locals []
        in
        let body = conv_expr body in
        let result =
          match result with None -> [] | Some typ -> [ C.result typ ]
        in
        C.func ~name ~params ~locals ~result ~body
      in
      [ C.declare_func name; func ]

  let conv_type name (descr : Type.descr) =
    match descr with
    | Struct { sub; fields } ->
      let descr = C.struct_type fields in
      let descr =
        match sub with None -> descr | Some sub -> C.sub sub descr
      in
      C.type_ name descr
    | Array { sub; fields } ->
      let descr = C.array_type fields in
      let descr =
        match sub with None -> descr | Some sub -> C.sub sub descr
      in
      C.type_ name descr
    | Func { params; result } ->
      C.type_ name (C.func_type params (option_to_list result))

  let conv_type_rec types =
    C.rec_ (List.map (fun (name, descr) -> conv_type name descr) types)

  let rec conv_decl = function
    | [] -> [ C.start Start ]
    | Decl.Const { name; descr } :: tl -> conv_const name descr :: conv_decl tl
    | Decl.Func { name; descr } :: tl ->
      let func = conv_func name descr in
      func @ conv_decl tl
    | Decl.Type (name, descr) :: tl ->
      let type_ = conv_type name descr in
      type_ :: conv_decl tl
    | Decl.Type_rec types :: tl ->
      let type_ = conv_type_rec types in
      type_ :: conv_decl tl

  let conv_module module_ = C.module_ (conv_decl module_)
end

let output_file ~output_prefix module_ =
  let wastfile = output_prefix ^ ".wast" in
  let oc = open_out_bin wastfile in
  let ppf = Format.formatter_of_out_channel oc in
  Misc.try_finally
    ~always:(fun () ->
      Format.fprintf ppf "@.";
      close_out oc )
    (* ~exceptionally:(fun () -> Misc.remove_file wastfile) *)
      (fun () -> ToWasm.Cst.emit ppf module_ )

let run ~output_prefix (flambda : Flambda.program) =
  State.reset ();
  let print_everything =
    match Sys.getenv_opt "WASMPRINT" with None -> false | Some _ -> true
  in
  let offsets = Wasm_closure_offsets.compute flambda in
  let top_env = Conv.{ offsets } in
  let m = Conv.conv_body top_env flambda.program_body [] in
  let closure_types = Conv.closure_types flambda in
  let functions = Conv.conv_functions ~top_env flambda in
  let m = closure_types @ functions @ m in
  if print_everything then
    Format.printf "WASM %s@.%a@." output_prefix Module.print m;
  let common = Conv.make_common () in
  if print_everything then Format.printf "COMMON@.%a@." Module.print common;
  let wasm = ToWasm.conv_module (common @ m) in
  Format.printf "@.%a@." ToWasm.Cst.emit wasm;
  output_file ~output_prefix wasm