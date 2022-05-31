grammar lmlangmap;

nonterminal Program;
nonterminal DeclList;
nonterminal Decl;
nonterminal Qid;
nonterminal Exp;
nonterminal BindListSeq;
nonterminal BindListRec;
nonterminal BindListPar;

type Target_type = Decorated Exp;
type Scope_type = Scope<Target_type>;
type Decl_type = Declaration<Target_type>;
type Usage_type = Usage<Target_type>;

synthesized attribute pp::String occurs on Program, DeclList, Decl, Qid, Exp, 
  BindListSeq, BindListRec, BindListPar;
inherited attribute tab_level::String occurs on Program, DeclList, Decl, Qid, Exp, 
  BindListSeq, BindListRec, BindListPar;
global tab_spacing :: String = "\t";

inherited attribute inh_scope::Scope_type occurs on DeclList, Decl, Qid, Exp, 
  BindListSeq, BindListRec, BindListPar;
inherited attribute inh_scope_two::Scope_type occurs on BindListPar, Qid;

synthesized attribute syn_scope::Scope_type occurs on Program, DeclList, Decl, Qid, Exp, 
  BindListSeq, BindListRec, BindListPar;

synthesized attribute syn_decls::[(String, Decorated Decl_type)] occurs on DeclList, 
  Decl, Qid, Exp,BindListSeq, BindListRec, BindListPar;
synthesized attribute syn_refs::[(String, Decorated Usage_type)] occurs on DeclList, 
  Decl, Qid, Exp, BindListSeq, BindListRec, BindListPar;
synthesized attribute syn_imports::[(String, Decorated Usage_type)] occurs on DeclList, 
  Decl, Qid, Exp, BindListSeq, BindListRec, BindListPar;

synthesized attribute syn_decls_two::[(String, Decorated Decl_type)] occurs on BindListPar;
synthesized attribute syn_refs_two::[(String, Decorated Usage_type)] occurs on BindListPar;
synthesized attribute syn_imports_two::[(String, Decorated Usage_type)] occurs on BindListPar;

synthesized attribute syn_iqid_import::(String, Decorated Usage_type) occurs on Qid;

synthesized attribute ret_scope::Scope_type occurs on BindListSeq;

-- Error checking
synthesized attribute errors :: [String] with ++ occurs on Program, DeclList, Decl, Qid, Exp,
  BindListSeq, BindListRec, BindListPar;

------------------------------------------------------------
---- Program root
------------------------------------------------------------

abstract production prog 
top::Program ::= list::DeclList
{
  top.pp = "program(\n" ++ list.pp ++ "\n)";
  list.tab_level = tab_spacing;
  
  local attribute init_scope::Scope_type = cons_scope(
    nothing(),
    list.syn_decls,
    list.syn_refs,
    list.syn_imports
  );
  list.inh_scope = init_scope;
  top.syn_scope = init_scope;

  top.errors := ["ok"];
}



------------------------------------------------------------
---- Declaration lists
------------------------------------------------------------

abstract production decllist_list
top::DeclList ::= decl::Decl list::DeclList
{
  top.pp = top.tab_level ++ "decl_list(\n" ++ decl.pp ++ ",\n" 
    ++ list.pp ++ "\n" ++ top.tab_level ++ ")";
  decl.tab_level = tab_spacing ++ top.tab_level;
  list.tab_level = tab_spacing ++ top.tab_level; 

  top.syn_decls = decl.syn_decls ++ list.syn_decls;
  top.syn_refs = decl.syn_refs ++ list.syn_refs;
  top.syn_imports = decl.syn_imports ++ list.syn_imports;
}

abstract production decllist_nothing
top::DeclList ::=
{
  top.pp = top.tab_level ++ "decl_list()";
  top.syn_scope = top.inh_scope;

  top.syn_decls = [];
  top.syn_refs = [];
  top.syn_imports = [];
}



------------------------------------------------------------
---- Declarations
------------------------------------------------------------

abstract production decl_module
top::Decl ::= id::ID_t list::DeclList
{
  top.pp = top.tab_level ++ "module(\n" ++ tab_spacing ++ top.tab_level ++ id.lexeme ++ ",\n" 
    ++ list.pp ++ "\n" ++ top.tab_level ++ ")";
  list.tab_level = tab_spacing ++ top.tab_level;

  local attribute init_scope::Scope_type = cons_scope (
    just(top.inh_scope),
    list.syn_decls,
    list.syn_refs,
    list.syn_imports
  );
  local attribute par_scope::Scope_type = top.inh_scope; -- Cannot simply use top.inh_scope in cons_decl(?)
  local attribute init_decl::Decl_type = cons_decl(
    id.lexeme,
    par_scope, -- Cannot simply use top.inh_scope in cons_decl(?)
    just(init_scope)
  );
  top.syn_decls = [(id.lexeme, init_decl)];
  top.syn_refs = [];
  top.syn_imports = [];
  list.inh_scope = init_scope;
}

