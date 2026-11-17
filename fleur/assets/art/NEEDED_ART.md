# Недостающая графика «Послевкусия»

Единый список. Собирается скриптом `tools/needed_art.py` прямо по сценам, карточкам и папкам с артом, поэтому всегда отражает текущее состояние. Перезапуск: `python tools/needed_art.py` из корня репозитория.

Пути: портрет — `assets/art/characters/<id>.png` или `<id>/neutral.png`; эмоция — `<id>/<эмоция>.png`; сценический образ — `<id>/looks/<образ>/<эмоция>.png`; фон — `assets/art/backgrounds/<id>.png`.

**Итого:** 17 персонажей без портрета · 108 эмоций · 28 кадров для сценических образов · 2 фонов отсутствуют совсем · 7 фонов подменены другими.

## 1. Персонажи без портрета

Без базового рисунка персонаж в сцене и на столе показывается заглушкой. Это первое, что стоит нарисовать.

- **char_jakob** — Жакоб Ингольд. Выцветшие светлые волосы, гладкое лицо без возраста (на вид лет 35), тёмный дорожный плащ, карманные часы на цепочке. Спокойный, вежливый, взгляд старше лица.
  - Сцены: jakob_bones, jakob_hire, jakob_return, jakob_road.
  - Эмоции после портрета: embarrassed («смущение»), sad («грусть»), serious («серьёзно»), smile («улыбка»), surprised («удивление»), thoughtful («задумчиво»).
- **npc_adele_landlady** — Хозяйка парусной мастерской. Сдаёт Адель чердак над водой. Ходит по лестнице с ведром и обваливает осетрину в сухарях.
  - Сцены: adele_window.
  - Эмоции после портрета: smug («ехидно»).
- **npc_aglaya** — Аглая. Землемер из Снежной. Аглая работает у нижних причалов и умеет отличить Звёздный клин от тёплой стекляшки. О местном роднике она расспрашивает тех, кому каждый день носить оттуда воду.
  - Сцены: etoile_quay, etoile_thaw.
  - Эмоции после портрета: happy («веселье»), laugh («смех»), serious («сосредоточенность»), sly («лукаво»), smile («улыбка»), surprised («изумление»), thoughtful («задумчиво»).
- **npc_albine** — Альбина. Маленькая седая кассирша карусели, по костяшки пальцев в жёлтой краске.
  - Сцены: adele_salon.
  - Эмоции после портрета: smug («ехидно»), tender («нежность»).
- **npc_annette** — Аннета. Привратница дома, двадцать пять лет службы. В молодости играла в «Женихе для вдовы» и помнит все четыре роли.
  - Сцены: entracte_josie.
  - Эмоции после портрета: laugh («смех»), smile («улыбка»), tender («нежность»).
- **npc_berthe** — Берта. Корзинщица из Берилла. Её артель плетёт чехлы для стекла. Шевалье помнит Берту с тех пор, когда ему позволяли катать пустые бутыли по двору.
  - Сцены: sillage_wine_route.
  - Эмоции после портрета: happy («веселье»), hurt («обида»), laugh («смех»), serious («сосредоточенность»), thoughtful («задумчиво»), tired («усталость»).
- **npc_bertin** — Фанни Бертен. Бывшая «морская невеста» ярмарочного аттракциона. Носит каблуки и не стесняется шлейфа.
  - Сцены: eirin_bureau, eirin_print.
  - Эмоции после портрета: laugh («смех»).
- **npc_blanche** — Бланш. Торговка из шестого ряда. Бланш покупает скатерти из Берилла. Её сестра ткёт, муж работает в городской конторе, а с покупателями каждый день видится она сама.
  - Сцены: faubourg_comptoir, faubourg_entrepot.
  - Эмоции после портрета: relieved («облегчение»), sad («горечь»), serious («сдержанно»), smile («улыбка»), worried («настороженность»).
- **npc_blanche_husband** — Муж Бланш. Клерк, муж Бланш.
  - Сцены: faubourg_entrepot.
- **npc_farida** — Фарида. Наёмница-пустынница из Сумеру: выгоревшая накидка, тёмные волосы узлом, нож на поясе, обветренное лицо.
  - Сцены: jakob_bones, jakob_return, jakob_road.
  - Эмоции после портрета: smile («улыбка»), smug («ехидно»), surprised («удивление»), worried («тревога»).
- **npc_gossip_lady** — Покупательница в Пассаже. Внушительная дама в сукне, которая всё знает о чужих утрах у часовщика.
  - Сцены: eirin_market.
  - Эмоции после портрета: sly («лукаво»).
- **npc_isaure** — Изора Беллан. Хозяйка гравёрной мастерской. Давняя приятельница Элоизы. Когда-то они вместе занимались фехтованием.
  - Сцены: sillage_assaut.
  - Эмоции после портрета: happy («веселье»), laugh («смех»), serious («серьёзно»), sly («лукаво»), smile («улыбка»), smug («ехидно»).
- **npc_jeanne** — Жанна. Вторая «морская невеста», выше подруги на полголовы. Приехала сняться во весь рост в рабочих башмаках.
  - Сцены: eirin_print.
  - Эмоции после портрета: surprised («удивление»).
- **npc_laurent** — Господин Лоран. Пассажир, которому по ошибке всучили чужую трость.
  - Сцены: eirin_cane.
  - Эмоции после портрета: worried («тревога»).
- **npc_odette** — Одетта. Гостья салона. В молодости ей подстелили под ведро синюю шалевую ткань с розой де ла Флёров, и из остатков вышли две дочкины юбки и несносимое пальто.
  - Сцены: adele_salon.
