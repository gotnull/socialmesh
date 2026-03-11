// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get adminProductsActivate => 'Активировать';

  @override
  String get adminProductsActive => 'Активный';

  @override
  String get adminProductsActiveSubtitle => 'Товар виден в магазине';

  @override
  String get adminProductsAddImage => 'Добавить изображение';

  @override
  String get adminProductsAddTitle => 'Добавить товар';

  @override
  String get adminProductsAddTooltip => 'Добавить товар';

  @override
  String get adminProductsAllCategories => 'Все категории';

  @override
  String get adminProductsBasicInfoSection => 'Основная информация';

  @override
  String get adminProductsBatteryHint => 'напр., 4000mAh';

  @override
  String get adminProductsBatteryLabel => 'Ёмкость аккумулятора';

  @override
  String get adminProductsBluetooth => 'Bluetooth';

  @override
  String get adminProductsCategoryLabel => 'Категория *';

  @override
  String get adminProductsCategorySellerSection => 'Категория и продавец';

  @override
  String get adminProductsChipsetHint => 'напр., ESP32-S3';

  @override
  String get adminProductsChipsetLabel => 'Чипсет';

  @override
  String get adminProductsComparePriceHint => 'Исходная цена для распродажи';

  @override
  String get adminProductsComparePriceLabel => 'Цена для сравнения';

  @override
  String get adminProductsCreate => 'Создать товар';

  @override
  String get adminProductsCreated => 'Товар создан';

  @override
  String get adminProductsDeactivate => 'Деактивировать';

  @override
  String get adminProductsDelete => 'Удалить';

  @override
  String get adminProductsDeleteConfirmMessage =>
      'Вы уверены, что хотите безвозвратно удалить этот товар?';

  @override
  String get adminProductsDeleteConfirmTitle => 'Удалить товар';

  @override
  String get adminProductsDeleteMenu => 'Удалить';

  @override
  String adminProductsDeleteMessage(String name) {
    return 'Вы уверены, что хотите безвозвратно удалить «$name»?\n\nЭто действие нельзя отменить.';
  }

  @override
  String get adminProductsDeleteTitle => 'Удалить товар';

  @override
  String get adminProductsDeleteTooltip => 'Удалить';

  @override
  String get adminProductsDeleted => 'Товар удалён';

  @override
  String get adminProductsDeletedSuccess => 'Товар удалён';

  @override
  String get adminProductsDimensionsHint => 'напр., 100x50x25mm';

  @override
  String get adminProductsDimensionsLabel => 'Размеры';

  @override
  String get adminProductsDisplay => 'Дисплей';

  @override
  String get adminProductsEdit => 'Редактировать';

  @override
  String get adminProductsEditTitle => 'Редактировать товар';

  @override
  String adminProductsErrorLoadingSellers(String error) {
    return 'Ошибка загрузки продавцов: $error';
  }

  @override
  String get adminProductsFeatured => 'Рекомендуемый';

  @override
  String get adminProductsFeaturedBadge => 'РЕКОМЕНДУЕМЫЙ';

  @override
  String get adminProductsFeaturedOrderHelper =>
      'Управляет порядком отображения в разделе рекомендуемых';

  @override
  String get adminProductsFeaturedOrderHint =>
      'Меньшие числа отображаются первыми (0 = верхняя позиция)';

  @override
  String get adminProductsFeaturedOrderLabel => 'Порядок в рекомендуемых';

  @override
  String get adminProductsFeaturedSubtitle =>
      'Показывать в разделе рекомендуемых товаров';

  @override
  String get adminProductsFilterTooltip => 'Фильтровать по категории';

  @override
  String get adminProductsFrequencyBandsSection => 'Диапазоны частот';

  @override
  String get adminProductsFullDescHint => 'Подробное описание товара';

  @override
  String get adminProductsFullDescLabel => 'Полное описание *';

  @override
  String get adminProductsGps => 'GPS';

  @override
  String get adminProductsHideInactive => 'Скрыть неактивные';

  @override
  String get adminProductsImageRequired => 'Требуется хотя бы одно изображение';

  @override
  String get adminProductsImageWarning =>
      'Пожалуйста, добавьте хотя бы одно изображение';

  @override
  String get adminProductsImagesSection => 'Изображения товара';

  @override
  String get adminProductsInStock => 'В наличии';

  @override
  String get adminProductsInactiveBadge => 'НЕАКТИВНЫЙ';

  @override
  String get adminProductsInvalid => 'Недействительный';

  @override
  String get adminProductsLoraChipHint => 'напр., SX1262';

  @override
  String get adminProductsLoraChipLabel => 'Чип LoRa';

  @override
  String get adminProductsMainImage => 'Главное';

  @override
  String get adminProductsNameHint => 'напр., T-Beam Supreme';

  @override
  String get adminProductsNameLabel => 'Название товара *';

  @override
  String get adminProductsNotFound => 'Товары не найдены';

  @override
  String get adminProductsPhysicalSpecsSection => 'Физические характеристики';

  @override
  String get adminProductsPriceLabel => 'Цена (USD) *';

  @override
  String get adminProductsPricingSection => 'Ценообразование';

  @override
  String get adminProductsPurchaseLinkSection => 'Ссылка для покупки';

  @override
  String get adminProductsPurchaseUrlLabel => 'URL для покупки';

  @override
  String get adminProductsRequired => 'Обязательно';

  @override
  String get adminProductsSaveChanges => 'Сохранить изменения';

  @override
  String get adminProductsSearchHint => 'Поиск товаров...';

  @override
  String get adminProductsSelectSeller => 'Выберите продавца';

  @override
  String get adminProductsSelectSellerWarning =>
      'Пожалуйста, выберите продавца';

  @override
  String get adminProductsSellerLabel => 'Продавец *';

  @override
  String get adminProductsShortDescHint =>
      'Краткое описание (макс. 150 символов)';

  @override
  String get adminProductsShortDescLabel => 'Краткое описание';

  @override
  String get adminProductsShowInactive => 'Показать неактивные';

  @override
  String get adminProductsStockHint =>
      'Оставьте пустым для неограниченного количества';

  @override
  String get adminProductsStockLabel => 'Количество на складе';

  @override
  String get adminProductsStockSection => 'Запасы и статус';

  @override
  String get adminProductsTagsHint => 'meshtastic, lora, gps (через запятую)';

  @override
  String get adminProductsTagsLabel => 'Теги';

  @override
  String get adminProductsTagsSection => 'Теги';

  @override
  String get adminProductsTechSpecsSection => 'Технические характеристики';

  @override
  String get adminProductsTitle => 'Управление товарами';

  @override
  String get adminProductsUpdated => 'Товар обновлён';

  @override
  String get adminProductsUploading => 'Загрузка...';

  @override
  String get adminProductsVendorUnverifiedSubtitle =>
      'Отметьте, когда поставщик подтвердит точность всех характеристик';

  @override
  String get adminProductsVendorVerificationSection => 'Верификация поставщика';

  @override
  String get adminProductsVendorVerifiedSubtitle =>
      'Характеристики проверены поставщиком';

  @override
  String get adminProductsVendorVerifiedTitle =>
      'Характеристики подтверждены поставщиком';

  @override
  String get adminProductsWeightHint => 'напр., 50g';

  @override
  String get adminProductsWeightLabel => 'Вес';

  @override
  String get adminProductsWifi => 'WiFi';

  @override
  String get adminSellersActivate => 'Активировать';

  @override
  String get adminSellersActive => 'Активный';

  @override
  String get adminSellersActiveSubtitle => 'Продавец виден в магазине';

  @override
  String get adminSellersAddTitle => 'Добавить продавца';

  @override
  String get adminSellersAddTooltip => 'Добавить продавца';

  @override
  String get adminSellersBasicInfoSection => 'Основная информация';

  @override
  String get adminSellersCancel => 'Отмена';

  @override
  String get adminSellersClearDiscount => 'Очистить код скидки';

  @override
  String get adminSellersContactInfoSection => 'Контактная информация';

  @override
  String get adminSellersCountriesHint => 'US, CA, UK, DE (через запятую)';

  @override
  String get adminSellersCountriesLabel => 'Страны';

  @override
  String get adminSellersCreate => 'Создать продавца';

  @override
  String get adminSellersCreated => 'Продавец создан';

  @override
  String get adminSellersDangerZone => 'Опасная зона';

  @override
  String get adminSellersDeactivate => 'Деактивировать';

  @override
  String get adminSellersDeleteConfirm => 'Удалить';

  @override
  String get adminSellersDeleteDescription =>
      'Безвозвратно удалить этого продавца и деактивировать все его товары. Это действие нельзя отменить.';

  @override
  String adminSellersDeleteDialogMessage(String name) {
    return 'Вы уверены, что хотите безвозвратно удалить «$name»?';
  }

  @override
  String get adminSellersDeleteDialogTitle => 'Удалить продавца';

  @override
  String get adminSellersDeletePermanently => 'Удалить продавца навсегда';

  @override
  String adminSellersDeleteProductWarning(int productCount) {
    return 'У этого продавца $productCount товаров. Удаление продавца также удалит все его товары.';
  }

  @override
  String get adminSellersDeleteTitle => 'Удалить продавца';

  @override
  String get adminSellersDeleteTooltip => 'Удалить продавца';

  @override
  String get adminSellersDeleteUndoWarning => 'Это действие нельзя отменить.';

  @override
  String get adminSellersDeleted => 'Продавец удалён';

  @override
  String get adminSellersDescriptionHint => 'Краткое описание продавца';

  @override
  String get adminSellersDescriptionLabel => 'Описание';

  @override
  String get adminSellersDiscountCodeHint => 'напр., MESH10';

  @override
  String get adminSellersDiscountCodeLabel => 'Код скидки';

  @override
  String get adminSellersDiscountDisplayHint =>
      'напр., Скидка 10% для пользователей Socialmesh';

  @override
  String get adminSellersDiscountDisplayLabel => 'Отображаемое название';

  @override
  String get adminSellersDiscountExpired => 'Срок действия кода скидки истёк';

  @override
  String get adminSellersDiscountExpiryLabel =>
      'Дата истечения (необязательно)';

  @override
  String get adminSellersDiscountNoExpiry => 'Без срока действия';

  @override
  String get adminSellersDiscountSection => 'Партнёрский код скидки';

  @override
  String get adminSellersDiscountTermsHint =>
      'напр., Нельзя совмещать с другими акциями';

  @override
  String get adminSellersDiscountTermsLabel => 'Условия и положения';

  @override
  String get adminSellersEdit => 'Редактировать';

  @override
  String get adminSellersEditTitle => 'Редактировать продавца';

  @override
  String get adminSellersEmailHint => 'support@example.com';

  @override
  String get adminSellersEmailLabel => 'Контактный email';

  @override
  String get adminSellersHideInactive => 'Скрыть неактивных';

  @override
  String get adminSellersInactiveBadge => 'НЕАКТИВНЫЙ';

  @override
  String get adminSellersLogoSection => 'Логотип продавца';

  @override
  String get adminSellersNameHint => 'напр., LilyGO, RAK Wireless';

  @override
  String get adminSellersNameLabel => 'Название продавца *';

  @override
  String get adminSellersNotFound => 'Продавцы не найдены';

  @override
  String get adminSellersOfficialPartner => 'Официальный партнёр';

  @override
  String get adminSellersOfficialPartnerSubtitle =>
      'Отображать как официального партнёра Meshtastic';

  @override
  String get adminSellersPartnerBadge => 'ПАРТНЁР';

  @override
  String get adminSellersRemoveLogo => 'Удалить';

  @override
  String get adminSellersSaveChanges => 'Сохранить изменения';

  @override
  String get adminSellersSearchHint => 'Поиск продавцов...';

  @override
  String get adminSellersShippingSection => 'Страны доставки';

  @override
  String get adminSellersShowInactive => 'Показать неактивных';

  @override
  String get adminSellersStatusSection => 'Статус и верификация';

  @override
  String get adminSellersTitle => 'Управление продавцами';

  @override
  String get adminSellersUpdated => 'Продавец обновлён';

  @override
  String get adminSellersUploadLogo => 'Загрузить логотип';

  @override
  String get adminSellersUploading => 'Загрузка...';

  @override
  String get adminSellersVerifiedBadge => 'ПРОВЕРЕННЫЙ';

  @override
  String get adminSellersVerifiedSubtitle => 'Личность продавца подтверждена';

  @override
  String get adminSellersVerifiedToggle => 'Проверенный';

  @override
  String get adminSellersWebsiteLabel => 'URL сайта *';

  @override
  String get aetherDetailAltitude => 'Высота';

  @override
  String get aetherDetailArrival => 'Прибытие';

  @override
  String get aetherDetailCoverageRadius => 'Радиус покрытия';

  @override
  String get aetherDetailDeparture => 'Отправление';

  @override
  String aetherDetailDistanceAway(int distance) {
    return '$distance км';
  }

  @override
  String get aetherDetailFlightDetails => 'Детали рейса';

  @override
  String get aetherDetailGroundSpeed => 'Путевая скорость';

  @override
  String get aetherDetailHeading => 'Курс';

  @override
  String get aetherDetailLivePosition => 'Позиция в реальном времени';

  @override
  String get aetherDetailNode => 'Нода';

  @override
  String get aetherDetailNotes => 'Заметки';

  @override
  String get aetherDetailOperator => 'Оператор';

  @override
  String get aetherDetailPositionUnavailable => 'Данные о позиции недоступны';

  @override
  String get aetherDetailReceptions => 'Приёмы сигнала';

  @override
  String aetherDetailReceptionsValue(int count) {
    return 'Зафиксировано: $count';
  }

  @override
  String get aetherDetailRefreshTooltip => 'Обновить позицию';

  @override
  String get aetherDetailReportButton => 'Я принял этот рейс!';

  @override
  String get aetherDetailReportsError => 'Ошибка загрузки отчётов';

  @override
  String get aetherDetailReportsTitle => 'Отчёты о приёме сигнала';

  @override
  String get aetherDetailShareCopied =>
      'Ссылка на рейс скопирована в буфер обмена';

  @override
  String aetherDetailShareError(String error) {
    return 'Не удалось поделиться рейсом: $error';
  }

  @override
  String get aetherDetailShareTooltip => 'Поделиться рейсом';

  @override
  String get aetherDetailUnknownNode => 'Неизвестная нода';

  @override
  String aetherDetailUpdated(String time) {
    return 'Обновлено $time';
  }

  @override
  String get aetherDuplicateReport => 'Вы уже сообщали об этом рейсе';

  @override
  String get aetherEmptyActionSchedule => 'Запланировать рейс';

  @override
  String get aetherEmptyActiveSubtitle =>
      'Нет нод Meshtastic в воздухе.\nБудьте первым, кто запланирует полёт!';

  @override
  String get aetherEmptyActiveTitle => 'Нет активных рейсов';

  @override
  String get aetherEmptyAllSubtitle =>
      'Рейсов пока нет.\nБудьте первым, кто поделится своим путешествием!';

  @override
  String get aetherEmptyAllTitle => 'Рейсы не найдены';

  @override
  String aetherErrorWithDetails(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get aetherEmptyMyFlightsSubtitle =>
      'Вы ещё не запланировали рейсов.\nНажмите кнопку выше, чтобы добавить!';

  @override
  String get aetherEmptyMyFlightsTitle => 'Нет запланированных рейсов';

  @override
  String aetherEmptySearchSubtitle(String query) {
    return 'Нет результатов для «$query».\nПопробуйте другой запрос.';
  }

  @override
  String get aetherEmptyTagline1 =>
      'Рейсов пока нет.\nБудьте первым, кто поделится воздушным путешествием!';

  @override
  String get aetherEmptyTagline2 =>
      'Отслеживайте ноды Meshtastic на высоте.\nПосмотрите, как далеко достигает ваш сигнал с неба.';

  @override
  String get aetherEmptyTagline3 =>
      'Соревнуйтесь в таблице лидеров.\nКонтакты на наибольшей дальности занимают верхние строчки.';

  @override
  String get aetherEmptyTagline4 =>
      'Запланируйте следующий рейс.\nУкажите аэропорты вылета и прилёта.';

  @override
  String get aetherEmptyTitleKeyword => 'рейсов';

  @override
  String get aetherEmptyTitlePrefix => 'Нет ';

  @override
  String get aetherEmptyTitleSuffix => ' в воздухе';

  @override
  String get aetherEmptyUpcomingSubtitle =>
      'Рейсов пока нет.\nСпланируйте следующий воздушный тест!';

  @override
  String get aetherEmptyUpcomingTitle => 'Нет предстоящих рейсов';

  @override
  String get aetherFilterActive => 'Активные';

  @override
  String get aetherFilterAll => 'Все';

  @override
  String get aetherFilterMyFlights => 'Мои рейсы';

  @override
  String get aetherFilterUpcoming => 'Предстоящие';

  @override
  String get aetherFormEnterFlightNumber => 'Введите номер рейса';

  @override
  String get aetherFormInvalidFlightFormat =>
      'Неверный формат (например, UA123, EXS49MY)';

  @override
  String get aetherFormRequired => 'Обязательное поле';

  @override
  String get aetherFormUnknownAirport => 'Неизвестный аэропорт';

  @override
  String get aetherFormUseLetterCode => 'Используйте код из 3–4 букв';

  @override
  String get aetherInfoGroundStations =>
      'Наземные станции следят за вашим сигналом';

  @override
  String get aetherInfoLoraRange =>
      'На высоте 35 000 футов LoRa может достигать 400+ км!';

  @override
  String get aetherInfoReceptions =>
      'Сообщайте о приёмах и устанавливайте рекорды дальности!';

  @override
  String get aetherInfoSchedule => 'Запланируйте рейс со своей нодой';

  @override
  String get aetherInfoTagline => 'Отслеживайте ноды Meshtastic на высоте!';

  @override
  String get aetherInfoTitle => 'Aether';

  @override
  String get aetherLeaderboardEmpty => 'Таблица лидеров пуста';

  @override
  String get aetherLeaderboardEmptySubtitle =>
      'Будьте первым, кто сообщит о приёме сигнала с воздушной ноды, и займите первое место!';

  @override
  String get aetherLeaderboardError => 'Ошибка загрузки таблицы лидеров';

  @override
  String get aetherLeaderboardErrorSubtitle =>
      'Потяните вниз для обновления и повторите попытку.';

  @override
  String get aetherLeaderboardSubtitle =>
      'Глобальный рейтинг по дальности приёма';

  @override
  String get aetherLeaderboardTitle => 'Таблица лидеров по дальности';

  @override
  String get aetherLeaderboardTooltip => 'Таблица лидеров';

  @override
  String get aetherMatchInFlight => 'В ВОЗДУХЕ';

  @override
  String get aetherMatchReportCta => 'Нажмите, чтобы сообщить о приёме';

  @override
  String get aetherMenuAbout => 'О программе Aether';

  @override
  String get aetherMenuHelp => 'Справка';

  @override
  String get aetherMenuSettings => 'Настройки';

  @override
  String aetherNodeAlreadyHasFlight(
    String nodeName,
    String flightNumber,
    String status,
  ) {
    return '$nodeName уже имеет рейс ($flightNumber — $status)';
  }

  @override
  String get aetherOverlayDetected => 'ОБНАРУЖЕН';

  @override
  String get aetherOverlayReport => 'Сообщить';

  @override
  String aetherPickerAirportCount(int count) {
    return '$count аэропортов';
  }

  @override
  String get aetherPickerArrivalTitle => 'Аэропорт прибытия';

  @override
  String get aetherPickerDepartureTitle => 'Аэропорт отправления';

  @override
  String get aetherPickerManualEntry => 'Вы можете ввести код вручную';

  @override
  String get aetherPickerNoResults => 'Аэропорты не найдены';

  @override
  String aetherPickerResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count результата',
      many: '$count результатов',
      few: '$count результата',
      one: '1 результат',
    );
    return '$_temp0';
  }

  @override
  String get aetherPickerSearchHint => 'Поиск по коду, городу или названию';

  @override
  String get aetherReportAddNotes => 'Добавить заметки';

  @override
  String get aetherReportEstimatedDistance => 'Расчётное расстояние ';

  @override
  String get aetherReportFlightEnded => 'Этот рейс завершён';

  @override
  String get aetherReportLocationDetected =>
      'Местоположение определено автоматически';

  @override
  String get aetherReportLocationUnavailable => 'Местоположение недоступно';

  @override
  String get aetherReportNodeNotDetected =>
      'Нода рейса не обнаружена в вашей mesh-сети';

  @override
  String get aetherReportNotOnMesh =>
      'Нода этого рейса не находится в вашей mesh-сети. Сообщить о приёме можно только тогда, когда нода видна вашему устройству.';

  @override
  String get aetherReportNotesHint =>
      'Оборудование, антенна, описание места...';

  @override
  String get aetherReportNotesLabel => 'Заметки';

  @override
  String get aetherReportRemoveNotes => 'Удалить';

  @override
  String get aetherReportRssiLabel => 'RSSI ';

  @override
  String get aetherReportSnrLabel => 'SNR ';

  @override
  String get aetherReportSubmit => 'Отправить отчёт';

  @override
  String aetherReportSubtitle(String flightNumber) {
    return 'Я принял рейс $flightNumber на своей ноде!';
  }

  @override
  String get aetherReportSuccess => 'Приём сигнала зафиксирован!';

  @override
  String get aetherReportTitle => 'Сообщить о приёме';

  @override
  String get aetherScheduleAlreadyValidatedTooltip => 'Уже подтверждён';

  @override
  String get aetherScheduleArrivalBeforeDeparture =>
      'Время прибытия должно быть позже времени отправления';

  @override
  String get aetherScheduleArrivalDateTitle => 'Дата прибытия';

  @override
  String get aetherScheduleArrivalTimeTitle => 'Время прибытия';

  @override
  String get aetherScheduleBrowseTooltip => 'Просмотр аэропортов';

  @override
  String get aetherScheduleButton => 'Запланировать рейс';

  @override
  String get aetherScheduleConnectDevice =>
      'Сначала подключите устройство Meshtastic';

  @override
  String get aetherScheduleConnectToSchedule =>
      'Подключитесь, чтобы запланировать рейс';

  @override
  String get aetherScheduleDateLabel => 'Дата';

  @override
  String get aetherScheduleDepartureDateTitle => 'Дата отправления';

  @override
  String get aetherScheduleDepartureInPast => 'Время отправления в прошлом';

  @override
  String get aetherScheduleDepartureTimeTitle => 'Время отправления';

  @override
  String get aetherScheduleDepartureTooFar =>
      'Отправление не может быть позже чем через год';

  @override
  String aetherScheduleDurationTooLong(int hours, int minutes) {
    return 'Продолжительность рейса превышает 24 часа ($hoursч $minutesм)';
  }

  @override
  String get aetherScheduleDurationTooShort =>
      'Продолжительность рейса должна быть не менее 5 минут';

  @override
  String aetherScheduleError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get aetherScheduleFlightNumberHint => 'UA123';

  @override
  String get aetherScheduleFlightNumberLabel => 'Номер рейса';

  @override
  String get aetherScheduleFlightOnGround => 'Рейс в настоящее время на земле';

  @override
  String aetherScheduleFlightSelectedAlt(int altitude) {
    return 'Рейс выбран! $altitude фут.';
  }

  @override
  String get aetherScheduleFlightTooltip => 'Запланировать рейс';

  @override
  String get aetherScheduleFromHint => 'LAX';

  @override
  String get aetherScheduleFromLabel => 'Откуда';

  @override
  String aetherScheduleIncompleteMessage(String fields) {
    return 'Не удалось автоматически заполнить поля $fields из OpenSky Network. Введите эти данные вручную ниже.';
  }

  @override
  String get aetherScheduleIncompleteTitle => 'Неполные данные рейса';

  @override
  String get aetherScheduleIntroBanner =>
      'Запланируйте рейс и поделитесь им на aether.socialmesh.app, чтобы сообщество могло попытаться принять ваш сигнал!';

  @override
  String get aetherScheduleLoadingFlights =>
      'Загрузка рейсов, попробуйте ещё раз';

  @override
  String get aetherScheduleNoDeviceConnected => 'Устройство не подключено';

  @override
  String aetherScheduleNodeHasActiveFlight(
    String nodeName,
    String flightNumber,
  ) {
    return '$nodeName уже имеет активный рейс ($flightNumber)';
  }

  @override
  String get aetherScheduleNotesHint =>
      'Место у окна, левая сторона. Мощность 20 дБм.';

  @override
  String get aetherScheduleNotesLabel => 'Заметки';

  @override
  String get aetherScheduleResponsibilityTooltip => 'Ваша ответственность';

  @override
  String aetherScheduleRouteExceedsRange(int distance) {
    return '$distance — превышает максимальную дальность воздушного судна';
  }

  @override
  String aetherScheduleRouteFound(String route) {
    return 'Маршрут найден: $route';
  }

  @override
  String get aetherScheduleRouteSameAirport => 'Одинаковый аэропорт';

  @override
  String aetherScheduleRouteTooClose(
    String departure,
    String arrival,
    int distance,
  ) {
    return '$departure и $arrival находятся на расстоянии $distance км — слишком близко для коммерческого рейса';
  }

  @override
  String get aetherScheduleSameAirport =>
      'Аэропорты отправления и прибытия не могут совпадать';

  @override
  String get aetherScheduleSearchButton => 'Найти';

  @override
  String get aetherScheduleSearchTooltip => 'Поиск рейсов';

  @override
  String get aetherScheduleSectionArrival => 'Время прибытия (необязательно)';

  @override
  String get aetherScheduleSectionDeparture => 'Время отправления';

  @override
  String get aetherScheduleSectionFlight => 'Информация о рейсе';

  @override
  String get aetherScheduleSectionNotes =>
      'Дополнительные заметки (необязательно)';

  @override
  String get aetherScheduleSelect => 'Выбрать';

  @override
  String get aetherScheduleSelectDepartureTime =>
      'Выберите дату и время отправления';

  @override
  String get aetherScheduleSignInRequired =>
      'Войдите, чтобы запланировать рейс';

  @override
  String get aetherScheduleSuccessInFlight => 'Рейс в воздухе!';

  @override
  String get aetherScheduleSuccessScheduled => 'Рейс запланирован!';

  @override
  String get aetherScheduleSwapTooltip => 'Поменять аэропорты местами';

  @override
  String get aetherScheduleTimeLabel => 'Время';

  @override
  String get aetherScheduleTip1 => 'По возможности занимайте место у окна';

  @override
  String get aetherScheduleTip2 => 'Держите ноду рядом с окном во время полёта';

  @override
  String get aetherScheduleTip3 => 'Чем выше мощность TX, тем больше дальность';

  @override
  String get aetherScheduleTip4 => 'Сообщите другим свою частоту/регион';

  @override
  String get aetherScheduleTipsTitle => 'Советы для лучшего приёма';

  @override
  String get aetherScheduleTitle => 'Запланировать рейс';

  @override
  String get aetherScheduleToHint => 'JFK';

  @override
  String get aetherScheduleToLabel => 'Куда';

  @override
  String aetherScheduleTooClose(
    String departure,
    String arrival,
    int distance,
  ) {
    return '$departure и $arrival находятся всего в $distance км — коммерческих маршрутов нет';
  }

  @override
  String aetherScheduleTooFar(String departure, String arrival, int distance) {
    return '$departure — $arrival: $distance — превышает максимальную дальность воздушного судна';
  }

  @override
  String get aetherScheduleValidateFlightTooltip => 'Проверить рейс';

  @override
  String get aetherScreenTitle => 'Aether';

  @override
  String get aetherSearchEmptySubtitle =>
      'Попробуйте другой номер рейса или проверьте,\nнаходится ли рейс в воздухе';

  @override
  String get aetherSearchEmptyTitle => 'Активных рейсов не найдено';

  @override
  String get aetherSearchError => 'Ошибка поиска. Повторите попытку.';

  @override
  String get aetherSearchFlightNumberHint => 'Номер рейса (например, UA123)';

  @override
  String get aetherSearchHint => 'Поиск рейсов, аэропортов, нод...';

  @override
  String get aetherSearchIdleSubtitle =>
      'Введите callsign и нажмите «Найти»,\nчтобы найти рейсы в воздухе';

  @override
  String get aetherSearchIdleTitle => 'Поиск активных рейсов';

  @override
  String get aetherSearchOnGround => 'На земле';

  @override
  String get aetherSearchRetry => 'Повторить';

  @override
  String aetherSearchRouteFrom(String airport) {
    return 'Из $airport · В пути';
  }

  @override
  String aetherSearchRouteTo(String airport) {
    return 'В $airport';
  }

  @override
  String get aetherSearchTitle => 'Поиск рейсов';

  @override
  String get aetherSearchTooltip => 'Поиск';

  @override
  String aetherShareText(
    Object flightNumber,
    Object departure,
    Object arrival,
    Object url,
  ) {
    return '$flightNumber $departure → $arrival\nОтслеживайте этот Meshtastic-рейс в Aether:\n$url';
  }

  @override
  String get aetherSignInRequired => 'Требуется вход';

  @override
  String get aetherSignInRequiredSubtitle =>
      'Войдите, чтобы просматривать запланированные рейсы и управлять ими.';

  @override
  String get aetherStatsActive => 'Активные';

  @override
  String get aetherStatsRecord => 'Рекорд';

  @override
  String get aetherStatsReports => 'Отчёты';

  @override
  String get aetherStatsScheduled => 'Запланированные';

  @override
  String get aetherStatusCompleted => 'Завершён';

  @override
  String get aetherStatusInFlight => 'В полёте';

  @override
  String get aetherStatusScheduled => 'Запланирован';

  @override
  String get aetherStatusUpcoming => 'Предстоящий';

  @override
  String get aetherValidationActive => 'Рейс в настоящее время активен!';

  @override
  String aetherValidationActiveAlt(int altitude) {
    return 'Рейс в настоящее время активен! $altitude фут.';
  }

  @override
  String get aetherValidationEnterFlightFirst => 'Сначала введите номер рейса';

  @override
  String get aetherValidationFailed => 'Не удалось проверить рейс';

  @override
  String get aetherValidationInvalidFormat => 'Неверный формат номера рейса';

  @override
  String get aetherValidationRateLimited =>
      'Превышен лимит запросов. Повторите через несколько минут.';

  @override
  String get aetherValidationVerified => 'Рейс подтверждён в базе OpenSky';

  @override
  String get ambientLightingBlue => 'Синий';

  @override
  String get ambientLightingBrightness => 'Яркость LED';

  @override
  String get ambientLightingCurrent => 'Ток';

  @override
  String get ambientLightingCurrentSubtitle => 'Ток питания LED (яркость)';

  @override
  String ambientLightingCurrentValue(int milliamps) {
    return '$milliamps мА';
  }

  @override
  String get ambientLightingCustomColor => 'Пользовательский цвет';

  @override
  String get ambientLightingDeviceSupportInfo =>
      'Фоновое освещение доступно только на устройствах с поддержкой LED (RAK WisBlock, T-Beam и др.)';

  @override
  String get ambientLightingGreen => 'Зелёный';

  @override
  String get ambientLightingLedEnabled => 'LED включён';

  @override
  String get ambientLightingLedEnabledSubtitle =>
      'Включить или выключить фоновое освещение';

  @override
  String get ambientLightingPresetColors => 'Готовые цвета';

  @override
  String get ambientLightingRed => 'Красный';

  @override
  String get ambientLightingSave => 'Сохранить';

  @override
  String ambientLightingSaveError(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get ambientLightingSaved => 'Фоновое освещение сохранено';

  @override
  String get ambientLightingTitle => 'Фоновое освещение';

  @override
  String get appTitle => 'Socialmesh';

  @override
  String get arCalibratingSensors => 'Калибровка датчиков...';

  @override
  String get arCalibrationScreenAccuracyImproved => 'Точность компаса улучшена';

  @override
  String get arCalibrationScreenComplete => 'КАЛИБРОВКА ЗАВЕРШЕНА';

  @override
  String get arCalibrationScreenContinue => 'ПЕРЕЙТИ К AR';

  @override
  String get arCalibrationScreenInstructionAlmost =>
      'Почти готово!\nЕщё немного.';

  @override
  String get arCalibrationScreenInstructionIdle =>
      'Двигайте устройство по траектории цифры 8, чтобы откалибровать компас для точной AR-навигации.';

  @override
  String get arCalibrationScreenInstructionMoving =>
      'Продолжайте движение по траектории 8...\nСледуйте за светящейся точкой.';

  @override
  String get arCalibrationScreenInstructionProgress =>
      'Отличный прогресс!\nПродолжайте движение по траектории 8.';

  @override
  String get arCalibrationScreenSkip => 'Пропустить пока';

  @override
  String get arCalibrationScreenStart => 'НАЧАТЬ КАЛИБРОВКУ';

  @override
  String get arCalibrationScreenTitle => 'КАЛИБРОВКА КОМПАСА';

  @override
  String arCouldNotOpenMaps(String name) {
    return 'Не удалось открыть карты для $name';
  }

  @override
  String get arEngineError => 'ОШИБКА AR-ДВИЖКА';

  @override
  String get arInitializingEngine => 'ИНИЦИАЛИЗАЦИЯ AR-ДВИЖКА';

  @override
  String get arNoCamerasAvailable => 'Камеры недоступны';

  @override
  String get arNodeBadgeCritical => 'КРИТИЧНО';

  @override
  String get arNodeBadgeMoving => 'В ДВИЖЕНИИ';

  @override
  String get arNodeBadgeNew => 'НОВЫЙ';

  @override
  String get arNodeBadgeOffline => 'ОФЛАЙН';

  @override
  String get arNodeBadgeWarning => 'ПРЕДУПРЕЖДЕНИЕ';

  @override
  String get arNodeDetailAltitude => 'Высота';

  @override
  String get arNodeDetailBattery => 'Аккумулятор';

  @override
  String get arNodeDetailBearing => 'НАПРАВЛЕНИЕ';

  @override
  String get arNodeDetailDistance => 'РАССТОЯНИЕ';

  @override
  String get arNodeDetailElevation => 'ВЫСОТА НАД УРОВНЕМ МОРЯ';

  @override
  String get arNodeDetailLastHeard => 'Последний сигнал';

  @override
  String get arNodeDetailNavigate => 'Навигация';

  @override
  String get arNodeDetailRssi => 'RSSI';

  @override
  String get arNodeDetailSnr => 'SNR';

  @override
  String get arNodeDetailSpeed => 'Скорость';

  @override
  String get arNodeDetailUnknownNode => 'Неизвестная нода';

  @override
  String get arNodeNoGpsPosition => 'Нода не имеет GPS-координат';

  @override
  String get arRetry => 'ПОВТОРИТЬ';

  @override
  String get arSettingsAlerts => 'Оповещения';

  @override
  String get arSettingsAltimeter => 'Альтиметр';

  @override
  String get arSettingsCompass => 'Компас';

  @override
  String get arSettingsDistanceFilter => 'ФИЛЬТР РАССТОЯНИЯ';

  @override
  String get arSettingsExplorer => 'Исследователь';

  @override
  String get arSettingsFavoritesOnly => 'Только избранные';

  @override
  String get arSettingsHorizon => 'Горизонт';

  @override
  String get arSettingsHudElements => 'ЭЛЕМЕНТЫ HUD';

  @override
  String get arSettingsMaxDistance => 'Макс. расстояние';

  @override
  String get arSettingsMaxDistanceLabel => '100 км';

  @override
  String get arSettingsMinDistanceLabel => '100 м';

  @override
  String get arSettingsMinimal => 'Минимальный';

  @override
  String get arSettingsNodeFilters => 'ФИЛЬТРЫ УЗЛОВ';

  @override
  String get arSettingsShowOfflineNodes => 'Показывать офлайн-ноды';

  @override
  String get arSettingsTactical => 'Расширенный';

  @override
  String get arSettingsViewMode => 'РЕЖИМ ПРОСМОТРА';

  @override
  String get arTouchLocked => 'Касание заблокировано';

  @override
  String get arTouchUnlocked => 'Касание разблокировано';

  @override
  String get arViewModeSelectorExp => 'ИСС';

  @override
  String get arViewModeSelectorMin => 'МИН';

  @override
  String get arViewModeSelectorTac => 'РАС';

  @override
  String get authMfaActiveMethods => 'Активные методы';

  @override
  String get authMfaCancelButton => 'Отмена';

  @override
  String get authMfaChangePhoneNumber => 'Изменить номер телефона';

  @override
  String authMfaCodeSentTo(String phoneNumber) {
    return 'Код подтверждения отправлен на $phoneNumber';
  }

  @override
  String authMfaDateDaysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String authMfaDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяцев назад',
      many: '$count месяцев назад',
      few: '$count месяца назад',
      one: '1 месяц назад',
    );
    return '$_temp0';
  }

  @override
  String get authMfaDateToday => 'сегодня';

  @override
  String authMfaDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count недель назад',
      many: '$count недель назад',
      few: '$count недели назад',
      one: '1 неделю назад',
    );
    return '$_temp0';
  }

  @override
  String get authMfaDateYesterday => 'вчера';

  @override
  String get authMfaEnableButton => 'Включить двухфакторную аутентификацию';

  @override
  String get authMfaEnabled => 'Двухфакторная аутентификация включена';

  @override
  String get authMfaEnrollmentHeading =>
      'Добавьте дополнительный уровень защиты';

  @override
  String get authMfaEnrollmentSubheading =>
      'При входе вы будете получать код подтверждения по SMS';

  @override
  String get authMfaEnrollmentTitle => 'Включить двухфакторную аутентификацию';

  @override
  String authMfaEnterCodeSentTo(String phone) {
    return 'Введите код, отправленный на $phone';
  }

  @override
  String authMfaEnterCodeSentToPhone(String phoneNumber) {
    return 'Введите 6-значный код, отправленный на $phoneNumber';
  }

  @override
  String get authMfaEnterSixDigitCode => 'Введите 6-значный код';

  @override
  String get authMfaEnterSixDigitCodeWarning => 'Введите 6-значный код';

  @override
  String get authMfaErrorAccountExistsDifferentCredential =>
      'Аккаунт с таким адресом электронной почты уже существует, но привязан к другому способу входа. Войдите с помощью исходного метода.';

  @override
  String get authMfaErrorAlreadyEnrolled =>
      'Этот номер телефона уже зарегистрирован для двухфакторной аутентификации.';

  @override
  String get authMfaErrorAppVerificationFailed =>
      'Проверка приложения не удалась. Попробуйте ещё раз.';

  @override
  String get authMfaErrorCancelled => 'Подтверждение отменено.';

  @override
  String get authMfaErrorCodeExpired =>
      'Срок действия кода подтверждения истёк. Запросите новый.';

  @override
  String get authMfaErrorCredentialInUse =>
      'Этот номер телефона уже используется другим аккаунтом.';

  @override
  String get authMfaErrorEmailInUse =>
      'Этот адрес электронной почты уже привязан к другому аккаунту.';

  @override
  String get authMfaErrorGeneric =>
      'Подтверждение не удалось. Попробуйте ещё раз.';

  @override
  String get authMfaErrorInfoNotFound =>
      'Данные двухфакторной аутентификации не найдены. Зарегистрируйте второй фактор повторно.';

  @override
  String get authMfaErrorInternal =>
      'Произошла внутренняя ошибка. Попробуйте ещё раз.';

  @override
  String get authMfaErrorInvalidAppCredential =>
      'Проверка приложения не удалась. Перезапустите приложение и попробуйте снова.';

  @override
  String get authMfaErrorInvalidCertHash =>
      'Проверка подписи приложения не удалась. Возможно, эта сборка неправильно настроена для телефонной аутентификации.';

  @override
  String get authMfaErrorInvalidCode =>
      'Неверный код. Проверьте и попробуйте снова.';

  @override
  String get authMfaErrorInvalidCredential =>
      'Введённый код неверен или устарел. Попробуйте ещё раз.';

  @override
  String get authMfaErrorInvalidData =>
      'Недопустимые данные подтверждения. Запросите новый код.';

  @override
  String get authMfaErrorInvalidPhoneNumber =>
      'Введите корректный номер телефона с кодом страны (например, +7 912 345 67 89).';

  @override
  String get authMfaErrorInvalidTotpCode =>
      'Неверный код из приложения-аутентификатора. Проверьте и попробуйте снова.';

  @override
  String get authMfaErrorMaxFactors =>
      'Достигнуто максимальное количество дополнительных факторов.';

  @override
  String get authMfaErrorMissingAppCredential =>
      'Проверка приложения не настроена. Попробуйте позже.';

  @override
  String get authMfaErrorMissingClientId =>
      'Проверка приложения не удалась. Перезапустите приложение и попробуйте снова.';

  @override
  String get authMfaErrorMissingCode =>
      'Введите код подтверждения, отправленный на ваш телефон.';

  @override
  String get authMfaErrorMissingPhone => 'Введите номер телефона.';

  @override
  String get authMfaErrorMissingTotpCode =>
      'Введите код из приложения-аутентификатора.';

  @override
  String get authMfaErrorNoCurrentUser =>
      'Войдите в систему, чтобы управлять двухфакторной аутентификацией.';

  @override
  String get authMfaErrorNoInternet =>
      'Нет подключения к интернету. Проверьте сеть и попробуйте снова.';

  @override
  String get authMfaErrorPhoneNotEnabled =>
      'Подтверждение по телефону не включено. Обратитесь в поддержку.';

  @override
  String get authMfaErrorProviderAlreadyLinked =>
      'Этот способ входа уже привязан к вашему аккаунту.';

  @override
  String get authMfaErrorQuotaExceeded =>
      'Сервис временно недоступен. Попробуйте позже.';

  @override
  String get authMfaErrorReauthCancelled =>
      'Повторная аутентификация отменена. Попробуйте ещё раз.';

  @override
  String get authMfaErrorReauthFailed =>
      'Повторная аутентификация не удалась. Выйдите из системы, войдите снова и попробуйте ещё раз.';

  @override
  String get authMfaErrorResolveSignInFailed =>
      'Код подтверждения неверен или устарел. Попробуйте ещё раз или запросите новый код.';

  @override
  String get authMfaErrorSecondFactorRequired =>
      'Для завершения входа требуется двухфакторная проверка.';

  @override
  String get authMfaErrorSessionExpired =>
      'Сессия подтверждения истекла. Запросите новый код.';

  @override
  String get authMfaErrorSignInSessionExpired =>
      'Сессия входа истекла. Начните вход заново.';

  @override
  String get authMfaErrorTimeout =>
      'Время ожидания запроса истекло. Попробуйте ещё раз.';

  @override
  String get authMfaErrorTooManyRequests =>
      'Слишком много попыток. Подождите несколько минут и попробуйте снова.';

  @override
  String authMfaErrorUnknown(String errorCode) {
    return 'Подтверждение не удалось (ошибка: $errorCode). Попробуйте ещё раз.';
  }

  @override
  String get authMfaErrorUnsupportedFirstFactor =>
      'Ваш способ входа не поддерживает двухфакторную аутентификацию.';

  @override
  String get authMfaErrorUserDisabled =>
      'Этот аккаунт заблокирован. Обратитесь в поддержку.';

  @override
  String get authMfaErrorVerificationFailed =>
      'Подтверждение по телефону не удалось. Проверьте номер и попробуйте снова.';

  @override
  String get authMfaErrorWrongAccount =>
      'Этот аккаунт не совпадает с тем, в который вы вошли. Попробуйте снова и выберите правильный аккаунт.';

  @override
  String authMfaFactorAdded(String relativeTime) {
    return 'Добавлено $relativeTime';
  }

  @override
  String get authMfaHowItWorks => 'Как это работает';

  @override
  String get authMfaInfoQuickDescription =>
      'Подтверждение занимает всего несколько секунд при входе';

  @override
  String get authMfaInfoQuickTitle => 'Быстро и просто';

  @override
  String get authMfaInfoSecurityDescription =>
      'Защищает ваш аккаунт, даже если пароль скомпрометирован';

  @override
  String get authMfaInfoSecurityTitle => 'Дополнительная защита';

  @override
  String get authMfaInfoSmsDescription =>
      'Получайте код подтверждения по SMS при каждом входе';

  @override
  String get authMfaInfoSmsTitle => 'Подтверждение по SMS';

  @override
  String get authMfaManagementTitle => 'Двухфакторная аутентификация';

  @override
  String get authMfaNoInternetBody =>
      'Управление двухфакторной аутентификацией требует подключения к интернету. Подключитесь и попробуйте снова.';

  @override
  String get authMfaNoInternetTitle => 'Нет подключения к интернету';

  @override
  String get authMfaNoPhoneFactorFound => 'Телефонный фактор не найден';

  @override
  String get authMfaNoVerificationId =>
      'Идентификатор подтверждения отсутствует. Попробуйте отправить код повторно.';

  @override
  String get authMfaNotEnabledDescription =>
      'Добавьте дополнительный уровень защиты';

  @override
  String get authMfaOfflineBanner =>
      'Вы не в сети. Изменения невозможны до восстановления подключения.';

  @override
  String get authMfaPhoneCountryCodeRequired =>
      'Номер телефона должен включать код страны (+7, +1, +44 и т.д.)';

  @override
  String get authMfaPhoneFallback => 'Телефон';

  @override
  String get authMfaPhoneNumberHint => '+7 912 345 67 89';

  @override
  String get authMfaPhoneNumberLabel => 'Номер телефона';

  @override
  String get authMfaPhoneRequired => 'Введите номер телефона';

  @override
  String get authMfaProtectedDescription =>
      'Ваш аккаунт защищён двухфакторной аутентификацией';

  @override
  String get authMfaRemoveConfirmLabel => 'Удалить';

  @override
  String get authMfaRemoveConfirmMessage =>
      'Ваш аккаунт станет менее защищённым. Вы можете включить её снова в любой момент.';

  @override
  String get authMfaRemoveConfirmTitle =>
      'Удалить двухфакторную аутентификацию?';

  @override
  String get authMfaRemoveRequiresInternet =>
      'Для отключения двухфакторной аутентификации требуется подключение к интернету.';

  @override
  String get authMfaRemoved => 'Двухфакторная аутентификация удалена';

  @override
  String get authMfaRequiresInternet =>
      'Двухфакторная аутентификация требует подключения к интернету.';

  @override
  String get authMfaRetryButton => 'Повторить';

  @override
  String get authMfaSendCodeButton => 'Отправить код';

  @override
  String get authMfaSendCodeRequiresInternet =>
      'Для отправки кодов подтверждения требуется подключение к интернету.';

  @override
  String get authMfaSendingButton => 'Отправка...';

  @override
  String get authMfaSendingCode => 'Отправка кода подтверждения...';

  @override
  String get authMfaStatusNotEnabled => 'Не включено';

  @override
  String get authMfaStatusProtected => 'Защищено';

  @override
  String get authMfaStillOffline => 'Всё ещё нет сети. Проверьте подключение.';

  @override
  String get authMfaVerificationCodeHint => '000000';

  @override
  String get authMfaVerificationCodeLabel => 'Код подтверждения';

  @override
  String get authMfaVerifyAndEnableButton => 'Подтвердить и включить';

  @override
  String get authMfaVerifyButton => 'Подтвердить';

  @override
  String get authMfaVerifyIdentityTitle => 'Подтверждение личности';

  @override
  String get authMfaVerifyRequiresInternet =>
      'Для проверки кодов требуется подключение к интернету.';

  @override
  String get authMfaVerifyingButton => 'Проверка...';

  @override
  String get authMfaYourPhone => 'ваш телефон';

  @override
  String get automationActionBodyLabel => 'Тело';

  @override
  String get automationActionChangeType => 'Изменить тип действия';

  @override
  String automationActionChannelIndex(int index) {
    return 'Канал $index';
  }

  @override
  String get automationActionChannelMessage => 'Сообщение в канале';

  @override
  String automationActionChannelsCount(int count) {
    return '$count каналов';
  }

  @override
  String get automationActionCustomSound =>
      'Пользовательский звук (необязательно)';

  @override
  String get automationActionDefaultChannel => 'Канал по умолчанию';

  @override
  String get automationActionDirectMessage => 'Личное сообщение';

  @override
  String get automationActionDone => 'Готово';

  @override
  String get automationActionGlyphPattern =>
      'Паттерн подсветки (Nothing Phone)';

  @override
  String get automationActionGotIt => 'Понятно';

  @override
  String get automationActionIftttEventName => 'Название события IFTTT';

  @override
  String get automationActionIftttHelp =>
      'Использует ваш ключ Webhook IFTTT из настроек';

  @override
  String get automationActionIftttHint => 'например, meshtastic_alert';

  @override
  String get automationActionWebhookEventName => 'Event Name';

  @override
  String get automationActionWebhookUrlLabel => 'Webhook URL (optional)';

  @override
  String get automationActionWebhookUrlHint =>
      'e.g., http://192.168.1.100:8123/api/webhook/...';

  @override
  String get automationActionWebhookHelp =>
      'Enter a custom URL to POST directly, or leave blank to use your global IFTTT/webhook settings. Private/LAN addresses (192.168.x, 10.x) are supported.';

  @override
  String get automationActionLogEvent => 'Записать в историю';

  @override
  String get automationActionMessageLabel => 'Сообщение';

  @override
  String get automationActionNoChannels => 'Нет доступных каналов';

  @override
  String get automationActionNoSoundsFound => 'Звуки не найдены';

  @override
  String get automationActionPlaySound => 'Воспроизвести звук оповещения';

  @override
  String automationActionPlayFailed(String error) {
    return 'Ошибка воспроизведения: $error';
  }

  @override
  String automationActionPlaySoundFailed(String error) {
    return 'Не удалось воспроизвести звук: $error';
  }

  @override
  String automationActionPlayingSound(String name) {
    return 'Воспроизведение «$name»...';
  }

  @override
  String get automationActionPlaysAfter => 'Воспроизводится после уведомления';

  @override
  String get automationActionPreview => 'Предпросмотр';

  @override
  String get automationActionPrimary => 'Основной';

  @override
  String get automationActionPushNotification => 'Push-уведомление';

  @override
  String get automationActionRtttlRingtone => 'Мелодия RTTTL';

  @override
  String get automationActionSearchResults => 'РЕЗУЛЬТАТЫ ПОИСКА';

  @override
  String get automationActionSearchSounds => 'Поиск звуков...';

  @override
  String get automationActionSelectChannel => 'Выбрать канал';

  @override
  String get automationActionSelectChannelTitle => 'Выбор канала';

  @override
  String get automationActionSelectNodePlaceholder => 'Выберите ноду';

  @override
  String get automationActionSelectSound => 'Выбрать звук';

  @override
  String get automationActionSendMessage => 'Отправить сообщение ноде';

  @override
  String get automationActionSendToChannel => 'Отправить в канал';

  @override
  String get automationActionShortcutDataInfo =>
      'Данные события (имя ноды, аккумулятор, местоположение и т.д.) будут переданы как JSON во входные данные Shortcut.';

  @override
  String get automationActionShortcutHelpTitle => 'Использование Shortcuts';

  @override
  String get automationActionShortcutIosNote =>
      'Примечание: приложение «Shortcuts» кратко откроется при срабатывании. Это ограничение iOS.';

  @override
  String get automationActionShortcutKeyBattery =>
      'Уровень аккумулятора % (если доступно)';

  @override
  String get automationActionShortcutKeyLatitude =>
      'Широта GPS (если доступно)';

  @override
  String get automationActionShortcutKeyLongitude =>
      'Долгота GPS (если доступно)';

  @override
  String get automationActionShortcutKeyMessage =>
      'Текст сообщения (если применимо)';

  @override
  String get automationActionShortcutKeyNodeName => 'Имя ноды';

  @override
  String get automationActionShortcutKeyNodeNum => 'Номер ноды';

  @override
  String get automationActionShortcutKeyTimestamp => 'Временная метка события';

  @override
  String get automationActionShortcutKeyTrigger =>
      'Тип триггера (nodeOffline и т.д.)';

  @override
  String get automationActionShortcutKeysTitle => 'Доступные ключи в словаре:';

  @override
  String get automationActionShortcutNameHint => 'Введите точное имя Shortcut';

  @override
  String get automationActionShortcutNameLabel => 'Имя Shortcut';

  @override
  String get automationActionShortcutSetup => 'Настройка Shortcut:';

  @override
  String get automationActionShortcutStep1 =>
      'Добавьте действие «Получить словарь из»\nВыберите «Входные данные Shortcut»';

  @override
  String get automationActionShortcutStep2 =>
      'Добавьте действие «Получить значение для»\nУкажите ключ (например, node_name) и выберите «Словарь»';

  @override
  String get automationActionShortcutStep3 =>
      'Используйте извлечённое значение в ваших действиях\n(например, «Отправить сообщение», «Показать уведомление»)';

  @override
  String get automationActionSoundSection => 'ЗВУК';

  @override
  String automationActionSoundsCount(int count) {
    return '$count звуков';
  }

  @override
  String get automationActionSuggestions => 'ПРЕДЛОЖЕНИЯ';

  @override
  String get automationActionSystemDefault => 'Системный по умолчанию';

  @override
  String get automationActionTapToChoose => 'Нажмите, чтобы выбрать';

  @override
  String get automationActionTitleLabel => 'Заголовок';

  @override
  String get automationActionTo => 'КОМУ';

  @override
  String get automationActionTriggerShortcut => 'Запустить iOS Shortcut';

  @override
  String get automationActionTriggerWebhook => 'Вызвать Webhook (IFTTT)';

  @override
  String get automationActionUpdateWidget =>
      'Обновить виджет на главном экране';

  @override
  String get automationActionVariableHint =>
      'Нажмите на переменные ниже для вставки';

  @override
  String get automationActionVibrate => 'Вибрация устройства';

  @override
  String automationCardActionCount(int count, String s) {
    return '$count действие$s';
  }

  @override
  String automationCardDaysAgo(int count) {
    return '$countд назад';
  }

  @override
  String automationCardHoursAgo(int count) {
    return '$countч назад';
  }

  @override
  String get automationCardJustNow => 'Только что';

  @override
  String automationCardMinutesAgo(int count) {
    return '$countм назад';
  }

  @override
  String automationCardRunsCount(int count) {
    return '$count запусков';
  }

  @override
  String automationCardWeeksAgo(int count) {
    return '$countн назад';
  }

  @override
  String get automationCategoryBattery => 'Аккумулятор';

  @override
  String get automationCategoryLocation => 'Местоположение';

  @override
  String get automationCategoryManual => 'Вручную';

  @override
  String get automationCategoryMessages => 'Сообщения';

  @override
  String get automationCategoryNodeStatus => 'Статус ноды';

  @override
  String get automationCategorySensors => 'Датчики';

  @override
  String get automationCategorySignal => 'Сигнал';

  @override
  String get automationCategoryTime => 'Время';

  @override
  String get automationConditionBatteryAbove =>
      'Аккумулятор выше порогового значения';

  @override
  String get automationConditionBatteryBelow =>
      'Аккумулятор ниже порогового значения';

  @override
  String get automationConditionDayOfWeek => 'В определённые дни';

  @override
  String get automationConditionNodeOffline => 'Нода неактивна';

  @override
  String get automationConditionNodeOnline => 'Нода активна';

  @override
  String get automationConditionOutsideGeofence => 'За пределами геозоны';

  @override
  String get automationConditionTimeRange => 'В течение временного диапазона';

  @override
  String get automationConditionWithinGeofence => 'В пределах геозоны';

  @override
  String get automationEditorAddAction => 'Добавить действие';

  @override
  String get automationEditorCreateAutomation => 'Создать автоматизацию';

  @override
  String get automationEditorCreated => 'Автоматизация создана';

  @override
  String get automationEditorDeleteError => 'Не удалось удалить автоматизацию';

  @override
  String get automationEditorDeleteTooltip => 'Удалить';

  @override
  String automationEditorDescBatteryLow(String threshold) {
    return 'Срабатывает, когда уровень аккумулятора падает ниже $threshold%';
  }

  @override
  String automationEditorDescSilent(int minutes) {
    return 'Оповещение, если нет активности от ноды в течение $minutes минут';
  }

  @override
  String get automationEditorDescriptionHint => 'Что делает эта автоматизация?';

  @override
  String get automationEditorDescriptionLabel => 'Описание (необязательно)';

  @override
  String automationEditorInvalidVars(String vars) {
    return 'Недопустимые переменные: $vars';
  }

  @override
  String get automationEditorNameHint => 'например, Оповещение о низком заряде';

  @override
  String get automationEditorNameLabel => 'Название';

  @override
  String get automationEditorNoActions => 'Действия не настроены';

  @override
  String get automationEditorNoActionsHint =>
      'Нажмите «+ Добавить действие», чтобы добавить';

  @override
  String get automationEditorSaveChanges => 'Сохранить изменения';

  @override
  String get automationEditorSaveError => 'Не удалось сохранить автоматизацию';

  @override
  String get automationEditorSaving => 'Сохранение...';

  @override
  String automationEditorStepNumber(int number) {
    return 'Шаг $number';
  }

  @override
  String get automationEditorThen => 'ТОГДА';

  @override
  String get automationEditorThen2 => 'тогда...';

  @override
  String get automationEditorThenDo => 'тогда выполнить...';

  @override
  String get automationEditorTitleEdit => 'Редактировать автоматизацию';

  @override
  String get automationEditorTitleNew => 'Новая автоматизация';

  @override
  String get automationEditorUpdated => 'Автоматизация обновлена';

  @override
  String get automationEditorValidateActions =>
      'Добавьте хотя бы одно действие';

  @override
  String get automationEditorValidateName =>
      'Введите название для этой автоматизации';

  @override
  String get automationEditorWhen => 'КОГДА';

  @override
  String get automationFlowAddNode => 'Добавить ноду';

  @override
  String get automationFlowCompilationIssues => 'Проблемы компиляции';

  @override
  String get automationFlowCreate => 'Создать';

  @override
  String get automationFlowCreated => 'Автоматизация создана';

  @override
  String get automationFlowDiscard => 'Отменить';

  @override
  String get automationFlowDiscardMessage =>
      'У вас есть несохранённые изменения в редакторе потока. Отменить их и вернуться назад?';

  @override
  String get automationFlowDiscardTitle => 'Отменить изменения?';

  @override
  String get automationFlowEditTitle => 'Редактировать поток';

  @override
  String get automationFlowErrors => 'Ошибки';

  @override
  String get automationFlowKeepEditing => 'Продолжить редактирование';

  @override
  String get automationFlowNameHint => 'Название потока...';

  @override
  String get automationFlowNewTitle => 'Новый поток';

  @override
  String get automationFlowNoCompilation =>
      'Из этого графа не удалось скомпилировать ни одной автоматизации';

  @override
  String automationFlowNodesCount(int count) {
    return '$count нод';
  }

  @override
  String get automationFlowSave => 'Сохранить';

  @override
  String get automationFlowSaveError => 'Не удалось сохранить автоматизацию';

  @override
  String get automationFlowToolbarAdd => 'Добавить';

  @override
  String automationFlowToolbarDelete(int count) {
    return 'Удалить ($count)';
  }

  @override
  String get automationFlowToolbarFit => 'По размеру';

  @override
  String get automationFlowToolbarRedo => 'Повторить';

  @override
  String get automationFlowToolbarUndo => 'Отменить';

  @override
  String get automationFlowUpdated => 'Автоматизация обновлена';

  @override
  String get automationFlowValidateName =>
      'Введите название для этой автоматизации';

  @override
  String get automationFlowValidationTooltip => 'Проблемы проверки';

  @override
  String get automationFlowWarnings => 'Предупреждения';

  @override
  String automationImportActionsCount(int count) {
    return 'Действия ($count)';
  }

  @override
  String get automationImportButton => 'Импортировать';

  @override
  String automationImportConditionsCount(int count) {
    return 'Условия ($count)';
  }

  @override
  String automationImportConditionsText(int count) {
    return '$count условий';
  }

  @override
  String get automationImportEditFirst => 'Сначала изменить';

  @override
  String automationImportError(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String automationImportFailed(String error) {
    return 'Не удалось импортировать автоматизацию: $error';
  }

  @override
  String get automationImportFailedTitle => 'Ошибка импорта';

  @override
  String get automationImportGoBack => 'Назад';

  @override
  String get automationImportNoData => 'Данные автоматизации не предоставлены';

  @override
  String get automationImportNotFound =>
      'Автоматизация не найдена или была удалена';

  @override
  String get automationImportSuccess => 'Автоматизация успешно импортирована';

  @override
  String get automationImportTitle => 'Импорт автоматизации';

  @override
  String get automationImportTrigger => 'Триггер';

  @override
  String get automationImportView => 'Просмотр';

  @override
  String get automationImportWarning =>
      'Эта автоматизация будет импортирована как отключённая. Проверьте её и включите, когда будете готовы.';

  @override
  String get automationScreenAcceptableUse => 'Допустимое использование';

  @override
  String get automationScreenAddAutomation => 'Добавить автоматизацию';

  @override
  String get automationScreenClear => 'Очистить';

  @override
  String get automationScreenCreateFromScratch => 'Создать с нуля';

  @override
  String get automationScreenCreateFromScratchSubtitle =>
      'Создайте пользовательскую автоматизацию с полным контролем над триггерами и действиями';

  @override
  String get automationScreenCreatedFromTemplate =>
      'Автоматизация создана из шаблона';

  @override
  String automationScreenDaysAgo(int count) {
    return '$countд назад';
  }

  @override
  String get automationScreenDelete => 'Удалить';

  @override
  String automationScreenDeleteMessage(String name) {
    return 'Вы уверены, что хотите удалить «$name»?';
  }

  @override
  String get automationScreenDeleteTitle => 'Удалить автоматизацию';

  @override
  String automationScreenDeleted(String name) {
    return '«$name» удалено';
  }

  @override
  String automationScreenDeleting(String name) {
    return 'Удаление «$name»...';
  }

  @override
  String get automationScreenEmptyDescription =>
      'Создавайте автоматизации для автоматического выполнения действий при возникновении событий в вашей mesh-сети.';

  @override
  String get automationScreenEmptyTitle => 'Автоматизируйте вашу сеть';

  @override
  String get automationScreenExecutionLog => 'Журнал выполнения';

  @override
  String get automationScreenHelp => 'Справка';

  @override
  String automationScreenHoursAgo(int count) {
    return '$countч назад';
  }

  @override
  String get automationScreenJustNow => 'Только что';

  @override
  String get automationScreenLoadError => 'Не удалось загрузить автоматизации';

  @override
  String automationScreenMinutesAgo(int count) {
    return '$countм назад';
  }

  @override
  String get automationScreenNewTooltip => 'Новая автоматизация';

  @override
  String get automationScreenNoExecutions => 'Выполнений пока нет';

  @override
  String get automationScreenQuickStartSubtitle =>
      'Быстрая настройка для распространённых сценариев';

  @override
  String get automationScreenQuickStartTemplates => 'Шаблоны быстрого старта';

  @override
  String get automationScreenRetry => 'Повторить';

  @override
  String automationScreenRunFailed(String error) {
    return 'Ошибка запуска: $error';
  }

  @override
  String automationScreenRunSuccess(String name) {
    return '«$name» выполнено успешно';
  }

  @override
  String automationScreenRunning(String name) {
    return 'Выполнение «$name»...';
  }

  @override
  String get automationScreenScanQrCode => 'Сканировать QR-код';

  @override
  String get automationScreenStartWithTrigger => 'Начать с триггера';

  @override
  String get automationScreenStartWithTriggerSubtitle =>
      'Выберите событие, которое запускает вашу автоматизацию';

  @override
  String get automationScreenStatActive => 'Активных';

  @override
  String get automationScreenStatExecutions => 'Выполнений';

  @override
  String get automationScreenStatTotal => 'Всего';

  @override
  String get automationScreenTitle => 'Автоматизации';

  @override
  String get automationShareMessage =>
      'Посмотрите эту автоматизацию в Socialmesh!';

  @override
  String get automationShareScanInfo =>
      'Отсканируйте этот QR-код в Socialmesh, чтобы импортировать автоматизацию';

  @override
  String get automationShareSignIn => 'Войдите, чтобы делиться автоматизациями';

  @override
  String get automationShareSignInAction => 'Войти';

  @override
  String automationShareSubject(String name) {
    return 'Автоматизация Socialmesh: $name';
  }

  @override
  String get automationShareTitle => 'Поделиться автоматизацией';

  @override
  String get automationTriggerAnyChannel => 'Любой канал';

  @override
  String get automationTriggerAnyNode => 'Любая нода';

  @override
  String get automationTriggerBatteryFull => 'Аккумулятор полностью заряжен';

  @override
  String get automationTriggerBatteryLow =>
      'Уровень аккумулятора падает ниже порога';

  @override
  String get automationTriggerBatteryThreshold =>
      'Пороговый уровень аккумулятора';

  @override
  String get automationTriggerChannelActivity => 'Активность на канале';

  @override
  String get automationTriggerChannelHelp =>
      'Оставьте пустым, чтобы срабатывать при любой активности в канале';

  @override
  String automationTriggerChannelIndex(int index) {
    return 'Канал $index';
  }

  @override
  String get automationTriggerChannelLabel => 'Канал (необязательно)';

  @override
  String get automationTriggerDaily => 'Ежедневно';

  @override
  String get automationTriggerDayFri => 'Пт';

  @override
  String get automationTriggerDayMon => 'Пн';

  @override
  String get automationTriggerDaySat => 'Сб';

  @override
  String get automationTriggerDaySun => 'Вс';

  @override
  String get automationTriggerDayThu => 'Чт';

  @override
  String get automationTriggerDayTue => 'Вт';

  @override
  String get automationTriggerDayWed => 'Ср';

  @override
  String get automationTriggerDays => 'Дни';

  @override
  String get automationTriggerDescBatteryFull =>
      'Срабатывает, когда аккумулятор полностью заряжен';

  @override
  String get automationTriggerDescBatteryLow =>
      'Срабатывает, когда уровень аккумулятора падает ниже порога';

  @override
  String get automationTriggerDescChannelActivity =>
      'Срабатывает при активности на канале';

  @override
  String get automationTriggerDescDetectionSensor =>
      'Срабатывает при активации датчика обнаружения';

  @override
  String get automationTriggerDescGeofenceEnter =>
      'Срабатывает, когда нода входит в геозону';

  @override
  String get automationTriggerDescGeofenceExit =>
      'Срабатывает, когда нода выходит из геозоны';

  @override
  String get automationTriggerDescManual =>
      'Запускается вручную через Shortcuts или интерфейс';

  @override
  String get automationTriggerDescMessageContains =>
      'Срабатывает, когда сообщение содержит ключевое слово';

  @override
  String get automationTriggerDescMessageReceived =>
      'Срабатывает при получении любого сообщения';

  @override
  String get automationTriggerDescNodeOffline =>
      'Срабатывает, когда нода долгое время не отвечает';

  @override
  String get automationTriggerDescNodeOnline =>
      'Срабатывает, когда нода недавно выходила на связь';

  @override
  String get automationTriggerDescNodeSilent =>
      'Срабатывает, когда нода молчит в течение заданного времени';

  @override
  String get automationTriggerDescPositionChanged =>
      'Срабатывает, когда изменяется положение ноды';

  @override
  String get automationTriggerDescScheduled => 'Срабатывает по расписанию';

  @override
  String get automationTriggerDescSignalWeak =>
      'Срабатывает, когда уровень сигнала падает';

  @override
  String get automationTriggerDetectionSensor => 'Сработал датчик обнаружения';

  @override
  String automationTriggerEveryHours(int hours, String s) {
    return 'Каждые $hours час$s';
  }

  @override
  String automationTriggerEveryHoursMinutes(int hours, String s, int minutes) {
    return 'Каждые $hours час$s $minutes минут';
  }

  @override
  String automationTriggerEveryMinutes(int count) {
    return 'Каждые $count минут';
  }

  @override
  String get automationTriggerGeofenceCenter => 'Центр геозоны';

  @override
  String get automationTriggerGeofenceEnter => 'Вход в геозону';

  @override
  String get automationTriggerGeofenceExit => 'Выход из геозоны';

  @override
  String get automationTriggerInterval => 'Интервал';

  @override
  String get automationTriggerKeywordHint => 'например, SOS, помощь, срочно';

  @override
  String get automationTriggerKeywordLabel => 'Ключевое слово для поиска';

  @override
  String get automationTriggerLatitude => 'Широта';

  @override
  String get automationTriggerLongitude => 'Долгота';

  @override
  String get automationTriggerManual => 'Запуск вручную';

  @override
  String get automationTriggerManualDescription =>
      'Эту автоматизацию можно запустить вручную из:\n• Экрана автоматизаций (нажмите кнопку воспроизведения)\n• Siri Shortcuts\n• Виджетов';

  @override
  String get automationTriggerManualTitle => 'Запуск вручную';

  @override
  String get automationTriggerMessageContains =>
      'Сообщение содержит ключевое слово';

  @override
  String get automationTriggerMessageReceived => 'Сообщение получено';

  @override
  String get automationTriggerNodeFilterHelp =>
      'Оставьте пустым, чтобы срабатывать для любой ноды';

  @override
  String get automationTriggerNodeFilterLabel =>
      'Фильтр по ноде (необязательно)';

  @override
  String get automationTriggerNodeOffline => 'Нода стала неактивной';

  @override
  String get automationTriggerNodeOnline => 'Нода стала активной';

  @override
  String get automationTriggerNodeSilent =>
      'Нода молчит в течение заданного времени';

  @override
  String get automationTriggerPickOnMap => 'Выбрать на карте';

  @override
  String get automationTriggerPositionChanged => 'Местоположение обновлено';

  @override
  String get automationTriggerRadius => 'Радиус';

  @override
  String get automationTriggerRepeatEvery => 'Повторять каждые';

  @override
  String get automationTriggerScheduleType => 'Тип расписания';

  @override
  String get automationTriggerScheduled => 'Запланированное время';

  @override
  String get automationTriggerSelectNode => 'Выбрать ноду';

  @override
  String get automationTriggerSelectTrigger => 'Выбрать триггер';

  @override
  String get automationTriggerSensorAny => 'Любой';

  @override
  String get automationTriggerSensorClear => 'Нет срабатывания';

  @override
  String get automationTriggerSensorDetected => 'Обнаружено';

  @override
  String get automationTriggerSensorNameHelp =>
      'Оставьте пустым, чтобы срабатывать для любого датчика';

  @override
  String get automationTriggerSensorNameHint =>
      'например, Движение, Дверь, Окно';

  @override
  String get automationTriggerSensorNameLabel =>
      'Фильтр по имени датчика (необязательно)';

  @override
  String get automationTriggerSensorState => 'Срабатывать, когда датчик:';

  @override
  String get automationTriggerSignalThreshold =>
      'Пороговое значение сигнала (SNR)';

  @override
  String get automationTriggerSignalWeak => 'Уровень сигнала падает';

  @override
  String get automationTriggerSilentDuration => 'Продолжительность молчания';

  @override
  String get automationTriggerTime => 'Время';

  @override
  String get automationTriggerWeekly => 'Еженедельно';

  @override
  String get automationValidateGeofence => 'Выберите местоположение геозоны';

  @override
  String get automationValidateKeyword => 'Введите ключевое слово для поиска';

  @override
  String get automationValidateMessage => 'Введите сообщение для отправки';

  @override
  String get automationValidateSchedule => 'Задайте время расписания';

  @override
  String get automationValidateShortcutName => 'Введите имя Shortcut';

  @override
  String get automationValidateTargetNode => 'Выберите целевую ноду';

  @override
  String get automationValidateWebhookEvent => 'Введите имя события Webhook';

  @override
  String get automationVariableAllVariables => 'Все переменные';

  @override
  String get automationVariableDeleteHint =>
      'Нажмите на переменную, чтобы выбрать её, затем нажмите Backspace для удаления';

  @override
  String get automationVariableDescBattery =>
      'Текущий уровень аккумулятора в процентах';

  @override
  String get automationVariableDescChannelName => 'Название канала';

  @override
  String get automationVariableDescKeyword => 'Найденное ключевое слово';

  @override
  String get automationVariableDescLocation =>
      'GPS-координаты (широта, долгота)';

  @override
  String get automationVariableDescMessage => 'Содержимое сообщения';

  @override
  String get automationVariableDescNodeName =>
      'Имя ноды, вызвавшего срабатывание';

  @override
  String get automationVariableDescNodeNum =>
      'Номер ноды в шестнадцатеричном формате (например, a1b2)';

  @override
  String get automationVariableDescSensorName => 'Имя датчика обнаружения';

  @override
  String get automationVariableDescSensorState =>
      'Состояние датчика (обнаружено / нет срабатывания)';

  @override
  String get automationVariableDescSignalThreshold =>
      'Пороговое значение сигнала в дБ (SNR)';

  @override
  String get automationVariableDescSilentDuration =>
      'Настройка продолжительности молчания';

  @override
  String get automationVariableDescThreshold =>
      'Настроенное пороговое значение триггера';

  @override
  String get automationVariableDescTime => 'Текущая временная метка (ISO 8601)';

  @override
  String get automationVariableDescZoneRadius => 'Радиус геозоны в метрах';

  @override
  String get automationVariableNoMatch => 'Совпадающих переменных не найдено';

  @override
  String get automationVariablePickerTitle => 'Вставить переменную';

  @override
  String get automationVariableSearchHint => 'Поиск переменных...';

  @override
  String get automationVariableSectionTrigger => 'Контекст триггера';

  @override
  String get automationVariableSectionUniversal => 'Универсальные';

  @override
  String get categoryProductsApplyFilters => 'Применить фильтры';

  @override
  String get categoryProductsClearFilters => 'Сбросить фильтры';

  @override
  String get categoryProductsErrorLoading => 'Ошибка загрузки товаров';

  @override
  String get categoryProductsFilter => 'Фильтр';

  @override
  String get categoryProductsFiltersTitle => 'Фильтры';

  @override
  String get categoryProductsFrequencyBands => 'Частотные диапазоны';

  @override
  String get categoryProductsInStockOnly => 'Только в наличии';

  @override
  String get categoryProductsNotFound => 'Товары не найдены';

  @override
  String get categoryProductsOutOfStock => 'НЕТ В НАЛИЧИИ';

  @override
  String get categoryProductsPriceRange => 'Ценовой диапазон';

  @override
  String get categoryProductsReset => 'Сбросить';

  @override
  String categoryProductsResultCount(int count) {
    return '$count товаров';
  }

  @override
  String get categoryProductsRetry => 'Повторить';

  @override
  String get categoryProductsSortNewest => 'Сначала новые';

  @override
  String get categoryProductsSortPopular => 'Самые популярные';

  @override
  String get categoryProductsSortPriceHigh => 'Цена: по убыванию';

  @override
  String get categoryProductsSortPriceLow => 'Цена: по возрастанию';

  @override
  String get categoryProductsSortRating => 'Лучший рейтинг';

  @override
  String get categoryProductsTryFilters => 'Попробуйте изменить фильтры';

  @override
  String get channelFormApproxLocationTitle => 'Приблизительное местоположение';

  @override
  String get channelFormCreatedSnackbar => 'Канал создан';

  @override
  String channelFormDefaultName(int index) {
    return 'Канал $index';
  }

  @override
  String get channelFormDeviceNotConnected =>
      'Невозможно сохранить канал: устройство не подключено';

  @override
  String get channelFormDeviceNotReady =>
      'Устройство не готово — подождите установления соединения';

  @override
  String get channelFormDownlinkSubtitle => 'Получать сообщения с сервера MQTT';

  @override
  String get channelFormDownlinkTitle => 'Входящий канал (Downlink) включён';

  @override
  String get channelFormEditTitle => 'Изменить канал';

  @override
  String get channelFormEncryptionLabel => 'Шифрование';

  @override
  String channelFormError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get channelFormInvalidBase64 => 'Неверная кодировка base64';

  @override
  String channelFormInvalidKeySize(int byteCount) {
    return 'Недопустимый размер ключа ($byteCount байт). Используйте 1, 16 или 32 байта.';
  }

  @override
  String get channelFormKeyEmpty => 'Ключ не может быть пустым';

  @override
  String get channelFormKeySizeAes128 => 'AES-128';

  @override
  String get channelFormKeySizeAes256 => 'AES-256';

  @override
  String channelFormKeySizeBitDesc(int bits) {
    return 'Ключ шифрования $bits бит';
  }

  @override
  String get channelFormKeySizeDefault => 'По умолчанию (простой)';

  @override
  String get channelFormKeySizeDefaultDesc =>
      'Однобайтовый простой ключ (AQ==)';

  @override
  String get channelFormKeySizeNone => 'Без шифрования';

  @override
  String get channelFormKeySizeNoneDesc =>
      'Сообщения отправляются в открытом виде';

  @override
  String get channelFormMaxChannelsReached => 'Максимально допустимо 8 каналов';

  @override
  String get channelFormMqttLabel => 'MQTT';

  @override
  String get channelFormMqttWarning =>
      'Большинство устройств имеют очень ограниченные вычислительные ресурсы и оперативную память. Подключение активного канала, например LongFast, через стандартный сервер MQTT может перегрузить устройство потоком 15–25 пакетов в секунду, из-за чего оно перестанет отвечать. Рекомендуется использовать частный MQTT-сервер или менее загруженный канал.';

  @override
  String get channelFormNameHint => 'Введите имя канала (без пробелов)';

  @override
  String get channelFormNameMaxHint => 'Не более 11 символов';

  @override
  String get channelFormNameTitle => 'Имя канала';

  @override
  String get channelFormNewTitle => 'Новый канал';

  @override
  String get channelFormPositionEnabledSubtitle =>
      'Передавать местоположение в этом канале';

  @override
  String get channelFormPositionEnabledTitle =>
      'Передача местоположения включена';

  @override
  String get channelFormPositionLabel => 'Местоположение';

  @override
  String get channelFormPreciseLocationSubtitle =>
      'Передавать точные координаты GPS';

  @override
  String get channelFormPreciseLocationTitle => 'Точное местоположение';

  @override
  String get channelFormPrecision12 => 'С точностью до 5,8 км';

  @override
  String get channelFormPrecision13 => 'С точностью до 2,9 км';

  @override
  String get channelFormPrecision14 => 'С точностью до 1,5 км';

  @override
  String get channelFormPrecision15 => 'С точностью до 700 м';

  @override
  String get channelFormPrecision32 => 'Точное местоположение';

  @override
  String get channelFormPrecisionUnknown => 'Неизвестно';

  @override
  String get channelFormPrimaryChannelNote =>
      'Это основной канал для связи устройства. Изменения могут повлиять на соединение.';

  @override
  String get channelFormPrimaryChannelTitle => 'Основной канал';

  @override
  String get channelFormSaveButton => 'Сохранить';

  @override
  String get channelFormUpdatedSnackbar => 'Канал обновлён';

  @override
  String get channelFormUplinkSubtitle => 'Пересылать сообщения на сервер MQTT';

  @override
  String get channelFormUplinkTitle => 'Исходящий канал (Uplink) включён';

  @override
  String get channelOptionsCopyButton => 'Копировать';

  @override
  String channelOptionsDefaultName(int index) {
    return 'Канал $index';
  }

  @override
  String get channelOptionsDelete => 'Удалить канал';

  @override
  String get channelOptionsDeleteButton => 'Удалить';

  @override
  String channelOptionsDeleteConfirm(String name) {
    return 'Удалить канал «$name»?';
  }

  @override
  String channelOptionsDeleteFailed(String error) {
    return 'Не удалось удалить канал: $error';
  }

  @override
  String get channelOptionsDeleteNotConnected =>
      'Невозможно удалить канал: устройство не подключено';

  @override
  String get channelOptionsDeleteTitle => 'Удалить канал';

  @override
  String get channelOptionsEdit => 'Изменить канал';

  @override
  String get channelOptionsEncrypted => 'Зашифрован';

  @override
  String get channelOptionsHideButton => 'Скрыть';

  @override
  String get channelOptionsInviteLink => 'Поделиться ссылкой-приглашением';

  @override
  String get channelOptionsKeyCopied => 'Ключ скопирован в буфер обмена';

  @override
  String channelOptionsKeySubtitle(int keyBits, int keyBytes) {
    return '$keyBits бит · $keyBytes байт · Base64';
  }

  @override
  String get channelOptionsKeyTitle => 'Ключ шифрования';

  @override
  String get channelOptionsNoEncryption => 'Без шифрования';

  @override
  String get channelOptionsShare => 'Поделиться каналом';

  @override
  String get channelOptionsShowButton => 'Показать';

  @override
  String get channelOptionsMuteNotifications => 'Mute Notifications';

  @override
  String get channelOptionsUnmuteNotifications => 'Unmute Notifications';

  @override
  String get channelOptionsViewKey => 'Просмотреть ключ шифрования';

  @override
  String get channelShareCreatingInvite => 'Создание ссылки-приглашения...';

  @override
  String channelShareDefaultName(int index) {
    return 'Канал $index';
  }

  @override
  String get channelShareInviteCopied =>
      'Ссылка-приглашение скопирована в буфер обмена';

  @override
  String get channelShareInviteFailed =>
      'Не удалось создать ссылку-приглашение';

  @override
  String get channelShareMessage =>
      'Присоединяйтесь к моему каналу в Socialmesh!';

  @override
  String get channelShareQrInfo =>
      'Отсканируйте этот QR-код в Socialmesh, чтобы импортировать канал';

  @override
  String get channelShareSignInAction => 'Войти';

  @override
  String get channelShareSignInRequired =>
      'Для публикации каналов необходимо войти в аккаунт';

  @override
  String channelShareSubject(String channelName) {
    return 'Канал Socialmesh: $channelName';
  }

  @override
  String get channelShareTitle => 'Поделиться каналом';

  @override
  String get channelWizardBackButton => 'Назад';

  @override
  String get channelWizardCompatMax =>
      'Максимальная защита. Убедитесь, что все участники поддерживают шифрование AES-256.';

  @override
  String get channelWizardCompatOpen =>
      'Совместим со всеми устройствами. Обмен ключами не требуется.';

  @override
  String get channelWizardCompatPrivate =>
      'Рекомендуется. Безопасно поделитесь QR-кодом с теми, кому хотите разрешить доступ.';

  @override
  String get channelWizardCompatShared =>
      'Использует стандартный ключ Meshtastic. Другие пользователи с настройками по умолчанию могут перехватывать сообщения.';

  @override
  String get channelWizardContinueButton => 'Продолжить';

  @override
  String get channelWizardCopyUrlButton => 'Копировать URL';

  @override
  String get channelWizardCreateButton => 'Создать канал';

  @override
  String channelWizardCreateFailed(String error) {
    return 'Не удалось создать канал: $error';
  }

  @override
  String get channelWizardCreatedHeading => 'Канал создан!';

  @override
  String get channelWizardCreatedSubtitle =>
      'Поделитесь этим QR-кодом, чтобы другие могли присоединиться.';

  @override
  String get channelWizardCreating => 'Создание канала...';

  @override
  String get channelWizardDefaultKey => 'Ключ по умолчанию';

  @override
  String get channelWizardDeviceNotConnected =>
      'Невозможно сохранить канал: устройство не подключено';

  @override
  String get channelWizardDisabled => 'Отключено';

  @override
  String get channelWizardDoneButton => 'Готово';

  @override
  String get channelWizardDownlinkSubtitle =>
      'Получать сообщения из MQTT и рассылать их в этом канале.';

  @override
  String get channelWizardDownlinkTitle => 'Входящий канал (Downlink) включён';

  @override
  String get channelWizardEnabled => 'Включено';

  @override
  String get channelWizardEncryptionKeyLabel => 'Ключ шифрования';

  @override
  String get channelWizardHelpTooltip => 'Справка';

  @override
  String channelWizardKeyBits(int bits) {
    return '$bits бит';
  }

  @override
  String get channelWizardKeySizeAes128 => 'AES-128';

  @override
  String get channelWizardKeySizeAes128Desc =>
      'Надёжное шифрование — рекомендуется для большинства случаев';

  @override
  String get channelWizardKeySizeAes256 => 'AES-256';

  @override
  String get channelWizardKeySizeAes256Desc =>
      'Максимальное шифрование — наивысший уровень защиты';

  @override
  String get channelWizardKeySizeDefault => 'По умолчанию';

  @override
  String get channelWizardKeySizeDefaultDesc =>
      'Простой общий ключ — совместим, но небезопасен';

  @override
  String get channelWizardKeySizeNone => 'Нет';

  @override
  String get channelWizardKeySizeNoneDesc =>
      'Без шифрования — сообщения отправляются в открытом виде';

  @override
  String get channelWizardMqttFloodWarning =>
      'Большинство устройств имеют очень ограниченные вычислительные ресурсы и оперативную память. Подключение активного канала, например LongFast, через стандартный сервер MQTT может перегрузить устройство потоком 15–25 пакетов в секунду, из-за чего оно перестанет отвечать. Рекомендуется использовать частный MQTT-сервер или менее загруженный канал.';

  @override
  String get channelWizardMqttHeader => 'Настройки MQTT';

  @override
  String get channelWizardMqttWarning =>
      'Для работы uplink/downlink необходимо настроить MQTT на устройстве.';

  @override
  String get channelWizardNameBannerInfo =>
      'Имя канала ограничено 12 буквенно-цифровыми символами.';

  @override
  String get channelWizardNameHeading => 'Назовите канал';

  @override
  String get channelWizardNameHint => 'Например: Семья, Друзья, Поход';

  @override
  String get channelWizardNameLabel => 'Имя канала';

  @override
  String get channelWizardNameSubtitle =>
      'Выберите имя, по которому вы будете узнавать этот канал. Оно будет видно всем, кто к нему присоединится.';

  @override
  String get channelWizardNoKey => 'Нет ключа';

  @override
  String get channelWizardOptionsHeading => 'Дополнительные параметры';

  @override
  String get channelWizardOptionsSubtitle =>
      'Настройте дополнительные параметры канала.';

  @override
  String get channelWizardPositionSubtitle =>
      'Передавать ваше местоположение в этом канале.';

  @override
  String get channelWizardPositionTitle => 'Передача местоположения включена';

  @override
  String get channelWizardPrivacyHeading =>
      'Выберите уровень конфиденциальности';

  @override
  String get channelWizardPrivacyMaxDesc =>
      'Шифрование AES-256 для максимальной защиты. Идеально для конфиденциальной переписки. Незначительно повышает расход заряда батареи.';

  @override
  String get channelWizardPrivacyMaxTitle => 'Максимальная защита';

  @override
  String get channelWizardPrivacyOpenDesc =>
      'Без шифрования. Любой пользователь с совместимым радиоустройством сможет читать ваши сообщения. Используйте только для публичных трансляций.';

  @override
  String get channelWizardPrivacyOpenTitle => 'Открытый канал';

  @override
  String get channelWizardPrivacyPrivateDesc =>
      'Шифрование AES-128 со случайным ключом. Присоединиться смогут только те, кому вы передадите QR-код. Рекомендуется для большинства случаев.';

  @override
  String get channelWizardPrivacyPrivateTitle => 'Приватный канал';

  @override
  String get channelWizardPrivacySharedDesc =>
      'Использует общеизвестный ключ по умолчанию. Другие пользователи Meshtastic могут читать сообщения. Подходит для публичных сообществ.';

  @override
  String get channelWizardPrivacySharedTitle => 'Общий канал';

  @override
  String get channelWizardPrivacySubtitle =>
      'Выберите уровень защиты канала. Более высокий уровень означает более стойкое шифрование.';

  @override
  String get channelWizardRadioComplianceLink =>
      'Посмотреть правила использования радиосвязи';

  @override
  String get channelWizardReviewEncryption => 'Шифрование';

  @override
  String get channelWizardReviewHeading => 'Проверка и создание';

  @override
  String get channelWizardReviewKeySize => 'Размер ключа';

  @override
  String get channelWizardReviewMqttDownlink =>
      'MQTT входящий канал (Downlink)';

  @override
  String get channelWizardReviewMqttUplink => 'MQTT исходящий канал (Uplink)';

  @override
  String get channelWizardReviewName => 'Имя';

  @override
  String get channelWizardReviewPositionSharing => 'Передача местоположения';

  @override
  String get channelWizardReviewPrivacyLevel => 'Уровень конфиденциальности';

  @override
  String get channelWizardReviewSubtitle =>
      'Проверьте настройки канала перед созданием.';

  @override
  String get channelWizardScreenTitle => 'Создать канал';

  @override
  String get channelWizardStepNameContent =>
      'Придумайте запоминающееся имя для вашего канала.\n\n• Имя ограничено 12 символами\n• Допустимы только буквы и цифры\n• Имя видно всем, кто присоединится\n• Выбирайте что-то понятное, например «Семья» или «Поход»';

  @override
  String get channelWizardStepNameTitle => 'Имя канала';

  @override
  String get channelWizardStepOptionsContent =>
      'Настройте дополнительные параметры канала.\n\n• Передача местоположения: разрешить геолокацию в этом канале\n• MQTT Uplink: отправлять сообщения в интернет (требует настройки MQTT)\n• MQTT Downlink: получать сообщения из интернета\n• Ключ шифрования: генерируется автоматически, но можно вставить собственный\n\nБольшинству пользователей эти расширенные настройки не нужны.';

  @override
  String get channelWizardStepOptionsTitle => 'Дополнительные параметры';

  @override
  String get channelWizardStepPrivacyContent =>
      'Выберите уровень защиты вашего канала.\n\n• ОТКРЫТЫЙ: без шифрования — сообщения может читать каждый\n• ОБЩИЙ: использует стандартный ключ Meshtastic — не является приватным\n• ПРИВАТНЫЙ (рекомендуется): уникальный ключ AES-128 — безопасный\n• МАКСИМАЛЬНЫЙ: шифрование AES-256 — наивысший уровень защиты\n\nПри более высоком уровне защиты необходимо передать ключ канала другим участникам.';

  @override
  String get channelWizardStepPrivacyTitle => 'Уровень конфиденциальности';

  @override
  String get channelWizardStepReviewContent =>
      'Проверьте настройки канала перед созданием.\n\n• Убедитесь, что имя и уровень конфиденциальности верны\n• После создания поделитесь QR-кодом с другими участниками\n• Другие сканируют QR-код, чтобы присоединиться к каналу\n• Можно также скопировать URL и отправить его в виде текста';

  @override
  String get channelWizardStepReviewTitle => 'Проверка и создание';

  @override
  String get channelWizardSummaryEncryption => 'Шифрование';

  @override
  String get channelWizardSummaryName => 'Имя';

  @override
  String get channelWizardSummaryPrivacy => 'Конфиденциальность';

  @override
  String get channelWizardUplinkSubtitle =>
      'Отправлять сообщения из этого канала в MQTT при наличии подключения к интернету.';

  @override
  String get channelWizardUplinkTitle => 'Исходящий канал (Uplink) включён';

  @override
  String get channelWizardUrlCopied => 'URL канала скопирован в буфер обмена';

  @override
  String get channelsClearSearch => 'Очистить поиск';

  @override
  String channelsDefaultChannelName(int index) {
    return 'Канал $index';
  }

  @override
  String get channelsEmpty => 'Каналы не настроены';

  @override
  String get channelsEmptySubtitle =>
      'Каналы ещё загружаются с устройства\nили воспользуйтесь значками выше, чтобы добавить каналы';

  @override
  String get channelsFilterAll => 'Все';

  @override
  String get channelsFilterEncrypted => 'Зашифрованные';

  @override
  String get channelsFilterMqtt => 'MQTT';

  @override
  String get channelsFilterPosition => 'Местоположение';

  @override
  String get channelsFilterPrimary => 'Основной';

  @override
  String get channelsMenuAddChannel => 'Добавить канал';

  @override
  String get channelsMenuHelp => 'Справка';

  @override
  String get channelsMenuScanQrCode => 'Сканировать QR-код';

  @override
  String get channelsMenuSettings => 'Настройки';

  @override
  String channelsNoMatch(String query) {
    return 'Каналов, соответствующих «$query», не найдено';
  }

  @override
  String get channelsPrimaryChannelName => 'Основной канал';

  @override
  String channelsScreenTitle(int count) {
    return 'Каналы ($count)';
  }

  @override
  String get channelsSearchHint => 'Поиск каналов';

  @override
  String get channelsTileEncrypted => 'Зашифрован';

  @override
  String get channelsTileNoEncryption => 'Без шифрования';

  @override
  String get channelsTilePrimaryBadge => 'ОСНОВНОЙ';

  @override
  String get channelsUnreadOverflow => '99+';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonDone => 'Готово';

  @override
  String commonErrorWithDetails(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get commonGoBack => 'Назад';

  @override
  String get commonNext => 'Далее';

  @override
  String get commonNever => 'Никогда';

  @override
  String get commonJustNow => 'только что';

  @override
  String commonMinutesAgo(int count) {
    return '$count мин. назад';
  }

  @override
  String commonHoursAgo(int count) {
    return '$count ч. назад';
  }

  @override
  String commonDaysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String commonHopsSingular(int count) {
    return '$count хоп';
  }

  @override
  String commonHopsPlural(int count) {
    return '$count хопа';
  }

  @override
  String nodeInfoLatitude(String value) {
    return 'Шир: $value°';
  }

  @override
  String nodeInfoLongitude(String value) {
    return 'Дол: $value°';
  }

  @override
  String get nodeInfoNotAvailable => 'Н/Д';

  @override
  String get nodeInfoYou => 'ВЫ';

  @override
  String get nodeInfoPosition => 'Позиция';

  @override
  String get nodeInfoMessage => 'Сообщение';

  @override
  String get nodeInfoTraceroute => 'Traceroute';

  @override
  String get nodeInfoViewDetails => 'View Details';

  @override
  String get nodeInfoViewHistory => 'Traceroute History';

  @override
  String get nodeInfoShareLocation => 'Share Location';

  @override
  String get nodeInfoCopyCoordinates => 'Copy Coordinates';

  @override
  String get nodeInfoPositionConfirmTitle => 'Request Position';

  @override
  String nodeInfoPositionConfirmMessage(String name) {
    return 'Request $name\'s current position over the mesh?';
  }

  @override
  String get nodeInfoShareConfirmTitle => 'Share Location';

  @override
  String get nodeInfoShareConfirmMessage =>
      'Share this node\'s coordinates as a link?';

  @override
  String get nodeInfoTracerouteConfirmTitle => 'Send Traceroute';

  @override
  String nodeInfoTracerouteConfirmMessage(String name) {
    return 'Send a traceroute packet to $name? This uses mesh airtime.';
  }

  @override
  String get bindingSelectorNoResults => 'Переменные не найдены';

  @override
  String get commonOk => 'OК';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get debugScreenAppLogTitle => 'Журнал приложения';

  @override
  String get debugScreenApply => 'Применить';

  @override
  String get debugScreenAutoScrollOff => 'Автопрокрутка выключена';

  @override
  String get debugScreenAutoScrollOn => 'Автопрокрутка включена';

  @override
  String get debugScreenClear => 'Очистить';

  @override
  String get debugScreenClearLogsMenuItem => 'Очистить журналы';

  @override
  String get debugScreenClearLogsMessage =>
      'Вы уверены, что хотите удалить все журналы?';

  @override
  String get debugScreenClearLogsTitle => 'Очистить журналы';

  @override
  String get debugScreenClearMenuItem => 'Очистить';

  @override
  String get debugScreenCopy => 'Копировать';

  @override
  String get debugScreenCopyToClipboard => 'Копировать в буфер обмена';

  @override
  String get debugScreenDebugExportMessage =>
      'Этот экспорт содержит сведения об устройстве, состояние подключения, список нод, метаданные маршрутов и последние журналы приложения.\n\nТекст сообщений скрыт, координаты GPS огрублены. Проверьте файл перед отправкой.';

  @override
  String get debugScreenDebugExportTitle => 'Экспорт отладки';

  @override
  String get debugScreenDeviceApply => 'Применить';

  @override
  String get debugScreenDeviceAutoScrollOff => 'Автопрокрутка ВЫКЛ';

  @override
  String get debugScreenDeviceAutoScrollOn => 'Автопрокрутка ВКЛ';

  @override
  String get debugScreenDeviceClear => 'Очистить';

  @override
  String get debugScreenDeviceClearMessage =>
      'Вы уверены, что хотите удалить все журналы устройства?';

  @override
  String get debugScreenDeviceClearTitle => 'Очистить журналы';

  @override
  String debugScreenDeviceEntryCount(int count) {
    return '$count записей';
  }

  @override
  String get debugScreenDeviceFilterSubtitle => 'Выберите отображаемые уровни';

  @override
  String get debugScreenDeviceFilterTitle => 'Фильтр уровней журнала';

  @override
  String get debugScreenDeviceLogsCopied =>
      'Журналы устройства скопированы в буфер обмена';

  @override
  String get debugScreenDeviceLogsTitle => 'Журналы устройства';

  @override
  String get debugScreenDeviceSearchHint => 'Поиск в журналах...';

  @override
  String debugScreenEntryCount(int count) {
    return '$count записей';
  }

  @override
  String get debugScreenExport => 'Экспорт';

  @override
  String get debugScreenExportDebugJson => 'Экспортировать JSON отладки';

  @override
  String debugScreenExportFailed(String error) {
    return 'Экспорт не выполнен: $error';
  }

  @override
  String get debugScreenFilter => 'Фильтр';

  @override
  String get debugScreenFilterLevelsTooltip => 'Фильтр уровней';

  @override
  String get debugScreenFilterLogLevels => 'Фильтр уровней журнала';

  @override
  String get debugScreenFilterSubtitle => 'Выберите отображаемые уровни';

  @override
  String get debugScreenFiltered => 'Отфильтровано';

  @override
  String get debugScreenGeneratingExport => 'Создание экспорта отладки...';

  @override
  String get debugScreenLogCopied => 'Журнал скопирован в буфер обмена';

  @override
  String get debugScreenLogsWillAppear =>
      'Журналы будут появляться здесь по мере поступления от устройства';

  @override
  String get debugScreenNoDeviceLogs => 'Журналов устройства ещё нет';

  @override
  String get debugScreenNoLogEntries => 'Записей журнала нет';

  @override
  String get debugScreenSearchLogsHint => 'Поиск в журналах...';

  @override
  String get debugScreenShare => 'Поделиться';

  @override
  String get debugScreenShareLog => 'Поделиться журналом';

  @override
  String get debugScreenStreamingBanner =>
      'Получение отладочных журналов прошивки с подключённого устройства через BLE';

  @override
  String get deviceConfigBleName => 'Имя BLE';

  @override
  String get deviceConfigBroadcastEighteenHours => 'Восемнадцать часов';

  @override
  String get deviceConfigBroadcastFiveHours => 'Пять часов';

  @override
  String get deviceConfigBroadcastFortyEightHours => 'Сорок восемь часов';

  @override
  String get deviceConfigBroadcastFourHours => 'Четыре часа';

  @override
  String get deviceConfigBroadcastInterval => 'Интервал трансляции';

  @override
  String get deviceConfigBroadcastIntervalSubtitle =>
      'Как часто транслировать информацию о ноде в сеть';

  @override
  String get deviceConfigBroadcastNever => 'Никогда';

  @override
  String get deviceConfigBroadcastSeventyTwoHours => 'Семьдесят два часа';

  @override
  String get deviceConfigBroadcastSixHours => 'Шесть часов';

  @override
  String get deviceConfigBroadcastThirtySixHours => 'Тридцать шесть часов';

  @override
  String get deviceConfigBroadcastThreeHours => 'Три часа';

  @override
  String get deviceConfigBroadcastTwelveHours => 'Двенадцать часов';

  @override
  String get deviceConfigBroadcastTwentyFourHours => 'Двадцать четыре часа';

  @override
  String get deviceConfigButtonGpio => 'GPIO кнопки';

  @override
  String get deviceConfigBuzzerAllEnabled => 'Все включены';

  @override
  String get deviceConfigBuzzerAllEnabledDesc =>
      'Зуммер сигнализирует обо всех событиях, включая нажатия кнопок и оповещения.';

  @override
  String get deviceConfigBuzzerDirectMsgOnly => 'Только личные сообщения';

  @override
  String get deviceConfigBuzzerDirectMsgOnlyDesc =>
      'Зуммер срабатывает только для личных сообщений и оповещений.';

  @override
  String get deviceConfigBuzzerDisabled => 'Отключён';

  @override
  String get deviceConfigBuzzerDisabledDesc =>
      'Все звуковые сигналы зуммера отключены.';

  @override
  String get deviceConfigBuzzerGpio => 'GPIO зуммера';

  @override
  String get deviceConfigBuzzerNotificationsOnly => 'Только уведомления';

  @override
  String get deviceConfigBuzzerNotificationsOnlyDesc =>
      'Зуммер срабатывает только для уведомлений и оповещений, но не при нажатии кнопок.';

  @override
  String get deviceConfigBuzzerSystemOnly => 'Только системные';

  @override
  String get deviceConfigBuzzerSystemOnlyDesc =>
      'Только нажатия кнопок, включение и выключение устройства. Без оповещений.';

  @override
  String get deviceConfigDisableLedHeartbeat => 'Отключить мигание LED';

  @override
  String get deviceConfigDisableLedHeartbeatSubtitle =>
      'Выключить мигающий индикатор состояния';

  @override
  String get deviceConfigDisableTripleClick => 'Отключить тройное нажатие';

  @override
  String get deviceConfigDisableTripleClickSubtitle =>
      'Отключить тройное нажатие для переключения GPS';

  @override
  String get deviceConfigDoubleTapAsButton => 'Двойное касание как кнопка';

  @override
  String get deviceConfigDoubleTapAsButtonSubtitle =>
      'Обрабатывать двойное касание акселерометра как нажатие кнопки';

  @override
  String get deviceConfigFactoryReset => 'Сброс к заводским настройкам';

  @override
  String get deviceConfigFactoryResetDialogConfirm => 'Сбросить';

  @override
  String get deviceConfigFactoryResetDialogMessage =>
      'Это сбросит ВСЕ настройки устройства к заводским значениям, включая каналы, конфигурацию и сохранённые данные.\n\nДействие нельзя отменить!';

  @override
  String get deviceConfigFactoryResetDialogTitle =>
      'Сброс к заводским настройкам';

  @override
  String deviceConfigFactoryResetError(String error) {
    return 'Не удалось выполнить сброс: $error';
  }

  @override
  String get deviceConfigFactoryResetSubtitle =>
      'Сбросить устройство к заводским настройкам';

  @override
  String get deviceConfigFactoryResetSuccess =>
      'Сброс к заводским настройкам начат — устройство перезагружается';

  @override
  String get deviceConfigFrequencyOverride => 'Переопределение частоты (MHz)';

  @override
  String get deviceConfigFrequencyOverrideHint =>
      '0.0 (использовать по умолчанию)';

  @override
  String get deviceConfigGpioWarning =>
      'Изменяйте эти параметры только если вы знаете, что ваше устройство требует нестандартных GPIO-пинов.';

  @override
  String get deviceConfigHamModeInfo =>
      'Режим HAM использует ваше полное имя в качестве позывного (макс. 8 символов), транслирует информацию о ноде каждые 10 минут, переопределяет частоту, рабочий цикл и мощность передачи, а также отключает шифрование.';

  @override
  String get deviceConfigHamModeWarning =>
      'Ноды HAM не могут ретранслировать зашифрованный трафик. Другие ноды сети без режима HAM не смогут маршрутизировать зашифрованные сообщения через эту ноду, создавая разрыв в ретрансляции.';

  @override
  String get deviceConfigHardware => 'Аппаратная часть';

  @override
  String get deviceConfigLicensedOperator => 'Лицензированный оператор (HAM)';

  @override
  String get deviceConfigLicensedOperatorSubtitle =>
      'Задаёт позывной, переопределяет частоту и мощность, отключает шифрование';

  @override
  String get deviceConfigLongName => 'Полное имя';

  @override
  String get deviceConfigLongNameHint => 'Введите отображаемое имя';

  @override
  String get deviceConfigLongNameSubtitle => 'Отображаемое имя, видимое в сети';

  @override
  String get deviceConfigNameHelpText =>
      'Имя вашего устройства транслируется в сеть и видно другим нодам.';

  @override
  String get deviceConfigNodeNumber => 'Номер ноды';

  @override
  String get deviceConfigPosixTimezone => 'POSIX-часовой пояс';

  @override
  String get deviceConfigPosixTimezoneExample =>
      'например, EST5EDT,M3.2.0,M11.1.0';

  @override
  String get deviceConfigPosixTimezoneHint => 'Оставьте пустым для UTC';

  @override
  String get deviceConfigRebootWarning =>
      'Изменения конфигурации устройства приведут к его перезагрузке.';

  @override
  String get deviceConfigRebroadcastAll => 'Все';

  @override
  String get deviceConfigRebroadcastAllDesc =>
      'Ретранслировать любое обнаруженное сообщение. Поведение по умолчанию.';

  @override
  String get deviceConfigRebroadcastAllSkipDecoding =>
      'Все (без декодирования)';

  @override
  String get deviceConfigRebroadcastAllSkipDecodingDesc =>
      'Ретранслировать все сообщения без декодирования. Быстрее, меньше нагрузка на CPU.';

  @override
  String get deviceConfigRebroadcastCorePortnumsOnly =>
      'Только основные номера портов';

  @override
  String get deviceConfigRebroadcastCorePortnumsOnlyDesc =>
      'Ретранслировать только основные пакеты Meshtastic (позиция, телеметрия и т.д.).';

  @override
  String get deviceConfigRebroadcastKnownOnly => 'Только известные';

  @override
  String get deviceConfigRebroadcastKnownOnlyDesc =>
      'Ретранслировать только сообщения от нод из базы данных нод.';

  @override
  String get deviceConfigRebroadcastLocalOnly => 'Только локальные';

  @override
  String get deviceConfigRebroadcastLocalOnlyDesc =>
      'Ретранслировать только сообщения от локальных отправителей. Подходит для изолированных сетей.';

  @override
  String get deviceConfigRebroadcastNone => 'Нет';

  @override
  String get deviceConfigRebroadcastNoneDesc =>
      'Не ретранслировать никакие сообщения. Нода только принимает.';

  @override
  String deviceConfigRemoteAdminConfiguring(String nodeName) {
    return 'Настройка: $nodeName';
  }

  @override
  String get deviceConfigRemoteAdminTitle => 'Удалённое администрирование';

  @override
  String get deviceConfigResetNodeDb => 'Сбросить базу данных нод';

  @override
  String get deviceConfigResetNodeDbDialogConfirm => 'Сбросить';

  @override
  String get deviceConfigResetNodeDbDialogMessage =>
      'Это удалит всю сохранённую информацию о нодах с устройства. Сети потребуется заново обнаружить все ноды.\n\nВы уверены, что хотите продолжить?';

  @override
  String get deviceConfigResetNodeDbDialogTitle => 'Сбросить базу данных нод';

  @override
  String deviceConfigResetNodeDbError(String error) {
    return 'Не удалось выполнить сброс: $error';
  }

  @override
  String get deviceConfigResetNodeDbSubtitle =>
      'Удалить всю сохранённую информацию о нодах';

  @override
  String get deviceConfigResetNodeDbSuccess => 'Сброс базы данных нод начат';

  @override
  String get deviceConfigRoleClient => 'Клиент';

  @override
  String get deviceConfigRoleClientBase => 'Базовый клиент';

  @override
  String get deviceConfigRoleClientBaseDesc =>
      'Базовая станция для избранных нод. Маршрутизирует их пакеты как маршрутизатор, остальные — как клиент.';

  @override
  String get deviceConfigRoleClientDesc =>
      'Роль по умолчанию. Пакеты сети маршрутизируются через эту ноду. Может отправлять и получать сообщения.';

  @override
  String get deviceConfigRoleClientHidden => 'Скрытый клиент';

  @override
  String get deviceConfigRoleClientHiddenDesc =>
      'Работает как клиент, но скрыт из списка нод. По-прежнему маршрутизирует трафик.';

  @override
  String get deviceConfigRoleClientMute => 'Немой клиент';

  @override
  String get deviceConfigRoleClientMuteDesc =>
      'Аналогично клиенту, но не передаёт собственные сообщения. Полезно для мониторинга.';

  @override
  String get deviceConfigRoleLostAndFound => 'Бюро находок';

  @override
  String get deviceConfigRoleLostAndFoundDesc =>
      'Оптимизировано для поиска потерянных устройств. Периодически отправляет маяки.';

  @override
  String get deviceConfigRoleRouter => 'Маршрутизатор';

  @override
  String get deviceConfigRoleRouterDesc =>
      'Маршрутизирует пакеты сети между нодами. Экран и Bluetooth отключены для экономии питания.';

  @override
  String get deviceConfigRoleRouterLate => 'Запоздалый маршрутизатор';

  @override
  String get deviceConfigRoleRouterLateDesc =>
      'Ретранслирует все пакеты после других маршрутизаторов. Расширяет зону покрытия без расхода приоритетных переходов.';

  @override
  String get deviceConfigRoleSensor => 'Сенсор';

  @override
  String get deviceConfigRoleSensorDesc =>
      'Предназначен для дистанционного сбора данных. Передаёт телеметрию через заданные интервалы.';

  @override
  String get deviceConfigRoleTak => 'TAK';

  @override
  String get deviceConfigRoleTakDesc =>
      'Интеграция с Team Awareness Kit. Соединяет Meshtastic и системы TAK.';

  @override
  String get deviceConfigRoleTakTracker => 'TAK-трекер';

  @override
  String get deviceConfigRoleTakTrackerDesc =>
      'Сочетание режимов TAK и трекера.';

  @override
  String get deviceConfigRoleTracker => 'Трекер';

  @override
  String get deviceConfigRoleTrackerDesc =>
      'Оптимизировано для GPS-трекинга. Отправляет обновления позиции через заданные интервалы.';

  @override
  String get deviceConfigSave => 'Сохранить';

  @override
  String get deviceConfigSaveAndReboot => 'Сохранить и перезагрузить';

  @override
  String get deviceConfigSaveChangesMessage =>
      'Сохранение конфигурации устройства приведёт к его перезагрузке. Вы будете кратковременно отключены на время перезапуска.';

  @override
  String get deviceConfigSaveChangesTitle => 'Сохранить изменения?';

  @override
  String deviceConfigSaveError(String error) {
    return 'Ошибка сохранения конфигурации: $error';
  }

  @override
  String get deviceConfigSavedLocal =>
      'Конфигурация сохранена — устройство перезагружается';

  @override
  String get deviceConfigSavedRemote =>
      'Конфигурация отправлена на удалённая нода';

  @override
  String get deviceConfigSectionButtonInput => 'Кнопки и ввод';

  @override
  String get deviceConfigSectionBuzzer => 'Зуммер';

  @override
  String get deviceConfigSectionDangerZone => 'Опасная зона';

  @override
  String get deviceConfigSectionDeviceInfo => 'Информация об устройстве';

  @override
  String get deviceConfigSectionDeviceRole => 'Роль устройства';

  @override
  String get deviceConfigSectionGpio => 'GPIO (дополнительно)';

  @override
  String get deviceConfigSectionLed => 'LED';

  @override
  String get deviceConfigSectionNodeInfoBroadcast =>
      'Трансляция информации о ноде';

  @override
  String get deviceConfigSectionRebroadcastMode => 'Режим ретрансляции';

  @override
  String get deviceConfigSectionSerial => 'Последовательный порт';

  @override
  String get deviceConfigSectionTimezone => 'Часовой пояс';

  @override
  String get deviceConfigSectionUserFlags => 'Пользовательские флаги';

  @override
  String get deviceConfigSerialConsole => 'Консоль последовательного порта';

  @override
  String get deviceConfigSerialConsoleSubtitle =>
      'Включить последовательный порт для отладки';

  @override
  String get deviceConfigShortName => 'Короткое имя';

  @override
  String get deviceConfigShortNameHint => 'например, FUZZ';

  @override
  String deviceConfigShortNameSubtitle(int maxLength) {
    return 'Макс. $maxLength символов (A-Z, 0-9)';
  }

  @override
  String get deviceConfigTitle => 'Конфигурация устройства';

  @override
  String get deviceConfigTitleRemote => 'Конфигурация устройства (удалённая)';

  @override
  String get deviceConfigTxPower => 'Мощность передачи (TX)';

  @override
  String deviceConfigTxPowerValue(int power) {
    return '$power dBm';
  }

  @override
  String get deviceConfigUnknown => 'Неизвестно';

  @override
  String get deviceConfigUnmessagable => 'Недоступен для сообщений';

  @override
  String get deviceConfigUnmessagableSubtitle =>
      'Пометить как инфраструктурную ноду, не отвечающий на сообщения';

  @override
  String get deviceConfigUserId => 'ID пользователя';

  @override
  String get deviceSheetActionAppSettings => 'Настройки приложения';

  @override
  String get deviceSheetActionAppSettingsSubtitle =>
      'Уведомления, тема оформления, настройки';

  @override
  String get deviceSheetActionDeviceConfig => 'Конфигурация устройства';

  @override
  String get deviceSheetActionDeviceConfigSubtitle =>
      'Настроить роль и параметры устройства';

  @override
  String get deviceSheetActionDeviceManagement => 'Управление устройством';

  @override
  String get deviceSheetActionDeviceManagementSubtitle =>
      'Настройки радио, дисплея, питания и позиции';

  @override
  String get deviceSheetActionResetNodeDb => 'Сбросить базу данных нод';

  @override
  String get deviceSheetActionResetNodeDbSubtitle =>
      'Удалить все известные ноды с устройства';

  @override
  String get deviceSheetActionScanQr => 'Сканировать QR-код';

  @override
  String get deviceSheetActionScanQrSubtitle =>
      'Импортировать ноды, каналы или автоматизации';

  @override
  String get deviceSheetAddress => 'Адрес';

  @override
  String get deviceSheetBattery => 'Аккумулятор';

  @override
  String deviceSheetBatteryPercent(String percent) {
    return '$percent%';
  }

  @override
  String get deviceSheetBatteryRefreshFailed => 'Ошибка';

  @override
  String get deviceSheetBatteryRefreshIdle =>
      'Получить уровень заряда с устройства';

  @override
  String deviceSheetBatteryRefreshResult(String percent, String millivolts) {
    return '$percent%$millivolts';
  }

  @override
  String get deviceSheetBluetoothLe => 'Bluetooth LE';

  @override
  String get deviceSheetCharging => 'Зарядка';

  @override
  String get deviceSheetConnected => 'Подключено';

  @override
  String get deviceSheetConnecting => 'Подключение...';

  @override
  String get deviceSheetConnectionType => 'Тип подключения';

  @override
  String get deviceSheetDeviceName => 'Имя устройства';

  @override
  String get deviceSheetDisconnectButton => 'Отключить';

  @override
  String get deviceSheetDisconnectDialogConfirm => 'Отключить';

  @override
  String get deviceSheetDisconnectDialogMessage =>
      'Вы уверены, что хотите отключиться от этого устройства?';

  @override
  String get deviceSheetDisconnectDialogTitle => 'Отключить';

  @override
  String get deviceSheetDisconnected => 'Отключено';

  @override
  String get deviceSheetDisconnecting => 'Отключение...';

  @override
  String get deviceSheetDisconnectingButton => 'Отключение...';

  @override
  String get deviceSheetError => 'Ошибка';

  @override
  String get deviceSheetFirmware => 'Прошивка';

  @override
  String get deviceSheetInfoCardConnected => 'Подключено';

  @override
  String get deviceSheetInfoCardConnecting => 'Подключение...';

  @override
  String get deviceSheetInfoCardConnectionError => 'Ошибка подключения';

  @override
  String get deviceSheetInfoCardDisconnected => 'Отключено';

  @override
  String get deviceSheetInfoCardDisconnecting => 'Отключение...';

  @override
  String get deviceSheetNoDevice => 'Нет устройства';

  @override
  String get deviceSheetNodeId => 'ID ноды';

  @override
  String get deviceSheetNodeName => 'Имя ноды';

  @override
  String get deviceSheetProtocol => 'Протокол';

  @override
  String get deviceSheetReconnecting => 'Переподключение...';

  @override
  String get deviceSheetRefreshBattery => 'Обновить данные аккумулятора';

  @override
  String get deviceSheetRefreshingBattery =>
      'Обновление данных аккумулятора...';

  @override
  String get deviceSheetResetNodeDbDialogConfirm => 'Сбросить';

  @override
  String get deviceSheetResetNodeDbDialogMessage =>
      'Это удалит все известные ноды с устройства и из приложения. Устройству потребуется заново обнаружить ноды в сети.\n\nВы уверены, что хотите продолжить?';

  @override
  String get deviceSheetResetNodeDbDialogTitle => 'Сбросить базу данных нод';

  @override
  String deviceSheetResetNodeDbError(String error) {
    return 'Не удалось сбросить базу данных нод: $error';
  }

  @override
  String get deviceSheetResetNodeDbSuccess =>
      'База данных нод успешно сброшена';

  @override
  String get deviceSheetScanForDevices => 'Сканировать устройства';

  @override
  String get deviceSheetSectionConnectionDetails => 'Сведения о подключении';

  @override
  String get deviceSheetSectionDeveloperTools => 'Инструменты разработчика';

  @override
  String get deviceSheetSectionQuickActions => 'Быстрые действия';

  @override
  String get deviceSheetSignalStrength => 'Уровень сигнала';

  @override
  String deviceSheetSignalStrengthValue(String rssi) {
    return '$rssi dBm';
  }

  @override
  String get deviceSheetStatus => 'Статус';

  @override
  String get deviceSheetUnknown => 'Неизвестно';

  @override
  String get deviceSheetUsb => 'USB';

  @override
  String get deviceShopBecomeSeller => 'Стать продавцом';

  @override
  String get deviceShopBecomeSellerBody =>
      'Вы являетесь производителем или дистрибьютором устройств, совместимых с Meshtastic? Присоединяйтесь к нашей торговой площадке и охватите энтузиастов по всему миру.';

  @override
  String get deviceShopBrowseByCategory => 'Просмотр по категориям';

  @override
  String get deviceShopCategories => 'Категории';

  @override
  String get deviceShopClear => 'Очистить';

  @override
  String get deviceShopConnectToBrowse =>
      'Подключитесь для просмотра устройств';

  @override
  String get deviceShopContactUs => 'Связаться с нами';

  @override
  String get deviceShopErrorLoadingProducts => 'Ошибка загрузки товаров';

  @override
  String get deviceShopFavoritesTooltip => 'Избранное';

  @override
  String get deviceShopFeatured => 'Рекомендуемые';

  @override
  String get deviceShopHelpTooltip => 'Помощь';

  @override
  String get deviceShopMarketplaceDisclaimer =>
      'Покупки совершаются в официальном магазине продавца. Socialmesh не несёт ответственности за оплату, доставку, гарантию и возвраты.';

  @override
  String get deviceShopMarketplaceInfoTitle => 'Информация о торговой площадке';

  @override
  String get deviceShopNewArrivals => 'Новинки';

  @override
  String get deviceShopNoInternet => 'Нет подключения к интернету';

  @override
  String deviceShopNoResults(String query) {
    return 'Нет результатов для «$query»';
  }

  @override
  String get deviceShopOfficialPartners => 'Официальные партнёры';

  @override
  String get deviceShopOnSale => 'Распродажа';

  @override
  String get deviceShopOutOfStock => 'НЕТ В НАЛИЧИИ';

  @override
  String get deviceShopPopularDevices => 'Популярные устройства';

  @override
  String get deviceShopRecentSearches => 'Недавние запросы';

  @override
  String get deviceShopRetry => 'Повторить';

  @override
  String get deviceShopSearchHint => 'Поиск устройств, модулей, антенн...';

  @override
  String get deviceShopSeeAll => 'Смотреть все';

  @override
  String get deviceShopSellYourDevices =>
      'Продавайте ваши устройства Meshtastic';

  @override
  String get deviceShopSupportEmail => 'support@socialmesh.app';

  @override
  String get deviceShopTitle => 'Магазин устройств';

  @override
  String get deviceShopTrending => 'В тренде';

  @override
  String get deviceShopTryAgain => 'Повторите попытку через некоторое время';

  @override
  String get deviceShopTryDifferentKeywords =>
      'Попробуйте другие ключевые слова';

  @override
  String get deviceShopUnableToLoad => 'Не удалось загрузить товары';

  @override
  String deviceShopErrorWithDetails(String error) {
    return 'Ошибка: $error';
  }

  @override
  String deviceShopFailedToUploadImage(String error) {
    return 'Не удалось загрузить изображение: $error';
  }

  @override
  String deviceShopFailedToUploadLogo(String error) {
    return 'Не удалось загрузить логотип: $error';
  }

  @override
  String get deviceShopFieldRequired => 'Обязательное поле';

  @override
  String get deviceShopGoBackTooltip => 'Назад';

  @override
  String get deviceShopRefreshTooltip => 'Обновить';

  @override
  String deviceShopReviewSubmitFailed(String error) {
    return 'Не удалось отправить отзыв: $error';
  }

  @override
  String get discoveryDiscoveredBadge => 'ОБНАРУЖЕН';

  @override
  String discoveryNodesFound(int count) {
    return 'Найдено нод: $count';
  }

  @override
  String get discoveryScanningNetwork => 'Сканирование сети';

  @override
  String get discoverySearchingForNodes => 'Поиск нод...';

  @override
  String get discoverySignalExcellent => 'Отличный';

  @override
  String get discoverySignalGood => 'Хороший';

  @override
  String get discoverySignalWeak => 'Слабый';

  @override
  String get discoveryUnknownNode => 'Неизвестная нода';

  @override
  String get drawerAdminDashboard => 'Панель администратора';

  @override
  String get drawerAdminSectionHeader => 'АДМИНИСТРАТОР';

  @override
  String get drawerBadgeNew => 'НОВОЕ';

  @override
  String get drawerBadgePro => 'PRO';

  @override
  String get drawerBadgeTryIt => 'ПОПРОБУЙТЕ';

  @override
  String get drawerEnterpriseDeviceManagement => 'Управление устройствами';

  @override
  String get drawerEnterpriseExportDenied =>
      'Требуется роль Supervisor или Admin';

  @override
  String get drawerEnterpriseFieldReports => 'Полевые отчёты';

  @override
  String get drawerEnterpriseIncidents => 'Инциденты';

  @override
  String get drawerEnterpriseOrgSettings => 'Настройки организации';

  @override
  String get drawerEnterpriseReports => 'Отчёты';

  @override
  String get drawerEnterpriseSectionHeader => 'КОРПОРАТИВНОЕ';

  @override
  String get drawerEnterpriseTasks => 'Задачи';

  @override
  String get drawerEnterpriseUserManagement => 'Управление пользователями';

  @override
  String get drawerNodeNotConnected => 'Не подключён';

  @override
  String get drawerNodeOffline => 'Офлайн';

  @override
  String get drawerNodeOnline => 'Онлайн';

  @override
  String get explorerTitleCartographer => 'Картограф';

  @override
  String get explorerTitleCartographerDescription =>
      'Картографирует невидимую инфраструктуру';

  @override
  String get explorerTitleExplorer => 'Исследователь';

  @override
  String get explorerTitleExplorerDescription => 'Активно исследует сеть';

  @override
  String get explorerTitleLongRangeRecordHolder => 'Рекордсмен дальней связи';

  @override
  String get explorerTitleLongRangeRecordHolderDescription =>
      'Раздвигает границы дальности';

  @override
  String get explorerTitleMeshCartographer => 'Картограф сети';

  @override
  String get explorerTitleMeshCartographerDescription =>
      'Прокладывает регионы и маршруты';

  @override
  String get explorerTitleMeshVeteran => 'Ветеран сети';

  @override
  String get explorerTitleMeshVeteranDescription => 'Глубокое знание сети';

  @override
  String get explorerTitleNewcomer => 'Новичок';

  @override
  String get explorerTitleNewcomerDescription => 'Только начинает путь по сети';

  @override
  String get explorerTitleObserver => 'Наблюдатель';

  @override
  String get explorerTitleObserverDescription => 'Изучает сеть Mesh';

  @override
  String get explorerTitleSignalHunter => 'Охотник за сигналами';

  @override
  String get explorerTitleSignalHunterDescription =>
      'Ищет сигналы по всему диапазону';

  @override
  String get favoritesCancelCompare => 'Отменить сравнение';

  @override
  String get favoritesCannotCompare => 'Невозможно сравнить ноды вне сети';

  @override
  String get favoritesCharging => 'Зарядка';

  @override
  String get favoritesCompareNodes => 'Сравнить ноды';

  @override
  String get favoritesDelete => 'Удалить';

  @override
  String get favoritesEmptyDescription =>
      'Нажмите значок звезды на любом ноде, чтобы добавить его в избранное для быстрого доступа.';

  @override
  String get favoritesEmptyTitle => 'Избранного пока нет';

  @override
  String get favoritesErrorLoading => 'Ошибка загрузки избранного';

  @override
  String get favoritesNodeNotInMesh =>
      'Нода в данный момент не в сети. Проверьте позже.';

  @override
  String get favoritesNotInMesh => 'Не в сети';

  @override
  String get favoritesRemoveConfirm => 'Удалить';

  @override
  String favoritesRemoveMessage(String name) {
    return 'Удалить $name из избранного?';
  }

  @override
  String get favoritesRemoveTitle => 'Удалить из избранного?';

  @override
  String get favoritesRemoveTooltip => 'Удалить из избранного';

  @override
  String get favoritesRetry => 'Повторить';

  @override
  String get favoritesSelectFirst => 'Выберите первую ноду';

  @override
  String get favoritesSelectSecond => 'Выберите вторую ноду';

  @override
  String get favoritesTitle => 'Избранные ноды';

  @override
  String get featuredProductsDiscard => 'Отменить';

  @override
  String get featuredProductsEmpty => 'Нет рекомендуемых товаров';

  @override
  String get featuredProductsEmptySubtitle =>
      'Отметьте товары как рекомендуемые, чтобы управлять их порядком здесь';

  @override
  String get featuredProductsOrderUpdated => 'Порядок рекомендуемых обновлён';

  @override
  String get featuredProductsRemove => 'Удалить';

  @override
  String featuredProductsRemoveMessage(String name) {
    return 'Удалить «$name» из рекомендуемых товаров?';
  }

  @override
  String get featuredProductsRemoveTitle => 'Убрать из рекомендуемых';

  @override
  String get featuredProductsRemoveTooltip => 'Убрать из рекомендуемых';

  @override
  String get featuredProductsRemoved => 'Убрано из рекомендуемых';

  @override
  String get featuredProductsReorderInfo =>
      'Перетащите товары для изменения порядка. Товары вверху появятся первыми в разделе рекомендуемых.';

  @override
  String get featuredProductsSave => 'Сохранить';

  @override
  String get featuredProductsTitle => 'Рекомендуемые товары';

  @override
  String get featuredProductsUnsavedChanges => 'Есть несохранённые изменения';

  @override
  String get feedbackBugReportsTitle => 'Мои сообщения об ошибках';

  @override
  String get feedbackConversation => 'Диалог';

  @override
  String get feedbackFailedToLoad => 'Не удалось загрузить отчёты';

  @override
  String get feedbackFilterAll => 'Все';

  @override
  String get feedbackFilterAwaiting => 'Ожидающие';

  @override
  String get feedbackFilterOpen => 'Открытые';

  @override
  String get feedbackFilterResolved => 'Решённые';

  @override
  String get feedbackFilterResponded => 'С ответом';

  @override
  String get feedbackFormHint => 'Опишите проблему, с которой вы столкнулись';

  @override
  String get feedbackFormTitle => 'Сообщить об ошибке';

  @override
  String get feedbackFormValidationError => 'Пожалуйста, опишите проблему.';

  @override
  String get feedbackFormWhatHappened => 'Что произошло?';

  @override
  String get feedbackIncludeScreenshot => 'Включить снимок экрана в отчёт';

  @override
  String get feedbackNoBugReports => 'Сообщений об ошибках пока нет';

  @override
  String get feedbackNoBugReportsDesc =>
      'Встряхните устройство, чтобы сообщить об ошибке.\nВаши отчёты и ответы на них появятся здесь.';

  @override
  String get feedbackNoMatchFilter => 'Отчёты не соответствуют фильтру';

  @override
  String get feedbackNoMatchSearch => 'Отчёты не соответствуют запросу';

  @override
  String feedbackReplyFailed(String error) {
    return 'Не удалось отправить ответ: $error';
  }

  @override
  String get feedbackReplyHint => 'Написать ответ...';

  @override
  String get feedbackReplySent => 'Ответ отправлен';

  @override
  String get feedbackReportBugAction => 'Сообщить об ошибке';

  @override
  String get feedbackReportBugDescription =>
      'Если что-то работает неправильно, вы можете сообщить об этом, чтобы помочь улучшить Socialmesh для всех.';

  @override
  String get feedbackReportBugTitle => 'Сообщить об ошибке?';

  @override
  String get feedbackReportResolved => 'Этот отчёт решён';

  @override
  String get feedbackResponseAuthorSocialmesh => 'Socialmesh';

  @override
  String get feedbackResponseAuthorYou => 'Вы';

  @override
  String get feedbackRetry => 'Повторить';

  @override
  String get feedbackScreenshotSubtitle =>
      'Помогает нам быстрее диагностировать проблему';

  @override
  String get feedbackSearchReports => 'Поиск отчётов';

  @override
  String get feedbackSendButton => 'Отправить';

  @override
  String get feedbackSendingReport => 'Отправка отчёта об ошибке...';

  @override
  String get feedbackShakeToReport =>
      'Встряхните устройство, чтобы сообщить об ошибке';

  @override
  String get feedbackToggleOff => 'Отключите, чтобы деактивировать';

  @override
  String get feedbackWaitingForAdmin => 'Ожидание ответа администратора';

  @override
  String get feedbackYourReport => 'Ваш отчёт';

  @override
  String fileTransferAccepted(String filename) {
    return 'Принято: $filename';
  }

  @override
  String get fileTransferActionAccept => 'Принять';

  @override
  String get fileTransferActionCancel => 'Отмена';

  @override
  String get fileTransferActionDelete => 'Удалить';

  @override
  String get fileTransferActionInfo => 'Информация';

  @override
  String get fileTransferActionReject => 'Отклонить';

  @override
  String get fileTransferActionRetry => 'Повторить';

  @override
  String get fileTransferActionShare => 'Поделиться';

  @override
  String fileTransferAttachmentMeta(int size, String chunkCount) {
    return '$size · $chunkCount фрагментов по сети';
  }

  @override
  String fileTransferCardChunksProgress(String completed, String total) {
    return '$completed/$total chunks';
  }

  @override
  String fileTransferCardChunksTotal(String count) {
    return '$count chunks';
  }

  @override
  String fileTransferCardChunkSize(String size) {
    return '$size ea.';
  }

  @override
  String get fileTransferBinaryFileHint =>
      'Бинарный файл — сохраните, чтобы открыть во внешнем приложении';

  @override
  String get fileTransferCancelConfirm => 'Отменить передачу';

  @override
  String fileTransferCancelMessage(String filename) {
    return 'Отменить передачу файла «$filename»?';
  }

  @override
  String get fileTransferCancelTitle => 'Отменить передачу?';

  @override
  String get fileTransferCancelled => 'Передача отменена';

  @override
  String get fileTransferClearCompleted => 'Очистить завершённые';

  @override
  String get fileTransferClearConfirm => 'Очистить';

  @override
  String get fileTransferClearMessage =>
      'Удалить все завершённые, неудавшиеся и отменённые передачи? Отменить невозможно.';

  @override
  String get fileTransferClearTitle => 'Очистить завершённые передачи?';

  @override
  String fileTransferClearedCount(int count) {
    return 'Очищено $count передач';
  }

  @override
  String get fileTransferContactsClearSearch => 'Очистить поиск';

  @override
  String fileTransferContactsDaysAgo(int count) {
    return '$countд назад';
  }

  @override
  String get fileTransferContactsDetailReceived => 'Получено';

  @override
  String get fileTransferContactsDetailSent => 'Отправлено';

  @override
  String get fileTransferContactsDetailTotal => 'Итого';

  @override
  String get fileTransferContactsDiscoveredHint =>
      'Обнаруженные ноды появятся здесь';

  @override
  String get fileTransferContactsFilterActive => 'Активные';

  @override
  String get fileTransferContactsFilterAll => 'Все';

  @override
  String get fileTransferContactsFilterFavorites => 'Избранное';

  @override
  String get fileTransferContactsFilterHasFiles => 'С файлами';

  @override
  String fileTransferContactsHoursAgo(int count) {
    return '$countч назад';
  }

  @override
  String get fileTransferContactsJustNow => 'только что';

  @override
  String fileTransferContactsMinutesAgo(int count) {
    return '$countмин назад';
  }

  @override
  String fileTransferContactsNoMatchFilter(String filter) {
    return 'Нет контактов «$filter»';
  }

  @override
  String fileTransferContactsNoMatchSearch(String query) {
    return 'Нет контактов, соответствующих «$query»';
  }

  @override
  String get fileTransferContactsNoNodes => 'Нод в сети ещё нет';

  @override
  String get fileTransferContactsSearchHint => 'Поиск контактов';

  @override
  String get fileTransferContactsSectionActive => 'Активные';

  @override
  String get fileTransferContactsSectionFavorites => 'Избранное';

  @override
  String get fileTransferContactsSectionInactive => 'Неактивные';

  @override
  String get fileTransferContactsSectionWithFiles => 'С файлами';

  @override
  String get fileTransferContactsSendFile => 'Отправить файл';

  @override
  String get fileTransferContactsSendImage => 'Send Image';

  @override
  String fileTransferContactsStarted(String filename) {
    return 'Передача начата: $filename';
  }

  @override
  String get fileTransferContainerClearCompleted => 'Очистить завершённые';

  @override
  String get fileTransferContainerClearMessage =>
      'Удалить все завершённые, неудавшиеся и отменённые передачи? Отменить невозможно.';

  @override
  String get fileTransferContainerClearTitle =>
      'Очистить завершённые передачи?';

  @override
  String fileTransferContainerCleared(int count) {
    return 'Очищено $count передач';
  }

  @override
  String get fileTransferContainerMenuHelp => 'Help';

  @override
  String get fileTransferContainerPurgeExpired => 'Удалить просроченные';

  @override
  String get fileTransferContainerPurged => 'Просроченные передачи удалены';

  @override
  String get fileTransferContainerSendFile => 'Отправить файл';

  @override
  String get fileTransferContainerSendImage => 'Send Image';

  @override
  String get fileTransferContainerSendToNode => 'Отправить на ноду';

  @override
  String fileTransferContainerStarted(String filename) {
    return 'Передача начата: $filename';
  }

  @override
  String get fileTransferContainerTitle => 'Передача файлов';

  @override
  String get fileTransferCopiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get fileTransferCopyAction => 'Копировать';

  @override
  String fileTransferCouldNotReadFile(String error) {
    return 'Не удалось прочитать файл: $error';
  }

  @override
  String get fileTransferCouldNotRead => 'Не удалось прочитать файл.';

  @override
  String get fileTransferCouldNotSaveForSharing =>
      'Не удалось сохранить файл для отправки';

  @override
  String get fileTransferCouldNotStart =>
      'Не удалось начать передачу. Убедитесь, что нода подключена, и повторите попытку.';

  @override
  String get fileTransferDeleteConfirm => 'Удалить';

  @override
  String fileTransferDeleteMessage(String filename) {
    return 'Удалить «$filename»? Отменить невозможно.';
  }

  @override
  String get fileTransferDeleteTitle => 'Удалить передачу?';

  @override
  String fileTransferDeleted(String filename) {
    return 'Удалено: $filename';
  }

  @override
  String get fileTransferDetailsSection => 'Детали передачи';

  @override
  String get fileTransferDirectionReceived => 'Получено';

  @override
  String get fileTransferDirectionSent => 'Отправлено';

  @override
  String get fileTransferEmptyDescriptionContacts =>
      'Перейдите в «Контакты», нажмите на ноду\nи выберите «Отправить файл»';

  @override
  String get fileTransferEmptyDescriptionOverflow =>
      'Отправляйте файлы другим нодам через\nменю или NodeDex';

  @override
  String fileTransferEmptyFilterTitle(String filter) {
    return 'Нет передач «$filter»';
  }

  @override
  String get fileTransferEmptyTitle => 'Нет передач файлов';

  @override
  String get fileTransferExpiredPurged => 'Просроченные передачи удалены';

  @override
  String get fileTransferFileEmpty => 'Выбранный файл пуст.';

  @override
  String fileTransferFileTooLarge(
    String filename,
    String fileSize,
    String limit,
  ) {
    return '$filename — $fileSize КБ, а лимит передачи по сети составляет $limit КБ.';
  }

  @override
  String get fileTransferFilterActive => 'Активные';

  @override
  String get fileTransferFilterAll => 'Все';

  @override
  String get fileTransferFilterDone => 'Завершённые';

  @override
  String get fileTransferFilterReceived => 'Полученные';

  @override
  String get fileTransferFilterSent => 'Отправленные';

  @override
  String get fileTransferGoToContacts => 'Перейти в контакты';

  @override
  String get fileTransferImageDecodeError =>
      'Не удалось декодировать изображение';

  @override
  String get fileTransferImagePickerTitle => 'Send Image';

  @override
  String get fileTransferImagePickerCamera => 'Take Photo';

  @override
  String get fileTransferImagePickerCameraSubtitle =>
      'Use camera to take a photo';

  @override
  String get fileTransferImagePickerGallery => 'Choose from Gallery';

  @override
  String get fileTransferImagePickerGallerySubtitle =>
      'Select a photo from your library';

  @override
  String get fileTransferImagePickerCancel => 'Cancel';

  @override
  String get fileTransferImageCompressing =>
      'Compressing image for mesh transfer...';

  @override
  String fileTransferImageTooLargeAfterCompression(String limit) {
    return 'Image could not be compressed to fit within $limit KB mesh limit.';
  }

  @override
  String fileTransferImageCompressed(String size, String width, String height) {
    return 'Image compressed to $size bytes (${width}x$height)';
  }

  @override
  String get fileTransferInfoChunkSize => 'Размер фрагмента';

  @override
  String get fileTransferInfoChunks => 'Фрагменты';

  @override
  String get fileTransferInfoCompleted => 'Завершено';

  @override
  String get fileTransferInfoCreated => 'Создано';

  @override
  String get fileTransferInfoDirection => 'Направление';

  @override
  String get fileTransferInfoDirectionReceived => 'Получено';

  @override
  String get fileTransferInfoDirectionSent => 'Отправлено';

  @override
  String get fileTransferInfoExpires => 'Истекает';

  @override
  String get fileTransferInfoFailure => 'Сбой';

  @override
  String get fileTransferInfoMimeType => 'MIME-тип';

  @override
  String get fileTransferInfoNackRounds => 'Циклы NACK';

  @override
  String get fileTransferInfoSize => 'Размер';

  @override
  String get fileTransferInfoSourceNode => 'Нода-источник';

  @override
  String get fileTransferInfoStatus => 'Статус';

  @override
  String get fileTransferInfoTargetNode => 'Нода-получатель';

  @override
  String get fileTransferInfoTransferId => 'ID передачи';

  @override
  String fileTransferMoreBytes(int count) {
    return '... ещё $count байт';
  }

  @override
  String get fileTransferNoMatchFilter =>
      'Нет передач, соответствующих фильтру';

  @override
  String get fileTransferPinchToZoom => 'Сведите пальцы для масштабирования';

  @override
  String fileTransferGalleryToNode(String name) {
    return 'to $name';
  }

  @override
  String fileTransferGalleryFromNode(String name) {
    return 'from $name';
  }

  @override
  String get fileTransferGallerySentBadge => 'Sent';

  @override
  String get fileTransferGalleryReceivedBadge => 'Received';

  @override
  String fileTransferGallerySizeBadge(String size) {
    return '$size';
  }

  @override
  String fileTransferGalleryChunksBadge(String completed, String total) {
    return '$completed/$total chunks';
  }

  @override
  String fileTransferGalleryDurationBadge(String duration) {
    return '$duration';
  }

  @override
  String fileTransferGalleryHashBadge(String hash) {
    return 'SHA-256 $hash';
  }

  @override
  String get fileTransferGalleryViewDetails => 'Details';

  @override
  String get fileTransferGalleryMeshTransfer => 'Mesh Transfer';

  @override
  String fileTransferGalleryDurationSeconds(int count) {
    return '${count}s';
  }

  @override
  String fileTransferGalleryDurationMinutes(int count) {
    return '${count}m';
  }

  @override
  String fileTransferGalleryDurationHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get fileTransferPurgeExpired => 'Удалить просроченные';

  @override
  String get fileTransferRejectConfirm => 'Отклонить';

  @override
  String fileTransferRejectMessage(String filename) {
    return 'Отклонить входящий файл «$filename»? Отправитель будет уведомлён.';
  }

  @override
  String get fileTransferRejectTitle => 'Отклонить передачу?';

  @override
  String get fileTransferRejected => 'Передача отклонена';

  @override
  String get fileTransferSearchHint => 'Поиск передач';

  @override
  String get fileTransferSendAFile => 'Отправить файл';

  @override
  String get fileTransferSendFile => 'Отправить файл';

  @override
  String get fileTransferSendToNode => 'Отправить на ноду';

  @override
  String fileTransferStarted(String filename) {
    return 'Передача начата: $filename';
  }

  @override
  String get fileTransferTabContacts => 'Контакты';

  @override
  String get fileTransferTabFiles => 'Файлы';

  @override
  String get fileTransferTitle => 'Передача файлов';

  @override
  String fileTransferLineCount(int count) {
    return '$count строк';
  }

  @override
  String get firmwareUpdateAvailable => 'Доступно обновление';

  @override
  String get firmwareUpdateBackupWarningSubtitle =>
      'Обновления прошивки могут сбросить настройки устройства. Рекомендуется экспортировать настройки перед обновлением.';

  @override
  String get firmwareUpdateBackupWarningTitle =>
      'Создайте резервную копию настроек';

  @override
  String get firmwareUpdateBluetooth => 'Bluetooth';

  @override
  String get firmwareUpdateCheckFailed =>
      'Не удалось проверить наличие обновлений';

  @override
  String get firmwareUpdateChecking => 'Проверка обновлений...';

  @override
  String get firmwareUpdateDownload => 'Скачать обновление';

  @override
  String get firmwareUpdateHardware => 'Аппаратное обеспечение';

  @override
  String get firmwareUpdateInstalledFirmware => 'Установленная прошивка';

  @override
  String firmwareUpdateLatestVersion(String version) {
    return 'Последняя: $version';
  }

  @override
  String get firmwareUpdateNewBadge => 'НОВОЕ';

  @override
  String get firmwareUpdateNodeId => 'ID ноды';

  @override
  String get firmwareUpdateOpenWebFlasher => 'Открыть веб-прошивальщик';

  @override
  String get firmwareUpdateReleaseNotes => 'Примечания к выпуску';

  @override
  String get firmwareUpdateSectionAvailableUpdate => 'Доступное обновление';

  @override
  String get firmwareUpdateSectionCurrentVersion => 'Текущая версия';

  @override
  String get firmwareUpdateSectionHowToUpdate => 'Как обновить';

  @override
  String get firmwareUpdateStep1 =>
      'Скачайте файл прошивки для вашего устройства';

  @override
  String get firmwareUpdateStep2 => 'Подключите устройство через USB';

  @override
  String get firmwareUpdateStep3 =>
      'Используйте Meshtastic Web Flasher или CLI для прошивки';

  @override
  String get firmwareUpdateStep4 =>
      'Дождитесь перезагрузки устройства и повторного подключения';

  @override
  String get firmwareUpdateSupported => 'Поддерживается';

  @override
  String get firmwareUpdateTitle => 'Обновление прошивки';

  @override
  String get firmwareUpdateUnableToCheck => 'Не удалось проверить обновления';

  @override
  String get firmwareUpdateUnknown => 'Неизвестно';

  @override
  String get firmwareUpdateUpToDate => 'Актуальная версия';

  @override
  String get firmwareUpdateUptime => 'Время работы';

  @override
  String get firmwareUpdateVisitWebsite =>
      'Посетите сайт Meshtastic для получения последней прошивки.';

  @override
  String get firmwareUpdateWifi => 'WiFi';

  @override
  String get globeEmptyDescription =>
      'Здесь появятся ноды с данными о местоположении';

  @override
  String get globeEmptyTitle => 'Нет нод с GPS';

  @override
  String get globeHelp => 'Справка';

  @override
  String get globeHideConnections => 'Скрыть подключения';

  @override
  String globeNodeCount(int count) {
    return '$count нод';
  }

  @override
  String get globeResetView => 'Сбросить вид';

  @override
  String get globeScreenTitle => 'Глобус сети';

  @override
  String get globeSelectNode => 'Выбрать ноду';

  @override
  String get globeShowConnections => 'Показать подключения';

  @override
  String get gpsStatusAccuracy => 'Точность';

  @override
  String gpsStatusAccuracyValue(String meters) {
    return '±$meters м';
  }

  @override
  String get gpsStatusAcquiring => 'Получение GPS...';

  @override
  String get gpsStatusActiveBadge => 'АКТИВЕН';

  @override
  String get gpsStatusAltitude => 'Высота';

  @override
  String gpsStatusAltitudeValue(String meters) {
    return '$meters м';
  }

  @override
  String get gpsStatusCardinalE => 'В';

  @override
  String get gpsStatusCardinalN => 'С';

  @override
  String get gpsStatusCardinalNE => 'СВ';

  @override
  String get gpsStatusCardinalNW => 'СЗ';

  @override
  String get gpsStatusCardinalS => 'Ю';

  @override
  String get gpsStatusCardinalSE => 'ЮВ';

  @override
  String get gpsStatusCardinalSW => 'ЮЗ';

  @override
  String get gpsStatusCardinalW => 'З';

  @override
  String gpsStatusDateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String gpsStatusDaysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String get gpsStatusFixAcquired => 'GPS-фиксация получена';

  @override
  String get gpsStatusGroundSpeed => 'Путевая скорость';

  @override
  String gpsStatusGroundSpeedValue(String mps, String kmh) {
    return '$mps м/с ($kmh км/ч)';
  }

  @override
  String get gpsStatusGroundTrack => 'Курс над землёй';

  @override
  String gpsStatusGroundTrackValue(String degrees, String direction) {
    return '$degrees° $direction';
  }

  @override
  String gpsStatusHoursAgo(int count) {
    return '$count ч. назад';
  }

  @override
  String get gpsStatusLatitude => 'Широта';

  @override
  String gpsStatusLatitudeValue(String value) {
    return '$value°';
  }

  @override
  String get gpsStatusLongitude => 'Долгота';

  @override
  String gpsStatusLongitudeValue(String value) {
    return '$value°';
  }

  @override
  String gpsStatusMinutesAgo(int count) {
    return '$count мин. назад';
  }

  @override
  String get gpsStatusNoGpsFix => 'GPS-фиксация отсутствует';

  @override
  String get gpsStatusNoGpsFixMessage =>
      'Устройство ещё не получило GPS-координаты. Убедитесь, что у устройства открытый вид на небо.';

  @override
  String get gpsStatusOpenInMaps => 'Открыть в картах';

  @override
  String get gpsStatusPrecisionBits => 'Биты точности';

  @override
  String get gpsStatusSatFair => 'Удовлетворительно';

  @override
  String get gpsStatusSatGood => 'Хорошо';

  @override
  String get gpsStatusSatNoFix => 'Нет фиксации';

  @override
  String get gpsStatusSatPoor => 'Слабо';

  @override
  String gpsStatusSatellitesCount(int count) {
    return '$count спутников в зоне видимости';
  }

  @override
  String get gpsStatusSatellitesInView => 'Спутники в зоне видимости';

  @override
  String get gpsStatusSearchingSatellites => 'Поиск спутников...';

  @override
  String gpsStatusSecondsAgo(int count) {
    return '$count с. назад';
  }

  @override
  String get gpsStatusSectionLastUpdate => 'Последнее обновление';

  @override
  String get gpsStatusSectionMotion => 'Движение';

  @override
  String get gpsStatusSectionPosition => 'Положение';

  @override
  String get gpsStatusSectionSatellites => 'Спутники';

  @override
  String get gpsStatusTitle => 'Статус GPS';

  @override
  String gpsStatusTodayAt(String time) {
    return 'Сегодня в $time';
  }

  @override
  String get gpsStatusUnknown => 'Неизвестно';

  @override
  String get helpArticleLoadFailed => 'Не удалось загрузить статью';

  @override
  String helpArticleMinRead(int minutes) {
    return '$minutes мин чтения';
  }

  @override
  String get helpCenterArticleRead => 'Прочитано';

  @override
  String get helpCenterArticleUnread => 'Не прочитано';

  @override
  String get helpCenterArticlesRead => 'статей прочитано';

  @override
  String get helpCenterComeBackToRefresh =>
      'Возвращайтесь в любое время, чтобы освежить знания.';

  @override
  String get helpCenterCompleted => 'Завершено';

  @override
  String get helpCenterContentBeingPrepared =>
      'Справочные материалы готовятся. Заходите позже.';

  @override
  String get helpCenterFilterAll => 'Все';

  @override
  String helpCenterFindThisIn(String screenName) {
    return 'Найти здесь: $screenName';
  }

  @override
  String get helpCenterHapticFeedbackSubtitle =>
      'Вибрация при эффекте печатающего текста';

  @override
  String get helpCenterHapticFeedbackTitle => 'Тактильная обратная связь';

  @override
  String get helpCenterHelpPreferences => 'НАСТРОЙКИ СПРАВКИ';

  @override
  String get helpCenterInteractiveTours => 'Интерактивные туры';

  @override
  String get helpCenterLearnHowItWorks => 'Узнайте, как работает Meshtastic';

  @override
  String get helpCenterLoadFailed =>
      'Не удалось загрузить справочное содержимое';

  @override
  String get helpCenterMarkAsComplete => 'Отметить как завершённое';

  @override
  String get helpCenterNoArticlesAvailable => 'Статьи недоступны';

  @override
  String get helpCenterNoArticlesInCategory => 'В этой категории нет статей';

  @override
  String get helpCenterNoArticlesMatchSearch =>
      'По вашему запросу статьи не найдены.\nПопробуйте другие ключевые слова.';

  @override
  String get helpCenterReadEverything => 'Вы прочитали всё!';

  @override
  String get helpCenterResetAllProgress => 'Сбросить весь прогресс';

  @override
  String get helpCenterResetProgressLabel => 'Сбросить';

  @override
  String get helpCenterResetProgressMessage =>
      'Все статьи будут отмечены как непрочитанные, а прогресс интерактивных туров будет сброшен. Вы можете начать заново.';

  @override
  String get helpCenterResetProgressTitle => 'Сбросить прогресс в справке?';

  @override
  String get helpCenterScreenAether => 'Aether';

  @override
  String get helpCenterScreenAutomations => 'Автоматизации';

  @override
  String get helpCenterScreenChannels => 'Каналы';

  @override
  String get helpCenterScreenCreateSignal => 'Создать Сигнал';

  @override
  String get helpCenterScreenDeviceShop => 'Магазин устройств';

  @override
  String get helpCenterScreenGlobe => 'Глобус';

  @override
  String get helpCenterScreenMap => 'Карта';

  @override
  String get helpCenterScreenMesh3d => 'Mesh 3D';

  @override
  String get helpCenterScreenMeshHealth => 'Здоровье сети';

  @override
  String get helpCenterScreenMessages => 'Сообщения';

  @override
  String get helpCenterScreenNodeDex => 'NodeDex';

  @override
  String get helpCenterScreenNodes => 'Ноды';

  @override
  String get helpCenterScreenPresence => 'Присутствие';

  @override
  String get helpCenterScreenProfile => 'Профиль';

  @override
  String get helpCenterScreenRadioConfig => 'Настройка радио';

  @override
  String get helpCenterScreenReachability => 'Достижимость';

  @override
  String get helpCenterScreenRegionSelection => 'Выбор региона';

  @override
  String get helpCenterScreenRoutes => 'Маршруты';

  @override
  String get helpCenterScreenScanner => 'Сканер';

  @override
  String get helpCenterScreenSettings => 'Настройки';

  @override
  String get helpCenterScreenSignalFeed => 'Лента Сигналов';

  @override
  String get helpCenterScreenTakGateway => 'TAK Шлюз';

  @override
  String get helpCenterScreenTimeline => 'История';

  @override
  String get helpCenterScreenTraceRouteLog => 'Журнал трассировки маршрута';

  @override
  String get helpCenterScreenWidgetBuilder => 'Конструктор виджетов';

  @override
  String get helpCenterScreenWidgetDashboard => 'Панель виджетов';

  @override
  String get helpCenterScreenWidgetMarketplace => 'Маркетплейс виджетов';

  @override
  String get helpCenterScreenWorldMesh => 'Мировая сеть';

  @override
  String get helpCenterSearchByTitle =>
      'Поиск по названию статьи\nили описанию.';

  @override
  String get helpCenterSearchHint => 'Поиск статей';

  @override
  String get helpCenterShowHelpHintsSubtitle =>
      'Показывать мигающие кнопки справки на экранах';

  @override
  String get helpCenterShowHelpHintsTitle => 'Показывать подсказки';

  @override
  String get helpCenterTapToLearn =>
      'Нажмите на статью, чтобы узнать о mesh-сетях, настройках радио и многом другом.';

  @override
  String get helpCenterTitle => 'Справочный центр';

  @override
  String helpCenterToursCompletedCount(int completed, int total) {
    return '$completed / $total завершено';
  }

  @override
  String get helpCenterToursDescription =>
      'Пошаговые руководства по функциям приложения. Ico проведёт вас по каждому экрану.';

  @override
  String get helpCenterTryDifferentCategory =>
      'Попробуйте выбрать другую категорию с помощью фильтров выше.';

  @override
  String get incidentActionAssign => 'Назначить';

  @override
  String get incidentActionCancel => 'Отмена';

  @override
  String get incidentActionClose => 'Закрыть';

  @override
  String incidentActionDeniedTooltip(String roleHint) {
    return 'Требуется $roleHint';
  }

  @override
  String get incidentActionEscalate => 'Эскалировать';

  @override
  String get incidentActionFailedSnackbar => 'Действие не выполнено';

  @override
  String get incidentActionResolve => 'Устранить';

  @override
  String get incidentActionSubmit => 'Отправить';

  @override
  String incidentActionSuccessSnackbar(String action) {
    return 'Инцидент $action';
  }

  @override
  String get incidentAssignCancelButton => 'Отмена';

  @override
  String get incidentAssignConfirmButton => 'Назначить';

  @override
  String get incidentAssignSheetTitle => 'Назначить инцидент';

  @override
  String incidentAssignedLabel(String assigneeId) {
    return 'Назначено: $assigneeId';
  }

  @override
  String get incidentAssigneeHint => 'Введите ID пользователя';

  @override
  String get incidentAssigneeLabel => 'ID пользователя-исполнителя';

  @override
  String get incidentClassificationComms => 'Связь';

  @override
  String get incidentClassificationEnvironmental => 'Экологический';

  @override
  String get incidentClassificationLogistics => 'Логистика';

  @override
  String get incidentClassificationMedical => 'Медицинский';

  @override
  String get incidentClassificationOperational => 'Операционный';

  @override
  String get incidentClassificationSafety => 'Безопасность';

  @override
  String get incidentClassificationSecurity => 'Охрана';

  @override
  String get incidentCreateButtonLabel => 'Создать инцидент';

  @override
  String get incidentCreateCaptureLocation => 'Захватить местоположение';

  @override
  String get incidentCreateClassificationSection => 'Классификация';

  @override
  String get incidentCreateDescriptionHint => 'Подробное описание инцидента';

  @override
  String get incidentCreateDescriptionSection => 'Описание (необязательно)';

  @override
  String incidentCreateError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get incidentCreateFailed => 'Не удалось создать';

  @override
  String get incidentCreateGettingLocation => 'Получение местоположения...';

  @override
  String get incidentCreateLocationError =>
      'Не удалось получить местоположение';

  @override
  String incidentCreateLocationException(String error) {
    return 'Ошибка местоположения: $error';
  }

  @override
  String get incidentCreateLocationSection => 'Местоположение (необязательно)';

  @override
  String get incidentCreatePrioritySection => 'Приоритет';

  @override
  String get incidentCreateRemoveLocation => 'Удалить';

  @override
  String get incidentCreateScreenTitle => 'Создать инцидент';

  @override
  String get incidentCreateSubmitButton => 'Создать инцидент';

  @override
  String get incidentCreateSubmitting => 'Создание...';

  @override
  String get incidentCreateTitleHint => 'Краткое название инцидента';

  @override
  String get incidentCreateTitleRequired => 'Название обязательно';

  @override
  String get incidentCreateTitleSection => 'Название';

  @override
  String get incidentCreateTooltip => 'Создать инцидент';

  @override
  String get incidentCreatedSuccess => 'Инцидент создан';

  @override
  String incidentDetailError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get incidentDetailTitle => 'Детали инцидента';

  @override
  String get incidentDetailTitleLoading => 'Инцидент';

  @override
  String get incidentEmptyStateDescription =>
      'Инциденты отслеживают события от создания до устранения. Создайте один, чтобы начать.';

  @override
  String get incidentEmptyStateTitle => 'Инцидентов нет';

  @override
  String get incidentFilterAssignedToMe => 'Назначено мне';

  @override
  String get incidentFilterStateAssigned => 'Назначен';

  @override
  String get incidentFilterStateCancelled => 'Отменён';

  @override
  String get incidentFilterStateClosed => 'Закрыт';

  @override
  String get incidentFilterStateDraft => 'Черновик';

  @override
  String get incidentFilterStateEscalated => 'Эскалирован';

  @override
  String get incidentFilterStateOpen => 'Открыт';

  @override
  String get incidentFilterStateResolved => 'Устранён';

  @override
  String incidentListLoadError(String error) {
    return 'Не удалось загрузить инциденты:\n$error';
  }

  @override
  String get incidentListTitle => 'Инциденты';

  @override
  String get incidentNotFound => 'Инцидент не найден';

  @override
  String get incidentNoteContinueButton => 'Продолжить';

  @override
  String get incidentNoteHint => 'Необязательная заметка для этого перехода';

  @override
  String get incidentNoteLabel => 'Заметка';

  @override
  String incidentNoteSheetTitle(String action) {
    return 'Заметка — $action (необязательно)';
  }

  @override
  String get incidentNoteSkipButton => 'Пропустить';

  @override
  String get incidentPriorityFlash => 'Молниеносный';

  @override
  String get incidentPriorityImmediate => 'Немедленный';

  @override
  String get incidentPriorityPriority => 'Приоритетный';

  @override
  String get incidentPriorityRoutine => 'Плановый';

  @override
  String get incidentRoleHintAssignedOperator => 'Назначенный оператор';

  @override
  String get incidentRoleHintOperatorOrAbove => 'Оператор или выше';

  @override
  String get incidentRoleHintSupervisorOrAdmin =>
      'Руководитель или администратор';

  @override
  String get incidentStateMachineAssigneeRequired =>
      'assigneeId обязателен при переходе в состояние «назначен»';

  @override
  String incidentStateMachineCreateDenied(String roleName) {
    return 'createIncident запрещено для роли $roleName';
  }

  @override
  String incidentStateMachineInvalidTransition(
    String fromState,
    String toState,
  ) {
    return '$fromState -> $toState — недопустимый переход';
  }

  @override
  String incidentStateMachinePermissionDenied(
    String permissionName,
    String roleName,
  ) {
    return '$permissionName запрещено для роли $roleName';
  }

  @override
  String incidentStateMachineTerminalState(String stateName) {
    return 'Невозможно выполнить переход из $stateName: конечное состояние: $stateName';
  }

  @override
  String incidentTerminalStateMessage(String state) {
    return 'Этот инцидент $state — дальнейшие действия недоступны.';
  }

  @override
  String get incidentTimelineEmpty => 'История переходов отсутствует';

  @override
  String get incidentTimelineFinalState =>
      'Конечное состояние — дальнейшие переходы невозможны';

  @override
  String get incidentTimelineSuperseded => 'заменён';

  @override
  String get incidentTimelineUnknownRole => 'неизвестно';

  @override
  String get incidentTransitionHistoryHeader => 'История переходов';

  @override
  String incidentTransitionsLoadError(String error) {
    return 'Не удалось загрузить переходы: $error';
  }

  @override
  String get legalAcceptanceAgreeButton => 'Принимаю';

  @override
  String get legalAcceptanceAgreeSemantics =>
      'Я принимаю Условия использования и Политику конфиденциальности. Нажмите, чтобы подтвердить и продолжить.';

  @override
  String get legalAcceptanceAppIconSemantics => 'Значок приложения Socialmesh';

  @override
  String get legalAcceptanceDateFormatApril => 'Апрель';

  @override
  String get legalAcceptanceDateFormatAugust => 'Август';

  @override
  String get legalAcceptanceDateFormatDecember => 'Декабрь';

  @override
  String get legalAcceptanceDateFormatFebruary => 'Февраль';

  @override
  String get legalAcceptanceDateFormatJanuary => 'Январь';

  @override
  String get legalAcceptanceDateFormatJuly => 'Июль';

  @override
  String get legalAcceptanceDateFormatJune => 'Июнь';

  @override
  String get legalAcceptanceDateFormatMarch => 'Март';

  @override
  String get legalAcceptanceDateFormatMay => 'Май';

  @override
  String get legalAcceptanceDateFormatNovember => 'Ноябрь';

  @override
  String get legalAcceptanceDateFormatOctober => 'Октябрь';

  @override
  String get legalAcceptanceDateFormatSeptember => 'Сентябрь';

  @override
  String get legalAcceptanceDeclineBody =>
      'Для использования Socialmesh необходимо принять Условия использования и Политику конфиденциальности. Вы можете ознакомиться с ними и принять в любое время.';

  @override
  String get legalAcceptanceDeclineButton => 'Не сейчас';

  @override
  String get legalAcceptanceDeclineSemantics =>
      'Не сейчас. Отклонить и выйти из приложения.';

  @override
  String get legalAcceptanceDeclineTitle => 'Необходимо принять условия';

  @override
  String get legalAcceptanceFinePrint =>
      'Нажимая «Принимаю», вы принимаете наши Условия использования и подтверждаете ознакомление с Политикой конфиденциальности.';

  @override
  String get legalAcceptanceFinePrintSemantics =>
      'Нажимая «Принимаю», вы принимаете наши Условия использования и подтверждаете ознакомление с Политикой конфиденциальности.';

  @override
  String get legalAcceptanceGoBackSemantics =>
      'Вернуться для ознакомления с условиями и их принятия';

  @override
  String get legalAcceptanceInformationSemantics => 'Информация';

  @override
  String get legalAcceptanceLegalShieldSemantics => 'Правовая защита';

  @override
  String legalAcceptancePrivacyEffective(String date) {
    return 'Действует с $date';
  }

  @override
  String get legalAcceptancePrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get legalAcceptanceReviewButton => 'Ознакомиться с условиями';

  @override
  String get legalAcceptanceSubtitleInitial =>
      'Перед началом работы ознакомьтесь с нашими Условиями использования и Политикой конфиденциальности.';

  @override
  String get legalAcceptanceSubtitleUpdate =>
      'Мы обновили Условия использования. Пожалуйста, ознакомьтесь с изменениями и примите их, чтобы продолжить пользоваться Socialmesh.';

  @override
  String legalAcceptanceTermsEffective(String date) {
    return 'Действует с $date';
  }

  @override
  String get legalAcceptanceTermsOfService => 'Условия использования';

  @override
  String get legalAcceptanceTermsSummarySemantics => 'Сводка условий';

  @override
  String get legalAcceptanceTitleInitial => 'Условия и конфиденциальность';

  @override
  String get legalAcceptanceTitleUpdate => 'Обновлённые условия';

  @override
  String get legalAcceptanceViewPrivacySemantics =>
      'Просмотреть Политику конфиденциальности';

  @override
  String get legalAcceptanceViewTermsSemantics =>
      'Просмотреть Условия использования';

  @override
  String get legalEligibilityBody =>
      'Socialmesh предназначен для лиц от 16 лет и старше. Для продолжения необходимо подтвердить, что вам исполнилось 16 лет.';

  @override
  String get legalEligibilityConfirmButton => 'Мне 16 лет или больше';

  @override
  String get legalEligibilityConfirmSemantics =>
      'Мне 16 лет или больше. Нажмите для подтверждения и продолжения.';

  @override
  String get legalEligibilityExitBody =>
      'Для использования Socialmesh необходимо подтвердить, что вам исполнилось 16 лет или больше. Вы можете подтвердить в любое время.';

  @override
  String get legalEligibilityExitButton => 'Выйти';

  @override
  String get legalEligibilityExitSemantics =>
      'Выйти. Для использования Socialmesh необходимо быть не моложе 16 лет.';

  @override
  String get legalEligibilityExitTitle => 'Необходимо подтверждение возраста';

  @override
  String get legalEligibilityGoBackButton => 'Назад';

  @override
  String get legalEligibilityGoBackSemantics =>
      'Вернуться для подтверждения возраста';

  @override
  String get legalEligibilityIconSemantics => 'Возрастное ограничение';

  @override
  String get legalEligibilityInformationSemantics => 'Информация';

  @override
  String get legalEligibilityNoticeSemantics =>
      'Уведомление о возрастном ограничении';

  @override
  String get legalEligibilityPrivacyLink => 'Конфиденциальность';

  @override
  String get legalEligibilityTermsLink => 'Условия';

  @override
  String get legalEligibilityTitle => '16+';

  @override
  String get legalEligibilityViewPrivacySemantics =>
      'Просмотреть Политику конфиденциальности';

  @override
  String get legalEligibilityViewTermsSemantics =>
      'Просмотреть Условия использования';

  @override
  String get legalEligibilityAgePrompt => 'Select your age range to continue.';

  @override
  String get legalEligibilityOptionUnder13 => 'Under 13';

  @override
  String get legalEligibilityOptionUnder13Subtitle => 'App not available';

  @override
  String get legalEligibilityOptionTeen => '13 to 17';

  @override
  String get legalEligibilityOptionTeenSubtitle =>
      'Privacy-enhanced settings apply';

  @override
  String get legalEligibilityOptionAdult => '18 or Older';

  @override
  String get settingsAgeGroupTitle => 'Age Group';

  @override
  String get settingsAgeGroupSubtitleUnknown => 'Not set';

  @override
  String get settingsAgeGroupSubtitleUnder13 => 'Under 13';

  @override
  String get settingsAgeGroupSubtitleTeen => '13 to 17';

  @override
  String get settingsAgeGroupSubtitleAdult => '18 or older';

  @override
  String get lilygoModelPriceUnavailable => 'Цена недоступна';

  @override
  String get linkDeviceBannerLinkButton => 'Привязать';

  @override
  String linkDeviceBannerLinkError(String error) {
    return 'Не удалось привязать: $error';
  }

  @override
  String get linkDeviceBannerLinkedSuccess =>
      'Устройство привязано к вашему профилю!';

  @override
  String get linkDeviceBannerSubtitle =>
      'Другие смогут найти вас и подписаться';

  @override
  String get linkDeviceBannerTitle =>
      'Привяжите это устройство к своему профилю';

  @override
  String mapAgeHours(String hours) {
    return '$hours ч назад';
  }

  @override
  String mapAgeMinutes(String minutes) {
    return '$minutes мин назад';
  }

  @override
  String mapAgeSeconds(String seconds) {
    return '$seconds с назад';
  }

  @override
  String get mapCoordinatesCopied => 'Координаты скопированы в буфер обмена';

  @override
  String get mapCopyBothCoordinates => 'Координаты точек A и B';

  @override
  String get mapCopyCoordinates => 'Копировать координаты';

  @override
  String get mapCopyCoordinatesTooltip => 'Копировать координаты';

  @override
  String get mapCopySummary => 'Копировать сводку';

  @override
  String get mapDelete => 'Удалить';

  @override
  String get mapDismissTooltip => 'Закрыть';

  @override
  String get mapDistance10Km => '10 км';

  @override
  String get mapDistance1Km => '1 км';

  @override
  String get mapDistance25Km => '25 км';

  @override
  String get mapDistance5Km => '5 км';

  @override
  String get mapDistanceAll => 'Все';

  @override
  String mapDistanceKilometers(String km) {
    return '$km км';
  }

  @override
  String mapDistanceKilometersFormal(String km) {
    return '$km км';
  }

  @override
  String mapDistanceKilometersPrecise(String km) {
    return '$km км';
  }

  @override
  String mapDistanceKilometersRound(String km) {
    return '$km км';
  }

  @override
  String mapDistanceMeters(String meters) {
    return '$meters м';
  }

  @override
  String mapDistanceMetersFormal(String meters) {
    return '$meters м';
  }

  @override
  String get mapDropWaypoint => 'Поставить путевую точку';

  @override
  String get mapEmptyBodyNoNodes =>
      'Ноды появятся на карте, как только\nони передадут свои координаты GPS.';

  @override
  String mapEmptyBodyWithNodes(int totalNodes) {
    return 'Обнаружено нод: $totalNodes, но ни один\nещё не передал координаты GPS.';
  }

  @override
  String get mapEmptyTitle => 'Нет нод с GPS';

  @override
  String get mapEntitiesTitle => 'Объекты';

  @override
  String mapEstimatedPathLoss(String pathLoss) {
    return 'Расчётные потери на трассе: $pathLoss дБ (в свободном пространстве)';
  }

  @override
  String get mapExitMeasureMode => 'Выйти из режима измерения';

  @override
  String get mapExitMeasureModeTooltip => 'Выйти из режима измерения';

  @override
  String get mapFilterActive => 'Активные';

  @override
  String get mapFilterAll => 'Все';

  @override
  String get mapFilterInRange => 'В зоне доступа';

  @override
  String get mapFilterInactive => 'Неактивные';

  @override
  String get mapFilterNodesTitle => 'Фильтр нод';

  @override
  String get mapFilterNodesTooltip => 'Фильтровать ноды';

  @override
  String get mapFilterWithGps => 'С GPS';

  @override
  String get mapGlobeView => 'Вид глобуса 3D';

  @override
  String get mapHelp => 'Справка';

  @override
  String get mapHideConnectionLines => 'Скрыть линии соединений';

  @override
  String get mapHideHeatmap => 'Скрыть тепловую карту';

  @override
  String get mapHidePositionHistory => 'Скрыть историю местоположений';

  @override
  String get mapHideRangeCircles => 'Скрыть круги дальности';

  @override
  String get mapHideTakEntities => 'Скрыть объекты TAK';

  @override
  String get mapLastKnown => '• Последнее известное';

  @override
  String get mapLinkBudgetCopied =>
      'Бюджет радиолинии скопирован в буфер обмена';

  @override
  String get mapLocationTitle => 'Местоположение';

  @override
  String get mapLongPressForActions => 'Удерживайте для вызова действий';

  @override
  String get mapLosAnalysis => 'Анализ прямой видимости';

  @override
  String get mapLosAnalysisSubtitle => 'Проверка кривизны Земли и зоны Френеля';

  @override
  String mapLosBulgeAndFresnel(String bulge, String fresnel) {
    return 'Выпуклость: $bulge м · F1: $fresnel м';
  }

  @override
  String mapLosVerdict(String verdict) {
    return 'Прямая видимость: $verdict';
  }

  @override
  String get mapMaxDistance => 'Максимальное расстояние';

  @override
  String get mapMeasureDistance => 'Измерить расстояние';

  @override
  String get mapMeasureMarkerA => 'A';

  @override
  String get mapMeasureMarkerB => 'B';

  @override
  String get mapMeasureTapPointA => 'Нажмите на ноду или карту для точки A';

  @override
  String get mapMeasureTapPointB => 'Нажмите на ноду или карту для точки B';

  @override
  String get mapMeasurementActions => 'Действия с измерением';

  @override
  String get mapMeasurementCopied =>
      'Результат измерения скопирован в буфер обмена';

  @override
  String get mapNavigateToTooltip => 'Проложить маршрут';

  @override
  String get mapNewMeasurement => 'Новое измерение';

  @override
  String get mapNoEntities => 'Нет объектов';

  @override
  String get mapNoMatchingEntities => 'Подходящих объектов не найдено';

  @override
  String mapNodeCount(String count) {
    return 'Нод: $count';
  }

  @override
  String get mapNodesTitle => 'Ноды';

  @override
  String get mapOpenInExternalApp =>
      'Открыть во внешнем картографическом приложении';

  @override
  String get mapOpenMidpointInMaps => 'Открыть среднюю точку в Картах';

  @override
  String get mapPositionBroadcastHint =>
      'Трансляция местоположения может занимать до 15 минут.\nНажмите, чтобы запросить немедленно.';

  @override
  String get mapRefreshPositions => 'Обновить местоположения';

  @override
  String get mapRefreshing => 'Обновление...';

  @override
  String get mapRequestPositions => 'Запросить местоположения';

  @override
  String get mapRequesting => 'Запрос...';

  @override
  String get mapReverseDirection =>
      'Изменить направление измерения на обратное';

  @override
  String get mapRfLinkBudget => 'Бюджет радиолинии';

  @override
  String mapRfLinkBudgetClipboard(
    String distance,
    String frequency,
    String pathLoss,
    String linkMargin,
  ) {
    return 'Бюджет радиолинии (потери в свободном пространстве)\nРасстояние: $distance\nЧастота: $frequency\nПотери на трассе: $pathLoss\nЗапас линии: $linkMargin';
  }

  @override
  String get mapSaDashboard => 'Панель TAK';

  @override
  String get mapScreenTitle => 'Карта сети Mesh';

  @override
  String get mapSearchEntitiesHint => 'Поиск объектов...';

  @override
  String get mapSearchHint => 'Попробуйте другой поисковый запрос';

  @override
  String get mapSearchNodesHint => 'Поиск нод...';

  @override
  String get mapSettings => 'Настройки';

  @override
  String get mapShare => 'Поделиться';

  @override
  String mapShareDistanceLabel(String distance) {
    return 'Расстояние: $distance';
  }

  @override
  String get mapShareLocation => 'Поделиться местоположением';

  @override
  String get mapShareMeasurement => 'Поделиться измерением';

  @override
  String get mapShareMeasurementSubtitle => 'Поделиться через системный диалог';

  @override
  String get mapShowConnectionLines => 'Показать линии соединений';

  @override
  String get mapShowHeatmap => 'Показать тепловую карту';

  @override
  String get mapShowPositionHistory => 'Показать историю местоположений';

  @override
  String get mapShowRangeCircles => 'Показать круги дальности';

  @override
  String get mapShowTakEntities => 'Показать объекты TAK';

  @override
  String get mapStyleTooltip => 'Стиль карты';

  @override
  String get mapSwapAB => 'Поменять A ↔ B';

  @override
  String get mapTakActive => 'Активен';

  @override
  String get mapTakActiveBadge => 'АКТИВЕН';

  @override
  String mapTakEntityCount(int count) {
    return '• Объектов: $count';
  }

  @override
  String get mapTakStale => 'Устарел';

  @override
  String get mapTakStaleBadge => 'УСТАРЕЛ';

  @override
  String get mapTakTrack => 'Трек';

  @override
  String get mapTakTracked => 'Отслеживается';

  @override
  String mapWaypointDefaultLabel(int number) {
    return 'ТЧ $number';
  }

  @override
  String get mapYouBadge => 'ВЫ';

  @override
  String get mesh3dAutoRotate => 'Автовращение';

  @override
  String get mesh3dChangeViewTooltip => 'Изменить вид';

  @override
  String mesh3dFilteredNodeCount(int filtered, int total) {
    return '$filtered/$total нод';
  }

  @override
  String get mesh3dHelp => 'Справка';

  @override
  String get mesh3dHideConnections => 'Скрыть соединения';

  @override
  String get mesh3dLegendActive => 'Активный';

  @override
  String get mesh3dLegendActiveNow => 'Активен сейчас';

  @override
  String get mesh3dLegendActivePeer => 'Активная нода';

  @override
  String get mesh3dLegendFading => 'Затухающий';

  @override
  String get mesh3dLegendFadingPeer => 'Затухающая нода';

  @override
  String get mesh3dLegendFairSignal => 'Удовлетворительный сигнал';

  @override
  String get mesh3dLegendGoodSignal => 'Хороший сигнал';

  @override
  String get mesh3dLegendHighAltitude => 'Большая высота';

  @override
  String get mesh3dLegendLowAltitude => 'Малая высота';

  @override
  String get mesh3dLegendOffline => 'Офлайн';

  @override
  String get mesh3dLegendPoorSignal => 'Слабый сигнал';

  @override
  String get mesh3dLegendSnrBar => 'Шкала SNR';

  @override
  String get mesh3dLegendStaleIdle => 'Устаревший / неактивный';

  @override
  String get mesh3dLegendYourNode => 'Ваша нода';

  @override
  String get mesh3dMyNodeBadge => 'Я';

  @override
  String mesh3dNodeCount(int count) {
    return '$count нод';
  }

  @override
  String get mesh3dNodesDrawerTitle => 'Ноды';

  @override
  String get mesh3dShowConnections => 'Показать соединения';

  @override
  String get mesh3dStatActive => 'Активных';

  @override
  String get mesh3dStatChUtil => 'Загр. кан.';

  @override
  String get mesh3dStatGps => 'GPS';

  @override
  String get mesh3dStatSnr => 'SNR';

  @override
  String get mesh3dStatTotal => 'Всего';

  @override
  String get mesh3dStopRotation => 'Остановить вращение';

  @override
  String get mesh3dViewModeTitle => 'Режим отображения';

  @override
  String meshHealthActiveNodesPackets(int activeNodeCount, int totalPackets) {
    return '$activeNodeCount активных нод • $totalPackets пакетов';
  }

  @override
  String get meshHealthBatteryUsageSubtitle =>
      'Мониторинг работоспособности сети потребляет дополнительный заряд. Приостановите при отсутствии необходимости.';

  @override
  String get meshHealthBatteryUsageTitle => 'Расход аккумулятора';

  @override
  String get meshHealthChannelUtilization => 'Загрузка канала';

  @override
  String get meshHealthCriticalIssues => 'Обнаружены критические проблемы';

  @override
  String get meshHealthDetectedIssues => 'Обнаруженные проблемы';

  @override
  String get meshHealthDontRemindAgain => 'Больше не напоминать';

  @override
  String get meshHealthFloodBadge => 'ФЛУД';

  @override
  String get meshHealthHealthy => 'Сеть в норме';

  @override
  String get meshHealthIndicatorLabel => 'Состояние';

  @override
  String meshHealthIssueCount(int count) {
    return '$count проблем';
  }

  @override
  String get meshHealthIssuesDetected => 'Проблемы обнаружены';

  @override
  String get meshHealthKeepRunning => 'Продолжить работу';

  @override
  String get meshHealthMonitoringActiveTitle => 'Мониторинг всё ещё активен';

  @override
  String get meshHealthMonitoringBatteryWarning =>
      'Мониторинг работоспособности сети потребляет дополнительный заряд в фоновом режиме.';

  @override
  String get meshHealthMonitoringPaused => 'Мониторинг приостановлен';

  @override
  String get meshHealthNoDataYet => 'Данных пока нет';

  @override
  String get meshHealthNoIssuesDetected => 'Проблем не обнаружено';

  @override
  String get meshHealthNoNodesDetected => 'Ноды не обнаружены';

  @override
  String meshHealthNodePrefix(String nodeId) {
    return 'Нода: $nodeId';
  }

  @override
  String get meshHealthNormal => 'Норма';

  @override
  String get meshHealthOfAirtime => 'эфирного времени';

  @override
  String meshHealthPacketsAirtime(int packetCount, int airtimeMs) {
    return '$packetCount пакетов • $airtimeMs мс эфирного времени';
  }

  @override
  String get meshHealthPauseAndLeave => 'Пауза и выход';

  @override
  String get meshHealthPauseTooltip => 'Пауза';

  @override
  String get meshHealthReliability => 'Надёжность';

  @override
  String get meshHealthReliabilityFair => 'Удовлетворительно';

  @override
  String get meshHealthReliabilityGood => 'Хорошо';

  @override
  String get meshHealthReliabilityPoor => 'Плохо';

  @override
  String get meshHealthResetDataTooltip => 'Сбросить данные';

  @override
  String get meshHealthResumeTooltip => 'Возобновить';

  @override
  String get meshHealthSaturated => 'ПЕРЕГРУЖЕН';

  @override
  String get meshHealthSpamBadge => 'СПАМ';

  @override
  String get meshHealthThresholdLabel => 'Порог 50%';

  @override
  String get meshHealthTitle => 'Работоспособность сети';

  @override
  String get meshHealthTopContributors => 'Наиболее активные участники';

  @override
  String get meshHealthUtilization => 'Загрузка';

  @override
  String get meshcoreAbout => 'О приложении';

  @override
  String get meshcoreAboutDescription =>
      'SocialMesh — приложение-компаньон для mesh-радио, поддерживающее устройства Meshtastic и MeshCore.';

  @override
  String get meshcoreAboutSocialMesh => 'О SocialMesh';

  @override
  String get meshcoreActions => 'Действия';

  @override
  String get meshcoreActiveLabel => 'Активен';

  @override
  String get meshcoreAdd => 'Добавить';

  @override
  String get meshcoreAddContact => 'Добавить контакт';

  @override
  String get meshcoreAddContactButton => 'Добавить контакт';

  @override
  String get meshcoreAdvertisementSent => 'Объявление отправлено';

  @override
  String get meshcoreAdvertisementSentTools => 'Объявление отправлено';

  @override
  String get meshcoreAnalysis => 'Анализ';

  @override
  String get meshcoreBandwidthLabel => 'Полоса пропускания';

  @override
  String get meshcoreBasedOnLiPoVoltage =>
      'На основе диапазона напряжения LiPo (3,0 В — 4,2 В)';

  @override
  String get meshcoreBatteryAndStorage => 'Батарея и хранилище';

  @override
  String get meshcoreBatteryInfoNotAvailable =>
      'Информация о батарее недоступна';

  @override
  String get meshcoreBatteryLabel => 'Батарея';

  @override
  String get meshcoreBatteryStatus => 'Состояние батареи';

  @override
  String get meshcoreBatteryStatusLabel => 'Батарея';

  @override
  String get meshcoreBatteryUnknown => 'Неизвестно';

  @override
  String get meshcoreBroadcastPresenceToMesh =>
      'Транслировать своё присутствие в сеть';

  @override
  String get meshcoreBroadcastYourPresence => 'Транслировать присутствие';

  @override
  String get meshcoreCancel => 'Отмена';

  @override
  String get meshcoreCenter => 'Центр';

  @override
  String meshcoreChannelAlreadyExists(String channelName) {
    return '$channelName уже есть в ваших каналах';
  }

  @override
  String get meshcoreChannelCodeCopied => 'Код канала скопирован';

  @override
  String meshcoreChannelCreated(String channelName) {
    return 'Канал «$channelName» создан';
  }

  @override
  String get meshcoreChannelNameHint => 'Название канала';

  @override
  String get meshcoreChannelNameHintGeneral => 'general';

  @override
  String get meshcoreChannelNameHintHashtag => 'например, general';

  @override
  String get meshcoreChannelNameLabel => 'Название канала';

  @override
  String get meshcoreChannelPskCopied => 'PSK канала скопирован';

  @override
  String get meshcoreChannelsCreateChannel => 'Создать канал';

  @override
  String get meshcoreChannelsJoinChannel => 'Вступить в канал';

  @override
  String get meshcoreChannelsLabel => 'Каналы';

  @override
  String get meshcoreChannelsRefreshChannels => 'Обновить каналы';

  @override
  String get meshcoreChannelsTitle => 'Каналы';

  @override
  String get meshcoreChatNode => 'Нода чата';

  @override
  String get meshcoreClear => 'Очистить';

  @override
  String get meshcoreClose => 'Закрыть';

  @override
  String get meshcoreCodingRateLabel => 'Скорость кодирования';

  @override
  String get meshcoreConnected => 'Подключено';

  @override
  String meshcoreConnectedTo(String deviceName) {
    return 'Подключено к $deviceName';
  }

  @override
  String get meshcoreConsoleCaptureCleared => 'Захват очищен';

  @override
  String get meshcoreConsoleClear => 'Очистить';

  @override
  String get meshcoreConsoleCopyHex => 'Скопировать Hex';

  @override
  String get meshcoreConsoleDevBadge => 'DEV';

  @override
  String meshcoreConsoleFramesCaptured(int count) {
    return 'Захвачено кадров: $count';
  }

  @override
  String get meshcoreConsoleHexCopied => 'Hex-лог скопирован в буфер обмена';

  @override
  String get meshcoreConsoleNoFrames => 'Кадры ещё не захвачены';

  @override
  String get meshcoreConsoleRefresh => 'Обновить';

  @override
  String get meshcoreConsoleTitle => 'Консоль MeshCore';

  @override
  String meshcoreContactAdded(String contactName) {
    return '$contactName добавлен';
  }

  @override
  String meshcoreContactAddedToContacts(String contactName) {
    return '$contactName добавлен в контакты';
  }

  @override
  String meshcoreContactAlreadyExists(String contactName) {
    return '$contactName уже есть в ваших контактах';
  }

  @override
  String get meshcoreContactCodeCopied => 'Код контакта скопирован';

  @override
  String meshcoreContactCount(int count) {
    return '$count контакт';
  }

  @override
  String meshcoreContactCountPlural(int count) {
    return '$count контактов';
  }

  @override
  String meshcoreContactRemoved(String contactName) {
    return '$contactName удалён';
  }

  @override
  String get meshcoreContactsLabel => 'Контакты';

  @override
  String get meshcoreContactsTitle => 'Контакты';

  @override
  String get meshcoreControlAdvertVisibility =>
      'Управлять видимостью объявлений';

  @override
  String get meshcoreCoordinatesCopied =>
      'Координаты скопированы в буфер обмена';

  @override
  String get meshcoreCopy => 'Копировать';

  @override
  String get meshcoreCopyChannelCode => 'Копировать код канала';

  @override
  String get meshcoreCopyCoordinates => 'Копировать координаты';

  @override
  String get meshcoreCopyCoordinatesSubtitle => 'Координаты A и B';

  @override
  String get meshcoreCopyPublicKey => 'Копировать публичный ключ';

  @override
  String get meshcoreCopySummary => 'Копировать сводку';

  @override
  String get meshcoreCreate => 'Создать';

  @override
  String get meshcoreCreateChannelButton => 'Создать канал';

  @override
  String get meshcoreCreateChannelDialogTitle => 'Создать канал';

  @override
  String get meshcoreDebug => 'Отладка';

  @override
  String get meshcoreDeviceInfo => 'Информация об устройстве';

  @override
  String get meshcoreDeviceInfoCopied => 'Информация об устройстве скопирована';

  @override
  String get meshcoreDeviceInfoNotAvailable =>
      'Информация об устройстве недоступна';

  @override
  String get meshcoreDeviceInfoTool => 'Информация об устройстве';

  @override
  String get meshcoreDeviceInformation => 'Информация об устройстве';

  @override
  String get meshcoreDiagnostics => 'Диагностика';

  @override
  String get meshcoreDisconnect => 'Отключиться';

  @override
  String get meshcoreDisconnectedChannelsDescription =>
      'Подключитесь к устройству MeshCore для просмотра каналов';

  @override
  String get meshcoreDisconnectedContactsDescription =>
      'Подключитесь к устройству MeshCore для просмотра контактов';

  @override
  String get meshcoreDisconnectedMapDescription =>
      'Подключитесь к устройству MeshCore для просмотра карты';

  @override
  String get meshcoreDisconnectedMapTitle => 'MeshCore отключён';

  @override
  String get meshcoreDisconnectedMessagesWillQueue =>
      'Отключено — сообщения будут поставлены в очередь';

  @override
  String get meshcoreDisconnectedStatus => 'Отключено';

  @override
  String get meshcoreDisconnectedTitle => 'MeshCore отключён';

  @override
  String get meshcoreDisconnectedToolsDescription =>
      'Подключитесь к устройству MeshCore для доступа к инструментам';

  @override
  String get meshcoreDisconnectedToolsTitle => 'MeshCore отключён';

  @override
  String get meshcoreDiscovery => 'Обнаружение';

  @override
  String get meshcoreDone => 'Готово';

  @override
  String get meshcoreEditNodeName => 'Изменить имя ноды';

  @override
  String get meshcoreEnterChannelCode => 'Введите код канала';

  @override
  String get meshcoreEnterChannelCodeSubtitle =>
      'Вставьте код приглашения в канал';

  @override
  String get meshcoreEnterCodeManually => 'Ввести код вручную';

  @override
  String get meshcoreEnterContactCode => 'Введите код контакта';

  @override
  String get meshcoreEnterNodeNameHint => 'Введите имя ноды...';

  @override
  String get meshcoreErrorEnterChannelCode => 'Пожалуйста, введите код канала';

  @override
  String get meshcoreErrorEnterChannelName =>
      'Пожалуйста, введите название канала';

  @override
  String get meshcoreExitMeasureMode => 'Выйти из режима измерения';

  @override
  String get meshcoreFailedToRebootDevice =>
      'Не удалось перезагрузить устройство';

  @override
  String get meshcoreFailedToSendAdTools => 'Не удалось отправить объявление';

  @override
  String get meshcoreFailedToSendAdvertisement =>
      'Не удалось отправить объявление';

  @override
  String get meshcoreFailedToSendMessage => 'Не удалось отправить сообщение';

  @override
  String get meshcoreFailedToSetName => 'Не удалось задать имя';

  @override
  String get meshcoreFailedToSyncTime => 'Не удалось синхронизировать время';

  @override
  String get meshcoreFilterChatNodes => 'Ноды чата';

  @override
  String get meshcoreFilterMap => 'Фильтр карты';

  @override
  String get meshcoreFilterOtherNodes => 'Другие ноды';

  @override
  String get meshcoreFilterRepeaters => 'Ретрансляторы';

  @override
  String get meshcoreFilterTooltip => 'Фильтр';

  @override
  String get meshcoreFramesLabel => 'Кадры';

  @override
  String get meshcoreFrequencyLabel => 'Частота';

  @override
  String get meshcoreInvalidChannelCodeFormat =>
      'Неверный формат кода канала (ожидается: name:pskHex)';

  @override
  String get meshcoreInvalidContactCode => 'Неверный код контакта';

  @override
  String get meshcoreInvalidQrCodeFormat => 'Неверный формат QR-кода';

  @override
  String get meshcoreJoin => 'Вступить';

  @override
  String get meshcoreJoinButton => 'Вступить';

  @override
  String get meshcoreJoinHashtagChannel => 'Вступить в канал с хэштегом';

  @override
  String get meshcoreJoinHashtagChannelSubtitle =>
      'Введите название канала (например, #general)';

  @override
  String meshcoreJoinedChannel(String channelName) {
    return 'Вы вступили в $channelName';
  }

  @override
  String meshcoreJoinedHashtagChannel(String name) {
    return 'Вы вступили в #$name';
  }

  @override
  String get meshcoreJustNow => 'Только что';

  @override
  String get meshcoreLeave => 'Покинуть';

  @override
  String get meshcoreLeaveChannel => 'Покинуть канал';

  @override
  String meshcoreLeaveChannelMessage(String channelName) {
    return 'Вы уверены, что хотите покинуть $channelName?';
  }

  @override
  String get meshcoreLeaveChannelTitle => 'Покинуть канал?';

  @override
  String meshcoreLeftChannel(String channelName) {
    return 'Вы покинули $channelName';
  }

  @override
  String get meshcoreLegendChat => 'Чат';

  @override
  String get meshcoreLegendRepeater => 'Ретранслятор';

  @override
  String get meshcoreLegendRoom => 'Комната';

  @override
  String get meshcoreLegendSensor => 'Датчик';

  @override
  String get meshcoreLoadingChannels => 'Загрузка каналов...';

  @override
  String get meshcoreLoadingContacts => 'Загрузка контактов...';

  @override
  String get meshcoreLoadingMessages => 'Загрузка сообщений...';

  @override
  String get meshcoreLocationComingSoon =>
      'Настройки местоположения появятся в ближайшее время.\n\nЭто позволит вам вручную задать положение ноды или использовать GPS.';

  @override
  String get meshcoreLocationInfoLabel => 'Местоположение';

  @override
  String get meshcoreLocationSetting => 'Местоположение';

  @override
  String get meshcoreLongPressForActions => 'Удерживайте для действий';

  @override
  String get meshcoreMapTitle => 'Карта';

  @override
  String get meshcoreMaxTxPowerLabel => 'Макс. мощность TX';

  @override
  String get meshcoreMeasurementActions => 'Действия с измерением';

  @override
  String get meshcoreMeasurementCopied =>
      'Измерение скопировано в буфер обмена';

  @override
  String get meshcoreMeshCoreDevice => 'Устройство MeshCore';

  @override
  String get meshcoreMessageButton => 'Сообщение';

  @override
  String get meshcoreMonitorPowerStorage =>
      'Мониторинг питания и состояния хранилища';

  @override
  String get meshcoreMyContactCode => 'Мой код контакта';

  @override
  String get meshcoreNameLabel => 'Имя';

  @override
  String get meshcoreNewMeasurement => 'Новое измерение';

  @override
  String get meshcoreNoChannels => 'Нет каналов';

  @override
  String get meshcoreNoChannelsDescription =>
      'Каналы — это общие пространства для групповой связи.\n\nСоздайте новый канал или вступите в существующий.';

  @override
  String get meshcoreNoContacts => 'Нет контактов';

  @override
  String get meshcoreNoContactsDescription =>
      'Контакты будут появляться здесь по мере обнаружения через объявления.\n\nВы также можете добавить контакты вручную, используя их код контакта.';

  @override
  String get meshcoreNoContactsForTrace => 'Нет контактов для трассировки';

  @override
  String get meshcoreNoContactsWithLocation =>
      'Нет контактов с местоположением';

  @override
  String get meshcoreNoContactsWithLocationDescription =>
      'Контакты с координатами GPS будут отображены на карте.\nУбедитесь, что у ваших контактов включена передача местоположения.';

  @override
  String get meshcoreNoMessagesYet => 'Сообщений пока нет';

  @override
  String get meshcoreNodeNameLabel => 'Имя ноды';

  @override
  String get meshcoreNodeNameSetting => 'Имя ноды';

  @override
  String get meshcoreNodeNameUpdated => 'Имя ноды обновлено';

  @override
  String get meshcoreNodeSettings => 'Настройки ноды';

  @override
  String get meshcoreNotConnected => 'Нет подключения';

  @override
  String get meshcoreNotConnectedToDevice =>
      'Нет подключения к устройству MeshCore';

  @override
  String get meshcoreNotConnectedTools => 'Нет подключения';

  @override
  String get meshcoreNotSet => 'Не задано';

  @override
  String get meshcoreNotValidChannelQr =>
      'Недействительный QR-код канала MeshCore';

  @override
  String get meshcoreNotValidContactQr =>
      'Недействительный QR-код контакта MeshCore';

  @override
  String get meshcoreNotYetImplemented => 'Ещё не реализовано';

  @override
  String get meshcoreOpenChannel => 'Открыть канал';

  @override
  String get meshcoreOpenInExternalMapApp =>
      'Открыть во внешнем картографическом приложении';

  @override
  String get meshcoreOpenMidpointInMaps => 'Открыть среднюю точку на карте';

  @override
  String get meshcorePasteChannelCodeHint => 'Вставьте код канала здесь...';

  @override
  String get meshcorePasteContactCodeHint => 'Вставьте код контакта здесь...';

  @override
  String get meshcorePointCameraAtChannelQr =>
      'Наведите камеру на QR-код канала MeshCore';

  @override
  String get meshcorePointCameraAtContactQr =>
      'Наведите камеру на QR-код контакта MeshCore';

  @override
  String get meshcorePrivacyComingSoon =>
      'Настройки конфиденциальности появятся в ближайшее время.\n\nЭто позволит управлять тем, транслирует ли ваша нода объявления.';

  @override
  String get meshcorePrivacyMode => 'Режим конфиденциальности';

  @override
  String get meshcorePrivacyModeDialogTitle => 'Режим конфиденциальности';

  @override
  String get meshcorePrivate => 'Приватный';

  @override
  String get meshcorePrivateChannel => 'Приватный канал';

  @override
  String get meshcoreProtocolCapture => 'Захват протокола';

  @override
  String get meshcoreProtocolCaptureDialogTitle => 'Захват протокола';

  @override
  String get meshcorePskDerivedFromName =>
      'PSK получен из имени (обнаруживаемый)';

  @override
  String get meshcorePublic => 'Публичный';

  @override
  String get meshcorePublicChannel => 'Публичный канал';

  @override
  String get meshcorePublicHashtagChannel => 'Публичный канал с хэштегом';

  @override
  String get meshcorePublicKeyCopied => 'Публичный ключ скопирован';

  @override
  String get meshcorePublicKeyCopiedSettings => 'Публичный ключ скопирован';

  @override
  String get meshcorePublicKeySettingsLabel => 'Публичный ключ';

  @override
  String get meshcoreRadioConfiguredOnFirmware =>
      'Настройки радио задаются в прошивке устройства.';

  @override
  String get meshcoreRadioSettings => 'Настройки радио';

  @override
  String get meshcoreRadioSettingsDialogTitle => 'Настройки радио';

  @override
  String get meshcoreRadioSettingsNotAvailable => 'Настройки радио недоступны';

  @override
  String get meshcoreRadioSettingsSubtitle =>
      'Частота, мощность TX, полоса пропускания';

  @override
  String get meshcoreRadioSettingsTitle => 'Настройки радио';

  @override
  String get meshcoreRadioSettingsTool => 'Настройки радио';

  @override
  String get meshcoreRandomPskPrivate => 'Случайный PSK (приватный)';

  @override
  String get meshcoreReboot => 'Перезагрузить';

  @override
  String get meshcoreRebootCommandSent => 'Команда перезагрузки отправлена';

  @override
  String get meshcoreRebootDevice => 'Перезагрузить устройство';

  @override
  String get meshcoreRebootDeviceMessage =>
      'Вы уверены, что хотите перезагрузить устройство MeshCore?';

  @override
  String get meshcoreRebootDeviceTitle => 'Перезагрузить устройство';

  @override
  String get meshcoreRefresh => 'Обновить';

  @override
  String get meshcoreRefreshButton => 'Обновить';

  @override
  String get meshcoreRefreshContacts => 'Обновить контакты';

  @override
  String get meshcoreRefreshContactsSetting => 'Обновить контакты';

  @override
  String get meshcoreRefreshing => 'Обновление...';

  @override
  String get meshcoreRefreshingContacts => 'Обновление контактов...';

  @override
  String get meshcoreReloadContactsFromDevice =>
      'Перезагрузить контакты с устройства';

  @override
  String get meshcoreRemove => 'Удалить';

  @override
  String get meshcoreRemoveContact => 'Удалить контакт';

  @override
  String meshcoreRemoveContactMessage(String contactName) {
    return 'Вы уверены, что хотите удалить $contactName?';
  }

  @override
  String get meshcoreRemoveContactTitle => 'Удалить контакт?';

  @override
  String get meshcoreRepeaterNode => 'Нода-ретранслятор';

  @override
  String get meshcoreRestartMeshCoreDevice =>
      'Перезапустить устройство MeshCore';

  @override
  String get meshcoreReverseMeasurementDirection =>
      'Поменять направление измерения';

  @override
  String get meshcoreRoomNode => 'Нода-комната';

  @override
  String get meshcoreSave => 'Сохранить';

  @override
  String get meshcoreScanChannelQrSubtitle => 'Сканировать QR-код канала';

  @override
  String get meshcoreScanChannelQrTitle => 'Сканировать QR канала';

  @override
  String get meshcoreScanContactQrSubtitle => 'Сканировать QR-код контакта';

  @override
  String get meshcoreScanContactQrTitle => 'Сканировать QR контакта';

  @override
  String get meshcoreScanQrCode => 'Сканировать QR-код';

  @override
  String get meshcoreScanQrToJoinChannel =>
      'Сканируйте этот QR-код, чтобы вступить в канал';

  @override
  String get meshcoreScanToAddMeSubtitle =>
      'Сканируйте этот код, чтобы добавить меня в контакты';

  @override
  String get meshcoreSearchContactsHint => 'Поиск контактов...';

  @override
  String get meshcoreSelectContactToTrace =>
      'Выберите контакт для трассировки маршрута через сеть.';

  @override
  String get meshcoreSelfInfoNotAvailable => 'Информация о себе недоступна';

  @override
  String get meshcoreSendAdvertisement => 'Отправить объявление';

  @override
  String get meshcoreSendAdvertisementTool => 'Отправить объявление';

  @override
  String get meshcoreSendMessage => 'Отправить сообщение';

  @override
  String get meshcoreSendMessageToStart =>
      'Отправьте сообщение, чтобы начать переписку';

  @override
  String get meshcoreSending => 'Отправка...';

  @override
  String get meshcoreSessionNotActive => 'Сессия MeshCore не активна';

  @override
  String get meshcoreSetLocation => 'Задать местоположение';

  @override
  String get meshcoreSetNodePosition => 'Задать положение ноды';

  @override
  String get meshcoreSettingsTitle => 'Настройки';

  @override
  String get meshcoreSfCrLabel => 'SF/CR';

  @override
  String get meshcoreShare => 'Поделиться';

  @override
  String get meshcoreShareChannel => 'Поделиться каналом';

  @override
  String get meshcoreShareContact => 'Поделиться контактом';

  @override
  String get meshcoreShareContactCodeInfo =>
      'Поделитесь своим кодом контакта, чтобы другие могли написать вам';

  @override
  String get meshcoreShellAddChannelHint =>
      'Используйте меню для создания или вступления в канал';

  @override
  String get meshcoreShellAddContactHint =>
      'Используйте кнопку + для добавления контакта';

  @override
  String get meshcoreShellAddContactSubtitle =>
      'Сканировать QR или ввести код контакта';

  @override
  String get meshcoreShellAdvertisementSent =>
      'Объявление отправлено — ждите ответов';

  @override
  String get meshcoreShellAdvertisementSentListening =>
      'Объявление отправлено — ожидание ответов';

  @override
  String get meshcoreShellAppSettings => 'Настройки приложения';

  @override
  String get meshcoreShellAppSettingsSubtitle => 'Уведомления, тема, параметры';

  @override
  String meshcoreShellConnectedTo(String deviceName) {
    return 'Подключено к $deviceName';
  }

  @override
  String get meshcoreShellDefaultDeviceName => 'MeshCore';

  @override
  String get meshcoreShellDefaultDeviceNameFull => 'Устройство MeshCore';

  @override
  String get meshcoreShellDefaultInitials => 'MC';

  @override
  String get meshcoreShellDeviceInfoNotAvailable =>
      'Информация об устройстве недоступна';

  @override
  String get meshcoreShellDeviceTooltip => 'Устройство';

  @override
  String get meshcoreShellDisconnect => 'Отключиться';

  @override
  String get meshcoreShellDisconnectConfirmMessage =>
      'Вы уверены, что хотите отключиться от этого устройства MeshCore?';

  @override
  String meshcoreShellDisconnectedFrom(String deviceName) {
    return 'Отключено от $deviceName';
  }

  @override
  String get meshcoreShellDisconnecting => 'Отключение...';

  @override
  String get meshcoreShellDiscoverSubtitle =>
      'Отправить объявление для поиска ближайших нод';

  @override
  String get meshcoreShellDrawerAddChannel => 'Добавить канал';

  @override
  String get meshcoreShellDrawerAddContact => 'Добавить контакт';

  @override
  String get meshcoreShellDrawerDisconnect => 'Отключиться';

  @override
  String get meshcoreShellDrawerDiscoverContacts => 'Найти контакты';

  @override
  String get meshcoreShellDrawerMyContactCode => 'Мой код контакта';

  @override
  String get meshcoreShellDrawerSectionHeader => 'MESHCORE';

  @override
  String get meshcoreShellDrawerSettings => 'Настройки';

  @override
  String get meshcoreShellInfoNodeId => 'ID ноды';

  @override
  String get meshcoreShellInfoNodeName => 'Имя ноды';

  @override
  String get meshcoreShellInfoProtocol => 'Протокол';

  @override
  String get meshcoreShellInfoProtocolValue => 'MeshCore';

  @override
  String get meshcoreShellInfoPublicKey => 'Публичный ключ';

  @override
  String get meshcoreShellInfoStatus => 'Статус';

  @override
  String get meshcoreShellJoinChannel => 'Вступить в канал';

  @override
  String get meshcoreShellJoinChannelHint =>
      'Используйте меню для вступления в канал';

  @override
  String get meshcoreShellJoinChannelSubtitle =>
      'Сканировать QR или ввести код канала';

  @override
  String get meshcoreShellMenuTooltip => 'Меню';

  @override
  String get meshcoreShellNavChannels => 'Каналы';

  @override
  String get meshcoreShellNavContacts => 'Контакты';

  @override
  String get meshcoreShellNavMap => 'Карта';

  @override
  String get meshcoreShellNavTools => 'Инструменты';

  @override
  String get meshcoreShellNoSavedDevice =>
      'Нет сохранённого устройства для повторного подключения';

  @override
  String get meshcoreShellNotConnected => 'Нет подключения';

  @override
  String get meshcoreShellReconnectButton => 'Переподключиться';

  @override
  String meshcoreShellReconnectFailed(String error) {
    return 'Переподключение не удалось: $error';
  }

  @override
  String meshcoreShellReconnecting(String deviceName) {
    return 'Переподключение к $deviceName...';
  }

  @override
  String get meshcoreShellScanToAddContact =>
      'Сканировать для добавления в контакты';

  @override
  String get meshcoreShellSectionConnection => 'Подключение';

  @override
  String get meshcoreShellSectionDeviceInfo => 'Информация об устройстве';

  @override
  String get meshcoreShellSectionQuickActions => 'Быстрые действия';

  @override
  String get meshcoreShellShareContactInfo =>
      'Поделитесь своим кодом контакта, чтобы другие могли написать вам';

  @override
  String get meshcoreShellShareContactSubtitle => 'Поделиться данными контакта';

  @override
  String get meshcoreShellStatusConnected => 'Подключено';

  @override
  String get meshcoreShellStatusConnecting => 'Подключение...';

  @override
  String get meshcoreShellStatusDisconnected => 'Отключено';

  @override
  String get meshcoreShellStatusOffline => 'Не в сети';

  @override
  String get meshcoreShellStatusOnline => 'В сети';

  @override
  String get meshcoreShellUnknown => 'Неизвестно';

  @override
  String get meshcoreShellUnnamedNode => 'Безымянная нода';

  @override
  String meshcoreSlotIndex(int index) {
    return 'Слот $index';
  }

  @override
  String get meshcoreSpreadingFactorLabel => 'Коэффициент распространения';

  @override
  String get meshcoreStatusLabel => 'Статус';

  @override
  String get meshcoreSwapAB => 'Поменять A ↔ B';

  @override
  String get meshcoreSyncTime => 'Синхронизировать время';

  @override
  String get meshcoreSyncing => 'Синхронизация...';

  @override
  String get meshcoreTapForPointA => 'Нажмите на ноду или карту для точки A';

  @override
  String get meshcoreTapForPointB => 'Нажмите на ноду или карту для точки B';

  @override
  String meshcoreTimeAgoDays(int count) {
    return '$countд назад';
  }

  @override
  String meshcoreTimeAgoHours(int count) {
    return '$countч назад';
  }

  @override
  String meshcoreTimeAgoMinutes(int count) {
    return '$countм назад';
  }

  @override
  String get meshcoreTimeSynchronized => 'Время синхронизировано';

  @override
  String get meshcoreToolsTitle => 'Инструменты';

  @override
  String get meshcoreTracePacketRoutes =>
      'Трассировка маршрутов пакетов через сеть';

  @override
  String get meshcoreTracePath => 'Трассировка маршрута';

  @override
  String meshcoreTracePathInitiated(String name) {
    return 'Трассировка маршрута до $name запущена';
  }

  @override
  String get meshcoreTracePathTitle => 'Трассировка маршрута';

  @override
  String get meshcoreTxPowerLabel => 'Мощность TX';

  @override
  String get meshcoreTxPowerStatusLabel => 'Мощность TX';

  @override
  String get meshcoreTypeContactCode => 'Введите код контакта';

  @override
  String get meshcoreTypeLabel => 'Тип';

  @override
  String get meshcoreTypeMessageHint => 'Введите сообщение...';

  @override
  String get meshcoreUnknown => 'Неизвестно';

  @override
  String get meshcoreUpdateDeviceClock => 'Обновить часы устройства';

  @override
  String meshcoreVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get meshcoreViewDeviceInfo =>
      'Просмотр подробной информации об устройстве';

  @override
  String get meshcoreViewFrameLogs => 'Просмотр журнала кадров MeshCore';

  @override
  String get meshcoreViewLoRaConfig => 'Просмотр конфигурации LoRa-радио';

  @override
  String get messageContextMenuCopy => 'Копировать';

  @override
  String get messageContextMenuMessageCopied => 'Сообщение скопировано';

  @override
  String get messageContextMenuMessageDetails => 'Сведения о сообщении';

  @override
  String get messageContextMenuNoRecents => 'Нет последних';

  @override
  String get messageContextMenuReply => 'Ответить';

  @override
  String get messageContextMenuSearchEmoji => 'Поиск эмодзи…';

  @override
  String get messageContextMenuStatusDelivered => 'Доставлено ✔️';

  @override
  String messageContextMenuStatusFailed(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get messageContextMenuStatusSending => 'Отправка…';

  @override
  String get messageContextMenuStatusSent => 'Отправлено';

  @override
  String get messageContextMenuTapbackFailed => 'Не удалось отправить реакцию';

  @override
  String get messageContextMenuTapbackSent => 'Реакция отправлена';

  @override
  String get messagesAddChannelNotConnected =>
      'Подключитесь к устройству, чтобы добавить каналы';

  @override
  String get messagesChannelsTab => 'Каналы';

  @override
  String get messagesContactsTab => 'Контакты';

  @override
  String get messagesContainerTitle => 'Сообщения';

  @override
  String get messagesScanChannelNotConnected =>
      'Подключитесь к устройству для сканирования каналов';

  @override
  String get messagingAddChannel => 'Добавить канал';

  @override
  String get messagingAdvancedResetNodeDatabase =>
      'Дополнительно: сбросить базу данных нод';

  @override
  String get messagingChannelSettings => 'Настройки канала';

  @override
  String get messagingChannelSubtitle => 'Канал';

  @override
  String get messagingClearSearch => 'Очистить поиск';

  @override
  String get messagingCloseSearch => 'Закрыть поиск';

  @override
  String get messagingConfigureQuickResponses =>
      'Настройте быстрые ответы в Настройках';

  @override
  String get messagingContactsDiscoveredHint =>
      'Здесь появятся обнаруженные ноды';

  @override
  String get messagingContactsTitle => 'Контакты';

  @override
  String messagingContactsTitleWithCount(int count) {
    return 'Контакты ($count)';
  }

  @override
  String get messagingDeleteMessageConfirmation =>
      'Вы уверены, что хотите удалить это сообщение? Оно будет удалено только локально.';

  @override
  String get messagingDeleteMessageTitle => 'Удалить сообщение';

  @override
  String get messagingDirectMessageSubtitle => 'Личное сообщение';

  @override
  String messagingEncryptionKeyIssueSubtitle(String name) {
    return 'Личное сообщение для $name не доставлено';
  }

  @override
  String get messagingEncryptionKeyIssueTitle => 'Проблема с ключом шифрования';

  @override
  String get messagingEncryptionKeyWarning =>
      'Ключи шифрования могут быть рассинхронизированы. Это может произойти, если нода была сброшена или исключён из базы данных сети.';

  @override
  String get messagingFailedToSend => 'Не удалось отправить';

  @override
  String get messagingFilterActive => 'Активные';

  @override
  String get messagingFilterAll => 'Все';

  @override
  String get messagingFilterFavorites => 'Избранные';

  @override
  String get messagingFilterMessaged => 'С перепиской';

  @override
  String get messagingFilterUnread => 'Непрочитанные';

  @override
  String get messagingFindMessageHint => 'Найти сообщение';

  @override
  String get messagingHelp => 'Справка';

  @override
  String get messagingMessageDeleted => 'Сообщение удалено';

  @override
  String get messagingMessageHint => 'Сообщение';

  @override
  String get messagingSendTooltip => 'Отправить (Ctrl/Cmd+Enter)';

  @override
  String get messagingMessageQueuedOffline =>
      'Сообщение в очереди — будет отправлено при подключении';

  @override
  String messagingNoContactsMatchSearch(String query) {
    return 'Контакты по запросу «$query» не найдены';
  }

  @override
  String get messagingNoContactsYet => 'Контактов пока нет';

  @override
  String messagingNoFilteredContacts(String filter) {
    return 'Нет контактов: $filter';
  }

  @override
  String get messagingNoMessagesInChannel => 'В этом канале нет сообщений';

  @override
  String get messagingNoMessagesMatchSearch =>
      'Сообщения по вашему запросу не найдены';

  @override
  String get messagingNoQuickResponsesConfigured =>
      'Быстрые ответы не настроены.\nДобавьте их в Настройках → Быстрые ответы.';

  @override
  String get messagingOriginalMessage => 'Исходное сообщение';

  @override
  String get messagingQuickResponses => 'Быстрые ответы';

  @override
  String messagingReplyingTo(String name) {
    return 'Ответ для $name';
  }

  @override
  String get messagingRequestUserInfo => 'Запросить данные пользователя';

  @override
  String messagingRequestUserInfoFailed(String error) {
    return 'Не удалось запросить данные: $error';
  }

  @override
  String messagingRequestUserInfoSuccess(String name) {
    return 'Запрошены актуальные данные от $name';
  }

  @override
  String get messagingRetryMessage => 'Повторить отправку';

  @override
  String get messagingStatusAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String get messagingStatusUnconfirmed => 'Unconfirmed';

  @override
  String get messagingStatusRetrying => 'Retrying';

  @override
  String get messagingStatusConfirmed => 'Confirmed';

  @override
  String get messagingStatusSentToRadio => 'Sent to radio';

  @override
  String get messagingResend => 'Resend';

  @override
  String get messagingAutoRetryEnable => 'Retry every 60s until confirmed';

  @override
  String get messagingAutoRetryStop => 'Stop retrying';

  @override
  String get messagingAutoRetryWarning =>
      'May increase airtime and battery usage';

  @override
  String messagingRetryProgress(int count, int max) {
    return '$count/$max retries';
  }

  @override
  String get messagingScanQrCode => 'Сканировать QR-код';

  @override
  String get messagingSearchContactsHint => 'Поиск контактов';

  @override
  String get messagingSearchMessages => 'Поиск сообщений';

  @override
  String get messagingSectionActive => 'Активные';

  @override
  String get messagingSectionFavorites => 'Избранные';

  @override
  String get messagingSectionInactive => 'Неактивные';

  @override
  String get messagingSectionUnread => 'Непрочитанные';

  @override
  String get messagingSettings => 'Настройки';

  @override
  String get messagingSourceAutomation => 'Автоматизация';

  @override
  String get messagingSourceNotification => 'Уведомление';

  @override
  String get messagingSourceShortcut => 'Shortcut';

  @override
  String get messagingSourceTapback => 'Реакция';

  @override
  String get messagingStartConversation => 'Начните разговор';

  @override
  String get messagingUnknownNode => 'Неизвестная нода';

  @override
  String get navigationActivity => 'Активность';

  @override
  String get navigationAether => 'Aether';

  @override
  String get navigationAutomations => 'Автоматизации';

  @override
  String get navigationDashboard => 'Панель';

  @override
  String get navigationDeviceLogs => 'Журнал устройства';

  @override
  String get navigationDeviceTooltip => 'Устройство';

  @override
  String get navigationFileTransfers => 'Передача файлов';

  @override
  String get navigationFirmwareErrorTitle => 'Ошибка устройства Meshtastic';

  @override
  String navigationFirmwareMessage(String message) {
    return 'Прошивка: $message';
  }

  @override
  String get navigationFirmwareWarningTitle =>
      'Предупреждение устройства Meshtastic';

  @override
  String navigationFlightActivated(String flightNumber, String route) {
    return '$flightNumber ($route) в воздухе!';
  }

  @override
  String navigationFlightCompleted(String flightNumber, String route) {
    return '$flightNumber ($route) рейс завершён';
  }

  @override
  String get navigationGuestName => 'Гость';

  @override
  String get navigationHelpSupport => 'Помощь и поддержка';

  @override
  String get navigationIftttIntegration => 'Интеграция IFTTT';

  @override
  String get navigationMap => 'Карта';

  @override
  String get navigationMenuTooltip => 'Меню';

  @override
  String get navigationMesh3dView => '3D-вид сети';

  @override
  String get navigationMeshHealth => 'Состояние сети';

  @override
  String get navigationMessages => 'Сообщения';

  @override
  String get navigationNodeDex => 'NodeDex';

  @override
  String get navigationNodes => 'Ноды';

  @override
  String get navigationNotSignedIn => 'Не выполнен вход';

  @override
  String get navigationOffline => 'Офлайн';

  @override
  String get navigationPresence => 'Присутствие';

  @override
  String get navigationReachability => 'Доступность';

  @override
  String get navigationRingtonePack => 'Пакет рингтонов';

  @override
  String get navigationRoutes => 'Маршруты';

  @override
  String get navigationSectionAccount => 'АККАУНТ';

  @override
  String get navigationSectionAdvanced => 'ADVANCED';

  @override
  String get navigationSectionDiscover => 'DISCOVER';

  @override
  String get navigationSectionIdentity => 'IDENTITY';

  @override
  String get navigationSectionMesh => 'СЕТЬ';

  @override
  String get navigationSectionPremium => 'ПРЕМИУМ';

  @override
  String get navigationSectionSocial => 'СОЦИАЛЬНОЕ';

  @override
  String get navigationSectionTools => 'TOOLS';

  @override
  String get navigationSignals => 'Сигналы';

  @override
  String get navigationSocial => 'Социальное';

  @override
  String get navigationSyncError => 'Ошибка синхронизации';

  @override
  String get navigationSynced => 'Синхронизировано';

  @override
  String get navigationSyncing => 'Синхронизация...';

  @override
  String get navigationTakGateway => 'TAK Шлюз';

  @override
  String get navigationTakMap => 'TAK Карта';

  @override
  String get navigationThemePack => 'Пакет тем';

  @override
  String get navigationTimeline => 'История';

  @override
  String get navigationViewProfile => 'Просмотр профиля';

  @override
  String get navigationWidgets => 'Виджеты';

  @override
  String get navigationWorldMap => 'Карта мира';

  @override
  String get nodeAnalyticsAddFavoriteTooltip => 'Добавить в избранное';

  @override
  String get nodeAnalyticsAddedToFavorites => 'Добавлено в избранное';

  @override
  String get nodeAnalyticsAirTimeTx => 'Время передачи TX';

  @override
  String nodeAnalyticsAltitude(String meters) {
    return '$metersм';
  }

  @override
  String get nodeAnalyticsAltitudeRowLabel => 'Высота';

  @override
  String get nodeAnalyticsAvgBattery => 'Средний заряд';

  @override
  String get nodeAnalyticsBadgeLive => 'ПРЯМО СЕЙЧАС';

  @override
  String get nodeAnalyticsBattery => 'Аккумулятор';

  @override
  String get nodeAnalyticsChannelUtilization => 'Утилизация канала';

  @override
  String get nodeAnalyticsCharging => 'Зарядка';

  @override
  String get nodeAnalyticsClear => 'Очистить';

  @override
  String get nodeAnalyticsClearConfirm => 'Очистить';

  @override
  String get nodeAnalyticsClearHistoryMessage =>
      'Это удалит все исторические данные для этой ноды. Действие невозможно отменить.';

  @override
  String get nodeAnalyticsClearHistoryTitle => 'Очистить историю';

  @override
  String get nodeAnalyticsCsvShared => 'CSV-данные переданы';

  @override
  String get nodeAnalyticsDataUpdated => 'Данные ноды обновлены';

  @override
  String nodeAnalyticsDirectNeighbors(int count) {
    return 'Прямые соседи ($count)';
  }

  @override
  String get nodeAnalyticsExport => 'Экспорт';

  @override
  String get nodeAnalyticsExportCsv => 'CSV';

  @override
  String nodeAnalyticsExportCsvSubject(String name) {
    return 'История ноды $name (CSV)';
  }

  @override
  String get nodeAnalyticsExportHistoryTitle => 'Экспорт истории';

  @override
  String get nodeAnalyticsExportJson => 'JSON';

  @override
  String nodeAnalyticsExportJsonSubject(String name) {
    return 'История ноды $name (JSON)';
  }

  @override
  String nodeAnalyticsExportRecordCount(int count) {
    return '$count записей';
  }

  @override
  String get nodeAnalyticsFirstSeen => 'Впервые замечен';

  @override
  String get nodeAnalyticsHardware => 'Оборудование';

  @override
  String get nodeAnalyticsHistoryCleared => 'История очищена';

  @override
  String get nodeAnalyticsJsonShared => 'JSON-данные переданы';

  @override
  String get nodeAnalyticsLastUpdate => 'Последнее обновление';

  @override
  String get nodeAnalyticsLatitude => 'Широта';

  @override
  String get nodeAnalyticsLiveWatchDisabled =>
      'Слежение в реальном времени отключено';

  @override
  String get nodeAnalyticsLiveWatchEnabled =>
      'Слежение в реальном времени включено (обновление каждые 30с)';

  @override
  String get nodeAnalyticsLongName => 'Полное имя';

  @override
  String get nodeAnalyticsLongitude => 'Долгота';

  @override
  String get nodeAnalyticsNoGatewayData => 'Нет данных шлюза';

  @override
  String get nodeAnalyticsNoHistoryToExport =>
      'Нет данных истории для экспорта';

  @override
  String get nodeAnalyticsNoHistoryYet => 'Исторических данных пока нет';

  @override
  String get nodeAnalyticsNoNeighborData => 'Нет данных о соседях';

  @override
  String get nodeAnalyticsNodeIdCopied => 'ID ноды скопирован';

  @override
  String get nodeAnalyticsNodeNotFound => 'Нода не найдена в сети';

  @override
  String get nodeAnalyticsRecords => 'Записи';

  @override
  String nodeAnalyticsRefreshFailed(String error) {
    return 'Ошибка обновления: $error';
  }

  @override
  String get nodeAnalyticsRefreshNow => 'Обновить сейчас';

  @override
  String get nodeAnalyticsRefreshing => 'Обновление...';

  @override
  String get nodeAnalyticsRemoveFavoriteTooltip => 'Удалить из избранного';

  @override
  String get nodeAnalyticsRemovedFromFavorites => 'Удалено из избранного';

  @override
  String get nodeAnalyticsRole => 'Роль';

  @override
  String get nodeAnalyticsSectionDeviceInfo => 'Информация об устройстве';

  @override
  String get nodeAnalyticsSectionDeviceMetrics => 'Метрики устройства';

  @override
  String get nodeAnalyticsSectionHistory => 'История';

  @override
  String get nodeAnalyticsSectionNetwork => 'Сеть';

  @override
  String get nodeAnalyticsSectionTrends => 'Тенденции';

  @override
  String nodeAnalyticsSeenByGateways(int count) {
    return 'Замечен шлюзами ($count)';
  }

  @override
  String get nodeAnalyticsShareDetailBatteryCharging => 'Аккумулятор: Зарядка';

  @override
  String nodeAnalyticsShareDetailBatteryLevel(String level) {
    return 'Аккумулятор: $level%';
  }

  @override
  String nodeAnalyticsShareDetailGateways(String count) {
    return 'Шлюзы: $count';
  }

  @override
  String nodeAnalyticsShareDetailHardware(String hardware) {
    return 'Оборудование: $hardware';
  }

  @override
  String nodeAnalyticsShareDetailHeader(String name) {
    return '🛰️ Нода Mesh: $name';
  }

  @override
  String nodeAnalyticsShareDetailId(String nodeId) {
    return 'ID: !$nodeId';
  }

  @override
  String nodeAnalyticsShareDetailLocation(String location) {
    return 'Местоположение: $location';
  }

  @override
  String nodeAnalyticsShareDetailNeighbors(String count) {
    return 'Соседи: $count';
  }

  @override
  String nodeAnalyticsShareDetailRole(String role) {
    return 'Роль: $role';
  }

  @override
  String nodeAnalyticsShareDetailStatus(String status) {
    return 'Статус: $status';
  }

  @override
  String get nodeAnalyticsShareDetails => 'Поделиться подробностями';

  @override
  String get nodeAnalyticsShareDetailsSubtitle =>
      'Полная техническая информация в виде текста';

  @override
  String nodeAnalyticsShareFailed(String error) {
    return 'Ошибка при передаче ноды: $error';
  }

  @override
  String get nodeAnalyticsShareLink => 'Поделиться ссылкой';

  @override
  String get nodeAnalyticsShareLinkSubtitle =>
      'Красивый предпросмотр в iMessage, Slack и др.';

  @override
  String get nodeAnalyticsShareNodeTitle => 'Поделиться нодой';

  @override
  String nodeAnalyticsShareSubject(String name) {
    return 'Нода Mesh: $name';
  }

  @override
  String nodeAnalyticsShareText(String name, String url) {
    return 'Посмотрите на $name в Socialmesh!\n$url';
  }

  @override
  String get nodeAnalyticsShareTooltip => 'Поделиться информацией о ноде';

  @override
  String get nodeAnalyticsShortName => 'Краткое имя';

  @override
  String get nodeAnalyticsShowOnMap => 'Показать на карте';

  @override
  String get nodeAnalyticsSignIn => 'Войти';

  @override
  String get nodeAnalyticsSignInToShare => 'Войдите, чтобы делиться нодами';

  @override
  String get nodeAnalyticsStopWatching => 'Остановить слежение';

  @override
  String nodeAnalyticsTimeDaysAgo(int days) {
    return '$daysд назад';
  }

  @override
  String nodeAnalyticsTimeHoursAgo(int hours) {
    return '$hoursч назад';
  }

  @override
  String get nodeAnalyticsTimeJustNow => 'Только что';

  @override
  String nodeAnalyticsTimeMinutesAgo(int minutes) {
    return '$minutesмин назад';
  }

  @override
  String get nodeAnalyticsUnknown => 'Неизвестно';

  @override
  String get nodeAnalyticsUptime => 'Время работы';

  @override
  String get nodeAnalyticsUptimeStat => 'Время работы';

  @override
  String get nodeAnalyticsVisitAgain =>
      'Посетите эту ноду ещё раз, чтобы накопить историю';

  @override
  String get nodeAnalyticsVoltage => 'Напряжение';

  @override
  String get nodeAnalyticsWatchLive => 'Следить в реальном времени';

  @override
  String get nodeComparisonCharging => 'Зарядка';

  @override
  String get nodeComparisonNo => 'Нет';

  @override
  String get nodeComparisonNoData => '--';

  @override
  String get nodeComparisonNodeIdCopied => 'ID ноды скопирован';

  @override
  String get nodeComparisonRowAirTimeTx => 'Время передачи TX';

  @override
  String get nodeComparisonRowBattery => 'Аккумулятор';

  @override
  String get nodeComparisonRowChannelUtil => 'Утилизация канала';

  @override
  String get nodeComparisonRowFirmware => 'Прошивка';

  @override
  String get nodeComparisonRowGateways => 'Шлюзы';

  @override
  String get nodeComparisonRowHardware => 'Оборудование';

  @override
  String get nodeComparisonRowHasLocation => 'Есть местоположение';

  @override
  String get nodeComparisonRowNeighbors => 'Соседи';

  @override
  String get nodeComparisonRowRegion => 'Регион';

  @override
  String get nodeComparisonRowRole => 'Роль';

  @override
  String get nodeComparisonRowStatus => 'Статус';

  @override
  String get nodeComparisonRowUptime => 'Время работы';

  @override
  String get nodeComparisonRowVoltage => 'Напряжение';

  @override
  String get nodeComparisonSectionDeviceInfo => 'Информация об устройстве';

  @override
  String get nodeComparisonSectionMetrics => 'Метрики';

  @override
  String get nodeComparisonSectionNetwork => 'Сеть';

  @override
  String get nodeComparisonSectionStatus => 'Статус';

  @override
  String get nodeComparisonTitle => 'Сравнение нод';

  @override
  String get nodeComparisonUnknown => 'Неизвестно';

  @override
  String get nodeComparisonVs => 'VS';

  @override
  String get nodeComparisonYes => 'Да';

  @override
  String get nodeDetailAddToFavoritesTooltip => 'Добавить в избранное';

  @override
  String nodeDetailAddedToFavorites(String name) {
    return '$name добавлен в избранное';
  }

  @override
  String get nodeDetailAppBarTitle => 'Сведения о ноде';

  @override
  String get nodeDetailBatteryCharging => 'Зарядка';

  @override
  String nodeDetailBatteryPercent(int level) {
    return '$level%';
  }

  @override
  String nodeDetailDistanceKilometers(String km) {
    return '$km км';
  }

  @override
  String nodeDetailDistanceMeters(String meters) {
    return '$meters м';
  }

  @override
  String get nodeDetailFavoriteBadge => 'Избранное';

  @override
  String nodeDetailFavoriteError(String error) {
    return 'Ошибка обновления избранного: $error';
  }

  @override
  String nodeDetailFixedPositionError(String error) {
    return 'Ошибка установки фиксированной позиции: $error';
  }

  @override
  String nodeDetailFixedPositionSet(String name) {
    return 'Фиксированная позиция установлена по местоположению $name';
  }

  @override
  String get nodeDetailLabelAirUtilTx => 'Утилизация TX';

  @override
  String get nodeDetailLabelAltitude => 'Высота';

  @override
  String get nodeDetailLabelBadPackets => 'Плохие пакеты';

  @override
  String get nodeDetailLabelBattery => 'Аккумулятор';

  @override
  String get nodeDetailLabelCacheHits => 'Попадания в кэш';

  @override
  String get nodeDetailLabelChannelUtil => 'Утилизация канала';

  @override
  String get nodeDetailLabelDistance => 'Расстояние';

  @override
  String get nodeDetailLabelEncryption => 'Шифрование';

  @override
  String get nodeDetailLabelFirmware => 'Прошивка';

  @override
  String get nodeDetailLabelHardware => 'Оборудование';

  @override
  String get nodeDetailLabelHopExhausted => 'Хопы исчерпаны';

  @override
  String get nodeDetailLabelHopsPreserved => 'Хопы сохранены';

  @override
  String get nodeDetailLabelInspected => 'Проверено';

  @override
  String get nodeDetailLabelNoiseFloor => 'Уровень шума';

  @override
  String get nodeDetailLabelOnlineNodes => 'Ноды онлайн';

  @override
  String get nodeDetailLabelPacketsRx => 'Пакеты RX';

  @override
  String get nodeDetailLabelPacketsTx => 'Пакеты TX';

  @override
  String get nodeDetailLabelPosition => 'Позиция';

  @override
  String get nodeDetailLabelPositionDedup => 'Дедупликация позиции';

  @override
  String get nodeDetailLabelRateLimitDrops => 'Сброс по лимиту скорости';

  @override
  String get nodeDetailLabelRssi => 'RSSI';

  @override
  String get nodeDetailLabelSnr => 'SNR';

  @override
  String get nodeDetailLabelStatus => 'Статус';

  @override
  String get nodeDetailLabelTotalNodes => 'Всего нод';

  @override
  String get nodeDetailLabelTxDropped => 'TX сброшено';

  @override
  String get nodeDetailLabelUnknownDrops => 'Неизвестные сбросы';

  @override
  String get nodeDetailLabelUptime => 'Время работы';

  @override
  String get nodeDetailLabelUserId => 'ID пользователя';

  @override
  String get nodeDetailLabelVoltage => 'Напряжение';

  @override
  String nodeDetailLastHeardDaysAgo(int days) {
    return '$daysд назад';
  }

  @override
  String nodeDetailLastHeardHoursAgo(int hours) {
    return '$hoursч назад';
  }

  @override
  String get nodeDetailLastHeardJustNow => 'Только что';

  @override
  String nodeDetailLastHeardMinutesAgo(int minutes) {
    return '$minutesмин назад';
  }

  @override
  String get nodeDetailLastHeardNever => 'Никогда';

  @override
  String nodeDetailLastHeardTimestamp(String timestamp) {
    return 'Последний сигнал $timestamp';
  }

  @override
  String get nodeDetailMenuAdminSettings => 'Настройки администратора';

  @override
  String get nodeDetailMenuAdminSubtitle => 'Настроить эту ноду удалённо';

  @override
  String get nodeDetailMenuExchangePositions => 'Обменяться позициями';

  @override
  String get nodeDetailMenuQrCode => 'QR-код';

  @override
  String get nodeDetailMenuRemoveNode => 'Удалить нода';

  @override
  String get nodeDetailMenuRequestUserInfo =>
      'Запросить информацию о пользователе';

  @override
  String get nodeDetailMenuSetFixedPosition =>
      'Установить фиксированную позицию';

  @override
  String get nodeDetailMenuShowOnMap => 'Показать на карте';

  @override
  String get nodeDetailMenuTracerouteHistory => 'История traceroute';

  @override
  String get nodeDetailMessageButton => 'Сообщение';

  @override
  String nodeDetailMuteError(String error) {
    return 'Ошибка изменения статуса отключения звука: $error';
  }

  @override
  String get nodeDetailMuteNotConnected =>
      'Невозможно изменить статус отключения звука: устройство не подключено';

  @override
  String get nodeDetailMuteTooltip => 'Отключить звук ноды';

  @override
  String nodeDetailMuted(String name) {
    return '$name отключён';
  }

  @override
  String get nodeDetailMutedBadge => 'Без звука';

  @override
  String get nodeDetailNoPkiBadge => 'Нет PKI';

  @override
  String get nodeDetailNoPositionData => 'У ноды нет данных о позиции';

  @override
  String get nodeDetailPkiBadge => 'PKI';

  @override
  String nodeDetailPositionError(String error) {
    return 'Ошибка запроса позиции: $error';
  }

  @override
  String nodeDetailPositionRequested(String name) {
    return 'Позиция запрошена от $name';
  }

  @override
  String nodeDetailQrInfoText(String nodeId) {
    return 'ID ноды: $nodeId';
  }

  @override
  String get nodeDetailQrSubtitle => 'Отсканируйте, чтобы добавить эту ноду';

  @override
  String get nodeDetailRebootButton => 'Перезагрузить';

  @override
  String get nodeDetailRebootConfirm => 'Перезагрузить';

  @override
  String nodeDetailRebootError(String error) {
    return 'Ошибка перезагрузки: $error';
  }

  @override
  String get nodeDetailRebootMessage =>
      'Будет выполнена перезагрузка устройства Meshtastic. Приложение автоматически переподключится после перезапуска устройства.';

  @override
  String get nodeDetailRebootNotConnected =>
      'Невозможно перезагрузить: устройство не подключено';

  @override
  String get nodeDetailRebootTitle => 'Перезагрузка устройства';

  @override
  String get nodeDetailRebootingSnackbar => 'Устройство перезагружается...';

  @override
  String get nodeDetailRemoveConfirm => 'Удалить';

  @override
  String nodeDetailRemoveError(String error) {
    return 'Ошибка удаления ноды: $error';
  }

  @override
  String get nodeDetailRemoveFromFavoritesTooltip => 'Удалить из избранного';

  @override
  String nodeDetailRemoveMessage(String name) {
    return 'Удалить $name из базы данных нод? Нода будет удалена с вашего локального устройства.';
  }

  @override
  String get nodeDetailRemoveTitle => 'Удалить нода';

  @override
  String nodeDetailRemovedFromFavorites(String name) {
    return '$name удалён из избранного';
  }

  @override
  String nodeDetailRemovedSnackbar(String name) {
    return '$name удалён';
  }

  @override
  String get nodeDetailSectionDeviceMetrics => 'Метрики устройства';

  @override
  String get nodeDetailSectionIdentity => 'Идентификация';

  @override
  String get nodeDetailSectionNetwork => 'Сеть';

  @override
  String get nodeDetailSectionRadio => 'Радио';

  @override
  String get nodeDetailSectionTraffic => 'Управление трафиком';

  @override
  String get nodeDetailShutdownButton => 'Выключить';

  @override
  String get nodeDetailShutdownConfirm => 'Выключить';

  @override
  String nodeDetailShutdownError(String error) {
    return 'Ошибка выключения: $error';
  }

  @override
  String get nodeDetailShutdownMessage =>
      'Устройство Meshtastic будет выключено. Для повторного подключения потребуется физически включить его.';

  @override
  String get nodeDetailShutdownNotConnected =>
      'Невозможно выключить: устройство не подключено';

  @override
  String get nodeDetailShutdownTitle => 'Выключение устройства';

  @override
  String get nodeDetailShuttingDownSnackbar => 'Устройство выключается...';

  @override
  String get nodeDetailSigilCardTooltip => 'Карточка Sigil';

  @override
  String get nodeDetailSignalExcellent => 'Отличный';

  @override
  String get nodeDetailSignalFair => 'Удовлетворительный';

  @override
  String get nodeDetailSignalGood => 'Хороший';

  @override
  String get nodeDetailSignalUnknown => 'Неизвестно';

  @override
  String get nodeDetailSignalVeryWeak => 'Очень слабый';

  @override
  String get nodeDetailSignalWeak => 'Слабый';

  @override
  String nodeDetailTracerouteCooldownTooltip(int seconds) {
    return 'Ожидание traceroute: $secondsс';
  }

  @override
  String nodeDetailTracerouteError(String error) {
    return 'Ошибка отправки traceroute: $error';
  }

  @override
  String get nodeDetailTracerouteNotConnected =>
      'Невозможно отправить traceroute: устройство не подключено';

  @override
  String nodeDetailTracerouteSent(String name) {
    return 'Traceroute отправлен на $name — проверьте историю traceroute для результатов';
  }

  @override
  String get nodeDetailTracerouteTooltip => 'Traceroute';

  @override
  String get nodeDetailUnmuteTooltip => 'Включить звук ноды';

  @override
  String nodeDetailUnmuted(String name) {
    return '$name включён';
  }

  @override
  String nodeDetailUserInfoError(String error) {
    return 'Ошибка запроса информации о пользователе: $error';
  }

  @override
  String nodeDetailUserInfoRequested(String name) {
    return 'Информация о пользователе запрошена от $name';
  }

  @override
  String nodeDetailValueAltitude(int altitude) {
    return '$altitude м';
  }

  @override
  String get nodeDetailValueNoPublicKey => 'Нет открытого ключа';

  @override
  String nodeDetailValueNoiseFloor(int noiseFloor) {
    return '$noiseFloor dBm';
  }

  @override
  String nodeDetailValuePercent(String value) {
    return '$value%';
  }

  @override
  String get nodeDetailValuePkiEnabled => 'PKI включён';

  @override
  String nodeDetailValueRssi(int rssi) {
    return '$rssi dBm';
  }

  @override
  String nodeDetailValueSnr(String snr) {
    return '$snr dB';
  }

  @override
  String nodeDetailValueVoltage(String voltage) {
    return '$voltage В';
  }

  @override
  String get nodeDetailYouBadge => 'ВЫ';

  @override
  String nodeHistoryDataPointCount(int current, int required) {
    return '$current/$required точек данных';
  }

  @override
  String get nodeHistoryMetricBattery => 'Аккумулятор';

  @override
  String get nodeHistoryMetricChannelUtil => 'Утилизация канала';

  @override
  String get nodeHistoryMetricConnectivity => 'Подключение';

  @override
  String get nodeHistoryNeedMoreData => 'Недостаточно данных для графиков';

  @override
  String nodeHistoryNoMetricData(String metric) {
    return 'Нет данных $metric';
  }

  @override
  String get nodeIntelligenceActivityActive => 'Активный';

  @override
  String get nodeIntelligenceActivityCold => 'Холодный';

  @override
  String get nodeIntelligenceActivityHot => 'Горячий';

  @override
  String get nodeIntelligenceActivityQuiet => 'Тихий';

  @override
  String get nodeIntelligenceChannelUtil => 'Утилизация канала';

  @override
  String get nodeIntelligenceConnectivity => 'Подключение';

  @override
  String get nodeIntelligenceDerivedBadge => 'РАСЧЁТНЫЙ';

  @override
  String nodeIntelligenceGatewayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шлюза',
      many: '$count шлюзов',
      few: '$count шлюза',
      one: '1 шлюз',
    );
    return '$_temp0';
  }

  @override
  String get nodeIntelligenceHealth => 'Состояние';

  @override
  String get nodeIntelligenceMobilityElevated => 'Повышенная';

  @override
  String get nodeIntelligenceMobilityInfra => 'Инфраструктура';

  @override
  String get nodeIntelligenceMobilityMobile => 'Мобильный';

  @override
  String get nodeIntelligenceMobilityStationary => 'Стационарный';

  @override
  String get nodeIntelligenceMobilityTracker => 'Трекер';

  @override
  String nodeIntelligenceNeighborCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count соседа',
      many: '$count соседей',
      few: '$count соседа',
      one: '1 сосед',
    );
    return '$_temp0';
  }

  @override
  String get nodeIntelligenceTapHint => 'Нажмите для детальной аналитики';

  @override
  String get nodeIntelligenceTitle => 'Аналитика Mesh';

  @override
  String get nodeIntelligenceUnknown => 'Неизвестно';

  @override
  String nodedexActiveDaysOf14(int count) {
    return '$count/14 дней';
  }

  @override
  String get nodedexActiveNow => 'активен сейчас';

  @override
  String get nodedexActivityTimelineTitle => 'История активности';

  @override
  String get nodedexAddToAppleWallet => 'Добавить в Apple Wallet';

  @override
  String get nodedexAdditionalTraits => 'Дополнительные характеристики';

  @override
  String nodedexAgeDiscoveredDaysAgo(int days) {
    return 'обнаружен $days д. назад';
  }

  @override
  String nodedexAgeDiscoveredMonthsAgo(int months) {
    return 'обнаружен $months мес. назад';
  }

  @override
  String nodedexAgeDiscoveredWeeksAgo(int weeks) {
    return 'обнаружен $weeks нед. назад';
  }

  @override
  String nodedexAgeDiscoveredYearsAgo(int years) {
    return 'обнаружен $years л. назад';
  }

  @override
  String get nodedexAgeDiscoveredYesterday => 'обнаружен вчера';

  @override
  String get nodedexAgeNewToday => 'новый сегодня';

  @override
  String get nodedexAirUtilTxLabel => 'Air Util TX';

  @override
  String get nodedexBatteryLabel => 'Батарея';

  @override
  String get nodedexBestRssi => 'Лучший RSSI';

  @override
  String get nodedexBestSnr => 'Лучший SNR';

  @override
  String get nodedexBestSnrStatLabel => 'Лучший SNR';

  @override
  String nodedexBusiestDay(String day) {
    return 'Самый активный: $day';
  }

  @override
  String get nodedexCardBrandSocialmesh => 'SOCIALMESH';

  @override
  String get nodedexCardDeviceFirmware => 'ПРОШИВКА';

  @override
  String get nodedexCardDeviceHardware => 'ЖЕЛЕЗО';

  @override
  String get nodedexCardDeviceRole => 'РОЛЬ';

  @override
  String get nodedexCardRarity100plus => '100+ встреч';

  @override
  String get nodedexCardRarity20to49 => '20 - 49 встреч';

  @override
  String get nodedexCardRarity50to99 => '50 - 99 встреч';

  @override
  String get nodedexCardRarity5to19 => '5 - 19 встреч';

  @override
  String get nodedexCardRarityEpic => 'ЭПИЧЕСКАЯ';

  @override
  String get nodedexCardRarityInfoDescription =>
      'Редкость карточки отражает, как часто вы встречали эту ноду в сети. Чем больше пересечений, тем редкостнее становится карточка.';

  @override
  String get nodedexCardRarityInfoTitle => 'Редкость карточки';

  @override
  String get nodedexCardRarityLegendary => 'ЛЕГЕНДАРНАЯ';

  @override
  String get nodedexCardRarityRare => 'РЕДКАЯ';

  @override
  String get nodedexCardRarityStandard => 'СТАНДАРТНАЯ';

  @override
  String get nodedexCardRarityUncommon => 'НЕОБЫЧНАЯ';

  @override
  String get nodedexCardRarityUnder5 => 'Менее 5 встреч';

  @override
  String get nodedexChannelUtilLabel => 'Загрузка канала';

  @override
  String get nodedexClassificationChange => 'Изменить';

  @override
  String get nodedexClassificationClassify => 'Классифицировать';

  @override
  String get nodedexClassificationLabel => 'КЛАССИФИКАЦИЯ';

  @override
  String get nodedexClassificationTitle => 'Классификация';

  @override
  String get nodedexClassifyNodeDescription =>
      'Назначьте личную классификацию этой ноде. Она видна только вам.';

  @override
  String get nodedexClassifyNodeTitle => 'Классифицировать нода';

  @override
  String get nodedexClearFilter => 'Очистить';

  @override
  String get nodedexCloseGallerySemanticLabel => 'Закрыть галерею';

  @override
  String get nodedexCoSeenCompactLabel => 'Вместе';

  @override
  String get nodedexCoSeenDescription =>
      'Ноды, часто встречаемые в одном сеансе';

  @override
  String get nodedexCoSeenLinksTitle => 'Связи совместных наблюдений';

  @override
  String get nodedexCoSeenRelationshipDetails =>
      'Детали совместного наблюдения';

  @override
  String nodedexCollectedCount(int count) {
    return '$count собрано';
  }

  @override
  String get nodedexConfidenceLabel => 'Уверенность';

  @override
  String nodedexConfidenceTooltip(int percentage) {
    return 'Уверенность: $percentage%';
  }

  @override
  String get nodedexConstellationCloseSearch => 'Закрыть поиск';

  @override
  String get nodedexConstellationEmptySubtitle =>
      'Откройте больше нод, чтобы увидеть их связи.\nНоды, встреченные вместе, образуют связи созвездия.';

  @override
  String get nodedexConstellationEmptyTitle => 'Созвездие ещё не создано';

  @override
  String nodedexConstellationLinkCount(int count) {
    return '$count связей';
  }

  @override
  String get nodedexConstellationLinkTitle => 'Связь созвездия';

  @override
  String nodedexConstellationNodeCount(int count) {
    return '$count нод';
  }

  @override
  String get nodedexConstellationProfile => 'Профиль';

  @override
  String get nodedexConstellationSearchHint => 'Поиск по имени или ID ноды…';

  @override
  String get nodedexConstellationSearchNodes => 'Поиск нод';

  @override
  String get nodedexConstellationTitle => 'Созвездие';

  @override
  String get nodedexDayFri => 'Пт';

  @override
  String get nodedexDayFriday => 'Пятница';

  @override
  String get nodedexDayMon => 'Пн';

  @override
  String get nodedexDayMonday => 'Понедельник';

  @override
  String get nodedexDaySat => 'Сб';

  @override
  String get nodedexDaySaturday => 'Суббота';

  @override
  String get nodedexDaySun => 'Вс';

  @override
  String get nodedexDaySunday => 'Воскресенье';

  @override
  String get nodedexDayThu => 'Чт';

  @override
  String get nodedexDayThursday => 'Четверг';

  @override
  String get nodedexDayTue => 'Вт';

  @override
  String get nodedexDayTuesday => 'Вторник';

  @override
  String get nodedexDayWed => 'Ср';

  @override
  String get nodedexDayWednesday => 'Среда';

  @override
  String get nodedexDaysCompactLabel => 'Дни';

  @override
  String get nodedexDensityAll => 'Все';

  @override
  String get nodedexDensityDense => 'Плотная';

  @override
  String get nodedexDensityNormal => 'Обычная';

  @override
  String get nodedexDensitySparse => 'Разреженная';

  @override
  String get nodedexDensityStars => 'Звёзды';

  @override
  String get nodedexDetailNotFoundSubtitle =>
      'Эта нода ещё не была обнаружена.';

  @override
  String get nodedexDetailNotFoundTitle => 'Нода не найдена в NodeDex';

  @override
  String get nodedexDeviceTitle => 'Устройство';

  @override
  String get nodedexMrrpServicesTitle => 'MRRP Services';

  @override
  String get nodedexDiscoveryTitle => 'Обнаружение';

  @override
  String nodedexDistanceKilometers(String distance) {
    return '$distance км';
  }

  @override
  String nodedexDistanceMeters(String distance) {
    return '$distance м';
  }

  @override
  String get nodedexDistanceUnknown => 'расстояние неизвестно';

  @override
  String nodedexDurationDays(int days) {
    return '$days д';
  }

  @override
  String nodedexDurationHours(int hours) {
    return '$hours ч';
  }

  @override
  String nodedexDurationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String nodedexDurationMonths(int months) {
    return '$months мес';
  }

  @override
  String nodedexDurationMonthsDays(int months, int days) {
    return '$months мес $days д';
  }

  @override
  String nodedexDurationYears(int years) {
    return '$years г';
  }

  @override
  String nodedexDurationYearsMonths(int years, int months) {
    return '$years г $months мес';
  }

  @override
  String get nodedexEdgeDensityAll => 'Все';

  @override
  String get nodedexEdgeDensityDense => 'Плотная';

  @override
  String get nodedexEdgeDensityNormal => 'Обычная';

  @override
  String get nodedexEdgeDensitySparse => 'Разреженная';

  @override
  String nodedexEdgeDensityTooltip(String label) {
    return 'Плотность связей: $label';
  }

  @override
  String get nodedexEmptyAlbumDescription =>
      'Подключитесь к сетевому устройству и обнаруживайте ноды,\nчтобы начать формировать коллекцию';

  @override
  String get nodedexEmptyAlbumHintMove => 'Перемещайтесь';

  @override
  String get nodedexEmptyAlbumHintScan => 'Сканировать устройства';

  @override
  String get nodedexEmptyAlbumTitle => 'Карточек пока нет';

  @override
  String get nodedexEmptyAllSubtitle =>
      'Подключитесь к устройству Meshtastic, и ноды будут появляться здесь по мере их обнаружения в сети.';

  @override
  String get nodedexEmptyAllTitle => 'Ноды ещё не обнаружены';

  @override
  String get nodedexEmptyBeaconsSubtitle =>
      'Маяки — это ноды с очень высокой активностью и частыми встречами. Для их классификации требуется время.';

  @override
  String get nodedexEmptyBeaconsTitle => 'Маяки не найдены';

  @override
  String get nodedexEmptyContactSubtitle =>
      'Ноды, классифицированные вами как Контакт, появятся здесь. Удерживайте ноду, чтобы назначить эту метку.';

  @override
  String get nodedexEmptyContactTitle => 'Контакты отсутствуют';

  @override
  String get nodedexEmptyFrequentPeerSubtitle =>
      'Ноды, классифицированные вами как Частый партнёр, появятся здесь. Удерживайте ноду, чтобы назначить эту метку.';

  @override
  String get nodedexEmptyFrequentPeerTitle => 'Частые партнёры отсутствуют';

  @override
  String get nodedexEmptyGalleryDescription =>
      'Обнаруживайте ноды, чтобы наполнить коллекцию';

  @override
  String get nodedexEmptyGalleryTitle => 'Нет карточек для отображения';

  @override
  String get nodedexEmptyGhostsSubtitle =>
      'Призраки — это ноды, которые появляются редко относительно времени, в течение которого они известны.';

  @override
  String get nodedexEmptyGhostsTitle => 'Призраки не найдены';

  @override
  String get nodedexEmptyKnownRelaySubtitle =>
      'Ноды, классифицированные вами как Известный ретранслятор, появятся здесь. Удерживайте ноду, чтобы назначить эту метку.';

  @override
  String get nodedexEmptyKnownRelayTitle =>
      'Известные ретрансляторы отсутствуют';

  @override
  String get nodedexEmptyRecentSubtitle =>
      'Ноды, обнаруженные за последние 24 часа, появятся здесь.';

  @override
  String get nodedexEmptyRecentTitle => 'Недавних открытий нет';

  @override
  String get nodedexEmptyRelaysSubtitle =>
      'Ретрансляторы — это ноды с ролью маршрутизатора и активной переадресацией трафика.';

  @override
  String get nodedexEmptyRelaysTitle => 'Ретрансляторы не найдены';

  @override
  String get nodedexEmptySentinelsSubtitle =>
      'Часовые — это долгоживущие ноды с фиксированным положением и стабильным присутствием.';

  @override
  String get nodedexEmptySentinelsTitle => 'Часовые не найдены';

  @override
  String get nodedexEmptyTaggedSubtitle =>
      'Удерживайте ноду в списке, чтобы назначить социальную метку: Контакт, Доверенную ноду или Известный ретранслятор.';

  @override
  String get nodedexEmptyTaggedTitle => 'Нод с метками нет';

  @override
  String get nodedexEmptyTagline1 =>
      'Ноды ещё не обнаружены.\nПодключитесь к сетевому устройству, чтобы начать вести полевой журнал.';

  @override
  String get nodedexEmptyTagline2 =>
      'NodeDex каталогизирует каждый обнаруженная нода.\nКаждый получает уникальную процедурную идентичность.';

  @override
  String get nodedexEmptyTagline3 =>
      'Открывайте странников, часовых и призраков.\nЧерты личности формируются из поведенческих паттернов.';

  @override
  String get nodedexEmptyTagline4 =>
      'Отмечайте ноды как контакты или доверенные ретрансляторы.\nСтройте своё сетевое сообщество со временем.';

  @override
  String get nodedexEmptyTitleKeyword => 'NodeDex';

  @override
  String get nodedexEmptyTitlePrefix => 'Ваш ';

  @override
  String get nodedexEmptyTitleSuffix => ' пуст';

  @override
  String get nodedexEmptyTrustedNodeSubtitle =>
      'Ноды, классифицированные вами как Доверенная нода, появятся здесь. Удерживайте ноду, чтобы назначить эту метку.';

  @override
  String get nodedexEmptyTrustedNodeTitle => 'Доверенных нод нет';

  @override
  String get nodedexEmptyWanderersSubtitle =>
      'Странники — это ноды, замеченные в нескольких местах. Они появляются со временем по мере накопления данных о положении.';

  @override
  String get nodedexEmptyWanderersTitle => 'Странники не найдены';

  @override
  String get nodedexEncounterActivityTitle => 'Активность встреч';

  @override
  String nodedexEncounterCountLabel(int count) {
    return '$count встреч';
  }

  @override
  String get nodedexEncounterLogLabel => 'ЖУРНАЛ ВСТРЕЧ';

  @override
  String nodedexEncountersCount(int count) {
    return '$count встреч';
  }

  @override
  String get nodedexEncountersLabel => 'Встречи';

  @override
  String get nodedexEncountersStatLabel => 'Встречи';

  @override
  String get nodedexEvidenceActiveLastHour =>
      'Активен в течение последнего часа';

  @override
  String nodedexEvidenceAirtimeTx(String percent) {
    return 'Время в эфире TX $percent%';
  }

  @override
  String nodedexEvidenceChannelUtilization(String percent) {
    return 'Загрузка канала $percent%';
  }

  @override
  String nodedexEvidenceCoSeenWith(int count) {
    return 'Замечен вместе с $count нодами';
  }

  @override
  String nodedexEvidenceDistinctPositions(int count) {
    return 'Наблюдался в $count различных позициях';
  }

  @override
  String nodedexEvidenceEncounterRate(String rate) {
    return '$rate встреч/день';
  }

  @override
  String nodedexEvidenceEncounterRateLow(String rate) {
    return 'Частота встреч $rate/день';
  }

  @override
  String nodedexEvidenceEncountersReliable(int count) {
    return '$count встреч (надёжных)';
  }

  @override
  String nodedexEvidenceFewEncountersOverDays(int encounters, int days) {
    return 'Всего $encounters встреч за $days дней';
  }

  @override
  String get nodedexEvidenceFixedLocation => 'Фиксированное местоположение';

  @override
  String get nodedexEvidenceFixedPosition =>
      'Фиксированная позиция (одно место)';

  @override
  String get nodedexEvidenceHighEncounterCount => 'Высокое число встреч (20+)';

  @override
  String get nodedexEvidenceInsufficientData =>
      'Недостаточно данных для классификации';

  @override
  String nodedexEvidenceIrregularTiming(String cv) {
    return 'Нерегулярный интервал (CV $cv)';
  }

  @override
  String nodedexEvidenceKnownForDays(int days) {
    return 'Известен $days дней';
  }

  @override
  String nodedexEvidenceLastSeenDaysAgo(int days) {
    return 'Последний раз замечен $days д. назад';
  }

  @override
  String nodedexEvidenceMaxRange(String km) {
    return 'Максимальная дальность $km км';
  }

  @override
  String nodedexEvidenceMessagesExchanged(int count) {
    return '$count сообщений обменяно';
  }

  @override
  String nodedexEvidenceMessagesPerEncounter(String ratio) {
    return '$ratio сообщений на встречу';
  }

  @override
  String get nodedexEvidenceMobileWithMessaging =>
      'Мобильный с активным обменом сообщениями';

  @override
  String nodedexEvidenceModerateEncounterRate(String rate) {
    return 'Умеренная частота встреч ($rate/день)';
  }

  @override
  String nodedexEvidencePersistentPresence(int days) {
    return 'Постоянное присутствие ($days дней)';
  }

  @override
  String nodedexEvidencePositionsObserved(int count) {
    return '$count позиций зафиксировано';
  }

  @override
  String nodedexEvidenceRoleIs(String role) {
    return 'Роль: $role';
  }

  @override
  String nodedexEvidenceSeenAcrossRegions(int count) {
    return 'Замечен в $count регионах';
  }

  @override
  String nodedexEvidenceSomewhatIrregularTiming(String cv) {
    return 'Несколько нерегулярный интервал (CV $cv)';
  }

  @override
  String nodedexEvidenceTotalEncounters(int count) {
    return '$count встреч всего';
  }

  @override
  String nodedexEvidenceUptime(int days) {
    return 'Время работы $days д';
  }

  @override
  String nodedexExportFailed(String error) {
    return 'Экспорт не удался: $error';
  }

  @override
  String get nodedexExportNothingToExport =>
      'Нечего экспортировать — NodeDex пуст';

  @override
  String get nodedexExportShareSubject => 'Экспорт Socialmesh NodeDex';

  @override
  String nodedexFieldNoteAnchor0(int coSeen) {
    return 'Нода-хаб. Замечен вместе с $coSeen другими нодами.';
  }

  @override
  String get nodedexFieldNoteAnchor1 =>
      'Социальный центр локальной сети. Множество связей.';

  @override
  String nodedexFieldNoteAnchor2(int coSeen) {
    return 'Постоянный хаб. $coSeen нод в непосредственной близости.';
  }

  @override
  String get nodedexFieldNoteAnchor3 =>
      'Якорная точка для соседних нод. Фиксирован и хорошо связан.';

  @override
  String get nodedexFieldNoteAnchor4 =>
      'Центральная нода локальной топологии. Высокая плотность совместных наблюдений.';

  @override
  String get nodedexFieldNoteAnchor5 =>
      'Гравитационный центр. Другие ноды группируются вокруг него.';

  @override
  String nodedexFieldNoteAnchor6(int coSeen) {
    return 'Инфраструктурный якорь. $coSeen связанных партнёров.';
  }

  @override
  String get nodedexFieldNoteAnchor7 =>
      'Сетевой нексус. Стабильное присутствие с широкими связями.';

  @override
  String nodedexFieldNoteBeacon0(String rate) {
    return 'Устойчивый сигнал. $rate наблюдений в день.';
  }

  @override
  String get nodedexFieldNoteBeacon1 =>
      'Постоянное присутствие в сети. Всегда транслирует.';

  @override
  String nodedexFieldNoteBeacon2(String lastSeen) {
    return 'Надёжный и стабильный. Последний раз слышан $lastSeen.';
  }

  @override
  String nodedexFieldNoteBeacon3(int encounters) {
    return 'Высокая доступность. Зафиксировано $encounters встреч.';
  }

  @override
  String get nodedexFieldNoteBeacon4 =>
      'Непрерывная работа подтверждена. Сигнал почти не пропадает.';

  @override
  String get nodedexFieldNoteBeacon5 =>
      'Постоянно активен. Надёжная точка отсчёта.';

  @override
  String nodedexFieldNoteBeacon6(String rate) {
    return 'Стабильная трансляция. $rate наблюдений в день.';
  }

  @override
  String get nodedexFieldNoteBeacon7 =>
      'Чёткий ритм. Предсказуемые интервалы между сеансами.';

  @override
  String nodedexFieldNoteCourier0(int messages, int encounters) {
    return 'Большой объём сообщений. $messages сообщений за $encounters встреч.';
  }

  @override
  String get nodedexFieldNoteCourier1 =>
      'Носитель данных. Повышенное соотношение сообщений к встречам.';

  @override
  String get nodedexFieldNoteCourier2 =>
      'Активный обмен сообщениями. Поведение курьера вероятно.';

  @override
  String nodedexFieldNoteCourier3(int messages) {
    return 'Переносит данные между сегментами сети. Зарегистрировано $messages сообщений.';
  }

  @override
  String get nodedexFieldNoteCourier4 =>
      'Высокая плотность сообщений указывает на целенаправленную передачу данных.';

  @override
  String nodedexFieldNoteCourier5(int messages) {
    return 'Нода с интенсивной коммуникацией. Зафиксировано $messages обменов.';
  }

  @override
  String get nodedexFieldNoteCourier6 =>
      'Частый посредник. Передаёт данные по сети.';

  @override
  String get nodedexFieldNoteCourier7 =>
      'Зафиксирован паттерн доставки. Сообщений больше, чем встреч.';

  @override
  String get nodedexFieldNoteDrifter0 =>
      'Время появления непредсказуемо. Появляется и исчезает без закономерности.';

  @override
  String get nodedexFieldNoteDrifter1 =>
      'Нерегулярные интервалы между наблюдениями.';

  @override
  String get nodedexFieldNoteDrifter2 =>
      'Нет стабильного расписания. Поведение дрейфера подтверждено.';

  @override
  String get nodedexFieldNoteDrifter3 =>
      'Появляется спорадически, но не редко. Время непредсказуемо.';

  @override
  String get nodedexFieldNoteDrifter4 =>
      'Сигнал то появляется, то пропадает. Ритм не обнаружен.';

  @override
  String get nodedexFieldNoteDrifter5 =>
      'Присутствует, но ненадёжен. Интервалы сильно варьируются.';

  @override
  String get nodedexFieldNoteDrifter6 =>
      'Время наблюдений хаотично. Периодичность не найдена.';

  @override
  String get nodedexFieldNoteDrifter7 =>
      'Непостоянен, но активен. Расписание не поддаётся предсказанию.';

  @override
  String nodedexFieldNoteGhost0(String lastSeen) {
    return 'Наблюдается редко. Последнее подтверждённое обнаружение: $lastSeen.';
  }

  @override
  String nodedexFieldNoteGhost1(int encounters, int age) {
    return 'Неуловимый. $encounters встреч за $age дней.';
  }

  @override
  String get nodedexFieldNoteGhost2 =>
      'Сигнал появляется ненадолго и исчезает. Паттерн неизвестен.';

  @override
  String get nodedexFieldNoteGhost3 =>
      'Только слабый след. Недостаточно данных для профиля.';

  @override
  String get nodedexFieldNoteGhost4 =>
      'Слабый и спорадический. Присутствие ненадёжно.';

  @override
  String get nodedexFieldNoteGhost5 =>
      'Появляется без предупреждения. Исчезает бесследно.';

  @override
  String get nodedexFieldNoteGhost6 =>
      'Низкая плотность встреч. Поведение сложно классифицировать.';

  @override
  String get nodedexFieldNoteGhost7 =>
      'Обнаружен на периферии. Окно наблюдения узкое.';

  @override
  String get nodedexFieldNoteLabel => 'Полевая заметка';

  @override
  String get nodedexFieldNoteRelay0 =>
      'Переадресация трафика. Роль маршрутизатора подтверждена.';

  @override
  String get nodedexFieldNoteRelay1 =>
      'Активный ретранслятор. Загрузка канала повышена.';

  @override
  String get nodedexFieldNoteRelay2 =>
      'Инфраструктурная роль: наблюдается переадресация трафика.';

  @override
  String get nodedexFieldNoteRelay3 =>
      'Обнаружена сигнатура маршрутизатора. Высокое использование эфирного времени.';

  @override
  String get nodedexFieldNoteRelay4 =>
      'Элемент магистрали сети. Обеспечивает связность.';

  @override
  String nodedexFieldNoteRelay5(int encounters) {
    return 'Поведение ретранслятора стабильно на протяжении $encounters сеансов.';
  }

  @override
  String get nodedexFieldNoteRelay6 =>
      'Обработчик трафика. Паттерн переадресации стабилен.';

  @override
  String get nodedexFieldNoteRelay7 =>
      'Сетевая инфраструктура. Маршрутизация подтверждена ролью.';

  @override
  String nodedexFieldNoteSentinel0(int age) {
    return 'Фиксированная позиция. Мониторинг ведётся $age дней.';
  }

  @override
  String get nodedexFieldNoteSentinel1 =>
      'Стационарная установка. Сигнал стабильный и сильный.';

  @override
  String nodedexFieldNoteSentinel2(int encounters) {
    return 'Присутствие часового. $encounters наблюдений из одной точки.';
  }

  @override
  String nodedexFieldNoteSentinel3(String firstSeen) {
    return 'Долгосрочный пост. Первое наблюдение: $firstSeen.';
  }

  @override
  String get nodedexFieldNoteSentinel4 =>
      'Нет отклонений позиции. Инфраструктурная сигнатура подтверждена.';

  @override
  String get nodedexFieldNoteSentinel5 =>
      'Удерживает позицию. Надёжен с момента первого контакта.';

  @override
  String nodedexFieldNoteSentinel6(int snr) {
    return 'Стационарное развёртывание. Лучший сигнал $snr dB SNR.';
  }

  @override
  String nodedexFieldNoteSentinel7(int age) {
    return 'Постоянный объект. Непрерывно наблюдается в течение $age дней.';
  }

  @override
  String get nodedexFieldNoteUnknown0 =>
      'Недавно обнаружен. Наблюдение ведётся.';

  @override
  String get nodedexFieldNoteUnknown1 =>
      'Новый контакт. Недостаточно данных для классификации.';

  @override
  String nodedexFieldNoteUnknown2(String firstSeen) {
    return 'Первая запись: $firstSeen. Ожидаются дальнейшие сигналы.';
  }

  @override
  String get nodedexFieldNoteUnknown3 =>
      'Личность зафиксирована. Поведенческий профиль формируется.';

  @override
  String get nodedexFieldNoteUnknown4 =>
      'Первичная запись. Для оценки необходимо больше встреч.';

  @override
  String get nodedexFieldNoteUnknown5 =>
      'Каталогизирован. Поведенческий паттерн ещё не установлен.';

  @override
  String get nodedexFieldNoteUnknown6 =>
      'Сигнал принят. Классификация отложена.';

  @override
  String get nodedexFieldNoteUnknown7 =>
      'Запись создана. Мониторинг инициирован.';

  @override
  String nodedexFieldNoteWanderer0(int regions) {
    return 'Зафиксирован в $regions регионах. Постоянного направления нет.';
  }

  @override
  String nodedexFieldNoteWanderer1(int positions) {
    return 'Проходит, не задерживаясь. Зафиксировано $positions позиций.';
  }

  @override
  String nodedexFieldNoteWanderer2(int regions) {
    return 'Переходящий сигнал. Наблюдался в движении через $regions зоны.';
  }

  @override
  String nodedexFieldNoteWanderer3(String distance) {
    return 'Предполагается миграционный паттерн. Дальность до $distance.';
  }

  @override
  String get nodedexFieldNoteWanderer4 =>
      'Появляется в разных координатах в каждом сеансе.';

  @override
  String nodedexFieldNoteWanderer5(int regions) {
    return 'Якорная точка не обнаружена. Дрейф подтверждён в $regions регионах.';
  }

  @override
  String nodedexFieldNoteWanderer6(int positions) {
    return 'Зарегистрирован в $positions позициях. Маршрут неясен.';
  }

  @override
  String get nodedexFieldNoteWanderer7 =>
      'Источник сигнала меняется между сеансами.';

  @override
  String get nodedexFilterAll => 'Все';

  @override
  String get nodedexFilterByDateHelp => 'Фильтровать встречи по дате';

  @override
  String get nodedexFilterRecent => 'Недавние';

  @override
  String get nodedexFilterTagged => 'С метками';

  @override
  String get nodedexFirmwareLabel => 'Прошивка';

  @override
  String get nodedexFirstDiscovered => 'Первое обнаружение';

  @override
  String get nodedexFirstSeenStatLabel => 'Впервые замечен';

  @override
  String get nodedexFirstSighting => 'Первое наблюдение';

  @override
  String get nodedexGalleryHint =>
      'Нажмите, чтобы перевернуть • Проведите для просмотра';

  @override
  String nodedexGalleryPositionCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String get nodedexGotIt => 'Понятно';

  @override
  String get nodedexGroupByLabel => 'ГРУППИРОВАТЬ ПО';

  @override
  String get nodedexGroupByRarity => 'Редкости';

  @override
  String get nodedexGroupByRegion => 'Региону';

  @override
  String get nodedexGroupByTrait => 'Характеристике';

  @override
  String get nodedexHardwareLabel => 'Оборудование';

  @override
  String get nodedexHelpActivityTimeline => 'История активности';

  @override
  String get nodedexHelpClassification => 'Классификация';

  @override
  String get nodedexHelpConstellationLinks => 'Связи созвездия';

  @override
  String get nodedexHelpDeviceInfo => 'Информация об устройстве';

  @override
  String get nodedexHelpDiscoveryStats => 'Статистика обнаружений';

  @override
  String get nodedexHelpInfoDefault => 'Информация';

  @override
  String get nodedexHelpNote => 'Заметка';

  @override
  String get nodedexHelpPersonalityTrait => 'Характеристика личности';

  @override
  String get nodedexHelpRecentEncounters => 'Недавние встречи';

  @override
  String get nodedexHelpRegionHistory => 'История регионов';

  @override
  String get nodedexHelpSigil => 'Sigil';

  @override
  String get nodedexHelpSignalRecords => 'Записи сигнала';

  @override
  String nodedexImportButtonLabelPlural(int count) {
    return 'Импортировать $count записей';
  }

  @override
  String nodedexImportButtonLabelSingular(int count) {
    return 'Импортировать $count запись';
  }

  @override
  String nodedexImportClassificationConflictPlural(int count) {
    return '$count конфликтов классификации';
  }

  @override
  String nodedexImportClassificationConflictSingular(int count) {
    return '$count конфликт классификации';
  }

  @override
  String get nodedexImportConflictingDataMessage =>
      'Некоторые записи содержат конфликтующие данные';

  @override
  String get nodedexImportConflictingEntriesLabel => 'Конфликтующие записи';

  @override
  String get nodedexImportConflictsFallback =>
      'Обнаружены конфликты в полях пользователя.';

  @override
  String nodedexImportConflictsResolveBelow(String details) {
    return '$details. Выберите способ разрешения ниже.';
  }

  @override
  String nodedexImportEntriesInFile(int count) {
    return '$count записей в файле';
  }

  @override
  String nodedexImportFailed(String error) {
    return 'Импорт не удался: $error';
  }

  @override
  String get nodedexImportFailedToReadFile => 'Не удалось прочитать файл';

  @override
  String get nodedexImportFieldClassification => 'Классификация';

  @override
  String get nodedexImportFieldNote => 'Заметка';

  @override
  String get nodedexImportHideDetails => 'Скрыть подробности';

  @override
  String get nodedexImportImportLabel => 'Импорт';

  @override
  String get nodedexImportImportingLabel => 'Импорт...';

  @override
  String get nodedexImportLocalLabel => 'Локальные';

  @override
  String get nodedexImportMergeStrategyLabel => 'Стратегия слияния';

  @override
  String get nodedexImportNoValidEntries =>
      'В файле не найдено допустимых записей NodeDex';

  @override
  String get nodedexImportNoneValue => 'Нет';

  @override
  String nodedexImportNoteConflictPlural(int count) {
    return '$count конфликтов заметок';
  }

  @override
  String nodedexImportNoteConflictSingular(int count) {
    return '$count конфликт заметки';
  }

  @override
  String get nodedexImportNothingNewToImport => 'Нет ничего нового для импорта';

  @override
  String get nodedexImportNothingToImportDescription =>
      'Файл не содержит допустимых записей NodeDex.';

  @override
  String get nodedexImportNothingToImportTitle => 'Нечего импортировать';

  @override
  String get nodedexImportPreviewSubtitle => 'Проверьте перед применением';

  @override
  String get nodedexImportPreviewTitle => 'Предварительный просмотр импорта';

  @override
  String get nodedexImportShowDetails => 'Показать подробности';

  @override
  String get nodedexImportStrategyKeepLocalDescription =>
      'Ваши классификации и заметки останутся без изменений';

  @override
  String get nodedexImportStrategyKeepLocalTitle => 'Сохранить локальные';

  @override
  String get nodedexImportStrategyPreferImportDescription =>
      'Использовать импортированные классификации и заметки там, где они отличаются';

  @override
  String get nodedexImportStrategyPreferImportTitle => 'Предпочесть импорт';

  @override
  String get nodedexImportStrategyReviewEachDescription =>
      'Выбирать для каждого конфликта, какое значение сохранить';

  @override
  String get nodedexImportStrategyReviewEachTitle => 'Проверять каждый';

  @override
  String nodedexImportSuccessPlural(int count) {
    return 'Импортировано $count записей';
  }

  @override
  String nodedexImportSuccessSingular(int count) {
    return 'Импортирована $count запись';
  }

  @override
  String get nodedexImportSummaryConflicts => 'Конфликты';

  @override
  String get nodedexImportSummaryMerge => 'Слияние';

  @override
  String get nodedexImportSummaryNew => 'Новые';

  @override
  String get nodedexKnownFor => 'Известен с';

  @override
  String nodedexKnownForDaysAgo(int days) {
    return '$days дней назад';
  }

  @override
  String nodedexKnownForHoursAgo(int hours) {
    return '$hours ч назад';
  }

  @override
  String get nodedexKnownForOneDayAgo => '1 день назад';

  @override
  String get nodedexLastLogged => 'Последняя запись';

  @override
  String nodedexLastReadings(int count) {
    return 'Последние $count показаний';
  }

  @override
  String nodedexLastRelative(String relative) {
    return '$relative назад';
  }

  @override
  String get nodedexLastSeen => 'Последний раз в сети';

  @override
  String get nodedexLastSeenStatLabel => 'Последний раз в сети';

  @override
  String nodedexLastSeenAtTime(String date, String time) {
    return '$date в $time';
  }

  @override
  String get nodedexLegendFair => 'Среднее';

  @override
  String get nodedexLegendNoData => 'Нет данных';

  @override
  String get nodedexLegendStrong => 'Сильный';

  @override
  String get nodedexLegendWeak => 'Слабый';

  @override
  String nodedexLinkCountPlural(int count) {
    return '$count связей';
  }

  @override
  String nodedexLinkCountSingular(int count) {
    return '$count связь';
  }

  @override
  String get nodedexLinkStrengthLabel => 'Сила связи';

  @override
  String nodedexLinkedForDuration(String duration) {
    return 'Связь $duration';
  }

  @override
  String get nodedexMaxDistanceStatLabel => 'Макс. расстояние';

  @override
  String nodedexMaxRange(String distance) {
    return 'Макс. дальность: $distance';
  }

  @override
  String get nodedexMaxRangeLabel => 'Макс. дальность';

  @override
  String get nodedexMessageActivity => 'Активность сообщений';

  @override
  String nodedexMessagesExchangedCoPresent(int count) {
    return '$count сообщений обменяно в присутствии друг друга';
  }

  @override
  String get nodedexMessagesLabel => 'Сообщения';

  @override
  String get nodedexMessagesStatLabel => 'Сообщения';

  @override
  String get nodedexNicknameHint => 'Никнейм';

  @override
  String get nodedexNoClassification =>
      'Классификация не назначена. Нажмите «Классифицировать», чтобы добавить.';

  @override
  String get nodedexNoEncountersOnDate => 'Встреч в эту дату нет';

  @override
  String get nodedexNoEncountersRecorded => 'Встречи не зафиксированы';

  @override
  String get nodedexNoNoteYet =>
      'Заметок нет. Нажмите «Добавить заметку», чтобы написать.';

  @override
  String get nodedexNoRelationshipDataDescription =>
      'Эти ноды не наблюдались вместе.';

  @override
  String get nodedexNoRelationshipDataTitle => 'Нет данных о связи';

  @override
  String nodedexNodeCountPlural(int count) {
    return '$count нод';
  }

  @override
  String nodedexNodeCountSingular(int count) {
    return '$count нода';
  }

  @override
  String get nodedexNoteAdd => 'Добавить заметку';

  @override
  String get nodedexNoteCancel => 'Отмена';

  @override
  String get nodedexNoteEdit => 'Редактировать';

  @override
  String get nodedexNoteHint => 'Напишите заметку об этом ноде...';

  @override
  String get nodedexNoteSave => 'Сохранить';

  @override
  String get nodedexNoteTitle => 'Заметка';

  @override
  String get nodedexObservationTimelineTitle => 'История наблюдений';

  @override
  String nodedexObservedDate(String date) {
    return 'Наблюдался $date';
  }

  @override
  String get nodedexPaletteColorPrimary => 'Основной';

  @override
  String get nodedexPaletteColorSecondary => 'Дополнительный';

  @override
  String get nodedexPaletteColorTertiary => 'Третичный';

  @override
  String get nodedexPatinaAxisEncounters => 'Встречи';

  @override
  String get nodedexPatinaAxisEncountersDescription =>
      'Количество отдельных наблюдений';

  @override
  String get nodedexPatinaAxisReach => 'Охват';

  @override
  String get nodedexPatinaAxisReachDescription =>
      'Географический охват по регионам';

  @override
  String get nodedexPatinaAxisRecency => 'Давность';

  @override
  String get nodedexPatinaAxisRecencyDescription =>
      'Насколько недавно эта нода была активна';

  @override
  String get nodedexPatinaAxisSignalDepth => 'Глубина сигнала';

  @override
  String get nodedexPatinaAxisSignalDepthDescription =>
      'Качество собранных записей сигнала';

  @override
  String get nodedexPatinaAxisSocial => 'Социальный';

  @override
  String get nodedexPatinaAxisSocialDescription =>
      'Совместные наблюдения и сообщения';

  @override
  String get nodedexPatinaAxisTenure => 'Стаж';

  @override
  String get nodedexPatinaAxisTenureDescription =>
      'Как давно известен эта нода';

  @override
  String get nodedexPatinaBreakdownSubtitle =>
      'Накопленная история по шести измерениям';

  @override
  String get nodedexPatinaBreakdownTitle => 'Детали патины';

  @override
  String get nodedexPatinaEncounters => 'Встречи';

  @override
  String get nodedexPatinaLabel => 'ПАТИНА';

  @override
  String get nodedexPatinaReach => 'Охват';

  @override
  String get nodedexPatinaRecency => 'Давность';

  @override
  String get nodedexPatinaSignal => 'Сигнал';

  @override
  String get nodedexPatinaSocial => 'Социальный';

  @override
  String get nodedexPatinaStampArchival => 'Архивный';

  @override
  String get nodedexPatinaStampCanonical => 'Канонический';

  @override
  String get nodedexPatinaStampEtched => 'Гравированный';

  @override
  String get nodedexPatinaStampFaint => 'Слабый';

  @override
  String get nodedexPatinaStampInked => 'Отпечатанный';

  @override
  String get nodedexPatinaStampLogged => 'Записанный';

  @override
  String get nodedexPatinaStampNoted => 'Отмеченный';

  @override
  String get nodedexPatinaStampTrace => 'След';

  @override
  String get nodedexPatinaTenure => 'Стаж';

  @override
  String get nodedexPerDay => '/день';

  @override
  String get nodedexPositionsLabel => 'Позиции';

  @override
  String get nodedexPresenceActive => 'Активен';

  @override
  String get nodedexPresenceFading => 'Затухает';

  @override
  String get nodedexPresenceStale => 'Устарел';

  @override
  String get nodedexPresenceUnknown => 'Неизвестно';

  @override
  String get nodedexProfileButton => 'Профиль';

  @override
  String nodedexRarityCardsPageTitle(String rarityLabel) {
    return 'Карточки $rarityLabel';
  }

  @override
  String get nodedexRecentLabel => 'НЕДАВНИЕ';

  @override
  String nodedexRegionEncounterCount(int count) {
    return '$count встреч';
  }

  @override
  String get nodedexRegionsCompactLabel => 'Регионы';

  @override
  String get nodedexRegionsLabel => 'Регионы';

  @override
  String get nodedexRelationshipTimeline => 'История отношений';

  @override
  String nodedexRelativeDaysAgo(int days) {
    return '$daysд назад';
  }

  @override
  String nodedexRelativeHoursAgo(int hours) {
    return '$hoursч назад';
  }

  @override
  String get nodedexRelativeJustNow => 'только что';

  @override
  String nodedexRelativeMinutesAgo(int minutes) {
    return '$minutesм назад';
  }

  @override
  String nodedexRelativeMonthsAgo(int months) {
    return '$monthsмес назад';
  }

  @override
  String nodedexRelativeTimeDaysAgo(int days) {
    return '$daysд назад';
  }

  @override
  String nodedexRelativeTimeHoursAgo(int hours) {
    return '$hoursч назад';
  }

  @override
  String nodedexRelativeTimeMinutesAgo(int minutes) {
    return '$minutesм назад';
  }

  @override
  String get nodedexRelativeTimeMomentsAgo => 'только что';

  @override
  String nodedexRelativeTimeMonthsAgo(int months) {
    return '$months месяцев назад';
  }

  @override
  String get nodedexRelativeTimeOneMonthAgo => '1 месяц назад';

  @override
  String get nodedexRelativeTimeYesterday => 'вчера';

  @override
  String get nodedexRemoveClassification => 'Удалить классификацию';

  @override
  String get nodedexResetViewTooltip => 'Сбросить вид';

  @override
  String get nodedexRngLabel => 'RNG';

  @override
  String nodedexRssiDbmValue(String value) {
    return '$value dBm';
  }

  @override
  String get nodedexRssiLabel => 'RSSI';

  @override
  String get nodedexSearchHint => 'Найти ноду';

  @override
  String get nodedexSectionDiscoveredNodes => 'Обнаруженные ноды';

  @override
  String get nodedexSectionYourDevice => 'Ваше устройство';

  @override
  String nodedexSeenTogetherCount(int count) {
    return 'Замечены вместе $count раз';
  }

  @override
  String nodedexSelectedLinksCount(int count) {
    return '$count связей';
  }

  @override
  String get nodedexSetNickname => 'Задать никнейм';

  @override
  String get nodedexSettingsTooltip => 'Настройки';

  @override
  String nodedexShareCardCheckOut(String name) {
    return 'Посмотрите карточку Sigil для $name в Socialmesh!';
  }

  @override
  String get nodedexShareCardImageFailed =>
      'Не удалось создать изображение карточки';

  @override
  String get nodedexShareCouldNotShare => 'Не удалось поделиться карточкой';

  @override
  String get nodedexShareGetSocialmesh => 'Получить Socialmesh:';

  @override
  String get nodedexShareSigilCard => 'Поделиться карточкой Sigil';

  @override
  String nodedexSightingsPlural(int count) {
    return '$count наблюдений';
  }

  @override
  String nodedexSightingsSingular(int count) {
    return '$count наблюдение';
  }

  @override
  String get nodedexSigilCardTitle => 'Карточка Sigil';

  @override
  String get nodedexSignalRecordsTitle => 'Записи сигнала';

  @override
  String nodedexSnrDbValue(String value) {
    return '$value dB';
  }

  @override
  String get nodedexSnrLabel => 'SNR';

  @override
  String get nodedexSnrTrend => 'ТРЕНД SNR';

  @override
  String get nodedexSocialTagContactDescription =>
      'Человек, с которым вы общаетесь';

  @override
  String get nodedexSocialTagFrequentPeerDescription =>
      'Регулярно появляется в сети';

  @override
  String get nodedexSocialTagKnownRelayDescription =>
      'Нода, надёжно пересылающий трафик';

  @override
  String get nodedexSocialTagTrustedNodeDescription =>
      'Проверенная инфраструктура, которой вы доверяете';

  @override
  String get nodedexSortDiscovered => 'Обнаружен';

  @override
  String get nodedexSortEncounters => 'Встречи';

  @override
  String get nodedexSortFirstDiscovered => 'Первое обнаружение';

  @override
  String get nodedexSortLastSeen => 'Последний раз в сети';

  @override
  String get nodedexSortLongestRange => 'Наибольшая дальность';

  @override
  String get nodedexSortMostEncounters => 'Больше всего встреч';

  @override
  String get nodedexSortName => 'Имя';

  @override
  String get nodedexSortRange => 'Дальность';

  @override
  String get nodedexStatCoSeen => 'Совместно замечены';

  @override
  String get nodedexStatDuration => 'Продолжительность';

  @override
  String get nodedexStatFirstLink => 'Первая связь';

  @override
  String get nodedexStatLastSeen => 'Последний раз в сети';

  @override
  String get nodedexStatMessages => 'Сообщения';

  @override
  String get nodedexStatsDays => 'ДНИ';

  @override
  String get nodedexStatsEncounters => 'ВСТРЕЧИ';

  @override
  String get nodedexStatsNodes => 'УЗЛЫ';

  @override
  String get nodedexStatsRegions => 'РЕГИОНЫ';

  @override
  String nodedexStreakDays(int count) {
    return 'Серия $count дней';
  }

  @override
  String get nodedexStrengthEmerging => 'Формирующаяся';

  @override
  String get nodedexStrengthModerate => 'Умеренная';

  @override
  String get nodedexStrengthNew => 'Новая';

  @override
  String get nodedexStrengthStrong => 'Сильная';

  @override
  String get nodedexStrengthVeryStrong => 'Очень сильная';

  @override
  String get nodedexSummaryCardTitle => 'Сводка';

  @override
  String nodedexSummaryEncountersRecorded(int count) {
    return '$count встреч зафиксировано';
  }

  @override
  String get nodedexSummaryKeepObserving =>
      'Продолжайте наблюдать, чтобы сформировать профиль';

  @override
  String nodedexSummaryMostActiveIn(String bucket) {
    return 'Наиболее активен $bucket';
  }

  @override
  String nodedexSummarySeenDaysOf14(int activeDays) {
    return 'В сети $activeDays из последних 14 дней';
  }

  @override
  String nodedexSummarySpottedDaysOf14(int activeDays) {
    return 'Замечен в $activeDays из последних 14 дней';
  }

  @override
  String nodedexSummaryUsuallyOnDay(String day) {
    return 'Обычно по $dayм';
  }

  @override
  String get nodedexSwitchToAlbumView => 'Переключиться на вид альбома';

  @override
  String get nodedexSwitchToListView => 'Переключиться на вид списка';

  @override
  String get nodedexTagContact => 'Контакт';

  @override
  String get nodedexTagFrequentPeer => 'Частый партнёр';

  @override
  String get nodedexTagKnownRelay => 'Известный ретранслятор';

  @override
  String get nodedexTagTrustedNode => 'Доверенная нода';

  @override
  String get nodedexTapCardToFlipSemanticLabel =>
      'Нажмите на карточку, чтобы перевернуть';

  @override
  String get nodedexTapToFlip => 'НАЖМИТЕ, ЧТОБЫ ПЕРЕВЕРНУТЬ';

  @override
  String get nodedexTimeBucketDawn => 'Утро';

  @override
  String get nodedexTimeBucketDawnRange => '5:00 – 11:00';

  @override
  String get nodedexTimeBucketEvening => 'Вечер';

  @override
  String get nodedexTimeBucketEveningRange => '17:00 – 23:00';

  @override
  String get nodedexTimeBucketMidday => 'День';

  @override
  String get nodedexTimeBucketMiddayRange => '11:00 – 17:00';

  @override
  String get nodedexTimeBucketNight => 'Ночь';

  @override
  String get nodedexTimeBucketNightRange => '23:00 – 5:00';

  @override
  String nodedexTimelineChannel(String channel) {
    return 'Канал $channel';
  }

  @override
  String get nodedexTimelineCouldNotLoad => 'Не удалось загрузить историю';

  @override
  String nodedexTimelineEncounterBestSnr(int snr) {
    return ', лучший SNR ${snr}dB';
  }

  @override
  String nodedexTimelineEncounterClosest(String distance) {
    return ', ближайшее $distance';
  }

  @override
  String nodedexTimelineEncounterSession(
    int count,
    String duration,
    String detail,
  ) {
    return '$count встреч за $duration$detail';
  }

  @override
  String get nodedexTimelineEncountered => 'Встречен';

  @override
  String nodedexTimelineEncounteredAtDistance(String distance) {
    return 'Встречен на расстоянии $distance';
  }

  @override
  String nodedexTimelineEncounteredSnr(int snr) {
    return 'Встречен (SNR ${snr}dB)';
  }

  @override
  String get nodedexTimelineEventsAppearHere =>
      'События будут появляться здесь по мере взаимодействия с этой нодой.';

  @override
  String get nodedexTimelineFirst => 'Первый';

  @override
  String nodedexTimelineHoursUnit(String hours) {
    return '$hours ч';
  }

  @override
  String get nodedexTimelineJustNow => 'Только что';

  @override
  String get nodedexTimelineLatest => 'Последний';

  @override
  String get nodedexTimelineLessThanOneMin => '<1 мин';

  @override
  String nodedexTimelineMinutesUnit(int minutes) {
    return '$minutes мин';
  }

  @override
  String get nodedexTimelineNoActivityYet => 'Активности пока нет';

  @override
  String nodedexTimelineReceived(String text) {
    return 'Получено: $text';
  }

  @override
  String nodedexTimelineSent(String text) {
    return 'Отправлено: $text';
  }

  @override
  String nodedexTimelineSignal(String content) {
    return 'Сигнал: $content';
  }

  @override
  String get nodedexTitle => 'NodeDex';

  @override
  String nodedexTotalCount(int count) {
    return '$count всего';
  }

  @override
  String get nodedexTraitAnchor => 'Якорь';

  @override
  String get nodedexTraitAnchorDescription =>
      'Постоянная нода со множеством соединений';

  @override
  String get nodedexTraitBeacon => 'Маяк';

  @override
  String get nodedexTraitBeaconDescription =>
      'Всегда активен, высокая доступность';

  @override
  String get nodedexTraitCollectionLabel => 'КОЛЛЕКЦИЯ ХАРАКТЕРИСТИК';

  @override
  String get nodedexTraitCourier => 'Курьер';

  @override
  String get nodedexTraitCourierDescription => 'Доставляет сообщения по сети';

  @override
  String get nodedexTraitDrifter => 'Дрейфер';

  @override
  String get nodedexTraitDrifterDescription =>
      'Нерегулярные появления, исчезает и появляется';

  @override
  String get nodedexTraitGhost => 'Призрак';

  @override
  String get nodedexTraitGhostDescription =>
      'Редко встречается, неуловимое присутствие';

  @override
  String nodedexTraitNodesPageTitle(String traitLabel) {
    return 'Ноды $traitLabel';
  }

  @override
  String get nodedexTraitRelay => 'Ретранслятор';

  @override
  String get nodedexTraitRelayDescription =>
      'Высокая пропускная способность, пересылает трафик';

  @override
  String get nodedexTraitSentinel => 'Часовой';

  @override
  String get nodedexTraitSentinelDescription =>
      'Фиксированное положение, долговечный страж';

  @override
  String get nodedexTraitUnknown => 'Новичок';

  @override
  String get nodedexTraitUnknownDescription => 'Недавно обнаружен';

  @override
  String get nodedexTraitWanderer => 'Странник';

  @override
  String get nodedexTraitWandererDescription => 'Замечен в разных местах';

  @override
  String get nodedexTrustDescriptionEstablished =>
      'Глубокая история по всем измерениям';

  @override
  String get nodedexTrustDescriptionFamiliar =>
      'Регулярное присутствие с некоторой историей';

  @override
  String get nodedexTrustDescriptionObserved =>
      'Встречался несколько раз в сети';

  @override
  String get nodedexTrustDescriptionTrusted =>
      'Частый, долгосрочный, коммуникативный';

  @override
  String get nodedexTrustDescriptionUnknown => 'Недостаточно данных для оценки';

  @override
  String get nodedexTrustLevelEstablished => 'Устоявшийся';

  @override
  String get nodedexTrustLevelFamiliar => 'Знакомый';

  @override
  String get nodedexTrustLevelObserved => 'Наблюдаемый';

  @override
  String get nodedexTrustLevelTrusted => 'Доверенный';

  @override
  String get nodedexTrustLevelUnknown => 'Неизвестный';

  @override
  String get nodedexUnknownRegion => 'Неизвестный регион';

  @override
  String get nodedexUptimeLabel => 'Время работы';

  @override
  String get nodedexViewProfile => 'Просмотреть профиль';

  @override
  String get nodedexWalletCouldNotAdd => 'Не удалось добавить в Apple Wallet';

  @override
  String get nodedexWalletCouldNotOpen => 'Не удалось открыть Apple Wallet';

  @override
  String get nodedexWalletCouldNotPublish =>
      'Не удалось опубликовать карточку sigil';

  @override
  String get nodesScreenConnectedDevice => 'Подключённое устройство';

  @override
  String get nodesScreenDisconnect => 'Отключить';

  @override
  String nodesScreenDistanceKilometers(String km) {
    return '$km км';
  }

  @override
  String nodesScreenDistanceMeters(String meters) {
    return '$meters м';
  }

  @override
  String get nodesScreenEmptyAll => 'Ноды пока не обнаружены';

  @override
  String get nodesScreenEmptyFiltered => 'Нет нод, соответствующих фильтру';

  @override
  String get nodesScreenFilterActive => 'Активные';

  @override
  String get nodesScreenFilterAll => 'Все';

  @override
  String get nodesScreenFilterFavorites => 'Избранные';

  @override
  String get nodesScreenFilterInactive => 'Неактивные';

  @override
  String get nodesScreenFilterMqtt => 'MQTT';

  @override
  String get nodesScreenFilterNew => 'Новые';

  @override
  String get nodesScreenFilterRf => 'RF';

  @override
  String get nodesScreenFilterWithPosition => 'С позицией';

  @override
  String get nodesScreenGps => 'GPS';

  @override
  String get nodesScreenHelpMenu => 'Справка';

  @override
  String nodesScreenHopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хопа',
      many: '$count хопов',
      few: '$count хопа',
      one: '1 хоп',
    );
    return '$_temp0';
  }

  @override
  String get nodesScreenHopDirect => 'Прямой';

  @override
  String get nodesScreenLogsLabel => 'Журналы:';

  @override
  String get nodesScreenNoGps => 'Нет GPS';

  @override
  String get nodesScreenScanQrCodeTooltip => 'Сканировать QR-код';

  @override
  String get nodesScreenSearchHint => 'Найти ноду';

  @override
  String get nodesScreenSectionActive => 'Активные';

  @override
  String get nodesScreenSectionAetherFlights => 'Рейсы Aether поблизости';

  @override
  String get nodesScreenSectionBatteryCritical => 'Критический (<20%)';

  @override
  String get nodesScreenSectionBatteryFull => 'Полный (80–100%)';

  @override
  String get nodesScreenSectionBatteryGood => 'Хороший (50–80%)';

  @override
  String get nodesScreenSectionBatteryLow => 'Низкий (20–50%)';

  @override
  String get nodesScreenSectionCharging => 'Зарядка';

  @override
  String get nodesScreenSectionDiscovering => 'Поиск';

  @override
  String get nodesScreenSectionFavorites => 'Избранные';

  @override
  String get nodesScreenSectionInactive => 'Неактивные';

  @override
  String get nodesScreenSectionSeenRecently => 'Недавно замеченные';

  @override
  String get nodesScreenSectionSignalMedium => 'Средний (от -10 до 0 dB)';

  @override
  String get nodesScreenSectionSignalStrong => 'Сильный (>0 dB)';

  @override
  String get nodesScreenSectionSignalWeak => 'Слабый (<-10 dB)';

  @override
  String get nodesScreenSectionUnknown => 'Неизвестные';

  @override
  String get nodesScreenSectionYourDevice => 'Ваше устройство';

  @override
  String get nodesScreenSettingsMenu => 'Настройки';

  @override
  String get nodesScreenShowAllButton => 'Показать все ноды';

  @override
  String get nodesScreenSortBattery => 'Аккумулятор';

  @override
  String get nodesScreenSortMenuBatteryLevel => 'Уровень заряда';

  @override
  String get nodesScreenSortMenuMostRecent => 'Последние';

  @override
  String get nodesScreenSortMenuNameAZ => 'Имя (А-Я)';

  @override
  String get nodesScreenSortMenuSignalStrength => 'Уровень сигнала';

  @override
  String get nodesScreenSortName => 'Имя';

  @override
  String get nodesScreenSortRecent => 'Последние';

  @override
  String get nodesScreenSortSignal => 'Сигнал';

  @override
  String get nodesScreenThisDevice => 'Это устройство';

  @override
  String nodesScreenTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ноды ($count)',
      many: 'Ноды ($count)',
      few: 'Ноды ($count)',
      one: 'Нода (1)',
    );
    return '$_temp0';
  }

  @override
  String get nodesScreenTransportMqtt => 'MQTT';

  @override
  String get nodesScreenTransportRf => 'RF';

  @override
  String get nodesScreenYouBadge => 'ВЫ';

  @override
  String get onboardingAutomationGeofence => 'Геозона базового лагеря';

  @override
  String get onboardingAutomationGeofenceDesc => 'Вход в обозначенную зону';

  @override
  String get onboardingAutomationLowBattery => 'Предупреждение о низком заряде';

  @override
  String get onboardingAutomationLowBatteryDesc =>
      'Заряд батареи опускается ниже 20%';

  @override
  String get onboardingAutomationSilentWatch => 'Молчание ноды';

  @override
  String get onboardingAutomationSilentWatchDesc =>
      'Нет связи в течение 30 мин';

  @override
  String get onboardingAutomationSosKeyword => 'Ключевое слово SOS';

  @override
  String get onboardingAutomationSosKeywordDesc => 'Сообщение содержит «SOS»';

  @override
  String get onboardingAutomationsAdvisor =>
      'Настройте правила один раз — я буду следить за всем остальным. Низкий заряд? Сообщу. Нода замолчал? Предупрежу. Получен SOS? Активирую ваш вебхук.';

  @override
  String get onboardingAutomationsDescription =>
      'Запускайте действия на основе событий сети.\nОповещения о батарее, геозоны, ключевые слова и многое другое.';

  @override
  String get onboardingAutomationsTitle => 'Интеллектуальная автоматизация';

  @override
  String get onboardingCheckingRadio => 'Проверка конфигурации радиоустройства';

  @override
  String get onboardingConnectAdvisor =>
      'После подключения работа полностью автономна. Сеть ждёт.';

  @override
  String get onboardingConnectDescription =>
      'Подключите устройство Meshtastic для начала работы.\nBluetooth или USB — на ваш выбор.';

  @override
  String get onboardingConnectDeviceButton => 'Подключить устройство';

  @override
  String get onboardingConnectTitle => 'Готово к подключению';

  @override
  String get onboardingContinueButton => 'Продолжить';

  @override
  String get onboardingDashboardAdvisor =>
      'Виджеты, карты, статистика — расположите их так, как удобно вам. Ваша сеть, ваш вид, ваш контроль.';

  @override
  String get onboardingDashboardDescription =>
      'Настраиваемая панель с телеметрией в реальном времени.\nОтслеживайте ноды, следите за каналами, визуализируйте сеть.';

  @override
  String get onboardingDashboardTitle => 'Ваш командный центр';

  @override
  String get onboardingDeviceHeltec => 'Heltec V3';

  @override
  String get onboardingDeviceHeltecCategory => 'Универсальный';

  @override
  String get onboardingDeviceHeltecDescription =>
      'Многофункциональная нода со встроенным дисплеем';

  @override
  String get onboardingDeviceLilygo => 'LilyGo T-Beam';

  @override
  String get onboardingDeviceLilygoCategory => 'Дальнобойный';

  @override
  String get onboardingDeviceLilygoDescription =>
      'Максимальный радиус с внешней антенной';

  @override
  String get onboardingDevicePopularBadge => 'ПОПУЛЯРНЫЙ';

  @override
  String get onboardingDeviceRak => 'RAK WisMesh';

  @override
  String get onboardingDeviceRakCategory => 'Профессиональный';

  @override
  String get onboardingDeviceRakDescription => 'Промышленная надёжность';

  @override
  String get onboardingDeviceSensecap => 'SenseCAP T1000-E';

  @override
  String get onboardingDeviceSensecapCategory => 'Трекер';

  @override
  String get onboardingDeviceSensecapDescription =>
      'Компактный GPS-трекер с длительным временем работы от батареи';

  @override
  String get onboardingEmotionConfiguratorTitle => 'Настройка эмоций';

  @override
  String get onboardingEmotionResetDefaults =>
      'Сбросить до значений по умолчанию';

  @override
  String get onboardingEmotionSettingsTooltip => 'Настройки';

  @override
  String get onboardingHardwareAdvisor =>
      'Возьмите SenseCAP T1000-E для отслеживания, Heltec V3 для дальности или RAK WisMesh для надёжности. Я работаю с любым из них.';

  @override
  String get onboardingHardwareDescription =>
      'Совместимо со всеми устройствами Meshtastic.\nОт компактных трекеров до дальнобойных станций.';

  @override
  String get onboardingHardwareTitle => 'Совместимое оборудование';

  @override
  String get onboardingNodedexAdvisor =>
      'Каждая нода получает уникальный Sigil, уровень редкости и патину, которая углубляется с каждой встречей. Соберите их все — ваш NodeDex — это ваша история в сети.';

  @override
  String get onboardingNodedexBaseCamp => 'Нода базового лагеря';

  @override
  String get onboardingNodedexDescription =>
      'Каждый встреченная нода становится коллекционной карточкой.\nСоздавайте свой полевой журнал по всей сети.';

  @override
  String get onboardingNodedexEpic => 'ЭПИЧЕСКИЙ';

  @override
  String get onboardingNodedexLegendary => 'ЛЕГЕНДАРНЫЙ';

  @override
  String get onboardingNodedexRare => 'РЕДКИЙ';

  @override
  String get onboardingNodedexStandard => 'СТАНДАРТНЫЙ';

  @override
  String get onboardingNodedexSummitRelay => 'Ретранслятор на вершине';

  @override
  String get onboardingNodedexTitle => 'NodeDex — Альбом коллекционера';

  @override
  String get onboardingNodedexTrailMarker => 'Маркер маршрута';

  @override
  String get onboardingNodedexValleyScout => 'Разведчик долины';

  @override
  String get onboardingOffGridAdvisor =>
      'Каждое сообщение прыгает по сети, пока не достигнет адресата. Дальность — в километрах, а не в делениях сигнала.';

  @override
  String get onboardingOffGridDescription =>
      'Без сотовых вышек. Без интернета.\nНастоящая одноранговая радиосвязь.';

  @override
  String get onboardingOffGridTitle => 'Автономность — по умолчанию';

  @override
  String get onboardingPrivacyAdvisor =>
      'Всё хранится локально, если вы явно не включили облачную синхронизацию. Без слежки, без аналитики, без компромиссов.';

  @override
  String get onboardingPrivacyDescription =>
      'Без обязательной регистрации. Без облака по умолчанию.\nВаши данные остаются на вашем устройстве.';

  @override
  String get onboardingPrivacyTitle => 'Приватность прежде всего';

  @override
  String get onboardingSettingUpDevice => 'Настройка устройства...';

  @override
  String get onboardingSignalDirect => 'Прямой';

  @override
  String onboardingSignalHopCount(int count) {
    return '$count хоп';
  }

  @override
  String get onboardingSignalLocationShared => 'Местоположение передано';

  @override
  String get onboardingSignalPhoto => 'Фото';

  @override
  String onboardingSignalTtlRemaining(int minutes) {
    return 'Осталось $minutes мин.';
  }

  @override
  String get onboardingSignalsAdvisor =>
      'Сигналы — это то, что отличает нас. Транслируйте всем в зоне доступности, наблюдайте, как они распространяются по сети, и удаляйте их по вашему желанию.';

  @override
  String get onboardingSignalsDescription =>
      'Эфемерные трансляции по всей сети.\nПоделитесь присутствием, фото и местоположением — и пусть они исчезнут.';

  @override
  String get onboardingSignalsTitle => 'Сигналы';

  @override
  String get onboardingSkipButton => 'Пропустить';

  @override
  String get onboardingWelcomeAdvisor =>
      'Я Ico, ваш гид. Позвольте показать вам коммуникационную платформу, которая работает там, где всё остальное не работает.';

  @override
  String get onboardingWelcomeDescription =>
      'Самое продвинутое приложение для Meshtastic.\nСоздано для профессионалов. Разработано для всех.';

  @override
  String get onboardingWelcomeTitle => 'Добро пожаловать в Socialmesh';

  @override
  String get onboardingWidgetBattery => 'Батарея';

  @override
  String get onboardingWidgetDashboard => 'Панель';

  @override
  String get onboardingWidgetLiveBadge => 'LIVE';

  @override
  String get onboardingWidgetNodesOnline => 'Нод онлайн';

  @override
  String get onboardingWidgetSnrDb => 'SNR dB';

  @override
  String get paxCounterAboutSubtitle =>
      'PAX Counter пассивно прослушивает WiFi- и Bluetooth-зондирующие запросы от ближайших устройств. MAC-адреса и персональные данные не сохраняются.';

  @override
  String get paxCounterAboutTitle => 'О PAX Counter';

  @override
  String get paxCounterCardSubtitle =>
      'Подсчёт ближайших WiFi и Bluetooth устройств';

  @override
  String get paxCounterCardTitle => 'PAX Counter';

  @override
  String get paxCounterEnable => 'Включить PAX Counter';

  @override
  String get paxCounterEnableSubtitle =>
      'Считать ближайшие устройства и передавать данные в сеть';

  @override
  String paxCounterIntervalMinutes(int minutes) {
    return '$minutes мин.';
  }

  @override
  String get paxCounterMaxLabel => '60 мин.';

  @override
  String get paxCounterMinLabel => '1 мин.';

  @override
  String get paxCounterSave => 'Сохранить';

  @override
  String paxCounterSaveError(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get paxCounterSaved => 'Конфигурация PAX Counter сохранена';

  @override
  String get paxCounterTitle => 'PAX Counter';

  @override
  String get paxCounterUpdateInterval => 'Интервал обновления';

  @override
  String get presenceAllNodes => 'Все ноды';

  @override
  String get presenceBackNearby => 'Снова рядом';

  @override
  String get presenceBroadcastInfo =>
      'Ваши намерения и статус передаются вместе с вашими сигналами.';

  @override
  String get presenceClear => 'Очистить';

  @override
  String get presenceEmptyTagline1 =>
      'Ноды ещё не обнаружены.\nПодключитесь к сетевому устройству, чтобы видеть присутствие.';

  @override
  String get presenceEmptyTagline2 =>
      'Присутствие показывает, кто активен в вашей сети.\nНоды появляются по мере трансляции.';

  @override
  String get presenceEmptyTagline3 =>
      'Наблюдайте за появлением и исчезновением нод в реальном времени.\nСостояния: активный, затухающий, офлайн.';

  @override
  String get presenceEmptyTagline4 =>
      'Знакомые лица выделены.\nСтройте сообщество в вашей сети постепенно.';

  @override
  String get presenceEmptyTitleKeyword => 'присутствия';

  @override
  String get presenceEmptyTitlePrefix => 'Нет ';

  @override
  String get presenceEmptyTitleSuffix => ' не обнаружено';

  @override
  String get presenceFamiliarBadge => 'Знакомый';

  @override
  String get presenceFilterActive => 'Активные';

  @override
  String get presenceFilterAll => 'Все';

  @override
  String get presenceFilterFading => 'Видели недавно';

  @override
  String get presenceFilterFamiliar => 'Знакомые';

  @override
  String get presenceFilterInactive => 'Неактивные';

  @override
  String get presenceFilterUnknown => 'Неизвестные';

  @override
  String get presenceIntentLabel => 'Намерение';

  @override
  String get presenceIntentUpdated => 'Намерение присутствия обновлено';

  @override
  String get presenceLegendMedium => '2–10 мин.';

  @override
  String get presenceLegendShort => '< 2 мин.';

  @override
  String get presenceMyPresence => 'Моё присутствие';

  @override
  String get presenceNoMatchFilter => 'Ноды не соответствуют фильтру';

  @override
  String get presenceNoMatchSearch => 'Ноды не соответствуют запросу';

  @override
  String presenceNodeCount(int count, String noun) {
    return '$count $noun';
  }

  @override
  String get presenceNodePlural => 'нод';

  @override
  String get presenceNodeSingular => 'нода';

  @override
  String get presenceQuietMesh =>
      'Сеть сейчас тиха — ноды появятся по мере выхода в онлайн.';

  @override
  String get presenceRecentActivity => 'Последняя активность';

  @override
  String get presenceSave => 'Сохранить';

  @override
  String get presenceSearchHint => 'Поиск нод';

  @override
  String get presenceSectionActive => 'Активные';

  @override
  String get presenceSectionInactive => 'Неактивные';

  @override
  String get presenceSectionSeenRecently => 'Видели недавно';

  @override
  String get presenceSectionUnknown => 'Неизвестные';

  @override
  String get presenceSelectIntent => 'Выбрать намерение';

  @override
  String get presenceSetStatus => 'Установить статус';

  @override
  String get presenceShowAll => 'Показать все ноды';

  @override
  String get presenceStatusHint => 'Чем вы занимаетесь?';

  @override
  String get presenceStatusLabel => 'Статус';

  @override
  String get presenceStatusNotSet => 'Не задан';

  @override
  String get presenceStatusUpdated => 'Статус обновлён';

  @override
  String get presenceTitle => 'Присутствие';

  @override
  String get presenceTryDifferent => 'Попробуйте другой запрос или фильтр';

  @override
  String get presenceWillAppear => 'Ноды появятся здесь по мере обнаружения';

  @override
  String get productDetailAnonymous => 'Аноним';

  @override
  String get productDetailBattery => 'Аккумулятор';

  @override
  String get productDetailBeFirstReviewer =>
      'Станьте первым, кто оставит отзыв на этот товар!';

  @override
  String get productDetailBluetooth => 'Bluetooth';

  @override
  String get productDetailBuyNow => 'Купить сейчас';

  @override
  String productDetailBySeller(String seller) {
    return 'от $seller';
  }

  @override
  String get productDetailCancel => 'Отмена';

  @override
  String get productDetailChipset => 'Чипсет';

  @override
  String get productDetailContactSeller => 'Связаться с продавцом';

  @override
  String get productDetailContactToPurchase =>
      'Свяжитесь с продавцом для приобретения этого товара.';

  @override
  String productDetailDaysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String get productDetailDescription => 'Описание';

  @override
  String get productDetailDimensions => 'Размеры';

  @override
  String productDetailDiscountBadge(int percent) {
    return '-$percent% СКИДКА';
  }

  @override
  String get productDetailDisplay => 'Дисплей';

  @override
  String get productDetailEdit => 'Изменить';

  @override
  String get productDetailErrorLoading => 'Ошибка загрузки товара';

  @override
  String productDetailEstimatedDelivery(int days) {
    return 'Примерно $days дней';
  }

  @override
  String get productDetailFeatures => 'Характеристики';

  @override
  String get productDetailFirmware => 'Прошивка';

  @override
  String get productDetailFreeShipping => 'Бесплатная доставка';

  @override
  String get productDetailFrequencyBands => 'Частотные диапазоны';

  @override
  String get productDetailGoBack => 'Назад';

  @override
  String get productDetailGps => 'GPS';

  @override
  String get productDetailHardwareVersion => 'Версия аппаратного обеспечения';

  @override
  String productDetailImageCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String productDetailInStockCount(int quantity) {
    return 'В наличии ($quantity шт.)';
  }

  @override
  String get productDetailIncludedAccessories => 'Комплектующие';

  @override
  String get productDetailLoraChip => 'Чип LoRa';

  @override
  String get productDetailMeshtasticCompatible => 'Совместимо с Meshtastic';

  @override
  String productDetailMonthsAgo(int count) {
    return '$count мес. назад';
  }

  @override
  String get productDetailNoReviews => 'Отзывов пока нет';

  @override
  String get productDetailNotFound => 'Товар не найден';

  @override
  String get productDetailOutOfStock => 'Нет в наличии';

  @override
  String get productDetailOutOfStockButton => 'Нет в наличии';

  @override
  String get productDetailPurchaseDisclaimer =>
      'Покупки завершаются в официальном магазине продавца';

  @override
  String get productDetailPurchaseTitle => 'Покупка';

  @override
  String get productDetailReadMore => 'Подробнее';

  @override
  String get productDetailRetry => 'Повторить';

  @override
  String productDetailReviewCount(int count) {
    return '($count отзывов)';
  }

  @override
  String get productDetailReviewHint =>
      'Поделитесь впечатлениями об этом товаре...';

  @override
  String productDetailReviewPrivacyNotice(String userName) {
    return 'Ваш отзыв будет опубликован под именем «$userName». Отзывы проверяются модераторами перед публикацией на странице товара.';
  }

  @override
  String get productDetailReviewSubmitted =>
      'Отзыв отправлен на модерацию. Спасибо!';

  @override
  String get productDetailReviewTitleLabel => 'Заголовок (необязательно)';

  @override
  String get productDetailReviewValidation =>
      'Пожалуйста, напишите описание отзыва';

  @override
  String get productDetailReviewVerified => 'Подтверждённый';

  @override
  String get productDetailReviews => 'Отзывы';

  @override
  String productDetailSelectedPrice(String price) {
    return 'Выбрано: \$$price';
  }

  @override
  String get productDetailSellerResponse => 'Ответ продавца';

  @override
  String get productDetailShipping => 'Доставка';

  @override
  String productDetailShippingCost(String cost) {
    return 'Доставка: \$$cost';
  }

  @override
  String productDetailShipsTo(String countries) {
    return 'Доставка в: $countries';
  }

  @override
  String get productDetailShowLess => 'Свернуть';

  @override
  String get productDetailSignInFavorites =>
      'Войдите, чтобы сохранить избранное';

  @override
  String productDetailSoldCount(int count) {
    return 'Продано: $count';
  }

  @override
  String get productDetailSubmitReview => 'Отправить отзыв';

  @override
  String get productDetailTechSpecs => 'Технические характеристики';

  @override
  String get productDetailTitle => 'Товар';

  @override
  String get productDetailToday => 'Сегодня';

  @override
  String get productDetailTotal => 'Итого';

  @override
  String get productDetailUnableToLoadPage => 'Не удалось загрузить страницу';

  @override
  String get productDetailUnableToLoadReviews => 'Не удалось загрузить отзывы';

  @override
  String get productDetailVendorVerified => 'Продавец проверен';

  @override
  String productDetailVerifiedOn(String date) {
    return 'Проверено $date';
  }

  @override
  String get productDetailWebviewOffline =>
      'Для отображения этого контента требуется подключение к интернету. Проверьте подключение и повторите попытку.';

  @override
  String productDetailWeeksAgo(int count) {
    return '$count нед. назад';
  }

  @override
  String get productDetailWeight => 'Вес';

  @override
  String get productDetailWifi => 'WiFi';

  @override
  String get productDetailWriteReview => 'Написать отзыв';

  @override
  String get productDetailWriteReviewTitle => 'Написать отзыв';

  @override
  String productDetailYearsAgo(int count) {
    return '$count лет назад';
  }

  @override
  String get productDetailYesterday => 'Вчера';

  @override
  String get productDetailYourRating => 'Ваша оценка';

  @override
  String get productDetailYourReview => 'Ваш отзыв *';

  @override
  String get profileBasicInfo => 'Основная информация';

  @override
  String get profileBioHint => 'Расскажите о себе';

  @override
  String get profileBioLabel => 'Биография';

  @override
  String get profileCallsignHint => 'Позывной радиолюбителя или идентификатор';

  @override
  String get profileCallsignInappropriate =>
      'Позывной не может содержать недопустимый контент';

  @override
  String get profileCallsignLabel => 'Позывной';

  @override
  String get profileCallsignMax => 'Максимум 10 символов';

  @override
  String get profileCloudBackup => 'Облачное резервное копирование';

  @override
  String get profileCloudStartingUp =>
      'Облачные сервисы запускаются — попробуйте снова через некоторое время';

  @override
  String get profileContinueApple => 'Продолжить с Apple';

  @override
  String get profileContinueGitHub => 'Продолжить с GitHub';

  @override
  String get profileContinueGoogle => 'Продолжить с Google';

  @override
  String profileCopiedToClipboard(String label) {
    return '$label скопировано в буфер обмена';
  }

  @override
  String get profileCreate => 'Создать профиль';

  @override
  String get profileDeleteAccount => 'Удалить аккаунт';

  @override
  String get profileDeleteConfirmMsg =>
      'Это действие навсегда удалит ваш аккаунт и все связанные данные. Действие нельзя отменить.';

  @override
  String get profileDeleteRequiresInternet =>
      'Для удаления аккаунта требуется подключение к интернету.';

  @override
  String get profileDeletingAccount => 'Удаление аккаунта...';

  @override
  String get profileDeletionFailed =>
      'Удаление не удалось. Пожалуйста, попробуйте снова или обратитесь в поддержку.';

  @override
  String get profileDetailsSection => 'Подробности';

  @override
  String get profileDiscordHint => 'username#0000';

  @override
  String get profileDiscordLabel => 'Discord';

  @override
  String get profileDisplayNameHint => 'Как вас будут знать';

  @override
  String get profileDisplayNameLabel => 'Отображаемое имя';

  @override
  String get profileEditButton => 'Редактировать профиль';

  @override
  String get profileEditSheetTitle => 'Редактировать профиль';

  @override
  String get profileEditTooltip => 'Редактировать профиль';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String profileErrorWithMessage(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get profileGitHubHint => 'username';

  @override
  String get profileGitHubLabel => 'GitHub';

  @override
  String get profileGitHubLinked => 'Аккаунт GitHub успешно привязан!';

  @override
  String get profileHelpTooltip => 'Справка';

  @override
  String get profileLinkFailed => 'Не удалось связать аккаунты';

  @override
  String get profileLinkGitHub => 'Привязать аккаунт GitHub';

  @override
  String profileLinkGitHubMsg(String email, String provider) {
    return 'Аккаунт с адресом $email уже существует и использует $provider.\n\nВойти через $provider, чтобы привязать аккаунт GitHub?';
  }

  @override
  String get profileLinkedAccounts => 'Связанные аккаунты';

  @override
  String get profileLinksSection => 'Ссылки';

  @override
  String get profileMastodonHint => '@user@instance.social';

  @override
  String get profileMastodonLabel => 'Mastodon';

  @override
  String get profileMemberSince => 'Участник с';

  @override
  String get profileNoInternet => 'Нет подключения к интернету';

  @override
  String get profileNotBackedUp => 'Резервная копия не создана';

  @override
  String get profileSetup => 'Настройте свой профиль';

  @override
  String get profileSetupDesc =>
      'Добавьте имя, фото и биографию, чтобы персонализировать своё присутствие в сети.';

  @override
  String get profileSignInDesc =>
      'Войдите, чтобы создать резервную копию профиля в облаке и синхронизировать данные на всех устройствах.';

  @override
  String get profileSignInFailed => 'Ошибка входа';

  @override
  String get profileSignInRequiresInternet =>
      'Для входа требуется подключение к интернету.';

  @override
  String get profileSignInServicesUnavailable =>
      'Не удаётся подключиться к службе входа. Проверьте подключение к интернету и повторите попытку.';

  @override
  String profileSignInWithProvider(String provider) {
    return 'Войти через $provider';
  }

  @override
  String get profileSignOut => 'Выйти';

  @override
  String get profileSignOutConfirm => 'Вы уверены, что хотите выйти?';

  @override
  String get profileSignOutRequiresInternet =>
      'Для выхода требуется подключение к интернету.';

  @override
  String get profileSignedInApple => 'Выполнен вход через Apple';

  @override
  String get profileSignedInGitHub => 'Выполнен вход через GitHub';

  @override
  String get profileSignedInGoogle => 'Выполнен вход через Google';

  @override
  String get profileSigningIn => 'Выполняется вход...';

  @override
  String get profileSocialSection => 'Социальные сети';

  @override
  String get profileSyncError =>
      'Ошибка синхронизации • Нажмите, чтобы повторить';

  @override
  String get profileSyncFailed => 'Синхронизация не удалась';

  @override
  String get profileSyncPermissionDenied => 'Доступ к синхронизации запрещён';

  @override
  String get profileSyncRequiresInternet =>
      'Для синхронизации требуется подключение к интернету.';

  @override
  String get profileSyncTempUnavailable => 'Синхронизация временно недоступна';

  @override
  String get profileSyncTempUnavailable2 =>
      'Облачная синхронизация временно недоступна';

  @override
  String get profileSyncTimedOut =>
      'Время синхронизации истекло — попробуйте снова';

  @override
  String profileSynced(String email) {
    return 'Синхронизировано • $email';
  }

  @override
  String get profileSynced2 => 'Профиль синхронизирован!';

  @override
  String get profileSyncing => 'Синхронизация...';

  @override
  String get profileTelegramHint => 'username';

  @override
  String get profileTelegramLabel => 'Telegram';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileTwitterHint => 'username';

  @override
  String get profileTwitterLabel => 'Twitter / X';

  @override
  String get profileUidLabel => 'UID';

  @override
  String get profileUrlInvalid => 'Пожалуйста, введите корректный URL';

  @override
  String get profileUrlMustStartHttp =>
      'URL должен начинаться с http:// или https://';

  @override
  String get profileWebsiteHint => 'https://example.com';

  @override
  String get profileWebsiteLabel => 'Веб-сайт';

  @override
  String get qrScannerAddNodeConfirm => 'Добавить ноду';

  @override
  String qrScannerAddNodePrompt(String name) {
    return 'Добавить «$name» в отслеживаемые ноды?';
  }

  @override
  String get qrScannerAddNodeTitle => 'Добавить ноду';

  @override
  String get qrScannerCancel => 'Отмена';

  @override
  String get qrScannerCancelAdd => 'Отмена';

  @override
  String qrScannerChannelAlreadyExists(String name) {
    return 'У вас уже есть этот канал под названием «$name»';
  }

  @override
  String get qrScannerChannelCancel => 'Отмена';

  @override
  String get qrScannerChannelEditFirst => 'Сначала изменить';

  @override
  String get qrScannerChannelImport => 'Импортировать';

  @override
  String qrScannerChannelImported(String name) {
    return 'Канал «$name» импортирован';
  }

  @override
  String get qrScannerChannelInfoEncryption => 'Шифрование';

  @override
  String get qrScannerChannelInfoName => 'Название';

  @override
  String get qrScannerChannelSyncNotice =>
      'Канал будет синхронизирован с подключённым устройством.';

  @override
  String get qrScannerConnectDeviceToImport =>
      'Подключите устройство для импорта этого канала';

  @override
  String qrScannerFailedToProcess(String error) {
    return 'Не удалось обработать QR-код: $error';
  }

  @override
  String get qrScannerImportChannelTitle => 'Импортировать канал';

  @override
  String qrScannerImportFailed(String error) {
    return 'Импорт не выполнен: $error';
  }

  @override
  String get qrScannerImportedChannelName => 'Импортировано';

  @override
  String get qrScannerMaxChannels =>
      'Максимум 8 каналов — сначала удалите один';

  @override
  String qrScannerNodeAddedToFavorites(String name) {
    return 'Нода «$name» добавлена в избранное';
  }

  @override
  String get qrScannerNodeAlreadyExists => 'Нода уже существует';

  @override
  String qrScannerNodeAlreadyInList(String name) {
    return 'Эта нода уже есть в вашем списке под именем «$name».';
  }

  @override
  String get qrScannerNodeInfoId => 'ID ноды';

  @override
  String get qrScannerNodeInfoName => 'Название';

  @override
  String get qrScannerNodeInfoShort => 'Краткое';

  @override
  String get qrScannerPrompt => 'Наведите камеру на QR-код';

  @override
  String get qrScannerSupportsHint =>
      'Поддерживаются ноды, каналы, автоматизации и многое другое';

  @override
  String get qrScannerTitle => 'Сканировать QR-код';

  @override
  String get qrScannerUpdate => 'Обновить';

  @override
  String qrScannerUpdateNamePrompt(String name) {
    return 'Обновить имя на «$name» и добавить в избранное?';
  }

  @override
  String get reachabilityAboutTitle => 'О достижимости';

  @override
  String get reachabilityAboutTooltip => 'О достижимости';

  @override
  String get reachabilityBetaBadge => 'БЕТА';

  @override
  String get reachabilityDisclaimerBanner =>
      'Только оценки вероятности. Доставка в сети никогда не гарантирована.';

  @override
  String get reachabilityEmptyDescription =>
      'Ноды будут появляться по мере их обнаружения\nв сети.';

  @override
  String get reachabilityEmptyTitle => 'Ноды ещё не обнаружены';

  @override
  String get reachabilityGotIt => 'Понятно';

  @override
  String get reachabilityHowCalculatedContent =>
      'Оценка вероятности учитывает несколько факторов:\n• Актуальность: как давно мы получали сигнал от ноды\n• Глубина пути: наблюдаемое число прыжков\n• Качество сигнала: RSSI и SNR при наличии данных\n• Характер наблюдений: прямые или ретранслированные пакеты\n• История ACK: успешность подтверждений личных сообщений';

  @override
  String get reachabilityHowCalculatedTitle => 'Как рассчитывается?';

  @override
  String get reachabilityLevelHigh => 'Высокая';

  @override
  String get reachabilityLevelLow => 'Низкая';

  @override
  String get reachabilityLevelMedium => 'Средняя';

  @override
  String get reachabilityLevelsMeanContent =>
      '• Высокая: сильные недавние показатели, но без гарантий\n• Средняя: умеренная уверенность на основе имеющихся данных\n• Низкая: слабые или устаревшие показатели, доставка маловероятна';

  @override
  String get reachabilityLevelsMeanTitle => 'Что означают уровни';

  @override
  String get reachabilityLimitationsContent =>
      '• Meshtastic не имеет истинных таблиц маршрутизации\n• Сквозных подтверждений не существует\n• Пересылка осуществляется по возможности\n• Топология сети постоянно меняется\n• Все оценки основаны только на пассивном наблюдении';

  @override
  String get reachabilityLimitationsTitle => 'Важные ограничения';

  @override
  String reachabilityScorePercent(String percentage) {
    return '$percentage%';
  }

  @override
  String get reachabilityScoringModelContent =>
      'Модель оценки вероятности достижения ноды (v1) — БЕТА\n\nЭвристическая модель, определяющая вероятность доставки до ноды на основе наблюдаемых RF-метрик и истории пакетов. Оценка отражает вероятность, а не гарантию достижимости. Meshtastic пересылает пакеты по возможности без маршрутизации. Высокая оценка не гарантирует доставку.';

  @override
  String get reachabilityScoringModelTitle => 'Модель оценки';

  @override
  String get reachabilityScreenTitle => 'Достижимость';

  @override
  String get reachabilitySearchHint => 'Поиск нод';

  @override
  String get reachabilityWhatIsThisContent =>
      'На этом экране отображается вероятностная оценка того, насколько вероятно, что ваши сообщения дойдут до каждой ноды. Это НЕ гарантия доставки.';

  @override
  String get reachabilityWhatIsThisTitle => 'Что это такое?';

  @override
  String get regionSelectionApplyDialogConfirm => 'Продолжить';

  @override
  String get regionSelectionApplyDialogMessageChange =>
      'Изменение региона приведёт к перезагрузке устройства. Это может занять до 30 секунд.\n\nВо время перезапуска устройства соединение будет кратковременно прервано.';

  @override
  String get regionSelectionApplyDialogMessageInitial =>
      'Устройство перезагрузится для применения настроек региона. Это может занять до 30 секунд.\n\nПриложение автоматически переподключится, когда будет готово.';

  @override
  String get regionSelectionApplyDialogTitle => 'Применить регион';

  @override
  String get regionSelectionApplying => 'Применение...';

  @override
  String get regionSelectionBannerSubtitle =>
      'Выберите правильную частоту для вашего местоположения в соответствии с местными требованиями.';

  @override
  String get regionSelectionBannerTitle => 'Важно: выберите ваш регион';

  @override
  String get regionSelectionBluetoothSettings => 'Настройки Bluetooth';

  @override
  String get regionSelectionContinue => 'Продолжить';

  @override
  String get regionSelectionCurrentBadge => 'ТЕКУЩИЙ';

  @override
  String get regionSelectionDeviceDisconnected =>
      'Устройство отключено. Пожалуйста, переподключитесь и повторите попытку.';

  @override
  String get regionSelectionOpenBluetoothSettingsError =>
      'Не удалось открыть настройки Bluetooth. Откройте Настройки > Bluetooth вручную.';

  @override
  String get regionSelectionPairingHintMessage =>
      'Сопряжение Bluetooth удалено. Удалите «Meshtastic_XXXX» в Настройках > Bluetooth и подключитесь повторно.';

  @override
  String get regionSelectionPairingInvalidation =>
      'Телефон удалил сохранённые данные сопряжения для этого устройства.\nПерейдите в Настройки > Bluetooth, удалите устройство Meshtastic и повторите попытку.';

  @override
  String get regionSelectionReconnectTimeout =>
      'Время подключения истекло. Пожалуйста, повторите попытку.';

  @override
  String get regionSelectionRegionAnz => 'Австралия/НЗ';

  @override
  String get regionSelectionRegionAnzDesc => 'Австралия и Новая Зеландия';

  @override
  String get regionSelectionRegionAnzFreq => '915 MHz';

  @override
  String get regionSelectionRegionCn => 'Китай';

  @override
  String get regionSelectionRegionCnDesc => 'Китай';

  @override
  String get regionSelectionRegionCnFreq => '470 MHz';

  @override
  String get regionSelectionRegionEu433 => 'Европа 433';

  @override
  String get regionSelectionRegionEu433Desc => 'Альтернативная частота ЕС';

  @override
  String get regionSelectionRegionEu433Freq => '433 MHz';

  @override
  String get regionSelectionRegionEu868 => 'Европа 868';

  @override
  String get regionSelectionRegionEu868Desc =>
      'ЕС, Великобритания и большая часть Европы';

  @override
  String get regionSelectionRegionEu868Freq => '868 MHz';

  @override
  String get regionSelectionRegionIn => 'Индия';

  @override
  String get regionSelectionRegionInDesc => 'Индия';

  @override
  String get regionSelectionRegionInFreq => '865 MHz';

  @override
  String get regionSelectionRegionJp => 'Япония';

  @override
  String get regionSelectionRegionJpDesc => 'Япония';

  @override
  String get regionSelectionRegionJpFreq => '920 MHz';

  @override
  String get regionSelectionRegionKr => 'Корея';

  @override
  String get regionSelectionRegionKrDesc => 'Южная Корея';

  @override
  String get regionSelectionRegionKrFreq => '920 MHz';

  @override
  String get regionSelectionRegionLora24 => '2.4 GHz';

  @override
  String get regionSelectionRegionLora24Desc => 'Всемирный диапазон 2.4 GHz';

  @override
  String get regionSelectionRegionLora24Freq => '2.4 GHz';

  @override
  String get regionSelectionRegionMy433 => 'Малайзия 433';

  @override
  String get regionSelectionRegionMy433Desc => 'Малайзия';

  @override
  String get regionSelectionRegionMy433Freq => '433 MHz';

  @override
  String get regionSelectionRegionMy919 => 'Малайзия 919';

  @override
  String get regionSelectionRegionMy919Desc => 'Малайзия';

  @override
  String get regionSelectionRegionMy919Freq => '919 MHz';

  @override
  String get regionSelectionRegionNz865 => 'Новая Зеландия 865';

  @override
  String get regionSelectionRegionNz865Desc =>
      'Альтернативная частота Новой Зеландии';

  @override
  String get regionSelectionRegionNz865Freq => '865 MHz';

  @override
  String get regionSelectionRegionRu => 'Россия';

  @override
  String get regionSelectionRegionRuDesc => 'Россия';

  @override
  String get regionSelectionRegionRuFreq => '868 MHz';

  @override
  String get regionSelectionRegionSg923 => 'Сингапур';

  @override
  String get regionSelectionRegionSg923Desc => 'Сингапур';

  @override
  String get regionSelectionRegionSg923Freq => '923 MHz';

  @override
  String get regionSelectionRegionTh => 'Таиланд';

  @override
  String get regionSelectionRegionThDesc => 'Таиланд';

  @override
  String get regionSelectionRegionThFreq => '920 MHz';

  @override
  String get regionSelectionRegionTw => 'Тайвань';

  @override
  String get regionSelectionRegionTwDesc => 'Тайвань';

  @override
  String get regionSelectionRegionTwFreq => '923 MHz';

  @override
  String get regionSelectionRegionUa433 => 'Украина 433';

  @override
  String get regionSelectionRegionUa433Desc => 'Украина';

  @override
  String get regionSelectionRegionUa433Freq => '433 MHz';

  @override
  String get regionSelectionRegionUa868 => 'Украина 868';

  @override
  String get regionSelectionRegionUa868Desc => 'Украина';

  @override
  String get regionSelectionRegionUa868Freq => '868 MHz';

  @override
  String get regionSelectionRegionUs => 'США';

  @override
  String get regionSelectionRegionUsDesc => 'США, Канада, Мексика';

  @override
  String get regionSelectionRegionUsFreq => '915 MHz';

  @override
  String get regionSelectionSave => 'Сохранить';

  @override
  String get regionSelectionSearchHint => 'Поиск регионов...';

  @override
  String regionSelectionSetRegionError(String error) {
    return 'Не удалось установить регион: $error';
  }

  @override
  String get regionSelectionTitleChange => 'Изменить регион';

  @override
  String get regionSelectionTitleInitial => 'Выберите ваш регион';

  @override
  String get regionSelectionViewScanner => 'Открыть сканер';

  @override
  String get reviewModerationAllCaughtUp => 'Все проверено!';

  @override
  String get reviewModerationAllReviews => 'Все отзывы';

  @override
  String get reviewModerationAnonymous => 'Аноним';

  @override
  String get reviewModerationApprove => 'Одобрить';

  @override
  String get reviewModerationApproved => 'Отзыв одобрен';

  @override
  String get reviewModerationCancel => 'Отмена';

  @override
  String get reviewModerationDelete => 'Удалить';

  @override
  String get reviewModerationDeleteMessage =>
      'Вы уверены, что хотите безвозвратно удалить этот отзыв?';

  @override
  String get reviewModerationDeleteTitle => 'Удалить отзыв';

  @override
  String get reviewModerationDeleted => 'Отзыв удалён';

  @override
  String get reviewModerationErrorLoading => 'Ошибка загрузки отзывов';

  @override
  String get reviewModerationLegacy => 'Устаревший (без статуса)';

  @override
  String get reviewModerationNoDatabase => 'Отзывов в базе данных нет';

  @override
  String get reviewModerationNoPending => 'Нет отзывов, ожидающих проверки';

  @override
  String get reviewModerationNoReviews => 'Отзывов пока нет';

  @override
  String get reviewModerationPending => 'На проверке';

  @override
  String get reviewModerationReject => 'Отклонить';

  @override
  String get reviewModerationRejectReasonHint =>
      'Например: неприемлемый контент, спам и т.д.';

  @override
  String get reviewModerationRejectReasonLabel => 'Причина отклонения';

  @override
  String get reviewModerationRejectTitle => 'Отклонить отзыв';

  @override
  String get reviewModerationRejected => 'Отзыв отклонён';

  @override
  String get reviewModerationTitle => 'Управление отзывами';

  @override
  String get reviewModerationVerified => 'Подтверждённый';

  @override
  String get routeDetailCenterOnNodeTooltip => 'Центрировать на ноде';

  @override
  String routeDetailDistanceKilometers(String km) {
    return '$km км';
  }

  @override
  String get routeDetailDistanceLabel => 'Расстояние';

  @override
  String routeDetailDistanceMeters(String meters) {
    return '$meters м';
  }

  @override
  String routeDetailDurationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String get routeDetailDurationLabel => 'Длительность';

  @override
  String routeDetailDurationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get routeDetailElevationLabel => 'Высота';

  @override
  String routeDetailElevationValue(String meters) {
    return '$meters м';
  }

  @override
  String routeDetailExportFailed(String error) {
    return 'Экспорт не выполнен: $error';
  }

  @override
  String get routeDetailNoData => '--';

  @override
  String get routeDetailNoGpsPoints => 'GPS-точек нет';

  @override
  String get routeDetailPointsLabel => 'Точки';

  @override
  String routeDetailShareText(String name) {
    return 'Маршрут: $name';
  }

  @override
  String get routeDetailStorageUnavailable => 'Хранилище недоступно';

  @override
  String get routeDetailYouBadge => 'Вы';

  @override
  String get routesCancel => 'Отмена';

  @override
  String get routesCancelRecording => 'Отмена';

  @override
  String routesCardDurationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String routesCardDurationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get routesColorLabel => 'Цвет';

  @override
  String get routesDeleteAction => 'Удалить';

  @override
  String get routesDeleteConfirmAction => 'Удалить';

  @override
  String routesDeleteConfirmMessage(String name) {
    return 'Вы уверены, что хотите удалить «$name»? Это действие нельзя отменить.';
  }

  @override
  String get routesDeleteConfirmTitle => 'Удалить маршрут?';

  @override
  String routesDistanceDuration(String distance, String duration) {
    return '$distance • $duration';
  }

  @override
  String routesDistanceKilometers(String km) {
    return '$km км';
  }

  @override
  String routesDistanceMeters(String meters) {
    return '$meters м';
  }

  @override
  String routesDurationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String routesDurationMinutesSeconds(int minutes, int seconds) {
    return '$minutes мин $seconds с';
  }

  @override
  String routesDurationSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String routesElevationGain(String meters) {
    return '$meters м ↑';
  }

  @override
  String get routesEmptyDescription =>
      'Запишите первый маршрут или импортируйте GPX-файл';

  @override
  String get routesEmptyTitle => 'Маршрутов пока нет';

  @override
  String routesExportFailed(String error) {
    return 'Экспорт не выполнен: $error';
  }

  @override
  String get routesExportGpx => 'Экспортировать GPX';

  @override
  String get routesFileReadFailed => 'Не удалось прочитать файл';

  @override
  String routesImportFailed(String error) {
    return 'Импорт не выполнен: $error';
  }

  @override
  String get routesImportGpx => 'Импортировать GPX';

  @override
  String routesImportSuccess(String name) {
    return 'Импортировано: $name';
  }

  @override
  String get routesInvalidGpxFile => 'Некорректный GPX-файл';

  @override
  String get routesNewRouteSubtitle => 'Начните запись GPS-трека';

  @override
  String get routesNewRouteTitle => 'Новый маршрут';

  @override
  String get routesNotesHint => 'Состояние тропы, погода и т.д.';

  @override
  String get routesNotesLabel => 'Заметки (необязательно)';

  @override
  String routesPointCount(int count) {
    return '$count точек';
  }

  @override
  String routesPointsShort(int count) {
    return '$count тч.';
  }

  @override
  String get routesRecordingLabel => 'Запись';

  @override
  String get routesRouteNameHint => 'Утренняя прогулка';

  @override
  String get routesRouteNameLabel => 'Название маршрута';

  @override
  String get routesScreenTitle => 'Маршруты';

  @override
  String routesShareText(String name) {
    return 'Маршрут: $name';
  }

  @override
  String get routesStart => 'Старт';

  @override
  String get routesStartRoute => 'Начать маршрут';

  @override
  String get routesStopRecording => 'Стоп';

  @override
  String get scannerAuthFailedError =>
      'Ошибка аутентификации. Возможно, устройство нужно повторно сопрячь. Перейдите в Настройки > Bluetooth, удалите устройство Meshtastic, затем нажмите на него ниже для переподключения.';

  @override
  String get scannerAutoReconnectDisabledSubtitle =>
      'Выберите устройство ниже для ручного подключения.';

  @override
  String scannerAutoReconnectDisabledSubtitleWithDevice(String name) {
    return 'Выберите «$name» ниже или включите автоподключение.';
  }

  @override
  String get scannerAutoReconnectDisabledTitle => 'Автоподключение отключено';

  @override
  String get scannerAvailableDevices => 'Доступные устройства';

  @override
  String get scannerBluetoothSettings => 'Настройки Bluetooth';

  @override
  String get scannerBluetoothSettingsOpenFailed =>
      'Не удалось открыть настройки Bluetooth. Откройте Настройки > Bluetooth вручную.';

  @override
  String get scannerConnectDeviceTitle => 'Подключить устройство';

  @override
  String get scannerConnectingStatus => 'Подключение...';

  @override
  String scannerConnectionFailedWithError(String error) {
    return 'Ошибка подключения: $error';
  }

  @override
  String get scannerConnectionTimedOut =>
      'Время подключения истекло. Возможно, устройство вне зоны действия, выключено или подключено к другому телефону.';

  @override
  String get scannerCopyright => '© 2026 Socialmesh. Все права защищены.';

  @override
  String get scannerDetailAddress => 'Адрес';

  @override
  String get scannerDetailBluetoothLowEnergy => 'Bluetooth Low Energy';

  @override
  String get scannerDetailConnectionType => 'Тип подключения';

  @override
  String get scannerDetailDeviceName => 'Имя устройства';

  @override
  String get scannerDetailManufacturerData => 'Данные производителя';

  @override
  String get scannerDetailServiceUuids => 'UUID сервисов';

  @override
  String get scannerDetailSignalStrength => 'Уровень сигнала';

  @override
  String get scannerDetailUsbSerial => 'USB Serial';

  @override
  String get scannerDeviceDisconnectedUnexpectedly =>
      'Устройство неожиданно отключилось. Возможно, оно вышло из зоны действия или потеряло питание.';

  @override
  String get scannerDeviceNotFoundSubtitle =>
      'Если другое приложение подключено к этому устройству, сначала отключитесь от него. Только одно приложение может использовать Bluetooth одновременно.';

  @override
  String scannerDeviceNotFoundTitle(String name) {
    return '$name не найдено';
  }

  @override
  String scannerDevicesFoundCount(int count) {
    return 'Найдено устройств: $count';
  }

  @override
  String get scannerDevicesTitle => 'Устройства';

  @override
  String get scannerEnableAutoReconnectMessage =>
      'Приложение будет автоматически подключаться к последнему использованному устройству при каждом запуске.';

  @override
  String scannerEnableAutoReconnectMessageWithDevice(String name) {
    return 'Приложение автоматически подключится к «$name» сейчас и при каждом последующем запуске.';
  }

  @override
  String get scannerEnableAutoReconnectTitle => 'Включить автоподключение?';

  @override
  String get scannerEnableBluetoothHint =>
      'Убедитесь, что Bluetooth включён и устройство Meshtastic включено';

  @override
  String get scannerEnableLabel => 'Включить';

  @override
  String get scannerGattConnectionFailed =>
      'Ошибка подключения. Это может произойти, если устройство ранее было сопряжено с другим приложением. Перейдите в Настройки > Bluetooth, найдите устройство Meshtastic, нажмите «Забыть» и повторите попытку.';

  @override
  String get scannerLookingForDevices => 'Поиск устройств…';

  @override
  String get scannerMeshCoreConnectionFailed => 'Ошибка подключения MeshCore';

  @override
  String scannerMeshCoreConnectionFailedWithError(String error) {
    return 'Ошибка подключения MeshCore: $error';
  }

  @override
  String get scannerPairingInvalidatedError =>
      'Телефон удалил сохранённые данные сопряжения для этого устройства. Перейдите в Настройки > Bluetooth, удалите «Meshtastic_XXXX» и повторите попытку.';

  @override
  String get scannerPinRequiredError =>
      'Ошибка подключения — повторите попытку и введите PIN при появлении запроса';

  @override
  String get scannerProtocolMeshCore => 'MeshCore';

  @override
  String get scannerProtocolMeshtastic => 'Meshtastic';

  @override
  String get scannerProtocolUnknown => 'Неизвестный';

  @override
  String get scannerRetryScan => 'Повторить сканирование';

  @override
  String get scannerScanningSubtitle => 'Поиск устройств Meshtastic...';

  @override
  String get scannerScanningTitle => 'Сканирование ближайших устройств';

  @override
  String get scannerTransportBluetooth => 'Bluetooth';

  @override
  String get scannerTransportUsb => 'USB';

  @override
  String get scannerUnknownDeviceDescription =>
      'Это устройство не определено как Meshtastic или MeshCore.';

  @override
  String get scannerUnknownProtocol => 'Неизвестный протокол';

  @override
  String get scannerUnsupportedDeviceMessage =>
      'Это устройство не может быть подключено автоматически. Поддерживаются только устройства Meshtastic и MeshCore.';

  @override
  String scannerVersionText(String version) {
    return 'Socialmesh v$version';
  }

  @override
  String scannerVersionTextShort(String version) {
    return 'Версия v$version';
  }

  @override
  String get searchProductsBrowseByCategory => 'Обзор по категориям';

  @override
  String get searchProductsClear => 'Очистить';

  @override
  String get searchProductsHint => 'Поиск устройств, модулей, антенн...';

  @override
  String searchProductsNoResults(String query) {
    return 'Нет результатов по запросу «$query»';
  }

  @override
  String get searchProductsOutOfStock => 'Нет в наличии';

  @override
  String get searchProductsRecentSearches => 'Недавние поиски';

  @override
  String searchProductsResultCount(int count, String query) {
    return '$count результатов по запросу «$query»';
  }

  @override
  String get searchProductsRetry => 'Повторить';

  @override
  String get searchProductsSearchFailed => 'Поиск не удался';

  @override
  String get searchProductsTrending => 'Популярное';

  @override
  String get searchProductsTryDifferent =>
      'Попробуйте другие ключевые слова или просмотрите категории';

  @override
  String get sellerProfileAbout => 'О продавце';

  @override
  String get sellerProfileApplyCodeHint =>
      'Используйте этот код при оформлении заказа в магазине продавца';

  @override
  String get sellerProfileCodeCopied => 'Код скопирован в буфер обмена';

  @override
  String get sellerProfileContactShipping => 'Контакты и доставка';

  @override
  String get sellerProfileDiscountExclusive =>
      'Эксклюзивный код скидки для пользователей Socialmesh';

  @override
  String get sellerProfileEmail => 'Email';

  @override
  String get sellerProfileErrorLoading => 'Ошибка загрузки продавца';

  @override
  String get sellerProfileFoundedStat => 'Основан';

  @override
  String get sellerProfileGoBack => 'Назад';

  @override
  String get sellerProfileNoProducts => 'Товары ещё не добавлены';

  @override
  String sellerProfileNoSearchResults(String query) {
    return 'Нет товаров, соответствующих запросу «$query»';
  }

  @override
  String get sellerProfileNotFound => 'Продавец не найден';

  @override
  String get sellerProfileOfficialPartner => 'Официальный партнёр';

  @override
  String get sellerProfilePartnerDiscount => 'Партнёрская скидка';

  @override
  String sellerProfileProductsCount(int count) {
    return 'Товары ($count)';
  }

  @override
  String get sellerProfileProductsStat => 'Товары';

  @override
  String get sellerProfileRevealCode => 'Показать код';

  @override
  String sellerProfileReviewCount(int count) {
    return '$count отзывов';
  }

  @override
  String get sellerProfileSalesStat => 'Продажи';

  @override
  String get sellerProfileSearchHint => 'Поиск товаров...';

  @override
  String get sellerProfileShipsTo => 'Доставка в';

  @override
  String get sellerProfileTitle => 'Продавец';

  @override
  String get sellerProfileCopyCodeTooltip => 'Копировать код';

  @override
  String get sellerProfileUnableToLoad => 'Не удалось загрузить товары';

  @override
  String get sellerProfileWebsite => 'Сайт';

  @override
  String get serialConfigBaudRate => 'Скорость передачи';

  @override
  String get serialConfigBaudRateSubtitle => 'Скорость последовательной связи';

  @override
  String get serialConfigEcho => 'Эхо';

  @override
  String get serialConfigEchoSubtitle =>
      'Отправлять отправленные пакеты обратно на последовательный порт';

  @override
  String get serialConfigEnabled => 'Последовательный порт включён';

  @override
  String get serialConfigEnabledSubtitle =>
      'Включить связь через последовательный порт';

  @override
  String serialConfigGpioPin(int pin) {
    return 'Вывод $pin';
  }

  @override
  String get serialConfigGpioUnset => 'Не задан';

  @override
  String get serialConfigModeCaltopoDesc =>
      'Формат CalTopo для картографических приложений';

  @override
  String get serialConfigModeNmeaDesc =>
      'Вывод NMEA GPS для навигационных приложений';

  @override
  String get serialConfigModeProtoDesc =>
      'Бинарный протокол Protobuf для программного доступа';

  @override
  String get serialConfigModeSimpleDesc =>
      'Простой последовательный вывод для базального терминала';

  @override
  String get serialConfigModeTextmsgDesc =>
      'Режим текстовых сообщений для SMS-подобного общения';

  @override
  String get serialConfigOverrideConsole =>
      'Переопределить консольный последовательный порт';

  @override
  String get serialConfigOverrideConsoleSubtitle =>
      'Использовать последовательный модуль вместо консоли';

  @override
  String get serialConfigRxdGpio => 'GPIO-вывод RXD';

  @override
  String get serialConfigRxdGpioSubtitle =>
      'Номер GPIO-вывода для приёма данных';

  @override
  String get serialConfigSave => 'Сохранить';

  @override
  String serialConfigSaveError(String error) {
    return 'Ошибка сохранения конфигурации: $error';
  }

  @override
  String get serialConfigSaved =>
      'Конфигурация последовательного порта сохранена';

  @override
  String get serialConfigSectionBaudRate => 'Скорость передачи';

  @override
  String get serialConfigSectionGeneral => 'Общие';

  @override
  String get serialConfigSectionSerialMode => 'Режим последовательного порта';

  @override
  String get serialConfigSectionTimeout => 'Тайм-аут';

  @override
  String get serialConfigTimeout => 'Тайм-аут';

  @override
  String serialConfigTimeoutValue(int seconds) {
    return '$seconds секунд';
  }

  @override
  String get serialConfigTitle => 'Настройки последовательного порта';

  @override
  String get serialConfigTxdGpio => 'GPIO-вывод TXD';

  @override
  String get serialConfigTxdGpioSubtitle =>
      'Номер GPIO-вывода для передачи данных';

  @override
  String settingsClearAllDataFailed(String error) {
    return 'Не удалось очистить некоторые данные: $error';
  }

  @override
  String get settingsClearAllDataLabel => 'Очистить всё';

  @override
  String get settingsClearAllDataMessage =>
      'Это удалит ВСЕ данные приложения: сообщения, ноды, каналы, настройки, ключи, сигналы, закладки, автоматизации, виджеты и сохранённые параметры. Это действие нельзя отменить.';

  @override
  String get settingsClearAllDataSuccess => 'Все данные успешно очищены';

  @override
  String get settingsClearAllDataTitle => 'Очистить все данные';

  @override
  String get settingsClearMessagesLabel => 'Очистить';

  @override
  String get settingsClearMessagesMessage =>
      'Это удалит все сохранённые сообщения. Это действие нельзя отменить.';

  @override
  String get settingsClearMessagesSuccess => 'Сообщения очищены';

  @override
  String get settingsClearMessagesTitle => 'Очистить сообщения';

  @override
  String get settingsDeviceInfoConnection => 'Подключение';

  @override
  String get settingsDeviceInfoDeviceName => 'Имя устройства';

  @override
  String get settingsDeviceInfoHardware => 'Оборудование';

  @override
  String get settingsDeviceInfoLongName => 'Полное имя';

  @override
  String get settingsDeviceInfoNodeNumber => 'Номер ноды';

  @override
  String get settingsDeviceInfoNone => 'Нет';

  @override
  String get settingsDeviceInfoNotConnected => 'Не подключено';

  @override
  String get settingsDeviceInfoShortName => 'Краткое имя';

  @override
  String get settingsDeviceInfoTitle => 'Информация об устройстве';

  @override
  String get settingsDeviceInfoUnknown => 'Неизвестно';

  @override
  String get settingsDeviceInfoUserId => 'ID пользователя';

  @override
  String settingsErrorLoading(String error) {
    return 'Ошибка загрузки настроек: $error';
  }

  @override
  String settingsForceSyncFailed(String error) {
    return 'Синхронизация не удалась: $error';
  }

  @override
  String get settingsForceSyncLabel => 'Синхронизировать';

  @override
  String get settingsForceSyncMessage =>
      'Это очистит все локальные сообщения, ноды и каналы, а затем повторно синхронизирует всё с подключённым устройством.\n\nВы уверены, что хотите продолжить?';

  @override
  String get settingsForceSyncNotConnected => 'Устройство не подключено';

  @override
  String get settingsForceSyncSuccess => 'Синхронизация завершена';

  @override
  String get settingsForceSyncTitle => 'Принудительная синхронизация';

  @override
  String get settingsForceSyncingStatus => 'Синхронизация с устройством…';

  @override
  String get settingsHapticIntensityTitle =>
      'Интенсивность тактильного отклика';

  @override
  String get settingsHapticMediumDescription =>
      'Сбалансированный отклик для большинства действий';

  @override
  String get settingsHapticStrongDescription =>
      'Сильный отклик для чёткого подтверждения';

  @override
  String get settingsHapticSubtleDescription =>
      'Лёгкий отклик для мягкого прикосновения';

  @override
  String get settingsHelpTooltip => 'Помощь';

  @override
  String settingsHistoryLimitOption(int limit) {
    return '$limit сообщений';
  }

  @override
  String get settingsHistoryLimitTitle => 'Лимит истории сообщений';

  @override
  String get settingsLoadingStatus => 'Загрузка…';

  @override
  String get settingsMeshtasticGoBack => 'Назад';

  @override
  String get settingsMeshtasticOfflineMessage =>
      'Для отображения этого содержимого требуется подключение к интернету. Проверьте соединение и повторите попытку.';

  @override
  String get settingsMeshtasticRefresh => 'Обновить';

  @override
  String get settingsMeshtasticUnableToLoad => 'Не удалось загрузить страницу';

  @override
  String get settingsMeshtasticWebViewTitle => 'Meshtastic';

  @override
  String get settingsNoSettingsFound => 'Настройки не найдены';

  @override
  String get settingsNotConfigured => 'Не настроено';

  @override
  String get settingsOpenSourceAppName => 'Socialmesh';

  @override
  String get settingsOpenSourceLegalese =>
      '© 2024 Socialmesh\n\nЭто приложение использует программное обеспечение с открытым исходным кодом. Полный список сторонних лицензий представлен ниже.';

  @override
  String get settingsPremiumAllUnlocked => 'Все функции разблокированы!';

  @override
  String get settingsPremiumBadgeLocked => 'ЗАБЛОКИРОВАНО';

  @override
  String get settingsPremiumBadgeOwned => 'КУПЛЕНО';

  @override
  String get settingsPremiumBadgeTry => 'ПОПРОБОВАТЬ';

  @override
  String settingsPremiumPartiallyUnlocked(int owned, int total) {
    return '$owned из $total разблокировано';
  }

  @override
  String get settingsPremiumUnlockFeaturesTitle => 'Разблокировать функции';

  @override
  String get settingsProfileLocalOnly => 'Только локально';

  @override
  String get settingsProfileSubtitle => 'Настройте свой профиль';

  @override
  String get settingsProfileSynced => 'Синхронизировано';

  @override
  String get settingsProfileTitle => 'Профиль';

  @override
  String get settingsRegionConfigureSubtitle =>
      'Настройка радиочастоты устройства';

  @override
  String get settingsRemoteAdminConfigureTitle => 'Настройка устройства';

  @override
  String get settingsRemoteAdminConfiguringTitle => 'Настройка удалённой ноды';

  @override
  String get settingsRemoteAdminConnectedDevice => 'Подключённое устройство';

  @override
  String settingsRemoteAdminNodeCount(int count) {
    return '$count нод';
  }

  @override
  String get settingsRemoteAdminWarning =>
      'Для удалённого администрирования необходимо, чтобы ваш публичный ключ был добавлен в список ключей администратора целевой ноды.';

  @override
  String get settingsResetLocalDataLabel => 'Сбросить';

  @override
  String get settingsResetLocalDataMessage =>
      'Это очистит все сообщения и данные нод, что вынудит выполнить свежую синхронизацию с устройством при следующем подключении.\n\nВаши настройки, тема и параметры будут сохранены.\n\nИспользуйте это, если ноды показывают некорректный статус или сообщения отображаются неправильно.';

  @override
  String get settingsResetLocalDataSuccess =>
      'Локальные данные сброшены. Подключитесь повторно для синхронизации.';

  @override
  String get settingsResetLocalDataTitle => 'Сбросить локальные данные';

  @override
  String get settingsSearchAutoAcceptTransfersSubtitle =>
      'Автоматически принимать входящие предложения файлов';

  @override
  String get settingsSearchAutoAcceptTransfersTitle => 'Автоприём передач';

  @override
  String get settingsSearchAutomationsPackSubtitle =>
      'Автоматические действия и триггеры';

  @override
  String get settingsSearchAutomationsPackTitle => 'Пакет автоматизаций';

  @override
  String get settingsSearchCannedMessagesSubtitle =>
      'Преднастроенные сообщения устройства';

  @override
  String get settingsSearchCannedMessagesTitle => 'Готовые сообщения';

  @override
  String get settingsSearchChannelNotificationsSubtitle =>
      'Уведомления о трансляциях в каналах';

  @override
  String get settingsSearchChannelNotificationsTitle =>
      'Уведомления о сообщениях в каналах';

  @override
  String get settingsSearchClearAllDataSubtitle =>
      'Удалить сообщения, настройки и ключи';

  @override
  String get settingsSearchClearAllMessagesSubtitle =>
      'Удалить все сохранённые сообщения';

  @override
  String get settingsSearchClearAllMessagesTitle => 'Очистить все сообщения';

  @override
  String get settingsSearchCommentsSubtitle =>
      'Push-уведомления о комментариях и @упоминаниях';

  @override
  String get settingsSearchDmNotificationsSubtitle =>
      'Уведомления о личных сообщениях';

  @override
  String get settingsSearchDmNotificationsTitle =>
      'Уведомления о личных сообщениях';

  @override
  String get settingsSearchExportDataSubtitle => 'Экспорт сообщений и настроек';

  @override
  String get settingsSearchExportDataTitle => 'Экспорт данных';

  @override
  String get settingsSearchFileTransferSubtitle =>
      'Отправка и получение небольших файлов через сеть';

  @override
  String get settingsSearchFileTransferTitle => 'Передача файлов';

  @override
  String get settingsSearchForceSyncSubtitle =>
      'Принудительная синхронизация конфигурации';

  @override
  String get settingsSearchForceSyncTitle => 'Принудительная синхронизация';

  @override
  String get settingsSearchHapticIntensitySubtitle =>
      'Лёгкий, средний или сильный отклик';

  @override
  String get settingsSearchHint => 'Найти настройку';

  @override
  String get settingsSearchHistoryLimitSubtitle =>
      'Максимальное количество сохраняемых сообщений';

  @override
  String get settingsSearchHistoryLimitTitle => 'Лимит истории сообщений';

  @override
  String get settingsSearchIftttPackSubtitle =>
      'Интеграция с внешними сервисами';

  @override
  String get settingsSearchIftttPackTitle => 'Пакет IFTTT';

  @override
  String get settingsSearchLikesSubtitle =>
      'Push-уведомления о лайках публикаций';

  @override
  String get settingsSearchLinkedDevicesSubtitle =>
      'Устройства Meshtastic, привязанные к вашему профилю';

  @override
  String get settingsSearchLinkedDevicesTitle => 'Привязанные устройства';

  @override
  String get settingsSearchNewFollowersSubtitle =>
      'Push-уведомления, когда кто-то подписывается на вас';

  @override
  String get settingsSearchNewNodesNotificationsSubtitle =>
      'Уведомлять о появлении новых нод в сети';

  @override
  String get settingsSearchNewNodesNotificationsTitle =>
      'Уведомления о новых нодах';

  @override
  String get settingsSearchNotificationSoundSubtitle =>
      'Воспроизводить звук при уведомлениях';

  @override
  String get settingsSearchNotificationSoundTitle => 'Звук уведомлений';

  @override
  String get settingsSearchNotificationVibrationSubtitle =>
      'Вибрировать при уведомлениях';

  @override
  String get settingsSearchNotificationVibrationTitle =>
      'Вибрация при уведомлениях';

  @override
  String get settingsSearchPremiumSubtitle =>
      'Рингтоны, темы, автоматизации, IFTTT, виджеты';

  @override
  String get settingsSearchProfileSubtitle =>
      'Ваше отображаемое имя, аватар и описание';

  @override
  String get settingsSearchRegionSubtitle => 'Регион радиочастоты устройства';

  @override
  String get settingsSearchRegionTitle => 'Регион';

  @override
  String get settingsSearchRemoteAdminSubtitle =>
      'Настройка удалённых нод через PKI-администрирование';

  @override
  String get settingsSearchRemoteAdminTitle => 'Удалённое администрирование';

  @override
  String get settingsSearchResetLocalDataSubtitle =>
      'Очистить все локальные данные приложения';

  @override
  String get settingsSearchResetLocalDataTitle => 'Сбросить локальные данные';

  @override
  String get settingsSearchRingtonePackSubtitle =>
      'Пользовательские звуки уведомлений';

  @override
  String get settingsSearchRingtonePackTitle => 'Пакет рингтонов';

  @override
  String get settingsSearchScanForDeviceSubtitle =>
      'Сканировать QR-код для быстрой настройки';

  @override
  String get settingsSearchScanForDeviceTitle => 'Сканировать устройство';

  @override
  String get settingsSearchTakGatewaySubtitle =>
      'URL шлюза, публикация местоположения, позывной';

  @override
  String get settingsSearchTakGatewayTitle => 'Шлюз TAK';

  @override
  String get settingsSearchThemePackSubtitle =>
      'Акцентные цвета и визуальная кастомизация';

  @override
  String get settingsSearchThemePackTitle => 'Пакет тем';

  @override
  String get settingsSearchWidgetPackSubtitle => 'Виджеты главного экрана';

  @override
  String get settingsSearchWidgetPackTitle => 'Пакет виджетов';

  @override
  String get settingsSectionAbout => 'О ПРИЛОЖЕНИИ';

  @override
  String get settingsSectionAccount => 'АККАУНТ';

  @override
  String get settingsSectionAnimations => 'АНИМАЦИИ';

  @override
  String get settingsSectionAppearance => 'ВНЕШНИЙ ВИД';

  @override
  String get settingsSectionConnection => 'ПОДКЛЮЧЕНИЕ';

  @override
  String get settingsSectionDataStorage => 'ДАННЫЕ И ХРАНИЛИЩЕ';

  @override
  String get settingsSectionDevice => 'УСТРОЙСТВО';

  @override
  String get settingsSectionFeedback => 'ОБРАТНАЯ СВЯЗЬ';

  @override
  String get settingsSectionHapticFeedback => 'ТАКТИЛЬНЫЙ ОТКЛИК';

  @override
  String get settingsSectionMessaging => 'СООБЩЕНИЯ';

  @override
  String get settingsSectionModules => 'МОДУЛИ';

  @override
  String get settingsSectionNotifications => 'УВЕДОМЛЕНИЯ';

  @override
  String get settingsSectionPremium => 'PREMIUM';

  @override
  String get settingsSectionRemoteAdmin => 'УДАЛЁННОЕ АДМИНИСТРИРОВАНИЕ';

  @override
  String get settingsSectionSocialNotifications => 'СОЦИАЛЬНЫЕ УВЕДОМЛЕНИЯ';

  @override
  String get settingsSectionTelemetryLogs => 'ЖУРНАЛЫ ТЕЛЕМЕТРИИ';

  @override
  String get settingsSectionTools => 'ИНСТРУМЕНТЫ';

  @override
  String get settingsSectionWhatsNew => 'ЧТО НОВОГО';

  @override
  String get settingsSocialCommentsSubtitle =>
      'Когда кто-то комментирует или @упоминает вас';

  @override
  String get settingsSocialCommentsTitle => 'Комментарии и упоминания';

  @override
  String get settingsSocialLikesSubtitle =>
      'Когда кто-то ставит лайк вашим публикациям';

  @override
  String get settingsSocialLikesTitle => 'Лайки';

  @override
  String get settingsSocialNewFollowersSubtitle =>
      'Когда кто-то подписывается на вас или отправляет запрос';

  @override
  String get settingsSocialNewFollowersTitle => 'Новые подписчики';

  @override
  String get settingsSocialNotificationsLoading => 'Загрузка…';

  @override
  String get settingsSocialNotificationsLoadingSubtitle =>
      'Получение настроек уведомлений';

  @override
  String settingsSocialmeshVersionSnackbar(String version) {
    return 'Socialmesh v$version';
  }

  @override
  String get settingsTile3dEffectsSubtitle =>
      'Перспективные преобразования и эффекты глубины';

  @override
  String get settingsTile3dEffectsTitle => '3D-эффекты';

  @override
  String get settingsTileAirQualitySubtitle => 'Показания PM2.5, PM10, CO2';

  @override
  String get settingsTileAirQualityTitle => 'Качество воздуха';

  @override
  String get settingsTileAmbientLightingSubtitle =>
      'Настройка параметров LED и RGB';

  @override
  String get settingsTileAmbientLightingTitle => 'Окружающее освещение';

  @override
  String get settingsTileAppLogSubtitle =>
      'Просмотр отладочных журналов приложения';

  @override
  String get settingsTileAppLogTitle => 'Журнал приложения';

  @override
  String get settingsTileAppearanceSubtitle =>
      'Шрифт, размер текста, плотность, контрастность, движение';

  @override
  String get settingsTileAppearanceTitle => 'Внешний вид и доступность';

  @override
  String get settingsTileAutoReconnectSubtitle =>
      'Автоматически переподключаться к последнему устройству';

  @override
  String get settingsTileAutoReconnectTitle => 'Автоподключение';

  @override
  String get settingsTileBackgroundConnectionSubtitle =>
      'Фоновое BLE, уведомления и настройки питания';

  @override
  String get settingsTileBackgroundConnectionTitle => 'Фоновое подключение';

  @override
  String get settingsTileBluetoothSubtitle => 'Режим сопряжения, настройки PIN';

  @override
  String get settingsTileBluetoothTitle => 'Bluetooth';

  @override
  String get settingsTileCannedMessagesSubtitle =>
      'Настройки готовых сообщений на стороне устройства';

  @override
  String get settingsTileCannedMessagesTitle => 'Модуль готовых сообщений';

  @override
  String get settingsTileChannelMessagesSubtitle =>
      'Уведомления о трансляциях в каналах';

  @override
  String get settingsTileChannelMessagesTitle => 'Сообщения в каналах';

  @override
  String get settingsTileClearAllDataSubtitle =>
      'Удалить сообщения, настройки и ключи';

  @override
  String get settingsTileClearAllDataTitle => 'Очистить все данные';

  @override
  String get settingsTileClearMessageHistorySubtitle =>
      'Удалить все сохранённые сообщения';

  @override
  String get settingsTileClearMessageHistoryTitle =>
      'Очистить историю сообщений';

  @override
  String get settingsTileDetectionSensorLogsSubtitle =>
      'История событий датчика';

  @override
  String get settingsTileDetectionSensorLogsTitle =>
      'Журналы датчика обнаружения';

  @override
  String get settingsTileDetectionSensorSubtitle =>
      'Настройка датчиков движения и дверных датчиков на базе GPIO';

  @override
  String get settingsTileDetectionSensorTitle => 'Датчик обнаружения';

  @override
  String get settingsTileDeviceInfoSubtitle =>
      'Просмотр информации о подключённом устройстве';

  @override
  String get settingsTileDeviceInfoTitle => 'Информация об устройстве';

  @override
  String get settingsTileDeviceManagementSubtitle =>
      'Перезагрузка, выключение, сброс к заводским настройкам';

  @override
  String get settingsTileDeviceManagementTitle => 'Управление устройством';

  @override
  String get settingsTileDeviceMetricsSubtitle =>
      'История заряда батареи, напряжения и использования';

  @override
  String get settingsTileDeviceMetricsTitle => 'Метрики устройства';

  @override
  String get settingsTileDeviceRoleSubtitle =>
      'Настройка поведения и роли устройства';

  @override
  String get settingsTileDeviceRoleTitle => 'Роль и настройки устройства';

  @override
  String get settingsTileDirectMessagesSubtitle =>
      'Уведомления о личных сообщениях';

  @override
  String get settingsTileDirectMessagesTitle => 'Личные сообщения';

  @override
  String get settingsTileDisplaySettingsSubtitle =>
      'Тайм-аут экрана, единицы измерения, режим отображения';

  @override
  String get settingsTileDisplaySettingsTitle => 'Настройки экрана';

  @override
  String get settingsTileEnvironmentMetricsSubtitle =>
      'Журналы температуры, влажности и давления';

  @override
  String get settingsTileEnvironmentMetricsTitle => 'Метрики окружающей среды';

  @override
  String get settingsTileExportDataSubtitle =>
      'Экспорт сообщений, телеметрии, маршрутов';

  @override
  String get settingsTileExportDataTitle => 'Экспорт данных';

  @override
  String get settingsTileExportMessagesSubtitle =>
      'Экспорт сообщений в PDF или CSV';

  @override
  String get settingsTileExportMessagesTitle => 'Экспорт сообщений';

  @override
  String get settingsTileExternalNotificationSubtitle =>
      'Настройка зуммеров, LED и вибрационных оповещений';

  @override
  String get settingsTileExternalNotificationTitle => 'Внешнее уведомление';

  @override
  String get settingsTileFirmwareUpdateSubtitle =>
      'Проверить наличие обновлений прошивки устройства';

  @override
  String get settingsTileFirmwareUpdateTitle => 'Обновление прошивки';

  @override
  String get settingsTileForceSyncSubtitle =>
      'Повторная синхронизация всех данных с подключённым устройством';

  @override
  String get settingsTileForceSyncTitle => 'Принудительная синхронизация';

  @override
  String get settingsTileGlyphMatrixSubtitle =>
      'LED-паттерны для Nothing Phone 3';

  @override
  String get settingsTileGlyphMatrixTitle => 'Тест матрицы глифов';

  @override
  String get settingsTileGpsStatusSubtitle =>
      'Просмотр подробной информации GPS';

  @override
  String get settingsTileGpsStatusTitle => 'Статус GPS';

  @override
  String get settingsTileHapticFeedbackSubtitle =>
      'Вибрационный отклик на действия';

  @override
  String get settingsTileHapticFeedbackTitle => 'Тактильный отклик';

  @override
  String get settingsTileHelpCenterSubtitle =>
      'Интерактивные руководства с Ico, вашим проводником по сети';

  @override
  String get settingsTileHelpCenterTitle => 'Центр помощи';

  @override
  String get settingsTileHelpSupportSubtitle =>
      'Вопросы и ответы, устранение неполадок и контактная информация';

  @override
  String get settingsTileHelpSupportTitle => 'Помощь и поддержка';

  @override
  String get settingsTileIntensityTitle => 'Интенсивность';

  @override
  String get settingsTileListAnimationsSubtitle =>
      'Эффекты скольжения и отскока в списках';

  @override
  String get settingsTileListAnimationsTitle => 'Анимации списков';

  @override
  String settingsTileMessageHistorySubtitle(int count) {
    return '$count сохранённых сообщений';
  }

  @override
  String get settingsTileMessageHistoryTitle => 'История сообщений';

  @override
  String get settingsTileMqttSubtitle =>
      'Настройка моста между сетью и интернетом';

  @override
  String get settingsTileMqttTitle => 'MQTT';

  @override
  String get settingsTileMyBugReportsNotSignedIn =>
      'Войдите, чтобы отслеживать свои отчёты и получать ответы';

  @override
  String get settingsTileMyBugReportsSubtitle =>
      'Просмотр ваших отчётов и ответов на них';

  @override
  String get settingsTileMyBugReportsTitle => 'Мои отчёты об ошибках';

  @override
  String get settingsTileNetworkSubtitle => 'Настройки WiFi, Ethernet, NTP';

  @override
  String get settingsTileNetworkTitle => 'Сеть';

  @override
  String get settingsTileNewNodesSubtitle =>
      'Уведомлять о появлении новых нод в сети';

  @override
  String get settingsTileNewNodesTitle => 'Новые ноды';

  @override
  String get settingsTileOpenSourceSubtitle =>
      'Сторонние библиотеки и атрибуции';

  @override
  String get settingsTileOpenSourceTitle => 'Лицензии на ПО с открытым кодом';

  @override
  String get settingsTilePaxCounterLogsSubtitle =>
      'История обнаружения устройств';

  @override
  String get settingsTilePaxCounterLogsTitle => 'Журналы PAX Counter';

  @override
  String get settingsTilePaxCounterSubtitle =>
      'Настройки обнаружения устройств WiFi/BLE';

  @override
  String get settingsTilePaxCounterTitle => 'PAX Counter';

  @override
  String get settingsTilePositionHistorySubtitle => 'Журналы GPS-позиции';

  @override
  String get settingsTilePositionHistoryTitle => 'История местоположения';

  @override
  String get settingsTilePositionSubtitle =>
      'Режим GPS, интервалы трансляции, фиксированная позиция';

  @override
  String get settingsTilePositionTitle => 'Местоположение и GPS';

  @override
  String get settingsTilePowerManagementSubtitle =>
      'Энергосбережение, настройки сна';

  @override
  String get settingsTilePowerManagementTitle => 'Управление питанием';

  @override
  String get settingsTilePrivacyPolicySubtitle =>
      'Как мы обрабатываем ваши данные';

  @override
  String get settingsTilePrivacyPolicyTitle => 'Политика конфиденциальности';

  @override
  String get settingsTilePrivacySubtitle =>
      'Аналитика, отчёты о сбоях и управление данными';

  @override
  String get settingsTilePrivacyTitle => 'Конфиденциальность';

  @override
  String get settingsTileProvideLocationSubtitle =>
      'Передавать GPS телефона в сеть для устройств без GPS';

  @override
  String get settingsTileProvideLocationTitle =>
      'Передавать местоположение телефона';

  @override
  String get settingsTilePushNotificationsSubtitle =>
      'Главный переключатель для всех уведомлений';

  @override
  String get settingsTilePushNotificationsTitle => 'Push-уведомления';

  @override
  String get settingsTileQuickResponsesSubtitle =>
      'Управление готовыми ответами для быстрой переписки';

  @override
  String get settingsTileQuickResponsesTitle => 'Быстрые ответы';

  @override
  String get settingsTileRadioConfigSubtitle =>
      'Настройки LoRa, предустановка модема, мощность';

  @override
  String get settingsTileRadioConfigTitle => 'Конфигурация радио';

  @override
  String get settingsTileRangeTestSubtitle =>
      'Проверка дальности сигнала с другими нодами';

  @override
  String get settingsTileRangeTestTitle => 'Тест дальности';

  @override
  String get settingsTileRegionTitle => 'Регион / Частота';

  @override
  String get settingsTileResetLocalDataSubtitle =>
      'Очистить сообщения и ноды, сохранив настройки';

  @override
  String get settingsTileResetLocalDataTitle => 'Сбросить локальные данные';

  @override
  String get settingsTileRoutesSubtitle => 'Запись и управление GPS-маршрутами';

  @override
  String get settingsTileRoutesTitle => 'Маршруты';

  @override
  String get settingsTileScanQrCodeSubtitle =>
      'Импорт нод, каналов или автоматизаций';

  @override
  String get settingsTileScanQrCodeTitle => 'Сканировать QR-код';

  @override
  String get settingsTileSecuritySubtitle =>
      'Контроль доступа, управляемый режим';

  @override
  String get settingsTileSecurityTitle => 'Безопасность';

  @override
  String get settingsTileSerialSubtitle =>
      'Конфигурация последовательного порта';

  @override
  String get settingsTileSerialTitle => 'Serial';

  @override
  String get settingsTileShakeToReportSubtitle =>
      'Встряхните устройство, чтобы открыть форму отчёта об ошибке';

  @override
  String get settingsTileShakeToReportTitle => 'Встряхните для отправки отчёта';

  @override
  String get settingsTileSocialmeshSubtitle =>
      'Приложение-компаньон Meshtastic';

  @override
  String get settingsTileSocialmeshTitle => 'Socialmesh';

  @override
  String get settingsTileSoundSubtitle =>
      'Воспроизводить звук при уведомлениях';

  @override
  String get settingsTileSoundTitle => 'Звук';

  @override
  String get settingsTileStoreForwardSubtitle =>
      'Хранить и пересылать сообщения для отключённых нод';

  @override
  String get settingsTileStoreForwardTitle => 'Хранение и пересылка';

  @override
  String get settingsTileTelemetryIntervalsSubtitle =>
      'Настройка частоты обновления телеметрии';

  @override
  String get settingsTileTelemetryIntervalsTitle => 'Интервалы телеметрии';

  @override
  String get settingsTileTermsOfServiceSubtitle =>
      'Юридические условия и положения';

  @override
  String get settingsTileTermsOfServiceTitle => 'Условия использования';

  @override
  String get settingsTileTracerouteHistorySubtitle =>
      'Журналы анализа сетевых путей';

  @override
  String get settingsTileTracerouteHistoryTitle => 'История трассировки';

  @override
  String get settingsTileTrafficManagementSubtitle =>
      'Оптимизация и фильтрация трафика в сети';

  @override
  String get settingsTileTrafficManagementTitle => 'Управление трафиком';

  @override
  String get settingsTileVibrationSubtitle => 'Вибрация при уведомлениях';

  @override
  String get settingsTileVibrationTitle => 'Вибрация';

  @override
  String get settingsTileWhatsNewSubtitle =>
      'Обзор последних функций и обновлений';

  @override
  String get settingsTileWhatsNewTitle => 'Что нового';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsTryDifferentSearch => 'Попробуйте другой поисковый запрос';

  @override
  String settingsVersionString(String version) {
    return 'Версия $version';
  }

  @override
  String get shopAdminDashboardAccessDenied => 'Доступ запрещён';

  @override
  String get shopAdminDashboardAccessRequired =>
      'Требуется доступ администратора';

  @override
  String shopAdminDashboardActiveCount(int count) {
    return '$count активных';
  }

  @override
  String get shopAdminDashboardAddProduct => 'Добавить товар';

  @override
  String get shopAdminDashboardAddSeller => 'Добавить продавца';

  @override
  String get shopAdminDashboardError => 'Ошибка';

  @override
  String get shopAdminDashboardEstRevenue => 'Приблизительный доход';

  @override
  String get shopAdminDashboardFeatured => 'Рекомендуемые товары';

  @override
  String get shopAdminDashboardFeaturedSubtitle =>
      'Управление порядком отображения рекомендуемых товаров';

  @override
  String get shopAdminDashboardInactive => 'Неактивные';

  @override
  String get shopAdminDashboardManagement => 'Управление';

  @override
  String get shopAdminDashboardNoPermission =>
      'У вас нет прав для доступа к этому разделу.';

  @override
  String get shopAdminDashboardOutOfStock => 'Нет в наличии';

  @override
  String get shopAdminDashboardProducts => 'Товары';

  @override
  String get shopAdminDashboardProductsSubtitle =>
      'Управление всеми объявлениями о товарах';

  @override
  String get shopAdminDashboardQuickActions => 'Быстрые действия';

  @override
  String get shopAdminDashboardRefresh => 'Обновить';

  @override
  String get shopAdminDashboardReviews => 'Отзывы';

  @override
  String get shopAdminDashboardReviewsMgmt => 'Отзывы';

  @override
  String get shopAdminDashboardReviewsSubtitle => 'Модерация отзывов о товарах';

  @override
  String get shopAdminDashboardSellers => 'Продавцы';

  @override
  String get shopAdminDashboardSellersSubtitle =>
      'Управление профилями продавцов и партнёрствами';

  @override
  String get shopAdminDashboardTitle => 'Администрирование магазина';

  @override
  String get shopAdminDashboardTotalProducts => 'Всего товаров';

  @override
  String get shopAdminDashboardTotalSales => 'Всего продаж';

  @override
  String get shopAdminDashboardTotalSellers => 'Всего продавцов';

  @override
  String get shopAdminDashboardTotalViews => 'Всего просмотров';

  @override
  String get shopFavoritesEmpty => 'Нет избранных товаров';

  @override
  String get shopFavoritesEmptySubtitle =>
      'Нажмите на значок сердца на товаре, чтобы сохранить его';

  @override
  String get shopFavoritesErrorLoading => 'Ошибка загрузки избранного';

  @override
  String get shopFavoritesInStock => 'В наличии';

  @override
  String get shopFavoritesOutOfStock => 'Нет в наличии';

  @override
  String get shopFavoritesProductRemoved => 'Товар больше не доступен';

  @override
  String get shopFavoritesRetry => 'Повторить';

  @override
  String get shopFavoritesSignIn => 'Войдите, чтобы сохранять избранное';

  @override
  String get shopFavoritesSignInSubtitle =>
      'Ваши любимые устройства появятся здесь';

  @override
  String get shopFavoritesTitle => 'Избранное';

  @override
  String get shopFavoritesUnableToLoad => 'Не удалось загрузить товар';

  @override
  String get shopModelBandAu915 => 'AU 915MHz';

  @override
  String get shopModelBandAu915Range => '915–928 MHz';

  @override
  String get shopModelBandCn470 => 'CN 470MHz';

  @override
  String get shopModelBandCn470Range => '470–510 MHz';

  @override
  String get shopModelBandEu868 => 'EU 868MHz';

  @override
  String get shopModelBandEu868Range => '863–870 MHz';

  @override
  String get shopModelBandIn865 => 'IN 865MHz';

  @override
  String get shopModelBandIn865Range => '865–867 MHz';

  @override
  String get shopModelBandJp920 => 'JP 920MHz';

  @override
  String get shopModelBandJp920Range => '920–925 MHz';

  @override
  String get shopModelBandKr920 => 'KR 920MHz';

  @override
  String get shopModelBandKr920Range => '920–923 MHz';

  @override
  String get shopModelBandMulti => 'Многодиапазонный';

  @override
  String get shopModelBandMultiRange => 'Несколько частот';

  @override
  String get shopModelBandUs915 => 'US 915MHz';

  @override
  String get shopModelBandUs915Range => '902–928 MHz';

  @override
  String get shopModelCategoryAccessories => 'Аксессуары';

  @override
  String get shopModelCategoryAccessoriesDescription =>
      'Кабели, аккумуляторы и многое другое';

  @override
  String get shopModelCategoryAntennas => 'Антенны';

  @override
  String get shopModelCategoryAntennasDescription => 'Антенны и RF-аксессуары';

  @override
  String get shopModelCategoryEnclosures => 'Корпуса';

  @override
  String get shopModelCategoryEnclosuresDescription => 'Чехлы и корпуса';

  @override
  String get shopModelCategoryKits => 'Наборы';

  @override
  String get shopModelCategoryKitsDescription => 'DIY-наборы и комплекты';

  @override
  String get shopModelCategoryModules => 'Модули';

  @override
  String get shopModelCategoryModulesDescription =>
      'Дополнительные модули и платы';

  @override
  String get shopModelCategoryNodes => 'Ноды';

  @override
  String get shopModelCategoryNodesDescription =>
      'Готовые устройства Meshtastic';

  @override
  String get shopModelCategorySolar => 'Солнечная энергия';

  @override
  String get shopModelCategorySolarDescription =>
      'Солнечные панели и решения для питания';

  @override
  String shopModelPriceFrom(String price) {
    return 'От \$$price';
  }

  @override
  String get showcaseCardAmplify => 'Расширьте охват';

  @override
  String get showcaseCardBroadcast => 'ТРАНСЛЯЦИЯ';

  @override
  String get showcaseCardConnected => 'Подключено к сети';

  @override
  String get showcaseCardEncrypted => 'Сквозное шифрование';

  @override
  String get showcaseCardMeshNetwork => 'MESH-СЕТЬ';

  @override
  String get showcaseCardNodeOnline => 'УЗЕЛ В СЕТИ';

  @override
  String get showcaseCardOffGrid => 'Связь без инфраструктуры';

  @override
  String get showcaseCardReachEveryone => 'Свяжитесь с каждым';

  @override
  String get showcaseCardSecureChannel => 'ЗАЩИЩЁННЫЙ КАНАЛ';

  @override
  String get showcaseCardSignalBoost => 'УСИЛЕНИЕ СИГНАЛА';

  @override
  String get showcaseResetAllCards => 'Сбросить все карточки';

  @override
  String get showcaseSnapEffectTitle => 'Эффект щелчка';

  @override
  String get showcaseTapInstruction =>
      'Нажмите на карточку, чтобы убрать её (в стиле Таноса)';

  @override
  String get sigilStageHeraldic => 'Геральдический';

  @override
  String get sigilStageInscribed => 'Начертанный';

  @override
  String get sigilStageLegacy => 'Устаревший';

  @override
  String get sigilStageMarked => 'Отмеченный';

  @override
  String get sigilStageSeed => 'Начальный';

  @override
  String get signalAcquiringDeviceLocation =>
      'Определение местоположения устройства...';

  @override
  String signalActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count активных',
      many: '$count активных',
      few: '$count активных',
      one: '1 активный',
    );
    return '$_temp0';
  }

  @override
  String signalActiveDays(int days) {
    return 'Активен $daysд';
  }

  @override
  String signalActiveHours(int hours) {
    return 'Активен $hoursч';
  }

  @override
  String signalActiveMinutes(int minutes) {
    return 'Активен $minutesм';
  }

  @override
  String get signalActiveNow => 'Активен сейчас';

  @override
  String get signalAddLocation => 'Добавить местоположение';

  @override
  String get signalAddPhotos => 'Добавить фото';

  @override
  String get signalAnonAuthor => 'Аноним';

  @override
  String get signalAnonymous => 'Анонимно';

  @override
  String get signalAnonymousFeed => 'Анонимно';

  @override
  String signalApproxArea(int radiusMeters) {
    return 'Примерный район (~$radiusMetersм)';
  }

  @override
  String get signalAttachFile => 'Прикрепить файл';

  @override
  String get signalBackNearby => 'Назад к ближайшим';

  @override
  String get signalBeFirstToRespond =>
      'Будьте первым, кто ответит на этот сигнал';

  @override
  String get signalBleNoMeshTrafficIos =>
      'Подключено через BLE, но трафик сети не обнаружен. На iOS режим полёта может блокировать BLE-трафик даже при наличии подключения. Отключите режим полёта или переключите Bluetooth.';

  @override
  String get signalBroadcastYourSignal => 'Транслировать свой сигнал';

  @override
  String get signalBroadcastingOverMesh => 'Трансляция по сети...';

  @override
  String get signalCancel => 'Отмена';

  @override
  String get signalChooseFromGallery => 'Выбрать из галереи';

  @override
  String get signalCloudBadge => 'Облако';

  @override
  String get signalCloudFeaturesUnavailable => 'Облачные функции недоступны.';

  @override
  String signalCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count комментария',
      many: '$count комментариев',
      few: '$count комментария',
      one: '1 комментарий',
    );
    return '$_temp0';
  }

  @override
  String get signalCommentReported => 'Комментарий отмечен. Спасибо.';

  @override
  String get signalConnectToAddLocation =>
      'Подключите устройство, чтобы добавить местоположение к сигналу.';

  @override
  String get signalConnectToGoActive =>
      'Подключите устройство, чтобы стать активным';

  @override
  String get signalConnectToSend =>
      'Подключите устройство для отправки сигналов';

  @override
  String get signalConversation => 'Обсуждение';

  @override
  String get signalCreateFailed => 'Не удалось создать сигнал';

  @override
  String get signalCurrentLocation => 'Текущее местоположение';

  @override
  String get signalDelete => 'Удалить';

  @override
  String get signalDeleteMessage => 'Этот сигнал немедленно исчезнет.';

  @override
  String get signalDeleteTitle => 'Удалить сигнал?';

  @override
  String get signalDetailTitle => 'Сигнал';

  @override
  String get signalDeviceNotConnected => 'Устройство не подключено';

  @override
  String get signalDiscardConfirm => 'Отменить';

  @override
  String get signalDiscardMessage => 'Черновик будет удалён.';

  @override
  String get signalDiscardTitle => 'Отменить сигнал?';

  @override
  String get signalDuration => 'Длительность сигнала';

  @override
  String get signalDurationSubtitle => 'Через сколько времени сигнал угаснет';

  @override
  String get signalEmptyTagline1 =>
      'Здесь пока нет активных сигналов.\nСигналы появляются, когда кто-то поблизости становится активным.';

  @override
  String get signalEmptyTagline2 =>
      'Сигналы работают через сеть и существуют временно.\nОни исчезают по истечении таймера.';

  @override
  String get signalEmptyTagline3 =>
      'Поделитесь статусом или фото.\nБлижайшие ноды увидят это в реальном времени.';

  @override
  String get signalEmptyTagline4 =>
      'Станьте активным, чтобы оповестить о своём присутствии.\nБез интернета, напрямую между устройствами.';

  @override
  String get signalEmptyTitleKeyword => 'сигналов';

  @override
  String get signalEmptyTitlePrefix => 'Нет активных ';

  @override
  String get signalEmptyTitleSuffix => ' рядом';

  @override
  String get signalEnableGpsOrFixedPosition =>
      'Устройство ещё не определило местоположение. Включите GPS или задайте фиксированную позицию.';

  @override
  String get signalExpiredBadge => 'Истёк';

  @override
  String get signalFaded => 'Угас';

  @override
  String get signalFadesIn => 'Угаснет через';

  @override
  String signalFadesInDays(int days) {
    return 'Угаснет через $daysд';
  }

  @override
  String signalFadesInHours(int hours) {
    return 'Угаснет через $hoursч';
  }

  @override
  String signalFadesInMinutes(int minutes) {
    return 'Угаснет через $minutesм';
  }

  @override
  String signalFadesInMinutesSeconds(int minutes, int seconds) {
    return 'Угаснет через $minutesм $secondsс';
  }

  @override
  String signalFadesInSeconds(int seconds) {
    return 'Угаснет через $secondsс';
  }

  @override
  String get signalFallbackContent => 'Сигнал';

  @override
  String signalFileTooLarge(int size) {
    return 'Файл слишком большой. Передача по сети ограничена $size КБ.';
  }

  @override
  String get signalFileTransferFailed => 'Не удалось начать передачу файла';

  @override
  String get signalFileTransfers => 'Передача файлов';

  @override
  String get signalFilterAll => 'Все';

  @override
  String get signalFilterExpiring => 'Истекающие';

  @override
  String get signalFilterHidden => 'Скрытые';

  @override
  String get signalFilterLocation => 'Местоположение';

  @override
  String get signalFilterMedia => 'Медиа';

  @override
  String get signalFilterMesh => 'Mesh';

  @override
  String get signalFilterNearby => 'Рядом';

  @override
  String get signalFilterReplies => 'Ответы';

  @override
  String get signalFilterSaved => 'Сохранённые';

  @override
  String get signalFitAllSignals => 'Показать все сигналы';

  @override
  String get signalGetLocationFailed => 'Не удалось получить местоположение';

  @override
  String get signalGoActive => 'Стать активным';

  @override
  String get signalGoActiveAction => 'Стать активным';

  @override
  String get signalHasFaded => 'Этот сигнал угас';

  @override
  String get signalHelp => 'Помощь';

  @override
  String get signalHidden => 'Сигнал скрыт';

  @override
  String get signalHide => 'Скрыть';

  @override
  String signalHopSingular(int count) {
    return '$count хоп';
  }

  @override
  String signalHopsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хопа',
      many: '$count хопов',
      few: '$count хопа',
      one: '1 хоп',
    );
    return '$_temp0';
  }

  @override
  String signalHopsPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хопа',
      many: '$count хопов',
      few: '$count хопа',
      one: '1 хоп',
    );
    return '$_temp0';
  }

  @override
  String get signalImageBlockedSingular =>
      'Изображение нарушает правила контента и было заблокировано';

  @override
  String signalImagesAddedCount(int passedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      passedCount,
      locale: localeName,
      other: 'Добавлено $passedCount изображения',
      many: 'Добавлено $passedCount изображений',
      few: 'Добавлено $passedCount изображения',
      one: 'Добавлено 1 изображение',
    );
    return '$_temp0';
  }

  @override
  String signalImagesBlockedAndAdded(int failedCount, int passedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      failedCount,
      locale: localeName,
      other: 'Заблокировано $failedCount изображения',
      many: 'Заблокировано $failedCount изображений',
      few: 'Заблокировано $failedCount изображения',
      one: 'Заблокировано 1 изображение',
    );
    return '$_temp0, добавлено $passedCount';
  }

  @override
  String signalImagesBlockedPlural(int failedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      failedCount,
      locale: localeName,
      other: '$failedCount изображения заблокированы',
      many: '$failedCount изображений заблокировано',
      few: '$failedCount изображения заблокированы',
      one: '1 изображение заблокировано',
    );
    return '$_temp0 правилами контента';
  }

  @override
  String get signalImagesHiddenOffline =>
      'Изображения скрыты в автономном режиме. Они вернутся при подключении к сети.';

  @override
  String get signalImagesRequireInternet =>
      'Изображения требуют интернета. Изображения удалены.';

  @override
  String get signalImagesRestored => 'Изображения восстановлены!';

  @override
  String get signalIntentLabel => 'Цель';

  @override
  String get signalIosAirplaneModeWarning =>
      'Режим полёта на iOS может приостанавливать BLE-трафик сети даже при наличии подключения. Если сигналы перестали поступать, отключите режим полёта или переключите Bluetooth.';

  @override
  String get signalKeepEditing => 'Продолжить редактирование';

  @override
  String get signalLegendFiveMin => '< 5 мин';

  @override
  String get signalLegendOverTwoHrs => '> 2 ч';

  @override
  String get signalLegendThirtyMin => '< 30 мин';

  @override
  String get signalLegendTwoHrs => '< 2 ч';

  @override
  String get signalLetOthersKnowIntent => 'Сообщите другим, зачем вы активны';

  @override
  String get signalLoadingComments => 'Загрузка комментариев...';

  @override
  String get signalLocal => 'Локальный';

  @override
  String get signalLocalBadge => 'Локальный';

  @override
  String get signalLocalBadgeGallery => 'Локальный';

  @override
  String get signalLocationBadge => 'Местоположение';

  @override
  String signalLocationPrivacyNote(int radiusMeters) {
    return 'Местоположение сигнала использует позицию устройства в сети, округлённую до ~$radiusMetersм.';
  }

  @override
  String get signalLocationUnavailableSent =>
      'Местоположение недоступно, сигнал отправлен без координат.';

  @override
  String signalMaxFileSize(int size) {
    return 'Макс. $size КБ';
  }

  @override
  String signalMaxImagesAllowed(int maxImages) {
    String _temp0 = intl.Intl.pluralLogic(
      maxImages,
      locale: localeName,
      other: '$maxImages изображения',
      many: '$maxImages изображений',
      few: '$maxImages изображения',
      one: '1 изображение',
    );
    return 'Максимум $_temp0';
  }

  @override
  String get signalMeshOnlyDebugBanner =>
      'Включён режим отладки (только Mesh). Сигналы используют локальную БД и только сеть.';

  @override
  String get signalMeshOnlyDebugCloudDisabled =>
      'Включён режим отладки (только Mesh). Облачные функции отключены.';

  @override
  String get signalNoCommentsYet => 'Комментариев пока нет';

  @override
  String get signalNoDeviceConnectedTooltip => 'Устройство не подключено';

  @override
  String get signalNoDeviceLocation =>
      'Местоположение подключённого устройства недоступно';

  @override
  String get signalNoFilterMatch => 'Нет сигналов, соответствующих фильтру';

  @override
  String get signalNoIntent => 'Цель не указана';

  @override
  String get signalNoLocationDescription =>
      'Сигналы будут отображаться здесь, когда они содержат GPS-координаты';

  @override
  String get signalNoLocationTitle => 'Нет сигналов с местоположением';

  @override
  String get signalNoSignals => 'Нет сигналов';

  @override
  String get signalOfflineCloudUnavailable =>
      'Автономный режим: изображения и облачные функции недоступны.';

  @override
  String signalOnMapCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count на карте',
      many: '$count на карте',
      few: '$count на карте',
      one: '1 на карте',
    );
    return '$_temp0';
  }

  @override
  String get signalOriginCloud => 'Облако';

  @override
  String get signalOriginMesh => 'Mesh';

  @override
  String signalPeopleActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count активного пользователя',
      many: '$count активных пользователей',
      few: '$count активных пользователя',
      one: '1 активный пользователь',
    );
    return '$_temp0';
  }

  @override
  String get signalProcessingImage => 'Обработка изображения...';

  @override
  String get signalProfile => 'Профиль';

  @override
  String get signalRemoveLocation => 'Удалить местоположение';

  @override
  String get signalRemoveVoteFailed => 'Не удалось отменить голос';

  @override
  String get signalRemovedFromSaved => 'Удалено из сохранённых';

  @override
  String get signalReplyAction => 'Ответить';

  @override
  String signalReplyWithCount(int count) {
    return 'Ответить ($count)';
  }

  @override
  String signalReplyingTo(String author) {
    return 'Ответ $author';
  }

  @override
  String get signalReport => 'Пожаловаться';

  @override
  String get signalReportCopyright => 'Нарушение авторских прав';

  @override
  String signalReportFailed(String error) {
    return 'Не удалось отправить жалобу: $error';
  }

  @override
  String get signalReportHarassment => 'Преследование или травля';

  @override
  String get signalReportNudity => 'Откровенный или сексуальный контент';

  @override
  String get signalReportOther => 'Другое';

  @override
  String get signalReportSpam => 'Спам или дезинформация';

  @override
  String get signalReportSubmitted => 'Жалоба отправлена. Спасибо.';

  @override
  String get signalReportViolence => 'Насилие или опасный контент';

  @override
  String get signalRespondToSignalHint => 'Ответьте на этот сигнал...';

  @override
  String get signalRestore => 'Восстановить';

  @override
  String get signalRestored => 'Сигнал восстановлен';

  @override
  String get signalRetrievingDeviceLocation =>
      'Получение местоположения устройства...';

  @override
  String get signalSaved => 'Сигнал сохранён';

  @override
  String get signalSavedBadge => 'Сохранён';

  @override
  String get signalSearchHint => 'Поиск сигналов';

  @override
  String signalSeenCount(String formattedCount) {
    return 'Просмотрено $formattedCount';
  }

  @override
  String get signalSelectUpToFourPhotos => 'Выберите до 4 фотографий';

  @override
  String get signalSendASignal => 'Отправить сигнал...';

  @override
  String get signalSendButton => 'Отправить сигнал';

  @override
  String get signalSendResponseFailed => 'Не удалось отправить ответ';

  @override
  String get signalSendSignal => 'Отправить сигнал';

  @override
  String get signalSending => 'Отправка...';

  @override
  String get signalSendingLabel => 'Отправка...';

  @override
  String get signalSent => 'Сигнал отправлен';

  @override
  String get signalSettings => 'Настройки';

  @override
  String get signalShortStatusHint => 'например, «На тропе у вершины»';

  @override
  String get signalShortStatusOptional => 'Краткий статус (необязательно)';

  @override
  String get signalShowAll => 'Показать все сигналы';

  @override
  String get signalSignIn => 'Войти';

  @override
  String get signalSignInForCloudFeatures =>
      'Войдите, чтобы включить изображения и облачные функции.';

  @override
  String get signalSignInForImagesAndComments =>
      'Войдите для доступа к изображениям и комментариям';

  @override
  String get signalSignInRequiredToComment =>
      'Для комментирования необходимо войти';

  @override
  String get signalSignInToViewMedia =>
      'Войдите, чтобы просмотреть прикреплённые медиафайлы';

  @override
  String get signalSignInToVote => 'Войдите, чтобы голосовать за ответы';

  @override
  String signalSignalsNearbyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сигнала рядом',
      many: '$count сигналов рядом',
      few: '$count сигнала рядом',
      one: '1 сигнал рядом',
    );
    return '$_temp0';
  }

  @override
  String get signalSomeone => 'Кто-то';

  @override
  String get signalSortByProximity => 'По расстоянию';

  @override
  String get signalSortClosest => 'Ближайшие';

  @override
  String get signalSortExpiring => 'Истекающие';

  @override
  String get signalSortExpiringSoon => 'Скоро истекут';

  @override
  String get signalSortMostRecent => 'Самые новые';

  @override
  String get signalSortNewest => 'Новейшие';

  @override
  String get signalSwipeSave => 'Сохранить';

  @override
  String get signalSwipeUnsave => 'Убрать из сохранённых';

  @override
  String get signalSyncingMedia => 'Синхронизация медиа';

  @override
  String get signalTakePhoto => 'Сделать фото';

  @override
  String get signalTapToSet => 'Нажмите для установки';

  @override
  String get signalTapToView => 'Нажмите для просмотра';

  @override
  String get signalTemporaryBanner =>
      'Сигналы временны. Они угасают автоматически и существуют только пока активны.';

  @override
  String signalTimeDaysAgo(int days) {
    return '$daysд назад';
  }

  @override
  String signalTimeHoursAgo(int hours) {
    return '$hoursч назад';
  }

  @override
  String get signalTimeJustNow => 'Только что';

  @override
  String signalTimeMinutesAgo(int minutes) {
    return '$minutesм назад';
  }

  @override
  String get signalTimeNowCompact => 'сейчас';

  @override
  String signalTimeWeeksAgo(int weeks) {
    return '$weeksн назад';
  }

  @override
  String signalTtlDaysLeft(int days) {
    return 'Осталось $daysд';
  }

  @override
  String get signalTtlExpired => 'Истёк';

  @override
  String signalTtlHoursLeft(int hours) {
    return 'Осталось $hoursч';
  }

  @override
  String signalTtlMinutesLeft(int minutes) {
    return 'Осталось $minutesм';
  }

  @override
  String signalTtlSecondsLeft(int seconds) {
    return 'Осталось $secondsс';
  }

  @override
  String get signalUnknownAuthor => 'Неизвестный';

  @override
  String get signalUseCamera => 'Использовать камеру';

  @override
  String get signalValidateImagesFailed => 'Не удалось проверить изображения';

  @override
  String signalValidatingImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изображений',
      many: '$count изображений',
      few: '$count изображений',
      one: '1 изображения',
    );
    return 'Проверка $_temp0...';
  }

  @override
  String get signalViewButton => 'Просмотреть';

  @override
  String get signalViewGallery => 'Открыть галерею';

  @override
  String get signalViewGrid => 'Сетка';

  @override
  String get signalViewList => 'Список';

  @override
  String get signalViewLocation => 'Посмотреть местоположение';

  @override
  String get signalViewMap => 'Карта';

  @override
  String get signalVoteFailed => 'Не удалось отправить голос';

  @override
  String get signalWhatAreYouSignaling => 'Что вы сигналите?';

  @override
  String get signalWhyReportComment =>
      'Почему вы жалуетесь на этот комментарий?';

  @override
  String get signalWhyReportSignal => 'Почему вы жалуетесь на этот сигнал?';

  @override
  String get signalWriteReplyHint => 'Написать ответ...';

  @override
  String get signalYouBadge => 'вы';

  @override
  String get signalYourIntent => 'Ваша цель';

  @override
  String get signalYourResponsibility => 'Ваша ответственность';

  @override
  String get signalsFadeAutomatically =>
      'Сигналы угасают автоматически. Видно только то, что ещё активно.';

  @override
  String get signalsFeedTitle => 'Сигналы';

  @override
  String get signalsPanelTitle => 'Сигналы';

  @override
  String get socialAboutSensitiveContent => 'О контенте для взрослых';

  @override
  String get socialAccountGoodStanding => 'Аккаунт в порядке';

  @override
  String get socialAccountGoodStandingDesc =>
      'У вас нет активных предупреждений или нарушений.';

  @override
  String get socialAccountGoodStandingLabel => 'В порядке';

  @override
  String get socialAccountMaxStrikes => 'Максимальное число нарушений';

  @override
  String get socialAccountRecentActivity => 'Недавняя активность';

  @override
  String get socialAccountStatusActive => 'Активен';

  @override
  String socialAccountStatusError(String error) {
    return 'Ошибка загрузки статуса: $error';
  }

  @override
  String get socialAccountStatusLabel => 'Статус аккаунта';

  @override
  String get socialAccountStatusTitle => 'Статус аккаунта';

  @override
  String get socialAccountStrikeMeter => 'Счётчик нарушений';

  @override
  String get socialAccountStrikes => 'Нарушения';

  @override
  String get socialAccountSuspended => 'Заблокирован';

  @override
  String get socialAccountSuspendedTitle => 'Аккаунт заблокирован';

  @override
  String get socialAccountSuspendedMessage =>
      'Ваш аккаунт в данный момент заблокирован. Вы не можете публиковать посты или комментарии до снятия блокировки.';

  @override
  String get socialAccountWarningStrikesActive =>
      'Предупреждение: есть активные нарушения';

  @override
  String get socialAccountWarnings => 'Предупреждения';

  @override
  String get socialAccountWarningsActive => 'Активные предупреждения';

  @override
  String get socialActiveStrikes => 'Активные нарушения';

  @override
  String get socialActiveWarnings => 'Активные предупреждения';

  @override
  String get socialActivityClearAll => 'Очистить всё';

  @override
  String get socialActivityClearConfirmLabel => 'Очистить';

  @override
  String get socialActivityClearConfirmMessage =>
      'Все записи активности будут удалены. Это действие нельзя отменить.';

  @override
  String get socialActivityClearConfirmTitle => 'Очистить всю активность?';

  @override
  String get socialActivityCommentedSignal => ' прокомментировал(а) ваш сигнал';

  @override
  String get socialActivityErrorLoading => 'Не удалось загрузить активность';

  @override
  String get socialActivityGroupEarlier => 'Ранее';

  @override
  String get socialActivityGroupThisMonth => 'В этом месяце';

  @override
  String get socialActivityGroupThisWeek => 'На этой неделе';

  @override
  String get socialActivityGroupToday => 'Сегодня';

  @override
  String get socialActivityGroupYesterday => 'Вчера';

  @override
  String get socialActivityInteracted =>
      ' взаимодействовал(а) с вашим контентом';

  @override
  String get socialActivityLikedSignal => ' оценил(а) ваш сигнал';

  @override
  String get socialActivityLoadingSignal => 'Загрузка сигнала...';

  @override
  String get socialActivityMarkAllRead => 'Отметить всё как прочитанное';

  @override
  String get socialActivityRepliedComment => ' ответил(а) на ваш комментарий';

  @override
  String get socialActivitySignalNotFound => 'Сигнал не найден';

  @override
  String get socialActivityTagline1 =>
      'Активности пока нет.\nВзаимодействия с вашими публикациями отображаются здесь.';

  @override
  String get socialActivityTagline2 =>
      'Лайки, комментарии, подписки — всё в одном месте.\nОпубликуйте что-нибудь, чтобы начать.';

  @override
  String get socialActivityTagline3 =>
      'Ваша социальная жизнь начинается здесь.\nПодключайтесь к другим, чтобы видеть активность.';

  @override
  String get socialActivityTagline4 =>
      'Пока ничего. Активность появится, когда другие\nбудут взаимодействовать с вашим контентом.';

  @override
  String get socialActivityTitle => 'Активность';

  @override
  String get socialActivityTitleKeyword => 'активность';

  @override
  String get socialActivityTitlePrefix => 'Нет ';

  @override
  String get socialActivityTitleSuffix => ' пока';

  @override
  String get socialAdd => 'Добавить';

  @override
  String get socialAddBanner => 'Добавить баннер';

  @override
  String get socialAlbumAll => 'Все альбомы';

  @override
  String get socialAlbumFavorites => 'Избранное';

  @override
  String get socialAlbumRecents => 'Недавние';

  @override
  String get socialAlbumVideos => 'Видео';

  @override
  String get socialAppealDecision => 'Обжаловать решение';

  @override
  String get socialBanReasonHarassment => 'Преследование / Травля';

  @override
  String get socialBanReasonHateSpeech =>
      'Разжигание ненависти / Дискриминация';

  @override
  String get socialBanReasonIllegal => 'Незаконная деятельность';

  @override
  String get socialBanReasonImpersonation => 'Самозванство';

  @override
  String get socialBanReasonOther => 'Другое нарушение';

  @override
  String get socialBanReasonPornography => 'Порнография / Сексуальный контент';

  @override
  String get socialBanReasonSpam => 'Спам / Мошенничество';

  @override
  String get socialBanReasonViolence => 'Насилие / Угрозы';

  @override
  String get socialBanUserAndDelete => 'Заблокировать пользователя и удалить';

  @override
  String get socialBanUserButton => 'Заблокировать пользователя';

  @override
  String socialBanUserFailed(String error) {
    return 'Не удалось заблокировать пользователя: $error';
  }

  @override
  String socialBannerRemoveFailed(String error) {
    return 'Не удалось удалить баннер: $error';
  }

  @override
  String get socialBannerRemoved => 'Баннер удалён';

  @override
  String get socialBannerUpdated => 'Баннер обновлён';

  @override
  String socialBannerUploadFailed(String error) {
    return 'Не удалось загрузить баннер: $error';
  }

  @override
  String get socialBlock => 'Заблокировать';

  @override
  String get socialBlockUser => 'Заблокировать пользователя';

  @override
  String get socialBlockUserConfirm =>
      'Вы больше не будете видеть публикации этого пользователя.';

  @override
  String get socialBlurSensitiveDesc =>
      'Размывать потенциально чувствительные изображения и видео до нажатия для просмотра';

  @override
  String get socialBlurSensitiveMedia => 'Размывать чувствительный контент';

  @override
  String get socialCancel => 'Отмена';

  @override
  String get socialCannotIdentifyUser =>
      'Невозможно определить пользователя для блокировки';

  @override
  String get socialChangeBanner => 'Изменить баннер';

  @override
  String get socialClose => 'Закрыть';

  @override
  String socialCommentActionFailed(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get socialCommentDeleteConfirm =>
      'Вы уверены, что хотите удалить этот комментарий?';

  @override
  String socialCommentDeleteFailed(String error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String get socialCommentDeleteTitle => 'Удалить комментарий';

  @override
  String get socialCommentHintAdd => 'Добавить комментарий...';

  @override
  String get socialCommentHintReply => 'Написать ответ...';

  @override
  String get socialCommentReply => 'Ответить';

  @override
  String get socialCommentReported => 'Жалоба на комментарий отправлена';

  @override
  String get socialCommentUnknown => 'Неизвестно';

  @override
  String get socialComments => 'Комментарии';

  @override
  String get socialCommunityGuidelines => 'Правила сообщества';

  @override
  String get socialConfirm => 'Подтвердить';

  @override
  String get socialConnectionsTitle => 'Контакты';

  @override
  String get socialContactSupport => 'Вопросы? Обратитесь в поддержку';

  @override
  String get socialContactSupportButton => 'Обратиться в поддержку';

  @override
  String get socialContentApproved => 'Контент одобрен';

  @override
  String get socialContentIdNotFound => 'Идентификатор контента не найден';

  @override
  String get socialContentRemoved => 'Контент удалён';

  @override
  String get socialContentType => 'Тип контента';

  @override
  String get socialCreatePostAction => 'Создать публикацию';

  @override
  String get socialCreatePostAddImage => 'Добавить изображение';

  @override
  String get socialCreatePostAddLocation => 'Добавить местоположение';

  @override
  String get socialCreatePostButton => 'Опубликовать';

  @override
  String get socialCreatePostCreated => 'Публикация создана!';

  @override
  String get socialCreatePostCurrentDesc => 'Поделиться координатами GPS';

  @override
  String get socialCreatePostCurrentLocation => 'Текущее местоположение';

  @override
  String get socialCreatePostDiscardMsgDraft => 'Ваш черновик будет потерян.';

  @override
  String get socialCreatePostDiscardMsgImages =>
      'Загруженные изображения будут удалены.';

  @override
  String get socialCreatePostDiscardTitle => 'Отменить публикацию?';

  @override
  String get socialCreatePostEnterLocation => 'Введите местоположение';

  @override
  String get socialCreatePostEnterManually => 'Ввести местоположение вручную';

  @override
  String socialCreatePostFailed(String error) {
    return 'Не удалось создать публикацию: $error';
  }

  @override
  String get socialCreatePostHint => 'Что происходит в сети?';

  @override
  String socialCreatePostImageCount(int count, int max) {
    return '$count/$max изображений';
  }

  @override
  String get socialCreatePostImageViolation =>
      'Одно или несколько изображений нарушают правила контента.';

  @override
  String get socialCreatePostLocationDenied =>
      'Доступ к местоположению запрещён';

  @override
  String get socialCreatePostLocationHint => 'например, Москва';

  @override
  String get socialCreatePostLocationLabel => 'Местоположение';

  @override
  String get socialCreatePostLocationSheetTitle => 'Добавить местоположение';

  @override
  String get socialCreatePostManualDesc => 'Введите название места';

  @override
  String socialCreatePostMaxImages(int max) {
    return 'Максимально допустимо $max изображений';
  }

  @override
  String get socialCreatePostNoNodes =>
      'Нет доступных нод. Сначала подключитесь к сети.';

  @override
  String socialCreatePostNodeLabel(String nodeId) {
    return 'Нода $nodeId';
  }

  @override
  String get socialCreatePostSignIn => 'Войдите, чтобы создавать публикации';

  @override
  String get socialCreatePostTagNode => 'Отметить нода';

  @override
  String get socialCreatePostTagNodeTitle => 'Отметить нода';

  @override
  String get socialCreatePostTitle => 'Создать публикацию';

  @override
  String get socialCreatePostUseCurrent =>
      'Использовать текущее местоположение';

  @override
  String get socialCreateStoryCamera => 'Камера';

  @override
  String get socialCreateStoryCloseFriends => 'Близкие друзья';

  @override
  String get socialCreateStoryDelete => 'Удалить';

  @override
  String get socialCreateStoryDragInstructions =>
      'Перетащите для перемещения • Сведите пальцы для изменения размера • Долгое нажатие для удаления';

  @override
  String get socialCreateStoryEdit => 'Редактировать';

  @override
  String get socialCreateStoryFailed => 'Не удалось создать историю';

  @override
  String get socialCreateStoryFollowers => 'Подписчики';

  @override
  String socialCreateStoryItemsCount(int count) {
    return '$count элементов';
  }

  @override
  String get socialCreateStoryLinkNode => 'Привязать ноду';

  @override
  String get socialCreateStoryLocationFailed =>
      'Не удалось определить местоположение';

  @override
  String get socialCreateStoryLocationRequired =>
      'Требуется разрешение на доступ к местоположению';

  @override
  String get socialCreateStoryPublic => 'Публично';

  @override
  String get socialCreateStoryShared => 'История опубликована!';

  @override
  String get socialCreateStorySignIn => 'Войдите, чтобы создавать истории';

  @override
  String get socialCreateStoryTitle => 'Добавить в историю';

  @override
  String get socialCreateStoryTypeSomething => 'Напишите что-нибудь...';

  @override
  String get socialCreateStoryUntitledAlbum => 'Альбом без названия';

  @override
  String get socialDate => 'Дата';

  @override
  String get socialDefault => 'По умолчанию';

  @override
  String get socialDelete => 'Удалить';

  @override
  String get socialDeleteComment => 'Удалить комментарий';

  @override
  String get socialDeleteCommentConfirm =>
      'Вы уверены, что хотите удалить этот комментарий?';

  @override
  String get socialDeletePost => 'Удалить публикацию';

  @override
  String get socialDeletePostConfirm =>
      'Вы уверены, что хотите удалить эту публикацию?';

  @override
  String get socialDeleteStory => 'Удалить историю';

  @override
  String get socialDeleteStoryConfirm =>
      'Эта история будет удалена без возможности восстановления.';

  @override
  String socialDeleteType(String type) {
    return 'Удалить $type';
  }

  @override
  String socialDeleteTypeConfirm(String type) {
    return 'Это действие навсегда удалит пожалованный объект типа $type. Продолжить?';
  }

  @override
  String get socialDiscard => 'Отменить';

  @override
  String socialDiscordCopied(String username) {
    return 'Имя пользователя Discord скопировано: $username';
  }

  @override
  String get socialDismiss => 'Закрыть';

  @override
  String get socialDisplayOptions => 'Параметры отображения';

  @override
  String get socialDone => 'Готово';

  @override
  String get socialEditProfile => 'Редактировать профиль';

  @override
  String get socialEmailCopied =>
      'Электронная почта скопирована в буфер обмена';

  @override
  String get socialEmptyPostsTagline1 =>
      'Делитесь фото и историями о ваших приключениях в сети.';

  @override
  String get socialEmptyPostsTagline2 =>
      'Публикуйте о настройке нод, тестах дальности и открытиях.';

  @override
  String get socialEmptyPostsTagline3 =>
      'Сообщество сети ждёт, чтобы увидеть, что вы создаёте.';

  @override
  String get socialEmptyPostsTagline4 =>
      'Документируйте свои приключения и делитесь ими с сетью.';

  @override
  String get socialErrorLoadingReports => 'Ошибка загрузки жалоб';

  @override
  String get socialErrorLoadingViewers => 'Ошибка загрузки просмотров';

  @override
  String socialErrorWithDetails(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get socialExpires => 'Истекает';

  @override
  String socialFailedToBlock(String error) {
    return 'Не удалось заблокировать пользователя: $error';
  }

  @override
  String socialFailedToDelete(String error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String socialFailedToGetLocation(String error) {
    return 'Не удалось получить местоположение: $error';
  }

  @override
  String socialFailedToReport(String error) {
    return 'Не удалось пожаловаться: $error';
  }

  @override
  String socialFailedToReportStory(String error) {
    return 'Не удалось пожаловаться на историю: $error';
  }

  @override
  String get socialFailedToUpdateLike =>
      'Не удалось обновить отметку «Нравится»';

  @override
  String socialFailedToUploadImage(String error) {
    return 'Не удалось загрузить изображение: $error';
  }

  @override
  String get socialFeedLocationFallback => 'Местоположение';

  @override
  String get socialFilterLevelLess => 'Меньше';

  @override
  String get socialFilterLevelLessDesc =>
      'Вы можете видеть контент, который может расстроить или оскорбить. Этот параметр склоняется к показу большего количества контента.';

  @override
  String get socialFilterLevelStandard => 'Стандартный';

  @override
  String get socialFilterLevelStandardDesc =>
      'Контент, который может расстроить или оскорбить, фильтруется. Вы всё же можете видеть некоторый пограничный контент.';

  @override
  String get socialFollow => 'Подписаться';

  @override
  String socialFollowActionFailed(String error) {
    return 'Ошибка: $error';
  }

  @override
  String socialFollowFailed(String error) {
    return 'Не удалось обновить подписку: $error';
  }

  @override
  String get socialFollowRequestAcceptFailed => 'Не удалось принять запрос';

  @override
  String socialFollowRequestAccepted(String name) {
    return 'Запрос от $name принят';
  }

  @override
  String get socialFollowRequestDeclineFailed => 'Не удалось отклонить запрос';

  @override
  String socialFollowRequestDeclined(String name) {
    return 'Запрос от $name отклонён';
  }

  @override
  String get socialFollowRequestsEmpty => 'Нет ожидающих запросов';

  @override
  String get socialFollowRequestsEmptyDesc =>
      'Когда кто-то запросит подписку на вас, это появится здесь.';

  @override
  String socialFollowRequestsError(String error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String get socialFollowRequestsTitle => 'Запросы на подписку';

  @override
  String socialFollowersError(String error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String get socialFollowing => 'Подписки';

  @override
  String get socialGuidelineNoExplicit =>
      'Запрещён откровенный или контент для взрослых';

  @override
  String get socialGuidelineNoHarassment =>
      'Запрещены преследование, угрозы и разжигание ненависти';

  @override
  String get socialGuidelineNoSpam =>
      'Запрещены спам, мошенничество и вводящий в заблуждение контент';

  @override
  String get socialGuidelinesWarning =>
      'Предупреждение о нарушении правил сообщества';

  @override
  String get socialHubSignIn =>
      'Войдите, чтобы получить доступ к разделу «Социальный»';

  @override
  String get socialHubSignInDesc =>
      'Создавайте публикации, подписывайтесь на пользователей и общайтесь с сообществом сети.';

  @override
  String get socialHubTitle => 'Социальный';

  @override
  String get socialIUnderstand => 'Понятно';

  @override
  String get socialImageBlockedByModeration =>
      'Изображение заблокировано модерацией';

  @override
  String get socialInvalidNodeId => 'Недействительный идентификатор ноды';

  @override
  String socialJoined(String date) {
    return 'Присоединился $date';
  }

  @override
  String get socialLike => 'Нравится';

  @override
  String get socialLiked => 'Понравилось';

  @override
  String get socialLikePlural => 'отметок «Нравится»';

  @override
  String get socialLikeSingular => 'отметка «Нравится»';

  @override
  String get socialLinkNodeHint => 'Привяжите нода сети к следующей публикации';

  @override
  String get socialLocationFallback => 'Местоположение';

  @override
  String get socialModerationAdditionalNotes =>
      'Дополнительные заметки (необязательно)';

  @override
  String get socialModerationApprove => 'Одобрить';

  @override
  String get socialModerationApproved => 'Контент одобрен';

  @override
  String get socialModerationErrorLoading => 'Ошибка загрузки очереди';

  @override
  String get socialModerationNoPending => 'Нет элементов на рассмотрении';

  @override
  String socialModerationNoStatus(String status) {
    return 'Нет элементов со статусом «$status»';
  }

  @override
  String get socialModerationQueueTitle => 'Очередь модерации';

  @override
  String get socialModerationReasonHarassment => 'Преследование или травля';

  @override
  String get socialModerationReasonHateSpeech =>
      'Разжигание ненависти или дискриминация';

  @override
  String get socialModerationReasonIP =>
      'Нарушение прав интеллектуальной собственности';

  @override
  String get socialModerationReasonNudity =>
      'Обнажённость или сексуальный контент';

  @override
  String get socialModerationReasonOther => 'Другое нарушение правил';

  @override
  String get socialModerationReasonSpam =>
      'Спам или вводящий в заблуждение контент';

  @override
  String get socialModerationReasonViolence => 'Насилие или опасный контент';

  @override
  String get socialModerationReject => 'Отклонить';

  @override
  String get socialModerationRejected => 'Контент отклонён';

  @override
  String get socialModerationRejectionReason => 'Причина отклонения';

  @override
  String socialModerationReviewedBy(String reviewedBy) {
    return 'Проверено: $reviewedBy';
  }

  @override
  String get socialModerationTabApproved => 'Одобрено';

  @override
  String get socialModerationTabPending => 'На рассмотрении';

  @override
  String get socialModerationTabRejected => 'Отклонено';

  @override
  String socialModerationUserLabel(String userId) {
    return 'Пользователь: $userId';
  }

  @override
  String get socialNext => 'Далее';

  @override
  String get socialNoAlbumsFound => 'Альбомы не найдены';

  @override
  String get socialNoCommentsYet => 'Комментариев пока нет. Будьте первым!';

  @override
  String get socialNoContent => 'Нет контента';

  @override
  String get socialNoFollowersYet => 'Подписчиков пока нет';

  @override
  String get socialNoLocationPosts => 'Нет публикаций с геолокацией';

  @override
  String get socialNoNodePosts => 'Нет публикаций от нод';

  @override
  String socialNoPendingFilterReports(String filter) {
    return 'Нет ожидающих жалоб по фильтру «$filter»';
  }

  @override
  String get socialNoPendingReports => 'Нет ожидающих жалоб';

  @override
  String get socialNoPhotoPosts => 'Нет фотопубликаций';

  @override
  String get socialNoPosts => 'Нет публикаций';

  @override
  String get socialNoPostsYet => 'Публикаций пока нет';

  @override
  String get socialNoRecentActivity => 'Нет недавней активности';

  @override
  String get socialNoSuggestions => 'Нет доступных предложений';

  @override
  String get socialNoUsersFound => 'Пользователи не найдены';

  @override
  String get socialNoViewsYet => 'Просмотров пока нет';

  @override
  String socialNodeLabel(String nodeId) {
    return 'Нода $nodeId';
  }

  @override
  String get socialNotFollowingAnyone => 'Вы пока ни на кого не подписаны';

  @override
  String socialNoticesCount(int current, int total) {
    return '$current из $total уведомлений';
  }

  @override
  String get socialOK => 'ОК';

  @override
  String get socialOnline => 'В сети';

  @override
  String get socialOpenSettings => 'Открыть настройки';

  @override
  String get socialPermanentlyBanned => 'Заблокирован навсегда';

  @override
  String get socialPhotoAccessDesc =>
      'Для создания историй нам необходим доступ к вашей фотобиблиотеке.';

  @override
  String get socialPhotoAccessTitle => 'Разрешить доступ к фотографиям';

  @override
  String get socialPostCardLocationFallback => 'Местоположение';

  @override
  String socialPostCardNodeLabel(String nodeId) {
    return 'Нода $nodeId';
  }

  @override
  String get socialPostCardUnknownUser => 'Неизвестный пользователь';

  @override
  String get socialPostDeleted => 'Публикация удалена';

  @override
  String get socialPostDetailTitle => 'Публикация';

  @override
  String get socialPostNotFound => 'Публикация не найдена';

  @override
  String get socialPostNotFoundForComment =>
      'Публикация для этого комментария не найдена';

  @override
  String get socialPrivateAccount => 'Этот аккаунт закрытый';

  @override
  String socialPrivateAccountDesc(String name) {
    return 'Подпишитесь на $name, чтобы видеть публикации и подключённые устройства.';
  }

  @override
  String get socialProfileBlockLabel => 'Заблокировать';

  @override
  String get socialProfileLoadFailed => 'Не удалось загрузить профиль';

  @override
  String get socialProfileNotFound => 'Профиль не найден';

  @override
  String get socialProfileNotFoundDesc =>
      'Этот профиль мог быть удалён или временно недоступен.';

  @override
  String get socialProfileReportLabel => 'Пожаловаться';

  @override
  String get socialProfileShareLabel => 'Поделиться профилем';

  @override
  String get socialReason => 'Причина';

  @override
  String get socialRecentFailed =>
      'Не удалось загрузить недавних пользователей';

  @override
  String get socialRecentlyActive => 'Недавно активен';

  @override
  String get socialRejectDelete => 'Отклонить и удалить';

  @override
  String socialRejectDeleteMsg(String contentType) {
    return 'Это удалит $contentType и вынесет предупреждение пользователю.';
  }

  @override
  String get socialRemoveBanner => 'Удалить баннер';

  @override
  String get socialReply => 'Ответить';

  @override
  String socialReplyingTo(String name) {
    return 'Ответ пользователю $name';
  }

  @override
  String get socialRepeatedViolationsWarning =>
      'Повторные нарушения могут привести к блокировке аккаунта.';

  @override
  String get socialReport => 'Пожаловаться';

  @override
  String get socialReportComment => 'Пожаловаться на комментарий';

  @override
  String get socialReportCommentWhy =>
      'Почему вы жалуетесь на этот комментарий?';

  @override
  String get socialReportDescribeIssue => 'Опишите проблему...';

  @override
  String get socialReportDismissed => 'Жалоба отклонена';

  @override
  String get socialReportPost => 'Пожаловаться на публикацию';

  @override
  String get socialReportPostWhy => 'Почему вы жалуетесь на эту публикацию?';

  @override
  String get socialReportProfileSubmitted => 'Жалоба отправлена';

  @override
  String get socialReportReasonFalseInfo => 'Ложная информация';

  @override
  String get socialReportReasonHarassment => 'Преследование или травля';

  @override
  String get socialReportReasonHateSpeech => 'Язык ненависти';

  @override
  String get socialReportReasonNudity => 'Обнажённость или сексуальный контент';

  @override
  String get socialReportReasonOther => 'Другое';

  @override
  String get socialReportReasonSpam => 'Спам';

  @override
  String get socialReportReasonViolence => 'Насилие или угрозы';

  @override
  String get socialReportStory => 'Пожаловаться на историю';

  @override
  String get socialReportStoryReasonCopyright => 'Нарушение авторских прав';

  @override
  String get socialReportStoryReasonHarassment => 'Преследование или травля';

  @override
  String get socialReportStoryReasonNudity =>
      'Обнажённость или сексуальный контент';

  @override
  String get socialReportStoryReasonOther => 'Другое';

  @override
  String get socialReportStoryReasonSpam => 'Спам или введение в заблуждение';

  @override
  String get socialReportStoryReasonViolence => 'Насилие или опасный контент';

  @override
  String get socialReportStoryWhy => 'Почему вы жалуетесь на эту историю?';

  @override
  String get socialReportSubmitted => 'Жалоба отправлена. Спасибо.';

  @override
  String get socialReportedContentRejected =>
      'Контент отклонён, пользователю вынесено предупреждение';

  @override
  String get socialReportedContentTitle => 'Пожаловавшийся контент';

  @override
  String get socialReportedErrorLoading => 'Ошибка загрузки очереди модерации';

  @override
  String get socialReportedNoFlagged => 'Нет помеченного контента';

  @override
  String get socialReportedNoFlaggedDesc =>
      'Автомодерация не пометила никакой контент';

  @override
  String get socialReportedTabAll => 'Все';

  @override
  String get socialReportedTabAuto => 'Авто';

  @override
  String get socialReportedTabComments => 'Комментарии';

  @override
  String get socialReportedTabPosts => 'Публикации';

  @override
  String get socialReportedTabSigComments => 'Комм. к сигналам';

  @override
  String get socialReportedTabSignals => 'Сигналы';

  @override
  String get socialRequested => 'Запрошено';

  @override
  String get socialRetry => 'Повторить';

  @override
  String socialSearchFailed(String error) {
    return 'Ошибка поиска: $error';
  }

  @override
  String get socialSearchHint => 'Поиск пользователей...';

  @override
  String get socialSearchTitle => 'Поиск';

  @override
  String get socialSearchTooltip => 'Поиск';

  @override
  String get socialSendMessage => 'Отправить сообщение';

  @override
  String get socialSensitiveContentControl =>
      'Управление чувствительным контентом';

  @override
  String get socialSensitiveContentDescription =>
      'Socialmesh использует автоматизированные системы для обнаружения потенциально чувствительного контента. Вы можете настроить отображение такого контента.';

  @override
  String get socialSensitiveContentExplanation =>
      'Управляйте тем, какой контент отображается в вашей ленте. Это влияет на фильтрацию публикаций, сигналов и историй с помощью ИИ-модерации.';

  @override
  String get socialSensitiveContentTitle => 'Чувствительный контент';

  @override
  String get socialSettingsTooltip => 'Настройки';

  @override
  String get socialShare => 'Поделиться';

  @override
  String get socialShareFirstPostKeyword => 'публикацию';

  @override
  String get socialShareFirstPostPrefix => 'Поделитесь своей первой ';

  @override
  String get socialSharePhotoHint =>
      'Поделитесь фотопубликацией, чтобы она отобразилась здесь';

  @override
  String get socialSignIn => 'Войти';

  @override
  String get socialSignInToLikePosts =>
      'Войдите, чтобы ставить отметки «Нравится»';

  @override
  String get socialSignInToUploadImages =>
      'Войдите, чтобы загружать изображения';

  @override
  String get socialSignInSubscriptions => 'Войдите, чтобы управлять подписками';

  @override
  String get socialStatFollower => 'Подписчик';

  @override
  String get socialStatFollowers => 'Подписчики';

  @override
  String get socialStatFollowing => 'Подписки';

  @override
  String get socialStatPost => 'Публикация';

  @override
  String get socialStatPosts => 'Публикации';

  @override
  String get socialStatsBarFollowers => 'Подписчики';

  @override
  String get socialStatsBarFollowing => 'Подписки';

  @override
  String get socialStatsBarPosts => 'Публикации';

  @override
  String get socialStatusFlagged => 'ПОМЕЧЕНО';

  @override
  String get socialStatusPending => 'НА РАССМОТРЕНИИ';

  @override
  String get socialStatusRejected => 'ОТКЛОНЕНО';

  @override
  String get socialStatusStrike => 'НАРУШЕНИЕ';

  @override
  String get socialStatusSuspended => 'ЗАБЛОКИРОВАНО';

  @override
  String get socialStoryBarAdd => 'Добавить';

  @override
  String get socialStoryContentUnavailable => 'Контент недоступен';

  @override
  String socialStoryDeleteFailed(String error) {
    return 'Не удалось удалить историю: $error';
  }

  @override
  String get socialStoryDeleted => 'История удалена';

  @override
  String get socialStoryMayBeRemoved => 'Эта история могла быть удалена';

  @override
  String get socialStoryReported =>
      'Жалоба на историю отправлена. Мы скоро её рассмотрим.';

  @override
  String get socialStoryUserFallback => 'Пользователь';

  @override
  String get socialStrike3Suspension =>
      '3 нарушения приводят к блокировке аккаунта';

  @override
  String get socialStrikeAcknowledge => 'Я понимаю';

  @override
  String get socialStrikeAgainstAccount => 'Нарушение на вашем аккаунте';

  @override
  String socialStrikeContentLabel(String type) {
    return 'Контент: $type';
  }

  @override
  String socialStrikeContentTitle(String typeDisplayName) {
    return 'Контент $typeDisplayName';
  }

  @override
  String socialStrikeError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get socialStrikeNext => 'Далее';

  @override
  String socialStrikeOfTotal(int current, int total) {
    return '$current из $total';
  }

  @override
  String get socialStrikeReasonLabel => 'Причина';

  @override
  String get socialStrikeReceivedStrike =>
      'Вашему аккаунту засчитано нарушение в связи с несоблюдением правил сообщества.';

  @override
  String get socialStrikeReceivedWarning =>
      'Вам вынесено предупреждение. Пожалуйста, ознакомьтесь с правилами сообщества.';

  @override
  String socialStrikeTapReview(int count) {
    return 'У вас $count нарушение(й) — нажмите для просмотра';
  }

  @override
  String get socialStrikesExpireInfo =>
      'Нарушения аннулируются через 90 дней без новых нарушений.';

  @override
  String socialStrikesOnAccount(int count) {
    return '$count активное(ых) нарушение(й) на вашем аккаунте';
  }

  @override
  String get socialSubscribe => 'Подписаться';

  @override
  String get socialSubscribed => 'Подписка оформлена';

  @override
  String socialSubscriptionFailed(String error) {
    return 'Не удалось обновить подписку: $error';
  }

  @override
  String get socialSuggestedForYou => 'Рекомендуем вам';

  @override
  String get socialSuggestionsFailed => 'Не удалось загрузить предложения';

  @override
  String get socialSuspendedContactSupport =>
      'Обратитесь в поддержку, чтобы обжаловать это решение';

  @override
  String socialSuspendedDaysPlural(int n) {
    return '$n дней';
  }

  @override
  String socialSuspendedDaysSingular(int n) {
    return '$n день';
  }

  @override
  String get socialSuspendedDefaultReason =>
      'Ваш аккаунт заблокирован из-за повторных нарушений правил сообщества.';

  @override
  String get socialSuspendedGoBack => 'Назад';

  @override
  String socialSuspendedHoursPlural(int n) {
    return '$n часов';
  }

  @override
  String socialSuspendedHoursSingular(int n) {
    return '$n час';
  }

  @override
  String get socialSuspendedIndefinite => 'Бессрочная блокировка';

  @override
  String get socialSuspendedIndefinitely => 'бессрочно';

  @override
  String get socialSuspendedLabel => 'Заблокирован';

  @override
  String socialSuspendedMinutesPlural(int n) {
    return '$n минут';
  }

  @override
  String socialSuspendedMinutesSingular(int n) {
    return '$n минута';
  }

  @override
  String get socialSuspendedPermanent => 'Аккаунт заблокирован';

  @override
  String socialSuspendedRemaining(String duration) {
    return 'Осталось: $duration';
  }

  @override
  String get socialSuspendedReviewGuidelines =>
      'Ознакомьтесь с правилами сообщества';

  @override
  String get socialSuspendedShortly => 'скоро';

  @override
  String socialSuspendedStrikesCount(int count) {
    return '$count нарушение(й) на вашем аккаунте';
  }

  @override
  String get socialSuspendedTemporary => 'Публикация временно заблокирована';

  @override
  String get socialSuspendedWaitAppeal =>
      'Дождитесь рассмотрения вашей апелляции';

  @override
  String get socialSuspendedWaitPeriod =>
      'Дождитесь окончания срока блокировки';

  @override
  String get socialSuspendedWhatCanIDo => 'Что я могу сделать?';

  @override
  String get socialSuspendedWhyTitle => 'Почему я вижу это?';

  @override
  String get socialSuspensionEnds => 'Блокировка заканчивается';

  @override
  String get socialTabFollowers => 'Подписчики';

  @override
  String get socialTabFollowing => 'Подписки';

  @override
  String get socialTagLocationHint =>
      'Отметьте местоположение в следующей публикации';

  @override
  String socialTimeDaysAgo(int n) {
    return '$nд. назад';
  }

  @override
  String socialTimeHoursAgo(int n) {
    return '$nч. назад';
  }

  @override
  String get socialTimeJustNow => 'Только что';

  @override
  String socialTimeMinutesAgo(int n) {
    return '$nмин. назад';
  }

  @override
  String get socialTryDifferentFilter => 'Попробуйте выбрать другой фильтр';

  @override
  String get socialTryDifferentSearch => 'Попробуйте другой поисковый запрос';

  @override
  String socialTypeDeleted(String type) {
    return '$type удалено';
  }

  @override
  String get socialUnfollow => 'Отписаться';

  @override
  String get socialUnknownUser => 'Неизвестный пользователь';

  @override
  String get socialUnsubscribed => 'Подписка отменена';

  @override
  String get socialUnsuspend => 'Снять блокировку';

  @override
  String socialUnsuspendConfirm(String displayName) {
    return 'Вы уверены, что хотите снять блокировку с $displayName?';
  }

  @override
  String get socialUnsuspendUser => 'Снять блокировку с пользователя';

  @override
  String socialUserBannedAndDeleted(String type) {
    return 'Пользователь заблокирован, $type удалено';
  }

  @override
  String get socialUserBlocked => 'Пользователь заблокирован';

  @override
  String socialUserBlockedName(String name) {
    return '$name заблокирован';
  }

  @override
  String get socialUserFallback => 'Пользователь';

  @override
  String get socialUserUnsuspended => 'Блокировка с пользователя снята';

  @override
  String get socialView => 'Просмотр';

  @override
  String get socialViewLabel => 'просмотр';

  @override
  String get socialViewLocation => 'Посмотреть местоположение';

  @override
  String get socialViewOnMap => 'Открыть на карте';

  @override
  String get socialViewersTitle => 'Зрители';

  @override
  String get socialViewsLabel => 'просмотров';

  @override
  String get socialViolationsDetected => 'Обнаружены нарушения';

  @override
  String get socialVisibilityFollowers => 'Подписчики';

  @override
  String get socialVisibilityFollowersDesc =>
      'Это видят только ваши подписчики';

  @override
  String get socialVisibilityOnlyMe => 'Только я';

  @override
  String get socialVisibilityOnlyMeDesc => 'Эту публикацию видите только вы';

  @override
  String get socialVisibilityPublic => 'Публично';

  @override
  String get socialVisibilityPublicDesc => 'Эту публикацию может видеть любой';

  @override
  String get socialVisibilityWhoCanSee => 'Кто может видеть это?';

  @override
  String socialWarningsOnAccount(int count) {
    return '$count активное(ых) предупреждение(й) на вашем аккаунте';
  }

  @override
  String socialWarningsTapReview(int count) {
    return 'У вас $count предупреждение(й) — нажмите для просмотра';
  }

  @override
  String get socialYourStory => 'Ваша история';

  @override
  String get takAffiliationAssumedFriend => 'Предположительно союзник';

  @override
  String get takAffiliationFriendly => 'Дружественный';

  @override
  String get takAffiliationHostile => 'Враждебный';

  @override
  String get takAffiliationNeutral => 'Нейтральный';

  @override
  String get takAffiliationPending => 'Ожидает определения';

  @override
  String get takAffiliationSuspect => 'Подозрительный';

  @override
  String get takAffiliationUnknown => 'Неизвестный';

  @override
  String get takCompassE => 'В';

  @override
  String get takCompassN => 'С';

  @override
  String get takCompassNE => 'СВ';

  @override
  String get takCompassNW => 'СЗ';

  @override
  String get takCompassS => 'Ю';

  @override
  String get takCompassSE => 'ЮВ';

  @override
  String get takCompassSW => 'ЮЗ';

  @override
  String get takCompassW => 'З';

  @override
  String get takCotTypeAtom => 'Atom';

  @override
  String get takCotTypeBits => 'Bits';

  @override
  String get takCotTypeFriendly => 'Дружественный';

  @override
  String get takCotTypeHostile => 'Враждебный';

  @override
  String get takCotTypeNeutral => 'Нейтральный';

  @override
  String get takCotTypeTasking => 'Задание';

  @override
  String get takCotTypeUnknown => 'Неизвестный';

  @override
  String get takDashboardConnected => 'Подключено';

  @override
  String get takDashboardConnection => 'Соединение';

  @override
  String get takDashboardDisconnected => 'Отключено';

  @override
  String get takDashboardForceDisposition => 'Сводка объектов';

  @override
  String get takDashboardFriendly => 'Дружественные';

  @override
  String get takDashboardHostile => 'Враждебные';

  @override
  String get takDashboardLastEvent => 'Последнее событие';

  @override
  String get takDashboardLastEventNone => 'Нет';

  @override
  String takDashboardNearestHostile(String callsign) {
    return 'Ближайший враждебный: $callsign';
  }

  @override
  String takDashboardNearestUnknown(String callsign) {
    return 'Ближайший неизвестный: $callsign';
  }

  @override
  String get takDashboardNeutral => 'Нейтральные';

  @override
  String get takDashboardNoHostileContacts => 'Враждебных контактов нет';

  @override
  String get takDashboardNoUnknownContacts => 'Неизвестных контактов нет';

  @override
  String get takDashboardPositionPublishing => 'Публикация позиции';

  @override
  String takDashboardPublishingActive(String intervalSeconds) {
    return 'Активно ($intervalSecondsс)';
  }

  @override
  String get takDashboardPublishingDisabled => 'Отключено';

  @override
  String takDashboardRelativeTimeDays(int count) {
    return '$countд назад';
  }

  @override
  String takDashboardRelativeTimeHours(int count) {
    return '$countч назад';
  }

  @override
  String takDashboardRelativeTimeMinutes(int count) {
    return '$countм назад';
  }

  @override
  String takDashboardRelativeTimeSeconds(int count) {
    return '$countс назад';
  }

  @override
  String get takDashboardStaleEntities => 'Устаревшие объекты';

  @override
  String get takDashboardStatusHeader => 'Статус';

  @override
  String get takDashboardThreatProximity => 'Близость объектов';

  @override
  String get takDashboardTitle => 'TAK Панель управления';

  @override
  String get takDashboardTotalEntities => 'Всего объектов';

  @override
  String get takDashboardTracked => 'Отслеживаемые';

  @override
  String get takDashboardUnknown => 'Неизвестные';

  @override
  String takDistanceKilometers(double km) {
    return '$km км';
  }

  @override
  String takDistanceMeters(double meters) {
    return '$meters м';
  }

  @override
  String takEventAltitudeFormat(double meters, String feet) {
    return '$meters м ($feet фут.)';
  }

  @override
  String takEventCourseFormat(String degrees, String compassDirection) {
    return '$degrees° ($compassDirection)';
  }

  @override
  String get takEventDetailHelpAffiliation => 'Принадлежность';

  @override
  String get takEventDetailHelpCotType => 'Строка типа CoT';

  @override
  String get takEventDetailHelpIdentity => 'Идентификация';

  @override
  String get takEventDetailHelpMotion => 'Данные движения';

  @override
  String get takEventDetailHelpPosition => 'Позиция';

  @override
  String get takEventDetailHelpRawPayload => 'Необработанные данные';

  @override
  String get takEventDetailHelpTimestamps => 'Временные метки';

  @override
  String get takEventDetailHelpTracking => 'Отслеживание';

  @override
  String get takEventDetailJsonCopied => 'JSON события скопирован';

  @override
  String get takEventDetailLabelAltitude => 'Высота';

  @override
  String get takEventDetailLabelCallsign => 'Callsign';

  @override
  String get takEventDetailLabelCourse => 'Курс';

  @override
  String get takEventDetailLabelDescription => 'Описание';

  @override
  String get takEventDetailLabelEventTime => 'Время события';

  @override
  String get takEventDetailLabelLatitude => 'Широта';

  @override
  String get takEventDetailLabelLongitude => 'Долгота';

  @override
  String get takEventDetailLabelReceived => 'Получено';

  @override
  String get takEventDetailLabelSpeed => 'Скорость';

  @override
  String get takEventDetailLabelStaleTime => 'Время устаревания';

  @override
  String get takEventDetailLabelStatus => 'Статус';

  @override
  String get takEventDetailLabelType => 'Тип';

  @override
  String get takEventDetailLabelUid => 'UID';

  @override
  String get takEventDetailNavigateTo => 'Навигация к';

  @override
  String get takEventDetailNoMovement => 'Движение не зафиксировано';

  @override
  String takEventDetailPositionCount(int count) {
    return '($count позиций)';
  }

  @override
  String get takEventDetailSectionIdentity => 'Идентификация';

  @override
  String get takEventDetailSectionMotion => 'Движение';

  @override
  String get takEventDetailSectionPosition => 'Позиция';

  @override
  String get takEventDetailSectionPositionHistory => 'ИСТОРИЯ ПОЗИЦИЙ';

  @override
  String get takEventDetailSectionRawPayload => 'Необработанные данные';

  @override
  String get takEventDetailSectionTimestamps => 'Временные метки';

  @override
  String takEventDetailShowAllPositions(int count) {
    return 'Показать все $count позиций';
  }

  @override
  String get takEventDetailShowLess => 'Свернуть';

  @override
  String get takEventDetailStatusActive => 'АКТИВЕН';

  @override
  String get takEventDetailStatusStale => 'УСТАРЕЛ';

  @override
  String get takEventDetailTooltipCopyJson => 'Копировать JSON';

  @override
  String get takEventDetailTooltipShowOnMap => 'Показать на карте';

  @override
  String get takEventDetailTooltipTrack => 'Отслеживать';

  @override
  String get takEventDetailTooltipUntrack => 'Прекратить отслеживание';

  @override
  String takEventSpeedFormat(String kmh, String knots) {
    return '$kmh км/ч ($knots уз.)';
  }

  @override
  String get takEventSpeedStationary => 'Неподвижен';

  @override
  String get takEventTileActive => 'Активен';

  @override
  String takEventTileRelativeTimeHours(int count) {
    return '$countч назад';
  }

  @override
  String takEventTileRelativeTimeMinutes(int count) {
    return '$countм назад';
  }

  @override
  String takEventTileRelativeTimeSeconds(int count) {
    return '$countс назад';
  }

  @override
  String get takEventTileStale => 'Устарел';

  @override
  String get takFilterBarClear => 'Очистить';

  @override
  String get takFilterBarSearchHint => 'Поиск по callsign или UID...';

  @override
  String get takFilterBarStaleModeActive => 'Активные';

  @override
  String get takFilterBarStaleModeAll => 'Все';

  @override
  String get takFilterBarStaleModeStale => 'Устаревшие';

  @override
  String takNavigateEta(String eta) {
    return 'ОВП: $eta';
  }

  @override
  String get takNavigateLastUpdate => 'Последнее обновление';

  @override
  String get takNavigateNoPosition =>
      'Позиция недоступна\nПодключитесь к ноде с GPS';

  @override
  String get takNavigatePosition => 'Позиция';

  @override
  String takNavigateRelativeTimeDays(int count) {
    return '$countд назад';
  }

  @override
  String takNavigateRelativeTimeHours(int count) {
    return '$countч назад';
  }

  @override
  String takNavigateRelativeTimeMinutes(int count) {
    return '$countм назад';
  }

  @override
  String takNavigateRelativeTimeSeconds(int count) {
    return '$countс назад';
  }

  @override
  String takNavigateTitle(String callsign) {
    return 'Навигация к $callsign';
  }

  @override
  String get takScreenButtonConnect => 'Подключить';

  @override
  String get takScreenButtonSignIn => 'Войдите для подключения';

  @override
  String get takScreenEmptyDisconnected =>
      'Подключитесь к TAK Шлюзу, чтобы начать получать CoT объекты.';

  @override
  String get takScreenEmptyListening => 'Ожидание CoT событий от TAK Шлюза...';

  @override
  String get takScreenEmptySignIn =>
      'Войдите и подключитесь, чтобы начать получать CoT объекты в реальном времени.';

  @override
  String get takScreenEmptyTitle => 'Нет TAK объектов';

  @override
  String get takScreenFilterAll => 'Все';

  @override
  String get takScreenHelpTitleDefault => 'Информация';

  @override
  String get takScreenHelpTitleFilters => 'Фильтры';

  @override
  String get takScreenHelpTitleSettings => 'Настройки';

  @override
  String get takScreenHelpTitleStatus => 'Статус соединения';

  @override
  String get takScreenOverflowDashboard => 'TAK Панель управления';

  @override
  String get takScreenOverflowSettings => 'TAK Настройки';

  @override
  String get takScreenSearchHint => 'Поиск по callsign или UID';

  @override
  String get takScreenStaleModeActiveOnly => 'Только активные';

  @override
  String get takScreenStaleModeAll => 'Статус: все';

  @override
  String get takScreenStaleModeStaleOnly => 'Только устаревшие';

  @override
  String get takScreenTitle => 'TAK Шлюз';

  @override
  String get takScreenTooltipConnect => 'Подключить';

  @override
  String get takScreenTooltipDisconnect => 'Отключить';

  @override
  String get takScreenTooltipSignInToConnect => 'Войдите для подключения';

  @override
  String get takSettingsAlertHostile => 'Враждебный';

  @override
  String get takSettingsAlertOn => 'Оповещать при:';

  @override
  String get takSettingsAlertSuspect => 'Подозрительный';

  @override
  String get takSettingsAlertUnknown => 'Неизвестный';

  @override
  String get takSettingsAutoConnectSubtitle =>
      'Автоматически подключаться при открытии TAK экранов';

  @override
  String get takSettingsAutoConnectTitle => 'Автоподключение при открытии';

  @override
  String get takSettingsCallsignDefault => 'Используется имя ноды';

  @override
  String get takSettingsCallsignEditorHint =>
      'Оставьте пустым, чтобы использовать имя вашей ноды';

  @override
  String get takSettingsCallsignEditorPlaceholder => 'например, HIKER-7';

  @override
  String get takSettingsCallsignEditorTitle => 'Переопределение callsign';

  @override
  String get takSettingsCallsignTitle => 'Переопределение callsign';

  @override
  String takSettingsError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get takSettingsGatewayEditorHint =>
      'Оставьте пустым для использования шлюза по умолчанию';

  @override
  String get takSettingsGatewayEditorPlaceholder =>
      'https://tak.socialmesh.app';

  @override
  String get takSettingsGatewayEditorTitle => 'URL шлюза';

  @override
  String get takSettingsGatewayUrlDefault =>
      'По умолчанию (tak.socialmesh.app)';

  @override
  String get takSettingsGatewayUrlTitle => 'URL шлюза';

  @override
  String get takSettingsIntervalSubtitle => 'Как часто отправлять вашу позицию';

  @override
  String get takSettingsIntervalTitle => 'Интервал публикации';

  @override
  String get takSettingsMapLayerSubtitle =>
      'Отображать маркеры TAK объектов на специальной карте';

  @override
  String get takSettingsMapLayerTitle => 'Показывать TAK слой на карте';

  @override
  String get takSettingsProximitySubtitle =>
      'Уведомлять, когда неопознанные объекты входят в радиус';

  @override
  String get takSettingsProximityTitle => 'Включить оповещения о близости';

  @override
  String get takSettingsPublishSubtitle =>
      'Публиковать позицию вашей ноды для операторов ATAK/WinTAK';

  @override
  String get takSettingsPublishTitle => 'Публиковать мою позицию';

  @override
  String takSettingsRadiusSubtitle(double km) {
    return '$km км';
  }

  @override
  String get takSettingsRadiusTitle => 'Радиус оповещения';

  @override
  String get takSettingsSave => 'Сохранить';

  @override
  String get takSettingsSectionConnection => 'СОЕДИНЕНИЕ';

  @override
  String get takSettingsSectionMap => 'КАРТА';

  @override
  String get takSettingsSectionProximity => 'ОПОВЕЩЕНИЯ О БЛИЗОСТИ';

  @override
  String get takSettingsSectionPublishing => 'ПУБЛИКАЦИЯ ПОЗИЦИИ';

  @override
  String get takSettingsTitle => 'TAK Настройки';

  @override
  String get takStatusCardConnected => 'Подключено';

  @override
  String get takStatusCardConnecting => 'Подключение...';

  @override
  String get takStatusCardCounterEntities => 'Объекты';

  @override
  String get takStatusCardCounterEvents => 'События';

  @override
  String get takStatusCardCounterUptime => 'Время работы';

  @override
  String get takStatusCardDisconnected => 'Отключено';

  @override
  String get takStatusCardLabel => 'TAK Шлюз';

  @override
  String get takStatusCardReconnecting => 'Переподключение...';

  @override
  String takStatusCardUptimeHoursMinutes(int hours, int minutes) {
    return '$hoursч $minutesм';
  }

  @override
  String takStatusCardUptimeMinutes(int minutes) {
    return '$minutesм';
  }

  @override
  String takStatusCardUptimeSeconds(int seconds) {
    return '$secondsс';
  }

  @override
  String get tapbackReact => 'Реакция';

  @override
  String taskErrorCompleteTaskDenied(String roleName) {
    return 'completeTask запрещено для роли $roleName';
  }

  @override
  String get taskErrorCompletionNoteRequired =>
      'Для завершения требуется заметка не менее 10 символов';

  @override
  String taskErrorCreateDenied(String roleName) {
    return 'createTask запрещено для роли $roleName';
  }

  @override
  String get taskErrorFailureReasonRequired =>
      'Для фиксации ошибки требуется причина не менее 10 символов';

  @override
  String taskErrorInvalidTransition(String fromState, String toState) {
    return '$fromState -> $toState — недопустимый переход';
  }

  @override
  String get taskErrorOnlyAssigneeCanAcknowledge =>
      'Только назначенный исполнитель может подтвердить задачу';

  @override
  String get taskErrorOnlyAssigneeCanReportFailure =>
      'Только назначенный исполнитель может сообщить об ошибке задачи';

  @override
  String get taskErrorOnlyAssigneeCanStartWork =>
      'Только назначенный исполнитель может начать работу над задачей';

  @override
  String get taskErrorReassignmentRequiresAssignee =>
      'Переназначение требует newAssigneeId';

  @override
  String taskErrorRequiresSupervisorOrAdmin(String action, String roleName) {
    return '$action требует роли супервизора или администратора, текущая роль: $roleName';
  }

  @override
  String taskErrorTerminalState(String stateName) {
    return 'Невозможно перейти из $stateName: конечное состояние: $stateName';
  }

  @override
  String get taskPriorityImmediate => 'немедленно';

  @override
  String get taskPriorityPriority => 'приоритетно';

  @override
  String get taskPriorityRoutine => 'обычно';

  @override
  String get taskStateAcknowledged => 'подтверждено';

  @override
  String get taskStateAssigned => 'назначено';

  @override
  String get taskStateCancelled => 'отменено';

  @override
  String get taskStateCompleted => 'завершено';

  @override
  String get taskStateCreated => 'создано';

  @override
  String get taskStateFailed => 'ошибка';

  @override
  String get taskStateInProgress => 'в процессе';

  @override
  String get taskStateReassigned => 'переназначено';

  @override
  String get telemetryAirQualityNoData =>
      'Данные о качестве воздуха ещё не записаны';

  @override
  String get telemetryAirQualityParticle03um => '>0.3µm';

  @override
  String get telemetryAirQualityParticle05um => '>0.5µm';

  @override
  String get telemetryAirQualityParticle100um => '>10µm';

  @override
  String get telemetryAirQualityParticle10um => '>1.0µm';

  @override
  String get telemetryAirQualityParticle25um => '>2.5µm';

  @override
  String get telemetryAirQualityParticle50um => '>5.0µm';

  @override
  String get telemetryAirQualityParticleCounts =>
      'Количество частиц (на 0.1 л)';

  @override
  String get telemetryAirQualityPm100Label => 'PM10';

  @override
  String get telemetryAirQualityPm10Label => 'PM1.0';

  @override
  String get telemetryAirQualityPm25Label => 'PM2.5';

  @override
  String get telemetryAirQualityPmEnvironmental =>
      'Взвешенные частицы (окружающая среда)';

  @override
  String get telemetryAirQualityPmStandard => 'Взвешенные частицы (стандарт)';

  @override
  String get telemetryAirQualityTitle => 'Журнал качества воздуха';

  @override
  String get telemetryAirQualityUnitMicrogram => 'µg/m³';

  @override
  String get telemetryAllNodes => 'Все ноды';

  @override
  String get telemetryAqiGood => 'Хорошее';

  @override
  String get telemetryAqiHazardous => 'Опасное';

  @override
  String get telemetryAqiModerate => 'Умеренное';

  @override
  String get telemetryAqiUnhealthy => 'Вредное';

  @override
  String get telemetryAqiUnhealthySensitive => 'Вредное (Ч)';

  @override
  String get telemetryClearAllFilters => 'Сбросить все фильтры';

  @override
  String get telemetryClearData => 'Очистить данные';

  @override
  String get telemetryClearDateFilterTooltip => 'Сбросить фильтр по дате';

  @override
  String get telemetryCo2Excellent => 'Отличное';

  @override
  String get telemetryCo2Fair => 'Удовлетворительное';

  @override
  String get telemetryCo2Good => 'Хорошее';

  @override
  String telemetryCo2Label(String rating) {
    return 'CO₂ — $rating';
  }

  @override
  String get telemetryCo2Poor => 'Плохое';

  @override
  String get telemetryConfigAirQualityDesc =>
      'PM1.0, PM2.5, PM10, количество частиц, CO2';

  @override
  String get telemetryConfigAirtimeWarning =>
      'Данные телеметрии передаются всем нодам сети. Более короткие интервалы увеличивают использование эфирного времени.';

  @override
  String get telemetryConfigDeviceMetricsDesc =>
      'Уровень заряда аккумулятора, напряжение, загруженность канала, TX эфирного времени';

  @override
  String get telemetryConfigDisplayFahrenheit => 'Отображать в Фаренгейтах';

  @override
  String get telemetryConfigDisplayFahrenheitSubtitle =>
      'Показывать температуру в градусах Фаренгейта вместо Цельсия';

  @override
  String get telemetryConfigDisplayOnScreen => 'Отображать на экране';

  @override
  String get telemetryConfigDisplayOnScreenSubtitle =>
      'Показывать данные об окружающей среде на экране устройства';

  @override
  String get telemetryConfigEnabled => 'Включено';

  @override
  String get telemetryConfigEnvironmentMetricsDesc =>
      'Температура, влажность, атмосферное давление, сопротивление газа';

  @override
  String get telemetryConfigMinutes => ' минут';

  @override
  String get telemetryConfigPowerMetricsDesc =>
      'Напряжение и ток для каналов 1–3';

  @override
  String get telemetryConfigSave => 'Сохранить';

  @override
  String telemetryConfigSaveError(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get telemetryConfigSaved => 'Конфигурация телеметрии сохранена';

  @override
  String get telemetryConfigSectionAirQuality => 'Качество воздуха';

  @override
  String get telemetryConfigSectionDeviceMetrics => 'Метрики устройства';

  @override
  String get telemetryConfigSectionEnvironmentMetrics =>
      'Метрики окружающей среды';

  @override
  String get telemetryConfigSectionPowerMetrics => 'Метрики питания';

  @override
  String get telemetryConfigTitle => 'Телеметрия';

  @override
  String get telemetryConfigUpdateInterval => 'Интервал обновления';

  @override
  String get telemetryDateRangeTooltip => 'Диапазон дат';

  @override
  String get telemetryDetectionClearBadge => 'Очистить';

  @override
  String get telemetryDetectionDescription =>
      'Датчики обнаружения фиксируют движение и присутствие';

  @override
  String get telemetryDetectionDetected => 'ОБНАРУЖЕНО';

  @override
  String get telemetryDetectionNoData => 'События датчика ещё не записаны';

  @override
  String get telemetryDetectionSensor => 'Датчик обнаружения';

  @override
  String get telemetryDetectionTitle => 'Журнал датчика обнаружения';

  @override
  String get telemetryDeviceCharging => 'Зарядка';

  @override
  String get telemetryDeviceFilterAirUtil => 'Эфирное время';

  @override
  String get telemetryDeviceFilterBattery => 'Аккумулятор';

  @override
  String get telemetryDeviceFilterChannel => 'Канал';

  @override
  String get telemetryDeviceFilterUptime => 'Время работы';

  @override
  String get telemetryDeviceFilterVoltage => 'Напряжение';

  @override
  String get telemetryDeviceLegendAirUtil => 'Эфирное время';

  @override
  String get telemetryDeviceLegendBattery => 'Аккумулятор';

  @override
  String get telemetryDeviceLegendChUtil => 'Загр. кан.';

  @override
  String get telemetryDeviceLegendVoltage => 'Напряжение';

  @override
  String telemetryDeviceMetricsAirUtil(String percent) {
    return 'Эфир $percent%';
  }

  @override
  String telemetryDeviceMetricsChannelUtil(String percent) {
    return 'Кан. $percent%';
  }

  @override
  String get telemetryDeviceMetricsTitle => 'Метрики устройства';

  @override
  String telemetryDeviceMetricsVoltageValue(String voltage) {
    return '${voltage}V';
  }

  @override
  String get telemetryDeviceNoMetrics => 'Метрики устройства ещё отсутствуют';

  @override
  String get telemetryEndDate => 'Дата окончания';

  @override
  String telemetryEnvGasResistanceValue(String value) {
    return '$value Ω';
  }

  @override
  String telemetryEnvHumidityValue(String value) {
    return '$value%';
  }

  @override
  String telemetryEnvIaqValue(String value) {
    return 'IAQ $value';
  }

  @override
  String telemetryEnvLuxValue(String value) {
    return '$value lux';
  }

  @override
  String telemetryEnvPressureValue(String value) {
    return '$value hPa';
  }

  @override
  String telemetryEnvTemperatureValue(String value) {
    return '$value°C';
  }

  @override
  String telemetryEnvWindSpeedValue(String value) {
    return '$value m/s';
  }

  @override
  String get telemetryEnvironmentFilterGas => 'Газ';

  @override
  String get telemetryEnvironmentFilterHumidity => 'Влажность';

  @override
  String get telemetryEnvironmentFilterIaq => 'IAQ';

  @override
  String get telemetryEnvironmentFilterLight => 'Освещённость';

  @override
  String get telemetryEnvironmentFilterPressure => 'Давление';

  @override
  String get telemetryEnvironmentFilterTemp => 'Темп.';

  @override
  String get telemetryEnvironmentFilterWind => 'Ветер';

  @override
  String get telemetryEnvironmentLegendHumidity => 'Влажность';

  @override
  String get telemetryEnvironmentLegendTemperature => 'Температура';

  @override
  String get telemetryEnvironmentNoMetrics =>
      'Метрики окружающей среды ещё отсутствуют';

  @override
  String get telemetryEnvironmentTitle => 'Метрики окружающей среды';

  @override
  String telemetryError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get telemetryExportCsv => 'Экспорт CSV';

  @override
  String telemetryExportFailed(String error) {
    return 'Экспорт не выполнен: $error';
  }

  @override
  String get telemetryExporting => 'Экспорт...';

  @override
  String telemetryFailedToClear(String error) {
    return 'Не удалось очистить данные: $error';
  }

  @override
  String get telemetryFilterAll => 'Все';

  @override
  String get telemetryHelp => 'Справка';

  @override
  String get telemetryMetricsWillAppear =>
      'Метрики появятся, когда устройство передаст данные телеметрии';

  @override
  String get telemetryNoMetricsMatchFilters =>
      'Нет метрик, соответствующих фильтрам';

  @override
  String get telemetryPaxBluetooth => 'Bluetooth';

  @override
  String get telemetryPaxDescription =>
      'PAX-счётчик обнаруживает устройства поблизости';

  @override
  String get telemetryPaxNoData => 'Данные PAX ещё не записаны';

  @override
  String get telemetryPaxTitle => 'Журнал PAX-счётчика';

  @override
  String telemetryPaxUptime(String uptime) {
    return 'Время работы: $uptime';
  }

  @override
  String get telemetryPaxWifi => 'WiFi';

  @override
  String get telemetryPositionAllNodesDescription =>
      'Показать местоположения всех нод';

  @override
  String get telemetryPositionAllNodesOption => 'Все ноды';

  @override
  String get telemetryPositionClearLabel => 'Очистить';

  @override
  String get telemetryPositionClearMessage =>
      'Это действие безвозвратно удалит всю историю местоположений для всех нод. Отменить невозможно.';

  @override
  String get telemetryPositionClearTitle => 'Очистить данные о местоположении';

  @override
  String get telemetryPositionCleared => 'Данные о местоположении очищены';

  @override
  String telemetryPositionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count местоположения',
      many: '$count местоположений',
      few: '$count местоположения',
      one: '$count местоположение',
    );
    return '$_temp0';
  }

  @override
  String get telemetryPositionDateRange => 'Диапазон дат';

  @override
  String get telemetryPositionDrawerTitle => 'Ноды';

  @override
  String get telemetryPositionExportSubject =>
      'Экспорт местоположений Socialmesh';

  @override
  String telemetryPositionExportedCount(int count) {
    return 'Экспортировано $count местоположений';
  }

  @override
  String get telemetryPositionFilterGoodFix => 'Хороший сигнал';

  @override
  String get telemetryPositionFilterMyNode => 'Моя нода';

  @override
  String get telemetryPositionFilterThisWeek => 'На этой неделе';

  @override
  String get telemetryPositionFilterToday => 'Сегодня';

  @override
  String get telemetryPositionListView => 'Список';

  @override
  String get telemetryPositionMapStyle => 'Стиль карты';

  @override
  String get telemetryPositionMapView => 'Карта';

  @override
  String get telemetryPositionNoDisplay => 'Нет местоположений для отображения';

  @override
  String get telemetryPositionNoExportData =>
      'Нет данных о местоположении для экспорта';

  @override
  String get telemetryPositionNoHistory => 'История местоположений отсутствует';

  @override
  String get telemetryPositionNoMatch =>
      'Нет местоположений, соответствующих фильтрам';

  @override
  String telemetryPositionNodesCount(int count) {
    return '$count нод';
  }

  @override
  String get telemetryPositionStatDistance => 'Расстояние';

  @override
  String get telemetryPositionStatNodes => 'Ноды';

  @override
  String get telemetryPositionStatPoints => 'Точки';

  @override
  String get telemetryPositionTitle => 'Местоположение';

  @override
  String telemetryReadingsCount(int count) {
    return '$count показаний';
  }

  @override
  String get telemetrySearchByNode => 'Поиск по ноде';

  @override
  String get telemetrySearchByNodeName => 'Поиск по имени ноды';

  @override
  String get telemetrySettings => 'Настройки';

  @override
  String get telemetryStartDate => 'Дата начала';

  @override
  String get telemetryTracerouteClearLabel => 'Очистить';

  @override
  String telemetryTracerouteClearMessage(String scope) {
    return 'Это действие безвозвратно удалит всю историю трассировки для $scope. Отменить невозможно.';
  }

  @override
  String get telemetryTracerouteClearTitle => 'Очистить данные трассировки';

  @override
  String get telemetryTracerouteCleared => 'Данные трассировки очищены';

  @override
  String get telemetryTracerouteDirectConnection =>
      'Прямое соединение — промежуточные ноды отсутствуют';

  @override
  String get telemetryTracerouteEmptyHint =>
      'Запустите трассировку с ноды, чтобы увидеть сетевые пути';

  @override
  String telemetryTracerouteExportSubject(String scope) {
    return 'Экспорт трассировки Socialmesh ($scope)';
  }

  @override
  String telemetryTracerouteExportedCount(int count) {
    return 'Экспортировано $count трассировок';
  }

  @override
  String get telemetryTracerouteFilterNoResponse => 'Нет ответа';

  @override
  String get telemetryTracerouteFilterResponse => 'Ответ';

  @override
  String get telemetryTracerouteForwardPath => 'Прямой путь';

  @override
  String get telemetryTracerouteHopsBack => 'Хопов ←';

  @override
  String get telemetryTracerouteHopsForward => 'Хопов →';

  @override
  String get telemetryTracerouteMoreActions => 'Дополнительные действия';

  @override
  String get telemetryTracerouteNoData => 'Трассировки ещё не записаны';

  @override
  String get telemetryTracerouteNoExportData =>
      'Нет данных трассировки для экспорта';

  @override
  String get telemetryTracerouteNoMatch =>
      'Нет трассировок, соответствующих фильтрам';

  @override
  String get telemetryTracerouteNoResponseBadge => 'Нет ответа';

  @override
  String get telemetryTracerouteResponseBadge => 'Ответ';

  @override
  String get telemetryTracerouteReturnPath => 'Обратный путь';

  @override
  String get telemetryTracerouteTitle => 'История трассировок';

  @override
  String get telemetryTracerouteTo => 'Кому';

  @override
  String get telemetryTryAdjustingFilters =>
      'Попробуйте изменить поисковый запрос или фильтры';

  @override
  String get timelineActivityWillAppear =>
      'Активность будет отображаться здесь по мере возникновения';

  @override
  String get timelineFilterAll => 'Все';

  @override
  String get timelineFilterMessages => 'Сообщения';

  @override
  String get timelineFilterNodes => 'Ноды';

  @override
  String get timelineFilterSignals => 'Сигналы';

  @override
  String get timelineFilterWaypoints => 'Точки маршрута';

  @override
  String get timelineFriday => 'Пятница';

  @override
  String timelineLastHeard(String timeAgo) {
    return 'Последний сигнал $timeAgo';
  }

  @override
  String get timelineMonday => 'Понедельник';

  @override
  String get timelineNoEvents => 'Событий пока нет';

  @override
  String get timelineNoFilterResults => 'Нет событий, соответствующих фильтру';

  @override
  String get timelineNoSearchResults => 'Нет событий, соответствующих поиску';

  @override
  String timelineNodeActive(String name) {
    return '$name активен';
  }

  @override
  String timelineNodeInactive(String name) {
    return '$name стал неактивным';
  }

  @override
  String timelineRssiValue(double value) {
    return 'RSSI: $value dBm';
  }

  @override
  String get timelineSaturday => 'Суббота';

  @override
  String get timelineSearchHint => 'Поиск событий';

  @override
  String get timelineShowAllEvents => 'Показать все события';

  @override
  String timelineSnrValue(double value) {
    return 'SNR: $value dB';
  }

  @override
  String get timelineSunday => 'Воскресенье';

  @override
  String get timelineThursday => 'Четверг';

  @override
  String get timelineTitle => 'История';

  @override
  String get timelineToday => 'Сегодня';

  @override
  String get timelineTryDifferent =>
      'Попробуйте другой поисковый запрос или фильтр';

  @override
  String get timelineTuesday => 'Вторник';

  @override
  String timelineWeakSignal(String name) {
    return 'Слабый сигнал от $name';
  }

  @override
  String get timelineWednesday => 'Среда';

  @override
  String get timelineYesterday => 'Вчера';

  @override
  String get widgetBuilderActionCopyToClipboard => 'Копировать в буфер обмена';

  @override
  String get widgetBuilderActionEmergencySos => 'Экстренный SOS';

  @override
  String get widgetBuilderActionNavigateLabel => 'Навигация';

  @override
  String get widgetBuilderActionNoAction => 'Без действия';

  @override
  String get widgetBuilderActionOpenUrl => 'Открыть URL';

  @override
  String get widgetBuilderActionRequestPositions => 'Запросить позиции';

  @override
  String get widgetBuilderActionRequestPositionsDesc =>
      'Запросить у всех нод передать своё местоположение';

  @override
  String get widgetBuilderActionRequestPositionsLabel => 'Запросить позиции';

  @override
  String get widgetBuilderActionSendMessage => 'Отправить сообщение';

  @override
  String get widgetBuilderActionSendMessageDesc =>
      'Открыть редактор для отправки сообщения';

  @override
  String get widgetBuilderActionSendMessageLabel => 'Отправить сообщение';

  @override
  String get widgetBuilderActionShareLocation => 'Поделиться местоположением';

  @override
  String get widgetBuilderActionShareLocationDesc =>
      'Передать текущие координаты GPS';

  @override
  String get widgetBuilderActionShareLocationLabel =>
      'Поделиться местоположением';

  @override
  String get widgetBuilderActionSosAlert => 'SOS-оповещение';

  @override
  String get widgetBuilderActionSosAlertDesc =>
      'Отправить экстренное оповещение всем нодам';

  @override
  String get widgetBuilderActionTraceroute => 'Traceroute';

  @override
  String get widgetBuilderActionTracerouteDesc => 'Проследить маршрут до ноды';

  @override
  String get widgetBuilderActionTracerouteLabel => 'Traceroute';

  @override
  String get widgetBuilderAddAction => 'Добавить действие';

  @override
  String get widgetBuilderAddBlock => 'Добавить блок';

  @override
  String get widgetBuilderAddElement => 'Добавить элемент';

  @override
  String get widgetBuilderAddIcon => 'Иконка';

  @override
  String get widgetBuilderAddIconDesc => 'Добавить символ или эмодзи';

  @override
  String widgetBuilderAddItemCount(int count) {
    return 'Добавить элемент ($count эл.)';
  }

  @override
  String get widgetBuilderAddProgressBar => 'Индикатор прогресса';

  @override
  String get widgetBuilderAddProgressBarDesc => 'Отобразить значение визуально';

  @override
  String get widgetBuilderAddReferenceLines =>
      'Добавить опорные линии на заданных значениях';

  @override
  String get widgetBuilderAddSpace => 'Пробел';

  @override
  String get widgetBuilderAddSpaceDesc =>
      'Добавить пустое пространство между элементами';

  @override
  String get widgetBuilderAddTapAction => 'Добавить действие по нажатию...';

  @override
  String get widgetBuilderAddText => 'Текст';

  @override
  String get widgetBuilderAddTextDesc => 'Добавить метку или значение';

  @override
  String get widgetBuilderAddToDashboard => 'Добавить на панель';

  @override
  String widgetBuilderAddedToDashboard(String name) {
    return '$name добавлен на панель';
  }

  @override
  String get widgetBuilderAll => 'Все';

  @override
  String get widgetBuilderAllNodes => 'Все ноды';

  @override
  String widgetBuilderApprovedSuccess(String name) {
    return '$name одобрен';
  }

  @override
  String get widgetBuilderBindingActiveMeshNodes => 'Активные ноды сети';

  @override
  String get widgetBuilderBindingActiveMeshNodesDesc =>
      'Ноды, от которых недавно поступал сигнал';

  @override
  String get widgetBuilderBindingActiveMeshNodesLegacy =>
      'Активные ноды сети (устаревшее)';

  @override
  String get widgetBuilderBindingActiveMeshNodesLegacyDesc =>
      'Псевдоним счётчика активных нод (для обратной совместимости)';

  @override
  String get widgetBuilderBindingAirtimeTx => 'Эфирное время TX';

  @override
  String get widgetBuilderBindingAirtimeTxDesc =>
      'Использование эфирного времени при передаче';

  @override
  String get widgetBuilderBindingAltitude => 'Высота';

  @override
  String get widgetBuilderBindingAltitudeDesc => 'Высота над уровнем моря';

  @override
  String get widgetBuilderBindingBadPacketsRx => 'Повреждённые пакеты RX';

  @override
  String get widgetBuilderBindingBadPacketsRxDesc =>
      'Количество полученных повреждённых пакетов';

  @override
  String get widgetBuilderBindingBatteryLevel => 'Уровень заряда';

  @override
  String get widgetBuilderBindingBatteryLevelDesc =>
      'Заряд батареи в процентах (0–100)';

  @override
  String get widgetBuilderBindingBatteryVoltage => 'Напряжение батареи';

  @override
  String get widgetBuilderBindingBatteryVoltageDesc => 'Напряжение батареи';

  @override
  String get widgetBuilderBindingCategoryAirQuality => 'Качество воздуха';

  @override
  String get widgetBuilderBindingCategoryDevice => 'Устройство';

  @override
  String get widgetBuilderBindingCategoryEnvironment => 'Окружающая среда';

  @override
  String get widgetBuilderBindingCategoryGps => 'GPS';

  @override
  String get widgetBuilderBindingCategoryMessages => 'Сообщения';

  @override
  String get widgetBuilderBindingCategoryNetwork => 'Сеть';

  @override
  String get widgetBuilderBindingCategoryNodeInfo => 'Информация о ноде';

  @override
  String get widgetBuilderBindingCategoryPower => 'Питание';

  @override
  String get widgetBuilderBindingCh1Current => 'Ток канала 1';

  @override
  String get widgetBuilderBindingCh1CurrentDesc => 'Ток силового канала 1';

  @override
  String get widgetBuilderBindingCh1Voltage => 'Напряжение канала 1';

  @override
  String get widgetBuilderBindingCh1VoltageDesc =>
      'Напряжение силового канала 1';

  @override
  String get widgetBuilderBindingCh2Current => 'Ток канала 2';

  @override
  String get widgetBuilderBindingCh2CurrentDesc => 'Ток силового канала 2';

  @override
  String get widgetBuilderBindingCh2Voltage => 'Напряжение канала 2';

  @override
  String get widgetBuilderBindingCh2VoltageDesc =>
      'Напряжение силового канала 2';

  @override
  String get widgetBuilderBindingCh3Current => 'Ток канала 3';

  @override
  String get widgetBuilderBindingCh3CurrentDesc => 'Ток силового канала 3';

  @override
  String get widgetBuilderBindingCh3Voltage => 'Напряжение канала 3';

  @override
  String get widgetBuilderBindingCh3VoltageDesc =>
      'Напряжение силового канала 3';

  @override
  String get widgetBuilderBindingChannelUtil => 'Загрузка канала';

  @override
  String get widgetBuilderBindingChannelUtilDesc =>
      'Текущий процент загрузки канала';

  @override
  String get widgetBuilderBindingCo2 => 'CO2';

  @override
  String get widgetBuilderBindingCo2Desc => 'Концентрация CO2';

  @override
  String get widgetBuilderBindingDisplayName => 'Отображаемое имя';

  @override
  String get widgetBuilderBindingDisplayNameDesc =>
      'Отображаемое имя ноды (полное или короткое)';

  @override
  String get widgetBuilderBindingDistance => 'Расстояние';

  @override
  String get widgetBuilderBindingDistanceDesc => 'Расстояние до ноды в метрах';

  @override
  String get widgetBuilderBindingFirmwareVersion => 'Версия прошивки';

  @override
  String get widgetBuilderBindingFirmwareVersionDesc =>
      'Текущая версия прошивки';

  @override
  String get widgetBuilderBindingFirstHeard => 'Первый контакт';

  @override
  String get widgetBuilderBindingFirstHeardDesc =>
      'Когда нода была обнаружена впервые';

  @override
  String get widgetBuilderBindingGroundSpeed => 'Скорость';

  @override
  String get widgetBuilderBindingGroundSpeedDesc =>
      'Скорость относительно земли';

  @override
  String get widgetBuilderBindingHardwareModel => 'Модель оборудования';

  @override
  String get widgetBuilderBindingHardwareModelDesc =>
      'Аппаратная модель устройства';

  @override
  String get widgetBuilderBindingHeading => 'Курс';

  @override
  String get widgetBuilderBindingHeadingDesc => 'Курс движения в градусах';

  @override
  String get widgetBuilderBindingHopCount => 'Количество хопов';

  @override
  String get widgetBuilderBindingHopCountDesc =>
      'Число хопов от данной ноды (0 = прямой сосед)';

  @override
  String get widgetBuilderBindingHumidity => 'Влажность';

  @override
  String get widgetBuilderBindingHumidityDesc =>
      'Относительная влажность в процентах';

  @override
  String get widgetBuilderBindingIaqIndex => 'Индекс IAQ';

  @override
  String get widgetBuilderBindingIaqIndexDesc =>
      'Индекс качества воздуха в помещении';

  @override
  String get widgetBuilderBindingLastHeard => 'Последний контакт';

  @override
  String get widgetBuilderBindingLastHeardDesc =>
      'Когда от ноды последний раз поступал сигнал';

  @override
  String get widgetBuilderBindingLatitude => 'Широта';

  @override
  String get widgetBuilderBindingLatitudeDesc => 'Координата широты GPS';

  @override
  String get widgetBuilderBindingLightLevel => 'Освещённость';

  @override
  String get widgetBuilderBindingLightLevelDesc =>
      'Уровень окружающего освещения';

  @override
  String get widgetBuilderBindingLongitude => 'Долгота';

  @override
  String get widgetBuilderBindingLongitudeDesc => 'Координата долготы GPS';

  @override
  String get widgetBuilderBindingNodeName => 'Имя ноды';

  @override
  String get widgetBuilderBindingNodeNameDesc => 'Полное имя ноды';

  @override
  String get widgetBuilderBindingNodeNumber => 'Номер ноды';

  @override
  String get widgetBuilderBindingNodeNumberDesc => 'Уникальный номер ноды';

  @override
  String get widgetBuilderBindingNodeRole => 'Роль ноды';

  @override
  String get widgetBuilderBindingNodeRoleDesc =>
      'Роль в сети (CLIENT, ROUTER и др.)';

  @override
  String get widgetBuilderBindingNodeStatus => 'Статус ноды';

  @override
  String get widgetBuilderBindingNodeStatusDesc =>
      'Пользовательский статус-сообщение от ноды';

  @override
  String get widgetBuilderBindingNodesHeard2h => 'Ноды в эфире (2 ч)';

  @override
  String get widgetBuilderBindingNodesHeard2hDesc =>
      'Метрика Meshtastic: ноды, от которых поступал сигнал за последние 2 часа';

  @override
  String get widgetBuilderBindingNoiseFloor => 'Шумовой порог';

  @override
  String get widgetBuilderBindingNoiseFloorDesc =>
      'Измеренный уровень шума в dBm';

  @override
  String get widgetBuilderBindingPacketsRx => 'Пакеты RX';

  @override
  String get widgetBuilderBindingPacketsRxDesc => 'Всего получено пакетов';

  @override
  String get widgetBuilderBindingPacketsTx => 'Пакеты TX';

  @override
  String get widgetBuilderBindingPacketsTxDesc => 'Всего отправлено пакетов';

  @override
  String get widgetBuilderBindingPacketsTxDropped => 'Пакеты TX отброшены';

  @override
  String get widgetBuilderBindingPacketsTxDroppedDesc =>
      'Пакеты, отброшенные из-за переполнения очереди TX';

  @override
  String get widgetBuilderBindingPm10Large => 'PM10';

  @override
  String get widgetBuilderBindingPm10LargeDesc => 'Взвешенные частицы PM10';

  @override
  String get widgetBuilderBindingPm10Small => 'PM1.0';

  @override
  String get widgetBuilderBindingPm10SmallDesc => 'Взвешенные частицы PM1.0';

  @override
  String get widgetBuilderBindingPm25 => 'PM2.5';

  @override
  String get widgetBuilderBindingPm25Desc => 'Взвешенные частицы PM2.5';

  @override
  String get widgetBuilderBindingPresenceConfidence =>
      'Достоверность присутствия';

  @override
  String get widgetBuilderBindingPresenceConfidenceDesc =>
      'Расчётное присутствие: активен, угасает, устарело, неизвестно';

  @override
  String get widgetBuilderBindingPressure => 'Давление';

  @override
  String get widgetBuilderBindingPressureDesc => 'Атмосферное давление';

  @override
  String get widgetBuilderBindingRainfall1h => 'Осадки (1 ч)';

  @override
  String get widgetBuilderBindingRainfall1hDesc =>
      'Количество осадков за последний час';

  @override
  String get widgetBuilderBindingRainfall24h => 'Осадки (24 ч)';

  @override
  String get widgetBuilderBindingRainfall24hDesc =>
      'Количество осадков за последние 24 часа';

  @override
  String get widgetBuilderBindingRecentMessages => 'Последние сообщения';

  @override
  String get widgetBuilderBindingRecentMessagesDesc =>
      'Количество последних сообщений';

  @override
  String get widgetBuilderBindingRssi => 'RSSI';

  @override
  String get widgetBuilderBindingRssiDesc => 'Уровень принимаемого сигнала';

  @override
  String get widgetBuilderBindingSatellites => 'Спутники';

  @override
  String get widgetBuilderBindingSatellitesDesc =>
      'Количество видимых спутников GPS';

  @override
  String get widgetBuilderBindingShortName => 'Короткое имя';

  @override
  String get widgetBuilderBindingShortNameDesc =>
      'Короткий 4-символьный идентификатор ноды';

  @override
  String get widgetBuilderBindingSnr => 'SNR';

  @override
  String get widgetBuilderBindingSnrDesc => 'Отношение сигнал/шум';

  @override
  String get widgetBuilderBindingSoilMoisture => 'Влажность почвы';

  @override
  String get widgetBuilderBindingSoilMoistureDesc =>
      'Влажность почвы в процентах';

  @override
  String get widgetBuilderBindingSoilTemperature => 'Температура почвы';

  @override
  String get widgetBuilderBindingSoilTemperatureDesc => 'Температура почвы';

  @override
  String get widgetBuilderBindingTemperature => 'Температура';

  @override
  String get widgetBuilderBindingTemperatureDesc =>
      'Температура окружающей среды';

  @override
  String get widgetBuilderBindingTotalMeshNodes => 'Всего нод сети';

  @override
  String get widgetBuilderBindingTotalMeshNodesDesc =>
      'Общее количество нод в сети';

  @override
  String get widgetBuilderBindingTotalNodes => 'Всего нод';

  @override
  String get widgetBuilderBindingTotalNodesDesc =>
      'Общее количество известных нод';

  @override
  String get widgetBuilderBindingUnreadMessages => 'Непрочитанные сообщения';

  @override
  String get widgetBuilderBindingUnreadMessagesDesc =>
      'Количество непрочитанных сообщений';

  @override
  String get widgetBuilderBindingUptime => 'Время работы';

  @override
  String get widgetBuilderBindingUptimeDesc =>
      'Время работы устройства в секундах';

  @override
  String get widgetBuilderBindingViaMqtt => 'Через MQTT';

  @override
  String get widgetBuilderBindingViaMqttDesc =>
      'Получен ли последний сигнал от ноды через MQTT';

  @override
  String get widgetBuilderBindingWindDirection => 'Направление ветра';

  @override
  String get widgetBuilderBindingWindDirectionDesc =>
      'Направление ветра в градусах';

  @override
  String get widgetBuilderBindingWindGust => 'Порыв ветра';

  @override
  String get widgetBuilderBindingWindGustDesc => 'Скорость порыва ветра';

  @override
  String get widgetBuilderBindingWindSpeed => 'Скорость ветра';

  @override
  String get widgetBuilderBindingWindSpeedDesc => 'Текущая скорость ветра';

  @override
  String get widgetBuilderBlockActionButton => 'Кнопка действия';

  @override
  String get widgetBuilderBlockActionButtonDesc =>
      'Кнопка с назначенным действием';

  @override
  String get widgetBuilderBlockInfoBlock => 'Информационный блок';

  @override
  String get widgetBuilderBlockInfoBlockDesc => 'Иконка + Метка + Значение';

  @override
  String get widgetBuilderBlockMetric => 'Метрика';

  @override
  String get widgetBuilderBlockMetricDesc => 'Крупное значение с подписью';

  @override
  String get widgetBuilderBlockNewRow => 'Новая строка';

  @override
  String get widgetBuilderBlockNewRowDesc =>
      'Добавить строку для дополнительных блоков';

  @override
  String get widgetBuilderBlockStatus => 'Статус';

  @override
  String get widgetBuilderBlockStatusDesc =>
      'Индикатор статуса с привязкой данных';

  @override
  String get widgetBuilderBoolNo => 'Нет';

  @override
  String get widgetBuilderBoolYes => 'Да';

  @override
  String get widgetBuilderBroadcastSubtitle => 'Трансляция всем в канале';

  @override
  String get widgetBuilderBrowseMarketplace => 'Открыть маркетплейс';

  @override
  String widgetBuilderByAuthor(String author) {
    return 'автор: $author';
  }

  @override
  String get widgetBuilderCancel => 'Отмена';

  @override
  String widgetBuilderCannotSaveMessage(String message) {
    return '$message\n\nВернитесь к шагу 1, чтобы изменить шаблон, или к шагу 3, чтобы обновить выбор.';
  }

  @override
  String get widgetBuilderCannotSaveTitle => 'Невозможно сохранить виджет';

  @override
  String get widgetBuilderCategoryCharts => 'Графики';

  @override
  String get widgetBuilderCategoryDeviceStatus => 'Статус устройства';

  @override
  String get widgetBuilderCategoryLocation => 'Местоположение';

  @override
  String get widgetBuilderCategoryMeshNetwork => 'Mesh-сеть';

  @override
  String get widgetBuilderCategoryMetrics => 'Метрики';

  @override
  String get widgetBuilderCategoryOther => 'Прочее';

  @override
  String get widgetBuilderCategoryUtility => 'Утилиты';

  @override
  String get widgetBuilderCategoryWeather => 'Погода';

  @override
  String get widgetBuilderChooseAction =>
      'Выберите действие для этого элемента';

  @override
  String get widgetBuilderChooseColor => 'Выбрать цвет';

  @override
  String get widgetBuilderColorSectionLabel => 'ЦВЕТ';

  @override
  String get widgetBuilderChooseStyle => 'Выберите подходящий стиль';

  @override
  String get widgetBuilderCreateFirstWidget => 'Создайте первый виджет';

  @override
  String get widgetBuilderCreateFirstWidgetDesc =>
      'Используйте мастер для создания виджета с нужными данными и макетом';

  @override
  String get widgetBuilderCreateWidgetTooltip => 'Создать виджет';

  @override
  String get widgetBuilderCustomDashboardWidgets =>
      'Пользовательские виджеты панели';

  @override
  String get widgetBuilderCustomWidget => 'Пользовательский виджет';

  @override
  String get widgetBuilderDeleteAction => 'Удалить';

  @override
  String get widgetBuilderDeleteButton => 'Удалить';

  @override
  String get widgetBuilderDeleteWidgetTitle => 'Удалить виджет?';

  @override
  String get widgetBuilderDiscard => 'Отклонить';

  @override
  String get widgetBuilderDiscardChangesMessage =>
      'Есть несохранённые изменения. Закрыть без сохранения?';

  @override
  String get widgetBuilderDiscardChangesTitle => 'Отклонить изменения?';

  @override
  String get widgetBuilderDiscoverCommunity =>
      'Откройте для себя виджеты, созданные сообществом';

  @override
  String get widgetBuilderDuplicate => 'Дублировать';

  @override
  String get widgetBuilderEdit => 'Редактировать';

  @override
  String get widgetBuilderElementNotFound => 'Элемент не найден';

  @override
  String get widgetBuilderEnablePhoneLocation =>
      'Включите «Передавать местоположение телефона» в настройках, чтобы делиться своим положением';

  @override
  String get widgetBuilderEnterThresholdValue => 'Введите пороговое значение';

  @override
  String get widgetBuilderEnterWidgetName => 'Введите название виджета';

  @override
  String widgetBuilderFailedToApprove(String error) {
    return 'Ошибка одобрения: $error';
  }

  @override
  String widgetBuilderFailedToImport(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String widgetBuilderFailedToInstall(String error) {
    return 'Ошибка установки: $error';
  }

  @override
  String widgetBuilderFailedToReject(String error) {
    return 'Ошибка отклонения: $error';
  }

  @override
  String widgetBuilderFailedToRequestPositions(String error) {
    return 'Ошибка запроса позиций: $error';
  }

  @override
  String widgetBuilderFailedToSaveWidget(String error) {
    return 'Ошибка сохранения виджета: $error';
  }

  @override
  String widgetBuilderFailedToShareLocation(String error) {
    return 'Ошибка передачи местоположения: $error';
  }

  @override
  String widgetBuilderFailedToSubmit(String error) {
    return 'Ошибка отправки: $error';
  }

  @override
  String get widgetBuilderHelp => 'Справка';

  @override
  String get widgetBuilderHeroDescription =>
      'Создавайте персональные виджеты для отображения данных сети так, как вам удобно. Отслеживайте заряд батареи, уровень сигнала, местоположение и многое другое с одного взгляда.';

  @override
  String get widgetBuilderIconAdd => 'Добавить';

  @override
  String get widgetBuilderIconAir => 'Воздух';

  @override
  String get widgetBuilderIconAlert => 'Оповещение';

  @override
  String get widgetBuilderIconAnalytics => 'Аналитика';

  @override
  String get widgetBuilderIconBluetooth => 'Bluetooth';

  @override
  String get widgetBuilderIconBookmark => 'Закладка';

  @override
  String get widgetBuilderIconCall => 'Звонок';

  @override
  String get widgetBuilderIconCategoryActions => 'Действия';

  @override
  String get widgetBuilderIconCategoryBatteryPower => 'Батарея и питание';

  @override
  String get widgetBuilderIconCategoryCommunication => 'Связь';

  @override
  String get widgetBuilderIconCategoryConnectivity => 'Подключение';

  @override
  String get widgetBuilderIconCategoryDataCharts => 'Данные и графики';

  @override
  String get widgetBuilderIconCategoryEnvironment => 'Окружающая среда';

  @override
  String get widgetBuilderIconCategoryFavorites => 'Избранное';

  @override
  String get widgetBuilderIconCategoryLocationMaps => 'Местоположение и карты';

  @override
  String get widgetBuilderIconCategoryStatus => 'Статус';

  @override
  String get widgetBuilderIconCharging => 'Зарядка';

  @override
  String get widgetBuilderIconChart => 'График';

  @override
  String get widgetBuilderIconChat => 'Чат';

  @override
  String get widgetBuilderIconCheck => 'Галочка';

  @override
  String get widgetBuilderIconCloud => 'Облако';

  @override
  String get widgetBuilderIconDelete => 'Удалить';

  @override
  String get widgetBuilderIconDevices => 'Устройства';

  @override
  String get widgetBuilderIconDown => 'Вниз';

  @override
  String get widgetBuilderIconEdit => 'Изменить';

  @override
  String get widgetBuilderIconError => 'Ошибка';

  @override
  String get widgetBuilderIconExplore => 'Обзор';

  @override
  String get widgetBuilderIconFlash => 'Вспышка';

  @override
  String get widgetBuilderIconFull => 'Полный';

  @override
  String get widgetBuilderIconGps => 'GPS';

  @override
  String get widgetBuilderIconHeart => 'Сердце';

  @override
  String get widgetBuilderIconHelp => 'Помощь';

  @override
  String get widgetBuilderIconHub => 'Концентратор';

  @override
  String get widgetBuilderIconHumidity => 'Влажность';

  @override
  String get widgetBuilderIconInfo => 'Инфо';

  @override
  String get widgetBuilderIconLocation => 'Местоположение';

  @override
  String get widgetBuilderIconMap => 'Карта';

  @override
  String get widgetBuilderIconMessage => 'Сообщение';

  @override
  String get widgetBuilderIconNavigate => 'Навигация';

  @override
  String get widgetBuilderIconNearMe => 'Рядом со мной';

  @override
  String get widgetBuilderIconNetwork => 'Сеть';

  @override
  String get widgetBuilderIconNotification => 'Уведомление';

  @override
  String get widgetBuilderIconPower => 'Питание';

  @override
  String get widgetBuilderIconPressure => 'Давление';

  @override
  String get widgetBuilderIconRefresh => 'Обновить';

  @override
  String get widgetBuilderIconRemove => 'Удалить';

  @override
  String get widgetBuilderIconRoute => 'Маршрут';

  @override
  String get widgetBuilderIconRouter => 'Маршрутизатор';

  @override
  String get widgetBuilderIconSend => 'Отправить';

  @override
  String get widgetBuilderIconSettings => 'Настройки';

  @override
  String get widgetBuilderIconSignal => 'Сигнал';

  @override
  String get widgetBuilderIconSpeed => 'Скорость';

  @override
  String get widgetBuilderIconStar => 'Звезда';

  @override
  String get widgetBuilderIconSun => 'Солнце';

  @override
  String get widgetBuilderIconTemperature => 'Температура';

  @override
  String get widgetBuilderIconThumbsUp => 'Нравится';

  @override
  String get widgetBuilderIconTimeline => 'История';

  @override
  String get widgetBuilderIconUp => 'Вверх';

  @override
  String get widgetBuilderIconWarning => 'Предупреждение';

  @override
  String get widgetBuilderIconWifi => 'WiFi';

  @override
  String get widgetBuilderImportButton => 'Импорт';

  @override
  String get widgetBuilderImportEditFirst => 'Сначала изменить';

  @override
  String get widgetBuilderImportFailed2 => 'Ошибка импорта';

  @override
  String get widgetBuilderImportGoBack => 'Назад';

  @override
  String get widgetBuilderImportInfoNotice =>
      'Этот виджет будет добавлен в ваши пользовательские виджеты. Вы можете изменить его в любое время.';

  @override
  String get widgetBuilderImportNoData => 'Данные виджета не предоставлены';

  @override
  String get widgetBuilderImportNotFound => 'Виджет не найден или был удалён';

  @override
  String get widgetBuilderImportPreview => 'Предпросмотр';

  @override
  String get widgetBuilderImportSize => 'Размер';

  @override
  String get widgetBuilderImportTags => 'Теги';

  @override
  String get widgetBuilderImportTitle => 'Импорт виджета';

  @override
  String get widgetBuilderImportedSuccess => 'Виджет успешно импортирован';

  @override
  String get widgetBuilderImportedSuccessAction =>
      'Виджет успешно импортирован';

  @override
  String widgetBuilderInstalledSuccess(String name) {
    return '$name установлен!';
  }

  @override
  String get widgetBuilderKeepCurrent => 'Оставить текущий';

  @override
  String get widgetBuilderLabelAccent => 'Акцент';

  @override
  String get widgetBuilderLabelBindTo => 'Привязать к';

  @override
  String get widgetBuilderLabelGap => 'Отступ между элементами';

  @override
  String get widgetBuilderLabelHintExample =>
      'например, «Предупреждение», «Критично»';

  @override
  String get widgetBuilderLabelIcon => 'Значок';

  @override
  String get widgetBuilderLabelIconColor => 'Цвет значка';

  @override
  String get widgetBuilderLabelMax => 'Макс.';

  @override
  String get widgetBuilderLabelMin => 'Мин.';

  @override
  String get widgetBuilderLabelScreen => 'Экран';

  @override
  String get widgetBuilderLabelShape => 'Форма';

  @override
  String get widgetBuilderLabelText => 'Текст';

  @override
  String get widgetBuilderLabelType => 'Тип';

  @override
  String get widgetBuilderLabelUrl => 'URL';

  @override
  String get widgetBuilderLargeMaxTwoRows =>
      'Большие виджеты допускают не более 2 строк';

  @override
  String get widgetBuilderLargeOnlyTwoRowsMax =>
      'Большие виджеты допускают не более 2 строк';

  @override
  String get widgetBuilderLivePreview => 'Предпросмотр в реальном времени';

  @override
  String get widgetBuilderLocationSharedMesh =>
      'Местоположение передано в сеть';

  @override
  String get widgetBuilderLocationSharedRecently =>
      'Местоположение было недавно передано — подождите перед повторной отправкой';

  @override
  String widgetBuilderLocationSharedWithNode(String name) {
    return 'Местоположение передано ноде $name';
  }

  @override
  String get widgetBuilderMakeUnique =>
      'Сделайте виджет более уникальным перед отправкой.';

  @override
  String get widgetBuilderMapView => 'Вид карты';

  @override
  String get widgetBuilderMarketplace => 'Маркетплейс';

  @override
  String get widgetBuilderMarketplaceAlreadyInstalled => 'Уже установлен';

  @override
  String get widgetBuilderMarketplaceApprove => 'Одобрить';

  @override
  String get widgetBuilderMarketplaceCancel => 'Отмена';

  @override
  String get widgetBuilderMarketplaceDescription => 'Описание';

  @override
  String widgetBuilderMarketplaceRatingWithCount(String rating, int count) {
    return '$rating ($count)';
  }

  @override
  String get widgetBuilderMarketplaceEnterReason => 'Укажите причину...';

  @override
  String widgetBuilderMarketplaceFailedLoadPending(String error) {
    return 'Не удалось загрузить ожидающие виджеты: $error';
  }

  @override
  String get widgetBuilderMarketplaceFailedLoadCategory =>
      'Не удалось загрузить категорию';

  @override
  String get widgetBuilderMarketplaceFailedNewest =>
      'Не удалось загрузить новые виджеты';

  @override
  String get widgetBuilderMarketplaceFailedPopular =>
      'Не удалось загрузить популярные виджеты';

  @override
  String get widgetBuilderMarketplaceFavoritesHint =>
      'Нажмите на значок сердца на любом виджете, чтобы добавить его сюда';

  @override
  String widgetBuilderMarketplaceFavoritesWithCount(int count) {
    return 'Избранное ($count)';
  }

  @override
  String get widgetBuilderMarketplaceHelpTooltip => 'Помощь';

  @override
  String get widgetBuilderMarketplaceInstallWidget => 'Установить виджет';

  @override
  String widgetBuilderMarketplaceDaysAgo(int count) {
    return '$count д. назад';
  }

  @override
  String widgetBuilderMarketplaceHoursAgo(int count) {
    return '$count ч. назад';
  }

  @override
  String widgetBuilderMarketplaceInstallsCount(int count) {
    return '$count установок';
  }

  @override
  String get widgetBuilderMarketplaceJustNow => 'Только что';

  @override
  String widgetBuilderMarketplaceMinutesAgo(int count) {
    return '$count мин. назад';
  }

  @override
  String get widgetBuilderMarketplaceLoadingPreview =>
      'Загрузка предпросмотра...';

  @override
  String get widgetBuilderMarketplaceNoFavorites => 'Нет избранных виджетов';

  @override
  String get widgetBuilderMarketplaceNoFeatured => 'Нет рекомендуемых виджетов';

  @override
  String get widgetBuilderMarketplaceNoNew => 'Новых виджетов пока нет';

  @override
  String get widgetBuilderMarketplaceNoPending =>
      'Нет виджетов, ожидающих проверки';

  @override
  String get widgetBuilderMarketplaceNoPopular =>
      'Популярных виджетов пока нет';

  @override
  String get widgetBuilderMarketplaceNoWidgets => 'Нет доступных виджетов';

  @override
  String get widgetBuilderMarketplaceNoWidgetsFound => 'Виджеты не найдены';

  @override
  String get widgetBuilderMarketplaceNoWidgetsInCategory =>
      'В этой категории нет виджетов';

  @override
  String get widgetBuilderMarketplaceNotAuthenticated => 'Не авторизован';

  @override
  String get widgetBuilderMarketplacePending => 'НА ПРОВЕРКЕ';

  @override
  String get widgetBuilderMarketplacePleaseEnterReason =>
      'Пожалуйста, укажите причину';

  @override
  String get widgetBuilderMarketplaceProcessing => 'Обработка...';

  @override
  String get widgetBuilderMarketplaceRejectButton => 'Отклонить';

  @override
  String get widgetBuilderMarketplaceRejectWidget => 'Отклонить виджет';

  @override
  String get widgetBuilderMarketplaceRequiresInternet =>
      'Для установки виджетов необходимо подключение к интернету.';

  @override
  String get widgetBuilderMarketplaceRetry => 'Повторить';

  @override
  String get widgetBuilderMarketplaceSearchHint => 'Поиск виджетов...';

  @override
  String get widgetBuilderMarketplaceShareTooltip => 'Поделиться виджетом';

  @override
  String get widgetBuilderMarketplaceSharingRequiresInternet =>
      'Для публикации виджетов необходимо подключение к интернету.';

  @override
  String get widgetBuilderMarketplaceTabCategories => 'Категории';

  @override
  String get widgetBuilderMarketplaceTabFavorites => 'Избранное';

  @override
  String get widgetBuilderMarketplaceTabFeatured => 'Рекомендуемые';

  @override
  String get widgetBuilderMarketplaceTabNew => 'Новые';

  @override
  String get widgetBuilderMarketplaceTabPopular => 'Популярные';

  @override
  String get widgetBuilderMarketplaceTags => 'Теги';

  @override
  String get widgetBuilderMarketplaceTitle => 'Маркетплейс виджетов';

  @override
  String get widgetBuilderMarketplaceUnableToLoad =>
      'Не удалось загрузить маркетплейс';

  @override
  String get widgetBuilderMarketplaceWidgetApproval => 'Проверка виджета';

  @override
  String get widgetBuilderMediumOnlyOneRow =>
      'Средние виджеты допускают только 1 строку';

  @override
  String get widgetBuilderMediumOnlyOneRowLimit =>
      'Средние виджеты допускают только 1 строку';

  @override
  String get widgetBuilderMerge => 'Объединить';

  @override
  String get widgetBuilderMyWidgets => 'Мои виджеты';

  @override
  String get widgetBuilderNameHint => 'например, Мой виджет батареи';

  @override
  String get widgetBuilderNewWidget => 'Новый виджет';

  @override
  String get widgetBuilderNoAdditionalOptions =>
      'Нет дополнительных параметров';

  @override
  String get widgetBuilderNoDataBinding =>
      'Нет привязки данных — используется статический текст';

  @override
  String get widgetBuilderNoDataSelected => 'Данные не выбраны';

  @override
  String get widgetBuilderNoIconsFound => 'Значки не найдены';

  @override
  String get widgetBuilderNoInfoSelected => 'Информация не выбрана';

  @override
  String get widgetBuilderNoLocationDataSelected =>
      'Данные о местоположении не выбраны';

  @override
  String get widgetBuilderNoSensorDataSelected => 'Данные датчиков не выбраны';

  @override
  String get widgetBuilderNone => 'Нет';

  @override
  String get widgetBuilderOk => 'ОК';

  @override
  String get widgetBuilderOptions => 'Параметры';

  @override
  String get widgetBuilderPickNodeThenSend => 'Выберите ноду, затем отправьте';

  @override
  String get widgetBuilderPickNodeToTrace => 'Выберите ноду для трассировки';

  @override
  String get widgetBuilderPrebuiltWidgets => 'Готовые виджеты для настройки';

  @override
  String get widgetBuilderQuickMessageSheet => 'Быстрая отправка сообщения';

  @override
  String get widgetBuilderQuickStartTemplates => 'Шаблоны для быстрого старта';

  @override
  String widgetBuilderRejectedSuccess(String name) {
    return '$name отклонён';
  }

  @override
  String get widgetBuilderRemoveExtraRows =>
      'Сначала удалите лишние строки — средний размер допускает только 1 строку';

  @override
  String get widgetBuilderRemoveFromDashboard => 'Убрать с панели';

  @override
  String widgetBuilderRemovedFromDashboard(String name) {
    return '$name удалён с панели';
  }

  @override
  String get widgetBuilderReviewGuidelines => 'Правила проверки';

  @override
  String get widgetBuilderReviewGuidelinesText =>
      '• Виджет будет проверен на качество\n• Похожие виджеты могут быть отклонены\n• Вы будете указаны как автор';

  @override
  String get widgetBuilderSave => 'Сохранить';

  @override
  String get widgetBuilderSearchIcons => 'Поиск значков...';

  @override
  String get widgetBuilderSearchVariables => 'Поиск переменных...';

  @override
  String get widgetBuilderSectionActionBlocks => 'Блоки действий';

  @override
  String get widgetBuilderSectionDisplayBlocks => 'Блоки отображения';

  @override
  String get widgetBuilderSectionEmergency => 'ЭКСТРЕННЫЕ';

  @override
  String get widgetBuilderSectionLayout => 'Макет';

  @override
  String get widgetBuilderSectionMessaging => 'СООБЩЕНИЯ';

  @override
  String get widgetBuilderSectionNetwork => 'СЕТЬ';

  @override
  String get widgetBuilderSelectAnAction => 'Выберите действие';

  @override
  String get widgetBuilderSelectIcon => 'Выбрать значок';

  @override
  String get widgetBuilderSelectVariable => 'Выбрать переменную';

  @override
  String get widgetBuilderShareInfoText =>
      'Отсканируйте этот QR-код в Socialmesh, чтобы импортировать виджет';

  @override
  String get widgetBuilderShareLocationWith => 'Поделиться местоположением с';

  @override
  String get widgetBuilderShareMessage =>
      'Посмотрите этот виджет в Socialmesh!';

  @override
  String widgetBuilderShareSubject(String name) {
    return 'Виджет Socialmesh: $name';
  }

  @override
  String get widgetBuilderShareTitle => 'Поделиться виджетом';

  @override
  String get widgetBuilderShowChannelPicker => 'Показать выбор канала';

  @override
  String get widgetBuilderShowChannelPickerDesc =>
      'Позволить пользователю выбрать канал';

  @override
  String get widgetBuilderShowNodePickerFirst => 'Сначала показать выбор ноды';

  @override
  String get widgetBuilderShowNodePickerFirstDesc =>
      'Позволить пользователю выбрать ноду для сообщения';

  @override
  String get widgetBuilderShowNodePickerTrace => 'Сначала показать выбор ноды';

  @override
  String get widgetBuilderShowNodePickerTraceDesc =>
      'Позволить пользователю выбрать ноду для трассировки';

  @override
  String get widgetBuilderSignInAction => 'Войти';

  @override
  String get widgetBuilderSignInToShare => 'Войдите, чтобы делиться виджетами';

  @override
  String get widgetBuilderSignInToSubmit =>
      'Войдите, чтобы публиковать виджеты';

  @override
  String get widgetBuilderSimilarWidgetExists =>
      'Похожий виджет уже есть в маркетплейсе:';

  @override
  String widgetBuilderSimilarWidgetExistsError(String name) {
    return 'Похожий виджет уже существует: $name';
  }

  @override
  String get widgetBuilderSimilarWidgetFound => 'Найден похожий виджет';

  @override
  String get widgetBuilderSizeCustom => 'Произвольный размер';

  @override
  String get widgetBuilderSizeLarge => 'Большой (2×2)';

  @override
  String get widgetBuilderSizeMedium => 'Средний (2×1)';

  @override
  String get widgetBuilderSubmitButton => 'Отправить';

  @override
  String get widgetBuilderSubmitCancel => 'Отмена';

  @override
  String get widgetBuilderSubmitTitle => 'Отправить в маркетплейс';

  @override
  String get widgetBuilderSubmitToMarketplace => 'Отправить в маркетплейс';

  @override
  String widgetBuilderSubmittedForReview(String name) {
    return '$name отправлен на проверку';
  }

  @override
  String get widgetBuilderSwitch => 'Переключить';

  @override
  String widgetBuilderSwitchTemplateIncompatible(
    String templateName,
    String newDataType,
  ) {
    return '«$templateName» использует $newDataType, поэтому текущие выборы не будут применены.';
  }

  @override
  String widgetBuilderSwitchTemplateItemCount(int count, String dataType) {
    return 'Вы выбрали $count $dataType.';
  }

  @override
  String get widgetBuilderSwitchTemplateTitle => 'Сменить шаблон?';

  @override
  String get widgetBuilderTemplateBatteryStatus => 'Статус батареи';

  @override
  String get widgetBuilderTemplateBatteryStatusDesc =>
      'Мониторинг уровня заряда';

  @override
  String get widgetBuilderTemplateEnvironment => 'Окружающая среда';

  @override
  String get widgetBuilderTemplateEnvironmentDesc => 'Погода и датчики';

  @override
  String get widgetBuilderTemplateGpsPosition => 'GPS-позиция';

  @override
  String get widgetBuilderTemplateGpsPositionDesc =>
      'Отслеживание местоположения';

  @override
  String get widgetBuilderTemplateNetworkOverview => 'Обзор сети';

  @override
  String get widgetBuilderTemplateNetworkOverviewDesc =>
      'Состояние сети с первого взгляда';

  @override
  String get widgetBuilderTemplateSignalStrength => 'Уровень сигнала';

  @override
  String get widgetBuilderTemplateSignalStrengthDesc =>
      'Отслеживание подключения';

  @override
  String get widgetBuilderThresholdLines => 'Пороговые линии';

  @override
  String get widgetBuilderToggleToolbox =>
      'Показать/скрыть панель инструментов';

  @override
  String get widgetBuilderTraceRouteToNode => 'Трассировать маршрут до ноды';

  @override
  String get widgetBuilderTypeDecimal => 'десятичное';

  @override
  String get widgetBuilderTypeGauge => 'Шкала';

  @override
  String get widgetBuilderTypeGaugeDesc => 'Большой визуальный индикатор';

  @override
  String get widgetBuilderTypeGraph => 'График';

  @override
  String get widgetBuilderTypeGraphDesc => 'Диаграммы по времени';

  @override
  String get widgetBuilderTypeInfoCard => 'Информационная карточка';

  @override
  String get widgetBuilderTypeInfoCardDesc => 'Текст и подробности';

  @override
  String get widgetBuilderTypeLocation => 'Местоположение';

  @override
  String get widgetBuilderTypeLocationDesc => 'GPS-координаты';

  @override
  String get widgetBuilderTypeNumber => 'число';

  @override
  String get widgetBuilderTypeQuickActions => 'Быстрые действия';

  @override
  String get widgetBuilderTypeQuickActionsDesc => 'Нажмите для запуска';

  @override
  String get widgetBuilderTypeStatusDisplay => 'Отображение статуса';

  @override
  String get widgetBuilderTypeStatusDisplayDesc =>
      'Значения с индикаторами прогресса';

  @override
  String get widgetBuilderTypeText => 'текст';

  @override
  String get widgetBuilderTypeTime => 'время';

  @override
  String get widgetBuilderTypeValue => 'значение';

  @override
  String get widgetBuilderTypeYesNo => 'да/нет';

  @override
  String get widgetBuilderUnableToGetLocation =>
      'Не удалось определить ваше местоположение';

  @override
  String get widgetBuilderUse => 'Использовать';

  @override
  String get widgetBuilderValidationActionsRequired =>
      'Для быстрых действий необходимо выбрать хотя бы одно действие. Привязки данных заданы, но действия не выбраны.';

  @override
  String get widgetBuilderValidationDataRequired =>
      'Для этого шаблона необходима привязка данных. Действия выбраны, но данные не заданы.';

  @override
  String get widgetBuilderView => 'Просмотр';

  @override
  String get widgetBuilderWhatShouldHappen =>
      'Что должно произойти при нажатии?';

  @override
  String get widgetBuilderWhatToAdd => 'Что вы хотите добавить?';

  @override
  String get widgetBuilderWhatWouldYouLikeToDo => 'Что вы хотите сделать?';

  @override
  String get widgetBuilderWidgetCreated => 'Виджет создан!';

  @override
  String get widgetBuilderWidgetName => 'Название виджета';

  @override
  String get widgetBuilderWidgetTypes => 'Типы виджетов';

  @override
  String get widgetBuilderWidgetUpdated => 'Виджет обновлён!';

  @override
  String get widgetBuilderWizardStep1Subtitle =>
      'Как должен выглядеть ваш виджет?';

  @override
  String get widgetBuilderWizardStep1Title => 'Выберите стиль';

  @override
  String get widgetBuilderWizardStep2Subtitle =>
      'Придумайте запоминающееся название';

  @override
  String get widgetBuilderWizardStep2Title => 'Назовите виджет';

  @override
  String get widgetBuilderWizardStep3SubtitleActions =>
      'К каким действиям нужен быстрый доступ?';

  @override
  String get widgetBuilderWizardStep3SubtitleData =>
      'Какую информацию вы хотите видеть?';

  @override
  String get widgetBuilderWizardStep3TitleActions => 'Выберите действия';

  @override
  String get widgetBuilderWizardStep3TitleData => 'Выберите данные';

  @override
  String get widgetBuilderWizardStep4Subtitle => 'Настройте цвета и макет';

  @override
  String get widgetBuilderWizardStep4Title => 'Сделайте его своим';

  @override
  String get worldMeshAddToFavorites => 'Добавить в избранное';

  @override
  String get worldMeshAddedToFavorites => 'Добавлено в избранное';

  @override
  String get worldMeshBadgeActive => 'АКТИВЕН';

  @override
  String get worldMeshCoordinatesCopied =>
      'Координаты скопированы в буфер обмена';

  @override
  String get worldMeshCopyCoordinates => 'Копировать координаты';

  @override
  String get worldMeshCopyCoordinatesSubtitle => 'Координаты обеих точек A и B';

  @override
  String get worldMeshCopyId => 'Копировать ID';

  @override
  String get worldMeshCopySummary => 'Копировать сводку';

  @override
  String get worldMeshErrorTitle => 'Не удалось загрузить карту сети Mesh';

  @override
  String get worldMeshExitMeasureMode => 'Выйти из режима измерения';

  @override
  String get worldMeshFavoritesTooltip => 'Избранное';

  @override
  String worldMeshFilterActiveCount(int count) {
    return '$count активных';
  }

  @override
  String get worldMeshFilterAny => 'Любой';

  @override
  String get worldMeshFilterBatteryInfo => 'Сведения о батарее';

  @override
  String get worldMeshFilterCatBatteryInfo => 'Сведения о батарее';

  @override
  String get worldMeshFilterCatEnvSensors => 'Датчики окружающей среды';

  @override
  String get worldMeshFilterCatFirmware => 'Прошивка';

  @override
  String get worldMeshFilterCatHardware => 'Аппаратное обеспечение';

  @override
  String get worldMeshFilterCatModemPreset => 'Пресет модема';

  @override
  String get worldMeshFilterCatRegion => 'Регион';

  @override
  String get worldMeshFilterCatRole => 'Роль';

  @override
  String get worldMeshFilterCatStatus => 'Статус';

  @override
  String get worldMeshFilterClearAll => 'Очистить всё';

  @override
  String get worldMeshFilterEnvironmentSensors => 'Датчики окружающей среды';

  @override
  String get worldMeshFilterFirmwareVersion => 'Версия прошивки';

  @override
  String get worldMeshFilterHardwareModel => 'Модель оборудования';

  @override
  String get worldMeshFilterModemPreset => 'Пресет модема';

  @override
  String get worldMeshFilterNo => 'Нет';

  @override
  String get worldMeshFilterNoOptions => 'Нет доступных вариантов';

  @override
  String worldMeshFilterNodeCount(int filteredCount, int totalCount) {
    return '$filteredCount из $totalCount нод';
  }

  @override
  String get worldMeshFilterNodeRole => 'Роль ноды';

  @override
  String worldMeshFilterNodesWithBattery(int count) {
    return '$count нод с данными о батарее';
  }

  @override
  String worldMeshFilterNodesWithSensors(int count) {
    return '$count нод с датчиками';
  }

  @override
  String get worldMeshFilterRegion => 'Регион';

  @override
  String get worldMeshFilterStatus => 'Статус';

  @override
  String get worldMeshFilterStatusActive => 'Активен (≤2 мин)';

  @override
  String get worldMeshFilterStatusFading => 'Затухает (2–10 мин)';

  @override
  String get worldMeshFilterStatusInactive => 'Неактивен (10–60 мин)';

  @override
  String get worldMeshFilterStatusUnknown => 'Неизвестно (>60 мин)';

  @override
  String get worldMeshFilterTitle => 'Фильтр нод';

  @override
  String get worldMeshFilterTooltip => 'Фильтровать ноды';

  @override
  String get worldMeshFilterYes => 'Да';

  @override
  String get worldMeshFocus => 'Фокус';

  @override
  String worldMeshFsplSubtitle(String db) {
    return 'FSPL: $db дБ';
  }

  @override
  String get worldMeshHelp => 'Справка';

  @override
  String get worldMeshInfoAltitude => 'Высота';

  @override
  String get worldMeshInfoCoordinates => 'Координаты';

  @override
  String get worldMeshInfoFirmware => 'Прошивка';

  @override
  String get worldMeshInfoHardware => 'Оборудование';

  @override
  String get worldMeshInfoLocalNodes => 'Локальные ноды';

  @override
  String get worldMeshInfoModem => 'Модем';

  @override
  String get worldMeshInfoPrecision => 'Точность';

  @override
  String get worldMeshInfoRegion => 'Регион';

  @override
  String get worldMeshInfoRole => 'Роль';

  @override
  String worldMeshLastSeen(String time) {
    return 'Последний раз: $time';
  }

  @override
  String get worldMeshLegendActive => 'Активен (<1 ч)';

  @override
  String get worldMeshLegendIdle => 'Простаивает (1–24 ч)';

  @override
  String get worldMeshLegendOffline => 'Офлайн (>24 ч)';

  @override
  String get worldMeshLinkBudgetCopied =>
      'Энергетический бюджет скопирован в буфер обмена';

  @override
  String get worldMeshLoadingNodeInfo => 'Загрузка информации о ноде...';

  @override
  String get worldMeshLongPressHint => 'Удерживайте для вызова действий';

  @override
  String get worldMeshLosAnalysis => 'Анализ прямой видимости';

  @override
  String worldMeshLosBulgeAndFresnel(String bulge, String fresnel) {
    return 'Выпуклость: $bulge м · F1: $fresnel м';
  }

  @override
  String get worldMeshLosSubtitle => 'Проверка кривизны Земли и зоны Френеля';

  @override
  String worldMeshLosVerdict(String verdict) {
    return 'LOS: $verdict';
  }

  @override
  String get worldMeshMapStyleDark => 'Тёмная карта';

  @override
  String get worldMeshMapStyleLight => 'Светлая карта';

  @override
  String get worldMeshMapStyleSatellite => 'Спутник';

  @override
  String get worldMeshMapStyleTerrain => 'Рельеф';

  @override
  String get worldMeshMeasurePointA => 'A';

  @override
  String get worldMeshMeasurePointB => 'B';

  @override
  String get worldMeshMeasureTapA => 'Нажмите на ноду или карту для точки A';

  @override
  String get worldMeshMeasureTapB => 'Нажмите на ноду или карту для точки B';

  @override
  String get worldMeshMeasurementActions => 'Действия с измерением';

  @override
  String get worldMeshMeasurementCopied =>
      'Измерение скопировано в буфер обмена';

  @override
  String worldMeshMoreGateways(int count) {
    return ' +$count ещё';
  }

  @override
  String get worldMeshNewMeasurement => 'Новое измерение';

  @override
  String get worldMeshNodeIdCopied => 'ID ноды скопирован';

  @override
  String get worldMeshOpenMidpointInMaps => 'Открыть середину в картах';

  @override
  String get worldMeshOpenMidpointSubtitle =>
      'Открыть во внешнем картографическом приложении';

  @override
  String get worldMeshRefresh => 'Обновить';

  @override
  String get worldMeshRefreshing => 'Обновление данных мировой сети Mesh...';

  @override
  String get worldMeshRemoveFromFavorites => 'Удалить из избранного';

  @override
  String get worldMeshRemovedFromFavorites => 'Удалено из избранного';

  @override
  String get worldMeshRetry => 'Повторить';

  @override
  String get worldMeshRfLinkBudget => 'Энергетический бюджет RF';

  @override
  String worldMeshRfLinkBudgetClipboard(
    String distance,
    String frequency,
    String pathLoss,
    String linkMargin,
  ) {
    return 'Энергетический бюджет RF (потери в свободном пространстве)\nРасстояние: $distance\nЧастота: $frequency\nПотери пути: $pathLoss\nЗапас линии: $linkMargin';
  }

  @override
  String get worldMeshScrollForMore => 'Прокрутите для просмотра...';

  @override
  String get worldMeshSearchHint => 'Найти ноду';

  @override
  String worldMeshSearchResultCount(int count) {
    return '$count результатов';
  }

  @override
  String get worldMeshSectionDevice => 'Устройство';

  @override
  String get worldMeshSectionDeviceMetrics => 'Метрики устройства';

  @override
  String get worldMeshSectionEnvironment => 'Окружающая среда';

  @override
  String worldMeshSectionNeighbors(int count) {
    return 'Соседи ($count)';
  }

  @override
  String get worldMeshSectionPosition => 'Позиция';

  @override
  String worldMeshSectionSeenBy(int count) {
    return 'Обнаружен ($count шлюзами)';
  }

  @override
  String get worldMeshStatsFiltered => 'отфильтровано';

  @override
  String get worldMeshStatsTotal => 'всего';

  @override
  String get worldMeshStatsVisible => 'видимых';

  @override
  String get worldMeshSwapAB => 'Поменять A ↔ B';

  @override
  String get worldMeshSwapSubtitle =>
      'Изменить направление измерения на обратное';

  @override
  String worldMeshTimeHoursAgo(int hours) {
    return '$hours ч назад';
  }

  @override
  String get worldMeshTimeJustNow => 'только что';

  @override
  String worldMeshTimeMinutesAgo(int minutes) {
    return '$minutes мин назад';
  }

  @override
  String get worldMeshTitle => 'Мировая карта';

  @override
  String worldMeshUptimeLabel(String uptime) {
    return 'Время работы: $uptime';
  }

  @override
  String get deepLinkLoadingSignal => 'Загрузка сигнала';

  @override
  String deepLinkErrorLoadingSignal(String error) {
    return 'Ошибка загрузки сигнала: $error';
  }

  @override
  String get deepLinkSignalNotFound => 'Сигнал не найден';

  @override
  String get deepLinkLoadingFlight => 'Загрузка рейса';

  @override
  String deepLinkErrorLoadingFlight(String error) {
    return 'Ошибка загрузки рейса: $error';
  }

  @override
  String get deepLinkFlightNotFound => 'Рейс не найден';

  @override
  String get deepLinkImportChannel => 'Импортировать канал';

  @override
  String deepLinkErrorLoadingChannel(String error) {
    return 'Ошибка загрузки канала: $error';
  }

  @override
  String get deepLinkChannelNotAvailable => 'Канал недоступен';

  @override
  String get deepLinkChannelNotAvailableDescription =>
      'Возможно, у вас нет доступа к этому каналу,\nили владелец должен поделиться им повторно.';

  @override
  String get deepLinkJoinChannel => 'Присоединиться к каналу';

  @override
  String get deepLinkJoiningChannel => 'Присоединение к каналу...';

  @override
  String get deepLinkInviteExpired => 'Срок действия этого приглашения истёк';

  @override
  String get deepLinkInviteRevoked => 'Это приглашение было отозвано';

  @override
  String get deepLinkInviteUsageLimitReached =>
      'Это приглашение достигло лимита использования';

  @override
  String get deepLinkInviteLinkInvalid => 'Недействительная ссылка приглашения';

  @override
  String get deepLinkChannelNoLongerExists => 'Этот канал больше не существует';

  @override
  String get deepLinkInviteNotFound => 'Приглашение не найдено';

  @override
  String get deepLinkPleaseSignIn =>
      'Пожалуйста, войдите, чтобы присоединиться';

  @override
  String get deepLinkFailedToJoinChannel =>
      'Не удалось присоединиться к каналу';

  @override
  String get deepLinkLoadingWidget => 'Загрузка виджета';

  @override
  String deepLinkErrorLoadingWidget(String error) {
    return 'Ошибка загрузки виджета: $error';
  }

  @override
  String get deepLinkSomethingWentWrong => 'Что-то пошло не так';

  @override
  String deepLinkProfileTitle(String displayName) {
    return '@$displayName';
  }

  @override
  String get deepLinkCloudServicesNotAvailable =>
      'Облачные сервисы пока недоступны';

  @override
  String deepLinkErrorLookingUpUser(String error) {
    return 'Ошибка поиска пользователя: $error';
  }

  @override
  String deepLinkUserNotFound(String displayName) {
    return 'Пользователь «@$displayName» не найден';
  }

  @override
  String get blockedRouteDeviceRequired => 'Требуется устройство';

  @override
  String get blockedRouteConnectDevice =>
      'Подключите устройство для доступа к этому экрану';

  @override
  String get blockedRouteDeviceReset => 'Устройство сброшено';

  @override
  String get blockedRouteDeviceNotConnected => 'Устройство не подключено';

  @override
  String get blockedRouteDeviceResetDescription =>
      'Ваше устройство было сброшено до заводских настроек или заменено.\n\nПерейдите в Настройки → Bluetooth и удалите устройство';

  @override
  String get blockedRouteScanForDevices => 'Сканировать устройства';

  @override
  String get blockedRouteConnectDeviceButton => 'Подключить устройство';

  @override
  String get deepLinkWidgetNotFound => 'Виджет не найден';

  @override
  String get deepLinkAlreadyHaveChannel => 'У вас уже есть этот канал';

  @override
  String get transformableTextDeleteTitle => 'Удалить текст?';

  @override
  String get transformableTextDeleteMessage => 'Это удалит текстовый оверлей.';

  @override
  String get transformableTextDeleteConfirm => 'Удалить';

  @override
  String get transformableTextDone => 'Готово';

  @override
  String get transformableTextHint => 'Введите что-нибудь...';

  @override
  String get qrSharePreparingLink => 'Подготовка ссылки для шаринга...';

  @override
  String get qrShareSharing => 'Отправка...';

  @override
  String get qrShareShareLink => 'Поделиться ссылкой';

  @override
  String get qrShareCopyLink => 'Копировать ссылку';

  @override
  String qrShareFailedToShare(String error) {
    return 'Не удалось поделиться: $error';
  }

  @override
  String get qrShareLinkCopied => 'Ссылка скопирована в буфер обмена';

  @override
  String get legalDocumentTermsOfService => 'Условия использования';

  @override
  String get legalDocumentPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get legalDocumentHelpAndSupport => 'Помощь и поддержка';

  @override
  String get legalDocumentDocumentation => 'Документация';

  @override
  String get legalDocumentFaq => 'FAQ';

  @override
  String get legalDocumentDeleteAccount => 'Удалить аккаунт';

  @override
  String get legalDocumentUnableToLoad => 'Не удалось загрузить страницу';

  @override
  String get legalDocumentRequiresInternet =>
      'Для этого содержимого требуется подключение к Интернету. Проверьте подключение и попробуйте снова.';

  @override
  String get legalDocumentGoBack => 'Назад';

  @override
  String get legalDocumentRefresh => 'Обновить';

  @override
  String get channelKeyEncryptionKey => 'Ключ шифрования';

  @override
  String get channelKeyEnterBase64 => 'Введите ключ в кодировке base64';

  @override
  String get channelKeyBase64Encoded => 'Кодировка base64';

  @override
  String get channelKeyHint => 'Например: AQ== или AAAAAAAAAAAAAAAAAAAAAA==';

  @override
  String get channelKeyNoKeySet => '(ключ не задан)';

  @override
  String get channelKeyHide => 'Скрыть';

  @override
  String get channelKeyShow => 'Показать';

  @override
  String get channelKeyEdit => 'Изменить';

  @override
  String get channelKeyGenerate => 'Сгенерировать';

  @override
  String get channelKeyNewGenerated => 'Новый ключ сгенерирован';

  @override
  String get channelKeyCopy => 'Копировать';

  @override
  String get channelKeyCopied => 'Ключ скопирован в буфер обмена';

  @override
  String get remoteAdminTitle => 'Удалённое администрирование';

  @override
  String get remoteAdminSearchHint => 'Поиск нод...';

  @override
  String get remoteAdminConnectedDevice => 'Подключённое устройство';

  @override
  String get remoteAdminLocalVia => 'Локально (через BLE/USB)';

  @override
  String get remoteAdminPkiEnabledNodes => 'УЗЛЫ С PKI';

  @override
  String remoteAdminNodesAvailable(int count) {
    return '$count доступно';
  }

  @override
  String get remoteAdminRequiresPki =>
      'Для удалённого администрирования целевая нода должен иметь ваш публичный ключ в списке Admin Keys.';

  @override
  String get remoteAdminNoNodes => 'Нет нод с включённым PKI';

  @override
  String remoteAdminNoMatchingNodes(String query) {
    return 'Нет нод, соответствующих запросу «$query»';
  }

  @override
  String get remoteAdminNodesNeedPki =>
      'Нодам требуется включённое PKI-шифрование\nдля принятия команд удалённого администрирования';

  @override
  String get remoteAdminPkiEnabled => '• PKI включено';

  @override
  String get contentModerationNotAllowedTitle => 'Контент не разрешён';

  @override
  String get contentModerationMayViolateTitle =>
      'Контент может нарушать правила';

  @override
  String get contentModerationBlockedMessage =>
      'Ваш контент нарушает наши Правила сообщества и не может быть опубликован.';

  @override
  String get contentModerationWarningMessage =>
      'Ваш контент может нарушать наши Правила сообщества. Пожалуйста, проверьте перед публикацией.';

  @override
  String get contentModerationIssuesDetected => 'Обнаружены нарушения';

  @override
  String get contentModerationRepeatedViolations =>
      'Повторные нарушения могут привести к ограничению аккаунта.';

  @override
  String get contentModerationPostingViolations =>
      'Публикация контента, нарушающего наши правила, может привести к удалению контента и ограничениям аккаунта.';

  @override
  String get contentModerationEditContent => 'Редактировать контент';

  @override
  String get contentModerationPostAnyway => 'Опубликовать всё равно';

  @override
  String get contentModerationSexualContent => 'Сексуальный контент';

  @override
  String get contentModerationHateSpeech => 'Разжигание ненависти';

  @override
  String get contentModerationViolence => 'Насилие';

  @override
  String get contentModerationProfanity => 'Нецензурная лексика';

  @override
  String get contentModerationHarassment => 'Преследование';

  @override
  String get contentModerationSpam => 'Спам';

  @override
  String get contentModerationIllegalActivity => 'Незаконная деятельность';

  @override
  String get contentModerationSelfHarm => 'Причинение вреда себе';

  @override
  String get contentModerationAdultContent => 'Контент для взрослых';

  @override
  String get contentModerationSuggestiveContent => 'Провокационный контент';

  @override
  String contentModerationRemovedWithReason(String reason) {
    return 'Контент удалён — $reason';
  }

  @override
  String get contentModerationRemovedGeneric =>
      'Контент удалён — ваш контент нарушил Правила сообщества.';

  @override
  String get contentModerationLearnMore => 'Подробнее';

  @override
  String get devicePrivacyLocationSharing => 'Передача геолокации устройства';

  @override
  String get devicePrivacySharingEnabled =>
      'Устройство настроено на передачу своей GPS-позиции.';

  @override
  String get devicePrivacySharingDisabled =>
      'Это устройство не передаёт данные GPS-позиции.';

  @override
  String get devicePrivacyWhatThisMeans => 'Что это означает';

  @override
  String get devicePrivacyPublicVisibility => 'Публичная видимость';

  @override
  String get devicePrivacyPublicDescription =>
      'Местоположение устройства будет видно всем пользователям сети и на карте мира в приложении.';

  @override
  String get devicePrivacyFollowerAccess => 'Доступ подписчиков';

  @override
  String get devicePrivacyFollowerDescription =>
      'Ваши подписчики будут видеть обновления позиции этого устройства в реальном времени.';

  @override
  String get devicePrivacyUpdateFrequency => 'Частота обновления';

  @override
  String devicePrivacyUpdateFrequencyDescription(int seconds) {
    return 'Обновление местоположения каждые $seconds секунд.';
  }

  @override
  String get devicePrivacyPrivacyDependsNote =>
      'Конфиденциальность вашего местоположения зависит от конфигурации Meshtastic на этом устройстве. Чтобы изменить настройки передачи данных, обновите конфигурацию позиции устройства.';

  @override
  String get devicePrivacyPrivacyProtected =>
      'Это устройство отключило передачу геолокации. Ваша конфиденциальность защищена.';

  @override
  String get devicePrivacyLinkDeviceLocationShared =>
      'Привязать устройство (геолокация передаётся)';

  @override
  String get devicePrivacyLinkDevice => 'Привязать устройство';

  @override
  String get dateTimePickerMonthJanuary => 'Январь';

  @override
  String get dateTimePickerMonthFebruary => 'Февраль';

  @override
  String get dateTimePickerMonthMarch => 'Март';

  @override
  String get dateTimePickerMonthApril => 'Апрель';

  @override
  String get dateTimePickerMonthMay => 'Май';

  @override
  String get dateTimePickerMonthJune => 'Июнь';

  @override
  String get dateTimePickerMonthJuly => 'Июль';

  @override
  String get dateTimePickerMonthAugust => 'Август';

  @override
  String get dateTimePickerMonthSeptember => 'Сентябрь';

  @override
  String get dateTimePickerMonthOctober => 'Октябрь';

  @override
  String get dateTimePickerMonthNovember => 'Ноябрь';

  @override
  String get dateTimePickerMonthDecember => 'Декабрь';

  @override
  String get dateTimePickerMonthJan => 'Янв';

  @override
  String get dateTimePickerMonthFeb => 'Фев';

  @override
  String get dateTimePickerMonthMar => 'Мар';

  @override
  String get dateTimePickerMonthApr => 'Апр';

  @override
  String get dateTimePickerMonthMayShort => 'Май';

  @override
  String get dateTimePickerMonthJun => 'Июн';

  @override
  String get dateTimePickerMonthJul => 'Июл';

  @override
  String get dateTimePickerMonthAug => 'Авг';

  @override
  String get dateTimePickerMonthSep => 'Сен';

  @override
  String get dateTimePickerMonthOct => 'Окт';

  @override
  String get dateTimePickerMonthNov => 'Ноя';

  @override
  String get dateTimePickerMonthDec => 'Дек';

  @override
  String get dateTimePickerDateSection => 'Дата';

  @override
  String get dateTimePickerTimeSection => 'Время';

  @override
  String get dateTimePickerAm => 'ДП';

  @override
  String get dateTimePickerPm => 'ПП';

  @override
  String get actionConnect => 'Подключить';

  @override
  String get actionView => 'Просмотр';

  @override
  String albumRarityPageTitle(String rarity) {
    return 'Карточки $rarity';
  }

  @override
  String get actionSheetQuickMessage => 'Быстрое сообщение';

  @override
  String get actionSheetTo => 'КОМУ';

  @override
  String get actionSheetAllNodes => 'Все ноды';

  @override
  String get actionSheetBroadcastToAll => 'Трансляция всем нодам';

  @override
  String get actionSheetBroadcastToEveryone => 'Трансляция всем в канале';

  @override
  String get actionSheetSendTo => 'Отправить';

  @override
  String get actionSheetQuickMessageLabel => 'БЫСТРОЕ СООБЩЕНИЕ';

  @override
  String get actionSheetOrTypeCustom => 'ИЛИ ВВЕДИТЕ СВОЁ';

  @override
  String get actionSheetTypeMessage => 'Введите сообщение...';

  @override
  String get actionSheetBroadcast => 'Трансляция';

  @override
  String get actionSheetSend => 'Отправить';

  @override
  String actionSheetSentTo(String target) {
    return 'Отправлено $target';
  }

  @override
  String actionSheetSendFailed(String error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String get actionSheetPresetOnMyWay => 'Уже еду';

  @override
  String get actionSheetPresetRunningLate => 'Опаздываю';

  @override
  String get actionSheetPresetCheckInOk => 'Всё в порядке';

  @override
  String get actionSheetPresetNeedAssistance => 'Нужна помощь';

  @override
  String get actionSheetPresetAtDestination => 'На месте';

  @override
  String get actionSheetPresetWeatherAlert => 'Погодное предупреждение';

  @override
  String get actionSheetEmergencySos => 'Экстренный SOS';

  @override
  String get actionSheetThisWill => 'Это действие:';

  @override
  String get actionSheetSosBroadcast =>
      'Транслирует экстренное сообщение ВСЕМ нодам';

  @override
  String get actionSheetSosLocation =>
      'Включает ваше текущее местоположение (если доступно)';

  @override
  String get actionSheetSosIfttt => 'Активирует IFTTT webhook (если настроен)';

  @override
  String get actionSheetSosReady => 'Готово к отправке экстренного сигнала';

  @override
  String actionSheetSosCountdown(int seconds) {
    return 'Подождите $seconds секунд...';
  }

  @override
  String get actionSheetSendSos => 'Отправить SOS';

  @override
  String get actionSheetSosSent => 'Экстренный SOS отправлен всем нодам';

  @override
  String actionSheetSosFailed(String error) {
    return 'Не удалось отправить SOS: $error';
  }

  @override
  String get actionSheetTraceroute => 'Трассировка';

  @override
  String get actionSheetTracerouteTo => 'Трассировка до';

  @override
  String get actionSheetTracerouteInfo =>
      'Трассировка определяет путь пакетов до ноды через сеть Mesh';

  @override
  String get actionSheetTargetNode => 'ЦЕЛЕВОЙ УЗЕЛ';

  @override
  String get actionSheetSelected => 'Выбран';

  @override
  String get actionSheetTapToSelectNode => 'Нажмите для выбора ноды';

  @override
  String get actionSheetTrace => 'Трассировать';

  @override
  String actionSheetTracerouteSent(String target) {
    return 'Трассировка отправлена к $target — проверьте Историю трассировок для результатов';
  }

  @override
  String actionSheetTracerouteFailed(String error) {
    return 'Не удалось выполнить трассировку: $error';
  }

  @override
  String get premiumPreviewAutomations =>
      'Режим предпросмотра — обновитесь, чтобы создавать автоматизации';

  @override
  String get premiumPreviewIfttt =>
      'Режим предпросмотра — обновитесь, чтобы подключить сервисы';

  @override
  String get premiumPreviewWidgets =>
      'Режим предпросмотра — обновитесь, чтобы создавать виджеты';

  @override
  String get premiumPreviewRingtones =>
      'Режим предпросмотра — обновитесь, чтобы получить доступ к полной библиотеке';

  @override
  String get premiumPreviewThemes =>
      'Режим предпросмотра — обновитесь, чтобы разблокировать все цвета';

  @override
  String get premiumUpgrade => 'Обновить';

  @override
  String get premiumExample => 'Пример';

  @override
  String get premiumUnlockFeature => 'Разблокировать функцию';

  @override
  String get premiumNotNow => 'Не сейчас';

  @override
  String get premiumRestorePurchases => 'Восстановить покупки';

  @override
  String get premiumOneTimePurchase => 'Разовая покупка • Навсегда ваше';

  @override
  String premiumUnlockFor(String price) {
    return 'Разблокировать за $price';
  }

  @override
  String get premiumPurchaseRequiresInternet =>
      'Для покупок требуется подключение к интернету.';

  @override
  String premiumPurchaseUnlocked(String name) {
    return '$name разблокировано!';
  }

  @override
  String get premiumPurchaseFailed =>
      'Покупка не удалась. Пожалуйста, попробуйте снова.';

  @override
  String get premiumPurchaseError =>
      'Что-то пошло не так. Пожалуйста, попробуйте снова.';

  @override
  String get premiumRestoreRequiresInternet =>
      'Для восстановления покупок требуется подключение к интернету.';

  @override
  String get premiumRestoreSuccess => 'Покупки восстановлены!';

  @override
  String get premiumRestoreNone => 'Покупок для восстановления не найдено';

  @override
  String get premiumRestoreFailed => 'Не удалось восстановить покупки';

  @override
  String get premiumConfigSaved =>
      'Ваша конфигурация сохранена. После покупки просто нажмите «Сохранить» ещё раз.';

  @override
  String get premiumHeadlineAutomations => 'Автоматизируйте вашу сеть';

  @override
  String get premiumHeadlineIfttt => 'Объедините всё';

  @override
  String get premiumHeadlineThemes => 'Сделайте интерфейс своим';

  @override
  String get premiumHeadlineRingtones => 'Библиотека звуков';

  @override
  String get premiumHeadlineWidgets => 'Ваша Панель';

  @override
  String get premiumHeadlineWidgetsAlt => 'Создайте свою Панель';

  @override
  String get premiumHeadlineRingtonesAlt => 'Разблокировать библиотеку звуков';

  @override
  String get premiumSubtitleAutomations =>
      'Сохраните эту автоматизацию и раскройте весь потенциал автоматических оповещений, сообщений и умных триггеров.';

  @override
  String get premiumSubtitleIfttt =>
      'Подключите вашу сеть к сотням приложений и сервисов.';

  @override
  String get premiumSubtitleThemes =>
      'Выразите себя с помощью 12 потрясающих акцентных цветов.';

  @override
  String get premiumSubtitleRingtones =>
      'Получите доступ к огромной библиотеке звуков уведомлений.';

  @override
  String get premiumSubtitleWidgets =>
      'Создавайте пользовательские панели с визуализацией данных в реальном времени.';

  @override
  String get premiumDescAutomations =>
      'Создавайте мощные автоматизации, которые запускают оповещения, отправляют сообщения и реагируют на события сети автоматически.';

  @override
  String get premiumDescIfttt =>
      'Подключите вашу сеть к 700+ приложениям и сервисам через вебхуки IFTTT.';

  @override
  String get premiumDescWidgets =>
      'Создавайте пользовательские виджеты панели с актуальными данными, графиками и мониторингом в реальном времени.';

  @override
  String get premiumDescRingtones =>
      'Более 7 000 рингтонов: классические мелодии, темы из сериалов и саундтреки к фильмам.';

  @override
  String get premiumDescThemes =>
      'Персонализируйте приложение с помощью 12 потрясающих акцентных цветов.';

  @override
  String get premiumBenefitUnlimitedAutomations =>
      'Неограниченные автоматизации';

  @override
  String get premiumBenefitUnlimitedAutomationsDesc =>
      'Создавайте столько правил, сколько вам нужно';

  @override
  String get premiumBenefitSmartNotifications => 'Умные уведомления';

  @override
  String get premiumBenefitSmartNotificationsDesc =>
      'Получайте оповещения о заряде батареи, нодах не в сети и многом другом';

  @override
  String get premiumBenefitScheduledActions => 'Запланированные действия';

  @override
  String get premiumBenefitScheduledActionsDesc =>
      'Запускайте автоматизации в определённое время';

  @override
  String get premiumBenefitScheduledActionsShort => 'Запуск в заданное время';

  @override
  String get premiumBenefitGeofenceTriggers => 'Геозонные триггеры';

  @override
  String get premiumBenefitGeofenceTriggersDesc =>
      'Реагируйте, когда ноды входят в зону или покидают её';

  @override
  String get premiumBenefitGeofenceTriggersShort =>
      'Реакция на события по местоположению';

  @override
  String get premiumBenefitConnect700 => 'Подключить 700+ сервисов';

  @override
  String get premiumBenefitConnect700Desc =>
      'Умный дом, уведомления, таблицы и многое другое';

  @override
  String get premiumBenefitSmartHome => 'Умный дом';

  @override
  String get premiumBenefitSmartHomeDesc =>
      'Управляйте освещением, замками и устройствами';

  @override
  String get premiumBenefitSmartHomeControl => 'Управление умным домом';

  @override
  String get premiumBenefitSmartHomeControlDesc =>
      'Активируйте освещение, замки и устройства';

  @override
  String get premiumBenefitCrossPlatform => 'Кросс-платформенность';

  @override
  String get premiumBenefitCrossPlatformDesc =>
      'Оповещения в Slack, Discord, по email';

  @override
  String get premiumBenefitCrossPlatformAlerts =>
      'Кросс-платформенные оповещения';

  @override
  String get premiumBenefitCrossPlatformAlertsDesc =>
      'Отправляйте в Slack, Discord, по email и не только';

  @override
  String get premiumBenefitLogging => 'Журналирование';

  @override
  String get premiumBenefitLoggingDesc => 'Сохраняйте события в таблицы';

  @override
  String get premiumBenefit12Colors => '12 премиум-цветов';

  @override
  String get premiumBenefit12ColorsDesc =>
      'Персонализируйте каждый экран и кнопку';

  @override
  String get premiumBenefit15Colors => '15 цветов';

  @override
  String get premiumBenefit15ColorsDesc => 'Премиум варианты акцентных цветов';

  @override
  String get premiumBenefitExclusiveStyles => 'Эксклюзивные стили';

  @override
  String get premiumBenefitExclusiveStylesDesc =>
      'Уникальные акцентные сочетания';

  @override
  String get premiumBenefitExclusive => 'Эксклюзивно';

  @override
  String get premiumBenefitExclusiveDesc => 'Уникальные сочетания';

  @override
  String get premiumBenefit7000Ringtones => '7 000+ рингтонов';

  @override
  String get premiumBenefit7000RingtonesDesc =>
      'Классические мелодии, темы из сериалов, игры и многое другое';

  @override
  String get premiumBenefit10000Tones => '10 000+ мелодий';

  @override
  String get premiumBenefit10000TonesDesc => 'Огромная библиотека с поиском';

  @override
  String get premiumBenefitSearchableLibrary => 'Библиотека с поиском';

  @override
  String get premiumBenefitSearchableLibraryDesc =>
      'Найдите любую мелодию мгновенно';

  @override
  String get premiumBenefitEasySearch => 'Удобный поиск';

  @override
  String get premiumBenefitEasySearchDesc => 'Найдите любую мелодию мгновенно';

  @override
  String get premiumBenefitCustomPresets => 'Пользовательские пресеты';

  @override
  String get premiumBenefitCustomPresetsDesc => 'Сохраняйте избранное';

  @override
  String get premiumBenefitCustomDashboards => 'Пользовательские панели';

  @override
  String get premiumBenefitCustomDashboardsDesc =>
      'Создавайте собственные макеты виджетов';

  @override
  String get premiumBenefitLiveCharts => 'Графики и датчики в реальном времени';

  @override
  String get premiumBenefitLiveChartsDesc =>
      'Визуализируйте телеметрию в реальном времени';

  @override
  String get premiumBenefitLiveChartsAlt => 'Графики в реальном времени';

  @override
  String get premiumBenefitLiveChartsAltDesc =>
      'Визуализация данных в реальном времени';

  @override
  String get premiumBenefitBatterySensors => 'Батарея и датчики';

  @override
  String get premiumBenefitBatterySensorsDesc =>
      'Следите за всем с первого взгляда';

  @override
  String get premiumBenefitMonitoring => 'Мониторинг';

  @override
  String get premiumBenefitMonitoringDesc => 'Батарея, датчики, телеметрия';

  @override
  String get premiumBenefitCustomLayouts => 'Пользовательские макеты';

  @override
  String get premiumBenefitCustomLayoutsDesc =>
      'Создавайте собственные представления';

  @override
  String get premiumBenefitSmartAlerts => 'Умные оповещения';

  @override
  String get premiumBenefitSmartAlertsDesc =>
      'Низкий заряд батареи, нода не в сети и многое другое';

  @override
  String get settingsPremiumFeatureRequired =>
      'Для использования этой функции требуется покупка';

  @override
  String get settingsPremiumViewUpgrades => 'Посмотреть улучшения';

  @override
  String get settingsPremiumPro => 'PRO';

  @override
  String get settingsPremiumFeatureTitle => 'Премиум-функция';

  @override
  String get settingsPremiumFeatureDescription =>
      'Для разблокировки этой функции требуется покупка.';

  @override
  String settingsPremiumUnlockPrice(String price) {
    return 'Разблокировать за \$$price';
  }

  @override
  String get glyphMatrixTitle => 'МАТРИЦА ГЛИФОВ';

  @override
  String get glyphMatrixTurnOff => 'Выключить';

  @override
  String get glyphMatrixInitializing => 'ИНИЦИАЛИЗАЦИЯ МАТРИЦЫ ГЛИФОВ...';

  @override
  String get glyphMatrixInitFailed => 'ОШИБКА ИНИЦИАЛИЗАЦИИ';

  @override
  String get glyphMatrixNotSupported => 'УСТРОЙСТВО НЕ ПОДДЕРЖИВАЕТСЯ';

  @override
  String get glyphMatrixRequiresDevice =>
      'Матрица глифов требует\nNothing Phone (3)';

  @override
  String get glyphMatrixSwipeToExecute => '← ПРОВЕДИТЕ ДЛЯ ВЫПОЛНЕНИЯ →';

  @override
  String batteryOptTitle(String oemName) {
    return 'Оптимизация для $oemName';
  }

  @override
  String get batteryOptDescription =>
      'Производитель устройства может агрессивно ограничивать фоновые приложения. Следуйте этим шагам';

  @override
  String get batteryOptOpenSettings => 'Открыть настройки батареи';

  @override
  String get batteryOptDismiss => 'Закрыть';

  @override
  String get batteryOptDontShowAgain => 'Больше не показывать';

  @override
  String get batteryOptXiaomiStep1 =>
      'Откройте Настройки > Приложения > Управление приложениями > Socialmesh.';

  @override
  String get batteryOptXiaomiStep2 => 'Нажмите «Автозапуск» и включите его.';

  @override
  String get batteryOptXiaomiStep3 =>
      'Вернитесь назад и нажмите «Экономия батареи».';

  @override
  String get batteryOptXiaomiStep4 =>
      'Выберите «Без ограничений» для Socialmesh.';

  @override
  String get batteryOptSamsungStep1 =>
      'Откройте Настройки > Обслуживание устройства > Батарея.';

  @override
  String get batteryOptSamsungStep2 =>
      'Нажмите «Ограничения использования в фоне».';

  @override
  String get batteryOptSamsungStep3 =>
      'Удалите Socialmesh из списков «Спящие приложения» и «Приложения в глубоком сне».';

  @override
  String get batteryOptSamsungStep4 =>
      'При желании отключите «Адаптивное питание» для лучших результатов.';

  @override
  String get batteryOptHuaweiStep1 =>
      'Откройте Настройки > Батарея > Запуск приложений.';

  @override
  String get batteryOptHuaweiStep2 =>
      'Найдите Socialmesh и установите «Управлять вручную».';

  @override
  String get batteryOptHuaweiStep3 =>
      'Включите все три переключателя: Автозапуск, Дополнительный запуск и Работа в фоне.';

  @override
  String get batteryOptOneplusStep1 =>
      'Откройте Настройки > Приложения > Управление приложениями > Socialmesh.';

  @override
  String get batteryOptOneplusStep2 =>
      'Включите «Автозапуск» и «Разрешить активность в фоне».';

  @override
  String get batteryOptOneplusStep3 =>
      'На OnePlus 14+: также проверьте Настройки > Батарея > Оптимизация батареи > Socialmesh.';

  @override
  String get batteryOptGenericStep1 =>
      'Откройте Настройки > Приложения > Socialmesh > Батарея.';

  @override
  String get batteryOptGenericStep2 =>
      'Выберите «Без ограничений» или «Не оптимизировать».';

  @override
  String get batteryOptGenericStep3 =>
      'Это позволит Socialmesh поддерживать соединение с сетью Mesh в фоновом режиме.';

  @override
  String get helpCenterNoResultsPrefix => '';

  @override
  String get helpCenterNoResultsKeyword => 'Результатов';

  @override
  String get helpCenterNoResultsSuffix => ' не найдено';

  @override
  String helpCenterReadingTime(int minutes) {
    return '$minutes мин';
  }

  @override
  String helpCenterMoreTours(int count) {
    return '+ ещё $count туров';
  }

  @override
  String helpCenterStepsCount(int count) {
    return '$count шагов';
  }

  @override
  String get storeForwardTitle => 'Сохранение и пересылка';

  @override
  String get storeForwardSaveSuccess =>
      'Конфигурация сохранения и пересылки сохранена';

  @override
  String get storeForwardLoadFailed => 'Не удалось загрузить конфигурацию';

  @override
  String storeForwardSaveFailed(String error) {
    return 'Не удалось сохранить конфигурацию: $error';
  }

  @override
  String get storeForwardSave => 'Сохранить';

  @override
  String get storeForwardModuleSettings => 'Настройки модуля';

  @override
  String get storeForwardServerSettings => 'Настройки сервера';

  @override
  String get storeForwardInfoDescription =>
      'Позволяет нодам хранить сообщения и пересылать их устройствам, которые были офлайн. Требуется достаточно памяти.';

  @override
  String get storeForwardEnable => 'Включить сохранение и пересылку';

  @override
  String get storeForwardEnableSubtitle => 'Участвовать в сети S&F';

  @override
  String get storeForwardActAsServer => 'Работать как сервер';

  @override
  String get storeForwardActAsServerSubtitle =>
      'Хранить сообщения для других нод (использует больше ОЗУ)';

  @override
  String get storeForwardHeartbeat => 'Пульс';

  @override
  String get storeForwardHeartbeatSubtitle =>
      'Отправлять периодические объявления в сеть Mesh';

  @override
  String get storeForwardRecordsLimit => 'Лимит записей';

  @override
  String get storeForwardRecordsLimitSubtitle =>
      'Использовать настройки устройства по умолчанию';

  @override
  String get storeForwardAuto => 'Авто';

  @override
  String get storeForwardHistoryReturnMax => 'Максимум возвращаемой истории';

  @override
  String storeForwardHistoryReturnMaxSubtitle(int count) {
    return 'Не более $count сообщений на запрос';
  }

  @override
  String get storeForwardHistoryWindow => 'Окно истории';

  @override
  String storeForwardHistoryWindowSubtitle(int hours) {
    return 'Хранить сообщения $hours часов';
  }

  @override
  String get geofenceTitle => 'Задать геозону';

  @override
  String get geofenceDone => 'Готово';

  @override
  String get geofencePermissionDenied =>
      'Доступ к местоположению запрещён. Разрешите доступ, чтобы задать центр геозоны.';

  @override
  String get geofenceOpenSettings => 'Открыть настройки';

  @override
  String geofenceLocationFailed(String error) {
    return 'Не удалось получить местоположение: $error';
  }

  @override
  String get geofenceTapToSet => 'Нажмите на карту, чтобы задать центр геозоны';

  @override
  String get geofenceTapToSetCenter => 'Нажмите для задания центра геозоны';

  @override
  String get geofenceDragToAdjust =>
      'Перетащите край круга для изменения радиуса';

  @override
  String geofenceNodesCount(int count) {
    return '$count нод';
  }

  @override
  String get geofenceMonitoredNode => 'Отслеживаемая нода';

  @override
  String get geofenceRadius => 'Радиус';

  @override
  String geofenceRadiusKm(String value) {
    return 'Радиус: $value км';
  }

  @override
  String geofenceRadiusM(String value) {
    return 'Радиус: $value м';
  }

  @override
  String get subscriptionFallbackRingtonePack => 'Набор рингтонов';

  @override
  String get subscriptionFallbackThemePack => 'Набор тем';

  @override
  String get subscriptionFallbackWidgetPack => 'Набор виджетов';

  @override
  String get subscriptionFallbackAutomations => 'Автоматизации';

  @override
  String get subscriptionFallbackIfttt => 'IFTTT';

  @override
  String get geofenceLocating => 'Определение местоположения...';

  @override
  String get geofenceUseMyLocation => 'Использовать моё местоположение';

  @override
  String get geofenceSetGeofence => 'Задать геозону';

  @override
  String get geofenceSelectNode => 'Выбрать ноду';

  @override
  String get geofenceNoNodesWithGps => 'Нет нод с GPS';

  @override
  String get geofenceYou => 'ВЫ';

  @override
  String get geofenceMonitored => 'Отслеживается';

  @override
  String get geofenceMonitor => 'Отслеживать';

  @override
  String get restorePurchasesTitle => 'Восстановить покупки';

  @override
  String get restorePurchasesRequiresInternet =>
      'Для восстановления покупок требуется подключение к Интернету.';

  @override
  String get restorePurchasesSuccess => 'Покупки успешно восстановлены!';

  @override
  String get restorePurchasesAlreadyActive => 'Ваши покупки уже активны';

  @override
  String get restorePurchasesNone => 'Покупки для восстановления не найдены';

  @override
  String get bluetoothTitle => 'Bluetooth';

  @override
  String get bluetoothSave => 'Сохранить';

  @override
  String get bluetoothSaveSuccess => 'Конфигурация Bluetooth сохранена';

  @override
  String bluetoothSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get bluetoothInvalidPin =>
      'Пожалуйста, введите корректный 6-значный PIN-код';

  @override
  String get bluetoothEnabled => 'Bluetooth включён';

  @override
  String get bluetoothEnableSubtitle => 'Включить подключение по Bluetooth';

  @override
  String get bluetoothPairingMode => 'РЕЖИМ СОПРЯЖЕНИЯ';

  @override
  String get bluetoothFixedPin => 'ФИКСИРОВАННЫЙ PIN';

  @override
  String get bluetoothPinHint =>
      'Введите 6-значный PIN-код для сопряжения по Bluetooth';

  @override
  String get bluetoothInfoDescription =>
      'Настройки Bluetooth определяют, как ваше устройство сопрягается с телефонами и другими устройствами.';

  @override
  String get bluetoothModeRandom => 'Случайный PIN';

  @override
  String get bluetoothModeFixed => 'Фиксированный PIN';

  @override
  String get bluetoothModeNone => 'Без PIN';

  @override
  String get bluetoothModeUnknown => 'Неизвестно';

  @override
  String get bluetoothModeRandomDesc =>
      'Генерировать случайный PIN при каждом включении';

  @override
  String get bluetoothModeFixedDesc => 'Использовать фиксированный PIN-код';

  @override
  String get bluetoothModeNoneDesc => 'PIN не требуется (небезопасно)';

  @override
  String get detectionSensorTitle => 'Датчик обнаружения';

  @override
  String get detectionSensorSave => 'Сохранить';

  @override
  String get detectionSensorSaveSuccess =>
      'Конфигурация датчика обнаружения сохранена';

  @override
  String detectionSensorSaveFailed(String error) {
    return 'Не удалось сохранить конфигурацию: $error';
  }

  @override
  String get detectionSensorBasicSettings => 'Основные настройки';

  @override
  String get detectionSensorPinConfig => 'Конфигурация вывода';

  @override
  String get detectionSensorTiming => 'Таймирование';

  @override
  String get detectionSensorClientOptions => 'Параметры клиента';

  @override
  String get detectionSensorInfoDescription =>
      'Мониторинг GPIO-вывода и трансляция изменений состояния в сеть Mesh. Используется с PIR-датчиками движения и другими.';

  @override
  String get detectionSensorEnable => 'Включить датчик обнаружения';

  @override
  String get detectionSensorEnableSubtitle =>
      'Мониторинг GPIO-вывода и трансляция изменений состояния';

  @override
  String get detectionSensorName => 'Название датчика';

  @override
  String get detectionSensorNameHint =>
      'например, Входная дверь, Датчик движения';

  @override
  String get detectionSensorGpioPin => 'GPIO-вывод';

  @override
  String get detectionSensorGpioPinSubtitle =>
      'Номер GPIO-вывода для мониторинга';

  @override
  String get detectionSensorTriggerType => 'Тип триггера';

  @override
  String get detectionSensorUsePullup =>
      'Использовать внутренний подтягивающий резистор';

  @override
  String get detectionSensorUsePullupSubtitle =>
      'Включить внутренний подтягивающий резистор на выводе';

  @override
  String get detectionSensorSendBell => 'Отправлять символ звонка';

  @override
  String get detectionSensorSendBellSubtitle =>
      'Отправлять символ звонка (\\a) в сообщениях обнаружения';

  @override
  String get detectionSensorMinBroadcastInterval =>
      'Минимальный интервал трансляции';

  @override
  String detectionSensorMinBroadcastIntervalSubtitle(int seconds) {
    return 'Ждать $seconds секунд между трансляциями';
  }

  @override
  String get detectionSensorStateBroadcastInterval =>
      'Интервал трансляции состояния';

  @override
  String detectionSensorStateBroadcastIntervalSubtitle(int minutes) {
    return 'Транслировать текущее состояние каждые $minutes минут';
  }

  @override
  String get detectionSensorEnableNotifications => 'Включить уведомления';

  @override
  String get detectionSensorEnableNotificationsSubtitle =>
      'Показывать уведомления при получении событий датчика';

  @override
  String get detectionSensorTriggerLogicLow =>
      'Логический ноль (активен, когда вывод LOW)';

  @override
  String get detectionSensorTriggerLogicHigh =>
      'Логическая единица (активен, когда вывод HIGH)';

  @override
  String get detectionSensorTriggerFallingEdge =>
      'Нисходящий фронт (срабатывает при HIGH→LOW)';

  @override
  String get detectionSensorTriggerRisingEdge =>
      'Восходящий фронт (срабатывает при LOW→HIGH)';

  @override
  String get detectionSensorTriggerEitherEdgeLow => 'Любой фронт (активен LOW)';

  @override
  String get detectionSensorTriggerEitherEdgeHigh =>
      'Любой фронт (активен HIGH)';

  @override
  String get subscriptionPremiumTitle => 'Премиум';

  @override
  String get subscriptionOrBuyIndividually => 'или купить по отдельности';

  @override
  String get subscriptionIncludedFeatures => 'Включённые функции';

  @override
  String get subscriptionUnlockFeatures => 'Разблокировать функции';

  @override
  String get subscriptionOneTimePurchases => 'Разовые покупки, навсегда ваши';

  @override
  String get subscriptionTerms => 'Условия';

  @override
  String get subscriptionPrivacy => 'Конфиденциальность';

  @override
  String get subscriptionAllUnlocked => 'Все функции разблокированы';

  @override
  String get subscriptionThankYou => 'Спасибо за вашу поддержку!';

  @override
  String get subscriptionCompletePack => 'Полный пакет';

  @override
  String get subscriptionCompletePackSubtitle => 'Всё. Навсегда. Одна цена.';

  @override
  String subscriptionTones(String count) {
    return '$count тонов';
  }

  @override
  String get subscriptionAccentColors => '12 акцентных цветов';

  @override
  String get subscriptionUnlimitedWidgets =>
      'Неограниченное количество пользовательских виджетов';

  @override
  String get subscriptionTriggersSchedules => 'Триггеры и расписания';

  @override
  String get subscriptionAppIntegrations =>
      'Более 700 интеграций с приложениями';

  @override
  String get subscriptionBestValue => 'Лучшее предложение — все функции';

  @override
  String get subscriptionGetAll => 'Получить всё';

  @override
  String get subscriptionOwned => 'КУПЛЕНО';

  @override
  String subscriptionSearchableTones(String count) {
    return '$count тонов RTTTL с поиском';
  }

  @override
  String get subscriptionView => 'Просмотр';

  @override
  String get subscriptionAllUnlockedCelebration =>
      'Все функции разблокированы!';

  @override
  String get subscriptionCelebrationMessage =>
      'Теперь у вас есть доступ ко всему, что предлагает Socialmesh. Спасибо за вашу поддержку!';

  @override
  String get subscriptionAwesome => 'Отлично!';

  @override
  String get cannedResponsesTitle => 'Быстрые ответы';

  @override
  String get cannedResponsesAddTooltip => 'Добавить ответ';

  @override
  String get cannedResponsesDoneTooltip => 'Готово';

  @override
  String get cannedResponsesReorderTooltip => 'Изменить порядок';

  @override
  String get cannedResponsesResetToDefaults => 'Сбросить к умолчаниям';

  @override
  String get cannedResponsesDeleteTitle => 'Удалить ответ';

  @override
  String cannedResponsesDeleteMessage(String text) {
    return 'Удалить «$text»?';
  }

  @override
  String get cannedResponsesDeleteConfirm => 'Удалить';

  @override
  String get cannedResponsesResetTitle => 'Сбросить к умолчаниям';

  @override
  String get cannedResponsesResetMessage =>
      'Это удалит все пользовательские ответы и восстановит набор по умолчанию.';

  @override
  String get cannedResponsesResetConfirm => 'Сбросить';

  @override
  String get cannedResponsesDragToReorder =>
      'Перетащите для изменения порядка ответов';

  @override
  String get cannedResponsesTapToEdit =>
      'Нажмите для редактирования, проведите для удаления';

  @override
  String get cannedResponsesDefault => 'По умолчанию';

  @override
  String get cannedResponsesEditTitle => 'Редактировать ответ';

  @override
  String get cannedResponsesAddTitle => 'Добавить ответ';

  @override
  String get cannedResponsesCreateSubtitle =>
      'Создайте быстрое сообщение для быстрой отправки';

  @override
  String get cannedResponsesMessageLabel => 'Сообщение';

  @override
  String get cannedResponsesMessageHint => 'например, Уже еду';

  @override
  String get cannedResponsesSave => 'Сохранить';

  @override
  String get cannedResponsesAdd => 'Добавить';

  @override
  String get rangeTestTitle => 'Тест дальности';

  @override
  String get rangeTestSave => 'Сохранить';

  @override
  String get rangeTestSaveSuccess => 'Конфигурация теста дальности сохранена';

  @override
  String rangeTestSaveFailed(String error) {
    return 'Не удалось сохранить конфигурацию: $error';
  }

  @override
  String get rangeTestNoNodes => 'Нет других доступных нод';

  @override
  String get rangeTestSelectTarget => 'Выбрать цель';

  @override
  String get rangeTestConfiguration => 'Конфигурация';

  @override
  String rangeTestResultsCount(int count) {
    return 'Результаты ($count)';
  }

  @override
  String get rangeTestAbout => 'О тесте дальности';

  @override
  String get rangeTestRunning => 'Тест выполняется';

  @override
  String get rangeTestReady => 'Готов к тестированию';

  @override
  String rangeTestPacketsReceived(int count) {
    return 'Получено пакетов: $count';
  }

  @override
  String get rangeTestSelectNode => 'Выбрать ноду';

  @override
  String get rangeTestStop => 'Стоп';

  @override
  String get rangeTestStartTest => 'Начать тест';

  @override
  String get rangeTestEnableModule => 'Включить модуль теста дальности';

  @override
  String get rangeTestEnableModuleSubtitle =>
      'Разрешить этому устройству участвовать в тестах дальности';

  @override
  String get rangeTestSenderInterval => 'Интервал отправки';

  @override
  String rangeTestSenderIntervalSubtitle(int seconds) {
    return 'Отправлять тестовый пакет каждые $seconds секунд';
  }

  @override
  String get rangeTestSaveResultsToSd => 'Сохранять результаты на SD';

  @override
  String get rangeTestSaveResultsToSdSubtitle =>
      'Хранить результаты тестов на SD-карте устройства';

  @override
  String get rangeTestAvgSnr => 'Ср. SNR';

  @override
  String get rangeTestAvgRssi => 'Ср. RSSI';

  @override
  String get rangeTestMaxDist => 'Макс. дальность';

  @override
  String get rangeTestHowItWorks => 'Как работает тест дальности';

  @override
  String get rangeTestHowItWorksDescription =>
      '1. Выберите целевую ноду для теста дальности\n2. Начните тест для отправки пакетов';

  @override
  String get rangeTestSelectTargetNode => 'Выбрать целевую ноду';

  @override
  String get rangeTestSearchNodes => 'Поиск нод…';

  @override
  String rangeTestNoNodesMatch(String query) {
    return 'Нет нод, соответствующих запросу «$query»';
  }

  @override
  String get themeSettingsTitle => 'Настройки темы';

  @override
  String get themeSettingsCurrentAccent => 'Текущий акцентный цвет';

  @override
  String get themeSettingsAccentColor => 'АКЦЕНТНЫЙ ЦВЕТ';

  @override
  String get themeSettingsQrCodeStyle => 'СТИЛЬ QR-КОДА';

  @override
  String get themeSettingsPreview => 'ПРЕДПРОСМОТР';

  @override
  String themeSettingsCompletePackOnly(String colorName) {
    return '$colorName (только полный пакет)';
  }

  @override
  String themeSettingsThemePack(String colorName) {
    return '$colorName (набор тем)';
  }

  @override
  String get themeSettingsPattern => 'Паттерн';

  @override
  String get themeSettingsStyleDots => 'Точки';

  @override
  String get themeSettingsStyleSmooth => 'Гладкий';

  @override
  String get themeSettingsStyleClassic => 'Классический';

  @override
  String get themeSettingsStyleDotsDesc => 'Чистые круглые модули';

  @override
  String get themeSettingsStyleSmoothDesc => 'Премиальные жидкие модули';

  @override
  String get themeSettingsStyleClassicDesc => 'Максимальная совместимость';

  @override
  String get themeSettingsUseAccentGradient =>
      'Использовать градиент акцентного цвета';

  @override
  String get themeSettingsApplyAccentToQr =>
      'Применить акцентный цвет к QR-кодам';

  @override
  String get themeSettingsButtons => 'Кнопки';

  @override
  String get themeSettingsPrimary => 'Основной';

  @override
  String get themeSettingsSecondary => 'Вторичный';

  @override
  String get themeSettingsText => 'Текст';

  @override
  String get themeSettingsControls => 'Элементы управления';

  @override
  String get themeSettingsProgress => 'Прогресс';

  @override
  String get themeSettingsBadges => 'Значки';

  @override
  String get themeSettingsOnline => 'Онлайн';

  @override
  String get themeSettingsNewCount => '5 новых';

  @override
  String get privacySettingsTitle => 'Конфиденциальность';

  @override
  String get privacySettingsInfoDescription =>
      'Socialmesh собирает минимум данных для повышения стабильности и производительности приложения. Вы можете управлять параметрами ниже.';

  @override
  String get privacySettingsDataCollection => 'СБОР ДАННЫХ';

  @override
  String get privacySettingsUsageAnalytics => 'Аналитика использования';

  @override
  String get privacySettingsUsageAnalyticsSubtitle =>
      'Помогает понять, какие функции используются чаще всего. Содержимое сообщений и точное местоположение не собираются.';

  @override
  String get privacySettingsCrashReporting => 'Отчёты о сбоях';

  @override
  String get privacySettingsCrashReportingSubtitle =>
      'Автоматически отправляет данные о сбоях при ошибках приложения. Помогает нам быстрее исправлять ошибки.';

  @override
  String get privacySettingsDisableAnalyticsTitle =>
      'Отключить аналитику использования?';

  @override
  String get privacySettingsDisableAnalyticsMessage =>
      'Аналитика использования помогает понять, как используется приложение, и выявлять проблемы. Личные сообщения не собираются.';

  @override
  String get privacySettingsDisable => 'Отключить';

  @override
  String get privacySettingsAnalyticsEnabled =>
      'Аналитика использования включена';

  @override
  String get privacySettingsAnalyticsDisabled =>
      'Аналитика использования отключена';

  @override
  String get privacySettingsDisableCrashTitle => 'Отключить отчёты о сбоях?';

  @override
  String get privacySettingsDisableCrashMessage =>
      'Отчёты о сбоях помогают быстрее исправлять ошибки. Личные сообщения и данные о местоположении не собираются.';

  @override
  String get privacySettingsCrashEnabled => 'Отчёты о сбоях включены';

  @override
  String get privacySettingsCrashDisabled => 'Отчёты о сбоях отключены';

  @override
  String get privacySettingsPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get privacySettingsThirdPartyServices => 'СТОРОННИЕ СЕРВИСЫ';

  @override
  String get privacySettingsFirebaseCategories =>
      'Отчёты о сбоях, аналитика использования (при согласии)';

  @override
  String get privacySettingsRevenueCatCategories =>
      'Идентификаторы покупок, статус подписки';

  @override
  String get privacySettingsSigilCategories =>
      'Хешированные идентификаторы нод для генерации изображений';

  @override
  String get appearanceTitle => 'Внешний вид и доступность';

  @override
  String get appearanceResetTooltip => 'Сбросить к умолчаниям';

  @override
  String get appearanceLanguage => 'Язык';

  @override
  String get appearanceLanguageSystemDefault => 'Системный по умолчанию';

  @override
  String get appearanceLanguageEnglish => 'Английский';

  @override
  String get appearanceLanguageItalian => 'Итальянский';

  @override
  String get appearanceLanguageRussian => 'Русский';

  @override
  String get appearanceLanguagePortuguese => 'Portuguese';

  @override
  String get helpCategoryGettingStarted => 'Getting Started';

  @override
  String get helpCategoryMeshBasics => 'Mesh Basics';

  @override
  String get helpCategoryChannels => 'Channels & Encryption';

  @override
  String get helpCategoryMessaging => 'Messaging';

  @override
  String get helpCategoryNodes => 'Nodes & Roles';

  @override
  String get helpCategoryDevice => 'Device & Radio';

  @override
  String get helpCategoryNetwork => 'Network & Maps';

  @override
  String get helpCategorySafety => 'Safety & Rules';

  @override
  String get flowNodeNodeOnline => 'Node Online';

  @override
  String get flowNodeNodeOffline => 'Node Offline';

  @override
  String get flowNodeBatteryLow => 'Battery Low';

  @override
  String get flowNodeBatteryFull => 'Battery Full';

  @override
  String get flowNodeMessageReceived => 'Message Received';

  @override
  String get flowNodePositionChanged => 'Position Changed';

  @override
  String get flowNodeGeofenceEnter => 'Geofence Enter';

  @override
  String get flowNodeGeofenceExit => 'Geofence Exit';

  @override
  String get flowNodeSendMessage => 'Send Message';

  @override
  String get flowNodePlaySound => 'Play Sound';

  @override
  String get flowNodeVibrate => 'Vibrate';

  @override
  String get flowNodePushNotification => 'Push Notification';

  @override
  String get flowNodeTriggerWebhook => 'Trigger Webhook';

  @override
  String get flowNodeLogEvent => 'Log Event';

  @override
  String get flowNodeUpdateWidget => 'Update Widget';

  @override
  String get flowNodeSendToChannel => 'Send to Channel';

  @override
  String get flowNodeTriggerShortcut => 'Trigger Shortcut';

  @override
  String get flowNodeGlyphPattern => 'Glyph Pattern';

  @override
  String get flowNodeTimeRange => 'Time Range';

  @override
  String get flowNodeDayOfWeek => 'Day of Week';

  @override
  String get flowNodeBatteryAbove => 'Battery Above';

  @override
  String get flowNodeBatteryBelow => 'Battery Below';

  @override
  String get flowNodeNodeIsOnline => 'Node Is Online';

  @override
  String get flowNodeNodeIsOffline => 'Node Is Offline';

  @override
  String get flowNodeWithinGeofence => 'Within Geofence';

  @override
  String get flowNodeOutsideGeofence => 'Outside Geofence';

  @override
  String get flowNodeGateAllMustPass => 'All inputs must pass';

  @override
  String get flowNodeGateAnyCanPass => 'Any input can pass';

  @override
  String get flowNodeGateInverts => 'Inverts the signal';

  @override
  String get flowNodeGateDelays => 'Delays the signal';

  @override
  String get flowSubgroupTriggers => 'Triggers';

  @override
  String get flowSubgroupConditions => 'Conditions';

  @override
  String get flowSubgroupLogic => 'Logic';

  @override
  String get flowSubgroupActions => 'Actions';

  @override
  String get flowSubgroupNodeDex => 'NodeDex';

  @override
  String get flowCompilerVisualFlow => 'Visual Flow';

  @override
  String flowCompilerWhen(String trigger) {
    return 'When: $trigger';
  }

  @override
  String flowCompilerIf(String conditions) {
    return 'If: $conditions';
  }

  @override
  String flowCompilerAfterDelay(String delay) {
    return 'After: $delay delay';
  }

  @override
  String flowCompilerThen(String actions) {
    return 'Then: $actions';
  }

  @override
  String get glyphZoneA => 'Zone A';

  @override
  String get glyphZoneB => 'Zone B';

  @override
  String get glyphZoneC => 'Zone C';

  @override
  String get glyphZoneD => 'Zone D';

  @override
  String get glyphZoneE => 'Zone E';

  @override
  String get glyphZoneDescCamera => 'Camera';

  @override
  String get glyphZoneDescDiagonal => 'Diagonal Strip';

  @override
  String get glyphZoneDescUsbc => 'USB-C Port';

  @override
  String get glyphZoneDescLower => 'Lower Strip';

  @override
  String get glyphZoneDescBattery => 'Battery';

  @override
  String get appearanceFontBranded => 'Branded';

  @override
  String get appearanceFontBrandedDesc =>
      'JetBrainsMono - Our signature monospace font';

  @override
  String get appearanceFontSystem => 'System';

  @override
  String get appearanceFontSystemDesc => 'Your device’s default font';

  @override
  String get appearanceFontAccessibility => 'Accessibility';

  @override
  String get appearanceFontAccessibilityDesc =>
      'Inter - Optimized for readability';

  @override
  String get appearanceTextScaleSystem => 'System Default';

  @override
  String get appearanceTextScaleSystemDesc =>
      'Follows your device accessibility settings';

  @override
  String get appearanceTextScaleDefault => 'Default';

  @override
  String get appearanceTextScaleDefaultDesc =>
      'Fixed size, ignores device settings';

  @override
  String get appearanceTextScaleLarge => 'Large';

  @override
  String get appearanceTextScaleLargeDesc => '15% larger than default';

  @override
  String get appearanceTextScaleExtraLarge => 'Extra Large';

  @override
  String get appearanceTextScaleExtraLargeDesc => '30% larger than default';

  @override
  String get appearanceDensityCompact => 'Compact';

  @override
  String get appearanceDensityCompactDesc => 'Denser UI, more content visible';

  @override
  String get appearanceDensityComfortable => 'Comfortable';

  @override
  String get appearanceDensityComfortableDesc => 'Balanced spacing (default)';

  @override
  String get appearanceDensityLargeTouch => 'Large Touch';

  @override
  String get appearanceDensityLargeTouchDesc =>
      'Bigger tap targets, easier to use';

  @override
  String get appearanceContrastNormal => 'Normal';

  @override
  String get appearanceContrastNormalDesc => 'Standard color contrast';

  @override
  String get appearanceContrastHigh => 'High Contrast';

  @override
  String get appearanceContrastHighDesc =>
      'Enhanced visibility for text and UI';

  @override
  String get appearanceMotionNormal => 'Normal';

  @override
  String get appearanceMotionNormalDesc => 'All animations enabled';

  @override
  String get appearanceMotionReduced => 'Reduced';

  @override
  String get appearanceMotionReducedDesc =>
      'Minimal animations for accessibility';

  @override
  String get appearanceFont => 'Шрифт';

  @override
  String get appearanceTextSize => 'Размер текста';

  @override
  String get appearanceDisplayDensity => 'Плотность отображения';

  @override
  String get appearanceContrast => 'Контрастность';

  @override
  String get appearanceMotion => 'Анимации';

  @override
  String get appearanceResetSuccess => 'Настройки сброшены к умолчаниям';

  @override
  String get appearanceLivePreview => 'Предпросмотр в реальном времени';

  @override
  String get appearanceChangesApplyInstantly =>
      'Изменения применяются мгновенно';

  @override
  String get appearanceSampleText =>
      'Образец основного текста для предпросмотра настроек. Настройте параметры ниже, чтобы найти подходящий вариант.';

  @override
  String get appearanceHighContrast => 'Высокая контрастность';

  @override
  String get appearanceHighContrastDesc =>
      'Улучшенная видимость текста и элементов интерфейса';

  @override
  String get appearanceElementalAtmosphere => 'Стихийная атмосфера';

  @override
  String get appearanceElementalDisabled =>
      'Отключено, пока активно «Уменьшить анимации»';

  @override
  String get appearanceElementalDesc =>
      'Фоновые эффекты частиц, управляемые активностью сети Mesh';

  @override
  String get appearanceReduceMotion => 'Уменьшить анимации';

  @override
  String get appearanceReduceMotionDesc =>
      'Минимизировать анимации в приложении';

  @override
  String get appearanceResetToRecommended => 'Сбросить к рекомендуемым';

  @override
  String get appearanceRestoreDefaults => 'Восстановить настройки по умолчанию';

  @override
  String get appearanceUsingRecommended =>
      'Используются рекомендуемые настройки';

  @override
  String get appearanceResetDialogTitle => 'Сбросить к умолчаниям?';

  @override
  String get appearanceResetDialogMessage =>
      'Все настройки внешнего вида и доступности будут восстановлены до рекомендуемых значений.';

  @override
  String get appearanceResetDialogCancel => 'Отмена';

  @override
  String get appearanceResetDialogConfirm => 'Сбросить';

  @override
  String get settingsSectionProfile => 'ПРОФИЛЬ';

  @override
  String get settingsSectionFileTransfer => 'ПЕРЕДАЧА ФАЙЛОВ';

  @override
  String get settingsGlyphMatrixTest => 'Тест матрицы глифов';

  @override
  String get cloudSyncUnableToLoad => 'Не удалось загрузить параметры подписки';

  @override
  String get cloudSyncTitle => 'Разблокировать облачную синхронизацию';

  @override
  String get cloudSyncDescription =>
      'Синхронизируйте данные сети Mesh между устройствами. Локальные данные всегда остаются бесплатными и доступными.';

  @override
  String get cloudSyncNodeDex => 'NodeDex — встречи, теги, заметки';

  @override
  String get cloudSyncAutomations => 'Автоматизации — правила и триггеры';

  @override
  String get cloudSyncWidgets => 'Пользовательские виджеты — макеты и данные';

  @override
  String get cloudSyncOfflineNote => 'Работает полностью офлайн без подписки';

  @override
  String get cloudSyncAutoRenewNote =>
      'Подписки автоматически обновляются, если не отменены не менее чем за 24 часа до окончания текущего периода.';

  @override
  String get cloudSyncYearlySave => 'Годовая (сэкономьте 44%)';

  @override
  String get cloudSyncMonthly => 'Ежемесячная';

  @override
  String get cloudSyncRequired => 'Требуется облачная синхронизация';

  @override
  String get cloudSyncSubscriptionRestored => 'Подписка восстановлена';

  @override
  String get cloudSyncNoSubscription =>
      'Подписка на облачную синхронизацию не найдена';

  @override
  String get cloudSyncRestoreFailed =>
      'Не удалось восстановить. Пожалуйста, попробуйте снова.';

  @override
  String get cloudSyncExpiredMessage =>
      'Срок действия вашей подписки на облачную синхронизацию истёк. Ваши данные доступны только для чтения.';

  @override
  String get cloudSyncRenew => 'Обновить';

  @override
  String get cloudSyncPaymentIssue =>
      'Возникла проблема с оплатой. Пожалуйста, обновите способ оплаты.';

  @override
  String get signalSettingsTitle => 'Сигналы';

  @override
  String get signalSettingsPrivacy => 'КОНФИДЕНЦИАЛЬНОСТЬ СИГНАЛОВ';

  @override
  String get signalSettingsLocationRadius => 'Радиус местоположения сигнала';

  @override
  String get signalSettingsRadiusDescription =>
      'Местоположение сигналов округляется до этого радиуса, а не указывает точный адрес';

  @override
  String get signalSettingsContent => 'КОНТЕНТ СИГНАЛОВ';

  @override
  String get signalSettingsMaxImages => 'Макс. изображений на сигнал';

  @override
  String get signalSettingsImageLimit => 'Ограничение: 1–4 изображения';

  @override
  String get signalSettingsNotifications => 'УВЕДОМЛЕНИЯ О СИГНАЛАХ';

  @override
  String get signalSettingsNotifySignals => 'Сигналы';

  @override
  String get signalSettingsNotifySignalsSubtitle =>
      'Уведомлять, когда кто-то публикует сигнал';

  @override
  String get signalSettingsNotifyVotes => 'Голоса';

  @override
  String get signalSettingsNotifyVotesSubtitle =>
      'Когда кто-то голосует за ваши комментарии к сигналам';

  @override
  String get adminFollowTitle => 'Социальный администратор';

  @override
  String get adminFollowTabRequests => 'Запросы на подписку';

  @override
  String get adminFollowTabSeedData => 'Тестовые данные';

  @override
  String get adminFollowErrorLoading => 'Ошибка загрузки запросов';

  @override
  String get adminFollowNoPending => 'Нет ожидающих запросов';

  @override
  String get adminFollowApproved => 'Запрос одобрен';

  @override
  String adminFollowApproveFailed(String error) {
    return 'Не удалось одобрить: $error';
  }

  @override
  String get adminFollowDeclined => 'Запрос отклонён';

  @override
  String adminFollowDeclineFailed(String error) {
    return 'Не удалось отклонить: $error';
  }

  @override
  String adminFollowRequestedTime(String time) {
    return 'Запрошено $time';
  }

  @override
  String get adminFollowDecline => 'Отклонить';

  @override
  String get adminFollowAccept => 'Принять';

  @override
  String get adminFollowJustNow => 'только что';

  @override
  String adminFollowMinutesAgo(int minutes) {
    return '$minutes мин. назад';
  }

  @override
  String adminFollowHoursAgo(int hours) {
    return '$hours ч. назад';
  }

  @override
  String adminFollowDaysAgo(int days) {
    return '$days дн. назад';
  }

  @override
  String get adminFollowTestData => 'Тестовые данные';

  @override
  String get adminFollowProfiles => 'Профили';

  @override
  String get adminFollowPosts => 'Публикации';

  @override
  String get adminFollowStories => 'Истории';

  @override
  String get adminFollowComments => 'Комментарии';

  @override
  String get adminFollowDummyUsers => 'Тестовые пользователи';

  @override
  String get adminFollowLog => 'Журнал';

  @override
  String get adminFollowResetAndSeed => 'Сброс и заполнение';

  @override
  String get adminFollowSeedData => 'Заполнить данными';

  @override
  String get adminFollowSeedDescription =>
      'Сброс и заполнение: сначала очищает все тестовые данные, затем добавляет новые.\nЗаполнить данными: добавляет к существующим данным (возможны дубликаты).';

  @override
  String adminFollowSeededSummary(
    int users,
    int posts,
    int stories,
    int comments,
  ) {
    return 'Добавлено: $users пользователей, $posts публикаций, $stories историй, $comments комментариев';
  }

  @override
  String get adminPostsTitle => 'Сигналы';

  @override
  String get adminPostsDeleteAll => 'Удалить все сигналы';

  @override
  String get adminPostsRefresh => 'Обновить снимок';

  @override
  String get adminPostsFilterHint => 'Фильтровать по содержимому или ID автора';

  @override
  String adminPostsLoadFailed(String error) {
    return 'Не удалось загрузить публикации: $error';
  }

  @override
  String get adminPostsNoMatched => 'Публикации не найдены';

  @override
  String get adminPostsFilterAll => 'Все';

  @override
  String get adminPostsFilterSignals => 'Сигналы';

  @override
  String get adminPostsFilterExpired => 'Истёкшие';

  @override
  String get adminPostsFilterLocation => 'Местоположение';

  @override
  String get adminPostsFilterMedia => 'Медиа';

  @override
  String get adminPostsDeletePostTitle => 'Удалить публикацию?';

  @override
  String get adminPostsDeletePostMessage =>
      'Удаление публикации немедленно убирает её из Firebase. Это действие нельзя отменить.';

  @override
  String get adminPostsDeleteConfirm => 'Удалить';

  @override
  String get adminPostsDeleteSignalsTitle => 'Удалить сигналы?';

  @override
  String adminPostsDeleteFilteredMessage(int filtered, int total) {
    return 'Удалить отфильтрованные ($filtered) или все ($total) сигналы.';
  }

  @override
  String adminPostsDeleteAllMessage(int total) {
    return 'Удалить все $total сигналов.';
  }

  @override
  String get adminPostsDeleteWarning =>
      'Это действие нельзя отменить. Введите DELETE для подтверждения.';

  @override
  String get adminPostsDeleteHint => 'DELETE';

  @override
  String get adminPostsNoText => '(без текста)';

  @override
  String adminPostsAuthor(String authorId) {
    return 'Автор $authorId';
  }

  @override
  String adminPostsStats(int comments, int likes) {
    return 'Комментарии $comments · Лайки $likes';
  }

  @override
  String get adminPostsDeletePostTooltip => 'Удалить публикацию';

  @override
  String get bgConnDisableTitle => 'Отключить фоновое подключение?';

  @override
  String get bgConnDisableBody =>
      'Подключение к сети Mesh может быть потеряно, когда приложение находится в фоне. Вы не будете получать уведомления.';

  @override
  String get bgConnDisableConfirm => 'Отключить';

  @override
  String get bgConnTitle => 'Фоновое подключение';

  @override
  String get bgConnSectionConnection => 'ПОДКЛЮЧЕНИЕ';

  @override
  String get bgConnToggleTitle => 'Фоновое подключение';

  @override
  String get bgConnToggleSubtitle =>
      'Держать радио Mesh подключённым, когда приложение в фоне';

  @override
  String get bgConnSectionNotifications => 'ФОНОВЫЕ УВЕДОМЛЕНИЯ';

  @override
  String get bgConnDirectMessages => 'Личные сообщения';

  @override
  String get bgConnDirectMessagesSubtitle =>
      'Уведомлять о личных сообщениях, полученных в фоне';

  @override
  String get bgConnChannelMessages => 'Сообщения в каналах';

  @override
  String get bgConnChannelMessagesSubtitle =>
      'Уведомлять о сообщениях в каналах в фоне';

  @override
  String get bgConnNodeDiscovery => 'Обнаружение нод';

  @override
  String get bgConnNodeDiscoverySubtitle =>
      'Уведомлять при обнаружении новых нод';

  @override
  String get bgConnSectionPersistentNotification => 'ПОСТОЯННОЕ УВЕДОМЛЕНИЕ';

  @override
  String get bgConnSectionBattery => 'БАТАРЕЯ';

  @override
  String get bgConnBatteryGuide => 'Руководство по оптимизации батареи';

  @override
  String get bgConnBatteryGuideSubtitle =>
      'Инструкции для надёжной фоновой работы для конкретных производителей';

  @override
  String get bgConnStyleMinimal => 'Минимальный';

  @override
  String get bgConnStyleDetailed => 'Подробный';

  @override
  String get bgConnNotificationStyle => 'Стиль уведомления';

  @override
  String get bgConnStyleMinimalDesc => 'Показывает «Подключено к [устройство]»';

  @override
  String get bgConnStyleDetailedDesc =>
      'Показывает статус подключения с количеством нод и временем последнего сообщения';

  @override
  String get linkedDevicesTitle => 'Привязанные устройства';

  @override
  String get linkedDevicesSignInRequired => 'Требуется вход';

  @override
  String get linkedDevicesSignInBody =>
      'Войдите, чтобы привязать ваши устройства Meshtastic к социальному профилю.';

  @override
  String get linkedDevicesLinkDescription =>
      'Привяжите ваши устройства Meshtastic к профилю, чтобы другие могли найти вас и подписаться.';

  @override
  String get linkedDevicesNoDevices => 'Нет привязанных устройств';

  @override
  String get linkedDevicesNoDevicesBody =>
      'Подключитесь к устройству Meshtastic и нажмите «Привязать текущее устройство» выше.';

  @override
  String get linkedDevicesLinkAnother =>
      'Чтобы привязать другое устройство, отключитесь от текущего и подключитесь к новому.';

  @override
  String get linkedDevicesLoadFailed =>
      'Не удалось загрузить привязанные устройства';

  @override
  String get linkedDevicesDeviceNotFound => 'Устройство не найдено';

  @override
  String get linkedDevicesUnknownDevice => 'Неизвестное устройство';

  @override
  String get linkedDevicesLinked => 'Устройство привязано к вашему профилю';

  @override
  String linkedDevicesLinkFailed(String error) {
    return 'Не удалось привязать устройство: $error';
  }

  @override
  String get linkedDevicesPrimaryUpdated => 'Основное устройство обновлено';

  @override
  String linkedDevicesSetPrimaryFailed(String error) {
    return 'Не удалось установить основным: $error';
  }

  @override
  String get linkedDevicesUnlinkTitle => 'Отвязать устройство';

  @override
  String get linkedDevicesUnlinkBody =>
      'Удалить это устройство из вашего профиля? Другие больше не будут видеть ваш профиль через это устройство.';

  @override
  String get linkedDevicesUnlinkConfirm => 'Отвязать';

  @override
  String get linkedDevicesUnlinked => 'Устройство отвязано';

  @override
  String linkedDevicesUnlinkFailed(String error) {
    return 'Не удалось отвязать: $error';
  }

  @override
  String get linkedDevicesConnectedDevice => 'Подключённое устройство';

  @override
  String get linkedDevicesLinkButton => 'Привязать';

  @override
  String get linkedDevicesPrimaryBadge => 'ОСНОВНОЕ';

  @override
  String get linkedDevicesSendMessage => 'Отправить сообщение';

  @override
  String get linkedDevicesViewOnMap => 'Показать на карте';

  @override
  String get linkedDevicesSetAsPrimary => 'Сделать основным';

  @override
  String get linkedDevicesSetAsPrimarySubtitle =>
      'Отображать это устройство в вашем профиле';

  @override
  String get homeWidgetsTitle => 'Виджеты главного экрана';

  @override
  String get homeWidgetsSectionAvailable => 'ДОСТУПНЫЕ ВИДЖЕТЫ';

  @override
  String get homeWidgetsMeshStatus => 'Статус Mesh';

  @override
  String get homeWidgetsMeshStatusDesc =>
      'Показывает количество подключённых нод и состояние сети Mesh';

  @override
  String get homeWidgetsSizeSmall => 'Маленький';

  @override
  String get homeWidgetsSizeMedium => 'Средний';

  @override
  String get homeWidgetsSizeLarge => 'Большой';

  @override
  String get homeWidgetsRecentMessages => 'Последние сообщения';

  @override
  String get homeWidgetsRecentMessagesDesc =>
      'Отображает последние сообщения из вашей сети Mesh';

  @override
  String get homeWidgetsDeviceBattery => 'Батарея устройства';

  @override
  String get homeWidgetsDeviceBatteryDesc =>
      'Показывает уровень заряда подключённого устройства';

  @override
  String get homeWidgetsQuickMessage => 'Быстрое сообщение';

  @override
  String get homeWidgetsQuickMessageDesc =>
      'Отправить готовый ответ одним нажатием';

  @override
  String get homeWidgetsLocationBeacon => 'Маяк местоположения';

  @override
  String get homeWidgetsLocationBeaconDesc =>
      'Поделитесь своим местоположением одним нажатием';

  @override
  String get homeWidgetsSectionHowTo => 'КАК ДОБАВИТЬ ВИДЖЕТЫ';

  @override
  String get homeWidgetsSectionTips => 'СОВЕТЫ';

  @override
  String get homeWidgetsAddToHomeScreen =>
      'Добавьте виджеты на главный экран для быстрого доступа';

  @override
  String get homeWidgetsIosLongPress => 'Долгое нажатие на главном экране';

  @override
  String get homeWidgetsIosLongPressDesc =>
      'Нажмите и удерживайте пустую область, пока приложения не начнут трястись';

  @override
  String get homeWidgetsIosTapPlus => 'Нажмите кнопку +';

  @override
  String get homeWidgetsIosTapPlusDesc => 'Расположена в левом верхнем углу';

  @override
  String get homeWidgetsIosSearch => 'Найдите «Socialmesh»';

  @override
  String get homeWidgetsIosSearchDesc =>
      'Или прокрутите для поиска наших виджетов';

  @override
  String get homeWidgetsIosChooseSize => 'Выберите размер виджета';

  @override
  String get homeWidgetsIosChooseSizeDesc =>
      'Смахните для просмотра доступных размеров, нажмите «Добавить виджет»';

  @override
  String get homeWidgetsIosPosition => 'Разместите и нажмите Готово';

  @override
  String get homeWidgetsIosPositionDesc => 'Перетащите в нужное место';

  @override
  String get homeWidgetsAndroidLongPress =>
      'Нажмите и удерживайте пустую область';

  @override
  String get homeWidgetsAndroidTapWidgets => 'Нажмите «Виджеты»';

  @override
  String get homeWidgetsAndroidTapWidgetsDesc => 'В появившемся меню';

  @override
  String get homeWidgetsAndroidLongPressDrag => 'Удерживайте и перетащите';

  @override
  String get homeWidgetsAndroidLongPressDragDesc =>
      'Удерживайте виджет и разместите его на главном экране';

  @override
  String get homeWidgetsIosInstructions => 'Инструкция для iOS';

  @override
  String get homeWidgetsAndroidInstructions => 'Инструкция для Android';

  @override
  String get homeWidgetsTipAutoUpdate =>
      'Виджеты обновляются автоматически при подключении';

  @override
  String get homeWidgetsTipOffline =>
      'При отключении отображаются офлайн-данные';

  @override
  String get homeWidgetsTipTapToOpen =>
      'Нажмите на любой виджет, чтобы открыть приложение';

  @override
  String get homeWidgetsTipAccentColor =>
      'Цвета виджетов соответствуют акцентному цвету';

  @override
  String get radioConfigSaved => 'Конфигурация радио сохранена';

  @override
  String radioConfigSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get radioConfigTitle => 'Радио';

  @override
  String get radioConfigHelp => 'Справка';

  @override
  String get radioConfigSave => 'Сохранить';

  @override
  String get radioConfigSectionRegion => 'РЕГИОН';

  @override
  String get radioConfigSectionModemPreset => 'ПРЕСЕТ МОДЕМА';

  @override
  String get radioConfigSectionTransmission => 'ПЕРЕДАЧА';

  @override
  String get radioConfigTxEnabled => 'Передача включена';

  @override
  String get radioConfigTxEnabledSubtitle =>
      'Разрешить устройству передавать сигнал';

  @override
  String get radioConfigHopLimit => 'Лимит хопов';

  @override
  String get radioConfigHopLimitSubtitle =>
      'Количество раз, которое сообщение может быть ретранслировано';

  @override
  String get radioConfigTxPowerOverride => 'Переопределение мощности передачи';

  @override
  String get radioConfigTxPowerDefault => 'По умолчанию';

  @override
  String get radioConfigTxPowerSubtitle =>
      'Переопределить мощность передачи (0 = использовать по умолчанию)';

  @override
  String get radioConfigSectionAdvanced => 'РАСШИРЕННЫЕ';

  @override
  String get radioConfigUsePreset => 'Использовать пресет';

  @override
  String get radioConfigUsePresetSubtitle =>
      'Использовать пресетные настройки модема вместо пользовательских';

  @override
  String get radioConfigBandwidth => 'Полоса пропускания';

  @override
  String get radioConfigSpreadFactor => 'Коэффициент распространения';

  @override
  String get radioConfigCodingRate => 'Скорость кодирования';

  @override
  String get radioConfigFrequencySlot => 'Слот частоты';

  @override
  String get radioConfigFrequencySlotSubtitle =>
      'Рабочая частота рассчитывается исходя из региона, пресета модема и этого значения';

  @override
  String get radioConfigRxBoostedGain => 'Усиленное усиление RX';

  @override
  String get radioConfigRxBoostedGainSubtitle =>
      'Включить усиленное усиление на приёмниках SX126x';

  @override
  String get radioConfigFrequencyOverride => 'Переопределение частоты';

  @override
  String get radioConfigFrequencyOverrideSubtitle =>
      'Переопределить частоту в MHz (0 = отключено)';

  @override
  String get radioConfigIgnoreMqtt => 'Игнорировать MQTT';

  @override
  String get radioConfigIgnoreMqttSubtitle =>
      'Игнорировать сообщения через MQTT от этого устройства';

  @override
  String get radioConfigOkToMqtt => 'Разрешить MQTT';

  @override
  String get radioConfigOkToMqttSubtitle =>
      'Конфигурацию разрешено отправлять через MQTT-аплинк';

  @override
  String get radioConfigRegionUnset => 'Не задан';

  @override
  String get radioConfigRegionNotConfigured => 'Не настроен';

  @override
  String get radioConfigRegionSelectHint =>
      'Выберите регион, соответствующий законодательству вашей страны';

  @override
  String get radioConfigRegionUs => 'US';

  @override
  String get radioConfigRegionEu433 => 'EU 433';

  @override
  String get radioConfigRegionEu868 => 'EU 868';

  @override
  String get radioConfigRegionChina => 'Китай';

  @override
  String get radioConfigRegionJapan => 'Япония';

  @override
  String get radioConfigRegionAnz => 'ANZ';

  @override
  String get radioConfigRegionKorea => 'Корея';

  @override
  String get radioConfigRegionTaiwan => 'Тайвань';

  @override
  String get radioConfigRegionRussia => 'Россия';

  @override
  String get radioConfigRegionIndia => 'Индия';

  @override
  String get radioConfigRegionNz865 => 'NZ 865';

  @override
  String get radioConfigRegionThailand => 'Таиланд';

  @override
  String get radioConfigRegionUkraine433 => 'Украина 433';

  @override
  String get radioConfigRegionUkraine868 => 'Украина 868';

  @override
  String get radioConfigRegionMalaysia433 => 'Малайзия 433';

  @override
  String get radioConfigRegionMalaysia919 => 'Малайзия 919';

  @override
  String get radioConfigRegionSingapore => 'Сингапур';

  @override
  String get radioConfigRegionLora24 => 'LoRa 2.4ГГц';

  @override
  String get radioConfigPresetLongFast => 'Дальний быстрый';

  @override
  String get radioConfigPresetLongFastDesc =>
      'Наибольший радиус с хорошей скоростью';

  @override
  String get radioConfigPresetLongSlow => 'Дальний медленный';

  @override
  String get radioConfigPresetLongSlowDesc => 'Максимальный радиус, медленнее';

  @override
  String get radioConfigPresetVeryLongSlow => 'Очень дальний медленный';

  @override
  String get radioConfigPresetVeryLongSlowDesc =>
      'Экстремальный радиус, очень медленно';

  @override
  String get radioConfigPresetLongModerate => 'Дальний умеренный';

  @override
  String get radioConfigPresetLongModerateDesc => 'Хороший баланс';

  @override
  String get radioConfigPresetMediumFast => 'Средний быстрый';

  @override
  String get radioConfigPresetMediumFastDesc => 'Средний радиус, быстро';

  @override
  String get radioConfigPresetMediumSlow => 'Средний медленный';

  @override
  String get radioConfigPresetMediumSlowDesc => 'Средний радиус, надёжно';

  @override
  String get radioConfigPresetShortFast => 'Ближний быстрый';

  @override
  String get radioConfigPresetShortFastDesc =>
      'Малый радиус, максимальная скорость';

  @override
  String get radioConfigPresetShortSlow => 'Ближний медленный';

  @override
  String get radioConfigPresetShortSlowDesc => 'Малый радиус, надёжно';

  @override
  String get radioConfigPresetMustMatch =>
      'Все устройства в сети должны использовать один и тот же пресет';

  @override
  String get radioConfigRebootWarning =>
      'Изменение настроек радио приведёт к перезагрузке устройства. Все устройства в вашей сети должны использовать одинаковый регион и пресет модема.';

  @override
  String get cannedModuleTitle => 'Модуль готовых сообщений';

  @override
  String get cannedModuleSaved => 'Конфигурация готовых сообщений сохранена';

  @override
  String cannedModuleSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get cannedModuleSave => 'Сохранить';

  @override
  String get cannedModuleSectionOptions => 'ПАРАМЕТРЫ';

  @override
  String get cannedModuleEnabled => 'Включено';

  @override
  String get cannedModuleEnabledSubtitle =>
      'Включить модуль готовых сообщений на устройстве';

  @override
  String get cannedModuleSendBell => 'Отправлять звонок';

  @override
  String get cannedModuleSendBellSubtitle =>
      'Отправлять символ звонка вместе с сообщениями';

  @override
  String get cannedModuleSectionDeviceMessages => 'СООБЩЕНИЯ УСТРОЙСТВА';

  @override
  String get cannedModuleMessages => 'Сообщения';

  @override
  String get cannedModuleMessagesHint => 'Сообщение 1|Сообщение 2|Сообщение 3';

  @override
  String get cannedModuleMessagesHelp =>
      'Разделяйте сообщения символом | (вертикальная черта). Эти сообщения будут храниться на устройстве и могут отправляться с помощью аппаратных элементов управления.';

  @override
  String get cannedModulePresetManual => 'Ручная настройка';

  @override
  String get cannedModulePresetManualDesc =>
      'Пользовательские настройки GPIO и событий';

  @override
  String get cannedModulePresetRak => 'Поворотный энкодер RAK';

  @override
  String get cannedModulePresetRakDesc =>
      'Преднастроено для поворотного энкодера RAK';

  @override
  String get cannedModulePresetM5Stack => 'M5 Stack Card KB';

  @override
  String get cannedModulePresetM5StackDesc =>
      'Преднастроено для Card KB / RAK Keypad';

  @override
  String get cannedModuleSectionPreset => 'ПРЕСЕТ КОНФИГУРАЦИИ';

  @override
  String get cannedModuleSectionControlType => 'ТИП УПРАВЛЕНИЯ';

  @override
  String get cannedModuleControlRotary => 'Поворотный энкодер';

  @override
  String get cannedModuleControlRotaryDesc =>
      'Простой энкодер, отправляющий импульсы на контакты A/B';

  @override
  String get cannedModuleControlUpDown => 'Кнопки вверх/вниз';

  @override
  String get cannedModuleControlUpDownDesc =>
      'Использует определения A/B/нажатие из брокера входных данных';

  @override
  String get cannedModuleSectionGpio => 'ВХОДЫ GPIO';

  @override
  String get cannedModuleGpioPinA => 'Контакт A';

  @override
  String get cannedModuleGpioPinB => 'Контакт B';

  @override
  String get cannedModuleGpioPressPin => 'Контакт нажатия';

  @override
  String get cannedModuleGpioPinUnset => 'Не задан';

  @override
  String cannedModuleGpioPinLabel(int pin) {
    return 'Контакт $pin';
  }

  @override
  String get cannedModuleEventNone => 'Нет';

  @override
  String get cannedModuleEventUp => 'Вверх';

  @override
  String get cannedModuleEventDown => 'Вниз';

  @override
  String get cannedModuleEventLeft => 'Влево';

  @override
  String get cannedModuleEventRight => 'Вправо';

  @override
  String get cannedModuleEventSelect => 'Выбрать';

  @override
  String get cannedModuleEventBack => 'Назад';

  @override
  String get cannedModuleEventCancel => 'Отмена';

  @override
  String get cannedModuleSectionKeyMapping => 'НАЗНАЧЕНИЕ КЛАВИШ';

  @override
  String get cannedModuleClockwiseEvent => 'Событие по часовой стрелке';

  @override
  String get cannedModuleCounterClockwiseEvent =>
      'Событие против часовой стрелки';

  @override
  String get cannedModulePressEvent => 'Событие нажатия';

  @override
  String get cannedModuleInfoCard =>
      'Здесь настраивается модуль готовых сообщений на устройстве, позволяющий отправлять предопределённые сообщения с помощью аппаратных элементов управления — поворотных энкодеров или кнопок.';

  @override
  String get positionConfigLocationDisabled =>
      'Службы геолокации отключены. Включите GPS в настройках устройства.';

  @override
  String get positionConfigOpenSettings => 'Открыть настройки';

  @override
  String get positionConfigPermissionDenied =>
      'Доступ к геолокации запрещён. Предоставьте разрешение на использование местоположения для этой функции.';

  @override
  String get positionConfigPermissionPermanentlyDenied =>
      'Доступ к геолокации отклонён навсегда. Включите его в настройках устройства.';

  @override
  String get positionConfigLocationUpdated =>
      'Местоположение обновлено из GPS телефона';

  @override
  String positionConfigLocationFailed(String error) {
    return 'Не удалось получить местоположение: $error';
  }

  @override
  String get positionConfigSaved => 'Конфигурация местоположения сохранена';

  @override
  String positionConfigSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get positionConfigTitle => 'Местоположение';

  @override
  String get positionConfigSave => 'Сохранить';

  @override
  String get positionConfigSectionGpsMode => 'РЕЖИМ GPS';

  @override
  String get positionConfigSectionBroadcast => 'НАСТРОЙКИ ТРАНСЛЯЦИИ';

  @override
  String get positionConfigSmartBroadcast => 'Умная трансляция';

  @override
  String get positionConfigSmartBroadcastSubtitle =>
      'Транслировать только при значительном изменении положения';

  @override
  String get positionConfigBroadcastInterval =>
      'Интервал трансляции местоположения';

  @override
  String get positionConfigBroadcastIntervalSubtitle =>
      'Максимальное время между трансляциями местоположения';

  @override
  String get positionConfigGpsUpdateInterval => 'Интервал обновления GPS';

  @override
  String get positionConfigGpsUpdateIntervalSubtitle =>
      'Как часто GPS устройства проверяет положение';

  @override
  String get positionConfigSectionFixed => 'ФИКСИРОВАННОЕ МЕСТОПОЛОЖЕНИЕ';

  @override
  String get positionConfigUseFixed =>
      'Использовать фиксированное местоположение';

  @override
  String get positionConfigUseFixedSubtitle =>
      'Задать положение вручную вместо использования GPS';

  @override
  String get positionConfigLatitude => 'Широта';

  @override
  String get positionConfigLongitude => 'Долгота';

  @override
  String get positionConfigAltitude => 'Высота (метры)';

  @override
  String get positionConfigGettingLocation => 'Определение местоположения...';

  @override
  String get positionConfigUseCurrentLocation =>
      'Использовать текущее местоположение';

  @override
  String get positionConfigFixedInfo =>
      'Фиксированное местоположение полезно для стационарных устройств, таких как маршрутизаторы или базовые станции.';

  @override
  String get positionConfigSectionSmartBroadcast =>
      'НАСТРОЙКИ УМНОЙ ТРАНСЛЯЦИИ';

  @override
  String get positionConfigMinDistance => 'Минимальное расстояние';

  @override
  String get positionConfigMinDistanceSubtitle =>
      'Минимальное расстояние перемещения для трансляции';

  @override
  String get positionConfigMinInterval => 'Минимальный интервал';

  @override
  String get positionConfigMinIntervalSubtitle =>
      'Максимальная частота отправки обновлений местоположения при выполнении условия минимального расстояния';

  @override
  String get positionConfigSectionFlags => 'ФЛАГИ МЕСТОПОЛОЖЕНИЯ';

  @override
  String get positionConfigFlagsInfo =>
      'Дополнительные поля для включения в сообщения о местоположении. Больше флагов означает большие пакеты.';

  @override
  String get positionConfigFlagAltitude => 'Включить высоту';

  @override
  String get positionConfigFlagAltitudeDesc =>
      'Включить высоту в отчёты о местоположении';

  @override
  String get positionConfigFlagSatsInView => 'Включить видимые спутники';

  @override
  String get positionConfigFlagSatsInViewDesc =>
      'Включить количество видимых спутников';

  @override
  String get positionConfigFlagSeqNumber => 'Включить порядковый номер';

  @override
  String get positionConfigFlagSeqNumberDesc =>
      'Включить порядковый номер позиции';

  @override
  String get positionConfigFlagTimestamp => 'Включить метку времени';

  @override
  String get positionConfigFlagTimestampDesc => 'Включить метку времени GPS';

  @override
  String get positionConfigFlagHeading => 'Включить курс';

  @override
  String get positionConfigFlagHeadingDesc =>
      'Включить курс/направление движения';

  @override
  String get positionConfigFlagSpeed => 'Включить скорость';

  @override
  String get positionConfigFlagSpeedDesc =>
      'Включить скорость относительно земли';

  @override
  String get positionConfigFlagMsl => 'Высота над уровнем моря';

  @override
  String get positionConfigFlagMslDesc => 'Сообщать высоту как MSL, а не HAE';

  @override
  String get positionConfigFlagGeoidalSep => 'Включить геоидальное разделение';

  @override
  String get positionConfigFlagGeoidalSepDesc =>
      'Включить значение геоидального разделения';

  @override
  String get positionConfigFlagDop => 'Включить DOP';

  @override
  String get positionConfigFlagDopDesc => 'Включить снижение точности (PDOP)';

  @override
  String get positionConfigFlagHvdop => 'Использовать HDOP / VDOP';

  @override
  String get positionConfigFlagHvdopDesc =>
      'Отправлять отдельные HDOP/VDOP вместо PDOP';

  @override
  String get positionConfigSectionGpsGpio => 'GPS GPIO';

  @override
  String get positionConfigGpsRxGpio => 'GPIO RX GPS';

  @override
  String get positionConfigGpsRxGpioDesc => 'Контакт GPIO для сигнала RX GPS';

  @override
  String get positionConfigGpsTxGpio => 'GPIO TX GPS';

  @override
  String get positionConfigGpsTxGpioDesc => 'Контакт GPIO для сигнала TX GPS';

  @override
  String get positionConfigGpsEnableGpio => 'GPIO включения GPS';

  @override
  String get positionConfigGpsEnableGpioDesc =>
      'Контакт GPIO для управления питанием GPS';

  @override
  String get positionConfigGpioPinUnset => 'Не задан';

  @override
  String positionConfigGpioPinLabel(int pin) {
    return 'Контакт $pin';
  }

  @override
  String get positionConfigGpsModeEnabled => 'Включено';

  @override
  String get positionConfigGpsModeEnabledDesc =>
      'GPS активен и определяет местоположение';

  @override
  String get positionConfigGpsModeDisabled => 'Отключено';

  @override
  String get positionConfigGpsModeDisabledDesc =>
      'GPS присутствует, но выключен';

  @override
  String get positionConfigGpsModeNotPresent => 'Отсутствует';

  @override
  String get positionConfigGpsModeNotPresentDesc =>
      'На этом устройстве нет GPS';

  @override
  String get positionConfigIntervalNever => 'Никогда';

  @override
  String get positionConfigIntervalDefault => 'По умолчанию';

  @override
  String get positionConfigIntervalOnBoot => 'Только при загрузке';

  @override
  String get powerConfigSaved => 'Конфигурация питания сохранена';

  @override
  String powerConfigSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get powerConfigDisabled => 'Отключено';

  @override
  String get powerConfigTitle => 'Питание';

  @override
  String get powerConfigSave => 'Сохранить';

  @override
  String get powerConfigSectionPower => 'ПИТАНИЕ';

  @override
  String get powerConfigPowerSaving => 'Режим энергосбережения';

  @override
  String get powerConfigPowerSavingSubtitle =>
      'Снижать потребление энергии в режиме ожидания';

  @override
  String get powerConfigShutdownOnPowerLoss => 'Выключение при потере питания';

  @override
  String get powerConfigShutdownOnPowerLossSubtitle =>
      'Выключать устройство при отключении внешнего питания';

  @override
  String get powerConfigShutdownDelay => 'Задержка выключения';

  @override
  String get powerConfigShutdownDelaySubtitle =>
      'Время ожидания перед выключением после потери питания';

  @override
  String get powerConfigSectionBattery => 'АККУМУЛЯТОР';

  @override
  String get powerConfigAdcMultiplierOverride =>
      'Переопределение множителя АЦП';

  @override
  String get powerConfigAdcMultiplierOverrideSubtitle =>
      'Переопределить коэффициент делителя напряжения для измерения заряда';

  @override
  String get powerConfigAdcMultiplier => 'Множитель АЦП';

  @override
  String get powerConfigAdcMultiplierHint =>
      'Коэффициент делителя напряжения (2.0 – 6.0)';

  @override
  String get powerConfigSectionSleep => 'НАСТРОЙКИ СНА';

  @override
  String get powerConfigWaitBluetooth => 'Ожидание Bluetooth';

  @override
  String get powerConfigWaitBluetoothSubtitle =>
      'Время ожидания подключения Bluetooth перед переходом в сон';

  @override
  String get powerConfigLightSleep => 'Длительность лёгкого сна';

  @override
  String get powerConfigLightSleepSubtitle =>
      'Продолжительность лёгкого сна перед глубоким сном';

  @override
  String get powerConfigDeepSleep => 'Длительность глубокого сна';

  @override
  String get powerConfigDeepSleepSubtitle =>
      'Продолжительность глубокого сна (SDS)';

  @override
  String get powerConfigMinWakeTime => 'Минимальное время активности';

  @override
  String get powerConfigMinWakeTimeSubtitle =>
      'Минимальное время активности устройства';

  @override
  String get powerConfigWarning =>
      'Настройки питания влияют на время работы от аккумулятора и отзывчивость устройства. Агрессивные настройки сна могут вызвать задержки при получении сообщений.';

  @override
  String get networkConfigNoWifiTitle => 'Нет оборудования WiFi';

  @override
  String get networkConfigNoWifiBody =>
      'Это устройство не имеет оборудования WiFi. Включение WiFi сделает устройство недоступным через BLE. Продолжить?';

  @override
  String get networkConfigSaveAnyway => 'Всё равно сохранить';

  @override
  String get networkConfigSaved => 'Конфигурация сети сохранена';

  @override
  String networkConfigSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get networkConfigTitle => 'Сеть';

  @override
  String get networkConfigSave => 'Сохранить';

  @override
  String get networkConfigSectionWifi => 'WI-FI';

  @override
  String get networkConfigNoWifiWarning =>
      'Это устройство не имеет оборудования WiFi. Включение WiFi сделает устройство недоступным через Bluetooth.';

  @override
  String get networkConfigWifiEnabled => 'WiFi включён';

  @override
  String get networkConfigWifiEnabledSubtitle => 'Подключиться к сети WiFi';

  @override
  String get networkConfigSsid => 'Имя сети (SSID)';

  @override
  String get networkConfigPassword => 'Пароль';

  @override
  String get networkConfigSectionEthernet => 'ETHERNET';

  @override
  String get networkConfigEthernetEnabled => 'Ethernet включён';

  @override
  String get networkConfigEthernetEnabledSubtitle =>
      'Использовать проводное подключение Ethernet';

  @override
  String get networkConfigSectionIpAddress => 'IP-АДРЕС';

  @override
  String get networkConfigSectionTimeSync => 'СИНХРОНИЗАЦИЯ ВРЕМЕНИ';

  @override
  String get networkConfigNtpServer => 'NTP-сервер';

  @override
  String get networkConfigNtpServerSubtitle =>
      'Сервер для синхронизации времени';

  @override
  String get networkConfigSectionUdpBroadcast => 'UDP-ТРАНСЛЯЦИЯ';

  @override
  String get networkConfigUdpBroadcast => 'UDP-трансляция';

  @override
  String get networkConfigUdpBroadcastSubtitle =>
      'Транслировать пакеты через локальную сеть';

  @override
  String get networkConfigUdpBroadcastInfo =>
      'Включает трансляцию пакетов сети через UDP по локальной сети. Полезно для соединения нескольких экземпляров.';

  @override
  String get networkConfigSectionLogging => 'ВЕДЕНИЕ ЖУРНАЛА';

  @override
  String get networkConfigNoHardwareInfo =>
      'Настройки сети доступны только на устройствах с поддержкой WiFi или Ethernet.';

  @override
  String get networkConfigIpModeDhcp => 'DHCP';

  @override
  String get networkConfigIpModeDhcpDesc => 'Автоматически получить IP-адрес';

  @override
  String get networkConfigIpModeStatic => 'Статический';

  @override
  String get networkConfigIpModeStaticDesc =>
      'Использовать настроенный вручную IP-адрес';

  @override
  String get networkConfigRsyslogServer => 'Сервер Rsyslog';

  @override
  String get networkConfigRsyslogServerSubtitle =>
      'Удалённый сервер syslog для журналов устройства';

  @override
  String get ringtoneTitle => 'Рингтон';

  @override
  String get ringtoneDeviceRingtone => 'Рингтон устройства';

  @override
  String get ringtoneCurrentlySet => 'Установлен на устройстве';

  @override
  String get ringtoneSaved => 'Рингтон сохранён на устройстве';

  @override
  String ringtoneSaveFailed(String error) {
    return 'Не удалось сохранить рингтон: $error';
  }

  @override
  String get ringtoneAccessPremium => 'Доступ к премиум-пресетам рингтонов';

  @override
  String get ringtoneCustomAdded => 'Пользовательский рингтон добавлен';

  @override
  String get ringtoneRtttlGuideTitle => 'Руководство по формату RTTTL';

  @override
  String get ringtoneRtttlWhat => 'Что такое RTTTL?';

  @override
  String get ringtoneRtttlWhatContent =>
      'Ring Tone Text Transfer Language (RTTTL) — формат, разработанный Nokia для кодирования рингтонов в виде текстовых строк.';

  @override
  String get ringtoneRtttlFormat => 'Формат';

  @override
  String get ringtoneRtttlHeader => 'Заголовок';

  @override
  String get ringtoneRtttlHeaderContent => 'name:d=duration,o=octave,b=bpm';

  @override
  String get ringtoneRtttlNotes => 'Ноты';

  @override
  String get ringtoneRtttlNotesContent =>
      'длительность, нота, октава (например, 8c5 = восьмая нота C в октаве 5)';

  @override
  String get ringtoneRtttlExample => 'Пример';

  @override
  String get ringtoneRtttlComposerTip =>
      'Попробуйте Nokia Composer онлайн для создания и предварительного прослушивания RTTTL-строк';

  @override
  String get ringtoneRtttlHelp => 'Справка по RTTTL';

  @override
  String get ringtoneSave => 'Сохранить';

  @override
  String get ringtoneSectionRtttl => 'RTTTL СТРОКА';

  @override
  String get ringtoneRtttlHint => 'Вставьте или выберите RTTTL рингтон...';

  @override
  String get ringtoneStop => 'Стоп';

  @override
  String get ringtonePreview => 'Прослушать';

  @override
  String get ringtoneClear => 'Очистить';

  @override
  String get ringtoneTapPreview =>
      'Нажмите «Прослушать», затем «Сохранить на устройство»';

  @override
  String get ringtoneSectionLibrary => 'БИБЛИОТЕКА РИНГТОНОВ';

  @override
  String ringtoneBrowseCount(int count) {
    return 'Просмотреть $count рингтонов';
  }

  @override
  String get ringtoneBrowseSubtitle =>
      'Ищите классические мелодии, темы из сериалов, саундтреки к фильмам и многое другое';

  @override
  String get ringtoneSectionSelected => 'ВЫБРАННЫЙ РИНГТОН';

  @override
  String get ringtoneSectionBuiltIn => 'ВСТРОЕННЫЕ ПРЕСЕТЫ';

  @override
  String get ringtoneSectionCustom => 'ПОЛЬЗОВАТЕЛЬСКИЕ ПРЕСЕТЫ';

  @override
  String get ringtoneAdd => 'Добавить';

  @override
  String get ringtoneNoCustom => 'Нет пользовательских рингтонов';

  @override
  String get ringtoneNoCustomBody =>
      'Нажмите «Добавить», чтобы создать свои пресеты';

  @override
  String get ringtoneFindDeviceTip => 'Совет: найдите своё устройство';

  @override
  String get ringtoneFindDeviceBody =>
      'Отправьте сообщение с эмодзи колокольчика (🔔), чтобы устройство воспроизвело рингтон.';

  @override
  String get ringtoneNameRequired => 'Необходимо указать название';

  @override
  String get ringtoneDefaultDescription => 'Пользовательский рингтон';

  @override
  String get ringtoneAddCustomTitle => 'Добавить пользовательский рингтон';

  @override
  String get ringtoneAddCustomSubtitle =>
      'Создать пользовательский RTTTL пресет рингтона';

  @override
  String get ringtoneAddCustomName => 'Название';

  @override
  String get ringtoneAddCustomRtttl => 'RTTTL строка';

  @override
  String get ringtoneAddCustomDescription => 'Описание (необязательно)';

  @override
  String get ringtoneLibraryTitle => 'Библиотека рингтонов';

  @override
  String get ringtoneLibrarySearchHint =>
      'Поиск по песне, исполнителю или теме...';

  @override
  String get ringtoneLibraryPopularPicks => 'Популярные';

  @override
  String get ringtoneLibraryNoResults => 'Ничего не найдено';

  @override
  String get ringtoneLibraryStartTyping => 'Начните вводить для поиска';

  @override
  String get ringtoneLibraryTryDifferent =>
      'Попробуйте другой поисковый запрос';

  @override
  String ringtoneLibrarySearchCount(int count) {
    return 'Поиск по $count доступным мелодиям';
  }

  @override
  String get ringtoneValidationEmpty => 'RTTTL строка не может быть пустой';

  @override
  String ringtoneValidationTooLong(int length, int max) {
    return 'Слишком длинная: $length/$max символов. Рингтон будет обрезан.';
  }

  @override
  String get ringtoneValidationMissingColons =>
      'Неверный формат: отсутствуют двоеточия. Ожидается name:defaults:notes';

  @override
  String get ringtoneValidationInvalidFormat =>
      'Неверный формат: ожидается name:defaults:notes';

  @override
  String get ringtoneValidationInvalidDefaults =>
      'Неверные значения по умолчанию: ожидается d=duration, o=octave, b=bpm';

  @override
  String get ringtoneValidationNoNotes => 'В строке RTTTL не найдено нот';

  @override
  String ringtoneValidationInvalidNote(String note) {
    return 'Неверная нота: «$note»';
  }

  @override
  String get ringtoneValidationNoValidNotes => 'Не найдено допустимых нот';

  @override
  String get accountSubTitle => 'Аккаунт';

  @override
  String get accountSubSectionAccount => 'АККАУНТ';

  @override
  String get accountSubSectionPremium => 'ПРЕМИУМ';

  @override
  String get accountSubSectionManage => 'УПРАВЛЕНИЕ';

  @override
  String get accountSubGuestAccount => 'Гостевой аккаунт';

  @override
  String get accountSubSignedIn => 'Выполнен вход';

  @override
  String get accountSubLinkedAccounts => 'Связанные аккаунты';

  @override
  String get accountSubLinkEmailPrompt =>
      'Привяжите email, чтобы сохранить данные на всех устройствах';

  @override
  String get accountSubLinkAccountBtn => 'Привязать аккаунт';

  @override
  String get accountSubMfaRequiresInternet =>
      'Двухфакторная аутентификация требует подключения к интернету.';

  @override
  String get accountSubSignOutBtn => 'Выйти';

  @override
  String get accountSubSignInToSync =>
      'Войдите, чтобы синхронизировать данные на всех устройствах';

  @override
  String get accountSubLocalDataAvailable =>
      'Ваши локальные данные всегда доступны';

  @override
  String get accountSubContinueGoogle => 'Продолжить с Google';

  @override
  String get accountSubContinueApple => 'Продолжить с Apple';

  @override
  String get accountSubContinueGitHub => 'Продолжить с GitHub';

  @override
  String get accountSubContinueX => 'Продолжить с X';

  @override
  String get accountSubExpiresToday => 'Истекает сегодня';

  @override
  String get accountSubExpiresTomorrow => 'Истекает завтра';

  @override
  String accountSubExpiresDate(int day, String month) {
    return 'Истекает $day $month';
  }

  @override
  String accountSubCancelledExpires(String expiresText) {
    return 'Отменена · $expiresText';
  }

  @override
  String get accountSubPaymentIssue => 'Проблема с оплатой — обновите данные';

  @override
  String get accountSubSignInToSyncShort => 'Войдите для синхронизации';

  @override
  String get accountSubMonthlySubscription => 'Ежемесячная подписка';

  @override
  String get accountSubSubscriptionExpired => 'Подписка истекла';

  @override
  String get accountSubSignInToEnable => 'Войдите выше, чтобы активировать';

  @override
  String get accountSubSyncAllDevices =>
      'Синхронизация на всех ваших устройствах';

  @override
  String get accountSubBadgeCancelled => 'ОТМЕНЕНА';

  @override
  String get accountSubBadgeActive => 'АКТИВНА';

  @override
  String get accountSubBadgeExpired => 'ИСТЕКЛА';

  @override
  String get accountSubCloudSync => 'Облачная синхронизация';

  @override
  String get accountSubWontRenew =>
      'Ваша подписка не будет продлена. Вы можете подписаться повторно в любое время.';

  @override
  String get accountSubFeatureNodedex => 'NodeDex — встречи, метки, заметки';

  @override
  String get accountSubFeatureAutomations =>
      'Автоматизации — правила и триггеры';

  @override
  String get accountSubFeatureWidgets =>
      'Пользовательские виджеты — макеты и данные';

  @override
  String get accountSubFeatureBackup =>
      'Резервная копия — восстановление после переустановки или на новом телефоне';

  @override
  String get accountSubFeatureOffline => 'Полностью работает без интернета';

  @override
  String get accountSubRenewSubscription => 'Продлить подписку';

  @override
  String get accountSubManageSubscription => 'Управление подпиской';

  @override
  String get accountSubSignInToSubscribe => 'Войдите, чтобы подписаться';

  @override
  String get accountSubSubRequiresInternet =>
      'Для оформления подписки требуется подключение к интернету.';

  @override
  String get accountSubRenew => 'Продлить';

  @override
  String get accountSubSubscribe => 'Подписаться';

  @override
  String get accountSubCouldNotLoadStatus =>
      'Не удалось загрузить статус подписки';

  @override
  String get accountSubFeaturePacks => 'Пакеты функций';

  @override
  String get accountSubAllUnlocked => 'Все функции разблокированы!';

  @override
  String accountSubOneTimePurchases(int owned, int total) {
    return 'Разовые покупки · $owned из $total';
  }

  @override
  String get accountSubViewFeatures => 'Просмотр функций';

  @override
  String get accountSubPremiumRequiresInternet =>
      'Для покупки премиум-функций требуется подключение к интернету.';

  @override
  String get accountSubViewAndPurchase => 'Просмотр и покупка';

  @override
  String get accountSubRestorePurchases => 'Восстановить покупки';

  @override
  String get accountSubRestorePurchasesSubtitle =>
      'Восстановить ранее приобретённые элементы';

  @override
  String get accountSubRestoreRequiresInternet =>
      'Для восстановления покупок требуется подключение к интернету.';

  @override
  String get accountSubPurchasesRestored => 'Покупки успешно восстановлены!';

  @override
  String get accountSubPurchasesAlreadyActive => 'Ваши покупки уже активны';

  @override
  String get accountSubNoPurchasesFound =>
      'Покупок для восстановления не найдено';

  @override
  String get accountSubTermsOfService => 'Условия использования';

  @override
  String get accountSubPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get accountSubSignInRequiresInternet =>
      'Для входа требуется подключение к интернету.';

  @override
  String get accountSubCannotConnectSignIn =>
      'Не удаётся подключиться к службе входа. Проверьте подключение к интернету и повторите попытку.';

  @override
  String accountSubSignInFailed(String message) {
    return 'Ошибка входа: $message';
  }

  @override
  String get accountSubSignInFailedRetry =>
      'Ошибка входа. Пожалуйста, попробуйте снова.';

  @override
  String get accountSubLinkGitHubTitle => 'Привязать аккаунт GitHub';

  @override
  String accountSubAccountExistsLinking(String email, String provider) {
    return 'Аккаунт с адресом $email уже существует и использует $provider.\n\nВойти через $provider, чтобы привязать аккаунт GitHub?';
  }

  @override
  String accountSubSignInWithProvider(String provider) {
    return 'Войти через $provider';
  }

  @override
  String get accountSubGitHubLinked => 'Аккаунт GitHub успешно привязан!';

  @override
  String get accountSubFailedLinkAccounts => 'Не удалось связать аккаунты';

  @override
  String get accountSubSignOutRequiresInternet =>
      'Для выхода требуется подключение к интернету.';

  @override
  String get accountSubSignOutConfirmTitle => 'Выход';

  @override
  String get accountSubSignOutConfirmMsg => 'Вы уверены, что хотите выйти?';

  @override
  String get accountSubSignedOutSuccess => 'Выход выполнен';

  @override
  String accountSubGenericError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get accountSubLinkAccountSheetTitle => 'Привязать аккаунт';

  @override
  String get accountSubLinkSignInMethod =>
      'Привяжите способ входа, чтобы сохранить свои данные';

  @override
  String get accountSubLinkWithGoogle => 'Привязать через Google';

  @override
  String get accountSubLinkWithApple => 'Привязать через Apple';

  @override
  String get accountSubLinkWithX => 'Привязать через X';

  @override
  String get accountSubManageSubRequiresInternet =>
      'Для управления подпиской требуется подключение к интернету.';

  @override
  String get accountSubIosManageHint =>
      'Перейдите в Настройки > Apple ID > Подписки для управления';

  @override
  String get accountSubAndroidManageHint =>
      'Перейдите в Play Store > Платежи и подписки для управления';

  @override
  String get accountSubGuestName => 'Гость';

  @override
  String get accountSubTapToEditProfile =>
      'Нажмите, чтобы редактировать профиль';

  @override
  String get accountSubSignInToCreateProfile =>
      'Войдите, чтобы создать профиль';

  @override
  String get accountSubTwoFactorAuth => 'Двухфакторная аутентификация';

  @override
  String get accountSubBadgeOffline => 'Не в сети';

  @override
  String get accountSubBadgeUnavailable => 'Недоступно';

  @override
  String get accountSubBadgeOn => 'ВКЛ';

  @override
  String get accountSubSyncSyncing => 'Синхронизация';

  @override
  String get accountSubSyncSynced => 'Синхронизировано';

  @override
  String get accountSubSyncError => 'Ошибка';

  @override
  String get accountSubSyncReady => 'Готово';

  @override
  String get accountSubSyncOffline => 'Не в сети';

  @override
  String get accountSubMonthJanuary => 'Январь';

  @override
  String get accountSubMonthFebruary => 'Февраль';

  @override
  String get accountSubMonthMarch => 'Март';

  @override
  String get accountSubMonthApril => 'Апрель';

  @override
  String get accountSubMonthMay => 'Май';

  @override
  String get accountSubMonthJune => 'Июнь';

  @override
  String get accountSubMonthJuly => 'Июль';

  @override
  String get accountSubMonthAugust => 'Август';

  @override
  String get accountSubMonthSeptember => 'Сентябрь';

  @override
  String get accountSubMonthOctober => 'Октябрь';

  @override
  String get accountSubMonthNovember => 'Ноябрь';

  @override
  String get accountSubMonthDecember => 'Декабрь';

  @override
  String get accountSubUnlockCloudSync =>
      'Разблокировать облачную синхронизацию';

  @override
  String get accountSubSyncBackupAll =>
      'Синхронизируйте и создавайте резервные копии данных сети на всех ваших устройствах';

  @override
  String get accountSubCouldNotLoadPrices => 'Не удалось загрузить цены';

  @override
  String get accountSubSubActivated => 'Подписка активирована!';

  @override
  String get accountSubPurchaseFailed => 'Покупка не удалась';

  @override
  String get accountSubAutoRenewDisclaimer =>
      'Подписки автоматически продлеваются, если не отменить их не позднее чем за 24 часа до окончания текущего периода.';

  @override
  String get accountSubYearlySave => 'Ежегодная (экономия 44%)';

  @override
  String get accountSubMonthlyProduct => 'Ежемесячная';

  @override
  String get accountSubLinkingRequiresInternet =>
      'Для привязки аккаунта требуется подключение к интернету.';

  @override
  String get accountSubConfirm => 'Подтвердить';

  @override
  String get accountSubCancel => 'Отмена';

  @override
  String get dataExportTitle => 'Экспорт данных';

  @override
  String get dataExportSectionMessages => 'Сообщения';

  @override
  String get dataExportSectionTelemetry => 'Телеметрия';

  @override
  String get dataExportSectionPositionData => 'Данные местоположения';

  @override
  String get dataExportSectionAutomations => 'Автоматизации';

  @override
  String get dataExportSectionNetwork => 'Сеть';

  @override
  String get dataExportSectionCompleteExport => 'Полный экспорт';

  @override
  String get dataExportSectionClearData => 'Очистить данные';

  @override
  String get dataExportAllMessages => 'Все сообщения';

  @override
  String get dataExportAllMessagesSubtitle =>
      'Экспорт всех сообщений каналов и личных сообщений';

  @override
  String get dataExportDeviceMetrics => 'Метрики устройства';

  @override
  String get dataExportDeviceMetricsSubtitle =>
      'Журналы заряда аккумулятора, напряжения, загруженности';

  @override
  String get dataExportEnvironmentMetrics => 'Метрики окружающей среды';

  @override
  String get dataExportEnvironmentMetricsSubtitle =>
      'Журналы температуры, влажности, давления';

  @override
  String get dataExportAirQuality => 'Качество воздуха';

  @override
  String get dataExportAirQualitySubtitle => 'Показания PM2.5, PM10, CO2';

  @override
  String get dataExportPowerMetrics => 'Метрики питания';

  @override
  String get dataExportPowerMetricsSubtitle => 'Напряжение и ток каналов';

  @override
  String get dataExportPositionHistory => 'История местоположений';

  @override
  String get dataExportPositionHistorySubtitle =>
      'Журналы GPS с метками времени';

  @override
  String get dataExportRoutes => 'Маршруты';

  @override
  String get dataExportRoutesSubtitle => 'Записанные маршруты и треки';

  @override
  String get dataExportTraceroutes => 'Трассировки';

  @override
  String get dataExportTraceroutesSubtitle => 'Анализ сетевых путей';

  @override
  String get dataExportAutomationRules => 'Правила автоматизации';

  @override
  String get dataExportAutomationRulesSubtitle =>
      'Все конфигурации автоматизации';

  @override
  String get dataExportExecutionLog => 'Журнал выполнения';

  @override
  String get dataExportExecutionLogSubtitle =>
      'История срабатываний автоматизации с результатами';

  @override
  String get dataExportNodeList => 'Список нод';

  @override
  String get dataExportNodeListSubtitle =>
      'Все обнаруженные ноды с подробностями';

  @override
  String get dataExportExportAll => 'Экспортировать все данные';

  @override
  String get dataExportExportAllSubtitle =>
      'Полная резервная копия всех данных приложения';

  @override
  String get dataExportClearAll => 'Очистить все данные';

  @override
  String get dataExportClearAllSubtitle =>
      'Удалить все сохранённые данные телеметрии, маршруты и журналы';

  @override
  String get dataExportInfoText =>
      'Экспортированные файлы можно передать по электронной почте, AirDrop или сохранить в «Файлы». Нажмите значок корзины для очистки определённых данных.';

  @override
  String get dataExportFormatCsv => 'CSV';

  @override
  String get dataExportFormatGpx => 'GPX';

  @override
  String get dataExportFormatJson => 'JSON';

  @override
  String get dataExportTooltipClearData => 'Очистить данные';

  @override
  String get dataExportTooltipExport => 'Экспорт';

  @override
  String dataExportClearConfirmTitle(String dataName) {
    return 'Очистить $dataName?';
  }

  @override
  String dataExportClearConfirmMsg(String dataName) {
    return 'Это действие необратимо удалит все данные $dataName.';
  }

  @override
  String get dataExportClearConfirmBtn => 'Удалить';

  @override
  String get dataExportClearAllConfirmTitle => 'Очистить все данные?';

  @override
  String get dataExportClearAllConfirmMsg =>
      'Это необратимо удалит ВСЕ сохранённые данные, включая телеметрию, маршруты и журналы автоматизации.';

  @override
  String get dataExportClearAllConfirmBtn => 'Удалить всё';

  @override
  String dataExportExportFailed(String error) {
    return 'Экспорт не выполнен: $error';
  }

  @override
  String get dataExportDataCleared => 'Данные очищены';

  @override
  String dataExportClearFailed(String error) {
    return 'Не удалось очистить данные: $error';
  }

  @override
  String get dataExportAllDataCleared => 'Все данные очищены';

  @override
  String get dataExportNoRoutesToExport => 'Нет маршрутов для экспорта';

  @override
  String get dataExportNoAutomationsToExport =>
      'Нет автоматизаций для экспорта';

  @override
  String get dataExportNoAutomationLogEntries =>
      'Нет записей журнала автоматизации';

  @override
  String get dataExportClearAllMessages => 'все сообщения';

  @override
  String get dataExportClearDeviceMetrics => 'метрики устройства';

  @override
  String get dataExportClearEnvironmentMetrics => 'метрики окружающей среды';

  @override
  String get dataExportClearAirQualityData => 'данные качества воздуха';

  @override
  String get dataExportClearPowerMetrics => 'метрики питания';

  @override
  String get dataExportClearPositionHistory => 'история местоположений';

  @override
  String get dataExportClearAllRoutes => 'все маршруты';

  @override
  String get dataExportClearTracerouteData => 'данные трассировки';

  @override
  String get dataExportClearAllAutomationRules => 'все правила автоматизации';

  @override
  String get dataExportClearAutomationLog => 'журнал автоматизации';

  @override
  String get dataExportShareSubjectMessages => 'Экспорт сообщений Socialmesh';

  @override
  String get dataExportShareSubjectDeviceMetrics =>
      'Экспорт метрик устройства Socialmesh';

  @override
  String get dataExportShareSubjectEnvironmentMetrics =>
      'Экспорт метрик окружающей среды Socialmesh';

  @override
  String get dataExportShareSubjectAirQuality =>
      'Экспорт данных качества воздуха Socialmesh';

  @override
  String get dataExportShareSubjectPowerMetrics =>
      'Экспорт метрик питания Socialmesh';

  @override
  String get dataExportShareSubjectPositionHistory =>
      'Экспорт истории местоположений Socialmesh';

  @override
  String get dataExportShareSubjectRoutes => 'Экспорт маршрутов Socialmesh';

  @override
  String get dataExportShareSubjectTraceroutes =>
      'Экспорт трассировок Socialmesh';

  @override
  String get dataExportShareSubjectAutomations =>
      'Экспорт автоматизаций Socialmesh';

  @override
  String get dataExportShareSubjectAutomationLog =>
      'Экспорт журнала автоматизации Socialmesh';

  @override
  String get dataExportShareSubjectNodeList => 'Экспорт списка нод Socialmesh';

  @override
  String get dataExportShareSubjectComplete => 'Полный экспорт Socialmesh';

  @override
  String get dataExportUnknownSender => 'Неизвестно';

  @override
  String get dataExportSnrNotAvailable => 'Н/Д';

  @override
  String get deviceMgmtTitle => 'Управление устройством';

  @override
  String deviceMgmtDefaultWarning(String action) {
    return 'Вы уверены, что хотите $action? Это действие нельзя отменить.';
  }

  @override
  String deviceMgmtSuccessDisconnect(String action) {
    return '$action — устройство отключится';
  }

  @override
  String deviceMgmtSuccessCommandSent(String action) {
    return 'Команда $action отправлена';
  }

  @override
  String deviceMgmtFailed(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get deviceMgmtNotConnected =>
      'Устройство не подключено. Подключите устройство для управления им.';

  @override
  String get deviceMgmtSectionPower => 'ПИТАНИЕ';

  @override
  String get deviceMgmtSectionTime => 'ВРЕМЯ';

  @override
  String get deviceMgmtSectionReset => 'СБРОС';

  @override
  String get deviceMgmtSectionFirmware => 'ПРОШИВКА';

  @override
  String get deviceMgmtRebootTitle => 'Перезагрузить устройство';

  @override
  String get deviceMgmtRebootSubtitle => 'Перезапустить устройство';

  @override
  String get deviceMgmtRebootWarning =>
      'Устройство перезагрузится через 2 секунды. Вы будете кратковременно отключены на время перезапуска.';

  @override
  String get deviceMgmtShutdownTitle => 'Выключить устройство';

  @override
  String get deviceMgmtShutdownSubtitle => 'Отключить питание устройства';

  @override
  String get deviceMgmtShutdownWarning =>
      'Устройство выключится через 2 секунды. Для повторного включения потребуется нажать кнопку питания вручную.';

  @override
  String get deviceMgmtSyncTimeTitle => 'Синхронизировать время';

  @override
  String get deviceMgmtSyncTimeSubtitle =>
      'Установить на устройстве текущее время';

  @override
  String get deviceMgmtResetNodeDbTitle => 'Сбросить базу данных нод';

  @override
  String get deviceMgmtResetNodeDbSubtitle =>
      'Удалить все известные ноды с устройства и из приложения';

  @override
  String get deviceMgmtResetNodeDbWarning =>
      'Это удалит все обнаруженные ноды с устройства и из приложения. Ноды будут обнаружены повторно со временем.';

  @override
  String get deviceMgmtFactoryResetConfigTitle =>
      'Сброс конфигурации к заводским настройкам';

  @override
  String get deviceMgmtFactoryResetConfigSubtitle =>
      'Сбросить всё, кроме базы данных нод';

  @override
  String get deviceMgmtFactoryResetConfigWarning =>
      'Это удалит каналы, регион и все настройки, но сохранит базу данных нод.\n\nУстройство перезагрузится через 5 секунд. Вам потребуется заново настроить регион.';

  @override
  String get deviceMgmtFullFactoryResetTitle =>
      'Полный сброс к заводским настройкам';

  @override
  String get deviceMgmtFullFactoryResetSubtitle =>
      'Полностью стереть данные и сбросить устройство';

  @override
  String get deviceMgmtFullFactoryResetWarning =>
      'ВНИМАНИЕ: Это полностью сотрёт данные устройства, включая:\n· Всю конфигурацию\n· Все каналы\n· Все известные ноды\n· Идентификатор устройства\n\nУстройство перезагрузится через 5 секунд. Вам потребуется выполнить сопряжение и настройку заново.';

  @override
  String get deviceMgmtEnterDfuTitle => 'Перейти в режим DFU';

  @override
  String get deviceMgmtEnterDfuSubtitle =>
      'Загрузиться в режим обновления прошивки';

  @override
  String get deviceMgmtEnterDfuWarning =>
      'Устройство перейдёт в режим обновления прошивки (DFU). Для прошивки новой прошивки или сброса устройства потребуется инструмент обновления прошивки.\n\nВы будете отключены от устройства.';

  @override
  String get displayConfigTitle => 'Конфигурация дисплея';

  @override
  String get displayConfigSave => 'Сохранить';

  @override
  String get displayConfigSectionScreen => 'ЭКРАН';

  @override
  String get displayConfigSectionTimeCompass => 'ВРЕМЯ И КОМПАС';

  @override
  String get displayConfigSectionOledType => 'ТИП OLED ЭКРАНА';

  @override
  String get displayConfigSectionUnitsFormat => 'ЕДИНИЦЫ И ФОРМАТ';

  @override
  String get displayConfigSectionDisplayMode => 'РЕЖИМ ОТОБРАЖЕНИЯ';

  @override
  String get displayConfigScreenTimeoutAlwaysOn => 'Всегда включён';

  @override
  String displayConfigScreenTimeoutSeconds(int seconds) {
    return '$secondsс';
  }

  @override
  String displayConfigScreenTimeoutLabel(String value) {
    return 'Таймаут экрана: $value';
  }

  @override
  String get displayConfigScreenTimeoutDesc =>
      'Через какое время экран отключится';

  @override
  String get displayConfigAutoCarouselDisabled => 'Отключено';

  @override
  String get displayConfigAutoCarouselOff => 'Выкл';

  @override
  String displayConfigAutoCarouselLabel(String value) {
    return 'Авто-карусель: $value';
  }

  @override
  String get displayConfigAutoCarouselDesc =>
      'Автоматически переключаться между экранами';

  @override
  String get displayConfigFlipScreen => 'Перевернуть экран';

  @override
  String get displayConfigFlipScreenSubtitle => 'Повернуть дисплей на 180°';

  @override
  String get displayConfigWakeOnTap => 'Включение по касанию/движению';

  @override
  String get displayConfigWakeOnTapSubtitle =>
      'Включать экран при движении устройства';

  @override
  String get displayConfigLongNodeNames => 'Длинные имена нод';

  @override
  String get displayConfigLongNodeNamesSubtitle =>
      'Показывать полные имена нод на экране устройства';

  @override
  String get displayConfigMessageBubbles => 'Пузырьки сообщений';

  @override
  String get displayConfigMessageBubblesSubtitle =>
      'Отображать сообщения в виде пузырьков на экране';

  @override
  String get displayConfig12hClock => '12-часовые часы';

  @override
  String get displayConfig12hClockSubtitle =>
      'Отображать время в 12-часовом формате (AM/PM)';

  @override
  String get displayConfigCompassNorth => 'Компас всегда направлен на север';

  @override
  String get displayConfigCompassNorthSubtitle =>
      'Отметка курса снаружи окружности всегда указывает на север';

  @override
  String get displayConfigCompassOrientation => 'Ориентация компаса';

  @override
  String get displayConfigCompassOrientationDesc =>
      'Настроить поворот отображения компаса';

  @override
  String get displayConfigDeg0 => '0°';

  @override
  String get displayConfigDeg90 => '90°';

  @override
  String get displayConfigDeg180 => '180°';

  @override
  String get displayConfigDeg270 => '270°';

  @override
  String get displayConfigDeg0Inv => '0° инвертированный';

  @override
  String get displayConfigDeg90Inv => '90° инвертированный';

  @override
  String get displayConfigDeg180Inv => '180° инвертированный';

  @override
  String get displayConfigDeg270Inv => '270° инвертированный';

  @override
  String get displayConfigOledTypeTitle => 'Тип OLED';

  @override
  String get displayConfigOledTypeDesc =>
      'Переопределить автоматическое определение OLED';

  @override
  String get displayConfigOledAuto => 'Авто';

  @override
  String get displayConfigOledAutoDesc => 'Автоматически определять тип OLED';

  @override
  String get displayConfigOledSsd1306Desc => 'Распространённый OLED 128x64';

  @override
  String get displayConfigOledSh1106Desc => 'Контроллер OLED 132x64';

  @override
  String get displayConfigOledSh1107Desc => 'Вертикальный OLED 64x128';

  @override
  String get displayConfigOledSh1107_128Desc => 'Квадратный OLED 128x128';

  @override
  String get displayConfigMeasurementUnits => 'Единицы измерения';

  @override
  String get displayConfigMetric => 'Метрическая';

  @override
  String get displayConfigMetricDesc => 'Километры, Цельсий';

  @override
  String get displayConfigImperial => 'Имперская';

  @override
  String get displayConfigImperialDesc => 'Мили, Фаренгейт';

  @override
  String get displayConfigBoldHeadings => 'Жирные заголовки';

  @override
  String get displayConfigBoldHeadingsSubtitle =>
      'Отображать курсовые заголовки жирным шрифтом';

  @override
  String get displayConfigDisplayModeTitle => 'Режим отображения';

  @override
  String get displayConfigDisplayModeDesc => 'Выбрать режим отрисовки дисплея';

  @override
  String get displayConfigModeDefault => 'По умолчанию';

  @override
  String get displayConfigModeDefaultDesc => 'Стандартный макет дисплея';

  @override
  String get displayConfigModeTwoColor => 'Двухцветный';

  @override
  String get displayConfigModeTwoColorDesc =>
      'Оптимизировано для двухцветных дисплеев';

  @override
  String get displayConfigModeInverted => 'Инвертированный';

  @override
  String get displayConfigModeInvertedDesc => 'Тёмный фон, светлый текст';

  @override
  String get displayConfigModeColor => 'Цветной';

  @override
  String get displayConfigModeColorDesc => 'Режим полноцветного дисплея';

  @override
  String get displayConfigSaved => 'Конфигурация дисплея сохранена';

  @override
  String displayConfigSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get extNotifTitle => 'Внешнее уведомление';

  @override
  String get extNotifSave => 'Сохранить';

  @override
  String get extNotifNotConnected =>
      'Подключитесь к устройству для настройки параметров внешнего уведомления';

  @override
  String get extNotifSectionOptions => 'Параметры';

  @override
  String get extNotifSectionPrimaryGpio => 'Основной GPIO';

  @override
  String get extNotifSectionOptionalGpio => 'Дополнительный GPIO';

  @override
  String get extNotifEnabled => 'Включено';

  @override
  String get extNotifEnabledSubtitle => 'Включить модуль внешнего уведомления';

  @override
  String get extNotifAlertOnBell => 'Оповещение при звонке';

  @override
  String get extNotifAlertOnBellSubtitle =>
      'Срабатывать при получении символа звонка';

  @override
  String get extNotifAlertOnMessage => 'Оповещение при сообщении';

  @override
  String get extNotifAlertOnMessageSubtitle =>
      'Срабатывать при получении сообщения';

  @override
  String get extNotifUsePwm => 'Использовать ШИМ-зуммер';

  @override
  String get extNotifUsePwmSubtitle =>
      'Использовать ШИМ-выход для мелодий вместо вкл/выкл';

  @override
  String get extNotifUseI2s => 'Использовать I2S как зуммер';

  @override
  String get extNotifUseI2sSubtitle =>
      'Использовать аудиовыход I2S для мелодий RTTTL (T-Watch, T-Deck)';

  @override
  String get extNotifActiveHigh => 'Активный высокий';

  @override
  String get extNotifActiveHighSubtitle =>
      'Вывод подтягивается к высокому уровню при активации';

  @override
  String get extNotifOutputGpioPin => 'Вывод GPIO выхода';

  @override
  String get extNotifGpioUnset => 'Не задан';

  @override
  String extNotifGpioValue(int value) {
    return 'GPIO $value';
  }

  @override
  String extNotifGpioPinLabel(int pin) {
    return 'Контакт $pin';
  }

  @override
  String get extNotifOutputDuration => 'Длительность выхода';

  @override
  String get extNotifOutputDurationSubtitle =>
      'Как долго держать выход активным';

  @override
  String get extNotifDurationDefault => 'По умолчанию';

  @override
  String get extNotifDuration100ms => '100 мс';

  @override
  String get extNotifDuration250ms => '250 мс';

  @override
  String get extNotifDuration500ms => '500 мс';

  @override
  String get extNotifDuration1s => '1 секунда';

  @override
  String get extNotifDuration2s => '2 секунды';

  @override
  String get extNotifDuration5s => '5 секунд';

  @override
  String get extNotifNagTimeout => 'Тайм-аут повтора';

  @override
  String get extNotifNagTimeoutSubtitle => 'Как часто повторять уведомление';

  @override
  String get extNotifTimeoutDisabled => 'Отключено';

  @override
  String get extNotifTimeout15s => '15 секунд';

  @override
  String get extNotifTimeout30s => '30 секунд';

  @override
  String get extNotifTimeout1m => '1 минута';

  @override
  String get extNotifTimeout2m => '2 минуты';

  @override
  String get extNotifTimeout5m => '5 минут';

  @override
  String get extNotifTimeout10m => '10 минут';

  @override
  String get extNotifBuzzerOnBell => 'Зуммер при звонке';

  @override
  String get extNotifBuzzerOnBellSubtitle =>
      'Активировать GPIO зуммера при получении звонка';

  @override
  String get extNotifVibraOnBell => 'Вибрация при звонке';

  @override
  String get extNotifVibraOnBellSubtitle =>
      'Активировать мотор вибрации при получении звонка';

  @override
  String get extNotifBuzzerOnMsg => 'Зуммер при сообщении';

  @override
  String get extNotifBuzzerOnMsgSubtitle =>
      'Активировать GPIO зуммера при получении сообщения';

  @override
  String get extNotifVibraOnMsg => 'Вибрация при сообщении';

  @override
  String get extNotifVibraOnMsgSubtitle =>
      'Активировать мотор вибрации при получении сообщения';

  @override
  String get extNotifBuzzerGpioPin => 'Контакт GPIO зуммера';

  @override
  String get extNotifVibraGpioPin => 'Контакт GPIO вибрации';

  @override
  String get extNotifSaved => 'Настройки внешнего уведомления сохранены';

  @override
  String extNotifSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get extNotifLoadFailed => 'Не удалось загрузить конфигурацию';

  @override
  String get iftttConfigTitle => 'Интеграция IFTTT';

  @override
  String get iftttConfigSave => 'Сохранить';

  @override
  String get iftttConfigPremiumTitle => 'Подключитесь к 700+ сервисам';

  @override
  String get iftttConfigPremiumDesc =>
      'Управляйте устройствами умного дома, записывайте события в таблицы, отправляйте сообщения в Discord/Slack и многое другое.';

  @override
  String get iftttConfigPremiumExampleTitle => 'Нода отключилась';

  @override
  String get iftttConfigPremiumExampleDesc =>
      'Автоматически включить умный свет или отправить себе уведомление, когда вашу ноду перестаёт отвечать.';

  @override
  String get iftttConfigSectionWebhook => 'ВЕБХУК';

  @override
  String get iftttConfigSectionMessageTriggers => 'ТРИГГЕРЫ СООБЩЕНИЙ';

  @override
  String get iftttConfigSectionNodeTriggers => 'ТРИГГЕРЫ СОСТОЯНИЯ УЗЛА';

  @override
  String get iftttConfigSectionTelemetryTriggers => 'ТРИГГЕРЫ ТЕЛЕМЕТРИИ';

  @override
  String get iftttConfigSectionGeofencing => 'ГЕОЗОНЫ';

  @override
  String get iftttConfigEnable => 'Включить IFTTT';

  @override
  String get iftttConfigEnableSubtitle =>
      'Отправлять события в сервис IFTTT Webhooks';

  @override
  String get iftttConfigDataSharingTitle => 'Передача данных IFTTT';

  @override
  String get iftttConfigDataSharingMsg =>
      'При включённых IFTTT Webhooks данные о событиях сети (сообщения, статус нод, местоположения, уровень заряда) будут отправляться на серверы IFTTT через ваш персональный ключ вебхука.\n\nIFTTT — сторонний сервис со своей политикой конфиденциальности. Передаваться будут только выбранные вами типы событий.';

  @override
  String get iftttConfigIUnderstand => 'Понятно';

  @override
  String get iftttConfigWebhookKeyLabel => 'Ключ вебхука';

  @override
  String get iftttConfigWebhookKeyHint => 'например, cMcOnB_zaJTrZwsVvzVTHY';

  @override
  String get iftttConfigWebhookKeyHelper =>
      'Скопируйте из URL IFTTT Webhooks после /use/';

  @override
  String get iftttConfigTesting => 'Проверка...';

  @override
  String get iftttConfigTestConnection => 'Проверить соединение';

  @override
  String get iftttConfigEnterKeyToEnable =>
      'Введите ключ вебхука для включения IFTTT';

  @override
  String get iftttConfigEnterKeyFirst => 'Сначала введите ключ вебхука';

  @override
  String get iftttConfigTestSuccess =>
      'Тестовый вебхук отправлен! Проверьте свой апплет IFTTT.';

  @override
  String get iftttConfigTestFailed =>
      'Не удалось отправить тестовый вебхук. Проверьте ключ.';

  @override
  String get iftttConfigMessageReceived => 'Получено сообщение';

  @override
  String get iftttConfigMessageReceivedSubtitle =>
      'Срабатывать при получении сообщения';

  @override
  String get iftttConfigSosEmergency => 'SOS / Экстренный сигнал';

  @override
  String get iftttConfigSosEmergencySubtitle =>
      'Срабатывать при ключевых словах SOS, экстренно, помощь, mayday';

  @override
  String get iftttConfigNodeActive => 'Нода активна';

  @override
  String get iftttConfigNodeActiveSubtitle =>
      'Срабатывать, когда нода недавно отвечал';

  @override
  String get iftttConfigNodeInactive => 'Нода неактивна';

  @override
  String get iftttConfigNodeInactiveSubtitle =>
      'Срабатывать, когда нода долго не отвечает';

  @override
  String get iftttConfigBatteryLow => 'Низкий заряд';

  @override
  String get iftttConfigBatteryLowSubtitle =>
      'Срабатывать, когда заряд ниже порогового значения';

  @override
  String get iftttConfigBatteryThreshold => 'Порог заряда';

  @override
  String get iftttConfigTemperatureAlert => 'Предупреждение о температуре';

  @override
  String get iftttConfigTemperatureAlertSubtitle =>
      'Срабатывать, когда температура превышает порог';

  @override
  String get iftttConfigTemperatureThreshold => 'Порог температуры';

  @override
  String get iftttConfigPositionUpdates => 'Обновления местоположения';

  @override
  String get iftttConfigPositionUpdatesSubtitle =>
      'Срабатывать, когда нода покидает геозону';

  @override
  String get iftttConfigGeofenceRadius => 'Радиус геозоны';

  @override
  String get iftttConfigGeofenceRadiusHint => '1000';

  @override
  String get iftttConfigGeofenceUnitM => 'м';

  @override
  String get iftttConfigCenterLatitude => 'Широта центра';

  @override
  String get iftttConfigCenterLatHint => '-33.8688';

  @override
  String get iftttConfigCenterLongitude => 'Долгота центра';

  @override
  String get iftttConfigCenterLonHint => '151.2093';

  @override
  String get iftttConfigMonitoredNode => 'Отслеживаемая нода';

  @override
  String get iftttConfigNoNodeSelected =>
      'Нода не выбран. Будут отслеживаться все ноды.';

  @override
  String get iftttConfigAlertCooldown => 'Пауза между оповещениями';

  @override
  String get iftttConfigCooldown5min => '5 мин';

  @override
  String get iftttConfigCooldown15min => '15 мин';

  @override
  String get iftttConfigCooldown30min => '30 мин';

  @override
  String get iftttConfigCooldown1hour => '1 час';

  @override
  String get iftttConfigCooldown2hours => '2 часа';

  @override
  String get iftttConfigCooldown4hours => '4 часа';

  @override
  String get iftttConfigCooldown8hours => '8 часов';

  @override
  String get iftttConfigCooldown24hours => '24 часа';

  @override
  String get iftttConfigCooldownDesc =>
      'Минимальное время между оповещениями о геозоне для одной ноды';

  @override
  String get iftttConfigPickOnMap => 'Выбрать на карте';

  @override
  String get iftttConfigSetupGuide => 'Руководство по настройке';

  @override
  String get iftttConfigStep1 => 'Создайте аккаунт на ifttt.com';

  @override
  String get iftttConfigStep2 => 'Найдите сервис «Webhooks» и подключите его';

  @override
  String get iftttConfigStep3 =>
      'Перейдите в настройки Webhooks, чтобы найти ваш ключ';

  @override
  String get iftttConfigStep4 =>
      'Создавайте апплеты с Webhooks в качестве триггера';

  @override
  String get iftttConfigEventNamesRef => 'Справочник имён событий';

  @override
  String get iftttConfigEventNamesSubtitle =>
      'Используйте эти имена в ваших апплетах IFTTT';

  @override
  String get iftttConfigSaved => 'Настройки IFTTT сохранены';

  @override
  String get iftttConfigSaveFailed => 'Не удалось сохранить настройки IFTTT';

  @override
  String get webhookModeIfttt => 'IFTTT Key';

  @override
  String get webhookModeCustomUrl => 'Custom URL';

  @override
  String get webhookConfigCustomUrlLabel => 'Webhook URL';

  @override
  String get webhookConfigCustomUrlHint =>
      'http://192.168.1.100:8123/api/webhook/...';

  @override
  String get webhookConfigCustomUrlHelper =>
      'POST JSON to any HTTP/HTTPS endpoint. LAN addresses supported.';

  @override
  String get webhookConfigEnterUrlToEnable =>
      'Please enter a webhook URL to enable';

  @override
  String get webhookConfigEnterUrlFirst => 'Please enter a webhook URL first';

  @override
  String get mqttConfigTitle => 'MQTT';

  @override
  String get mqttConfigSave => 'Сохранить';

  @override
  String mqttConfigDutyCycleWarning(String percent) {
    return 'В вашем регионе допускается рабочий цикл $percent%. Использование MQTT с ретрансляцией по радио не рекомендуется при ограничении рабочего цикла — дополнительный трафик быстро перегрузит вашу сеть LoRa.';
  }

  @override
  String get mqttConfigEnable => 'Включить MQTT';

  @override
  String get mqttConfigEnableSubtitle =>
      'Подключить ноду к серверу для отправки и получения данных через интернет';

  @override
  String get mqttConfigNoWifiAdvisory =>
      'Это устройство не имеет оборудования WiFi. Включите прокси клиента ниже, чтобы приложение могло передавать сообщения от имени устройства.';

  @override
  String get mqttConfigNoWifiTitle => 'Нет оборудования WiFi';

  @override
  String get mqttConfigNoWifiMsg =>
      'Это устройство не имеет оборудования WiFi. Без прокси клиента устройство не может самостоятельно подключиться к MQTT-серверу.\n\nВсё равно сохранить без прокси?';

  @override
  String get mqttConfigSaveAnyway => 'Всё равно сохранить';

  @override
  String get mqttConfigSectionServer => 'СЕРВЕР';

  @override
  String get mqttConfigSectionAuth => 'АУТЕНТИФИКАЦИЯ';

  @override
  String get mqttConfigSectionOptions => 'ПАРАМЕТРЫ';

  @override
  String get mqttConfigServerAddressLabel => 'Адрес сервера';

  @override
  String get mqttConfigServerAddressHint => 'mqtt.meshtastic.org';

  @override
  String get mqttConfigTopicRootLabel => 'Корневая тема';

  @override
  String get mqttConfigTopicRootHint => 'msh';

  @override
  String get mqttConfigUseTls => 'Использовать TLS';

  @override
  String get mqttConfigUseTlsSubtitle => 'Шифровать подключение к MQTT';

  @override
  String get mqttConfigUsernameLabel => 'Имя пользователя';

  @override
  String get mqttConfigOptionalHint => 'Необязательно';

  @override
  String get mqttConfigPasswordLabel => 'Пароль';

  @override
  String get mqttConfigEncryption => 'Шифрование';

  @override
  String get mqttConfigEncryptionSubtitle =>
      'Шифровать сообщения, отправляемые по MQTT';

  @override
  String get mqttConfigJsonOutput => 'Вывод JSON';

  @override
  String get mqttConfigJsonOutputSubtitle =>
      'Публиковать сообщения в формате JSON (без шифрования)';

  @override
  String get mqttConfigClientProxy => 'Прокси клиента';

  @override
  String get mqttConfigClientProxySubtitle =>
      'Использовать интернет с телефона для MQTT\n(Необходимо для устройств без WiFi)';

  @override
  String get mqttConfigMapReporting => 'Отчёт на карте';

  @override
  String get mqttConfigMapReportingSubtitle =>
      'Передавать местоположение на публичную карту сети';

  @override
  String get mqttConfigMapReportSettingsHeader => 'НАСТРОЙКИ ОТЧЁТА НА КАРТЕ';

  @override
  String mqttConfigPublishInterval(int minutes) {
    return 'Интервал публикации: $minutes мин';
  }

  @override
  String get mqttConfigPublishIntervalDesc =>
      'Как часто передавать местоположение на карту';

  @override
  String get mqttConfigPositionPrecision => 'Точность местоположения';

  @override
  String get mqttConfigPositionPrecisionDesc =>
      'Приблизительная точность положения для карты';

  @override
  String get mqttConfigPrecisionWithin5_8km => 'В пределах 5,8 км';

  @override
  String get mqttConfigPrecisionWithin2_9km => 'В пределах 2,9 км';

  @override
  String get mqttConfigPrecisionWithin1_5km => 'В пределах 1,5 км';

  @override
  String get mqttConfigPrecisionWithin700m => 'В пределах 700 м';

  @override
  String get mqttConfigPrecisionUnknown => 'Неизвестно';

  @override
  String get mqttConfigInfoText =>
      'MQTT позволяет устройству выгружать свои данные на публичные карты в интернете, а также обмениваться данными через интернет. Можно обеспечить связь с нодами, находящимися вне зоны прямого радиоприёма.';

  @override
  String get mqttConfigSaved => 'Конфигурация MQTT сохранена';

  @override
  String mqttConfigSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get securityConfigTitle => 'Безопасность';

  @override
  String get securityConfigSave => 'Сохранить';

  @override
  String get securityConfigSectionDmKey => 'КЛЮЧ ЛИЧНЫХ СООБЩЕНИЙ';

  @override
  String get securityConfigSectionAdminKeys => 'КЛЮЧИ АДМИНИСТРАТОРА';

  @override
  String get securityConfigSectionDeviceMgmt => 'УПРАВЛЕНИЕ УСТРОЙСТВОМ';

  @override
  String get securityConfigSectionAccessControls => 'КОНТРОЛЬ ДОСТУПА';

  @override
  String get securityConfigPublicKey => 'Публичный ключ';

  @override
  String get securityConfigNoKeySet => 'Ключ не задан';

  @override
  String get securityConfigPublicKeyDesc =>
      'Ваш публичный ключ отправляется другим нодам для защищённого обмена сообщениями';

  @override
  String get securityConfigPrivateKey => 'Приватный ключ';

  @override
  String get securityConfigPrivateKeyHint =>
      '32-байтовый ключ в кодировке Base64';

  @override
  String get securityConfigPrivateKeyDesc =>
      'Используется для вычисления общего секрета с удалёнными устройствами';

  @override
  String get securityConfigRegenKeyPair => 'Обновить пару ключей';

  @override
  String get securityConfigGenerating => 'Генерация...';

  @override
  String get securityConfigGenerate => 'Сгенерировать';

  @override
  String get securityConfigRegenDesc =>
      'Создать новую пару ключей (публичный ключ будет получен автоматически)';

  @override
  String get securityConfigKeyBackup => 'Резервная копия ключа';

  @override
  String get securityConfigBackupDesc =>
      'Создайте резервную копию приватного ключа в защищённом хранилище для восстановления. Ключи хранятся в связке ключей устройства с включённой синхронизацией iCloud.';

  @override
  String get securityConfigBackupBtn => 'Создать копию';

  @override
  String get securityConfigRestoreBtn => 'Восстановить';

  @override
  String get securityConfigDeleteBackupTooltip => 'Удалить резервную копию';

  @override
  String get securityConfigAdminKeysDesc =>
      'Публичные ключи, которым разрешено администрировать эту ноду удаленно';

  @override
  String get securityConfigPrimaryAdminKey => 'Основной ключ администратора';

  @override
  String get securityConfigSecondaryAdminKey =>
      'Дополнительный ключ администратора';

  @override
  String get securityConfigTertiaryAdminKey => 'Третий ключ администратора';

  @override
  String get securityConfigAdminKeyHint => 'Публичный ключ в кодировке Base64';

  @override
  String get securityConfigManagedMode => 'Управляемый режим';

  @override
  String get securityConfigManagedModeSubtitle =>
      'Устройство управляется внешней системой';

  @override
  String get securityConfigSerialConsole => 'Последовательная консоль';

  @override
  String get securityConfigSerialConsoleSubtitle =>
      'Включить доступ к консоли через USB';

  @override
  String get securityConfigDebugLogging => 'Журнал отладки';

  @override
  String get securityConfigDebugLoggingSubtitle =>
      'Включить подробный вывод журнала отладки';

  @override
  String get securityConfigAdminChannel => 'Канал администратора';

  @override
  String get securityConfigAdminChannelSubtitle =>
      'Разрешить удалённое администрирование через канал администратора';

  @override
  String get securityConfigWarning =>
      'Отключение последовательной консоли или включение управляемого режима может затруднить восстановление устройства. Убедитесь, что понимаете последствия, прежде чем вносить изменения.';

  @override
  String get securityConfigDeleteBackupTitle => 'Удалить резервную копию?';

  @override
  String get securityConfigDeleteBackupMsg =>
      'Это необратимо удалит резервную копию приватного ключа из защищённого хранилища.';

  @override
  String get securityConfigDeleteBtn => 'Удалить';

  @override
  String get securityConfigNewKeyPairGenerated => 'Создана новая пара ключей';

  @override
  String securityConfigKeyGenFailed(String error) {
    return 'Не удалось сгенерировать ключ: $error';
  }

  @override
  String get securityConfigSaved => 'Конфигурация безопасности сохранена';

  @override
  String securityConfigSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get securityConfigInvalidPrivateKey =>
      'Неверный формат приватного ключа';

  @override
  String get securityConfigInvalidAdminKey =>
      'Неверный формат ключа администратора';

  @override
  String get securityConfigNoDevice => 'Нет подключённого устройства';

  @override
  String get securityConfigBackedUp =>
      'Приватный ключ сохранён в защищённом хранилище';

  @override
  String securityConfigBackupFailed(String error) {
    return 'Не удалось создать резервную копию ключа: $error';
  }

  @override
  String get securityConfigNoBackupFound =>
      'Резервная копия для этого устройства не найдена';

  @override
  String get securityConfigRestored =>
      'Приватный ключ восстановлен из резервной копии';

  @override
  String securityConfigRestoreFailed(String error) {
    return 'Не удалось восстановить ключ: $error';
  }

  @override
  String get securityConfigBackupDeleted => 'Резервная копия удалена';

  @override
  String securityConfigDeleteBackupFailed(String error) {
    return 'Не удалось удалить резервную копию: $error';
  }

  @override
  String get trafficMgmtTitle => 'Управление трафиком';

  @override
  String get trafficMgmtSave => 'Сохранить';

  @override
  String get trafficMgmtSectionGeneral => 'ОБЩЕЕ';

  @override
  String get trafficMgmtSectionPositionDedup => 'ДЕДУПЛИКАЦИЯ МЕСТОПОЛОЖЕНИЙ';

  @override
  String get trafficMgmtSectionNodeinfoResponse => 'ПРЯМОЙ ОТВЕТ НА NODEINFO';

  @override
  String get trafficMgmtSectionRateLimit => 'ОГРАНИЧЕНИЕ СКОРОСТИ';

  @override
  String get trafficMgmtSectionUnknownPackets => 'НЕИЗВЕСТНЫЕ ПАКЕТЫ';

  @override
  String get trafficMgmtSectionHopMgmt => 'УПРАВЛЕНИЕ ПЕРЕХОДАМИ';

  @override
  String get trafficMgmtEnable => 'Включить управление трафиком';

  @override
  String get trafficMgmtEnableSubtitle =>
      'Главный переключатель всех функций управления трафиком';

  @override
  String get trafficMgmtPositionDedup => 'Дедупликация местоположений';

  @override
  String get trafficMgmtPositionDedupSubtitle =>
      'Отбрасывать дублирующиеся пакеты местоположения';

  @override
  String trafficMgmtPrecisionBits(int value) {
    return 'Биты точности: $value';
  }

  @override
  String get trafficMgmtPrecisionBitsDesc =>
      'Меньшее значение означает более агрессивную дедупликацию';

  @override
  String trafficMgmtPrecisionBitsLabel(int value) {
    return '$value бит';
  }

  @override
  String trafficMgmtMinInterval(int seconds) {
    return 'Мин. интервал: $secondsс';
  }

  @override
  String get trafficMgmtMinIntervalDesc =>
      'Минимальный интервал между обновлениями местоположения в секундах';

  @override
  String get trafficMgmtDirectResponse => 'Прямой ответ';

  @override
  String get trafficMgmtDirectResponseSubtitle =>
      'Отвечать на запросы NodeInfo напрямую';

  @override
  String trafficMgmtMaxHops(int value) {
    return 'Макс. переходов: $value';
  }

  @override
  String get trafficMgmtMaxHopsDesc =>
      'Максимальное число переходов для прямого ответа NodeInfo';

  @override
  String get trafficMgmtPerNodeRateLimit => 'Ограничение скорости на ноду';

  @override
  String get trafficMgmtPerNodeRateLimitSubtitle =>
      'Ограничивать скорость пакетов от отдельных нод';

  @override
  String trafficMgmtWindow(int seconds) {
    return 'Окно: $secondsс';
  }

  @override
  String get trafficMgmtWindowDesc =>
      'Временное окно для расчёта ограничения скорости';

  @override
  String trafficMgmtMaxPackets(int value) {
    return 'Макс. пакетов: $value';
  }

  @override
  String get trafficMgmtMaxPacketsDesc =>
      'Максимальное число пакетов в окне перед отбрасыванием';

  @override
  String get trafficMgmtDropUnknown => 'Отбрасывать неизвестные пакеты';

  @override
  String get trafficMgmtDropUnknownSubtitle =>
      'Отбрасывать пакеты из неизвестных источников';

  @override
  String trafficMgmtThreshold(int value) {
    return 'Порог: $value';
  }

  @override
  String get trafficMgmtThresholdDesc =>
      'Количество неизвестных пакетов перед отбрасыванием';

  @override
  String get trafficMgmtExhaustHopTelemetry =>
      'Исчерпание переходов для телеметрии';

  @override
  String get trafficMgmtExhaustHopTelemetrySub =>
      'Установить лимит переходов 0 для ретранслируемой телеметрии';

  @override
  String get trafficMgmtExhaustHopPosition =>
      'Исчерпание переходов для местоположения';

  @override
  String get trafficMgmtExhaustHopPositionSub =>
      'Установить лимит переходов 0 для ретранслируемых местоположений';

  @override
  String get trafficMgmtPreserveRouterHops =>
      'Сохранять переходы маршрутизатора';

  @override
  String get trafficMgmtPreserveRouterHopsSub =>
      'Сохранять счётчик переходов для нод-маршрутизаторов';

  @override
  String get trafficMgmtSaved => 'Конфигурация управления трафиком сохранена';

  @override
  String trafficMgmtSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get adminPanelTitle => 'Администратор';

  @override
  String get adminPanelSectionShop => 'УПРАВЛЕНИЕ МАГАЗИНОМ';

  @override
  String get adminPanelShopDashboard => 'Панель управления магазином';

  @override
  String get adminPanelShopDashboardSub =>
      'Управление товарами, заказами и запасами';

  @override
  String get adminPanelDeviceShop => 'Магазин устройств';

  @override
  String get adminPanelDeviceShopSub =>
      'Просмотр и управление списком устройств';

  @override
  String get adminPanelSectionModeration => 'МОДЕРАЦИЯ КОНТЕНТА';

  @override
  String get adminPanelBugReports => 'Отчёты об ошибках';

  @override
  String get adminPanelBugReportsSub =>
      'Просмотр отчётов об ошибках и ответы пользователям';

  @override
  String get adminPanelReviewMod => 'Модерация отзывов';

  @override
  String get adminPanelReviewModSub =>
      'Одобрение или отклонение отзывов пользователей';

  @override
  String get adminPanelReportedContent => 'Жалобы на контент';

  @override
  String get adminPanelReportedContentSub =>
      'Проверка публикаций и комментариев, на которые поступили жалобы';

  @override
  String get adminPanelWidgetReview => 'Проверка виджетов для маркетплейса';

  @override
  String get adminPanelWidgetReviewSub =>
      'Одобрение ожидающих заявок на виджеты';

  @override
  String get adminPanelSectionUsers => 'УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ';

  @override
  String get adminPanelSocialSeeding => 'Социальное заполнение';

  @override
  String get adminPanelSocialSeedingSub =>
      'Управление запросами на подписку и связями';

  @override
  String get adminPanelUserPurchases => 'Покупки пользователей';

  @override
  String get adminPanelUserPurchasesSub =>
      'Просмотр транзакций пользователей и управление ими';

  @override
  String get adminPanelSectionConfig => 'КОНФИГУРАЦИЯ ПРИЛОЖЕНИЯ';

  @override
  String get adminPanelBroadcast => 'Массовое уведомление';

  @override
  String get adminPanelBroadcastSub =>
      'Отправить push-уведомление всем пользователям';

  @override
  String get adminPanelQrStyles => 'Стили QR-кодов';

  @override
  String get adminPanelQrStylesSub =>
      'Предварительный просмотр фирменных дизайнов QR-кодов';

  @override
  String get adminPanelSectionDiag => 'ДИАГНОСТИКА УСТРОЙСТВ';

  @override
  String get adminPanelDiagHarness => 'Стенд диагностики';

  @override
  String get adminPanelDiagHarnessSub =>
      'Запуск протокольных проверок и экспорт отладочного пакета';

  @override
  String get adminPanelConformance => 'Стенд соответствия';

  @override
  String get adminPanelConformanceSub =>
      'Тесты соответствия и нагрузочные тесты устройств с привязкой к провайдеру';

  @override
  String get adminPanelStorageHealth => 'Storage Health';

  @override
  String get adminPanelStorageHealthSub =>
      'Verify WAL mode is active on all SQLite databases';

  @override
  String get adminStorageHealthTitle => 'Storage Health';

  @override
  String get adminStorageHealthRefresh => 'Refresh';

  @override
  String get adminStorageHealthChecking => 'Checking databases…';

  @override
  String get adminStorageHealthAllPass => 'All databases in WAL mode';

  @override
  String get adminStorageHealthSomeFail => 'Some databases not in WAL mode';

  @override
  String adminStorageHealthSummary(int pass, int fail, int total) {
    return '$pass passed · $fail failed · $total total';
  }

  @override
  String get adminStorageStatusWal => 'WAL';

  @override
  String get adminStorageStatusUnknown => 'UNKNOWN';

  @override
  String get adminStorageStatusMissing => 'NOT OPENED';

  @override
  String get adminStorageStatusError => 'ERROR';

  @override
  String get adminStorageWalPresent => '-wal present';

  @override
  String get adminStorageWalAbsent => '-wal absent';

  @override
  String get adminStorageShmPresent => '-shm present';

  @override
  String get adminStorageShmAbsent => '-shm absent';

  @override
  String get adminStoragePathCopied => 'Path copied to clipboard';

  @override
  String get adminPanelBadgeOverflow => '99+';

  @override
  String get adminBroadcastTitle => 'Массовое уведомление';

  @override
  String get adminBroadcastSignInRequired =>
      'Для отправки уведомлений необходимо войти в систему';

  @override
  String get adminBroadcastTestSentTitle => 'Тест отправлен';

  @override
  String get adminBroadcastSentTitle => 'Рассылка отправлена';

  @override
  String get adminBroadcastTestSentBody =>
      'Тестовое уведомление отправлено всем администраторам.';

  @override
  String get adminBroadcastSentBody =>
      'Уведомление отправлено всем пользователям Socialmesh.';

  @override
  String get adminBroadcastDone => 'Готово';

  @override
  String adminBroadcastFailedDetailed(String code, String message) {
    return 'Не удалось отправить: $code - $message';
  }

  @override
  String adminBroadcastFailed(String error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String get adminBroadcastSelectDeepLink => 'Выбрать глубокую ссылку';

  @override
  String get adminBroadcastSelectIcon => 'Выбрать иконку';

  @override
  String get adminBroadcastPreviewTitlePlaceholder => 'Заголовок уведомления';

  @override
  String get adminBroadcastPreviewBodyPlaceholder =>
      'Здесь будет отображаться текст уведомления...';

  @override
  String get adminBroadcastWarning =>
      'Это отправит push-уведомление всем пользователям Socialmesh. Используйте редко и только для важных объявлений.';

  @override
  String get adminBroadcastIconLabel => 'Иконка';

  @override
  String get adminBroadcastClear => 'Очистить';

  @override
  String get adminBroadcastFieldTitle => 'Заголовок';

  @override
  String get adminBroadcastTitleHint => 'Заголовок уведомления...';

  @override
  String get adminBroadcastTitleRequired => 'Заголовок обязателен';

  @override
  String get adminBroadcastFieldMessage => 'Сообщение';

  @override
  String get adminBroadcastMessageHint => 'Текст уведомления...';

  @override
  String get adminBroadcastMessageRequired => 'Сообщение обязательно';

  @override
  String get adminBroadcastDeepLinkLabel => 'Глубокая ссылка (необязательно)';

  @override
  String get adminBroadcastDeepLinkHelper =>
      'Экран, который откроется при нажатии на уведомление.';

  @override
  String get adminBroadcastDeepLinkNone => 'Нет';

  @override
  String get adminBroadcastSendingTest => 'Отправка теста...';

  @override
  String get adminBroadcastTestButton => 'Тест только для администраторов';

  @override
  String get adminBroadcastTestHint =>
      'Отправьте тестовое уведомление администраторам перед рассылкой всем пользователям.';

  @override
  String adminBroadcastCountdownCancel(int seconds) {
    return 'Отмена — отправка через $secondsс...';
  }

  @override
  String get adminBroadcastSending => 'Отправка...';

  @override
  String get adminBroadcastSendAll => 'Отправить всем';

  @override
  String adminBroadcastSendHint(int seconds) {
    return 'Отправляет push-уведомление всем пользователям Socialmesh. Обратный отсчёт $secondsс даёт время для отмены.';
  }

  @override
  String get adminBroadcastPreviewLabel => 'ПРЕДПРОСМОТР';

  @override
  String get adminBroadcastPreviewAppName => 'SOCIALMESH';

  @override
  String get adminBroadcastPreviewNow => 'сейчас';

  @override
  String get adminBroadcastIconCatGeneral => 'ОБЩЕЕ';

  @override
  String get adminBroadcastIconCatSocial => 'СОЦИАЛЬНОЕ';

  @override
  String get adminBroadcastIconCatPremium => 'ПРЕМИУМ';

  @override
  String get adminBroadcastIconAnnouncement => 'Объявление';

  @override
  String get adminBroadcastIconUpdate => 'Обновление приложения';

  @override
  String get adminBroadcastIconFeature => 'Новая функция';

  @override
  String get adminBroadcastIconMaintenance => 'Техническое обслуживание';

  @override
  String get adminBroadcastIconAlert => 'Предупреждение';

  @override
  String get adminBroadcastIconCelebration => 'Праздник';

  @override
  String get adminBroadcastIconTip => 'Совет';

  @override
  String get adminBroadcastIconSignals => 'Signals';

  @override
  String get adminBroadcastIconNodedex => 'NodeDex';

  @override
  String get adminBroadcastIconAether => 'Aether';

  @override
  String get adminBroadcastIconActivity => 'Активность';

  @override
  String get adminBroadcastIconPresence => 'Presence';

  @override
  String get adminBroadcastIconCommunity => 'Сообщество';

  @override
  String get adminBroadcastIconWorldMap => 'Карта мира';

  @override
  String get adminBroadcastIconThemes => 'Набор тем';

  @override
  String get adminBroadcastIconRingtones => 'Набор рингтонов';

  @override
  String get adminBroadcastIconWidgets => 'Виджеты';

  @override
  String get adminBroadcastIconAutomations => 'Автоматизации';

  @override
  String get adminBroadcastIconIfttt => 'Интеграция IFTTT';

  @override
  String get adminBroadcastDefTitleAnnouncement => 'Объявление';

  @override
  String get adminBroadcastDefTitleUpdate => 'Доступно обновление приложения';

  @override
  String get adminBroadcastDefTitleFeature => 'Новая функция';

  @override
  String get adminBroadcastDefTitleMaintenance =>
      'Плановое техническое обслуживание';

  @override
  String get adminBroadcastDefTitleAlert => 'Важное предупреждение';

  @override
  String get adminBroadcastDefTitleCelebration => 'Праздник';

  @override
  String get adminBroadcastDefTitleTip => 'Полезный совет';

  @override
  String get adminBroadcastDefTitleSignals => 'Обновление Signals';

  @override
  String get adminBroadcastDefTitleNodedex => 'Обновление NodeDex';

  @override
  String get adminBroadcastDefTitleAether => 'Обновление Aether';

  @override
  String get adminBroadcastDefTitleActivity => 'Обновление активности';

  @override
  String get adminBroadcastDefTitlePresence => 'Обновление Presence';

  @override
  String get adminBroadcastDefTitleCommunity => 'Обновление сообщества';

  @override
  String get adminBroadcastDefTitleWorldMap => 'Обновление карты мира';

  @override
  String get adminBroadcastDefTitleThemes => 'Новый набор тем';

  @override
  String get adminBroadcastDefTitleRingtones => 'Новый набор рингтонов';

  @override
  String get adminBroadcastDefTitleWidgets => 'Новые виджеты';

  @override
  String get adminBroadcastDefTitleAutomations => 'Обновление автоматизаций';

  @override
  String get adminBroadcastDefTitleIfttt => 'Интеграция IFTTT';

  @override
  String get adminBroadcastDefBodyAnnouncement =>
      'У нас есть важное объявление для сообщества Socialmesh.';

  @override
  String get adminBroadcastDefBodyUpdate =>
      'Доступна новая версия Socialmesh с улучшениями и исправлениями ошибок.';

  @override
  String get adminBroadcastDefBodyFeature =>
      'Мы только что запустили новую функцию в Socialmesh. Попробуйте!';

  @override
  String get adminBroadcastDefBodyMaintenance =>
      'Сервисы Socialmesh будут кратковременно недоступны в связи с плановым техническим обслуживанием.';

  @override
  String get adminBroadcastDefBodyAlert =>
      'Обратите внимание на важную проблему, затрагивающую Socialmesh.';

  @override
  String get adminBroadcastDefBodyCelebration =>
      'У нас есть повод отпраздновать вместе с сообществом Socialmesh!';

  @override
  String get adminBroadcastDefBodyTip =>
      'Вот полезный совет, который поможет вам получить максимум от Socialmesh.';

  @override
  String get adminBroadcastDefBodySignals =>
      'Узнайте, что нового в Signals — вашей mesh-ленте присутствия.';

  @override
  String get adminBroadcastDefBodyNodedex =>
      'В NodeDex появились новые функции для обнаружения и отслеживания mesh-нод.';

  @override
  String get adminBroadcastDefBodyAether =>
      'Новые улучшения Aether для обмена полётами теперь доступны.';

  @override
  String get adminBroadcastDefBodyActivity =>
      'Посмотрите, что происходит в вашей ленте активности.';

  @override
  String get adminBroadcastDefBodyPresence =>
      'Обнаружение присутствия улучшено для лучшего осознания mesh-сети.';

  @override
  String get adminBroadcastDefBodyCommunity =>
      'Присоединяйтесь к последним инициативам сообщества Socialmesh.';

  @override
  String get adminBroadcastDefBodyWorldMap =>
      'На карте глобальной mesh-сети появились новые функции для изучения покрытия.';

  @override
  String get adminBroadcastDefBodyThemes =>
      'В магазине Socialmesh теперь доступен новый набор тем.';

  @override
  String get adminBroadcastDefBodyRingtones =>
      'Новый набор рингтонов для ваших mesh-уведомлений теперь доступен.';

  @override
  String get adminBroadcastDefBodyWidgets =>
      'Новые виджеты для главного экрана теперь доступны в Socialmesh.';

  @override
  String get adminBroadcastDefBodyAutomations =>
      'Доступны новые триггеры и действия для автоматизаций.';

  @override
  String get adminBroadcastDefBodyIfttt =>
      'Подключите Socialmesh к любимым сервисам через IFTTT.';

  @override
  String get adminBroadcastDeepLinkCatCore => 'ОСНОВНОЕ';

  @override
  String get adminBroadcastDeepLinkCatSocial => 'СОЦИАЛЬНОЕ';

  @override
  String get adminBroadcastDeepLinkCatMesh => 'MESH';

  @override
  String get adminBroadcastDeepLinkCatPremium => 'ПРЕМИУМ';

  @override
  String get adminBroadcastLinkSettings => 'Настройки';

  @override
  String get adminBroadcastLinkAccount => 'Аккаунт и подписки';

  @override
  String get adminBroadcastLinkScanner => 'Сканер';

  @override
  String get adminBroadcastLinkMessages => 'Сообщения';

  @override
  String get adminBroadcastLinkChannels => 'Каналы';

  @override
  String get adminBroadcastLinkNodes => 'Ноды';

  @override
  String get adminBroadcastLinkMap => 'Карта';

  @override
  String get adminBroadcastLinkSignals => 'Signals';

  @override
  String get adminBroadcastLinkNodedex => 'NodeDex';

  @override
  String get adminBroadcastLinkAether => 'Aether';

  @override
  String get adminBroadcastLinkActivity => 'Активность';

  @override
  String get adminBroadcastLinkPresence => 'Presence';

  @override
  String get adminBroadcastLinkTimeline => 'Лента';

  @override
  String get adminBroadcastLinkWorldMap => 'Карта мира';

  @override
  String get adminBroadcastLinkGlobe => '3D-глобус';

  @override
  String get adminBroadcastLinkReachability => 'Доступность';

  @override
  String get adminBroadcastLinkThemes => 'Набор тем';

  @override
  String get adminBroadcastLinkRingtones => 'Набор рингтонов';

  @override
  String get adminBroadcastLinkWidgets => 'Виджеты';

  @override
  String get adminBroadcastLinkAutomations => 'Автоматизации';

  @override
  String get adminBroadcastLinkIfttt => 'Интеграция IFTTT';

  @override
  String get adminDiagTitle => 'Диагностика администратора';

  @override
  String get adminDiagTargetLocal => 'Локальное устройство';

  @override
  String adminDiagTargetRemote(String hexId) {
    return 'Удалённое: $hexId';
  }

  @override
  String get adminDiagDescription =>
      'Запускайте диагностические проверки подключённого устройства и экспортируйте подробный пакет данных для отладки проблем с протоколом и транспортом.';

  @override
  String get adminDiagTargetLabel => 'Цель';

  @override
  String get adminDiagMyNodeLabel => 'Моя нода';

  @override
  String get adminDiagStressToggle => 'Включить стресс-тесты';

  @override
  String get adminDiagStressToggleSub =>
      'Пакетное чтение и корреляция не по порядку';

  @override
  String get adminDiagWriteToggle => 'Включить тесты записи (обратимые)';

  @override
  String get adminDiagWriteToggleSub => 'Фиктивные записи с проверкой чтения';

  @override
  String get adminDiagRunButton => 'Запустить диагностику';

  @override
  String get adminDiagNoDevice => 'Устройство не подключено';

  @override
  String adminDiagProbeProgress(int completed, int total) {
    return '$completed / $total проверок';
  }

  @override
  String get adminDiagCancel => 'Отмена';

  @override
  String adminDiagResultSummary(int passed, int failed) {
    return '$passed пройдено, $failed не пройдено';
  }

  @override
  String get adminDiagExportBundle => 'Экспортировать пакет';

  @override
  String get adminDiagCopySummary => 'Скопировать сводку в буфер обмена';

  @override
  String get adminDiagRunAgain => 'Запустить снова';

  @override
  String get adminDiagWriteTestsDialogTitle => 'Включить тесты записи?';

  @override
  String get adminDiagWriteTestsDialogBody =>
      'Тесты записи выполняют фиктивные записи (то же значение) для проверки поведения при передаче. Они не изменяют состояние устройства, но отправляют команды SET на устройство.\n\nВы уверены, что хотите включить тесты записи?';

  @override
  String get adminDiagWriteTestsCancel => 'Отмена';

  @override
  String get adminDiagWriteTestsEnable => 'Включить';

  @override
  String adminDiagExportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get adminDiagCopiedToClipboard => 'Сводка скопирована в буфер обмена';

  @override
  String get adminPurchasesTitle => 'Покупки пользователей';

  @override
  String get adminPurchasesLabelTotal => ' ВСЕГО · ';

  @override
  String get adminPurchasesLabelPaying => ' ПЛАТЯЩИХ · ';

  @override
  String get adminPurchasesLabelFree => ' БЕСПЛАТНЫХ · ';

  @override
  String get adminPurchasesLabelRevenue => ' ВЫРУЧКА';

  @override
  String get adminPurchasesLabelExcluded => ' ИСКЛЮЧЕНО';

  @override
  String get adminPurchasesStatTotalUsers => 'Всего пользователей';

  @override
  String get adminPurchasesStatPaying => 'Платящие';

  @override
  String adminPurchasesStatExcludedCount(int count) {
    return 'Исключено: $count';
  }

  @override
  String get adminPurchasesStatFree => 'Бесплатные';

  @override
  String get adminPurchasesStatConversion => 'Конверсия';

  @override
  String get adminPurchasesStatArpu => 'ARPU';

  @override
  String get adminPurchasesStatArpuTooltip => 'Средняя выручка на пользователя';

  @override
  String get adminPurchasesStatGross => 'Валовая выручка';

  @override
  String get adminPurchasesStatExcluded => 'Исключено';

  @override
  String get adminPurchasesStatNet => 'Чистая выручка';

  @override
  String get adminPurchasesStatNewUsers24h => 'Новых пользователей (24ч)';

  @override
  String get adminPurchasesStatPurchases24h => 'Покупок (24ч)';

  @override
  String get adminPurchasesStatRevenue24h => 'Выручка (24ч)';

  @override
  String get adminPurchasesSearchHint => 'Поиск пользователей...';

  @override
  String get adminPurchasesFilterAll => 'Все';

  @override
  String get adminPurchasesFilterPaying => 'Платящие';

  @override
  String get adminPurchasesFilterFree => 'Бесплатные';

  @override
  String get adminPurchasesFilterExcluded => 'Исключённые';

  @override
  String get adminPurchasesFilterAnonymous => 'Анонимные';

  @override
  String get adminPurchasesFilterDeleted => 'Удалённые';

  @override
  String get adminPurchasesBannerTitle =>
      'Отображаются покупки, синхронизированные через вход в приложение или вебхуки RevenueCat.';

  @override
  String get adminPurchasesBannerSubtitle =>
      'Пользователи должны открыть приложение, будучи авторизованными, чтобы их покупки отобразились здесь.';

  @override
  String get adminPurchasesErrorLoading => 'Ошибка загрузки пользователей';

  @override
  String get adminPurchasesRetry => 'Повторить';

  @override
  String get adminPurchasesNoSearchResults => 'Пользователи не найдены';

  @override
  String get adminPurchasesNoUsers => 'Пользователи не найдены';

  @override
  String get adminPurchasesUnknownUser => 'Неизвестный пользователь';

  @override
  String get adminPurchasesAnonymousTag => 'Анонимный';

  @override
  String get adminPurchasesDeletedTag => 'Удалён';

  @override
  String get adminPurchasesAnonRcUser => 'Анонимный пользователь RevenueCat';

  @override
  String get adminPurchasesFallbackCloudSync => 'Облачная синхронизация';

  @override
  String get adminPurchasesSectionIds => 'Идентификаторы';

  @override
  String get adminPurchasesFirebaseUid => 'Firebase UID';

  @override
  String get adminPurchasesRevenueCatId => 'RevenueCat ID';

  @override
  String get adminPurchasesMemberSince => 'Участник с';

  @override
  String get adminPurchasesSectionPurchases => 'Покупки';

  @override
  String adminPurchasesItemCount(int count) {
    return '$count позиций';
  }

  @override
  String get adminPurchasesNoPurchases => 'Покупки отсутствуют';

  @override
  String get adminPurchasesCopied => 'Скопировано в буфер обмена';

  @override
  String get adminPurchasesCopyTooltip => 'Скопировать';

  @override
  String get adminQrStyleTitle => 'Стили QR-кодов';

  @override
  String get adminQrStyleHeading => 'Фирменные стили QR-кодов';

  @override
  String get adminQrStyleDescription =>
      'Предпросмотр различных стилей QR-кодов с логотипом Socialmesh. Все стили используют уровень коррекции ошибок H для надёжного сканирования.';

  @override
  String get adminQrStyleSmooth => 'Плавный';

  @override
  String get adminQrStyleSmoothDesc =>
      'Современные закруглённые жидкообразные модули. Премиальный вид.';

  @override
  String get adminQrStyleDots => 'Точки';

  @override
  String get adminQrStyleDotsDesc =>
      'Круглые модули-точки. Чистый и минималистичный вид.';

  @override
  String get adminQrStyleSquares => 'Квадраты';

  @override
  String get adminQrStyleSquaresDesc =>
      'Классический блочный стиль QR. Максимальная совместимость.';

  @override
  String get adminQrStyleElevatedHeader => 'РАСШИРЕННЫЕ СТИЛИ';

  @override
  String adminQrStyleElevatedSub(String styleName) {
    return 'Премиальные цветовые решения с использованием паттерна $styleName';
  }

  @override
  String get adminQrStyleNeonGlow => 'Неоновое свечение';

  @override
  String get adminQrStyleFrostedGlass => 'Матовое стекло';

  @override
  String get adminQrStyleInverted => 'Инвертированный';

  @override
  String get adminQrStyleHolographic => 'Голографический';

  @override
  String get adminQrStyleAccentBranded => 'Фирменный акцент';

  @override
  String get adminQrStyleMinimal => 'Минимальный';

  @override
  String get adminQrStyleCyberpunk => 'Киберпанк';

  @override
  String get adminQrStyleAccentGlow => 'Акцентное свечение';

  @override
  String get adminQrStyleOcean => 'Океан';

  @override
  String get adminQrStyleLuxury => 'Люкс';

  @override
  String adminQrStyleSelected(String styleName) {
    return 'Выбрано: $styleName';
  }

  @override
  String get adminQrStyleScanToVerify => 'Сканируйте для проверки';

  @override
  String get adminBugReportsTitle => 'Отчёты об ошибках';

  @override
  String get adminBugReportsSearchHint => 'Поиск отчётов';

  @override
  String get adminBugReportsLoadError => 'Не удалось загрузить отчёты';

  @override
  String get adminBugReportsMessageTooLong =>
      'Сообщение превышает 2 000 символов.';

  @override
  String get adminBugReportsReplySent => 'Ответ отправлен.';

  @override
  String adminBugReportsReplyFailed(String error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String get adminBugReportsResolved => 'Отчёт решён.';

  @override
  String get adminBugReportsReopened => 'Отчёт повторно открыт.';

  @override
  String adminBugReportsStatusFailed(String error) {
    return 'Не удалось обновить статус: $error';
  }

  @override
  String get adminBugReportsStatusOpen => 'ОТКРЫТ';

  @override
  String get adminBugReportsStatusUserReplied => 'ПОЛЬЗОВАТЕЛЬ ОТВЕТИЛ';

  @override
  String get adminBugReportsStatusResponded => 'ПОЛУЧЕН ОТВЕТ';

  @override
  String get adminBugReportsStatusResolved => 'РЕШЁН';

  @override
  String get adminBugReportsTimeJustNow => 'только что';

  @override
  String adminBugReportsTimeMinutes(int minutes) {
    return '$minutesмин. назад';
  }

  @override
  String adminBugReportsTimeHours(int hours) {
    return '$hoursч. назад';
  }

  @override
  String adminBugReportsTimeDays(int days) {
    return '$daysд. назад';
  }

  @override
  String get adminBugReportsSectionDesc => 'ОПИСАНИЕ';

  @override
  String get adminBugReportsSectionScreenshot => 'СНИМОК ЭКРАНА';

  @override
  String get adminBugReportsSectionDetails => 'ДЕТАЛИ';

  @override
  String get adminBugReportsDetailReportId => 'ID отчёта';

  @override
  String get adminBugReportsDetailUserId => 'ID пользователя';

  @override
  String get adminBugReportsAnonymousValue => 'анонимно';

  @override
  String get adminBugReportsDetailEmail => 'Электронная почта';

  @override
  String get adminBugReportsDetailDevice => 'Устройство';

  @override
  String get adminBugReportsDetailOs => 'Версия ОС';

  @override
  String get adminBugReportsDetailAppVer => 'Версия приложения';

  @override
  String get adminBugReportsSectionConversation => 'ПЕРЕПИСКА';

  @override
  String get adminBugReportsThreadYou => 'Вы';

  @override
  String get adminBugReportsThreadUser => 'Пользователь';

  @override
  String get adminBugReportsReplyHint => 'Напишите ответ...';

  @override
  String get adminBugReportsReopen => 'Открыть заново';

  @override
  String get adminBugReportsResolve => 'Решить';

  @override
  String adminBugReportsCountdownCancel(int seconds) {
    return 'Отмена · $seconds';
  }

  @override
  String get adminBugReportsSend => 'Отправить';

  @override
  String get adminBugReportsAnonNotice =>
      'Анонимный отчёт — ответы не могут быть доставлены.';

  @override
  String get adminBugReportsEmptyFilter =>
      'Нет отчётов, соответствующих вашему фильтру.';

  @override
  String get adminBugReportsEmptyAll => 'Отчётов об ошибках пока нет.';

  @override
  String get adminConformanceTitle => 'Стенд тестирования соответствия';

  @override
  String get adminConformanceDescription =>
      'Тестирование соответствия устройства через провайдер. Все мутации проходят через те же точки входа провайдера, что используются реальными экранами.';

  @override
  String get adminConformanceTargetDevice => 'Целевое устройство';

  @override
  String adminConformanceTargetRemote(String target) {
    return 'Удалённое: $target';
  }

  @override
  String get adminConformanceTargetLocal => 'Локальное устройство';

  @override
  String adminConformanceNodesAvailable(int count) {
    return 'Доступно $count удалённых нод';
  }

  @override
  String get adminConformanceOtaPki => 'Удалённое управление через PKI';

  @override
  String get adminConformanceNoNodes => 'Нет удалённых нод с поддержкой PKI';

  @override
  String get adminConformanceSwitchLocal => 'Переключиться на локальное';

  @override
  String get adminConformanceTestOptions => 'Параметры тестирования';

  @override
  String get adminConformanceDestructive => 'Деструктивные тесты';

  @override
  String get adminConformanceDestructiveSub =>
      'Случайные мутации, пакетная нагрузка, сброс базы нод. Может временно изменить конфигурацию устройства.';

  @override
  String get adminConformanceRunRemoteDestructive =>
      'Запустить удалённое тестирование (деструктивное)';

  @override
  String get adminConformanceRunRemoteSafe =>
      'Запустить удалённое тестирование (безопасное)';

  @override
  String get adminConformanceRunLocalDestructive =>
      'Запустить тестирование (деструктивное)';

  @override
  String get adminConformanceRunLocalSafe =>
      'Запустить тестирование (безопасное)';

  @override
  String adminConformanceProgress(
    int completed,
    int total,
    int pass,
    int fail,
  ) {
    return '$completed / $total  (пройдено: $pass, не пройдено: $fail)';
  }

  @override
  String get adminConformanceCancel => 'Отмена';

  @override
  String get adminConformanceAllPassed => 'Все тесты пройдены';

  @override
  String get adminConformanceSomeFailed => 'Некоторые тесты не пройдены';

  @override
  String get adminConformanceLabelPassed => 'Пройдено';

  @override
  String get adminConformanceLabelFailed => 'Не пройдено';

  @override
  String get adminConformanceLabelSkipped => 'Пропущено';

  @override
  String get adminConformanceLabelTimeouts => 'Таймауты';

  @override
  String get adminConformanceAnomalies => 'Аномалии:';

  @override
  String get adminConformanceTestResults => 'Результаты тестов';

  @override
  String get adminConformanceExportBundle => 'Экспортировать пакет';

  @override
  String get adminConformanceRunAgain => 'Запустить снова';

  @override
  String get adminConformanceInitializing => 'Инициализация';

  @override
  String get globalLayerDiagnosticsTitle => 'Диагностика';

  @override
  String get globalLayerCopyReportTooltip => 'Копировать отчёт';

  @override
  String get globalLayerCheckResultsHeader => 'Результаты проверки';

  @override
  String get globalLayerConnectionDiagnosticsTitle => 'Диагностика подключения';

  @override
  String get globalLayerConnectionDiagnosticsDescription =>
      'Выполнить серию проверок для верификации подключения к MQTT-серверу. Каждый шаг тестирует отдельный уровень стека подключения.';

  @override
  String globalLayerRunningChecksProgress(int passed, int total) {
    return 'Выполняются проверки... $passed/$total';
  }

  @override
  String get globalLayerRunAgain => 'Запустить снова';

  @override
  String get globalLayerStartDiagnostics => 'Начать диагностику';

  @override
  String get globalLayerSummaryHeader => 'Сводка';

  @override
  String globalLayerTotalTime(int milliseconds) {
    return 'Общее время: $millisecondsмс';
  }

  @override
  String get globalLayerAllClearTitle => 'Всё в порядке';

  @override
  String globalLayerAllChecksPassed(int count) {
    return 'Все $count проверки пройдены';
  }

  @override
  String get globalLayerWarningsFoundTitle => 'Обнаружены предупреждения';

  @override
  String get globalLayerWarningsFoundMessage =>
      'Все проверки пройдены, но есть предупреждения для просмотра';

  @override
  String get globalLayerIssuesFoundTitle => 'Обнаружены проблемы';

  @override
  String globalLayerChecksFailedCount(int failed, int total) {
    return '$failed из $total проверок не пройдено';
  }

  @override
  String get globalLayerDiagnosticsReportCopied =>
      'Отчёт диагностики скопирован в буфер обмена';

  @override
  String get globalLayerChecking => 'Проверка...';

  @override
  String globalLayerSkippedBecauseFailed(String checkName) {
    return 'Пропущено, так как $checkName не прошла.';
  }

  @override
  String globalLayerFixCheckFirst(String checkName) {
    return 'Сначала исправьте $checkName, затем повторно запустите диагностику.';
  }

  @override
  String get globalLayerNoHostnameConfigured => 'Адрес сервера не настроен.';

  @override
  String get globalLayerEnterBrokerHostname =>
      'Введите адрес сервера MQTT в мастере настройки.';

  @override
  String globalLayerHostnameResolved(String host) {
    return 'Адрес сервера «$host» успешно разрешен.';
  }

  @override
  String globalLayerTcpConnectionEstablished(String host, int port) {
    return 'TCP-соединение с $host:$port установлено.';
  }

  @override
  String get globalLayerTlsHandshakeCompleted =>
      'TLS handshake успешно завершен.';

  @override
  String globalLayerAuthenticatedAs(String username) {
    return 'Выполнен вход как «$username».';
  }

  @override
  String get globalLayerAnonymousConnection =>
      'Анонимное подключение принято сервером.';

  @override
  String globalLayerSubscribedToTopics(int count) {
    return 'Выполнена подписка на $count тем успешно.';
  }

  @override
  String get globalLayerSubscribeCapabilityVerified =>
      'Возможность подписки подтверждена (темы не включены).';

  @override
  String get globalLayerPublishTestPassed =>
      'Тестовое сообщение опубликовано и получено в режиме обратной петли.';

  @override
  String get globalLayerFailedToLoadConfig =>
      'Не удалось загрузить конфигурацию MQTT';

  @override
  String get globalLayerRetry => 'Повторить';

  @override
  String get globalLayerCopyDiagnosticsTooltip => 'Копировать диагностику';

  @override
  String get globalLayerTopicExplorerTitle => 'Обозреватель тем';

  @override
  String get globalLayerRunDiagnosticsMenuItem => 'Запустить диагностику';

  @override
  String get globalLayerReconfigureMenuItem => 'Перенастроить';

  @override
  String get globalLayerReset => 'Сбросить';

  @override
  String get globalLayerRecentActivityHeader => 'Последняя активность';

  @override
  String get globalLayerPausedSnackbar => 'Обмен по MQTT приостановлен';

  @override
  String get globalLayerResumedSnackbar => 'Обмен по MQTT возобновлён';

  @override
  String get globalLayerDiagnosticsCopiedSnackbar =>
      'Диагностика скопирована в буфер обмена';

  @override
  String get globalLayerResetTitle => 'Сбросить настройки MQTT';

  @override
  String get globalLayerResetMessage =>
      'Это очистит всю конфигурацию MQTT-сервера, учётные данные и историю подключений. Вам потребуется повторно запустить мастер настройки.';

  @override
  String get globalLayerQuickActionsHeader => 'Быстрые действия';

  @override
  String get globalLayerDisconnectAction => 'Отключиться';

  @override
  String get globalLayerConnectAction => 'Подключиться';

  @override
  String get globalLayerPauseAction => 'Приостановить';

  @override
  String get globalLayerResumeAction => 'Возобновить';

  @override
  String get globalLayerDiagnoseAction => 'Диагностировать';

  @override
  String get globalLayerTopicsAction => 'Темы';

  @override
  String get globalLayerBrokerHeader => 'MQTT-сервер';

  @override
  String get globalLayerHostLabel => 'Адрес';

  @override
  String get globalLayerPortLabel => 'Порт';

  @override
  String get globalLayerTlsLabel => 'TLS';

  @override
  String get globalLayerTlsEnabled => 'Включено';

  @override
  String get globalLayerTlsDisabled => 'Отключено';

  @override
  String get globalLayerUserLabel => 'Имя пользователя';

  @override
  String get globalLayerLastConnectedLabel => 'Последнее подключение';

  @override
  String get globalLayerTopicsLabel => 'Темы';

  @override
  String globalLayerActiveTopicsCount(int count) {
    return '$count активных';
  }

  @override
  String get globalLayerJustNow => 'Только что';

  @override
  String globalLayerMinutesAgo(int minutes) {
    return '$minutesм назад';
  }

  @override
  String globalLayerHoursAgo(int hours) {
    return '$hoursч назад';
  }

  @override
  String globalLayerDaysAgo(int days) {
    return '$daysд назад';
  }

  @override
  String globalLayerSecondsAgo(int seconds) {
    return '$secondsс назад';
  }

  @override
  String globalLayerDateFormat(int day, int month, int year) {
    return '$day.$month.$year';
  }

  @override
  String globalLayerShortDateFormat(int month, int day) {
    return '$day.$month';
  }

  @override
  String get globalLayerHealthHeader => 'Состояние';

  @override
  String get globalLayerHealthy => 'Исправен';

  @override
  String get globalLayerUnhealthy => 'Неисправен';

  @override
  String get globalLayerPingLabel => 'Пинг';

  @override
  String get globalLayerReconnectsLabel => 'Переподключения';

  @override
  String get globalLayerInboundLabel => 'Входящие';

  @override
  String get globalLayerOutboundLabel => 'Исходящие';

  @override
  String get globalLayerThroughputLabel => 'Пропускная способность';

  @override
  String get globalLayerSessionLabel => 'Сессия';

  @override
  String globalLayerActiveErrors(int count) {
    return '$count активных ошибок';
  }

  @override
  String get globalLayerPrivacyHeader => 'Конфиденциальность';

  @override
  String get globalLayerPrivacyAllOff => 'Всё выключено';

  @override
  String get globalLayerShareMessagesLabel => 'Поделиться сообщениями';

  @override
  String get globalLayerShareMessagesDescription =>
      'Пересылать локальные сообщения на сервер';

  @override
  String get globalLayerShareTelemetryLabel => 'Поделиться телеметрией';

  @override
  String get globalLayerShareTelemetryDescription =>
      'Публиковать данные о состоянии устройства';

  @override
  String get globalLayerAcceptInboundLabel => 'Получать данные';

  @override
  String get globalLayerAcceptInboundDescription =>
      'Получать сообщения и данные от сервера';

  @override
  String get globalLayerStatusOn => 'ВКЛ';

  @override
  String get globalLayerStatusOff => 'ВЫКЛ';

  @override
  String get globalLayerAddFromTemplate => 'Добавить из шаблона';

  @override
  String get globalLayerAddCustomTopic => 'Добавить пользовательскую тему';

  @override
  String get globalLayerSubscriptionsHeader => 'Подписки';

  @override
  String get globalLayerAddButton => 'Добавить';

  @override
  String get globalLayerRemoveTopicTitle => 'Удалить тему';

  @override
  String globalLayerRemoveTopicMessage(String label, String topic) {
    return 'Удалить «$label» ($topic) из ваших подписок? Вы сможете добавить её позже.';
  }

  @override
  String get globalLayerRemoveConfirm => 'Удалить';

  @override
  String globalLayerRemovedSnackbar(String label) {
    return 'Удалено «$label»';
  }

  @override
  String get globalLayerUndo => 'Отменить';

  @override
  String globalLayerFailedToLoadTopics(String error) {
    return 'Не удалось загрузить темы: $error';
  }

  @override
  String get globalLayerNoTopicSubscriptions => 'Нет подписок на темы';

  @override
  String get globalLayerEmptyTopicsDescription =>
      'Добавьте темы, чтобы управлять типами данных сети, проходящих через MQTT.';

  @override
  String get globalLayerFromTemplateButton => 'Из шаблона';

  @override
  String get globalLayerCustomButton => 'Пользовательская';

  @override
  String get globalLayerTopicPaused => 'Приостановлена';

  @override
  String get globalLayerTopicListening => 'Прослушивается';

  @override
  String get globalLayerTopicOffline => 'Не в сети';

  @override
  String get globalLayerStatsTopics => 'Темы';

  @override
  String get globalLayerStatsActive => 'Активные';

  @override
  String get globalLayerStatsMessages => 'Сообщения';

  @override
  String get globalLayerStatsRate => 'Скорость';

  @override
  String get globalLayerAddCustomTopicDescription =>
      'Подписаться на пользовательскую тему MQTT. Разрешены символы подстановки: + и #';

  @override
  String get globalLayerLabelFieldLabel => 'Метка';

  @override
  String get globalLayerLabelFieldHint => 'например, Отчёты о погоде';

  @override
  String get globalLayerMqttTopicFieldLabel => 'Тема MQTT';

  @override
  String get globalLayerMqttTopicFieldHint => 'например, msh/weather/+';

  @override
  String get globalLayerAddSubscriptionButton => 'Добавить подписку';

  @override
  String get globalLayerAddFromTemplateDescription =>
      'Выберите предопределённый шаблон темы. Заполнители будут заменены значениями, указанными ниже.';

  @override
  String get globalLayerChannelFieldLabel => 'Канал';

  @override
  String get globalLayerChannelFieldHint => 'LongFast';

  @override
  String get globalLayerNodeIdFieldLabel => 'ID ноды';

  @override
  String get globalLayerNodeIdFieldHint => '!a1b2c3d4';

  @override
  String get globalLayerTemplateAdded => 'Добавлено';

  @override
  String get adminFollowRequestFrom => 'ОТ';

  @override
  String get adminFollowRequestTo => 'КОМУ';

  @override
  String adminPostsFilteredCount(int count) {
    return 'Отфильтровано ($count)';
  }

  @override
  String get dashboardAddToFavorites => 'Добавить в избранное';

  @override
  String get dashboardAddWidget => 'Добавить виджет';

  @override
  String get dashboardAddWidgets => 'Добавить виджеты';

  @override
  String get dashboardChUtilLabel => 'Исп. кан.';

  @override
  String get dashboardDone => 'Готово';

  @override
  String get dashboardEditTitle => 'Редактировать панель';

  @override
  String get dashboardHealthConnection => 'Соединение';

  @override
  String get dashboardHealthNodes => 'Ноды';

  @override
  String get dashboardHealthOffline => 'Не в сети';

  @override
  String get dashboardHealthOnline => 'В сети';

  @override
  String get dashboardHealthSignal => 'Сигнал';

  @override
  String get dashboardHelp => 'Справка';

  @override
  String get dashboardLastHour => 'Последний час';

  @override
  String get dashboardLive => 'LIVE';

  @override
  String get dashboardNoChannelsConfigured => 'Каналы не настроены';

  @override
  String get dashboardNoMessagesYet => 'Сообщений пока нет';

  @override
  String get dashboardNoNearbyNodes => 'Ближайшие ноды не обнаружены';

  @override
  String get dashboardNoSignalData => 'Данные о сигнале недоступны';

  @override
  String get dashboardNodesLabel => 'Ноды';

  @override
  String get dashboardQuickMessage => 'Быстрое\nсообщение';

  @override
  String get dashboardRemoveConfirm => 'Удалить';

  @override
  String get dashboardRemoveFromFavorites => 'Удалить из избранного';

  @override
  String get dashboardRemoveWidget => 'Удалить виджет';

  @override
  String dashboardRemoveWidgetMessage(String displayName) {
    return 'Вы уверены, что хотите удалить «$displayName» с панели?';
  }

  @override
  String get dashboardRemoveWidgetTitle => 'Удалить виджет?';

  @override
  String get dashboardRssiLabel => 'RSSI';

  @override
  String get dashboardSettings => 'Настройки';

  @override
  String get dashboardShareLocation => 'Поделиться\nположением';

  @override
  String get dashboardSignalLabel => 'СИГНАЛ';

  @override
  String get dashboardSnrLabel => 'SNR';

  @override
  String get dashboardStatusLabel => 'Статус';

  @override
  String get dashboardStatusOffline => 'Не в сети';

  @override
  String get dashboardStatusOnline => 'В сети';

  @override
  String get dashboardTitle => 'Панель';

  @override
  String get dashboardTraceroute => 'Трассировка';

  @override
  String get dashboardWidgetActiveNodes => 'Активные ноды';

  @override
  String get dashboardWidgetActiveNodesDesc =>
      'Ноды, активные за последний час';

  @override
  String get dashboardWidgetAirtimeUsage => 'Использование эфирного времени';

  @override
  String get dashboardWidgetAirtimeUsageDesc =>
      'Время радиопередачи и ограничения';

  @override
  String get dashboardWidgetChannelActivity => 'Активность канала';

  @override
  String get dashboardWidgetChannelActivityDesc =>
      'Активность сообщений по каналам';

  @override
  String get dashboardWidgetGpsPosition => 'GPS-позиция';

  @override
  String get dashboardWidgetGpsPositionDesc =>
      'Текущее местоположение устройства';

  @override
  String get dashboardWidgetMeshHealth => 'Состояние сети';

  @override
  String get dashboardWidgetMeshHealthDesc =>
      'Общий показатель здоровья радиосети';

  @override
  String get dashboardWidgetMessages => 'Сообщения';

  @override
  String get dashboardWidgetMessagesDesc =>
      'Всего отправлено и получено сообщений';

  @override
  String get dashboardWidgetNetworkTopology => 'Топология сети';

  @override
  String get dashboardWidgetNetworkTopologyDesc => 'Визуальный граф радиосети';

  @override
  String get dashboardWidgetNodes => 'Ноды';

  @override
  String get dashboardWidgetNodesDesc => 'Всего обнаруженных нод в сети';

  @override
  String get dashboardWidgetPacketStats => 'Статистика пакетов';

  @override
  String get dashboardWidgetPacketStatsDesc =>
      'Количество отправленных, полученных и отброшенных пакетов';

  @override
  String get dashboardWidgetQuickActions => 'Быстрые действия';

  @override
  String get dashboardWidgetQuickActionsDesc =>
      'Быстрый доступ к основным функциям';

  @override
  String get dashboardWidgetRangeTest => 'Тест дальности';

  @override
  String get dashboardWidgetRangeTestDesc =>
      'Тест дальности сигнала с другими нодами';

  @override
  String get dashboardWidgetRecentMessages => 'Последние сообщения';

  @override
  String get dashboardWidgetRecentMessagesDesc => 'Свежие сообщения из сети';

  @override
  String get dashboardWidgetSignalStrength => 'Мощность сигнала';

  @override
  String get dashboardWidgetSignalStrengthDesc =>
      'График RSSI, SNR и загруженности канала в реальном времени';

  @override
  String get dashboardWidgetWeatherData => 'Погодные данные';

  @override
  String get dashboardWidgetWeatherDataDesc =>
      'Показания датчиков окружающей среды';

  @override
  String get discoveryFilterAllSources => 'Все источники';

  @override
  String get draggableTextHint => 'Введите текст...';

  @override
  String get globalLayerAdvanced => 'ДОПОЛНИТЕЛЬНО';

  @override
  String get globalLayerAuth => 'Аутентификация';

  @override
  String get globalLayerAuthentication => 'АУТЕНТИФИКАЦИЯ';

  @override
  String get globalLayerBack => 'Назад';

  @override
  String get globalLayerBrokerAddress => 'Адрес сервера';

  @override
  String get globalLayerClientId => 'ID клиента';

  @override
  String get globalLayerClientIdHint =>
      'Генерируется автоматически, если не указан';

  @override
  String get globalLayerConnection => 'ПОДКЛЮЧЕНИЕ';

  @override
  String get globalLayerContinue => 'Продолжить';

  @override
  String get globalLayerCustomiseConnection =>
      'Настроить параметры подключения';

  @override
  String get globalLayerDataTypes => 'ТИПЫ ДАННЫХ';

  @override
  String get globalLayerEnable => 'Включить MQTT';

  @override
  String get globalLayerMqttNote =>
      'Используется для обмена данными с сервером MQTT.';

  @override
  String get globalLayerNext => 'Далее';

  @override
  String get globalLayerOptional => 'Необязательно';

  @override
  String get globalLayerPassword => 'Пароль';

  @override
  String get globalLayerPort => 'Порт';

  @override
  String get globalLayerPreConfiguredAuth =>
      'Предварительно настроено (публичные учётные данные)';

  @override
  String get globalLayerServer => 'Сервер';

  @override
  String get globalLayerSetupTitle => 'Настройка MQTT';

  @override
  String globalLayerStepOf(String current, int total) {
    return 'Шаг $current из $total';
  }

  @override
  String get globalLayerTopicRoot => 'КОРНЕВАЯ ТЕМА';

  @override
  String get globalLayerTopicRootDescription =>
      'Префикс для всех тем. Измените его, если необходимо отделить трафик вашей сети.';

  @override
  String get globalLayerTopicRootLabel => 'Корневая тема';

  @override
  String get globalLayerUsername => 'Имя пользователя';

  @override
  String get globalLayerWhatItDoes => 'Что это делает';

  @override
  String get globalLayerWhatItDoesNot => 'Чего это НЕ делает';

  @override
  String helpCenterProgressLabel(int completed, int total) {
    return '$completed / $total';
  }

  @override
  String get mapControlsCenterOnMe => 'Центрировать на мне';

  @override
  String get mapControlsFitAll => 'Вписать всё';

  @override
  String get mapControlsResetNorth => 'Сброс севера';

  @override
  String get mapNodeDrawerClosePanel => 'Закрыть панель';

  @override
  String get nodeSelectorSearchHint => 'Поиск нод...';

  @override
  String get portalViewBroker => 'MQTT-сервер';

  @override
  String get portalViewLocalMesh => 'Локальная сеть';

  @override
  String get portalViewRemote => 'Удалённый';

  @override
  String get positionConfigAltitudeHint => 'например, 100';

  @override
  String get positionConfigLatitudeHint => 'например, 37.7749';

  @override
  String get positionConfigLongitudeHint => 'например, -122.4194';

  @override
  String get privacySettingsFirebaseTitle => 'Firebase (Google)';

  @override
  String get privacySettingsRevenueCatTitle => 'RevenueCat';

  @override
  String get privacySettingsSigilTitle => 'Sigil API (Socialmesh)';

  @override
  String get profileDeleteConfirmLabel => 'Удалить';

  @override
  String get scannerFilteringByUuid => 'Фильтрация по UUID Meshtastic';

  @override
  String get scannerScanningAllDevices =>
      'Сканирование всех устройств (режим разработчика)';

  @override
  String get scannerShowAllBleDevices => 'Показать все BLE устройства';

  @override
  String get settingsGlyphMatrixTestSubtitle =>
      'LED-паттерны для Nothing Phone 3';

  @override
  String get signalQualityExcellent => 'Отличный';

  @override
  String get signalQualityFair => 'Удовлетворительный';

  @override
  String get signalQualityGood => 'Хороший';

  @override
  String get signalQualityPoor => 'Слабый';

  @override
  String get signalQualityVeryGood => 'Очень хороший';

  @override
  String get signalQualityWeak => 'Очень слабый';

  @override
  String themeSettingsError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get widgetWizardAdd => 'Добавить';

  @override
  String get dashboardRequestPositions => 'Запросить\nположения';

  @override
  String adminPostsDeleteAllCount(int count) {
    return 'Удалить все ($count)';
  }

  @override
  String get globalLayerAllowInboundChat => 'Разрешить получение сообщений';

  @override
  String get globalLayerDiagBrokerEmpty => 'Адрес сервера не заполнен.';

  @override
  String globalLayerDiagUnexpectedError(String error) {
    return 'Неожиданная ошибка: $error';
  }

  @override
  String get globalLayerDiagUsernameNoPassword =>
      'Указано имя пользователя, но пароль не заполнен.';

  @override
  String get globalLayerShareMessages => 'Делиться сообщениями';

  @override
  String get globalLayerShareTelemetry => 'Делиться телеметрией';

  @override
  String get aetherInFlight => 'В полёте';

  @override
  String get aetherLiveFlightData => 'Данные рейса в реальном времени';

  @override
  String get aetherOnGround => 'На земле';

  @override
  String globalLayerNodesSeenVia(int count) {
    return '$count нод обнаружено через MQTT';
  }

  @override
  String get helpChannelCreationTitle => 'Создание канала';

  @override
  String get helpChannelCreationDescription =>
      'Узнайте, как создавать и настраивать mesh-каналы';

  @override
  String get helpEncryptionLevelsTitle => 'Шифрование канала';

  @override
  String get helpEncryptionLevelsDescription =>
      'Понимание параметров конфиденциальности и шифрования';

  @override
  String get helpMessageRoutingTitle => 'Как передаются сообщения';

  @override
  String get helpMessageRoutingDescription =>
      'Понимание маршрутизации в mesh-сети и ретрансляции сообщений';

  @override
  String get helpNodesOverviewTitle => 'Ваша mesh-сеть';

  @override
  String get helpNodesOverviewDescription =>
      'Знакомство с нодами вашей mesh-сети';

  @override
  String get helpNodeRolesTitle => 'Роли нод';

  @override
  String get helpNodeRolesDescription =>
      'Объяснение ролей CLIENT, ROUTER и REPEATER';

  @override
  String get helpRegionSelectionTitle => 'Выбор региона';

  @override
  String get helpRegionSelectionDescription =>
      'Частотные диапазоны и соответствие законодательству';

  @override
  String get helpDeviceConnectionTitle => 'Подключение устройства';

  @override
  String get helpDeviceConnectionDescription =>
      'BLE против USB и процесс сопряжения';

  @override
  String get helpGpsSettingsTitle => 'GPS и передача местоположения';

  @override
  String get helpGpsSettingsDescription =>
      'Обновления местоположения и конфиденциальность';

  @override
  String get helpSignalMetricsTitle => 'Понимание уровня сигнала';

  @override
  String get helpSignalMetricsDescription => 'SNR, RSSI и что они означают';

  @override
  String get helpMapOverviewTitle => 'Карта mesh-сети';

  @override
  String get helpMapOverviewDescription => 'Просматривайте mesh-сеть на карте';

  @override
  String get helpChannelsOverviewTitle => 'Ваши каналы';

  @override
  String get helpChannelsOverviewDescription =>
      'Управление каналами mesh-связи';

  @override
  String get helpAutomationsOverviewTitle => 'Автоматизации';

  @override
  String get helpAutomationsOverviewDescription =>
      'Автоматические действия для вашей mesh-сети';

  @override
  String get helpDashboardOverviewTitle => 'Ваша панель управления';

  @override
  String get helpDashboardOverviewDescription =>
      'Настраиваемый центр управления mesh-сетью';

  @override
  String get helpWidgetBuilderOverviewTitle => 'Конструктор виджетов';

  @override
  String get helpWidgetBuilderOverviewDescription =>
      'Создавайте собственные виджеты';

  @override
  String get helpMarketplaceOverviewTitle => 'Маркетплейс виджетов';

  @override
  String get helpMarketplaceOverviewDescription =>
      'Открывайте виджеты, созданные сообществом';

  @override
  String get helpSignalsOverviewTitle => 'Сигналы';

  @override
  String get helpSignalsOverviewDescription =>
      'Рассылайте кратковременные сигналы в вашу mesh-сеть';

  @override
  String get helpSignalCreationTitle => 'Создание сигнала';

  @override
  String get helpSignalCreationDescription =>
      'Как составить и разослать сигнал';

  @override
  String get helpSignalDetailTitle => 'Детали сигнала';

  @override
  String get helpSignalDetailDescription =>
      'Взаимодействие с сигналом и его ответами';

  @override
  String get helpWorldMeshOverviewTitle => 'Мировая сеть';

  @override
  String get helpWorldMeshOverviewDescription =>
      'Визуализация глобальной mesh-сети';

  @override
  String get helpRoutesOverviewTitle => 'Маршруты';

  @override
  String get helpRoutesOverviewDescription =>
      'Записывайте и делитесь GPS-маршрутами';

  @override
  String get helpPositionOverviewTitle => 'История позиций';

  @override
  String get helpPositionOverviewDescription =>
      'Журналы GPS-позиций всех нод вашей mesh-сети';

  @override
  String get helpSettingsOverviewTitle => 'Настройки';

  @override
  String get helpSettingsOverviewDescription =>
      'Настройка приложения и устройства';

  @override
  String get helpProfileOverviewTitle => 'Ваш профиль';

  @override
  String get helpProfileOverviewDescription =>
      'Управление вашей идентичностью в mesh-сети';

  @override
  String get helpMesh3dOverviewTitle => 'Mesh 3D';

  @override
  String get helpMesh3dOverviewDescription => '3D-визуализация топологии сети';

  @override
  String get helpGlobeOverviewTitle => 'Вид глобуса';

  @override
  String get helpGlobeOverviewDescription => '3D-глобус с вашей mesh-сетью';

  @override
  String get helpTimelineOverviewTitle => 'История';

  @override
  String get helpTimelineOverviewDescription =>
      'История активности в вашей mesh-сети';

  @override
  String get helpDeviceShopOverviewTitle => 'Магазин устройств';

  @override
  String get helpDeviceShopOverviewDescription =>
      'Обзор оборудования Meshtastic';

  @override
  String get helpOfflineMapsOverviewTitle => 'Офлайн-карты';

  @override
  String get helpOfflineMapsOverviewDescription =>
      'Параметры отображения и управления картой';

  @override
  String get helpRadioConfigOverviewTitle => 'Настройки радио';

  @override
  String get helpRadioConfigOverviewDescription =>
      'Настройка вашего LoRa радио';

  @override
  String get helpPresenceOverviewTitle => 'Присутствие ноды';

  @override
  String get helpPresenceOverviewDescription =>
      'Отслеживайте, какие ноды активны в вашей mesh-сети';

  @override
  String get helpReachabilityOverviewTitle => 'Достижимость mesh-сети';

  @override
  String get helpReachabilityOverviewDescription =>
      'Определение доступных для вас нод';

  @override
  String get helpMeshHealthOverviewTitle => 'Здоровье mesh-сети';

  @override
  String get helpMeshHealthOverviewDescription =>
      'Мониторинг состояния вашей mesh-сети';

  @override
  String get helpTracerouteOverviewTitle => 'Трассировка маршрута';

  @override
  String get helpTracerouteOverviewDescription =>
      'Определение пути прохождения пакетов через вашу mesh-сеть';

  @override
  String get helpNodedexOverviewTitle => 'Полевой журнал NodeDex';

  @override
  String get helpNodedexOverviewDescription =>
      'Ваша личная запись обо всех нодах, обнаруженных в mesh-сети';

  @override
  String get helpNodedexAlbumTitle => 'Альбом коллекционера';

  @override
  String get helpNodedexAlbumDescription =>
      'Представление обнаруженных нод в виде коллекционных карточек';

  @override
  String get helpNodedexConstellationTitle => 'Вид созвездия';

  @override
  String get helpNodedexConstellationDescription =>
      'Визуализация связей совместно обнаруженных нод в виде звёздной карты';

  @override
  String get helpNodedexDetailTitle => 'Профиль ноды';

  @override
  String get helpNodedexDetailDescription =>
      'Полная история и идентификация ноды';

  @override
  String get helpCloudSyncOverviewTitle => 'Облачная синхронизация';

  @override
  String get helpCloudSyncOverviewDescription =>
      'Премиум-синхронизация данных mesh-сети между устройствами';

  @override
  String get helpAetherOverviewTitle => 'Aether';

  @override
  String get helpAetherOverviewDescription =>
      'Отслеживание нод Meshtastic на высоте';

  @override
  String get helpTakGatewayOverviewTitle => 'TAK Шлюз';

  @override
  String get helpTakGatewayOverviewDescription =>
      'Интеграция вашей mesh-сети в экосистему TAK';

  @override
  String get helpRadioComplianceTitle =>
      'Правила использования радио и ваши обязанности';

  @override
  String get helpRadioComplianceDescription =>
      'Понимание ваших правовых обязательств при использовании радиоустройств';

  @override
  String get helpAcceptableUseTitle =>
      'Допустимое использование и запрещённые действия';

  @override
  String get helpAcceptableUseDescription =>
      'Что можно и нельзя делать в Socialmesh';

  @override
  String get helpUserResponsibilityTitle =>
      'Ваши данные — ваша ответственность';

  @override
  String get helpUserResponsibilityDescription =>
      'Как Socialmesh обрабатывает данные и за что вы несёте ответственность';

  @override
  String get helpFileTransferOverviewTitle => 'Передача файлов';

  @override
  String get helpFileTransferOverviewDescription =>
      'Отправка файлов по радиоканалу mesh-сети без интернета';

  @override
  String get helpFileTransferLimitsTitle => 'Почему только 8 КБ?';

  @override
  String get helpFileTransferLimitsDescription =>
      'Объяснение бюджета эфирного времени и рабочего цикла LoRa';

  @override
  String get helpChannelIntroBubble =>
      'Давайте создадим **канал**! Это как рация. Только ваши друзья, знающие секрет, смогут слушать.';

  @override
  String get helpChannelNameBubble =>
      'Сначала выберите **название** для вашего канала. Что-то лёгкое для запоминания, например «Семья» или «Друзья-туристы».';

  @override
  String get helpPrivacyLevelBubble =>
      'Насколько секретным должен быть ваш канал?\\n\\n**ОТКРЫТЫЙ**: Любой может слушать.\\n**ОБЩИЙ**: Как пароль, который знают все.\\n**ПРИВАТНЫЙ**: Только приглашённые вами друзья.\\n**МАКСИМАЛЬНЫЙ**: Сверхсекретный!';

  @override
  String get helpEncryptionKeyBubble =>
      'Я создал для вас **секретный ключ**! Он зашифровывает ваши сообщения, чтобы их могли читать только ваши друзья. Как секретный код!';

  @override
  String get helpChannelCompleteBubble =>
      'Всё готово! Покажите друзьям **QR-код**, и они смогут присоединиться к вашему каналу. Проще простого!';

  @override
  String get helpEncryptionIntroBubble =>
      'Позвольте объяснить **уровни шифрования**. Это как выбор степени секретности ваших сообщений!';

  @override
  String get helpDefaultKeyBubble =>
      '**КЛЮЧ ПО УМОЛЧАНИЮ** означает, что все участники mesh-сети могут читать ваши сообщения. Это публично! Используйте для общих объявлений или тестирования.';

  @override
  String get helpPskEncryptionBubble =>
      '**PSK** (Pre-Shared Key) означает, что вы создаёте случайный секретный ключ. Только люди с этим точным ключом смогут расшифровать ваши сообщения. Намного приватнее!';

  @override
  String get helpPskSharingBubble =>
      'Поделитесь своим PSK через **QR-код**! При сканировании собеседник получит ключ и настройки канала. Проще простого!';

  @override
  String get helpRoutingIntroBubble =>
      'Хотите увидеть, как это работает? Когда вы отправляете сообщение, оно **передаётся от ноды к ноде**, как горячая картошка!';

  @override
  String get helpRoutingHopsBubble =>
      'Каждый **прыжок** — это когда нода получает ваше сообщение и пересылает его дальше. Большинству сообщений нужно **1–3 прыжка**, чтобы достичь получателя!';

  @override
  String get helpRoutingRouterRoleBubble =>
      'Ноды **ROUTER** — супергерои mesh-сети: они ретранслируют сообщения для всех! Ноды **CLIENT** лишь отправляют и получают собственные сообщения.';

  @override
  String get helpRoutingStoreForwardBubble =>
      '**Store & Forward** — отличная функция! Если от получателя давно не было сигнала, сообщение будет сохранено и доставлено при следующем появлении пакета.';

  @override
  String get helpNodesIntroBubble =>
      'Это ваша **mesh-сеть**! Каждое устройство, которое вы видите здесь, — нода, способный общаться с вами.';

  @override
  String get helpNodesStatusBubble =>
      '**Зелёная точка** означает **Активен** (слышен совсем недавно). **Жёлтая** — **Виден недавно**. **Серая** — **Неактивен**. LoRa не имеет сигнала об отключении — статус определяется косвенно.';

  @override
  String get helpNodesInfoBubble =>
      'На каждой карточке отображается **имя** ноды, **уровень заряда** и **уровень сигнала**. Нажмите на любую ноду, чтобы узнать подробнее!';

  @override
  String get helpNodesFiltersBubble =>
      'Используйте **фильтры** вверху для поиска конкретных нод. Можно отображать только **Активные** ноды, избранные или ноды с GPS.';

  @override
  String get helpNodesActionsBubble =>
      'Нажмите на ноду, чтобы **отправить сообщение**, увидеть **местоположение на карте** или проверить **данные телеметрии**!';

  @override
  String get helpRolesIntroBubble =>
      '**Роли нод** определяют, как ваше устройство помогает mesh-сети. Давайте разберём каждую!';

  @override
  String get helpRoleClientBubble =>
      '**CLIENT**: Ваше устройство отправляет и получает сообщения, но не ретранслирует их для других. Отличный выбор для **экономии батареи**!';

  @override
  String get helpRoleRouterBubble =>
      '**ROUTER**: Вы супергерой mesh-сети! Вы ретранслируете сообщения для всех. Расходует больше батареи, но делает сеть сильнее!';

  @override
  String get helpRoleRouterLateBubble =>
      '**ROUTER LATE**: Повторно транслирует после других роутеров. Расширяет покрытие, не занимая приоритетные прыжки. Отлично для резервных ретрансляторов!';

  @override
  String get helpRoleClientBaseBubble =>
      '**CLIENT BASE**: Базовая станция для ваших избранных нод. Маршрутизирует их пакеты как роутер, а всё остальное обрабатывает как клиент!';

  @override
  String get helpRegionIntroBubble =>
      'Это важно! Ваш **регион** определяет, какие радиочастоты вы можете использовать по закону.';

  @override
  String get helpRegionLegalBubble =>
      'В каждой стране свои правила. Использование **неверной частоты** может быть незаконным! Всегда выбирайте регион по своему фактическому местоположению.';

  @override
  String get helpRegionBandsBubble =>
      'Большинство регионов используют **915 МГц** (Америка) или **868 МГц** (Европа). Некоторые — **433 МГц**. Оборудование вашего устройства должно поддерживать эту частоту!';

  @override
  String get helpRegionWarningBubble =>
      'Неверный регион = **невозможность общаться** с другими! Убедитесь, что все участники вашей mesh-сети используют одинаковую настройку региона.';

  @override
  String get helpConnectionIntroBubble =>
      'Давайте подключим ваше устройство Meshtastic! Есть два способа: **Bluetooth** или **USB**.';

  @override
  String get helpConnectionBleBubble =>
      '**BLUETOOTH** (BLE): Беспроводное подключение! Ваше устройство отображается как **Meshtastic_XXXX**. Просто нажмите для подключения. Работает, пока устройство в кармане!';

  @override
  String get helpConnectionUsbBubble =>
      '**USB**: Подключение кабелем. Надёжнее, заряжает устройство, немного быстрее. Отлично подходит для настройки!';

  @override
  String get helpConnectionPairingBubble =>
      'Первый раз? Устройство должно находиться в **режиме сопряжения**. Найдите значок Bluetooth на экране или нажмите кнопку!';

  @override
  String get helpConnectionTroubleshootBubble =>
      'Не можете найти устройство? Проверьте:\\n- **Bluetooth включён**\\n- Устройство заряжено\\n- Устройство не подключено к другому источнику\\n- Вы находитесь достаточно близко (до 10 м)';

  @override
  String get helpGpsIntroBubble =>
      '**GPS** позволяет другим видеть вас на карте! Давайте объясним, как это работает.';

  @override
  String get helpGpsBroadcastBubble =>
      'Ваше устройство отправляет **обновления позиции** каждые несколько минут. Другие ноды видят вас на своей карте!';

  @override
  String get helpGpsPrivacyBubble =>
      'Конфиденциальность важна! Вы можете **отключить GPS** или задать интервалы обновлений. Отключите его, когда хотите оставаться невидимым!';

  @override
  String get helpGpsBatteryBubble =>
      'GPS расходует **батарею**! Большие интервалы обновлений = лучший заряд батареи. Балансируйте между конфиденциальностью и удобством!';

  @override
  String get helpMetricsIntroBubble =>
      'Давайте разберём цифры сигнала! Они показывают, насколько хорошо работает ваше соединение.';

  @override
  String get helpMetricsRssiBubble =>
      '**RSSI** (мощность принятого сигнала): насколько громкий сигнал. Чем выше, тем лучше! **−50 дБм** = отлично, **−120 дБм** = еле держится.';

  @override
  String get helpMetricsSnrBubble =>
      '**SNR** (отношение сигнал/шум): насколько чистый сигнал. Положительное = хорошо, отрицательное = шумно! **+10 дБ** = отлично, **−10 дБ** = плохо.';

  @override
  String get helpMetricsPracticalBubble =>
      'На практике: **Зелёный** = отлично, **жёлтый** = нормально, **красный** = плохо. Подойдите ближе или найдите возвышенность для улучшения!';

  @override
  String get helpMapIntroBubble =>
      'Добро пожаловать на **карту mesh-сети**! Каждая точка — это нода с GPS. Все они часть вашей сети!';

  @override
  String get helpMapMarkersBubble =>
      '**Нажмите на любой маркер**, чтобы узнать, кто это. Вы можете отправить сообщение, проверить батарею или посмотреть, когда нода была видена последний раз!';

  @override
  String get helpMapFeaturesBubble =>
      'Попробуйте **тепловую карту**, чтобы увидеть, где концентрируются ноды, или **линии связи**, чтобы увидеть, кто с кем общается!';

  @override
  String get helpMapMeasureBubble =>
      'Используйте **режим измерения** для проверки расстояний между точками. Отлично подходит для планирования размещения новой ноды!';

  @override
  String get helpMapFiltersBubble =>
      'Используйте **фильтры**, чтобы показывать только **Активные** ноды или ноды с GPS. Помогает, когда на карте много объектов!';

  @override
  String get helpChannelsIntroBubble =>
      'Это ваши **каналы**! Представьте их как разные радиочастоты. Каждый — отдельный разговор.';

  @override
  String get helpChannelsPrimaryBubble =>
      '**Основной** канал особенный. Он всегда занимает слот 0 и не может быть удалён. Большая часть трафика mesh-сети идёт через него!';

  @override
  String get helpChannelsSecondaryBubble =>
      '**Дополнительные каналы** предназначены для приватных групп. Создайте один для семьи, туристического клуба или аварийной команды!';

  @override
  String get helpChannelsEncryptionBubble =>
      'Видите **значок замка**? Это означает, что канал зашифрован. Только люди с ключом могут читать сообщения!';

  @override
  String get helpChannelsShareBubble =>
      'Нажмите на канал, чтобы увидеть его **QR-код**. Друзья могут отсканировать его для мгновенного подключения с правильными настройками!';

  @override
  String get helpAutomationsIntroBubble =>
      '**Автоматизации** делают вашу mesh-сеть умнее! Настройте правила, и нужные действия будут выполняться автоматически.';

  @override
  String get helpAutomationsTriggersBubble =>
      'Каждая автоматизация начинается с **триггера**. Например, когда нода становится неактивным, батарея разряжается или вы входите в зону!';

  @override
  String get helpAutomationsActionsBubble =>
      'Затем выберите **действие**! Отправить сообщение, воспроизвести звук, показать уведомление или даже активировать IFTTT!';

  @override
  String get helpAutomationsExamplesBubble =>
      'Пример: **Уведомить меня, когда заряд батареи папы упадёт ниже 20%**. Или **Отправить «Я дома!», когда я войду в геозону**!';

  @override
  String get helpAutomationsToggleBubble =>
      'Используйте **переключатель**, чтобы включать или отключать автоматизации. Протестируйте их перед использованием!';

  @override
  String get helpDashboardIntroBubble =>
      'Добро пожаловать на **Панель управления**! Это ваш персональный командный центр. Всё необходимое — с первого взгляда!';

  @override
  String get helpDashboardWidgetsBubble =>
      'Каждая карточка — это **виджет**. Они отображают актуальные данные вашей сети — уровень заряда, сообщения, погоду и многое другое!';

  @override
  String get helpDashboardReorderBubble =>
      '**Удерживайте и перетаскивайте** виджеты, чтобы переупорядочить их. Поместите избранные наверх! Нажмите **Изменить**, чтобы добавить или удалить их.';

  @override
  String get helpDashboardTapBubble =>
      '**Нажмите на любой виджет**, чтобы увидеть подробности или выполнить действие. Попробуйте нажать на виджет ноды, чтобы увидеть всю его информацию!';

  @override
  String get helpBuilderIntroBubble =>
      'Добро пожаловать в **Конструктор виджетов**! Здесь вы можете создавать собственные виджеты с нуля!';

  @override
  String get helpBuilderTemplatesBubble =>
      'Начните с **шаблона** или создайте с нуля. Шаблоны предоставляют готовые датчики, графики и карточки статуса для настройки!';

  @override
  String get helpBuilderBindingsBubble =>
      'Вся магия — в **привязках данных**! Подключите любой элемент к актуальным данным сети — заряду, GPS, температуре, уровню сигнала!';

  @override
  String get helpBuilderPreviewBubble =>
      'Используйте **Предпросмотр**, чтобы увидеть, как ваш виджет выглядит с реальными данными, прежде чем сохранить. Настраивайте до совершенства!';

  @override
  String get helpMarketplaceIntroBubble =>
      'Добро пожаловать на **Маркетплейс**! Просматривайте виджеты, созданные другими энтузиастами mesh-сетей по всему миру!';

  @override
  String get helpMarketplaceBrowseBubble =>
      'Просматривайте по **категориям** — находите дисплеи статуса, графики, датчики или оригинальные дизайны. Нажмите на любой виджет для предпросмотра!';

  @override
  String get helpMarketplaceInstallBubble =>
      'Нашли то, что нравится? **Нажмите «Установить»** — и виджет добавится в вашу коллекцию. Используйте его на панели управления прямо сейчас!';

  @override
  String get helpMarketplaceShareBubble =>
      'Создали что-то классное? **Поделитесь своими виджетами** на маркетплейсе и помогите сообществу!';

  @override
  String get helpSignalsIntroBubble =>
      'Добро пожаловать в **Сигналы**! Транслируйте моменты в вашу mesh-сеть. Сигналы **эфемерны** — они существуют только ограниченное время!';

  @override
  String get helpSignalsCreateBubble =>
      'Нажмите на **значок датчика**, чтобы стать активным! Добавьте текст, фото или своё местоположение. Выберите, как долго сигнал будет жить!';

  @override
  String get helpSignalsProximityBubble =>
      'Сигналы показывают **метки близости** — сколько прыжков до отправителя. **Рядом** означает прямую видимость!';

  @override
  String get helpSignalsFiltersBubble =>
      'Используйте **фильтры**, чтобы сосредоточиться на важном: ближайшие сигналы, только mesh или по типу контента.';

  @override
  String get helpSignalsPrivacyBubble =>
      'Сигналы ориентированы **на mesh** — они передаются через радиосеть. Когда они попадают в интернет, это опционально и контролируется вами.';

  @override
  String get helpCreateIntroBubble =>
      'Пора **стать активным**! Сигнал — это эфемерная трансляция, которая живёт в mesh-сети заданное время. Расскажите всем, что происходит!';

  @override
  String get helpCreateTextBubble =>
      'Введите сообщение в главное поле — до **280 символов**. Круговой счётчик показывает оставшееся место.';

  @override
  String get helpCreateImageBubble =>
      'Нажмите на **значок изображения**, чтобы прикрепить фото. Изображения загружаются через облако, когда есть интернет — по mesh передаётся только ссылка.';

  @override
  String get helpCreateLocationBubble =>
      'Нажмите на **метку местоположения**, чтобы прикрепить текущую GPS-позицию устройства. Ваше местоположение видно всем, кто получит сигнал.';

  @override
  String get helpCreateTtlBubble =>
      '**Значок таймера** задаёт TTL — как долго сигнал остаётся активным. Выбирайте от нескольких минут до нескольких часов.';

  @override
  String get helpCreateIntentBubble =>
      'Выберите **Намерение присутствия**, чтобы сообщить сети, чем вы занимаетесь — исследуете, наблюдаете, помогаете или просто слушаете. Это добавляет контекст без лишних слов.';

  @override
  String get helpCreateStatusBubble =>
      'Поле **краткого статуса** — это одна строка, которая отображается как подпись к вашему сигналу в ленте.';

  @override
  String get helpCreateSubmitBubble =>
      'Когда будете готовы, нажмите **Транслировать**! Ваш сигнал распространится по mesh-сети через радио. Он доступен всем в пределах досягаемости!';

  @override
  String get helpDetailIntroBubble =>
      'Это экран **подробностей сигнала**. Здесь можно прочитать полный текст, увидеть, откуда он пришёл, и ответить!';

  @override
  String get helpDetailTtlBubble =>
      '**Шкала TTL** показывает, сколько времени сигнал ещё будет жить. Когда она обнулится — сигнал исчезнет из сети.';

  @override
  String get helpDetailResponsesBubble =>
      'Ответы **вложены в цепочки**. Вы можете ответить напрямую на сигнал или на ответ другого пользователя.';

  @override
  String get helpDetailVotingBubble =>
      'Нажмите на **стрелку вверх или вниз** у любого ответа, чтобы проголосовать. Голоса выводят наверх самые полезные ответы.';

  @override
  String get helpDetailReplyBubble =>
      'Используйте **панель ответа** внизу для ответа. Нажмите на значок ответа у любого сообщения, чтобы ответить именно на него.';

  @override
  String get helpDetailActionsBubble =>
      '**Меню действий** (три точки) позволяет **удалить** свой сигнал или **пожаловаться** на чужой. Используйте с умом!';

  @override
  String get helpWorldIntroBubble =>
      'Добро пожаловать в **Мировую сеть**! Смотрите всю глобальную сеть Meshtastic. Каждая точка — это нода где-то в мире!';

  @override
  String get helpWorldScopeBubble =>
      'Отдалитесь, чтобы увидеть **мировую сеть**, или приблизьтесь, чтобы исследовать локальные кластеры. Это поистине глобальное сообщество!';

  @override
  String get helpWorldDataBubble =>
      'Данные поступают через **MQTT** — от нод, которые решили публично делиться своим местоположением. Вы тоже можете участвовать!';

  @override
  String get helpWorldFiltersBubble =>
      'Используйте **фильтры** для отображения конкретных регионов или временных промежутков. Находите активные mesh-сети рядом с вами!';

  @override
  String get helpRoutesIntroBubble =>
      '**Маршруты** позволяют записывать ваши путешествия! Идеально для походов, велопрогулок или любых вылазок на природу!';

  @override
  String get helpRoutesRecordBubble =>
      'Нажмите **Запись**, чтобы начать отслеживание. GPS-точки сохраняются по мере движения. Работает даже в офлайн-режиме!';

  @override
  String get helpRoutesGpxBubble =>
      '**Импортируйте GPX-файлы**, чтобы следовать по готовым маршрутам. Экспортируйте свои маршруты и делитесь ими с другими!';

  @override
  String get helpRoutesShareBubble =>
      'Делитесь маршрутами с участниками вашей сети! Отлично подходит для координации точек встречи или обмена любимыми тропами.';

  @override
  String get helpPositionIntroBubble =>
      '**История позиций** записывает каждую GPS-позицию, переданную нодами вашей сети.';

  @override
  String get helpPositionListMapBubble =>
      'Переключайтесь между **списком** и **картой** через меню. Карта показывает, где побывали все ноды с течением времени!';

  @override
  String get helpPositionFiltersBubble =>
      'Используйте **чипы фильтров** для сужения результатов: сегодня, на этой неделе, хорошее GPS-соединение или только конкретная нода.';

  @override
  String get helpPositionSearchBubble =>
      '**Строка поиска** фильтрует по имени ноды. Удобно, когда в вашей сети десятки нод!';

  @override
  String get helpPositionMapNodesBubble =>
      'В режиме карты нажмите кнопку **список нод**, чтобы выбрать конкретную ноду. Каждую ноду получает свой цвет для удобства!';

  @override
  String get helpPositionExportBubble =>
      '**Экспортируйте в CSV** через меню для анализа в таблицах или GIS-инструментах. Отличный способ документировать покрытие!';

  @override
  String get helpPositionGoodFixBubble =>
      'Фильтр **Хорошее соединение** показывает только позиции с 6+ спутниками. Это помогает отсеять неточные данные!';

  @override
  String get helpSettingsIntroBubble =>
      'Добро пожаловать в **Настройки**! Здесь вы можете настроить всё — от внешнего вида приложения до параметров радио!';

  @override
  String get helpSettingsDeviceBubble =>
      '**Настройки устройства** позволяют настроить ваше Meshtastic-радио — имя, регион, мощность и многое другое.';

  @override
  String get helpSettingsAppBubble =>
      '**Настройки приложения** управляют темами, уведомлениями, параметрами конфиденциальности и поведением приложения.';

  @override
  String get helpSettingsCloudBubble =>
      '**Облачная синхронизация** — это премиум-подписка, которая синхронизирует ваш **NodeDex**, **автоматизации** и **профиль** между устройствами.';

  @override
  String get helpProfileIntroBubble =>
      'Это **ваш профиль**! Настройте свою идентичность в mesh-сети: отображаемое имя, позывной и аватар.';

  @override
  String get helpProfileCustomizeBubble =>
      'Ваш профиль **необязателен и по умолчанию приватен**. Настройте его, чтобы выделиться в mesh-сообществе!';

  @override
  String get helpProfileShareBubble =>
      'Добавьте **позывной**, **аватар** и **ссылки**, чтобы сделать профиль по-настоящему своим.';

  @override
  String get helpProfileCloudBubble =>
      '**Облачная синхронизация** — это премиум-функция, которая создаёт резервные копии вашего профиля, NodeDex, автоматизаций и настроек на всех устройствах.';

  @override
  String get helpMesh3dIntroBubble =>
      'Добро пожаловать в **Mesh 3D**! Смотрите всю сеть в трёх измерениях. Вращайте, масштабируйте и исследуйте топологию!';

  @override
  String get helpMesh3dNodesBubble =>
      'Каждая сфера — это **нода**. Линии показывают соединения на основе мощности сигнала. Более толстые линии — более надёжное соединение!';

  @override
  String get helpMesh3dColorsBubble =>
      'Цвета отражают **состояние ноды**. Зелёный — активный, жёлтый — затухающий, серый — неактивный. Смотрите, как ваша сеть меняется со временем!';

  @override
  String get helpMesh3dTapBubble =>
      '**Нажмите на любую ноду**, чтобы выбрать его и увидеть подробности. Отлично помогает понять структуру сети!';

  @override
  String get helpGlobeIntroBubble =>
      'Вращайте **Глобус**, чтобы смотреть на вашу сеть из космоса! Каждая светящаяся точка — это ноду с известным местоположением!';

  @override
  String get helpGlobeInteractBubble =>
      '**Перетаскивайте для вращения**, сводите/разводите пальцы для масштабирования. Нажмите на ноду, чтобы подлететь к его местоположению и увидеть подробности!';

  @override
  String get helpGlobeArcsBubble =>
      'Наблюдайте за **дугами соединений** — они показывают пути сообщений, проходящих по вашей сети!';

  @override
  String get helpTimelineIntroBubble =>
      '**Лента событий** показывает всё, что происходит в вашей сети. Сообщения, изменения нод, сигналы — всё в хронологическом порядке!';

  @override
  String get helpTimelineFilterBubble =>
      'Используйте **фильтры** для просмотра конкретных типов событий. Только сообщения? Только входы нод? Настраивайте под себя!';

  @override
  String get helpTimelineTapBubble =>
      '**Нажмите на любое событие**, чтобы увидеть полные подробности. Отлично подходит для отладки или понимания происходящего в сети!';

  @override
  String get helpShopIntroBubble =>
      'Добро пожаловать в **Магазин устройств**! Просматривайте радиоустройства и аксессуары, совместимые с Meshtastic!';

  @override
  String get helpShopCompareBubble =>
      '**Сравнивайте устройства** по дальности, заряду батареи и функциям. Каждое оценено, чтобы помочь вам выбрать подходящее!';

  @override
  String get helpShopLinksBubble =>
      'Нажмите **Купить**, чтобы перейти к проверенным продавцам. Показанные цены и наличие взяты из реальных магазинов.';

  @override
  String get helpOfflineIntroBubble =>
      '**Офлайн-карты** позволяют пользоваться картой без интернета! Необходимы для вылазок туда, где нет связи!';

  @override
  String get helpOfflineDownloadBubble =>
      '**Выберите регион** и уровень масштаба, затем нажмите «Скачать». Все тайлы карты сохранятся на вашем устройстве!';

  @override
  String get helpOfflineManageBubble =>
      'Управляйте загрузками здесь — смотрите использованное место и **удаляйте** старые регионы, которые вам больше не нужны.';

  @override
  String get helpRadioIntroBubble =>
      '**Настройки радио** управляют передачей вашего устройства. Регион, мощность и пресет модема влияют на дальность и расход батареи!';

  @override
  String get helpRadioRegionBubble =>
      '**Регион** определяет разрешённые частоты. Неверная настройка может создать помехи другим пользователям и нарушить закон!';

  @override
  String get helpRadioModemBubble =>
      '**Пресет модема** балансирует между дальностью и скоростью. Дальний диапазон = медленнее, но дальше. Короткий диапазон = быстрее, но ближе!';

  @override
  String get helpRadioPowerBubble =>
      'Большая **мощность передатчика** означает большую дальность, но быстрее расходует батарею. Найдите оптимальный баланс для вашей ситуации!';

  @override
  String get helpPresenceIntroBubble =>
      '**Присутствие** показывает, какие ноды активны, недавно видны или неактивны в вашей сети!';

  @override
  String get helpPresenceActiveBubble =>
      '**Активные** ноды (зелёные) отправили сообщение за последние 2 минуты. Они точно доступны!';

  @override
  String get helpPresenceRecentBubble =>
      '**Недавно видимые** ноды (жёлтые) были активны 2–10 минут назад. Скорее всего, ещё в зоне досягаемости!';

  @override
  String get helpPresenceInactiveBubble =>
      '**Неактивные** ноды (серые) не выходили на связь более 10 минут. Возможно, они выключены, вышли из зоны или разрядились!';

  @override
  String get helpPresenceChartBubble =>
      '**График активности** показывает недавнюю активность нод по времени. Наблюдайте, как ваша сеть оживает в течение дня!';

  @override
  String get helpReachabilityIntroBubble =>
      '**Достижимость** оценивает вероятность связи с каждой нодой на основе истории наблюдений сигнала!';

  @override
  String get helpReachabilityBetaBubble =>
      'Это **БЕТА-версия** — тестовые пакеты не отправляются! Всё вычисляется на основе истории наблюдений сигнала.';

  @override
  String get helpReachabilityHighBubble =>
      '**Высокая** достижимость (яркая) означает, что мы наблюдали много коммуникации с этой нодой. Скорее всего, он доступен!';

  @override
  String get helpReachabilityMediumBubble =>
      '**Средняя** достижимость (менее яркая) означает частичную связь. Возможно, он в зоне досягаемости, но нестабильно!';

  @override
  String get helpReachabilityLowBubble =>
      '**Низкая** достижимость (очень тусклая) означает редкую связь. Нода может быть на краю зоны или временно недоступна!';

  @override
  String get helpHealthIntroBubble =>
      '**Состояние сети** отслеживает проблемы: перегрузка, потеря пакетов и нестабильные ноды могут влиять на вашу сеть!';

  @override
  String get helpHealthStatusBubble =>
      '**Индикатор состояния** показывает общее состояние сети. Зелёный — всё хорошо, жёлтый — есть проблемы, красный — критично!';

  @override
  String get helpHealthMetricsBubble =>
      '**Метрики** показывают количество пакетов, повторные передачи и количество прыжков. Следите за высокими значениями повторных передач!';

  @override
  String get helpHealthUtilizationBubble =>
      '**График использования** показывает загрузку вашей сети по времени. Пики могут указывать на перегрузку или помехи!';

  @override
  String get helpHealthIssuesBubble =>
      'Раздел **Проблемы** выделяет конкретные неполадки и предлагает решения. Проверьте здесь, если что-то идёт не так!';

  @override
  String get helpHealthMonitoringBubble =>
      'Используйте кнопку **паузы**, чтобы остановить мониторинг и сэкономить батарею. Нажмите **возобновить**, когда будете готовы проверить снова!';

  @override
  String get helpTracerouteIntroBubble =>
      '**Трассировка маршрута** определяет фактический путь, по которому ваши пакеты доходят до другой ноды!';

  @override
  String get helpTracerouteHowBubble =>
      'При отправке трассировки каждый ретранслятор на пути добавляет себя в пакет. Когда он возвращается, вы видите полный путь!';

  @override
  String get helpTracerouteSendBubble =>
      'Отправьте трассировку с **карточки сведений о ноде** (нажмите значок маршрута) или из **истории трассировок** в любое время.';

  @override
  String get helpTracerouteCooldownBubble =>
      'Между трассировками есть **30-секундная пауза** для соблюдения норм использования эфирного времени. Пожалуйста, используйте их разумно!';

  @override
  String get helpTracerouteResultsBubble =>
      'Результаты показывают пути прыжков **туда** и **обратно** с **SNR** (отношение сигнал/шум) для каждого прыжка.';

  @override
  String get helpTracerouteHistoryBubble =>
      'Все трассировки сохраняются в **Историю трассировок** (Настройки > Журналы телеметрии). Удобно для отслеживания изменений сети!';

  @override
  String get helpTracerouteExportBubble =>
      'Экспортируйте историю трассировок в **CSV** для анализа тенденций или документирования. Используйте меню на экране истории!';

  @override
  String get helpTracerouteTipsBubble =>
      '**Совет профессионала:** Запускайте трассировки после перемещения нод, замены антенн или добавления новых ретрансляторов, чтобы проверить улучшения!';

  @override
  String get helpNodedexIntroBubble =>
      'Добро пожаловать в **NodeDex** — ваш личный полевой журнал mesh-сети! Каждая нода, который вы обнаружите, добавляется в вашу коллекцию!';

  @override
  String get helpNodedexSigilsBubble =>
      'Каждая нода получает уникальный **процедурный Символ** — геометрический глиф, сгенерированный из его идентификатора. Никаких двух одинаковых!';

  @override
  String get helpNodedexTraitsBubble =>
      'Ноды получают **Черты** на основе реального поведения — **Странник** перемещается между регионами, **Маяк** всегда доступен, **Призрак** мелькает редко!';

  @override
  String get helpNodedexFiltersBubble =>
      'Используйте **чипы фильтров**, чтобы показывать только ноды с определёнными чертами, недавно обнаруженные ноды или конкретные типы устройств.';

  @override
  String get helpNodedexFieldJournalBubble =>
      'По мере наблюдения за нодами ваш **полевой журнал** пополняется — каждая нода получает рейтинг, автосводку и историю!';

  @override
  String get helpNodedexAlbumModeBubble =>
      'Нажмите **переключатель вида** в панели приложения, чтобы перейти в **режим Альбома** — вид коллекционных карточек вашего NodeDex!';

  @override
  String get helpNodedexAtmosphereBubble =>
      'Замечаете тонкие **частицы** за экраном? Это **Стихийная Атмосфера** — она отражает преобладающий элемент вашего текущего набора нод!';

  @override
  String get helpNodedexCloudSyncBubble =>
      'Ваш NodeDex хранится локально в SQLite и сохраняется после перезапуска приложения — но **не** при переустановке. Используйте **Облачную синхронизацию** для резервного копирования!';

  @override
  String get helpNodedexExportBubble =>
      'Используйте **меню**, чтобы **экспортировать** NodeDex в JSON-файл для резервного копирования или **импортировать** его обратно на другом устройстве.';

  @override
  String get helpNodedexSigilBubble =>
      'Это **Символ** ноды — уникальный процедурный глиф, сгенерированный из его идентификатора. Он не меняется и однозначно идентифицирует нода.';

  @override
  String get helpNodedexTraitBubble =>
      '**Черта** — это выведенная личность на основе поведения данной ноды: движение, частота появления, уровень сигнала и режимы активности.';

  @override
  String get helpNodedexAutoSummaryBubble =>
      '**Автосводка** вычисляет инсайты из истории встреч — распределение по времени суток, динамику появлений и качество сигнала.';

  @override
  String get helpNodedexObservationTimelineBubble =>
      '**Временная шкала наблюдений** визуализирует плотность встреч с этой нодой с течением времени. Отражает, когда и как часто вы видели эту ноду.';

  @override
  String get helpNodedexDiscoveryBubble =>
      '**Статистика обнаружения** показывает, когда вы впервые и последний раз видели эту ноду, количество встреч и общий охват активности.';

  @override
  String get helpNodedexSignalBubble =>
      '**Записи сигнала** отслеживают лучшие и последние значения SNR и RSSI. Это помогает понять качество соединения с данным нодой.';

  @override
  String get helpNodedexSocialTagBubble =>
      '**Социальный тег** — это метка, которую вы назначаете для категоризации ноды: друг, ретранслятор, инфраструктура и т.д.';

  @override
  String get helpNodedexNoteBubble =>
      '**Ваша заметка** — свободное текстовое поле для всего, что вы хотите запомнить об этом ноде. Видно только вам.';

  @override
  String get helpNodedexRegionsBubble =>
      '**История регионов** записывает каждый регулятивный регион, в котором наблюдался эта нода. Видно, путешествует ли он!';

  @override
  String get helpNodedexEncountersBubble =>
      '**Последние встречи** — история появлений этой ноды в вашей сети. Каждая запись включает время, SNR и контекст.';

  @override
  String get helpNodedexActivityTimelineBubble =>
      '**Лента активности** — единая хронологическая лента всего наблюдаемого об этом ноде: встречи, изменения, телеметрия и сигналы.';

  @override
  String get helpNodedexCoseenBubble =>
      '**Совместно наблюдаемые** — ноды, часто замечаемые в одной сессии с этой нодой. Помогает понять топологию и кластеры сети.';

  @override
  String get helpNodedexDeviceBubble =>
      '**Информация об устройстве** показывает актуальную телеметрию — уровень заряда, модель оборудования, версию прошивки и время работы.';

  @override
  String get helpAlbumIntroBubble =>
      'Добро пожаловать в **Альбом коллекционера** — вид вашего NodeDex в формате карточек! Каждая нода становится уникальной коллекционной карточкой!';

  @override
  String get helpAlbumCoverBubble =>
      '**Обложка альбома** — ваша панель: там показан ваш **Титул исследователя**, общее количество карточек и краткое описание коллекции.';

  @override
  String get helpAlbumGroupingBubble =>
      'Используйте **чипы группировки**, чтобы упорядочить карточки по **Черте** (Маяк, Ретранслятор, Призрак...), **Редкости** или **Дате обнаружения**.';

  @override
  String get helpAlbumRarityBubble =>
      'Карточки получают **уровни редкости** на основе количества встреч и черты. **Обычные** ноды встречаются часто, **Легендарные** — невероятно редки!';

  @override
  String get helpAlbumInteractionsBubble =>
      '**Нажмите** на карточку, чтобы открыть полный профиль ноды. **Удерживайте**, чтобы открыть **Галерею карточек** для этой черты.';

  @override
  String get helpAlbumGalleryBubble =>
      'В **Галерее карточек** листайте влево и вправо. **Нажмите** на карточку, чтобы развернуть её, и изучите детали.';

  @override
  String get helpAlbumHolographicBubble =>
      'Карточки более высокой редкости переливаются **голографическим эффектом** — чем редче карточка, тем интенсивнее эффект!';

  @override
  String get helpAlbumPersistenceBubble =>
      'Ваши предпочтения вида альбома и выбор группировки **сохраняются автоматически**. С облачной синхронизацией они переносятся между устройствами!';

  @override
  String get helpConstellationIntroBubble =>
      'Добро пожаловать в **Созвездие** — звёздную карту вашей mesh-сети! Ноды выглядят как звёзды, а связи — как линии созвездий!';

  @override
  String get helpConstellationLayoutBubble =>
      'Расположение **управляется силами** — ноды, которые часто встречаются вместе, группируются. Изолированные ноды дрейфуют на периферию!';

  @override
  String get helpConstellationInteractionsBubble =>
      '**Нажмите** на ноду, чтобы выделить его связи. **Двойное нажатие** для приближения к кластеру. **Щипок для масштабирования** панорамирует вид!';

  @override
  String get helpConstellationEdgesBubble =>
      'Используйте кнопку **плотности связей** в панели приложения, чтобы управлять количеством отображаемых связей. Меньше шума — чётче структура!';

  @override
  String get helpConstellationSearchBubble =>
      'Значок **поиска** позволяет найти конкретную ноду по имени или hex-идентификатору. Вид автоматически центрируется на нём!';

  @override
  String get helpConstellationAtmosphereBubble =>
      'Созвездие имеет собственную **Стихийную Атмосферу** — тонкий звёздный свет и туманности, отражающие характер вашей коллекции!';

  @override
  String get helpConstellationDataBubble =>
      'Данные о совместных наблюдениях формируются **автоматически** из ваших встреч. Чем больше сессий, тем богаче созвездие!';

  @override
  String get helpCloudSyncIntroBubble =>
      '**Облачная синхронизация** — это премиум-подписка, которая синхронизирует данные вашей mesh-сети между всеми устройствами!';

  @override
  String get helpCloudSyncWhatSyncsBubble =>
      'Облачная синхронизация создаёт резервные копии вашего **NodeDex** (символы, встречи, социальные теги, заметки, совместные наблюдения), **автоматизаций**, **профиля** и **настроек приложения**.';

  @override
  String get helpCloudSyncOfflineFirstBubble =>
      'Приложение **работает офлайн в первую очередь**. Изменения сразу сохраняются в SQLite, а когда появляется интернет — синхронизируются в фоне.';

  @override
  String get helpCloudSyncConflictBubble =>
      'Если вы редактируете одну ноду на двух устройствах, Облачная синхронизация использует принцип **«последняя запись побеждает»** — сохраняется самое последнее изменение.';

  @override
  String get helpCloudSyncSubscriptionBubble =>
      'Облачная синхронизация доступна по **ежемесячной** или **ежегодной** подписке. Управляйте ею в Настройках > Облачная синхронизация.';

  @override
  String get helpCloudSyncWithoutBubble =>
      'Без Облачной синхронизации все данные хранятся только на устройстве. Они сохраняются после перезапуска, но не переживают переустановку приложения.';

  @override
  String get helpAetherIntroBubble =>
      '**Aether** позволяет отслеживать ноды Meshtastic на высоте! На высоте 10 000 м сигналы LoRa могут покрывать тысячи километров!';

  @override
  String get helpAetherScheduleBubble =>
      '**Запланируйте рейс** перед полётом. Введите номер рейса, аэропорты, дату вылета и настройте отслеживание.';

  @override
  String get helpAetherActiveBubble =>
      '**Активные рейсы** показывают актуальные данные о местоположении из API OpenSky Network. Вы увидите свою позицию на карте в реальном времени!';

  @override
  String get helpAetherReportsBubble =>
      '**Отчёты о приёме** позволяют наземным станциям сообщать, когда они принимают ваш сигнал. Создавайте карты покрытия на большой высоте!';

  @override
  String get helpAetherLeaderboardBubble =>
      '**Таблица лидеров глобальная и постоянная** — хранится в облаке, а не на вашем устройстве. Ваши рекорды сохраняются при смене телефона!';

  @override
  String get helpAetherTipsBubble =>
      '**Советы**: Лучше садиться у окна. Ненадолго отключите авиарежим в крейсерском полёте. Используйте антенну с круговой поляризацией для лучших результатов!';

  @override
  String get helpTakIntroBubble =>
      '**TAK Gateway** интегрирует вашу mesh-сеть в экосистему Team Awareness Kit (TAK). Импортируйте CoT-объекты с TAK-серверов!';

  @override
  String get helpTakConnectBubble =>
      'Нажмите на **значок ссылки** в панели приложения для подключения или отключения. Карточка статуса показывает текущее состояние соединения.';

  @override
  String get helpTakAffiliationsBubble =>
      'Каждый объект окрашен по **стандартной принадлежности** — синий для дружественных, красный для враждебных, жёлтый для неизвестных, зелёный для нейтральных.';

  @override
  String get helpTakFilterBubble =>
      'Используйте **чипы фильтров** для сужения списка по принадлежности или введите позывной в строку поиска.';

  @override
  String get helpTakDetailBubble =>
      'Нажмите на любой объект, чтобы открыть экран **подробностей** — полные поля CoT, координаты, скорость и временны́е метки.';

  @override
  String get helpTakTrackingBubble =>
      '**Удерживайте** плитку объекта, чтобы включить/выключить отслеживание. Отслеживаемые объекты выделяются и остаются в верхней части списка.';

  @override
  String get helpTakSettingsBubble =>
      'Откройте **Настройки TAK** из меню, чтобы изменить URL шлюза, переключить автоподключение или сбросить историю объектов.';

  @override
  String get helpRadioResponsibilityBubble =>
      '**Вы** несёте ответственность за то, чтобы ваше радиооборудование соответствовало законам вашей страны. Meshtastic работает на нелицензируемых диапазонах — но правила всё равно действуют!';

  @override
  String get helpRadioLicenceBubble =>
      'В некоторых регионах для передачи сигнала требуется **лицензия радиолюбителя**. Уточните требования вашей страны перед использованием.';

  @override
  String get helpRadioInterferenceBubble =>
      'Никогда не создавайте помех **аварийным коммуникациям** или лицензированным службам. Нарушения могут повлечь серьёзные правовые последствия.';

  @override
  String get helpRadioTermsLinkBubble =>
      'Для получения полной информации ознакомьтесь с разделом **«Радио и соответствие законодательству»** в наших Условиях использования.';

  @override
  String get helpUseIntroBubble =>
      'Socialmesh — мощный инструмент. Автоматизации, сигналы и mesh-сообщения дают широкие возможности — используйте их ответственно!';

  @override
  String get helpUseLawfulBubble =>
      'Используйте приложение только в **законных целях**. Не передавайте вредоносный, угрожающий или незаконный контент по сети.';

  @override
  String get helpUseAutomationsBubble =>
      'Автоматизации отлично подходят для оповещений, но не используйте их для **спама или флуда** в сети. Будьте уважительным участником!';

  @override
  String get helpUseImpersonationBubble =>
      'Не **выдавайте себя** за других людей или организации в mesh-сети. Будьте собой и уважайте остальных участников!';

  @override
  String get helpUseTermsLinkBubble =>
      'Полный список запрещённых действий находится в разделе **«Использование сервиса»** в наших Условиях использования.';

  @override
  String get helpResponsibilityIntroBubble =>
      'Socialmesh разработан с приоритетом **конфиденциальности**. Ваши сообщения и данные хранятся на вашем устройстве — мы не продаём ваши данные!';

  @override
  String get helpResponsibilitySignalsBubble =>
      'Когда вы создаёте **Сигнал**, он транслируется по mesh-сети. Все, у кого есть совместимое устройство, могут его получить.';

  @override
  String get helpResponsibilityContentBubble =>
      'Вы несёте ответственность за **всё, что передаёте**. Не распространяйте личные данные других без их согласия.';

  @override
  String get helpResponsibilityThirdPartyBubble =>
      'Некоторые функции используют **сторонние сервисы**: RevenueCat для покупок и Firebase для облачного резервного копирования.';

  @override
  String get helpResponsibilityTermsLinkBubble =>
      'Для получения полной информации ознакомьтесь с нашими **Условиями использования** и **Политикой конфиденциальности** в Настройках.';

  @override
  String get helpFtIntroBubble =>
      '**Передача файлов** позволяет отправлять небольшие файлы — текст, конфигурации, координаты — напрямую через mesh!';

  @override
  String get helpFtHowBubble =>
      'Файлы разбиваются на **фрагменты ~200 байт** и отправляются по одному через mesh. Получатель собирает фрагменты обратно в файл!';

  @override
  String get helpFtNackBubble =>
      'Пропустили фрагмент? Не проблема. Получатель отправляет **NACK** (отрицательное подтверждение), и отправитель повторяет только пропущенные фрагменты!';

  @override
  String get helpFtLimitBubble =>
      'Максимальный размер файлов — **8 КБ**. LoRa — медленная, общая, маломощная радиосвязь. Один файл 8 КБ может занять несколько минут!';

  @override
  String get helpFtBetaBubble =>
      'Эта функция находится в стадии **БЕТА**. Оба ноды должны работать на Socialmesh в одной и той же mesh-сети.';

  @override
  String get helpFtContactsBubble =>
      'Используйте вкладку **Контакты**, чтобы выбрать ноду, затем нажмите **Отправить файл**. Вкладка «Контакты» показывает, кто сейчас в сети.';

  @override
  String get helpFtlSharedBubble =>
      'Каналы LoRa **общие и медленные**. Каждый байт, который вы отправляете, — это эфирное время, которое используется совместно с другими. Отправляйте только необходимое!';

  @override
  String get helpFtlToaBubble =>
      '**Время в эфире** на фрагмент зависит от коэффициента распространения (SF). SF7 (быстро, малая дальность): ~30 мс/фрагмент. SF12 (медленно, большая дальность): ~1,5 с/фрагмент!';

  @override
  String get helpFtlMathBubble =>
      '8 КБ ÷ 200 байт/фрагмент = **41 фрагмент**. При SF7: ~1,2 с всего. При SF12: **~61 с** — и это только эфирное время, без учёта повторных передач!';

  @override
  String get helpFtlDutyBubble =>
      'Диапазоны EU868 и аналогичные имеют **1% рабочий цикл** — радио может передавать только 1% времени. Файл на 8 КБ при SF12 может занять **несколько часов**!';

  @override
  String get helpFtlCapBubble =>
      '8 КБ — это **самый безопасный максимум**, при котором передача остаётся выполнимой даже при наихудшем коэффициенте распространения.';

  @override
  String get helpFtlUsbBubble =>
      'Передачи через BLE и USB не имеют ограничений рабочего цикла. В будущих версиях этот лимит может быть снят для таких подключений.';

  @override
  String get helpNodeDexSectionSigil =>
      'Уникальный процедурный глиф, сгенерированный из идентификатора данной ноды.';

  @override
  String get helpNodeDexSectionTrait =>
      'Выведенный архетип личности на основе поведенческих сигналов:';

  @override
  String get helpNodeDexSectionAutoSummary =>
      'Вычисленные инсайты из истории встреч данной ноды. Распределение по времени суток';

  @override
  String get helpNodeDexSectionObservationTimeline =>
      'Визуальная временная шкала истории наблюдений данной ноды. Столбик показывает';

  @override
  String get helpNodeDexSectionDiscovery =>
      'Отслеживает время первого и последнего обнаружения данной ноды в вашей сети, общее';

  @override
  String get helpNodeDexSectionSignal =>
      'Лучшие и последние значения SNR (отношение сигнал/шум) и RSSI';

  @override
  String get helpNodeDexSectionSocialTag =>
      'Личная метка для категоризации данной ноды. Социальные теги являются';

  @override
  String get helpNodeDexSectionNote =>
      'Свободная заметка о любой информации, которую вы хотите запомнить об этом ноде.';

  @override
  String get helpNodeDexSectionRegions =>
      'Все регулятивные регионы, в которых наблюдался данная нода. Регион';

  @override
  String get helpNodeDexSectionEncounters =>
      'Хронологическая лента появлений данной ноды в вашей сети.';

  @override
  String get helpNodeDexSectionActivityTimeline =>
      'Единая хронологическая лента всего наблюдаемого об этом ноде:';

  @override
  String get helpNodeDexSectionCoseen =>
      'Ноды, которые часто наблюдаются в одной сессии с этой нодой.';

  @override
  String get helpNodeDexSectionDevice =>
      'Актуальная телеметрия с ноды: процент заряда батареи, модель оборудования,';

  @override
  String get helpNodeDexSectionAlbumRarity =>
      'Уровни редкости вычисляются на основе количества встреч и выведенной черты.';

  @override
  String get helpNodeDexSectionAlbumGrouping =>
      'Карточки можно группировать по Черте (поведенческий архетип), Редкости';

  @override
  String get helpNodeDexSectionAlbumExplorerTitle =>
      'Ваш Титул исследователя отражает общий прогресс коллекции.';

  @override
  String get helpNodeDexSectionAlbumHolographic =>
      'Голографическое мерцание на карточках — визуальный индикатор редкости.';

  @override
  String get helpNodeDexSectionAlbumPatina =>
      'Патина — сводная оценка, отражающая глубину ваших наблюдений за';

  @override
  String get helpNodeDexSectionAlbumCloudSync =>
      'С подпиской Облачная синхронизация весь ваш альбом NodeDex резервируется';

  @override
  String get helpTakSectionStatus =>
      'Карточка статуса показывает, подключено ли WebSocket-соединение с TAK';

  @override
  String get helpTakSectionAffiliation =>
      'Принадлежность описывает отношение объекта к';

  @override
  String get helpTakSectionCotType =>
      'Строка типа CoT кодирует принадлежность, измерение и';

  @override
  String get helpTakSectionIdentity =>
      'UID однозначно идентифицирует данный объект во всех CoT-сообщениях.';

  @override
  String get helpTakSectionPosition =>
      'Широта и долгота в десятичных градусах WGS-84, как указано в';

  @override
  String get helpTakSectionMotion =>
      'Скорость, курс и высота, извлечённые из трека и';

  @override
  String get helpTakSectionTimestamps =>
      'Время события — момент генерации CoT-события. Время устаревания — когда';

  @override
  String get helpTakSectionTracking =>
      'Отслеживаемые объекты закреплены и выделены на карте с';

  @override
  String get helpTakSectionRawPayload =>
      'Необработанные JSON-данные, полученные от WebSocket TAK Gateway.';

  @override
  String get helpTakSectionFilters =>
      'Чипы фильтров позволяют сужать список объектов по принадлежности.';

  @override
  String get helpTakSectionSettings =>
      'Настройки TAK позволяют настроить URL шлюза, переключить автоподключение';

  @override
  String get accessRestrictedTitle => 'Доступ ограничен';

  @override
  String get goBack => 'Назад';

  @override
  String get deviceNotConnected => 'Устройство не подключено';

  @override
  String get connectDevice => 'Подключить устройство';

  @override
  String get connectDeviceToUseFeature =>
      'Подключите устройство для использования этой функции';

  @override
  String positionRequestedFrom(String name) {
    return 'Местоположение запрошено у $name';
  }

  @override
  String failedGeneric(String error) {
    return 'Ошибка: $error';
  }

  @override
  String failedToUpdateSignalLocationRadius(String error) {
    return 'Не удалось обновить радиус местоположения сигнала: $error';
  }

  @override
  String failedToSaveConfiguration(String error) {
    return 'Не удалось сохранить конфигурацию: $error';
  }

  @override
  String automationActionError(int index, String error) {
    return 'Действие $index: $error';
  }

  @override
  String failedToPlay(String error) {
    return 'Не удалось воспроизвести: $error';
  }

  @override
  String get whatsNewVersion190Subtitle => 'Версия 1.9.0';

  @override
  String get whatsNewReachabilityTitle => 'Достижимость';

  @override
  String get whatsNewReachabilityDescription =>
      'Оцените вероятность достижения каждой ноды в вашей сети — без отправки единого тестового пакета.\\n\\nДостижимость пассивно наблюдает за трафиком в сети и присваивает каждой ноде уровень уверенности: высокий, средний или низкий. Найдите в меню под разделом «Сеть».';

  @override
  String get whatsNewVersion1100Subtitle => 'Версия 1.10.0';

  @override
  String get whatsNewWorldMapTitle => 'Карта мира';

  @override
  String get whatsNewWorldMapDescription =>
      'Смотрите всю глобальную сеть Meshtastic на одной карте. Каждая точка — нода, передающий своё местоположение. Приближайте, перемещайте карту, нажимайте на точки для просмотра сведений о нодах, информации об оборудовании и времени последней активности.\\n\\nПодключение не требуется. Карта мира берёт данные в реальном времени из бэкенда Socialmesh, чтобы вы могли изучать сеть где угодно.';

  @override
  String get whatsNewVersion1101Subtitle => 'Версия 1.10.1';

  @override
  String get whatsNewPresenceTitle => 'Присутствие';

  @override
  String get whatsNewPresenceDescription =>
      'Смотрите, кто активен в вашей сети, с первого взгляда. Присутствие показывает активность нод в реальном времени с индикаторами намерений — мониторинг, мобильный или стационарная базовая станция.\\n\\nФильтруйте по уровню активности, ищите по имени и нажимайте на любая нода для просмотра полного профиля. Найдите в меню под разделом «Социальное».';

  @override
  String get whatsNewVersion1110Subtitle => 'Версия 1.11.0';

  @override
  String get whatsNewSignalsTitle => 'Сигналы';

  @override
  String get whatsNewSignalsDescription =>
      'Транслируйте мимолётные моменты в вашу сеть. Сигналы — это кратковременные публикации: поделитесь текстом, фото или вашим местоположением с TTL от 15 минут до 24 часов.\\n\\nБлижайшие сигналы отображаются первыми с бейджами близости, показывающими число переходов. Когда они исчезнут, они пропадут навсегда. Настоящий автономный эфемерный контент.';

  @override
  String get whatsNewVersion1130Subtitle => 'Версия 1.13.0';

  @override
  String get whatsNewNodeDexTitle => 'NodeDex';

  @override
  String get whatsNewNodeDexDescription =>
      'Живой полевой журнал мира радиосетей. Каждый обнаруженная нода автоматически записывается с уникальным процедурным Sigil и чертой характера, полученной из реального поведения.\\n\\nНайдите в меню под разделом «Социальное». Фильтруйте по чертам, ищите по имени или шестнадцатеричному ID, нажимайте на запись для изучения полного профиля — история сигнала, хронология обнаружения и многое другое.';

  @override
  String get whatsNewVersion1150Subtitle => 'Версия 1.15.0';

  @override
  String get whatsNewAetherTitle => 'Aether';

  @override
  String get whatsNewAetherDescription =>
      'Отслеживайте ноды Meshtastic на высоте! Запланируйте полёт с вашей нодой и позвольте наземным станциям по всему миру прослушивать ваш сигнал.\\n\\nНа высоте 35 000 футов LoRa может достигать 400+ км. Сообщайте о приёмах, соревнуйтесь в таблице лидеров по дальности и устанавливайте новые рекорды. Найдите в меню под разделом «Социальное».';

  @override
  String get whatsNewVersion1160Subtitle => 'Версия 1.16.0';

  @override
  String get whatsNewTakGatewayTitle => 'TAK Шлюз';

  @override
  String get whatsNewTakGatewayDescription =>
      'Подключите вашу сеть к экосистеме Team Awareness Kit (TAK). Socialmesh теперь подключается к TAK Gateway через WebSocket и передаёт живые объекты Cursor-on-Target на вашу карту.\\n\\nКаждый объект раскрашен по стандартной принадлежности и снабжён иконкой соответствующего типа. Фильтруйте по принадлежности, ищите позывные, отслеживайте объекты долгим нажатием и нажимайте на маркер для просмотра полных данных CoT. Найдите в меню под разделом «Сеть».';

  @override
  String get notificationNewNodeTitle => 'Обнаружен новая нода';

  @override
  String notificationNewNodeBody(String nodeName, String shortCode) {
    return '$nodeName ($shortCode) присоединился к сети';
  }

  @override
  String get notificationAetherFlightTitle => 'Обнаружен полёт Aether';

  @override
  String notificationDetectionSensorTitle(String sensorName, String state) {
    return '$sensorName: $state';
  }

  @override
  String notificationDetectionSensorBody(String displayName) {
    return 'От $displayName';
  }

  @override
  String notificationEntityStaleTitle(String callsign) {
    return 'Устаревший объект: $callsign';
  }

  @override
  String notificationProximityAlertTitle(String callsign) {
    return 'Оповещение о близости: $callsign';
  }

  @override
  String notificationDirectMessageTitle(String senderName, String shortCode) {
    return 'Сообщение от $senderName ($shortCode)';
  }

  @override
  String notificationChannelMessageTitle(
    String senderName,
    String shortCode,
    String channelName,
  ) {
    return '$senderName ($shortCode) в $channelName';
  }

  @override
  String get notificationChannelNodeDiscovery =>
      'Уведомления о новых обнаруженных нодах сети';

  @override
  String get notificationChannelAetherFlights =>
      'Уведомления о событиях обнаружения полётов Aether';

  @override
  String get notificationChannelDeviceAlerts =>
      'Важные уведомления от вашего устройства Meshtastic';

  @override
  String get notificationChannelDetectionSensor =>
      'Уведомления о событиях датчиков обнаружения';

  @override
  String get notificationChannelTakStale =>
      'Уведомления при устаревании отслеживаемых объектов TAK';

  @override
  String get notificationChannelTakProximity =>
      'Уведомления о близости объектов TAK';

  @override
  String get notificationChannelDirectMessages =>
      'Уведомления о личных сообщениях сети';

  @override
  String get notificationChannelMessages =>
      'Уведомления о сообщениях в каналах сети';

  @override
  String get flowNodeEvent => 'Событие';

  @override
  String get flowNodeMessageContains => 'Сообщение содержит';

  @override
  String get flowNodeNodeSilent => 'Нода молчит';

  @override
  String get flowNodeScheduled => 'По расписанию';

  @override
  String get flowNodeSignalWeak => 'Слабый сигнал';

  @override
  String get flowNodeChannelActivity => 'Активность канала';

  @override
  String get flowNodeDetectionSensor => 'Датчик обнаружения';

  @override
  String get flowNodeManual => 'Вручную';

  @override
  String get flowNodeAllNodes => 'Все ноды';

  @override
  String get flowNodeNodes => 'Ноды';

  @override
  String get flowNodeTraitFilter => 'Фильтр по чертам';

  @override
  String get flowNodeDistanceFilter => 'Фильтр по расстоянию';

  @override
  String get flowNodeEncounterFilter => 'Фильтр по встречам';

  @override
  String get flowNodeOnlineFilter => 'Фильтр по наличию в сети';

  @override
  String get flowNodeBatteryFilter => 'Фильтр по заряду';

  @override
  String get flowNodeNameFilter => 'Фильтр по имени';

  @override
  String get flowNodeSort => 'Сортировка';

  @override
  String get flowNodeLimit => 'Ограничение';

  @override
  String get flowNodeInput => 'Входные данные';

  @override
  String get flowNodeFiltered => 'Отфильтровано';

  @override
  String get flowNodeSorted => 'Отсортировано';

  @override
  String get flowNodeLimited => 'Ограничено';

  @override
  String get flowNodeExecute => 'Выполнить';

  @override
  String get flowNodeAnd => 'И';

  @override
  String get flowNodeOr => 'ИЛИ';

  @override
  String get flowNodeNot => 'НЕ';

  @override
  String get flowNodeDelay => 'Задержка';

  @override
  String get flowNodeAllMet => 'Все условия';

  @override
  String get flowNodeAnyMet => 'Любое условие';

  @override
  String get flowNodeInverted => 'Инвертировано';

  @override
  String get flowNodeDelayed => 'Отложено';

  @override
  String get automationTemplateLowBatteryTitle => 'Оповещение о низком заряде';

  @override
  String get automationTemplateNodeOfflineTitle =>
      'Оповещение об отключении ноды';

  @override
  String get automationTemplateWeatherReportTitle => 'Отчёт о погоде';

  @override
  String get automationTemplateWeatherReportDescription =>
      'Периодически отправлять данные о погоде с датчиков окружающей среды';

  @override
  String get automationTemplateChannelMonitorTitle => 'Мониторинг канала';

  @override
  String get automationTemplateChannelMonitorDescription =>
      'Записывать активность в определённом канале';

  @override
  String get automationTemplateEmergencyBeaconTitle => 'Аварийный маяк';

  @override
  String get automationTemplateEmergencyBeaconDescription =>
      'Транслировать аварийное местоположение каждые 5 минут при срабатывании';

  @override
  String get automationTemplateGeofenceExitTitle =>
      'Оповещение о выходе из геозоны';

  @override
  String get automationTemplateSosTitle => 'Ответ на SOS';

  @override
  String get automationTemplateDeadManTitle => 'Мёртвая рука';

  @override
  String get whatsNewCtaOpenWorldMap => 'Открыть карту мира';

  @override
  String get whatsNewCtaOpenPresence => 'Открыть присутствие';

  @override
  String get whatsNewCtaOpenNodedex => 'Открыть NodeDex';

  @override
  String get whatsNewCtaOpenAether => 'Открыть Aether';

  @override
  String get whatsNewCtaOpenReachability => 'Открыть достижимость';

  @override
  String get whatsNewCtaOpenSignals => 'Открыть сигналы';

  @override
  String get whatsNewCtaOpenTakGateway => 'Открыть TAK шлюз';

  @override
  String get whatsNewHeadline => 'Что нового в Socialmesh';

  @override
  String get connectingStatusInitializing => 'Инициализация';

  @override
  String get connectingStatusScanning => 'Поиск устройства';

  @override
  String get connectingStatusConnecting => 'Подключение';

  @override
  String get connectingStatusAutoReconnecting =>
      'Автоматическое переподключение';

  @override
  String get connectingStatusConfiguring => 'Настройка устройства';

  @override
  String get connectingStatusConnected => 'Подключено';

  @override
  String get connectingStatusFailed => 'Ошибка подключения';

  @override
  String get profileAvatarUpdated => 'Аватар обновлён';

  @override
  String get profileAvatarRemoved => 'Аватар удалён';

  @override
  String get profileBannerUpdated => 'Баннер обновлён';

  @override
  String get profileBannerRemoved => 'Баннер удалён';

  @override
  String get commonOpenSettings => 'Открыть настройки';

  @override
  String get socialGuidelineNoViolentImagery =>
      'Запрещены жестокие или шокирующие изображения';

  @override
  String get globalLayerConnectionTestLabel => 'ТЕСТ ПОДКЛЮЧЕНИЯ';

  @override
  String get commonSignIn => 'Вход';

  @override
  String get onboardingSignalContentMike =>
      'Базовый лагерь разбит. Готов по вашей команде.';

  @override
  String get onboardingSignalContentAlex => 'Уже еду, буду через 15 мин';

  @override
  String get automationErrorSendMsgNotConfigured =>
      'Обратный вызов отправки сообщений не настроен';

  @override
  String get automationErrorNoTargetNode => 'Целевая нода не указан';

  @override
  String get automationErrorSendChannelNotConfigured =>
      'Обратный вызов отправки в канал не настроен';

  @override
  String get automationErrorNoTargetChannel => 'Целевой канал не указан';

  @override
  String get automationErrorNoSoundConfigured => 'Звук не настроен';

  @override
  String automationErrorPlaySoundFailed(String error) {
    return 'Не удалось воспроизвести звук: $error';
  }

  @override
  String get automationErrorNotificationsNotInit =>
      'Уведомления не инициализированы';

  @override
  String get automationErrorNoWebhookEvent => 'Имя события Webhook не указано';

  @override
  String get automationErrorIftttNotConfigured =>
      'IFTTT не настроен — включите IFTTT и укажите ключ Webhook в настройках';

  @override
  String get automationErrorWebhookFailed =>
      'Запрос Webhook не удался — проверьте подключение к сети';

  @override
  String get automationErrorSendMsgFailed => 'Не удалось отправить сообщение';

  @override
  String get automationErrorSendChannelFailed => 'Не удалось отправить в канал';

  @override
  String get automationErrorShortcutsIosOnly =>
      'Shortcuts доступны только на iOS';

  @override
  String get automationErrorNoShortcutName => 'Имя Shortcut не указано';

  @override
  String automationErrorShortcutLaunchFailed(String name) {
    return 'Не удалось запустить Shortcut «$name»';
  }

  @override
  String automationErrorShortcutRunFailed(String error) {
    return 'Не удалось выполнить Shortcut: $error';
  }

  @override
  String get automationErrorGlyphNotAvailable =>
      'Интерфейс подсветки недоступен';

  @override
  String automationErrorGlyphPatternFailed(String error) {
    return 'Не удалось отобразить паттерн подсветки: $error';
  }

  @override
  String get automationTemplateLowBatteryDesc =>
      'Уведомить, когда уровень аккумулятора ноды падает ниже 20%';

  @override
  String get automationTemplateNodeOfflineDesc =>
      'Уведомить, когда нода уходит в офлайн';

  @override
  String get automationTemplateGeofenceExitDesc =>
      'Оповестить, когда нода покидает обозначенную зону';

  @override
  String get automationTemplateSosDesc =>
      'Автоматически ответить при получении SOS-сообщения';

  @override
  String get automationTemplateDeadManDesc =>
      'Оповестить, если нет активности от ноды в течение 30 минут';

  @override
  String get automationScheduledTitle => 'Автоматизация по расписанию';

  @override
  String get automationScheduledBody =>
      'Нажмите, чтобы запустить автоматизацию по расписанию';

  @override
  String automationLogNode(String nodeName) {
    return 'Node: $nodeName';
  }

  @override
  String automationLogBattery(int level) {
    return 'Battery: $level%';
  }

  @override
  String automationLogMessage(String text) {
    return 'Message: $text';
  }

  @override
  String get authErrorGoogleSignInCancelled => 'Вход через Google отменён';

  @override
  String get authErrorGoogleNoIdToken =>
      'Вход через Google не вернул токен идентификации';

  @override
  String get authErrorNoCurrentUser =>
      'Ни один пользователь не вошёл в систему';

  @override
  String get authErrorGoogleReauthCancelled =>
      'Повторная аутентификация через Google отменена';

  @override
  String get authErrorNoSupportedProvider =>
      'Не найден поддерживаемый провайдер для повторной аутентификации';

  @override
  String get authErrorNoUserSignedIn => 'Пользователь не вошёл в систему';

  @override
  String get authErrorSessionLost =>
      'Сессия пользователя утеряна во время повторной аутентификации';

  @override
  String get authErrorVerificationCodeFailed =>
      'Не удалось отправить код подтверждения';

  @override
  String get connectionErrorBluetoothDisabled => 'Bluetooth отключён';

  @override
  String get connectionErrorDeviceNotFound => 'Устройство не найдено';

  @override
  String get connectionErrorDeviceReset =>
      'Устройство было сброшено или заменено. Настройте его заново.';

  @override
  String countdownTracerouteTo(String displayName) {
    return 'Трассировка до $displayName';
  }

  @override
  String get countdownRequestingPositions => 'Запрос местоположений в сети';

  @override
  String get countdownBroadcastingPosition =>
      'Трансляция местоположения в сеть';

  @override
  String get lifecycleAppNotActive => 'Приложение неактивно';

  @override
  String get lifecycleCommandExpired => 'Команда истекла';

  @override
  String get nodedexMilestoneFirstDiscovered => 'Первое обнаружение';

  @override
  String nodedexMilestoneEncounterN(int count) {
    return 'Встреча #$count';
  }

  @override
  String meshHealthRssiDegraded(String rssi) {
    return 'Средний RSSI ухудшился до $rssi dBm';
  }

  @override
  String offlineQueueMaxRetries(String error) {
    return 'Достигнуто максимальное число попыток: $error';
  }

  @override
  String get connectionAlreadyInProgress => 'Подключение уже выполняется';

  @override
  String get connectionCancelled => 'Подключение отменено';

  @override
  String get adminConformanceBundleTitle =>
      'Пакет тестирования соответствия Socialmesh';

  @override
  String get adminDiagnosticBundleText =>
      'Диагностический пакет администратора от Socialmesh';

  @override
  String adminDiagnosticBundleSubject(String runId) {
    return 'Диагностика Socialmesh $runId';
  }

  @override
  String get onboardingSignalAuthorSarah => 'Sarah';

  @override
  String get onboardingSignalContentSarah =>
      'Только что достигла вершины! Сигнал кристально чистый.';

  @override
  String get onboardingSignalAuthorMike => 'Mike';

  @override
  String get onboardingSignalAuthorAlex => 'Alex';

  @override
  String get globalLayerCopyExplainTitle => 'Что такое MQTT?';

  @override
  String get globalLayerCopyExplainBody =>
      'Ваш радио-модуль связывается с ближайшими устройствами по радио — без интернета. MQTT позволяет передавать ваши даные на общедоступные карты, а также связываться с другими нодами через интернет.';

  @override
  String get globalLayerCopyExplainWhatItDoes =>
      'Передает ваши сообщения и другие данные через интернет.';

  @override
  String get globalLayerCopyExplainWhatItDoesNot =>
      'НЕ заменяет ваше радио - оно работает независимо.';

  @override
  String get globalLayerCopyBrokerTitle => 'Выберите сервер';

  @override
  String get globalLayerCopyBrokerBody =>
      'Выберите MQTT-сервер для подключения. Большинству пользователей можно начать с официального сервера Meshtastic.';

  @override
  String get globalLayerCopyTopicsTitle => 'Выберите, чем делиться';

  @override
  String get globalLayerCopyTopicsBody =>
      'Темы определяют, какие типы данных проходят через MQTT.';

  @override
  String get globalLayerCopyPrivacyTitle => 'Конфиденциальность и безопасность';

  @override
  String get globalLayerCopyPrivacyBody =>
      'Обмен через MQTT работает только по вашему желанию. Ничего не передаётся до тех пор, пока вы явно не включите это.';

  @override
  String get globalLayerCopyPrivacyBrokerTrustWarning =>
      'MQTT-сервер видит все данные, которые вы через него отправляете. Подключайтесь только к тем серверам, которым доверяете.';

  @override
  String get globalLayerCopyTestTitle => 'Тест подключения';

  @override
  String get globalLayerCopyTestBody =>
      'Проверяется доступность сервера и корректность настроек.';

  @override
  String get globalLayerCopySummaryTitle => 'Готово к подключению';

  @override
  String get globalLayerCopySummaryBody =>
      'Просмотрите настройки MQTT ниже. Вы можете изменить любую из них позже.';

  @override
  String get mqttTopicChatLabel => 'Чат';

  @override
  String get mqttTopicChatDescription =>
      'Текстовые сообщения, которыми обмениваются ноды сети по определённому каналу.';

  @override
  String get mqttTopicTelemetryLabel => 'Телеметрия';

  @override
  String get mqttTopicTelemetryDescription =>
      'Данные о состоянии устройства: уровень заряда, напряжение, время работы.';

  @override
  String get mqttTopicPositionLabel => 'Местоположение';

  @override
  String get mqttTopicPositionDescription =>
      'GPS-координаты, передаваемые нодами сети (конфиденциальные данные).';

  @override
  String get mqttTopicNodeInfoLabel => 'Информация о ноде';

  @override
  String get mqttTopicNodeInfoDescription =>
      'Общие сведения о ноде: длинное имя, короткое имя, модель оборудования.';

  @override
  String get mqttTopicMapReportsLabel => 'Отчёты карты';

  @override
  String get mqttTopicMapReportsDescription =>
      'Периодические отчёты о местоположении для общедоступных карт в интернете.';

  @override
  String get mqttBrokerMeshtasticName => 'Meshtastic (официальный)';

  @override
  String get mqttBrokerMeshtasticDescription =>
      'Стандартный MQTT-сервер Meshtastic. Подключает вас к общемировой сети. Учётная запись не требуется.';

  @override
  String get mqttBrokerMeshtasticNote =>
      'Публичные учётные данные используются всеми пользователями Meshtastic.';

  @override
  String get mqttBrokerMosquittoName => 'Mosquitto Test';

  @override
  String get mqttBrokerMosquittoDescription =>
      'Бесплатный тестовый MQTT-сервер от проекта Eclipse Mosquitto. Для проверки настроек перед подключением к рабочему серверу.';

  @override
  String get mqttBrokerMosquittoNote =>
      'Тестовый сервер — не для полноценного использования. Возможны перебои.';

  @override
  String get mqttBrokerCustomName => 'Пользовательский MQTT-сервер';

  @override
  String get mqttBrokerCustomDescription =>
      'Введите данные для подключения вручную.';

  @override
  String get globalLayerDiagConfigTitle => 'Конфигурация';

  @override
  String get globalLayerDiagConfigDescription =>
      'Проверка правильности формата адреса сервера, порта и корневой темы.';

  @override
  String get globalLayerDiagDnsTitle => 'Разрешение DNS';

  @override
  String get globalLayerDiagDnsDescription =>
      'Поиск имени сервера для определения его сетевого адреса.';

  @override
  String get globalLayerDiagTcpTitle => 'TCP-подключение';

  @override
  String get globalLayerDiagTcpDescription =>
      'Установка сетевого соединения с сервером.';

  @override
  String get globalLayerDiagTlsTitle => 'TLS handshake';

  @override
  String get globalLayerDiagTlsDescription =>
      'Согласование защищённого соединения с сервером.';

  @override
  String get globalLayerDiagAuthTitle => 'Аутентификация';

  @override
  String get globalLayerDiagAuthDescription =>
      'Проверка имени пользователя и пароля на сервере.';

  @override
  String get globalLayerDiagSubscribeTitle => 'Тест подписки';

  @override
  String get globalLayerDiagSubscribeDescription =>
      'Подписка на тестовую тему для проверки доступа на чтение.';

  @override
  String get globalLayerDiagPublishTitle => 'Тест публикации';

  @override
  String get globalLayerDiagPublishDescription =>
      'Публикация тестового сообщения для проверки доступа на запись.';

  @override
  String get globalLayerDiagSuggestionCorrectFields =>
      'Исправьте выделенные поля и повторите попытку.';

  @override
  String get globalLayerDiagSuggestionUnexpectedBehavior =>
      'Эти проблемы могут не мешать подключению, но способны вызвать непредвиденное поведение.';

  @override
  String get globalLayerDiagConfigValid => 'Все поля конфигурации корректны.';

  @override
  String get globalLayerDiagSuggestionValidHostname =>
      'Введите корректный адрес сервера.';

  @override
  String get globalLayerDiagSuggestionBothCredentials =>
      'Некоторые MQTT-серверы требуют указания как имени пользователя, так и пароля.';

  @override
  String globalLayerWizardDnsValid(String host) {
    return 'Адрес сервера корректный: $host';
  }

  @override
  String globalLayerWizardTcpReachable(String host, int port) {
    return 'TCP-подключение к $host:$port доступно.';
  }

  @override
  String get globalLayerWizardTlsAccepted => 'Параметры TLS handshake приняты.';

  @override
  String get globalLayerWizardCredentialsAccepted =>
      'Учётные данные предоставлены и приняты.';

  @override
  String get globalLayerWizardAnonymousAccess =>
      'Учётные данные не указаны — используется анонимный доступ.';

  @override
  String get globalLayerWizardSubscribeVerified =>
      'Права на подписку подтверждены.';

  @override
  String get globalLayerWizardPublishVerified =>
      'Права на публикацию подтверждены.';

  @override
  String get globalLayerShareMessagesSubtitle =>
      'Ваши сообщения будут пересылаться в интернет.';

  @override
  String get globalLayerShareTelemetrySubtitle =>
      'Уровень заряда батареи, напряжение и время работы устройства будут пересылаться в интернет.';

  @override
  String get globalLayerAllowInboundSubtitle =>
      'Сообщения из интернета будут доставляться в ваши локальные каналы.';

  @override
  String get globalLayerBrokerTrust => 'Доверие к MQTT-серверу';

  @override
  String get globalLayerRunConnectionTest => 'Запустить тест подключения';

  @override
  String get globalLayerSkipTestHint =>
      'Вы можете пропустить этот шаг и протестировать позже.';

  @override
  String get globalLayerWizardAllChecksPassed => 'Все проверки пройдены';

  @override
  String get globalLayerPassedWithWarnings => 'Пройдено с предупреждениями';

  @override
  String get globalLayerSomeChecksFailed => 'Некоторые проверки не пройдены';

  @override
  String get globalLayerTestInProgress => 'Тест выполняется';

  @override
  String get globalLayerSummaryBrokerSection => 'СЕРВЕР';

  @override
  String get globalLayerSummaryTopicsSection => 'ТЕМЫ';

  @override
  String get globalLayerSummaryPrivacySection => 'КОНФИДЕНЦИАЛЬНОСТЬ';

  @override
  String get globalLayerSummaryAddress => 'Адрес';

  @override
  String get globalLayerSummaryPort => 'Порт';

  @override
  String get globalLayerSummaryTls => 'TLS';

  @override
  String get globalLayerSummaryTlsEnabled => 'Включено';

  @override
  String get globalLayerSummaryTlsDisabled => 'Отключено';

  @override
  String get globalLayerSummaryAuth => 'Аутентификация';

  @override
  String get globalLayerSummaryAuthCredentials => 'Учётные данные настроены';

  @override
  String get globalLayerSummaryAuthAnonymous => 'Анонимно';

  @override
  String get globalLayerSummaryRoot => 'Корневая тема';

  @override
  String get globalLayerSummaryTopicsEnabled => 'Включены';

  @override
  String get globalLayerSummaryTopicsNone => 'Нет';

  @override
  String get globalLayerSummaryShareMessages => 'Делиться сообщениями';

  @override
  String get globalLayerSummaryShareTelemetry => 'Делиться телеметрией';

  @override
  String get globalLayerSummaryInboundGlobal => 'Получать данные';

  @override
  String get globalLayerSummaryOn => 'ВКЛ';

  @override
  String get globalLayerSummaryOff => 'ВЫКЛ';

  @override
  String get globalLayerAllSharingOff =>
      'Передача данных в интернет полностью выключена. Данные остаются локальными.';

  @override
  String get globalLayerNoTlsLabel => 'Без TLS';

  @override
  String get tapbackPoop => 'Какашка';

  @override
  String get tapbackQuestion => 'Вопрос';

  @override
  String get tapbackExclamation => 'Восклицание';

  @override
  String get tapbackHaha => 'ХаХа';

  @override
  String get tapbackThumbsDown => 'Не нравится';

  @override
  String get tapbackThumbsUp => 'Нравится';

  @override
  String get tapbackHeart => 'Сердце';

  @override
  String get tapbackWave => 'Привет';

  @override
  String get cannedResponseThanks => 'Спасибо!';

  @override
  String get cannedResponseWaitForMe => 'Подождите меня';

  @override
  String get cannedResponseImSafe => 'Я в безопасности';

  @override
  String get cannedResponseNeedHelp => 'Нужна помощь';

  @override
  String get cannedResponseOnMyWay => 'Уже иду';

  @override
  String get cannedResponseNo => 'Нет';

  @override
  String get cannedResponseYes => 'Да';

  @override
  String get cannedResponseOk => 'Хорошо';

  @override
  String get deepLinkUnableToOpenLink => 'Не удалось открыть ссылку';

  @override
  String get deepLinkInvalidLegalDocumentLink =>
      'Недействительная ссылка на правовой документ';

  @override
  String get deepLinkInvalidAetherFlightLink =>
      'Недействительная ссылка на полёт Aether';

  @override
  String get deepLinkInvalidAutomationLink =>
      'Недействительная ссылка на автоматизацию';

  @override
  String get deepLinkInvalidLocationCoordinates =>
      'Недействительные координаты местоположения';

  @override
  String get deepLinkInvalidPostLink => 'Недействительная ссылка на публикацию';

  @override
  String get deepLinkInvalidWidgetLink => 'Недействительная ссылка на виджет';

  @override
  String get deepLinkInvalidProfileLink => 'Недействительная ссылка на профиль';

  @override
  String get deepLinkSignInToJoinChannel =>
      'Войдите для присоединения к этому каналу';

  @override
  String get deepLinkInvalidInviteLink =>
      'Недействительная или неполная ссылка-приглашение';

  @override
  String get deepLinkInvalidChannelData => 'Недействительные данные канала';

  @override
  String get deepLinkConnectToImportChannel =>
      'Подключите устройство для импорта этого канала';

  @override
  String get deepLinkUnableToLoadNode => 'Не удалось загрузить данные ноды';

  @override
  String get deepLinkNodeAddedSuccess => 'Нода успешно добавлена';

  @override
  String get lifecycleActionCancelled => 'Действие отменено';

  @override
  String get lifecycleActionExpiredBackground =>
      'Действие истекло, пока приложение было в фоне';

  @override
  String get lifecycleActionCancelledBackground =>
      'Действие отменено — приложение в фоновом режиме';

  @override
  String get commandErrorCheckInternet => 'Проверьте подключение к интернету';

  @override
  String get commandErrorWaitingConfig => 'Ожидание конфигурации устройства';

  @override
  String get commandErrorConnectDevice =>
      'Подключите устройство для использования этой функции';

  @override
  String get sipBadgeLabel => 'Socialmesh';

  @override
  String get sipIdentityStateUnverified => 'Unverified';

  @override
  String get sipIdentityStateVerifiedTofu => 'Verified (TOFU)';

  @override
  String get sipIdentityStatePinned => 'Pinned';

  @override
  String get sipIdentityStateChangedKey => 'Key Changed';

  @override
  String get sipIdentityStateStale => 'Expired';

  @override
  String get sipChangedKeyWarning =>
      'This peer\'s identity key has changed. Verify before trusting.';

  @override
  String get sipDisplayNameLabel => 'SIP Name';

  @override
  String get sipPersonaIdLabel => 'Persona ID';

  @override
  String get sipDiscoveryTitle => 'Socialmesh Discovery';

  @override
  String sipDiscoveryPeersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'peers',
      one: 'peer',
    );
    return '$count Socialmesh $_temp0 nearby';
  }

  @override
  String get sipDiscoveryNoPeers => 'No Socialmesh peers detected';

  @override
  String get sipDiscoveryNoPeersDescription =>
      'Socialmesh peers will appear here when detected via beacon or rollcall.';

  @override
  String get sipDiscoveryScanButton => 'Scan for Socialmesh';

  @override
  String sipDiscoveryScanCooldown(int seconds) {
    return 'Scan available in ${seconds}s';
  }

  @override
  String get sipDiscoveryPeerAnonymous => 'SIP Peer';

  @override
  String sipDiscoveryDeviceClass(String deviceClass) {
    return 'Device class: $deviceClass';
  }

  @override
  String get sipHandshakeAction => 'Handshake';

  @override
  String get sipHandshakeInProgress => 'Handshake in progress…';

  @override
  String get sipHandshakeComplete => 'Handshake complete';

  @override
  String get sipHandshakeFailed => 'Handshake failed';

  @override
  String get sipHandshakePendingLabel => 'Request Pending';

  @override
  String get sipRequestIdentity => 'Request Identity';

  @override
  String get sipShareIdentity => 'Share Identity';

  @override
  String get sipDmTitle => 'Ephemeral DM';

  @override
  String sipDmExpiry(String time) {
    return 'Expires in $time';
  }

  @override
  String get sipDmPinned => 'Session pinned';

  @override
  String get sipDmInputHint => 'Message…';

  @override
  String get sipDmSendButton => 'Send';

  @override
  String get sipDmEmptyState => 'No messages yet';

  @override
  String get sipDmEmptyDescription =>
      'Send a message to start the conversation.';

  @override
  String get sipDmBudgetExhausted =>
      'Airtime budget exhausted. Try again later.';

  @override
  String get sipDmSessionClosed => 'This session has been closed.';

  @override
  String get sipDmPinAction => 'Pin Session';

  @override
  String get sipDmUnpinAction => 'Unpin Session';

  @override
  String get sipDmCloseAction => 'Close Session';

  @override
  String get sipDmOpenAction => 'Open DM';

  @override
  String get sipPeerDetailTitle => 'Peer Details';

  @override
  String get sipPeerDetailNodeId => 'Node ID';

  @override
  String get sipPeerDetailDeviceClass => 'Device Class';

  @override
  String get sipPeerDetailFeatures => 'Features';

  @override
  String get sipPeerDetailMtu => 'MTU Hint';

  @override
  String get sipPeerDetailLastSeen => 'Last Seen';

  @override
  String get sipPeerDetailJustNow => 'Just now';

  @override
  String sipPeerDetailMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'minutes',
      one: 'minute',
    );
    return '$count $_temp0 ago';
  }

  @override
  String sipPeerDetailHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hours',
      one: 'hour',
    );
    return '$count $_temp0 ago';
  }

  @override
  String get sipPeerDetailSupportsSip1 => 'Identity & Handshake';

  @override
  String get sipPeerDetailSupportsSip3 => 'Micro-Exchange';

  @override
  String get sipPeerDetailCapabilities => 'Capabilities';

  @override
  String get sipCountersTitle => 'SIP Debug Counters';

  @override
  String get sipHubTitle => 'Socialmesh';

  @override
  String get sipHubSectionPeers => 'Nearby Peers';

  @override
  String get sipHubSectionConversations => 'Conversations';

  @override
  String get sipHubSectionIncomingRequests => 'Incoming Requests';

  @override
  String sipHubIncomingRequestFrom(String peerName) {
    return '$peerName wants to connect';
  }

  @override
  String get sipHubAccept => 'Accept';

  @override
  String get sipHubDecline => 'Decline';

  @override
  String get sipHubEmptyTitle => 'No peers nearby';

  @override
  String get sipHubEmptyDescription =>
      'Tap Scan to look for other Socialmesh users on the mesh.';

  @override
  String get sipHubScanningTitlePrefix => 'No peers ';

  @override
  String get sipHubScanningTitleKeyword => 'nearby';

  @override
  String get sipHubScanningTitleSuffix => '';

  @override
  String get sipHubScanningTagline1 =>
      'Listens for Socialmesh beacons over the radio mesh';

  @override
  String get sipHubScanningTagline2 =>
      'Tap Scan to send a rollcall — wakes up nearby peers';

  @override
  String get sipHubScanningTagline3 =>
      'Peers respond anonymously — no account needed';

  @override
  String get sipHubScanningTagline4 =>
      'Found one? Initiate a handshake to start chatting';

  @override
  String get sipHubHelp => 'Help';

  @override
  String get helpSipHubOverviewTitle => 'Socialmesh';

  @override
  String get helpSipHubOverviewDescription =>
      'Discover and chat with nearby Socialmesh peers';

  @override
  String get helpSipHubIntroBubble =>
      'Welcome to **Socialmesh**! This is your peer discovery hub. Nearby devices running Socialmesh appear here once they beacon or respond to a rollcall.';

  @override
  String get helpSipHubScanBubble =>
      'Tap the **scan icon** to send a rollcall request. Nearby peers will respond within seconds. Auto-scan fires every 60 seconds in the background.';

  @override
  String get helpSipHubHandshakeBubble =>
      'Once you see a peer, tap **Handshake** to exchange identity. After the handshake you can open an **end-to-end encrypted** ephemeral DM — no servers, no accounts.';

  @override
  String get helpSipHubPrivacyBubble =>
      'All discovery is **anonymous by default**. Peers only reveal a rotating 4-byte ambient ID until you mutually agree to a handshake.';

  @override
  String sipHubLastSeen(String time) {
    return 'Seen $time';
  }

  @override
  String get sipHubHandshaking => 'Handshaking…';

  @override
  String get sipHubReady => 'Ready to chat';

  @override
  String get sipHubConnected => 'Connected';

  @override
  String sipHubMessagePreview(String name, String message) {
    return '$name: $message';
  }

  @override
  String sipHubSessionExpiry(String time) {
    return 'Expires in $time';
  }

  @override
  String get sipHubSessionPinned => 'Pinned';

  @override
  String get sipHubNoMessages => 'No messages yet';

  @override
  String sipDmPeerName(String hexId) {
    return 'Peer $hexId';
  }

  @override
  String get sipAutoScanEnabled => 'Auto-scan enabled';

  @override
  String get sipAutoScanDisabled => 'Auto-scan disabled';

  @override
  String get sipAutoScanToggle => 'Auto-scan';

  @override
  String get sipScanningIndicator => 'Scanning…';

  @override
  String get sipConnecting => 'Connecting…';

  @override
  String get sipDmReplyingTo => 'Replying to';

  @override
  String get sipDmSwipeToReply => 'Swipe to reply';

  @override
  String get sipDmActionReply => 'Reply';

  @override
  String get sipDmActionCopy => 'Copy';

  @override
  String get sipDmActionDelete => 'Delete';

  @override
  String get sipDmMessageCopied => 'Message copied';

  @override
  String get sipDmDeleteConfirmTitle => 'Delete message?';

  @override
  String get sipDmDeleteConfirmMessage =>
      'This will delete the message for both you and the recipient.';

  @override
  String notificationSipDmTitle(String peerName) {
    return '$peerName';
  }

  @override
  String get notificationSipHandshakeTitle => 'Secure Chat Ready';

  @override
  String notificationSipHandshakeBody(String peerName) {
    return 'You can now send private messages with $peerName.';
  }

  @override
  String get notificationChannelSipMessages => 'Ephemeral Messages';

  @override
  String get notificationChannelSipHandshake => 'Connection Requests';

  @override
  String get notificationSipHandshakeRequestTitle => 'Chat Request';

  @override
  String notificationSipHandshakeRequestBody(String peerName) {
    return '$peerName wants to start a private chat.';
  }

  @override
  String get notificationSipHandshakeDeclinedTitle => 'Connection Declined';

  @override
  String notificationSipHandshakeDeclinedBody(String peerName) {
    return '$peerName declined your connection request.';
  }

  @override
  String get mrrpHarnessTitle => 'Protocol Harness';

  @override
  String get mrrpHarnessDrawerLabel => 'Protocol Harness';

  @override
  String get mrrpHarnessStatusSip => 'SIP';

  @override
  String get mrrpHarnessStatusMrrp => 'MRRP';

  @override
  String get mrrpHarnessStatusEnabled => 'Enabled';

  @override
  String get mrrpHarnessStatusDisabled => 'Disabled';

  @override
  String get mrrpHarnessRadioState => 'Radio';

  @override
  String get mrrpHarnessRadioConnected => 'Connected';

  @override
  String get mrrpHarnessRadioDisconnected => 'Disconnected';

  @override
  String get mrrpHarnessChannel => 'Channel';

  @override
  String get mrrpHarnessChannelNone => 'No channel';

  @override
  String get mrrpHarnessSipPeers => 'SIP Peers';

  @override
  String get mrrpHarnessMrrpServices => 'MRRP Services';

  @override
  String get mrrpHarnessBudget => 'Budget';

  @override
  String mrrpHarnessBudgetValue(int remaining, int capacity) {
    return '$remaining/$capacity bytes';
  }

  @override
  String get mrrpHarnessScanPeers => 'Scan for Peers';

  @override
  String get mrrpHarnessBrowseServices => 'Browse Services';

  @override
  String get mrrpHarnessOpenComposer => 'Open Composer';

  @override
  String get mrrpHarnessOpenTraffic => 'Traffic Console';

  @override
  String get mrrpHarnessSectionStatus => 'Protocol Status';

  @override
  String get mrrpHarnessSectionActions => 'Quick Actions';

  @override
  String get mrrpHarnessPeerInspectorTitle => 'Peer Inspector';

  @override
  String mrrpHarnessPeerServices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'services',
      one: 'service',
    );
    return '$count $_temp0';
  }

  @override
  String mrrpHarnessPeerLastAdvert(String time) {
    return 'Last advert: $time';
  }

  @override
  String get mrrpHarnessRefreshDirectory => 'Refresh Directory';

  @override
  String get mrrpHarnessServiceBrowserTitle => 'Service Browser';

  @override
  String mrrpHarnessServiceVersion(int major, int minor) {
    return 'v$major.$minor';
  }

  @override
  String mrrpHarnessServiceFlags(String flags) {
    return 'Flags: $flags';
  }

  @override
  String get mrrpHarnessRawHex => 'Raw hex';

  @override
  String get mrrpHarnessComposerTitle => 'Request Composer';

  @override
  String get mrrpHarnessSelectPeer => 'Select peer';

  @override
  String get mrrpHarnessSelectService => 'Select service';

  @override
  String get mrrpHarnessSelectAction => 'Select action';

  @override
  String get mrrpHarnessPayloadPreset => 'Payload preset';

  @override
  String get mrrpHarnessPayloadRawHex => 'Raw hex payload';

  @override
  String get mrrpHarnessRequestTtl => 'Request TTL';

  @override
  String mrrpHarnessEncodedSize(int size) {
    return '$size bytes encoded';
  }

  @override
  String get mrrpHarnessSend => 'Send';

  @override
  String get mrrpHarnessResponseTitle => 'Response';

  @override
  String get mrrpHarnessResponsePending => 'Waiting for response…';

  @override
  String get mrrpHarnessResponseTimeout => 'Request timed out';

  @override
  String mrrpHarnessResponseStatus(String status) {
    return 'Status: $status';
  }

  @override
  String mrrpHarnessResponseLatency(int ms) {
    return 'Latency: ${ms}ms';
  }

  @override
  String get mrrpHarnessResponseDuplicate => 'Duplicate response';

  @override
  String get mrrpHarnessResponseCached => 'Cached response';

  @override
  String get mrrpHarnessSimLabTitle => 'Simulated Peer Lab';

  @override
  String get mrrpHarnessSimCreate => 'Create Simulated Peer';

  @override
  String get mrrpHarnessSimBadge => 'SIM';

  @override
  String get mrrpHarnessSimResponseMode => 'Response mode';

  @override
  String get mrrpHarnessSimModeNormal => 'Normal';

  @override
  String get mrrpHarnessSimModeDelayed => 'Delayed';

  @override
  String get mrrpHarnessSimModeError => 'Error';

  @override
  String get mrrpHarnessSimModeTimeout => 'Timeout';

  @override
  String get mrrpHarnessSimModeDuplicate => 'Duplicate';

  @override
  String get mrrpHarnessSimModeMalformed => 'Malformed';

  @override
  String get mrrpHarnessSimMaxPeers => 'Maximum 4 simulated peers';

  @override
  String get mrrpHarnessSimDeleteConfirm => 'Delete simulated peer?';

  @override
  String get mrrpHarnessSimServices => 'Services';

  @override
  String get mrrpHarnessSimDelay => 'Delay (seconds)';

  @override
  String get mrrpHarnessSimErrorCode => 'Error status code';

  @override
  String get mrrpHarnessTrafficTitle => 'Traffic Console';

  @override
  String get mrrpHarnessTrafficEmpty => 'No MRRP traffic yet';

  @override
  String get mrrpHarnessTrafficEmptyDescription =>
      'MRRP events will appear here as traffic flows.';

  @override
  String get mrrpHarnessTrafficFilterPeer => 'Filter by peer';

  @override
  String get mrrpHarnessTrafficFilterType => 'Filter by type';

  @override
  String get mrrpHarnessTrafficFilterService => 'Filter by service';

  @override
  String get mrrpHarnessTrafficFilterAll => 'All';

  @override
  String get mrrpHarnessTrafficFilterRequest => 'Request';

  @override
  String get mrrpHarnessTrafficFilterResponse => 'Response';

  @override
  String get mrrpHarnessTrafficFilterError => 'Error';

  @override
  String get mrrpHarnessTrafficFilterCancel => 'Cancel';

  @override
  String get mrrpHarnessTrafficFilterAdvert => 'Advert';

  @override
  String get mrrpHarnessTrafficFilterDirReq => 'Dir Req';

  @override
  String get mrrpHarnessTrafficFilterDirResp => 'Dir Resp';

  @override
  String get mrrpHarnessTrafficSearchHint => 'Search events...';

  @override
  String get mrrpHarnessComposerInfoText =>
      'Select a discovered peer, service, and action to compose an MRRP request frame. The payload field accepts raw hex bytes.';

  @override
  String get mrrpHarnessComposerSectionTarget => 'TARGET';

  @override
  String get mrrpHarnessComposerSectionPayload => 'PAYLOAD';

  @override
  String get mrrpHarnessSimLabInfoText =>
      'Create virtual MRRP peers for testing. Each peer advertises echo.test and can simulate different response modes including delays, errors, and malformed data.';

  @override
  String get mrrpHarnessResponseSectionRequest => 'REQUEST';

  @override
  String get mrrpHarnessResponseSectionResult => 'RESULT';

  @override
  String get mrrpHarnessPeerInspectorInfoText =>
      'Discovered peers advertising MRRP services over SIP. Expand a peer to view its service directory and test requests.';

  @override
  String get mrrpHarnessTrafficCopy => 'Copy event';

  @override
  String get mrrpHarnessTrafficExport => 'Export events';

  @override
  String mrrpHarnessTrafficDirection(String direction) {
    return '$direction';
  }

  @override
  String get mrrpHarnessBudgetTitle => 'Budget & Timing';

  @override
  String get mrrpHarnessBudgetRemaining => 'Remaining budget';

  @override
  String get mrrpHarnessBudgetBlocked => 'Sends blocked';

  @override
  String get mrrpHarnessBudgetDedupHits => 'Dedup hits';

  @override
  String get mrrpHarnessBudgetTimeouts => 'Timeouts';

  @override
  String get mrrpHarnessBudgetAdvertCadence => 'Advert cadence';

  @override
  String get mrrpHarnessBudgetLatency => 'Latency';

  @override
  String get mrrpHarnessNoPeers => 'No MRRP peers discovered';

  @override
  String get mrrpHarnessNoPeersDescription =>
      'MRRP-capable peers will appear here when discovered.';

  @override
  String get mrrpHarnessNoServices => 'No services';

  @override
  String get mrrpHarnessTestRequest => 'Test Request';

  @override
  String get mrrpHarnessOpenSimLab => 'Simulated Peers';

  @override
  String get mrrpHarnessOpenFixtures => 'Fixture Replay';

  @override
  String get mrrpHarnessFixtureTitle => 'Fixture Replay';

  @override
  String get mrrpHarnessFixtureVectors => 'Test Vectors';

  @override
  String get mrrpHarnessFixtureFuzz => 'Fuzz Cases';

  @override
  String get mrrpHarnessFixtureReplay => 'Replay';

  @override
  String get mrrpHarnessFixtureReplayAll => 'Replay All';

  @override
  String get mrrpHarnessFixturePass => 'PASS';

  @override
  String get mrrpHarnessFixtureFail => 'FAIL';

  @override
  String get mrrpHarnessFixtureDecodeNull => 'Decode returned null';

  @override
  String get mrrpHarnessFixtureDecodeOk => 'Decode OK';

  @override
  String get mrrpHarnessFixtureExpected => 'Expected';

  @override
  String get mrrpHarnessFixtureActual => 'Actual';

  @override
  String mrrpHarnessFixtureSummary(int passed, int total) {
    return '$passed/$total passed';
  }

  @override
  String mrrpHarnessFixtureBytes(int count) {
    return '$count bytes';
  }

  @override
  String mrrpHarnessFixtureFieldsMatch(int matched, int total) {
    return '$matched/$total fields match';
  }

  @override
  String get mrrpHarnessFixtureRejected => 'Rejected (expected)';

  @override
  String get mrrpHarnessFixtureNotRejected => 'Not rejected (unexpected)';

  @override
  String get mrrpHarnessFixtureEmpty => 'No fixtures available';

  @override
  String get mrrpHarnessOpenQaRunner => 'QA Scenarios';

  @override
  String get mrrpHarnessQaTitle => 'QA Scenario Runner';

  @override
  String get mrrpHarnessQaScenarios => 'Scenarios';

  @override
  String get mrrpHarnessQaRunAll => 'Run All';

  @override
  String mrrpHarnessQaSteps(int count) {
    return '$count steps';
  }

  @override
  String get mrrpHarnessQaRunScenario => 'Run';

  @override
  String get mrrpHarnessQaStepPass => 'PASS';

  @override
  String get mrrpHarnessQaStepFail => 'FAIL';

  @override
  String get mrrpHarnessQaStepPending => 'Pending';

  @override
  String get mrrpHarnessQaScenarioPass => 'PASSED';

  @override
  String get mrrpHarnessQaScenarioFail => 'FAILED';

  @override
  String mrrpHarnessQaSummary(int passed, int total) {
    return '$passed/$total scenarios passed';
  }

  @override
  String get mrrpHarnessQaEmpty => 'No scenarios defined';

  @override
  String get mrrpHarnessQaRunning => 'Running...';

  @override
  String get mrrpHarnessQaExpected => 'Expected';

  @override
  String get mrrpHarnessQaActual => 'Actual';

  @override
  String get mrrpHarnessCountersSectionTraffic => 'Traffic Counters';

  @override
  String get mrrpHarnessCountersSectionDedup => 'Dedup & Cache';

  @override
  String get mrrpHarnessCountersSectionErrors => 'Errors & Rejections';

  @override
  String get mrrpHarnessCountersSectionHarness => 'Harness Activity';

  @override
  String get mrrpHarnessCountersReqSent => 'Requests Sent';

  @override
  String get mrrpHarnessCountersReqRecv => 'Requests Received';

  @override
  String get mrrpHarnessCountersRespSent => 'Responses Sent';

  @override
  String get mrrpHarnessCountersRespRecv => 'Responses Received';

  @override
  String get mrrpHarnessCountersDirReqSent => 'Dir Requests Sent';

  @override
  String get mrrpHarnessCountersDirReqRecv => 'Dir Requests Received';

  @override
  String get mrrpHarnessCountersDirRespSent => 'Dir Responses Sent';

  @override
  String get mrrpHarnessCountersDirRespRecv => 'Dir Responses Received';

  @override
  String get mrrpHarnessCountersDupReq => 'Duplicate Requests Ignored';

  @override
  String get mrrpHarnessCountersDupResp => 'Duplicate Responses Ignored';

  @override
  String get mrrpHarnessCountersCachedResp => 'Cached Responses Served';

  @override
  String get mrrpHarnessCountersReqTimeouts => 'Request Timeouts';

  @override
  String get mrrpHarnessCountersRespTimeouts => 'Response Timeouts';

  @override
  String get mrrpHarnessCountersCancellations => 'Cancellations';

  @override
  String get mrrpHarnessCountersErrSent => 'Errors Sent';

  @override
  String get mrrpHarnessCountersErrRecv => 'Errors Received';

  @override
  String get mrrpHarnessCountersPayloadReject => 'Payload Too Large';

  @override
  String get mrrpHarnessCountersHarnessActions => 'Harness Actions';

  @override
  String get mrrpHarnessCountersSimFaults => 'Simulated Faults';

  @override
  String get meshExplorerTitle => 'Mesh Explorer';

  @override
  String get meshExplorerDrawerLabel => 'Mesh Explorer';

  @override
  String get meshExplorerHeroConnected => 'Connected to mesh';

  @override
  String get meshExplorerHeroDisconnected => 'No radio connected';

  @override
  String meshExplorerHeroPeersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nearby peers',
      one: '1 nearby peer',
      zero: 'No nearby peers',
    );
    return '$_temp0';
  }

  @override
  String meshExplorerHeroServicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count services',
      one: '1 service',
      zero: 'No services',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerSectionNearby => 'Nearby';

  @override
  String get meshExplorerSectionServices => 'Services';

  @override
  String get meshExplorerSectionBoard => 'Board Activity';

  @override
  String get meshExplorerScanningTitlePrefix => 'No peers ';

  @override
  String get meshExplorerScanningTitleKeyword => 'nearby';

  @override
  String get meshExplorerScanningTitleSuffix => '';

  @override
  String get meshExplorerScanningTagline1 =>
      'Scans for Socialmesh peers broadcasting on the mesh';

  @override
  String get meshExplorerScanningTagline2 =>
      'Tap Scan to send a rollcall — wakes up nearby peers';

  @override
  String get meshExplorerScanningTagline3 =>
      'Peers appear anonymously — handshake to identify them';

  @override
  String get meshExplorerScanningTagline4 =>
      'Radio range matters — try moving closer to the mesh';

  @override
  String get meshExplorerHelp => 'Help';

  @override
  String get helpMeshExplorerOverviewTitle => 'Mesh Explorer';

  @override
  String get helpMeshExplorerOverviewDescription =>
      'Explore nearby peers and mesh services';

  @override
  String get helpMeshExplorerIntroBubble =>
      'Welcome to **Mesh Explorer**! This shows all Socialmesh-capable peers currently in radio range. Anonymous peers appear instantly — no handshake needed.';

  @override
  String get helpMeshExplorerPeersBubble =>
      'Each tile shows a **peer\'s ambient sigil** and capabilities. Tap a peer to view details or initiate a **SIP handshake** for identity exchange.';

  @override
  String get helpMeshExplorerServicesBubble =>
      'The **Services** section shows what nearby peers are offering — Bulletin Boards, Profiles, and more. Tap a service tile to interact with it.';

  @override
  String get helpMeshExplorerScanBubble =>
      'Tap the **sensor icon** to broadcast a rollcall to the mesh. Peers respond within seconds. The explorer refreshes automatically when new peers are heard.';

  @override
  String get meshExplorerScanningAction => 'Scan now';

  @override
  String get notificationSipPeerFoundTitle => 'Peer found nearby';

  @override
  String get notificationSipPeerFoundBody =>
      'A Socialmesh peer is in range. Open Mesh Explorer to connect.';

  @override
  String get notificationChannelSipDiscovery => 'Peer Discovery';

  @override
  String get meshExplorerEmptyNearbyTitle => 'No nearby peers';

  @override
  String get meshExplorerEmptyNearbyBody =>
      'Peers will appear when mesh devices are in range';

  @override
  String get meshExplorerEmptyServicesTitle => 'No services found';

  @override
  String get meshExplorerEmptyServicesBody =>
      'Nearby peers will advertise services here';

  @override
  String get meshExplorerEmptyBoardTitle => 'No board activity';

  @override
  String get meshExplorerEmptyBoardBody =>
      'Board posts from nearby peers will appear here';

  @override
  String get nearbyActivitySectionTitle => 'Activity';

  @override
  String get nearbyActivityEmptyTitle => 'No recent activity';

  @override
  String get nearbyActivityEmptyBody =>
      'Nearby services and signals will appear here';

  @override
  String get meshExplorerNotConnectedTitle => 'Radio not connected';

  @override
  String get meshExplorerNotConnectedBody =>
      'Connect a Meshtastic radio to discover the mesh around you';

  @override
  String get meshExplorerPeerAnonymous => 'Nearby peer';

  @override
  String get meshExplorerPeerHandshaked => 'Handshaked';

  @override
  String get meshExplorerPeerVerified => 'Verified';

  @override
  String get meshExplorerPeerPinned => 'Pinned';

  @override
  String meshExplorerHopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hops',
      one: '1 hop',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerHopCountFar => '3+ hops';

  @override
  String meshExplorerServiceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count services',
      one: '1 service',
      zero: 'No services',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerActionHandshake => 'Handshake';

  @override
  String get meshExplorerActionView => 'View';

  @override
  String get meshExplorerActionRequestIdentity => 'Request Identity';

  @override
  String get meshExplorerActionOpenNodeDex => 'Open in NodeDex';

  @override
  String get meshExplorerActionBlock => 'Block';

  @override
  String get meshExplorerActionPin => 'Pin Peer';

  @override
  String get meshExplorerActionUnpin => 'Unpin Peer';

  @override
  String get meshExplorerPeerDetail => 'Peer Detail';

  @override
  String get meshExplorerPeerDetailIdentity => 'Identity';

  @override
  String get meshExplorerPeerDetailServices => 'Available Services';

  @override
  String get meshExplorerPeerDetailActions => 'Actions';

  @override
  String get meshExplorerServiceBulletinBoard => 'Bulletin Board';

  @override
  String get meshExplorerServiceBulletinBoardSub => 'Local mesh posts';

  @override
  String get meshExplorerServicePeerProfile => 'Peer Profile';

  @override
  String get meshExplorerServicePeerProfileSub => 'Shared identity info';

  @override
  String get meshExplorerServiceGeneric => 'Service';

  @override
  String get meshExplorerServiceGenericSub => 'Available nearby';

  @override
  String get meshExplorerServiceOpenBoard => 'Open Board';

  @override
  String get meshExplorerServiceViewProfile => 'View Profile';

  @override
  String get meshExplorerServiceDetails => 'Details';

  @override
  String get meshExplorerServiceRequiresHandshake => 'Requires handshake';

  @override
  String get meshExplorerServiceRequiresIdentity => 'Requires identity';

  @override
  String meshExplorerServicePeerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peers',
      one: '1 peer',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerPrivacyTitle => 'Mesh Privacy';

  @override
  String get meshExplorerPrivacySectionVisibility => 'Visibility';

  @override
  String get meshExplorerPrivacySectionSharing => 'Sharing';

  @override
  String get meshExplorerPrivacySectionActions => 'Actions';

  @override
  String get meshExplorerPrivacyDiscoverable => 'Discoverable';

  @override
  String get meshExplorerPrivacyDiscoverableSub =>
      'Broadcast your presence to nearby mesh peers';

  @override
  String get meshExplorerPrivacyProfileSharing => 'Profile Sharing';

  @override
  String get meshExplorerPrivacyProfileSharingSub =>
      'Respond to profile requests from peers';

  @override
  String get meshExplorerPrivacyDmAvailable => 'Direct Messages';

  @override
  String get meshExplorerPrivacyDmAvailableSub =>
      'Allow direct messages from identified peers';

  @override
  String get meshExplorerPrivacyClearCache => 'Clear Nearby Cache';

  @override
  String get meshExplorerPrivacyClearCacheSub =>
      'Remove all discovered nearby peer data';

  @override
  String get meshExplorerPrivacyCacheCleared => 'Nearby cache cleared';

  @override
  String get meshExplorerScanAction => 'Scan';

  @override
  String get meshExplorerRefreshAction => 'Refresh';

  @override
  String get meshExplorerChangedKey => 'Changed key';

  @override
  String get meshExplorerScanSent => 'Scanning for nearby peers…';

  @override
  String get meshExplorerScanCooldown => 'Mesh is busy, scan blocked';

  @override
  String get meshExplorerHandshakeSent => 'Handshake request sent';

  @override
  String get meshExplorerHandshakeCooldown =>
      'Handshake on cooldown, try again shortly';

  @override
  String get meshExplorerHandshakeInProgress => 'In progress…';

  @override
  String get meshServicesDrawerLabel => 'My Services';

  @override
  String get meshServicesTitle => 'My Services';

  @override
  String get meshServicesEmpty => 'No services yet';

  @override
  String get meshServicesEmptyDescription =>
      'Create a service to share something useful on the mesh';

  @override
  String get meshServicesCreateAction => 'Create Service';

  @override
  String get meshServicesCreateTitle => 'Create a Service';

  @override
  String get meshServicesCreateSubtitle =>
      'Choose what you want to share on the mesh';

  @override
  String get meshServicesTemplateBoard => 'Bulletin Board';

  @override
  String get meshServicesTemplateBoardDescription =>
      'Share short posts with nearby peers';

  @override
  String get meshServicesTemplateSignal => 'Signal Beacon';

  @override
  String get meshServicesTemplateSignalDescription =>
      'Broadcast a signal to nearby peers';

  @override
  String get meshServicesTemplatePoll => 'Quick Poll';

  @override
  String get meshServicesTemplatePollDescription =>
      'Ask a question with multiple choice answers';

  @override
  String get meshServicesTemplateChecklist => 'Shared Checklist';

  @override
  String get meshServicesTemplateChecklistDescription =>
      'Collaborate on a checklist with nearby peers';

  @override
  String get meshServicesTemplateResourceList => 'Resource List';

  @override
  String get meshServicesTemplateResourceListDescription =>
      'Share a list of useful resources or supplies';

  @override
  String get meshServicesTemplateWeatherStation => 'Weather Station';

  @override
  String get meshServicesTemplateWeatherStationDescription =>
      'Share local weather readings with nearby peers';

  @override
  String get meshServicesTemplateSensorNode => 'Sensor Node';

  @override
  String get meshServicesTemplateSensorNodeDescription =>
      'Publish sensor data from a connected device';

  @override
  String get meshServicesTemplateTaskBoard => 'Task Board';

  @override
  String get meshServicesTemplateTaskBoardDescription =>
      'Coordinate tasks with nearby peers';

  @override
  String get meshServicesTemplateTrailConditions => 'Trail Conditions';

  @override
  String get meshServicesTemplateTrailConditionsDescription =>
      'Report trail and route conditions for others';

  @override
  String get meshServicesTemplateLostAndFound => 'Lost & Found';

  @override
  String get meshServicesTemplateLostAndFoundDescription =>
      'Post lost or found items for nearby peers';

  @override
  String get schemaFieldNoData => 'No data';

  @override
  String get schemaFieldEmptyList => 'Empty list';

  @override
  String schemaFieldMoreItems(int count) {
    return '$count more';
  }

  @override
  String get schemaFieldJustNow => 'Just now';

  @override
  String schemaFieldMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String schemaFieldHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String schemaFieldDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get serviceDetailUnknownTitle => 'Unknown Service';

  @override
  String serviceDetailUnknownBody(String serviceType) {
    return 'Service type \"$serviceType\" is not recognized by this version of the app.';
  }

  @override
  String get meshServicesFieldTitle => 'Title';

  @override
  String get meshServicesFieldDescription => 'Description';

  @override
  String get meshServicesDescriptionHint =>
      'Describe your service for other mesh users...';

  @override
  String get meshServicesFieldDuration => 'Duration';

  @override
  String get meshServicesFieldQuestion => 'Question';

  @override
  String meshServicesFieldOption(int index) {
    return 'Option $index';
  }

  @override
  String get meshServicesFieldAddOption => 'Add Option';

  @override
  String meshServicesFieldItem(int index) {
    return 'Item $index';
  }

  @override
  String get meshServicesFieldAddItem => 'Add Item';

  @override
  String get meshServicesPreviewTitle => 'Preview';

  @override
  String get meshServicesPreviewSubtitle =>
      'This is what nearby peers will see';

  @override
  String get meshServicesPublishAction => 'Publish';

  @override
  String get meshServicesPublishSuccess => 'Service published';

  @override
  String get meshServicesStatusActive => 'Active';

  @override
  String get meshServicesStatusStopped => 'Stopped';

  @override
  String get meshServicesStatusExpired => 'Expired';

  @override
  String get meshServicesStopAction => 'Stop';

  @override
  String get meshServicesDeleteAction => 'Delete';

  @override
  String get meshServicesActionsLabel => 'Actions';

  @override
  String get meshServicesStopConfirm =>
      'Stop this service? Nearby peers will no longer see it.';

  @override
  String get meshServicesDeleteConfirm =>
      'Delete this service? This cannot be undone.';

  @override
  String get meshServicesDetailTitle => 'Service Details';

  @override
  String meshServicesRemainingTime(String duration) {
    return '$duration remaining';
  }

  @override
  String meshServicesDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String meshServicesDurationHours(int count) {
    return '$count hr';
  }

  @override
  String get meshServicesTitleRequired => 'Title is required';

  @override
  String get meshServicesMinOptions => 'At least 2 options required';

  @override
  String get meshServicesMinItems => 'At least 1 item required';

  @override
  String get meshServicesConfirmAction => 'Confirm';

  @override
  String get meshServicesCancelAction => 'Cancel';

  @override
  String get meshServicesSearchHint => 'Search services';

  @override
  String get meshServicesFilterAll => 'All';

  @override
  String get meshServicesFilterActive => 'Active';

  @override
  String get meshServicesFilterExpired => 'Expired';

  @override
  String get meshServicesFilterStopped => 'Stopped';

  @override
  String get meshServicesNoResults => 'No matching services';

  @override
  String get mapTerrainProfile => 'Terrain Profile';

  @override
  String get mapTerrainProfileSubtitle =>
      'Elevation cross-section + LOS overlay';

  @override
  String get mapTerrainProfileTitle => 'Terrain Profile';

  @override
  String get mapTerrainProfileLoading => 'Fetching elevation data…';

  @override
  String get mapTerrainProfileOffline => 'Elevation data unavailable offline';

  @override
  String get mapTerrainProfileOfflineSubtitle =>
      'Connect to the internet to load terrain elevation.';

  @override
  String get mapTerrainProfileError => 'Could not load elevation data';

  @override
  String get mapTerrainProfileErrorSubtitle =>
      'Check your connection and try again.';

  @override
  String get mapTerrainProfileNeedsAltitude => 'LOS overlay unavailable';

  @override
  String get mapTerrainProfileNeedsAltitudeSubtitle =>
      'One or both nodes have no GPS altitude. Terrain profile is still shown.';

  @override
  String mapTerrainProfileSampleCount(int count) {
    return '$count elevation samples';
  }

  @override
  String mapTerrainLosVerdict(String verdict) {
    return 'Terrain LOS: $verdict';
  }

  @override
  String mapTerrainAdditionalClearance(String meters) {
    return 'Additional clearance needed: ${meters}m';
  }

  @override
  String get mapTerrainRetry => 'Retry';

  @override
  String terrainLosExplanationObstructed(String depth) {
    return 'Terrain obstructs path by ${depth}m at the worst point.';
  }

  @override
  String get terrainLosExplanationMarginal =>
      'Path clears terrain but Fresnel zone is partially obstructed. Signal may be degraded.';

  @override
  String get terrainLosExplanationClear =>
      'Clear LOS with ≥60% first Fresnel zone clearance throughout.';

  @override
  String get unitKm => 'km';

  @override
  String get unitM => 'm';

  @override
  String mapTerrainNodeAltitude(String value) {
    return '· ${value}m';
  }

  @override
  String mapTerrainEndpointLabel(String prefix, String name) {
    return '$prefix: $name';
  }

  @override
  String mapTerrainEndpointCoords(String prefix, String lat, String lon) {
    return '$prefix: $lat, $lon';
  }

  @override
  String get losVerdictClear => 'Clear';

  @override
  String get losVerdictMarginal => 'Marginal';

  @override
  String get losVerdictObstructed => 'Obstructed';

  @override
  String get losVerdictUnknown => 'Unknown';

  @override
  String get losExplanationNoAltitude =>
      'Altitude data unavailable for one or both points.';

  @override
  String losExplanationObstructed(String depth) {
    return 'Earth curvature obstructs the path by ${depth}m at midpoint. Terrain/obstacles not considered.';
  }

  @override
  String losExplanationClear(String clearance) {
    return 'Clear line of sight with ${clearance}m clearance above earth bulge. Terrain/obstacles not considered.';
  }

  @override
  String losExplanationMarginal(String clearance, String required) {
    return 'Marginal clearance (${clearance}m) — below the recommended ${required}m Fresnel clearance. Terrain/obstacles not considered.';
  }
}