abstract production decl_import
top::Decl ::= qid::Qid
{
  top.pp = top.tab_level ++ "import(\n" ++ qid.pp ++ "\n" ++ top.tab_level ++ ")";

  top.syn_decls = qid.syn_decls;
  top.syn_refs = qid.syn_refs;
  top.syn_imports = qid.syn_imports ++ [qid.syn_iqid_import]; -- rqid followed by iqid in construction rules
}

abstract production decl_def
top::Decl ::= id::ID_t exp::Exp
{
  top.pp = top.tab_level ++ "def(\n" ++ top.tab_level ++ tab_spacing ++ id.lexeme ++ ",\n"
    ++ exp.pp ++ "\n" ++ top.tab_level ++ ")";
  exp.tab_level = tab_spacing ++ top.tab_level;

  local attribute par_scope::Scope_type = top.inh_scope; -- Cannot simply use top.inh_scope in cons_decl(?)
  local attribute init_decl::Decl_type = cons_decl (
    id.lexeme,
    par_scope, -- Cannot simply use top.inh_scope in cons_decl(?)
    nothing()
  );
  top.syn_decls = [(id.lexeme, init_decl)] ++ exp.syn_decls;
  top.syn_refs = exp.syn_refs;
  top.syn_imports = exp.syn_imports;
  exp.inh_scope = top.inh_scope;
}

abstract production decl_exp
-- (un)removing this for now to (not) comply with the grammar in a theory of name resolution
top::Decl ::= exp::Exp
{
  top.pp = top.tab_level ++ "decl_exp(\n" ++ exp.pp ++ "\n" ++ top.tab_level ++ ")";
  exp.tab_level = tab_spacing ++ top.tab_level;

  top.syn_decls = exp.syn_decls;
  top.syn_refs = exp.syn_refs;
  top.syn_imports = top.syn_imports;
}



------------------------------------------------------------
---- Sequential let expressions
------------------------------------------------------------

abstract production exp_let
top::Exp ::= list::BindListSeq exp::Exp
{
  top.pp = top.tab_level ++ "let(\n" ++ list.pp ++ ",\n" ++ exp.pp ++ "\n" ++ top.tab_level ++ ")";
  list.tab_level = tab_spacing ++ top.tab_level;
  exp.tab_level = tab_spacing ++ top.tab_level;

  top.syn_decls = list.syn_decls;
  top.syn_refs = list.syn_refs;
  top.syn_imports = list.syn_imports;
  exp.inh_scope = list.ret_scope;
}

-- Defines the binding pattern for the sequential let feature
abstract production bindlist_list_seq
top::BindListSeq ::= id::ID_t exp::Exp list::BindListSeq
{
  top.pp = top.tab_level ++ "bind_list(\n" ++ top.tab_level ++ tab_spacing ++ id.lexeme ++ ",\n" 
    ++ exp.pp ++ ",\n" ++ list.pp ++ "\n" ++ top.tab_level ++ ")";
  exp.tab_level = tab_spacing ++ top.tab_level;
  list.tab_level = tab_spacing ++ top.tab_level;

  top.syn_decls = exp.syn_decls;
  top.syn_refs = exp.syn_refs;
  top.syn_imports = exp.syn_imports;
  local attribute par_scope::Scope_type = top.inh_scope; -- Cannot simply use top.inh_scope in cons_decl(?)
  local attribute init_decl::Decl_type = cons_decl (
    id.lexeme,
    par_scope, -- Cannot simply use top.inh_scope in cons_decl(?)
    nothing()
  );
  local attribute init_scope::Scope_type = cons_scope (
    just(top.inh_scope),
    list.syn_decls ++ [(id.lexeme, init_decl)],
    list.syn_refs,
    list.syn_imports
  );
  list.inh_scope = init_scope;
  top.ret_scope = list.ret_scope;
}

abstract production bindlist_nothing_seq
top::BindListSeq ::=
{
  top.pp = top.tab_level ++ "bind_list()";
  top.ret_scope = top.inh_scope;
  top.syn_decls = [];
  top.syn_refs = [];
  top.syn_imports = [];
}



------------------------------------------------------------
---- Recursive let expressions
------------------------------------------------------------

abstract production exp_letrec
top::Exp ::= list::BindListRec exp::Exp
{
  top.pp = top.tab_level ++ "exp_letrec(\n" ++ list.pp ++ ",\n" 
    ++ exp.pp ++ "\n" ++ top.tab_level ++ ")";
  list.tab_level = tab_spacing ++ top.tab_level;
  exp.tab_level = tab_spacing ++ top.tab_level;
}

