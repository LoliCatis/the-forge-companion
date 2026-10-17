part of 'app.dart';

/// Translates only interface strings. Game names and user-created text fall
/// through unchanged, so ore and recipe names retain their original spelling.
String appLocalizedText(BuildContext context, String value) {
  if (Localizations.localeOf(context).languageCode != 'ru') return value;
  final exact = _ruText[value];
  if (exact != null) return exact;

  final activeData = RegExp(r'^Active data · (.*)$').firstMatch(value);
  if (activeData != null) return 'Активный набор данных · ${activeData[1]}';
  final ruleset = RegExp(r'^Ruleset · (.*)$').firstMatch(value);
  if (ruleset != null) return 'Набор правил · ${ruleset[1]}';
  final available = RegExp(r'^(\d+) available for recipes$').firstMatch(value);
  if (available != null) return 'Доступно для рецептов: ${available[1]}';
  final confidence = RegExp(r'^Data confidence (\d+)% · (\d+) ore types$')
      .firstMatch(value);
  if (confidence != null) {
    return 'Надёжность данных: ${confidence[1]}% · типов руды: ${confidence[2]}';
  }
  final export = RegExp(r'^Bundle exported: (.*)$').firstMatch(value);
  if (export != null) return 'Пакет экспортирован: ${export[1]}';
  final failure = RegExp(r'^Bundle validation failed: (.*)$').firstMatch(value);
  if (failure != null) return 'Не удалось проверить пакет: ${failure[1]}';
  final reviewFailure = RegExp(r'^Review failed: (.*)$').firstMatch(value);
  if (reviewFailure != null) return 'Ошибка проверки: ${reviewFailure[1]}';
  final slot = RegExp(r'^Ore slot (\d+)$').firstMatch(value);
  if (slot != null) return 'Ячейка руды ${slot[1]}';
  final editOre = RegExp(r'^Edit (.+)$').firstMatch(value);
  if (editOre != null) return 'Изменить ${editOre[1]}';
  final trait = RegExp(r'^Trait · (.*)$').firstMatch(value);
  if (trait != null) return 'Эффект · ${trait[1]}';
  final source = RegExp(r'^Source · (.*)$').firstMatch(value);
  if (source != null) return 'Источник · ${source[1]}';
  final preferred = RegExp(r'^Preferred value: (.*)$').firstMatch(value);
  if (preferred != null) return 'Предпочтительное значение: ${preferred[1]}';
  final currentPreferred = RegExp(r'^Current preferred: (.*)$').firstMatch(value);
  if (currentPreferred != null) {
    return 'Текущее предпочтительное значение: ${currentPreferred[1]}';
  }
  final preferredShort = RegExp(r'^Preferred: (.*)$').firstMatch(value);
  if (preferredShort != null) return 'Предпочтительно: ${preferredShort[1]}';
  final countVerified = RegExp(r'^(\d+) fields verified from this screenshot\.$')
      .firstMatch(value);
  if (countVerified != null) {
    return 'Полей подтверждено по этому снимку: ${countVerified[1]}.';
  }
  final reviewCount = RegExp(r'^Review & confirm (\d+) fields$').firstMatch(value);
  if (reviewCount != null) return 'Проверить и подтвердить: ${reviewCount[1]} пол.';
  final activeHealth = RegExp(r'^ACTIVE DATA · (.*)$').firstMatch(value);
  if (activeHealth != null) return 'АКТИВНЫЕ ДАННЫЕ · ${activeHealth[1]}';
  final objective = RegExp(r'^Objective: (.*)$').firstMatch(value);
  if (objective != null) return 'Цель: ${objective[1]}';
  final verifiedRows = RegExp(r'^IN-GAME VERIFIED OBSERVATIONS · (\d+)$')
      .firstMatch(value);
  if (verifiedRows != null) {
    return 'ПРОВЕРЕНО В ИГРЕ · ${verifiedRows[1]} наблюдений';
  }
  final localEvidence = RegExp(r'^(\d+) local evidence artifacts · (.*)$')
      .firstMatch(value);
  if (localEvidence != null) {
    return 'Локальных файлов свидетельств: ${localEvidence[1]} · ${localEvidence[2]}';
  }
  final statusPill = RegExp(r'^(.+) · (\d+)$').firstMatch(value);
  if (statusPill != null && _ruText.containsKey(statusPill[1])) {
    return '${_ruText[statusPill[1]]} · ${statusPill[2]}';
  }
  final saveCount = RegExp(r'^(\d+) saved (recipe|recipes)$').firstMatch(value);
  if (saveCount != null) return 'Сохранено рецептов: ${saveCount[1]}';
  final warningCount = RegExp(r'^(\d+) data items need attention\.$')
      .firstMatch(value);
  if (warningCount != null) return 'Требуют внимания элементов данных: ${warningCount[1]}.';
  final updateError = RegExp(r'^Update check failed: (.*)$').firstMatch(value);
  if (updateError != null) return 'Не удалось проверить обновления: ${updateError[1]}';
  final outdated = RegExp(r'^Mark (.*) \((.*)\) outdated$').firstMatch(value);
  if (outdated != null) {
    return 'Пометить ${outdated[1]} (${outdated[2]}) как устаревшее';
  }
  final preferredSet = RegExp(r'^Preferred value set to (.*)\. Alternatives remain in history\.$').firstMatch(value);
  if (preferredSet != null) {
    return 'Предпочтительным выбрано значение ${preferredSet[1]}. Альтернативы сохранены в истории.';
  }
  final candidatePack = RegExp(r'^Verified candidate pack v([^ ]+) · (\d+) eligible fields$')
      .firstMatch(value);
  if (candidatePack != null) {
    return 'Кандидат проверенного набора v${candidatePack[1]} · полей: ${candidatePack[2]}';
  }
  final candidateOverlay = RegExp(r'^Verified overlay exported: (.*)$').firstMatch(value);
  if (candidateOverlay != null) {
    return 'Проверенный слой данных экспортирован: ${candidateOverlay[1]}';
  }
  final reviewEvidence = RegExp(r'^Review (.*)$').firstMatch(value);
  if (reviewEvidence != null) return 'Проверить ${reviewEvidence[1]}';
  final status = RegExp(r'^Status: (.*)$').firstMatch(value);
  if (status != null) return 'Статус: ${status[1]}';
  final share = RegExp(r'^Share (.*)$').firstMatch(value);
  if (share != null) return 'Доля ${share[1]}';
  final currentBuild = RegExp(r'^Current build: (.*)$').firstMatch(value);
  if (currentBuild != null) return 'Текущая сборка: ${currentBuild[1]}';
  final newBuild = RegExp(r'^New build: (.*)$').firstMatch(value);
  if (newBuild != null) return 'Новая сборка: ${newBuild[1]}';
  final totalOres = RegExp(r'^Total ores: (\d+)\s+•\s+Up to (\d+) ore types$')
      .firstMatch(value);
  if (totalOres != null) {
    return 'Всего руды: ${totalOres[1]}   •   До ${totalOres[2]} видов';
  }
  final versionPair = RegExp(r'^Version: (.*) → (.*)$').firstMatch(value);
  if (versionPair != null) {
    return 'Версия: ${versionPair[1]} → ${versionPair[2]}';
  }
  final commitPair = RegExp(r'^Commit: (.*) → (.*)$').firstMatch(value);
  if (commitPair != null) {
    return 'Коммит: ${commitPair[1]} → ${commitPair[2]}';
  }
  final dataVersion = RegExp(r'^Data version: (.*)$').firstMatch(value);
  if (dataVersion != null) return 'Версия данных: ${dataVersion[1]}';
  final buildDate = RegExp(r'^Build date \(UTC\): (.*)$').firstMatch(value);
  if (buildDate != null) return 'Дата сборки (UTC): ${buildDate[1]}';
  return value;
}

