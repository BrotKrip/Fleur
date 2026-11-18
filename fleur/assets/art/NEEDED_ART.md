# Недостающая графика «Послевкусия»

Единый список. Собирается скриптом `tools/needed_art.py` прямо по сценам, карточкам и папкам с артом, поэтому всегда отражает текущее состояние. Перезапуск: `python tools/needed_art.py` из корня репозитория.

Пути: портрет — `assets/art/characters/<id>.png` или `<id>/neutral.png`; эмоция — `<id>/<эмоция>.png`; сценический образ — `<id>/looks/<образ>/<эмоция>.png`; фон — `assets/art/backgrounds/<id>.png`.

**Итого:** 7 персонажей без портрета · 120 эмоций · 24 кадров для сценических образов · 0 фонов отсутствуют совсем · 0 фонов подменены другими.

## 1. Персонажи без портрета

Без базового рисунка персонаж в сцене и на столе показывается заглушкой. Это первое, что стоит нарисовать.

- **npc_cooper_widow** — Вдова бондаря. Берёт жалованье до последней моры и зовёт на голубей.
  - Сцены: maison_paie.
  - Эмоции после портрета: smile («улыбка»).
- **npc_delphin** — Дельфен. Муж привратницы Аннеты. Видит сцену левым глазом и до сих пор помнит, как сделал предложение без табурета.
  - Сцены: entracte_josie.
  - Эмоции после портрета: smile («улыбка»).
- **npc_ferret_merchant** — Купец с хорьком. Партнёр Флёра по картам. Уверен, что его ручной хорёк необычайно умён.
  - Сцены: cards_evening.
  - Эмоции после портрета: proud («гордость»).
- **npc_poisson_granny** — Старуха из Пуассона. Хочет лично убедиться, что скат настоящий, а ткань на манжете хорошая.
  - Сцены: poisson_skate.
  - Эмоции после портрета: thoughtful («задумчиво»).
- **npc_salon_customer** — Посетительница парикмахерской. Высовывается из двери, чтобы задать самый неудобный вопрос.
  - Сцены: sillage_ribbon_guess.
  - Эмоции после портрета: smug («ехидно»).
- **npc_shooting_master** — Хозяин тира. Держит тир на ярмарке. Гордится совами-призами и женой, которая их шьёт.
  - Сцены: fair_josie.
  - Эмоции после портрета: proud («гордость»).
- **npc_tenant_boy** — Мальчишка с нижнего этажа. Сын жильцов. Пишет объявления для пьесы и верит, что лавку можно описать по-настоящему.
  - Сцены: entracte_josie.
  - Эмоции после портрета: excited («восторг»).

## 2. Эмоции для персонажей с портретом

Пока эмоции нет, игра показывает обычный портрет.

