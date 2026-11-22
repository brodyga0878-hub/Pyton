# Покупаемые корабли DOS Frontier: First Encounters

В DOS-сборке из `Frontier_First_Encounters.rar` есть **45 моделей в обычных предложениях верфей**. Среди них **Puma Clipper** (ID 60, базовая цена 1 265 000 кр.) и **Panther Clipper** (ID 62, 2 753 000 кр.). Обе модели входят в коммерческий пул Федерации. Полный пул используется при классе населения от 4, как в Sol. Puma Clipper также попадает в сокращённый список при классе 3. Фактическое наличие зависит от сгенерированного ассортимента конкретного порта. [Таблица Федерации](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffedat.asm#L9543-L9547) · [Данные о населении Sol](PARITY_AUDIT_SYSTEM_INFO_RU.md#L123)

## Полный список штатных предложений

Цены берутся из 24-байтных спецификаций. На верфи рассчитывается доплата с учётом сдаваемого корабля. В CSV сохранены английские подписи из EXE посимвольно, включая конечный пробел у `Harrier `. [Скачать данные CSV](../data/ffe_dos_shipyard_catalog.csv) · [Расчёт цены](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L30475-L30530)

| ID | Оригинальное название | Базовая цена, кр. | Пулы |
| ---: | --- | ---: | --- |
| 15 | Interplanetary Shuttle | 14 000 | 13 |
| 18 | Lifter | 16 000 | 13 |
| 19 | Osprey attack fighter | 45 000 | 2 |
| 20 | Falcon attack fighter | 46 000 | 4,6 |
| 21 | Hawk airfighter | 48 000 | 4 |
| 22 | Kestrel airfighter | 50 000 | 4 |
| 23 | Eagle long range fighter | 38 000 | 3,4,6 |
| 24 | Eagle Mk2 fighter | 41 000 | 4,6 |
| 25 | Eagle Mk3 fighter | 43 000 | 2,3 |
| 26 | Sidewinder | 44 000 | 0,6 |
| 27 | Krait Assault Craft | 50 000 | 0 |
| 28 | Gecko | 66 000 | 0,1 |
| 29 | Adder | 73 000 | 0,1,5,6,7 |
| 30 | Viper Defence Craft | 87 000 | 0,1,2,4,5,6 |
| 31 | Saker III fighter | 43 000 | 4,6,7 |
| 32 | Osprey X attack fighter | 69 000 | 2 |
| 33 | Merlin attack fighter | 48 000 | 4,6 |
| 34 | Viper Defence MkII | 89 000 | 0,1,2,4,5,6 |
| 35 | Gyr attack fighter | 102 000 | 4,6 |
| 36 | Cobra Mk I | 97 000 | 0,1,5,6,7 |
| 37 | Moray Starboat | 109 000 | 1 |
| 38 | Cobra Mk III | 124 000 | 1,5,7 |
| 39 | Constrictor | 143 000 | 1,4,5,7 |
| 40 | Asp Explorer | 187 000 | 0,1,5,6,7 |
| 41 | Lanner | 284 000 | 1,6,7 |
| 42 | Harris fighter | 135 000 | 0,6,7 |
| 43 | Spar attack fighter | 71 000 | 4,6 |
| 44 | Wyvern Explorer | 222 000 | 1,5,7 |
| 45 | Skeet cruiser | 698 000 | 5,7 |
| 47 | Lanner II | 310 000 | 1,7 |
| 48 | Harrier | 174 000 | 6 |
| 53 | Transporter | 241 000 | 1,5 |
| 54 | Lion Transport | 348 000 | 5 |
| 55 | Tiger Trader | 472 000 | 5 |
| 56 | Imperial Courier | 611 000 | 2,3 |
| 57 | Python Freighter | 575 000 | 1,7 |
| 58 | Imperial Trader | 954 000 | 3 |
| 59 | Anaconda Freighter | 1 060 000 | 1,7 |
| 60 | Puma Clipper | 1 265 000 | 5 |
| 61 | Boa Freighter | 2 474 000 | 1,7 |
| 62 | Panther Clipper | 2 753 000 | 5 |
| 64 | Tiercel Freighter | 400 000 | 7 |
| 65 | Imperial Explorer | 2 966 000 | 1,3,7 |
| 67 | Mantis Transport | 1 179 000 | 5,7 |
| 68 | Griffin Carrier | 3 403 000 | 1,5,7 |

## Сюжетные корабли и вторичный оборот

- **Argent's Quest** имеет модель **Turner Class** (ID 46). В диалоге упоминается сделка в New Rossyth Shipyard. При принятии задания сценарий напрямую заменяет корабль игрока на ID 46, присваивает индивидуальное имя и устанавливает оснащение. [Диалог](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffedat.asm#L903-L919) · [Сценарная команда](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffebmp.asm#L9481-L9497) · [Прямая установка модели](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L3791-L3810)
- **Thargoid War Ship** — сюжетная награда. В проверенной ветви выдачи используется ID 52, чья техническая подпись в таблице — `Unknown`. У **Thargoid Transporter** отдельный ID 69. Обычное меню услуг со ссылкой на верфь пропускается в системах с кодом принадлежности 4. [Выдача награды](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffebmp.asm#L5521-L5529) · [Диалог о награде](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffedat.asm#L1142-L1149) · [Условие меню услуг](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L28443-L28454)
- При покупке выбранную строку предложения занимает предыдущий корпус игрока. Такая строка зависит от истории обменов. Каталог выше перечисляет модели, которые выставляет штатный генератор предложения. [Замена строки при обмене](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L31034-L31060)

## Проверка источника

Исполняемый файл `FIRSTENC/FIRSTENC.EXE` извлечён заново из RAR. Его SHA‑256 — `d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`. Повторно прочитаны 57 спецификаций, исходные строки и 19 пулов. Все совпали с опубликованным реестром. Английские строки Puma Clipper и Panther Clipper начинаются по файловым смещениям `0xBB691` и `0xBB6FE`. [Реестр всех моделей](FFE_DOS_SHIP_REFERENCE_RU.md) · [Данные проверенных спецификаций](../data/ffe_ship_registry.json)

В самом DOS-файле заполнение верфи передаёт группы 13, 0 и 1. Функция по адресу `0x42BE10` подставляет группы по принадлежности системы и сокращает коммерческий список по классу населения. В штатных условиях это объединение групп 0–7 и 13. Меню выводит все сформированные предложения, а сделка проверяет пассажиров на борту и баланс, затем устанавливает выбранный корпус. Команды сценарной замены на ID 46 и 52 дополнительно сверены по файловым смещениям `0x768AB` и `0x71436`. Выводы получены из таблиц и кода DOS-выпуска. [Заполнение предложения](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L42833-L42869) · [Выбор пула](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L43576-L43622) · [Отображение предложений](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L30502-L30539) · [Сделка](https://github.com/videogamepreservation/jjffe/blob/7e540341d4e09aa3c92877b87d49e7f2c143ad8d/ffe.asm#L30971-L31017)
