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

## O'yinchi halok bo'lganda yuboriladi. "O'yin tugadi" (GameOver) ekrani eshitadi.
signal player_died()

## Qurol almashtirilganda yuboriladi (1/2 tugmalari). HUD WeaponLabel'ni yangilaydi.
signal weapon_changed(weapon_name: String)

## Yangi to'lqin (wave) boshlanganda yuboriladi. HUD to'lqin raqamini ko'rsatadi.
signal wave_started(wave: int)

## O'q nishonga (take_damage'li narsaga) tekkanda. HUD crosshair hit-marker ko'rsatadi.
signal target_hit()

## Snayperni aim qilganda (durbin). Scope overlay ko'rsatiladi, HUD crosshair yashiriladi.
signal scoped(active: bool)

## O'yinchi o'q uzganda (otish ovozi). Yaqindagi dushmanlar "eshitib" tovush kelgan
## joyni tekshirishga boradi (idrok — eshitish). Dunyo koordinatasi yuboriladi.
signal player_fired(world_pos: Vector3)
