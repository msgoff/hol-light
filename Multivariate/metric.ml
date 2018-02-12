(* ========================================================================= *)
(* Formalization of general topological and metric spaces in HOL Light       *)
(*                                                                           *)
(*              (c) Copyright, John Harrison 1998-2017                       *)
(*                (c) Copyright, Marco Maggesi 2014-2017                     *)
(*             (c) Copyright, Andrea Gabrielli  2016-2017                    *)
(* ========================================================================= *)

needs "Library/products.ml";;
needs "Multivariate/misc.ml";;
needs "Library/iter.ml";;
prioritize_real();;

(* ------------------------------------------------------------------------- *)
(* Instrument classical tactics to attach label to inductive hypothesis.     *)
(* ------------------------------------------------------------------------- *)

let LABEL_INDUCT_TAC =
  let IND_TAC = MATCH_MP_TAC num_INDUCTION THEN CONJ_TAC in
  fun (asl,w as gl) ->
    let s = fst (dest_var (fst (dest_forall w)))  in
    (IND_TAC THENL
     [ALL_TAC; GEN_TAC THEN DISCH_THEN (LABEL_TAC("ind_"^s))])
    gl;;

let LABEL_ABBREV_TAC tm =
  let cvs,t = dest_eq tm in
  let v,vs = strip_comb cvs in
  let s = name_of v in
  let rs = list_mk_abs(vs,t) in
  let eq = mk_eq(rs,v) in
  let th1 = itlist (fun v th -> CONV_RULE(LAND_CONV BETA_CONV) (AP_THM th v))
                   (rev vs) (ASSUME eq) in
  let th2 = SIMPLE_CHOOSE v (SIMPLE_EXISTS v (GENL vs th1)) in
  let th3 = PROVE_HYP (EXISTS(mk_exists(v,eq),rs) (REFL rs)) th2 in
  fun (asl,w as gl) ->
    let avoids = itlist (union o frees o concl o snd) asl (frees w) in
    if mem v avoids then failwith "LABEL_ABBREV_TAC: variable already used" else
    CHOOSE_THEN
     (fun th -> RULE_ASSUM_TAC(PURE_ONCE_REWRITE_RULE[th]) THEN
                PURE_ONCE_REWRITE_TAC[th] THEN
                LABEL_TAC s th)
     th3 gl;;

(* ------------------------------------------------------------------------- *)
(* Further tactics for structuring the proof flow.                           *)
(* ------------------------------------------------------------------------- *)

let CUT_TAC : term -> tactic =
  let th = MESON [] `(p ==> q) /\ p ==> q`
  and ptm = `p:bool` in
  fun tm -> MATCH_MP_TAC (INST [tm,ptm] th) THEN CONJ_TAC;;

let CLAIM_TAC s tm = SUBGOAL_THEN tm (DESTRUCT_TAC s);;

let CONJ_LIST = end_itlist CONJ;;

(* ------------------------------------------------------------------------- *)
(* General notion of a topology.                                             *)
(* ------------------------------------------------------------------------- *)

let istopology = new_definition
 `istopology L <=>
        {} IN L /\
        (!s t. s IN L /\ t IN L ==> (s INTER t) IN L) /\
        (!k. k SUBSET L ==> (UNIONS k) IN L)`;;

let topology_tybij_th = prove
 (`?t:(A->bool)->bool. istopology t`,
  EXISTS_TAC `UNIV:(A->bool)->bool` THEN REWRITE_TAC[istopology; IN_UNIV]);;

let topology_tybij =
  new_type_definition "topology" ("topology","open_in") topology_tybij_th;;

let ISTOPOLOGY_OPEN_IN = prove
 (`istopology(open_in top)`,
  MESON_TAC[topology_tybij]);;

let TOPOLOGY_EQ = prove
 (`!top1 top2. top1 = top2 <=> !s. open_in top1 s <=> open_in top2 s`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM FUN_EQ_THM] THEN
  REWRITE_TAC[ETA_AX] THEN MESON_TAC[topology_tybij]);;

(* ------------------------------------------------------------------------- *)
(* Infer the "universe" from union of all sets in the topology.              *)
(* ------------------------------------------------------------------------- *)

let topspace = new_definition
 `topspace top = UNIONS {s | open_in top s}`;;

(* ------------------------------------------------------------------------- *)
(* Main properties of open sets.                                             *)
(* ------------------------------------------------------------------------- *)

let OPEN_IN_CLAUSES = prove
 (`!top:(A)topology.
        open_in top {} /\
        (!s t. open_in top s /\ open_in top t ==> open_in top (s INTER t)) /\
        (!k. (!s. s IN k ==> open_in top s) ==> open_in top (UNIONS k))`,
  SIMP_TAC[IN; SUBSET; SIMP_RULE[istopology; IN; SUBSET] ISTOPOLOGY_OPEN_IN]);;

let OPEN_IN_SUBSET = prove
 (`!top s. open_in top s ==> s SUBSET (topspace top)`,
  REWRITE_TAC[topspace] THEN SET_TAC[]);;

let OPEN_IN_EMPTY = prove
 (`!top. open_in top {}`,
  REWRITE_TAC[OPEN_IN_CLAUSES]);;

let OPEN_IN_INTER = prove
 (`!top s t. open_in top s /\ open_in top t ==> open_in top (s INTER t)`,
  REWRITE_TAC[OPEN_IN_CLAUSES]);;

let OPEN_IN_UNIONS = prove
 (`!top k. (!s. s IN k ==> open_in top s) ==> open_in top (UNIONS k)`,
  REWRITE_TAC[OPEN_IN_CLAUSES]);;

let OPEN_IN_UNION = prove
 (`!top s t. open_in top s /\ open_in top t ==> open_in top (s UNION t)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[GSYM UNIONS_2] THEN
  MATCH_MP_TAC OPEN_IN_UNIONS THEN ASM SET_TAC[]);;

let OPEN_IN_TOPSPACE = prove
 (`!top. open_in top (topspace top)`,
  SIMP_TAC[topspace; OPEN_IN_UNIONS; IN_ELIM_THM]);;

let OPEN_IN_INTERS = prove
 (`!top s:(A->bool)->bool.
        FINITE s /\ ~(s = {}) /\ (!t. t IN s ==> open_in top t)
        ==> open_in top (INTERS s)`,
  GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[INTERS_INSERT; IMP_IMP; NOT_INSERT_EMPTY; FORALL_IN_INSERT] THEN
  MAP_EVERY X_GEN_TAC [`s:A->bool`; `f:(A->bool)->bool`] THEN
  ASM_CASES_TAC `f:(A->bool)->bool = {}` THEN
  ASM_SIMP_TAC[INTERS_0; INTER_UNIV] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC OPEN_IN_INTER THEN ASM_SIMP_TAC[]);;

let OPEN_IN_SUBOPEN = prove
 (`!top s:A->bool.
        open_in top s <=>
        !x. x IN s ==> ?t. open_in top t /\ x IN t /\ t SUBSET s`,
  REPEAT GEN_TAC THEN EQ_TAC THENL [MESON_TAC[SUBSET_REFL]; ALL_TAC] THEN
  REWRITE_TAC[RIGHT_IMP_EXISTS_THM; SKOLEM_THM] THEN
  REWRITE_TAC[TAUT `a ==> b /\ c <=> (a ==> b) /\ (a ==> c)`] THEN
  REWRITE_TAC[FORALL_AND_THM; LEFT_IMP_EXISTS_THM] THEN
  ONCE_REWRITE_TAC[GSYM FORALL_IN_IMAGE] THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_UNIONS) THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN ASM SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Closed sets.                                                              *)
(* ------------------------------------------------------------------------- *)

let closed_in = new_definition
 `closed_in top s <=>
        s SUBSET (topspace top) /\ open_in top (topspace top DIFF s)`;;

let CLOSED_IN_SUBSET = prove
 (`!top s. closed_in top s ==> s SUBSET (topspace top)`,
  MESON_TAC[closed_in]);;

let CLOSED_IN_EMPTY = prove
 (`!top. closed_in top {}`,
  REWRITE_TAC[closed_in; EMPTY_SUBSET; DIFF_EMPTY; OPEN_IN_TOPSPACE]);;

let CLOSED_IN_TOPSPACE = prove
 (`!top. closed_in top (topspace top)`,
  REWRITE_TAC[closed_in; SUBSET_REFL; DIFF_EQ_EMPTY; OPEN_IN_EMPTY]);;

let CLOSED_IN_UNION = prove
 (`!top s t. closed_in top s /\ closed_in top t ==> closed_in top (s UNION t)`,
  SIMP_TAC[closed_in; UNION_SUBSET; OPEN_IN_INTER;
           SET_RULE `u DIFF (s UNION t) = (u DIFF s) INTER (u DIFF t)`]);;

let CLOSED_IN_INTERS = prove
 (`!top k:(A->bool)->bool.
        ~(k = {}) /\ (!s. s IN k ==> closed_in top s)
        ==> closed_in top (INTERS k)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[closed_in] THEN REPEAT STRIP_TAC THENL
   [ASM SET_TAC[]; ALL_TAC] THEN
  SUBGOAL_THEN `topspace top DIFF INTERS k :A->bool =
                UNIONS {topspace top DIFF s | s IN k}` SUBST1_TAC
  THENL [ALL_TAC; MATCH_MP_TAC OPEN_IN_UNIONS THEN ASM SET_TAC[]] THEN
  GEN_REWRITE_TAC I [EXTENSION] THEN ONCE_REWRITE_TAC[SIMPLE_IMAGE] THEN
  REWRITE_TAC[IN_UNIONS; IN_INTERS; IN_DIFF; EXISTS_IN_IMAGE] THEN
  MESON_TAC[]);;

let CLOSED_IN_INTER = prove
 (`!top s t. closed_in top s /\ closed_in top t ==> closed_in top (s INTER t)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[GSYM INTERS_2] THEN
  MATCH_MP_TAC CLOSED_IN_INTERS THEN ASM SET_TAC[]);;

let OPEN_IN_CLOSED_IN_EQ = prove
 (`!top s. open_in top s <=>
           s SUBSET topspace top /\ closed_in top (topspace top DIFF s)`,
  REWRITE_TAC[closed_in; SET_RULE `(u DIFF s) SUBSET u`] THEN
  REWRITE_TAC[SET_RULE `u DIFF (u DIFF s) = u INTER s`] THEN
  MESON_TAC[OPEN_IN_SUBSET; SET_RULE `s SUBSET t ==> t INTER s = s`]);;

let OPEN_IN_CLOSED_IN = prove
 (`!s. s SUBSET topspace top
       ==> (open_in top s <=> closed_in top (topspace top DIFF s))`,
  SIMP_TAC[OPEN_IN_CLOSED_IN_EQ]);;

let OPEN_IN_DIFF = prove
 (`!top s t:A->bool.
      open_in top s /\ closed_in top t ==> open_in top (s DIFF t)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `s DIFF t :A->bool = s INTER (topspace top DIFF t)`
  SUBST1_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN SET_TAC[];
    MATCH_MP_TAC OPEN_IN_INTER THEN ASM_MESON_TAC[closed_in]]);;

let CLOSED_IN_DIFF = prove
 (`!top s t:A->bool.
        closed_in top s /\ open_in top t ==> closed_in top (s DIFF t)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `s DIFF t :A->bool = s INTER (topspace top DIFF t)`
  SUBST1_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN SET_TAC[];
    MATCH_MP_TAC CLOSED_IN_INTER THEN ASM_MESON_TAC[OPEN_IN_CLOSED_IN_EQ]]);;

let FORALL_OPEN_IN = prove
 (`!top. (!s. open_in top s ==> P s) <=>
         (!s. closed_in top s ==> P(topspace top DIFF s))`,
  MESON_TAC[OPEN_IN_CLOSED_IN_EQ; OPEN_IN_CLOSED_IN; closed_in;
            SET_RULE `s SUBSET u ==> u DIFF (u DIFF s) = s`]);;

let FORALL_CLOSED_IN = prove
 (`!top. (!s. closed_in top s ==> P s) <=>
         (!s. open_in top s ==> P(topspace top DIFF s))`,
  MESON_TAC[OPEN_IN_CLOSED_IN_EQ; OPEN_IN_CLOSED_IN; closed_in;
            SET_RULE `s SUBSET u ==> u DIFF (u DIFF s) = s`]);;

let EXISTS_OPEN_IN = prove
 (`!top. (?s. open_in top s /\ P s) <=>
         (?s. closed_in top s /\ P(topspace top DIFF s))`,
  MESON_TAC[OPEN_IN_CLOSED_IN_EQ; OPEN_IN_CLOSED_IN; closed_in;
            SET_RULE `s SUBSET u ==> u DIFF (u DIFF s) = s`]);;

let EXISTS_CLOSED_IN = prove
 (`!top. (?s. closed_in top s /\ P s) <=>
         (?s. open_in top s /\ P(topspace top DIFF s))`,
  MESON_TAC[OPEN_IN_CLOSED_IN_EQ; OPEN_IN_CLOSED_IN; closed_in;
            SET_RULE `s SUBSET u ==> u DIFF (u DIFF s) = s`]);;

let TOPOLOGY_FINER_CLOSED_IN = prove
 (`!top top':A topology.
        topspace top' = topspace top
        ==> ((!s. open_in top s ==> open_in top' s) <=>
             (!s. closed_in top s ==> closed_in top' s))`,
  REWRITE_TAC[FORALL_CLOSED_IN] THEN
  MESON_TAC[OPEN_IN_CLOSED_IN; OPEN_IN_SUBSET]);;

let CLOSED_IN_UNIONS = prove
 (`!top s. FINITE s /\ (!t. t IN s ==> closed_in top t)
           ==> closed_in top (UNIONS s)`,
  GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[UNIONS_INSERT; UNIONS_0; CLOSED_IN_EMPTY; IN_INSERT] THEN
  MESON_TAC[CLOSED_IN_UNION]);;

let TOPOLOGY_EQ_ALT = prove
 (`!top1 top2:A topology.
        top1 = top2 <=> !s. closed_in top1 s <=> closed_in top2 s`,
  REPEAT GEN_TAC THEN EQ_TAC THEN SIMP_TAC[] THEN DISCH_TAC THEN
  FIRST_ASSUM(fun th ->
    MP_TAC(SPEC `topspace top1:A->bool` th) THEN
    MP_TAC(SPEC `topspace top2:A->bool` th)) THEN
  REWRITE_TAC[CLOSED_IN_TOPSPACE; IMP_IMP] THEN
  DISCH_THEN(CONJUNCTS_THEN(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
  REWRITE_TAC[IMP_IMP; SUBSET_ANTISYM_EQ] THEN DISCH_TAC THEN
  REWRITE_TAC[TOPOLOGY_EQ; TAUT `(p <=> q) <=> (p ==> q) /\ (q ==> p)`] THEN
  ASM_REWRITE_TAC[FORALL_AND_THM; FORALL_OPEN_IN] THEN
  ASM_MESON_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE]);;

let CLOSED_IN_LOCALLY_FINITE_UNIONS = prove
 (`!top f:(A->bool)->bool.
        (!s. s IN f ==> closed_in top s) /\
        (!x. x IN topspace top
             ==> ?v. open_in top v /\ x IN v /\
                     FINITE {s | s IN f /\ ~(s INTER v = {})})
        ==> closed_in top (UNIONS f)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[closed_in] THEN CONJ_TAC THENL
    [RULE_ASSUM_TAC(REWRITE_RULE[closed_in]) THEN
     ASM_SIMP_TAC[UNIONS_SUBSET];
     ALL_TAC] THEN
  ONCE_REWRITE_TAC[OPEN_IN_SUBOPEN] THEN X_GEN_TAC `x:A` THEN
  REWRITE_TAC[IN_DIFF] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN ASM_REWRITE_TAC[] THEN
  DISCH_THEN(X_CHOOSE_THEN `v:A->bool` STRIP_ASSUME_TAC) THEN EXISTS_TAC
    `v DIFF UNIONS {s | s IN f /\ ~(s INTER v = {})}:A->bool` THEN
  ASM_REWRITE_TAC[IN_DIFF; GSYM CONJ_ASSOC] THEN CONJ_TAC THENL
   [MATCH_MP_TAC OPEN_IN_DIFF THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC CLOSED_IN_UNIONS THEN ASM_SIMP_TAC[IN_ELIM_THM];
    FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* The discrete topology.                                                    *)
(* ------------------------------------------------------------------------- *)

let discrete_topology = new_definition
 `discrete_topology u = topology {s:A->bool | s SUBSET u}`;;

let OPEN_IN_DISCRETE_TOPOLOGY = prove
 (`!u s:A->bool. open_in (discrete_topology u) s <=> s SUBSET u`,
  REPEAT GEN_TAC THEN REWRITE_TAC[discrete_topology] THEN
  GEN_REWRITE_TAC RAND_CONV [SET_RULE `s SUBSET u <=> {t | t SUBSET u} s`] THEN
  AP_THM_TAC THEN REWRITE_TAC[GSYM(CONJUNCT2 topology_tybij)] THEN
  REWRITE_TAC[istopology; IN_ELIM_THM; EMPTY_SUBSET; UNIONS_SUBSET] THEN
  SET_TAC[]);;

let TOPSPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. topspace(discrete_topology u) = u`,
  REWRITE_TAC[topspace; OPEN_IN_DISCRETE_TOPOLOGY] THEN SET_TAC[]);;

let CLOSED_IN_DISCRETE_TOPOLOGY = prove
 (`!u s:A->bool. closed_in (discrete_topology u) s <=> s SUBSET u`,
  REWRITE_TAC[closed_in] THEN
  REWRITE_TAC[OPEN_IN_DISCRETE_TOPOLOGY; TOPSPACE_DISCRETE_TOPOLOGY] THEN
  SET_TAC[]);;

let DISCRETE_TOPOLOGY_UNIQUE = prove
 (`!top u:A->bool.
        discrete_topology u = top <=>
        topspace top = u /\ (!x. x IN u ==> open_in top {x})`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [DISCH_THEN(SUBST1_TAC o SYM) THEN
    REWRITE_TAC[TOPSPACE_DISCRETE_TOPOLOGY; OPEN_IN_DISCRETE_TOPOLOGY] THEN
    REWRITE_TAC[SING_SUBSET];
    STRIP_TAC THEN REWRITE_TAC[TOPOLOGY_EQ; OPEN_IN_DISCRETE_TOPOLOGY] THEN
    X_GEN_TAC `s:A->bool` THEN EQ_TAC THENL
     [DISCH_TAC; ASM_MESON_TAC[OPEN_IN_SUBSET]] THEN
    SUBGOAL_THEN `s = UNIONS(IMAGE (\x:A. {x}) s)` SUBST1_TAC THENL
     [REWRITE_TAC[UNIONS_IMAGE] THEN SET_TAC[];
      MATCH_MP_TAC OPEN_IN_UNIONS THEN REWRITE_TAC[FORALL_IN_IMAGE] THEN
      ASM SET_TAC[]]]);;

let DISCRETE_TOPOLOGY_UNIQUE_ALT = prove
 (`!top u:A->bool.
        discrete_topology u = top <=>
        topspace top SUBSET u /\ (!x. x IN u ==> open_in top {x})`,
  REPEAT GEN_TAC THEN REWRITE_TAC[DISCRETE_TOPOLOGY_UNIQUE] THEN
  REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ] THEN MATCH_MP_TAC(TAUT
   `(r ==> q) ==> ((p /\ q) /\ r <=> p /\ r)`) THEN
  DISCH_TAC THEN MATCH_MP_TAC OPEN_IN_SUBSET THEN
  SUBGOAL_THEN `u = UNIONS(IMAGE (\x:A. {x}) u)` SUBST1_TAC THENL
   [REWRITE_TAC[UNIONS_IMAGE] THEN SET_TAC[];
    MATCH_MP_TAC OPEN_IN_UNIONS THEN ASM_REWRITE_TAC[FORALL_IN_IMAGE]]);;

let SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_EMPTY = prove
 (`!top:A topology. top = discrete_topology {} <=> topspace top = {}`,
  REPEAT GEN_TAC THEN EQ_TAC THEN SIMP_TAC[TOPSPACE_DISCRETE_TOPOLOGY] THEN
  DISCH_TAC THEN REWRITE_TAC[TOPOLOGY_EQ; OPEN_IN_DISCRETE_TOPOLOGY] THEN
  X_GEN_TAC `u:A->bool` THEN EQ_TAC THENL
   [ASM_MESON_TAC[OPEN_IN_SUBSET];
    REWRITE_TAC[SET_RULE `s SUBSET {} <=> s = {}`] THEN
    ASM_MESON_TAC[OPEN_IN_EMPTY; OPEN_IN_TOPSPACE]]);;

let SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_SING = prove
 (`!top a:A. top = discrete_topology {a} <=> topspace top = {a}`,
  REPEAT GEN_TAC THEN EQ_TAC THEN SIMP_TAC[TOPSPACE_DISCRETE_TOPOLOGY] THEN
  DISCH_TAC THEN REWRITE_TAC[TOPOLOGY_EQ; OPEN_IN_DISCRETE_TOPOLOGY] THEN
  X_GEN_TAC `u:A->bool` THEN EQ_TAC THENL
   [ASM_MESON_TAC[OPEN_IN_SUBSET];
    REWRITE_TAC[SET_RULE `s SUBSET {a} <=> s = {} \/ s = {a}`] THEN
    ASM_MESON_TAC[OPEN_IN_EMPTY; OPEN_IN_TOPSPACE]]);;

(* ------------------------------------------------------------------------- *)
(* Subspace topology.                                                        *)
(* ------------------------------------------------------------------------- *)

let subtopology = new_definition
 `subtopology top u = topology {s INTER u | open_in top s}`;;

let ISTOPLOGY_SUBTOPOLOGY = prove
 (`!top u:A->bool. istopology {s INTER u | open_in top s}`,
  REWRITE_TAC[istopology; SET_RULE
   `{s INTER u | open_in top s} =
    IMAGE (\s. s INTER u) {s | open_in top s}`] THEN
  REWRITE_TAC[IMP_CONJ; FORALL_IN_IMAGE; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[SUBSET_IMAGE; IN_IMAGE; IN_ELIM_THM; SUBSET] THEN
  REPEAT GEN_TAC THEN REPEAT CONJ_TAC THENL
   [EXISTS_TAC `{}:A->bool` THEN REWRITE_TAC[OPEN_IN_EMPTY; INTER_EMPTY];
    SIMP_TAC[SET_RULE `(s INTER u) INTER t INTER u = (s INTER t) INTER u`] THEN
    ASM_MESON_TAC[OPEN_IN_INTER];
    REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`f:(A->bool)->bool`; `g:(A->bool)->bool`] THEN
    STRIP_TAC THEN EXISTS_TAC `UNIONS g :A->bool` THEN
    ASM_SIMP_TAC[OPEN_IN_UNIONS; INTER_UNIONS] THEN SET_TAC[]]);;

let ISTOPOLOGY_RELATIVE_TO = prove
 (`!top u:A->bool.
        istopology top ==> istopology(top relative_to u)`,
  REWRITE_TAC[RELATIVE_TO] THEN ONCE_REWRITE_TAC[INTER_COMM] THEN
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC LAND_CONV [topology_tybij] THEN
  DISCH_THEN(SUBST1_TAC o SYM) THEN REWRITE_TAC[ISTOPLOGY_SUBTOPOLOGY]);;

let OPEN_IN_SUBTOPOLOGY = prove
 (`!top u s. open_in (subtopology top u) s <=>
                ?t. open_in top t /\ s = t INTER u`,
  REWRITE_TAC[subtopology] THEN
  SIMP_TAC[REWRITE_RULE[CONJUNCT2 topology_tybij] ISTOPLOGY_SUBTOPOLOGY] THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM]);;

let OPEN_IN_SUBSET_TOPSPACE = prove
 (`!top s t:A->bool.
        open_in top s /\ s SUBSET t ==> open_in (subtopology top t) s`,
  SIMP_TAC[OPEN_IN_SUBTOPOLOGY; SET_RULE `s SUBSET t <=> s INTER t = s`] THEN
  MESON_TAC[]);;

let OPEN_INTER_OPEN_IN_SUBTOPOLOGY = prove
 (`!top s t:A->bool.
        open_in top s ==> open_in (subtopology top t) (s INTER t)`,
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN MESON_TAC[]);;

let OPEN_IN_SUBTOPOLOGY_INTER_OPEN = prove
 (`!top s t:A->bool.
        open_in top t ==> open_in (subtopology top s) (s INTER t)`,
  ONCE_REWRITE_TAC[INTER_COMM] THEN
  REWRITE_TAC[OPEN_INTER_OPEN_IN_SUBTOPOLOGY]);;

let OPEN_IN_RELATIVE_TO = prove
 (`!top s t:A->bool.
        (open_in top relative_to s) t <=>
        open_in (subtopology top s) t`,
  REWRITE_TAC[relative_to; OPEN_IN_SUBTOPOLOGY] THEN MESON_TAC[INTER_COMM]);;

let OPEN_IN_SUBTOPOLOGY_ALT = prove
 (`!top u s:A->bool.
       open_in (subtopology top u) s <=> s IN {u INTER t | open_in top t}`,
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY; IN_ELIM_THM] THEN SET_TAC[]);;

let OPEN_IN_SUBSET_TRANS = prove
 (`!top s t u:A->bool.
         open_in (subtopology top u) s /\ s SUBSET t /\ t SUBSET u
         ==> open_in (subtopology top t) s`,
   REWRITE_TAC[GSYM OPEN_IN_RELATIVE_TO; RELATIVE_TO_SUBSET_TRANS]);;

let OPEN_IN_SUBTOPOLOGY_INTER_SUBSET = prove
 (`!top s u v:A->bool.
        open_in (subtopology top u) (u INTER s) /\ v SUBSET u
        ==> open_in (subtopology top v) (v INTER s)`,
  REPEAT GEN_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN MATCH_MP_TAC MONO_EXISTS THEN
  ASM SET_TAC[]);;

let OPEN_IN_SUBTOPOLOGY_INTER_OPEN_IN = prove
 (`!top s t u.
        open_in (subtopology top u) s /\ open_in top t
        ==> open_in (subtopology top u) (s INTER t)`,
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN REPEAT STRIP_TAC THEN
  ASM_MESON_TAC[OPEN_IN_INTER; INTER_ACI]);;

let TOPSPACE_SUBTOPOLOGY = prove
 (`!top u. topspace(subtopology top u) = topspace top INTER u`,
  REWRITE_TAC[topspace; OPEN_IN_SUBTOPOLOGY; INTER_UNIONS] THEN
  REPEAT STRIP_TAC THEN AP_TERM_TAC THEN
  GEN_REWRITE_TAC I [EXTENSION] THEN REWRITE_TAC[IN_ELIM_THM]);;

let TOPSPACE_SUBTOPOLOGY_SUBSET = prove
 (`!top s:A->bool. s SUBSET topspace top ==> topspace(subtopology top s) = s`,
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN SET_TAC[]);;

let TOPSPACE_SUBTOPOLOGY_IS_SUBSET = prove
 (`!top s:A->bool. topspace(subtopology top s) SUBSET s`,
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; INTER_SUBSET]);;

let OPEN_IN_TRANS = prove
 (`!top s t u:A->bool.

        open_in (subtopology top t) s /\
        open_in (subtopology top u) t
        ==> open_in (subtopology top u) s`,
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN REPEAT STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN ASM_MESON_TAC[OPEN_IN_INTER; INTER_ACI]);;

let CLOSED_IN_SUBTOPOLOGY = prove
 (`!top u s. closed_in (subtopology top u) s <=>
                ?t:A->bool. closed_in top t /\ s = t INTER u`,
  REWRITE_TAC[closed_in; TOPSPACE_SUBTOPOLOGY] THEN
  REWRITE_TAC[SUBSET_INTER; OPEN_IN_SUBTOPOLOGY; RIGHT_AND_EXISTS_THM] THEN
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  DISCH_THEN(X_CHOOSE_THEN `t:A->bool` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `topspace top DIFF t :A->bool` THEN
  ASM_SIMP_TAC[CLOSED_IN_TOPSPACE; OPEN_IN_DIFF; CLOSED_IN_DIFF;
               OPEN_IN_TOPSPACE] THEN
  ASM SET_TAC[]);;

let CLOSED_IN_SUBSET_TOPSPACE = prove
 (`!top s t:A->bool.
        closed_in top s /\ s SUBSET t ==> closed_in (subtopology top t) s`,
  SIMP_TAC[CLOSED_IN_SUBTOPOLOGY; SET_RULE `s SUBSET t <=> s INTER t = s`] THEN
  MESON_TAC[]);;

let CLOSED_INTER_CLOSED_IN_SUBTOPOLOGY = prove
 (`!top s t:A->bool.
        closed_in top s ==> closed_in (subtopology top t) (s INTER t)`,
  REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY] THEN MESON_TAC[]);;

let CLOSED_IN_SUBTOPOLOGY_INTER_CLOSED = prove
 (`!top s t:A->bool.
        closed_in top t ==> closed_in (subtopology top s) (s INTER t)`,
  ONCE_REWRITE_TAC[INTER_COMM] THEN
  REWRITE_TAC[CLOSED_INTER_CLOSED_IN_SUBTOPOLOGY]);;

let CLOSED_IN_RELATIVE_TO = prove
 (`!top s t:A->bool.
        (closed_in top relative_to s) t <=>
        closed_in (subtopology top s) t`,
  REWRITE_TAC[relative_to; CLOSED_IN_SUBTOPOLOGY] THEN MESON_TAC[INTER_COMM]);;

let CLOSED_IN_SUBTOPOLOGY_ALT = prove
 (`!top u s:A->bool.
       closed_in (subtopology top u) s <=> s IN {u INTER t | closed_in top t}`,
  REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY; IN_ELIM_THM] THEN SET_TAC[]);;

let CLOSED_IN_SUBSET_TRANS = prove
 (`!top s t u:A->bool.
         closed_in (subtopology top u) s /\ s SUBSET t /\ t SUBSET u
         ==> closed_in (subtopology top t) s`,
   REWRITE_TAC[GSYM CLOSED_IN_RELATIVE_TO; RELATIVE_TO_SUBSET_TRANS]);;

let CLOSED_IN_SUBTOPOLOGY_INTER_SUBSET = prove
 (`!top s u v:A->bool.
        closed_in (subtopology top u) (u INTER s) /\ v SUBSET u
        ==> closed_in (subtopology top v) (v INTER s)`,
  REPEAT GEN_TAC THEN SIMP_TAC[CLOSED_IN_SUBTOPOLOGY; LEFT_AND_EXISTS_THM] THEN
  MATCH_MP_TAC MONO_EXISTS THEN SET_TAC[]);;

let CLOSED_IN_SUBTOPOLOGY_INTER_CLOSED_IN = prove
 (`!top s t u.
        closed_in (subtopology top u) s /\ closed_in top t
        ==> closed_in (subtopology top u) (s INTER t)`,
  REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY] THEN REPEAT STRIP_TAC THEN
  ASM_MESON_TAC[CLOSED_IN_INTER; INTER_ACI]);;

let SUBTOPOLOGY_SUBTOPOLOGY = prove
 (`!top s t:A->bool.
        subtopology (subtopology top s) t = subtopology top (s INTER t)`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[subtopology] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[SET_RULE `{f x | ?y. P y /\ x = g y} = {f(g y) | P y}`] THEN
  REWRITE_TAC[INTER_ASSOC]);;

let CLOSED_IN_TRANS = prove
 (`!top s t u:A->bool.
        closed_in (subtopology top t) s /\
        closed_in (subtopology top u) t
        ==> closed_in (subtopology top u) s`,
  REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY] THEN REPEAT STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN ASM_MESON_TAC[CLOSED_IN_INTER; INTER_ACI]);;

let OPEN_IN_TOPSPACE_EMPTY = prove
 (`!top:A topology s. topspace top = {} ==> (open_in top s <=> s = {})`,
  MESON_TAC[OPEN_IN_EMPTY; OPEN_IN_SUBSET; SUBSET_EMPTY]);;

let CLOSED_IN_TOPSPACE_EMPTY = prove
 (`!top:A topology s. topspace top = {} ==> (closed_in top s <=> s = {})`,
  MESON_TAC[CLOSED_IN_EMPTY; CLOSED_IN_SUBSET; SUBSET_EMPTY]);;

let OPEN_IN_SUBTOPOLOGY_EMPTY = prove
 (`!top s. open_in (subtopology top {}) s <=> s = {}`,
  SIMP_TAC[OPEN_IN_TOPSPACE_EMPTY; TOPSPACE_SUBTOPOLOGY; INTER_EMPTY]);;

let CLOSED_IN_SUBTOPOLOGY_EMPTY = prove
 (`!top s. closed_in (subtopology top {}) s <=> s = {}`,
  SIMP_TAC[CLOSED_IN_TOPSPACE_EMPTY; TOPSPACE_SUBTOPOLOGY; INTER_EMPTY]);;

let OPEN_IN_SUBTOPOLOGY_REFL = prove
 (`!top u:A->bool. open_in (subtopology top u) u <=> u SUBSET topspace top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN EQ_TAC THENL
   [REPEAT STRIP_TAC THEN ONCE_ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC(SET_RULE `s SUBSET u ==> s INTER t SUBSET u`) THEN
    ASM_SIMP_TAC[OPEN_IN_SUBSET];
    DISCH_TAC THEN EXISTS_TAC `topspace top:A->bool` THEN
    REWRITE_TAC[OPEN_IN_TOPSPACE] THEN ASM SET_TAC[]]);;

let CLOSED_IN_SUBTOPOLOGY_REFL = prove
 (`!top u:A->bool. closed_in (subtopology top u) u <=> u SUBSET topspace top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY] THEN EQ_TAC THENL
   [REPEAT STRIP_TAC THEN ONCE_ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC(SET_RULE `s SUBSET u ==> s INTER t SUBSET u`) THEN
    ASM_SIMP_TAC[CLOSED_IN_SUBSET];
    DISCH_TAC THEN EXISTS_TAC `topspace top:A->bool` THEN
    REWRITE_TAC[CLOSED_IN_TOPSPACE] THEN ASM SET_TAC[]]);;

let SUBTOPOLOGY_SUPERSET = prove
 (`!top s:A->bool. topspace top SUBSET s ==> subtopology top s = top`,
  REPEAT GEN_TAC THEN SIMP_TAC[TOPOLOGY_EQ; OPEN_IN_SUBTOPOLOGY] THEN
  DISCH_TAC THEN X_GEN_TAC `u:A->bool` THEN EQ_TAC THENL
   [DISCH_THEN(CHOOSE_THEN(CONJUNCTS_THEN2 MP_TAC SUBST1_TAC)) THEN
    DISCH_THEN(fun th -> MP_TAC th THEN
      ASSUME_TAC(MATCH_MP OPEN_IN_SUBSET th)) THEN
    MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN ASM SET_TAC[];
    DISCH_TAC THEN EXISTS_TAC `u:A->bool` THEN
    FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]]);;

let SUBTOPOLOGY_TOPSPACE = prove
 (`!top. subtopology top (topspace top) = top`,
  SIMP_TAC[SUBTOPOLOGY_SUPERSET; SUBSET_REFL]);;

let SUBTOPOLOGY_UNIV = prove
 (`!top. subtopology top UNIV = top`,
  SIMP_TAC[SUBTOPOLOGY_SUPERSET; SUBSET_UNIV]);;

let SUBTOPOLOGY_RESTRICT = prove
 (`!top s:A->bool.
        subtopology top s = subtopology top (topspace top INTER s)`,
  MESON_TAC[SUBTOPOLOGY_TOPSPACE; SUBTOPOLOGY_SUBTOPOLOGY]);;

let OPEN_IN_IMP_SUBSET = prove
 (`!top s t. open_in (subtopology top s) t ==> t SUBSET s`,
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN SET_TAC[]);;

let CLOSED_IN_IMP_SUBSET = prove
 (`!top s t. closed_in (subtopology top s) t ==> t SUBSET s`,
  REWRITE_TAC[closed_in; TOPSPACE_SUBTOPOLOGY] THEN SET_TAC[]);;

let OPEN_IN_TRANS_FULL = prove
 (`!top s t u.
        open_in (subtopology top u) s /\ open_in top u ==> open_in top s`,
  MESON_TAC[OPEN_IN_TRANS; SUBTOPOLOGY_TOPSPACE]);;

let CLOSED_IN_TRANS_FULL = prove
 (`!top s t u.
      closed_in (subtopology top u) s /\ closed_in top u ==> closed_in top s`,
  MESON_TAC[CLOSED_IN_TRANS; SUBTOPOLOGY_TOPSPACE]);;

let OPEN_IN_SUBTOPOLOGY_DIFF_CLOSED = prove
 (`!top s t:A->bool.
        s SUBSET topspace top /\ closed_in top t
        ==> open_in (subtopology top s) (s DIFF t)`,
  REWRITE_TAC[closed_in; OPEN_IN_SUBTOPOLOGY] THEN REPEAT STRIP_TAC THEN
  EXISTS_TAC `topspace top DIFF t:A->bool` THEN ASM SET_TAC[]);;

let CLOSED_IN_SUBTOPOLOGY_DIFF_OPEN = prove
 (`!top s t:A->bool.
        s SUBSET topspace top /\ open_in top t
        ==> closed_in (subtopology top s) (s DIFF t)`,
  REWRITE_TAC[OPEN_IN_CLOSED_IN_EQ; CLOSED_IN_SUBTOPOLOGY] THEN
  REPEAT STRIP_TAC THEN
  EXISTS_TAC `topspace top DIFF t:A->bool` THEN ASM SET_TAC[]);;

let OPEN_IN_SUBTOPOLOGY_UNION = prove
 (`!top s t u:A->bool.
        open_in (subtopology top t) s /\ open_in (subtopology top u) s
        ==> open_in (subtopology top (t UNION u)) s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN
  DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_THEN `s':A->bool` STRIP_ASSUME_TAC)
   (X_CHOOSE_THEN `t':A->bool` STRIP_ASSUME_TAC)) THEN
  EXISTS_TAC `s' INTER t':A->bool` THEN ASM_SIMP_TAC[OPEN_IN_INTER] THEN
  ASM SET_TAC[]);;

let CLOSED_IN_SUBTOPOLOGY_UNION = prove
 (`!top s t u:A->bool.
        closed_in (subtopology top t) s /\ closed_in (subtopology top u) s
        ==> closed_in (subtopology top (t UNION u)) s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY] THEN
  DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_THEN `s':A->bool` STRIP_ASSUME_TAC)
   (X_CHOOSE_THEN `t':A->bool` STRIP_ASSUME_TAC)) THEN
  EXISTS_TAC `s' INTER t':A->bool` THEN ASM_SIMP_TAC[CLOSED_IN_INTER] THEN
  ASM SET_TAC[]);;

let SUBTOPOLOGY_DISCRETE_TOPOLOGY = prove
 (`!u s:A->bool.
        subtopology (discrete_topology u) s = discrete_topology(u INTER s)`,
  REWRITE_TAC[subtopology; OPEN_IN_DISCRETE_TOPOLOGY] THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[discrete_topology] THEN
  AP_TERM_TAC THEN REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ] THEN
  ONCE_REWRITE_TAC[SUBSET] THEN REWRITE_TAC[FORALL_IN_GSPEC] THEN
  SIMP_TAC[IN_ELIM_THM; SUBSET_INTER] THEN SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Derived set (set of limit points).                                        *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("derived_set_of",(21,"right"));;

let derived_set_of = new_definition
  `top derived_set_of s =
   {x:A | x IN topspace top /\
          (!t. x IN t /\ open_in top t
               ==> ?y. ~(y = x) /\ y IN s /\ y IN t)}`;;

let DERIVED_SET_OF_RESTRICT = prove
 (`!top s:A->bool.
     top derived_set_of s = top derived_set_of (topspace top INTER s)`,
  REWRITE_TAC[derived_set_of; EXTENSION; IN_ELIM_THM; IN_INTER] THEN
  MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let IN_DERIVED_SET_OF = prove
 (`!top s x:A.
     x IN top derived_set_of s <=>
     x IN topspace top /\
     (!t. x IN t /\ open_in top t ==> ?y. ~(y = x) /\ y IN s /\ y IN t)`,
  REWRITE_TAC[derived_set_of; IN_ELIM_THM]);;

let DERIVED_SET_OF_SUBSET_TOPSPACE = prove
 (`!top s:A->bool. top derived_set_of s SUBSET topspace top`,
  REWRITE_TAC[derived_set_of] THEN SET_TAC[]);;

let DERIVED_SET_OF_SUBTOPOLOGY = prove
 (`!top u s:A->bool.
        (subtopology top u) derived_set_of s =
        u INTER top derived_set_of (u INTER s)`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC I [EXTENSION] THEN
  REWRITE_TAC[derived_set_of; OPEN_IN_SUBTOPOLOGY; TOPSPACE_SUBTOPOLOGY] THEN
  REWRITE_TAC[RIGHT_AND_EXISTS_THM; LEFT_IMP_EXISTS_THM; IN_ELIM_THM] THEN
  ONCE_REWRITE_TAC[SWAP_FORALL_THM] THEN ONCE_REWRITE_TAC[TAUT
   `p /\ q /\ r ==> s <=> r ==> p /\ q ==> s`] THEN
  REWRITE_TAC[FORALL_UNWIND_THM2; IN_INTER; IN_ELIM_THM] THEN
  ASM SET_TAC[]);;

let DERIVED_SET_OF_SUBSET_SUBTOPOLOGY = prove
 (`!top s t:A->bool. (subtopology top s) derived_set_of t SUBSET s`,
  SIMP_TAC[DERIVED_SET_OF_SUBTOPOLOGY; INTER_SUBSET]);;

let DERIVED_SET_OF_EMPTY = prove
 (`!top:A topology. top derived_set_of {} = {}`,
  REWRITE_TAC[EXTENSION; IN_DERIVED_SET_OF; NOT_IN_EMPTY] THEN
  MESON_TAC[OPEN_IN_TOPSPACE]);;

let DERIVED_SET_OF_MONO = prove
 (`!top s t:A->bool.
        s SUBSET t ==> top derived_set_of s SUBSET top derived_set_of t`,
  REWRITE_TAC[derived_set_of] THEN SET_TAC[]);;

let DERIVED_SET_OF_UNION = prove
 (`!top s t:A->bool.
       top derived_set_of (s UNION t) =
       top derived_set_of s UNION top derived_set_of t`,
  REPEAT GEN_TAC THEN
  SIMP_TAC[GSYM SUBSET_ANTISYM_EQ; UNION_SUBSET; DERIVED_SET_OF_MONO;
           SUBSET_UNION] THEN
  REWRITE_TAC[SUBSET; IN_DERIVED_SET_OF; IN_UNION] THEN
  X_GEN_TAC `x:A` THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  ASM_REWRITE_TAC[] THEN GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN
  REWRITE_TAC[DE_MORGAN_THM; NOT_FORALL_THM; NOT_IMP] THEN
  DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_TAC `u:A->bool`) (X_CHOOSE_TAC `v:A->bool`)) THEN
  EXISTS_TAC `u INTER v:A->bool` THEN
  ASM_SIMP_TAC[OPEN_IN_INTER; IN_INTER] THEN ASM_MESON_TAC[]);;

let DERIVED_SET_OF_UNIONS = prove
 (`!top (f:(A->bool)->bool).
        FINITE f
        ==> top derived_set_of (UNIONS f) =
            UNIONS {top derived_set_of s | s IN f}`,
  GEN_TAC THEN MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[UNIONS_0; NOT_IN_EMPTY; UNIONS_INSERT; DERIVED_SET_OF_EMPTY;
           DERIVED_SET_OF_UNION; SIMPLE_IMAGE; IMAGE_CLAUSES]);;

let DERIVED_SET_OF_TOPSPACE = prove
 (`!top:A topology.
        top derived_set_of (topspace top) =
        {x | x IN topspace top /\ ~open_in top {x}}`,
  GEN_TAC THEN REWRITE_TAC[EXTENSION; derived_set_of; IN_ELIM_THM] THEN
  X_GEN_TAC `a:A` THEN ASM_CASES_TAC `(a:A) IN topspace top` THEN
  ASM_REWRITE_TAC[] THEN EQ_TAC THEN DISCH_TAC THENL
   [DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC `{a:A}`) THEN ASM SET_TAC[];
    X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
    ASM_CASES_TAC `u = {a:A}` THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
    FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]]);;

let DISCRETE_TOPOLOGY_UNIQUE_DERIVED_SET = prove
 (`!top u:A->bool.
        discrete_topology u = top <=>
        topspace top = u /\ top derived_set_of u = {}`,
  REPEAT GEN_TAC THEN REWRITE_TAC[DISCRETE_TOPOLOGY_UNIQUE] THEN
  ASM_CASES_TAC `u:A->bool = topspace top` THEN
  ASM_REWRITE_TAC[DERIVED_SET_OF_TOPSPACE] THEN SET_TAC[]);;

let SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_EQ = prove
 (`!top u:A->bool.
        subtopology top u = discrete_topology u <=>
        u SUBSET topspace top /\ u INTER top derived_set_of u = {}`,
  REPEAT GEN_TAC THEN CONV_TAC (LAND_CONV SYM_CONV) THEN
  REWRITE_TAC[DISCRETE_TOPOLOGY_UNIQUE_DERIVED_SET] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; DERIVED_SET_OF_SUBTOPOLOGY] THEN
  REWRITE_TAC[SET_RULE `u INTER u = u`] THEN SET_TAC[]);;

let SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY = prove
 (`!top s:A->bool.
        s SUBSET topspace top /\ s INTER top derived_set_of s = {}
        ==> subtopology top s = discrete_topology s`,
  REWRITE_TAC[SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_EQ]);;

let SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_GEN = prove
 (`!top s:A->bool.
        s INTER top derived_set_of s = {}
        ==> subtopology top s = discrete_topology(topspace top INTER s)`,
  REPEAT STRIP_TAC THEN
  ONCE_REWRITE_TAC[SUBTOPOLOGY_RESTRICT] THEN
  MATCH_MP_TAC SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY THEN
  REWRITE_TAC[GSYM DERIVED_SET_OF_RESTRICT] THEN ASM SET_TAC[]);;

let OPEN_IN_INTER_DERIVED_SET_OF_SUBSET = prove
 (`!top s t:A->bool.
       open_in top s
       ==> s INTER top derived_set_of t SUBSET top derived_set_of (s INTER t)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[derived_set_of] THEN
  REWRITE_TAC[SUBSET; IN_INTER; IN_ELIM_THM] THEN
  X_GEN_TAC `x:A` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `s INTER u:A->bool`) THEN
  ASM_SIMP_TAC[OPEN_IN_INTER; IN_INTER] THEN MESON_TAC[]);;

let OPEN_IN_INTER_DERIVED_SET_OF_EQ = prove
 (`!top s t:A->bool.
        open_in top s
        ==> s INTER top derived_set_of t =
            s INTER top derived_set_of (s INTER t)`,
  SIMP_TAC[GSYM SUBSET_ANTISYM_EQ; INTER_SUBSET; SUBSET_INTER] THEN
  SIMP_TAC[OPEN_IN_INTER_DERIVED_SET_OF_SUBSET] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC(SET_RULE `s SUBSET t ==> u INTER s SUBSET t`) THEN
  MATCH_MP_TAC DERIVED_SET_OF_MONO THEN SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Closure with respect to a topological space.                              *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("closure_of",(21,"right"));;

let closure_of = new_definition
  `top closure_of s =
   {x:A | x IN topspace top /\
          (!t. x IN t /\ open_in top t ==> ?y. y IN s /\ y IN t)}`;;

let CLOSURE_OF_RESTRICT = prove
 (`!top s:A->bool. top closure_of s = top closure_of (topspace top INTER s)`,
  REWRITE_TAC[closure_of; EXTENSION; IN_ELIM_THM; IN_INTER] THEN
  MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let IN_CLOSURE_OF = prove
 (`!top s x:A.
     x IN top closure_of s <=>
     x IN topspace top /\
     (!t. x IN t /\ open_in top t ==> ?y. y IN s /\ y IN t)`,
  REWRITE_TAC[closure_of; IN_ELIM_THM]);;

let CLOSURE_OF = prove
 (`!top s:A->bool.
     top closure_of s =
     topspace top INTER (s UNION top derived_set_of s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[EXTENSION] THEN FIX_TAC "[x]" THEN
  REWRITE_TAC[IN_CLOSURE_OF; IN_DERIVED_SET_OF; IN_UNION; IN_INTER] THEN
  ASM_CASES_TAC `x:A IN topspace top` THEN ASM_REWRITE_TAC[] THEN
  POP_ASSUM(LABEL_TAC "x_ok") THEN MESON_TAC[]);;

let CLOSURE_OF_ALT = prove
 (`!top s:A->bool.
        top closure_of s = topspace top INTER s UNION top derived_set_of s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CLOSURE_OF] THEN
  MP_TAC(ISPECL [`top:A topology`; `s:A->bool`]
        DERIVED_SET_OF_SUBSET_TOPSPACE) THEN
  SET_TAC[]);;

let DERIVED_SET_OF_SUBSET_CLOSURE_OF = prove
 (`!top s:A->bool. top derived_set_of s SUBSET top closure_of s`,
  REWRITE_TAC[CLOSURE_OF; SUBSET_INTER; DERIVED_SET_OF_SUBSET_TOPSPACE] THEN
  SIMP_TAC[SUBSET_UNION]);;

let CLOSURE_OF_SUBTOPOLOGY = prove
 (`!top u s:A->bool.
      (subtopology top u) closure_of s = u INTER (top closure_of (u INTER s))`,
  SIMP_TAC[CLOSURE_OF; TOPSPACE_SUBTOPOLOGY; DERIVED_SET_OF_SUBTOPOLOGY] THEN
  SET_TAC[]);;

let CLOSURE_OF_EMPTY = prove
 (`!top. top closure_of {}:A->bool = {}`,
  REWRITE_TAC[EXTENSION; IN_CLOSURE_OF; NOT_IN_EMPTY] THEN
  MESON_TAC[OPEN_IN_TOPSPACE]);;

let CLOSURE_OF_TOPSPACE = prove
 (`!top:A topology. top closure_of topspace top = topspace top`,
  REWRITE_TAC[EXTENSION; IN_CLOSURE_OF] THEN MESON_TAC[]);;

let CLOSURE_OF_UNIV = prove
 (`!top. top closure_of (:A) = topspace top`,
  REWRITE_TAC[closure_of] THEN SET_TAC[]);;

let CLOSURE_OF_SUBSET_TOPSPACE = prove
 (`!top s:A->bool. top closure_of s SUBSET topspace top`,
  REWRITE_TAC[closure_of] THEN SET_TAC[]);;

let CLOSURE_OF_SUBSET_SUBTOPOLOGY = prove
 (`!top s t:A->bool. (subtopology top s) closure_of t SUBSET s`,
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; closure_of] THEN SET_TAC[]);;

let CLOSURE_OF_MONO = prove
 (`!top s t:A->bool.
        s SUBSET t ==> top closure_of s SUBSET top closure_of t`,
  REWRITE_TAC[closure_of] THEN SET_TAC[]);;

let CLOSURE_OF_SUBTOPOLOGY_SUBSET = prove
 (`!top s u:A->bool.
        (subtopology top u) closure_of s SUBSET (top closure_of s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CLOSURE_OF_SUBTOPOLOGY] THEN
  MATCH_MP_TAC(SET_RULE `t SUBSET u ==> s INTER t SUBSET u`) THEN
  MATCH_MP_TAC CLOSURE_OF_MONO THEN REWRITE_TAC[INTER_SUBSET]);;

let CLOSURE_OF_SUBTOPOLOGY_MONO = prove
 (`!top s t u:A->bool.
        t SUBSET u
        ==> (subtopology top t) closure_of s SUBSET
            (subtopology top u) closure_of s`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[CLOSURE_OF_SUBTOPOLOGY] THEN
  MATCH_MP_TAC(SET_RULE
   `s SUBSET s' /\ t SUBSET t' ==> s INTER t SUBSET s' INTER t'`) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC CLOSURE_OF_MONO THEN
  ASM SET_TAC[]);;

let CLOSURE_OF_UNION = prove
 (`!top s t:A->bool.
       top closure_of (s UNION t) = top closure_of s UNION top closure_of t`,
  REWRITE_TAC[CLOSURE_OF; DERIVED_SET_OF_UNION] THEN SET_TAC[]);;

let CLOSURE_OF_UNIONS = prove
 (`!top (f:(A->bool)->bool).
        FINITE f
        ==> top closure_of (UNIONS f) =  UNIONS {top closure_of s | s IN f}`,
  GEN_TAC THEN MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[UNIONS_0; NOT_IN_EMPTY; UNIONS_INSERT; CLOSURE_OF_EMPTY;
           CLOSURE_OF_UNION; SIMPLE_IMAGE; IMAGE_CLAUSES]);;

let CLOSURE_OF_SUBSET = prove
 (`!top s:A->bool. s SUBSET topspace top ==> s SUBSET top closure_of s`,
  REWRITE_TAC[CLOSURE_OF] THEN SET_TAC[]);;

let CLOSURE_OF_SUBSET_INTER = prove
 (`!top s:A->bool. topspace top INTER s SUBSET top closure_of s`,
  REWRITE_TAC[CLOSURE_OF] THEN SET_TAC[]);;

let CLOSURE_OF_SUBSET_EQ = prove
 (`!top s:A->bool.
     s SUBSET topspace top /\ top closure_of s SUBSET s <=> closed_in top s`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THEN
  ASM_REWRITE_TAC[closed_in; SUBSET; closure_of; IN_ELIM_THM] THEN
  GEN_REWRITE_TAC RAND_CONV [OPEN_IN_SUBOPEN] THEN
  MP_TAC(ISPEC `top:A topology` OPEN_IN_SUBSET) THEN ASM SET_TAC[]);;

let CLOSURE_OF_EQ = prove
 (`!top s:A->bool. top closure_of s = s <=> closed_in top s`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THENL
   [ASM_MESON_TAC[SUBSET_ANTISYM_EQ; CLOSURE_OF_SUBSET; CLOSURE_OF_SUBSET_EQ];
    ASM_MESON_TAC[CLOSED_IN_SUBSET; CLOSURE_OF_SUBSET_TOPSPACE]]);;

let CLOSED_IN_CONTAINS_DERIVED_SET = prove
 (`!top s:A->bool.
        closed_in top s <=>
        top derived_set_of s SUBSET s /\ s SUBSET topspace top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[GSYM CLOSURE_OF_SUBSET_EQ; CLOSURE_OF] THEN
  MP_TAC(ISPECL [`top:A topology`; `s:A->bool`]
    DERIVED_SET_OF_SUBSET_TOPSPACE) THEN
  SET_TAC[]);;

let DERIVED_SET_SUBSET_GEN = prove
 (`!top s:A->bool.
        top derived_set_of s SUBSET s <=>
        closed_in top (topspace top INTER s)`,
  REWRITE_TAC[CLOSED_IN_CONTAINS_DERIVED_SET; INTER_SUBSET] THEN
  REWRITE_TAC[GSYM DERIVED_SET_OF_RESTRICT; SUBSET_INTER] THEN
  REWRITE_TAC[DERIVED_SET_OF_SUBSET_TOPSPACE]);;

let DERIVED_SET_SUBSET = prove
 (`!top s:A->bool.
        s SUBSET topspace top
        ==> (top derived_set_of s SUBSET s <=> closed_in top s)`,
  SIMP_TAC[CLOSED_IN_CONTAINS_DERIVED_SET]);;

let CLOSED_IN_DERIVED_SET = prove
 (`!top s t:A->bool.
        closed_in (subtopology top t) s <=>
        s SUBSET topspace top /\ s SUBSET t /\
        !x. x IN top derived_set_of s /\ x IN t ==> x IN s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CLOSED_IN_CONTAINS_DERIVED_SET] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER] THEN
  REWRITE_TAC[DERIVED_SET_OF_SUBTOPOLOGY] THEN
  ASM_CASES_TAC `t INTER s:A->bool = s` THEN ASM_REWRITE_TAC[] THEN
  ASM SET_TAC[]);;

let CLOSED_IN_INTER_CLOSURE_OF = prove
 (`!top s t:A->bool.
        closed_in (subtopology top s) t <=> s INTER top closure_of t = t`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CLOSURE_OF; CLOSED_IN_DERIVED_SET] THEN
  MP_TAC(ISPECL [`top:A topology`; `t:A->bool`]
        DERIVED_SET_OF_SUBSET_TOPSPACE) THEN
  SET_TAC[]);;

let CLOSURE_OF_CLOSED_IN = prove
 (`!top s:A->bool. closed_in top s ==> top closure_of s = s`,
  REWRITE_TAC[CLOSURE_OF_EQ]);;

let CLOSED_IN_CLOSURE_OF = prove
 (`!top s:A->bool. closed_in top (top closure_of s)`,
   REPEAT GEN_TAC THEN
  SUBGOAL_THEN
   `top closure_of (s:A->bool) =
    topspace top DIFF
    UNIONS {t | open_in top t /\ DISJOINT s t}`
  SUBST1_TAC THENL
   [REWRITE_TAC[closure_of; UNIONS_GSPEC] THEN SET_TAC[];
    MATCH_MP_TAC CLOSED_IN_DIFF THEN REWRITE_TAC[CLOSED_IN_TOPSPACE] THEN
    SIMP_TAC[OPEN_IN_UNIONS; FORALL_IN_GSPEC]]);;

let CLOSURE_OF_CLOSURE_OF = prove
 (`!top s:A->bool. top closure_of (top closure_of s) = top closure_of s`,
  REWRITE_TAC[CLOSURE_OF_EQ; CLOSED_IN_CLOSURE_OF]);;

let CLOSURE_OF_HULL = prove
 (`!top s:A->bool.
        s SUBSET topspace top ==> top closure_of s = (closed_in top) hull s`,
  REPEAT STRIP_TAC THEN CONV_TAC SYM_CONV THEN MATCH_MP_TAC HULL_UNIQUE THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBSET; CLOSED_IN_CLOSURE_OF] THEN
  ASM_MESON_TAC[CLOSURE_OF_EQ; CLOSURE_OF_MONO]);;

let CLOSURE_OF_MINIMAL = prove
 (`!top s t:A->bool.
        s SUBSET t /\ closed_in top t ==> (top closure_of s) SUBSET t`,
  ASM_MESON_TAC[CLOSURE_OF_EQ; CLOSURE_OF_MONO]);;

let CLOSURE_OF_MINIMAL_EQ = prove
 (`!top s t:A->bool.
        s SUBSET topspace top /\ closed_in top t
        ==> ((top closure_of s) SUBSET t <=> s SUBSET t)`,
  MESON_TAC[SUBSET_TRANS; CLOSURE_OF_SUBSET; CLOSURE_OF_MINIMAL]);;

let CLOSURE_OF_UNIQUE = prove
 (`!top s t. s SUBSET t /\ closed_in top t /\
             (!t'. s SUBSET t' /\ closed_in top t' ==> t SUBSET t')
             ==> top closure_of s = t`,
  REPEAT STRIP_TAC THEN
  W(MP_TAC o PART_MATCH (lhand o rand) CLOSURE_OF_HULL o lhand o snd) THEN
  ANTS_TAC THENL
   [ASM_MESON_TAC[CLOSED_IN_SUBSET; SUBSET_TRANS];
    DISCH_THEN SUBST1_TAC] THEN
  MATCH_MP_TAC HULL_UNIQUE THEN ASM_REWRITE_TAC[]);;

let FORALL_IN_CLOSURE_OF_GEN = prove
 (`!top P s:A->bool.
         (!x. x IN s ==> P x) /\
         closed_in top {x | x IN top closure_of s /\ P x}
         ==> (!x. x IN top closure_of s ==> P x)`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
  STRIP_TAC THEN
  REWRITE_TAC[SET_RULE
   `(!x. x IN s ==> P x) <=> s SUBSET {x | x IN s /\ P x}`] THEN
  MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN ASM_REWRITE_TAC[] THEN
  MP_TAC(ISPECL [`top:A topology`; `topspace top INTER s:A->bool`]
        CLOSURE_OF_SUBSET) THEN
  ASM SET_TAC[]);;

let FORALL_IN_CLOSURE_OF = prove
 (`!top P s:A->bool.
         (!x. x IN s ==> P x) /\
         closed_in top {x | x IN topspace top /\ P x}
         ==> (!x. x IN top closure_of s ==> P x)`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  MATCH_MP_TAC FORALL_IN_CLOSURE_OF_GEN THEN ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN `{x:A | x IN top closure_of s /\ P x} =
                top closure_of s INTER {x | x IN topspace top /\ P x}`
   (fun th -> ASM_SIMP_TAC[th; CLOSED_IN_INTER; CLOSED_IN_CLOSURE_OF]) THEN
  MP_TAC(ISPECL
   [`top:A topology`; `s:A->bool`] CLOSURE_OF_SUBSET_TOPSPACE) THEN
  SET_TAC[]);;

let FORALL_IN_CLOSURE_OF_UNIV = prove
 (`!top P s:A->bool.
        (!x. x IN s ==> P x) /\ closed_in top {x | P x}
        ==> !x. x IN top closure_of s ==> P x`,
  REWRITE_TAC[SET_RULE `(!x. x IN s ==> P x) <=> s SUBSET {x | P x}`] THEN
  SIMP_TAC[CLOSURE_OF_MINIMAL]);;

let CLOSURE_OF_EQ_EMPTY_GEN = prove
 (`!top s:A->bool.
        top closure_of s = {} <=> DISJOINT (topspace top) s`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT; DISJOINT] THEN
  EQ_TAC THEN SIMP_TAC[CLOSURE_OF_EMPTY] THEN
  MATCH_MP_TAC(SET_RULE `t SUBSET s ==> s = {} ==> t = {}`) THEN
  MATCH_MP_TAC CLOSURE_OF_SUBSET THEN REWRITE_TAC[INTER_SUBSET]);;

let CLOSURE_OF_EQ_EMPTY = prove
 (`!top s:A->bool.
        s SUBSET topspace top ==> (top closure_of s = {} <=> s = {})`,
  REWRITE_TAC[CLOSURE_OF_EQ_EMPTY_GEN] THEN SET_TAC[]);;

let OPEN_IN_INTER_CLOSURE_OF_SUBSET = prove
 (`!top s t:A->bool.
        open_in top s
        ==> s INTER top closure_of t SUBSET top closure_of (s INTER t)`,
  REPEAT GEN_TAC THEN DISCH_THEN(MP_TAC o SPEC `t:A->bool` o MATCH_MP
    OPEN_IN_INTER_DERIVED_SET_OF_SUBSET) THEN
  REWRITE_TAC[CLOSURE_OF] THEN SET_TAC[]);;

let CLOSURE_OF_OPEN_IN_INTER_CLOSURE_OF = prove
 (`!top s t:A->bool.
        open_in top s
        ==> top closure_of (s INTER top closure_of t) =
            top closure_of (s INTER t)`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC SUBSET_ANTISYM THEN CONJ_TAC THENL
   [MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN
    REWRITE_TAC[CLOSED_IN_CLOSURE_OF] THEN
    ASM_SIMP_TAC[OPEN_IN_INTER_CLOSURE_OF_SUBSET];
    MATCH_MP_TAC CLOSURE_OF_MONO THEN
    MP_TAC(ISPECL [`top:A topology`; `topspace top INTER t:A->bool`]
        CLOSURE_OF_SUBSET) THEN
    REWRITE_TAC[INTER_SUBSET; GSYM CLOSURE_OF_RESTRICT] THEN
    FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
    SET_TAC[]]);;

let OPEN_IN_INTER_CLOSURE_OF_EQ = prove
 (`!top s t:A->bool.
        open_in top s
        ==> s INTER top closure_of t = s INTER top closure_of (s INTER t)`,
  SIMP_TAC[GSYM SUBSET_ANTISYM_EQ; INTER_SUBSET; SUBSET_INTER] THEN
  SIMP_TAC[OPEN_IN_INTER_CLOSURE_OF_SUBSET] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC(SET_RULE `s SUBSET t ==> u INTER s SUBSET t`) THEN
  MATCH_MP_TAC CLOSURE_OF_MONO THEN SET_TAC[]);;

let OPEN_IN_INTER_CLOSURE_OF_EQ_EMPTY = prove
 (`!top s t:A->bool.
        open_in top s ==> (s INTER top closure_of t = {} <=> s INTER t = {})`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(SUBST1_TAC o SPEC `t:A->bool` o
      MATCH_MP OPEN_IN_INTER_CLOSURE_OF_EQ) THEN
  EQ_TAC THEN SIMP_TAC[CLOSURE_OF_EMPTY; INTER_EMPTY] THEN
  MATCH_MP_TAC(SET_RULE
   `s INTER t SUBSET c ==> s INTER c = {} ==> s INTER t = {}`) THEN
  MATCH_MP_TAC CLOSURE_OF_SUBSET THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN SET_TAC[]);;

let CLOSURE_OF_OPEN_IN_INTER_SUPERSET = prove
 (`!top s t:A->bool.
        open_in top s /\ s SUBSET top closure_of t
        ==> top closure_of (s INTER t) = top closure_of s`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(SUBST1_TAC o SYM o SPEC `t:A->bool` o
    MATCH_MP CLOSURE_OF_OPEN_IN_INTER_CLOSURE_OF) THEN
  AP_TERM_TAC THEN ASM SET_TAC[]);;

let CLOSURE_OF_OPEN_IN_SUBTOPOLOGY_INTER_CLOSURE_OF = prove
 (`!top s t u:A->bool.
        open_in (subtopology top u) s /\ t SUBSET u
        ==> top closure_of (s INTER top closure_of t) =
            top closure_of (s INTER t)`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC SUBSET_ANTISYM THEN CONJ_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_SUBTOPOLOGY]) THEN
    DISCH_THEN(X_CHOOSE_THEN `v:A->bool`
     (CONJUNCTS_THEN2 ASSUME_TAC SUBST1_TAC)) THEN
    FIRST_ASSUM(MP_TAC o SPEC `t:A->bool` o
      MATCH_MP CLOSURE_OF_OPEN_IN_INTER_CLOSURE_OF) THEN
    ASM_SIMP_TAC[SET_RULE
     `t SUBSET u ==> (v INTER u) INTER t = v INTER t`] THEN
    DISCH_THEN(SUBST1_TAC o SYM) THEN
    MATCH_MP_TAC CLOSURE_OF_MONO THEN SET_TAC[];
    MATCH_MP_TAC CLOSURE_OF_MONO THEN
    MP_TAC(ISPECL [`top:A topology`; `topspace top INTER t:A->bool`]
        CLOSURE_OF_SUBSET) THEN
    REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT; INTER_SUBSET] THEN
    FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
    REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN SET_TAC[]]);;

let CLOSURE_OF_SUBTOPOLOGY_OPEN = prove
 (`!top u s:A->bool.
        open_in top u \/ s SUBSET u
        ==> (subtopology top u) closure_of s = u INTER top closure_of s`,
  REWRITE_TAC[SET_RULE `s SUBSET u <=> u INTER s = s`] THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[CLOSURE_OF_SUBTOPOLOGY] THEN
  ASM_MESON_TAC[OPEN_IN_INTER_CLOSURE_OF_EQ]);;

let DISCRETE_TOPOLOGY_CLOSURE_OF = prove
 (`!u s:A->bool. (discrete_topology u) closure_of s = u INTER s`,
  ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
  REWRITE_TAC[TOPSPACE_DISCRETE_TOPOLOGY; CLOSURE_OF_EQ] THEN
  REWRITE_TAC[CLOSED_IN_DISCRETE_TOPOLOGY; INTER_SUBSET]);;

(* ------------------------------------------------------------------------- *)
(* Interior with respect to a topological space.                             *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("interior_of",(21,"right"));;

let interior_of = new_definition
 `top interior_of s = {x | ?t. open_in top t /\ x IN t /\ t SUBSET s}`;;

let INTERIOR_OF_RESTRICT = prove
 (`!top s:A->bool.
        top interior_of s = top interior_of (topspace top INTER s)`,
  REWRITE_TAC[interior_of; EXTENSION; IN_ELIM_THM; SUBSET_INTER] THEN
  MESON_TAC[OPEN_IN_SUBSET]);;

let INTERIOR_OF_EQ = prove
 (`!top s:A->bool. (top interior_of s = s) <=> open_in top s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[EXTENSION; interior_of; IN_ELIM_THM] THEN
  GEN_REWRITE_TAC RAND_CONV [OPEN_IN_SUBOPEN] THEN MESON_TAC[SUBSET]);;

let INTERIOR_OF_OPEN_IN = prove
 (`!top s:a->bool. open_in top s ==> top interior_of s = s`,
  MESON_TAC[INTERIOR_OF_EQ]);;

let INTERIOR_OF_EMPTY = prove
 (`!top:A topology. top interior_of {} = {}`,
  REWRITE_TAC[INTERIOR_OF_EQ; OPEN_IN_EMPTY]);;

let INTERIOR_OF_TOPSPACE = prove
 (`!top:A topology. top interior_of (topspace top) = topspace top`,
  REWRITE_TAC[INTERIOR_OF_EQ; OPEN_IN_TOPSPACE]);;

let OPEN_IN_INTERIOR_OF = prove
 (`!top s:A->bool. open_in top (top interior_of s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[interior_of] THEN
  GEN_REWRITE_TAC I [OPEN_IN_SUBOPEN] THEN
  REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN MESON_TAC[]);;

let INTERIOR_OF_INTERIOR_OF = prove
 (`!top s:A->bool. top interior_of top interior_of s = top interior_of s`,
  REWRITE_TAC[INTERIOR_OF_EQ; OPEN_IN_INTERIOR_OF]);;

let INTERIOR_OF_SUBSET = prove
 (`!top s:A->bool. top interior_of s SUBSET s`,
  REWRITE_TAC[interior_of] THEN SET_TAC[]);;

let INTERIOR_OF_SUBSET_CLOSURE_OF = prove
 (`!top s:A->bool. top interior_of s SUBSET top closure_of s`,
  REPEAT GEN_TAC THEN
  ONCE_REWRITE_TAC[INTERIOR_OF_RESTRICT; CLOSURE_OF_RESTRICT] THEN
  TRANS_TAC SUBSET_TRANS `topspace top INTER s:A->bool` THEN
  SIMP_TAC[INTERIOR_OF_SUBSET; CLOSURE_OF_SUBSET; INTER_SUBSET]);;

let SUBSET_INTERIOR_OF_EQ = prove
 (`!top s:A->bool. s SUBSET top interior_of s <=> open_in top s`,
  SIMP_TAC[GSYM INTERIOR_OF_EQ; GSYM SUBSET_ANTISYM_EQ; INTERIOR_OF_SUBSET]);;

let INTERIOR_OF_MONO = prove
 (`!top s t:A->bool.
        s SUBSET t ==> top interior_of s SUBSET top interior_of t`,
   REWRITE_TAC[interior_of] THEN SET_TAC[]);;

let INTERIOR_OF_MAXIMAL = prove
 (`!top s t:A->bool.
        t SUBSET s /\ open_in top t ==> t SUBSET top interior_of s`,
  REWRITE_TAC[interior_of] THEN SET_TAC[]);;

let INTERIOR_OF_MAXIMAL_EQ = prove
 (`!top s t:A->bool.
        open_in top t ==> (t SUBSET top interior_of s <=> t SUBSET s)`,
  MESON_TAC[INTERIOR_OF_MAXIMAL; SUBSET_TRANS; INTERIOR_OF_SUBSET]);;

let INTERIOR_OF_UNIQUE = prove
 (`!top s t:A->bool.
        t SUBSET s /\ open_in top t /\
        (!t'. t' SUBSET s /\ open_in top t' ==> t' SUBSET t)
        ==> top interior_of s = t`,
  MESON_TAC[SUBSET_ANTISYM; INTERIOR_OF_MAXIMAL; INTERIOR_OF_SUBSET;
            OPEN_IN_INTERIOR_OF]);;

let INTERIOR_OF_SUBSET_TOPSPACE = prove
 (`!top s:A->bool. top interior_of s SUBSET topspace top`,
  REWRITE_TAC[SUBSET; interior_of; IN_ELIM_THM] THEN
  MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let INTERIOR_OF_SUBSET_SUBTOPOLOGY = prove
 (`!top s t:A->bool. (subtopology top s) interior_of t SUBSET s`,
  REPEAT STRIP_TAC THEN MP_TAC
   (ISPEC `subtopology top (s:A->bool)` INTERIOR_OF_SUBSET_TOPSPACE) THEN
  SIMP_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER]);;

let INTERIOR_OF_INTER = prove
 (`!top s t:A->bool.
      top interior_of (s INTER t) = top interior_of s INTER top interior_of t`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ; SUBSET_INTER] THEN
  SIMP_TAC[INTERIOR_OF_MONO; INTER_SUBSET] THEN
  SIMP_TAC[INTERIOR_OF_MAXIMAL_EQ; OPEN_IN_INTERIOR_OF; OPEN_IN_INTER] THEN
  MATCH_MP_TAC(SET_RULE
      `s SUBSET s' /\ t SUBSET t' ==> s INTER t SUBSET s' INTER t'`) THEN
  REWRITE_TAC[INTERIOR_OF_SUBSET]);;

let INTERIOR_OF_INTERS_SUBSET = prove
 (`!top f:(A->bool)->bool.
        top interior_of (INTERS f) SUBSET
        INTERS {top interior_of s | s IN f}`,
  REWRITE_TAC[SUBSET; interior_of; INTERS_GSPEC] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_INTERS] THEN MESON_TAC[]);;

let UNION_INTERIOR_OF_SUBSET = prove
 (`!top s t:A->bool.
        top interior_of s UNION top interior_of t
        SUBSET top interior_of (s UNION t)`,
  SIMP_TAC[UNION_SUBSET; INTERIOR_OF_MONO; SUBSET_UNION]);;

let INTERIOR_OF_EQ_EMPTY = prove
 (`!top s:A->bool.
                top interior_of s = {} <=>
                !t. open_in top t /\ t SUBSET s ==> t = {}`,
  MESON_TAC[INTERIOR_OF_MAXIMAL_EQ; SUBSET_EMPTY;
            OPEN_IN_INTERIOR_OF; INTERIOR_OF_SUBSET]);;

let INTERIOR_OF_EQ_EMPTY_ALT = prove
 (`!top s:A->bool.
        top interior_of s = {} <=>
        !t. open_in top t /\ ~(t = {}) ==> ~(t DIFF s = {})`,
  GEN_TAC THEN REWRITE_TAC[INTERIOR_OF_EQ_EMPTY] THEN SET_TAC[]);;

let INTERIOR_OF_UNIONS_OPEN_IN_SUBSETS = prove
 (`!top s:A->bool.
        UNIONS {t | open_in top t /\ t SUBSET s} = top interior_of s`,
  REPEAT GEN_TAC THEN CONV_TAC SYM_CONV THEN
  MATCH_MP_TAC INTERIOR_OF_UNIQUE THEN
  SIMP_TAC[OPEN_IN_UNIONS; IN_ELIM_THM] THEN SET_TAC[]);;

let INTERIOR_OF_COMPLEMENT = prove
 (`!top s:A->bool.
        top interior_of (topspace top DIFF s) =
        topspace top DIFF top closure_of s`,
  REWRITE_TAC[interior_of; closure_of] THEN
  REWRITE_TAC[EXTENSION; IN_DIFF; IN_ELIM_THM; SUBSET] THEN
  MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let INTERIOR_OF_CLOSURE_OF = prove
 (`!top s:A->bool.
        top interior_of s =
        topspace top DIFF top closure_of (topspace top DIFF s)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[GSYM INTERIOR_OF_COMPLEMENT] THEN
  GEN_REWRITE_TAC LAND_CONV [INTERIOR_OF_RESTRICT] THEN
  AP_TERM_TAC THEN SET_TAC[]);;

let CLOSURE_OF_INTERIOR_OF = prove
 (`!top s:A->bool.
        top closure_of s =
        topspace top DIFF top interior_of (topspace top DIFF s)`,
  REWRITE_TAC[INTERIOR_OF_COMPLEMENT] THEN
  REWRITE_TAC[SET_RULE `s = t DIFF (t DIFF s) <=> s SUBSET t`] THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE]);;

let CLOSURE_OF_COMPLEMENT = prove
 (`!top s:A->bool.
        top closure_of (topspace top DIFF s) =
        topspace top DIFF top interior_of s`,
  REWRITE_TAC[interior_of; closure_of] THEN
  REWRITE_TAC[EXTENSION; IN_DIFF; IN_ELIM_THM; SUBSET] THEN
  MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let INTERIOR_OF_EQ_EMPTY_COMPLEMENT = prove
 (`!top s:A->bool.
        top interior_of s = {} <=>
        top closure_of (topspace top DIFF s) = topspace top`,
  REPEAT GEN_TAC THEN MP_TAC(ISPECL
   [`top:A topology`; `s:A->bool`] INTERIOR_OF_SUBSET_TOPSPACE) THEN
  REWRITE_TAC[CLOSURE_OF_COMPLEMENT] THEN SET_TAC[]);;

let CLOSURE_OF_EQ_UNIV = prove
 (`!top s:A->bool.
     top closure_of s = topspace top <=>
     top interior_of (topspace top DIFF s) = {}`,
  REPEAT GEN_TAC THEN MP_TAC(ISPECL
   [`top:A topology`; `s:A->bool`] CLOSURE_OF_SUBSET_TOPSPACE) THEN
  REWRITE_TAC[INTERIOR_OF_COMPLEMENT] THEN SET_TAC[]);;

let INTERIOR_OF_SUBTOPOLOGY_SUBSET = prove
 (`!top s u:A->bool.
        u INTER top interior_of s SUBSET (subtopology top u) interior_of s`,
  REWRITE_TAC[SUBSET; IN_INTER; interior_of;
              OPEN_IN_SUBTOPOLOGY; IN_ELIM_THM] THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[LEFT_AND_EXISTS_THM] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  GEN_REWRITE_TAC RAND_CONV [SWAP_EXISTS_THM] THEN
  MATCH_MP_TAC MONO_EXISTS THEN
  REWRITE_TAC[TAUT `(p /\ q) /\ r <=> q /\ p /\ r`] THEN
  REWRITE_TAC[UNWIND_THM2] THEN ASM SET_TAC[]);;

let INTERIOR_OF_SUBTOPOLOGY_SUBSETS = prove
 (`!top s t u:A->bool.
        t SUBSET u
        ==> t INTER (subtopology top u) interior_of s SUBSET
            (subtopology top t) interior_of s`,
  REPEAT STRIP_TAC THEN FIRST_ASSUM(SUBST1_TAC o MATCH_MP (SET_RULE
   `t SUBSET u ==> t = u INTER t`)) THEN
  REWRITE_TAC[GSYM SUBTOPOLOGY_SUBTOPOLOGY] THEN
  FIRST_ASSUM(SUBST1_TAC o MATCH_MP (SET_RULE
   `t SUBSET u ==> u INTER t = t`)) THEN
  REWRITE_TAC[INTERIOR_OF_SUBTOPOLOGY_SUBSET]);;

let INTERIOR_OF_SUBTOPOLOGY_MONO = prove
 (`!top s t u:A->bool.
        s SUBSET t /\ t SUBSET u
        ==> (subtopology top u) interior_of s SUBSET
            (subtopology top t) interior_of s`,
  REPEAT GEN_TAC THEN
  DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
  MATCH_MP_TAC(SET_RULE
    `i SUBSET s /\ t INTER i SUBSET i'
     ==> s SUBSET t ==> i SUBSET i'`) THEN
  ASM_SIMP_TAC[INTERIOR_OF_SUBSET; INTERIOR_OF_SUBTOPOLOGY_SUBSETS]);;

let INTERIOR_OF_SUBTOPOLOGY_OPEN = prove
 (`!top u s:A->bool.
        open_in top u
        ==> (subtopology top u) interior_of s = u INTER top interior_of s`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[INTERIOR_OF_CLOSURE_OF] THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBTOPOLOGY_OPEN] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
  REWRITE_TAC[SET_RULE `s INTER t DIFF u = t INTER (s DIFF u)`] THEN
  ASM_SIMP_TAC[GSYM OPEN_IN_INTER_CLOSURE_OF_EQ] THEN SET_TAC[]);;

let DENSE_INTERSECTS_OPEN = prove
 (`!top s:A->bool.
        top closure_of s = topspace top <=>
        !t. open_in top t /\ ~(t = {}) ==> ~(s INTER t = {})`,
  REWRITE_TAC[CLOSURE_OF_INTERIOR_OF] THEN
  SIMP_TAC[INTERIOR_OF_SUBSET_TOPSPACE;
   SET_RULE `s SUBSET u ==> (u DIFF s = u <=> s = {})`] THEN
  REWRITE_TAC[INTERIOR_OF_EQ_EMPTY_ALT] THEN
  SIMP_TAC[OPEN_IN_SUBSET; SET_RULE
   `t SUBSET u ==> (~(t DIFF (u DIFF s) = {}) <=> ~(s INTER t = {}))`]);;

let INTERIOR_OF_CLOSED_IN_UNION_EMPTY_INTERIOR_OF = prove
 (`!top s t:A->bool.
        closed_in top s /\ top interior_of t = {}
        ==> top interior_of (s UNION t) = top interior_of s`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[INTERIOR_OF_CLOSURE_OF] THEN
  AP_TERM_TAC THEN
  REWRITE_TAC[SET_RULE `u DIFF (s UNION t) = (u DIFF s) INTER (u DIFF t)`] THEN
  W(MP_TAC o PART_MATCH (rand o rand) CLOSURE_OF_OPEN_IN_INTER_CLOSURE_OF o
    lhand o snd) THEN
  ASM_SIMP_TAC[CLOSURE_OF_COMPLEMENT; OPEN_IN_DIFF; OPEN_IN_TOPSPACE] THEN
  DISCH_THEN(SUBST1_TAC o SYM) THEN
  REWRITE_TAC[GSYM CLOSURE_OF_COMPLEMENT] THEN
  AP_TERM_TAC THEN SET_TAC[]);;

let INTERIOR_OF_UNION_EQ_EMPTY = prove
 (`!top s t:A->bool.
        closed_in top s \/ closed_in top t
        ==> (top interior_of (s UNION t) = {} <=>
             top interior_of s = {} /\ top interior_of t = {})`,
  GEN_TAC THEN MATCH_MP_TAC(MESON[]
   `(!x y. R x y ==> R y x) /\ (!x y. P x ==> R x y)
    ==> (!x y. P x \/ P y ==> R x y)`) THEN
  CONJ_TAC THENL [REWRITE_TAC[UNION_COMM] THEN SET_TAC[]; ALL_TAC] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC(TAUT
   `(p ==> r) /\ (r ==> (p <=> q)) ==> (p <=> q /\ r)`) THEN
  ASM_SIMP_TAC[INTERIOR_OF_CLOSED_IN_UNION_EMPTY_INTERIOR_OF] THEN
  MATCH_MP_TAC(SET_RULE `s SUBSET t ==> t = {} ==> s = {}`) THEN
  SIMP_TAC[INTERIOR_OF_MONO; SUBSET_UNION]);;

let DISCRETE_TOPOLOGY_INTERIOR_OF = prove
 (`!u s:A->bool. (discrete_topology u) interior_of s = u INTER s`,
  ONCE_REWRITE_TAC[INTERIOR_OF_RESTRICT] THEN
  REWRITE_TAC[TOPSPACE_DISCRETE_TOPOLOGY; INTERIOR_OF_EQ] THEN
  REWRITE_TAC[OPEN_IN_DISCRETE_TOPOLOGY; INTER_SUBSET]);;

(* ------------------------------------------------------------------------- *)
(* Frontier with respect to topological space.                               *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("frontier_of",(21,"right"));;

let frontier_of = new_definition
 `top frontier_of s =  top closure_of s DIFF top interior_of s`;;

let FRONTIER_OF_CLOSURES = prove
 (`!top s. top frontier_of s =
           top closure_of s INTER top closure_of (topspace top DIFF s)`,
  REPEAT GEN_TAC THEN CONV_TAC SYM_CONV THEN
  REWRITE_TAC[frontier_of; CLOSURE_OF_COMPLEMENT] THEN
  MATCH_MP_TAC(SET_RULE `s SUBSET u ==> s INTER (u DIFF t) = s DIFF t`) THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE]);;

let INTERIOR_OF_UNION_FRONTIER_OF = prove
 (`!top s:A->bool.
        top interior_of s UNION top frontier_of s = top closure_of s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[frontier_of] THEN
  MP_TAC(ISPECL [`top:A topology`; `s:A->bool`]
    INTERIOR_OF_SUBSET_CLOSURE_OF) THEN
  SET_TAC[]);;

let FRONTIER_OF_RESTRICT = prove
 (`!top s:A->bool. top frontier_of s = top frontier_of (topspace top INTER s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[FRONTIER_OF_CLOSURES] THEN
  BINOP_TAC THEN GEN_REWRITE_TAC LAND_CONV [CLOSURE_OF_RESTRICT] THEN
  AP_TERM_TAC THEN SET_TAC[]);;

let CLOSED_IN_FRONTIER_OF = prove
 (`!top s:A->bool. closed_in top (top frontier_of s)`,
  SIMP_TAC[FRONTIER_OF_CLOSURES; CLOSED_IN_INTER; CLOSED_IN_CLOSURE_OF]);;

let FRONTIER_OF_SUBSET_TOPSPACE = prove
 (`!top s:A->bool. top frontier_of s SUBSET topspace top`,
  SIMP_TAC[CLOSED_IN_SUBSET; CLOSED_IN_FRONTIER_OF]);;

let FRONTIER_OF_SUBSET_SUBTOPOLOGY = prove
 (`!top s t:A->bool. (subtopology top s) frontier_of t SUBSET s`,
  MESON_TAC[TOPSPACE_SUBTOPOLOGY; FRONTIER_OF_SUBSET_TOPSPACE; SUBSET_INTER]);;

let FRONTIER_OF_SUBTOPOLOGY_SUBSET = prove
 (`!top s u:A->bool.
        u INTER (subtopology top u) frontier_of s SUBSET (top frontier_of s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[frontier_of] THEN MATCH_MP_TAC(SET_RULE
   `s SUBSET s' /\ u INTER t' SUBSET t
    ==> u INTER (s DIFF t) SUBSET s' DIFF t'`) THEN
  REWRITE_TAC[CLOSURE_OF_SUBTOPOLOGY_SUBSET; INTERIOR_OF_SUBTOPOLOGY_SUBSET]);;

let FRONTIER_OF_SUBTOPOLOGY_MONO = prove
 (`!top s t u:A->bool.
        s SUBSET t /\ t SUBSET u
        ==> (subtopology top t) frontier_of s SUBSET
            (subtopology top u) frontier_of s`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[frontier_of] THEN MATCH_MP_TAC(SET_RULE
   `s SUBSET s' /\ t' SUBSET t ==> s DIFF t SUBSET s' DIFF t'`) THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBTOPOLOGY_MONO; INTERIOR_OF_SUBTOPOLOGY_MONO]);;

let CLOPEN_IN_EQ_FRONTIER_OF = prove
 (`!top s:A->bool.
        closed_in top s /\ open_in top s <=>
        s SUBSET topspace top /\ top frontier_of s = {}`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[FRONTIER_OF_CLOSURES; OPEN_IN_CLOSED_IN_EQ] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THEN ASM_REWRITE_TAC[] THEN
  EQ_TAC THENL [SIMP_TAC[CLOSURE_OF_CLOSED_IN] THEN SET_TAC[]; DISCH_TAC] THEN
  ASM_REWRITE_TAC[GSYM CLOSURE_OF_SUBSET_EQ; SUBSET_DIFF] THEN
  MATCH_MP_TAC(SET_RULE
   `c INTER c' = {} /\
    s SUBSET c /\ (u DIFF s) SUBSET c' /\ c SUBSET u /\ c' SUBSET u
        ==> c SUBSET s /\ c' SUBSET (u DIFF s)`) THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBSET; SUBSET_DIFF; CLOSURE_OF_SUBSET_TOPSPACE]);;

let FRONTIER_OF_EQ_EMPTY = prove
 (`!top s:A->bool.
        s SUBSET topspace top
        ==> (top frontier_of s = {} <=> closed_in top s /\ open_in top s)`,
  SIMP_TAC[CLOPEN_IN_EQ_FRONTIER_OF]);;

let FRONTIER_OF_OPEN_IN = prove
 (`!top s:A->bool.
        open_in top s ==> top frontier_of s = top closure_of s DIFF s`,
  SIMP_TAC[frontier_of; INTERIOR_OF_OPEN_IN]);;

let FRONTIER_OF_OPEN_IN_STRADDLE_INTER = prove
 (`!top s u:A->bool.
        open_in top  u /\ ~(u INTER top frontier_of s = {})
        ==> ~(u INTER s = {}) /\ ~(u DIFF s = {})`,
  REPEAT GEN_TAC THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  REWRITE_TAC[FRONTIER_OF_CLOSURES] THEN DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
   `~(s INTER t INTER u = {})
    ==> ~(s INTER t = {}) /\ ~(s INTER u = {})`)) THEN
  MATCH_MP_TAC MONO_AND THEN CONJ_TAC THEN
  W(MP_TAC o PART_MATCH (lhand o rand) OPEN_IN_INTER_CLOSURE_OF_EQ_EMPTY o
     rand o lhand o snd) THEN
  ASM SET_TAC[]);;

let FRONTIER_OF_SUBSET_CLOSED_IN = prove
 (`!top s:A->bool. closed_in top s ==> (top frontier_of s) SUBSET s`,
  REWRITE_TAC[GSYM CLOSURE_OF_SUBSET_EQ; frontier_of] THEN SET_TAC[]);;

let FRONTIER_OF_EMPTY = prove
 (`!top. top frontier_of {} = {}`,
  REWRITE_TAC[FRONTIER_OF_CLOSURES; CLOSURE_OF_EMPTY; INTER_EMPTY]);;

let FRONTIER_OF_TOPSPACE = prove
 (`!top:A topology. top frontier_of topspace top = {}`,
  SIMP_TAC[FRONTIER_OF_EQ_EMPTY; SUBSET_REFL] THEN
  REWRITE_TAC[OPEN_IN_TOPSPACE; CLOSED_IN_TOPSPACE]);;

let FRONTIER_OF_SUBSET_EQ = prove
 (`!top s:A->bool.
        s SUBSET topspace top
        ==> ((top frontier_of s) SUBSET s <=> closed_in top s)`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN SIMP_TAC[FRONTIER_OF_SUBSET_CLOSED_IN] THEN
  REWRITE_TAC[FRONTIER_OF_CLOSURES] THEN
  ASM_REWRITE_TAC[GSYM CLOSURE_OF_SUBSET_EQ] THEN
  ONCE_REWRITE_TAC[SET_RULE `s INTER t = s DIFF (s DIFF t)`]  THEN
  DISCH_THEN(MATCH_MP_TAC o MATCH_MP (SET_RULE
   `s DIFF t SUBSET u ==> t SUBSET u ==> s SUBSET u`)) THEN
  MATCH_MP_TAC(SET_RULE
   `!u. u DIFF s SUBSET d /\ c SUBSET u ==> c DIFF d SUBSET s`) THEN
  EXISTS_TAC `topspace top:A->bool` THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE] THEN
  MATCH_MP_TAC CLOSURE_OF_SUBSET THEN SET_TAC[]);;

let FRONTIER_OF_COMPLEMENT = prove
 (`!top s:A->bool. top frontier_of (topspace top DIFF s) = top frontier_of s`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[FRONTIER_OF_RESTRICT] THEN
  REWRITE_TAC[FRONTIER_OF_CLOSURES] THEN
  GEN_REWRITE_TAC RAND_CONV [INTER_COMM] THEN
  BINOP_TAC THEN AP_TERM_TAC THEN SET_TAC[]);;

let FRONTIER_OF_DISJOINT_EQ = prove
 (`!top s. s SUBSET topspace top
        ==> ((top frontier_of s) INTER s = {} <=> open_in top s)`,
  REPEAT STRIP_TAC THEN
  ASM_SIMP_TAC[OPEN_IN_CLOSED_IN] THEN
  ASM_SIMP_TAC[GSYM FRONTIER_OF_SUBSET_EQ; SUBSET_DIFF] THEN
  REWRITE_TAC[FRONTIER_OF_COMPLEMENT] THEN
  MATCH_MP_TAC(SET_RULE
   `f SUBSET u ==> (f INTER s = {} <=> f SUBSET u DIFF s)`) THEN
  REWRITE_TAC[FRONTIER_OF_SUBSET_TOPSPACE]);;

let FRONTIER_OF_DISJOINT_EQ_ALT = prove
 (`!top s:A->bool.
        s SUBSET (topspace top DIFF top frontier_of s) <=>
        open_in top s`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THENL
   [ASM_SIMP_TAC[GSYM FRONTIER_OF_DISJOINT_EQ] THEN ASM SET_TAC[];
    EQ_TAC THENL [ASM SET_TAC[]; ASM_MESON_TAC[OPEN_IN_SUBSET]]]);;

let FRONTIER_OF_INTER = prove
 (`!top s t:A->bool.
        top frontier_of(s INTER t) =
        top closure_of (s INTER t) INTER
        (top frontier_of s UNION top frontier_of t)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[FRONTIER_OF_CLOSURES] THEN
  SIMP_TAC[CLOSURE_OF_MONO; INTER_SUBSET; GSYM CLOSURE_OF_UNION; SET_RULE
    `u SUBSET s /\ u SUBSET t
     ==> u INTER (s INTER x UNION t INTER y) = u INTER (x UNION y)`] THEN
  REPLICATE_TAC 2 AP_TERM_TAC THEN SET_TAC[]);;

let FRONTIER_OF_INTER_SUBSET = prove
 (`!top s t. top frontier_of(s INTER t) SUBSET
             top frontier_of(s) UNION top frontier_of(t)`,
  REWRITE_TAC[FRONTIER_OF_INTER] THEN SET_TAC[]);;

let FRONTIER_OF_INTER_CLOSED_IN = prove
 (`!top s t:A->bool.
        closed_in top s /\ closed_in top t
        ==> top frontier_of(s INTER t) =
            top frontier_of s INTER t UNION s INTER top frontier_of t`,
  SIMP_TAC[FRONTIER_OF_INTER; CLOSED_IN_INTER; CLOSURE_OF_CLOSED_IN] THEN
  REPEAT STRIP_TAC THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP FRONTIER_OF_SUBSET_CLOSED_IN)) THEN
  SET_TAC[]);;

let FRONTIER_OF_UNION_SUBSET = prove
 (`!top s t:A->bool.
      top frontier_of(s UNION t) SUBSET
      top frontier_of s UNION top frontier_of t`,
  ONCE_REWRITE_TAC[GSYM FRONTIER_OF_COMPLEMENT] THEN
  REWRITE_TAC[SET_RULE `u DIFF (s UNION t) = (u DIFF s) INTER (u DIFF t)`] THEN
  REWRITE_TAC[FRONTIER_OF_INTER_SUBSET]);;

let FRONTIER_OF_UNIONS_SUBSET = prove
 (`!top f:(A->bool)->bool.
        FINITE f
        ==> top frontier_of (UNIONS f) SUBSET
            UNIONS {top frontier_of t | t IN f}`,
  GEN_TAC THEN MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[SIMPLE_IMAGE; IMAGE_UNIONS; IMAGE_CLAUSES; UNIONS_0;
           UNIONS_INSERT; FRONTIER_OF_EMPTY; SUBSET_REFL] THEN
  REPEAT STRIP_TAC THEN
  W(MP_TAC o PART_MATCH lhand FRONTIER_OF_UNION_SUBSET o lhand o snd) THEN
  ASM SET_TAC[]);;

let FRONTIER_OF_FRONTIER_OF_SUBSET = prove
 (`!top s:A->bool.
    top frontier_of (top frontier_of s) SUBSET top frontier_of s`,
  REPEAT GEN_TAC THEN MATCH_MP_TAC FRONTIER_OF_SUBSET_CLOSED_IN THEN
  REWRITE_TAC[CLOSED_IN_FRONTIER_OF]);;

let FRONTIER_OF_SUBTOPOLOGY_OPEN = prove
 (`!top u s:A->bool.
        open_in top u
        ==> (subtopology top u) frontier_of s = u INTER top frontier_of s`,
  SIMP_TAC[frontier_of; CLOSURE_OF_SUBTOPOLOGY_OPEN;
           INTERIOR_OF_SUBTOPOLOGY_OPEN] THEN
  SET_TAC[]);;

let DISCRETE_TOPOLOGY_FRONTIER_OF = prove
 (`!u s:A->bool. (discrete_topology u) frontier_of s = {}`,
  REWRITE_TAC[frontier_of; DISCRETE_TOPOLOGY_CLOSURE_OF;
              DISCRETE_TOPOLOGY_INTERIOR_OF; DIFF_EQ_EMPTY]);;

(* ------------------------------------------------------------------------- *)
(* Iteration of interior and closure.                                        *)
(* ------------------------------------------------------------------------- *)

let INTERIOR_OF_CLOSURE_OF_IDEMP = prove
 (`!top s:A->bool.
        top interior_of top closure_of top interior_of top closure_of s =
        top interior_of top closure_of s`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC INTERIOR_OF_UNIQUE THEN
  REWRITE_TAC[OPEN_IN_INTERIOR_OF] THEN
  SIMP_TAC[CLOSURE_OF_SUBSET; INTERIOR_OF_SUBSET_TOPSPACE] THEN
  SIMP_TAC[INTERIOR_OF_MAXIMAL_EQ] THEN
  X_GEN_TAC `t:A->bool` THEN DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] SUBSET_TRANS) THEN
  MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN
  REWRITE_TAC[CLOSED_IN_CLOSURE_OF; INTERIOR_OF_SUBSET]);;

let CLOSURE_OF_INTERIOR_OF_IDEMP = prove
 (`!top s:A->bool.
        top closure_of top interior_of top closure_of top interior_of s =
        top closure_of top interior_of s`,
  REPEAT GEN_TAC THEN
  MP_TAC(ISPECL [`top:A topology`; `topspace top DIFF s:A->bool`]
        INTERIOR_OF_CLOSURE_OF_IDEMP) THEN
  REWRITE_TAC[CLOSURE_OF_COMPLEMENT; INTERIOR_OF_COMPLEMENT] THEN
  MATCH_MP_TAC(SET_RULE
   `s SUBSET u /\ t SUBSET u ==> u DIFF s = u DIFF t ==> s = t`) THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE; INTERIOR_OF_SUBSET_TOPSPACE]);;

let INTERIOR_OF_FRONTIER_OF = prove
 (`!top s:A->bool.
        top interior_of (top frontier_of s) =
        top interior_of (top closure_of s) DIFF
        top closure_of (top interior_of s)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[FRONTIER_OF_CLOSURES; INTERIOR_OF_INTER] THEN
  REWRITE_TAC[CLOSURE_OF_COMPLEMENT; INTERIOR_OF_COMPLEMENT] THEN
  MP_TAC(ISPECL [`top:A topology`; `top closure_of s:A->bool`]
        INTERIOR_OF_SUBSET_TOPSPACE) THEN
  SET_TAC[]);;

let THIN_FRONTIER_OF_SUBSET = prove
 (`!top s:A->bool.
        top interior_of (top frontier_of s) = {} <=>
        top interior_of (top closure_of s) SUBSET
        top closure_of (top interior_of s)`,
  REWRITE_TAC[INTERIOR_OF_FRONTIER_OF] THEN SET_TAC[]);;

let THIN_FRONTIER_OF_CIC = prove
 (`!top s:A->bool.
        top interior_of (top frontier_of s) = {} <=>
        top closure_of (top interior_of (top closure_of s)) =
        top closure_of (top interior_of s)`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM SUBSET_ANTISYM_EQ] THEN
  REWRITE_TAC[THIN_FRONTIER_OF_SUBSET] THEN
  MATCH_MP_TAC(TAUT `(p <=> q) /\ r==> (p <=> q /\ r)`) THEN CONJ_TAC THENL
   [SIMP_TAC[CLOSURE_OF_MINIMAL_EQ; CLOSED_IN_CLOSURE_OF;
             INTERIOR_OF_SUBSET_TOPSPACE];
    GEN_REWRITE_TAC LAND_CONV [GSYM CLOSURE_OF_INTERIOR_OF_IDEMP] THEN
    SIMP_TAC[CLOSURE_OF_MONO; INTERIOR_OF_MONO; INTERIOR_OF_SUBSET]]);;

let THIN_FRONTIER_OF_ICI = prove
 (`!s:A->bool.
        top interior_of (top frontier_of s) = {} <=>
        top interior_of (top closure_of (top interior_of s)) =
        top interior_of (top closure_of  s)`,
  GEN_TAC THEN REWRITE_TAC[THIN_FRONTIER_OF_CIC] THEN
  MESON_TAC[INTERIOR_OF_CLOSURE_OF_IDEMP; CLOSURE_OF_INTERIOR_OF_IDEMP]);;

let INTERIOR_OF_FRONTIER_OF_EMPTY = prove
 (`!top s:A->bool.
        open_in top s \/ closed_in top s
        ==> top interior_of (top frontier_of s) = {}`,
  REPEAT STRIP_TAC THENL
   [REWRITE_TAC[THIN_FRONTIER_OF_ICI]; REWRITE_TAC[THIN_FRONTIER_OF_CIC]] THEN
  ASM_SIMP_TAC[INTERIOR_OF_OPEN_IN; CLOSURE_OF_CLOSED_IN]);;

let FRONTIER_OF_FRONTIER_OF = prove
 (`!top s:A->bool.
        open_in top s \/ closed_in top s
        ==> top frontier_of (top frontier_of s) = top frontier_of s`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (RAND_CONV o LAND_CONV) [frontier_of] THEN
  SIMP_TAC[INTERIOR_OF_FRONTIER_OF_EMPTY; CLOSURE_OF_CLOSED_IN;
          CLOSED_IN_FRONTIER_OF; DIFF_EMPTY]);;

let FRONTIER_OF_FRONTIER_OF_FRONTIER_OF = prove
 (`!top s:A->bool.
        top frontier_of top frontier_of top frontier_of s =
        top frontier_of top frontier_of s`,
  SIMP_TAC[FRONTIER_OF_FRONTIER_OF; CLOSED_IN_FRONTIER_OF]);;

let REGULAR_CLOSURE_OF_INTERIOR_OF = prove
 (`!top s:A->bool.
        s SUBSET top closure_of top interior_of s <=>
        s SUBSET topspace top /\
        top closure_of top interior_of s = top closure_of s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ] THEN
  SIMP_TAC[CLOSURE_OF_MONO; INTERIOR_OF_SUBSET] THEN
  MESON_TAC[CLOSURE_OF_MINIMAL_EQ; CLOSED_IN_CLOSURE_OF;
            CLOSURE_OF_SUBSET_TOPSPACE; SUBSET_TRANS]);;

let REGULAR_INTERIOR_OF_CLOSURE_OF = prove
 (`!top s:A->bool.
        top interior_of top closure_of s SUBSET s <=>
        top interior_of top closure_of s = top interior_of s`,
  REPEAT GEN_TAC THEN
  SUBST1_TAC(ISPECL [`top:A topology`; `s:A->bool`] CLOSURE_OF_RESTRICT) THEN
  SUBST1_TAC(ISPECL [`top:A topology`; `s:A->bool`] INTERIOR_OF_RESTRICT) THEN
  REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ] THEN
  SIMP_TAC[INTERIOR_OF_MONO; CLOSURE_OF_SUBSET; INTER_SUBSET] THEN
  SIMP_TAC[INTERIOR_OF_MAXIMAL_EQ; OPEN_IN_INTERIOR_OF] THEN
  REWRITE_TAC[SUBSET_INTER; INTERIOR_OF_SUBSET_TOPSPACE]);;

let REGULAR_CLOSED_IN = prove
 (`!top s:A->bool.
        top closure_of top interior_of s = s <=>
        closed_in top s /\ s SUBSET top closure_of top interior_of s`,
  REWRITE_TAC[REGULAR_CLOSURE_OF_INTERIOR_OF; GSYM CLOSURE_OF_EQ] THEN
  MESON_TAC[CLOSURE_OF_SUBSET_TOPSPACE; CLOSURE_OF_CLOSURE_OF]);;

let REGULAR_OPEN_IN = prove
 (`!top s:A->bool.
        top interior_of top closure_of s = s <=>
        open_in top s /\ top interior_of top closure_of s SUBSET s`,
  REWRITE_TAC[REGULAR_INTERIOR_OF_CLOSURE_OF; GSYM INTERIOR_OF_EQ] THEN
  MESON_TAC[INTERIOR_OF_INTERIOR_OF]);;

let REGULAR_CLOSURE_OF_IMP_THIN_FRONTIER_OF = prove
 (`!top s:A->bool.
        s SUBSET top closure_of top interior_of s
        ==> top interior_of top frontier_of s = {}`,
  SIMP_TAC[REGULAR_CLOSURE_OF_INTERIOR_OF; THIN_FRONTIER_OF_ICI]);;

let REGULAR_INTERIOR_OF_IMP_THIN_FRONTIER_OF = prove
 (`!top s:A->bool.
        top interior_of top closure_of s SUBSET s
        ==> top interior_of top frontier_of s = {}`,
  SIMP_TAC[REGULAR_INTERIOR_OF_CLOSURE_OF; THIN_FRONTIER_OF_CIC]);;

(* ------------------------------------------------------------------------- *)
(* Continuous maps.                                                          *)
(* ------------------------------------------------------------------------- *)

let continuous_map = new_definition
  `!top top' f:A->B.
     continuous_map (top,top')  f <=>
     (!x. x IN topspace top ==> f x IN topspace top') /\
     (!u. open_in top' u
          ==> open_in top {x | x IN topspace top /\ f x IN u})`;;

let CONTINUOUS_MAP = prove
 (`!top top' f.
        continuous_map (top,top') f <=>
        IMAGE f (topspace top) SUBSET topspace top' /\
        !u. open_in top' u
            ==> open_in top {x | x IN topspace top /\ f x IN u}`,
  REWRITE_TAC[continuous_map; SUBSET; FORALL_IN_IMAGE]);;

let CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE = prove
 (`!top top' f:A->B. continuous_map (top,top')  f
                     ==> IMAGE f (topspace top) SUBSET topspace top'`,
  REWRITE_TAC[continuous_map] THEN SET_TAC[]);;

let CONTINUOUS_MAP_ON_EMPTY = prove
 (`!top top' (f:A->B). topspace top = {} ==> continuous_map(top,top') f`,
  SIMP_TAC[continuous_map; NOT_IN_EMPTY; EMPTY_GSPEC; OPEN_IN_EMPTY]);;

let CONTINUOUS_MAP_CLOSED_IN = prove
 (`!top top' f:A->B.
         continuous_map (top,top') f <=>
         (!x. x IN topspace top ==> f x IN topspace top') /\
         (!c. closed_in top' c
              ==> closed_in top {x | x IN topspace top /\ f x IN c})`,
  REPEAT GEN_TAC THEN REWRITE_TAC[continuous_map] THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
  DISCH_TAC THEN EQ_TAC THEN DISCH_TAC THEN
  X_GEN_TAC `t:B->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `topspace top' DIFF t:B->bool`) THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; CLOSED_IN_DIFF; OPEN_IN_TOPSPACE;
               CLOSED_IN_TOPSPACE] THEN
  GEN_REWRITE_TAC LAND_CONV [closed_in; OPEN_IN_CLOSED_IN_EQ] THEN
  REWRITE_TAC[SUBSET_RESTRICT] THEN MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
  ASM SET_TAC[]);;

let OPEN_IN_CONTINUOUS_MAP_PREIMAGE = prove
 (`!f:A->B top top' u.
        continuous_map (top,top') f /\ open_in top' u
        ==> open_in top {x | x IN topspace top /\ f x IN u}`,
  REWRITE_TAC[continuous_map] THEN SET_TAC[]);;

let CLOSED_IN_CONTINUOUS_MAP_PREIMAGE = prove
 (`!f:A->B top top' c.
        continuous_map (top,top') f /\ closed_in top' c
        ==> closed_in top {x | x IN topspace top /\ f x IN c}`,
  REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN] THEN SET_TAC[]);;

let OPEN_IN_CONTINUOUS_MAP_PREIMAGE_GEN = prove
 (`!f:A->B top top' u v.
        continuous_map (top,top') f /\ open_in top u /\ open_in top' v
        ==> open_in top {x | x IN u /\ f x IN v}`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `{x | x IN u /\ (f:A->B) x IN v} =
                u INTER {x | x IN topspace top /\ f x IN v}`
  SUBST1_TAC THENL
   [REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN SET_TAC[];
    MATCH_MP_TAC OPEN_IN_INTER THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
    ASM_MESON_TAC[]]);;

let CLOSED_IN_CONTINUOUS_MAP_PREIMAGE_GEN = prove
 (`!f:A->B top top' u v.
        continuous_map (top,top') f /\ closed_in top u /\ closed_in top' v
        ==> closed_in top {x | x IN u /\ f x IN v}`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `{x | x IN u /\ (f:A->B) x IN v} =
                u INTER {x | x IN topspace top /\ f x IN v}`
  SUBST1_TAC THENL
   [REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN SET_TAC[];
    MATCH_MP_TAC CLOSED_IN_INTER THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE THEN
    ASM_MESON_TAC[]]);;

let CONTINUOUS_MAP_IMAGE_CLOSURE_SUBSET = prove
 (`!top top' (f:A->B) s.
        continuous_map (top,top') f
        ==> IMAGE f (top closure_of s) SUBSET top' closure_of IMAGE f s`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE) THEN
  ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
  TRANS_TAC SUBSET_TRANS
   `top' closure_of (IMAGE (f:A->B) (topspace top INTER s))` THEN
  CONJ_TAC THENL
   [ALL_TAC; MATCH_MP_TAC CLOSURE_OF_MONO THEN ASM SET_TAC[]] THEN
  MP_TAC(SET_RULE `(topspace top INTER s:A->bool) SUBSET topspace top`) THEN
  SPEC_TAC(`topspace top INTER s:A->bool`,`s:A->bool`) THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[SET_RULE
   `IMAGE f s SUBSET t <=> s SUBSET {x | x IN s /\ f x IN t}`] THEN
  MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN CONJ_TAC THENL
   [MATCH_MP_TAC(SET_RULE
     `s SUBSET s' /\ IMAGE f s SUBSET t'
      ==> s SUBSET {x | x IN s' /\ f x IN t'}`) THEN
    CONJ_TAC THEN MATCH_MP_TAC CLOSURE_OF_SUBSET THEN ASM SET_TAC[];
    MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE_GEN THEN
    EXISTS_TAC `top':B topology` THEN
    ASM_REWRITE_TAC[CLOSED_IN_CLOSURE_OF]]);;

let [CONTINUOUS_MAP_EQ_IMAGE_CLOSURE_SUBSET;
     CONTINUOUS_MAP_EQ_IMAGE_CLOSURE_SUBSET_ALT;
     CONTINUOUS_MAP_EQ_IMAGE_CLOSURE_SUBSET_GEN] = (CONJUNCTS o prove)
 (`(!top top' f:A->B.
        continuous_map (top,top') f <=>
        !s. IMAGE f (top closure_of s) SUBSET top' closure_of IMAGE f s) /\
   (!top top' f:A->B.
        continuous_map (top,top') f <=>
        !s. s SUBSET topspace top
            ==> IMAGE f (top closure_of s) SUBSET top' closure_of IMAGE f s) /\
   (!top top' f:A->B.
        continuous_map (top,top') f <=>
        IMAGE f (topspace top) SUBSET topspace top' /\
        !s. IMAGE f (top closure_of s) SUBSET top' closure_of IMAGE f s)`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN MATCH_MP_TAC(TAUT
   `(p ==> q) /\ (q ==> q') /\ (p ==> r) /\ (q' ==> p)
    ==> (p <=> q) /\ (p <=> q') /\ (p <=> r /\ q)`) THEN
  SIMP_TAC[CONTINUOUS_MAP_IMAGE_CLOSURE_SUBSET] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE] THEN
  DISCH_TAC THEN REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN] THEN CONJ_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o SPEC `topspace top:A->bool`) THEN
    REWRITE_TAC[SUBSET_REFL; CLOSURE_OF_TOPSPACE] THEN
    MATCH_MP_TAC(SET_RULE
     `v' SUBSET v ==> IMAGE f u SUBSET v' ==> !x. x IN u ==> f x IN v`) THEN
    REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE];
    X_GEN_TAC `c:B->bool` THEN DISCH_TAC THEN
    REWRITE_TAC[GSYM CLOSURE_OF_SUBSET_EQ; SUBSET_RESTRICT] THEN
    REWRITE_TAC[SET_RULE
     `s SUBSET {x | x IN t /\ f x IN u} <=>
      s SUBSET t /\ IMAGE f s SUBSET u`] THEN
    REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE] THEN
    FIRST_ASSUM(fun th ->
       W(MP_TAC o PART_MATCH (lhand o rand) th o lhand o snd)) THEN
    REWRITE_TAC[SUBSET_RESTRICT] THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] SUBSET_TRANS) THEN
    MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN ASM SET_TAC[]]);;

let CONTINUOUS_MAP_CLOSURE_PREIMAGE_SUBSET = prove
 (`!top top' (f:A->B) t.
        continuous_map (top,top') f
        ==> top closure_of {x | x IN topspace top /\ f x IN t}
            SUBSET {x | x IN topspace top /\ f x IN top' closure_of t}`,
  REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN ASM_SIMP_TAC[CLOSED_IN_CLOSURE_OF] THEN
  MP_TAC(ISPECL [`top':B topology`; `topspace top' INTER t:B->bool`]
    CLOSURE_OF_SUBSET) THEN
  REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT] THEN ASM SET_TAC[]);;

let CONTINUOUS_MAP_EQ_CLOSURE_PREIMAGE_SUBSET,
    CONTINUOUS_MAP_EQ_CLOSURE_PREIMAGE_SUBSET_ALT = (CONJ_PAIR o prove)
 (`(!top top' f:A->B.
        continuous_map (top,top') f <=>
        IMAGE f (topspace top) SUBSET topspace top' /\
        !t. top closure_of {x | x IN topspace top /\ f x IN t}
            SUBSET {x | x IN topspace top /\ f x IN top' closure_of t}) /\
   (!top top' f:A->B.
        continuous_map (top,top') f <=>
        IMAGE f (topspace top) SUBSET topspace top' /\
        !t. t SUBSET topspace top'
            ==> top closure_of {x | x IN topspace top /\ f x IN t}
                SUBSET {x | x IN topspace top /\ f x IN top' closure_of t})`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  SIMP_TAC[CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE;
           CONTINUOUS_MAP_CLOSURE_PREIMAGE_SUBSET] THEN
  STRIP_TAC THEN REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN] THEN
  (CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC]) THEN
  X_GEN_TAC `t:B->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `t:B->bool`) THEN
  ASM_SIMP_TAC[CLOSURE_OF_CLOSED_IN; CLOSED_IN_SUBSET] THEN
  SIMP_TAC[GSYM CLOSURE_OF_SUBSET_EQ; SUBSET_RESTRICT]);;

let CONTINUOUS_MAP_FRONTIER_FRONTIER_PREIMAGE_SUBSET = prove
 (`!top top' (f:A->B) t.
        continuous_map (top,top') f
        ==> top frontier_of {x | x IN topspace top /\ f x IN t}
            SUBSET {x | x IN topspace top /\ f x IN top' frontier_of t}`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[FRONTIER_OF_CLOSURES] THEN
  MATCH_MP_TAC(SET_RULE
   `s SUBSET {x | x IN t /\ f x IN u} /\ s' SUBSET {x | x IN t /\ f x IN u'}
    ==> s INTER s' SUBSET {x | x IN t /\ f x IN u INTER u'}`) THEN
  SUBGOAL_THEN
   `topspace top DIFF {x | x IN topspace top /\ (f:A->B) x IN t} =
    {x | x IN topspace top /\ f x IN topspace top' DIFF t}`
   (fun th -> ASM_SIMP_TAC[th; CONTINUOUS_MAP_CLOSURE_PREIMAGE_SUBSET]) THEN
  RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[]);;

let CONTINUOUS_MAP_ID = prove
 (`!top:A topology. continuous_map (top,top) (\x. x)`,
  REWRITE_TAC[continuous_map] THEN REPEAT GEN_TAC THEN
  MATCH_MP_TAC(MESON[] `(P x ==> x = y) ==> P x ==> P y`) THEN
  REWRITE_TAC[SET_RULE `u = {x | x IN s /\ x IN u} <=> u SUBSET s`] THEN
  REWRITE_TAC[OPEN_IN_SUBSET]);;

let TOPOLOGY_FINER_CONTINUOUS_ID = prove
 (`!top top':A topology.
        topspace top' = topspace top
        ==> ((!s. open_in top s ==> open_in top' s) <=>
             continuous_map (top',top) (\x. x))`,
  REWRITE_TAC[continuous_map] THEN SIMP_TAC[OPEN_IN_SUBSET; SET_RULE
   `u SUBSET s ==> {x | x IN s /\ x IN u} = u`]);;

let CONTINUOUS_MAP_CONST = prove
 (`!top1:A topology top2:B topology c.
       continuous_map (top1,top2) (\x. c) <=>
       topspace top1 = {} \/ c IN topspace top2`,
  REPEAT GEN_TAC THEN REWRITE_TAC[continuous_map] THEN
  ASM_CASES_TAC `topspace top1:A->bool = {}` THEN
  ASM_REWRITE_TAC[NOT_IN_EMPTY; EMPTY_GSPEC; OPEN_IN_EMPTY] THEN
  ASM_CASES_TAC `(c:B) IN topspace top2` THEN ASM_REWRITE_TAC[] THENL
   [ALL_TAC; ASM SET_TAC[]] THEN
  X_GEN_TAC `u:B->bool` THEN
  ASM_CASES_TAC `(c:B) IN u` THEN
  ASM_REWRITE_TAC[EMPTY_GSPEC; OPEN_IN_EMPTY] THEN
  REWRITE_TAC[SET_RULE `{x | x IN s} = s`; OPEN_IN_TOPSPACE]);;

let CONTINUOUS_MAP_COMPOSE = prove
 (`!top top' top'' f:A->B g:B->C.
        continuous_map (top,top') f /\ continuous_map (top',top'') g
        ==> continuous_map (top,top'') (g o f)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[continuous_map; o_THM] THEN STRIP_TAC THEN
  CONJ_TAC THENL [ASM SET_TAC[]; X_GEN_TAC `u:C->bool`] THEN
  SUBGOAL_THEN
   `{x:A | x IN topspace top /\ (g:B->C) (f x) IN u} =
    {x:A | x IN  topspace top /\ f x IN {y | y IN topspace top' /\ g y IN u}}`
  SUBST1_TAC THENL [ASM SET_TAC[]; ASM SIMP_TAC[]]);;

let CONTINUOUS_MAP_EQ = prove
 (`!top top' f g:A->B.
        (!x. x IN topspace top ==> f x = g x) /\ continuous_map (top,top') f
        ==> continuous_map (top,top') g`,
  REPEAT GEN_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  REWRITE_TAC[continuous_map] THEN
  MATCH_MP_TAC MONO_AND THEN CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  MATCH_MP_TAC MONO_FORALL THEN GEN_TAC THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN AP_TERM_TAC THEN
  ASM SET_TAC[]);;

let RESTRICTION_CONTINUOUS_MAP = prove
 (`!top top' f:A->B s.
        topspace top SUBSET s
        ==> (continuous_map (top,top') (RESTRICTION s f) <=>
             continuous_map (top,top') f)`,
  REPEAT GEN_TAC THEN DISCH_TAC THEN EQ_TAC THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] CONTINUOUS_MAP_EQ) THEN
  REWRITE_TAC[RESTRICTION] THEN ASM SET_TAC[]);;

let CONTINUOUS_MAP_IN_SUBTOPOLOGY = prove
 (`!top top' s f:A->B.
     continuous_map (top,subtopology top' s) f <=>
     continuous_map (top,top')  f /\ IMAGE f (topspace top) SUBSET s`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[continuous_map; TOPSPACE_SUBTOPOLOGY; IN_INTER;
    OPEN_IN_SUBTOPOLOGY] THEN
  EQ_TAC THEN SIMP_TAC[] THENL
  [INTRO_TAC "img cont" THEN CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
   INTRO_TAC "!u; u" THEN
   SUBGOAL_THEN
     `{x:A | x IN topspace top /\ f x:B IN u} =
      {x | x IN topspace top /\ f x IN u INTER s}`
     (fun th -> REWRITE_TAC[th]) THENL [HYP SET_TAC "img" []; ALL_TAC] THEN
   REMOVE_THEN "cont" MATCH_MP_TAC THEN EXISTS_TAC `u:B->bool` THEN
   ASM_REWRITE_TAC[] THEN ASM SET_TAC[];
   INTRO_TAC "(img cont) img'" THEN
   CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
   INTRO_TAC "!u; @t. t ueq" THEN REMOVE_THEN "ueq" SUBST_VAR_TAC THEN
   SUBGOAL_THEN
     `{x:A | x IN topspace top /\ f x:B IN t INTER s} =
      {x | x IN topspace top /\ f x IN t}`
     (fun th -> ASM_REWRITE_TAC[th]) THEN
   ASM SET_TAC[]]);;

let CONTINUOUS_MAP_FROM_SUBTOPOLOGY = prove
 (`!top top' f:A->B s.
        continuous_map (top,top') f
        ==> continuous_map (subtopology top s,top') f`,
  SIMP_TAC[continuous_map; TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN
  REPEAT GEN_TAC THEN STRIP_TAC THEN X_GEN_TAC `u:B->bool` THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN
  EXISTS_TAC `{x | x IN topspace top /\ (f:A->B) x IN u}` THEN
  ASM_SIMP_TAC[] THEN SET_TAC[]);;

let CONTINUOUS_MAP_INTO_FULLTOPOLOGY = prove
 (`!top top' f:A->B t.
        continuous_map (top,subtopology top' t) f
        ==> continuous_map (top,top') f`,
  SIMP_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY]);;

let CONTINUOUS_MAP_INTO_SUBTOPOLOGY = prove
 (`!top top' f:A->B t.
        continuous_map (top,top') f /\
        IMAGE f (topspace top) SUBSET t
        ==> continuous_map (top,subtopology top' t) f`,
  SIMP_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY]);;

let CONTINUOUS_MAP_FROM_SUBTOPOLOGY_MONO = prove
 (`!top top' f s t.
           continuous_map (subtopology top t,top') f /\ s SUBSET t
           ==> continuous_map (subtopology top s,top') f`,
  MESON_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY; SUBTOPOLOGY_SUBTOPOLOGY;
            SET_RULE `s SUBSET t ==> t INTER s = s`]);;

(* ------------------------------------------------------------------------- *)
(* Open and closed maps (not a priori assumed continuous).                   *)
(* ------------------------------------------------------------------------- *)

let open_map = new_definition
 `open_map (top1,top2) (f:A->B) <=>
  !u. open_in top1 u ==> open_in top2 (IMAGE f u)`;;

let closed_map = new_definition
 `closed_map (top1,top2) (f:A->B) <=>
  !u. closed_in top1 u ==> closed_in top2 (IMAGE f u)`;;

let OPEN_MAP_IMP_SUBSET_TOPSPACE = prove
 (`!top1 top2 f:A->B.
        open_map (top1,top2) f
        ==> IMAGE f (topspace top1) SUBSET topspace top2`,
  MESON_TAC[OPEN_IN_SUBSET; open_map; OPEN_IN_TOPSPACE]);;

let OPEN_MAP_IMP_SUBSET = prove
 (`!top1 top2 f:A->B s.
        open_map (top1,top2) f /\ s SUBSET topspace top1
        ==> IMAGE f s SUBSET topspace top2`,
  MESON_TAC[OPEN_MAP_IMP_SUBSET_TOPSPACE; IMAGE_SUBSET; SUBSET_TRANS]);;

let TOPOLOGY_FINER_OPEN_ID = prove
 (`!top top':A topology.
        (!s. open_in top s ==> open_in top' s) <=>
        open_map (top,top') (\x. x)`,
  REWRITE_TAC[open_map; IMAGE_ID]);;

let OPEN_MAP_ID = prove
 (`!top:A topology. open_map(top,top) (\x. x)`,
  REWRITE_TAC[GSYM TOPOLOGY_FINER_OPEN_ID]);;

let OPEN_MAP_EQ = prove
 (`!top top' f g:A->B.
        (!x. x IN topspace top ==> f x = g x) /\ open_map (top,top') f
        ==> open_map (top,top') g`,
  REPEAT GEN_TAC THEN REWRITE_TAC[open_map] THEN STRIP_TAC THEN
  X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `u:A->bool`) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]);;

let OPEN_MAP_INCLUSION_EQ = prove
 (`!top s:A->bool.
        open_map (subtopology top s,top) (\x. x) <=>
        open_in top (topspace top INTER s)`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[INTER_COMM] THEN
  REWRITE_TAC[open_map; OPEN_IN_SUBTOPOLOGY_ALT] THEN
  REWRITE_TAC[IMAGE_ID; FORALL_IN_GSPEC] THEN
  EQ_TAC THEN SIMP_TAC[OPEN_IN_TOPSPACE] THEN DISCH_TAC THEN
  X_GEN_TAC `t:A->bool` THEN DISCH_TAC THEN
  SUBGOAL_THEN `s INTER t:A->bool = (s INTER topspace top) INTER t`
  SUBST1_TAC THENL
   [REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
    ASM SET_TAC[];
    ASM_SIMP_TAC[OPEN_IN_INTER]]);;

let OPEN_MAP_INCLUSION = prove
 (`!top s:A->bool.
        open_in top s ==> open_map (subtopology top s,top) (\x. x)`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
  REWRITE_TAC[OPEN_MAP_INCLUSION_EQ] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u ==> u INTER s = s`]);;

let OPEN_MAP_COMPOSE = prove
 (`!top top' top'' (f:A->B) (g:B->C).
        open_map(top,top') f /\ open_map(top',top'') g
        ==> open_map(top,top'') (g o f)`,
  REWRITE_TAC[open_map; IMAGE_o] THEN MESON_TAC[]);;

let CLOSED_MAP_IMP_SUBSET_TOPSPACE = prove
 (`!top1 top2 f:A->B.
        closed_map (top1,top2) f
        ==> IMAGE f (topspace top1) SUBSET topspace top2`,
  MESON_TAC[CLOSED_IN_SUBSET; closed_map; CLOSED_IN_TOPSPACE]);;

let CLOSED_MAP_IMP_SUBSET = prove
 (`!top1 top2 f:A->B s.
        closed_map (top1,top2) f /\ s SUBSET topspace top1
        ==> IMAGE f s SUBSET topspace top2`,
  MESON_TAC[CLOSED_MAP_IMP_SUBSET_TOPSPACE; IMAGE_SUBSET; SUBSET_TRANS]);;

let TOPOLOGY_FINER_CLOSED_ID = prove
 (`!top top':A topology.
        (!s. closed_in top s ==> closed_in top' s) <=>
        closed_map (top,top') (\x. x)`,
  REWRITE_TAC[closed_map; IMAGE_ID]);;

let CLOSED_MAP_ID = prove
 (`!top:A topology. closed_map(top,top) (\x. x)`,
  REWRITE_TAC[GSYM TOPOLOGY_FINER_CLOSED_ID]);;

let CLOSED_MAP_EQ = prove
 (`!top top' f g:A->B.
        (!x. x IN topspace top ==> f x = g x) /\ closed_map (top,top') f
        ==> closed_map (top,top') g`,
  REPEAT GEN_TAC THEN REWRITE_TAC[closed_map] THEN STRIP_TAC THEN
  X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `u:A->bool`) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN ASM SET_TAC[]);;

let CLOSED_MAP_COMPOSE = prove
 (`!top top' top'' (f:A->B) (g:B->C).
        closed_map(top,top') f /\ closed_map(top',top'') g
        ==> closed_map(top,top'') (g o f)`,
  REWRITE_TAC[closed_map; IMAGE_o] THEN MESON_TAC[]);;

let CLOSED_MAP_INCLUSION_EQ = prove
 (`!top s:A->bool.
        closed_map (subtopology top s,top) (\x. x) <=>
        closed_in top (topspace top INTER s)`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[INTER_COMM] THEN
  REWRITE_TAC[closed_map; CLOSED_IN_SUBTOPOLOGY_ALT] THEN
  REWRITE_TAC[IMAGE_ID; FORALL_IN_GSPEC] THEN
  EQ_TAC THEN SIMP_TAC[CLOSED_IN_TOPSPACE] THEN DISCH_TAC THEN
  X_GEN_TAC `t:A->bool` THEN DISCH_TAC THEN
  SUBGOAL_THEN `s INTER t:A->bool = (s INTER topspace top) INTER t`
  SUBST1_TAC THENL
   [REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
    ASM SET_TAC[];
    ASM_SIMP_TAC[CLOSED_IN_INTER]]);;

let CLOSED_MAP_INCLUSION = prove
 (`!top s:A->bool.
        closed_in top s ==> closed_map (subtopology top s,top) (\x. x)`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
  REWRITE_TAC[CLOSED_MAP_INCLUSION_EQ] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u ==> u INTER s = s`]);;

let OPEN_MAP_INTO_SUBTOPOLOGY = prove
 (`!top top' (f:A->B) s.
        open_map (top,top') f /\ IMAGE f (topspace top) SUBSET s
        ==> open_map (top,subtopology top' s) f`,
  REPEAT GEN_TAC THEN REWRITE_TAC[open_map; OPEN_IN_SUBTOPOLOGY] THEN
  STRIP_TAC THEN X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN
  EXISTS_TAC `IMAGE (f:A->B) u` THEN ASM_SIMP_TAC[] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]);;

let CLOSED_MAP_INTO_SUBTOPOLOGY = prove
 (`!top top' (f:A->B) s.
        closed_map (top,top') f /\ IMAGE f (topspace top) SUBSET s
        ==> closed_map (top,subtopology top' s) f`,
  REPEAT GEN_TAC THEN REWRITE_TAC[closed_map; CLOSED_IN_SUBTOPOLOGY] THEN
  STRIP_TAC THEN X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN
  EXISTS_TAC `IMAGE (f:A->B) u` THEN ASM_SIMP_TAC[] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN ASM SET_TAC[]);;

let BIJECTIVE_OPEN_IMP_CLOSED_MAP = prove
 (`!top top' f:A->B.
        open_map (top,top') f /\ IMAGE f (topspace top) = topspace top' /\
        (!x y. x IN topspace top /\ y IN topspace top /\ f x = f y ==> x = y)
        ==> closed_map (top,top') f`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[open_map; closed_map; INJECTIVE_ON_ALT] THEN STRIP_TAC THEN
  ONCE_REWRITE_TAC[FORALL_CLOSED_IN] THEN
  X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `u:A->bool`) THEN
  ASM_REWRITE_TAC[closed_in] THEN
  DISCH_THEN(fun th -> CONJ_TAC THENL [ASM SET_TAC[]; MP_TAC th]) THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]);;

let BIJECTIVE_CLOSED_IMP_OPEN_MAP = prove
 (`!top top' f:A->B.
        closed_map (top,top') f /\ IMAGE f (topspace top) = topspace top' /\
        (!x y. x IN topspace top /\ y IN topspace top /\ f x = f y ==> x = y)
        ==> open_map (top,top') f`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[open_map; closed_map; INJECTIVE_ON_ALT] THEN STRIP_TAC THEN
  ONCE_REWRITE_TAC[FORALL_OPEN_IN] THEN
  X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `u:A->bool`) THEN
  ASM_REWRITE_TAC[OPEN_IN_CLOSED_IN_EQ] THEN
  DISCH_THEN(fun th -> CONJ_TAC THENL [ASM SET_TAC[]; MP_TAC th]) THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN ASM SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Quotient maps.                                                            *)
(* ------------------------------------------------------------------------- *)

let quotient_map = new_definition
 `quotient_map (top,top') (f:A->B) <=>
        IMAGE f (topspace top) = topspace top' /\
        !u. u SUBSET topspace top'
            ==> (open_in top {x | x IN topspace top /\ f x IN u} <=>
                 open_in top' u)`;;

let QUOTIENT_MAP_EQ = prove
 (`!top top' f g:A->B.
        (!x. x IN topspace top ==> f x = g x) /\ quotient_map (top,top') f
        ==> quotient_map (top,top') g`,
  REPEAT GEN_TAC THEN REWRITE_TAC[quotient_map] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  MATCH_MP_TAC MONO_AND THEN CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN ABS_TAC THEN
  AP_TERM_TAC THEN AP_THM_TAC THEN AP_TERM_TAC THEN AP_TERM_TAC THEN
  ASM SET_TAC[]);;

let QUOTIENT_MAP_COMPOSE = prove
 (`!top top' top'' (f:A->B) (g:B->C).
        quotient_map(top,top') f /\ quotient_map(top',top'') g
        ==> quotient_map(top,top'') (g o f)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[quotient_map; IMAGE_o; o_THM] THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  X_GEN_TAC `w:C->bool` THEN DISCH_TAC THEN FIRST_X_ASSUM
   (MP_TAC o SPEC `{y | y IN topspace top' /\ (g:B->C) y IN w}`) THEN
  ASM_SIMP_TAC[SUBSET_RESTRICT] THEN DISCH_THEN(SUBST1_TAC o SYM) THEN
  AP_TERM_TAC THEN ASM SET_TAC[]);;

let QUOTIENT_IMP_CONTINUOUS_MAP = prove
 (`!top top' f:A->B.
        quotient_map (top,top') f ==> continuous_map (top,top') f`,
  SIMP_TAC[quotient_map; CONTINUOUS_MAP; OPEN_IN_SUBSET; SUBSET_REFL]);;

let QUOTIENT_IMP_SURJECTIVE_MAP = prove
 (`!top top' f:A->B.
        quotient_map (top,top') f ==> IMAGE f (topspace top) = topspace top'`,
  SIMP_TAC[quotient_map]);;

let QUOTIENT_MAP = prove
 (`!top top' f:A->B.
        quotient_map (top,top') f <=>
        IMAGE f (topspace top) = topspace top' /\
        !u. u SUBSET topspace top'
            ==> (closed_in top {x | x IN topspace top /\ f x IN u} <=>
                 closed_in top' u)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[quotient_map] THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
  DISCH_TAC THEN EQ_TAC THEN DISCH_TAC THEN
  X_GEN_TAC `s:B->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `topspace top' DIFF s:B->bool`) THEN
  ASM_SIMP_TAC[closed_in; SUBSET_RESTRICT; SUBSET_DIFF;
               SET_RULE `s SUBSET u ==> u DIFF (u DIFF s) = s`] THEN
  DISCH_THEN(SUBST1_TAC o SYM) THEN
  AP_TERM_TAC THEN ASM SET_TAC[]);;

let CONTINUOUS_OPEN_IMP_QUOTIENT_MAP = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\ open_map (top,top') f /\
        IMAGE f (topspace top) = topspace top'
        ==> quotient_map (top,top') f`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[continuous_map; open_map; quotient_map] THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN X_GEN_TAC `v:B->bool` THEN
  DISCH_TAC THEN EQ_TAC THEN ASM_SIMP_TAC[] THEN
  DISCH_THEN(ANTE_RES_THEN MP_TAC) THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN ASM SET_TAC[]);;

let CONTINUOUS_CLOSED_IMP_QUOTIENT_MAP = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\ closed_map (top,top') f /\
        IMAGE f (topspace top) = topspace top'
        ==> quotient_map (top,top') f`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN; closed_map; QUOTIENT_MAP] THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN X_GEN_TAC `v:B->bool` THEN
  DISCH_TAC THEN EQ_TAC THEN ASM_SIMP_TAC[] THEN
  DISCH_THEN(ANTE_RES_THEN MP_TAC) THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN ASM SET_TAC[]);;

let CONTINUOUS_OPEN_QUOTIENT_MAP = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\
        open_map (top,top') f
        ==> (quotient_map (top,top') f <=>
             IMAGE f (topspace top) = topspace top')`,
  MESON_TAC[CONTINUOUS_OPEN_IMP_QUOTIENT_MAP; quotient_map]);;

let CONTINUOUS_CLOSED_QUOTIENT_MAP = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\
        closed_map (top,top') f
        ==> (quotient_map (top,top') f <=>
             IMAGE f (topspace top) = topspace top')`,
  MESON_TAC[CONTINUOUS_CLOSED_IMP_QUOTIENT_MAP; quotient_map]);;

let INJECTIVE_QUOTIENT_MAP = prove
 (`!top top' f:A->B.
        (!x y. x IN topspace top /\ y IN topspace top
               ==> (f x = f y <=> x = y))
        ==> (quotient_map (top,top') f <=>
             continuous_map (top,top') f /\
             open_map (top,top') f /\
             closed_map (top,top') f /\
             IMAGE f (topspace top) = topspace top')`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [ALL_TAC; MESON_TAC[CONTINUOUS_OPEN_IMP_QUOTIENT_MAP]] THEN
  SIMP_TAC[QUOTIENT_IMP_CONTINUOUS_MAP; QUOTIENT_IMP_SURJECTIVE_MAP] THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[open_map; closed_map] THEN
  X_GEN_TAC `u:A->bool` THEN DISCH_TAC THENL
   [FIRST_ASSUM(ASSUME_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [quotient_map]);
    FIRST_ASSUM(ASSUME_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [QUOTIENT_MAP])] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
   (MP_TAC o SPEC `IMAGE (f:A->B) u`)) THEN
  (ANTS_TAC THENL [ASM SET_TAC[]; DISCH_THEN(SUBST1_TAC o SYM)]) THEN
  SUBGOAL_THEN `{x | x IN topspace top /\ (f:A->B) x IN IMAGE f u} = u`
   (fun th -> ASM_REWRITE_TAC[th]) THEN
  ASM SET_TAC[]);;

let CONTINUOUS_COMPOSE_QUOTIENT_MAP = prove
 (`!top top' top'' (f:A->B) (g:B->C).
        quotient_map (top,top') f /\
        continuous_map (top,top'') (g o f)
        ==> continuous_map (top',top'') g`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[quotient_map; continuous_map; o_THM] THEN STRIP_TAC THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  X_GEN_TAC `v:C->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(fun th -> W(MP_TAC o PART_MATCH (rand o rand) th o snd)) THEN
  REWRITE_TAC[SUBSET_RESTRICT] THEN DISCH_THEN(SUBST1_TAC o SYM) THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `v:C->bool`) THEN
  ASM_REWRITE_TAC[IN_ELIM_THM] THEN
  MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN ASM SET_TAC[]);;

let CONTINUOUS_COMPOSE_QUOTIENT_MAP_EQ = prove
 (`!top top' top'' (f:A->B) (g:B->C).
        quotient_map (top,top') f
        ==> (continuous_map (top,top'') (g o f) <=>
             continuous_map (top',top'') g)`,
  MESON_TAC[CONTINUOUS_COMPOSE_QUOTIENT_MAP; QUOTIENT_IMP_CONTINUOUS_MAP;
            CONTINUOUS_MAP_COMPOSE]);;

(* ------------------------------------------------------------------------- *)
(* Homeomorphisms (1-way and 2-way versions may be useful in places).        *)
(* ------------------------------------------------------------------------- *)

let homeomorphic_map = new_definition
 `homeomorphic_map (top,top') (f:A->B) <=>
      quotient_map (top,top') f /\
      !x y. x IN topspace top /\ y IN topspace top
            ==> (f x = f y <=> x = y)`;;

let homeomorphic_maps = new_definition
 `homeomorphic_maps(top,top') (f:A->B,g) <=>
        continuous_map(top,top') f /\
        continuous_map(top',top) g /\
        (!x. x IN topspace top ==> g(f x) = x) /\
        (!y. y IN topspace top' ==> f(g y) = y)`;;

let HOMEOMORPHIC_MAP_EQ = prove
 (`!top top' f g:A->B.
        (!x. x IN topspace top ==> f x = g x) /\ homeomorphic_map (top,top') f
        ==> homeomorphic_map (top,top') g`,
  REWRITE_TAC[homeomorphic_map] THEN MESON_TAC[QUOTIENT_MAP_EQ]);;

let HOMEOMORPHIC_MAPS_EQ = prove
 (`!top top' f (f':A->B) g g'.
        (!x. x IN topspace top ==> f x = f' x) /\
        (!x. x IN topspace top' ==> g x = g' x) /\
        homeomorphic_maps (top,top') (f,g)
        ==> homeomorphic_maps (top,top') (f',g')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_maps] THEN STRIP_TAC THEN
  GEN_REWRITE_TAC I [CONJ_ASSOC] THEN
  CONJ_TAC THENL [ASM_MESON_TAC[CONTINUOUS_MAP_EQ]; ALL_TAC] THEN
  REPEAT(FIRST_X_ASSUM
   (MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE)) THEN
  ASM SET_TAC[]);;

let HOMEOMORPHIC_MAPS_SYM = prove
 (`!(f:A->B) g top top'.
        homeomorphic_maps(top,top') (f,g) <=>
        homeomorphic_maps(top',top) (g,f)`,
  REWRITE_TAC[homeomorphic_maps; CONJ_ACI]);;

let HOMEOMORPHIC_MAPS_ID = prove
 (`!top top':A topology.
        homeomorphic_maps(top,top') ((\x. x),(\x. x)) <=> top' = top`,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC[homeomorphic_maps; CONTINUOUS_MAP_ID] THEN
  REWRITE_TAC[continuous_map; IMAGE_ID] THEN
  ASM_CASES_TAC `topspace top':A->bool = topspace top` THENL
   [ASM_REWRITE_TAC[]; ASM SET_TAC[]] THEN
  ASM_SIMP_TAC[OPEN_IN_SUBSET; SET_RULE
   `s SUBSET u ==> {x | x IN u /\ x IN s} = s`] THEN
  FIRST_X_ASSUM(SUBST1_TAC o SYM) THEN
  ASM_SIMP_TAC[OPEN_IN_SUBSET; SET_RULE
   `s SUBSET u ==> {x | x IN u /\ x IN s} = s`] THEN
  REWRITE_TAC[TOPOLOGY_EQ] THEN MESON_TAC[]);;

let HOMEOMORPHIC_MAP_ID = prove
 (`!top top':A topology.
        homeomorphic_map(top,top') (\x. x) <=> top' = top`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[homeomorphic_map; quotient_map; IMAGE_ID] THEN EQ_TAC THENL
   [DISCH_THEN(CONJUNCTS_THEN2 (ASSUME_TAC o SYM) MP_TAC); ALL_TAC] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u ==> {x | x IN u /\ x IN s} = s`] THEN
  GEN_REWRITE_TAC RAND_CONV [TOPOLOGY_EQ] THEN
  ASM_MESON_TAC[OPEN_IN_SUBSET]);;

let HOMEOMORPHIC_MAPS_I = prove
 (`!top top':A topology.
        homeomorphic_maps(top,top') (I,I) <=> top' = top`,
  REWRITE_TAC[I_DEF; HOMEOMORPHIC_MAPS_ID]);;

let HOMEOMORPHIC_MAP_I = prove
 (`!top top':A topology. homeomorphic_map(top,top') I <=> top' = top`,
  REWRITE_TAC[I_DEF; HOMEOMORPHIC_MAP_ID]);;

let HOMEOMORPHIC_MAP_COMPOSE = prove
 (`!top top' top'' (f:A->B) (g:B->C).
        homeomorphic_map(top,top') f /\ homeomorphic_map(top',top'') g
        ==> homeomorphic_map(top,top'') (g o f)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_map; o_THM] THEN STRIP_TAC THEN
  CONJ_TAC THENL [ASM_MESON_TAC[QUOTIENT_MAP_COMPOSE]; ALL_TAC] THEN
  RULE_ASSUM_TAC(REWRITE_RULE
   [quotient_map; GSYM SUBSET_ANTISYM_EQ; SUBSET; FORALL_IN_IMAGE]) THEN
  ASM_MESON_TAC[]);;

let HOMEOMORPHIC_MAPS_COMPOSE = prove
 (`!top top' top'' (f:A->B) (g:B->C) h k.
        homeomorphic_maps(top,top') (f,h) /\
        homeomorphic_maps(top',top'') (g,k)
        ==> homeomorphic_maps(top,top'') (g o f,h o k)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_maps; o_THM] THEN STRIP_TAC THEN
  GEN_REWRITE_TAC I [CONJ_ASSOC] THEN
  CONJ_TAC THENL [ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE]; ALL_TAC] THEN
  REPEAT(FIRST_X_ASSUM
   (MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE)) THEN
  ASM SET_TAC[]);;

let HOMEOMORPHIC_EQ_EVERYTHING_MAP = prove
 (`!top top' f:A->B.
        homeomorphic_map (top,top') f <=>
        continuous_map (top,top') f /\
        open_map (top,top') f /\
        closed_map (top,top') f /\
        IMAGE f (topspace top) = topspace top' /\
        !x y. x IN topspace top /\ y IN topspace top
              ==> (f x = f y <=> x = y)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_map] THEN
  ASM_CASES_TAC
   `!x y. x IN topspace top /\ y IN topspace top
          ==> ((f:A->B) x = f y <=> x = y)` THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC INJECTIVE_QUOTIENT_MAP THEN
  ASM_REWRITE_TAC[]);;

let HOMEOMORPHIC_IMP_CONTINUOUS_MAP = prove
 (`!top top' f:A->B.
        homeomorphic_map (top,top') f ==> continuous_map (top,top') f`,
  SIMP_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP]);;

let HOMEOMORPHIC_IMP_OPEN_MAP = prove
 (`!top top' f:A->B.
        homeomorphic_map (top,top') f ==> open_map (top,top') f`,
  SIMP_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP]);;

let HOMEOMORPHIC_IMP_CLOSED_MAP = prove
 (`!top top' f:A->B.
        homeomorphic_map (top,top') f ==> closed_map (top,top') f`,
  SIMP_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP]);;

let HOMEOMORPHIC_IMP_SURJECTIVE_MAP = prove
 (`!top top' f:A->B.
        homeomorphic_map (top,top') f
        ==> IMAGE f (topspace top) = topspace top'`,
  SIMP_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP]);;

let HOMEOMORPHIC_IMP_INJECTIVE_MAP = prove
 (`!top top' f:A->B.
        homeomorphic_map (top,top') f
        ==> !x y. x IN topspace top /\ y IN topspace top
                  ==> (f x = f y <=> x = y)`,
  SIMP_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP]);;

let BIJECTIVE_OPEN_IMP_HOMEOMORPHIC_MAP = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\
        open_map (top,top') f /\
        IMAGE f (topspace top) = topspace top' /\
        (!x y. x IN topspace top /\ y IN topspace top
               ==> (f x = f y <=> x = y))
        ==> homeomorphic_map(top,top') f`,
  REPEAT STRIP_TAC THEN
  ASM_REWRITE_TAC[homeomorphic_map] THEN
  MATCH_MP_TAC CONTINUOUS_OPEN_IMP_QUOTIENT_MAP THEN
  ASM_REWRITE_TAC[]);;

let BIJECTIVE_CLOSED_IMP_HOMEOMORPHIC_MAP = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\
        closed_map (top,top') f /\
        IMAGE f (topspace top) = topspace top' /\
        (!x y. x IN topspace top /\ y IN topspace top
               ==> (f x = f y <=> x = y))
        ==> homeomorphic_map(top,top') f`,
  REPEAT STRIP_TAC THEN
  ASM_REWRITE_TAC[homeomorphic_map] THEN
  MATCH_MP_TAC CONTINUOUS_CLOSED_IMP_QUOTIENT_MAP THEN
  ASM_REWRITE_TAC[]);;

let OPEN_EQ_CONTINUOUS_INVERSE_MAP = prove
 (`!top top' (f:A->B) g.
        (!x. x IN topspace top ==> f x IN topspace top' /\ g(f x) = x) /\
        (!y. y IN topspace top' ==> g y IN topspace top /\ f(g y) = y)
        ==> (open_map (top,top') f <=> continuous_map (top',top) g)`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  ASM_SIMP_TAC[open_map; continuous_map] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `u:A->bool` THEN
  ASM_CASES_TAC `open_in top (u:A->bool)` THEN ASM_REWRITE_TAC[] THEN
  FIRST_X_ASSUM(ASSUME_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
  AP_TERM_TAC THEN ASM SET_TAC[]);;

let CLOSED_EQ_CONTINUOUS_INVERSE_MAP = prove
 (`!top top' (f:A->B) g.
        (!x. x IN topspace top ==> f x IN topspace top' /\ g(f x) = x) /\
        (!y. y IN topspace top' ==> g y IN topspace top /\ f(g y) = y)
        ==> (closed_map (top,top') f <=> continuous_map (top',top) g)`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  ASM_SIMP_TAC[closed_map; CONTINUOUS_MAP_CLOSED_IN] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `u:A->bool` THEN
  ASM_CASES_TAC `closed_in top (u:A->bool)` THEN ASM_REWRITE_TAC[] THEN
  FIRST_X_ASSUM(ASSUME_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
  AP_TERM_TAC THEN ASM SET_TAC[]);;

let HOMEOMORPHIC_MAPS_MAP = prove
 (`!top top' (f:A->B) g.
        homeomorphic_maps(top,top') (f:A->B,g) <=>
        homeomorphic_map(top,top') f /\
        homeomorphic_map(top',top) g /\
        (!x. x IN topspace top ==> g(f x) = x) /\
        (!y. y IN topspace top' ==> f(g y) = y)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_maps] THEN
  EQ_TAC THENL [STRIP_TAC; MESON_TAC[HOMEOMORPHIC_IMP_CONTINUOUS_MAP]] THEN
  ASM_REWRITE_TAC[] THEN
  CONJ_TAC THEN MATCH_MP_TAC BIJECTIVE_OPEN_IMP_HOMEOMORPHIC_MAP THEN
  ASM_REWRITE_TAC[] THENL
   [MP_TAC(ISPECL [`top:A topology`; `top':B topology`; `f:A->B`; `g:B->A`]
        OPEN_EQ_CONTINUOUS_INVERSE_MAP);
    MP_TAC(ISPECL [`top':B topology`; `top:A topology`; `g:B->A`; `f:A->B`]
        OPEN_EQ_CONTINUOUS_INVERSE_MAP)] THEN
  ASM_REWRITE_TAC[] THEN REPEAT
   (FIRST_X_ASSUM(MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE)) THEN
  ASM SET_TAC[]);;

let HOMEOMORPHIC_MAPS_IMP_MAP = prove
 (`!top top' (f:A->B) g.
        homeomorphic_maps (top,top') (f,g) ==> homeomorphic_map (top,top') f`,
  SIMP_TAC[HOMEOMORPHIC_MAPS_MAP]);;

let HOMEOMORPHIC_MAP_MAPS = prove
 (`!top top' f:A->B.
     homeomorphic_map (top,top') f <=> ?g. homeomorphic_maps (top,top') (f,g)`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [ALL_TAC; MESON_TAC[HOMEOMORPHIC_MAPS_MAP]] THEN
  REWRITE_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM INJECTIVE_ON_ALT]) THEN
  REWRITE_TAC[INJECTIVE_ON_LEFT_INVERSE] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `g:B->A` THEN DISCH_TAC THEN
  MP_TAC(ISPECL [`top:A topology`; `top':B topology`; `f:A->B`; `g:B->A`]
        OPEN_EQ_CONTINUOUS_INVERSE_MAP) THEN
  ASM_REWRITE_TAC[homeomorphic_maps] THEN ASM SET_TAC[]);;

let HOMEOMORPHIC_MAP_OPENNESS = prove
 (`!(f:A->B) top top' u.
        homeomorphic_map(top,top') f /\ u SUBSET topspace top
        ==> (open_in top' (IMAGE f u) <=> open_in top u)`,
  REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [HOMEOMORPHIC_MAP_MAPS]) THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; HOMEOMORPHIC_MAPS_MAP] THEN
  X_GEN_TAC `g:B->A` THEN STRIP_TAC THEN EQ_TAC THENL
   [DISCH_TAC; ASM_MESON_TAC[HOMEOMORPHIC_IMP_OPEN_MAP; open_map]] THEN
  SUBGOAL_THEN `u = IMAGE (g:B->A) (IMAGE f u)` SUBST1_TAC THENL
   [ASM SET_TAC[]; ASM_MESON_TAC[HOMEOMORPHIC_IMP_OPEN_MAP; open_map]]);;

let HOMEOMORPHIC_MAP_CLOSEDNESS = prove
 (`!(f:A->B) top top' u.
        homeomorphic_map(top,top') f /\ u SUBSET topspace top
        ==> (closed_in top' (IMAGE f u) <=> closed_in top u)`,
  REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [HOMEOMORPHIC_MAP_MAPS]) THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; HOMEOMORPHIC_MAPS_MAP] THEN
  X_GEN_TAC `g:B->A` THEN STRIP_TAC THEN EQ_TAC THENL
   [DISCH_TAC; ASM_MESON_TAC[HOMEOMORPHIC_IMP_CLOSED_MAP; closed_map]] THEN
  SUBGOAL_THEN `u = IMAGE (g:B->A) (IMAGE f u)` SUBST1_TAC THENL
   [ASM SET_TAC[]; ASM_MESON_TAC[HOMEOMORPHIC_IMP_CLOSED_MAP; closed_map]]);;

let HOMEOMORPHIC_MAP_OPENNESS_EQ = prove
 (`!(f:A->B) top top' u.
        homeomorphic_map(top,top') f
        ==> (open_in top u <=>
             u SUBSET topspace top /\ open_in top' (IMAGE f u))`,
  MESON_TAC[HOMEOMORPHIC_MAP_OPENNESS; OPEN_IN_SUBSET]);;

let HOMEOMORPHIC_MAP_CLOSEDNESS_EQ = prove
 (`!(f:A->B) top top' u.
        homeomorphic_map(top,top') f
        ==> (closed_in top u <=>
             u SUBSET topspace top /\ closed_in top' (IMAGE f u))`,
  MESON_TAC[HOMEOMORPHIC_MAP_CLOSEDNESS; CLOSED_IN_SUBSET]);;

let FORALL_OPEN_IN_HOMEOMORPHIC_IMAGE = prove
 (`!(f:A->B) top top' P.
        homeomorphic_map(top,top') f
        ==> ((!v. open_in top' v ==> P v) <=>
             (!u. open_in top u ==> P(IMAGE f u)))`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [ASM_MESON_TAC[HOMEOMORPHIC_MAP_OPENNESS; OPEN_IN_SUBSET];
    DISCH_TAC THEN X_GEN_TAC `v:B->bool` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [HOMEOMORPHIC_MAP_MAPS]) THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM; HOMEOMORPHIC_MAPS_MAP] THEN
    X_GEN_TAC `g:B->A` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (g:B->A) v`) THEN ANTS_TAC THENL
     [ASM_MESON_TAC[HOMEOMORPHIC_MAP_OPENNESS; OPEN_IN_SUBSET];
      MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
      FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
      ASM SET_TAC[]]]);;

let FORALL_CLOSED_IN_HOMEOMORPHIC_IMAGE = prove
 (`!(f:A->B) top top' P.
        homeomorphic_map(top,top') f
        ==> ((!v. closed_in top' v ==> P v) <=>
             (!u. closed_in top u ==> P(IMAGE f u)))`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[FORALL_CLOSED_IN] THEN
  FIRST_ASSUM(fun th ->
    REWRITE_TAC[MATCH_MP FORALL_OPEN_IN_HOMEOMORPHIC_IMAGE th]) THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `u:A->bool` THEN
  ASM_CASES_TAC `open_in top (u:A->bool)` THEN ASM_REWRITE_TAC[] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[HOMEOMORPHIC_MAP_MAPS; homeomorphic_maps;
        continuous_map]) THEN
  AP_TERM_TAC THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]);;

let HOMEOMORPHIC_MAPS_SUBTOPOLOGIES = prove
 (`!top top' (f:A->B) g s t.
        homeomorphic_maps(top,top') (f,g) /\
        IMAGE f (topspace top INTER s) = topspace top' INTER t
        ==> homeomorphic_maps(subtopology top s,subtopology top' t) (f,g)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_maps] THEN STRIP_TAC THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; CONTINUOUS_MAP_FROM_SUBTOPOLOGY;
               TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN
  REPEAT(FIRST_X_ASSUM
   (MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE)) THEN
  ASM SET_TAC[]);;

let HOMEOMORPHIC_MAP_SUBTOPOLOGIES = prove
 (`!top top' (f:A->B) s t.
        homeomorphic_map(top,top') f /\
        IMAGE f (topspace top INTER s) = topspace top' INTER t
        ==> homeomorphic_map(subtopology top s,subtopology top' t) f`,
  REPEAT GEN_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
  REWRITE_TAC[HOMEOMORPHIC_MAP_MAPS] THEN MATCH_MP_TAC MONO_EXISTS THEN
  ASM_MESON_TAC[HOMEOMORPHIC_MAPS_SUBTOPOLOGIES]);;

(* ------------------------------------------------------------------------- *)
(* Relation of homeomorphism between topological spaces.                     *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("homeomorphic_space",(12,"right"));;

let homeomorphic_space = new_definition
 `(top:A topology) homeomorphic_space (top':B topology) <=>
        ?f g. homeomorphic_maps(top,top') (f,g)`;;

let HOMEOMORPHIC_SPACE_REFL = prove
 (`!top:A topology. top homeomorphic_space top`,
  REWRITE_TAC[homeomorphic_space] THEN MESON_TAC[HOMEOMORPHIC_MAPS_I]);;

let HOMEOMORPHIC_SPACE_SYM = prove
 (`!top:A topology top':B topology.
        top homeomorphic_space top' <=> top' homeomorphic_space top`,
  REWRITE_TAC[homeomorphic_space] THEN MESON_TAC[HOMEOMORPHIC_MAPS_SYM]);;

let HOMEOMORPHIC_SPACE_TRANS = prove
 (`!top1:A topology top2:B topology top3:C topology.
        top1 homeomorphic_space top2 /\ top2 homeomorphic_space top3
        ==> top1 homeomorphic_space top3`,
  REWRITE_TAC[homeomorphic_space; LEFT_AND_EXISTS_THM;
              RIGHT_AND_EXISTS_THM] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN REPEAT GEN_TAC THEN
  DISCH_THEN(MP_TAC o MATCH_MP HOMEOMORPHIC_MAPS_COMPOSE) THEN MESON_TAC[]);;

let HOMEOMORPHIC_SPACE = prove
 (`!top:A topology top':B topology.
        top homeomorphic_space top' <=> ?f. homeomorphic_map (top,top') f`,
  REWRITE_TAC[homeomorphic_space; HOMEOMORPHIC_MAP_MAPS]);;

let HOMEOMORPHIC_MAPS_IMP_HOMEOMORPHIC_SPACE = prove
 (`!top top' (f:A->B) g.
        homeomorphic_maps (top,top') (f,g) ==> top homeomorphic_space top'`,
  REWRITE_TAC[homeomorphic_space] THEN MESON_TAC[]);;

let HOMEOMORPHIC_MAP_IMP_HOMEOMORPHIC_SPACE = prove
 (`!top top' f:A->B.
        homeomorphic_map (top,top') f ==> top homeomorphic_space top'`,
  REWRITE_TAC[HOMEOMORPHIC_MAP_MAPS; LEFT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAPS_IMP_HOMEOMORPHIC_SPACE]);;

(* ------------------------------------------------------------------------- *)
(* Embedding maps.                                                           *)
(* ------------------------------------------------------------------------- *)

let embedding_map = new_definition
 `embedding_map (top,top') (f:A->B) <=>
        homeomorphic_map (top,subtopology top' (IMAGE f (topspace top))) f`;;

let EMBEDDING_MAP_EQ = prove
 (`!top top' f g:A->B.
        (!x. x IN topspace top ==> f x = g x) /\ embedding_map (top,top') f
        ==> embedding_map (top,top') g`,
  REPEAT GEN_TAC THEN REWRITE_TAC[embedding_map] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  FIRST_ASSUM(SUBST1_TAC o MATCH_MP (SET_RULE
   `(!x. x IN s ==> f x = g x) ==> IMAGE f s = IMAGE g s`)) THEN
  ASM_MESON_TAC[HOMEOMORPHIC_MAP_EQ]);;

let EMBEDDING_MAP_COMPOSE = prove
 (`!top top' top'' (f:A->B) (g:B->C).
        embedding_map(top,top') f /\ embedding_map(top',top'') g
        ==> embedding_map(top,top'') (g o f)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[embedding_map] THEN DISCH_TAC THEN
  MATCH_MP_TAC HOMEOMORPHIC_MAP_COMPOSE THEN
  EXISTS_TAC `subtopology top' (IMAGE (f:A->B) (topspace top))` THEN
  ASM_REWRITE_TAC[] THEN FIRST_ASSUM(MP_TAC o
   SPECL [`IMAGE (f:A->B) (topspace top)`;
          `IMAGE (g:B->C) (IMAGE (f:A->B) (topspace top))`] o
   MATCH_MP (REWRITE_RULE[IMP_CONJ] HOMEOMORPHIC_MAP_SUBTOPOLOGIES) o
   CONJUNCT2) THEN
  FIRST_X_ASSUM(CONJUNCTS_THEN (MP_TAC o
    MATCH_MP HOMEOMORPHIC_IMP_SURJECTIVE_MAP)) THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  DISCH_TAC THEN DISCH_TAC THEN REWRITE_TAC[IMAGE_o] THEN
  ANTS_TAC THENL [ASM SET_TAC[]; MATCH_MP_TAC EQ_IMP] THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN AP_TERM_TAC THEN AP_TERM_TAC THEN
  ASM SET_TAC[]);;

let SURJECTIVE_EMBEDDING_MAP = prove
 (`!top top' f:A->B.
      embedding_map (top,top') f /\ IMAGE f (topspace top) = topspace top' <=>
      homeomorphic_map (top,top') f`,
  REWRITE_TAC[embedding_map; HOMEOMORPHIC_EQ_EVERYTHING_MAP] THEN
  MESON_TAC[SUBTOPOLOGY_TOPSPACE]);;

let EMBEDDING_MAP_IN_SUBTOPOLOGY = prove
 (`!top top' s f:A->B.
         embedding_map (top,subtopology top' s) f <=>
         embedding_map (top,top') f /\ IMAGE f (topspace top) SUBSET s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[embedding_map; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  ASM_CASES_TAC `IMAGE (f:A->B) (topspace top) SUBSET s` THEN
  ASM_SIMP_TAC[SET_RULE `t SUBSET s ==> s INTER t = t`] THEN
  POP_ASSUM MP_TAC THEN REWRITE_TAC[CONTRAPOS_THM] THEN
  REWRITE_TAC[homeomorphic_map; quotient_map; TOPSPACE_SUBTOPOLOGY] THEN
  SET_TAC[]);;

let INJECTIVE_OPEN_IMP_EMBEDDING_MAP = prove
 (`!top top' (f:A->B).
           continuous_map (top,top') f /\
           open_map (top,top') f /\
           (!x y. x IN topspace top /\ y IN topspace top
                  ==> (f x = f y <=> x = y))
           ==> embedding_map (top,top') f`,
  REPEAT STRIP_TAC THEN
  REWRITE_TAC[embedding_map] THEN
  MATCH_MP_TAC BIJECTIVE_OPEN_IMP_HOMEOMORPHIC_MAP THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET_REFL] THEN
  ASM_SIMP_TAC[OPEN_MAP_INTO_SUBTOPOLOGY; SUBSET_REFL] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[]);;

let INJECTIVE_CLOSED_IMP_EMBEDDING_MAP = prove
 (`!top top' (f:A->B).
           continuous_map (top,top') f /\
           closed_map (top,top') f /\
           (!x y. x IN topspace top /\ y IN topspace top
                  ==> (f x = f y <=> x = y))
           ==> embedding_map (top,top') f`,
  REPEAT STRIP_TAC THEN
  REWRITE_TAC[embedding_map] THEN
  MATCH_MP_TAC BIJECTIVE_CLOSED_IMP_HOMEOMORPHIC_MAP THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET_REFL] THEN
  ASM_SIMP_TAC[CLOSED_MAP_INTO_SUBTOPOLOGY; SUBSET_REFL] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[]);;

let EMBEDDING_MAP_IMP_HOMEOMORPHIC_SPACE = prove
 (`!top top' f:A->B.
      embedding_map (top,top') f
      ==> top homeomorphic_space (subtopology top' (IMAGE f (topspace top)))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[embedding_map] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAP_IMP_HOMEOMORPHIC_SPACE]);;

(* ------------------------------------------------------------------------- *)
(* A variant of nets (slightly non-standard but good for our purposes).      *)
(* ------------------------------------------------------------------------- *)

let net_tybij = new_type_definition "net" ("mk_net","dest_net")
 (prove
   (`?g:((A->bool)->bool)#(A->bool).
        !s t. s IN FST g /\ t IN FST g ==> (s INTER t) IN FST g`,
    REWRITE_TAC[EXISTS_PAIR_THM] THEN EXISTS_TAC `(:A->bool)` THEN
    REWRITE_TAC[IN_UNIV]));;

let netfilter = new_definition
 `netfilter(n:A net) = FST(dest_net n)`;;

let netlimits = new_definition
 `netlimits(n:A net) = SND(dest_net n)`;;

let netlimit = new_definition
 `netlimit(n:A net) = @x. x IN netlimits n`;;

let NET = prove
 (`!n x y. !s t. s IN netfilter n /\ t IN netfilter n
                 ==> (s INTER t) IN netfilter n`,
  REWRITE_TAC[netfilter] THEN MESON_TAC[net_tybij]);;

(* ------------------------------------------------------------------------- *)
(* The generic "within" modifier for nets.                                   *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("within",(14,"right"));;

let within = new_definition
  `net within s = mk_net (netfilter net relative_to s,netlimits net)`;;

let WITHIN,NETLIMITS_WITHIN = (CONJ_PAIR o prove)
 (`(!n s:A->bool. netfilter(n within s) = netfilter n relative_to s) /\
   (!n s:A->bool. netlimits(n within s) = netlimits n)`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  REWRITE_TAC[netfilter; netlimits; GSYM PAIR_EQ] THEN
  REWRITE_TAC[within] THEN
  W(MP_TAC o PART_MATCH (lhand o lhand) (GSYM(CONJUNCT2 net_tybij)) o
   lhand o snd) THEN
  MATCH_MP_TAC(TAUT `q /\ (p ==> r) ==> (p <=> q) ==> r`) THEN
  SIMP_TAC[GSYM netfilter; GSYM netlimits; RELATIVE_TO] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_IN_GSPEC] THEN
  X_GEN_TAC `t:A->bool` THEN DISCH_TAC THEN
  X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN
  REWRITE_TAC[RELATIVE_TO; IN_ELIM_THM] THEN
  EXISTS_TAC `t INTER u:A->bool` THEN
  ASM_SIMP_TAC[REWRITE_RULE[IN] NET] THEN SET_TAC[]);;

let NET_WITHIN_UNIV = prove
 (`!net. net within (:A) = net`,
  GEN_TAC THEN MATCH_MP_TAC(MESON[net_tybij]
   `dest_net x = dest_net y ==> x = y`) THEN
  GEN_REWRITE_TAC BINOP_CONV [GSYM PAIR] THEN
  PURE_REWRITE_TAC[GSYM netlimits; GSYM netfilter] THEN
  REWRITE_TAC[WITHIN; NETLIMITS_WITHIN] THEN
  REWRITE_TAC[PAIR_EQ; FUN_EQ_THM; RELATIVE_TO_UNIV]);;

let WITHIN_WITHIN = prove
 (`!net s t. (net within s) within t = net within (s INTER t)`,
  REPEAT GEN_TAC THEN MATCH_MP_TAC(MESON[net_tybij]
   `dest_net x = dest_net y ==> x = y`) THEN
  GEN_REWRITE_TAC BINOP_CONV [GSYM PAIR] THEN
  PURE_REWRITE_TAC[GSYM netlimits; GSYM netfilter] THEN
  REWRITE_TAC[WITHIN; NETLIMITS_WITHIN; PAIR_EQ] THEN
  REWRITE_TAC[RELATIVE_TO_RELATIVE_TO]);;

(* ------------------------------------------------------------------------- *)
(* Some property holds "eventually" for a net.                               *)
(* ------------------------------------------------------------------------- *)

let eventually = new_definition
 `eventually (P:A->bool) net <=>
        netfilter net = {} \/
        ?u. u IN netfilter net /\
            !x. x IN u DIFF netlimits net ==> P x`;;

let trivial_limit = new_definition
  `trivial_limit net <=> eventually (\x. F) net`;;

let EVENTUALLY_WITHIN_IMP = prove
 (`!net (P:A->bool) s.
        eventually P (net within s) <=>
        eventually (\x. x IN s ==> P x) net`,
  REWRITE_TAC[eventually; WITHIN; RELATIVE_TO; EXISTS_IN_GSPEC] THEN
  REWRITE_TAC[INTERS_GSPEC; NETLIMITS_WITHIN] THEN SET_TAC[]);;

let EVENTUALLY_IMP_WITHIN = prove
 (`!net (P:A->bool) s.
        eventually P net ==> eventually P (net within s)`,
  REWRITE_TAC[EVENTUALLY_WITHIN_IMP] THEN REWRITE_TAC[eventually] THEN
  MESON_TAC[]);;

let EVENTUALLY_WITHIN_INTER_IMP = prove
 (`!net (P:A->bool) s t.
        eventually P (net within s INTER t) <=>
        eventually (\x. x IN t ==> P x) (net within s)`,
  REWRITE_TAC[GSYM WITHIN_WITHIN] THEN
  REWRITE_TAC[EVENTUALLY_WITHIN_IMP]);;

let NONTRIVIAL_LIMIT_WITHIN = prove
 (`!net s. trivial_limit net ==> trivial_limit(net within s)`,
  REWRITE_TAC[trivial_limit; EVENTUALLY_IMP_WITHIN]);;

let EVENTUALLY_HAPPENS = prove
 (`!net p. eventually p net ==> trivial_limit net \/ ?x. p x`,
  REWRITE_TAC[trivial_limit; eventually] THEN SET_TAC[]);;

let ALWAYS_EVENTUALLY = prove
 (`(!x. p x) ==> eventually p net`,
  SIMP_TAC[eventually] THEN SET_TAC[]);;

let EVENTUALLY_MONO = prove
 (`!net:(A net) p q.
        (!x. p x ==> q x) /\ eventually p net
        ==> eventually q net`,
  REWRITE_TAC[eventually] THEN MESON_TAC[]);;

let EVENTUALLY_AND = prove
 (`!net:(A net) p q.
        eventually (\x. p x /\ q x) net <=>
        eventually p net /\ eventually q net`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [DISCH_THEN(fun th -> CONJ_TAC THEN MP_TAC th) THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
    SIMP_TAC[];
    REWRITE_TAC[eventually] THEN
    ASM_CASES_TAC `netfilter(net:A net) = {}` THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(CONJUNCTS_THEN2
     (X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC)
     (X_CHOOSE_THEN `v:A->bool` STRIP_ASSUME_TAC)) THEN
    EXISTS_TAC `u INTER v:A->bool` THEN
    ASM_SIMP_TAC[IN_INTER; NET] THEN ASM SET_TAC[]]);;

let EVENTUALLY_MP = prove
 (`!net:(A net) p q.
        eventually (\x. p x ==> q x) net /\ eventually p net
        ==> eventually q net`,
  REWRITE_TAC[GSYM EVENTUALLY_AND] THEN
  REWRITE_TAC[eventually] THEN MESON_TAC[]);;

let EVENTUALLY_EQ_MP = prove
 (`!net P Q. eventually (\x:A. P x <=> Q x) net /\ eventually P net
             ==> eventually Q net`,
  INTRO_TAC "!net P Q; PQ P" THEN REMOVE_THEN "P" MP_TAC THEN
  MATCH_MP_TAC (REWRITE_RULE[IMP_CONJ] EVENTUALLY_MP) THEN
  POP_ASSUM MP_TAC THEN
  MATCH_MP_TAC (REWRITE_RULE[IMP_CONJ] EVENTUALLY_MP) THEN
  MATCH_MP_TAC ALWAYS_EVENTUALLY THEN SIMP_TAC[]);;

let EVENTUALLY_IFF = prove
 (`!net P Q. eventually (\x:A. P x <=> Q x) net
             ==> (eventually P net <=> eventually Q net)`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  (MATCH_MP_TAC o REWRITE_RULE[IMP_CONJ]) EVENTUALLY_EQ_MP THEN
  ASM_REWRITE_TAC[] THEN ONCE_REWRITE_TAC[EQ_SYM_EQ] THEN
  ASM_REWRITE_TAC[]);;

let EVENTUALLY_FALSE = prove
 (`!net. eventually (\x. F) net <=> trivial_limit net`,
  REWRITE_TAC[trivial_limit]);;

let EVENTUALLY_TRUE = prove
 (`!net. eventually (\x. T) net <=> T`,
  REWRITE_TAC[eventually] THEN SET_TAC[]);;

let EVENTUALLY_WITHIN_SUBSET = prove
 (`!P net s t:A->bool.
    eventually P (net within s) /\ t SUBSET s ==> eventually P (net within t)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[EVENTUALLY_WITHIN_IMP] THEN
  DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN ASM SET_TAC[]);;

let ALWAYS_WITHIN_EVENTUALLY = prove
 (`!net P. (!x. x IN s ==> P x) ==> eventually P (net within s)`,
  SIMP_TAC[EVENTUALLY_WITHIN_IMP; EVENTUALLY_TRUE]);;

let NOT_EVENTUALLY = prove
 (`!net p. (!x. ~(p x)) /\ ~(trivial_limit net) ==> ~(eventually p net)`,
  REWRITE_TAC[eventually; trivial_limit] THEN MESON_TAC[]);;

let EVENTUALLY_FORALL = prove
 (`!net:(A net) p s:B->bool.
        FINITE s /\ ~(s = {})
        ==> (eventually (\x. !a. a IN s ==> p a x) net <=>
             !a. a IN s ==> eventually (p a) net)`,
  GEN_TAC THEN GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[FORALL_IN_INSERT; EVENTUALLY_AND; ETA_AX] THEN
  MAP_EVERY X_GEN_TAC [`b:B`; `t:B->bool`] THEN
  ASM_CASES_TAC `t:B->bool = {}` THEN
  ASM_SIMP_TAC[NOT_IN_EMPTY; EVENTUALLY_TRUE]);;

let FORALL_EVENTUALLY = prove
 (`!net:(A net) p s:B->bool.
        FINITE s /\ ~(s = {})
        ==> ((!a. a IN s ==> eventually (p a) net) <=>
             eventually (\x. !a. a IN s ==> p a x) net)`,
  SIMP_TAC[EVENTUALLY_FORALL]);;

let EVENTUALLY_TRIVIAL = prove
 (`!net P:A->bool. trivial_limit net ==> eventually P net`,
  REPEAT GEN_TAC THEN REWRITE_TAC[trivial_limit] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  REWRITE_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Sequential limits.                                                        *)
(* ------------------------------------------------------------------------- *)

let sequentially = new_definition
  `sequentially = mk_net({from n | n IN (:num)},{})`;;

let SEQUENTIALLY,NETLIMITS_SEQUENTIALLY = (CONJ_PAIR o prove)
 (`(!m n. netfilter sequentially = {from n | n IN (:num)}) /\
   (!m n. netlimits sequentially = {})`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  REWRITE_TAC[netfilter; netlimits; GSYM PAIR_EQ] THEN
  REWRITE_TAC[sequentially] THEN
  REWRITE_TAC[GSYM(CONJUNCT2 net_tybij)] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_IN_GSPEC; IN_UNIV] THEN
  MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN
  REWRITE_TAC[IN_ELIM_THM] THEN EXISTS_TAC `MAX m n` THEN
  REWRITE_TAC[EXTENSION; IN_INTER; IN_FROM] THEN ARITH_TAC);;

let EVENTUALLY_SEQUENTIALLY = prove
 (`!p. eventually p sequentially <=> ?N. !n. N <= n ==> p n`,
  REWRITE_TAC[eventually; SEQUENTIALLY; NETLIMITS_SEQUENTIALLY] THEN
  SIMP_TAC[SIMPLE_IMAGE; EXISTS_IN_IMAGE; IMAGE_EQ_EMPTY; UNIV_NOT_EMPTY] THEN
  REWRITE_TAC[IN_UNIV; INTERS_IMAGE; IN_FROM; IN_ELIM_THM; IN_DIFF;
              NOT_IN_EMPTY] THEN
  MESON_TAC[ARITH_RULE `~(SUC n <= n)`]);;

let TRIVIAL_LIMIT_SEQUENTIALLY = prove
 (`~(trivial_limit sequentially)`,
  REWRITE_TAC[trivial_limit; EVENTUALLY_SEQUENTIALLY] THEN
  MESON_TAC[LE_REFL]);;

let EVENTUALLY_HAPPENS_SEQUENTIALLY = prove
 (`!P. eventually P sequentially ==> ?n. P n`,
  MESON_TAC[EVENTUALLY_HAPPENS; TRIVIAL_LIMIT_SEQUENTIALLY]);;

let EVENTUALLY_SEQUENTIALLY_WITHIN = prove
 (`!k p. eventually p (sequentially within k) <=>
         FINITE k \/ (?N. !n. n IN k /\ N <= n ==> p n)`,
  GEN_TAC THEN GEN_TAC THEN
  REWRITE_TAC[EVENTUALLY_WITHIN_IMP; EVENTUALLY_SEQUENTIALLY] THEN
  ASM_CASES_TAC `FINITE (k:num->bool)` THEN ASM_REWRITE_TAC[] THENL
  [POP_ASSUM (STRIP_ASSUME_TAC o REWRITE_RULE[num_FINITE]) THEN
   EXISTS_TAC `a + 1` THEN
   REWRITE_TAC[ARITH_RULE `a + 1 <= n <=> a < n`] THEN
   ASM_MESON_TAC[NOT_LE];
   POP_ASSUM MP_TAC THEN
   REWRITE_TAC[GSYM INFINITE; num_INFINITE_EQ] THEN
   MESON_TAC[]]);;

let TRIVIAL_LIMIT_SEQUENTIALLY_WITHIN = prove
 (`!k. trivial_limit (sequentially within k) <=> FINITE k`,
  GEN_TAC THEN REWRITE_TAC[trivial_limit] THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY_WITHIN] THEN
  ASM_CASES_TAC `FINITE (k:num->bool)` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[NOT_EXISTS_THM; NOT_FORALL_THM] THEN GEN_TAC THEN
  POP_ASSUM (MP_TAC o REWRITE_RULE[GSYM INFINITE; num_INFINITE_EQ]) THEN
  MESON_TAC[]);;

let EVENTUALLY_SUBSEQUENCE = prove
 (`!P r. (!m n. m < n ==> r m < r n) /\ eventually P sequentially
         ==> eventually (P o r) sequentially`,
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY; o_THM] THEN
  MESON_TAC[MONOTONE_BIGGER; LE_TRANS]);;

let ARCH_EVENTUALLY_LT = prove
 (`!x. eventually (\n. x < &n) sequentially`,
  GEN_TAC THEN MP_TAC(ISPEC `x + &1` REAL_ARCH_SIMPLE) THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN MATCH_MP_TAC MONO_EXISTS THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_LE] THEN REAL_ARITH_TAC);;

let ARCH_EVENTUALLY_LE = prove
 (`!x. eventually (\n. x <= &n) sequentially`,
  GEN_TAC THEN MP_TAC(ISPEC `x:real` REAL_ARCH_SIMPLE) THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN MATCH_MP_TAC MONO_EXISTS THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_LE] THEN REAL_ARITH_TAC);;

let ARCH_EVENTUALLY_ABS_INV_OFFSET = prove
 (`!a e. eventually (\n. abs(inv(&n + a)) < e) sequentially <=> &0 < e`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_HAPPENS) THEN
    REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY] THEN REAL_ARITH_TAC;
    DISCH_TAC THEN MATCH_MP_TAC EVENTUALLY_MONO THEN
    EXISTS_TAC `\n. max (&0) (max (&2 * abs a) (&2 / e)) < &n` THEN
    REWRITE_TAC[ARCH_EVENTUALLY_LT] THEN X_GEN_TAC `n:num` THEN
    REWRITE_TAC[REAL_MAX_LT; REAL_OF_NUM_LT] THEN STRIP_TAC THEN
    TRANS_TAC REAL_LET_TRANS `inv(&n / &2)` THEN
    REWRITE_TAC[REAL_ABS_INV] THEN CONJ_TAC THENL
     [MATCH_MP_TAC REAL_LE_INV2 THEN ASM_REAL_ARITH_TAC;
      GEN_REWRITE_TAC RAND_CONV [GSYM REAL_INV_INV] THEN
      MATCH_MP_TAC REAL_LT_INV2 THEN
      ASM_REWRITE_TAC[REAL_LT_INV_EQ] THEN ASM_REAL_ARITH_TAC]]);;

let ARCH_EVENTUALLY_INV_OFFSET = prove
 (`!a e. eventually (\n. inv (&n + a) < e) sequentially <=> &0 < e`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MP_TAC(ISPEC `abs a` ARCH_EVENTUALLY_LT) THEN
    REWRITE_TAC[IMP_IMP; GSYM EVENTUALLY_AND] THEN
    DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_HAPPENS) THEN
    REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `n:num` THEN DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] REAL_LET_TRANS) THEN
    REWRITE_TAC[REAL_LE_INV_EQ] THEN ASM_REAL_ARITH_TAC;
    DISCH_TAC THEN MATCH_MP_TAC EVENTUALLY_MONO THEN
    EXISTS_TAC `\n. abs(inv(&n + a)) < e` THEN
    ASM_SIMP_TAC[ARCH_EVENTUALLY_ABS_INV_OFFSET] THEN REAL_ARITH_TAC]);;

let ARCH_EVENTUALLY_INV1 = prove
 (`!e. eventually (\n. inv(&n + &1) < e) sequentially <=> &0 < e`,
  MP_TAC(SPEC `&1` ARCH_EVENTUALLY_INV_OFFSET) THEN REWRITE_TAC[]);;

let ARCH_EVENTUALLY_INV = prove
 (`!e. eventually (\n. inv(&n) < e) sequentially <=> &0 < e`,
  MP_TAC(SPEC `&0` ARCH_EVENTUALLY_INV_OFFSET) THEN
  REWRITE_TAC[REAL_ADD_RID]);;

let ARCH_EVENTUALLY_POW = prove
 (`!x b. &1 < x ==> eventually (\n. b < x pow n) sequentially`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN
  FIRST_ASSUM(MP_TAC o SPEC `b:real` o MATCH_MP REAL_ARCH_POW) THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `N:num` THEN
  DISCH_TAC THEN X_GEN_TAC `n:num` THEN DISCH_TAC THEN
  TRANS_TAC REAL_LTE_TRANS `(x:real) pow N` THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC REAL_POW_MONO THEN
  ASM_SIMP_TAC[REAL_LT_IMP_LE]);;

let ARCH_EVENTUALLY_POW_INV = prove
 (`!x e. &0 < e /\ abs(x) < &1
         ==> eventually (\n. abs(x pow n) < e) sequentially`,
  REPEAT STRIP_TAC THEN ASM_CASES_TAC `x = &0` THENL
   [REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN EXISTS_TAC `1` THEN
    ASM_SIMP_TAC[REAL_POW_ZERO; LE_1; REAL_ABS_NUM];
    ALL_TAC] THEN
  MP_TAC(ISPECL [`inv(abs x)`; `inv e:real`] ARCH_EVENTUALLY_POW) THEN
  ANTS_TAC THENL
   [MATCH_MP_TAC REAL_INV_1_LT THEN ASM_REAL_ARITH_TAC;
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO)] THEN
  X_GEN_TAC `n:num` THEN REWRITE_TAC[REAL_ABS_POW] THEN DISCH_TAC THEN
  GEN_REWRITE_TAC BINOP_CONV [GSYM REAL_INV_INV] THEN
  ASM_SIMP_TAC[GSYM REAL_POW_INV; REAL_LT_INV; REAL_LT_INV2]);;

let EVENTUALLY_IN_SEQUENTIALLY = prove
 (`!P. eventually P sequentially <=> FINITE {n | ~P n}`,
  GEN_TAC THEN
  REWRITE_TAC[num_FINITE; EVENTUALLY_SEQUENTIALLY; IN_ELIM_THM] THEN
  GEN_REWRITE_TAC (RAND_CONV o ONCE_DEPTH_CONV) [GSYM CONTRAPOS_THM] THEN
  REWRITE_TAC[NOT_LE] THEN
  MESON_TAC[LT_IMP_LE; ARITH_RULE `a + 1 <= x ==> a < x`]);;

let EVENTUALLY_NO_SUBSEQUENCE = prove
 (`!P. eventually P sequentially <=>
       ~(?r:num->num. (!m n. m < n ==> r m < r n) /\ (!n. ~P(r n)))`,
  GEN_TAC THEN REWRITE_TAC[EVENTUALLY_IN_SEQUENTIALLY] THEN
  ONCE_REWRITE_TAC[TAUT `(p <=> ~q) <=> (~p <=> q)`] THEN
  REWRITE_TAC[GSYM INFINITE; INFINITE_ENUMERATE_EQ_ALT] THEN
  REWRITE_TAC[IN_ELIM_THM]);;

let EVENTUALLY_UBOUND_LE_SEQUENTIALLY = prove
 (`!f. (?b. eventually (\n. f n <= b) sequentially) <=> (?b. !n. f n <= b)`,
  GEN_TAC THEN EQ_TAC THEN REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THENL
  [ALL_TAC;
   INTRO_TAC "@b. b" THEN EXISTS_TAC `b:real` THEN ASM_REWRITE_TAC[]] THEN
  INTRO_TAC "@b N. b" THEN ASM_CASES_TAC `N = 0` THENL
  [POP_ASSUM SUBST_ALL_TAC THEN POP_ASSUM MP_TAC THEN
   REWRITE_TAC[LE_0] THEN MESON_TAC[];
   ALL_TAC] THEN
  EXISTS_TAC `max b (sup {f m | m:num < N})` THEN INTRO_TAC "![m]" THEN
  REWRITE_TAC[REAL_LE_MAX] THEN ASM_CASES_TAC `m < N:num` THENL
  [ALL_TAC; DISJ1_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_ARITH_TAC] THEN
  DISJ2_TAC THEN
  CLAIM_TAC "fin" `FINITE {f m:real | m:num < N}` THENL
  [SUBST1_TAC (SET_RULE
     `{f m:real | m:num < N} = IMAGE f {m:num | m < N}`) THEN
   MATCH_MP_TAC FINITE_IMAGE THEN
   REWRITE_TAC[num_FINITE; FORALL_IN_GSPEC] THEN
   EXISTS_TAC `N:num` THEN ARITH_TAC;
   ALL_TAC] THEN
  CLAIM_TAC "ne" `~({f m:real | m:num < N} = {})` THENL
  [REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN EXISTS_TAC `f 0:real` THEN
   REWRITE_TAC[IN_ELIM_THM] THEN EXISTS_TAC `0` THEN
   CONJ_TAC THENL [ASM_ARITH_TAC; REFL_TAC];
   ALL_TAC] THEN
  ASM_SIMP_TAC[REAL_LE_SUP_FINITE] THEN EXISTS_TAC `f (m:num):real` THEN
  REWRITE_TAC[IN_ELIM_THM; REAL_LE_REFL] THEN EXISTS_TAC `m:num` THEN
  ASM_REWRITE_TAC[]);;

let EVENTUALLY_LBOUND_LE_SEQUENTIALLY = prove
 (`!f. (?b. eventually (\n. b <= f n) sequentially) <=> (?b. !n. b <= f n)`,
  GEN_TAC THEN EQ_TAC THEN REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THENL
  [ALL_TAC;
   INTRO_TAC "@b. b" THEN EXISTS_TAC `b:real` THEN ASM_REWRITE_TAC[]] THEN
  INTRO_TAC "@b N. b" THEN ASM_CASES_TAC `N = 0` THENL
  [POP_ASSUM SUBST_ALL_TAC THEN POP_ASSUM MP_TAC THEN
   REWRITE_TAC[LE_0] THEN MESON_TAC[];
   ALL_TAC] THEN
  EXISTS_TAC `min b (inf {f m | m:num < N})` THEN INTRO_TAC "![m]" THEN
  REWRITE_TAC[REAL_MIN_LE] THEN ASM_CASES_TAC `m < N:num` THENL
  [ALL_TAC; DISJ1_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_ARITH_TAC] THEN
  DISJ2_TAC THEN
  CLAIM_TAC "fin" `FINITE {f m:real | m:num < N}` THENL
  [SUBST1_TAC (SET_RULE
     `{f m:real | m:num < N} = IMAGE f {m:num | m < N}`) THEN
   MATCH_MP_TAC FINITE_IMAGE THEN
   REWRITE_TAC[num_FINITE; FORALL_IN_GSPEC] THEN
   EXISTS_TAC `N:num` THEN ARITH_TAC;
   ALL_TAC] THEN
  CLAIM_TAC "ne" `~({f m:real | m:num < N} = {})` THENL
  [REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN EXISTS_TAC `f 0:real` THEN
   REWRITE_TAC[IN_ELIM_THM] THEN EXISTS_TAC `0` THEN
   CONJ_TAC THENL [ASM_ARITH_TAC; REFL_TAC];
   ALL_TAC] THEN
  ASM_SIMP_TAC[REAL_INF_LE_FINITE] THEN EXISTS_TAC `f (m:num):real` THEN
  REWRITE_TAC[IN_ELIM_THM; REAL_LE_REFL] THEN EXISTS_TAC `m:num` THEN
  ASM_REWRITE_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Metric spaces.                                                            *)
(* ------------------------------------------------------------------------- *)

let is_metric_space = new_definition
  `is_metric_space (s,d) <=>
   (!x y:A. x IN s /\ y IN s ==> &0 <= d(x,y)) /\
   (!x y. x IN s /\ y IN s ==> (d(x,y) = &0 <=> x = y)) /\
   (!x y. x IN s /\ y IN s ==> d(x,y) = d(y,x)) /\
   (!x y z. x IN s /\ y IN s /\ z IN s ==> d(x,z) <= d(x,y) + d(y,z))`;;

let IS_METRIC_SPACE = prove
 (`!s d:A#A->real.
        is_metric_space (s,d) <=>
        (!x y. x IN s /\ y IN s ==> (d(x,y) = &0 <=> x = y)) /\
        (!x y z.
              x IN s /\ y IN s /\ z IN s ==> d(x,z) <= d(y,x) + d(y,z))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[is_metric_space] THEN
  EQ_TAC THENL [MESON_TAC[]; STRIP_TAC THEN ASM_REWRITE_TAC[]] THEN
  MATCH_MP_TAC(TAUT `(q ==> r) /\ p /\ q ==> p /\ q /\ r`) THEN
  REPEAT CONJ_TAC THENL
   [ASM_MESON_TAC[];
    ONCE_REWRITE_TAC[REAL_ARITH `&0 <= x <=> &0 <= x + x`] THEN
    ASM_MESON_TAC[];
    REWRITE_TAC[GSYM REAL_LE_ANTISYM] THEN ASM_MESON_TAC[REAL_ADD_RID]]);;

let metric_tybij =
 (new_type_definition "metric" ("metric","dest_metric") o prove)
 (`?m:(A->bool)#(A#A->real). is_metric_space m`,
  EXISTS_TAC `({}:A->bool,(\p:A#A. &0))` THEN
  REWRITE_TAC[is_metric_space; NOT_IN_EMPTY]);;

let IS_METRIC_SPACE_SUBSPACE = prove
 (`!(s:A->bool) d. is_metric_space (s,d) ==>
                   (! s'. s' SUBSET s ==> is_metric_space (s',d))`,
  SIMP_TAC[SUBSET; is_metric_space]);;

let mspace = new_definition
  `!m:A metric. mspace m = FST (dest_metric m)`;;

let mdist = new_definition
  `!m:A metric. mdist m = SND (dest_metric m)`;;

let METRIC = prove
 (`!s d. is_metric_space (s:A->bool,d)
         ==> mspace (metric (s,d)) = s /\
             mdist (metric (s,d)) = d`,
  REWRITE_TAC[mspace; mdist] THEN MESON_TAC[metric_tybij; FST; SND]);;

let MSPACE = prove
 (`!s:A->bool d. is_metric_space (s,d) ==> mspace (metric (s,d)) = s`,
  SIMP_TAC[METRIC]);;

let MDIST = prove
 (`!s:A->bool d. is_metric_space (s,d) ==> mdist (metric (s,d)) = d`,
  SIMP_TAC[METRIC]);;

(* ------------------------------------------------------------------------- *)
(* Distance properties.                                                      *)
(* ------------------------------------------------------------------------- *)

let [MDIST_POS_LE; MDIST_0; MDIST_SYM; MDIST_TRIANGLE] =
  let FORALL_METRIC_THM = prove
   (`!P. (!m. P m) <=>
         (!s:A->bool d. is_metric_space(s,d) ==> P(metric (s,d)))`,
    REWRITE_TAC[GSYM FORALL_PAIR_THM; metric_tybij] THEN
    MESON_TAC[CONJUNCT1 metric_tybij]) in
  let METRIC_AXIOMS =
   (`!m. (!x y:A. x IN mspace m /\ y IN mspace m
                  ==> &0 <= mdist m (x,y)) /\
         (!x y. x IN mspace m /\ y IN mspace m
                ==> (mdist m (x,y) = &0 <=> x = y)) /\
         (!x y. x IN mspace m /\ y IN mspace m
                ==> mdist m (x,y) = mdist m (y,x)) /\
         (!x y z. x IN mspace m /\ y IN mspace m /\ z IN mspace m
                  ==> mdist m (x,z) <= mdist m (x,y) + mdist m (y,z))`,
    SIMP_TAC[FORALL_METRIC_THM; MSPACE; MDIST; is_metric_space]) in
  (CONJUNCTS o REWRITE_RULE [FORALL_AND_THM] o prove) METRIC_AXIOMS;;

let REAL_ABS_MDIST = prove
 (`!m x y:A. x IN mspace m /\ y IN mspace m
             ==> abs(mdist m (x,y)) = mdist m (x,y)`,
  SIMP_TAC[REAL_ABS_REFL; MDIST_POS_LE]);;

let MDIST_POS_LT = prove
 (`!m x y:A. x IN mspace m /\ y IN mspace m /\ ~(x=y)
             ==> &0 < mdist m (x,y)`,
  SIMP_TAC [REAL_LT_LE; MDIST_POS_LE] THEN MESON_TAC[MDIST_0]);;

let MDIST_REFL = prove
 (`!m x:A. x IN mspace m ==> mdist m (x,x) = &0`,
  SIMP_TAC[MDIST_0]);;

let MDIST_POS_EQ = prove
 (`!m x y:A.
        x IN mspace m /\ y IN mspace m
        ==> (&0 < mdist m (x,y) <=> ~(x = y))`,
  MESON_TAC[MDIST_POS_LT; MDIST_REFL; REAL_LT_REFL]);;

let MDIST_REVERSE_TRIANGLE = prove
 (`!m x y z:A. x IN mspace m /\ y IN mspace m /\ z IN mspace m
               ==> abs(mdist m (x,y) - mdist m (y,z)) <= mdist m (x,z)`,
  GEN_TAC THEN
  CLAIM_TAC "rmk"
    `!x y z:A. x IN mspace m /\ y IN mspace m /\ z IN mspace m
               ==> mdist m (x,y) - mdist m (y,z) <= mdist m (x,z)` THEN
  REPEAT STRIP_TAC THENL
  [REWRITE_TAC[REAL_LE_SUB_RADD] THEN ASM_MESON_TAC[MDIST_TRIANGLE; MDIST_SYM];
   REWRITE_TAC[REAL_ABS_BOUNDS;
               REAL_ARITH `!a b c. --a <= b - c <=> c - a <= b`] THEN
   ASM_MESON_TAC[MDIST_SYM]]);;

(* ------------------------------------------------------------------------- *)
(* Open ball.                                                                *)
(* ------------------------------------------------------------------------- *)

let mball = new_definition
  `mball m (x:A,r) =
   {y | x IN mspace m /\ y IN mspace m /\ mdist m (x,y) < r}`;;

let IN_MBALL = prove
 (`!m x y:A r.
     y IN mball m (x,r) <=>
     x IN mspace m /\ y IN mspace m /\ mdist m (x,y) < r`,
  REWRITE_TAC[mball; IN_ELIM_THM]);;

let CENTRE_IN_MBALL = prove
 (`!m x:A r. &0 < r /\ x IN mspace m ==> x IN mball m (x,r)`,
  SIMP_TAC[IN_MBALL; MDIST_REFL; real_gt]);;

let CENTRE_IN_MBALL_EQ = prove
 (`!m x:A r. x IN mball m (x,r) <=> x IN mspace m /\ &0 < r`,
  REPEAT GEN_TAC THEN REWRITE_TAC[IN_MBALL] THEN
  ASM_CASES_TAC `x:A IN mspace m` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[MDIST_REFL]);;

let MBALL_SUBSET_MSPACE = prove
 (`!m (x:A) r. mball m (x,r) SUBSET mspace m`,
  SIMP_TAC[SUBSET; IN_MBALL]);;

let MBALL_EMPTY = prove
 (`!m x:A r. r <= &0 ==> mball m (x,r) = {}`,
  REWRITE_TAC[IN_MBALL; EXTENSION; NOT_IN_EMPTY] THEN
  MESON_TAC[MDIST_POS_LE; REAL_ARITH `!x. ~(r <= &0 /\ &0 <= x /\ x < r)`]);;

let MBALL_EMPTY_ALT = prove
 (`!m x:A r. ~(x IN mspace m) ==> mball m (x,r) = {}`,
  REWRITE_TAC[EXTENSION; NOT_IN_EMPTY; IN_MBALL] THEN MESON_TAC[]);;

let MBALL_EQ_EMPTY = prove
 (`!m x:A r. mball m (x,r) = {} <=> ~(x IN mspace m) \/ r <= &0`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
  [MP_TAC CENTRE_IN_MBALL THEN REWRITE_TAC[GSYM REAL_NOT_LE] THEN SET_TAC[];
   STRIP_TAC THEN ASM_SIMP_TAC[MBALL_EMPTY; MBALL_EMPTY_ALT]]);;

let MBALL_SUBSET = prove
 (`!m x y:A a b. y IN mspace m /\ mdist m (x,y) + a <= b
                 ==> mball m (x,a) SUBSET mball m (y,b)`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `x:A IN mspace m` THENL
  [STRIP_TAC; ASM SET_TAC [MBALL_EMPTY_ALT]] THEN
  ASM_REWRITE_TAC[SUBSET; IN_MBALL] THEN FIX_TAC "[z]" THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  CUT_TAC `mdist m (y,z) <= mdist m (x:A,y) + mdist m (x,z)` THENL
  [ASM_REAL_ARITH_TAC; ASM_MESON_TAC[MDIST_SYM; MDIST_TRIANGLE]]);;

let DISJOINT_MBALL = prove
 (`!m x:A x' r r'. r + r' <= mdist m (x,x')
             ==> DISJOINT (mball m (x,r)) (mball m (x',r'))`,
  REWRITE_TAC[DISJOINT; EXTENSION; IN_INTER; IN_MBALL;
              NOT_IN_EMPTY; CONJ_ACI] THEN
  INTRO_TAC "!m x x' r r'; HPrr'; !x''; x x' x'' d1 d2" THEN
  SUBGOAL_THEN `mdist m (x:A,x') < r + r'`
    (fun th -> ASM_MESON_TAC[th; REAL_NOT_LE]) THEN
  TRANS_TAC REAL_LET_TRANS `mdist m (x:A,x'') + mdist m (x'',x')` THEN
  ASM_SIMP_TAC[MDIST_TRIANGLE; MDIST_SYM] THEN
  HYP (MP_TAC o end_itlist CONJ) "d1 d2" [] THEN REAL_ARITH_TAC);;

let MBALL_SUBSET_CONCENTRIC = prove
 (`!m (x:A) r1 r2. r1 <= r2 ==> mball m (x,r1) SUBSET mball m (x,r2)`,
  SIMP_TAC[SUBSET; IN_MBALL] THEN MESON_TAC[REAL_LTE_TRANS]);;

(* ------------------------------------------------------------------------- *)
(* Subspace of a metric space.                                               *)
(* ------------------------------------------------------------------------- *)

let submetric = new_definition
  `submetric (m:A metric) s = metric (s INTER mspace m, mdist m)`;;

let SUBMETRIC = prove
 (`(!m:A metric s. mspace (submetric m s) = s INTER mspace m) /\
   (!m:A metric s. mdist (submetric m s) = mdist m)`,
  CLAIM_TAC "metric"
    `!m:A metric s. is_metric_space (s INTER mspace m, mdist m)` THENL
  [REWRITE_TAC[is_metric_space; IN_INTER] THEN
   SIMP_TAC[MDIST_POS_LE; MDIST_0; MDIST_SYM; MDIST_TRIANGLE];
   ASM_SIMP_TAC[submetric; MSPACE; MDIST]]);;

let MBALL_SUBMETRIC_EQ = prove
 (`!m s a:A r. mball (submetric m s) (a,r) =
               if a IN s then s INTER mball m (a,r) else {}`,
  REPEAT GEN_TAC THEN COND_CASES_TAC THEN
  ASM_REWRITE_TAC[EXTENSION; IN_INTER; IN_MBALL; SUBMETRIC] THEN
  SET_TAC[]);;

let MBALL_SUBMETRIC = prove
 (`!m s x:A r. x IN s ==> mball (submetric m s) (x,r) = mball m (x,r) INTER s`,
  SIMP_TAC[MBALL_SUBMETRIC_EQ; INTER_COMM]);;

let SUBMETRIC_UNIV = prove
 (`submetric m (:A) = m`,
  REWRITE_TAC[submetric; INTER_UNIV; mspace; mdist; metric_tybij]);;

let SUBMETRIC_SUBMETRIC = prove
 (`!m s t:A->bool.
        submetric (submetric m s) t = submetric m (s INTER t)`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[submetric] THEN
  REWRITE_TAC[SUBMETRIC] THEN
  REWRITE_TAC[SET_RULE `(s INTER t) INTER m = t INTER s INTER m`]);;

let SUBMETRIC_MSPACE = prove
 (`!m:A metric. submetric m (mspace m) = m`,
  GEN_TAC THEN REWRITE_TAC[submetric; SET_RULE `s INTER s = s`] THEN
  GEN_REWRITE_TAC RAND_CONV [GSYM(CONJUNCT1 metric_tybij)] THEN
  REWRITE_TAC[mspace; mdist]);;

let SUBMETRIC_RESTRICT = prove
 (`!m s:A->bool. submetric m s = submetric m (mspace m INTER s)`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o LAND_CONV) [GSYM SUBMETRIC_MSPACE] THEN
  REWRITE_TAC[SUBMETRIC_SUBMETRIC]);;

(* ------------------------------------------------------------------------- *)
(* Metric topology                                                           *)
(* ------------------------------------------------------------------------- *)

let mtopology = new_definition
  `mtopology (m:A metric) =
   topology {u | u SUBSET mspace m /\
                 !x:A. x IN u ==> ?r. &0 < r /\ mball m (x,r) SUBSET u}`;;

let IS_TOPOLOGY_METRIC_TOPOLOGY = prove
 (`istopology {u | u SUBSET mspace m /\
                   !x:A. x IN u ==> ?r. &0 < r /\ mball m (x,r) SUBSET u}`,
  REWRITE_TAC[istopology; IN_ELIM_THM; NOT_IN_EMPTY; EMPTY_SUBSET] THEN
  CONJ_TAC THENL
  [INTRO_TAC "!s t; (s shp) (t thp)" THEN CONJ_TAC THENL
   [HYP SET_TAC "s t" []; ALL_TAC] THEN
   REWRITE_TAC[IN_INTER] THEN INTRO_TAC "!x; sx tx" THEN
   REMOVE_THEN "shp"
     (DESTRUCT_TAC "@r1. r1 rs" o C MATCH_MP (ASSUME `x:A IN s`)) THEN
   REMOVE_THEN "thp"
     (DESTRUCT_TAC "@r2. r2 rt" o C MATCH_MP (ASSUME `x:A IN t`)) THEN
   EXISTS_TAC `min r1 r2` THEN
   ASM_REWRITE_TAC[REAL_LT_MIN; SUBSET_INTER] THEN
   ASM_MESON_TAC[REAL_MIN_MIN; MBALL_SUBSET_CONCENTRIC; SUBSET_TRANS];
   REWRITE_TAC[SUBSET; IN_ELIM_THM; IN_UNIONS] THEN MESON_TAC[]]);;

let OPEN_IN_MTOPOLOGY = prove
 (`!m:A metric u.
     open_in (mtopology m) u <=>
     u SUBSET mspace m /\
     (!x. x IN u ==> ?r. &0 < r /\ mball m (x,r) SUBSET u)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[mtopology] THEN
  (SUBST1_TAC o REWRITE_RULE[IS_TOPOLOGY_METRIC_TOPOLOGY] o
  SPEC `{u | u SUBSET mspace m /\
             !x:A. x IN u ==> ?r. &0 < r /\ mball m (x,r) SUBSET u}` o
  CONJUNCT2)
  topology_tybij THEN
  GEN_REWRITE_TAC LAND_CONV [GSYM IN] THEN REWRITE_TAC[IN_ELIM_THM]);;

let TOPSPACE_MTOPOLOGY = prove
 (`!m:A metric. topspace (mtopology m) = mspace m`,
  GEN_TAC THEN REWRITE_TAC[mtopology; topspace] THEN
  (SUBST1_TAC o REWRITE_RULE[IS_TOPOLOGY_METRIC_TOPOLOGY] o
  SPEC `{u | u SUBSET mspace m /\
             !x:A. x IN u ==> ?r. &0 < r /\ mball m (x,r) SUBSET u}` o
  CONJUNCT2)
  topology_tybij THEN
  REWRITE_TAC[EXTENSION; IN_UNIONS; IN_ELIM_THM] THEN GEN_TAC THEN EQ_TAC THENL
  [SET_TAC[]; ALL_TAC] THEN
  INTRO_TAC "x" THEN EXISTS_TAC `mspace (m:A metric)` THEN
  ASM_REWRITE_TAC[MBALL_SUBSET_MSPACE; SUBSET_REFL] THEN
  MESON_TAC[REAL_LT_01]);;

let SUBTOPOLOGY_MSPACE = prove
 (`!m:A metric. subtopology (mtopology m) (mspace m) = mtopology m`,
  REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY; SUBTOPOLOGY_TOPSPACE]);;

let OPEN_IN_MSPACE = prove
 (`!m:A metric. open_in (mtopology m) (mspace m)`,
  REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY; OPEN_IN_TOPSPACE]);;

let CLOSED_IN_MSPACE = prove
 (`!m:A metric. closed_in (mtopology m) (mspace m)`,
  REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY; CLOSED_IN_TOPSPACE]);;

let OPEN_IN_MBALL = prove
 (`!m (x:A) r. open_in (mtopology m) (mball m (x,r))`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `&0 < (r:real)` THENL
  [ALL_TAC; ASM_SIMP_TAC[MBALL_EMPTY; GSYM REAL_NOT_LT; OPEN_IN_EMPTY]] THEN
  REWRITE_TAC[OPEN_IN_MTOPOLOGY; MBALL_SUBSET_MSPACE; IN_MBALL; SUBSET] THEN
  INTRO_TAC "![y]; x y xy" THEN ASM_REWRITE_TAC[] THEN
  EXISTS_TAC `r - mdist m (x:A,y)` THEN CONJ_TAC THENL
  [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
  INTRO_TAC "![z]; z lt" THEN ASM_REWRITE_TAC[] THEN
  TRANS_TAC REAL_LET_TRANS `mdist m (x:A,y) + mdist m (y,z)` THEN
  ASM_SIMP_TAC[MDIST_TRIANGLE] THEN ASM_REAL_ARITH_TAC);;

let MTOPOLOGY_SUBMETRIC = prove
 (`!m:A metric s. mtopology (submetric m s) = subtopology (mtopology m) s`,
  REWRITE_TAC[TOPOLOGY_EQ] THEN INTRO_TAC "!m s [u]" THEN
  EQ_TAC THEN INTRO_TAC "hp" THENL
  [REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN
   EXISTS_TAC
     `UNIONS {mball m (c:A,r) | c,r | mball m (c,r) INTER s SUBSET u}` THEN
   CONJ_TAC THENL
   [MATCH_MP_TAC OPEN_IN_UNIONS THEN REWRITE_TAC[IN_ELIM_THM] THEN
    INTRO_TAC "![t]; @c r. sub t" THEN REMOVE_THEN "t" SUBST_VAR_TAC THEN
    MATCH_ACCEPT_TAC OPEN_IN_MBALL;
    MATCH_MP_TAC SUBSET_ANTISYM THEN CONJ_TAC THENL [ALL_TAC; SET_TAC[]] THEN
    HYP_TAC "hp: (us um) hp"
      (REWRITE_RULE[OPEN_IN_MTOPOLOGY; SUBMETRIC; SUBSET_INTER]) THEN
    ASM_REWRITE_TAC[SUBSET_INTER] THEN REWRITE_TAC[SUBSET] THEN
    INTRO_TAC "!x; x" THEN
    USE_THEN "x" (HYP_TAC "hp: @r. rpos sub" o C MATCH_MP) THEN
    REWRITE_TAC[IN_UNIONS; IN_ELIM_THM] THEN
    EXISTS_TAC `mball m (x:A,r)` THEN
    CONJ_TAC THENL
    [REWRITE_TAC[IN_ELIM_THM] THEN MAP_EVERY EXISTS_TAC [`x:A`; `r:real`] THEN
     IMP_REWRITE_TAC [GSYM MBALL_SUBMETRIC] THEN ASM SET_TAC[];
     MATCH_MP_TAC CENTRE_IN_MBALL THEN ASM SET_TAC[]]];
   ALL_TAC] THEN
  REWRITE_TAC[OPEN_IN_MTOPOLOGY; SUBMETRIC; SUBSET_INTER] THEN
  HYP_TAC "hp: @t. t u" (REWRITE_RULE[OPEN_IN_SUBTOPOLOGY]) THEN
  REMOVE_THEN "u" SUBST_VAR_TAC THEN
  HYP_TAC "t: tm r" (REWRITE_RULE[OPEN_IN_MTOPOLOGY]) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  REWRITE_TAC[IN_INTER] THEN INTRO_TAC "!x; xt xs" THEN
  USE_THEN "xt" (HYP_TAC "r: @r. rpos sub" o C MATCH_MP) THEN
  EXISTS_TAC `r:real` THEN IMP_REWRITE_TAC[MBALL_SUBMETRIC] THEN
  ASM SET_TAC[]);;

let METRIC_INJECTIVE_IMAGE = prove
 (`!(f:A->B) m s.
        IMAGE f s SUBSET mspace m /\
        (!x y. x IN s /\ y IN s /\ f x = f y ==> x = y)
        ==> (mspace(metric(s,\(x,y). mdist m (f x,f y))) = s) /\
            (mdist(metric(s,\(x,y). mdist m (f x,f y))) =
             \(x,y). mdist m (f x,f y))`,
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; INJECTIVE_ON_ALT] THEN
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  REWRITE_TAC[mspace; mdist; GSYM PAIR_EQ] THEN
  REWRITE_TAC[GSYM(CONJUNCT2 metric_tybij); is_metric_space] THEN
  REWRITE_TAC[GSYM mspace; GSYM mdist] THEN
  ASM_SIMP_TAC[MDIST_POS_LE; MDIST_TRIANGLE; MDIST_0] THEN
  ASM_MESON_TAC[MDIST_SYM]);;

(* ------------------------------------------------------------------------- *)
(* Closed sets.                                                              *)
(* ------------------------------------------------------------------------- *)

let CLOSED_IN_METRIC = prove
 (`!m c:A->bool.
     closed_in (mtopology m) c <=>
     c SUBSET mspace m /\
     (!x. x IN mspace m DIFF c ==> ?r. &0 < r /\ DISJOINT c (mball m (x,r)))`,
  REWRITE_TAC[closed_in; OPEN_IN_MTOPOLOGY; DISJOINT; TOPSPACE_MTOPOLOGY] THEN
  MP_TAC MBALL_SUBSET_MSPACE THEN ASM SET_TAC[]);;

let mcball = new_definition
  `mcball m (x:A,r) =
   {y | x IN mspace m /\ y IN mspace m /\ mdist m (x,y) <= r}`;;

let IN_MCBALL = prove
 (`!m (x:A) r y.
     y IN mcball m (x,r) <=>
     x IN mspace m /\ y IN mspace m /\ mdist m (x,y) <= r`,
  REWRITE_TAC[mcball; IN_ELIM_THM]);;

let CENTRE_IN_MCBALL = prove
 (`!m x:A r. &0 <= r /\ x IN mspace m ==> x IN mcball m (x,r)`,
  SIMP_TAC[IN_MCBALL; MDIST_REFL]);;

let CENTRE_IN_MCBALL_EQ = prove
 (`!m x:A r. x IN mcball m (x,r) <=> x IN mspace m /\ &0 <= r`,
  REPEAT GEN_TAC THEN REWRITE_TAC[IN_MCBALL] THEN
  ASM_CASES_TAC `x:A IN mspace m` THEN ASM_SIMP_TAC[MDIST_REFL]);;

let MCBALL_EQ_EMPTY = prove
 (`!m x:A r. mcball m (x,r) = {} <=> ~(x IN mspace m) \/ r < &0`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[EXTENSION; IN_MCBALL; IN_ELIM_THM; NOT_IN_EMPTY] THEN
  ASM_MESON_TAC[REAL_NOT_LT; REAL_LE_TRANS; MDIST_POS_LE; MDIST_REFL]);;

let MCBALL_EMPTY = prove
 (`!m (x:A) r. r < &0 ==> mcball m (x,r) = {}`,
  SIMP_TAC[MCBALL_EQ_EMPTY]);;

let MCBALL_EMPTY_ALT = prove
 (`!m (x:A) r. ~(x IN mspace m) ==> mcball m (x,r) = {}`,
  SIMP_TAC[MCBALL_EQ_EMPTY]);;

let MCBALL_SUBSET_MSPACE = prove
 (`!m (x:A) r. mcball m (x,r) SUBSET (mspace m)`,
  REWRITE_TAC[mcball; SUBSET; IN_ELIM_THM] THEN MESON_TAC[]);;

let MBALL_SUBSET_MCBALL = prove
 (`!m x:A r. mball m (x,r) SUBSET mcball m (x,r)`,
  SIMP_TAC[SUBSET; IN_MBALL; IN_MCBALL; REAL_LT_IMP_LE]);;

let MCBALL_SUBSET = prove
 (`!m x y:A a b. y IN mspace m /\ mdist m (x,y) + a <= b
                 ==> mcball m (x,a) SUBSET mcball m (y,b)`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `x:A IN mspace m` THENL
  [STRIP_TAC; ASM SET_TAC [MCBALL_EMPTY_ALT]] THEN
  ASM_REWRITE_TAC[SUBSET; IN_MCBALL] THEN FIX_TAC "[z]" THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  CUT_TAC `mdist m (y,z) <= mdist m (x:A,y) + mdist m (x,z)` THENL
  [ASM_REAL_ARITH_TAC; ASM_MESON_TAC[MDIST_SYM; MDIST_TRIANGLE]]);;

let MCBALL_SUBSET_CONCENTRIC = prove
 (`!m (x:A) a b. a <= b ==> mcball m (x,a) SUBSET mcball m (x,b)`,
  SIMP_TAC[SUBSET; IN_MCBALL] THEN MESON_TAC[REAL_LE_TRANS]);;

let MCBALL_SUBSET_MBALL = prove
 (`!m x y:A a b.
     y IN mspace m /\ mdist m (x,y) + a < b
     ==> mcball m (x,a) SUBSET mball m (y,b)`,
  INTRO_TAC "!m x y a b; y lt" THEN ASM_CASES_TAC `x:A IN mspace m` THENL
  [POP_ASSUM (LABEL_TAC "x");
   ASM_SIMP_TAC[MCBALL_EMPTY_ALT; EMPTY_SUBSET]] THEN
  ASM_REWRITE_TAC[SUBSET; IN_MCBALL; IN_MBALL] THEN
  INTRO_TAC "![z]; z le" THEN HYP REWRITE_TAC "z" [] THEN
  TRANS_TAC REAL_LET_TRANS `mdist m (y:A,x) + mdist m (x,z)` THEN
  ASM_SIMP_TAC[MDIST_TRIANGLE] THEN
  TRANS_TAC REAL_LET_TRANS `mdist m (x:A,y) + a` THEN
  HYP REWRITE_TAC "lt" [] THEN HYP SIMP_TAC "x y" [MDIST_SYM] THEN
  ASM_REAL_ARITH_TAC);;

let MCBALL_SUBSET_MBALL_CONCENTRIC = prove
 (`!m x:A a b. a < b ==> mcball m (x,a) SUBSET mball m (x,b)`,
  INTRO_TAC "!m x a b; lt" THEN ASM_CASES_TAC `x:A IN mspace m` THENL
  [POP_ASSUM (LABEL_TAC "x");
   ASM_SIMP_TAC[MCBALL_EMPTY_ALT; EMPTY_SUBSET]] THEN
  MATCH_MP_TAC MCBALL_SUBSET_MBALL THEN ASM_SIMP_TAC[MDIST_REFL] THEN
  ASM_REAL_ARITH_TAC);;

let CLOSED_IN_MCBALL = prove
 (`!m:A metric x r. closed_in (mtopology m) (mcball m (x,r))`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[CLOSED_IN_METRIC; MCBALL_SUBSET_MSPACE; DIFF; IN_ELIM_THM;
              IN_MCBALL; DE_MORGAN_THM; REAL_NOT_LE] THEN
  FIX_TAC "[y]" THEN
  MAP_EVERY ASM_CASES_TAC [`x:A IN mspace m`; `y:A IN mspace m`] THEN
  ASM_REWRITE_TAC[] THENL
  [ALL_TAC;
   ASM_SIMP_TAC[MCBALL_EMPTY_ALT; DISJOINT_EMPTY] THEN
   MESON_TAC[REAL_LT_01]] THEN
  INTRO_TAC "lt" THEN EXISTS_TAC `mdist m (x:A,y) - r` THEN
  CONJ_TAC THENL [ASM_REAL_ARITH_TAC; ASM_REWRITE_TAC[]] THEN
  REWRITE_TAC[EXTENSION; DISJOINT; IN_INTER; NOT_IN_EMPTY;
              IN_MBALL; IN_MCBALL] THEN
  FIX_TAC "[z]" THEN ASM_CASES_TAC `z:A IN mspace m` THEN
  ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN `mdist m (x,y) <= mdist m (x:A,z) + mdist m (z,y)` MP_TAC THENL
  [ASM_SIMP_TAC[MDIST_TRIANGLE]; ALL_TAC] THEN
  ASM_SIMP_TAC[MDIST_SYM] THEN ASM_REAL_ARITH_TAC);;

let MCBALL_SUBMETRIC_EQ = prove
 (`!m s a:A r. mcball (submetric m s) (a,r) =
               if a IN s then s INTER mcball m (a,r) else {}`,
  REPEAT GEN_TAC THEN COND_CASES_TAC THEN
  ASM_REWRITE_TAC[EXTENSION; IN_INTER; IN_MCBALL; SUBMETRIC] THEN
  SET_TAC[]);;

let MCBALL_SUBMETRIC = prove
 (`!m s x:A r.
     x IN s ==> mcball (submetric m s) (x,r) = mcball m (x,r) INTER s`,
  SIMP_TAC[MCBALL_SUBMETRIC_EQ; INTER_COMM]);;

let OPEN_IN_MTOPOLOGY_MCBALL = prove
 (`!m u. open_in (mtopology m) (u:A->bool) <=>
         u SUBSET mspace m /\
         (!x. x IN u ==> (?r. &0 < r /\ mcball m (x,r) SUBSET u))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[OPEN_IN_MTOPOLOGY] THEN
  ASM_CASES_TAC `u:A->bool SUBSET mspace m` THEN
  ASM_REWRITE_TAC[] THEN EQ_TAC THENL
  [INTRO_TAC "hp; !x; x" THEN
   REMOVE_THEN "x" (HYP_TAC "hp: @r. rpos sub" o C MATCH_MP) THEN
   EXISTS_TAC `r / &2` THEN
   HYP REWRITE_TAC "rpos" [REAL_HALF] THEN
   TRANS_TAC SUBSET_TRANS `mball m (x:A,r)` THEN HYP REWRITE_TAC "sub" [] THEN
   MATCH_MP_TAC MCBALL_SUBSET_MBALL_CONCENTRIC THEN
   ASM_REAL_ARITH_TAC;
   INTRO_TAC "hp; !x; x" THEN
   REMOVE_THEN "x" (HYP_TAC "hp: @r. rpos sub" o C MATCH_MP) THEN
   EXISTS_TAC `r:real` THEN HYP REWRITE_TAC "rpos" [] THEN
   TRANS_TAC SUBSET_TRANS `mcball m (x:A,r)` THEN
   HYP REWRITE_TAC "sub" [MBALL_SUBSET_MCBALL]]);;

let METRIC_DERIVED_SET_OF = prove
  (`!m s.
      mtopology m derived_set_of s =
      {x:A | x IN mspace m /\
            (!r. &0 < r ==> (?y. ~(y = x) /\ y IN s /\ y IN mball m (x,r)))}`,
  REWRITE_TAC[derived_set_of; TOPSPACE_MTOPOLOGY; OPEN_IN_MTOPOLOGY; EXTENSION;
              IN_ELIM_THM] THEN
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `x:A IN mspace m` THEN ASM_REWRITE_TAC[] THEN
  POP_ASSUM (LABEL_TAC "x") THEN EQ_TAC THENL
  [INTRO_TAC "hp; !r; r" THEN HYP_TAC "hp: +" (SPEC `mball m (x:A,r)`) THEN
   ASM_REWRITE_TAC[CENTRE_IN_MBALL_EQ; MBALL_SUBSET_MSPACE] THEN
   DISCH_THEN MATCH_MP_TAC THEN HYP REWRITE_TAC "x" [IN_MBALL] THEN
   INTRO_TAC "![y]; y xy" THEN EXISTS_TAC `r - mdist m (x:A,y)` THEN
   CONJ_TAC THENL
   [REMOVE_THEN "xy" MP_TAC THEN REAL_ARITH_TAC;
    HYP REWRITE_TAC "x y" [SUBSET; IN_MBALL] THEN INTRO_TAC "![z]; z lt" THEN
    HYP REWRITE_TAC "z" [] THEN
    TRANS_TAC REAL_LET_TRANS `mdist m (x:A,y) + mdist m (y,z)` THEN
    ASM_SIMP_TAC[MDIST_TRIANGLE] THEN ASM_REAL_ARITH_TAC];
   INTRO_TAC "hp; !t; t inc r" THEN
   HYP_TAC "r: @r. r ball" (C MATCH_MP (ASSUME `x:A IN t`)) THEN
   HYP_TAC "hp: @y. neq y dist" (C MATCH_MP (ASSUME `&0 < r`)) THEN
   EXISTS_TAC `y:A` THEN HYP REWRITE_TAC "neq y" [] THEN
   ASM SET_TAC[]]);;

let METRIC_CLOSURE_OF = prove
  (`!m s.
      mtopology m closure_of s =
      {x:A | x IN mspace m /\
            (!r. &0 < r ==> (?y. y IN s /\ y IN mball m (x,r)))}`,
  REWRITE_TAC[closure_of; TOPSPACE_MTOPOLOGY; OPEN_IN_MTOPOLOGY; EXTENSION;
              IN_ELIM_THM] THEN
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `x:A IN mspace m` THEN ASM_REWRITE_TAC[] THEN
  POP_ASSUM (LABEL_TAC "x") THEN EQ_TAC THENL
  [INTRO_TAC "hp; !r; r" THEN HYP_TAC "hp: +" (SPEC `mball m (x:A,r)`) THEN
   ASM_REWRITE_TAC[CENTRE_IN_MBALL_EQ; MBALL_SUBSET_MSPACE] THEN
   DISCH_THEN MATCH_MP_TAC THEN HYP REWRITE_TAC "x" [IN_MBALL] THEN
   INTRO_TAC "![y]; y xy" THEN EXISTS_TAC `r - mdist m (x:A,y)` THEN
   CONJ_TAC THENL
   [REMOVE_THEN "xy" MP_TAC THEN REAL_ARITH_TAC;
    HYP REWRITE_TAC "x y" [SUBSET; IN_MBALL] THEN INTRO_TAC "![z]; z lt" THEN
    HYP REWRITE_TAC "z" [] THEN
    TRANS_TAC REAL_LET_TRANS `mdist m (x:A,y) + mdist m (y,z)` THEN
    ASM_SIMP_TAC[MDIST_TRIANGLE] THEN ASM_REAL_ARITH_TAC];
   INTRO_TAC "hp; !t; t inc r" THEN
   HYP_TAC "r: @r. r ball" (C MATCH_MP (ASSUME `x:A IN t`)) THEN
   HYP_TAC "hp: @y. y dist" (C MATCH_MP (ASSUME `&0 < r`)) THEN
   EXISTS_TAC `y:A` THEN HYP REWRITE_TAC "y" [] THEN
   ASM SET_TAC[]]);;

let METRIC_CLOSURE_OF_ALT = prove
 (`!m s:A->bool.
      mtopology m closure_of s =
      {x | x IN mspace m /\
           !r. &0 < r ==> ?y. y IN s /\ y IN mcball m (x,r)}`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM; METRIC_CLOSURE_OF] THEN
  X_GEN_TAC `x:A` THEN EQ_TAC THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  X_GEN_TAC `r:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `r / &2`) THEN
  ASM_REWRITE_TAC[REAL_HALF] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `y:A` THEN MATCH_MP_TAC MONO_AND THEN
  SIMP_TAC[IN_MBALL; IN_MCBALL] THEN ASM_REAL_ARITH_TAC);;

let METRIC_INTERIOR_OF = prove
 (`!m s:A->bool.
        mtopology m interior_of s =
        {x | x IN mspace m /\ ?e. &0 < e /\ mball m (x,e) SUBSET s}`,
  REWRITE_TAC[INTERIOR_OF_CLOSURE_OF; METRIC_CLOSURE_OF; TOPSPACE_MTOPOLOGY;
              IN_DIFF; IN_MBALL; SUBSET] THEN
  SET_TAC[]);;

let METRIC_INTERIOR_OF_ALT = prove
 (`!m s:A->bool.
        mtopology m interior_of s =
        {x | x IN mspace m /\ ?e. &0 < e /\ mcball m (x,e) SUBSET s}`,
  REWRITE_TAC[INTERIOR_OF_CLOSURE_OF; METRIC_CLOSURE_OF_ALT; IN_DIFF;
              IN_MCBALL; TOPSPACE_MTOPOLOGY; SUBSET] THEN
  SET_TAC[]);;

let IN_INTERIOR_OF_MBALL = prove
 (`!m s x:A.
        x IN (mtopology m) interior_of s <=>
        x IN mspace m /\
        ?e. &0 < e /\ mball m (x,e) SUBSET s`,
  REWRITE_TAC[METRIC_INTERIOR_OF; IN_ELIM_THM]);;

let IN_INTERIOR_OF_MCBALL = prove
 (`!m s x:A.
        x IN (mtopology m) interior_of s <=>
        x IN mspace m /\
        ?e. &0 < e /\ mcball m (x,e) SUBSET s`,
  REWRITE_TAC[METRIC_INTERIOR_OF_ALT; IN_ELIM_THM]);;

(* ------------------------------------------------------------------------- *)
(* The discrete metric.                                                      *)
(* ------------------------------------------------------------------------- *)

let discrete_metric = new_definition
  `discrete_metric s = metric(s,(\(x,y). if x = y then &0 else &1))`;;

let DISCRETE_METRIC = prove
 (`(!s:A->bool. mspace(discrete_metric s) = s) /\
   (!s x y:A. mdist (discrete_metric s) (x,y) = if x = y then &0 else &1)`,
  REWRITE_TAC[AND_FORALL_THM] THEN X_GEN_TAC `s:A->bool` THEN
  MP_TAC(ISPECL [`s:A->bool`; `\(x:A,y). if x = y then &0 else &1`]
        METRIC) THEN
  REWRITE_TAC[GSYM discrete_metric] THEN
  REWRITE_TAC[FUN_EQ_THM; FORALL_PAIR_THM] THEN
  DISCH_THEN MATCH_MP_TAC THEN REWRITE_TAC[is_metric_space] THEN
  REPEAT STRIP_TAC THEN REPEAT(COND_CASES_TAC THEN ASM_REWRITE_TAC[]) THEN
  CONV_TAC REAL_RAT_REDUCE_CONV THEN ASM_MESON_TAC[]);;

let MTOPOLOGY_DISCRETE_METRIC = prove
 (`!s:A->bool. mtopology(discrete_metric s) = discrete_topology s`,
  GEN_TAC THEN CONV_TAC SYM_CONV THEN
  REWRITE_TAC[DISCRETE_TOPOLOGY_UNIQUE] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY; DISCRETE_METRIC; OPEN_IN_MTOPOLOGY] THEN
  X_GEN_TAC `x:A` THEN DISCH_TAC THEN ASM_REWRITE_TAC[SING_SUBSET] THEN
  REWRITE_TAC[IN_SING; FORALL_UNWIND_THM2] THEN EXISTS_TAC `&1` THEN
  REWRITE_TAC[SUBSET; REAL_LT_01; IN_MBALL; DISCRETE_METRIC] THEN
  GEN_TAC THEN COND_CASES_TAC THEN ASM_REWRITE_TAC[IN_SING; REAL_LT_REFL]);;

let DISCRETE_ULTRAMETRIC = prove
 (`!s x y z:A.
        mdist(discrete_metric s) (x,z) <=
        max (mdist(discrete_metric s) (x,y))
            (mdist(discrete_metric s) (y,z))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[DISCRETE_METRIC] THEN
  REPEAT(COND_CASES_TAC THEN ASM_REWRITE_TAC[]) THEN
  CONV_TAC REAL_RAT_REDUCE_CONV THEN ASM_MESON_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Spheres in metric spaces.                                                 *)
(* ------------------------------------------------------------------------- *)

let msphere = new_definition
  `msphere m (x:A,e) = {y | mdist m (x,y) = e}`;;

(* ------------------------------------------------------------------------- *)
(* Bounded sets.                                                             *)
(* ------------------------------------------------------------------------- *)

let mbounded = new_definition
  `mbounded m s <=> (?c:A b. s SUBSET mcball m (c,b))`;;

let MBOUNDED_POS = prove
 (`!m s:A->bool.
        mbounded m s <=> ?c b. &0 < b /\ s SUBSET mcball m (c,b)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[mbounded] THEN
  EQ_TAC THEN MATCH_MP_TAC MONO_EXISTS THENL [ALL_TAC; MESON_TAC[]] THEN
  X_GEN_TAC `a:A` THEN DISCH_THEN(X_CHOOSE_TAC `B:real`) THEN
  EXISTS_TAC `abs B + &1` THEN CONJ_TAC THENL [REAL_ARITH_TAC; ALL_TAC] THEN
  TRANS_TAC SUBSET_TRANS `mcball m (a:A,B)` THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MCBALL_SUBSET_CONCENTRIC THEN
  REAL_ARITH_TAC);;

let MBOUNDED_ALT = prove
 (`!m s:A->bool.
        mbounded m s <=>
        s SUBSET mspace m /\
        ?b. !x y. x IN s /\ y IN s ==> mdist m (x,y) <= b`,
  REPEAT GEN_TAC THEN REWRITE_TAC[mbounded] THEN EQ_TAC THENL
   [REWRITE_TAC[LEFT_IMP_EXISTS_THM; SUBSET; IN_MCBALL] THEN
    MAP_EVERY X_GEN_TAC [`a:A`; `b:real`] THEN
    STRIP_TAC THEN ASM_SIMP_TAC[] THEN EXISTS_TAC `&2 * b` THEN
    MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
    TRANS_TAC REAL_LE_TRANS `mdist m (x:A,a) + mdist m (a,y)` THEN
    CONJ_TAC THENL [ASM_MESON_TAC[MDIST_TRIANGLE; MDIST_SYM]; ALL_TAC] THEN
    MATCH_MP_TAC(REAL_ARITH `x <= b /\ y <= b ==> x + y <= &2 * b`) THEN
    ASM_MESON_TAC[MDIST_SYM];
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (X_CHOOSE_TAC `B:real`)) THEN
    ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[EMPTY_SUBSET] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `a:A` THEN STRIP_TAC THEN
    EXISTS_TAC `B:real` THEN REWRITE_TAC[SUBSET; IN_MCBALL] THEN
    X_GEN_TAC `x:A` THEN DISCH_TAC THEN ASM SET_TAC[]]);;

let MBOUNDED_ALT_POS = prove
 (`!m s:A->bool.
        mbounded m s <=>
        s SUBSET mspace m /\
        ?B. &0 < B /\ !x y. x IN s /\ y IN s ==> mdist m (x,y) <= B`,
  REPEAT GEN_TAC THEN REWRITE_TAC[MBOUNDED_ALT] THEN AP_TERM_TAC THEN
  EQ_TAC THENL [ALL_TAC; MESON_TAC[]] THEN
  DISCH_THEN(X_CHOOSE_THEN `B:real` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `abs B + &1` THEN CONJ_TAC THENL
   [REAL_ARITH_TAC; ASM_MESON_TAC[REAL_ARITH `x <= b ==> x <= abs b + &1`]]);;

let MBOUNDED_SUBSET = prove
 (`!m s t:A->bool. mbounded m t /\ s SUBSET t ==> mbounded m s`,
  REWRITE_TAC[mbounded] THEN SET_TAC[]);;

let MBOUNDED_SUBSET_MSPACE = prove
 (`!m s:A->bool. mbounded m s ==> s SUBSET mspace m`,
  REWRITE_TAC[mbounded] THEN REPEAT STRIP_TAC THEN
  TRANS_TAC SUBSET_TRANS `mcball m (c:A,b)` THEN
  ASM_REWRITE_TAC[MCBALL_SUBSET_MSPACE]);;

let MBOUNDED = prove
 (`!m s. mbounded m s <=>
         s = {} \/
         (!x:A. x IN s ==> x IN mspace m) /\
         (?c b. c IN mspace m /\ (!x. x IN s ==> mdist m (c,x) <= b))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[mbounded; SUBSET; IN_MCBALL] THEN
  ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[NOT_IN_EMPTY] THEN
  ASM SET_TAC[]);;

let MBOUNDED_EMPTY = prove
 (`!m:A metric. mbounded m {}`,
  REWRITE_TAC[mbounded; EMPTY_SUBSET]);;

let MBOUNDED_MCBALL = prove
 (`!m:A metric c b. mbounded m (mcball m (c,b))`,
  REWRITE_TAC[mbounded] THEN MESON_TAC[SUBSET_REFL]);;

let MBOUNDED_MBALL = prove
 (`!m:A metric c b. mbounded m (mball m (c,b))`,
  REPEAT GEN_TAC THEN MATCH_MP_TAC MBOUNDED_SUBSET THEN
  EXISTS_TAC `mcball m (c:A,b)` THEN
  REWRITE_TAC[MBALL_SUBSET_MCBALL; MBOUNDED_MCBALL]);;

let MBOUNDED_INSERT = prove
 (`!m a:A s. mbounded m (a INSERT s) <=> a IN mspace m /\ mbounded m s`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[MBOUNDED; NOT_INSERT_EMPTY; IN_INSERT] THEN
  ASM_CASES_TAC `a:A IN mspace m` THEN ASM_REWRITE_TAC[] THENL
  [ALL_TAC; ASM_MESON_TAC[]] THEN ASM_CASES_TAC `s:A->bool = {}` THEN
  ASM_SIMP_TAC[NOT_IN_EMPTY] THENL [ASM_MESON_TAC[REAL_LE_REFL]; ALL_TAC] THEN
  EQ_TAC THEN STRIP_TAC THEN ASM_SIMP_TAC[] THENL
  [ASM_MESON_TAC[]; ALL_TAC] THEN
  CONJ_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
  MAP_EVERY EXISTS_TAC [`c:A`; `max b (mdist m (c:A,a))`] THEN
  REPEAT STRIP_TAC THEN ASM_REWRITE_TAC[REAL_MAX_MAX] THEN
  TRANS_TAC REAL_LE_TRANS `b:real` THEN ASM_SIMP_TAC[REAL_MAX_MAX]);;

let MBOUNDED_INTER = prove
 (`!m:A metric s t. mbounded m s /\ mbounded m t ==> mbounded m (s INTER t)`,
  REWRITE_TAC[mbounded] THEN SET_TAC[]);;

let MBOUNDED_UNION = prove
 (`!m:A metric s t. mbounded m (s UNION t) <=> mbounded m s /\ mbounded m t`,
  REPEAT GEN_TAC THEN REWRITE_TAC[mbounded] THEN EQ_TAC THENL
  [SET_TAC[]; INTRO_TAC "(@c1 b1. s) (@c2 b2. t)"] THEN
  ASM_CASES_TAC
    `&0 <= b1 /\ &0 <= b2 /\ c1:A IN mspace m /\ c2 IN mspace m` THENL
  [POP_ASSUM STRIP_ASSUME_TAC;
   POP_ASSUM MP_TAC THEN REWRITE_TAC[DE_MORGAN_THM; REAL_NOT_LE] THEN
   ASM SET_TAC [MCBALL_EMPTY; MCBALL_EMPTY_ALT]] THEN
  MAP_EVERY EXISTS_TAC [`c1:A`; `b1 + b2 + mdist m (c1:A,c2)`] THEN
  REWRITE_TAC[UNION_SUBSET] THEN CONJ_TAC THENL
  [TRANS_TAC SUBSET_TRANS `mcball m (c1:A,b1)` THEN ASM_REWRITE_TAC[] THEN
   MATCH_MP_TAC MCBALL_SUBSET_CONCENTRIC THEN
   CUT_TAC `&0 <= mdist m (c1:A,c2)` THENL
   [ASM_REAL_ARITH_TAC; ASM_SIMP_TAC[MDIST_POS_LE]];
   TRANS_TAC SUBSET_TRANS `mcball m (c2:A,b2)` THEN ASM_REWRITE_TAC[] THEN
   MATCH_MP_TAC MCBALL_SUBSET THEN ASM_SIMP_TAC[MDIST_SYM] THEN
   ASM_REAL_ARITH_TAC]);;

let MBOUNDED_UNIONS = prove
 (`!m f:(A->bool)->bool.
        FINITE f /\ (!s. s IN f ==> mbounded m s)
        ==> mbounded m (UNIONS f)`,
  GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[FORALL_IN_INSERT; UNIONS_INSERT; NOT_IN_EMPTY] THEN
  SIMP_TAC[UNIONS_0; MBOUNDED_EMPTY; MBOUNDED_UNION]);;

let MBOUNDED_CLOSURE_OF = prove
 (`!m s:A->bool.
      mbounded m s ==> mbounded m (mtopology m closure_of s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[mbounded] THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN DISCH_TAC THEN
  MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN
  ASM_REWRITE_TAC[CLOSED_IN_MCBALL]);;

let MBOUNDED_CLOSURE_OF_EQ = prove
 (`!m s:A->bool.
        s SUBSET mspace m
        ==> (mbounded m (mtopology m closure_of s) <=> mbounded m s)`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  REWRITE_TAC[MBOUNDED_CLOSURE_OF] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] MBOUNDED_SUBSET) THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBSET; TOPSPACE_MTOPOLOGY]);;

let MBOUNDED_SUBMETRIC = prove
 (`!m:A metric s.
     mbounded (submetric m s) t <=> mbounded m (s INTER t) /\ t SUBSET s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[MBOUNDED_ALT; SUBMETRIC] THEN
  SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* A decision procedure for metric spaces.                                   *)
(* ------------------------------------------------------------------------- *)

let METRIC_ARITH : term -> thm =
  let SUP_CONV =
    let conv0 = REWR_CONV SUP_INSERT_INSERT
    and conv1 = REWR_CONV SUP_SING in
    conv1 ORELSEC (conv0 THENC REPEATC conv0 THENC TRY_CONV conv1) in
  let MAXDIST_THM = prove
   (`!m s x y:A.
       mbounded m s /\ x IN s /\ y IN s
       ==> mdist m (x,y) =
           sup (IMAGE (\a. abs(mdist m (x,a) - mdist m (a,y))) s)`,
    REPEAT GEN_TAC THEN INTRO_TAC "bnd x y" THEN
    MATCH_MP_TAC (GSYM SUP_UNIQUE) THEN
    CLAIM_TAC "inc" `!p:A. p IN s ==> p IN mspace m` THENL
    [HYP SET_TAC "bnd" [MBOUNDED_SUBSET_MSPACE]; ALL_TAC] THEN
    GEN_TAC THEN REWRITE_TAC[FORALL_IN_IMAGE] THEN EQ_TAC THENL
    [INTRO_TAC "le; ![z]; z" THEN
     TRANS_TAC REAL_LE_TRANS `mdist m (x:A,y)` THEN
     ASM_SIMP_TAC[MDIST_REVERSE_TRIANGLE];
     DISCH_THEN (MP_TAC o C MATCH_MP (ASSUME `y:A IN s`)) THEN
     ASM_SIMP_TAC[MDIST_REFL; REAL_SUB_RZERO; REAL_ABS_MDIST]])
  and METRIC_EQ_THM = prove
   (`!m s x y:A.
       s SUBSET mspace m /\ x IN s /\ y IN s
       ==> (x = y <=> (!a. a IN s ==> mdist m (x,a) = mdist m (y,a)))`,
    INTRO_TAC "!m s x y; sub sx sy" THEN EQ_TAC THEN SIMP_TAC[] THEN
    DISCH_THEN (MP_TAC o SPEC `y:A`) THEN
    CLAIM_TAC "x y" `x:A IN mspace m /\ y IN mspace m` THENL
    [ASM SET_TAC []; ASM_SIMP_TAC[MDIST_REFL; MDIST_0]]) in
  let CONJ1_CONV : conv -> conv =
    let TRUE_CONJ_CONV = REWR_CONV (MESON [] `T /\ p <=> p`) in
    fun conv -> LAND_CONV conv THENC TRUE_CONJ_CONV in
  let IN_CONV : conv =
    let DISJ_TRUE_CONV = REWR_CONV (MESON [] `p \/ T <=> T`)
    and TRUE_DISJ_CONV = REWR_CONV (MESON [] `T \/ p <=> T`) in
    let REFL_CONV = REWR_CONV (MESON [] `x:A = x <=> T`) in
    let conv0 = REWR_CONV (EQF_INTRO (SPEC_ALL NOT_IN_EMPTY)) in
    let conv1 = REWR_CONV IN_INSERT in
    let conv2 = LAND_CONV REFL_CONV THENC TRUE_DISJ_CONV in
    let rec IN_CONV tm =
      (conv0 ORELSEC
       (conv1 THENC
        (conv2 ORELSEC
         (RAND_CONV IN_CONV THENC DISJ_TRUE_CONV)))) tm in
    IN_CONV
  and IMAGE_CONV : conv =
    let pth0,pth1 = CONJ_PAIR IMAGE_CLAUSES in
    let conv0 = REWR_CONV pth0
    and conv1 = REWR_CONV pth1 THENC TRY_CONV (LAND_CONV BETA_CONV) in
    let rec IMAGE_CONV tm =
      (conv0 ORELSEC (conv1 THENC RAND_CONV IMAGE_CONV)) tm in
    IMAGE_CONV in
  let SUBSET_CONV : conv -> conv =
    let conv0 = REWR_CONV (EQT_INTRO (SPEC_ALL EMPTY_SUBSET)) in
    let conv1 = REWR_CONV INSERT_SUBSET in
    fun conv ->
      let conv2 = conv1 THENC CONJ1_CONV conv in
      REPEATC conv2 THENC conv0 in
  let rec prove_hyps th =
    match hyp th with
    | [] -> th
    | htm :: _ ->
        let emth = SPEC htm EXCLUDED_MIDDLE in
        let nhp = EQF_INTRO (ASSUME (mk_neg htm)) in
        let nth1 = (SUBS_CONV [nhp] THENC PRESIMP_CONV) (concl th) in
        let nth2 = MESON [nhp] (rand (concl nth1)) in
        let nth = EQ_MP (SYM nth1) nth2 in
        prove_hyps(DISJ_CASES emth th nth) in
  let rec guess_metric tm =
    match tm with
    | Comb(Const("mdist",_),m) -> m
    | Comb(Const("mspace",_),m) -> m
    | Comb(s,t) -> (try guess_metric s with Failure _ -> guess_metric t)
    | Abs(_, bd) -> guess_metric bd
    | _ -> failwith "metric not found" in
  let find_mdist mtm =
    let rec find tm =
      match tm with
      | Comb(Comb(Const("mdist",_),pmtm),p) when pmtm = mtm -> [tm]
      | Comb(s,t) -> union (find s) (find t)
      | Abs(v, bd) -> filter (fun x -> not(free_in v x)) (find bd)
      | _ -> [] in
    find
  and find_eq mty =
    let rec find tm =
      match tm with
      | Comb(Comb(Const("=",ty),_),_) when fst(dest_fun_ty ty) = mty -> [tm]
      | Comb(s,t) -> union (find s) (find t)
      | Abs(v, bd) -> filter (fun x -> not(free_in v x)) (find bd)
      | _ -> [] in
    find
  and find_points mtm =
    let rec find tm =
      match tm with
      | Comb(Comb(Const("mdist",_),pmtm),p) when pmtm = mtm ->
          let x,y = dest_pair p in
          if x = y then [x] else [x;y]
      | Comb(Comb(Const("IN",_),x),Comb(Const("mspace",_),pmtm))
          when pmtm = mtm -> [x]
      | Comb(s,t) -> union (find s) (find t)
      | Abs(v, bd) -> filter (fun x -> not(free_in v x)) (find bd)
      | _ -> [] in
    find in
  let prenex_conv =
    TOP_DEPTH_CONV BETA_CONV THENC
    PURE_REWRITE_CONV[FORALL_SIMP; EXISTS_SIMP] THENC
    NNFC_CONV THENC DEPTH_BINOP_CONV `(/\)` CONDS_CELIM_CONV THENC
    PRESIMP_CONV THENC
    GEN_REWRITE_CONV REDEPTH_CONV
      [AND_FORALL_THM; LEFT_AND_FORALL_THM; RIGHT_AND_FORALL_THM;
       LEFT_OR_FORALL_THM; RIGHT_OR_FORALL_THM] THENC
    PRENEX_CONV
  and real_poly_conv =
    let eths = REAL_ARITH
      `(x = y <=> x - y = &0) /\
       (x < y <=> y - x > &0) /\
       (x > y <=> x - y > &0) /\
       (x <= y <=> y - x >= &0) /\
       (x >= y <=> x - y >= &0)` in
    GEN_REWRITE_CONV I [eths] THENC LAND_CONV REAL_POLY_CONV
  and augment_mdist_pos_thm =
    MESON [] `p ==> (q <=> r) ==> (q <=> (p ==> r))` in
  fun tm ->
    let mtm = guess_metric tm in
    let mty = hd(snd(dest_type(type_of mtm))) in
    let mspace_tm = mk_icomb(mk_const("mspace",[]),mtm) in
    let metric_eq_thm = ISPEC mtm METRIC_EQ_THM
    and mk_in_mspace_th =
      let in_tm = mk_const("IN",[mty,aty]) in
      fun pt -> ASSUME (mk_comb(mk_comb(in_tm,pt),mspace_tm)) in
    let th0 = prenex_conv tm in
    let tm0 = rand (concl th0) in
    let avs,bod = strip_forall tm0 in
    let points = find_points mtm bod in
    let in_mspace_conv = GEN_REWRITE_CONV I (map mk_in_mspace_th points) in
    let in_mspace2_conv = CONJ1_CONV in_mspace_conv THENC in_mspace_conv in
    let MDIST_REFL_CONV =
      let pconv = IMP_REWR_CONV (ISPEC mtm MDIST_REFL) in
      fun tm -> MP_CONV in_mspace_conv (pconv tm)
    and MDIST_SYM_CONV =
      let pconv = IMP_REWR_CONV (ISPEC mtm MDIST_SYM) in
      fun tm -> let x,y = dest_pair (rand tm) in
                if x <= y then failwith "MDIST_SYM_CONV" else
                MP_CONV in_mspace2_conv (pconv tm)
    and MBOUNDED_CONV =
      let conv0 = REWR_CONV (EQT_INTRO (ISPEC mtm MBOUNDED_EMPTY)) in
      let conv1 = REWR_CONV (ISPEC mtm MBOUNDED_INSERT) in
      let rec mbounded_conv tm =
        try conv0 tm with Failure _ ->
        (conv1 THENC CONJ1_CONV in_mspace_conv THENC mbounded_conv) tm in
      mbounded_conv in
    let REFL_SYM_CONV = MDIST_REFL_CONV ORELSEC MDIST_SYM_CONV in
    let ABS_MDIST_CONV =
      let pconv = IMP_REWR_CONV (ISPEC mtm REAL_ABS_MDIST) in
      fun tm -> MP_CONV in_mspace2_conv (pconv tm) in
    let metric_eq_prerule =
      (CONV_RULE o BINDER_CONV o BINDER_CONV)
      (LAND_CONV (CONJ1_CONV (SUBSET_CONV in_mspace_conv)) THENC
       RAND_CONV (REWRITE_CONV[FORALL_IN_INSERT; NOT_IN_EMPTY])) in
    let MAXDIST_CONV =
      let maxdist_thm = ISPEC mtm MAXDIST_THM
      and ante_conv =
        CONJ1_CONV MBOUNDED_CONV THENC CONJ1_CONV IN_CONV THENC IN_CONV
      and image_conv =
        IMAGE_CONV THENC ONCE_DEPTH_CONV REFL_SYM_CONV THENC
        PURE_REWRITE_CONV
          [REAL_SUB_LZERO; REAL_SUB_RZERO; REAL_SUB_REFL;
           REAL_ABS_0; REAL_ABS_NEG; REAL_ABS_SUB; INSERT_AC] THENC
        ONCE_DEPTH_CONV ABS_MDIST_CONV THENC
        PURE_REWRITE_CONV[INSERT_AC] in
      let sup_conv = RAND_CONV image_conv THENC SUP_CONV in
      fun fset_tm ->
        let maxdist_th = SPEC fset_tm maxdist_thm in
        fun tm ->
          let th0 = MP_CONV ante_conv (IMP_REWR_CONV maxdist_th tm) in
          let tm0 = rand (concl th0) in
          let th1 = sup_conv tm0 in
          TRANS th0 th1 in
    let AUGMENT_MDISTS_POS_RULE =
      let mdist_pos_le = ISPEC mtm MDIST_POS_LE in
      let augment_rule : term -> thm -> thm =
        let mk_mdist_pos_thm tm =
          let xtm,ytm = dest_pair (rand tm) in
          let pth = SPECL[xtm;ytm] mdist_pos_le in
          MP_CONV (CONJ1_CONV in_mspace_conv THENC in_mspace_conv) pth in
        fun mdist_tm ->
          let ith =
            MATCH_MP augment_mdist_pos_thm (mk_mdist_pos_thm mdist_tm) in
          fun th -> MATCH_MP ith th in
      fun th ->
        let mdist_thl = find_mdist mtm (concl th) in
        itlist augment_rule mdist_thl th in
    let BASIC_METRIC_ARITH (tm : term) : thm =
      let mdist_tms = find_mdist mtm tm in
      let th0 =
        let eqs =
          mapfilter (MDIST_REFL_CONV ORELSEC MDIST_SYM_CONV) mdist_tms in
        (ONCE_DEPTH_CONV in_mspace_conv THENC PRESIMP_CONV THENC
         SUBS_CONV eqs THENC REAL_RAT_REDUCE_CONV THENC
         ONCE_DEPTH_CONV real_poly_conv) tm in
      let tm0 = rand (concl th0) in
      let points = find_points mtm tm0 in
      let fset_tm = mk_setenum(points,mty) in
      let METRIC_EQ_CONV =
        let th = metric_eq_prerule (SPEC fset_tm metric_eq_thm) in
        fun tm ->
          let xtm,ytm = dest_eq tm in
          let th0 = SPECL[xtm;ytm] th in
          let th1 = MP_CONV (CONJ1_CONV IN_CONV THENC IN_CONV) th0 in
          let tm1 = rand (concl th1) in
          let th2 = ONCE_DEPTH_CONV REFL_SYM_CONV tm1 in
          TRANS th1 th2 in
      let eq1 = map (MAXDIST_CONV fset_tm) (find_mdist mtm tm0)
      and eq2 = map METRIC_EQ_CONV (find_eq mty tm0) in
      let th1 = AUGMENT_MDISTS_POS_RULE (SUBS_CONV (eq1 @ eq2) tm0) in
      let tm1 = rand (concl th1) in
      prove_hyps (EQ_MP (SYM th0) (EQ_MP (SYM th1) (REAL_ARITH tm1))) in
    let SIMPLE_METRIC_ARITH tm =
      let th0 = (WEAK_CNF_CONV THENC CONJ_CANON_CONV) tm in
      let tml =
        try conjuncts (rand (concl th0))
        with Failure s -> failwith("conjuncts "^s) in
      let th1 =
        try end_itlist CONJ (map BASIC_METRIC_ARITH tml)
        with Failure s -> failwith("end_itlist "^s) in
      EQ_MP (SYM th0) th1 in
    let elim_exists tm =
      let points = find_points mtm tm in
      let rec try_points v tm ptl =
        if ptl = [] then fail () else
        let xtm = hd ptl in
        try EXISTS (mk_exists(v,tm),xtm) (elim_exists (vsubst [xtm,v] tm))
        with Failure _ -> try_points v tm (tl ptl)
      and elim_exists tm =
        try let v,bd = dest_exists tm in
            try_points v bd points
        with Failure _ -> SIMPLE_METRIC_ARITH tm in
      elim_exists tm in
    EQ_MP (SYM th0) (GENL avs (elim_exists bod));;

let METRIC_ARITH_TAC = CONV_TAC METRIC_ARITH;;

let ASM_METRIC_ARITH_TAC =
  REPEAT(FIRST_X_ASSUM(MP_TAC o check (not o is_forall o concl))) THEN
  METRIC_ARITH_TAC;;

(* ------------------------------------------------------------------------- *)
(* Compact sets.                                                             *)
(* ------------------------------------------------------------------------- *)

let compact_in = new_definition
  `!top s:A->bool.
     compact_in top s <=>
     s SUBSET topspace top /\
     (!U. (!u. u IN U ==> open_in top u) /\ s SUBSET UNIONS U
          ==> (?V. FINITE V /\ V SUBSET U /\ s SUBSET UNIONS V))`;;

let compact_space = new_definition
 `compact_space(top:A topology) <=> compact_in top (topspace top)`;;

let COMPACT_SPACE_ALT = prove
 (`!top:A topology.
        compact_space top <=>
        !U. (!u. u IN U ==> open_in top u) /\
            topspace top SUBSET UNIONS U
            ==> ?V. FINITE V /\ V SUBSET U /\ topspace top SUBSET UNIONS V`,
  REWRITE_TAC[compact_space; compact_in; SUBSET_REFL]);;

let COMPACT_SPACE = prove
 (`!top:A topology.
        compact_space top <=>
        !U. (!u. u IN U ==> open_in top u) /\
            UNIONS U = topspace top
            ==> ?V. FINITE V /\ V SUBSET U /\ UNIONS V = topspace top`,
  GEN_TAC THEN REWRITE_TAC[COMPACT_SPACE_ALT] THEN
  REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ; UNIONS_SUBSET] THEN
  AP_TERM_TAC THEN ABS_TAC THEN
  MESON_TAC[SUBSET; OPEN_IN_SUBSET]);;

let COMPACT_IN_ABSOLUTE = prove
 (`!top s:A->bool.
        compact_in (subtopology top s) s <=> compact_in top s`,
  REWRITE_TAC[compact_in] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER; SUBSET_REFL] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY; SET_RULE
   `(!x. x IN s ==> ?y. P y /\ x = f y) <=> s SUBSET IMAGE f {y | P y}`] THEN
  REWRITE_TAC[IMP_CONJ; FORALL_SUBSET_IMAGE] THEN
  REWRITE_TAC[EXISTS_FINITE_SUBSET_IMAGE] THEN
  REWRITE_TAC[GSYM SIMPLE_IMAGE; GSYM INTER_UNIONS] THEN
  REWRITE_TAC[SUBSET_INTER; SUBSET_REFL] THEN SET_TAC[]);;

let COMPACT_IN_SUBSPACE = prove
 (`!top s:A->bool.
        compact_in top s <=>
        s SUBSET topspace top /\ compact_space (subtopology top s)`,
  REWRITE_TAC[compact_space; COMPACT_IN_ABSOLUTE; TOPSPACE_SUBTOPOLOGY] THEN
  ONCE_REWRITE_TAC[TAUT `p /\ q <=> ~(p ==> ~q)`] THEN
  SIMP_TAC[SET_RULE `s SUBSET t ==> t INTER s = s`] THEN
  REWRITE_TAC[COMPACT_IN_ABSOLUTE] THEN
  REWRITE_TAC[TAUT `(p <=> ~(q ==> ~p)) <=> (p ==> q)`] THEN
  SIMP_TAC[compact_in]);;

let COMPACT_SPACE_SUBTOPOLOGY = prove
 (`!top s:A->bool. compact_in top s ==> compact_space (subtopology top s)`,
  SIMP_TAC[COMPACT_IN_SUBSPACE]);;

let COMPACT_IN_SUBTOPOLOGY = prove
 (`!top s t:A->bool.
        compact_in (subtopology top s) t <=> compact_in top t /\ t SUBSET s`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[COMPACT_IN_SUBSPACE; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER] THEN
  ASM_CASES_TAC `(t:A->bool) SUBSET s` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[SET_RULE `t SUBSET s ==> s INTER t = t`]);;

let COMPACT_IN_SUBSET_TOPSPACE = prove
 (`!top s:A->bool. compact_in top s ==> s SUBSET topspace top`,
  SIMP_TAC[compact_in]);;

let COMPACT_IN_CONTRACTIVE = prove
 (`!top top':A topology.
        topspace top' = topspace top /\
        (!u. open_in top u ==> open_in top' u)
        ==> !s. compact_in top' s ==> compact_in top s`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN GEN_TAC THEN
  REWRITE_TAC[compact_in] THEN MATCH_MP_TAC MONO_AND THEN CONJ_TAC THENL
   [ASM SET_TAC[]; MATCH_MP_TAC MONO_FORALL THEN ASM SET_TAC[]]);;

let FINITE_IMP_COMPACT_IN = prove
 (`!top s:A->bool. s SUBSET topspace top /\ FINITE s ==> compact_in top s`,
  SIMP_TAC[compact_in] THEN INTRO_TAC "!top s; sub fin; !U; U s" THEN
  EXISTS_TAC `IMAGE (\x:A. @u. u IN U /\ x IN u) s` THEN
  HYP SIMP_TAC "fin" [FINITE_IMAGE] THEN ASM SET_TAC []);;

let COMPACT_IN_EMPTY = prove
 (`!top:A topology. compact_in top {}`,
  GEN_TAC THEN MATCH_MP_TAC FINITE_IMP_COMPACT_IN THEN
  REWRITE_TAC[FINITE_EMPTY; EMPTY_SUBSET]);;

let COMPACT_SPACE_TOPSPACE_EMPTY = prove
 (`!top:A topology. topspace top = {} ==> compact_space top`,
  MESON_TAC[SUBTOPOLOGY_TOPSPACE; COMPACT_IN_EMPTY; compact_space]);;

let FINITE_IMP_COMPACT_IN_EQ = prove
 (`!top s:A->bool.
        FINITE s ==> (compact_in top s <=> s SUBSET topspace top)`,
  MESON_TAC[COMPACT_IN_SUBSET_TOPSPACE; FINITE_IMP_COMPACT_IN]);;

let COMPACT_IN_SING = prove
 (`!top a:A. compact_in top {a} <=> a IN topspace top`,
  SIMP_TAC[FINITE_IMP_COMPACT_IN_EQ; FINITE_SING; SING_SUBSET]);;

let CLOSED_COMPACT_IN = prove
 (`!top k c:A->bool. compact_in top k /\ c SUBSET k /\ closed_in top c
                     ==> compact_in top c`,
  INTRO_TAC "! *; cpt sub cl" THEN REWRITE_TAC[compact_in] THEN CONJ_TAC THENL
  [HYP SET_TAC "sub cpt" [compact_in]; INTRO_TAC "!U; U c"] THEN
  HYP_TAC "cpt: ksub cpt" (REWRITE_RULE[compact_in]) THEN
  REMOVE_THEN "cpt" (MP_TAC o
    SPEC `(topspace top DIFF c:A->bool) INSERT U`) THEN
  ANTS_TAC THENL
  [CONJ_TAC THENL
   [CUT_TAC `open_in top (topspace top DIFF c:A->bool)` THENL
    [HYP SET_TAC "U" [IN_DIFF];
     HYP SIMP_TAC "cl" [OPEN_IN_DIFF; OPEN_IN_TOPSPACE]];
    HYP_TAC "cl: c' cl" (REWRITE_RULE[closed_in]) THEN
    REWRITE_TAC[SUBSET; IN_INSERT; IN_DIFF; IN_UNIONS] THEN
    INTRO_TAC "!x; x" THEN ASM_CASES_TAC `x:A IN c` THEN
    POP_ASSUM (LABEL_TAC "x'") THENL
    [HYP SET_TAC "c x'" [];
     EXISTS_TAC `topspace top DIFF c:A->bool` THEN
     ASM_REWRITE_TAC[] THEN ASM SET_TAC []]];
   INTRO_TAC "@V. fin v k" THEN
   EXISTS_TAC `V DELETE (topspace top DIFF c:A->bool)` THEN
   ASM_REWRITE_TAC[FINITE_DELETE] THEN
   CONJ_TAC THENL [ASM SET_TAC []; ALL_TAC] THEN
   REWRITE_TAC[SUBSET; IN_UNIONS; IN_DELETE] THEN ASM SET_TAC []]);;

let CLOSED_IN_COMPACT_SPACE = prove
 (`!top s:A->bool.
        compact_space top /\ closed_in top s ==> compact_in top s`,
  REWRITE_TAC[compact_space] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC CLOSED_COMPACT_IN THEN EXISTS_TAC `topspace top:A->bool` THEN
  ASM_MESON_TAC[CLOSED_IN_SUBSET]);;

let COMPACT_INTER_CLOSED_IN = prove
 (`!top s t:A->bool.
        compact_in top s /\ closed_in top t ==> compact_in top (s INTER t)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `compact_in (subtopology top s) (s INTER t:A->bool)`
  MP_TAC THENL
   [MATCH_MP_TAC CLOSED_IN_COMPACT_SPACE THEN
    CONJ_TAC THENL [ASM_MESON_TAC[COMPACT_IN_SUBSPACE]; ALL_TAC] THEN
    MATCH_MP_TAC CLOSED_IN_SUBTOPOLOGY_INTER_CLOSED_IN THEN
    ASM_REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY_REFL] THEN
    ASM_MESON_TAC[compact_in];
    REWRITE_TAC[COMPACT_IN_SUBTOPOLOGY; INTER_SUBSET]]);;

let CLOSED_INTER_COMPACT_IN = prove
 (`!top s t:A->bool.
        closed_in top s /\ compact_in top t ==> compact_in top (s INTER t)`,
  ONCE_REWRITE_TAC[INTER_COMM] THEN SIMP_TAC[COMPACT_INTER_CLOSED_IN]);;

let COMPACT_IN_UNION = prove
 (`!top s t:A->bool.
        compact_in top s /\ compact_in top t ==> compact_in top (s UNION t)`,
  REPEAT GEN_TAC THEN SIMP_TAC[compact_in; UNION_SUBSET] THEN
  DISCH_THEN(CONJUNCTS_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  REWRITE_TAC[IMP_IMP; AND_FORALL_THM] THEN MATCH_MP_TAC MONO_FORALL THEN
  X_GEN_TAC `u:(A->bool)->bool` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[] THEN DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_THEN `v:(A->bool)->bool` STRIP_ASSUME_TAC)
   (X_CHOOSE_THEN `w:(A->bool)->bool` STRIP_ASSUME_TAC)) THEN
  EXISTS_TAC `v UNION w:(A->bool)->bool` THEN
  ASM_REWRITE_TAC[FINITE_UNION; UNIONS_UNION] THEN
  ASM SET_TAC[]);;

let COMPACT_IN_UNIONS = prove
 (`!top f:(A->bool)->bool.
        FINITE f /\ (!s. s IN f ==> compact_in top s)
        ==> compact_in top (UNIONS f)`,
  GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[UNIONS_0; COMPACT_IN_EMPTY; IN_INSERT; UNIONS_INSERT] THEN
  MESON_TAC[COMPACT_IN_UNION]);;

let COMPACT_IN_IMP_MBOUNDED = prove
 (`!m s:A->bool. compact_in (mtopology m) s ==> mbounded m s`,
  REWRITE_TAC[compact_in; TOPSPACE_MTOPOLOGY; mbounded] THEN
  INTRO_TAC "!m s; s cpt" THEN ASM_CASES_TAC `s:A->bool = {}` THENL
  [ASM_REWRITE_TAC[EMPTY_SUBSET];
   POP_ASSUM (DESTRUCT_TAC "@a. a" o REWRITE_RULE[GSYM MEMBER_NOT_EMPTY])] THEN
  CLAIM_TAC "a'" `a:A IN mspace m` THENL [ASM SET_TAC[]; EXISTS_TAC `a:A`] THEN
  REMOVE_THEN "cpt" (MP_TAC o SPEC `{mball m (a:A,&n) | n IN (:num)}`) THEN
  ANTS_TAC THENL
  [CONJ_TAC THENL
   [REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN GEN_TAC THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[IN; OPEN_IN_MBALL];
    REWRITE_TAC[SUBSET; IN_UNIONS; IN_ELIM_THM; IN_UNIV] THEN
    INTRO_TAC "!x; x" THEN CLAIM_TAC "@n. n" `?n. mdist m (a:A,x) <= &n` THENL
    [MATCH_ACCEPT_TAC REAL_ARCH_SIMPLE;
     EXISTS_TAC `mball m (a:A,&n + &1)`] THEN
    CONJ_TAC THENL
    [REWRITE_TAC[REAL_OF_NUM_ADD; IN_UNIV] THEN MESON_TAC[];
     ASM_SIMP_TAC[IN_MBALL; REAL_ARITH `!x. x <= &n ==> x < &n + &1`] THEN
     ASM SET_TAC []]];
   ALL_TAC] THEN
  INTRO_TAC "@V. fin V cov" THEN
  CLAIM_TAC "@k. k" `?k. !v. v IN V ==> v = mball m (a:A,&(k v))` THENL
  [REWRITE_TAC[GSYM SKOLEM_THM; RIGHT_EXISTS_IMP_THM] THEN ASM SET_TAC [];
   ALL_TAC] THEN
  CLAIM_TAC "kfin" `FINITE (IMAGE (k:(A->bool)->num) V)` THENL
  [HYP SIMP_TAC "fin" [FINITE_IMAGE];
   HYP_TAC "kfin: @n. n" (REWRITE_RULE[num_FINITE])] THEN EXISTS_TAC `&n` THEN
  TRANS_TAC SUBSET_TRANS `UNIONS (V:(A->bool)->bool)` THEN
  HYP SIMP_TAC "cov" [UNIONS_SUBSET] THEN INTRO_TAC "![v]; v" THEN
  USE_THEN "v" (HYP_TAC "k" o C MATCH_MP) THEN REMOVE_THEN "k" SUBST1_TAC THEN
  TRANS_TAC SUBSET_TRANS `mball m (a:A,&n)` THEN
  REWRITE_TAC[MBALL_SUBSET_MCBALL] THEN MATCH_MP_TAC MBALL_SUBSET THEN
  ASM_SIMP_TAC[MDIST_REFL; REAL_ADD_LID; REAL_OF_NUM_LE] THEN
  HYP SET_TAC "n v" []);;

let COMPACT_IN_SUBTOPOLOGY_IMP_COMPACT = prove
 (`!top k s:A->bool.
     compact_in (subtopology top s) k ==> compact_in top k`,
  REWRITE_TAC[compact_in; TOPSPACE_SUBTOPOLOGY; SUBSET_INTER] THEN
  INTRO_TAC "!top k s; (k sub) cpt" THEN ASM_REWRITE_TAC[] THEN
  INTRO_TAC "!U; open cover" THEN
  HYP_TAC "cpt: +" (SPEC `{u INTER s | u | u:A->bool IN U}`) THEN
  ANTS_TAC THENL
  [ASM_REWRITE_TAC[GSYM INTER_UNIONS; SUBSET_INTER] THEN
   REWRITE_TAC[IN_ELIM_THM; OPEN_IN_SUBTOPOLOGY] THEN
   INTRO_TAC "!u; @v. v ueq" THEN
   REMOVE_THEN "ueq" SUBST_VAR_TAC THEN EXISTS_TAC `v:A->bool` THEN
   REMOVE_THEN "v" (HYP_TAC "open" o C MATCH_MP) THEN ASM_REWRITE_TAC[];
   ALL_TAC] THEN
  INTRO_TAC "@V. fin V k" THEN EXISTS_TAC `IMAGE (\v:A->bool.
    if v IN V then @u. u IN U /\ v = u INTER s else {}) V` THEN
  ASM_SIMP_TAC[FINITE_IMAGE] THEN
  CONJ_TAC THENL
  [REWRITE_TAC[SUBSET; IN_IMAGE] THEN INTRO_TAC "![u]; @v. ueq v" THEN
   REMOVE_THEN "ueq" SUBST_VAR_TAC THEN ASM_REWRITE_TAC[] THEN
   HYP_TAC "V" (REWRITE_RULE[SUBSET; IN_ELIM_THM]) THEN
   REMOVE_THEN "v" (HYP_TAC "V: @u. u veq" o C MATCH_MP) THEN
   REMOVE_THEN "veq" SUBST_VAR_TAC THEN HYP MESON_TAC "u" [];
   ALL_TAC] THEN
  REWRITE_TAC[SUBSET; IN_UNIONS; IN_IMAGE] THEN INTRO_TAC "!x; x" THEN
  HYP_TAC "k" (REWRITE_RULE[SUBSET; IN_UNIONS]) THEN
  USE_THEN "x" (HYP_TAC "k: @v. v xINv" o C MATCH_MP) THEN
  LABEL_ABBREV_TAC `u:A->bool = @u. u IN U /\ v = u INTER s` THEN
  CLAIM_TAC "u' veq" `u:A->bool IN U /\ v = u INTER s` THENL
  [REMOVE_THEN "u" SUBST_VAR_TAC THEN
   CUT_TAC `?u:A->bool. u IN U /\ v = u INTER s` THENL
   [MESON_TAC[]; ALL_TAC] THEN
   HYP_TAC "V" (REWRITE_RULE[SUBSET; IN_ELIM_THM]) THEN
   USE_THEN "v" (HYP_TAC "V" o C MATCH_MP) THEN
   REMOVE_THEN "V" MATCH_ACCEPT_TAC;
   EXISTS_TAC `u:A->bool` THEN CONJ_TAC THENL
   [EXISTS_TAC `v:A->bool` THEN ASM_REWRITE_TAC[];
    HYP SET_TAC "veq xINv" []]]);;

let COMPACT_IMP_COMPACT_IN_SUBTOPOLOGY = prove
 (`!top k s:A->bool.
     compact_in top k /\ k SUBSET s ==> compact_in (subtopology top s) k`,
   INTRO_TAC "!top k s; cpt sub" THEN
   ASM_SIMP_TAC[compact_in; TOPSPACE_SUBTOPOLOGY; SUBSET_INTER;
     COMPACT_IN_SUBSET_TOPSPACE] THEN
   INTRO_TAC "!U; open cover" THEN
   HYP_TAC "cpt: sub' cpt" (REWRITE_RULE[compact_in]) THEN
   (HYP_TAC "cpt: +" o SPEC)
     `{v:A->bool | v | open_in top v /\ ?u. u IN U /\ u = v INTER s}` THEN
   ANTS_TAC THENL
   [SIMP_TAC[IN_ELIM_THM] THEN TRANS_TAC SUBSET_TRANS `UNIONS U:A->bool` THEN
    ASM_REWRITE_TAC[] THEN MATCH_MP_TAC UNIONS_MONO THEN
    INTRO_TAC "![u]; u" THEN USE_THEN "u" (HYP_TAC "open" o C MATCH_MP) THEN
    HYP_TAC "open: @v. v ueq" (REWRITE_RULE[OPEN_IN_SUBTOPOLOGY]) THEN
    EXISTS_TAC `v:A->bool` THEN REMOVE_THEN "ueq" SUBST_VAR_TAC THEN
    ASM_REWRITE_TAC[IN_ELIM_THM] THEN CONJ_TAC THENL
    [EXISTS_TAC `v INTER s:A->bool` THEN ASM_REWRITE_TAC[]; SET_TAC[]];
    ALL_TAC] THEN
   INTRO_TAC "@V. fin open cover" THEN
   EXISTS_TAC `{v INTER s | v | v:A->bool IN V}` THEN CONJ_TAC THENL
   [(SUBST1_TAC o SET_RULE)
      `{v INTER s | v | v:A->bool IN V} = IMAGE (\v. v INTER s) V` THEN
    ASM_SIMP_TAC[FINITE_IMAGE];
    ALL_TAC] THEN
   ASM_REWRITE_TAC[GSYM INTER_UNIONS; SUBSET_INTER] THEN
   REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN INTRO_TAC "![u]; @v. v ueq" THEN
   REMOVE_THEN "ueq" SUBST_VAR_TAC THEN
   HYP_TAC "open" (REWRITE_RULE[SUBSET; IN_ELIM_THM]) THEN
   REMOVE_THEN "v" (HYP_TAC "open: v @u. u ueq" o C MATCH_MP) THEN
   REMOVE_THEN "ueq" SUBST_VAR_TAC THEN ASM_REWRITE_TAC[]);;

let COMPACT_SPACE_FIP = prove
 (`!top:A topology.
        compact_space top <=>
        !f. (!c. c IN f ==> closed_in top c) /\
            (!f'. FINITE f' /\ f' SUBSET f ==> ~(INTERS f' = {}))
           ==> ~(INTERS f = {})`,
  GEN_TAC THEN ASM_CASES_TAC `topspace top:A->bool = {}` THENL
   [ASM_SIMP_TAC[compact_space; CLOSED_IN_TOPSPACE_EMPTY] THEN
    REWRITE_TAC[COMPACT_IN_EMPTY; SET_RULE
     `(!x. x IN s ==> x = a) <=> s = {} \/ s = {a}`] THEN
    X_GEN_TAC `f:(A->bool)->bool` THEN
    ASM_CASES_TAC `f:(A->bool)->bool = {}` THEN
    ASM_REWRITE_TAC[INTERS_0; UNIV_NOT_EMPTY] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
     (MP_TAC o SPEC `f:(A->bool)->bool`)) THEN
    ASM_REWRITE_TAC[INTERS_1; FINITE_SING; SUBSET_REFL];
    ALL_TAC] THEN
  REWRITE_TAC[COMPACT_SPACE_ALT] THEN EQ_TAC THEN
  INTRO_TAC "0" THEN X_GEN_TAC `U:(A->bool)->bool` THEN STRIP_TAC THEN
  REMOVE_THEN "0" (MP_TAC o SPEC
   `IMAGE (\s:A->bool. topspace top DIFF s) U`) THEN
  ASM_SIMP_TAC[FORALL_IN_IMAGE; CLOSED_IN_DIFF; OPEN_IN_DIFF;
               OPEN_IN_TOPSPACE; CLOSED_IN_TOPSPACE] THEN
  REWRITE_TAC[FORALL_FINITE_SUBSET_IMAGE; EXISTS_FINITE_SUBSET_IMAGE] THEN
  GEN_REWRITE_TAC LAND_CONV [GSYM CONTRAPOS_THM] THENL
   [REWRITE_TAC[GSYM SIMPLE_IMAGE; GSYM DIFF_INTERS] THEN
    ANTS_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
    DISCH_THEN(X_CHOOSE_THEN `V:(A->bool)->bool` MP_TAC) THEN
    REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    ASM_CASES_TAC `V:(A->bool)->bool = {}` THEN
    ASM_REWRITE_TAC[INTERS_0; UNIV_NOT_EMPTY] THENL
     [ASM SET_TAC[]; ALL_TAC] THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `V:(A->bool)->bool`) THEN
    ASM_REWRITE_TAC[] THEN MATCH_MP_TAC(SET_RULE
    `~(u = {}) /\ s SUBSET u ==> ~(s = {}) ==> ~(u SUBSET u DIFF s)`) THEN
    ASM_REWRITE_TAC[] THEN MATCH_MP_TAC INTERS_SUBSET THEN
    ASM_MESON_TAC[SUBSET; CLOSED_IN_SUBSET];
    ASM_CASES_TAC `U:(A->bool)->bool = {}` THENL
     [ASM_MESON_TAC[UNIONS_0; SUBSET_EMPTY]; ALL_TAC] THEN
    UNDISCH_TAC `(topspace top:A->bool) SUBSET UNIONS U` THEN
    REWRITE_TAC[UNIONS_INTERS] THEN
    ONCE_REWRITE_TAC[SET_RULE
     `u SUBSET UNIV DIFF t <=> u SUBSET u DIFF u INTER u INTER t`] THEN
    ONCE_REWRITE_TAC[GSYM INTERS_INSERT] THEN
    REWRITE_TAC[INTER_INTERS; NOT_INSERT_EMPTY] THEN
    REWRITE_TAC[SIMPLE_IMAGE; INTERS_INSERT; IMAGE_CLAUSES] THEN
    REWRITE_TAC[SET_RULE `u DIFF (u INTER u) INTER t = u DIFF t`] THEN
    REWRITE_TAC[GSYM IMAGE_o; o_DEF] THEN
    REWRITE_TAC[SET_RULE `u INTER (UNIV DIFF s) = u DIFF s`] THEN
    DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
     `u SUBSET u DIFF s ==> u = {} \/ (s SUBSET u ==> s = {})`)) THEN
    ASM_REWRITE_TAC[] THEN ANTS_TAC THENL
     [MATCH_MP_TAC INTERS_SUBSET THEN
      ASM_REWRITE_TAC[IMAGE_EQ_EMPTY; FORALL_IN_IMAGE] THEN SET_TAC[];
      DISCH_TAC THEN ASM_REWRITE_TAC[NOT_FORALL_THM]] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `V:(A->bool)->bool` THEN
    SIMP_TAC[NOT_IMP; DIFF_EMPTY; SUBSET_REFL]]);;

let COMPACT_IN_FIP = prove
 (`!top s:A->bool.
        compact_in top s <=>
        s SUBSET topspace top /\
        !f. (!c. c IN f ==> closed_in top c) /\
            (!f'. FINITE f' /\ f' SUBSET f ==> ~(s INTER INTERS f' = {}))
            ==> ~(s INTER INTERS f = {})`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `s:A->bool = {}` THENL
   [ASM_REWRITE_TAC[COMPACT_IN_EMPTY; INTER_EMPTY; EMPTY_SUBSET] THEN
    GEN_TAC THEN
    DISCH_THEN(MP_TAC o SPEC `{}:(A->bool)->bool` o CONJUNCT2) THEN
    REWRITE_TAC[FINITE_EMPTY; EMPTY_SUBSET];
    ALL_TAC] THEN
  REWRITE_TAC[COMPACT_IN_SUBSPACE; COMPACT_SPACE_FIP] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THEN
  ASM_REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY_ALT; GSYM SUBSET; IMP_CONJ] THEN
  ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN REWRITE_TAC[FORALL_SUBSET_IMAGE] THEN
  REWRITE_TAC[IMP_IMP; FORALL_FINITE_SUBSET_IMAGE] THEN
  REWRITE_TAC[INTER_INTERS; GSYM SIMPLE_IMAGE] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `f:(A->bool)->bool` THEN
  ASM_CASES_TAC `f:(A->bool)->bool = {}` THEN
  ASM_SIMP_TAC[SUBSET_EMPTY] THENL
   [REWRITE_TAC[SET_RULE `{f x | x IN {}} = {}`; INTERS_0; UNIV_NOT_EMPTY] THEN
    DISCH_THEN(MATCH_MP_TAC o CONJUNCT2) THEN MESON_TAC[FINITE_EMPTY];
    REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN
    ASM_CASES_TAC `!c:A->bool. c IN f ==> closed_in top c` THEN
    ASM_REWRITE_TAC[] THEN
    ASM_CASES_TAC `INTERS {s INTER t:A->bool | t IN f} = {}` THEN
    ASM_REWRITE_TAC[] THEN AP_TERM_TAC THEN
    AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
    X_GEN_TAC `g:(A->bool)->bool` THEN
    ASM_CASES_TAC `g:(A->bool)->bool = {}` THEN
    ASM_SIMP_TAC[SET_RULE `{f x | x IN {}} = {}`; INTERS_0; UNIV_NOT_EMPTY]]);;

let COMPACT_SPACE_IMP_NEST = prove
 (`!top c:num->A->bool.
        compact_space top /\
        (!n. closed_in top (c n)) /\
        (!n. ~(c n = {})) /\
        (!m n. m <= n ==> c n SUBSET c m)
        ==> ~(INTERS {c n | n IN (:num)} = {})`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [COMPACT_SPACE_FIP]) THEN
  DISCH_THEN(MP_TAC o SPEC
   `IMAGE (\n. INTERS {(c:num->A->bool) m | m <= n}) (:num)`) THEN
  REWRITE_TAC[FORALL_FINITE_SUBSET_IMAGE; SUBSET_UNIV] THEN ANTS_TAC THENL
   [CONJ_TAC THENL
     [REWRITE_TAC[FORALL_IN_IMAGE; IN_UNIV] THEN GEN_TAC THEN
      MATCH_MP_TAC CLOSED_IN_INTERS THEN
      ASM_REWRITE_TAC[FORALL_IN_GSPEC; GSYM MEMBER_NOT_EMPTY] THEN
      MATCH_MP_TAC(SET_RULE `(?x. P x) ==> ?x. x IN {f a | P a}`) THEN
      MESON_TAC[LE_0];
      X_GEN_TAC `k:num->bool` THEN
      DISCH_THEN(MP_TAC o ISPEC `\n:num. n` o
        MATCH_MP UPPER_BOUND_FINITE_SET) THEN
      REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `n:num` THEN
      DISCH_TAC THEN MATCH_MP_TAC(SET_RULE
       `!t. ~(t = {}) /\ t SUBSET s ==> ~(s = {})`) THEN
      EXISTS_TAC `(c:num->A->bool) n` THEN
      ASM_SIMP_TAC[SUBSET_INTERS; FORALL_IN_IMAGE; FORALL_IN_GSPEC] THEN
      ASM SET_TAC[]];
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN MATCH_MP_TAC MONO_EXISTS THEN
    REWRITE_TAC[INTERS_GSPEC; INTERS_IMAGE; IN_UNIV; IN_ELIM_THM] THEN
    MESON_TAC[LE_REFL]]);;

let COMPACT_IN_DISCRETE_TOPOLOGY = prove
 (`!u s:A->bool.
        compact_in (discrete_topology u) s <=> s SUBSET u /\ FINITE s`,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC[FINITE_IMP_COMPACT_IN; TOPSPACE_DISCRETE_TOPOLOGY] THEN
  REWRITE_TAC[compact_in; TOPSPACE_DISCRETE_TOPOLOGY] THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (\x:A. {x}) u`) THEN
  REWRITE_TAC[FORALL_IN_IMAGE; OPEN_IN_DISCRETE_TOPOLOGY; SING_SUBSET] THEN
  REWRITE_TAC[EXISTS_FINITE_SUBSET_IMAGE] THEN
  ASM_REWRITE_TAC[UNIONS_IMAGE; SET_RULE `(?x. x IN u /\ y IN {x}) <=> y IN u`;
                  SET_RULE `{x | x IN s} = s`] THEN
  MESON_TAC[FINITE_SUBSET]);;

let COMPACT_SPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. compact_space(discrete_topology u) <=> FINITE u`,
  REWRITE_TAC[compact_space; COMPACT_IN_DISCRETE_TOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_DISCRETE_TOPOLOGY; SUBSET_REFL]);;

let COMPACT_SPACE_IMP_BOLZANO_WEIERSTRASS = prove
 (`!top s:A->bool.
        compact_space top /\ INFINITE s /\ s SUBSET topspace top
        ==> ~(top derived_set_of s = {})`,
  REPEAT STRIP_TAC THEN
  UNDISCH_TAC `INFINITE(s:A->bool)` THEN REWRITE_TAC[INFINITE] THEN
  SUBGOAL_THEN `compact_in top (s:A->bool)` MP_TAC THENL
   [MATCH_MP_TAC CLOSED_IN_COMPACT_SPACE THEN ASM_REWRITE_TAC[] THEN
    ASM_REWRITE_TAC[CLOSED_IN_CONTAINS_DERIVED_SET; NOT_IN_EMPTY] THEN
    ASM SET_TAC[];
    ASM_SIMP_TAC[COMPACT_IN_SUBSPACE; SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY;
                 INTER_EMPTY; COMPACT_SPACE_DISCRETE_TOPOLOGY]]);;

let COMPACT_IN_IMP_BOLZANO_WEIERSTRASS = prove
 (`!top s t:A->bool.
        compact_in top s /\ INFINITE t /\ t SUBSET s
        ==> ~(s INTER top derived_set_of t = {})`,
  REWRITE_TAC[COMPACT_IN_SUBSPACE] THEN REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`subtopology top (s:A->bool)`; `t:A->bool`]
        COMPACT_SPACE_IMP_BOLZANO_WEIERSTRASS) THEN
  ASM_REWRITE_TAC[DERIVED_SET_OF_SUBTOPOLOGY; TOPSPACE_SUBTOPOLOGY] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u ==> u INTER s = s`]);;

let COMPACT_CLOSURE_OF_IMP_BOLZANO_WEIERSTRASS = prove
 (`!top s t:A->bool.
        compact_in top (top closure_of s) /\
        INFINITE t /\ t SUBSET s /\ t SUBSET topspace top
        ==> ~(top derived_set_of t = {})`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `t:A->bool` o MATCH_MP (REWRITE_RULE[IMP_CONJ]
        COMPACT_IN_IMP_BOLZANO_WEIERSTRASS)) THEN
  ASM_REWRITE_TAC[INTER_EMPTY] THEN
  TRANS_TAC SUBSET_TRANS `top closure_of t:A->bool` THEN
  ASM_SIMP_TAC[CLOSURE_OF_MONO; CLOSURE_OF_SUBSET]);;

let DISCRETE_COMPACT_IN_EQ_FINITE = prove
 (`!top s:A->bool.
        s INTER top derived_set_of s = {}
        ==> (compact_in top s <=> s SUBSET topspace top /\ FINITE s)`,
  REPEAT STRIP_TAC THEN
  EQ_TAC THENL [ALL_TAC; MESON_TAC[FINITE_IMP_COMPACT_IN]] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THENL
   [ASM_REWRITE_TAC[]; ASM_MESON_TAC[compact_in]] THEN
  GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN
  REWRITE_TAC[GSYM INFINITE] THEN
  ASM_MESON_TAC[COMPACT_IN_IMP_BOLZANO_WEIERSTRASS; SUBSET_REFL]);;

let DISCRETE_COMPACT_SPACE_EQ_FINITE = prove
 (`!top:A topology.
        top derived_set_of (topspace top) = {}
        ==> (compact_space top <=> FINITE(topspace top))`,
  SIMP_TAC[compact_space; DISCRETE_COMPACT_IN_EQ_FINITE; INTER_EMPTY] THEN
  REWRITE_TAC[SUBSET_REFL]);;

let IMAGE_COMPACT_IN = prove
 (`!top top' (f:A->B) s.
     compact_in top s /\ continuous_map (top,top')  f
     ==> compact_in top' (IMAGE f s)`,
  INTRO_TAC "!top top' f s; cpt cont" THEN REWRITE_TAC[compact_in] THEN
  CONJ_TAC THENL
  [TRANS_TAC SUBSET_TRANS `IMAGE (f:A->B) (topspace top)` THEN
   ASM_SIMP_TAC[CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE; IMAGE_SUBSET;
     COMPACT_IN_SUBSET_TOPSPACE];
   INTRO_TAC "!U; U img"] THEN
  HYP_TAC "cpt : sub cpt" (REWRITE_RULE[compact_in]) THEN
  REMOVE_THEN "cpt" (MP_TAC o
    SPEC `{{x | x | x IN topspace top /\ (f:A->B) x IN u} | u | u IN U}`) THEN
  ANTS_TAC THENL
  [REWRITE_TAC[SUBSET; IN_ELIM_THM; IN_UNIONS] THEN
   INTRO_TAC "{![w]; @v. v eq & !x; x}" THENL
   [REMOVE_THEN "eq" SUBST1_TAC THEN
    HYP_TAC "cont : wd cont" (REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[];
    REMOVE_THEN "img" (MP_TAC o SPEC `f (x:A):B` o REWRITE_RULE[SUBSET]) THEN
    ANTS_TAC THENL [HYP SET_TAC "x" []; REWRITE_TAC[IN_UNIONS]] THEN
    INTRO_TAC "@t. t fx" THEN
    EXISTS_TAC `{x:A | x IN topspace top /\ f x:B IN t}` THEN ASM SET_TAC[]];
   ALL_TAC] THEN
  INTRO_TAC "@V. fin sub s" THEN
  CLAIM_TAC "@u. u"
    `?u. !v. v IN V ==> u v IN U /\
                        v = {x:A | x IN topspace top /\ f x:B IN u v}` THENL
  [REWRITE_TAC[GSYM SKOLEM_THM; RIGHT_EXISTS_IMP_THM] THEN
   INTRO_TAC "!v; v" THEN
   HYP_TAC "sub" (REWRITE_RULE[SUBSET; IN_ELIM_THM]) THEN
   REMOVE_THEN "v" (HYP_TAC "sub: @u. u eq" o C MATCH_MP) THEN
   EXISTS_TAC `u:B->bool` THEN ASM_REWRITE_TAC[];
   ALL_TAC] THEN
  EXISTS_TAC `IMAGE (u:(A->bool)->(B->bool)) V` THEN CONJ_TAC THENL
  [HYP SIMP_TAC "fin" [FINITE_IMAGE]; ASM SET_TAC []]);;

let HOMEOMORPHIC_COMPACT_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (compact_space top <=> compact_space top')`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[homeomorphic_space; homeomorphic_maps; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN STRIP_TAC THEN
  REWRITE_TAC[compact_space] THEN EQ_TAC THEN DISCH_TAC THENL
   [SUBGOAL_THEN `topspace top' = IMAGE (f:A->B) (topspace top)`
    SUBST1_TAC THENL [ALL_TAC; ASM_MESON_TAC[IMAGE_COMPACT_IN]];
    SUBGOAL_THEN `topspace top = IMAGE (g:B->A) (topspace top')`
    SUBST1_TAC THENL [ALL_TAC; ASM_MESON_TAC[IMAGE_COMPACT_IN]]] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Separated sets.                                                           *)
(* ------------------------------------------------------------------------- *)

let SEPARATION_CLOSED_IN_UNION_GEN = prove
 (`!top s t:A->bool.
        s SUBSET topspace top /\ t SUBSET topspace top
        ==> (s INTER top closure_of t = {} /\ t INTER top closure_of s = {} <=>
             DISJOINT s t /\
             closed_in (subtopology top (s UNION t)) s /\
             closed_in (subtopology top (s UNION t)) t)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CLOSED_IN_INTER_CLOSURE_OF] THEN
  MP_TAC(ISPECL [`top:A topology`; `s:A->bool`] CLOSURE_OF_SUBSET) THEN
  MP_TAC(ISPECL [`top:A topology`; `t:A->bool`] CLOSURE_OF_SUBSET) THEN
  SET_TAC[]);;

let SEPARATION_OPEN_IN_UNION_GEN = prove
 (`!top s t:A->bool.
        s SUBSET topspace top /\ t SUBSET topspace top
        ==> (s INTER top closure_of t = {} /\ t INTER top closure_of s = {} <=>
             DISJOINT s t /\
             open_in (subtopology top (s UNION t)) s /\
             open_in (subtopology top (s UNION t)) t)`,
  REPEAT STRIP_TAC THEN
  REWRITE_TAC[OPEN_IN_CLOSED_IN_EQ] THEN
  ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER; SUBSET_UNION] THEN
  ASM_SIMP_TAC[SEPARATION_CLOSED_IN_UNION_GEN] THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
  DISCH_TAC THEN GEN_REWRITE_TAC RAND_CONV[CONJ_SYM] THEN BINOP_TAC THEN
  AP_TERM_TAC THEN ASM SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Connected topological spaces.                                             *)
(* ------------------------------------------------------------------------- *)

let connected_space = new_definition
  `connected_space(top:A topology) <=>
        ~(?e1 e2. open_in top e1 /\ open_in top e2 /\
                  topspace top SUBSET e1 UNION e2 /\ e1 INTER e2 = {} /\
                  ~(e1 = {}) /\ ~(e2 = {}))`;;

let connected_in = new_definition
 `connected_in top s <=>
  s SUBSET topspace top /\ connected_space (subtopology top s)`;;

let CONNECTED_IN_SUBSET_TOPSPACE = prove
 (`!top s:A->bool. connected_in top s ==> s SUBSET topspace top`,
  SIMP_TAC[connected_in]);;

let CONNECTED_IN_TOPSPACE = prove
 (`!top:A topology. connected_in top (topspace top) <=> connected_space top`,
  REWRITE_TAC[connected_in; SUBSET_REFL; SUBTOPOLOGY_TOPSPACE]);;

let CONNECTED_SPACE_SUBTOPOLOGY = prove
 (`!top s:A->bool.
        connected_in top s ==> connected_space (subtopology top s)`,
  SIMP_TAC[connected_in]);;

let CONNECTED_IN_SUBTOPOLOGY = prove
 (`!top s t:A->bool.
      connected_in (subtopology top s) t <=> connected_in top t /\ t SUBSET s`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[connected_in; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER] THEN
  ASM_CASES_TAC `(t:A->bool) SUBSET s` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[SET_RULE `t SUBSET s ==> s INTER t = t`]);;

let CONNECTED_SPACE_EQ = prove
 (`!top:A topology.
        connected_space(top:A topology) <=>
        ~(?e1 e2. open_in top e1 /\ open_in top e2 /\
                  e1 UNION e2 = topspace top /\ e1 INTER e2 = {} /\
                  ~(e1 = {}) /\ ~(e2 = {}))`,
  REWRITE_TAC[SET_RULE
   `s UNION t = u <=> u SUBSET s UNION t /\ s SUBSET u /\ t SUBSET u`] THEN
  REWRITE_TAC[connected_space] THEN MESON_TAC[OPEN_IN_SUBSET]);;

let CONNECTED_SPACE_CLOSED_IN = prove
 (`!top:A topology.
        connected_space(top:A topology) <=>
        ~(?e1 e2. closed_in top e1 /\ closed_in top e2 /\
                  topspace top SUBSET e1 UNION e2 /\ e1 INTER e2 = {} /\
                  ~(e1 = {}) /\ ~(e2 = {}))`,
  GEN_TAC THEN REWRITE_TAC[connected_space] THEN AP_TERM_TAC THEN
  EQ_TAC THEN REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:A->bool`] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC
   [`topspace top DIFF v:A->bool`; `topspace top DIFF u:A->bool`] THEN
  ASM_SIMP_TAC[CLOSED_IN_DIFF; CLOSED_IN_TOPSPACE;
               OPEN_IN_DIFF; OPEN_IN_TOPSPACE] THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
  ASM SET_TAC[]);;

let CONNECTED_SPACE_CLOSED_IN_EQ = prove
 (`!top:A topology.
        connected_space(top:A topology) <=>
        ~(?e1 e2. closed_in top e1 /\ closed_in top e2 /\
                  e1 UNION e2 = topspace top /\ e1 INTER e2 = {} /\
                  ~(e1 = {}) /\ ~(e2 = {}))`,
  REWRITE_TAC[SET_RULE
   `s UNION t = u <=> u SUBSET s UNION t /\ s SUBSET u /\ t SUBSET u`] THEN
  REWRITE_TAC[CONNECTED_SPACE_CLOSED_IN] THEN MESON_TAC[CLOSED_IN_SUBSET]);;

let CONNECTED_SPACE_CLOPEN_IN = prove
 (`!top:A topology.
        connected_space top <=>
        !t. open_in top t /\ closed_in top t ==> t = {} \/ t = topspace top`,
  GEN_TAC THEN REWRITE_TAC[CONNECTED_SPACE_EQ] THEN SIMP_TAC[OPEN_IN_SUBSET;
     SET_RULE `(open_in top e1 ==> e1 SUBSET topspace top) /\
               (open_in top e2 ==> e2 SUBSET topspace top)
               ==> (open_in top e1 /\ open_in top e2 /\
                    e1 UNION e2 = topspace top /\ e1 INTER e2 = {} /\ P <=>
                    e2 = topspace top DIFF e1 /\
                    open_in top e1 /\ open_in top e2 /\ P)`] THEN
  REWRITE_TAC[UNWIND_THM2; closed_in] THEN
  REWRITE_TAC[NOT_EXISTS_THM] THEN AP_TERM_TAC THEN ABS_TAC THEN
  ONCE_REWRITE_TAC[OPEN_IN_CLOSED_IN_EQ] THEN SET_TAC[]);;

let CONNECTED_IN = prove
 (`!top s:A->bool.
        connected_in top s <=>
        s SUBSET topspace top /\
        ~(?e1 e2. open_in top e1 /\ open_in top e2 /\
                  s SUBSET (e1 UNION e2) /\
                  (e1 INTER e2 INTER s = {}) /\
                  ~(e1 INTER s = {}) /\ ~(e2 INTER s = {}))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[connected_in] THEN MATCH_MP_TAC
   (TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN DISCH_TAC THEN
  REWRITE_TAC[connected_space; OPEN_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[MESON[]
   `(?e1 e2. (?t1. P1 t1 /\ e1 = f1 t1) /\ (?t2. P2 t2 /\ e2 = f2 t2) /\
             R e1 e2) <=> (?t1 t2. P1 t1 /\ P2 t2 /\ R(f1 t1) (f2 t2))`] THEN
  AP_TERM_TAC THEN REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
  EQ_TAC THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
  ASM SET_TAC[]);;

let CONNECTED_IN_CLOSED_IN = prove
 (`!top s:A->bool.
        connected_in top s <=>
        s SUBSET topspace top /\
        ~(?e1 e2. closed_in top e1 /\ closed_in top e2 /\
                  s SUBSET (e1 UNION e2) /\
                  (e1 INTER e2 INTER s = {}) /\
                  ~(e1 INTER s = {}) /\ ~(e2 INTER s = {}))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[connected_in] THEN MATCH_MP_TAC
   (TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN DISCH_TAC THEN
  REWRITE_TAC[CONNECTED_SPACE_CLOSED_IN; CLOSED_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[MESON[]
   `(?e1 e2. (?t1. P1 t1 /\ e1 = f1 t1) /\ (?t2. P2 t2 /\ e2 = f2 t2) /\
             R e1 e2) <=> (?t1 t2. P1 t1 /\ P2 t2 /\ R(f1 t1) (f2 t2))`] THEN
  AP_TERM_TAC THEN REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
  EQ_TAC THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
  ASM SET_TAC[]);;

let CONNECTED_IN_EMPTY = prove
 (`!top:A topology. connected_in top {}`,
  REWRITE_TAC[CONNECTED_IN; EMPTY_SUBSET; INTER_EMPTY]);;

let CONNECTED_SPACE_TOPSPACE_EMPTY = prove
 (`!top:A topology. topspace top = {} ==> connected_space top`,
  MESON_TAC[SUBTOPOLOGY_TOPSPACE; connected_in; CONNECTED_IN_EMPTY]);;

let CONNECTED_IN_SING = prove
 (`!top a:A. connected_in top {a} <=> a IN topspace top`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MESON_TAC[CONNECTED_IN_SUBSET_TOPSPACE; SING_SUBSET];
    SIMP_TAC[CONNECTED_IN; SING_SUBSET] THEN SET_TAC[]]);;

let CONNECTED_IN_ABSOLUTE = prove
 (`!top s:A->bool. connected_in (subtopology top s) s <=> connected_in top s`,
  REWRITE_TAC[connected_in; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER; SUBSET_REFL] THEN
  REWRITE_TAC[INTER_ACI]);;

let CONNECTED_SPACE_SUBCONNECTED = prove
 (`!top:A topology.
        connected_space top <=>
        !x y. x IN topspace top /\ y IN topspace top
              ==> ?s. connected_in top s /\
                      x IN s /\ y IN s /\ s SUBSET topspace top`,
  GEN_TAC THEN EQ_TAC THENL
   [REPEAT STRIP_TAC THEN EXISTS_TAC `topspace top:A->bool` THEN
    ASM_REWRITE_TAC[SUBTOPOLOGY_TOPSPACE; connected_in; SUBSET_REFL];
    DISCH_TAC] THEN
  REWRITE_TAC[connected_space; NOT_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:A->bool`] THEN
  REPLICATE_TAC 4 (DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_TAC `a:A`) (X_CHOOSE_TAC `b:A`)) THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`a:A`; `b:A`]) THEN ANTS_TAC THENL
   [ASM_MESON_TAC[OPEN_IN_SUBSET; SUBSET]; ALL_TAC] THEN
  DISCH_THEN(X_CHOOSE_THEN `t:A->bool` STRIP_ASSUME_TAC) THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [CONNECTED_IN]) THEN
  ASM_REWRITE_TAC[] THEN MAP_EVERY EXISTS_TAC [`u:A->bool`; `v:A->bool`] THEN
  ASM SET_TAC[]);;

let CONNECTED_IN_INTERMEDIATE_CLOSURE_OF = prove
 (`!top s t:A->bool.
        connected_in top s /\ s SUBSET t /\ t SUBSET top closure_of s
        ==> connected_in top t`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[CONNECTED_IN; CLOSURE_OF_SUBSET_TOPSPACE] THEN
  DISCH_THEN(CONJUNCTS_THEN2 MP_TAC STRIP_ASSUME_TAC) THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  DISCH_THEN(fun th -> CONJ_TAC THEN MP_TAC th) THENL
   [DISCH_THEN(K ALL_TAC) THEN MP_TAC(ISPECL
      [`top:A topology`; `s:A->bool`] CLOSURE_OF_SUBSET_TOPSPACE) THEN
    ASM SET_TAC[];
    REWRITE_TAC[CONTRAPOS_THM] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `u:A->bool` THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `v:A->bool` THEN
    MP_TAC(ISPECL [`top:A topology`; `u:A->bool`; `s:A->bool`]
        OPEN_IN_INTER_CLOSURE_OF_EQ_EMPTY) THEN
    MP_TAC(ISPECL [`top:A topology`; `v:A->bool`; `s:A->bool`]
        OPEN_IN_INTER_CLOSURE_OF_EQ_EMPTY) THEN
    ASM SET_TAC[]]);;

let CONNECTED_IN_CLOSURE_OF = prove
 (`!top s:A->bool. connected_in top s ==> connected_in top (top closure_of s)`,
  REPEAT GEN_TAC THEN DISCH_THEN(fun th ->
    ASSUME_TAC(CONJUNCT1(REWRITE_RULE[connected_in] th)) THEN MP_TAC th) THEN
  MATCH_MP_TAC(ONCE_REWRITE_RULE[IMP_CONJ_ALT]
    CONNECTED_IN_INTERMEDIATE_CLOSURE_OF) THEN
  ASM_SIMP_TAC[SUBSET_REFL; CLOSURE_OF_SUBSET]);;

let CONNECTED_IN_SEPARATION,CONNECTED_IN_SEPARATION_ALT = (CONJ_PAIR o prove)
 (`(!top s:A->bool.
        connected_in top s <=>
        s SUBSET topspace top /\
        ~(?c1 c2. c1 UNION c2 = s /\ ~(c1 = {}) /\ ~(c2 = {}) /\
                  c1 INTER top closure_of c2 = {} /\
                  c2 INTER top closure_of c1 = {})) /\
   (!top s:A->bool.
        connected_in top s <=>
        s SUBSET topspace top /\
        ~(?c1 c2.
            s SUBSET c1 UNION c2 /\ ~(c1 INTER s = {}) /\ ~(c2 INTER s = {}) /\
            c1 INTER top closure_of c2 = {} /\
            c2 INTER top closure_of c1 = {}))`,
  REWRITE_TAC[AND_FORALL_THM] THEN
  MAP_EVERY X_GEN_TAC [`top: A topology`; `s:A->bool`] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THENL
   [ASM_REWRITE_TAC[]; ASM_MESON_TAC[connected_in]] THEN
  MATCH_MP_TAC(TAUT
   `(q ==> r) /\ (~q ==> p) /\ (r ==> ~p)
    ==> (p <=> ~q) /\ (p <=> ~r)`) THEN
  REPEAT CONJ_TAC THENL
   [REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN SET_TAC[];
    ASM_REWRITE_TAC[connected_in; CONNECTED_SPACE_CLOSED_IN_EQ] THEN
    REWRITE_TAC[CLOSED_IN_INTER_CLOSURE_OF; CONTRAPOS_THM] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `c1:A->bool` THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `c2:A->bool` THEN
    REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN ASM SET_TAC[];
    REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`c1:A->bool`; `c2:A->bool`] THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[CONNECTED_IN_CLOSED_IN] THEN
    MAP_EVERY EXISTS_TAC
     [`top closure_of c1:A->bool`; `top closure_of c2:A->bool`] THEN
    REWRITE_TAC[CLOSED_IN_CLOSURE_OF] THEN
    MP_TAC(ISPEC `top:A topology` CLOSURE_OF_SUBSET_INTER) THEN DISCH_THEN
     (fun th -> MP_TAC(SPEC `c1:A->bool` th) THEN
                MP_TAC(SPEC `c2:A->bool` th)) THEN
    ASM SET_TAC[]]);;

let CONNECTED_SPACE_CLOSURES = prove
 (`!top:A topology.
        connected_space top <=>
        ~(?e1 e2. e1 UNION e2 = topspace top /\
                  top closure_of e1 INTER top closure_of e2 = {} /\
                  ~(e1 = {}) /\ ~(e2 = {}))`,
  GEN_TAC THEN REWRITE_TAC[CONNECTED_SPACE_CLOSED_IN_EQ] THEN
  AP_TERM_TAC THEN AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `u:A->bool` THEN REWRITE_TAC[] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `v:A->bool` THEN REWRITE_TAC[] THEN
  MAP_EVERY (fun t -> ASM_CASES_TAC t THEN ASM_REWRITE_TAC[])
   [`u:A->bool = {}`; `v:A->bool = {}`;
   `u UNION v:A->bool = topspace top`] THEN
  REWRITE_TAC[GSYM CLOSURE_OF_EQ] THEN
  MAP_EVERY (MP_TAC o ISPECL [`top:A topology`; `u:A->bool`])
   [CLOSURE_OF_SUBSET; CLOSURE_OF_SUBSET_TOPSPACE] THEN
  MAP_EVERY (MP_TAC o ISPECL [`top:A topology`; `v:A->bool`])
   [CLOSURE_OF_SUBSET; CLOSURE_OF_SUBSET_TOPSPACE] THEN
  ASM SET_TAC[]);;

let CONNECTED_IN_INTER_FRONTIER_OF = prove
 (`!top s t:A->bool.
        connected_in top s /\ ~(s INTER t = {}) /\ ~(s DIFF t = {})
        ==> ~(s INTER top frontier_of t = {})`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  ONCE_REWRITE_TAC[FRONTIER_OF_RESTRICT] THEN
  SUBGOAL_THEN `~(s DIFF (topspace top INTER t):A->bool = {})` MP_TAC THENL
   [ASM SET_TAC[]; ALL_TAC] THEN
  SUBGOAL_THEN `~(s INTER topspace top INTER t:A->bool = {})` MP_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[connected_in]) THEN ASM SET_TAC[];
    UNDISCH_TAC `connected_in top (s:A->bool)`] THEN
  POP_ASSUM_LIST(K ALL_TAC) THEN
  MP_TAC(SET_RULE `(topspace top INTER t:A->bool) SUBSET topspace top`) THEN
  SPEC_TAC(`topspace top INTER t:A->bool`,`t:A->bool`) THEN
  REWRITE_TAC[frontier_of] THEN REPEAT STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [CONNECTED_IN]) THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  REWRITE_TAC[] THEN MAP_EVERY EXISTS_TAC
   [`top interior_of t:A->bool`;
    `topspace top DIFF top closure_of t:A->bool`] THEN
  SIMP_TAC[OPEN_IN_INTERIOR_OF; OPEN_IN_DIFF; CLOSED_IN_CLOSURE_OF;
           OPEN_IN_TOPSPACE] THEN
  MP_TAC(ISPECL [`top:A topology`; `t:A->bool`] INTERIOR_OF_SUBSET) THEN
  MP_TAC(ISPECL [`top:A topology`; `t:A->bool`] CLOSURE_OF_SUBSET) THEN
  ASM SET_TAC[]);;

let CONNECTED_IN_CONTINUOUS_MAP_IMAGE = prove
 (`!f:A->B top top' s.
        continuous_map (top,top') f /\ connected_in top s
        ==> connected_in top' (IMAGE f s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CONNECTED_IN] THEN
  REWRITE_TAC[connected_space; NOT_EXISTS_THM] THEN STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  MAP_EVERY X_GEN_TAC [`u:B->bool`; `v:B->bool`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL
   [`{x | x IN topspace top /\ (f:A->B) x IN u}`;
    `{x | x IN topspace top /\ (f:A->B) x IN v}`]) THEN
  REWRITE_TAC[] THEN GEN_REWRITE_TAC I [CONJ_ASSOC] THEN CONJ_TAC THENL
   [CONJ_TAC THEN MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
    ASM SET_TAC[];
    ASM SET_TAC[]]);;

let HOMEOMORPHIC_CONNECTED_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (connected_space top <=> connected_space top')`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[homeomorphic_space; homeomorphic_maps; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN STRIP_TAC THEN
  REWRITE_TAC[GSYM CONNECTED_IN_TOPSPACE] THEN EQ_TAC THEN DISCH_TAC THENL
   [SUBGOAL_THEN `topspace top' = IMAGE (f:A->B) (topspace top)` SUBST1_TAC
    THENL [ALL_TAC; ASM_MESON_TAC[CONNECTED_IN_CONTINUOUS_MAP_IMAGE]];
    SUBGOAL_THEN `topspace top = IMAGE (g:B->A) (topspace top')` SUBST1_TAC
    THENL [ALL_TAC; ASM_MESON_TAC[CONNECTED_IN_CONTINUOUS_MAP_IMAGE]]] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Topology bases and sub-bases including Alexander sub-base theorem.        *)
(* ------------------------------------------------------------------------- *)

let ISTOPOLOGY_BASE_ALT = prove
 (`!P:(A->bool)->bool.
        istopology (ARBITRARY UNION_OF P) <=>
        (!s t. (ARBITRARY UNION_OF P) s /\ (ARBITRARY UNION_OF P) t
               ==> (ARBITRARY UNION_OF P) (s INTER t))`,
  GEN_TAC THEN REWRITE_TAC[REWRITE_RULE[IN] istopology] THEN
  REWRITE_TAC[ARBITRARY_UNION_OF_EMPTY] THEN
  MATCH_MP_TAC(TAUT `q ==> (p /\ q <=> p)`) THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC ARBITRARY_UNION_OF_UNIONS THEN
  ASM SET_TAC[]);;

let ISTOPOLOGY_BASE_EQ = prove
 (`!P:(A->bool)->bool.
        istopology (ARBITRARY UNION_OF P) <=>
        (!s t. P s /\ P t ==> (ARBITRARY UNION_OF P) (s INTER t))`,
  REWRITE_TAC[ISTOPOLOGY_BASE_ALT; ARBITRARY_UNION_OF_INTER_EQ]);;

let ISTOPOLOGY_BASE = prove
 (`!P:(A->bool)->bool.
        (!s t. P s /\ P t ==> P(s INTER t))
        ==> istopology (ARBITRARY UNION_OF P)`,
  REWRITE_TAC[ISTOPOLOGY_BASE_EQ] THEN
  MESON_TAC[ARBITRARY_UNION_OF_INC]);;

let MINIMAL_TOPOLOGY_BASE = prove
 (`!top:A topology P.
        (!s. P s ==> open_in top s) /\
        (!s t. P s /\ P t ==> P(s INTER t))
        ==> !s. open_in(topology(ARBITRARY UNION_OF P)) s ==> open_in top s`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP ISTOPOLOGY_BASE) THEN
  SIMP_TAC[topology_tybij] THEN DISCH_THEN(K ALL_TAC) THEN
  ASM_SIMP_TAC[FORALL_UNION_OF; OPEN_IN_UNIONS]);;

let OPEN_IN_TOPOLOGY_BASE_UNIQUE = prove
 (`!top:A topology B.
        open_in top = ARBITRARY UNION_OF B <=>
        (!v. v IN B ==> open_in top v) /\
        (!u x. open_in top u /\ x IN u
               ==> ?v. v IN B /\ x IN v /\ v SUBSET u)`,
  REPEAT GEN_TAC THEN EQ_TAC THEN DISCH_TAC THEN REPEAT CONJ_TAC THENL
   [ASM_REWRITE_TAC[ARBITRARY_UNION_OF_INC; IN];
    ASM_REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
    REWRITE_TAC[FORALL_UNION_OF; ARBITRARY; SUBSET; IN_UNIONS] THEN SET_TAC[];
    REWRITE_TAC[FUN_EQ_THM; TAUT `(p <=> q) <=> (p ==> q) /\ (q ==> p)`] THEN
    ASM_REWRITE_TAC[FORALL_UNION_OF; ARBITRARY; FORALL_AND_THM] THEN
    CONJ_TAC THENL
     [X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN
      REWRITE_TAC[UNION_OF; ARBITRARY] THEN
      EXISTS_TAC `{v:A->bool | v IN B /\ v SUBSET u}` THEN
      REWRITE_TAC[UNIONS_GSPEC; IN_ELIM_THM] THEN ASM SET_TAC[];
      REPEAT STRIP_TAC THEN MATCH_MP_TAC OPEN_IN_UNIONS THEN ASM SET_TAC[]]]);;

let TOPOLOGY_BASE_UNIQUE = prove
 (`!top:A topology P.
        (!s. P s ==> open_in top s) /\
        (!u x. open_in top u /\ x IN u ==> ?b. P b /\ x IN b /\ b SUBSET u)
        ==> topology(ARBITRARY UNION_OF P) = top`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC(MESON[topology_tybij]
   `open_in top = P ==> topology P = top`) THEN
  REWRITE_TAC[OPEN_IN_TOPOLOGY_BASE_UNIQUE] THEN ASM SET_TAC[]);;

let TOPOLOGY_BASES_EQ = prove
 (`!top P Q.
        (!u x. P u /\ x IN u ==> ?v. Q v /\ x IN v /\ v SUBSET u) /\
        (!v x. Q v /\ x IN v ==> ?u. P u /\ x IN u /\ u SUBSET v)
        ==> topology (ARBITRARY UNION_OF P) =
            topology (ARBITRARY UNION_OF Q)`,
  REPEAT STRIP_TAC THEN AP_TERM_TAC THEN MATCH_MP_TAC SUBSET_ANTISYM THEN
  CONJ_TAC THEN
  GEN_REWRITE_TAC RAND_CONV [GSYM ARBITRARY_UNION_OF_IDEMPOT] THEN
  REWRITE_TAC[SUBSET; IN] THEN GEN_TAC THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] UNION_OF_MONO) THEN
  REWRITE_TAC[ARBITRARY_UNION_OF_ALT] THEN ASM SET_TAC[]);;

let MTOPOLOGY_BASE = prove
 (`!m:A metric.
      mtopology m =
      topology(ARBITRARY UNION_OF
                 {mball m (x,r) |x,r| x IN mspace m /\ &0 < r})`,
  GEN_TAC THEN CONV_TAC SYM_CONV THEN MATCH_MP_TAC TOPOLOGY_BASE_UNIQUE THEN
  REWRITE_TAC[SET_RULE `GSPEC s x <=> x IN GSPEC s`] THEN
  REWRITE_TAC[FORALL_IN_GSPEC; EXISTS_IN_GSPEC; OPEN_IN_MBALL] THEN
  REWRITE_TAC[OPEN_IN_MTOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `x:A`] THEN STRIP_TAC THEN
  EXISTS_TAC `x:A` THEN FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_EXISTS THEN
  ASM_MESON_TAC[CENTRE_IN_MBALL; SUBSET]);;

let ISTOPOLOGY_SUBBASE = prove
 (`!P s:A->bool.
     istopology (ARBITRARY UNION_OF (FINITE INTERSECTION_OF P relative_to s))`,
  REPEAT GEN_TAC THEN MATCH_MP_TAC ISTOPOLOGY_BASE THEN
  MATCH_MP_TAC RELATIVE_TO_INTER THEN
  REWRITE_TAC[FINITE_INTERSECTION_OF_INTER]);;

let OPEN_IN_SUBBASE = prove
 (`!B u s:A->bool.
        open_in (topology
           (ARBITRARY UNION_OF (FINITE INTERSECTION_OF B relative_to u))) s <=>
        (ARBITRARY UNION_OF (FINITE INTERSECTION_OF B relative_to u)) s`,
  GEN_TAC THEN GEN_TAC THEN
  REWRITE_TAC[GSYM(CONJUNCT2 topology_tybij); GSYM FUN_EQ_THM; ETA_AX] THEN
  REWRITE_TAC[ISTOPOLOGY_SUBBASE]);;

let TOPSPACE_SUBBASE = prove
 (`!B u:A->bool.
        topspace(topology
           (ARBITRARY UNION_OF (FINITE INTERSECTION_OF B relative_to u))) = u`,
  REWRITE_TAC[OPEN_IN_SUBBASE; topspace; GSYM SUBSET_ANTISYM_EQ] THEN
  REPEAT STRIP_TAC THENL
   [REWRITE_TAC[UNIONS_SUBSET; IN_ELIM_THM; FORALL_UNION_OF] THEN
    GEN_TAC THEN REWRITE_TAC[ARBITRARY] THEN MATCH_MP_TAC(MESON[]
     `(!x. Q x ==> R x) ==> (!x. P x ==> Q x) ==> (!x. P x ==> R x)`) THEN
    REWRITE_TAC[FORALL_RELATIVE_TO; INTER_SUBSET];
    MATCH_MP_TAC(SET_RULE `x IN s ==> x SUBSET UNIONS s`) THEN
    REWRITE_TAC[UNION_OF; ARBITRARY; IN_ELIM_THM] THEN
    EXISTS_TAC `{u:A->bool}` THEN REWRITE_TAC[UNIONS_1] THEN
    REWRITE_TAC[FORALL_IN_INSERT; NOT_IN_EMPTY; relative_to] THEN
    EXISTS_TAC `(:A)` THEN REWRITE_TAC[INTER_UNIV] THEN
    REWRITE_TAC[INTERSECTION_OF] THEN EXISTS_TAC `{}:(A->bool)->bool` THEN
    REWRITE_TAC[FINITE_EMPTY; NOT_IN_EMPTY; INTERS_0]]);;

let MINIMAL_TOPOLOGY_SUBBASE = prove
 (`!top:A topology u P.
        (!s. P s ==> open_in top s) /\ open_in top u
        ==> !s. open_in(topology(ARBITRARY UNION_OF
                       (FINITE INTERSECTION_OF P relative_to u))) s
                ==> open_in top s`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  SIMP_TAC[REWRITE_RULE[topology_tybij] ISTOPOLOGY_SUBBASE] THEN
  REWRITE_TAC[FORALL_UNION_OF; ARBITRARY] THEN
  X_GEN_TAC `v:(A->bool)->bool` THEN DISCH_TAC THEN
  MATCH_MP_TAC OPEN_IN_UNIONS THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
   (SET_RULE `(!x. P x ==> Q x)
              ==> (!x. Q x ==> R x) ==> (!x. P x ==> R x)`)) THEN
  REWRITE_TAC[FORALL_RELATIVE_TO; FORALL_INTERSECTION_OF] THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[GSYM INTERS_INSERT] THEN
  MATCH_MP_TAC OPEN_IN_INTERS THEN
  ASM_REWRITE_TAC[FORALL_IN_INSERT; FINITE_INSERT; NOT_INSERT_EMPTY] THEN
  ASM_MESON_TAC[]);;

let ISTOPOLOGY_SUBBASE_UNIV = prove
 (`!P:(A->bool)->bool.
       istopology (ARBITRARY UNION_OF (FINITE INTERSECTION_OF P))`,
  GEN_TAC THEN MATCH_MP_TAC ISTOPOLOGY_BASE THEN
  REWRITE_TAC[FINITE_INTERSECTION_OF_INTER]);;

let ALEXANDER_SUBBASE_THEOREM = prove
 (`!top:A topology B.
        topology
          (ARBITRARY UNION_OF
               (FINITE INTERSECTION_OF B relative_to UNIONS B)) = top /\
        (!C. C SUBSET B /\ UNIONS C = topspace top
             ==> ?C'. FINITE C' /\ C' SUBSET C /\ UNIONS C' = topspace top)
        ==> compact_space top`,
  REPEAT GEN_TAC THEN INTRO_TAC "top fin" THEN
  SUBGOAL_THEN `UNIONS B:A->bool = topspace top` ASSUME_TAC THENL
   [EXPAND_TAC "top" THEN REWRITE_TAC[TOPSPACE_SUBBASE]; ALL_TAC] THEN
  REWRITE_TAC[compact_space; compact_in; SUBSET_REFL] THEN
  MP_TAC(ISPEC
   `\C. (!u:A->bool. u IN C ==> open_in top u) /\
        topspace top SUBSET UNIONS C /\
        !C'. FINITE C' /\ C' SUBSET C ==> ~(topspace top SUBSET UNIONS C')`
    ZL_SUBSETS_UNIONS_NONEMPTY) THEN
  REWRITE_TAC[] THEN
  MATCH_MP_TAC(TAUT `(~p' ==> p) /\ q /\ ~r ==> (p /\ q ==> r) ==> p'`) THEN
  CONJ_TAC THENL [MESON_TAC[]; ALL_TAC] THEN CONJ_TAC THENL
   [X_GEN_TAC `c:((A->bool)->bool)->bool` THEN
    REWRITE_TAC[MEMBER_NOT_EMPTY] THEN STRIP_TAC THEN
    REPEAT(CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC]) THEN
    X_GEN_TAC `c':(A->bool)->bool` THEN STRIP_TAC THEN
    MP_TAC(ISPECL [`c:((A->bool)->bool)->bool`; `c':(A->bool)->bool`]
     FINITE_SUBSET_UNIONS_CHAIN) THEN
    ASM SET_TAC[];
    ALL_TAC] THEN
  DISCH_THEN(X_CHOOSE_THEN `C:(A->bool)->bool` MP_TAC) THEN
  DISCH_THEN(CONJUNCTS_THEN2 STRIP_ASSUME_TAC (LABEL_TAC "*")) THEN
  SUBGOAL_THEN
   `?x:A. x IN topspace top /\ ~(x IN UNIONS(B INTER C))`
  STRIP_ASSUME_TAC THENL
   [MATCH_MP_TAC(SET_RULE
     `s SUBSET t /\ ~(s = t) ==> ?x. x IN t /\ ~(x IN s)`) THEN
    CONJ_TAC THENL
     [REWRITE_TAC[UNIONS_SUBSET; IN_INTER] THEN ASM_MESON_TAC[OPEN_IN_SUBSET];
      DISCH_TAC] THEN
    REMOVE_THEN "fin" (MP_TAC o SPEC `B INTER C:(A->bool)->bool`) THEN
    ASM_REWRITE_TAC[INTER_SUBSET; SUBSET_INTER] THEN
    ASM_MESON_TAC[SUBSET_REFL];
    ALL_TAC] THEN
  SUBGOAL_THEN
   `?c B'. c IN C /\ open_in top c /\ ~(c = topspace top) /\
           FINITE B' /\ B' SUBSET B /\ ~(B' = {}) /\ (x:A) IN INTERS B' /\
           INTERS B' SUBSET c`
  STRIP_ASSUME_TAC THENL
   [SUBGOAL_THEN `?u:A->bool. open_in top u /\ u IN C /\ x IN u`
    MP_TAC THENL [ASM SET_TAC[]; MATCH_MP_TAC MONO_EXISTS] THEN
    X_GEN_TAC `c:A->bool` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[RIGHT_EXISTS_AND_THM] THEN
    MATCH_MP_TAC(TAUT `p /\ (p ==> q) ==> p /\ q`) THEN CONJ_TAC THENL
     [ASM_MESON_TAC[SING_SUBSET; FINITE_SING; UNIONS_1; SUBSET_REFL];
      UNDISCH_TAC `(x:A) IN c`] THEN
    UNDISCH_TAC `open_in top (c:A->bool)` THEN EXPAND_TAC "top" THEN
    REWRITE_TAC[REWRITE_RULE[topology_tybij] ISTOPOLOGY_SUBBASE] THEN
    SPEC_TAC(`c:A->bool`,`d:A->bool`) THEN
    ASM_REWRITE_TAC[FORALL_UNION_OF; ARBITRARY] THEN
    X_GEN_TAC `v:(A->bool)->bool` THEN
    DISCH_THEN(LABEL_TAC "+") THEN
    ONCE_REWRITE_TAC[TAUT `p ==> q ==> r <=> q ==> p ==> r`] THEN
    DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
     `~(UNIONS v = u) ==> UNIONS v SUBSET u ==> ~(u IN v)`)) THEN
    ANTS_TAC THENL
     [REWRITE_TAC[UNIONS_SUBSET] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
       (SET_RULE `(!x. P x ==> Q x)
                  ==> (!x. Q x ==> R x) ==> (!x. P x ==> R x)`)) THEN
      REWRITE_TAC[FORALL_RELATIVE_TO; INTER_SUBSET];
      DISCH_TAC] THEN
    REWRITE_TAC[IN_UNIONS; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `w:A->bool` THEN STRIP_TAC THEN
    REMOVE_THEN "+" (MP_TAC o SPEC `w:A->bool`) THEN
    ASM_REWRITE_TAC[relative_to; LEFT_IMP_EXISTS_THM] THEN
    REWRITE_TAC[IMP_CONJ; FORALL_INTERSECTION_OF] THEN
    REWRITE_TAC[IMP_IMP; LEFT_FORALL_IMP_THM] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `B':(A->bool)->bool` THEN
    ASM_CASES_TAC `B':(A->bool)->bool = {}` THENL [ALL_TAC; ASM SET_TAC[]] THEN
    ASM_REWRITE_TAC[INTERS_0; INTER_UNIV; FINITE_EMPTY; NOT_IN_EMPTY] THEN
    ASM_MESON_TAC[];
    ALL_TAC] THEN
  SUBGOAL_THEN
   `!b. (b:A->bool) IN B'
        ==> ?C'. FINITE C' /\ C' SUBSET C /\
                 topspace top SUBSET UNIONS(b INSERT C')`
  MP_TAC THENL
   [X_GEN_TAC `b:A->bool` THEN DISCH_TAC THEN
    REMOVE_THEN "*" (MP_TAC o SPEC `(b:A->bool) INSERT C`) THEN
    ASM_REWRITE_TAC[FORALL_IN_INSERT; SET_RULE `s SUBSET a INSERT s`] THEN
    MATCH_MP_TAC(TAUT
     `q /\ ~s /\ p /\ (~r ==> t) ==> (p /\ q /\ r ==> s) ==> t`) THEN
    REPLICATE_TAC 2 (CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC]) THEN
    CONJ_TAC THENL
     [EXPAND_TAC "top" THEN REWRITE_TAC[OPEN_IN_SUBBASE] THEN
      MATCH_MP_TAC UNION_OF_INC THEN REWRITE_TAC[ARBITRARY] THEN
      REWRITE_TAC[INTERSECTION_OF; relative_to] THEN
      EXISTS_TAC `b:A->bool` THEN
      CONJ_TAC THENL [EXISTS_TAC `{b:A->bool}`; ASM SET_TAC[]] THEN
      REWRITE_TAC[FINITE_SING; FORALL_IN_INSERT; INTERS_1; NOT_IN_EMPTY] THEN
      ASM SET_TAC[];
      REWRITE_TAC[NOT_FORALL_THM; NOT_IMP] THEN
      DISCH_THEN(X_CHOOSE_THEN `C':(A->bool)->bool` STRIP_ASSUME_TAC) THEN
      EXISTS_TAC `C' DELETE (b:A->bool)` THEN
      ASM_REWRITE_TAC[FINITE_DELETE] THEN ASM SET_TAC[]];
    REWRITE_TAC[RIGHT_IMP_EXISTS_THM; SKOLEM_THM]] THEN
  DISCH_THEN(X_CHOOSE_TAC `cc:(A->bool)->(A->bool)->bool`) THEN
  SUBGOAL_THEN
   `topspace top SUBSET
    UNIONS(c INSERT UNIONS(IMAGE (cc:(A->bool)->(A->bool)->bool) B'))`
  MP_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[]] THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN
  ASM_REWRITE_TAC[FINITE_INSERT; FINITE_UNIONS] THEN
  ASM_SIMP_TAC[FINITE_IMAGE; FORALL_IN_IMAGE] THEN ASM SET_TAC[]);;

let ALEXANDER_SUBBASE_THEOREM_ALT = prove
 (`!top:A topology B u.
        u SUBSET UNIONS B /\
        topology
          (ARBITRARY UNION_OF
               (FINITE INTERSECTION_OF B relative_to u)) = top /\
        (!C. C SUBSET B /\ u SUBSET UNIONS C
             ==> ?C'. FINITE C' /\ C' SUBSET C /\ u SUBSET UNIONS C')
        ==> compact_space top`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `topspace top:A->bool = u` ASSUME_TAC THENL
   [ASM_MESON_TAC[TOPSPACE_SUBBASE]; ALL_TAC] THEN
  MATCH_MP_TAC ALEXANDER_SUBBASE_THEOREM THEN
  EXISTS_TAC `B relative_to (topspace top:A->bool)` THEN CONJ_TAC THENL
   [FIRST_X_ASSUM(fun th -> GEN_REWRITE_TAC RAND_CONV [SYM th]) THEN
    AP_TERM_TAC THEN AP_TERM_TAC THEN
    GEN_REWRITE_TAC (RAND_CONV o ONCE_DEPTH_CONV)
     [FINITE_INTERSECTION_OF_RELATIVE_TO] THEN
    ASM_REWRITE_TAC[] THEN AP_TERM_TAC THEN REWRITE_TAC[RELATIVE_TO] THEN
    ONCE_REWRITE_TAC[SET_RULE `{f x | s x} = {f x | x IN s}`] THEN
    REWRITE_TAC[GSYM INTER_UNIONS] THEN ASM SET_TAC[];
    REWRITE_TAC[RELATIVE_TO; IMP_CONJ] THEN
    ONCE_REWRITE_TAC[SET_RULE `{f x | s x} = IMAGE f s`] THEN
    REWRITE_TAC[FORALL_SUBSET_IMAGE; EXISTS_FINITE_SUBSET_IMAGE] THEN
    REWRITE_TAC[GSYM SIMPLE_IMAGE; GSYM INTER_UNIONS] THEN
    REWRITE_TAC[SET_RULE `s INTER t = s <=> s SUBSET t`] THEN
    ASM_MESON_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* Neigbourhood bases (useful for "local" properties of various kind).       *)
(* ------------------------------------------------------------------------- *)

let neighbourhood_base_at = new_definition
 `neighbourhood_base_at (x:A) P top <=>
        !w. open_in top w /\ x IN w
            ==>  ?u v. open_in top u /\ P v /\
                     x IN u /\ u SUBSET v /\ v SUBSET w`;;

let neighbourhood_base_of = new_definition
 `neighbourhood_base_of P top <=>
        !x. x IN topspace top ==> neighbourhood_base_at x P top`;;

let NEIGHBOURHOOD_BASE_OF = prove
 (`!(top:A topology) P.
        neighbourhood_base_of P top <=>
        !w x. open_in top w /\ x IN w
              ==> ?u v. open_in top u /\ P v /\
                        x IN u /\ u SUBSET v /\ v SUBSET w`,
  REWRITE_TAC[neighbourhood_base_at; neighbourhood_base_of] THEN
  MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let NEIGHBOURHOOD_BASE_AT_MONO = prove
 (`!top P Q x:A.
        (!s. P s /\ x IN s ==> Q s) /\ neighbourhood_base_at x P top
        ==> neighbourhood_base_at x Q top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[neighbourhood_base_at] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  MATCH_MP_TAC MONO_FORALL THEN ASM SET_TAC[]);;

let NEIGHBOURHOOD_BASE_OF_MONO = prove
 (`!top P Q:(A->bool)->bool.
        (!s. P s ==> Q s) /\ neighbourhood_base_of P top
        ==> neighbourhood_base_of Q top`,
  REWRITE_TAC[neighbourhood_base_of] THEN
  MESON_TAC[NEIGHBOURHOOD_BASE_AT_MONO]);;

let OPEN_NEIGHBOURHOOD_BASE_AT = prove
 (`!top P x:A.
        (!s. P s /\ x IN s ==> open_in top s)
        ==> (neighbourhood_base_at x P top <=>
             !w. open_in top w /\ x IN w ==> ?u. P u /\ x IN u /\ u SUBSET w)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[neighbourhood_base_at] THEN
  ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET]);;

let OPEN_NEIGHBOURHOOD_BASE_OF = prove
 (`!top P:(A->bool)->bool.
      (!s. P s ==> open_in top s)
      ==> (neighbourhood_base_of P top <=>
           !w x. open_in top w /\ x IN w ==> ?u. P u /\ x IN u /\ u SUBSET w)`,
  REWRITE_TAC[neighbourhood_base_of] THEN
  SIMP_TAC[OPEN_NEIGHBOURHOOD_BASE_AT] THEN
  MESON_TAC[SUBSET; OPEN_IN_SUBSET]);;

let OPEN_IN_TOPOLOGY_NEIGHBOURHOOD_BASE_UNIQUE = prove
 (`!top b:(A->bool)->bool.
        open_in top = ARBITRARY UNION_OF b <=>
        (!u. u IN b ==> open_in top u) /\ neighbourhood_base_of b top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[OPEN_IN_TOPOLOGY_BASE_UNIQUE] THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
  REWRITE_TAC[IN] THEN SIMP_TAC[OPEN_NEIGHBOURHOOD_BASE_OF] THEN
  REWRITE_TAC[IN]);;

let NEIGHBOURHOOD_BASE_OF_OPEN_SUBSET = prove
 (`!top P s:A->bool.
        neighbourhood_base_of P top /\ open_in top s
        ==> neighbourhood_base_of P (subtopology top s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[RIGHT_EXISTS_AND_THM; FORALL_IN_GSPEC; EXISTS_IN_GSPEC] THEN
  REWRITE_TAC[IMP_IMP] THEN STRIP_TAC THEN
  X_GEN_TAC `v:A->bool` THEN DISCH_TAC THEN
  X_GEN_TAC `x:A` THEN REWRITE_TAC[IN_INTER] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `s INTER v:A->bool`) THEN
  ASM_SIMP_TAC[OPEN_IN_INTER; IN_INTER] THEN
  DISCH_THEN(MP_TAC o SPEC `x:A`) THEN ASM_REWRITE_TAC[SUBSET_INTER] THEN
  MATCH_MP_TAC MONO_EXISTS THEN ASM SET_TAC[]);;

let NEIGHBOURHOOD_BASE_AT_TOPOLOGY_BASE = prove
 (`!P top b x:A.
        open_in top = ARBITRARY UNION_OF b
        ==> (neighbourhood_base_at x P top <=>
             !w. w IN b /\ x IN w
                 ==> ?u v. open_in top u /\
                           P v /\
                           x IN u /\
                           u SUBSET v /\
                           v SUBSET w)`,
  REWRITE_TAC[OPEN_IN_TOPOLOGY_BASE_UNIQUE; neighbourhood_base_at] THEN
  REPEAT GEN_TAC THEN STRIP_TAC THEN EQ_TAC THEN ASM_SIMP_TAC[] THEN
  DISCH_TAC THEN X_GEN_TAC `w:A->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`w:A->bool`; `x:A`]) THEN
  ASM_MESON_TAC[SUBSET_TRANS]);;

let NEIGHBOURHOOD_BASE_OF_TOPOLOGY_BASE = prove
 (`!P top b:(A->bool)->bool.
        open_in top = ARBITRARY UNION_OF b
        ==> (neighbourhood_base_of P top <=>
             !w x. w IN b /\ x IN w
                   ==> ?u v. open_in top u /\
                             P v /\
                             x IN u /\
                             u SUBSET v /\
                             v SUBSET w)`,
  REWRITE_TAC[OPEN_IN_TOPOLOGY_BASE_UNIQUE; NEIGHBOURHOOD_BASE_OF] THEN
  REPEAT GEN_TAC THEN STRIP_TAC THEN EQ_TAC THEN ASM_SIMP_TAC[] THEN
  GEN_REWRITE_TAC LAND_CONV [SWAP_FORALL_THM] THEN DISCH_TAC THEN
  MAP_EVERY X_GEN_TAC [`w:A->bool`; `x:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`w:A->bool`; `x:A`]) THEN
  ASM_MESON_TAC[SUBSET_TRANS]);;

let NEIGHBOURHOOD_BASE_AT_UNLOCALIZED = prove
 (`!top P x:A.
       (!s t. P s /\ open_in top t /\ x IN t /\ t SUBSET s ==> P t)
       ==> (neighbourhood_base_at x P top <=>
            x IN topspace top
            ==> ?u v. open_in top u /\ P v /\ x IN u /\
                      u SUBSET v /\ v SUBSET topspace top)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[neighbourhood_base_at] THEN
  EQ_TAC THENL [MESON_TAC[OPEN_IN_TOPSPACE; SUBSET]; DISCH_TAC] THEN
  X_GEN_TAC `w:A->bool` THEN STRIP_TAC THEN
  SUBGOAL_THEN `(x:A) IN topspace top` (ANTE_RES_THEN MP_TAC) THENL
   [ASM_MESON_TAC[OPEN_IN_SUBSET; SUBSET];
    REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:A->bool`] THEN STRIP_TAC THEN
  REPEAT(EXISTS_TAC `u INTER w:A->bool`) THEN
  ASM_SIMP_TAC[IN_INTER; SUBSET_REFL; OPEN_IN_INTER; INTER_SUBSET] THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN EXISTS_TAC `v:A->bool` THEN
  ASM_SIMP_TAC[IN_INTER; OPEN_IN_INTER] THEN ASM SET_TAC[]);;

let NEIGHBOURHOOD_BASE_OF_UNLOCALIZED = prove
 (`!top P:(A->bool)->bool.
       (!s t. P s /\ open_in top t /\ ~(t = {}) /\ t SUBSET s ==> P t)
       ==> (neighbourhood_base_of P top <=>
            !x. x IN topspace top
                ==> ?u v. open_in top u /\ P v /\ x IN u /\
                          u SUBSET v /\ v SUBSET topspace top)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[neighbourhood_base_of] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `x:A` THEN
  ASM_CASES_TAC `(x:A) IN topspace top` THEN ASM_REWRITE_TAC[] THEN
  W(MP_TAC o PART_MATCH (lhand o rand)
    NEIGHBOURHOOD_BASE_AT_UNLOCALIZED o lhand o snd) THEN
  ANTS_TAC THENL [ASM_MESON_TAC[MEMBER_NOT_EMPTY]; DISCH_THEN SUBST1_TAC] THEN
  ASM_REWRITE_TAC[]);;

let NEIGHBOURHOOD_BASE_AT_DISCRETE_TOPOLOGY = prove
 (`!P u x:A.
        neighbourhood_base_at x P (discrete_topology u) <=>
        x IN u ==> P {x}`,
  REPEAT GEN_TAC THEN REWRITE_TAC[neighbourhood_base_at] THEN
  REWRITE_TAC[OPEN_IN_DISCRETE_TOPOLOGY] THEN
  ASM_CASES_TAC `(x:A) IN u` THEN ASM_REWRITE_TAC[] THENL
   [ALL_TAC; ASM SET_TAC[]] THEN
  EQ_TAC THENL
   [DISCH_THEN(MP_TAC o SPEC `{x:A}`) THEN
    ASM_REWRITE_TAC[IN_SING; SING_SUBSET; LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`s:A->bool`; `t:A->bool`] THEN
    ASM_CASES_TAC `t:A->bool = {x}` THEN ASM_SIMP_TAC[] THEN ASM SET_TAC[];
    DISCH_TAC THEN X_GEN_TAC `w:A->bool` THEN STRIP_TAC THEN
    REPEAT(EXISTS_TAC `{x:A}`) THEN ASM SET_TAC[]]);;

let NEIGHBOURHOOD_BASE_OF_DISCRETE_TOPOLOGY = prove
 (`!P u:A->bool.
        neighbourhood_base_of P (discrete_topology u) <=>
        !x. x IN u ==> P {x}`,
  REPEAT GEN_TAC THEN REWRITE_TAC[neighbourhood_base_of] THEN
  REWRITE_TAC[NEIGHBOURHOOD_BASE_AT_DISCRETE_TOPOLOGY] THEN
  SIMP_TAC[TOPSPACE_DISCRETE_TOPOLOGY]);;

(* ------------------------------------------------------------------------- *)
(* Metrizable spaces.                                                        *)
(* ------------------------------------------------------------------------- *)

let metrizable_space = new_definition
 `metrizable_space top <=> ?m. top = mtopology m`;;

let METRIZABLE_SPACE_MTOPOLOGY = prove
 (`!m. metrizable_space (mtopology m)`,
  REWRITE_TAC[metrizable_space] THEN MESON_TAC[]);;

let FORALL_METRIC_TOPOLOGY = prove
 (`!P. (!m:A metric. P (mtopology m) (mspace m)) <=>
       !top. metrizable_space top ==> P top (topspace top)`,
  SIMP_TAC[metrizable_space; LEFT_IMP_EXISTS_THM; TOPSPACE_MTOPOLOGY] THEN
  MESON_TAC[]);;

let FORALL_METRIZABLE_SPACE = prove
 (`!P. (!top. metrizable_space top ==> P top (topspace top)) <=>
       (!m:A metric. P (mtopology m) (mspace m))`,
  REWRITE_TAC[FORALL_METRIC_TOPOLOGY]);;

let EXISTS_METRIZABLE_SPACE = prove
 (`!P. (?top. metrizable_space top /\ P top (topspace top)) <=>
       (?m:A metric. P (mtopology m) (mspace m))`,
  REWRITE_TAC[MESON[] `(?x. P x) <=> ~(!x. ~P x)`] THEN
  REWRITE_TAC[FORALL_METRIC_TOPOLOGY] THEN MESON_TAC[]);;

let METRIZABLE_SPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. metrizable_space(discrete_topology u)`,
  REWRITE_TAC[metrizable_space] THEN MESON_TAC[MTOPOLOGY_DISCRETE_METRIC]);;

let METRIZABLE_SPACE_SUBTOPOLOGY = prove
 (`!top s:A->bool.
    metrizable_space top ==> metrizable_space(subtopology top s)`,
  REWRITE_TAC[metrizable_space] THEN MESON_TAC[MTOPOLOGY_SUBMETRIC]);;

let HOMEOMORPHIC_METRIZABLE_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (metrizable_space top <=> metrizable_space top')`,
  let lemma = prove
   (`!(top:A topology) (top':B topology).
          top homeomorphic_space top'
          ==> metrizable_space top ==> metrizable_space top'`,
    REPEAT GEN_TAC THEN
    REWRITE_TAC[metrizable_space; homeomorphic_space; LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN DISCH_TAC THEN
    X_GEN_TAC `m:A metric` THEN DISCH_THEN(STRIP_ASSUME_TAC o GSYM) THEN
    ABBREV_TAC
     `m' = metric(topspace top',\(x,y). mdist m ((g:B->A) x,g y))` THEN
    MP_TAC(ISPECL [`g:B->A`; `m:A metric`; `topspace top':B->bool`]
          METRIC_INJECTIVE_IMAGE) THEN
    ASM_REWRITE_TAC[] THEN ANTS_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [homeomorphic_maps]) THEN
      EXPAND_TAC "top" THEN
      REWRITE_TAC[continuous_map; TOPSPACE_MTOPOLOGY] THEN SET_TAC[];
      STRIP_TAC THEN EXISTS_TAC `m':B metric`] THEN
    REWRITE_TAC[TOPOLOGY_EQ; OPEN_IN_MTOPOLOGY] THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [HOMEOMORPHIC_MAPS_SYM]) THEN
    DISCH_THEN(MP_TAC o MATCH_MP HOMEOMORPHIC_MAPS_IMP_MAP) THEN
    DISCH_THEN(fun th ->
      REWRITE_TAC[MATCH_MP HOMEOMORPHIC_MAP_OPENNESS_EQ th]) THEN
    X_GEN_TAC `v:B->bool` THEN
    ASM_CASES_TAC `(v:B->bool) SUBSET topspace top'` THEN
    ASM_REWRITE_TAC[] THEN
    EXPAND_TAC "top" THEN REWRITE_TAC[OPEN_IN_MTOPOLOGY] THEN
    ASM_REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
    ASM_REWRITE_TAC[IN_MBALL] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[homeomorphic_maps; continuous_map]) THEN
    MATCH_MP_TAC(TAUT `p /\ (q <=> r) ==> (p /\ q <=> r)`) THEN
    CONJ_TAC THENL [ASM SET_TAC[]; EQ_TAC] THEN
    MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `b:B` THEN
    ASM_CASES_TAC `(b:B) IN v` THEN
    ASM_REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:real` THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[] THENL
     [X_GEN_TAC `y:B` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `(g:B->A) y`) THEN ASM SET_TAC[];
      ASM SET_TAC[]]) in
  REPEAT STRIP_TAC THEN EQ_TAC THEN MATCH_MP_TAC lemma THEN
  ASM_MESON_TAC[HOMEOMORPHIC_SPACE_SYM]);;

(* ------------------------------------------------------------------------- *)
(* T_1 spaces with equivalences to many naturally "nice" properties.         *)
(* ------------------------------------------------------------------------- *)

let t1_space = new_definition
 `t1_space top <=>
  !x y. x IN topspace top /\ y IN topspace top /\ ~(x = y)
        ==> ?u. open_in top u /\ x IN u /\ ~(y IN u)`;;

let T1_SPACE_ALT = prove
 (`!top:A topology.
        t1_space top <=>
        !x y. x IN topspace top /\ y IN topspace top /\ ~(x = y)
              ==> ?u. closed_in top u /\ x IN u /\ ~(y IN u)`,
  SIMP_TAC[t1_space; EXISTS_CLOSED_IN; IN_DIFF] THEN MESON_TAC[]);;

let T1_SPACE_DERIVED_SET_OF_SING = prove
 (`!top:A topology.
      t1_space top <=> !x. x IN topspace top ==> top derived_set_of {x} = {}`,
  GEN_TAC THEN REWRITE_TAC[t1_space; derived_set_of; SET_RULE
   `(?y. P y /\ y IN {a} /\ Q y) <=> P a /\ Q a`] THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM; NOT_IN_EMPTY] THEN
  MESON_TAC[OPEN_IN_TOPSPACE]);;

let T1_SPACE_DERIVED_SET_OF_FINITE = prove
 (`!top:A topology.
      t1_space top <=> !s. FINITE s ==> top derived_set_of s = {}`,
  GEN_TAC THEN REWRITE_TAC[T1_SPACE_DERIVED_SET_OF_SING] THEN
  EQ_TAC THEN SIMP_TAC[FINITE_SING] THEN REPEAT STRIP_TAC THEN
  ONCE_REWRITE_TAC[DERIVED_SET_OF_RESTRICT] THEN
  GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [GSYM UNIONS_SINGS] THEN
  ASM_SIMP_TAC[DERIVED_SET_OF_UNIONS; SIMPLE_IMAGE; FINITE_IMAGE; IN_INTER;
               FINITE_INTER; EMPTY_UNIONS; FORALL_IN_IMAGE]);;

let T1_SPACE_CLOSED_IN_SING = prove
 (`!top:A topology.
      t1_space top <=> !x. x IN topspace top ==> closed_in top {x}`,
  GEN_TAC THEN EQ_TAC THENL
   [SIMP_TAC[T1_SPACE_DERIVED_SET_OF_SING; CLOSED_IN_CONTAINS_DERIVED_SET] THEN
    REWRITE_TAC[NOT_IN_EMPTY; SING_SUBSET] THEN SET_TAC[];
    DISCH_TAC THEN REWRITE_TAC[T1_SPACE_ALT] THEN
    MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
    EXISTS_TAC `{x:A}` THEN ASM_SIMP_TAC[IN_SING]]);;

let T1_SPACE_CLOSED_IN_FINITE = prove
 (`!top:A topology.
      t1_space top <=>
      !s. FINITE s /\ s SUBSET topspace top ==> closed_in top s`,
  GEN_TAC THEN REWRITE_TAC[T1_SPACE_CLOSED_IN_SING] THEN
  EQ_TAC THEN SIMP_TAC[FINITE_SING; SING_SUBSET] THEN REPEAT STRIP_TAC THEN
  GEN_REWRITE_TAC RAND_CONV [GSYM UNIONS_SINGS] THEN
  MATCH_MP_TAC CLOSED_IN_UNIONS THEN
  ASM_SIMP_TAC[SIMPLE_IMAGE; FORALL_IN_IMAGE; FINITE_IMAGE] THEN
  ASM SET_TAC[]);;

let T1_SPACE_OPEN_IN_DELETE = prove
 (`!top:A topology.
        t1_space top <=>
        !u x. open_in top u /\ x IN u ==> open_in top (u DELETE x)`,
  GEN_TAC THEN REWRITE_TAC[T1_SPACE_CLOSED_IN_SING] THEN EQ_TAC THENL
   [REWRITE_TAC[SET_RULE `u DELETE x = u DIFF {x}`] THEN
    REPEAT STRIP_TAC THEN MATCH_MP_TAC OPEN_IN_DIFF THEN ASM_REWRITE_TAC[] THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[];
    DISCH_TAC THEN X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    SUBGOAL_THEN `{x:A} = topspace top DIFF (topspace top DELETE x)`
    SUBST1_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
    MATCH_MP_TAC CLOSED_IN_DIFF THEN
    ASM_SIMP_TAC[OPEN_IN_TOPSPACE; CLOSED_IN_TOPSPACE]]);;

let T1_SPACE_OPEN_IN_DELETE_ALT = prove
 (`!top:A topology.
        t1_space top <=> !u x. open_in top u ==> open_in top (u DELETE x)`,
  REWRITE_TAC[T1_SPACE_OPEN_IN_DELETE] THEN
  MESON_TAC[SET_RULE `x IN u \/ u DELETE x = u`]);;

let T1_SPACE_SING_INTERS_OPEN,T1_SPACE_INTERS_OPEN_SUPERSETS =
 (CONJ_PAIR o prove)
 (`(!top:A topology.
      t1_space top <=>
      !x. x IN topspace top ==> INTERS {u | open_in top u /\ x IN u} = {x}) /\
   (!top:A topology.
      t1_space top <=>
      !s. s SUBSET topspace top
          ==> INTERS {u | open_in top u /\ s SUBSET u} = s)`,
  REWRITE_TAC[AND_FORALL_THM] THEN GEN_TAC THEN MATCH_MP_TAC(TAUT
   `(r ==> q) /\ (q ==> p) /\ (p ==> r)
    ==> (p <=> q) /\ (p <=> r)`) THEN
  REPEAT CONJ_TAC THENL
   [SIMP_TAC[GSYM SING_SUBSET];
    REWRITE_TAC[t1_space; INTERS_GSPEC] THEN SET_TAC[];
    REWRITE_TAC[T1_SPACE_CLOSED_IN_SING] THEN
    DISCH_TAC THEN X_GEN_TAC `s:A->bool` THEN DISCH_TAC THEN
    REWRITE_TAC[INTERS_GSPEC] THEN MATCH_MP_TAC SUBSET_ANTISYM THEN
    CONJ_TAC THENL [GEN_REWRITE_TAC I [SUBSET]; SET_TAC[]] THEN
    REWRITE_TAC[FORALL_OPEN_IN; IN_ELIM_THM; IMP_CONJ] THEN
    X_GEN_TAC `x:A` THEN DISCH_THEN(fun th ->
      MP_TAC(SPEC `{x:A}` th) THEN MP_TAC(SPEC `{}:A->bool` th)) THEN
    ASM_SIMP_TAC[CLOSED_IN_EMPTY; DIFF_EMPTY] THEN ASM SET_TAC[]]);;

let T1_SPACE_DERIVED_SET_OF_INFINITE_OPEN_IN = prove
 (`!top:A topology.
        t1_space top <=>
        !s. top derived_set_of s =
            {x | x IN topspace top /\
                 !u. x IN u /\ open_in top u ==> INFINITE(s INTER u)}`,
  GEN_TAC THEN EQ_TAC THEN DISCH_TAC THENL
   [REPEAT STRIP_TAC THEN REWRITE_TAC[EXTENSION; IN_ELIM_THM] THEN
    X_GEN_TAC `x:A` THEN EQ_TAC THENL
     [DISCH_TAC THEN CONJ_TAC THENL
       [ASM_MESON_TAC[DERIVED_SET_OF_SUBSET_TOPSPACE; SUBSET];
        X_GEN_TAC `u:A->bool` THEN REWRITE_TAC[INFINITE] THEN
        REPEAT STRIP_TAC THEN
        FIRST_ASSUM(MP_TAC o SPEC `s INTER u:A->bool` o
          REWRITE_RULE[T1_SPACE_DERIVED_SET_OF_FINITE]) THEN
        FIRST_ASSUM(MP_TAC o SPEC `s:A->bool` o MATCH_MP
         OPEN_IN_INTER_DERIVED_SET_OF_SUBSET) THEN
        ASM_REWRITE_TAC[INTER_COMM] THEN ASM SET_TAC[]];
      REWRITE_TAC[derived_set_of; IN_ELIM_THM; INFINITE; SET_RULE
       `(?y. ~(y = x) /\ y IN s /\ y IN t) <=> ~((s INTER t) SUBSET {x})`] THEN
      MESON_TAC[FINITE_SUBSET; FINITE_SING]];
    ASM_REWRITE_TAC[T1_SPACE_DERIVED_SET_OF_SING] THEN
    REWRITE_TAC[EXTENSION; NOT_IN_EMPTY; IN_ELIM_THM] THEN
    SIMP_TAC[FINITE_INTER; FINITE_SING; INFINITE] THEN
    MESON_TAC[OPEN_IN_TOPSPACE]]);;

let FINITE_T1_SPACE_IMP_DISCRETE_TOPOLOGY = prove
 (`!top u:A->bool.
        topspace top = u /\ FINITE u /\ t1_space top
        ==> top = discrete_topology u`,
  REPEAT STRIP_TAC THEN CONV_TAC SYM_CONV THEN
  ASM_REWRITE_TAC[DISCRETE_TOPOLOGY_UNIQUE_DERIVED_SET] THEN
  ASM_MESON_TAC[T1_SPACE_DERIVED_SET_OF_FINITE]);;

let T1_SPACE_SUBTOPOLOGY = prove
 (`!top u:A->bool.
        t1_space top ==> t1_space(subtopology top u)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[t1_space; TOPSPACE_SUBTOPOLOGY] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; RIGHT_EXISTS_AND_THM] THEN
  REWRITE_TAC[EXISTS_IN_GSPEC; IN_INTER] THEN MESON_TAC[]);;

let CLOSED_IN_DERIVED_SET_OF_GEN = prove
 (`!top s:A->bool. t1_space top ==> closed_in top (top derived_set_of s)`,
  REPEAT STRIP_TAC THEN
  REWRITE_TAC[CLOSED_IN_CONTAINS_DERIVED_SET] THEN
  REWRITE_TAC[DERIVED_SET_OF_SUBSET_TOPSPACE] THEN
  REWRITE_TAC[SUBSET] THEN X_GEN_TAC `x'':A` THEN
  REWRITE_TAC[IN_DERIVED_SET_OF] THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `u:A->bool`) THEN ASM_REWRITE_TAC[] THEN
  DISCH_THEN(X_CHOOSE_THEN `x':A` STRIP_ASSUME_TAC) THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [t1_space]) THEN
  DISCH_THEN(MP_TAC o SPECL [`x':A`; `x'':A`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `v:A->bool` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `u INTER v:A->bool`) THEN
  ASM_SIMP_TAC[IN_INTER; OPEN_IN_INTER] THEN ASM SET_TAC[]);;

let DERIVED_SET_OF_DERIVED_SET_SUBSET_GEN = prove
 (`!top s:A->bool.
        t1_space top
        ==> top derived_set_of (top derived_set_of s) SUBSET
            top derived_set_of s`,
  SIMP_TAC[DERIVED_SET_SUBSET; DERIVED_SET_OF_SUBSET_TOPSPACE] THEN
  REWRITE_TAC[CLOSED_IN_DERIVED_SET_OF_GEN]);;

let SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_GEN_FINITE = prove
 (`!top s:A->bool.
        t1_space top /\ FINITE s
        ==> subtopology top s = discrete_topology(topspace top INTER s)`,
  REWRITE_TAC[T1_SPACE_DERIVED_SET_OF_FINITE] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_GEN THEN
  ASM_SIMP_TAC[INTER_EMPTY]);;

let SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_FINITE = prove
 (`!top s:A->bool.
        t1_space top /\ s SUBSET topspace top /\ FINITE s
        ==> subtopology top s = discrete_topology s`,
  REWRITE_TAC[T1_SPACE_DERIVED_SET_OF_FINITE] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY THEN
  ASM_SIMP_TAC[INTER_EMPTY]);;

let T1_SPACE_CLOSED_MAP_IMAGE = prove
 (`!f:A->B top top'.
        closed_map (top,top') f /\ IMAGE f (topspace top) = topspace top' /\
        t1_space top ==> t1_space top'`,
  REPEAT GEN_TAC THEN REWRITE_TAC[T1_SPACE_CLOSED_IN_SING; closed_map] THEN
  STRIP_TAC THEN FIRST_ASSUM(SUBST1_TAC o SYM) THEN
  REWRITE_TAC[FORALL_IN_IMAGE] THEN
  ONCE_REWRITE_TAC[SET_RULE `{f x} = IMAGE f {x}`] THEN
  ASM_SIMP_TAC[]);;

let HOMEOMORPHIC_T1_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (t1_space top <=> t1_space top')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAPS_MAP; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN
  REWRITE_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP] THEN STRIP_TAC THEN
  EQ_TAC THEN MATCH_MP_TAC(ONCE_REWRITE_RULE[IMP_CONJ]
   (REWRITE_RULE[CONJ_ASSOC] T1_SPACE_CLOSED_MAP_IMAGE)) THEN
  ASM_MESON_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Hausdorff spaces.                                                         *)
(* ------------------------------------------------------------------------- *)

let hausdorff_space = new_definition
 `hausdorff_space (top:A topology) <=>
        !x y. x IN topspace top /\ y IN topspace top /\ ~(x = y)
              ==> ?u v. open_in top u /\ open_in top v /\ x IN u /\ y IN v /\
                        DISJOINT u v`;;

let HAUSDORFF_SPACE_SING_INTERS_CLOSED = prove
 (`!top:A topology.
      hausdorff_space top <=>
      !x. x IN topspace top
          ==> INTERS {u | closed_in top u /\ x IN top interior_of u} = {x}`,
  REWRITE_TAC[SET_RULE `s = {a} <=> a IN s /\ !b. ~(b = a) ==> ~(b IN s)`] THEN
  REWRITE_TAC[INTERS_GSPEC; IN_ELIM_THM; IMP_CONJ] THEN
  REWRITE_TAC[REWRITE_RULE[SUBSET] INTERIOR_OF_SUBSET] THEN
  GEN_TAC THEN REWRITE_TAC[NOT_FORALL_THM; NOT_IMP; MESON[]
   `(!x. x IN s ==> !y. ~(y = x) ==> R x y) <=>
    (!x y. x IN s /\ ~(y IN s) ==> R x y) /\
    (!y x. y IN s /\ x IN s /\ ~(y = x) ==> R x y)`] THEN
  MATCH_MP_TAC(TAUT `q /\ (p <=> r) ==> (p <=> q /\ r)`) THEN CONJ_TAC THENL
   [MESON_TAC[CLOSED_IN_TOPSPACE; INTERIOR_OF_TOPSPACE]; ALL_TAC] THEN
  REWRITE_TAC[hausdorff_space; EXISTS_CLOSED_IN] THEN
  SIMP_TAC[INTERIOR_OF_COMPLEMENT; IN_DIFF; RIGHT_EXISTS_AND_THM] THEN
  SIMP_TAC[closure_of; IN_ELIM_THM] THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN SET_TAC[]);;

let HAUSDORFF_SPACE_SUBTOPOLOGY = prove
 (`!top s:A->bool.
        hausdorff_space top ==> hausdorff_space(subtopology top s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[hausdorff_space; TOPSPACE_SUBTOPOLOGY] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; RIGHT_EXISTS_AND_THM] THEN
  REWRITE_TAC[EXISTS_IN_GSPEC; IN_INTER] THEN
  REPEAT(MATCH_MP_TAC MONO_FORALL THEN GEN_TAC) THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC THEN
  MATCH_MP_TAC MONO_AND THEN REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN SET_TAC[]);;

let HAUSDORFF_IMP_T1_SPACE = prove
 (`!top:A topology. hausdorff_space top ==> t1_space top`,
  REWRITE_TAC[hausdorff_space; t1_space] THEN SET_TAC[]);;

let T1_OR_HAUSDORFF_SPACE = prove
 (`!top:A topology.
        t1_space top \/ hausdorff_space top <=> t1_space top`,
  MESON_TAC[HAUSDORFF_IMP_T1_SPACE]);;

let HAUSDORFF_SPACE_MTOPOLOGY = prove
 (`!m:A metric. hausdorff_space(mtopology m)`,
  REWRITE_TAC[hausdorff_space; TOPSPACE_MTOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`m:A metric`; `x:A`; `y:A`] THEN STRIP_TAC THEN
  EXISTS_TAC `mball m (x:A,mdist m (x,y) / &2)` THEN
  EXISTS_TAC `mball m (y:A,mdist m (x,y) / &2)` THEN
  REWRITE_TAC[SET_RULE `DISJOINT s t <=> !x. x IN s /\ x IN t ==> F`] THEN
  REWRITE_TAC[OPEN_IN_MBALL; IN_MBALL] THEN
  POP_ASSUM_LIST(MP_TAC o end_itlist CONJ) THEN CONV_TAC METRIC_ARITH);;

let T1_SPACE_MTOPOLOGY = prove
 (`!m:A metric. t1_space(mtopology m)`,
  SIMP_TAC[HAUSDORFF_IMP_T1_SPACE; HAUSDORFF_SPACE_MTOPOLOGY]);;

let METRIZABLE_IMP_HAUSDORFF_SPACE = prove
 (`!top. metrizable_space top ==> hausdorff_space top`,
  MESON_TAC[metrizable_space; HAUSDORFF_SPACE_MTOPOLOGY]);;

let METRIZABLE_IMP_T1_SPACE = prove
 (`!top. metrizable_space top ==> t1_space top`,
  MESON_TAC[HAUSDORFF_IMP_T1_SPACE; METRIZABLE_IMP_HAUSDORFF_SPACE]);;

let HAUSDORFF_SPACE_SING_INTERS_OPENS = prove
 (`!top a:A.
        hausdorff_space top /\ a IN topspace top
        ==> INTERS {u | open_in top u /\ a IN u} =  {a}`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[GSYM T1_SPACE_SING_INTERS_OPEN] THEN
  REWRITE_TAC[HAUSDORFF_IMP_T1_SPACE]);;

let HAUSDORFF_SPACE_COMPACT_SEPARATION = prove
 (`!top s t:A->bool.
        hausdorff_space top /\
        compact_in top s /\ compact_in top t /\ DISJOINT s t
        ==> ?u v. open_in top u /\ open_in top v /\
                  s SUBSET u /\ t SUBSET v /\ DISJOINT u v`,
  let lemma = prove
   (`!top s a:A.
        hausdorff_space top /\ compact_in top s /\
        a IN topspace top /\ ~(a IN s)
        ==> ?u v. open_in top u /\ open_in top v /\ DISJOINT u v /\
                  a IN u /\ s SUBSET v`,
    REWRITE_TAC[hausdorff_space; compact_in] THEN REPEAT STRIP_TAC THEN
    ASM_CASES_TAC `s:A->bool = {}` THENL
     [MAP_EVERY EXISTS_TAC [`topspace top:A->bool`; `{}:A->bool`] THEN
      ASM_REWRITE_TAC[OPEN_IN_TOPSPACE; OPEN_IN_EMPTY] THEN ASM SET_TAC[];
      ALL_TAC] THEN
    FIRST_X_ASSUM(MP_TAC o GEN `x:A` o SPECL [`x:A`; `a:A`]) THEN
    ASM_REWRITE_TAC[] THEN
    GEN_REWRITE_TAC (LAND_CONV o TOP_DEPTH_CONV) [RIGHT_IMP_EXISTS_THM] THEN
    REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->A->bool`; `v:A->A->bool`] THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (u:A->A->bool) s`) THEN
    REWRITE_TAC[FORALL_IN_IMAGE; EXISTS_FINITE_SUBSET_IMAGE] THEN
    ANTS_TAC THENL [SIMP_TAC[UNIONS_IMAGE] THEN ASM SET_TAC[]; ALL_TAC] THEN
    REWRITE_TAC[UNIONS_IMAGE; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `k:A->bool` THEN STRIP_TAC THEN
    EXISTS_TAC `INTERS(IMAGE (v:A->A->bool) k)` THEN
    EXISTS_TAC `UNIONS(IMAGE (u:A->A->bool) k)` THEN
    CONJ_TAC THENL
     [MATCH_MP_TAC OPEN_IN_INTERS THEN ASM_SIMP_TAC[FINITE_IMAGE] THEN
      ASM SET_TAC[];
      CONJ_TAC THENL [MATCH_MP_TAC OPEN_IN_UNIONS; ALL_TAC] THEN
      ASM SET_TAC[]]) in
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `s:A->bool = {}` THENL
   [MAP_EVERY EXISTS_TAC [`{}:A->bool`; `topspace top:A->bool`] THEN
    ASM_REWRITE_TAC[OPEN_IN_TOPSPACE; OPEN_IN_EMPTY] THEN
    ASM_SIMP_TAC[COMPACT_IN_SUBSET_TOPSPACE] THEN ASM SET_TAC[];
    ALL_TAC] THEN
  SUBGOAL_THEN
   `!x:A. ?u v.
        x IN s ==> open_in top u /\ open_in top v /\
                   x IN u /\ t SUBSET v /\ DISJOINT u v`
  MP_TAC THENL
   [X_GEN_TAC `x:A` THEN REWRITE_TAC[RIGHT_EXISTS_IMP_THM] THEN DISCH_TAC THEN
    MP_TAC(ISPECL [`top:A topology`; `t:A->bool`; `x:A`]
        lemma) THEN
    ANTS_TAC THENL [ASM_REWRITE_TAC[]; MESON_TAC[]] THEN
    REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP COMPACT_IN_SUBSET_TOPSPACE)) THEN
    ASM SET_TAC[];
    REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
  MAP_EVERY X_GEN_TAC [`u:A->A->bool`; `v:A->A->bool`] THEN DISCH_TAC THEN
  UNDISCH_TAC `compact_in top (s:A->bool)` THEN REWRITE_TAC[compact_in] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
   (MP_TAC o SPEC `IMAGE (u:A->A->bool) s`)) THEN
  REWRITE_TAC[FORALL_IN_IMAGE; EXISTS_FINITE_SUBSET_IMAGE] THEN
  ANTS_TAC THENL [SIMP_TAC[UNIONS_IMAGE] THEN ASM SET_TAC[]; ALL_TAC] THEN
  REWRITE_TAC[UNIONS_IMAGE; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `k:A->bool` THEN STRIP_TAC THEN
  EXISTS_TAC `UNIONS(IMAGE (u:A->A->bool) k)` THEN
  EXISTS_TAC `INTERS(IMAGE (v:A->A->bool) k)` THEN
  CONJ_TAC THENL [MATCH_MP_TAC OPEN_IN_UNIONS THEN ASM SET_TAC[]; ALL_TAC] THEN
  CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
  MATCH_MP_TAC OPEN_IN_INTERS THEN ASM_SIMP_TAC[FINITE_IMAGE] THEN
  ASM SET_TAC[]);;

let HAUSDORFF_SPACE_COMPACT_SETS = prove
 (`!top:A topology.
        hausdorff_space top <=>
        !s t. compact_in top s /\ compact_in top t /\ DISJOINT s t
              ==> ?u v. open_in top u /\ open_in top v /\
                        s SUBSET u /\ t SUBSET v /\ DISJOINT u v`,
  GEN_TAC THEN EQ_TAC THEN SIMP_TAC[HAUSDORFF_SPACE_COMPACT_SEPARATION] THEN
  DISCH_TAC THEN REWRITE_TAC[hausdorff_space] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`{x:A}`; `{y:A}`]) THEN
  ASM_REWRITE_TAC[SING_SUBSET; COMPACT_IN_SING] THEN
  ANTS_TAC THENL [ASM SET_TAC[]; MESON_TAC[]]);;

let COMPACT_IN_IMP_CLOSED_IN = prove
 (`!top s:A->bool.
        hausdorff_space top /\ compact_in top s ==> closed_in top s`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP COMPACT_IN_SUBSET_TOPSPACE) THEN
  ASM_REWRITE_TAC[closed_in] THEN
  GEN_REWRITE_TAC I [OPEN_IN_SUBOPEN] THEN
  X_GEN_TAC `y:A` THEN REWRITE_TAC[IN_DIFF] THEN STRIP_TAC THEN
  MP_TAC(ISPECL [`top:A topology`; `{y:A}`; `s:A->bool`]
    HAUSDORFF_SPACE_COMPACT_SEPARATION) THEN
  ASM_REWRITE_TAC[COMPACT_IN_SING] THEN
  ANTS_TAC THENL [ASM SET_TAC[]; MATCH_MP_TAC MONO_EXISTS] THEN
  REPEAT STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  REPEAT(FIRST_X_ASSUM(ASSUME_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
  ASM SET_TAC[]);;

let CLOSED_IN_HAUSDORFF_SING = prove
 (`!top x:A. hausdorff_space top /\ x IN topspace top ==> closed_in top {x}`,
  MESON_TAC[COMPACT_IN_IMP_CLOSED_IN; FINITE_IMP_COMPACT_IN; FINITE_SING;
            SING_SUBSET]);;

let CLOSED_IN_HAUSDORFF_SING_EQ = prove
 (`!top x:A. hausdorff_space top
             ==> (closed_in top {x} <=> x IN topspace top)`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN ASM_SIMP_TAC[CLOSED_IN_HAUSDORFF_SING] THEN
  DISCH_THEN(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN SET_TAC[]);;

let CLOSED_IN_DERIVED_SET_OF = prove
 (`!(top:A topology) s.
        hausdorff_space top ==> closed_in top (top derived_set_of s)`,
  MESON_TAC[CLOSED_IN_DERIVED_SET_OF_GEN; HAUSDORFF_IMP_T1_SPACE]);;

let HAUSDORFF_SPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. hausdorff_space(discrete_topology u)`,
  GEN_TAC THEN REWRITE_TAC[hausdorff_space; OPEN_IN_DISCRETE_TOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN
  REWRITE_TAC[TOPSPACE_DISCRETE_TOPOLOGY] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC [`{x:A}`; `{y:A}`] THEN ASM SET_TAC[]);;

let COMPACT_IN_INTER = prove
 (`!top s t:A->bool.
        hausdorff_space top /\ compact_in top s /\ compact_in top t
        ==> compact_in top (s INTER t)`,
  MESON_TAC[COMPACT_IN_IMP_CLOSED_IN; COMPACT_INTER_CLOSED_IN]);;

let FINITE_TOPSPACE_IMP_DISCRETE_TOPOLOGY = prove
 (`!top:A topology.
        topspace top = u /\ FINITE u /\ hausdorff_space top
        ==> top = discrete_topology u`,
  ASM_MESON_TAC[HAUSDORFF_IMP_T1_SPACE;
                FINITE_T1_SPACE_IMP_DISCRETE_TOPOLOGY]);;

let DERIVED_SET_OF_FINITE = prove
 (`!top s:A->bool.
        hausdorff_space top /\ FINITE s ==> top derived_set_of s = {}`,
  MESON_TAC[T1_SPACE_DERIVED_SET_OF_FINITE; HAUSDORFF_IMP_T1_SPACE]);;

let DERIVED_SET_OF_SING = prove
 (`!top x:A. hausdorff_space top ==> top derived_set_of {x} = {}`,
  SIMP_TAC[DERIVED_SET_OF_FINITE; FINITE_SING]);;

let CLOSED_IN_HAUSDORFF_FINITE = prove
 (`!top s:A->bool.
        hausdorff_space top /\ s SUBSET topspace top /\ FINITE s
        ==> closed_in top s`,
  MESON_TAC[T1_SPACE_CLOSED_IN_FINITE; HAUSDORFF_IMP_T1_SPACE]);;

let OPEN_IN_HAUSDORFF_DELETE = prove
 (`!top s x:A.
        hausdorff_space top /\ open_in top s ==> open_in top (s DELETE x)`,
  MESON_TAC[T1_SPACE_OPEN_IN_DELETE_ALT; HAUSDORFF_IMP_T1_SPACE]);;

let CLOSED_IN_HAUSDORFF_FINITE_EQ = prove
 (`!top s:A->bool.
        hausdorff_space top /\ FINITE s
        ==> (closed_in top s <=> s SUBSET topspace top)`,
  MESON_TAC[CLOSED_IN_HAUSDORFF_FINITE; CLOSED_IN_SUBSET]);;

let DERIVED_SET_OF_INFINITE_OPEN_IN = prove
 (`!top s:A->bool.
        hausdorff_space top
        ==> top derived_set_of s =
            {x | x IN topspace top /\
                 !u. x IN u /\ open_in top u ==> INFINITE(s INTER u)}`,
  REWRITE_TAC[RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[GSYM T1_SPACE_DERIVED_SET_OF_INFINITE_OPEN_IN] THEN
  REWRITE_TAC[HAUSDORFF_IMP_T1_SPACE]);;

let DERIVED_SET_OF_INFINITE_OPEN_IN_METRIC = prove
 (`!m s:A->bool.
        mtopology m derived_set_of s =
        {x | x IN mspace m /\
             !u. x IN u /\ open_in (mtopology m) u ==> INFINITE(s INTER u)}`,
  SIMP_TAC[DERIVED_SET_OF_INFINITE_OPEN_IN; HAUSDORFF_SPACE_MTOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY]);;

let DERIVED_SET_OF_INFINITE_MBALL,DERIVED_SET_OF_INFINITE_MCBALL =
 (CONJ_PAIR o prove)
 (`(!m s:A->bool.
        mtopology m derived_set_of s =
        {x | x IN mspace m /\
             !e. &0 < e ==> INFINITE(s INTER mball m (x,e))}) /\
   (!m s:A->bool.
        mtopology m derived_set_of s =
        {x | x IN mspace m /\
             !e. &0 < e ==> INFINITE(s INTER mcball m (x,e))})`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  REWRITE_TAC[EXTENSION; DERIVED_SET_OF_INFINITE_OPEN_IN_METRIC] THEN
  REWRITE_TAC[IN_ELIM_THM; AND_FORALL_THM] THEN X_GEN_TAC `x:A` THEN
  ASM_CASES_TAC `(x:A) IN mspace m` THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC(TAUT
   `(q ==> r) /\ (r ==> p) /\ (p ==> q) ==> (p <=> q) /\ (p <=> r)`) THEN
  ASM_SIMP_TAC[OPEN_IN_MBALL; CENTRE_IN_MBALL] THEN CONJ_TAC THENL
   [MATCH_MP_TAC MONO_FORALL THEN GEN_TAC THEN
    MATCH_MP_TAC MONO_IMP THEN REWRITE_TAC[];
    REPEAT STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_MTOPOLOGY_MCBALL]) THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `x:A`)) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `e:real` THEN
    DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC `e:real`)] THEN
  ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] INFINITE_SUPERSET) THEN
  MATCH_MP_TAC(SET_RULE `t SUBSET u ==> s INTER t SUBSET s INTER u`) THEN
  ASM_REWRITE_TAC[MBALL_SUBSET_MCBALL]);;

let HAUSDORFF_SPACE_DISCRETE_COMPACT_IN = prove
 (`!top s:A->bool.
        hausdorff_space top
        ==> (s INTER top derived_set_of s = {} /\ compact_in top s <=>
             s SUBSET topspace top /\ FINITE s)`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [ASM_MESON_TAC[DISCRETE_COMPACT_IN_EQ_FINITE]; STRIP_TAC] THEN
  ASM_SIMP_TAC[FINITE_IMP_COMPACT_IN] THEN
  MP_TAC(ISPECL [`top:A topology`; `s:A->bool`]
    SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_EQ) THEN
  ASM_REWRITE_TAC[] THEN DISCH_THEN(SUBST1_TAC o SYM) THEN
  MATCH_MP_TAC FINITE_TOPSPACE_IMP_DISCRETE_TOPOLOGY THEN
  ASM_SIMP_TAC[HAUSDORFF_SPACE_SUBTOPOLOGY; TOPSPACE_SUBTOPOLOGY] THEN
  ASM SET_TAC[]);;

let HAUSDORFF_SPACE_FINITE_TOPSPACE = prove
 (`!top:A topology.
        hausdorff_space top
        ==> (top derived_set_of (topspace top) = {} /\ compact_space top <=>
             FINITE(topspace top))`,
  GEN_TAC THEN
  DISCH_THEN(MP_TAC o SPEC `topspace top:A->bool` o MATCH_MP
    HAUSDORFF_SPACE_DISCRETE_COMPACT_IN) THEN
  REWRITE_TAC[SUBSET_REFL] THEN DISCH_THEN(SUBST1_TAC o SYM) THEN
  REWRITE_TAC[GSYM compact_space] THEN
  REWRITE_TAC[derived_set_of] THEN SET_TAC[]);;

let DERIVED_SET_OF_DERIVED_SET_SUBSET = prove
 (`!top s:A->bool.
        hausdorff_space top
        ==> top derived_set_of (top derived_set_of s) SUBSET
            top derived_set_of s`,
  SIMP_TAC[DERIVED_SET_OF_DERIVED_SET_SUBSET_GEN;
           HAUSDORFF_IMP_T1_SPACE]);;

let HAUSDORFF_SPACE_INJECTIVE_PREIMAGE = prove
 (`!top top' f:A->B.
       continuous_map (top,top') f /\
       (!x y. x IN topspace top /\ y IN topspace top /\ f x = f y ==> x = y) /\
       hausdorff_space top'
       ==> hausdorff_space top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[hausdorff_space; continuous_map] THEN
  REWRITE_TAC[INJECTIVE_ON_ALT] THEN
  STRIP_TAC THEN MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`(f:A->B) x`; `(f:A->B) y`]) THEN
  ASM_SIMP_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:B->bool`; `v:B->bool`] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC
   [`{x | x IN topspace top /\ (f:A->B) x IN u}`;
    `{x | x IN topspace top /\ (f:A->B) x IN v}`] THEN
  ASM_SIMP_TAC[] THEN ASM SET_TAC[]);;

let HOMEOMORPHIC_HAUSDORFF_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (hausdorff_space top <=> hausdorff_space top')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAPS_MAP; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN
  REWRITE_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP] THEN STRIP_TAC THEN
  EQ_TAC THEN MATCH_MP_TAC(ONCE_REWRITE_RULE[IMP_CONJ]
   (REWRITE_RULE[CONJ_ASSOC] HAUSDORFF_SPACE_INJECTIVE_PREIMAGE)) THEN
  ASM_MESON_TAC[]);;

let COMPACT_HAUSDORFF_SPACE_OPTIMAL = prove
 (`!top top':A topology.
        topspace top' = topspace top /\
        (!u. open_in top u ==> open_in top' u) /\
        hausdorff_space top /\ compact_space top'
        ==> top' = top`,
  REPEAT STRIP_TAC THEN ASM_REWRITE_TAC[TOPOLOGY_EQ; FORALL_AND_THM; TAUT
   `(p <=> q) <=> (p ==> q) /\ (q ==> p)`] THEN
  ASM_SIMP_TAC[TOPOLOGY_FINER_CLOSED_IN] THEN
  X_GEN_TAC `c:A->bool` THEN DISCH_TAC THEN
  MATCH_MP_TAC COMPACT_IN_IMP_CLOSED_IN THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_IMP; RIGHT_IMP_FORALL_THM]
        COMPACT_IN_CONTRACTIVE) THEN
  EXISTS_TAC `top':A topology` THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC CLOSED_IN_COMPACT_SPACE THEN
  ASM_REWRITE_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Regular spaces. These are *not* a priori assumed to be Hausdorff/T_1.     *)
(* ------------------------------------------------------------------------- *)

let regular_space = new_definition
 `regular_space top <=>
        !c a:A. closed_in top c /\ a IN topspace top DIFF c
                ==> ?u v. open_in top u /\ open_in top v /\
                          a IN u /\ c SUBSET v /\ DISJOINT u v`;;

let HOMEOMORPHIC_REGULAR_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (regular_space top <=> regular_space top')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAPS_MAP; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN DISCH_TAC THEN
  REWRITE_TAC[regular_space; IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[RIGHT_EXISTS_AND_THM] THEN REWRITE_TAC[MESON[]
   `(?x. P x /\ Q x) <=> ~(!x. P x ==> ~Q x)`] THEN
  FIRST_ASSUM(MP_TAC o CONJUNCT1) THEN DISCH_THEN(fun th ->
    REWRITE_TAC[MATCH_MP FORALL_OPEN_IN_HOMEOMORPHIC_IMAGE th] THEN
    REWRITE_TAC[MATCH_MP FORALL_CLOSED_IN_HOMEOMORPHIC_IMAGE th]) THEN
  RULE_ASSUM_TAC(REWRITE_RULE[HOMEOMORPHIC_EQ_EVERYTHING_MAP]) THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `c:A->bool` THEN ASM_CASES_TAC `closed_in top (c:A->bool)` THEN
  ASM_REWRITE_TAC[] THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
  SUBGOAL_THEN
   `topspace top' DIFF IMAGE (f:A->B) c = IMAGE f (topspace top DIFF c)`
  SUBST1_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[FORALL_IN_IMAGE]] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `a:A` THEN ASM_CASES_TAC `(a:A) IN topspace top DIFF c` THEN
  ASM_REWRITE_TAC[NOT_FORALL_THM; NOT_IMP; RIGHT_AND_EXISTS_THM] THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN ONCE_REWRITE_TAC[CONJ_ASSOC] THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
  DISCH_THEN(CONJUNCTS_THEN(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
  ASM SET_TAC[]);;

let REGULAR_SPACE = prove
 (`!top:A topology.
        regular_space top <=>
        !c a. closed_in top c /\ a IN topspace top DIFF c
              ==> ?u. open_in top u /\ a IN u /\
                      DISJOINT c (top closure_of u)`,
  GEN_TAC THEN REWRITE_TAC[regular_space] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `s:A->bool` THEN REWRITE_TAC[] THEN AP_TERM_TAC THEN
  GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `a:A` THEN
  REWRITE_TAC[] THEN MATCH_MP_TAC(TAUT
   `(p ==> (q <=> r)) ==> (p ==> q <=> p ==> r)`) THEN STRIP_TAC THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `u:A->bool` THEN REWRITE_TAC[] THEN EQ_TAC THENL
   [DISCH_THEN(X_CHOOSE_THEN `v:A->bool` STRIP_ASSUME_TAC) THEN
    ASM_REWRITE_TAC[] THEN FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
     `t SUBSET v ==> v INTER c = {} ==> DISJOINT t c`)) THEN
    ASM_SIMP_TAC[OPEN_IN_INTER_CLOSURE_OF_EQ_EMPTY] THEN ASM SET_TAC[];
    STRIP_TAC THEN EXISTS_TAC `topspace top DIFF top closure_of u:A->bool` THEN
    ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE; CLOSED_IN_CLOSURE_OF] THEN
    MP_TAC(ISPECL [`top:A topology`; `u:A->bool`] CLOSURE_OF_SUBSET) THEN
    REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
    FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]]);;

let NEIGHBOURHOOD_BASE_OF_CLOSED_IN = prove
 (`!top:A topology.
      neighbourhood_base_of (closed_in top) top <=> regular_space top`,
  GEN_TAC THEN REWRITE_TAC[NEIGHBOURHOOD_BASE_OF; regular_space] THEN
  ONCE_REWRITE_TAC[SWAP_FORALL_THM] THEN
  REWRITE_TAC[IMP_CONJ; FORALL_OPEN_IN] THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN REPEAT
   (MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> ((p ==> q) <=> (p ==> r))`) THEN
    DISCH_TAC) THEN
  FIRST_X_ASSUM(ASSUME_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
  REWRITE_TAC[RIGHT_EXISTS_AND_THM] THEN REWRITE_TAC[EXISTS_CLOSED_IN] THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC THEN
   MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
   DISCH_THEN(ASSUME_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
  ASM SET_TAC[]);;

let REGULAR_SPACE_DISCRETE_TOPOLOGY = prove
 (`!s:A->bool. regular_space(discrete_topology s)`,
  GEN_TAC THEN
  REWRITE_TAC[regular_space; CLOSED_IN_DISCRETE_TOPOLOGY] THEN
  REWRITE_TAC[OPEN_IN_DISCRETE_TOPOLOGY; TOPSPACE_DISCRETE_TOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`c:A->bool`; `a:A`] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC [`{a:A}`; `c:A->bool`] THEN ASM SET_TAC[]);;

let REGULAR_SPACE_SUBTOPOLOGY = prove
 (`!top s:A->bool.
        regular_space top ==> regular_space(subtopology top s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[regular_space] THEN DISCH_TAC THEN
  REWRITE_TAC[RIGHT_FORALL_IMP_THM; IMP_CONJ; RIGHT_EXISTS_AND_THM] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; CLOSED_IN_SUBTOPOLOGY_ALT] THEN
  REWRITE_TAC[FORALL_IN_GSPEC; EXISTS_IN_GSPEC; TOPSPACE_SUBTOPOLOGY] THEN
  X_GEN_TAC `c:A->bool` THEN DISCH_TAC THEN REWRITE_TAC[IN_DIFF; IN_INTER] THEN
  X_GEN_TAC `a:A` THEN STRIP_TAC THEN REWRITE_TAC[RIGHT_AND_EXISTS_THM] THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`c:A->bool`; `a:A`]) THEN
  ANTS_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN ASM SET_TAC[]);;

let REGULAR_T1_IMP_HAUSDORFF_SPACE = prove
 (`!top:A topology.
        regular_space top /\ t1_space top ==> hausdorff_space top`,
  REWRITE_TAC[T1_SPACE_CLOSED_IN_SING; regular_space; hausdorff_space] THEN
  GEN_TAC THEN STRIP_TAC THEN MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN
  STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`{y:A}`; `x:A`]) THEN
  ASM_SIMP_TAC[IN_DIFF; IN_SING; SING_SUBSET]);;

let REGULAR_T1_EQ_HAUSDORFF_SPACE = prove
 (`!top:A topology.
        regular_space top ==> (t1_space top <=> hausdorff_space top)`,
  MESON_TAC[REGULAR_T1_IMP_HAUSDORFF_SPACE; HAUSDORFF_IMP_T1_SPACE]);;

let COMPACT_HAUSDORFF_IMP_REGULAR_SPACE = prove
 (`!top:A topology.
        compact_space top /\ hausdorff_space top ==> regular_space top`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[regular_space; IN_DIFF] THEN
  MAP_EVERY X_GEN_TAC [`s:A->bool`; `a:A`] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [HAUSDORFF_SPACE_COMPACT_SETS]) THEN
  DISCH_THEN(MP_TAC o SPECL [`{a:A}`; `s:A->bool`]) THEN
  ASM_SIMP_TAC[CLOSED_IN_COMPACT_SPACE; COMPACT_IN_SING] THEN
  ANTS_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN ASM SET_TAC[]);;

let REGULAR_SPACE_MTOPOLOGY = prove
 (`!m:A metric. regular_space(mtopology m)`,
  GEN_TAC THEN REWRITE_TAC[regular_space] THEN
  MAP_EVERY X_GEN_TAC [`c:A->bool`; `a:A`] THEN STRIP_TAC THEN
  SUBGOAL_THEN `open_in (mtopology m) (topspace(mtopology m) DIFF c:A->bool)`
  MP_TAC THENL [ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE]; ALL_TAC] THEN
  GEN_REWRITE_TAC (LAND_CONV o ONCE_DEPTH_CONV) [OPEN_IN_MTOPOLOGY] THEN
  DISCH_THEN(MP_TAC o SPEC `a:A` o CONJUNCT2) THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; TOPSPACE_MTOPOLOGY] THEN
  X_GEN_TAC `r:real` THEN STRIP_TAC THEN
  EXISTS_TAC `mball m (a:A,r / &2)` THEN
  EXISTS_TAC `topspace(mtopology m) DIFF mcball m (a:A,r / &2)` THEN
  RULE_ASSUM_TAC(REWRITE_RULE[IN_DIFF; TOPSPACE_MTOPOLOGY]) THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; CLOSED_IN_MCBALL; OPEN_IN_MBALL; OPEN_IN_TOPSPACE;
               CENTRE_IN_MBALL; REAL_HALF] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN CONJ_TAC THENL
   [FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
     `b SUBSET m DIFF c
      ==> c SUBSET m /\ b' SUBSET b  ==> c SUBSET m DIFF b'`)) THEN
    CONJ_TAC THENL
     [ASM_MESON_TAC[CLOSED_IN_SUBSET; TOPSPACE_MTOPOLOGY];
      ASM_SIMP_TAC[SUBSET; IN_MBALL; IN_MCBALL] THEN ASM_REAL_ARITH_TAC];
    MATCH_MP_TAC(SET_RULE
     `(!x. x IN s ==> x IN t) ==> DISJOINT s (u DIFF t)`) THEN
    ASM_SIMP_TAC[SUBSET; IN_MBALL; IN_MCBALL] THEN ASM_REAL_ARITH_TAC]);;

let METRIZABLE_IMP_REGULAR_SPACE = prove
 (`!top:A topology. metrizable_space top ==> regular_space top`,
  MESON_TAC[metrizable_space; REGULAR_SPACE_MTOPOLOGY]);;

let REGULAR_SPACE_COMPACT_CLOSED_SEPARATION = prove
 (`!top s t:A->bool.
        regular_space top /\
        compact_in top s /\ closed_in top t /\ DISJOINT s t
        ==> ?u v. open_in top u /\ open_in top v /\
                  s SUBSET u /\ t SUBSET v /\ DISJOINT u v`,
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `s:A->bool = {}` THENL
   [MAP_EVERY EXISTS_TAC [`{}:A->bool`; `topspace top:A->bool`] THEN
    ASM_REWRITE_TAC[OPEN_IN_TOPSPACE; OPEN_IN_EMPTY] THEN
    ASM_SIMP_TAC[CLOSED_IN_SUBSET] THEN ASM SET_TAC[];
    ALL_TAC] THEN
  SUBGOAL_THEN
   `!x:A. ?u v.
        x IN s ==> open_in top u /\ open_in top v /\
                   x IN u /\ t SUBSET v /\ DISJOINT u v`
  MP_TAC THENL
   [X_GEN_TAC `x:A` THEN ASM_CASES_TAC `(x:A) IN s` THEN ASM_REWRITE_TAC[] THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`t:A->bool`; `x:A`] o
        REWRITE_RULE[regular_space]) THEN
    ASM_REWRITE_TAC[IN_DIFF] THEN DISCH_THEN MATCH_MP_TAC THEN
    FIRST_ASSUM(MP_TAC o MATCH_MP COMPACT_IN_SUBSET_TOPSPACE) THEN
    ASM SET_TAC[];
    REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
  MAP_EVERY X_GEN_TAC [`u:A->A->bool`; `v:A->A->bool`] THEN DISCH_TAC THEN
  UNDISCH_TAC `compact_in top (s:A->bool)` THEN REWRITE_TAC[compact_in] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
   (MP_TAC o SPEC `IMAGE (u:A->A->bool) s`)) THEN
  REWRITE_TAC[FORALL_IN_IMAGE; EXISTS_FINITE_SUBSET_IMAGE] THEN
  ANTS_TAC THENL [SIMP_TAC[UNIONS_IMAGE] THEN ASM SET_TAC[]; ALL_TAC] THEN
  REWRITE_TAC[UNIONS_IMAGE; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `k:A->bool` THEN STRIP_TAC THEN
  EXISTS_TAC `UNIONS(IMAGE (u:A->A->bool) k)` THEN
  EXISTS_TAC `INTERS(IMAGE (v:A->A->bool) k)` THEN
  CONJ_TAC THENL [MATCH_MP_TAC OPEN_IN_UNIONS THEN ASM SET_TAC[]; ALL_TAC] THEN
  CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
  MATCH_MP_TAC OPEN_IN_INTERS THEN ASM_SIMP_TAC[FINITE_IMAGE] THEN
  ASM SET_TAC[]);;

let REGULAR_SPACE_COMPACT_CLOSED_SETS = prove
 (`!top:A topology.
        regular_space top <=>
        !s t. compact_in top s /\ closed_in top t /\ DISJOINT s t
              ==> ?u v. open_in top u /\ open_in top v /\
                        s SUBSET u /\ t SUBSET v /\ DISJOINT u v`,
  GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC[REGULAR_SPACE_COMPACT_CLOSED_SEPARATION] THEN
  DISCH_TAC THEN REWRITE_TAC[regular_space] THEN
  MAP_EVERY X_GEN_TAC [`s:A->bool`;` x:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`{x:A}`; `s:A->bool`]) THEN
  ASM_REWRITE_TAC[SING_SUBSET; COMPACT_IN_SING] THEN
  ANTS_TAC THENL [ASM SET_TAC[]; MESON_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* Locally compact spaces.                                                   *)
(* ------------------------------------------------------------------------- *)

let locally_compact_space = new_definition
 `locally_compact_space top <=>
    !x. x IN topspace top
        ==> ?u k. open_in top u /\ compact_in top k /\ x IN u /\ u SUBSET k`;;

let HOMEOMORPHIC_LOCALLY_COMPACT_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (locally_compact_space top <=> locally_compact_space top')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAPS_MAP; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN DISCH_TAC THEN
  REWRITE_TAC[locally_compact_space] THEN
  SUBGOAL_THEN `topspace top' = IMAGE (f:A->B) (topspace top)` SUBST1_TAC THENL
   [ASM_MESON_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP];
    REWRITE_TAC[FORALL_IN_IMAGE; RIGHT_EXISTS_AND_THM]] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `a:A` THEN ASM_CASES_TAC `(a:A) IN topspace top` THEN
  ASM_REWRITE_TAC[] THEN ONCE_REWRITE_TAC[MESON[]
   `(?x. P x /\ Q x) <=> ~(!x. P x ==> ~Q x)`] THEN
  FIRST_ASSUM(MP_TAC o CONJUNCT1) THEN DISCH_THEN(fun th ->
    REWRITE_TAC[MATCH_MP FORALL_OPEN_IN_HOMEOMORPHIC_IMAGE th]) THEN
  AP_TERM_TAC THEN AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `u:A->bool` THEN
  ASM_CASES_TAC `open_in top (u:A->bool)` THEN ASM_REWRITE_TAC[] THEN
  AP_TERM_TAC THEN REWRITE_TAC[COMPACT_IN_SUBSPACE] THEN
  SUBGOAL_THEN `topspace top' = IMAGE (f:A->B) (topspace top)` SUBST1_TAC THENL
   [ASM_MESON_TAC[HOMEOMORPHIC_EQ_EVERYTHING_MAP];
    REWRITE_TAC[GSYM CONJ_ASSOC; EXISTS_SUBSET_IMAGE]] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `k:A->bool` THEN
  ASM_CASES_TAC `(k:A->bool) SUBSET topspace top` THEN
  ASM_REWRITE_TAC[] THEN BINOP_TAC THENL
   [MATCH_MP_TAC HOMEOMORPHIC_COMPACT_SPACE THEN
    REWRITE_TAC[homeomorphic_space; GSYM HOMEOMORPHIC_MAP_MAPS] THEN
    EXISTS_TAC `f:A->B` THEN MATCH_MP_TAC HOMEOMORPHIC_MAP_SUBTOPOLOGIES THEN
    ASM_REWRITE_TAC[] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[HOMEOMORPHIC_EQ_EVERYTHING_MAP]) THEN
    ASM SET_TAC[];
    FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
    ASM SET_TAC[]]);;

let COMPACT_IMP_LOCALLY_COMPACT_SPACE = prove
 (`!top:A topology. compact_space top ==> locally_compact_space top`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[locally_compact_space] THEN
  REPEAT STRIP_TAC THEN REPEAT(EXISTS_TAC `topspace top:A->bool`) THEN
  ASM_REWRITE_TAC[GSYM compact_space; OPEN_IN_TOPSPACE; SUBSET_REFL]);;

let NEIGHBOURHOOD_BASE_IMP_LOCALLY_COMPACT_SPACE = prove
 (`!top:A topology.
         neighbourhood_base_of (compact_in top) top
         ==> locally_compact_space top`,
  REWRITE_TAC[locally_compact_space; NEIGHBOURHOOD_BASE_OF] THEN
  MESON_TAC[OPEN_IN_TOPSPACE]);;

let (LOCALLY_COMPACT_SPACE_NEIGHBOURHOOD_BASE,
     LOCALLY_COMPACT_HAUSDORFF_IMP_REGULAR_SPACE) = (CONJ_PAIR o prove)
 (`(!top:A topology.
        hausdorff_space top \/ regular_space top
        ==> (locally_compact_space top <=>
             neighbourhood_base_of (compact_in top) top)) /\
   (!top:A topology.
        locally_compact_space top /\ hausdorff_space top
        ==> regular_space top)`,
  REWRITE_TAC[AND_FORALL_THM] THEN GEN_TAC THEN MATCH_MP_TAC(TAUT
   `(n ==> l) /\ (h /\ n ==> r) /\ (l /\ r ==> n) /\ (h /\ l ==> r)
    ==> (h \/ r ==> (l <=> n)) /\ (l /\ h ==> r)`) THEN
  REWRITE_TAC[NEIGHBOURHOOD_BASE_IMP_LOCALLY_COMPACT_SPACE] THEN
  REPEAT CONJ_TAC THENL
   [REWRITE_TAC[IMP_CONJ; GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN
    DISCH_TAC THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] NEIGHBOURHOOD_BASE_OF_MONO) THEN
    ASM_SIMP_TAC[COMPACT_IN_IMP_CLOSED_IN];
    REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN
    REWRITE_TAC[locally_compact_space; NEIGHBOURHOOD_BASE_OF] THEN
    STRIP_TAC THEN MAP_EVERY X_GEN_TAC [`w:A->bool`; `x:A`] THEN
    STRIP_TAC THEN
    SUBGOAL_THEN `(x:A) IN topspace top` ASSUME_TAC THENL
     [ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET]; ALL_TAC] THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`u INTER w:A->bool`; `x:A`]) THEN
    ASM_SIMP_TAC[OPEN_IN_INTER; IN_INTER; SUBSET_INTER] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `v:A->bool` THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `c:A->bool` THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC COMPACT_IN_SUBTOPOLOGY_IMP_COMPACT THEN
    EXISTS_TAC `k:A->bool` THEN
    MATCH_MP_TAC CLOSED_IN_COMPACT_SPACE THEN
    ASM_SIMP_TAC[COMPACT_SPACE_SUBTOPOLOGY] THEN
    MATCH_MP_TAC CLOSED_IN_SUBSET_TOPSPACE THEN ASM SET_TAC[];
    REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN
    REWRITE_TAC[locally_compact_space; NEIGHBOURHOOD_BASE_OF] THEN
    STRIP_TAC THEN MAP_EVERY X_GEN_TAC [`w:A->bool`; `x:A`] THEN STRIP_TAC THEN
    SUBGOAL_THEN `(x:A) IN topspace top` ASSUME_TAC THENL
     [ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET]; ALL_TAC] THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
    SUBGOAL_THEN `regular_space(subtopology top (k:A->bool))` MP_TAC THENL
     [MATCH_MP_TAC COMPACT_HAUSDORFF_IMP_REGULAR_SPACE THEN
      ASM_SIMP_TAC[COMPACT_SPACE_SUBTOPOLOGY; HAUSDORFF_SPACE_SUBTOPOLOGY];
      REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN
      REWRITE_TAC[NEIGHBOURHOOD_BASE_OF]] THEN
    DISCH_THEN(MP_TAC o SPECL [`k INTER w:A->bool`; `x:A`]) THEN
    ASM_SIMP_TAC[IN_INTER; OPEN_IN_SUBTOPOLOGY_INTER_OPEN] THEN
    ANTS_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
    REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; CLOSED_IN_SUBTOPOLOGY_ALT] THEN
    REWRITE_TAC[RIGHT_EXISTS_AND_THM; EXISTS_IN_GSPEC] THEN
    DISCH_THEN(X_CHOOSE_THEN `v:A->bool`
     (CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    REWRITE_TAC[SUBSET_INTER; IN_INTER; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `c:A->bool` THEN STRIP_TAC THEN
    EXISTS_TAC `u INTER v:A->bool` THEN ASM_SIMP_TAC[OPEN_IN_INTER] THEN
    EXISTS_TAC `k INTER c:A->bool` THEN
    ASM_SIMP_TAC[CLOSED_IN_INTER; COMPACT_IN_IMP_CLOSED_IN] THEN
    ASM SET_TAC[]]);;

let LOCALLY_COMPACT_HAUSDORFF_OR_REGULAR = prove
 (`!top:A topology.
        locally_compact_space top /\
        (hausdorff_space top \/ regular_space top) <=>
        locally_compact_space top /\ regular_space top`,
  MESON_TAC[LOCALLY_COMPACT_HAUSDORFF_IMP_REGULAR_SPACE]);;

let LOCALLY_COMPACT_SPACE_COMPACT_CLOSED_IN = prove
 (`!top:A topology.
        hausdorff_space top \/ regular_space top
        ==> (locally_compact_space top <=>
             !x. x IN topspace top
                 ==> ?u k. open_in top u /\
                           compact_in top k /\ closed_in top k /\
                           x IN u /\ u SUBSET k)`,
  GEN_TAC THEN MATCH_MP_TAC(TAUT
   `(p ==> l) /\ (l /\ h ==> r) /\ (l /\ r ==> p)
    ==> h \/ r ==> (l <=> p)`) THEN
  REWRITE_TAC[LOCALLY_COMPACT_HAUSDORFF_IMP_REGULAR_SPACE] THEN
  REWRITE_TAC[locally_compact_space] THEN
  CONJ_TAC THENL [MESON_TAC[]; STRIP_TAC] THEN
  X_GEN_TAC `x:A` THEN DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o
    GEN_REWRITE_RULE I [GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN]) THEN
  REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
  DISCH_THEN(MP_TAC o SPECL [`u:A->bool`; `x:A`]) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `v:A->bool` THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `c:A->bool` THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC COMPACT_IN_SUBTOPOLOGY_IMP_COMPACT THEN
  EXISTS_TAC `k:A->bool` THEN
  MATCH_MP_TAC CLOSED_IN_COMPACT_SPACE THEN
  ASM_SIMP_TAC[COMPACT_SPACE_SUBTOPOLOGY] THEN
  MATCH_MP_TAC CLOSED_IN_SUBSET_TOPSPACE THEN ASM SET_TAC[]);;

let LOCALLY_COMPACT_SPACE_COMPACT_CLOSURE_OF = prove
 (`!top:A topology.
        hausdorff_space top \/ regular_space top
        ==> (locally_compact_space top <=>
             !x. x IN topspace top
                 ==> ?u. open_in top u /\ compact_in top (top closure_of u) /\
                         x IN u)`,
  GEN_TAC THEN DISCH_TAC THEN
  ASM_SIMP_TAC[LOCALLY_COMPACT_SPACE_COMPACT_CLOSED_IN] THEN
  EQ_TAC THEN DISCH_TAC THEN X_GEN_TAC `x:A` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `u:A->bool` THENL
   [DISCH_THEN(X_CHOOSE_THEN `k:A->bool` STRIP_ASSUME_TAC) THEN
    ASM_REWRITE_TAC[] THEN MATCH_MP_TAC COMPACT_IN_SUBTOPOLOGY_IMP_COMPACT THEN
    EXISTS_TAC `k:A->bool` THEN MATCH_MP_TAC CLOSED_IN_COMPACT_SPACE THEN
    ASM_SIMP_TAC[COMPACT_SPACE_SUBTOPOLOGY] THEN
    MATCH_MP_TAC CLOSED_IN_SUBSET_TOPSPACE THEN
    ASM_SIMP_TAC[CLOSURE_OF_MINIMAL; CLOSED_IN_CLOSURE_OF];
    STRIP_TAC THEN EXISTS_TAC `top closure_of u:A->bool` THEN
    ASM_SIMP_TAC[CLOSED_IN_CLOSURE_OF; CLOSURE_OF_SUBSET; OPEN_IN_SUBSET]]);;

let LOCALLY_COMPACT_SPACE_NEIGBOURHOOD_BASE_CLOSED_IN = prove
 (`!top:A topology.
     hausdorff_space top \/ regular_space top
     ==> (locally_compact_space top <=>
          neighbourhood_base_of(\c. compact_in top c /\ closed_in top c) top)`,
  GEN_TAC THEN MATCH_MP_TAC(TAUT
   `(p ==> l) /\ (l /\ h ==> r) /\ (l /\ r ==> p)
    ==> h \/ r ==> (l <=> p)`) THEN
  REWRITE_TAC[LOCALLY_COMPACT_HAUSDORFF_IMP_REGULAR_SPACE] THEN CONJ_TAC THENL
   [DISCH_THEN(fun th -> MATCH_MP_TAC
      NEIGHBOURHOOD_BASE_IMP_LOCALLY_COMPACT_SPACE THEN MP_TAC th) THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] NEIGHBOURHOOD_BASE_OF_MONO) THEN
    SIMP_TAC[];
    DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
    ASM_SIMP_TAC[LOCALLY_COMPACT_SPACE_NEIGHBOURHOOD_BASE] THEN
    REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN DISCH_TAC THEN
    MAP_EVERY X_GEN_TAC [`w:A->bool`; `x:A`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`w:A->bool`; `x:A`]) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o
      GEN_REWRITE_RULE I [GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN]) THEN
    REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
    DISCH_THEN(MP_TAC o SPECL [`u:A->bool`; `x:A`]) THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `v:A->bool` THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `c:A->bool` THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
    MATCH_MP_TAC COMPACT_IN_SUBTOPOLOGY_IMP_COMPACT THEN
    EXISTS_TAC `k:A->bool` THEN
    MATCH_MP_TAC CLOSED_IN_COMPACT_SPACE THEN
    ASM_SIMP_TAC[COMPACT_SPACE_SUBTOPOLOGY] THEN
    MATCH_MP_TAC CLOSED_IN_SUBSET_TOPSPACE THEN ASM SET_TAC[]]);;

let LOCALLY_COMPACT_SPACE_NEIGBOURHOOD_BASE_CLOSURE_OF = prove
 (`!top:A topology.
      hausdorff_space top \/ regular_space top
      ==> (locally_compact_space top <=>
           neighbourhood_base_of (\t. compact_in top (top closure_of t)) top)`,
  GEN_TAC THEN DISCH_TAC THEN EQ_TAC THENL
   [ASM_SIMP_TAC[LOCALLY_COMPACT_SPACE_NEIGBOURHOOD_BASE_CLOSED_IN] THEN
    POP_ASSUM(K ALL_TAC) THEN REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
    DISCH_TAC THEN MAP_EVERY X_GEN_TAC [`w:A->bool`; `x:A`] THEN
    STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPECL [`w:A->bool`; `x:A`]) THEN
    ASM_REWRITE_TAC[] THEN REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN
    SIMP_TAC[CLOSURE_OF_CLOSED_IN];
    POP_ASSUM(K ALL_TAC) THEN
    ASM_REWRITE_TAC[locally_compact_space; NEIGHBOURHOOD_BASE_OF] THEN
    STRIP_TAC THEN X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`topspace top:A->bool`; `x:A`]) THEN
    ASM_REWRITE_TAC[OPEN_IN_TOPSPACE] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `u:A->bool` THEN
    DISCH_THEN(X_CHOOSE_THEN `v:A->bool` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `top closure_of (v:A->bool)` THEN
    ASM_MESON_TAC[SUBSET_TRANS; CLOSURE_OF_SUBSET]]);;

let LOCALLY_COMPACT_REGULAR_SPACE_NEIGHBOURHOOD_BASE = prove
 (`!top:A topology.
        locally_compact_space top /\ regular_space top <=>
        neighbourhood_base_of (\c. compact_in top c /\ closed_in top c) top`,
  GEN_TAC THEN MATCH_MP_TAC(TAUT
   `(r ==> q) /\ (q ==> (p <=> r)) ==> (p /\ q <=> r)`) THEN
  SIMP_TAC[LOCALLY_COMPACT_SPACE_NEIGBOURHOOD_BASE_CLOSED_IN] THEN
  REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] NEIGHBOURHOOD_BASE_OF_MONO) THEN
  SIMP_TAC[]);;

let LOCALLY_COMPACT_SPACE_CLOSED_SUBSET = prove
 (`!top s:A->bool.
        locally_compact_space top /\ closed_in top s
        ==> locally_compact_space (subtopology top s)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[locally_compact_space; TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN
  STRIP_TAC THEN X_GEN_TAC `x:A` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM; COMPACT_IN_SUBTOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC [`s INTER u:A->bool`; `s INTER k:A->bool`] THEN
  ASM_SIMP_TAC[OPEN_IN_SUBTOPOLOGY_INTER_OPEN] THEN
  ASM_SIMP_TAC[CLOSED_INTER_COMPACT_IN] THEN ASM SET_TAC[]);;

let LOCALLY_COMPACT_SPACE_OPEN_SUBSET = prove
 (`!top s:A->bool.
        (hausdorff_space top \/ regular_space top) /\
        locally_compact_space top /\ open_in top s
        ==> locally_compact_space (subtopology top s)`,
  REWRITE_TAC[TAUT `p /\ q /\ r ==> s <=> r ==> q /\ p ==> s`] THEN
  REWRITE_TAC[LOCALLY_COMPACT_HAUSDORFF_OR_REGULAR] THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[locally_compact_space] THEN
  DISCH_TAC THEN STRIP_TAC THEN X_GEN_TAC `x:A` THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I
   [GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN]) THEN
  REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
  DISCH_THEN(MP_TAC o SPECL [`u INTER s:A->bool`; `x:A`]) THEN
  ASM_SIMP_TAC[IN_INTER; LEFT_IMP_EXISTS_THM; OPEN_IN_INTER; SUBSET_INTER] THEN
  MAP_EVERY X_GEN_TAC [`v:A->bool`; `c:A->bool`] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC [`v:A->bool`; `c INTER k:A->bool`] THEN
  ASM_SIMP_TAC[COMPACT_IN_SUBTOPOLOGY; SUBSET_INTER;
               CLOSED_INTER_COMPACT_IN] THEN
  CONJ_TAC THENL [MATCH_MP_TAC OPEN_IN_SUBSET_TOPSPACE; ASM SET_TAC[]] THEN
  ASM SET_TAC[]);;

let LOCALLY_COMPACT_SPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. locally_compact_space (discrete_topology u)`,
  REWRITE_TAC[locally_compact_space; OPEN_IN_DISCRETE_TOPOLOGY;
              CLOSED_IN_DISCRETE_TOPOLOGY; COMPACT_IN_DISCRETE_TOPOLOGY;
              TOPSPACE_DISCRETE_TOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`v:A->bool`; `x:A`] THEN DISCH_TAC THEN
  MAP_EVERY EXISTS_TAC [`{x:A}`; `{x:A}`] THEN
  REWRITE_TAC[FINITE_SING] THEN ASM SET_TAC[]);;

let LOCALLY_COMPACT_SPACE_CONTINUOUS_OPEN_MAP_IMAGE = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\ open_map (top,top') f /\
        IMAGE f (topspace top) = topspace top' /\
        locally_compact_space top
        ==> locally_compact_space top'`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[locally_compact_space] THEN
  FIRST_ASSUM(SUBST1_TAC o SYM) THEN REWRITE_TAC[FORALL_IN_IMAGE] THEN
  X_GEN_TAC `x:A` THEN DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC `x:A` o
    GEN_REWRITE_RULE I [locally_compact_space]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC [`IMAGE (f:A->B) u`; `IMAGE (f:A->B) k`] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[open_map]) THEN
  ASM_SIMP_TAC[FUN_IN_IMAGE; IMAGE_SUBSET] THEN
  ASM_MESON_TAC[IMAGE_COMPACT_IN]);;

let LOCALLY_COMPACT_SUBSPACE_OPEN_IN_CLOSURE_OF = prove
 (`!top s:A->bool.
        hausdorff_space top /\
        s SUBSET topspace top /\ locally_compact_space(subtopology top s)
        ==> open_in (subtopology top (top closure_of s)) s`,
  REPEAT STRIP_TAC THEN ONCE_REWRITE_TAC[OPEN_IN_SUBOPEN] THEN
  X_GEN_TAC `a:A` THEN DISCH_TAC THEN
  SUBGOAL_THEN `(a:A) IN topspace top` ASSUME_TAC THENL
   [ASM SET_TAC[]; ALL_TAC] THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [locally_compact_space]) THEN
  DISCH_THEN(MP_TAC o SPEC `a:A`) THEN
  ASM_REWRITE_TAC[IN_INTER; TOPSPACE_SUBTOPOLOGY; COMPACT_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[RIGHT_EXISTS_AND_THM; OPEN_IN_SUBTOPOLOGY_ALT] THEN
  REWRITE_TAC[EXISTS_IN_GSPEC; IN_INTER] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `u:A->bool` THEN DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
   (X_CHOOSE_THEN `k:A->bool` STRIP_ASSUME_TAC)) THEN ASM_REWRITE_TAC[] THEN
  CONJ_TAC THENL [ASM_MESON_TAC[CLOSURE_OF_SUBSET; SUBSET]; ALL_TAC] THEN
  ONCE_REWRITE_TAC[INTER_COMM] THEN
  W(MP_TAC o PART_MATCH (lhand o rand) OPEN_IN_INTER_CLOSURE_OF_EQ o
    lhand o snd) THEN
  ASM_REWRITE_TAC[] THEN DISCH_THEN SUBST1_TAC THEN
  MATCH_MP_TAC(SET_RULE `t SUBSET u ==> s INTER t SUBSET u`) THEN
  TRANS_TAC SUBSET_TRANS `k:A->bool` THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN
  ONCE_REWRITE_TAC[INTER_COMM] THEN ASM_SIMP_TAC[COMPACT_IN_IMP_CLOSED_IN]);;

let LOCALLY_COMPACT_SUBSPACE_CLOSED_INTER_OPEN_IN = prove
 (`!top s:A->bool.
        hausdorff_space top /\
        s SUBSET topspace top /\ locally_compact_space(subtopology top s)
        ==> ?c u. closed_in top c /\ open_in top u /\ c INTER u = s`,
  REPEAT GEN_TAC THEN DISCH_TAC THEN EXISTS_TAC `top closure_of s:A->bool` THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP
   LOCALLY_COMPACT_SUBSPACE_OPEN_IN_CLOSURE_OF) THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY; CLOSED_IN_CLOSURE_OF] THEN
  MESON_TAC[INTER_COMM]);;

let LOCALLY_COMPACT_SUBSPACE_OPEN_IN_CLOSURE_OF_EQ = prove
 (`!top s:A->bool.
      hausdorff_space top /\ locally_compact_space top
      ==> (open_in (subtopology top (top closure_of s)) s <=>
           s SUBSET topspace top /\ locally_compact_space(subtopology top s))`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [DISCH_TAC; ASM_MESON_TAC[LOCALLY_COMPACT_SUBSPACE_OPEN_IN_CLOSURE_OF]] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER] THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN
   `subtopology top (s:A->bool) =
    subtopology (subtopology top (top closure_of s)) s`
  SUBST1_TAC THENL
   [REWRITE_TAC[SUBTOPOLOGY_SUBTOPOLOGY] THEN AP_TERM_TAC THEN ASM SET_TAC[];
    MATCH_MP_TAC LOCALLY_COMPACT_SPACE_OPEN_SUBSET THEN
    ASM_SIMP_TAC[HAUSDORFF_SPACE_SUBTOPOLOGY] THEN
    MATCH_MP_TAC LOCALLY_COMPACT_SPACE_CLOSED_SUBSET THEN
    ASM_REWRITE_TAC[CLOSED_IN_CLOSURE_OF]]);;

let LOCALLY_COMPACT_SUBSPACE_CLOSED_INTER_OPEN_IN_EQ = prove
 (`!top s:A->bool.
      hausdorff_space top /\ locally_compact_space top
      ==> ((?c u. closed_in top c /\ open_in top u /\ c INTER u = s) <=>
           s SUBSET topspace top /\ locally_compact_space(subtopology top s))`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [REWRITE_TAC[LEFT_IMP_EXISTS_THM];
    ASM_MESON_TAC[LOCALLY_COMPACT_SUBSPACE_CLOSED_INTER_OPEN_IN]] THEN
  MAP_EVERY X_GEN_TAC [`c:A->bool`; `u:A->bool`] THEN STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  EXPAND_TAC "s" THEN REWRITE_TAC[GSYM SUBTOPOLOGY_SUBTOPOLOGY] THEN
  ONCE_REWRITE_TAC[SUBTOPOLOGY_RESTRICT] THEN
  MATCH_MP_TAC LOCALLY_COMPACT_SPACE_OPEN_SUBSET THEN
  ASM_SIMP_TAC[LOCALLY_COMPACT_SPACE_CLOSED_SUBSET;
               HAUSDORFF_SPACE_SUBTOPOLOGY] THEN
  ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY_SUBSET] THEN
  EXPAND_TAC "s" THEN ASM_SIMP_TAC[OPEN_IN_SUBTOPOLOGY_INTER_OPEN]);;

(* ------------------------------------------------------------------------- *)
(* F_sigma and G_delta sets in a topological space.                          *)
(* ------------------------------------------------------------------------- *)

let fsigma_in = new_definition
 `fsigma_in (top:A topology) = COUNTABLE UNION_OF closed_in top`;;

let gdelta_in = new_definition
 `gdelta_in (top:A topology) =
        (COUNTABLE INTERSECTION_OF open_in top) relative_to topspace top`;;

let GDELTA_IN_ALT = prove
 (`!top s:A->bool.
        gdelta_in top s <=>
        s SUBSET topspace top /\ (COUNTABLE INTERSECTION_OF open_in top) s`,
  SIMP_TAC[COUNTABLE_INTERSECTION_OF_RELATIVE_TO_ALT; gdelta_in;
           OPEN_IN_TOPSPACE] THEN
  REWRITE_TAC[CONJ_ACI]);;

let FSIGMA_IN_SUBSET = prove
 (`!top s:A->bool. fsigma_in top s ==> s SUBSET topspace top`,
  GEN_TAC THEN REWRITE_TAC[fsigma_in; FORALL_UNION_OF; UNIONS_SUBSET] THEN
  SIMP_TAC[CLOSED_IN_SUBSET]);;

let GDELTA_IN_SUBSET = prove
 (`!top s:A->bool. gdelta_in top s ==> s SUBSET topspace top`,
  SIMP_TAC[GDELTA_IN_ALT]);;

let CLOSED_IMP_FSIGMA_IN = prove
 (`!top s:A->bool. closed_in top s ==> fsigma_in top s`,
  REWRITE_TAC[fsigma_in; COUNTABLE_UNION_OF_INC]);;

let OPEN_IMP_GDELTA_IN = prove
 (`!top s:A->bool. open_in top s ==> gdelta_in top s`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[gdelta_in] THEN
  FIRST_ASSUM(SUBST1_TAC o MATCH_MP (SET_RULE `s SUBSET u ==> s = u INTER s`) o
    MATCH_MP OPEN_IN_SUBSET) THEN
  MATCH_MP_TAC RELATIVE_TO_INC THEN
  ASM_SIMP_TAC[COUNTABLE_INTERSECTION_OF_INC]);;

let FSIGMA_IN_EMPTY = prove
 (`!top:A topology. fsigma_in top {}`,
  SIMP_TAC[CLOSED_IMP_FSIGMA_IN; CLOSED_IN_EMPTY]);;

let GDELTA_IN_EMPTY = prove
 (`!top:A topology. gdelta_in top {}`,
  SIMP_TAC[OPEN_IMP_GDELTA_IN; OPEN_IN_EMPTY]);;

let FSIGMA_IN_TOPSPACE = prove
 (`!top:A topology. fsigma_in top (topspace top)`,
  SIMP_TAC[CLOSED_IMP_FSIGMA_IN; CLOSED_IN_TOPSPACE]);;

let GDELTA_IN_TOPSPACE = prove
 (`!top:A topology. gdelta_in top (topspace top)`,
  SIMP_TAC[OPEN_IMP_GDELTA_IN; OPEN_IN_TOPSPACE]);;

let FSIGMA_IN_UNIONS = prove
 (`!top t:(A->bool)->bool.
        COUNTABLE t /\ (!s. s IN t ==> fsigma_in top s)
        ==> fsigma_in top (UNIONS t)`,
  REWRITE_TAC[fsigma_in; COUNTABLE_UNION_OF_UNIONS]);;

let FSIGMA_IN_UNION = prove
 (`!top s t:A->bool.
        fsigma_in top s /\ fsigma_in top t ==> fsigma_in top (s UNION t)`,
  REWRITE_TAC[fsigma_in; COUNTABLE_UNION_OF_UNION]);;

let FSIGMA_IN_INTER = prove
 (`!top s t:A->bool.
        fsigma_in top s /\ fsigma_in top t ==> fsigma_in top (s INTER t)`,
  GEN_TAC THEN REWRITE_TAC[fsigma_in] THEN
  MATCH_MP_TAC COUNTABLE_UNION_OF_INTER THEN
  REWRITE_TAC[CLOSED_IN_INTER]);;

let GDELTA_IN_INTERS = prove
 (`!top t:(A->bool)->bool.
        COUNTABLE t /\ ~(t = {}) /\ (!s. s IN t ==> gdelta_in top s)
        ==> gdelta_in top (INTERS t)`,
  REWRITE_TAC[GDELTA_IN_ALT] THEN REPEAT STRIP_TAC THEN
  ASM_SIMP_TAC[INTERS_SUBSET] THEN
  ASM_SIMP_TAC[COUNTABLE_INTERSECTION_OF_INTERS]);;

let GDELTA_IN_INTER = prove
 (`!top s t:A->bool.
        gdelta_in top s /\ gdelta_in top t ==> gdelta_in top (s INTER t)`,
  SIMP_TAC[GSYM INTERS_2; GDELTA_IN_INTERS; COUNTABLE_INSERT; COUNTABLE_EMPTY;
           NOT_INSERT_EMPTY; FORALL_IN_INSERT; NOT_IN_EMPTY]);;

let GDELTA_IN_UNION = prove
 (`!top s t:A->bool.
        gdelta_in top s /\ gdelta_in top t ==> gdelta_in top (s UNION t)`,
  SIMP_TAC[GDELTA_IN_ALT; UNION_SUBSET] THEN
  MESON_TAC[COUNTABLE_INTERSECTION_OF_UNION; OPEN_IN_UNION]);;

let FSIGMA_IN_DIFF = prove
 (`!top s t:A->bool.
        fsigma_in top s /\ gdelta_in top t ==> fsigma_in top (s DIFF t)`,
  GEN_TAC THEN SUBGOAL_THEN
   `!s:A->bool. gdelta_in top s ==> fsigma_in top (topspace top DIFF s)`
  ASSUME_TAC THENL
   [REWRITE_TAC[fsigma_in; gdelta_in; FORALL_RELATIVE_TO] THEN
    REWRITE_TAC[FORALL_INTERSECTION_OF; DIFF_INTERS; SET_RULE
     `s DIFF (s INTER t) = s DIFF t`] THEN
    REPEAT STRIP_TAC THEN MATCH_MP_TAC COUNTABLE_UNION_OF_UNIONS THEN
    ASM_SIMP_TAC[SIMPLE_IMAGE; COUNTABLE_IMAGE; FORALL_IN_IMAGE] THEN
    ASM_SIMP_TAC[COUNTABLE_UNION_OF_INC; CLOSED_IN_DIFF;
                 CLOSED_IN_TOPSPACE];
    REPEAT STRIP_TAC THEN
    SUBGOAL_THEN `s DIFF t:A->bool = s INTER (topspace top DIFF t)`
     (fun th -> SUBST1_TAC th THEN ASM_SIMP_TAC[FSIGMA_IN_INTER]) THEN
   FIRST_ASSUM(MP_TAC o MATCH_MP FSIGMA_IN_SUBSET) THEN ASM SET_TAC[]]);;

let GDELTA_IN_DIFF = prove
 (`!top s t:A->bool.
        gdelta_in top s /\ fsigma_in top t ==> gdelta_in top (s DIFF t)`,
  GEN_TAC THEN SUBGOAL_THEN
   `!s:A->bool. fsigma_in top s ==> gdelta_in top (topspace top DIFF s)`
  ASSUME_TAC THENL
   [REWRITE_TAC[fsigma_in; gdelta_in; FORALL_UNION_OF; DIFF_UNIONS] THEN
    REPEAT STRIP_TAC THEN MATCH_MP_TAC RELATIVE_TO_INC THEN
    MATCH_MP_TAC COUNTABLE_INTERSECTION_OF_INTERS THEN
    ASM_SIMP_TAC[SIMPLE_IMAGE; COUNTABLE_IMAGE; FORALL_IN_IMAGE] THEN
    ASM_SIMP_TAC[COUNTABLE_INTERSECTION_OF_INC; OPEN_IN_DIFF;
                 OPEN_IN_TOPSPACE];
    REPEAT STRIP_TAC THEN
    SUBGOAL_THEN `s DIFF t:A->bool = s INTER (topspace top DIFF t)`
     (fun th -> SUBST1_TAC th THEN ASM_SIMP_TAC[GDELTA_IN_INTER]) THEN
   FIRST_ASSUM(MP_TAC o MATCH_MP GDELTA_IN_SUBSET) THEN ASM SET_TAC[]]);;

let GDELTA_IN_FSIGMA_IN = prove
 (`!top s:A->bool.
       gdelta_in top s <=>
       s SUBSET topspace top /\ fsigma_in top (topspace top DIFF s)`,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC[GDELTA_IN_SUBSET; FSIGMA_IN_DIFF; FSIGMA_IN_TOPSPACE] THEN
  STRIP_TAC THEN FIRST_ASSUM(SUBST1_TAC o MATCH_MP (SET_RULE
   `s SUBSET u ==> s = u DIFF (u DIFF s)`)) THEN
  ASM_SIMP_TAC[GDELTA_IN_DIFF; GDELTA_IN_TOPSPACE]);;

let FSIGMA_IN_GDELTA_IN = prove
 (`!top s:A->bool.
        fsigma_in top s <=>
        s SUBSET topspace top /\ gdelta_in top (topspace top DIFF s)`,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC[FSIGMA_IN_SUBSET; GDELTA_IN_DIFF; GDELTA_IN_TOPSPACE] THEN
  STRIP_TAC THEN FIRST_ASSUM(SUBST1_TAC o MATCH_MP (SET_RULE
   `s SUBSET u ==> s = u DIFF (u DIFF s)`)) THEN
  ASM_SIMP_TAC[FSIGMA_IN_DIFF; FSIGMA_IN_TOPSPACE]);;

let CLOSED_IMP_GDELTA_IN = prove
 (`!top s:A->bool.
        metrizable_space top /\ closed_in top s ==> gdelta_in top s`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_METRIZABLE_SPACE] THEN
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[GDELTA_IN_EMPTY] THEN
  SUBGOAL_THEN
   `s:A->bool =
    INTERS
     {{x | x IN mspace m /\
           ?y. y IN s /\ mdist m (x,y) < inv(&n + &1)} | n IN (:num)}`
  SUBST1_TAC THENL
   [GEN_REWRITE_TAC I [EXTENSION] THEN X_GEN_TAC `x:A` THEN
    REWRITE_TAC[INTERS_GSPEC; IN_ELIM_THM; IN_UNIV] THEN EQ_TAC THENL
     [DISCH_TAC THEN X_GEN_TAC `n:num` THEN
      SUBGOAL_THEN `(x:A) IN mspace m` ASSUME_TAC THENL
       [ASM_MESON_TAC[CLOSED_IN_SUBSET; SUBSET; TOPSPACE_MTOPOLOGY];
        ASM_REWRITE_TAC[] THEN EXISTS_TAC `x:A` THEN
        ASM_SIMP_TAC[MDIST_REFL; REAL_LT_INV_EQ] THEN REAL_ARITH_TAC];
      ASM_CASES_TAC `(x:A) IN mspace m` THEN ASM_REWRITE_TAC[] THEN
      W(MP_TAC o PART_MATCH (rand o rand)
        FORALL_POS_MONO_1_EQ o lhand o snd) THEN
      ANTS_TAC THENL
       [MESON_TAC[REAL_LT_TRANS]; DISCH_THEN(SUBST1_TAC o SYM)] THEN
      GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN DISCH_TAC THEN
      FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [closed_in]) THEN
      REWRITE_TAC[OPEN_IN_MTOPOLOGY; NOT_FORALL_THM; NOT_IMP] THEN
      DISCH_THEN(MP_TAC o SPEC `x:A` o CONJUNCT2 o CONJUNCT2) THEN
      ASM_REWRITE_TAC[IN_DIFF; TOPSPACE_MTOPOLOGY; SUBSET; IN_MBALL] THEN
      ASM_MESON_TAC[CLOSED_IN_SUBSET; SUBSET; TOPSPACE_MTOPOLOGY]];
    MATCH_MP_TAC GDELTA_IN_INTERS THEN
    SIMP_TAC[SIMPLE_IMAGE; COUNTABLE_IMAGE; NUM_COUNTABLE] THEN
    REWRITE_TAC[IMAGE_EQ_EMPTY; FORALL_IN_IMAGE; UNIV_NOT_EMPTY; IN_UNIV] THEN
    X_GEN_TAC `n:num` THEN MATCH_MP_TAC OPEN_IMP_GDELTA_IN THEN
    REWRITE_TAC[OPEN_IN_MTOPOLOGY; SUBSET_RESTRICT; IN_ELIM_THM] THEN
    X_GEN_TAC `x:A` THEN STRIP_TAC THEN
    EXISTS_TAC `inv(&n + &1) - mdist m (x:A,y)` THEN
    ASM_REWRITE_TAC[SUBSET; IN_MBALL; IN_ELIM_THM; REAL_SUB_LT] THEN
    X_GEN_TAC `z:A` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    EXISTS_TAC `y:A` THEN ASM_REWRITE_TAC[] THEN FIRST_X_ASSUM(MATCH_MP_TAC o
      MATCH_MP (METRIC_ARITH
        `mdist m (x,z) < e - mdist m (x,y)
         ==> x IN mspace m /\ y IN mspace m /\ z IN mspace m
             ==> mdist m (z,y) < e`)) THEN
    ASM_MESON_TAC[CLOSED_IN_SUBSET; SUBSET; TOPSPACE_MTOPOLOGY]]);;

let OPEN_IMP_FSIGMA_IN = prove
 (`!top s:A->bool.
        metrizable_space top /\ open_in top s ==> fsigma_in top s`,
  REPEAT STRIP_TAC THEN
  ASM_SIMP_TAC[FSIGMA_IN_GDELTA_IN; OPEN_IN_SUBSET] THEN
  MATCH_MP_TAC CLOSED_IMP_GDELTA_IN THEN
  ASM_SIMP_TAC[CLOSED_IN_DIFF; CLOSED_IN_TOPSPACE]);;

(* ------------------------------------------------------------------------- *)
(* The most basic facts about usual topology and metric on R.                *)
(* ------------------------------------------------------------------------- *)

let real_open = new_definition
  `real_open s <=>
      !x. x IN s ==> ?e. &0 < e /\ !x'. abs(x' - x) < e ==> x' IN s`;;

let real_closed = new_definition
 `real_closed s <=> real_open((:real) DIFF s)`;;

let euclideanreal = new_definition
 `euclideanreal = topology real_open`;;

let REAL_OPEN_EMPTY = prove
 (`real_open {}`,
  REWRITE_TAC[real_open; NOT_IN_EMPTY]);;

let REAL_OPEN_UNIV = prove
 (`real_open(:real)`,
  REWRITE_TAC[real_open; IN_UNIV] THEN MESON_TAC[REAL_LT_01]);;

let REAL_OPEN_INTER = prove
 (`!s t. real_open s /\ real_open t ==> real_open (s INTER t)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[real_open; AND_FORALL_THM; IN_INTER] THEN
  MATCH_MP_TAC MONO_FORALL THEN GEN_TAC THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[] THEN DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_TAC `d1:real`) (X_CHOOSE_TAC `d2:real`)) THEN
  MP_TAC(SPECL [`d1:real`; `d2:real`] REAL_DOWN2) THEN
  ASM_MESON_TAC[REAL_LT_TRANS]);;

let REAL_OPEN_UNIONS = prove
 (`(!s. s IN f ==> real_open s) ==> real_open(UNIONS f)`,
  REWRITE_TAC[real_open; IN_UNIONS] THEN MESON_TAC[]);;

let REAL_OPEN_IN = prove
 (`!s. real_open s <=> open_in euclideanreal s`,
  GEN_TAC THEN REWRITE_TAC[euclideanreal] THEN CONV_TAC SYM_CONV THEN
  AP_THM_TAC THEN REWRITE_TAC[GSYM(CONJUNCT2 topology_tybij)] THEN
  REWRITE_TAC[REWRITE_RULE[IN] istopology] THEN
  REWRITE_TAC[REAL_OPEN_EMPTY; REAL_OPEN_INTER; SUBSET] THEN
  MESON_TAC[IN; REAL_OPEN_UNIONS]);;

let TOPSPACE_EUCLIDEANREAL = prove
 (`topspace euclideanreal = (:real)`,
  REWRITE_TAC[topspace; EXTENSION; IN_UNIV; IN_UNIONS; IN_ELIM_THM] THEN
  MESON_TAC[REAL_OPEN_UNIV; IN_UNIV; REAL_OPEN_IN]);;

let TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY = prove
 (`!s. topspace (subtopology euclideanreal s) = s`,
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; TOPSPACE_SUBTOPOLOGY; INTER_UNIV]);;

let REAL_CLOSED_IN = prove
 (`!s. real_closed s <=> closed_in euclideanreal s`,
  REWRITE_TAC[real_closed; closed_in; TOPSPACE_EUCLIDEANREAL;
              REAL_OPEN_IN; SUBSET_UNIV]);;

let REAL_OPEN_UNION = prove
 (`!s t. real_open s /\ real_open t ==> real_open(s UNION t)`,
  REWRITE_TAC[REAL_OPEN_IN; OPEN_IN_UNION]);;

let REAL_OPEN_SUBREAL_OPEN = prove
 (`!s. real_open s <=> !x. x IN s ==> ?t. real_open t /\ x IN t /\ t SUBSET s`,
  REWRITE_TAC[REAL_OPEN_IN; GSYM OPEN_IN_SUBOPEN]);;

let REAL_CLOSED_EMPTY = prove
 (`real_closed {}`,
  REWRITE_TAC[REAL_CLOSED_IN; CLOSED_IN_EMPTY]);;

let REAL_CLOSED_UNIV = prove
 (`real_closed(:real)`,
  REWRITE_TAC[REAL_CLOSED_IN; GSYM TOPSPACE_EUCLIDEANREAL;
              CLOSED_IN_TOPSPACE]);;

let REAL_CLOSED_UNION = prove
 (`!s t. real_closed s /\ real_closed t ==> real_closed(s UNION t)`,
  REWRITE_TAC[REAL_CLOSED_IN; CLOSED_IN_UNION]);;

let REAL_CLOSED_INTER = prove
 (`!s t. real_closed s /\ real_closed t ==> real_closed(s INTER t)`,
  REWRITE_TAC[REAL_CLOSED_IN; CLOSED_IN_INTER]);;

let REAL_CLOSED_INTERS = prove
 (`!f. (!s. s IN f ==> real_closed s) ==> real_closed(INTERS f)`,
  REWRITE_TAC[REAL_CLOSED_IN] THEN REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `f:(real->bool)->bool = {}` THEN
  ASM_SIMP_TAC[CLOSED_IN_INTERS; INTERS_0] THEN
  REWRITE_TAC[GSYM TOPSPACE_EUCLIDEANREAL; CLOSED_IN_TOPSPACE]);;

let REAL_OPEN_REAL_CLOSED = prove
 (`!s. real_open s <=> real_closed(UNIV DIFF s)`,
  SIMP_TAC[REAL_OPEN_IN; REAL_CLOSED_IN; TOPSPACE_EUCLIDEANREAL; SUBSET_UNIV;
           OPEN_IN_CLOSED_IN_EQ]);;

let REAL_OPEN_DIFF = prove
 (`!s t. real_open s /\ real_closed t ==> real_open(s DIFF t)`,
  REWRITE_TAC[REAL_OPEN_IN; REAL_CLOSED_IN; OPEN_IN_DIFF]);;

let REAL_CLOSED_DIFF = prove
 (`!s t. real_closed s /\ real_open t ==> real_closed(s DIFF t)`,
  REWRITE_TAC[REAL_OPEN_IN; REAL_CLOSED_IN; CLOSED_IN_DIFF]);;

let REAL_OPEN_INTERS = prove
 (`!s. FINITE s /\ (!t. t IN s ==> real_open t) ==> real_open(INTERS s)`,
  REWRITE_TAC[IMP_CONJ] THEN MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[INTERS_INSERT; INTERS_0; REAL_OPEN_UNIV; IN_INSERT] THEN
  MESON_TAC[REAL_OPEN_INTER]);;

let REAL_CLOSED_UNIONS = prove
 (`!s. FINITE s /\ (!t. t IN s ==> real_closed t) ==> real_closed(UNIONS s)`,
  REWRITE_TAC[IMP_CONJ] THEN MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[UNIONS_INSERT; UNIONS_0; REAL_CLOSED_EMPTY; IN_INSERT] THEN
  MESON_TAC[REAL_CLOSED_UNION]);;

let REAL_OPEN_HALFSPACE_GT = prove
 (`!a. real_open {x | x > a}`,
  GEN_TAC THEN REWRITE_TAC[real_open; IN_ELIM_THM] THEN
  X_GEN_TAC `b:real` THEN DISCH_TAC THEN
  EXISTS_TAC `abs(a - b):real` THEN ASM_REAL_ARITH_TAC);;

let REAL_OPEN_HALFSPACE_LT = prove
 (`!a. real_open {x | x < a}`,
  GEN_TAC THEN REWRITE_TAC[real_open; IN_ELIM_THM] THEN
  X_GEN_TAC `b:real` THEN DISCH_TAC THEN
  EXISTS_TAC `abs(a - b):real` THEN ASM_REAL_ARITH_TAC);;

let REAL_OPEN_REAL_INTERVAL = prove
 (`!a b. real_open(real_interval(a,b))`,
  REWRITE_TAC[real_interval; SET_RULE
   `{x | P x /\ Q x} = {x | P x} INTER {x | Q x}`] THEN
  SIMP_TAC[REAL_OPEN_INTER; REAL_OPEN_HALFSPACE_LT;
           REWRITE_RULE[real_gt] REAL_OPEN_HALFSPACE_GT]);;

let REAL_CLOSED_HALFSPACE_LE = prove
 (`!a. real_closed {x | x <= a}`,
  GEN_TAC THEN
  REWRITE_TAC[real_closed; real_open; IN_DIFF; IN_UNIV; IN_ELIM_THM] THEN
  X_GEN_TAC `b:real` THEN DISCH_TAC THEN
  EXISTS_TAC `abs(a - b):real` THEN ASM_REAL_ARITH_TAC);;

let REAL_CLOSED_HALFSPACE_GE = prove
 (`!a. real_closed {x | x >= a}`,
  GEN_TAC THEN
  REWRITE_TAC[real_closed; real_open; IN_DIFF; IN_UNIV; IN_ELIM_THM] THEN
  X_GEN_TAC `b:real` THEN DISCH_TAC THEN
  EXISTS_TAC `abs(a - b):real` THEN ASM_REAL_ARITH_TAC);;

let REAL_CLOSED_REAL_INTERVAL = prove
 (`!a b. real_closed(real_interval[a,b])`,
  REWRITE_TAC[real_interval; SET_RULE
   `{x | P x /\ Q x} = {x | P x} INTER {x | Q x}`] THEN
  SIMP_TAC[REAL_CLOSED_INTER; REAL_CLOSED_HALFSPACE_LE;
           REWRITE_RULE[real_ge] REAL_CLOSED_HALFSPACE_GE]);;

let REAL_CLOSED_SING = prove
 (`!a. real_closed {a}`,
  MESON_TAC[REAL_INTERVAL_SING; REAL_CLOSED_REAL_INTERVAL]);;

let real_euclidean_metric = new_definition
  `real_euclidean_metric = metric ((:real),\(x,y). abs(y-x))`;;

let REAL_EUCLIDEAN_METRIC = prove
 (`mspace real_euclidean_metric = (:real) /\
   (!x y. mdist real_euclidean_metric (x,y) = abs(y-x))`,
  SUBGOAL_THEN `is_metric_space((:real),\ (x,y). abs(y-x))` MP_TAC THENL
  [REWRITE_TAC[is_metric_space; IN_UNIV] THEN REAL_ARITH_TAC;
   SIMP_TAC[real_euclidean_metric; metric_tybij; mspace; mdist]]);;

let MTOPOLOGY_REAL_EUCLIDEAN_METRIC = prove
 (`mtopology real_euclidean_metric = euclideanreal`,
  REWRITE_TAC[TOPOLOGY_EQ; OPEN_IN_MTOPOLOGY; REAL_EUCLIDEAN_METRIC;
    GSYM REAL_OPEN_IN; real_open; IN_MBALL; REAL_EUCLIDEAN_METRIC;
    SUBSET; IN_UNIV]);;

let MBALL_REAL_INTERVAL = prove
 (`!x r. mball real_euclidean_metric (x,r) = real_interval(x - r,x + r)`,
  REWRITE_TAC[EXTENSION; IN_MBALL; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_UNIV; IN_REAL_INTERVAL] THEN REAL_ARITH_TAC);;

let MCBALL_REAL_INTERVAL = prove
 (`!x r. mcball real_euclidean_metric (x,r) = real_interval[x - r,x + r]`,
  REWRITE_TAC[EXTENSION; IN_MCBALL; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_UNIV; IN_REAL_INTERVAL] THEN REAL_ARITH_TAC);;

let METRIZABLE_SPACE_EUCLIDEANREAL = prove
 (`metrizable_space euclideanreal`,
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC;
              METRIZABLE_SPACE_MTOPOLOGY]);;

let HAUSDORFF_SPACE_EUCLIDEANREAL = prove
 (`hausdorff_space euclideanreal`,
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC;
              HAUSDORFF_SPACE_MTOPOLOGY]);;

let T1_SPACE_EUCLIDEANREAL = prove
 (`t1_space euclideanreal`,
  SIMP_TAC[HAUSDORFF_SPACE_EUCLIDEANREAL; HAUSDORFF_IMP_T1_SPACE]);;

let REGULAR_SPACE_EUCLIDEANREAL = prove
 (`regular_space euclideanreal`,
  MESON_TAC[METRIZABLE_IMP_REGULAR_SPACE; METRIZABLE_SPACE_EUCLIDEANREAL]);;

let SUBBASE_SUBTOPOLOGY_EUCLIDEANREAL = prove
 (`!u. topology
        (ARBITRARY UNION_OF
          (FINITE INTERSECTION_OF
            ({{x | x > a} | a IN (:real)} UNION {{x | x < a} | a IN (:real)})
           relative_to u)) =
       subtopology euclideanreal u`,
  GEN_TAC THEN
  REWRITE_TAC[subtopology; GSYM ARBITRARY_UNION_OF_RELATIVE_TO] THEN
  AP_TERM_TAC THEN REWRITE_TAC[RELATIVE_TO] THEN
  GEN_REWRITE_TAC (RAND_CONV o ONCE_DEPTH_CONV) [INTER_COMM] THEN
  ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN AP_TERM_TAC THEN
  GEN_REWRITE_TAC I [EXTENSION] THEN REWRITE_TAC[IN_ELIM_THM] THEN
  X_GEN_TAC `s:real->bool` THEN AP_THM_TAC THEN CONV_TAC SYM_CONV THEN
  REWRITE_TAC[OPEN_IN_TOPOLOGY_BASE_UNIQUE] THEN CONJ_TAC THENL
   [GEN_REWRITE_TAC ONCE_DEPTH_CONV [IN] THEN
    REWRITE_TAC[FORALL_INTERSECTION_OF] THEN
    X_GEN_TAC `t:(real->bool)->bool` THEN
    ASM_CASES_TAC `t:(real->bool)->bool = {}` THENL
     [ASM_MESON_TAC[TOPSPACE_EUCLIDEANREAL; INTERS_0; OPEN_IN_TOPSPACE];
      ALL_TAC] THEN
    DISCH_THEN(fun th -> MATCH_MP_TAC OPEN_IN_INTERS THEN
      CONJUNCTS_THEN2 ASSUME_TAC MP_TAC th) THEN
    ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_FORALL THEN
    X_GEN_TAC `d:real->bool` THEN
    MATCH_MP_TAC MONO_IMP THEN REWRITE_TAC[] THEN
    SPEC_TAC(`d:real->bool`,`d:real->bool`) THEN
    GEN_REWRITE_TAC (BINDER_CONV o LAND_CONV) [GSYM IN] THEN
    REWRITE_TAC[FORALL_IN_UNION; FORALL_IN_GSPEC; IN_UNIV] THEN
    REWRITE_TAC[GSYM REAL_OPEN_IN; REAL_OPEN_HALFSPACE_LT] THEN
    REWRITE_TAC[REAL_OPEN_HALFSPACE_GT];
    MAP_EVERY X_GEN_TAC [`u:real->bool`; `x:real`] THEN
    REWRITE_TAC[real_open; GSYM REAL_OPEN_IN] THEN
    DISCH_THEN(CONJUNCTS_THEN2 (MP_TAC o SPEC `x:real`) ASSUME_TAC) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `d:real` THEN STRIP_TAC THEN
    EXISTS_TAC `{y:real | y > x - d} INTER {y | y < x + d}` THEN
    CONJ_TAC THENL
     [GEN_REWRITE_TAC I [IN] THEN
      MATCH_MP_TAC FINITE_INTERSECTION_OF_INTER THEN CONJ_TAC THEN
      MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN
      GEN_REWRITE_TAC I [GSYM IN] THEN
      REWRITE_TAC[IN_UNION; IN_ELIM_THM] THENL
       [DISJ1_TAC THEN EXISTS_TAC `x - d:real`;
        DISJ2_TAC THEN EXISTS_TAC `x + d:real`] THEN
      REWRITE_TAC[IN_UNIV];
      REWRITE_TAC[SUBSET; IN_INTER; IN_ELIM_THM] THEN
      CONJ_TAC THENL [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
      REPEAT STRIP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
      ASM_REAL_ARITH_TAC]]);;

let EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GE = prove
 (`!a. euclideanreal closure_of {x | x >= a} = {x | x >= a}`,
  SIMP_TAC[CLOSURE_OF_EQ; GSYM REAL_CLOSED_IN; REAL_CLOSED_HALFSPACE_GE]);;

let EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LE = prove
 (`!a. euclideanreal closure_of {x | x <= a} = {x | x <= a}`,
  SIMP_TAC[CLOSURE_OF_EQ; GSYM REAL_CLOSED_IN; REAL_CLOSED_HALFSPACE_LE]);;

let EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GT = prove
 (`!a. euclideanreal closure_of {x | x > a} = {x | x >= a}`,
  GEN_TAC THEN MATCH_MP_TAC SUBSET_ANTISYM THEN CONJ_TAC THENL
   [GEN_REWRITE_TAC RAND_CONV [GSYM EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GE] THEN
    MATCH_MP_TAC CLOSURE_OF_MONO THEN
    REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN REAL_ARITH_TAC;
    REWRITE_TAC[SUBSET; IN_ELIM_THM; real_gt; real_ge] THEN
    REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; METRIC_CLOSURE_OF] THEN
    X_GEN_TAC `b:real` THEN REWRITE_TAC[REAL_EUCLIDEAN_METRIC; mball] THEN
    DISCH_TAC THEN REWRITE_TAC[IN_ELIM_THM; IN_UNIV] THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    EXISTS_TAC `b + e / &2` THEN ASM_REAL_ARITH_TAC]);;

let EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LT = prove
 (`!a. euclideanreal closure_of {x | x < a} = {x | x <= a}`,
  GEN_TAC THEN MATCH_MP_TAC SUBSET_ANTISYM THEN CONJ_TAC THENL
   [GEN_REWRITE_TAC RAND_CONV [GSYM EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LE] THEN
    MATCH_MP_TAC CLOSURE_OF_MONO THEN
    REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN REAL_ARITH_TAC;
    REWRITE_TAC[SUBSET; IN_ELIM_THM; real_gt; real_ge] THEN
    REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; METRIC_CLOSURE_OF] THEN
    X_GEN_TAC `b:real` THEN REWRITE_TAC[REAL_EUCLIDEAN_METRIC; mball] THEN
    DISCH_TAC THEN REWRITE_TAC[IN_ELIM_THM; IN_UNIV] THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    EXISTS_TAC `b - e / &2` THEN ASM_REAL_ARITH_TAC]);;

let EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_GE = prove
 (`!a. euclideanreal interior_of {x | x >= a} = {x | x > a}`,
  GEN_TAC THEN REWRITE_TAC[INTERIOR_OF_CLOSURE_OF; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[SET_RULE `UNIV DIFF {x | P x} = {x | ~P x}`] THEN
  REWRITE_TAC[REAL_ARITH `~(x >= a) <=> x < a`] THEN
  REWRITE_TAC[EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LT; EXTENSION] THEN
  REWRITE_TAC[IN_DIFF; IN_UNIV; IN_ELIM_THM] THEN REAL_ARITH_TAC);;

let EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_LE = prove
 (`!a. euclideanreal interior_of {x | x <= a} = {x | x < a}`,
  GEN_TAC THEN REWRITE_TAC[INTERIOR_OF_CLOSURE_OF; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[SET_RULE `UNIV DIFF {x | P x} = {x | ~P x}`] THEN
  REWRITE_TAC[REAL_ARITH `~(x <= a) <=> x > a`] THEN
  REWRITE_TAC[EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GT; EXTENSION] THEN
  REWRITE_TAC[IN_DIFF; IN_UNIV; IN_ELIM_THM] THEN REAL_ARITH_TAC);;

let EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_GT = prove
 (`!a. euclideanreal interior_of {x | x > a} = {x | x > a}`,
  SIMP_TAC[INTERIOR_OF_EQ; GSYM REAL_OPEN_IN; REAL_OPEN_HALFSPACE_GT]);;

let EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_LT = prove
 (`!a. euclideanreal interior_of {x | x < a} = {x | x < a}`,
  SIMP_TAC[INTERIOR_OF_EQ; GSYM REAL_OPEN_IN; REAL_OPEN_HALFSPACE_LT]);;

let EUCLIDEANREAL_FRONTIER_OF_HALSPACE_GE = prove
 (`!a. euclideanreal frontier_of {x | x >= a} = {x | x = a}`,
  GEN_TAC THEN REWRITE_TAC[frontier_of] THEN
  REWRITE_TAC[EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_GE;
              EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GE] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_DIFF; EXTENSION] THEN REAL_ARITH_TAC);;

let EUCLIDEANREAL_FRONTIER_OF_HALSPACE_LE = prove
 (`!a. euclideanreal frontier_of {x | x <= a} = {x | x = a}`,
  GEN_TAC THEN REWRITE_TAC[frontier_of] THEN
  REWRITE_TAC[EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_LE;
              EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LE] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_DIFF; EXTENSION] THEN REAL_ARITH_TAC);;

let EUCLIDEANREAL_FRONTIER_OF_HALSPACE_GT = prove
 (`!a. euclideanreal frontier_of {x | x > a} = {x | x = a}`,
  GEN_TAC THEN REWRITE_TAC[frontier_of] THEN
  REWRITE_TAC[EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_GT;
              EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GT] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_DIFF; EXTENSION] THEN REAL_ARITH_TAC);;

let EUCLIDEANREAL_FRONTIER_OF_HALSPACE_LT = prove
 (`!a. euclideanreal frontier_of {x | x < a} = {x | x = a}`,
  GEN_TAC THEN REWRITE_TAC[frontier_of] THEN
  REWRITE_TAC[EUCLIDEANREAL_INTERIOR_OF_HALFSPACE_LT;
              EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LT] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_DIFF; EXTENSION] THEN REAL_ARITH_TAC);;

(* ------------------------------------------------------------------------- *)
(* Boundedness in R.                                                         *)
(* ------------------------------------------------------------------------- *)

let real_bounded = new_definition
 `real_bounded s <=> ?B. !x. x IN s ==> abs(x) <= B`;;

let REAL_BOUNDED_POS = prove
 (`!s. real_bounded s <=> ?B. &0 < B /\ !x. x IN s ==> abs(x) <= B`,
  REWRITE_TAC[real_bounded] THEN
  MESON_TAC[REAL_ARITH `&0 < &1 + abs B /\ (x <= B ==> x <= &1 + abs B)`]);;

let MBOUNDED_REAL_EUCLIDEAN_METRIC = prove
 (`mbounded real_euclidean_metric = real_bounded`,
  REWRITE_TAC[FUN_EQ_THM] THEN X_GEN_TAC `s:real->bool` THEN
  REWRITE_TAC[mbounded; real_bounded] THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC; SUBSET; IN_MCBALL; IN_UNIV] THEN
  EQ_TAC THEN REWRITE_TAC[LEFT_IMP_EXISTS_THM] THENL
   [MAP_EVERY X_GEN_TAC [`c:real`; `b:real`] THEN STRIP_TAC THEN
    EXISTS_TAC `abs c + b`;
    X_GEN_TAC `b:real` THEN DISCH_TAC THEN
    MAP_EVERY EXISTS_TAC [`&0`; `b:real`]] THEN
  X_GEN_TAC `x:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:real`) THEN
  ASM_REWRITE_TAC[] THEN ASM_REAL_ARITH_TAC);;

let REAL_BOUNDED_REAL_INTERVAL = prove
 (`(!a b. real_bounded(real_interval[a,b])) /\
   (!a b. real_bounded(real_interval(a,b)))`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[real_bounded; IN_REAL_INTERVAL] THEN
  EXISTS_TAC `max (abs a) (abs b)` THEN REAL_ARITH_TAC);;

let REAL_BOUNDED_SHRINK = prove
 (`!s. real_bounded (IMAGE (\x. x / (&1 + abs x)) s)`,
  GEN_TAC THEN REWRITE_TAC[real_bounded; FORALL_IN_IMAGE] THEN
  MESON_TAC[REAL_SHRINK_RANGE; REAL_LT_IMP_LE]);;

(* ------------------------------------------------------------------------- *)
(* Connectedness and compactness characterizations for R.                    *)
(* ------------------------------------------------------------------------- *)

let CONNECTED_IN_EUCLIDEANREAL = prove
 (`!s. connected_in euclideanreal s <=> is_realinterval s`,
  let tac = ASM_MESON_TAC[REAL_LT_IMP_LE; REAL_LE_TOTAL; REAL_LE_ANTISYM] in
  GEN_TAC THEN
  REWRITE_TAC[CONNECTED_IN; TOPSPACE_EUCLIDEANREAL; SUBSET_UNIV] THEN
  REWRITE_TAC[GSYM REAL_OPEN_IN; is_realinterval; NOT_EXISTS_THM] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; INTER_UNIV] THEN
  EQ_TAC THEN DISCH_TAC THENL
   [MAP_EVERY X_GEN_TAC [`a:real`; `b:real`; `c:real`] THEN STRIP_TAC THEN
    ASM_CASES_TAC `(c:real) IN s` THEN ASM_REWRITE_TAC[] THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`{x:real | x < c}`; `{x:real | x > c}`]) THEN
    REWRITE_TAC[REAL_OPEN_HALFSPACE_LT; REAL_OPEN_HALFSPACE_GT] THEN
    REWRITE_TAC[SUBSET; EXTENSION; IN_INTER; IN_UNION; IN_ELIM_THM] THEN
    REWRITE_TAC[NOT_IN_EMPTY; REAL_ARITH `x < a \/ x > a <=> ~(x = a)`] THEN
    CONJ_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
    CONJ_TAC THENL [REAL_ARITH_TAC; ALL_TAC] THEN CONJ_TAC THENL
     [DISCH_THEN(MP_TAC o SPEC `a:real`);
      DISCH_THEN(MP_TAC o SPEC `b:real`)] THEN
    ASM_REWRITE_TAC[REAL_LT_LE; real_gt] THEN ASM SET_TAC[];
    REWRITE_TAC[TAUT `~(p /\ q /\ r /\ s /\ t /\ u) <=>
                      t /\ u ==> ~(p /\ q /\ r /\ s)`] THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_AND_EXISTS_THM] THEN
    REWRITE_TAC[IN_INTER; RIGHT_AND_EXISTS_THM; LEFT_IMP_EXISTS_THM] THEN
    ONCE_REWRITE_TAC[MESON[]
     `(!s t x y. P x y s t) <=> (!x y s t. P x y s t)`] THEN
    MATCH_MP_TAC REAL_WLOG_LT THEN
    CONJ_TAC THENL [SET_TAC[]; REWRITE_TAC[GSYM INTER_ASSOC]] THEN
    CONJ_TAC THENL [MESON_TAC[INTER_COMM; UNION_COMM]; ALL_TAC] THEN
    MAP_EVERY X_GEN_TAC [`a:real`; `b:real`] THEN DISCH_TAC THEN
    MAP_EVERY X_GEN_TAC [`e1:real->bool`; `e2:real->bool`] THEN STRIP_TAC THEN
    REWRITE_TAC[real_open] THEN STRIP_TAC THEN
    SUBGOAL_THEN `~(?x:real. a <= x /\ x <= b /\ x IN e1 /\ x IN e2)`
    ASSUME_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
    SUBGOAL_THEN `?x:real. a <= x /\ x <= b /\ ~(x IN e1) /\ ~(x IN e2)`
    MP_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
    MP_TAC(SPEC `\c:real. !x. a <= x /\ x <= c ==> x IN e1` REAL_COMPLETE) THEN
    REWRITE_TAC[] THEN ANTS_TAC THENL [tac; ALL_TAC] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `x:real` THEN STRIP_TAC THEN
    SUBGOAL_THEN `a <= x /\ x <= b` STRIP_ASSUME_TAC THENL [tac; ALL_TAC] THEN
    ASM_REWRITE_TAC[] THEN
    SUBGOAL_THEN `!z. a <= z /\ z < x ==> (z:real) IN e1` ASSUME_TAC THENL
     [ASM_MESON_TAC[REAL_NOT_LT; REAL_LT_IMP_LE]; ALL_TAC] THEN
    REPEAT STRIP_TAC THENL
     [SUBGOAL_THEN
       `?d. &0 < d /\ !y. abs(y - x) < d ==> (y:real) IN e1`
      STRIP_ASSUME_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
      ASM_MESON_TAC[REAL_DOWN; REAL_ARITH `&0 < e ==> ~(x + e <= x)`;
       REAL_ARITH `z <= x + e /\ e < d ==> z < x \/ abs(z - x) < d`];
      SUBGOAL_THEN `?d. &0 < d /\ !y:real. abs(y - x) < d ==> y IN e2`
      STRIP_ASSUME_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
      MP_TAC(SPECL [`x - a:real`; `d:real`] REAL_DOWN2) THEN ANTS_TAC THENL
       [ASM_MESON_TAC[REAL_LT_LE; REAL_SUB_LT]; ALL_TAC] THEN
      ASM_MESON_TAC[REAL_ARITH `e < x - a ==> a <= x - e`;
        REAL_ARITH `&0 < e /\ e < d ==> x - e < x /\ abs((x - e) - x) < d`;
        REAL_ARITH `&0 < e /\ x <= b ==> x - e <= b`]]]);;

let CONNECTED_IN_EUCLIDEANREAL_INTERVAL = prove
 (`(!a b. connected_in euclideanreal (real_interval[a,b])) /\
   (!a b. connected_in euclideanreal (real_interval(a,b)))`,
  REWRITE_TAC[CONNECTED_IN_EUCLIDEANREAL; IS_REALINTERVAL_INTERVAL]);;

let COMPACT_IN_EUCLIDEANREAL_INTERVAL = prove
 (`!a b. compact_in euclideanreal (real_interval[a,b])`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `real_interval[a,b] = {}` THEN
  ASM_REWRITE_TAC[COMPACT_IN_EMPTY] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[REAL_INTERVAL_NE_EMPTY]) THEN
  REWRITE_TAC[COMPACT_IN_SUBSPACE; TOPSPACE_EUCLIDEANREAL; SUBSET_UNIV] THEN
  MATCH_MP_TAC ALEXANDER_SUBBASE_THEOREM_ALT THEN
  EXISTS_TAC
   `{{x | x > a} | a IN (:real)} UNION {{x | x < a} | a IN (:real)}` THEN
  EXISTS_TAC `real_interval[a,b]` THEN
  REWRITE_TAC[SUBBASE_SUBTOPOLOGY_EUCLIDEANREAL] THEN
  CONJ_TAC THENL
   [REWRITE_TAC[UNIONS_UNION] THEN
    MATCH_MP_TAC(SET_RULE `(!x. x IN s) ==> t SUBSET s UNION v`) THEN
    REWRITE_TAC[UNIONS_GSPEC; IN_ELIM_THM; IN_UNIV] THEN
    MESON_TAC[REAL_ARITH `a > a - &1:real`];
    ALL_TAC] THEN
  REWRITE_TAC[IMP_CONJ; FORALL_SUBSET_UNION; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[SIMPLE_IMAGE; FORALL_SUBSET_IMAGE; SUBSET_UNIV] THEN
  MAP_EVERY X_GEN_TAC [`l:real->bool`; `r:real->bool`] THEN
  REWRITE_TAC[UNIONS_UNION] THEN DISCH_TAC THEN MP_TAC
   (CONJUNCT2(ISPECL [`a:real`; `b:real`] IS_REALINTERVAL_INTERVAL)) THEN
  REWRITE_TAC[GSYM CONNECTED_IN_EUCLIDEANREAL] THEN
  REWRITE_TAC[CONNECTED_IN; TOPSPACE_EUCLIDEANREAL; SUBSET_UNIV;
              NOT_EXISTS_THM] THEN
  DISCH_THEN(MP_TAC o SPECL
   [`UNIONS (IMAGE (\a:real. {x | x > a}) l)`;
    `UNIONS (IMAGE (\a:real. {x | x < a}) r)`]) THEN
  ASM_REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; INTER_UNIV] THEN
  MATCH_MP_TAC(TAUT
   `(p /\ q) /\ ((s ==> u) /\ (t ==> u)) /\ (~r ==> u)
    ==> ~(p /\ q /\ r /\ ~s /\ ~t) ==> u`) THEN
  CONJ_TAC THENL
   [CONJ_TAC THEN MATCH_MP_TAC OPEN_IN_UNIONS THEN
    REWRITE_TAC[FORALL_IN_IMAGE; GSYM REAL_OPEN_IN] THEN
    REWRITE_TAC[REAL_OPEN_HALFSPACE_GT; REAL_OPEN_HALFSPACE_LT];
    ALL_TAC] THEN
  CONJ_TAC THENL
   [CONJ_TAC THENL
     [FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
       `s SUBSET u UNION v
        ==> ((!x. x IN s ==> x IN v) ==> P) ==> u INTER s = {} ==> P`)) THEN
      DISCH_THEN(MP_TAC o SPEC `b:real`);
      FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
       `s SUBSET u UNION v
        ==> ((!x. x IN s ==> x IN u) ==> P) ==> v INTER s = {} ==> P`)) THEN
      DISCH_THEN(MP_TAC o SPEC `a:real`)] THEN
    ASM_REWRITE_TAC[IN_REAL_INTERVAL; REAL_LE_REFL] THEN
    REWRITE_TAC[UNIONS_IMAGE; IN_ELIM_THM; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `c:real` THEN STRIP_TAC THENL
     [EXISTS_TAC `{{x:real | x < c}}`; EXISTS_TAC `{{x:real | x > c}}`] THEN
    REWRITE_TAC[FINITE_SING; SING_SUBSET; UNIONS_1] THEN
    REWRITE_TAC[IN_UNION; IN_IMAGE; OR_EXISTS_THM; LEFT_AND_EXISTS_THM] THEN
    EXISTS_TAC `c:real` THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[SUBSET; IN_REAL_INTERVAL; IN_ELIM_THM] THEN
    ASM_REAL_ARITH_TAC;
    REWRITE_TAC[EXTENSION; UNIONS_IMAGE; NOT_IN_EMPTY; IN_INTER] THEN
    REWRITE_TAC[IN_ELIM_THM; NOT_FORALL_THM; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `c:real` THEN REWRITE_TAC[CONJ_ASSOC] THEN
    REWRITE_TAC[IN_REAL_INTERVAL] THEN
    DISCH_THEN(CONJUNCTS_THEN2 MP_TAC STRIP_ASSUME_TAC) THEN
    DISCH_THEN(CONJUNCTS_THEN2
     (X_CHOOSE_THEN `u:real` STRIP_ASSUME_TAC)
     (X_CHOOSE_THEN `v:real` STRIP_ASSUME_TAC)) THEN
    EXISTS_TAC `{{x:real | x > u},{x | x < v}}` THEN
    REWRITE_TAC[FINITE_INSERT; FINITE_EMPTY; UNIONS_2] THEN
    REWRITE_TAC[SUBSET; IN_UNION; IN_ELIM_THM; IN_REAL_INTERVAL] THEN
    CONJ_TAC THENL [ALL_TAC; ASM_REAL_ARITH_TAC] THEN
    REWRITE_TAC[FORALL_IN_INSERT; NOT_IN_EMPTY; IN_IMAGE] THEN CONJ_TAC THENL
     [DISJ1_TAC THEN EXISTS_TAC `u:real` THEN ASM_REWRITE_TAC[];
      DISJ2_TAC THEN EXISTS_TAC `v:real` THEN ASM_REWRITE_TAC[]]]);;

let COMPACT_IN_EUCLIDEANREAL = prove
 (`!s. compact_in euclideanreal s <=>
       mbounded real_euclidean_metric s /\ closed_in euclideanreal s`,
  GEN_TAC THEN EQ_TAC THENL
   [MESON_TAC[COMPACT_IN_IMP_CLOSED_IN; HAUSDORFF_SPACE_EUCLIDEANREAL;
              COMPACT_IN_IMP_MBOUNDED; MTOPOLOGY_REAL_EUCLIDEAN_METRIC];
    STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [mbounded]) THEN
    REWRITE_TAC[mcball; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
    REWRITE_TAC[SUBSET; LEFT_IMP_EXISTS_THM; IN_ELIM_THM] THEN
    MAP_EVERY X_GEN_TAC [`a:real`; `d:real`] THEN STRIP_TAC THEN
    MATCH_MP_TAC CLOSED_COMPACT_IN THEN
    EXISTS_TAC `real_interval[a - d,a + d]` THEN
    ASM_REWRITE_TAC[COMPACT_IN_EUCLIDEANREAL_INTERVAL] THEN
    REWRITE_TAC[SUBSET; IN_REAL_INTERVAL] THEN X_GEN_TAC `x:real` THEN
    DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC `x:real`) THEN
    ASM_REWRITE_TAC[] THEN REAL_ARITH_TAC]);;

let real_compact_def = new_definition
 `real_compact s <=> compact_in euclideanreal s`;;

let REAL_COMPACT_EQ_BOUNDED_CLOSED = prove
 (`!s. real_compact s <=> real_bounded s /\ real_closed s`,
  REWRITE_TAC[real_compact_def; GSYM MBOUNDED_REAL_EUCLIDEAN_METRIC;
              REAL_CLOSED_IN; COMPACT_IN_EUCLIDEANREAL]);;

let REAL_COMPACT_IMP_BOUNDED = prove
 (`!s. real_compact s ==> real_bounded s`,
  SIMP_TAC[REAL_COMPACT_EQ_BOUNDED_CLOSED]);;

let REAL_COMPACT_IMP_CLOSED = prove
 (`!s. real_compact s ==> real_closed s`,
  SIMP_TAC[REAL_COMPACT_EQ_BOUNDED_CLOSED]);;

let REAL_COMPACT_INTERVAL = prove
 (`!a b. real_compact(real_interval[a,b])`,
  REWRITE_TAC[real_compact_def; COMPACT_IN_EUCLIDEANREAL_INTERVAL]);;

let REAL_COMPACT_UNION = prove
 (`!s t. real_compact s /\ real_compact t ==> real_compact(s UNION t)`,
  REWRITE_TAC[real_compact_def; COMPACT_IN_UNION]);;

let REAL_CLOSED_CONTAINS_SUP = prove
 (`!s b. real_closed s /\ ~(s = {}) /\ (!x. x IN s ==> x <= b)
         ==> sup s IN s`,
  REWRITE_TAC[REAL_CLOSED_IN; GSYM CLOSURE_OF_SUBSET_EQ] THEN
  REWRITE_TAC[SUBSET; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; METRIC_CLOSURE_OF] THEN
  REWRITE_TAC[mball; REAL_EUCLIDEAN_METRIC; IN_UNIV; IN_ELIM_THM] THEN
  REPEAT STRIP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  MP_TAC(SPEC `s:real->bool` SUP) THEN
  ANTS_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
    (MP_TAC o SPEC `sup s - e`)) THEN
  ASM_REWRITE_TAC[REAL_ARITH `s <= s - e <=> ~(&0 < e)`; NOT_FORALL_THM] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `y:real` THEN
  REWRITE_TAC[NOT_IMP] THEN STRIP_TAC THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o SPEC `y:real`)) THEN
  ASM_REWRITE_TAC[] THEN ASM_REAL_ARITH_TAC);;

let REAL_COMPACT_CONTAINS_SUP = prove
 (`!s. real_compact s /\ ~(s = {}) ==> sup s IN s`,
  REWRITE_TAC[REAL_COMPACT_EQ_BOUNDED_CLOSED; real_bounded] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC REAL_CLOSED_CONTAINS_SUP THEN
  ASM_REWRITE_TAC[] THEN
  ASM_MESON_TAC[REAL_ARITH `abs x <= b ==> x <= b`]);;

let REAL_COMPACT_ATTAINS_SUP = prove
 (`!s. real_compact s /\ ~(s = {}) ==> ?x. x IN s /\ !y. y IN s ==> y <= x`,
  REPEAT STRIP_TAC THEN EXISTS_TAC `sup s` THEN
  ASM_SIMP_TAC[REAL_COMPACT_CONTAINS_SUP] THEN
  W(MP_TAC o PART_MATCH (lhand o rand) SUP o snd) THEN
  ANTS_TAC THENL [ASM_REWRITE_TAC[]; SIMP_TAC[]] THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP REAL_COMPACT_IMP_BOUNDED) THEN
  REWRITE_TAC[real_bounded] THEN
  MESON_TAC[REAL_ARITH `abs x <= b ==> x <= b`]);;

let REAL_CLOSED_CONTAINS_INF = prove
 (`!s b. real_closed s /\ ~(s = {}) /\ (!x. x IN s ==> b <= x)
         ==> inf s IN s`,
  REWRITE_TAC[REAL_CLOSED_IN; GSYM CLOSURE_OF_SUBSET_EQ] THEN
  REWRITE_TAC[SUBSET; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; METRIC_CLOSURE_OF] THEN
  REWRITE_TAC[mball; REAL_EUCLIDEAN_METRIC; IN_UNIV; IN_ELIM_THM] THEN
  REPEAT STRIP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  MP_TAC(SPEC `s:real->bool` INF) THEN
  ANTS_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
    (MP_TAC o SPEC `inf s + e`)) THEN
  ASM_REWRITE_TAC[REAL_ARITH `s + e <= s <=> ~(&0 < e)`; NOT_FORALL_THM] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `y:real` THEN
  REWRITE_TAC[NOT_IMP] THEN STRIP_TAC THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o SPEC `y:real`)) THEN
  ASM_REWRITE_TAC[] THEN ASM_REAL_ARITH_TAC);;

let REAL_COMPACT_CONTAINS_INF = prove
 (`!s. real_compact s /\ ~(s = {}) ==> inf s IN s`,
  REWRITE_TAC[REAL_COMPACT_EQ_BOUNDED_CLOSED; real_bounded] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC REAL_CLOSED_CONTAINS_INF THEN
  ASM_REWRITE_TAC[] THEN
  ASM_MESON_TAC[REAL_ARITH `abs x <= b ==> --b <= x`]);;

let REAL_COMPACT_ATTAINS_INF = prove
 (`!s. real_compact s /\ ~(s = {}) ==> ?x. x IN s /\ !y. y IN s ==> x <= y`,
  REPEAT STRIP_TAC THEN EXISTS_TAC `inf s` THEN
  ASM_SIMP_TAC[REAL_COMPACT_CONTAINS_INF] THEN
  W(MP_TAC o PART_MATCH (lhand o rand) INF o snd) THEN
  ANTS_TAC THENL [ASM_REWRITE_TAC[]; SIMP_TAC[]] THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP REAL_COMPACT_IMP_BOUNDED) THEN
  REWRITE_TAC[real_bounded] THEN
  MESON_TAC[REAL_ARITH `abs x <= b ==> --b <= x`]);;

let REAL_COMPACT_IS_REALINTERVAL = prove
 (`!s. real_compact s /\ is_realinterval s <=> ?a b. s = real_interval[a,b]`,
  GEN_TAC THEN EQ_TAC THENL
   [ASM_CASES_TAC `s:real->bool = {}` THENL
     [STRIP_TAC THEN MAP_EVERY EXISTS_TAC [`&1`; `&0`] THEN
      ASM_REWRITE_TAC[EXTENSION; NOT_IN_EMPTY; IN_REAL_INTERVAL] THEN
      REAL_ARITH_TAC;
      STRIP_TAC THEN MAP_EVERY EXISTS_TAC [`inf s`; `sup s`] THEN
      REWRITE_TAC[EXTENSION; IN_REAL_INTERVAL] THEN X_GEN_TAC `x:real` THEN
      EQ_TAC THENL
       [FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I
         [REAL_COMPACT_EQ_BOUNDED_CLOSED]) THEN
        REWRITE_TAC[real_bounded; GSYM REAL_BOUNDS_LE] THEN
        ASM_MESON_TAC[SUP; INF];
        STRIP_TAC THEN
        FIRST_X_ASSUM(MATCH_MP_TAC o REWRITE_RULE[is_realinterval]) THEN
        ASM_MESON_TAC[REAL_COMPACT_CONTAINS_SUP; REAL_COMPACT_CONTAINS_INF]]];
    STRIP_TAC THEN
    ASM_REWRITE_TAC[REAL_COMPACT_INTERVAL; IS_REALINTERVAL_INTERVAL]]);;

let IS_REALINTERVAL_CLOSURE_OF = prove
 (`!s. is_realinterval s ==> is_realinterval(euclideanreal closure_of s)`,
  REWRITE_TAC[GSYM CONNECTED_IN_EUCLIDEANREAL; CONNECTED_IN_CLOSURE_OF]);;

let IS_REALINTERVAL_INTERIOR_OF = prove
 (`!s. is_realinterval s ==> is_realinterval(euclideanreal interior_of s)`,
  GEN_TAC THEN REWRITE_TAC[is_realinterval] THEN DISCH_TAC THEN
  MAP_EVERY X_GEN_TAC [`a:real`; `b:real`; `x:real`] THEN STRIP_TAC THEN
  ASM_CASES_TAC `x:real = a` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `x:real = b` THEN ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN `x IN real_interval(a,b)` MP_TAC THENL
   [REWRITE_TAC[IN_REAL_INTERVAL] THEN ASM_REAL_ARITH_TAC; ALL_TAC] THEN
  MATCH_MP_TAC(SET_RULE `s SUBSET t ==> x IN s ==> x IN t`) THEN
  MATCH_MP_TAC INTERIOR_OF_MAXIMAL THEN
  REWRITE_TAC[GSYM REAL_OPEN_IN; REAL_OPEN_REAL_INTERVAL] THEN
  REWRITE_TAC[SUBSET; IN_REAL_INTERVAL] THEN
  X_GEN_TAC `y:real` THEN STRIP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  MAP_EVERY EXISTS_TAC [`a:real`; `b:real`] THEN
  ASM_SIMP_TAC[REAL_LT_IMP_LE] THEN
  MP_TAC(ISPECL [`euclideanreal`; `s:real->bool`] INTERIOR_OF_SUBSET) THEN
  ASM SET_TAC[]);;

let IS_REALINTERVAL_INTERIOR_SEGMENT = prove
 (`!s a b.
        is_realinterval s /\
        a IN euclideanreal closure_of s /\ b IN euclideanreal closure_of s
        ==> real_interval(a,b) SUBSET euclideanreal interior_of s`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `real_interval(a,b) = {}` THEN
  ASM_REWRITE_TAC[EMPTY_SUBSET] THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [REAL_INTERVAL_NE_EMPTY]) THEN
  DISCH_TAC THEN DISCH_THEN(CONJUNCTS_THEN ASSUME_TAC) THEN
  REWRITE_TAC[SUBSET; IN_REAL_INTERVAL] THEN X_GEN_TAC `x:real` THEN
  STRIP_TAC THEN FIRST_X_ASSUM(CONJUNCTS_THEN MP_TAC) THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; METRIC_CLOSURE_OF] THEN
  REWRITE_TAC[METRIC_INTERIOR_OF; mball; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_UNIV] THEN
  DISCH_THEN(MP_TAC o SPEC `(b - x) / &2`) THEN
  ASM_REWRITE_TAC[REAL_HALF; REAL_SUB_LT; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `b':real` THEN STRIP_TAC THEN
  DISCH_THEN(MP_TAC o SPEC `(x - a) / &2`) THEN
  ASM_REWRITE_TAC[REAL_HALF; REAL_SUB_LT; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `a':real` THEN STRIP_TAC THEN
  EXISTS_TAC `min (x - a') (b' - x)` THEN
  CONJ_TAC THENL [ASM_REAL_ARITH_TAC; REWRITE_TAC[SUBSET; IN_ELIM_THM]] THEN
  X_GEN_TAC `y:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MATCH_MP_TAC o REWRITE_RULE[is_realinterval]) THEN
  MAP_EVERY EXISTS_TAC [`a':real`; `b':real`] THEN
  ASM_REWRITE_TAC[] THEN ASM_REAL_ARITH_TAC);;

let REAL_OPEN_SUBSET_CLOSURE_OF_REALINTERVAL = prove
 (`!u s. real_open u /\ is_realinterval s
         ==> (u SUBSET euclideanreal closure_of s <=>
              u SUBSET euclideanreal interior_of s)`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [ALL_TAC; MESON_TAC[SUBSET_TRANS; INTERIOR_OF_SUBSET_CLOSURE_OF]] THEN
  REWRITE_TAC[SUBSET] THEN DISCH_TAC THEN
  X_GEN_TAC `x:real` THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [REAL_OPEN_IN]) THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; OPEN_IN_MTOPOLOGY] THEN
  DISCH_THEN(MP_TAC o SPEC `x:real` o CONJUNCT2) THEN
  ASM_REWRITE_TAC[MBALL_REAL_INTERVAL; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `e:real` THEN REWRITE_TAC[SUBSET] THEN STRIP_TAC THEN
  MP_TAC(ISPECL [`s:real->bool`; `x - e / &2`; `x + e / &2`]
      IS_REALINTERVAL_INTERIOR_SEGMENT) THEN
  ASM_REWRITE_TAC[SUBSET] THEN ANTS_TAC THENL
   [CONJ_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC;
    REWRITE_TAC[MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
    DISCH_THEN MATCH_MP_TAC] THEN
  REWRITE_TAC[IN_REAL_INTERVAL] THEN ASM_REAL_ARITH_TAC);;

let REAL_OPEN_SUBSET_CLOSURE_OF_REALINTERVAL_ALT = prove
 (`!u s. real_open u /\ is_realinterval s
         ==> (u SUBSET euclideanreal closure_of s <=> u SUBSET s)`,
  SIMP_TAC[REAL_OPEN_SUBSET_CLOSURE_OF_REALINTERVAL; REAL_OPEN_IN;
           INTERIOR_OF_MAXIMAL_EQ]);;

let INTERIOR_OF_CLOSURE_OF_REALINTERVAL = prove
 (`!s. is_realinterval s
       ==> euclideanreal interior_of (euclideanreal closure_of s) =
           euclideanreal interior_of s`,
  GEN_TAC THEN DISCH_TAC THEN REWRITE_TAC[interior_of] THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM; GSYM REAL_OPEN_IN] THEN
  ASM_MESON_TAC[REAL_OPEN_SUBSET_CLOSURE_OF_REALINTERVAL_ALT]);;

let CLOSURE_OF_REAL_INTERVAL = prove
 (`!a b. euclideanreal closure_of real_interval(a,b) =
         if real_interval(a,b) = {} then {} else real_interval[a,b]`,
  REPEAT GEN_TAC THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[CLOSURE_OF_EMPTY] THEN
  MATCH_MP_TAC SUBSET_ANTISYM THEN
  SIMP_TAC[CLOSURE_OF_MINIMAL_EQ; GSYM REAL_CLOSED_IN; TOPSPACE_EUCLIDEANREAL;
           REAL_INTERVAL_OPEN_SUBSET_CLOSED; REAL_CLOSED_REAL_INTERVAL;
           SUBSET_UNIV] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[REAL_INTERVAL_NE_EMPTY]) THEN
  ASM_SIMP_TAC[REAL_CLOSED_OPEN_INTERVAL; REAL_LT_IMP_LE] THEN
  SIMP_TAC[UNION_SUBSET; CLOSURE_OF_SUBSET; TOPSPACE_EUCLIDEANREAL;
           SUBSET_UNIV; INSERT_SUBSET; EMPTY_SUBSET] THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[METRIC_CLOSURE_OF; mball; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_UNIV; MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  CONJ_TAC THEN X_GEN_TAC `r:real` THEN DISCH_TAC THENL
   [EXISTS_TAC `min ((a + b) / &2) (a + r / &2)`;
    EXISTS_TAC `max ((a + b) / &2) (b - r / &2)`] THEN
  REWRITE_TAC[IN_REAL_INTERVAL] THEN ASM_REAL_ARITH_TAC);;

let INTERIOR_OF_REAL_INTERVAL = prove
 (`!a b. euclideanreal interior_of real_interval[a,b] = real_interval(a,b)`,
  REPEAT GEN_TAC THEN MATCH_MP_TAC SUBSET_ANTISYM THEN
  SIMP_TAC[INTERIOR_OF_MAXIMAL_EQ; GSYM REAL_OPEN_IN;
           REAL_OPEN_REAL_INTERVAL; REAL_INTERVAL_OPEN_SUBSET_CLOSED] THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; METRIC_INTERIOR_OF;
    MBALL_REAL_INTERVAL; REAL_EUCLIDEAN_METRIC; IN_UNIV; IN_ELIM_THM] THEN
  REWRITE_TAC[SUBSET_REAL_INTERVAL] THEN
  REWRITE_TAC[SUBSET; IN_ELIM_THM; IN_REAL_INTERVAL] THEN REAL_ARITH_TAC);;

let CLOSURE_OF_INTERIOR_OF_REALINTERVAL = prove
 (`!s. is_realinterval s /\ ~(euclideanreal interior_of s = {})
       ==> euclideanreal closure_of (euclideanreal interior_of s) =
           euclideanreal closure_of s`,
  REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
  DISCH_THEN(X_CHOOSE_TAC `a:real`) THEN MATCH_MP_TAC SUBSET_ANTISYM THEN
  SIMP_TAC[CLOSURE_OF_MONO; INTERIOR_OF_SUBSET] THEN
  REWRITE_TAC[SUBSET] THEN X_GEN_TAC `b:real` THEN DISCH_TAC THEN
  REPEAT_TCL DISJ_CASES_THEN
  ASSUME_TAC (REAL_ARITH `b = a \/ a:real < b \/ b < a`) THENL
   [MP_TAC(ISPECL [`euclideanreal`; `euclideanreal interior_of s`]
        CLOSURE_OF_SUBSET) THEN
    ASM_REWRITE_TAC[TOPSPACE_EUCLIDEANREAL] THEN ASM SET_TAC[];
    MP_TAC(ISPECL [`s:real->bool`; `a:real`; `b:real`]
        IS_REALINTERVAL_INTERIOR_SEGMENT);
    MP_TAC(ISPECL [`s:real->bool`; `b:real`; `a:real`]
        IS_REALINTERVAL_INTERIOR_SEGMENT)] THEN
  (ASM_REWRITE_TAC[] THEN ANTS_TAC THENL
    [ASM_MESON_TAC[INTERIOR_OF_SUBSET_CLOSURE_OF; SUBSET];
     DISCH_THEN(MP_TAC o MATCH_MP CLOSURE_OF_MONO) THEN
     REWRITE_TAC[SUBSET] THEN DISCH_THEN MATCH_MP_TAC THEN
     ASM_SIMP_TAC[CLOSURE_OF_REAL_INTERVAL; REAL_INTERVAL_EQ_EMPTY] THEN
     ASM_REWRITE_TAC[GSYM REAL_NOT_LT; IN_REAL_INTERVAL] THEN
     ASM_REAL_ARITH_TAC]));;

let CARD_FRONTIER_OF_REALINTERVAL = prove
 (`!s. is_realinterval s
       ==> FINITE(euclideanreal frontier_of s) /\
           CARD(euclideanreal frontier_of s) <= 2`,
  GEN_TAC THEN STRIP_TAC THEN REWRITE_TAC[TAUT `p /\ q <=> ~(p ==> ~q)`] THEN
  REWRITE_TAC[ARITH_RULE `~(n <= 2) <=> 3 <= n`] THEN
  DISCH_THEN(MP_TAC o MATCH_MP CHOOSE_SUBSET_STRONG) THEN
  DISCH_THEN(X_CHOOSE_THEN `t:real->bool` (CONJUNCTS_THEN MP_TAC)) THEN
  CONV_TAC(LAND_CONV HAS_SIZE_CONV) THEN
  SIMP_TAC[LEFT_IMP_EXISTS_THM; INSERT_SUBSET; EMPTY_SUBSET] THEN
  MATCH_MP_TAC REAL_WLOG_LE_3 THEN CONJ_TAC THENL
  [MESON_TAC[INSERT_AC]; ALL_TAC] THEN
  MAP_EVERY X_GEN_TAC [`a:real`; `b:real`; `c:real`] THEN
  REWRITE_TAC[frontier_of; IN_DIFF] THEN REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`s:real->bool`; `a:real`; `c:real`]
    IS_REALINTERVAL_INTERIOR_SEGMENT) THEN
  ASM_REWRITE_TAC[SUBSET; IN_REAL_INTERVAL] THEN
  DISCH_THEN(MP_TAC o SPEC `b:real`) THEN ASM_REWRITE_TAC[] THEN
  ASM_REAL_ARITH_TAC);;

let LOCALLY_COMPACT_SPACE_EUCLIDEANREAL = prove
 (`locally_compact_space euclideanreal`,
  REWRITE_TAC[locally_compact_space; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
  X_GEN_TAC `x:real` THEN MAP_EVERY EXISTS_TAC
   [`real_interval(x - &1,x + &1)`; `real_interval[x - &1,x + &1]`] THEN
  REWRITE_TAC[REAL_INTERVAL_OPEN_SUBSET_CLOSED] THEN
  REWRITE_TAC[GSYM real_compact_def; GSYM REAL_OPEN_IN] THEN
  REWRITE_TAC[REAL_COMPACT_INTERVAL; REAL_OPEN_REAL_INTERVAL] THEN
  REWRITE_TAC[IN_REAL_INTERVAL] THEN REAL_ARITH_TAC);;

(* ------------------------------------------------------------------------- *)
(* Limits at a point in a topological space.                                 *)
(* ------------------------------------------------------------------------- *)

let atpointof = new_definition
 `atpointof top a = mk_net({u | open_in top u /\ a IN u},{a})`;;

let ATPOINTOF,NETLIMITS_ATPOINTOF = (CONJ_PAIR o prove)
 (`(!top a:A.
        netfilter(atpointof top a) = {u | open_in top u /\ a IN u}) /\
   (!top a:A. netlimits(atpointof top a) = {a})`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  REWRITE_TAC[netfilter; netlimits; atpointof; GSYM PAIR_EQ] THEN
  REWRITE_TAC[GSYM(CONJUNCT2 net_tybij)] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_IN_GSPEC] THEN
  X_GEN_TAC `u:A->bool` THEN REPEAT DISCH_TAC THEN
  X_GEN_TAC `v:A->bool` THEN REPEAT DISCH_TAC THEN
  REWRITE_TAC[IN_ELIM_THM] THEN ASM_SIMP_TAC[OPEN_IN_INTER; IN_INTER]);;

let NETLIMIT_ATPOINTOF = prove
 (`!top a:A. netlimit(atpointof top a) = a`,
  REWRITE_TAC[netlimit; NETLIMITS_ATPOINTOF; IN_SING; SELECT_REFL]);;

let EVENTUALLY_ATPOINTOF = prove
 (`!P top a:A.
        eventually P (atpointof top a) <=>
        ~(a IN topspace top) \/
        ?u. open_in top u /\ a IN u /\ !x. x IN u DELETE a ==> P x`,
  REWRITE_TAC[eventually; ATPOINTOF; NETLIMITS_ATPOINTOF; EXISTS_IN_GSPEC] THEN
  REWRITE_TAC[SET_RULE `{f x | P x} = {} <=> ~(?x. P x)`] THEN
  REPEAT STRIP_TAC THEN ASM_CASES_TAC `(a:A) IN topspace top` THENL
   [ALL_TAC; ASM_MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]] THEN
  ASM_SIMP_TAC[IN_DELETE; IN_DIFF; IN_SING] THEN
  ASM_MESON_TAC[OPEN_IN_TOPSPACE]);;

let ATPOINTOF_WITHIN_TRIVIAL = prove
 (`!top u a:A.
     topspace top SUBSET u ==> (atpointof top a) within u = atpointof top a`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC(MESON[net_tybij]
   `dest_net x = dest_net y ==> x = y`) THEN
  GEN_REWRITE_TAC BINOP_CONV [GSYM PAIR] THEN
  PURE_REWRITE_TAC[GSYM netfilter; GSYM netlimits] THEN
  REWRITE_TAC[ATPOINTOF; WITHIN; NETLIMITS_ATPOINTOF; NETLIMITS_WITHIN] THEN
  REWRITE_TAC[PAIR_EQ; RELATIVE_TO] THEN
  REWRITE_TAC[SET_RULE `{f x | {g y | P y} x} = {f(g y) | P y}`] THEN
  MATCH_MP_TAC(SET_RULE
   `(!x. P x ==> f x = g x) ==> {f x | P x} = {g x | P x}`) THEN
  REPEAT STRIP_TAC THEN FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
  ASM SET_TAC[]);;

let ATPOINTOF_WITHIN_TOPSPACE = prove
 (`!top a:A. (atpointof top a) within (topspace top) = atpointof top a`,
  SIMP_TAC[ATPOINTOF_WITHIN_TRIVIAL; SUBSET_REFL]);;

let TRIVIAL_LIMIT_ATPOINTOF_WITHIN = prove
 (`!top s a:A.
        trivial_limit(atpointof top a within s) <=>
        ~(a IN top derived_set_of s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[trivial_limit; EVENTUALLY_WITHIN_IMP] THEN
  ASM_SIMP_TAC[EVENTUALLY_ATPOINTOF] THEN
  REWRITE_TAC[derived_set_of; IN_ELIM_THM] THEN
  ASM_CASES_TAC `(a:A) IN topspace top` THEN ASM_REWRITE_TAC[] THEN
  SET_TAC[]);;

let DERIVED_SET_OF_TRIVIAL_LIMIT = prove
 (`!top s a:A.
      a IN top derived_set_of s <=> ~trivial_limit(atpointof top a within s)`,
  REWRITE_TAC[TRIVIAL_LIMIT_ATPOINTOF_WITHIN]);;

let TRIVIAL_LIMIT_ATPOINTOF = prove
 (`!top a:A.
        trivial_limit(atpointof top a) <=>
        ~(a IN top derived_set_of topspace top)`,
  ONCE_REWRITE_TAC[GSYM ATPOINTOF_WITHIN_TOPSPACE] THEN
  REWRITE_TAC[TRIVIAL_LIMIT_ATPOINTOF_WITHIN]);;

let ATPOINTOF_SUBTOPOLOGY = prove
 (`!top s a:A.
        a IN s
        ==> (atpointof (subtopology top s) a =
             atpointof top a within s)`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC(MESON[net_tybij]
   `dest_net x = dest_net y ==> x = y`) THEN
  GEN_REWRITE_TAC BINOP_CONV [GSYM PAIR] THEN
  PURE_REWRITE_TAC[GSYM netfilter; GSYM netlimits] THEN
  REWRITE_TAC[WITHIN; NETLIMITS_WITHIN] THEN
  REWRITE_TAC[ATPOINTOF; NETLIMITS_ATPOINTOF] THEN
  REWRITE_TAC[PAIR_EQ; RELATIVE_TO; OPEN_IN_SUBTOPOLOGY_ALT] THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM] THEN ASM SET_TAC[]);;

let EVENTUALLY_ATPOINTOF_METRIC = prove
 (`!P m a:A.
        eventually P (atpointof (mtopology m) a) <=>
        a IN mspace m
        ==> ?d. &0 < d /\
                !x. x IN mspace m /\ &0 < mdist m (x,a) /\ mdist m (x,a) < d
                    ==> P x`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[EVENTUALLY_ATPOINTOF; TOPSPACE_MTOPOLOGY] THEN
  ASM_CASES_TAC `(a:A) IN mspace m` THEN ASM_REWRITE_TAC[] THEN EQ_TAC THENL
   [DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_MTOPOLOGY]) THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `a:A`)) THEN
    ASM_SIMP_TAC[IMP_CONJ; MDIST_POS_EQ; IN_MBALL; SUBSET; MDIST_SYM] THEN
    ASM SET_TAC[];
    ASM_SIMP_TAC[IMP_CONJ; MDIST_POS_EQ] THEN
    DISCH_THEN(X_CHOOSE_THEN `d:real` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `mball m (a:A,d)` THEN
    ASM_SIMP_TAC[OPEN_IN_MBALL; CENTRE_IN_MBALL; IN_DELETE] THEN
    REWRITE_TAC[IN_MBALL] THEN ASM_MESON_TAC[MDIST_SYM]]);;

(* ------------------------------------------------------------------------- *)
(* Limits in a topological space.                                            *)
(* ------------------------------------------------------------------------- *)

let limit = new_definition
  `limit top (f:A->B) l net <=>
   l IN topspace top /\
   (!u. open_in top u /\ l IN u ==> eventually (\x. f x IN u) net)`;;

let LIMIT_IMP_WITHIN = prove
 (`!net top (f:A->B) l s.
        limit top f l net ==> limit top f l (net within s)`,
  REWRITE_TAC[limit] THEN MESON_TAC[EVENTUALLY_IMP_WITHIN]);;

let LIMIT_IN_TOPSPACE = prove
 (`!net top f:A->B l. limit top f l net ==> l IN topspace top`,
  SIMP_TAC[limit]);;

let LIMIT_CONST = prove
(`!net:A net l:B. limit top (\a. l) l net <=> l IN topspace top`,
  SIMP_TAC[limit; EVENTUALLY_TRUE]);;

let LIMIT_REAL_CONST = prove
(`!net:A net l. limit euclideanreal (\a. l) l net`,
  REWRITE_TAC[LIMIT_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV]);;

let LIMIT_EVENTUALLY = prove
 (`!top net f:K->A l.
        l IN topspace top /\ eventually (\x. f x = l) net
        ==> limit top f l net`,
  REPEAT STRIP_TAC THEN ASM_REWRITE_TAC[limit] THEN
  GEN_TAC THEN STRIP_TAC THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
   (REWRITE_RULE[IMP_CONJ_ALT] EVENTUALLY_MONO)) THEN
  ASM_SIMP_TAC[]);;

let LIMIT_WITHIN_SUBSET = prove
 (`!net top f:A->B l s t.
        limit top f l (net within s) /\ t SUBSET s
        ==> limit top f l (net within t)`,
  REWRITE_TAC[limit] THEN ASM_MESON_TAC[EVENTUALLY_WITHIN_SUBSET]);;

let LIMIT_SUBSEQUENCE = prove
 (`!top f:num->A l r.
        (!m n. m < n ==> r m < r n) /\ limit top f l sequentially
        ==> limit top (f o r) l sequentially`,
  REPEAT GEN_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  REWRITE_TAC[limit] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_FORALL THEN GEN_TAC THEN
  MATCH_MP_TAC MONO_IMP THEN REWRITE_TAC[] THEN
  UNDISCH_TAC `!m n. m < n ==> (r:num->num) m < r n` THEN
  REWRITE_TAC[IMP_IMP] THEN
  DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_SUBSEQUENCE) THEN
  REWRITE_TAC[o_DEF]);;

let LIMIT_SUBTOPOLOGY = prove
 (`!net top s l f:A->B.
        limit (subtopology top s) f l net <=>
        l IN s /\ eventually (\a. f a IN s) net /\ limit top f l net`,
  REPEAT GEN_TAC THEN REWRITE_TAC[limit; TOPSPACE_SUBTOPOLOGY] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; IMP_CONJ; FORALL_IN_GSPEC] THEN
  REWRITE_TAC[IN_INTER; IMP_IMP] THEN
  ASM_CASES_TAC `(l:B) IN s` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `(l:B) IN topspace top` THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC(MESON[]
   `(?x. P x) /\ (!x. P x ==> (Q x <=> A /\ R x))
    ==> ((!x. P x ==> Q x) <=> A /\ (!x. P x ==> R x))`) THEN
  REWRITE_TAC[EVENTUALLY_AND] THEN ASM_MESON_TAC[OPEN_IN_TOPSPACE]);;

let LIMIT_HAUSDORFF_UNIQUE = prove
 (`!net top f:A->B l1 l2.
     ~trivial_limit net /\
     hausdorff_space top /\
     limit top f l1 net /\
     limit top f l2 net
     ==> l1 = l2`,
  REWRITE_TAC[limit; hausdorff_space] THEN
  INTRO_TAC "! *; nontriv hp (l1 hp1) (l2 hp2)" THEN
  REFUTE_THEN (LABEL_TAC "contra") THEN
  REMOVE_THEN "hp" (MP_TAC o SPECL [`l1:B`; `l2:B`]) THEN
  ASM_REWRITE_TAC[NOT_EXISTS_THM] THEN REPEAT GEN_TAC THEN
  CUT_TAC `open_in top u /\ open_in top v /\ l1:B IN u /\ l2:B IN v
           ==> ?x:A. f x IN u /\ f x IN v` THENL
  [SET_TAC[]; STRIP_TAC] THEN
  CLAIM_TAC "rmk" `eventually (\x:A. f x:B IN u /\ f x IN v) net` THENL
  [ASM_SIMP_TAC[EVENTUALLY_AND];
   HYP_TAC "rmk" (MATCH_MP EVENTUALLY_HAPPENS) THEN ASM_MESON_TAC[]]);;

let LIMIT_SEQUENTIALLY = prove
 (`!top s l:A.
     limit top s l sequentially <=>
     l IN topspace top /\
     (!u. open_in top u /\ l IN u ==> (?N. !n. N <= n ==> s n IN u))`,
  REWRITE_TAC[limit; EVENTUALLY_SEQUENTIALLY]);;

let LIMIT_SEQUENTIALLY_OFFSET = prove
 (`!top f l:A k. limit top f l sequentially
                 ==> limit top (\i. f (i + k)) l sequentially`,
  SIMP_TAC[LIMIT_SEQUENTIALLY] THEN INTRO_TAC "! *; l lim; !u; hp" THEN
  USE_THEN "hp" (HYP_TAC "lim: @N. N" o C MATCH_MP) THEN
  EXISTS_TAC `N:num` THEN INTRO_TAC "!n; n" THEN
  USE_THEN "N" MATCH_MP_TAC THEN ASM_ARITH_TAC);;

let LIMIT_SEQUENTIALLY_OFFSET_REV = prove
 (`!top f l:A k. limit top (\i. f (i + k)) l sequentially
                 ==> limit top f l sequentially`,
  SIMP_TAC[LIMIT_SEQUENTIALLY] THEN INTRO_TAC "! *; l lim; !u; hp" THEN
  USE_THEN "hp" (HYP_TAC "lim: @N. N" o C MATCH_MP) THEN
  EXISTS_TAC `N+k:num` THEN INTRO_TAC "!n; n" THEN
  REMOVE_THEN "N" (MP_TAC o SPEC `n-k:num`) THEN
  ANTS_TAC THENL [ASM_ARITH_TAC; ALL_TAC] THEN
  SUBGOAL_THEN `n - k + k = n:num` (fun th -> REWRITE_TAC[th]) THEN
  ASM_ARITH_TAC);;

let LIMIT_ATPOINTOF = prove
 (`!top top' f:A->B x y.
        limit top' f y (atpointof top x) <=>
        y IN topspace top' /\
        (x IN topspace top
         ==> !v. open_in top' v /\ y IN v
                 ==> ?u. open_in top u /\ x IN u /\
                         IMAGE f (u DELETE x) SUBSET v)`,
  REPEAT GEN_TAC THEN ASM_SIMP_TAC[limit; EVENTUALLY_ATPOINTOF] THEN
  ASM_CASES_TAC `(y:B) IN topspace top'` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `(x:A) IN topspace top` THEN ASM_REWRITE_TAC[] THEN
  AP_TERM_TAC THEN ABS_TAC THEN SET_TAC[]);;

let LIMIT_ATPOINTOF_SELF = prove
 (`!top1 top2 f:A->B a.
        limit top2 f (f a) (atpointof top1 a) <=>
        f a IN topspace top2 /\
        (a IN topspace top1
         ==> (!v. open_in top2 v /\ f a IN v
                  ==> (?u. open_in top1 u /\ a IN u /\ IMAGE f u SUBSET v)))`,
  REWRITE_TAC[LIMIT_ATPOINTOF] THEN SET_TAC[]);;

let LIMIT_TRIVIAL = prove
 (`!net f:A->B top y.
        trivial_limit net /\ y IN topspace top ==> limit top f y net`,
  SIMP_TAC[limit; EVENTUALLY_TRIVIAL]);;

let LIMIT_TRANSFORM_EVENTUALLY = prove
 (`!net top f:A->B g l.
        eventually (\x. f x = g x) net /\ limit top f l net
        ==> limit top g l net`,
  REPEAT GEN_TAC THEN REWRITE_TAC[limit] THEN
  ASM_CASES_TAC `(l:B) IN topspace top` THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC(MESON[]
   `(?x. Q x) /\ (!x. P /\ R x ==> R' x)
    ==> P /\ (!x. Q x ==> R x) ==> (!x. Q x ==> R' x)`) THEN
  CONJ_TAC THENL [ASM_MESON_TAC[OPEN_IN_TOPSPACE]; ALL_TAC] THEN
  REWRITE_TAC[GSYM EVENTUALLY_AND] THEN GEN_TAC THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  MESON_TAC[]);;

let CONTINUOUS_MAP_LIMIT = prove
 (`!net top top' f:A->B g:B->C l.
     continuous_map (top,top')  g /\ limit top f l net
     ==> limit top' (g o f) (g l) net`,
  REWRITE_TAC[limit; o_THM] THEN INTRO_TAC "! *; cont l lim" THEN
  USE_THEN "cont" MP_TAC THEN REWRITE_TAC[continuous_map] THEN
  INTRO_TAC "g cont" THEN ASM_SIMP_TAC[] THEN INTRO_TAC "!u; u gl" THEN
  ASM_CASES_TAC `trivial_limit (net:A net)` THENL
  [ASM_REWRITE_TAC[eventually]; POP_ASSUM (LABEL_TAC "nontriv")] THEN
  REMOVE_THEN "lim"
    (MP_TAC o SPEC `{x:B | x IN topspace top /\ g x:C IN u}`) THEN
  ASM_SIMP_TAC[IN_ELIM_THM; eventually] THEN MESON_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Topological limit in metric spaces.                                       *)
(* ------------------------------------------------------------------------- *)

let LIMIT_IN_MSPACE = prove
 (`!net m f:A->B l. limit (mtopology m) f l net ==> l IN mspace m`,
  MESON_TAC[LIMIT_IN_TOPSPACE; TOPSPACE_MTOPOLOGY]);;

let LIMIT_METRIC_UNIQUE = prove
 (`!net m f:A->B l1 l2.
     ~trivial_limit net /\
     limit (mtopology m) f l1 net /\
     limit (mtopology m) f l2 net
     ==> l1 = l2`,
  MESON_TAC[LIMIT_HAUSDORFF_UNIQUE; HAUSDORFF_SPACE_MTOPOLOGY]);;

let LIMIT_METRIC = prove
 (`!m f:A->B l net.
     limit (mtopology m) f l net <=>
     l IN mspace m /\
     (!e. &0 < e
          ==> eventually (\x. f x IN mspace m /\ mdist m (f x, l) < e) net)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[limit; OPEN_IN_MTOPOLOGY; TOPSPACE_MTOPOLOGY] THEN EQ_TAC THENL
  [INTRO_TAC "l hp" THEN ASM_REWRITE_TAC[] THEN INTRO_TAC "!e; e" THEN
   REMOVE_THEN "hp" (MP_TAC o SPEC `mball m (l:B,e)`) THEN
   ASM_REWRITE_TAC[MBALL_SUBSET_MSPACE] THEN ASM_SIMP_TAC[CENTRE_IN_MBALL] THEN
   REWRITE_TAC[IN_MBALL] THEN ANTS_TAC THENL
   [INTRO_TAC "!x; x lt" THEN
    EXISTS_TAC `e - mdist m (l:B,x)` THEN
    CONJ_TAC THENL
    [ASM_REAL_ARITH_TAC;
     ASM_REWRITE_TAC[SUBSET; IN_MBALL] THEN INTRO_TAC "![y]; y lt'" THEN
     ASM_REWRITE_TAC[] THEN
     TRANS_TAC REAL_LET_TRANS `mdist m (l:B,x) + mdist m (x,y)` THEN
     ASM_SIMP_TAC[MDIST_TRIANGLE] THEN ASM_REAL_ARITH_TAC];
    MATCH_MP_TAC (REWRITE_RULE [IMP_CONJ] EVENTUALLY_MONO) THEN
    GEN_TAC THEN REWRITE_TAC[] THEN ASM_CASES_TAC `f (x:A):B IN mspace m` THEN
    ASM_SIMP_TAC[MDIST_SYM]];
   INTRO_TAC "l hp" THEN ASM_REWRITE_TAC[] THEN INTRO_TAC "!u; (u hp) l" THEN
   REMOVE_THEN "hp"
     (DESTRUCT_TAC "@r. r sub" o C MATCH_MP (ASSUME `l:B IN u`)) THEN
   REMOVE_THEN "hp" (MP_TAC o C MATCH_MP (ASSUME `&0 < r`)) THEN
   MATCH_MP_TAC (REWRITE_RULE [IMP_CONJ] EVENTUALLY_MONO) THEN
   GEN_TAC THEN REWRITE_TAC[] THEN INTRO_TAC "f lt" THEN
   CLAIM_TAC "rmk" `f (x:A):B IN mball m (l,r)` THENL
   [ASM_SIMP_TAC[IN_MBALL; MDIST_SYM]; HYP SET_TAC "rmk sub" []]]);;

let LIMIT_METRIC_SEQUENTIALLY = prove
 (`!m f:num->A l.
     limit (mtopology m) f l sequentially <=>
     l IN mspace m /\
     (!e. &0 < e ==> (?N. !n. N <= n
                              ==> f n IN mspace m /\ mdist m (f n,l) < e))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[LIMIT_METRIC; EVENTUALLY_SEQUENTIALLY] THEN
  EQ_TAC THEN STRIP_TAC THEN ASM_REWRITE_TAC[]);;

let LIMIT_IN_CLOSED_IN = prove
 (`!net top s f:A->B l.
      ~trivial_limit net /\ limit top f l net /\
      closed_in top s /\ eventually (\x. f x IN s) net
      ==> l IN s`,
  INTRO_TAC "! *; ntriv lim cl ev" THEN REFUTE_THEN (LABEL_TAC "contra") THEN
  HYP_TAC "lim: l lim" (REWRITE_RULE[limit]) THEN
  REMOVE_THEN "lim" (MP_TAC o SPEC `topspace top DIFF s:B->bool`) THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE; IN_DIFF; EVENTUALLY_AND] THEN
  REWRITE_TAC[DE_MORGAN_THM] THEN DISJ2_TAC THEN INTRO_TAC "nev" THEN
  HYP (MP_TAC o CONJ_LIST) "ev nev" [] THEN
  REWRITE_TAC[GSYM EVENTUALLY_AND] THEN MATCH_MP_TAC NOT_EVENTUALLY THEN
  ASM_REWRITE_TAC[] THEN MESON_TAC[]);;

let LIMIT_SUBMETRIC_IFF = prove
 (`!net m s f:A->B l.
     limit (mtopology (submetric m s)) f l net <=>
     l IN s /\ eventually (\x. f x IN s) net /\ limit (mtopology m) f l net`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[LIMIT_METRIC; SUBMETRIC; IN_INTER; EVENTUALLY_AND] THEN
  EQ_TAC THEN SIMP_TAC[] THENL [INTRO_TAC "l hp"; MESON_TAC[]] THEN
  HYP_TAC "hp" (C MATCH_MP REAL_LT_01) THEN ASM_REWRITE_TAC[]);;

let METRIC_CLOSED_IN_IFF_SEQUENTIALLY_CLOSED = prove
 (`!m s:A->bool.
     closed_in (mtopology m) s <=>
     s SUBSET mspace m /\
     (!a l. (!n. a n IN s) /\ limit (mtopology m) a l sequentially
            ==> l IN s)`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
  [INTRO_TAC "cl" THEN CONJ_TAC THENL
   [ASM_MESON_TAC[CLOSED_IN_METRIC]; INTRO_TAC "!a l; a lim"] THEN
   MATCH_MP_TAC
     (ISPECL[`sequentially`; `mtopology (m:A metric)`] LIMIT_IN_CLOSED_IN) THEN
   EXISTS_TAC `a:num->A` THEN
   ASM_REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY; EVENTUALLY_TRUE];
   ALL_TAC] THEN
  SIMP_TAC[CLOSED_IN_METRIC; IN_DIFF] THEN
  INTRO_TAC "sub seq; !x; x diff" THEN
  REFUTE_THEN (LABEL_TAC "contra" o
    REWRITE_RULE[NOT_EXISTS_THM; MESON[] `~(a /\ b) <=> a ==> ~b`]) THEN
  CLAIM_TAC "@a. a lt"
    `?a. (!n. a n:A IN s) /\ (!n. mdist m (x, a n) < inv(&n + &1))` THENL
  [REWRITE_TAC[GSYM FORALL_AND_THM; GSYM SKOLEM_THM] THEN GEN_TAC THEN
   REMOVE_THEN "contra" (MP_TAC o SPEC `inv (&n + &1)`) THEN
   ANTS_TAC THENL [MATCH_MP_TAC REAL_LT_INV THEN REAL_ARITH_TAC; ALL_TAC] THEN
   REWRITE_TAC[SET_RULE `~DISJOINT s t <=> ?x:A. x IN s /\ x IN t`] THEN
   ASM_REWRITE_TAC[IN_MBALL] THEN MESON_TAC[];
   ALL_TAC] THEN
  CLAIM_TAC "a'" `!n:num. a n:A IN mspace m` THENL
  [HYP SET_TAC "sub a" []; ALL_TAC] THEN
  REMOVE_THEN "seq" (MP_TAC o SPECL[`a:num->A`;`x:A`]) THEN
  ASM_REWRITE_TAC[LIMIT_METRIC_SEQUENTIALLY] THEN INTRO_TAC "!e; e" THEN
  HYP_TAC "e -> @N. NZ Ngt Nlt" (ONCE_REWRITE_RULE[REAL_ARCH_INV]) THEN
  EXISTS_TAC `N:num` THEN INTRO_TAC "!n; n" THEN
  TRANS_TAC REAL_LT_TRANS `inv (&n + &1)` THEN CONJ_TAC THENL
  [HYP MESON_TAC "lt a' x" [MDIST_SYM]; ALL_TAC] THEN
  TRANS_TAC REAL_LET_TRANS `inv (&N)` THEN HYP REWRITE_TAC "Nlt" [] THEN
  MATCH_MP_TAC REAL_LE_INV2 THEN
  REWRITE_TAC[REAL_OF_NUM_LT; REAL_OF_NUM_LE; REAL_OF_NUM_ADD] THEN
  ASM_ARITH_TAC);;

let LIMIT_ATPOINTOF_METRIC = prove
 (`!m top f:A->B x y.
        limit top f y (atpointof (mtopology m) x) <=>
        y IN topspace top /\
        (x IN mspace m
         ==> !v. open_in top v /\ y IN v
                 ==> ?d. &0 < d /\
                         !x'. x' IN mspace m /\
                              &0 < mdist m (x',x) /\ mdist m (x',x) < d
                              ==> f x' IN v)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[limit; EVENTUALLY_ATPOINTOF_METRIC] THEN
  MESON_TAC[]);;

let LIMIT_METRIC_DIST_NULL = prove
 (`!net m (f:K->A) l.
        limit (mtopology m) f l net <=>
        l IN mspace m /\ eventually (\x. f x IN mspace m) net /\
        limit euclideanreal (\x. mdist m (f x,l)) (&0) net`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[LIMIT_METRIC; GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV; EVENTUALLY_AND] THEN
  ASM_CASES_TAC `(l:A) IN mspace m` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[GSYM EVENTUALLY_AND; MESON[REAL_LT_01]
   `P /\ (!e. &0 < e ==> Q e) <=> (!e. &0 < e ==> P /\ Q e)`] THEN
  REWRITE_TAC[REAL_ARITH `abs(&0 - x) = abs x`] THEN
  ASM_SIMP_TAC[TAUT `(p /\ q) <=> ~(p ==> ~q)`; MDIST_POS_LE; real_abs]);;

let LIMIT_NULL_REAL = prove
 (`!net f:A->real.
        limit euclideanreal f (&0) net <=>
        !e. &0 < e ==> eventually (\a. abs(f a) < e) net`,
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC; LIMIT_METRIC] THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  REWRITE_TAC[REAL_ARITH `abs(&0 - x) = abs x`]);;

let LIMIT_NULL_REAL_ABS = prove
 (`!net (f:A->real).
        limit euclideanreal (\a. abs(f a)) (&0) net <=>
        limit euclideanreal f (&0) net`,
  REWRITE_TAC[LIMIT_NULL_REAL; REAL_ABS_ABS]);;

let LIMIT_NULL_REAL_COMPARISON = prove
 (`!net f g:A->real.
        limit euclideanreal f (&0) net /\
        eventually (\a. abs(g a) <= abs(f a)) net
        ==> limit euclideanreal g (&0) net`,
  REPEAT GEN_TAC THEN REWRITE_TAC[LIMIT_NULL_REAL] THEN
  STRIP_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN
  UNDISCH_TAC `&0 < e` THEN SIMP_TAC[] THEN DISCH_THEN(K ALL_TAC) THEN
  POP_ASSUM MP_TAC THEN REWRITE_TAC[IMP_IMP; GSYM EVENTUALLY_AND] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  REWRITE_TAC[] THEN REAL_ARITH_TAC);;

let LIMIT_NULL_REAL_HARMONIC_OFFSET = prove
 (`!a. limit euclideanreal (\n. inv(&n + a)) (&0) sequentially`,
  REWRITE_TAC[LIMIT_NULL_REAL; ARCH_EVENTUALLY_ABS_INV_OFFSET]);;

(* ------------------------------------------------------------------------- *)
(* More sequential characterizations in a metric space.                      *)
(* ------------------------------------------------------------------------- *)

let [EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY;
     EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_INJ;
     EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_DECREASING] = (CONJUNCTS o prove)
 (`(!met P s a:A.
        eventually P (atpointof (mtopology met) a within s) <=>
        !x. (!n. x(n) IN (s INTER mspace met) DELETE a) /\
            limit (mtopology met) x a sequentially
            ==> eventually (\n. P(x n)) sequentially) /\
   (!met P s a:A.
        eventually P (atpointof (mtopology met) a within s) <=>
        !x. (!n. x(n) IN (s INTER mspace met) DELETE a) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology met) x a sequentially
            ==> eventually (\n. P(x n)) sequentially) /\
   (!met P s a:A.
        eventually P (atpointof (mtopology met) a within s) <=>
        !x. (!n. x(n) IN (s INTER mspace met) DELETE a) /\
            (!m n. m < n ==> mdist met (x n,a) < mdist met (x m,a)) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology met) x a sequentially
            ==> eventually (\n. P(x n)) sequentially)`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  MATCH_MP_TAC(TAUT
   `(r ==> s) /\ (q ==> r) /\ (p ==> q) /\ (s ==> p)
    ==> (p <=> q) /\ (p <=> r) /\ (p <=> s)`) THEN
  REPEAT CONJ_TAC THENL
   [MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `x:num->A` THEN
    DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN MATCH_MP_TAC THEN
    MATCH_MP_TAC WLOG_LT THEN REWRITE_TAC[] THEN
    ASM_MESON_TAC[REAL_LT_REFL];
    MATCH_MP_TAC MONO_FORALL THEN MESON_TAC[];
    REWRITE_TAC[EVENTUALLY_WITHIN_IMP; EVENTUALLY_ATPOINTOF] THEN
    REWRITE_TAC[limit; TOPSPACE_MTOPOLOGY] THEN
    ASM_CASES_TAC `(a:A) IN mspace met` THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM; IMP_IMP; IN_DELETE; IN_INTER] THEN
    X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
    X_GEN_TAC `x:num->A` THEN REWRITE_TAC[FORALL_AND_THM] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `u:A->bool`) THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN ASM SET_TAC[];
    STRIP_TAC THEN
    REWRITE_TAC[EVENTUALLY_ATPOINTOF_METRIC; EVENTUALLY_WITHIN_IMP] THEN
    DISCH_TAC THEN ASM_SIMP_TAC[IMP_CONJ; MDIST_POS_EQ] THEN
    GEN_REWRITE_TAC I [MESON[]
      `(?d. P d /\ Q d) <=> ~(!d. P d ==> ~Q d)`] THEN
    GEN_REWRITE_TAC (RAND_CONV o TOP_DEPTH_CONV)
     [NOT_FORALL_THM; NOT_IMP; GSYM CONJ_ASSOC] THEN
    DISCH_TAC THEN
    SUBGOAL_THEN
     `?x. (!n. (x n) IN mspace met /\
              ~(x n = a) /\
               mdist met (x n,a) < inv(&n + &1) /\
               x n IN s /\
               ~P(x n:A)) /\
          (!n. mdist met (x(SUC n),a) < mdist met (x n,a))`
    STRIP_ASSUME_TAC THENL
     [MATCH_MP_TAC DEPENDENT_CHOICE THEN CONV_TAC REAL_RAT_REDUCE_CONV THEN
      CONJ_TAC THENL [ASM_MESON_TAC[REAL_LT_01]; ALL_TAC] THEN
      MAP_EVERY X_GEN_TAC [`n:num`; `x:A`] THEN STRIP_TAC THEN
      SIMP_TAC[TAUT `(p /\ q /\ r /\ s /\ t) /\ u <=>
                      p /\ q /\ (r /\ u) /\ s /\ t`] THEN
      REWRITE_TAC[GSYM REAL_LT_MIN] THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
      ASM_SIMP_TAC[REAL_LT_MIN; MDIST_POS_EQ; REAL_LT_INV_EQ] THEN
      REAL_ARITH_TAC;
      FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN
      ASM_REWRITE_TAC[NOT_IMP; IN_DELETE; IN_INTER; GSYM CONJ_ASSOC] THEN
      MATCH_MP_TAC(TAUT `p /\ (p ==> q) ==> p /\ q`) THEN CONJ_TAC THENL
       [MATCH_MP_TAC  TRANSITIVE_STEPWISE_LT THEN
        ASM_REWRITE_TAC[] THEN REAL_ARITH_TAC;
        DISCH_TAC] THEN
      REPEAT CONJ_TAC THENL
       [MATCH_MP_TAC WLOG_LT THEN ASM_MESON_TAC[REAL_LT_REFL];
        ASM_REWRITE_TAC[LIMIT_METRIC; EVENTUALLY_SEQUENTIALLY] THEN
        MATCH_MP_TAC FORALL_POS_MONO_1 THEN CONJ_TAC THENL
         [MESON_TAC[REAL_LT_TRANS]; ALL_TAC] THEN
        X_GEN_TAC `N:num` THEN EXISTS_TAC `N:num` THEN
        X_GEN_TAC `n:num` THEN DISCH_TAC THEN
        TRANS_TAC REAL_LTE_TRANS `inv(&n + &1)` THEN
        ASM_REWRITE_TAC[] THEN MATCH_MP_TAC REAL_LE_INV2 THEN
        REWRITE_TAC[REAL_OF_NUM_LE; REAL_OF_NUM_LT; REAL_OF_NUM_ADD] THEN
        ASM_ARITH_TAC;
        REWRITE_TAC[EVENTUALLY_FALSE; TRIVIAL_LIMIT_SEQUENTIALLY]]]]);;

let EVENTUALLY_ATPOINTOF_SEQUENTIALLY = prove
 (`!met P a:A.
        eventually P (atpointof (mtopology met) a) <=>
        !x. (!n. x(n) IN mspace met DELETE a) /\
            limit (mtopology met) x a sequentially
            ==> eventually (\n. P(x n)) sequentially`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [GSYM NET_WITHIN_UNIV] THEN
  SIMP_TAC[EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY; INTER_UNIV]);;

let EVENTUALLY_ATPOINTOF_SEQUENTIALLY_INJ = prove
 (`!met P a:A.
        eventually P (atpointof (mtopology met) a) <=>
        !x. (!n. x(n) IN mspace met DELETE a) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology met) x a sequentially
            ==> eventually (\n. P(x n)) sequentially`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [GSYM NET_WITHIN_UNIV] THEN
  SIMP_TAC[EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_INJ; INTER_UNIV]);;

let EVENTUALLY_ATPOINTOF_SEQUENTIALLY_DECREASING = prove
 (`!met P a:A.
        eventually P (atpointof (mtopology met) a) <=>
        !x. (!n. x(n) IN mspace met DELETE a) /\
            (!m n. m < n ==> mdist met (x n,a) < mdist met (x m,a)) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology met) x a sequentially
            ==> eventually (\n. P(x n)) sequentially`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [GSYM NET_WITHIN_UNIV] THEN
  SIMP_TAC[EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_DECREASING; INTER_UNIV]);;

let LIMIT_ATPOINTOF_SEQUENTIALLY_WITHIN = prove
 (`!m1 m2 s f:A->B a l.
        limit (mtopology m2) f l (atpointof (mtopology m1) a within s) <=>
        l IN mspace m2 /\
        !x. (!n. x(n) IN (s INTER mspace m1) DELETE a) /\
            limit (mtopology m1) x a sequentially
            ==> limit (mtopology m2) (f o x) l sequentially`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC LAND_CONV [limit] THEN
  ASM_CASES_TAC `(l:B) IN mspace m2` THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
  GEN_REWRITE_TAC (RAND_CONV o BINDER_CONV o RAND_CONV) [limit] THEN
  REWRITE_TAC[EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY] THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY; o_DEF; RIGHT_IMP_FORALL_THM] THEN
  GEN_REWRITE_TAC RAND_CONV [SWAP_FORALL_THM] THEN
  REWRITE_TAC[IMP_IMP; CONJ_ACI]);;

let LIMIT_ATPOINTOF_SEQUENTIALLY_WITHIN_INJ = prove
 (`!m1 m2 s f:A->B a l.
        limit (mtopology m2) f l (atpointof (mtopology m1) a within s) <=>
        l IN mspace m2 /\
        !x. (!n. x(n) IN (s INTER mspace m1) DELETE a) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology m1) x a sequentially
            ==> limit (mtopology m2) (f o x) l sequentially`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC LAND_CONV [limit] THEN
  ASM_CASES_TAC `(l:B) IN mspace m2` THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
  GEN_REWRITE_TAC (RAND_CONV o BINDER_CONV o RAND_CONV) [limit] THEN
  REWRITE_TAC[EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_INJ] THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY; o_DEF; RIGHT_IMP_FORALL_THM] THEN
  GEN_REWRITE_TAC RAND_CONV [SWAP_FORALL_THM] THEN
  REWRITE_TAC[IMP_IMP; CONJ_ACI]);;

let LIMIT_ATPOINTOF_SEQUENTIALLY_WITHIN_DECREASING = prove
 (`!m1 m2 s f:A->B a l.
        limit (mtopology m2) f l (atpointof (mtopology m1) a within s) <=>
        l IN mspace m2 /\
        !x. (!n. x(n) IN (s INTER mspace m1) DELETE a) /\
            (!m n. m < n ==> mdist m1 (x n,a) < mdist m1 (x m,a)) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology m1) x a sequentially
            ==> limit (mtopology m2) (f o x) l sequentially`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC LAND_CONV [limit] THEN
  ASM_CASES_TAC `(l:B) IN mspace m2` THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
  GEN_REWRITE_TAC (RAND_CONV o BINDER_CONV o RAND_CONV) [limit] THEN
  REWRITE_TAC[EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_DECREASING] THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY; o_DEF; RIGHT_IMP_FORALL_THM] THEN
  GEN_REWRITE_TAC RAND_CONV [SWAP_FORALL_THM] THEN
  REWRITE_TAC[IMP_IMP; CONJ_ACI]);;

let LIMIT_ATPOINTOF_SEQUENTIALLY = prove
 (`!m1 m2 f:A->B a l.
        limit (mtopology m2) f l (atpointof (mtopology m1) a) <=>
        l IN mspace m2 /\
        !x. (!n. x(n) IN mspace m1 DELETE a) /\
            limit (mtopology m1) x a sequentially
            ==> limit (mtopology m2) (f o x) l sequentially`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [GSYM NET_WITHIN_UNIV] THEN
  REWRITE_TAC[LIMIT_ATPOINTOF_SEQUENTIALLY_WITHIN] THEN
  REWRITE_TAC[INTER_UNIV]);;

let LIMIT_ATPOINTOF_SEQUENTIALLY_INJ = prove
 (`!m1 m2 f:A->B a l.
        limit (mtopology m2) f l (atpointof (mtopology m1) a) <=>
        l IN mspace m2 /\
        !x. (!n. x(n) IN mspace m1 DELETE a) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology m1) x a sequentially
            ==> limit (mtopology m2) (f o x) l sequentially`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [GSYM NET_WITHIN_UNIV] THEN
  REWRITE_TAC[LIMIT_ATPOINTOF_SEQUENTIALLY_WITHIN_INJ] THEN
  REWRITE_TAC[INTER_UNIV]);;

let LIMIT_ATPOINTOF_SEQUENTIALLY_DECREASING = prove
 (`!m1 m2 f:A->B a l.
        limit (mtopology m2) f l (atpointof (mtopology m1) a) <=>
        l IN mspace m2 /\
        !x. (!n. x(n) IN mspace m1 DELETE a) /\
            (!m n. m < n ==> mdist m1 (x n,a) < mdist m1 (x m,a)) /\
            (!m n. x m = x n <=> m = n) /\
            limit (mtopology m1) x a sequentially
            ==> limit (mtopology m2) (f o x) l sequentially`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [GSYM NET_WITHIN_UNIV] THEN
  REWRITE_TAC[LIMIT_ATPOINTOF_SEQUENTIALLY_WITHIN_DECREASING] THEN
  REWRITE_TAC[INTER_UNIV]);;

let DERIVED_SET_OF_SEQUENTIALLY = prove
 (`!met s:A->bool.
        (mtopology met) derived_set_of s =
        {x | x IN mspace met /\
             ?f. (!n. f(n) IN ((s INTER mspace met) DELETE x)) /\
                 limit (mtopology met) f x sequentially}`,
  REWRITE_TAC[DERIVED_SET_OF_TRIVIAL_LIMIT; EXTENSION; IN_ELIM_THM] THEN
  REWRITE_TAC[trivial_limit; EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY] THEN
  REWRITE_TAC[EVENTUALLY_FALSE; TRIVIAL_LIMIT_SEQUENTIALLY] THEN
  REWRITE_TAC[limit; TOPSPACE_MTOPOLOGY] THEN MESON_TAC[]);;

let DERIVED_SET_OF_SEQUENTIALLY_ALT = prove
 (`!met s:A->bool.
        (mtopology met) derived_set_of s =
        {x | ?f. (!n. f(n) IN (s DELETE x)) /\
                 limit (mtopology met) f x sequentially}`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[DERIVED_SET_OF_TRIVIAL_LIMIT; EXTENSION; IN_ELIM_THM] THEN
  REWRITE_TAC[trivial_limit; EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY] THEN
  REWRITE_TAC[EVENTUALLY_FALSE; TRIVIAL_LIMIT_SEQUENTIALLY] THEN
  X_GEN_TAC `x:A` THEN REWRITE_TAC[NOT_FORALL_THM; IN_DELETE; IN_INTER] THEN
  EQ_TAC THENL [MESON_TAC[]; REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `a:num->A` THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [limit]) THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN DISCH_THEN(CONJUNCTS_THEN2
   ASSUME_TAC (MP_TAC o SPEC `topspace(mtopology met):A->bool`)) THEN
  REWRITE_TAC[OPEN_IN_TOPSPACE] THEN ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `N:num` THEN DISCH_TAC THEN
  EXISTS_TAC `\n. (a:num->A) (N + n)` THEN ASM_SIMP_TAC[LE_ADD] THEN
  ONCE_REWRITE_TAC[ADD_SYM] THEN MATCH_MP_TAC LIMIT_SEQUENTIALLY_OFFSET THEN
  ASM_REWRITE_TAC[]);;

let DERIVED_SET_OF_SEQUENTIALLY_INJ = prove
 (`!met s:A->bool.
        (mtopology met) derived_set_of s =
        {x | x IN mspace met /\
             ?f. (!n. f(n) IN ((s INTER mspace met) DELETE x)) /\
                 (!m n. f m = f n <=> m = n) /\
                 limit (mtopology met) f x sequentially}`,
  REWRITE_TAC[DERIVED_SET_OF_TRIVIAL_LIMIT; EXTENSION; IN_ELIM_THM] THEN
  REWRITE_TAC[trivial_limit; EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_INJ] THEN
  REWRITE_TAC[EVENTUALLY_FALSE; TRIVIAL_LIMIT_SEQUENTIALLY] THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[limit; TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[NOT_FORALL_THM; RIGHT_AND_EXISTS_THM] THEN
  AP_TERM_TAC THEN ABS_TAC THEN REWRITE_TAC[CONJ_ACI]);;

let DERIVED_SET_OF_SEQUENTIALLY_INJ_ALT = prove
 (`!met s:A->bool.
        (mtopology met) derived_set_of s =
        {x | ?f. (!n. f(n) IN (s DELETE x)) /\
                 (!m n. f m = f n <=> m = n) /\
                 limit (mtopology met) f x sequentially}`,
  REPEAT GEN_TAC THEN REWRITE_TAC[DERIVED_SET_OF_SEQUENTIALLY_INJ] THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM; IN_INTER; IN_DELETE] THEN
  X_GEN_TAC `x:A` THEN
  EQ_TAC THENL [MESON_TAC[]; REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `a:num->A` THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [limit]) THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN DISCH_THEN(CONJUNCTS_THEN2
   ASSUME_TAC (MP_TAC o SPEC `topspace(mtopology met):A->bool`)) THEN
  REWRITE_TAC[OPEN_IN_TOPSPACE] THEN ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `N:num` THEN DISCH_TAC THEN
  EXISTS_TAC `\n. (a:num->A) (N + n)` THEN
  ASM_SIMP_TAC[LE_ADD; EQ_ADD_LCANCEL] THEN
  ONCE_REWRITE_TAC[ADD_SYM] THEN MATCH_MP_TAC LIMIT_SEQUENTIALLY_OFFSET THEN
  ASM_REWRITE_TAC[]);;

let DERIVED_SET_OF_SEQUENTIALLY_DECREASING = prove
 (`!met s:A->bool.
        (mtopology met) derived_set_of s =
        {x | x IN mspace met /\
             ?f. (!n. f(n) IN ((s INTER mspace met) DELETE x)) /\
                 (!m n. m < n ==> mdist met (f n,x) < mdist met (f m,x)) /\
                 (!m n. f m = f n <=> m = n) /\
                 limit (mtopology met) f x sequentially}`,
  REWRITE_TAC[DERIVED_SET_OF_TRIVIAL_LIMIT; EXTENSION; IN_ELIM_THM] THEN
  REWRITE_TAC[trivial_limit;
    EVENTUALLY_ATPOINTOF_WITHIN_SEQUENTIALLY_DECREASING] THEN
  REWRITE_TAC[EVENTUALLY_FALSE; TRIVIAL_LIMIT_SEQUENTIALLY] THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[limit; TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[NOT_FORALL_THM; RIGHT_AND_EXISTS_THM] THEN
  AP_TERM_TAC THEN ABS_TAC THEN REWRITE_TAC[CONJ_ACI]);;

let DERIVED_SET_OF_SEQUENTIALLY_DECREASING_ALT = prove
 (`!met s:A->bool.
        (mtopology met) derived_set_of s =
        {x | ?f. (!n. f(n) IN (s DELETE x)) /\
                 (!m n. m < n ==> mdist met (f n,x) < mdist met (f m,x)) /\
                 (!m n. f m = f n <=> m = n) /\
                 limit (mtopology met) f x sequentially}`,
  REPEAT GEN_TAC THEN REWRITE_TAC[DERIVED_SET_OF_SEQUENTIALLY_DECREASING] THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM; IN_INTER; IN_DELETE] THEN
  X_GEN_TAC `x:A` THEN EQ_TAC THENL
   [DISCH_THEN(MP_TAC o CONJUNCT2) THEN MATCH_MP_TAC MONO_EXISTS THEN
    MESON_TAC[];
    REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `a:num->A` THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [limit]) THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN DISCH_THEN(CONJUNCTS_THEN2
   ASSUME_TAC (MP_TAC o SPEC `topspace(mtopology met):A->bool`)) THEN
  REWRITE_TAC[OPEN_IN_TOPSPACE] THEN ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `N:num` THEN DISCH_TAC THEN
  EXISTS_TAC `\n. (a:num->A) (N + n)` THEN
  ASM_SIMP_TAC[LE_ADD; EQ_ADD_LCANCEL; LT_ADD_LCANCEL] THEN
  ONCE_REWRITE_TAC[ADD_SYM] THEN MATCH_MP_TAC LIMIT_SEQUENTIALLY_OFFSET THEN
  ASM_REWRITE_TAC[]);;

let CLOSURE_OF_SEQUENTIALLY = prove
 (`!met s:A->bool.
        (mtopology met) closure_of s =
        {x | x IN mspace met /\
             ?f. (!n. f(n) IN (s INTER mspace met)) /\
                 limit (mtopology met) f x sequentially}`,
  REPEAT GEN_TAC THEN REWRITE_TAC[EXTENSION; IN_ELIM_THM] THEN
  X_GEN_TAC `x:A` THEN EQ_TAC THENL
   [REWRITE_TAC[CLOSURE_OF; IN_INTER; IN_UNION; TOPSPACE_MTOPOLOGY] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    ASM_REWRITE_TAC[DERIVED_SET_OF_SEQUENTIALLY; IN_ELIM_THM] THEN
    REWRITE_TAC[IN_INTER; IN_DELETE] THEN
    STRIP_TAC THENL [ALL_TAC; ASM_MESON_TAC[]] THEN
    EXISTS_TAC `(\n. x):num->A` THEN
    ASM_REWRITE_TAC[LIMIT_CONST; TOPSPACE_MTOPOLOGY];
    REPEAT STRIP_TAC THEN
    MATCH_MP_TAC(ISPEC `sequentially` LIMIT_IN_CLOSED_IN) THEN
    MAP_EVERY EXISTS_TAC [`mtopology met:A topology`; `f:num->A`] THEN
    ASM_REWRITE_TAC[CLOSED_IN_CLOSURE_OF; TRIVIAL_LIMIT_SEQUENTIALLY] THEN
    MATCH_MP_TAC ALWAYS_EVENTUALLY THEN GEN_TAC THEN REWRITE_TAC[] THEN
    MATCH_MP_TAC(REWRITE_RULE[SUBSET] CLOSURE_OF_SUBSET_INTER) THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN ASM SET_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* Combining theorems for real limits.                                       *)
(* ------------------------------------------------------------------------- *)

let LIMIT_REAL_MUL = prove
 (`!(net:A net) f g l m.
        limit euclideanreal f l net /\ limit euclideanreal g m net
        ==> limit euclideanreal (\x. f x * g x) (l * m) net`,
  REPEAT GEN_TAC THEN REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[LIMIT_METRIC; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  DISCH_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(CONJUNCTS_THEN(MP_TAC o SPEC
    `min (&1) (e / &2 / (abs l + abs m + &1))`)) THEN
  ASM_SIMP_TAC[REAL_HALF; REAL_LT_DIV; REAL_LT_MIN; REAL_LT_01; IMP_IMP;
    GSYM EVENTUALLY_AND; REAL_ARITH `&0 < abs x + abs y + &1`] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  SIMP_TAC[REAL_LT_RDIV_EQ; REAL_ARITH `&0 < abs x + abs y + &1`] THEN
  X_GEN_TAC `y:A` THEN
  SIMP_TAC[REAL_LT_RDIV_EQ; REAL_ARITH `&0 < abs x + abs y + &1`] THEN
  DISCH_THEN(CONJUNCTS_THEN (CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  MATCH_MP_TAC(REAL_ARITH
   `abs((f' - f) * g') <= x /\ abs((g' - g) * f) <= y
    ==> x < e / &2 ==> y < e / &2
        ==> abs(f' * g' - f * g) < e`) THEN
  REWRITE_TAC[REAL_ABS_MUL] THEN CONJ_TAC THEN MATCH_MP_TAC REAL_LE_LMUL THEN
  ASM_REAL_ARITH_TAC);;

let LIMIT_REAL_LMUL = prove
 (`!(net:A net) c f l.
        limit euclideanreal f l net
        ==> limit euclideanreal (\x. c * f x) (c * l) net`,
  SIMP_TAC[LIMIT_REAL_MUL; LIMIT_REAL_CONST]);;

let LIMIT_REAL_LMUL_EQ = prove
 (`!(net:A net) c f l.
        limit euclideanreal (\x. c * f x) (c * l) net <=>
        c = &0 \/ limit euclideanreal f l net`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `c = &0` THEN
  ASM_REWRITE_TAC[REAL_MUL_LZERO; LIMIT_REAL_CONST] THEN
  EQ_TAC THEN REWRITE_TAC[LIMIT_REAL_LMUL] THEN
  DISCH_THEN(MP_TAC o SPEC `inv(c):real` o MATCH_MP LIMIT_REAL_LMUL) THEN
  ASM_SIMP_TAC[REAL_MUL_ASSOC; REAL_MUL_LINV; REAL_MUL_LID; ETA_AX]);;

let LIMIT_REAL_RMUL = prove
 (`!(net:A net) f c l.
        limit euclideanreal f l net
        ==> limit euclideanreal (\x. f x * c) (l * c) net`,
  ONCE_REWRITE_TAC[REAL_MUL_SYM] THEN REWRITE_TAC[LIMIT_REAL_LMUL]);;

let LIMIT_REAL_RMUL_EQ = prove
 (`!(net:A net) f c l.
        limit euclideanreal (\x. f x * c) (l * c) net <=>
        c = &0 \/ limit euclideanreal f l net`,
  ONCE_REWRITE_TAC[REAL_MUL_SYM] THEN REWRITE_TAC[LIMIT_REAL_LMUL_EQ]);;

let LIMIT_REAL_NEG = prove
 (`!(net:A net) f l.
        limit euclideanreal f l net
        ==> limit euclideanreal (\x. --(f x)) (--l) net`,
  ONCE_REWRITE_TAC[REAL_ARITH `--x:real = --(&1) * x`] THEN
  REWRITE_TAC[LIMIT_REAL_LMUL]);;

let LIMIT_REAL_NEG_EQ = prove
 (`!(net:A net) f l.
        limit euclideanreal (\x. --(f x)) l net <=>
        limit euclideanreal f (--l) net`,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  DISCH_THEN(MP_TAC o MATCH_MP LIMIT_REAL_NEG) THEN
  REWRITE_TAC[REAL_NEG_NEG; ETA_AX]);;

let LIMIT_REAL_ADD = prove
 (`!(net:A net) f g l m.
        limit euclideanreal f l net /\ limit euclideanreal g m net
        ==> limit euclideanreal (\x. f x + g x) (l + m) net`,
  REPEAT GEN_TAC THEN REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[LIMIT_METRIC; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  DISCH_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(CONJUNCTS_THEN (MP_TAC o SPEC `e / &2`)) THEN
  ASM_REWRITE_TAC[REAL_HALF; IMP_IMP; GSYM EVENTUALLY_AND] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  REWRITE_TAC[] THEN REAL_ARITH_TAC);;

let LIMIT_REAL_SUB = prove
 (`!(net:A net) f g l m.
        limit euclideanreal f l net /\ limit euclideanreal g m net
        ==> limit euclideanreal (\x. f x - g x) (l - m) net`,
  SIMP_TAC[real_sub; LIMIT_REAL_ADD; LIMIT_REAL_NEG]);;

let LIMIT_REAL_ABS = prove
 (`!(net:A net) f l.
        limit euclideanreal f l net
        ==> limit euclideanreal (\x. abs(f x)) (abs l) net`,
  REPEAT  GEN_TAC THEN REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[LIMIT_METRIC; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  MATCH_MP_TAC MONO_FORALL THEN GEN_TAC THEN MATCH_MP_TAC MONO_IMP THEN
  REWRITE_TAC[] THEN  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  REWRITE_TAC[] THEN REAL_ARITH_TAC);;

let LIMIT_REAL_MAX = prove
 (`!(net:A net) f g l m.
        limit euclideanreal f l net /\ limit euclideanreal g m net
        ==> limit euclideanreal (\x. max (f x) (g x)) (max l m) net`,
  REWRITE_TAC[REAL_ARITH `max a b = inv(&2) * (abs(a - b) + a + b)`] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC LIMIT_REAL_LMUL THEN
  REPEAT(MATCH_MP_TAC LIMIT_REAL_ADD THEN CONJ_TAC) THEN
  ASM_SIMP_TAC[LIMIT_REAL_SUB; LIMIT_REAL_ABS]);;

let LIMIT_REAL_MIN = prove
 (`!(net:A net) f g l m.
        limit euclideanreal f l net /\ limit euclideanreal g m net
        ==> limit euclideanreal (\x. min (f x) (g x)) (min l m) net`,
  REWRITE_TAC[REAL_ARITH `min a b = inv(&2) * ((a + b) - abs(a - b))`] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC LIMIT_REAL_LMUL THEN
  ASM_SIMP_TAC[LIMIT_REAL_ADD; LIMIT_REAL_SUB; LIMIT_REAL_ABS]);;

let LIMIT_SUM = prove
 (`!net f:A->K->real l k.
        FINITE k /\
        (!i. i IN k ==> limit euclideanreal (\x. f x i) (l i) net)
        ==> limit euclideanreal (\x. sum k (f x)) (sum k l) net`,
  REPLICATE_TAC 3 GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[SUM_CLAUSES; LIMIT_REAL_CONST; FORALL_IN_INSERT] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC LIMIT_REAL_ADD THEN
  ASM_SIMP_TAC[ETA_AX]);;

let LIMIT_PRODUCT = prove
 (`!net f:A->K->real l k.
        FINITE k /\
        (!i. i IN k ==> limit euclideanreal (\x. f x i) (l i) net)
        ==> limit euclideanreal (\x. product k (f x)) (product k l) net`,
  REPLICATE_TAC 3 GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[PRODUCT_CLAUSES; LIMIT_REAL_CONST; FORALL_IN_INSERT] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC LIMIT_REAL_MUL THEN
  ASM_SIMP_TAC[ETA_AX]);;

let LIMIT_REAL_INV = prove
 (`!(net:A net) f l.
        limit euclideanreal f l net /\ ~(l = &0)
        ==> limit euclideanreal (\x. inv(f x)) (inv l) net`,
  REPEAT GEN_TAC THEN REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[LIMIT_METRIC; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  STRIP_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `min (abs l / &2) ((l pow 2 * e) / &2)`) THEN
  ASM_SIMP_TAC[REAL_LT_MIN; REAL_HALF; GSYM REAL_ABS_NZ; REAL_LT_MUL;
               REAL_LT_POW_2] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN GEN_TAC THEN
  SIMP_TAC[REAL_LT_RDIV_EQ; REAL_OF_NUM_LT; ARITH] THEN STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP (REAL_ARITH
   `abs(l - x) * &2 < abs l ==> ~(x = &0)`)) THEN
  ASM_SIMP_TAC[REAL_SUB_INV; REAL_ABS_DIV; REAL_LT_LDIV_EQ;
               GSYM REAL_ABS_NZ; REAL_ENTIRE] THEN
  FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP (REAL_ARITH
   `abs(x - y) * &2 < b * c ==> c * b <= d * &2 ==> abs(y - x) < d`)) THEN
  ASM_SIMP_TAC[GSYM REAL_MUL_ASSOC; REAL_LE_LMUL_EQ] THEN
  ONCE_REWRITE_TAC[GSYM REAL_POW2_ABS] THEN
  REWRITE_TAC[GSYM REAL_MUL_ASSOC; REAL_POW_2; REAL_ABS_MUL] THEN
  MATCH_MP_TAC REAL_LE_LMUL THEN ASM_REAL_ARITH_TAC);;

let LIMIT_REAL_DIV = prove
 (`!(net:A net) f g l m.
      limit euclideanreal f l net /\ limit euclideanreal g m net /\ ~(m = &0)
      ==> limit euclideanreal (\x. f x / g x) (l / m) net`,
  SIMP_TAC[real_div; LIMIT_REAL_INV; LIMIT_REAL_MUL]);;

let LIMIT_INF = prove
 (`!net f:A->K->real l k.
        FINITE k /\
        (!i. i IN k ==> limit euclideanreal (\x. f x i) (l i) net)
        ==> limit euclideanreal
              (\x. inf {f x i | i IN k}) (inf {l i | i IN k}) net`,
  REPLICATE_TAC 3 GEN_TAC THEN REWRITE_TAC[SIMPLE_IMAGE; IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[IMAGE_CLAUSES; LIMIT_REAL_CONST] THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[FORALL_IN_INSERT] THEN
  DISCH_THEN(fun th -> REPEAT STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
  ASM_SIMP_TAC[INF_INSERT_FINITE; FINITE_IMAGE; IMAGE_EQ_EMPTY] THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC LIMIT_REAL_MIN THEN ASM_REWRITE_TAC[]);;

let LIMIT_SUP = prove
 (`!net f:A->K->real l k.
        FINITE k /\
        (!i. i IN k ==> limit euclideanreal (\x. f x i) (l i) net)
        ==> limit euclideanreal
              (\x. sup {f x i | i IN k}) (sup {l i | i IN k}) net`,
  REPLICATE_TAC 3 GEN_TAC THEN REWRITE_TAC[SIMPLE_IMAGE; IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  REWRITE_TAC[IMAGE_CLAUSES; LIMIT_REAL_CONST] THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[FORALL_IN_INSERT] THEN
  DISCH_THEN(fun th -> REPEAT STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
  ASM_SIMP_TAC[SUP_INSERT_FINITE; FINITE_IMAGE; IMAGE_EQ_EMPTY] THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC LIMIT_REAL_MAX THEN ASM_REWRITE_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Cauchy sequences and complete metric spaces.                              *)
(* ------------------------------------------------------------------------- *)

let cauchy_in = new_definition
  `!m:A metric s:num->A.
     cauchy_in m s <=>
     (!n. s n IN mspace m) /\
     (!e. &0 < e
          ==> (?N. !n n'. N <= n /\ N <= n'
                          ==> mdist m (s n,s n') < e))`;;

let mcomplete = new_definition
  `!m:A metric.
     mcomplete m <=>
     (!s. cauchy_in m s ==> ?x. limit (mtopology m) s x sequentially)`;;

let MCOMPLETE = prove
 (`!m:A metric.
        mcomplete m <=>
        !s. eventually (\n. s n IN mspace m) sequentially /\
            (!e. &0 < e
                 ==> ?N. !n n'. N <= n /\ N <= n' ==> mdist m (s n,s n') < e)
            ==> ?x. limit (mtopology m) s x sequentially`,
  GEN_TAC THEN REWRITE_TAC[mcomplete; cauchy_in] THEN EQ_TAC THEN
  DISCH_TAC THEN X_GEN_TAC `s:num->A` THEN STRIP_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [EVENTUALLY_SEQUENTIALLY]) THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `N:num` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `(s:num->A) o (\n. N + n)`) THEN
    ASM_SIMP_TAC[o_DEF; LE_ADD] THEN ANTS_TAC THENL
     [ASM_MESON_TAC[ARITH_RULE `M:num <= n ==> M <= N + n`];
      MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC THEN ONCE_REWRITE_TAC[ADD_SYM] THEN
      REWRITE_TAC[LIMIT_SEQUENTIALLY_OFFSET_REV]];
    FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC[EVENTUALLY_TRUE]]);;

let MCOMPLETE_EMPTY_MSPACE = prove
 (`!m:A metric. mspace m = {} ==> mcomplete m`,
  SIMP_TAC[mcomplete; cauchy_in; NOT_IN_EMPTY]);;

let MCOMPLETE_SUBMETRIC_EMPTY = prove
 (`!m:A metric. mcomplete(submetric m {})`,
  SIMP_TAC[MCOMPLETE_EMPTY_MSPACE; SUBMETRIC; INTER_EMPTY]);;

let CAUCHY_IN_SUBMETRIC = prove
 (`!m s x:num->A.
    cauchy_in (submetric m s) x <=> (!n. x n IN s) /\ cauchy_in m x`,
  REWRITE_TAC[cauchy_in; SUBMETRIC; IN_INTER] THEN MESON_TAC[]);;

let CAUCHY_IN_CONST = prove
 (`!m a:A. cauchy_in m (\n. a) <=> a IN mspace m`,
  REPEAT GEN_TAC THEN REWRITE_TAC[cauchy_in] THEN
  ASM_CASES_TAC `(a:A) IN mspace m` THEN ASM_SIMP_TAC[MDIST_REFL]);;

let CONVERGENT_IMP_CAUCHY_IN = prove
 (`!m x l:A. (!n. x n IN mspace m) /\ limit (mtopology m) x l sequentially
             ==> cauchy_in m x`,
  REPEAT GEN_TAC THEN SIMP_TAC[LIMIT_METRIC; cauchy_in] THEN
  STRIP_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN
  ASM_REWRITE_TAC[REAL_HALF; EVENTUALLY_SEQUENTIALLY] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `N:num` THEN DISCH_TAC THEN
  MAP_EVERY X_GEN_TAC [`n:num`; `p:num`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(fun th ->
    MP_TAC(SPEC `n:num` th) THEN MP_TAC(SPEC `p:num` th)) THEN
  ASM_REWRITE_TAC[] THEN UNDISCH_TAC `(l:A) IN mspace m` THEN
  SUBGOAL_THEN `(x:num->A) n IN mspace m /\ x p IN mspace m` MP_TAC THENL
   [ASM_REWRITE_TAC[]; CONV_TAC METRIC_ARITH]);;

let MCOMPLETE_ALT = prove
 (`!m:A metric.
        mcomplete m <=>
        !s. cauchy_in m s <=>
            (!n. s n IN mspace m) /\
            ?x. limit (mtopology m) s x sequentially`,
  MESON_TAC[CONVERGENT_IMP_CAUCHY_IN; mcomplete; cauchy_in]);;

let CAUCHY_IN_SUBSEQUENCE = prove
 (`!m (x:num->A) r.
        (!m n. m < n ==> r m < r n) /\ cauchy_in m x
        ==> cauchy_in m (x o r)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[cauchy_in; o_DEF] THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `N:num` THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN
  ASM_MESON_TAC[MONOTONE_BIGGER; LE_TRANS]);;

let CAUCHY_IN_OFFSET = prove
 (`!m a x:num->A.
        (!n. n < a ==> x n IN mspace m) /\ cauchy_in m (\n. x(a + n))
        ==> cauchy_in m x`,
  REPEAT GEN_TAC THEN REWRITE_TAC[cauchy_in] THEN STRIP_TAC THEN
  CONJ_TAC THENL
   [ASM_MESON_TAC[ARITH_RULE `n:num < a \/ n = a + (n - a)`]; ALL_TAC] THEN
  X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
  DISCH_THEN(X_CHOOSE_THEN `N:num` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `a + N:num` THEN
  MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`m - a:num`; `n - a:num`]) THEN
  ANTS_TAC THENL [ASM_ARITH_TAC; MATCH_MP_TAC EQ_IMP] THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN AP_TERM_TAC THEN
  BINOP_TAC THEN AP_TERM_TAC THEN ASM_ARITH_TAC);;

let CAUCHY_IN_CONVERGENT_SUBSEQUENCE = prove
 (`!m r a x:num->A.
        cauchy_in m x /\
        (!m n. m < n ==> r m < r n) /\
        limit (mtopology m) (x o r) a sequentially
        ==> limit (mtopology m) x a sequentially`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[LIMIT_METRIC] THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [LIMIT_METRIC]) THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN X_GEN_TAC `e:real` THEN
  DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [cauchy_in]) THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `e / &2`)) THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN
  ASM_REWRITE_TAC[REAL_HALF; LEFT_IMP_EXISTS_THM; EVENTUALLY_SEQUENTIALLY] THEN
  X_GEN_TAC `M:num` THEN ASM_REWRITE_TAC[o_THM] THEN DISCH_TAC THEN
  X_GEN_TAC `N:num` THEN DISCH_TAC THEN
  EXISTS_TAC `MAX ((r:num->num) M) N` THEN X_GEN_TAC `n:num` THEN
  REWRITE_TAC[ARITH_RULE `MAX M N <= n <=> M <= n /\ N <= n`] THEN
  STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`n:num`; `(r:num->num) n`]) THEN ANTS_TAC THENL
   [ASM_MESON_TAC[LE_TRANS; MONOTONE_BIGGER; LE_REFL]; ALL_TAC] THEN
  MATCH_MP_TAC(METRIC_ARITH
   `x IN mspace m /\ y IN mspace m /\ z IN mspace m /\
    mdist m (y:A,z) < e / &2
    ==> mdist m (x,y) < e / &2 ==> mdist m (x,z) < e`) THEN
  ASM_REWRITE_TAC[] THEN ASM_MESON_TAC[LE_TRANS; MONOTONE_BIGGER]);;

let CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE = prove
 (`!m s:A->bool. closed_in (mtopology m) s /\ mcomplete m
                 ==> mcomplete (submetric m s)`,
  INTRO_TAC "!m s; cl cp" THEN REWRITE_TAC[mcomplete] THEN
  INTRO_TAC "![a]; a" THEN CLAIM_TAC "cy'" `cauchy_in m (a:num->A)` THENL
  [REMOVE_THEN "a" MP_TAC THEN SIMP_TAC[cauchy_in; SUBMETRIC; IN_INTER];
   HYP_TAC "cp" (GSYM o REWRITE_RULE[mcomplete]) THEN
   HYP REWRITE_TAC "cp" [LIMIT_SUBMETRIC_IFF] THEN
   REMOVE_THEN "cp" (HYP_TAC "cy': @l.l" o MATCH_MP) THEN EXISTS_TAC `l:A` THEN
   HYP_TAC "a: A cy" (REWRITE_RULE[cauchy_in; SUBMETRIC; IN_INTER]) THEN
   ASM_REWRITE_TAC[EVENTUALLY_TRUE] THEN MATCH_MP_TAC
     (ISPECL [`sequentially`; `mtopology(m:A metric)`] LIMIT_IN_CLOSED_IN) THEN
   EXISTS_TAC `a:num->A` THEN
   ASM_REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY; EVENTUALLY_TRUE]]);;

let SEQUENTIALLY_CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE = prove
 (`!m s:A->bool.
     mcomplete m /\
     (!x l. (!n. x n IN s) /\ limit (mtopology m) x l sequentially ==> l IN s)
            ==> mcomplete (submetric m s)`,
  INTRO_TAC "!m s; cpl seq" THEN SUBGOAL_THEN
    `submetric m (s:A->bool) = submetric m (mspace m INTER s)` SUBST1_TAC THENL
  [REWRITE_TAC[submetric; INTER_ACI]; ALL_TAC] THEN
  MATCH_MP_TAC CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE THEN
  ASM_REWRITE_TAC[METRIC_CLOSED_IN_IFF_SEQUENTIALLY_CLOSED; INTER_SUBSET] THEN
  INTRO_TAC "!a l; a lim" THEN REWRITE_TAC[IN_INTER] THEN CONJ_TAC THENL
  [MATCH_MP_TAC (ISPEC `sequentially` LIMIT_IN_MSPACE) THEN
   HYP MESON_TAC "lim" [];
   REMOVE_THEN "seq" MATCH_MP_TAC THEN HYP SET_TAC "a lim" []]);;

let CAUCHY_IN_INTERLEAVING_GEN = prove
 (`!m x y:num->A.
        cauchy_in m (\n. if EVEN n then x(n DIV 2) else y(n DIV 2)) <=>
        cauchy_in m x /\ cauchy_in m y /\
        limit euclideanreal (\n. mdist m (x n,y n)) (&0) sequentially`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [DISCH_TAC THEN REPEAT CONJ_TAC THENL
     [FIRST_ASSUM(MP_TAC o SPEC `\n. 2 * n` o MATCH_MP
       (REWRITE_RULE[IMP_CONJ_ALT] CAUCHY_IN_SUBSEQUENCE)) THEN
      REWRITE_TAC[o_DEF; ARITH_RULE `(2 * m) DIV 2 = m`] THEN
      REWRITE_TAC[EVEN_MULT; ARITH; ETA_AX] THEN
      DISCH_THEN MATCH_MP_TAC THEN ARITH_TAC;
      FIRST_ASSUM(MP_TAC o SPEC `\n. 2 * n + 1` o MATCH_MP
       (REWRITE_RULE[IMP_CONJ_ALT] CAUCHY_IN_SUBSEQUENCE)) THEN
      REWRITE_TAC[o_DEF; ARITH_RULE `(2 * m + 1) DIV 2 = m`] THEN
      REWRITE_TAC[EVEN_MULT; EVEN_ADD; ARITH; ETA_AX] THEN
      DISCH_THEN MATCH_MP_TAC THEN ARITH_TAC;
      REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
      REWRITE_TAC[LIMIT_METRIC; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
      X_GEN_TAC `e:real` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [cauchy_in]) THEN
      DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `e:real`)) THEN
      ASM_REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `N:num` THEN
      STRIP_TAC THEN X_GEN_TAC `n:num` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPECL [`2 * n`; `2 * n + 1`]) THEN
      ANTS_TAC THENL [ASM_ARITH_TAC; ALL_TAC] THEN FIRST_X_ASSUM(MP_TAC o
       MATCH_MP(MESON[]
         `(!n. P n) ==> (!n. P(2 * n)) /\ (!n. P(2 * n + 1))`)) THEN
      REWRITE_TAC[EVEN_ADD; EVEN_MULT; ARITH] THEN
      REWRITE_TAC[ARITH_RULE `(2 * m) DIV 2 = m /\ (2 * m + 1) DIV 2 = m`] THEN
      SIMP_TAC[REAL_ARITH `&0 <= x ==> abs(&0 - x) = x`; MDIST_POS_LE]];
    REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
    REWRITE_TAC[LIMIT_METRIC; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
    REWRITE_TAC[cauchy_in] THEN
    ASM_CASES_TAC `!n. (x:num->A) n IN mspace m` THEN ASM_REWRITE_TAC[] THEN
    ASM_CASES_TAC `!n. (y:num->A) n IN mspace m` THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[AND_FORALL_THM] THEN DISCH_TAC THEN
    CONJ_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN
    ASM_REWRITE_TAC[REAL_HALF; EVENTUALLY_SEQUENTIALLY] THEN
    ASM_SIMP_TAC[REAL_ARITH `&0 <= x ==> abs(&0 - x) = x`; MDIST_POS_LE] THEN
    DISCH_THEN(CONJUNCTS_THEN2 (X_CHOOSE_TAC `N1:num`)
     (CONJUNCTS_THEN2 (X_CHOOSE_TAC `N2:num`) (X_CHOOSE_TAC `N3:num`))) THEN
    EXISTS_TAC `2 * MAX N1 (MAX N2 N3)` THEN REWRITE_TAC[ARITH_RULE
     `2 * MAX M N <= n <=> 2 * M <= n /\ 2 * N <= n`] THEN
    MATCH_MP_TAC(MESON[EVEN_OR_ODD]
     `(!m n. P m n ==> P n m) /\
      (!m n. EVEN m /\ EVEN n ==> P m n) /\
      (!m n. ODD m /\ ODD n ==> P m n) /\
      (!m n. EVEN m /\ ODD n ==> P m n)
      ==> (!m n. P m n)`) THEN
    CONJ_TAC THENL [ASM_MESON_TAC[MDIST_SYM]; ALL_TAC] THEN
    REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
    REWRITE_TAC[MESON[EVEN_EXISTS; ODD_EXISTS; ADD1]
     `((!n. EVEN n ==> P n) <=> (!n. P(2 * n))) /\
      ((!n. ODD n ==> P n) <=> (!n. P(2 * n + 1)))`] THEN
    REWRITE_TAC[EVEN_MULT; EVEN_ADD; ARITH] THEN
    REWRITE_TAC[ARITH_RULE `(2 * m) DIV 2 = m /\ (2 * m + 1) DIV 2 = m`] THEN
    REPEAT CONJ_TAC THEN MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN
    REPEAT DISCH_TAC THENL
     [MATCH_MP_TAC(REAL_ARITH `&0 < e /\ x < e / &2 ==> x < e`) THEN
      ASM_REWRITE_TAC[] THEN FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_ARITH_TAC;
      MATCH_MP_TAC(REAL_ARITH `&0 < e /\ x < e / &2 ==> x < e`) THEN
      ASM_REWRITE_TAC[] THEN FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_ARITH_TAC;
      MATCH_MP_TAC(METRIC_ARITH
       `!b. a IN mspace m /\ b IN mspace m /\ c IN mspace m /\
            mdist m (a,b) < e / &2 /\ mdist m (b,c) < e / &2
            ==> mdist m (a:A,c) < e`) THEN
      EXISTS_TAC `(x:num->A) n` THEN
      ASM_REWRITE_TAC[] THEN CONJ_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
      ASM_ARITH_TAC]]);;

let CAUCHY_IN_INTERLEAVING = prove
 (`!m x a:A.
         cauchy_in m (\n. if EVEN n then x(n DIV 2) else a) <=>
         (!n. x n IN mspace m) /\ limit (mtopology m) x a sequentially`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CAUCHY_IN_INTERLEAVING_GEN] THEN
  REWRITE_TAC[CAUCHY_IN_CONST] THEN
  GEN_REWRITE_TAC (RAND_CONV o RAND_CONV) [LIMIT_METRIC_DIST_NULL] THEN
  EQ_TAC THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[cauchy_in]) THEN
    ASM_REWRITE_TAC[EVENTUALLY_TRUE];
    MATCH_MP_TAC CONVERGENT_IMP_CAUCHY_IN THEN
    ONCE_REWRITE_TAC[LIMIT_METRIC_DIST_NULL] THEN
    EXISTS_TAC `a:A` THEN ASM_REWRITE_TAC[]]);;

let MCOMPLETE_NEST = prove
 (`!m:A metric.
      mcomplete m <=>
      !c. (!n. closed_in (mtopology m) (c n)) /\
          (!n. ~(c n = {})) /\
          (!m n. m <= n ==> c n SUBSET c m) /\
          (!e. &0 < e ==> ?n a. c n SUBSET mcball m (a,e))
          ==> ~(INTERS {c n | n IN (:num)} = {})`,
  GEN_TAC THEN REWRITE_TAC[mcomplete] THEN EQ_TAC THEN DISCH_TAC THENL
   [X_GEN_TAC `c:num->A->bool` THEN STRIP_TAC THEN
    SUBGOAL_THEN `!n. ?x. x IN (c:num->A->bool) n` MP_TAC THENL
     [ASM SET_TAC[]; REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
    X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN ANTS_TAC THENL
     [REWRITE_TAC[cauchy_in] THEN CONJ_TAC THENL
       [ASM_MESON_TAC[closed_in; SUBSET; TOPSPACE_MTOPOLOGY]; ALL_TAC] THEN
      X_GEN_TAC `e:real` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `e / &3`) THEN
      ASM_REWRITE_TAC[REAL_ARITH `&0 < e / &3 <=> &0 < e`] THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `N:num` THEN
      REWRITE_TAC[SUBSET; IN_MCBALL] THEN DISCH_THEN(X_CHOOSE_TAC `a:A`) THEN
      MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN STRIP_TAC THEN
      FIRST_X_ASSUM(fun th ->
       MP_TAC(SPEC `(x:num->A) m` th) THEN MP_TAC(SPEC `(x:num->A) n` th)) THEN
      REPEAT(ANTS_TAC THENL [ASM SET_TAC[]; DISCH_TAC]) THEN
      MATCH_MP_TAC(METRIC_ARITH
       `!a x y:A. a IN mspace m /\ x IN mspace m /\ y IN mspace m /\ &0 < e /\
                  mdist m (a,x) <= e / &3 /\ mdist m (a,y) <= e / &3
                  ==> mdist m (x,y) < e`) THEN
      EXISTS_TAC `a:A` THEN ASM_REWRITE_TAC[];
      REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; INTERS_GSPEC; IN_ELIM_THM] THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `l:A` THEN REPEAT STRIP_TAC THEN
      MATCH_MP_TAC(ISPEC `sequentially` LIMIT_IN_CLOSED_IN) THEN
      MAP_EVERY EXISTS_TAC [`mtopology m:A topology`; `x:num->A`] THEN
      ASM_REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY] THEN
      REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN EXISTS_TAC `n:num` THEN
      ASM SET_TAC[]];
    X_GEN_TAC `x:num->A` THEN REWRITE_TAC[cauchy_in] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC
     `\n. mtopology m closure_of (IMAGE (x:num->A) (from n))`) THEN
    REWRITE_TAC[CLOSED_IN_CLOSURE_OF] THEN
    SIMP_TAC[CLOSURE_OF_MONO; FROM_MONO; IMAGE_SUBSET] THEN
    REWRITE_TAC[CLOSURE_OF_EQ_EMPTY_GEN; TOPSPACE_MTOPOLOGY] THEN
    ASM_SIMP_TAC[FROM_NONEMPTY; SET_RULE
     `(!n. x n IN s) /\ ~(k = {}) ==> ~DISJOINT s (IMAGE x k)`] THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; INTERS_GSPEC; IN_ELIM_THM] THEN
    ANTS_TAC THENL
     [X_GEN_TAC `e:real` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `N:num` THEN DISCH_TAC THEN
      EXISTS_TAC `(x:num->A) N` THEN MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN
      REWRITE_TAC[CLOSED_IN_MCBALL; SUBSET; FORALL_IN_IMAGE] THEN
      ASM_SIMP_TAC[IN_FROM; LE_REFL; IN_MCBALL; REAL_LT_IMP_LE];
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `l:A` THEN
      REWRITE_TAC[IN_UNIV; METRIC_CLOSURE_OF; IN_ELIM_THM; FORALL_AND_THM] THEN
      REWRITE_TAC[EXISTS_IN_IMAGE; IN_FROM; IN_MBALL] THEN STRIP_TAC THEN
      ASM_REWRITE_TAC[LIMIT_METRIC] THEN
      X_GEN_TAC `e:real` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN
      ASM_REWRITE_TAC[REAL_HALF; EVENTUALLY_SEQUENTIALLY] THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `N:num` THEN STRIP_TAC THEN
      X_GEN_TAC `n:num` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPECL [`N:num`; `e / &2`]) THEN
      ASM_REWRITE_TAC[REAL_HALF] THEN
      DISCH_THEN(X_CHOOSE_THEN `p:num` STRIP_ASSUME_TAC) THEN
      FIRST_X_ASSUM(MP_TAC o SPECL [`n:num`; `p:num`]) THEN
      ASM_REWRITE_TAC[] THEN MATCH_MP_TAC(METRIC_ARITH
       `x IN mspace m /\ y IN mspace m /\ l IN mspace m /\
        mdist m(l,y) < e / &2
        ==> mdist m (x,y) < e / &2 ==> mdist m (x,l) < e`) THEN
      ASM_REWRITE_TAC[]]]);;

let MCOMPLETE_NEST_SING = prove
 (`!m:A metric.
      mcomplete m <=>
      !c. (!n. closed_in (mtopology m) (c n)) /\
          (!n. ~(c n = {})) /\
          (!m n. m <= n ==> c n SUBSET c m) /\
          (!e. &0 < e ==> ?n a. c n SUBSET mcball m (a,e))
          ==> ?l. l IN mspace m /\ INTERS {c n | n IN (:num)} = {l}`,
  GEN_TAC THEN REWRITE_TAC[MCOMPLETE_NEST] THEN
  EQ_TAC THEN MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `c:num->A->bool` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `l:A` THEN STRIP_TAC THEN ASM_REWRITE_TAC[IN_SING] THEN
  SUBGOAL_THEN `!a:A. a IN INTERS {c n | n IN (:num)} ==> a IN mspace m`
  ASSUME_TAC THENL
   [REWRITE_TAC[INTERS_GSPEC; IN_ELIM_THM; IN_UNIV] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[closed_in; TOPSPACE_MTOPOLOGY]) THEN
    ASM SET_TAC[];
    ASM_SIMP_TAC[]] THEN
  MATCH_MP_TAC(SET_RULE
   `l IN s /\ (!l'. ~(l' = l) ==> ~(l' IN s)) ==> s = {l}`) THEN
  ASM_REWRITE_TAC[] THEN X_GEN_TAC `l':A` THEN REPEAT DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `mdist m (l:A,l') / &3`) THEN ANTS_TAC THENL
   [ASM_MESON_TAC[MDIST_POS_EQ; REAL_ARITH `&0 < e / &3 <=> &0 < e`];
    REWRITE_TAC[NOT_EXISTS_THM]] THEN
  MAP_EVERY X_GEN_TAC [`n:num`; `a:A`] THEN REWRITE_TAC[SUBSET; IN_MCBALL] THEN
  DISCH_THEN(fun th -> MP_TAC(SPEC `l':A` th) THEN MP_TAC(SPEC `l:A` th)) THEN
  MATCH_MP_TAC(TAUT
   `(p /\ p') /\ ~(q /\ q') ==> (p ==> q) ==> (p' ==> q') ==> F`) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  UNDISCH_TAC `~(l':A = l)` THEN CONV_TAC METRIC_ARITH);;

let MCOMPLETE_FIP = prove
 (`!m:A metric.
        mcomplete m <=>
        !f. (!c. c IN f ==> closed_in (mtopology m) c) /\
            (!e. &0 < e ==> ?c a. c IN f /\ c SUBSET mcball m (a,e)) /\
            (!f'. FINITE f' /\ f' SUBSET f ==> ~(INTERS f' = {}))
            ==> ~(INTERS f = {})`,
  GEN_TAC THEN EQ_TAC THENL
   [REWRITE_TAC[MCOMPLETE_NEST_SING];
    REWRITE_TAC[MCOMPLETE_NEST] THEN
    DISCH_TAC THEN X_GEN_TAC `c:num->A->bool` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (c:num->A->bool) (:num)`) THEN
    ASM_REWRITE_TAC[FORALL_IN_IMAGE; RIGHT_EXISTS_AND_THM] THEN
    ASM_REWRITE_TAC[EXISTS_IN_IMAGE; FORALL_FINITE_SUBSET_IMAGE; IN_UNIV] THEN
    REWRITE_TAC[GSYM SIMPLE_IMAGE; IN_UNIV; SUBSET_UNIV] THEN
    DISCH_THEN MATCH_MP_TAC THEN X_GEN_TAC `k:num->bool` THEN
    DISCH_THEN(MP_TAC o ISPEC `\n:num. n` o
      MATCH_MP UPPER_BOUND_FINITE_SET) THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `n:num` THEN
    DISCH_TAC THEN MATCH_MP_TAC(SET_RULE
     `!t. ~(t = {}) /\ t SUBSET s ==> ~(s = {})`) THEN
    EXISTS_TAC `(c:num->A->bool) n` THEN
    ASM_SIMP_TAC[SUBSET_INTERS; FORALL_IN_GSPEC]] THEN
  DISCH_TAC THEN X_GEN_TAC `f:(A->bool)->bool` THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN `n:num` o SPEC `inv(&n + &1)`) THEN
  REWRITE_TAC[REAL_LT_INV_EQ; RIGHT_EXISTS_AND_THM] THEN
  REWRITE_TAC[REAL_ARITH `&0 < &n + &1`; SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `c:num->A->bool` THEN REWRITE_TAC[FORALL_AND_THM] THEN
  STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `\n. INTERS {(c:num->A->bool) m | m <= n}`) THEN
  REWRITE_TAC[] THEN ANTS_TAC THENL
   [REPEAT CONJ_TAC THENL
     [GEN_TAC THEN MATCH_MP_TAC CLOSED_IN_INTERS THEN
      ASM_SIMP_TAC[FORALL_IN_GSPEC; GSYM MEMBER_NOT_EMPTY] THEN
      EXISTS_TAC `(c:num->A->bool) n` THEN
      MATCH_MP_TAC(SET_RULE `P n n ==> c n IN {c m | P m n}`) THEN
      REWRITE_TAC[LE_REFL];
      GEN_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
      ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN
      ASM_SIMP_TAC[FINITE_IMAGE; FINITE_NUMSEG_LE; SUBSET] THEN
      ASM_REWRITE_TAC[FORALL_IN_IMAGE];
      REPEAT STRIP_TAC THEN MATCH_MP_TAC INTERS_ANTIMONO THEN
      ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN MATCH_MP_TAC IMAGE_SUBSET THEN
      REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN ASM_ARITH_TAC;
      MATCH_MP_TAC FORALL_POS_MONO_1 THEN CONJ_TAC THENL
       [MESON_TAC[MCBALL_SUBSET_CONCENTRIC; SUBSET_TRANS; REAL_LT_IMP_LE];
        X_GEN_TAC `n:num` THEN EXISTS_TAC `n:num` THEN
        FIRST_X_ASSUM(X_CHOOSE_TAC `a:A` o SPEC `n:num`) THEN
        EXISTS_TAC `a:A` THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
         (REWRITE_RULE[IMP_CONJ_ALT] SUBSET_TRANS)) THEN
        MATCH_MP_TAC(SET_RULE
         `P n n ==> INTERS {c m | P m n} SUBSET c n`) THEN
        REWRITE_TAC[LE_REFL]]];
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; INTERS_GSPEC; IN_ELIM_THM; IN_UNIV] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `a:A` THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    REWRITE_TAC[MESON[LE_REFL]
     `(!n m:num. m <= n ==> P m) <=> (!n. P n)`] THEN
    REWRITE_TAC[SET_RULE `{x | P x} = {a} <=> P a /\ (!b. P b ==> a = b)`] THEN
    STRIP_TAC THEN REWRITE_TAC[IN_INTERS] THEN
    X_GEN_TAC `t:A->bool` THEN DISCH_TAC] THEN
  FIRST_X_ASSUM(MP_TAC o SPEC
   `\n. t INTER INTERS {(c:num->A->bool) m | m <= n}`) THEN
  REWRITE_TAC[GSYM INTERS_INSERT] THEN ANTS_TAC THENL
   [REPEAT CONJ_TAC THENL
     [GEN_TAC THEN MATCH_MP_TAC CLOSED_IN_INTERS THEN
      REWRITE_TAC[FORALL_IN_INSERT; NOT_INSERT_EMPTY] THEN
      ASM_SIMP_TAC[FORALL_IN_GSPEC; GSYM MEMBER_NOT_EMPTY];
      GEN_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
      ASM_REWRITE_TAC[FINITE_INSERT; INSERT_SUBSET] THEN
      ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN
      ASM_SIMP_TAC[FINITE_IMAGE; FINITE_NUMSEG_LE; SUBSET] THEN
      ASM_REWRITE_TAC[FORALL_IN_IMAGE];
      REPEAT STRIP_TAC THEN MATCH_MP_TAC INTERS_ANTIMONO THEN
      MATCH_MP_TAC(SET_RULE `s SUBSET t ==> x INSERT s SUBSET x INSERT t`) THEN
      ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN MATCH_MP_TAC IMAGE_SUBSET THEN
      REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN ASM_ARITH_TAC;
      MATCH_MP_TAC FORALL_POS_MONO_1 THEN CONJ_TAC THENL
       [MESON_TAC[MCBALL_SUBSET_CONCENTRIC; SUBSET_TRANS; REAL_LT_IMP_LE];
        X_GEN_TAC `n:num` THEN EXISTS_TAC `n:num` THEN
        FIRST_X_ASSUM(X_CHOOSE_TAC `x:A` o SPEC `n:num`) THEN
        EXISTS_TAC `x:A` THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
         (REWRITE_RULE[IMP_CONJ_ALT] SUBSET_TRANS)) THEN
        MATCH_MP_TAC(SET_RULE
         `P n n ==> INTERS(t INSERT {c m | P m n}) SUBSET c n`) THEN
        REWRITE_TAC[LE_REFL]]];
    REWRITE_TAC[INTERS_INSERT] THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; INTERS_GSPEC; IN_ELIM_THM] THEN
    REWRITE_TAC[IN_UNIV; IN_INTER; FORALL_AND_THM; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `b:A` THEN REWRITE_TAC[IN_ELIM_THM] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    REWRITE_TAC[MESON[LE_REFL]
     `(!n m:num. m <= n ==> P m) <=> (!n. P n)`] THEN
    ASM SET_TAC[]]);;

let MCOMPLETE_FIP_SING = prove
 (`!m:A metric.
        mcomplete m <=>
        !f. (!c. c IN f ==> closed_in (mtopology m) c) /\
            (!e. &0 < e ==> ?c a. c IN f /\ c SUBSET mcball m (a,e)) /\
            (!f'. FINITE f' /\ f' SUBSET f ==> ~(INTERS f' = {}))
            ==> ?l. l IN mspace m /\ INTERS f = {l}`,
  GEN_TAC THEN REWRITE_TAC[MCOMPLETE_FIP] THEN
  EQ_TAC THEN MATCH_MP_TAC MONO_FORALL THEN
  X_GEN_TAC `f:(A->bool)->bool` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `l:A` THEN STRIP_TAC THEN ASM_REWRITE_TAC[IN_SING] THEN
  ASM_CASES_TAC `f:(A->bool)->bool = {}` THENL
   [ASM_MESON_TAC[MEMBER_NOT_EMPTY; REAL_LT_01]; ALL_TAC] THEN
  SUBGOAL_THEN `!a:A. a IN INTERS f ==> a IN mspace m`
  ASSUME_TAC THENL
   [REWRITE_TAC[INTERS_GSPEC; IN_ELIM_THM; IN_UNIV] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[closed_in; TOPSPACE_MTOPOLOGY]) THEN
    ASM SET_TAC[];
    ASM_SIMP_TAC[]] THEN
  MATCH_MP_TAC(SET_RULE
   `l IN s /\ (!l'. ~(l' = l) ==> ~(l' IN s)) ==> s = {l}`) THEN
  ASM_REWRITE_TAC[] THEN X_GEN_TAC `l':A` THEN REPEAT DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `mdist m (l:A,l') / &3`) THEN ANTS_TAC THENL
   [ASM_MESON_TAC[MDIST_POS_EQ; REAL_ARITH `&0 < e / &3 <=> &0 < e`];
    REWRITE_TAC[NOT_EXISTS_THM]] THEN
  MAP_EVERY X_GEN_TAC [`c:A->bool`; `a:A`] THEN
  REWRITE_TAC[SUBSET; IN_MCBALL] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  DISCH_THEN(fun th -> MP_TAC(SPEC `l':A` th) THEN MP_TAC(SPEC `l:A` th)) THEN
  MATCH_MP_TAC(TAUT
   `(p /\ p') /\ ~(q /\ q') ==> (p ==> q) ==> (p' ==> q') ==> F`) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  UNDISCH_TAC `~(l':A = l)` THEN CONV_TAC METRIC_ARITH);;

(* ------------------------------------------------------------------------- *)
(* Totally bounded subsets of metric spaces.                                 *)
(* ------------------------------------------------------------------------- *)

let totally_bounded_in = new_definition
 `totally_bounded_in m (s:A->bool) <=>
        !e. &0 < e
            ==> ?k. FINITE k /\ k SUBSET s /\
                    s SUBSET UNIONS { mball m (x,e) | x IN k}`;;

let TOTALLY_BOUNDED_IN_EMPTY = prove
 (`!m:A metric. totally_bounded_in m {}`,
  REWRITE_TAC[totally_bounded_in; EMPTY_SUBSET; SUBSET_EMPTY] THEN
  MESON_TAC[FINITE_EMPTY]);;

let FINITE_IMP_TOTALLY_BOUNDED_IN = prove
 (`!m s:A->bool. FINITE s /\ s SUBSET mspace m ==> totally_bounded_in m s`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[totally_bounded_in] THEN
  X_GEN_TAC `e:real` THEN DISCH_TAC THEN EXISTS_TAC `s:A->bool` THEN
  ASM_REWRITE_TAC[SUBSET_REFL] THEN MATCH_MP_TAC(SET_RULE
   `(!x. x IN s ==> x IN f x) ==> s SUBSET UNIONS {f x | x IN s}`) THEN
  ASM_REWRITE_TAC[CENTRE_IN_MBALL_EQ; GSYM SUBSET]);;

let TOTALLY_BOUNDED_IN_IMP_SUBSET = prove
 (`!m s:A->bool. totally_bounded_in m s ==> s SUBSET mspace m`,
  REPEAT GEN_TAC THEN REWRITE_TAC[totally_bounded_in] THEN
  DISCH_THEN(MP_TAC o SPEC `&1`) THEN REWRITE_TAC[REAL_LT_01] THEN
  STRIP_TAC THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
   (REWRITE_RULE[IMP_CONJ] SUBSET_TRANS)) THEN
  REWRITE_TAC[UNIONS_SUBSET; FORALL_IN_GSPEC; MBALL_SUBSET_MSPACE]);;

let TOTALLY_BOUNDED_IN_SING = prove
 (`!m x:A. totally_bounded_in m {x} <=> x IN mspace m`,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC[FINITE_IMP_TOTALLY_BOUNDED_IN; FINITE_SING; SING_SUBSET] THEN
  REWRITE_TAC[GSYM SING_SUBSET; TOTALLY_BOUNDED_IN_IMP_SUBSET]);;

let TOTALLY_BOUNDED_IN_SEQUENTIALLY = prove
 (`!m s:A->bool.
        totally_bounded_in m s <=>
        s SUBSET mspace m /\
        !x:num->A. (!n. x n IN s)
                   ==> ?r. (!m n. m < n ==> r m < r n) /\
                           cauchy_in m (x o r)`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET mspace m` THENL
   [ASM_REWRITE_TAC[]; ASM_MESON_TAC[TOTALLY_BOUNDED_IN_IMP_SUBSET]] THEN
  REWRITE_TAC[totally_bounded_in] THEN
  REPEAT(STRIP_TAC ORELSE EQ_TAC) THENL
   [ALL_TAC;
    ONCE_REWRITE_TAC[MESON[] `(?x. P x /\ Q x /\ R x) <=>
      ~(!x. P x /\ Q x ==> ~R x)`] THEN
    DISCH_TAC THEN
    SUBGOAL_THEN
      `?x. (!n. (x:num->A) n IN s) /\ (!n p. p < n ==> e <= mdist m (x p,x n))`
    STRIP_ASSUME_TAC THENL
     [REWRITE_TAC[AND_FORALL_THM] THEN
      MATCH_MP_TAC (MATCH_MP WF_REC_EXISTS WF_num) THEN SIMP_TAC[] THEN
      MAP_EVERY X_GEN_TAC [`x:num->A`; `n:num`] THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (x:num->A) {i | i < n}`) THEN
      ASM_SIMP_TAC[FINITE_IMAGE; FINITE_NUMSEG_LT] THEN
      ASM_SIMP_TAC[UNIONS_GSPEC; SUBSET; FORALL_IN_IMAGE; IN_ELIM_THM] THEN
      REWRITE_TAC[NOT_FORALL_THM; NOT_IMP; EXISTS_IN_IMAGE] THEN
      REWRITE_TAC[IN_ELIM_THM; IN_MBALL; GSYM REAL_NOT_LT] THEN ASM SET_TAC[];
      FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN ASM_REWRITE_TAC[] THEN
      DISCH_THEN(X_CHOOSE_THEN `r:num->num` STRIP_ASSUME_TAC) THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `e:real` o CONJUNCT2 o
        GEN_REWRITE_RULE I [cauchy_in]) THEN
      ASM_REWRITE_TAC[o_DEF] THEN
      DISCH_THEN(X_CHOOSE_THEN `N:num`
          (MP_TAC o SPECL [`N:num`; `(r:num->num) N + 1`])) THEN
      REWRITE_TAC[LE_REFL; NOT_IMP; REAL_NOT_LT] THEN CONJ_TAC THENL
       [MATCH_MP_TAC(ARITH_RULE `n <= m ==> n <= m + 1`) THEN
        ASM_MESON_TAC[MONOTONE_BIGGER];
        FIRST_X_ASSUM MATCH_MP_TAC THEN
        MATCH_MP_TAC(ARITH_RULE `n + 1 <= m ==> n < m`) THEN
        ASM_MESON_TAC[MONOTONE_BIGGER]]]] THEN
  MP_TAC(ISPEC
   `\(i:num) (r:num->num).
      ?N. !n n'. N <= n /\ N <= n'
                 ==> mdist m (x(r n):A,x(r n')) < inv(&i + &1)`
   SUBSEQUENCE_DIAGONALIZATION_LEMMA) THEN
  REWRITE_TAC[o_DEF] THEN ANTS_TAC THENL
   [ALL_TAC;
    DISCH_THEN(MP_TAC o SPEC `\n:num. n`) THEN
    ASM_REWRITE_TAC[cauchy_in] THEN MATCH_MP_TAC MONO_EXISTS THEN
    X_GEN_TAC `r:num->num` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
    MATCH_MP_TAC FORALL_POS_MONO_1 THEN ASM_REWRITE_TAC[] THEN
    MESON_TAC[REAL_LT_TRANS]] THEN
  CONJ_TAC THENL
   [ALL_TAC;
    MAP_EVERY X_GEN_TAC
     [`i:num`; `r:num->num`; `k1:num->num`; `k2:num->num`; `M:num`] THEN
    DISCH_THEN(CONJUNCTS_THEN2 (X_CHOOSE_TAC `N:num`) ASSUME_TAC) THEN
    EXISTS_TAC `MAX M N` THEN
    ASM_REWRITE_TAC[ARITH_RULE `MAX M N <= n <=> M <= n /\ N <= n`] THEN
    ASM_METIS_TAC [LE_TRANS]] THEN
  MAP_EVERY X_GEN_TAC [`d:num`; `r:num->num`] THEN
  ABBREV_TAC `y:num->A = (x:num->A) o (r:num->num)` THEN
  FIRST_X_ASSUM(MP_TAC o ISPEC `r:num->num` o MATCH_MP (MESON[]
   `(!n. x n IN s) ==> !r. (!n. x(r n) IN s)`)) THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [FUN_EQ_THM]) THEN
  SIMP_TAC[o_THM] THEN DISCH_THEN(K ALL_TAC) THEN
  SPEC_TAC(`y:num->A`,`x:num->A`) THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `inv(&d + &1) / &2`) THEN
  REWRITE_TAC[REAL_HALF; REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
  REWRITE_TAC[UNIONS_GSPEC; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `k:A->bool` THEN STRIP_TAC THEN
  SUBGOAL_THEN
    `(:num) SUBSET UNIONS {{i | x i IN mball m (z,inv(&d + &1) / &2)} |
                           (z:A) IN k}`
  MP_TAC THENL [REWRITE_TAC[UNIONS_GSPEC] THEN ASM SET_TAC[]; ALL_TAC] THEN
  DISCH_THEN(MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT] FINITE_SUBSET)) THEN
  ASM_SIMP_TAC[SIMPLE_IMAGE; FINITE_UNIONS; FINITE_IMAGE] THEN
  REWRITE_TAC[REWRITE_RULE[INFINITE] num_INFINITE; FORALL_IN_IMAGE] THEN
  REWRITE_TAC[NOT_FORALL_THM; NOT_IMP; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `z:A` THEN REWRITE_TAC[GSYM INFINITE] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP INFINITE_ENUMERATE) THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:num->num` THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN EXISTS_TAC `0` THEN
  MAP_EVERY X_GEN_TAC [`p:num`; `q:num`] THEN DISCH_THEN(K ALL_TAC) THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP (SET_RULE
    `IMAGE f UNIV = {x | P x} ==> !a. P(f a)`)) THEN
  DISCH_THEN(fun t ->MP_TAC(SPEC `q:num` t) THEN MP_TAC(SPEC `p:num` t)) THEN
  REWRITE_TAC[IN_MBALL] THEN
  SUBGOAL_THEN
   `(z:A) IN mspace m /\ x((r:num->num) p) IN mspace m /\ x(r q) IN mspace m`
  MP_TAC THENL [ASM SET_TAC[]; CONV_TAC METRIC_ARITH]);;

let TOTALLY_BOUNDED_IN_SUBSET = prove
 (`!m s t:A->bool.
     totally_bounded_in m s /\ t SUBSET s ==> totally_bounded_in m t`,
  REWRITE_TAC[TOTALLY_BOUNDED_IN_SEQUENTIALLY] THEN SET_TAC[]);;

let TOTALLY_BOUNDED_IN_UNION = prove
 (`!m s t:A->bool.
        totally_bounded_in m s /\ totally_bounded_in m t
        ==> totally_bounded_in m (s UNION t)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[totally_bounded_in] THEN
  REWRITE_TAC[AND_FORALL_THM] THEN MATCH_MP_TAC MONO_FORALL THEN
  X_GEN_TAC `e:real` THEN ASM_CASES_TAC `&0 < e` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[UNIONS_GSPEC] THEN DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC)
   (X_CHOOSE_THEN `v:A->bool` STRIP_ASSUME_TAC)) THEN
  EXISTS_TAC `u UNION v:A->bool` THEN
  ASM_REWRITE_TAC[FINITE_UNION] THEN ASM SET_TAC[]);;

let TOTALLY_BOUNDED_IN_UNIONS = prove
 (`!m f:(A->bool)->bool.
        FINITE f /\ (!s. s IN f ==> totally_bounded_in m s)
        ==> totally_bounded_in m (UNIONS f)`,
  GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[UNIONS_0; TOTALLY_BOUNDED_IN_EMPTY; IN_INSERT; UNIONS_INSERT] THEN
  MESON_TAC[TOTALLY_BOUNDED_IN_UNION]);;

let TOTALLY_BOUNDED_IN_IMP_MBOUNDED = prove
 (`!m s:A->bool. totally_bounded_in m s ==> mbounded m s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[totally_bounded_in] THEN
  DISCH_THEN(MP_TAC o SPEC `&1`) THEN
  REWRITE_TAC[REAL_LT_01; LEFT_IMP_EXISTS_THM] THEN GEN_TAC THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] MBOUNDED_SUBSET) THEN
  MATCH_MP_TAC MBOUNDED_UNIONS THEN
  ASM_SIMP_TAC[SIMPLE_IMAGE; FINITE_IMAGE; FORALL_IN_IMAGE] THEN
  REWRITE_TAC[MBOUNDED_MBALL]);;

let TOTALLY_BOUNDED_IN_SUBMETRIC = prove
 (`!m s t:A->bool.
        totally_bounded_in m s /\ s SUBSET t
        ==> totally_bounded_in (submetric m t) s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[totally_bounded_in] THEN
  SIMP_TAC[UNIONS_GSPEC; SUBSET; IN_ELIM_THM] THEN STRIP_TAC THEN
  X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `k:A->bool` THEN
  ONCE_REWRITE_TAC[MESON[] `(?x. P x /\ Q x) <=> ~(!x. P x ==> ~Q x)`] THEN
  ASM_SIMP_TAC[MBALL_SUBMETRIC] THEN ASM SET_TAC[]);;

let TOTALLY_BOUNDED_IN_ABSOLUTE = prove
 (`!m s:A->bool.
        totally_bounded_in (submetric m s) s <=> totally_bounded_in m s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[totally_bounded_in] THEN
  SIMP_TAC[UNIONS_GSPEC; SUBSET; IN_ELIM_THM] THEN EQ_TAC THEN STRIP_TAC THEN
  X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `k:A->bool` THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  ASM_REWRITE_TAC[] THEN
  ONCE_REWRITE_TAC[MESON[] `(?x. P x /\ Q x) <=> ~(!x. P x ==> ~Q x)`] THEN
  ASM_SIMP_TAC[MBALL_SUBMETRIC] THEN ASM SET_TAC[]);;

let TOTALLY_BOUNDED_IN_CLOSURE_OF = prove
 (`!m s:A->bool.
        totally_bounded_in m s
        ==> totally_bounded_in m (mtopology m closure_of s)`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
  DISCH_THEN(MP_TAC o SPEC `mspace m INTER s:A->bool` o
   MATCH_MP(REWRITE_RULE[IMP_CONJ] TOTALLY_BOUNDED_IN_SUBSET)) THEN
  REWRITE_TAC[INTER_SUBSET; TOPSPACE_MTOPOLOGY] THEN
  MP_TAC(SET_RULE `mspace m INTER (s:A->bool) SUBSET mspace m`) THEN
  SPEC_TAC(`mspace m INTER (s:A->bool)`,`s:A->bool`) THEN
  GEN_TAC THEN DISCH_TAC THEN REWRITE_TAC[totally_bounded_in] THEN
  DISCH_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN ASM_REWRITE_TAC[REAL_HALF] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `k:A->bool` THEN
  REWRITE_TAC[UNIONS_GSPEC] THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  CONJ_TAC THENL
   [ASM_MESON_TAC[SUBSET_TRANS; CLOSURE_OF_SUBSET; TOPSPACE_MTOPOLOGY];
    ALL_TAC] THEN
  REWRITE_TAC[SUBSET; METRIC_CLOSURE_OF; IN_ELIM_THM] THEN
  X_GEN_TAC `x:A` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN ASM_REWRITE_TAC[REAL_HALF] THEN
  REWRITE_TAC[IN_MBALL] THEN
  DISCH_THEN(X_CHOOSE_THEN `y:A` STRIP_ASSUME_TAC) THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `y:A` o MATCH_MP (SET_RULE
   `s SUBSET {x | P x} ==> !a. a IN s ==> P a`)) THEN
  ASM_REWRITE_TAC[IN_MBALL] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `z:A` THEN ASM_CASES_TAC `(z:A) IN k` THEN ASM_SIMP_TAC[] THEN
  MAP_EVERY UNDISCH_TAC
   [`(x:A) IN mspace m`; `(y:A) IN mspace m`; `mdist m (x:A,y) < e / &2`] THEN
  CONV_TAC METRIC_ARITH);;

let TOTALLY_BOUNDED_IN_CLOSURE_OF_EQ = prove
 (`!m s:A->bool.
        s SUBSET mspace m
        ==> (totally_bounded_in m (mtopology m closure_of s) <=>
             totally_bounded_in m s)`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  REWRITE_TAC[TOTALLY_BOUNDED_IN_CLOSURE_OF] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] TOTALLY_BOUNDED_IN_SUBSET) THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBSET; TOPSPACE_MTOPOLOGY]);;

let TOTALLY_BOUNDED_IN_CAUCHY_SEQUENCE = prove
 (`!m x:num->A.
        cauchy_in m x ==> totally_bounded_in m (IMAGE x (:num))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[cauchy_in; totally_bounded_in] THEN
  STRIP_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
  DISCH_THEN(X_CHOOSE_THEN `N:num` (MP_TAC o SPEC `N:num`)) THEN
  REWRITE_TAC[LE_REFL] THEN DISCH_TAC THEN
  EXISTS_TAC `IMAGE (x:num->A) (0..N)` THEN
  SIMP_TAC[FINITE_IMAGE; FINITE_NUMSEG; IMAGE_SUBSET; SUBSET_UNIV] THEN
  REWRITE_TAC[SUBSET; UNIONS_GSPEC; IN_UNIV; FORALL_IN_IMAGE] THEN
  REWRITE_TAC[EXISTS_IN_IMAGE; IN_ELIM_THM; IN_NUMSEG; LE_0] THEN
  X_GEN_TAC `n:num` THEN ASM_CASES_TAC `n:num <= N` THENL
   [EXISTS_TAC `n:num` THEN ASM_SIMP_TAC[CENTRE_IN_MBALL];
    EXISTS_TAC `N:num` THEN ASM_REWRITE_TAC[IN_MBALL; LE_REFL] THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_ARITH_TAC]);;

let CAUCHY_IN_IMP_MBOUNDED = prove
 (`!m:A metric x. cauchy_in m x ==> mbounded m {x i | i IN (:num)}`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[SIMPLE_IMAGE] THEN
  ASM_SIMP_TAC[TOTALLY_BOUNDED_IN_IMP_MBOUNDED;
               TOTALLY_BOUNDED_IN_CAUCHY_SEQUENCE]);;

(* ------------------------------------------------------------------------- *)
(* Compactness in metric spaces.                                             *)
(* ------------------------------------------------------------------------- *)

let BOLZANO_WEIERSTRASS_PROPERTY = prove
 (`!m u s:A->bool.
      s SUBSET u /\ s SUBSET mspace m
      ==> ((!x. (!n:num. x n IN s)
                ==> ?l r. l IN u /\ (!m n. m < n ==> r m < r n) /\
                          limit (mtopology m) (x o r) l sequentially) <=>
           (!t. t SUBSET s /\ INFINITE t
                ==> ~(u INTER (mtopology m) derived_set_of t = {})))`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [DISCH_TAC THEN X_GEN_TAC `t:A->bool` THEN STRIP_TAC THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [INFINITE_CARD_LE]) THEN
    REWRITE_TAC[le_c; INJECTIVE_ON_ALT; LEFT_IMP_EXISTS_THM; IN_UNIV] THEN
    X_GEN_TAC `f:num->A` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `f:num->A`) THEN
    ANTS_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[GSYM MEMBER_NOT_EMPTY]] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `l:A` THEN
    DISCH_THEN(X_CHOOSE_THEN `r:num->num` STRIP_ASSUME_TAC) THEN
    ASM_REWRITE_TAC[IN_INTER] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [LIMIT_METRIC]) THEN
    REWRITE_TAC[METRIC_DERIVED_SET_OF; IN_ELIM_THM] THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[] THEN  X_GEN_TAC `r:real` THEN
    DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC `r:real`) THEN
    ASM_REWRITE_TAC[EVENTUALLY_SEQUENTIALLY; o_THM] THEN
    DISCH_THEN(X_CHOOSE_THEN `N:num` (fun th ->
      MP_TAC(SPEC `N + 1` th) THEN MP_TAC(SPEC `N:num` th))) THEN
    REWRITE_TAC[ARITH_RULE `N <= N + 1`; LE_REFL] THEN
    REPEAT STRIP_TAC THEN MATCH_MP_TAC(MESON[]
     `(?x y. P x /\ P y /\ ~(x = y)) ==> (?z. ~(z = l) /\ P z)`) THEN
    MAP_EVERY EXISTS_TAC [`(f:num->A)(r(N + 1))`; `(f:num->A)(r(N:num))`] THEN
    ASM_SIMP_TAC[IN_MBALL; ARITH_RULE `N < N + 1`;
       MESON[LT_REFL] `x:num < y ==> ~(y = x)`] THEN
    ASM_MESON_TAC[MDIST_SYM; SUBSET];
    ALL_TAC] THEN
  REWRITE_TAC[METRIC_DERIVED_SET_OF; GSYM MEMBER_NOT_EMPTY] THEN
  REWRITE_TAC[IN_INTER; IN_ELIM_THM] THEN
  DISCH_TAC THEN X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
  ASM_CASES_TAC `FINITE(IMAGE (x:num->A) (:num))` THENL
   [FIRST_ASSUM(MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
      FINITE_IMAGE_INFINITE)) THEN
    REWRITE_TAC[num_INFINITE; IN_UNIV; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `m:num` THEN
    DISCH_THEN(MP_TAC o MATCH_MP INFINITE_ENUMERATE) THEN
    GEN_REWRITE_TAC RAND_CONV [SWAP_EXISTS_THM] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:num->num` THEN
    STRIP_TAC THEN EXISTS_TAC `(x:num->A) m` THEN
    FIRST_ASSUM(ASSUME_TAC o MATCH_MP (SET_RULE
     `IMAGE f UNIV = {x | P x} ==> !n. P(f n)`)) THEN
    ASM_REWRITE_TAC[o_DEF; LIMIT_CONST; TOPSPACE_MTOPOLOGY] THEN
    ASM SET_TAC[];
    FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (x:num->A) (:num)`) THEN
    ASM_REWRITE_TAC[INFINITE; SUBSET; FORALL_IN_IMAGE] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `l:A` THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    SUBGOAL_THEN `!n. (x:num->A) n IN mspace m` ASSUME_TAC THENL
     [ASM SET_TAC[]; ALL_TAC] THEN
    SUBGOAL_THEN
     `?r:num->num.
              (!n. (!p. p < n ==> r p < r n) /\
                   ~(x(r n) = l) /\ mdist m (x(r n):A,l) < inv(&n + &1))`
    MP_TAC THENL
     [MATCH_MP_TAC (MATCH_MP WF_REC_EXISTS WF_num) THEN SIMP_TAC[] THEN
      X_GEN_TAC `r:num->num` THEN
      X_GEN_TAC `n:num`  THEN  DISCH_THEN(K ALL_TAC) THEN
      FIRST_ASSUM(MP_TAC o SPEC
       `inf((inv(&n + &1)) INSERT
        (IMAGE (\k. mdist m (l,(x:num->A) k))
               (UNIONS (IMAGE (\p. 0..r p) {p | p < n})) DELETE (&0)))`) THEN
      SIMP_TAC[REAL_LT_INF_FINITE; FINITE_INSERT; NOT_INSERT_EMPTY; IN_MBALL;
               FINITE_DELETE; FINITE_IMAGE; FINITE_UNIONS;
               FORALL_IN_IMAGE; FINITE_NUMSEG; FINITE_NUMSEG_LT] THEN
      REWRITE_TAC[FORALL_IN_INSERT; REAL_LT_INV_EQ; IN_DELETE; IMP_CONJ] THEN
      REWRITE_TAC[FORALL_IN_IMAGE; FORALL_IN_UNIONS; IMP_CONJ;
                  RIGHT_FORALL_IMP_THM; IN_NUMSEG; IN_ELIM_THM] THEN
      ASM_SIMP_TAC[MDIST_POS_LT; MDIST_0; REAL_ARITH `&0 < &n + &1`] THEN
      ONCE_REWRITE_TAC[TAUT `p /\ q /\ r <=> q /\ p /\ r`] THEN
      REWRITE_TAC[EXISTS_IN_IMAGE; IN_UNIV; FORALL_AND_THM] THEN
      MATCH_MP_TAC MONO_EXISTS THEN SIMP_TAC[GSYM NOT_LT; CONJUNCT1 LT] THEN
      ASM_MESON_TAC[MDIST_SYM; REAL_LT_REFL];
      MATCH_MP_TAC MONO_EXISTS THEN REWRITE_TAC[FORALL_AND_THM] THEN
      X_GEN_TAC `r:num->num` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
      ASM_REWRITE_TAC[LIMIT_METRIC; o_DEF] THEN
      X_GEN_TAC `e:real` THEN DISCH_TAC THEN
      MATCH_MP_TAC EVENTUALLY_MONO THEN
      EXISTS_TAC `\n. inv(&n + &1) < e` THEN
      ASM_REWRITE_TAC[ARCH_EVENTUALLY_INV1] THEN X_GEN_TAC `k:num` THEN
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] REAL_LT_TRANS) THEN
      ASM_REWRITE_TAC[]]]);;

let [COMPACT_IN_EQ_BOLZANO_WEIERSTRASS;
     COMPACT_IN_SEQUENTIALLY;
     COMPACT_IN_IMP_TOTALLY_BOUNDED_IN_EXPLICIT;
     LEBESGUE_NUMBER] = (CONJUNCTS o prove)
 (`(!m s:A->bool.
        compact_in (mtopology m) s <=>
        s SUBSET mspace m /\
        !t. t SUBSET s /\ INFINITE t
            ==> ~(s INTER (mtopology m) derived_set_of t = {})) /\
   (!m s:A->bool.
        compact_in (mtopology m) s <=>
        s SUBSET mspace m /\
        !x. (!n:num. x n IN s)
            ==> ?l r. l IN s /\ (!m n. m < n ==> r m < r n) /\
                      limit (mtopology m) (x o r) l sequentially) /\
   (!m (s:A->bool) e.
        compact_in (mtopology m) s /\ &0 < e
        ==> ?k. FINITE k /\ k SUBSET s /\
                s SUBSET UNIONS { mball m (x,e) | x IN k}) /\
   (!m (s:A->bool) U.
        compact_in (mtopology m) s /\
        (!u. u IN U ==> open_in (mtopology m) u) /\ s SUBSET UNIONS U
        ==> ?e. &0 < e /\
                !x. x IN s ==> ?u. u IN U /\ mball m (x,e) SUBSET u)`,
  REWRITE_TAC[AND_FORALL_THM] THEN
  MAP_EVERY X_GEN_TAC [`m:A metric`; `s:A->bool`] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET mspace m` THENL
   [ASM_REWRITE_TAC[];
    ASM_MESON_TAC[COMPACT_IN_SUBSET_TOPSPACE; TOPSPACE_MTOPOLOGY]] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[IMP_IMP; GSYM CONJ_ASSOC] THEN MATCH_MP_TAC(TAUT
   `(p ==> q) /\ (q ==> r) /\ (r ==> s) /\ (r ==> t) /\ (s /\ t ==> p)
    ==> (p <=> q) /\ (p <=> r) /\ (p ==> s) /\ (p ==> t)`) THEN
  REPEAT CONJ_TAC THENL
   [MESON_TAC[COMPACT_IN_IMP_BOLZANO_WEIERSTRASS];
    MATCH_MP_TAC EQ_IMP THEN CONV_TAC SYM_CONV THEN
    MATCH_MP_TAC BOLZANO_WEIERSTRASS_PROPERTY THEN
    ASM_REWRITE_TAC[SUBSET_REFL];
    DISCH_TAC THEN ASM_REWRITE_TAC[GSYM totally_bounded_in] THEN
    ASM_SIMP_TAC[TOTALLY_BOUNDED_IN_SEQUENTIALLY] THEN
    X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN ASM_REWRITE_TAC[] THEN
    GEN_REWRITE_TAC LAND_CONV [SWAP_EXISTS_THM] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:num->num` THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC CONVERGENT_IMP_CAUCHY_IN THEN
    REWRITE_TAC[o_THM] THEN ASM SET_TAC[];
    DISCH_TAC THEN X_GEN_TAC `U:(A->bool)->bool` THEN STRIP_TAC THEN
    ONCE_REWRITE_TAC[MESON[] `(?x. P x /\ Q x) <=> ~(!x. P x ==> ~Q x)`] THEN
    GEN_REWRITE_TAC (RAND_CONV o TOP_DEPTH_CONV)
      [NOT_FORALL_THM; RIGHT_IMP_EXISTS_THM; NOT_IMP] THEN
    DISCH_THEN(MP_TAC o GEN `n:num` o SPEC `inv(&n + &1)`) THEN
    REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
    REWRITE_TAC[SKOLEM_THM; NOT_EXISTS_THM; FORALL_AND_THM] THEN
    X_GEN_TAC `x:num->A` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN
    ASM_REWRITE_TAC[NOT_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`l:A`; `r:num->num`] THEN STRIP_TAC THEN
    SUBGOAL_THEN `?b:A->bool. l IN b /\ b IN U` STRIP_ASSUME_TAC THENL
     [ASM_MESON_TAC[SUBSET; IN_UNIONS]; ALL_TAC] THEN
    SUBGOAL_THEN
     `?e. &0 < e /\ !z:A. z IN mspace m /\ mdist m (z,l) < e ==> z IN b`
    STRIP_ASSUME_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o SPEC `b:A->bool`) THEN
      ASM_REWRITE_TAC[OPEN_IN_MTOPOLOGY; SUBSET; IN_MBALL] THEN
      DISCH_THEN(CONJUNCTS_THEN (MP_TAC o SPEC `l:A`)) THEN
      ASM_MESON_TAC[MDIST_SYM];
      ALL_TAC] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [LIMIT_METRIC]) THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `e / &2`)) THEN
    MP_TAC(ISPEC `e / &2` ARCH_EVENTUALLY_INV1) THEN
    ASM_REWRITE_TAC[REAL_HALF; TAUT `p ==> ~q <=> ~(p /\ q)`] THEN
    REWRITE_TAC[GSYM EVENTUALLY_AND; o_THM] THEN
    DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_HAPPENS) THEN
    REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY; NOT_EXISTS_THM] THEN
    X_GEN_TAC `n:num` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`(r:num->num) n`; `b:A->bool`]) THEN
    ASM_REWRITE_TAC[SUBSET; IN_MBALL] THEN X_GEN_TAC `z:A` THEN STRIP_TAC THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC[] THEN
    FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (METRIC_ARITH
      `mdist m (x,l) < e / &2
       ==> x IN mspace m /\ z IN mspace m /\ l IN mspace m /\
           mdist m (x,z) < e / &2
           ==> mdist m (z,l) < e`)) THEN
    ASM_REWRITE_TAC[] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (REWRITE_RULE[IMP_CONJ_ALT] REAL_LT_TRANS)) THEN
    FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (REWRITE_RULE[IMP_CONJ] REAL_LTE_TRANS)) THEN
    MATCH_MP_TAC REAL_LE_INV2 THEN
    REWRITE_TAC[REAL_OF_NUM_LE; REAL_LE_RADD; REAL_ARITH `&0 < &n + &1`] THEN
    ASM_MESON_TAC[MONOTONE_BIGGER];
    DISCH_TAC THEN ASM_REWRITE_TAC[compact_in; TOPSPACE_MTOPOLOGY] THEN
    X_GEN_TAC `U:(A->bool)->bool` THEN STRIP_TAC THEN FIRST_X_ASSUM
     (CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `U:(A->bool)->bool`)) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `r:real` THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
     (MP_TAC o REWRITE_RULE[RIGHT_IMP_EXISTS_THM])) THEN
    REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `f:A->A->bool` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `r:real`) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM; UNIONS_GSPEC] THEN
    X_GEN_TAC `k:A->bool` THEN STRIP_TAC THEN
    EXISTS_TAC `IMAGE (f:A->A->bool) k` THEN
    ASM_SIMP_TAC[FINITE_IMAGE; SUBSET; UNIONS_IMAGE; FORALL_IN_IMAGE] THEN
    ASM SET_TAC[]]);;

let COMPACT_SPACE_SEQUENTIALLY = prove
 (`!m:A metric.
        compact_space(mtopology m) <=>
        !x. (!n:num. x n IN mspace m)
            ==> ?l r. l IN mspace m /\
                      (!m n. m < n ==> r m < r n) /\
                      limit (mtopology m) (x o r) l sequentially`,
  REWRITE_TAC[compact_space; COMPACT_IN_SEQUENTIALLY; SUBSET_REFL;
              TOPSPACE_MTOPOLOGY]);;

let COMPACT_SPACE_EQ_BOLZANO_WEIERSTRASS = prove
 (`!m:A metric.
        compact_space(mtopology m) <=>
        !s. s SUBSET mspace m /\ INFINITE s
            ==> ~(mtopology m derived_set_of s = {})`,
  REWRITE_TAC[compact_space; COMPACT_IN_EQ_BOLZANO_WEIERSTRASS] THEN
  GEN_TAC THEN REWRITE_TAC[TOPSPACE_MTOPOLOGY; SUBSET_REFL] THEN
  REWRITE_TAC[derived_set_of; TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; IN_INTER; IN_ELIM_THM] THEN
  AP_TERM_TAC THEN ABS_TAC THEN SET_TAC[]);;

let COMPACT_SPACE_NEST = prove
 (`!m:A metric.
        compact_space(mtopology m) <=>
        !c. (!n. closed_in (mtopology m) (c n)) /\
            (!n. ~(c n = {})) /\
            (!m n. m <= n ==> c n SUBSET c m)
            ==> ~(INTERS {c n | n IN (:num)} = {})`,
  GEN_TAC THEN EQ_TAC THENL
   [REWRITE_TAC[COMPACT_SPACE_FIP] THEN DISCH_TAC THEN
    X_GEN_TAC `c:num->A->bool` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (c:num->A->bool) (:num)`) THEN
    ASM_REWRITE_TAC[SIMPLE_IMAGE; FORALL_IN_IMAGE] THEN
    DISCH_THEN MATCH_MP_TAC THEN
    REWRITE_TAC[FORALL_FINITE_SUBSET_IMAGE; SUBSET_UNIV] THEN
    X_GEN_TAC `k:num->bool` THEN DISCH_THEN(MP_TAC o ISPEC `\n:num. n` o
      MATCH_MP UPPER_BOUND_FINITE_SET) THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `n:num` THEN
    DISCH_TAC THEN MATCH_MP_TAC(SET_RULE
     `!t. ~(t = {}) /\ t SUBSET s ==> ~(s = {})`) THEN
    EXISTS_TAC `(c:num->A->bool) n` THEN
    ASM_SIMP_TAC[SUBSET_INTERS; FORALL_IN_IMAGE];
    DISCH_TAC THEN REWRITE_TAC[COMPACT_SPACE_SEQUENTIALLY] THEN
    X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC
     `\n. mtopology m closure_of (IMAGE (x:num->A) (from n))`) THEN
    REWRITE_TAC[CLOSED_IN_CLOSURE_OF] THEN
    SIMP_TAC[CLOSURE_OF_MONO; FROM_MONO; IMAGE_SUBSET] THEN
    REWRITE_TAC[CLOSURE_OF_EQ_EMPTY_GEN; TOPSPACE_MTOPOLOGY] THEN
    ASM_SIMP_TAC[FROM_NONEMPTY; SET_RULE
     `(!n. x n IN s) /\ ~(k = {}) ==> ~DISJOINT s (IMAGE x k)`] THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; INTERS_GSPEC; IN_ELIM_THM] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `l:A` THEN
    REWRITE_TAC[IN_UNIV; METRIC_CLOSURE_OF; IN_ELIM_THM; FORALL_AND_THM] THEN
    REWRITE_TAC[EXISTS_IN_IMAGE; IN_FROM; IN_MBALL] THEN STRIP_TAC THEN
    SUBGOAL_THEN
     `?r. (!n. mdist m (l:A,x(r n)) < inv(&n + &1)) /\
          (!n. (r:num->num) n < r(SUC n))`
    MP_TAC THENL
     [MATCH_MP_TAC DEPENDENT_CHOICE THEN CONJ_TAC THENL
       [FIRST_X_ASSUM(MP_TAC o SPECL [`0`; `&1`]);
        MAP_EVERY X_GEN_TAC [`n:num`; `m:num`] THEN STRIP_TAC THEN
        FIRST_X_ASSUM(MP_TAC o SPECL [`m + 1`; `inv(&(SUC n) + &1)`])] THEN
      REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
      CONV_TAC REAL_RAT_REDUCE_CONV THEN
      REWRITE_TAC[ARITH_RULE `m + 1 <= n <=> m < n`] THEN MESON_TAC[];
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:num->num` THEN
      STRIP_TAC THEN ASM_REWRITE_TAC[SUBSEQUENCE_STEPWISE] THEN
      ASM_REWRITE_TAC[LIMIT_METRIC; o_THM] THEN X_GEN_TAC `e:real` THEN
      GEN_REWRITE_TAC LAND_CONV [GSYM ARCH_EVENTUALLY_INV1] THEN
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
      ASM_MESON_TAC[REAL_LT_TRANS; MDIST_SYM]]]);;

let COMPACT_IN_IMP_TOTALLY_BOUNDED_IN = prove
 (`!m (s:A->bool). compact_in (mtopology m) s ==> totally_bounded_in m s`,
  REWRITE_TAC[totally_bounded_in] THEN
  MESON_TAC[COMPACT_IN_IMP_TOTALLY_BOUNDED_IN_EXPLICIT]);;

let MCOMPLETE_DISCRETE_METRIC = prove
 (`!s:A->bool. mcomplete (discrete_metric s)`,
  GEN_TAC THEN REWRITE_TAC[mcomplete; DISCRETE_METRIC; cauchy_in] THEN
  X_GEN_TAC `x:num->A` THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `&1`)) THEN
  ONCE_REWRITE_TAC[COND_RAND] THEN ONCE_REWRITE_TAC[COND_RATOR] THEN
  CONV_TAC REAL_RAT_REDUCE_CONV THEN
  DISCH_THEN(X_CHOOSE_THEN `N:num` (MP_TAC o SPEC `N:num`)) THEN
  REWRITE_TAC[LE_REFL; TAUT `(if p then T else F) = p`] THEN
  DISCH_TAC THEN EXISTS_TAC `(x:num->A) N` THEN
  MATCH_MP_TAC LIMIT_EVENTUALLY THEN
  ASM_REWRITE_TAC[DISCRETE_METRIC; TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN ASM_MESON_TAC[]);;

let COMPACT_SPACE_IMP_MCOMPLETE = prove
 (`!m:A metric. compact_space(mtopology m) ==> mcomplete m`,
  SIMP_TAC[COMPACT_SPACE_NEST; MCOMPLETE_NEST]);;

let COMPACT_IN_IMP_MCOMPLETE = prove
 (`!m s:A->bool. compact_in (mtopology m) s ==> mcomplete (submetric m s)`,
  REWRITE_TAC[COMPACT_IN_SUBSPACE] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC COMPACT_SPACE_IMP_MCOMPLETE THEN
  ASM_REWRITE_TAC[MTOPOLOGY_SUBMETRIC]);;

let MCOMPLETE_IMP_CLOSED_IN = prove
 (`!m s:A->bool.
       mcomplete(submetric m s) /\ s SUBSET mspace m
       ==> closed_in (mtopology m) s`,
  REPEAT STRIP_TAC THEN
  ASM_REWRITE_TAC[METRIC_CLOSED_IN_IFF_SEQUENTIALLY_CLOSED] THEN
  MAP_EVERY X_GEN_TAC [`x:num->A`; `l:A`] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
        CONVERGENT_IMP_CAUCHY_IN)) THEN
  ANTS_TAC THENL [ASM SET_TAC[]; STRIP_TAC] THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A` o REWRITE_RULE[mcomplete]) THEN
  ASM_REWRITE_TAC[CAUCHY_IN_SUBMETRIC; LIMIT_SUBTOPOLOGY;
                  MTOPOLOGY_SUBMETRIC] THEN
  DISCH_THEN(X_CHOOSE_THEN `l':A` STRIP_ASSUME_TAC) THEN
  SUBGOAL_THEN `l:A = l'` (fun th -> ASM_REWRITE_TAC[th]) THEN
  MATCH_MP_TAC(ISPEC `sequentially` LIMIT_METRIC_UNIQUE) THEN
  ASM_MESON_TAC[TRIVIAL_LIMIT_SEQUENTIALLY]);;

let CLOSED_IN_EQ_MCOMPLETE = prove
 (`!m s:A->bool.
        mcomplete m
        ==> (closed_in (mtopology m) s <=>
             s SUBSET mspace m /\ mcomplete(submetric m s))`,
  MESON_TAC[MCOMPLETE_IMP_CLOSED_IN; CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE;
            CLOSED_IN_SUBSET; TOPSPACE_MTOPOLOGY]);;

let COMPACT_SPACE_EQ_MCOMPLETE_TOTALLY_BOUNDED_IN = prove
 (`!m:A metric.
        compact_space(mtopology m) <=>
        mcomplete m /\ totally_bounded_in m (mspace m)`,
  GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC[COMPACT_SPACE_IMP_MCOMPLETE; COMPACT_IN_IMP_TOTALLY_BOUNDED_IN;
           GSYM compact_space; GSYM TOPSPACE_MTOPOLOGY] THEN
  SIMP_TAC[TOTALLY_BOUNDED_IN_SEQUENTIALLY; SUBSET_REFL] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN STRIP_TAC THEN
  REWRITE_TAC[compact_space; COMPACT_IN_SEQUENTIALLY] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY; SUBSET_REFL] THEN
  X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN
  ASM_REWRITE_TAC[] THEN ONCE_REWRITE_TAC[SWAP_EXISTS_THM] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:num->num` THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  FIRST_ASSUM(MP_TAC o SPEC `(x:num->A) o (r:num->num)` o
      REWRITE_RULE[mcomplete]) THEN
  ASM_REWRITE_TAC[limit; TOPSPACE_MTOPOLOGY] THEN MESON_TAC[]);;

let COMPACT_CLOSURE_OF_IMP_TOTALLY_BOUNDED_IN = prove
 (`!m s:A->bool.
      s SUBSET mspace m /\ compact_in (mtopology m) (mtopology m closure_of s)
      ==> totally_bounded_in m s`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC TOTALLY_BOUNDED_IN_SUBSET THEN
  EXISTS_TAC `mtopology m closure_of s:A->bool` THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBSET; TOPSPACE_MTOPOLOGY] THEN
  MATCH_MP_TAC COMPACT_IN_IMP_TOTALLY_BOUNDED_IN THEN ASM_REWRITE_TAC[]);;

let TOTALLY_BOUNDED_IN_EQ_COMPACT_CLOSURE_OF = prove
 (`!m s:A->bool.
        mcomplete m
        ==> (totally_bounded_in m s <=>
             s SUBSET mspace m /\
             compact_in (mtopology m) (mtopology m closure_of s))`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  SIMP_TAC[COMPACT_CLOSURE_OF_IMP_TOTALLY_BOUNDED_IN] THEN
  SIMP_TAC[TOTALLY_BOUNDED_IN_IMP_SUBSET] THEN DISCH_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP TOTALLY_BOUNDED_IN_IMP_SUBSET) THEN
  REWRITE_TAC[COMPACT_IN_SUBSPACE; CLOSURE_OF_SUBSET_TOPSPACE] THEN
  REWRITE_TAC[GSYM MTOPOLOGY_SUBMETRIC] THEN
  REWRITE_TAC[COMPACT_SPACE_EQ_MCOMPLETE_TOTALLY_BOUNDED_IN] THEN
  ASM_SIMP_TAC[CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE; CLOSED_IN_CLOSURE_OF] THEN
  MATCH_MP_TAC TOTALLY_BOUNDED_IN_SUBMETRIC THEN
  REWRITE_TAC[SUBMETRIC; INTER_SUBSET] THEN
  SIMP_TAC[SET_RULE `s SUBSET u ==> s INTER u = s`;
           CLOSURE_OF_SUBSET_TOPSPACE; GSYM TOPSPACE_MTOPOLOGY] THEN
  ASM_SIMP_TAC[TOTALLY_BOUNDED_IN_CLOSURE_OF]);;

let COMPACT_CLOSURE_OF_EQ_BOLZANO_WEIERSTRASS = prove
 (`!m s:A->bool.
        compact_in (mtopology m) (mtopology m closure_of s) <=>
        !t. INFINITE t /\ t SUBSET s /\ t SUBSET mspace m
            ==> ~(mtopology m derived_set_of t = {})`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [DISCH_TAC THEN GEN_TAC THEN STRIP_TAC THEN
    MATCH_MP_TAC COMPACT_CLOSURE_OF_IMP_BOLZANO_WEIERSTRASS THEN
    EXISTS_TAC `s:A->bool` THEN ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY];
    REWRITE_TAC[GSYM SUBSET_INTER] THEN ONCE_REWRITE_TAC[INTER_COMM] THEN
    ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
    MP_TAC(SET_RULE `mspace m INTER (s:A->bool) SUBSET mspace m`) THEN
    SPEC_TAC(`mspace m INTER (s:A->bool)`,`s:A->bool`)] THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[COMPACT_IN_SEQUENTIALLY] THEN
  REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY; CLOSURE_OF_SUBSET_TOPSPACE] THEN
  MP_TAC(ISPECL [`m:A metric`; `mtopology m closure_of s:A->bool`;
                `s:A->bool`] BOLZANO_WEIERSTRASS_PROPERTY) THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBSET; TOPSPACE_MTOPOLOGY] THEN
  MATCH_MP_TAC(TAUT `q /\ (p ==> r) ==> (p <=> q) ==> r`) THEN CONJ_TAC THENL
   [X_GEN_TAC `t:A->bool` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `t:A->bool`) THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; IN_INTER] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `a:A` THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[CLOSURE_OF; IN_INTER; IN_UNION] THEN
    ASM_MESON_TAC[SUBSET; DERIVED_SET_OF_MONO; DERIVED_SET_OF_SUBSET_TOPSPACE];
    ALL_TAC] THEN
  DISCH_TAC THEN X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
  SUBGOAL_THEN `!n. ?y. y IN s /\ mdist m ((x:num->A) n,y) < inv(&n + &1)`
  MP_TAC THENL
   [X_GEN_TAC `n:num` THEN FIRST_ASSUM(MP_TAC o
        GEN_REWRITE_RULE RAND_CONV [METRIC_CLOSURE_OF] o SPEC `n:num`) THEN
    ASM_REWRITE_TAC[IN_ELIM_THM; IN_MBALL] THEN
    DISCH_THEN(MP_TAC o SPEC `inv(&n + &1)` o CONJUNCT2) THEN
    REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN MESON_TAC[];
    REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `y:num->A` THEN REWRITE_TAC[FORALL_AND_THM] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `y:num->A`) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `l:A` THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:num->num` THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  ASM_REWRITE_TAC[LIMIT_METRIC] THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  X_GEN_TAC `e:real` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN
  MP_TAC(SPEC `e / &2` ARCH_EVENTUALLY_INV1) THEN
  ASM_REWRITE_TAC[REAL_HALF; IMP_IMP; GSYM EVENTUALLY_AND] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  X_GEN_TAC `n:num` THEN REWRITE_TAC[o_THM] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  SUBGOAL_THEN `mdist m ((x:num->A)(r(n:num)),y(r n)) < e / &2` MP_TAC THENL
   [TRANS_TAC REAL_LT_TRANS `inv(&(r(n:num)) + &1)` THEN
    ASM_REWRITE_TAC[] THEN
    TRANS_TAC REAL_LET_TRANS `inv(&n + &1)` THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC REAL_LE_INV2 THEN
    CONJ_TAC THENL [REAL_ARITH_TAC; REWRITE_TAC[REAL_LE_RADD]] THEN
    ASM_MESON_TAC[REAL_OF_NUM_LE; MONOTONE_BIGGER];
    UNDISCH_TAC `(l:A) IN mspace m`] THEN
  SUBGOAL_THEN `(x:num->A)(r(n:num)) IN mspace m` MP_TAC THENL
   [ASM_MESON_TAC[SUBSET; CLOSURE_OF_SUBSET_TOPSPACE; TOPSPACE_MTOPOLOGY];
    SIMP_TAC[] THEN CONV_TAC METRIC_ARITH]);;

let MCOMPLETE_REAL_EUCLIDEAN_METRIC = prove
 (`mcomplete real_euclidean_metric`,
  REWRITE_TAC[mcomplete] THEN X_GEN_TAC `x:num->real` THEN
  DISCH_TAC THEN FIRST_ASSUM(MP_TAC o MATCH_MP CAUCHY_IN_IMP_MBOUNDED) THEN
  SIMP_TAC[mbounded; mcball; SUBSET; LEFT_IMP_EXISTS_THM; FORALL_IN_GSPEC] THEN
  REWRITE_TAC[IN_UNIV; IN_ELIM_THM; REAL_EUCLIDEAN_METRIC] THEN
  MAP_EVERY X_GEN_TAC [`a:real`; `b:real`] THEN DISCH_TAC THEN
  MP_TAC(ISPECL [`a - b:real`; `a + b:real`]
    COMPACT_IN_EUCLIDEANREAL_INTERVAL) THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  DISCH_THEN(MP_TAC o MATCH_MP COMPACT_IN_IMP_MCOMPLETE) THEN
  ASM_REWRITE_TAC[mcomplete; CAUCHY_IN_SUBMETRIC] THEN
  DISCH_THEN(MP_TAC o SPEC `x:num->real`) THEN
  ASM_REWRITE_TAC[IN_REAL_INTERVAL; REAL_ARITH
   `a - b <= x /\ x <= a + b <=> abs(x - a) <= b`] THEN
  MATCH_MP_TAC MONO_EXISTS THEN
  SIMP_TAC[LIMIT_SUBTOPOLOGY; MTOPOLOGY_SUBMETRIC]);;

let MCOMPLETE_SUBMETRIC_REAL_EUCLIDEAN_METRIC = prove
 (`!s. mcomplete(submetric real_euclidean_metric s) <=>
       closed_in euclideanreal s`,
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  SIMP_TAC[CLOSED_IN_EQ_MCOMPLETE; MCOMPLETE_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC; SUBSET_UNIV]);;

(* ------------------------------------------------------------------------- *)
(* Completely metrizable (a.k.a. "topologically complete") spaces.           *)
(* ------------------------------------------------------------------------- *)

let completely_metrizable_space = new_definition
 `completely_metrizable_space top <=>
  ?m. mcomplete m /\ top = mtopology m`;;

let COMPLETELY_METRIZABLE_IMP_METRIZABLE_SPACE = prove
 (`!top:A topology. completely_metrizable_space top ==> metrizable_space top`,
  REWRITE_TAC[completely_metrizable_space; metrizable_space] THEN
  MESON_TAC[]);;

let FORALL_MCOMPLETE_TOPOLOGY = prove
 (`!P. (!m:A metric. mcomplete m ==> P (mtopology m) (mspace m)) <=>
       !top. completely_metrizable_space top ==> P top (topspace top)`,
  SIMP_TAC[completely_metrizable_space; LEFT_IMP_EXISTS_THM;
           TOPSPACE_MTOPOLOGY] THEN
  MESON_TAC[]);;

let FORALL_COMPLETELY_METRIZABLE_SPACE = prove
 (`(!top. completely_metrizable_space top ==> P top (topspace top)) <=>
   (!m:A metric. mcomplete m ==> P (mtopology m) (mspace m))`,
  SIMP_TAC[completely_metrizable_space; LEFT_IMP_EXISTS_THM;
           TOPSPACE_MTOPOLOGY] THEN
  MESON_TAC[]);;

let EXISTS_COMPLETELY_METRIZABLE_SPACE = prove
 (`!P. (?top. completely_metrizable_space top /\ P top (topspace top)) <=>
       (?m:A metric.mcomplete m /\  P (mtopology m) (mspace m))`,
  REWRITE_TAC[MESON[] `(?x. P x /\ Q x) <=> ~(!x. P x ==> ~Q x)`] THEN
  REWRITE_TAC[FORALL_MCOMPLETE_TOPOLOGY] THEN MESON_TAC[]);;

let COMPLETELY_METRIZABLE_SPACE_MTOPOLOGY = prove
 (`!m:A metric. mcomplete m ==> completely_metrizable_space(mtopology m)`,
  REWRITE_TAC[FORALL_MCOMPLETE_TOPOLOGY]);;

let COMPLETELY_METRIZABLE_SPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. completely_metrizable_space(discrete_topology u)`,
  REWRITE_TAC[completely_metrizable_space] THEN
  MESON_TAC[MTOPOLOGY_DISCRETE_METRIC; MCOMPLETE_DISCRETE_METRIC]);;

let COMPLETELY_METRIZABLE_SPACE_EUCLIDEANREAL = prove
 (`completely_metrizable_space euclideanreal`,
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  MATCH_MP_TAC COMPLETELY_METRIZABLE_SPACE_MTOPOLOGY THEN
  REWRITE_TAC[MCOMPLETE_REAL_EUCLIDEAN_METRIC]);;

let COMPLETELY_METRIZABLE_SPACE_CLOSED_IN = prove
 (`!top s:A->bool.
        completely_metrizable_space top /\ closed_in top s
        ==> completely_metrizable_space(subtopology top s)`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[GSYM FORALL_MCOMPLETE_TOPOLOGY] THEN
  REWRITE_TAC[GSYM MTOPOLOGY_SUBMETRIC] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC COMPLETELY_METRIZABLE_SPACE_MTOPOLOGY THEN
  MATCH_MP_TAC CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE THEN ASM_REWRITE_TAC[]);;

let HOMEOMORPHIC_COMPLETELY_METRIZABLE_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (completely_metrizable_space top <=>
             completely_metrizable_space top')`,
  let lemma = prove
   (`!(top:A topology) (top':B topology).
          top homeomorphic_space top'
          ==> completely_metrizable_space top
              ==> completely_metrizable_space top'`,
    REPEAT GEN_TAC THEN REWRITE_TAC[completely_metrizable_space] THEN
    REWRITE_TAC[homeomorphic_space; LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN DISCH_TAC THEN
    X_GEN_TAC `m:A metric` THEN DISCH_THEN(STRIP_ASSUME_TAC o GSYM) THEN
    ABBREV_TAC
     `m' = metric(topspace top',\(x,y). mdist m ((g:B->A) x,g y))` THEN
    MP_TAC(ISPECL [`g:B->A`; `m:A metric`; `topspace top':B->bool`]
          METRIC_INJECTIVE_IMAGE) THEN
    ASM_REWRITE_TAC[] THEN ANTS_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [homeomorphic_maps]) THEN
      EXPAND_TAC "top" THEN
      REWRITE_TAC[continuous_map; TOPSPACE_MTOPOLOGY] THEN SET_TAC[];
      STRIP_TAC THEN EXISTS_TAC `m':B metric`] THEN
    MATCH_MP_TAC(TAUT `(q ==> p) /\ q ==> p /\ q`) THEN CONJ_TAC THENL
     [DISCH_THEN(ASSUME_TAC o SYM) THEN
      UNDISCH_TAC `mcomplete(m:A metric)` THEN
      ASM_REWRITE_TAC[mcomplete; cauchy_in; GSYM TOPSPACE_MTOPOLOGY] THEN
      DISCH_TAC THEN X_GEN_TAC `x:num->B` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `(g:B->A) o (x:num->B)`) THEN
      ASM_REWRITE_TAC[o_THM] THEN
      FIRST_X_ASSUM(STRIP_ASSUME_TAC o
        GEN_REWRITE_RULE I [homeomorphic_maps]) THEN
      ANTS_TAC THENL
       [RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[];
        DISCH_THEN(X_CHOOSE_TAC `y:A`)] THEN
      EXISTS_TAC `(f:A->B) y` THEN
      SUBGOAL_THEN `x = f o (g:B->A) o (x:num->B)` SUBST1_TAC THENL
       [REWRITE_TAC[FUN_EQ_THM; o_THM] THEN
        RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[];
        MATCH_MP_TAC CONTINUOUS_MAP_LIMIT THEN ASM_MESON_TAC[]];
      ALL_TAC] THEN
    REWRITE_TAC[TOPOLOGY_EQ; OPEN_IN_MTOPOLOGY] THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [HOMEOMORPHIC_MAPS_SYM]) THEN
    DISCH_THEN(MP_TAC o MATCH_MP HOMEOMORPHIC_MAPS_IMP_MAP) THEN
    DISCH_THEN(fun th ->
      REWRITE_TAC[MATCH_MP HOMEOMORPHIC_MAP_OPENNESS_EQ th]) THEN
    X_GEN_TAC `v:B->bool` THEN
    ASM_CASES_TAC `(v:B->bool) SUBSET topspace top'` THEN
    ASM_REWRITE_TAC[] THEN
    EXPAND_TAC "top" THEN REWRITE_TAC[OPEN_IN_MTOPOLOGY] THEN
    ASM_REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
    ASM_REWRITE_TAC[IN_MBALL] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[homeomorphic_maps; continuous_map]) THEN
    MATCH_MP_TAC(TAUT `p /\ (q <=> r) ==> (p /\ q <=> r)`) THEN
    CONJ_TAC THENL [ASM SET_TAC[]; EQ_TAC] THEN
    MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `b:B` THEN
    ASM_CASES_TAC `(b:B) IN v` THEN
    ASM_REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:real` THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[] THENL
     [X_GEN_TAC `y:B` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `(g:B->A) y`) THEN ASM SET_TAC[];
      ASM SET_TAC[]]) in
  REPEAT STRIP_TAC THEN EQ_TAC THEN MATCH_MP_TAC lemma THEN
  ASM_MESON_TAC[HOMEOMORPHIC_SPACE_SYM]);;

(* ------------------------------------------------------------------------- *)
(* A perfect set in common cases must have cardinality >= c.                 *)
(* ------------------------------------------------------------------------- *)

let CARD_GE_PERFECT_SET = prove
 (`!top s:A->bool.
        (completely_metrizable_space top \/
         locally_compact_space top /\ hausdorff_space top) /\
        top derived_set_of s = s /\ ~(s = {})
        ==> (:real) <=_c s`,
  REWRITE_TAC[TAUT `(p \/ q) /\ r ==> s <=>
                    (p ==> r ==> s) /\ (q /\ r ==> s)`] THEN
  REWRITE_TAC[FORALL_AND_THM; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[GSYM FORALL_MCOMPLETE_TOPOLOGY] THEN
  REWRITE_TAC[RIGHT_IMP_FORALL_THM; IMP_IMP; GSYM CONJ_ASSOC] THEN
  CONJ_TAC THENL
   [REPEAT STRIP_TAC THEN
    TRANS_TAC CARD_LE_TRANS `(:num->bool)` THEN
    SIMP_TAC[CARD_EQ_REAL; CARD_EQ_IMP_LE] THEN
    SUBGOAL_THEN `(s:A->bool) SUBSET mspace m` ASSUME_TAC THENL
     [ASM_MESON_TAC[DERIVED_SET_OF_SUBSET_TOPSPACE; TOPSPACE_MTOPOLOGY];
      ALL_TAC] THEN
    SUBGOAL_THEN
     `!x e. x IN s /\ &0 < e
            ==> ?y z d. y IN s /\ z IN s /\ &0 < d /\ d < e / &2 /\
                        mcball m (y,d) SUBSET mcball m (x,e) /\
                        mcball m (z,d) SUBSET mcball m (x,e) /\
                        DISJOINT (mcball m (y:A,d)) (mcball m (z,d))`
    MP_TAC THENL
     [REPEAT STRIP_TAC THEN
      MP_TAC(ISPECL [`m:A metric`; `s:A->bool`]
          DERIVED_SET_OF_INFINITE_MBALL) THEN
      ASM_REWRITE_TAC[EXTENSION; IN_ELIM_THM] THEN
      DISCH_THEN(MP_TAC o SPEC `x:A`) THEN ASM_REWRITE_TAC[] THEN
      DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `e / &4`)) THEN
      ASM_REWRITE_TAC[INFINITE; REAL_ARITH `&0 < e / &4 <=> &0 < e`] THEN
      DISCH_THEN(MP_TAC o SPEC `x:A` o MATCH_MP
       (MESON[FINITE_RULES; FINITE_SUBSET]
         `~FINITE s ==> !a b c. ~(s SUBSET {a,b,c})`)) THEN
      DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
       `(!b c. ~(s SUBSET {a,b,c}))
        ==> ?b c. b IN s /\ c IN s /\ ~(c = a) /\ ~(b = a) /\ ~(b = c)`)) THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `l:A` THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `r:A` THEN
      REWRITE_TAC[IN_INTER] THEN STRIP_TAC THEN
      EXISTS_TAC `mdist m (l:A,r) / &3` THEN
      REPEAT(FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [IN_MBALL])) THEN
      UNDISCH_TAC `~(l:A = r)` THEN
      REWRITE_TAC[DISJOINT; SUBSET; EXTENSION; IN_INTER; NOT_IN_EMPTY] THEN
      ASM_SIMP_TAC[IN_MCBALL] THEN UNDISCH_TAC `(x:A) IN mspace m` THEN
      POP_ASSUM_LIST(K ALL_TAC) THEN
      REPEAT(DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC)) THEN
      ONCE_REWRITE_TAC[CONJ_ASSOC] THEN CONJ_TAC THENL
       [REPEAT(POP_ASSUM MP_TAC) THEN CONV_TAC METRIC_ARITH; ALL_TAC] THEN
      REWRITE_TAC[AND_FORALL_THM] THEN X_GEN_TAC `y:A` THEN
      REWRITE_TAC[CONJ_ASSOC] THEN CONJ_TAC THENL
       [ALL_TAC; REPEAT(POP_ASSUM MP_TAC) THEN CONV_TAC METRIC_ARITH] THEN
      REPEAT STRIP_TAC THEN FIRST_ASSUM(MP_TAC o SPEC `e:real` o MATCH_MP
        (REAL_ARITH `x <= y / &3 ==> !e. y < e / &2 ==> x < e / &6`)) THEN
      (ANTS_TAC THENL
        [REPEAT(POP_ASSUM MP_TAC) THEN CONV_TAC METRIC_ARITH; ALL_TAC])
      THENL
       [UNDISCH_TAC `mdist m (x:A,l) < e / &4`;
        UNDISCH_TAC `mdist m (x:A,r) < e / &4`] THEN
      MAP_EVERY UNDISCH_TAC
       [`(x:A) IN mspace m`; `(y:A) IN mspace m`;
        `(l:A) IN mspace m`; `(r:A) IN mspace m`] THEN
      CONV_TAC METRIC_ARITH;
      REWRITE_TAC[RIGHT_IMP_EXISTS_THM; SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
    MAP_EVERY X_GEN_TAC
     [`l:A->real->A`; `r:A->real->A`; `d:A->real->real`] THEN
    DISCH_TAC THEN FIRST_X_ASSUM(X_CHOOSE_TAC `a:A` o
     REWRITE_RULE[GSYM MEMBER_NOT_EMPTY]) THEN
    SUBGOAL_THEN
      `!b. ?xe. xe 0 = (a:A,&1) /\
                !n. xe(SUC n) = (if b(n) then r else l) (FST(xe n)) (SND(xe n)),
                                d (FST(xe n)) (SND(xe n))`
    MP_TAC THENL
     [GEN_TAC THEN
      W(ACCEPT_TAC o prove_recursive_functions_exist num_RECURSION o
          snd o dest_exists o snd);
      REWRITE_TAC[EXISTS_PAIR_FUN_THM; PAIR_EQ] THEN
      REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM; FORALL_AND_THM]] THEN
    MAP_EVERY X_GEN_TAC
     [`x:(num->bool)->num->A`; `r:(num->bool)->num->real`] THEN
    STRIP_TAC THEN
    SUBGOAL_THEN `mcomplete (submetric m s:A metric)` MP_TAC THENL
     [MATCH_MP_TAC CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE THEN
      ASM_REWRITE_TAC[CLOSED_IN_CONTAINS_DERIVED_SET; TOPSPACE_MTOPOLOGY] THEN
      ASM SET_TAC[];
      REWRITE_TAC[MCOMPLETE_NEST_SING]] THEN
    DISCH_THEN(MP_TAC o MATCH_MP MONO_FORALL o GEN `b:num->bool` o
      SPEC `\n. mcball (submetric m s)
                       ((x:(num->bool)->num->A) b n,r b n)`) THEN
    REWRITE_TAC[SKOLEM_THM] THEN
    SUBGOAL_THEN `(!b n. (x:(num->bool)->num->A) b n IN s) /\
                  (!b n. &0 < (r:(num->bool)->num->real) b n)`
    STRIP_ASSUME_TAC THENL
     [REWRITE_TAC[AND_FORALL_THM] THEN GEN_TAC THEN
      INDUCT_TAC THEN ASM_REWRITE_TAC[REAL_LT_01] THEN ASM_MESON_TAC[];
      ALL_TAC] THEN
    SUBGOAL_THEN `(!b n. (x:(num->bool)->num->A) b n IN mspace m)`
    ASSUME_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
    ANTS_TAC THENL
     [X_GEN_TAC `b:num->bool` THEN REWRITE_TAC[CLOSED_IN_MCBALL] THEN
      ASM_REWRITE_TAC[MCBALL_EQ_EMPTY; SUBMETRIC; IN_INTER] THEN
      ASM_SIMP_TAC[REAL_ARITH `&0 < x ==> ~(x < &0)`] THEN CONJ_TAC THENL
       [MATCH_MP_TAC TRANSITIVE_STEPWISE_LE THEN
        REPEAT(CONJ_TAC THENL [SET_TAC[]; ALL_TAC]) THEN
        ASM_REWRITE_TAC[MCBALL_SUBMETRIC_EQ] THEN ASM SET_TAC[];
        X_GEN_TAC `e:real` THEN DISCH_TAC THEN
        MP_TAC(ISPECL [`inv(&2)`; `e:real`] REAL_ARCH_POW_INV) THEN
        ASM_REWRITE_TAC[REAL_POW_INV] THEN CONV_TAC REAL_RAT_REDUCE_CONV THEN
        MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `n:num` THEN
        DISCH_TAC THEN EXISTS_TAC `(x:(num->bool)->num->A) b n` THEN
        MATCH_MP_TAC MCBALL_SUBSET_CONCENTRIC THEN
        TRANS_TAC REAL_LE_TRANS `inv(&2 pow n)` THEN
        ASM_SIMP_TAC[REAL_LT_IMP_LE] THEN
        SPEC_TAC(`n:num`,`n:num`) THEN
        MATCH_MP_TAC num_INDUCTION THEN ASM_REWRITE_TAC[real_pow] THEN
        CONV_TAC REAL_RAT_REDUCE_CONV THEN REWRITE_TAC[REAL_INV_MUL] THEN
        GEN_TAC THEN MATCH_MP_TAC(REAL_ARITH
         `d < e / &2 ==> e <= i ==> d <= inv(&2) * i`) THEN
        ASM_SIMP_TAC[]];
      REWRITE_TAC[SKOLEM_THM; le_c; IN_UNIV] THEN
      MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `z:(num->bool)->A` THEN
      SIMP_TAC[SUBMETRIC; IN_INTER; FORALL_AND_THM] THEN STRIP_TAC THEN
      MAP_EVERY X_GEN_TAC [`b:num->bool`; `c:num->bool`] THEN
      GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN
      REWRITE_TAC[FUN_EQ_THM; NOT_FORALL_THM] THEN
      GEN_REWRITE_TAC LAND_CONV [num_WOP] THEN
      REWRITE_TAC[LEFT_IMP_EXISTS_THM; TAUT `~(p <=> q) <=> p <=> ~q`] THEN
      X_GEN_TAC `n:num` THEN REPEAT STRIP_TAC THEN FIRST_ASSUM(MP_TAC o
        GEN_REWRITE_RULE (BINDER_CONV o LAND_CONV) [INTERS_GSPEC]) THEN
      DISCH_THEN(fun th ->
       MP_TAC(SPEC `c:num->bool` th) THEN MP_TAC(SPEC `b:num->bool` th)) THEN
      ASM_REWRITE_TAC[TAUT `p ==> ~q <=> ~(p /\ q)`] THEN
      DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
       `s = {a} /\ t = {a} ==> a IN s INTER t`)) THEN
      REWRITE_TAC[IN_INTER; IN_ELIM_THM; AND_FORALL_THM] THEN
      DISCH_THEN(MP_TAC o SPEC `SUC n`) THEN ASM_REWRITE_TAC[COND_SWAP] THEN
      SUBGOAL_THEN
       `(x:(num->bool)->num->A) b n = x c n /\
        (r:(num->bool)->num->real) b n = r c n`
       (CONJUNCTS_THEN SUBST1_TAC)
      THENL
       [UNDISCH_TAC `!m:num. m < n ==> (b m <=> c m)` THEN
        SPEC_TAC(`n:num`,`p:num`) THEN
        INDUCT_TAC THEN ASM_SIMP_TAC[LT_SUC_LE; LE_REFL; LT_IMP_LE];
        COND_CASES_TAC THEN ASM_REWRITE_TAC[MCBALL_SUBMETRIC_EQ; IN_INTER] THEN
        ASM SET_TAC[]]];

    SUBGOAL_THEN
     `!top:A topology.
          locally_compact_space top /\ hausdorff_space top /\
          top derived_set_of topspace top = topspace top /\ ~(topspace top = {})
          ==> (:real) <=_c topspace top`
    ASSUME_TAC THENL
     [REPEAT STRIP_TAC;
      MAP_EVERY X_GEN_TAC [`top:A topology`; `s:A->bool`] THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `subtopology top (s:A->bool)`) THEN
      SUBGOAL_THEN `(s:A->bool) SUBSET topspace top` ASSUME_TAC THENL
       [ASM_MESON_TAC[DERIVED_SET_OF_SUBSET_TOPSPACE]; ALL_TAC] THEN
      ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; HAUSDORFF_SPACE_SUBTOPOLOGY;
                   DERIVED_SET_OF_SUBTOPOLOGY; SET_RULE `s INTER s = s`;
                   SET_RULE `s SUBSET u ==> u INTER s = s`] THEN
      DISCH_THEN MATCH_MP_TAC THEN
      MATCH_MP_TAC LOCALLY_COMPACT_SPACE_CLOSED_SUBSET THEN
      ASM_REWRITE_TAC[CLOSED_IN_CONTAINS_DERIVED_SET; SUBSET_REFL]] THEN
    TRANS_TAC CARD_LE_TRANS `(:num->bool)` THEN
    SIMP_TAC[CARD_EQ_REAL; CARD_EQ_IMP_LE] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    DISCH_THEN(X_CHOOSE_TAC `z:A`) THEN
    FIRST_ASSUM(MP_TAC o SPEC `z:A` o REWRITE_RULE[locally_compact_space]) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
    SUBGOAL_THEN `~(u:A->bool = {})` ASSUME_TAC THENL
     [ASM SET_TAC[];
      REPEAT(FIRST_X_ASSUM(K ALL_TAC o check (free_in `z:A`) o concl))] THEN
    SUBGOAL_THEN
     `!c. closed_in top c /\ c SUBSET k /\ ~(top interior_of c = {})
          ==> ?d e. closed_in top d /\ d SUBSET k /\
                    ~(top interior_of d = {}) /\
                    closed_in top e /\ e SUBSET k /\
                    ~(top interior_of e = {}) /\
                    DISJOINT d e /\ d SUBSET c /\ e SUBSET (c:A->bool)`
    MP_TAC THENL
     [REPEAT STRIP_TAC THEN
      UNDISCH_TAC `~(top interior_of c:A->bool = {})` THEN
      ASM_REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
      X_GEN_TAC `z:A` THEN DISCH_TAC THEN
      SUBGOAL_THEN `(z:A) IN topspace top` ASSUME_TAC THENL
       [ASM_MESON_TAC[SUBSET; INTERIOR_OF_SUBSET_TOPSPACE]; ALL_TAC] THEN
      MP_TAC(ISPECL [`top:A topology`; `topspace top:A->bool`]
            DERIVED_SET_OF_INFINITE_OPEN_IN) THEN
      ASM_REWRITE_TAC[] THEN DISCH_THEN(MP_TAC o AP_TERM `\s. (z:A) IN s`) THEN
      ASM_REWRITE_TAC[IN_ELIM_THM] THEN
      DISCH_THEN(MP_TAC o SPEC `top interior_of c:A->bool`) THEN
      ASM_SIMP_TAC[OPEN_IN_INTERIOR_OF; INTERIOR_OF_SUBSET_TOPSPACE;
                   SET_RULE `s SUBSET u ==> u INTER s = s`] THEN
      DISCH_THEN(MP_TAC o MATCH_MP (MESON[INFINITE; FINITE_SING; FINITE_SUBSET]
        `INFINITE s ==> !a. ~(s SUBSET {a})`)) THEN
      DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
       `(!a. ~(s SUBSET {a})) ==> ?a b. a IN s /\ b IN s /\ ~(a = b)`)) THEN
      REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
      MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
      SUBGOAL_THEN `(x:A) IN topspace top /\ y IN topspace top`
      STRIP_ASSUME_TAC THENL
       [ASM_MESON_TAC[SUBSET; INTERIOR_OF_SUBSET_TOPSPACE]; ALL_TAC] THEN
      FIRST_ASSUM(MP_TAC o SPECL [`x:A`; `y:A`] o
        REWRITE_RULE[hausdorff_space]) THEN
      ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
      MAP_EVERY X_GEN_TAC [`v:A->bool`; `w:A->bool`] THEN STRIP_TAC THEN
      MP_TAC(ISPEC `top:A topology`
        LOCALLY_COMPACT_HAUSDORFF_IMP_REGULAR_SPACE) THEN
      ASM_REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN
      REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN DISCH_THEN(fun th ->
        MP_TAC(SPECL [`top interior_of c INTER w:A->bool`; `y:A`] th) THEN
        MP_TAC(SPECL [`top interior_of c INTER v:A->bool`; `x:A`] th)) THEN
      ASM_SIMP_TAC[IN_INTER; OPEN_IN_INTER; OPEN_IN_INTERIOR_OF] THEN
      REWRITE_TAC[LEFT_IMP_EXISTS_THM; SUBSET_INTER] THEN
      MAP_EVERY X_GEN_TAC [`m:A->bool`; `d:A->bool`] THEN STRIP_TAC THEN
      MAP_EVERY X_GEN_TAC [`n:A->bool`; `e:A->bool`] THEN STRIP_TAC THEN
      MAP_EVERY EXISTS_TAC [`d:A->bool`; `e:A->bool`] THEN
      ASM_REWRITE_TAC[] THEN ONCE_REWRITE_TAC[TAUT
       `p /\ q /\ r /\ s /\ t <=> (q /\ s) /\ p /\ r /\ t`] THEN
      CONJ_TAC THENL
       [CONJ_TAC THENL [EXISTS_TAC `x:A`; EXISTS_TAC `y:A`] THEN
        REWRITE_TAC[interior_of; IN_ELIM_THM] THEN ASM_MESON_TAC[];
        MP_TAC(ISPECL [`top:A topology`; `c:A->bool`] INTERIOR_OF_SUBSET) THEN
        ASM SET_TAC[]];
      ALL_TAC] THEN
    REWRITE_TAC[RIGHT_IMP_EXISTS_THM; SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`l:(A->bool)->A->bool`; `r:(A->bool)->A->bool`] THEN
    DISCH_TAC THEN
    SUBGOAL_THEN
     `!b. ?d:num->A->bool.
          d 0 = k /\
          (!n. d(SUC n) = (if b(n) then r else l) (d n))`
    MP_TAC THENL
     [GEN_TAC THEN
      W(ACCEPT_TAC o prove_recursive_functions_exist num_RECURSION o
          snd o dest_exists o snd);
      REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM; FORALL_AND_THM]] THEN
    X_GEN_TAC `d:(num->bool)->num->A->bool` THEN STRIP_TAC THEN
    SUBGOAL_THEN
     `!b n. closed_in top (d b n) /\ d b n SUBSET k /\
            ~(top interior_of ((d:(num->bool)->num->A->bool) b n) = {})`
    MP_TAC THENL
     [GEN_TAC THEN INDUCT_TAC THENL
       [ASM_SIMP_TAC[SUBSET_REFL; COMPACT_IN_IMP_CLOSED_IN] THEN
        FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
         `~(u = {}) ==> u SUBSET i ==> ~(i = {})`)) THEN
        ASM_SIMP_TAC[INTERIOR_OF_MAXIMAL_EQ];
        ASM_REWRITE_TAC[] THEN COND_CASES_TAC THEN ASM_SIMP_TAC[]];
      REWRITE_TAC[FORALL_AND_THM] THEN STRIP_TAC] THEN
    SUBGOAL_THEN
     `!b. ~(INTERS {(d:(num->bool)->num->A->bool) b n | n IN (:num)} = {})`
    MP_TAC THENL
     [X_GEN_TAC `b:num->bool` THEN MATCH_MP_TAC COMPACT_SPACE_IMP_NEST THEN
      EXISTS_TAC `subtopology top (k:A->bool)` THEN
      ASM_SIMP_TAC[CLOSED_IN_SUBSET_TOPSPACE; COMPACT_SPACE_SUBTOPOLOGY] THEN
      CONJ_TAC THENL [ASM_MESON_TAC[INTERIOR_OF_EMPTY]; ALL_TAC] THEN
      MATCH_MP_TAC TRANSITIVE_STEPWISE_LE THEN
      REPEAT(CONJ_TAC THENL [SET_TAC[]; ALL_TAC]) THEN
      ASM_SIMP_TAC[] THEN GEN_TAC THEN COND_CASES_TAC THEN
      ASM_SIMP_TAC[];
      REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
    X_GEN_TAC `x:(num->bool)->A` THEN
    REWRITE_TAC[INTERS_GSPEC; IN_ELIM_THM; IN_UNIV] THEN DISCH_TAC THEN
    REWRITE_TAC[le_c; IN_UNIV] THEN EXISTS_TAC `x:(num->bool)->A` THEN
    CONJ_TAC THENL [ASM_MESON_TAC[CLOSED_IN_SUBSET; SUBSET]; ALL_TAC] THEN
    MAP_EVERY X_GEN_TAC [`b:num->bool`; `c:num->bool`] THEN
    GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN
    REWRITE_TAC[FUN_EQ_THM; NOT_FORALL_THM] THEN
    GEN_REWRITE_TAC LAND_CONV [num_WOP] THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM; TAUT `~(p <=> q) <=> p <=> ~q`] THEN
    X_GEN_TAC `n:num` THEN REPEAT STRIP_TAC THEN
    SUBGOAL_THEN
     `DISJOINT ((d:(num->bool)->num->A->bool) b (SUC n)) (d c (SUC n))`
    MP_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
    ASM_SIMP_TAC[COND_SWAP] THEN
    SUBGOAL_THEN `(d:(num->bool)->num->A->bool) b n = d c n` SUBST1_TAC THENL
     [ALL_TAC; ASM_MESON_TAC[DISJOINT_SYM]] THEN
    UNDISCH_TAC `!m:num. m < n ==> (b m <=> c m)` THEN
    SPEC_TAC(`n:num`,`p:num`) THEN
    INDUCT_TAC THEN ASM_SIMP_TAC[LT_SUC_LE; LE_REFL; LT_IMP_LE]]);;

(* ------------------------------------------------------------------------- *)
(* Pointwise continuity in topological spaces.                               *)
(* ------------------------------------------------------------------------- *)

let topcontinuous_at = new_definition
  `!top top' f:A->B x.
     topcontinuous_at top top' f x <=>
     x IN topspace top /\
     (!x. x IN topspace top ==> f x IN topspace top') /\
     (!v. open_in top' v /\ f x IN v
          ==> (?u. open_in top u /\ x IN u /\ (!y. y IN u ==> f y IN v)))`;;

let TOPCONTINUOUS_AT_ATPOINTOF = prove
 (`!top top' f:A->B x.
        topcontinuous_at top top' f x <=>
        x IN topspace top /\
        (!x. x IN topspace top ==> f x IN topspace top') /\
        limit top' f (f x) (atpointof top x)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[topcontinuous_at] THEN
  MATCH_MP_TAC(TAUT
   `(p /\ q ==> (r <=> s)) ==> (p /\ q /\ r <=> p /\ q /\ s)`) THEN
  STRIP_TAC THEN ASM_SIMP_TAC[LIMIT_ATPOINTOF] THEN
  AP_TERM_TAC THEN ABS_TAC THEN SET_TAC[]);;

let CONTINUOUS_MAP_EQ_TOPCONTINUOUS_AT = prove
 (`!top top' f:A->B.
     continuous_map (top,top')  f <=>
     (!x. x IN topspace top ==> topcontinuous_at top top' f x)`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
  [SIMP_TAC[continuous_map; topcontinuous_at] THEN
   INTRO_TAC "f v; !x; x; !v; v1 v2" THEN
   REMOVE_THEN "v" (MP_TAC o C MATCH_MP
     (ASSUME `open_in top' (v:B->bool)`)) THEN
   INTRO_TAC "pre" THEN
   EXISTS_TAC `{x:A | x IN topspace top /\ f x:B IN v}` THEN
   ASM_SIMP_TAC[IN_ELIM_THM];
   ALL_TAC] THEN
  SIMP_TAC[continuous_map; topcontinuous_at; SUBSET] THEN
  INTRO_TAC "hp1" THEN CONJ_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
  INTRO_TAC "![v]; v" THEN ONCE_REWRITE_TAC[OPEN_IN_SUBOPEN] THEN
  REWRITE_TAC[IN_ELIM_THM] THEN INTRO_TAC "!x; x1 x2" THEN
  REMOVE_THEN "hp1" (MP_TAC o SPEC `x:A`) THEN ASM_SIMP_TAC[] THEN
  INTRO_TAC "x3 v1" THEN REMOVE_THEN "v1" (MP_TAC o SPEC `v:B->bool`) THEN
  USE_THEN "x1" (LABEL_TAC "x4" o REWRITE_RULE[IN_ELIM_THM]) THEN
  ASM_SIMP_TAC[] THEN INTRO_TAC "@u. u1 u2 u3" THEN
  EXISTS_TAC `u:A->bool` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[SUBSET; IN_ELIM_THM] THEN
  ASM_MESON_TAC[OPEN_IN_SUBSET; SUBSET]);;

let CONTINUOUS_MAP_ATPOINTOF = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f <=>
        !x. x IN topspace top ==> limit top' f (f x) (atpointof top x)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[CONTINUOUS_MAP_EQ_TOPCONTINUOUS_AT] THEN
  ASM_SIMP_TAC[TOPCONTINUOUS_AT_ATPOINTOF] THEN
  REWRITE_TAC[limit] THEN SET_TAC[]);;

let LIMIT_CONTINUOUS_MAP = prove
 (`!top top' (f:A->B) a b.
        continuous_map(top,top') f /\ a IN topspace top /\ f a = b
        ==> limit top' f b (atpointof top a)`,
  REWRITE_TAC[CONTINUOUS_MAP_ATPOINTOF] THEN MESON_TAC[]);;

let LIMIT_CONTINUOUS_MAP_WITHIN = prove
 (`!top top' (f:A->B) a b.
        continuous_map(subtopology top s,top') f /\
        a IN s /\ a IN topspace top /\ f a = b
        ==> limit top' f b (atpointof top a within s)`,
  SIMP_TAC[GSYM ATPOINTOF_SUBTOPOLOGY] THEN
  SIMP_TAC[LIMIT_CONTINUOUS_MAP; TOPSPACE_SUBTOPOLOGY; IN_INTER]);;

(* ------------------------------------------------------------------------- *)
(* "Pasting lemma" variants and continuity from casewise definitions.        *)
(* ------------------------------------------------------------------------- *)

let PASTING_LEMMA = prove
 (`!top top' (f:K->A->B) g t k.
        (!i. i IN k
             ==> open_in top (t i) /\
                 continuous_map(subtopology top (t i),top') (f i)) /\
        (!i j x. i IN k /\ j IN k /\ x IN topspace top INTER t i INTER t j
                 ==> f i x = f j x) /\
        (!x. x IN topspace top ==> ?j. j IN k /\ x IN t j /\ g x = f j x)
        ==> continuous_map(top,top') g`,
  REPEAT GEN_TAC THEN REWRITE_TAC[continuous_map; TOPSPACE_SUBTOPOLOGY] THEN
  ASM_CASES_TAC `!i. i IN k ==> (t:K->A->bool) i SUBSET topspace top` THENL
   [ALL_TAC; ASM_MESON_TAC[OPEN_IN_SUBSET]] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET t ==> t INTER s = s`] THEN STRIP_TAC THEN
  CONJ_TAC THENL [ASM SET_TAC[]; X_GEN_TAC `u:B->bool` THEN DISCH_TAC] THEN
  SUBGOAL_THEN
   `{x | x IN topspace top /\ g x IN u} =
    UNIONS {{x | x IN (t i) /\ ((f:K->A->B) i x) IN u} |
            i IN k}`
  SUBST1_TAC THENL
   [REWRITE_TAC[UNIONS_GSPEC] THEN ASM SET_TAC[];
    MATCH_MP_TAC OPEN_IN_UNIONS THEN REWRITE_TAC[FORALL_IN_GSPEC] THEN
    ASM_MESON_TAC[OPEN_IN_TRANS_FULL]]);;

let PASTING_LEMMA_EXISTS = prove
 (`!top top' (f:K->A->B) t k.
        topspace top SUBSET UNIONS {t i | i IN k} /\
        (!i. i IN k
             ==> open_in top (t i) /\
                 continuous_map(subtopology top (t i),top') (f i)) /\
        (!i j x. i IN k /\ j IN k /\ x IN topspace top INTER t i INTER t j
                 ==> f i x = f j x)
        ==> ?g. continuous_map(top,top') g /\
                !x i. i IN k /\ x IN topspace top INTER t i ==> g x = f i x`,
  REPEAT STRIP_TAC THEN
  EXISTS_TAC `\x. (f:K->A->B)(@i. i IN k /\ x IN t i) x` THEN CONJ_TAC THENL
   [MATCH_MP_TAC PASTING_LEMMA THEN
    MAP_EVERY EXISTS_TAC [`f:K->A->B`; `t:K->A->bool`; `k:K->bool`] THEN
    ASM SET_TAC[];
    RULE_ASSUM_TAC(REWRITE_RULE[OPEN_IN_CLOSED_IN_EQ]) THEN ASM SET_TAC[]]);;

let PASTING_LEMMA_LOCALLY_FINITE = prove
 (`!top top' (f:K->A->B) g t k.
        (!x. x IN topspace top
             ==> ?v. open_in top v /\ x IN v /\
                     FINITE {i | i IN k /\ ~(t i INTER v = {})}) /\
        (!i. i IN k
             ==> closed_in top (t i) /\
                 continuous_map(subtopology top (t i),top') (f i)) /\
        (!i j x. i IN k /\ j IN k /\ x IN topspace top INTER t i INTER t j
                 ==> f i x = f j x) /\
        (!x. x IN topspace top ==> ?j. j IN k /\ x IN t j /\ g x = f j x)
        ==> continuous_map(top,top') g`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN; TOPSPACE_SUBTOPOLOGY] THEN
  ASM_CASES_TAC `!i. i IN k ==> (t:K->A->bool) i SUBSET topspace top` THENL
   [ALL_TAC; ASM_MESON_TAC[CLOSED_IN_SUBSET]] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET t ==> t INTER s = s`] THEN STRIP_TAC THEN
  CONJ_TAC THENL [ASM SET_TAC[]; X_GEN_TAC `u:B->bool` THEN DISCH_TAC] THEN
  SUBGOAL_THEN
   `{x | x IN topspace top /\ g x IN u} =
    UNIONS {{x | x IN (t i) /\ ((f:K->A->B) i x) IN u} |
            i IN k}`
  SUBST1_TAC THENL
   [REWRITE_TAC[UNIONS_GSPEC] THEN ASM SET_TAC[];
    MATCH_MP_TAC CLOSED_IN_LOCALLY_FINITE_UNIONS THEN
    REWRITE_TAC[FORALL_IN_GSPEC] THEN
    CONJ_TAC THENL [ASM_MESON_TAC[CLOSED_IN_TRANS_FULL]; ALL_TAC] THEN
    REWRITE_TAC[SET_RULE
     `{y | y IN {f x | x IN s} /\ P y} = IMAGE f {x | x IN s /\ P(f x)}`] THEN
    X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(fun th -> MP_TAC(SPEC `x:A` th) THEN
        ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_EXISTS) THEN
    X_GEN_TAC `v:A->bool` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC FINITE_IMAGE THEN
    FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ]
        FINITE_SUBSET)) THEN
    SET_TAC[]]);;

let PASTING_LEMMA_EXISTS_LOCALLY_FINITE = prove
 (`!top top' (f:K->A->B) t k.
        (!x. x IN topspace top
             ==> ?v. open_in top v /\ x IN v /\
                     FINITE {i | i IN k /\ ~(t i INTER v = {})}) /\
        topspace top SUBSET UNIONS {t i | i IN k} /\
        (!i. i IN k
             ==> closed_in top (t i) /\
                 continuous_map(subtopology top (t i),top') (f i)) /\
        (!i j x. i IN k /\ j IN k /\ x IN topspace top INTER t i INTER t j
                 ==> f i x = f j x)
        ==> ?g. continuous_map(top,top') g /\
                !x i. i IN k /\ x IN topspace top INTER t i ==> g x = f i x`,
  REPEAT STRIP_TAC THEN
  EXISTS_TAC `\x. (f:K->A->B)(@i. i IN k /\ x IN t i) x` THEN CONJ_TAC THENL
   [MATCH_MP_TAC PASTING_LEMMA_LOCALLY_FINITE THEN
    MAP_EVERY EXISTS_TAC [`f:K->A->B`; `t:K->A->bool`; `k:K->bool`] THEN
    ASM SET_TAC[];
    RULE_ASSUM_TAC(REWRITE_RULE[closed_in]) THEN ASM SET_TAC[]]);;

let PASTING_LEMMA_CLOSED = prove
 (`!top top' (f:K->A->B) g t k.
        FINITE k /\
        (!i. i IN k
             ==> closed_in top (t i) /\
                 continuous_map(subtopology top (t i),top') (f i)) /\
        (!i j x. i IN k /\ j IN k /\ x IN topspace top INTER t i INTER t j
                 ==> f i x = f j x) /\
        (!x. x IN topspace top ==> ?j. j IN k /\ x IN t j /\ g x = f j x)
        ==> continuous_map(top,top') g`,
  MP_TAC PASTING_LEMMA_LOCALLY_FINITE THEN
  REPEAT(MATCH_MP_TAC MONO_FORALL THEN GEN_TAC) THEN
  MATCH_MP_TAC MONO_IMP THEN SIMP_TAC[FINITE_RESTRICT] THEN
  MESON_TAC[OPEN_IN_TOPSPACE]);;

let PASTING_LEMMA_EXISTS_CLOSED = prove
 (`!top top' (f:K->A->B) t k.
        FINITE k /\
        topspace top SUBSET UNIONS {t i | i IN k} /\
        (!i. i IN k
             ==> closed_in top (t i) /\
                 continuous_map(subtopology top (t i),top') (f i)) /\
        (!i j x. i IN k /\ j IN k /\ x IN topspace top INTER t i INTER t j
                 ==> f i x = f j x)
        ==> ?g. continuous_map(top,top') g /\
                !x i. i IN k /\ x IN topspace top INTER t i ==> g x = f i x`,
  MP_TAC PASTING_LEMMA_EXISTS_LOCALLY_FINITE THEN
  REPEAT(MATCH_MP_TAC MONO_FORALL THEN GEN_TAC) THEN
  MATCH_MP_TAC MONO_IMP THEN SIMP_TAC[FINITE_RESTRICT] THEN
  MESON_TAC[OPEN_IN_TOPSPACE]);;

let CONTINUOUS_MAP_CASES = prove
 (`!top top' P f g:A->B.
        continuous_map (subtopology top (top closure_of {x | P x}),top') f /\
        continuous_map (subtopology top (top closure_of {x | ~P x}),top') g /\
        (!x. x IN top frontier_of {x | P x} ==> f x = g x)
        ==> continuous_map (top,top') (\x. if P x then f x else g x)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[FRONTIER_OF_CLOSURES] THEN
  REWRITE_TAC[SET_RULE `u DIFF {x | P x} = u INTER {x | ~P x}`] THEN
  REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT] THEN STRIP_TAC THEN
  MP_TAC(ISPECL
   [`top:A topology`; `top':B topology`;
    `\p. if p then (f:A->B) else g`;
    `\x. if P x then (f:A->B) x else g x`;
    `\p. if p then top closure_of {x:A | P x}
              else top closure_of {x | ~P x}`;
    `{T,F}`] PASTING_LEMMA_CLOSED) THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[EXISTS_IN_INSERT; FORALL_IN_INSERT; NOT_IN_EMPTY] THEN
  ASM_REWRITE_TAC[FINITE_INSERT; CLOSED_IN_CLOSURE_OF; FINITE_EMPTY] THEN
  ANTS_TAC THENL [ASM SET_TAC[]; DISCH_THEN MATCH_MP_TAC] THEN
  MP_TAC(ISPECL [`top:A topology`; `topspace top INTER {x:A | P x}`]
        CLOSURE_OF_SUBSET) THEN
  MP_TAC(ISPECL [`top:A topology`; `topspace top INTER {x:A | ~P x}`]
        CLOSURE_OF_SUBSET) THEN
  REWRITE_TAC[INTER_SUBSET; GSYM CLOSURE_OF_RESTRICT] THEN
  ASM SET_TAC[]);;

let CONTINUOUS_MAP_CASES_ALT = prove
 (`!top top' P f g:A->B.
        continuous_map (subtopology top
         (top closure_of {x | x IN topspace top /\ P x}),top') f /\
        continuous_map (subtopology top
         (top closure_of {x | x IN topspace top /\ ~P x}),top') g /\
        (!x. x IN top frontier_of {x | x IN topspace top /\ P x} ==> f x = g x)
        ==> continuous_map (top,top') (\x. if P x then f x else g x)`,
  REWRITE_TAC[SET_RULE `{x | x IN s /\ P x} = s INTER {x | P x}`] THEN
  REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT; GSYM FRONTIER_OF_RESTRICT] THEN
  REWRITE_TAC[CONTINUOUS_MAP_CASES]);;

let CONTINUOUS_MAP_CASES_FUNCTION = prove
 (`!top top' top'' (p:A->C) f (g:A->B) u.
        continuous_map (top,top'') p /\
        continuous_map (subtopology top
         {x | x IN topspace top /\ p x IN top'' closure_of u},top') f /\
        continuous_map (subtopology top
         {x | x IN topspace top /\
              p x IN top'' closure_of (topspace top'' DIFF u)},top') g /\
        (!x. x IN topspace top /\ p x IN top'' frontier_of u ==> f x = g x)
        ==> continuous_map (top,top') (\x. if p x IN u then f x else g x)`,
  REPEAT STRIP_TAC THEN
  MATCH_MP_TAC CONTINUOUS_MAP_CASES_ALT THEN REPEAT CONJ_TAC THENL
   [MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY_MONO THEN
    EXISTS_TAC
     `{x | x IN topspace top /\ (p:A->C) x IN top'' closure_of u}` THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_CLOSURE_PREIMAGE_SUBSET];
    MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY_MONO THEN
    EXISTS_TAC
     `{x | x IN topspace top /\
           (p:A->C) x IN top'' closure_of (topspace top'' DIFF u)}` THEN
    ASM_REWRITE_TAC[] THEN
    W(MP_TAC o PART_MATCH (rand o rand)
      CONTINUOUS_MAP_CLOSURE_PREIMAGE_SUBSET o rand o snd) THEN
    ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] SUBSET_TRANS) THEN
    MATCH_MP_TAC CLOSURE_OF_MONO THEN
    RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[];
    GEN_TAC THEN
    FIRST_ASSUM(MP_TAC o SPEC `u:C->bool` o  MATCH_MP
      CONTINUOUS_MAP_FRONTIER_FRONTIER_PREIMAGE_SUBSET) THEN
    ASM SET_TAC[]]);;

let CONTINUOUS_MAP_SEPARATED_UNION = prove
 (`!top top' (f:A->B) s t.
        continuous_map (subtopology top s,top') f /\
        continuous_map (subtopology top t,top') f /\
        DISJOINT s (top closure_of t) /\
        DISJOINT t (top closure_of s)
        ==> continuous_map (subtopology top (s UNION t),top') f`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL
   [`subtopology top (s UNION t:A->bool)`;
    `top':B topology`;
    `\x:A. x IN s`;
     `f:A->B`; `f:A->B`] CONTINUOUS_MAP_CASES) THEN
  REWRITE_TAC[COND_ID; ETA_AX] THEN DISCH_THEN MATCH_MP_TAC THEN
  CONJ_TAC THEN MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY_MONO THENL
   [EXISTS_TAC `s:A->bool`; EXISTS_TAC `t:A->bool`] THEN
  ASM_REWRITE_TAC[CLOSURE_OF_SUBTOPOLOGY; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  ASM_REWRITE_TAC[IN_GSPEC; SET_RULE `(s UNION t) INTER s = s`] THEN
  ASM_REWRITE_TAC[SET_RULE `(s UNION t) INTER t = t`] THENL
   [ASM SET_TAC[]; ALL_TAC] THEN
  TRANS_TAC SUBSET_TRANS `(s UNION t) INTER top closure_of t:A->bool` THEN
  CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
  MATCH_MP_TAC(SET_RULE `t SUBSET u ==> (s INTER t) SUBSET (s INTER u)`) THEN
  MATCH_MP_TAC CLOSURE_OF_MONO THEN ASM SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Continuity via bases/subbases, hence upper and lower semicontinuity.      *)
(* ------------------------------------------------------------------------- *)

let CONTINUOUS_MAP_INTO_TOPOLOGY_BASE = prove
 (`!top top' b f:A->B.
        open_in top' = ARBITRARY UNION_OF b /\
        (!x. x IN topspace top ==> f x IN topspace top') /\
        (!u. u IN b ==> open_in top {x | x IN topspace top /\ f x IN u})
        ==> continuous_map(top,top') f`,
  let lemma = prove
   (`{x | P x /\ f x IN UNIONS u} =
     UNIONS {{x | P x /\ f x IN b} | b IN u}`,
    REWRITE_TAC[UNIONS_GSPEC] THEN SET_TAC[]) in
  REPEAT STRIP_TAC THEN REWRITE_TAC[continuous_map] THEN
  ASM_REWRITE_TAC[FORALL_UNION_OF; ARBITRARY] THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[lemma] THEN
  MATCH_MP_TAC OPEN_IN_UNIONS THEN ASM SET_TAC[]);;

let CONTINUOUS_MAP_INTO_TOPOLOGY_BASE_EQ = prove
 (`!top top' b f:A->B.
      open_in top' = ARBITRARY UNION_OF b
      ==> (continuous_map(top,top') f <=>
           (!x. x IN topspace top ==> f x IN topspace top') /\
           (!u. u IN b ==> open_in top {x | x IN topspace top /\ f x IN u}))`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [REWRITE_TAC[continuous_map] THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[] THEN REPEAT STRIP_TAC THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN ASM SET_TAC[];
    POP_ASSUM MP_TAC THEN REWRITE_TAC[GSYM IMP_CONJ] THEN
    REWRITE_TAC[CONTINUOUS_MAP_INTO_TOPOLOGY_BASE]]);;

let CONTINUOUS_MAP_INTO_TOPOLOGY_SUBBASE = prove
 (`!top top' b u f:A->B.
        topology(ARBITRARY UNION_OF (FINITE INTERSECTION_OF b relative_to u)) =
        top' /\
        (!x. x IN topspace top ==> f x IN topspace top') /\
        (!u. u IN b ==> open_in top {x | x IN topspace top /\ f x IN u})
        ==> continuous_map(top,top') f`,
  let lemma = prove
   (`{x | P x /\ f x IN INTERS(a INSERT u)} =
     INTERS {{x | P x /\ f x IN b} | b IN (a INSERT u)}`,
    REWRITE_TAC[INTERS_GSPEC; INTERS_INSERT] THEN SET_TAC[]) in
  REPEAT STRIP_TAC THEN MATCH_MP_TAC CONTINUOUS_MAP_INTO_TOPOLOGY_BASE THEN
  EXISTS_TAC `(FINITE INTERSECTION_OF b relative_to u):(B->bool)->bool` THEN
  EXPAND_TAC "top'" THEN REWRITE_TAC[OPEN_IN_SUBBASE; FUN_EQ_THM] THEN
  ASM_REWRITE_TAC[] THEN
  GEN_REWRITE_TAC (BINDER_CONV o LAND_CONV o ONCE_DEPTH_CONV) [IN] THEN
  REWRITE_TAC[FORALL_RELATIVE_TO; FORALL_INTERSECTION_OF] THEN
  REWRITE_TAC[GSYM INTERS_INSERT; lemma] THEN
  REPEAT STRIP_TAC THEN MATCH_MP_TAC OPEN_IN_INTERS THEN
  ASM_SIMP_TAC[SIMPLE_IMAGE; FINITE_IMAGE; FINITE_INSERT] THEN
  REWRITE_TAC[IMAGE_EQ_EMPTY; NOT_INSERT_EMPTY; FORALL_IN_IMAGE] THEN
  REWRITE_TAC[FORALL_IN_INSERT] THEN
  FIRST_ASSUM(MP_TAC o AP_TERM `topspace:(B)topology->B->bool`) THEN
  REWRITE_TAC[TOPSPACE_SUBBASE] THEN DISCH_THEN SUBST1_TAC THEN
  ASM_SIMP_TAC[OPEN_IN_TOPSPACE; SET_RULE
    `(!x. x IN s ==> Q x) ==> {x | x IN s /\ Q x} = s`] THEN
  ASM SET_TAC[]);;

let CONTINUOUS_MAP_INTO_TOPOLOGY_SUBBASE_EQ = prove
 (`!top top' b u f:A->B.
      topology(ARBITRARY UNION_OF
                (FINITE INTERSECTION_OF b relative_to u)) = top'
      ==> (continuous_map(top,top') f <=>
           (!x. x IN topspace top ==> f x IN topspace top') /\
           (!u. u IN b ==> open_in top {x | x IN topspace top /\ f x IN u}))`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [REWRITE_TAC[continuous_map] THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    X_GEN_TAC `v:B->bool` THEN DISCH_TAC THEN
    SUBGOAL_THEN
     `{x | x IN topspace top /\ (f:A->B) x IN v} =
      {x | x IN topspace top /\ f x IN (u INTER v)}`
    SUBST1_TAC THENL
     [FIRST_ASSUM(MP_TAC o AP_TERM `topspace:(B)topology->B->bool`) THEN
      REWRITE_TAC[TOPSPACE_SUBBASE] THEN ASM SET_TAC[];
      FIRST_X_ASSUM MATCH_MP_TAC THEN EXPAND_TAC "top'" THEN
      REWRITE_TAC[OPEN_IN_SUBBASE] THEN
      MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN
      MATCH_MP_TAC RELATIVE_TO_INC THEN
      MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN ASM SET_TAC[]];
    POP_ASSUM MP_TAC THEN REWRITE_TAC[GSYM IMP_CONJ] THEN
    REWRITE_TAC[CONTINUOUS_MAP_INTO_TOPOLOGY_SUBBASE]]);;

let CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LT_GEN = prove
 (`!top u f:A->real.
         continuous_map (top,subtopology euclideanreal u) f <=>
         (!x. x IN topspace top ==> f x IN u) /\
         (!a. open_in top {x | x IN topspace top /\ f x > a}) /\
         (!a. open_in top {x | x IN topspace top /\ f x < a})`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[MATCH_MP CONTINUOUS_MAP_INTO_TOPOLOGY_SUBBASE_EQ
   (SPEC `u:real->bool` SUBBASE_SUBTOPOLOGY_EUCLIDEANREAL)] THEN
  REWRITE_TAC[FORALL_IN_UNION; FORALL_IN_GSPEC; IN_UNIV] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; IN_ELIM_THM]);;

let CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LT = prove
 (`!top f:A->real.
         continuous_map (top,euclideanreal) f <=>
         (!a. open_in top {x | x IN topspace top /\ f x > a}) /\
         (!a. open_in top {x | x IN topspace top /\ f x < a})`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC
   (LAND_CONV o LAND_CONV o RAND_CONV) [GSYM SUBTOPOLOGY_TOPSPACE] THEN
  REWRITE_TAC[CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LT_GEN] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; IN_UNIV]);;

let CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LE_GEN = prove
 (`!top u f:A->real.
         continuous_map (top,subtopology euclideanreal u) f <=>
         (!x. x IN topspace top ==> f x IN u) /\
         (!a. closed_in top {x | x IN topspace top /\ f x >= a}) /\
         (!a. closed_in top {x | x IN topspace top /\ f x <= a})`,
  REWRITE_TAC[REAL_ARITH `a >= b <=> ~(b > a)`; GSYM REAL_NOT_LT] THEN
  REWRITE_TAC[closed_in; SUBSET_RESTRICT] THEN
  REWRITE_TAC[SET_RULE `u DIFF {x | x IN u /\ ~P x} = {x | x IN u /\ P x}`;
              CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LT_GEN] THEN
  REWRITE_TAC[real_gt; CONJ_ACI]);;

let CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LE = prove
 (`!top f:A->real.
         continuous_map (top,euclideanreal) f <=>
         (!a. closed_in top {x | x IN topspace top /\ f x >= a}) /\
         (!a. closed_in top {x | x IN topspace top /\ f x <= a})`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC
   (LAND_CONV o LAND_CONV o RAND_CONV) [GSYM SUBTOPOLOGY_TOPSPACE] THEN
  REWRITE_TAC[CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LE_GEN] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; IN_UNIV]);;

let CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LTE_GEN = prove
 (`!top u f:A->real.
         continuous_map (top,subtopology euclideanreal u) f <=>
         (!x. x IN topspace top ==> f x IN u) /\
         (!a. open_in top {x | x IN topspace top /\ f x < a}) /\
         (!a. closed_in top {x | x IN topspace top /\ f x <= a})`,
  REWRITE_TAC[GSYM REAL_NOT_LT] THEN
  REWRITE_TAC[closed_in; SUBSET_RESTRICT] THEN
  REWRITE_TAC[SET_RULE `u DIFF {x | x IN u /\ ~P x} = {x | x IN u /\ P x}`;
              CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LT_GEN] THEN
  REWRITE_TAC[real_gt; CONJ_ACI]);;

let CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LTE = prove
 (`!top u f:A->real.
         continuous_map (top,euclideanreal) f <=>
         (!a. open_in top {x | x IN topspace top /\ f x < a}) /\
         (!a. closed_in top {x | x IN topspace top /\ f x <= a})`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC
   (LAND_CONV o LAND_CONV o RAND_CONV) [GSYM SUBTOPOLOGY_TOPSPACE] THEN
  REWRITE_TAC[CONTINUOUS_MAP_UPPER_LOWER_SEMICONTINUOUS_LTE_GEN] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; IN_UNIV]);;

(* ------------------------------------------------------------------------- *)
(* Continuous functions on metric spaces.                                    *)
(* ------------------------------------------------------------------------- *)

let METRIC_CONTINUOUS_MAP = prove
 (`!m m' f:A->B.
     continuous_map (mtopology m,mtopology m') f <=>
     (!x. x IN mspace m ==> f x IN mspace m') /\
     (!a e. &0 < e /\ a IN mspace m
            ==> (?d. &0 < d /\
                     (!x. x IN mspace m /\ mdist m (a,x) < d
                          ==> mdist m' (f a, f x) < e)))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[continuous_map; TOPSPACE_MTOPOLOGY] THEN
  EQ_TAC THEN SIMP_TAC[] THENL
  [INTRO_TAC "f cont; !a e; e a" THEN
   REMOVE_THEN "cont" (MP_TAC o SPEC `mball m' (f (a:A):B,e)`) THEN
   REWRITE_TAC[OPEN_IN_MBALL] THEN
   ASM_SIMP_TAC[OPEN_IN_MTOPOLOGY; SUBSET; IN_MBALL; IN_ELIM_THM] THEN
   DISCH_THEN (MP_TAC o SPEC `a:A`) THEN ASM_SIMP_TAC[MDIST_REFL];
   SIMP_TAC[OPEN_IN_MTOPOLOGY; SUBSET; IN_MBALL; IN_ELIM_THM] THEN
   ASM_MESON_TAC[]]);;

let CONTINUOUS_MAP_TO_METRIC = prove
 (`!t m f:A->B.
     continuous_map (t,mtopology m) f <=>
     (!x. x IN topspace t
          ==> (!r. &0 < r
                   ==> (?u. open_in t u /\
                            x IN u /\
                            (!y. y IN u ==> f y IN mball m (f x,r)))))`,
  INTRO_TAC "!t m f" THEN
  REWRITE_TAC[CONTINUOUS_MAP_EQ_TOPCONTINUOUS_AT; topcontinuous_at;
              TOPSPACE_MTOPOLOGY] THEN
  EQ_TAC THENL
  [INTRO_TAC "A; !x; x" THEN REMOVE_THEN "A" (MP_TAC o SPEC `x:A`) THEN
   ASM_SIMP_TAC[OPEN_IN_MBALL; CENTRE_IN_MBALL];
   INTRO_TAC "A; !x; x" THEN ASM_REWRITE_TAC[] THEN CONJ_TAC THENL
   [ASM_MESON_TAC[REAL_LT_01; IN_MBALL];
    ASM_MESON_TAC[OPEN_IN_MTOPOLOGY; SUBSET]]]);;

let CONTINUOUS_MAP_FROM_METRIC = prove
 (`!m top f:A->B.
        continuous_map (mtopology m,top) f <=>
        IMAGE f (mspace m) SUBSET topspace top /\
        !a. a IN mspace m
            ==> !u. open_in top u /\ f(a) IN u
                    ==> ?d. &0 < d /\
                            !x. x IN mspace m /\ mdist m (a,x) < d
                                ==> f x IN u`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CONTINUOUS_MAP; TOPSPACE_MTOPOLOGY] THEN
  ASM_CASES_TAC `IMAGE (f:A->B) (mspace m) SUBSET topspace top` THEN
  ASM_REWRITE_TAC[OPEN_IN_MTOPOLOGY] THEN EQ_TAC THEN DISCH_TAC THENL
   [X_GEN_TAC `a:A` THEN DISCH_TAC THEN
    X_GEN_TAC `u:B->bool` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `u:B->bool`) THEN
    ASM_REWRITE_TAC[] THEN DISCH_THEN(MP_TAC o SPEC `a:A` o CONJUNCT2) THEN
    ASM_REWRITE_TAC[IN_ELIM_THM; SUBSET; IN_MBALL] THEN MESON_TAC[];
    X_GEN_TAC `u:B->bool` THEN DISCH_TAC THEN
    REWRITE_TAC[SUBSET_RESTRICT; IN_ELIM_THM] THEN
    X_GEN_TAC `a:A` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `a:A`) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(MP_TAC o SPEC `u:B->bool`) THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[SUBSET; IN_MBALL; IN_ELIM_THM] THEN MESON_TAC[]]);;

let CONTINUOUS_MAP_UNIFORM_LIMIT = prove
 (`!net top m f:K->A->B g.
        ~trivial_limit net /\
        eventually (\n. continuous_map (top,mtopology m) (f n)) net /\
        (!e. &0 < e
             ==> eventually
                   (\n. !x. x IN topspace top
                            ==> g x IN mspace m /\ mdist m (f n x,g x) < e)
                 net)
        ==> continuous_map (top,mtopology m) g`,
  REPEAT GEN_TAC THEN REWRITE_TAC[CONTINUOUS_MAP_TO_METRIC] THEN
  DISCH_THEN(CONJUNCTS_THEN ASSUME_TAC) THEN X_GEN_TAC `x:A` THEN
  DISCH_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(CONJUNCTS_THEN2 MP_TAC (MP_TAC o SPEC `e / &3`)) THEN
  ASM_REWRITE_TAC[REAL_ARITH `&0 < e / &3 <=> &0 < e`; IMP_IMP] THEN
  REWRITE_TAC[GSYM EVENTUALLY_AND] THEN
  DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_HAPPENS) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `k:K` THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `x:A`)) THEN
  ASM_REWRITE_TAC[] THEN DISCH_THEN(MP_TAC o SPEC `e / &3`) THEN
  ASM_REWRITE_TAC[REAL_ARITH `&0 < e / &3 <=> &0 < e`] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `u:A->bool` THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `y:A` THEN
  DISCH_THEN(fun th -> DISCH_TAC THEN MP_TAC th) THEN FIRST_X_ASSUM(fun th ->
    MP_TAC(SPEC `y:A` th) THEN MP_TAC(SPEC `x:A` th)) THEN
  SUBGOAL_THEN `(y:A) IN topspace top` ASSUME_TAC THENL
   [ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET]; ASM_REWRITE_TAC[]] THEN
  ASM_SIMP_TAC[IN_MBALL] THEN CONV_TAC METRIC_ARITH);;

let CONTINUOUS_MAP_UNIFORM_LIMIT_ALT = prove
 (`!net top m f:K->A->B g.
        ~trivial_limit net /\
        IMAGE g (topspace top) SUBSET mspace m /\
        eventually (\n. continuous_map (top,mtopology m) (f n)) net /\
        (!e. &0 < e
             ==> eventually
                   (\n. !x. x IN topspace top ==> mdist m (f n x,g x) < e)
                 net)
        ==> continuous_map (top,mtopology m) g`,
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC(ISPEC `net:K net` CONTINUOUS_MAP_UNIFORM_LIMIT) THEN
  EXISTS_TAC `f:K->A->B` THEN ASM_SIMP_TAC[]);;

let CONTINUOUS_MAP_UNIFORMLY_CAUCHY_LIMIT = prove
 (`!top ms f:num->A->B.
      ~trivial_limit sequentially /\ mcomplete ms /\
      eventually (\n. continuous_map (top,mtopology ms) (f n)) sequentially /\
      (!e. &0 < e
           ==> ?N. !m n x. N <= m /\ N <= n /\ x IN topspace top
                           ==> mdist ms (f m x,f n x) < e)
      ==> ?g. continuous_map (top,mtopology ms) g /\
              !e. &0 < e
                  ==> eventually
                       (\n. !x. x IN topspace top
                                ==> mdist ms (f n x,g x) < e)
                       sequentially`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN
   `!x. x IN topspace top
        ==> ?l. limit (mtopology ms) (\n. (f:num->A->B) n x) l sequentially`
  MP_TAC THENL
   [X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    FIRST_ASSUM(MATCH_MP_TAC o GEN_REWRITE_RULE I [MCOMPLETE]) THEN
    REWRITE_TAC[cauchy_in] THEN CONJ_TAC THENL
     [FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
        EVENTUALLY_MONO)) THEN
      ASM_SIMP_TAC[continuous_map; TOPSPACE_MTOPOLOGY];
      ASM_MESON_TAC[]];
    GEN_REWRITE_TAC (LAND_CONV o BINDER_CONV) [RIGHT_IMP_EXISTS_THM] THEN
    REWRITE_TAC[SKOLEM_THM]] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `g:A->B` THEN DISCH_TAC THEN
  MATCH_MP_TAC(TAUT `q /\ (q ==> p) ==> p /\ q`) THEN CONJ_TAC THENL
   [X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN
    ASM_REWRITE_TAC[REAL_HALF; EVENTUALLY_SEQUENTIALLY] THEN
    DISCH_THEN(X_CHOOSE_THEN `N:num` STRIP_ASSUME_TAC) THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [EVENTUALLY_SEQUENTIALLY]) THEN
    REWRITE_TAC[continuous_map; LEFT_IMP_EXISTS_THM; TOPSPACE_MTOPOLOGY] THEN
    X_GEN_TAC `P:num` THEN DISCH_TAC THEN EXISTS_TAC `MAX N P` THEN
    ASM_REWRITE_TAC[ARITH_RULE `MAX N P <= n <=> N <= n /\ P <= n`] THEN
    X_GEN_TAC `n:num` THEN STRIP_TAC THEN X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN ASM_REWRITE_TAC[LIMIT_METRIC] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `e / &2`)) THEN
    ASM_REWRITE_TAC[REAL_HALF; EVENTUALLY_SEQUENTIALLY] THEN
    DISCH_THEN(X_CHOOSE_THEN `M:num` (MP_TAC o SPEC `MAX M (MAX N P)`)) THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`n:num`; `MAX M (MAX N P)`; `x:A`]) THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `n:num`) THEN
    ASM_SIMP_TAC[ARITH_RULE `n <= MAX M N <=> n <= M \/ n <= N`; LE_REFL] THEN
    DISCH_THEN(MP_TAC o SPEC `x:A` o CONJUNCT1) THEN
    UNDISCH_TAC `(g:A->B) x IN mspace ms` THEN ASM_REWRITE_TAC[] THEN
    CONV_TAC METRIC_ARITH;
    DISCH_TAC THEN
    MATCH_MP_TAC(ISPEC `sequentially` CONTINUOUS_MAP_UNIFORM_LIMIT_ALT) THEN
    EXISTS_TAC `f:num->A->B` THEN
    RULE_ASSUM_TAC(REWRITE_RULE[limit; TOPSPACE_MTOPOLOGY]) THEN
    ASM_SIMP_TAC[SUBSET; FORALL_IN_IMAGE]]);;

(* ------------------------------------------------------------------------- *)
(* Combining theorems for continuous functions into the reals.               *)
(* ------------------------------------------------------------------------- *)

let CONTINUOUS_MAP_REAL_CONST = prove
 (`!top. continuous_map (top,euclideanreal) (\x:A. c)`,
  REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV]);;

let CONTINUOUS_MAP_REAL_MUL = prove
 (`!top f g:A->real.
        continuous_map (top,euclideanreal) f /\
        continuous_map (top,euclideanreal) g
        ==> continuous_map (top,euclideanreal) (\x. f x * g x)`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_MUL]);;

let CONTINUOUS_MAP_REAL_POW = prove
 (`!top (f:A->real) n.
        continuous_map (top,euclideanreal) f
        ==> continuous_map (top,euclideanreal) (\x. f x pow n)`,
  REWRITE_TAC[RIGHT_FORALL_IMP_THM] THEN REPEAT GEN_TAC THEN DISCH_TAC THEN
  INDUCT_TAC THEN
  ASM_SIMP_TAC[real_pow; CONTINUOUS_MAP_REAL_CONST; CONTINUOUS_MAP_REAL_MUL]);;

let CONTINUOUS_MAP_REAL_LMUL = prove
 (`!top c f:A->real.
        continuous_map (top,euclideanreal) f
        ==> continuous_map (top,euclideanreal) (\x. c * f x)`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_LMUL]);;

let CONTINUOUS_MAP_REAL_LMUL_EQ = prove
 (`!top c f:A->real.
        continuous_map (top,euclideanreal) (\x. c * f x) <=>
        c = &0 \/ continuous_map (top,euclideanreal) f`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `c = &0` THEN
  ASM_REWRITE_TAC[REAL_MUL_LZERO; CONTINUOUS_MAP_REAL_CONST] THEN
  EQ_TAC THEN REWRITE_TAC[CONTINUOUS_MAP_REAL_LMUL] THEN DISCH_THEN(MP_TAC o
   SPEC `inv(c):real` o MATCH_MP CONTINUOUS_MAP_REAL_LMUL) THEN
  ASM_SIMP_TAC[REAL_MUL_ASSOC; REAL_MUL_LINV; REAL_MUL_LID; ETA_AX]);;

let CONTINUOUS_MAP_REAL_RMUL = prove
 (`!top c f:A->real.
        continuous_map (top,euclideanreal) f
        ==> continuous_map (top,euclideanreal) (\x. f x * c)`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_RMUL]);;

let CONTINUOUS_MAP_REAL_RMUL_EQ = prove
 (`!top c f:A->real.
        continuous_map (top,euclideanreal) (\x. f x * c) <=>
        c = &0 \/ continuous_map (top,euclideanreal) f`,
  ONCE_REWRITE_TAC[REAL_MUL_SYM] THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_LMUL_EQ]);;

let CONTINUOUS_MAP_REAL_NEG = prove
 (`!top f:A->real.
        continuous_map (top,euclideanreal) f
        ==> continuous_map (top,euclideanreal) (\x. --(f x))`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_NEG]);;

let CONTINUOUS_MAP_REAL_NEG_EQ = prove
 (`!top f:A->real.
        continuous_map (top,euclideanreal) (\x. --(f x)) <=>
        continuous_map (top,euclideanreal) f`,
  ONCE_REWRITE_TAC[REAL_NEG_MINUS1] THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_LMUL_EQ] THEN
  CONV_TAC REAL_RAT_REDUCE_CONV);;

let CONTINUOUS_MAP_REAL_ADD = prove
 (`!top f g:A->real.
        continuous_map (top,euclideanreal) f /\
        continuous_map (top,euclideanreal) g
        ==> continuous_map (top,euclideanreal) (\x. f x + g x)`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_ADD]);;

let CONTINUOUS_MAP_REAL_SUB = prove
 (`!top f g:A->real.
        continuous_map (top,euclideanreal) f /\
        continuous_map (top,euclideanreal) g
        ==> continuous_map (top,euclideanreal) (\x. f x - g x)`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_SUB]);;

let CONTINUOUS_MAP_REAL_ABS = prove
 (`!top f:A->real.
        continuous_map (top,euclideanreal) f
        ==> continuous_map (top,euclideanreal) (\x. abs(f x))`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_ABS]);;

let CONTINUOUS_MAP_REAL_MAX = prove
 (`!top f g:A->real.
        continuous_map (top,euclideanreal) f /\
        continuous_map (top,euclideanreal) g
        ==> continuous_map (top,euclideanreal) (\x. max (f x) (g x))`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_MAX]);;

let CONTINUOUS_MAP_REAL_MIN = prove
 (`!top f g:A->real.
        continuous_map (top,euclideanreal) f /\
        continuous_map (top,euclideanreal) g
        ==> continuous_map (top,euclideanreal) (\x. min (f x) (g x))`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_MIN]);;

let CONTINUOUS_MAP_SUM = prove
 (`!top f:A->K->real k.
        FINITE k /\
        (!i. i IN k ==> continuous_map (top,euclideanreal) (\x. f x i))
        ==> continuous_map (top,euclideanreal) (\x. sum k (f x))`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_SUM]);;

let CONTINUOUS_MAP_PRODUCT = prove
 (`!top f:A->K->real k.
        FINITE k /\
        (!i. i IN k ==> continuous_map (top,euclideanreal) (\x. f x i))
        ==> continuous_map (top,euclideanreal) (\x. product k (f x))`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_PRODUCT]);;

let CONTINUOUS_MAP_REAL_INV = prove
 (`!top f:A->real.
        continuous_map (top,euclideanreal) f /\
        (!x. x IN topspace top ==> ~(f x = &0))
        ==> continuous_map (top,euclideanreal) (\x. inv(f x))`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_INV]);;

let CONTINUOUS_MAP_REAL_DIV = prove
 (`!top f g:A->real.
        continuous_map (top,euclideanreal) f /\
        continuous_map (top,euclideanreal) g /\
        (!x. x IN topspace top ==> ~(g x = &0))
        ==> continuous_map (top,euclideanreal) (\x. f x / g x)`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_REAL_DIV]);;

let CONTINUOUS_MAP_INF = prove
 (`!top f:A->K->real k.
        FINITE k /\
        (!i. i IN k ==> continuous_map (top,euclideanreal) (\x. f x i))
        ==> continuous_map (top,euclideanreal) (\x. inf {f x i | i IN k})`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_INF]);;

let CONTINUOUS_MAP_SUP = prove
 (`!top f:A->K->real k.
        FINITE k /\
        (!i. i IN k ==> continuous_map (top,euclideanreal) (\x. f x i))
        ==> continuous_map (top,euclideanreal) (\x. sup {f x i | i IN k})`,
  SIMP_TAC[CONTINUOUS_MAP_ATPOINTOF; LIMIT_SUP]);;

let CONTINUOUS_MAP_REAL_SHRINK = prove
 (`continuous_map (euclideanreal,
                   subtopology euclideanreal (real_interval(--(&1),&1)))
                  (\x. x / (&1 + abs x))`,
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
  REWRITE_TAC[IN_REAL_INTERVAL; REAL_BOUNDS_LT; REAL_SHRINK_RANGE] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_DIV THEN
  REWRITE_TAC[CONTINUOUS_MAP_ID; REAL_ARITH `~(&1 + abs x = &0)`] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_ADD THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST] THEN
  GEN_REWRITE_TAC RAND_CONV [GSYM ETA_AX] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_ABS THEN
  REWRITE_TAC[CONTINUOUS_MAP_ID]);;

let CONTINUOUS_MAP_REAL_GROW = prove
 (`continuous_map (subtopology euclideanreal (real_interval(--(&1),&1)),
                   euclideanreal)
                  (\x. x / (&1 - abs x))`,
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_DIV THEN
  SIMP_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY; CONTINUOUS_MAP_ID] THEN
  SIMP_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; IN_REAL_INTERVAL] THEN
  CONJ_TAC THENL [MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB; REAL_ARITH_TAC] THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY THEN
  GEN_REWRITE_TAC RAND_CONV [GSYM ETA_AX] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_ABS THEN
  REWRITE_TAC[CONTINUOUS_MAP_ID]);;

let HOMEOMORPHIC_MAPS_REAL_SHRINK = prove
 (`homeomorphic_maps
     (euclideanreal,subtopology euclideanreal (real_interval(--(&1),&1)))
     ((\x. x / (&1 + abs x)),(\y. y / (&1 - abs y)))`,
  REWRITE_TAC[homeomorphic_maps] THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_SHRINK; CONTINUOUS_MAP_REAL_GROW] THEN
  REWRITE_TAC[REAL_GROW_SHRINK; REAL_SHRINK_GROW_EQ] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; IN_REAL_INTERVAL] THEN
  REAL_ARITH_TAC);;

let CONTINUOUS_MAP_CASES_LE = prove
 (`!top top' p q f (g:A->B).
        continuous_map (top,euclideanreal) p /\
        continuous_map (top,euclideanreal) q /\
        continuous_map
         (subtopology top {x | x IN topspace top /\ p x <= q x},top') f /\
        continuous_map
         (subtopology top {x | x IN topspace top /\ q x <= p x},top') g /\
        (!x. x IN topspace top /\ p x = q x ==> f x = g x)
        ==> continuous_map (top,top') (\x. if p x <= q x then f x else g x)`,
  REPEAT STRIP_TAC THEN
  ONCE_REWRITE_TAC[REAL_ARITH `x <= y <=> y - x >= &0`] THEN
  ONCE_REWRITE_TAC[SET_RULE `x >= &0 <=> x IN {t | t >= &0}`] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_CASES_FUNCTION THEN
  EXISTS_TAC `euclideanreal` THEN ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_SUB] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; REAL_ARITH `~(x >= y) <=> x:real < y`;
    SET_RULE `UNIV DIFF {x | P x} = {x | ~P x}`] THEN
  REWRITE_TAC[EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GE;
              EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LT;
              EUCLIDEANREAL_FRONTIER_OF_HALSPACE_GE] THEN
  ASM_REWRITE_TAC[IN_ELIM_THM; REAL_SUB_0; real_ge; REAL_SUB_LE] THEN
  ASM_REWRITE_TAC[REAL_ARITH `p - q <= &0 <=> p <= q`] THEN
  ASM_MESON_TAC[]);;

let CONTINUOUS_MAP_CASES_LT = prove
 (`!top top' p q f (g:A->B).
        continuous_map (top,euclideanreal) p /\
        continuous_map (top,euclideanreal) q /\
        continuous_map
         (subtopology top {x | x IN topspace top /\ p x <= q x},top') f /\
        continuous_map
         (subtopology top {x | x IN topspace top /\ q x <= p x},top') g /\
        (!x. x IN topspace top /\ p x = q x ==> f x = g x)
        ==> continuous_map (top,top') (\x. if p x < q x then f x else g x)`,
  REPEAT STRIP_TAC THEN
  ONCE_REWRITE_TAC[REAL_ARITH `x < y <=> y - x > &0`] THEN
  ONCE_REWRITE_TAC[SET_RULE `x > &0 <=> x IN {t | t > &0}`] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_CASES_FUNCTION THEN
  EXISTS_TAC `euclideanreal` THEN ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_SUB] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; REAL_ARITH `~(x > y) <=> x:real <= y`;
    SET_RULE `UNIV DIFF {x | P x} = {x | ~P x}`] THEN
  REWRITE_TAC[EUCLIDEANREAL_CLOSURE_OF_HALSPACE_GT;
              EUCLIDEANREAL_CLOSURE_OF_HALSPACE_LE;
              EUCLIDEANREAL_FRONTIER_OF_HALSPACE_GT] THEN
  ASM_REWRITE_TAC[IN_ELIM_THM; REAL_SUB_0; real_ge; REAL_SUB_LE] THEN
  ASM_REWRITE_TAC[REAL_ARITH `p - q <= &0 <=> p <= q`] THEN
  ASM_MESON_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Paths and path-connectedness.                                             *)
(* ------------------------------------------------------------------------- *)

let path_in = new_definition
 `path_in top (g:real->A) <=>
  continuous_map (subtopology euclideanreal (real_interval[&0,&1]),top) g`;;

let PATH_IN_COMPOSE = prove
 (`!top top' f:A->B g:real->A.
        path_in top g /\ continuous_map(top,top') f ==> path_in top' (f o g)`,
  REWRITE_TAC[path_in; CONTINUOUS_MAP_COMPOSE]);;

let PATH_IN_SUBTOPOLOGY = prove
 (`!top s g:real->A.
        path_in (subtopology top s) g <=>
        path_in top g /\ (!x. x IN real_interval[&0,&1] ==> g x IN s)`,
  REWRITE_TAC[path_in; CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
  SIMP_TAC[continuous_map; TOPSPACE_SUBTOPOLOGY; TOPSPACE_EUCLIDEANREAL] THEN
  SET_TAC[]);;

let PATH_IN_CONST = prove
 (`!top a:A. path_in top (\x. a) <=> a IN topspace top`,
  REWRITE_TAC[path_in; CONTINUOUS_MAP_CONST] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; REAL_INTERVAL_EQ_EMPTY] THEN
  CONV_TAC REAL_RAT_REDUCE_CONV);;

let path_connected_space = new_definition
 `path_connected_space top <=>
        !x y:A. x IN topspace top /\ y IN topspace top
                ==> ?g. path_in top g /\ g(&0) = x /\ g(&1) = y`;;

let path_connected_in = new_definition
 `path_connected_in top (s:A->bool) <=>
  s SUBSET topspace top /\ path_connected_space(subtopology top s)`;;

let PATH_CONNECTED_IN_ABSOLUTE = prove
 (`!top s:A->bool.
        path_connected_in (subtopology top s) s <=> path_connected_in top s`,
  REWRITE_TAC[path_connected_in; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER; SUBSET_REFL] THEN
  REWRITE_TAC[INTER_ACI]);;

let PATH_CONNECTED_IN_SUBTOPOLOGY = prove
 (`!top s t:A->bool.
      path_connected_in (subtopology top s) t <=>
      path_connected_in top t /\ t SUBSET s`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[path_connected_in; SUBTOPOLOGY_SUBTOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; SUBSET_INTER] THEN
  ASM_CASES_TAC `(t:A->bool) SUBSET s` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[SET_RULE `t SUBSET s ==> s INTER t = t`]);;

let PATH_CONNECTED_IN = prove
 (`!top s:A->bool.
        path_connected_in top s <=>
        s SUBSET topspace top /\
        !x y. x IN s /\ y IN s
              ==> ?g. path_in top g /\
                      IMAGE g (real_interval[&0,&1]) SUBSET s /\
                      g(&0) = x /\ g(&1) = y`,
  REPEAT GEN_TAC THEN REWRITE_TAC[path_connected_in; path_connected_space] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; path_in; CONTINUOUS_MAP_IN_SUBTOPOLOGY;
               SET_RULE `s SUBSET u ==> u INTER s = s`] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; INTER_UNIV; GSYM CONJ_ASSOC]);;

let PATH_CONNECTED_IN_TOPSPACE = prove
 (`!top:A topology. path_connected_in top (topspace top) <=>
                    path_connected_space top`,
  REWRITE_TAC[path_connected_in; SUBSET_REFL; SUBTOPOLOGY_TOPSPACE]);;

let PATH_CONNECTED_IMP_CONNECTED_SPACE = prove
 (`!top:A topology. path_connected_space top ==> connected_space top`,
  REWRITE_TAC[path_connected_space; CONNECTED_SPACE_SUBCONNECTED] THEN
  GEN_TAC THEN STRIP_TAC THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`x:A`; `y:A`]) THEN
  ASM_REWRITE_TAC[path_in; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `g:real->A` THEN STRIP_TAC THEN
  EXISTS_TAC `IMAGE (g:real->A) (real_interval [&0,&1])` THEN
  REPEAT CONJ_TAC THENL
   [FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ]
      CONNECTED_IN_CONTINUOUS_MAP_IMAGE)) THEN
    REWRITE_TAC[CONNECTED_IN_ABSOLUTE] THEN
    REWRITE_TAC[CONNECTED_IN_EUCLIDEANREAL_INTERVAL];
    REWRITE_TAC[IN_IMAGE] THEN EXISTS_TAC `&0` THEN
    ASM_REWRITE_TAC[IN_REAL_INTERVAL; REAL_POS];
    REWRITE_TAC[IN_IMAGE] THEN EXISTS_TAC `&1` THEN
    ASM_REWRITE_TAC[IN_REAL_INTERVAL; REAL_POS; REAL_LE_REFL];
    FIRST_ASSUM(MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE) THEN
    REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY]]);;

let PATH_CONNECTED_IN_IMP_CONNECTED_IN = prove
 (`!top s:A->bool. path_connected_in top s ==> connected_in top s`,
  SIMP_TAC[path_connected_in; connected_in] THEN
  SIMP_TAC[PATH_CONNECTED_IMP_CONNECTED_SPACE]);;

let PATH_CONNECTED_SPACE_TOPSPACE_EMPTY = prove
 (`!top:A topology. topspace top = {} ==> path_connected_space top`,
  SIMP_TAC[path_connected_space; NOT_IN_EMPTY]);;

let PATH_CONNECTED_IN_EMPTY = prove
 (`!top:A topology. path_connected_in top {}`,
  SIMP_TAC[path_connected_in; PATH_CONNECTED_SPACE_TOPSPACE_EMPTY;
           EMPTY_SUBSET; TOPSPACE_SUBTOPOLOGY; INTER_EMPTY]);;

let PATH_CONNECTED_IN_SING = prove
 (`!top a:A. path_connected_in top {a} <=> a IN topspace top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[PATH_CONNECTED_IN; SING_SUBSET] THEN
  ASM_CASES_TAC `(a:A) IN topspace top` THEN ASM_REWRITE_TAC[IN_SING] THEN
  REPEAT STRIP_TAC THEN EXISTS_TAC `(\x. a):real->A` THEN
  ASM_REWRITE_TAC[path_in; CONTINUOUS_MAP_CONST] THEN SET_TAC[]);;

let PATH_CONNECTED_IN_CONTINUOUS_MAP_IMAGE = prove
 (`!f:A->B top top' s.
        continuous_map (top,top') f /\ path_connected_in top s
        ==> path_connected_in top' (IMAGE f s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[PATH_CONNECTED_IN] THEN
  STRIP_TAC THEN FIRST_ASSUM(ASSUME_TAC o MATCH_MP
   CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[FORALL_IN_IMAGE_2]] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`x:A`; `y:A`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `g:real->A` THEN STRIP_TAC THEN
  EXISTS_TAC `(f:A->B) o (g:real->A)` THEN
  ASM_SIMP_TAC[o_THM; IMAGE_o; IMAGE_SUBSET] THEN
  ASM_MESON_TAC[PATH_IN_COMPOSE]);;

let HOMEOMORPHIC_PATH_CONNECTED_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (path_connected_space top <=> path_connected_space top')`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[homeomorphic_space; homeomorphic_maps; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN STRIP_TAC THEN
  REWRITE_TAC[GSYM PATH_CONNECTED_IN_TOPSPACE] THEN EQ_TAC THEN DISCH_TAC THENL
   [SUBGOAL_THEN `topspace top' = IMAGE (f:A->B) (topspace top)` SUBST1_TAC
    THENL [ALL_TAC; ASM_MESON_TAC[PATH_CONNECTED_IN_CONTINUOUS_MAP_IMAGE]];
    SUBGOAL_THEN `topspace top = IMAGE (g:B->A) (topspace top')` SUBST1_TAC
    THENL [ALL_TAC; ASM_MESON_TAC[PATH_CONNECTED_IN_CONTINUOUS_MAP_IMAGE]]] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[continuous_map]) THEN ASM SET_TAC[]);;

let PATH_CONNECTED_IN_EUCLIDEANREAL_INTERVAL = prove
 (`(!a b. path_connected_in euclideanreal (real_interval[a,b])) /\
   (!a b. path_connected_in euclideanreal (real_interval(a,b)))`,
  REPEAT STRIP_TAC THEN
  REWRITE_TAC[PATH_CONNECTED_IN; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[IN_UNIV; SUBSET_UNIV] THEN
  MAP_EVERY X_GEN_TAC [`x:real`; `y:real`] THEN
  REWRITE_TAC[IN_REAL_INTERVAL] THEN STRIP_TAC THEN
  EXISTS_TAC `\u. (&1 - u) * x + u * y` THEN
  REWRITE_TAC[REAL_SUB_REFL; REAL_SUB_RZERO; REAL_MUL_LZERO] THEN
  REWRITE_TAC[REAL_MUL_LID; REAL_ADD_LID; REAL_ADD_RID] THEN
  (CONV_TAC o GEN_SIMPLIFY_CONV TOP_DEPTH_SQCONV (basic_ss []) 4)
   [path_in; CONTINUOUS_MAP_REAL_ADD; CONTINUOUS_MAP_REAL_RMUL;
    CONTINUOUS_MAP_ID; CONTINUOUS_MAP_REAL_SUB; CONTINUOUS_MAP_REAL_CONST;
    CONTINUOUS_MAP_FROM_SUBTOPOLOGY] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IN_REAL_INTERVAL] THEN
  X_GEN_TAC `t:real` THEN STRIP_TAC THENL
   [MATCH_MP_TAC(REAL_ARITH
     `!x y:real.
       (a <= x /\ y <= b) /\ (x <= r /\ r <= y) ==> a <= r /\ r <= b`);
    MATCH_MP_TAC(REAL_ARITH
     `!x y:real.
       (a < x /\ y < b) /\ (x <= r /\ r <= y) ==> a < r /\ r < b`)] THEN
  MAP_EVERY EXISTS_TAC [`min x y:real`; `max x y:real`] THEN
  (CONJ_TAC THENL [ASM_REAL_ARITH_TAC; ALL_TAC]) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC(REAL_ARITH
      `(&0 <= t * (y - x) \/ &0 <= (&1 - t) * (x - y)) /\
       (&0 <= t * (x - y) \/ &0 <= (&1 - t) * (y - x))
       ==> min x y <= (&1 - t) * x + t * y /\
           (&1 - t) * x + t * y <= max x y`) THEN
  ASM_MESON_TAC[REAL_SUB_LE; REAL_LE_MUL;
                REAL_ARITH `&0 <= x - y \/ &0 <= y - x`]);;

let PATH_CONNECTED_IN_PATH_IMAGE = prove
 (`!top g:real->A.
     path_in top g ==> path_connected_in top (IMAGE g (real_interval[&0,&1]))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[path_in] THEN REPEAT STRIP_TAC THEN
  MATCH_MP_TAC PATH_CONNECTED_IN_CONTINUOUS_MAP_IMAGE THEN
  EXISTS_TAC `subtopology euclideanreal (real_interval [&0,&1])` THEN
  ASM_REWRITE_TAC[PATH_CONNECTED_IN_SUBTOPOLOGY; SUBSET_REFL] THEN
  REWRITE_TAC[PATH_CONNECTED_IN_EUCLIDEANREAL_INTERVAL]);;

let CONNECTED_IN_PATH_IMAGE = prove
 (`!top g:real->A.
     path_in top g ==> connected_in top (IMAGE g (real_interval[&0,&1]))`,
  MESON_TAC[PATH_CONNECTED_IN_IMP_CONNECTED_IN;
            PATH_CONNECTED_IN_PATH_IMAGE]);;

let COMPACT_IN_PATH_IMAGE = prove
 (`!top g:real->A.
     path_in top g ==> compact_in top (IMAGE g (real_interval[&0,&1]))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[path_in] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] IMAGE_COMPACT_IN) THEN
  REWRITE_TAC[COMPACT_IN_SUBTOPOLOGY; SUBSET_REFL] THEN
  REWRITE_TAC[COMPACT_IN_EUCLIDEANREAL_INTERVAL]);;

let PATH_START_IN_TOPSPACE = prove
 (`!top g:real->A. path_in top g ==> g(&0) IN topspace top`,
  REWRITE_TAC[path_in; continuous_map] THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[INTER_UNIV; IN_REAL_INTERVAL] THEN REAL_ARITH_TAC);;

let PATH_FINISH_IN_TOPSPACE = prove
 (`!top g:real->A. path_in top g ==> g(&1) IN topspace top`,
  REWRITE_TAC[path_in; continuous_map] THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[INTER_UNIV; IN_REAL_INTERVAL] THEN REAL_ARITH_TAC);;

let PATH_IMAGE_SUBSET_TOPSPACE = prove
 (`!top g:real->A.
    path_in top g ==> IMAGE g (real_interval[&0,&1]) SUBSET topspace top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[path_in] THEN
  DISCH_THEN(MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE) THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; INTER_UNIV; TOPSPACE_EUCLIDEANREAL]);;

let PATH_CONNECTED_SPACE_SUBCONNECTED = prove
 (`!top. path_connected_space top <=>
         !x y:A. x IN topspace top /\ y IN topspace top
                 ==> ?s. path_connected_in top s /\
                         x IN s /\
                         y IN s /\
                         s SUBSET topspace top`,
  GEN_TAC THEN REWRITE_TAC[path_connected_space] THEN EQ_TAC THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `x:A` THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `y:A` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[] THENL
   [DISCH_THEN(X_CHOOSE_THEN `g:real->A` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `IMAGE (g:real->A) (real_interval[&0,&1])` THEN
    ASM_SIMP_TAC[PATH_CONNECTED_IN_PATH_IMAGE; PATH_IMAGE_SUBSET_TOPSPACE] THEN
    REWRITE_TAC[IN_IMAGE; IN_REAL_INTERVAL] THEN CONJ_TAC THENL
     [EXISTS_TAC `&0`; EXISTS_TAC `&1`] THEN
    ASM_REWRITE_TAC[] THEN CONV_TAC REAL_RAT_REDUCE_CONV;
    DISCH_THEN(X_CHOOSE_THEN `s:A->bool` STRIP_ASSUME_TAC) THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [PATH_CONNECTED_IN]) THEN
    ASM_MESON_TAC[]]);;

let PATH_CONNECTED_IN_EUCLIDEANREAL = prove
 (`!s. path_connected_in euclideanreal s <=> is_realinterval s`,
  GEN_TAC THEN EQ_TAC THENL
   [MESON_TAC[CONNECTED_IN_EUCLIDEANREAL; PATH_CONNECTED_IN_IMP_CONNECTED_IN];
    REWRITE_TAC[is_realinterval] THEN DISCH_TAC] THEN
  REWRITE_TAC[path_connected_in; TOPSPACE_EUCLIDEANREAL; SUBSET_UNIV] THEN
  REWRITE_TAC[PATH_CONNECTED_SPACE_SUBCONNECTED] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; TOPSPACE_EUCLIDEANREAL; INTER_UNIV] THEN
  MAP_EVERY X_GEN_TAC [`x:real`; `y:real`] THEN STRIP_TAC THEN
  EXISTS_TAC `real_interval[min x y,max x y]` THEN
  REWRITE_TAC[PATH_CONNECTED_IN_EUCLIDEANREAL_INTERVAL; IN_REAL_INTERVAL;
              PATH_CONNECTED_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[REAL_LE_MAX; REAL_MIN_LE; REAL_LE_REFL] THEN
  REWRITE_TAC[SUBSET; IN_REAL_INTERVAL] THEN
  X_GEN_TAC `z:real` THEN STRIP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  MAP_EVERY EXISTS_TAC [`min x y:real`; `max x y:real`] THEN
  ASM_REWRITE_TAC[] THEN REWRITE_TAC[real_min; real_max] THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Path components.                                                          *)
(* ------------------------------------------------------------------------- *)

let path_component_of = new_definition
 `path_component_of top x y <=>
        ?g. path_in top g /\ g(&0) = x /\ g(&1) = y`;;

let path_components_of = new_definition
 `path_components_of top = {path_component_of top x |x| x IN topspace top}`;;

let PATH_COMPONENT_IN_TOPSPACE = prove
 (`!top x y:A.
        path_component_of top x y ==> x IN topspace top /\ y IN topspace top`,
  REWRITE_TAC[path_component_of; path_in; continuous_map] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY] THEN
  REPEAT STRIP_TAC THEN REPEAT(FIRST_X_ASSUM(SUBST1_TAC o SYM)) THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN REWRITE_TAC[IN_REAL_INTERVAL] THEN
  REAL_ARITH_TAC);;

let PATH_COMPONENT_OF_REFL = prove
 (`!top x:A. path_component_of top x x <=> x IN topspace top`,
  REPEAT GEN_TAC THEN
  EQ_TAC THENL [MESON_TAC[PATH_COMPONENT_IN_TOPSPACE]; DISCH_TAC] THEN
  REWRITE_TAC[path_component_of] THEN
  EXISTS_TAC `(\t. x):real->A` THEN ASM_REWRITE_TAC[PATH_IN_CONST]);;

let PATH_COMPONENT_OF_SYM = prove
 (`!top x y:A. path_component_of top x y <=> path_component_of top y x`,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  REWRITE_TAC[path_component_of; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `g:real->A` THEN REWRITE_TAC[path_in] THEN STRIP_TAC THEN
  EXISTS_TAC `(g:real->A) o (\t. &1 - t)` THEN
  REWRITE_TAC[o_THM] THEN CONV_TAC REAL_RAT_REDUCE_CONV THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `subtopology euclideanreal (real_interval [&0,&1])` THEN
  ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
  REWRITE_TAC[IN_REAL_INTERVAL] THEN
  (CONJ_TAC THENL [ALL_TAC; REAL_ARITH_TAC]) THEN
  MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST; CONTINUOUS_MAP_ID]);;

let PATH_COMPONENT_OF_TRANS = prove
 (`!top x y z:A.
        path_component_of top x y /\ path_component_of top y z
        ==> path_component_of top x z`,
  REPEAT GEN_TAC THEN REWRITE_TAC[path_component_of; path_in] THEN
  DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_THEN `g1:real->A` STRIP_ASSUME_TAC)
   (X_CHOOSE_THEN `g2:real->A` STRIP_ASSUME_TAC)) THEN
  EXISTS_TAC
   `\x. if x <= &1 / &2 then ((g1:real->A) o (\t. &2 * t)) x
        else (g2 o (\t. &2 * t - &1)) x` THEN
  REWRITE_TAC[o_THM] THEN CONV_TAC REAL_RAT_REDUCE_CONV THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC CONTINUOUS_MAP_CASES_LE THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST] THEN
  SIMP_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY; CONTINUOUS_MAP_ID] THEN
  CONV_TAC REAL_RAT_REDUCE_CONV THEN ASM_REWRITE_TAC[] THEN
  CONJ_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `subtopology euclideanreal (real_interval [&0,&1])` THEN
  ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBTOPOLOGY_SUBTOPOLOGY;
        TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE; IN_INTER;
        IN_REAL_INTERVAL; IN_ELIM_THM] THEN
  (CONJ_TAC THENL [ALL_TAC; REAL_ARITH_TAC]) THEN
  MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY THEN
  REPEAT(MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB) THEN REPEAT CONJ_TAC THEN
  REPEAT(MATCH_MP_TAC CONTINUOUS_MAP_REAL_MUL) THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST; CONTINUOUS_MAP_ID]);;

let PATH_COMPONENT_OF_SET = prove
 (`!top x:A.
        path_component_of top x =
        {y | ?g. path_in top g /\ g(&0) = x /\ g(&1) = y}`,
  REWRITE_TAC[EXTENSION; IN_ELIM_THM] THEN
  REWRITE_TAC[IN; path_component_of]);;

let PATH_COMPONENT_OF_SUBSET = prove
 (`!top x. (path_component_of top x) SUBSET topspace top`,
  REWRITE_TAC[SUBSET; IN] THEN MESON_TAC[PATH_COMPONENT_IN_TOPSPACE; IN]);;

let PATH_COMPONENT_OF_EQ_EMPTY = prove
 (`!top x. path_component_of top x = {} <=> ~(x IN topspace top)`,
  REWRITE_TAC[EXTENSION; NOT_IN_EMPTY] THEN
  MESON_TAC[IN; PATH_COMPONENT_OF_REFL; PATH_COMPONENT_IN_TOPSPACE]);;

let PATH_CONNECTED_SPACE_IFF_PATH_COMPONENT = prove
 (`!top:A topology.
        path_connected_space top <=>
        !x y. x IN topspace top /\ y IN topspace top
              ==> path_component_of top x y`,
  REWRITE_TAC[path_connected_space; path_component_of]);;

let PATH_CONNECTED_SPACE_IMP_PATH_COMPONENT_OF = prove
 (`!top a b:A.
        path_connected_space top /\ a IN topspace top /\ b IN topspace top
        ==> path_component_of top a b`,
  MESON_TAC[PATH_CONNECTED_SPACE_IFF_PATH_COMPONENT]);;

let PATH_CONNECTED_SPACE_PATH_COMPONENT_SET = prove
 (`!top. path_connected_space top <=>
         !x:A. x IN topspace top ==> path_component_of top x = topspace top`,
  REWRITE_TAC[PATH_CONNECTED_SPACE_IFF_PATH_COMPONENT;
              GSYM SUBSET_ANTISYM_EQ] THEN
  REWRITE_TAC[PATH_COMPONENT_OF_SUBSET] THEN SET_TAC[]);;

let PATH_COMPONENT_OF_MAXIMAL = prove
 (`!top s x:A.
     path_connected_in top s /\ x IN s ==> s SUBSET (path_component_of top x)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[PATH_CONNECTED_IN] THEN STRIP_TAC THEN
  REWRITE_TAC[SUBSET; PATH_COMPONENT_OF_SET; IN_ELIM_THM] THEN
  ASM_MESON_TAC[]);;

let PATH_COMPONENT_OF_EQUIV = prove
 (`!top x y:A.
        path_component_of top x y <=>
        x IN topspace top /\ y IN topspace top /\
        path_component_of top x = path_component_of top y`,
  REWRITE_TAC[FUN_EQ_THM] THEN
  MESON_TAC[PATH_COMPONENT_OF_REFL; PATH_COMPONENT_OF_TRANS;
            PATH_COMPONENT_OF_SYM]);;

let PATH_COMPONENT_OF_DISJOINT = prove
 (`!top x y:A.
        DISJOINT (path_component_of top x) (path_component_of top y) <=>
        ~(path_component_of top x y)`,
  REWRITE_TAC[DISJOINT; EXTENSION; IN_INTER; NOT_IN_EMPTY] THEN
  REWRITE_TAC[IN] THEN
  MESON_TAC[PATH_COMPONENT_OF_SYM; PATH_COMPONENT_OF_TRANS]);;

let PATH_COMPONENT_OF_EQ = prove
 (`!top x y:A.
        path_component_of top x = path_component_of top y <=>
        ~(x IN topspace top) /\ ~(y IN topspace top) \/
        x IN topspace top /\ y IN topspace top /\ path_component_of top x y`,
  MESON_TAC[PATH_COMPONENT_OF_REFL; PATH_COMPONENT_OF_EQUIV;
            PATH_COMPONENT_OF_EQ_EMPTY]);;

let PATH_CONNECTED_IN_PATH_IMAGE = prove
 (`!top g:real->A.
     path_in top g ==> path_connected_in top (IMAGE g (real_interval[&0,&1]))`,
  REWRITE_TAC[path_in] THEN REPEAT STRIP_TAC THEN
  REWRITE_TAC[PATH_CONNECTED_SPACE_IFF_PATH_COMPONENT; path_connected_in] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE) THEN
  REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY] THEN
  SIMP_TAC[TOPSPACE_SUBTOPOLOGY_SUBSET] THEN DISCH_TAC THEN
  SUBGOAL_THEN
   `!x. x IN IMAGE g (real_interval[&0,&1])
        ==> path_component_of
             (subtopology top (IMAGE g (real_interval[&0,&1])))
             (g(&0)) (x:A)`
  MP_TAC THENL
   [REWRITE_TAC[FORALL_IN_IMAGE; IN_REAL_INTERVAL];
    MESON_TAC[PATH_COMPONENT_OF_SYM; PATH_COMPONENT_OF_TRANS]] THEN
  X_GEN_TAC `a:real` THEN DISCH_TAC THEN
  REWRITE_TAC[path_component_of] THEN
  EXISTS_TAC `(g:real->A) o (\x. a * x)` THEN
  REWRITE_TAC[path_in; o_THM; REAL_MUL_RZERO; REAL_MUL_RID] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; IMAGE_o] THEN CONJ_TAC THENL
   [MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
    EXISTS_TAC `subtopology euclideanreal (real_interval [&0,&1])` THEN
    ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE;
                TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; IN_REAL_INTERVAL] THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY; CONTINUOUS_MAP_REAL_LMUL;
                 CONTINUOUS_MAP_ID];
    MATCH_MP_TAC IMAGE_SUBSET THEN
    REWRITE_TAC[SUBSET; FORALL_IN_IMAGE;
                TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; IN_REAL_INTERVAL]] THEN
  ASM_SIMP_TAC[REAL_LE_MUL] THEN REPEAT STRIP_TAC THEN
  GEN_REWRITE_TAC RAND_CONV [GSYM REAL_MUL_RID] THEN
  MATCH_MP_TAC REAL_LE_MUL2 THEN ASM_REWRITE_TAC[]);;

let PATH_CONNECTED_IN_PATH_COMPONENT_OF = prove
 (`!top x:A. path_connected_in top (path_component_of top x)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[path_connected_in; PATH_COMPONENT_OF_SUBSET] THEN
  REWRITE_TAC[PATH_CONNECTED_SPACE_IFF_PATH_COMPONENT] THEN
  SIMP_TAC[TOPSPACE_SUBTOPOLOGY_SUBSET; PATH_COMPONENT_OF_SUBSET] THEN
  SUBGOAL_THEN
   `!y. y IN path_component_of top (x:A)
        ==> path_component_of (subtopology top (path_component_of top x)) x y`
  MP_TAC THENL
   [X_GEN_TAC `y:A` THEN REWRITE_TAC[IN];
    MESON_TAC[PATH_COMPONENT_OF_SYM; PATH_COMPONENT_OF_TRANS]] THEN
  REWRITE_TAC[path_component_of] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `g:real->A` THEN STRIP_TAC THEN
  ASM_REWRITE_TAC[PATH_IN_SUBTOPOLOGY; SET_RULE
   `(!x. x IN s ==> f x IN t) <=> IMAGE f s SUBSET t`] THEN
  MATCH_MP_TAC PATH_COMPONENT_OF_MAXIMAL THEN
  ASM_SIMP_TAC[PATH_CONNECTED_IN_PATH_IMAGE; IN_IMAGE] THEN
  EXISTS_TAC `&0:real` THEN ASM_REWRITE_TAC[IN_REAL_INTERVAL] THEN
  CONV_TAC REAL_RAT_REDUCE_CONV);;

let UNIONS_PATH_COMPONENTS_OF = prove
 (`!top:A topology. UNIONS (path_components_of top) = topspace top`,
  GEN_TAC THEN REWRITE_TAC[path_components_of] THEN
  MATCH_MP_TAC SUBSET_ANTISYM THEN
  REWRITE_TAC[UNIONS_SUBSET; FORALL_IN_GSPEC; PATH_COMPONENT_OF_SUBSET] THEN
  REWRITE_TAC[SUBSET; UNIONS_GSPEC; IN_ELIM_THM] THEN
  X_GEN_TAC `x:A` THEN DISCH_TAC THEN EXISTS_TAC `x:A` THEN
  ASM_REWRITE_TAC[] THEN REWRITE_TAC[IN] THEN
  ASM_REWRITE_TAC[PATH_COMPONENT_OF_REFL]);;

let PATH_COMPONENTS_OF_MAXIMAL = prove
 (`!top s c:A->bool.
        c IN path_components_of top /\ path_connected_in top s /\ ~DISJOINT c s
        ==> s SUBSET c`,
  REWRITE_TAC[path_components_of; IMP_CONJ; FORALL_IN_GSPEC;
    LEFT_IMP_EXISTS_THM; SET_RULE `~DISJOINT P t <=> ?x. P x /\ x IN t`] THEN
  SIMP_TAC[PATH_COMPONENT_OF_EQUIV] THEN
  MESON_TAC[PATH_COMPONENT_OF_MAXIMAL]);;

let PAIRWISE_DISJOINT_PATH_COMPONENTS_OF = prove
 (`!top:A topology. pairwise DISJOINT (path_components_of top)`,
  SIMP_TAC[pairwise; IMP_CONJ; path_components_of; RIGHT_IMP_FORALL_THM] THEN
  REWRITE_TAC[FORALL_IN_GSPEC; RIGHT_FORALL_IMP_THM] THEN
  SIMP_TAC[PATH_COMPONENT_OF_EQ; PATH_COMPONENT_OF_DISJOINT]);;

let NONEMPTY_PATH_COMPONENTS_OF = prove
 (`!top c:A->bool. c IN path_components_of top ==> ~(c = {})`,
  SIMP_TAC[path_components_of; FORALL_IN_GSPEC; PATH_COMPONENT_OF_EQ_EMPTY]);;

let PATH_COMPONENTS_OF_SUBSET = prove
 (`!top c:A->bool. c IN path_components_of top ==> c SUBSET topspace top`,
  SIMP_TAC[path_components_of; FORALL_IN_GSPEC; PATH_COMPONENT_OF_SUBSET]);;

let PATH_CONNECTED_IN_PATH_COMPONENTS_OF = prove
 (`!top c:A->bool. c IN path_components_of top ==> path_connected_in top c`,
  REWRITE_TAC[path_components_of; FORALL_IN_GSPEC] THEN
  REWRITE_TAC[PATH_CONNECTED_IN_PATH_COMPONENT_OF]);;

(* ------------------------------------------------------------------------- *)
(* Normal spaces including Urysohn's lemma and the Tietze extension theorem. *)
(* ------------------------------------------------------------------------- *)

let normal_space = new_definition
 `normal_space (top:A topology) <=>
        !s t. closed_in top s /\ closed_in top t /\ DISJOINT s t
              ==> ?u v. open_in top u /\ open_in top v /\
                        s SUBSET u /\ t SUBSET v /\
                        DISJOINT u v`;;

let HOMEOMORPHIC_NORMAL_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (normal_space top <=> normal_space top')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAPS_MAP; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN DISCH_TAC THEN
  REWRITE_TAC[normal_space; IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[RIGHT_EXISTS_AND_THM] THEN REWRITE_TAC[MESON[]
   `(?x. P x /\ Q x) <=> ~(!x. P x ==> ~Q x)`] THEN
  FIRST_ASSUM(MP_TAC o CONJUNCT1) THEN DISCH_THEN(fun th ->
    REWRITE_TAC[MATCH_MP FORALL_OPEN_IN_HOMEOMORPHIC_IMAGE th] THEN
    REWRITE_TAC[MATCH_MP FORALL_CLOSED_IN_HOMEOMORPHIC_IMAGE th]) THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC THEN
         MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p ==> q <=> p ==> r)`) THEN
         DISCH_THEN(ASSUME_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
  RULE_ASSUM_TAC(REWRITE_RULE[HOMEOMORPHIC_EQ_EVERYTHING_MAP]) THEN
  BINOP_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  REWRITE_TAC[NOT_FORALL_THM; NOT_IMP; RIGHT_AND_EXISTS_THM] THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN ONCE_REWRITE_TAC[CONJ_ASSOC] THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
  DISCH_THEN(CONJUNCTS_THEN(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
  ASM SET_TAC[]);;

let NORMAL_SPACE = prove
 (`!top:A topology.
      normal_space (top:A topology) <=>
      !s t. closed_in top s /\ closed_in top t /\ DISJOINT s t
            ==> ?u. open_in top u /\
                    s SUBSET u /\ DISJOINT t (top closure_of u)`,
  GEN_TAC THEN REWRITE_TAC[normal_space] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `s:A->bool` THEN REWRITE_TAC[] THEN AP_TERM_TAC THEN
  GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `t:A->bool` THEN
  REWRITE_TAC[] THEN MATCH_MP_TAC(TAUT
   `(p ==> (q <=> r)) ==> (p ==> q <=> p ==> r)`) THEN STRIP_TAC THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `u:A->bool` THEN REWRITE_TAC[] THEN EQ_TAC THENL
   [DISCH_THEN(X_CHOOSE_THEN `v:A->bool` STRIP_ASSUME_TAC) THEN
    ASM_REWRITE_TAC[] THEN FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
     `t SUBSET v ==> v INTER c = {} ==> DISJOINT t c`)) THEN
    ASM_SIMP_TAC[OPEN_IN_INTER_CLOSURE_OF_EQ_EMPTY] THEN ASM SET_TAC[];
    STRIP_TAC THEN EXISTS_TAC `topspace top DIFF top closure_of u:A->bool` THEN
    ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE; CLOSED_IN_CLOSURE_OF] THEN
    MP_TAC(ISPECL [`top:A topology`; `u:A->bool`] CLOSURE_OF_SUBSET) THEN
    REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
    FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN ASM SET_TAC[]]);;

let NORMAL_SPACE_ALT = prove
 (`!top:A topology.
      normal_space (top:A topology) <=>
      !s u. closed_in top s /\ open_in top u /\ s SUBSET u
            ==> ?v. open_in top v /\ s SUBSET v /\ top closure_of v SUBSET u`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_OPEN_IN] THEN
  REWRITE_TAC[SET_RULE `s SUBSET t DIFF u <=> s SUBSET t /\ DISJOINT u s`] THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE; NORMAL_SPACE] THEN
  MESON_TAC[CLOSED_IN_SUBSET; DISJOINT_SYM]);;

let NORMAL_T1_IMP_HAUSDORFF_SPACE = prove
 (`!top:A topology.
        normal_space top /\ t1_space top ==> hausdorff_space top`,
  REWRITE_TAC[T1_SPACE_CLOSED_IN_SING; normal_space; hausdorff_space] THEN
  GEN_TAC THEN STRIP_TAC THEN MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN
  STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`{x:A}`; `{y:A}`]) THEN
  ASM_SIMP_TAC[SING_SUBSET; SET_RULE `DISJOINT {x} {y} <=> ~(x = y)`]);;

let NORMAL_T1_EQ_HAUSDORFF_SPACE = prove
 (`!top:A topology.
        normal_space top ==> (t1_space top <=> hausdorff_space top)`,
  MESON_TAC[NORMAL_T1_IMP_HAUSDORFF_SPACE; HAUSDORFF_IMP_T1_SPACE]);;

let NORMAL_T1_IMP_REGULAR_SPACE = prove
 (`!top:A topology.
        normal_space top /\ t1_space top ==> regular_space top`,
  REWRITE_TAC[T1_SPACE_CLOSED_IN_SING; normal_space; regular_space] THEN
  GEN_TAC THEN STRIP_TAC THEN MAP_EVERY X_GEN_TAC [`s:A->bool`; `x:A`] THEN
  STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`{x:A}`; `s:A->bool`]) THEN
  ASM_SIMP_TAC[SING_SUBSET] THEN DISCH_THEN MATCH_MP_TAC THEN
  ASM SET_TAC[]);;

let COMPACT_HAUSDORFF_OR_REGULAR_IMP_NORMAL_SPACE = prove
 (`!top:A topology.
        compact_space top /\ (hausdorff_space top \/ regular_space top)
        ==> normal_space top`,
  REWRITE_TAC[HAUSDORFF_SPACE_COMPACT_SETS;
              REGULAR_SPACE_COMPACT_CLOSED_SETS] THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[normal_space] THEN
  REPEAT STRIP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  ASM_MESON_TAC[CLOSED_IN_COMPACT_SPACE]);;

let NORMAL_SPACE_MTOPOLOGY = prove
 (`!m:A metric. normal_space(mtopology m)`,
  GEN_TAC THEN REWRITE_TAC[normal_space] THEN
  MAP_EVERY X_GEN_TAC [`s:A->bool`; `t:A->bool`] THEN STRIP_TAC THEN
  MP_TAC(ISPEC `m:A metric` OPEN_IN_MTOPOLOGY) THEN DISCH_THEN(fun th ->
   MP_TAC(SPEC `topspace(mtopology m) DIFF t:A->bool` th) THEN
   MP_TAC(SPEC `topspace(mtopology m) DIFF s:A->bool` th)) THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; CLOSED_IN_DIFF; OPEN_IN_TOPSPACE;
               CLOSED_IN_TOPSPACE; IMP_IMP] THEN
  GEN_REWRITE_TAC (LAND_CONV o ONCE_DEPTH_CONV) [RIGHT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[IMP_IMP; SKOLEM_THM] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY; SUBSET_DIFF] THEN
  SIMP_TAC[SUBSET; mball; IN_DIFF; IN_ELIM_THM] THEN
  DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_THEN `d:A->real` (LABEL_TAC "d"))
   (X_CHOOSE_THEN `e:A->real` (LABEL_TAC "e"))) THEN
  MAP_EVERY EXISTS_TAC
   [`UNIONS {mball m (x:A,e x / &2) | x IN s}`;
    `UNIONS {mball m (x:A,d x / &2) | x IN t}`] THEN
  REWRITE_TAC[SET_RULE
   `DISJOINT (UNIONS s) (UNIONS t) <=>
    !u. u IN s ==> !v. v IN t ==> DISJOINT u v`] THEN
  SIMP_TAC[OPEN_IN_UNIONS; FORALL_IN_GSPEC; OPEN_IN_MBALL] THEN
  REWRITE_TAC[IN_UNIONS; EXISTS_IN_GSPEC] THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN REPEAT DISCH_TAC THEN
  RULE_ASSUM_TAC(REWRITE_RULE[SET_RULE
   `DISJOINT s t <=> !x. ~(x IN s /\ x IN t)`]) THEN
  REPEAT(CONJ_TAC THENL
   [ASM_MESON_TAC[REAL_HALF; CENTRE_IN_MBALL; SUBSET]; ALL_TAC]) THEN
  X_GEN_TAC `x:A` THEN DISCH_TAC THEN
  X_GEN_TAC `y:A` THEN DISCH_TAC THEN
  SUBGOAL_THEN `(x:A) IN mspace m /\ (y:A) IN mspace m` STRIP_ASSUME_TAC THENL
   [ASM SET_TAC[]; ALL_TAC] THEN
  REMOVE_THEN "e" (MP_TAC o SPEC `x:A`) THEN
  ANTS_TAC THENL [ASM SET_TAC[]; DISCH_THEN(MP_TAC o CONJUNCT2)] THEN
  REMOVE_THEN "d" (MP_TAC o SPEC `y:A`) THEN
  ANTS_TAC THENL [ASM SET_TAC[]; DISCH_THEN(MP_TAC o CONJUNCT2)] THEN
  REWRITE_TAC[IMP_IMP] THEN DISCH_THEN(CONJUNCTS_THEN2
   (MP_TAC o SPEC `x:A`) (MP_TAC o SPEC `y:A`)) THEN
  ASM_SIMP_TAC[REAL_NOT_LT; DISJOINT; EXTENSION; NOT_IN_EMPTY; IN_INTER] THEN
  MAP_EVERY UNDISCH_TAC [`(x:A) IN mspace m`; `(y:A) IN mspace m`] THEN
  REWRITE_TAC[mball; IN_ELIM_THM] THEN CONV_TAC METRIC_ARITH);;

let METRIZABLE_IMP_NORMAL_SPACE = prove
 (`!top:A topology. metrizable_space top ==> normal_space top`,
  REWRITE_TAC[FORALL_METRIZABLE_SPACE; NORMAL_SPACE_MTOPOLOGY]);;

let NORMAL_SPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. normal_space(discrete_topology u)`,
  SIMP_TAC[METRIZABLE_SPACE_DISCRETE_TOPOLOGY;
           METRIZABLE_IMP_NORMAL_SPACE]);;

let NORMAL_SPACE_SUBTOPOLOGY = prove
 (`!top s:A->bool.
        normal_space top /\ closed_in top s
        ==> normal_space (subtopology top s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[normal_space] THEN STRIP_TAC THEN
  MAP_EVERY X_GEN_TAC [`c1:A->bool`; `c2:A->bool`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`c1:A->bool`; `c2:A->bool`]) THEN
  ANTS_TAC THENL [ASM_MESON_TAC[CLOSED_IN_TRANS_FULL]; ALL_TAC] THEN
  REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; RIGHT_EXISTS_AND_THM] THEN
  REWRITE_TAC[EXISTS_IN_GSPEC] THEN REWRITE_TAC[RIGHT_AND_EXISTS_THM] THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_IMP_SUBSET)) THEN
  ASM SET_TAC[]);;

let NORMAL_SPACE_CONTINUOUS_CLOSED_MAP_IMAGE = prove
 (`!top top' f:A->B.
        continuous_map (top,top') f /\ closed_map (top,top') f /\
        IMAGE f (topspace top) = topspace top' /\
        normal_space top
        ==> normal_space top'`,
  REPEAT GEN_TAC THEN REWRITE_TAC[normal_space; closed_map] THEN STRIP_TAC THEN
  MAP_EVERY X_GEN_TAC [`s:B->bool`; `t:B->bool`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL
   [`{x | x IN topspace top /\ (f:A->B) x IN s}`;
    `{x | x IN topspace top /\ (f:A->B) x IN t}`]) THEN
  ASM_REWRITE_TAC[CONJ_ASSOC] THEN ANTS_TAC THENL
   [CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN CONJ_TAC THEN
    MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE THEN ASM_MESON_TAC[];
    REWRITE_TAC[GSYM CONJ_ASSOC; RIGHT_EXISTS_AND_THM] THEN
    REWRITE_TAC[EXISTS_OPEN_IN] THEN REWRITE_TAC[RIGHT_AND_EXISTS_THM] THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:A->bool`] THEN STRIP_TAC THEN
    MAP_EVERY EXISTS_TAC [`IMAGE (f:A->B) u`; `IMAGE (f:A->B) v`] THEN
    ASM_SIMP_TAC[] THEN REPEAT STRIP_TAC THEN
    REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET)) THEN
    ASM SET_TAC[]]);;

let URYSOHN_LEMMA = prove
 (`!(top:A topology) s t a b.
        a <= b /\ normal_space top /\
        closed_in top s /\ closed_in top t /\ DISJOINT s t
        ==> ?f. continuous_map
                    (top,subtopology euclideanreal (real_interval[a,b])) f /\
                (!x. x IN s ==> f x = a) /\
                (!x. x IN t ==> f x = b)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN
   `?f. continuous_map
         (top,subtopology euclideanreal (real_interval[&0,&1])) (f:A->real) /\
         (!x. x IN s ==> f x = &0) /\
         (!x. x IN t ==> f x = &1)`
  MP_TAC THENL
   [UNDISCH_THEN `a:real <= b` (K ALL_TAC);
    REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `f:A->real` THEN STRIP_TAC THEN
    EXISTS_TAC `\x. a + (b - a) * (f:A->real) x` THEN
    ASM_SIMP_TAC[] THEN CONJ_TAC THENL [ALL_TAC; REAL_ARITH_TAC] THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_ADD; CONTINUOUS_MAP_REAL_LMUL;
                 CONTINUOUS_MAP_REAL_CONST] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [SUBSET]) THEN
    REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IN_REAL_INTERVAL; REAL_LE_ADDR] THEN
    REWRITE_TAC[REAL_ARITH
      `a + (b - a) * y <= b <=> &0 <= (b - a) * (&1 - y)`] THEN
    ASM_SIMP_TAC[REAL_LE_MUL; REAL_SUB_LE]] THEN
  FIRST_ASSUM(MP_TAC o SPECL [`s:A->bool`; `topspace top DIFF t:A->bool`] o
    REWRITE_RULE[NORMAL_SPACE_ALT]) THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u DIFF t <=> s SUBSET u /\ DISJOINT s t`;
               CLOSED_IN_SUBSET] THEN
  DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
  SUBGOAL_THEN
   `?g:real->A->bool.
        g(&0) = u /\ g(&1) = topspace top DIFF t /\
        !x y. x IN {&k / &2 pow n | k <= 2 EXP n} /\
              y IN {&k / &2 pow n | k <= 2 EXP n} /\
              x < y
              ==> open_in top (g x) /\ open_in top (g y) /\
                  top closure_of (g x) SUBSET (g y)`
  STRIP_ASSUME_TAC THENL
   [MATCH_MP_TAC RECURSION_ON_DYADIC_FRACTIONS THEN
    ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE] THEN
    ASM_SIMP_TAC[SET_RULE `s SUBSET u DIFF t <=> s SUBSET u /\ DISJOINT s t`;
                 CLOSED_IN_SUBSET] THEN
    CONJ_TAC THENL
     [ASM_MESON_TAC[CLOSURE_OF_SUBSET; OPEN_IN_SUBSET; SUBSET_TRANS];
      ALL_TAC] THEN
    MAP_EVERY X_GEN_TAC [`w:A->bool`; `z:A->bool`] THEN STRIP_TAC THEN
    FIRST_ASSUM(MP_TAC o SPECL [`top closure_of w:A->bool`; `z:A->bool`] o
      REWRITE_RULE[NORMAL_SPACE_ALT]) THEN
    ASM_SIMP_TAC[CLOSED_IN_CLOSURE_OF] THEN ASM SET_TAC[];
    ALL_TAC] THEN
  ABBREV_TAC `dint = {&k / &2 pow n | k <= 2 EXP n}` THEN
  SUBGOAL_THEN `dint SUBSET real_interval[&0,&1]` ASSUME_TAC THENL
   [EXPAND_TAC "dint" THEN SIMP_TAC[SUBSET; IN_ELIM_THM; IN_REAL_INTERVAL] THEN
    REPEAT STRIP_TAC THEN
    ASM_SIMP_TAC[REAL_LE_LDIV_EQ; REAL_LE_RDIV_EQ; REAL_LT_POW2] THEN
    REWRITE_TAC[REAL_MUL_LZERO; REAL_POS; REAL_MUL_LID] THEN
    ASM_REWRITE_TAC[REAL_OF_NUM_LE; REAL_OF_NUM_POW];
    ALL_TAC] THEN
  ABBREV_TAC
   `f = \x:A. inf(&1 INSERT {r | r IN dint /\ x IN g r})` THEN
  EXISTS_TAC `f:A->real` THEN REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IN_REAL_INTERVAL] THEN
  SUBGOAL_THEN
   `!x. x IN topspace top ==> &0 <= (f:A->real) x /\ f x <= &1`
  ASSUME_TAC THENL
   [GEN_TAC THEN DISCH_TAC THEN EXPAND_TAC "f" THEN REWRITE_TAC[] THEN
    MATCH_MP_TAC REAL_INF_BOUNDS THEN
    REWRITE_TAC[FORALL_IN_INSERT; NOT_INSERT_EMPTY] THEN
    CONV_TAC REAL_RAT_REDUCE_CONV THEN
    UNDISCH_TAC `dint SUBSET real_interval[&0,&1]` THEN
    SIMP_TAC[IN_REAL_INTERVAL; IN_ELIM_THM; SUBSET];
    ASM_REWRITE_TAC[]] THEN
  SUBGOAL_THEN `&0 IN dint /\ &1 IN dint` STRIP_ASSUME_TAC THENL
   [EXPAND_TAC "dint" THEN REWRITE_TAC[IN_ELIM_THM] THEN
    CONJ_TAC THENL [EXISTS_TAC `0`; EXISTS_TAC `1`] THEN
    EXISTS_TAC `0` THEN CONV_TAC NUM_REDUCE_CONV THEN
    CONV_TAC REAL_RAT_REDUCE_CONV;
    ALL_TAC] THEN
  SUBGOAL_THEN `!r. r IN dint ==> open_in top ((g:real->A->bool) r)`
  ASSUME_TAC THENL
   [X_GEN_TAC `r:real` THEN DISCH_TAC THEN
    SUBGOAL_THEN `&0 < r \/ r < &1` MP_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
    SUBGOAL_THEN `r IN real_interval[&0,&1]` MP_TAC THENL
     [ASM SET_TAC[]; REWRITE_TAC[IN_REAL_INTERVAL] THEN REAL_ARITH_TAC];
    ALL_TAC] THEN
  REPEAT CONJ_TAC THENL
   [ALL_TAC;
    X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    SUBGOAL_THEN `(x:A) IN topspace top` ASSUME_TAC THENL
     [ASM_MESON_TAC[SUBSET; CLOSED_IN_SUBSET];
      ASM_SIMP_TAC[GSYM REAL_LE_ANTISYM]] THEN
    EXPAND_TAC "f" THEN MATCH_MP_TAC INF_LE_ELEMENT THEN CONJ_TAC THENL
     [EXISTS_TAC `&0` THEN REWRITE_TAC[FORALL_IN_INSERT; REAL_POS] THEN
      REWRITE_TAC[FORALL_IN_GSPEC] THEN
      UNDISCH_TAC `dint SUBSET real_interval[&0,&1]` THEN
      SIMP_TAC[IN_REAL_INTERVAL; IN_ELIM_THM; SUBSET];
      REWRITE_TAC[IN_INSERT; IN_ELIM_THM] THEN ASM SET_TAC[]];
    X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    SUBGOAL_THEN `(x:A) IN topspace top` ASSUME_TAC THENL
     [ASM_MESON_TAC[SUBSET; CLOSED_IN_SUBSET];
      ASM_SIMP_TAC[GSYM REAL_LE_ANTISYM]] THEN
    EXPAND_TAC "f" THEN MATCH_MP_TAC REAL_LE_INF THEN
    REWRITE_TAC[NOT_INSERT_EMPTY; FORALL_IN_INSERT; REAL_LE_REFL] THEN
    X_GEN_TAC `r:real` THEN REWRITE_TAC[IN_ELIM_THM] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN
    REWRITE_TAC[REAL_NOT_LE] THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`r:real`; `&1`]) THEN
    ASM_REWRITE_TAC[] THEN
    REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    MATCH_MP_TAC(SET_RULE
     `x IN t /\ g SUBSET g' ==> g' SUBSET u DIFF t ==> ~(x IN g)`) THEN
    ASM_MESON_TAC[OPEN_IN_SUBSET; CLOSURE_OF_SUBSET]] THEN
  MP_TAC(GEN `z:A`
   (SPEC `&1 INSERT {r | r IN dint /\ z IN (g:real->A->bool) r}` INF)) THEN
  FIRST_ASSUM(fun th ->
   REWRITE_TAC[REWRITE_RULE[] (GEN_REWRITE_RULE I [FUN_EQ_THM] th)]) THEN
  REWRITE_TAC[NOT_INSERT_EMPTY; FORALL_IN_INSERT] THEN
  DISCH_THEN(MP_TAC o MATCH_MP MONO_FORALL) THEN ANTS_TAC THENL
   [GEN_TAC THEN EXISTS_TAC `&0:real` THEN
    REWRITE_TAC[IN_ELIM_THM; REAL_POS] THEN
    UNDISCH_TAC `dint SUBSET real_interval[&0,&1]` THEN
    SIMP_TAC[IN_REAL_INTERVAL; IN_ELIM_THM; SUBSET];
    REWRITE_TAC[FORALL_AND_THM; IN_ELIM_THM]] THEN
  DISCH_THEN(CONJUNCTS_THEN2 STRIP_ASSUME_TAC (LABEL_TAC "*")) THEN
  SUBGOAL_THEN
   `!z x. x IN dint /\ ~(z IN (g:real->A->bool) x) ==> x <= (f:A->real) z`
  ASSUME_TAC THENL
   [MAP_EVERY X_GEN_TAC [`z:A`; `r:real`] THEN STRIP_TAC THEN
    REMOVE_THEN "*" MATCH_MP_TAC THEN CONJ_TAC THENL
     [UNDISCH_TAC `dint SUBSET real_interval[&0,&1]` THEN
      ASM_SIMP_TAC[IN_REAL_INTERVAL; IN_ELIM_THM; SUBSET];
      X_GEN_TAC `s:real` THEN STRIP_TAC] THEN
    ONCE_REWRITE_TAC[GSYM REAL_NOT_LT] THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`s:real`; `r:real`]) THEN
    ASM_REWRITE_TAC[] THEN
    REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    MP_TAC(ISPECL [`top:A topology`; `(g:real->A->bool) s`]
      CLOSURE_OF_SUBSET) THEN
    ASM_SIMP_TAC[OPEN_IN_SUBSET] THEN ASM SET_TAC[];
    REMOVE_THEN "*" (K ALL_TAC)] THEN
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[CONTINUOUS_MAP_TO_METRIC; IN_MBALL; REAL_EUCLIDEAN_METRIC] THEN
  X_GEN_TAC `x:A` THEN DISCH_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  REWRITE_TAC[IN_UNIV] THEN
  SUBGOAL_THEN
   `(!y d. &0 < y /\ y <= &1 /\ &0 < d
           ==> ?r. r IN dint /\ r < y /\ abs(r - y) < d) /\
    (!y d. &0 <= y /\ y < &1 /\ &0 < d
           ==> ?r. r IN dint /\ y < r /\ abs(r - y) < d)`
  ASSUME_TAC THENL
   [REPEAT STRIP_TAC THENL
     [MP_TAC(ISPECL [`&2`; `y:real`; `d:real`]
        PADIC_RATIONAL_APPROXIMATION_STRADDLE_POS) THEN ANTS_TAC
      THENL [ASM_REAL_ARITH_TAC; REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
      MAP_EVERY X_GEN_TAC [`n:num`; `q:num`; `r:num`] THEN STRIP_TAC THEN
      EXISTS_TAC `&q / &2 pow n` THEN CONJ_TAC THENL
       [EXPAND_TAC "dint"; ASM_REAL_ARITH_TAC] THEN
      REWRITE_TAC[IN_ELIM_THM] THEN
      MAP_EVERY EXISTS_TAC [`q:num`; `n:num`] THEN ASM_REWRITE_TAC[] THEN
      SUBGOAL_THEN `&q / &2 pow n <= &1` MP_TAC THENL
       [ASM_REAL_ARITH_TAC; SIMP_TAC[REAL_LE_LDIV_EQ; REAL_LT_POW2]] THEN
      REWRITE_TAC[REAL_MUL_LID; REAL_OF_NUM_POW; REAL_OF_NUM_LE];
      MP_TAC(ISPECL [`&2`; `y:real`; `d:real`]
        PADIC_RATIONAL_APPROXIMATION_STRADDLE_POS_LE) THEN ANTS_TAC
      THENL [ASM_REAL_ARITH_TAC; REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
      MAP_EVERY X_GEN_TAC [`n:num`; `q:num`; `r:num`] THEN STRIP_TAC THEN
      EXISTS_TAC `min (&1) (&r / &2 pow n)` THEN CONJ_TAC THENL
       [REWRITE_TAC[real_min]; ASM_REAL_ARITH_TAC] THEN
      COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
      EXPAND_TAC "dint" THEN REWRITE_TAC[IN_ELIM_THM] THEN
      MAP_EVERY EXISTS_TAC [`r:num`; `n:num`] THEN ASM_REWRITE_TAC[] THEN
      SUBGOAL_THEN `&r / &2 pow n <= &1` MP_TAC THENL
       [ASM_REAL_ARITH_TAC; SIMP_TAC[REAL_LE_LDIV_EQ; REAL_LT_POW2]] THEN
      REWRITE_TAC[REAL_MUL_LID; REAL_OF_NUM_POW; REAL_OF_NUM_LE]];
    ALL_TAC] THEN
  ASM_CASES_TAC `(f:A->real) x = &0` THENL
   [FIRST_X_ASSUM(MP_TAC o SPECL [`(f:A->real) x`; `e / &2`] o CONJUNCT2) THEN
    ASM_SIMP_TAC[REAL_LT_01; REAL_HALF] THEN
    DISCH_THEN(X_CHOOSE_THEN `r:real` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `(g:real->A->bool) r` THEN ASM_SIMP_TAC[] THEN CONJ_TAC THENL
     [MATCH_MP_TAC(TAUT `(~p ==> F) ==> p`) THEN DISCH_TAC THEN
      SUBGOAL_THEN `r <= (f:A->real) x` MP_TAC THENL
       [FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC[]; ASM_REAL_ARITH_TAC];
      X_GEN_TAC `y:A` THEN DISCH_TAC THEN
      SUBGOAL_THEN `(f:A->real) y <= r` MP_TAC THENL
       [FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC[]; ALL_TAC] THEN
      SUBGOAL_THEN `&0 <= (f:A->real) y /\ f y <= &1` MP_TAC THENL
       [FIRST_X_ASSUM MATCH_MP_TAC; ASM_REAL_ARITH_TAC] THEN
      ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET]];
    ALL_TAC] THEN
  ASM_CASES_TAC `(f:A->real) x = &1` THENL
   [FIRST_ASSUM(MP_TAC o SPECL [`(f:A->real) x`; `e / &2`] o CONJUNCT1) THEN
    ANTS_TAC THENL [ASM SIMP_TAC[] THEN ASM_REAL_ARITH_TAC; ALL_TAC] THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `r:real` THEN
    STRIP_TAC THEN
    EXISTS_TAC `topspace top DIFF top closure_of (g:real->A->bool) r` THEN
    ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE; CLOSED_IN_CLOSURE_OF] THEN
    ASM_REWRITE_TAC[IN_DIFF] THEN CONJ_TAC THENL
     [DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPECL [`r:real`; `&1 - r`] o CONJUNCT2) THEN
      ANTS_TAC THENL
       [ASM_REWRITE_TAC[REAL_SUB_LT] THEN
        ASM_MESON_TAC[SUBSET; IN_REAL_INTERVAL];
        DISCH_THEN(X_CHOOSE_THEN `r':real` STRIP_ASSUME_TAC)] THEN
      SUBGOAL_THEN `(f:A->real) x <= r'` MP_TAC THENL
       [FIRST_X_ASSUM MATCH_MP_TAC THEN ASM SET_TAC[];
        ASM_REAL_ARITH_TAC];
      X_GEN_TAC `y:A` THEN STRIP_TAC THEN
      SUBGOAL_THEN `r <= (f:A->real) y` MP_TAC THENL
       [FIRST_X_ASSUM MATCH_MP_TAC THEN
        MP_TAC(ISPECL [`top:A topology`; `(g:real->A->bool) r`]
                CLOSURE_OF_SUBSET) THEN
        ASM_SIMP_TAC[OPEN_IN_SUBSET] THEN ASM SET_TAC[];
        SUBGOAL_THEN `(f:A->real) y <= &1` MP_TAC THENL
         [ASM_MESON_TAC[SUBSET; IN_REAL_INTERVAL]; ASM_REAL_ARITH_TAC]]];
    ALL_TAC] THEN
  FIRST_ASSUM(CONJUNCTS_THEN(MP_TAC o SPECL [`(f:A->real) x`; `e / &2`])) THEN
  SUBGOAL_THEN `&0 <= (f:A->real) x /\ f x <= &1` STRIP_ASSUME_TAC THENL
   [ASM_MESON_TAC[SUBSET; IN_REAL_INTERVAL]; ALL_TAC] THEN
  ANTS_TAC THENL [ASM_REAL_ARITH_TAC; REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `r':real` THEN STRIP_TAC THEN
  ANTS_TAC THENL [ASM_REAL_ARITH_TAC; REWRITE_TAC[LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `r:real` THEN STRIP_TAC THEN
  EXISTS_TAC `(g:real->A->bool) r' DIFF top closure_of g r` THEN
  ASM_SIMP_TAC[IN_DIFF; OPEN_IN_DIFF; CLOSED_IN_CLOSURE_OF] THEN
  REPEAT CONJ_TAC THENL
   [MATCH_MP_TAC(TAUT `(~p ==> F) ==> p`) THEN DISCH_TAC THEN
    SUBGOAL_THEN `r' <= (f:A->real) x` MP_TAC THENL
     [FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC[]; ASM_REAL_ARITH_TAC];
    DISCH_TAC THEN FIRST_X_ASSUM(MP_TAC o
      SPECL [`r:real`; `f(x:A) - r:real`] o CONJUNCT2) THEN
    ANTS_TAC THENL
     [ASM_REWRITE_TAC[REAL_SUB_LT] THEN CONJ_TAC THENL
       [ASM_MESON_TAC[SUBSET; IN_REAL_INTERVAL]; ASM_REAL_ARITH_TAC];
      DISCH_THEN(X_CHOOSE_THEN `r'':real` STRIP_ASSUME_TAC)] THEN
    SUBGOAL_THEN `(f:A->real) x <= r''` MP_TAC THENL
     [FIRST_X_ASSUM MATCH_MP_TAC THEN ASM SET_TAC[];
      ASM_REAL_ARITH_TAC];
    X_GEN_TAC `y:A` THEN STRIP_TAC THEN
    SUBGOAL_THEN `(y:A) IN topspace top` ASSUME_TAC THENL
     [ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET]; ALL_TAC] THEN
    SUBGOAL_THEN `&0 <= (f:A->real) y /\ f y <= &1` STRIP_ASSUME_TAC THENL
     [FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC[]; ALL_TAC] THEN
    SUBGOAL_THEN `r <= (f:A->real) y /\ f y <= r'` MP_TAC THENL
     [ALL_TAC; ASM_REAL_ARITH_TAC] THEN
    CONJ_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
    ASM_REWRITE_TAC[] THEN
    MP_TAC(ISPECL [`top:A topology`; `(g:real->A->bool) r`]
              CLOSURE_OF_SUBSET) THEN
    ASM_SIMP_TAC[OPEN_IN_SUBSET] THEN ASM SET_TAC[]]);;

let URYSOHN_LEMMA_ALT = prove
 (`!(top:A topology) s t a b.
        normal_space top /\ closed_in top s /\ closed_in top t /\ DISJOINT s t
        ==> ?f. continuous_map(top,euclideanreal) f /\
                (!x. x IN s ==> f x = a) /\
                (!x. x IN t ==> f x = b)`,
  GEN_TAC THEN ONCE_REWRITE_TAC[MESON[]
   `(!s t a b. P s t a b) <=> (!a b s t. P s t a b)`] THEN
  MATCH_MP_TAC REAL_WLOG_LE THEN CONJ_TAC THENL
   [REPEAT GEN_TAC THEN
    GEN_REWRITE_TAC LAND_CONV [SWAP_FORALL_THM] THEN
    REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN MESON_TAC[DISJOINT_SYM];
    REWRITE_TAC[RIGHT_IMP_FORALL_THM; IMP_IMP] THEN REPEAT GEN_TAC THEN
    DISCH_THEN(MP_TAC o MATCH_MP URYSOHN_LEMMA) THEN
    REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN MESON_TAC[]]);;

let NORMAL_SPACE_EQ_URYSOHN_GEN_ALT = prove
 (`!top:A topology a b.
     ~(a = b)
     ==> (normal_space top <=>
          !s t. closed_in top s /\ closed_in top t /\ DISJOINT s t
                ==> ?f. continuous_map (top,euclideanreal) f /\
                        (!x. x IN s ==> f x = a) /\
                        (!x. x IN t ==> f x = b))`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN ASM_SIMP_TAC[URYSOHN_LEMMA_ALT] THEN
  REWRITE_TAC[normal_space] THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `s:A->bool` THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `t:A->bool` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `f:A->real` THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC
   [`{x:A | x IN topspace top /\
            f x IN mball real_euclidean_metric (a,abs(a - b) / &2)}`;
    `{x:A | x IN topspace top /\
            f x IN mball real_euclidean_metric (b,abs(a - b) / &2)}`] THEN
  ONCE_REWRITE_TAC[CONJ_ASSOC] THEN CONJ_TAC THENL
   [CONJ_TAC THEN MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
    EXISTS_TAC `euclideanreal` THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[OPEN_IN_MBALL; GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC];
    ONCE_REWRITE_TAC[CONJ_ASSOC] THEN CONJ_TAC THENL
     [ASM_SIMP_TAC[SUBSET; IN_ELIM_THM; CENTRE_IN_MBALL_EQ] THEN
      ASM_REWRITE_TAC[REAL_ARITH `&0 < abs(a - b) / &2 <=> ~(a = b)`] THEN
      REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
      ASM_SIMP_TAC[GSYM SUBSET; CLOSED_IN_SUBSET];
      SIMP_TAC[EXTENSION; DISJOINT; IN_INTER; NOT_IN_EMPTY; IN_ELIM_THM;
               mball; REAL_EUCLIDEAN_METRIC] THEN
      REAL_ARITH_TAC]]);;

let NORMAL_SPACE_EQ_URYSOHN_GEN = prove
 (`!top:A topology a b.
     a < b
     ==> (normal_space top <=>
          !s t. closed_in top s /\ closed_in top t /\ DISJOINT s t
                ==> ?f. continuous_map
                         (top,
                          subtopology euclideanreal (real_interval[a,b])) f /\
                        (!x. x IN s ==> f x = a) /\
                        (!x. x IN t ==> f x = b))`,
  REPEAT STRIP_TAC THEN EQ_TAC THEN
  ASM_SIMP_TAC[URYSOHN_LEMMA; REAL_LT_IMP_LE] THEN
  ASM_SIMP_TAC[NORMAL_SPACE_EQ_URYSOHN_GEN_ALT; REAL_LT_IMP_NE] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
  REPEAT(MATCH_MP_TAC MONO_FORALL THEN GEN_TAC) THEN MESON_TAC[]);;

let NORMAL_SPACE_EQ_URYSOHN_ALT = prove
 (`!top:A topology.
     normal_space top <=>
     !s t. closed_in top s /\ closed_in top t /\ DISJOINT s t
           ==> ?f. continuous_map (top,euclideanreal) f /\
                   (!x. x IN s ==> f x = &0) /\
                   (!x. x IN t ==> f x = &1)`,
  GEN_TAC THEN MATCH_MP_TAC NORMAL_SPACE_EQ_URYSOHN_GEN_ALT THEN
  CONV_TAC REAL_RAT_REDUCE_CONV);;

let NORMAL_SPACE_EQ_URYSOHN = prove
 (`!top:A topology.
     normal_space top <=>
     !s t. closed_in top s /\ closed_in top t /\ DISJOINT s t
           ==> ?f. continuous_map
                    (top,subtopology euclideanreal (real_interval[&0,&1])) f /\
                   (!x. x IN s ==> f x = &0) /\
                   (!x. x IN t ==> f x = &1)`,
  GEN_TAC THEN MATCH_MP_TAC NORMAL_SPACE_EQ_URYSOHN_GEN THEN
  REWRITE_TAC[REAL_LT_01]);;

let TIETZE_EXTENSION_CLOSED_REAL_INTERVAL = prove
 (`!top f:A->real s a b.
        normal_space top /\ closed_in top s /\ a <= b /\
        continuous_map (subtopology top s,euclideanreal) f /\
        (!x. x IN s ==> f x IN real_interval[a,b])
        ==> ?g. continuous_map(top,euclideanreal) g /\
                (!x. x IN topspace top ==> g x IN real_interval[a,b]) /\
                (!x. x IN s ==> g x = f x)`,
  REWRITE_TAC[IN_REAL_INTERVAL] THEN REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `?c. &0 < c /\ !x. x IN s ==> abs((f:A->real) x) <= c`
  STRIP_ASSUME_TAC THENL
   [EXISTS_TAC `max (abs a) (abs b) + &1` THEN
    ASM_SIMP_TAC[REAL_ARITH
     `a <= x /\ x <= b ==> abs x <= max (abs a) (abs b) + &1`] THEN
    REAL_ARITH_TAC;
    ALL_TAC] THEN
  SUBGOAL_THEN
   `?g:num->A->real.
        (!n. continuous_map(top,euclideanreal) (g n) /\
             !x. x IN s ==> abs(f x - g n x) <= c * (&2 / &3) pow n) /\
        (!n x. x IN topspace top
               ==> abs(g(SUC n) x - g n x) <= c * (&2 / &3) pow n / &3)`
  MP_TAC THENL
   [MATCH_MP_TAC DEPENDENT_CHOICE THEN CONJ_TAC THENL
     [EXISTS_TAC `(\x. &0):A->real` THEN
      REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST] THEN
      ASM_REWRITE_TAC[real_pow; REAL_MUL_RID; REAL_SUB_RZERO];
      MAP_EVERY X_GEN_TAC [`n:num`; `h:A->real`] THEN STRIP_TAC] THEN
    MP_TAC(ISPECL
     [`top:A topology`;
      `{x | x IN s /\ ((f:A->real) x - h x) IN
                      {y | y <= --(c / &3 * (&2 / &3) pow n)}}`;
      `{x | x IN s /\ ((f:A->real) x - h x) IN
                      {y | y >= c / &3 * (&2 / &3) pow n}}`;
      `--(c / &3 * (&2 / &3) pow n)`; `c / &3 * (&2 / &3) pow n`]
     URYSOHN_LEMMA) THEN
    REWRITE_TAC[REAL_ARITH `--(c / &3 * x) <= c / &3 * x <=> &0 <= c * x`] THEN
    SUBGOAL_THEN `&0 < c * (&2 / &3) pow n` ASSUME_TAC THENL
     [MATCH_MP_TAC REAL_LT_MUL THEN ASM_REWRITE_TAC[] THEN
      MATCH_MP_TAC REAL_POW_LT THEN CONV_TAC REAL_RAT_REDUCE_CONV;
      ASM_SIMP_TAC[REAL_LT_IMP_LE]] THEN
    ANTS_TAC THENL
     [REWRITE_TAC[CONJ_ASSOC] THEN CONJ_TAC THENL
       [SUBGOAL_THEN `s:A->bool = topspace(subtopology top s)` SUBST1_TAC THENL
         [ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; CLOSED_IN_SUBSET;
                       SET_RULE `s = u INTER s <=> s SUBSET u`];
          CONJ_TAC THEN MATCH_MP_TAC CLOSED_IN_TRANS_FULL THEN
          EXISTS_TAC `s:A->bool` THEN ASM_REWRITE_TAC[] THEN
          MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE THEN
          EXISTS_TAC `euclideanreal` THEN
          ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_SUB; GSYM REAL_CLOSED_IN;
                       CONTINUOUS_MAP_FROM_SUBTOPOLOGY] THEN
          REWRITE_TAC[REAL_CLOSED_HALFSPACE_LE; REAL_CLOSED_HALFSPACE_GE]];
        SIMP_TAC[DISJOINT; EXTENSION; IN_INTER; NOT_IN_EMPTY; IN_ELIM_THM] THEN
        ASM_REAL_ARITH_TAC];
      REWRITE_TAC[IN_ELIM_THM; LEFT_IMP_EXISTS_THM] THEN
      REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
      REWRITE_TAC[IN_REAL_INTERVAL; GSYM REAL_ABS_BOUNDS; IN_ELIM_THM] THEN
      X_GEN_TAC `g:A->real` THEN STRIP_TAC THEN
      EXISTS_TAC `\x. h x + (g:A->real) x` THEN
      ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_ADD; REAL_ADD_SUB] THEN
      ASM_REWRITE_TAC[REAL_ARITH `x * y / &3 = x / &3 * y`] THEN
      X_GEN_TAC `x:A` THEN DISCH_TAC THEN REWRITE_TAC[real_pow] THEN
      REPEAT(FIRST_X_ASSUM(MP_TAC o SPEC `x:A`)) THEN
      FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
      ASM_SIMP_TAC[SUBSET] THEN ASM_REAL_ARITH_TAC];
    REWRITE_TAC[LEFT_IMP_EXISTS_THM; FORALL_AND_THM]] THEN
  X_GEN_TAC `g:num->A->real` THEN STRIP_TAC THEN
  MP_TAC(ISPECL
   [`top:A topology`; `real_euclidean_metric`; `g:num->A->real`]
   CONTINUOUS_MAP_UNIFORMLY_CAUCHY_LIMIT) THEN
  ASM_REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY; MTOPOLOGY_REAL_EUCLIDEAN_METRIC;
                  EVENTUALLY_TRUE; MCOMPLETE_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC] THEN ANTS_TAC THENL
   [X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    MP_TAC(ISPECL [`&2 / &3`; `e / c:real`] ARCH_EVENTUALLY_POW_INV) THEN
    CONV_TAC REAL_RAT_REDUCE_CONV THEN ASM_SIMP_TAC[REAL_LT_DIV] THEN
    REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN MATCH_MP_TAC MONO_EXISTS THEN
    X_GEN_TAC `N:num` THEN DISCH_TAC THEN MATCH_MP_TAC WLOG_LT THEN
    ASM_REWRITE_TAC[REAL_SUB_REFL; REAL_ABS_NUM] THEN
    CONJ_TAC THENL [ASM_MESON_TAC[REAL_ABS_SUB]; ALL_TAC] THEN
    MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN STRIP_TAC THEN
    X_GEN_TAC `x:A` THEN STRIP_TAC THEN
    TRANS_TAC REAL_LET_TRANS
     `abs(sum(m..n - 1) (\n. g (SUC n) (x:A) - g n x))` THEN
    CONJ_TAC THENL
     [REWRITE_TAC[SUM_DIFFS_ALT; ADD1] THEN
      FIRST_ASSUM(MP_TAC o MATCH_MP (ARITH_RULE
       `m < n ==> m <= n - 1 /\ n - 1 + 1 = n`)) THEN
      SIMP_TAC[REAL_LE_REFL];
      TRANS_TAC REAL_LET_TRANS
       `sum (m..n-1) (\j. c * (&2 / &3) pow j / &3)` THEN
      ASM_SIMP_TAC[SUM_ABS_LE; FINITE_NUMSEG] THEN
      REWRITE_TAC[real_div; SUM_LMUL; SUM_RMUL; SUM_GP] THEN
      CONV_TAC REAL_RAT_REDUCE_CONV THEN
      COND_CASES_TAC THENL [ASM_ARITH_TAC; ALL_TAC] THEN
      REWRITE_TAC[REAL_ARITH `c * (x * &3) * &1 / &3 = x * c`] THEN
      ASM_SIMP_TAC[GSYM REAL_LT_RDIV_EQ] THEN
      MATCH_MP_TAC(REAL_ARITH `abs x < y /\ &0 <= z ==> x - z < y`) THEN
      ASM_SIMP_TAC[] THEN MATCH_MP_TAC REAL_POW_LE THEN
      CONV_TAC REAL_RAT_REDUCE_CONV];
    DISCH_THEN(X_CHOOSE_THEN `h:A->real` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `\x. max a (min ((h:A->real) x) b)` THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_MAX; CONTINUOUS_MAP_REAL_MIN;
                 CONTINUOUS_MAP_REAL_CONST] THEN
    CONJ_TAC THEN X_GEN_TAC `x:A` THEN DISCH_TAC THENL
     [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
    MATCH_MP_TAC(REAL_ARITH
     `a <= x /\ x <= b /\ y = x ==> max a (min y b) = x`) THEN
    ASM_SIMP_TAC[] THEN
    MATCH_MP_TAC(ISPEC `sequentially` LIMIT_METRIC_UNIQUE) THEN
    MAP_EVERY EXISTS_TAC
     [`real_euclidean_metric`; `\n. (g:num->A->real) n x`] THEN
    REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY; LIMIT_METRIC] THEN
    REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
    FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
    REWRITE_TAC[SUBSET] THEN DISCH_THEN(MP_TAC o SPEC `x:A`) THEN
    ASM_REWRITE_TAC[] THEN DISCH_TAC THEN CONJ_TAC THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN
      ASM_REWRITE_TAC[] THEN
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
      ASM_SIMP_TAC[];
      MP_TAC(ISPECL [`&2 / &3`; `e / c:real`] ARCH_EVENTUALLY_POW_INV) THEN
      CONV_TAC REAL_RAT_REDUCE_CONV THEN ASM_SIMP_TAC[REAL_LT_DIV] THEN
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
      ASM_SIMP_TAC[REAL_LT_RDIV_EQ] THEN X_GEN_TAC `n:num` THEN
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] REAL_LET_TRANS) THEN
      REWRITE_TAC[REAL_ARITH
       `abs x * c = c * (if &0 <= x then x else --x)`] THEN
      ASM_SIMP_TAC[REAL_POW_LE; REAL_ARITH `&0 <= &2 / &3`]]]);;

let TIETZE_EXTENSION_REALINTERVAL = prove
 (`!top f:A->real s t.
        normal_space top /\ closed_in top s /\
        is_realinterval t /\ ~(t = {}) /\
        continuous_map (subtopology top s,euclideanreal) f /\
        (!x. x IN s ==> f x IN t)
        ==> ?g. continuous_map(top,euclideanreal) g /\
                (!x. x IN topspace top ==> g x IN t) /\
                (!x. x IN s ==> g x = f x)`,
  GEN_TAC THEN GEN_REWRITE_TAC I [SWAP_FORALL_THM] THEN
  GEN_TAC THEN GEN_REWRITE_TAC I [SWAP_FORALL_THM] THEN
  MATCH_MP_TAC(MESON[]
   `((!t. real_bounded t ==> P t) ==> (!t. P t)) /\
    (!t. real_bounded t ==> P t)
    ==> !t. P t`) THEN
  CONJ_TAC THENL
   [DISCH_TAC THEN
    MAP_EVERY X_GEN_TAC [`t:real->bool`; `f:A->real`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `IMAGE (\x. x / (&1 + abs x)) t`) THEN
    ASM_REWRITE_TAC[IS_REALINTERVAL_SHRINK; REAL_BOUNDED_SHRINK] THEN
    DISCH_THEN(MP_TAC o SPEC `(\x. x / (&1 + abs x)) o (f:A->real)`) THEN
    ASM_REWRITE_TAC[IMAGE_EQ_EMPTY] THEN ANTS_TAC THENL
     [CONJ_TAC THENL [ALL_TAC; REWRITE_TAC[o_DEF] THEN ASM SET_TAC[]] THEN
      FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ]
        CONTINUOUS_MAP_COMPOSE)) THEN
      REWRITE_TAC[REWRITE_RULE[CONTINUOUS_MAP_IN_SUBTOPOLOGY]
        CONTINUOUS_MAP_REAL_SHRINK];

      DISCH_THEN(X_CHOOSE_THEN `g:A->real` STRIP_ASSUME_TAC) THEN
      EXISTS_TAC `(\x. x / (&1 - abs x)) o (g:A->real)` THEN
      ASM_SIMP_TAC[o_THM; REAL_GROW_SHRINK] THEN CONJ_TAC THENL
       [MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
        EXISTS_TAC `subtopology euclideanreal (real_interval(-- &1,&1))` THEN
        REWRITE_TAC[CONTINUOUS_MAP_REAL_GROW] THEN
        ASM_REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
        FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
         `(!x. x IN t ==> g x IN IMAGE h u) ==> (!x. x IN u ==> h x IN v)
          ==> IMAGE g t SUBSET v`)) THEN
        REWRITE_TAC[IN_REAL_INTERVAL; REAL_BOUNDS_LT; REAL_SHRINK_RANGE];
        FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
         `(!x. x IN u ==> g x IN IMAGE h t)
          ==> (!x. x IN t ==> f(h x) = x)
              ==> (!x. x IN u ==> f(g x) IN t)`)) THEN
        REWRITE_TAC[REAL_GROW_SHRINK]]];
    X_GEN_TAC `t:real->bool` THEN DISCH_TAC THEN
    X_GEN_TAC `f:A->real` THEN STRIP_TAC] THEN
  MP_TAC(SPEC `euclideanreal closure_of t` REAL_COMPACT_IS_REALINTERVAL) THEN
  ASM_SIMP_TAC[IS_REALINTERVAL_CLOSURE_OF] THEN
  REWRITE_TAC[REAL_COMPACT_EQ_BOUNDED_CLOSED; REAL_CLOSED_IN] THEN
  REWRITE_TAC[CLOSED_IN_CLOSURE_OF; GSYM MBOUNDED_REAL_EUCLIDEAN_METRIC] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[SYM MBOUNDED_REAL_EUCLIDEAN_METRIC]) THEN
  ASM_SIMP_TAC[MBOUNDED_CLOSURE_OF; GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  MAP_EVERY X_GEN_TAC [`a:real`; `b:real`] THEN
  ASM_CASES_TAC `real_interval[a,b] = {}` THEN
  ASM_SIMP_TAC[CLOSURE_OF_EQ_EMPTY; TOPSPACE_EUCLIDEANREAL; SUBSET_UNIV] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[REAL_INTERVAL_NE_EMPTY]) THEN DISCH_TAC THEN
  MP_TAC(ISPECL[`top:A topology`; `f:A->real`; `s:A->bool`; `a:real`; `b:real`]
        TIETZE_EXTENSION_CLOSED_REAL_INTERVAL) THEN
  ASM_REWRITE_TAC[] THEN ANTS_TAC THENL
   [ASM_MESON_TAC[CLOSURE_OF_SUBSET; SUBSET; IN_UNIV; TOPSPACE_EUCLIDEANREAL];
    DISCH_THEN(X_CHOOSE_THEN `g:A->real` STRIP_ASSUME_TAC)] THEN
  MP_TAC(ISPECL
   [`top:A topology`;
    `{x | x IN topspace top /\
          (g:A->real) x IN euclideanreal closure_of t DIFF t}`;
    `s:A->bool`; `&0`; `&1`] URYSOHN_LEMMA) THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; REAL_POS] THEN
  ANTS_TAC THENL
   [CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
    MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE THEN
    EXISTS_TAC `euclideanreal` THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC COMPACT_IN_IMP_CLOSED_IN THEN
    REWRITE_TAC[HAUSDORFF_SPACE_EUCLIDEANREAL] THEN
    MATCH_MP_TAC FINITE_IMP_COMPACT_IN THEN
    REWRITE_TAC[TOPSPACE_EUCLIDEANREAL; SUBSET_UNIV] THEN
    MATCH_MP_TAC FINITE_SUBSET THEN EXISTS_TAC `{a:real,b}` THEN
    REWRITE_TAC[FINITE_INSERT; FINITE_EMPTY] THEN
    MATCH_MP_TAC(SET_RULE `s DIFF u SUBSET t ==> s DIFF t SUBSET u`) THEN
    REWRITE_TAC[GSYM REAL_OPEN_CLOSED_INTERVAL] THEN
    ASM_SIMP_TAC[GSYM REAL_OPEN_SUBSET_CLOSURE_OF_REALINTERVAL_ALT;
                 REAL_OPEN_REAL_INTERVAL; REAL_INTERVAL_OPEN_SUBSET_CLOSED];
    REWRITE_TAC[LEFT_IMP_EXISTS_THM; SUBSET; FORALL_IN_IMAGE] THEN
    X_GEN_TAC `h:A->real` THEN
    REWRITE_TAC[IN_REAL_INTERVAL; IN_ELIM_THM] THEN
    REWRITE_TAC[IN_DIFF] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    DISCH_THEN(X_CHOOSE_TAC `z:real`) THEN
    EXISTS_TAC `\x. z + (h:A->real) x * (g x - z)` THEN
    ASM_SIMP_TAC[REAL_ARITH `z + &1 * (x - z) = x`] THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_ADD; CONTINUOUS_MAP_REAL_SUB;
      CONTINUOUS_MAP_REAL_MUL; CONTINUOUS_MAP_REAL_CONST; ETA_AX] THEN
    X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    ASM_CASES_TAC `(g:A->real) x IN t` THEN
    ASM_SIMP_TAC[REAL_MUL_LZERO; REAL_ADD_RID] THEN
    SUBGOAL_THEN
     `z <= z + h x * (g x - z) /\ z + h x * ((g:A->real) x - z) <= g x \/
      g x <= z + h x * (g x - z) /\ z + h x * (g x - z) <= z`
    MP_TAC THENL [ALL_TAC; ASM_MESON_TAC[is_realinterval]] THEN
    MATCH_MP_TAC(REAL_ARITH
     `abs(x - a) <= abs(b - a) /\ abs(x - b) <= abs(b - a)
      ==> a <= x /\ x <= b \/ b <= x /\ x <= a`) THEN
    REWRITE_TAC[REAL_ARITH `(z + h * (g - z)) - g = --(&1 - h) * (g - z)`] THEN
    REWRITE_TAC[REAL_ADD_SUB; REAL_ABS_MUL; REAL_ABS_NEG] THEN
    CONJ_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM REAL_MUL_LID] THEN
    MATCH_MP_TAC REAL_LE_RMUL THEN REWRITE_TAC[REAL_ABS_POS] THEN
    ASM_SIMP_TAC[REAL_ARITH
     `&0 <= x /\ x <= &1 ==> abs x <= &1 /\ abs(&1 - x) <= &1`]]);;

let NORMAL_SPACE_EQ_TIETZE = prove
 (`!top:A topology.
        normal_space top <=>
        !f s. closed_in top s /\
              continuous_map (subtopology top s,euclideanreal) f
              ==> ?g. continuous_map(top,euclideanreal) g /\
                      !x. x IN s ==> g x = f x`,
  GEN_TAC THEN EQ_TAC THENL
   [REPEAT STRIP_TAC THEN
    MP_TAC(ISPECL [`top:A topology`; `f:A->real`; `s:A->bool`; `(:real)`]
        TIETZE_EXTENSION_REALINTERVAL) THEN
    ASM_REWRITE_TAC[IS_REALINTERVAL_UNIV; IN_UNIV; UNIV_NOT_EMPTY];
    DISCH_TAC THEN REWRITE_TAC[NORMAL_SPACE_EQ_URYSOHN_ALT] THEN
    MAP_EVERY X_GEN_TAC [`s:A->bool`; `t:A->bool`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL
     [`(\x. if x IN s then &0 else &1):A->real`; `s UNION t:A->bool`]) THEN
    RULE_ASSUM_TAC(REWRITE_RULE[SET_RULE
     `DISJOINT s t <=> !x. x IN t ==> ~(x IN s)`]) THEN
    ASM_SIMP_TAC[CLOSED_IN_UNION; FORALL_IN_UNION] THEN
    DISCH_THEN MATCH_MP_TAC THEN
    REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
    X_GEN_TAC `c:real->bool` THEN STRIP_TAC THEN
    MATCH_MP_TAC CLOSED_IN_SUBSET_TOPSPACE THEN
    REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
    CONJ_TAC THENL [ALL_TAC; SET_TAC[]] THEN
    ONCE_REWRITE_TAC[COND_RAND] THEN ONCE_REWRITE_TAC[COND_RATOR] THEN
    REWRITE_TAC[IN_INTER; GSYM CONJ_ASSOC] THEN
    ONCE_REWRITE_TAC[COND_RAND] THEN SIMP_TAC[IN_UNION] THEN
    ASM_SIMP_TAC[COND_EXPAND; TAUT
     `(q ==> ~p) ==> ((~p \/ z) /\ (p \/ q /\ w) <=> p /\ z \/ q /\ w)`] THEN
    ASM_SIMP_TAC[CLOSED_IN_SUBSET; SET_RULE
     `s SUBSET u /\ t SUBSET u
      ==> {x | x IN u /\ (x IN s /\ P \/ x IN t /\ Q)} =
          {x | x IN s /\ P} UNION {x | x IN t /\ Q}`] THEN
    MAP_EVERY ASM_CASES_TAC [`(&0:real) IN c`; `(&1:real) IN c`] THEN
    ASM_REWRITE_TAC[EMPTY_GSPEC; CLOSED_IN_EMPTY; UNION_EMPTY; IN_GSPEC] THEN
    ASM_SIMP_TAC[CLOSED_IN_UNION]]);;

(* ------------------------------------------------------------------------- *)
(* Completely regular spaces.                                                *)
(* ------------------------------------------------------------------------- *)

let completely_regular_space = new_definition
 `completely_regular_space (top:A topology) <=>
    !s x. closed_in top s /\ x IN topspace top DIFF s
          ==> ?f. continuous_map
                   (top,subtopology euclideanreal (real_interval[&0,&1])) f /\
                  f(x) = &0 /\ !x. x IN s ==> f x = &1`;;

let HOMEOMORPHIC_COMPLETELY_REGULAR_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (completely_regular_space top <=> completely_regular_space top')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  REWRITE_TAC[HOMEOMORPHIC_MAPS_MAP; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:A->B`; `g:B->A`] THEN STRIP_TAC THEN
  REWRITE_TAC[completely_regular_space; IN_DIFF] THEN
  EQ_TAC THEN DISCH_TAC THENL
   [MAP_EVERY X_GEN_TAC [`d:B->bool`; `y:B`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`IMAGE (g:B->A) d`; `(g:B->A) y`]);
    MAP_EVERY X_GEN_TAC [`c:A->bool`; `x:A`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`IMAGE (f:A->B) c`; `(f:A->B) x`])] THEN
  (ANTS_TAC THENL
   [CONJ_TAC THENL
     [ASM_MESON_TAC[HOMEOMORPHIC_MAP_CLOSEDNESS_EQ];
      FIRST_X_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN
      RULE_ASSUM_TAC(REWRITE_RULE[HOMEOMORPHIC_EQ_EVERYTHING_MAP]) THEN
      ASM SET_TAC[]];
    ALL_TAC])
  THENL
   [DISCH_THEN(X_CHOOSE_THEN `h:A->real` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `(h:A->real) o (g:B->A)`;
    DISCH_THEN(X_CHOOSE_THEN `h:B->real` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `(h:B->real) o (f:A->B)`] THEN
  ASM_REWRITE_TAC[o_THM] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[HOMEOMORPHIC_EQ_EVERYTHING_MAP]) THEN
  (CONJ_TAC THENL [ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE]; ASM SET_TAC[]]));;

let COMPLETELY_REGULAR_SPACE_ALT = prove
 (`!top:A topology.
        completely_regular_space top <=>
        !s x. closed_in top s /\ x IN topspace top DIFF s
              ==> ?f. continuous_map (top,euclideanreal) f /\
                      f(x) = &0 /\ (!x. x IN s ==> f x = &1)`,
  GEN_TAC THEN REWRITE_TAC[completely_regular_space] THEN EQ_TAC THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `s:A->bool` THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `x:A` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THENL
   [MESON_TAC[]; ALL_TAC] THEN
  DISCH_THEN(X_CHOOSE_THEN `f:A->real` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `\x. max (&0) (min ((f:A->real) x) (&1))` THEN
  ASM_SIMP_TAC[SUBSET; FORALL_IN_IMAGE; IN_REAL_INTERVAL; GSYM CONJ_ASSOC] THEN
  CONJ_TAC THENL [ALL_TAC; REAL_ARITH_TAC] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_MAX THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_MIN THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST]);;

let COMPLETELY_REGULAR_SPACE_GEN_ALT = prove
 (`!(top:A topology) a b.
        ~(a = b)
        ==> (completely_regular_space top <=>
             !s x. closed_in top s /\ x IN topspace top DIFF s
                   ==> ?f. continuous_map (top,euclideanreal) f /\
                           f(x) = a /\ !x. x IN s ==> f x = b)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[COMPLETELY_REGULAR_SPACE_ALT] THEN
  EQ_TAC THEN  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `s:A->bool` THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `x:A` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `f:A->real` THEN STRIP_TAC THENL
   [EXISTS_TAC `\x. a + (b - a) * (f:A->real) x`;
    EXISTS_TAC `\x. inv(b - a) * ((f:A->real) x - a)`] THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_REAL_ADD; CONTINUOUS_MAP_REAL_LMUL; ETA_AX;
               CONTINUOUS_MAP_REAL_SUB;
               CONTINUOUS_MAP_REAL_CONST] THEN
  REPEAT STRIP_TAC THEN UNDISCH_TAC `~(a:real = b)` THEN
  CONV_TAC REAL_FIELD);;

let COMPLETELY_REGULAR_SPACE_GEN = prove
 (`!(top:A topology) a b.
        a < b
        ==> (completely_regular_space top <=>
             !s x. closed_in top s /\ x IN topspace top DIFF s
                   ==> ?f. continuous_map
                              (top,subtopology euclideanreal
                                     (real_interval[a,b])) f /\
                           f(x) = a /\ !x. x IN s ==> f x = b)`,
  REPEAT STRIP_TAC THEN
  ASM_SIMP_TAC[COMPLETELY_REGULAR_SPACE_GEN_ALT; REAL_LT_IMP_NE] THEN
  EQ_TAC THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `s:A->bool` THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `x:A` THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THENL
   [ALL_TAC; MESON_TAC[]] THEN
  DISCH_THEN(X_CHOOSE_THEN `f:A->real` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `\x. max a (min ((f:A->real) x) b)` THEN
  ASM_SIMP_TAC[SUBSET; FORALL_IN_IMAGE; IN_REAL_INTERVAL; GSYM CONJ_ASSOC] THEN
  CONJ_TAC THENL [ALL_TAC; ASM_REAL_ARITH_TAC] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_MAX THEN
  REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_MIN THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST]);;

let NORMAL_IMP_COMPLETELY_REGULAR_SPACE_GEN = prove
 (`!top:A topology.
        normal_space top /\
        (t1_space top \/ hausdorff_space top \/ regular_space top)
        ==> completely_regular_space top`,
  GEN_TAC THEN REWRITE_TAC[NORMAL_SPACE_EQ_URYSOHN_ALT] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  REWRITE_TAC[COMPLETELY_REGULAR_SPACE_ALT; IN_DIFF] THEN
  MATCH_MP_TAC(TAUT
   `(q ==> p) /\ (p ==> s) /\ (r ==> s) ==> (p \/ q \/ r ==> s)`) THEN
  REWRITE_TAC[HAUSDORFF_IMP_T1_SPACE] THEN CONJ_TAC THEN DISCH_TAC THEN
  MAP_EVERY X_GEN_TAC [`s:A->bool`; `x:A`] THEN STRIP_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o SPECL [`{x:A}`; `s:A->bool`]) THEN
    ASM_SIMP_TAC[SET_RULE `DISJOINT {x} s <=> ~(x IN s)`] THEN
    REWRITE_TAC[IN_SING; FORALL_UNWIND_THM2] THEN
    DISCH_THEN MATCH_MP_TAC THEN ASM_MESON_TAC[T1_SPACE_CLOSED_IN_SING];
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM
      NEIGHBOURHOOD_BASE_OF_CLOSED_IN]) THEN
    REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
    DISCH_THEN(MP_TAC o SPECL [`topspace top DIFF s:A->bool`; `x:A`]) THEN
    ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE; IN_DIFF;
                 LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `c:A->bool`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL [`c:A->bool`; `s:A->bool`]) THEN
    ANTS_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
    MATCH_MP_TAC MONO_EXISTS THEN ASM SET_TAC[]]);;

let NORMAL_IMP_COMPLETELY_REGULAR_SPACE = prove
 (`!top:A topology.
        normal_space top /\ (hausdorff_space top \/ regular_space top)
        ==> completely_regular_space top`,
  MESON_TAC[NORMAL_IMP_COMPLETELY_REGULAR_SPACE_GEN]);;

let COMPLETELY_REGULAR_SPACE_MTOPOLOGY = prove
 (`!m:A metric. completely_regular_space (mtopology m)`,
  SIMP_TAC[NORMAL_IMP_COMPLETELY_REGULAR_SPACE; NORMAL_SPACE_MTOPOLOGY;
           HAUSDORFF_SPACE_MTOPOLOGY]);;

let METRIZABLE_IMP_COMPLETELY_REGULAR_SPACE = prove
 (`!top:A topology. metrizable_space top ==> completely_regular_space top`,
  REWRITE_TAC[FORALL_METRIZABLE_SPACE; COMPLETELY_REGULAR_SPACE_MTOPOLOGY]);;

let COMPLETELY_REGULAR_SPACE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. completely_regular_space(discrete_topology u)`,
  SIMP_TAC[METRIZABLE_SPACE_DISCRETE_TOPOLOGY;
           METRIZABLE_IMP_COMPLETELY_REGULAR_SPACE]);;

let COMPLETELY_REGULAR_SPACE_SUBTOPOLOGY = prove
 (`!top s:A->bool.
        completely_regular_space top
        ==> completely_regular_space (subtopology top s)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[completely_regular_space; IN_DIFF] THEN
  STRIP_TAC THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; CLOSED_IN_SUBTOPOLOGY_ALT] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER; FORALL_IN_GSPEC] THEN
  X_GEN_TAC `t:A->bool` THEN DISCH_TAC THEN
  X_GEN_TAC `x:A` THEN STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`t:A->bool`; `x:A`]) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_EXISTS THEN
  SIMP_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY]);;

let COMPLETELY_REGULAR_IMP_REGULAR_SPACE = prove
 (`!top:A topology. completely_regular_space top ==> regular_space top`,
  GEN_TAC THEN REWRITE_TAC[completely_regular_space; regular_space] THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `c:A->bool` THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `x:A` THEN REWRITE_TAC[IN_DIFF] THEN
  DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM; CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
  X_GEN_TAC `f:A->real` THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC
   [`{x:A | x IN topspace top /\ f x IN {x | x < &1 / &2}}`;
    `{x:A | x IN topspace top /\ f x IN {x | x > &1 / &2}}`] THEN
  ONCE_REWRITE_TAC[CONJ_ASSOC] THEN CONJ_TAC THENL
   [CONJ_TAC THEN MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
    EXISTS_TAC `euclideanreal` THEN ASM_REWRITE_TAC[GSYM REAL_OPEN_IN] THEN
    REWRITE_TAC[REAL_OPEN_HALFSPACE_LT; REAL_OPEN_HALFSPACE_GT];
    ONCE_REWRITE_TAC[CONJ_ASSOC] THEN CONJ_TAC THENL
     [ASM_SIMP_TAC[SUBSET; IN_ELIM_THM] THEN
      CONV_TAC REAL_RAT_REDUCE_CONV THEN
      ASM_MESON_TAC[CLOSED_IN_SUBSET; SUBSET];
      SIMP_TAC[EXTENSION; DISJOINT; IN_INTER; NOT_IN_EMPTY; IN_ELIM_THM] THEN
      REAL_ARITH_TAC]]);;

let LOCALLY_COMPACT_REGULAR_IMP_COMPLETELY_REGULAR_SPACE = prove
 (`!top:A topology.
        locally_compact_space top /\ (hausdorff_space top \/ regular_space top)
        ==> completely_regular_space top`,
  REWRITE_TAC[LOCALLY_COMPACT_HAUSDORFF_OR_REGULAR] THEN
  REPEAT STRIP_TAC THEN REWRITE_TAC[completely_regular_space; IN_DIFF] THEN
  MAP_EVERY X_GEN_TAC [`s:A->bool`; `x:A`] THEN STRIP_TAC THEN
  MP_TAC(ISPEC `top:A topology`
   LOCALLY_COMPACT_REGULAR_SPACE_NEIGHBOURHOOD_BASE) THEN
  ASM_REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
  DISCH_THEN(MP_TAC o SPECL [`topspace top DIFF s:A->bool`; `x:A`]) THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE; IN_DIFF;
               LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `m:A->bool`] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM
   NEIGHBOURHOOD_BASE_OF_CLOSED_IN]) THEN
  REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
  DISCH_THEN(MP_TAC o SPECL [`u:A->bool`; `x:A`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`v:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
  MP_TAC(ISPECL [`subtopology top (m:A->bool)`;
                 `k:A->bool`; `m DIFF u:A->bool`; `&0:real`; `&1:real`]
        URYSOHN_LEMMA) THEN
  REWRITE_TAC[REAL_POS; IN_DIFF] THEN ANTS_TAC THENL
   [REPEAT CONJ_TAC THENL
     [MATCH_MP_TAC COMPACT_HAUSDORFF_OR_REGULAR_IMP_NORMAL_SPACE THEN
      ASM_SIMP_TAC[COMPACT_SPACE_SUBTOPOLOGY; REGULAR_SPACE_SUBTOPOLOGY];
      MATCH_MP_TAC CLOSED_IN_SUBSET_TOPSPACE THEN ASM SET_TAC[];
      REWRITE_TAC[CLOSED_IN_SUBTOPOLOGY] THEN
      EXISTS_TAC `topspace top DIFF u:A->bool` THEN
      ASM_SIMP_TAC[CLOSED_IN_DIFF; CLOSED_IN_TOPSPACE] THEN
      FIRST_ASSUM(MP_TAC o MATCH_MP COMPACT_IN_SUBSET_TOPSPACE) THEN
      ASM SET_TAC[];
      ASM SET_TAC[]];
    REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
    ASM_SIMP_TAC[COMPACT_IN_SUBSET_TOPSPACE; TOPSPACE_SUBTOPOLOGY;
                 SET_RULE `s SUBSET u ==> u INTER s = s`] THEN
    DISCH_THEN(X_CHOOSE_THEN `g:A->real` STRIP_ASSUME_TAC)] THEN
  EXISTS_TAC `\x. if x IN m then (g:A->real) x else &1` THEN
  ASM_REWRITE_TAC[] THEN CONJ_TAC THENL
   [ALL_TAC; REPEAT STRIP_TAC THEN COND_CASES_TAC THEN ASM SET_TAC[]] THEN
  CONJ_TAC THENL
   [ALL_TAC; ASM_MESON_TAC[ENDS_IN_UNIT_REAL_INTERVAL]] THEN
  REWRITE_TAC[CONTINUOUS_MAP_CLOSED_IN; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
  X_GEN_TAC `c:real->bool` THEN DISCH_TAC THEN
  SUBGOAL_THEN
   `{x | x IN topspace top /\ (if x IN m then g x else &1) IN c} =
    {x | x IN m /\ (g:A->real) x IN c} UNION
    (if &1 IN c then topspace top DIFF u else {})`
  SUBST1_TAC THENL
   [REWRITE_TAC[EXTENSION; IN_UNION; IN_ELIM_THM; IN_DIFF] THEN
    X_GEN_TAC `y:A` THEN ASM_CASES_TAC `(y:A) IN m` THEN
    ASM_REWRITE_TAC[] THENL [ALL_TAC; ASM SET_TAC[]] THEN
    COND_CASES_TAC THEN ASM_REWRITE_TAC[IN_DIFF; NOT_IN_EMPTY] THEN
    FIRST_X_ASSUM(MP_TAC o MATCH_MP COMPACT_IN_SUBSET_TOPSPACE) THEN
    ASM SET_TAC[];
    MATCH_MP_TAC CLOSED_IN_UNION THEN CONJ_TAC THENL
     [MATCH_MP_TAC CLOSED_IN_TRANS_FULL THEN EXISTS_TAC `m:A->bool` THEN
      ASM_REWRITE_TAC[] THEN
      MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE_GEN THEN
      EXISTS_TAC `euclideanreal` THEN
      ASM_SIMP_TAC[CLOSED_IN_SUBSET_TOPSPACE; SUBSET_REFL];
      COND_CASES_TAC THEN REWRITE_TAC[CLOSED_IN_EMPTY] THEN
      ASM_SIMP_TAC[CLOSED_IN_DIFF; CLOSED_IN_TOPSPACE]]]);;

(* ------------------------------------------------------------------------- *)
(* Product topology.                                                         *)
(* ------------------------------------------------------------------------- *)

let product_topology = new_definition
 `product_topology t (tops:K->A topology) =
        topology
          (ARBITRARY UNION_OF
             ((FINITE INTERSECTION_OF
              { {x:K->A | x k IN u} | k,u | k IN t /\ open_in (tops k) u})
              relative_to {x | EXTENSIONAL t x /\
                               !k. k IN t ==> x k IN topspace(tops k)}))`;;

let TOPSPACE_PRODUCT_TOPOLOGY = prove
 (`!(tops:K->A topology) t.
        topspace (product_topology t tops) =
        cartesian_product t (topspace o tops)`,
  REWRITE_TAC[product_topology; cartesian_product; o_THM; TOPSPACE_SUBBASE]);;

let TOPSPACE_PRODUCT_TOPOLOGY_ALT = prove
 (`!(tops:K->A topology) t.
        topspace (product_topology t tops) =
        {x | EXTENSIONAL t x /\ !k. k IN t ==> x k IN topspace(tops k)}`,
  REWRITE_TAC[product_topology; TOPSPACE_SUBBASE]);;

let PRODUCT_TOPOLOGY_EMPTY_DISCRETE = prove
 (`!tops:K->A topology.
        product_topology {} tops = discrete_topology {(\x. ARB)}`,
  REWRITE_TAC[SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_SING] THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; CARTESIAN_PRODUCT_EMPTY]);;

let OPEN_IN_PRODUCT_TOPOLOGY = prove
 (`!(tops:K->A topology) t.
        open_in (product_topology t tops) =
        ARBITRARY UNION_OF
          ((FINITE INTERSECTION_OF
           { {x:K->A | x k IN u} | k,u | k IN t /\ open_in (tops k) u})
           relative_to topspace (product_topology t tops))`,
  REWRITE_TAC[product_topology; TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
  REWRITE_TAC[GSYM(CONJUNCT2 topology_tybij); ISTOPOLOGY_SUBBASE]);;

let SUBTOPOLOGY_CARTESIAN_PRODUCT = prove
 (`!tops:K->A topology s k.
        subtopology (product_topology k tops) (cartesian_product k s) =
        product_topology k (\i. subtopology (tops i) (s i))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[TOPOLOGY_EQ] THEN
  REWRITE_TAC[GSYM OPEN_IN_RELATIVE_TO; OPEN_IN_PRODUCT_TOPOLOGY] THEN
  X_GEN_TAC `u:(K->A)->bool` THEN
  REWRITE_TAC[ARBITRARY_UNION_OF_RELATIVE_TO] THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[o_DEF; TOPSPACE_SUBTOPOLOGY] THEN
  REWRITE_TAC[GSYM INTER_CARTESIAN_PRODUCT] THEN
  REWRITE_TAC[RELATIVE_TO_RELATIVE_TO] THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN
  ONCE_REWRITE_TAC[FINITE_INTERSECTION_OF_RELATIVE_TO] THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN AP_TERM_TAC THEN
  GEN_REWRITE_TAC I [GSYM SUBSET_ANTISYM_EQ] THEN
  REWRITE_TAC[SUBSET] THEN
  REWRITE_TAC[RELATIVE_TO; FORALL_IN_GSPEC] THEN
  GEN_REWRITE_TAC (BINOP_CONV o BINDER_CONV o LAND_CONV) [GSYM IN] THEN
  REWRITE_TAC[FORALL_IN_GSPEC] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  CONJ_TAC THEN X_GEN_TAC `i:K` THEN DISCH_TAC THENL
   [ALL_TAC; GEN_REWRITE_TAC (BINDER_CONV o LAND_CONV) [GSYM IN]] THEN
  REWRITE_TAC[FORALL_IN_GSPEC] THEN X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN
  GEN_REWRITE_TAC I [IN_ELIM_THM] THEN REWRITE_TAC[] THEN
  GEN_REWRITE_TAC (BINDER_CONV o LAND_CONV) [GSYM IN] THEN
  REWRITE_TAC[EXISTS_IN_GSPEC] THEN EXISTS_TAC `i:K` THEN
  ASM_REWRITE_TAC[] THENL
   [GEN_REWRITE_TAC (BINDER_CONV o LAND_CONV) [GSYM IN]; ALL_TAC] THEN
  REWRITE_TAC[EXISTS_IN_GSPEC] THEN
  EXISTS_TAC `u:A->bool` THEN ASM_REWRITE_TAC[] THEN
  GEN_REWRITE_TAC I [EXTENSION] THEN
  REWRITE_TAC[IN_INTER; IN_ELIM_THM; cartesian_product] THEN
  ASM SET_TAC[]);;

let PRODUCT_TOPOLOGY_SUBBASE_ALT = prove
 (`!tops:K->A topology.
        ((FINITE INTERSECTION_OF
          { {x | x k IN u} | k,u | k IN t /\ open_in (tops k) u})
         relative_to topspace (product_topology t tops)) =
        ((FINITE INTERSECTION_OF
         { {x | x k IN u} | k,u |
           k IN t /\ open_in (tops k) u /\ u PSUBSET topspace (tops k)})
         relative_to topspace (product_topology t tops))`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `s:(K->A)->bool` THEN
  ONCE_REWRITE_TAC[FINITE_INTERSECTION_OF_RELATIVE_TO] THEN
  REWRITE_TAC[INTERSECTION_OF; relative_to; IN_ELIM_THM] THEN
  REWRITE_TAC[LEFT_AND_EXISTS_THM] THEN
  ONCE_REWRITE_TAC[SWAP_EXISTS_THM] THEN
  ONCE_REWRITE_TAC[TAUT `p /\ q /\ r <=> r /\ p /\ q`] THEN
  REWRITE_TAC[UNWIND_THM1; GSYM CONJ_ASSOC] THEN
  EQ_TAC THENL [ALL_TAC; MESON_TAC[]] THEN
  DISCH_THEN(X_CHOOSE_THEN `w:((K->A)->bool)->bool` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `w DELETE topspace(product_topology t (tops:K->A topology))` THEN
  ASM_REWRITE_TAC[FINITE_DELETE; IN_DELETE] THEN
  REWRITE_TAC[GSYM INTERS_INSERT] THEN
  REWRITE_TAC[SET_RULE `x INSERT (s DELETE x) = x INSERT s`] THEN
  ASM_REWRITE_TAC[INTERS_INSERT] THEN
  X_GEN_TAC `w:(K->A)->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `w:(K->A)->bool`) THEN
  ASM_REWRITE_TAC[] THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  DISCH_THEN(SUBST_ALL_TAC o SYM) THEN
  STRIP_TAC THEN FIRST_X_ASSUM SUBST_ALL_TAC THEN
  ASM_REWRITE_TAC[PSUBSET] THEN CONJ_TAC THENL
   [ASM_MESON_TAC[OPEN_IN_SUBSET]; DISCH_THEN SUBST_ALL_TAC] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PRODUCT_TOPOLOGY_ALT]) THEN
  ASM SET_TAC[]);;

let PRODUCT_TOPOLOGY_BASE_ALT = prove
 (`!(tops:K->A topology) k.
        FINITE INTERSECTION_OF {{x | x i IN u} | i IN k /\ open_in (tops i) u}
        relative_to topspace(product_topology k tops) =
        { cartesian_product k u | u |
          FINITE {i | i IN k /\ ~(u i = topspace(tops i))} /\
          !i. i IN k ==> open_in (tops i) (u i)}`,
  REPEAT GEN_TAC THEN GEN_REWRITE_TAC I [EXTENSION] THEN
  GEN_REWRITE_TAC (BINDER_CONV o LAND_CONV) [IN] THEN
  REWRITE_TAC[FORALL_AND_THM; TAUT `(p <=> q) <=> (p ==> q) /\ (q ==> p)`] THEN
  CONJ_TAC THENL
   [REWRITE_TAC[FORALL_RELATIVE_TO; FORALL_INTERSECTION_OF] THEN
    REWRITE_TAC[IMP_CONJ; IN_ELIM_THM; GSYM CONJ_ASSOC] THEN
    MATCH_MP_TAC FINITE_INDUCT_STRONG THEN CONJ_TAC THENL
     [DISCH_THEN(K ALL_TAC) THEN
      EXISTS_TAC `(\i. topspace(tops i)):K->A->bool` THEN
      REWRITE_TAC[EMPTY_GSPEC; INTERS_0; INTER_UNIV] THEN
      REWRITE_TAC[FINITE_EMPTY; OPEN_IN_TOPSPACE] THEN
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; o_DEF];
      MAP_EVERY X_GEN_TAC [`v:(K->A)->bool`; `ovs:((K->A)->bool)->bool`] THEN
      REWRITE_TAC[FORALL_IN_INSERT] THEN
      DISCH_THEN(fun th -> DISCH_THEN(CONJUNCTS_THEN ASSUME_TAC) THEN
        CONJUNCTS_THEN2 MP_TAC STRIP_ASSUME_TAC th) THEN
      ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
      X_GEN_TAC `u:K->(A->bool)` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(X_CHOOSE_THEN `i:K` (X_CHOOSE_THEN `v:A->bool`
        (STRIP_ASSUME_TAC o GSYM))) THEN
      EXISTS_TAC
       `\j. (u:K->(A->bool)) j INTER
            (if j = i then v else topspace(tops j))` THEN
      REWRITE_TAC[] THEN REPEAT CONJ_TAC THENL
       [MATCH_MP_TAC FINITE_SUBSET THEN EXISTS_TAC
        `i INSERT {i | i IN k /\ ~((u:K->A->bool) i = topspace (tops i))}` THEN
        ASM_REWRITE_TAC[FINITE_INSERT] THEN SET_TAC[];
        REPEAT STRIP_TAC THEN COND_CASES_TAC THEN
        ASM_SIMP_TAC[OPEN_IN_INTER; OPEN_IN_TOPSPACE];
        ASM_REWRITE_TAC[INTERS_INSERT; SET_RULE
         `s INTER (t INTER u) = (s INTER u) INTER t`] THEN
        REWRITE_TAC[GSYM INTER_CARTESIAN_PRODUCT] THEN EXPAND_TAC "v" THEN
        REWRITE_TAC[EXTENSION; cartesian_product; IN_ELIM_THM; IN_INTER] THEN
        X_GEN_TAC `f:K->A` THEN MATCH_MP_TAC(TAUT
         `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
        STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
        EQ_TAC THENL [DISCH_TAC; ASM_MESON_TAC[]] THEN
        X_GEN_TAC `j:K` THEN COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
        ASM_MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]]];
    REWRITE_TAC[FORALL_IN_GSPEC] THEN X_GEN_TAC `u:K->A->bool` THEN
    STRIP_TAC THEN REWRITE_TAC[relative_to] THEN
    EXISTS_TAC
     `INTERS (IMAGE (\i. {x | x i IN u i})
             {i | i IN k /\ ~(u i = topspace((tops:K->A topology) i))})` THEN
    CONJ_TAC THENL
     [MATCH_MP_TAC FINITE_INTERSECTION_OF_INTERS THEN
      ASM_SIMP_TAC[FINITE_IMAGE; FORALL_IN_IMAGE] THEN
      X_GEN_TAC `i:K` THEN REWRITE_TAC[IN_ELIM_THM] THEN STRIP_TAC THEN
      MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN
      REWRITE_TAC[IN_ELIM_THM] THEN
      MAP_EVERY EXISTS_TAC [`i:K`; `(u:K->A->bool) i`] THEN
      ASM_MESON_TAC[];
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; o_DEF] THEN
      GEN_REWRITE_TAC I [EXTENSION] THEN
      REWRITE_TAC[cartesian_product; IN_ELIM_THM; IN_INTER; INTERS_IMAGE] THEN
      ASM_MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]]]);;

let OPEN_IN_PRODUCT_TOPOLOGY_ALT = prove
 (`!k (tops:K->A topology) s.
         open_in (product_topology k tops) s <=>
         !x. x IN s
             ==> ?u. FINITE {i | i IN k /\ ~(u i = topspace(tops i))} /\
                     (!i. i IN k ==> open_in (tops i) (u i)) /\
                     x IN cartesian_product k u /\
                     cartesian_product k u SUBSET s`,
  REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY; ARBITRARY_UNION_OF_ALT] THEN
  REWRITE_TAC[PRODUCT_TOPOLOGY_BASE_ALT; EXISTS_IN_GSPEC; GSYM CONJ_ASSOC]);;

let OPEN_IN_PRODUCT_TOPOLOGY_ALT_EXPAND = prove
 (`!k (tops:K->A topology) s.
        open_in (product_topology k tops) s <=>
        s SUBSET topspace(product_topology k tops) /\
        !x. x IN s
            ==> ?u. FINITE {i | i IN k /\ ~(u i = topspace(tops i))} /\
                    (!i. i IN k ==> open_in (tops i) (u i) /\ x i IN u i) /\
                    cartesian_product k u SUBSET s`,
  REPEAT GEN_TAC THEN REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY_ALT] THEN
  GEN_REWRITE_TAC (RAND_CONV o LAND_CONV) [SUBSET] THEN
  REWRITE_TAC[AND_FORALL_THM] THEN AP_TERM_TAC THEN
  GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `x:K->A` THEN
  ASM_CASES_TAC `(x:K->A) IN s` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[RIGHT_AND_EXISTS_THM; TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[cartesian_product; IN_ELIM_THM; o_THM] THEN
  EQ_TAC THEN MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC THEN
  STRIP_TAC THEN ASM_SIMP_TAC[] THEN
  ASM_MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let LIMIT_COMPONENTWISE = prove
 (`!(net:C net) (tops:K->A topology) t f l.
        limit (product_topology t tops) f l net <=>
        EXTENSIONAL t l /\
        eventually (\a. f a IN topspace(product_topology t tops)) net /\
        !k. k IN t ==> limit (tops k) (\c. f c k) (l k) net`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[limit; TOPSPACE_PRODUCT_TOPOLOGY_ALT; IN_ELIM_THM] THEN
  ASM_CASES_TAC `EXTENSIONAL t (l:K->A)` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[TAUT `p ==> q /\ r <=> (p ==> q) /\ (p ==> r)`] THEN
  REWRITE_TAC[RIGHT_IMP_FORALL_THM; FORALL_AND_THM] THEN
  ASM_CASES_TAC `!k. k IN t ==> (l:K->A) k IN topspace (tops k)` THEN
  ASM_REWRITE_TAC[IMP_IMP] THEN EQ_TAC THENL
   [DISCH_TAC THEN CONJ_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o SPEC
       `topspace(product_topology t tops):(K->A)->bool`) THEN
      REWRITE_TAC[OPEN_IN_TOPSPACE] THEN
      ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT; IN_ELIM_THM];
      ALL_TAC] THEN
    MAP_EVERY X_GEN_TAC [`k:K`; `u:A->bool`] THEN
    REPEAT DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC
     `{y:K->A | y k IN u} INTER topspace(product_topology t tops)`) THEN
    ANTS_TAC THENL
     [ASM_REWRITE_TAC[IN_INTER; IN_ELIM_THM; TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
      REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY] THEN
      REWRITE_TAC[GSYM ARBITRARY_UNION_OF_RELATIVE_TO] THEN
      REWRITE_TAC[relative_to; TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
      EXISTS_TAC `{y:K->A | y k IN u}` THEN
      CONJ_TAC THENL [ALL_TAC; SET_TAC[]] THEN
      MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN
      MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN
      REWRITE_TAC[IN_ELIM_THM] THEN
      MAP_EVERY EXISTS_TAC [`k:K`; `u:A->bool`] THEN
      ASM_REWRITE_TAC[];
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
      SIMP_TAC[IN_INTER; IN_ELIM_THM]];
    STRIP_TAC THEN
    REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY; FORALL_UNION_OF;
                ARBITRARY; IMP_CONJ] THEN
    X_GEN_TAC `v:((K->A)->bool)->bool` THEN REWRITE_TAC[IN_UNIONS] THEN
    MATCH_MP_TAC(MESON[]
     `(!x. P x ==> x IN v /\ Q x ==> R)
      ==> (!x. x IN v ==> P x) ==> (?x. x IN v /\ Q x) ==> R`) THEN
    REWRITE_TAC[FORALL_RELATIVE_TO; FORALL_INTERSECTION_OF] THEN
    X_GEN_TAC `w:((K->A)->bool)->bool` THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
    MATCH_MP_TAC EVENTUALLY_MONO THEN EXISTS_TAC
     `\x. (f:C->K->A) x IN
          topspace(product_topology t tops) INTER INTERS w` THEN
    REWRITE_TAC[] THEN CONJ_TAC THENL
     [REPEAT STRIP_TAC THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (MESON[]
       `a IN v ==> P a ==> ?x. x IN v /\ P x`)) THEN
      ASM SET_TAC[];
      ASM_REWRITE_TAC[EVENTUALLY_AND; IN_INTER]] THEN
    ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT; IN_ELIM_THM] THEN
    REWRITE_TAC[IN_INTERS] THEN
    W(MP_TAC o PART_MATCH (lhand o rand) EVENTUALLY_FORALL o snd) THEN
    ASM_CASES_TAC `w:((K->A)->bool)->bool = {}` THEN
    ASM_REWRITE_TAC[NOT_IN_EMPTY; EVENTUALLY_TRUE] THEN
    DISCH_THEN SUBST1_TAC THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (SET_RULE `(!x. P x ==> Q x)
                ==> (!x. x IN Q ==> P x ==> R x) ==> (!x. P x ==> R x)`)) THEN
    REWRITE_TAC[FORALL_IN_GSPEC; ETA_AX] THEN REPEAT STRIP_TAC THEN
    REWRITE_TAC[IN_ELIM_THM] THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
    ASM_REWRITE_TAC[] THEN
    FIRST_X_ASSUM(MP_TAC o CONJUNCT2 o REWRITE_RULE[IN_INTER]) THEN
    DISCH_THEN(MP_TAC o GEN_REWRITE_RULE I [IN_INTERS]) THEN
    FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
     `a IN s ==> (P a ==> Q) ==> (!x. x IN s ==> P x) ==> Q`)) THEN
    REWRITE_TAC[IN_ELIM_THM]]);;

let CONTINUOUS_MAP_COMPONENTWISE = prove
 (`!top:A topology (tops:K->B topology) t f.
       continuous_map (top,product_topology t tops) f <=>
       IMAGE f (topspace top) SUBSET EXTENSIONAL t /\
       !k. k IN t ==> continuous_map (top,tops k) (\x. f x k)`,
  let lemma = prove
   (`{x | x IN s /\ f x IN UNIONS v} =
     UNIONS {{x | x IN s /\ f x IN u} | u IN v} /\
     {x | x IN s /\ f x IN INTERS v} =
     s INTER INTERS {{x | x IN s /\ f x IN u} | u IN v}`,
    REWRITE_TAC[UNIONS_GSPEC; INTERS_GSPEC] THEN SET_TAC[]) in
  REPEAT GEN_TAC THEN
  REWRITE_TAC[continuous_map; TOPSPACE_PRODUCT_TOPOLOGY_ALT; IN_ELIM_THM] THEN
  ASM_CASES_TAC
    `!x. x IN topspace top ==> EXTENSIONAL t ((f:A->K->B) x)`
  THENL [ASM_SIMP_TAC[]; ASM SET_TAC[]] THEN
  ASM_CASES_TAC
    `!k x. k IN t /\ x IN topspace top
           ==> (f:A->K->B) x k IN topspace(tops k)`
  THENL [ASM_SIMP_TAC[]; ASM SET_TAC[]] THEN
  MATCH_MP_TAC(TAUT `q /\ (p <=> r) ==> (p <=> q /\ r)`) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  REWRITE_TAC[RIGHT_IMP_FORALL_THM; IMP_IMP] THEN EQ_TAC THENL
   [DISCH_TAC THEN MAP_EVERY X_GEN_TAC [`k:K`; `u:B->bool`] THEN
    REPEAT DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC
     `{y:K->B | y k IN u} INTER topspace(product_topology t tops)`) THEN
    ANTS_TAC THENL
     [REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY] THEN
      REWRITE_TAC[GSYM ARBITRARY_UNION_OF_RELATIVE_TO] THEN
      REWRITE_TAC[relative_to; TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
      EXISTS_TAC `{y:K->B | y k IN u}` THEN
      CONJ_TAC THENL [ALL_TAC; SET_TAC[]] THEN
      MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN
      MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN
      REWRITE_TAC[IN_ELIM_THM] THEN
      MAP_EVERY EXISTS_TAC [`k:K`; `u:B->bool`] THEN
      ASM_REWRITE_TAC[];
      MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN ASM SET_TAC[]];
    DISCH_TAC THEN
    REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY; FORALL_UNION_OF; ARBITRARY] THEN
    X_GEN_TAC `v:((K->B)->bool)->bool` THEN DISCH_TAC THEN
    REWRITE_TAC[lemma] THEN MATCH_MP_TAC OPEN_IN_UNIONS THEN
    REWRITE_TAC[FORALL_IN_GSPEC] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (SET_RULE `(!x. P x ==> Q x)
                ==> (!x. Q x ==> R x) ==> (!x. P x ==> R x)`)) THEN
    REWRITE_TAC[FORALL_RELATIVE_TO; FORALL_INTERSECTION_OF] THEN
    X_GEN_TAC `w:((K->B)->bool)->bool` THEN STRIP_TAC THEN
    REWRITE_TAC[SET_RULE
    `{x | x IN s /\ f x IN t INTER u} =
     {x | x IN {x | x IN s /\ f x IN t} /\ f x IN u}`] THEN
    REWRITE_TAC[lemma] THEN
    SUBGOAL_THEN
     `{x | x IN topspace top /\
           (f:A->K->B) x IN topspace (product_topology t tops)} =
      topspace top`
    SUBST1_TAC THENL
     [REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN ASM SET_TAC[];
      ALL_TAC] THEN
    ASM_CASES_TAC `w:((K->B)->bool)->bool = {}` THEN
    ASM_REWRITE_TAC[NOT_IN_EMPTY; SET_RULE `{f x | x | F} = {}`;
                    INTERS_0; INTER_UNIV; OPEN_IN_TOPSPACE] THEN
    MATCH_MP_TAC OPEN_IN_INTER THEN REWRITE_TAC[OPEN_IN_TOPSPACE] THEN
    MATCH_MP_TAC OPEN_IN_INTERS THEN
    ASM_SIMP_TAC[SIMPLE_IMAGE; FINITE_IMAGE; FORALL_IN_IMAGE] THEN
    ASM_REWRITE_TAC[IMAGE_EQ_EMPTY] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (SET_RULE `(!x. P x ==> Q x)
                ==> (!x. x IN Q ==> R x) ==> (!x. P x ==> R x)`)) THEN
    REWRITE_TAC[ETA_AX; FORALL_IN_GSPEC] THEN ASM_REWRITE_TAC[IN_ELIM_THM]]);;

let CONTINUOUS_MAP_COMPONENTWISE_UNIV = prove
 (`!top tops (f:A->K->B).
         continuous_map (top,product_topology (:K) tops) f <=>
         !k. continuous_map (top,tops k) (\x. f x k)`,
  REWRITE_TAC[CONTINUOUS_MAP_COMPONENTWISE; IN_UNIV] THEN
  REWRITE_TAC[SET_RULE `IMAGE f s SUBSET P <=> !x. x IN s ==> P(f x)`] THEN
  REWRITE_TAC[EXTENSIONAL_UNIV]);;

let CONTINUOUS_MAP_PRODUCT_PROJECTION = prove
 (`!(tops:K->A topology) t k.
        k IN t ==> continuous_map (product_topology t tops,tops k) (\x. x k)`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL
   [`product_topology t (tops:K->A topology)`;
    `tops:K->A topology`; `t:K->bool`; `\x:K->A. x`]
        CONTINUOUS_MAP_COMPONENTWISE) THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_ID]);;

let OPEN_MAP_PRODUCT_PROJECTION = prove
 (`!(tops:K->A topology) t k.
        k IN t ==> open_map (product_topology t tops,tops k) (\x. x k)`,
  let lemma = prove
   (`k IN t
     ==> {a | a IN v /\
          (\i. if i = k then a else if i IN t then x i else b) IN u}
     SUBSET IMAGE (\x:K->A. x k) u`,
    REWRITE_TAC[SUBSET; FORALL_IN_GSPEC; IN_IMAGE] THEN
    REPEAT STRIP_TAC THEN
    EXISTS_TAC `(\i. if i = k then a else if i IN t then x i else b):K->A` THEN
    ASM_REWRITE_TAC[]) in
  REPEAT STRIP_TAC THEN REWRITE_TAC[open_map] THEN
  REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY; FORALL_UNION_OF; ARBITRARY] THEN
  X_GEN_TAC `v:((K->A)->bool)->bool` THEN DISCH_TAC THEN
  REWRITE_TAC[IMAGE_UNIONS] THEN MATCH_MP_TAC OPEN_IN_UNIONS THEN
  REWRITE_TAC[FORALL_IN_IMAGE] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
   (SET_RULE `(!x. P x ==> Q x)
              ==> (!x. Q x ==> R x) ==> (!x. P x ==> R x)`)) THEN
  REWRITE_TAC[FORALL_RELATIVE_TO; FORALL_INTERSECTION_OF] THEN
  X_GEN_TAC `w:((K->A)->bool)->bool` THEN STRIP_TAC THEN
  ONCE_REWRITE_TAC[OPEN_IN_SUBOPEN] THEN REWRITE_TAC[FORALL_IN_IMAGE] THEN
  X_GEN_TAC `x:K->A` THEN REWRITE_TAC[IN_INTER; IN_ELIM_THM] THEN
  STRIP_TAC THEN
  EXISTS_TAC `{a | a IN topspace(tops k) /\
                   (\i:K. if i = k then a:A
                          else if i IN t then x i else ARB) IN
                   topspace(product_topology t tops) INTER INTERS w}` THEN
  ASM_SIMP_TAC[lemma] THEN CONJ_TAC THENL
   [ALL_TAC;
    RULE_ASSUM_TAC(REWRITE_RULE
     [TOPSPACE_PRODUCT_TOPOLOGY_ALT; EXTENSIONAL; IN_ELIM_THM]) THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT; EXTENSIONAL; IN_ELIM_THM] THEN
    ASM SET_TAC[]] THEN
  MATCH_MP_TAC(MESON[continuous_map]
   `!top'. continuous_map (top,top') f /\ open_in top' u
           ==> open_in top {x | x IN topspace top /\ f x IN u}`) THEN
  EXISTS_TAC `product_topology t (tops:K->A topology)` THEN
  REWRITE_TAC[CONTINUOUS_MAP_COMPONENTWISE] THEN REPEAT CONJ_TAC THENL
   [REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; EXTENSIONAL; IN_ELIM_THM] THEN
    ASM SET_TAC[];
    X_GEN_TAC `j:K` THEN ASM_CASES_TAC `j:K = k` THEN
    ASM_REWRITE_TAC[ETA_AX; CONTINUOUS_MAP_ID] THEN
    RULE_ASSUM_TAC(REWRITE_RULE
     [TOPSPACE_PRODUCT_TOPOLOGY_ALT; IN_ELIM_THM]) THEN
    ASM_CASES_TAC `(j:K) IN t` THEN ASM_SIMP_TAC[CONTINUOUS_MAP_CONST];
    REWRITE_TAC[INTER_INTERS] THEN COND_CASES_TAC THEN
    REWRITE_TAC[GSYM TOPSPACE_PRODUCT_TOPOLOGY_ALT; OPEN_IN_TOPSPACE] THEN
    MATCH_MP_TAC OPEN_IN_INTERS THEN
    ASM_SIMP_TAC[FINITE_IMAGE; IMAGE_EQ_EMPTY; SIMPLE_IMAGE] THEN
    REWRITE_TAC[FORALL_IN_IMAGE] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (SET_RULE `(!x. P x ==> Q x)
                ==> (!x. x IN Q ==> R x) ==> (!x. P x ==> R x)`)) THEN
    REWRITE_TAC[FORALL_IN_GSPEC; ETA_AX] THEN
    MAP_EVERY X_GEN_TAC [`i:K`; `v:A->bool`] THEN STRIP_TAC THEN
    REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY] THEN
    MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN REWRITE_TAC[relative_to] THEN
    EXISTS_TAC `{x:K->A | x i IN v}` THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
    MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN
    REWRITE_TAC[IN_ELIM_THM] THEN
    MAP_EVERY EXISTS_TAC [`i:K`; `v:A->bool`] THEN
    ASM_REWRITE_TAC[]]);;

let QUOTIENT_MAP_PRODUCT_PROJECTION = prove
 (`!(tops:K->A topology) k i.
      i IN k
      ==> (quotient_map(product_topology k tops,tops i) (\x. x i) <=>
           topspace(product_topology k tops) = {} ==> topspace(tops i) = {})`,
  REPEAT STRIP_TAC THEN
  ASM_SIMP_TAC[CONTINUOUS_OPEN_QUOTIENT_MAP; OPEN_MAP_PRODUCT_PROJECTION;
               CONTINUOUS_MAP_PRODUCT_PROJECTION] THEN
  ASM_REWRITE_TAC[IMAGE_PROJECTION_CARTESIAN_PRODUCT;
                  TOPSPACE_PRODUCT_TOPOLOGY; o_THM] THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[EQ_SYM_EQ]);;

let PRODUCT_TOPOLOGY_HOMEOMORPHIC_COMPONENT = prove
 (`!(tops:K->A topology) k i.
        i IN k /\
        (!j. j IN k /\ ~(j = i) ==> ?a. topspace(tops j) = {a})
        ==> product_topology k tops homeomorphic_space (tops i)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  EXISTS_TAC `\x:K->A. x i` THEN
  REWRITE_TAC[GSYM HOMEOMORPHIC_MAP_MAPS; homeomorphic_map] THEN
  ASM_SIMP_TAC[QUOTIENT_MAP_PRODUCT_PROJECTION; TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[CARTESIAN_PRODUCT_EQ_EMPTY; o_THM] THEN
  CONJ_TAC THENL [ASM_MESON_TAC[NOT_INSERT_EMPTY]; ALL_TAC] THEN
  REPEAT STRIP_TAC THEN EQ_TAC THEN SIMP_TAC[] THEN DISCH_TAC THEN
  MATCH_MP_TAC CARTESIAN_PRODUCT_EQ_MEMBERS THEN
  MAP_EVERY EXISTS_TAC [`k:K->bool`; `topspace o (tops:K->A topology)`] THEN
  ASM_REWRITE_TAC[] THEN RULE_ASSUM_TAC(REWRITE_RULE
   [cartesian_product; EXTENSIONAL; IN_ELIM_THM; o_THM]) THEN
  X_GEN_TAC `j:K` THEN FIRST_X_ASSUM(MP_TAC o SPEC `j:K`) THEN
  ASM_MESON_TAC[IN_SING]);;

let TOPOLOGICAL_PROPERTY_OF_PRODUCT_COMPONENT = prove
 (`!P Q (tops:K->A topology) k.
        (!z i. z IN topspace(product_topology k tops) /\
               P(product_topology k tops) /\
               i IN k
               ==> P(subtopology
                       (product_topology k tops)
                       (cartesian_product k
                         (\j. if j = i then topspace(tops i) else {z j})))) /\
        (!top top'. top homeomorphic_space top' ==> (P top <=> Q top'))
        ==> P(product_topology k tops)
            ==> topspace(product_topology k tops) = {} \/
                !i. i IN k ==> Q(tops i)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[TAUT `p \/ q <=> ~p ==> q`] THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `z:K->A` THEN DISCH_TAC THEN X_GEN_TAC `i:K` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`z:K->A`; `i:K`]) THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC EQ_IMP THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  REWRITE_TAC[SUBTOPOLOGY_CARTESIAN_PRODUCT] THEN
  FIRST_ASSUM(fun th ->
      W(MP_TAC o PART_MATCH (lhand o rand)
        (MATCH_MP (REWRITE_RULE[IMP_CONJ]
         PRODUCT_TOPOLOGY_HOMEOMORPHIC_COMPONENT) th) o lhand o snd)) THEN
  REWRITE_TAC[SUBTOPOLOGY_TOPSPACE] THEN DISCH_THEN MATCH_MP_TAC THEN
  X_GEN_TAC `j:K` THEN REPEAT DISCH_TAC THEN
  ASM_REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product;
    IN_ELIM_THM; o_THM]) THEN
  ASM_MESON_TAC[SET_RULE `a IN s ==> s INTER {a} = {a}`]);;

let OPEN_IN_CARTESIAN_PRODUCT_GEN = prove
 (`!(tops:K->A topology) s k.
        open_in (product_topology k tops) (cartesian_product k s) <=>
        cartesian_product k s = {} \/
        FINITE {i | i IN k /\ ~(s i = topspace(tops i))} /\
        (!i. i IN k ==> open_in (tops i) (s i))`,
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `cartesian_product k (s:K->A->bool) = {}` THEN
  ASM_REWRITE_TAC[OPEN_IN_EMPTY] THEN EQ_TAC THENL
   [ALL_TAC;
    STRIP_TAC THEN REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY] THEN
    MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN
    REWRITE_TAC[PRODUCT_TOPOLOGY_BASE_ALT; IN_ELIM_THM] THEN
    EXISTS_TAC `s:K->A->bool` THEN ASM_REWRITE_TAC[]] THEN
  DISCH_TAC THEN CONJ_TAC THENL
   [ALL_TAC;
    X_GEN_TAC `i:K` THEN DISCH_TAC THEN
    MP_TAC(ISPECL [`tops:K->A topology`; `k:K->bool`; `i:K`]
        OPEN_MAP_PRODUCT_PROJECTION) THEN
    ASM_REWRITE_TAC[open_map] THEN
    DISCH_THEN(MP_TAC o SPEC `cartesian_product k (s:K->A->bool)`) THEN
    ASM_REWRITE_TAC[IMAGE_PROJECTION_CARTESIAN_PRODUCT]] THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_PRODUCT_TOPOLOGY_ALT]) THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
  DISCH_THEN(X_CHOOSE_TAC `z:K->A`) THEN
  DISCH_THEN(MP_TAC o SPEC `z:K->A`) THEN
  ASM_REWRITE_TAC[SUBSET_CARTESIAN_PRODUCT] THEN
  DISCH_THEN(X_CHOOSE_THEN `u:K->A->bool` STRIP_ASSUME_TAC) THENL
   [ASM SET_TAC[]; ALL_TAC] THEN
  FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP
   (REWRITE_RULE[IMP_CONJ] FINITE_SUBSET)) THEN
  REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN X_GEN_TAC `i:K` THEN
  ASM_CASES_TAC `(i:K) IN k` THEN ASM_REWRITE_TAC[] THEN MATCH_MP_TAC(SET_RULE
   `t SUBSET s /\ s SUBSET u ==> ~(s = u) ==> ~(t = u)`) THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
  ASM_SIMP_TAC[TOPSPACE_PRODUCT_TOPOLOGY; SUBSET_CARTESIAN_PRODUCT; o_DEF]);;

let OPEN_IN_CARTESIAN_PRODUCT = prove
 (`!(tops:K->A topology) (s:K->A->bool) k.
        FINITE k
        ==> (open_in (product_topology k tops) (cartesian_product k s) <=>
             cartesian_product k s = {} \/
             (!i. i IN k ==> open_in (tops i) (s i)))`,
  SIMP_TAC[OPEN_IN_CARTESIAN_PRODUCT_GEN; FINITE_RESTRICT]);;

let PRODUCT_TOPOLOGY_EMPTY,OPEN_IN_PRODUCT_TOPOLOGY_EMPTY = (CONJ_PAIR o prove)
 (`(!tops:K->A topology.
        product_topology {} tops = topology {{},{\k. ARB}}) /\
   (!tops:K->A topology s.
        open_in (product_topology {} tops) s <=> s IN {{},{\k. ARB}})`,
  REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY; TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
  REWRITE_TAC[product_topology; EXTENSIONAL_EMPTY; NOT_IN_EMPTY] THEN
  CONJ_TAC THENL
   [AP_TERM_TAC;
    ONCE_REWRITE_TAC[SET_RULE `(!x. P x <=> x IN s) <=> P = s`] THEN
    REWRITE_TAC[ETA_AX]] THEN
  REWRITE_TAC[SET_RULE `{f x y | x,y| F} = {}`] THEN
  REWRITE_TAC[SET_RULE `{x | s x} = s`; ETA_AX] THEN
  ABBREV_TAC `g:K->A = \x. ARB` THEN
  REWRITE_TAC[INTERSECTION_OF] THEN
  REWRITE_TAC[SET_RULE `(!x. x IN s ==> t x) <=> s SUBSET t`] THEN
  REWRITE_TAC[MESON[SUBSET_EMPTY; FINITE_EMPTY]
   `(?u. FINITE u /\ u SUBSET {} /\ P u) <=> P {}`] THEN
  REWRITE_TAC[SET_RULE `(\s. a = s) = {a}`; INTERS_0] THEN
  REWRITE_TAC[UNION_OF] THEN
  REWRITE_TAC[SET_RULE `(!x. x IN s ==> t x) <=> s SUBSET t`] THEN
  REWRITE_TAC[ETA_AX; ARBITRARY] THEN
  REWRITE_TAC[RELATIVE_TO; SET_RULE `{f x | s x} = IMAGE f s`] THEN
  REWRITE_TAC[IMAGE_CLAUSES; ETA_AX; INTER_UNIV] THEN
  REWRITE_TAC[SET_RULE `s SUBSET {a} <=> s = {} \/ s = {a}`] THEN
  REWRITE_TAC[EXISTS_OR_THM; UNWIND_THM2; RIGHT_OR_DISTRIB] THEN
  REWRITE_TAC[UNIONS_0; UNIONS_1] THEN GEN_REWRITE_TAC I [EXTENSION] THEN
  REWRITE_TAC[IN_ELIM_THM; IN_INSERT; NOT_IN_EMPTY] THEN MESON_TAC[]);;

let TOPSPACE_PRODUCT_TOPOLOGY_EMPTY = prove
 (`!tops:K->A topology.
        topspace(product_topology {} tops) = {\k. ARB}`,
  REWRITE_TAC[topspace; OPEN_IN_PRODUCT_TOPOLOGY_EMPTY] THEN
  REWRITE_TAC[SET_RULE `{x | x IN s} = s`; UNIONS_2; UNION_EMPTY]);;

let COMPACT_SPACE_PRODUCT_TOPOLOGY = prove
 (`!(tops:K->A topology) t.
        compact_space(product_topology t tops) <=>
        topspace(product_topology t tops) = {} \/
        !k. k IN t ==> compact_space(tops k)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[compact_space] THEN
  ASM_CASES_TAC `topspace(product_topology t (tops:K->A topology)) = {}` THEN
  ASM_REWRITE_TAC[COMPACT_IN_EMPTY] THEN EQ_TAC THENL
   [REWRITE_TAC[compact_space] THEN REPEAT STRIP_TAC THEN
    FIRST_ASSUM(MP_TAC o
      ISPECL [`(tops:K->A topology) k`; `\(f:K->A). f k`] o
      MATCH_MP (REWRITE_RULE[IMP_CONJ] IMAGE_COMPACT_IN)) THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION] THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
    MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
    REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ; SUBSET;
                FORALL_IN_IMAGE; IN_ELIM_THM] THEN
    ASM_SIMP_TAC[IN_IMAGE; EXTENSIONAL] THEN
    DISCH_THEN(X_CHOOSE_TAC `z:K->A`) THEN
    X_GEN_TAC `a:A` THEN DISCH_TAC THEN
    EXISTS_TAC
     `\i. if i = k then a else if i IN t then (z:K->A) i else ARB` THEN
    ASM_REWRITE_TAC[IN_ELIM_THM] THEN ASM_MESON_TAC[];
    DISCH_TAC] THEN
  ASM_CASES_TAC `t:K->bool = {}` THENL
   [ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_EMPTY] THEN
    MATCH_MP_TAC FINITE_IMP_COMPACT_IN THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_EMPTY; FINITE_SING; SUBSET_REFL];
    REWRITE_TAC[GSYM compact_space]] THEN
  MATCH_MP_TAC ALEXANDER_SUBBASE_THEOREM_ALT THEN
  EXISTS_TAC `{{x:K->A | x k IN u} | k IN t /\ open_in (tops k) u}` THEN
  EXISTS_TAC `topspace(product_topology t (tops:K->A topology))` THEN
  REPEAT CONJ_TAC THENL
   [MATCH_MP_TAC(SET_RULE
      `(?s. s IN f /\ x SUBSET s) ==> x SUBSET UNIONS f`) THEN
    REWRITE_TAC[EXISTS_IN_GSPEC] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `k:K` THEN DISCH_TAC THEN
    EXISTS_TAC `topspace((tops:K->A topology) k)` THEN
    ASM_REWRITE_TAC[OPEN_IN_TOPSPACE] THEN GEN_REWRITE_TAC I [SUBSET] THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN ASM SET_TAC[];
    GEN_REWRITE_TAC RAND_CONV [product_topology] THEN
    REWRITE_TAC[GSYM TOPSPACE_PRODUCT_TOPOLOGY_ALT];
    ALL_TAC] THEN
  X_GEN_TAC `C:((K->A)->bool)->bool` THEN STRIP_TAC THEN
  ASM_CASES_TAC
    `?k. k IN t /\
         topspace ((tops:K->A topology) k) SUBSET
         UNIONS {u | open_in (tops k) u /\ {x | x k IN u} IN C}`
  THENL
   [FIRST_X_ASSUM(X_CHOOSE_THEN `k:K` STRIP_ASSUME_TAC) THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `k:K`) THEN
    ASM_REWRITE_TAC[] THEN DISCH_TAC THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [compact_in]) THEN
    REWRITE_TAC[SUBSET_REFL] THEN DISCH_THEN(MP_TAC o SPEC
     `{u | open_in (tops k) u /\ {x:K->A | x k IN u} IN C}`) THEN
    ASM_SIMP_TAC[IN_ELIM_THM] THEN
    DISCH_THEN(X_CHOOSE_THEN `D:(A->bool)->bool` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `IMAGE (\u. {x:K->A | x k IN u}) D` THEN
    ASM_SIMP_TAC[FINITE_IMAGE] THEN
    CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
    REWRITE_TAC[SUBSET; TOPSPACE_PRODUCT_TOPOLOGY_ALT; UNIONS_IMAGE] THEN
    ASM SET_TAC[];
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [NOT_EXISTS_THM]) THEN
    REWRITE_TAC[TAUT `~(p /\ q) <=> p ==> ~q`; SET_RULE
     `(!x. x IN t ==> ~(f x SUBSET g x)) <=>
      (!x. ?a. x IN t ==> a IN f x /\ ~(a IN g x))`] THEN
    REWRITE_TAC[IN_UNIONS; IN_ELIM_THM; SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `z:K->A` THEN DISCH_TAC THEN UNDISCH_TAC
     `topspace (product_topology t (tops:K->A topology)) SUBSET UNIONS C` THEN
    MATCH_MP_TAC(SET_RULE
     `(?x. x IN s /\ ~(x IN t)) ==> s SUBSET t ==> Q`) THEN
    EXISTS_TAC `\i. if i IN t then (z:K->A) i else ARB` THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY_ALT; EXTENSIONAL; IN_ELIM_THM] THEN
    ASM_SIMP_TAC[IN_UNIONS] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (SET_RULE `t SUBSET s ==> (!x. x IN s ==> x IN t ==> ~P x)
        ==> ~(?x. x IN t /\ P x)`)) THEN
    REWRITE_TAC[FORALL_IN_GSPEC] THEN SIMP_TAC[IN_ELIM_THM] THEN
    ASM_MESON_TAC[]]);;

let COMPACT_IN_CARTESIAN_PRODUCT = prove
 (`!tops:K->A topology s k.
        compact_in (product_topology k tops) (cartesian_product k s) <=>
        cartesian_product k s = {} \/
        !i. i IN k ==> compact_in (tops i) (s i)`,
  REWRITE_TAC[COMPACT_IN_SUBSPACE; SUBTOPOLOGY_CARTESIAN_PRODUCT] THEN
  REWRITE_TAC[COMPACT_SPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[SUBSET_CARTESIAN_PRODUCT; TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[CARTESIAN_PRODUCT_EQ_EMPTY; o_DEF; TOPSPACE_SUBTOPOLOGY] THEN
  SET_TAC[]);;

let CLOSURE_OF_CARTESIAN_PRODUCT = prove
 (`!k tops s:K->A->bool.
        (product_topology k tops) closure_of (cartesian_product k s) =
        cartesian_product k (\i. (tops i) closure_of (s i))`,
  REPEAT GEN_TAC THEN REWRITE_TAC[closure_of; SET_RULE
   `(?y. y IN s /\ y IN t) <=> ~(s INTER t = {})`] THEN
  GEN_REWRITE_TAC I [EXTENSION] THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[SET_RULE `{x | x IN s /\ P x} = s INTER {x | P x}`] THEN
  REWRITE_TAC[GSYM INTER_CARTESIAN_PRODUCT] THEN
  X_GEN_TAC `f:K->A` THEN REWRITE_TAC[IN_INTER; o_DEF; IN_ELIM_THM] THEN
  REWRITE_TAC[cartesian_product; IN_ELIM_THM] THEN
  REWRITE_TAC[GSYM cartesian_product] THEN MATCH_MP_TAC(TAUT
   `(p ==> (q <=> r)) ==> (p /\ q <=> p /\ r)`) THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN EQ_TAC THENL
   [DISCH_TAC THEN X_GEN_TAC `i:K` THEN DISCH_TAC THEN
    X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC
     `topspace (product_topology k tops) INTER {x:K->A | x i IN u}`) THEN
    ASM_REWRITE_TAC[IN_INTER; TOPSPACE_PRODUCT_TOPOLOGY; IN_ELIM_THM] THEN
    ANTS_TAC THENL
     [CONJ_TAC THENL
       [ASM_REWRITE_TAC[cartesian_product; IN_ELIM_THM; o_DEF];
        REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY] THEN
        MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN
        REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN
        MATCH_MP_TAC RELATIVE_TO_INC THEN
        MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN ASM SET_TAC[]];
      REWRITE_TAC[EXTENSION; IN_INTER; NOT_IN_EMPTY; NOT_FORALL_THM] THEN
      REWRITE_TAC[cartesian_product; IN_ELIM_THM; o_DEF] THEN ASM SET_TAC[]];
    DISCH_TAC THEN X_GEN_TAC `u:(K->A)->bool` THEN
    REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY; UNION_OF; ARBITRARY] THEN
    DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
     `x IN s /\ (?u. (!c. c IN u ==> P c) /\ UNIONS u = s)
      ==> ?c. P c /\ c SUBSET s /\ x IN c`)) THEN
    REWRITE_TAC[IMP_CONJ; LEFT_IMP_EXISTS_THM; FORALL_RELATIVE_TO] THEN
    REWRITE_TAC[FORALL_INTERSECTION_OF] THEN
    X_GEN_TAC `t:((K->A)->bool)->bool` THEN STRIP_TAC THEN
    REWRITE_TAC[IN_INTER; TOPSPACE_PRODUCT_TOPOLOGY] THEN
    DISCH_TAC THEN STRIP_TAC THEN
    RULE_ASSUM_TAC(REWRITE_RULE[RIGHT_IMP_FORALL_THM; IMP_IMP]) THEN
    FIRST_ASSUM(MP_TAC o GEN `i:K` o SPECL
     [`i:K`;
      `topspace((tops:K->A topology) i) INTER
       INTERS {u | open_in (tops i) u /\ {x | x i IN u} IN t}`]) THEN
    DISCH_THEN(MP_TAC o MATCH_MP (MESON[]
     `(!i. P i /\ Q i /\ R i ==> S i)
      ==> (!i. P i ==> Q i /\ R i) ==> (!i. P i ==> S i)`)) THEN
    ANTS_TAC THENL
     [X_GEN_TAC `i:K` THEN DISCH_TAC THEN REWRITE_TAC[IN_INTER] THEN
      RULE_ASSUM_TAC(REWRITE_RULE[cartesian_product; IN_ELIM_THM; o_DEF]) THEN
      ASM_SIMP_TAC[IN_INTERS; IN_ELIM_THM] THEN CONJ_TAC THENL
       [X_GEN_TAC `v:A->bool` THEN STRIP_TAC THEN
        FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [IN_INTERS]) THEN
        DISCH_THEN(MP_TAC o SPEC `{x:K->A | x i IN v}`) THEN
        ASM_REWRITE_TAC[IN_ELIM_THM];
        REWRITE_TAC[GSYM INTERS_INSERT] THEN MATCH_MP_TAC OPEN_IN_INTERS THEN
        REWRITE_TAC[NOT_INSERT_EMPTY; FORALL_IN_INSERT] THEN
        SIMP_TAC[IN_ELIM_THM; OPEN_IN_TOPSPACE; FINITE_INSERT] THEN
        ONCE_REWRITE_TAC[SET_RULE
         `{x | P x /\ Q x} = {x | x IN P /\ Q x}`] THEN
        MATCH_MP_TAC FINITE_FINITE_PREIMAGE_GENERAL THEN
        ASM_REWRITE_TAC[] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
         `(!x. P x ==> Q x) ==> (!x. Q x ==> R x) ==> (!x. P x ==> R x)`)) THEN
        SIMP_TAC[LEFT_IMP_EXISTS_THM] THEN REPEAT STRIP_TAC THEN
        MATCH_MP_TAC(MESON[FINITE_SING; FINITE_SUBSET]
         `(?a. s SUBSET {a}) ==> FINITE s`) THEN
        MATCH_MP_TAC(SET_RULE `(!x y. f x = f y ==> x = y)
         ==> ?a. {x | P x /\ f x = c} SUBSET {a}`) THEN
        REWRITE_TAC[EXTENSION; IN_ELIM_THM] THEN
        MAP_EVERY X_GEN_TAC [`z1:A->bool`; `z2:A->bool`] THEN
        DISCH_THEN(fun th -> X_GEN_TAC `z:A` THEN
          MP_TAC(SPEC `(\i. z):K->A` th)) THEN
        REWRITE_TAC[]];
      REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN
      GEN_REWRITE_TAC (LAND_CONV o BINDER_CONV) [RIGHT_IMP_EXISTS_THM] THEN
      REWRITE_TAC[SKOLEM_THM; IN_INTER; IN_INTERS; IN_ELIM_THM] THEN
      DISCH_THEN(X_CHOOSE_THEN `x:K->A` (LABEL_TAC "*")) THEN
      EXISTS_TAC `\i. if i IN k then (x:K->A) i else ARB` THEN CONJ_TAC THENL
       [ASM_SIMP_TAC[cartesian_product; IN_ELIM_THM; EXTENSIONAL];
        FIRST_X_ASSUM(MATCH_MP_TAC o GEN_REWRITE_RULE I [SUBSET])] THEN
      REWRITE_TAC[IN_INTER; cartesian_product; IN_ELIM_THM; o_DEF] THEN
      ASM_SIMP_TAC[EXTENSIONAL; IN_ELIM_THM; IN_INTERS] THEN
      FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
       `(!x. P x ==> Q x) ==> (!x. x IN Q ==> P x ==> R x)
        ==> (!x. P x ==> R x)`)) THEN
      REWRITE_TAC[ETA_AX; FORALL_IN_GSPEC] THEN
      ASM_SIMP_TAC[IN_ELIM_THM]]]);;

let CLOSED_IN_CARTESIAN_PRODUCT = prove
 (`!(tops:K->A topology) (s:K->A->bool) k.
        closed_in (product_topology k tops) (cartesian_product k s) <=>
        cartesian_product k s = {} \/
        (!i. i IN k ==> closed_in (tops i) (s i))`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[GSYM CLOSURE_OF_EQ; CLOSURE_OF_CARTESIAN_PRODUCT] THEN
  REWRITE_TAC[CARTESIAN_PRODUCT_EQ] THEN
  ASM_CASES_TAC `cartesian_product k (s:K->A->bool) = {}` THEN
  ASM_REWRITE_TAC[] THEN DISJ1_TAC THEN POP_ASSUM MP_TAC THEN
  REWRITE_TAC[CARTESIAN_PRODUCT_EQ_EMPTY] THEN
  MATCH_MP_TAC MONO_EXISTS THEN SIMP_TAC[CLOSURE_OF_EMPTY]);;

let INTERIOR_IN_CARTESIAN_PRODUCT = prove
 (`!k tops s:K->A->bool.
        FINITE k
        ==> ((product_topology k tops) interior_of (cartesian_product k s) =
             cartesian_product k (\i. (tops i) interior_of (s i)))`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC INTERIOR_OF_UNIQUE THEN
  REWRITE_TAC[SUBSET_CARTESIAN_PRODUCT; INTERIOR_OF_SUBSET] THEN
  ASM_SIMP_TAC[OPEN_IN_CARTESIAN_PRODUCT; OPEN_IN_INTERIOR_OF] THEN
  X_GEN_TAC `w:(K->A)->bool` THEN STRIP_TAC THEN
  REWRITE_TAC[SUBSET; cartesian_product; IN_ELIM_THM] THEN
  X_GEN_TAC `f:K->A` THEN DISCH_TAC THEN CONJ_TAC THENL
   [FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [SUBSET]) THEN
    ASM_SIMP_TAC[cartesian_product; IN_ELIM_THM];
    X_GEN_TAC `i:K` THEN DISCH_TAC THEN
    REWRITE_TAC[interior_of; IN_ELIM_THM] THEN
    EXISTS_TAC `IMAGE (\x:K->A. x i) w` THEN REPEAT CONJ_TAC THENL
     [MP_TAC(ISPECL [`tops:K->A topology`; `k:K->bool`; `i:K`]
        OPEN_MAP_PRODUCT_PROJECTION) THEN
      ASM_SIMP_TAC[open_map];
      ASM SET_TAC[];
      FIRST_ASSUM(MP_TAC o ISPEC `\x:K->A. x i` o MATCH_MP IMAGE_SUBSET) THEN
      ASM_REWRITE_TAC[IMAGE_PROJECTION_CARTESIAN_PRODUCT] THEN SET_TAC[]]]);;

let CONNECTED_SPACE_PRODUCT_TOPOLOGY = prove
 (`!tops:K->A topology k.
        connected_space(product_topology k tops) <=>
        topspace(product_topology k tops) = {} \/
        !i. i IN k ==> connected_space(tops i)`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `topspace(product_topology k (tops:K->A topology)) = {}` THEN
  ASM_SIMP_TAC[CONNECTED_SPACE_TOPSPACE_EMPTY] THEN EQ_TAC THENL
   [REWRITE_TAC[GSYM CONNECTED_IN_TOPSPACE] THEN DISCH_TAC THEN
    X_GEN_TAC `i:K` THEN DISCH_TAC THEN FIRST_ASSUM(MP_TAC o
      ISPECL [`\(f:K->A). f i`; `(tops:K->A topology) i`] o
      MATCH_MP(REWRITE_RULE[IMP_CONJ_ALT]
        CONNECTED_IN_CONTINUOUS_MAP_IMAGE)) THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION] THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN
    REWRITE_TAC[IMAGE_PROJECTION_CARTESIAN_PRODUCT] THEN
    ASM_REWRITE_TAC[GSYM TOPSPACE_PRODUCT_TOPOLOGY; o_THM];
    DISCH_TAC] THEN
  REWRITE_TAC[connected_space; NOT_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:(K->A)->bool`; `v:(K->A)->bool`] THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN STRIP_TAC THEN
  SUBGOAL_THEN
   `(u:(K->A)->bool) SUBSET topspace(product_topology k tops) /\
    (v:(K->A)->bool) SUBSET topspace(product_topology k tops)`
  MP_TAC THENL [ASM_MESON_TAC[OPEN_IN_SUBSET]; ALL_TAC] THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN STRIP_TAC THEN
  UNDISCH_TAC `~(u:(K->A)->bool = {})` THEN
  REWRITE_TAC[EXTENSION; NOT_IN_EMPTY] THEN
  X_GEN_TAC `f:K->A` THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP (SET_RULE
   `s SUBSET u UNION v
    ==> u SUBSET s /\ v SUBSET s /\ u INTER v = {} /\ ~(v = {})
       ==> ~(s SUBSET u)`)) THEN
  ASM_REWRITE_TAC[NOT_IMP] THEN
  SUBGOAL_THEN `f IN cartesian_product k (topspace o (tops:K->A topology))`
  ASSUME_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  MP_TAC(ASSUME `open_in (product_topology k (tops:K->A topology)) u`) THEN
  REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY; UNION_OF; ARBITRARY] THEN
  DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
   `(?u. (!c. c IN u ==> P c) /\ UNIONS u = s)
    ==> !x. x IN s ==> ?c. P c /\ c SUBSET s /\ x IN c`)) THEN
  DISCH_THEN(MP_TAC o SPEC `f:K->A`) THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; IMP_CONJ; FORALL_RELATIVE_TO] THEN
  REWRITE_TAC[FORALL_INTERSECTION_OF] THEN
  REWRITE_TAC[IN_ELIM_THM] THEN
  X_GEN_TAC `t:((K->A)->bool)->bool` THEN STRIP_TAC THEN
  REWRITE_TAC[IN_INTER] THEN REPEAT STRIP_TAC THEN
  SUBGOAL_THEN
   `?l. FINITE l /\
        !i u. i IN k /\ open_in (tops i) u /\ u PSUBSET topspace(tops i) /\
              {x:K->A | x i IN u} IN t
              ==> i IN l`
  STRIP_ASSUME_TAC THENL
   [EXISTS_TAC
     `UNIONS(IMAGE (\c. {i | IMAGE (\x:K->A. x i) c PSUBSET topspace(tops i)})
                   t)` THEN
    CONJ_TAC THENL
     [ASM_SIMP_TAC[FINITE_UNIONS; FINITE_IMAGE; FORALL_IN_IMAGE] THEN
      FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
       `(!x. P x ==> Q x)
        ==> (!x. Q x ==> P x ==> R x) ==> (!x. P x ==> R x)`)) THEN
      SIMP_TAC[LEFT_IMP_EXISTS_THM] THEN
      MAP_EVERY X_GEN_TAC [`c:(K->A)->bool`; `i:K`; `v:A->bool`] THEN
      STRIP_TAC THEN DISCH_THEN(MP_TAC o MATCH_MP (SET_RULE
       `s IN t ==> !x. x IN INTERS t ==> x IN s`)) THEN
      DISCH_THEN(MP_TAC o SPEC `f:K->A`) THEN ASM_REWRITE_TAC[IN_ELIM_THM] THEN
      DISCH_TAC THEN MATCH_MP_TAC FINITE_SUBSET THEN
      EXISTS_TAC `{i:K}` THEN REWRITE_TAC[FINITE_SING] THEN
      REWRITE_TAC[SUBSET; IN_ELIM_THM; IN_SING] THEN X_GEN_TAC `j:K` THEN
      MATCH_MP_TAC(SET_RULE `(~P ==> s = UNIV) ==> (s PSUBSET t ==> P)`) THEN
      DISCH_TAC THEN
      REWRITE_TAC[EXTENSION; IN_UNIV; IN_IMAGE; IN_ELIM_THM] THEN
      X_GEN_TAC `z:A` THEN
      EXISTS_TAC `\m. if m = j then z else (f:K->A) m` THEN
      ASM_REWRITE_TAC[];
      REWRITE_TAC[UNIONS_IMAGE; IN_ELIM_THM] THEN
      MAP_EVERY X_GEN_TAC [`i:K`; `u:A->bool`] THEN STRIP_TAC THEN
      EXISTS_TAC `{x:K->A | x i IN u}` THEN ASM SET_TAC[]];
    ALL_TAC] THEN
  REWRITE_TAC[SUBSET] THEN X_GEN_TAC `h:K->A` THEN DISCH_TAC THEN
  ABBREV_TAC `g = \i. if i IN l then (f:K->A) i else h i` THEN
  SUBGOAL_THEN `(g:K->A) IN u` ASSUME_TAC THENL
   [FIRST_X_ASSUM(MATCH_MP_TAC o GEN_REWRITE_RULE I [SUBSET]) THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; IN_INTER; IN_INTERS] THEN
    CONJ_TAC THENL
     [MAP_EVERY UNDISCH_TAC
       [`(f:K->A) IN topspace (product_topology k tops)`;
        `(h:K->A) IN cartesian_product k (topspace o tops)`] THEN
      EXPAND_TAC "g" THEN
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product] THEN
      REWRITE_TAC[IN_ELIM_THM; EXTENSIONAL] THEN MESON_TAC[];
      ALL_TAC] THEN
    FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
     `(!x. P x ==> Q x)
      ==> (!x. Q x ==> P x ==> R x) ==> (!x. P x ==> R x)`)) THEN
    SIMP_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`c:(K->A)->bool`; `i:K`; `v:A->bool`] THEN
    REPEAT STRIP_TAC THEN EXPAND_TAC "g" THEN REWRITE_TAC[IN_ELIM_THM] THEN
    COND_CASES_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [IN_INTERS]) THEN
      DISCH_THEN(MP_TAC o SPEC `{x:K->A | x i IN v}`) THEN
      ASM_REWRITE_TAC[IN_ELIM_THM];
      UNDISCH_TAC `(h:K->A) IN cartesian_product k (topspace o tops)` THEN
      REWRITE_TAC[cartesian_product; IN_ELIM_THM; o_THM] THEN
      DISCH_THEN(MP_TAC o SPEC `i:K` o CONJUNCT2) THEN
      ASM_REWRITE_TAC[] THEN MATCH_MP_TAC(SET_RULE
       `s SUBSET t /\ ~(s PSUBSET t) ==> x IN t ==> x IN s`) THEN
      ASM_SIMP_TAC[OPEN_IN_SUBSET] THEN ASM_MESON_TAC[]];
    ALL_TAC] THEN
  SUBGOAL_THEN
   `!m. FINITE m
        ==> !h. h IN cartesian_product k (topspace o tops) /\
                {i | i IN k /\ ~((h:K->A) i = g i)} SUBSET m
                ==> h IN u`
  MP_TAC THENL
   [ALL_TAC;
    DISCH_THEN(MP_TAC o SPEC `l:K->bool`) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN MATCH_MP_TAC THEN ASM_REWRITE_TAC[] THEN
    EXPAND_TAC "g" THEN REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN MESON_TAC[]] THEN
  REPEAT(FIRST_X_ASSUM(K ALL_TAC o check (free_in `h:K->A` o concl))) THEN
  REPEAT(FIRST_X_ASSUM(K ALL_TAC o check (free_in `f:K->A` o concl))) THEN
  SUBGOAL_THEN `(g:K->A) IN cartesian_product k (topspace o tops)`
  ASSUME_TAC THENL
   [REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN ASM SET_TAC[];
    ALL_TAC] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN CONJ_TAC THENL
   [X_GEN_TAC `h:K->A` THEN REWRITE_TAC[SET_RULE
     `{i | i IN k /\ ~(h i = g i)} SUBSET {} <=>
      !i. i IN k ==> h i = g i`] THEN
    ASM_CASES_TAC `h:K->A = g` THEN ASM_REWRITE_TAC[] THEN
    MAP_EVERY UNDISCH_TAC
     [`(g:K->A) IN cartesian_product k (topspace o tops)`;
      `~(h:K->A = g)`] THEN
    REWRITE_TAC[FUN_EQ_THM] THEN
    REWRITE_TAC[cartesian_product; IN_ELIM_THM; EXTENSIONAL] THEN
    MESON_TAC[];
    ALL_TAC] THEN
  MAP_EVERY X_GEN_TAC [`i:K`; `m:K->bool`] THEN
  DISCH_THEN(CONJUNCTS_THEN2 (LABEL_TAC "*") STRIP_ASSUME_TAC) THEN
  X_GEN_TAC `h:K->A` THEN STRIP_TAC THEN
  ABBREV_TAC `(f:K->A) = \j. if j = i then g i else h j` THEN
  SUBGOAL_THEN `(f:K->A) IN cartesian_product k (topspace o tops)`
  ASSUME_TAC THENL
   [MAP_EVERY UNDISCH_TAC
     [`(g:K->A) IN cartesian_product k (topspace o tops)`;
      `(h:K->A) IN cartesian_product k (topspace o tops)`] THEN
    EXPAND_TAC "f" THEN REWRITE_TAC[cartesian_product; IN_ELIM_THM] THEN
    REWRITE_TAC[EXTENSIONAL; IN_ELIM_THM] THEN MESON_TAC[];
    ALL_TAC] THEN
  REMOVE_THEN "*" (MP_TAC o SPEC `f:K->A`) THEN
  ASM_REWRITE_TAC[] THEN ANTS_TAC THENL
   [EXPAND_TAC "f" THEN REWRITE_TAC[] THEN ASM SET_TAC[]; DISCH_TAC] THEN
  ASM_CASES_TAC `(h:K->A) IN v` THENL [ALL_TAC; ASM SET_TAC[]] THEN
  ASM_CASES_TAC `(i:K) IN k` THENL
   [ALL_TAC;
    ASM_CASES_TAC `h:K->A = f` THEN ASM_REWRITE_TAC[] THEN
    MAP_EVERY UNDISCH_TAC
     [`(f:K->A) IN cartesian_product k (topspace o tops)`;
      `(h:K->A) IN cartesian_product k (topspace o tops)`;
      `~(h:K->A = f)`] THEN
    GEN_REWRITE_TAC (LAND_CONV o RAND_CONV) [FUN_EQ_THM] THEN
    EXPAND_TAC "f" THEN REWRITE_TAC[cartesian_product; IN_ELIM_THM] THEN
    REWRITE_TAC[EXTENSIONAL; IN_ELIM_THM] THEN ASM SET_TAC[]] THEN
  SUBGOAL_THEN `connected_space ((tops:K->A topology) i)` MP_TAC THENL
   [ASM_MESON_TAC[]; REWRITE_TAC[connected_space; NOT_EXISTS_THM]] THEN
  DISCH_THEN(MP_TAC o SPECL
   [`{x | x IN topspace((tops:K->A topology) i) /\
          (\j. if j = i then x else h j) IN u}`;
    `{x | x IN topspace((tops:K->A topology) i) /\
          (\j. if j = i then x else h j) IN v}`]) THEN
  MATCH_MP_TAC(TAUT `p ==> ~p ==> q`) THEN
  GEN_REWRITE_TAC I [CONJ_ASSOC] THEN CONJ_TAC THENL
   [CONJ_TAC THEN MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
    EXISTS_TAC `product_topology k (tops:K->A topology)` THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_COMPONENTWISE] THEN
    (CONJ_TAC THENL
      [REWRITE_TAC[SUBSET; FORALL_IN_IMAGE];
       X_GEN_TAC `j:K` THEN DISCH_TAC THEN ASM_CASES_TAC `j:K = i` THEN
       ASM_REWRITE_TAC[CONTINUOUS_MAP_ID; CONTINUOUS_MAP_CONST]] THEN
     UNDISCH_TAC `(h:K->A) IN cartesian_product k (topspace o tops)` THEN
     REWRITE_TAC[cartesian_product; IN_ELIM_THM; o_DEF; EXTENSIONAL] THEN
     ASM SET_TAC[]);
    ALL_TAC] THEN
  CONJ_TAC THENL
   [SIMP_TAC[SUBSET; IN_ELIM_THM; IN_UNION] THEN FIRST_X_ASSUM(MATCH_MP_TAC o
    MATCH_MP (SET_RULE
      `s SUBSET u UNION v ==> IMAGE f q SUBSET s
       ==> (!x. x IN q ==> f x IN u \/ f x IN v)`)) THEN
    REWRITE_TAC[SUBSET; FORALL_IN_IMAGE] THEN
    UNDISCH_TAC `(h:K->A) IN cartesian_product k (topspace o tops)` THEN
    REWRITE_TAC[cartesian_product; IN_ELIM_THM; o_DEF; EXTENSIONAL] THEN
    ASM SET_TAC[];
    ALL_TAC] THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; IN_ELIM_THM] THEN CONJ_TAC THENL
   [EXISTS_TAC `(g:K->A) i` THEN ASM_REWRITE_TAC[] THEN
    UNDISCH_TAC `(g:K->A) IN cartesian_product k (topspace o tops)`;
    EXISTS_TAC `(h:K->A) i` THEN
    REWRITE_TAC[MESON[] `(if j = i then h i else h j) = h j`] THEN
    ASM_REWRITE_TAC[ETA_AX] THEN
    UNDISCH_TAC `(h:K->A) IN cartesian_product k (topspace o tops)`] THEN
  REWRITE_TAC[cartesian_product; IN_ELIM_THM; o_DEF] THEN ASM SET_TAC[]);;

let CONNECTED_IN_CARTESIAN_PRODUCT = prove
 (`!tops:K->A topology s k.
        connected_in (product_topology k tops) (cartesian_product k s) <=>
        cartesian_product k s = {} \/
        !i. i IN k ==> connected_in (tops i) (s i)`,
  REWRITE_TAC[connected_in; SUBTOPOLOGY_CARTESIAN_PRODUCT] THEN
  REWRITE_TAC[CONNECTED_SPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[SUBSET_CARTESIAN_PRODUCT; TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[CARTESIAN_PRODUCT_EQ_EMPTY; o_DEF; TOPSPACE_SUBTOPOLOGY] THEN
  SET_TAC[]);;

let PATH_CONNECTED_SPACE_PRODUCT_TOPOLOGY = prove
 (`!tops:K->A topology k.
        path_connected_space(product_topology k tops) <=>
        topspace(product_topology k tops) = {} \/
        !i. i IN k ==> path_connected_space(tops i)`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `topspace(product_topology k (tops:K->A topology)) = {}` THEN
  ASM_SIMP_TAC[PATH_CONNECTED_SPACE_TOPSPACE_EMPTY] THEN EQ_TAC THENL
   [REWRITE_TAC[GSYM PATH_CONNECTED_IN_TOPSPACE] THEN DISCH_TAC THEN
    X_GEN_TAC `i:K` THEN DISCH_TAC THEN FIRST_ASSUM(MP_TAC o
      ISPECL [`\(f:K->A). f i`; `(tops:K->A topology) i`] o
      MATCH_MP(REWRITE_RULE[IMP_CONJ_ALT]
        PATH_CONNECTED_IN_CONTINUOUS_MAP_IMAGE)) THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION] THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN
    REWRITE_TAC[IMAGE_PROJECTION_CARTESIAN_PRODUCT] THEN
    ASM_REWRITE_TAC[GSYM TOPSPACE_PRODUCT_TOPOLOGY; o_THM];
    DISCH_TAC] THEN
  REWRITE_TAC[path_connected_space; TOPSPACE_PRODUCT_TOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`x:K->A`; `y:K->A`] THEN STRIP_TAC THEN
  SUBGOAL_THEN
   `!i. ?g. i IN k
            ==> path_in ((tops:K->A topology) i) g /\
                g(&0) = x i /\ g(&1) = y i`
  MP_TAC THENL
   [X_GEN_TAC `i:K` THEN ASM_CASES_TAC `(i:K) IN k` THEN ASM_REWRITE_TAC[] THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `i:K`) THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[path_connected_space] THEN DISCH_THEN MATCH_MP_TAC THEN
    RULE_ASSUM_TAC(REWRITE_RULE[cartesian_product; o_DEF; IN_ELIM_THM]) THEN
    ASM_SIMP_TAC[];
    REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `g:K->real->A` THEN STRIP_TAC THEN
  EXISTS_TAC `\a i. if i IN k then (g:K->real->A) i a else ARB` THEN
  REWRITE_TAC[] THEN CONJ_TAC THENL
   [SIMP_TAC[path_in; CONTINUOUS_MAP_COMPONENTWISE] THEN
    SIMP_TAC[SUBSET; FORALL_IN_IMAGE; EXTENSIONAL; IN_ELIM_THM] THEN
    ASM_SIMP_TAC[GSYM path_in; ETA_AX];
    CONJ_TAC THENL
     [UNDISCH_TAC `(x:K->A) IN cartesian_product k (topspace o tops)`;
      UNDISCH_TAC `(y:K->A) IN cartesian_product k (topspace o tops)`] THEN
    SIMP_TAC[cartesian_product; EXTENSIONAL; IN_ELIM_THM] THEN
    REWRITE_TAC[FUN_EQ_THM; o_THM] THEN ASM_MESON_TAC[]]);;

let PATH_CONNECTED_IN_CARTESIAN_PRODUCT = prove
 (`!tops:K->A topology s k.
        path_connected_in (product_topology k tops) (cartesian_product k s) <=>
        cartesian_product k s = {} \/
        !i. i IN k ==> path_connected_in (tops i) (s i)`,
  REWRITE_TAC[path_connected_in; SUBTOPOLOGY_CARTESIAN_PRODUCT] THEN
  REWRITE_TAC[PATH_CONNECTED_SPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[SUBSET_CARTESIAN_PRODUCT; TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[CARTESIAN_PRODUCT_EQ_EMPTY; o_DEF; TOPSPACE_SUBTOPOLOGY] THEN
  SET_TAC[]);;

let T1_SPACE_PRODUCT_TOPOLOGY = prove
 (`!tops:K->A topology k.
        t1_space (product_topology k tops) <=>
        topspace(product_topology k tops) = {} \/
        !i. i IN k ==> t1_space (tops i)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[T1_SPACE_CLOSED_IN_SING] THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; IMP_IMP; RIGHT_IMP_FORALL_THM] THEN
  REWRITE_TAC[o_DEF; GSYM FORALL_CARTESIAN_PRODUCT_ELEMENTS] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  AP_TERM_TAC THEN ABS_TAC THEN
  W(MP_TAC o PART_MATCH (rand o rand) CLOSED_IN_CARTESIAN_PRODUCT o
    rand o rand o snd) THEN
  REWRITE_TAC[CARTESIAN_PRODUCT_EQ_EMPTY; NOT_INSERT_EMPTY] THEN
  DISCH_THEN(SUBST1_TAC o SYM) THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p ==> q <=> p ==> r)`) THEN
  REWRITE_TAC[cartesian_product; IN_ELIM_THM; EXTENSIONAL] THEN
  DISCH_TAC THEN AP_TERM_TAC THEN
  REWRITE_TAC[EXTENSION; IN_SING; IN_ELIM_THM] THEN
  REWRITE_TAC[FUN_EQ_THM] THEN ASM_MESON_TAC[]);;

let HAUSDORFF_SPACE_PRODUCT_TOPOLOGY = prove
 (`!tops:K->A topology k.
        hausdorff_space (product_topology k tops) <=>
        topspace(product_topology k tops) = {} \/
        !i. i IN k ==> hausdorff_space (tops i)`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MATCH_MP_TAC TOPOLOGICAL_PROPERTY_OF_PRODUCT_COMPONENT THEN
    REWRITE_TAC[HOMEOMORPHIC_HAUSDORFF_SPACE] THEN
    SIMP_TAC[HAUSDORFF_SPACE_SUBTOPOLOGY];
    ALL_TAC] THEN
  ASM_CASES_TAC
   `cartesian_product k (topspace o (tops:K->A topology)) = {}` THEN
  ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THENL
   [ASM_REWRITE_TAC[hausdorff_space; TOPSPACE_PRODUCT_TOPOLOGY; NOT_IN_EMPTY];
    ALL_TAC] THEN
  DISCH_TAC THEN REWRITE_TAC[hausdorff_space; FUN_EQ_THM] THEN
  MAP_EVERY X_GEN_TAC [`f:K->A`; `g:K->A`] THEN
  ONCE_REWRITE_TAC[TAUT `p /\ q /\ r ==> s <=> r ==> p /\ q ==> s`] THEN
  REWRITE_TAC[NOT_FORALL_THM; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `m:K` THEN DISCH_TAC THEN
  DISCH_THEN(fun th -> STRIP_ASSUME_TAC th THEN MP_TAC th) THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product] THEN
  REWRITE_TAC[IN_ELIM_THM; o_DEF; EXTENSIONAL] THEN
  ASM_CASES_TAC `(m:K) IN k` THENL [STRIP_TAC; ASM_MESON_TAC[]] THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE RAND_CONV [hausdorff_space] o
      SPEC `m:K`) THEN
  ASM_REWRITE_TAC[] THEN
  DISCH_THEN(MP_TAC o SPECL [`(f:K->A) m`; `(g:K->A) m`]) THEN
  ASM_SIMP_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:A->bool`] THEN STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC
   [`topspace(product_topology k tops) INTER {x:K->A | x m IN u}`;
    `topspace(product_topology k tops) INTER {x:K->A | x m IN v}` ] THEN
  ASM_REWRITE_TAC[IN_ELIM_THM; CONJ_ASSOC; IN_INTER] THEN
  CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
  REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY] THEN CONJ_TAC THEN
  MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN
  MATCH_MP_TAC RELATIVE_TO_INC THEN
  MATCH_MP_TAC FINITE_INTERSECTION_OF_INC THEN
  REWRITE_TAC[IN_ELIM_THM] THEN EXISTS_TAC `m:K` THENL
   [EXISTS_TAC `u:A->bool`; EXISTS_TAC `v:A->bool`] THEN
  ASM_REWRITE_TAC[]);;

let REGULAR_SPACE_PRODUCT_TOPOLOGY = prove
 (`!(tops:K->A topology) k.
        regular_space (product_topology k tops) <=>
        topspace (product_topology k tops) = {} \/
        !i. i IN k ==> regular_space (tops i)`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MATCH_MP_TAC TOPOLOGICAL_PROPERTY_OF_PRODUCT_COMPONENT THEN
    REWRITE_TAC[HOMEOMORPHIC_REGULAR_SPACE] THEN
    SIMP_TAC[REGULAR_SPACE_SUBTOPOLOGY];
    ALL_TAC] THEN
  ASM_CASES_TAC
   `cartesian_product k (topspace o (tops:K->A topology)) = {}` THEN
  ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THENL
   [ASM_REWRITE_TAC[regular_space; TOPSPACE_PRODUCT_TOPOLOGY;
                    IN_DIFF; NOT_IN_EMPTY];
    ALL_TAC] THEN
  REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN DISCH_TAC THEN
  REWRITE_TAC[MATCH_MP NEIGHBOURHOOD_BASE_OF_TOPOLOGY_BASE
   (SPEC_ALL OPEN_IN_PRODUCT_TOPOLOGY)] THEN
  REWRITE_TAC[PRODUCT_TOPOLOGY_BASE_ALT] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[FORALL_IN_GSPEC] THEN
  X_GEN_TAC `w:K->A->bool` THEN STRIP_TAC THEN
  X_GEN_TAC `x:K->A` THEN DISCH_TAC THEN
  RULE_ASSUM_TAC(REWRITE_RULE
   [NEIGHBOURHOOD_BASE_OF; RIGHT_IMP_FORALL_THM; IMP_IMP]) THEN
  FIRST_X_ASSUM(MP_TAC o GEN `i:K` o SPECL
   [`i:K`; `(w:K->A->bool) i`; `(x:K->A) i`]) THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE RAND_CONV [cartesian_product]) THEN
  ASM_SIMP_TAC[IN_ELIM_THM; IMP_CONJ] THEN DISCH_TAC THEN DISCH_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o TOP_DEPTH_CONV) [RIGHT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:K->A->bool`; `c:K->A->bool`] THEN DISCH_TAC THEN
  MAP_EVERY EXISTS_TAC
   [`cartesian_product k
      (\i. if w i = topspace(tops i) then topspace(tops i)
           else (u:K->A->bool) i)`;
    `cartesian_product k
      (\i. if w i = topspace(tops i) then topspace(tops i)
           else (c:K->A->bool) i)`] THEN
  REWRITE_TAC[] THEN REPEAT CONJ_TAC THENL
   [REWRITE_TAC[OPEN_IN_CARTESIAN_PRODUCT_GEN] THEN DISJ2_TAC THEN
    CONJ_TAC THENL [ALL_TAC; ASM_MESON_TAC[OPEN_IN_TOPSPACE]] THEN
    FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP
     (REWRITE_RULE[IMP_CONJ] FINITE_SUBSET)) THEN
    SET_TAC[];
    REWRITE_TAC[CLOSED_IN_CARTESIAN_PRODUCT] THEN DISJ2_TAC THEN
    ASM_MESON_TAC[CLOSED_IN_TOPSPACE];
    ASM_REWRITE_TAC[IN_ELIM_THM; cartesian_product] THEN
    ASM_MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET];
    REWRITE_TAC[SUBSET_CARTESIAN_PRODUCT] THEN ASM SET_TAC[];
    REWRITE_TAC[SUBSET_CARTESIAN_PRODUCT] THEN ASM SET_TAC[]]);;

let LOCALLY_COMPACT_SPACE_PRODUCT_TOPOLOGY = prove
 (`!(tops:K->A topology) k.
        locally_compact_space(product_topology k tops) <=>
        topspace(product_topology k tops) = {} \/
        FINITE {i | i IN k /\ ~compact_space(tops i)} /\
        !i. i IN k ==> locally_compact_space(tops i)`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `topspace(product_topology k (tops:K->A topology)) = {}` THEN
  ASM_REWRITE_TAC[locally_compact_space; NOT_IN_EMPTY] THEN EQ_TAC THENL
   [DISCH_TAC THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    DISCH_THEN(X_CHOOSE_TAC `z:K->A`) THEN CONJ_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o SPEC `z:K->A`) THEN
      ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
      MAP_EVERY X_GEN_TAC [`u:(K->A)->bool`; `c:(K->A)->bool`] THEN
      STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC `z:K->A` o
        REWRITE_RULE[OPEN_IN_PRODUCT_TOPOLOGY_ALT]) THEN
      ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
      X_GEN_TAC `v:K->A->bool` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ]
        FINITE_SUBSET)) THEN
      REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN X_GEN_TAC `i:K` THEN
      ASM_CASES_TAC `(i:K) IN k` THEN ASM_REWRITE_TAC[CONTRAPOS_THM] THEN
      DISCH_TAC THEN
      FIRST_ASSUM(MP_TAC o ISPECL [`(tops:K->A topology) i`; `\x:K->A. x i`] o
        MATCH_MP (REWRITE_RULE[IMP_CONJ] IMAGE_COMPACT_IN)) THEN
      ASM_SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION; compact_space] THEN
      MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN FIRST_X_ASSUM(MATCH_MP_TAC o
       MATCH_MP (SET_RULE `v = u ==> v SUBSET s /\ s SUBSET u ==> s = u`)) THEN
      CONJ_TAC THENL
       [TRANS_TAC SUBSET_TRANS `IMAGE (\x:K->A. x i) u` THEN
        ASM_SIMP_TAC[IMAGE_SUBSET] THEN TRANS_TAC SUBSET_TRANS
         `IMAGE (\x:K->A. x i) (cartesian_product k v)` THEN
        ASM_SIMP_TAC[IMAGE_SUBSET] THEN
        REWRITE_TAC[IMAGE_PROJECTION_CARTESIAN_PRODUCT] THEN
        COND_CASES_TAC THEN ASM_REWRITE_TAC[SUBSET_REFL] THEN
        ASM SET_TAC[];
        TRANS_TAC SUBSET_TRANS
          `IMAGE (\x:K->A. x i) (topspace(product_topology k tops))` THEN
        ASM_SIMP_TAC[IMAGE_SUBSET; COMPACT_IN_SUBSET_TOPSPACE] THEN
        RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PRODUCT_TOPOLOGY]) THEN
        ASM_REWRITE_TAC[IMAGE_PROJECTION_CARTESIAN_PRODUCT;
                        TOPSPACE_PRODUCT_TOPOLOGY] THEN
        REWRITE_TAC[o_THM; SUBSET_REFL]];
      X_GEN_TAC `i:K` THEN DISCH_TAC THEN
      REWRITE_TAC[GSYM locally_compact_space] THEN
      RULE_ASSUM_TAC(REWRITE_RULE[GSYM locally_compact_space]) THEN
      FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP (ONCE_REWRITE_RULE[IMP_CONJ_ALT]
        (REWRITE_RULE[CONJ_ASSOC]
                LOCALLY_COMPACT_SPACE_CONTINUOUS_OPEN_MAP_IMAGE)))  THEN
      EXISTS_TAC `\x:K->A. x i` THEN
      ASM_SIMP_TAC[OPEN_MAP_PRODUCT_PROJECTION; TOPSPACE_PRODUCT_TOPOLOGY;
                   CONTINUOUS_MAP_PRODUCT_PROJECTION;
                   IMAGE_PROJECTION_CARTESIAN_PRODUCT] THEN
      ASM_REWRITE_TAC[GSYM TOPSPACE_PRODUCT_TOPOLOGY; o_THM]];
    STRIP_TAC THEN X_GEN_TAC `z:K->A` THEN DISCH_TAC THEN
    SUBGOAL_THEN
     `!i. i IN k
          ==> ?u c. open_in (tops i) u /\
                    compact_in (tops i) c /\
                    ((z:K->A) i) IN u /\
                     u SUBSET c /\
                    (compact_space(tops i)
                     ==> u = topspace(tops i) /\ c = topspace(tops i))`
    MP_TAC THENL
     [X_GEN_TAC `i:K` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `i:K`) THEN ASM_REWRITE_TAC[] THEN
      DISCH_THEN(MP_TAC o SPEC `(z:K->A) i`) THEN ANTS_TAC THENL
       [ALL_TAC;
        ASM_CASES_TAC `compact_space((tops:K->A topology) i)` THEN
        ASM_REWRITE_TAC[] THEN DISCH_THEN(K ALL_TAC) THEN
        REPEAT(EXISTS_TAC `topspace((tops:K->A topology) i)`) THEN
        ASM_SIMP_TAC[OPEN_IN_TOPSPACE; GSYM compact_space; SUBSET_REFL]] THEN
      UNDISCH_TAC `(z:K->A) IN topspace (product_topology k tops)` THEN
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product] THEN
      ASM_SIMP_TAC[IN_ELIM_THM; o_THM];
      GEN_REWRITE_TAC (LAND_CONV o TOP_DEPTH_CONV) [RIGHT_IMP_EXISTS_THM] THEN
      REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
    MAP_EVERY X_GEN_TAC [`u:K->A->bool`; `c:K->A->bool`] THEN DISCH_TAC THEN
    MAP_EVERY EXISTS_TAC
     [`cartesian_product k (u:K->A->bool)`;
      `cartesian_product k (c:K->A->bool)`] THEN
    ASM_SIMP_TAC[COMPACT_IN_CARTESIAN_PRODUCT] THEN
    ASM_SIMP_TAC[SUBSET_CARTESIAN_PRODUCT] THEN
    REWRITE_TAC[OPEN_IN_CARTESIAN_PRODUCT_GEN] THEN CONJ_TAC THENL
     [DISJ2_TAC THEN ASM_SIMP_TAC[] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
        (REWRITE_RULE[IMP_CONJ] FINITE_SUBSET)) THEN
      REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN ASM_MESON_TAC[];
      UNDISCH_TAC `(z:K->A) IN topspace (product_topology k tops)` THEN
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product] THEN
      ASM_SIMP_TAC[IN_ELIM_THM; o_THM]]]);;

let COMPLETELY_REGULAR_SPACE_PRODUCT_TOPOLOGY = prove
 (`!(tops:K->A topology) k.
        completely_regular_space (product_topology k tops) <=>
        topspace (product_topology k tops) = {} \/
        !i. i IN k ==> completely_regular_space (tops i)`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MATCH_MP_TAC TOPOLOGICAL_PROPERTY_OF_PRODUCT_COMPONENT THEN
    REWRITE_TAC[HOMEOMORPHIC_COMPLETELY_REGULAR_SPACE] THEN
    SIMP_TAC[COMPLETELY_REGULAR_SPACE_SUBTOPOLOGY];
    ALL_TAC] THEN
  ASM_CASES_TAC `topspace (product_topology k (tops:K->A topology)) = {}` THENL
   [ASM_REWRITE_TAC[completely_regular_space; NOT_IN_EMPTY; IN_DIFF];
    ASM_REWRITE_TAC[]] THEN
  REWRITE_TAC[COMPLETELY_REGULAR_SPACE_ALT] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[FORALL_CLOSED_IN] THEN SIMP_TAC[IN_DIFF; IMP_CONJ] THEN
  GEN_REWRITE_TAC (BINOP_CONV o TOP_DEPTH_CONV) [RIGHT_IMP_FORALL_THM] THEN
  REWRITE_TAC[IMP_IMP; GSYM CONJ_ASSOC] THEN STRIP_TAC THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`w:(K->A)->bool`; `x:K->A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I
   [OPEN_IN_PRODUCT_TOPOLOGY_ALT]) THEN
  DISCH_THEN(MP_TAC o SPEC `x:K->A`) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `u:K->A->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN `i:K` o SPECL
   [`i:K`; `(u:K->A->bool) i`; `(x:K->A) i`]) THEN
  REWRITE_TAC[MESON[SUBSET; OPEN_IN_SUBSET]
   `(P /\ open_in top u /\ x IN topspace top /\ x IN u ==> Q) <=>
    P ==> open_in top u /\ x IN u ==> Q`] THEN
  MP_TAC(ASSUME `(x:K->A) IN cartesian_product k u`) THEN
  REWRITE_TAC[cartesian_product; IN_ELIM_THM] THEN
  STRIP_TAC THEN ASM_SIMP_TAC[] THEN
  GEN_REWRITE_TAC (LAND_CONV o BINDER_CONV) [RIGHT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IN_REAL_INTERVAL] THEN
  X_GEN_TAC `f:K->A->real` THEN DISCH_TAC THEN
  EXISTS_TAC
   `\z. &1 - product {i | i IN k /\ ~(u i :A->bool = topspace(tops i))}
                     (\i. &1 - (f:K->A->real) i (z i))` THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product; IN_ELIM_THM] THEN
  REPEAT CONJ_TAC THENL
   [MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB THEN
    REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
    MATCH_MP_TAC CONTINUOUS_MAP_PRODUCT THEN
    ASM_REWRITE_TAC[IN_ELIM_THM] THEN X_GEN_TAC `i:K` THEN STRIP_TAC THEN
    MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB THEN
    REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
    GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
    MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
    EXISTS_TAC `(tops:K->A topology) i` THEN
    ASM_SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION];
    REWRITE_TAC[REAL_ARITH `&1 - x = &0 <=> x = &1`] THEN
    MATCH_MP_TAC PRODUCT_EQ_1 THEN
    ASM_SIMP_TAC[IN_ELIM_THM; REAL_ARITH `&1 - x = &1 <=> x = &0`];
    X_GEN_TAC `y:K->A` THEN REWRITE_TAC[o_THM] THEN STRIP_TAC THEN
    REWRITE_TAC[REAL_ARITH `&1 - x = &1 <=> x = &0`] THEN
    ASM_SIMP_TAC[PRODUCT_EQ_0; REAL_ARITH `&1 - x = &0 <=> x = &1`] THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `y:K->A` o GEN_REWRITE_RULE I [SUBSET]) THEN
    ASM_REWRITE_TAC[cartesian_product; IN_ELIM_THM] THEN ASM_MESON_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* "Capped" equivalent bounded metrics and general product metrics.          *)
(* ------------------------------------------------------------------------- *)

let capped_metric = new_definition
 `capped_metric d (m:A metric) =
        if d <= &0 then m
        else metric(mspace m,(\(x,y). min d (mdist m (x,y))))`;;

let CAPPED_METRIC = prove
 (`!d m:A metric.
        mspace (capped_metric d m) = mspace m /\
        mdist (capped_metric d m) =
           \(x,y). if d <= &0 then mdist m (x,y) else min d (mdist m (x,y))`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `d:real <= &0` THEN
  ASM_REWRITE_TAC[capped_metric; PAIRED_ETA_THM; ETA_AX] THEN
  REWRITE_TAC[capped_metric; mspace; mdist; GSYM PAIR_EQ] THEN
  REWRITE_TAC[GSYM(CONJUNCT2 metric_tybij)] THEN
  REWRITE_TAC[is_metric_space; GSYM mspace; GSYM mdist] THEN
  ASM_SIMP_TAC[REAL_ARITH `~(d <= &0) ==> (&0 <= min d x <=> &0 <= x)`] THEN
  ASM_SIMP_TAC[MDIST_POS_LE; MDIST_0; REAL_ARITH
    `~(d <= &0) /\ &0 <= x  ==> (min d x = &0 <=> x = &0)`] THEN
  CONJ_TAC THENL [MESON_TAC[MDIST_SYM]; REPEAT STRIP_TAC] THEN
  MATCH_MP_TAC(REAL_ARITH
   `~(d <= &0) /\ &0 <= y /\ &0 <= z /\ x <= y + z
    ==> min d x <= min d y + min d z`) THEN
  ASM_MESON_TAC[MDIST_POS_LE; MDIST_TRIANGLE]);;

let MDIST_CAPPED = prove
 (`!d m x y:A. &0 < d ==> mdist(capped_metric d m) (x,y) <= d`,
  SIMP_TAC[CAPPED_METRIC; GSYM REAL_NOT_LT] THEN REAL_ARITH_TAC);;

let MTOPOLOGY_CAPPED_METRIC = prove
 (`!d m:A metric. mtopology(capped_metric d m) = mtopology m`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `d <= &0` THENL
   [ASM_MESON_TAC[capped_metric];
    RULE_ASSUM_TAC(REWRITE_RULE[REAL_NOT_LE])] THEN
  REWRITE_TAC[TOPOLOGY_EQ] THEN
  X_GEN_TAC `s:A->bool` THEN ASM_REWRITE_TAC[OPEN_IN_MTOPOLOGY] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET mspace m` THEN
  ASM_REWRITE_TAC[CAPPED_METRIC] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `a:A` THEN ASM_CASES_TAC `(a:A) IN s` THEN ASM_REWRITE_TAC[] THEN
  ASM_REWRITE_TAC[SUBSET; IN_MBALL] THEN
  ASM_CASES_TAC `(a:A) IN mspace m` THENL
   [ASM_REWRITE_TAC[CAPPED_METRIC]; ASM SET_TAC[]] THEN
  EQ_TAC THEN
  DISCH_THEN(X_CHOOSE_THEN `r:real` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `min (d / &2) r` THEN
  ASM_REWRITE_TAC[REAL_LT_MIN; REAL_HALF] THEN
  REPEAT STRIP_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  ASM_REWRITE_TAC[] THEN ASM_REAL_ARITH_TAC);;

let CAUCHY_IN_CAPPED_METRIC = prove
 (`!d (m:A metric) x.
        cauchy_in (capped_metric d m) x <=> cauchy_in m x`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `d <= &0` THENL
   [ASM_MESON_TAC[capped_metric]; ALL_TAC] THEN
  ASM_REWRITE_TAC[cauchy_in; CAPPED_METRIC; REAL_MIN_LT] THEN
  ASM_MESON_TAC[REAL_ARITH `~(d < min d e)`; REAL_LT_MIN; REAL_NOT_LE]);;

let MCOMPLETE_CAPPED_METRIC = prove
 (`!d (m:A metric). mcomplete(capped_metric d m) <=> mcomplete m`,
  REWRITE_TAC[mcomplete; CAUCHY_IN_CAPPED_METRIC; MTOPOLOGY_CAPPED_METRIC]);;

let BOUNDED_EQUIVALENT_METRIC = prove
 (`!m:A metric d.
        &0 < d
        ==> ?m'. mspace m' = mspace m /\
                 mtopology m' = mtopology m /\
                 !x y. mdist m' (x,y) < d`,
  REPEAT STRIP_TAC THEN EXISTS_TAC `capped_metric (d / &2) m:A metric` THEN
  ASM_REWRITE_TAC[MTOPOLOGY_CAPPED_METRIC; CAPPED_METRIC] THEN
  ASM_REAL_ARITH_TAC);;

let SUP_METRIC_CARTESIAN_PRODUCT = prove
 (`!k (m:K->(A)metric) m'.
        metric(cartesian_product k (mspace o m),
               \(x,y). sup {mdist(m i) (x i,y i) | i IN k}) = m' /\
        ~(k = {}) /\
        (?c. !i x y. i IN k /\ x IN mspace(m i) /\ y IN mspace(m i)
                      ==> mdist(m i) (x,y) <= c)
        ==> mspace m' = cartesian_product k (mspace o m) /\
            mdist m' = (\(x,y). sup {mdist(m i) (x i,y i) | i IN k}) /\
            !x y b. x IN cartesian_product k (mspace o m) /\
                    y IN cartesian_product k (mspace o m)
                    ==> (mdist m' (x,y) <= b <=>
                         !i. i IN k ==> mdist (m i) (x i,y i) <= b)`,
  REPEAT GEN_TAC THEN DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  ABBREV_TAC `M = \(x,y). sup {mdist(m i) (x i:A,y i) | (i:K) IN k}` THEN
  SUBGOAL_THEN
   `!x (y:K->A) b.
        x IN cartesian_product k (mspace o m) /\
        y IN cartesian_product k (mspace o m)
        ==> (M(x,y) <= b <=> !i. i IN k ==> mdist (m i) (x i,y i) <= b)`
  ASSUME_TAC THENL
   [REWRITE_TAC[cartesian_product; o_DEF; IN_ELIM_THM] THEN
    REPEAT STRIP_TAC THEN EXPAND_TAC "M" THEN REWRITE_TAC[] THEN
    W(MP_TAC o PART_MATCH (lhand o rand) REAL_SUP_LE_EQ o lhand o snd) THEN
    REWRITE_TAC[FORALL_IN_GSPEC] THEN ASM SET_TAC[];
    ALL_TAC] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP (MESON[]
   `m = m' ==> mspace m = mspace m' /\ mdist m = mdist m'`)) THEN
  REWRITE_TAC[GSYM PAIR_EQ; mspace; mdist] THEN
  W(MP_TAC o PART_MATCH (lhand o rand) (CONJUNCT2 metric_tybij) o
    lhand o lhand o snd) THEN
  DISCH_THEN(MP_TAC o fst o EQ_IMP_RULE) THEN ANTS_TAC THENL
   [ALL_TAC;
    DISCH_THEN SUBST1_TAC THEN DISCH_THEN(SUBST1_TAC o SYM) THEN
    ASM_REWRITE_TAC[GSYM mdist]] THEN
  REWRITE_TAC[is_metric_space] THEN
  MATCH_MP_TAC(TAUT `p /\ (p ==> q) ==> p /\ q`) THEN CONJ_TAC THENL
   [REPEAT STRIP_TAC THEN EXPAND_TAC "M" THEN REWRITE_TAC[] THEN
    MATCH_MP_TAC REAL_LE_SUP THEN
    ASM_SIMP_TAC[FORALL_IN_GSPEC; EXISTS_IN_GSPEC] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[cartesian_product; IN_ELIM_THM; o_THM]) THEN
    FIRST_X_ASSUM(X_CHOOSE_TAC `c:real`) THEN EXISTS_TAC `c:real` THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    MATCH_MP_TAC MONO_EXISTS THEN ASM_SIMP_TAC[MDIST_POS_LE];
    DISCH_TAC] THEN
  REPEAT CONJ_TAC THENL
   [ASM_SIMP_TAC[GSYM REAL_LE_ANTISYM] THEN REPEAT GEN_TAC THEN
    DISCH_THEN(fun th ->
      SUBST1_TAC(MATCH_MP CARTESIAN_PRODUCT_EQ_MEMBERS_EQ th) THEN
      MP_TAC th) THEN
    REWRITE_TAC[cartesian_product; o_THM; IN_ELIM_THM] THEN
    SIMP_TAC[METRIC_ARITH
     `x IN mspace m /\ y IN mspace m ==> (mdist m (x,y) <= &0 <=> x = y)`];
    REPEAT STRIP_TAC THEN EXPAND_TAC "M" THEN REWRITE_TAC[IN_ELIM_THM] THEN
    AP_TERM_TAC THEN MATCH_MP_TAC(SET_RULE
     `(!i. i IN w ==> f i = g i) ==> {f i | i IN w} = {g i | i IN w}`) THEN
    RULE_ASSUM_TAC(REWRITE_RULE[cartesian_product; IN_ELIM_THM; o_THM]) THEN
    ASM_MESON_TAC[MDIST_SYM];
    MAP_EVERY X_GEN_TAC [`x:K->A`; `y:K->A`; `z:K->A`] THEN
    ASM_SIMP_TAC[] THEN STRIP_TAC THEN X_GEN_TAC `i:K` THEN DISCH_TAC THEN
    TRANS_TAC REAL_LE_TRANS
      `mdist (m i) ((x:K->A) i,y i) + mdist (m i) (y i,z i)` THEN
    CONJ_TAC THENL
     [MATCH_MP_TAC MDIST_TRIANGLE THEN
      RULE_ASSUM_TAC(REWRITE_RULE[cartesian_product; IN_ELIM_THM; o_THM]) THEN
      ASM_SIMP_TAC[];
      MATCH_MP_TAC REAL_LE_ADD2 THEN EXPAND_TAC "M" THEN
      REWRITE_TAC[] THEN CONJ_TAC THEN MATCH_MP_TAC ELEMENT_LE_SUP THEN
      RULE_ASSUM_TAC(REWRITE_RULE[cartesian_product; IN_ELIM_THM; o_THM]) THEN
      ASM SET_TAC[]]]);;

let (METRIZABLE_SPACE_PRODUCT_TOPOLOGY,
     COMPLETELY_METRIZABLE_SPACE_PRODUCT_TOPOLOGY) = (CONJ_PAIR o prove)
 (`(!(tops:K->A topology) k.
        metrizable_space (product_topology k tops) <=>
        topspace (product_topology k tops) = {} \/
        COUNTABLE {i | i IN k /\ ~(?a. topspace(tops i) SUBSET {a})} /\
        !i. i IN k ==> metrizable_space (tops i)) /\
   (!(tops:K->A topology) k.
        completely_metrizable_space (product_topology k tops) <=>
        topspace (product_topology k tops) = {} \/
        COUNTABLE {i | i IN k /\ ~(?a. topspace(tops i) SUBSET {a})} /\
        !i. i IN k ==> completely_metrizable_space (tops i))`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  MATCH_MP_TAC(TAUT
   `(n ==> m) /\ (t ==> n) /\ (m ==> t \/ m') /\ (n ==> t \/ n') /\
    (~t ==> m /\ m' ==> c) /\ (~t ==> c ==> (m' ==> m) /\ (n' ==> n))
    ==> (m <=> t \/ c /\ m') /\ (n <=> t \/ c /\ n')`) THEN
  REWRITE_TAC[COMPLETELY_METRIZABLE_IMP_METRIZABLE_SPACE] THEN CONJ_TAC THENL
   [SIMP_TAC[GSYM SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_EMPTY] THEN
    REWRITE_TAC[COMPLETELY_METRIZABLE_SPACE_DISCRETE_TOPOLOGY];
    GEN_REWRITE_TAC I [CONJ_ASSOC]] THEN
  CONJ_TAC THENL
   [CONJ_TAC THEN MATCH_MP_TAC TOPOLOGICAL_PROPERTY_OF_PRODUCT_COMPONENT THEN
    REWRITE_TAC[HOMEOMORPHIC_COMPLETELY_METRIZABLE_SPACE;
                HOMEOMORPHIC_METRIZABLE_SPACE] THEN
    ASM_SIMP_TAC[METRIZABLE_SPACE_SUBTOPOLOGY] THEN REPEAT STRIP_TAC THEN
    MATCH_MP_TAC COMPLETELY_METRIZABLE_SPACE_CLOSED_IN THEN
    ASM_REWRITE_TAC[CLOSED_IN_CARTESIAN_PRODUCT] THEN
    DISJ2_TAC THEN REPEAT STRIP_TAC THEN
    COND_CASES_TAC THEN ASM_REWRITE_TAC[CLOSED_IN_TOPSPACE] THEN
    FIRST_ASSUM(MP_TAC o
      MATCH_MP COMPLETELY_METRIZABLE_IMP_METRIZABLE_SPACE) THEN
    DISCH_THEN(MP_TAC o MATCH_MP METRIZABLE_IMP_T1_SPACE) THEN
    REWRITE_TAC[T1_SPACE_PRODUCT_TOPOLOGY] THEN
    REWRITE_TAC[T1_SPACE_CLOSED_IN_SING; RIGHT_IMP_FORALL_THM; IMP_IMP] THEN
    STRIP_TAC THENL [ASM SET_TAC[]; FIRST_X_ASSUM MATCH_MP_TAC] THEN
    RULE_ASSUM_TAC(REWRITE_RULE
     [TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product; o_DEF; IN_ELIM_THM]) THEN
    ASM SET_TAC[];
    ALL_TAC] THEN
  CONJ_TAC THENL
   [REPEAT STRIP_TAC THEN ABBREV_TAC
     `l = {i:K | i IN k /\ ~(?a:A. topspace(tops i) SUBSET {a})}` THEN
    SUBGOAL_THEN
     `!i:K. ?p q:A.
        i IN l ==> p IN topspace(tops i) /\ q IN topspace(tops i) /\ ~(p = q)`
    MP_TAC THENL [EXPAND_TAC "l" THEN SET_TAC[]; ALL_TAC] THEN
    REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`a:K->A`; `b:K->A`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
    REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; o_DEF; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `z:K->A` THEN DISCH_TAC THEN
    ABBREV_TAC `p:K->A = \i. if i IN l then a i else z i` THEN
    ABBREV_TAC `q:K->K->A = \i j. if j = i then b i else p j` THEN
    SUBGOAL_THEN
     `p IN topspace(product_topology k (tops:K->A topology)) /\
      (!i:K. i IN l
             ==> q i IN topspace(product_topology k (tops:K->A topology)))`
    STRIP_ASSUME_TAC THENL
     [UNDISCH_TAC `(z:K->A) IN cartesian_product k (\x. topspace(tops x))` THEN
      MAP_EVERY EXPAND_TAC ["q"; "p"] THEN
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product; o_THM] THEN
      REWRITE_TAC[EXTENSIONAL; IN_ELIM_THM] THEN ASM SET_TAC[];
      ALL_TAC] THEN
    SUBGOAL_THEN
     `!u:(K->A)->bool.
        open_in (product_topology k tops) u /\ p IN u
        ==> FINITE {i:K | i IN l /\ ~(q i IN u)}`
    ASSUME_TAC THENL
     [X_GEN_TAC `u:(K->A)->bool` THEN
      DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
      REWRITE_TAC[OPEN_IN_PRODUCT_TOPOLOGY_ALT] THEN
      DISCH_THEN(MP_TAC o SPEC `p:K->A`) THEN
      ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
      X_GEN_TAC `v:K->A->bool` THEN
      DISCH_THEN(CONJUNCTS_THEN2 MP_TAC STRIP_ASSUME_TAC) THEN
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] FINITE_SUBSET) THEN
      REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN X_GEN_TAC `i:K` THEN
      MATCH_MP_TAC(TAUT
       `(l ==> k) /\ (k /\ l ==> p ==> q) ==> l /\ ~q ==> k /\ ~p`) THEN
      CONJ_TAC THENL [ASM SET_TAC[]; REPEAT STRIP_TAC] THEN
      FIRST_X_ASSUM(MATCH_MP_TAC o GEN_REWRITE_RULE I [SUBSET]) THEN
      EXPAND_TAC "q" THEN UNDISCH_TAC `(p:K->A) IN cartesian_product k v` THEN
      REWRITE_TAC[cartesian_product; IN_ELIM_THM; EXTENSIONAL] THEN
      ASM SET_TAC[];
      ALL_TAC] THEN
    FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [metrizable_space]) THEN
    DISCH_THEN(X_CHOOSE_TAC `m:(K->A)metric`) THEN
    MATCH_MP_TAC COUNTABLE_SUBSET THEN
    EXISTS_TAC `UNIONS {{i | i IN l /\
                             ~((q:K->K->A) i IN mball m (p,inv(&n + &1)))} |
                        n IN (:num)}` THEN
    CONJ_TAC THENL
     [MATCH_MP_TAC COUNTABLE_UNIONS THEN REWRITE_TAC[SIMPLE_IMAGE] THEN
      SIMP_TAC[COUNTABLE_IMAGE; NUM_COUNTABLE; FORALL_IN_IMAGE] THEN
      X_GEN_TAC `n:num` THEN DISCH_THEN(K ALL_TAC) THEN
      MATCH_MP_TAC FINITE_IMP_COUNTABLE THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
      ASM_REWRITE_TAC[OPEN_IN_MBALL] THEN MATCH_MP_TAC CENTRE_IN_MBALL THEN
      REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
      ASM_MESON_TAC[TOPSPACE_MTOPOLOGY];
      REWRITE_TAC[SUBSET; UNIONS_GSPEC; IN_ELIM_THM; IN_UNIV] THEN
      X_GEN_TAC `i:K` THEN DISCH_TAC THEN MP_TAC(snd(EQ_IMP_RULE(ISPEC
       `mdist (m:(K->A)metric) (p,q(i:K))` ARCH_EVENTUALLY_INV1))) THEN
      ANTS_TAC THENL
       [MATCH_MP_TAC MDIST_POS_LT THEN REPEAT
         (CONJ_TAC THENL [ASM_MESON_TAC[TOPSPACE_MTOPOLOGY]; ALL_TAC]) THEN
        DISCH_THEN(MP_TAC o C AP_THM `i:K`) THEN
        MAP_EVERY EXPAND_TAC ["q"; "p"] THEN REWRITE_TAC[] THEN
        ASM_SIMP_TAC[];
        DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_HAPPENS_SEQUENTIALLY) THEN
        MATCH_MP_TAC MONO_EXISTS THEN
        ASM_REWRITE_TAC[IN_MBALL] THEN REAL_ARITH_TAC]];
    ALL_TAC] THEN
  DISCH_TAC THEN DISCH_TAC THEN
  ASM_CASES_TAC `k:K->bool = {}` THENL
   [ASM_REWRITE_TAC[NOT_IN_EMPTY; EMPTY_GSPEC; COUNTABLE_EMPTY] THEN
    REWRITE_TAC[PRODUCT_TOPOLOGY_EMPTY_DISCRETE;
                METRIZABLE_SPACE_DISCRETE_TOPOLOGY;
                COMPLETELY_METRIZABLE_SPACE_DISCRETE_TOPOLOGY];
    ALL_TAC] THEN
  REWRITE_TAC[metrizable_space; completely_metrizable_space] THEN
  GEN_REWRITE_TAC (BINOP_CONV o LAND_CONV o BINDER_CONV)
      [RIGHT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM; AND_FORALL_THM] THEN
  X_GEN_TAC `m:K->A metric` THEN ONCE_REWRITE_TAC[EQ_SYM_EQ] THEN
  ASM_CASES_TAC `!i. i IN k ==> mtopology(m i) = (tops:K->A topology) i` THEN
  ASM_SIMP_TAC[] THENL [ALL_TAC; ASM_MESON_TAC[]] THEN MATCH_MP_TAC(MESON[]
   `!m. P m /\ (Q ==> C m) ==> (?m. P m) /\ (Q ==> ?m. C m /\ P m)`) THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I
   [COUNTABLE_AS_INJECTIVE_IMAGE_SUBSET]) THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; INJECTIVE_ON_LEFT_INVERSE] THEN
  MAP_EVERY X_GEN_TAC [`nk:num->K`; `c:num->bool`] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (X_CHOOSE_TAC `kn:K->num`)) THEN
  MP_TAC(ISPECL
   [`k:K->bool`; `\i. capped_metric (inv(&(kn i) + &1)) ((m:K->A metric) i)`]
   SUP_METRIC_CARTESIAN_PRODUCT) THEN
  REWRITE_TAC[o_DEF; CONJUNCT1(SPEC_ALL CAPPED_METRIC)] THEN
  MATCH_MP_TAC(MESON[]
   `Q /\ (!m. P m ==> R m)
    ==> (!m. a = m /\ Q ==> P m) ==> ?m. R m`) THEN
  CONJ_TAC THENL
   [ASM_REWRITE_TAC[] THEN EXISTS_TAC `&1:real` THEN
    REWRITE_TAC[CAPPED_METRIC; GSYM REAL_NOT_LT] THEN
    REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
    REWRITE_TAC[REAL_NOT_LT; REAL_MIN_LE] THEN REPEAT STRIP_TAC THEN
    DISJ1_TAC THEN MATCH_MP_TAC REAL_INV_LE_1 THEN REAL_ARITH_TAC;
    X_GEN_TAC `M:(K->A)metric`] THEN
  SUBGOAL_THEN
   `cartesian_product k (\i. mspace (m i)) =
    topspace(product_topology k (tops:K->A topology))`
  SUBST1_TAC THENL
   [REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; CARTESIAN_PRODUCT_EQ] THEN
    ASM_SIMP_TAC[GSYM TOPSPACE_MTOPOLOGY; o_THM];
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    DISCH_THEN(CONJUNCTS_THEN2 (ASSUME_TAC o SYM) ASSUME_TAC)] THEN
  MATCH_MP_TAC(TAUT `p /\ (p ==> q) ==> p /\ q`) THEN CONJ_TAC THENL
   [REWRITE_TAC[MTOPOLOGY_BASE; product_topology] THEN
    REWRITE_TAC[GSYM TOPSPACE_PRODUCT_TOPOLOGY_ALT] THEN
    REWRITE_TAC[PRODUCT_TOPOLOGY_BASE_ALT] THEN
    MATCH_MP_TAC TOPOLOGY_BASES_EQ THEN
    REWRITE_TAC[SET_RULE `GSPEC P x <=> x IN GSPEC P`] THEN
    REWRITE_TAC[EXISTS_IN_GSPEC; IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
    REWRITE_TAC[FORALL_IN_GSPEC; GSYM CONJ_ASSOC; IN_MBALL] THEN CONJ_TAC THENL
     [MAP_EVERY X_GEN_TAC [`z:K->A`; `r:real`] THEN STRIP_TAC THEN
      X_GEN_TAC `x:K->A` THEN STRIP_TAC THEN
      SUBGOAL_THEN
       `(!i. i IN k ==> (z:K->A) i IN topspace(tops i)) /\
        (!i. i IN k ==> (x:K->A) i IN topspace(tops i))`
      STRIP_ASSUME_TAC THENL
       [MAP_EVERY UNDISCH_TAC
         [`(z:K->A) IN mspace M`; `(x:K->A) IN mspace M`] THEN
        ASM_SIMP_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product; o_DEF] THEN
        SET_TAC[];
        ALL_TAC] THEN
      SUBGOAL_THEN `?R. &0 < R /\ mdist M (z:K->A,x) < R /\ R < r`
      STRIP_ASSUME_TAC THENL
       [ASM_MESON_TAC[REAL_LT_BETWEEN; REAL_LET_TRANS; MDIST_POS_LE];
        ALL_TAC] THEN
      EXISTS_TAC
       `\i. if R <= inv(&(kn i) + &1) then mball (m i) (z i,R)
            else topspace((tops:K->A topology) i)` THEN
      REWRITE_TAC[] THEN REPEAT CONJ_TAC THENL
       [MP_TAC(ASSUME `&0 < R`) THEN DISCH_THEN(MP_TAC o
          SPEC `&1:real` o MATCH_MP REAL_ARCH) THEN
        DISCH_THEN(X_CHOOSE_TAC `n:num`) THEN
        MATCH_MP_TAC FINITE_SUBSET THEN
        EXISTS_TAC `IMAGE (nk:num->K) (c INTER (0..n))` THEN
        SIMP_TAC[FINITE_IMAGE; FINITE_INTER; FINITE_NUMSEG] THEN
        REWRITE_TAC[SUBSET; IN_ELIM_THM; MESON[]
         `~((if p then x else y) = y) <=> p /\ ~(x = y)`] THEN
        FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
         `{i | i IN k /\ P i} = IMAGE nk c
          ==> (!i. i IN k /\ Q i ==> P i) /\
              (!n. n IN c ==> Q(nk n) ==> n IN s)
              ==> !i. i IN k /\ Q i ==> i IN IMAGE nk (c INTER s)`)) THEN
        CONJ_TAC THENL
         [X_GEN_TAC `i:K` THEN
          DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
          MATCH_MP_TAC(SET_RULE
           `!x. b SUBSET u /\ x IN b
                ==> P /\ ~(b = u) ==> ~(?a. u SUBSET {a})`) THEN
          EXISTS_TAC `(z:K->A) i` THEN CONJ_TAC THENL
           [REWRITE_TAC[SUBSET; IN_MBALL];
            MATCH_MP_TAC CENTRE_IN_MBALL] THEN
          ASM_MESON_TAC[TOPSPACE_MTOPOLOGY];
          X_GEN_TAC `m:num` THEN ASM_SIMP_TAC[IN_NUMSEG; LE_0] THEN
          DISCH_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
          GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN
          REWRITE_TAC[NOT_LE; REAL_NOT_LE] THEN DISCH_TAC THEN
          REWRITE_TAC[REAL_ARITH `inv x < y <=> &1 / x < y`] THEN
          ASM_SIMP_TAC[REAL_LT_LDIV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
          FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REAL_ARITH
           `&1 < n * r ==> r * n < r * m ==> &1 < r * m`)) THEN
          ASM_SIMP_TAC[REAL_LT_LMUL_EQ; REAL_OF_NUM_ADD; REAL_OF_NUM_LT] THEN
          ASM_ARITH_TAC];
        ASM_MESON_TAC[OPEN_IN_MBALL; OPEN_IN_TOPSPACE];
        SUBGOAL_THEN `(x:K->A) IN cartesian_product k (topspace o tops)`
        MP_TAC THENL [ASM_MESON_TAC[TOPSPACE_PRODUCT_TOPOLOGY]; ALL_TAC] THEN
        REWRITE_TAC[cartesian_product; o_DEF; IN_ELIM_THM] THEN
        STRIP_TAC THEN ASM_REWRITE_TAC[] THEN X_GEN_TAC `i:K` THEN
        DISCH_TAC THEN COND_CASES_TAC THEN ASM_SIMP_TAC[IN_MBALL] THEN
        REPEAT(CONJ_TAC THENL
         [ASM_MESON_TAC[TOPSPACE_MTOPOLOGY]; ALL_TAC]) THEN
        FIRST_X_ASSUM(MP_TAC o SPECL
         [`z:K->A`; `x:K->A`; `mdist M (z:K->A,x)`]) THEN
        ANTS_TAC THENL [ASM_MESON_TAC[]; REWRITE_TAC[REAL_LE_REFL]] THEN
        DISCH_THEN(MP_TAC o SPEC `i:K`) THEN
        ASM_REWRITE_TAC[CAPPED_METRIC] THEN ASM_REAL_ARITH_TAC;
        REWRITE_TAC[SUBSET] THEN X_GEN_TAC `y:K->A` THEN
        DISCH_THEN(LABEL_TAC "*") THEN
        SUBGOAL_THEN `(y:K->A) IN mspace M` ASSUME_TAC THENL
         [ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY] THEN
          REMOVE_THEN "*" MP_TAC THEN REWRITE_TAC[cartesian_product] THEN
          REWRITE_TAC[IN_ELIM_THM; o_THM] THEN
          MATCH_MP_TAC MONO_AND THEN REWRITE_TAC[] THEN
          MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `i:K` THEN
          ASM_CASES_TAC `(i:K) IN k` THEN ASM_REWRITE_TAC[] THEN
          COND_CASES_TAC THEN ASM_REWRITE_TAC[IN_MBALL] THEN
          MATCH_MP_TAC(SET_RULE
           `s SUBSET t ==> P /\ x IN s /\ Q ==> x IN t`) THEN
          ASM_SIMP_TAC[GSYM TOPSPACE_MTOPOLOGY; SUBSET_REFL];
          ALL_TAC] THEN
        ASM_REWRITE_TAC[IN_MBALL] THEN
        TRANS_TAC REAL_LET_TRANS `R:real` THEN ASM_REWRITE_TAC[] THEN
        FIRST_X_ASSUM(MP_TAC o SPECL
         [`z:K->A`; `y:K->A`; `R:real`]) THEN
        ANTS_TAC THENL [ASM_MESON_TAC[]; DISCH_THEN SUBST1_TAC] THEN
        REWRITE_TAC[CAPPED_METRIC; REAL_ARITH `x <= &0 <=> ~(&0 < x)`] THEN
        REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
        REWRITE_TAC[REAL_MIN_LE] THEN X_GEN_TAC `i:K` THEN DISCH_TAC THEN
        MATCH_MP_TAC(REAL_ARITH
         `(a <= b ==> c <= d) ==> b <= a \/ c <= d`) THEN
        DISCH_TAC THEN REMOVE_THEN "*" MP_TAC THEN
        ASM_REWRITE_TAC[cartesian_product; IN_ELIM_THM] THEN
        DISCH_THEN(MP_TAC o SPEC `i:K` o CONJUNCT2) THEN
        ASM_REWRITE_TAC[IN_MBALL] THEN REAL_ARITH_TAC];
      X_GEN_TAC `u:K->A->bool` THEN STRIP_TAC THEN
      X_GEN_TAC `z:K->A` THEN DISCH_TAC THEN
      SUBGOAL_THEN `(z:K->A) IN mspace M` ASSUME_TAC THENL
       [UNDISCH_TAC `(z:K->A) IN cartesian_product k u` THEN
        ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product] THEN
        REWRITE_TAC[IN_ELIM_THM; o_THM] THEN
        ASM_MESON_TAC[OPEN_IN_SUBSET; SUBSET];
        EXISTS_TAC `z:K->A` THEN ASM_SIMP_TAC[MDIST_REFL; CONJ_ASSOC]] THEN
      SUBGOAL_THEN
       `!i. ?r. i IN k ==> &0 < r /\ mball (m i) ((z:K->A) i,r) SUBSET u i`
      MP_TAC THENL
       [X_GEN_TAC `i:K` THEN REWRITE_TAC[RIGHT_EXISTS_IMP_THM] THEN
        DISCH_TAC THEN
        SUBGOAL_THEN `open_in(mtopology(m i)) ((u:K->A->bool) i)` MP_TAC THENL
         [ASM_MESON_TAC[]; REWRITE_TAC[OPEN_IN_MTOPOLOGY]] THEN
        DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MATCH_MP_TAC) THEN
        UNDISCH_TAC `(z:K->A) IN cartesian_product k u` THEN
        ASM_SIMP_TAC[cartesian_product; IN_ELIM_THM];
        REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
      X_GEN_TAC `r:K->real` THEN DISCH_TAC THEN
      SUBGOAL_THEN `?a:K. a IN k` STRIP_ASSUME_TAC THENL
       [ASM SET_TAC[]; ALL_TAC] THEN
      EXISTS_TAC
        `inf (IMAGE (\i. min (r i) (inv(&(kn i) + &1)))
                 (a INSERT {i | i IN k /\
                                ~(u i = topspace ((tops:K->A topology) i))})) /
         &2` THEN
      ASM_SIMP_TAC[REAL_LT_INF_FINITE; FINITE_INSERT; NOT_INSERT_EMPTY;
        REAL_HALF; FINITE_IMAGE; IMAGE_EQ_EMPTY; FORALL_IN_IMAGE] THEN
      REWRITE_TAC[REAL_LT_MIN; REAL_LT_INV_EQ] THEN
      REWRITE_TAC[REAL_ARITH `&0 < &n + &1`] THEN
      ASM_SIMP_TAC[FORALL_IN_INSERT; IN_ELIM_THM] THEN
      REWRITE_TAC[SUBSET; IN_MBALL] THEN X_GEN_TAC `x:K->A` THEN
      DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC o CONJUNCT2) THEN
      DISCH_THEN(MP_TAC o MATCH_MP REAL_LT_IMP_LE) THEN
      FIRST_X_ASSUM(MP_TAC o SPECL [`z:K->A`; `x:K->A`]) THEN
      REWRITE_TAC[RIGHT_FORALL_IMP_THM] THEN
      ANTS_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
      DISCH_THEN(fun th -> REWRITE_TAC[th]) THEN
      SUBGOAL_THEN `(x:K->A) IN topspace(product_topology k tops)` MP_TAC THENL
       [ASM_MESON_TAC[]; REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY]] THEN
      REWRITE_TAC[cartesian_product; o_THM; IN_ELIM_THM] THEN
      DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
      ASM_REWRITE_TAC[IMP_IMP; AND_FORALL_THM] THEN
      MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `i:K` THEN
      ASM_CASES_TAC `(i:K) IN k` THEN ASM_REWRITE_TAC[] THEN
      DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
      REWRITE_TAC[REAL_ARITH `x <= y / &2 <=> &2 * x <= y`] THEN
      ASM_SIMP_TAC[REAL_LE_INF_FINITE; FINITE_INSERT; NOT_INSERT_EMPTY;
        REAL_HALF; FINITE_IMAGE; IMAGE_EQ_EMPTY; FORALL_IN_IMAGE] THEN
      REWRITE_TAC[FORALL_IN_INSERT] THEN
      DISCH_THEN(MP_TAC o SPEC `i:K` o CONJUNCT2) THEN
      ASM_CASES_TAC `(u:K->A->bool) i = topspace(tops i)` THEN
      ASM_REWRITE_TAC[IN_ELIM_THM] THEN
      REWRITE_TAC[CAPPED_METRIC; REAL_ARITH `x <= &0 <=> ~(&0 < x)`] THEN
      REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
      DISCH_THEN(MP_TAC o MATCH_MP (REAL_ARITH
       `&2 * min a b <= min c a ==> &0 < a /\ &0 < c ==> b < c`)) THEN
      REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
      ASM_SIMP_TAC[] THEN DISCH_TAC THEN
      REPEAT(FIRST_X_ASSUM(MP_TAC o SPEC `i:K`)) THEN
      ASM_REWRITE_TAC[] THEN REPEAT STRIP_TAC THEN
      FIRST_X_ASSUM(MATCH_MP_TAC o GEN_REWRITE_RULE I [SUBSET]) THEN
      ASM_REWRITE_TAC[IN_MBALL] THEN
      CONJ_TAC THENL [ALL_TAC; ASM_MESON_TAC[TOPSPACE_MTOPOLOGY]] THEN
      UNDISCH_TAC `(z:K->A) IN mspace M` THEN
      ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product] THEN
      REWRITE_TAC[IN_ELIM_THM; o_DEF] THEN
      ASM_MESON_TAC[TOPSPACE_MTOPOLOGY]];
    DISCH_TAC THEN REWRITE_TAC[mcomplete] THEN DISCH_THEN(LABEL_TAC "*") THEN
    X_GEN_TAC `x:num->K->A` THEN ASM_REWRITE_TAC[cauchy_in] THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[LIMIT_COMPONENTWISE] THEN
    SUBGOAL_THEN
     `!i. ?y. i IN k ==> limit (tops i) (\n. (x:num->K->A) n i) y sequentially`
    MP_TAC THENL
     [X_GEN_TAC `i:K` THEN ASM_CASES_TAC `(i:K) IN k` THEN
      ASM_REWRITE_TAC[] THEN REMOVE_THEN "*" (MP_TAC o SPEC `i:K`) THEN
      ASM_SIMP_TAC[] THEN DISCH_THEN MATCH_MP_TAC THEN
      REWRITE_TAC[cauchy_in; GSYM TOPSPACE_MTOPOLOGY] THEN CONJ_TAC THENL
       [RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PRODUCT_TOPOLOGY;
           cartesian_product; IN_ELIM_THM; o_DEF]) THEN ASM_MESON_TAC[];
        X_GEN_TAC `e:real` THEN DISCH_TAC] THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `min e (inv(&(kn(i:K)) + &1)) / &2`) THEN
      REWRITE_TAC[REAL_HALF; REAL_LT_MIN; REAL_LT_INV_EQ] THEN
      ANTS_TAC THENL [ASM_REAL_ARITH_TAC; MATCH_MP_TAC MONO_EXISTS] THEN
      X_GEN_TAC `N:num` THEN DISCH_TAC THEN
      MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPECL [`m:num`; `n:num`]) THEN
      ASM_REWRITE_TAC[] THEN DISCH_THEN(MP_TAC o MATCH_MP REAL_LT_IMP_LE) THEN
      ASM_SIMP_TAC[] THEN DISCH_THEN(MP_TAC o SPEC `i:K`) THEN
      ASM_REWRITE_TAC[CAPPED_METRIC; REAL_ARITH `x <= &0 <=> ~(&0 < x)`] THEN
      REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
      MATCH_MP_TAC(REAL_ARITH
        `&0 < d /\ &0 < e ==> min d x <= min e d / &2 ==> x < e`) THEN
      ASM_REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`];
      REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM]] THEN
    X_GEN_TAC `y:K->A` THEN DISCH_TAC THEN
    EXISTS_TAC `RESTRICTION k (y:K->A)` THEN
    ASM_REWRITE_TAC[REWRITE_RULE[IN] RESTRICTION_IN_EXTENSIONAL] THEN
    SIMP_TAC[RESTRICTION; EVENTUALLY_TRUE] THEN ASM_REWRITE_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* A binary product topology where the two types can be different.           *)
(* ------------------------------------------------------------------------- *)

let prod_topology = new_definition
 `prod_topology (top1:A topology) (top2:B topology) =
    topology (ARBITRARY UNION_OF
               {s CROSS t | open_in top1 s /\ open_in top2 t})`;;

let OPEN_IN_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
     open_in (prod_topology top1 top2) =
     (ARBITRARY UNION_OF {s CROSS t | open_in top1 s /\ open_in top2 t})`,
  REWRITE_TAC[prod_topology; GSYM(CONJUNCT2 topology_tybij)] THEN
  REPEAT GEN_TAC THEN MATCH_MP_TAC ISTOPOLOGY_BASE THEN
  ONCE_REWRITE_TAC[SET_RULE `GSPEC p x <=> x IN GSPEC p`] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_IN_GSPEC] THEN
  MAP_EVERY (fun t -> X_GEN_TAC t THEN DISCH_TAC)
   [`s1:A->bool`; `t1:B->bool`; `s2:A->bool`; `t2:B->bool`] THEN
  REWRITE_TAC[IN_ELIM_THM] THEN
  MAP_EVERY EXISTS_TAC [`s1 INTER s2:A->bool`; `t1 INTER t2:B->bool`] THEN
  ASM_SIMP_TAC[OPEN_IN_INTER; INTER_CROSS]);;

let TOPSPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        topspace(prod_topology top1 top2) =
        topspace top1 CROSS topspace top2`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC LAND_CONV [topspace] THEN
  REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ] THEN CONJ_TAC THENL
   [REWRITE_TAC[UNIONS_SUBSET; FORALL_IN_GSPEC; OPEN_IN_PROD_TOPOLOGY] THEN
    X_GEN_TAC `s:A#B->bool` THEN REWRITE_TAC[UNION_OF; ARBITRARY] THEN
    REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN GEN_TAC THEN
    DISCH_THEN(CONJUNCTS_THEN2 MP_TAC (SUBST1_TAC o SYM)) THEN
    REWRITE_TAC[UNIONS_SUBSET] THEN MATCH_MP_TAC(SET_RULE
     `(!x. x IN P ==> Q x) ==> (!x. R x ==> P x) ==> (!x. R x ==> Q x)`) THEN
    REWRITE_TAC[ETA_AX; FORALL_IN_GSPEC; SUBSET_CROSS] THEN
    MESON_TAC[OPEN_IN_SUBSET];
    MATCH_MP_TAC(SET_RULE `x IN s ==> x SUBSET UNIONS s`) THEN
    REWRITE_TAC[OPEN_IN_PROD_TOPOLOGY; IN_ELIM_THM] THEN
    MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN
    REWRITE_TAC[IN_ELIM_THM] THEN MAP_EVERY EXISTS_TAC
     [`topspace top1:A->bool`; `topspace top2:B->bool`] THEN
    REWRITE_TAC[OPEN_IN_TOPSPACE]]);;

let SUBTOPOLOGY_CROSS = prove
 (`!top1:A topology top2:B topology s t.
        subtopology (prod_topology top1 top2) (s CROSS t) =
        prod_topology (subtopology top1 s) (subtopology top2 t)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[TOPOLOGY_EQ] THEN
  REWRITE_TAC[GSYM OPEN_IN_RELATIVE_TO; OPEN_IN_PROD_TOPOLOGY] THEN
  REWRITE_TAC[ARBITRARY_UNION_OF_RELATIVE_TO] THEN
  X_GEN_TAC `t:A#B->bool` THEN AP_THM_TAC THEN AP_TERM_TAC THEN
  GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `s:A#B->bool` THEN
  REWRITE_TAC[relative_to] THEN
  GEN_REWRITE_TAC (LAND_CONV o BINDER_CONV o LAND_CONV) [GSYM IN] THEN
  REWRITE_TAC[EXISTS_IN_GSPEC; INTER_CROSS] THEN
  REWRITE_TAC[IN_ELIM_THM] THEN MESON_TAC[]);;

let PROD_TOPOLOGY_SUBTOPOLOGY = prove
 (`(!(top:A topology) (top':B topology) s.
        prod_topology (subtopology top s) top' =
        subtopology (prod_topology top top') (s CROSS topspace top')) /\
   (!(top:A topology) (top':B topology) t.
        prod_topology top (subtopology top' t) =
        subtopology (prod_topology top top') (topspace top CROSS t))`,
  REWRITE_TAC[SUBTOPOLOGY_CROSS; SUBTOPOLOGY_TOPSPACE]);;

let PROD_TOPOLOGY_DISCRETE_TOPOLOGY = prove
 (`!s:A->bool t:B->bool.
        prod_topology (discrete_topology s) (discrete_topology t) =
        discrete_topology (s CROSS t)`,
  REPEAT STRIP_TAC THEN CONV_TAC SYM_CONV THEN
  REWRITE_TAC[DISCRETE_TOPOLOGY_UNIQUE] THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; TOPSPACE_DISCRETE_TOPOLOGY] THEN
  REWRITE_TAC[OPEN_IN_PROD_TOPOLOGY; OPEN_IN_DISCRETE_TOPOLOGY] THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN STRIP_TAC THEN
  MATCH_MP_TAC ARBITRARY_UNION_OF_INC THEN REWRITE_TAC[IN_ELIM_THM] THEN
  MAP_EVERY EXISTS_TAC [`{x:A}`; `{y:B}`] THEN
  REWRITE_TAC[EXTENSION; FORALL_PAIR_THM; IN_SING; IN_CROSS; SUBSET] THEN
  REWRITE_TAC[PAIR_EQ] THEN ASM_MESON_TAC[]);;

let OPEN_IN_PROD_TOPOLOGY_ALT = prove
 (`!top1:A topology top2:B topology s.
        open_in (prod_topology top1 top2) s <=>
        !x y. (x,y) IN s
              ==> ?u v. open_in top1 u /\ open_in top2 v /\
                        x IN u /\ y IN v /\ u CROSS v SUBSET s`,
  REWRITE_TAC[OPEN_IN_PROD_TOPOLOGY] THEN
  REWRITE_TAC[ARBITRARY_UNION_OF_ALT; EXISTS_IN_GSPEC] THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS; GSYM CONJ_ASSOC]);;

let OPEN_MAP_FST,OPEN_MAP_SND = (CONJ_PAIR o prove)
 (`(!top1:A topology top2:B topology.
      open_map (prod_topology top1 top2,top1) FST) /\
   (!top1:A topology top2:B topology.
      open_map (prod_topology top1 top2,top2) SND)`,
  REPEAT STRIP_TAC THEN  REWRITE_TAC[open_map; OPEN_IN_PROD_TOPOLOGY_ALT] THEN
  X_GEN_TAC `w:A#B->bool` THEN STRIP_TAC THEN
  GEN_REWRITE_TAC I [OPEN_IN_SUBOPEN] THEN
  REWRITE_TAC[FORALL_IN_IMAGE; FORALL_PAIR_THM; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`x:A`; `y:B`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:B->bool`] THEN STRIP_TAC THENL
   [EXISTS_TAC `u:A->bool` THEN ASM_REWRITE_TAC[] THEN
    TRANS_TAC SUBSET_TRANS `IMAGE FST ((u:A->bool) CROSS (v:B->bool))`;
    EXISTS_TAC `v:B->bool` THEN ASM_REWRITE_TAC[] THEN
    TRANS_TAC SUBSET_TRANS `IMAGE SND ((u:A->bool) CROSS (v:B->bool))`] THEN
  ASM_SIMP_TAC[IMAGE_SUBSET] THEN
  REWRITE_TAC[IMAGE_FST_CROSS; IMAGE_SND_CROSS] THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[SUBSET_REFL] THEN ASM SET_TAC[]);;

let OPEN_IN_CROSS = prove
 (`!top1:A topology top2:B topology s t.
        open_in (prod_topology top1 top2) (s CROSS t) <=>
        s = {} \/ t = {} \/ open_in top1 s /\ open_in top2 t`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `s:A->bool = {}` THEN
  ASM_REWRITE_TAC[CROSS_EMPTY; OPEN_IN_EMPTY] THEN
  ASM_CASES_TAC `t:B->bool = {}` THEN
  ASM_REWRITE_TAC[CROSS_EMPTY; OPEN_IN_EMPTY] THEN
  REWRITE_TAC[OPEN_IN_PROD_TOPOLOGY_ALT; FORALL_PASTECART; IN_CROSS] THEN
  GEN_REWRITE_TAC (RAND_CONV o BINOP_CONV) [OPEN_IN_SUBOPEN] THEN
  REWRITE_TAC[SUBSET_CROSS] THEN EQ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  DISCH_TAC THEN MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(CONJUNCTS_THEN2
   (MP_TAC o SPEC `x:A`) (MP_TAC o SPEC `y:B`)) THEN
  ASM SET_TAC[]);;

let CLOSURE_OF_CROSS = prove
 (`!top1:A topology top2:B topology s t.
        (prod_topology top1 top2) closure_of (s CROSS t) =
        (top1 closure_of s) CROSS (top2 closure_of t)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[closure_of; SET_RULE
   `(?y. y IN s /\ y IN t) <=> ~(s INTER t = {})`] THEN
  GEN_REWRITE_TAC I [EXTENSION] THEN REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY] THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS; IN_ELIM_THM] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN
  ASM_CASES_TAC `(x:A) IN topspace top1` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `(y:B) IN topspace top2` THEN ASM_REWRITE_TAC[] THEN
  EQ_TAC THEN DISCH_TAC THENL
   [CONJ_TAC THENL
     [X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `(u CROSS topspace top2):A#B->bool`);
      X_GEN_TAC `v:B->bool` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `(topspace top1 CROSS v):A#B->bool`)] THEN
    ASM_REWRITE_TAC[IN_CROSS; OPEN_IN_CROSS; OPEN_IN_TOPSPACE] THEN
    SIMP_TAC[INTER_CROSS; CROSS_EQ_EMPTY; DE_MORGAN_THM];
    REWRITE_TAC[OPEN_IN_PROD_TOPOLOGY_ALT] THEN X_GEN_TAC `w:A#B->bool` THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPECL [`x:A`; `y:B`])) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:B->bool`] THEN
    REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    MATCH_MP_TAC(SET_RULE
     `~(u INTER s = {}) ==> s SUBSET t ==> ~(u INTER t = {})`) THEN
    REWRITE_TAC[INTER_CROSS; CROSS_EQ_EMPTY] THEN ASM_MESON_TAC[]]);;

let CLOSED_IN_CROSS = prove
 (`!top1:A topology top2:B topology s t.
        closed_in (prod_topology top1 top2) (s CROSS t) <=>
        s = {} \/ t = {} \/ closed_in top1 s /\ closed_in top2 t`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[GSYM CLOSURE_OF_EQ; CLOSURE_OF_CROSS; CROSS_EQ] THEN
  ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[CLOSURE_OF_EMPTY] THEN
  ASM_CASES_TAC `t:B->bool = {}` THEN ASM_REWRITE_TAC[CLOSURE_OF_EMPTY]);;

let LIMIT_PAIRWISE = prove
 (`!(net:C net) top1:A topology top2:B topology f l.
        limit (prod_topology top1 top2) f l net <=>
        limit top1 (FST o f) (FST l) net /\
        limit top2 (SND o f) (SND l) net`,
  REPLICATE_TAC 4 GEN_TAC THEN REWRITE_TAC[FORALL_PAIR_THM] THEN
  MAP_EVERY X_GEN_TAC [`l1:A`; `l2:B`] THEN
  REWRITE_TAC[limit; TOPSPACE_PROD_TOPOLOGY; IN_CROSS] THEN
  ASM_CASES_TAC `(l1:A) IN topspace top1` THEN
  ASM_CASES_TAC `(l2:B) IN topspace top2` THEN ASM_REWRITE_TAC[] THEN
  EQ_TAC THEN DISCH_TAC THENL
   [CONJ_TAC THENL
     [X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC
       `(u:A->bool) CROSS (topspace top2:B->bool)`);
      X_GEN_TAC `v:B->bool` THEN STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC
       `(topspace top1:A->bool) CROSS (v:B->bool)`)] THEN
    ASM_REWRITE_TAC[IN_CROSS; OPEN_IN_CROSS; OPEN_IN_TOPSPACE];
    X_GEN_TAC `w:A#B->bool` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_PROD_TOPOLOGY_ALT]) THEN
    DISCH_THEN(MP_TAC o SPECL [`l1:A`; `l2:B`]) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:B->bool`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(CONJUNCTS_THEN2
     (MP_TAC o SPEC `u:A->bool`) (MP_TAC o SPEC `v:B->bool`)) THEN
    ASM_REWRITE_TAC[GSYM EVENTUALLY_AND; IMP_IMP]] THEN
  MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] EVENTUALLY_MONO) THEN
  X_GEN_TAC `a:C` THEN REWRITE_TAC[o_THM] THEN
  SPEC_TAC(`(f:C->A#B) a`,`y:A#B`) THEN
  RULE_ASSUM_TAC(REWRITE_RULE[SUBSET; FORALL_PAIR_THM; IN_CROSS]) THEN
  ASM_SIMP_TAC[FORALL_PAIR_THM; IN_CROSS]);;

let CONTINUOUS_MAP_PAIRWISE = prove
 (`!top top1 top2 f:A->B#C.
        continuous_map (top,prod_topology top1 top2) f <=>
        continuous_map (top,top1) (FST o f) /\
        continuous_map (top,top2) (SND o f)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[continuous_map; TOPSPACE_PROD_TOPOLOGY] THEN
  MAP_EVERY ABBREV_TAC [`g = FST o (f:A->B#C)`; `h = SND o (f:A->B#C)`] THEN
  SUBGOAL_THEN `!x. (f:A->B#C) x = g x,h x` (fun th -> REWRITE_TAC[th]) THENL
   [MAP_EVERY EXPAND_TAC ["g"; "h"] THEN REWRITE_TAC[o_THM]; ALL_TAC] THEN
  REWRITE_TAC[IN_CROSS] THEN
  ASM_CASES_TAC `!x. x IN topspace top ==> (g:A->B) x IN topspace top1` THEN
  ASM_SIMP_TAC[] THENL [ALL_TAC; ASM_MESON_TAC[]] THEN
  ASM_CASES_TAC `!x. x IN topspace top ==> (h:A->C) x IN topspace top2` THEN
  ASM_SIMP_TAC[] THEN EQ_TAC THEN DISCH_TAC THENL
   [CONJ_TAC THENL
     [X_GEN_TAC `u:B->bool` THEN STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC
       `(u:B->bool) CROSS (topspace top2:C->bool)`);
      X_GEN_TAC `v:C->bool` THEN STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC
       `(topspace top1:B->bool) CROSS (v:C->bool)`)] THEN
    ASM_REWRITE_TAC[IN_CROSS; OPEN_IN_CROSS; OPEN_IN_TOPSPACE] THEN
    MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN ASM SET_TAC[];
    X_GEN_TAC `w:B#C->bool` THEN STRIP_TAC THEN
    GEN_REWRITE_TAC I [OPEN_IN_SUBOPEN] THEN
    X_GEN_TAC `x:A` THEN REWRITE_TAC[IN_ELIM_THM] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_PROD_TOPOLOGY_ALT]) THEN
    DISCH_THEN(MP_TAC o SPECL [`(g:A->B) x`; `(h:A->C) x`]) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:B->bool`; `v:C->bool`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(CONJUNCTS_THEN2
     (MP_TAC o SPEC `u:B->bool`) (MP_TAC o SPEC `v:C->bool`)) THEN
    ASM_REWRITE_TAC[IMP_IMP] THEN MATCH_MP_TAC(MESON[OPEN_IN_INTER]
     `P(s INTER t)
      ==> open_in top s /\ open_in top t ==> ?u. open_in top u /\ P u`) THEN
    ASM_REWRITE_TAC[IN_INTER; IN_ELIM_THM] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[SUBSET; FORALL_PAIR_THM; IN_CROSS]) THEN
    ASM SET_TAC[]]);;

let CONTINUOUS_MAP_PAIRED = prove
 (`!top top1 top2 (f:A->B) (g:A->C).
        continuous_map (top,prod_topology top1 top2) (\x. f x,g x) <=>
        continuous_map(top,top1) f /\ continuous_map(top,top2) g`,
  REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let CONTINUOUS_MAP_FST,CONTINUOUS_MAP_SND = (CONJ_PAIR o prove)
 (`(!top1:A topology top2:B topology.
        continuous_map (prod_topology top1 top2,top1) FST) /\
   (!top1:A topology top2:B topology.
        continuous_map (prod_topology top1 top2,top2) SND)`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  MP_TAC(ISPECL [`prod_topology top1 top2 :(A#B)topology`;
                 `top1:A topology`; `top2:B topology`; `\x:A#B. x`]
        CONTINUOUS_MAP_PAIRWISE) THEN
  SIMP_TAC[CONTINUOUS_MAP_ID; o_DEF; ETA_AX]);;

let CONTINUOUS_MAP_FST_OF = prove
 (`!top top1 top2 f:A->B#C.
         continuous_map (top,prod_topology top1 top2) f
         ==> continuous_map (top,top1) (\x. FST(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE; CONTINUOUS_MAP_FST]);;

let CONTINUOUS_MAP_SND_OF = prove
 (`!top top1 top2 f:A->B#C.
         continuous_map (top,prod_topology top1 top2) f
         ==> continuous_map (top,top2) (\x. SND(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE; CONTINUOUS_MAP_SND]);;

let QUOTIENT_MAP_FST = prove
 (`!top:A topology top':B topology.
        quotient_map(prod_topology top top',top) FST <=>
        (topspace top' = {} ==> topspace top = {})`,
  SIMP_TAC[CONTINUOUS_OPEN_QUOTIENT_MAP; OPEN_MAP_FST; CONTINUOUS_MAP_FST] THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; IMAGE_FST_CROSS] THEN
  REPEAT STRIP_TAC THEN COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[EQ_SYM_EQ]);;

let QUOTIENT_MAP_SND = prove
 (`!top:A topology top':B topology.
        quotient_map(prod_topology top top',top') SND <=>
        (topspace top = {} ==> topspace top' = {})`,
  SIMP_TAC[CONTINUOUS_OPEN_QUOTIENT_MAP; OPEN_MAP_SND; CONTINUOUS_MAP_SND] THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; IMAGE_SND_CROSS] THEN
  REPEAT STRIP_TAC THEN COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[EQ_SYM_EQ]);;

let CONTINUOUS_MAP_OF_FST = prove
 (`!top:C topology top1:A topology top2:B topology f.
        continuous_map (prod_topology top1 top2,top) (\x. f(FST x)) <=>
        topspace top2 = {} \/ continuous_map (top1,top) f`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `topspace top2:B->bool = {}` THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_ON_EMPTY;
               TOPSPACE_PROD_TOPOLOGY; CROSS_EMPTY] THEN
  REWRITE_TAC[GSYM o_DEF] THEN
  MATCH_MP_TAC CONTINUOUS_COMPOSE_QUOTIENT_MAP_EQ THEN
  ASM_REWRITE_TAC[QUOTIENT_MAP_FST]);;

let CONTINUOUS_MAP_OF_SND = prove
 (`!top:C topology top1:A topology top2:B topology f.
        continuous_map (prod_topology top1 top2,top) (\x. f(SND x)) <=>
        topspace top1 = {} \/ continuous_map (top2,top) f`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `topspace top1:A->bool = {}` THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_ON_EMPTY;
               TOPSPACE_PROD_TOPOLOGY; CROSS_EMPTY] THEN
  REWRITE_TAC[GSYM o_DEF] THEN
  MATCH_MP_TAC CONTINUOUS_COMPOSE_QUOTIENT_MAP_EQ THEN
  ASM_REWRITE_TAC[QUOTIENT_MAP_SND]);;

let CONTINUOUS_MAP_PROD = prove
 (`!top1 top2 top3 top4 (f:A->B) (g:C->D).
        continuous_map (prod_topology top1 top2,prod_topology top3 top4)
                       (\(x,y). f x,g y) <=>
        topspace(prod_topology top1 top2) = {} \/
        continuous_map (top1,top3) f /\ continuous_map (top2,top4) g`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#C->bool = {}` THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_ON_EMPTY] THEN
  REWRITE_TAC[LAMBDA_PAIR] THEN
  REWRITE_TAC[CONTINUOUS_MAP_PAIRED] THEN
  REWRITE_TAC[CONTINUOUS_MAP_OF_FST; CONTINUOUS_MAP_OF_SND] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PROD_TOPOLOGY; CROSS_EQ_EMPTY]) THEN
  ASM_MESON_TAC[]);;

let HOMEOMORPHIC_MAPS_PROD = prove
 (`!top1 top2 top3 top4 (f:A->B) (g:C->D) f' g'.
        homeomorphic_maps (prod_topology top1 top2,prod_topology top3 top4)
                          ((\(x,y). f x,g y),(\(x,y). f' x,g' y)) <=>
        topspace(prod_topology top1 top2) = {} /\
        topspace(prod_topology top3 top4) = {} \/
        homeomorphic_maps (top1,top3) (f,f') /\
        homeomorphic_maps (top2,top4) (g,g')`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_maps; CONTINUOUS_MAP_PROD] THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; FORALL_PAIR_THM; IN_CROSS] THEN
  REWRITE_TAC[CROSS_EQ_EMPTY; PAIR_EQ] THEN
  REWRITE_TAC[continuous_map] THEN SET_TAC[]);;

let EMBEDDING_MAP_GRAPH = prove
 (`!top top' (f:A->B).
        embedding_map(top,prod_topology top top') (\x. x,f x) <=>
        continuous_map (top,top') f`,
  REPEAT GEN_TAC THEN REWRITE_TAC[embedding_map] THEN EQ_TAC THENL
   [DISCH_THEN(MP_TAC o MATCH_MP HOMEOMORPHIC_IMP_CONTINUOUS_MAP) THEN
    REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET_REFL] THEN
    DISCH_TAC THEN SUBGOAL_THEN `(f:A->B) = SND o (\x. x,f x)` SUBST1_TAC THENL
     [REWRITE_TAC[o_DEF; ETA_AX];
      ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE; CONTINUOUS_MAP_SND]];
    DISCH_TAC THEN REWRITE_TAC[HOMEOMORPHIC_MAP_MAPS] THEN
    EXISTS_TAC `FST:A#B->A` THEN
    ASM_REWRITE_TAC[homeomorphic_maps; CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_PAIRED; SUBSET_REFL; CONTINUOUS_MAP_ID] THEN
    SIMP_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY; CONTINUOUS_MAP_FST] THEN
    REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER; IMP_CONJ_ALT] THEN
    REWRITE_TAC[FORALL_IN_IMAGE]]);;

let IN_PROD_TOPOLOGY_CLOSURE_OF = prove
 (`!top1 top2 s z:A#B.
        z IN (prod_topology top1 top2) closure_of s
        ==> FST z IN top1 closure_of (IMAGE FST s) /\
            SND z IN top2 closure_of (IMAGE SND s)`,
  REPEAT STRIP_TAC THENL
   [MATCH_MP_TAC(REWRITE_RULE
    [SUBSET; FORALL_IN_IMAGE; CONTINUOUS_MAP_EQ_IMAGE_CLOSURE_SUBSET]
    CONTINUOUS_MAP_FST);
   MATCH_MP_TAC(REWRITE_RULE
    [SUBSET; FORALL_IN_IMAGE; CONTINUOUS_MAP_EQ_IMAGE_CLOSURE_SUBSET]
    CONTINUOUS_MAP_SND)] THEN
  ASM_MESON_TAC[]);;

let IN_PRODUCT_TOPOLOGY_CLOSURE_OF = prove
 (`!(tops:K->A topology) s k z.
        z IN (product_topology k tops) closure_of s
        ==> !i. i IN k ==> z i IN ((tops i) closure_of (IMAGE (\x. x i) s))`,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM(MATCH_MP_TAC o REWRITE_RULE
   [SUBSET; FORALL_IN_IMAGE; CONTINUOUS_MAP_EQ_IMAGE_CLOSURE_SUBSET] o
   MATCH_MP CONTINUOUS_MAP_PRODUCT_PROJECTION) THEN
  ASM_REWRITE_TAC[]);;

let HOMEOMORPHIC_SPACE_SINGLETON_PRODUCT = prove
 (`!(tops:K->A topology) k.
        product_topology {k} tops homeomorphic_space (tops k)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[HOMEOMORPHIC_SPACE] THEN
  EXISTS_TAC `\x:K->A. x k` THEN
  MATCH_MP_TAC BIJECTIVE_OPEN_IMP_HOMEOMORPHIC_MAP THEN
  SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION; IN_SING;
           OPEN_MAP_PRODUCT_PROJECTION] THEN
  REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; IMAGE_PROJECTION_CARTESIAN_PRODUCT;
              CARTESIAN_PRODUCT_EQ_EMPTY; IN_SING; UNWIND_THM2; o_THM] THEN
  CONJ_TAC THENL [MESON_TAC[]; REPEAT GEN_TAC] THEN
  DISCH_THEN(SUBST1_TAC o MATCH_MP CARTESIAN_PRODUCT_EQ_MEMBERS_EQ) THEN
  SET_TAC[]);;

let HOMEOMORPHIC_SPACE_PROD_TOPOLOGY = prove
 (`!(top1:A topology) (top1':B topology) (top2:C topology) (top2':D topology).
        top1 homeomorphic_space top1' /\ top2 homeomorphic_space top2'
        ==> prod_topology top1 top2 homeomorphic_space
            prod_topology top1' top2'`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homeomorphic_space; LEFT_AND_EXISTS_THM] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; RIGHT_AND_EXISTS_THM] THEN
  REPEAT GEN_TAC THEN DISCH_THEN(MP_TAC o MATCH_MP (MATCH_MP (TAUT
   `(p <=> q \/ r) ==> (r ==> p)`) (SPEC_ALL HOMEOMORPHIC_MAPS_PROD))) THEN
  MESON_TAC[]);;

let PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_LEFT = prove
 (`!(top:A topology) (top':B topology) b.
        topspace top' = {b} ==> prod_topology top top' homeomorphic_space top`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  EXISTS_TAC `FST:A#B->A` THEN
  REWRITE_TAC[GSYM HOMEOMORPHIC_MAP_MAPS; homeomorphic_map] THEN
  ASM_REWRITE_TAC[QUOTIENT_MAP_FST; NOT_INSERT_EMPTY] THEN
  REWRITE_TAC[FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_CROSS; PAIR_EQ] THEN
  ASM_SIMP_TAC[IN_SING]);;

let PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_RIGHT = prove
 (`!(top:A topology) (top':B topology) a.
        topspace top = {a} ==> prod_topology top top' homeomorphic_space top'`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[homeomorphic_space] THEN
  EXISTS_TAC `SND:A#B->B` THEN
  REWRITE_TAC[GSYM HOMEOMORPHIC_MAP_MAPS; homeomorphic_map] THEN
  ASM_REWRITE_TAC[QUOTIENT_MAP_SND; NOT_INSERT_EMPTY] THEN
  REWRITE_TAC[FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_CROSS; PAIR_EQ] THEN
  ASM_SIMP_TAC[IN_SING]);;

let HOMEOMORPHIC_SPACE_PROD_TOPOLOGY_SING = prove
 (`(!top:A topology top':B topology b.
      b IN topspace top'
      ==> top homeomorphic_space (prod_topology top (subtopology top' {b}))) /\
   (!top:A topology top':B topology a.
      a IN topspace top
      ==> top' homeomorphic_space (prod_topology (subtopology top {a}) top'))`,
  REPEAT STRIP_TAC THEN ONCE_REWRITE_TAC[HOMEOMORPHIC_SPACE_SYM] THENL
   [MATCH_MP_TAC PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_LEFT;
    MATCH_MP_TAC PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_RIGHT] THEN
  ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; SET_RULE
   `a IN s ==> s INTER {a} = {a}`] THEN
  ASM_MESON_TAC[]);;

let TOPOLOGICAL_PROPERTY_OF_PROD_COMPONENT = prove
 (`!P Q R (top1:A topology) (top2:B topology).
        (!a. a IN topspace top1 /\ P(prod_topology top1 top2)
             ==> P(subtopology (prod_topology top1 top2)
                               ({a} CROSS topspace top2))) /\
        (!b. b IN topspace top2 /\ P(prod_topology top1 top2)
             ==> P(subtopology (prod_topology top1 top2)
                               (topspace top1 CROSS {b}))) /\
        (!top top'. top homeomorphic_space top' ==> (P top <=> Q top')) /\
        (!top top'. top homeomorphic_space top' ==> (P top <=> R top'))
        ==> P(prod_topology top1 top2)
            ==> topspace(prod_topology top1 top2) = {} \/
                Q top1 /\ R top2`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[TAUT `p \/ q <=> ~p ==> q`] THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`a:A`; `b:B`] THEN REPEAT STRIP_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o SPEC `b:B`);
    FIRST_X_ASSUM(MP_TAC o SPEC `a:A`)] THEN
  ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC EQ_IMP THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
  REWRITE_TAC[SUBTOPOLOGY_CROSS; SUBTOPOLOGY_TOPSPACE] THEN
  ONCE_REWRITE_TAC[HOMEOMORPHIC_SPACE_SYM] THEN
  ASM_SIMP_TAC[HOMEOMORPHIC_SPACE_PROD_TOPOLOGY_SING]);;

let INTERIOR_OF_CROSS = prove
 (`!top1:A topology top2:B topology s t.
        (prod_topology top1 top2) interior_of (s CROSS t) =
        (top1 interior_of s) CROSS (top2 interior_of t)`,
  REPEAT GEN_TAC THEN MATCH_MP_TAC INTERIOR_OF_UNIQUE THEN
  REWRITE_TAC[SUBSET_CROSS; INTERIOR_OF_SUBSET] THEN
  REWRITE_TAC[OPEN_IN_CROSS; OPEN_IN_INTERIOR_OF] THEN
  X_GEN_TAC `w:A#B->bool` THEN STRIP_TAC THEN
  REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_PROD_TOPOLOGY_ALT]) THEN
  DISCH_THEN(MP_TAC o SPECL [`x:A`; `y:B`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:B->bool`] THEN STRIP_TAC THEN
  SUBGOAL_THEN `((u CROSS v):A#B->bool) SUBSET s CROSS t` MP_TAC THENL
   [ASM SET_TAC[]; REWRITE_TAC[SUBSET_CROSS]] THEN
  ASM_CASES_TAC `u:A->bool = {}` THENL [ASM SET_TAC[]; ALL_TAC] THEN
  ASM_CASES_TAC `v:B->bool = {}` THENL [ASM SET_TAC[]; ALL_TAC] THEN
  ASM_REWRITE_TAC[interior_of; IN_ELIM_THM] THEN ASM_MESON_TAC[]);;

let T1_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        t1_space(prod_topology top1 top2) <=>
        topspace(prod_topology top1 top2) = {} \/
        t1_space top1 /\ t1_space top2`,
  REWRITE_TAC[T1_SPACE_CLOSED_IN_SING; FORALL_PAIR_THM] THEN
  REWRITE_TAC[GSYM CROSS_SING; CLOSED_IN_CROSS; NOT_INSERT_EMPTY] THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; CROSS_EQ_EMPTY; IN_CROSS] THEN
  SET_TAC[]);;

let HAUSDORFF_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        hausdorff_space(prod_topology top1 top2) <=>
        topspace(prod_topology top1 top2) = {} \/
        hausdorff_space top1 /\ hausdorff_space top2`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MATCH_MP_TAC TOPOLOGICAL_PROPERTY_OF_PROD_COMPONENT THEN
    REWRITE_TAC[HOMEOMORPHIC_HAUSDORFF_SPACE] THEN
    SIMP_TAC[HAUSDORFF_SPACE_SUBTOPOLOGY];
    ALL_TAC] THEN
  ASM_CASES_TAC `(topspace top1 CROSS topspace top2):A#B->bool = {}` THEN
  ASM_REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY] THENL
   [ASM_REWRITE_TAC[hausdorff_space; TOPSPACE_PROD_TOPOLOGY; NOT_IN_EMPTY];
    FIRST_X_ASSUM(MP_TAC o REWRITE_RULE[CROSS_EQ_EMPTY]) THEN
    REWRITE_TAC[DE_MORGAN_THM] THEN STRIP_TAC] THEN
  STRIP_TAC THEN REWRITE_TAC[hausdorff_space; TOPSPACE_PROD_TOPOLOGY] THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS; PAIR_EQ] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:B`; `x':A`; `y':B`] THEN
  ASM_CASES_TAC `y':B = y` THEN ASM_REWRITE_TAC[] THEN STRIP_TAC THENL
   [UNDISCH_TAC `hausdorff_space(top1:A topology)`;
    UNDISCH_TAC `hausdorff_space(top2:B topology)`] THEN
  REWRITE_TAC[hausdorff_space] THENL
   [DISCH_THEN(MP_TAC o SPECL [`x:A`; `x':A`]) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:A->bool`] THEN STRIP_TAC THEN
    EXISTS_TAC `(u CROSS topspace top2):A#B->bool` THEN
    EXISTS_TAC `(v CROSS topspace top2):A#B->bool`;
    DISCH_THEN(MP_TAC o SPECL [`y:B`; `y':B`]) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:B->bool`; `v:B->bool`] THEN STRIP_TAC THEN
    EXISTS_TAC `(topspace top1 CROSS u):A#B->bool` THEN
    EXISTS_TAC `(topspace top1 CROSS v):A#B->bool`] THEN
  ASM_REWRITE_TAC[OPEN_IN_CROSS; OPEN_IN_TOPSPACE; IN_CROSS] THEN
  ASM_REWRITE_TAC[DISJOINT_CROSS]);;

let REGULAR_SPACE_PROD_TOPOLOGY = prove
 (`!(top1:A topology) (top2:B topology).
        regular_space (prod_topology top1 top2) <=>
        topspace (prod_topology top1 top2) = {} \/
        regular_space top1 /\ regular_space top2`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MATCH_MP_TAC TOPOLOGICAL_PROPERTY_OF_PROD_COMPONENT THEN
    REWRITE_TAC[HOMEOMORPHIC_REGULAR_SPACE] THEN
    SIMP_TAC[REGULAR_SPACE_SUBTOPOLOGY];
    ALL_TAC] THEN
  ASM_CASES_TAC `(topspace top1 CROSS topspace top2):A#B->bool = {}` THEN
  ASM_REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY] THENL
   [ASM_REWRITE_TAC[regular_space; TOPSPACE_PROD_TOPOLOGY; IN_DIFF;
                    NOT_IN_EMPTY];
    FIRST_X_ASSUM(MP_TAC o REWRITE_RULE[CROSS_EQ_EMPTY]) THEN
    REWRITE_TAC[DE_MORGAN_THM] THEN STRIP_TAC] THEN
  REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN
  REWRITE_TAC[NEIGHBOURHOOD_BASE_OF; FORALL_PAIR_THM] THEN STRIP_TAC THEN
  MAP_EVERY X_GEN_TAC [`w:A#B->bool`; `x:A`; `y:B`] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_PROD_TOPOLOGY_ALT]) THEN
  DISCH_THEN(MP_TAC o SPECL [`x:A`; `y:B`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:B->bool`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`v:B->bool`; `y:B`]) THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`u:A->bool`; `x:A`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`d1:A->bool`; `c1:A->bool`] THEN STRIP_TAC THEN
  MAP_EVERY X_GEN_TAC [`d2:B->bool`; `c2:B->bool`] THEN STRIP_TAC THEN
  EXISTS_TAC `(d1:A->bool) CROSS (d2:B->bool)` THEN
  EXISTS_TAC `(c1:A->bool) CROSS (c2:B->bool)` THEN
  ASM_SIMP_TAC[SUBSET_CROSS; OPEN_IN_CROSS; CLOSED_IN_CROSS; IN_CROSS] THEN
  FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
      SUBSET_TRANS)) THEN
  ASM_REWRITE_TAC[SUBSET_CROSS]);;

let COMPACT_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        compact_space(prod_topology top1 top2) <=>
        topspace(prod_topology top1 top2) = {} \/
        compact_space top1 /\ compact_space top2`,
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#B->bool = {}` THEN
  ASM_SIMP_TAC[COMPACT_SPACE_TOPSPACE_EMPTY] THEN EQ_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PROD_TOPOLOGY;
        CROSS_EQ_EMPTY; DE_MORGAN_THM]) THEN
    REWRITE_TAC[compact_space] THEN REPEAT STRIP_TAC THENL
     [MP_TAC(ISPECL [`prod_topology top1 top2:(A#B)topology`;
                     `top1:A topology`; `FST:A#B->A`;
                     `topspace(prod_topology top1 top2:(A#B)topology)`]
        IMAGE_COMPACT_IN);
      MP_TAC(ISPECL [`prod_topology top1 top2:(A#B)topology`;
                     `top2:B topology`; `SND:A#B->B`;
                     `topspace(prod_topology top1 top2:(A#B)topology)`]
        IMAGE_COMPACT_IN)] THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_FST; CONTINUOUS_MAP_SND] THEN
    REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY] THEN
    ASM_REWRITE_TAC[IMAGE_FST_CROSS; IMAGE_SND_CROSS];
    STRIP_TAC THEN MATCH_MP_TAC ALEXANDER_SUBBASE_THEOREM_ALT THEN
    EXISTS_TAC
     `{(topspace top1 CROSS v):A#B->bool | open_in top2 v} UNION
      {u CROSS topspace top2 | open_in top1 u}` THEN
    EXISTS_TAC `(topspace top1 CROSS topspace top2):A#B->bool` THEN
    REPEAT CONJ_TAC THENL
     [MATCH_MP_TAC(SET_RULE
      `(?s. s IN f /\ x SUBSET s) ==> x SUBSET UNIONS f`) THEN
      REWRITE_TAC[EXISTS_IN_UNION; EXISTS_IN_GSPEC] THEN DISJ2_TAC THEN
      EXISTS_TAC `topspace top1:A->bool` THEN
      REWRITE_TAC[OPEN_IN_TOPSPACE; SUBSET_REFL];
      GEN_REWRITE_TAC RAND_CONV [prod_topology] THEN
      AP_TERM_TAC THEN AP_TERM_TAC THEN
      MATCH_MP_TAC SUBSET_ANTISYM THEN CONJ_TAC THENL
       [REWRITE_TAC[SET_RULE `s SUBSET t <=> !x. s x ==> x IN t`] THEN
        REWRITE_TAC[FORALL_RELATIVE_TO; FORALL_INTERSECTION_OF] THEN
        REWRITE_TAC[IMP_CONJ] THEN MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
        CONJ_TAC THENL
         [REWRITE_TAC[NOT_IN_EMPTY; INTERS_0; INTER_UNIV; IN_ELIM_THM] THEN
          ASM_MESON_TAC[OPEN_IN_TOPSPACE];
          MAP_EVERY X_GEN_TAC [`c:A#B->bool`; `t:(A#B->bool)->bool`] THEN
          REWRITE_TAC[FORALL_IN_INSERT] THEN DISCH_THEN(fun th ->
            DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN MP_TAC th) THEN
          ASM_REWRITE_TAC[] THEN
          REWRITE_TAC[IN_ELIM_THM; UNION] THEN REPEAT STRIP_TAC THEN
          REWRITE_TAC[INTERS_INSERT] THEN ONCE_REWRITE_TAC[SET_RULE
           `s INTER t INTER u = (s INTER u) INTER t`] THEN
          ASM_REWRITE_TAC[INTER_CROSS] THEN
          ASM_MESON_TAC[OPEN_IN_INTER; OPEN_IN_TOPSPACE]];
        REWRITE_TAC[SET_RULE `s SUBSET t <=> !x. x IN s ==> t x`] THEN
        REWRITE_TAC[FORALL_IN_GSPEC] THEN
        MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:B->bool`] THEN STRIP_TAC THEN
        SUBGOAL_THEN
         `(u CROSS v):A#B->bool =
          (topspace top1 CROSS topspace top2) INTER (u CROSS v)`
        SUBST1_TAC THENL
         [REWRITE_TAC[SET_RULE `s = u INTER s <=> s SUBSET u`] THEN
          ASM_SIMP_TAC[SUBSET_CROSS; OPEN_IN_SUBSET];
          MATCH_MP_TAC RELATIVE_TO_INC] THEN
        REWRITE_TAC[INTERSECTION_OF] THEN EXISTS_TAC
         `{(u CROSS topspace top2),(topspace top1 CROSS v)}
          :(A#B->bool)->bool` THEN
        REWRITE_TAC[FINITE_INSERT; FINITE_EMPTY; INTERS_2] THEN
        REWRITE_TAC[FORALL_IN_INSERT; NOT_IN_EMPTY] THEN CONJ_TAC THENL
         [REWRITE_TAC[UNION; IN_ELIM_THM] THEN ASM_MESON_TAC[];
          REWRITE_TAC[INTER_CROSS; CROSS_EQ] THEN
          REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
          SET_TAC[]]];
        REWRITE_TAC[FORALL_SUBSET_UNION; IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
        ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN
        REWRITE_TAC[FORALL_SUBSET_IMAGE; UNIONS_UNION] THEN
        REWRITE_TAC[SUBSET; UNIONS_IMAGE; IN_UNION; IN_ELIM_THM] THEN
        X_GEN_TAC `v:(B->bool)->bool` THEN DISCH_TAC THEN
        X_GEN_TAC `u:(A->bool)->bool` THEN DISCH_TAC THEN
        SIMP_TAC[FORALL_PAIR_THM; IN_CROSS] THEN DISCH_TAC THEN
        FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE (RAND_CONV o LAND_CONV)
         [TOPSPACE_PROD_TOPOLOGY]) THEN
        REWRITE_TAC[CROSS_EQ_EMPTY; DE_MORGAN_THM] THEN STRIP_TAC THEN
        SUBGOAL_THEN
         `topspace top1 SUBSET (UNIONS u:A->bool) \/
          topspace top2 SUBSET (UNIONS v:B->bool)`
        STRIP_ASSUME_TAC THENL
         [REWRITE_TAC[SUBSET; IN_UNIONS] THEN ASM SET_TAC[];
          UNDISCH_TAC `compact_space(top1:A topology)`;
          UNDISCH_TAC `compact_space(top2:B topology)`] THEN
        REWRITE_TAC[compact_in; compact_space; SUBSET_REFL] THENL
         [DISCH_THEN(MP_TAC o SPEC `u:(A->bool)->bool`);
          DISCH_THEN(MP_TAC o SPEC `v:(B->bool)->bool`)] THEN
        ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THENL
         [X_GEN_TAC `u':(A->bool)->bool` THEN STRIP_TAC THEN EXISTS_TAC
          `IMAGE (\c. (c:A->bool) CROSS topspace(top2:B topology)) u'`;
          X_GEN_TAC `v':(B->bool)->bool` THEN STRIP_TAC THEN EXISTS_TAC
          `IMAGE (\c. topspace(top1:A topology) CROSS (c:B->bool)) v'`] THEN
        ASM_SIMP_TAC[FINITE_IMAGE] THEN
        (CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC]) THEN
        MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN STRIP_TAC THEN
        ASM_REWRITE_TAC[UNIONS_IMAGE; IN_ELIM_THM; IN_CROSS] THEN
        ASM SET_TAC[]]]);;

let COMPACT_IN_CROSS = prove
 (`!top1 top2 s:A->bool t:B->bool.
        compact_in (prod_topology top1 top2) (s CROSS t) <=>
        s = {} \/ t = {} \/ compact_in top1 s /\ compact_in top2 t`,
  REPEAT GEN_TAC THEN REWRITE_TAC[COMPACT_IN_SUBSPACE; SUBTOPOLOGY_CROSS] THEN
  REWRITE_TAC[COMPACT_SPACE_PROD_TOPOLOGY; TOPSPACE_PROD_TOPOLOGY] THEN
  REWRITE_TAC[SUBSET_CROSS; CROSS_EQ_EMPTY; TOPSPACE_SUBTOPOLOGY] THEN
  ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[INTER_EMPTY] THEN
  ASM_CASES_TAC `t:B->bool = {}` THEN ASM_REWRITE_TAC[INTER_EMPTY] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top1` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `(t:B->bool) SUBSET topspace top2` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u ==> u INTER s = s`]);;

let CONNECTED_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        connected_space(prod_topology top1 top2) <=>
        topspace(prod_topology top1 top2) = {} \/
        connected_space top1 /\ connected_space top2`,
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#B->bool = {}` THEN
  ASM_SIMP_TAC[CONNECTED_SPACE_TOPSPACE_EMPTY] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PROD_TOPOLOGY;
        CROSS_EQ_EMPTY; DE_MORGAN_THM]) THEN
  EQ_TAC THENL
   [REWRITE_TAC[GSYM CONNECTED_IN_TOPSPACE] THEN REPEAT STRIP_TAC THENL
     [MP_TAC(ISPECL [`FST:A#B->A`; `prod_topology top1 top2:(A#B)topology`;
                     `top1:A topology`;
                     `topspace(prod_topology top1 top2:(A#B)topology)`]
        CONNECTED_IN_CONTINUOUS_MAP_IMAGE);
      MP_TAC(ISPECL [`SND:A#B->B`; `prod_topology top1 top2:(A#B)topology`;
                     `top2:B topology`;
                     `topspace(prod_topology top1 top2:(A#B)topology)`]
        CONNECTED_IN_CONTINUOUS_MAP_IMAGE)] THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_FST; CONTINUOUS_MAP_SND] THEN
    REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY] THEN
    ASM_REWRITE_TAC[IMAGE_FST_CROSS; IMAGE_SND_CROSS];
    REWRITE_TAC[connected_space; NOT_EXISTS_THM] THEN STRIP_TAC] THEN
  MAP_EVERY X_GEN_TAC [`u:A#B->bool`; `v:A#B->bool`] THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY] THEN STRIP_TAC THEN
  SUBGOAL_THEN
   `(u:A#B->bool) SUBSET (topspace top1) CROSS (topspace top2) /\
    v SUBSET (topspace top1) CROSS (topspace top2)`
  STRIP_ASSUME_TAC THENL
   [ASM_MESON_TAC[OPEN_IN_SUBSET; TOPSPACE_PROD_TOPOLOGY]; ALL_TAC] THEN
  UNDISCH_TAC `~(u:A#B->bool = {})` THEN
  REWRITE_TAC[EXTENSION; FORALL_PAIR_THM; NOT_IN_EMPTY] THEN
  MAP_EVERY X_GEN_TAC [`a:A`; `b:B`] THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP (SET_RULE
   `s SUBSET u UNION v
    ==> u SUBSET s /\ v SUBSET s /\ u INTER v = {} /\ ~(v = {})
       ==> ~(s SUBSET u)`)) THEN
  ASM_REWRITE_TAC[NOT_IMP] THEN
  SUBGOAL_THEN `(a:A,b:B) IN topspace top1 CROSS topspace top2` MP_TAC THENL
   [ASM SET_TAC[]; REWRITE_TAC[IN_CROSS] THEN STRIP_TAC] THEN
  REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN STRIP_TAC THEN
  SUBGOAL_THEN `((a:A),(y:B)) IN u` ASSUME_TAC THENL
   [FIRST_X_ASSUM(MP_TAC o SPECL
     [`{y | y IN topspace top2 /\ (a:A,y:B) IN u}`;
      `{y | y IN topspace top2 /\ (a:A,y:B) IN v}`]);
    FIRST_X_ASSUM(MP_TAC o SPECL
     [`{x | x IN topspace top1 /\ (x:A,y:B) IN u}`;
      `{x | x IN topspace top1 /\ (x:A,y:B) IN v}`])] THEN
  (MATCH_MP_TAC(TAUT
    `(s /\ t) /\ (p /\ q) /\ r /\ (~u ==> v)
     ==> ~(p /\ q /\ r /\ s /\ t /\ u) ==> v`) THEN
   CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN CONJ_TAC THENL
    [CONJ_TAC THEN MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
     EXISTS_TAC `prod_topology top1 top2 :(A#B)topology` THEN
     ASM_REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF] THEN
     ASM_REWRITE_TAC[CONTINUOUS_MAP_ID; CONTINUOUS_MAP_CONST];
     ALL_TAC] THEN
   CONJ_TAC THENL
    [SIMP_TAC[SUBSET; IN_ELIM_THM; IN_UNION] THEN FIRST_X_ASSUM(MATCH_MP_TAC o
       MATCH_MP (SET_RULE
         `s SUBSET u UNION v ==> IMAGE f q SUBSET s
        ==> (!x. x IN q ==> f x IN u \/ f x IN v)`)) THEN
     ASM_REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IN_CROSS];
     REWRITE_TAC[]])
  THENL
   [MATCH_MP_TAC(SET_RULE
     `P y /\ (a,y) IN u UNION v
      ==> {y | P y /\ (a,y) IN v} = {} ==> (a,y) IN u`);
    MATCH_MP_TAC(SET_RULE
     `P x /\ (x,y) IN u UNION v
      ==> {x | P x /\ (x,y) IN v} = {} ==> (x,y) IN u`)] THEN
  ASM_REWRITE_TAC[] THEN
  FIRST_ASSUM(MATCH_MP_TAC o GEN_REWRITE_RULE I [SUBSET]) THEN
  ASM_REWRITE_TAC[IN_CROSS]);;

let CONNECTED_IN_CROSS = prove
 (`!top1 top2 s:A->bool t:B->bool.
        connected_in (prod_topology top1 top2) (s CROSS t) <=>
        s = {} \/ t = {} \/ connected_in top1 s /\ connected_in top2 t`,
  REPEAT GEN_TAC THEN REWRITE_TAC[connected_in; SUBTOPOLOGY_CROSS] THEN
  REWRITE_TAC[CONNECTED_SPACE_PROD_TOPOLOGY; TOPSPACE_PROD_TOPOLOGY] THEN
  REWRITE_TAC[SUBSET_CROSS; CROSS_EQ_EMPTY; TOPSPACE_SUBTOPOLOGY] THEN
  ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[INTER_EMPTY] THEN
  ASM_CASES_TAC `t:B->bool = {}` THEN ASM_REWRITE_TAC[INTER_EMPTY] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top1` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `(t:B->bool) SUBSET topspace top2` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u ==> u INTER s = s`]);;

let PATH_CONNECTED_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        path_connected_space(prod_topology top1 top2) <=>
        topspace(prod_topology top1 top2) = {} \/
        path_connected_space top1 /\ path_connected_space top2`,
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#B->bool = {}` THEN
  ASM_SIMP_TAC[PATH_CONNECTED_SPACE_TOPSPACE_EMPTY] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[TOPSPACE_PROD_TOPOLOGY;
        CROSS_EQ_EMPTY; DE_MORGAN_THM]) THEN
  EQ_TAC THENL
   [REWRITE_TAC[GSYM PATH_CONNECTED_IN_TOPSPACE] THEN REPEAT STRIP_TAC THENL
     [MP_TAC(ISPECL [`FST:A#B->A`; `prod_topology top1 top2:(A#B)topology`;
                     `top1:A topology`;
                     `topspace(prod_topology top1 top2:(A#B)topology)`]
        PATH_CONNECTED_IN_CONTINUOUS_MAP_IMAGE);
      MP_TAC(ISPECL [`SND:A#B->B`; `prod_topology top1 top2:(A#B)topology`;
                     `top2:B topology`;
                     `topspace(prod_topology top1 top2:(A#B)topology)`]
        PATH_CONNECTED_IN_CONTINUOUS_MAP_IMAGE)] THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_FST; CONTINUOUS_MAP_SND] THEN
    REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY] THEN
    ASM_REWRITE_TAC[IMAGE_FST_CROSS; IMAGE_SND_CROSS];
    REWRITE_TAC[path_connected_space; NOT_EXISTS_THM] THEN STRIP_TAC] THEN
  REWRITE_TAC[FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`x1:A`; `x2:B`; `y1:A`; `y2:B`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`x2:B`; `y2:B`]) THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`x1:A`; `y1:A`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `g1:real->A` THEN STRIP_TAC THEN
  X_GEN_TAC `g2:real->B` THEN STRIP_TAC THEN
  EXISTS_TAC `(\t. g1 t,g2 t):real->A#B` THEN
  ASM_REWRITE_TAC[path_in; CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX] THEN
  ASM_REWRITE_TAC[GSYM path_in]);;

let PATH_CONNECTED_IN_CROSS = prove
 (`!top1 top2 s:A->bool t:B->bool.
        path_connected_in (prod_topology top1 top2) (s CROSS t) <=>
        s = {} \/ t = {} \/
        path_connected_in top1 s /\ path_connected_in top2 t`,
  REPEAT GEN_TAC THEN REWRITE_TAC[path_connected_in; SUBTOPOLOGY_CROSS] THEN
  REWRITE_TAC[PATH_CONNECTED_SPACE_PROD_TOPOLOGY; TOPSPACE_PROD_TOPOLOGY] THEN
  REWRITE_TAC[SUBSET_CROSS; CROSS_EQ_EMPTY; TOPSPACE_SUBTOPOLOGY] THEN
  ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[INTER_EMPTY] THEN
  ASM_CASES_TAC `t:B->bool = {}` THEN ASM_REWRITE_TAC[INTER_EMPTY] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET topspace top1` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `(t:B->bool) SUBSET topspace top2` THEN ASM_REWRITE_TAC[] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET u ==> u INTER s = s`]);;

let LOCALLY_COMPACT_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        locally_compact_space (prod_topology top1 top2) <=>
        topspace (prod_topology top1 top2) = {} \/
        locally_compact_space top1 /\ locally_compact_space top2`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#B->bool = {}` THENL
   [ASM_REWRITE_TAC[NOT_IN_EMPTY; locally_compact_space]; ALL_TAC] THEN
  ASM_REWRITE_TAC[] THEN RULE_ASSUM_TAC(REWRITE_RULE
   [TOPSPACE_PROD_TOPOLOGY; CROSS_EQ_EMPTY; DE_MORGAN_THM]) THEN
  ASM_REWRITE_TAC[] THEN EQ_TAC THENL
   [DISCH_THEN(fun th -> CONJ_TAC THEN MP_TAC th) THEN
    MATCH_MP_TAC(ONCE_REWRITE_RULE[IMP_CONJ] (REWRITE_RULE[CONJ_ASSOC]
      LOCALLY_COMPACT_SPACE_CONTINUOUS_OPEN_MAP_IMAGE))
    THENL [EXISTS_TAC `FST:A#B->A`; EXISTS_TAC `SND:A#B->B`] THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_FST; OPEN_MAP_FST; TOPSPACE_PROD_TOPOLOGY;
      CONTINUOUS_MAP_SND; OPEN_MAP_SND; IMAGE_FST_CROSS; IMAGE_SND_CROSS];
    FIRST_X_ASSUM(CONJUNCTS_THEN MP_TAC) THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `z:B` THEN DISCH_TAC THEN X_GEN_TAC `w:A` THEN DISCH_TAC THEN
    REWRITE_TAC[locally_compact_space; FORALL_PAIR_THM; IN_CROSS;
                TOPSPACE_PROD_TOPOLOGY] THEN STRIP_TAC THEN
    MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `y:B`) THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u1:A->bool`; `k1:A->bool`] THEN STRIP_TAC THEN
    MAP_EVERY X_GEN_TAC [`u2:B->bool`; `k2:B->bool`] THEN STRIP_TAC THEN
    EXISTS_TAC `(u1:A->bool) CROSS (u2:B->bool)` THEN
    EXISTS_TAC `(k1:A->bool) CROSS (k2:B->bool)` THEN
    ASM_SIMP_TAC[OPEN_IN_CROSS; COMPACT_IN_CROSS; IN_CROSS; SUBSET_CROSS]]);;

let COMPLETELY_REGULAR_SPACE_PROD_TOPOLOGY = prove
 (`!(top1:A topology) (top2:B topology).
        completely_regular_space (prod_topology top1 top2) <=>
        topspace (prod_topology top1 top2) = {} \/
        completely_regular_space top1 /\ completely_regular_space top2`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MATCH_MP_TAC TOPOLOGICAL_PROPERTY_OF_PROD_COMPONENT THEN
    REWRITE_TAC[HOMEOMORPHIC_COMPLETELY_REGULAR_SPACE] THEN
    SIMP_TAC[COMPLETELY_REGULAR_SPACE_SUBTOPOLOGY];
    ALL_TAC] THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#B->bool = {}` THENL
   [ASM_REWRITE_TAC[completely_regular_space; IN_DIFF; NOT_IN_EMPTY];
    ASM_REWRITE_TAC[]] THEN
  REWRITE_TAC[COMPLETELY_REGULAR_SPACE_ALT] THEN
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[FORALL_CLOSED_IN] THEN SIMP_TAC[IN_DIFF; IMP_CONJ] THEN
  GEN_REWRITE_TAC (BINOP_CONV o TOP_DEPTH_CONV) [RIGHT_IMP_FORALL_THM] THEN
  REWRITE_TAC[IMP_IMP; GSYM CONJ_ASSOC] THEN STRIP_TAC THEN
  REWRITE_TAC[FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`w:A#B->bool`; `x:A`; `y:B`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [OPEN_IN_PROD_TOPOLOGY_ALT]) THEN
  DISCH_THEN(MP_TAC o SPECL [`x:A`; `y:B`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `v:B->bool`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`v:B->bool`; `y:B`]) THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`u:A->bool`; `x:A`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM; IN_REAL_INTERVAL] THEN
  X_GEN_TAC `f:A->real` THEN STRIP_TAC THEN
  X_GEN_TAC `g:B->real` THEN STRIP_TAC THEN
  EXISTS_TAC `\(x,y). &1 - (&1 - (f:A->real) x) * (&1 - (g:B->real) y)` THEN
  ASM_REWRITE_TAC[FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_CROSS] THEN
  CONV_TAC REAL_RAT_REDUCE_CONV THEN CONJ_TAC THENL
   [REWRITE_TAC[LAMBDA_PAIR] THEN
    REPEAT((MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB ORELSE
            MATCH_MP_TAC CONTINUOUS_MAP_REAL_MUL) THEN CONJ_TAC) THEN
    REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_OF_FST; CONTINUOUS_MAP_OF_SND];
    REWRITE_TAC[REAL_RING
     `&1 - (&1 - x) * (&1 - y) = &1 <=> x = &1 \/ y = &1`] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[SUBSET; FORALL_PAIR_THM; IN_CROSS]) THEN
    ASM SET_TAC[]]);;

let HAUSDORFF_SPACE_CLOSED_IN_DIAGONAL = prove
 (`!top:A topology.
        hausdorff_space top <=>
        closed_in (prod_topology top top) {(x,x) | x IN topspace top}`,
  GEN_TAC THEN REWRITE_TAC[closed_in] THEN
  REWRITE_TAC[OPEN_IN_PROD_TOPOLOGY_ALT; hausdorff_space] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_GSPEC; TOPSPACE_PROD_TOPOLOGY; IN_CROSS;
    NOT_IN_EMPTY; DISJOINT; EXTENSION; IN_INTER; IN_DIFF; FORALL_PAIR_THM] THEN
  REWRITE_TAC[IN_ELIM_THM; PAIR_EQ; SET_RULE
   `(?z. P z /\ x = z /\ y = z) <=> P x /\ x = y`] THEN
  REWRITE_TAC[TAUT `(p /\ q) /\ ~(p /\ r) <=> p /\ q /\ ~r`] THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN AP_TERM_TAC THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN
  MESON_TAC[REWRITE_RULE[SUBSET] OPEN_IN_SUBSET]);;

let FORALL_IN_CLOSURE_OF_EQ = prove
 (`!top top' f g:A->B.
        hausdorff_space top' /\
        continuous_map (top,top') f /\ continuous_map (top,top') g /\
        (!x. x IN s ==> f x = g x)
        ==> !x. x IN top closure_of s ==> f x = g x`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  MATCH_MP_TAC FORALL_IN_CLOSURE_OF THEN ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN
   `{x | x IN topspace top /\ (f:A->B) x = g x} =
    {x | x IN topspace top /\ (f x,g x) IN {(z,z) | z IN topspace top'}}`
  SUBST1_TAC THENL
   [REWRITE_TAC[EXTENSION; IN_ELIM_THM; PAIR_EQ] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[CONTINUOUS_MAP]) THEN ASM SET_TAC[];
    MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE THEN
    EXISTS_TAC `prod_topology (top':B topology) top'` THEN
    ASM_REWRITE_TAC[GSYM HAUSDORFF_SPACE_CLOSED_IN_DIAGONAL] THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]]);;

(* ------------------------------------------------------------------------- *)
(* Product metric. For the nicest fit with the main Euclidean theories, we   *)
(* make this the Euclidean product, though others would work topologically.  *)
(* ------------------------------------------------------------------------- *)

let prod_metric = new_definition
 `prod_metric m1 m2 =
  metric((mspace m1 CROSS mspace m2):A#B->bool,
         \((x,y),(x',y')).
            sqrt(mdist m1 (x,x') pow 2 + mdist m2 (y,y') pow 2))`;;

let PROD_METRIC = prove
 (`(!(m1:A metric) (m2:B metric).
      mspace(prod_metric m1 m2) = mspace m1 CROSS mspace m2) /\
   (!(m1:A metric) (m2:B metric).
        mdist(prod_metric m1 m2) =
        \((x,y),(x',y')).
            sqrt(mdist m1 (x,x') pow 2 + mdist m2 (y,y') pow 2))`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o LAND_CONV) [mspace] THEN
  GEN_REWRITE_TAC (RAND_CONV o LAND_CONV) [mdist] THEN
  REWRITE_TAC[PAIR; GSYM PAIR_EQ] THEN REWRITE_TAC[prod_metric] THEN
  REWRITE_TAC[GSYM(CONJUNCT2 metric_tybij)] THEN
  REWRITE_TAC[is_metric_space; FORALL_PAIR_THM; IN_CROSS] THEN
  REPEAT CONJ_TAC THENL
   [SIMP_TAC[SQRT_POS_LE; REAL_LE_ADD; REAL_LE_POW_2];
    REWRITE_TAC[PAIR_EQ; SQRT_EQ_0] THEN SIMP_TAC[REAL_LE_POW_2; REAL_ARITH
     `&0 <= x /\ &0 <= y ==> (x + y = &0 <=> x = &0 /\ y = &0)`] THEN
    SIMP_TAC[REAL_POW_EQ_0; MDIST_0] THEN CONV_TAC NUM_REDUCE_CONV;
    SIMP_TAC[MDIST_SYM];
    MAP_EVERY X_GEN_TAC [`x1:A`; `y1:B`; `x2:A`; `y2:B`; `x3:A`; `y3:B`] THEN
    STRIP_TAC THEN MATCH_MP_TAC REAL_LE_LSQRT THEN
    ASM_SIMP_TAC[REAL_LE_ADD; SQRT_POS_LE; REAL_LE_POW_2] THEN
    REWRITE_TAC[REAL_ARITH
     `(a + b:real) pow 2 = (a pow 2 + b pow 2) + &2 * a * b`] THEN
    SIMP_TAC[SQRT_POW_2; REAL_LE_ADD; REAL_LE_POW_2] THEN
    TRANS_TAC REAL_LE_TRANS
     `(mdist m1 (x1:A,x2) + mdist m1 (x2,x3)) pow 2 +
      (mdist m2 (y1:B,y2) + mdist m2 (y2,y3)) pow 2` THEN
    CONJ_TAC THENL
     [MATCH_MP_TAC REAL_LE_ADD2 THEN CONJ_TAC THEN
      MATCH_MP_TAC REAL_POW_LE2 THEN
      ASM_MESON_TAC[MDIST_POS_LE; MDIST_TRIANGLE];
      REWRITE_TAC[REAL_ARITH
       `(x1 + x2) pow 2 + (y1 + y2) pow 2 <=
        ((x1 pow 2 + y1 pow 2) + (x2 pow 2 + y2 pow 2)) + &2 * b <=>
        x1 * x2 + y1 * y2 <= b`] THEN
      REWRITE_TAC[GSYM SQRT_MUL] THEN MATCH_MP_TAC REAL_LE_RSQRT THEN
      REWRITE_TAC[REAL_LE_POW_2; REAL_ARITH
        `(x1 * x2 + y1 * y2) pow 2 <=
         (x1 pow 2 + y1 pow 2) * (x2 pow 2 + y2 pow 2) <=>
         &0 <= (x1 * y2 - x2 * y1) pow 2`]]]);;

let COMPONENT_LE_PROD_METRIC = prove
 (`!m1 m2 x1 y1 x2:A y2:B.
        mdist m1 (x1,x2) <= mdist (prod_metric m1 m2) ((x1,y1),(x2,y2)) /\
        mdist m2 (y1,y2) <= mdist (prod_metric m1 m2) ((x1,y1),(x2,y2))`,
  REPEAT GEN_TAC THEN CONJ_TAC THEN REWRITE_TAC[PROD_METRIC] THEN
  MATCH_MP_TAC REAL_LE_RSQRT THEN REWRITE_TAC[REAL_LE_ADDR; REAL_LE_ADDL] THEN
  REWRITE_TAC[REAL_LE_POW_2]);;

let PROD_METRIC_LE_COMPONENTS = prove
 (`!m1 m2 x1 y1 x2:A y2:B.
        x1 IN mspace m1 /\ x2 IN mspace m1 /\
        y1 IN mspace m2 /\ y2 IN mspace m2
        ==> mdist (prod_metric m1 m2) ((x1,y1),(x2,y2))
            <= mdist m1 (x1,x2) + mdist m2 (y1,y2)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[PROD_METRIC] THEN
  MATCH_MP_TAC REAL_LE_LSQRT THEN ASM_SIMP_TAC[REAL_LE_ADD; MDIST_POS_LE;
   REAL_ARITH `x pow 2 + y pow 2 <= (x + y) pow 2 <=> &0 <= x * y`] THEN
  ASM_SIMP_TAC[REAL_LE_MUL; MDIST_POS_LE]);;

let MBALL_PROD_METRIC_SUBSET = prove
 (`!m1 m2 x:A y:B r.
        mball (prod_metric m1 m2) ((x,y),r) SUBSET
        mball m1 (x,r) CROSS mball m2 (y,r)`,
  REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_MBALL; IN_CROSS;
              CONJUNCT1 PROD_METRIC] THEN
  MESON_TAC[COMPONENT_LE_PROD_METRIC; REAL_LET_TRANS]);;

let MCBALL_PROD_METRIC_SUBSET = prove
 (`!m1 m2 x:A y:B r.
        mcball (prod_metric m1 m2) ((x,y),r) SUBSET
        mcball m1 (x,r) CROSS mcball m2 (y,r)`,
  REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_MCBALL; IN_CROSS;
              CONJUNCT1 PROD_METRIC] THEN
  MESON_TAC[COMPONENT_LE_PROD_METRIC; REAL_LE_TRANS]);;

let MBALL_SUBSET_PROD_METRIC = prove
 (`!m1 m2 x:A y:B r r'.
        mball m1 (x,r) CROSS mball m2 (y,r')
        SUBSET mball (prod_metric m1 m2) ((x,y),r + r')`,
  REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_MBALL; IN_CROSS;
              CONJUNCT1 PROD_METRIC] THEN
  MESON_TAC[REAL_ARITH `x <= y + z /\ y < a /\ z < b ==> x < a + b`;
            PROD_METRIC_LE_COMPONENTS]);;

let MCBALL_SUBSET_PROD_METRIC = prove
 (`!m1 m2 x:A y:B r r'.
        mcball m1 (x,r) CROSS mcball m2 (y,r')
        SUBSET mcball (prod_metric m1 m2) ((x,y),r + r')`,
  REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_MCBALL; IN_CROSS;
              CONJUNCT1 PROD_METRIC] THEN
  MESON_TAC[REAL_ARITH `x <= y + z /\ y <= a /\ z <= b ==> x <= a + b`;
            PROD_METRIC_LE_COMPONENTS]);;

let MTOPOLOGY_PROD_METRIC = prove
 (`!(m1:A metric) (m2:B metric).
        mtopology(prod_metric m1 m2) =
        prod_topology (mtopology m1) (mtopology m2)`,
  REPEAT GEN_TAC THEN CONV_TAC SYM_CONV THEN REWRITE_TAC[prod_topology] THEN
  MATCH_MP_TAC TOPOLOGY_BASE_UNIQUE THEN
  REWRITE_TAC[SET_RULE `GSPEC a x <=> x IN GSPEC a`] THEN REPEAT CONJ_TAC THENL
   [REWRITE_TAC[FORALL_IN_GSPEC; OPEN_IN_MTOPOLOGY; PROD_METRIC] THEN
    MAP_EVERY X_GEN_TAC [`s:A->bool`; `t:B->bool`] THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[SUBSET_CROSS; FORALL_PAIR_THM; IN_CROSS] THEN
    MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `y:B`) THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `r1:real` THEN STRIP_TAC THEN
    X_GEN_TAC `r2:real` THEN STRIP_TAC THEN
    EXISTS_TAC `min r1 r2:real` THEN ASM_REWRITE_TAC[REAL_LT_MIN] THEN
    W(MP_TAC o PART_MATCH lhand MBALL_PROD_METRIC_SUBSET o lhand o snd) THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] SUBSET_TRANS) THEN
    REWRITE_TAC[SUBSET_CROSS] THEN REPEAT DISJ2_TAC THEN CONJ_TAC;
    REWRITE_TAC[FORALL_PAIR_THM; EXISTS_IN_GSPEC] THEN
    MAP_EVERY X_GEN_TAC [`u:A#B->bool`; `x:A`; `y:B`] THEN
    GEN_REWRITE_TAC (LAND_CONV o ONCE_DEPTH_CONV) [OPEN_IN_MTOPOLOGY] THEN
    DISCH_THEN(CONJUNCTS_THEN2 (CONJUNCTS_THEN2 ASSUME_TAC
     (MP_TAC o SPEC `(x,y):A#B`)) ASSUME_TAC) THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `r:real` THEN STRIP_TAC THEN MAP_EVERY EXISTS_TAC
     [`mball m1 (x:A,r / &2)`; `mball m2 (y:B,r / &2)`] THEN
    FIRST_ASSUM(MP_TAC o SPEC `(x,y):A#B` o REWRITE_RULE[SUBSET] o
     GEN_REWRITE_RULE RAND_CONV [CONJUNCT1 PROD_METRIC]) THEN
    ASM_REWRITE_TAC[IN_CROSS] THEN STRIP_TAC THEN
    ASM_SIMP_TAC[OPEN_IN_MBALL; IN_CROSS; CENTRE_IN_MBALL; REAL_HALF] THEN
    W(MP_TAC o PART_MATCH lhand MBALL_SUBSET_PROD_METRIC o lhand o snd) THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT] SUBSET_TRANS)] THEN
  FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
   (REWRITE_RULE[IMP_CONJ_ALT] SUBSET_TRANS)) THEN
  MATCH_MP_TAC MBALL_SUBSET_CONCENTRIC THEN REAL_ARITH_TAC);;

let SUBMETRIC_PROD_METRIC = prove
 (`!m1 m2 s:A->bool t:B->bool.
        submetric (prod_metric m1 m2) (s CROSS t) =
        prod_metric (submetric m1 s) (submetric m2 t)`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC RAND_CONV [prod_metric] THEN
  GEN_REWRITE_TAC LAND_CONV [submetric] THEN
  REWRITE_TAC[SUBMETRIC; PROD_METRIC; INTER_CROSS]);;

let METRIZABLE_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        metrizable_space (prod_topology top1 top2) <=>
        topspace(prod_topology top1 top2) = {} \/
        metrizable_space top1 /\ metrizable_space top2`,
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#B->bool = {}` THENL
   [ASM_MESON_TAC[SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_EMPTY;
                  METRIZABLE_SPACE_DISCRETE_TOPOLOGY];
    ASM_REWRITE_TAC[]] THEN
  EQ_TAC THENL
   [ALL_TAC; MESON_TAC[MTOPOLOGY_PROD_METRIC; metrizable_space]] THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; LEFT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`a:A`; `b:B`] THEN REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP METRIZABLE_SPACE_SUBTOPOLOGY) THENL
   [DISCH_THEN(MP_TAC o SPEC `(topspace top1 CROSS {b}):A#B->bool`);
    DISCH_THEN(MP_TAC o SPEC `({a} CROSS topspace top2):A#B->bool`)] THEN
  MATCH_MP_TAC EQ_IMP THEN MATCH_MP_TAC HOMEOMORPHIC_METRIZABLE_SPACE THEN
  REWRITE_TAC[SUBTOPOLOGY_CROSS; SUBTOPOLOGY_TOPSPACE] THENL
   [MATCH_MP_TAC PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_LEFT;
    MATCH_MP_TAC PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_RIGHT] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN ASM SET_TAC[]);;

let CAUCHY_IN_PROD_METRIC = prove
 (`!m1 m2 x:num->A#B.
        cauchy_in (prod_metric m1 m2) x <=>
        cauchy_in m1 (FST o x) /\ cauchy_in m2 (SND o x)`,
  REWRITE_TAC[FORALL_PAIR_FUN_THM] THEN MAP_EVERY X_GEN_TAC
   [`m1:A metric`; `m2:B metric`; `a:num->A`; `b:num->B`] THEN
  REWRITE_TAC[cauchy_in; CONJUNCT1 PROD_METRIC; IN_CROSS; o_DEF] THEN
  ASM_CASES_TAC `!n. (a:num->A) n IN mspace m1` THEN
  ASM_REWRITE_TAC[FORALL_AND_THM] THEN
  ASM_CASES_TAC `!n. (b:num->B) n IN mspace m2` THEN ASM_REWRITE_TAC[] THEN
  EQ_TAC THENL
   [ASM_MESON_TAC[COMPONENT_LE_PROD_METRIC; REAL_LET_TRANS];
    DISCH_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC] THEN
  FIRST_X_ASSUM(CONJUNCTS_THEN (MP_TAC o SPEC `e / &2`)) THEN
  ASM_REWRITE_TAC[REAL_HALF; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `M:num` THEN DISCH_TAC THEN X_GEN_TAC `N:num` THEN DISCH_TAC THEN
  EXISTS_TAC `MAX M N` THEN
  REWRITE_TAC[ARITH_RULE `MAX M N <= n <=> M <= n /\ N <= n`] THEN
  MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN STRIP_TAC THEN
  REPEAT(FIRST_X_ASSUM(MP_TAC o SPECL [`m:num`; `n:num`])) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC(REAL_ARITH
   `z <= x + y ==> x < e / &2 ==> y < e / &2 ==> z < e`) THEN
  ASM_MESON_TAC[PROD_METRIC_LE_COMPONENTS; REAL_ADD_SYM]);;

let MCOMPLETE_PROD_METRIC = prove
 (`!(m1:A metric) (m2:B metric).
        mcomplete (prod_metric m1 m2) <=>
        mspace m1 = {} \/ mspace m2 = {} \/ mcomplete m1 /\ mcomplete m2`,
  REPEAT STRIP_TAC THEN MAP_EVERY ASM_CASES_TAC
   [`mspace m1:A->bool = {}`; `mspace m2:B->bool = {}`] THEN
  ASM_SIMP_TAC[MCOMPLETE_EMPTY_MSPACE; CONJUNCT1 PROD_METRIC; CROSS_EMPTY] THEN
  REWRITE_TAC[mcomplete; CAUCHY_IN_PROD_METRIC] THEN
  REWRITE_TAC[MTOPOLOGY_PROD_METRIC; LIMIT_PAIRWISE; EXISTS_PAIR_THM] THEN
  EQ_TAC THENL [ALL_TAC; ASM_MESON_TAC[]] THEN DISCH_TAC THEN CONJ_TAC THENL
   [X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
    UNDISCH_TAC `~(mspace m2:B->bool = {})` THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `y:B` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `(\n. (x n,y)):num->A#B`);
    X_GEN_TAC `y:num->B` THEN DISCH_TAC THEN
    UNDISCH_TAC `~(mspace m1:A->bool = {})` THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `(\n. (x,y n)):num->A#B`)] THEN
  ASM_REWRITE_TAC[o_DEF; ETA_AX; CAUCHY_IN_CONST] THEN MESON_TAC[]);;

let COMPLETELY_METRIZABLE_SPACE_PROD_TOPOLOGY = prove
 (`!top1:A topology top2:B topology.
        completely_metrizable_space (prod_topology top1 top2) <=>
        topspace(prod_topology top1 top2) = {} \/
        completely_metrizable_space top1 /\ completely_metrizable_space top2`,
  REPEAT STRIP_TAC THEN
  ASM_CASES_TAC `topspace(prod_topology top1 top2):A#B->bool = {}` THENL
   [ASM_MESON_TAC[SUBTOPOLOGY_EQ_DISCRETE_TOPOLOGY_EMPTY;
                  COMPLETELY_METRIZABLE_SPACE_DISCRETE_TOPOLOGY];
    ASM_REWRITE_TAC[]] THEN
  EQ_TAC THENL
   [ALL_TAC;
    REWRITE_TAC[completely_metrizable_space] THEN
    METIS_TAC[MCOMPLETE_PROD_METRIC; MTOPOLOGY_PROD_METRIC]] THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY]) THEN
  REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; LEFT_IMP_EXISTS_THM] THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS] THEN
  MAP_EVERY X_GEN_TAC [`a:A`; `b:B`] THEN REPEAT STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP METRIZABLE_IMP_HAUSDORFF_SPACE o
     MATCH_MP COMPLETELY_METRIZABLE_IMP_METRIZABLE_SPACE) THEN
  REWRITE_TAC[HAUSDORFF_SPACE_PROD_TOPOLOGY; TOPSPACE_PROD_TOPOLOGY] THEN
  REWRITE_TAC[EXTENSION; IN_ELIM_THM; IN_CROSS; FORALL_PAIR_THM] THEN
  (STRIP_TAC THENL [ASM SET_TAC[]; ALL_TAC]) THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP
   (REWRITE_RULE[IMP_CONJ] COMPLETELY_METRIZABLE_SPACE_CLOSED_IN))
  THENL
   [DISCH_THEN(MP_TAC o SPEC `(topspace top1 CROSS {b}):A#B->bool`);
    DISCH_THEN(MP_TAC o SPEC `({a} CROSS topspace top2):A#B->bool`)] THEN
  REWRITE_TAC[CLOSED_IN_CROSS; CLOSED_IN_TOPSPACE] THEN
  ASM_SIMP_TAC[CLOSED_IN_HAUSDORFF_SING] THEN MATCH_MP_TAC EQ_IMP THEN
  MATCH_MP_TAC HOMEOMORPHIC_COMPLETELY_METRIZABLE_SPACE THEN
  REWRITE_TAC[SUBTOPOLOGY_CROSS; SUBTOPOLOGY_TOPSPACE] THENL
   [MATCH_MP_TAC PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_LEFT;
    MATCH_MP_TAC PROD_TOPOLOGY_HOMEOMORPHIC_SPACE_RIGHT] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN ASM SET_TAC[]);;

let MBOUNDED_CROSS = prove
 (`!(m1:A metric) (m2:B metric) s t.
        mbounded (prod_metric m1 m2) (s CROSS t) <=>
        s = {} \/ t = {} \/ mbounded m1 s /\ mbounded m2 t`,
  REPEAT GEN_TAC THEN MAP_EVERY ASM_CASES_TAC
   [`s:A->bool = {}`; `t:B->bool = {}`] THEN
  ASM_REWRITE_TAC[MBOUNDED_EMPTY; CROSS_EMPTY] THEN
  REWRITE_TAC[mbounded; EXISTS_PAIR_THM] THEN MATCH_MP_TAC(MESON[]
   `(!x y. P x y <=> Q x /\ R y)
    ==> ((?x y. P x y) <=> (?x. Q x) /\ (?y. R y))`) THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:B`] THEN EQ_TAC THENL
   [DISCH_THEN(X_CHOOSE_TAC `r:real`) THEN
    REWRITE_TAC[LEFT_AND_EXISTS_THM; RIGHT_AND_EXISTS_THM] THEN
    REPEAT(EXISTS_TAC `r:real`) THEN
    MATCH_MP_TAC(MESON[SUBSET_CROSS]
     `s CROSS t SUBSET u CROSS v /\ ~(s = {}) /\ ~(t = {})
      ==> s SUBSET u /\ t SUBSET v`) THEN
    ASM_MESON_TAC[SUBSET_TRANS; MCBALL_PROD_METRIC_SUBSET];
    DISCH_THEN(CONJUNCTS_THEN2
     (X_CHOOSE_TAC `r1:real`) (X_CHOOSE_TAC `r2:real`)) THEN
    EXISTS_TAC `r1 + r2:real` THEN
    W(MP_TAC o PART_MATCH rand MCBALL_SUBSET_PROD_METRIC o rand o snd) THEN
    MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ] SUBSET_TRANS) THEN
    ASM_REWRITE_TAC[SUBSET_CROSS]]);;

let MBOUNDED_PROD_METRIC = prove
 (`!(m1:A metric) (m2:B metric) u.
        mbounded (prod_metric m1 m2) u <=>
        mbounded m1 (IMAGE FST u) /\ mbounded m2 (IMAGE SND u)`,
  REPEAT GEN_TAC THEN  EQ_TAC THENL
   [REWRITE_TAC[mbounded; SUBSET; FORALL_IN_IMAGE; FORALL_PAIR_THM] THEN
    REWRITE_TAC[EXISTS_PAIR_THM] THEN MATCH_MP_TAC(MESON[]
     `(!r x y. R x y r ==> P x r /\ Q y r)
      ==> (?x y r. R x y r) ==> (?x r. P x r) /\ (?y r. Q y r)`) THEN
    MAP_EVERY X_GEN_TAC [`r:real`; `x:A`; `y:B`] THEN
    MP_TAC(ISPECL [`m1:A metric`; `m2:B metric`; `x:A`; `y:B`; `r:real`]
        MCBALL_PROD_METRIC_SUBSET) THEN
    REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_CROSS] THEN MESON_TAC[];
    STRIP_TAC THEN MATCH_MP_TAC MBOUNDED_SUBSET THEN
    EXISTS_TAC `((IMAGE FST u) CROSS (IMAGE SND u)):A#B->bool` THEN
    ASM_REWRITE_TAC[MBOUNDED_CROSS; IMAGE_EQ_EMPTY] THEN
    REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_CROSS] THEN
    REWRITE_TAC[IN_IMAGE; EXISTS_PAIR_THM] THEN MESON_TAC[]]);;

let TOTALLY_BOUNDED_IN_CROSS = prove
 (`!(m1:A metric) (m2:B metric) s t.
       totally_bounded_in (prod_metric m1 m2) (s CROSS t) <=>
       s = {} \/ t = {} \/ totally_bounded_in m1 s /\ totally_bounded_in m2 t`,
  REPEAT GEN_TAC THEN MAP_EVERY ASM_CASES_TAC
   [`s:A->bool = {}`; `t:B->bool = {}`] THEN
  ASM_REWRITE_TAC[CROSS_EMPTY; TOTALLY_BOUNDED_IN_EMPTY] THEN
  REWRITE_TAC[TOTALLY_BOUNDED_IN_SEQUENTIALLY] THEN
  ASM_REWRITE_TAC[CONJUNCT1 PROD_METRIC; SUBSET_CROSS] THEN
  ASM_CASES_TAC `(s:A->bool) SUBSET mspace m1` THEN ASM_REWRITE_TAC[] THEN
  ASM_CASES_TAC `(t:B->bool) SUBSET mspace m2` THEN ASM_REWRITE_TAC[] THEN
  EQ_TAC THEN STRIP_TAC THEN TRY CONJ_TAC THENL
   [X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
    UNDISCH_TAC `~(t:B->bool = {})` THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `y:B` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `(\n. (x n,y)):num->A#B`) THEN
    ASM_REWRITE_TAC[IN_CROSS; CAUCHY_IN_PROD_METRIC] THEN
    MATCH_MP_TAC MONO_EXISTS THEN SIMP_TAC[o_DEF];
    X_GEN_TAC `y:num->B` THEN DISCH_TAC THEN
    UNDISCH_TAC `~(s:A->bool = {})` THEN
    REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `x:A` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `(\n. (x,y n)):num->A#B`) THEN
    ASM_REWRITE_TAC[IN_CROSS; CAUCHY_IN_PROD_METRIC] THEN
    MATCH_MP_TAC MONO_EXISTS THEN SIMP_TAC[o_DEF];
    REWRITE_TAC[FORALL_PAIR_FUN_THM; IN_CROSS; FORALL_AND_THM] THEN
    MAP_EVERY X_GEN_TAC [`x:num->A`; `y:num->B`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(X_CHOOSE_THEN `r1:num->num` STRIP_ASSUME_TAC) THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `(y:num->B) o (r1:num->num)`) THEN
    ASM_REWRITE_TAC[o_THM] THEN
    DISCH_THEN(X_CHOOSE_THEN `r2:num->num` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `(r1:num->num) o (r2:num->num)` THEN
    ASM_SIMP_TAC[o_THM; CAUCHY_IN_PROD_METRIC; o_ASSOC] THEN
    ONCE_REWRITE_TAC[o_ASSOC] THEN GEN_REWRITE_TAC
     (BINOP_CONV o RAND_CONV o LAND_CONV o LAND_CONV) [o_DEF] THEN
    ASM_REWRITE_TAC[ETA_AX] THEN ASM_SIMP_TAC[CAUCHY_IN_SUBSEQUENCE]]);;

let TOTALLY_BOUNDED_IN_PROD_METRIC = prove
 (`!(m1:A metric) (m2:B metric) u.
        totally_bounded_in (prod_metric m1 m2) u <=>
        totally_bounded_in m1 (IMAGE FST u) /\
        totally_bounded_in m2 (IMAGE SND u)`,
  REPEAT GEN_TAC THEN  EQ_TAC THENL
   [REWRITE_TAC[TOTALLY_BOUNDED_IN_SEQUENTIALLY] THEN
    REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; FORALL_PAIR_THM] THEN
    REWRITE_TAC[CONJUNCT1 PROD_METRIC; IN_CROSS] THEN STRIP_TAC THEN
    CONJ_TAC THEN (CONJ_TAC THENL [ASM_MESON_TAC[]; ALL_TAC]) THEN
    SIMP_TAC[IN_IMAGE; SKOLEM_THM; LEFT_IMP_EXISTS_THM] THEN
    GEN_TAC THEN X_GEN_TAC `z:num->A#B` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `z:num->A#B`) THEN
    ASM_REWRITE_TAC[CAUCHY_IN_PROD_METRIC] THEN
    MATCH_MP_TAC MONO_EXISTS THEN ASM_SIMP_TAC[o_DEF];
    STRIP_TAC THEN MATCH_MP_TAC TOTALLY_BOUNDED_IN_SUBSET THEN
    EXISTS_TAC `((IMAGE FST u) CROSS (IMAGE SND u)):A#B->bool` THEN
    ASM_REWRITE_TAC[TOTALLY_BOUNDED_IN_CROSS; IMAGE_EQ_EMPTY] THEN
    REWRITE_TAC[SUBSET; FORALL_PAIR_THM; IN_CROSS] THEN
    REWRITE_TAC[IN_IMAGE; EXISTS_PAIR_THM] THEN MESON_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* Homotopy of maps p,q : X->Y with property P of all intermediate maps.     *)
(* We often just want to require that it fixes some subset, but to take in   *)
(* the case of loop homotopy it's convenient to have a general property P.   *)
(* ------------------------------------------------------------------------- *)

let homotopic_with = new_definition
  `homotopic_with P (X,Y) p q <=>
   ?h. continuous_map
       (prod_topology (subtopology euclideanreal (real_interval[&0,&1])) X,
        Y) h /\
       (!x. h(&0,x) = p x) /\ (!x. h(&1,x) = q x) /\
       (!t. t IN real_interval[&0,&1] ==> P(\x. h(t,x)))`;;

let HOMOTOPIC_WITH_IMP_CONTINUOUS_MAPS = prove
 (`!P X Y p q:A->B.
        homotopic_with P (X,Y) p q
        ==> continuous_map (X,Y) p /\ continuous_map (X,Y) q`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[homotopic_with; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `h:real#A->B` THEN REPEAT STRIP_TAC THENL
   [SUBGOAL_THEN `p = (h:real#A->B) o (\x. (&0,x))` SUBST1_TAC THENL
     [ASM_REWRITE_TAC[FUN_EQ_THM; o_THM]; ALL_TAC];
    SUBGOAL_THEN `q = (h:real#A->B) o (\x. (&1,x))` SUBST1_TAC THENL
     [ASM_REWRITE_TAC[FUN_EQ_THM; o_THM]; ALL_TAC]] THEN
  FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
        CONTINUOUS_MAP_COMPOSE)) THEN
  REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX] THEN
  REWRITE_TAC[CONTINUOUS_MAP_ID; CONTINUOUS_MAP_CONST] THEN DISJ2_TAC THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; TOPSPACE_EUCLIDEANREAL; INTER_UNIV] THEN
  REWRITE_TAC[IN_REAL_INTERVAL] THEN REAL_ARITH_TAC);;

let HOMOTOPIC_WITH_IMP_PROPERTY = prove
 (`!P X Y f g:A->B. homotopic_with P (X,Y) f g ==> P f /\ P g`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homotopic_with] THEN
  DISCH_THEN(X_CHOOSE_THEN `h:real#A->B` MP_TAC) THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN DISCH_THEN
   (fun th -> MP_TAC(SPEC `&0:real` th) THEN
              MP_TAC(SPEC `&1:real` th)) THEN
  ASM_SIMP_TAC[ENDS_IN_UNIT_REAL_INTERVAL; ETA_AX]);;

let HOMOTOPIC_WITH_EQUAL = prove
 (`!P top top' (f:A->B) g.
        P f /\ P g /\
        continuous_map(top,top') f /\
        (!x. x IN topspace top ==> f x = g x)
        ==> homotopic_with P (top,top') f g`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[homotopic_with] THEN
  EXISTS_TAC `(\(t,x). if t = &1 then g x else f x):real#A->B` THEN
  ASM_REWRITE_TAC[] THEN CONV_TAC REAL_RAT_REDUCE_CONV THEN CONJ_TAC THENL
   [MATCH_MP_TAC CONTINUOUS_MAP_EQ THEN EXISTS_TAC `(f o SND):real#A->B` THEN
    REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; FORALL_PAIR_THM] THEN
    REWRITE_TAC[TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY; o_THM; IN_CROSS] THEN
    ASM_SIMP_TAC[COND_ID] THEN MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
    EXISTS_TAC `top:A topology` THEN ASM_REWRITE_TAC[] THEN
    SIMP_TAC[PROD_TOPOLOGY_SUBTOPOLOGY; CONTINUOUS_MAP_FROM_SUBTOPOLOGY;
             CONTINUOUS_MAP_SND];
    X_GEN_TAC `t:real` THEN ASM_CASES_TAC `t:real = &1` THEN
    ASM_REWRITE_TAC[ETA_AX]]);;

let HOMOTOPIC_WITH_REFL = prove
 (`!P top top' f:A->B.
        homotopic_with P (top,top') f f <=>
        continuous_map (top,top') f /\ P f`,
  REPEAT GEN_TAC THEN EQ_TAC THENL
   [MESON_TAC[HOMOTOPIC_WITH_IMP_CONTINUOUS_MAPS; HOMOTOPIC_WITH_IMP_PROPERTY];
    DISCH_TAC THEN MATCH_MP_TAC HOMOTOPIC_WITH_EQUAL THEN
    ASM_REWRITE_TAC[]]);;

let HOMOTOPIC_WITH_SYM = prove
 (`!P X Y f g:A->B.
     homotopic_with P (X,Y) f g <=> homotopic_with P (X,Y) g f`,
  REPLICATE_TAC 3 GEN_TAC THEN MATCH_MP_TAC(MESON[]
   `(!x y. P x y ==> P y x) ==> (!x y. P x y <=> P y x)`) THEN
  REPEAT GEN_TAC THEN REWRITE_TAC[homotopic_with] THEN
  DISCH_THEN(X_CHOOSE_THEN `h:real#A->B` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `\(t,x). (h:real#A->B) (&1 - t,x)` THEN
  ASM_REWRITE_TAC[REAL_SUB_REFL; REAL_SUB_RZERO] THEN CONJ_TAC THENL
   [REWRITE_TAC[LAMBDA_PAIR] THEN
    GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
    MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN EXISTS_TAC
      `prod_topology (subtopology euclideanreal (real_interval [&0,&1]))
                     (X:A topology)` THEN
    ASM_REWRITE_TAC[CONTINUOUS_MAP_PAIRED; CONTINUOUS_MAP_SND] THEN
    REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
    REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; TOPSPACE_EUCLIDEANREAL_SUBTOPOLOGY;
                FORALL_PAIR_THM; IN_CROSS; IN_REAL_INTERVAL] THEN
    CONJ_TAC THENL [ALL_TAC; REAL_ARITH_TAC] THEN
    MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB THEN
    REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
    GEN_REWRITE_TAC RAND_CONV [GSYM ETA_AX] THEN
    REWRITE_TAC[CONTINUOUS_MAP_OF_FST] THEN
    SIMP_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY; CONTINUOUS_MAP_ID];
    REWRITE_TAC[IN_REAL_INTERVAL] THEN REPEAT STRIP_TAC THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN REWRITE_TAC[IN_REAL_INTERVAL] THEN
    ASM_REAL_ARITH_TAC]);;

let HOMOTOPIC_WITH_TRANS = prove
 (`!P top top' (f:A->B) g h.
        homotopic_with P (top,top') f g /\
        homotopic_with P (top,top') g h
        ==> homotopic_with P (top,top') f h`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homotopic_with; IN_REAL_INTERVAL] THEN
  DISCH_THEN(CONJUNCTS_THEN2
   (X_CHOOSE_THEN `h:real#A->B` STRIP_ASSUME_TAC)
   (X_CHOOSE_THEN `k:real#A->B` STRIP_ASSUME_TAC)) THEN
  EXISTS_TAC `\z. if FST z <= &1 / &2
                  then (h:real#A->B)(&2 * FST z,SND z)
                  else (k:real#A->B)(&2 * FST z - &1,SND z)` THEN
  REWRITE_TAC[] THEN CONV_TAC REAL_RAT_REDUCE_CONV THEN
  ASM_REWRITE_TAC[] THEN CONJ_TAC THENL
   [MATCH_MP_TAC CONTINUOUS_MAP_CASES_LE THEN
    SIMP_TAC[] THEN CONV_TAC REAL_RAT_REDUCE_CONV THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
    CONJ_TAC THENL
     [REWRITE_TAC[PROD_TOPOLOGY_SUBTOPOLOGY] THEN
      SIMP_TAC[CONTINUOUS_MAP_FST; CONTINUOUS_MAP_FROM_SUBTOPOLOGY];
      CONJ_TAC THEN
      GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
      MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN EXISTS_TAC
       `prod_topology (subtopology euclideanreal (real_interval [&0,&1]))
                      (top:A topology)` THEN
      ASM_REWRITE_TAC[] THEN
      REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX] THEN
      SIMP_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY; CONTINUOUS_MAP_SND] THEN
      REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
      REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; TOPSPACE_SUBTOPOLOGY;
                  FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_INTER;
                  IN_ELIM_THM; IN_CROSS; IN_REAL_INTERVAL] THEN
      (CONJ_TAC THENL [ALL_TAC; REAL_ARITH_TAC]) THEN
      TRY(MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB) THEN
      REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
      MATCH_MP_TAC CONTINUOUS_MAP_REAL_LMUL THEN
      MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY THEN
      REWRITE_TAC[PROD_TOPOLOGY_SUBTOPOLOGY] THEN
      MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY THEN
      REWRITE_TAC[CONTINUOUS_MAP_FST; ETA_AX]];
    X_GEN_TAC `t:real` THEN STRIP_TAC THEN
    ASM_CASES_TAC `t <= &1 / &2` THEN ASM_REWRITE_TAC[] THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_REAL_ARITH_TAC]);;

let HOMOTOPIC_COMPOSE_CONTINUOUS_MAP_LEFT = prove
 (`!(f:A->B) g (h:B->C) top1 top2 top3.
        homotopic_with (\k. T) (top1,top2) f g /\
        continuous_map (top2,top3) h
        ==> homotopic_with (\k. T) (top1,top3) (h o f) (h o g)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[IMP_CONJ_ALT] THEN DISCH_TAC THEN
  REWRITE_TAC[homotopic_with; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `k:real#A->B` THEN STRIP_TAC THEN
  EXISTS_TAC `(h:B->C) o (k:real#A->B)` THEN
  ASM_REWRITE_TAC[o_THM] THEN
  ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE]);;

let HOMOTOPIC_COMPOSE_CONTINUOUS_MAP_RIGHT = prove
 (`!(f:B->C) g (h:A->B) top1 top2 top3.
        homotopic_with (\k. T) (top2,top3) f g /\
        continuous_map (top1,top2) h
        ==> homotopic_with (\k. T) (top1,top3) (f o h) (g o h)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[IMP_CONJ_ALT] THEN DISCH_TAC THEN
  REWRITE_TAC[homotopic_with; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `k:real#B->C` THEN STRIP_TAC THEN
  EXISTS_TAC `\(t,x). (k:real#B->C)(t,(h:A->B) x)` THEN
  ASM_REWRITE_TAC[o_THM] THEN
  REWRITE_TAC[LAMBDA_PAIR] THEN
  GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
     CONTINUOUS_MAP_COMPOSE)) THEN
  REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX] THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_FST; CONTINUOUS_MAP_OF_SND]);;

(* ------------------------------------------------------------------------- *)
(* Homotopy equivalence of topological spaces.                               *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("homotopy_equivalent_space",(12,"right"));;

let homotopy_equivalent_space = new_definition
 `(top:A topology) homotopy_equivalent_space (top':B topology) <=>
        ?f g. continuous_map (top,top') f /\
              continuous_map (top',top) g /\
              homotopic_with (\x. T) (top,top) (g o f) I /\
              homotopic_with (\x. T) (top',top') (f o g) I`;;

let HOMEOMORPHIC_IMP_HOMOTOPY_EQUIVALENT_SPACE = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> top homotopy_equivalent_space top'`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[homeomorphic_space; homotopy_equivalent_space] THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN
  REWRITE_TAC[homeomorphic_maps] THEN REPEAT STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC HOMOTOPIC_WITH_EQUAL THEN
  ASM_REWRITE_TAC[o_THM; I_THM] THEN
  ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE]);;

let HOMOTOPY_EQUIVALENT_SPACE_REFL = prove
 (`!top:A topology. top homotopy_equivalent_space top`,
  SIMP_TAC[HOMEOMORPHIC_IMP_HOMOTOPY_EQUIVALENT_SPACE;
           HOMEOMORPHIC_SPACE_REFL]);;

let HOMOTOPY_EQUIVALENT_SPACE_SYM = prove
 (`!(top:A topology) (top':B topology).
        top homotopy_equivalent_space top' <=>
        top' homotopy_equivalent_space top`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homotopy_equivalent_space] THEN
  GEN_REWRITE_TAC RAND_CONV [SWAP_EXISTS_THM] THEN
  REPEAT(AP_TERM_TAC THEN ABS_TAC) THEN CONV_TAC TAUT);;

let HOMOTOPY_EQUIVALENT_SPACE_TRANS = prove
 (`!top1:A topology top2:B topology top3:C topology.
        top1 homotopy_equivalent_space top2 /\
        top2 homotopy_equivalent_space top3
        ==> top1 homotopy_equivalent_space top3`,
  REPEAT GEN_TAC THEN REWRITE_TAC[homotopy_equivalent_space] THEN
  SIMP_TAC[LEFT_AND_EXISTS_THM; LEFT_IMP_EXISTS_THM] THEN
  SIMP_TAC[RIGHT_AND_EXISTS_THM; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC
   [`f1:A->B`; `g1:B->A`;
    `f2:B->C`; `g2:C->B`] THEN
  STRIP_TAC THEN
  MAP_EVERY EXISTS_TAC
   [`(f2:B->C) o (f1:A->B)`;
    `(g1:B->A) o (g2:C->B)`] THEN
  REWRITE_TAC[IMAGE_o] THEN REPLICATE_TAC 2
   (CONJ_TAC THENL [ASM_MESON_TAC[CONTINUOUS_MAP_COMPOSE]; ALL_TAC]) THEN
  CONJ_TAC THEN MATCH_MP_TAC HOMOTOPIC_WITH_TRANS THENL
   [EXISTS_TAC `(g1:B->A) o I o (f1:A->B)`;
    EXISTS_TAC `(f2:B->C) o I o (g2:C->B)`] THEN
  (CONJ_TAC THENL [ALL_TAC; ASM_REWRITE_TAC[I_O_ID]]) THEN
  REWRITE_TAC[GSYM o_ASSOC] THEN
  MATCH_MP_TAC HOMOTOPIC_COMPOSE_CONTINUOUS_MAP_LEFT THEN
  EXISTS_TAC `top2:B topology` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[o_ASSOC] THEN
  MATCH_MP_TAC HOMOTOPIC_COMPOSE_CONTINUOUS_MAP_RIGHT THEN
  EXISTS_TAC `top2:B topology` THEN ASM_REWRITE_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Contractible spaces. The definition (which agrees with "contractible" on  *)
(* subsets of Euclidean space) is a little cryptic because we don't in fact  *)
(* assume that the constant "a" is in the space. This forces the convention  *)
(* that the empty space / set is contractible, avoiding some special cases.  *)
(* ------------------------------------------------------------------------- *)

let contractible_space = new_definition
 `contractible_space (top:A topology) <=>
        ?a. homotopic_with (\x. T) (top,top) (\x. x) (\x. a)`;;

let CONTRACTIBLE_SPACE_EMPTY = prove
 (`!top:A topology. topspace top = {} ==> contractible_space top`,
  REWRITE_TAC[contractible_space; homotopic_with] THEN
  SIMP_TAC[CONTINUOUS_MAP_ON_EMPTY; TOPSPACE_PROD_TOPOLOGY; CROSS_EMPTY] THEN
  REPEAT STRIP_TAC THEN MAP_EVERY EXISTS_TAC
   [`ARB:A`; `\(t,x):real#A. if t = &0 then x else ARB`] THEN
  REWRITE_TAC[REAL_ARITH `~(&1 = &0)`]);;

let CONTRACTIBLE_SPACE_SING = prove
 (`!top a:A. topspace top = {a} ==> contractible_space top`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[contractible_space] THEN
  EXISTS_TAC `a:A` THEN REWRITE_TAC[homotopic_with] THEN
  EXISTS_TAC `(\(t,x). if t = &0 then x else a):real#A->A` THEN
  REWRITE_TAC[REAL_ARITH `~(&1 = &0)`] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_EQ THEN EXISTS_TAC `(\z. a):real#A->A` THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_CONST; IN_SING] THEN
  ASM_REWRITE_TAC[FORALL_PAIR_THM; TOPSPACE_PROD_TOPOLOGY; IN_CROSS] THEN
  SET_TAC[]);;

let CONTRACTIBLE_SPACE_SUBSET_SING = prove
 (`!top a:A. topspace top SUBSET {a} ==> contractible_space top`,
  REWRITE_TAC[SET_RULE `s SUBSET {a} <=> s = {} \/ s = {a}`] THEN
  MESON_TAC[CONTRACTIBLE_SPACE_EMPTY; CONTRACTIBLE_SPACE_SING]);;

let CONTRACTIBLE_SPACE_SUBTOPOLOGY_SING = prove
 (`!top a:A. contractible_space(subtopology top {a})`,
  REPEAT GEN_TAC THEN MATCH_MP_TAC CONTRACTIBLE_SPACE_SUBSET_SING THEN
  EXISTS_TAC `a:A` THEN REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; INTER_SUBSET]);;

let CONTRACTIBLE_SPACE = prove
 (`!top:A topology.
        contractible_space top <=>
        topspace top = {} \/
        ?a. a IN topspace top /\
            homotopic_with (\x. T) (top,top) (\x. x) (\x. a)`,
  GEN_TAC THEN ASM_CASES_TAC `topspace top:A->bool = {}` THEN
  ASM_SIMP_TAC[CONTRACTIBLE_SPACE_EMPTY] THEN
  REWRITE_TAC[contractible_space] THEN EQ_TAC THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `a:A` THEN
  STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP HOMOTOPIC_WITH_IMP_CONTINUOUS_MAPS) THEN
  REWRITE_TAC[continuous_map] THEN ASM SET_TAC[]);;

let CONTRACTIBLE_IMP_PATH_CONNECTED_SPACE = prove
 (`!top:A topology.
        contractible_space top ==> path_connected_space top`,
  GEN_TAC THEN
  ASM_CASES_TAC `topspace top:A->bool = {}` THEN
  ASM_SIMP_TAC[PATH_CONNECTED_SPACE_TOPSPACE_EMPTY; CONTRACTIBLE_SPACE] THEN
  REWRITE_TAC[homotopic_with; LEFT_IMP_EXISTS_THM; RIGHT_AND_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`a:A`; `h:real#A->A`] THEN STRIP_TAC THEN
  REWRITE_TAC[PATH_CONNECTED_SPACE_IFF_PATH_COMPONENT] THEN
  SUBGOAL_THEN
   `!x:A. x IN topspace top ==> path_component_of top x a`
  MP_TAC THENL
   [ALL_TAC;
    ASM_MESON_TAC[PATH_COMPONENT_OF_TRANS; PATH_COMPONENT_OF_SYM]] THEN
  X_GEN_TAC `b:A` THEN DISCH_TAC THEN REWRITE_TAC[path_component_of] THEN
  EXISTS_TAC `(h:real#A->A) o (\x. x,b)` THEN
  ASM_REWRITE_TAC[o_THM] THEN REWRITE_TAC[path_in] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN EXISTS_TAC
   `prod_topology (subtopology euclideanreal (real_interval[&0,&1]))
                  (top:A topology)` THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF] THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_ID; CONTINUOUS_MAP_CONST]);;

let NULLHOMOTOPIC_THROUGH_CONTRACTIBLE_SPACE = prove
 (`!(f:A->B) (g:B->C) top1 top2 top3.
        continuous_map (top1,top2) f /\
        continuous_map (top2,top3) g /\
        contractible_space top2
        ==> ?c. homotopic_with (\h. T) (top1,top3) (g o f) (\x. c)`,
  REPEAT STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [contractible_space]) THEN
  DISCH_THEN(X_CHOOSE_THEN `b:B` MP_TAC) THEN
  DISCH_THEN(MP_TAC o ISPECL [`g:B->C`; `top3:C topology`] o MATCH_MP
   (ONCE_REWRITE_RULE[IMP_CONJ] HOMOTOPIC_COMPOSE_CONTINUOUS_MAP_LEFT)) THEN
  ASM_REWRITE_TAC[] THEN
  DISCH_THEN(MP_TAC o ISPECL [`f:A->B`; `top1:A topology`] o MATCH_MP
   (ONCE_REWRITE_RULE[IMP_CONJ] HOMOTOPIC_COMPOSE_CONTINUOUS_MAP_RIGHT)) THEN
  ASM_REWRITE_TAC[o_DEF] THEN DISCH_TAC THEN
  EXISTS_TAC `(g:B->C) b` THEN ASM_REWRITE_TAC[]);;

let NULLHOMOTOPIC_INTO_CONTRACTIBLE_SPACE = prove
 (`!(f:A->B) top1 top2.
        continuous_map (top1,top2) f /\ contractible_space top2
        ==> ?c. homotopic_with (\h. T) (top1,top2) f (\x. c)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(f:A->B) = (\x. x) o f` SUBST1_TAC THENL
   [REWRITE_TAC[o_THM; FUN_EQ_THM];
    MATCH_MP_TAC NULLHOMOTOPIC_THROUGH_CONTRACTIBLE_SPACE THEN
    EXISTS_TAC `top2:B topology` THEN ASM_REWRITE_TAC[CONTINUOUS_MAP_ID]]);;

let NULLHOMOTOPIC_FROM_CONTRACTIBLE_SPACE = prove
 (`!(f:A->B) top1 top2.
        continuous_map (top1,top2) f /\ contractible_space top1
        ==> ?c. homotopic_with (\h. T) (top1,top2) f (\x. c)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(f:A->B) = f o (\x. x)` SUBST1_TAC THENL
   [REWRITE_TAC[o_THM; FUN_EQ_THM];
    MATCH_MP_TAC NULLHOMOTOPIC_THROUGH_CONTRACTIBLE_SPACE THEN
    EXISTS_TAC `top1:A topology` THEN ASM_REWRITE_TAC[CONTINUOUS_MAP_ID]]);;

let HOMOTOPY_DOMINATED_CONTRACTIBILITY = prove
 (`!(f:A->B) g top top'.
        continuous_map (top,top') f /\
        continuous_map (top',top) g /\
        homotopic_with (\x. T) (top',top') (f o g) I /\
        contractible_space top
        ==> contractible_space top'`,
  REPEAT GEN_TAC THEN SIMP_TAC[contractible_space; I_DEF] THEN STRIP_TAC THEN
  MP_TAC(ISPECL [`f:A->B`; `top:A topology`; `top':B topology`]
        NULLHOMOTOPIC_FROM_CONTRACTIBLE_SPACE) THEN
  ASM_REWRITE_TAC[contractible_space; I_DEF] THEN
  ANTS_TAC THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `b:B` THEN
  ONCE_REWRITE_TAC[HOMOTOPIC_WITH_SYM] THEN DISCH_TAC THEN
  MATCH_MP_TAC HOMOTOPIC_WITH_TRANS THEN
  EXISTS_TAC `(f:A->B) o (g:B->A)` THEN
  ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN `(\x. (b:B)) = (\x. b) o (g:B->A)`
  SUBST1_TAC THENL [REWRITE_TAC[o_DEF]; ALL_TAC] THEN
  MATCH_MP_TAC HOMOTOPIC_COMPOSE_CONTINUOUS_MAP_RIGHT THEN
  EXISTS_TAC `top:A topology` THEN ASM_REWRITE_TAC[]);;

let HOMOTOPY_EQUIVALENT_SPACE_CONTRACTIBILITY = prove
 (`!(top:A topology) (top':B topology).
        top homotopy_equivalent_space top'
        ==> (contractible_space top <=> contractible_space top')`,
  REWRITE_TAC[homotopy_equivalent_space] THEN REPEAT STRIP_TAC THEN EQ_TAC THEN
  MATCH_MP_TAC(ONCE_REWRITE_RULE[IMP_CONJ]
   (REWRITE_RULE[CONJ_ASSOC] HOMOTOPY_DOMINATED_CONTRACTIBILITY)) THEN
  ASM_MESON_TAC[]);;

let HOMEOMORPHIC_SPACE_CONTRACTIBILITY = prove
 (`!(top:A topology) (top':B topology).
        top homeomorphic_space top'
        ==> (contractible_space top <=> contractible_space top')`,
  MESON_TAC[HOMOTOPY_EQUIVALENT_SPACE_CONTRACTIBILITY;
            HOMEOMORPHIC_IMP_HOMOTOPY_EQUIVALENT_SPACE]);;

let CONTRACTIBLE_EQ_HOMOTOPY_EQUIVALENT_SINGLETON_SUBTOPOLOGY = prove
 (`!top:A topology.
        contractible_space top <=>
        topspace top = {} \/
        ?a. a IN topspace top /\
            top homotopy_equivalent_space (subtopology top {a})`,
  GEN_TAC THEN ASM_CASES_TAC `topspace top:A->bool = {}` THEN
  ASM_SIMP_TAC[CONTRACTIBLE_SPACE_EMPTY] THEN EQ_TAC THENL
   [ASM_REWRITE_TAC[CONTRACTIBLE_SPACE] THEN MATCH_MP_TAC MONO_EXISTS THEN
    X_GEN_TAC `a:A` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[homotopy_equivalent_space] THEN
    MAP_EVERY EXISTS_TAC [`(\x. a):A->A`; `(\x. x):A->A`] THEN
    ASM_SIMP_TAC[o_DEF; CONTINUOUS_MAP_FROM_SUBTOPOLOGY; CONTINUOUS_MAP_ID;
      IN_INTER; CONTINUOUS_MAP_CONST; TOPSPACE_SUBTOPOLOGY; IN_SING] THEN
    ONCE_REWRITE_TAC[HOMOTOPIC_WITH_SYM] THEN
    ASM_REWRITE_TAC[I_DEF] THEN MATCH_MP_TAC HOMOTOPIC_WITH_EQUAL THEN
    REWRITE_TAC[CONTINUOUS_MAP_ID; TOPSPACE_SUBTOPOLOGY] THEN SET_TAC[];
    DISCH_THEN(X_CHOOSE_THEN `a:A` STRIP_ASSUME_TAC) THEN
    FIRST_ASSUM(SUBST1_TAC o
      MATCH_MP HOMOTOPY_EQUIVALENT_SPACE_CONTRACTIBILITY) THEN
    MATCH_MP_TAC CONTRACTIBLE_SPACE_SING THEN
    EXISTS_TAC `a:A` THEN ASM_REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
    ASM SET_TAC[]]);;

(* ------------------------------------------------------------------------- *)
(* Three more restrictive notions of continuity for metric spaces.           *)
(* ------------------------------------------------------------------------- *)

let lipschitz_continuous_map = new_definition
 `lipschitz_continuous_map (m1,m2) f <=>
        IMAGE f (mspace m1) SUBSET mspace m2 /\
        ?B. !x y. x IN mspace m1 /\ y IN mspace m1
                  ==> mdist m2 (f x,f y) <= B * mdist m1 (x,y)`;;

let LIPSCHITZ_CONTINUOUS_MAP_POS = prove
 (`!m1 m2 f:A->B.
        lipschitz_continuous_map (m1,m2) f <=>
        IMAGE f (mspace m1) SUBSET mspace m2 /\
        ?B. &0 < B /\
            !x y. x IN mspace m1 /\ y IN mspace m1
                  ==> mdist m2 (f x,f y) <= B * mdist m1 (x,y)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[lipschitz_continuous_map] THEN
  AP_TERM_TAC THEN EQ_TAC THENL [ALL_TAC; MESON_TAC[]] THEN
  DISCH_THEN(X_CHOOSE_THEN `B:real` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `abs B + &1` THEN CONJ_TAC THENL [REAL_ARITH_TAC; ALL_TAC] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
  TRANS_TAC REAL_LE_TRANS `B * mdist m1 (x:A,y)` THEN
  ASM_SIMP_TAC[] THEN MATCH_MP_TAC REAL_LE_RMUL THEN
  ASM_SIMP_TAC[MDIST_POS_LE] THEN REAL_ARITH_TAC);;

let LIPSCHITZ_CONTINUOUS_MAP_EQ = prove
 (`!m1 m2 f g.
      (!x. x IN mspace m1 ==> f x = g x) /\ lipschitz_continuous_map (m1,m2) f
      ==> lipschitz_continuous_map (m1,m2) g`,
  REWRITE_TAC[lipschitz_continuous_map] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IMP_CONJ] THEN SIMP_TAC[]);;

let LIPSCHITZ_CONTINUOUS_MAP_FROM_SUBMETRIC = prove
 (`!m1 m2 s f:A->B.
        lipschitz_continuous_map (m1,m2) f
        ==> lipschitz_continuous_map (submetric m1 s,m2) f`,
  REWRITE_TAC[lipschitz_continuous_map; SUBMETRIC] THEN SET_TAC[]);;

let LIPSCHITZ_CONTINUOUS_MAP_FROM_SUBMETRIC_MONO = prove
 (`!m1 m2 f s t.
           lipschitz_continuous_map (submetric m1 t,m2) f /\ s SUBSET t
           ==> lipschitz_continuous_map (submetric m1 s,m2) f`,
  MESON_TAC[LIPSCHITZ_CONTINUOUS_MAP_FROM_SUBMETRIC; SUBMETRIC_SUBMETRIC;
            SET_RULE `s SUBSET t ==> t INTER s = s`]);;

let LIPSCHITZ_CONTINUOUS_MAP_INTO_SUBMETRIC = prove
 (`!m1 m2 s f:A->B.
        lipschitz_continuous_map (m1,submetric m2 s) f <=>
        IMAGE f (mspace m1) SUBSET s /\
        lipschitz_continuous_map (m1,m2) f`,
  REWRITE_TAC[lipschitz_continuous_map; SUBMETRIC] THEN SET_TAC[]);;

let LIPSCHITZ_CONTINUOUS_MAP_CONST = prove
 (`!m1:A metric m2:B metric c.
        lipschitz_continuous_map (m1,m2) (\x. c) <=>
        mspace m1 = {} \/ c IN mspace m2`,
  REPEAT GEN_TAC THEN REWRITE_TAC[lipschitz_continuous_map] THEN
  ASM_CASES_TAC `mspace m1:A->bool = {}` THEN
  ASM_REWRITE_TAC[IMAGE_CLAUSES; EMPTY_SUBSET; NOT_IN_EMPTY] THEN
  ASM_CASES_TAC `(c:B) IN mspace m2` THENL [ALL_TAC; ASM SET_TAC[]] THEN
  ASM_REWRITE_TAC[] THEN CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  EXISTS_TAC `&1` THEN ASM_SIMP_TAC[MDIST_REFL; MDIST_POS_LE; REAL_MUL_LID]);;

let LIPSCHITZ_CONTINUOUS_MAP_ID = prove
 (`!m1:A metric. lipschitz_continuous_map (m1,m1) (\x. x)`,
  REWRITE_TAC[lipschitz_continuous_map; IMAGE_ID; SUBSET_REFL] THEN
  GEN_TAC THEN EXISTS_TAC `&1` THEN REWRITE_TAC[REAL_LE_REFL; REAL_MUL_LID]);;

let LIPSCHITZ_CONTINUOUS_MAP_COMPOSE = prove
 (`!m1 m2 m3 f:A->B g:B->C.
      lipschitz_continuous_map (m1,m2) f /\ lipschitz_continuous_map (m2,m3) g
      ==> lipschitz_continuous_map (m1,m3) (g o f)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_POS] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IMP_CONJ; LEFT_IMP_EXISTS_THM] THEN
  DISCH_TAC THEN X_GEN_TAC `B:real` THEN REPEAT DISCH_TAC THEN
  X_GEN_TAC `C:real` THEN REPEAT DISCH_TAC THEN ASM_SIMP_TAC[o_THM] THEN
  EXISTS_TAC `C * B:real` THEN ASM_SIMP_TAC[REAL_LT_MUL] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN REPEAT DISCH_TAC THEN
  TRANS_TAC REAL_LE_TRANS `C * mdist m2 ((f:A->B) x,f y)` THEN
  ASM_SIMP_TAC[GSYM REAL_MUL_ASSOC; REAL_LE_LMUL_EQ]);;

let uniformly_continuous_map = new_definition
 `uniformly_continuous_map (m1,m2) f <=>
        IMAGE f (mspace m1) SUBSET mspace m2 /\
        !e. &0 < e
            ==> ?d. &0 < d /\
                    !x x'. x IN mspace m1 /\ x' IN mspace m1 /\
                           mdist m1 (x',x) < d
                           ==> mdist m2 (f x',f x) < e`;;

let UNIFORMLY_CONTINUOUS_MAP_SEQUENTIALLY,
    UNIFORMLY_CONTINUOUS_MAP_SEQUENTIALLY_ALT = (CONJ_PAIR o prove)
 (`(!m1 m2 f:A->B.
        uniformly_continuous_map (m1,m2) f <=>
        IMAGE f (mspace m1) SUBSET mspace m2 /\
        !x y. (!n. x n IN mspace m1) /\ (!n. y n IN mspace m1) /\
              limit euclideanreal (\n. mdist m1 (x n,y n)) (&0) sequentially
              ==> limit euclideanreal
                    (\n. mdist m2 (f(x n),f(y n))) (&0) sequentially) /\
   (!m1 m2 f:A->B.
        uniformly_continuous_map (m1,m2) f <=>
        IMAGE f (mspace m1) SUBSET mspace m2 /\
        !e x y. &0 < e /\ (!n. x n IN mspace m1) /\ (!n. y n IN mspace m1) /\
                limit euclideanreal (\n. mdist m1 (x n,y n)) (&0) sequentially
                ==> ?n. mdist m2 (f(x n),f(y n)) < e)`,
  REWRITE_TAC[AND_FORALL_THM] THEN REPEAT GEN_TAC THEN
  MATCH_MP_TAC(TAUT
   `(p ==> q) /\ (q ==> r) /\ (r ==> p)
    ==> (p <=> q) /\ (p <=> r)`) THEN
  REPEAT CONJ_TAC THENL
   [REWRITE_TAC[uniformly_continuous_map; SUBSET; FORALL_IN_IMAGE] THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
    REWRITE_TAC[LIMIT_METRIC; EVENTUALLY_SEQUENTIALLY] THEN
    REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV; IMP_CONJ] THEN
    ASM_SIMP_TAC[MDIST_POS_LE; REAL_ARITH `&0 <= x ==> abs(&0 - x) = x`] THEN
    ASM_MESON_TAC[];
    REWRITE_TAC[SUBSET; FORALL_IN_IMAGE] THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    MAP_EVERY X_GEN_TAC [`e:real`; `x:num->A`; `y:num->A`] THEN
    STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPECL [`x:num->A`; `y:num->A`]) THEN
    ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
    REWRITE_TAC[LIMIT_METRIC] THEN
    DISCH_THEN(MP_TAC o SPEC `e:real` o CONJUNCT2) THEN
    ASM_REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
    DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_HAPPENS) THEN
    REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY] THEN
    ASM_SIMP_TAC[MDIST_POS_LE; REAL_ARITH `&0 <= x ==> abs(&0 - x) = x`];
    REWRITE_TAC[uniformly_continuous_map; SUBSET; FORALL_IN_IMAGE] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `e:real` THEN
    ONCE_REWRITE_TAC[TAUT `p ==> q ==> r <=> q ==> ~r ==> ~p`] THEN
    DISCH_TAC THEN REWRITE_TAC[NOT_EXISTS_THM] THEN
    DISCH_THEN(MP_TAC o GEN `n:num` o SPEC `inv(&n + &1)`) THEN
    REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
    REWRITE_TAC[NOT_FORALL_THM; NOT_IMP; SKOLEM_THM] THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `x:num->A` THEN
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `y:num->A` THEN
    REWRITE_TAC[AND_FORALL_THM; REAL_NOT_LT] THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[NOT_EXISTS_THM] THEN CONJ_TAC THENL
     [ALL_TAC; ASM_MESON_TAC[MDIST_SYM; REAL_NOT_LT]] THEN
    MATCH_MP_TAC LIMIT_NULL_REAL_COMPARISON THEN
    EXISTS_TAC `\n. inv(&n + &1)` THEN
    REWRITE_TAC[EVENTUALLY_SEQUENTIALLY; LIMIT_NULL_REAL_HARMONIC_OFFSET] THEN
    EXISTS_TAC `0` THEN X_GEN_TAC `n:num` THEN DISCH_TAC THEN
    ASM_SIMP_TAC[REAL_ABS_INV; REAL_ARITH `abs(&n + &1) = &n + &1`;
      METRIC_ARITH `x IN mspace m /\ y IN mspace m
                    ==> abs(mdist m (x,y)) = mdist m (y,x)`] THEN
    ASM_SIMP_TAC[REAL_LT_IMP_LE]]);;

let UNIFORMLY_CONTINUOUS_MAP_EQ = prove
 (`!m1 m2 f g.
      (!x. x IN mspace m1 ==> f x = g x) /\ uniformly_continuous_map (m1,m2) f
      ==> uniformly_continuous_map (m1,m2) g`,
  REWRITE_TAC[uniformly_continuous_map] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; IMP_CONJ] THEN SIMP_TAC[]);;

let UNIFORMLY_CONTINUOUS_MAP_FROM_SUBMETRIC = prove
 (`!m1 m2 s f:A->B.
        uniformly_continuous_map (m1,m2) f
        ==> uniformly_continuous_map (submetric m1 s,m2) f`,
  REWRITE_TAC[uniformly_continuous_map; SUBMETRIC] THEN SET_TAC[]);;

let UNIFORMLY_CONTINUOUS_MAP_FROM_SUBMETRIC_MONO = prove
 (`!m1 m2 f s t.
           uniformly_continuous_map (submetric m1 t,m2) f /\ s SUBSET t
           ==> uniformly_continuous_map (submetric m1 s,m2) f`,
  MESON_TAC[UNIFORMLY_CONTINUOUS_MAP_FROM_SUBMETRIC; SUBMETRIC_SUBMETRIC;
            SET_RULE `s SUBSET t ==> t INTER s = s`]);;

let UNIFORMLY_CONTINUOUS_MAP_INTO_SUBMETRIC = prove
 (`!m1 m2 s f:A->B.
        uniformly_continuous_map (m1,submetric m2 s) f <=>
        IMAGE f (mspace m1) SUBSET s /\
        uniformly_continuous_map (m1,m2) f`,
  REWRITE_TAC[uniformly_continuous_map; SUBMETRIC] THEN SET_TAC[]);;

let UNIFORMLY_CONTINUOUS_MAP_CONST = prove
 (`!m1:A metric m2:B metric c.
        uniformly_continuous_map (m1,m2) (\x. c) <=>
        mspace m1 = {} \/ c IN mspace m2`,
  REPEAT GEN_TAC THEN REWRITE_TAC[uniformly_continuous_map] THEN
  ASM_CASES_TAC `mspace m1:A->bool = {}` THEN
  ASM_REWRITE_TAC[IMAGE_CLAUSES; EMPTY_SUBSET; NOT_IN_EMPTY] THENL
   [MESON_TAC[]; ALL_TAC] THEN
  ASM_CASES_TAC `(c:B) IN mspace m2` THENL [ALL_TAC; ASM SET_TAC[]] THEN
  ASM_REWRITE_TAC[] THEN CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  ASM_SIMP_TAC[MDIST_REFL] THEN MESON_TAC[]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_CONST = prove
 (`!m. uniformly_continuous_map (m,real_euclidean_metric) (\x:A. c)`,
  REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_CONST; REAL_EUCLIDEAN_METRIC; IN_UNIV]);;

let UNIFORMLY_CONTINUOUS_MAP_ID = prove
 (`!m1:A metric. uniformly_continuous_map (m1,m1) (\x. x)`,
  REWRITE_TAC[uniformly_continuous_map; IMAGE_ID; SUBSET_REFL] THEN
  MESON_TAC[]);;

let UNIFORMLY_CONTINUOUS_MAP_COMPOSE = prove
 (`!m1 m2 f:A->B g:B->C.
    uniformly_continuous_map (m1,m2) f /\ uniformly_continuous_map (m2,m3) g
    ==> uniformly_continuous_map (m1,m3) (g o f)`,
  REWRITE_TAC[uniformly_continuous_map; o_DEF; SUBSET; FORALL_IN_IMAGE] THEN
  REPEAT GEN_TAC THEN SIMP_TAC[CONJ_ASSOC] THEN
  DISCH_THEN(CONJUNCTS_THEN2 STRIP_ASSUME_TAC MP_TAC) THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `e:real` THEN ASM_MESON_TAC[]);;

let cauchy_continuous_map = new_definition
 `cauchy_continuous_map (m1,m2) f <=>
        !x. cauchy_in m1 x ==> cauchy_in m2 (f o x)`;;

let CAUCHY_CONTINUOUS_MAP_IMAGE = prove
 (`!m1 m2 f:A->B.
        cauchy_continuous_map (m1,m2) f
        ==> IMAGE f (mspace m1) SUBSET mspace m2`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[SUBSET; FORALL_IN_IMAGE] THEN
  X_GEN_TAC `a:A` THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `(\n. a):num->A` o
    REWRITE_RULE[cauchy_continuous_map]) THEN
  ASM_REWRITE_TAC[o_DEF; CAUCHY_IN_CONST]);;

let CAUCHY_CONTINUOUS_MAP_EQ = prove
 (`!m1 m2 f g.
      (!x. x IN mspace m1 ==> f x = g x) /\ cauchy_continuous_map (m1,m2) f
      ==> cauchy_continuous_map (m1,m2) g`,
  REWRITE_TAC[cauchy_continuous_map; cauchy_in; o_DEF; IMP_CONJ] THEN
  SIMP_TAC[]);;

let CAUCHY_CONTINUOUS_MAP_FROM_SUBMETRIC = prove
 (`!m1 m2 s f:A->B.
        cauchy_continuous_map (m1,m2) f
        ==> cauchy_continuous_map (submetric m1 s,m2) f`,
  SIMP_TAC[cauchy_continuous_map; CAUCHY_IN_SUBMETRIC]);;

let CAUCHY_CONTINUOUS_MAP_FROM_SUBMETRIC_MONO = prove
 (`!m1 m2 f s t.
           cauchy_continuous_map (submetric m1 t,m2) f /\ s SUBSET t
           ==> cauchy_continuous_map (submetric m1 s,m2) f`,
  MESON_TAC[CAUCHY_CONTINUOUS_MAP_FROM_SUBMETRIC; SUBMETRIC_SUBMETRIC;
            SET_RULE `s SUBSET t ==> t INTER s = s`]);;

let CAUCHY_CONTINUOUS_MAP_INTO_SUBMETRIC = prove
 (`!m1 m2 s f:A->B.
        cauchy_continuous_map (m1,submetric m2 s) f <=>
        IMAGE f (mspace m1) SUBSET s /\
        cauchy_continuous_map (m1,m2) f`,
  REPEAT GEN_TAC THEN EQ_TAC THEN STRIP_TAC THENL
   [CONJ_TAC THENL
     [FIRST_ASSUM(MP_TAC o MATCH_MP CAUCHY_CONTINUOUS_MAP_IMAGE) THEN
      REWRITE_TAC[SUBMETRIC] THEN SET_TAC[];
      POP_ASSUM MP_TAC THEN
      SIMP_TAC[cauchy_continuous_map; CAUCHY_IN_SUBMETRIC; o_THM]];
    REPEAT(POP_ASSUM MP_TAC) THEN
    SIMP_TAC[cauchy_continuous_map; CAUCHY_IN_SUBMETRIC; o_THM] THEN
    REWRITE_TAC[cauchy_in] THEN SET_TAC[]]);;

let CAUCHY_CONTINUOUS_MAP_CONST = prove
 (`!m1:A metric m2:B metric c.
        cauchy_continuous_map (m1,m2) (\x. c) <=>
        mspace m1 = {} \/ c IN mspace m2`,
  REPEAT GEN_TAC THEN REWRITE_TAC[cauchy_continuous_map] THEN
  REWRITE_TAC[o_DEF; CAUCHY_IN_CONST] THEN
  ASM_CASES_TAC `(c:B) IN mspace m2` THEN ASM_REWRITE_TAC[] THEN
  EQ_TAC THENL [ALL_TAC; SIMP_TAC[cauchy_in; NOT_IN_EMPTY]] THEN
  GEN_REWRITE_TAC I [GSYM CONTRAPOS_THM] THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `a:A` THEN DISCH_TAC THEN
  DISCH_THEN(MP_TAC o SPEC `(\n. a):num->A`) THEN
  ASM_REWRITE_TAC[CAUCHY_IN_CONST]);;

let CAUCHY_CONTINUOUS_MAP_REAL_CONST = prove
 (`!m. cauchy_continuous_map (m,real_euclidean_metric) (\x:A. c)`,
  REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_CONST; REAL_EUCLIDEAN_METRIC; IN_UNIV]);;

let CAUCHY_CONTINUOUS_MAP_ID = prove
 (`!m1:A metric. cauchy_continuous_map (m1,m1) (\x. x)`,
  REWRITE_TAC[cauchy_continuous_map; o_DEF; ETA_AX]);;

let CAUCHY_CONTINUOUS_MAP_COMPOSE = prove
 (`!m1 m2 f:A->B g:B->C.
    cauchy_continuous_map (m1,m2) f /\ cauchy_continuous_map (m2,m3) g
    ==> cauchy_continuous_map (m1,m3) (g o f)`,
  REWRITE_TAC[cauchy_continuous_map; o_DEF; SUBSET; FORALL_IN_IMAGE] THEN
  REPEAT GEN_TAC THEN SIMP_TAC[CONJ_ASSOC] THEN
  DISCH_THEN(CONJUNCTS_THEN2 STRIP_ASSUME_TAC MP_TAC) THEN
  MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `e:real` THEN ASM_MESON_TAC[]);;

let LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        lipschitz_continuous_map (m1,m2) f
        ==> uniformly_continuous_map (m1,m2) f`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_POS; uniformly_continuous_map] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
   (X_CHOOSE_THEN `B:real` STRIP_ASSUME_TAC)) THEN
  ASM_REWRITE_TAC[] THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  EXISTS_TAC `e / B:real` THEN
  ASM_SIMP_TAC[REAL_LT_RDIV_EQ; REAL_MUL_LZERO] THEN
  ASM_MESON_TAC[REAL_LET_TRANS; REAL_MUL_SYM]);;

let UNIFORMLY_IMP_CAUCHY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        uniformly_continuous_map (m1,m2) f
        ==> cauchy_continuous_map (m1,m2) f`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[uniformly_continuous_map; cauchy_continuous_map] THEN
  STRIP_TAC THEN X_GEN_TAC `x:num->A` THEN REWRITE_TAC[cauchy_in] THEN
  STRIP_TAC THEN REWRITE_TAC[o_THM] THEN ASM SET_TAC[]);;

let LOCALLY_CAUCHY_CONTINUOUS_MAP = prove
 (`!m1 m2 e f:A->B.
        &0 < e /\
        (!x. x IN mspace m1
             ==> cauchy_continuous_map (submetric m1 (mball m1 (x,e)),m2) f)
        ==> cauchy_continuous_map (m1,m2) f`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[cauchy_continuous_map] THEN
  X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [cauchy_in]) THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `e:real`)) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `M:num` THEN STRIP_TAC THEN
  MATCH_MP_TAC CAUCHY_IN_OFFSET THEN EXISTS_TAC `M:num` THEN CONJ_TAC THENL
   [X_GEN_TAC `n:num` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `(x:num->A) n`) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(MP_TAC o MATCH_MP CAUCHY_CONTINUOUS_MAP_IMAGE) THEN
    ASM_SIMP_TAC[SUBSET; FORALL_IN_IMAGE; SUBMETRIC; SUBMETRIC; o_THM;
                 IN_INTER; CENTRE_IN_MBALL];
    FIRST_X_ASSUM(MP_TAC o SPEC `(x:num->A) M`) THEN
    ASM_REWRITE_TAC[cauchy_continuous_map; o_DEF] THEN
    DISCH_THEN MATCH_MP_TAC THEN
    ASM_REWRITE_TAC[CAUCHY_IN_SUBMETRIC; IN_MBALL] THEN
    ASM_SIMP_TAC[LE_ADD; LE_REFL] THEN
    GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
    MATCH_MP_TAC CAUCHY_IN_SUBSEQUENCE THEN
    ASM_REWRITE_TAC[LT_ADD_LCANCEL]]);;

let CAUCHY_CONTINUOUS_IMP_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        cauchy_continuous_map (m1,m2) f
        ==> continuous_map (mtopology m1,mtopology m2) f`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[CONTINUOUS_MAP_ATPOINTOF] THEN
  X_GEN_TAC `a:A` THEN REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN DISCH_TAC THEN
  REWRITE_TAC[LIMIT_ATPOINTOF_SEQUENTIALLY] THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP CAUCHY_CONTINUOUS_MAP_IMAGE) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  X_GEN_TAC `x:num->A` THEN REWRITE_TAC[IN_DELETE; FORALL_AND_THM] THEN
  STRIP_TAC THEN FIRST_X_ASSUM(MP_TAC o SPEC
   `\n. if EVEN n then x(n DIV 2) else a:A` o
   REWRITE_RULE[cauchy_continuous_map]) THEN
  ASM_SIMP_TAC[o_DEF; COND_RAND; CAUCHY_IN_INTERLEAVING]);;

let UNIFORMLY_CONTINUOUS_IMP_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        uniformly_continuous_map (m1,m2) f
        ==> continuous_map (mtopology m1,mtopology m2) f`,
  MESON_TAC[UNIFORMLY_IMP_CAUCHY_CONTINUOUS_MAP;
            CAUCHY_CONTINUOUS_IMP_CONTINUOUS_MAP]);;

let LIPSCHITZ_CONTINUOUS_IMP_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        lipschitz_continuous_map(m1,m2) f
        ==> continuous_map (mtopology m1,mtopology m2) f`,
  SIMP_TAC[UNIFORMLY_CONTINUOUS_IMP_CONTINUOUS_MAP;
           LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP]);;

let LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        lipschitz_continuous_map(m1,m2) f
        ==> cauchy_continuous_map(m1,m2) f`,
  SIMP_TAC[LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP;
           UNIFORMLY_IMP_CAUCHY_CONTINUOUS_MAP]);;

let CONTINUOUS_IMP_CAUCHY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        mcomplete m1 /\
        continuous_map (mtopology m1,mtopology m2) f
        ==> cauchy_continuous_map (m1,m2) f`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[cauchy_continuous_map] THEN
  X_GEN_TAC `x:num->A` THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `x:num->A` o REWRITE_RULE[mcomplete]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN X_GEN_TAC `y:A` THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP
   (REWRITE_RULE[IMP_CONJ] (ISPEC `sequentially` CONTINUOUS_MAP_LIMIT))) THEN
  DISCH_THEN(MP_TAC o SPECL [`x:num->A`; `y:A`]) THEN
  ASM_REWRITE_TAC[] THEN
  DISCH_THEN(MATCH_MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
        CONVERGENT_IMP_CAUCHY_IN)) THEN
  RULE_ASSUM_TAC(REWRITE_RULE
   [continuous_map; TOPSPACE_MTOPOLOGY; cauchy_in]) THEN
  REWRITE_TAC[o_DEF] THEN ASM SET_TAC[]);;

let CAUCHY_IMP_UNIFORMLY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        totally_bounded_in m1 (mspace m1) /\
        cauchy_continuous_map (m1,m2) f
        ==> uniformly_continuous_map (m1,m2) f`,
  REPEAT STRIP_TAC THEN
  REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_SEQUENTIALLY_ALT] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP CAUCHY_CONTINUOUS_MAP_IMAGE) THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE] THEN
  DISCH_TAC THEN ASM_REWRITE_TAC[] THEN
  MAP_EVERY X_GEN_TAC [`e:real`; `x:num->A`; `y:num->A`] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `x:num->A` o CONJUNCT2 o
   REWRITE_RULE[TOTALLY_BOUNDED_IN_SEQUENTIALLY]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `r1:num->num` THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `(y:num->A) o (r1:num->num)` o CONJUNCT2 o
   REWRITE_RULE[TOTALLY_BOUNDED_IN_SEQUENTIALLY]) THEN
  ASM_REWRITE_TAC[o_THM; GSYM o_ASSOC; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `r2:num->num` THEN STRIP_TAC THEN
  ABBREV_TAC `r = (r1:num->num) o (r2:num->num)` THEN
  SUBGOAL_THEN `!m n. m < n ==> (r:num->num) m < r n` ASSUME_TAC THENL
   [EXPAND_TAC "r" THEN REWRITE_TAC[o_DEF] THEN ASM_MESON_TAC[]; ALL_TAC] THEN
  FIRST_ASSUM(MP_TAC o
   SPEC `\n. if EVEN n then (x o r) (n DIV 2):A
             else (y o (r:num->num)) (n DIV 2)` o
   REWRITE_RULE[cauchy_continuous_map]) THEN
  ASM_REWRITE_TAC[CAUCHY_IN_INTERLEAVING_GEN; ETA_AX] THEN ANTS_TAC THENL
   [EXPAND_TAC "r" THEN REWRITE_TAC[o_ASSOC] THEN
    ASM_SIMP_TAC[CAUCHY_IN_SUBSEQUENCE] THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `r:num->num` o
      MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT] LIMIT_SUBSEQUENCE)) THEN
    ASM_REWRITE_TAC[GSYM o_ASSOC] THEN REWRITE_TAC[o_DEF];
    ONCE_REWRITE_TAC[o_DEF] THEN
    REWRITE_TAC[COND_RAND; CAUCHY_IN_INTERLEAVING_GEN] THEN
    DISCH_THEN(MP_TAC o CONJUNCT2 o CONJUNCT2) THEN
    REWRITE_TAC[LIMIT_NULL_REAL] THEN
    DISCH_THEN(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(MP_TAC o MATCH_MP EVENTUALLY_HAPPENS) THEN
    REWRITE_TAC[o_DEF; TRIVIAL_LIMIT_SEQUENTIALLY] THEN
    ASM_SIMP_TAC[real_abs; MDIST_POS_LE] THEN MESON_TAC[]]);;

let CONTINUOUS_IMP_UNIFORMLY_CONTINUOUS_MAP = prove
(`!m1 m2 f:A->B.
        compact_space (mtopology m1) /\
        continuous_map (mtopology m1,mtopology m2) f
        ==> uniformly_continuous_map (m1,m2) f`,
  REWRITE_TAC[COMPACT_SPACE_EQ_MCOMPLETE_TOTALLY_BOUNDED_IN] THEN
  REPEAT STRIP_TAC THEN
  MATCH_MP_TAC CAUCHY_IMP_UNIFORMLY_CONTINUOUS_MAP THEN
  ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC CONTINUOUS_IMP_CAUCHY_CONTINUOUS_MAP THEN
  ASM_REWRITE_TAC[]);;

let CONTINUOUS_EQ_CAUCHY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        mcomplete m1
        ==> (continuous_map (mtopology m1,mtopology m2) f <=>
             cauchy_continuous_map (m1,m2) f)`,
  MESON_TAC[CONTINUOUS_IMP_CAUCHY_CONTINUOUS_MAP;
            CAUCHY_CONTINUOUS_IMP_CONTINUOUS_MAP]);;

let CONTINUOUS_EQ_UNIFORMLY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        compact_space (mtopology m1)
        ==> (continuous_map (mtopology m1,mtopology m2) f <=>
             uniformly_continuous_map (m1,m2) f)`,
  MESON_TAC[CONTINUOUS_IMP_UNIFORMLY_CONTINUOUS_MAP;
            UNIFORMLY_CONTINUOUS_IMP_CONTINUOUS_MAP]);;

let CAUCHY_EQ_UNIFORMLY_CONTINUOUS_MAP = prove
 (`!m1 m2 f:A->B.
        totally_bounded_in m1 (mspace m1)
        ==> (cauchy_continuous_map (m1,m2) f <=>
             uniformly_continuous_map (m1,m2) f)`,
  MESON_TAC[CAUCHY_IMP_UNIFORMLY_CONTINUOUS_MAP;
            UNIFORMLY_IMP_CAUCHY_CONTINUOUS_MAP]);;

let LIPSCHITZ_CONTINUOUS_MAP_PROJECTIONS = prove
 (`(!m1:A metric m2:B metric.
        lipschitz_continuous_map (prod_metric m1 m2,m1) FST) /\
   (!m1:A metric m2:B metric.
        lipschitz_continuous_map (prod_metric m1 m2,m2) SND)`,
  CONJ_TAC THEN REPEAT GEN_TAC THEN REWRITE_TAC[lipschitz_continuous_map] THEN
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; CONJUNCT1 PROD_METRIC] THEN
  SIMP_TAC[FORALL_PAIR_THM; IN_CROSS] THEN EXISTS_TAC `&1` THEN
  REWRITE_TAC[REAL_MUL_LID; COMPONENT_LE_PROD_METRIC]);;

let LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE = prove
 (`!m m1 m2 (f:A->B#C).
        lipschitz_continuous_map(m,prod_metric m1 m2) f <=>
        lipschitz_continuous_map(m,m1) (FST o f) /\
        lipschitz_continuous_map(m,m2) (SND o f)`,
  REWRITE_TAC[FORALL_AND_THM; TAUT `(p <=> q) <=> (p ==> q) /\ (q ==> p)`] THEN
  CONJ_TAC THENL
   [MESON_TAC[LIPSCHITZ_CONTINUOUS_MAP_COMPOSE;
              LIPSCHITZ_CONTINUOUS_MAP_PROJECTIONS];
    REPLICATE_TAC 3 GEN_TAC THEN
    REWRITE_TAC[FORALL_PAIR_FUN_THM; o_DEF; ETA_AX] THEN
    MAP_EVERY X_GEN_TAC [`x:A->B`; `y:A->C`] THEN
    REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_POS] THEN
    REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; CONJUNCT1 PROD_METRIC] THEN
    DISCH_THEN(CONJUNCTS_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    ASM_SIMP_TAC[IN_CROSS; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `B:real` THEN STRIP_TAC THEN
    X_GEN_TAC `C:real` THEN STRIP_TAC THEN EXISTS_TAC `B + C:real` THEN
    ASM_SIMP_TAC[REAL_LT_ADD] THEN REPEAT STRIP_TAC THEN
    W(MP_TAC o PART_MATCH (lhand o rand) PROD_METRIC_LE_COMPONENTS o
      lhand o snd) THEN
    ASM_SIMP_TAC[] THEN MATCH_MP_TAC(REAL_ARITH
     `y <= c * m /\ z <= b * m ==> x <= y + z ==> x <= (b + c) * m`) THEN
    ASM_SIMP_TAC[]]);;

let UNIFORMLY_CONTINUOUS_MAP_PAIRWISE = prove
 (`!m m1 m2 (f:A->B#C).
        uniformly_continuous_map(m,prod_metric m1 m2) f <=>
        uniformly_continuous_map(m,m1) (FST o f) /\
        uniformly_continuous_map(m,m2) (SND o f)`,
  REWRITE_TAC[FORALL_AND_THM; TAUT `(p <=> q) <=> (p ==> q) /\ (q ==> p)`] THEN
  CONJ_TAC THENL
   [MESON_TAC[UNIFORMLY_CONTINUOUS_MAP_COMPOSE;
              LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP;
              LIPSCHITZ_CONTINUOUS_MAP_PROJECTIONS];
    REPLICATE_TAC 3 GEN_TAC THEN
    REWRITE_TAC[FORALL_PAIR_FUN_THM; o_DEF; ETA_AX] THEN
    MAP_EVERY X_GEN_TAC [`x:A->B`; `y:A->C`] THEN
    REWRITE_TAC[uniformly_continuous_map] THEN
    REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; CONJUNCT1 PROD_METRIC] THEN
    DISCH_THEN(CONJUNCTS_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    ASM_SIMP_TAC[IN_CROSS; IMP_IMP] THEN DISCH_TAC THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(CONJUNCTS_THEN(MP_TAC o SPEC `e / &2`)) THEN
    ASM_REWRITE_TAC[REAL_HALF; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `d1:real` THEN STRIP_TAC THEN
    X_GEN_TAC `d2:real` THEN STRIP_TAC THEN
    EXISTS_TAC `min d1 d2:real` THEN ASM_REWRITE_TAC[REAL_LT_MIN] THEN
    REPEAT STRIP_TAC THEN
    W(MP_TAC o PART_MATCH (lhand o rand) PROD_METRIC_LE_COMPONENTS o
      lhand o snd) THEN
    ASM_SIMP_TAC[] THEN MATCH_MP_TAC(REAL_ARITH
     `x < e / &2 /\ y < e / &2 ==> z <= x + y ==> z < e`) THEN
    ASM_SIMP_TAC[]]);;

let CAUCHY_CONTINUOUS_MAP_PAIRWISE = prove
 (`!m m1 m2 (f:A->B#C).
        cauchy_continuous_map(m,prod_metric m1 m2) f <=>
        cauchy_continuous_map(m,m1) (FST o f) /\
        cauchy_continuous_map(m,m2) (SND o f)`,
  REWRITE_TAC[cauchy_continuous_map; CAUCHY_IN_PROD_METRIC; o_ASSOC] THEN
  MESON_TAC[]);;

let LIPSCHITZ_CONTINUOUS_MAP_PAIRED = prove
 (`!m m1 m2 (f:A->B) (g:A->C).
        lipschitz_continuous_map (m,prod_metric m1 m2) (\x. f x,g x) <=>
        lipschitz_continuous_map(m,m1) f /\ lipschitz_continuous_map(m,m2) g`,
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let UNIFORMLY_CONTINUOUS_MAP_PAIRED = prove
 (`!m m1 m2 (f:A->B) (g:A->C).
        uniformly_continuous_map (m,prod_metric m1 m2) (\x. f x,g x) <=>
        uniformly_continuous_map(m,m1) f /\ uniformly_continuous_map(m,m2) g`,
  REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let CAUCHY_CONTINUOUS_MAP_PAIRED = prove
 (`!m m1 m2 (f:A->B) (g:A->C).
        cauchy_continuous_map (m,prod_metric m1 m2) (\x. f x,g x) <=>
        cauchy_continuous_map(m,m1) f /\ cauchy_continuous_map(m,m2) g`,
  REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let MBOUNDED_LIPSCHITZ_CONTINUOUS_IMAGE = prove
 (`!m1 m2 (f:A->B) s.
        lipschitz_continuous_map (m1,m2) f /\ mbounded m1 s
        ==> mbounded m2 (IMAGE f s)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[MBOUNDED_ALT_POS; LIPSCHITZ_CONTINUOUS_MAP_POS] THEN
  REWRITE_TAC[IMP_CONJ; LEFT_IMP_EXISTS_THM] THEN DISCH_TAC THEN
  X_GEN_TAC `B:real` THEN DISCH_TAC THEN REWRITE_TAC[IMP_IMP] THEN
  STRIP_TAC THEN X_GEN_TAC `C:real` THEN STRIP_TAC THEN
  CONJ_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[FORALL_IN_IMAGE_2]] THEN
  EXISTS_TAC `B * C:real` THEN ASM_SIMP_TAC[REAL_LT_MUL] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
  TRANS_TAC REAL_LE_TRANS `B * mdist m1 (x:A,y)` THEN
  ASM_SIMP_TAC[REAL_LE_LMUL_EQ] THEN ASM SET_TAC[]);;

let TOTALLY_BOUNDED_IN_CAUCHY_CONTINUOUS_IMAGE = prove
 (`!m1 m2 (f:A->B) s.
        cauchy_continuous_map (m1,m2) f /\ totally_bounded_in m1 s
        ==> totally_bounded_in m2 (IMAGE f s)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[TOTALLY_BOUNDED_IN_SEQUENTIALLY] THEN STRIP_TAC THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP CAUCHY_CONTINUOUS_MAP_IMAGE) THEN
  CONJ_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[IN_IMAGE]] THEN
  X_GEN_TAC `y:num->B` THEN REWRITE_TAC[SKOLEM_THM; FORALL_AND_THM]THEN
  DISCH_THEN(X_CHOOSE_THEN `x:num->A` STRIP_ASSUME_TAC) THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:num->A`) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `r:num->num` THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [cauchy_continuous_map]) THEN
  DISCH_THEN(MP_TAC o SPEC `(x:num->A) o (r:num->num)`) THEN
  ASM_REWRITE_TAC[] THEN ASM_REWRITE_TAC[o_DEF]);;

let LIPSCHITZ_COEFFICIENT_POS = prove
 (`!m m' f:A->B k.
     (!x. x IN mspace m ==> f x IN mspace m') /\
     (!x y. x IN mspace m /\ y IN mspace m
            ==> mdist m' (f x,f y) <= k * mdist m (x,y)) /\
     (?x y. x IN mspace m /\ y IN mspace m /\ ~(f x = f y))
     ==> &0 < k`,
  REPEAT GEN_TAC THEN INTRO_TAC "f k (@x y. x y fneq)" THEN
  CLAIM_TAC "neq" `~(x:A = y)` THENL [HYP MESON_TAC "fneq" []; ALL_TAC] THEN
  TRANS_TAC REAL_LTE_TRANS `mdist m' (f x:B,f y) / mdist m (x:A,y)` THEN
  ASM_SIMP_TAC[REAL_LT_DIV; MDIST_POS_LT; REAL_LE_LDIV_EQ]);;

let LIPSCHITZ_CONTINUOUS_MAP_METRIC = prove
 (`!m:A metric.
        lipschitz_continuous_map
          (prod_metric m m,real_euclidean_metric)
          (mdist m)`,
  SIMP_TAC[lipschitz_continuous_map; CONJUNCT1 PROD_METRIC;
           REAL_EUCLIDEAN_METRIC] THEN
  GEN_TAC THEN REWRITE_TAC[FORALL_PAIR_THM; IN_CROSS; SUBSET_UNIV] THEN
  EXISTS_TAC `&2` THEN
  MAP_EVERY X_GEN_TAC [`x1:A`; `y1:A`; `x2:A`; `y2:A`] THEN STRIP_TAC THEN
  W(MP_TAC o PART_MATCH (rand o rand) COMPONENT_LE_PROD_METRIC o
    rand o rand o snd) THEN
  MATCH_MP_TAC(REAL_ARITH
   `x <= y + z ==> y <= p /\ z <= p ==> x <= &2 * p`) THEN
  REWRITE_TAC[REAL_ABS_BOUNDS] THEN CONJ_TAC THEN
  REPEAT(POP_ASSUM MP_TAC) THEN CONV_TAC METRIC_ARITH);;

let LIPSCHITZ_CONTINUOUS_MAP_MDIST = prove
 (`!m m' (f:A->B) g.
      lipschitz_continuous_map (m,m') f /\
      lipschitz_continuous_map (m,m') g
      ==> lipschitz_continuous_map (m,real_euclidean_metric)
             (\x. mdist m' (f x,g x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric (m':B metric) m'` THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_METRIC] THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRED]);;

let UNIFORMLY_CONTINUOUS_MAP_MDIST = prove
 (`!m m' (f:A->B) g.
      uniformly_continuous_map (m,m') f /\
      uniformly_continuous_map (m,m') g
      ==> uniformly_continuous_map (m,real_euclidean_metric)
             (\x. mdist m' (f x,g x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric (m':B metric) m'` THEN
  SIMP_TAC[LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP;
           LIPSCHITZ_CONTINUOUS_MAP_METRIC] THEN
  ASM_REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRED]);;

let CAUCHY_CONTINUOUS_MAP_MDIST = prove
 (`!m m' (f:A->B) g.
      cauchy_continuous_map (m,m') f /\
      cauchy_continuous_map (m,m') g
      ==> cauchy_continuous_map (m,real_euclidean_metric)
             (\x. mdist m' (f x,g x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric (m':B metric) m'` THEN
  SIMP_TAC[LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP;
           LIPSCHITZ_CONTINUOUS_MAP_METRIC] THEN
  ASM_REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_PAIRED]);;

let CONTINUOUS_MAP_METRIC = prove
 (`!m:A metric.
        continuous_map (prod_topology (mtopology m) (mtopology m),
                        euclideanreal)
                       (mdist m)`,
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC;
              GSYM MTOPOLOGY_PROD_METRIC] THEN
  GEN_TAC THEN MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_IMP_CONTINUOUS_MAP THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_METRIC]);;

let CONTINUOUS_MAP_MDIST_ALT = prove
 (`!m f:A->B#B.
        continuous_map (top,prod_topology (mtopology m) (mtopology m)) f
        ==> continuous_map (top,euclideanreal) (\x. mdist m (f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  ASM_MESON_TAC[CONTINUOUS_MAP_METRIC; CONTINUOUS_MAP_COMPOSE]);;

let CONTINUOUS_MAP_MDIST = prove
 (`!top m f g:A->B.
        continuous_map (top,mtopology m) f /\
        continuous_map (top,mtopology m) g
        ==> continuous_map (top,euclideanreal) (\x. mdist m (f x,g x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_topology (mtopology m:B topology) (mtopology m)` THEN
  REWRITE_TAC[CONTINUOUS_MAP_METRIC; CONTINUOUS_MAP_PAIRWISE] THEN
  ASM_REWRITE_TAC[o_DEF; ETA_AX]);;

let CONTINUOUS_ON_MDIST = prove
 (`!m a. a:A IN mspace m
         ==> continuous_map (mtopology m,euclideanreal) (\x. mdist m (a,x))`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC CONTINUOUS_MAP_MDIST THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_ID; CONTINUOUS_MAP_CONST] THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_LEFT_MULTIPLICATION = prove
 (`!c. lipschitz_continuous_map(real_euclidean_metric,real_euclidean_metric)
         (\x. c * x)`,
  GEN_TAC THEN REWRITE_TAC[lipschitz_continuous_map] THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV; SUBSET_UNIV] THEN
  REWRITE_TAC[GSYM REAL_SUB_LDISTRIB; REAL_ABS_MUL] THEN
  MESON_TAC[REAL_LE_REFL]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_RIGHT_MULTIPLICATION = prove
 (`!c. lipschitz_continuous_map(real_euclidean_metric,real_euclidean_metric)
         (\x. x * c)`,
  ONCE_REWRITE_TAC[REAL_MUL_SYM] THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_LEFT_MULTIPLICATION]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_NEGATION = prove
 (`lipschitz_continuous_map(real_euclidean_metric,real_euclidean_metric) (--)`,
  GEN_REWRITE_TAC RAND_CONV [GSYM ETA_AX] THEN
  ONCE_REWRITE_TAC[REAL_NEG_MINUS1] THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_LEFT_MULTIPLICATION]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_ABSOLUTE_VALUE = prove
 (`lipschitz_continuous_map(real_euclidean_metric,real_euclidean_metric) abs`,
  SIMP_TAC[lipschitz_continuous_map; REAL_EUCLIDEAN_METRIC; SUBSET_UNIV] THEN
  EXISTS_TAC `&1` THEN REAL_ARITH_TAC);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_ADDITION = prove
 (`lipschitz_continuous_map
    (prod_metric real_euclidean_metric real_euclidean_metric,
     real_euclidean_metric)
    (\(x,y). x + y)`,
  REWRITE_TAC[lipschitz_continuous_map; CONJUNCT1 PROD_METRIC] THEN
  REWRITE_TAC[FORALL_PAIR_THM; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_UNIV; SUBSET_UNIV; IN_CROSS] THEN
  EXISTS_TAC `&2` THEN REPEAT GEN_TAC THEN
  REWRITE_TAC[REAL_ARITH `x <= &2 * y <=> x / &2 <= y`] THEN
  W(MP_TAC o PART_MATCH (rand o rand)
        COMPONENT_LE_PROD_METRIC o rand o snd) THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC] THEN REAL_ARITH_TAC);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_SUBTRACTION = prove
 (`lipschitz_continuous_map
    (prod_metric real_euclidean_metric real_euclidean_metric,
     real_euclidean_metric)
    (\(x,y). x - y)`,
  REWRITE_TAC[lipschitz_continuous_map; CONJUNCT1 PROD_METRIC] THEN
  REWRITE_TAC[FORALL_PAIR_THM; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_UNIV; SUBSET_UNIV; IN_CROSS] THEN
  EXISTS_TAC `&2` THEN REPEAT GEN_TAC THEN
  REWRITE_TAC[REAL_ARITH `x <= &2 * y <=> x / &2 <= y`] THEN
  W(MP_TAC o PART_MATCH (rand o rand)
        COMPONENT_LE_PROD_METRIC o rand o snd) THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC] THEN REAL_ARITH_TAC);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_MAXIMUM = prove
 (`lipschitz_continuous_map
    (prod_metric real_euclidean_metric real_euclidean_metric,
     real_euclidean_metric)
    (\(x,y). max x y)`,
  REWRITE_TAC[lipschitz_continuous_map; CONJUNCT1 PROD_METRIC] THEN
  REWRITE_TAC[FORALL_PAIR_THM; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_UNIV; SUBSET_UNIV; IN_CROSS] THEN
  EXISTS_TAC `&1` THEN REPEAT GEN_TAC THEN REWRITE_TAC[REAL_MUL_LID] THEN
  W(MP_TAC o PART_MATCH (rand o rand)
        COMPONENT_LE_PROD_METRIC o rand o snd) THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC] THEN REAL_ARITH_TAC);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_MINIMUM = prove
 (`lipschitz_continuous_map
    (prod_metric real_euclidean_metric real_euclidean_metric,
     real_euclidean_metric)
    (\(x,y). min x y)`,
  REWRITE_TAC[lipschitz_continuous_map; CONJUNCT1 PROD_METRIC] THEN
  REWRITE_TAC[FORALL_PAIR_THM; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_UNIV; SUBSET_UNIV; IN_CROSS] THEN
  EXISTS_TAC `&1` THEN REPEAT GEN_TAC THEN REWRITE_TAC[REAL_MUL_LID] THEN
  W(MP_TAC o PART_MATCH (rand o rand)
        COMPONENT_LE_PROD_METRIC o rand o snd) THEN
  REWRITE_TAC[REAL_EUCLIDEAN_METRIC] THEN REAL_ARITH_TAC);;

let LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_MULTIPLICATION = prove
 (`!s. mbounded (prod_metric real_euclidean_metric real_euclidean_metric) s
       ==> lipschitz_continuous_map
            (submetric
              (prod_metric real_euclidean_metric real_euclidean_metric) s,
             real_euclidean_metric)
            (\(x,y). x * y)`,
  GEN_TAC THEN REWRITE_TAC[MBOUNDED_PROD_METRIC] THEN
  REWRITE_TAC[MBOUNDED_REAL_EUCLIDEAN_METRIC; REAL_BOUNDED_POS] THEN
  REWRITE_TAC[IMP_CONJ; FORALL_IN_IMAGE; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `B:real` THEN REWRITE_TAC[FORALL_PAIR_THM] THEN
  REPEAT DISCH_TAC THEN X_GEN_TAC `C:real` THEN REPEAT DISCH_TAC THEN
  SIMP_TAC[lipschitz_continuous_map; REAL_EUCLIDEAN_METRIC; SUBSET_UNIV] THEN
  EXISTS_TAC `B + C:real` THEN
  REWRITE_TAC[FORALL_PAIR_THM; SUBMETRIC; IN_INTER; CONJUNCT1 PROD_METRIC] THEN
  MAP_EVERY X_GEN_TAC [`x1:real`; `y1:real`; `x2:real`; `y2:real`] THEN
  REWRITE_TAC[IN_CROSS; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN STRIP_TAC THEN
  TRANS_TAC REAL_LE_TRANS
   `B * mdist real_euclidean_metric (y1,y2) +
    C * mdist real_euclidean_metric (x1,x2)` THEN
  CONJ_TAC THENL
   [REWRITE_TAC[REAL_EUCLIDEAN_METRIC];
    MATCH_MP_TAC(REAL_ARITH
     `x <= b * d /\ y <= c * d ==> x + y <= (b + c) * d`) THEN
    ASM_SIMP_TAC[REAL_LE_LMUL_EQ; COMPONENT_LE_PROD_METRIC]] THEN
  ONCE_REWRITE_TAC[REAL_ARITH
   `x2 * y2 - x1 * y1:real = x2 * (y2 - y1) + y1 * (x2 - x1)`] THEN
  MATCH_MP_TAC(REAL_ARITH
   `abs x <= a /\ abs y <= b ==> abs(x + y) <= a + b`) THEN
  REWRITE_TAC[REAL_ABS_MUL] THEN CONJ_TAC THEN
  MATCH_MP_TAC REAL_LE_RMUL THEN REWRITE_TAC[REAL_ABS_POS] THEN
  ASM_MESON_TAC[]);;

let CAUCHY_CONTINUOUS_MAP_REAL_MULTIPLICATION = prove
 (`cauchy_continuous_map
    (prod_metric real_euclidean_metric real_euclidean_metric,
     real_euclidean_metric)
    (\(x,y). x * y)`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC LOCALLY_CAUCHY_CONTINUOUS_MAP THEN
  EXISTS_TAC `&1` THEN REWRITE_TAC[REAL_LT_01] THEN
  GEN_TAC THEN DISCH_TAC THEN
  MATCH_MP_TAC LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP THEN
  MATCH_MP_TAC LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_MULTIPLICATION THEN
  REWRITE_TAC[MBOUNDED_MBALL]);;

let LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_INVERSION = prove
 (`!s. ~(&0 IN euclideanreal closure_of s)
       ==> lipschitz_continuous_map
             (submetric real_euclidean_metric s,real_euclidean_metric)
             inv`,
  X_GEN_TAC `s:real->bool` THEN
  REWRITE_TAC[CLOSURE_OF_INTERIOR_OF; IN_DIFF; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[IN_UNIV; GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_INTERIOR_OF_MBALL] THEN
  REWRITE_TAC[SUBSET; IN_MBALL; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  REWRITE_TAC[REAL_SUB_RZERO; REAL_NOT_LT; SET_RULE
   `(!x. P x ==> x IN UNIV DIFF s) <=> (!x. x IN s ==> ~P x)`] THEN
  DISCH_THEN(X_CHOOSE_THEN `b:real` STRIP_ASSUME_TAC) THEN
  REWRITE_TAC[lipschitz_continuous_map; REAL_EUCLIDEAN_METRIC; SUBSET_UNIV;
              SUBMETRIC; INTER_UNIV] THEN
  EXISTS_TAC `inv(b pow 2):real` THEN
  MAP_EVERY X_GEN_TAC [`x:real`; `y:real`] THEN
  STRIP_TAC THEN
  ASM_CASES_TAC `x = &0` THENL
   [FIRST_X_ASSUM(MP_TAC o SPEC `x:real`) THEN ASM_REWRITE_TAC[] THEN
    ASM_REAL_ARITH_TAC;
    ALL_TAC] THEN
  ASM_CASES_TAC `y = &0` THENL
   [FIRST_X_ASSUM(MP_TAC o SPEC `y:real`) THEN ASM_REWRITE_TAC[] THEN
    ASM_REAL_ARITH_TAC;
    ALL_TAC] THEN
  ASM_SIMP_TAC[REAL_FIELD
   `~(x = &0) /\ ~(y = &0) ==> inv y - inv x = --inv(x * y) * (y - x)`] THEN
  REWRITE_TAC[REAL_ABS_MUL; REAL_ABS_NEG; REAL_ABS_INV] THEN
  MATCH_MP_TAC REAL_LE_RMUL THEN REWRITE_TAC[REAL_ABS_POS] THEN
  MATCH_MP_TAC REAL_LE_INV2 THEN ASM_SIMP_TAC[REAL_POW_LT] THEN
  REWRITE_TAC[REAL_POW_2] THEN MATCH_MP_TAC REAL_LE_MUL2 THEN
  ASM_SIMP_TAC[REAL_LT_IMP_LE]);;

let LIPSCHITZ_CONTINUOUS_MAP_FST = prove
 (`!m m1 m2 f:A->B#C.
        lipschitz_continuous_map(m,prod_metric m1 m2) f
        ==> lipschitz_continuous_map(m,m1) (\x. FST(f x))`,
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE; o_DEF]);;

let LIPSCHITZ_CONTINUOUS_MAP_SND = prove
 (`!m m1 m2 f:A->B#C.
        lipschitz_continuous_map(m,prod_metric m1 m2) f
        ==> lipschitz_continuous_map(m,m2) (\x. SND(f x))`,
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE; o_DEF]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_LMUL = prove
 (`!m c f:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. c * f x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. c * f x) = (\y. c * y) o (f:A->real)`
  SUBST1_TAC THENL [REWRITE_TAC[FUN_EQ_THM; o_DEF]; ALL_TAC] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `real_euclidean_metric` THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_LEFT_MULTIPLICATION]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_RMUL = prove
 (`!m c f:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. f x * c)`,
  ONCE_REWRITE_TAC[REAL_MUL_SYM] THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_LMUL]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_NEG = prove
 (`!m f:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. --(f x))`,
  ONCE_REWRITE_TAC[REAL_NEG_MINUS1] THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_LMUL]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_ABS = prove
 (`!m f:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. abs(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `real_euclidean_metric` THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_ABSOLUTE_VALUE]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_INV = prove
 (`!m f:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f /\
      ~(&0 IN euclideanreal closure_of (IMAGE f (mspace m)))
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. inv(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN EXISTS_TAC
   `submetric real_euclidean_metric (IMAGE f (mspace m:A->bool))` THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_INTO_SUBMETRIC; SUBSET_REFL] THEN
  MATCH_MP_TAC LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_INVERSION THEN
  ASM_REWRITE_TAC[]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_ADD = prove
 (`!m f g:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f /\
      lipschitz_continuous_map (m,real_euclidean_metric) g
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. f x + g x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. f x + g x) = (\(x,y). x + y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_ADDITION] THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_SUB = prove
 (`!m f g:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f /\
      lipschitz_continuous_map (m,real_euclidean_metric) g
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. f x - g x)`,
  REWRITE_TAC[real_sub] THEN
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_ADD;
           LIPSCHITZ_CONTINUOUS_MAP_REAL_NEG]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_MAX = prove
 (`!m f g:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f /\
      lipschitz_continuous_map (m,real_euclidean_metric) g
      ==> lipschitz_continuous_map (m,real_euclidean_metric)
            (\x. max (f x) (g x))`,
  REPEAT STRIP_TAC THEN SUBGOAL_THEN
   `(\x. max (f x) (g x)) = (\(x,y). max x y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_MAXIMUM] THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_MIN = prove
 (`!m f g:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f /\
      lipschitz_continuous_map (m,real_euclidean_metric) g
      ==> lipschitz_continuous_map (m,real_euclidean_metric)
            (\x. min (f x) (g x))`,
  REPEAT STRIP_TAC THEN SUBGOAL_THEN
   `(\x. min (f x) (g x)) = (\(x,y). min x y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_MINIMUM] THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_MUL = prove
 (`!m f g:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f /\
      lipschitz_continuous_map (m,real_euclidean_metric) g /\
      real_bounded (IMAGE f (mspace m)) /\ real_bounded (IMAGE g (mspace m))
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. f x * g x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. f x * g x) = (\(x,y). x * y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC
   `submetric (prod_metric real_euclidean_metric real_euclidean_metric)
              (IMAGE (f:A->real) (mspace m) CROSS IMAGE g (mspace m))` THEN
  ASM_REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX;
                  LIPSCHITZ_CONTINUOUS_MAP_INTO_SUBMETRIC] THEN
  SIMP_TAC[SUBSET; FORALL_IN_IMAGE; IN_CROSS; FUN_IN_IMAGE] THEN
  MATCH_MP_TAC LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_MULTIPLICATION THEN
  ASM_REWRITE_TAC[MBOUNDED_CROSS; MBOUNDED_REAL_EUCLIDEAN_METRIC]);;

let LIPSCHITZ_CONTINUOUS_MAP_REAL_DIV = prove
 (`!m f g:A->real.
      lipschitz_continuous_map (m,real_euclidean_metric) f /\
      lipschitz_continuous_map (m,real_euclidean_metric) g /\
      real_bounded (IMAGE f (mspace m)) /\
      ~(&0 IN euclideanreal closure_of (IMAGE g (mspace m)))
      ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. f x / g x)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[real_div] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_REAL_MUL THEN
  ASM_SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_INV] THEN
  FIRST_X_ASSUM(MP_TAC o check (is_neg o concl)) THEN
  REWRITE_TAC[CLOSURE_OF_INTERIOR_OF; IN_DIFF; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[IN_UNIV; GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_INTERIOR_OF_MBALL] THEN
  REWRITE_TAC[SUBSET; IN_MBALL; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  REWRITE_TAC[REAL_SUB_RZERO; REAL_NOT_LT; SET_RULE
   `(!x. P x ==> x IN UNIV DIFF s) <=> (!x. x IN s ==> ~P x)`] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; FORALL_IN_IMAGE] THEN
  X_GEN_TAC `b:real` THEN STRIP_TAC THEN
  REWRITE_TAC[real_bounded; FORALL_IN_IMAGE; REAL_ABS_INV] THEN
  EXISTS_TAC `inv b:real` THEN X_GEN_TAC `x:A` THEN DISCH_TAC THEN
  MATCH_MP_TAC REAL_LE_INV2 THEN ASM_SIMP_TAC[]);;

let LIPSCHITZ_CONTINUOUS_MAP_SUM = prove
 (`!m f:K->A->real k.
      FINITE k /\
      (!i. i IN k
          ==> lipschitz_continuous_map (m,real_euclidean_metric) (\x. f x i))
      ==> lipschitz_continuous_map (m,real_euclidean_metric)
                (\x. sum k (f x))`,
  GEN_TAC THEN GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[SUM_CLAUSES; LIPSCHITZ_CONTINUOUS_MAP_CONST; REAL_EUCLIDEAN_METRIC;
    FORALL_IN_INSERT; LIPSCHITZ_CONTINUOUS_MAP_REAL_ADD; ETA_AX; IN_UNIV]);;

let UNIFORMLY_CONTINUOUS_MAP_FST = prove
 (`!m m1 m2 f:A->B#C.
        uniformly_continuous_map(m,prod_metric m1 m2) f
        ==> uniformly_continuous_map(m,m1) (\x. FST(f x))`,
  SIMP_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRWISE; o_DEF]);;

let UNIFORMLY_CONTINUOUS_MAP_SND = prove
 (`!m m1 m2 f:A->B#C.
        uniformly_continuous_map(m,prod_metric m1 m2) f
        ==> uniformly_continuous_map(m,m2) (\x. SND(f x))`,
  SIMP_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRWISE; o_DEF]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_LMUL = prove
 (`!m c f:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. c * f x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. c * f x) = (\y. c * y) o (f:A->real)`
  SUBST1_TAC THENL [REWRITE_TAC[FUN_EQ_THM; o_DEF]; ALL_TAC] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `real_euclidean_metric` THEN
  ASM_SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_LEFT_MULTIPLICATION;
               LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_RMUL = prove
 (`!m c f:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. f x * c)`,
  ONCE_REWRITE_TAC[REAL_MUL_SYM] THEN
  REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_REAL_LMUL]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_NEG = prove
 (`!m f:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. --(f x))`,
  ONCE_REWRITE_TAC[REAL_NEG_MINUS1] THEN
  REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_REAL_LMUL]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_ABS = prove
 (`!m f:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. abs(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `real_euclidean_metric` THEN
  ASM_SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_ABSOLUTE_VALUE;
               LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_INV = prove
 (`!m f:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f /\
      ~(&0 IN euclideanreal closure_of (IMAGE f (mspace m)))
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. inv(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN EXISTS_TAC
   `submetric real_euclidean_metric (IMAGE f (mspace m:A->bool))` THEN
  ASM_REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_INTO_SUBMETRIC; SUBSET_REFL] THEN
  MATCH_MP_TAC LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP THEN
  MATCH_MP_TAC LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_INVERSION THEN
  ASM_REWRITE_TAC[]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_ADD = prove
 (`!m f g:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f /\
      uniformly_continuous_map (m,real_euclidean_metric) g
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. f x + g x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. f x + g x) = (\(x,y). x + y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_ADDITION;
           LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP] THEN
  ASM_REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_SUB = prove
 (`!m f g:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f /\
      uniformly_continuous_map (m,real_euclidean_metric) g
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. f x - g x)`,
  REWRITE_TAC[real_sub] THEN
  SIMP_TAC[UNIFORMLY_CONTINUOUS_MAP_REAL_ADD;
           UNIFORMLY_CONTINUOUS_MAP_REAL_NEG]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_MAX = prove
 (`!m f g:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f /\
      uniformly_continuous_map (m,real_euclidean_metric) g
     ==> uniformly_continuous_map (m,real_euclidean_metric)
            (\x. max (f x) (g x))`,
  REPEAT STRIP_TAC THEN SUBGOAL_THEN
   `(\x. max (f x) (g x)) = (\(x,y). max x y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_MAXIMUM;
           LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP] THEN
  ASM_REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_MIN = prove
 (`!m f g:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f /\
      uniformly_continuous_map (m,real_euclidean_metric) g
     ==> uniformly_continuous_map (m,real_euclidean_metric)
            (\x. min (f x) (g x))`,
  REPEAT STRIP_TAC THEN SUBGOAL_THEN
   `(\x. min (f x) (g x)) = (\(x,y). min x y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_MINIMUM;
           LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP] THEN
  ASM_REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_MUL = prove
 (`!m f g:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f /\
      uniformly_continuous_map (m,real_euclidean_metric) g /\
      real_bounded (IMAGE f (mspace m)) /\ real_bounded (IMAGE g (mspace m))
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. f x * g x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. f x * g x) = (\(x,y). x * y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC
   `submetric (prod_metric real_euclidean_metric real_euclidean_metric)
              (IMAGE (f:A->real) (mspace m) CROSS IMAGE g (mspace m))` THEN
  ASM_REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX;
                  UNIFORMLY_CONTINUOUS_MAP_INTO_SUBMETRIC] THEN
  SIMP_TAC[SUBSET; FORALL_IN_IMAGE; IN_CROSS; FUN_IN_IMAGE] THEN
  MATCH_MP_TAC LIPSCHITZ_IMP_UNIFORMLY_CONTINUOUS_MAP THEN
  MATCH_MP_TAC LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_MULTIPLICATION THEN
  ASM_REWRITE_TAC[MBOUNDED_CROSS; MBOUNDED_REAL_EUCLIDEAN_METRIC]);;

let UNIFORMLY_CONTINUOUS_MAP_REAL_DIV = prove
 (`!m f g:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f /\
      uniformly_continuous_map (m,real_euclidean_metric) g /\
      real_bounded (IMAGE f (mspace m)) /\
      ~(&0 IN euclideanreal closure_of (IMAGE g (mspace m)))
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. f x / g x)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[real_div] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_REAL_MUL THEN
  ASM_SIMP_TAC[UNIFORMLY_CONTINUOUS_MAP_REAL_INV] THEN
  FIRST_X_ASSUM(MP_TAC o check (is_neg o concl)) THEN
  REWRITE_TAC[CLOSURE_OF_INTERIOR_OF; IN_DIFF; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[IN_UNIV; GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_INTERIOR_OF_MBALL] THEN
  REWRITE_TAC[SUBSET; IN_MBALL; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  REWRITE_TAC[REAL_SUB_RZERO; REAL_NOT_LT; SET_RULE
   `(!x. P x ==> x IN UNIV DIFF s) <=> (!x. x IN s ==> ~P x)`] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; FORALL_IN_IMAGE] THEN
  X_GEN_TAC `b:real` THEN STRIP_TAC THEN
  REWRITE_TAC[real_bounded; FORALL_IN_IMAGE; REAL_ABS_INV] THEN
  EXISTS_TAC `inv b:real` THEN X_GEN_TAC `x:A` THEN DISCH_TAC THEN
  MATCH_MP_TAC REAL_LE_INV2 THEN ASM_SIMP_TAC[]);;

let UNIFORMLY_CONTINUOUS_MAP_SUM = prove
 (`!m f:K->A->real k.
      FINITE k /\
      (!i. i IN k
          ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. f x i))
      ==> uniformly_continuous_map (m,real_euclidean_metric)
                (\x. sum k (f x))`,
  GEN_TAC THEN GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[SUM_CLAUSES; UNIFORMLY_CONTINUOUS_MAP_CONST; REAL_EUCLIDEAN_METRIC;
    FORALL_IN_INSERT; UNIFORMLY_CONTINUOUS_MAP_REAL_ADD; ETA_AX; IN_UNIV]);;

let CAUCHY_CONTINUOUS_MAP_FST = prove
 (`!m m1 m2 f:A->B#C.
        cauchy_continuous_map(m,prod_metric m1 m2) f
        ==> cauchy_continuous_map(m,m1) (\x. FST(f x))`,
  SIMP_TAC[CAUCHY_CONTINUOUS_MAP_PAIRWISE; o_DEF]);;

let CAUCHY_CONTINUOUS_MAP_SND = prove
 (`!m m1 m2 f:A->B#C.
        cauchy_continuous_map(m,prod_metric m1 m2) f
        ==> cauchy_continuous_map(m,m2) (\x. SND(f x))`,
  SIMP_TAC[CAUCHY_CONTINUOUS_MAP_PAIRWISE; o_DEF]);;

let CAUCHY_CONTINUOUS_MAP_REAL_INV = prove
 (`!m f:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f /\
      ~(&0 IN euclideanreal closure_of (IMAGE f (mspace m)))
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. inv(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN EXISTS_TAC
   `submetric real_euclidean_metric (IMAGE f (mspace m:A->bool))` THEN
  ASM_REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_INTO_SUBMETRIC; SUBSET_REFL] THEN
  MATCH_MP_TAC LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP THEN
  MATCH_MP_TAC LOCALLY_LIPSCHITZ_CONTINUOUS_MAP_REAL_INVERSION THEN
  ASM_REWRITE_TAC[]);;

let CAUCHY_CONTINUOUS_MAP_REAL_ADD = prove
 (`!m f g:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f /\
      cauchy_continuous_map (m,real_euclidean_metric) g
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. f x + g x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. f x + g x) = (\(x,y). x + y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_ADDITION;
           LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP] THEN
  ASM_REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let CAUCHY_CONTINUOUS_MAP_REAL_MUL = prove
 (`!m f g:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f /\
      cauchy_continuous_map (m,real_euclidean_metric) g
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. f x * g x)`,
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `(\x. f x * g x) = (\(x,y). x * y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC
   `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_REAL_MULTIPLICATION] THEN
  ASM_REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let CAUCHY_CONTINUOUS_MAP_REAL_LMUL = prove
 (`!m c f:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. c * f x)`,
  SIMP_TAC[CAUCHY_CONTINUOUS_MAP_REAL_MUL; CAUCHY_CONTINUOUS_MAP_REAL_CONST]);;

let CAUCHY_CONTINUOUS_MAP_REAL_RMUL = prove
 (`!m c f:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. f x * c)`,
  ONCE_REWRITE_TAC[REAL_MUL_SYM] THEN
  REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_REAL_LMUL]);;

let CAUCHY_CONTINUOUS_MAP_REAL_POW = prove
 (`!m (f:A->real) n.
        cauchy_continuous_map (m,real_euclidean_metric) f
        ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. f x pow n)`,
  REWRITE_TAC[RIGHT_FORALL_IMP_THM] THEN REPEAT GEN_TAC THEN DISCH_TAC THEN
  INDUCT_TAC THEN
  ASM_SIMP_TAC[real_pow; CAUCHY_CONTINUOUS_MAP_REAL_CONST;
               CAUCHY_CONTINUOUS_MAP_REAL_MUL]);;

let CAUCHY_CONTINUOUS_MAP_REAL_NEG = prove
 (`!m f:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. --(f x))`,
  ONCE_REWRITE_TAC[REAL_NEG_MINUS1] THEN
  REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_REAL_LMUL]);;

let CAUCHY_CONTINUOUS_MAP_REAL_ABS = prove
 (`!m f:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. abs(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `real_euclidean_metric` THEN
  ASM_SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_ABSOLUTE_VALUE;
               LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP]);;

let CAUCHY_CONTINUOUS_MAP_REAL_SUB = prove
 (`!m f g:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f /\
      cauchy_continuous_map (m,real_euclidean_metric) g
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. f x - g x)`,
  REWRITE_TAC[real_sub] THEN
  SIMP_TAC[CAUCHY_CONTINUOUS_MAP_REAL_ADD;
           CAUCHY_CONTINUOUS_MAP_REAL_NEG]);;

let CAUCHY_CONTINUOUS_MAP_REAL_MAX = prove
 (`!m f g:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f /\
      cauchy_continuous_map (m,real_euclidean_metric) g
    ==> cauchy_continuous_map (m,real_euclidean_metric)
            (\x. max (f x) (g x))`,
  REPEAT STRIP_TAC THEN SUBGOAL_THEN
   `(\x. max (f x) (g x)) = (\(x,y). max x y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_MAXIMUM;
           LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP] THEN
  ASM_REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let CAUCHY_CONTINUOUS_MAP_REAL_MIN = prove
 (`!m f g:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f /\
      cauchy_continuous_map (m,real_euclidean_metric) g
    ==> cauchy_continuous_map (m,real_euclidean_metric)
            (\x. min (f x) (g x))`,
  REPEAT STRIP_TAC THEN SUBGOAL_THEN
   `(\x. min (f x) (g x)) = (\(x,y). min x y) o (\z. (f:A->real) z,g z)`
  SUBST1_TAC THENL
   [REWRITE_TAC[FUN_EQ_THM; o_DEF; FORALL_PAIR_THM]; ALL_TAC] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `prod_metric real_euclidean_metric real_euclidean_metric` THEN
  SIMP_TAC[LIPSCHITZ_CONTINUOUS_MAP_REAL_MINIMUM;
           LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP] THEN
  ASM_REWRITE_TAC[CAUCHY_CONTINUOUS_MAP_PAIRWISE; o_DEF; ETA_AX]);;

let CAUCHY_CONTINUOUS_MAP_REAL_DIV = prove
 (`!m f g:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f /\
      cauchy_continuous_map (m,real_euclidean_metric) g /\
      ~(&0 IN euclideanreal closure_of (IMAGE g (mspace m)))
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. f x / g x)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[real_div] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_REAL_MUL THEN
  ASM_SIMP_TAC[CAUCHY_CONTINUOUS_MAP_REAL_INV] THEN
  FIRST_X_ASSUM(MP_TAC o check (is_neg o concl)) THEN
  REWRITE_TAC[CLOSURE_OF_INTERIOR_OF; IN_DIFF; TOPSPACE_EUCLIDEANREAL] THEN
  REWRITE_TAC[IN_UNIV; GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_INTERIOR_OF_MBALL] THEN
  REWRITE_TAC[SUBSET; IN_MBALL; REAL_EUCLIDEAN_METRIC; IN_UNIV] THEN
  REWRITE_TAC[REAL_SUB_RZERO; REAL_NOT_LT; SET_RULE
   `(!x. P x ==> x IN UNIV DIFF s) <=> (!x. x IN s ==> ~P x)`] THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM; FORALL_IN_IMAGE] THEN
  X_GEN_TAC `b:real` THEN STRIP_TAC THEN
  REWRITE_TAC[real_bounded; FORALL_IN_IMAGE; REAL_ABS_INV] THEN
  EXISTS_TAC `inv b:real` THEN X_GEN_TAC `x:A` THEN DISCH_TAC THEN
  MATCH_MP_TAC REAL_LE_INV2 THEN ASM_SIMP_TAC[]);;

let CAUCHY_CONTINUOUS_MAP_SUM = prove
 (`!m f:K->A->real k.
      FINITE k /\
      (!i. i IN k
          ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. f x i))
      ==> cauchy_continuous_map (m,real_euclidean_metric)
                (\x. sum k (f x))`,
  GEN_TAC THEN GEN_TAC THEN REWRITE_TAC[IMP_CONJ] THEN
  REWRITE_TAC[IMP_CONJ] THEN
  MATCH_MP_TAC FINITE_INDUCT_STRONG THEN
  SIMP_TAC[SUM_CLAUSES; CAUCHY_CONTINUOUS_MAP_REAL_CONST;
    FORALL_IN_INSERT; CAUCHY_CONTINUOUS_MAP_REAL_ADD; ETA_AX]);;

let UNIFORMLY_CONTINUOUS_MAP_SQUARE_ROOT = prove
 (`uniformly_continuous_map(real_euclidean_metric,real_euclidean_metric) sqrt`,
  REWRITE_TAC[uniformly_continuous_map; REAL_EUCLIDEAN_METRIC] THEN
  REWRITE_TAC[IN_UNIV; SUBSET_UNIV] THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  EXISTS_TAC `e pow 2 / &2` THEN ASM_SIMP_TAC[REAL_HALF; REAL_POW_LT] THEN
  MAP_EVERY X_GEN_TAC [`x:real`; `y:real`] THEN DISCH_TAC THEN
  TRANS_TAC REAL_LET_TRANS `sqrt(&2 * abs(x - y))` THEN
  REWRITE_TAC[REAL_ABS_LE_SQRT] THEN MATCH_MP_TAC REAL_LT_LSQRT THEN
  ASM_REAL_ARITH_TAC);;

let CONTINUOUS_MAP_SQUARE_ROOT = prove
 (`continuous_map(euclideanreal,euclideanreal) sqrt`,
  REWRITE_TAC[GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_IMP_CONTINUOUS_MAP THEN
  REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_SQUARE_ROOT]);;

let UNIFORMLY_CONTINUOUS_MAP_SQRT = prove
 (`!m f:A->real.
      uniformly_continuous_map (m,real_euclidean_metric) f
      ==> uniformly_continuous_map (m,real_euclidean_metric) (\x. sqrt(f x))`,
   REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `real_euclidean_metric` THEN
  ASM_REWRITE_TAC[UNIFORMLY_CONTINUOUS_MAP_SQUARE_ROOT]);;

let CAUCHY_CONTINUOUS_MAP_SQRT = prove
 (`!m f:A->real.
      cauchy_continuous_map (m,real_euclidean_metric) f
      ==> cauchy_continuous_map (m,real_euclidean_metric) (\x. sqrt(f x))`,
   REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `real_euclidean_metric` THEN
  ASM_SIMP_TAC[UNIFORMLY_CONTINUOUS_MAP_SQUARE_ROOT;
               UNIFORMLY_IMP_CAUCHY_CONTINUOUS_MAP]);;

let CONTINUOUS_MAP_SQRT = prove
 (`!top f:A->real.
        continuous_map (top,euclideanreal) f
        ==> continuous_map (top,euclideanreal) (\x. sqrt(f x))`,
  REPEAT STRIP_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `euclideanreal` THEN ASM_REWRITE_TAC[] THEN
  SIMP_TAC[UNIFORMLY_CONTINUOUS_MAP_SQUARE_ROOT; GSYM
           MTOPOLOGY_REAL_EUCLIDEAN_METRIC;
           UNIFORMLY_CONTINUOUS_IMP_CONTINUOUS_MAP]);;

let ISOMETRY_IMP_EMBEDDING_MAP = prove
 (`!m m' (f:A->B).
        IMAGE f (mspace m) SUBSET mspace m' /\
        (!x y. x IN mspace m /\ y IN mspace m
               ==> mdist m' (f x,f y) = mdist m (x,y))
        ==> embedding_map(mtopology m,mtopology m') f`,
  REWRITE_TAC[SUBSET; FORALL_IN_IMAGE] THEN REPEAT STRIP_TAC THEN
  SUBGOAL_THEN
   `!x y. x IN mspace m /\ y IN mspace m /\ (f:A->B) x = f y ==> x = y`
  MP_TAC THENL [ASM_MESON_TAC[MDIST_0]; ALL_TAC] THEN
  REWRITE_TAC[INJECTIVE_ON_LEFT_INVERSE; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `g:B->A` THEN DISCH_TAC THEN
  REWRITE_TAC[embedding_map; HOMEOMORPHIC_MAP_MAPS] THEN
  EXISTS_TAC `g:B->A` THEN
  ASM_REWRITE_TAC[homeomorphic_maps; TOPSPACE_MTOPOLOGY;
                  TOPSPACE_SUBTOPOLOGY; IN_INTER; IMP_CONJ_ALT] THEN
  ASM_SIMP_TAC[FORALL_IN_IMAGE] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN
  ASM_REWRITE_TAC[SUBSET; FORALL_IN_IMAGE; TOPSPACE_MTOPOLOGY] THEN
  SIMP_TAC[FUN_IN_IMAGE; GSYM MTOPOLOGY_SUBMETRIC] THEN
  CONJ_TAC THEN MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_IMP_CONTINUOUS_MAP THEN
  ASM_SIMP_TAC[lipschitz_continuous_map; SUBSET; FORALL_IN_IMAGE;
               SUBMETRIC; IMP_CONJ; IN_INTER] THEN
  EXISTS_TAC `&1` THEN
  REWRITE_TAC[RIGHT_FORALL_IMP_THM; FORALL_IN_IMAGE; REAL_MUL_LID] THEN
  ASM_SIMP_TAC[REAL_LE_REFL]);;

let ISOMETRY_IMP_HOMEOMORPHIC_MAP = prove
 (`!m m' (f:A->B).
        IMAGE f (mspace m) = mspace m' /\
        (!x y. x IN mspace m /\ y IN mspace m
               ==> mdist m' (f x,f y) = mdist m (x,y))
        ==> homeomorphic_map(mtopology m,mtopology m') f`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m:A metric`; `m':B metric`; `f:A->B`]
        ISOMETRY_IMP_EMBEDDING_MAP) THEN
  ASM_REWRITE_TAC[SUBSET_REFL; embedding_map; TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY; SUBTOPOLOGY_TOPSPACE]);;

(* ------------------------------------------------------------------------- *)
(* Extending continuous maps "pointwise" in a regular space.                 *)
(* ------------------------------------------------------------------------- *)

let CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE_OF = prove
 (`!top top' f:A->B s t.
       regular_space top' /\
       t SUBSET top closure_of s /\
       (!x. x IN t ==> limit top' f (f x) (atpointof top x within s))
       ==> continuous_map (subtopology top t,top') f`,
  REWRITE_TAC[GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN] THEN REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `IMAGE (f:A->B) t SUBSET topspace top'` ASSUME_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[limit]) THEN ASM SET_TAC[]; ALL_TAC] THEN
  REWRITE_TAC[CONTINUOUS_MAP_ATPOINTOF; TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN
  X_GEN_TAC `a:A` THEN STRIP_TAC THEN ASM_SIMP_TAC[ATPOINTOF_SUBTOPOLOGY] THEN
  REWRITE_TAC[limit] THEN CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
  X_GEN_TAC `w:B->bool` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [NEIGHBOURHOOD_BASE_OF]) THEN
  DISCH_THEN(MP_TAC o SPECL [`w:B->bool`; `(f:A->B) a`]) THEN
  ASM_REWRITE_TAC[SUBTOPOLOGY_TOPSPACE; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`v:B->bool`; `c:B->bool`] THEN STRIP_TAC THEN
  REWRITE_TAC[EVENTUALLY_ATPOINTOF; EVENTUALLY_WITHIN_IMP] THEN DISJ2_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `a:A`) THEN
  ANTS_TAC THENL [ASM_REWRITE_TAC[]; REWRITE_TAC[limit]] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC (MP_TAC o SPEC `v:B->bool`)) THEN
  ASM_REWRITE_TAC[EVENTUALLY_ATPOINTOF; EVENTUALLY_WITHIN_IMP] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `u:A->bool` THEN
  REWRITE_TAC[IMP_IMP] THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  X_GEN_TAC `z:A` THEN REWRITE_TAC[IN_DELETE] THEN STRIP_TAC THEN
  SUBGOAL_THEN `z IN topspace top /\ (f:A->B) z IN topspace top'`
  STRIP_ASSUME_TAC THENL
   [REPEAT(FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET)) THEN
    ASM SET_TAC[];
    ALL_TAC] THEN
  SUBGOAL_THEN `~((f:A->B) z IN topspace top' DIFF c)` MP_TAC THENL
   [REWRITE_TAC[IN_DIFF] THEN STRIP_TAC; ASM SET_TAC[]] THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE RAND_CONV [limit] o SPEC `z:A`) THEN
  ASM_REWRITE_TAC[] THEN
  DISCH_THEN(MP_TAC o SPEC `topspace top' DIFF c:B->bool`) THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_TOPSPACE; IN_DIFF] THEN
  ASM_REWRITE_TAC[EVENTUALLY_ATPOINTOF; EVENTUALLY_WITHIN_IMP] THEN
  DISCH_THEN(X_CHOOSE_THEN `u':A->bool` STRIP_ASSUME_TAC) THEN
  UNDISCH_TAC `(t:A->bool) SUBSET top closure_of s` THEN
  REWRITE_TAC[closure_of; IN_ELIM_THM; SUBSET] THEN
  DISCH_THEN(MP_TAC o SPEC `z:A`) THEN ASM_REWRITE_TAC[] THEN
  DISCH_THEN(MP_TAC o SPEC `u INTER u':A->bool`) THEN
  ASM_SIMP_TAC[OPEN_IN_INTER] THEN ASM SET_TAC[]);;

let CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE_OF_EQ = prove
 (`!top top' f:A->B s t.
        regular_space top' /\ s SUBSET t /\ t SUBSET top closure_of s
        ==> (continuous_map (subtopology top t,top') f <=>
             !x. x IN t ==> limit top' f (f x) (atpointof top x within s))`,
  REPEAT STRIP_TAC THEN EQ_TAC THENL
   [REWRITE_TAC[CONTINUOUS_MAP_ATPOINTOF; TOPSPACE_SUBTOPOLOGY] THEN
    MATCH_MP_TAC MONO_FORALL THEN X_GEN_TAC `x:A` THEN
    ASM_CASES_TAC `(x:A) IN t` THEN ASM_SIMP_TAC[ATPOINTOF_SUBTOPOLOGY] THEN
    ASSUME_TAC(ISPECL [`top:A topology`; `s:A->bool`]
      CLOSURE_OF_SUBSET_TOPSPACE) THEN
    ANTS_TAC THENL [ASM SET_TAC[]; ASM_MESON_TAC[LIMIT_WITHIN_SUBSET]];
    ASM_MESON_TAC[CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE_OF]]);;

let CONTINUOUS_MAP_EXTENSION_POINTWISE_ALT = prove
 (`!top1 top2 f:A->B s t.
        regular_space top2 /\ s SUBSET t /\ t SUBSET top1 closure_of s /\
        continuous_map (subtopology top1 s,top2) f /\
        (!x. x IN t DIFF s ==> ?l. limit top2 f l (atpointof top1 x within s))
        ==> ?g. continuous_map (subtopology top1 t,top2) g /\
                (!x. x IN s ==> g x = f x)`,
  REPEAT STRIP_TAC THEN FIRST_X_ASSUM
   (MP_TAC o GEN_REWRITE_RULE BINDER_CONV [RIGHT_IMP_EXISTS_THM]) THEN
  REWRITE_TAC[SKOLEM_THM; LEFT_IMP_EXISTS_THM; IN_DIFF] THEN
  X_GEN_TAC `g:A->B` THEN DISCH_TAC THEN
  EXISTS_TAC `\x. if x IN s then (f:A->B) x else g x` THEN
  ASM_SIMP_TAC[CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE_OF_EQ] THEN
  X_GEN_TAC `x:A` THEN DISCH_TAC THEN
  MATCH_MP_TAC LIMIT_TRANSFORM_EVENTUALLY THEN
  EXISTS_TAC `f:A->B` THEN SIMP_TAC[ALWAYS_WITHIN_EVENTUALLY] THEN
  COND_CASES_TAC THEN
  ASM_SIMP_TAC[GSYM ATPOINTOF_SUBTOPOLOGY] THEN
  FIRST_ASSUM(MATCH_MP_TAC o
   GEN_REWRITE_RULE I [CONTINUOUS_MAP_ATPOINTOF]) THEN
  ASM_REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[closure_of]) THEN ASM SET_TAC[]);;

let CONTINUOUS_MAP_EXTENSION_POINTWISE = prove
 (`!top1 top2 f:A->B s t.
        regular_space top2 /\ s SUBSET t /\ t SUBSET top1 closure_of s /\
        (!x. x IN t
             ==> ?g. continuous_map (subtopology top1 (x INSERT s),top2) g /\
                     !x. x IN s ==> g x = f x)
        ==> ?g. continuous_map (subtopology top1 t,top2) g /\
                (!x. x IN s ==> g x = f x)`,
  REPEAT STRIP_TAC THEN
  MATCH_MP_TAC CONTINUOUS_MAP_EXTENSION_POINTWISE_ALT THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_ATPOINTOF] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_DIFF; IN_INTER] THEN
  CONJ_TAC THEN X_GEN_TAC `x:A` THEN STRIP_TAC THEN
  (SUBGOAL_THEN `(x:A) IN topspace top1` ASSUME_TAC THENL
    [RULE_ASSUM_TAC(SIMP_RULE[closure_of]) THEN ASM SET_TAC[]; ALL_TAC]) THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `x:A`) THEN
  (ANTS_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[LEFT_IMP_EXISTS_THM]]) THEN
  X_GEN_TAC `g:A->B` THEN REWRITE_TAC[CONTINUOUS_MAP_ATPOINTOF] THEN
  DISCH_THEN(CONJUNCTS_THEN2 (MP_TAC o SPEC `x:A`) ASSUME_TAC) THEN
  ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER; IN_INSERT] THEN
  ASM_SIMP_TAC[ATPOINTOF_SUBTOPOLOGY; IN_INSERT] THEN
  STRIP_TAC THENL [ALL_TAC; EXISTS_TAC `(g:A->B) x`] THEN
  MATCH_MP_TAC LIMIT_TRANSFORM_EVENTUALLY THEN
  EXISTS_TAC `(g:A->B)` THEN ASM_SIMP_TAC[ALWAYS_WITHIN_EVENTUALLY] THEN
  MATCH_MP_TAC LIMIT_WITHIN_SUBSET THEN
  EXISTS_TAC `(x:A) INSERT s` THEN
  ASM_REWRITE_TAC[SET_RULE `s SUBSET x INSERT s`]);;

(* ------------------------------------------------------------------------- *)
(* Lavrentiev extension theorem etc.                                         *)
(* ------------------------------------------------------------------------- *)

let CONVERGENT_EQ_ZERO_OSCILLATION_GEN = prove
 (`!top m (f:A->B) s a.
        mcomplete m /\ IMAGE f (topspace top INTER s) SUBSET mspace m
        ==> ((?l. limit (mtopology m) f l (atpointof top a within s)) <=>
             ~(mspace m = {}) /\
             (a IN topspace top
              ==> !e. &0 < e
                      ==> ?u. open_in top u /\ a IN u /\
                              !x y. x IN (s INTER u) DELETE a /\
                                    y IN (s INTER u) DELETE a
                                    ==> mdist m (f x,f y) < e))`,
  REPEAT GEN_TAC THEN
  ASM_CASES_TAC `mspace m:B->bool = {}` THENL
   [ASM_REWRITE_TAC[LIMIT_METRIC; NOT_IN_EMPTY]; STRIP_TAC] THEN
  ASM_CASES_TAC `(a:A) IN topspace top` THENL
   [ASM_REWRITE_TAC[];
    ASM_SIMP_TAC[LIMIT_METRIC; EVENTUALLY_WITHIN_IMP;
                 EVENTUALLY_ATPOINTOF; NOT_IN_EMPTY] THEN
    ASM SET_TAC[]] THEN
  ASM_CASES_TAC `(a:A) IN top derived_set_of s` THENL
   [ALL_TAC;
    MATCH_MP_TAC(TAUT `p /\ q ==> (p <=> q)`) THEN CONJ_TAC THENL
     [ASM_MESON_TAC[MEMBER_NOT_EMPTY; TOPSPACE_MTOPOLOGY;
                    TRIVIAL_LIMIT_ATPOINTOF_WITHIN; LIMIT_TRIVIAL];
      REPEAT STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE (RAND_CONV o RAND_CONV)
       [derived_set_of]) THEN
      ASM_REWRITE_TAC[IN_ELIM_THM; NOT_FORALL_THM; NOT_IMP] THEN
      MATCH_MP_TAC MONO_EXISTS THEN SET_TAC[]]] THEN
  EQ_TAC THENL
   [REWRITE_TAC[LIMIT_METRIC; EVENTUALLY_WITHIN_IMP; EVENTUALLY_ATPOINTOF] THEN
    ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM; IMP_IMP] THEN
    X_GEN_TAC `l:B` THEN STRIP_TAC THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN
    ASM_REWRITE_TAC[REAL_HALF] THEN MATCH_MP_TAC MONO_EXISTS THEN
    X_GEN_TAC `u:A->bool` THEN REWRITE_TAC[IN_DELETE; IN_INTER] THEN
    STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
    MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
    FIRST_X_ASSUM(fun th ->
      MP_TAC(SPEC `y:A` th) THEN MP_TAC(SPEC `x:A` th)) THEN
    ASM_REWRITE_TAC[] THEN UNDISCH_TAC `(l:B) IN mspace m` THEN
    CONV_TAC METRIC_ARITH;
    DISCH_TAC] THEN
  FIRST_ASSUM(MP_TAC o GEN_REWRITE_RULE I [MCOMPLETE_FIP_SING]) THEN
  DISCH_THEN(MP_TAC o SPEC
   `{ mtopology m closure_of (IMAGE (f:A->B) ((s INTER u) DELETE a)) |u|
      open_in top u /\ a IN u}`) THEN
  ANTS_TAC THENL
   [REWRITE_TAC[FORALL_IN_GSPEC; CLOSED_IN_CLOSURE_OF] THEN
    ONCE_REWRITE_TAC[SIMPLE_IMAGE_GEN] THEN
    REWRITE_TAC[FORALL_FINITE_SUBSET_IMAGE; RIGHT_EXISTS_AND_THM] THEN
    REWRITE_TAC[EXISTS_IN_IMAGE; EXISTS_IN_GSPEC] THEN CONJ_TAC THENL
     [X_GEN_TAC `e:real` THEN DISCH_TAC THEN
      FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN
      ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_EXISTS THEN
      X_GEN_TAC `u:A->bool` THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [IN_DERIVED_SET_OF]) THEN
      ASM_REWRITE_TAC[] THEN DISCH_THEN(MP_TAC o SPEC `u:A->bool`) THEN
      ASM_REWRITE_TAC[] THEN
      DISCH_THEN(X_CHOOSE_THEN `b:A` STRIP_ASSUME_TAC) THEN
      EXISTS_TAC `(f:A->B) b` THEN MATCH_MP_TAC CLOSURE_OF_MINIMAL THEN
      REWRITE_TAC[CLOSED_IN_MCBALL; SUBSET; FORALL_IN_IMAGE] THEN
      REWRITE_TAC[IN_INTER; IN_DELETE; IN_MCBALL; CONJ_ASSOC] THEN
      GEN_TAC THEN STRIP_TAC THEN CONJ_TAC THENL
       [RULE_ASSUM_TAC(REWRITE_RULE[SUBSET; IN_INTER; FORALL_IN_IMAGE]) THEN
        ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET];
        MATCH_MP_TAC REAL_LT_IMP_LE THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
        ASM_REWRITE_TAC[IN_INTER; IN_DELETE]];
      X_GEN_TAC `t:(A->bool)->bool` THEN
      REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN STRIP_TAC THEN
      ONCE_REWRITE_TAC[GSYM o_DEF] THEN REWRITE_TAC[IMAGE_o] THEN
      MATCH_MP_TAC(SET_RULE
       `!g. (!s. s IN t ==> s SUBSET g s) /\ (?x. x IN INTERS t)
             ==> ~(INTERS (IMAGE g t) = {})`) THEN
      CONJ_TAC THENL
       [REWRITE_TAC[FORALL_IN_IMAGE] THEN REPEAT STRIP_TAC THEN
        MATCH_MP_TAC CLOSURE_OF_SUBSET THEN
        REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
        RULE_ASSUM_TAC(REWRITE_RULE[OPEN_IN_CLOSED_IN_EQ]) THEN
        ASM SET_TAC[];
        FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [IN_DERIVED_SET_OF]) THEN
        DISCH_THEN(MP_TAC o SPEC
          `INTERS (topspace top INSERT t):A->bool` o CONJUNCT2) THEN
        ASM_SIMP_TAC[OPEN_IN_INTERS; GSYM INTERS_INSERT; NOT_INSERT_EMPTY;
                     FINITE_INSERT; FORALL_IN_INSERT; OPEN_IN_TOPSPACE] THEN
        ANTS_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN
        DISCH_THEN(X_CHOOSE_THEN `y:A` STRIP_ASSUME_TAC) THEN
        EXISTS_TAC `(f:A->B) y` THEN REWRITE_TAC[INTERS_IMAGE] THEN
        ASM SET_TAC[]]];
    MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `b:B` THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[LIMIT_METRIC] THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN ASM_REWRITE_TAC[REAL_HALF] THEN
    DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
    FIRST_ASSUM(MP_TAC o MATCH_MP (SET_RULE `s = {a} ==> a IN s`)) THEN
    REWRITE_TAC[INTERS_GSPEC; closure_of; IN_ELIM_THM] THEN
    DISCH_THEN(MP_TAC o SPEC `u:A->bool`) THEN
    ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY; EXISTS_IN_IMAGE] THEN
    DISCH_THEN(MP_TAC o SPEC `mball m (b:B,e / &2)`) THEN
    ASM_SIMP_TAC[CENTRE_IN_MBALL; REAL_HALF; OPEN_IN_MBALL; IN_INTER] THEN
    REWRITE_TAC[IN_MBALL; LEFT_IMP_EXISTS_THM; IN_DELETE; IN_INTER] THEN
    X_GEN_TAC `x:A` THEN STRIP_TAC THEN
    ASM_REWRITE_TAC[EVENTUALLY_WITHIN_IMP; EVENTUALLY_ATPOINTOF] THEN
    EXISTS_TAC `u:A->bool` THEN ASM_REWRITE_TAC[IN_DELETE] THEN
    X_GEN_TAC `y:A` THEN STRIP_TAC THEN DISCH_TAC THEN
    MATCH_MP_TAC(TAUT `p /\ (p ==> q) ==> p /\ q`) THEN CONJ_TAC THENL
     [RULE_ASSUM_TAC(REWRITE_RULE[SUBSET; IN_INTER; FORALL_IN_IMAGE]) THEN
      ASM_MESON_TAC[SUBSET; OPEN_IN_SUBSET];
      FIRST_X_ASSUM(MP_TAC o SPECL [`x:A`; `y:A`]) THEN
      ASM_REWRITE_TAC[IN_INTER; IN_DELETE] THEN
      MAP_EVERY UNDISCH_TAC
       [`mdist m (b,(f:A->B) x) < e / &2`; `(b:B) IN mspace m`;
        `(f:A->B) x IN mspace m`] THEN
      CONV_TAC METRIC_ARITH]]);;

let GDELTA_IN_POINTS_OF_CONVERGENCE_WITHIN = prove
 (`!top top' (f:A->B) s.
        completely_metrizable_space top' /\
        (continuous_map (subtopology top s,top') f \/
         t1_space top /\ IMAGE f s SUBSET topspace top')
        ==> gdelta_in top
             {x | x IN topspace top /\
                  ?l. limit top' f l (atpointof top x within s)}`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[FORALL_COMPLETELY_METRIZABLE_SPACE] THEN
  REPEAT GEN_TAC THEN DISCH_TAC THEN REPEAT GEN_TAC THEN
  DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  SUBGOAL_THEN `IMAGE (f:A->B) (topspace top INTER s) SUBSET mspace m`
  ASSUME_TAC THENL
   [FIRST_X_ASSUM DISJ_CASES_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
    ASM_MESON_TAC[CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE; TOPSPACE_SUBTOPOLOGY;
                  TOPSPACE_MTOPOLOGY];
    ONCE_REWRITE_TAC[TAUT `p /\ q <=> ~(p ==> ~q)`] THEN
    ASM_SIMP_TAC[CONVERGENT_EQ_ZERO_OSCILLATION_GEN] THEN
    REWRITE_TAC[NOT_IMP]] THEN
  ASM_CASES_TAC `mspace m:B->bool = {}` THEN
  ASM_REWRITE_TAC[EMPTY_GSPEC; GDELTA_IN_EMPTY] THEN
  MATCH_MP_TAC(MESON[]
   `!s. gdelta_in top s /\ t = s ==> gdelta_in top t`) THEN
  FIRST_X_ASSUM(DISJ_CASES_THEN STRIP_ASSUME_TAC) THENL
   [EXISTS_TAC
     `topspace top INTER
      INTERS {UNIONS {u | open_in top u /\
                          !x y. x IN (s INTER u) /\
                                y IN (s INTER u)
                                ==> mdist m ((f:A->B) x,f y) < inv(&n + &1)}
              | n IN (:num)}`;
    EXISTS_TAC
     `topspace top INTER
      INTERS {UNIONS {u | open_in top u /\
                          ?b. b IN topspace top /\
                              !x y. x IN (s INTER u) DELETE b /\
                                    y IN (s INTER u) DELETE b
                                    ==> mdist m ((f:A->B) x,f y) < inv(&n + &1)}
              | n IN (:num)}`] THEN
  (CONJ_TAC THENL
    [REWRITE_TAC[gdelta_in] THEN MATCH_MP_TAC RELATIVE_TO_INC THEN
     MATCH_MP_TAC COUNTABLE_INTERSECTION_OF_INTERS THEN
     ASM_SIMP_TAC[SIMPLE_IMAGE; COUNTABLE_IMAGE; NUM_COUNTABLE] THEN
     REWRITE_TAC[FORALL_IN_IMAGE; IN_UNIV] THEN GEN_TAC THEN
     MATCH_MP_TAC COUNTABLE_INTERSECTION_OF_INC THEN
     MATCH_MP_TAC OPEN_IN_UNIONS THEN SIMP_TAC[IN_ELIM_THM];
     ALL_TAC]) THEN
  GEN_REWRITE_TAC I [EXTENSION] THEN
  REWRITE_TAC[IN_INTER; INTERS_GSPEC; IN_ELIM_THM] THEN
  REWRITE_TAC[IN_UNIV; IN_UNIONS; IN_ELIM_THM] THEN
  X_GEN_TAC `a:A` THEN ASM_CASES_TAC `(a:A) IN topspace top` THEN
  ASM_REWRITE_TAC[] THEN
  W(MP_TAC o PART_MATCH (rand o rand) FORALL_POS_MONO_1_EQ o rand o snd) THEN
  (ANTS_TAC THENL
    [MESON_TAC[REAL_LT_TRANS]; DISCH_THEN(SUBST1_TAC o SYM)]) THEN
  REWRITE_TAC[IN_INTER; IN_DELETE; IN_ELIM_THM] THENL
   [EQ_TAC THENL [DISCH_TAC; MESON_TAC[]] THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
    ASM_CASES_TAC `(a:A) IN s` THENL [ALL_TAC; ASM_MESON_TAC[]] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [CONTINUOUS_MAP_TO_METRIC]) THEN
    DISCH_THEN(MP_TAC o SPEC `a:A`) THEN
    ASM_REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN
    DISCH_THEN(MP_TAC o SPEC `e:real`) THEN
    ASM_REWRITE_TAC[OPEN_IN_SUBTOPOLOGY_ALT; EXISTS_IN_GSPEC; IN_INTER] THEN
    REWRITE_TAC[IN_MBALL; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `v:A->bool` THEN STRIP_TAC THEN
    EXISTS_TAC `u INTER v:A->bool` THEN
    ASM_SIMP_TAC[OPEN_IN_INTER; IN_INTER] THEN
    MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
    ASM_CASES_TAC `x:A = a` THEN ASM_SIMP_TAC[] THEN
    ASM_CASES_TAC `y:A = a` THEN ASM_SIMP_TAC[] THEN
    ASM_MESON_TAC[MDIST_SYM];
    EQ_TAC THENL [ASM_METIS_TAC[]; DISCH_TAC] THEN
    X_GEN_TAC `e:real` THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `e:real`) THEN
    ASM_REWRITE_TAC[RIGHT_AND_EXISTS_THM; LEFT_AND_EXISTS_THM;
                    LEFT_IMP_EXISTS_THM] THEN
    MAP_EVERY X_GEN_TAC [`u:A->bool`; `b:A`] THEN STRIP_TAC THEN
    ASM_CASES_TAC `b:A = a` THENL [ASM_MESON_TAC[]; ALL_TAC] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [t1_space]) THEN
    DISCH_THEN(MP_TAC o SPECL [`a:A`; `b:A`]) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(X_CHOOSE_THEN `v:A->bool` STRIP_ASSUME_TAC) THEN
    EXISTS_TAC `u INTER v:A->bool` THEN
    ASM_SIMP_TAC[OPEN_IN_INTER; IN_INTER] THEN ASM SET_TAC[]]);;

let LAVRENTIEV_EXTENSION_GEN = prove
 (`!top s top' (f:A->B).
        s SUBSET topspace top /\
        completely_metrizable_space top' /\
        continuous_map(subtopology top s,top') f
        ==> ?u g. gdelta_in top u /\
                  s SUBSET u /\
                  continuous_map
                     (subtopology top (top closure_of s INTER u),top') g /\
                  !x. x IN s ==> g x = f x`,
  REPEAT STRIP_TAC THEN
  EXISTS_TAC
   `{x | x IN topspace top /\
         ?l. limit top' (f:A->B) l (atpointof top x within s)}` THEN
  REWRITE_TAC[INTER_SUBSET; RIGHT_EXISTS_AND_THM] THEN
  ASM_SIMP_TAC[GDELTA_IN_POINTS_OF_CONVERGENCE_WITHIN] THEN
  MATCH_MP_TAC(TAUT `p /\ (p ==> q) ==> p /\ q`) THEN CONJ_TAC THENL
   [REWRITE_TAC[SUBSET; IN_ELIM_THM] THEN X_GEN_TAC `x:A` THEN
    DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [CONTINUOUS_MAP_ATPOINTOF]) THEN
    REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER] THEN
    ASM_MESON_TAC[ATPOINTOF_SUBTOPOLOGY; SUBSET];
    DISCH_TAC THEN MATCH_MP_TAC CONTINUOUS_MAP_EXTENSION_POINTWISE_ALT THEN
    ASM_SIMP_TAC[INTER_SUBSET; METRIZABLE_IMP_REGULAR_SPACE;
                 COMPLETELY_METRIZABLE_IMP_METRIZABLE_SPACE] THEN
    SIMP_TAC[IN_INTER; IN_ELIM_THM; IN_DIFF] THEN
    ASM_SIMP_TAC[SUBSET_INTER; CLOSURE_OF_SUBSET]]);;

let LAVRENTIEV_EXTENSION = prove
 (`!top s top' (f:A->B).
        s SUBSET topspace top /\
        (metrizable_space top \/ topspace top SUBSET top closure_of s) /\
        completely_metrizable_space top' /\
        continuous_map(subtopology top s,top') f
        ==> ?u g. gdelta_in top u /\
                  s SUBSET u /\
                  u SUBSET top closure_of s /\
                  continuous_map(subtopology top u,top') g /\
                  !x. x IN s ==> g x = f x`,
  REPEAT GEN_TAC THEN
  DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  MP_TAC(ISPECL [`top:A topology`; `s:A->bool`; `top':B topology`; `f:A->B`]
    LAVRENTIEV_EXTENSION_GEN) THEN
  ASM_REWRITE_TAC[] THEN ONCE_REWRITE_TAC[SWAP_EXISTS_THM] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `g:A->B` THEN
  DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `top closure_of s INTER u:A->bool` THEN
  ASM_SIMP_TAC[INTER_SUBSET; SUBSET_INTER; CLOSURE_OF_SUBSET] THEN
  FIRST_X_ASSUM DISJ_CASES_TAC THENL
   [MATCH_MP_TAC GDELTA_IN_INTER THEN
    ASM_SIMP_TAC[CLOSED_IMP_GDELTA_IN; CLOSED_IN_CLOSURE_OF];
    FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP (MESON[]
     `gdelta_in top s ==> t = s ==> gdelta_in top t`)) THEN
    REWRITE_TAC[SET_RULE `c INTER u = u <=> u SUBSET c`] THEN
    ASM_MESON_TAC[SUBSET_TRANS; GDELTA_IN_SUBSET]]);;

(* ------------------------------------------------------------------------- *)
(* Extending Cauchy continuous functions to the closure.                     *)
(* ------------------------------------------------------------------------- *)

let CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CONTINUOUS_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s.
        mcomplete m2 /\ cauchy_continuous_map (submetric m1 s,m2) f
        ==> ?g. continuous_map
                 (subtopology (mtopology m1) (mtopology m1 closure_of s),
                  mtopology m2) g /\
                !x. x IN s ==> g x = f x`,
  GEN_TAC THEN GEN_TAC THEN GEN_TAC THEN
  MATCH_MP_TAC(MESON[]
   `!m. ((!s. s SUBSET mspace m ==> P s) ==> (!s. P s)) /\
        (!s. s SUBSET mspace m ==> P s)
        ==> !s. P s`) THEN
  EXISTS_TAC `m1:A metric` THEN CONJ_TAC THENL
   [DISCH_TAC THEN X_GEN_TAC `s:A->bool` THEN STRIP_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPEC `mspace m1 INTER s:A->bool`) THEN
    ASM_REWRITE_TAC[GSYM SUBMETRIC_SUBMETRIC; SUBMETRIC_MSPACE] THEN
    REWRITE_TAC[INTER_SUBSET; GSYM TOPSPACE_MTOPOLOGY] THEN
    REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT; IN_INTER] THEN
    DISCH_THEN(X_CHOOSE_THEN `g:A->B` STRIP_ASSUME_TAC) THEN EXISTS_TAC
     `\x. if x IN topspace(mtopology m1) then (g:A->B) x else f x` THEN
    ASM_SIMP_TAC[COND_ID] THEN MATCH_MP_TAC CONTINUOUS_MAP_EQ THEN
    EXISTS_TAC `g:A->B` THEN ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER];
    ALL_TAC] THEN
  REPEAT STRIP_TAC THEN
  MATCH_MP_TAC CONTINUOUS_MAP_EXTENSION_POINTWISE_ALT THEN
  REWRITE_TAC[REGULAR_SPACE_MTOPOLOGY; SUBSET_REFL] THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBSET; TOPSPACE_MTOPOLOGY] THEN
  ASM_SIMP_TAC[CAUCHY_CONTINUOUS_IMP_CONTINUOUS_MAP;
               GSYM MTOPOLOGY_SUBMETRIC; IN_DIFF] THEN
  X_GEN_TAC `a:A` THEN STRIP_TAC THEN FIRST_ASSUM
   (MP_TAC o GEN_REWRITE_RULE RAND_CONV [CLOSURE_OF_SEQUENTIALLY]) THEN
  REWRITE_TAC[IN_ELIM_THM; IN_INTER; FORALL_AND_THM] THEN
  DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
   (X_CHOOSE_THEN `x:num->A` STRIP_ASSUME_TAC)) THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ_ALT]
      CONVERGENT_IMP_CAUCHY_IN)) THEN
  ASM_REWRITE_TAC[] THEN DISCH_TAC THEN FIRST_ASSUM(MP_TAC o
    SPEC `x:num->A` o REWRITE_RULE[cauchy_continuous_map]) THEN
  ASM_REWRITE_TAC[CAUCHY_IN_SUBMETRIC] THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o SPEC `(f:A->B) o (x:num->A)` o
    REWRITE_RULE[mcomplete]) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_EXISTS THEN
  X_GEN_TAC `l:B` THEN DISCH_TAC THEN
  FIRST_ASSUM(MP_TAC o CONJUNCT1 o REWRITE_RULE[limit]) THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN DISCH_TAC THEN
  ASM_REWRITE_TAC[LIMIT_ATPOINTOF_SEQUENTIALLY_WITHIN] THEN
  X_GEN_TAC `y:num->A` THEN
  REWRITE_TAC[IN_INTER; IN_DELETE; FORALL_AND_THM] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o
   SPEC `\n. if EVEN n then x(n DIV 2):A else y(n DIV 2)` o
   REWRITE_RULE[cauchy_continuous_map]) THEN
  REWRITE_TAC[CAUCHY_IN_INTERLEAVING_GEN; o_DEF; COND_RAND] THEN
  ASM_REWRITE_TAC[SUBMETRIC; CAUCHY_IN_SUBMETRIC] THEN ANTS_TAC THENL
   [CONJ_TAC THENL [ASM_MESON_TAC[CONVERGENT_IMP_CAUCHY_IN]; ALL_TAC] THEN
    MAP_EVERY UNDISCH_TAC
     [`limit (mtopology m1) y (a:A) sequentially`;
      `limit (mtopology m1) x (a:A) sequentially`] THEN
    REWRITE_TAC[IMP_IMP] THEN
    GEN_REWRITE_TAC (LAND_CONV o BINOP_CONV) [LIMIT_METRIC_DIST_NULL] THEN
    ASM_REWRITE_TAC[EVENTUALLY_TRUE] THEN
    DISCH_THEN(MP_TAC o MATCH_MP LIMIT_REAL_ADD) THEN
    REWRITE_TAC[REAL_ADD_LID] THEN MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT]
      LIMIT_NULL_REAL_COMPARISON) THEN
    MATCH_MP_TAC ALWAYS_EVENTUALLY THEN REWRITE_TAC[] THEN GEN_TAC THEN
    MATCH_MP_TAC(METRIC_ARITH
      `a IN mspace m /\ x IN mspace m /\ y IN mspace m
       ==> abs(mdist m (x,y)) <= abs(mdist m (x,a) + mdist m (y,a))`) THEN
    ASM_REWRITE_TAC[];
    DISCH_THEN(MP_TAC o CONJUNCT2 o CONJUNCT2) THEN
    GEN_REWRITE_TAC RAND_CONV [LIMIT_METRIC_DIST_NULL] THEN
    UNDISCH_TAC `limit (mtopology m2) ((f:A->B) o x) l sequentially` THEN
    GEN_REWRITE_TAC LAND_CONV [LIMIT_METRIC_DIST_NULL] THEN
    SIMP_TAC[o_DEF] THEN
    REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
    REWRITE_TAC[IMP_IMP] THEN
    DISCH_THEN(MP_TAC o MATCH_MP LIMIT_REAL_ADD) THEN
    REWRITE_TAC[REAL_ADD_RID] THEN
    DISCH_THEN(fun th -> CONJ_TAC THEN MP_TAC th) THENL
     [DISCH_THEN(K ALL_TAC) THEN MATCH_MP_TAC ALWAYS_EVENTUALLY THEN
      FIRST_ASSUM(MP_TAC o MATCH_MP CAUCHY_CONTINUOUS_MAP_IMAGE) THEN
      REWRITE_TAC[SUBMETRIC] THEN ASM SET_TAC[];
      MATCH_MP_TAC(REWRITE_RULE[IMP_CONJ_ALT]
        LIMIT_NULL_REAL_COMPARISON) THEN
      MATCH_MP_TAC ALWAYS_EVENTUALLY THEN REWRITE_TAC[] THEN GEN_TAC THEN
      MATCH_MP_TAC(METRIC_ARITH
       `a IN mspace m /\ x IN mspace m /\ y IN mspace m
        ==> abs(mdist m (y,a)) <= abs(mdist m (x,a) + mdist m (x,y))`) THEN
      FIRST_ASSUM(MP_TAC o MATCH_MP CAUCHY_CONTINUOUS_MAP_IMAGE) THEN
      REWRITE_TAC[SUBMETRIC] THEN ASM SET_TAC[]]]);;

let CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CONTINUOUS_INTERMEDIATE_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s t.
        mcomplete m2 /\ cauchy_continuous_map (submetric m1 s,m2) f /\
        t SUBSET mtopology m1 closure_of s
        ==> ?g. continuous_map(subtopology (mtopology m1) t,mtopology m2) g /\
                !x. x IN s ==> g x = f x`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m1:A metric`; `m2:B metric`; `f:A->B`; `s:A->bool`]
        CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CONTINUOUS_CLOSURE_OF) THEN
  ASM_REWRITE_TAC[] THEN
  ASM_MESON_TAC[CONTINUOUS_MAP_FROM_SUBTOPOLOGY_MONO]);;

let LIPSCHITZ_CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE = prove
 (`!m1 m2 f:A->B s t.
        s SUBSET t /\ t SUBSET (mtopology m1) closure_of s /\
        continuous_map (subtopology (mtopology m1) t,mtopology m2) f /\
        lipschitz_continuous_map (submetric m1 s,m2) f
        ==> lipschitz_continuous_map (submetric m1 t,m2) f`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
  SUBGOAL_THEN `submetric m1 (s:A->bool) = submetric m1 (mspace m1 INTER s)`
  SUBST1_TAC THENL
   [REWRITE_TAC[GSYM SUBMETRIC_SUBMETRIC; SUBMETRIC_MSPACE];
    DISCH_THEN(CONJUNCTS_THEN2
     (MP_TAC o SPEC `mspace m1:A->bool` o MATCH_MP (SET_RULE
       `s SUBSET t ==> !u. u INTER s SUBSET u /\ u INTER s SUBSET t`))
     MP_TAC) THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
    SPEC_TAC(`mspace m1 INTER (s:A->bool)`,`s:A->bool`)] THEN
  GEN_TAC THEN DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  SUBGOAL_THEN `(t:A->bool) SUBSET mspace m1` ASSUME_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[closure_of; TOPSPACE_MTOPOLOGY]) THEN
    ASM SET_TAC[];
    FIRST_ASSUM(MP_TAC o CONJUNCT1 o REWRITE_RULE[CONTINUOUS_MAP])] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[LIPSCHITZ_CONTINUOUS_MAP_POS] THEN
  ASM_SIMP_TAC[SUBMETRIC; SET_RULE `s SUBSET u ==> s INTER u = s`;
               SET_RULE `s SUBSET u ==> u INTER s = s`] THEN
  DISCH_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `B:real` THEN STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN
  MP_TAC(ISPECL
   [`prod_topology (subtopology (mtopology m1) (t:A->bool))
                   (subtopology (mtopology m1) (t:A->bool))`;
    `\z. mdist m2 ((f:A->B) (FST z),f(SND z)) <= B * mdist m1 (FST z,SND z)`;
    `s CROSS (s:A->bool)`] FORALL_IN_CLOSURE_OF) THEN
  ASM_REWRITE_TAC[CLOSURE_OF_CROSS; FORALL_PAIR_THM; IN_CROSS] THEN
  REWRITE_TAC[CLOSURE_OF_SUBTOPOLOGY] THEN ASM_SIMP_TAC[SET_RULE
   `s SUBSET t ==> t INTER s = s /\ s INTER t = s`] THEN
  ANTS_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
  ONCE_REWRITE_TAC[GSYM REAL_SUB_LE] THEN REWRITE_TAC[SET_RULE
   `{x | x IN s /\ &0 <= f x} = {x | x IN s /\ f x IN {y | &0 <= y}}`] THEN
  MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE THEN
  EXISTS_TAC `euclideanreal` THEN REWRITE_TAC[GSYM REAL_CLOSED_IN] THEN
  REWRITE_TAC[REWRITE_RULE[real_ge] REAL_CLOSED_HALFSPACE_GE] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB THEN CONJ_TAC THENL
   [MATCH_MP_TAC CONTINUOUS_MAP_REAL_LMUL THEN
    GEN_REWRITE_TAC (RAND_CONV o ABS_CONV o RAND_CONV) [GSYM PAIR];
    ALL_TAC] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_MDIST THENL
   [ALL_TAC;
    CONJ_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
    MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
    EXISTS_TAC `subtopology (mtopology m1) (t:A->bool)`] THEN
  REPEAT CONJ_TAC THEN
  TRY(MATCH_MP_TAC CONTINUOUS_MAP_INTO_SUBTOPOLOGY THEN
      REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; IMAGE_FST_CROSS; IMAGE_SND_CROSS;
                  INTER_CROSS] THEN
      REWRITE_TAC[TOPSPACE_SUBTOPOLOGY] THEN
      CONJ_TAC THENL [ALL_TAC; SET_TAC[]]) THEN
  ASM_REWRITE_TAC[GSYM SUBTOPOLOGY_CROSS] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_FROM_SUBTOPOLOGY THEN
  REWRITE_TAC[CONTINUOUS_MAP_FST; CONTINUOUS_MAP_SND]);;

let LIPSCHITZ_CONTINUOUS_MAP_EXTENDS_TO_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s.
        mcomplete m2 /\ lipschitz_continuous_map (submetric m1 s,m2) f
        ==> ?g. lipschitz_continuous_map
                   (submetric m1 (mtopology m1 closure_of s),m2) g /\
                !x. x IN s ==> g x = f x`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m1:A metric`; `m2:B metric`; `f:A->B`; `s:A->bool`]
         CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CONTINUOUS_CLOSURE_OF) THEN
  ASM_SIMP_TAC[LIPSCHITZ_IMP_CAUCHY_CONTINUOUS_MAP] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `g:A->B` THEN STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE THEN
  EXISTS_TAC `mspace m1 INTER s:A->bool` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_INTER; GSYM TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT; SUBSET_REFL] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY; GSYM SUBMETRIC_RESTRICT] THEN
  MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_MAP_EQ THEN EXISTS_TAC `f:A->B` THEN
  ASM_SIMP_TAC[SUBMETRIC; IN_INTER]);;

let LIPSCHITZ_CONTINUOUS_MAP_EXTENDS_TO_INTERMEDIATE_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s t.
        mcomplete m2 /\
        lipschitz_continuous_map (submetric m1 s,m2) f /\
        t SUBSET mtopology m1 closure_of s
        ==> ?g. lipschitz_continuous_map (submetric m1 t,m2) g /\
                !x. x IN s ==> g x = f x`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m1:A metric`; `m2:B metric`; `f:A->B`; `s:A->bool`]
        LIPSCHITZ_CONTINUOUS_MAP_EXTENDS_TO_CLOSURE_OF) THEN
  ASM_REWRITE_TAC[] THEN
  ASM_MESON_TAC[LIPSCHITZ_CONTINUOUS_MAP_FROM_SUBMETRIC_MONO]);;

let UNIFORMLY_CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE = prove
 (`!m1 m2 f:A->B s t.
        s SUBSET t /\ t SUBSET (mtopology m1) closure_of s /\
        continuous_map (subtopology (mtopology m1) t,mtopology m2) f /\
        uniformly_continuous_map (submetric m1 s,m2) f
        ==> uniformly_continuous_map (submetric m1 t,m2) f`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
  SUBGOAL_THEN `submetric m1 (s:A->bool) = submetric m1 (mspace m1 INTER s)`
  SUBST1_TAC THENL
   [REWRITE_TAC[GSYM SUBMETRIC_SUBMETRIC; SUBMETRIC_MSPACE];
    DISCH_THEN(CONJUNCTS_THEN2
     (MP_TAC o SPEC `mspace m1:A->bool` o MATCH_MP (SET_RULE
       `s SUBSET t ==> !u. u INTER s SUBSET u /\ u INTER s SUBSET t`))
     MP_TAC) THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
    SPEC_TAC(`mspace m1 INTER (s:A->bool)`,`s:A->bool`)] THEN
  GEN_TAC THEN DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  SUBGOAL_THEN `(t:A->bool) SUBSET mspace m1` ASSUME_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[closure_of; TOPSPACE_MTOPOLOGY]) THEN
    ASM SET_TAC[];
    FIRST_ASSUM(MP_TAC o CONJUNCT1 o REWRITE_RULE[CONTINUOUS_MAP])] THEN
  REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[uniformly_continuous_map] THEN
  ASM_SIMP_TAC[SUBMETRIC; SET_RULE `s SUBSET u ==> s INTER u = s`;
               SET_RULE `s SUBSET u ==> u INTER s = s`] THEN
  DISCH_TAC THEN STRIP_TAC THEN X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN ASM_REWRITE_TAC[REAL_HALF] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `d:real` THEN STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN
  MP_TAC(ISPECL
   [`prod_topology (subtopology (mtopology m1) (t:A->bool))
                   (subtopology (mtopology m1) (t:A->bool))`;
    `\z. mdist m1 (FST z,SND z) < d
         ==> mdist m2 ((f:A->B) (FST z),f(SND z)) <= e / &2`;
    `s CROSS (s:A->bool)`] FORALL_IN_CLOSURE_OF) THEN
  ASM_REWRITE_TAC[CLOSURE_OF_CROSS; FORALL_PAIR_THM; IN_CROSS] THEN
  REWRITE_TAC[CLOSURE_OF_SUBTOPOLOGY] THEN ASM_SIMP_TAC[SET_RULE
   `s SUBSET t ==> t INTER s = s /\ s INTER t = s`] THEN ANTS_TAC THENL
   [ASM_SIMP_TAC[REAL_LT_IMP_LE];
    ASM_MESON_TAC[REAL_ARITH `&0 < e /\ x <= e / &2 ==> x < e`]] THEN
  ONCE_REWRITE_TAC[GSYM REAL_NOT_LE] THEN
  ONCE_REWRITE_TAC[GSYM REAL_SUB_LE] THEN
  REWRITE_TAC[SET_RULE
   `{x | x IN s /\ (~(&0 <= f x) ==> &0 <= g x)} =
    {x | x IN s /\ g x IN {y | &0 <= y}} UNION
    {x | x IN s /\ f x IN {y | &0 <= y}}`] THEN
  MATCH_MP_TAC CLOSED_IN_UNION THEN CONJ_TAC THEN
  MATCH_MP_TAC CLOSED_IN_CONTINUOUS_MAP_PREIMAGE THEN
  EXISTS_TAC `euclideanreal` THEN REWRITE_TAC[GSYM REAL_CLOSED_IN] THEN
  REWRITE_TAC[REWRITE_RULE[real_ge] REAL_CLOSED_HALFSPACE_GE] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_REAL_SUB THEN
  REWRITE_TAC[CONTINUOUS_MAP_CONST; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_MDIST_ALT THEN
  REWRITE_TAC[CONTINUOUS_MAP_PAIRWISE; o_DEF; GSYM SUBTOPOLOGY_CROSS] THEN
  SIMP_TAC[CONTINUOUS_MAP_FST; CONTINUOUS_MAP_SND; ETA_AX;
           CONTINUOUS_MAP_FROM_SUBTOPOLOGY] THEN
  CONJ_TAC THEN GEN_REWRITE_TAC RAND_CONV [GSYM o_DEF] THEN
  MATCH_MP_TAC CONTINUOUS_MAP_COMPOSE THEN
  EXISTS_TAC `subtopology (mtopology m1) (t:A->bool)` THEN
  ASM_SIMP_TAC[SUBTOPOLOGY_CROSS; CONTINUOUS_MAP_FST; CONTINUOUS_MAP_SND]);;

let UNIFORMLY_CONTINUOUS_MAP_EXTENDS_TO_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s.
        mcomplete m2 /\ uniformly_continuous_map (submetric m1 s,m2) f
        ==> ?g. uniformly_continuous_map
                   (submetric m1 (mtopology m1 closure_of s),m2) g /\
                !x. x IN s ==> g x = f x`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m1:A metric`; `m2:B metric`; `f:A->B`; `s:A->bool`]
         CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CONTINUOUS_CLOSURE_OF) THEN
  ASM_SIMP_TAC[UNIFORMLY_IMP_CAUCHY_CONTINUOUS_MAP] THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `g:A->B` THEN STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE THEN
  EXISTS_TAC `mspace m1 INTER s:A->bool` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_INTER; GSYM TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT; SUBSET_REFL] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY; GSYM SUBMETRIC_RESTRICT] THEN
  MATCH_MP_TAC UNIFORMLY_CONTINUOUS_MAP_EQ THEN EXISTS_TAC `f:A->B` THEN
  ASM_SIMP_TAC[SUBMETRIC; IN_INTER]);;

let UNIFORMLY_CONTINUOUS_MAP_EXTENDS_TO_INTERMEDIATE_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s t.
        mcomplete m2 /\
        uniformly_continuous_map (submetric m1 s,m2) f /\
        t SUBSET mtopology m1 closure_of s
        ==> ?g. uniformly_continuous_map (submetric m1 t,m2) g /\
                !x. x IN s ==> g x = f x`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m1:A metric`; `m2:B metric`; `f:A->B`; `s:A->bool`]
        UNIFORMLY_CONTINUOUS_MAP_EXTENDS_TO_CLOSURE_OF) THEN
  ASM_REWRITE_TAC[] THEN
  ASM_MESON_TAC[UNIFORMLY_CONTINUOUS_MAP_FROM_SUBMETRIC_MONO]);;

let CAUCHY_CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE = prove
 (`!m1 m2 f:A->B s t.
        s SUBSET t /\ t SUBSET (mtopology m1) closure_of s /\
        continuous_map (subtopology (mtopology m1) t,mtopology m2) f /\
        cauchy_continuous_map (submetric m1 s,m2) f
        ==> cauchy_continuous_map (submetric m1 t,m2) f`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
  SUBGOAL_THEN `submetric m1 (s:A->bool) = submetric m1 (mspace m1 INTER s)`
  SUBST1_TAC THENL
   [REWRITE_TAC[GSYM SUBMETRIC_SUBMETRIC; SUBMETRIC_MSPACE];
    DISCH_THEN(CONJUNCTS_THEN2
     (MP_TAC o SPEC `mspace m1:A->bool` o MATCH_MP (SET_RULE
       `s SUBSET t ==> !u. u INTER s SUBSET u /\ u INTER s SUBSET t`))
     MP_TAC) THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN
    SPEC_TAC(`mspace m1 INTER (s:A->bool)`,`s:A->bool`)] THEN
  GEN_TAC THEN DISCH_THEN(fun th -> STRIP_TAC THEN MP_TAC th) THEN
  REPEAT(DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC)) THEN
  SUBGOAL_THEN `(t:A->bool) SUBSET mspace m1` ASSUME_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[closure_of; TOPSPACE_MTOPOLOGY]) THEN
    ASM SET_TAC[];
    DISCH_TAC] THEN
  REWRITE_TAC[cauchy_continuous_map; CAUCHY_IN_SUBMETRIC] THEN
  X_GEN_TAC `x:num->A` THEN STRIP_TAC THEN
  SUBGOAL_THEN
   `!n. ?y. y IN s /\
            mdist m1 (x n,y) < inv(&n + &1) /\
            mdist m2 ((f:A->B)(x n),f y) < inv(&n + &1)`
  MP_TAC THENL
   [X_GEN_TAC `n:num` THEN
    RULE_ASSUM_TAC(REWRITE_RULE[GSYM MTOPOLOGY_SUBMETRIC]) THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [METRIC_CONTINUOUS_MAP]) THEN
    ASM_SIMP_TAC[SUBMETRIC; SET_RULE `s SUBSET u ==> s INTER u = s`] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    DISCH_THEN(MP_TAC o SPECL [`(x:num->A) n`; `inv(&n + &1)`]) THEN
    ASM_REWRITE_TAC[REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
    DISCH_THEN(X_CHOOSE_THEN `d:real` STRIP_ASSUME_TAC) THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE RAND_CONV [METRIC_CLOSURE_OF]) THEN
    REWRITE_TAC[SUBSET; IN_ELIM_THM; IN_MBALL] THEN
    DISCH_THEN(MP_TAC o SPEC `(x:num->A) n`) THEN ASM_REWRITE_TAC[] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC
     (MP_TAC o SPEC `min d (inv(&n + &1))`)) THEN
    ASM_SIMP_TAC[REAL_LT_MIN; REAL_LT_INV_EQ; REAL_ARITH `&0 < &n + &1`] THEN
    MATCH_MP_TAC MONO_EXISTS THEN ASM SET_TAC[];
    REWRITE_TAC[SKOLEM_THM; FORALL_AND_THM; LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `y:num->A` THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [cauchy_continuous_map]) THEN
  DISCH_THEN(MP_TAC o SPEC `y:num->A`) THEN
  ASM_SIMP_TAC[CAUCHY_IN_SUBMETRIC; SUBMETRIC; SET_RULE
   `s SUBSET u ==> s INTER u = s`] THEN
  ANTS_TAC THENL [UNDISCH_TAC `cauchy_in m1 (x:num->A)`; ALL_TAC] THEN
  ASM_REWRITE_TAC[cauchy_in; o_THM] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o CONJUNCT1 o GEN_REWRITE_RULE I [continuous_map]) THEN
  ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; TOPSPACE_MTOPOLOGY;
               SET_RULE `s SUBSET t ==> t INTER s = s`] THEN
  DISCH_TAC THEN TRY(CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC]) THEN
  X_GEN_TAC `e:real` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `e / &2`) THEN ASM_REWRITE_TAC[REAL_HALF] THEN
  DISCH_THEN(X_CHOOSE_TAC `M:num`) THEN
  MP_TAC(SPEC `e / &4` ARCH_EVENTUALLY_INV1) THEN
  ASM_REWRITE_TAC[REAL_ARITH `&0 < e / &4 <=> &0 < e`] THEN
  REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN
  DISCH_THEN(X_CHOOSE_TAC `N:num`) THEN EXISTS_TAC `MAX M N` THEN
  ASM_REWRITE_TAC[ARITH_RULE `MAX M N <= n <=> M <= n /\ N <= n`] THEN
  MAP_EVERY X_GEN_TAC [`m:num`; `n:num`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`m:num`; `n:num`]) THEN
  ASM_REWRITE_TAC[] THENL
   [MATCH_MP_TAC(METRIC_ARITH
     `(x IN mspace m /\ x' IN mspace m /\ y IN mspace m /\ y' IN mspace m) /\
      (mdist m (x,y) < e / &4 /\ mdist m (x',y') < e / &4)
      ==> mdist m (x,x') < e / &2 ==> mdist m (y,y') < e`);
    MATCH_MP_TAC(METRIC_ARITH
     `(x IN mspace m /\ x' IN mspace m /\ y IN mspace m /\ y' IN mspace m) /\
      (mdist m (x,y) < e / &4 /\ mdist m (x',y') < e / &4)
      ==> mdist m (y,y') < e / &2 ==> mdist m (x,x') < e`)] THEN
  (CONJ_TAC THENL [ASM SET_TAC[]; ASM_MESON_TAC[REAL_LT_TRANS]]));;

let CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s.
        mcomplete m2 /\ cauchy_continuous_map (submetric m1 s,m2) f
        ==> ?g. cauchy_continuous_map
                   (submetric m1 (mtopology m1 closure_of s),m2) g /\
                !x. x IN s ==> g x = f x`,
  REPEAT GEN_TAC THEN DISCH_TAC THEN FIRST_ASSUM(MP_TAC o MATCH_MP
    CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CONTINUOUS_CLOSURE_OF) THEN
  MATCH_MP_TAC MONO_EXISTS THEN X_GEN_TAC `g:A->B` THEN STRIP_TAC THEN
  ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_ON_INTERMEDIATE_CLOSURE THEN
  EXISTS_TAC `mspace m1 INTER s:A->bool` THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_INTER; GSYM TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[GSYM CLOSURE_OF_RESTRICT; SUBSET_REFL] THEN
  REWRITE_TAC[TOPSPACE_MTOPOLOGY; GSYM SUBMETRIC_RESTRICT] THEN
  MATCH_MP_TAC CAUCHY_CONTINUOUS_MAP_EQ THEN EXISTS_TAC `f:A->B` THEN
  ASM_SIMP_TAC[SUBMETRIC; IN_INTER]);;

let CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_INTERMEDIATE_CLOSURE_OF = prove
 (`!m1 m2 (f:A->B) s t.
        mcomplete m2 /\
        cauchy_continuous_map (submetric m1 s,m2) f /\
        t SUBSET mtopology m1 closure_of s
        ==> ?g. cauchy_continuous_map (submetric m1 t,m2) g /\
                !x. x IN s ==> g x = f x`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m1:A metric`; `m2:B metric`; `f:A->B`; `s:A->bool`]
        CAUCHY_CONTINUOUS_MAP_EXTENDS_TO_CLOSURE_OF) THEN
  ASM_REWRITE_TAC[] THEN
  ASM_MESON_TAC[CAUCHY_CONTINUOUS_MAP_FROM_SUBMETRIC_MONO]);;

(* ------------------------------------------------------------------------- *)
(* Contractions.                                                             *)
(* ------------------------------------------------------------------------- *)

let CONTRACTION_IMP_UNIQUE_FIXPOINT = prove
 (`!m (f:A->A) k x y.
     k < &1 /\
     (!x. x IN mspace m ==> f x IN mspace m) /\
     (!x y. x IN mspace m /\ y IN mspace m
            ==> mdist m (f x, f y) <= k * mdist m (x,y)) /\
     x IN mspace m /\ y IN mspace m /\ f x = x /\ f y = y
     ==> x = y`,
  INTRO_TAC "!m f k x y; k f le x y xeq yeq" THEN
  ASM_CASES_TAC `x:A = y` THENL [POP_ASSUM ACCEPT_TAC; ALL_TAC] THEN
  REMOVE_THEN "le" (MP_TAC o SPECL[`x:A`;`y:A`]) THEN ASM_REWRITE_TAC[] THEN
  CUT_TAC `&0 < (&1 - k) * mdist m (x:A,y:A)` THENL
  [REAL_ARITH_TAC;
   MATCH_MP_TAC REAL_LT_MUL THEN ASM_SIMP_TAC[MDIST_POS_LT] THEN
   ASM_REAL_ARITH_TAC]);;

(* ------------------------------------------------------------------------- *)
(* Banach Fixed-Point Theorem (aka, Contraction Mapping Principle).          *)
(* ------------------------------------------------------------------------- *)

let BANACH_FIXPOINT_THM = prove
 (`!m f:A->A k.
     ~(mspace m = {}) /\
     mcomplete m /\
     (!x. x IN mspace m ==> f x IN mspace m) /\
     k < &1 /\
     (!x y. x IN mspace m /\ y IN mspace m
            ==> mdist m (f x, f y) <= k * mdist m (x,y))
     ==> (?!x. x IN mspace m /\ f x = x)`,
  INTRO_TAC "!m f k; ne compl 4 k1 contr" THEN REMOVE_THEN "ne" MP_TAC THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN INTRO_TAC "@a. aINm" THEN
  REWRITE_TAC[EXISTS_UNIQUE_THM] THEN CONJ_TAC THENL
  [ALL_TAC;
   REPEAT STRIP_TAC THEN MATCH_MP_TAC CONTRACTION_IMP_UNIQUE_FIXPOINT THEN
   ASM_MESON_TAC[]] THEN
  ASM_CASES_TAC `!x:A. x IN mspace m ==> f x:A = f a` THENL
  [ASM_MESON_TAC[]; POP_ASSUM (LABEL_TAC "nonsing")] THEN
  CLAIM_TAC "kpos" `&0 < k` THENL
  [MATCH_MP_TAC (ISPECL [`m:A metric`; `m:A metric`; `f:A->A`]
     LIPSCHITZ_COEFFICIENT_POS) THEN
   ASM_SIMP_TAC[] THEN ASM_MESON_TAC[];
   ALL_TAC] THEN
  CLAIM_TAC "fINm" `!n:num. (ITER n f (a:A)) IN mspace m` THENL
  [LABEL_INDUCT_TAC THEN ASM_SIMP_TAC[ITER]; ALL_TAC] THEN
  ASM_CASES_TAC `f a = a:A` THENL
  [ASM_MESON_TAC[]; POP_ASSUM (LABEL_TAC "aneq")] THEN
  CUT_TAC `cauchy_in (m:A metric) (\n. ITER n f (a:A))` THENL
  [DISCH_THEN (fun cauchy -> HYP_TAC "compl : @l. lim"
    (C MATCH_MP cauchy o REWRITE_RULE[mcomplete])) THEN
   EXISTS_TAC `l:A` THEN CONJ_TAC THENL
   [ASM_MESON_TAC [LIMIT_IN_MSPACE]; ALL_TAC] THEN
   MATCH_MP_TAC
     (ISPECL [`sequentially`; `m:A metric`; `(\n. ITER n f a:A)`]
             LIMIT_METRIC_UNIQUE) THEN
   ASM_REWRITE_TAC[TRIVIAL_LIMIT_SEQUENTIALLY] THEN
   MATCH_MP_TAC LIMIT_SEQUENTIALLY_OFFSET_REV THEN
   EXISTS_TAC `1` THEN REWRITE_TAC[GSYM ADD1] THEN
   SUBGOAL_THEN `(\i. ITER (SUC i) f (a:A)) = f o (\i. ITER i f a)`
     SUBST1_TAC THENL [REWRITE_TAC[FUN_EQ_THM; o_THM; ITER]; ALL_TAC] THEN
   MATCH_MP_TAC CONTINUOUS_MAP_LIMIT THEN
   EXISTS_TAC `mtopology (m:A metric)` THEN ASM_REWRITE_TAC[] THEN
   MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_IMP_CONTINUOUS_MAP THEN
   ASM_REWRITE_TAC[lipschitz_continuous_map; SUBSET; FORALL_IN_IMAGE] THEN
   EXISTS_TAC `k:real` THEN ASM_REWRITE_TAC[];
   ALL_TAC] THEN
  CLAIM_TAC "k1'" `&0 < &1 - k` THENL [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
  ASM_SIMP_TAC[cauchy_in] THEN INTRO_TAC "!e; e" THEN
  CLAIM_TAC "@N. N" `?N. k pow N < ((&1 - k) * e) / mdist m (a:A,f a)` THENL
  [MATCH_MP_TAC REAL_ARCH_POW_INV THEN
   ASM_SIMP_TAC[REAL_LT_DIV; MDIST_POS_LT; REAL_LT_MUL];
   EXISTS_TAC `N:num`] THEN
  MATCH_MP_TAC WLOG_LT THEN ASM_SIMP_TAC[MDIST_REFL] THEN CONJ_TAC THENL
  [HYP MESON_TAC "fINm" [MDIST_SYM]; ALL_TAC] THEN
  INTRO_TAC "!n n'; lt; le le'" THEN
  TRANS_TAC REAL_LET_TRANS
    `sum (n..n'-1) (\i. mdist m (ITER i f a:A, ITER (SUC i) f a))` THEN
  CONJ_TAC THENL
  [REMOVE_THEN "lt" MP_TAC THEN SPEC_TAC (`n':num`,`n':num`) THEN
   LABEL_INDUCT_TAC THENL [REWRITE_TAC[LT]; REWRITE_TAC[LT_SUC_LE]] THEN
   INTRO_TAC "nle" THEN HYP_TAC "nle : nlt | neq" (REWRITE_RULE[LE_LT]) THENL
   [ALL_TAC;
    POP_ASSUM SUBST_ALL_TAC THEN
    REWRITE_TAC[ITER;
      ARITH_RULE `SUC n'' - 1 = n''`; SUM_SING_NUMSEG; REAL_LE_REFL]] THEN
   USE_THEN "nlt" (HYP_TAC "ind_n'" o C MATCH_MP) THEN REWRITE_TAC[ITER] THEN
   TRANS_TAC REAL_LE_TRANS
     `mdist m (ITER n f a:A,ITER n'' f a) +
      mdist m (ITER n'' f a,f (ITER n'' f a))` THEN
   ASM_SIMP_TAC[MDIST_TRIANGLE] THEN
   SUBGOAL_THEN `SUC n'' - 1 = SUC (n'' - 1)` SUBST1_TAC THENL
   [ASM_ARITH_TAC; ASM_SIMP_TAC[SUM_CLAUSES_NUMSEG]] THEN
   SUBGOAL_THEN `SUC (n'' - 1) = n''` SUBST1_TAC THENL
   [ASM_ARITH_TAC; ASM_SIMP_TAC[LT_IMP_LE; REAL_LE_RADD]] THEN
   REMOVE_THEN "ind_n'" (ACCEPT_TAC o REWRITE_RULE[ITER]);
   ALL_TAC] THEN
  TRANS_TAC REAL_LET_TRANS
     `sum (n..n'-1) (\i. mdist m (a:A, f a) * k pow i)` THEN CONJ_TAC THENL
  [MATCH_MP_TAC SUM_LE_NUMSEG THEN
   CUT_TAC `!i. mdist m (ITER i f a,ITER (SUC i) f a) <=
                mdist m (a:A,f a) * k pow i` THENL
   [SIMP_TAC[ITER]; ALL_TAC] THEN
   LABEL_INDUCT_TAC THENL
   [REWRITE_TAC[ITER; real_pow; REAL_MUL_RID; REAL_LE_REFL];
    HYP_TAC "ind_i" (REWRITE_RULE[ITER]) THEN
    TRANS_TAC REAL_LE_TRANS `k * mdist m (ITER i f a:A, f (ITER i f a))` THEN
    ASM_SIMP_TAC[real_pow; REAL_LE_LMUL_EQ; ITER;
      REAL_ARITH `!x. x * k * k pow i = k * x * k pow i`]];
   ALL_TAC] THEN
  REWRITE_TAC[SUM_LMUL; SUM_GP] THEN
  HYP SIMP_TAC "lt" [ARITH_RULE `n < n' ==> ~(n' - 1 < n)`] THEN
  HYP SIMP_TAC "k1" [REAL_ARITH `k < &1 ==> ~(k = &1)`] THEN
  USE_THEN "lt" (SUBST1_TAC o
    MATCH_MP (ARITH_RULE `n < n' ==> SUC (n' - 1) = n'`)) THEN
  SUBGOAL_THEN `k pow n - k pow n' = k pow n * (&1 - k pow (n' - n))`
    SUBST1_TAC THENL
  [REWRITE_TAC[REAL_SUB_LDISTRIB; REAL_MUL_RID; GSYM REAL_POW_ADD] THEN
   HYP SIMP_TAC "lt" [ARITH_RULE `n < n' ==> n + n' - n = n':num`];
   (SUBST1_TAC o REAL_ARITH)
     `mdist m (a:A,f a) * (k pow n * (&1 - k pow (n' - n))) / (&1 - k) =
      ((k pow n * (&1 - k pow (n' - n))) / (&1 - k)) * mdist m (a,f a)`] THEN
  ASM_SIMP_TAC[GSYM REAL_LT_RDIV_EQ; MDIST_POS_LT; REAL_LT_LDIV_EQ] THEN
  TRANS_TAC REAL_LET_TRANS `k pow n` THEN CONJ_TAC THENL
  [ONCE_REWRITE_TAC[GSYM REAL_SUB_LE] THEN
   REWRITE_TAC[GSYM REAL_POW_ADD;
     REAL_ARITH `k pow n - k pow n * (&1 - k pow (n' - n)) =
                 k pow n * k pow (n' - n)`] THEN
   HYP SIMP_TAC "lt" [ARITH_RULE `n < n' ==> n + n' - n = n':num`] THEN
   HYP SIMP_TAC "kpos" [REAL_POW_LE; REAL_LT_IMP_LE];
   TRANS_TAC REAL_LET_TRANS `k pow N` THEN
   ASM_SIMP_TAC[REAL_POW_MONO_INV; REAL_LT_IMP_LE;
     REAL_ARITH `e / mdist m (a:A,f a) * (&1 - k) =
                 ((&1 - k) * e) / mdist m (a,f a)`]]);;

(* ------------------------------------------------------------------------- *)
(* Metric space of bounded functions.                                        *)
(* ------------------------------------------------------------------------- *)

let funspace = new_definition
  `funspace s m =
   metric ({f:A->B | (!x. x IN s ==> f x IN mspace m) /\
                     f IN EXTENSIONAL s /\
                     mbounded m (IMAGE f s)},
           (\(f,g). if s = {} then &0 else
                    sup {mdist m (f x,g x) | x | x IN s}))`;;

let FUNSPACE = (REWRITE_RULE[GSYM FORALL_AND_THM] o prove)
 (`!s m.
     mspace (funspace s m) =
       {f:A->B | (!x. x IN s ==> f x IN mspace m) /\
                 f IN EXTENSIONAL s /\
                 mbounded m (IMAGE f s)} /\
     (!f g. mdist (funspace s m) (f,g) =
              if s = {} then &0 else
              sup {mdist m (f x,g x) | x | x IN s})`,
  REPEAT GEN_TAC THEN MAP_EVERY LABEL_ABBREV_TAC
    [`fspace = {f:A->B | (!x. x IN s ==> f x IN mspace m) /\
                         f IN EXTENSIONAL s /\
                         mbounded m (IMAGE f s)}`;
     `fdist =
        \(f,g). if s = {} then &0 else
                sup {mdist m (f x:B,g x) | x | x:A IN s}`] THEN
  CUT_TAC `mspace (funspace s m) = fspace:(A->B)->bool /\
           mdist (funspace s m:(A->B)metric) = fdist` THENL
  [EXPAND_TAC "fdist" THEN DISCH_THEN (fun th -> REWRITE_TAC[th]);
   ASM_REWRITE_TAC[funspace] THEN MATCH_MP_TAC METRIC] THEN
  ASM_CASES_TAC `s:A->bool = {}` THENL
  [POP_ASSUM SUBST_ALL_TAC THEN MAP_EVERY EXPAND_TAC ["fspace"; "fdist"] THEN
   SIMP_TAC[is_metric_space; NOT_IN_EMPTY; IN_EXTENSIONAL; IMAGE_CLAUSES;
     MBOUNDED_EMPTY; IN_ELIM_THM; REAL_LE_REFL; REAL_ADD_LID; FUN_EQ_THM];
   POP_ASSUM (LABEL_TAC "nempty")] THEN
  REMOVE_THEN "nempty" (fun th ->
    RULE_ASSUM_TAC(REWRITE_RULE[th]) THEN LABEL_TAC "nempty" th) THEN
  CLAIM_TAC "wd ext bound"
    `(!f x:A. f IN fspace /\ x IN s ==> f x:B IN mspace m) /\
     (!f. f IN fspace ==> f IN EXTENSIONAL s) /\
     (!f. f IN fspace
          ==> (?c b. c IN mspace m /\
                     (!x. x IN s ==> mdist m (c,f x) <= b)))` THENL
  [EXPAND_TAC "fspace" THEN
   ASM_SIMP_TAC[IN_ELIM_THM; MBOUNDED; IMAGE_EQ_EMPTY] THEN SET_TAC[];
   ALL_TAC] THEN
  CLAIM_TAC "bound2"
    `!f g:A->B. f IN fspace /\ g IN fspace
                ==> (?b. !x. x IN s ==> mdist m (f x,g x) <= b)` THENL
  [REMOVE_THEN "fspace" (SUBST_ALL_TAC o GSYM) THEN
   REWRITE_TAC[IN_ELIM_THM] THEN REPEAT STRIP_TAC THEN
   CUT_TAC `mbounded m (IMAGE (f:A->B) s UNION IMAGE g s)` THENL
   [REWRITE_TAC[MBOUNDED_ALT; SUBSET; IN_UNION] THEN
    STRIP_TAC THEN EXISTS_TAC `b:real` THEN ASM SET_TAC [];
    ASM_REWRITE_TAC[MBOUNDED_UNION]];
   ALL_TAC] THEN
  HYP_TAC "nempty -> @a. a" (REWRITE_RULE[GSYM MEMBER_NOT_EMPTY]) THEN
  REWRITE_TAC[is_metric_space] THEN CONJ_TAC THENL
  [INTRO_TAC "![f] [g]; f  g" THEN EXPAND_TAC "fdist" THEN
   REWRITE_TAC[] THEN MATCH_MP_TAC REAL_LE_SUP THEN
   CLAIM_TAC "@b. b" `?b. !x:A. x IN s ==> mdist m (f x:B,g x) <= b` THENL
   [HYP SIMP_TAC "bound2 f g" [];
    ALL_TAC] THEN
    MAP_EVERY EXISTS_TAC [`b:real`; `mdist m (f(a:A):B,g a)`] THEN
    REWRITE_TAC[IN_ELIM_THM] THEN HYP SIMP_TAC "wd f g a" [MDIST_POS_LE] THEN
    HYP MESON_TAC "a b" [];
    ALL_TAC] THEN
  CONJ_TAC THENL
  [INTRO_TAC "![f] [g]; f  g" THEN EXPAND_TAC "fdist" THEN
   REWRITE_TAC[] THEN EQ_TAC THENL
   [INTRO_TAC "sup0" THEN MATCH_MP_TAC (SPEC `s:A->bool` EXTENSIONAL_EQ) THEN
    HYP SIMP_TAC "f g ext" [] THEN INTRO_TAC "!x; x" THEN
    REFUTE_THEN (LABEL_TAC "neq") THEN
    CUT_TAC
      `&0 < mdist m (f (x:A):B, g x) /\
       mdist m (f x, g x) <= sup {mdist m (f x,g x) | x IN s}` THENL
    [HYP REWRITE_TAC "sup0" [] THEN REAL_ARITH_TAC; ALL_TAC] THEN
    HYP SIMP_TAC "wd f g x neq" [MDIST_POS_LT] THEN
    MATCH_MP_TAC REAL_LE_SUP THEN
    CLAIM_TAC "@B. B" `?b. !x:A. x IN s ==> mdist m (f x:B,g x) <= b` THENL
    [HYP SIMP_TAC "bound2 f g" []; ALL_TAC] THEN
    MAP_EVERY EXISTS_TAC [`B:real`; `mdist m (f (x:A):B,g x)`] THEN
    REWRITE_TAC[IN_ELIM_THM; IN_UNIV; REAL_LE_REFL] THEN
    HYP MESON_TAC "B x" [];
    DISCH_THEN (SUBST1_TAC o GSYM) THEN
    SUBGOAL_THEN `{mdist m (f x:B,f x) | x:A IN s} = {&0}`
      (fun th -> REWRITE_TAC[th; SUP_SING]) THEN
    REWRITE_TAC[EXTENSION; IN_ELIM_THM; NOT_IN_EMPTY; IN_UNIV; IN_INSERT] THEN
    HYP MESON_TAC "wd f a" [MDIST_REFL]];
   ALL_TAC] THEN
  CONJ_TAC THENL
  [INTRO_TAC "![f] [g]; f g" THEN EXPAND_TAC "fdist" THEN REWRITE_TAC[] THEN
   AP_TERM_TAC THEN REWRITE_TAC[EXTENSION; IN_ELIM_THM] THEN
   HYP MESON_TAC "wd f g" [MDIST_SYM];
   ALL_TAC] THEN
  INTRO_TAC "![f] [g] [h]; f g h" THEN EXPAND_TAC "fdist" THEN
  REWRITE_TAC[] THEN MATCH_MP_TAC REAL_SUP_LE THEN CONJ_TAC THENL
  [REWRITE_TAC[EXTENSION; IN_ELIM_THM; NOT_IN_EMPTY; IN_UNIV] THEN
   HYP MESON_TAC "a" [];
   ALL_TAC] THEN
  FIX_TAC "[d]" THEN REWRITE_TAC [IN_ELIM_THM; IN_UNIV] THEN
  INTRO_TAC "@x. x d" THEN POP_ASSUM SUBST1_TAC THEN
  CUT_TAC
    `mdist m (f (x:A):B,h x) <= mdist m (f x,g x) + mdist m (g x, h x) /\
     mdist m (f x, g x) <= fdist (f,g) /\
     mdist m (g x, h x) <= fdist (g,h)` THEN
  EXPAND_TAC "fdist" THEN REWRITE_TAC[] THENL [REAL_ARITH_TAC; ALL_TAC] THEN
  HYP SIMP_TAC "wd f g h x" [MDIST_TRIANGLE] THEN
  CONJ_TAC THEN MATCH_MP_TAC REAL_LE_SUP THENL
  [CLAIM_TAC "@B. B" `?b. !x:A. x IN s ==> mdist m (f x:B,g x) <= b` THENL
   [HYP SIMP_TAC "bound2 f g" [];
    MAP_EVERY EXISTS_TAC [`B:real`; `mdist m (f(x:A):B,g x)`]] THEN
   REWRITE_TAC[IN_ELIM_THM; IN_UNIV; REAL_LE_REFL] THEN HYP MESON_TAC "B x" [];
   CLAIM_TAC "@B. B" `?b. !x:A. x IN s ==> mdist m (g x:B,h x) <= b` THENL
   [HYP SIMP_TAC "bound2 g h" []; ALL_TAC] THEN
   MAP_EVERY EXISTS_TAC [`B:real`; `mdist m (g(x:A):B,h x)`] THEN
   REWRITE_TAC[IN_ELIM_THM; IN_UNIV; REAL_LE_REFL] THEN
   HYP MESON_TAC "B x" []]);;

let FUNSPACE_IMP_WELLDEFINED = prove
 (`!s m f:A->B x. f IN mspace (funspace s m) /\ x IN s ==> f x IN mspace m`,
  SIMP_TAC[FUNSPACE; IN_ELIM_THM]);;

let FUNSPACE_IMP_EXTENSIONAL = prove
 (`!s m f:A->B. f IN mspace (funspace s m) ==> f IN EXTENSIONAL s`,
  SIMP_TAC[FUNSPACE; IN_ELIM_THM]);;

let FUNSPACE_IMP_BOUNDED_IMAGE = prove
 (`!s m f:A->B. f IN mspace (funspace s m) ==> mbounded m (IMAGE f s)`,
  SIMP_TAC[FUNSPACE; IN_ELIM_THM]);;

let FUNSPACE_IMP_BOUNDED = prove
 (`!s m f:A->B. f IN mspace (funspace s m)
                ==> s = {} \/ (?c b. !x. x IN s ==> mdist m (c,f x) <= b)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[FUNSPACE; MBOUNDED; IMAGE_EQ_EMPTY; IN_ELIM_THM] THEN
  ASM_CASES_TAC `s:A->bool = {}` THEN ASM_REWRITE_TAC[] THEN ASM SET_TAC[]);;

let FUNSPACE_IMP_BOUNDED2 = prove
 (`!s m f g:A->B. f IN mspace (funspace s m) /\ g IN mspace (funspace s m)
                  ==> (?b. !x. x IN s ==> mdist m (f x,g x) <= b)`,
  REWRITE_TAC[FUNSPACE; IN_ELIM_THM] THEN REPEAT STRIP_TAC THEN
  CUT_TAC `mbounded m (IMAGE (f:A->B) s UNION IMAGE g s)` THENL
  [REWRITE_TAC[MBOUNDED_ALT; SUBSET; IN_UNION] THEN
   STRIP_TAC THEN EXISTS_TAC `b:real` THEN ASM SET_TAC [];
   ASM_REWRITE_TAC[MBOUNDED_UNION]]);;

let FUNSPACE_MDIST_LE = prove
 (`!s m f g:A->B a.
     ~(s = {}) /\
     f IN mspace (funspace s m) /\
     g IN mspace (funspace s m)
     ==> (mdist (funspace s m) (f,g) <= a <=>
          !x. x IN s ==> mdist m (f x, g x) <= a)`,
  INTRO_TAC "! *; ne f g" THEN
  HYP (DESTRUCT_TAC "@b. b" o
    MATCH_MP FUNSPACE_IMP_BOUNDED2 o CONJ_LIST) "f g" [] THEN
  ASM_REWRITE_TAC[FUNSPACE] THEN
  MP_TAC (ISPECL [`{mdist m (f x:B,g x) | x:A IN s}`; `a:real`]
    REAL_SUP_LE_EQ) THEN
  ANTS_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[IN_ELIM_THM]] THEN
  MESON_TAC[]);;

let MCOMPLETE_FUNSPACE = prove
 (`!s:A->bool m:B metric. mcomplete m ==> mcomplete (funspace s m)`,
  REWRITE_TAC[mcomplete] THEN INTRO_TAC "!s m; cpl; ![f]; cy" THEN
  ASM_CASES_TAC `s:A->bool = {}` THENL
  [POP_ASSUM SUBST_ALL_TAC THEN EXISTS_TAC `\x:A. ARB:B` THEN
   REMOVE_THEN "cy" MP_TAC THEN
   SIMP_TAC[cauchy_in; LIMIT_METRIC_SEQUENTIALLY; FUNSPACE; NOT_IN_EMPTY;
     IN_ELIM_THM; IN_EXTENSIONAL; IMAGE_CLAUSES; MBOUNDED_EMPTY];
   POP_ASSUM (LABEL_TAC "nempty")] THEN
  LABEL_ABBREV_TAC
    `g (x:A) = if x IN s
               then @y. limit (mtopology m) (\n:num. f n x) y sequentially
               else ARB:B` THEN
  EXISTS_TAC `g:A->B` THEN USE_THEN "cy" MP_TAC THEN
  HYP REWRITE_TAC "nempty"
    [cauchy_in; FUNSPACE; IN_ELIM_THM; FORALL_AND_THM] THEN
  INTRO_TAC "(fwd fext fbd) cy'" THEN
  ASM_REWRITE_TAC[LIMIT_METRIC_SEQUENTIALLY; FUNSPACE; IN_ELIM_THM] THEN
  CLAIM_TAC "gext" `g:A->B IN EXTENSIONAL s` THENL
  [REMOVE_THEN "g" (fun th -> SIMP_TAC[IN_EXTENSIONAL; GSYM th]);
   HYP REWRITE_TAC "gext" []] THEN
  CLAIM_TAC "bd2"
     `!n n'. ?b. !x:A. x IN s ==> mdist m (f (n:num) x:B, f n' x) <= b` THENL
  [REPEAT GEN_TAC THEN MATCH_MP_TAC FUNSPACE_IMP_BOUNDED2 THEN
   ASM_REWRITE_TAC[FUNSPACE; IN_ELIM_THM; ETA_AX];
   ALL_TAC] THEN
  CLAIM_TAC "sup"
    `!n n':num x0:A. x0 IN s
                     ==> mdist m (f n x0:B,f n' x0) <=
                         sup {mdist m (f n x,f n' x) | x IN s}` THENL
  [INTRO_TAC "!n n' x0; x0" THEN MATCH_MP_TAC REAL_LE_SUP THEN
   REMOVE_THEN "bd2" (DESTRUCT_TAC "@b. b" o SPECL[`n:num`;`n':num`]) THEN
   MAP_EVERY EXISTS_TAC
     [`b:real`; `mdist m (f (n:num) (x0:A):B, f n' x0)`] THEN
   REWRITE_TAC[IN_ELIM_THM] THEN CONJ_TAC THENL
   [HYP MESON_TAC "x0" []; REWRITE_TAC[REAL_LE_REFL]] THEN
   INTRO_TAC "![d]; @y. y d" THEN REMOVE_THEN "d" SUBST1_TAC THEN
   HYP SIMP_TAC "b y" [];
   ALL_TAC] THEN
  CLAIM_TAC "pcy" `!x:A. x IN s ==> cauchy_in m (\n. f n x:B)` THENL
  [INTRO_TAC "!x; x" THEN REWRITE_TAC[cauchy_in] THEN
   HYP SIMP_TAC "fwd x" [] THEN INTRO_TAC "!e; e" THEN
   USE_THEN "e" (HYP_TAC "cy': @N.N" o C MATCH_MP) THEN EXISTS_TAC `N:num` THEN
   REPEAT GEN_TAC THEN DISCH_THEN (HYP_TAC "N" o C MATCH_MP) THEN
   TRANS_TAC REAL_LET_TRANS
     `sup {mdist m (f (n:num) x:B,f n' x) | x:A IN s}` THEN
   HYP REWRITE_TAC "N" [] THEN HYP SIMP_TAC "sup x" [];
   ALL_TAC] THEN
  CLAIM_TAC "glim"
    `!x:A. x IN s
           ==> limit (mtopology m) (\n. f n x:B) (g x) sequentially` THENL
  [INTRO_TAC "!x; x" THEN
   REMOVE_THEN "g" (fun th -> ASM_REWRITE_TAC[GSYM th]) THEN
   SELECT_ELIM_TAC THEN HYP SIMP_TAC "cpl pcy x" [];
   ALL_TAC] THEN
  CLAIM_TAC "gwd" `!x:A. x IN s ==> g x:B IN mspace m` THENL
  [INTRO_TAC "!x; x" THEN
   MATCH_MP_TAC (ISPECL[`sequentially`] LIMIT_IN_MSPACE) THEN
   EXISTS_TAC `\n:num. f n (x:A):B` THEN HYP SIMP_TAC "glim x" [];
   HYP REWRITE_TAC "gwd" []] THEN
  CLAIM_TAC "unif"
    `!e. &0 < e ==> ?N:num. !x:A n. x IN s /\ N <= n
                    ==> mdist m (f n x:B, g x) < e` THENL
  [INTRO_TAC "!e; e" THEN REMOVE_THEN "cy'" (MP_TAC o SPEC `e / &2`) THEN
   HYP REWRITE_TAC "e" [REAL_HALF] THEN INTRO_TAC "@N. N" THEN
   EXISTS_TAC `N:num` THEN INTRO_TAC "!x n; x n" THEN
   USE_THEN "x" (HYP_TAC "glim" o C MATCH_MP) THEN
   HYP_TAC "glim: gx glim" (REWRITE_RULE[LIMIT_METRIC_SEQUENTIALLY]) THEN
   REMOVE_THEN "glim" (MP_TAC o SPEC `e / &2`) THEN
   HYP REWRITE_TAC "e" [REAL_HALF] THEN
   HYP SIMP_TAC "fwd x" [] THEN INTRO_TAC "@N'. N'" THEN
   TRANS_TAC REAL_LET_TRANS
     `mdist m (f n (x:A):B, f (MAX N N') x) +
      mdist m (f (MAX N N') x, g x)` THEN
   HYP SIMP_TAC "fwd x gwd" [MDIST_TRIANGLE] THEN
   TRANS_TAC REAL_LTE_TRANS `e / &2 + e / &2` THEN CONJ_TAC THENL
   [MATCH_MP_TAC REAL_LT_ADD2; REWRITE_TAC[REAL_HALF; REAL_LE_REFL]] THEN
   CONJ_TAC THENL [ALL_TAC; REMOVE_THEN "N'" MATCH_MP_TAC THEN ARITH_TAC] THEN
   TRANS_TAC REAL_LET_TRANS
     `sup {mdist m (f n x:B,f (MAX N N') x) | x:A IN s}` THEN
   HYP SIMP_TAC "N n" [ARITH_RULE `N <= MAX N N'`] THEN
   HYP SIMP_TAC "sup x" [];
   ALL_TAC] THEN
  CONJ_TAC THENL
  [HYP_TAC "cy': @N. N" (C MATCH_MP REAL_LT_01) THEN
   USE_THEN "fbd" (MP_TAC o REWRITE_RULE[MBOUNDED] o SPEC `N:num`) THEN
   HYP REWRITE_TAC "nempty" [mbounded; IMAGE_EQ_EMPTY] THEN
   INTRO_TAC "Nwd (@c b. c Nbd)" THEN
   MAP_EVERY EXISTS_TAC [`c:B`; `b + &1`] THEN
   REWRITE_TAC[SUBSET; IN_IMAGE; IN_MCBALL] THEN
   INTRO_TAC "![y]; (@x. y x)" THEN REMOVE_THEN "y" SUBST1_TAC THEN
   HYP SIMP_TAC "x gwd c" [] THEN TRANS_TAC REAL_LE_TRANS
     `mdist m (c:B, f (N:num) (x:A)) + mdist m (f N x, g x)` THEN
   HYP SIMP_TAC "c fwd gwd x" [MDIST_TRIANGLE] THEN
   MATCH_MP_TAC REAL_LE_ADD2 THEN CONJ_TAC THENL
   [REMOVE_THEN "Nbd" MATCH_MP_TAC THEN REWRITE_TAC[IN_IMAGE] THEN
    HYP MESON_TAC "x" [];
    REFUTE_THEN (LABEL_TAC "contra" o REWRITE_RULE[REAL_NOT_LE])] THEN
   CLAIM_TAC "@a. a1 a2"
     `?a. &1 < a /\ a < mdist m (f (N:num) (x:A), g x:B)` THENL
   [EXISTS_TAC `(&1 + mdist m (f (N:num) (x:A), g x:B)) / &2` THEN
    REMOVE_THEN "contra" MP_TAC THEN REAL_ARITH_TAC;
    USE_THEN "x" (HYP_TAC "glim" o C MATCH_MP)] THEN
   REMOVE_THEN "glim" (MP_TAC o REWRITE_RULE[LIMIT_METRIC_SEQUENTIALLY]) THEN
   HYP SIMP_TAC "gwd x" [] THEN DISCH_THEN (MP_TAC o SPEC `a - &1`) THEN
   ANTS_TAC THENL [REMOVE_THEN "a1" MP_TAC THEN REAL_ARITH_TAC; ALL_TAC] THEN
   HYP SIMP_TAC "fwd x" [] THEN INTRO_TAC "@N'. N'" THEN
   CUT_TAC `mdist m (f (N:num) (x:A), g x:B) < a` THENL
   [REMOVE_THEN "a2" MP_TAC THEN REAL_ARITH_TAC; ALL_TAC] THEN
   TRANS_TAC REAL_LET_TRANS
     `mdist m (f N (x:A),f (MAX N N') x:B) + mdist m (f (MAX N N') x,g x)` THEN
   HYP SIMP_TAC "fwd gwd x" [MDIST_TRIANGLE] THEN
   SUBST1_TAC (REAL_ARITH `a = &1 + (a - &1)`) THEN
   MATCH_MP_TAC REAL_LT_ADD2 THEN CONJ_TAC THENL
   [ALL_TAC; REMOVE_THEN "N'" MATCH_MP_TAC THEN ARITH_TAC] THEN
   TRANS_TAC REAL_LET_TRANS
     `sup {mdist m (f N x:B,f (MAX N N') x) | x:A IN s}` THEN
   CONJ_TAC THENL
   [HYP SIMP_TAC "sup x" []; REMOVE_THEN "N" MATCH_MP_TAC THEN ARITH_TAC];
   ALL_TAC] THEN
  INTRO_TAC "!e; e" THEN REMOVE_THEN "unif" (MP_TAC o SPEC `e / &2`) THEN
  HYP REWRITE_TAC "e" [REAL_HALF] THEN INTRO_TAC "@N. N" THEN
  EXISTS_TAC `N:num` THEN INTRO_TAC "!n; n" THEN
  TRANS_TAC REAL_LET_TRANS `e / &2` THEN CONJ_TAC THENL
  [ALL_TAC; REMOVE_THEN "e" MP_TAC THEN REAL_ARITH_TAC] THEN
  MATCH_MP_TAC REAL_SUP_LE THEN REWRITE_TAC[IN_ELIM_THM] THEN CONJ_TAC THENL
  [HYP SET_TAC "nempty" []; HYP MESON_TAC "N n" [REAL_LT_IMP_LE]]);;

(* ------------------------------------------------------------------------- *)
(* Metric space of continuous bounded functions.                             *)
(* ------------------------------------------------------------------------- *)

let cfunspace = new_definition
  `cfunspace top m =
   submetric (funspace (topspace top) m)
     {f:A->B | continuous_map (top,mtopology m) f}`;;

let CFUNSPACE = (REWRITE_RULE[GSYM FORALL_AND_THM] o prove)
 (`(!top m.
      mspace (cfunspace top m) =
      {f:A->B | (!x. x IN topspace top ==> f x IN mspace m) /\
                f IN EXTENSIONAL (topspace top) /\
                mbounded m (IMAGE f (topspace top)) /\
                continuous_map (top,mtopology m) f}) /\
     (!f g:A->B.
        mdist (cfunspace top m) (f,g) =
        if topspace top = {} then &0 else
        sup {mdist m (f x,g x) | x IN topspace top})`,
  REWRITE_TAC[cfunspace; SUBMETRIC; FUNSPACE] THEN SET_TAC[]);;

let CFUNSPACE_SUBSET_FUNSPACE = prove
 (`!top:A topology m:B metric.
     mspace (cfunspace top m) SUBSET mspace (funspace (topspace top) m)`,
  SIMP_TAC[SUBSET; FUNSPACE; CFUNSPACE; IN_ELIM_THM]);;

let MDIST_CFUNSPACE_EQ_MDIST_FUNSPACE = prove
 (`!top m f g:A->B.
     mdist (cfunspace top m) (f,g) = mdist (funspace (topspace top) m) (f,g)`,
  REWRITE_TAC[FUNSPACE; CFUNSPACE]);;

let CFUNSPACE_MDIST_LE = prove
 (`!top m f g:A->B a.
     ~(topspace top = {}) /\
     f IN mspace (cfunspace top m) /\
     g IN mspace (cfunspace top m)
     ==> (mdist (cfunspace top m) (f,g) <= a <=>
          !x. x IN topspace top ==> mdist m (f x, g x) <= a)`,
  INTRO_TAC "! *; ne f g" THEN
  REWRITE_TAC[MDIST_CFUNSPACE_EQ_MDIST_FUNSPACE] THEN
  MATCH_MP_TAC FUNSPACE_MDIST_LE THEN
  ASM_SIMP_TAC[REWRITE_RULE[SUBSET] CFUNSPACE_SUBSET_FUNSPACE]);;

let CFUNSPACE_IMP_BOUNDED2 = prove
 (`!top m f g:A->B.
     f IN mspace (cfunspace top m) /\ g IN mspace (cfunspace top m)
     ==> (?b. !x. x IN topspace top ==> mdist m (f x,g x) <= b)`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC FUNSPACE_IMP_BOUNDED2 THEN
  ASM SET_TAC [CFUNSPACE_SUBSET_FUNSPACE]);;

let CFUNSPACE_MDIST_LT = prove
 (`!top m f g:A->B a x.
     compact_in top (topspace top) /\
     f IN mspace (cfunspace top m) /\ g IN mspace (cfunspace top m) /\
     mdist (cfunspace top m) (f, g) < a /\
     x IN topspace top
     ==> mdist m (f x, g x) < a`,
  REPEAT GEN_TAC THEN ASM_CASES_TAC `topspace (top:A topology) = {}` THEN
  ASM_REWRITE_TAC[NOT_IN_EMPTY] THEN INTRO_TAC "cpt f g lt x" THEN
  REMOVE_THEN "lt" MP_TAC THEN ASM_REWRITE_TAC[CFUNSPACE] THEN
  INTRO_TAC "lt" THEN
  TRANS_TAC REAL_LET_TRANS
    `sup {mdist m (f x:B,g x) | x:A IN topspace top}` THEN
  HYP SIMP_TAC "lt" [] THEN  MATCH_MP_TAC REAL_LE_SUP THEN
  HYP (DESTRUCT_TAC "@b. b" o
    MATCH_MP CFUNSPACE_IMP_BOUNDED2 o CONJ_LIST) "f g" [] THEN
  MAP_EVERY EXISTS_TAC [`b:real`; `mdist m (f (x:A):B,g x)`] THEN
  REWRITE_TAC[IN_ELIM_THM; REAL_LE_REFL] THEN HYP MESON_TAC "x b" []);;

let MDIST_CFUNSPACE_LE = prove
 (`!top m B f g.
     &0 <= B /\
     (!x:A. x IN topspace top ==> mdist m (f x:B, g x) <= B)
     ==> mdist (cfunspace top m) (f,g) <= B`,
  INTRO_TAC "!top m B f g; Bpos bound" THEN
  REWRITE_TAC[CFUNSPACE] THEN COND_CASES_TAC THEN
  HYP REWRITE_TAC "Bpos" [] THEN MATCH_MP_TAC REAL_SUP_LE THEN
  CONJ_TAC THENL
  [POP_ASSUM MP_TAC THEN SET_TAC[];
   REWRITE_TAC[IN_ELIM_THM] THEN HYP MESON_TAC "bound" []]);;

let MDIST_CFUNSPACE_IMP_MDIST_LE = prove
 (`!top m f g:A->B a x.
     f IN mspace (cfunspace top m) /\
     g IN mspace (cfunspace top m) /\
     mdist (cfunspace top m) (f,g) <= a /\
     x IN topspace top
     ==> mdist m (f x,g x) <= a`,
  MESON_TAC[MEMBER_NOT_EMPTY; CFUNSPACE_MDIST_LE]);;

let COMPACT_IN_MSPACE_CFUNSPACE = prove
 (`!top m.
     compact_in top (topspace top)
     ==> mspace (cfunspace top m) =
          {f | (!x:A. x IN topspace top ==> f x:B IN mspace m) /\
               f IN EXTENSIONAL (topspace top) /\
               continuous_map (top,mtopology m) f}`,
  REWRITE_TAC[CFUNSPACE; EXTENSION; IN_ELIM_THM] THEN REPEAT STRIP_TAC THEN
  EQ_TAC THEN SIMP_TAC[] THEN INTRO_TAC "wd ext cont" THEN
  MATCH_MP_TAC COMPACT_IN_IMP_MBOUNDED THEN
  MATCH_MP_TAC (ISPEC `top:A topology` IMAGE_COMPACT_IN) THEN
  ASM_REWRITE_TAC[]);;

let MCOMPLETE_CFUNSPACE = prove
 (`!top:A topology m:B metric. mcomplete m ==> mcomplete (cfunspace top m)`,
  INTRO_TAC "!top m; cpl" THEN REWRITE_TAC[cfunspace] THEN
  MATCH_MP_TAC SEQUENTIALLY_CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE THEN
  ASM_SIMP_TAC[MCOMPLETE_FUNSPACE] THEN
  REWRITE_TAC[IN_ELIM_THM; LIMIT_METRIC_SEQUENTIALLY] THEN
  INTRO_TAC "![f] [g]; fcont g lim" THEN
  ASM_CASES_TAC `topspace top = {}:A->bool` THENL
  [ASM_REWRITE_TAC[continuous_map; NOT_IN_EMPTY; EMPTY_GSPEC; OPEN_IN_EMPTY];
   POP_ASSUM (LABEL_TAC "nempty")] THEN
  REWRITE_TAC[CONTINUOUS_MAP_TO_METRIC; IN_MBALL] THEN
  INTRO_TAC "!x; x; ![e]; e" THEN CLAIM_TAC "e3pos" `&0 < e / &3` THENL
  [REMOVE_THEN "e" MP_TAC THEN REAL_ARITH_TAC;
   USE_THEN "e3pos" (HYP_TAC "lim: @N. N" o C MATCH_MP)] THEN
  HYP_TAC "N: f lt" (C MATCH_MP (SPEC `N:num` LE_REFL)) THEN
  HYP_TAC "fcont" (REWRITE_RULE[CONTINUOUS_MAP_TO_METRIC]) THEN
  USE_THEN "x" (HYP_TAC "fcont" o C MATCH_MP) THEN
  USE_THEN "e3pos" (HYP_TAC "fcont" o C MATCH_MP) THEN
  HYP_TAC "fcont: @u. u x' inc" (SPEC `N:num`) THEN EXISTS_TAC `u:A->bool` THEN
  HYP REWRITE_TAC "u x'" [] THEN INTRO_TAC "!y; y'" THEN
  CLAIM_TAC "uinc" `!x:A. x IN u ==> x IN topspace top` THENL
  [REMOVE_THEN "u" (MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN SET_TAC[];
   ALL_TAC] THEN
  HYP_TAC "g -> gwd gext gbd" (REWRITE_RULE[FUNSPACE; IN_ELIM_THM]) THEN
  HYP_TAC "f -> fwd fext fbd" (REWRITE_RULE[FUNSPACE; IN_ELIM_THM]) THEN
  CLAIM_TAC "y" `y:A IN topspace top` THENL
  [HYP SIMP_TAC "uinc y'" [OPEN_IN_SUBSET]; HYP SIMP_TAC "gwd x y" []] THEN
  CLAIM_TAC "sup" `!x0:A. x0 IN topspace top
                          ==> mdist m (f (N:num) x0:B,g x0) <= e / &3` THENL
  [INTRO_TAC "!x0; x0" THEN TRANS_TAC REAL_LE_TRANS
     `sup {mdist m (f (N:num) x,g x:B) | x:A IN topspace top}` THEN
   CONJ_TAC THENL
   [MATCH_MP_TAC REAL_LE_SUP THEN HYP (DESTRUCT_TAC "@b. b" o
      MATCH_MP FUNSPACE_IMP_BOUNDED2 o CONJ_LIST) "f g" [] THEN
    MAP_EVERY EXISTS_TAC [`b:real`; `mdist m (f (N:num) (x0:A), g x0:B)`] THEN
    REWRITE_TAC[IN_ELIM_THM; REAL_LE_REFL] THEN
    CONJ_TAC THENL [HYP SET_TAC "x0" []; HYP MESON_TAC "b" []];
    REMOVE_THEN "lt" MP_TAC THEN HYP REWRITE_TAC "nempty" [FUNSPACE] THEN
    MATCH_ACCEPT_TAC REAL_LT_IMP_LE];
   ALL_TAC] THEN
  TRANS_TAC REAL_LET_TRANS
    `mdist m (g (x:A):B, f (N:num) x) + mdist m (f N x, g y)` THEN
  HYP SIMP_TAC "gwd fwd x y" [MDIST_TRIANGLE] THEN
  SUBST1_TAC (ARITH_RULE `e = e / &3 + (e / &3 + e / &3)`) THEN
  MATCH_MP_TAC REAL_LET_ADD2 THEN HYP SIMP_TAC "gwd fwd x sup" [MDIST_SYM] THEN
  TRANS_TAC REAL_LET_TRANS
    `mdist m (f (N:num) (x:A):B, f N y) + mdist m (f N y, g y)` THEN
  HYP SIMP_TAC "fwd gwd x y" [MDIST_TRIANGLE] THEN
  MATCH_MP_TAC REAL_LTE_ADD2 THEN HYP SIMP_TAC "gwd fwd y sup" [] THEN
  REMOVE_THEN "inc" MP_TAC THEN HYP SIMP_TAC "fwd x y' uinc" [IN_MBALL]);;

(* ------------------------------------------------------------------------- *)
(* Existence of completion for any metric space M as a subspace of M->R.     *)
(* ------------------------------------------------------------------------- *)

let METRIC_COMPLETION_EXPLICIT = prove
 (`!m:A metric. ?s f:A->A->real.
      s SUBSET mspace(funspace (mspace m) real_euclidean_metric) /\
      mcomplete(submetric (funspace (mspace m) real_euclidean_metric) s) /\
      IMAGE f (mspace m) SUBSET s /\
      mtopology(funspace (mspace m) real_euclidean_metric) closure_of
      IMAGE f (mspace m) = s /\
      !x y. x IN mspace m /\ y IN mspace m
            ==> mdist (funspace (mspace m) real_euclidean_metric) (f x,f y) =
                mdist m (x,y)`,
  GEN_TAC THEN
  ABBREV_TAC `m' = funspace (mspace m:A->bool) real_euclidean_metric` THEN
  ASM_CASES_TAC `mspace m:A->bool = {}` THENL
   [EXISTS_TAC `{}:(A->real)->bool` THEN
    ASM_REWRITE_TAC[NOT_IN_EMPTY; IMAGE_CLAUSES; CLOSURE_OF_EMPTY;
                 EMPTY_SUBSET; INTER_EMPTY; mcomplete; CAUCHY_IN_SUBMETRIC];
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [GSYM MEMBER_NOT_EMPTY])] THEN
  DISCH_THEN(X_CHOOSE_TAC `a:A`) THEN
  ABBREV_TAC
    `f:A->A->real =
     \x. RESTRICTION (mspace m) (\u. mdist m (x,u) - mdist m (a,u))` THEN
  EXISTS_TAC `mtopology(funspace (mspace m) real_euclidean_metric) closure_of
              IMAGE (f:A->A->real) (mspace m)` THEN
  EXISTS_TAC `f:A->A->real` THEN
  EXPAND_TAC "m'" THEN
 SUBGOAL_THEN `IMAGE (f:A->A->real) (mspace m) SUBSET mspace m'`
  ASSUME_TAC THENL
   [EXPAND_TAC "m'" THEN REWRITE_TAC[SUBSET; FUNSPACE] THEN
    REWRITE_TAC[FORALL_IN_IMAGE; IN_ELIM_THM; EXTENSIONAL] THEN
    REWRITE_TAC[REAL_EUCLIDEAN_METRIC; IN_UNIV; mbounded; mcball] THEN
    X_GEN_TAC `b:A` THEN DISCH_TAC THEN
    EXPAND_TAC "f" THEN SIMP_TAC[RESTRICTION; SUBSET; FORALL_IN_IMAGE] THEN
    MAP_EVERY EXISTS_TAC [`&0:real`; `mdist m (a:A,b)`] THEN
    REWRITE_TAC[IN_ELIM_THM; REAL_SUB_RZERO] THEN
    MAP_EVERY UNDISCH_TAC [`(a:A) IN mspace m`; `(b:A) IN mspace m`] THEN
    CONV_TAC METRIC_ARITH;
    ALL_TAC] THEN
  REWRITE_TAC[SUBMETRIC] THEN ASM_REWRITE_TAC[] THEN REPEAT CONJ_TAC THENL
   [REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY] THEN
    REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE];
    MATCH_MP_TAC CLOSED_IN_MCOMPLETE_IMP_MCOMPLETE THEN
    REWRITE_TAC[CLOSED_IN_CLOSURE_OF] THEN EXPAND_TAC "m'" THEN
    MATCH_MP_TAC MCOMPLETE_FUNSPACE THEN
    REWRITE_TAC[MCOMPLETE_REAL_EUCLIDEAN_METRIC];
    MATCH_MP_TAC CLOSURE_OF_SUBSET THEN
    ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY];
    MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN STRIP_TAC THEN
    EXPAND_TAC "m'" THEN REWRITE_TAC[FUNSPACE] THEN
    COND_CASES_TAC THENL [ASM_MESON_TAC[NOT_IN_EMPTY]; ALL_TAC] THEN
    MATCH_MP_TAC SUP_UNIQUE THEN SIMP_TAC[FORALL_IN_GSPEC] THEN
    X_GEN_TAC `b:real` THEN REWRITE_TAC[REAL_EUCLIDEAN_METRIC] THEN
    EXPAND_TAC "f" THEN REWRITE_TAC[RESTRICTION] THEN EQ_TAC THENL
     [DISCH_THEN(fun th -> MP_TAC(SPEC `x:A` th)) THEN EXPAND_TAC "f" THEN
      ASM_SIMP_TAC[MDIST_REFL; MDIST_SYM] THEN REAL_ARITH_TAC;
      MAP_EVERY UNDISCH_TAC [`(x:A) IN mspace m`; `(y:A) IN mspace m`] THEN
      CONV_TAC METRIC_ARITH]]);;

let METRIC_COMPLETION = prove
 (`!m:A metric.
        ?m' f:A->A->real.
                mcomplete m' /\
                IMAGE f (mspace m) SUBSET mspace m' /\
                (mtopology m') closure_of (IMAGE f (mspace m)) = mspace m' /\
                !x y. x IN mspace m /\ y IN mspace m
                      ==> mdist m' (f x,f y) = mdist m (x,y)`,
  GEN_TAC THEN
  MATCH_MP_TAC(MESON[]
   `(?s f. P (submetric (funspace (mspace m) real_euclidean_metric) s) f)
    ==> ?n f. P n f`) THEN
  MP_TAC(SPEC `m:A metric` METRIC_COMPLETION_EXPLICIT) THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN
  REWRITE_TAC[SUBMETRIC; SUBSET_INTER] THEN
  REWRITE_TAC[MTOPOLOGY_SUBMETRIC; CLOSURE_OF_SUBTOPOLOGY] THEN
  SIMP_TAC[SET_RULE `t SUBSET s ==> s INTER t = t`] THEN SET_TAC[]);;

let METRIZABLE_SPACE_COMPLETION = prove
 (`!top:A topology.
        metrizable_space top
        ==> ?top' (f:A->A->real).
                completely_metrizable_space top' /\
                embedding_map(top,top') f /\
                top' closure_of (IMAGE f (topspace top)) = topspace top'`,
  REWRITE_TAC[FORALL_METRIZABLE_SPACE; RIGHT_EXISTS_AND_THM] THEN
  X_GEN_TAC `m:A metric` THEN
  REWRITE_TAC[EXISTS_COMPLETELY_METRIZABLE_SPACE; RIGHT_AND_EXISTS_THM] THEN
  MP_TAC(ISPEC `m:A metric` METRIC_COMPLETION) THEN
  REPEAT(MATCH_MP_TAC MONO_EXISTS THEN GEN_TAC) THEN
  MESON_TAC[ISOMETRY_IMP_EMBEDDING_MAP]);;

(* ------------------------------------------------------------------------- *)
(* The Baire Category Theorem                                                *)
(* ------------------------------------------------------------------------- *)

let METRIC_BAIRE_CATEGORY = prove
 (`!m:A metric g.
     mcomplete m /\
     COUNTABLE g /\
     (!t. t IN g ==> open_in (mtopology m) t /\
                     mtopology m closure_of t = mspace m)
     ==> mtopology m closure_of INTERS g = mspace m`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN INTRO_TAC "!m; m" THEN
  REWRITE_TAC[FORALL_COUNTABLE_AS_IMAGE; NOT_IN_EMPTY; CLOSURE_OF_UNIV;
  INTERS_0; TOPSPACE_MTOPOLOGY; FORALL_IN_IMAGE; IN_UNIV; FORALL_AND_THM] THEN
  INTRO_TAC "![u]; u_open u_dense" THEN
  REWRITE_TAC[GSYM TOPSPACE_MTOPOLOGY] THEN
  REWRITE_TAC[DENSE_INTERSECTS_OPEN] THEN
  INTRO_TAC "![w]; w_open w_ne" THEN
  REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN
  CLAIM_TAC "@x0. x0" `?x0:A. x0 IN u 0 INTER w` THENL
  [REWRITE_TAC[MEMBER_NOT_EMPTY] THEN
   ASM_MESON_TAC[DENSE_INTERSECTS_OPEN; TOPSPACE_MTOPOLOGY];
   ALL_TAC] THEN
  CLAIM_TAC "@r0. r0pos r0lt1 sub"
    `?r. &0 < r /\ r < &1 /\ mcball m (x0:A,r) SUBSET u 0 INTER w` THENL
  [SUBGOAL_THEN `open_in (mtopology m) (u 0 INTER w:A->bool)` MP_TAC THENL
   [HYP SIMP_TAC "u_open w_open" [OPEN_IN_INTER]; ALL_TAC] THEN
   REWRITE_TAC[OPEN_IN_MTOPOLOGY] THEN INTRO_TAC "u0w hp" THEN
   REMOVE_THEN "hp" (MP_TAC o SPEC `x0:A`) THEN
   ANTS_TAC THENL [HYP REWRITE_TAC "x0" []; ALL_TAC] THEN
   INTRO_TAC "@r. rpos ball" THEN EXISTS_TAC `min r (&1) / &2` THEN
   CONJ_TAC THENL [ASM_ARITH_TAC; ALL_TAC] THEN
   CONJ_TAC THENL [REAL_ARITH_TAC; ALL_TAC] THEN
   TRANS_TAC SUBSET_TRANS `mball m (x0:A,r)` THEN
   HYP REWRITE_TAC "ball" [] THEN
   MATCH_MP_TAC MCBALL_SUBSET_MBALL_CONCENTRIC THEN
   ASM_REAL_ARITH_TAC; ALL_TAC] THEN
  (DESTRUCT_TAC "@b. b0 b1" o prove_general_recursive_function_exists)
    `?b:num->(A#real).
       b 0 = (x0:A,r0) /\
       (!n. b (SUC n) =
            @(x,r). &0 < r /\ r < SND (b n) / &2 /\ x IN mspace m /\
                    mcball m (x,r) SUBSET mball m (b n) INTER u n)` THEN
  CLAIM_TAC "rmk"
    `!n. (\ (x:A,r). &0 < r /\ r < SND (b n) / &2 /\ x IN mspace m /\
                   mcball m (x,r) SUBSET mball m (b n) INTER u n)
         (b (SUC n))` THENL
  [LABEL_INDUCT_TAC THENL
   [REMOVE_THEN "b1" (fun b1 -> REWRITE_TAC[b1]) THEN
    MATCH_MP_TAC CHOICE_PAIRED_THM THEN
    REMOVE_THEN "b0" (fun b0 -> REWRITE_TAC[b0]) THEN
    MAP_EVERY EXISTS_TAC [`x0:A`; `r0 / &4`] THEN
    CONJ_TAC THENL [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
    CONJ_TAC THENL [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
    CONJ_TAC THENL
    [CUT_TAC `u 0:A->bool SUBSET mspace m` THENL
     [HYP SET_TAC "x0" [];
      HYP SIMP_TAC "u_open" [GSYM TOPSPACE_MTOPOLOGY; OPEN_IN_SUBSET]];
     ALL_TAC] THEN
    TRANS_TAC SUBSET_TRANS `mball m (x0:A,r0)` THEN CONJ_TAC THENL
    [MATCH_MP_TAC MCBALL_SUBSET_MBALL_CONCENTRIC THEN ASM_REAL_ARITH_TAC;
     REWRITE_TAC[SUBSET_INTER; SUBSET_REFL] THEN
     TRANS_TAC SUBSET_TRANS `mcball m (x0:A,r0)` THEN
     REWRITE_TAC [MBALL_SUBSET_MCBALL] THEN HYP SET_TAC "sub" []];
    ALL_TAC] THEN
   USE_THEN "b1" (fun b1 -> GEN_REWRITE_TAC RAND_CONV [b1]) THEN
   MATCH_MP_TAC CHOICE_PAIRED_THM THEN REWRITE_TAC[] THEN
   HYP_TAC "ind_n: rpos rlt x subn" (REWRITE_RULE[LAMBDA_PAIR]) THEN
   USE_THEN "u_dense" (MP_TAC o SPEC `SUC n` o
     REWRITE_RULE[GSYM TOPSPACE_MTOPOLOGY]) THEN
   REWRITE_TAC[DENSE_INTERSECTS_OPEN] THEN
   DISCH_THEN (MP_TAC o SPEC `mball m (b (SUC n):A#real)`) THEN
   (DESTRUCT_TAC "@x1 r1. bsuc" o MESON[PAIR])
     `?x1:A r1:real. b (SUC n) = x1,r1` THEN
   HYP REWRITE_TAC "bsuc" [] THEN
   REMOVE_THEN "bsuc"
    (fun th -> RULE_ASSUM_TAC (REWRITE_RULE[th]) THEN LABEL_TAC "bsuc" th) THEN
   ANTS_TAC THENL
   [HYP REWRITE_TAC "x" [OPEN_IN_MBALL; MBALL_EQ_EMPTY; DE_MORGAN_THM] THEN
    ASM_REAL_ARITH_TAC; ALL_TAC] THEN
   REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN INTRO_TAC "@z. hp" THEN
   EXISTS_TAC `z:A` THEN
   SUBGOAL_THEN `open_in (mtopology m) (mball m (x1:A,r1) INTER u (SUC n))`
     (DESTRUCT_TAC "hp1 hp2" o REWRITE_RULE[OPEN_IN_MTOPOLOGY_MCBALL]) THENL
   [HYP SIMP_TAC "u_open" [OPEN_IN_INTER; OPEN_IN_MBALL]; ALL_TAC] THEN
   CLAIM_TAC "z" `z:A IN mspace m` THENL
   [CUT_TAC `u (SUC n):A->bool SUBSET mspace m` THENL
    [HYP SET_TAC "hp" [];
     HYP SIMP_TAC "u_open" [GSYM TOPSPACE_MTOPOLOGY; OPEN_IN_SUBSET]];
    HYP REWRITE_TAC "z" []] THEN
   REMOVE_THEN "hp2" (MP_TAC o SPEC `z:A`) THEN
   ANTS_TAC THENL [HYP SET_TAC "hp" []; ALL_TAC] THEN
   INTRO_TAC "@r. rpos ball" THEN EXISTS_TAC `min r (r1 / &4)` THEN
   CONJ_TAC THENL [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
   CONJ_TAC THENL [ASM_REAL_ARITH_TAC; ALL_TAC] THEN
   TRANS_TAC SUBSET_TRANS `mcball m (z:A,r)` THEN
   HYP SIMP_TAC "ball" [MCBALL_SUBSET_CONCENTRIC; REAL_MIN_MIN];
   ALL_TAC] THEN
  CLAIM_TAC "@x r. b" `?x r. !n:num. b n = x n:A, r n:real` THENL
  [MAP_EVERY EXISTS_TAC
     [`FST o (b:num->A#real)`; `SND o (b:num->A#real)`] THEN
   REWRITE_TAC[o_DEF]; ALL_TAC] THEN
  REMOVE_THEN "b"
    (fun b -> RULE_ASSUM_TAC (REWRITE_RULE[b]) THEN LABEL_TAC "b" b) THEN
  HYP_TAC "b0: x_0 r_0" (REWRITE_RULE[PAIR_EQ]) THEN
  REMOVE_THEN "x_0" (SUBST_ALL_TAC o GSYM) THEN
  REMOVE_THEN "r_0" (SUBST_ALL_TAC o GSYM) THEN
  HYP_TAC "rmk: r1pos r1lt x1 ball" (REWRITE_RULE[FORALL_AND_THM]) THEN
  CLAIM_TAC "x" `!n:num. x n:A IN mspace m` THENL
  [LABEL_INDUCT_TAC THENL
   [CUT_TAC `u 0:A->bool SUBSET mspace m` THENL
    [HYP SET_TAC "x0" [];
     HYP SIMP_TAC "u_open" [GSYM TOPSPACE_MTOPOLOGY; OPEN_IN_SUBSET]];
    HYP REWRITE_TAC "x1" []];
   ALL_TAC] THEN
  CLAIM_TAC "rpos" `!n:num. &0 < r n` THENL
  [LABEL_INDUCT_TAC THENL
   [HYP REWRITE_TAC "r0pos" []; HYP REWRITE_TAC "r1pos" []];
   ALL_TAC] THEN
  CLAIM_TAC "rmono" `!p q:num. p <= q ==> r q <= r p` THENL
  [MATCH_MP_TAC LE_INDUCT THEN REWRITE_TAC[REAL_LE_REFL] THEN
   INTRO_TAC "!p q; pq rpq" THEN
   REMOVE_THEN "r1lt" (MP_TAC o SPEC `q:num`) THEN
   REMOVE_THEN "rpos" (MP_TAC o SPEC `q:num`) THEN
   ASM_REAL_ARITH_TAC;
   ALL_TAC] THEN
  CLAIM_TAC "rlt" `!n:num. r n < inv (&2 pow n)` THENL
  [LABEL_INDUCT_TAC THENL
   [CONV_TAC (RAND_CONV REAL_RAT_REDUCE_CONV) THEN HYP REWRITE_TAC "r0lt1" [];
    TRANS_TAC REAL_LTE_TRANS `r (n:num) / &2` THEN
    HYP REWRITE_TAC "r1lt" [real_pow] THEN REMOVE_THEN "ind_n" MP_TAC THEN
    REMOVE_THEN "rpos" (MP_TAC o SPEC `n:num`) THEN CONV_TAC REAL_FIELD];
   ALL_TAC] THEN
  CLAIM_TAC "nested"
    `!p q:num. p <= q ==> mball m (x q:A, r q) SUBSET mball m (x p, r p)` THENL
  [MATCH_MP_TAC LE_INDUCT THEN REWRITE_TAC[SUBSET_REFL] THEN
   INTRO_TAC "!p q; pq sub" THEN
   TRANS_TAC SUBSET_TRANS `mball m (x (q:num):A,r q)` THEN
   HYP REWRITE_TAC "sub" [] THEN
   TRANS_TAC SUBSET_TRANS `mcball m (x (SUC q):A,r(SUC q))` THEN
   REWRITE_TAC[MBALL_SUBSET_MCBALL] THEN HYP SET_TAC "ball" [];
   ALL_TAC] THEN
  CLAIM_TAC "in_ball" `!p q:num. p <= q ==> x q:A IN mball m (x p, r p)` THENL
  [INTRO_TAC "!p q; le" THEN CUT_TAC `x (q:num):A IN mball m (x q, r q)` THENL
   [HYP SET_TAC "nested le" []; HYP SIMP_TAC "x rpos" [CENTRE_IN_MBALL_EQ]];
   ALL_TAC] THEN
  CLAIM_TAC "@l. l" `?l:A. limit (mtopology m) x l sequentially` THENL
  [HYP_TAC "m" (REWRITE_RULE[mcomplete]) THEN REMOVE_THEN "m" MATCH_MP_TAC THEN
   HYP REWRITE_TAC "x" [cauchy_in] THEN INTRO_TAC "!e; epos" THEN
   CLAIM_TAC "@N. N" `?N. inv(&2 pow N) < e` THENL
   [REWRITE_TAC[REAL_INV_POW] THEN MATCH_MP_TAC REAL_ARCH_POW_INV THEN
    HYP REWRITE_TAC "epos" [] THEN REAL_ARITH_TAC;
    ALL_TAC] THEN
   EXISTS_TAC `N:num` THEN MATCH_MP_TAC WLOG_LE THEN CONJ_TAC THENL
   [HYP SIMP_TAC "x" [MDIST_SYM] THEN MESON_TAC[]; ALL_TAC] THEN
   INTRO_TAC "!n n'; le; n n'" THEN
   TRANS_TAC REAL_LT_TRANS `inv (&2 pow N)` THEN HYP REWRITE_TAC "N" [] THEN
   TRANS_TAC REAL_LT_TRANS `r (N:num):real` THEN HYP REWRITE_TAC "rlt" [] THEN
   CUT_TAC `x (n':num):A IN mball m (x n, r n)` THENL
   [HYP REWRITE_TAC "x" [IN_MBALL] THEN INTRO_TAC "hp" THEN
    TRANS_TAC REAL_LTE_TRANS `r (n:num):real` THEN
    HYP SIMP_TAC "n rmono hp" [];
    HYP SIMP_TAC "in_ball le" []];
   ALL_TAC] THEN
  EXISTS_TAC `l:A` THEN
  CLAIM_TAC "in_mcball" `!n:num. l:A IN mcball m (x n, r n)` THENL
  [GEN_TAC THEN
   (MATCH_MP_TAC o ISPECL [`sequentially`; `mtopology (m:A metric)`])
   LIMIT_IN_CLOSED_IN THEN EXISTS_TAC `x:num->A` THEN
   HYP REWRITE_TAC "l" [TRIVIAL_LIMIT_SEQUENTIALLY; CLOSED_IN_MCBALL] THEN
   REWRITE_TAC[EVENTUALLY_SEQUENTIALLY] THEN EXISTS_TAC `n:num` THEN
   INTRO_TAC "![p]; p" THEN CUT_TAC `x (p:num):A IN mball m (x n, r n)` THENL
   [SET_TAC[MBALL_SUBSET_MCBALL]; HYP SIMP_TAC "in_ball p" []];
   ALL_TAC] THEN
  REWRITE_TAC[IN_INTER] THEN CONJ_TAC THENL
  [REWRITE_TAC[IN_INTERS; FORALL_IN_IMAGE; IN_UNIV] THEN
   LABEL_INDUCT_TAC THENL
   [HYP SET_TAC "in_mcball sub " []; HYP SET_TAC "in_mcball ball " []];
   HYP SET_TAC "sub in_mcball" []]);;

let METRIC_BAIRE_CATEGORY_ALT = prove
 (`!m g:(A->bool)->bool.
         mcomplete m /\
         COUNTABLE g /\
         (!t. t IN g
              ==> closed_in (mtopology m) t /\ mtopology m interior_of t = {})
         ==> mtopology m interior_of (UNIONS g) = {}`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`m:A metric`; `IMAGE (\u:A->bool. mspace m DIFF u) g`]
        METRIC_BAIRE_CATEGORY) THEN
  ASM_SIMP_TAC[COUNTABLE_IMAGE; FORALL_IN_IMAGE] THEN
  ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_MSPACE] THEN
  REWRITE_TAC[CLOSURE_OF_COMPLEMENT; GSYM TOPSPACE_MTOPOLOGY] THEN
  ASM_SIMP_TAC[DIFF_EMPTY] THEN REWRITE_TAC[CLOSURE_OF_INTERIOR_OF] THEN
  MATCH_MP_TAC(SET_RULE
    `s SUBSET u /\ s' = s ==> u DIFF s' = u ==> s = {}`) THEN
  REWRITE_TAC[INTERIOR_OF_SUBSET_TOPSPACE] THEN AP_TERM_TAC THEN
  REWRITE_TAC[DIFF_INTERS; SET_RULE
   `{f y | y IN IMAGE g s} = {f(g x) | x IN s}`] THEN
  AP_TERM_TAC THEN MATCH_MP_TAC(SET_RULE
   `(!x. x IN s ==> f x = x) ==> {f x | x IN s} = s`) THEN
  X_GEN_TAC `s:A->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `s:A->bool`) THEN
  ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN SET_TAC[]);;

let BAIRE_CATEGORY_ALT = prove
 (`!top g:(A->bool)->bool.
        (completely_metrizable_space top \/
         locally_compact_space top /\
         (hausdorff_space top \/ regular_space top)) /\
        COUNTABLE g /\
        (!t. t IN g ==> closed_in top t /\ top interior_of t = {})
        ==> top interior_of (UNIONS g) = {}`,
  REWRITE_TAC[TAUT `(p \/ q) /\ r ==> s <=>
                    (p ==> r ==> s) /\ (q /\ r ==> s)`] THEN
  REWRITE_TAC[FORALL_AND_THM; RIGHT_FORALL_IMP_THM] THEN
  REWRITE_TAC[GSYM FORALL_MCOMPLETE_TOPOLOGY] THEN
  SIMP_TAC[METRIC_BAIRE_CATEGORY_ALT] THEN REPEAT GEN_TAC THEN
  DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP (TAUT `(p \/ q) ==> (p ==> q) ==> q`)) THEN
  ANTS_TAC THENL
   [ASM_MESON_TAC[LOCALLY_COMPACT_HAUSDORFF_IMP_REGULAR_SPACE]; DISCH_TAC] THEN
  ASM_CASES_TAC `g:(A->bool)->bool = {}` THEN
  ASM_REWRITE_TAC[UNIONS_0; INTERIOR_OF_EMPTY] THEN
  FIRST_X_ASSUM(MP_TAC o MATCH_MP (REWRITE_RULE[IMP_CONJ]
        COUNTABLE_AS_IMAGE)) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `t:num->A->bool` THEN DISCH_THEN SUBST_ALL_TAC THEN
  FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [FORALL_IN_IMAGE]) THEN
  REWRITE_TAC[IN_UNIV; FORALL_AND_THM] THEN STRIP_TAC THEN
  REWRITE_TAC[interior_of; EXTENSION; IN_ELIM_THM; NOT_IN_EMPTY] THEN
  X_GEN_TAC `z:A` THEN
  DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
  MP_TAC(ISPEC `top:A topology`
        LOCALLY_COMPACT_SPACE_NEIGBOURHOOD_BASE_CLOSED_IN) THEN
  ASM_REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
  FIRST_ASSUM(MP_TAC o SPEC `z:A` o REWRITE_RULE[SUBSET] o MATCH_MP
    OPEN_IN_SUBSET) THEN
  ASM_REWRITE_TAC[] THEN DISCH_TAC THEN
  DISCH_THEN(MP_TAC o SPECL [`u:A->bool`; `z:A`]) THEN
  ASM_REWRITE_TAC[NOT_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`v:A->bool`; `k:A->bool`] THEN STRIP_TAC THEN
  SUBGOAL_THEN
   `?c:num->A->bool.
        (!n. c n SUBSET k /\ closed_in top (c n) /\
             ~(top interior_of c n = {}) /\ DISJOINT (c n) (t n)) /\
        (!n. c (SUC n) SUBSET c n)`
  MP_TAC THENL
   [MATCH_MP_TAC DEPENDENT_CHOICE THEN CONJ_TAC THENL
     [FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I
       [GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN]) THEN
      REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
      DISCH_THEN(MP_TAC o SPEC `v DIFF (t:num->A->bool) 0`) THEN
      ASM_SIMP_TAC[OPEN_IN_DIFF] THEN
      DISCH_THEN(MP_TAC o MATCH_MP MONO_EXISTS) THEN ANTS_TAC THENL
       [REWRITE_TAC[SET_RULE `(?x. x IN s DIFF t) <=> ~(s SUBSET t)`] THEN
        DISCH_TAC THEN
        SUBGOAL_THEN `top interior_of (t:num->A->bool) 0 = {}` MP_TAC THENL
         [ASM_REWRITE_TAC[]; REWRITE_TAC[interior_of]] THEN
        REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; IN_ELIM_THM] THEN ASM_MESON_TAC[];
        REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
        MAP_EVERY X_GEN_TAC [`x:A`; `n:A->bool`; `c:A->bool`] THEN
        STRIP_TAC THEN EXISTS_TAC `c:A->bool` THEN
        ASM_REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN
        REPEAT CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC; ASM SET_TAC[]] THEN
        EXISTS_TAC `x:A` THEN REWRITE_TAC[interior_of; IN_ELIM_THM] THEN
        ASM_MESON_TAC[]];
      MAP_EVERY X_GEN_TAC [`n:num`; `c:A->bool`] THEN STRIP_TAC THEN
      FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I
       [GSYM NEIGHBOURHOOD_BASE_OF_CLOSED_IN]) THEN
      REWRITE_TAC[NEIGHBOURHOOD_BASE_OF] THEN
      DISCH_THEN(MP_TAC o SPEC
        `top interior_of c DIFF (t:num->A->bool) (SUC n)`) THEN
      ASM_SIMP_TAC[OPEN_IN_DIFF; OPEN_IN_INTERIOR_OF] THEN
      DISCH_THEN(MP_TAC o MATCH_MP MONO_EXISTS) THEN ANTS_TAC THENL
       [REWRITE_TAC[SET_RULE `(?x. x IN s DIFF t) <=> ~(s SUBSET t)`] THEN
        DISCH_TAC THEN
        SUBGOAL_THEN `top interior_of t(SUC n):A->bool = {}` MP_TAC THENL
         [ASM_REWRITE_TAC[]; REWRITE_TAC[interior_of]] THEN
        REWRITE_TAC[GSYM MEMBER_NOT_EMPTY; IN_ELIM_THM] THEN
        ASM_MESON_TAC[OPEN_IN_INTERIOR_OF; MEMBER_NOT_EMPTY];
        REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
        MAP_EVERY X_GEN_TAC [`x:A`; `n:A->bool`; `d:A->bool`] THEN
        STRIP_TAC THEN EXISTS_TAC `d:A->bool` THEN
        ASM_REWRITE_TAC[GSYM MEMBER_NOT_EMPTY] THEN REPEAT CONJ_TAC THENL
         [MP_TAC(ISPECL[`top:A topology`; `c:A->bool`] INTERIOR_OF_SUBSET) THEN
          ASM SET_TAC[];
          EXISTS_TAC `x:A` THEN REWRITE_TAC[interior_of; IN_ELIM_THM] THEN
          ASM_MESON_TAC[];
          ASM SET_TAC[];
          MP_TAC(ISPECL[`top:A topology`; `c:A->bool`] INTERIOR_OF_SUBSET) THEN
          ASM SET_TAC[]]]];
    REWRITE_TAC[NOT_EXISTS_THM; FORALL_AND_THM]] THEN
  X_GEN_TAC `c:num->A->bool` THEN STRIP_TAC THEN
  MP_TAC(ISPECL [`subtopology top (k:A->bool)`; `c:num->A->bool`]
        COMPACT_SPACE_IMP_NEST) THEN
  ASM_SIMP_TAC[COMPACT_SPACE_SUBTOPOLOGY; CLOSED_IN_SUBSET_TOPSPACE] THEN
  REWRITE_TAC[NOT_IMP] THEN REPEAT CONJ_TAC THENL
   [ASM_MESON_TAC[INTERIOR_OF_SUBSET; CLOSED_IN_SUBSET; MEMBER_NOT_EMPTY;
                  SUBSET];
    MATCH_MP_TAC TRANSITIVE_STEPWISE_LE THEN ASM SET_TAC[];
    RULE_ASSUM_TAC(REWRITE_RULE[UNIONS_IMAGE; IN_UNIV]) THEN
    REWRITE_TAC[INTERS_GSPEC] THEN ASM SET_TAC[]]);;

let BAIRE_CATEGORY = prove
 (`!top g:(A->bool)->bool.
        (completely_metrizable_space top \/
         locally_compact_space top /\
         (hausdorff_space top \/ regular_space top)) /\
        COUNTABLE g /\
        (!t. t IN g ==> open_in top t /\ top closure_of t = topspace top)
        ==> top closure_of INTERS g = topspace top`,
  REPEAT GEN_TAC THEN DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  ASM_CASES_TAC `g:(A->bool)->bool = {}` THENL
   [ONCE_REWRITE_TAC[CLOSURE_OF_RESTRICT] THEN
    ASM_SIMP_TAC[INTERS_0; INTER_UNIV; CLOSURE_OF_TOPSPACE];
    ALL_TAC] THEN
  MP_TAC(ISPECL [`top:A topology`;
                 `IMAGE (\u:A->bool. topspace top DIFF u) g`]
        BAIRE_CATEGORY_ALT) THEN
  ASM_SIMP_TAC[COUNTABLE_IMAGE; FORALL_IN_IMAGE] THEN
  ASM_SIMP_TAC[CLOSED_IN_DIFF; CLOSED_IN_TOPSPACE] THEN
  ASM_SIMP_TAC[INTERIOR_OF_COMPLEMENT; DIFF_EQ_EMPTY] THEN
  REWRITE_TAC[INTERIOR_OF_CLOSURE_OF] THEN
  MATCH_MP_TAC(SET_RULE
    `s SUBSET u /\ s' = s ==> u DIFF s' = {} ==> s = u`) THEN
  REWRITE_TAC[CLOSURE_OF_SUBSET_TOPSPACE] THEN AP_TERM_TAC THEN
  REWRITE_TAC[DIFF_UNIONS; SET_RULE
   `{f y | y IN IMAGE g s} = {f(g x) | x IN s}`] THEN
  MATCH_MP_TAC(SET_RULE `t SUBSET u /\ s = t ==> u INTER s = t`) THEN
  CONJ_TAC THENL [ASM_MESON_TAC[INTERS_SUBSET; OPEN_IN_SUBSET]; ALL_TAC] THEN
  AP_TERM_TAC THEN MATCH_MP_TAC(SET_RULE
   `(!x. x IN s ==> f x = x) ==> {f x | x IN s} = s`) THEN
  X_GEN_TAC `s:A->bool` THEN DISCH_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPEC `s:A->bool`) THEN
  ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN SET_TAC[]);;

(* ------------------------------------------------------------------------- *)
(* Embedding in products and hence more about topological completeness.      *)
(* ------------------------------------------------------------------------- *)

let GDELTA_HOMEOMORPHIC_SPACE_CLOSED_IN_PRODUCT = prove
 (`!top (s:K->A->bool) k.
        metrizable_space top /\ (!i. i IN k ==> open_in top(s i))
        ==> ?t. closed_in
                 (prod_topology top (product_topology k (\i. euclideanreal)))
                 t /\
                 subtopology top (INTERS {s i | i IN k}) homeomorphic_space
                 subtopology
                  (prod_topology top (product_topology k (\i. euclideanreal)))
                  t`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_METRIZABLE_SPACE] THEN
  MAP_EVERY X_GEN_TAC [`m:A metric`; `s:K->A->bool`; `k:K->bool`] THEN
  DISCH_TAC THEN ASM_CASES_TAC `k:K->bool = {}` THENL
   [ASM_REWRITE_TAC[NOT_IN_EMPTY; SET_RULE `{f x |x| F} = {}`] THEN
    REWRITE_TAC[INTERS_0; SUBTOPOLOGY_UNIV;
                PRODUCT_TOPOLOGY_EMPTY_DISCRETE] THEN
    EXISTS_TAC
     `(mspace m:A->bool) CROSS {(\x. ARB):K->real}` THEN
    REWRITE_TAC[CLOSED_IN_CROSS; CLOSED_IN_MSPACE] THEN
    REWRITE_TAC[CLOSED_IN_DISCRETE_TOPOLOGY; SUBSET_REFL] THEN
    REWRITE_TAC[SUBTOPOLOGY_CROSS; SUBTOPOLOGY_MSPACE] THEN
    MATCH_MP_TAC(CONJUNCT1 HOMEOMORPHIC_SPACE_PROD_TOPOLOGY_SING) THEN
    REWRITE_TAC[TOPSPACE_DISCRETE_TOPOLOGY; IN_SING];
    ALL_TAC] THEN
  REPEAT STRIP_TAC THEN
  SUBGOAL_THEN `!i. i IN k ==> (s:K->A->bool) i SUBSET mspace m`
  ASSUME_TAC THENL
   [ASM_MESON_TAC[OPEN_IN_SUBSET; TOPSPACE_MTOPOLOGY]; ALL_TAC] THEN
  SUBGOAL_THEN `INTERS {(s:K->A->bool) i | i IN k} SUBSET mspace m`
  ASSUME_TAC THENL [ASM SET_TAC[]; ALL_TAC] THEN ABBREV_TAC
   `d:K->A->real =
    \i. if ~(i IN k) \/ s i = mspace m then \a. &1
        else \a. inf {mdist m (a,x) |x| x IN mspace m DIFF s i}` THEN
  SUBGOAL_THEN
   `!i. continuous_map (subtopology (mtopology m) (s i),euclideanreal)
        ((d:K->A->real) i)`
  ASSUME_TAC THENL
   [X_GEN_TAC `i:K` THEN EXPAND_TAC "d" THEN REWRITE_TAC[] THEN
    COND_CASES_TAC THEN REWRITE_TAC[CONTINUOUS_MAP_REAL_CONST] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [DE_MORGAN_THM]) THEN
    ASM_SIMP_TAC[OPEN_IN_SUBSET; IMP_CONJ; GSYM TOPSPACE_MTOPOLOGY; SET_RULE
                  `s SUBSET u ==> (~(s = u) <=> ~(u DIFF s = {}))`] THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN REPEAT STRIP_TAC THEN
    REWRITE_TAC[GSYM MTOPOLOGY_SUBMETRIC;
                GSYM MTOPOLOGY_REAL_EUCLIDEAN_METRIC] THEN
    MATCH_MP_TAC LIPSCHITZ_CONTINUOUS_IMP_CONTINUOUS_MAP THEN
    REWRITE_TAC[lipschitz_continuous_map; REAL_EUCLIDEAN_METRIC] THEN
    REWRITE_TAC[SUBSET_UNIV; SUBMETRIC] THEN EXISTS_TAC `&1:real` THEN
    MAP_EVERY X_GEN_TAC [`x:A`; `y:A`] THEN
    REWRITE_TAC[IN_INTER; REAL_MUL_LID] THEN STRIP_TAC THEN
    EXPAND_TAC "d" THEN REWRITE_TAC[REAL_ARITH
     `abs(x - y) <= d <=> x - d <= y /\ y - d <= x`] THEN
    CONJ_TAC THEN
    W(MP_TAC o PART_MATCH (lhand o rand) REAL_LE_INF_EQ o snd) THEN
    ASM_SIMP_TAC[SIMPLE_IMAGE; IMAGE_EQ_EMPTY; FORALL_IN_IMAGE; IN_DIFF] THEN
    (ANTS_TAC THENL [ASM_MESON_TAC[MDIST_POS_LE]; DISCH_THEN SUBST1_TAC]) THEN
    X_GEN_TAC `z:A` THEN STRIP_TAC THEN REWRITE_TAC[REAL_LE_SUB_RADD] THENL
     [TRANS_TAC REAL_LE_TRANS `mdist m (y:A,z)`;
      TRANS_TAC REAL_LE_TRANS `mdist m (x:A,z)`] THEN
    (CONJ_TAC THENL
      [MATCH_MP_TAC INF_LE_ELEMENT THEN
       CONJ_TAC THENL [EXISTS_TAC `&0`; ASM SET_TAC[]] THEN
       ASM_SIMP_TAC[FORALL_IN_IMAGE; IN_DIFF; MDIST_POS_LE];
       MAP_EVERY UNDISCH_TAC
        [`(x:A) IN mspace m`; `(y:A) IN mspace m`; `(z:A) IN mspace m`] THEN
       CONV_TAC METRIC_ARITH]);
    ALL_TAC] THEN
  SUBGOAL_THEN `!i x. x IN s i ==> &0 < (d:K->A->real) i x`
  ASSUME_TAC THENL
   [REPEAT STRIP_TAC THEN EXPAND_TAC "d" THEN REWRITE_TAC[] THEN
    COND_CASES_TAC THEN REWRITE_TAC[REAL_LT_01] THEN
    FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [DE_MORGAN_THM]) THEN
    ASM_SIMP_TAC[OPEN_IN_SUBSET; IMP_CONJ; GSYM TOPSPACE_MTOPOLOGY; SET_RULE
                  `s SUBSET u ==> (~(s = u) <=> ~(u DIFF s = {}))`] THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN REPEAT STRIP_TAC THEN
    MP_TAC(ISPECL
     [`m:A metric`; `(s:K->A->bool) i`] OPEN_IN_MTOPOLOGY) THEN
    ASM_SIMP_TAC[] THEN
    DISCH_THEN(MP_TAC o SPEC `x:A`) THEN ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[SUBSET; IN_MBALL; LEFT_IMP_EXISTS_THM] THEN
    X_GEN_TAC `r:real` THEN STRIP_TAC THEN
    TRANS_TAC REAL_LTE_TRANS `r:real` THEN ASM_REWRITE_TAC[] THEN
    MATCH_MP_TAC REAL_LE_INF THEN
    ASM_REWRITE_TAC[FORALL_IN_GSPEC; GSYM REAL_NOT_LT] THEN
    REPEAT(FIRST_X_ASSUM(MP_TAC o SPEC `i:K`) THEN ASM_REWRITE_TAC[]) THEN
    REPEAT DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN ASM SET_TAC[];
    ALL_TAC] THEN
  ABBREV_TAC `f = \x. x,RESTRICTION k (\i. inv((d:K->A->real) i x))` THEN
  EXISTS_TAC `IMAGE (f:A->A#(K->real)) (INTERS {s(i:K) | i IN k})` THEN
  CONJ_TAC THENL
   [ALL_TAC;
    MP_TAC(snd(EQ_IMP_RULE(ISPECL
     [`subtopology (mtopology m) (INTERS {(s:K->A->bool) i | i IN k})`;
      `product_topology (k:K->bool) (\i. euclideanreal)`;
      `\x. RESTRICTION k (\i. inv((d:K->A->real) i x))`]
        EMBEDDING_MAP_GRAPH))) THEN
    ASM_REWRITE_TAC[] THEN ANTS_TAC THENL
     [REWRITE_TAC[CONTINUOUS_MAP_COMPONENTWISE; SUBSET; FORALL_IN_IMAGE] THEN
      REWRITE_TAC[RESTRICTION_IN_EXTENSIONAL] THEN X_GEN_TAC `i:K` THEN
      SIMP_TAC[RESTRICTION] THEN DISCH_TAC THEN
      MATCH_MP_TAC CONTINUOUS_MAP_REAL_INV THEN CONJ_TAC THENL
       [REWRITE_TAC[ETA_AX] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
         (REWRITE_RULE[IMP_CONJ] CONTINUOUS_MAP_FROM_SUBTOPOLOGY_MONO) o
         SPEC `i:K`) THEN
        ASM SET_TAC[];
        REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; IN_INTER; INTERS_GSPEC] THEN
        ASM_SIMP_TAC[IN_ELIM_THM; REAL_LT_IMP_NZ]];
      DISCH_THEN(MP_TAC o MATCH_MP EMBEDDING_MAP_IMP_HOMEOMORPHIC_SPACE) THEN
      MATCH_MP_TAC EQ_IMP THEN AP_TERM_TAC THEN
      ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY_SUBSET; TOPSPACE_MTOPOLOGY] THEN
      REWRITE_TAC[PROD_TOPOLOGY_SUBTOPOLOGY; SUBTOPOLOGY_SUBTOPOLOGY] THEN
      AP_TERM_TAC THEN MATCH_MP_TAC(SET_RULE
       `(!x. x IN s ==> f x IN t) ==> t INTER IMAGE f s = IMAGE f s`) THEN
      SIMP_TAC[TOPSPACE_PRODUCT_TOPOLOGY; o_DEF; TOPSPACE_EUCLIDEANREAL] THEN
      EXPAND_TAC "f" THEN SIMP_TAC[IN_CROSS] THEN
      REWRITE_TAC[RESTRICTION_IN_CARTESIAN_PRODUCT; IN_UNIV]]] THEN
  REWRITE_TAC[GSYM CLOSURE_OF_SUBSET_EQ] THEN CONJ_TAC THENL
   [EXPAND_TAC "f" THEN REWRITE_TAC[SUBSET; FORALL_IN_IMAGE] THEN
    REWRITE_TAC[TOPSPACE_PROD_TOPOLOGY; TOPSPACE_PRODUCT_TOPOLOGY] THEN
    REWRITE_TAC[o_DEF; TOPSPACE_EUCLIDEANREAL; IN_CROSS] THEN
    REWRITE_TAC[RESTRICTION_IN_CARTESIAN_PRODUCT; IN_UNIV] THEN
    ASM_REWRITE_TAC[GSYM SUBSET; TOPSPACE_MTOPOLOGY];
    ALL_TAC] THEN
  GEN_REWRITE_TAC I [SUBSET] THEN REWRITE_TAC[closure_of] THEN
  REWRITE_TAC[FORALL_PAIR_THM; IN_ELIM_THM; TOPSPACE_PROD_TOPOLOGY] THEN
  MAP_EVERY X_GEN_TAC [`x:A`; `ds:K->real`] THEN
  REWRITE_TAC[IN_CROSS; TOPSPACE_MTOPOLOGY; TOPSPACE_PRODUCT_TOPOLOGY] THEN
  REWRITE_TAC[o_THM; TOPSPACE_EUCLIDEANREAL; IN_UNIV; cartesian_product] THEN
  REWRITE_TAC[IN_ELIM_THM] THEN
  DISCH_THEN(CONJUNCTS_THEN2 STRIP_ASSUME_TAC MP_TAC) THEN
  DISCH_THEN(MP_TAC o GENL [`u:A->bool`; `v:(K->real)->bool`] o
    SPEC `(u:A->bool) CROSS (v:(K->real)->bool)`) THEN
  REWRITE_TAC[IN_CROSS; OPEN_IN_CROSS; SET_RULE
   `(x IN s /\ y IN t) /\ (s = {} \/ t = {} \/ R s t) <=>
    x IN s /\ y IN t /\ R s t`] THEN
  REWRITE_TAC[EXISTS_IN_IMAGE] THEN DISCH_TAC THEN
  SUBGOAL_THEN `x IN INTERS {(s:K->A->bool) i | i IN k}` ASSUME_TAC THENL
   [REWRITE_TAC[INTERS_GSPEC; IN_ELIM_THM] THEN
    X_GEN_TAC `i:K` THEN DISCH_TAC THEN
    GEN_REWRITE_TAC I [TAUT `p <=> ~p ==> F`] THEN DISCH_TAC THEN
    FIRST_X_ASSUM(MP_TAC o SPECL
     [`mball m (x:A,inv(abs(ds(i:K)) + &1))`;
      `{z | z IN topspace(product_topology k (\i. euclideanreal)) /\
            (z:K->real) i IN real_interval(ds i - &1,ds i + &1)}`]) THEN
    REWRITE_TAC[IN_ELIM_THM; NOT_IMP] THEN REPEAT CONJ_TAC THENL
     [MATCH_MP_TAC CENTRE_IN_MBALL THEN
      ASM_REWRITE_TAC[REAL_LT_INV_EQ] THEN REAL_ARITH_TAC;
      ASM_REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; TOPSPACE_EUCLIDEANREAL; o_DEF;
                      cartesian_product; IN_ELIM_THM; IN_UNIV];
      REWRITE_TAC[IN_REAL_INTERVAL] THEN REAL_ARITH_TAC;
      REWRITE_TAC[OPEN_IN_MBALL];
      MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
      EXISTS_TAC `euclideanreal` THEN
      ASM_SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION] THEN
      REWRITE_TAC[GSYM REAL_OPEN_IN; REAL_OPEN_REAL_INTERVAL];
      ALL_TAC] THEN
    EXPAND_TAC "f" THEN REWRITE_TAC[INTERS_GSPEC; IN_ELIM_THM] THEN
    REWRITE_TAC[NOT_EXISTS_THM; IN_CROSS; IN_ELIM_THM] THEN
    X_GEN_TAC `y:A` THEN
    DISCH_THEN(CONJUNCTS_THEN2 (MP_TAC o SPEC `i:K`) ASSUME_TAC) THEN
    ASM_REWRITE_TAC[] THEN DISCH_TAC THEN
    FIRST_X_ASSUM(CONJUNCTS_THEN MP_TAC) THEN
    DISCH_THEN(MP_TAC o CONJUNCT2) THEN ASM_REWRITE_TAC[RESTRICTION] THEN
    DISCH_TAC THEN ASM_REWRITE_TAC[IN_MBALL] THEN
    DISCH_THEN(CONJUNCTS_THEN2 ASSUME_TAC MP_TAC) THEN
    REWRITE_TAC[REAL_NOT_LT] THEN
    TRANS_TAC REAL_LE_TRANS `(d:K->A->real) i y` THEN CONJ_TAC THENL
     [MATCH_MP_TAC REAL_LE_LINV THEN ASM_SIMP_TAC[] THEN
      FIRST_X_ASSUM(MP_TAC o GEN_REWRITE_RULE I [IN_REAL_INTERVAL]) THEN
      REAL_ARITH_TAC;
      EXPAND_TAC "d" THEN REWRITE_TAC[] THEN
      COND_CASES_TAC THENL [ASM SET_TAC[]; REWRITE_TAC[]] THEN
      MATCH_MP_TAC INF_LE_ELEMENT THEN CONJ_TAC THENL
       [EXISTS_TAC `&0` THEN
        ASM_SIMP_TAC[FORALL_IN_GSPEC; IN_DIFF; MDIST_POS_LE];
        REWRITE_TAC[IN_ELIM_THM] THEN EXISTS_TAC `x:A` THEN
        ASM_REWRITE_TAC[IN_DIFF] THEN ASM_MESON_TAC[MDIST_SYM]]];
    REWRITE_TAC[IN_IMAGE] THEN EXISTS_TAC `x:A` THEN
    ASM_REWRITE_TAC[] THEN EXPAND_TAC "f" THEN REWRITE_TAC[PAIR_EQ] THEN
    GEN_REWRITE_TAC I [FUN_EQ_THM] THEN X_GEN_TAC `i:K` THEN
    REWRITE_TAC[RESTRICTION] THEN
    COND_CASES_TAC THENL
     [ALL_TAC;
      RULE_ASSUM_TAC(REWRITE_RULE[EXTENSIONAL]) THEN ASM SET_TAC[]] THEN
    REWRITE_TAC[REAL_ARITH `x = y <=> ~(&0 < abs(x - y))`] THEN DISCH_TAC THEN
    FIRST_ASSUM(MP_TAC o
      MATCH_MP (REWRITE_RULE[IMP_CONJ] CONTINUOUS_MAP_REAL_INV) o
      SPEC `i:K`) THEN
    ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY; REAL_LT_IMP_NZ; IN_INTER] THEN
    ABBREV_TAC `e = abs (ds i - inv((d:K->A->real) i x))` THEN
    REWRITE_TAC[continuous_map] THEN DISCH_THEN(MP_TAC o SPEC
     `real_interval(inv((d:K->A->real) i x) - e / &2,inv(d i x) + e / &2)` o
     CONJUNCT2) THEN
    REWRITE_TAC[GSYM REAL_OPEN_IN; REAL_OPEN_REAL_INTERVAL] THEN
    ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY_SUBSET; TOPSPACE_MTOPOLOGY] THEN
    REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN
    DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
    FIRST_X_ASSUM(MP_TAC o SPECL
     [`u:A->bool`;
      `{z | z IN topspace(product_topology k (\i:K. euclideanreal)) /\
            z i IN real_interval(ds i - e / &2,ds i + e / &2)}`]) THEN
    ASM_REWRITE_TAC[IN_ELIM_THM; NOT_IMP] THEN REPEAT CONJ_TAC THENL
     [FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
       `s = u INTER t ==> x IN s ==>  x IN u`)) THEN
      REWRITE_TAC[IN_REAL_INTERVAL; IN_ELIM_THM] THEN
      CONJ_TAC THENL [ASM SET_TAC[]; ASM_REAL_ARITH_TAC];
      REWRITE_TAC[TOPSPACE_PRODUCT_TOPOLOGY; cartesian_product] THEN
      ASM_REWRITE_TAC[o_THM; TOPSPACE_EUCLIDEANREAL; IN_UNIV; IN_ELIM_THM];
      REWRITE_TAC[IN_REAL_INTERVAL] THEN ASM_REAL_ARITH_TAC;
      MATCH_MP_TAC OPEN_IN_CONTINUOUS_MAP_PREIMAGE THEN
      EXISTS_TAC `euclideanreal` THEN
      ASM_SIMP_TAC[CONTINUOUS_MAP_PRODUCT_PROJECTION] THEN
      REWRITE_TAC[GSYM REAL_OPEN_IN; REAL_OPEN_REAL_INTERVAL];
      ALL_TAC] THEN
    EXPAND_TAC "f" THEN REWRITE_TAC[IN_CROSS; IN_ELIM_THM] THEN
    ASM_REWRITE_TAC[RESTRICTION; NOT_EXISTS_THM] THEN X_GEN_TAC `y:A` THEN
    GEN_REWRITE_TAC RAND_CONV [CONJ_ASSOC] THEN
    DISCH_THEN(CONJUNCTS_THEN2 MP_TAC ASSUME_TAC) THEN
    FIRST_ASSUM(MATCH_MP_TAC o MATCH_MP (SET_RULE
     `t = u INTER s i
      ==> i IN k /\ ~(y IN t)
          ==> y IN INTERS {s i | i  IN k} /\ y IN u ==> F`)) THEN
    ASM_REWRITE_TAC[IN_ELIM_THM] THEN
    DISCH_THEN(MP_TAC o CONJUNCT2) THEN
    FIRST_X_ASSUM(MP_TAC o CONJUNCT2) THEN
    REWRITE_TAC[IN_REAL_INTERVAL] THEN
    EXPAND_TAC "e" THEN REAL_ARITH_TAC]);;

let OPEN_HOMEOMORPHIC_SPACE_CLOSED_IN_PRODUCT = prove
 (`!top (s:A->bool).
        metrizable_space top /\ open_in top s
        ==> ?t. closed_in (prod_topology top euclideanreal) t /\
                subtopology top s homeomorphic_space
                subtopology (prod_topology top euclideanreal) t`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`top:A topology`; `(\x. s):1->A->bool`; `{one}`]
        GDELTA_HOMEOMORPHIC_SPACE_CLOSED_IN_PRODUCT) THEN
  ASM_REWRITE_TAC[SET_RULE `INTERS {s |i| i IN {a}} = s`] THEN
  DISCH_THEN(X_CHOOSE_THEN `t:A#(1->real)->bool` STRIP_ASSUME_TAC) THEN
  SUBGOAL_THEN
   `prod_topology (top:A topology) (product_topology {one} (\i. euclideanreal))
    homeomorphic_space prod_topology top euclideanreal`
  MP_TAC THENL
   [MATCH_MP_TAC HOMEOMORPHIC_SPACE_PROD_TOPOLOGY THEN
    REWRITE_TAC[HOMEOMORPHIC_SPACE_SINGLETON_PRODUCT; HOMEOMORPHIC_SPACE_REFL];
    REWRITE_TAC[HOMEOMORPHIC_SPACE; LEFT_IMP_EXISTS_THM]] THEN
  X_GEN_TAC `f:A#(1->real)->A#real` THEN DISCH_TAC THEN
  EXISTS_TAC `IMAGE (f:A#(1->real)->A#real) t` THEN CONJ_TAC THENL
   [ASM_MESON_TAC[HOMEOMORPHIC_MAP_CLOSEDNESS_EQ]; ALL_TAC] THEN
  REWRITE_TAC[GSYM HOMEOMORPHIC_SPACE] THEN
  FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (ONCE_REWRITE_RULE[IMP_CONJ]
      HOMEOMORPHIC_SPACE_TRANS)) THEN
  REWRITE_TAC[HOMEOMORPHIC_SPACE] THEN EXISTS_TAC `f:A#(1->real)->A#real` THEN
  MATCH_MP_TAC HOMEOMORPHIC_MAP_SUBTOPOLOGIES THEN
  ASM_REWRITE_TAC[] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[HOMEOMORPHIC_EQ_EVERYTHING_MAP]) THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP CLOSED_IN_SUBSET) THEN ASM SET_TAC[]);;

let COMPLETELY_METRIZABLE_SPACE_GDELTA_IN_ALT = prove
 (`!top s:A->bool.
        completely_metrizable_space top /\
        (COUNTABLE INTERSECTION_OF open_in top) s
        ==> completely_metrizable_space (subtopology top s)`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM; FORALL_INTERSECTION_OF] THEN
  X_GEN_TAC `top:A topology` THEN DISCH_TAC THEN
  X_GEN_TAC `u:(A->bool)->bool` THEN REPEAT DISCH_TAC THEN
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`top:A topology`; `(\x:A->bool. x)`; `u:(A->bool)->bool`]
        GDELTA_HOMEOMORPHIC_SPACE_CLOSED_IN_PRODUCT) THEN
  ASM_SIMP_TAC[COMPLETELY_METRIZABLE_IMP_METRIZABLE_SPACE; IN_GSPEC] THEN
  DISCH_THEN(X_CHOOSE_THEN `c:A#((A->bool)->real)->bool` STRIP_ASSUME_TAC) THEN
  FIRST_X_ASSUM(SUBST1_TAC o
    MATCH_MP HOMEOMORPHIC_COMPLETELY_METRIZABLE_SPACE) THEN
  MATCH_MP_TAC COMPLETELY_METRIZABLE_SPACE_CLOSED_IN THEN
  ASM_REWRITE_TAC[COMPLETELY_METRIZABLE_SPACE_PROD_TOPOLOGY] THEN
  REWRITE_TAC[COMPLETELY_METRIZABLE_SPACE_EUCLIDEANREAL;
              COMPLETELY_METRIZABLE_SPACE_PRODUCT_TOPOLOGY] THEN
  ASM_SIMP_TAC[COUNTABLE_RESTRICT]);;

let COMPLETELY_METRIZABLE_SPACE_GDELTA_IN = prove
 (`!top s:A->bool.
        completely_metrizable_space top /\ gdelta_in top s
        ==> completely_metrizable_space (subtopology top s)`,
  SIMP_TAC[GDELTA_IN_ALT; COMPLETELY_METRIZABLE_SPACE_GDELTA_IN_ALT]);;

let COMPLETELY_METRIZABLE_SPACE_OPEN_IN = prove
 (`!top s:A->bool.
        completely_metrizable_space top /\ open_in top s
        ==> completely_metrizable_space (subtopology top s)`,
  SIMP_TAC[COMPLETELY_METRIZABLE_SPACE_GDELTA_IN; OPEN_IMP_GDELTA_IN]);;

let LOCALLY_COMPACT_IMP_COMPLETELY_METRIZABLE_SPACE = prove
 (`!top:A topology.
        metrizable_space top /\ locally_compact_space top
        ==> completely_metrizable_space top`,
  REWRITE_TAC[IMP_CONJ; FORALL_METRIZABLE_SPACE] THEN
  X_GEN_TAC `m:A metric` THEN DISCH_TAC THEN
  MP_TAC(ISPEC `m:A metric` METRIC_COMPLETION) THEN
  REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`m':(A->real)metric`; `f:A->A->real`] THEN
  STRIP_TAC THEN
  SUBGOAL_THEN
   `mtopology m homeomorphic_space
    subtopology (mtopology m') (IMAGE (f:A->A->real) (mspace m))`
  ASSUME_TAC THENL
   [MP_TAC(ISPECL [`m:A metric`; `m':(A->real)metric`; `f:A->A->real`]
        ISOMETRY_IMP_EMBEDDING_MAP) THEN
    ASM_SIMP_TAC[SUBSET_REFL] THEN
    DISCH_THEN(MP_TAC o MATCH_MP EMBEDDING_MAP_IMP_HOMEOMORPHIC_SPACE) THEN
    REWRITE_TAC[TOPSPACE_MTOPOLOGY];
    ALL_TAC] THEN
  FIRST_ASSUM(SUBST1_TAC o
    MATCH_MP HOMEOMORPHIC_COMPLETELY_METRIZABLE_SPACE) THEN
  FIRST_X_ASSUM(MP_TAC o
    MATCH_MP HOMEOMORPHIC_LOCALLY_COMPACT_SPACE) THEN
  ASM_REWRITE_TAC[] THEN DISCH_THEN(MP_TAC o MATCH_MP
   (ONCE_REWRITE_RULE[IMP_CONJ_ALT] (REWRITE_RULE[CONJ_ASSOC]
        LOCALLY_COMPACT_SUBSPACE_OPEN_IN_CLOSURE_OF))) THEN
  ASM_REWRITE_TAC[HAUSDORFF_SPACE_MTOPOLOGY; SUBTOPOLOGY_MSPACE] THEN
  ASM_REWRITE_TAC[TOPSPACE_MTOPOLOGY] THEN DISCH_TAC THEN
  MATCH_MP_TAC COMPLETELY_METRIZABLE_SPACE_OPEN_IN THEN
  ASM_SIMP_TAC[COMPLETELY_METRIZABLE_SPACE_MTOPOLOGY]);;

let COMPLETELY_METRIZABLE_SPACE_IMP_GDELTA_IN = prove
 (`!top s:A->bool.
        metrizable_space top /\ s SUBSET topspace top /\
        completely_metrizable_space (subtopology top s)
        ==> gdelta_in top s`,
  REPEAT STRIP_TAC THEN
  MP_TAC(ISPECL [`top:A topology`; `s:A->bool`;
                 `subtopology top s:A topology`; `\x:A. x`]
        LAVRENTIEV_EXTENSION) THEN
  ASM_REWRITE_TAC[CONTINUOUS_MAP_ID; LEFT_IMP_EXISTS_THM] THEN
  MAP_EVERY X_GEN_TAC [`u:A->bool`; `f:A->A`] THEN STRIP_TAC THEN
  SUBGOAL_THEN `s:A->bool = u` (fun th -> ASM_REWRITE_TAC[th]) THEN
  ASM_REWRITE_TAC[GSYM SUBSET_ANTISYM_EQ] THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP CONTINUOUS_MAP_IMAGE_SUBSET_TOPSPACE) THEN
  ASM_SIMP_TAC[TOPSPACE_SUBTOPOLOGY_SUBSET; GDELTA_IN_SUBSET] THEN
  MATCH_MP_TAC(SET_RULE
    `(!x. x IN u ==> f x = x) ==> IMAGE f u SUBSET s ==> u SUBSET s`) THEN
  MP_TAC(ISPECL
   [`subtopology top u:A topology`; `subtopology top u:A topology`;
   `f:A->A`; `\x:A. x`] FORALL_IN_CLOSURE_OF_EQ) THEN
  ASM_SIMP_TAC[CLOSURE_OF_SUBTOPOLOGY; CONTINUOUS_MAP_ID; SET_RULE
   `s SUBSET u ==> u INTER s = s`] THEN
  ANTS_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
  ASM_SIMP_TAC[HAUSDORFF_SPACE_SUBTOPOLOGY;
               METRIZABLE_IMP_HAUSDORFF_SPACE] THEN
  UNDISCH_TAC
   `continuous_map (subtopology top u,subtopology top s) (f:A->A)` THEN
  SIMP_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY] THEN ASM SET_TAC[]);;

let COMPLETELY_METRIZABLE_SPACE_EQ_GDELTA_IN = prove
 (`!top s:A->bool.
        completely_metrizable_space top /\ s SUBSET topspace top
        ==> (completely_metrizable_space (subtopology top s) <=>
             gdelta_in top s)`,
  MESON_TAC[COMPLETELY_METRIZABLE_SPACE_GDELTA_IN;
            COMPLETELY_METRIZABLE_SPACE_IMP_GDELTA_IN;
            COMPLETELY_METRIZABLE_IMP_METRIZABLE_SPACE]);;

let GDELTA_IN_EQ_COMPLETELY_METRIZABLE_SPACE = prove
 (`!top s:A->bool.
        completely_metrizable_space top
        ==> (gdelta_in top s <=>
             s SUBSET topspace top /\
             completely_metrizable_space (subtopology top s))`,
  MESON_TAC[GDELTA_IN_ALT; COMPLETELY_METRIZABLE_SPACE_EQ_GDELTA_IN]);;

(* ------------------------------------------------------------------------- *)
(* Basic definition of the small inductive dimension relation ind t <= n.    *)
(* We plan to prove most of the theorems in R^n so this is as good a         *)
(* definition as any other, but the present stuff works in any top space.    *)
(* ------------------------------------------------------------------------- *)

parse_as_infix("dimension_le",(12,"right"));;

let DIMENSION_LE_RULES,DIMENSION_LE_INDUCT,DIMENSION_LE_CASES =
  new_inductive_definition
  `!top n. -- &1 <= n /\
           (!v a. open_in top v /\ a IN v
                  ==> ?u. a IN u /\ u SUBSET v /\ open_in top u /\
                          subtopology top (top frontier_of u)
                          dimension_le (n - &1))
            ==> (top:A topology) dimension_le (n:int)`;;

let DIMENSION_LE_NEIGHBOURHOOD_BASE = prove
 (`!(top:A topology) n.
        top dimension_le n <=>
        -- &1 <= n /\
        neighbourhood_base_of
         (\u. open_in top u /\
              (subtopology top (top frontier_of u))
              dimension_le (n - &1)) top`,
  REPEAT GEN_TAC THEN SIMP_TAC[OPEN_NEIGHBOURHOOD_BASE_OF] THEN
  GEN_REWRITE_TAC LAND_CONV [DIMENSION_LE_CASES] THEN MESON_TAC[]);;

let DIMENSION_LE_BOUND = prove
 (`!top:(A)topology n. top dimension_le n ==> -- &1 <= n`,
  MATCH_MP_TAC DIMENSION_LE_INDUCT THEN SIMP_TAC[]);;

let DIMENSION_LE_MONO = prove
 (`!top:(A)topology m n. top dimension_le m /\ m <= n ==> top dimension_le n`,
  REWRITE_TAC[IMP_CONJ; RIGHT_FORALL_IMP_THM] THEN
  MATCH_MP_TAC DIMENSION_LE_INDUCT THEN
  MAP_EVERY X_GEN_TAC [`top:(A)topology`; `m:int`] THEN STRIP_TAC THEN
  X_GEN_TAC `n:int` THEN DISCH_TAC THEN
  GEN_REWRITE_TAC I [DIMENSION_LE_CASES] THEN
  CONJ_TAC THENL [ASM_MESON_TAC[INT_LE_TRANS]; ALL_TAC] THEN
  MAP_EVERY X_GEN_TAC [`v:A->bool`; `a:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`v:A->bool`; `a:A`]) THEN
  ASM_REWRITE_TAC[] THEN MATCH_MP_TAC MONO_EXISTS THEN
  GEN_TAC THEN STRIP_TAC THEN ASM_REWRITE_TAC[] THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN ASM_INT_ARITH_TAC);;

let DIMENSION_LE_EQ_EMPTY = prove
 (`!top:(A)topology. top dimension_le (-- &1) <=> topspace top = {}`,
  REPEAT GEN_TAC THEN ONCE_REWRITE_TAC[DIMENSION_LE_CASES] THEN
  CONV_TAC INT_REDUCE_CONV THEN
  SUBGOAL_THEN `!top:A topology. ~(top dimension_le --(&2))`
   (fun th -> REWRITE_TAC[th])
  THENL
   [GEN_TAC THEN DISCH_THEN(MP_TAC o MATCH_MP DIMENSION_LE_BOUND) THEN
    INT_ARITH_TAC;
    EQ_TAC THENL
     [DISCH_THEN(MP_TAC o SPEC `topspace top:A->bool`) THEN
      REWRITE_TAC[OPEN_IN_TOPSPACE] THEN SET_TAC[];
      REPEAT STRIP_TAC THEN
      FIRST_ASSUM(MP_TAC o MATCH_MP OPEN_IN_SUBSET) THEN
      ASM SET_TAC[]]]);;

let DIMENSION_LE_0_NEIGHBOURHOOD_BASE_OF_CLOPEN = prove
 (`!top:A topology.
        top dimension_le &0 <=>
        neighbourhood_base_of (\u. closed_in top u /\ open_in top u) top`,
  GEN_TAC THEN GEN_REWRITE_TAC LAND_CONV [DIMENSION_LE_NEIGHBOURHOOD_BASE] THEN
  CONV_TAC INT_REDUCE_CONV THEN
  REWRITE_TAC[DIMENSION_LE_EQ_EMPTY; TOPSPACE_SUBTOPOLOGY] THEN
  AP_THM_TAC THEN AP_TERM_TAC THEN ABS_TAC THEN
  SIMP_TAC[FRONTIER_OF_SUBSET_TOPSPACE; SET_RULE
   `s SUBSET u ==> u INTER s = s`] THEN
  MESON_TAC[FRONTIER_OF_EQ_EMPTY; OPEN_IN_SUBSET]);;

let DIMENSION_LE_SUBTOPOLOGY = prove
 (`!top n s:A->bool.
        top dimension_le n ==> (subtopology top s) dimension_le n`,
  REWRITE_TAC[RIGHT_FORALL_IMP_THM] THEN MATCH_MP_TAC DIMENSION_LE_INDUCT THEN
  MAP_EVERY X_GEN_TAC [`top:A topology`; `n:int`] THEN STRIP_TAC THEN
  X_GEN_TAC `s:A->bool` THEN GEN_REWRITE_TAC I [DIMENSION_LE_CASES] THEN
  ASM_REWRITE_TAC[] THEN MAP_EVERY X_GEN_TAC [`u':A->bool`; `a:A`] THEN
  GEN_REWRITE_TAC (LAND_CONV o LAND_CONV) [OPEN_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[IMP_CONJ; LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `u:A->bool` THEN DISCH_TAC THEN DISCH_THEN SUBST1_TAC THEN
  REWRITE_TAC[IN_INTER] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`u:A->bool`; `a:A`]) THEN
  ASM_REWRITE_TAC[LEFT_IMP_EXISTS_THM] THEN
  X_GEN_TAC `v:A->bool` THEN STRIP_TAC THEN
  EXISTS_TAC `s INTER v:A->bool` THEN
  ASM_REWRITE_TAC[IN_INTER] THEN REPEAT CONJ_TAC THENL
   [ASM SET_TAC[];
    REWRITE_TAC[OPEN_IN_SUBTOPOLOGY] THEN ASM_MESON_TAC[INTER_COMM];
    FIRST_X_ASSUM(MP_TAC o SPEC
     `subtopology top s frontier_of (s INTER v):A->bool`) THEN
    REWRITE_TAC[SUBTOPOLOGY_SUBTOPOLOGY] THEN
    MATCH_MP_TAC EQ_IMP THEN AP_THM_TAC THEN AP_TERM_TAC THEN
    AP_TERM_TAC THEN MATCH_MP_TAC(SET_RULE
     `s SUBSET u /\ s SUBSET t ==> t INTER s = u INTER s`) THEN
    REWRITE_TAC[FRONTIER_OF_SUBSET_SUBTOPOLOGY] THEN
    REWRITE_TAC[FRONTIER_OF_CLOSURES; CLOSURE_OF_SUBTOPOLOGY] THEN
    REWRITE_TAC[TOPSPACE_SUBTOPOLOGY; INTER_ASSOC] THEN
    MATCH_MP_TAC(SET_RULE
     `t SUBSET u /\ v SUBSET w
      ==> s INTER t INTER s INTER v SUBSET u INTER w`) THEN
    CONJ_TAC THEN MATCH_MP_TAC CLOSURE_OF_MONO THEN SET_TAC[]]);;

let DIMENSION_LE_SUBTOPOLOGIES = prove
 (`!top n s t:A->bool.
        s SUBSET t /\
        subtopology top t dimension_le n
        ==> (subtopology top s) dimension_le n`,
  REPEAT STRIP_TAC THEN FIRST_ASSUM(MP_TAC o
    ISPEC `s:A->bool` o MATCH_MP DIMENSION_LE_SUBTOPOLOGY) THEN
  REWRITE_TAC[SUBTOPOLOGY_SUBTOPOLOGY] THEN
  ASM_SIMP_TAC[SET_RULE `s SUBSET t ==> t INTER s = s`]);;

let DIMENSION_LE_EQ_SUBTOPOLOGY = prove
 (`!top s:A->bool n.
        (subtopology top s) dimension_le n <=>
        -- &1 <= n /\
        !v a. open_in top v /\ a IN v /\ a IN s
              ==> ?u. a IN u /\ u SUBSET v /\ open_in top u /\
                      subtopology top
                       ((subtopology top s frontier_of (s INTER u)))
                      dimension_le (n - &1)`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC LAND_CONV [DIMENSION_LE_CASES] THEN
  REWRITE_TAC[SUBTOPOLOGY_SUBTOPOLOGY; OPEN_IN_SUBTOPOLOGY] THEN
  REWRITE_TAC[LEFT_AND_EXISTS_THM; LEFT_IMP_EXISTS_THM] THEN
  ONCE_REWRITE_TAC[MESON[]
   `(!v a t. (P t /\ Q v t) /\ R a v t ==> S a v t) <=>
    (!t a v. Q v t ==> P t /\ R a v t ==> S a v t)`] THEN
  REWRITE_TAC[FORALL_UNWIND_THM2] THEN AP_TERM_TAC THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `v:A->bool` THEN REWRITE_TAC[] THEN
  AP_TERM_TAC THEN GEN_REWRITE_TAC I [FUN_EQ_THM] THEN
  X_GEN_TAC `a:A` THEN REWRITE_TAC[IN_INTER] THEN
  MATCH_MP_TAC(TAUT `(p ==> (q <=> r)) ==> (p ==> q <=> p ==> r)`) THEN
  STRIP_TAC THEN REWRITE_TAC[RIGHT_AND_EXISTS_THM] THEN
  GEN_REWRITE_TAC LAND_CONV [SWAP_EXISTS_THM] THEN
  ONCE_REWRITE_TAC[TAUT
    `p /\ q /\ (r /\ s) /\ t <=> s /\ p /\ q /\ r /\ t`] THEN
  ASM_REWRITE_TAC[UNWIND_THM2; IN_INTER] THEN
  EQ_TAC THEN DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `u INTER v:A->bool` THEN
  ASM_SIMP_TAC[IN_INTER; OPEN_IN_INTER] THEN
  (CONJ_TAC THENL [ASM SET_TAC[]; ALL_TAC]) THEN
  ASM_SIMP_TAC[SET_RULE `u SUBSET v ==> u INTER v = u`;
               SET_RULE `u INTER s SUBSET v INTER s
                         ==> s INTER u INTER v = s INTER u`] THEN
  POP_ASSUM_LIST(MP_TAC o end_itlist CONJ o rev) THEN
  ASM_SIMP_TAC[FRONTIER_OF_SUBSET_SUBTOPOLOGY;
               SET_RULE `v SUBSET u ==> u INTER v = v`] THEN
  STRIP_TAC THEN ONCE_REWRITE_TAC[INTER_COMM] THEN ASM_REWRITE_TAC[]);;

let DIMENSION_LE_DISCRETE_TOPOLOGY = prove
 (`!u:A->bool. (discrete_topology u) dimension_le &0`,
  GEN_TAC THEN ONCE_REWRITE_TAC[DIMENSION_LE_CASES] THEN
  CONV_TAC INT_REDUCE_CONV THEN
  REWRITE_TAC[OPEN_IN_DISCRETE_TOPOLOGY; DISCRETE_TOPOLOGY_FRONTIER_OF] THEN
  REWRITE_TAC[DIMENSION_LE_EQ_EMPTY; TOPSPACE_SUBTOPOLOGY; INTER_EMPTY] THEN
  SET_TAC[]);;

let ZERO_DIMENSIONAL_IMP_COMPLETELY_REGULAR_SPACE = prove
 (`!top:A topology. top dimension_le &0 ==> completely_regular_space top`,
  GEN_TAC THEN REWRITE_TAC[DIMENSION_LE_0_NEIGHBOURHOOD_BASE_OF_CLOPEN] THEN
  SIMP_TAC[OPEN_NEIGHBOURHOOD_BASE_OF] THEN DISCH_TAC THEN
  REWRITE_TAC[completely_regular_space; IN_DIFF] THEN
  MAP_EVERY X_GEN_TAC [`c:A->bool`; `a:A`] THEN STRIP_TAC THEN
  FIRST_X_ASSUM(MP_TAC o SPECL [`topspace top DIFF c:A->bool`; `a:A`]) THEN
  ASM_SIMP_TAC[IN_DIFF; OPEN_IN_DIFF; OPEN_IN_TOPSPACE] THEN
  DISCH_THEN(X_CHOOSE_THEN `u:A->bool` STRIP_ASSUME_TAC) THEN
  EXISTS_TAC `(\x. if x IN u then &0 else &1):A->real` THEN
  ASM_REWRITE_TAC[] THEN CONJ_TAC THENL [ALL_TAC; ASM SET_TAC[]] THEN
  REWRITE_TAC[CONTINUOUS_MAP_IN_SUBTOPOLOGY; SUBSET; FORALL_IN_IMAGE] THEN
  CONJ_TAC THENL [ALL_TAC; ASM_MESON_TAC[ENDS_IN_UNIT_REAL_INTERVAL]] THEN
  REWRITE_TAC[continuous_map; TOPSPACE_EUCLIDEANREAL; IN_UNIV] THEN
  X_GEN_TAC `r:real->bool` THEN DISCH_TAC THEN REWRITE_TAC[TAUT
    `(if p then a else b) IN r <=> p /\ a IN r \/ ~p /\ b IN r`] THEN
  MAP_EVERY ASM_CASES_TAC [`(&0:real) IN r`; `(&1:real) IN r`] THEN
  ASM_REWRITE_TAC[EMPTY_GSPEC; OPEN_IN_EMPTY; OPEN_IN_TOPSPACE;
                  IN_GSPEC; TAUT `p \/ ~p`] THEN
  ASM_REWRITE_TAC[GSYM DIFF; GSYM INTER] THEN
  ASM_SIMP_TAC[OPEN_IN_TOPSPACE; OPEN_IN_INTER; OPEN_IN_DIFF]);;

let ZERO_DIMENSIONAL_IMP_REGULAR_SPACE = prove
 (`!top:A topology. top dimension_le &0 ==> regular_space top`,
  MESON_TAC[COMPLETELY_REGULAR_IMP_REGULAR_SPACE;
            ZERO_DIMENSIONAL_IMP_COMPLETELY_REGULAR_SPACE]);;
