# Недостающая графика «Послевкусия»

Единый список. Собирается скриптом `tools/needed_art.py` прямо по сценам, карточкам и папкам с артом, поэтому всегда отражает текущее состояние. Перезапуск: `python tools/needed_art.py` из корня репозитория.

Пути: портрет — `assets/art/characters/<id>.png` или `<id>/neutral.png`; эмоция — `<id>/<эмоция>.png`; сценический образ — `<id>/looks/<образ>/<эмоция>.png`; фон — `assets/art/backgrounds/<id>.png`.

**Итого:** 0 персонажей без портрета · 108 эмоций · 28 кадров для сценических образов · 0 фонов отсутствуют совсем · 0 фонов подменены другими.

## 1. Персонажи без портрета

Без базового рисунка персонаж в сцене и на столе показывается заглушкой. Это первое, что стоит нарисовать.


## 2. Эмоции для персонажей с портретом

Пока эмоции нет, игра показывает обычный портрет.

- **arue** — Аруэ: `surprised` («удивление»; clorinde_case)
- **char_adele** — Адель: `confused` («растерянность»; adele_letter), `determined` («решимость»; adele_letter), `excited` («восторг»; adele_arrival), `flirty` («флирт»; adele_window), `proud` («гордость»; adele_rings), `sly` («лукаво»; adele_gambit, adele_rings, adele_window), `tearful` («слёзы»; adele_letter)
- **char_chevreuse** — Шеврёз: `embarrassed` («смущение»; chevreuse_home), `sly` («лукаво»; chevreuse_office), `surprised` («удивление»; chevreuse_home), `tired` («усталость»; chevreuse_home)
- **char_childe** — Чайльд: `angry` («злость»; sillage_verdict)
- **char_clorinde** — Клоринда: `sad` («грусть»; clorinde_case), `tired` («усталость»; clorinde_case)
- **char_eirin** — Эйрин Валентайн: `annoyed` («раздражение»; eirin_print, eirin_upstairs), `sad` («грусть»; eirin_market), `sly` («лукаво»; eirin_bureau)
- **char_emilie** — Эмилия: `sly` («лукаво»; emilie_perfume)
- **char_furina** — Фурина: `sly` («лукаво»; city_furina_glasses, furina_sketch_delivery, tiori_fitting)
- **char_jakob** — Жакоб Ингольд: `embarrassed` («смущение»; jakob_bones, jakob_hire, jakob_return и ещё 1), `sad` («грусть»; jakob_bones, jakob_return, jakob_road), `serious` («серьёзно»; jakob_bones, jakob_hire, jakob_road), `smile` («улыбка»; jakob_bones, jakob_hire, jakob_return), `surprised` («удивление»; jakob_bones, jakob_return), `thoughtful` («задумчиво»; jakob_bones, jakob_hire, jakob_return и ещё 1)
- **char_josie** — Жози: `tearful` («слёзы»; josie_left_first), `tired` («усталость»; josie_left_first)
- **char_lyney** — Лини: `sly` («лукаво»; opera_night)
- **char_marcel** — Дядя Марсель: `angry` («злость»; sillage_verdict), `sly` («лукаво»; sillage_marcel_sunday), `tearful` («слёзы»; sillage_verdict)
- **char_navia** — Навия: `angry` («злость»; navia_wake_list, sillage_wine_route), `flirty` («флирт»; faubourg_navia, sillage_supper), `sly` («лукаво»; faubourg_navia, sillage_melus, sillage_supper), `tearful` («слёзы»; navia_wake_list), `tender` («нежность»; faubourg_navia), `thoughtful` («задумчиво»; sillage_verdict), `worried` («тревога»; sillage_wine_route)
- **char_sigewinne** — Сиджвин: `sly` («лукаво»; maison_infirmerie), `smile` («улыбка»; maison_infirmerie), `thoughtful` («задумчиво»; maison_infirmerie)
- **char_silver** — Сильвер: `proud` («гордость»; sillage_supper)
- **char_tiori** — Тиори: `angry` («злость»; tiori_failure, tiori_fitting), `sad` («грусть»; tiori_failure), `sly` («лукаво»; tiori_draw), `tired` («усталость»; tiori_failure)
- **eloise** — Баронесса Элоиза: `indignant` («возмущение»; sillage_assaut, sillage_plastron), `sly` («лукаво»; sillage_assaut), `smug` («ехидно»; sillage_plastron), `thoughtful` («задумчиво»; sillage_plastron)
- **gaston** — Гастон: `determined` («решимость»; debor_bar)
- **npc_adele_landlady** — Хозяйка парусной мастерской: `smug` («ехидно»; adele_window)
- **npc_aglaya** — Аглая: `happy` («веселье»; etoile_quay), `laugh` («смех»; etoile_quay), `serious` («сосредоточенность»; etoile_quay, etoile_thaw), `sly` («лукаво»; etoile_quay), `smile` («улыбка»; etoile_quay), `surprised` («изумление»; etoile_thaw), `thoughtful` («задумчиво»; etoile_quay)
- **npc_albine** — Альбина: `smug` («ехидно»; adele_salon), `tender` («нежность»; adele_salon)
- **npc_annette** — Аннета: `laugh` («смех»; entracte_josie), `smile` («улыбка»; entracte_josie), `tender` («нежность»; entracte_josie)
- **npc_berthe** — Берта: `happy` («веселье»; sillage_wine_route), `hurt` («обида»; sillage_wine_route), `laugh` («смех»; sillage_wine_route), `serious` («сосредоточенность»; sillage_wine_route), `thoughtful` («задумчиво»; sillage_wine_route), `tired` («усталость»; sillage_wine_route)
- **npc_bertin** — Фанни Бертен: `laugh` («смех»; eirin_bureau, eirin_print)
- **npc_blanche** — Бланш: `relieved` («облегчение»; faubourg_entrepot), `sad` («горечь»; faubourg_comptoir), `serious` («сдержанно»; faubourg_comptoir, faubourg_entrepot), `smile` («улыбка»; faubourg_entrepot), `worried` («настороженность»; faubourg_comptoir)
- **npc_farida** — Фарида: `smile` («улыбка»; jakob_bones, jakob_return), `smug` («ехидно»; jakob_road), `surprised` («удивление»; jakob_bones, jakob_road), `worried` («тревога»; jakob_bones)
- **npc_foreman** — Мастер цеха: `sad` («грусть»; josie_office), `worried` («тревога»; josie_office)
- **npc_gossip_lady** — Покупательница в Пассаже: `sly` («лукаво»; eirin_market)
- **npc_henri** — Анри: `sly` («лукаво»; sillage_wine_yard)
- **npc_isaure** — Изора Беллан: `happy` («веселье»; sillage_assaut), `laugh` («смех»; sillage_assaut), `serious` («серьёзно»; sillage_assaut), `sly` («лукаво»; sillage_assaut), `smile` («улыбка»; sillage_assaut), `smug` («ехидно»; sillage_assaut)
- **npc_jeanne** — Жанна: `surprised` («удивление»; eirin_print)
- **npc_jules_son** — Жюль-младший: `excited` («восторг»; jules_scalper)
- **npc_laurent** — Господин Лоран: `worried` («тревога»; eirin_cane)
- **npc_marta** — Марта: `annoyed` («раздражение»; sillage_ribbon_guess), `laugh` («смех»; sillage_ribbon_return), `serious` («серьёзно»; sillage_ribbon_return), `sly` («лукаво»; sillage_ribbon_guess, sillage_ribbon_return), `smile` («улыбка»; sillage_ribbon_return), `thoughtful` («задумчиво»; sillage_ribbon_return)
- **npc_odile** — Одиль: `angry` («злость»; sillage_lock), `laugh` («смех»; sillage_lock), `worried` («настороженность»; sillage_lock)
- **npc_pelagie** — Пелажи: `proud` («гордость»; jakob_bones), `smile` («улыбка»; jakob_bones), `surprised` («удивление»; jakob_bones)
- **npc_quiet_weaver** — Ткачиха: `worried` («тревога»; faubourg_entrepot)
- **npc_seamstress** — Белошвейка: `sly` («лукаво»; etoile_quay)