-- Defines the binding pattern for the recursive let feature
abstract production bindlist_list_rec
top::BindListRec ::= id::ID_t exp::Exp list::BindListRec
{
  top.pp = top.tab_level ++ "bindlist_list(\n" ++ top.tab_level ++ tab_spacing 
    ++ id.lexeme ++ " = " ++ exp.pp ++ ",\n" ++ list.pp ++ "\n" ++ top.tab_level ++ ")";
  exp.tab_level = tab_spacing ++ top.tab_level;
  list.tab_level = tab_spacing ++ top.tab_level;

  local attribute par_scope::Scope_type = top.inh_scope; -- Cannot simply use top.inh_scope in cons_decl(?)
  local attribute init_decl::Decl_type = cons_decl (
    id.lexeme,
    par_scope, -- Cannot simply use top.inh_scope in cons_decl(?)
    nothing()
  );
  top.syn_decls = exp.syn_decls ++ list.syn_decls ++ [(id.lexeme, init_decl)];
  top.syn_refs = exp.syn_refs ++ list.syn_refs;
  top.syn_imports = exp.syn_imports ++ list.syn_imports;
  exp.inh_scope = top.inh_scope;
  list.inh_scope = top.inh_scope;
}

abstract production bindlist_nothing_rec
top::BindListRec ::=
{
  top.pp = top.tab_level ++ "bindlist_list()";
  top.syn_decls = [];
  top.syn_refs = [];
  top.syn_imports = [];
}



------------------------------------------------------------
---- Parallel let expressions
------------------------------------------------------------

abstract production exp_letpar
top::Exp ::= list::BindListPar exp::Exp
{
  top.pp = top.tab_level ++ "exp_letpar(\n" ++ list.pp ++ ",\n" 
    ++ exp.pp ++ "\n" ++ top.tab_level ++ ")";
  list.tab_level = tab_spacing ++ top.tab_level;
  exp.tab_level = tab_spacing ++ top.tab_level;

  local attribute init_scope::Scope_type = cons_scope (
    just(top.inh_scope),
    list.syn_decls_two ++ exp.syn_decls,
    list.syn_refs_two ++ exp.syn_refs,
    list.syn_imports_two ++ exp.syn_imports 
  );

  exp.inh_scope = init_scope;
  list.inh_scope = top.inh_scope;
  list.inh_scope_two = init_scope;

  top.syn_decls = list.syn_decls;
  top.syn_refs = list.syn_refs;
  top.syn_imports = list.syn_imports;
}

-- Defines the binding pattern for the parallel let feature
abstract production bindlist_list_par
top::BindListPar ::= id::ID_t exp::Exp list::BindListPar
{
  top.pp = top.tab_level ++ "bindlist_list(\n" ++ top.tab_level ++ tab_spacing 
    ++ id.lexeme ++ " = " ++ exp.pp ++ ",\n" ++ list.pp ++ "\n" ++ top.tab_level ++ ")";
  exp.tab_level = tab_spacing ++ top.tab_level;
  list.tab_level = tab_spacing ++ top.tab_level;

  local attribute par_scope::Scope_type = top.inh_scope; -- Cannot simply use top.inh_scope in cons_decl(?)
  local attribute init_decl::Decl_type = cons_decl (
    id.lexeme,
    par_scope, -- Cannot simply use top.inh_scope in cons_decl(?)
    nothing()
  );

  top.syn_decls = exp.syn_decls;
  top.syn_refs = exp.syn_refs;
  top.syn_imports = exp.syn_imports;

  top.syn_decls_two = list.syn_decls_two ++ [(id.lexeme, init_decl)];
  top.syn_refs_two = list.syn_refs_two;
  top.syn_imports_two = list.syn_imports_two;

  exp.inh_scope = top.inh_scope;
  list.inh_scope = top.inh_scope;
  list.inh_scope_two = top.inh_scope_two;

}

abstract production bindlist_nothing_par
top::BindListPar ::=
{
  top.pp = top.tab_level ++ "bindlist_nothing()";

  top.syn_decls = [];
  top.syn_refs = [];
  top.syn_imports = [];

  top.syn_decls_two = [];
  top.syn_refs_two = [];
  top.syn_imports_two = [];
}



------------------------------------------------------------
---- Other expressions
------------------------------------------------------------

