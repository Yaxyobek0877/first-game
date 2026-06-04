extends Node
## Global "signal bus" (signallar avtobusi) — autoload singleton.
##
## Maqsad: turli sahnalar (player, dushman, HUD) bir-birini to'g'ridan-to'g'ri
## bilmasdan "gaplashishi" uchun. Masalan, qurol "ammo_changed" signalini
## yuboradi, HUD esa uni eshitadi — ikkalasi bir-biriga bog'lanmagan.
## Bu professional "decoupling" (ajratish) usuli.
##
## project.godot ichida Autoload sifatida ro'yxatdan o'tgan: nomi "Events".
## Shuning uchun istalgan skriptdan `Events.ammo_changed.emit(...)` deb chaqirsa bo'ladi.

## Qurol otganda yoki qayta o'qlanganda o'q-dori soni o'zgaradi.
signal ammo_changed(current: int, max_ammo: int)

## O'yinchi joni o'zgarganda (zarar olganda / davolanganda).
signal player_health_changed(current: float, max_health: float)

## Dushman/nishon yo'q qilinganda. Ochko sanash uchun ishlatiladi.
signal enemy_died(enemy: Node)
