# Архитектурный план The Forge Companion

Статус: архитектурное описание текущих компонентов и дальнейших направлений. Продукт остаётся нативным Windows/macOS desktop приложением на Flutter/Dart.

## Целевой поток

```text
Data Packs / Manual Capture / User Entry
                 ↓
  Candidate Observation Store (SQLite)
                 ↓
 Field Resolver + Conflict/Confidence Policy
                 ↓
 Versioned Game Catalog + Versioned Ruleset
                 ↓
 Calculation Engine (pure Dart)
       ↙             ↓             ↘
  Forge Preview   Optimizer      Comparator
       ↘             ↓             ↙
   Result Explanation + Data Health + Evidence
```

## Слои

### 1. Desktop application — Flutter

Нативная оболочка Windows/macOS: dashboard, ore catalog, inventory, forge preview, weapon/armor optimizer, DPS/effect optimizer, build comparison, capture review и Data Health. UI получает доменные результаты от Dart packages, а не повторяет формулы виджетами. Начальная поддержка должна сохранять Windows 10/11 x64 и macOS ARM64; macOS x86_64 оставить отдельной собираемой целью до подтверждённого решения об отказе.

### 2. Domain model — независимая от UI

Сущности `Ore`, `TraitDefinition`, `WeaponClass`, `WeaponVariant`, `ArmorClass`, `ArmorVariant`, `ProbabilityTable`, `Recipe`, `Build`, `GameVersion` имеют стабильные IDs и отдельно display name/aliases. Каждое числовое поле хранит либо resolved value с указателем на выбранное observation, либо `unknown`; не использовать значения-заглушки как реальные нули.

### 3. Evidence и resolver

Хранить `DataSource`, `Observation`, `Evidence`, `Conflict`, `Resolution`. Observation относится к конкретному полю и содержит raw text/value, единицы, source ID, captured/imported timestamp, заявленную/известную game version, confidence rationale, status и checksum/path evidence. Screenshot crop, OCR result и user-confirmed value — разные сущности/стадии. Resolver работает по полям; старые/непроверенные значения остаются видимы даже если выбран более новый resolved value.

Предлагаемые статусы: `IN_GAME_VERIFIED`, `USER_CONFIRMED_CAPTURE`, `COMMUNITY`, `GUIDE_LISTED`, `ESTIMATED`, `CONFLICTING`, `OUTDATED`, `UNKNOWN`. Статус `IN_GAME_VERIFIED` допускается лишь при понятном evidence и подтверждённой версии/контексте; OCR alone не повышает статус.

### 4. Calculation engine — чистый Dart

Пакет engine не выполняет сетевые запросы, SQL, OCR или UI. Вход — неизменяемые catalog/ruleset snapshot plus recipe/build. Выход содержит расчётные компоненты, использованные value IDs и assumptions.

Операции:

- weighted multiplier и ore composition;
- weapon/armor output probability lookup и variant probability normalization;
- trait eligibility/compatibility, share thresholds и effect scale по формуле указанной версии;
- base stat/quality projection;
- expected damage/DPS по каждому variant;
- armor/effective survivability;
- ingredient constraints и optimizer candidate ranking.

Ruleset отдельно версионирует функции и ограничения: `rulesetId`, effective date, source notes, formulas, rounding, valid count ranges, missing-table behavior и quality assumption. A catalog multiplier field must not encode formula logic.

### 5. Database и data packs

SQLite — долговременный источник локальных пользовательских inventory/build/capture и установленных candidate packs. Следует закрепить миграции, уникальные IDs и foreign keys, сохранить `manual override` без уничтожения истории. Пакет обновления должен включать schema version, data version, source refs, checksums, license/attribution, createdAt и compatibility range. Автоматическое обновление скачивает кандидат, валидирует подпись/hash/schema/ranges, строит diff, после review устанавливает пакет. Не заменять пользовательские observation или подтверждённые поля автоматически.

### 6. Optimizer и объяснение результата

Из одного inventory generator формируются допустимые комбинации: до установленного engine ruleset предела по количеству типов/общему ore count, без превышения имеющихся запасов. Optimizer разделить на:

