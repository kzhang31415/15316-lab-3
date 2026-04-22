import pca_logic as pca

# Counter to generate fresh variables
count = 0

def fresh_var(x: pca.Variable) -> pca.Variable:
    global count
    x_prime_id = f"{x.id}'{count}"
    count += 1
    return pca.Variable(x_prime_id)

def _term_free_vars(t: pca.Term) -> set[str]:
    match t:
        case pca.Variable(id):
            return {id}
        case pca.Constant(_):
            return set()
        case _:
            raise TypeError(f"Unknown term type: {type(t)}")

def _term_subst(x: pca.Variable, t: pca.Term, s: pca.Term) -> pca.Term:
    match s:
        case pca.Variable(id):
            return t if id == x.id else s
        case pca.Constant(_):
            return s
        case _:
            raise TypeError(f"Unknown term type: {type(s)}")

def eq_term(s: pca.Term, t: pca.Term) -> bool:
    match (s, t):
        case (pca.Variable(x), pca.Variable(y)):
            return x == y
        case (pca.Constant(c1), pca.Constant(c2)):
            return c1 == c2
        case _:
            return False

def _eq_term_alpha(
    s: pca.Term,
    t: pca.Term,
    left_to_right: dict[str, str],
    right_to_left: dict[str, str],
) -> bool:
    match (s, t):
        case (pca.Constant(c1), pca.Constant(c2)):
            return c1 == c2
        case (pca.Variable(x), pca.Variable(y)):
            left_bound = x in left_to_right
            right_bound = y in right_to_left
            if left_bound or right_bound:
                return left_to_right.get(x) == y and right_to_left.get(y) == x
            return x == y
        case _:
            return False

def eq_form(p: pca.Form, q: pca.Form) -> bool:
    def go(
        p0: pca.Form,
        q0: pca.Form,
        left_to_right: dict[str, str],
        right_to_left: dict[str, str],
    ) -> bool:
        match (p0, q0):
            case (pca.Atom(pred1, ts1), pca.Atom(pred2, ts2)):
                if pred1.name != pred2.name or len(ts1) != len(ts2):
                    return False
                return all(
                    _eq_term_alpha(s, t, left_to_right, right_to_left)
                    for s, t in zip(ts1, ts2)
                )
            case (pca.Says(a1, f1), pca.Says(a2, f2)):
                return _eq_term_alpha(a1, a2, left_to_right, right_to_left) and go(
                    f1, f2, left_to_right, right_to_left
                )
            case (pca.Implies(prem1, conc1), pca.Implies(prem2, conc2)):
                return go(prem1, prem2, left_to_right, right_to_left) and go(
                    conc1, conc2, left_to_right, right_to_left
                )
            case (pca.Forall(v1, f1), pca.Forall(v2, f2)):
                l2r = dict(left_to_right)
                r2l = dict(right_to_left)
                l2r[v1.id] = v2.id
                r2l[v2.id] = v1.id
                return go(f1, f2, l2r, r2l)
            case _:
                return False

    return go(p, q, {}, {})

def subst_form(x: pca.Variable, t: pca.Term, p: pca.Form) -> pca.Form:
    match p:
        case pca.Atom(predicate, terms):
            return pca.Atom(predicate=predicate, terms=[_term_subst(x, t, s) for s in terms])
        case pca.Says(agent, formula):
            return pca.Says(
                agent=_term_subst(x, t, agent),
                formula=subst_form(x, t, formula),
            )
        case pca.Implies(premise, conclusion):
            return pca.Implies(
                premise=subst_form(x, t, premise),
                conclusion=subst_form(x, t, conclusion),
            )
        case pca.Forall(y, formula):
            if y.id == x.id:
                return p

            if y.id in _term_free_vars(t):
                y_prime = fresh_var(y)
                alpha_renamed = subst_form(y, y_prime, formula)
                return pca.Forall(y_prime, subst_form(x, t, alpha_renamed))

            return pca.Forall(y, subst_form(x, t, formula))
        case _:
            raise TypeError(f"Unknown form type: {type(p)}")
