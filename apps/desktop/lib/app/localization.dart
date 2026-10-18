part of 'app.dart';

/// Translates only interface strings. Game names and user-created text fall
/// through unchanged, so ore and recipe names retain their original spelling.
String appLocalizedText(BuildContext context, String value) {
  if (Localizations.localeOf(context).languageCode != 'ru') return value;
  final exact = _ruText[value];
  if (exact != null) return exact;

  // Dynamic UI copy is translated by its stable label while values, IDs,
  // filenames, URLs, versions, and numeric data remain intact.
  if (value.contains('\n')) {
    return value.split('\n').map((line) => appLocalizedText(context, line)).join('\n');
  }

  final activeData = RegExp(r'^Active data · (.*)$').firstMatch(value);
  if (activeData != null) return 'Активный набор данных · ${activeData[1]}';
  final ruleset = RegExp(r'^Ruleset · (.*)$').firstMatch(value);
  if (ruleset != null) return 'Набор правил · ${ruleset[1]}';
  final unknownOfficialUpdate =
      RegExp(r'^Unknown official update(.*)$').firstMatch(value);
  if (unknownOfficialUpdate != null) {
    return 'Официальное обновление неизвестно${unknownOfficialUpdate[1]}';
  }
  final unspecifiedUpdate =
      RegExp(r'^Unspecified update(.*)$').firstMatch(value);
  if (unspecifiedUpdate != null) {
    return 'Обновление не указано${unspecifiedUpdate[1]}';
  }
  final confidence = RegExp(r'^Data confidence (\d+)% · (\d+) ore types$')
      .firstMatch(value);
  if (confidence != null) {
    return 'Надёжность данных: ${confidence[1]}% · типов руды: ${confidence[2]}';
  }
  final export = RegExp(r'^Bundle exported: (.*)$').firstMatch(value);
  if (export != null) return 'Пакет экспортирован: ${export[1]}';
  final failure = RegExp(r'^Bundle validation failed: (.*)$').firstMatch(value);
  if (failure != null) return 'Не удалось проверить пакет: ${_translateKnownError(failure[1]!)}';
  final reviewFailure = RegExp(r'^Review failed: (.*)$').firstMatch(value);
  if (reviewFailure != null) return 'Ошибка проверки: ${_translateKnownError(reviewFailure[1]!)}';
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
  final confidenceBadge = RegExp(r'^(\d+)% confidence$').firstMatch(value);
  if (confidenceBadge != null) return 'Достоверность ${confidenceBadge[1]}%';
  final unclassifiedRecipes = RegExp(r'^(\d+) saved recipes have no recorded craft target\. They are kept separate until their target is known\.$').firstMatch(value);
  if (unclassifiedRecipes != null) {
    return 'Рецептов без указанной цели ковки: ${unclassifiedRecipes[1]}. Они остаются отдельно, пока цель не будет известна.';
  }
  final targetRecipes = RegExp(r'^(\d+) saved recipes are recorded for this target\.$').firstMatch(value);
  if (targetRecipes != null) return 'Для этой цели сохранено рецептов: ${targetRecipes[1]}.';
  final saveCount = RegExp(r'^(\d+) saved (recipe|recipes)$').firstMatch(value);
  if (saveCount != null) return 'Сохранено рецептов: ${saveCount[1]}';
  final warningCount = RegExp(r'^(\d+) data items need attention\.$')
      .firstMatch(value);
  if (warningCount != null) return 'Требуют внимания элементов данных: ${warningCount[1]}.';
  final updateError = RegExp(r'^Update check failed: (.*)$').firstMatch(value);
  if (updateError != null) return 'Не удалось проверить обновления: ${_translateKnownError(updateError[1]!)}';
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
  final dataConfidence = RegExp(r'^Data confidence (\d+)% · (\d+) ore types$').firstMatch(value);
  if (dataConfidence != null) {
    return 'Достоверность данных: ${dataConfidence[1]}% · типов руды: ${dataConfidence[2]}';
  }
  final attention = RegExp(r'^(\d+) data items need attention\. Review conflicts and pending captures in (?:Data Health|Data status)\.$').firstMatch(value);
  if (attention != null) {
    return 'Требуют внимания элементов данных: ${attention[1]}. Проверьте конфликты и ожидающие подтверждения снимки в разделе «Состояние данных».';
  }
  final verifiedFromScreenshot = RegExp(r'^(\d+) fields verified from this screenshot\.$').firstMatch(value);
  if (verifiedFromScreenshot != null) {
    return 'По этому снимку подтверждено полей: ${verifiedFromScreenshot[1]}.';
  }
  final importedIntake = RegExp(r'^Imported (\d+) observations, (\d+) screenshots; (\d+) new ores, (\d+) merged\. All remain ENTERED\.$').firstMatch(value);
  if (importedIntake != null) {
    return 'Импортировано наблюдений: ${importedIntake[1]}, снимков: ${importedIntake[2]}; новых руд: ${importedIntake[3]}, объединено: ${importedIntake[4]}. Все записи остаются в статусе ENTERED.';
  }
  final fieldsReview = RegExp(r'^Review & confirm (\d+) fields$').firstMatch(value);
  if (fieldsReview != null) return 'Проверить и подтвердить полей: ${fieldsReview[1]}';
  final date = RegExp(r'^Date: (.*)$').firstMatch(value);
  if (date != null) return 'Дата: ${date[1]}';
  final observationReviewed = RegExp(r'^Observation marked reviewed\. Reopen the inspector to confirm it\.$').firstMatch(value);
  if (observationReviewed != null) {
    return 'Наблюдение отмечено как проверенное. Откройте инспектор повторно, чтобы подтвердить его.';
  }
  final importFailure = RegExp(r'^Repository intake import failed: (.*)$').firstMatch(value);
  if (importFailure != null) return 'Не удалось импортировать набор из репозитория: ${_translateKnownError(importFailure[1]!)}';
  final errorLine = RegExp(r'^Error: (.*)$').firstMatch(value);
  if (errorLine != null) return 'Ошибка: ${appLocalizedText(context, errorLine[1]!)}';
  final bundleExported = RegExp(r'^Bundle exported: (.*)$').firstMatch(value);
  if (bundleExported != null) return 'Пакет экспортирован: ${bundleExported[1]}';
  final overlayExported = RegExp(r'^Verified overlay exported: (.*)$').firstMatch(value);
  if (overlayExported != null) return 'Проверенный слой данных экспортирован: ${overlayExported[1]}';
  final noEligibleFields = RegExp(r'^No verified fields are eligible for an overlay yet\.$').firstMatch(value);
  if (noEligibleFields != null) return 'Пока нет проверенных полей, подходящих для слоя данных.';
  final currentPreferredLine = RegExp(r'^Current preferred: (.*)$').firstMatch(value);
  if (currentPreferredLine != null) return 'Текущее предпочтительное значение: ${currentPreferredLine[1]}';
  final sourceStatus = RegExp(r'^Source: (.*) · ([A-Z_]+) · confidence (.*)$').firstMatch(value);
  if (sourceStatus != null) {
    return 'Источник: ${sourceStatus[1]} · ${_ruText[sourceStatus[2]] ?? sourceStatus[2]} · достоверность ${sourceStatus[3]}';
  }
  final newObservation = RegExp(r'^New observation: (.*) · ([A-Z_]+)$').firstMatch(value);
  if (newObservation != null) {
    return 'Новое наблюдение: ${newObservation[1]} · ${_ruText[newObservation[2]] ?? newObservation[2]}';
  }
  final sourceLine = RegExp(r'^Source: (.*)$').firstMatch(value);
  if (sourceLine != null) return 'Источник: ${sourceLine[1]}';
  final gameLine = RegExp(r'^Game (.*)$').firstMatch(value);
  if (gameLine != null) return 'Игра: ${gameLine[1]}';
  final evidenceLine = RegExp(r'^Evidence (.*)$').firstMatch(value);
  if (evidenceLine != null) return 'Свидетельство: ${evidenceLine[1]}';
  final evidenceRecord = RegExp(r'^Evidence record (.*)$').firstMatch(value);
  if (evidenceRecord != null) return 'Запись свидетельства: ${evidenceRecord[1]}';
  final observedLine = RegExp(r'^Observed (.*)$').firstMatch(value);
  if (observedLine != null) return 'Дата наблюдения: ${observedLine[1]}';
  final reviewState = RegExp(r'^Review (.*)$').firstMatch(value);
  if (reviewState != null) return 'Проверка: ${appLocalizedText(context, reviewState[1]!)}';
  final statusMessage = RegExp(r'^Status: (.*)$').firstMatch(value);
  if (statusMessage != null) return 'Статус: ${appLocalizedText(context, statusMessage[1]!)}';
  final validBundle = RegExp(r'^Valid bundle · schema (\S+) · session (\S+) · integrity checks passed\. No data was installed\.$').firstMatch(value);
  if (validBundle != null) return 'Пакет корректен · схема ${validBundle[1]} · сессия ${validBundle[2]} · проверка целостности пройдена. Данные не установлены.';
  final verifiedCandidatePack = RegExp(r'^Verified candidate pack v(\S+) · (\d+) eligible fields$').firstMatch(value);
  if (verifiedCandidatePack != null) return 'Кандидат проверенного набора v${verifiedCandidatePack[1]} · подходящих полей: ${verifiedCandidatePack[2]}';
  final diffCategory = RegExp(r'^(Added|Changed|Conflicts|Removed) \((\d+)\)$').firstMatch(value);
  if (diffCategory != null) {
    final category = _ruText[diffCategory[1]] ?? diffCategory[1]!;
    return '$category (${diffCategory[2]})';
  }
  final conflictCounts = RegExp(r'^(\d+) different values from (\d+) observations$').firstMatch(value);
  if (conflictCounts != null) {
    return 'Разных значений: ${conflictCounts[1]} · наблюдений: ${conflictCounts[2]}';
  }
  final noMultiplier = RegExp(r'^(.+) multiplier has no resolved value$').firstMatch(value);
  if (noMultiplier != null) return 'Для руды ${noMultiplier[1]} не найдено разрешённое значение множителя';
  final candidateField = RegExp(r'^(.+) ([a-z_]+) is a candidate value without in-game evidence$').firstMatch(value);
  if (candidateField != null) {
    return '${candidateField[1]} · ${_ruText[candidateField[2]] ?? candidateField[2]} — предварительное значение без игрового свидетельства';
  }
  final unknownField = RegExp(r'^(.+) ([a-z_]+) is not established in this pack$').firstMatch(value);
  if (unknownField != null) {
    return '${unknownField[1]} · ${_ruText[unknownField[2]] ?? unknownField[2]} не определено в этом наборе данных';
  }
  final unknownTraitField = RegExp(r'^(.+) · (.+) (activation threshold|full activation threshold|proc chance|damage multiplier|flat damage|duration|cooldown|radius|trigger|stat modifier) is not established$').firstMatch(value);
  if (unknownTraitField != null) {
    final field = _ruText[unknownTraitField[3]] ?? unknownTraitField[3]!;
    return '${unknownTraitField[1]} · ${unknownTraitField[2]}: поле «$field» не определено';
  }
  final probabilitySum = RegExp(r'^Source probability sum ([^;]+); (.*)$').firstMatch(value);
  if (probabilitySum != null) return 'Исходная сумма вероятностей: ${probabilitySum[1]}; ${probabilitySum[2]}';
  final tableProbability = RegExp(r'^(.+) · raw sum ([^;]+); source status ([^.]+)\. ?(.*)$').firstMatch(value);
  if (tableProbability != null) {
    final suffix = tableProbability[4]!.isEmpty ? '' : ' ${tableProbability[4]}';
    return '${tableProbability[1]} · исходная сумма ${tableProbability[2]}; статус источника ${appLocalizedText(context, tableProbability[3]!)}.$suffix';
  }
  final verifiedStale = RegExp(r'^Verified for (.*) at (.*); current session context is (.*)\. Original observation is preserved\.$').firstMatch(value);
  if (verifiedStale != null) {
    return 'Проверено для версии ${verifiedStale[1]} от ${verifiedStale[2]}; текущий контекст сессии — ${verifiedStale[3]}. Исходное наблюдение сохранено.';
  }
  final superseded = RegExp(r'^A current in-game verified value supersedes older alternatives; all (\d+) observations remain in history\.$').firstMatch(value);
  if (superseded != null) return 'Текущее значение, проверенное в игре, заменяет старые варианты; все наблюдения (${superseded[1]}) сохранены в истории.';
  final observationReviewLine = RegExp(r'^Review (ENTERED|REVIEWED|USER_CONFIRMED_CAPTURE|IN_GAME_VERIFIED|REJECTED)$').firstMatch(value);
  if (observationReviewLine != null) {
    final state = switch (observationReviewLine[1]) {
      'ENTERED' => 'введено',
      'REVIEWED' => 'проверено',
      'USER_CONFIRMED_CAPTURE' => 'снимок подтверждён пользователем',
      'IN_GAME_VERIFIED' => 'проверено в игре',
      'REJECTED' => 'отклонено',
      _ => observationReviewLine[1]!,
    };
    return 'Проверка: $state';
  }
  final queueState = RegExp(r'^(.+) · (Conflict · )?(Unreviewed|Needs confirmation|Confirmed capture|Game verified|Rejected)$').firstMatch(value);
  if (queueState != null) {
    final conflict = queueState[2] == null ? '' : 'Конфликт · ';
    final status = _ruText[queueState[3]] ?? queueState[3]!;
    return '${queueState[1]} · $conflict$status';
  }
  final sessionLabel = RegExp(r'^(.*) · (Ore|Weapon|Trait|Probability|Craft Result) · (.*)$').firstMatch(value);
  if (sessionLabel != null) {
    return '${sessionLabel[1]} · ${_ruText[sessionLabel[2]] ?? sessionLabel[2]} · ${sessionLabel[3]}';
  }
  final entityField = RegExp(r'^([A-Z_]+) · (.+) · ([a-z_]+)$').firstMatch(value);
  if (entityField != null) {
    return '${_ruText[entityField[1]] ?? entityField[1]} · ${entityField[2]} · ${_ruText[entityField[3]] ?? entityField[3]}';
  }
  final entityId = RegExp(r'^([A-Z_]+) · (.+)$').firstMatch(value);
  if (entityId != null) return '${_ruText[entityId[1]] ?? entityId[1]} · ${entityId[2]}';
  final valueAndStatus = RegExp(r'^(.*?)(\s+·\s+)(IN_GAME_VERIFIED|USER_CONFIRMED_CAPTURE|REVIEWED|ENTERED|REJECTED|COMMUNITY|GUIDE_BASED|OUTDATED|CONFLICTING|UNKNOWN)$').firstMatch(value);
  if (valueAndStatus != null) {
    final translatedStatus = _ruText[valueAndStatus[3]] ?? valueAndStatus[3]!;
    return '${valueAndStatus[1]} · $translatedStatus';
  }
  final evidenceLabel = RegExp(r'^evidence (.*)$').firstMatch(value);
  if (evidenceLabel != null) return 'свидетельство ${evidenceLabel[1]}';
  final difference = RegExp(r'^Difference: (.*)$').firstMatch(value);
  if (difference != null) return 'Разница: ${_ruText[difference[1]] ?? difference[1]}';
  final rawError = _translateKnownError(value);
  if (rawError != value) return rawError;
  return value;
}

