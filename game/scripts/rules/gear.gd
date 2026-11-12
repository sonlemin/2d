class_name Gear
## Rule-bending gear as data (AR16). Each row is `{id, stat, op, value}`:
## - `op` is `&"set"`, `&"add"` or `&"mul"` on a `Tuning` key, or `&"flag"` to switch on a rule
##   from `Tuning.FLAGS` (`value` unused).
## - `Tuning.apply_gear()` applies the rows of the owned gear set → add → mul, so the result never
##   depends on the order gear was bought in. Nothing ever checks `if has_gear`.
## Gear bends a rule and never adds raw power (GDD Smith).

## Empty until E5/E6, which add Long Wick, Steady Grip, Silk Grip and Quick Wick with their stories.
const TABLE: Array[Dictionary] = []
