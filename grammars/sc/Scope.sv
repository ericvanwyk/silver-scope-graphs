grammar sc;

imports silver:langutil;
imports silver:langutil:pp;

nonterminal Scope;

synthesized attribute dcls :: [ Decorated Dcl ] occurs on Scope, Dcls;
synthesized attribute refs :: [ Decorated Ref ] occurs on Scope, Refs, Ref;
synthesized attribute imps :: [ Decorated Ref ] occurs on Scope, Refs, Ref;

inherited attribute parent :: Decorated Scope occurs on Ref, Refs, Dcl, Dcls, Scope;

synthesized attribute visible :: [ Decorated Dcl ] occurs on Ref;
synthesized attribute reachable :: [ [ Decorated Dcl ] ] occurs on Ref;

synthesized attribute scope_paths :: [ (Maybe<String>, [Decorated Scope]) ] 
            occurs on Ref, Scope;

synthesized attribute name :: String occurs on Dcl, Ref;
synthesized attribute index :: Integer occurs on Dcl, Ref;

attribute pp occurs on Scope, Dcl, Dcls, Ref, Refs;

production root_scope
gs::Scope ::= main::Scope
{
  gs.scope_paths = [];
  main.parent = gs; 

  gs.pp = main.pp;
}

function fold_scopes
[Decorated Scope] ::= sofar::[Decorated Scope] d::Decorated Dcl
{ return case d.assoc_scope of
         | nothing() -> sofar
         | just(s) -> s :: sofar
         end;
}

production scope_tr
s::Scope ::= dcls_tr::Dcls refs_tr::Refs imps_tr::Refs
{
  dcls_tr.parent = s; refs_tr.parent = s; imps_tr.parent = s;

  s.dcls = dcls_tr.dcls;
  s.refs = refs_tr.refs;
  s.imps = imps_tr.imps;

  local resolved_imports :: [(Maybe<String>,Decorated Dcl)] = 
    foldl (\ sofar :: [Decorated Dcl] r::Decorated Ref -> (just(r.name),r.visible) ++ sofar, 
           [], s.imps) ;

  local imported_scopes :: [(Maybe<String>, Decorated Scope)] = [];
--    foldl (fold_scopes, [], resolved_imports);

  -- look on this scope, then imports on this scope
  -- then parent of this scope, then imports on parent ...
  s.scope_paths = [(nothing(),s)] :: imported_scopes :: s.parent.scope_paths ;



  local dcls_doc :: Document =
     terminate (
       line(),
       map (\d::Decorated Dcl -> 
              ppConcat ([text(d.name), text(":"), pp(d.index),
                           text(" = ...")]),
           s.dcls)
        );


  s.pp = braces(
          nestlines(2,
            cat (dcls_doc,          
            cat (text("_ = "), ppImplode (cat (comma(), space()), 
                                          map ( (.pp), s.refs))))
         ));
}

function dcls_in_scope
[Decorated Dcl] ::= name::String dcls::[Decorated Dcl]
{
  return
    case dcls of
    | [] -> []
    | d::ds -> if d.name == name
               then d :: dcls_in_scope (name, ds)
               else dcls_in_scope (name, ds)
    end;
}

function local_resolutions
[Decorated Dcl] ::= name::String  seen::[String]
                    scopes::[(Maybe<String>,Decorated Scope)]
{
   return 
    case scopes of
    | [] -> []
    | (nothing(),s) :: ss 
        -> dcls_in_scope (name, s.dcls) ++ local_resolutions (name, seen, ss)
    | (just(nm),s) :: ss 
        -> dcls_in_scope (name, s.dcls) ++ local_resolutions (name, seen, ss)
    end;
}

function resolutions
[ [ Decorated Dcl] ] ::= name::String  seen::[String] 
                         scope_paths::[ [(Maybe<String>,Decorated Scope)] ]
{
  return 
    case scope_paths of
    | [] -> []
    | scopes :: rest -> let dcls :: [Decorated Dcl] = local_resolutions (name, scopes) 
                        in if null (dcls)
                           then resolutions (name, seen, rest)
                           else dcls :: resolutions (name, seen, rest)
                        end
    end;
}

--------------------------------------------------
nonterminal Dcl;
nonterminal Dcls;

{- Declarations have 
   - an associated scope, optionally
   - a reference to the AST node of the declaration
 -}
synthesized attribute assoc_scope :: Maybe <Decorated Scope> occurs on Dcl;

production dcl_tr
d::Dcl ::= n::String ind::Integer
{ d.name = n;
  d.index = ind;
  d.assoc_scope = nothing();
}

production dcl_scope_tr
d::Dcl ::= n::String ind::Integer s::Scope
{ d.name = n;
  d.index = ind;
  d.assoc_scope = just(s);
  s.parent = d.parent;
}


production dcl_nil
ds::Dcls ::=
{ ds.dcls = []; 
}

production dcl_cons
ds::Dcls ::= h::Dcl t::Dcls
{ ds.dcls = h :: t.dcls;
  h.parent = ds.parent;  t.parent = ds.parent;
}

--------------------------------------------------
nonterminal Ref;
nonterminal Refs;

production ref_tr
r::Ref ::= n::String ind::Integer
{ r.name = n;
  r.index = ind;
  r.pp = ppConcat ([text(n), text(":"), pp(ind)]);
  r.refs = [r];
  r.imps = [];

  r.scope_paths = r.parent.scope_paths;

  -- resolutions must be Dcls without an associated scope
  r.visible = case r.reachable of
                | [] -> []
                | h::t -> h
                end;
  
  r.reachable = resolutions (n, [], r.parent.scope_paths);

  r.all_refs <- [r];
}


production imp_tr
i::Ref ::= n::String ind::Integer
{ i.name = n;
  i.index = ind;
  i.refs = [];
  i.imps = [i];

  -- resolutions must be Dcls with an associated scope

  -- [ ]   - error, undeclared name used for an import
  -- [d]   -- OK - we have a Dcl
  -- [d1, d2] -- maybe an error, maybe OK
  i.visible = case i.reachable of
                | [] -> []
                | h::t -> h
                end;

  i.reachable = resolutions (n, i.parent.scope_paths);

  i.all_refs <- [i];
}


production ref_nil
rs::Refs ::=
{
  rs.refs = [];
  rs.imps = [];
}

production ref_cons
rs::Refs ::= h::Ref t::Refs
{
  rs.refs = h.refs ++ t.refs;
  rs.imps = h.imps ++ t.imps;

  h.parent = rs.parent;
  t.parent = rs.parent;
}


-- collecting things to the top for reporting
monoid attribute all_refs :: [Decorated Ref] occurs on Ref, Refs, Dcl, Dcls, Scope;

propagate all_refs on Ref, Refs, Dcl, Dcls, Scope;

function report
String ::= refs :: [Decorated Ref]
{ return
    concat (map ( \r::Decorated Ref -> r.name ++ ":" ++ toString (r.index) ++ 
                 case r.visible of
                 | [] -> " not declared \n"
                 | ds -> " is declared " ++
                              toString (length (ds)) ++ "\n"
                 end, refs) );
}  