- `Inventory Optimizer`: достижимость цели, вероятность нужного class/variant, расход редких руд и число craft attempts;
- `DPS/Effect Optimizer`: сравнение raw base DPS и expected/effective DPS; конфигурируемые assumptions для crit, burn duration/ticks/chance, explosions, attack speed и uptime;
- `Build Comparator`: 2–5 сохранённых setups side-by-side, оружие/броня, survivability и активные эффекты.

Вместо непрозрачного единого “best” score по умолчанию выдавать Pareto front и фильтры цели. Любой агрегированный ranking показывает формулу, weights и excluded candidates. Результат обязан включать диапазон или неизвестность при низком качестве входных полей.

### 7. Data Health и in-game verification

Data Health индексирует поля по urgency: unresolved conflicts, stale, single-source guide values, missing evidence, invalid probability rows, unknown formulas. Для пользовательской проверки: выбрать конкретное поле → показать ожидаемый формат → приложить crop/screenshot и game version → OCR suggestion → ручное подтверждение → записать observation и дать сравнить с текущими вариантами.

Результаты массовых crafts могут собирать категориальные counts, размер выборки и условия в локальные experiment records. Вероятность становится экспериментально поддержанной только после заранее определённых sample thresholds/confidence intervals; иначе показывается наблюдавшаяся частота с неопределённостью.

## Дизайн интерфейса

1. Dashboard показывает последнюю версию набора данных, unresolved conflicts, offline/online и быстрый переход к последней проверке.
2. Forge input слева/в центральном редакторе, outcome probabilities и traits рядом; каждое значение раскрывает источник и краткое объяснение.
3. Рядом с “Craft” preview ясно различать: guaranteed by input, probability estimate, guide range, user observation и unknown.
4. Optimizer показывает список кандидатов с column metrics, расходом запасов и причинами ранжирования; можно закрепить build в comparator.
5. Data Health — полноценный рабочий экран, не скрытая settings-страница: фильтры по полю, источнику, дате, статусу и игре/миру.
6. Никакие screenshot/OCR или remote fetch не активируются без понятного действия пользователя; приложение остаётся полезным офлайн с последним установленным пакетом.

## Инварианты качества

- Каждая отображаемая числовая механика имеет source/status/date или явно `unknown`.
- Probability rows проходят проверку `0 ≤ p ≤ 1` и сумму; rounding residual отделён от отсутствующих исходов. Автоматическая нормализация запрещена без правила в текущем ruleset.
- Missing count/table не переносится автоматически на максимальный key. Результат сообщается как unsupported, либо extrapolation явно помечается.
- Variant stats не усредняются друг с другом без весов реального variant distribution.
- Expected DPS сохраняет отдельные компоненты и attack interval. Proc effects моделируются только с необходимыми chance/duration/cooldown/stacking; иначе показывается interval/range или исключение из общего числа.
- Все результаты сохраняют ссылку на catalog version, ruleset version, exact observations и assumptions, чтобы воспроизвести расчёт.

## Порядок реализации

1. Завершить schema catalog/observation/conflict и миграции SQLite.
2. Внести ruleset snapshots и формальные validation helpers для probability tables.
3. Разблокировать first milestone: ручной inventory, forge preview только для доступных/неизвестных полей, source-aware Data Health.
4. Добавить weapon/armor variant schema и DPS components после появления проверяемых исходных данных.
5. Реализовать deterministic optimizer generator и multi-objective ranking; затем comparator.
6. Добавить capture/OCR proposal + manual confirmation, correction/export workflow.
7. Только после dataset checks — автоматические подписанные data-pack updates.

## Изменения к текущему начатому MVP

- Seed names без чисел сохранить `UNKNOWN`; community multiplier seed не должен становиться источником вычислений без observation metadata.
- Убедиться, что schema умеет несколько observations на одно поле, unresolved conflicts и source timestamps; одна `source_id/status` на всю руду будет недостаточна.
- Версионировать `ForgeCalculator` rules separately; формулу не фиксировать как верифицированную только потому, что её можно закодировать.
- До наличия variant interval / trait event data маркировать DPS как неполный, а optimizer ограничить прозрачным objective.
- Обновления каталога применять через transaction + versioned diff, не `REPLACE` с каскадом по пользовательскому inventory.
