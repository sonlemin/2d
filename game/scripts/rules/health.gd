class_name Health
extends RefCounted
## The player's HP, the damage table and invulnerability, pure (FR10, FR12, AR12; Story 1.19).
##
## Per-life (AR12): a new player gets a new Health, so a respawn is full HP (FR13). The damage
## table is rules data, not Tuning: no gear or difficulty bends it (FR25: difficulty "never …
## damage"; Story 1.19 D1). CAUSES is the one registry of cause ids, each mapped to its damage row:
## the death card reads the cause (Story 1.28/1.29) and the death log saves it, so a cause id is
## save data and is never renamed. Health knows nothing of the chain; the player orders the two
## (D2: lethal first, so a lethal hit loses held embers instead of banking them).

## Every HP change: a hit, a heal, a reset. The pips bind here (Story 1.25).
signal changed(hp: int)
## A hit landed: `amount` is the HP actually lost (clamped at 0), so the pips crack exactly that
## many (Story 1.25); `cause` is the cause id the death card reads (Story 1.29).
signal damaged(amount: int, cause: StringName)

const MAX := 4  ## HP at full (GDD Health and damage: "Health: 4 HP"; masks that raise it are out of scope for M2).
## HP lost per hit, one row per GDD damage-table row (GDD Health and damage; GDD Combat enemy table:
## walkers and hoverers deal 1 on contact). E2 decides the spiderling's row.
const DAMAGE := {&"crawler": 1, &"boss": 1, &"lurker": 2, &"hazard": 1}
## Cause id -> its DAMAGE row. Save data from Story 1.29 (the death log): never rename one. The
## death card needs finer causes than the rows (a walker and a hoverer have different tips, 1.28).
## E2 adds the Weaver's causes (-> boss).
const CAUSES := {
	&"crawler_walker": &"crawler",
	&"crawler_hoverer": &"crawler",
	&"lurker": &"lurker",
	&"spikes": &"hazard",
}

var hp: int = MAX
var invuln: float = 0.0  ## s of invulnerability left; public for tests and the blink


## A hit from `cause`. Refused (returns 0, emits nothing) while invulnerable or at 0 HP; else
## loses the cause's row, clamped at 0, starts `invuln_s` of invulnerability, emits `damaged`
## then `changed`, and returns the HP lost.
func hit(cause: StringName, invuln_s: float) -> int:
	assert(CAUSES.has(cause), "Health: unknown cause '%s' (add it to CAUSES)" % cause)
	if invulnerable() or is_empty():
		return 0
	var lost := mini(int(DAMAGE[CAUSES[cause]]), hp)
	hp -= lost
	invuln = invuln_s
	damaged.emit(lost, cause)
	changed.emit(hp)
	return lost


## Counts invulnerability down on game time, so a hitstop pauses it (as M1's did).
func tick(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)


## Up to MAX; `changed` only when HP moved. Never lowers HP: `n` <= 0 does nothing, since damage goes
## through hit(), which emits `damaged` and lets the player die (a heal(-n) left a live player at
## 0 HP that hit() refused forever; review of Story 1.19).
func heal(n: int) -> void:
	if n <= 0:
		return
	var next := mini(hp + n, MAX)
	if next != hp:
		hp = next
		changed.emit(hp)


## FR12: +1 HP for a safely banked chain of `min_links` or more (GDD Health and damage: "+1 HP when
## you bank a chain of 10 or more"; the threshold is Tuning bank_heal_min, passed in). Returns
## whether it healed: false below the threshold or at MAX.
func bank_heal(links: int, min_links: int) -> bool:
	if links < min_links or hp >= MAX:
		return false
	heal(1)
	return true


## Back to `to` HP (clamped to 1..MAX) with no invulnerability; DevTools' --hp uses it.
func reset(to := MAX) -> void:
	hp = clampi(to, 1, MAX)
	invuln = 0.0
	changed.emit(hp)


func invulnerable() -> bool:
	return invuln > 0.0


func is_empty() -> bool:
	return hp <= 0
