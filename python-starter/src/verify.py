import pca_logic as pca
from utils import eq_term, eq_form, subst_form

class VerifyException(Exception):
    """
    Exception raised during verification errors.

    Args:
        message (str): The error message describing the issue.
    """
    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


def check_policy(gamma: pca.Policy):
    """
    Checks if the given policy `gamma` is well-formed.

    Args:
        gamma (Policy): The policy to check.

    Raises:
        VerifyException: If `gamma` is not a well-formed policy.
    """
    seen: set[str] = set()

    def check_term_bound(t: pca.Term, bound_vars: set[str]) -> None:
        match t:
            case pca.Constant(_):
                return
            case pca.Variable(id):
                if id not in bound_vars:
                    raise VerifyException(f"unbound variable {id} in policy")
            case _:
                raise VerifyException(f"unknown term in policy: {t}")

    def check_form_well_formed(f: pca.Form, bound_vars: set[str]) -> None:
        match f:
            case pca.Atom(_, terms):
                for t in terms:
                    check_term_bound(t, bound_vars)
            case pca.Says(agent, formula):
                check_term_bound(agent, bound_vars)
                check_form_well_formed(formula, bound_vars)
            case pca.Implies(premise, conclusion):
                check_form_well_formed(premise, bound_vars)
                check_form_well_formed(conclusion, bound_vars)
            case pca.Forall(v, formula):
                if v.id in bound_vars:
                    raise VerifyException(f"shadowed quantifier {v.id} in policy")
                bound_next = set(bound_vars)
                bound_next.add(v.id)
                check_form_well_formed(formula, bound_next)
            case _:
                raise VerifyException(f"unknown formula in policy: {f}")

    for decl in gamma:
        name = decl.constant.name
        if name in seen:
            raise VerifyException(f"duplicate policy variable {name}")
        seen.add(name)
        check_form_well_formed(decl.formula, set())


def verify(gamma: pca.Policy, m: pca.Proof, p: pca.Form):
    """
    Verifies that the judgment `gamma ⊢ m ⇐ p` holds.

    Args:
        gamma (Policy): The policy under which to verify the proof.
        m (Proof): The proof to verify.
        p (Form): The formula to verify.

    Raises:
        VerifyException: If the verification `gamma ⊢ m ⇐ p` fails.
    """
    def lookup(name: str, env: pca.Policy) -> pca.Form:
        for decl in reversed(env):
            if decl.constant.name == name:
                return decl.formula
        raise VerifyException(f"unknown proof variable {name}")

    def infer(env: pca.Policy, proof: pca.Proof) -> pca.Form:
        match proof:
            case pca.Pvar(name):
                return lookup(name, env)
            case pca.App(m1, m2):
                fun_ty = infer(env, m1)
                match fun_ty:
                    case pca.Implies(premise, conclusion):
                        check(env, m2, premise)
                        return conclusion
                    case _:
                        raise VerifyException("application expects implication proof")
            case pca.Inst(m0, t):
                quantified_ty = infer(env, m0)
                match quantified_ty:
                    case pca.Forall(x, body):
                        return subst_form(x, t, body)
                    case _:
                        raise VerifyException("instantiation expects universal proof")
            case _:
                raise VerifyException("proof does not synthesize a type")

    def check_aff(env: pca.Policy, agent: pca.Term, proof: pca.Proof, goal: pca.Form) -> None:
        match proof:
            case pca.LetWrap(v, a, m0, n):
                if not eq_term(agent, a):
                    raise VerifyException("let-wrap principal does not match goal principal")
                wrapped_ty = infer(env, m0)
                match wrapped_ty:
                    case pca.Says(a2, inner):
                        if not eq_term(a, a2):
                            raise VerifyException("let-wrap principal mismatch with proof type")
                        env_ext = env + [pca.Declaration(pca.Constant(v.name), inner)]
                        check_aff(env_ext, agent, n, goal)
                    case _:
                        raise VerifyException("let-wrap expects a says-typed proof")
            case pca.Let(v, m0, n):
                ty = infer(env, m0)
                env_ext = env + [pca.Declaration(pca.Constant(v.name), ty)]
                check_aff(env_ext, agent, n, goal)
            case _:
                # aff rule: any ordinary proof of goal is also an affirmation.
                check(env, proof, goal)

    def check(env: pca.Policy, proof: pca.Proof, goal: pca.Form) -> None:
        match proof:
            case pca.Wrap(m0, a):
                match goal:
                    case pca.Says(a_goal, inner):
                        if not eq_term(a, a_goal):
                            raise VerifyException("wrap principal does not match says goal")
                        check_aff(env, a, m0, inner)
                    case _:
                        raise VerifyException("wrapped proof can only check against says goals")
            case pca.Let(v, m0, n):
                ty = infer(env, m0)
                env_ext = env + [pca.Declaration(pca.Constant(v.name), ty)]
                check(env_ext, n, goal)
            case _:
                inferred = infer(env, proof)
                if not eq_form(inferred, goal):
                    raise VerifyException("inferred type does not match expected goal")

    check_policy(gamma)
    check(gamma, m, p)