/// A small wrapper keeps screen code readable while making ordinary labels,
/// dialog copy, empty states, and button text use the selected app language.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.translate = true,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final bool translate;

  @override
  Widget build(BuildContext context) => material.Text(
    translate ? appLocalizedText(context, data) : data,
    key: key,
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
  );
}

const Map<String, String> _ruText = {
  'Dashboard': 'Обзор',
  'Inventory': 'Инвентарь',
  'Forge': 'Кузница',
  'Optimizer': 'Оптимизатор',
  'Compare': 'Сравнение',
  'Ores': 'Руды',
  'Data Health': 'Состояние данных',
  'Verification': 'Проверка',
  'Settings': 'Настройки',
  'WORKSPACE': 'РАБОЧАЯ ОБЛАСТЬ',
  'DATA TOOLS': 'ИНСТРУМЕНТЫ ДАННЫХ',
  'PREFERENCES': 'НАСТРОЙКИ',
  'Local data ready': 'Локальные данные готовы',
  'Values keep their source and confidence': 'У значений сохранены источники и оценка достоверности',
  'Expand navigation': 'Развернуть меню',
  'Collapse navigation': 'Свернуть меню',
  'Your forge at a glance': 'Кузница: обзор',
  'Your local workshop for ore, recipes, and source-aware results.': 'Место для работы с рудой, рецептами и данными с указанными источниками.',
  'Ready when you are': 'Всё готово к работе',
  'Build a recipe, inspect the mix, and keep every value tied to its source.': 'Соберите рецепт, проверьте состав и проследите источник каждого значения.',
  'not installed': 'не установлено',
  'Open Forge': 'Открыть кузницу',
  'Ore types in inventory': 'Видов руды в инвентаре',
  'with stored quantity': 'с сохранённым количеством',
  'Usable quantity': 'Доступное количество',
  'after protected stock': 'за вычетом запаса',
  'Last Forge scenario': 'Последний сценарий кузницы',
  'No saved recipes yet': 'Сохранённых рецептов пока нет',
  'recipe': 'рецепт',
  'recipes': 'рецептов',
  'Verified coverage': 'Проверено в игре',
  'known fields': 'из известных полей',
  'data items need attention': 'элементов данных требуют внимания',
  'Review conflicts and pending captures in Data Health.': 'Проверьте конфликты и ожидающие снимки в разделе «Состояние данных».',
  'Your workspace': 'Рабочая область',
  'Data stays on this device. Community values remain attributed and unverified.': 'Данные остаются на этом устройстве. У значений сообщества сохранён источник; они не считаются проверенными.',
  'Configure and inspect a recipe': 'Настроить и проверить рецепт',
  'Track available and protected ores': 'Учитывать доступную и зарезервированную руду',
  'Review saved recipes side by side': 'Сравнить сохранённые рецепты',
  'Ruleset': 'Набор правил',
  'Track what you have and reserve the pieces you want to keep.': 'Учитывайте запас и резервируйте руду, которую хотите сохранить.',
  'Available to forge': 'Доступно для ковки',
  'quantity after reservations': 'количество после резерва',
  'Ores tracked': 'Руды в инвентаре',
  'with a stored quantity': 'с сохранённым количеством',
  'Protected stock': 'Зарезервировано',
  'reserved from calculations': 'не учитывается в расчётах',
  'Find an ore': 'Найти руду',
  'Rarity': 'Редкость',
  'Sort by': 'Сортировка',
  'All': 'Все',
  'Unknown': 'Неизвестно',
  'Common': 'Обычная',
  'Uncommon': 'Необычная',
  'Rare': 'Редкая',
  'Epic': 'Эпическая',
  'Legendary': 'Легендарная',
  'Mythic': 'Мифическая',
  'Name': 'Название',
  'Quantity': 'Количество',
  'No ores match': 'Руды не найдены',
  'Try another search or clear the rarity filter.': 'Измените запрос или сбросьте фильтр редкости.',
  'Multiplier unknown': 'Множитель неизвестен',
  'Quantity owned': 'В наличии',
  'Protected': 'В резерве',
  'Forge calculator': 'Расчёт ковки',
  'Build a mix and inspect what can be calculated from the data you have.': 'Составьте смесь и посмотрите, что можно рассчитать на основе имеющихся данных.',
  'DATA POLICY': 'ПОЛИТИКА ДАННЫХ',
  'Best available': 'Все доступные данные',
  'Verified preferred': 'Проверенные в приоритете',
  'Verified only': 'Только проверенные',
  'Available inventory': 'Доступная руда',
  'Select ore': 'Выберите руду',
  'Unknown / no curve': 'Неизвестно / нет кривой',
  'Linear 10% → 30%': 'Линейная 10% → 30%',
  'Alternate code formula': 'Альтернативная формула кода',
  'Save scenario': 'Сохранить сценарий',
  'Recipe and calculation snapshot saved.': 'Рецепт и снимок расчёта сохранены.',
  'CALCULATION': 'РАСЧЁТ',
  'Manual scenario': 'Ручной сценарий',
  'COMPOSITION': 'СОСТАВ',
  'Choose ores to see the mix.': 'Выберите руды, чтобы увидеть состав смеси.',
  'TRAIT BREAKDOWN': 'РАСПРЕДЕЛЕНИЕ ЭФФЕКТОВ',
  'Effect parameters unknown': 'Параметры эффекта неизвестны',
  'No field observations recorded. Pack-level candidate values are shown with their source status.': 'Наблюдений по полям нет. Показаны предварительные значения из набора данных с их статусом источника.',
  'Close': 'Закрыть',
  'Total ores:': 'Всего руды:',
  'Up to 4 ore types': 'До 4 видов руды',
  'Build optimizer': 'Оптимизатор рецептов',
  'Searches craftable inventory mixes; unknown data cannot improve a score.': 'Подбирает смеси из доступного запаса. Неизвестные данные не повышают оценку.',
  'Max multiplier': 'Максимальный множитель',
  'Max raw DPS': 'Максимальный базовый урон в секунду',
  'Max expected DPS': 'Максимальный ожидаемый урон в секунду',
  'Max selected effects': 'Максимум выбранных эффектов',
  'No rankable recipes. Add inventory and source-aware multipliers in Ores; DPS objectives also require verified weapon and effect inputs.': 'Нет рецептов для ранжирования. Добавьте запас и множители с источниками в разделе «Руды». Для расчёта урона нужны проверенные данные оружия и эффектов.',
  'Why this result': 'Почему получен такой результат',
  'Save calculation snapshot': 'Сохранить снимок расчёта',
  'Calculation snapshot saved': 'Снимок расчёта сохранён',
  'Compare builds': 'Сравнение рецептов',
  'See recipe composition, multipliers, and what the current data cannot establish.': 'Сравнивайте состав рецептов и множители, а также ограничения текущих данных.',
  'Build and save a recipe in Forge to compare it here.': 'Создайте и сохраните рецепт в кузнице, чтобы сравнить его здесь.',
  'Saved recipes': 'Сохранённые рецепты',
  'Choose up to four recipes to compare.': 'Выберите до четырёх рецептов.',
  'Delete saved recipe': 'Удалить сохранённый рецепт',
  'Empty recipe': 'Пустой рецепт',
  'ore types': 'видов руды',
  'Ore database': 'Каталог руд',
  'Edit a value with its source. An unverified manual value stays marked UNKNOWN.': 'Изменяйте значение вместе с его источником. Непроверенное значение останется со статусом UNKNOWN.',
  'No ores found': 'Руды не найдены',
  'Try a shorter name or another search.': 'Попробуйте сократить запрос или изменить его.',
  'Trait': 'Эффект',
  'Source': 'Источник',
  'Price unknown': 'Цена неизвестна',
  'Edit': 'Изменить',
  'Cancel': 'Отмена',
  'Save': 'Сохранить',
  'Enter non-negative numeric values.': 'Введите неотрицательные числовые значения.',
  'CURRENT PREFERRED SOURCE': 'ТЕКУЩИЙ ПРЕДПОЧТИТЕЛЬНЫЙ ИСТОЧНИК',
  'ALTERNATIVE OBSERVATIONS': 'АЛЬТЕРНАТИВНЫЕ НАБЛЮДЕНИЯ',
  'No observations are recorded for this field.': 'Для этого поля нет сохранённых наблюдений.',
  'Observation marked reviewed. Reopen the inspector to confirm it.': 'Наблюдение отмечено как проверенное. Откройте инспектор ещё раз, чтобы подтвердить его.',
  'Confirm from in-game evidence': 'Подтвердить по игровому свидетельству',
  'Confirm': 'Подтвердить',
  'Set this observation as preferred': 'Сделать это наблюдение предпочтительным',
  'Mark reviewed': 'Отметить как проверенное',
  'Storage': 'Хранение данных',
  'Inventory, recipes, observations, and data source records are stored locally in SQLite.': 'Инвентарь, рецепты, наблюдения и источники данных хранятся локально в SQLite.',
  'Network access': 'Сетевой доступ',
  'The app does not collect game data. Application updates require your confirmation.': 'Приложение не собирает игровые данные. Обновления устанавливаются только после подтверждения.',
  'Application updates': 'Обновления приложения',
  'Changes': 'Изменения',
  'Version': 'Версия',
  'Commit': 'Коммит',
  'Data version': 'Версия данных',
  'Build date (UTC)': 'Дата сборки (UTC)',
  'Check the latest portable Windows build from the official project GitHub releases. Installation starts only after confirmation.': 'Проверьте последнюю portable-сборку Windows в официальных релизах проекта на GitHub. Установка начнётся только после подтверждения.',
  'Interface language': 'Язык интерфейса',
  'Language': 'Язык',
  'English': 'English',
  'Русский': 'Русский',
  'Planned after the first working version.': 'Запланировано после первой рабочей версии.',
  'This section will use the same source tracking and verification rules as the current data layer.': 'В этом разделе будут действовать те же правила отслеживания источников и проверки данных.',
  'Add target to session': 'Добавить цель в сессию',
  'CALCULATION-CRITICAL VERIFIED COVERAGE': 'ПРОВЕРЕННЫЕ ДАННЫЕ, ВАЖНЫЕ ДЛЯ РАСЧЁТОВ',
  'Counts cover catalog-critical fields; hidden effect parameters are not inferred from visible screenshots.': 'Подсчитываются важные для каталога поля; скрытые параметры эффектов не выводятся из видимых снимков.',
  'IN-GAME VERIFIED OBSERVATIONS': 'НАБЛЮДЕНИЯ, ПРОВЕРЕННЫЕ В ИГРЕ',
  'ISSUE FILTER': 'ФИЛЬТР ПРОБЛЕМ',
  'ACTIVE DATA': 'АКТИВНЫЕ ДАННЫЕ',
  'Issue filter': 'Фильтр проблем',
  'All issues': 'Все проблемы',
  'Verification status': 'Статус проверки',
  'Enter or search': 'Введите запрос или найдите',
  'Date:': 'Дата:',
  'Choose': 'Выбрать',
  'Save crop': 'Сохранить фрагмент',
  'Bundle exported:': 'Пакет экспортирован:',
  'Bundle validation failed:': 'Не удалось проверить пакет:',
  'Review': 'Проверка',
  'Confirm card and verify fields': 'Подтвердить карточку и проверить поля',
  'New session': 'Новая сессия',
  'Export ZIP': 'Экспортировать ZIP',
  'Edit session': 'Изменить сессию',
  'Session queue': 'Очередь сессии',
  'Priority targets': 'Приоритетные цели',
  'Import a PNG, JPG or WebP screenshot': 'Импортируйте снимок экрана PNG, JPG или WebP',
  'Evidence file is missing': 'Файл свидетельства не найден',
  'Manual extraction': 'Ручное извлечение данных',
  'Community examples remain labeled COMMUNITY. Screenshot values enter as ENTERED; confirmation is always explicit.': 'Примеры сообщества сохраняют статус COMMUNITY. Данные со снимков получают статус ENTERED и подтверждаются отдельно.',
  'Save as ENTERED': 'Сохранить со статусом ENTERED',
  'Review & provenance': 'Проверка и происхождение данных',
  'Save correction to this field': 'Сохранить исправление этого поля',
  'Review observation': 'Проверить наблюдение',
  'Reject': 'Отклонить',
  'Confirm from screenshot': 'Подтвердить по снимку',
  'Promote to IN_GAME_VERIFIED': 'Присвоить статус IN_GAME_VERIFIED',
  'Requires explicit confirmation, update context and an intact local screenshot checksum.': 'Требуется явное подтверждение, контекст обновления и совпадающая контрольная сумма локального снимка.',
  'Prefer this observation': 'Выбрать это наблюдение предпочтительным',
  'Existing alternatives': 'Существующие варианты',
  'Observation remains unresolved; no preferred value was changed.': 'Наблюдение осталось нерешённым; предпочтительное значение не изменено.',
  'Keep unresolved': 'Оставить нерешённым',
  'Current recipe': 'Текущий рецепт',
  'Select up to four ore types and set each amount.': 'Выберите до четырёх видов руды и укажите количество каждого.',
  'Objective': 'Цель',
  'Min ores': 'Минимум руды',
  'Max ores': 'Максимум руды',
  'Required ore IDs': 'Обязательные ID руд',
  'Forbidden ore IDs': 'Исключённые ID руд',
  'Effect tags': 'Теги эффектов',
  'ore-one, ore-two': 'ore-one, ore-two',
  'burn, defense': 'burn, defense',
  'Ranked recipes': 'Рецепты по рейтингу',
  'Protected quantities stay reserved from every suggestion.': 'Зарезервированная руда исключена из всех рекомендаций.',
  'Search ore database': 'Поиск по каталогу руд',
  'Multiplier': 'Множитель',
  'Ore price': 'Цена руды',
  'Source name': 'Название источника',
  'Source type': 'Тип источника',
  'Observed date (YYYY-MM-DD)': 'Дата наблюдения (ГГГГ-ММ-ДД)',
  'Game version/update context': 'Версия игры / контекст обновления',
  'Evidence reference / URL': 'Ссылка на свидетельство / URL',
  'Evidence type': 'Тип свидетельства',
  'Notes': 'Заметки',
  'Game version / update context': 'Версия игры / контекст обновления',
  'Official game version / update (optional)': 'Официальная версия игры / обновление (необязательно)',
  'World / location (optional)': 'Мир / локация (необязательно)',
  'Check type': 'Тип проверки',
  'Crop label': 'Название фрагмента',
  'Entity type': 'Тип сущности',
  'Entity id / name': 'ID / название сущности',
  'Field': 'Поле',
  'Value': 'Значение',
  'Evidence crop / screenshot': 'Фрагмент свидетельства / снимок',
  'Weapon stats source': 'Источник характеристик оружия',
  'Scenario base damage': 'Базовый урон сценария',
  'Attack interval (s)': 'Интервал атаки (с)',
  'Trait scaling hypothesis': 'Гипотеза масштабирования эффекта',
  'Recipe name': 'Название рецепта',
  'Qty': 'Кол-во',
  'No data issues here': 'Проблем с данными нет',
  'Nothing matches the current filters.': 'По текущим фильтрам ничего не найдено.',
  'Add to verification session': 'Добавить в сессию проверки',
  'Inspect multiplier sources': 'Посмотреть источники множителя',
  'Edit values': 'Изменить значения',
  'Validate ZIP': 'Проверить ZIP',
  'Import staged intake': 'Импортировать подготовленный набор',
  'Candidate diff': 'Сравнение кандидатов',
  'Export verified overlay': 'Экспортировать проверенный слой данных',
  'Import screenshot': 'Импортировать снимок',
  'Choose screenshot': 'Выбрать снимок',
  'Cancel crop': 'Отменить обрезку',
  'Select crop': 'Выбрать фрагмент',
  'Save crop as evidence': 'Сохранить фрагмент как свидетельство',
  'Confirm only if the screenshot supports every listed field. This action marks this card IN_GAME_VERIFIED; an official update number is optional.': 'Подтверждайте только те поля, которые видны на снимке. Карточка получит статус IN_GAME_VERIFIED; официальный номер обновления необязателен.',
  'Review & confirm': 'Проверить и подтвердить',
  'Trait ·': 'Эффект ·',
  'Source ·': 'Источник ·',
  'DPS': 'Урон в секунду',
  'Attack speed': 'Скорость атаки',
  'Range': 'Дальность',
  'Current preferred:': 'Текущее предпочтительное значение:',
  'Select or create a verification session': 'Выберите или создайте сессию проверки',
  'Screenshots': 'Снимки экрана',
  'Verification bundle': 'Пакет проверки',
  'Application language': 'Язык приложения',
  'EN': 'EN',
  'RU': 'RU',
  'community': 'сообщество',
  'community only': 'только сообщество',
  'entered': 'введено',
  'reviewed': 'проверено',
  'user confirmed capture': 'снимок подтверждён пользователем',
  'in game verified': 'проверено в игре',
  'conflict': 'конфликт',
  'unknown': 'неизвестно',
  'Data health': 'Состояние данных',
  'Field-level provenance, unresolved conflicts, and probability diagnostics.': 'Источники значений, нерешённые конфликты и диагностика вероятностей.',
  'Local-first prototype settings.': 'Локальные настройки приложения.',
  'ORES IN CATALOG': 'РУД В КАТАЛОГЕ',
  'VERIFIED FIELD OBSERVATIONS': 'ПОЛЕЙ ПОДТВЕРЖДЕНО',
  'COMMUNITY / GUIDE FIELDS': 'ПОЛЕЙ ИЗ СООБЩЕСТВА / РУКОВОДСТВ',
  'CONFLICTING FIELDS': 'ПОЛЕЙ С КОНФЛИКТАМИ',
  'OUTDATED OBSERVATIONS': 'УСТАРЕВШИХ НАБЛЮДЕНИЙ',
  'UNKNOWN / TABLE ISSUES': 'НЕИЗВЕСТНЫЕ ДАННЫЕ / ПРОБЛЕМЫ ТАБЛИЦ',
  'Field-level records and issues': 'Записи и проблемы отдельных полей',
  'No pack': 'Нет набора данных',
  'No ruleset': 'Нет набора правил',
  'Critical': 'Критично',
  'Needs Verification': 'Требует проверки',
  'Stale': 'Устарело',
  'Conflict': 'Конфликт',
  'Resolved': 'Разрешено',
  'Conflicts': 'Конфликты',
  'Unreviewed': 'Не проверено',
  'Needs confirmation': 'Требует подтверждения',
  'Confirmed capture': 'Снимок подтверждён',
  'Game verified': 'Проверено в игре',
  'Rejected': 'Отклонено',
  'Weapons': 'Оружие',
  'Traits': 'Эффекты',
  'Probabilities': 'Вероятности',
  'Formulas': 'Формулы',
  'Community fallback is active for selected inputs; results remain estimates.': 'Для выбранных данных используется запасной вариант из сообщества; результаты остаются оценочными.',
  'Game-verified values are preferred. Missing values use community data and remain labeled as such.': 'Приоритет у значений, проверенных в игре. Для отсутствующих используются данные сообщества с соответствующей пометкой.',
  'INCOMPLETE · Required verified inputs are missing; community values are withheld for this calculation.': 'НЕПОЛНЫЕ ДАННЫЕ · Нет обязательных проверенных значений; данные сообщества не используются в этом расчёте.',
  'Weapon damage and attack speed are not available as verified local inputs, so DPS remains Unknown for every recipe.': 'Проверенные значения урона и скорости атаки недоступны, поэтому урон в секунду для всех рецептов неизвестен.',
  'Source confidence and formula confidence are kept separate. Probability-table diagnostic rows show source sums and are never normalized in storage.': 'Достоверность источника и формулы учитывается отдельно. Диагностика таблиц вероятностей показывает суммы источников; значения не нормализуются при сохранении.',
  'Loading updates…': 'Проверяем обновления…',
  'Check for updates': 'Проверить обновления',
  'Install update': 'Установить обновление',
  'No update available': 'Обновлений нет',
  'Update available': 'Доступно обновление',
  'Update check failed': 'Не удалось проверить обновления',
  'Download failed': 'Не удалось скачать обновление',
  'Current build': 'Текущая сборка',
  'New build': 'Новая сборка',
  'Install now': 'Установить сейчас',
  'Not now': 'Не сейчас',
  'The app will close and reopen to finish installing the update.': 'Приложение закроется и откроется снова после установки обновления.',
  'This portable update is available for Windows builds only.': 'Автообновление этой portable-сборки доступно только в Windows.',
  'Not supported yet': 'Пока не поддерживается',
  'This installation folder is not writable.': 'Нет прав на запись в папку приложения.',
  'The downloaded update failed its SHA-256 check.': 'Контрольная сумма SHA-256 скачанного обновления не совпала.',
  'Downloading update…': 'Скачиваем обновление…',
  'Preparing update…': 'Подготавливаем обновление…',
};