String _translateKnownError(String value) {
  final message = value
      .replaceFirst(RegExp(r'^(?:HttpException|FormatException|SocketException):\s*'), '')
      .trim();
  const errors = <String, String>{
    'GitHub rate limit reached. Wait a little and check for updates again.': 'GitHub ограничил частоту запросов. Подождите и проверьте обновления снова.',
    'GitHub returned an invalid releases list.': 'GitHub вернул некорректный список релизов.',
    'This build has no comparable release version. Install an official alpha build before checking for updates.': 'У этой сборки нет версии для сравнения. Установите официальную alpha-сборку перед проверкой обновлений.',
    'The downloaded update failed its SHA-256 check.': 'Контрольная сумма SHA-256 скачанного обновления не совпала.',
    'A newer alpha release exists, but its Windows portable assets are missing or failed integrity validation. The current installation was not changed.': 'Найдена более новая alpha-сборка, но её portable-файлы Windows отсутствуют или не прошли проверку целостности. Текущая установка не изменена.',
    'The archive is missing Flutter assets and is not a complete Windows portable build.': 'В архиве отсутствуют Flutter-ресурсы; это не полная portable-сборка Windows.',
    'The update ZIP contains a path traversal entry.': 'ZIP-архив обновления содержит путь за пределы папки распаковки.',
    'The update is missing BUILD_INFO.txt.': 'В обновлении отсутствует файл BUILD_INFO.txt.',
    'The application folder is not writable. Extract the portable build to a folder you own and try again.': 'Нет прав на запись в папку приложения. Распакуйте portable-сборку в доступную вам папку и повторите попытку.',
    'Image data is invalid or unsupported': 'Изображение повреждено или имеет неподдерживаемый формат.',
    'Original screenshot is missing or its checksum is invalid': 'Исходный снимок отсутствует или его контрольная сумма неверна.',
    'Original screenshot cannot be decoded': 'Не удалось прочитать исходный снимок.',
    'Verification session not found': 'Сессия проверки не найдена.',
    'The GitHub asset has no valid SHA-256 digest.': 'У файла GitHub нет корректной контрольной суммы SHA-256.',
    'The GitHub release or asset was not found.': 'Релиз или файл обновления GitHub не найден.',
    'The archive does not contain the data pack named in its release manifest.': 'В архиве нет набора данных, указанного в манифесте релиза.',
    'The bundled data pack version does not match the release manifest.': 'Версия встроенного набора данных не совпадает с манифестом релиза.',
    'BUILD_INFO.txt does not match the selected release, commit and data pack.': 'Данные BUILD_INFO.txt не совпадают с выбранным релизом, коммитом и набором данных.',
    'The update ZIP contains an unsafe path.': 'ZIP-архив обновления содержит небезопасный путь.',
    'Downloaded file size does not match the GitHub release.': 'Размер скачанного файла не совпадает с размером файла в релизе GitHub.',
    'The application folder is not writable.': 'Нет прав на запись в папку приложения.',
    'This image is already stored as': 'Это изображение уже сохранено под именем',
  };
  return errors[message] ?? value;
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
  'Forge': 'Кузница',
  'Optimizer': 'Оптимизатор',
  'Compare': 'Сравнение',
  'Verification': 'Проверка',
  'Data status': 'Состояние данных',
  'Wiki review': 'Проверка вики',
  'Settings': 'Настройки',
  'WORKSPACE': 'РАБОЧАЯ ОБЛАСТЬ',
  'DATA TOOLS': 'ИНСТРУМЕНТЫ ДАННЫХ',
  'DATA / RESEARCH': 'ДАННЫЕ / ВИКИ',
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
  'Browse ores': 'Просмотреть руды',
  'Ore entries in catalog': 'Руд в каталоге',
  'Saved test recipes': 'Сохранённые тестовые рецепты',
  'ready to compare': 'можно сравнить',
  'recipe': 'рецепт',
  'recipes': 'рецептов',
  'Verified coverage': 'Проверено в игре',
  'known fields': 'из известных полей',
  'data items need attention': 'элементов данных требуют внимания',
  'Review conflicts and pending captures in Data Health.': 'Проверьте конфликты и ожидающие снимки в разделе «Состояние данных».',
  'Your workspace': 'Рабочая область',
  'Data stays on this device. Community values remain attributed and unverified.': 'Данные остаются на этом устройстве. У значений сообщества сохранён источник; они не считаются проверенными.',
  'Configure and inspect a recipe': 'Настроить и проверить рецепт',
  'Review catalog values and sources': 'Проверить значения и источники каталога',
  'Review saved recipes side by side': 'Сравнить сохранённые рецепты',
  'Ruleset': 'Набор правил',
  'Find an ore': 'Найти руду',
  'Sort by': 'Сортировка',
  'All': 'Все',
  'Common': 'Обычная',
  'Uncommon': 'Необычная',
  'Rare': 'Редкая',
  'Epic': 'Эпическая',
  'Legendary': 'Легендарная',
  'Mythic': 'Мифическая',
  'Name': 'Название',
  'Quantity': 'Количество',
  'Multiplier unknown': 'Множитель неизвестен',
  'Forge calculator': 'Расчёт ковки',
  'Build and compare hypothetical mixes from the full ore catalog.': 'Собирайте и сравнивайте гипотетические смеси из полного каталога руд.',
  'Best available': 'Все доступные данные',
  'Verified preferred': 'Проверенные в приоритете',
  'Verified only': 'Только проверенные',
  'Recipe and calculation snapshot saved.': 'Рецепт и снимок расчёта сохранены.',
  'CALCULATION': 'РАСЧЁТ',
  'COMPOSITION': 'СОСТАВ',
  'Choose ores to see the mix.': 'Выберите руды, чтобы увидеть состав смеси.',
  'TRAIT BREAKDOWN': 'РАСПРЕДЕЛЕНИЕ ЭФФЕКТОВ',
  'Effect parameters unknown': 'Параметры эффекта неизвестны',
  'No field observations recorded. Pack-level candidate values are shown with their source status.': 'Наблюдений по полям нет. Показаны предварительные значения из набора данных с их статусом источника.',
  'Close': 'Закрыть',
  'Max raw DPS': 'Максимальный базовый урон в секунду',
  'Max expected DPS': 'Максимальный ожидаемый урон в секунду',
  'No rankable recipes. Add source-aware multiplier candidates in Ores; DPS objectives also require verified weapon and effect inputs.': 'Нет рецептов для ранжирования. Добавьте значения множителей с источниками в разделе «Руды». Для расчёта урона нужны проверенные данные оружия и эффектов.',
  'Why this result': 'Почему получен такой результат',
  'Save calculation snapshot': 'Сохранить снимок расчёта',
  'Calculation snapshot saved': 'Снимок расчёта сохранён',
  'Source': 'Источник',
  'Edit': 'Изменить',
  'Cancel': 'Отмена',
  'Save': 'Сохранить',
  'Confirm': 'Подтвердить',
  'Language': 'Язык',
  'Русский': 'Русский',
  'Planned after the first working version.': 'Запланировано после первой рабочей версии.',
  'This section will use the same source tracking and verification rules as the current data layer.': 'В этом разделе будут действовать те же правила отслеживания источников и проверки данных.',
  'CALCULATION-CRITICAL VERIFIED COVERAGE': 'ПРОВЕРЕННЫЕ ДАННЫЕ, ВАЖНЫЕ ДЛЯ РАСЧЁТОВ',
  'IN-GAME VERIFIED OBSERVATIONS': 'НАБЛЮДЕНИЯ, ПРОВЕРЕННЫЕ В ИГРЕ',
  'ACTIVE DATA': 'АКТИВНЫЕ ДАННЫЕ',
  'All issues': 'Все проблемы',
  'Enter or search': 'Введите запрос или найдите',
  'Bundle exported:': 'Пакет экспортирован:',
  'Bundle validation failed:': 'Не удалось проверить пакет:',
  'Review': 'Проверка',
  'Objective': 'Цель',
  'Game version / update context': 'Версия игры / контекст обновления',
  'Official game version / update (optional)': 'Официальная версия игры / обновление (необязательно)',
  'World / location (optional)': 'Мир / локация (необязательно)',
  'Check type': 'Тип проверки',
  'Crop label': 'Название фрагмента',
  'Trait scaling hypothesis': 'Гипотеза масштабирования эффекта',
  'Qty': 'Кол-во',
  'Inspect multiplier sources': 'Посмотреть источники множителя',
  'Edit values': 'Изменить значения',
  'Confirm only if the screenshot supports every listed field. This action marks this card IN_GAME_VERIFIED; an official update number is optional.': 'Подтверждайте только те поля, которые видны на снимке. Карточка получит статус IN_GAME_VERIFIED; официальный номер обновления необязателен.',
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
  'community only': 'только сообщество',
  'entered': 'введено',
  'reviewed': 'проверено',
  'user confirmed capture': 'снимок подтверждён пользователем',
  'in game verified': 'проверено в игре',
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
  'Resolved': 'Разрешено',
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
  'Check for updates': 'Проверить обновления',
  'Install update': 'Установить обновление',
  'This installation folder is not writable.': 'Нет прав на запись в папку приложения.',
  'Downloading update…': 'Скачиваем обновление…',
  'Preparing update…': 'Подготавливаем обновление…',
  'The Forge\nCompanion': 'The Forge\nCompanion',
  'Entry is saved as a candidate. IN_GAME_VERIFIED requires review, game context and evidence.': 'Запись сохранена как кандидат. Для статуса IN_GAME_VERIFIED нужны проверка, игровой контекст и свидетельство.',
  'Confirm as IN_GAME_VERIFIED': 'Подтвердить статус IN_GAME_VERIFIED',
  'No verified fields are eligible for an overlay yet.': 'Пока нет проверенных полей, подходящих для слоя данных.',
  'No ores match': 'Руды не найдены',
  'Try another search or clear the rarity filter.': 'Измените запрос или сбросьте фильтр редкости.',
  'Available for test recipes': 'доступны для тестовых рецептов',
  'Total ores:': 'Всего руды:',
  'Up to 4 ore types': 'До 4 видов руды',
  'Test recipe': 'Тестовый рецепт',
  'Select any catalog ores and set hypothetical amounts.': 'Выберите руды из каталога и задайте предполагаемое количество.',
  'Current recipe': 'Текущий рецепт',
  'Select up to four ore types and set each amount.': 'Выберите до четырёх видов руды и укажите количество каждого.',
  'Select ore': 'Выберите руду',
  'Recipe name': 'Название рецепта',
  'DATA POLICY': 'ПОЛИТИКА ДАННЫХ',
  'Unknown / no curve': 'Неизвестно / нет кривой',
  'Linear 10% → 30%': 'Линейная 10% → 30%',
  'Alternate code formula': 'Альтернативная формула кода',
  'Save scenario': 'Сохранить сценарий',
  'Scenario saved.': 'Сценарий сохранён.',
  'No weapon selected': 'Оружие не выбрано',
  'Select weapon': 'Выбрать оружие',
  'Weapon stats source': 'Источник характеристик оружия',
  'Manual scenario': 'Ручной сценарий',
  'Scenario base damage': 'Базовый урон сценария',
  'Attack interval (s)': 'Интервал атаки (с)',
  'Variant probabilities, base weapon stats, critical contribution, proc effects, craft quality and sell value remain unknown unless you enter or verify their inputs. Scenario DPS is not a game prediction.': 'Вероятности вариантов, базовые характеристики оружия, критический урон, эффекты срабатывания, качество ковки и цена продажи остаются неизвестными, пока вы не введёте или не проверите эти данные. Урон в секунду в сценарии не является игровым прогнозом.',
  'Multiple values are retained. Choosing a preferred observation does not remove the conflict history.': 'Все значения сохраняются. Выбор предпочтительного наблюдения не удаляет историю конфликта.',
  'Build optimizer': 'Оптимизатор рецептов',
  'Ranks hypothetical ore mixes using values in the catalog.': 'Ранжирует предполагаемые смеси руд по значениям каталога.',
  'Ranked recipes': 'Рецепты по рейтингу',
  'Hypothetical mixes from the ore catalog.': 'Предполагаемые смеси из каталога руд.',
  'Max selected effects': 'Максимум выбранных эффектов',
  'Required ore IDs': 'Обязательные ID руд',
  'Forbidden ore IDs': 'Исключённые ID руд',
  'Effect tags': 'Теги эффектов',
  'Min ores': 'Минимум руды',
  'Max ores': 'Максимум руды',
  'tin, quartz': 'tin, quartz',
  'burn, defense': 'burn, defense',
  'Max multiplier': 'Максимальный множитель',
  'Probability confidence': 'Достоверность вероятностей',
  'not used for ranking.': 'не используется при ранжировании.',
  'Compare builds': 'Сравнение рецептов',
  'See recipe composition, multipliers, and what the current data cannot establish.': 'Сравнивайте состав рецептов и множители, а также ограничения текущих данных.',
  'Build and save a recipe in Forge to compare it here.': 'Создайте и сохраните рецепт в кузнице, чтобы сравнить его здесь.',
  'Saved recipes': 'Сохранённые рецепты',
  'Choose up to four recipes to compare.': 'Выберите до четырёх рецептов для сравнения.',
  'Delete saved recipe': 'Удалить сохранённый рецепт',
  'Empty recipe': 'Пустой рецепт',
  'Damage': 'Урон',
  'Attack speed / interval': 'Скорость атаки / интервал',
  'Raw / expected DPS': 'Базовый / ожидаемый урон в секунду',
  'Known traits': 'Известные эффекты',
  'Ore multiplier': 'Множитель руды',
  'Trait ·': 'Эффект ·',
  'Source ·': 'Источник ·',
  'Ore database': 'Каталог руд',
  'Edit a value with its source. An unverified manual value stays marked UNKNOWN.': 'Изменяйте значение вместе с его источником. Непроверенное вручную значение останется со статусом UNKNOWN.',
  'Search ore database': 'Поиск по каталогу руд',
  'No ores found': 'Руды не найдены',
  'Try a shorter name or another search.': 'Попробуйте сократить запрос или изменить его.',
  'Price unknown': 'Цена неизвестна',
  'Ore price': 'Цена руды',
  'Source name': 'Название источника',
  'Source type': 'Тип источника',
  'Observed date (YYYY-MM-DD)': 'Дата наблюдения (ГГГГ-ММ-ДД)',
  'Game version/update context': 'Версия игры / контекст обновления',
  'Evidence reference / URL': 'Ссылка на свидетельство / URL',
  'Evidence type': 'Тип свидетельства',
  'Notes': 'Заметки',
  'Conflicting observations remain preserved. This value needs in-game verification.': 'Конфликтующие наблюдения сохранены. Это значение нужно проверить в игре.',
  'CURRENT PREFERRED SOURCE': 'ТЕКУЩИЙ ПРЕДПОЧТИТЕЛЬНЫЙ ИСТОЧНИК',
  'ALTERNATIVE OBSERVATIONS': 'АЛЬТЕРНАТИВНЫЕ НАБЛЮДЕНИЯ',
  'No observations are recorded for this field.': 'Для этого поля нет сохранённых наблюдений.',
  'Set this observation as preferred': 'Сделать это наблюдение предпочтительным',
  'Mark reviewed': 'Отметить как проверенное',
  'Confirm from in-game evidence': 'Подтвердить по игровому свидетельству',
  'Observation marked reviewed. Reopen the inspector to confirm it.': 'Наблюдение отмечено как проверенное. Откройте инспектор повторно, чтобы подтвердить его.',
  'The latest portable Windows build from the official project GitHub releases can be checked here.': 'Здесь можно проверить последнюю portable-сборку Windows в официальных релизах проекта на GitHub.',
  'No saved recipes yet': 'Сохранённых рецептов пока нет',
  'Data confidence': 'Достоверность данных',
  'ore types': 'видов руды',
  'Delete': 'Удалить',
  'Add target to session': 'Добавить цель в сессию',
  'Date:': 'Дата:',
  'Choose': 'Выбрать',
  'Create': 'Создать',
  'Save changes': 'Сохранить изменения',
  'New verification session': 'Новая сессия проверки',
  'Edit verification session': 'Изменить сессию проверки',
  'Save crop': 'Сохранить фрагмент',
  'Entity type': 'Тип сущности',
  'Entity id / name': 'ID / название сущности',
  'Field': 'Поле',
  'Value': 'Значение',
  'Evidence crop / screenshot': 'Фрагмент свидетельства / снимок',
  'Manual extraction': 'Ручное извлечение данных',
  'Community examples remain labeled COMMUNITY. Screenshot values enter as ENTERED; confirmation is always explicit.': 'Данные сообщества сохраняют статус COMMUNITY. Значения со снимков получают статус ENTERED; подтверждение выполняется отдельно.',
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
  'Confirm card and verify fields': 'Подтвердить карточку и проверить поля',
  'Session queue': 'Очередь сессии',
  'Priority targets': 'Приоритетные цели',
  'Import a PNG, JPG or WebP screenshot': 'Импортируйте снимок экрана PNG, JPG или WebP',
  'Evidence file is missing': 'Файл свидетельства не найден',
  'New session': 'Новая сессия',
  'Export ZIP': 'Экспортировать ZIP',
  'Edit session': 'Изменить сессию',
  'Validate ZIP': 'Проверить ZIP',
  'Import staged intake': 'Импортировать подготовленный набор',
  'Candidate diff': 'Сравнение кандидатов',
  'Export verified overlay': 'Экспортировать проверенный слой данных',
  'Import screenshot': 'Импортировать снимок',
  'Choose screenshot': 'Выбрать снимок',
  'Cancel crop': 'Отменить обрезку',
  'Select crop': 'Выбрать фрагмент',
  'Save crop as evidence': 'Сохранить фрагмент как свидетельство',
  'Review & confirm': 'Проверить и подтвердить',
  'IN_GAME_VERIFIED': 'Проверено в игре',
  'CONFLICTS': 'КОНФЛИКТЫ',
  'UNKNOWN': 'Неизвестно',
  'SUPERSEDED': 'Заменено новым значением',
  'STALE_VERIFIED': 'Проверено для старой версии',
  'CONFLICT': 'Конфликт',
  'Ores': 'Руды',
  'Nothing matches the current filters.': 'По текущим фильтрам ничего не найдено.',
  'Counts cover catalog-critical fields; hidden effect parameters are not inferred from visible screenshots.': 'Считаются критичные для каталога поля; скрытые параметры эффектов не выводятся из видимых снимков.',
  'Source confidence and formula confidence are kept separate. Probability-table diagnostic rows show source sums and are never normalized in storage.': 'Достоверность источника и формулы учитывается отдельно. Диагностика таблиц вероятностей показывает исходные суммы; они не нормализуются при сохранении.',
  'Add to verification session': 'Добавить в сессию проверки',
  'In game manual': 'Вручную внесено из игры',
  'Added': 'Добавлено',
  'Changed': 'Изменено',
  'Removed': 'Удалено',
  'Observed': 'Наблюдалось',
  'Verification status': 'Статус проверки',
  'Application updates': 'Обновления приложения',
  'Storage': 'Хранение данных',
  'Network access': 'Сетевой доступ',
  'Interface language': 'Язык интерфейса',
  'English': 'Английский',
  'Russian': 'Русский',
  'Check the latest portable Windows build from the official project GitHub releases. Installation starts only after confirmation.': 'Проверьте последнюю portable-сборку Windows в официальных релизах проекта на GitHub. Установка начнётся только после подтверждения.',
  'The app does not collect game data. Application updates require your confirmation.': 'Приложение не собирает игровые данные. Обновление устанавливается только после вашего подтверждения.',
  'Ore catalog, recipes, observations, and data source records are stored locally in SQLite.': 'Каталог руд, рецепты, наблюдения и источники данных хранятся локально в SQLite.',
  'Update check failed': 'Не удалось проверить обновления',
  'GitHub rate limit reached. Wait a little and check for updates again.': 'GitHub ограничил частоту запросов. Подождите и проверьте обновления снова.',
  'Loading updates…': 'Проверяем обновления…',
  'Update available': 'Доступно обновление',
  'Download failed': 'Не удалось скачать обновление',
  'Not now': 'Не сейчас',
  'The app will close and reopen to finish installing the update.': 'Приложение закроется и откроется снова после установки обновления.',
  'This portable update is available for Windows builds only.': 'Автообновление этой portable-сборки доступно только в Windows.',
  'Not supported yet': 'Пока не поддерживается',
  'Version': 'Версия',
  'Commit': 'Коммит',
  'Data version': 'Версия данных',
  'Build date (UTC)': 'Дата сборки (UTC)',
  'Changes': 'Изменения',
  'Current build': 'Текущая сборка',
  'New build': 'Новая сборка',
  'Install now': 'Установить сейчас',
  'The downloaded update failed its SHA-256 check.': 'Контрольная сумма SHA-256 скачанного обновления не совпала.',
  'The installation folder is not writable.': 'Нет прав на запись в папку приложения.',
  'Enter non-negative numeric values.': 'Введите неотрицательные числовые значения.',
  'Update check failed:': 'Не удалось проверить обновления:',
  'ISSUE FILTER': 'ФИЛЬТР ПРОБЛЕМ',
  'Drop screenshot here or choose a file': 'Перетащите снимок сюда или выберите файл',
  'No difference': 'Нет различий',
  'Different value': 'Другое значение',
  'Craft Result': 'Результат ковки',
  'manual Transcription': 'ручная расшифровка',
  'web Source': 'веб-источник',
  'dataset Reference': 'ссылка на набор данных',
  'COMMUNITY': 'СООБЩЕСТВО',
  'GUIDE': 'РУКОВОДСТВО',
  'IN_GAME_MANUAL': 'ВРУЧНУЮ ВНЕСЕНО ИЗ ИГРЫ',
  'guide based': 'по руководству',
  'multi source verified': 'подтверждено несколькими источниками',
  'Unknown': 'Неизвестно',
  'unknown': 'неизвестно',
  'community': 'сообщество',
  'official': 'официальный источник',
  'external calculator': 'внешний калькулятор',
  'guide listed': 'указано в руководстве',
  'rejected': 'отклонено',
  'outdated': 'устарело',
  'stale verified': 'проверено для старой версии',
  'conflicting': 'конфликт',
  'invalid': 'некорректно',
  'underflow': 'сумма ниже 100%',
  'overflow': 'сумма выше 100%',
  'All critical inputs': 'Все критичные входные данные',
  'Ore multipliers': 'Множители руд',
  'Weapon stats': 'Характеристики оружия',
  'Trait thresholds': 'Пороги эффектов',
  'Effect parameters': 'Параметры эффектов',
  'activation_threshold': 'порог активации',
  'full_threshold': 'полный порог активации',
  'proc_chance': 'вероятность срабатывания',
  'damage_multiplier': 'множитель урона',
  'flat_damage': 'фиксированный урон',
  'duration_seconds': 'длительность (с)',
  'cooldown_seconds': 'перезарядка (с)',
  'radius': 'радиус',
  'trigger': 'условие срабатывания',
  'stat_modifier': 'модификатор характеристики',
  'base_damage': 'базовый урон',
  'attack_interval': 'интервал атаки',
  'range_value': 'дальность',
  'variant_weight': 'вес варианта',
  'activation threshold': 'порог активации',
  'full activation threshold': 'полный порог активации',
  'proc chance': 'вероятность срабатывания',
  'damage multiplier': 'множитель урона',
  'flat damage': 'фиксированный урон',
  'duration': 'длительность',
  'cooldown': 'перезарядка',
  'stat modifier': 'модификатор характеристики',
  'ORE': 'Руда',
  'WEAPON': 'Оружие',
  'WEAPON_VARIANT': 'Вариант оружия',
  'WEAPON_CLASS': 'Класс оружия',
  'TRAIT': 'Эффект',
  'PROBABILITY': 'Вероятность',
  'PROBABILITY_TABLE': 'Таблица вероятностей',
  'CRAFT_RESULT': 'Результат ковки',
  'multiplier': 'множитель',
  'rarity': 'редкость',
  'price': 'цена',
  'rocks': 'камни',
  'location': 'локация',
  'description': 'описание',
  'displayed_trait': 'отображаемый эффект',
  'attack_interval_seconds': 'интервал атаки (с)',
  'attack_speed': 'скорость атаки',
  'base_chance': 'базовый шанс',
  'manualTranscription': 'ручная расшифровка',
  'webSource': 'веб-источник',
  'datasetReference': 'ссылка на набор данных',
  'screenshot': 'снимок экрана',
  'experiment': 'эксперимент',
  'No session': 'Нет сессии',
  'No data issues here': 'Проблем с данными нет',
  'No update available': 'Обновлений нет',
  'Multiplier': 'Множитель',
  'Create a verification session before importing evidence.': 'Перед импортом свидетельства создайте сессию проверки.',
  'available for test recipes': 'доступны для тестовых рецептов',
  'Manual entry': 'Введено вручную',
  'Manual, not verified in game.': 'Введено вручную, не проверено в игре.',
  'Manual game observation': 'Наблюдение, вручную внесённое из игры',
  'This intake was already imported; no changes made.': 'Этот набор уже импортирован; изменений нет.',
  'The application data directory is unavailable.': 'Папка данных приложения недоступна.',
  'Multiplier source ID': 'ID источника множителя',
  'OFFICIAL': 'ОФИЦИАЛЬНЫЙ',
  'EXTERNAL_CALCULATOR': 'ВНЕШНИЙ КАЛЬКУЛЯТОР',
  'GUIDE_LISTED': 'УКАЗАНО В РУКОВОДСТВЕ',
  'CONFLICTING': 'КОНФЛИКТУЮЩИЕ ДАННЫЕ',
  'ENTERED': 'ВВЕДЕНО',
  'REVIEWED': 'ПРОВЕРЕНО',
  'OUTDATED': 'УСТАРЕЛО',
  'REJECTED': 'ОТКЛОНЕНО',
  'USER_CONFIRMED_CAPTURE': 'СНИМОК ПОДТВЕРЖДЁН',
  'MULTI_SOURCE_VERIFIED': 'ПОДТВЕРЖДЕНО НЕСКОЛЬКИМИ ИСТОЧНИКАМИ',
  'INVALID': 'НЕКОРРЕКТНО',
  'UNDERFLOW': 'СУММА НИЖЕ 100%',
  'OVERFLOW': 'СУММА ВЫШЕ 100%',
  'Dagger variant odds': 'Шансы вариантов кинжала',
  'At least one ore has no multiplier': 'Как минимум у одной руды нет множителя',
  'Estimated from selected values': 'Оценка по выбранным значениям',
  'Expected DPS': 'Ожидаемый урон в секунду',
  'Selected weapon type chance': 'Шанс выбранного типа оружия',
  'Variant weight': 'Вес варианта',
  'Weighted multiplier': 'Средневзвешенный множитель',
  'Alternative community code formula; not verified in game.': 'Альтернативная формула из кода сообщества; не проверена в игре.',
  'Linear from activation to full threshold.': 'Линейный рост от порога срабатывания до полного порога.',
  'Manual scenario input': 'Введено вручную для сценария',
  'Quality formula is not established': 'Формула качества не установлена',
  'Raw DPS': 'Базовый урон в секунду',
  'Repository formula': 'Формула из репозитория',
  'Linear scaling': 'Линейное масштабирование',
  'Attacks per second': 'Атак в секунду',
  'Attack interval': 'Интервал атаки',
  'Craft quality': 'Качество ковки',
  '1 / attack interval': '1 / интервал атаки',
  'Manual scenario inputs': 'Параметры сценария, введённые вручную',
  'not applied': 'не применяется',
  'Compare saved ore recipes for the same craft target.': 'Сравнивайте сохранённые рецепты из руд для одной цели ковки.',
  'Choose craft target': 'Выберите цель ковки',
  'Recipes are compared only within the selected category.': 'Сравниваются только рецепты выбранной категории.',
  'Weapon': 'Оружие',
  'Armor': 'Броня',
  'Unclassified': 'Без категории',
  'Saved recipes without a target': 'Рецепты без указанной цели',
  'Saved recipes for this target': 'Рецепты для этой цели',
  'Choose up to four. Their type is unknown, so these stay separate from Weapon and Armor comparisons.': 'Выберите до четырёх. Тип этих рецептов неизвестен, поэтому они не смешиваются со сравнением оружия и брони.',
  'Choose up to four recipes to compare side by side.': 'Выберите до четырёх рецептов для сравнения.',
  'What is being compared?': 'Что сравнивается?',
  'Each saved recipe stores ore IDs, quantities, and its craft target. Ore values use the Best Available data policy. The multiplier source ID is shown on each card; rarity, price, and trait fields can have separate sources that this summary does not list.': 'В сохранённом рецепте указаны руды, их количество и цель ковки. Значения руд берутся по политике «Все доступные данные». На карточке показан источник множителя; редкость, цена и эффекты могут иметь отдельные источники, которые здесь не перечислены.',
  'These are recipe and ore-data comparisons, not finished-item predictions. Damage, attack speed, armor stats, and DPS are not calculated here.': 'Здесь сравниваются рецепты и данные руд, а не готовые предметы. Урон, скорость атаки, характеристики брони и урон в секунду здесь не рассчитываются.',
  'No recipes in this category': 'В этой категории нет рецептов',
  'All saved recipes have a recorded craft target.': 'Для всех сохранённых рецептов указана цель ковки.',
  'Save a recipe for this target in Forge. Recipes with no target remain under Unclassified.': 'Сохраните рецепт для этой цели в кузнице. Рецепты без цели остаются в категории «Без категории».',
  'CRAFT GOAL': 'ЦЕЛЬ КОВКИ',
  'Weapon type': 'Тип оружия',
  'Stats source (optional)': 'Источник характеристик (необязательно)',
  'Unknown until selected': 'Неизвестно, пока не выбрано',
  'Armor class and defense data: Unknown': 'Класс брони и данные защиты: неизвестны',
  'Hide composition search': 'Скрыть подбор состава',
  'Find ore composition': 'Подобрать состав руд',
  'Suggested ore compositions': 'Предлагаемые составы руд',
  'Ranks available multiplier values only; it does not predict weapon or armor stats.': 'Ранжирует составы только по доступным множителям и не прогнозирует характеристики оружия или брони.',
  'No rankable mixes. Add multiplier values to the catalog first.': 'Нет составов для ранжирования. Сначала добавьте в каталог значения множителей.',
  'Use mix': 'Использовать состав',
  'Unknown for this composition': 'Неизвестно для этого состава',
  'Armor class odds': 'Шанс класса брони',
  'No current verified probability table': 'Нет актуальной проверенной таблицы вероятностей',
  'Armor defense': 'Защита брони',
  'No verified armor stats are available': 'Проверенные характеристики брони отсутствуют',
};