abstract production exp_funfix
top::Exp ::= id::ID_t exp::Exp
{
  top.pp = top.tab_level ++ "fun/fix(\n" ++ top.tab_level ++ tab_spacing ++ id.lexeme ++ ",\n"
    ++ exp.pp ++ "\n" ++ top.tab_level ++ ")";
  exp.tab_level = tab_spacing ++ top.tab_level;

  local attribute par_scope::Scope_type = top.inh_scope; -- Cannot simply use top.inh_scope in cons_decl(?)
  local attribute init_decl::Decl_type = cons_decl (
    id.lexeme,
    par_scope, -- Cannot simply use top.inh_scope in cons_decl(?)
    nothing()
  );

  local attribute init_scope::Scope_type = cons_scope (
    just(top.inh_scope),
    exp.syn_decls ++ [(id.lexeme, init_decl)],
    exp.syn_refs,
    exp.syn_imports
  );

  exp.inh_scope = init_scope;

  top.syn_decls = [];
  top.syn_refs = [];
  top.syn_imports = [];

}

abstract production exp_plus
top::Exp ::= expLeft::Exp expRight::Exp
{
  top.pp = top.tab_level ++ "add(\n" ++ expLeft.pp ++ ",\n" 
    ++ expRight.pp ++ "\n" ++ top.tab_level ++ ")";
  expLeft.tab_level = tab_spacing ++ top.tab_level;
  expRight.tab_level = tab_spacing ++ top.tab_level;

  top.syn_decls = expLeft.syn_decls ++ expRight.syn_decls;
  top.syn_refs = expLeft.syn_refs ++ expRight.syn_refs;
  top.syn_imports = expLeft.syn_imports ++ expRight.syn_imports;
}

abstract production exp_app
top::Exp ::= expLeft::Exp expRight::Exp
{
  top.pp = top.tab_level ++ "apply(\n" ++ expLeft.pp ++ ",\n" 
    ++ expRight.pp ++ "\n" ++ top.tab_level ++ ")";
  expLeft.tab_level = tab_spacing ++ top.tab_level;
  expRight.tab_level = tab_spacing ++ top.tab_level;

  top.syn_decls = expLeft.syn_decls ++ expRight.syn_decls;
  top.syn_refs = expLeft.syn_refs ++ expRight.syn_refs;
  top.syn_imports = expLeft.syn_imports ++ expRight.syn_imports;
}

abstract production exp_qid
top::Exp ::= qid::Qid
{
  top.pp = top.tab_level ++ "exp_qid(\n" ++ qid.pp ++ "\n" ++ top.tab_level ++ ")";
  qid.tab_level = tab_spacing ++ top.tab_level;

  top.syn_decls = qid.syn_decls;
  top.syn_refs = qid.syn_refs;
  top.syn_imports = qid.syn_imports;
}

abstract production exp_int
top::Exp ::= val::Int_t
{
  top.pp = top.tab_level ++ "exp_int(\n" ++ top.tab_level ++ tab_spacing 
    ++ val.lexeme ++ "\n" ++ top.tab_level ++ ")";
  
  top.syn_decls = [];
  top.syn_refs = [];
  top.syn_imports = [];
}



------------------------------------------------------------
---- Qualified identifiers
------------------------------------------------------------

synthesized attribute syn_last_ref::Decorated Usage_type occurs on Qid;

abstract production qid_list
top::Qid ::= id::ID_t qid::Qid
{
  top.pp = top.tab_level ++ "qid(\n" ++ top.tab_level ++ tab_spacing ++ id.lexeme ++ ",\n" 
    ++ qid.pp ++ "\n" ++ top.tab_level ++ ")";
  qid.tab_level = tab_spacing ++ top.tab_level;

  -- iqid
  qid.inh_scope_two = top.inh_scope_two;
  top.syn_iqid_import = qid.syn_iqid_import;

  -- rqid
  local attribute par_scope::Scope_type = top.inh_scope;
  local attribute init_usage::Usage_type = cons_usage (
    id.lexeme,
    par_scope
  );
  local attribute init_scope::Scope_type = cons_scope (
    nothing(),
    qid.syn_decls,
    qid.syn_refs,
    qid.syn_imports ++ [(id.lexeme, init_usage)]
  );
  qid.inh_scope = init_scope;
  top.syn_decls = [];
  top.syn_refs = [(id.lexeme, init_usage)];
  top.syn_imports = [];

}

abstract production qid_single
top::Qid ::= id::ID_t
{
  top.pp = top.tab_level ++ "qid(\n" ++ top.tab_level ++ tab_spacing ++ id.lexeme ++ "\n" 
    ++ top.tab_level ++ ")";

  -- iqid
  local attribute par_scope_two::Scope_type = top.inh_scope_two;
  local attribute init_import_two::Usage_type = cons_usage (
    id.lexeme,
    par_scope_two
  );
  top.syn_iqid_import = (id.lexeme, init_import_two);

  -- rqid:
  local attribute par_scope::Scope_type = top.inh_scope;
  local attribute init_import::Usage_type = cons_usage (
    id.lexeme,
    par_scope
  );
  top.syn_decls = [];
  top.syn_refs = [(id.lexeme, init_import)];
  top.syn_imports = [];
}