## 3. Сценические образы

Внутри образа (`@look`) игра ищет эмоцию в папке образа, а если её нет — нейтральный кадр этого же образа. Если нет и его, показывается обычный портрет.

- **char_charlotte** / `by_fire`: `sad` (fireplace)
- **char_charlotte** / `nightshirt`: `smile` (charlotte_night), `tender` (charlotte_night)
- **char_charlotte** / `reporting`: `laugh` (charlotte_first_archive), `sly` (etoile_thaw)
- **char_chevreuse** / `mirror`: `smug` (chevreuse_office)
- **char_childe** / `no_vision`: `confused` (childe_after), `excited` (entracte_childe_after), `smile` (entracte_childe_after), `smug` (entracte_childe)
- **char_clorinde** / `fencing`: `determined` (city_clorinde_lesson), `smile` (city_clorinde_lesson), `smug` (city_clorinde_lesson)
- **char_clorinde** / `fencing_button`: `serious` (city_clorinde_lesson), `smug` (city_clorinde_lesson)
- **char_clorinde** / `training_mask`: `smile` (clorinde_practice)
- **char_clorinde** / `training_rest`: `serious` (clorinde_practice), `sly` (clorinde_practice), `smile` (clorinde_practice), `smug` (clorinde_practice), `thoughtful` (clorinde_practice)
- **char_furina** / `spectacles`: `excited` (trial_opening)
- **char_josie** / `bath`: `sad` (josie_bath), `smug` (josie_bath)
- **char_navia** / `hatless`: `annoyed` (navia_lunch), `smile` (navia_lunch)
- **char_paimon** / `detective`: `excited` (trial_water)
- **npc_aurelie** / `fountain_walk`: `smug` (fountain_tiori_quarrel)

## 4. Фоны, которых нет совсем

Здесь сцена показывает пустой фон.

Таких нет.

## 5. Фоны, которые сейчас подменены

Для них в `ui/art.gd` указан похожий существующий фон. Свой PNG с этим именем отключит подмену сам.