- **arue** — Аруэ: `surprised` («удивление»; clorinde_case)
- **char_adele** — Адель: `confused` («растерянность»; adele_letter), `determined` («решимость»; adele_letter), `excited` («восторг»; adele_arrival), `proud` («гордость»; adele_rings), `tearful` («слёзы»; adele_letter)
- **char_chevreuse** — Шеврёз: `embarrassed` («смущение»; chevreuse_home), `sly` («лукаво»; chevreuse_office), `surprised` («удивление»; chevreuse_home), `tired` («усталость»; chevreuse_home)
- **char_childe** — Чайльд: `angry` («злость»; sillage_verdict)
- **char_clorinde** — Клоринда: `tired` («усталость»; clorinde_case)
- **char_eirin** — Эйрин Валентайн: `annoyed` («раздражение»; eirin_print, eirin_upstairs), `sad` («грусть»; eirin_market)
- **char_emilie** — Эмилия: `sly` («лукаво»; emilie_perfume)
- **char_furina** — Фурина: `sly` («лукаво»; city_furina_glasses, furina_sketch_delivery, tiori_fitting)
- **char_jakob** — Жакоб Ингольд: `embarrassed` («смущение»; jakob_bones, jakob_hire, jakob_return и ещё 1), `sad` («грусть»; jakob_bones, jakob_return, jakob_road), `serious` («серьёзно»; jakob_bones, jakob_hire, jakob_road), `smile` («улыбка»; jakob_bones, jakob_hire, jakob_return), `surprised` («удивление»; jakob_bones, jakob_return), `thoughtful` («задумчиво»; jakob_bones, jakob_hire, jakob_return и ещё 1)
- **char_josie** — Жози: `tearful` («слёзы»; josie_left_first), `tired` («усталость»; josie_left_first)
- **char_lyney** — Лини: `sly` («лукаво»; opera_night, twins_vasari)
- **char_marcel** — Дядя Марсель: `angry` («злость»; sillage_verdict), `sly` («лукаво»; sillage_marcel_sunday), `tearful` («слёзы»; sillage_verdict)
- **char_navia** — Навия: `angry` («злость»; navia_wake_list, sillage_wine_route), `flirty` («флирт»; faubourg_navia, sillage_supper), `sly` («лукаво»; faubourg_navia, sillage_supper), `tearful` («слёзы»; navia_wake_list), `tender` («нежность»; faubourg_navia), `thoughtful` («задумчиво»; faubourg_navia, sillage_verdict), `worried` («тревога»; sillage_wine_route)
- **char_paimon** — Паймон: `annoyed` («раздражение»; sillage_melus)
- **char_sigewinne** — Сиджвин: `sly` («лукаво»; maison_infirmerie), `smile` («улыбка»; maison_infirmerie), `thoughtful` («задумчиво»; maison_infirmerie)
- **char_silver** — Сильвер: `proud` («гордость»; sillage_supper)
- **char_tiori** — Тиори: `angry` («злость»; tiori_failure, tiori_fitting), `sad` («грусть»; tiori_failure), `tired` («усталость»; tiori_failure)
- **courier** — Посыльный: `embarrassed` («смущение»; courier_error)
- **eloise** — Баронесса Элоиза: `indignant` («возмущение»; sillage_assaut, sillage_plastron), `sly` («лукаво»; sillage_assaut), `smug` («ехидно»; sillage_plastron), `thoughtful` («задумчиво»; sillage_plastron)
- **gaston** — Гастон: `determined` («решимость»; debor_bar), `embarrassed` («смущение»; charlotte_article), `worried` («тревога»; jakob_hire)
- **npc_adele_landlady** — Хозяйка парусной мастерской: `annoyed` («раздражение»; adele_window)
- **npc_aglaya** — Аглая: `happy` («веселье»; etoile_quay), `laugh` («смех»; etoile_quay), `serious` («сосредоточенность»; etoile_quay, etoile_thaw), `smile` («улыбка»; etoile_quay), `surprised` («удивление»; etoile_quay, etoile_thaw), `thoughtful` («задумчиво»; etoile_quay)
- **npc_albine** — Альбина: `smug` («ехидно»; adele_rings, adele_salon), `tender` («нежность»; adele_salon)
- **npc_annette** — Аннета: `laugh` («смех»; entracte_josie), `smile` («улыбка»; entracte_josie), `tender` («нежность»; entracte_josie)
- **npc_berthe** — Берта: `happy` («веселье»; sillage_wine_route), `hurt` («обида»; sillage_wine_route), `laugh` («смех»; sillage_wine_route), `serious` («сосредоточенность»; sillage_wine_route), `thoughtful` («задумчиво»; sillage_wine_route), `tired` («усталость»; sillage_wine_route)
- **npc_bertin** — Фанни Бертен: `laugh` («смех»; eirin_bureau, eirin_print), `serious` («деловито»; eirin_bureau)
- **npc_blanche** — Бланш: `relieved` («облегчение»; faubourg_entrepot), `sad` («горечь»; faubourg_comptoir), `serious` («сдержанно»; faubourg_comptoir, faubourg_entrepot), `smile` («улыбка»; faubourg_entrepot), `worried` («настороженность»; faubourg_comptoir)
- **npc_clery** — Мадемуазель Клери: `smile` («улыбка»; sillage_billiards)
- **npc_estelle** — Эстель: `smug` («ехидно»; childe_after)
- **npc_farida** — Фарида: `annoyed` («раздражение»; jakob_road), `surprised` («удивление»; jakob_bones, jakob_road), `worried` («тревога»; jakob_bones)
- **npc_foreman** — Мастер цеха: `sad` («грусть»; josie_office), `worried` («тревога»; josie_office)
- **npc_fry_seller** — Продавщица картошки: `smug` («ехидно»; chevreuse_evening)
- **npc_gossip_lady** — Покупательница в Пассаже: `sly` («лукаво»; eirin_market)
- **npc_henri** — Анри: `embarrassed` («смущение»; manor_vineyard), `laugh` («смех»; sillage_wine_yard)
- **npc_isaure** — Изора Беллан: `happy` («веселье»; sillage_assaut), `laugh` («смех»; sillage_assaut), `serious` («серьёзно»; sillage_assaut), `smile` («улыбка»; sillage_assaut)
- **npc_jeanne** — Жанна: `surprised` («удивление»; eirin_print)
- **npc_jules_son** — Жюль-младший: `excited` («восторг»; jules_scalper)
- **npc_laurent** — Господин Лоран: `worried` («тревога»; eirin_cane)
- **npc_marta** — Марта: `annoyed` («раздражение»; sillage_ribbon_guess), `laugh` («смех»; sillage_ribbon_return), `serious` («деловито»; sillage_ribbon_return), `sly` («лукаво»; sillage_ribbon_guess, sillage_ribbon_return), `smile` («улыбка»; sillage_ribbon_return), `thoughtful` («задумчиво»; sillage_ribbon_return)
- **npc_odette** — Одетта: `annoyed` («раздражение»; adele_salon)
- **npc_odile** — Одиль: `angry` («злость»; sillage_lock), `laugh` («смех»; sillage_lock, textile_opening), `serious` («деловито»; textile_opening), `worried` («настороженность»; sillage_lock)
- **npc_pelagie** — Пелажи: `proud` («гордость»; jakob_bones), `smile` («улыбка»; jakob_bones), `surprised` («удивление»; jakob_bones)
- **npc_quiet_weaver** — Ткачиха: `worried` («тревога»; faubourg_entrepot)
- **npc_ribbon_seller** — Продавщица лент: `indignant` («возмущение»; sillage_ribbon_guess)
- **npc_seamstress** — Белошвейка: `sly` («лукаво»; etoile_quay)
- **npc_tristana** — Тристана: `excited` («восторг»; lynette_dressing)
- **viscount** — Виконт де Ламотт: `worried` («тревога»; lamotte_after)

