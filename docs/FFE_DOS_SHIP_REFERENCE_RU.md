# Реестр моделей DOS Frontier: First Encounters

57 спецификаций моделей с индексами 15–71 и 19 массивов выбора повторно извлечены из пользовательского FIRSTENC.EXE. Новое извлечение совпало с прежним реестром. SHA‑256 EXE — `d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`. Ниже только идентификаторы, названия и отношения таблиц. [Извлекатель](../recovered-history/ground_harness/tools/extract_ship_registry.py#L46) · [Реестр](../data/ffe_ship_registry.json)

В обычной генерации наличия F622 и F633 вызывают F634 с группами 0, 1 и 13. F635 меняет группы 0 и 1 по коду режима системы. Коды 0–3 дают пары 0–7. В объединении этих групп и 13 есть 45 уникальных моделей. Отдельно в таблице систем найден специальный режим 4, которому соответствуют группы 8 и 9 с таргоидными моделями. Это свидетельствует о наличии особых данных. Возможность покупки в действующем порту режима 4 и доступ по кампании требуют отдельной проверки.

Указание «обычные пулы» означает, что этот ID входит в один из входных списков генератора наличия. На реальные предложения влияют население, принадлежность порта и случайный выбор. F634 ограничивает один список 13 позициями. Попадание в пул само по себе не подтверждает прохождение всех условий покупки, экипажа или получения корпуса в кампании. [Заполнение верфи](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L42833) · [Выбор модели](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L43543) · [Сами пулы](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffedat.asm#L9622)

Индексы 16, 46, 52 и 66 не найдены ни в одном из 19 взвешенных пулов. Некоторые могут вызываться другим кодом. Шесть строк имеют исходное имя Unknown. Мины, несколько классов ракет и спасательная капсула имеют отдельные индексы 4–14 вне этих 57 спецификаций. [Справочник индексов](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/srctools/shipidx.txt#L5)

| ID | Исходная подпись | Обычные пулы верфи | Другие пулы | Поле экипажа |
| ---: | --- | --- | --- | ---: |
| 15 | Interplanetary Shuttle | 13 | — | 1 |
| 16 | StowMaster Fighter | — | — | 1 |
| 17 | Unknown | — | 18 | 1 |
| 18 | Lifter | 13 | — | 1 |
| 19 | Osprey attack fighter | 2 | 11 | 1 |
| 20 | Falcon attack fighter | 4, 6 | 11 | 1 |
| 21 | Hawk airfighter | 4 | 11 | 1 |
| 22 | Kestrel airfighter | 4 | 11 | 1 |
| 23 | Eagle long range fighter | 3, 4, 6 | 11 | 1 |
| 24 | Eagle Mk2 fighter | 4, 6 | 11 | 1 |
| 25 | Eagle Mk3 fighter | 2, 3 | 11 | 1 |
| 26 | Sidewinder | 0, 6 | 11 | 1 |
| 27 | Krait Assault Craft | 0 | 11 | 1 |
| 28 | Gecko | 0, 1 | 10, 11 | 1 |
| 29 | Adder | 0, 1, 5, 6, 7 | 10, 11, 12 | 1 |
| 30 | Viper Defence Craft | 0, 1, 2, 4, 5, 6 | 11, 14 | 1 |
| 31 | Saker III fighter | 4, 6, 7 | 11 | 1 |
| 32 | Osprey X attack fighter | 2 | 11, 12 | 1 |
| 33 | Merlin attack fighter | 4, 6 | 11 | 1 |
| 34 | Viper Defence MkII | 0, 1, 2, 4, 5, 6 | 10, 11, 14 | 1 |
| 35 | Gyr attack fighter | 4, 6 | 11, 12 | 1 |
| 36 | Cobra Mk I | 0, 1, 5, 6, 7 | 10, 11, 12 | 1 |
| 37 | Moray Starboat | 1 | 10, 12 | 1 |
| 38 | Cobra Mk III | 1, 5, 7 | 10, 12 | 1 |
| 39 | Constrictor | 1, 4, 5, 7 | 10, 12 | 2 |
| 40 | Asp Explorer | 0, 1, 5, 6, 7 | 10, 12 | 2 |
| 41 | Lanner | 1, 6, 7 | 10 | 3 |
| 42 | Harris fighter | 0, 6, 7 | 10, 11, 12 | 3 |
| 43 | Spar attack fighter | 4, 6 | 10, 11 | 1 |
| 44 | Wyvern Explorer | 1, 5, 7 | 16 | 3 |
| 45 | Skeet cruiser | 5, 7 | 16 | 6 |
| 46 | Turner Class | — | — | 1 |
| 47 | Lanner II | 1, 7 | 10, 16 | 3 |
| 48 | Harrier | 6 | 10, 11 | 2 |
| 49 | Unknown | — | 8, 9, 17 | 1 |
| 50 | Unknown | — | 8, 9, 17 | 1 |
| 51 | Unknown | — | 8, 9, 17 | 1 |
| 52 | Unknown | — | — | 1 |
| 53 | Transporter | 1, 5 | 16 | 3 |
| 54 | Lion Transport | 5 | 16 | 4 |
| 55 | Tiger Trader | 5 | 16 | 5 |
| 56 | Imperial Courier | 2, 3 | 10, 16 | 3 |
| 57 | Python Freighter | 1, 7 | 16 | 7 |
| 58 | Imperial Trader | 3 | 16 | 6 |
| 59 | Anaconda Freighter | 1, 7 | 16 | 8 |
| 60 | Puma Clipper | 5 | 16 | 9 |
| 61 | Boa Freighter | 1, 7 | 16 | 10 |
| 62 | Panther Clipper | 5 | 16 | 12 |
| 63 | Unknown | — | 8, 9, 17 | 1 |
| 64 | Tiercel Freighter | 7 | 16 | 6 |
| 65 | Imperial Explorer | 1, 3, 7 | 10, 16 | 10 |
| 66 | IMRA Command Ship | — | — | 10 |
| 67 | Mantis Transport | 5, 7 | 16 | 8 |
| 68 | Griffin Carrier | 1, 5, 7 | 16 | 12 |
| 69 | Thargoid Transporter | — | 9, 17 | 1 |
| 70 | Lynx Bulk Carrier | — | 15 | 20 |
| 71 | Long-range Cruiser | — | 15 | 100 |

Значение поля экипажа приведено из 24-байтной записи спецификации. Для сравнения с числом нанятых работников нужно учитывать правила допуска самой игры.
