# Оснащение DOS Frontier: First Encounters

Из пользовательского `FIRSTENC.EXE` прочитаны 66 записей оснащения и их оригинальные английские подписи. В присланном перечне найдено 53 совпадения, включая сокращения C1–C8 и M1–M4. Из 47 позиций, которые может показать штатный магазин DOS, в перечне есть 44. Проверены состав, массы, численные цены, условия вывода в магазине и приведённые ниже особенности механик. [Скачать CSV со всеми 66 записями](../data/ffe_dos_equipment_catalog.csv)

## Что добавить к перечню

| ID | Оригинальная подпись | Масса, т | Доступность |
| ---: | --- | ---: | --- |
| 10 | Missile Viewer | 0 | Магазин от техуровня 215. Показывает вид с выпущенной ракеты. |
| 11 | Auto targetter | 0 | Магазин от техуровня 176. Захватывает цель под прицелом в боевом или навигационном режиме. |
| 14 | Auto Refueller | 1 | Магазин от техуровня 137. Переливает подходящее грузовое топливо в реактивный бак при его истощении. |
| 8 | Mycoid Missile | 1 | В сюжете подбирается из контейнера с гипермикоидом и занимает свободную ракетную подвеску. |
| 60 | Transmission jammer | 0 | Сюжетное оснащение. |
| 61 | Military Cameras | 0 | Сюжетное оснащение для съёмки. |
| 62 | Inter-Species Translator | 0 | Сюжетное оснащение. |
| 63 | Tracking Device | 1 | Сюжетное оснащение для поиска корабля с вакциной. |
| 64 | Vaccine Mining Machine | 20 | Сюжетная машина для бункеров. У обычной MB4 масса 30 т. |
| 0 | XB13 Dummy Prox. Mine | 1 | Скрытая запись мины. |
| 13 | New Equipment 4 | 0 | Служебная подпись. |
| 50 | Fighter Launch Device | 100 | Скрытая запись. |
| 59 | "Stowmaster" fighter | 14 | Сюжетный спасательный истребитель. При катапультировании используется корпус `StowMaster Fighter` с ID 16. |

