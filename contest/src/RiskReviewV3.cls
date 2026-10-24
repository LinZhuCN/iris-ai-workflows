Class Contest.RiskReviewV3 Extends Contest.RiskReviewV2
{
ClassMethod Version() As %String
{
    Quit "staged-risk-v3"
}

ClassMethod Prompt(phase As %String) As %String
{
    If phase'="judge" Quit ##class(Contest.RiskReviewV2).Prompt(phase)
    Quit ##class(Contest.RiskReviewV2).Prompt("judge")_" Scope discipline: missing_information is an operational list of unresolved, fact-grounded questions MATERIAL to the supplied checked issues, not a list of every possible additional review. Before including an item, identify the supplied issue and explain internally how the missing fact prevents resolving a condition, relevant competing basis, or uncertainty actually raised by the supplied facts/evidence. Risk and a material unresolved question may coexist; do not hide a real permission gap merely because an incident/control failure is already established. Conversely, a resolved scoped risk/no-signal does not need generic requests for unrelated permissions, other laws/contracts, unspecified additional fields or certification of every cross-reference/current-law issue solely because legal coverage is partial. Those generic limitations remain coverage limitations, not newly invented facts or issue-specific unknowns. Keep necessary source/definition/exception gaps unresolved when they genuinely prevent deciding the supplied issue; unsupported incidents and unavailable evidence remain unresolved. Use [] when no material information is missing on the checked issues, even though overall compliance is not established. Explain the limited scope without requesting a speculative alternate workflow. For a disputed claim, distinguish why its rationale is unsupported from whether independent verified facts establish the selected path; neither silently endorse it nor let it negate an independently supported basis. Request a legal prerequisite only when the supplied evidence and actual path support its applicability; consider stated exceptions before demanding it. Do not suppress true unknowns or optimize for a desired aggregate. Keep the exact existing output schema; no new limitation/status/action fields."
}

ClassMethod ContractHash() As %String
{
    Quit ##class(Demo.Protocol).Hash(..Version()_"|judge-material-gaps-v1|base-contract:"_##class(Contest.RiskReviewV2).ContractHash()_"|"_..Prompt("judge"))
}
}
