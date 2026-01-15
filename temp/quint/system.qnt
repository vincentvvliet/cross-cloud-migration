module System {
    import Base.* from "./base"
    import GeneratedInvariants.* from "./generated_invariants"

    val SystemCorrect =
        base_invariants and generated_invariants
}