## 3. Сценические образы

Внутри образа (`@look`) игра ищет эмоцию в папке образа, а если её нет — нейтральный кадр этого же образа. Если нет и его, показывается обычный портрет.

- **char_charlotte** / `by_fire`: `sad` (fireplace)
- **char_charlotte** / `nightshirt`: `smile` (charlotte_night), `tender` (charlotte_night)
- **char_charlotte** / `reporting`: `laugh` (charlotte_first_archive)
- **char_childe** / `no_vision`: `confused` (childe_after), `excited` (entracte_childe_after), `smile` (entracte_childe, entracte_childe_after), `smug` (entracte_childe)
- **char_clorinde** / `fencing`: `determined` (city_clorinde_lesson), `serious` (city_clorinde_lesson), `smile` (city_clorinde_lesson)
- **char_clorinde** / `fencing_button`: `serious` (city_clorinde_lesson)
- **char_clorinde** / `training_mask`: `smile` (clorinde_practice)
- **char_clorinde** / `training_rest`: `serious` (clorinde_practice), `thoughtful` (clorinde_practice)
- **char_furina** / `spectacles`: `excited` (trial_opening)
- **char_josie** / `bath`: `sad` (josie_bath), `smug` (josie_bath)
- **char_lumine** / `trial_notes`: `thoughtful` (lumine_trial_eve)
- **char_lyney** / `bareheaded`: `tired` (lynette_dressing)
- **char_navia** / `hatless`: `annoyed` (navia_lunch), `smile` (navia_lunch)
- **char_paimon** / `detective`: `excited` (trial_water)
- **npc_aurelie** / `supper`: `tender` (aurelie_supper)

## 4. Фоны, которых нет совсем

Здесь сцена показывает пустой фон.

Таких нет.

## 5. Фоны, которые сейчас подменены

Для них в `ui/art.gd` указан похожий существующий фон. Свой PNG с этим именем отключит подмену сам.