В этом списке десять записей имеют порог техуровня 255 и недоступны в штатном магазине. Некоторое оборудование выдаётся сюжетом. Само наличие строки и спецификации не устанавливает способ получения или работоспособность в игре. [Сюжетные сообщения](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffedat.asm#L1123-L1171) · [Захват цели и управление камерой](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L78500-L78767) · [Выбор спасательного корпуса](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L80352-L80379)

## Цены и доступность в конкретном DOS-выпуске

Каждая сообщённая масса совпала с таблицей. Все численные цены совпали с базовым коэффициентом ×9, включая условные цифры у скрытых позиций. В оригинальном магазине DOS базовый коэффициент составляет ×12 при техуровне ниже 179, ×11 при 179–203 и ×9 начиная с 204. Часть позиций читает цену через изменяемый сценарный коэффициент. Запись базовой цены у сюжетного оборудования сама по себе не открывает продажу. [Расчёт цены и наполнение меню](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L28564-L28654)

В исходном DOS-коде F383 проверяет порог каждого товара, а F345 принимает первые **45** строк в порядке ID. Данные систем допускают максимум 253. Поэтому **15** позиций с порогом 255 отфильтровываются, ещё **четыре** обрезаются ограничением меню на всех достаточных для них техуровнях. Это **Class 3 Military Drive**, **Class 6 Hyperdrive**, **Large Plasma Accelerator** и **Class 7 Hyperdrive**. Все четыре требуют 235 в проверенном DOS-файле. **Class 5 Hyperdrive** и **Small Plasma Accelerator** появляются в диапазоне 215–234, например в Gateway с техуровнем 230. При техуровне 235 и выше они тоже вытесняются. [Ограничение списка](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L26940-L26960) · [Чтение техуровня](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L60899-L60925)

В штатной комплектации **Puma Clipper** установлен **Class 6 Hyperdrive**, а на **Panther Clipper** — **Class 8 Hyperdrive**. **Class 4 Military Drive** установлен на сюжетных моделях Turner Class и Thargoid War Ship. В DOS-магазине видны **NN500 Naval Missile**, **Naval E.C.M. System**, **Class 1 Military Drive** и **Class 2 Military Drive** при достаточном техуровне. После выбора позиция проходит проверки денег, свободного места и совместимости. [Спецификации корпусов](../data/ffe_ship_registry.json) · [Данные приводов](../data/ffe_hyperdrive.json)

## Подписи и поведение

| В присланном перечне | Исходная подпись DOS |
| --- | --- |
| Electronic Counter Measures (ECM) | E.C.M. System |
| Naval ECM | Naval E.C.M. System |
| Autopilot | Automatic Pilot |
| Hyperspace Cloud Analyzer | Hyperspace Cloud Analyser |
| Navigation Computer | Navigation computer |
| Interplanetary Drive | Interplanetary drive |
| C1–C8 | Class 1 Hyperdrive … Class 8 Hyperdrive |
| M1–M4 | Class 1 Military Drive … Class 4 Military Drive |

- В оригинальном бинарнике ветка ECM инвертирована для **LV111 Smart Missile**, **MV1 Assault Missile** и **MV2 Assault Missile**. Эти три уничтожает обычная ECM, а Naval ECM их пропускает. Для **XB74 Proximity Mine** и **KL760 Homing Missile** срабатывают обе, **NN500 Naval Missile** пропускают обе. JJFFE меняет переход на обратный, и именно с исправлением совпадает описание в перечне. [Исправленный переход JJFFE](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L47541-L47567)
- При добыче водорода DOS проверяет попадание в атмосферную область подходящей модели звезды или газового гиганта, установленный **Fuel Scoop**, высоту, скорость, задержку и свободный трюм. Проверки двух щитов в условии сбора нет. Атмосферная защита участвует в отдельной механике нагрева. Полученный водород попадает в трюм. [Проверка Fuel Scoop и Auto Refueller](SOURCE_MINING_AND_SCOOP_AUDIT_RU.md)
- Установка **Fuel Scoop** требует подходящего крепления корпуса. **Cargo Scoop Conversion** требует установленного Fuel Scoop. **Tractor Beam Cargo Scoop** имеет отдельный флаг и может работать на одном корабле с Fuel Scoop. [Проверки установки](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L29076-L29113)
- В одном из сюжетных маршрутов **Thargoid Laser**, **Thargoid Missile** и **Vaccine Mining Machine** устанавливаются уже перед вылетом за вакциной. **Inter-Species Translator** выдаётся вместе с Argent's Quest. [Оснащение для экспедиции](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffebmp.asm#L5298-L5306) · [Выдача переводчика](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffebmp.asm#L9548-L9552)
- Сценарий с гипермикоидом меняет модель контейнера. При подборе DOS ставит **Mycoid Missile** на свободную подвеску. [Сценарная команда](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffebmp.asm#L3356-L3377) · [Подбор ракеты](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L47322-L47351)
- В расчёте гипердальности DOS использует постоянную массу модели из спецификации корпуса и целочисленное деление. Для **Class 4 Military Drive** есть отдельная поправка к расходу. [Данные и контракт гиперпрыжка](../data/ffe_hyperdrive.json)

## Проверка источника

`FIRSTENC.EXE` имеет SHA‑256 `d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`. Таблица 66 × 22 байта начинается по файловому смещению `0xC1674`. 66 указателей имён для строковых кодов от `0x9875` прочитаны с `0xC1FD8`. Подписи находятся в диапазоне `[0xC41F9, 0xC46D4)`. Список доступности рассчитан по исходным техуровням и лимиту DOS. В CSV `appears_in_stock_menu` обозначает возможность появления в списке хотя бы при одном исходном техуровне, без индивидуальной проверки корабля. Поля `base_buy_raw` и `base_sell_raw` содержат числа до умножения. Когда `price_modifier_route_raw` равно 1, F383 читает сценарный коэффициент. Условие F345 подтверждено в DOS по адресу `0x421B8D`, переход ECM по файловому смещению `0x1F320`. Проверка выполнена по таблицам и машинному коду. [Исходная таблица записей](../data/ffe_hyperdrive.json) · [Данные техуровней](../data/ffe_system_information.json)