- **npc_pelagie** — Пелажи. Мелюзина из Меруси: зелёная курточка, жетон на шнурке на шее, фонарь в руке.
  - Сцены: jakob_bones.
  - Эмоции после портрета: proud («гордость»), smile («улыбка»), surprised («удивление»).
- **npc_quiet_weaver** — Ткачиха. Одна из ткачих Элоизы на старом винном складе. Просит, чтобы её имя нигде не писали: у дочери скоро смотрины.
  - Сцены: faubourg_entrepot.
  - Эмоции после портрета: worried («тревога»).

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
- **char_josie** — Жози: `tearful` («слёзы»; josie_left_first), `tired` («усталость»; josie_left_first)
- **char_lyney** — Лини: `sly` («лукаво»; opera_night)
- **char_marcel** — Дядя Марсель: `angry` («злость»; sillage_verdict), `sly` («лукаво»; sillage_marcel_sunday), `tearful` («слёзы»; sillage_verdict)
- **char_navia** — Навия: `angry` («злость»; navia_wake_list, sillage_wine_route), `flirty` («флирт»; faubourg_navia, sillage_supper), `sly` («лукаво»; faubourg_navia, sillage_melus, sillage_supper), `tearful` («слёзы»; navia_wake_list), `tender` («нежность»; faubourg_navia), `thoughtful` («задумчиво»; sillage_verdict), `worried` («тревога»; sillage_wine_route)
- **char_sigewinne** — Сиджвин: `sly` («лукаво»; maison_infirmerie), `smile` («улыбка»; maison_infirmerie), `thoughtful` («задумчиво»; maison_infirmerie)
- **char_silver** — Сильвер: `proud` («гордость»; sillage_supper)
- **char_tiori** — Тиори: `angry` («злость»; tiori_failure, tiori_fitting), `sad` («грусть»; tiori_failure), `sly` («лукаво»; tiori_draw), `tired` («усталость»; tiori_failure)
- **eloise** — Баронесса Элоиза: `indignant` («возмущение»; sillage_assaut, sillage_plastron), `sly` («лукаво»; sillage_assaut), `smug` («ехидно»; sillage_plastron), `thoughtful` («задумчиво»; sillage_plastron)
- **gaston** — Гастон: `determined` («решимость»; debor_bar)
- **npc_foreman** — Мастер цеха: `sad` («грусть»; josie_office), `worried` («тревога»; josie_office)
- **npc_henri** — Анри: `sly` («лукаво»; sillage_wine_yard)
- **npc_jules_son** — Жюль-младший: `excited` («восторг»; jules_scalper)
- **npc_marta** — Марта: `annoyed` («раздражение»; sillage_ribbon_guess), `laugh` («смех»; sillage_ribbon_return), `serious` («серьёзно»; sillage_ribbon_return), `sly` («лукаво»; sillage_ribbon_guess, sillage_ribbon_return), `smile` («улыбка»; sillage_ribbon_return), `thoughtful` («задумчиво»; sillage_ribbon_return)
- **npc_odile** — Одиль: `angry` («злость»; sillage_lock), `laugh` («смех»; sillage_lock), `worried` («настороженность»; sillage_lock)
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

- **meropide_infirmary** — maison_infirmerie, карточка loc_meropide. Лазарет крепости Меропид: тесная тёплая комната под водой, иллюминатор с мутной водой и проплывающей рыбёшкой, койки, корзинка медсестры с нитками, стул со спинкой для пальто посетителя.
- **meropide_office** — maison_duc. Кабинет герцога Ризли в Меропиде: тяжёлый стол, чайник на грелке, широкий таз за креслом, стулья для посетителей, металл и заклёпки крепости.

## 5. Фоны, которые сейчас подменены

Для них в `ui/art.gd` указан похожий существующий фон. Свой PNG с этим именем отключит подмену сам.

- **berill_ridge** → сейчас `vineyard` — jakob_bones, jakob_road. Восточный склон Берилла за последней межой. Белый известняк, длинные правильные дуги холмов, похожие на рёбра огромного существа, наполовину ушедшего в землю. Внизу маленькие ряды лоз и крыши поместья. День, ветер, сухая трава.
- **chevreuse_home** → сейчас `apartment` — chevreuse_home. Две комнаты Шеврёз над скобяной лавкой. Мундиры на спинках стульев, одна кружка, тарелка с крошками, стопка рапортов под утюгом. Второго стула нет — табурет, на нём сапоги. Кровать, на которой она сидит в мундире. Вечер, одна лампа.
- **debor_bar** → сейчас `bar` — aurelie_supper, cards_evening, debor_bar, faubourg_comptoir.
- **debor_hall** → сейчас `manor` — adele_salon, entracte_lynette, escoffier_tasting, jakob_hire и ещё 4.
- **elynas_cave** → сейчас `submerged_store` — jakob_bones. Вход в кости Элинаса. Расщелина переходит в гладкие слоистые стены, похожие на срез старого пня; над головой изгиб, как внутренняя сторона ребра. Фонарь мелюзины, тёплые охристые тона.
- **elynas_heart** → сейчас `submerged_store` — jakob_bones. «Первый красный зал». Стены с красноватым отливом, мягкие на вид. На одной стене светящаяся сама собой картина: море и солнце странного тёплого цвета, крупные мазки. В дальней стене застряли обломки старых механизмов. Над входом на ребре выцарапан нарцисс, переплетённый с крестом.
- **expedition_camp** → сейчас `vineyard` — jakob_road. Ночёвка под загнутым каменным ребром: костёр, тюки, котелок, две палатки, крупные низкие звёзды. Тёплый свет огня снизу, холодный сверху. Вызывается с профилем night.
