// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get adminProductsActivate => 'Ativar';

  @override
  String get adminProductsActive => 'Ativo';

  @override
  String get adminProductsActiveSubtitle => 'O produto está visível na loja';

  @override
  String get adminProductsAddImage => 'Adicionar imagem';

  @override
  String get adminProductsAddTitle => 'Adicionar produto';

  @override
  String get adminProductsAddTooltip => 'Adicionar produto';

  @override
  String get adminProductsAllCategories => 'Todas as categorias';

  @override
  String get adminProductsBasicInfoSection => 'Informações básicas';

  @override
  String get adminProductsBatteryHint => 'ex. 4000mAh';

  @override
  String get adminProductsBatteryLabel => 'Capacidade da bateria';

  @override
  String get adminProductsBluetooth => 'Bluetooth';

  @override
  String get adminProductsCategoryLabel => 'Categoria *';

  @override
  String get adminProductsCategorySellerSection => 'Categoria e vendedor';

  @override
  String get adminProductsChipsetHint => 'ex. ESP32-S3';

  @override
  String get adminProductsChipsetLabel => 'Chipset';

  @override
  String get adminProductsComparePriceHint => 'Preço original para promoção';

  @override
  String get adminProductsComparePriceLabel => 'Preço comparativo';

  @override
  String get adminProductsCreate => 'Criar produto';

  @override
  String get adminProductsCreated => 'Produto criado';

  @override
  String get adminProductsDeactivate => 'Desativar';

  @override
  String get adminProductsDelete => 'Excluir';

  @override
  String get adminProductsDeleteConfirmMessage =>
      'Tem certeza de que deseja excluir permanentemente este produto?';

  @override
  String get adminProductsDeleteConfirmTitle => 'Excluir produto';

  @override
  String get adminProductsDeleteMenu => 'Excluir';

  @override
  String adminProductsDeleteMessage(String name) {
    return 'Tem certeza de que deseja excluir permanentemente \"$name\"?\n\nEsta ação não pode ser desfeita.';
  }

  @override
  String get adminProductsDeleteTitle => 'Excluir produto';

  @override
  String get adminProductsDeleteTooltip => 'Excluir';

  @override
  String get adminProductsDeleted => 'Produto excluído';

  @override
  String get adminProductsDeletedSuccess => 'Produto excluído';

  @override
  String get adminProductsDimensionsHint => 'ex. 100x50x25mm';

  @override
  String get adminProductsDimensionsLabel => 'Dimensões';

  @override
  String get adminProductsDisplay => 'Ecrã';

  @override
  String get adminProductsEdit => 'Editar';

  @override
  String get adminProductsEditTitle => 'Editar produto';

  @override
  String adminProductsErrorLoadingSellers(String error) {
    return 'Erro ao carregar vendedores: $error';
  }

  @override
  String get adminProductsFeatured => 'Destaque';

  @override
  String get adminProductsFeaturedBadge => 'DESTAQUE';

  @override
  String get adminProductsFeaturedOrderHelper =>
      'Controla a ordem de exibição na seção de destaques';

  @override
  String get adminProductsFeaturedOrderHint =>
      'Números menores aparecem primeiro (0 = topo)';

  @override
  String get adminProductsFeaturedOrderLabel => 'Ordem de destaque';

  @override
  String get adminProductsFeaturedSubtitle =>
      'Exibir na seção de produtos em destaque';

  @override
  String get adminProductsFilterTooltip => 'Filtrar por categoria';

  @override
  String get adminProductsFrequencyBandsSection => 'Faixas de frequência';

  @override
  String get adminProductsFullDescHint => 'Descrição detalhada do produto';

  @override
  String get adminProductsFullDescLabel => 'Descrição completa *';

  @override
  String get adminProductsGps => 'GPS';

  @override
  String get adminProductsHideInactive => 'Ocultar inativos';

  @override
  String get adminProductsImageRequired => 'É necessária pelo menos uma imagem';

  @override
  String get adminProductsImageWarning => 'Adicione pelo menos uma imagem';

  @override
  String get adminProductsImagesSection => 'Imagens do produto';

  @override
  String get adminProductsInStock => 'Em estoque';

  @override
  String get adminProductsInactiveBadge => 'INATIVO';

  @override
  String get adminProductsInvalid => 'Inválido';

  @override
  String get adminProductsLoraChipHint => 'ex. SX1262';

  @override
  String get adminProductsLoraChipLabel => 'Chip LoRa';

  @override
  String get adminProductsMainImage => 'Principal';

  @override
  String get adminProductsNameHint => 'ex. T-Beam Supreme';

  @override
  String get adminProductsNameLabel => 'Nome do produto *';

  @override
  String get adminProductsNotFound => 'Nenhum produto encontrado';

  @override
  String get adminProductsPhysicalSpecsSection => 'Especificações físicas';

  @override
  String get adminProductsPriceLabel => 'Preço (USD) *';

  @override
  String get adminProductsPricingSection => 'Preços';

  @override
  String get adminProductsPurchaseLinkSection => 'Link de compra';

  @override
  String get adminProductsPurchaseUrlLabel => 'URL de compra';

  @override
  String get adminProductsRequired => 'Obrigatório';

  @override
  String get adminProductsSaveChanges => 'Salvar alterações';

  @override
  String get adminProductsSearchHint => 'Buscar produtos...';

  @override
  String get adminProductsSelectSeller => 'Selecionar vendedor';

  @override
  String get adminProductsSelectSellerWarning => 'Selecione um vendedor';

  @override
  String get adminProductsSellerLabel => 'Vendedor *';

  @override
  String get adminProductsShortDescHint => 'Resumo breve (máx. 150 caracteres)';

  @override
  String get adminProductsShortDescLabel => 'Descrição curta';

  @override
  String get adminProductsShowInactive => 'Mostrar inativos';

  @override
  String get adminProductsStockHint => 'Deixe vazio para ilimitado';

  @override
  String get adminProductsStockLabel => 'Quantidade em estoque';

  @override
  String get adminProductsStockSection => 'Estoque e status';

  @override
  String get adminProductsTagsHint =>
      'meshtastic, lora, gps (separados por vírgula)';

  @override
  String get adminProductsTagsLabel => 'Etiquetas';

  @override
  String get adminProductsTagsSection => 'Etiquetas';

  @override
  String get adminProductsTechSpecsSection => 'Especificações técnicas';

  @override
  String get adminProductsTitle => 'Gerenciar produtos';

  @override
  String get adminProductsUpdated => 'Produto atualizado';

  @override
  String get adminProductsUploading => 'Enviando...';

  @override
  String get adminProductsVendorUnverifiedSubtitle =>
      'Marque quando o vendedor confirmar que todas as especificações estão corretas';

  @override
  String get adminProductsVendorVerificationSection =>
      'Verificação do vendedor';

  @override
  String get adminProductsVendorVerifiedSubtitle =>
      'As especificações foram verificadas pelo vendedor';

  @override
  String get adminProductsVendorVerifiedTitle =>
      'Especificações verificadas pelo vendedor';

  @override
  String get adminProductsWeightHint => 'ex. 50g';

  @override
  String get adminProductsWeightLabel => 'Peso';

  @override
  String get adminProductsWifi => 'WiFi';

  @override
  String get adminSellersActivate => 'Ativar';

  @override
  String get adminSellersActive => 'Ativo';

  @override
  String get adminSellersActiveSubtitle => 'O vendedor está visível na loja';

  @override
  String get adminSellersAddTitle => 'Adicionar vendedor';

  @override
  String get adminSellersAddTooltip => 'Adicionar vendedor';

  @override
  String get adminSellersBasicInfoSection => 'Informações básicas';

  @override
  String get adminSellersCancel => 'Cancelar';

  @override
  String get adminSellersClearDiscount => 'Limpar código de desconto';

  @override
  String get adminSellersContactInfoSection => 'Informações de contato';

  @override
  String get adminSellersCountriesHint =>
      'US, CA, UK, DE (separados por vírgula)';

  @override
  String get adminSellersCountriesLabel => 'Países';

  @override
  String get adminSellersCreate => 'Criar vendedor';

  @override
  String get adminSellersCreated => 'Vendedor criado';

  @override
  String get adminSellersDangerZone => 'Zona de perigo';

  @override
  String get adminSellersDeactivate => 'Desativar';

  @override
  String get adminSellersDeleteConfirm => 'Excluir';

  @override
  String get adminSellersDeleteDescription =>
      'Exclui permanentemente este vendedor e desativa todos os seus produtos. Esta ação não pode ser desfeita.';

  @override
  String adminSellersDeleteDialogMessage(String name) {
    return 'Tem certeza de que deseja excluir permanentemente \"$name\"?';
  }

  @override
  String get adminSellersDeleteDialogTitle => 'Excluir vendedor';

  @override
  String get adminSellersDeletePermanently =>
      'Excluir vendedor permanentemente';

  @override
  String adminSellersDeleteProductWarning(int productCount) {
    return 'Este vendedor possui $productCount produtos. Excluir o vendedor também excluirá todos os seus produtos.';
  }

  @override
  String get adminSellersDeleteTitle => 'Excluir vendedor';

  @override
  String get adminSellersDeleteTooltip => 'Excluir vendedor';

  @override
  String get adminSellersDeleteUndoWarning =>
      'Esta ação não pode ser desfeita.';

  @override
  String get adminSellersDeleted => 'Vendedor excluído';

  @override
  String get adminSellersDescriptionHint => 'Breve descrição do vendedor';

  @override
  String get adminSellersDescriptionLabel => 'Descrição';

  @override
  String get adminSellersDiscountCodeHint => 'ex. MESH10';

  @override
  String get adminSellersDiscountCodeLabel => 'Código de desconto';

  @override
  String get adminSellersDiscountDisplayHint =>
      'ex. 10% de desconto para usuários Socialmesh';

  @override
  String get adminSellersDiscountDisplayLabel => 'Rótulo de exibição';

  @override
  String get adminSellersDiscountExpired => 'O código de desconto expirou';

  @override
  String get adminSellersDiscountExpiryLabel => 'Data de validade (opcional)';

  @override
  String get adminSellersDiscountNoExpiry => 'Sem validade';

  @override
  String get adminSellersDiscountSection => 'Código de desconto de parceiro';

  @override
  String get adminSellersDiscountTermsHint =>
      'ex. Não acumulável com outras ofertas';

  @override
  String get adminSellersDiscountTermsLabel => 'Termos e condições';

  @override
  String get adminSellersEdit => 'Editar';

  @override
  String get adminSellersEditTitle => 'Editar vendedor';

  @override
  String get adminSellersEmailHint => 'suporte@exemplo.com';

  @override
  String get adminSellersEmailLabel => 'E-mail de contato';

  @override
  String get adminSellersHideInactive => 'Ocultar inativos';

  @override
  String get adminSellersInactiveBadge => 'INATIVO';

  @override
  String get adminSellersLogoSection => 'Logo do vendedor';

  @override
  String get adminSellersNameHint => 'ex. LilyGO, RAK Wireless';

  @override
  String get adminSellersNameLabel => 'Nome do vendedor *';

  @override
  String get adminSellersNotFound => 'Nenhum vendedor encontrado';

  @override
  String get adminSellersOfficialPartner => 'Parceiro oficial';

  @override
  String get adminSellersOfficialPartnerSubtitle =>
      'Exibir como parceiro oficial Meshtastic';

  @override
  String get adminSellersPartnerBadge => 'PARCEIRO';

  @override
  String get adminSellersRemoveLogo => 'Remover';

  @override
  String get adminSellersSaveChanges => 'Salvar alterações';

  @override
  String get adminSellersSearchHint => 'Buscar vendedores...';

  @override
  String get adminSellersShippingSection => 'Países de envio';

  @override
  String get adminSellersShowInactive => 'Mostrar inativos';

  @override
  String get adminSellersStatusSection => 'Status e verificação';

  @override
  String get adminSellersTitle => 'Gerenciar vendedores';

  @override
  String get adminSellersUpdated => 'Vendedor atualizado';

  @override
  String get adminSellersUploadLogo => 'Enviar logo';

  @override
  String get adminSellersUploading => 'Enviando...';

  @override
  String get adminSellersVerifiedBadge => 'VERIFICADO';

  @override
  String get adminSellersVerifiedSubtitle =>
      'A identidade do vendedor foi verificada';

  @override
  String get adminSellersVerifiedToggle => 'Verificado';

  @override
  String get adminSellersWebsiteLabel => 'URL do site *';

  @override
  String get aetherDetailAltitude => 'Altitude';

  @override
  String get aetherDetailArrival => 'Chegada';

  @override
  String get aetherDetailCoverageRadius => 'Raio de cobertura';

  @override
  String get aetherDetailDeparture => 'Partida';

  @override
  String aetherDetailDistanceAway(int distance) {
    return '$distance km de distância';
  }

  @override
  String get aetherDetailFlightDetails => 'Detalhes do voo';

  @override
  String get aetherDetailGroundSpeed => 'Velocidade no solo';

  @override
  String get aetherDetailHeading => 'Direção';

  @override
  String get aetherDetailLivePosition => 'Posição em tempo real';

  @override
  String get aetherDetailNode => 'Nó';

  @override
  String get aetherDetailNotes => 'Notas';

  @override
  String get aetherDetailOperator => 'Operador';

  @override
  String get aetherDetailPositionUnavailable =>
      'Dados de posição indisponíveis';

  @override
  String get aetherDetailReceptions => 'Recepções';

  @override
  String aetherDetailReceptionsValue(int count) {
    return '$count reportadas';
  }

  @override
  String get aetherDetailRefreshTooltip => 'Atualizar posição';

  @override
  String get aetherDetailReportButton => 'Eu recebi este voo!';

  @override
  String get aetherDetailReportsError => 'Erro ao carregar relatórios';

  @override
  String get aetherDetailReportsTitle => 'Relatórios de recepção';

  @override
  String get aetherDetailShareCopied =>
      'Link do voo copiado para a área de transferência';

  @override
  String aetherDetailShareError(String error) {
    return 'Não foi possível compartilhar o voo: $error';
  }

  @override
  String get aetherDetailShareTooltip => 'Compartilhar voo';

  @override
  String get aetherDetailUnknownNode => 'Nó desconhecido';

  @override
  String aetherDetailUpdated(String time) {
    return 'Atualizado $time';
  }

  @override
  String get aetherDuplicateReport => 'Você já reportou este voo';

  @override
  String get aetherEmptyActionSchedule => 'Agendar voo';

  @override
  String get aetherEmptyActiveSubtitle =>
      'Nenhum nó Meshtastic no ar no momento.\nSeja o primeiro a agendar um!';

  @override
  String get aetherEmptyActiveTitle => 'Nenhum voo ativo';

  @override
  String get aetherEmptyAllSubtitle =>
      'Nenhum voo agendado ainda.\nSeja o primeiro a compartilhar sua jornada!';

  @override
  String get aetherEmptyAllTitle => 'Nenhum voo encontrado';

  @override
  String aetherErrorWithDetails(String error) {
    return 'Erro: $error';
  }

  @override
  String get aetherEmptyMyFlightsSubtitle =>
      'Você ainda não agendou nenhum voo.\nToque no botão acima para adicionar um!';

  @override
  String get aetherEmptyMyFlightsTitle => 'Nenhum voo agendado';

  @override
  String aetherEmptySearchSubtitle(String query) {
    return 'Nenhum resultado para \"$query\".\nTente um termo de busca diferente.';
  }

  @override
  String get aetherEmptyTagline1 =>
      'Nenhum voo agendado ainda.\nSeja o primeiro a compartilhar sua jornada aérea!';

  @override
  String get aetherEmptyTagline2 =>
      'Rastreie nós Meshtastic em altitude.\nVeja o alcance do seu sinal a partir do céu.';

  @override
  String get aetherEmptyTagline3 =>
      'Compita no ranking.\nContatos de maior alcance conquistam as primeiras posições.';

  @override
  String get aetherEmptyTagline4 =>
      'Agende seu próximo voo.\nCompartilhe seus aeroportos de partida e chegada.';

  @override
  String get aetherEmptyTitleKeyword => 'voos';

  @override
  String get aetherEmptyTitlePrefix => 'Nenhum ';

  @override
  String get aetherEmptyTitleSuffix => ' no ar';

  @override
  String get aetherEmptyUpcomingSubtitle =>
      'Nenhum voo agendado ainda.\nPlaneje seu próximo teste aéreo!';

  @override
  String get aetherEmptyUpcomingTitle => 'Nenhum voo programado';

  @override
  String get aetherFilterActive => 'Ativos';

  @override
  String get aetherFilterAll => 'Todos';

  @override
  String get aetherFilterMyFlights => 'Meus voos';

  @override
  String get aetherFilterUpcoming => 'Em breve';

  @override
  String get aetherFormEnterFlightNumber => 'Digite o número do voo';

  @override
  String get aetherFormInvalidFlightFormat =>
      'Formato inválido (ex. UA123, EXS49MY)';

  @override
  String get aetherFormRequired => 'Obrigatório';

  @override
  String get aetherFormUnknownAirport => 'Aeroporto desconhecido';

  @override
  String get aetherFormUseLetterCode => 'Use código de 3-4 letras';

  @override
  String get aetherInfoGroundStations =>
      'Estações terrestres monitoram seu sinal';

  @override
  String get aetherInfoLoraRange =>
      'A 35.000 ft, LoRa pode alcançar mais de 400 km!';

  @override
  String get aetherInfoReceptions =>
      'Reporte recepções e estabeleça recordes de distância!';

  @override
  String get aetherInfoSchedule => 'Agende seu voo com seu nó';

  @override
  String get aetherInfoTagline => 'Rastreie nós Meshtastic em altitude!';

  @override
  String get aetherInfoTitle => 'Aether';

  @override
  String get aetherLeaderboardEmpty => 'Ranking vazio';

  @override
  String get aetherLeaderboardEmptySubtitle =>
      'Seja o primeiro a reportar uma recepção de um nó no céu e conquiste o topo!';

  @override
  String get aetherLeaderboardError => 'Erro ao carregar ranking';

  @override
  String get aetherLeaderboardErrorSubtitle =>
      'Puxe para atualizar e tente novamente.';

  @override
  String get aetherLeaderboardSubtitle =>
      'Rankings globais por distância de recepção';

  @override
  String get aetherLeaderboardTitle => 'Ranking de distância';

  @override
  String get aetherLeaderboardTooltip => 'Ranking';

  @override
  String get aetherMatchInFlight => 'EM VOO';

  @override
  String get aetherMatchReportCta => 'Toque para reportar sua recepção';

  @override
  String get aetherMenuAbout => 'Sobre o Aether';

  @override
  String get aetherMenuHelp => 'Ajuda';

  @override
  String get aetherMenuSettings => 'Configurações';

  @override
  String aetherNodeAlreadyHasFlight(
    String nodeName,
    String flightNumber,
    String status,
  ) {
    return '$nodeName já tem um voo ($flightNumber — $status)';
  }

  @override
  String get aetherOverlayDetected => 'DETECTADO';

  @override
  String get aetherOverlayReport => 'Reportar';

  @override
  String aetherPickerAirportCount(int count) {
    return '$count aeroportos';
  }

  @override
  String get aetherPickerArrivalTitle => 'Aeroporto de chegada';

  @override
  String get aetherPickerDepartureTitle => 'Aeroporto de partida';

  @override
  String get aetherPickerManualEntry =>
      'Você ainda pode digitar o código manualmente';

  @override
  String get aetherPickerNoResults => 'Nenhum aeroporto encontrado';

  @override
  String aetherPickerResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
    );
    return '$_temp0';
  }

  @override
  String get aetherPickerSearchHint => 'Buscar por código, cidade ou nome';

  @override
  String get aetherReportAddNotes => 'Adicionar notas';

  @override
  String get aetherReportEstimatedDistance => 'Distância estimada ';

  @override
  String get aetherReportFlightEnded => 'Este voo terminou';

  @override
  String get aetherReportLocationDetected =>
      'Localização detectada automaticamente';

  @override
  String get aetherReportLocationUnavailable => 'Localização indisponível';

  @override
  String get aetherReportNodeNotDetected =>
      'Nó do voo não detectado na sua rede mesh';

  @override
  String get aetherReportNotOnMesh =>
      'O nó deste voo não está na sua rede mesh. Você só pode reportar uma recepção quando o nó estiver visível para seu dispositivo.';

  @override
  String get aetherReportNotesHint =>
      'Equipamento, antena, detalhes da localização...';

  @override
  String get aetherReportNotesLabel => 'Notas';

  @override
  String get aetherReportRemoveNotes => 'Remover';

  @override
  String get aetherReportRssiLabel => 'RSSI ';

  @override
  String get aetherReportSnrLabel => 'SNR ';

  @override
  String get aetherReportSubmit => 'Enviar relatório';

  @override
  String aetherReportSubtitle(String flightNumber) {
    return 'Eu recebi o voo $flightNumber no meu nó!';
  }

  @override
  String get aetherReportSuccess => 'Recepção reportada!';

  @override
  String get aetherReportTitle => 'Reportar recepção';

  @override
  String get aetherScheduleAlreadyValidatedTooltip => 'Já validado';

  @override
  String get aetherScheduleArrivalBeforeDeparture =>
      'A chegada deve ser após a partida';

  @override
  String get aetherScheduleArrivalDateTitle => 'Data de chegada';

  @override
  String get aetherScheduleArrivalTimeTitle => 'Hora de chegada';

  @override
  String get aetherScheduleBrowseTooltip => 'Explorar aeroportos';

  @override
  String get aetherScheduleButton => 'Agendar voo';

  @override
  String get aetherScheduleConnectDevice =>
      'Conecte seu dispositivo Meshtastic primeiro';

  @override
  String get aetherScheduleConnectToSchedule =>
      'Conecte-se para agendar um voo';

  @override
  String get aetherScheduleDateLabel => 'Data';

  @override
  String get aetherScheduleDepartureDateTitle => 'Data de partida';

  @override
  String get aetherScheduleDepartureInPast =>
      'O horário de partida está no passado';

  @override
  String get aetherScheduleDepartureTimeTitle => 'Hora de partida';

  @override
  String get aetherScheduleDepartureTooFar =>
      'A partida não pode ser mais de um ano a partir de agora';

  @override
  String aetherScheduleDurationTooLong(int hours, int minutes) {
    return 'A duração do voo excede 24 horas (${hours}h ${minutes}m)';
  }

  @override
  String get aetherScheduleDurationTooShort =>
      'A duração do voo deve ser de pelo menos 5 minutos';

  @override
  String aetherScheduleError(String error) {
    return 'Erro: $error';
  }

  @override
  String get aetherScheduleFlightNumberHint => 'UA123';

  @override
  String get aetherScheduleFlightNumberLabel => 'Número do voo';

  @override
  String get aetherScheduleFlightOnGround => 'O voo está atualmente em solo';

  @override
  String aetherScheduleFlightSelectedAlt(int altitude) {
    return 'Voo selecionado! $altitude ft';
  }

  @override
  String get aetherScheduleFlightTooltip => 'Agendar voo';

  @override
  String get aetherScheduleFromHint => 'LAX';

  @override
  String get aetherScheduleFromLabel => 'De';

  @override
  String aetherScheduleIncompleteMessage(String fields) {
    return 'Não foi possível preencher automaticamente $fields do OpenSky Network. Insira esses detalhes manualmente abaixo.';
  }

  @override
  String get aetherScheduleIncompleteTitle => 'Dados do voo incompletos';

  @override
  String get aetherScheduleIntroBanner =>
      'Agende seu voo e compartilhe em aether.socialmesh.app para que a comunidade tente receber seu sinal!';

  @override
  String get aetherScheduleLoadingFlights => 'Carregando voos, tente novamente';

  @override
  String get aetherScheduleNoDeviceConnected => 'Nenhum dispositivo conectado';

  @override
  String aetherScheduleNodeHasActiveFlight(
    String nodeName,
    String flightNumber,
  ) {
    return '$nodeName já tem um voo ativo ($flightNumber)';
  }

  @override
  String get aetherScheduleNotesHint =>
      'Assento na janela, lado esquerdo. TX a 20 dBm.';

  @override
  String get aetherScheduleNotesLabel => 'Notas';

  @override
  String get aetherScheduleResponsibilityTooltip => 'Sua responsabilidade';

  @override
  String aetherScheduleRouteExceedsRange(int distance) {
    return '$distance — excede o alcance máximo da aeronave';
  }

  @override
  String aetherScheduleRouteFound(String route) {
    return 'Rota encontrada: $route';
  }

  @override
  String get aetherScheduleRouteSameAirport => 'Mesmo aeroporto';

  @override
  String aetherScheduleRouteTooClose(
    String departure,
    String arrival,
    int distance,
  ) {
    return '$departure e $arrival estão a $distance km de distância — muito perto para um voo comercial';
  }

  @override
  String get aetherScheduleSameAirport =>
      'Partida e chegada não podem ser o mesmo aeroporto';

  @override
  String get aetherScheduleSearchButton => 'Buscar';

  @override
  String get aetherScheduleSearchTooltip => 'Buscar voos';

  @override
  String get aetherScheduleSectionArrival => 'Hora de chegada (opcional)';

  @override
  String get aetherScheduleSectionDeparture => 'Hora de partida';

  @override
  String get aetherScheduleSectionFlight => 'Informações do voo';

  @override
  String get aetherScheduleSectionNotes => 'Notas adicionais (opcional)';

  @override
  String get aetherScheduleSelect => 'Selecionar';

  @override
  String get aetherScheduleSelectDepartureTime =>
      'Selecione a data e hora de partida';

  @override
  String get aetherScheduleSignInRequired => 'Faça login para agendar um voo';

  @override
  String get aetherScheduleSuccessInFlight => 'Voo em andamento!';

  @override
  String get aetherScheduleSuccessScheduled => 'Voo agendado!';

  @override
  String get aetherScheduleSwapTooltip => 'Inverter aeroportos';

  @override
  String get aetherScheduleTimeLabel => 'Hora';

  @override
  String get aetherScheduleTip1 => 'Se possível, escolha um assento na janela';

  @override
  String get aetherScheduleTip2 =>
      'Mantenha o nó perto da janela durante o voo';

  @override
  String get aetherScheduleTip3 => 'Maior potência TX = maior alcance';

  @override
  String get aetherScheduleTip4 => 'Informe aos outros sua frequência/região';

  @override
  String get aetherScheduleTipsTitle => 'Dicas para melhor recepção';

  @override
  String get aetherScheduleTitle => 'Agendar voo';

  @override
  String get aetherScheduleToHint => 'JFK';

  @override
  String get aetherScheduleToLabel => 'Para';

  @override
  String aetherScheduleTooClose(
    String departure,
    String arrival,
    int distance,
  ) {
    return '$departure e $arrival estão a apenas $distance km de distância — não existem rotas comerciais';
  }

  @override
  String aetherScheduleTooFar(String departure, String arrival, int distance) {
    return 'De $departure a $arrival são $distance — excede o alcance máximo da aeronave';
  }

  @override
  String get aetherScheduleValidateFlightTooltip => 'Validar voo';

  @override
  String get aetherScreenTitle => 'Aether';

  @override
  String get aetherSearchEmptySubtitle =>
      'Tente outro número de voo ou verifique\nse o voo está atualmente no ar';

  @override
  String get aetherSearchEmptyTitle => 'Nenhum voo ativo encontrado';

  @override
  String get aetherSearchError => 'Busca falhou. Tente novamente.';

  @override
  String get aetherSearchFlightNumberHint => 'Número do voo (ex. UA123)';

  @override
  String get aetherSearchHint => 'Buscar voos, aeroportos, nós...';

  @override
  String get aetherSearchIdleSubtitle =>
      'Digite um indicativo e pressione Buscar\npara encontrar voos atualmente no ar';

  @override
  String get aetherSearchIdleTitle => 'Buscar voos ativos';

  @override
  String get aetherSearchOnGround => 'Em solo';

  @override
  String get aetherSearchRetry => 'Tentar novamente';

  @override
  String aetherSearchRouteFrom(String airport) {
    return 'De $airport · Em rota';
  }

  @override
  String aetherSearchRouteTo(String airport) {
    return 'Para $airport';
  }

  @override
  String get aetherSearchTitle => 'Buscar voos';

  @override
  String get aetherSearchTooltip => 'Buscar';

  @override
  String aetherShareText(
    Object flightNumber,
    Object departure,
    Object arrival,
    Object url,
  ) {
    return '$flightNumber $departure → $arrival\nRastreie este voo Meshtastic no Aether:\n$url';
  }

  @override
  String get aetherSignInRequired => 'Login necessário';

  @override
  String get aetherSignInRequiredSubtitle =>
      'Faça login para visualizar e gerenciar seus voos agendados.';

  @override
  String get aetherStatsActive => 'Ativos';

  @override
  String get aetherStatsRecord => 'Recorde';

  @override
  String get aetherStatsReports => 'Relatórios';

  @override
  String get aetherStatsScheduled => 'Agendados';

  @override
  String get aetherStatusCompleted => 'Concluído';

  @override
  String get aetherStatusInFlight => 'Em voo';

  @override
  String get aetherStatusScheduled => 'Agendado';

  @override
  String get aetherStatusUpcoming => 'Em breve';

  @override
  String get aetherValidationActive => 'O voo está atualmente ativo!';

  @override
  String aetherValidationActiveAlt(int altitude) {
    return 'O voo está atualmente ativo! $altitude ft';
  }

  @override
  String get aetherValidationEnterFlightFirst =>
      'Digite um número de voo primeiro';

  @override
  String get aetherValidationFailed => 'Falha ao validar o voo';

  @override
  String get aetherValidationInvalidFormat =>
      'Formato de número de voo inválido';

  @override
  String get aetherValidationRateLimited =>
      'Limite de requisições atingido. Tente novamente em alguns minutos.';

  @override
  String get aetherValidationVerified => 'Voo verificado nos registros OpenSky';

  @override
  String get ambientLightingBlue => 'Azul';

  @override
  String get ambientLightingBrightness => 'Brilho do LED';

  @override
  String get ambientLightingCurrent => 'Corrente';

  @override
  String get ambientLightingCurrentSubtitle => 'Corrente do LED (brilho)';

  @override
  String ambientLightingCurrentValue(int milliamps) {
    return '$milliamps mA';
  }

  @override
  String get ambientLightingCustomColor => 'Cor personalizada';

  @override
  String get ambientLightingDeviceSupportInfo =>
      'A iluminação ambiente está disponível apenas em dispositivos com suporte a LED (RAK WisBlock, T-Beam, etc.)';

  @override
  String get ambientLightingGreen => 'Verde';

  @override
  String get ambientLightingLedEnabled => 'LED ativado';

  @override
  String get ambientLightingLedEnabledSubtitle =>
      'Ativar ou desativar a iluminação ambiente';

  @override
  String get ambientLightingPresetColors => 'Cores predefinidas';

  @override
  String get ambientLightingRed => 'Vermelho';

  @override
  String get ambientLightingSave => 'Salvar';

  @override
  String ambientLightingSaveError(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get ambientLightingSaved => 'Iluminação ambiente salva';

  @override
  String get ambientLightingTitle => 'Iluminação ambiente';

  @override
  String get appTitle => 'Socialmesh';

  @override
  String get arCalibratingSensors => 'Calibrando sensores...';

  @override
  String get arCalibrationScreenAccuracyImproved =>
      'Precisão da bússola melhorada';

  @override
  String get arCalibrationScreenComplete => 'CALIBRAÇÃO CONCLUÍDA';

  @override
  String get arCalibrationScreenContinue => 'CONTINUAR PARA AR';

  @override
  String get arCalibrationScreenInstructionAlmost =>
      'Quase lá!\nSó mais um pouco.';

  @override
  String get arCalibrationScreenInstructionIdle =>
      'Mova seu dispositivo em movimento de 8 para calibrar a bússola para navegação AR precisa.';

  @override
  String get arCalibrationScreenInstructionMoving =>
      'Continue movendo em forma de 8...\nSiga o ponto brilhante.';

  @override
  String get arCalibrationScreenInstructionProgress =>
      'Ótimo progresso!\nContinue o movimento em 8.';

  @override
  String get arCalibrationScreenSkip => 'Pular por enquanto';

  @override
  String get arCalibrationScreenStart => 'INICIAR CALIBRAÇÃO';

  @override
  String get arCalibrationScreenTitle => 'CALIBRAÇÃO DA BÚSSOLA';

  @override
  String arCouldNotOpenMaps(String name) {
    return 'Não foi possível abrir mapas para $name';
  }

  @override
  String get arEngineError => 'ERRO NO MOTOR AR';

  @override
  String get arInitializingEngine => 'INICIALIZANDO MOTOR AR';

  @override
  String get arNoCamerasAvailable => 'Nenhuma câmera disponível';

  @override
  String get arNodeBadgeCritical => 'CRÍTICO';

  @override
  String get arNodeBadgeMoving => 'EM MOVIMENTO';

  @override
  String get arNodeBadgeNew => 'NOVO';

  @override
  String get arNodeBadgeOffline => 'OFFLINE';

  @override
  String get arNodeBadgeWarning => 'ATENÇÃO';

  @override
  String get arNodeDetailAltitude => 'Altitude';

  @override
  String get arNodeDetailBattery => 'Bateria';

  @override
  String get arNodeDetailBearing => 'DIREÇÃO';

  @override
  String get arNodeDetailDistance => 'DISTÂNCIA';

  @override
  String get arNodeDetailElevation => 'ELEVAÇÃO';

  @override
  String get arNodeDetailLastHeard => 'Último sinal';

  @override
  String get arNodeDetailNavigate => 'Navegar';

  @override
  String get arNodeDetailRssi => 'RSSI';

  @override
  String get arNodeDetailSnr => 'SNR';

  @override
  String get arNodeDetailSpeed => 'Velocidade';

  @override
  String get arNodeDetailUnknownNode => 'Nó desconhecido';

  @override
  String get arNodeNoGpsPosition => 'Nó sem posição GPS';

  @override
  String get arRetry => 'TENTAR NOVAMENTE';

  @override
  String get arSettingsAlerts => 'Alertas';

  @override
  String get arSettingsAltimeter => 'Altímetro';

  @override
  String get arSettingsCompass => 'Bússola';

  @override
  String get arSettingsDistanceFilter => 'FILTRO DE DISTÂNCIA';

  @override
  String get arSettingsExplorer => 'Explorar';

  @override
  String get arSettingsFavoritesOnly => 'Somente favoritos';

  @override
  String get arSettingsHorizon => 'Horizonte';

  @override
  String get arSettingsHudElements => 'ELEMENTOS HUD';

  @override
  String get arSettingsMaxDistance => 'Distância máxima';

  @override
  String get arSettingsMaxDistanceLabel => '100km';

  @override
  String get arSettingsMinDistanceLabel => '100m';

  @override
  String get arSettingsMinimal => 'Mínimo';

  @override
  String get arSettingsNodeFilters => 'FILTROS DE NÓS';

  @override
  String get arSettingsShowOfflineNodes => 'Mostrar nós offline';

  @override
  String get arSettingsTactical => 'Avançado';

  @override
  String get arSettingsViewMode => 'MODO DE VISUALIZAÇÃO';

  @override
  String get arTouchLocked => 'Toque bloqueado';

  @override
  String get arTouchUnlocked => 'Toque desbloqueado';

  @override
  String get arViewModeSelectorExp => 'EXP';

  @override
  String get arViewModeSelectorMin => 'MÍN';

  @override
  String get arViewModeSelectorTac => 'AVA';

  @override
  String get authMfaActiveMethods => 'Métodos ativos';

  @override
  String get authMfaCancelButton => 'Cancelar';

  @override
  String get authMfaChangePhoneNumber => 'Alterar número de telefone';

  @override
  String authMfaCodeSentTo(String phoneNumber) {
    return 'Código de verificação enviado para $phoneNumber';
  }

  @override
  String authMfaDateDaysAgo(int count) {
    return '$count dias atrás';
  }

  @override
  String authMfaDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses atrás',
      one: '1 mês atrás',
    );
    return '$_temp0';
  }

  @override
  String get authMfaDateToday => 'hoje';

  @override
  String authMfaDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas atrás',
      one: '1 semana atrás',
    );
    return '$_temp0';
  }

  @override
  String get authMfaDateYesterday => 'ontem';

  @override
  String get authMfaEnableButton => 'Ativar autenticação de dois fatores';

  @override
  String get authMfaEnabled => 'Autenticação de dois fatores ativada';

  @override
  String get authMfaEnrollmentHeading =>
      'Adicione uma camada extra de segurança';

  @override
  String get authMfaEnrollmentSubheading =>
      'Você receberá um código de verificação via SMS ao fazer login';

  @override
  String get authMfaEnrollmentTitle => 'Ativar autenticação de dois fatores';

  @override
  String authMfaEnterCodeSentTo(String phone) {
    return 'Digite o código enviado para $phone';
  }

  @override
  String authMfaEnterCodeSentToPhone(String phoneNumber) {
    return 'Digite o código de 6 dígitos enviado para $phoneNumber';
  }

  @override
  String get authMfaEnterSixDigitCode => 'Digite o código de 6 dígitos';

  @override
  String get authMfaEnterSixDigitCodeWarning => 'Digite o código de 6 dígitos';

  @override
  String get authMfaErrorAccountExistsDifferentCredential =>
      'Já existe uma conta com o mesmo e-mail mas com um método de login diferente. Faça login com o método original.';

  @override
  String get authMfaErrorAlreadyEnrolled =>
      'Este número de telefone já está registrado para autenticação de dois fatores.';

  @override
  String get authMfaErrorAppVerificationFailed =>
      'Verificação do app falhou. Tente novamente.';

  @override
  String get authMfaErrorCancelled => 'A verificação foi cancelada.';

  @override
  String get authMfaErrorCodeExpired =>
      'O código de verificação expirou. Solicite um novo.';

  @override
  String get authMfaErrorCredentialInUse =>
      'Este número de telefone já está sendo usado por outra conta.';

  @override
  String get authMfaErrorEmailInUse =>
      'Este e-mail já está associado a outra conta.';

  @override
  String get authMfaErrorGeneric => 'Verificação falhou. Tente novamente.';

  @override
  String get authMfaErrorInfoNotFound =>
      'Informações de autenticação de dois fatores não encontradas. Registre novamente seu segundo fator.';

  @override
  String get authMfaErrorInternal =>
      'Ocorreu um erro interno. Tente novamente.';

  @override
  String get authMfaErrorInvalidAppCredential =>
      'Verificação do app falhou. Reinicie o app e tente novamente.';

  @override
  String get authMfaErrorInvalidCertHash =>
      'Verificação de assinatura do app falhou. Esta versão pode não estar configurada corretamente para autenticação por telefone.';

  @override
  String get authMfaErrorInvalidCode =>
      'O código está incorreto. Verifique e tente novamente.';

  @override
  String get authMfaErrorInvalidCredential =>
      'O código inserido está incorreto ou expirou. Tente novamente.';

  @override
  String get authMfaErrorInvalidData =>
      'Dados de verificação inválidos. Solicite um novo código.';

  @override
  String get authMfaErrorInvalidPhoneNumber =>
      'Insira um número de telefone válido com código do país (ex. +1 234 567 890).';

  @override
  String get authMfaErrorInvalidTotpCode =>
      'O código do autenticador está incorreto. Verifique e tente novamente.';

  @override
  String get authMfaErrorMaxFactors =>
      'Você atingiu o número máximo de segundos fatores.';

  @override
  String get authMfaErrorMissingAppCredential =>
      'A verificação do app não está configurada. Tente novamente mais tarde.';

  @override
  String get authMfaErrorMissingClientId =>
      'Verificação do app falhou. Reinicie o app e tente novamente.';

  @override
  String get authMfaErrorMissingCode =>
      'Insira o código de verificação enviado para seu telefone.';

  @override
  String get authMfaErrorMissingPhone => 'Insira seu número de telefone.';

  @override
  String get authMfaErrorMissingTotpCode =>
      'Insira o código do seu app autenticador.';

  @override
  String get authMfaErrorNoCurrentUser =>
      'Faça login primeiro para gerenciar a autenticação de dois fatores.';

  @override
  String get authMfaErrorNoInternet =>
      'Sem conexão com a internet. Verifique sua rede e tente novamente.';

  @override
  String get authMfaErrorPhoneNotEnabled =>
      'A verificação por telefone não está habilitada. Entre em contato com o suporte.';

  @override
  String get authMfaErrorProviderAlreadyLinked =>
      'Este método de login já está vinculado à sua conta.';

  @override
  String get authMfaErrorQuotaExceeded =>
      'Serviço temporariamente indisponível. Tente novamente mais tarde.';

  @override
  String get authMfaErrorReauthCancelled =>
      'A reautenticação foi cancelada. Tente novamente.';

  @override
  String get authMfaErrorReauthFailed =>
      'Reautenticação falhou. Saia, entre novamente e tente outra vez.';

  @override
  String get authMfaErrorResolveSignInFailed =>
      'O código de verificação está incorreto ou expirou. Tente novamente ou solicite um novo código.';

  @override
  String get authMfaErrorSecondFactorRequired =>
      'A verificação de dois fatores é necessária para concluir o login.';

  @override
  String get authMfaErrorSessionExpired =>
      'Sua sessão de verificação expirou. Solicite um novo código.';

  @override
  String get authMfaErrorSignInSessionExpired =>
      'Sua sessão de login expirou. Inicie o login novamente.';

  @override
  String get authMfaErrorTimeout => 'A solicitação expirou. Tente novamente.';

  @override
  String get authMfaErrorTooManyRequests =>
      'Muitas tentativas. Aguarde alguns minutos e tente novamente.';

  @override
  String authMfaErrorUnknown(String errorCode) {
    return 'Verificação falhou (erro: $errorCode). Tente novamente.';
  }

  @override
  String get authMfaErrorUnsupportedFirstFactor =>
      'Seu método de login não suporta autenticação de dois fatores.';

  @override
  String get authMfaErrorUserDisabled =>
      'Esta conta foi desativada. Entre em contato com o suporte.';

  @override
  String get authMfaErrorVerificationFailed =>
      'Verificação por telefone falhou. Verifique seu número e tente novamente.';

  @override
  String get authMfaErrorWrongAccount =>
      'Essa conta não corresponde àquela em que você está conectado. Tente novamente e selecione a conta correta.';

  @override
  String authMfaFactorAdded(String relativeTime) {
    return 'Adicionado $relativeTime';
  }

  @override
  String get authMfaHowItWorks => 'Como funciona';

  @override
  String get authMfaInfoQuickDescription =>
      'Leva apenas alguns segundos para verificar durante o login';

  @override
  String get authMfaInfoQuickTitle => 'Rápido e fácil';

  @override
  String get authMfaInfoSecurityDescription =>
      'Protege sua conta mesmo se sua senha for comprometida';

  @override
  String get authMfaInfoSecurityTitle => 'Segurança extra';

  @override
  String get authMfaInfoSmsDescription =>
      'Receba um código de verificação via SMS ao fazer login';

  @override
  String get authMfaInfoSmsTitle => 'Verificação por SMS';

  @override
  String get authMfaManagementTitle => 'Autenticação de dois fatores';

  @override
  String get authMfaNoInternetBody =>
      'O gerenciamento da autenticação de dois fatores requer conexão com a internet. Conecte-se e tente novamente.';

  @override
  String get authMfaNoInternetTitle => 'Sem conexão com a internet';

  @override
  String get authMfaNoPhoneFactorFound => 'Nenhum fator de telefone encontrado';

  @override
  String get authMfaNoVerificationId =>
      'Sem ID de verificação. Tente reenviar.';

  @override
  String get authMfaNotEnabledDescription =>
      'Adicione uma camada extra de segurança';

  @override
  String get authMfaOfflineBanner =>
      'Você está offline. As alterações não podem ser feitas até que você se reconecte.';

  @override
  String get authMfaPhoneCountryCodeRequired =>
      'O número de telefone deve incluir o código do país (+1, +44, etc.)';

  @override
  String get authMfaPhoneFallback => 'Telefone';

  @override
  String get authMfaPhoneNumberHint => '+1 234 567 890';

  @override
  String get authMfaPhoneNumberLabel => 'Número de telefone';

  @override
  String get authMfaPhoneRequired => 'Insira seu número de telefone';

  @override
  String get authMfaProtectedDescription => 'Sua conta está protegida com 2FA';

  @override
  String get authMfaRemoveConfirmLabel => 'Remover';

  @override
  String get authMfaRemoveConfirmMessage =>
      'Sua conta ficará menos segura. Você pode reativar a qualquer momento.';

  @override
  String get authMfaRemoveConfirmTitle =>
      'Remover autenticação de dois fatores?';

  @override
  String get authMfaRemoveRequiresInternet =>
      'A remoção da autenticação de dois fatores requer conexão com a internet.';

  @override
  String get authMfaRemoved => 'Autenticação de dois fatores removida';

  @override
  String get authMfaRequiresInternet =>
      'A autenticação de dois fatores requer conexão com a internet.';

  @override
  String get authMfaRetryButton => 'Tentar novamente';

  @override
  String get authMfaSendCodeButton => 'Enviar código';

  @override
  String get authMfaSendCodeRequiresInternet =>
      'O envio de códigos de verificação requer conexão com a internet.';

  @override
  String get authMfaSendingButton => 'Enviando...';

  @override
  String get authMfaSendingCode => 'Enviando código de verificação...';

  @override
  String get authMfaStatusNotEnabled => 'Não ativado';

  @override
  String get authMfaStatusProtected => 'Protegido';

  @override
  String get authMfaStillOffline => 'Ainda offline. Verifique sua conexão.';

  @override
  String get authMfaVerificationCodeHint => '000000';

  @override
  String get authMfaVerificationCodeLabel => 'Código de verificação';

  @override
  String get authMfaVerifyAndEnableButton => 'Verificar e ativar';

  @override
  String get authMfaVerifyButton => 'Verificar';

  @override
  String get authMfaVerifyIdentityTitle => 'Verificar identidade';

  @override
  String get authMfaVerifyRequiresInternet =>
      'A verificação de códigos requer conexão com a internet.';

  @override
  String get authMfaVerifyingButton => 'Verificando...';

  @override
  String get authMfaYourPhone => 'seu telefone';

  @override
  String get automationActionBodyLabel => 'Corpo';

  @override
  String get automationActionChangeType => 'Alterar tipo de ação';

  @override
  String automationActionChannelIndex(int index) {
    return 'Canal $index';
  }

  @override
  String get automationActionChannelMessage => 'Mensagem no canal';

  @override
  String automationActionChannelsCount(int count) {
    return '$count canais';
  }

  @override
  String get automationActionCustomSound => 'Som personalizado (opcional)';

  @override
  String get automationActionDefaultChannel => 'Canal padrão';

  @override
  String get automationActionDirectMessage => 'Mensagem direta';

  @override
  String get automationActionDone => 'Concluído';

  @override
  String get automationActionGlyphPattern => 'Padrão de glifo (Nothing Phone)';

  @override
  String get automationActionGotIt => 'Entendi';

  @override
  String get automationActionIftttEventName => 'Nome do evento IFTTT';

  @override
  String get automationActionIftttHelp =>
      'Usa sua chave Webhook IFTTT das Configurações';

  @override
  String get automationActionIftttHint => 'ex. meshtastic_alert';

  @override
  String get automationActionWebhookEventName => 'Nome do Evento';

  @override
  String get automationActionWebhookUrlLabel => 'URL do Webhook (opcional)';

  @override
  String get automationActionWebhookUrlHint =>
      'ex., http://192.168.1.100:8123/api/webhook/...';

  @override
  String get automationActionWebhookHelp =>
      'Insira um URL personalizado para enviar via POST, ou deixe em branco para usar as configurações globais de IFTTT/webhook. Endereços privados/LAN (192.168.x, 10.x) são suportados.';

  @override
  String get automationActionLogEvent => 'Registrar no histórico';

  @override
  String get automationActionMessageLabel => 'Mensagem';

  @override
  String get automationActionNoChannels => 'Nenhum canal disponível';

  @override
  String get automationActionNoSoundsFound => 'Nenhum som encontrado';

  @override
  String get automationActionPlaySound => 'Reproduzir som de alerta';

  @override
  String automationActionPlayFailed(String error) {
    return 'Falha ao reproduzir: $error';
  }

  @override
  String automationActionPlaySoundFailed(String error) {
    return 'Falha ao reproduzir som: $error';
  }

  @override
  String automationActionPlayingSound(String name) {
    return 'Reproduzindo \"$name\"...';
  }

  @override
  String get automationActionPlaysAfter => 'Reproduz após a notificação';

  @override
  String get automationActionPreview => 'Pré-visualizar';

  @override
  String get automationActionPrimary => 'Primário';

  @override
  String get automationActionPushNotification => 'Notificação push';

  @override
  String get automationActionRtttlRingtone => 'Toque RTTTL';

  @override
  String get automationActionSearchResults => 'RESULTADOS DA BUSCA';

  @override
  String get automationActionSearchSounds => 'Buscar sons...';

  @override
  String get automationActionSelectChannel => 'Selecionar canal';

  @override
  String get automationActionSelectChannelTitle => 'Selecionar canal';

  @override
  String get automationActionSelectNodePlaceholder => 'Selecionar nó';

  @override
  String get automationActionSelectSound => 'Selecionar um som';

  @override
  String get automationActionSendMessage => 'Enviar mensagem para o nó';

  @override
  String get automationActionSendToChannel => 'Enviar para o canal';

  @override
  String get automationActionShortcutDataInfo =>
      'Os dados do evento (nome do nó, bateria, localização, etc.) serão passados como entrada JSON para seu atalho.';

  @override
  String get automationActionShortcutHelpTitle => 'Usando atalhos';

  @override
  String get automationActionShortcutIosNote =>
      'Nota: o app Atalhos abrirá brevemente quando acionado. Esta é uma limitação do iOS.';

  @override
  String get automationActionShortcutKeyBattery => 'Bateria % (se disponível)';

  @override
  String get automationActionShortcutKeyLatitude =>
      'Latitude GPS (se disponível)';

  @override
  String get automationActionShortcutKeyLongitude =>
      'Longitude GPS (se disponível)';

  @override
  String get automationActionShortcutKeyMessage =>
      'Texto da mensagem (se aplicável)';

  @override
  String get automationActionShortcutKeyNodeName => 'Nome do nó';

  @override
  String get automationActionShortcutKeyNodeNum => 'Número do nó';

  @override
  String get automationActionShortcutKeyTimestamp => 'Timestamp do evento';

  @override
  String get automationActionShortcutKeyTrigger =>
      'Tipo de gatilho (nodeOffline, etc.)';

  @override
  String get automationActionShortcutKeysTitle =>
      'Chaves disponíveis no dicionário:';

  @override
  String get automationActionShortcutNameHint =>
      'Insira o nome exato do atalho';

  @override
  String get automationActionShortcutNameLabel => 'Nome do atalho';

  @override
  String get automationActionShortcutSetup => 'Configurando seu atalho:';

  @override
  String get automationActionShortcutStep1 =>
      'Adicione a ação \"Obter dicionário de\"\nSelecione \"Entrada do atalho\"';

  @override
  String get automationActionShortcutStep2 =>
      'Adicione a ação \"Obter valor para\"\nDefina a chave (ex. node_name) e selecione \"Dicionário\"';

  @override
  String get automationActionShortcutStep3 =>
      'Use o valor extraído em suas ações\n(ex. Enviar mensagem, Mostrar notificação)';

  @override
  String get automationActionSoundSection => 'SOM';

  @override
  String automationActionSoundsCount(int count) {
    return '$count sons';
  }

  @override
  String get automationActionSuggestions => 'SUGESTÕES';

  @override
  String get automationActionSystemDefault => 'Padrão do sistema';

  @override
  String get automationActionTapToChoose => 'Toque para escolher';

  @override
  String get automationActionTitleLabel => 'Título';

  @override
  String get automationActionTo => 'PARA';

  @override
  String get automationActionTriggerShortcut => 'Executar atalho iOS';

  @override
  String get automationActionTriggerWebhook => 'Acionar webhook (IFTTT)';

  @override
  String get automationActionUpdateWidget => 'Atualizar widget da tela inicial';

  @override
  String get automationActionVariableHint =>
      'Toque nas variáveis abaixo para inserir';

  @override
  String get automationActionVibrate => 'Vibrar dispositivo';

  @override
  String automationCardActionCount(int count, String s) {
    return '$count ação$s';
  }

  @override
  String automationCardDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String automationCardHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String get automationCardJustNow => 'Agora';

  @override
  String automationCardMinutesAgo(int count) {
    return '${count}m atrás';
  }

  @override
  String automationCardRunsCount(int count) {
    return '$count execuções';
  }

  @override
  String automationCardWeeksAgo(int count) {
    return '${count}sem atrás';
  }

  @override
  String get automationCategoryBattery => 'Bateria';

  @override
  String get automationCategoryLocation => 'Localização';

  @override
  String get automationCategoryManual => 'Manual';

  @override
  String get automationCategoryMessages => 'Mensagens';

  @override
  String get automationCategoryNodeStatus => 'Status do nó';

  @override
  String get automationCategorySensors => 'Sensores';

  @override
  String get automationCategorySignal => 'Sinal';

  @override
  String get automationCategoryTime => 'Tempo';

  @override
  String get automationConditionBatteryAbove => 'Bateria acima do limite';

  @override
  String get automationConditionBatteryBelow => 'Bateria abaixo do limite';

  @override
  String get automationConditionDayOfWeek => 'Em dias específicos';

  @override
  String get automationConditionNodeOffline => 'Nó inativo';

  @override
  String get automationConditionNodeOnline => 'Nó ativo';

  @override
  String get automationConditionOutsideGeofence => 'Fora do geofence';

  @override
  String get automationConditionTimeRange => 'Durante intervalo de tempo';

  @override
  String get automationConditionWithinGeofence => 'Dentro do geofence';

  @override
  String get automationEditorAddAction => 'Adicionar ação';

  @override
  String get automationEditorCreateAutomation => 'Criar automação';

  @override
  String get automationEditorCreated => 'Automação criada';

  @override
  String get automationEditorDeleteError => 'Falha ao excluir automação';

  @override
  String get automationEditorDeleteTooltip => 'Excluir';

  @override
  String automationEditorDescBatteryLow(String threshold) {
    return 'Acionado quando a bateria cai abaixo de $threshold%';
  }

  @override
  String automationEditorDescSilent(int minutes) {
    return 'Alertar se nenhuma atividade do nó por $minutes minutos';
  }

  @override
  String get automationEditorDescriptionHint => 'O que esta automação faz?';

  @override
  String get automationEditorDescriptionLabel => 'Descrição (opcional)';

  @override
  String automationEditorInvalidVars(String vars) {
    return 'Variáveis inválidas: $vars';
  }

  @override
  String get automationEditorNameHint => 'ex. Alerta de bateria fraca';

  @override
  String get automationEditorNameLabel => 'Nome';

  @override
  String get automationEditorNoActions => 'Nenhuma ação configurada';

  @override
  String get automationEditorNoActionsHint =>
      'Toque em \"+ Adicionar ação\" para adicionar uma';

  @override
  String get automationEditorSaveChanges => 'Salvar alterações';

  @override
  String get automationEditorSaveError => 'Falha ao salvar automação';

  @override
  String get automationEditorSaving => 'Salvando...';

  @override
  String automationEditorStepNumber(int number) {
    return 'Passo $number';
  }

  @override
  String get automationEditorThen => 'ENTÃO';

  @override
  String get automationEditorThen2 => 'então...';

  @override
  String get automationEditorThenDo => 'então faça...';

  @override
  String get automationEditorTitleEdit => 'Editar automação';

  @override
  String get automationEditorTitleNew => 'Nova automação';

  @override
  String get automationEditorUpdated => 'Automação atualizada';

  @override
  String get automationEditorValidateActions => 'Adicione pelo menos uma ação';

  @override
  String get automationEditorValidateName =>
      'Insira um nome para esta automação';

  @override
  String get automationEditorWhen => 'QUANDO';

  @override
  String get automationFlowAddNode => 'Adicionar nó';

  @override
  String get automationFlowCompilationIssues => 'Problemas de compilação';

  @override
  String get automationFlowCreate => 'Criar';

  @override
  String get automationFlowCreated => 'Automação criada';

  @override
  String get automationFlowDiscard => 'Descartar';

  @override
  String get automationFlowDiscardMessage =>
      'Você tem alterações não salvas no editor de fluxo. Descartar e voltar?';

  @override
  String get automationFlowDiscardTitle => 'Descartar alterações?';

  @override
  String get automationFlowEditTitle => 'Editar fluxo';

  @override
  String get automationFlowErrors => 'Erros';

  @override
  String get automationFlowKeepEditing => 'Continuar editando';

  @override
  String get automationFlowNameHint => 'Nome do fluxo...';

  @override
  String get automationFlowNewTitle => 'Novo fluxo';

  @override
  String get automationFlowNoCompilation =>
      'Nenhuma automação pôde ser compilada a partir deste grafo';

  @override
  String automationFlowNodesCount(int count) {
    return '$count nós';
  }

  @override
  String get automationFlowSave => 'Salvar';

  @override
  String get automationFlowSaveError => 'Falha ao salvar automação';

  @override
  String get automationFlowToolbarAdd => 'Adicionar';

  @override
  String automationFlowToolbarDelete(int count) {
    return 'Excluir ($count)';
  }

  @override
  String get automationFlowToolbarFit => 'Ajustar';

  @override
  String get automationFlowToolbarRedo => 'Refazer';

  @override
  String get automationFlowToolbarUndo => 'Desfazer';

  @override
  String get automationFlowUpdated => 'Automação atualizada';

  @override
  String get automationFlowValidateName => 'Insira um nome para esta automação';

  @override
  String get automationFlowValidationTooltip => 'Problemas de validação';

  @override
  String get automationFlowWarnings => 'Avisos';

  @override
  String automationImportActionsCount(int count) {
    return 'Ações ($count)';
  }

  @override
  String get automationImportButton => 'Importar';

  @override
  String automationImportConditionsCount(int count) {
    return 'Condições ($count)';
  }

  @override
  String automationImportConditionsText(int count) {
    return '$count condições';
  }

  @override
  String get automationImportEditFirst => 'Editar primeiro';

  @override
  String automationImportError(String error) {
    return 'Falha ao importar: $error';
  }

  @override
  String automationImportFailed(String error) {
    return 'Falha ao importar automação: $error';
  }

  @override
  String get automationImportFailedTitle => 'Falha na importação';

  @override
  String get automationImportGoBack => 'Voltar';

  @override
  String get automationImportNoData => 'Nenhum dado de automação fornecido';

  @override
  String get automationImportNotFound => 'Automação não encontrada ou excluída';

  @override
  String get automationImportSuccess => 'Automação importada com sucesso';

  @override
  String get automationImportTitle => 'Importar automação';

  @override
  String get automationImportTrigger => 'Gatilho';

  @override
  String get automationImportView => 'Visualizar';

  @override
  String get automationImportWarning =>
      'Esta automação será importada como desativada. Revise e ative quando estiver pronto.';

  @override
  String get automationScreenAcceptableUse => 'Uso aceitável';

  @override
  String get automationScreenAddAutomation => 'Adicionar automação';

  @override
  String get automationScreenClear => 'Limpar';

  @override
  String get automationScreenClearLogTitle => 'Limpar log de execução';

  @override
  String get automationScreenClearLogMessage =>
      'Tem certeza de que deseja limpar o log de execução? Esta ação não pode ser desfeita.';

  @override
  String get automationScreenCreateFromScratch => 'Criar do zero';

  @override
  String get automationScreenCreateFromScratchSubtitle =>
      'Crie uma automação personalizada com controle total sobre gatilhos e ações';

  @override
  String get automationScreenCreatedFromTemplate =>
      'Automação criada a partir do modelo';

  @override
  String automationScreenDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String get automationScreenDelete => 'Excluir';

  @override
  String automationScreenDeleteMessage(String name) {
    return 'Tem certeza que deseja excluir \"$name\"?';
  }

  @override
  String get automationScreenDeleteTitle => 'Excluir automação';

  @override
  String automationScreenDeleted(String name) {
    return '\"$name\" excluída';
  }

  @override
  String automationScreenDeleting(String name) {
    return 'Excluindo \"$name\"...';
  }

  @override
  String get automationScreenEmptyDescription =>
      'Crie automações para acionar ações automaticamente quando eventos ocorrerem na sua rede mesh.';

  @override
  String get automationScreenEmptyTitle => 'Automatize sua rede mesh';

  @override
  String get automationScreenExecutionLog => 'Log de execuções';

  @override
  String get automationScreenHelp => 'Ajuda';

  @override
  String automationScreenHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String get automationScreenJustNow => 'Agora';

  @override
  String get automationScreenLoadError => 'Falha ao carregar automações';

  @override
  String automationScreenMinutesAgo(int count) {
    return '${count}m atrás';
  }

  @override
  String get automationScreenNewTooltip => 'Nova automação';

  @override
  String get automationScreenNoExecutions => 'Nenhuma execução ainda';

  @override
  String get automationScreenQuickStartSubtitle =>
      'Configuração rápida para os casos de uso mais comuns';

  @override
  String get automationScreenQuickStartTemplates => 'Modelos rápidos';

  @override
  String get automationScreenRetry => 'Tentar novamente';

  @override
  String automationScreenRunFailed(String error) {
    return 'Falha ao executar: $error';
  }

  @override
  String automationScreenRunSuccess(String name) {
    return '\"$name\" executada com sucesso';
  }

  @override
  String automationScreenRunning(String name) {
    return 'Executando \"$name\"...';
  }

  @override
  String get automationScreenScanQrCode => 'Escanear código QR';

  @override
  String get automationScreenStartWithTrigger => 'Comece com um gatilho';

  @override
  String get automationScreenStartWithTriggerSubtitle =>
      'Escolha qual evento inicia sua automação';

  @override
  String get automationScreenStatActive => 'Ativas';

  @override
  String get automationScreenStatExecutions => 'Execuções';

  @override
  String get automationScreenStatTotal => 'Total';

  @override
  String get automationScreenTitle => 'Automações';

  @override
  String get automationShareMessage => 'Confira esta automação no SocialMesh!';

  @override
  String get automationShareScanInfo =>
      'Escaneie este código QR no SocialMesh para importar esta automação';

  @override
  String get automationShareSignIn => 'Entre para compartilhar automações';

  @override
  String get automationShareSignInAction => 'Entrar';

  @override
  String automationShareSubject(String name) {
    return 'Automação SocialMesh: $name';
  }

  @override
  String get automationShareTitle => 'Compartilhar automação';

  @override
  String get automationTriggerAnyChannel => 'Qualquer canal';

  @override
  String get automationTriggerAnyNode => 'Qualquer nó';

  @override
  String get automationTriggerBatteryFull => 'Bateria totalmente carregada';

  @override
  String get automationTriggerBatteryLow => 'Bateria abaixo do limite';

  @override
  String get automationTriggerBatteryThreshold => 'Limite de bateria';

  @override
  String get automationTriggerChannelActivity => 'Atividade no canal';

  @override
  String get automationTriggerChannelHelp =>
      'Deixe vazio para acionar para qualquer atividade no canal';

  @override
  String automationTriggerChannelIndex(int index) {
    return 'Canal $index';
  }

  @override
  String get automationTriggerChannelLabel => 'Canal (opcional)';

  @override
  String get automationTriggerDaily => 'Diário';

  @override
  String get automationTriggerDayFri => 'Sex';

  @override
  String get automationTriggerDayMon => 'Seg';

  @override
  String get automationTriggerDaySat => 'Sáb';

  @override
  String get automationTriggerDaySun => 'Dom';

  @override
  String get automationTriggerDayThu => 'Qui';

  @override
  String get automationTriggerDayTue => 'Ter';

  @override
  String get automationTriggerDayWed => 'Qua';

  @override
  String get automationTriggerDays => 'Dias';

  @override
  String get automationTriggerDescBatteryFull =>
      'Acionado quando a bateria está totalmente carregada';

  @override
  String get automationTriggerDescBatteryLow =>
      'Acionado quando a bateria cai abaixo do limite';

  @override
  String get automationTriggerDescChannelActivity =>
      'Acionado quando há atividade no canal';

  @override
  String get automationTriggerDescDetectionSensor =>
      'Acionado quando o sensor de detecção é ativado';

  @override
  String get automationTriggerDescGeofenceEnter =>
      'Acionado quando o nó entra na área do geofence';

  @override
  String get automationTriggerDescGeofenceExit =>
      'Acionado quando o nó sai da área do geofence';

  @override
  String get automationTriggerDescManual =>
      'Acionado manualmente via Atalhos ou UI';

  @override
  String get automationTriggerDescMessageContains =>
      'Acionado quando a mensagem contém palavra-chave';

  @override
  String get automationTriggerDescMessageReceived =>
      'Acionado quando qualquer mensagem é recebida';

  @override
  String get automationTriggerDescNodeOffline =>
      'Acionado quando um nó não é detectado por um tempo';

  @override
  String get automationTriggerDescNodeOnline =>
      'Acionado quando um nó é detectado recentemente';

  @override
  String get automationTriggerDescNodeSilent =>
      'Acionado quando o nó fica silencioso pela duração definida';

  @override
  String get automationTriggerDescPositionChanged =>
      'Acionado quando a posição do nó muda';

  @override
  String get automationTriggerDescScheduled => 'Acionado no horário programado';

  @override
  String get automationTriggerDescSignalWeak =>
      'Acionado quando o sinal enfraquece';

  @override
  String get automationTriggerDetectionSensor => 'Sensor de detecção acionado';

  @override
  String automationTriggerEveryHours(int hours, String s) {
    return 'A cada $hours hora$s';
  }

  @override
  String automationTriggerEveryHoursMinutes(int hours, String s, int minutes) {
    return 'A cada $hours hora$s $minutes minutos';
  }

  @override
  String automationTriggerEveryMinutes(int count) {
    return 'A cada $count minutos';
  }

  @override
  String get automationTriggerGeofenceCenter => 'Centro do geofence';

  @override
  String get automationTriggerGeofenceEnter => 'Entra na área do geofence';

  @override
  String get automationTriggerGeofenceExit => 'Sai da área do geofence';

  @override
  String get automationTriggerInterval => 'Intervalo';

  @override
  String get automationTriggerKeywordHint => 'ex. SOS, ajuda, emergência';

  @override
  String get automationTriggerKeywordLabel => 'Palavra-chave a buscar';

  @override
  String get automationTriggerLatitude => 'Latitude';

  @override
  String get automationTriggerLongitude => 'Longitude';

  @override
  String get automationTriggerManual => 'Acionamento manual';

  @override
  String get automationTriggerManualDescription =>
      'Esta automação pode ser acionada manualmente a partir de:\n• A tela Automações (toque no botão play)\n• Atalhos da Siri\n• Widgets';

  @override
  String get automationTriggerManualTitle => 'Acionamento manual';

  @override
  String get automationTriggerMessageContains =>
      'Mensagem contém palavra-chave';

  @override
  String get automationTriggerMessageReceived => 'Mensagem recebida';

  @override
  String get automationTriggerNodeFilterHelp =>
      'Deixe vazio para acionar para qualquer nó';

  @override
  String get automationTriggerNodeFilterLabel => 'Filtrar por nó (opcional)';

  @override
  String get automationTriggerNodeOffline => 'Nó fica inativo';

  @override
  String get automationTriggerNodeOnline => 'Nó fica ativo';

  @override
  String get automationTriggerNodeSilent => 'Nó silencioso por duração';

  @override
  String get automationTriggerPickOnMap => 'Escolher no mapa';

  @override
  String get automationTriggerPositionChanged => 'Posição atualizada';

  @override
  String get automationTriggerRadius => 'Raio';

  @override
  String get automationTriggerRepeatEvery => 'Repetir a cada';

  @override
  String get automationTriggerScheduleType => 'Tipo de programação';

  @override
  String get automationTriggerScheduled => 'Horário programado';

  @override
  String get automationTriggerSelectNode => 'Selecionar nó';

  @override
  String get automationTriggerSelectTrigger => 'Selecionar gatilho';

  @override
  String get automationTriggerSensorAny => 'Qualquer';

  @override
  String get automationTriggerSensorClear => 'Livre';

  @override
  String get automationTriggerSensorDetected => 'Detectado';

  @override
  String get automationTriggerSensorNameHelp =>
      'Deixe vazio para acionar para qualquer sensor';

  @override
  String get automationTriggerSensorNameHint => 'ex. Movimento, Porta, Janela';

  @override
  String get automationTriggerSensorNameLabel =>
      'Filtro de nome do sensor (opcional)';

  @override
  String get automationTriggerSensorState => 'Acionar quando o sensor estiver';

  @override
  String get automationTriggerSignalThreshold => 'Limite de sinal (SNR)';

  @override
  String get automationTriggerSignalWeak => 'Sinal enfraquece';

  @override
  String get automationTriggerSilentDuration => 'Duração do silêncio';

  @override
  String get automationTriggerTime => 'Hora';

  @override
  String get automationTriggerWeekly => 'Semanal';

  @override
  String get automationValidateGeofence =>
      'Selecione uma localização para o geofence';

  @override
  String get automationValidateKeyword =>
      'Insira uma palavra-chave para buscar';

  @override
  String get automationValidateMessage => 'Insira uma mensagem para enviar';

  @override
  String get automationValidateSchedule => 'Defina um horário programado';

  @override
  String get automationValidateShortcutName => 'Insira um nome para o Atalho';

  @override
  String get automationValidateTargetNode => 'Selecione um nó de destino';

  @override
  String get automationValidateWebhookEvent =>
      'Insira um nome para o evento webhook';

  @override
  String get automationVariableAllVariables => 'Todas as variáveis';

  @override
  String get automationVariableDeleteHint =>
      'Toque em uma variável para selecioná-la, depois pressione backspace para remover';

  @override
  String get automationVariableDescBattery => 'Porcentagem atual da bateria';

  @override
  String get automationVariableDescChannelName => 'Nome do canal';

  @override
  String get automationVariableDescKeyword => 'Palavra-chave encontrada';

  @override
  String get automationVariableDescLocation => 'Coordenadas GPS (lat, lon)';

  @override
  String get automationVariableDescMessage => 'Conteúdo da mensagem';

  @override
  String get automationVariableDescNodeName => 'Nome do nó acionador';

  @override
  String get automationVariableDescNodeNum =>
      'Número do nó em hexadecimal (ex. a1b2)';

  @override
  String get automationVariableDescSensorName => 'Nome do sensor de detecção';

  @override
  String get automationVariableDescSensorState =>
      'Estado do sensor (detectado / livre)';

  @override
  String get automationVariableDescSignalThreshold =>
      'Limiar do sinal em dB (SNR)';

  @override
  String get automationVariableDescSilentDuration =>
      'Configuração de duração do silêncio';

  @override
  String get automationVariableDescThreshold =>
      'Limiar de acionamento configurado';

  @override
  String get automationVariableDescTime => 'Timestamp atual (ISO 8601)';

  @override
  String get automationVariableDescZoneRadius => 'Raio do geofence em metros';

  @override
  String get automationVariableNoMatch => 'Nenhuma variável correspondente';

  @override
  String get automationVariablePickerTitle => 'Inserir variável';

  @override
  String get automationVariableSearchHint => 'Buscar variáveis...';

  @override
  String get automationVariableSectionTrigger => 'Contexto do gatilho';

  @override
  String get automationVariableSectionUniversal => 'Universal';

  @override
  String get categoryProductsApplyFilters => 'Aplicar filtros';

  @override
  String get categoryProductsClearFilters => 'Limpar filtros';

  @override
  String get categoryProductsErrorLoading => 'Erro ao carregar produtos';

  @override
  String get categoryProductsFilter => 'Filtrar';

  @override
  String get categoryProductsFiltersTitle => 'Filtros';

  @override
  String get categoryProductsFrequencyBands => 'Faixas de frequência';

  @override
  String get categoryProductsInStockOnly => 'Somente em estoque';

  @override
  String get categoryProductsNotFound => 'Nenhum produto encontrado';

  @override
  String get categoryProductsOutOfStock => 'FORA DE ESTOQUE';

  @override
  String get categoryProductsPriceRange => 'Faixa de preço';

  @override
  String get categoryProductsReset => 'Redefinir';

  @override
  String categoryProductsResultCount(int count) {
    return '$count produtos';
  }

  @override
  String get categoryProductsRetry => 'Tentar novamente';

  @override
  String get categoryProductsSortNewest => 'Mais recentes';

  @override
  String get categoryProductsSortPopular => 'Mais populares';

  @override
  String get categoryProductsSortPriceHigh => 'Preço: maior para menor';

  @override
  String get categoryProductsSortPriceLow => 'Preço: menor para maior';

  @override
  String get categoryProductsSortRating => 'Mais bem avaliados';

  @override
  String get categoryProductsTryFilters => 'Tente ajustar seus filtros';

  @override
  String get channelFormApproxLocationTitle => 'Localização aproximada';

  @override
  String get channelFormCreatedSnackbar => 'Canal criado';

  @override
  String channelFormDefaultName(int index) {
    return 'Canal $index';
  }

  @override
  String get channelFormDeviceNotConnected =>
      'Não é possível salvar o canal: dispositivo não conectado';

  @override
  String get channelFormDeviceNotReady =>
      'Dispositivo não pronto - aguarde a conexão';

  @override
  String get channelFormDownlinkSubtitle =>
      'Receber mensagens do servidor MQTT';

  @override
  String get channelFormDownlinkTitle => 'Downlink habilitado';

  @override
  String get channelFormEditTitle => 'Editar canal';

  @override
  String get channelFormEncryptionLabel => 'Criptografia';

  @override
  String channelFormError(String error) {
    return 'Erro: $error';
  }

  @override
  String get channelFormInvalidBase64 => 'Codificação base64 inválida';

  @override
  String channelFormInvalidKeySize(int byteCount) {
    return 'Tamanho de chave inválido ($byteCount bytes). Use 1, 16 ou 32 bytes.';
  }

  @override
  String get channelFormKeyEmpty => 'A chave não pode estar vazia';

  @override
  String get channelFormKeySizeAes128 => 'AES-128';

  @override
  String get channelFormKeySizeAes256 => 'AES-256';

  @override
  String channelFormKeySizeBitDesc(int bits) {
    return 'Chave de criptografia de $bits bits';
  }

  @override
  String get channelFormKeySizeDefault => 'Padrão (Simples)';

  @override
  String get channelFormKeySizeDefaultDesc => 'Chave simples de 1 byte (AQ==)';

  @override
  String get channelFormKeySizeNone => 'Sem criptografia';

  @override
  String get channelFormKeySizeNoneDesc =>
      'Mensagens enviadas em texto simples';

  @override
  String get channelFormMaxChannelsReached => 'Máximo de 8 canais permitidos';

  @override
  String get channelFormMqttLabel => 'MQTT';

  @override
  String get channelFormMqttWarning =>
      'A maioria dos dispositivos tem capacidade de processamento e RAM muito limitadas. Conectar um canal movimentado como LongFast pelo servidor MQTT padrão pode inundar o dispositivo com 15-25 pacotes por segundo, fazendo-o parar de responder. Considere usar um broker privado ou um canal mais tranquilo.';

  @override
  String get channelFormNameHint => 'Digite o nome do canal (sem espaços)';

  @override
  String get channelFormNameMaxHint => 'Máx. 11 caracteres';

  @override
  String get channelFormNameTitle => 'Nome do canal';

  @override
  String get channelFormNewTitle => 'Novo canal';

  @override
  String get channelFormPositionEnabledSubtitle =>
      'Compartilhar posição neste canal';

  @override
  String get channelFormPositionEnabledTitle => 'Posições habilitadas';

  @override
  String get channelFormPositionLabel => 'Posição';

  @override
  String get channelFormPreciseLocationSubtitle =>
      'Compartilhar coordenadas GPS exatas';

  @override
  String get channelFormPreciseLocationTitle => 'Localização precisa';

  @override
  String get channelFormPrecision12 => 'Dentro de 5,8 km';

  @override
  String get channelFormPrecision13 => 'Dentro de 2,9 km';

  @override
  String get channelFormPrecision14 => 'Dentro de 1,5 km';

  @override
  String get channelFormPrecision15 => 'Dentro de 700 m';

  @override
  String get channelFormPrecision32 => 'Localização precisa';

  @override
  String get channelFormPrecisionUnknown => 'Desconhecida';

  @override
  String get channelFormPrimaryChannelNote =>
      'Este é o canal principal para comunicação do dispositivo. Alterações podem afetar a conectividade.';

  @override
  String get channelFormPrimaryChannelTitle => 'Canal primário';

  @override
  String get channelFormSaveButton => 'Salvar';

  @override
  String get channelFormUpdatedSnackbar => 'Canal atualizado';

  @override
  String get channelFormUplinkSubtitle =>
      'Encaminhar mensagens ao servidor MQTT';

  @override
  String get channelFormUplinkTitle => 'Uplink habilitado';

  @override
  String get channelOptionsCopyButton => 'Copiar';

  @override
  String channelOptionsDefaultName(int index) {
    return 'Canal $index';
  }

  @override
  String get channelOptionsDelete => 'Excluir canal';

  @override
  String get channelOptionsDeleteButton => 'Excluir';

  @override
  String channelOptionsDeleteConfirm(String name) {
    return 'Excluir canal \"$name\"?';
  }

  @override
  String channelOptionsDeleteFailed(String error) {
    return 'Falha ao excluir canal: $error';
  }

  @override
  String get channelOptionsDeleteNotConnected =>
      'Não é possível excluir o canal: dispositivo não conectado';

  @override
  String get channelOptionsDeleteTitle => 'Excluir canal';

  @override
  String get channelOptionsEdit => 'Editar canal';

  @override
  String get channelOptionsEncrypted => 'Criptografado';

  @override
  String get channelOptionsHideButton => 'Ocultar';

  @override
  String get channelOptionsInviteLink => 'Compartilhar link de convite';

  @override
  String get channelOptionsKeyCopied =>
      'Chave copiada para a área de transferência';

  @override
  String channelOptionsKeySubtitle(int keyBits, int keyBytes) {
    return '$keyBits bits · $keyBytes bytes · Base64';
  }

  @override
  String get channelOptionsKeyTitle => 'Chave de criptografia';

  @override
  String get channelOptionsNoEncryption => 'Sem criptografia';

  @override
  String get channelOptionsShare => 'Compartilhar canal';

  @override
  String get channelOptionsShowButton => 'Mostrar';

  @override
  String get channelOptionsMuteNotifications => 'Silenciar Notificações';

  @override
  String get channelOptionsUnmuteNotifications => 'Ativar Notificações';

  @override
  String get channelOptionsViewKey => 'Ver chave de criptografia';

  @override
  String get channelOptionsViewQr => 'Ver Código QR';

  @override
  String get channelOptionsViewQrInfo =>
      'Digitalize este código QR no Socialmesh para entrar neste canal';

  @override
  String get channelShareCreatingInvite => 'Criando link de convite...';

  @override
  String channelShareDefaultName(int index) {
    return 'Canal $index';
  }

  @override
  String get channelShareInviteCopied =>
      'Link de convite copiado para a área de transferência';

  @override
  String get channelShareInviteFailed => 'Falha ao criar link de convite';

  @override
  String get channelShareMessage => 'Entre no meu canal no SocialMesh!';

  @override
  String get channelShareQrInfo =>
      'Escaneie este código QR no SocialMesh para importar este canal';

  @override
  String get channelShareSignInAction => 'Entrar';

  @override
  String get channelShareSignInRequired => 'Entre para compartilhar canais';

  @override
  String channelShareSubject(String channelName) {
    return 'Canal SocialMesh: $channelName';
  }

  @override
  String get channelShareTitle => 'Compartilhar canal';

  @override
  String get channelWizardBackButton => 'Voltar';

  @override
  String get channelWizardCompatMax =>
      'Segurança máxima. Certifique-se de que todos os participantes suportam criptografia AES-256.';

  @override
  String get channelWizardCompatOpen =>
      'Compatível com todos os dispositivos. Nenhuma troca de chaves necessária.';

  @override
  String get channelWizardCompatPrivate =>
      'Recomendado. Compartilhe o código QR de forma segura com as pessoas com quem deseja se comunicar.';

  @override
  String get channelWizardCompatShared =>
      'Usa a chave Meshtastic padrão. Outros usuários com configurações padrão podem interceptar mensagens.';

  @override
  String get channelWizardDefaultKeyWarningTitle => 'Default Key Warning';

  @override
  String get channelWizardDefaultKeyWarningBody =>
      'The shared default key is publicly known. Anyone with a Meshtastic device using default settings can read messages on this channel.\n\nThis is fine for public community channels, but not recommended for private conversations.';

  @override
  String get channelWizardDefaultKeyKeep => 'Keep Default Key';

  @override
  String get channelWizardDefaultKeyUpgrade => 'Upgrade to Private Key';

  @override
  String get channelWizardContinueButton => 'Continuar';

  @override
  String get channelWizardCopyUrlButton => 'Copiar URL';

  @override
  String get channelWizardCreateButton => 'Criar canal';

  @override
  String channelWizardCreateFailed(String error) {
    return 'Falha ao criar canal: $error';
  }

  @override
  String get channelWizardCreatedHeading => 'Canal criado!';

  @override
  String get channelWizardCreatedSubtitle =>
      'Compartilhe este código QR com outros para que possam entrar.';

  @override
  String get channelWizardCreating => 'Criando canal...';

  @override
  String get channelWizardDefaultKey => 'Chave padrão';

  @override
  String get channelWizardDeviceNotConnected =>
      'Não é possível salvar o canal: dispositivo não conectado';

  @override
  String get channelWizardDisabled => 'Desabilitado';

  @override
  String get channelWizardDoneButton => 'Concluído';

  @override
  String get channelWizardDownlinkSubtitle =>
      'Receber mensagens do MQTT e transmiti-las neste canal.';

  @override
  String get channelWizardDownlinkTitle => 'Downlink habilitado';

  @override
  String get channelWizardEnabled => 'Habilitado';

  @override
  String get channelWizardEncryptionKeyLabel => 'Chave de criptografia';

  @override
  String get channelWizardHelpTooltip => 'Ajuda';

  @override
  String channelWizardKeyBits(int bits) {
    return '$bits bits';
  }

  @override
  String get channelWizardKeySizeAes128 => 'AES-128';

  @override
  String get channelWizardKeySizeAes128Desc =>
      'Criptografia forte - recomendada para a maioria dos usos';

  @override
  String get channelWizardKeySizeAes256 => 'AES-256';

  @override
  String get channelWizardKeySizeAes256Desc =>
      'Criptografia máxima - segurança mais elevada';

  @override
  String get channelWizardKeySizeDefault => 'Padrão';

  @override
  String get channelWizardKeySizeDefaultDesc =>
      'Chave compartilhada simples - compatível mas não segura';

  @override
  String get channelWizardKeySizeNone => 'Nenhuma';

  @override
  String get channelWizardKeySizeNoneDesc =>
      'Sem criptografia - mensagens enviadas em texto simples';

  @override
  String get channelWizardMqttFloodWarning =>
      'A maioria dos dispositivos tem capacidade de processamento e RAM muito limitadas. Conectar um canal movimentado como LongFast pelo servidor MQTT padrão pode inundar o dispositivo com 15-25 pacotes por segundo, fazendo-o parar de responder. Considere usar um broker privado ou um canal mais tranquilo.';

  @override
  String get channelWizardMqttHeader => 'Configurações MQTT';

  @override
  String get channelWizardMqttWarning =>
      'O MQTT deve estar configurado no seu dispositivo para que uplink/downlink funcionem.';

  @override
  String get channelWizardNameBannerInfo =>
      'Nomes de canais são limitados a 12 caracteres alfanuméricos.';

  @override
  String get channelWizardNameHeading => 'Nomeie seu canal';

  @override
  String get channelWizardNameHint => 'ex. Família, Amigos, Trilha';

  @override
  String get channelWizardNameLabel => 'Nome do canal';

  @override
  String get channelWizardNameSubtitle =>
      'Escolha um nome que ajude a identificar este canal. Ele será visível para qualquer pessoa que entrar.';

  @override
  String get channelWizardNoKey => 'Sem chave';

  @override
  String get channelWizardOptionsHeading => 'Opções avançadas';

  @override
  String get channelWizardOptionsSubtitle =>
      'Configure as opções avançadas do canal.';

  @override
  String get channelWizardPositionSubtitle =>
      'Compartilhe sua posição neste canal.';

  @override
  String get channelWizardPositionTitle => 'Posição habilitada';

  @override
  String get channelWizardPrivacyHeading => 'Escolha o nível de privacidade';

  @override
  String get channelWizardPrivacyMaxDesc =>
      'Criptografia AES-256 para segurança máxima. Ideal para comunicações sensíveis. Consumo de bateria levemente maior.';

  @override
  String get channelWizardPrivacyMaxTitle => 'Segurança máxima';

  @override
  String get channelWizardPrivacyOpenDesc =>
      'Sem criptografia. Qualquer pessoa com um rádio compatível pode ler suas mensagens. Use apenas para transmissões públicas.';

  @override
  String get channelWizardPrivacyOpenTitle => 'Canal aberto';

  @override
  String get channelWizardPrivacyPrivateDesc =>
      'Criptografia AES-128 com chave aleatória. Somente pessoas com quem você compartilhar o código QR podem entrar. Recomendado para a maioria dos usos.';

  @override
  String get channelWizardPrivacyPrivateTitle => 'Canal privado';

  @override
  String get channelWizardPrivacySharedDesc =>
      'Usa a conhecida chave padrão. Outros usuários Meshtastic podem ler as mensagens. Bom para canais comunitários.';

  @override
  String get channelWizardPrivacySharedTitle => 'Canal compartilhado';

  @override
  String get channelWizardPrivacySubtitle =>
      'Selecione o nível de segurança desejado para este canal. Maior segurança usa criptografia mais forte.';

  @override
  String get channelWizardRadioComplianceLink =>
      'Ver regras de conformidade de rádio';

  @override
  String get channelWizardReviewEncryption => 'Criptografia';

  @override
  String get channelWizardReviewHeading => 'Revisar e criar';

  @override
  String get channelWizardReviewKeySize => 'Tamanho da chave';

  @override
  String get channelWizardReviewMqttDownlink => 'MQTT Downlink';

  @override
  String get channelWizardReviewMqttUplink => 'MQTT Uplink';

  @override
  String get channelWizardReviewName => 'Nome';

  @override
  String get channelWizardReviewPositionSharing =>
      'Compartilhamento de posição';

  @override
  String get channelWizardReviewPrivacyLevel => 'Nível de privacidade';

  @override
  String get channelWizardReviewSubtitle =>
      'Revise as configurações do canal antes de criar.';

  @override
  String get channelWizardScreenTitle => 'Criar canal';

  @override
  String get channelWizardStepNameContent =>
      'Escolha um nome memorável para seu canal.\n\n• Nomes são limitados a 12 caracteres\n• Somente letras e números permitidos\n• O nome é visível para qualquer pessoa que entrar\n• Escolha algo descritivo como \"Família\" ou \"Trilha\"';

  @override
  String get channelWizardStepNameTitle => 'Nome do canal';

  @override
  String get channelWizardStepOptionsContent =>
      'Configure as opções avançadas do canal.\n\n• Compartilhamento de posição: permitir compartilhamento de localização neste canal\n• MQTT Uplink: enviar mensagens para a internet (requer configuração MQTT)\n• MQTT Downlink: receber mensagens da internet\n• Chave de criptografia: gerada automaticamente, mas você pode colar uma chave personalizada\n\nA maioria dos usuários pode pular estas opções avançadas.';

  @override
  String get channelWizardStepOptionsTitle => 'Opções avançadas';

  @override
  String get channelWizardStepPrivacyContent =>
      'Selecione o nível de segurança do canal.\n\n• ABERTO: sem criptografia - qualquer pessoa pode ler as mensagens\n• COMPARTILHADO: usa a chave Meshtastic padrão - não é privado\n• PRIVADO (Recomendado): chave AES-128 única - seguro\n• MÁXIMO: criptografia AES-256 - segurança mais elevada\n\nMaior segurança requer compartilhar a chave do canal.';

  @override
  String get channelWizardStepPrivacyTitle => 'Nível de privacidade';

  @override
  String get channelWizardStepReviewContent =>
      'Revise as configurações do canal antes de criar.\n\n• Verifique se o nome e o nível de privacidade estão corretos\n• Após a criação, compartilhe o código QR com outros\n• Outros escaneiam o código QR para entrar no canal\n• Você também pode copiar a URL para compartilhar por mensagem';

  @override
  String get channelWizardStepReviewTitle => 'Revisar e criar';

  @override
  String get channelWizardSummaryEncryption => 'Criptografia';

  @override
  String get channelWizardSummaryName => 'Nome';

  @override
  String get channelWizardSummaryPrivacy => 'Privacidade';

  @override
  String get channelWizardUplinkSubtitle =>
      'Enviar mensagens deste canal para MQTT quando conectado à internet.';

  @override
  String get channelWizardUplinkTitle => 'Uplink habilitado';

  @override
  String get channelWizardUrlCopied =>
      'URL do canal copiada para a área de transferência';

  @override
  String get channelsClearSearch => 'Limpar busca';

  @override
  String channelsDefaultChannelName(int index) {
    return 'Canal $index';
  }

  @override
  String get channelsEmpty => 'Nenhum canal configurado';

  @override
  String get channelsEmptySubtitle =>
      'Os canais ainda estão sendo carregados do dispositivo\nou use os ícones acima para adicionar canais';

  @override
  String get channelsFilterAll => 'Todos';

  @override
  String get channelsFilterEncrypted => 'Criptografados';

  @override
  String get channelsFilterMqtt => 'MQTT';

  @override
  String get channelsFilterPosition => 'Posição';

  @override
  String get channelsFilterPrimary => 'Primário';

  @override
  String get channelsMenuAddChannel => 'Adicionar canal';

  @override
  String get channelsMenuHelp => 'Ajuda';

  @override
  String get channelsMenuScanQrCode => 'Escanear código QR';

  @override
  String get channelsMenuSettings => 'Configurações';

  @override
  String channelsNoMatch(String query) {
    return 'Nenhum canal corresponde a \"$query\"';
  }

  @override
  String get channelsPrimaryChannelName => 'Canal primário';

  @override
  String channelsScreenTitle(int count) {
    return 'Canais ($count)';
  }

  @override
  String get channelsSearchHint => 'Buscar canais';

  @override
  String get channelsTileEncrypted => 'Criptografado';

  @override
  String get channelsTileNoEncryption => 'Sem criptografia';

  @override
  String get channelsTilePrimaryBadge => 'PRIMÁRIO';

  @override
  String get channelsUnreadOverflow => '99+';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonDone => 'Concluído';

  @override
  String commonErrorWithDetails(String error) {
    return 'Erro: $error';
  }

  @override
  String get commonGoBack => 'Voltar';

  @override
  String get commonNext => 'Próximo';

  @override
  String get commonNever => 'Nunca';

  @override
  String get commonJustNow => 'Agora';

  @override
  String commonMinutesAgo(int count) {
    return '${count}m atrás';
  }

  @override
  String commonHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String commonDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String commonHopsSingular(int count) {
    return '$count salto';
  }

  @override
  String commonHopsPlural(int count) {
    return '$count saltos';
  }

  @override
  String nodeInfoLatitude(String value) {
    return 'Lat: $value°';
  }

  @override
  String nodeInfoLongitude(String value) {
    return 'Lon: $value°';
  }

  @override
  String get nodeInfoNotAvailable => 'N/D';

  @override
  String get nodeInfoYou => 'VOCÊ';

  @override
  String get nodeInfoPosition => 'Posição';

  @override
  String get nodeInfoMessage => 'Mensagem';

  @override
  String get nodeInfoTraceroute => 'Traceroute';

  @override
  String get nodeInfoViewDetails => 'Ver Detalhes';

  @override
  String get nodeInfoViewHistory => 'Histórico de Traceroute';

  @override
  String get nodeInfoShowTrack => 'Mostrar histórico de posições';

  @override
  String get nodeInfoHideTrack => 'Ocultar histórico de posições';

  @override
  String get nodeInfoViewPositionLog => 'Registo de posições';

  @override
  String get nodeInfoShareLocation => 'Partilhar Localização';

  @override
  String get nodeInfoCopyCoordinates => 'Copiar Coordenadas';

  @override
  String get nodeInfoPositionConfirmTitle => 'Solicitar Posição';

  @override
  String nodeInfoPositionConfirmMessage(String name) {
    return 'Solicitar a posição atual de $name pela mesh?';
  }

  @override
  String get nodeInfoShareConfirmTitle => 'Partilhar Localização';

  @override
  String get nodeInfoShareConfirmMessage =>
      'Partilhar as coordenadas deste nó como um link?';

  @override
  String get nodeInfoTracerouteConfirmTitle => 'Enviar Traceroute';

  @override
  String nodeInfoTracerouteConfirmMessage(String name) {
    return 'Enviar um pacote traceroute para $name? Isto usa tempo de antena da mesh.';
  }

  @override
  String get nodeInfoLegendTitle => 'Action Legend';

  @override
  String get nodeInfoLegendPosition =>
      'Request the node\'s current GPS position over the mesh.';

  @override
  String get nodeInfoLegendMessage =>
      'Open a direct message conversation with this node.';

  @override
  String get nodeInfoLegendShare =>
      'Share this node\'s coordinates as a link via the system share sheet.';

  @override
  String get nodeInfoLegendCopy =>
      'Copy the node\'s GPS coordinates to the clipboard.';

  @override
  String get nodeInfoLegendTraceroute =>
      'Send a traceroute packet to discover the route to this node.';

  @override
  String get nodeInfoLegendViewDetails =>
      'Open the full detail screen for this node.';

  @override
  String get nodeInfoLegendHistory =>
      'View the traceroute history for this node.';

  @override
  String get nodeInfoLegendTrack =>
      'Toggle the node\'s position track polyline on the map.';

  @override
  String get nodeInfoLegendPositionLog =>
      'View the full position log for this node.';

  @override
  String get bindingSelectorNoResults => 'Nenhuma variável encontrada';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonSave => 'Salvar';

  @override
  String get debugScreenAppLogTitle => 'Log do app';

  @override
  String get debugScreenApply => 'Aplicar';

  @override
  String get debugScreenAutoScrollOff => 'Rolagem automática desativada';

  @override
  String get debugScreenAutoScrollOn => 'Rolagem automática ativada';

  @override
  String get debugScreenClear => 'Limpar';

  @override
  String get debugScreenClearLogsMenuItem => 'Limpar logs';

  @override
  String get debugScreenClearLogsMessage =>
      'Tem certeza de que deseja limpar todos os logs?';

  @override
  String get debugScreenClearLogsTitle => 'Limpar logs';

  @override
  String get debugScreenClearMenuItem => 'Limpar';

  @override
  String get debugScreenCopy => 'Copiar';

  @override
  String get debugScreenCopyToClipboard => 'Copiar para área de transferência';

  @override
  String get debugScreenDebugExportMessage =>
      'Esta exportação inclui info do dispositivo, estado da conexão, lista de nós, metadados de rotas e logs recentes.\n\nO texto das mensagens é ocultado e as coordenadas GPS são aproximadas. Revise o arquivo antes de compartilhar.';

  @override
  String get debugScreenDebugExportTitle => 'Exportação de debug';

  @override
  String get debugScreenDeviceApply => 'Aplicar';

  @override
  String get debugScreenDeviceAutoScrollOff => 'Rolagem automática OFF';

  @override
  String get debugScreenDeviceAutoScrollOn => 'Rolagem automática ON';

  @override
  String get debugScreenDeviceClear => 'Limpar';

  @override
  String get debugScreenDeviceClearMessage =>
      'Tem certeza de que deseja limpar todos os logs do dispositivo?';

  @override
  String get debugScreenDeviceClearTitle => 'Limpar logs';

  @override
  String debugScreenDeviceEntryCount(int count) {
    return '$count entradas';
  }

  @override
  String get debugScreenDeviceFilterSubtitle => 'Selecione os níveis a exibir';

  @override
  String get debugScreenDeviceFilterTitle => 'Filtrar níveis de log';

  @override
  String get debugScreenDeviceLogsCopied =>
      'Logs do dispositivo copiados para a área de transferência';

  @override
  String get debugScreenDeviceLogsTitle => 'Logs do dispositivo';

  @override
  String get debugScreenDeviceSearchHint => 'Buscar nos logs...';

  @override
  String debugScreenEntryCount(int count) {
    return '$count entradas';
  }

  @override
  String get debugScreenExport => 'Exportar';

  @override
  String get debugScreenExportDebugJson => 'Exportar JSON de debug';

  @override
  String debugScreenExportFailed(String error) {
    return 'Exportação falhou: $error';
  }

  @override
  String get debugScreenFilter => 'Filtrar';

  @override
  String get debugScreenFilterLevelsTooltip => 'Filtrar níveis';

  @override
  String get debugScreenFilterLogLevels => 'Filtrar níveis de log';

  @override
  String get debugScreenFilterSubtitle => 'Selecione os níveis a exibir';

  @override
  String get debugScreenFiltered => 'Filtrado';

  @override
  String get debugScreenGeneratingExport => 'Gerando exportação de debug...';

  @override
  String get debugScreenLogCopied => 'Log copiado para a área de transferência';

  @override
  String get debugScreenLogsWillAppear =>
      'Os logs aparecerão aqui quando o dispositivo enviá-los';

  @override
  String get debugScreenNoDeviceLogs => 'Nenhum log do dispositivo';

  @override
  String get debugScreenNoLogEntries => 'Nenhuma entrada de log';

  @override
  String get debugScreenSearchLogsHint => 'Buscar nos logs...';

  @override
  String get debugScreenShare => 'Compartilhar';

  @override
  String get debugScreenShareLog => 'Compartilhar log';

  @override
  String get debugScreenStreamingBanner =>
      'Transmitindo logs de debug do firmware do dispositivo conectado via BLE';

  @override
  String get deviceConfigBleName => 'Nome BLE';

  @override
  String get deviceConfigBroadcastEighteenHours => 'Dezoito horas';

  @override
  String get deviceConfigBroadcastFiveHours => 'Cinco horas';

  @override
  String get deviceConfigBroadcastFortyEightHours => 'Quarenta e oito horas';

  @override
  String get deviceConfigBroadcastFourHours => 'Quatro horas';

  @override
  String get deviceConfigBroadcastInterval => 'Intervalo de transmissão';

  @override
  String get deviceConfigBroadcastIntervalSubtitle =>
      'Frequência de transmissão de info do nó para a mesh';

  @override
  String get deviceConfigBroadcastNever => 'Nunca';

  @override
  String get deviceConfigBroadcastSeventyTwoHours => 'Setenta e duas horas';

  @override
  String get deviceConfigBroadcastSixHours => 'Seis horas';

  @override
  String get deviceConfigBroadcastThirtySixHours => 'Trinta e seis horas';

  @override
  String get deviceConfigBroadcastThreeHours => 'Três horas';

  @override
  String get deviceConfigBroadcastTwelveHours => 'Doze horas';

  @override
  String get deviceConfigBroadcastTwentyFourHours => 'Vinte e quatro horas';

  @override
  String get deviceConfigButtonGpio => 'GPIO do botão';

  @override
  String get deviceConfigBuzzerAllEnabled => 'Tudo ativado';

  @override
  String get deviceConfigBuzzerAllEnabledDesc =>
      'O buzzer soa para todos os feedbacks, incluindo botões e alertas.';

  @override
  String get deviceConfigBuzzerDirectMsgOnly => 'Somente mensagens diretas';

  @override
  String get deviceConfigBuzzerDirectMsgOnlyDesc =>
      'Buzzer apenas para mensagens diretas e alertas.';

  @override
  String get deviceConfigBuzzerDisabled => 'Desativado';

  @override
  String get deviceConfigBuzzerDisabledDesc =>
      'Todo feedback sonoro do buzzer está desativado.';

  @override
  String get deviceConfigBuzzerGpio => 'GPIO do buzzer';

  @override
  String get deviceConfigBuzzerNotificationsOnly => 'Somente notificações';

  @override
  String get deviceConfigBuzzerNotificationsOnlyDesc =>
      'Buzzer apenas para notificações e alertas, não para pressionamento de botões.';

  @override
  String get deviceConfigBuzzerSystemOnly => 'Somente sistema';

  @override
  String get deviceConfigBuzzerSystemOnlyDesc =>
      'Apenas pressionamento de botões, inicialização e desligamento. Sem alertas.';

  @override
  String get deviceConfigDisableLedHeartbeat => 'Desativar LED heartbeat';

  @override
  String get deviceConfigDisableLedHeartbeatSubtitle =>
      'Desliga o LED de status piscante';

  @override
  String get deviceConfigDisableTripleClick => 'Desativar triplo clique';

  @override
  String get deviceConfigDisableTripleClickSubtitle =>
      'Desativa o triplo clique para alternar o GPS';

  @override
  String get deviceConfigDoubleTapAsButton => 'Toque duplo como botão';

  @override
  String get deviceConfigDoubleTapAsButtonSubtitle =>
      'Tratar toque duplo do acelerômetro como pressionamento de botão';

  @override
  String get deviceConfigFactoryReset => 'Restauração de fábrica';

  @override
  String get deviceConfigFactoryResetDialogConfirm => 'Restauração de fábrica';

  @override
  String get deviceConfigFactoryResetDialogMessage =>
      'Isso redefinirá TODAS as configurações para os padrões de fábrica, incluindo canais, configuração e dados armazenados.\n\nEsta ação não pode ser desfeita!';

  @override
  String get deviceConfigFactoryResetDialogTitle => 'Restauração de fábrica';

  @override
  String deviceConfigFactoryResetError(String error) {
    return 'Falha ao restaurar: $error';
  }

  @override
  String get deviceConfigFactoryResetSubtitle =>
      'Restaurar dispositivo para os padrões de fábrica';

  @override
  String get deviceConfigFactoryResetSuccess =>
      'Restauração iniciada - o dispositivo será reiniciado';

  @override
  String get deviceConfigFrequencyOverride => 'Override de frequência (MHz)';

  @override
  String get deviceConfigFrequencyOverrideHint => '0.0 (usar padrão)';

  @override
  String get deviceConfigGpioWarning =>
      'Altere estes valores apenas se o seu hardware exigir pinos GPIO personalizados.';

  @override
  String get deviceConfigHamModeInfo =>
      'O modo Ham usa o nome longo como indicativo (máx. 8 caracteres), transmite info do nó a cada 10 minutos, sobrescreve frequência, duty cycle e potência TX, e desativa a criptografia.';

  @override
  String get deviceConfigHamModeWarning =>
      'Nós HAM não podem encaminhar tráfego criptografado. Outros nós não-HAM na mesh não poderão rotear mensagens criptografadas por este nó, criando uma lacuna na rede.';

  @override
  String get deviceConfigHardware => 'Hardware';

  @override
  String get deviceConfigLicensedOperator => 'Operador licenciado (Ham)';

  @override
  String get deviceConfigLicensedOperatorSubtitle =>
      'Define indicativo, sobrescreve frequência/potência, desativa criptografia';

  @override
  String get deviceConfigLongName => 'Nome longo';

  @override
  String get deviceConfigLongNameHint => 'Insira o nome de exibição';

  @override
  String get deviceConfigLongNameSubtitle => 'Nome de exibição visível na mesh';

  @override
  String get deviceConfigNameHelpText =>
      'O nome do dispositivo é transmitido para a mesh e visível para outros nós.';

  @override
  String get deviceConfigNodeNumber => 'Número do nó';

  @override
  String get deviceConfigPosixTimezone => 'Fuso horário POSIX';

  @override
  String get deviceConfigPosixTimezoneExample => 'ex. EST5EDT,M3.2.0,M11.1.0';

  @override
  String get deviceConfigPosixTimezoneHint => 'Deixe vazio para UTC';

  @override
  String get deviceConfigRebootWarning =>
      'Alterações na configuração do dispositivo causarão a reinicialização.';

  @override
  String get deviceConfigRebroadcastAll => 'Todos';

  @override
  String get deviceConfigRebroadcastAllDesc =>
      'Retransmitir qualquer mensagem observada. Comportamento padrão.';

  @override
  String get deviceConfigRebroadcastAllSkipDecoding =>
      'Todos (sem decodificação)';

  @override
  String get deviceConfigRebroadcastAllSkipDecodingDesc =>
      'Retransmitir todas as mensagens sem decodificar. Mais rápido, menos CPU.';

  @override
  String get deviceConfigRebroadcastCorePortnumsOnly => 'Somente portas core';

  @override
  String get deviceConfigRebroadcastCorePortnumsOnlyDesc =>
      'Retransmitir apenas pacotes core Meshtastic (posição, telemetria, etc.).';

  @override
  String get deviceConfigRebroadcastKnownOnly => 'Somente nós conhecidos';

  @override
  String get deviceConfigRebroadcastKnownOnlyDesc =>
      'Retransmitir apenas mensagens de nós presentes no banco de dados.';

  @override
  String get deviceConfigRebroadcastLocalOnly => 'Somente locais';

  @override
  String get deviceConfigRebroadcastLocalOnlyDesc =>
      'Retransmitir apenas mensagens de remetentes locais. Ideal para redes isoladas.';

  @override
  String get deviceConfigRebroadcastNone => 'Nenhum';

  @override
  String get deviceConfigRebroadcastNoneDesc =>
      'Não retransmitir nenhuma mensagem. O nó apenas recebe.';

  @override
  String deviceConfigRemoteAdminConfiguring(String nodeName) {
    return 'Configurando: $nodeName';
  }

  @override
  String get deviceConfigRemoteAdminTitle => 'Administração remota';

  @override
  String get deviceConfigResetNodeDb => 'Redefinir banco de dados de nós';

  @override
  String get deviceConfigResetNodeDbDialogConfirm => 'Redefinir';

  @override
  String get deviceConfigResetNodeDbDialogMessage =>
      'Isso limpará todas as informações de nós armazenadas no dispositivo. A rede mesh precisará redescobrir todos os nós.\n\nTem certeza de que deseja continuar?';

  @override
  String get deviceConfigResetNodeDbDialogTitle =>
      'Redefinir banco de dados de nós';

  @override
  String deviceConfigResetNodeDbError(String error) {
    return 'Falha ao redefinir: $error';
  }

  @override
  String get deviceConfigResetNodeDbSubtitle =>
      'Limpar todas as informações de nós armazenadas';

  @override
  String get deviceConfigResetNodeDbSuccess =>
      'Redefinição do banco de dados de nós iniciada';

  @override
  String get deviceConfigRoleClient => 'Cliente';

  @override
  String get deviceConfigRoleClientBase => 'Base de Cliente';

  @override
  String get deviceConfigRoleClientBaseDesc =>
      'Estação base para nós favoritos. Roteia pacotes deles como router, os demais como client.';

  @override
  String get deviceConfigRoleClientDesc =>
      'Função padrão. Pacotes mesh são roteados por este nó. Pode enviar e receber mensagens.';

  @override
  String get deviceConfigRoleClientHidden => 'Client oculto';

  @override
  String get deviceConfigRoleClientHiddenDesc =>
      'Age como client mas se oculta da lista de nós. Ainda roteia tráfego.';

  @override
  String get deviceConfigRoleClientMute => 'Client silencioso';

  @override
  String get deviceConfigRoleClientMuteDesc =>
      'Igual ao client mas não transmite mensagens próprias. Útil para monitoramento.';

  @override
  String get deviceConfigRoleLostAndFound => 'Achados e perdidos';

  @override
  String get deviceConfigRoleLostAndFoundDesc =>
      'Otimizado para encontrar dispositivos perdidos. Envia beacons periódicos.';

  @override
  String get deviceConfigRoleRouter => 'Router';

  @override
  String get deviceConfigRoleRouterDesc =>
      'Roteia pacotes mesh entre nós. Tela e Bluetooth desativados para economizar energia.';

  @override
  String get deviceConfigRoleRouterLate => 'Router atrasado';

  @override
  String get deviceConfigRoleRouterLateDesc =>
      'Retransmite todos os pacotes após outros routers. Estende a cobertura sem consumir saltos prioritários.';

  @override
  String get deviceConfigRoleSensor => 'Sensor';

  @override
  String get deviceConfigRoleSensorDesc =>
      'Projetado para sensoriamento remoto. Envia dados de telemetria em intervalos definidos.';

  @override
  String get deviceConfigRoleTak => 'TAK';

  @override
  String get deviceConfigRoleTakDesc =>
      'Integração Team Awareness Kit. Conecta sistemas Meshtastic e TAK.';

  @override
  String get deviceConfigRoleTakTracker => 'TAK Tracker';

  @override
  String get deviceConfigRoleTakTrackerDesc =>
      'Combinação dos modos TAK e Tracker.';

  @override
  String get deviceConfigRoleTracker => 'Tracker';

  @override
  String get deviceConfigRoleTrackerDesc =>
      'Otimizado para rastreamento GPS. Envia atualizações de posição em intervalos definidos.';

  @override
  String get deviceConfigSave => 'Salvar';

  @override
  String get deviceConfigSaveAndReboot => 'Salvar e reiniciar';

  @override
  String get deviceConfigSaveChangesMessage =>
      'Salvar a configuração causará a reinicialização do dispositivo. Você será brevemente desconectado durante a reinicialização.';

  @override
  String get deviceConfigSaveChangesTitle => 'Salvar alterações?';

  @override
  String deviceConfigSaveError(String error) {
    return 'Erro ao salvar configuração: $error';
  }

  @override
  String get deviceConfigSavedLocal =>
      'Configuração salva - dispositivo reiniciando';

  @override
  String get deviceConfigSavedRemote => 'Configuração enviada ao nó remoto';

  @override
  String get deviceConfigSectionButtonInput => 'Botão e entrada';

  @override
  String get deviceConfigSectionBuzzer => 'Buzzer';

  @override
  String get deviceConfigSectionDangerZone => 'Zona de perigo';

  @override
  String get deviceConfigSectionDeviceInfo => 'Info do dispositivo';

  @override
  String get deviceConfigSectionDeviceRole => 'Função do dispositivo';

  @override
  String get deviceConfigSectionGpio => 'GPIO (Avançado)';

  @override
  String get deviceConfigSectionLed => 'LED';

  @override
  String get deviceConfigSectionNodeInfoBroadcast =>
      'Transmissão de info do nó';

  @override
  String get deviceConfigSectionRebroadcastMode => 'Modo de retransmissão';

  @override
  String get deviceConfigSectionSerial => 'Serial';

  @override
  String get deviceConfigSectionTimezone => 'Fuso horário';

  @override
  String get deviceConfigSectionUserFlags => 'Flags do usuário';

  @override
  String get deviceConfigSerialConsole => 'Console serial';

  @override
  String get deviceConfigSerialConsoleSubtitle =>
      'Ativar porta serial para debug';

  @override
  String get deviceConfigShortName => 'Nome curto';

  @override
  String get deviceConfigShortNameHint => 'ex. FUZZ';

  @override
  String deviceConfigShortNameSubtitle(int maxLength) {
    return 'Máx. $maxLength caracteres (A-Z, 0-9)';
  }

  @override
  String get deviceConfigTitle => 'Configuração do dispositivo';

  @override
  String get deviceConfigTitleRemote => 'Configuração do dispositivo (remoto)';

  @override
  String get deviceConfigTxPower => 'Potência TX';

  @override
  String deviceConfigTxPowerValue(int power) {
    return '$power dBm';
  }

  @override
  String get deviceConfigUnknown => 'Desconhecido';

  @override
  String get deviceConfigUnmessagable => 'Não mensagável';

  @override
  String get deviceConfigUnmessagableSubtitle =>
      'Marcar como nó de infraestrutura que não responde a mensagens';

  @override
  String get deviceConfigUserId => 'ID do Usuário';

  @override
  String get deviceSheetActionAppSettings => 'Configurações do App';

  @override
  String get deviceSheetActionAppSettingsSubtitle =>
      'Notificações, tema, preferências';

  @override
  String get deviceSheetActionDeviceConfig => 'Config. do Dispositivo';

  @override
  String get deviceSheetActionDeviceConfigSubtitle =>
      'Configurar função e definições do dispositivo';

  @override
  String get deviceSheetActionDeviceManagement =>
      'Gerenciamento do Dispositivo';

  @override
  String get deviceSheetActionDeviceManagementSubtitle =>
      'Reiniciar, desligar, restaurar padrão de fábrica';

  @override
  String get deviceSheetActionResetNodeDb => 'Redefinir Banco de Nós';

  @override
  String get deviceSheetActionResetNodeDbSubtitle =>
      'Limpar todos os nós aprendidos do dispositivo';

  @override
  String get deviceSheetActionScanQr => 'Escanear Código QR';

  @override
  String get deviceSheetActionScanQrSubtitle =>
      'Importar nós, canais ou automações';

  @override
  String get deviceSheetAddress => 'Endereço';

  @override
  String get deviceSheetBattery => 'Bateria';

  @override
  String deviceSheetBatteryPercent(String percent) {
    return '$percent%';
  }

  @override
  String get deviceSheetBatteryRefreshFailed => 'Falhou';

  @override
  String get deviceSheetBatteryRefreshIdle => 'Obter bateria do dispositivo';

  @override
  String deviceSheetBatteryRefreshResult(String percent, String millivolts) {
    return '$percent%$millivolts';
  }

  @override
  String get deviceSheetBluetoothLe => 'Bluetooth LE';

  @override
  String get deviceSheetCharging => 'Carregando';

  @override
  String get deviceSheetConnected => 'Conectado';

  @override
  String get deviceSheetConnecting => 'Conectando...';

  @override
  String get deviceSheetConnectionType => 'Tipo de Conexão';

  @override
  String get deviceSheetDeviceName => 'Nome do Dispositivo';

  @override
  String get deviceSheetDisconnectButton => 'Desconectar';

  @override
  String get deviceSheetDisconnectDialogConfirm => 'Desconectar';

  @override
  String get deviceSheetDisconnectDialogMessage =>
      'Tem certeza de que deseja desconectar deste dispositivo?';

  @override
  String get deviceSheetDisconnectDialogTitle => 'Desconectar';

  @override
  String get deviceSheetDisconnected => 'Desconectado';

  @override
  String get deviceSheetDisconnecting => 'Desconectando...';

  @override
  String get deviceSheetDisconnectingButton => 'Desconectando...';

  @override
  String get deviceSheetError => 'Erro';

  @override
  String get deviceSheetFirmware => 'Firmware';

  @override
  String get deviceSheetInfoCardConnected => 'Conectado';

  @override
  String get deviceSheetInfoCardConnecting => 'Conectando...';

  @override
  String get deviceSheetInfoCardConnectionError => 'Erro de Conexão';

  @override
  String get deviceSheetInfoCardDisconnected => 'Desconectado';

  @override
  String get deviceSheetInfoCardDisconnecting => 'Desconectando...';

  @override
  String get deviceSheetNoDevice => 'Nenhum Dispositivo';

  @override
  String get deviceSheetNodeId => 'ID do Nó';

  @override
  String get deviceSheetNodeName => 'Nome do Nó';

  @override
  String get deviceSheetProtocol => 'Protocolo';

  @override
  String get deviceSheetReconnecting => 'Reconectando...';

  @override
  String get deviceSheetRefreshBattery => 'Atualizar Bateria';

  @override
  String get deviceSheetRefreshingBattery => 'Atualizando bateria...';

  @override
  String get deviceSheetResetNodeDbDialogConfirm => 'Redefinir';

  @override
  String get deviceSheetResetNodeDbDialogMessage =>
      'Isso limpará todos os nós aprendidos do dispositivo e do app. O dispositivo precisará redescobrir os nós na rede mesh.\n\nTem certeza de que deseja continuar?';

  @override
  String get deviceSheetResetNodeDbDialogTitle => 'Redefinir Banco de Nós';

  @override
  String deviceSheetResetNodeDbError(String error) {
    return 'Falha ao redefinir banco de nós: $error';
  }

  @override
  String get deviceSheetResetNodeDbSuccess =>
      'Banco de nós redefinido com sucesso';

  @override
  String get deviceSheetScanForDevices => 'Buscar Dispositivos';

  @override
  String get deviceSheetSectionConnectionDetails => 'Detalhes da Conexão';

  @override
  String get deviceSheetSectionDeveloperTools => 'Ferramentas do Desenvolvedor';

  @override
  String get deviceSheetSectionQuickActions => 'Ações Rápidas';

  @override
  String get deviceSheetSignalStrength => 'Intensidade do Sinal';

  @override
  String deviceSheetSignalStrengthValue(String rssi) {
    return '$rssi dBm';
  }

  @override
  String get deviceSheetStatus => 'Estado';

  @override
  String get deviceSheetUnknown => 'Desconhecido';

  @override
  String get deviceSheetUsb => 'USB';

  @override
  String get deviceShopBecomeSeller => 'Torne-se Vendedor';

  @override
  String get deviceShopBecomeSellerBody =>
      'Você é fabricante ou distribuidor de dispositivos compatíveis com Meshtastic? Junte-se ao nosso marketplace para alcançar entusiastas de rádio mesh em todo o mundo.';

  @override
  String get deviceShopBrowseByCategory => 'Navegar por Categoria';

  @override
  String get deviceShopCategories => 'Categorias';

  @override
  String get deviceShopClear => 'Limpar';

  @override
  String get deviceShopConnectToBrowse =>
      'Conecte-se para navegar dispositivos';

  @override
  String get deviceShopContactUs => 'Fale Conosco';

  @override
  String get deviceShopErrorLoadingProducts => 'Erro ao carregar produtos';

  @override
  String get deviceShopFavoritesTooltip => 'Favoritos';

  @override
  String get deviceShopFeatured => 'Destaques';

  @override
  String get deviceShopHelpTooltip => 'Ajuda';

  @override
  String get deviceShopMarketplaceDisclaimer =>
      'As compras são concluídas na loja oficial do vendedor. Socialmesh não gerencia pagamento, envio, garantia ou devoluções.';

  @override
  String get deviceShopMarketplaceInfoTitle => 'Informações do Marketplace';

  @override
  String get deviceShopNewArrivals => 'Novidades';

  @override
  String get deviceShopNoInternet => 'Sem conexão com a internet';

  @override
  String deviceShopNoResults(String query) {
    return 'Nenhum resultado para \"$query\"';
  }

  @override
  String get deviceShopOfficialPartners => 'Parceiros Oficiais';

  @override
  String get deviceShopOnSale => 'Em Promoção';

  @override
  String get deviceShopOutOfStock => 'ESGOTADO';

  @override
  String get deviceShopPopularDevices => 'Dispositivos Populares';

  @override
  String get deviceShopRecentSearches => 'Buscas Recentes';

  @override
  String get deviceShopRetry => 'Tentar novamente';

  @override
  String get deviceShopSearchHint => 'Buscar dispositivos, módulos, antenas...';

  @override
  String get deviceShopSeeAll => 'Ver Tudo';

  @override
  String get deviceShopSellYourDevices => 'Venda seus dispositivos Meshtastic';

  @override
  String get deviceShopSupportEmail => 'support@socialmesh.app';

  @override
  String get deviceShopTitle => 'Loja de Dispositivos';

  @override
  String get deviceShopTrending => 'Em Alta';

  @override
  String get deviceShopTryAgain => 'Tente novamente em instantes';

  @override
  String get deviceShopTryDifferentKeywords =>
      'Tente palavras-chave diferentes';

  @override
  String get deviceShopUnableToLoad => 'Não foi possível carregar os produtos';

  @override
  String deviceShopErrorWithDetails(String error) {
    return 'Erro: $error';
  }

  @override
  String deviceShopFailedToUploadImage(String error) {
    return 'Falha ao enviar imagem: $error';
  }

  @override
  String deviceShopFailedToUploadLogo(String error) {
    return 'Falha ao enviar logo: $error';
  }

  @override
  String get deviceShopFieldRequired => 'Obrigatório';

  @override
  String get deviceShopGoBackTooltip => 'Voltar';

  @override
  String get deviceShopRefreshTooltip => 'Atualizar';

  @override
  String deviceShopReviewSubmitFailed(String error) {
    return 'Falha ao enviar avaliação: $error';
  }

  @override
  String get discoveryDiscoveredBadge => 'DESCOBERTO';

  @override
  String discoveryNodesFound(int count) {
    return '$count nós encontrados';
  }

  @override
  String get discoveryScanningNetwork => 'Escaneando Rede';

  @override
  String get discoverySearchingForNodes => 'Buscando nós...';

  @override
  String get discoverySignalExcellent => 'Excelente';

  @override
  String get discoverySignalGood => 'Bom';

  @override
  String get discoverySignalWeak => 'Fraco';

  @override
  String get discoveryUnknownNode => 'Nó Desconhecido';

  @override
  String get drawerAdminDashboard => 'Painel Admin';

  @override
  String get drawerAdminSectionHeader => 'ADMIN';

  @override
  String get drawerBadgeNew => 'NOVO';

  @override
  String get drawerBadgePro => 'PRO';

  @override
  String get drawerBadgeTryIt => 'TESTE';

  @override
  String get drawerEnterpriseDeviceManagement =>
      'Gerenciamento de Dispositivos';

  @override
  String get drawerEnterpriseExportDenied =>
      'Requer função de Supervisor ou Admin';

  @override
  String get drawerEnterpriseFieldReports => 'Relatórios de Campo';

  @override
  String get drawerEnterpriseIncidents => 'Incidentes';

  @override
  String get drawerEnterpriseOrgSettings => 'Config. da Org.';

  @override
  String get drawerEnterpriseReports => 'Relatórios';

  @override
  String get drawerEnterpriseSectionHeader => 'EMPRESA';

  @override
  String get drawerEnterpriseTasks => 'Tarefas';

  @override
  String get drawerEnterpriseUserManagement => 'Gerenciamento de Usuários';

  @override
  String get drawerNodeNotConnected => 'Não Conectado';

  @override
  String get drawerNodeOffline => 'Offline';

  @override
  String get drawerNodeOnline => 'Online';

  @override
  String get explorerTitleCartographer => 'Cartógrafo';

  @override
  String get explorerTitleCartographerDescription =>
      'Mapeando a infraestrutura invisível';

  @override
  String get explorerTitleExplorer => 'Explorador';

  @override
  String get explorerTitleExplorerDescription =>
      'Descobrindo ativamente a rede';

  @override
  String get explorerTitleLongRangeRecordHolder =>
      'Recordista de Longo Alcance';

  @override
  String get explorerTitleLongRangeRecordHolderDescription =>
      'Ultrapassando os limites de alcance';

  @override
  String get explorerTitleMeshCartographer => 'Cartógrafo Mesh';

  @override
  String get explorerTitleMeshCartographerDescription =>
      'Mapeando regiões e rotas';

  @override
  String get explorerTitleMeshVeteran => 'Veterano Mesh';

  @override
  String get explorerTitleMeshVeteranDescription =>
      'Conhecimento profundo da rede mesh';

  @override
  String get explorerTitleNewcomer => 'Iniciante';

  @override
  String get explorerTitleNewcomerDescription =>
      'Começando a jornada na rede mesh';

  @override
  String get explorerTitleObserver => 'Observador';

  @override
  String get explorerTitleObserverDescription =>
      'Construindo consciência da rede mesh';

  @override
  String get explorerTitleSignalHunter => 'Caçador de Sinais';

  @override
  String get explorerTitleSignalHunterDescription =>
      'Buscando sinais por todo o espectro';

  @override
  String get favoritesCancelCompare => 'Cancelar comparação';

  @override
  String get favoritesCannotCompare =>
      'Não é possível comparar nós fora da rede mesh';

  @override
  String get favoritesCharging => 'Carregando';

  @override
  String get favoritesCompareNodes => 'Comparar nós';

  @override
  String get favoritesDelete => 'Excluir';

  @override
  String get favoritesEmptyDescription =>
      'Toque no ícone de estrela em qualquer nó para adicioná-lo aos favoritos e ter acesso rápido.';

  @override
  String get favoritesEmptyTitle => 'Nenhum Favorito';

  @override
  String get favoritesErrorLoading => 'Erro ao carregar favoritos';

  @override
  String get favoritesNodeNotInMesh =>
      'Nó não está na rede mesh no momento. Tente novamente mais tarde.';

  @override
  String get favoritesNotInMesh => 'Fora da rede mesh';

  @override
  String get favoritesRemoveConfirm => 'Remover';

  @override
  String favoritesRemoveMessage(String name) {
    return 'Remover $name dos favoritos?';
  }

  @override
  String get favoritesRemoveTitle => 'Remover Favorito?';

  @override
  String get favoritesRemoveTooltip => 'Remover dos favoritos';

  @override
  String get favoritesRetry => 'Tentar novamente';

  @override
  String get favoritesSelectFirst => 'Selecione o primeiro nó';

  @override
  String get favoritesSelectSecond => 'Selecione o segundo nó';

  @override
  String get favoritesTitle => 'Nós Favoritos';

  @override
  String get featuredProductsDiscard => 'Descartar';

  @override
  String get featuredProductsEmpty => 'Nenhum produto em destaque';

  @override
  String get featuredProductsEmptySubtitle =>
      'Marque produtos como destaque para gerenciar a ordem aqui';

  @override
  String get featuredProductsOrderUpdated => 'Ordem dos destaques atualizada';

  @override
  String get featuredProductsRemove => 'Remover';

  @override
  String featuredProductsRemoveMessage(String name) {
    return 'Remover \"$name\" dos produtos em destaque?';
  }

  @override
  String get featuredProductsRemoveTitle => 'Remover dos Destaques';

  @override
  String get featuredProductsRemoveTooltip => 'Remover dos destaques';

  @override
  String get featuredProductsRemoved => 'Removido dos destaques';

  @override
  String get featuredProductsReorderInfo =>
      'Arraste e solte os produtos para reordenar. Os produtos no topo aparecerão primeiro na seção de destaques.';

  @override
  String get featuredProductsSave => 'Salvar';

  @override
  String get featuredProductsTitle => 'Produtos em Destaque';

  @override
  String get featuredProductsUnsavedChanges => 'Você tem alterações não salvas';

  @override
  String get feedbackBugReportsTitle => 'Meus Relatórios de Bugs';

  @override
  String get feedbackConversation => 'Conversa';

  @override
  String get feedbackFailedToLoad => 'Falha ao carregar relatórios';

  @override
  String get feedbackFilterAll => 'Todos';

  @override
  String get feedbackFilterAwaiting => 'Aguardando';

  @override
  String get feedbackFilterOpen => 'Aberto';

  @override
  String get feedbackFilterResolved => 'Resolvido';

  @override
  String get feedbackFilterResponded => 'Respondido';

  @override
  String get feedbackFormHint => 'Conte-nos sobre o problema encontrado';

  @override
  String get feedbackFormTitle => 'Relatar bug';

  @override
  String get feedbackFormValidationError => 'Descreva o problema.';

  @override
  String get feedbackFormWhatHappened => 'O que aconteceu?';

  @override
  String get feedbackIncludeScreenshot => 'Incluir screenshot no relatório';

  @override
  String get feedbackNoBugReports => 'Nenhum relatório de bug';

  @override
  String get feedbackNoBugReportsDesc =>
      'Agite o dispositivo para relatar um bug.\nSeus relatórios e respostas aparecerão aqui.';

  @override
  String get feedbackNoMatchFilter =>
      'Nenhum relatório corresponde a este filtro';

  @override
  String get feedbackNoMatchSearch => 'Nenhum relatório corresponde à busca';

  @override
  String feedbackReplyFailed(String error) {
    return 'Falha ao enviar resposta: $error';
  }

  @override
  String get feedbackReplyHint => 'Escreva uma resposta...';

  @override
  String get feedbackReplySent => 'Resposta enviada';

  @override
  String get feedbackReportBugAction => 'Relatar bug';

  @override
  String get feedbackReportBugDescription =>
      'Se algo não está funcionando corretamente, você pode relatar para ajudar a melhorar o Socialmesh para todos.';

  @override
  String get feedbackReportBugTitle => 'Relatar um bug?';

  @override
  String get feedbackReportResolved => 'Este relatório foi resolvido';

  @override
  String get feedbackResponseAuthorSocialmesh => 'Socialmesh';

  @override
  String get feedbackResponseAuthorYou => 'Você';

  @override
  String get feedbackRetry => 'Tentar novamente';

  @override
  String get feedbackScreenshotSubtitle => 'Ajuda a resolver mais rápido';

  @override
  String get feedbackSearchReports => 'Buscar relatórios';

  @override
  String get feedbackSendButton => 'Enviar';

  @override
  String get feedbackSendingReport => 'Enviando relatório de bug...';

  @override
  String get feedbackShakeToReport => 'Agite o dispositivo para relatar um bug';

  @override
  String get feedbackToggleOff => 'Desative para desabilitar';

  @override
  String get feedbackWaitingForAdmin => 'Aguardando resposta do administrador';

  @override
  String get feedbackYourReport => 'Seu relatório';

  @override
  String fileTransferAccepted(String filename) {
    return 'Aceito: $filename';
  }

  @override
  String get fileTransferActionAccept => 'Aceitar';

  @override
  String get fileTransferActionCancel => 'Cancelar';

  @override
  String get fileTransferActionDelete => 'Excluir';

  @override
  String get fileTransferActionInfo => 'Info';

  @override
  String get fileTransferActionReject => 'Rejeitar';

  @override
  String get fileTransferActionRetry => 'Tentar novamente';

  @override
  String get fileTransferActionShare => 'Compartilhar';

  @override
  String fileTransferAttachmentMeta(int size, String chunkCount) {
    return '$size · $chunkCount blocos via mesh';
  }

  @override
  String fileTransferCardChunksProgress(String completed, String total) {
    return '$completed/$total blocos';
  }

  @override
  String fileTransferCardChunksTotal(String count) {
    return '$count blocos';
  }

  @override
  String fileTransferCardChunkSize(String size) {
    return '$size cada';
  }

  @override
  String get fileTransferBinaryFileHint =>
      'Arquivo binário — salve para abrir com um app externo';

  @override
  String get fileTransferCancelConfirm => 'Cancelar transferência';

  @override
  String fileTransferCancelMessage(String filename) {
    return 'Cancelar a transferência de \"$filename\"?';
  }

  @override
  String get fileTransferCancelTitle => 'Cancelar transferência?';

  @override
  String get fileTransferCancelled => 'Transferência cancelada';

  @override
  String get fileTransferClearCompleted => 'Limpar concluídas';

  @override
  String get fileTransferClearConfirm => 'Limpar';

  @override
  String get fileTransferClearMessage =>
      'Remover todas as transferências concluídas, com falha e canceladas? Isso não pode ser desfeito.';

  @override
  String get fileTransferClearTitle => 'Limpar transferências concluídas?';

  @override
  String fileTransferClearedCount(int count) {
    return '$count transferências removidas';
  }

  @override
  String get fileTransferContactsClearSearch => 'Limpar busca';

  @override
  String fileTransferContactsDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String get fileTransferContactsDetailReceived => 'Recebidos';

  @override
  String get fileTransferContactsDetailSent => 'Enviados';

  @override
  String get fileTransferContactsDetailTotal => 'Total';

  @override
  String get fileTransferContactsDiscoveredHint =>
      'Nós descobertos aparecerão aqui';

  @override
  String get fileTransferContactsFilterActive => 'Ativos';

  @override
  String get fileTransferContactsFilterAll => 'Todos';

  @override
  String get fileTransferContactsFilterFavorites => 'Favoritos';

  @override
  String get fileTransferContactsFilterHasFiles => 'Com arquivos';

  @override
  String fileTransferContactsHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String get fileTransferContactsJustNow => 'agora';

  @override
  String fileTransferContactsMinutesAgo(int count) {
    return '${count}m atrás';
  }

  @override
  String fileTransferContactsNoMatchFilter(String filter) {
    return 'Nenhum contato $filter';
  }

  @override
  String fileTransferContactsNoMatchSearch(String query) {
    return 'Nenhum contato corresponde a \"$query\"';
  }

  @override
  String get fileTransferContactsNoNodes => 'Nenhum nó na mesh ainda';

  @override
  String get fileTransferContactsSearchHint => 'Buscar contatos';

  @override
  String get fileTransferContactsSectionActive => 'Ativos';

  @override
  String get fileTransferContactsSectionFavorites => 'Favoritos';

  @override
  String get fileTransferContactsSectionInactive => 'Inativos';

  @override
  String get fileTransferContactsSectionWithFiles => 'Com arquivos';

  @override
  String get fileTransferContactsSendFile => 'Enviar arquivo';

  @override
  String get fileTransferContactsSendImage => 'Enviar Imagem';

  @override
  String fileTransferContactsStarted(String filename) {
    return 'Transferência iniciada: $filename';
  }

  @override
  String get fileTransferContainerClearCompleted => 'Limpar concluídas';

  @override
  String get fileTransferContainerClearMessage =>
      'Remover todas as transferências concluídas, com falha e canceladas? Isso não pode ser desfeito.';

  @override
  String get fileTransferContainerClearTitle =>
      'Limpar transferências concluídas?';

  @override
  String fileTransferContainerCleared(int count) {
    return '$count transferências removidas';
  }

  @override
  String get fileTransferContainerMenuHelp => 'Ajuda';

  @override
  String get fileTransferContainerPurgeExpired => 'Excluir expiradas';

  @override
  String get fileTransferContainerPurged =>
      'Transferências expiradas excluídas';

  @override
  String get fileTransferContainerSendFile => 'Enviar arquivo';

  @override
  String get fileTransferContainerSendImage => 'Enviar Imagem';

  @override
  String get fileTransferContainerSendToNode => 'Enviar para nó';

  @override
  String fileTransferContainerStarted(String filename) {
    return 'Transferência iniciada: $filename';
  }

  @override
  String get fileTransferContainerTitle => 'Transferências de arquivos';

  @override
  String get fileTransferCopiedToClipboard =>
      'Copiado para a área de transferência';

  @override
  String get fileTransferCopyAction => 'Copiar';

  @override
  String fileTransferCouldNotReadFile(String error) {
    return 'Não foi possível ler o arquivo: $error';
  }

  @override
  String get fileTransferCouldNotRead => 'Não foi possível ler o arquivo.';

  @override
  String get fileTransferCouldNotSaveForSharing =>
      'Não foi possível salvar o arquivo para compartilhamento';

  @override
  String get fileTransferCouldNotStart =>
      'Não foi possível iniciar a transferência. Verifique se um nó está conectado e tente novamente.';

  @override
  String get fileTransferDeleteConfirm => 'Excluir';

  @override
  String fileTransferDeleteMessage(String filename) {
    return 'Excluir \"$filename\"? Isso não pode ser desfeito.';
  }

  @override
  String get fileTransferDeleteTitle => 'Excluir transferência?';

  @override
  String fileTransferDeleted(String filename) {
    return 'Excluído: $filename';
  }

  @override
  String get fileTransferDetailsSection => 'Detalhes da transferência';

  @override
  String get fileTransferDirectionReceived => 'Recebido';

  @override
  String get fileTransferDirectionSent => 'Enviado';

  @override
  String get fileTransferStatusPreparing => 'Preparing…';

  @override
  String get fileTransferStatusOfferSent => 'Offer sent, waiting…';

  @override
  String get fileTransferStatusOfferPending => 'Incoming file — tap to review';

  @override
  String fileTransferStatusSending(String pct) {
    return 'Sending $pct%';
  }

  @override
  String fileTransferStatusReceiving(String pct) {
    return 'Receiving $pct%';
  }

  @override
  String get fileTransferStatusRecovering => 'Recovering missing chunks…';

  @override
  String get fileTransferStatusComplete => 'Complete';

  @override
  String get fileTransferStatusCancelled => 'Cancelled';

  @override
  String get fileTransferStatusAwaitingAccept => 'Awaiting Accept';

  @override
  String get fileTransferStatusFailed => 'Failed';

  @override
  String get fileTransferFailReasonOversized =>
      'File too large for mesh transfer';

  @override
  String get fileTransferFailReasonTimeout => 'Transfer timed out';

  @override
  String get fileTransferFailReasonInvalid => 'Invalid data received';

  @override
  String get fileTransferFailReasonRateLimited =>
      'Rate limited — try again later';

  @override
  String get fileTransferFailReasonHashMismatch => 'File verification failed';

  @override
  String get fileTransferFailReasonMaxRetries => 'Max retries exceeded';

  @override
  String get fileTransferFailReasonExpired => 'Transfer expired';

  @override
  String fileTransferMetaNodeTo(String nodeName) {
    return 'to $nodeName';
  }

  @override
  String fileTransferMetaNodeFrom(String nodeName) {
    return 'from $nodeName';
  }

  @override
  String get fileTransferTimeJustNow => 'just now';

  @override
  String fileTransferTimeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String fileTransferTimeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String fileTransferTimeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String fileTransferTimeDate(String month, String day) {
    return '$month/$day';
  }

  @override
  String get fileTransferVoiceBadge => 'Voice';

  @override
  String get fileTransferEmptyDescriptionContacts =>
      'Vá em Contatos, toque em um nó e\nescolha Enviar arquivo para começar';

  @override
  String get fileTransferEmptyDescriptionOverflow =>
      'Envie arquivos para outros nós pelo\nmenu overflow ou via NodeDex';

  @override
  String fileTransferEmptyFilterTitle(String filter) {
    return 'Nenhuma transferência $filter';
  }

  @override
  String get fileTransferEmptyTitle => 'Nenhuma transferência';

  @override
  String get fileTransferExpiredPurged => 'Transferências expiradas excluídas';

  @override
  String get fileTransferFileEmpty => 'O arquivo selecionado está vazio.';

  @override
  String fileTransferFileTooLarge(
    String filename,
    String fileSize,
    String limit,
  ) {
    return '$filename tem $fileSize KB — o limite mesh é $limit KB.';
  }

  @override
  String get fileTransferFilterActive => 'Ativas';

  @override
  String get fileTransferFilterAll => 'Todas';

  @override
  String get fileTransferFilterDone => 'Concluídas';

  @override
  String get fileTransferFilterReceived => 'Recebidas';

  @override
  String get fileTransferFilterSent => 'Enviadas';

  @override
  String get fileTransferGoToContacts => 'Ir para contatos';

  @override
  String get fileTransferImageDecodeError =>
      'Não foi possível decodificar a imagem';

  @override
  String get fileTransferImagePickerTitle => 'Enviar Imagem';

  @override
  String get fileTransferImagePickerCamera => 'Tirar Foto';

  @override
  String get fileTransferImagePickerCameraSubtitle =>
      'Usar câmara para tirar uma foto';

  @override
  String get fileTransferImagePickerGallery => 'Escolher da Galeria';

  @override
  String get fileTransferImagePickerGallerySubtitle =>
      'Selecionar uma foto da sua biblioteca';

  @override
  String get fileTransferImagePickerCancel => 'Cancelar';

  @override
  String get fileTransferImageCompressing =>
      'A comprimir imagem para transferência mesh…';

  @override
  String fileTransferImageTooLargeAfterCompression(String limit) {
    return 'Não foi possível comprimir a imagem para caber no limite de $limit KB da mesh.';
  }

  @override
  String fileTransferImageCompressed(String size, String width, String height) {
    return 'Imagem comprimida para $size bytes (${width}x$height)';
  }

  @override
  String get fileTransferInfoChunkSize => 'Tamanho do bloco';

  @override
  String get fileTransferInfoChunks => 'Blocos';

  @override
  String get fileTransferInfoCompleted => 'Concluído';

  @override
  String get fileTransferInfoCreated => 'Criado';

  @override
  String get fileTransferInfoDirection => 'Direção';

  @override
  String get fileTransferInfoDirectionReceived => 'Recebido';

  @override
  String get fileTransferInfoDirectionSent => 'Enviado';

  @override
  String get fileTransferInfoExpires => 'Expira';

  @override
  String get fileTransferInfoFailure => 'Falha';

  @override
  String get fileTransferInfoMimeType => 'Tipo MIME';

  @override
  String get fileTransferInfoNackRounds => 'Ciclos NACK';

  @override
  String get fileTransferInfoSize => 'Tamanho';

  @override
  String get fileTransferInfoSourceNode => 'Nó de origem';

  @override
  String get fileTransferInfoStatus => 'Estado';

  @override
  String get fileTransferInfoTargetNode => 'Nó de destino';

  @override
  String get fileTransferInfoTransferId => 'ID da transferência';

  @override
  String fileTransferMoreBytes(int count) {
    return '... mais $count bytes';
  }

  @override
  String get fileTransferNoMatchFilter =>
      'Nenhuma transferência corresponde ao filtro';

  @override
  String get fileTransferPinchToZoom => 'Aperte para ampliar';

  @override
  String fileTransferGalleryToNode(String name) {
    return 'para $name';
  }

  @override
  String fileTransferGalleryFromNode(String name) {
    return 'de $name';
  }

  @override
  String get fileTransferGallerySentBadge => 'Enviado';

  @override
  String get fileTransferGalleryReceivedBadge => 'Recebido';

  @override
  String fileTransferGallerySizeBadge(String size) {
    return '$size';
  }

  @override
  String fileTransferGalleryChunksBadge(String completed, String total) {
    return '$completed/$total blocos';
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
  String get fileTransferGalleryViewDetails => 'Detalhes';

  @override
  String get fileTransferGalleryMeshTransfer => 'Transferência Mesh';

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
  String get fileTransferPurgeExpired => 'Excluir expiradas';

  @override
  String get fileTransferRejectConfirm => 'Rejeitar';

  @override
  String fileTransferRejectMessage(String filename) {
    return 'Rejeitar o arquivo recebido \"$filename\"? O remetente será notificado.';
  }

  @override
  String get fileTransferRejectTitle => 'Rejeitar transferência?';

  @override
  String get fileTransferRejected => 'Transferência rejeitada';

  @override
  String get fileTransferSearchHint => 'Buscar transferências';

  @override
  String get fileTransferSendAFile => 'Enviar um arquivo';

  @override
  String get fileTransferSendFile => 'Enviar arquivo';

  @override
  String get fileTransferSendToNode => 'Enviar para nó';

  @override
  String fileTransferStarted(String filename) {
    return 'Transferência iniciada: $filename';
  }

  @override
  String get fileTransferTabContacts => 'Contatos';

  @override
  String get fileTransferTabFiles => 'Arquivos';

  @override
  String get fileTransferTitle => 'Transferências de arquivos';

  @override
  String fileTransferLineCount(int count) {
    return '$count linhas';
  }

  @override
  String get archiveContentsHeader => 'Contents';

  @override
  String archiveEntryCount(int count) {
    return '$count files';
  }

  @override
  String archiveSummaryImages(int count) {
    return '$count images';
  }

  @override
  String archiveSummaryVoice(int count) {
    return '$count voice';
  }

  @override
  String archiveSummaryText(int count) {
    return '$count text';
  }

  @override
  String archiveSummaryOther(int count) {
    return '$count other';
  }

  @override
  String archiveSummaryUnsupported(int count) {
    return '$count unsupported';
  }

  @override
  String get archiveActionPreview => 'Preview';

  @override
  String get archiveActionPlay => 'Play';

  @override
  String get archiveActionSave => 'Save';

  @override
  String get archiveStatusSupported => 'Supported';

  @override
  String get archiveStatusUnsupported => 'Unsupported';

  @override
  String get archiveStatusTooLarge => 'Too large';

  @override
  String get archiveStatusBlocked => 'Blocked';

  @override
  String get archiveStatusNested => 'Nested archive';

  @override
  String get archiveRejectEncrypted =>
      'This archive is encrypted or password-protected and cannot be inspected.';

  @override
  String get archiveRejectCorrupt => 'This archive is corrupt or unreadable.';

  @override
  String get archiveRejectTooManyEntries =>
      'This archive contains too many files and cannot be inspected.';

  @override
  String get archiveRejectTotalSizeTooLarge =>
      'The total uncompressed size of this archive exceeds the safety limit.';

  @override
  String get archiveRejectSaveHint =>
      'You can still save the archive file as-is.';

  @override
  String get firmwareUpdateAvailable => 'Atualização disponível';

  @override
  String get firmwareUpdateBackupWarningSubtitle =>
      'Atualizações de firmware podem redefinir a configuração do dispositivo. Considere exportar suas configurações antes de atualizar.';

  @override
  String get firmwareUpdateBackupWarningTitle => 'Backup das configurações';

  @override
  String get firmwareUpdateBluetooth => 'Bluetooth';

  @override
  String get firmwareUpdateCheckFailed => 'Falha ao verificar atualizações';

  @override
  String get firmwareUpdateChecking => 'Verificando atualizações...';

  @override
  String get firmwareUpdateDownload => 'Baixar atualização';

  @override
  String get firmwareUpdateHardware => 'Hardware';

  @override
  String get firmwareUpdateInstalledFirmware => 'Firmware instalado';

  @override
  String firmwareUpdateLatestVersion(String version) {
    return 'Última: $version';
  }

  @override
  String get firmwareUpdateNewBadge => 'NOVO';

  @override
  String get firmwareUpdateNodeId => 'ID do nó';

  @override
  String get firmwareUpdateOpenWebFlasher => 'Abrir Web Flasher';

  @override
  String get firmwareUpdateReleaseNotes => 'Notas de versão';

  @override
  String get firmwareUpdateSectionAvailableUpdate => 'Atualização disponível';

  @override
  String get firmwareUpdateSectionCurrentVersion => 'Versão atual';

  @override
  String get firmwareUpdateSectionHowToUpdate => 'Como atualizar';

  @override
  String get firmwareUpdateStep1 =>
      'Baixe o arquivo de firmware para o seu dispositivo';

  @override
  String get firmwareUpdateStep2 => 'Conecte o dispositivo via USB';

  @override
  String get firmwareUpdateStep3 =>
      'Use o Web Flasher ou a CLI do Meshtastic para gravar';

  @override
  String get firmwareUpdateStep4 =>
      'Aguarde o dispositivo reiniciar e reconectar';

  @override
  String get firmwareUpdateSupported => 'Suportado';

  @override
  String get firmwareUpdateTitle => 'Atualização de firmware';

  @override
  String get firmwareUpdateUnableToCheck =>
      'Não foi possível verificar atualizações';

  @override
  String get firmwareUpdateUnknown => 'Desconhecido';

  @override
  String get firmwareUpdateUpToDate => 'Atualizado';

  @override
  String get firmwareUpdateUptime => 'Tempo de atividade';

  @override
  String get firmwareUpdateVisitWebsite =>
      'Visite o site do Meshtastic para o firmware mais recente.';

  @override
  String get firmwareUpdateWifi => 'WiFi';

  @override
  String get firmwareDfuDownloading => 'Downloading firmware…';

  @override
  String firmwareDfuDownloadProgress(String percent) {
    return 'Downloading: $percent%';
  }

  @override
  String get firmwareDfuEnteringBootloader => 'Entering DFU mode…';

  @override
  String get firmwareDfuTransferring => 'Updating firmware…';

  @override
  String firmwareDfuProgress(int percent) {
    return '$percent% complete';
  }

  @override
  String get firmwareDfuComplete => 'Firmware updated successfully!';

  @override
  String get firmwareDfuFailed => 'Firmware update failed';

  @override
  String get firmwareDfuDeviceWillRestart =>
      'Your device will restart to apply the update.';

  @override
  String get firmwareDfuDoNotDisconnect =>
      'Do not disconnect your device during the update.';

  @override
  String get firmwareDfuStartUpdate => 'Start Update';

  @override
  String get firmwareDfuRetry => 'Retry';

  @override
  String get firmwareDfuInAppSupported => 'In-App Update Available';

  @override
  String firmwareDfuSpeed(String speed) {
    return '$speed KB/s';
  }

  @override
  String get firmwareDfuNoFirmwareFound =>
      'No firmware file found for this device model.';

  @override
  String get firmwareArchitectureNrf52 => 'nRF52840';

  @override
  String get firmwareArchitectureEsp32 => 'ESP32';

  @override
  String get firmwareArchitectureUnknown => 'Unknown';

  @override
  String get firmwareUpdateMethodInApp => 'In-App Update';

  @override
  String get firmwareUpdateMethodWebFlasher => 'Web Flasher';

  @override
  String get firmwareArchitecture => 'Architecture';

  @override
  String get firmwareUpdateMethod => 'Update Method';

  @override
  String get firmwareDfuConfirmTitle => 'Start Firmware Update?';

  @override
  String firmwareDfuConfirmBody(String version) {
    return 'This will update your device to version $version. The device will restart during the update.\n\nDo not disconnect or turn off your device until the update completes.';
  }

  @override
  String get firmwareDfuConfirmStart => 'Start Update';

  @override
  String get globeEmptyDescription =>
      'Nós com dados de posição aparecerão aqui';

  @override
  String get globeEmptyTitle => 'Nenhum nó com GPS';

  @override
  String get globeHelp => 'Ajuda';

  @override
  String get globeHideConnections => 'Ocultar conexões';

  @override
  String globeNodeCount(int count) {
    return '$count nós';
  }

  @override
  String get globeResetView => 'Redefinir vista';

  @override
  String get globeScreenTitle => 'Globo mesh';

  @override
  String get globeSelectNode => 'Selecionar nó';

  @override
  String get globeShowConnections => 'Mostrar conexões';

  @override
  String get gpsStatusAccuracy => 'Precisão';

  @override
  String gpsStatusAccuracyValue(String meters) {
    return '±${meters}m';
  }

  @override
  String get gpsStatusAcquiring => 'Adquirindo GPS...';

  @override
  String get gpsStatusActiveBadge => 'ATIVO';

  @override
  String get gpsStatusAltitude => 'Altitude';

  @override
  String gpsStatusAltitudeValue(String meters) {
    return '${meters}m';
  }

  @override
  String get gpsStatusCardinalE => 'L';

  @override
  String get gpsStatusCardinalN => 'N';

  @override
  String get gpsStatusCardinalNE => 'NE';

  @override
  String get gpsStatusCardinalNW => 'NO';

  @override
  String get gpsStatusCardinalS => 'S';

  @override
  String get gpsStatusCardinalSE => 'SE';

  @override
  String get gpsStatusCardinalSW => 'SO';

  @override
  String get gpsStatusCardinalW => 'O';

  @override
  String gpsStatusDateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String gpsStatusDaysAgo(int count) {
    return '$count dias atrás';
  }

  @override
  String get gpsStatusFixAcquired => 'Fix GPS adquirido';

  @override
  String get gpsStatusGroundSpeed => 'Velocidade no solo';

  @override
  String gpsStatusGroundSpeedValue(String mps, String kmh) {
    return '$mps m/s ($kmh km/h)';
  }

  @override
  String get gpsStatusGroundTrack => 'Rota no solo';

  @override
  String gpsStatusGroundTrackValue(String degrees, String direction) {
    return '$degrees° $direction';
  }

  @override
  String gpsStatusHoursAgo(int count) {
    return '$count horas atrás';
  }

  @override
  String get gpsStatusLatitude => 'Latitude';

  @override
  String gpsStatusLatitudeValue(String value) {
    return '$value°';
  }

  @override
  String get gpsStatusLongitude => 'Longitude';

  @override
  String gpsStatusLongitudeValue(String value) {
    return '$value°';
  }

  @override
  String gpsStatusMinutesAgo(int count) {
    return '$count minutos atrás';
  }

  @override
  String get gpsStatusNoGpsFix => 'Sem fix GPS';

  @override
  String get gpsStatusNoGpsFixMessage =>
      'O dispositivo ainda não adquiriu uma posição GPS. Certifique-se de que o dispositivo tenha visão clara do céu.';

  @override
  String get gpsStatusOpenInMaps => 'Abrir no Mapas';

  @override
  String get gpsStatusPrecisionBits => 'Bits de precisão';

  @override
  String get gpsStatusSatFair => 'Regular';

  @override
  String get gpsStatusSatGood => 'Bom';

  @override
  String get gpsStatusSatNoFix => 'Sem fix';

  @override
  String get gpsStatusSatPoor => 'Fraco';

  @override
  String gpsStatusSatellitesCount(int count) {
    return '$count satélites visíveis';
  }

  @override
  String get gpsStatusSatellitesInView => 'Satélites visíveis';

  @override
  String get gpsStatusSearchingSatellites => 'Buscando satélites...';

  @override
  String gpsStatusSecondsAgo(int count) {
    return '$count segundos atrás';
  }

  @override
  String get gpsStatusSectionLastUpdate => 'Última atualização';

  @override
  String get gpsStatusSectionMotion => 'Movimento';

  @override
  String get gpsStatusSectionPosition => 'Posição';

  @override
  String get gpsStatusSectionSatellites => 'Satélites';

  @override
  String get gpsStatusTitle => 'Status do GPS';

  @override
  String gpsStatusTodayAt(String time) {
    return 'Hoje às $time';
  }

  @override
  String get gpsStatusUnknown => 'Desconhecido';

  @override
  String get helpArticleLoadFailed => 'Falha ao carregar o artigo';

  @override
  String helpArticleMinRead(int minutes) {
    return '$minutes min de leitura';
  }

  @override
  String get helpCenterArticleRead => 'Lido';

  @override
  String get helpCenterArticleUnread => 'Não lido';

  @override
  String get helpCenterArticlesRead => 'artigos lidos';

  @override
  String get helpCenterComeBackToRefresh =>
      'Volte quando quiser para atualizar seus conhecimentos.';

  @override
  String get helpCenterCompleted => 'Concluído';

  @override
  String get helpCenterContentBeingPrepared =>
      'O conteúdo de ajuda está sendo preparado. Volte em breve.';

  @override
  String get helpCenterFilterAll => 'Todos';

  @override
  String helpCenterFindThisIn(String screenName) {
    return 'Encontre em: $screenName';
  }

  @override
  String get helpCenterHapticFeedbackSubtitle =>
      'Vibrar durante o efeito de texto máquina de escrever';

  @override
  String get helpCenterHapticFeedbackTitle => 'Feedback háptico';

  @override
  String get helpCenterHelpPreferences => 'PREFERÊNCIAS DE AJUDA';

  @override
  String get helpCenterInteractiveTours => 'Tours interativos';

  @override
  String get helpCenterLearnHowItWorks => 'Saiba como o Meshtastic funciona';

  @override
  String get helpCenterLoadFailed => 'Falha ao carregar o conteúdo de ajuda';

  @override
  String get helpCenterMarkAsComplete => 'Marcar como concluído';

  @override
  String get helpCenterNoArticlesAvailable => 'Nenhum artigo disponível';

  @override
  String get helpCenterNoArticlesInCategory => 'Nenhum artigo nesta categoria';

  @override
  String get helpCenterNoArticlesMatchSearch =>
      'Nenhum artigo corresponde à pesquisa.\nTente palavras-chave diferentes.';

  @override
  String get helpCenterReadEverything => 'Você leu tudo!';

  @override
  String get helpCenterResetAllProgress => 'Redefinir todo o progresso';

  @override
  String get helpCenterResetProgressLabel => 'Redefinir';

  @override
  String get helpCenterResetProgressMessage =>
      'Todos os artigos serão marcados como não lidos e o progresso dos tours interativos será zerado. Você pode recomeçar do zero.';

  @override
  String get helpCenterResetProgressTitle => 'Redefinir progresso da ajuda?';

  @override
  String get helpCenterScreenAether => 'Aether';

  @override
  String get helpCenterScreenAutomations => 'Automações';

  @override
  String get helpCenterScreenChannels => 'Canais';

  @override
  String get helpCenterScreenCreateSignal => 'Criar sinal';

  @override
  String get helpCenterScreenDeviceShop => 'Loja de dispositivos';

  @override
  String get helpCenterScreenGlobe => 'Globo';

  @override
  String get helpCenterScreenMap => 'Mapa';

  @override
  String get helpCenterScreenMesh3d => 'Mesh 3D';

  @override
  String get helpCenterScreenMeshHealth => 'Saúde da mesh';

  @override
  String get helpCenterScreenMessages => 'Mensagens';

  @override
  String get helpCenterScreenNodeDex => 'NodeDex';

  @override
  String get helpCenterScreenNodes => 'Nós';

  @override
  String get helpCenterScreenPresence => 'Presença';

  @override
  String get helpCenterScreenProfile => 'Perfil';

  @override
  String get helpCenterScreenRadioConfig => 'Configuração de rádio';

  @override
  String get helpCenterScreenReachability => 'Alcançabilidade';

  @override
  String get helpCenterScreenRegionSelection => 'Seleção de região';

  @override
  String get helpCenterScreenRoutes => 'Rotas';

  @override
  String get helpCenterScreenScanner => 'Scanner';

  @override
  String get helpCenterScreenSettings => 'Configurações';

  @override
  String get helpCenterScreenSignalFeed => 'Feed de sinais';

  @override
  String get helpCenterScreenTakGateway => 'Gateway TAK';

  @override
  String get helpCenterScreenTimeline => 'Linha do tempo';

  @override
  String get helpCenterScreenTraceRouteLog => 'Log de Trace Route';

  @override
  String get helpCenterScreenWidgetBuilder => 'Criador de widgets';

  @override
  String get helpCenterScreenWidgetDashboard => 'Dashboard de widgets';

  @override
  String get helpCenterScreenWidgetMarketplace => 'Marketplace de widgets';

  @override
  String get helpCenterScreenWorldMesh => 'World Mesh';

  @override
  String get helpCenterSearchByTitle => 'Pesquisar por título\nou descrição.';

  @override
  String get helpCenterSearchHint => 'Pesquisar artigos';

  @override
  String get helpCenterShowHelpHintsSubtitle =>
      'Exibir botões de ajuda pulsantes nas telas';

  @override
  String get helpCenterShowHelpHintsTitle => 'Mostrar dicas de ajuda';

  @override
  String get helpCenterTapToLearn =>
      'Toque em um artigo para saber mais sobre rede mesh, configurações de rádio e mais.';

  @override
  String get helpCenterTitle => 'Central de ajuda';

  @override
  String helpCenterToursCompletedCount(int completed, int total) {
    return '$completed / $total concluídos';
  }

  @override
  String get helpCenterToursDescription =>
      'Passo a passo das funcionalidades do app. Esses tours guiam você por cada tela com o Ico.';

  @override
  String get helpCenterTryDifferentCategory =>
      'Tente selecionar uma categoria diferente nos filtros acima.';

  @override
  String get incidentActionAssign => 'Atribuir';

  @override
  String get incidentActionCancel => 'Cancelar';

  @override
  String get incidentActionClose => 'Fechar';

  @override
  String incidentActionDeniedTooltip(String roleHint) {
    return 'Requer $roleHint';
  }

  @override
  String get incidentActionEscalate => 'Escalar';

  @override
  String get incidentActionFailedSnackbar => 'Ação falhou';

  @override
  String get incidentActionResolve => 'Resolver';

  @override
  String get incidentActionSubmit => 'Enviar';

  @override
  String incidentActionSuccessSnackbar(String action) {
    return 'Incidente $action';
  }

  @override
  String get incidentAssignCancelButton => 'Cancelar';

  @override
  String get incidentAssignConfirmButton => 'Atribuir';

  @override
  String get incidentAssignSheetTitle => 'Atribuir incidente';

  @override
  String incidentAssignedLabel(String assigneeId) {
    return 'Atribuído: $assigneeId';
  }

  @override
  String get incidentAssigneeHint => 'Insira o ID do usuário';

  @override
  String get incidentAssigneeLabel => 'ID do usuário atribuído';

  @override
  String get incidentClassificationComms => 'Comunicações';

  @override
  String get incidentClassificationEnvironmental => 'Ambiental';

  @override
  String get incidentClassificationLogistics => 'Logística';

  @override
  String get incidentClassificationMedical => 'Médico';

  @override
  String get incidentClassificationOperational => 'Operacional';

  @override
  String get incidentClassificationSafety => 'Segurança';

  @override
  String get incidentClassificationSecurity => 'Proteção';

  @override
  String get incidentCreateButtonLabel => 'Criar incidente';

  @override
  String get incidentCreateCaptureLocation => 'Capturar localização';

  @override
  String get incidentCreateClassificationSection => 'Classificação';

  @override
  String get incidentCreateDescriptionHint =>
      'Descrição detalhada do incidente';

  @override
  String get incidentCreateDescriptionSection => 'Descrição (opcional)';

  @override
  String incidentCreateError(String error) {
    return 'Erro: $error';
  }

  @override
  String get incidentCreateFailed => 'Falha ao criar';

  @override
  String get incidentCreateGettingLocation => 'Obtendo localização...';

  @override
  String get incidentCreateLocationError =>
      'Não foi possível obter a localização';

  @override
  String incidentCreateLocationException(String error) {
    return 'Erro de localização: $error';
  }

  @override
  String get incidentCreateLocationSection => 'Localização (opcional)';

  @override
  String get incidentCreatePrioritySection => 'Prioridade';

  @override
  String get incidentCreateRemoveLocation => 'Remover';

  @override
  String get incidentCreateScreenTitle => 'Criar incidente';

  @override
  String get incidentCreateSubmitButton => 'Criar incidente';

  @override
  String get incidentCreateSubmitting => 'Criando...';

  @override
  String get incidentCreateTitleHint => 'Título breve do incidente';

  @override
  String get incidentCreateTitleRequired => 'O título é obrigatório';

  @override
  String get incidentCreateTitleSection => 'Título';

  @override
  String get incidentCreateTooltip => 'Criar incidente';

  @override
  String get incidentCreatedSuccess => 'Incidente criado';

  @override
  String incidentDetailError(String error) {
    return 'Erro: $error';
  }

  @override
  String get incidentDetailTitle => 'Detalhe do incidente';

  @override
  String get incidentDetailTitleLoading => 'Incidente';

  @override
  String get incidentEmptyStateDescription =>
      'Incidentes rastreiam eventos da criação até a resolução. Crie um para começar.';

  @override
  String get incidentEmptyStateTitle => 'Nenhum incidente';

  @override
  String get incidentFilterAssignedToMe => 'Atribuídos a mim';

  @override
  String get incidentFilterStateAssigned => 'Atribuído';

  @override
  String get incidentFilterStateCancelled => 'Cancelado';

  @override
  String get incidentFilterStateClosed => 'Fechado';

  @override
  String get incidentFilterStateDraft => 'Rascunho';

  @override
  String get incidentFilterStateEscalated => 'Escalado';

  @override
  String get incidentFilterStateOpen => 'Aberto';

  @override
  String get incidentFilterStateResolved => 'Resolvido';

  @override
  String incidentListLoadError(String error) {
    return 'Falha ao carregar incidentes:\n$error';
  }

  @override
  String get incidentListTitle => 'Incidentes';

  @override
  String get incidentNotFound => 'Incidente não encontrado';

  @override
  String get incidentNoteContinueButton => 'Continuar';

  @override
  String get incidentNoteHint => 'Nota opcional para esta transição';

  @override
  String get incidentNoteLabel => 'Nota';

  @override
  String incidentNoteSheetTitle(String action) {
    return 'Nota de $action (opcional)';
  }

  @override
  String get incidentNoteSkipButton => 'Pular';

  @override
  String get incidentPriorityFlash => 'Flash';

  @override
  String get incidentPriorityImmediate => 'Imediato';

  @override
  String get incidentPriorityPriority => 'Prioridade';

  @override
  String get incidentPriorityRoutine => 'Rotina';

  @override
  String get incidentRoleHintAssignedOperator => 'Operador atribuído';

  @override
  String get incidentRoleHintOperatorOrAbove => 'Operador ou superior';

  @override
  String get incidentRoleHintSupervisorOrAdmin => 'Supervisor ou administrador';

  @override
  String get incidentStateMachineAssigneeRequired =>
      'assigneeId é obrigatório ao transicionar para atribuído';

  @override
  String incidentStateMachineCreateDenied(String roleName) {
    return 'createIncident negado para o papel $roleName';
  }

  @override
  String incidentStateMachineInvalidTransition(
    String fromState,
    String toState,
  ) {
    return '$fromState -> $toState não é uma transição válida';
  }

  @override
  String incidentStateMachinePermissionDenied(
    String permissionName,
    String roleName,
  ) {
    return '$permissionName negado para o papel $roleName';
  }

  @override
  String incidentStateMachineTerminalState(String stateName) {
    return 'Não é possível transicionar de $stateName: estado terminal: $stateName';
  }

  @override
  String incidentTerminalStateMessage(String state) {
    return 'Este incidente está $state — nenhuma ação disponível.';
  }

  @override
  String get incidentTimelineEmpty => 'Nenhum histórico de transições';

  @override
  String get incidentTimelineFinalState =>
      'Estado final — nenhuma transição possível';

  @override
  String get incidentTimelineSuperseded => 'substituído';

  @override
  String get incidentTimelineUnknownRole => 'desconhecido';

  @override
  String get incidentTransitionHistoryHeader => 'Histórico de transições';

  @override
  String incidentTransitionsLoadError(String error) {
    return 'Falha ao carregar transições: $error';
  }

  @override
  String get legalAcceptanceAgreeButton => 'Concordo';

  @override
  String get legalAcceptanceAgreeSemantics =>
      'Concordo com os Termos de Serviço e a Política de Privacidade. Toque para aceitar e continuar.';

  @override
  String get legalAcceptanceAppIconSemantics => 'Ícone do app Socialmesh';

  @override
  String get legalAcceptanceDateFormatApril => 'Abril';

  @override
  String get legalAcceptanceDateFormatAugust => 'Agosto';

  @override
  String get legalAcceptanceDateFormatDecember => 'Dezembro';

  @override
  String get legalAcceptanceDateFormatFebruary => 'Fevereiro';

  @override
  String get legalAcceptanceDateFormatJanuary => 'Janeiro';

  @override
  String get legalAcceptanceDateFormatJuly => 'Julho';

  @override
  String get legalAcceptanceDateFormatJune => 'Junho';

  @override
  String get legalAcceptanceDateFormatMarch => 'Março';

  @override
  String get legalAcceptanceDateFormatMay => 'Maio';

  @override
  String get legalAcceptanceDateFormatNovember => 'Novembro';

  @override
  String get legalAcceptanceDateFormatOctober => 'Outubro';

  @override
  String get legalAcceptanceDateFormatSeptember => 'Setembro';

  @override
  String get legalAcceptanceDeclineBody =>
      'É necessário aceitar os Termos de Serviço e a Política de Privacidade para usar o Socialmesh. Você pode revisá-los e aceitar quando quiser.';

  @override
  String get legalAcceptanceDeclineButton => 'Agora não';

  @override
  String get legalAcceptanceDeclineSemantics =>
      'Agora não. Recusar e sair do app.';

  @override
  String get legalAcceptanceDeclineTitle => 'Termos obrigatórios';

  @override
  String get legalAcceptanceFinePrint =>
      'Ao tocar em \"Concordo\", você aceita nossos Termos de Serviço e reconhece nossa Política de Privacidade.';

  @override
  String get legalAcceptanceFinePrintSemantics =>
      'Ao tocar em Concordo, você aceita nossos Termos de Serviço e reconhece nossa Política de Privacidade.';

  @override
  String get legalAcceptanceGoBackSemantics =>
      'Voltar para revisar e aceitar os termos';

  @override
  String get legalAcceptanceInformationSemantics => 'Informações';

  @override
  String get legalAcceptanceLegalShieldSemantics => 'Escudo legal';

  @override
  String legalAcceptancePrivacyEffective(String date) {
    return 'Em vigor desde $date';
  }

  @override
  String get legalAcceptancePrivacyPolicy => 'Política de Privacidade';

  @override
  String get legalAcceptanceReviewButton => 'Revisar termos';

  @override
  String get legalAcceptanceSubtitleInitial =>
      'Antes de começar, revise nossos Termos de Serviço e a Política de Privacidade.';

  @override
  String get legalAcceptanceSubtitleUpdate =>
      'Atualizamos nossos Termos de Serviço. Revise e aceite as alterações para continuar usando o Socialmesh.';

  @override
  String legalAcceptanceTermsEffective(String date) {
    return 'Em vigor desde $date';
  }

  @override
  String get legalAcceptanceTermsOfService => 'Termos de Serviço';

  @override
  String get legalAcceptanceTermsSummarySemantics => 'Resumo dos termos';

  @override
  String get legalAcceptanceTitleInitial => 'Termos e Privacidade';

  @override
  String get legalAcceptanceTitleUpdate => 'Termos atualizados';

  @override
  String get legalAcceptanceViewPrivacySemantics =>
      'Ver Política de Privacidade';

  @override
  String get legalAcceptanceViewTermsSemantics => 'Ver Termos de Serviço';

  @override
  String get legalEligibilityBody =>
      'Isso nos ajuda a aplicar as configurações de privacidade corretas. Sua faixa etária não é compartilhada com outros usuários.';

  @override
  String get legalEligibilityConfirmButton => 'Continuar';

  @override
  String get legalEligibilityConfirmSemantics =>
      'Continuar. Toque para confirmar sua seleção de idade e prosseguir.';

  @override
  String get legalEligibilityExitBody =>
      'Você deve confirmar sua idade para usar o Socialmesh. Você pode confirmar quando quiser.';

  @override
  String get legalEligibilityExitButton => 'Sair';

  @override
  String get legalEligibilityExitSemantics =>
      'Sair. Você deve confirmar sua idade para usar o Socialmesh.';

  @override
  String get legalEligibilityExitTitle => 'Confirmação de idade obrigatória';

  @override
  String get legalEligibilityGoBackButton => 'Voltar';

  @override
  String get legalEligibilityGoBackSemantics =>
      'Voltar para confirmar sua idade';

  @override
  String get legalEligibilityIconSemantics => 'Elegibilidade por idade';

  @override
  String get legalEligibilityInformationSemantics => 'Informações';

  @override
  String get legalEligibilityNoticeSemantics =>
      'Aviso de elegibilidade por idade';

  @override
  String get legalEligibilityPrivacyLink => 'Privacidade';

  @override
  String get legalEligibilityTermsLink => 'Termos';

  @override
  String get legalEligibilityTitle => 'Confirmação de Idade';

  @override
  String get legalEligibilityViewPrivacySemantics =>
      'Ver Política de Privacidade';

  @override
  String get legalEligibilityViewTermsSemantics => 'Ver Termos de Serviço';

  @override
  String get legalEligibilityAgePrompt =>
      'Selecione sua faixa etária para continuar.';

  @override
  String get legalEligibilityOptionUnder13 => 'Menos de 13';

  @override
  String get legalEligibilityOptionUnder13Subtitle =>
      'Aplicativo não disponível';

  @override
  String get legalEligibilityOptionTeen => '13 a 17';

  @override
  String get legalEligibilityOptionTeenSubtitle =>
      'Configurações de privacidade aprimoradas serão aplicadas';

  @override
  String get legalEligibilityOptionAdult => '18 anos ou mais';

  @override
  String get settingsAgeGroupTitle => 'Faixa Etária';

  @override
  String get settingsAgeGroupSubtitleUnknown => 'Não definido';

  @override
  String get settingsAgeGroupSubtitleUnder13 => 'Menor de 13';

  @override
  String get settingsAgeGroupSubtitleTeen => '13 a 17';

  @override
  String get settingsAgeGroupSubtitleAdult => '18 anos ou mais';

  @override
  String get lilygoModelPriceUnavailable => 'Preço indisponível';

  @override
  String get linkDeviceBannerLinkButton => 'Vincular';

  @override
  String linkDeviceBannerLinkError(String error) {
    return 'Falha ao vincular: $error';
  }

  @override
  String get linkDeviceBannerLinkedSuccess =>
      'Dispositivo vinculado ao seu perfil!';

  @override
  String get linkDeviceBannerSubtitle => 'Outros podem encontrar e seguir você';

  @override
  String get linkDeviceBannerTitle => 'Vincule este dispositivo ao seu perfil';

  @override
  String mapAgeHours(String hours) {
    return '${hours}h atrás';
  }

  @override
  String mapAgeMinutes(String minutes) {
    return '${minutes}m atrás';
  }

  @override
  String mapAgeSeconds(String seconds) {
    return '${seconds}s atrás';
  }

  @override
  String get mapCoordinatesCopied =>
      'Coordenadas copiadas para a área de transferência';

  @override
  String get mapCopyBothCoordinates => 'Ambas as coordenadas A e B';

  @override
  String get mapCopyCoordinates => 'Copiar coordenadas';

  @override
  String get mapCopyCoordinatesTooltip => 'Copiar coordenadas';

  @override
  String get mapCopySummary => 'Copiar resumo';

  @override
  String get mapDelete => 'Excluir';

  @override
  String get mapDismissTooltip => 'Fechar';

  @override
  String get mapDistance10Km => '10 km';

  @override
  String get mapDistance1Km => '1 km';

  @override
  String get mapDistance25Km => '25 km';

  @override
  String get mapDistance5Km => '5 km';

  @override
  String get mapDistanceAll => 'Todos';

  @override
  String mapDistanceKilometers(String km) {
    return '${km}km';
  }

  @override
  String mapDistanceKilometersFormal(String km) {
    return '$km km';
  }

  @override
  String mapDistanceKilometersPrecise(String km) {
    return '$km km';
  }

  @override
  String mapDistanceKilometersRound(String km) {
    return '${km}km';
  }

  @override
  String mapDistanceMeters(String meters) {
    return '${meters}m';
  }

  @override
  String mapDistanceMetersFormal(String meters) {
    return '$meters m';
  }

  @override
  String get mapDropWaypoint => 'Marcar waypoint';

  @override
  String get mapEmptyBodyNoNodes =>
      'Os nós aparecerão no mapa quando\ntransmitirem sua posição GPS.';

  @override
  String mapEmptyBodyWithNodes(int totalNodes) {
    return '$totalNodes nós descobertos, mas nenhum\ntransmitiu a posição GPS ainda.';
  }

  @override
  String get mapEmptyTitle => 'Nenhum nó com GPS';

  @override
  String get mapEntitiesTitle => 'Entidades';

  @override
  String mapEstimatedPathLoss(String pathLoss) {
    return 'Perda de percurso estimada: $pathLoss dB (espaço livre)';
  }

  @override
  String get mapExitMeasureMode => 'Sair do modo de medição';

  @override
  String get mapExitMeasureModeTooltip => 'Sair do modo de medição';

  @override
  String get mapFilterActive => 'Ativos';

  @override
  String get mapFilterAll => 'Todos';

  @override
  String get mapFilterInRange => 'No alcance';

  @override
  String get mapFilterInactive => 'Inativos';

  @override
  String get mapFilterNodesTitle => 'Filtrar nós';

  @override
  String get mapFilterNodesTooltip => 'Filtrar nós';

  @override
  String get mapFilterWithGps => 'Com GPS';

  @override
  String get mapGlobeView => 'Vista 3D do globo';

  @override
  String get mapHelp => 'Ajuda';

  @override
  String get mapHideConnectionLines => 'Ocultar linhas de conexão';

  @override
  String get mapHideHeatmap => 'Ocultar mapa de calor';

  @override
  String get mapHidePositionHistory => 'Ocultar histórico de posições';

  @override
  String get mapHideRangeCircles => 'Ocultar círculos de alcance';

  @override
  String get mapHideTakEntities => 'Ocultar entidades TAK';

  @override
  String get mapLastKnown => '• Última conhecida';

  @override
  String get mapLinkBudgetCopied =>
      'Link budget copiado para a área de transferência';

  @override
  String get mapLocationTitle => 'Localização';

  @override
  String get mapLongPressForActions => 'Pressione e segure para ações';

  @override
  String get mapLosAnalysis => 'Análise LOS';

  @override
  String get mapLosAnalysisSubtitle =>
      'Curvatura terrestre + verificação da zona de Fresnel';

  @override
  String get mapLosFetchingTerrain => 'A obter dados de terreno…';

  @override
  String get mapLosLegendClear => 'Livre';

  @override
  String get mapLosLegendMarginal => 'Marginal';

  @override
  String get mapLosLegendObstructed => 'Obstruído';

  @override
  String mapLosBulgeAndFresnel(String bulge, String fresnel) {
    return 'Protuberância: ${bulge}m · F1: ${fresnel}m';
  }

  @override
  String mapLosVerdict(String verdict) {
    return 'LOS: $verdict';
  }

  @override
  String get mapMaxDistance => 'Distância máxima';

  @override
  String get mapMeasureDistance => 'Medir distância';

  @override
  String get mapMeasureMarkerA => 'A';

  @override
  String get mapMeasureMarkerB => 'B';

  @override
  String get mapMeasureTapPointA => 'Toque em um nó ou no mapa para o ponto A';

  @override
  String get mapMeasureTapPointB => 'Toque em um nó ou no mapa para o ponto B';

  @override
  String get mapMeasurementActions => 'Ações de medição';

  @override
  String get mapMeasurementCopied =>
      'Medição copiada para a área de transferência';

  @override
  String get mapNavigateToTooltip => 'Navegar até';

  @override
  String get mapNewMeasurement => 'Nova medição';

  @override
  String get mapNoEntities => 'Nenhuma entidade';

  @override
  String get mapNoMatchingEntities => 'Nenhuma entidade correspondente';

  @override
  String mapNodeCount(String count) {
    return '$count nós';
  }

  @override
  String get mapNodesTitle => 'Nós';

  @override
  String get mapOpenInExternalApp => 'Abrir em app de mapas externo';

  @override
  String get mapOpenMidpointInMaps => 'Abrir ponto médio no Mapas';

  @override
  String get mapPositionBroadcastHint =>
      'Transmissões de posição podem levar até 15 minutos.\nToque para solicitar imediatamente.';

  @override
  String get mapRefreshPositions => 'Atualizar posições';

  @override
  String get mapRefreshing => 'Atualizando...';

  @override
  String get mapRequestPositions => 'Solicitar posições';

  @override
  String get mapRequesting => 'Solicitando...';

  @override
  String get mapReverseDirection => 'Inverter direção da medição';

  @override
  String get mapRfLinkBudget => 'Orçamento de Ligação RF';

  @override
  String mapRfLinkBudgetClipboard(
    String distance,
    String frequency,
    String pathLoss,
    String linkMargin,
  ) {
    return 'RF Link Budget (perda em espaço livre)\nDistância: $distance\nFrequência: $frequency\nPerda de percurso: $pathLoss\nMargem de enlace: $linkMargin';
  }

  @override
  String get mapSaDashboard => 'Painel TAK';

  @override
  String get mapScreenTitle => 'Mapa Mesh';

  @override
  String get mapSearchEntitiesHint => 'Buscar entidades...';

  @override
  String get mapSearchHint => 'Tente outro termo de busca';

  @override
  String get mapSearchNodesHint => 'Buscar nós...';

  @override
  String get mapSettings => 'Configurações';

  @override
  String get mapShare => 'Compartilhar';

  @override
  String mapShareDistanceLabel(String distance) {
    return 'Distância: $distance';
  }

  @override
  String get mapShareLocation => 'Compartilhar localização';

  @override
  String get mapShareMeasurement => 'Compartilhar medição';

  @override
  String get mapShareMeasurementSubtitle =>
      'Compartilhar via folha de compartilhamento';

  @override
  String get mapShowConnectionLines => 'Mostrar linhas de conexão';

  @override
  String get mapShowHeatmap => 'Mostrar mapa de calor';

  @override
  String get mapShowPositionHistory => 'Mostrar histórico de posições';

  @override
  String get mapShowRangeCircles => 'Mostrar círculos de alcance';

  @override
  String get mapShowTakEntities => 'Mostrar entidades TAK';

  @override
  String get mapStyleTooltip => 'Estilo do mapa';

  @override
  String get mapSwapAB => 'Trocar A ↔ B';

  @override
  String get mapTakActive => 'Ativo';

  @override
  String get mapTakActiveBadge => 'ATIVO';

  @override
  String mapTakEntityCount(int count) {
    return '• $count entidades';
  }

  @override
  String get mapTakStale => 'Obsoleto';

  @override
  String get mapTakStaleBadge => 'OBSOLETO';

  @override
  String get mapTakTrack => 'Rastrear';

  @override
  String get mapTakTracked => 'Rastreado';

  @override
  String mapWaypointDefaultLabel(int number) {
    return 'WP $number';
  }

  @override
  String get mapYouBadge => 'VOCÊ';

  @override
  String get mesh3dAutoRotate => 'Rotação automática';

  @override
  String get mesh3dChangeViewTooltip => 'Alterar vista';

  @override
  String mesh3dFilteredNodeCount(int filtered, int total) {
    return '$filtered/$total nós';
  }

  @override
  String get mesh3dHelp => 'Ajuda';

  @override
  String get mesh3dHideConnections => 'Ocultar conexões';

  @override
  String get mesh3dLegendActive => 'Ativo';

  @override
  String get mesh3dLegendActiveNow => 'Ativo agora';

  @override
  String get mesh3dLegendActivePeer => 'Peer ativo';

  @override
  String get mesh3dLegendFading => 'Esmaecendo';

  @override
  String get mesh3dLegendFadingPeer => 'Peer esmaecendo';

  @override
  String get mesh3dLegendFairSignal => 'Sinal razoável';

  @override
  String get mesh3dLegendGoodSignal => 'Sinal bom';

  @override
  String get mesh3dLegendHighAltitude => 'Alta altitude';

  @override
  String get mesh3dLegendLowAltitude => 'Baixa altitude';

  @override
  String get mesh3dLegendOffline => 'Offline';

  @override
  String get mesh3dLegendPoorSignal => 'Sinal fraco';

  @override
  String get mesh3dLegendSnrBar => 'Barra SNR';

  @override
  String get mesh3dLegendStaleIdle => 'Obsoleto / inativo';

  @override
  String get mesh3dLegendYourNode => 'Seu nó';

  @override
  String get mesh3dMyNodeBadge => 'EU';

  @override
  String mesh3dNodeCount(int count) {
    return '$count nós';
  }

  @override
  String get mesh3dNodesDrawerTitle => 'Nós';

  @override
  String get mesh3dShowConnections => 'Mostrar conexões';

  @override
  String get mesh3dStatOnline => 'Online';

  @override
  String get mesh3dStatChUtil => 'Util. canal';

  @override
  String get mesh3dStatGps => 'GPS';

  @override
  String get mesh3dStatSnr => 'SNR';

  @override
  String get mesh3dStatTotal => 'Total';

  @override
  String get mesh3dStopRotation => 'Parar rotação';

  @override
  String get mesh3dViewModeTitle => 'Modo de vista';

  @override
  String meshHealthActiveNodesPackets(int activeNodeCount, int totalPackets) {
    return '$activeNodeCount nós ativos • $totalPackets pacotes';
  }

  @override
  String get meshHealthBatteryUsageSubtitle =>
      'O monitoramento Mesh Health consome bateria extra. Pause quando não precisar.';

  @override
  String get meshHealthBatteryUsageTitle => 'Uso de bateria';

  @override
  String get meshHealthChannelUtilization => 'Utilização do canal';

  @override
  String get meshHealthCriticalIssues => 'Problemas críticos detectados';

  @override
  String get meshHealthDetectedIssues => 'Problemas detectados';

  @override
  String get meshHealthDontRemindAgain => 'Não lembrar novamente';

  @override
  String get meshHealthFloodBadge => 'INUNDAÇÃO';

  @override
  String get meshHealthHealthy => 'Mesh saudável';

  @override
  String get meshHealthIndicatorLabel => 'Saúde';

  @override
  String meshHealthIssueCount(int count) {
    return '$count problemas';
  }

  @override
  String get meshHealthIssuesDetected => 'Problemas detectados';

  @override
  String get meshHealthKeepRunning => 'Manter ativo';

  @override
  String get meshHealthMonitoringActiveTitle =>
      'O monitoramento ainda está ativo';

  @override
  String get meshHealthMonitoringBatteryWarning =>
      'O monitoramento Mesh Health consome bateria extra em segundo plano.';

  @override
  String get meshHealthMonitoringPaused => 'Monitoramento pausado';

  @override
  String get meshHealthNoDataYet => 'Sem dados ainda';

  @override
  String get meshHealthNoIssuesDetected => 'Nenhum problema detectado';

  @override
  String get meshHealthNoNodesDetected => 'Nenhum nó detectado';

  @override
  String meshHealthNodePrefix(String nodeId) {
    return 'Nó: $nodeId';
  }

  @override
  String get meshHealthNormal => 'Normal';

  @override
  String get meshHealthOfAirtime => 'de airtime';

  @override
  String meshHealthPacketsAirtime(int packetCount, int airtimeMs) {
    return '$packetCount pacotes • ${airtimeMs}ms airtime';
  }

  @override
  String get meshHealthPauseAndLeave => 'Pausar e sair';

  @override
  String get meshHealthPauseTooltip => 'Pausar';

  @override
  String get meshHealthReliability => 'Confiabilidade';

  @override
  String get meshHealthReliabilityFair => 'Razoável';

  @override
  String get meshHealthReliabilityGood => 'Boa';

  @override
  String get meshHealthReliabilityPoor => 'Fraca';

  @override
  String get meshHealthResetDataTooltip => 'Redefinir dados';

  @override
  String get meshHealthResumeTooltip => 'Retomar';

  @override
  String get meshHealthSaturated => 'SATURADO';

  @override
  String get meshHealthSpamBadge => 'SPAM';

  @override
  String get meshHealthThresholdLabel => 'Limite de 50%';

  @override
  String get meshHealthTitle => 'Saúde Mesh';

  @override
  String get meshHealthTopContributors => 'Principais contribuidores';

  @override
  String get meshHealthUtilization => 'Utilização';

  @override
  String get meshcoreAbout => 'Sobre';

  @override
  String get meshcoreAboutDescription =>
      'SocialMesh é um app companion para rádio mesh que suporta dispositivos Meshtastic e MeshCore.';

  @override
  String get meshcoreAboutSocialMesh => 'Sobre o SocialMesh';

  @override
  String get meshcoreActions => 'Ações';

  @override
  String get meshcoreActiveLabel => 'Ativo';

  @override
  String get meshcoreAdd => 'Adicionar';

  @override
  String get meshcoreAddContact => 'Adicionar contato';

  @override
  String get meshcoreAddContactButton => 'Adicionar contato';

  @override
  String get meshcoreAdvertisementSent => 'Anúncio enviado';

  @override
  String get meshcoreAdvertisementSentTools => 'Anúncio enviado';

  @override
  String get meshcoreAnalysis => 'Análise';

  @override
  String get meshcoreBandwidthLabel => 'Largura de banda';

  @override
  String get meshcoreBasedOnLiPoVoltage =>
      'Baseado na faixa de tensão LiPo (3.0V - 4.2V)';

  @override
  String get meshcoreBatteryAndStorage => 'Bateria e armazenamento';

  @override
  String get meshcoreBatteryInfoNotAvailable => 'Info de bateria indisponível';

  @override
  String get meshcoreBatteryLabel => 'Bateria';

  @override
  String get meshcoreBatteryStatus => 'Status da bateria';

  @override
  String get meshcoreBatteryStatusLabel => 'Bateria';

  @override
  String get meshcoreBatteryUnknown => 'Desconhecido';

  @override
  String get meshcoreBroadcastPresenceToMesh =>
      'Transmita sua presença para a rede mesh';

  @override
  String get meshcoreBroadcastYourPresence => 'Transmitir sua presença';

  @override
  String get meshcoreCancel => 'Cancelar';

  @override
  String get meshcoreCenter => 'Centralizar';

  @override
  String meshcoreChannelAlreadyExists(String channelName) {
    return '$channelName já está nos seus canais';
  }

  @override
  String get meshcoreChannelCodeCopied => 'Código do canal copiado';

  @override
  String meshcoreChannelCreated(String channelName) {
    return 'Canal \"$channelName\" criado';
  }

  @override
  String get meshcoreChannelNameHint => 'Nome do canal';

  @override
  String get meshcoreChannelNameHintGeneral => 'geral';

  @override
  String get meshcoreChannelNameHintHashtag => 'ex. geral';

  @override
  String get meshcoreChannelNameLabel => 'Nome do Canal';

  @override
  String get meshcoreChannelPskCopied => 'PSK do canal copiada';

  @override
  String get meshcoreChannelsCreateChannel => 'Criar Canal';

  @override
  String get meshcoreChannelsJoinChannel => 'Entrar no Canal';

  @override
  String get meshcoreChannelsLabel => 'Canais';

  @override
  String get meshcoreChannelsRefreshChannels => 'Atualizar Canais';

  @override
  String get meshcoreChannelsTitle => 'Canais';

  @override
  String get meshcoreChatNode => 'Nó de Chat';

  @override
  String get meshcoreClear => 'Limpar';

  @override
  String get meshcoreClose => 'Fechar';

  @override
  String get meshcoreCodingRateLabel => 'Taxa de Codificação';

  @override
  String get meshcoreConnected => 'Conectado';

  @override
  String meshcoreConnectedTo(String deviceName) {
    return 'Conectado a $deviceName';
  }

  @override
  String get meshcoreConsoleCaptureCleared => 'Captura limpa';

  @override
  String get meshcoreConsoleClear => 'Limpar';

  @override
  String get meshcoreConsoleCopyHex => 'Copiar Hex';

  @override
  String get meshcoreConsoleDevBadge => 'DEV';

  @override
  String meshcoreConsoleFramesCaptured(int count) {
    return '$count frames capturados';
  }

  @override
  String get meshcoreConsoleHexCopied =>
      'Log hex copiado para a área de transferência';

  @override
  String get meshcoreConsoleNoFrames => 'Nenhum frame capturado ainda';

  @override
  String get meshcoreConsoleRefresh => 'Atualizar';

  @override
  String get meshcoreConsoleTitle => 'Console MeshCore';

  @override
  String meshcoreContactAdded(String contactName) {
    return '$contactName adicionado';
  }

  @override
  String meshcoreContactAddedToContacts(String contactName) {
    return '$contactName adicionado aos contatos';
  }

  @override
  String meshcoreContactAlreadyExists(String contactName) {
    return '$contactName já está nos seus contatos';
  }

  @override
  String get meshcoreContactCodeCopied => 'Código de contato copiado';

  @override
  String meshcoreContactCount(int count) {
    return '$count contato';
  }

  @override
  String meshcoreContactCountPlural(int count) {
    return '$count contatos';
  }

  @override
  String meshcoreContactRemoved(String contactName) {
    return '$contactName removido';
  }

  @override
  String get meshcoreContactsLabel => 'Contatos';

  @override
  String get meshcoreContactsTitle => 'Contatos';

  @override
  String get meshcoreControlAdvertVisibility =>
      'Controlar visibilidade dos anúncios';

  @override
  String get meshcoreCoordinatesCopied =>
      'Coordenadas copiadas para a área de transferência';

  @override
  String get meshcoreCopy => 'Copiar';

  @override
  String get meshcoreCopyChannelCode => 'Copiar Código do Canal';

  @override
  String get meshcoreCopyCoordinates => 'Copiar Coordenadas';

  @override
  String get meshcoreCopyCoordinatesSubtitle => 'Ambas as coordenadas A e B';

  @override
  String get meshcoreCopyPublicKey => 'Copiar Chave Pública';

  @override
  String get meshcoreCopySummary => 'Copiar Resumo';

  @override
  String get meshcoreCreate => 'Criar';

  @override
  String get meshcoreCreateChannelButton => 'Criar Canal';

  @override
  String get meshcoreCreateChannelDialogTitle => 'Criar Canal';

  @override
  String get meshcoreDebug => 'Debug';

  @override
  String get meshcoreDeviceInfo => 'Info do Dispositivo';

  @override
  String get meshcoreDeviceInfoCopied => 'Info do dispositivo copiadas';

  @override
  String get meshcoreDeviceInfoNotAvailable =>
      'Info do dispositivo indisponíveis';

  @override
  String get meshcoreDeviceInfoTool => 'Info do Dispositivo';

  @override
  String get meshcoreDeviceInformation => 'Informações do Dispositivo';

  @override
  String get meshcoreDiagnostics => 'Diagnósticos';

  @override
  String get meshcoreDisconnect => 'Desconectar';

  @override
  String get meshcoreDisconnectedChannelsDescription =>
      'Conecte um dispositivo MeshCore para ver os canais';

  @override
  String get meshcoreDisconnectedContactsDescription =>
      'Conecte um dispositivo MeshCore para ver os contatos';

  @override
  String get meshcoreDisconnectedMapDescription =>
      'Conecte um dispositivo MeshCore para ver o mapa';

  @override
  String get meshcoreDisconnectedMapTitle => 'MeshCore Desconectado';

  @override
  String get meshcoreDisconnectedMessagesWillQueue =>
      'Desconectado - Mensagens serão enfileiradas';

  @override
  String get meshcoreDisconnectedStatus => 'Desconectado';

  @override
  String get meshcoreDisconnectedTitle => 'MeshCore Desconectado';

  @override
  String get meshcoreDisconnectedToolsDescription =>
      'Conecte um dispositivo MeshCore para acessar as ferramentas';

  @override
  String get meshcoreDisconnectedToolsTitle => 'MeshCore Desconectado';

  @override
  String get meshcoreDiscovery => 'Descoberta';

  @override
  String get meshcoreDone => 'Concluído';

  @override
  String get meshcoreEditNodeName => 'Editar Nome do Nó';

  @override
  String get meshcoreEnterChannelCode => 'Inserir Código do Canal';

  @override
  String get meshcoreEnterChannelCodeSubtitle =>
      'Cole um código de convite do canal';

  @override
  String get meshcoreEnterCodeManually => 'Inserir Código Manualmente';

  @override
  String get meshcoreEnterContactCode => 'Inserir Código de Contato';

  @override
  String get meshcoreEnterNodeNameHint => 'Inserir nome do nó...';

  @override
  String get meshcoreErrorEnterChannelCode => 'Insira um código de canal';

  @override
  String get meshcoreErrorEnterChannelName => 'Insira um nome de canal';

  @override
  String get meshcoreExitMeasureMode => 'Sair do modo medição';

  @override
  String get meshcoreFailedToRebootDevice => 'Falha ao reiniciar o dispositivo';

  @override
  String get meshcoreFailedToSendAdTools => 'Falha ao enviar anúncio';

  @override
  String get meshcoreFailedToSendAdvertisement => 'Falha ao enviar anúncio';

  @override
  String get meshcoreFailedToSendMessage => 'Falha ao enviar mensagem';

  @override
  String get meshcoreFailedToSetName => 'Falha ao definir nome';

  @override
  String get meshcoreFailedToSyncTime => 'Falha ao sincronizar horário';

  @override
  String get meshcoreFilterChatNodes => 'Nós de Chat';

  @override
  String get meshcoreFilterMap => 'Filtrar Mapa';

  @override
  String get meshcoreFilterOtherNodes => 'Outros Nós';

  @override
  String get meshcoreFilterRepeaters => 'Repetidores';

  @override
  String get meshcoreFilterTooltip => 'Filtrar';

  @override
  String get meshcoreFramesLabel => 'Quadros';

  @override
  String get meshcoreFrequencyLabel => 'Frequência';

  @override
  String get meshcoreInvalidChannelCodeFormat =>
      'Formato de código de canal inválido (esperado: nome:pskHex)';

  @override
  String get meshcoreInvalidContactCode => 'Código de contato inválido';

  @override
  String get meshcoreInvalidQrCodeFormat => 'Formato de código QR inválido';

  @override
  String get meshcoreJoin => 'Entrar';

  @override
  String get meshcoreJoinButton => 'Entrar';

  @override
  String get meshcoreJoinHashtagChannel => 'Entrar em Canal Hashtag';

  @override
  String get meshcoreJoinHashtagChannelSubtitle =>
      'Insira o nome do canal (ex. #geral)';

  @override
  String meshcoreJoinedChannel(String channelName) {
    return 'Entrou em $channelName';
  }

  @override
  String meshcoreJoinedHashtagChannel(String name) {
    return 'Entrou em #$name';
  }

  @override
  String get meshcoreJustNow => 'Agora';

  @override
  String get meshcoreLeave => 'Sair';

  @override
  String get meshcoreLeaveChannel => 'Sair do Canal';

  @override
  String meshcoreLeaveChannelMessage(String channelName) {
    return 'Tem certeza que deseja sair de $channelName?';
  }

  @override
  String get meshcoreLeaveChannelTitle => 'Sair do Canal?';

  @override
  String meshcoreLeftChannel(String channelName) {
    return 'Saiu de $channelName';
  }

  @override
  String get meshcoreLegendChat => 'Chat';

  @override
  String get meshcoreLegendRepeater => 'Repetidor';

  @override
  String get meshcoreLegendRoom => 'Sala';

  @override
  String get meshcoreLegendSensor => 'Sensor';

  @override
  String get meshcoreLoadingChannels => 'Carregando canais...';

  @override
  String get meshcoreLoadingContacts => 'Carregando contatos...';

  @override
  String get meshcoreLoadingMessages => 'Carregando mensagens...';

  @override
  String get meshcoreLocationComingSoon =>
      'Configurações de localização em breve.\n\nIsso permitirá definir manualmente a posição do nó ou usar o GPS.';

  @override
  String get meshcoreLocationInfoLabel => 'Localização';

  @override
  String get meshcoreLocationSetting => 'Localização';

  @override
  String get meshcoreLongPressForActions => 'Pressione e segure para ações';

  @override
  String get meshcoreMapTitle => 'Mapa';

  @override
  String get meshcoreMaxTxPowerLabel => 'Potência TX Máx';

  @override
  String get meshcoreMeasurementActions => 'Ações de Medição';

  @override
  String get meshcoreMeasurementCopied =>
      'Medição copiada para a área de transferência';

  @override
  String get meshcoreMeshCoreDevice => 'Dispositivo MeshCore';

  @override
  String get meshcoreMessageButton => 'Mensagem';

  @override
  String get meshcoreMonitorPowerStorage => 'Monitorar energia e armazenamento';

  @override
  String get meshcoreMyContactCode => 'Meu Código de Contato';

  @override
  String get meshcoreNameLabel => 'Nome';

  @override
  String get meshcoreNewMeasurement => 'Nova medição';

  @override
  String get meshcoreNoChannels => 'Nenhum Canal';

  @override
  String get meshcoreNoChannelsDescription =>
      'Canais são espaços compartilhados para comunicação em grupo.\n\nCrie um novo canal ou entre em um existente.';

  @override
  String get meshcoreNoContacts => 'Nenhum Contato';

  @override
  String get meshcoreNoContactsDescription =>
      'Os contatos aparecerão aqui quando descobertos via anúncios.\n\nVocê também pode adicionar contatos manualmente usando o código de contato.';

  @override
  String get meshcoreNoContactsForTrace =>
      'Nenhum contato disponível para rastreamento';

  @override
  String get meshcoreNoContactsWithLocation => 'Nenhum Contato com Localização';

  @override
  String get meshcoreNoContactsWithLocationDescription =>
      'Contatos com coordenadas GPS aparecerão no mapa.\nVerifique se seus contatos têm o compartilhamento de localização ativado.';

  @override
  String get meshcoreNoMessagesYet => 'Nenhuma mensagem ainda';

  @override
  String get meshcoreNodeNameLabel => 'Nome do Nó';

  @override
  String get meshcoreNodeNameSetting => 'Nome do Nó';

  @override
  String get meshcoreNodeNameUpdated => 'Nome do nó atualizado';

  @override
  String get meshcoreNodeSettings => 'Configurações do Nó';

  @override
  String get meshcoreNotConnected => 'Não conectado';

  @override
  String get meshcoreNotConnectedToDevice =>
      'Não conectado ao dispositivo MeshCore';

  @override
  String get meshcoreNotConnectedTools => 'Não conectado';

  @override
  String get meshcoreNotSet => 'Não definido';

  @override
  String get meshcoreNotValidChannelQr =>
      'Código QR de canal MeshCore inválido';

  @override
  String get meshcoreNotValidContactQr =>
      'Código QR de contato MeshCore inválido';

  @override
  String get meshcoreNotYetImplemented => 'Ainda não implementado';

  @override
  String get meshcoreOpenChannel => 'Abrir Canal';

  @override
  String get meshcoreOpenInExternalMapApp => 'Abrir no app de mapas externo';

  @override
  String get meshcoreOpenMidpointInMaps => 'Abrir Ponto Médio no Mapas';

  @override
  String get meshcorePasteChannelCodeHint => 'Cole o código do canal aqui...';

  @override
  String get meshcorePasteContactCodeHint => 'Cole o código de contato aqui...';

  @override
  String get meshcorePointCameraAtChannelQr =>
      'Aponte a câmera para o código QR de um canal MeshCore';

  @override
  String get meshcorePointCameraAtContactQr =>
      'Aponte a câmera para o código QR de um contato MeshCore';

  @override
  String get meshcorePrivacyComingSoon =>
      'Configurações de privacidade em breve.\n\nIsso controlará se o seu nó transmite anúncios.';

  @override
  String get meshcorePrivacyMode => 'Modo Privacidade';

  @override
  String get meshcorePrivacyModeDialogTitle => 'Modo Privacidade';

  @override
  String get meshcorePrivate => 'Privado';

  @override
  String get meshcorePrivateChannel => 'Canal Privado';

  @override
  String get meshcoreProtocolCapture => 'Captura de Protocolo';

  @override
  String get meshcoreProtocolCaptureDialogTitle => 'Captura de Protocolo';

  @override
  String get meshcorePskDerivedFromName => 'PSK derivada do nome (descobrível)';

  @override
  String get meshcorePublic => 'Público';

  @override
  String get meshcorePublicChannel => 'Canal Público';

  @override
  String get meshcorePublicHashtagChannel => 'Canal Hashtag Público';

  @override
  String get meshcorePublicKeyCopied => 'Chave pública copiada';

  @override
  String get meshcorePublicKeyCopiedSettings => 'Chave pública copiada';

  @override
  String get meshcorePublicKeySettingsLabel => 'Chave Pública';

  @override
  String get meshcoreRadioConfiguredOnFirmware =>
      'As configurações de rádio são definidas no firmware do dispositivo.';

  @override
  String get meshcoreRadioSettings => 'Configurações de Rádio';

  @override
  String get meshcoreRadioSettingsDialogTitle => 'Configurações de Rádio';

  @override
  String get meshcoreRadioSettingsNotAvailable =>
      'Configurações de rádio indisponíveis';

  @override
  String get meshcoreRadioSettingsSubtitle =>
      'Frequência, potência TX, largura de banda';

  @override
  String get meshcoreRadioSettingsTitle => 'Configurações de Rádio';

  @override
  String get meshcoreRadioSettingsTool => 'Configurações de Rádio';

  @override
  String get meshcoreRandomPskPrivate => 'PSK aleatória (privado)';

  @override
  String get meshcoreReboot => 'Reiniciar';

  @override
  String get meshcoreRebootCommandSent => 'Comando de reinício enviado';

  @override
  String get meshcoreRebootDevice => 'Reiniciar Dispositivo';

  @override
  String get meshcoreRebootDeviceMessage =>
      'Tem certeza que deseja reiniciar o dispositivo MeshCore?';

  @override
  String get meshcoreRebootDeviceTitle => 'Reiniciar Dispositivo';

  @override
  String get meshcoreRefresh => 'Atualizar';

  @override
  String get meshcoreRefreshButton => 'Atualizar';

  @override
  String get meshcoreRefreshContacts => 'Atualizar Contatos';

  @override
  String get meshcoreRefreshContactsSetting => 'Atualizar Contatos';

  @override
  String get meshcoreRefreshing => 'Atualizando...';

  @override
  String get meshcoreRefreshingContacts => 'Atualizando contatos...';

  @override
  String get meshcoreReloadContactsFromDevice =>
      'Recarregar contatos do dispositivo';

  @override
  String get meshcoreRemove => 'Remover';

  @override
  String get meshcoreRemoveContact => 'Remover Contato';

  @override
  String meshcoreRemoveContactMessage(String contactName) {
    return 'Tem certeza que deseja remover $contactName?';
  }

  @override
  String get meshcoreRemoveContactTitle => 'Remover Contato?';

  @override
  String get meshcoreRepeaterNode => 'Nó Repetidor';

  @override
  String get meshcoreRestartMeshCoreDevice =>
      'Reiniciar o dispositivo MeshCore';

  @override
  String get meshcoreReverseMeasurementDirection =>
      'Inverter direção da medição';

  @override
  String get meshcoreRoomNode => 'Nó de Sala';

  @override
  String get meshcoreSave => 'Salvar';

  @override
  String get meshcoreScanChannelQrSubtitle => 'Escaneie um código QR de canal';

  @override
  String get meshcoreScanChannelQrTitle => 'Escanear QR do Canal';

  @override
  String get meshcoreScanContactQrSubtitle =>
      'Escaneie o código QR de um contato';

  @override
  String get meshcoreScanContactQrTitle => 'Escanear QR de Contato';

  @override
  String get meshcoreScanQrCode => 'Escanear Código QR';

  @override
  String get meshcoreScanQrToJoinChannel =>
      'Escaneie este código QR para entrar no canal';

  @override
  String get meshcoreScanToAddMeSubtitle =>
      'Escaneie este código para me adicionar como contato';

  @override
  String get meshcoreSearchContactsHint => 'Buscar contatos...';

  @override
  String get meshcoreSelectContactToTrace =>
      'Selecione um contato para rastrear a rota pela mesh.';

  @override
  String get meshcoreSelfInfoNotAvailable => 'Info pessoal não disponível';

  @override
  String get meshcoreSendAdvertisement => 'Enviar anúncio';

  @override
  String get meshcoreSendAdvertisementTool => 'Enviar anúncio';

  @override
  String get meshcoreSendMessage => 'Enviar mensagem';

  @override
  String get meshcoreSendMessageToStart =>
      'Envie uma mensagem para iniciar a conversa';

  @override
  String get meshcoreSending => 'Enviando...';

  @override
  String get meshcoreSessionNotActive => 'Sessão MeshCore não ativa';

  @override
  String get meshcoreSetLocation => 'Definir localização';

  @override
  String get meshcoreSetNodePosition => 'Definir posição do nó';

  @override
  String get meshcoreSettingsTitle => 'Configurações';

  @override
  String get meshcoreSfCrLabel => 'SF/CR';

  @override
  String get meshcoreShare => 'Compartilhar';

  @override
  String get meshcoreShareChannel => 'Compartilhar canal';

  @override
  String get meshcoreShareContact => 'Compartilhar contato';

  @override
  String get meshcoreShareContactCodeInfo =>
      'Compartilhe seu código de contato para outros te enviarem mensagens';

  @override
  String get meshcoreShellAddChannelHint =>
      'Use o menu para criar ou entrar em um canal';

  @override
  String get meshcoreShellAddContactHint =>
      'Use o botão + para adicionar um contato';

  @override
  String get meshcoreShellAddContactSubtitle =>
      'Escaneie QR ou insira código de contato';

  @override
  String get meshcoreShellAdvertisementSent =>
      'Anúncio enviado - aguardando respostas';

  @override
  String get meshcoreShellAdvertisementSentListening =>
      'Anúncio enviado - aguardando respostas';

  @override
  String get meshcoreShellAppSettings => 'Configurações do app';

  @override
  String get meshcoreShellAppSettingsSubtitle =>
      'Notificações, tema, preferências';

  @override
  String meshcoreShellConnectedTo(String deviceName) {
    return 'Conectado a $deviceName';
  }

  @override
  String get meshcoreShellDefaultDeviceName => 'MeshCore';

  @override
  String get meshcoreShellDefaultDeviceNameFull => 'Dispositivo MeshCore';

  @override
  String get meshcoreShellDefaultInitials => 'MC';

  @override
  String get meshcoreShellDeviceInfoNotAvailable =>
      'Info do dispositivo não disponível';

  @override
  String get meshcoreShellDeviceTooltip => 'Dispositivo';

  @override
  String get meshcoreShellDisconnect => 'Desconectar';

  @override
  String get meshcoreShellDisconnectConfirmMessage =>
      'Tem certeza que deseja desconectar deste dispositivo MeshCore?';

  @override
  String meshcoreShellDisconnectedFrom(String deviceName) {
    return 'Desconectado de $deviceName';
  }

  @override
  String get meshcoreShellDisconnecting => 'Desconectando...';

  @override
  String get meshcoreShellDiscoverSubtitle =>
      'Envie anúncio para encontrar nós próximos';

  @override
  String get meshcoreShellDrawerAddChannel => 'Adicionar canal';

  @override
  String get meshcoreShellDrawerAddContact => 'Adicionar contato';

  @override
  String get meshcoreShellDrawerDisconnect => 'Desconectar';

  @override
  String get meshcoreShellDrawerDiscoverContacts => 'Descobrir contatos';

  @override
  String get meshcoreShellDrawerMyContactCode => 'Meu código de contato';

  @override
  String get meshcoreShellDrawerSectionHeader => 'MESHCORE';

  @override
  String get meshcoreShellDrawerSettings => 'Configurações';

  @override
  String get meshcoreShellInfoNodeId => 'ID do nó';

  @override
  String get meshcoreShellInfoNodeName => 'Nome do nó';

  @override
  String get meshcoreShellInfoProtocol => 'Protocolo';

  @override
  String get meshcoreShellInfoProtocolValue => 'MeshCore';

  @override
  String get meshcoreShellInfoPublicKey => 'Chave pública';

  @override
  String get meshcoreShellInfoStatus => 'Estado';

  @override
  String get meshcoreShellJoinChannel => 'Entrar no canal';

  @override
  String get meshcoreShellJoinChannelHint =>
      'Use o menu para entrar em um canal';

  @override
  String get meshcoreShellJoinChannelSubtitle =>
      'Escaneie QR ou insira código do canal';

  @override
  String get meshcoreShellMenuTooltip => 'Menu';

  @override
  String get meshcoreShellNavChannels => 'Canais';

  @override
  String get meshcoreShellNavContacts => 'Contatos';

  @override
  String get meshcoreShellNavMap => 'Mapa';

  @override
  String get meshcoreShellNavTools => 'Ferramentas';

  @override
  String get meshcoreShellNoSavedDevice =>
      'Nenhum dispositivo salvo para reconexão';

  @override
  String get meshcoreShellNotConnected => 'Não conectado';

  @override
  String get meshcoreShellReconnectButton => 'Reconectar';

  @override
  String meshcoreShellReconnectFailed(String error) {
    return 'Reconexão falhou: $error';
  }

  @override
  String meshcoreShellReconnecting(String deviceName) {
    return 'Reconectando a $deviceName...';
  }

  @override
  String get meshcoreShellScanToAddContact =>
      'Escaneie para adicionar como contato';

  @override
  String get meshcoreShellSectionConnection => 'Conexão';

  @override
  String get meshcoreShellSectionDeviceInfo => 'Informações do dispositivo';

  @override
  String get meshcoreShellSectionQuickActions => 'Ações rápidas';

  @override
  String get meshcoreShellShareContactInfo =>
      'Compartilhe seu código de contato para outros te enviarem mensagens';

  @override
  String get meshcoreShellShareContactSubtitle =>
      'Compartilhe suas info de contato';

  @override
  String get meshcoreShellStatusConnected => 'Conectado';

  @override
  String get meshcoreShellStatusConnecting => 'Conectando...';

  @override
  String get meshcoreShellStatusDisconnected => 'Desconectado';

  @override
  String get meshcoreShellStatusOffline => 'Offline';

  @override
  String get meshcoreShellStatusOnline => 'Online';

  @override
  String get meshcoreShellUnknown => 'Desconhecido';

  @override
  String get meshcoreShellUnnamedNode => 'Nó sem nome';

  @override
  String meshcoreSlotIndex(int index) {
    return 'Slot $index';
  }

  @override
  String get meshcoreSpreadingFactorLabel => 'Fator de Dispersão';

  @override
  String get meshcoreStatusLabel => 'Estado';

  @override
  String get meshcoreSwapAB => 'Trocar A ↔ B';

  @override
  String get meshcoreSyncTime => 'Sincronizar hora';

  @override
  String get meshcoreSyncing => 'Sincronizando...';

  @override
  String get meshcoreTapForPointA => 'Toque no nó ou mapa para o ponto A';

  @override
  String get meshcoreTapForPointB => 'Toque no nó ou mapa para o ponto B';

  @override
  String meshcoreTimeAgoDays(int count) {
    return '${count}d atrás';
  }

  @override
  String meshcoreTimeAgoHours(int count) {
    return '${count}h atrás';
  }

  @override
  String meshcoreTimeAgoMinutes(int count) {
    return '${count}m atrás';
  }

  @override
  String get meshcoreTimeSynchronized => 'Hora sincronizada';

  @override
  String get meshcoreToolsTitle => 'Ferramentas';

  @override
  String get meshcoreTracePacketRoutes => 'Rastrear rotas de pacotes pela mesh';

  @override
  String get meshcoreTracePath => 'Rastrear caminho';

  @override
  String meshcoreTracePathInitiated(String name) {
    return 'Rastreamento de caminho para $name iniciado';
  }

  @override
  String get meshcoreTracePathTitle => 'Rastrear caminho';

  @override
  String get meshcoreTxPowerLabel => 'Potência TX';

  @override
  String get meshcoreTxPowerStatusLabel => 'Potência TX';

  @override
  String get meshcoreTypeContactCode => 'Digite um código de contato';

  @override
  String get meshcoreTypeLabel => 'Tipo';

  @override
  String get meshcoreTypeMessageHint => 'Digite uma mensagem...';

  @override
  String get meshcoreUnknown => 'Desconhecido';

  @override
  String get meshcoreUpdateDeviceClock => 'Atualizar relógio do dispositivo';

  @override
  String meshcoreVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get meshcoreViewDeviceInfo =>
      'Ver informações detalhadas do dispositivo';

  @override
  String get meshcoreViewFrameLogs => 'Ver logs de frame MeshCore';

  @override
  String get meshcoreViewLoRaConfig => 'Ver configuração do rádio LoRa';

  @override
  String get messageContextMenuCopy => 'Copiar';

  @override
  String get messageContextMenuMessageCopied => 'Mensagem copiada';

  @override
  String get messageContextMenuMessageDetails => 'Detalhes da mensagem';

  @override
  String get messageContextMenuNoRecents => 'Nenhum recente';

  @override
  String get messageContextMenuReply => 'Responder';

  @override
  String get messageContextMenuSearchEmoji => 'Pesquisar emoji…';

  @override
  String get messageContextMenuStatusDelivered => 'Entregue ✔️';

  @override
  String messageContextMenuStatusFailed(String error) {
    return 'Falhou: $error';
  }

  @override
  String get messageContextMenuStatusSending => 'Enviando…';

  @override
  String get messageContextMenuStatusSent => 'Enviado';

  @override
  String get messageContextMenuTapbackFailed => 'Falha ao enviar tapback';

  @override
  String get messageContextMenuTapbackSent => 'Tapback enviado';

  @override
  String get messagesAddChannelNotConnected =>
      'Conecte-se a um dispositivo para adicionar canais';

  @override
  String get messagesChannelsTab => 'Canais';

  @override
  String get messagesContactsTab => 'Contatos';

  @override
  String get messagesContainerTitle => 'Mensagens';

  @override
  String get messagesScanChannelNotConnected =>
      'Conecte-se a um dispositivo para escanear canais';

  @override
  String get messagingAddChannel => 'Adicionar canal';

  @override
  String get messagingAdvancedResetNodeDatabase =>
      'Avançado: Redefinir banco de dados de nós';

  @override
  String get messagingChannelSettings => 'Configurações do canal';

  @override
  String get messagingChannelSubtitle => 'Canal';

  @override
  String get messagingClearSearch => 'Limpar pesquisa';

  @override
  String get messagingCloseSearch => 'Fechar pesquisa';

  @override
  String get messagingConfigureQuickResponses =>
      'Configure respostas rápidas nas Configurações';

  @override
  String get messagingContactsDiscoveredHint =>
      'Nós descobertos aparecerão aqui';

  @override
  String get messagingContactsTitle => 'Contatos';

  @override
  String messagingContactsTitleWithCount(int count) {
    return 'Contatos ($count)';
  }

  @override
  String get messagingDeleteMessageConfirmation =>
      'Tem certeza que deseja excluir esta mensagem? Ela será removida apenas localmente.';

  @override
  String get messagingDeleteMessageTitle => 'Excluir mensagem';

  @override
  String get messagingDirectMessageSubtitle => 'Mensagem direta';

  @override
  String messagingEncryptionKeyIssueSubtitle(String name) {
    return 'Mensagem direta para $name falhou';
  }

  @override
  String get messagingEncryptionKeyIssueTitle =>
      'Problema na chave de criptografia';

  @override
  String get messagingEncryptionKeyWarning =>
      'As chaves de criptografia podem estar dessincronizadas. Isso pode acontecer quando um nó foi redefinido ou removido do banco de dados da mesh.';

  @override
  String get messagingFailedToSend => 'Falha ao enviar';

  @override
  String get messagingFilterActive => 'Ativos';

  @override
  String get messagingFilterOnline => 'Online';

  @override
  String get messagingFilterAll => 'Todos';

  @override
  String get messagingFilterFavorites => 'Favoritos';

  @override
  String get messagingFilterMessaged => 'Com mensagens';

  @override
  String get messagingFilterUnread => 'Não lidas';

  @override
  String get messagingFindMessageHint => 'Encontrar uma mensagem';

  @override
  String get messagingHelp => 'Ajuda';

  @override
  String get messagingMessageDeleted => 'Mensagem excluída';

  @override
  String get messagingMessageHint => 'Mensagem';

  @override
  String get messagingSendTooltip => 'Enviar (Ctrl/Cmd+Enter)';

  @override
  String messagingComposerByteCounter(int used, int max) {
    return '$used/$max bytes';
  }

  @override
  String messagingComposerTooLong(int used, int max) {
    return 'Message is too long for the mesh ($used/$max bytes).';
  }

  @override
  String get messagingMessageQueuedOffline =>
      'Mensagem na fila - será enviada ao conectar';

  @override
  String messagingNoContactsMatchSearch(String query) {
    return 'Nenhum contato corresponde a \"$query\"';
  }

  @override
  String get messagingNoContactsYet => 'Nenhum contato ainda';

  @override
  String messagingNoFilteredContacts(String filter) {
    return 'Nenhum contato $filter';
  }

  @override
  String get messagingNoMessagesInChannel => 'Nenhuma mensagem neste canal';

  @override
  String get messagingNoMessagesMatchSearch =>
      'Nenhuma mensagem corresponde à pesquisa';

  @override
  String get messagingNoQuickResponsesConfigured =>
      'Nenhuma resposta rápida configurada.\nAdicione em Configurações → Respostas rápidas.';

  @override
  String get messagingOriginalMessage => 'Mensagem original';

  @override
  String get messagingQuickResponses => 'Respostas rápidas';

  @override
  String messagingReplyingTo(String name) {
    return 'Respondendo a $name';
  }

  @override
  String get messagingRequestUserInfo => 'Solicitar info do usuário';

  @override
  String messagingRequestUserInfoFailed(String error) {
    return 'Falha ao solicitar info: $error';
  }

  @override
  String messagingRequestUserInfoSuccess(String name) {
    return 'Info atualizadas solicitadas de $name';
  }

  @override
  String get messagingRetryMessage => 'Reenviar mensagem';

  @override
  String get messagingStatusAwaitingConfirmation => 'A aguardar confirmação';

  @override
  String get messagingStatusUnconfirmed => 'Não confirmado';

  @override
  String get messagingStatusRetrying => 'A retentar';

  @override
  String get messagingStatusConfirmed => 'Confirmado';

  @override
  String get messagingStatusSentToRadio => 'Enviado ao rádio';

  @override
  String get messagingResend => 'Reenviar';

  @override
  String get messagingAutoRetryEnable => 'Retentar a cada 60s até confirmação';

  @override
  String get messagingAutoRetryStop => 'Parar de retentar';

  @override
  String get messagingAutoRetryWarning =>
      'Pode aumentar o tempo de antena e consumo de bateria';

  @override
  String messagingRetryProgress(int count, int max) {
    return '$count/$max tentativas';
  }

  @override
  String get messagingScanQrCode => 'Escanear código QR';

  @override
  String get messagingSearchContactsHint => 'Pesquisar contatos';

  @override
  String messagingSearchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'messages',
      one: 'message',
    );
    return '$count $_temp0 found';
  }

  @override
  String get messagingSearchMessages => 'Pesquisar mensagens';

  @override
  String get messagingJumpToLatest => 'Jump to latest';

  @override
  String get messagingSectionActive => 'Online';

  @override
  String get messagingSectionFavorites => 'Favoritos';

  @override
  String get messagingSectionInactive => 'Offline';

  @override
  String get messagingSectionUnread => 'Não lidas';

  @override
  String get messagingSettings => 'Configurações';

  @override
  String get messagingSourceAutomation => 'Automação';

  @override
  String get messagingSourceNotification => 'Notificação';

  @override
  String get messagingSourceShortcut => 'Atalho';

  @override
  String get messagingSourceTapback => 'Tapback';

  @override
  String get messagingTechInfoDirectHop => 'Direct';

  @override
  String messagingTechInfoHops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hops',
      one: 'hop',
    );
    return '$count $_temp0';
  }

  @override
  String get messagingTechInfoMqtt => 'MQTT';

  @override
  String get messagingTechInfoRadio => 'Radio';

  @override
  String messagingTechInfoRssi(int value) {
    return 'RSSI $value dBm';
  }

  @override
  String messagingTechInfoSnr(String value) {
    return 'SNR $value dB';
  }

  @override
  String messagingTechInfoNodeId(String nodeHex) {
    return 'Node !$nodeHex';
  }

  @override
  String messagingTechInfoPacketId(int packetId) {
    return 'Packet #$packetId';
  }

  @override
  String get messagingTechInfoNoRadioData => 'No radio data';

  @override
  String get messagingTechInfoToggleTooltip => 'Radio details';

  @override
  String get messagingTechInfoExplainHopsTitle => 'Hop Count';

  @override
  String get messagingTechInfoExplainHopsBody =>
      'The number of times this message was relayed by other nodes before reaching you. \'Direct\' means no relay — the sender was in direct radio range.';

  @override
  String get messagingTechInfoExplainSnrTitle => 'Signal-to-Noise Ratio (SNR)';

  @override
  String get messagingTechInfoExplainSnrBody =>
      'Measures how clearly the radio signal was received compared to background noise. Higher is better. Typical range: -20 dB (very weak) to +15 dB (excellent).';

  @override
  String get messagingTechInfoExplainRssiTitle => 'Signal Strength (RSSI)';

  @override
  String get messagingTechInfoExplainRssiBody =>
      'Received Signal Strength Indicator — how strong the radio signal was when it arrived. Closer to 0 is stronger. Typical range: -120 dBm (very weak) to -40 dBm (very strong).';

  @override
  String get messagingTechInfoExplainTransportTitle => 'Transport';

  @override
  String get messagingTechInfoExplainTransportBody =>
      'How this message reached you. \'Radio\' means it travelled entirely over the mesh radio network. \'MQTT\' means it passed through an internet gateway at some point.';

  @override
  String get messagingTechInfoExplainNodeIdTitle => 'Sender Node ID';

  @override
  String get messagingTechInfoExplainNodeIdBody =>
      'The unique hardware identifier of the node that sent this message, shown in hexadecimal.';

  @override
  String get messagingTechInfoExplainPacketIdTitle => 'Packet ID';

  @override
  String get messagingTechInfoExplainPacketIdBody =>
      'The unique identifier for this radio packet, assigned by the sending node. Useful for debugging delivery issues.';

  @override
  String get messagingStartConversation => 'Iniciar a conversa';

  @override
  String get messagingUnknownNode => 'Nó desconhecido';

  @override
  String get timelineFilterLabel => 'Filter';

  @override
  String get timelineToday => 'Hoje';

  @override
  String get timelineWeek => 'Week';

  @override
  String get timelineMonth => 'Month';

  @override
  String get timelineYear => 'Year';

  @override
  String get timelinePriorityLow => 'Low';

  @override
  String get timelinePriorityMedium => 'Medium';

  @override
  String get timelinePriorityHigh => 'High';

  @override
  String get timelinePriorityDone => 'Done';

  @override
  String get timelineBreakTime => 'Break time';

  @override
  String timelineDuration(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String timelineDurationMinutesOnly(String minutes) {
    return '${minutes}m';
  }

  @override
  String timelineOverflowParticipants(int count) {
    return '+$count';
  }

  @override
  String get navigationActivity => 'Atividade';

  @override
  String get navigationAether => 'Aether';

  @override
  String get navigationAutomations => 'Automações';

  @override
  String get navigationDashboard => 'Painel';

  @override
  String get navigationDeviceLogs => 'Logs do dispositivo';

  @override
  String get navigationDeviceTooltip => 'Dispositivo';

  @override
  String get navigationFileTransfers => 'Transferências de arquivos';

  @override
  String get navigationFirmwareErrorTitle => 'Erro do dispositivo Meshtastic';

  @override
  String navigationFirmwareMessage(String message) {
    return 'Firmware: $message';
  }

  @override
  String get navigationFirmwareWarningTitle =>
      'Aviso do dispositivo Meshtastic';

  @override
  String navigationFlightActivated(String flightNumber, String route) {
    return '$flightNumber ($route) está agora em voo!';
  }

  @override
  String navigationFlightCompleted(String flightNumber, String route) {
    return '$flightNumber ($route) voo concluído';
  }

  @override
  String get navigationGuestName => 'Visitante';

  @override
  String get navigationHelpSupport => 'Ajuda e suporte';

  @override
  String get navigationIftttIntegration => 'Integração IFTTT';

  @override
  String get navigationTranslationPack => 'Translation Pack';

  @override
  String get navigationMap => 'Mapa';

  @override
  String get navigationMenuTooltip => 'Menu';

  @override
  String get navigationMesh3dView => 'Visualização 3D da mesh';

  @override
  String get navigationMeshHealth => 'Saúde da mesh';

  @override
  String get navigationMessages => 'Mensagens';

  @override
  String get navigationNodeDex => 'NodeDex';

  @override
  String get navigationNodes => 'Nós';

  @override
  String get navigationNotSignedIn => 'Não conectado';

  @override
  String get navigationOffline => 'Offline';

  @override
  String get navigationPresence => 'Presença';

  @override
  String get navigationReachability => 'Alcançabilidade';

  @override
  String get navigationRingtonePack => 'Pacote de toques';

  @override
  String get navigationRoutes => 'Rotas';

  @override
  String get navigationSectionAccount => 'CONTA';

  @override
  String get navigationSectionAdvanced => 'AVANÇADO';

  @override
  String get navigationSectionDiscover => 'DESCOBRIR';

  @override
  String get navigationSectionIdentity => 'IDENTIDADE';

  @override
  String get navigationSectionMesh => 'MESH';

  @override
  String get navigationSectionPremium => 'PREMIUM';

  @override
  String get navigationSectionSocial => 'SOCIAL';

  @override
  String get navigationSectionTools => 'FERRAMENTAS';

  @override
  String get navigationSignals => 'Sinais';

  @override
  String get navigationSocial => 'Social';

  @override
  String get navigationSyncError => 'Erro de sincronização';

  @override
  String get navigationSynced => 'Sincronizado';

  @override
  String get navigationSyncing => 'Sincronizando...';

  @override
  String get navigationTakGateway => 'Gateway TAK';

  @override
  String get navigationTakMap => 'Mapa TAK';

  @override
  String get navigationThemePack => 'Pacote de Tema';

  @override
  String get navigationTimeline => 'Linha do Tempo';

  @override
  String get navigationViewProfile => 'Ver Perfil';

  @override
  String get navigationWidgets => 'Widgets';

  @override
  String get navigationWorldMap => 'Mapa Mundial';

  @override
  String get nodeAnalyticsAddFavoriteTooltip => 'Adicionar aos favoritos';

  @override
  String get nodeAnalyticsAddedToFavorites => 'Adicionado aos favoritos';

  @override
  String get nodeAnalyticsAirTimeTx => 'Tempo de Antena TX';

  @override
  String nodeAnalyticsAltitude(String meters) {
    return '${meters}m';
  }

  @override
  String get nodeAnalyticsAltitudeRowLabel => 'Altitude';

  @override
  String get nodeAnalyticsAvgBattery => 'Bateria Média';

  @override
  String get nodeAnalyticsBadgeLive => 'AO VIVO';

  @override
  String get nodeAnalyticsBattery => 'Bateria';

  @override
  String get nodeAnalyticsChannelUtilization => 'Utilização do Canal';

  @override
  String get nodeAnalyticsCharging => 'Carregando';

  @override
  String get nodeAnalyticsClear => 'Limpar';

  @override
  String get nodeAnalyticsClearConfirm => 'Limpar';

  @override
  String get nodeAnalyticsClearHistoryMessage =>
      'Isso excluirá todos os dados históricos deste nó. Esta ação não pode ser desfeita.';

  @override
  String get nodeAnalyticsClearHistoryTitle => 'Limpar Histórico';

  @override
  String get nodeAnalyticsCsvShared => 'Dados CSV compartilhados';

  @override
  String get nodeAnalyticsDataUpdated => 'Dados do nó atualizados';

  @override
  String nodeAnalyticsDirectNeighbors(int count) {
    return 'Vizinhos Diretos ($count)';
  }

  @override
  String get nodeAnalyticsExport => 'Exportar';

  @override
  String get nodeAnalyticsExportCsv => 'CSV';

  @override
  String nodeAnalyticsExportCsvSubject(String name) {
    return 'Histórico do Nó $name (CSV)';
  }

  @override
  String get nodeAnalyticsExportHistoryTitle => 'Exportar Histórico';

  @override
  String get nodeAnalyticsExportJson => 'JSON';

  @override
  String nodeAnalyticsExportJsonSubject(String name) {
    return 'Histórico do Nó $name (JSON)';
  }

  @override
  String nodeAnalyticsExportRecordCount(int count) {
    return '$count registros';
  }

  @override
  String get nodeAnalyticsFirstSeen => 'Visto pela primeira vez';

  @override
  String get nodeAnalyticsHardware => 'Hardware';

  @override
  String get nodeAnalyticsHistoryCleared => 'Histórico limpo';

  @override
  String get nodeAnalyticsJsonShared => 'Dados JSON compartilhados';

  @override
  String get nodeAnalyticsLastUpdate => 'Última atualização';

  @override
  String get nodeAnalyticsLatitude => 'Latitude';

  @override
  String get nodeAnalyticsLiveWatchDisabled =>
      'Monitoramento ao vivo desativado';

  @override
  String get nodeAnalyticsLiveWatchEnabled =>
      'Monitoramento ao vivo ativado (atualização a cada 30s)';

  @override
  String get nodeAnalyticsLongName => 'Nome Longo';

  @override
  String get nodeAnalyticsLongitude => 'Longitude';

  @override
  String get nodeAnalyticsNoGatewayData => 'Nenhum dado de gateway disponível';

  @override
  String get nodeAnalyticsNoHistoryToExport =>
      'Nenhum dado histórico para exportar';

  @override
  String get nodeAnalyticsNoHistoryYet => 'Nenhum dado histórico ainda';

  @override
  String get nodeAnalyticsNoNeighborData =>
      'Nenhum dado de vizinhos disponível';

  @override
  String get nodeAnalyticsNodeIdCopied => 'ID do nó copiado';

  @override
  String get nodeAnalyticsNodeNotFound => 'Nó não encontrado na mesh';

  @override
  String get nodeAnalyticsRecords => 'Registros';

  @override
  String nodeAnalyticsRefreshFailed(String error) {
    return 'Falha ao atualizar: $error';
  }

  @override
  String get nodeAnalyticsRefreshNow => 'Atualizar Agora';

  @override
  String get nodeAnalyticsRefreshing => 'Atualizando...';

  @override
  String get nodeAnalyticsRemoveFavoriteTooltip => 'Remover dos favoritos';

  @override
  String get nodeAnalyticsRemovedFromFavorites => 'Removido dos favoritos';

  @override
  String get nodeAnalyticsRole => 'Função';

  @override
  String get nodeAnalyticsSectionDeviceInfo => 'Info do Dispositivo';

  @override
  String get nodeAnalyticsSectionDeviceMetrics => 'Métricas do Dispositivo';

  @override
  String get nodeAnalyticsSectionHistory => 'Histórico';

  @override
  String get nodeAnalyticsSectionNetwork => 'Rede';

  @override
  String get nodeAnalyticsSectionTrends => 'Tendências';

  @override
  String nodeAnalyticsSeenByGateways(int count) {
    return 'Visto por Gateways ($count)';
  }

  @override
  String get nodeAnalyticsShareDetailBatteryCharging => 'Bateria: Carregando';

  @override
  String nodeAnalyticsShareDetailBatteryLevel(String level) {
    return 'Bateria: $level%';
  }

  @override
  String nodeAnalyticsShareDetailGateways(String count) {
    return 'Gateways: $count';
  }

  @override
  String nodeAnalyticsShareDetailHardware(String hardware) {
    return 'Hardware: $hardware';
  }

  @override
  String nodeAnalyticsShareDetailHeader(String name) {
    return '🛰️ Nó Mesh: $name';
  }

  @override
  String nodeAnalyticsShareDetailId(String nodeId) {
    return 'ID: !$nodeId';
  }

  @override
  String nodeAnalyticsShareDetailLocation(String location) {
    return 'Localização: $location';
  }

  @override
  String nodeAnalyticsShareDetailNeighbors(String count) {
    return 'Vizinhos: $count';
  }

  @override
  String nodeAnalyticsShareDetailRole(String role) {
    return 'Função: $role';
  }

  @override
  String nodeAnalyticsShareDetailStatus(String status) {
    return 'Estado: $status';
  }

  @override
  String get nodeAnalyticsShareDetails => 'Compartilhar Detalhes';

  @override
  String get nodeAnalyticsShareDetailsSubtitle =>
      'Info técnicas completas como texto';

  @override
  String nodeAnalyticsShareFailed(String error) {
    return 'Falha ao compartilhar nó: $error';
  }

  @override
  String get nodeAnalyticsShareLink => 'Compartilhar Link';

  @override
  String get nodeAnalyticsShareLinkSubtitle =>
      'Prévia rica no iMessage, Slack, etc.';

  @override
  String get nodeAnalyticsShareNodeTitle => 'Compartilhar Nó';

  @override
  String nodeAnalyticsShareSubject(String name) {
    return 'Nó Mesh: $name';
  }

  @override
  String nodeAnalyticsShareText(String name, String url) {
    return 'Confira $name no SocialMesh!\n$url';
  }

  @override
  String get nodeAnalyticsShareTooltip => 'Compartilhar info do nó';

  @override
  String get nodeAnalyticsShortName => 'Nome Curto';

  @override
  String get nodeAnalyticsShowOnMap => 'Mostrar no Mapa';

  @override
  String get nodeAnalyticsSignIn => 'Entrar';

  @override
  String get nodeAnalyticsSignInToShare => 'Entre para compartilhar nós';

  @override
  String get nodeAnalyticsStopWatching => 'Parar monitoramento';

  @override
  String nodeAnalyticsTimeDaysAgo(int days) {
    return '${days}d atrás';
  }

  @override
  String nodeAnalyticsTimeHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String get nodeAnalyticsTimeJustNow => 'Agora';

  @override
  String nodeAnalyticsTimeMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String get nodeAnalyticsUnknown => 'Desconhecido';

  @override
  String get nodeAnalyticsUptime => 'Tempo ativo';

  @override
  String get nodeAnalyticsUptimeStat => 'Tempo ativo';

  @override
  String get nodeAnalyticsVisitAgain =>
      'Visite este nó novamente para criar o histórico';

  @override
  String get nodeAnalyticsVoltage => 'Voltagem';

  @override
  String get nodeAnalyticsWatchLive => 'Monitorar ao vivo';

  @override
  String get nodeComparisonCharging => 'Carregando';

  @override
  String get nodeComparisonNo => 'Não';

  @override
  String get nodeComparisonNoData => '--';

  @override
  String get nodeComparisonNodeIdCopied => 'ID do nó copiado';

  @override
  String get nodeComparisonRowAirTimeTx => 'Tempo de Antena TX';

  @override
  String get nodeComparisonRowBattery => 'Bateria';

  @override
  String get nodeComparisonRowChannelUtil => 'Util. Canal';

  @override
  String get nodeComparisonRowFirmware => 'Firmware';

  @override
  String get nodeComparisonRowGateways => 'Gateways';

  @override
  String get nodeComparisonRowHardware => 'Hardware';

  @override
  String get nodeComparisonRowHasLocation => 'Tem Localização';

  @override
  String get nodeComparisonRowNeighbors => 'Vizinhos';

  @override
  String get nodeComparisonRowRegion => 'Região';

  @override
  String get nodeComparisonRowRole => 'Função';

  @override
  String get nodeComparisonRowStatus => 'Estado';

  @override
  String get nodeComparisonRowUptime => 'Tempo ativo';

  @override
  String get nodeComparisonRowVoltage => 'Voltagem';

  @override
  String get nodeComparisonSectionDeviceInfo => 'Info do Dispositivo';

  @override
  String get nodeComparisonSectionMetrics => 'Métricas';

  @override
  String get nodeComparisonSectionNetwork => 'Rede';

  @override
  String get nodeComparisonSectionStatus => 'Estado';

  @override
  String get nodeComparisonTitle => 'Comparar Nós';

  @override
  String get nodeComparisonUnknown => 'Desconhecido';

  @override
  String get nodeComparisonVs => 'VS';

  @override
  String get nodeComparisonYes => 'Sim';

  @override
  String get nodeDetailAddToFavoritesTooltip => 'Adicionar aos favoritos';

  @override
  String nodeDetailAddedToFavorites(String name) {
    return '$name adicionado aos favoritos';
  }

  @override
  String get nodeDetailAppBarTitle => 'Detalhes do Nó';

  @override
  String get nodeDetailBatteryCharging => 'Carregando';

  @override
  String nodeDetailBatteryPercent(int level) {
    return '$level%';
  }

  @override
  String nodeDetailDistanceKilometers(String km) {
    return '$km km';
  }

  @override
  String nodeDetailDistanceMeters(String meters) {
    return '$meters m';
  }

  @override
  String get nodeDetailFavoriteBadge => 'Favorito';

  @override
  String nodeDetailFavoriteError(String error) {
    return 'Falha ao atualizar favorito: $error';
  }

  @override
  String nodeDetailFixedPositionError(String error) {
    return 'Falha ao definir posição fixa: $error';
  }

  @override
  String nodeDetailFixedPositionSet(String name) {
    return 'Posição fixa definida na localização de $name';
  }

  @override
  String get nodeDetailLabelAirUtilTx => 'Air Util TX';

  @override
  String get nodeDetailLabelAltitude => 'Altitude';

  @override
  String get nodeDetailLabelBadPackets => 'Pacotes Ruins';

  @override
  String get nodeDetailLabelBattery => 'Bateria';

  @override
  String get nodeDetailLabelCacheHits => 'Acertos em Cache';

  @override
  String get nodeDetailLabelChannelUtil => 'Util. Canal';

  @override
  String get nodeDetailLabelDistance => 'Distância';

  @override
  String get nodeDetailLabelEncryption => 'Criptografia';

  @override
  String get nodeDetailLabelFirmware => 'Firmware';

  @override
  String get nodeDetailLabelHardware => 'Hardware';

  @override
  String get nodeDetailLabelHopExhausted => 'Hops Esgotados';

  @override
  String get nodeDetailLabelHopsPreserved => 'Hops Preservados';

  @override
  String get nodeDetailLabelInspected => 'Inspecionados';

  @override
  String get nodeDetailLabelNoiseFloor => 'Piso de Ruído';

  @override
  String get nodeDetailLabelOnlineNodes => 'Nós Online';

  @override
  String get nodeDetailLabelPacketsRx => 'Pacotes RX';

  @override
  String get nodeDetailLabelPacketsTx => 'Pacotes TX';

  @override
  String get nodeDetailLabelPosition => 'Posição';

  @override
  String get nodeDetailLabelPositionDedup => 'Dedup Posição';

  @override
  String get nodeDetailLabelRateLimitDrops => 'Descartes Rate Limit';

  @override
  String get nodeDetailLabelRssi => 'RSSI';

  @override
  String get nodeDetailLabelSnr => 'SNR';

  @override
  String get nodeDetailLabelStatus => 'Estado';

  @override
  String get nodeDetailLabelTotalNodes => 'Nós Totais';

  @override
  String get nodeDetailLabelTxDropped => 'TX Descartados';

  @override
  String get nodeDetailLabelUnknownDrops => 'Descartes Desconhecidos';

  @override
  String get nodeDetailLabelUptime => 'Tempo ativo';

  @override
  String get nodeDetailLabelUserId => 'ID do Usuário';

  @override
  String get nodeDetailLabelVoltage => 'Voltagem';

  @override
  String nodeDetailLastHeardDaysAgo(int days) {
    return '${days}d atrás';
  }

  @override
  String nodeDetailLastHeardHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String get nodeDetailLastHeardJustNow => 'Agora';

  @override
  String nodeDetailLastHeardMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String get nodeDetailLastHeardNever => 'Nunca';

  @override
  String nodeDetailLastHeardTimestamp(String timestamp) {
    return 'Último contato $timestamp';
  }

  @override
  String get nodeDetailMenuAdminSettings => 'Configurações Admin';

  @override
  String get nodeDetailMenuAdminSubtitle => 'Configure este nó remotamente';

  @override
  String get nodeDetailMenuExchangePositions => 'Trocar Posições';

  @override
  String get nodeDetailMenuQrCode => 'Código QR';

  @override
  String get nodeDetailMenuRemoveNode => 'Remover Nó';

  @override
  String get nodeDetailMenuRequestUserInfo => 'Solicitar Info do Usuário';

  @override
  String get nodeDetailMenuSetFixedPosition => 'Definir Posição Fixa';

  @override
  String get nodeDetailMenuShowOnMap => 'Mostrar no Mapa';

  @override
  String get nodeDetailMenuTracerouteHistory => 'Histórico de Traceroute';

  @override
  String get nodeDetailMenuViewInNodeDex => 'View in NodeDex';

  @override
  String get nodeDetailMessageButton => 'Mensagem';

  @override
  String nodeDetailMuteError(String error) {
    return 'Falha ao atualizar silenciamento: $error';
  }

  @override
  String get nodeDetailMuteNotConnected =>
      'Não é possível alterar silenciamento: Dispositivo não conectado';

  @override
  String get nodeDetailMuteTooltip => 'Silenciar nó';

  @override
  String nodeDetailMuted(String name) {
    return '$name silenciado';
  }

  @override
  String get nodeDetailMutedBadge => 'Silenciado';

  @override
  String get nodeDetailNoPkiBadge => 'Sem PKI';

  @override
  String get nodeDetailNoPositionData => 'O nó não tem dados de posição';

  @override
  String get nodeDetailPkiBadge => 'PKI';

  @override
  String nodeDetailPositionError(String error) {
    return 'Falha ao solicitar posição: $error';
  }

  @override
  String nodeDetailPositionRequested(String name) {
    return 'Posição solicitada de $name';
  }

  @override
  String nodeDetailQrInfoText(String nodeId) {
    return 'ID do Nó: $nodeId';
  }

  @override
  String get nodeDetailQrSubtitle => 'Escaneie para adicionar este nó';

  @override
  String get nodeDetailRebootButton => 'Reiniciar';

  @override
  String get nodeDetailRebootConfirm => 'Reiniciar';

  @override
  String nodeDetailRebootError(String error) {
    return 'Falha ao reiniciar: $error';
  }

  @override
  String get nodeDetailRebootMessage =>
      'Isso reiniciará seu dispositivo Meshtastic. O app reconectará automaticamente após a reinicialização.';

  @override
  String get nodeDetailRebootNotConnected =>
      'Não é possível reiniciar: dispositivo não conectado';

  @override
  String get nodeDetailRebootTitle => 'Reiniciar dispositivo';

  @override
  String get nodeDetailRebootingSnackbar => 'Reiniciando dispositivo...';

  @override
  String get nodeDetailRemoveConfirm => 'Remover';

  @override
  String nodeDetailRemoveError(String error) {
    return 'Falha ao remover nó: $error';
  }

  @override
  String get nodeDetailRemoveFromFavoritesTooltip => 'Remover dos favoritos';

  @override
  String nodeDetailRemoveMessage(String name) {
    return 'Remover $name do banco de dados de nós? O nó será removido do seu dispositivo local.';
  }

  @override
  String get nodeDetailRemoveTitle => 'Remover nó';

  @override
  String nodeDetailRemovedFromFavorites(String name) {
    return '$name removido dos favoritos';
  }

  @override
  String nodeDetailRemovedSnackbar(String name) {
    return '$name removido';
  }

  @override
  String get nodeDetailSectionDeviceMetrics => 'Métricas do dispositivo';

  @override
  String get nodeDetailSectionIdentity => 'Identidade';

  @override
  String get nodeDetailSectionNetwork => 'Rede';

  @override
  String get nodeDetailSectionRadio => 'Rádio';

  @override
  String get nodeDetailSectionTraffic => 'Gerenciamento de tráfego';

  @override
  String get nodeDetailShutdownButton => 'Desligar';

  @override
  String get nodeDetailShutdownConfirm => 'Desligar';

  @override
  String nodeDetailShutdownError(String error) {
    return 'Falha ao desligar: $error';
  }

  @override
  String get nodeDetailShutdownMessage =>
      'Isso desligará seu dispositivo Meshtastic. Será necessário ligá-lo fisicamente para reconectar.';

  @override
  String get nodeDetailShutdownNotConnected =>
      'Não é possível desligar: dispositivo não conectado';

  @override
  String get nodeDetailShutdownTitle => 'Desligar dispositivo';

  @override
  String get nodeDetailShuttingDownSnackbar => 'Desligando dispositivo...';

  @override
  String get nodeDetailSigilCardTooltip => 'Card Sigil';

  @override
  String get nodeDetailSignalExcellent => 'Excelente';

  @override
  String get nodeDetailSignalFair => 'Razoável';

  @override
  String get nodeDetailSignalGood => 'Bom';

  @override
  String get nodeDetailSignalUnknown => 'Desconhecido';

  @override
  String get nodeDetailSignalVeryWeak => 'Muito fraco';

  @override
  String get nodeDetailSignalWeak => 'Fraco';

  @override
  String nodeDetailTracerouteCooldownTooltip(int seconds) {
    return 'Cooldown do traceroute: ${seconds}s';
  }

  @override
  String nodeDetailTracerouteError(String error) {
    return 'Falha ao enviar traceroute: $error';
  }

  @override
  String get nodeDetailTracerouteNotConnected =>
      'Não é possível enviar traceroute: dispositivo não conectado';

  @override
  String nodeDetailTracerouteSent(String name) {
    return 'Traceroute enviado para $name — verifique o histórico de traceroute para resultados';
  }

  @override
  String get nodeDetailTracerouteTooltip => 'Traceroute';

  @override
  String get nodeDetailTracerouteComplete => 'Traceroute concluído';

  @override
  String nodeDetailTracerouteSummaryRfDirect(String snr) {
    return 'RF • direto • SNR $snr dB';
  }

  @override
  String nodeDetailTracerouteSummaryRf(int hops, String snr) {
    return 'RF • $hops saltos • SNR $snr dB';
  }

  @override
  String nodeDetailTracerouteSummaryMqttDirect(String snr) {
    return 'MQTT • direto • SNR $snr dB';
  }

  @override
  String nodeDetailTracerouteSummaryMqtt(int hops, String snr) {
    return 'MQTT • $hops saltos • SNR $snr dB';
  }

  @override
  String get nodeDetailTracerouteSummaryDirectNoSnr => 'Ligação direta';

  @override
  String nodeDetailTracerouteSummaryHopsOnly(int hops) {
    return '$hops saltos';
  }

  @override
  String get nodeDetailTracerouteViewDetails => 'Ver detalhes';

  @override
  String get nodeDetailUnmuteTooltip => 'Reativar som do nó';

  @override
  String nodeDetailUnmuted(String name) {
    return '$name reativado';
  }

  @override
  String nodeDetailUserInfoError(String error) {
    return 'Falha ao solicitar info do usuário: $error';
  }

  @override
  String nodeDetailUserInfoRequested(String name) {
    return 'Info do usuário solicitada de $name';
  }

  @override
  String nodeDetailValueAltitude(int altitude) {
    return '$altitude m';
  }

  @override
  String get nodeDetailValueNoPublicKey => 'Sem chave pública';

  @override
  String nodeDetailValueNoiseFloor(int noiseFloor) {
    return '$noiseFloor dBm';
  }

  @override
  String nodeDetailValuePercent(String value) {
    return '$value%';
  }

  @override
  String get nodeDetailValuePkiEnabled => 'PKI habilitado';

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
    return '$voltage V';
  }

  @override
  String get nodeDetailYouBadge => 'VOCÊ';

  @override
  String nodeHistoryDataPointCount(int current, int required) {
    return '$current/$required pontos de dados';
  }

  @override
  String get nodeHistoryMetricBattery => 'Bateria';

  @override
  String get nodeHistoryMetricChannelUtil => 'Util. do canal';

  @override
  String get nodeHistoryMetricConnectivity => 'Conectividade';

  @override
  String get nodeHistoryNeedMoreData =>
      'Mais dados necessários para os gráficos';

  @override
  String nodeHistoryNoMetricData(String metric) {
    return 'Sem dados de $metric';
  }

  @override
  String get nodeIntelligenceActivityActive => 'Ativo';

  @override
  String get nodeIntelligenceActivityCold => 'Frio';

  @override
  String get nodeIntelligenceActivityHot => 'Quente';

  @override
  String get nodeIntelligenceActivityQuiet => 'Silencioso';

  @override
  String get nodeIntelligenceChannelUtil => 'Utilização do canal';

  @override
  String get nodeIntelligenceConnectivity => 'Conectividade';

  @override
  String get nodeIntelligenceDerivedBadge => 'DERIVADO';

  @override
  String nodeIntelligenceGatewayCount(int count) {
    return '$count gateways';
  }

  @override
  String get nodeIntelligenceHealth => 'Saúde';

  @override
  String get nodeIntelligenceMobilityElevated => 'Elevado';

  @override
  String get nodeIntelligenceMobilityInfra => 'Infraestrutura';

  @override
  String get nodeIntelligenceMobilityMobile => 'Móvel';

  @override
  String get nodeIntelligenceMobilityStationary => 'Estacionário';

  @override
  String get nodeIntelligenceMobilityTracker => 'Tracker';

  @override
  String nodeIntelligenceNeighborCount(int count) {
    return '$count vizinhos';
  }

  @override
  String get nodeIntelligenceTapHint => 'Toque para análise detalhada';

  @override
  String get nodeIntelligenceTitle => 'Insights da mesh';

  @override
  String get nodeIntelligenceUnknown => 'Desconhecido';

  @override
  String nodedexActiveDaysOf14(int count) {
    return '$count/14 dias';
  }

  @override
  String get nodedexActiveNow => 'ativo agora';

  @override
  String get nodedexActivityTimelineTitle => 'Linha do tempo de atividade';

  @override
  String get nodedexAddToAppleWallet => 'Adicionar ao Apple Wallet';

  @override
  String get nodedexAdditionalTraits => 'Características adicionais';

  @override
  String nodedexAgeDiscoveredDaysAgo(int days) {
    return 'descoberto há ${days}d';
  }

  @override
  String nodedexAgeDiscoveredMonthsAgo(int months) {
    return 'descoberto há ${months}m';
  }

  @override
  String nodedexAgeDiscoveredWeeksAgo(int weeks) {
    return 'descoberto há ${weeks}s';
  }

  @override
  String nodedexAgeDiscoveredYearsAgo(int years) {
    return 'descoberto há ${years}a';
  }

  @override
  String get nodedexAgeDiscoveredYesterday => 'descoberto ontem';

  @override
  String get nodedexAgeNewToday => 'novo hoje';

  @override
  String get nodedexAirUtilTxLabel => 'Air Util TX';

  @override
  String get nodedexBatteryLabel => 'Bateria';

  @override
  String get nodedexBestRssi => 'Melhor RSSI';

  @override
  String get nodedexBestSnr => 'Melhor SNR';

  @override
  String get nodedexBestSnrStatLabel => 'Melhor SNR';

  @override
  String nodedexBusiestDay(String day) {
    return '$day mais ativo';
  }

  @override
  String get nodedexCardBrandSocialmesh => 'SOCIALMESH';

  @override
  String get nodedexCardDeviceFirmware => 'FIRMWARE';

  @override
  String get nodedexCardDeviceHardware => 'HARDWARE';

  @override
  String get nodedexCardDeviceRole => 'FUNÇÃO';

  @override
  String get nodedexCardRarity100plus => '100+ encontros';

  @override
  String get nodedexCardRarity20to49 => '20 - 49 encontros';

  @override
  String get nodedexCardRarity50to99 => '50 - 99 encontros';

  @override
  String get nodedexCardRarity5to19 => '5 - 19 encontros';

  @override
  String get nodedexCardRarityEpic => 'ÉPICO';

  @override
  String get nodedexCardRarityInfoDescription =>
      'A raridade de um card reflete a frequência com que você encontrou este nó na mesh. Quanto mais cruzam caminhos, mais raro o card se torna.';

  @override
  String get nodedexCardRarityInfoTitle => 'Raridade do card';

  @override
  String get nodedexCardRarityLegendary => 'LENDÁRIO';

  @override
  String get nodedexCardRarityRare => 'RARO';

  @override
  String get nodedexCardRarityStandard => 'PADRÃO';

  @override
  String get nodedexCardRarityUncommon => 'INCOMUM';

  @override
  String get nodedexCardRarityUnder5 => 'Menos de 5 encontros';

  @override
  String get nodedexChannelUtilLabel => 'Util. do canal';

  @override
  String get nodedexClassificationChange => 'Alterar';

  @override
  String get nodedexClassificationClassify => 'Classificar';

  @override
  String get nodedexClassificationLabel => 'CLASSIFICAÇÃO';

  @override
  String get nodedexClassificationTitle => 'Classificação';

  @override
  String get nodedexClassifyNodeDescription =>
      'Atribua uma classificação pessoal a este nó. Visível apenas para você.';

  @override
  String get nodedexClassifyNodeTitle => 'Classificar nó';

  @override
  String get nodedexClearFilter => 'Limpar';

  @override
  String get nodedexCloseGallerySemanticLabel => 'Fechar galeria';

  @override
  String get nodedexCoSeenCompactLabel => 'Co-vistos';

  @override
  String get nodedexCoSeenDescription =>
      'Nós vistos frequentemente na mesma sessão';

  @override
  String get nodedexCoSeenLinksTitle => 'Links co-vistos';

  @override
  String get nodedexCoSeenRelationshipDetails =>
      'Detalhes da relação co-vistos';

  @override
  String nodedexCollectedCount(int count) {
    return '$count coletados';
  }

  @override
  String get nodedexConfidenceLabel => 'Confiança';

  @override
  String nodedexConfidenceTooltip(int percentage) {
    return 'Confiança: $percentage%';
  }

  @override
  String get nodedexConstellationCloseSearch => 'Fechar busca';

  @override
  String get nodedexConstellationEmptySubtitle =>
      'Descubra mais nós para ver como se conectam.\nNós vistos juntos formam links de constelação.';

  @override
  String get nodedexConstellationEmptyTitle => 'Nenhuma constelação';

  @override
  String nodedexConstellationLinkCount(int count) {
    return '$count ligações';
  }

  @override
  String get nodedexConstellationLinkTitle => 'Link de constelação';

  @override
  String nodedexConstellationNodeCount(int count) {
    return '$count nós';
  }

  @override
  String get nodedexConstellationProfile => 'Perfil';

  @override
  String get nodedexConstellationSearchHint => 'Buscar por nome ou ID do nó…';

  @override
  String get nodedexConstellationSearchNodes => 'Buscar nós';

  @override
  String get nodedexConstellationTitle => 'Constelação';

  @override
  String get nodedexDayFri => 'Sex';

  @override
  String get nodedexDayFriday => 'Sexta-feira';

  @override
  String get nodedexDayMon => 'Seg';

  @override
  String get nodedexDayMonday => 'Segunda-feira';

  @override
  String get nodedexDaySat => 'Sáb';

  @override
  String get nodedexDaySaturday => 'Sábado';

  @override
  String get nodedexDaySun => 'Dom';

  @override
  String get nodedexDaySunday => 'Domingo';

  @override
  String get nodedexDayThu => 'Qui';

  @override
  String get nodedexDayThursday => 'Quinta-feira';

  @override
  String get nodedexDayTue => 'Ter';

  @override
  String get nodedexDayTuesday => 'Terça-feira';

  @override
  String get nodedexDayWed => 'Qua';

  @override
  String get nodedexDayWednesday => 'Quarta-feira';

  @override
  String get nodedexDaysCompactLabel => 'Dias';

  @override
  String get nodedexDensityAll => 'Todos';

  @override
  String get nodedexDensityDense => 'Denso';

  @override
  String get nodedexDensityNormal => 'Normal';

  @override
  String get nodedexDensitySparse => 'Esparso';

  @override
  String get nodedexDensityStars => 'Estrelas';

  @override
  String get nodedexDetailNotFoundSubtitle =>
      'Este nó ainda não foi descoberto.';

  @override
  String get nodedexDetailNotFoundTitle => 'Nó não encontrado no NodeDex';

  @override
  String get nodedexDeviceTitle => 'Dispositivo';

  @override
  String get nodedexMrrpServicesTitle => 'Serviços MRRP';

  @override
  String get nodedexDiscoveryTitle => 'Descoberta';

  @override
  String nodedexDistanceKilometers(String distance) {
    return '$distance km';
  }

  @override
  String nodedexDistanceMeters(String distance) {
    return '$distance m';
  }

  @override
  String get nodedexDistanceUnknown => 'alcance desconhecido';

  @override
  String nodedexDurationDays(int days) {
    return '$days d';
  }

  @override
  String nodedexDurationHours(int hours) {
    return '$hours h';
  }

  @override
  String nodedexDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String nodedexDurationMonths(int months) {
    return '$months meses';
  }

  @override
  String nodedexDurationMonthsDays(int months, int days) {
    return '$months meses $days d';
  }

  @override
  String nodedexDurationYears(int years) {
    return '$years anos';
  }

  @override
  String nodedexDurationYearsMonths(int years, int months) {
    return '$years anos $months meses';
  }

  @override
  String get nodedexEdgeDensityAll => 'Todos';

  @override
  String get nodedexEdgeDensityDense => 'Denso';

  @override
  String get nodedexEdgeDensityNormal => 'Normal';

  @override
  String get nodedexEdgeDensitySparse => 'Esparso';

  @override
  String nodedexEdgeDensityTooltip(String label) {
    return 'Densidade de arestas: $label';
  }

  @override
  String get nodedexEmptyAlbumDescription =>
      'Conecte-se a um dispositivo mesh e descubra nós\npara começar sua coleção';

  @override
  String get nodedexEmptyAlbumHintMove => 'Movimente-se';

  @override
  String get nodedexEmptyAlbumHintScan => 'Buscar dispositivos';

  @override
  String get nodedexEmptyAlbumTitle => 'Nenhum card ainda';

  @override
  String get nodedexEmptyAllSubtitle =>
      'Conecte-se a um dispositivo Meshtastic e os nós aparecerão aqui conforme forem descobertos na mesh.';

  @override
  String get nodedexEmptyAllTitle => 'Nenhum nó descoberto';

  @override
  String get nodedexEmptyBeaconsSubtitle =>
      'Beacons são nós com atividade muito alta e encontros frequentes. Levam tempo para serem classificados.';

  @override
  String get nodedexEmptyBeaconsTitle => 'Nenhum beacon encontrado';

  @override
  String get nodedexEmptyContactSubtitle =>
      'Nós classificados como Contato aparecerão aqui. Mantenha pressionado em um nó para atribuir esta tag.';

  @override
  String get nodedexEmptyContactTitle => 'Nenhum contato';

  @override
  String get nodedexEmptyFrequentPeerSubtitle =>
      'Nós classificados como Peer frequente aparecerão aqui. Mantenha pressionado em um nó para atribuir esta tag.';

  @override
  String get nodedexEmptyFrequentPeerTitle => 'Nenhum peer frequente';

  @override
  String get nodedexEmptyGalleryDescription =>
      'Descubra nós para preencher sua coleção';

  @override
  String get nodedexEmptyGalleryTitle => 'Nenhum card para exibir';

  @override
  String get nodedexEmptyGhostsSubtitle =>
      'Fantasmas são nós que aparecem raramente em relação ao tempo em que são conhecidos.';

  @override
  String get nodedexEmptyGhostsTitle => 'Nenhum fantasma encontrado';

  @override
  String get nodedexEmptyKnownRelaySubtitle =>
      'Nós classificados como Relay conhecido aparecerão aqui. Mantenha pressionado em um nó para atribuir esta tag.';

  @override
  String get nodedexEmptyKnownRelayTitle => 'Nenhum relay conhecido';

  @override
  String get nodedexEmptyRecentSubtitle =>
      'Nós descobertos nas últimas 24 horas aparecerão aqui.';

  @override
  String get nodedexEmptyRecentTitle => 'Nenhuma descoberta recente';

  @override
  String get nodedexEmptyRelaysSubtitle =>
      'Relays são nós com funções de roteador e encaminhamento de tráfego ativo.';

  @override
  String get nodedexEmptyRelaysTitle => 'Nenhum relay encontrado';

  @override
  String get nodedexEmptySentinelsSubtitle =>
      'Sentinelas são nós de longa duração, posição fixa e presença confiável.';

  @override
  String get nodedexEmptySentinelsTitle => 'Nenhuma sentinela encontrada';

  @override
  String get nodedexEmptyTaggedSubtitle =>
      'Mantenha pressionado em um nó na lista para atribuir uma tag social como Contato, Nó confiável ou Relay conhecido.';

  @override
  String get nodedexEmptyTaggedTitle => 'Nenhum nó com tag';

  @override
  String get nodedexEmptyTagline1 =>
      'Nenhum nó descoberto.\nConecte-se a um dispositivo mesh para começar seu diário de campo.';

  @override
  String get nodedexEmptyTagline2 =>
      'NodeDex cataloga cada nó que você encontra.\nCada um recebe uma identidade procedural única.';

  @override
  String get nodedexEmptyTagline3 =>
      'Descubra andarilhos, sentinelas e fantasmas.\nTraços de personalidade emergem dos padrões de comportamento.';

  @override
  String get nodedexEmptyTagline4 =>
      'Marque nós como contatos ou relays confiáveis.\nConstrua sua comunidade mesh ao longo do tempo.';

  @override
  String get nodedexEmptyTitleKeyword => 'NodeDex';

  @override
  String get nodedexEmptyTitlePrefix => 'Seu ';

  @override
  String get nodedexEmptyTitleSuffix => ' está vazio';

  @override
  String get nodedexEmptyTrustedNodeSubtitle =>
      'Nós classificados como Nó Confiável aparecerão aqui. Toque e segure um nó para atribuir esta tag.';

  @override
  String get nodedexEmptyTrustedNodeTitle => 'Nenhum nó confiável';

  @override
  String get nodedexEmptyWanderersSubtitle =>
      'Andarilhos são nós vistos em múltiplas localizações. Surgem ao longo do tempo conforme os dados de posição se acumulam.';

  @override
  String get nodedexEmptyWanderersTitle => 'Nenhum andarilho encontrado';

  @override
  String get nodedexEncounterActivityTitle => 'Atividade de encontros';

  @override
  String nodedexEncounterCountLabel(int count) {
    return '$count encontros';
  }

  @override
  String get nodedexEncounterLogLabel => 'REGISTRO DE ENCONTROS';

  @override
  String nodedexEncountersCount(int count) {
    return '$count encontros';
  }

  @override
  String get nodedexEncountersLabel => 'Encontros';

  @override
  String get nodedexEncountersStatLabel => 'Encontros';

  @override
  String get nodedexEvidenceActiveLastHour => 'Ativo na última hora';

  @override
  String nodedexEvidenceAirtimeTx(String percent) {
    return 'Tempo de Antena TX $percent%';
  }

  @override
  String nodedexEvidenceChannelUtilization(String percent) {
    return 'Utilização do canal $percent%';
  }

  @override
  String nodedexEvidenceCoSeenWith(int count) {
    return 'Co-visto com $count nós';
  }

  @override
  String nodedexEvidenceDistinctPositions(int count) {
    return 'Observado em $count posições distintas';
  }

  @override
  String nodedexEvidenceEncounterRate(String rate) {
    return '$rate encontros/dia';
  }

  @override
  String nodedexEvidenceEncounterRateLow(String rate) {
    return 'Taxa de encontros $rate/dia';
  }

  @override
  String nodedexEvidenceEncountersReliable(int count) {
    return '$count encontros (confiáveis)';
  }

  @override
  String nodedexEvidenceFewEncountersOverDays(int encounters, int days) {
    return 'Apenas $encounters encontros em $days dias';
  }

  @override
  String get nodedexEvidenceFixedLocation => 'Localização fixa';

  @override
  String get nodedexEvidenceFixedPosition => 'Posição fixa (localização única)';

  @override
  String get nodedexEvidenceHighEncounterCount =>
      'Alto número de encontros (20+)';

  @override
  String get nodedexEvidenceInsufficientData =>
      'Dados insuficientes para classificação';

  @override
  String nodedexEvidenceIrregularTiming(String cv) {
    return 'Tempo irregular (CV $cv)';
  }

  @override
  String nodedexEvidenceKnownForDays(int days) {
    return 'Conhecido há $days dias';
  }

  @override
  String nodedexEvidenceLastSeenDaysAgo(int days) {
    return 'Visto há ${days}d';
  }

  @override
  String nodedexEvidenceMaxRange(String km) {
    return 'Alcance máx ${km}km';
  }

  @override
  String nodedexEvidenceMessagesExchanged(int count) {
    return '$count mensagens trocadas';
  }

  @override
  String nodedexEvidenceMessagesPerEncounter(String ratio) {
    return '$ratio mensagens por encontro';
  }

  @override
  String get nodedexEvidenceMobileWithMessaging => 'Móvel com mensagens ativas';

  @override
  String nodedexEvidenceModerateEncounterRate(String rate) {
    return 'Taxa de encontros moderada ($rate/dia)';
  }

  @override
  String nodedexEvidencePersistentPresence(int days) {
    return 'Presença persistente ($days dias)';
  }

  @override
  String nodedexEvidencePositionsObserved(int count) {
    return '$count posições observadas';
  }

  @override
  String nodedexEvidenceRoleIs(String role) {
    return 'Função: $role';
  }

  @override
  String nodedexEvidenceSeenAcrossRegions(int count) {
    return 'Visto em $count regiões';
  }

  @override
  String nodedexEvidenceSomewhatIrregularTiming(String cv) {
    return 'Tempo parcialmente irregular (CV $cv)';
  }

  @override
  String nodedexEvidenceTotalEncounters(int count) {
    return '$count encontros totais';
  }

  @override
  String nodedexEvidenceUptime(int days) {
    return 'Tempo Ativo ${days}d';
  }

  @override
  String nodedexExportFailed(String error) {
    return 'Exportação falhou: $error';
  }

  @override
  String get nodedexExportNothingToExport =>
      'Nada para exportar — o NodeDex está vazio';

  @override
  String get nodedexExportShareSubject => 'Exportação NodeDex Socialmesh';

  @override
  String nodedexFieldNoteAnchor0(int coSeen) {
    return 'Nó hub. Co-visto com $coSeen outros nós.';
  }

  @override
  String get nodedexFieldNoteAnchor1 =>
      'Centro social da mesh local. Muitas conexões.';

  @override
  String nodedexFieldNoteAnchor2(int coSeen) {
    return 'Hub persistente. $coSeen nós observados nas proximidades.';
  }

  @override
  String get nodedexFieldNoteAnchor3 =>
      'Ponto de ancoragem para nós próximos. Fixo e bem conectado.';

  @override
  String get nodedexFieldNoteAnchor4 =>
      'Central na topologia local. Alta densidade de co-visão.';

  @override
  String get nodedexFieldNoteAnchor5 =>
      'Centro gravitacional. Outros nós se agrupam ao redor deste.';

  @override
  String nodedexFieldNoteAnchor6(int coSeen) {
    return 'Âncora de infraestrutura. $coSeen pares conectados.';
  }

  @override
  String get nodedexFieldNoteAnchor7 =>
      'Nexo mesh. Presença estável com ampla conectividade.';

  @override
  String nodedexFieldNoteBeacon0(String rate) {
    return 'Sinal constante. $rate avistamentos por dia.';
  }

  @override
  String get nodedexFieldNoteBeacon1 =>
      'Presença persistente na mesh. Sempre transmitindo.';

  @override
  String nodedexFieldNoteBeacon2(String lastSeen) {
    return 'Confiável e consistente. Último contato $lastSeen.';
  }

  @override
  String nodedexFieldNoteBeacon3(int encounters) {
    return 'Alta disponibilidade. $encounters encontros registrados.';
  }

  @override
  String get nodedexFieldNoteBeacon4 =>
      'Operação contínua confirmada. Sinal raramente cai.';

  @override
  String get nodedexFieldNoteBeacon5 =>
      'Presença sempre ativa. Ponto de referência confiável.';

  @override
  String nodedexFieldNoteBeacon6(String rate) {
    return 'Transmissão consistente. $rate observações diárias.';
  }

  @override
  String get nodedexFieldNoteBeacon7 =>
      'Ritmo fixo. Tempo previsível entre sessões.';

  @override
  String nodedexFieldNoteCourier0(int messages, int encounters) {
    return 'Alto volume de mensagens. $messages mensagens em $encounters encontros.';
  }

  @override
  String get nodedexFieldNoteCourier1 =>
      'Transportador de dados. Taxa mensagens/encontros elevada.';

  @override
  String get nodedexFieldNoteCourier2 =>
      'Ativo na troca de mensagens. Comportamento de correio provável.';

  @override
  String nodedexFieldNoteCourier3(int messages) {
    return 'Transporta dados entre segmentos mesh. $messages mensagens registradas.';
  }

  @override
  String get nodedexFieldNoteCourier4 =>
      'Densidade de mensagens sugere transporte de dados deliberado.';

  @override
  String nodedexFieldNoteCourier5(int messages) {
    return 'Nó de alta comunicação. $messages trocas registradas.';
  }

  @override
  String get nodedexFieldNoteCourier6 =>
      'Mensageiro frequente. Move dados pela rede.';

  @override
  String get nodedexFieldNoteCourier7 =>
      'Padrão de entrega observado. Mensagens superam encontros.';

  @override
  String get nodedexFieldNoteDrifter0 =>
      'Tempo imprevisível. Aparece e desaparece sem padrão.';

  @override
  String get nodedexFieldNoteDrifter1 =>
      'Intervalos irregulares entre avistamentos.';

  @override
  String get nodedexFieldNoteDrifter2 =>
      'Sem programação consistente. Comportamento errático confirmado.';

  @override
  String get nodedexFieldNoteDrifter3 =>
      'Aparece esporadicamente mas não raramente. Tempo errático.';

  @override
  String get nodedexFieldNoteDrifter4 =>
      'Sinal vai e vem. Nenhum ritmo detectado.';

  @override
  String get nodedexFieldNoteDrifter5 =>
      'Presente mas não confiável. Intervalos variam muito.';

  @override
  String get nodedexFieldNoteDrifter6 =>
      'Tempo de observação disperso. Nenhuma periodicidade encontrada.';

  @override
  String get nodedexFieldNoteDrifter7 =>
      'Intermitente mas ativo. Programação imprevisível.';

  @override
  String nodedexFieldNoteGhost0(String lastSeen) {
    return 'Raramente observado. Último avistamento confirmado $lastSeen.';
  }

  @override
  String nodedexFieldNoteGhost1(int encounters, int age) {
    return 'Elusivo. $encounters encontros em $age dias.';
  }

  @override
  String get nodedexFieldNoteGhost2 =>
      'Sinal aparece brevemente e desaparece. Padrão desconhecido.';

  @override
  String get nodedexFieldNoteGhost3 =>
      'Apenas rastros intermitentes. Dados insuficientes para perfil.';

  @override
  String get nodedexFieldNoteGhost4 =>
      'Fraco e esporádico. Presença não confiável.';

  @override
  String get nodedexFieldNoteGhost5 =>
      'Aparece sem aviso. Desaparece sem rastro.';

  @override
  String get nodedexFieldNoteGhost6 =>
      'Baixa densidade de encontros. Comportamento difícil de classificar.';

  @override
  String get nodedexFieldNoteGhost7 =>
      'Detectado nas margens. Janela de observação estreita.';

  @override
  String get nodedexFieldNoteLabel => 'Nota de campo';

  @override
  String get nodedexFieldNoteRelay0 =>
      'Encaminhando tráfego. Função de roteador confirmada.';

  @override
  String get nodedexFieldNoteRelay1 =>
      'Nó relay ativo. Utilização do canal elevada.';

  @override
  String get nodedexFieldNoteRelay2 =>
      'Função de infraestrutura: encaminhamento de tráfego observado.';

  @override
  String get nodedexFieldNoteRelay3 =>
      'Assinatura de roteador detectada. Alto uso de airtime.';

  @override
  String get nodedexFieldNoteRelay4 =>
      'Elemento backbone da mesh. Facilita a conectividade.';

  @override
  String nodedexFieldNoteRelay5(int encounters) {
    return 'Comportamento relay consistente em $encounters sessões.';
  }

  @override
  String get nodedexFieldNoteRelay6 =>
      'Gerenciador de tráfego. Padrão de encaminhamento estável.';

  @override
  String get nodedexFieldNoteRelay7 =>
      'Infraestrutura de rede. Roteamento confirmado pela função.';

  @override
  String nodedexFieldNoteSentinel0(int age) {
    return 'Posição fixa. Monitorando há $age dias.';
  }

  @override
  String get nodedexFieldNoteSentinel1 =>
      'Instalação estacionária. Sinal consistente e forte.';

  @override
  String nodedexFieldNoteSentinel2(int encounters) {
    return 'Presença sentinela. $encounters observações de uma posição.';
  }

  @override
  String nodedexFieldNoteSentinel3(String firstSeen) {
    return 'Posto de longa duração. Primeira observação $firstSeen.';
  }

  @override
  String get nodedexFieldNoteSentinel4 =>
      'Sem variação de posição. Assinatura de infraestrutura confirmada.';

  @override
  String get nodedexFieldNoteSentinel5 =>
      'Mantendo posição. Confiável desde o primeiro contato.';

  @override
  String nodedexFieldNoteSentinel6(int snr) {
    return 'Instalação estática. Melhor sinal $snr dB SNR.';
  }

  @override
  String nodedexFieldNoteSentinel7(int age) {
    return 'Elemento permanente. Observado continuamente por $age dias.';
  }

  @override
  String get nodedexFieldNoteUnknown0 =>
      'Descoberto recentemente. Observação em andamento.';

  @override
  String get nodedexFieldNoteUnknown1 =>
      'Novo contato. Dados insuficientes para classificação.';

  @override
  String nodedexFieldNoteUnknown2(String firstSeen) {
    return 'Registrado pela primeira vez $firstSeen. Aguardando mais sinais.';
  }

  @override
  String get nodedexFieldNoteUnknown3 =>
      'Identidade registrada. Perfil comportamental pendente.';

  @override
  String get nodedexFieldNoteUnknown4 =>
      'Entrada inicial. Mais encontros necessários para avaliação.';

  @override
  String get nodedexFieldNoteUnknown5 =>
      'Catalogado. Nenhum padrão comportamental estabelecido ainda.';

  @override
  String get nodedexFieldNoteUnknown6 =>
      'Sinal reconhecido. Classificação adiada.';

  @override
  String get nodedexFieldNoteUnknown7 =>
      'Entrada criada. Monitoramento iniciado.';

  @override
  String nodedexFieldNoteWanderer0(int regions) {
    return 'Registrado em $regions regiões. Sem direção fixa.';
  }

  @override
  String nodedexFieldNoteWanderer1(int positions) {
    return 'Passa sem se fixar. $positions posições registradas.';
  }

  @override
  String nodedexFieldNoteWanderer2(int regions) {
    return 'Sinal transitório. Observado em movimento por $regions zonas.';
  }

  @override
  String nodedexFieldNoteWanderer3(String distance) {
    return 'Padrão migratório suspeito. Alcance até $distance.';
  }

  @override
  String get nodedexFieldNoteWanderer4 =>
      'Aparece em coordenadas diferentes a cada sessão.';

  @override
  String nodedexFieldNoteWanderer5(int regions) {
    return 'Nenhum ponto de ancoragem detectado. Deriva confirmada em $regions regiões.';
  }

  @override
  String nodedexFieldNoteWanderer6(int positions) {
    return 'Registrado em $positions posições. Caminho indefinido.';
  }

  @override
  String get nodedexFieldNoteWanderer7 => 'Origem do sinal muda entre sessões.';

  @override
  String get nodedexFilterAll => 'Todos';

  @override
  String get nodedexFilterByDateHelp => 'Filtrar encontros por data';

  @override
  String get nodedexFilterRecent => 'Recentes';

  @override
  String get nodedexFilterTagged => 'Com tag';

  @override
  String nodedexObservedOnPreset(String preset) {
    return 'Observed on: $preset';
  }

  @override
  String nodedexLastObservedOnPreset(String preset) {
    return 'Last observed on $preset';
  }

  @override
  String get nodedexFilterRadioPreset => 'Radio Preset';

  @override
  String get nodedexRadioPresetUnknown => 'Unknown';

  @override
  String get nodedexFrequencyOffset => 'Freq Offset';

  @override
  String nodedexFrequencyOffsetValue(String offset) {
    return '$offset Hz';
  }

  @override
  String get nodedexFilterRadioPresetAll => 'All Presets';

  @override
  String get nodedexRadioPresetSheetTitle => 'Filter by Radio Preset';

  @override
  String get nodedexFirmwareLabel => 'Firmware';

  @override
  String get nodedexFirstDiscovered => 'Primeira descoberta';

  @override
  String get nodedexFirstSeenStatLabel => 'Primeira visão';

  @override
  String get nodedexFirstSighting => 'Primeiro avistamento';

  @override
  String get nodedexGalleryHint =>
      'Toque no cartão para virar • Deslize para navegar';

  @override
  String nodedexGalleryPositionCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String get nodedexGotIt => 'Entendi';

  @override
  String get nodedexGroupByLabel => 'AGRUPAR POR';

  @override
  String get nodedexGroupByRarity => 'Raridade';

  @override
  String get nodedexGroupByRegion => 'Região';

  @override
  String get nodedexGroupByTrait => 'Traço';

  @override
  String get nodedexHardwareLabel => 'Hardware';

  @override
  String get nodedexHelpActivityTimeline => 'Cronologia de atividade';

  @override
  String get nodedexHelpClassification => 'Classificação';

  @override
  String get nodedexHelpConstellationLinks => 'Links de constelação';

  @override
  String get nodedexHelpDeviceInfo => 'Info do dispositivo';

  @override
  String get nodedexHelpDiscoveryStats => 'Estatísticas de descoberta';

  @override
  String get nodedexHelpInfoDefault => 'Info';

  @override
  String get nodedexHelpNote => 'Nota';

  @override
  String get nodedexHelpPersonalityTrait => 'Traço de personalidade';

  @override
  String get nodedexHelpRecentEncounters => 'Encontros recentes';

  @override
  String get nodedexHelpRegionHistory => 'Histórico da região';

  @override
  String get nodedexHelpSigil => 'Sigilo';

  @override
  String get nodedexHelpSignalRecords => 'Registros de sinal';

  @override
  String nodedexImportButtonLabelPlural(int count) {
    return 'Importar $count entradas';
  }

  @override
  String nodedexImportButtonLabelSingular(int count) {
    return 'Importar $count entrada';
  }

  @override
  String nodedexImportClassificationConflictPlural(int count) {
    return '$count conflitos de classificação';
  }

  @override
  String nodedexImportClassificationConflictSingular(int count) {
    return '$count conflito de classificação';
  }

  @override
  String get nodedexImportConflictingDataMessage =>
      'Algumas entradas têm dados conflitantes';

  @override
  String get nodedexImportConflictingEntriesLabel => 'Entradas conflitantes';

  @override
  String get nodedexImportConflictsFallback =>
      'Conflitos detectados em campos do usuário.';

  @override
  String nodedexImportConflictsResolveBelow(String details) {
    return '$details. Escolha como resolver abaixo.';
  }

  @override
  String nodedexImportEntriesInFile(int count) {
    return '$count entradas no arquivo';
  }

  @override
  String nodedexImportFailed(String error) {
    return 'Importação falhou: $error';
  }

  @override
  String get nodedexImportFailedToReadFile => 'Falha ao ler o arquivo';

  @override
  String get nodedexImportFieldClassification => 'Classificação';

  @override
  String get nodedexImportFieldNote => 'Nota';

  @override
  String get nodedexImportHideDetails => 'Ocultar detalhes';

  @override
  String get nodedexImportImportLabel => 'Importar';

  @override
  String get nodedexImportImportingLabel => 'Importando...';

  @override
  String get nodedexImportLocalLabel => 'Local';

  @override
  String get nodedexImportMergeStrategyLabel => 'Estratégia de mesclagem';

  @override
  String get nodedexImportNoValidEntries =>
      'Nenhuma entrada NodeDex válida encontrada no arquivo';

  @override
  String get nodedexImportNoneValue => 'Nenhum';

  @override
  String nodedexImportNoteConflictPlural(int count) {
    return '$count conflitos de nota';
  }

  @override
  String nodedexImportNoteConflictSingular(int count) {
    return '$count conflito de nota';
  }

  @override
  String get nodedexImportNothingNewToImport => 'Nada de novo para importar';

  @override
  String get nodedexImportNothingToImportDescription =>
      'O arquivo não contém entradas NodeDex válidas.';

  @override
  String get nodedexImportNothingToImportTitle => 'Nada para importar';

  @override
  String get nodedexImportPreviewSubtitle => 'Revise antes de aplicar';

  @override
  String get nodedexImportPreviewTitle => 'Prévia da importação';

  @override
  String get nodedexImportShowDetails => 'Mostrar detalhes';

  @override
  String get nodedexImportStrategyKeepLocalDescription =>
      'Suas classificações e notas permanecem inalteradas';

  @override
  String get nodedexImportStrategyKeepLocalTitle => 'Manter local';

  @override
  String get nodedexImportStrategyPreferImportDescription =>
      'Usar classificações e notas importadas onde diferentes';

  @override
  String get nodedexImportStrategyPreferImportTitle => 'Preferir importação';

  @override
  String get nodedexImportStrategyReviewEachDescription =>
      'Decida por conflito qual valor manter';

  @override
  String get nodedexImportStrategyReviewEachTitle => 'Revisar cada um';

  @override
  String nodedexImportSuccessPlural(int count) {
    return 'Importadas $count entradas';
  }

  @override
  String nodedexImportSuccessSingular(int count) {
    return 'Importada $count entrada';
  }

  @override
  String get nodedexImportSummaryConflicts => 'Conflitos';

  @override
  String get nodedexImportSummaryMerge => 'Mesclagem';

  @override
  String get nodedexImportSummaryNew => 'Novos';

  @override
  String get nodedexKnownFor => 'Conhecido há';

  @override
  String nodedexKnownForDaysAgo(int days) {
    return '$days dias atrás';
  }

  @override
  String nodedexKnownForHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String get nodedexKnownForOneDayAgo => '1 dia atrás';

  @override
  String get nodedexLastLogged => 'Último registro';

  @override
  String nodedexLastReadings(int count) {
    return 'Últimas $count leituras';
  }

  @override
  String nodedexLastRelative(String relative) {
    return 'último $relative';
  }

  @override
  String get nodedexLastSeen => 'Último avistamento';

  @override
  String get nodedexLastSeenStatLabel => 'Última visão';

  @override
  String nodedexLastSeenAtTime(String date, String time) {
    return '$date às $time';
  }

  @override
  String get nodedexLegendFair => 'Razoável';

  @override
  String get nodedexLegendNoData => 'Sem dados';

  @override
  String get nodedexLegendStrong => 'Forte';

  @override
  String get nodedexLegendWeak => 'Fraco';

  @override
  String nodedexLinkCountPlural(int count) {
    return '$count ligações';
  }

  @override
  String nodedexLinkCountSingular(int count) {
    return '$count ligação';
  }

  @override
  String get nodedexLinkStrengthLabel => 'Força do vínculo';

  @override
  String nodedexLinkedForDuration(String duration) {
    return 'Vinculado por $duration';
  }

  @override
  String get nodedexMaxDistanceStatLabel => 'Distância máx.';

  @override
  String nodedexMaxRange(String distance) {
    return 'Alcance máx.: $distance';
  }

  @override
  String get nodedexMaxRangeLabel => 'Alcance máx.';

  @override
  String get nodedexMessageActivity => 'Atividade de mensagens';

  @override
  String nodedexMessagesExchangedCoPresent(int count) {
    return '$count mensagens trocadas em co-presença';
  }

  @override
  String get nodedexMessagesLabel => 'Mensagens';

  @override
  String get nodedexMessagesStatLabel => 'Mensagens';

  @override
  String get nodedexNicknameHint => 'Apelido';

  @override
  String get nodedexNoClassification =>
      'Nenhuma classificação atribuída. Toque em \"Classificar\" para adicionar uma.';

  @override
  String get nodedexNoEncountersOnDate => 'Nenhum encontro nesta data';

  @override
  String get nodedexNoEncountersRecorded => 'Nenhum encontro registrado';

  @override
  String get nodedexNoNoteYet =>
      'Nenhuma nota ainda. Toque em \"Adicionar nota\" para escrever uma.';

  @override
  String get nodedexNoRelationshipDataDescription =>
      'Esses nós não foram observados juntos.';

  @override
  String get nodedexNoRelationshipDataTitle => 'Sem dados de relacionamento';

  @override
  String nodedexNodeCountPlural(int count) {
    return '$count nós';
  }

  @override
  String nodedexNodeCountSingular(int count) {
    return '$count nó';
  }

  @override
  String get nodedexNoteAdd => 'Adicionar nota';

  @override
  String get nodedexNoteCancel => 'Cancelar';

  @override
  String get nodedexNoteEdit => 'Editar';

  @override
  String get nodedexNoteHint => 'Escreva uma nota sobre este nó...';

  @override
  String get nodedexNoteSave => 'Salvar';

  @override
  String get nodedexNoteTitle => 'Nota';

  @override
  String get nodedexObservationTimelineTitle => 'Linha do tempo de observações';

  @override
  String nodedexObservedDate(String date) {
    return 'Observado em $date';
  }

  @override
  String get nodedexPaletteColorPrimary => 'Primária';

  @override
  String get nodedexPaletteColorSecondary => 'Secundária';

  @override
  String get nodedexPaletteColorTertiary => 'Terciária';

  @override
  String get nodedexPatinaAxisEncounters => 'Encontros';

  @override
  String get nodedexPatinaAxisEncountersDescription =>
      'Número de observações distintas';

  @override
  String get nodedexPatinaAxisReach => 'Alcance';

  @override
  String get nodedexPatinaAxisReachDescription =>
      'Distribuição geográfica entre regiões';

  @override
  String get nodedexPatinaAxisRecency => 'Recência';

  @override
  String get nodedexPatinaAxisRecencyDescription =>
      'Quão recentemente este nó esteve ativo';

  @override
  String get nodedexPatinaAxisSignalDepth => 'Profundidade do sinal';

  @override
  String get nodedexPatinaAxisSignalDepthDescription =>
      'Qualidade dos registros de sinal coletados';

  @override
  String get nodedexPatinaAxisSocial => 'Social';

  @override
  String get nodedexPatinaAxisSocialDescription =>
      'Relacionamentos co-vistos e mensagens';

  @override
  String get nodedexPatinaAxisTenure => 'Antiguidade';

  @override
  String get nodedexPatinaAxisTenureDescription =>
      'Há quanto tempo este nó é conhecido';

  @override
  String get nodedexPatinaBreakdownSubtitle =>
      'Histórico acumulado em seis dimensões';

  @override
  String get nodedexPatinaBreakdownTitle => 'Detalhamento da Pátina';

  @override
  String get nodedexPatinaEncounters => 'Encontros';

  @override
  String get nodedexPatinaLabel => 'PÁTINA';

  @override
  String get nodedexPatinaReach => 'Alcance';

  @override
  String get nodedexPatinaRecency => 'Recência';

  @override
  String get nodedexPatinaSignal => 'Sinal';

  @override
  String get nodedexPatinaSocial => 'Social';

  @override
  String get nodedexPatinaStampArchival => 'Arquival';

  @override
  String get nodedexPatinaStampCanonical => 'Canônico';

  @override
  String get nodedexPatinaStampEtched => 'Gravado';

  @override
  String get nodedexPatinaStampFaint => 'Tênue';

  @override
  String get nodedexPatinaStampInked => 'Marcado';

  @override
  String get nodedexPatinaStampLogged => 'Registrado';

  @override
  String get nodedexPatinaStampNoted => 'Anotado';

  @override
  String get nodedexPatinaStampTrace => 'Rastro';

  @override
  String get nodedexPatinaTenure => 'Antiguidade';

  @override
  String get nodedexPerDay => '/dia';

  @override
  String get nodedexPositionsLabel => 'Posições';

  @override
  String get nodedexPresenceActive => 'Ativo';

  @override
  String get nodedexPresenceFading => 'Desvanecendo';

  @override
  String get nodedexPresenceStale => 'Obsoleto';

  @override
  String get nodedexPresenceUnknown => 'Desconhecido';

  @override
  String get nodedexProfileButton => 'Perfil';

  @override
  String nodedexRarityCardsPageTitle(String rarityLabel) {
    return 'Cartas $rarityLabel';
  }

  @override
  String get nodedexRecentLabel => 'RECENTE';

  @override
  String nodedexRegionEncounterCount(int count) {
    return '$count encontros';
  }

  @override
  String get nodedexRegionsCompactLabel => 'Regiões';

  @override
  String get nodedexRegionsLabel => 'Regiões';

  @override
  String get nodedexRelationshipTimeline => 'Linha do tempo do relacionamento';

  @override
  String nodedexRelativeDaysAgo(int days) {
    return '${days}d atrás';
  }

  @override
  String nodedexRelativeHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String get nodedexRelativeJustNow => 'agora';

  @override
  String nodedexRelativeMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String nodedexRelativeMonthsAgo(int months) {
    return '${months}me atrás';
  }

  @override
  String nodedexRelativeTimeDaysAgo(int days) {
    return '${days}d atrás';
  }

  @override
  String nodedexRelativeTimeHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String nodedexRelativeTimeMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String get nodedexRelativeTimeMomentsAgo => 'agora mesmo';

  @override
  String nodedexRelativeTimeMonthsAgo(int months) {
    return '$months meses atrás';
  }

  @override
  String get nodedexRelativeTimeOneMonthAgo => '1 mês atrás';

  @override
  String get nodedexRelativeTimeYesterday => 'ontem';

  @override
  String get nodedexRemoveClassification => 'Remover classificação';

  @override
  String get nodedexResetViewTooltip => 'Redefinir visualização';

  @override
  String get nodedexRngLabel => 'RNG';

  @override
  String nodedexRssiDbmValue(String value) {
    return '$value dBm';
  }

  @override
  String get nodedexRssiLabel => 'RSSI';

  @override
  String get nodedexSearchHint => 'Buscar um nó';

  @override
  String get nodedexSectionDiscoveredNodes => 'Nós descobertos';

  @override
  String get nodedexSectionYourDevice => 'Seu dispositivo';

  @override
  String nodedexSeenTogetherCount(int count) {
    return 'Vistos juntos $count vezes';
  }

  @override
  String nodedexSelectedLinksCount(int count) {
    return '$count vínculos';
  }

  @override
  String get nodedexSetNickname => 'Definir apelido';

  @override
  String get nodedexSettingsTooltip => 'Configurações';

  @override
  String nodedexShareCardCheckOut(String name) {
    return 'Confira o Sigil Card de $name no SocialMesh!';
  }

  @override
  String get nodedexShareCardImageFailed =>
      'Falha ao capturar imagem do cartão';

  @override
  String get nodedexShareCouldNotShare =>
      'Não foi possível compartilhar o cartão';

  @override
  String get nodedexShareGetSocialmesh => 'Baixe o SocialMesh:';

  @override
  String get nodedexShareSigilCard => 'Compartilhar Sigil Card';

  @override
  String nodedexSightingsPlural(int count) {
    return '$count avistamentos';
  }

  @override
  String nodedexSightingsSingular(int count) {
    return '$count avistamento';
  }

  @override
  String get nodedexSigilCardTitle => 'Cartão Sigilo';

  @override
  String get nodedexSignalRecordsTitle => 'Registros de sinal';

  @override
  String nodedexSnrDbValue(String value) {
    return '$value dB';
  }

  @override
  String get nodedexSnrLabel => 'SNR';

  @override
  String get nodedexSnrTrend => 'TENDÊNCIA SNR';

  @override
  String get nodedexSocialTagContactDescription =>
      'Uma pessoa com quem você se comunica';

  @override
  String get nodedexSocialTagFrequentPeerDescription =>
      'Visto regularmente na rede mesh';

  @override
  String get nodedexSocialTagKnownRelayDescription =>
      'Um nó que encaminha tráfego de forma confiável';

  @override
  String get nodedexSocialTagTrustedNodeDescription =>
      'Infraestrutura verificada e confiável';

  @override
  String get nodedexSortDiscovered => 'Descoberto';

  @override
  String get nodedexSortEncounters => 'Encontros';

  @override
  String get nodedexSortFirstDiscovered => 'Primeira descoberta';

  @override
  String get nodedexSortLastSeen => 'Último avistamento';

  @override
  String get nodedexSortLongestRange => 'Maior alcance';

  @override
  String get nodedexSortMostEncounters => 'Mais encontros';

  @override
  String get nodedexSortName => 'Nome';

  @override
  String get nodedexSortRange => 'Alcance';

  @override
  String get nodedexStatCoSeen => 'Co-vistos';

  @override
  String get nodedexStatDuration => 'Duração';

  @override
  String get nodedexStatFirstLink => 'Primeiro vínculo';

  @override
  String get nodedexStatLastSeen => 'Último avistamento';

  @override
  String get nodedexStatMessages => 'Mensagens';

  @override
  String get nodedexStatsDays => 'DIAS';

  @override
  String get nodedexStatsEncounters => 'ENCONTROS';

  @override
  String get nodedexStatsNodes => 'NÓS';

  @override
  String get nodedexStatsRegions => 'REGIÕES';

  @override
  String nodedexStreakDays(int count) {
    return 'Sequência de $count dias';
  }

  @override
  String get nodedexStrengthEmerging => 'Emergente';

  @override
  String get nodedexStrengthModerate => 'Moderado';

  @override
  String get nodedexStrengthNew => 'Novo';

  @override
  String get nodedexStrengthStrong => 'Forte';

  @override
  String get nodedexStrengthVeryStrong => 'Muito forte';

  @override
  String get nodedexSummaryCardTitle => 'Resumo';

  @override
  String nodedexSummaryEncountersRecorded(int count) {
    return '$count encontros registrados';
  }

  @override
  String get nodedexSummaryKeepObserving =>
      'Continue observando para criar um perfil';

  @override
  String nodedexSummaryMostActiveIn(String bucket) {
    return 'Mais ativo de $bucket';
  }

  @override
  String nodedexSummarySeenDaysOf14(int activeDays) {
    return 'Visto $activeDays dos últimos 14 dias';
  }

  @override
  String nodedexSummarySpottedDaysOf14(int activeDays) {
    return 'Avistado $activeDays dos últimos 14 dias';
  }

  @override
  String nodedexSummaryUsuallyOnDay(String day) {
    return 'Geralmente às ${day}s';
  }

  @override
  String get nodedexSwitchToAlbumView => 'Mudar para visualização de álbum';

  @override
  String get nodedexSwitchToListView => 'Mudar para visualização de lista';

  @override
  String get nodedexTagContact => 'Contato';

  @override
  String get nodedexTagFrequentPeer => 'Peer frequente';

  @override
  String get nodedexTagKnownRelay => 'Relay conhecido';

  @override
  String get nodedexTagTrustedNode => 'Nó confiável';

  @override
  String get nodedexTapCardToFlipSemanticLabel => 'Toque no cartão para virar';

  @override
  String get nodedexTapToFlip => 'TOQUE PARA VIRAR';

  @override
  String get nodedexTimeBucketDawn => 'Amanhecer';

  @override
  String get nodedexTimeBucketDawnRange => '5h – 11h';

  @override
  String get nodedexTimeBucketEvening => 'Noite';

  @override
  String get nodedexTimeBucketEveningRange => '17h – 23h';

  @override
  String get nodedexTimeBucketMidday => 'Meio-dia';

  @override
  String get nodedexTimeBucketMiddayRange => '11h – 17h';

  @override
  String get nodedexTimeBucketNight => 'Madrugada';

  @override
  String get nodedexTimeBucketNightRange => '23h – 5h';

  @override
  String nodedexTimelineChannel(String channel) {
    return 'Canal $channel';
  }

  @override
  String get nodedexTimelineCouldNotLoad =>
      'Não foi possível carregar a linha do tempo';

  @override
  String nodedexTimelineEncounterBestSnr(int snr) {
    return ', melhor SNR ${snr}dB';
  }

  @override
  String nodedexTimelineEncounterClosest(String distance) {
    return ', mais perto $distance';
  }

  @override
  String nodedexTimelineEncounterSession(
    int count,
    String duration,
    String detail,
  ) {
    return '$count encontros em $duration$detail';
  }

  @override
  String get nodedexTimelineEncountered => 'Encontrado';

  @override
  String nodedexTimelineEncounteredAtDistance(String distance) {
    return 'Encontrado a $distance';
  }

  @override
  String nodedexTimelineEncounteredSnr(int snr) {
    return 'Encontrado (SNR ${snr}dB)';
  }

  @override
  String get nodedexTimelineEventsAppearHere =>
      'Os eventos aparecerão aqui conforme você interagir com este nó.';

  @override
  String get nodedexTimelineFirst => 'Primeiro';

  @override
  String nodedexTimelineHoursUnit(String hours) {
    return '$hours h';
  }

  @override
  String get nodedexTimelineJustNow => 'Agora';

  @override
  String get nodedexTimelineLatest => 'Último';

  @override
  String get nodedexTimelineLessThanOneMin => '<1 min';

  @override
  String nodedexTimelineMinutesUnit(int minutes) {
    return '$minutes min';
  }

  @override
  String get nodedexTimelineNoActivityYet => 'Nenhuma atividade ainda';

  @override
  String nodedexTimelineReceived(String text) {
    return 'Recebido: $text';
  }

  @override
  String nodedexTimelineSent(String text) {
    return 'Enviado: $text';
  }

  @override
  String nodedexTimelineSignal(String content) {
    return 'Sinal: $content';
  }

  @override
  String get nodedexTitle => 'NodeDex';

  @override
  String nodedexTotalCount(int count) {
    return '$count no total';
  }

  @override
  String get nodedexTraitAnchor => 'Âncora';

  @override
  String get nodedexTraitAnchorDescription =>
      'Hub persistente com muitas conexões';

  @override
  String get nodedexTraitBeacon => 'Farol';

  @override
  String get nodedexTraitBeaconDescription =>
      'Sempre ativo, alta disponibilidade';

  @override
  String get nodedexTraitCollectionLabel => 'COLEÇÃO DE TRAÇOS';

  @override
  String get nodedexTraitCourier => 'Correio';

  @override
  String get nodedexTraitCourierDescription =>
      'Transporta mensagens pela rede mesh';

  @override
  String get nodedexTraitDrifter => 'Errante';

  @override
  String get nodedexTraitDrifterDescription =>
      'Tempo irregular, aparece e desaparece';

  @override
  String get nodedexTraitGhost => 'Fantasma';

  @override
  String get nodedexTraitGhostDescription =>
      'Raramente visto, presença elusiva';

  @override
  String nodedexTraitNodesPageTitle(String traitLabel) {
    return 'Nós $traitLabel';
  }

  @override
  String get nodedexTraitRelay => 'Repetidor';

  @override
  String get nodedexTraitRelayDescription =>
      'Alto throughput, encaminha tráfego';

  @override
  String get nodedexTraitSentinel => 'Sentinela';

  @override
  String get nodedexTraitSentinelDescription =>
      'Posição fixa, guardião duradouro';

  @override
  String get nodedexTraitUnknown => 'Novato';

  @override
  String get nodedexTraitUnknownDescription => 'Descoberto recentemente';

  @override
  String get nodedexTraitWanderer => 'Andarilho';

  @override
  String get nodedexTraitWandererDescription => 'Visto em vários locais';

  @override
  String get nodedexTrustDescriptionEstablished =>
      'Histórico profundo em todas as dimensões';

  @override
  String get nodedexTrustDescriptionFamiliar =>
      'Presença regular com algum histórico';

  @override
  String get nodedexTrustDescriptionObserved => 'Visto algumas vezes na mesh';

  @override
  String get nodedexTrustDescriptionTrusted =>
      'Frequente, duradouro, comunicativo';

  @override
  String get nodedexTrustDescriptionUnknown =>
      'Dados insuficientes para avaliar';

  @override
  String get nodedexTrustLevelEstablished => 'Estabelecido';

  @override
  String get nodedexTrustLevelFamiliar => 'Familiar';

  @override
  String get nodedexTrustLevelObserved => 'Observado';

  @override
  String get nodedexTrustLevelTrusted => 'Confiável';

  @override
  String get nodedexTrustLevelUnknown => 'Desconhecido';

  @override
  String get nodedexUnknownRegion => 'Região desconhecida';

  @override
  String get nodedexUptimeLabel => 'Tempo ativo';

  @override
  String get nodedexViewProfile => 'Ver perfil';

  @override
  String get nodedexWalletCouldNotAdd =>
      'Não foi possível adicionar ao Apple Wallet';

  @override
  String get nodedexWalletCouldNotOpen =>
      'Não foi possível abrir o Apple Wallet';

  @override
  String get nodedexWalletCouldNotPublish =>
      'Não foi possível publicar o cartão sigil';

  @override
  String get nodesScreenConnectedDevice => 'Dispositivo conectado';

  @override
  String get nodesScreenDisconnect => 'Desconectar';

  @override
  String nodesScreenDistanceKilometers(String km) {
    return '$km km de distância';
  }

  @override
  String nodesScreenDistanceMeters(String meters) {
    return '$meters m de distância';
  }

  @override
  String get nodesScreenEmptyAll => 'Nenhum nó descoberto';

  @override
  String get nodesScreenEmptyFiltered => 'Nenhum nó corresponde a este filtro';

  @override
  String get nodesScreenFilterActive => 'Online';

  @override
  String get nodesScreenFilterAll => 'Todos';

  @override
  String get nodesScreenFilterFavorites => 'Favoritos';

  @override
  String get nodesScreenFilterInactive => 'Offline';

  @override
  String get nodesScreenFilterMqtt => 'MQTT';

  @override
  String get nodesScreenFilterNew => 'Novos';

  @override
  String get nodesScreenFilterRf => 'RF';

  @override
  String get nodesScreenFilterWithPosition => 'Com posição';

  @override
  String get nodesScreenGps => 'GPS';

  @override
  String get nodesScreenHelpMenu => 'Ajuda';

  @override
  String nodesScreenHopCount(int count) {
    return '$count saltos';
  }

  @override
  String get nodesScreenHopDirect => 'Direto';

  @override
  String get nodesScreenLogsLabel => 'Registos:';

  @override
  String get nodesScreenNoGps => 'Sem GPS';

  @override
  String get nodesScreenScanQrCodeTooltip => 'Escanear código QR';

  @override
  String get nodesScreenSearchHint => 'Buscar um nó';

  @override
  String get nodesScreenSectionActive => 'Ativos';

  @override
  String get nodesScreenSectionAetherFlights => 'Voos Aether nas proximidades';

  @override
  String get nodesScreenSectionBatteryCritical => 'Crítica (<20%)';

  @override
  String get nodesScreenSectionBatteryFull => 'Cheia (80-100%)';

  @override
  String get nodesScreenSectionBatteryGood => 'Boa (50-80%)';

  @override
  String get nodesScreenSectionBatteryLow => 'Baixa (20-50%)';

  @override
  String get nodesScreenSectionCharging => 'Carregando';

  @override
  String get nodesScreenSectionDiscovering => 'Descobrindo';

  @override
  String get nodesScreenSectionFavorites => 'Favoritos';

  @override
  String get nodesScreenSectionInactive => 'Inativos';

  @override
  String get nodesScreenSectionSeenRecently => 'Vistos recentemente';

  @override
  String get nodesScreenSectionSignalMedium => 'Médio (-10 a 0 dB)';

  @override
  String get nodesScreenSectionSignalStrong => 'Forte (>0 dB)';

  @override
  String get nodesScreenSectionSignalWeak => 'Fraco (<-10 dB)';

  @override
  String get nodesScreenSectionUnknown => 'Desconhecido';

  @override
  String get nodesScreenSectionYourDevice => 'Seu dispositivo';

  @override
  String get nodesScreenSettingsMenu => 'Configurações';

  @override
  String get nodesScreenShowAllButton => 'Mostrar todos os nós';

  @override
  String get nodesScreenSortBattery => 'Bateria';

  @override
  String get nodesScreenSortMenuBatteryLevel => 'Nível de bateria';

  @override
  String get nodesScreenSortMenuMostRecent => 'Mais recentes';

  @override
  String get nodesScreenSortMenuNameAZ => 'Nome (A-Z)';

  @override
  String get nodesScreenSortMenuSignalStrength => 'Potência do sinal';

  @override
  String get nodesScreenSortName => 'Nome';

  @override
  String get nodesScreenSortRecent => 'Recentes';

  @override
  String get nodesScreenSortSignal => 'Sinal';

  @override
  String get nodesScreenThisDevice => 'Este dispositivo';

  @override
  String nodesScreenTitle(int count) {
    return 'Nós ($count)';
  }

  @override
  String get nodesScreenTransportMqtt => 'MQTT';

  @override
  String get nodesScreenTransportRf => 'RF';

  @override
  String get nodesScreenYouBadge => 'VOCÊ';

  @override
  String get onboardingAutomationGeofence => 'Geofence do acampamento base';

  @override
  String get onboardingAutomationGeofenceDesc => 'Entra na área designada';

  @override
  String get onboardingAutomationLowBattery => 'Alerta de bateria fraca';

  @override
  String get onboardingAutomationLowBatteryDesc => 'Bateria cai abaixo de 20%';

  @override
  String get onboardingAutomationSilentWatch => 'Vigilância de nó silencioso';

  @override
  String get onboardingAutomationSilentWatchDesc => 'Sem contato por 30 min';

  @override
  String get onboardingAutomationSosKeyword => 'Palavra-chave SOS';

  @override
  String get onboardingAutomationSosKeywordDesc => 'Mensagem contém \"SOS\"';

  @override
  String get onboardingAutomationsAdvisor =>
      'Configure as regras uma vez e eu monitoro tudo. Bateria fraca? Eu aviso. Nó ficou silencioso? Eu notifico. SOS recebido? Eu aciono seu webhook.';

  @override
  String get onboardingAutomationsDescription =>
      'Acione ações com base em eventos da mesh.\nAlertas de bateria, geofences, palavras-chave e mais.';

  @override
  String get onboardingAutomationsTitle => 'Automações inteligentes';

  @override
  String get onboardingCheckingRadio => 'Verificando configuração do rádio';

  @override
  String get onboardingConnectAdvisor =>
      'Uma vez conectados, operamos completamente offline. A mesh está esperando.';

  @override
  String get onboardingConnectDescription =>
      'Pareie seu dispositivo Meshtastic para começar.\nBluetooth ou USB — você escolhe.';

  @override
  String get onboardingConnectDeviceButton => 'Conectar dispositivo';

  @override
  String get onboardingConnectTitle => 'Pronto para conectar';

  @override
  String get onboardingContinueButton => 'Continuar';

  @override
  String get onboardingDashboardAdvisor =>
      'Widgets, mapas, estatísticas — organize como preferir. Sua mesh, sua visão, seu controle.';

  @override
  String get onboardingDashboardDescription =>
      'Dashboard personalizável com telemetria em tempo real.\nMonitore nós, canais e visualize a rede.';

  @override
  String get onboardingDashboardTitle => 'Seu centro de comando';

  @override
  String get onboardingDeviceHeltec => 'Heltec V3';

  @override
  String get onboardingDeviceHeltecCategory => 'Uso geral';

  @override
  String get onboardingDeviceHeltecDescription =>
      'Nó versátil com display integrado';

  @override
  String get onboardingDeviceLilygo => 'LilyGo T-Beam';

  @override
  String get onboardingDeviceLilygoCategory => 'Longo alcance';

  @override
  String get onboardingDeviceLilygoDescription =>
      'Alcance máximo com antena externa';

  @override
  String get onboardingDevicePopularBadge => 'POPULAR';

  @override
  String get onboardingDeviceRak => 'RAK WisMesh';

  @override
  String get onboardingDeviceRakCategory => 'Profissional';

  @override
  String get onboardingDeviceRakDescription =>
      'Confiabilidade de grau industrial';

  @override
  String get onboardingDeviceSensecap => 'SenseCAP T1000-E';

  @override
  String get onboardingDeviceSensecapCategory => 'Rastreador';

  @override
  String get onboardingDeviceSensecapDescription =>
      'Rastreador GPS compacto com bateria de longa duração';

  @override
  String get onboardingEmotionConfiguratorTitle => 'Configurador de emoções';

  @override
  String get onboardingEmotionResetDefaults => 'Restaurar padrões';

  @override
  String get onboardingEmotionSettingsTooltip => 'Configurações';

  @override
  String get onboardingHardwareAdvisor =>
      'Escolha um SenseCAP T1000-E para rastreamento, um Heltec V3 para alcance ou um RAK WisMesh para confiabilidade. Funciono com qualquer um deles.';

  @override
  String get onboardingHardwareDescription =>
      'Compatível com todos os dispositivos Meshtastic.\nDe rastreadores compactos a estações de longo alcance.';

  @override
  String get onboardingHardwareTitle => 'Hardware compatível';

  @override
  String get onboardingNodedexAdvisor =>
      'Cada nó recebe um sigil único, um nível de raridade e uma pátina que se aprofunda a cada encontro. Colecione todos — seu NodeDex é sua história na mesh.';

  @override
  String get onboardingNodedexBaseCamp => 'Nó acampamento base';

  @override
  String get onboardingNodedexDescription =>
      'Cada nó encontrado se torna um cartão colecionável.\nConstrua seu diário de campo pela mesh.';

  @override
  String get onboardingNodedexEpic => 'ÉPICO';

  @override
  String get onboardingNodedexLegendary => 'LENDÁRIO';

  @override
  String get onboardingNodedexRare => 'RARO';

  @override
  String get onboardingNodedexStandard => 'PADRÃO';

  @override
  String get onboardingNodedexSummitRelay => 'Relay de cume';

  @override
  String get onboardingNodedexTitle => 'NodeDex — Álbum de colecionador';

  @override
  String get onboardingNodedexTrailMarker => 'Marcador de trilha';

  @override
  String get onboardingNodedexValleyScout => 'Explorador do vale';

  @override
  String get onboardingOffGridAdvisor =>
      'Cada mensagem salta pela mesh até chegar ao destino. Alcance medido em quilômetros, não em barras de sinal.';

  @override
  String get onboardingOffGridDescription =>
      'Sem torres de celular. Sem internet necessária.\nComunicação rádio peer-to-peer real.';

  @override
  String get onboardingOffGridTitle => 'Off-grid por design';

  @override
  String get onboardingPrivacyAdvisor =>
      'Tudo fica local a menos que você ative explicitamente a sincronização na nuvem. Sem rastreamento, sem análises, sem compromisso.';

  @override
  String get onboardingPrivacyDescription =>
      'Sem conta obrigatória. Sem nuvem por padrão.\nSeus dados ficam no seu dispositivo.';

  @override
  String get onboardingPrivacyTitle => 'Privacidade em primeiro lugar';

  @override
  String get onboardingSettingUpDevice => 'Configurando seu dispositivo...';

  @override
  String get onboardingSignalDirect => 'Direto';

  @override
  String onboardingSignalHopCount(int count) {
    return '$count salto';
  }

  @override
  String get onboardingSignalLocationShared => 'Localização compartilhada';

  @override
  String get onboardingSignalPhoto => 'Foto';

  @override
  String onboardingSignalTtlRemaining(int minutes) {
    return '${minutes}m restantes';
  }

  @override
  String get onboardingSignalsAdvisor =>
      'Os Signals nos diferenciam. Transmita para todos no alcance, veja-os se propagar pela rede e depois deixe-os desaparecer quando quiser.';

  @override
  String get onboardingSignalsDescription =>
      'Transmissões efêmeras pela mesh.\nCompartilhe presença, fotos e localização — depois deixe desaparecer.';

  @override
  String get onboardingSignalsTitle => 'Sinais';

  @override
  String get onboardingSkipButton => 'Pular';

  @override
  String get onboardingWelcomeAdvisor =>
      'Sou o Ico e serei seu guia. Deixe-me mostrar uma plataforma de comunicação que funciona quando nada mais funciona.';

  @override
  String get onboardingWelcomeDescription =>
      'O app companion Meshtastic mais avançado.\nFeito para profissionais. Projetado para todos.';

  @override
  String get onboardingWelcomeTitle => 'Bem-vindo ao Socialmesh';

  @override
  String get onboardingWidgetBattery => 'Bateria';

  @override
  String get onboardingWidgetDashboard => 'Painel';

  @override
  String get onboardingWidgetLiveBadge => 'AO VIVO';

  @override
  String get onboardingWidgetNodesOnline => 'Nós online';

  @override
  String get onboardingWidgetSnrDb => 'SNR dB';

  @override
  String get paxCounterAboutSubtitle =>
      'O PAX Counter escuta passivamente requisições probe de WiFi e Bluetooth de dispositivos próximos. Não armazena endereços MAC nem dados pessoais.';

  @override
  String get paxCounterAboutTitle => 'Sobre o PAX Counter';

  @override
  String get paxCounterCardSubtitle =>
      'Conta dispositivos WiFi e Bluetooth próximos';

  @override
  String get paxCounterCardTitle => 'Contador PAX';

  @override
  String get paxCounterEnable => 'Ativar PAX Counter';

  @override
  String get paxCounterEnableSubtitle =>
      'Contar dispositivos próximos e reportar à mesh';

  @override
  String paxCounterIntervalMinutes(int minutes) {
    return '$minutes minutos';
  }

  @override
  String get paxCounterMaxLabel => '60 min';

  @override
  String get paxCounterMinLabel => '1 min';

  @override
  String get paxCounterSave => 'Salvar';

  @override
  String paxCounterSaveError(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get paxCounterSaved => 'Configuração do PAX Counter salva';

  @override
  String get paxCounterTitle => 'Contador PAX';

  @override
  String get paxCounterUpdateInterval => 'Intervalo de atualização';

  @override
  String get presenceAllNodes => 'Todos os nós';

  @override
  String get presenceBackNearby => 'De volta nas proximidades';

  @override
  String get presenceBroadcastInfo =>
      'Sua intenção e status são transmitidos com seus signals.';

  @override
  String get presenceClear => 'Limpar';

  @override
  String get presenceEmptyTagline1 =>
      'Nenhum nó descoberto.\nConecte-se a um dispositivo mesh para ver a presença nas proximidades.';

  @override
  String get presenceEmptyTagline2 =>
      'A presença mostra quem está ativo na sua mesh.\nOs nós aparecem quando transmitem.';

  @override
  String get presenceEmptyTagline3 =>
      'Observe nós aparecerem e desaparecerem em tempo real.\nEstados ativo, esmaecendo e offline.';

  @override
  String get presenceEmptyTagline4 =>
      'Rostos familiares são destacados.\nConstrua sua comunidade mesh ao longo do tempo.';

  @override
  String get presenceEmptyTitleKeyword => 'presença';

  @override
  String get presenceEmptyTitlePrefix => 'Nenhuma ';

  @override
  String get presenceEmptyTitleSuffix => ' detectada';

  @override
  String get presenceFamiliarBadge => 'Familiar';

  @override
  String get presenceFilterActive => 'Ativos';

  @override
  String get presenceFilterAll => 'Todos';

  @override
  String get presenceFilterFading => 'Vistos recentemente';

  @override
  String get presenceFilterFamiliar => 'Familiares';

  @override
  String get presenceFilterInactive => 'Inativos';

  @override
  String get presenceFilterUnknown => 'Desconhecidos';

  @override
  String get presenceIntentLabel => 'Intenção';

  @override
  String get presenceIntentUpdated => 'Intenção de presença atualizada';

  @override
  String get presenceLegendMedium => '2-10 min';

  @override
  String get presenceLegendShort => '< 2 min';

  @override
  String get presenceMyPresence => 'Minha presença';

  @override
  String get presenceNoMatchFilter => 'Nenhum nó corresponde a este filtro';

  @override
  String get presenceNoMatchSearch => 'Nenhum nó corresponde à sua busca';

  @override
  String presenceNodeCount(int count, String noun) {
    return '$count $noun';
  }

  @override
  String get presenceNodePlural => 'nós';

  @override
  String get presenceNodeSingular => 'nó';

  @override
  String get presenceQuietMesh =>
      'A mesh está silenciosa — os nós aparecerão quando estiverem online.';

  @override
  String get presenceRecentActivity => 'Atividade recente';

  @override
  String get presenceSave => 'Salvar';

  @override
  String get presenceSearchHint => 'Buscar nós';

  @override
  String get presenceSectionActive => 'Ativos';

  @override
  String get presenceSectionInactive => 'Inativos';

  @override
  String get presenceSectionSeenRecently => 'Vistos recentemente';

  @override
  String get presenceSectionUnknown => 'Desconhecidos';

  @override
  String get presenceSelectIntent => 'Selecionar intenção';

  @override
  String get presenceSetStatus => 'Definir status';

  @override
  String get presenceShowAll => 'Mostrar todos os nós';

  @override
  String get presenceStatusHint => 'O que você está fazendo?';

  @override
  String get presenceStatusLabel => 'Estado';

  @override
  String get presenceStatusNotSet => 'Não definido';

  @override
  String get presenceStatusUpdated => 'Status atualizado';

  @override
  String get presenceTitle => 'Presença';

  @override
  String get presenceTryDifferent => 'Tente uma busca ou filtro diferente';

  @override
  String get presenceWillAppear =>
      'Os nós aparecerão aqui conforme forem descobertos';

  @override
  String get productDetailAnonymous => 'Anônimo';

  @override
  String get productDetailBattery => 'Bateria';

  @override
  String get productDetailBeFirstReviewer =>
      'Seja o primeiro a avaliar este produto!';

  @override
  String get productDetailBluetooth => 'Bluetooth';

  @override
  String get productDetailBuyNow => 'Comprar agora';

  @override
  String productDetailBySeller(String seller) {
    return 'por $seller';
  }

  @override
  String get productDetailCancel => 'Cancelar';

  @override
  String get productDetailChipset => 'Chipset';

  @override
  String get productDetailContactSeller => 'Contatar o vendedor';

  @override
  String get productDetailContactToPurchase =>
      'Entre em contato com o vendedor para comprar este produto.';

  @override
  String productDetailDaysAgo(int count) {
    return '$count dias atrás';
  }

  @override
  String get productDetailDescription => 'Descrição';

  @override
  String get productDetailDimensions => 'Dimensões';

  @override
  String productDetailDiscountBadge(int percent) {
    return '-$percent% DESC.';
  }

  @override
  String get productDetailDisplay => 'Tela';

  @override
  String get productDetailEdit => 'Editar';

  @override
  String get productDetailErrorLoading => 'Erro ao carregar produto';

  @override
  String productDetailEstimatedDelivery(int days) {
    return 'Entrega estimada em $days dias';
  }

  @override
  String get productDetailFeatures => 'Recursos';

  @override
  String get productDetailFirmware => 'Firmware';

  @override
  String get productDetailFreeShipping => 'Frete grátis';

  @override
  String get productDetailFrequencyBands => 'Faixas de frequência';

  @override
  String get productDetailGoBack => 'Voltar';

  @override
  String get productDetailGps => 'GPS';

  @override
  String get productDetailHardwareVersion => 'Versão do hardware';

  @override
  String productDetailImageCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String productDetailInStockCount(int quantity) {
    return 'Em estoque ($quantity disponíveis)';
  }

  @override
  String get productDetailIncludedAccessories => 'Acessórios inclusos';

  @override
  String get productDetailLoraChip => 'Chip LoRa';

  @override
  String get productDetailMeshtasticCompatible => 'Compatível com Meshtastic';

  @override
  String productDetailMonthsAgo(int count) {
    return '$count meses atrás';
  }

  @override
  String get productDetailNoReviews => 'Sem avaliações';

  @override
  String get productDetailNotFound => 'Produto não encontrado';

  @override
  String get productDetailOutOfStock => 'Esgotado';

  @override
  String get productDetailOutOfStockButton => 'Esgotado';

  @override
  String get productDetailPurchaseDisclaimer =>
      'Compras realizadas na loja oficial do vendedor';

  @override
  String get productDetailPurchaseTitle => 'Compra';

  @override
  String get productDetailReadMore => 'Ler mais';

  @override
  String get productDetailRetry => 'Tentar novamente';

  @override
  String productDetailReviewCount(int count) {
    return '($count avaliações)';
  }

  @override
  String get productDetailReviewHint =>
      'Compartilhe sua experiência com este produto...';

  @override
  String productDetailReviewPrivacyNotice(String userName) {
    return 'Sua avaliação será pública e postada como \"$userName\". As avaliações são moderadas antes de aparecerem na página do produto.';
  }

  @override
  String get productDetailReviewSubmitted =>
      'Avaliação enviada para moderação. Obrigado!';

  @override
  String get productDetailReviewTitleLabel => 'Título (opcional)';

  @override
  String get productDetailReviewValidation =>
      'Escreva uma descrição da avaliação';

  @override
  String get productDetailReviewVerified => 'Verificado';

  @override
  String get productDetailReviews => 'Avaliações';

  @override
  String productDetailSelectedPrice(String price) {
    return 'Selecionado: \$$price';
  }

  @override
  String get productDetailSellerResponse => 'Resposta do vendedor';

  @override
  String get productDetailShipping => 'Envio';

  @override
  String productDetailShippingCost(String cost) {
    return 'Frete: \$$cost';
  }

  @override
  String productDetailShipsTo(String countries) {
    return 'Envia para: $countries';
  }

  @override
  String get productDetailShowLess => 'Mostrar menos';

  @override
  String get productDetailSignInFavorites => 'Faça login para salvar favoritos';

  @override
  String productDetailSoldCount(int count) {
    return '$count vendidos';
  }

  @override
  String get productDetailSubmitReview => 'Enviar avaliação';

  @override
  String get productDetailTechSpecs => 'Especificações técnicas';

  @override
  String get productDetailTitle => 'Produto';

  @override
  String get productDetailToday => 'Hoje';

  @override
  String get productDetailTotal => 'Total';

  @override
  String get productDetailUnableToLoadPage =>
      'Não foi possível carregar a página';

  @override
  String get productDetailUnableToLoadReviews =>
      'Não foi possível carregar as avaliações';

  @override
  String get productDetailVendorVerified => 'Vendedor verificado';

  @override
  String productDetailVerifiedOn(String date) {
    return 'Verificado em $date';
  }

  @override
  String get productDetailWebviewOffline =>
      'Este conteúdo requer uma conexão com a internet. Verifique sua conexão e tente novamente.';

  @override
  String productDetailWeeksAgo(int count) {
    return '$count semanas atrás';
  }

  @override
  String get productDetailWeight => 'Peso';

  @override
  String get productDetailWifi => 'WiFi';

  @override
  String get productDetailWriteReview => 'Escrever avaliação';

  @override
  String get productDetailWriteReviewTitle => 'Escrever uma avaliação';

  @override
  String productDetailYearsAgo(int count) {
    return '$count anos atrás';
  }

  @override
  String get productDetailYesterday => 'Ontem';

  @override
  String get productDetailYourRating => 'Sua avaliação';

  @override
  String get productDetailYourReview => 'Sua avaliação *';

  @override
  String get profileBasicInfo => 'Informações básicas';

  @override
  String get profileBioHint => 'Conte-nos sobre você';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileCallsignHint =>
      'Indicativo de radioamador ou identificador';

  @override
  String get profileCallsignInappropriate =>
      'O indicativo não pode conter conteúdo inapropriado';

  @override
  String get profileCallsignLabel => 'Indicativo';

  @override
  String get profileCallsignMax => 'Máx. 10 caracteres';

  @override
  String get profileCloudBackup => 'Backup na nuvem';

  @override
  String get profileCloudStartingUp =>
      'Serviços na nuvem iniciando — tente novamente em breve';

  @override
  String get profileContinueApple => 'Continuar com Apple';

  @override
  String get profileContinueGitHub => 'Continuar com GitHub';

  @override
  String get profileContinueGoogle => 'Continuar com Google';

  @override
  String profileCopiedToClipboard(String label) {
    return '$label copiado para a área de transferência';
  }

  @override
  String get profileCreate => 'Criar perfil';

  @override
  String get profileDeleteAccount => 'Excluir conta';

  @override
  String get profileDeleteConfirmMsg =>
      'Isso excluirá permanentemente sua conta e todos os dados associados. Esta ação não pode ser desfeita.';

  @override
  String get profileDeleteRequiresInternet =>
      'A exclusão da conta requer uma conexão com a internet.';

  @override
  String get profileDeletingAccount => 'Excluindo conta...';

  @override
  String get profileDeletionFailed =>
      'Falha na exclusão. Tente novamente ou entre em contato com o suporte.';

  @override
  String get profileDetailsSection => 'Detalhes';

  @override
  String get profileDiscordHint => 'utilizador#0000';

  @override
  String get profileDiscordLabel => 'Discord';

  @override
  String get profileDisplayNameHint => 'Como você quer ser conhecido';

  @override
  String get profileDisplayNameLabel => 'Nome de exibição';

  @override
  String get profileEditButton => 'Editar perfil';

  @override
  String get profileEditSheetTitle => 'Editar perfil';

  @override
  String get profileEditTooltip => 'Editar perfil';

  @override
  String get profileEmailLabel => 'E-mail';

  @override
  String profileErrorWithMessage(String message) {
    return 'Erro: $message';
  }

  @override
  String get profileGitHubHint => 'utilizador';

  @override
  String get profileGitHubLabel => 'GitHub';

  @override
  String get profileGitHubLinked => 'Conta GitHub vinculada com sucesso!';

  @override
  String get profileHelpTooltip => 'Ajuda';

  @override
  String get profileLinkFailed => 'Falha ao vincular contas';

  @override
  String get profileLinkGitHub => 'Vincular conta GitHub';

  @override
  String profileLinkGitHubMsg(String email, String provider) {
    return 'Uma conta com $email já existe usando $provider.\n\nFaça login com $provider para vincular sua conta GitHub?';
  }

  @override
  String get profileLinkedAccounts => 'Contas vinculadas';

  @override
  String get profileLinksSection => 'Links';

  @override
  String get profileMastodonHint => '@utilizador@instancia.social';

  @override
  String get profileMastodonLabel => 'Mastodon';

  @override
  String get profileMemberSince => 'Membro desde';

  @override
  String get profileNoInternet => 'Sem conexão com a internet';

  @override
  String get profileNotBackedUp => 'Sem backup';

  @override
  String get profileSetup => 'Configure seu perfil';

  @override
  String get profileSetupDesc =>
      'Adicione seu nome, foto e bio para personalizar sua presença na rede mesh.';

  @override
  String get profileSignInDesc =>
      'Faça login para salvar seu perfil na nuvem e sincronizar entre dispositivos.';

  @override
  String get profileSignInFailed => 'Falha no login';

  @override
  String get profileSignInRequiresInternet =>
      'O login requer uma conexão com a internet.';

  @override
  String get profileSignInServicesUnavailable =>
      'Não foi possível conectar aos serviços de login. Verifique sua conexão com a internet e tente novamente.';

  @override
  String profileSignInWithProvider(String provider) {
    return 'Entrar com $provider';
  }

  @override
  String get profileSignOut => 'Sair';

  @override
  String get profileSignOutConfirm => 'Tem certeza de que deseja sair?';

  @override
  String get profileSignOutRequiresInternet =>
      'Sair requer uma conexão com a internet.';

  @override
  String get profileSignedInApple => 'Conectado com Apple';

  @override
  String get profileSignedInGitHub => 'Conectado com GitHub';

  @override
  String get profileSignedInGoogle => 'Conectado com Google';

  @override
  String get profileSigningIn => 'Entrando...';

  @override
  String get profileSocialSection => 'Social';

  @override
  String get profileSyncError =>
      'Erro de sincronização • Toque para tentar novamente';

  @override
  String get profileSyncFailed => 'Falha na sincronização';

  @override
  String get profileSyncPermissionDenied => 'Permissão de sincronização negada';

  @override
  String get profileSyncRequiresInternet =>
      'A sincronização requer uma conexão com a internet.';

  @override
  String get profileSyncTempUnavailable =>
      'Sincronização temporariamente indisponível';

  @override
  String get profileSyncTempUnavailable2 =>
      'Sincronização na nuvem temporariamente indisponível';

  @override
  String get profileSyncTimedOut => 'Sincronização expirou — tente novamente';

  @override
  String profileSynced(String email) {
    return 'Sincronizado • $email';
  }

  @override
  String get profileSynced2 => 'Perfil sincronizado!';

  @override
  String get profileSyncing => 'Sincronizando...';

  @override
  String get profileTelegramHint => 'utilizador';

  @override
  String get profileTelegramLabel => 'Telegram';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileTwitterHint => 'utilizador';

  @override
  String get profileTwitterLabel => 'Twitter / X';

  @override
  String get profileUidLabel => 'UID';

  @override
  String get profileUrlInvalid => 'Insira um URL válido';

  @override
  String get profileUrlMustStartHttp =>
      'O URL deve começar com http:// ou https://';

  @override
  String get profileWebsiteHint => 'https://example.com';

  @override
  String get profileWebsiteLabel => 'Site';

  @override
  String get qrScannerAddNodeConfirm => 'Adicionar nó';

  @override
  String qrScannerAddNodePrompt(String name) {
    return 'Adicionar \"$name\" aos seus nós rastreados?';
  }

  @override
  String get qrScannerAddNodeTitle => 'Adicionar nó';

  @override
  String get qrScannerCancel => 'Cancelar';

  @override
  String get qrScannerCancelAdd => 'Cancelar';

  @override
  String qrScannerChannelAlreadyExists(String name) {
    return 'Você já tem este canal como \"$name\"';
  }

  @override
  String get qrScannerChannelCancel => 'Cancelar';

  @override
  String get qrScannerChannelEditFirst => 'Editar primeiro';

  @override
  String get qrScannerChannelImport => 'Importar';

  @override
  String qrScannerChannelImported(String name) {
    return 'Canal \"$name\" importado';
  }

  @override
  String get qrScannerChannelInfoEncryption => 'Criptografia';

  @override
  String get qrScannerChannelInfoName => 'Nome';

  @override
  String get qrScannerChannelDefaultKeyRecommendation =>
      'Tap \"Edit First\" to generate a secure encryption key before importing.';

  @override
  String get qrScannerChannelDefaultKeyWarning =>
      'This channel uses the default encryption key, which is publicly known and provides no real security.';

  @override
  String get qrScannerChannelSyncNotice =>
      'O canal será sincronizado com o dispositivo conectado.';

  @override
  String get qrScannerConnectDeviceToImport =>
      'Conecte um dispositivo para importar este canal';

  @override
  String qrScannerFailedToProcess(String error) {
    return 'Falha ao processar código QR: $error';
  }

  @override
  String get qrScannerImportChannelTitle => 'Importar canal';

  @override
  String qrScannerImportFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get qrScannerImportedChannelName => 'Importado';

  @override
  String get qrScannerMaxChannels => 'Máximo de 8 canais — exclua um primeiro';

  @override
  String qrScannerNodeAddedToFavorites(String name) {
    return 'Nó \"$name\" adicionado aos favoritos';
  }

  @override
  String get qrScannerNodeAlreadyExists => 'Nó já existe';

  @override
  String qrScannerNodeAlreadyInList(String name) {
    return 'Este nó já está na sua lista como \"$name\".';
  }

  @override
  String get qrScannerNodeInfoId => 'ID do nó';

  @override
  String get qrScannerNodeInfoName => 'Nome';

  @override
  String get qrScannerNodeInfoShort => 'Curto';

  @override
  String get qrScannerPrompt => 'Aponte a câmera para um código QR';

  @override
  String get qrScannerSupportsHint => 'Suporta nós, canais, automações e mais';

  @override
  String get qrScannerTitle => 'Escanear código QR';

  @override
  String get qrScannerUpdate => 'Atualizar';

  @override
  String qrScannerUpdateNamePrompt(String name) {
    return 'Atualizar o nome para \"$name\" e adicionar aos favoritos?';
  }

  @override
  String get reachabilityAboutTitle => 'Sobre a alcançabilidade';

  @override
  String get reachabilityAboutTooltip => 'Sobre a alcançabilidade';

  @override
  String get reachabilityBetaBadge => 'BETA';

  @override
  String get reachabilityDisclaimerBanner =>
      'Apenas estimativas de probabilidade. A entrega nunca é garantida em uma rede mesh.';

  @override
  String get reachabilityEmptyDescription =>
      'Os nós aparecerão conforme forem\nobservados na rede mesh.';

  @override
  String get reachabilityEmptyTitle => 'Nenhum nó descoberto ainda';

  @override
  String get reachabilityGotIt => 'Entendi';

  @override
  String get reachabilityHowCalculatedContent =>
      'A pontuação de probabilidade combina vários fatores:\n• Atualidade: Quão recentemente ouvimos do nó\n• Profundidade do caminho: Número de hops observados\n• Qualidade do sinal: RSSI e SNR quando disponíveis\n• Padrão de observação: Pacotes diretos vs retransmitidos\n• Histórico de ACK: Taxa de sucesso de confirmações de DM';

  @override
  String get reachabilityHowCalculatedTitle => 'Como é calculado?';

  @override
  String get reachabilityLevelHigh => 'Alto';

  @override
  String get reachabilityLevelLow => 'Baixo';

  @override
  String get reachabilityLevelMedium => 'Médio';

  @override
  String get reachabilityLevelsMeanContent =>
      '• Alto: Indicadores recentes fortes, mas não garantido\n• Médio: Confiança moderada com base nos dados disponíveis\n• Baixo: Indicadores fracos ou desatualizados, entrega improvável';

  @override
  String get reachabilityLevelsMeanTitle => 'O que os níveis significam';

  @override
  String get reachabilityLimitationsContent =>
      '• Meshtastic não possui tabelas de roteamento reais\n• Não existem confirmações ponta a ponta\n• O encaminhamento é oportunístico\n• A topologia mesh muda constantemente\n• Todas as estimativas baseadas apenas em observação passiva';

  @override
  String get reachabilityLimitationsTitle => 'Limitações importantes';

  @override
  String reachabilityScorePercent(String percentage) {
    return '$percentage%';
  }

  @override
  String get reachabilityScoringModelContent =>
      'Modelo Oportunístico de Probabilidade de Alcance Mesh (v1) — BETA\n\nUm modelo heurístico que estima a probabilidade de alcançar um nó com base em métricas RF observadas e histórico de pacotes. Esta pontuação representa probabilidade, não alcançabilidade. O Meshtastic encaminha pacotes de forma oportunística sem roteamento. Uma pontuação alta não garante a entrega.';

  @override
  String get reachabilityScoringModelTitle => 'Modelo de Pontuação';

  @override
  String get reachabilityScreenTitle => 'Alcançabilidade';

  @override
  String get reachabilitySearchHint => 'Buscar nós';

  @override
  String get reachabilityWhatIsThisContent =>
      'Esta tela mostra uma estimativa probabilística de quão provável é que suas mensagens alcancem cada nó. NÃO é uma garantia de entrega.';

  @override
  String get reachabilityWhatIsThisTitle => 'O que é isto?';

  @override
  String get regionSelectionApplyDialogConfirm => 'Continuar';

  @override
  String get regionSelectionApplyDialogMessageChange =>
      'Alterar a região fará o dispositivo reiniciar. Isso pode levar até 30 segundos.\n\nVocê será brevemente desconectado enquanto o dispositivo reinicia.';

  @override
  String get regionSelectionApplyDialogMessageInitial =>
      'Seu dispositivo será reiniciado para aplicar as configurações de região. Isso pode levar até 30 segundos.\n\nO app se reconectará automaticamente quando estiver pronto.';

  @override
  String get regionSelectionApplyDialogTitle => 'Aplicar Região';

  @override
  String get regionSelectionApplying => 'Aplicando...';

  @override
  String get regionSelectionBannerSubtitle =>
      'Escolha a frequência correta para sua localização para cumprir as regulamentações locais.';

  @override
  String get regionSelectionBannerTitle => 'Importante: Selecione Sua Região';

  @override
  String get regionSelectionBluetoothSettings => 'Configurações Bluetooth';

  @override
  String get regionSelectionContinue => 'Continuar';

  @override
  String get regionSelectionCurrentBadge => 'ATUAL';

  @override
  String get regionSelectionDeviceDisconnected =>
      'Dispositivo desconectado. Reconecte e tente novamente.';

  @override
  String get regionSelectionOpenBluetoothSettingsError =>
      'Não foi possível abrir as Configurações Bluetooth. Abra manualmente em Ajustes > Bluetooth.';

  @override
  String get regionSelectionPairingHintMessage =>
      'O pareamento Bluetooth foi removido. Esqueça \"Meshtastic_XXXX\" em Ajustes > Bluetooth e reconecte para continuar.';

  @override
  String get regionSelectionPairingInvalidation =>
      'Seu telefone removeu as informações de pareamento armazenadas para este dispositivo.\nVá em Ajustes > Bluetooth, esqueça o dispositivo Meshtastic e tente novamente.';

  @override
  String get regionSelectionReconnectTimeout =>
      'Tempo de reconexão esgotado. Tente novamente.';

  @override
  String get regionSelectionRegionAnz => 'Austrália/NZ';

  @override
  String get regionSelectionRegionAnzDesc => 'Austrália e Nova Zelândia';

  @override
  String get regionSelectionRegionAnzFreq => '915 MHz';

  @override
  String get regionSelectionRegionCn => 'China';

  @override
  String get regionSelectionRegionCnDesc => 'China';

  @override
  String get regionSelectionRegionCnFreq => '470 MHz';

  @override
  String get regionSelectionRegionEu433 => 'Europa 433';

  @override
  String get regionSelectionRegionEu433Desc => 'Frequência alternativa da UE';

  @override
  String get regionSelectionRegionEu433Freq => '433 MHz';

  @override
  String get regionSelectionRegionEu868 => 'Europa 868';

  @override
  String get regionSelectionRegionEu868Desc =>
      'UE, Reino Unido e a maior parte da Europa';

  @override
  String get regionSelectionRegionEu868Freq => '868 MHz';

  @override
  String get regionSelectionRegionIn => 'Índia';

  @override
  String get regionSelectionRegionInDesc => 'Índia';

  @override
  String get regionSelectionRegionInFreq => '865 MHz';

  @override
  String get regionSelectionRegionJp => 'Japão';

  @override
  String get regionSelectionRegionJpDesc => 'Japão';

  @override
  String get regionSelectionRegionJpFreq => '920 MHz';

  @override
  String get regionSelectionRegionKr => 'Coreia';

  @override
  String get regionSelectionRegionKrDesc => 'Coreia do Sul';

  @override
  String get regionSelectionRegionKrFreq => '920 MHz';

  @override
  String get regionSelectionRegionLora24 => '2,4 GHz';

  @override
  String get regionSelectionRegionLora24Desc => 'Banda mundial de 2,4 GHz';

  @override
  String get regionSelectionRegionLora24Freq => '2,4 GHz';

  @override
  String get regionSelectionRegionMy433 => 'Malásia 433';

  @override
  String get regionSelectionRegionMy433Desc => 'Malásia';

  @override
  String get regionSelectionRegionMy433Freq => '433 MHz';

  @override
  String get regionSelectionRegionMy919 => 'Malásia 919';

  @override
  String get regionSelectionRegionMy919Desc => 'Malásia';

  @override
  String get regionSelectionRegionMy919Freq => '919 MHz';

  @override
  String get regionSelectionRegionNz865 => 'Nova Zelândia 865';

  @override
  String get regionSelectionRegionNz865Desc => 'Nova Zelândia alternativa';

  @override
  String get regionSelectionRegionNz865Freq => '865 MHz';

  @override
  String get regionSelectionRegionRu => 'Rússia';

  @override
  String get regionSelectionRegionRuDesc => 'Rússia';

  @override
  String get regionSelectionRegionRuFreq => '868 MHz';

  @override
  String get regionSelectionRegionSg923 => 'Singapura';

  @override
  String get regionSelectionRegionSg923Desc => 'Singapura';

  @override
  String get regionSelectionRegionSg923Freq => '923 MHz';

  @override
  String get regionSelectionRegionTh => 'Tailândia';

  @override
  String get regionSelectionRegionThDesc => 'Tailândia';

  @override
  String get regionSelectionRegionThFreq => '920 MHz';

  @override
  String get regionSelectionRegionTw => 'Taiwan';

  @override
  String get regionSelectionRegionTwDesc => 'Taiwan';

  @override
  String get regionSelectionRegionTwFreq => '923 MHz';

  @override
  String get regionSelectionRegionUa433 => 'Ucrânia 433';

  @override
  String get regionSelectionRegionUa433Desc => 'Ucrânia';

  @override
  String get regionSelectionRegionUa433Freq => '433 MHz';

  @override
  String get regionSelectionRegionUa868 => 'Ucrânia 868';

  @override
  String get regionSelectionRegionUa868Desc => 'Ucrânia';

  @override
  String get regionSelectionRegionUa868Freq => '868 MHz';

  @override
  String get regionSelectionRegionUs => 'Estados Unidos';

  @override
  String get regionSelectionRegionUsDesc => 'EUA, Canadá, México';

  @override
  String get regionSelectionRegionUsFreq => '915 MHz';

  @override
  String get regionSelectionSave => 'Salvar';

  @override
  String get regionSelectionSearchHint => 'Buscar regiões...';

  @override
  String regionSelectionSetRegionError(String error) {
    return 'Falha ao definir região: $error';
  }

  @override
  String get regionSelectionTitleChange => 'Alterar Região';

  @override
  String get regionSelectionTitleInitial => 'Selecione Sua Região';

  @override
  String get regionSelectionViewScanner => 'Ver Scanner';

  @override
  String get reviewModerationAllCaughtUp => 'Tudo em dia!';

  @override
  String get reviewModerationAllReviews => 'Todas as Avaliações';

  @override
  String get reviewModerationAnonymous => 'Anônimo';

  @override
  String get reviewModerationApprove => 'Aprovar';

  @override
  String get reviewModerationApproved => 'Avaliação aprovada';

  @override
  String get reviewModerationCancel => 'Cancelar';

  @override
  String get reviewModerationDelete => 'Excluir';

  @override
  String get reviewModerationDeleteMessage =>
      'Tem certeza de que deseja excluir permanentemente esta avaliação?';

  @override
  String get reviewModerationDeleteTitle => 'Excluir Avaliação';

  @override
  String get reviewModerationDeleted => 'Avaliação excluída';

  @override
  String get reviewModerationErrorLoading => 'Erro ao carregar avaliações';

  @override
  String get reviewModerationLegacy => 'Legacy (sem status)';

  @override
  String get reviewModerationNoDatabase =>
      'Nenhuma avaliação no banco de dados';

  @override
  String get reviewModerationNoPending =>
      'Nenhuma avaliação pendente para moderar';

  @override
  String get reviewModerationNoReviews => 'Nenhuma avaliação ainda';

  @override
  String get reviewModerationPending => 'Pendente';

  @override
  String get reviewModerationReject => 'Rejeitar';

  @override
  String get reviewModerationRejectReasonHint =>
      'Ex. Conteúdo inadequado, spam, etc.';

  @override
  String get reviewModerationRejectReasonLabel => 'Motivo da rejeição';

  @override
  String get reviewModerationRejectTitle => 'Rejeitar Avaliação';

  @override
  String get reviewModerationRejected => 'Avaliação rejeitada';

  @override
  String get reviewModerationTitle => 'Gerenciamento de Avaliações';

  @override
  String get reviewModerationVerified => 'Verificado';

  @override
  String get routeDetailCenterOnNodeTooltip => 'Centralizar no nó';

  @override
  String routeDetailDistanceKilometers(String km) {
    return '$km km';
  }

  @override
  String get routeDetailDistanceLabel => 'Distância';

  @override
  String routeDetailDistanceMeters(String meters) {
    return '$meters m';
  }

  @override
  String routeDetailDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get routeDetailDurationLabel => 'Duração';

  @override
  String routeDetailDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get routeDetailElevationLabel => 'Elevação';

  @override
  String routeDetailElevationValue(String meters) {
    return '$meters m';
  }

  @override
  String routeDetailExportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get routeDetailNoData => '--';

  @override
  String get routeDetailNoGpsPoints => 'Sem Pontos GPS';

  @override
  String get routeDetailPointsLabel => 'Pontos';

  @override
  String routeDetailShareText(String name) {
    return 'Rota: $name';
  }

  @override
  String get routeDetailStorageUnavailable => 'Armazenamento não disponível';

  @override
  String get routeDetailYouBadge => 'Você';

  @override
  String get routesCancel => 'Cancelar';

  @override
  String get routesCancelRecording => 'Cancelar';

  @override
  String routesCardDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String routesCardDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get routesColorLabel => 'Cor';

  @override
  String get routesDeleteAction => 'Excluir';

  @override
  String get routesDeleteConfirmAction => 'Excluir';

  @override
  String routesDeleteConfirmMessage(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Isso não pode ser desfeito.';
  }

  @override
  String get routesDeleteConfirmTitle => 'Excluir Rota?';

  @override
  String routesDistanceDuration(String distance, String duration) {
    return '$distance • $duration';
  }

  @override
  String routesDistanceKilometers(String km) {
    return '$km km';
  }

  @override
  String routesDistanceMeters(String meters) {
    return '$meters m';
  }

  @override
  String routesDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String routesDurationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String routesDurationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String routesElevationGain(String meters) {
    return '$meters m ↑';
  }

  @override
  String get routesEmptyDescription =>
      'Grave sua primeira rota ou importe um arquivo GPX';

  @override
  String get routesEmptyTitle => 'Nenhuma Rota';

  @override
  String routesExportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get routesExportGpx => 'Exportar GPX';

  @override
  String get routesFileReadFailed => 'Falha ao ler o arquivo';

  @override
  String routesImportFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get routesImportGpx => 'Importar GPX';

  @override
  String routesImportSuccess(String name) {
    return 'Importado: $name';
  }

  @override
  String get routesInvalidGpxFile => 'Arquivo GPX inválido';

  @override
  String get routesNewRouteSubtitle => 'Comece a gravar sua trilha GPS';

  @override
  String get routesNewRouteTitle => 'Nova Rota';

  @override
  String get routesNotesHint => 'Condições da trilha, clima, etc.';

  @override
  String get routesNotesLabel => 'Notas (opcional)';

  @override
  String routesPointCount(int count) {
    return '$count pontos';
  }

  @override
  String routesPointsShort(int count) {
    return '$count pts';
  }

  @override
  String get routesRecordingLabel => 'Gravando';

  @override
  String get routesRouteNameHint => 'Caminhada matinal';

  @override
  String get routesRouteNameLabel => 'Nome da Rota';

  @override
  String get routesScreenTitle => 'Rotas';

  @override
  String routesShareText(String name) {
    return 'Rota: $name';
  }

  @override
  String get routesStart => 'Iniciar';

  @override
  String get routesStartRoute => 'Iniciar Rota';

  @override
  String get routesStopRecording => 'Parar';

  @override
  String get scannerAuthFailedError =>
      'Falha na autenticação. O dispositivo pode precisar ser pareado novamente. Vá em Ajustes > Bluetooth, esqueça o dispositivo Meshtastic e toque nele abaixo para reconectar.';

  @override
  String get scannerAutoReconnectDisabledSubtitle =>
      'Selecione um dispositivo abaixo para conectar manualmente.';

  @override
  String scannerAutoReconnectDisabledSubtitleWithDevice(String name) {
    return 'Selecione \"$name\" abaixo, ou ative a reconexão automática.';
  }

  @override
  String get scannerAutoReconnectDisabledTitle =>
      'Reconexão automática desativada';

  @override
  String get scannerAvailableDevices => 'Dispositivos Disponíveis';

  @override
  String get scannerBluetoothSettings => 'Configurações Bluetooth';

  @override
  String get scannerBluetoothSettingsOpenFailed =>
      'Não foi possível abrir as Configurações Bluetooth. Abra manualmente em Ajustes > Bluetooth.';

  @override
  String get scannerConnectDeviceTitle => 'Conectar Dispositivo';

  @override
  String get scannerConnectingStatus => 'Conectando...';

  @override
  String scannerConnectionFailedWithError(String error) {
    return 'Falha na conexão: $error';
  }

  @override
  String get scannerConnectionTimedOut =>
      'Tempo de conexão esgotado. O dispositivo pode estar fora de alcance, desligado ou conectado a outro telefone.';

  @override
  String get scannerCopyright =>
      '© 2026 Socialmesh. Todos os direitos reservados.';

  @override
  String get scannerDetailAddress => 'Endereço';

  @override
  String get scannerDetailBluetoothLowEnergy => 'Bluetooth de Baixa Energia';

  @override
  String get scannerDetailConnectionType => 'Tipo de Conexão';

  @override
  String get scannerDetailDeviceName => 'Nome do Dispositivo';

  @override
  String get scannerDetailManufacturerData => 'Dados do Fabricante';

  @override
  String get scannerDetailServiceUuids => 'UUIDs do Serviço';

  @override
  String get scannerDetailSignalStrength => 'Intensidade do Sinal';

  @override
  String get scannerDetailUsbSerial => 'USB Serial';

  @override
  String get scannerDeviceDisconnectedUnexpectedly =>
      'O dispositivo desconectou inesperadamente. Pode estar fora de alcance ou sem energia.';

  @override
  String get scannerDeviceNotFoundSubtitle =>
      'Se outro app está conectado a este dispositivo, desconecte-o primeiro. Apenas um app pode usar o Bluetooth por vez.';

  @override
  String scannerDeviceNotFoundTitle(String name) {
    return '$name não encontrado';
  }

  @override
  String scannerDevicesFoundCount(int count) {
    return '$count dispositivos encontrados';
  }

  @override
  String get scannerDevicesTitle => 'Dispositivos';

  @override
  String get scannerEnableAutoReconnectMessage =>
      'Isso conectará automaticamente ao seu último dispositivo usado sempre que você abrir o app.';

  @override
  String scannerEnableAutoReconnectMessageWithDevice(String name) {
    return 'Isso conectará automaticamente a \"$name\" agora e sempre que você abrir o app.';
  }

  @override
  String get scannerEnableAutoReconnectTitle => 'Ativar Reconexão Automática?';

  @override
  String get scannerEnableBluetoothHint =>
      'Verifique se o Bluetooth está ativado e se seu dispositivo Meshtastic está ligado';

  @override
  String get scannerEnableLabel => 'Ativar';

  @override
  String get scannerGattConnectionFailed =>
      'Falha na conexão. Isso pode acontecer se o dispositivo foi pareado anteriormente com outro app. Vá em Ajustes > Bluetooth, encontre o dispositivo Meshtastic, toque em \"Esquecer\" e tente novamente.';

  @override
  String get scannerLookingForDevices => 'Procurando dispositivos…';

  @override
  String get scannerMeshCoreConnectionFailed => 'Falha na conexão MeshCore';

  @override
  String scannerMeshCoreConnectionFailedWithError(String error) {
    return 'Falha na conexão MeshCore: $error';
  }

  @override
  String get scannerPairingInvalidatedError =>
      'Seu telefone removeu as informações de pareamento armazenadas para este dispositivo. Volte em Ajustes > Bluetooth, esqueça \"Meshtastic_XXXX\" e tente novamente.';

  @override
  String get scannerPinRequiredError =>
      'Falha na conexão — tente novamente e insira o PIN quando solicitado';

  @override
  String get scannerProtocolMeshCore => 'MeshCore';

  @override
  String get scannerProtocolMeshtastic => 'Meshtastic';

  @override
  String get scannerProtocolUnknown => 'Desconhecido';

  @override
  String get scannerRetryScan => 'Tentar Novamente';

  @override
  String get scannerScanningSubtitle => 'Procurando dispositivos Meshtastic...';

  @override
  String get scannerScanningTitle => 'Buscando dispositivos próximos';

  @override
  String get scannerTipNoOtherApps =>
      'Verifique se nenhum outro app (ex. app oficial Meshtastic) está conectado ao dispositivo';

  @override
  String get scannerTipNoOtherDevices =>
      'Verifique se nenhum outro telefone ou tablet já está conectado ao dispositivo via Bluetooth';

  @override
  String get scannerTransportBluetooth => 'Bluetooth';

  @override
  String get scannerTransportUsb => 'USB';

  @override
  String get scannerUnknownDeviceDescription =>
      'Este dispositivo não foi detectado como Meshtastic ou MeshCore.';

  @override
  String get scannerUnknownProtocol => 'Protocolo desconhecido';

  @override
  String get scannerUnsupportedDeviceMessage =>
      'Este dispositivo não pode ser conectado automaticamente. Apenas dispositivos Meshtastic e MeshCore são suportados.';

  @override
  String scannerVersionText(String version) {
    return 'Socialmesh v$version';
  }

  @override
  String scannerVersionTextShort(String version) {
    return 'Versão v$version';
  }

  @override
  String get searchProductsBrowseByCategory => 'Explorar por categoria';

  @override
  String get searchProductsClear => 'Limpar';

  @override
  String get searchProductsHint => 'Buscar dispositivos, módulos, antenas...';

  @override
  String searchProductsNoResults(String query) {
    return 'Nenhum resultado para \"$query\"';
  }

  @override
  String get searchProductsOutOfStock => 'Esgotado';

  @override
  String get searchProductsRecentSearches => 'Buscas recentes';

  @override
  String searchProductsResultCount(int count, String query) {
    return '$count resultados para \"$query\"';
  }

  @override
  String get searchProductsRetry => 'Tentar novamente';

  @override
  String get searchProductsSearchFailed => 'Busca falhou';

  @override
  String get searchProductsTrending => 'Em alta';

  @override
  String get searchProductsTryDifferent =>
      'Tente palavras-chave diferentes ou explore as categorias';

  @override
  String get sellerProfileAbout => 'Sobre';

  @override
  String get sellerProfileApplyCodeHint =>
      'Aplique este código no checkout da loja do vendedor';

  @override
  String get sellerProfileCodeCopied =>
      'Código copiado para a área de transferência';

  @override
  String get sellerProfileContactShipping => 'Contato e envio';

  @override
  String get sellerProfileDiscountExclusive =>
      'Código de desconto exclusivo para usuários Socialmesh';

  @override
  String get sellerProfileEmail => 'E-mail';

  @override
  String get sellerProfileErrorLoading => 'Erro ao carregar vendedor';

  @override
  String get sellerProfileFoundedStat => 'Fundado';

  @override
  String get sellerProfileGoBack => 'Voltar';

  @override
  String get sellerProfileNoProducts => 'Nenhum produto listado ainda';

  @override
  String sellerProfileNoSearchResults(String query) {
    return 'Nenhum produto corresponde a \"$query\"';
  }

  @override
  String get sellerProfileNotFound => 'Vendedor não encontrado';

  @override
  String get sellerProfileOfficialPartner => 'Parceiro oficial';

  @override
  String get sellerProfilePartnerDiscount => 'Desconto de parceiro';

  @override
  String sellerProfileProductsCount(int count) {
    return 'Produtos ($count)';
  }

  @override
  String get sellerProfileProductsStat => 'Produtos';

  @override
  String get sellerProfileRevealCode => 'Revelar código';

  @override
  String sellerProfileReviewCount(int count) {
    return '$count avaliações';
  }

  @override
  String get sellerProfileSalesStat => 'Vendas';

  @override
  String get sellerProfileSearchHint => 'Buscar produtos...';

  @override
  String get sellerProfileShipsTo => 'Envia para';

  @override
  String get sellerProfileTitle => 'Vendedor';

  @override
  String get sellerProfileCopyCodeTooltip => 'Copiar código';

  @override
  String get sellerProfileUnableToLoad =>
      'Não foi possível carregar os produtos';

  @override
  String get sellerProfileWebsite => 'Site';

  @override
  String get serialConfigBaudRate => 'Velocidade de Transmissão';

  @override
  String get serialConfigBaudRateSubtitle => 'Velocidade de comunicação serial';

  @override
  String get serialConfigEcho => 'Eco';

  @override
  String get serialConfigEchoSubtitle =>
      'Ecoar pacotes enviados de volta à porta serial';

  @override
  String get serialConfigEnabled => 'Serial habilitada';

  @override
  String get serialConfigEnabledSubtitle =>
      'Habilitar comunicação pela porta serial';

  @override
  String serialConfigGpioPin(int pin) {
    return 'Pino $pin';
  }

  @override
  String get serialConfigGpioUnset => 'Não definido';

  @override
  String get serialConfigModeCaltopoDesc =>
      'Formato CalTopo para aplicativos de mapeamento';

  @override
  String get serialConfigModeNmeaDesc => 'Saída NMEA GPS para aplicativos GPS';

  @override
  String get serialConfigModeProtoDesc =>
      'Protocolo binário Protobuf para acesso programático';

  @override
  String get serialConfigModeSimpleDesc =>
      'Saída serial simples para uso básico no terminal';

  @override
  String get serialConfigModeTextmsgDesc =>
      'Modo de mensagem de texto para comunicação estilo SMS';

  @override
  String get serialConfigOverrideConsole => 'Substituir console serial';

  @override
  String get serialConfigOverrideConsoleSubtitle =>
      'Usar módulo serial no lugar do console';

  @override
  String get serialConfigRxdGpio => 'Pino GPIO RXD';

  @override
  String get serialConfigRxdGpioSubtitle =>
      'Número do pino GPIO para recepção de dados';

  @override
  String get serialConfigSave => 'Salvar';

  @override
  String serialConfigSaveError(String error) {
    return 'Erro ao salvar configuração: $error';
  }

  @override
  String get serialConfigSaved => 'Configuração serial salva';

  @override
  String get serialConfigSectionBaudRate => 'Velocidade de Transmissão';

  @override
  String get serialConfigSectionGeneral => 'Geral';

  @override
  String get serialConfigSectionSerialMode => 'Modo serial';

  @override
  String get serialConfigSectionTimeout => 'Tempo Limite';

  @override
  String get serialConfigTimeout => 'Tempo Limite';

  @override
  String serialConfigTimeoutValue(int seconds) {
    return '$seconds segundos';
  }

  @override
  String get serialConfigTitle => 'Configuração serial';

  @override
  String get serialConfigTxdGpio => 'Pino GPIO TXD';

  @override
  String get serialConfigTxdGpioSubtitle =>
      'Número do pino GPIO para transmissão de dados';

  @override
  String settingsClearAllDataFailed(String error) {
    return 'Falha ao limpar alguns dados: $error';
  }

  @override
  String get settingsClearAllDataLabel => 'Limpar tudo';

  @override
  String get settingsClearAllDataMessage =>
      'Isso excluirá TODOS os dados do app: mensagens, nós, canais, configurações, chaves, sinais, favoritos, automações, widgets e preferências salvas. Esta ação não pode ser desfeita.';

  @override
  String get settingsClearAllDataSuccess =>
      'Todos os dados foram limpos com sucesso';

  @override
  String get settingsClearAllDataTitle => 'Limpar todos os dados';

  @override
  String get settingsClearMessagesLabel => 'Limpar';

  @override
  String get settingsClearMessagesMessage =>
      'Isso excluirá todas as mensagens armazenadas. Esta ação não pode ser desfeita.';

  @override
  String get settingsClearMessagesSuccess => 'Mensagens limpas';

  @override
  String get settingsClearMessagesTitle => 'Limpar mensagens';

  @override
  String get settingsDeviceInfoConnection => 'Conexão';

  @override
  String get settingsDeviceInfoDeviceName => 'Nome do dispositivo';

  @override
  String get settingsDeviceInfoHardware => 'Hardware';

  @override
  String get settingsDeviceInfoLongName => 'Nome longo';

  @override
  String get settingsDeviceInfoNodeNumber => 'Número do nó';

  @override
  String get settingsDeviceInfoNone => 'Nenhum';

  @override
  String get settingsDeviceInfoNotConnected => 'Não conectado';

  @override
  String get settingsDeviceInfoShortName => 'Nome curto';

  @override
  String get settingsDeviceInfoTitle => 'Informações do dispositivo';

  @override
  String get settingsDeviceInfoUnknown => 'Desconhecido';

  @override
  String get settingsDeviceInfoUserId => 'ID do usuário';

  @override
  String settingsErrorLoading(String error) {
    return 'Erro ao carregar configurações: $error';
  }

  @override
  String settingsForceSyncFailed(String error) {
    return 'Sincronização falhou: $error';
  }

  @override
  String get settingsForceSyncLabel => 'Sincronizar';

  @override
  String get settingsForceSyncMessage =>
      'Isso limpará todas as mensagens, nós e canais locais e ressincronizará tudo do dispositivo conectado.\n\nTem certeza de que deseja continuar?';

  @override
  String get settingsForceSyncNotConnected => 'Não conectado a um dispositivo';

  @override
  String get settingsForceSyncSuccess => 'Sincronização concluída';

  @override
  String get settingsForceSyncTitle => 'Forçar sincronização';

  @override
  String get settingsForceSyncingStatus => 'Sincronizando do dispositivo…';

  @override
  String get settingsHapticIntensityTitle => 'Intensidade do feedback tátil';

  @override
  String get settingsHapticMediumDescription =>
      'Feedback equilibrado para a maioria das interações';

  @override
  String get settingsHapticStrongDescription =>
      'Feedback forte para confirmação clara';

  @override
  String get settingsHapticSubtleDescription =>
      'Feedback sutil para um toque suave';

  @override
  String get settingsHelpTooltip => 'Ajuda';

  @override
  String settingsHistoryLimitOption(int limit) {
    return '$limit mensagens';
  }

  @override
  String get settingsHistoryLimitTitle => 'Limite do histórico de mensagens';

  @override
  String get settingsLoadingStatus => 'Carregando…';

  @override
  String get settingsMeshtasticGoBack => 'Voltar';

  @override
  String get settingsMeshtasticOfflineMessage =>
      'Este conteúdo requer conexão com a internet. Verifique sua conexão e tente novamente.';

  @override
  String get settingsMeshtasticRefresh => 'Atualizar';

  @override
  String get settingsMeshtasticUnableToLoad =>
      'Não foi possível carregar a página';

  @override
  String get settingsMeshtasticWebViewTitle => 'Meshtastic';

  @override
  String get settingsNoSettingsFound => 'Nenhuma configuração encontrada';

  @override
  String get settingsNotConfigured => 'Não configurado';

  @override
  String get settingsOpenSourceAppName => 'Socialmesh';

  @override
  String get settingsOpenSourceLegalese =>
      '© 2024 Socialmesh\n\nEste app utiliza software de código aberto. Veja abaixo a lista completa de licenças de terceiros.';

  @override
  String get settingsPremiumAllUnlocked => 'Todos os recursos desbloqueados!';

  @override
  String get settingsPremiumBadgeLocked => 'BLOQUEADO';

  @override
  String get settingsPremiumBadgeOwned => 'ADQUIRIDO';

  @override
  String get settingsPremiumBadgeTry => 'TESTAR';

  @override
  String settingsPremiumPartiallyUnlocked(int owned, int total) {
    return '$owned de $total desbloqueados';
  }

  @override
  String get settingsPremiumUnlockFeaturesTitle => 'Desbloquear recursos';

  @override
  String get settingsProfileLocalOnly => 'Apenas local';

  @override
  String get settingsProfileSubtitle => 'Configure seu perfil';

  @override
  String get settingsProfileSynced => 'Sincronizado';

  @override
  String get settingsProfileTitle => 'Perfil';

  @override
  String get settingsRegionConfigureSubtitle =>
      'Configurar frequência de rádio do dispositivo';

  @override
  String get settingsRemoteAdminConfigureTitle => 'Configurar dispositivo';

  @override
  String get settingsRemoteAdminConfiguringTitle => 'Configurando nó remoto';

  @override
  String get settingsRemoteAdminConnectedDevice => 'Dispositivo conectado';

  @override
  String settingsRemoteAdminNodeCount(int count) {
    return '$count nós';
  }

  @override
  String get settingsRemoteAdminWarning =>
      'A administração remota requer que o nó de destino tenha sua chave pública na lista de chaves Admin.';

  @override
  String get settingsResetLocalDataLabel => 'Redefinir';

  @override
  String get settingsResetLocalDataMessage =>
      'Isso limpará todas as mensagens e dados dos nós, forçando uma nova sincronização do dispositivo na próxima conexão.\n\nSuas configurações, tema e preferências serão mantidos.\n\nUse isso se os nós mostrarem status incorreto ou as mensagens parecerem erradas.';

  @override
  String get settingsResetLocalDataSuccess =>
      'Dados locais redefinidos. Reconecte para sincronizar dados atualizados.';

  @override
  String get settingsResetLocalDataTitle => 'Redefinir dados locais';

  @override
  String get settingsSearchAutoAcceptTransfersSubtitle =>
      'Aceitar automaticamente ofertas de arquivos recebidos';

  @override
  String get settingsSearchAutoAcceptTransfersTitle =>
      'Aceitar transferências automaticamente';

  @override
  String get settingsSearchAutomationsPackSubtitle =>
      'Ações e gatilhos automatizados';

  @override
  String get settingsSearchAutomationsPackTitle => 'Pacote de automações';

  @override
  String get settingsSearchCannedMessagesSubtitle =>
      'Mensagens pré-configuradas no dispositivo';

  @override
  String get settingsSearchCannedMessagesTitle => 'Mensagens predefinidas';

  @override
  String get settingsSearchChannelNotificationsSubtitle =>
      'Notificar para transmissões do canal';

  @override
  String get settingsSearchChannelNotificationsTitle =>
      'Notificações de mensagens do canal';

  @override
  String get settingsSearchClearAllDataSubtitle =>
      'Excluir mensagens, configurações e chaves';

  @override
  String get settingsSearchClearAllMessagesSubtitle =>
      'Excluir todas as mensagens armazenadas';

  @override
  String get settingsSearchClearAllMessagesTitle => 'Limpar todas as mensagens';

  @override
  String get settingsSearchCommentsSubtitle =>
      'Notificações push para comentários e @menções';

  @override
  String get settingsSearchDmNotificationsSubtitle =>
      'Notificar para mensagens privadas';

  @override
  String get settingsSearchDmNotificationsTitle =>
      'Notificações de mensagens diretas';

  @override
  String get settingsSearchExportDataSubtitle =>
      'Exportar mensagens e configurações';

  @override
  String get settingsSearchExportDataTitle => 'Exportar dados';

  @override
  String get settingsSearchFileTransferSubtitle =>
      'Enviar e receber pequenos arquivos via mesh';

  @override
  String get settingsSearchFileTransferTitle => 'Transferência de arquivos';

  @override
  String get settingsSearchForceSyncSubtitle =>
      'Forçar sincronização da configuração';

  @override
  String get settingsSearchForceSyncTitle => 'Forçar sincronização';

  @override
  String get settingsSearchHapticIntensitySubtitle =>
      'Feedback leve, médio ou forte';

  @override
  String get settingsSearchHint => 'Buscar configuração';

  @override
  String get settingsSearchHistoryLimitSubtitle =>
      'Máximo de mensagens a manter';

  @override
  String get settingsSearchHistoryLimitTitle =>
      'Limite do histórico de mensagens';

  @override
  String get settingsSearchIftttPackSubtitle =>
      'Integração com serviços externos';

  @override
  String get settingsSearchIftttPackTitle => 'Pacote IFTTT';

  @override
  String get settingsSearchTranslationPackTitle => 'Translation Pack';

  @override
  String get settingsSearchTranslationPackSubtitle =>
      'One-tap message translation';

  @override
  String get settingsSearchLikesSubtitle =>
      'Notificações push para curtidas em publicações';

  @override
  String get settingsSearchLinkedDevicesSubtitle =>
      'Dispositivos Meshtastic vinculados ao seu perfil';

  @override
  String get settingsSearchLinkedDevicesTitle => 'Dispositivos vinculados';

  @override
  String get settingsSearchNewFollowersSubtitle =>
      'Notificações push quando alguém segue você';

  @override
  String get settingsSearchNewNodesNotificationsSubtitle =>
      'Notificar quando novos nós entram na rede mesh';

  @override
  String get settingsSearchNewNodesNotificationsTitle =>
      'Notificações de novos nós';

  @override
  String get settingsSearchNotificationSoundSubtitle =>
      'Reproduzir som para notificações';

  @override
  String get settingsSearchNotificationSoundTitle => 'Som de notificação';

  @override
  String get settingsSearchNotificationVibrationSubtitle =>
      'Vibrar para notificações';

  @override
  String get settingsSearchNotificationVibrationTitle =>
      'Vibração de notificação';

  @override
  String get settingsSearchPremiumSubtitle =>
      'Toques, temas, automações, IFTTT, widgets';

  @override
  String get settingsSearchProfileSubtitle =>
      'Seu nome de exibição, avatar e bio';

  @override
  String get settingsSearchRegionSubtitle =>
      'Região de frequência de rádio do dispositivo';

  @override
  String get settingsSearchRegionTitle => 'Região';

  @override
  String get settingsSearchRemoteAdminSubtitle =>
      'Configurar nós remotos via admin PKI';

  @override
  String get settingsSearchRemoteAdminTitle => 'Administração remota';

  @override
  String get settingsSearchResetLocalDataSubtitle =>
      'Limpar todos os dados locais do app';

  @override
  String get settingsSearchResetLocalDataTitle => 'Redefinir dados locais';

  @override
  String get settingsSearchRingtonePackSubtitle =>
      'Sons de notificação personalizados';

  @override
  String get settingsSearchRingtonePackTitle => 'Pacote de toques';

  @override
  String get settingsSearchScanForDeviceSubtitle =>
      'Escanear código QR para configuração rápida';

  @override
  String get settingsSearchScanForDeviceTitle => 'Buscar dispositivo';

  @override
  String get settingsSearchTakGatewaySubtitle =>
      'URL do gateway, publicação de posição, indicativo';

  @override
  String get settingsSearchTakGatewayTitle => 'Gateway TAK';

  @override
  String get settingsSearchThemePackSubtitle =>
      'Cores de destaque e personalização visual';

  @override
  String get settingsSearchThemePackTitle => 'Pacote de temas';

  @override
  String get settingsSearchWidgetPackSubtitle => 'Widgets para a tela inicial';

  @override
  String get settingsSearchWidgetPackTitle => 'Pacote de widgets';

  @override
  String get settingsSectionAbout => 'SOBRE';

  @override
  String get settingsSectionAccount => 'CONTA';

  @override
  String get settingsSectionAnimations => 'ANIMAÇÕES';

  @override
  String get settingsSectionAppearance => 'APARÊNCIA';

  @override
  String get settingsSectionConnection => 'CONEXÃO';

  @override
  String get settingsSectionDataStorage => 'DADOS E ARMAZENAMENTO';

  @override
  String get settingsSectionDevice => 'DISPOSITIVO';

  @override
  String get settingsSectionFeedback => 'FEEDBACK';

  @override
  String get settingsSectionHapticFeedback => 'FEEDBACK TÁTIL';

  @override
  String get settingsSectionMessaging => 'MENSAGENS';

  @override
  String get settingsSectionModules => 'MÓDULOS';

  @override
  String get settingsSectionNotifications => 'NOTIFICAÇÕES';

  @override
  String get settingsSectionPremium => 'PREMIUM';

  @override
  String get settingsSectionRemoteAdmin => 'ADMINISTRAÇÃO REMOTA';

  @override
  String get settingsSectionSocialNotifications => 'NOTIFICAÇÕES SOCIAIS';

  @override
  String get settingsSectionTelemetryLogs => 'LOGS DE TELEMETRIA';

  @override
  String get settingsSectionTools => 'FERRAMENTAS';

  @override
  String get settingsSectionWhatsNew => 'NOVIDADES';

  @override
  String get settingsSocialCommentsSubtitle =>
      'Quando alguém comenta ou @menciona você';

  @override
  String get settingsSocialCommentsTitle => 'Comentários e menções';

  @override
  String get settingsSocialLikesSubtitle =>
      'Quando alguém curte suas publicações';

  @override
  String get settingsSocialLikesTitle => 'Curtidas';

  @override
  String get settingsSocialNewFollowersSubtitle =>
      'Quando alguém segue você ou envia uma solicitação';

  @override
  String get settingsSocialNewFollowersTitle => 'Novos seguidores';

  @override
  String get settingsSocialNotificationsLoading => 'Carregando…';

  @override
  String get settingsSocialNotificationsLoadingSubtitle =>
      'Buscando preferências de notificação';

  @override
  String settingsSocialmeshVersionSnackbar(String version) {
    return 'Socialmesh v$version';
  }

  @override
  String get settingsTile3dEffectsSubtitle =>
      'Transformações de perspectiva e efeitos de profundidade';

  @override
  String get settingsTile3dEffectsTitle => 'Efeitos 3D';

  @override
  String get settingsTileAirQualitySubtitle => 'Leituras de PM2.5, PM10, CO2';

  @override
  String get settingsTileAirQualityTitle => 'Qualidade do ar';

  @override
  String get settingsTileAmbientLightingSubtitle =>
      'Configure as definições de LED e RGB';

  @override
  String get settingsTileAmbientLightingTitle => 'Iluminação ambiente';

  @override
  String get settingsTileAppLogSubtitle =>
      'Visualize os logs de depuração do app';

  @override
  String get settingsTileAppLogTitle => 'Log do app';

  @override
  String get settingsTileAppearanceSubtitle =>
      'Fonte, tamanho do texto, formato de hora, densidade, contraste, movimento';

  @override
  String get settingsTileAppearanceTitle => 'Aparência e acessibilidade';

  @override
  String get settingsTileAutoReconnectSubtitle =>
      'Reconectar automaticamente ao último dispositivo';

  @override
  String get settingsTileAutoReconnectTitle => 'Reconexão automática';

  @override
  String get settingsTileBackgroundConnectionSubtitle =>
      'BLE em segundo plano, notificações e energia';

  @override
  String get settingsTileBackgroundConnectionTitle =>
      'Conexão em segundo plano';

  @override
  String get settingsTileBluetoothSubtitle =>
      'Modo de pareamento, configurações de PIN';

  @override
  String get settingsTileBluetoothTitle => 'Bluetooth';

  @override
  String get settingsTileCannedMessagesSubtitle =>
      'Configurações de mensagens predefinidas no dispositivo';

  @override
  String get settingsTileCannedMessagesTitle =>
      'Módulo de mensagens predefinidas';

  @override
  String get settingsTileChannelMessagesSubtitle =>
      'Notificar transmissões do canal';

  @override
  String get settingsTileChannelMessagesTitle => 'Mensagens do canal';

  @override
  String get settingsTileClearAllDataSubtitle =>
      'Excluir mensagens, configurações e chaves';

  @override
  String get settingsTileClearAllDataTitle => 'Limpar todos os dados';

  @override
  String get settingsTileClearMessageHistorySubtitle =>
      'Excluir todas as mensagens armazenadas';

  @override
  String get settingsTileClearMessageHistoryTitle =>
      'Limpar histórico de mensagens';

  @override
  String get settingsTileDetectionSensorLogsSubtitle =>
      'Histórico de eventos do sensor';

  @override
  String get settingsTileDetectionSensorLogsTitle =>
      'Logs do sensor de detecção';

  @override
  String get settingsTileDetectionSensorSubtitle =>
      'Configure sensores de movimento/porta baseados em GPIO';

  @override
  String get settingsTileDetectionSensorTitle => 'Sensor de detecção';

  @override
  String get settingsTileDeviceInfoSubtitle =>
      'Visualize detalhes do dispositivo conectado';

  @override
  String get settingsTileDeviceInfoTitle => 'Info do dispositivo';

  @override
  String get settingsTileDeviceManagementSubtitle =>
      'Reiniciar, desligar, restaurar padrão de fábrica';

  @override
  String get settingsTileDeviceManagementTitle =>
      'Gerenciamento do dispositivo';

  @override
  String get settingsTileDeviceMetricsSubtitle =>
      'Histórico de bateria, tensão, utilização';

  @override
  String get settingsTileDeviceMetricsTitle => 'Métricas do dispositivo';

  @override
  String get settingsTileDeviceRoleSubtitle =>
      'Configure o comportamento e função do dispositivo';

  @override
  String get settingsTileDeviceRoleTitle =>
      'Função e configurações do dispositivo';

  @override
  String get settingsTileDirectMessagesSubtitle =>
      'Notificar mensagens privadas';

  @override
  String get settingsTileDirectMessagesTitle => 'Mensagens diretas';

  @override
  String get settingsTileDisplaySettingsSubtitle =>
      'Timeout da tela, unidades, modo de exibição';

  @override
  String get settingsTileDisplaySettingsTitle => 'Configurações de exibição';

  @override
  String get settingsTileEnvironmentMetricsSubtitle =>
      'Logs de temperatura, umidade, pressão';

  @override
  String get settingsTileEnvironmentMetricsTitle => 'Métricas ambientais';

  @override
  String get settingsTileExportDataSubtitle =>
      'Exportar mensagens, telemetria, rotas';

  @override
  String get settingsTileExportDataTitle => 'Exportar dados';

  @override
  String get settingsTileExportMessagesSubtitle =>
      'Exportar mensagens em PDF ou CSV';

  @override
  String get settingsTileExportMessagesTitle => 'Exportar mensagens';

  @override
  String get settingsTileExternalNotificationSubtitle =>
      'Configure buzzer, LEDs e alertas de vibração';

  @override
  String get settingsTileExternalNotificationTitle => 'Notificação externa';

  @override
  String get settingsTileFirmwareUpdateSubtitle =>
      'Verificar atualizações de firmware do dispositivo';

  @override
  String get settingsTileFirmwareUpdateTitle => 'Atualização de firmware';

  @override
  String get settingsTileForceSyncSubtitle =>
      'Ressincronizar todos os dados do dispositivo conectado';

  @override
  String get settingsTileForceSyncTitle => 'Forçar sincronização';

  @override
  String get settingsTileGlyphMatrixSubtitle =>
      'Padrões de LED do Nothing Phone 3';

  @override
  String get settingsTileGlyphMatrixTitle => 'Teste de matriz de glifos';

  @override
  String get settingsTileGpsStatusSubtitle =>
      'Visualize informações detalhadas do GPS';

  @override
  String get settingsTileGpsStatusTitle => 'Status do GPS';

  @override
  String get settingsTileHapticFeedbackSubtitle =>
      'Feedback de vibração para interações';

  @override
  String get settingsTileHapticFeedbackTitle => 'Feedback tátil';

  @override
  String get settingsTileHelpCenterSubtitle =>
      'Guias interativos com Ico, seu guia mesh';

  @override
  String get settingsTileHelpCenterTitle => 'Central de ajuda';

  @override
  String get settingsTileHelpSupportSubtitle =>
      'FAQ, solução de problemas e contato';

  @override
  String get settingsTileHelpSupportTitle => 'Ajuda e suporte';

  @override
  String get settingsTileIntensityTitle => 'Intensidade';

  @override
  String get settingsTileListAnimationsSubtitle =>
      'Efeitos de deslizar e quicar nas listas';

  @override
  String get settingsTileListAnimationsTitle => 'Animações de lista';

  @override
  String settingsTileMessageHistorySubtitle(int count) {
    return '$count mensagens armazenadas';
  }

  @override
  String get settingsTileMessageHistoryTitle => 'Histórico de mensagens';

  @override
  String get settingsTileMqttSubtitle => 'Configure a ponte mesh-internet';

  @override
  String get settingsTileMqttTitle => 'MQTT';

  @override
  String get settingsTileMyBugReportsNotSignedIn =>
      'Faça login para acompanhar seus relatórios e receber respostas';

  @override
  String get settingsTileMyBugReportsSubtitle =>
      'Visualize seus relatórios e respostas';

  @override
  String get settingsTileMyBugReportsTitle => 'Meus relatórios de bugs';

  @override
  String get settingsTileNetworkSubtitle =>
      'Configurações de WiFi, Ethernet, NTP';

  @override
  String get settingsTileNetworkTitle => 'Rede';

  @override
  String get settingsTileNewNodesSubtitle =>
      'Notificar quando novos nós entram na mesh';

  @override
  String get settingsTileNewNodesTitle => 'Novos nós';

  @override
  String get settingsTileOpenSourceSubtitle =>
      'Bibliotecas de terceiros e atribuições';

  @override
  String get settingsTileOpenSourceTitle => 'Licenças open source';

  @override
  String get settingsTilePaxCounterLogsSubtitle =>
      'Histórico de detecção de dispositivos';

  @override
  String get settingsTilePaxCounterLogsTitle => 'Logs do PAX Counter';

  @override
  String get settingsTilePaxCounterSubtitle =>
      'Configurações de detecção de dispositivos WiFi/BLE';

  @override
  String get settingsTilePaxCounterTitle => 'Contador PAX';

  @override
  String get settingsTilePositionHistorySubtitle => 'Logs de posição GPS';

  @override
  String get settingsTilePositionHistoryTitle => 'Histórico de posições';

  @override
  String get settingsTilePositionSubtitle =>
      'Modo GPS, intervalos de transmissão, posição fixa';

  @override
  String get settingsTilePositionTitle => 'Posição e GPS';

  @override
  String get settingsTilePowerManagementSubtitle =>
      'Economia de energia, configurações de suspensão';

  @override
  String get settingsTilePowerManagementTitle => 'Gerenciamento de energia';

  @override
  String get settingsTilePrivacyPolicySubtitle => 'Como tratamos seus dados';

  @override
  String get settingsTilePrivacyPolicyTitle => 'Política de privacidade';

  @override
  String get settingsTilePrivacySubtitle =>
      'Análise, relatórios de falhas e controles de dados';

  @override
  String get settingsTilePrivacyTitle => 'Privacidade';

  @override
  String get settingsTileProvideLocationSubtitle =>
      'Enviar GPS do telefone para a mesh em dispositivos sem hardware GPS';

  @override
  String get settingsTileProvideLocationTitle =>
      'Fornecer localização do telefone';

  @override
  String get settingsLocationServicesDisabled =>
      'Location services are disabled. Enable them in your device settings.';

  @override
  String get settingsLocationPermissionDenied =>
      'Location permission denied. Grant location access to share your position.';

  @override
  String get settingsLocationPermissionPermanentlyDenied =>
      'Location permission permanently denied. Enable in your device settings.';

  @override
  String get settingsLocationOpenSettings => 'Open Settings';

  @override
  String get settingsTilePushNotificationsSubtitle =>
      'Controle principal de todas as notificações';

  @override
  String get settingsTilePushNotificationsTitle => 'Notificações push';

  @override
  String get settingsTileQuickResponsesSubtitle =>
      'Gerencie respostas predefinidas para mensagens rápidas';

  @override
  String get settingsTileQuickResponsesTitle => 'Respostas rápidas';

  @override
  String get settingsTileRadioConfigSubtitle =>
      'Configurações LoRa, preset do modem, potência';

  @override
  String get settingsTileRadioConfigTitle => 'Configuração do rádio';

  @override
  String get settingsTileRangeTestSubtitle =>
      'Teste o alcance do sinal com outros nós';

  @override
  String get settingsTileRangeTestTitle => 'Teste de alcance';

  @override
  String get settingsTileRegionTitle => 'Região / Frequência';

  @override
  String get settingsTileResetLocalDataSubtitle =>
      'Limpar mensagens e nós, manter configurações';

  @override
  String get settingsTileResetLocalDataTitle => 'Redefinir dados locais';

  @override
  String get settingsTileRoutesSubtitle => 'Grave e gerencie rotas GPS';

  @override
  String get settingsTileRoutesTitle => 'Rotas';

  @override
  String get settingsTileScanQrCodeSubtitle =>
      'Importar nós, canais ou automações';

  @override
  String get settingsTileScanQrCodeTitle => 'Escanear código QR';

  @override
  String get settingsTileSecuritySubtitle =>
      'Controles de acesso, modo gerenciado';

  @override
  String get settingsTileSecurityTitle => 'Segurança';

  @override
  String get settingsTileSerialSubtitle => 'Configuração da porta serial';

  @override
  String get settingsTileSerialTitle => 'Serial';

  @override
  String get settingsTileShakeToReportSubtitle =>
      'Agite o dispositivo para abrir o relatório de bugs';

  @override
  String get settingsTileShakeToReportTitle => 'Agitar para relatar um bug';

  @override
  String get settingsTileSocialmeshSubtitle => 'App companion Meshtastic';

  @override
  String get settingsTileSocialmeshTitle => 'Socialmesh';

  @override
  String get settingsTileSoundSubtitle => 'Reproduzir som com notificações';

  @override
  String get settingsTileSoundTitle => 'Som';

  @override
  String get settingsTileStoreForwardSubtitle =>
      'Armazene e retransmita mensagens para nós offline';

  @override
  String get settingsTileStoreForwardTitle => 'Store & Forward';

  @override
  String get settingsTileTelemetryIntervalsSubtitle =>
      'Configure a frequência de atualização da telemetria';

  @override
  String get settingsTileTelemetryIntervalsTitle => 'Intervalos de telemetria';

  @override
  String get settingsTileTermsOfServiceSubtitle => 'Termos e condições legais';

  @override
  String get settingsTileTermsOfServiceTitle => 'Termos de serviço';

  @override
  String get settingsTileTracerouteHistorySubtitle =>
      'Logs de análise de caminhos de rede';

  @override
  String get settingsTileTracerouteHistoryTitle => 'Histórico de traceroute';

  @override
  String get settingsTileTrafficManagementSubtitle =>
      'Otimização e filtragem de tráfego mesh';

  @override
  String get settingsTileTrafficManagementTitle => 'Gerenciamento de tráfego';

  @override
  String get settingsTileVibrationSubtitle => 'Vibrar com notificações';

  @override
  String get settingsTileVibrationTitle => 'Vibração';

  @override
  String get settingsTileWhatsNewSubtitle =>
      'Veja recursos e atualizações recentes';

  @override
  String get settingsTileWhatsNewTitle => 'Novidades';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsTryDifferentSearch => 'Tente um termo de busca diferente';

  @override
  String settingsVersionString(String version) {
    return 'Versão $version';
  }

  @override
  String get shopAdminDashboardAccessDenied => 'Acesso negado';

  @override
  String get shopAdminDashboardAccessRequired => 'Acesso de admin necessário';

  @override
  String shopAdminDashboardActiveCount(int count) {
    return '$count ativos';
  }

  @override
  String get shopAdminDashboardAddProduct => 'Adicionar produto';

  @override
  String get shopAdminDashboardAddSeller => 'Adicionar vendedor';

  @override
  String get shopAdminDashboardError => 'Erro';

  @override
  String get shopAdminDashboardEstRevenue => 'Receita est.';

  @override
  String get shopAdminDashboardFeatured => 'Produtos em destaque';

  @override
  String get shopAdminDashboardFeaturedSubtitle =>
      'Gerencie a ordem de exibição dos produtos em destaque';

  @override
  String get shopAdminDashboardInactive => 'Inativo';

  @override
  String get shopAdminDashboardManagement => 'Gerenciamento';

  @override
  String get shopAdminDashboardNoPermission =>
      'Você não tem permissão para acessar esta área.';

  @override
  String get shopAdminDashboardOutOfStock => 'Fora de estoque';

  @override
  String get shopAdminDashboardProducts => 'Produtos';

  @override
  String get shopAdminDashboardProductsSubtitle =>
      'Gerencie todas as listagens de produtos';

  @override
  String get shopAdminDashboardQuickActions => 'Ações rápidas';

  @override
  String get shopAdminDashboardRefresh => 'Atualizar';

  @override
  String get shopAdminDashboardReviews => 'Avaliações';

  @override
  String get shopAdminDashboardReviewsMgmt => 'Avaliações';

  @override
  String get shopAdminDashboardReviewsSubtitle =>
      'Modere as avaliações de produtos';

  @override
  String get shopAdminDashboardSellers => 'Vendedores';

  @override
  String get shopAdminDashboardSellersSubtitle =>
      'Gerencie perfis de vendedores e parcerias';

  @override
  String get shopAdminDashboardTitle => 'Admin da loja';

  @override
  String get shopAdminDashboardTotalProducts => 'Total de produtos';

  @override
  String get shopAdminDashboardTotalSales => 'Total de vendas';

  @override
  String get shopAdminDashboardTotalSellers => 'Total de vendedores';

  @override
  String get shopAdminDashboardTotalViews => 'Total de visualizações';

  @override
  String get shopFavoritesEmpty => 'Nenhum favorito ainda';

  @override
  String get shopFavoritesEmptySubtitle =>
      'Toque no ícone de coração nos produtos para salvá-los';

  @override
  String get shopFavoritesErrorLoading => 'Erro ao carregar favoritos';

  @override
  String get shopFavoritesInStock => 'Em estoque';

  @override
  String get shopFavoritesOutOfStock => 'Fora de estoque';

  @override
  String get shopFavoritesProductRemoved => 'Produto não disponível';

  @override
  String get shopFavoritesRetry => 'Tentar novamente';

  @override
  String get shopFavoritesSignIn => 'Faça login para salvar favoritos';

  @override
  String get shopFavoritesSignInSubtitle =>
      'Seus dispositivos favoritos aparecerão aqui';

  @override
  String get shopFavoritesTitle => 'Favoritos';

  @override
  String get shopFavoritesUnableToLoad => 'Não foi possível carregar o produto';

  @override
  String get shopModelBandAu915 => 'AU 915MHz';

  @override
  String get shopModelBandAu915Range => '915-928 MHz';

  @override
  String get shopModelBandCn470 => 'CN 470MHz';

  @override
  String get shopModelBandCn470Range => '470-510 MHz';

  @override
  String get shopModelBandEu868 => 'EU 868MHz';

  @override
  String get shopModelBandEu868Range => '863-870 MHz';

  @override
  String get shopModelBandIn865 => 'IN 865MHz';

  @override
  String get shopModelBandIn865Range => '865-867 MHz';

  @override
  String get shopModelBandJp920 => 'JP 920MHz';

  @override
  String get shopModelBandJp920Range => '920-925 MHz';

  @override
  String get shopModelBandKr920 => 'KR 920MHz';

  @override
  String get shopModelBandKr920Range => '920-923 MHz';

  @override
  String get shopModelBandMulti => 'Multi-banda';

  @override
  String get shopModelBandMultiRange => 'Múltiplas frequências';

  @override
  String get shopModelBandUs915 => 'US 915MHz';

  @override
  String get shopModelBandUs915Range => '902-928 MHz';

  @override
  String get shopModelCategoryAccessories => 'Acessórios';

  @override
  String get shopModelCategoryAccessoriesDescription =>
      'Cabos, baterias e mais';

  @override
  String get shopModelCategoryAntennas => 'Antenas';

  @override
  String get shopModelCategoryAntennasDescription => 'Antenas e acessórios RF';

  @override
  String get shopModelCategoryEnclosures => 'Gabinetes';

  @override
  String get shopModelCategoryEnclosuresDescription => 'Cases e gabinetes';

  @override
  String get shopModelCategoryKits => 'Kits';

  @override
  String get shopModelCategoryKitsDescription => 'Kits DIY e pacotes';

  @override
  String get shopModelCategoryModules => 'Módulos';

  @override
  String get shopModelCategoryModulesDescription =>
      'Módulos e placas adicionais';

  @override
  String get shopModelCategoryNodes => 'Nós';

  @override
  String get shopModelCategoryNodesDescription =>
      'Dispositivos Meshtastic completos';

  @override
  String get shopModelCategorySolar => 'Solar';

  @override
  String get shopModelCategorySolarDescription =>
      'Painéis solares e soluções de energia';

  @override
  String shopModelPriceFrom(String price) {
    return 'A partir de $price';
  }

  @override
  String get showcaseCardAmplify => 'Amplie seu alcance';

  @override
  String get showcaseCardBroadcast => 'TRANSMISSÃO';

  @override
  String get showcaseCardConnected => 'Conectado à rede';

  @override
  String get showcaseCardEncrypted => 'Criptografia ponta a ponta';

  @override
  String get showcaseCardMeshNetwork => 'REDE MESH';

  @override
  String get showcaseCardNodeOnline => 'NÓ ONLINE';

  @override
  String get showcaseCardOffGrid => 'Comunicação off-grid';

  @override
  String get showcaseCardReachEveryone => 'Alcance todos';

  @override
  String get showcaseCardSecureChannel => 'CANAL SEGURO';

  @override
  String get showcaseCardSignalBoost => 'REFORÇO DE SINAL';

  @override
  String get showcaseResetAllCards => 'Redefinir todas as cartas';

  @override
  String get showcaseSnapEffectTitle => 'Efeito Snap';

  @override
  String get showcaseTapInstruction =>
      'Toque em uma carta para desintegrá-la (estilo Thanos)';

  @override
  String get sigilStageHeraldic => 'Heráldico';

  @override
  String get sigilStageInscribed => 'Inscrito';

  @override
  String get sigilStageLegacy => 'Legado';

  @override
  String get sigilStageMarked => 'Marcado';

  @override
  String get sigilStageSeed => 'Semente';

  @override
  String get signalAcquiringDeviceLocation =>
      'Obtendo localização do dispositivo...';

  @override
  String signalActiveCount(int count) {
    return '$count ativos';
  }

  @override
  String signalActiveDays(int days) {
    return 'Ativo ${days}d';
  }

  @override
  String signalActiveHours(int hours) {
    return 'Ativo ${hours}h';
  }

  @override
  String signalActiveMinutes(int minutes) {
    return 'Ativo ${minutes}m';
  }

  @override
  String get signalActiveNow => 'Ativo agora';

  @override
  String get signalAddLocation => 'Adicionar localização';

  @override
  String get signalAddPhotos => 'Adicionar fotos';

  @override
  String get signalAnonAuthor => 'Anónimo';

  @override
  String get signalAnonymous => 'Anônimo';

  @override
  String get signalAnonymousFeed => 'Anônimo';

  @override
  String signalApproxArea(int radiusMeters) {
    return 'Área aprox. (~${radiusMeters}m)';
  }

  @override
  String get signalAttachFile => 'Anexar arquivo';

  @override
  String get signalBackNearby => 'Voltar para próximos';

  @override
  String get signalBeFirstToRespond =>
      'Seja o primeiro a responder a este sinal';

  @override
  String get signalBleNoMeshTrafficIos =>
      'Conectado via BLE mas nenhum tráfego mesh detectado. No iOS, o modo avião pode bloquear o tráfego BLE mesmo quando conectado. Desative o modo avião ou alterne o Bluetooth.';

  @override
  String get signalBroadcastYourSignal => 'Transmita seu sinal';

  @override
  String get signalBroadcastingOverMesh => 'Transmitindo pela rede mesh...';

  @override
  String get signalCancel => 'Cancelar';

  @override
  String get signalChooseFromGallery => 'Escolher da galeria';

  @override
  String get signalCloudBadge => 'Nuvem';

  @override
  String get signalCloudFeaturesUnavailable => 'Recursos cloud indisponíveis.';

  @override
  String signalCommentCount(int count) {
    return '$count comentários';
  }

  @override
  String get signalCommentReported => 'Comentário denunciado. Obrigado.';

  @override
  String get signalConnectToAddLocation =>
      'Conecte um dispositivo para adicionar localização ao seu sinal.';

  @override
  String get signalConnectToGoActive =>
      'Conecte um dispositivo para ficar ativo';

  @override
  String get signalConnectToSend => 'Conecte um dispositivo para enviar sinais';

  @override
  String get signalConversation => 'Conversa';

  @override
  String get signalCreateFailed => 'Falha ao criar sinal';

  @override
  String get signalCurrentLocation => 'Localização atual';

  @override
  String get signalDelete => 'Excluir';

  @override
  String get signalDeleteMessage => 'Este sinal desaparecerá imediatamente.';

  @override
  String get signalDeleteTitle => 'Excluir sinal?';

  @override
  String get signalDetailTitle => 'Sinal';

  @override
  String get signalDeviceNotConnected => 'Dispositivo não conectado';

  @override
  String get signalDiscardConfirm => 'Descartar';

  @override
  String get signalDiscardMessage => 'Seu rascunho será perdido.';

  @override
  String get signalDiscardTitle => 'Descartar sinal?';

  @override
  String get signalDuration => 'Duração do sinal';

  @override
  String get signalDurationSubtitle => 'Quanto tempo até seu sinal desaparecer';

  @override
  String get signalEmptyTagline1 =>
      'Nada ativo aqui no momento.\nSinais aparecem quando alguém próximo fica ativo.';

  @override
  String get signalEmptyTagline2 =>
      'Sinais são mesh-first e efêmeros.\nDesaparecem quando o temporizador termina.';

  @override
  String get signalEmptyTagline3 =>
      'Compartilhe um status rápido ou foto.\nNós próximos verão em tempo real.';

  @override
  String get signalEmptyTagline4 =>
      'Fique ativo para transmitir sua presença.\nOff-grid, dispositivo a dispositivo.';

  @override
  String get signalEmptyTitleKeyword => 'sinais';

  @override
  String get signalEmptyTitlePrefix => 'Nenhum ';

  @override
  String get signalEmptyTitleSuffix => ' ativo por perto';

  @override
  String get signalEnableGpsOrFixedPosition =>
      'O dispositivo ainda não tem localização. Ative o GPS ou defina uma posição fixa.';

  @override
  String get signalExpiredBadge => 'Expirado';

  @override
  String get signalFaded => 'Desvanecido';

  @override
  String get signalFadesIn => 'Desaparece em';

  @override
  String signalFadesInDays(int days) {
    return 'Desaparece em ${days}d';
  }

  @override
  String signalFadesInHours(int hours) {
    return 'Desaparece em ${hours}h';
  }

  @override
  String signalFadesInMinutes(int minutes) {
    return 'Desaparece em ${minutes}m';
  }

  @override
  String signalFadesInMinutesSeconds(int minutes, int seconds) {
    return 'Desaparece em ${minutes}m ${seconds}s';
  }

  @override
  String signalFadesInSeconds(int seconds) {
    return 'Desaparece em ${seconds}s';
  }

  @override
  String get signalFallbackContent => 'Sinal';

  @override
  String signalFileTooLarge(int size) {
    return 'Arquivo muito grande. A transferência mesh é limitada a $size KB.';
  }

  @override
  String get signalFileTransferFailed =>
      'Falha ao iniciar transferência de arquivo';

  @override
  String get signalFileTransfers => 'Transferências de arquivos';

  @override
  String get signalFilterAll => 'Todos';

  @override
  String get signalFilterExpiring => 'Expirando';

  @override
  String get signalFilterHidden => 'Ocultos';

  @override
  String get signalFilterLocation => 'Localização';

  @override
  String get signalFilterMedia => 'Mídia';

  @override
  String get signalFilterMesh => 'Mesh';

  @override
  String get signalFilterNearby => 'Próximos';

  @override
  String get signalFilterReplies => 'Respostas';

  @override
  String get signalFilterSaved => 'Salvos';

  @override
  String get signalFitAllSignals => 'Ajustar todos os sinais';

  @override
  String get signalGetLocationFailed => 'Falha ao obter localização';

  @override
  String get signalGoActive => 'Ficar ativo';

  @override
  String get signalGoActiveAction => 'Ficar ativo';

  @override
  String get signalHasFaded => 'Este sinal desapareceu';

  @override
  String get signalHelp => 'Ajuda';

  @override
  String get signalHidden => 'Sinal oculto';

  @override
  String get signalHide => 'Ocultar';

  @override
  String signalHopSingular(int count) {
    return '$count salto';
  }

  @override
  String signalHopsBadge(int count) {
    return '$count saltos';
  }

  @override
  String signalHopsPlural(int count) {
    return '$count saltos';
  }

  @override
  String get signalImageBlockedSingular =>
      'A imagem viola as diretrizes de conteúdo e foi bloqueada';

  @override
  String signalImagesAddedCount(int passedCount) {
    return '$passedCount imagens adicionadas';
  }

  @override
  String signalImagesBlockedAndAdded(int failedCount, int passedCount) {
    return '$failedCount imagens bloqueadas, $passedCount adicionadas';
  }

  @override
  String signalImagesBlockedPlural(int failedCount) {
    return '$failedCount imagens bloqueadas pelas diretrizes de conteúdo';
  }

  @override
  String get signalImagesHiddenOffline =>
      'Imagens ocultas enquanto offline. Retornarão quando estiver online.';

  @override
  String get signalImagesRequireInternet =>
      'Imagens requerem internet. Imagens removidas.';

  @override
  String get signalImagesRestored => 'Imagens restauradas!';

  @override
  String get signalIntentLabel => 'Intenção';

  @override
  String get signalIosAirplaneModeWarning =>
      'O modo avião do iOS pode pausar o tráfego mesh BLE mesmo quando conectado. Se os sinais pararem, desative o modo avião ou alterne o Bluetooth.';

  @override
  String get signalKeepEditing => 'Continuar editando';

  @override
  String get signalLegendFiveMin => '< 5 min';

  @override
  String get signalLegendOverTwoHrs => '> 2 hrs';

  @override
  String get signalLegendThirtyMin => '< 30 min';

  @override
  String get signalLegendTwoHrs => '< 2 hrs';

  @override
  String get signalLetOthersKnowIntent => 'Diga aos outros por que está ativo';

  @override
  String get signalLoadingComments => 'Carregando comentários...';

  @override
  String get signalLocal => 'Local';

  @override
  String get signalLocalBadge => 'Local';

  @override
  String get signalLocalBadgeGallery => 'Local';

  @override
  String get signalLocationBadge => 'Localização';

  @override
  String signalLocationPrivacyNote(int radiusMeters) {
    return 'A localização do sinal usa a posição do dispositivo mesh, arredondada para ~${radiusMeters}m.';
  }

  @override
  String get signalLocationUnavailableSent =>
      'Localização indisponível, enviado sem localização.';

  @override
  String signalMaxFileSize(int size) {
    return 'Máx. $size KB';
  }

  @override
  String signalMaxImagesAllowed(int maxImages) {
    return 'Máximo de $maxImages imagens permitidas';
  }

  @override
  String get signalMeshOnlyDebugBanner =>
      'Modo debug somente mesh ativado. Sinais usam apenas DB local + mesh.';

  @override
  String get signalMeshOnlyDebugCloudDisabled =>
      'Modo debug somente mesh ativado. Recursos cloud desativados.';

  @override
  String get signalNoCommentsYet => 'Nenhum comentário ainda';

  @override
  String get signalNoDeviceConnectedTooltip => 'Nenhum dispositivo conectado';

  @override
  String get signalNoDeviceLocation =>
      'Nenhuma localização de dispositivo conectado disponível';

  @override
  String get signalNoFilterMatch => 'Nenhum sinal corresponde a este filtro';

  @override
  String get signalNoIntent => 'Sem intenção';

  @override
  String get signalNoLocationDescription =>
      'Sinais aparecerão aqui quando incluírem coordenadas GPS';

  @override
  String get signalNoLocationTitle => 'Nenhum sinal com localização';

  @override
  String get signalNoSignals => 'Nenhum sinal';

  @override
  String get signalOfflineCloudUnavailable =>
      'Offline: imagens e recursos cloud indisponíveis.';

  @override
  String signalOnMapCount(int count) {
    return '$count no mapa';
  }

  @override
  String get signalOriginCloud => 'Nuvem';

  @override
  String get signalOriginMesh => 'Mesh';

  @override
  String signalPeopleActiveCount(int count) {
    return '$count pessoas ativas';
  }

  @override
  String get signalProcessingImage => 'Processando imagem...';

  @override
  String get signalProfile => 'Perfil';

  @override
  String get signalRemoveLocation => 'Remover localização';

  @override
  String get signalRemoveVoteFailed => 'Falha ao remover voto';

  @override
  String get signalRemovedFromSaved => 'Removido dos salvos';

  @override
  String get signalReplyAction => 'Responder';

  @override
  String signalReplyWithCount(int count) {
    return 'Responder ($count)';
  }

  @override
  String signalReplyingTo(String author) {
    return 'Respondendo a $author';
  }

  @override
  String get signalReport => 'Denunciar';

  @override
  String get signalReportCopyright => 'Violação de direitos autorais';

  @override
  String signalReportFailed(String error) {
    return 'Falha ao denunciar: $error';
  }

  @override
  String get signalReportHarassment => 'Assédio ou bullying';

  @override
  String get signalReportNudity => 'Nudez ou conteúdo sexual';

  @override
  String get signalReportOther => 'Outro';

  @override
  String get signalReportSpam => 'Spam ou enganoso';

  @override
  String get signalReportSubmitted => 'Denúncia enviada. Obrigado.';

  @override
  String get signalReportViolence => 'Violência ou conteúdo perigoso';

  @override
  String get signalRespondToSignalHint => 'Responda a este sinal...';

  @override
  String get signalRestore => 'Restaurar';

  @override
  String get signalRestored => 'Sinal restaurado';

  @override
  String get signalRetrievingDeviceLocation =>
      'Obtendo localização do dispositivo...';

  @override
  String get signalSaved => 'Sinal salvo';

  @override
  String get signalSavedBadge => 'Salvo';

  @override
  String get signalSearchHint => 'Buscar sinais';

  @override
  String signalSeenCount(String formattedCount) {
    return 'Visto por $formattedCount';
  }

  @override
  String get signalSelectUpToFourPhotos => 'Selecione até 4 fotos';

  @override
  String get signalSendASignal => 'Enviar um sinal...';

  @override
  String get signalSendButton => 'Enviar sinal';

  @override
  String get signalSendResponseFailed => 'Falha ao enviar resposta';

  @override
  String get signalSendSignal => 'Enviar sinal';

  @override
  String get signalSending => 'Enviando...';

  @override
  String get signalSendingLabel => 'Enviando...';

  @override
  String get signalSent => 'Sinal enviado';

  @override
  String get signalSettings => 'Configurações';

  @override
  String get signalShortStatusHint => 'ex. \"Na trilha perto do cume\"';

  @override
  String get signalShortStatusOptional => 'Status curto (opcional)';

  @override
  String get signalShowAll => 'Mostrar todos os sinais';

  @override
  String get signalSignIn => 'Entrar';

  @override
  String get signalSignInForCloudFeatures =>
      'Entre para ativar imagens e recursos cloud.';

  @override
  String get signalSignInForImagesAndComments =>
      'Entre para imagens e comentários';

  @override
  String get signalSignInRequiredToComment => 'Login necessário para comentar';

  @override
  String get signalSignInToViewMedia => 'Entre para ver a mídia anexada';

  @override
  String get signalSignInToVote => 'Entre para votar nas respostas';

  @override
  String signalSignalsNearbyCount(int count) {
    return '$count sinais próximos';
  }

  @override
  String get signalSomeone => 'Alguém';

  @override
  String get signalSortByProximity => 'Por proximidade';

  @override
  String get signalSortClosest => 'Mais próximos';

  @override
  String get signalSortExpiring => 'Expirando';

  @override
  String get signalSortExpiringSoon => 'Expirando em breve';

  @override
  String get signalSortMostRecent => 'Mais recentes';

  @override
  String get signalSortNewest => 'Mais novos';

  @override
  String get signalSwipeSave => 'Salvar';

  @override
  String get signalSwipeUnsave => 'Remover';

  @override
  String get signalSyncingMedia => 'Sincronizando mídia';

  @override
  String get signalTakePhoto => 'Tirar foto';

  @override
  String get signalTapToSet => 'Toque para definir';

  @override
  String get signalTapToView => 'Toque para ver';

  @override
  String get signalTemporaryBanner =>
      'Sinais são temporários. Eles desaparecem automaticamente e existem apenas enquanto ativos.';

  @override
  String signalTimeDaysAgo(int days) {
    return '${days}d atrás';
  }

  @override
  String signalTimeHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String get signalTimeJustNow => 'Agora mesmo';

  @override
  String signalTimeMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String get signalTimeNowCompact => 'agora';

  @override
  String signalTimeWeeksAgo(int weeks) {
    return '${weeks}sem atrás';
  }

  @override
  String signalTtlDaysLeft(int days) {
    return '${days}d restantes';
  }

  @override
  String get signalTtlExpired => 'Expirado';

  @override
  String signalTtlHoursLeft(int hours) {
    return '${hours}h restantes';
  }

  @override
  String signalTtlMinutesLeft(int minutes) {
    return '${minutes}m restantes';
  }

  @override
  String signalTtlSecondsLeft(int seconds) {
    return '${seconds}s restantes';
  }

  @override
  String get signalUnknownAuthor => 'Desconhecido';

  @override
  String get signalUseCamera => 'Usar câmera';

  @override
  String get signalValidateImagesFailed => 'Falha ao validar imagens';

  @override
  String signalValidatingImages(int count) {
    return 'Validando $count imagens...';
  }

  @override
  String get signalViewButton => 'Ver';

  @override
  String get signalViewGallery => 'Ver galeria';

  @override
  String get signalViewGrid => 'Visualização em grade';

  @override
  String get signalViewList => 'Visualização em lista';

  @override
  String get signalViewLocation => 'Ver localização';

  @override
  String get signalViewMap => 'Visualização em mapa';

  @override
  String get signalVoteFailed => 'Falha ao enviar voto';

  @override
  String get signalWhatAreYouSignaling => 'O que você está sinalizando?';

  @override
  String get signalWhyReportComment =>
      'Por que você está denunciando este comentário?';

  @override
  String get signalWhyReportSignal =>
      'Por que você está denunciando este sinal?';

  @override
  String get signalWriteReplyHint => 'Escreva uma resposta...';

  @override
  String get signalYouBadge => 'você';

  @override
  String get signalYourIntent => 'Sua intenção';

  @override
  String get signalYourResponsibility => 'Sua responsabilidade';

  @override
  String get signalsFadeAutomatically =>
      'Sinais desaparecem automaticamente. Apenas os ainda ativos podem ser vistos.';

  @override
  String get signalsFeedTitle => 'Sinais';

  @override
  String get signalsPanelTitle => 'Sinais';

  @override
  String get socialAboutSensitiveContent => 'Sobre conteúdo sensível';

  @override
  String get socialAccountGoodStanding => 'Conta em boa situação';

  @override
  String get socialAccountGoodStandingDesc =>
      'Você não tem avisos ou penalidades ativos.';

  @override
  String get socialAccountGoodStandingLabel => 'Em boa situação';

  @override
  String get socialAccountMaxStrikes => 'Penalidades máximas';

  @override
  String get socialAccountRecentActivity => 'Atividade recente';

  @override
  String get socialAccountStatusActive => 'Ativo';

  @override
  String socialAccountStatusError(String error) {
    return 'Erro ao carregar status: $error';
  }

  @override
  String get socialAccountStatusLabel => 'Status da conta';

  @override
  String get socialAccountStatusTitle => 'Status da conta';

  @override
  String get socialAccountStrikeMeter => 'Indicador de penalidades';

  @override
  String get socialAccountStrikes => 'Penalidades';

  @override
  String get socialAccountSuspended => 'Suspenso';

  @override
  String get socialAccountSuspendedTitle => 'Conta suspensa';

  @override
  String get socialAccountSuspendedMessage =>
      'Sua conta está suspensa no momento. Você não pode publicar ou comentar até que a suspensão seja revogada.';

  @override
  String get socialAccountWarningStrikesActive => 'Atenção: penalidades ativas';

  @override
  String get socialAccountWarnings => 'Avisos';

  @override
  String get socialAccountWarningsActive => 'Avisos ativos';

  @override
  String get socialActiveStrikes => 'Penalidades ativas';

  @override
  String get socialActiveWarnings => 'Avisos ativos';

  @override
  String get socialActivityClearAll => 'Limpar tudo';

  @override
  String get socialActivityClearConfirmLabel => 'Limpar';

  @override
  String get socialActivityClearConfirmMessage =>
      'Todos os itens de atividade serão removidos. Esta ação não pode ser desfeita.';

  @override
  String get socialActivityClearConfirmTitle => 'Limpar toda a atividade?';

  @override
  String get socialActivityCommentedSignal => ' comentou no seu sinal';

  @override
  String get socialActivityErrorLoading => 'Falha ao carregar atividade';

  @override
  String get socialActivityGroupEarlier => 'Anteriormente';

  @override
  String get socialActivityGroupThisMonth => 'Este mês';

  @override
  String get socialActivityGroupThisWeek => 'Esta semana';

  @override
  String get socialActivityGroupToday => 'Hoje';

  @override
  String get socialActivityGroupYesterday => 'Ontem';

  @override
  String get socialActivityInteracted => ' interagiu com seu conteúdo';

  @override
  String get socialActivityLikedSignal => ' curtiu seu sinal';

  @override
  String get socialActivityLoadingSignal => 'Carregando sinal...';

  @override
  String get socialActivityMarkAllRead => 'Marcar tudo como lido';

  @override
  String get socialActivityRepliedComment => ' respondeu ao seu comentário';

  @override
  String get socialActivitySignalNotFound => 'Sinal não encontrado';

  @override
  String get socialActivityTagline1 =>
      'Nenhuma atividade ainda.\nInterações com suas publicações aparecem aqui.';

  @override
  String get socialActivityTagline2 =>
      'Curtidas, comentários, seguidores — tudo em um só lugar.\nPublique algo para começar.';

  @override
  String get socialActivityTagline3 =>
      'Seu pulso social começa aqui.\nConecte-se com outros para ver a atividade.';

  @override
  String get socialActivityTagline4 =>
      'Nada ainda. A atividade aparece quando outros\ninteragem com seu conteúdo.';

  @override
  String get socialActivityTitle => 'Atividade';

  @override
  String get socialActivityTitleKeyword => 'atividade';

  @override
  String get socialActivityTitlePrefix => 'Nenhuma ';

  @override
  String get socialActivityTitleSuffix => ' ainda';

  @override
  String get socialAdd => 'Adicionar';

  @override
  String get socialAddBanner => 'Adicionar banner';

  @override
  String get socialAlbumAll => 'Todos os álbuns';

  @override
  String get socialAlbumFavorites => 'Favoritos';

  @override
  String get socialAlbumRecents => 'Recentes';

  @override
  String get socialAlbumVideos => 'Vídeos';

  @override
  String get socialAppealDecision => 'Recorrer da decisão';

  @override
  String get socialBanReasonHarassment => 'Assédio / Bullying';

  @override
  String get socialBanReasonHateSpeech => 'Discurso de ódio / Discriminação';

  @override
  String get socialBanReasonIllegal => 'Atividade ilegal';

  @override
  String get socialBanReasonImpersonation => 'Falsidade ideológica';

  @override
  String get socialBanReasonOther => 'Outra violação';

  @override
  String get socialBanReasonPornography => 'Pornografia / Conteúdo sexual';

  @override
  String get socialBanReasonSpam => 'Spam / Golpe';

  @override
  String get socialBanReasonViolence => 'Violência / Ameaças';

  @override
  String get socialBanUserAndDelete => 'Banir usuário e excluir';

  @override
  String get socialBanUserButton => 'Banir usuário';

  @override
  String socialBanUserFailed(String error) {
    return 'Falha ao banir usuário: $error';
  }

  @override
  String socialBannerRemoveFailed(String error) {
    return 'Falha ao remover banner: $error';
  }

  @override
  String get socialBannerRemoved => 'Banner removido';

  @override
  String get socialBannerUpdated => 'Banner atualizado';

  @override
  String socialBannerUploadFailed(String error) {
    return 'Falha ao enviar banner: $error';
  }

  @override
  String get socialBlock => 'Bloquear';

  @override
  String get socialBlockUser => 'Bloquear usuário';

  @override
  String get socialBlockUserConfirm =>
      'Você não verá mais publicações deste usuário.';

  @override
  String get socialBlurSensitiveDesc =>
      'Desfocar imagens e vídeos potencialmente sensíveis até que você toque para revelar';

  @override
  String get socialBlurSensitiveMedia => 'Desfocar mídia sensível';

  @override
  String get socialCancel => 'Cancelar';

  @override
  String get socialCannotIdentifyUser =>
      'Não foi possível identificar o usuário para banir';

  @override
  String get socialChangeBanner => 'Alterar banner';

  @override
  String get socialClose => 'Fechar';

  @override
  String socialCommentActionFailed(String error) {
    return 'Falha: $error';
  }

  @override
  String get socialCommentDeleteConfirm =>
      'Tem certeza de que deseja excluir este comentário?';

  @override
  String socialCommentDeleteFailed(String error) {
    return 'Falha ao excluir: $error';
  }

  @override
  String get socialCommentDeleteTitle => 'Excluir comentário';

  @override
  String get socialCommentHintAdd => 'Adicione um comentário...';

  @override
  String get socialCommentHintReply => 'Escreva uma resposta...';

  @override
  String get socialCommentReply => 'Responder';

  @override
  String get socialCommentReported => 'Comentário denunciado';

  @override
  String get socialCommentUnknown => 'Desconhecido';

  @override
  String get socialComments => 'Comentários';

  @override
  String get socialCommunityGuidelines => 'Diretrizes da comunidade';

  @override
  String get socialConfirm => 'Confirmar';

  @override
  String get socialConnectionsTitle => 'Conexões';

  @override
  String get socialContactSupport => 'Dúvidas? Contate o suporte';

  @override
  String get socialContactSupportButton => 'Contatar suporte';

  @override
  String get socialContentApproved => 'Conteúdo aprovado';

  @override
  String get socialContentIdNotFound => 'ID do conteúdo não encontrado';

  @override
  String get socialContentRemoved => 'Conteúdo removido';

  @override
  String get socialContentType => 'Tipo de conteúdo';

  @override
  String get socialCreatePostAction => 'Criar publicação';

  @override
  String get socialCreatePostAddImage => 'Adicionar imagem';

  @override
  String get socialCreatePostAddLocation => 'Adicionar localização';

  @override
  String get socialCreatePostButton => 'Publicar';

  @override
  String get socialCreatePostCreated => 'Publicação criada!';

  @override
  String get socialCreatePostCurrentDesc => 'Compartilhe suas coordenadas GPS';

  @override
  String get socialCreatePostCurrentLocation => 'Localização atual';

  @override
  String get socialCreatePostDiscardMsgDraft => 'Seu rascunho será perdido.';

  @override
  String get socialCreatePostDiscardMsgImages =>
      'Suas imagens enviadas serão excluídas.';

  @override
  String get socialCreatePostDiscardTitle => 'Descartar publicação?';

  @override
  String get socialCreatePostEnterLocation => 'Inserir localização';

  @override
  String get socialCreatePostEnterManually => 'Inserir localização manualmente';

  @override
  String socialCreatePostFailed(String error) {
    return 'Falha ao criar publicação: $error';
  }

  @override
  String get socialCreatePostHint => 'O que está acontecendo na mesh?';

  @override
  String socialCreatePostImageCount(int count, int max) {
    return '$count/$max imagens';
  }

  @override
  String get socialCreatePostImageViolation =>
      'Uma ou mais imagens violaram a política de conteúdo.';

  @override
  String get socialCreatePostLocationDenied =>
      'Permissão de localização negada';

  @override
  String get socialCreatePostLocationHint => 'ex., São Paulo, SP';

  @override
  String get socialCreatePostLocationLabel => 'Localização';

  @override
  String get socialCreatePostLocationSheetTitle => 'Adicionar localização';

  @override
  String get socialCreatePostManualDesc => 'Digite um nome de lugar';

  @override
  String socialCreatePostMaxImages(int max) {
    return 'Máximo de $max imagens permitidas';
  }

  @override
  String get socialCreatePostNoNodes =>
      'Nenhum nó disponível. Conecte-se a uma mesh primeiro.';

  @override
  String socialCreatePostNodeLabel(String nodeId) {
    return 'Nó $nodeId';
  }

  @override
  String get socialCreatePostSignIn => 'Entre para criar publicações';

  @override
  String get socialCreatePostTagNode => 'Marcar nó';

  @override
  String get socialCreatePostTagNodeTitle => 'Marcar um nó';

  @override
  String get socialCreatePostTitle => 'Criar publicação';

  @override
  String get socialCreatePostUseCurrent => 'Usar localização atual';

  @override
  String get socialCreateStoryCamera => 'Câmera';

  @override
  String get socialCreateStoryCloseFriends => 'Amigos próximos';

  @override
  String get socialCreateStoryDelete => 'Excluir';

  @override
  String get socialCreateStoryDragInstructions =>
      'Arraste para mover • Aperte para redimensionar • Pressione longo para excluir';

  @override
  String get socialCreateStoryEdit => 'Editar';

  @override
  String get socialCreateStoryFailed => 'Falha ao criar story';

  @override
  String get socialCreateStoryFollowers => 'Seguidores';

  @override
  String socialCreateStoryItemsCount(int count) {
    return '$count itens';
  }

  @override
  String get socialCreateStoryLinkNode => 'Vincular a nó';

  @override
  String get socialCreateStoryLocationFailed =>
      'Não foi possível obter a localização';

  @override
  String get socialCreateStoryLocationRequired =>
      'Permissão de localização necessária';

  @override
  String get socialCreateStoryPublic => 'Público';

  @override
  String get socialCreateStoryShared => 'Story compartilhado!';

  @override
  String get socialCreateStorySignIn => 'Entre para criar stories';

  @override
  String get socialCreateStoryTitle => 'Adicionar ao story';

  @override
  String get socialCreateStoryTypeSomething => 'Digite algo...';

  @override
  String get socialCreateStoryUntitledAlbum => 'Álbum sem título';

  @override
  String get socialDate => 'Data';

  @override
  String get socialDefault => 'Padrão';

  @override
  String get socialDelete => 'Excluir';

  @override
  String get socialDeleteComment => 'Excluir comentário';

  @override
  String get socialDeleteCommentConfirm =>
      'Tem certeza de que deseja excluir este comentário?';

  @override
  String get socialDeletePost => 'Excluir publicação';

  @override
  String get socialDeletePostConfirm =>
      'Tem certeza de que deseja excluir esta publicação?';

  @override
  String get socialDeleteStory => 'Excluir story';

  @override
  String get socialDeleteStoryConfirm =>
      'Esta história será excluída permanentemente.';

  @override
  String socialDeleteType(String type) {
    return 'Excluir $type';
  }

  @override
  String socialDeleteTypeConfirm(String type) {
    return 'O $type denunciado será excluído permanentemente. Continuar?';
  }

  @override
  String get socialDiscard => 'Descartar';

  @override
  String socialDiscordCopied(String username) {
    return 'Nome de usuário do Discord copiado: $username';
  }

  @override
  String get socialDismiss => 'Dispensar';

  @override
  String get socialDisplayOptions => 'Opções de exibição';

  @override
  String get socialDone => 'Concluído';

  @override
  String get socialEditProfile => 'Editar perfil';

  @override
  String get socialEmailCopied => 'Email copiado para a área de transferência';

  @override
  String get socialEmptyPostsTagline1 =>
      'Compartilhe fotos e histórias sobre suas aventuras mesh.';

  @override
  String get socialEmptyPostsTagline2 =>
      'Publique sobre configurações de nós, testes de alcance e descobertas.';

  @override
  String get socialEmptyPostsTagline3 =>
      'Sua comunidade mesh está esperando para ver o que você constrói.';

  @override
  String get socialEmptyPostsTagline4 =>
      'Documente suas aventuras e compartilhe com a rede mesh.';

  @override
  String get socialErrorLoadingReports => 'Erro ao carregar denúncias';

  @override
  String get socialErrorLoadingViewers => 'Erro ao carregar visualizadores';

  @override
  String socialErrorWithDetails(String error) {
    return 'Erro: $error';
  }

  @override
  String get socialExpires => 'Expira';

  @override
  String socialFailedToBlock(String error) {
    return 'Falha ao bloquear usuário: $error';
  }

  @override
  String socialFailedToDelete(String error) {
    return 'Falha ao excluir: $error';
  }

  @override
  String socialFailedToGetLocation(String error) {
    return 'Falha ao obter localização: $error';
  }

  @override
  String socialFailedToReport(String error) {
    return 'Falha ao denunciar: $error';
  }

  @override
  String socialFailedToReportStory(String error) {
    return 'Falha ao denunciar história: $error';
  }

  @override
  String get socialFailedToUpdateLike => 'Falha ao atualizar curtida';

  @override
  String socialFailedToUploadImage(String error) {
    return 'Falha ao enviar imagem: $error';
  }

  @override
  String get socialFeedLocationFallback => 'Localização';

  @override
  String get socialFilterLevelLess => 'Menos';

  @override
  String get socialFilterLevelLessDesc =>
      'Você pode ver conteúdos que podem ser ofensivos ou perturbadores. Esta configuração tende a mostrar mais conteúdo.';

  @override
  String get socialFilterLevelStandard => 'Padrão';

  @override
  String get socialFilterLevelStandardDesc =>
      'Conteúdos potencialmente ofensivos ou perturbadores são filtrados. Você ainda pode ver alguns conteúdos limítrofes.';

  @override
  String get socialFollow => 'Seguir';

  @override
  String socialFollowActionFailed(String error) {
    return 'Falhou: $error';
  }

  @override
  String socialFollowFailed(String error) {
    return 'Falha ao atualizar seguir: $error';
  }

  @override
  String get socialFollowRequestAcceptFailed => 'Falha ao aceitar solicitação';

  @override
  String socialFollowRequestAccepted(String name) {
    return 'Solicitação de $name aceita';
  }

  @override
  String get socialFollowRequestDeclineFailed => 'Falha ao recusar solicitação';

  @override
  String socialFollowRequestDeclined(String name) {
    return 'Solicitação de $name recusada';
  }

  @override
  String get socialFollowRequestsEmpty => 'Nenhuma solicitação pendente';

  @override
  String get socialFollowRequestsEmptyDesc =>
      'Quando alguém solicitar seguir você, aparecerá aqui.';

  @override
  String socialFollowRequestsError(String error) {
    return 'Falha ao carregar: $error';
  }

  @override
  String get socialFollowRequestsTitle => 'Solicitações de seguir';

  @override
  String socialFollowersError(String error) {
    return 'Falha ao carregar: $error';
  }

  @override
  String get socialFollowing => 'Seguindo';

  @override
  String get socialGuidelineNoExplicit => 'Nenhum conteúdo explícito ou adulto';

  @override
  String get socialGuidelineNoHarassment =>
      'Nenhum assédio, ameaça ou discurso de ódio';

  @override
  String get socialGuidelineNoSpam => 'Nenhum spam, golpe ou conteúdo enganoso';

  @override
  String get socialGuidelinesWarning => 'Aviso das diretrizes da comunidade';

  @override
  String get socialHubSignIn => 'Faça login para acessar o Social';

  @override
  String get socialHubSignInDesc =>
      'Crie publicações, siga usuários e conecte-se com a comunidade mesh.';

  @override
  String get socialHubTitle => 'Social';

  @override
  String get socialIUnderstand => 'Eu entendo';

  @override
  String get socialImageBlockedByModeration =>
      'Imagem bloqueada pela moderação';

  @override
  String get socialInvalidNodeId => 'ID do nó inválido';

  @override
  String socialJoined(String date) {
    return 'Entrou em $date';
  }

  @override
  String get socialLike => 'Curtir';

  @override
  String get socialLiked => 'Curtido';

  @override
  String get socialLikePlural => 'curtidas';

  @override
  String get socialLikeSingular => 'curtida';

  @override
  String get socialLinkNodeHint =>
      'Vincule um nó mesh à sua próxima publicação';

  @override
  String get socialLocationFallback => 'Localização';

  @override
  String get socialModerationAdditionalNotes => 'Notas adicionais (opcional)';

  @override
  String get socialModerationApprove => 'Aprovar';

  @override
  String get socialModerationApproved => 'Conteúdo aprovado';

  @override
  String get socialModerationErrorLoading => 'Erro ao carregar fila';

  @override
  String get socialModerationNoPending => 'Nenhum item pendente de revisão';

  @override
  String socialModerationNoStatus(String status) {
    return 'Nenhum item $status';
  }

  @override
  String get socialModerationQueueTitle => 'Fila de moderação';

  @override
  String get socialModerationReasonHarassment => 'Assédio ou bullying';

  @override
  String get socialModerationReasonHateSpeech =>
      'Discurso de ódio ou discriminação';

  @override
  String get socialModerationReasonIP => 'Violação de propriedade intelectual';

  @override
  String get socialModerationReasonNudity => 'Nudez ou conteúdo sexual';

  @override
  String get socialModerationReasonOther => 'Outra violação de política';

  @override
  String get socialModerationReasonSpam => 'Spam ou conteúdo enganoso';

  @override
  String get socialModerationReasonViolence => 'Violência ou conteúdo perigoso';

  @override
  String get socialModerationReject => 'Rejeitar';

  @override
  String get socialModerationRejected => 'Conteúdo rejeitado';

  @override
  String get socialModerationRejectionReason => 'Motivo da rejeição';

  @override
  String socialModerationReviewedBy(String reviewedBy) {
    return 'Revisado por $reviewedBy';
  }

  @override
  String get socialModerationTabApproved => 'Aprovados';

  @override
  String get socialModerationTabPending => 'Pendentes';

  @override
  String get socialModerationTabRejected => 'Rejeitados';

  @override
  String socialModerationUserLabel(String userId) {
    return 'Usuário: $userId';
  }

  @override
  String get socialNext => 'Avançar';

  @override
  String get socialNoAlbumsFound => 'Nenhum álbum encontrado';

  @override
  String get socialNoCommentsYet => 'Nenhum comentário. Seja o primeiro!';

  @override
  String get socialNoContent => 'Nenhum conteúdo';

  @override
  String get socialNoFollowersYet => 'Nenhum seguidor ainda';

  @override
  String get socialNoLocationPosts => 'Nenhuma publicação com localização';

  @override
  String get socialNoNodePosts => 'Nenhuma publicação com nó';

  @override
  String socialNoPendingFilterReports(String filter) {
    return 'Nenhuma denúncia $filter pendente';
  }

  @override
  String get socialNoPendingReports => 'Nenhuma denúncia pendente';

  @override
  String get socialNoPhotoPosts => 'Nenhuma publicação com foto';

  @override
  String get socialNoPosts => 'Nenhuma publicação';

  @override
  String get socialNoPostsYet => 'Nenhuma publicação ainda';

  @override
  String get socialNoRecentActivity => 'Nenhuma atividade recente';

  @override
  String get socialNoSuggestions => 'Nenhuma sugestão disponível';

  @override
  String get socialNoUsersFound => 'Nenhum usuário encontrado';

  @override
  String get socialNoViewsYet => 'Nenhuma visualização ainda';

  @override
  String socialNodeLabel(String nodeId) {
    return 'Nó $nodeId';
  }

  @override
  String get socialNotFollowingAnyone => 'Não segue ninguém ainda';

  @override
  String socialNoticesCount(int current, int total) {
    return '$current de $total avisos';
  }

  @override
  String get socialOK => 'OK';

  @override
  String get socialOnline => 'Online';

  @override
  String get socialOpenSettings => 'Abrir configurações';

  @override
  String get socialPermanentlyBanned => 'Banido permanentemente';

  @override
  String get socialPhotoAccessDesc =>
      'Para criar histórias, precisamos de acesso à sua biblioteca de fotos.';

  @override
  String get socialPhotoAccessTitle => 'Permitir acesso às suas fotos';

  @override
  String get socialPostCardLocationFallback => 'Localização';

  @override
  String socialPostCardNodeLabel(String nodeId) {
    return 'Nó $nodeId';
  }

  @override
  String get socialPostCardUnknownUser => 'Usuário desconhecido';

  @override
  String get socialPostDeleted => 'Publicação excluída';

  @override
  String get socialPostDetailTitle => 'Publicação';

  @override
  String get socialPostNotFound => 'Publicação não encontrada';

  @override
  String get socialPostNotFoundForComment =>
      'Publicação não encontrada para este comentário';

  @override
  String get socialPrivateAccount => 'Esta conta é privada';

  @override
  String socialPrivateAccountDesc(String name) {
    return 'Siga $name para ver suas publicações e dispositivos vinculados.';
  }

  @override
  String get socialProfileBlockLabel => 'Bloquear';

  @override
  String get socialProfileLoadFailed => 'Falha ao carregar perfil';

  @override
  String get socialProfileNotFound => 'Perfil não encontrado';

  @override
  String get socialProfileNotFoundDesc =>
      'Este perfil pode ter sido removido ou está temporariamente indisponível.';

  @override
  String get socialProfileReportLabel => 'Denunciar';

  @override
  String get socialProfileShareLabel => 'Compartilhar perfil';

  @override
  String get socialReason => 'Motivo';

  @override
  String get socialRecentFailed => 'Falha ao carregar usuários recentes';

  @override
  String get socialRecentlyActive => 'Ativos recentemente';

  @override
  String get socialRejectDelete => 'Rejeitar e excluir';

  @override
  String socialRejectDeleteMsg(String contentType) {
    return 'Isso excluirá o $contentType e avisará o usuário.';
  }

  @override
  String get socialRemoveBanner => 'Remover banner';

  @override
  String get socialReply => 'Responder';

  @override
  String socialReplyingTo(String name) {
    return 'Respondendo a $name';
  }

  @override
  String get socialRepeatedViolationsWarning =>
      'Violações repetidas podem resultar na suspensão da conta.';

  @override
  String get socialReport => 'Denunciar';

  @override
  String get socialReportComment => 'Denunciar comentário';

  @override
  String get socialReportCommentWhy =>
      'Por que você está denunciando este comentário?';

  @override
  String get socialReportDescribeIssue => 'Descreva o problema...';

  @override
  String get socialReportDismissed => 'Denúncia dispensada';

  @override
  String get socialReportPost => 'Denunciar publicação';

  @override
  String get socialReportPostWhy =>
      'Por que você está denunciando esta publicação?';

  @override
  String get socialReportProfileSubmitted => 'Denúncia enviada';

  @override
  String get socialReportReasonFalseInfo => 'Informações falsas';

  @override
  String get socialReportReasonHarassment => 'Assédio ou bullying';

  @override
  String get socialReportReasonHateSpeech => 'Discurso de ódio';

  @override
  String get socialReportReasonNudity => 'Nudez ou conteúdo sexual';

  @override
  String get socialReportReasonOther => 'Outro';

  @override
  String get socialReportReasonSpam => 'Spam';

  @override
  String get socialReportReasonViolence => 'Violência ou ameaças';

  @override
  String get socialReportStory => 'Denunciar história';

  @override
  String get socialReportStoryReasonCopyright =>
      'Violação de direitos autorais';

  @override
  String get socialReportStoryReasonHarassment => 'Assédio ou bullying';

  @override
  String get socialReportStoryReasonNudity => 'Nudez ou conteúdo sexual';

  @override
  String get socialReportStoryReasonOther => 'Outro';

  @override
  String get socialReportStoryReasonSpam => 'Spam ou conteúdo enganoso';

  @override
  String get socialReportStoryReasonViolence =>
      'Violência ou conteúdo perigoso';

  @override
  String get socialReportStoryWhy =>
      'Por que você está denunciando esta história?';

  @override
  String get socialReportSubmitted => 'Denúncia enviada. Obrigado.';

  @override
  String get socialReportedContentRejected =>
      'Conteúdo rejeitado e usuário avisado';

  @override
  String get socialReportedContentTitle => 'Conteúdo denunciado';

  @override
  String get socialReportedErrorLoading => 'Erro ao carregar fila de moderação';

  @override
  String get socialReportedNoFlagged => 'Nenhum conteúdo sinalizado';

  @override
  String get socialReportedNoFlaggedDesc =>
      'A moderação automática não sinalizou nenhum conteúdo';

  @override
  String get socialReportedTabAll => 'Todos';

  @override
  String get socialReportedTabAuto => 'Auto';

  @override
  String get socialReportedTabComments => 'Comentários';

  @override
  String get socialReportedTabPosts => 'Publicações';

  @override
  String get socialReportedTabSigComments => 'Com. de sinais';

  @override
  String get socialReportedTabSignals => 'Sinais';

  @override
  String get socialRequested => 'Solicitado';

  @override
  String get socialRetry => 'Tentar novamente';

  @override
  String socialSearchFailed(String error) {
    return 'Falha na busca: $error';
  }

  @override
  String get socialSearchHint => 'Buscar usuários...';

  @override
  String get socialSearchTitle => 'Buscar';

  @override
  String get socialSearchTooltip => 'Buscar';

  @override
  String get socialSendMessage => 'Enviar mensagem';

  @override
  String get socialSensitiveContentControl => 'Controle de conteúdo sensível';

  @override
  String get socialSensitiveContentDescription =>
      'Socialmesh usa sistemas automatizados para detectar conteúdo potencialmente sensível. Você pode ajustar como esse conteúdo é exibido.';

  @override
  String get socialSensitiveContentExplanation =>
      'Controle o tipo de conteúdo no seu feed. Isso afeta a filtragem por IA de publicações, sinais e histórias.';

  @override
  String get socialSensitiveContentTitle => 'Conteúdo sensível';

  @override
  String get socialSettingsTooltip => 'Configurações';

  @override
  String get socialShare => 'Compartilhar';

  @override
  String get socialShareFirstPostKeyword => 'publicação';

  @override
  String get socialShareFirstPostPrefix => 'Compartilhe sua primeira ';

  @override
  String get socialSharePhotoHint => 'Compartilhe uma foto para vê-la aqui';

  @override
  String get socialSignIn => 'Entrar';

  @override
  String get socialSignInToLikePosts => 'Faça login para curtir publicações';

  @override
  String get socialSignInToUploadImages => 'Faça login para enviar imagens';

  @override
  String get socialSignInSubscriptions =>
      'Faça login para gerenciar assinaturas';

  @override
  String get socialStatFollower => 'Seguidor';

  @override
  String get socialStatFollowers => 'Seguidores';

  @override
  String get socialStatFollowing => 'Seguindo';

  @override
  String get socialStatPost => 'Publicação';

  @override
  String get socialStatPosts => 'Publicações';

  @override
  String get socialStatsBarFollowers => 'Seguidores';

  @override
  String get socialStatsBarFollowing => 'Seguindo';

  @override
  String get socialStatsBarPosts => 'Publicações';

  @override
  String get socialStatusFlagged => 'SINALIZADO';

  @override
  String get socialStatusPending => 'PENDENTE';

  @override
  String get socialStatusRejected => 'REJEITADO';

  @override
  String get socialStatusStrike => 'ADVERTÊNCIA';

  @override
  String get socialStatusSuspended => 'SUSPENSO';

  @override
  String get socialStoryBarAdd => 'Adicionar';

  @override
  String get socialStoryContentUnavailable => 'Conteúdo indisponível';

  @override
  String socialStoryDeleteFailed(String error) {
    return 'Falha ao excluir story: $error';
  }

  @override
  String get socialStoryDeleted => 'Story excluído';

  @override
  String get socialStoryMayBeRemoved => 'Este story pode ter sido removido';

  @override
  String get socialStoryReported =>
      'Story denunciado. Vamos analisá-lo em breve.';

  @override
  String get socialStoryUserFallback => 'Usuário';

  @override
  String get socialStrike3Suspension =>
      '3 avisos resultam em suspensão da conta';

  @override
  String get socialStrikeAcknowledge => 'Entendi';

  @override
  String get socialStrikeAgainstAccount => 'Aviso na sua conta';

  @override
  String socialStrikeContentLabel(String type) {
    return 'Conteúdo: $type';
  }

  @override
  String socialStrikeContentTitle(String typeDisplayName) {
    return 'Conteúdo $typeDisplayName';
  }

  @override
  String socialStrikeError(String error) {
    return 'Erro: $error';
  }

  @override
  String get socialStrikeNext => 'Próximo';

  @override
  String socialStrikeOfTotal(int current, int total) {
    return '$current de $total';
  }

  @override
  String get socialStrikeReasonLabel => 'Motivo';

  @override
  String get socialStrikeReceivedStrike =>
      'Você recebeu um aviso na sua conta por violação das diretrizes da comunidade.';

  @override
  String get socialStrikeReceivedWarning =>
      'Você recebeu um alerta. Revise nossas diretrizes da comunidade.';

  @override
  String socialStrikeTapReview(int count) {
    return 'Você tem $count aviso(s) - toque para revisar';
  }

  @override
  String get socialStrikesExpireInfo =>
      'Os avisos expiram após 90 dias sem violações.';

  @override
  String socialStrikesOnAccount(int count) {
    return '$count aviso(s) ativo(s) na sua conta';
  }

  @override
  String get socialSubscribe => 'Inscrever-se';

  @override
  String get socialSubscribed => 'Inscrito';

  @override
  String socialSubscriptionFailed(String error) {
    return 'Falha ao atualizar inscrição: $error';
  }

  @override
  String get socialSuggestedForYou => 'Sugestões para você';

  @override
  String get socialSuggestionsFailed => 'Falha ao carregar sugestões';

  @override
  String get socialSuspendedContactSupport =>
      'Entre em contato com o suporte para contestar esta decisão';

  @override
  String socialSuspendedDaysPlural(int n) {
    return '$n dias';
  }

  @override
  String socialSuspendedDaysSingular(int n) {
    return '$n dia';
  }

  @override
  String get socialSuspendedDefaultReason =>
      'Sua conta foi suspensa por violações repetidas das nossas diretrizes da comunidade.';

  @override
  String get socialSuspendedGoBack => 'Voltar';

  @override
  String socialSuspendedHoursPlural(int n) {
    return '$n horas';
  }

  @override
  String socialSuspendedHoursSingular(int n) {
    return '$n hora';
  }

  @override
  String get socialSuspendedIndefinite => 'Suspensão por tempo indeterminado';

  @override
  String get socialSuspendedIndefinitely => 'por tempo indeterminado';

  @override
  String get socialSuspendedLabel => 'Suspenso';

  @override
  String socialSuspendedMinutesPlural(int n) {
    return '$n minutos';
  }

  @override
  String socialSuspendedMinutesSingular(int n) {
    return '$n minuto';
  }

  @override
  String get socialSuspendedPermanent => 'Conta suspensa';

  @override
  String socialSuspendedRemaining(String duration) {
    return 'Restante: $duration';
  }

  @override
  String get socialSuspendedReviewGuidelines =>
      'Revise nossas diretrizes da comunidade';

  @override
  String get socialSuspendedShortly => 'em breve';

  @override
  String socialSuspendedStrikesCount(int count) {
    return '$count aviso(s) na sua conta';
  }

  @override
  String get socialSuspendedTemporary => 'Publicação temporariamente suspensa';

  @override
  String get socialSuspendedWaitAppeal => 'Aguarde a análise do seu recurso';

  @override
  String get socialSuspendedWaitPeriod =>
      'Aguarde o fim do período de suspensão';

  @override
  String get socialSuspendedWhatCanIDo => 'O que posso fazer?';

  @override
  String get socialSuspendedWhyTitle => 'Por que estou vendo isso?';

  @override
  String get socialSuspensionEnds => 'Fim da suspensão';

  @override
  String get socialTabFollowers => 'Seguidores';

  @override
  String get socialTabFollowing => 'Seguindo';

  @override
  String get socialTagLocationHint =>
      'Marque uma localização na sua próxima publicação';

  @override
  String socialTimeDaysAgo(int n) {
    return '${n}d atrás';
  }

  @override
  String socialTimeHoursAgo(int n) {
    return '${n}h atrás';
  }

  @override
  String get socialTimeJustNow => 'Agora';

  @override
  String socialTimeMinutesAgo(int n) {
    return '${n}m atrás';
  }

  @override
  String get socialTryDifferentFilter => 'Tente selecionar um filtro diferente';

  @override
  String get socialTryDifferentSearch => 'Tente um termo de busca diferente';

  @override
  String socialTypeDeleted(String type) {
    return '$type excluído';
  }

  @override
  String get socialUnfollow => 'Deixar de seguir';

  @override
  String get socialUnknownUser => 'Usuário desconhecido';

  @override
  String get socialUnsubscribed => 'Inscrição cancelada';

  @override
  String get socialUnsuspend => 'Reativar';

  @override
  String socialUnsuspendConfirm(String displayName) {
    return 'Tem certeza que deseja remover a suspensão de $displayName?';
  }

  @override
  String get socialUnsuspendUser => 'Reativar usuário';

  @override
  String socialUserBannedAndDeleted(String type) {
    return 'Usuário banido e $type excluído';
  }

  @override
  String get socialUserBlocked => 'Usuário bloqueado';

  @override
  String socialUserBlockedName(String name) {
    return '$name bloqueado';
  }

  @override
  String get socialUserFallback => 'Usuário';

  @override
  String get socialUserUnsuspended => 'Usuário reativado com sucesso';

  @override
  String get socialView => 'Ver';

  @override
  String get socialViewLabel => 'visualização';

  @override
  String get socialViewLocation => 'Ver localização';

  @override
  String get socialViewOnMap => 'Ver no mapa';

  @override
  String get socialViewersTitle => 'Visualizadores';

  @override
  String get socialViewsLabel => 'visualizações';

  @override
  String get socialViolationsDetected => 'Violações detectadas';

  @override
  String get socialVisibilityFollowers => 'Seguidores';

  @override
  String get socialVisibilityFollowersDesc =>
      'Apenas seus seguidores podem ver isso';

  @override
  String get socialVisibilityOnlyMe => 'Apenas eu';

  @override
  String get socialVisibilityOnlyMeDesc =>
      'Apenas você pode ver esta publicação';

  @override
  String get socialVisibilityPublic => 'Público';

  @override
  String get socialVisibilityPublicDesc =>
      'Qualquer pessoa pode ver esta publicação';

  @override
  String get socialVisibilityWhoCanSee => 'Quem pode ver isso?';

  @override
  String socialWarningsOnAccount(int count) {
    return '$count alerta(s) ativo(s) na sua conta';
  }

  @override
  String socialWarningsTapReview(int count) {
    return 'Você tem $count alerta(s) - toque para revisar';
  }

  @override
  String get socialYourStory => 'Seu story';

  @override
  String get takAffiliationAssumedFriend => 'Presumido amigo';

  @override
  String get takAffiliationFriendly => 'Amigo';

  @override
  String get takAffiliationHostile => 'Hostil';

  @override
  String get takAffiliationNeutral => 'Neutro';

  @override
  String get takAffiliationPending => 'Pendente';

  @override
  String get takAffiliationSuspect => 'Suspeito';

  @override
  String get takAffiliationUnknown => 'Desconhecido';

  @override
  String get takCompassE => 'L';

  @override
  String get takCompassN => 'N';

  @override
  String get takCompassNE => 'NE';

  @override
  String get takCompassNW => 'NO';

  @override
  String get takCompassS => 'S';

  @override
  String get takCompassSE => 'SE';

  @override
  String get takCompassSW => 'SO';

  @override
  String get takCompassW => 'O';

  @override
  String get takCotTypeAtom => 'Atom';

  @override
  String get takCotTypeBits => 'Bits';

  @override
  String get takCotTypeFriendly => 'Amigo';

  @override
  String get takCotTypeHostile => 'Hostil';

  @override
  String get takCotTypeNeutral => 'Neutro';

  @override
  String get takCotTypeTasking => 'Tasking';

  @override
  String get takCotTypeUnknown => 'Desconhecido';

  @override
  String get takDashboardConnected => 'Conectado';

  @override
  String get takDashboardConnection => 'Conexão';

  @override
  String get takDashboardDisconnected => 'Desconectado';

  @override
  String get takDashboardForceDisposition => 'Resumo de entidades';

  @override
  String get takDashboardFriendly => 'Amigo';

  @override
  String get takDashboardHostile => 'Hostil';

  @override
  String get takDashboardLastEvent => 'Último evento';

  @override
  String get takDashboardLastEventNone => 'Nenhum';

  @override
  String takDashboardNearestHostile(String callsign) {
    return 'Hostil mais próximo: $callsign';
  }

  @override
  String takDashboardNearestUnknown(String callsign) {
    return 'Desconhecido mais próximo: $callsign';
  }

  @override
  String get takDashboardNeutral => 'Neutro';

  @override
  String get takDashboardNoHostileContacts => 'Nenhum contato hostil';

  @override
  String get takDashboardNoUnknownContacts => 'Nenhum contato desconhecido';

  @override
  String get takDashboardPositionPublishing => 'Publicação de posição';

  @override
  String takDashboardPublishingActive(String intervalSeconds) {
    return 'Ativa (${intervalSeconds}s)';
  }

  @override
  String get takDashboardPublishingDisabled => 'Desativada';

  @override
  String takDashboardRelativeTimeDays(int count) {
    return '${count}d atrás';
  }

  @override
  String takDashboardRelativeTimeHours(int count) {
    return '${count}h atrás';
  }

  @override
  String takDashboardRelativeTimeMinutes(int count) {
    return '${count}m atrás';
  }

  @override
  String takDashboardRelativeTimeSeconds(int count) {
    return '${count}s atrás';
  }

  @override
  String get takDashboardStaleEntities => 'Entidades obsoletas';

  @override
  String get takDashboardStatusHeader => 'Estado';

  @override
  String get takDashboardThreatProximity => 'Proximidade de entidades';

  @override
  String get takDashboardTitle => 'Painel TAK';

  @override
  String get takDashboardTotalEntities => 'Total de entidades';

  @override
  String get takDashboardTracked => 'Rastreado';

  @override
  String get takDashboardUnknown => 'Desconhecido';

  @override
  String takDistanceKilometers(double km) {
    return '$km km';
  }

  @override
  String takDistanceMeters(double meters) {
    return '$meters m';
  }

  @override
  String takEventAltitudeFormat(double meters, String feet) {
    return '$meters m ($feet ft)';
  }

  @override
  String takEventCourseFormat(String degrees, String compassDirection) {
    return '$degrees° ($compassDirection)';
  }

  @override
  String get takEventDetailHelpAffiliation => 'Afiliação';

  @override
  String get takEventDetailHelpCotType => 'String de tipo CoT';

  @override
  String get takEventDetailHelpIdentity => 'Identidade';

  @override
  String get takEventDetailHelpMotion => 'Dados de movimento';

  @override
  String get takEventDetailHelpPosition => 'Posição';

  @override
  String get takEventDetailHelpRawPayload => 'Payload bruto';

  @override
  String get takEventDetailHelpTimestamps => 'Marcas Temporais';

  @override
  String get takEventDetailHelpTracking => 'Rastreamento';

  @override
  String get takEventDetailJsonCopied => 'JSON do evento copiado';

  @override
  String get takEventDetailLabelAltitude => 'Altitude';

  @override
  String get takEventDetailLabelCallsign => 'Indicativo';

  @override
  String get takEventDetailLabelCourse => 'Rumo';

  @override
  String get takEventDetailLabelDescription => 'Descrição';

  @override
  String get takEventDetailLabelEventTime => 'Hora do evento';

  @override
  String get takEventDetailLabelLatitude => 'Latitude';

  @override
  String get takEventDetailLabelLongitude => 'Longitude';

  @override
  String get takEventDetailLabelReceived => 'Recebido';

  @override
  String get takEventDetailLabelSpeed => 'Velocidade';

  @override
  String get takEventDetailLabelStaleTime => 'Tempo de expiração';

  @override
  String get takEventDetailLabelStatus => 'Estado';

  @override
  String get takEventDetailLabelType => 'Tipo';

  @override
  String get takEventDetailLabelUid => 'UID';

  @override
  String get takEventDetailNavigateTo => 'Navegar até';

  @override
  String get takEventDetailNoMovement => 'Nenhum movimento registrado';

  @override
  String takEventDetailPositionCount(int count) {
    return '($count posições)';
  }

  @override
  String get takEventDetailSectionIdentity => 'Identidade';

  @override
  String get takEventDetailSectionMotion => 'Movimento';

  @override
  String get takEventDetailSectionPosition => 'Posição';

  @override
  String get takEventDetailSectionPositionHistory => 'HISTÓRICO DE POSIÇÕES';

  @override
  String get takEventDetailSectionRawPayload => 'Payload bruto';

  @override
  String get takEventDetailSectionTimestamps => 'Marcas Temporais';

  @override
  String takEventDetailShowAllPositions(int count) {
    return 'Mostrar todas as $count posições';
  }

  @override
  String get takEventDetailShowLess => 'Mostrar menos';

  @override
  String get takEventDetailStatusActive => 'ATIVO';

  @override
  String get takEventDetailStatusStale => 'OBSOLETO';

  @override
  String get takEventDetailTooltipCopyJson => 'Copiar JSON';

  @override
  String get takEventDetailTooltipShowOnMap => 'Mostrar no mapa';

  @override
  String get takEventDetailTooltipTrack => 'Rastrear';

  @override
  String get takEventDetailTooltipUntrack => 'Parar de rastrear';

  @override
  String takEventSpeedFormat(String kmh, String knots) {
    return '$kmh km/h ($knots kn)';
  }

  @override
  String get takEventSpeedStationary => 'Parado';

  @override
  String get takEventTileActive => 'Ativo';

  @override
  String takEventTileRelativeTimeHours(int count) {
    return '${count}h atrás';
  }

  @override
  String takEventTileRelativeTimeMinutes(int count) {
    return '${count}m atrás';
  }

  @override
  String takEventTileRelativeTimeSeconds(int count) {
    return '${count}s atrás';
  }

  @override
  String get takEventTileStale => 'Obsoleto';

  @override
  String get takFilterBarClear => 'Limpar';

  @override
  String get takFilterBarSearchHint => 'Buscar indicativo ou UID...';

  @override
  String get takFilterBarStaleModeActive => 'Ativo';

  @override
  String get takFilterBarStaleModeAll => 'Todos';

  @override
  String get takFilterBarStaleModeStale => 'Obsoleto';

  @override
  String takNavigateEta(String eta) {
    return 'ETA: $eta';
  }

  @override
  String get takNavigateLastUpdate => 'Última atualização';

  @override
  String get takNavigateNoPosition =>
      'Posição indisponível\nConecte-se a um nó com GPS';

  @override
  String get takNavigatePosition => 'Posição';

  @override
  String takNavigateRelativeTimeDays(int count) {
    return '${count}d atrás';
  }

  @override
  String takNavigateRelativeTimeHours(int count) {
    return '${count}h atrás';
  }

  @override
  String takNavigateRelativeTimeMinutes(int count) {
    return '${count}m atrás';
  }

  @override
  String takNavigateRelativeTimeSeconds(int count) {
    return '${count}s atrás';
  }

  @override
  String takNavigateTitle(String callsign) {
    return 'Navegar até $callsign';
  }

  @override
  String get takScreenButtonConnect => 'Conectar';

  @override
  String get takScreenButtonSignIn => 'Entrar para conectar';

  @override
  String get takScreenEmptyDisconnected =>
      'Conecte-se ao TAK Gateway para iniciar o streaming de entidades CoT.';

  @override
  String get takScreenEmptyListening =>
      'Aguardando eventos CoT do TAK Gateway...';

  @override
  String get takScreenEmptySignIn =>
      'Entre e conecte-se para receber entidades CoT em tempo real.';

  @override
  String get takScreenEmptyTitle => 'Nenhuma entidade TAK';

  @override
  String get takScreenFilterAll => 'Todos';

  @override
  String get takScreenHelpTitleDefault => 'Info';

  @override
  String get takScreenHelpTitleFilters => 'Filtros';

  @override
  String get takScreenHelpTitleSettings => 'Configurações';

  @override
  String get takScreenHelpTitleStatus => 'Status da conexão';

  @override
  String get takScreenOverflowDashboard => 'Dashboard TAK';

  @override
  String get takScreenOverflowSettings => 'Configurações TAK';

  @override
  String get takScreenSearchHint => 'Buscar callsign ou UID';

  @override
  String get takScreenStaleModeActiveOnly => 'Somente ativos';

  @override
  String get takScreenStaleModeAll => 'Status: Todos';

  @override
  String get takScreenStaleModeStaleOnly => 'Somente inativos';

  @override
  String get takScreenTitle => 'Gateway TAK';

  @override
  String get takScreenTooltipConnect => 'Conectar';

  @override
  String get takScreenTooltipDisconnect => 'Desconectar';

  @override
  String get takScreenTooltipSignInToConnect => 'Entre para conectar';

  @override
  String get takSettingsAlertHostile => 'Hostil';

  @override
  String get takSettingsAlertOn => 'Alertar para:';

  @override
  String get takSettingsAlertSuspect => 'Suspeito';

  @override
  String get takSettingsAlertUnknown => 'Desconhecido';

  @override
  String get takSettingsAutoConnectSubtitle =>
      'Conectar automaticamente ao abrir as telas TAK';

  @override
  String get takSettingsAutoConnectTitle => 'Conexão automática';

  @override
  String get takSettingsCallsignDefault => 'Usando nome do nó';

  @override
  String get takSettingsCallsignEditorHint =>
      'Deixe vazio para usar o nome do nó';

  @override
  String get takSettingsCallsignEditorPlaceholder => 'ex., HIKER-7';

  @override
  String get takSettingsCallsignEditorTitle => 'Substituição de callsign';

  @override
  String get takSettingsCallsignTitle => 'Substituição de callsign';

  @override
  String takSettingsError(String error) {
    return 'Erro: $error';
  }

  @override
  String get takSettingsGatewayEditorHint =>
      'Deixe vazio para usar o gateway padrão';

  @override
  String get takSettingsGatewayEditorPlaceholder =>
      'https://tak.socialmesh.app';

  @override
  String get takSettingsGatewayEditorTitle => 'URL do gateway';

  @override
  String get takSettingsGatewayUrlDefault => 'Padrão (tak.socialmesh.app)';

  @override
  String get takSettingsGatewayUrlTitle => 'URL do gateway';

  @override
  String get takSettingsIntervalSubtitle => 'Frequência de envio da posição';

  @override
  String get takSettingsIntervalTitle => 'Intervalo de publicação';

  @override
  String get takSettingsMapLayerSubtitle =>
      'Exibir marcadores de entidades TAK no mapa dedicado';

  @override
  String get takSettingsMapLayerTitle => 'Mostrar camada TAK no mapa';

  @override
  String get takSettingsProximitySubtitle =>
      'Notificar quando entidades não reconhecidas entrarem no raio';

  @override
  String get takSettingsProximityTitle => 'Ativar alertas de proximidade';

  @override
  String get takSettingsPublishSubtitle =>
      'Compartilhar a posição do nó com operadores ATAK/WinTAK';

  @override
  String get takSettingsPublishTitle => 'Publicar minha posição';

  @override
  String takSettingsRadiusSubtitle(double km) {
    return '$km km';
  }

  @override
  String get takSettingsRadiusTitle => 'Raio de alerta';

  @override
  String get takSettingsSave => 'Salvar';

  @override
  String get takSettingsSectionConnection => 'CONEXÃO';

  @override
  String get takSettingsSectionMap => 'MAPA';

  @override
  String get takSettingsSectionProximity => 'ALERTAS DE PROXIMIDADE';

  @override
  String get takSettingsSectionPublishing => 'PUBLICAÇÃO DE POSIÇÃO';

  @override
  String get takSettingsTitle => 'Configurações TAK';

  @override
  String get takStatusCardConnected => 'Conectado';

  @override
  String get takStatusCardConnecting => 'Conectando...';

  @override
  String get takStatusCardCounterEntities => 'Entidades';

  @override
  String get takStatusCardCounterEvents => 'Eventos';

  @override
  String get takStatusCardCounterUptime => 'Tempo Ativo';

  @override
  String get takStatusCardDisconnected => 'Desconectado';

  @override
  String get takStatusCardLabel => 'Gateway TAK';

  @override
  String get takStatusCardReconnecting => 'Reconectando...';

  @override
  String takStatusCardUptimeHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String takStatusCardUptimeMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String takStatusCardUptimeSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get tapbackReact => 'Reagir';

  @override
  String taskErrorCompleteTaskDenied(String roleName) {
    return 'completeTask negado para o papel $roleName';
  }

  @override
  String get taskErrorCompletionNoteRequired =>
      'A conclusão requer uma nota com pelo menos 10 caracteres';

  @override
  String taskErrorCreateDenied(String roleName) {
    return 'createTask negado para o papel $roleName';
  }

  @override
  String get taskErrorFailureReasonRequired =>
      'A falha requer um motivo com pelo menos 10 caracteres';

  @override
  String taskErrorInvalidTransition(String fromState, String toState) {
    return '$fromState -> $toState não é uma transição válida';
  }

  @override
  String get taskErrorOnlyAssigneeCanAcknowledge =>
      'Somente o responsável pode confirmar uma tarefa';

  @override
  String get taskErrorOnlyAssigneeCanReportFailure =>
      'Somente o responsável pode relatar falha na tarefa';

  @override
  String get taskErrorOnlyAssigneeCanStartWork =>
      'Somente o responsável pode iniciar o trabalho em uma tarefa';

  @override
  String get taskErrorReassignmentRequiresAssignee =>
      'A reatribuição requer um newAssigneeId';

  @override
  String taskErrorRequiresSupervisorOrAdmin(String action, String roleName) {
    return '$action requer papel de supervisor ou admin, papel atual: $roleName';
  }

  @override
  String taskErrorTerminalState(String stateName) {
    return 'Não é possível transicionar de $stateName: estado terminal: $stateName';
  }

  @override
  String get taskPriorityImmediate => 'imediata';

  @override
  String get taskPriorityPriority => 'prioridade';

  @override
  String get taskPriorityRoutine => 'rotina';

  @override
  String get taskStateAcknowledged => 'confirmada';

  @override
  String get taskStateAssigned => 'atribuída';

  @override
  String get taskStateCancelled => 'cancelada';

  @override
  String get taskStateCompleted => 'concluída';

  @override
  String get taskStateCreated => 'criada';

  @override
  String get taskStateFailed => 'falhou';

  @override
  String get taskStateInProgress => 'em andamento';

  @override
  String get taskStateReassigned => 'reatribuída';

  @override
  String get telemetryAirQualityNoData =>
      'Nenhum dado de qualidade do ar registrado';

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
      'Contagem de partículas (por 0,1L)';

  @override
  String get telemetryAirQualityPm100Label => 'PM10';

  @override
  String get telemetryAirQualityPm10Label => 'PM1.0';

  @override
  String get telemetryAirQualityPm25Label => 'PM2.5';

  @override
  String get telemetryAirQualityPmEnvironmental =>
      'Material particulado (Ambiental)';

  @override
  String get telemetryAirQualityPmStandard => 'Material particulado (Padrão)';

  @override
  String get telemetryAirQualityTitle => 'Registro de qualidade do ar';

  @override
  String get telemetryAirQualityUnitMicrogram => 'µg/m³';

  @override
  String get telemetryAllNodes => 'Todos os nós';

  @override
  String get telemetryAqiGood => 'Bom';

  @override
  String get telemetryAqiHazardous => 'Perigoso';

  @override
  String get telemetryAqiModerate => 'Moderado';

  @override
  String get telemetryAqiUnhealthy => 'Insalubre';

  @override
  String get telemetryAqiUnhealthySensitive => 'Insalubre (S)';

  @override
  String get telemetryClearAllFilters => 'Limpar todos os filtros';

  @override
  String get telemetryClearData => 'Limpar dados';

  @override
  String get telemetryClearDateFilterTooltip => 'Limpar filtro de data';

  @override
  String get telemetryCo2Excellent => 'Excelente';

  @override
  String get telemetryCo2Fair => 'Razoável';

  @override
  String get telemetryCo2Good => 'Bom';

  @override
  String telemetryCo2Label(String rating) {
    return 'CO₂ - $rating';
  }

  @override
  String get telemetryCo2Poor => 'Ruim';

  @override
  String get telemetryConfigAirQualityDesc =>
      'PM1.0, PM2.5, PM10, contagem de partículas, CO2';

  @override
  String get telemetryConfigAirtimeWarning =>
      'Os dados de telemetria são compartilhados com todos os nós da rede mesh. Intervalos menores aumentam o uso de airtime.';

  @override
  String get telemetryConfigDeviceMetricsDesc =>
      'Nível de bateria, tensão, utilização do canal, air util TX';

  @override
  String get telemetryConfigDisplayFahrenheit => 'Exibir Fahrenheit';

  @override
  String get telemetryConfigDisplayFahrenheitSubtitle =>
      'Mostrar temperatura em Fahrenheit em vez de Celsius';

  @override
  String get telemetryConfigDisplayOnScreen => 'Exibir na tela';

  @override
  String get telemetryConfigDisplayOnScreenSubtitle =>
      'Mostrar dados ambientais na tela do dispositivo';

  @override
  String get telemetryConfigEnabled => 'Ativado';

  @override
  String get telemetryConfigEnvironmentMetricsDesc =>
      'Temperatura, umidade, pressão barométrica, resistência de gás';

  @override
  String get telemetryConfigMinutes => ' minutos';

  @override
  String get telemetryConfigPowerMetricsDesc =>
      'Tensão e corrente dos canais 1-3';

  @override
  String get telemetryConfigSave => 'Salvar';

  @override
  String telemetryConfigSaveError(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get telemetryConfigSaved => 'Configuração de telemetria salva';

  @override
  String get telemetryConfigSectionAirQuality => 'Qualidade do ar';

  @override
  String get telemetryConfigSectionDeviceMetrics => 'Métricas do dispositivo';

  @override
  String get telemetryConfigSectionEnvironmentMetrics => 'Métricas ambientais';

  @override
  String get telemetryConfigSectionPowerMetrics => 'Métricas de energia';

  @override
  String get telemetryConfigTitle => 'Telemetria';

  @override
  String get telemetryConfigUpdateInterval => 'Intervalo de atualização';

  @override
  String get telemetryDateRangeTooltip => 'Intervalo de datas';

  @override
  String get telemetryDetectionClearBadge => 'Limpar';

  @override
  String get telemetryDetectionDescription =>
      'Sensores de detecção reportam movimento e presença';

  @override
  String get telemetryDetectionDetected => 'DETECTADO';

  @override
  String get telemetryDetectionNoData => 'Nenhum evento de sensor registrado';

  @override
  String get telemetryDetectionSensor => 'Sensor de detecção';

  @override
  String get telemetryDetectionTitle => 'Registro do sensor de detecção';

  @override
  String get telemetryDeviceCharging => 'Carregando';

  @override
  String get telemetryDeviceFilterAirUtil => 'Air Util';

  @override
  String get telemetryDeviceFilterBattery => 'Bateria';

  @override
  String get telemetryDeviceFilterChannel => 'Canal';

  @override
  String get telemetryDeviceFilterUptime => 'Tempo Ativo';

  @override
  String get telemetryDeviceFilterVoltage => 'Tensão';

  @override
  String get telemetryDeviceLegendAirUtil => 'Air Util';

  @override
  String get telemetryDeviceLegendBattery => 'Bateria';

  @override
  String get telemetryDeviceLegendChUtil => 'Ch Util';

  @override
  String get telemetryDeviceLegendVoltage => 'Tensão';

  @override
  String telemetryDeviceMetricsAirUtil(String percent) {
    return 'Air $percent%';
  }

  @override
  String telemetryDeviceMetricsChannelUtil(String percent) {
    return 'Ch $percent%';
  }

  @override
  String get telemetryDeviceMetricsTitle => 'Métricas do dispositivo';

  @override
  String telemetryDeviceMetricsVoltageValue(String voltage) {
    return '${voltage}V';
  }

  @override
  String get telemetryDeviceNoMetrics => 'Nenhuma métrica do dispositivo';

  @override
  String get telemetryEndDate => 'Data final';

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
  String get telemetryEnvironmentFilterGas => 'Gás';

  @override
  String get telemetryEnvironmentFilterHumidity => 'Umidade';

  @override
  String get telemetryEnvironmentFilterIaq => 'IAQ';

  @override
  String get telemetryEnvironmentFilterLight => 'Luz';

  @override
  String get telemetryEnvironmentFilterPressure => 'Pressão';

  @override
  String get telemetryEnvironmentFilterTemp => 'Temp';

  @override
  String get telemetryEnvironmentFilterWind => 'Vento';

  @override
  String get telemetryEnvironmentLegendHumidity => 'Umidade';

  @override
  String get telemetryEnvironmentLegendTemperature => 'Temperatura';

  @override
  String get telemetryEnvironmentNoMetrics => 'Nenhuma métrica ambiental';

  @override
  String get telemetryEnvironmentTitle => 'Métricas ambientais';

  @override
  String telemetryError(String error) {
    return 'Erro: $error';
  }

  @override
  String get telemetryExportCsv => 'Exportar CSV';

  @override
  String telemetryExportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get telemetryExporting => 'Exportando...';

  @override
  String telemetryFailedToClear(String error) {
    return 'Falha ao limpar dados: $error';
  }

  @override
  String get telemetryFilterAll => 'Todos';

  @override
  String get telemetryHelp => 'Ajuda';

  @override
  String get telemetryMetricsWillAppear =>
      'As métricas aparecerão quando o dispositivo enviar telemetria';

  @override
  String get telemetryNoMetricsMatchFilters =>
      'Nenhuma métrica corresponde aos filtros';

  @override
  String get telemetryPaxBluetooth => 'Bluetooth';

  @override
  String get telemetryPaxDescription =>
      'O contador PAX detecta dispositivos próximos';

  @override
  String get telemetryPaxNoData => 'Nenhum dado PAX registrado';

  @override
  String get telemetryPaxTitle => 'Registro do contador PAX';

  @override
  String telemetryPaxUptime(String uptime) {
    return 'Tempo Ativo: $uptime';
  }

  @override
  String get telemetryPaxWifi => 'WiFi';

  @override
  String get telemetryPositionAllNodesDescription =>
      'Mostrar posições de todos os nós';

  @override
  String get telemetryPositionAllNodesOption => 'Todos os nós';

  @override
  String get telemetryPositionClearLabel => 'Limpar';

  @override
  String get telemetryPositionClearMessage =>
      'Isso excluirá permanentemente todo o histórico de posições de todos os nós. Não é possível desfazer.';

  @override
  String get telemetryPositionClearTitle => 'Limpar dados de posição';

  @override
  String get telemetryPositionCleared => 'Dados de posição limpos';

  @override
  String telemetryPositionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'posições',
      one: 'posição',
    );
    return '$count $_temp0';
  }

  @override
  String get telemetryPositionDateRange => 'Intervalo de datas';

  @override
  String get telemetryPositionDrawerTitle => 'Nós';

  @override
  String get telemetryPositionExportSubject =>
      'Exportação de posições Socialmesh';

  @override
  String telemetryPositionExportedCount(int count) {
    return '$count posições exportadas';
  }

  @override
  String get telemetryPositionFilterGoodFix => 'Fix válido';

  @override
  String get telemetryPositionFilterMyNode => 'Meu nó';

  @override
  String get telemetryPositionFilterThisWeek => 'Esta semana';

  @override
  String get telemetryPositionFilterToday => 'Hoje';

  @override
  String get telemetryPositionListView => 'Vista em lista';

  @override
  String get telemetryPositionMapStyle => 'Estilo do mapa';

  @override
  String get telemetryPositionMapView => 'Vista no mapa';

  @override
  String get telemetryPositionNoDisplay => 'Nenhuma posição para exibir';

  @override
  String get telemetryPositionNoExportData =>
      'Nenhum dado de posição para exportar';

  @override
  String get telemetryPositionNoHistory => 'Nenhum histórico de posições';

  @override
  String get telemetryPositionNoMatch =>
      'Nenhuma posição corresponde aos filtros';

  @override
  String telemetryPositionNodesCount(int count) {
    return '$count nós';
  }

  @override
  String get telemetryPositionStatDistance => 'Distância';

  @override
  String get telemetryPositionStatNodes => 'Nós';

  @override
  String get telemetryPositionStatPoints => 'Pontos';

  @override
  String get telemetryPositionTitle => 'Posição';

  @override
  String telemetryReadingsCount(int count) {
    return '$count leituras';
  }

  @override
  String get telemetrySearchByNode => 'Buscar por nó';

  @override
  String get telemetrySearchByNodeName => 'Buscar por nome do nó';

  @override
  String get telemetrySettings => 'Configurações';

  @override
  String get telemetryStartDate => 'Data de início';

  @override
  String get telemetryTracerouteClearLabel => 'Limpar';

  @override
  String telemetryTracerouteClearMessage(String scope) {
    return 'Isso excluirá permanentemente todo o histórico de traceroute de $scope. Esta ação não pode ser desfeita.';
  }

  @override
  String get telemetryTracerouteClearTitle => 'Limpar dados de traceroute';

  @override
  String get telemetryTracerouteCleared => 'Dados de traceroute limpos';

  @override
  String get telemetryTracerouteDirectConnection =>
      'Conexão direta — sem hops intermediários';

  @override
  String get telemetryTracerouteEmptyHint =>
      'Envie um traceroute de um nó para ver os caminhos da rede';

  @override
  String telemetryTracerouteExportSubject(String scope) {
    return 'Exportação de traceroute Socialmesh ($scope)';
  }

  @override
  String telemetryTracerouteExportedCount(int count) {
    return '$count traceroutes exportados';
  }

  @override
  String get telemetryTracerouteFilterNoResponse => 'Sem resposta';

  @override
  String get telemetryTracerouteFilterResponse => 'Resposta';

  @override
  String get telemetryTracerouteForwardPath => 'Caminho de ida';

  @override
  String get telemetryTracerouteHopsBack => 'Saltos ←';

  @override
  String get telemetryTracerouteHopsForward => 'Saltos →';

  @override
  String get telemetryTracerouteMoreActions => 'Mais ações';

  @override
  String get telemetryTracerouteNoData => 'Nenhum traceroute registrado';

  @override
  String get telemetryTracerouteNoExportData =>
      'Nenhum dado de traceroute para exportar';

  @override
  String get telemetryTracerouteNoMatch =>
      'Nenhum traceroute corresponde aos filtros';

  @override
  String get telemetryTracerouteNoResponseBadge => 'Sem resposta';

  @override
  String get telemetryTracerouteResponseBadge => 'Resposta';

  @override
  String get telemetryTracerouteReturnPath => 'Caminho de volta';

  @override
  String get telemetryTracerouteTitle => 'Histórico de traceroute';

  @override
  String get telemetryTracerouteTo => 'Para';

  @override
  String get telemetryTryAdjustingFilters =>
      'Tente ajustar sua busca ou filtros';

  @override
  String get timelineActivityWillAppear =>
      'A atividade aparecerá aqui conforme acontece';

  @override
  String get timelineFilterAll => 'Todos';

  @override
  String get timelineFilterMessages => 'Mensagens';

  @override
  String get timelineFilterNodes => 'Nós';

  @override
  String get timelineFilterSignals => 'Sinais';

  @override
  String get timelineFilterWaypoints => 'Pontos de Passagem';

  @override
  String get timelineFriday => 'Sexta-feira';

  @override
  String timelineLastHeard(String timeAgo) {
    return 'Último contato $timeAgo';
  }

  @override
  String get timelineMonday => 'Segunda-feira';

  @override
  String get timelineNoEvents => 'Nenhum evento ainda';

  @override
  String get timelineNoFilterResults =>
      'Nenhum evento corresponde a este filtro';

  @override
  String get timelineNoSearchResults => 'Nenhum evento corresponde à sua busca';

  @override
  String timelineNodeActive(String name) {
    return '$name está ativo';
  }

  @override
  String timelineNodeInactive(String name) {
    return '$name ficou inativo';
  }

  @override
  String timelineRssiValue(double value) {
    return 'RSSI: $value dBm';
  }

  @override
  String get timelineSaturday => 'Sábado';

  @override
  String get timelineSearchHint => 'Buscar eventos';

  @override
  String get timelineShowAllEvents => 'Mostrar todos os eventos';

  @override
  String timelineSnrValue(double value) {
    return 'SNR: $value dB';
  }

  @override
  String get timelineSunday => 'Domingo';

  @override
  String get timelineThursday => 'Quinta-feira';

  @override
  String get timelineTitle => 'Linha do tempo';

  @override
  String get timelineTryDifferent => 'Tente uma busca ou filtro diferente';

  @override
  String get timelineTuesday => 'Terça-feira';

  @override
  String timelineWeakSignal(String name) {
    return 'Sinal fraco de $name';
  }

  @override
  String get timelineWednesday => 'Quarta-feira';

  @override
  String get timelineYesterday => 'Ontem';

  @override
  String get widgetBuilderActionCopyToClipboard =>
      'Copiar para área de transferência';

  @override
  String get widgetBuilderActionEmergencySos => 'SOS de emergência';

  @override
  String get widgetBuilderActionNavigateLabel => 'Navegar';

  @override
  String get widgetBuilderActionNoAction => 'Nenhuma ação';

  @override
  String get widgetBuilderActionOpenUrl => 'Abrir URL';

  @override
  String get widgetBuilderActionRequestPositions => 'Solicitar posições';

  @override
  String get widgetBuilderActionRequestPositionsDesc =>
      'Pedir a todos os nós que reportem sua posição';

  @override
  String get widgetBuilderActionRequestPositionsLabel => 'Solicitar posições';

  @override
  String get widgetBuilderActionSendMessage => 'Enviar mensagem';

  @override
  String get widgetBuilderActionSendMessageDesc =>
      'Abrir compositor para enviar uma mensagem';

  @override
  String get widgetBuilderActionSendMessageLabel => 'Enviar mensagem';

  @override
  String get widgetBuilderActionShareLocation => 'Compartilhar localização';

  @override
  String get widgetBuilderActionShareLocationDesc =>
      'Compartilhar sua posição GPS atual';

  @override
  String get widgetBuilderActionShareLocationLabel =>
      'Compartilhar localização';

  @override
  String get widgetBuilderActionSosAlert => 'Alerta SOS';

  @override
  String get widgetBuilderActionSosAlertDesc =>
      'Enviar alerta de emergência para todos os nós';

  @override
  String get widgetBuilderActionTraceroute => 'Traceroute';

  @override
  String get widgetBuilderActionTracerouteDesc => 'Traçar a rota até um nó';

  @override
  String get widgetBuilderActionTracerouteLabel => 'Traceroute';

  @override
  String get widgetBuilderAddAction => 'Adicionar ação';

  @override
  String get widgetBuilderAddBlock => 'Adicionar bloco';

  @override
  String get widgetBuilderAddElement => 'Adicionar elemento';

  @override
  String get widgetBuilderAddIcon => 'Ícone';

  @override
  String get widgetBuilderAddIconDesc => 'Adicionar um símbolo ou emoji';

  @override
  String widgetBuilderAddItemCount(int count) {
    return 'Adicionar item ($count itens)';
  }

  @override
  String get widgetBuilderAddProgressBar => 'Barra de progresso';

  @override
  String get widgetBuilderAddProgressBarDesc => 'Mostrar um valor visualmente';

  @override
  String get widgetBuilderAddReferenceLines =>
      'Adicionar linhas de referência em valores específicos';

  @override
  String get widgetBuilderAddSpace => 'Espaço';

  @override
  String get widgetBuilderAddSpaceDesc =>
      'Adicionar espaço vazio entre os itens';

  @override
  String get widgetBuilderAddTapAction => 'Adicionar ação de toque...';

  @override
  String get widgetBuilderAddText => 'Texto';

  @override
  String get widgetBuilderAddTextDesc => 'Adicionar um rótulo ou valor';

  @override
  String get widgetBuilderAddToDashboard => 'Adicionar ao painel';

  @override
  String widgetBuilderAddedToDashboard(String name) {
    return '$name adicionado ao painel';
  }

  @override
  String get widgetBuilderAll => 'Todos';

  @override
  String get widgetBuilderAllNodes => 'Todos os nós';

  @override
  String widgetBuilderApprovedSuccess(String name) {
    return '$name aprovado';
  }

  @override
  String get widgetBuilderBindingActiveMeshNodes => 'Nós mesh online';

  @override
  String get widgetBuilderBindingActiveMeshNodesDesc =>
      'Nós contatados nas últimas 2 horas';

  @override
  String get widgetBuilderBindingActiveMeshNodesLegacy =>
      'Nós mesh online (legacy)';

  @override
  String get widgetBuilderBindingActiveMeshNodesLegacyDesc =>
      'Alias para contagem de nós online (retrocompatibilidade)';

  @override
  String get widgetBuilderBindingAirtimeTx => 'Tempo de Antena TX';

  @override
  String get widgetBuilderBindingAirtimeTxDesc =>
      'Utilização de airtime de transmissão';

  @override
  String get widgetBuilderBindingAltitude => 'Altitude';

  @override
  String get widgetBuilderBindingAltitudeDesc =>
      'Altitude acima do nível do mar';

  @override
  String get widgetBuilderBindingBadPacketsRx => 'Pacotes RX inválidos';

  @override
  String get widgetBuilderBindingBadPacketsRxDesc =>
      'Pacotes inválidos recebidos';

  @override
  String get widgetBuilderBindingBatteryLevel => 'Nível da bateria';

  @override
  String get widgetBuilderBindingBatteryLevelDesc =>
      'Percentual da bateria (0-100)';

  @override
  String get widgetBuilderBindingBatteryVoltage => 'Tensão da bateria';

  @override
  String get widgetBuilderBindingBatteryVoltageDesc => 'Tensão da bateria';

  @override
  String get widgetBuilderBindingCategoryAirQuality => 'Qualidade do ar';

  @override
  String get widgetBuilderBindingCategoryDevice => 'Dispositivo';

  @override
  String get widgetBuilderBindingCategoryEnvironment => 'Ambiente';

  @override
  String get widgetBuilderBindingCategoryGps => 'GPS';

  @override
  String get widgetBuilderBindingCategoryMessages => 'Mensagens';

  @override
  String get widgetBuilderBindingCategoryNetwork => 'Rede';

  @override
  String get widgetBuilderBindingCategoryNodeInfo => 'Info do nó';

  @override
  String get widgetBuilderBindingCategoryPower => 'Energia';

  @override
  String get widgetBuilderBindingCh1Current => 'Corrente do canal 1';

  @override
  String get widgetBuilderBindingCh1CurrentDesc =>
      'Corrente do canal de energia 1';

  @override
  String get widgetBuilderBindingCh1Voltage => 'Tensão do canal 1';

  @override
  String get widgetBuilderBindingCh1VoltageDesc =>
      'Tensão do canal de energia 1';

  @override
  String get widgetBuilderBindingCh2Current => 'Corrente do canal 2';

  @override
  String get widgetBuilderBindingCh2CurrentDesc =>
      'Corrente do canal de energia 2';

  @override
  String get widgetBuilderBindingCh2Voltage => 'Tensão do canal 2';

  @override
  String get widgetBuilderBindingCh2VoltageDesc =>
      'Tensão do canal de energia 2';

  @override
  String get widgetBuilderBindingCh3Current => 'Corrente do canal 3';

  @override
  String get widgetBuilderBindingCh3CurrentDesc =>
      'Corrente do canal de energia 3';

  @override
  String get widgetBuilderBindingCh3Voltage => 'Tensão do canal 3';

  @override
  String get widgetBuilderBindingCh3VoltageDesc =>
      'Tensão do canal de energia 3';

  @override
  String get widgetBuilderBindingChannelUtil => 'Utilização do canal';

  @override
  String get widgetBuilderBindingChannelUtilDesc =>
      'Percentual de utilização do canal atual';

  @override
  String get widgetBuilderBindingCo2 => 'CO2';

  @override
  String get widgetBuilderBindingCo2Desc => 'Concentração de CO2';

  @override
  String get widgetBuilderBindingDisplayName => 'Nome de exibição';

  @override
  String get widgetBuilderBindingDisplayNameDesc =>
      'Nome de exibição do nó (nome longo ou curto)';

  @override
  String get widgetBuilderBindingDistance => 'Distância';

  @override
  String get widgetBuilderBindingDistanceDesc => 'Distância até o nó em metros';

  @override
  String get widgetBuilderBindingFirmwareVersion => 'Versão do firmware';

  @override
  String get widgetBuilderBindingFirmwareVersionDesc =>
      'Versão atual do firmware';

  @override
  String get widgetBuilderBindingFirstHeard => 'Primeiro contato';

  @override
  String get widgetBuilderBindingFirstHeardDesc =>
      'Quando o nó foi descoberto pela primeira vez';

  @override
  String get widgetBuilderBindingGroundSpeed => 'Velocidade no solo';

  @override
  String get widgetBuilderBindingGroundSpeedDesc => 'Velocidade no solo';

  @override
  String get widgetBuilderBindingHardwareModel => 'Modelo de hardware';

  @override
  String get widgetBuilderBindingHardwareModelDesc =>
      'Modelo de hardware do dispositivo';

  @override
  String get widgetBuilderBindingHeading => 'Direção';

  @override
  String get widgetBuilderBindingHeadingDesc => 'Rota/direção no solo em graus';

  @override
  String get widgetBuilderBindingHopCount => 'Contagem de hops';

  @override
  String get widgetBuilderBindingHopCountDesc =>
      'Número de hops deste nó (0 = vizinho direto)';

  @override
  String get widgetBuilderBindingHumidity => 'Umidade';

  @override
  String get widgetBuilderBindingHumidityDesc =>
      'Percentual de umidade relativa';

  @override
  String get widgetBuilderBindingIaqIndex => 'Índice IAQ';

  @override
  String get widgetBuilderBindingIaqIndexDesc =>
      'Índice de qualidade do ar interno';

  @override
  String get widgetBuilderBindingLastHeard => 'Último contato';

  @override
  String get widgetBuilderBindingLastHeardDesc =>
      'Quando o nó foi ouvido pela última vez';

  @override
  String get widgetBuilderBindingLatitude => 'Latitude';

  @override
  String get widgetBuilderBindingLatitudeDesc => 'Coordenada GPS de latitude';

  @override
  String get widgetBuilderBindingLightLevel => 'Nível de luz';

  @override
  String get widgetBuilderBindingLightLevelDesc => 'Nível de luz ambiente';

  @override
  String get widgetBuilderBindingLongitude => 'Longitude';

  @override
  String get widgetBuilderBindingLongitudeDesc => 'Coordenada GPS de longitude';

  @override
  String get widgetBuilderBindingNodeName => 'Nome do nó';

  @override
  String get widgetBuilderBindingNodeNameDesc => 'Nome completo do nó';

  @override
  String get widgetBuilderBindingNodeNumber => 'Número do nó';

  @override
  String get widgetBuilderBindingNodeNumberDesc => 'Número único do nó';

  @override
  String get widgetBuilderBindingNodeRole => 'Função do nó';

  @override
  String get widgetBuilderBindingNodeRoleDesc =>
      'Função na mesh (CLIENT, ROUTER, etc.)';

  @override
  String get widgetBuilderBindingNodeStatus => 'Status do nó';

  @override
  String get widgetBuilderBindingNodeStatusDesc =>
      'Mensagem de status personalizada do nó';

  @override
  String get widgetBuilderBindingNodesHeard2h => 'Nós contatados (2h)';

  @override
  String get widgetBuilderBindingNodesHeard2hDesc =>
      'Métrica Meshtastic: nós contatados nas últimas 2 horas';

  @override
  String get widgetBuilderBindingNoiseFloor => 'Piso de ruído';

  @override
  String get widgetBuilderBindingNoiseFloorDesc =>
      'Piso de ruído medido em dBm';

  @override
  String get widgetBuilderBindingPacketsRx => 'Pacotes RX';

  @override
  String get widgetBuilderBindingPacketsRxDesc => 'Total de pacotes recebidos';

  @override
  String get widgetBuilderBindingPacketsTx => 'Pacotes TX';

  @override
  String get widgetBuilderBindingPacketsTxDesc =>
      'Total de pacotes transmitidos';

  @override
  String get widgetBuilderBindingPacketsTxDropped => 'Pacotes TX descartados';

  @override
  String get widgetBuilderBindingPacketsTxDroppedDesc =>
      'Pacotes descartados por fila TX cheia';

  @override
  String get widgetBuilderBindingPm10Large => 'PM10';

  @override
  String get widgetBuilderBindingPm10LargeDesc => 'Material particulado PM10';

  @override
  String get widgetBuilderBindingPm10Small => 'PM1.0';

  @override
  String get widgetBuilderBindingPm10SmallDesc => 'Material particulado PM1.0';

  @override
  String get widgetBuilderBindingPm25 => 'PM2.5';

  @override
  String get widgetBuilderBindingPm25Desc => 'Material particulado PM2.5';

  @override
  String get widgetBuilderBindingPresenceConfidence => 'Confiança de presença';

  @override
  String get widgetBuilderBindingPresenceConfidenceDesc =>
      'Presença inferida: ativo, diminuindo, obsoleto, desconhecido';

  @override
  String get widgetBuilderBindingPressure => 'Pressão';

  @override
  String get widgetBuilderBindingPressureDesc => 'Pressão barométrica';

  @override
  String get widgetBuilderBindingRainfall1h => 'Chuva (1h)';

  @override
  String get widgetBuilderBindingRainfall1hDesc => 'Chuva na última hora';

  @override
  String get widgetBuilderBindingRainfall24h => 'Chuva (24h)';

  @override
  String get widgetBuilderBindingRainfall24hDesc =>
      'Chuva nas últimas 24 horas';

  @override
  String get widgetBuilderBindingRecentMessages => 'Mensagens recentes';

  @override
  String get widgetBuilderBindingRecentMessagesDesc =>
      'Número de mensagens recentes';

  @override
  String get widgetBuilderBindingRssi => 'RSSI';

  @override
  String get widgetBuilderBindingRssiDesc =>
      'Indicador de intensidade do sinal recebido';

  @override
  String get widgetBuilderBindingSatellites => 'Satélites';

  @override
  String get widgetBuilderBindingSatellitesDesc =>
      'Número de satélites GPS visíveis';

  @override
  String get widgetBuilderBindingShortName => 'Nome curto';

  @override
  String get widgetBuilderBindingShortNameDesc =>
      'Identificador de nó com 4 caracteres';

  @override
  String get widgetBuilderBindingSnr => 'SNR';

  @override
  String get widgetBuilderBindingSnrDesc => 'Relação sinal/ruído';

  @override
  String get widgetBuilderBindingSoilMoisture => 'Umidade do solo';

  @override
  String get widgetBuilderBindingSoilMoistureDesc =>
      'Percentual de umidade do solo';

  @override
  String get widgetBuilderBindingSoilTemperature => 'Temperatura do solo';

  @override
  String get widgetBuilderBindingSoilTemperatureDesc => 'Temperatura do solo';

  @override
  String get widgetBuilderBindingTemperature => 'Temperatura';

  @override
  String get widgetBuilderBindingTemperatureDesc => 'Temperatura ambiente';

  @override
  String get widgetBuilderBindingTotalMeshNodes => 'Total de nós mesh';

  @override
  String get widgetBuilderBindingTotalMeshNodesDesc =>
      'Total de nós na rede mesh';

  @override
  String get widgetBuilderBindingTotalNodes => 'Total de nós';

  @override
  String get widgetBuilderBindingTotalNodesDesc =>
      'Número total de nós conhecidos';

  @override
  String get widgetBuilderBindingUnreadMessages => 'Mensagens não lidas';

  @override
  String get widgetBuilderBindingUnreadMessagesDesc =>
      'Número de mensagens não lidas';

  @override
  String get widgetBuilderBindingHardwareModelDistribution =>
      'Hardware Model Distribution';

  @override
  String get widgetBuilderBindingHardwareModelDistributionDesc =>
      'Node count grouped by hardware model';

  @override
  String get widgetBuilderBindingRoleDistribution => 'Role Distribution';

  @override
  String get widgetBuilderBindingRoleDistributionDesc =>
      'Node count grouped by device role';

  @override
  String get widgetBuilderDistributionTemplate => 'Distribution';

  @override
  String get widgetBuilderDistributionTemplateDesc =>
      'Hardware model or role breakdown across your mesh';

  @override
  String get widgetBuilderDistributionEmpty => 'No hardware data available';

  @override
  String get widgetBuilderDistributionEmptyHint =>
      'Connect to the mesh to see device distribution';

  @override
  String get widgetBuilderDistributionUnknown => 'Unknown';

  @override
  String get widgetBuilderDistributionOther => 'Other';

  @override
  String get widgetBuilderBindingUptime => 'Tempo ativo';

  @override
  String get widgetBuilderBindingUptimeDesc =>
      'Tempo ativo do dispositivo em segundos';

  @override
  String get widgetBuilderBindingViaMqtt => 'Via MQTT';

  @override
  String get widgetBuilderBindingViaMqttDesc =>
      'Se este nó foi detectado por transporte MQTT';

  @override
  String get widgetBuilderBindingWindDirection => 'Direção do vento';

  @override
  String get widgetBuilderBindingWindDirectionDesc =>
      'Direção do vento em graus';

  @override
  String get widgetBuilderBindingWindGust => 'Rajada de vento';

  @override
  String get widgetBuilderBindingWindGustDesc =>
      'Velocidade das rajadas de vento';

  @override
  String get widgetBuilderBindingWindSpeed => 'Velocidade do vento';

  @override
  String get widgetBuilderBindingWindSpeedDesc => 'Velocidade atual do vento';

  @override
  String get widgetBuilderBlockActionButton => 'Botão de ação';

  @override
  String get widgetBuilderBlockActionButtonDesc => 'Botão interativo com ação';

  @override
  String get widgetBuilderBlockInfoBlock => 'Bloco de info';

  @override
  String get widgetBuilderBlockInfoBlockDesc => 'Ícone + Rótulo + Valor';

  @override
  String get widgetBuilderBlockMetric => 'Métrica';

  @override
  String get widgetBuilderBlockMetricDesc => 'Valor grande com rótulo';

  @override
  String get widgetBuilderBlockNewRow => 'Nova linha';

  @override
  String get widgetBuilderBlockNewRowDesc =>
      'Adicionar uma linha para mais blocos';

  @override
  String get widgetBuilderBlockStatus => 'Estado';

  @override
  String get widgetBuilderBlockStatusDesc => 'Indicador de status com binding';

  @override
  String get widgetBuilderBoolNo => 'Não';

  @override
  String get widgetBuilderBoolYes => 'Sim';

  @override
  String get widgetBuilderBroadcastSubtitle => 'Transmitir para todos no canal';

  @override
  String get widgetBuilderBrowseMarketplace => 'Explorar Marketplace';

  @override
  String widgetBuilderByAuthor(String author) {
    return 'por $author';
  }

  @override
  String get widgetBuilderCancel => 'Cancelar';

  @override
  String widgetBuilderCannotSaveMessage(String message) {
    return '$message\n\nVolte ao Passo 1 para alterar seu modelo, ou ao Passo 3 para atualizar suas seleções.';
  }

  @override
  String get widgetBuilderCannotSaveTitle => 'Não foi possível salvar o widget';

  @override
  String get widgetBuilderCategoryCharts => 'Gráficos';

  @override
  String get widgetBuilderCategoryDeviceStatus => 'Status do dispositivo';

  @override
  String get widgetBuilderCategoryLocation => 'Localização';

  @override
  String get widgetBuilderCategoryMeshNetwork => 'Rede mesh';

  @override
  String get widgetBuilderCategoryMetrics => 'Métricas';

  @override
  String get widgetBuilderCategoryOther => 'Outros';

  @override
  String get widgetBuilderCategoryUtility => 'Utilidades';

  @override
  String get widgetBuilderCategoryWeather => 'Clima';

  @override
  String get widgetBuilderChooseAction => 'Escolha uma ação para este elemento';

  @override
  String get widgetBuilderChooseColor => 'Escolher cor';

  @override
  String get widgetBuilderColorSectionLabel => 'COR';

  @override
  String get widgetBuilderChooseStyle =>
      'Escolha um estilo que atenda suas necessidades';

  @override
  String get widgetBuilderCreateFirstWidget => 'Crie seu primeiro widget';

  @override
  String get widgetBuilderCreateFirstWidgetDesc =>
      'Use o assistente para criar um widget personalizado com os dados e layout de sua preferência';

  @override
  String get widgetBuilderCreateWidgetTooltip => 'Criar widget';

  @override
  String get widgetBuilderCustomDashboardWidgets =>
      'Widgets personalizados do painel';

  @override
  String get widgetBuilderCustomWidget => 'Widget personalizado';

  @override
  String get widgetBuilderDeleteAction => 'Excluir';

  @override
  String get widgetBuilderDeleteButton => 'Excluir';

  @override
  String get widgetBuilderDeleteWidgetTitle => 'Excluir widget?';

  @override
  String get widgetBuilderDiscard => 'Descartar';

  @override
  String get widgetBuilderDiscardChangesMessage =>
      'Você tem alterações não salvas. Deseja fechar sem salvar?';

  @override
  String get widgetBuilderDiscardChangesTitle => 'Descartar alterações?';

  @override
  String get widgetBuilderDiscoverCommunity =>
      'Descubra widgets criados pela comunidade';

  @override
  String get widgetBuilderDuplicate => 'Duplicar';

  @override
  String get widgetBuilderEdit => 'Editar';

  @override
  String get widgetBuilderElementNotFound => 'Elemento não encontrado';

  @override
  String get widgetBuilderEnablePhoneLocation =>
      'Ative \"Fornecer localização do telefone\" nas Configurações para compartilhar sua posição';

  @override
  String get widgetBuilderEnterThresholdValue => 'Insira o valor limite';

  @override
  String get widgetBuilderEnterWidgetName => 'Insira o nome do widget';

  @override
  String widgetBuilderFailedToApprove(String error) {
    return 'Falha ao aprovar: $error';
  }

  @override
  String widgetBuilderFailedToImport(String error) {
    return 'Falha ao importar: $error';
  }

  @override
  String widgetBuilderFailedToInstall(String error) {
    return 'Falha ao instalar: $error';
  }

  @override
  String widgetBuilderFailedToReject(String error) {
    return 'Falha ao rejeitar: $error';
  }

  @override
  String widgetBuilderFailedToRequestPositions(String error) {
    return 'Falha ao solicitar posições: $error';
  }

  @override
  String widgetBuilderFailedToSaveWidget(String error) {
    return 'Falha ao salvar widget: $error';
  }

  @override
  String widgetBuilderFailedToShareLocation(String error) {
    return 'Falha ao compartilhar localização: $error';
  }

  @override
  String widgetBuilderFailedToSubmit(String error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String get widgetBuilderHelp => 'Ajuda';

  @override
  String get widgetBuilderHeroDescription =>
      'Crie widgets personalizados para exibir dados mesh do seu jeito. Monitore bateria, intensidade do sinal, localização e mais com um olhar.';

  @override
  String get widgetBuilderIconAdd => 'Adicionar';

  @override
  String get widgetBuilderIconAir => 'Ar';

  @override
  String get widgetBuilderIconAlert => 'Alerta';

  @override
  String get widgetBuilderIconAnalytics => 'Análises';

  @override
  String get widgetBuilderIconBluetooth => 'Bluetooth';

  @override
  String get widgetBuilderIconBookmark => 'Favorito';

  @override
  String get widgetBuilderIconCall => 'Chamada';

  @override
  String get widgetBuilderIconCategoryActions => 'Ações';

  @override
  String get widgetBuilderIconCategoryBatteryPower => 'Bateria e energia';

  @override
  String get widgetBuilderIconCategoryCommunication => 'Comunicação';

  @override
  String get widgetBuilderIconCategoryConnectivity => 'Conectividade';

  @override
  String get widgetBuilderIconCategoryDataCharts => 'Dados e gráficos';

  @override
  String get widgetBuilderIconCategoryEnvironment => 'Ambiente';

  @override
  String get widgetBuilderIconCategoryFavorites => 'Favoritos';

  @override
  String get widgetBuilderIconCategoryLocationMaps => 'Localização e mapas';

  @override
  String get widgetBuilderIconCategoryStatus => 'Estado';

  @override
  String get widgetBuilderIconCharging => 'Carregando';

  @override
  String get widgetBuilderIconChart => 'Gráfico';

  @override
  String get widgetBuilderIconChat => 'Chat';

  @override
  String get widgetBuilderIconCheck => 'Verificar';

  @override
  String get widgetBuilderIconCloud => 'Nuvem';

  @override
  String get widgetBuilderIconDelete => 'Excluir';

  @override
  String get widgetBuilderIconDevices => 'Dispositivos';

  @override
  String get widgetBuilderIconDown => 'Baixo';

  @override
  String get widgetBuilderIconEdit => 'Editar';

  @override
  String get widgetBuilderIconError => 'Erro';

  @override
  String get widgetBuilderIconExplore => 'Explorar';

  @override
  String get widgetBuilderIconFlash => 'Flash';

  @override
  String get widgetBuilderIconFull => 'Cheio';

  @override
  String get widgetBuilderIconGps => 'GPS';

  @override
  String get widgetBuilderIconHeart => 'Coração';

  @override
  String get widgetBuilderIconHelp => 'Ajuda';

  @override
  String get widgetBuilderIconHub => 'Hub';

  @override
  String get widgetBuilderIconHumidity => 'Umidade';

  @override
  String get widgetBuilderIconInfo => 'Info';

  @override
  String get widgetBuilderIconLocation => 'Localização';

  @override
  String get widgetBuilderIconMap => 'Mapa';

  @override
  String get widgetBuilderIconMessage => 'Mensagem';

  @override
  String get widgetBuilderIconNavigate => 'Navegar';

  @override
  String get widgetBuilderIconNearMe => 'Perto de mim';

  @override
  String get widgetBuilderIconNetwork => 'Rede';

  @override
  String get widgetBuilderIconNotification => 'Notificação';

  @override
  String get widgetBuilderIconPower => 'Energia';

  @override
  String get widgetBuilderIconPressure => 'Pressão';

  @override
  String get widgetBuilderIconRefresh => 'Atualizar';

  @override
  String get widgetBuilderIconRemove => 'Remover';

  @override
  String get widgetBuilderIconRoute => 'Rota';

  @override
  String get widgetBuilderIconRouter => 'Router';

  @override
  String get widgetBuilderIconSend => 'Enviar';

  @override
  String get widgetBuilderIconSettings => 'Configurações';

  @override
  String get widgetBuilderIconSignal => 'Sinal';

  @override
  String get widgetBuilderIconSpeed => 'Velocidade';

  @override
  String get widgetBuilderIconStar => 'Estrela';

  @override
  String get widgetBuilderIconSun => 'Sol';

  @override
  String get widgetBuilderIconTemperature => 'Temperatura';

  @override
  String get widgetBuilderIconThumbsUp => 'Curtir';

  @override
  String get widgetBuilderIconTimeline => 'Linha do tempo';

  @override
  String get widgetBuilderIconUp => 'Cima';

  @override
  String get widgetBuilderIconWarning => 'Aviso';

  @override
  String get widgetBuilderIconWifi => 'WiFi';

  @override
  String get widgetBuilderImportButton => 'Importar';

  @override
  String get widgetBuilderImportEditFirst => 'Editar primeiro';

  @override
  String get widgetBuilderImportFailed2 => 'Falha na importação';

  @override
  String get widgetBuilderImportGoBack => 'Voltar';

  @override
  String get widgetBuilderImportInfoNotice =>
      'Este widget será adicionado aos seus widgets personalizados. Você pode editá-lo a qualquer momento.';

  @override
  String get widgetBuilderImportNoData => 'Nenhum dado de widget fornecido';

  @override
  String get widgetBuilderImportNotFound =>
      'Widget não encontrado ou foi excluído';

  @override
  String get widgetBuilderImportPreview => 'Pré-visualizar';

  @override
  String get widgetBuilderImportSize => 'Tamanho';

  @override
  String get widgetBuilderImportTags => 'Etiquetas';

  @override
  String get widgetBuilderImportTitle => 'Importar widget';

  @override
  String get widgetBuilderImportedSuccess => 'Widget importado com sucesso';

  @override
  String get widgetBuilderImportedSuccessAction =>
      'Widget importado com sucesso';

  @override
  String widgetBuilderInstalledSuccess(String name) {
    return '$name instalado!';
  }

  @override
  String get widgetBuilderKeepCurrent => 'Manter atual';

  @override
  String get widgetBuilderLabelAccent => 'Destaque';

  @override
  String get widgetBuilderLabelBindTo => 'Vincular a';

  @override
  String get widgetBuilderLabelGap => 'Espaço entre itens';

  @override
  String get widgetBuilderLabelHintExample => 'ex. \"Aviso\", \"Crítico\"';

  @override
  String get widgetBuilderLabelIcon => 'Ícone';

  @override
  String get widgetBuilderLabelIconColor => 'Cor do ícone';

  @override
  String get widgetBuilderLabelMax => 'Máx';

  @override
  String get widgetBuilderLabelMin => 'Mín';

  @override
  String get widgetBuilderLabelScreen => 'Tela';

  @override
  String get widgetBuilderLabelShape => 'Forma';

  @override
  String get widgetBuilderLabelText => 'Texto';

  @override
  String get widgetBuilderLabelType => 'Tipo';

  @override
  String get widgetBuilderLabelUrl => 'URL';

  @override
  String get widgetBuilderLargeMaxTwoRows =>
      'Widgets grandes permitem máx. 2 linhas';

  @override
  String get widgetBuilderLargeOnlyTwoRowsMax =>
      'Widgets grandes permitem apenas 2 linhas máx.';

  @override
  String get widgetBuilderLivePreview => 'Pré-visualização ao vivo';

  @override
  String get widgetBuilderLocationSharedMesh =>
      'Localização compartilhada com a rede mesh';

  @override
  String get widgetBuilderLocationSharedRecently =>
      'Localização compartilhada recentemente — aguarde antes de compartilhar novamente';

  @override
  String widgetBuilderLocationSharedWithNode(String name) {
    return 'Localização compartilhada com $name';
  }

  @override
  String get widgetBuilderMakeUnique =>
      'Considere tornar seu widget mais exclusivo antes de enviar.';

  @override
  String get widgetBuilderMapView => 'Vista do mapa';

  @override
  String get widgetBuilderMarketplace => 'Marketplace';

  @override
  String get widgetBuilderMarketplaceAlreadyInstalled => 'Já instalado';

  @override
  String get widgetBuilderMarketplaceApprove => 'Aprovar';

  @override
  String get widgetBuilderMarketplaceCancel => 'Cancelar';

  @override
  String get widgetBuilderMarketplaceDescription => 'Descrição';

  @override
  String widgetBuilderMarketplaceRatingWithCount(String rating, int count) {
    return '$rating ($count)';
  }

  @override
  String get widgetBuilderMarketplaceEnterReason => 'Insira o motivo...';

  @override
  String widgetBuilderMarketplaceFailedLoadPending(String error) {
    return 'Falha ao carregar widgets pendentes: $error';
  }

  @override
  String get widgetBuilderMarketplaceFailedLoadCategory =>
      'Falha ao carregar categoria';

  @override
  String get widgetBuilderMarketplaceFailedNewest =>
      'Falha ao carregar widgets mais recentes';

  @override
  String get widgetBuilderMarketplaceFailedPopular =>
      'Falha ao carregar widgets populares';

  @override
  String get widgetBuilderMarketplaceFavoritesHint =>
      'Toque no ícone de coração em qualquer widget para adicioná-lo aqui';

  @override
  String widgetBuilderMarketplaceFavoritesWithCount(int count) {
    return 'Favoritos ($count)';
  }

  @override
  String get widgetBuilderMarketplaceHelpTooltip => 'Ajuda';

  @override
  String get widgetBuilderMarketplaceInstallWidget => 'Instalar widget';

  @override
  String widgetBuilderMarketplaceDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String widgetBuilderMarketplaceHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String widgetBuilderMarketplaceInstallsCount(int count) {
    return '$count instalações';
  }

  @override
  String get widgetBuilderMarketplaceJustNow => 'Agora mesmo';

  @override
  String widgetBuilderMarketplaceMinutesAgo(int count) {
    return '${count}m atrás';
  }

  @override
  String get widgetBuilderMarketplaceLoadingPreview => 'Carregando prévia...';

  @override
  String get widgetBuilderMarketplaceNoFavorites => 'Nenhum widget favorito';

  @override
  String get widgetBuilderMarketplaceNoFeatured => 'Nenhum widget em destaque';

  @override
  String get widgetBuilderMarketplaceNoNew => 'Nenhum widget novo';

  @override
  String get widgetBuilderMarketplaceNoPending =>
      'Nenhum widget aguardando aprovação';

  @override
  String get widgetBuilderMarketplaceNoPopular => 'Nenhum widget popular';

  @override
  String get widgetBuilderMarketplaceNoWidgets => 'Nenhum widget disponível';

  @override
  String get widgetBuilderMarketplaceNoWidgetsFound =>
      'Nenhum widget encontrado';

  @override
  String get widgetBuilderMarketplaceNoWidgetsInCategory =>
      'Nenhum widget nesta categoria';

  @override
  String get widgetBuilderMarketplaceNotAuthenticated => 'Não autenticado';

  @override
  String get widgetBuilderMarketplacePending => 'PENDENTE';

  @override
  String get widgetBuilderMarketplacePleaseEnterReason => 'Insira um motivo';

  @override
  String get widgetBuilderMarketplaceProcessing => 'Processando...';

  @override
  String get widgetBuilderMarketplaceRejectButton => 'Rejeitar';

  @override
  String get widgetBuilderMarketplaceRejectWidget => 'Rejeitar widget';

  @override
  String get widgetBuilderMarketplaceRequiresInternet =>
      'A instalação de widgets requer conexão com a internet.';

  @override
  String get widgetBuilderMarketplaceRetry => 'Tentar novamente';

  @override
  String get widgetBuilderMarketplaceSearchHint => 'Buscar widgets...';

  @override
  String get widgetBuilderMarketplaceShareTooltip => 'Compartilhar widget';

  @override
  String get widgetBuilderMarketplaceSharingRequiresInternet =>
      'O compartilhamento de widgets requer conexão com a internet.';

  @override
  String get widgetBuilderMarketplaceTabCategories => 'Categorias';

  @override
  String get widgetBuilderMarketplaceTabFavorites => 'Favoritos';

  @override
  String get widgetBuilderMarketplaceTabFeatured => 'Destaques';

  @override
  String get widgetBuilderMarketplaceTabNew => 'Novos';

  @override
  String get widgetBuilderMarketplaceTabPopular => 'Populares';

  @override
  String get widgetBuilderMarketplaceTags => 'Etiquetas';

  @override
  String get widgetBuilderMarketplaceTitle => 'Marketplace de widgets';

  @override
  String get widgetBuilderMarketplaceUnableToLoad =>
      'Não foi possível carregar o marketplace';

  @override
  String get widgetBuilderMarketplaceWidgetApproval => 'Aprovação de widget';

  @override
  String get widgetBuilderMediumOnlyOneRow =>
      'Widgets médios permitem apenas 1 linha';

  @override
  String get widgetBuilderMediumOnlyOneRowLimit =>
      'Widgets médios permitem apenas 1 linha';

  @override
  String get widgetBuilderMerge => 'Mesclar';

  @override
  String get widgetBuilderMyWidgets => 'Meus widgets';

  @override
  String get widgetBuilderNameHint => 'ex. Meu widget de bateria';

  @override
  String get widgetBuilderNewWidget => 'Novo widget';

  @override
  String get widgetBuilderNoAdditionalOptions => 'Sem opções adicionais';

  @override
  String get widgetBuilderNoDataBinding =>
      'Sem vínculo de dados - use texto estático';

  @override
  String get widgetBuilderNoDataSelected => 'Nenhum dado selecionado';

  @override
  String get widgetBuilderNoIconsFound => 'Nenhum ícone encontrado';

  @override
  String get widgetBuilderNoInfoSelected => 'Nenhuma info selecionada';

  @override
  String get widgetBuilderNoLocationDataSelected =>
      'Nenhum dado de localização selecionado';

  @override
  String get widgetBuilderNoSensorDataSelected =>
      'Nenhum dado de sensor selecionado';

  @override
  String get widgetBuilderNone => 'Nenhum';

  @override
  String get widgetBuilderOk => 'OK';

  @override
  String get widgetBuilderOptions => 'Opções';

  @override
  String get widgetBuilderPickNodeThenSend => 'Escolha o nó e envie';

  @override
  String get widgetBuilderPickNodeToTrace => 'Escolha o nó para rastrear';

  @override
  String get widgetBuilderPrebuiltWidgets =>
      'Widgets prontos para personalizar';

  @override
  String get widgetBuilderQuickMessageSheet => 'Painel de mensagens rápidas';

  @override
  String get widgetBuilderQuickStartTemplates => 'Modelos de início rápido';

  @override
  String widgetBuilderRejectedSuccess(String name) {
    return '$name rejeitado';
  }

  @override
  String get widgetBuilderRemoveExtraRows =>
      'Remova as linhas extras - o formato médio permite apenas 1 linha';

  @override
  String get widgetBuilderRemoveFromDashboard => 'Remover do painel';

  @override
  String widgetBuilderRemovedFromDashboard(String name) {
    return '$name removido do painel';
  }

  @override
  String get widgetBuilderReviewGuidelines => 'Diretrizes de revisão';

  @override
  String get widgetBuilderReviewGuidelinesText =>
      '• O widget será avaliado pela qualidade\n• Widgets semelhantes podem ser rejeitados\n• Você será creditado como autor';

  @override
  String get widgetBuilderSave => 'Salvar';

  @override
  String get widgetBuilderSearchIcons => 'Buscar ícones...';

  @override
  String get widgetBuilderSearchVariables => 'Buscar variáveis...';

  @override
  String get widgetBuilderSectionActionBlocks => 'Blocos de ação';

  @override
  String get widgetBuilderSectionDisplayBlocks => 'Blocos de exibição';

  @override
  String get widgetBuilderSectionEmergency => 'EMERGÊNCIA';

  @override
  String get widgetBuilderSectionLayout => 'Layout';

  @override
  String get widgetBuilderSectionMessaging => 'MENSAGENS';

  @override
  String get widgetBuilderSectionNetwork => 'REDE';

  @override
  String get widgetBuilderSelectAnAction => 'Selecione uma ação';

  @override
  String get widgetBuilderSelectIcon => 'Selecionar ícone';

  @override
  String get widgetBuilderSelectVariable => 'Selecionar variável';

  @override
  String get widgetBuilderShareInfoText =>
      'Escaneie este código QR no SocialMesh para importar este widget';

  @override
  String get widgetBuilderShareLocationWith => 'Compartilhar localização com';

  @override
  String get widgetBuilderShareMessage => 'Confira este widget no SocialMesh!';

  @override
  String widgetBuilderShareSubject(String name) {
    return 'Widget SocialMesh: $name';
  }

  @override
  String get widgetBuilderShareTitle => 'Compartilhar widget';

  @override
  String get widgetBuilderShowChannelPicker => 'Mostrar seletor de canal';

  @override
  String get widgetBuilderShowChannelPickerDesc =>
      'Permitir ao usuário escolher o canal';

  @override
  String get widgetBuilderShowNodePickerFirst => 'Mostrar seletor de nó';

  @override
  String get widgetBuilderShowNodePickerFirstDesc =>
      'Permitir ao usuário escolher o nó para enviar';

  @override
  String get widgetBuilderShowNodePickerTrace => 'Mostrar seletor de nó';

  @override
  String get widgetBuilderShowNodePickerTraceDesc =>
      'Permitir ao usuário escolher o nó para rastrear';

  @override
  String get widgetBuilderSignInAction => 'Entrar';

  @override
  String get widgetBuilderSignInToShare => 'Entre para compartilhar widgets';

  @override
  String get widgetBuilderSignInToSubmit => 'Entre para enviar widgets';

  @override
  String get widgetBuilderSimilarWidgetExists =>
      'Um widget semelhante já existe no marketplace:';

  @override
  String widgetBuilderSimilarWidgetExistsError(String name) {
    return 'Widget semelhante já existe: $name';
  }

  @override
  String get widgetBuilderSimilarWidgetFound => 'Widget semelhante encontrado';

  @override
  String get widgetBuilderSizeCustom => 'Tamanho personalizado';

  @override
  String get widgetBuilderSizeLarge => 'Grande (2x2)';

  @override
  String get widgetBuilderSizeMedium => 'Médio (2x1)';

  @override
  String get widgetBuilderSubmitButton => 'Enviar';

  @override
  String get widgetBuilderSubmitCancel => 'Cancelar';

  @override
  String get widgetBuilderSubmitTitle => 'Enviar ao marketplace';

  @override
  String get widgetBuilderSubmitToMarketplace => 'Enviar ao marketplace';

  @override
  String widgetBuilderSubmittedForReview(String name) {
    return '$name enviado para revisão';
  }

  @override
  String get widgetBuilderSwitch => 'Alternar';

  @override
  String widgetBuilderSwitchTemplateIncompatible(
    String templateName,
    String newDataType,
  ) {
    return '\"$templateName\" usa $newDataType, então suas seleções atuais não serão utilizadas.';
  }

  @override
  String widgetBuilderSwitchTemplateItemCount(int count, String dataType) {
    return 'Você tem $count $dataType selecionados.';
  }

  @override
  String get widgetBuilderSwitchTemplateTitle => 'Trocar modelo?';

  @override
  String get widgetBuilderTemplateBatteryStatus => 'Status da bateria';

  @override
  String get widgetBuilderTemplateBatteryStatusDesc =>
      'Monitore os níveis de carga';

  @override
  String get widgetBuilderTemplateEnvironment => 'Ambiente';

  @override
  String get widgetBuilderTemplateEnvironmentDesc => 'Clima e sensores';

  @override
  String get widgetBuilderTemplateGpsPosition => 'Posição GPS';

  @override
  String get widgetBuilderTemplateGpsPositionDesc =>
      'Rastreamento de localização';

  @override
  String get widgetBuilderTemplateNetworkOverview => 'Visão geral da rede';

  @override
  String get widgetBuilderTemplateNetworkOverviewDesc => 'A mesh em um relance';

  @override
  String get widgetBuilderTemplateSignalStrength => 'Intensidade do sinal';

  @override
  String get widgetBuilderTemplateSignalStrengthDesc =>
      'Monitore a conectividade';

  @override
  String get widgetBuilderThresholdLines => 'Linhas de limite';

  @override
  String get widgetBuilderToggleToolbox => 'Alternar ferramentas';

  @override
  String get widgetBuilderTraceRouteToNode => 'Traçar rota até o nó';

  @override
  String get widgetBuilderTypeDecimal => 'decimal';

  @override
  String get widgetBuilderTypeGauge => 'Medidor';

  @override
  String get widgetBuilderTypeGaugeDesc => 'Medidor visual grande';

  @override
  String get widgetBuilderTypeGraph => 'Gráfico';

  @override
  String get widgetBuilderTypeGraphDesc => 'Gráficos ao longo do tempo';

  @override
  String get widgetBuilderTypeInfoCard => 'Cartão de info';

  @override
  String get widgetBuilderTypeInfoCardDesc => 'Texto e detalhes';

  @override
  String get widgetBuilderTypeLocation => 'Localização';

  @override
  String get widgetBuilderTypeLocationDesc => 'Coordenadas GPS';

  @override
  String get widgetBuilderTypeNumber => 'número';

  @override
  String get widgetBuilderTypeQuickActions => 'Ações rápidas';

  @override
  String get widgetBuilderTypeQuickActionsDesc => 'Toque para acionar';

  @override
  String get widgetBuilderTypeStatusDisplay => 'Exibição de status';

  @override
  String get widgetBuilderTypeStatusDisplayDesc =>
      'Valores com barras de progresso';

  @override
  String get widgetBuilderTypeText => 'texto';

  @override
  String get widgetBuilderTypeTime => 'hora';

  @override
  String get widgetBuilderTypeValue => 'valor';

  @override
  String get widgetBuilderTypeYesNo => 'sim/não';

  @override
  String get widgetBuilderUnableToGetLocation =>
      'Não foi possível obter sua localização';

  @override
  String get widgetBuilderUse => 'Usar';

  @override
  String get widgetBuilderValidationActionsRequired =>
      'Ações rápidas requer pelo menos uma ação selecionada. Você tem vínculos de dados mas nenhuma ação.';

  @override
  String get widgetBuilderValidationDataRequired =>
      'Este modelo requer vínculos de dados. Você tem ações selecionadas mas nenhum dado.';

  @override
  String get widgetBuilderView => 'Visualizar';

  @override
  String get widgetBuilderWhatShouldHappen => 'O que deve acontecer ao tocar?';

  @override
  String get widgetBuilderWhatToAdd => 'O que você gostaria de adicionar?';

  @override
  String get widgetBuilderWhatWouldYouLikeToDo =>
      'O que você gostaria de fazer?';

  @override
  String get widgetBuilderWidgetCreated => 'Widget criado!';

  @override
  String get widgetBuilderWidgetName => 'Nome do widget';

  @override
  String get widgetBuilderWidgetTypes => 'Tipos de widget';

  @override
  String get widgetBuilderWidgetUpdated => 'Widget atualizado!';

  @override
  String get widgetBuilderWizardStep1Subtitle =>
      'Como você quer que seu widget apareça?';

  @override
  String get widgetBuilderWizardStep1Title => 'Escolha um estilo';

  @override
  String get widgetBuilderWizardStep2Subtitle => 'Dê um nome memorável';

  @override
  String get widgetBuilderWizardStep2Title => 'Nomeie seu widget';

  @override
  String get widgetBuilderWizardStep3SubtitleActions =>
      'Quais ações você quer acessar rapidamente?';

  @override
  String get widgetBuilderWizardStep3SubtitleData =>
      'Quais informações você quer ver?';

  @override
  String get widgetBuilderWizardStep3TitleActions => 'Escolha as ações';

  @override
  String get widgetBuilderWizardStep3TitleData => 'Escolha seus dados';

  @override
  String get widgetBuilderWizardStep4Subtitle => 'Personalize cores e layout';

  @override
  String get widgetBuilderWizardStep4Title => 'Deixe do seu jeito';

  @override
  String get worldMeshAddToFavorites => 'Adicionar aos favoritos';

  @override
  String get worldMeshAddedToFavorites => 'Adicionado aos favoritos';

  @override
  String get worldMeshBadgeActive => 'ATIVO';

  @override
  String get worldMeshCoordinatesCopied =>
      'Coordenadas copiadas para a área de transferência';

  @override
  String get worldMeshCopyCoordinates => 'Copiar coordenadas';

  @override
  String get worldMeshCopyCoordinatesSubtitle => 'Ambas as coordenadas A e B';

  @override
  String get worldMeshCopyId => 'Copiar ID';

  @override
  String get worldMeshCopySummary => 'Copiar resumo';

  @override
  String get worldMeshErrorTitle => 'Não foi possível carregar o mapa mesh';

  @override
  String get worldMeshExitMeasureMode => 'Sair do modo medição';

  @override
  String get worldMeshFavoritesTooltip => 'Favoritos';

  @override
  String worldMeshFilterActiveCount(int count) {
    return '$count ativos';
  }

  @override
  String get worldMeshFilterAny => 'Qualquer';

  @override
  String get worldMeshFilterBatteryInfo => 'Info da bateria';

  @override
  String get worldMeshFilterCatBatteryInfo => 'Info da bateria';

  @override
  String get worldMeshFilterCatEnvSensors => 'Sensores ambientais';

  @override
  String get worldMeshFilterCatFirmware => 'Firmware';

  @override
  String get worldMeshFilterCatHardware => 'Hardware';

  @override
  String get worldMeshFilterCatModemPreset => 'Preset do modem';

  @override
  String get worldMeshFilterCatRegion => 'Região';

  @override
  String get worldMeshFilterCatRole => 'Função';

  @override
  String get worldMeshFilterCatStatus => 'Estado';

  @override
  String get worldMeshFilterClearAll => 'Limpar tudo';

  @override
  String get worldMeshFilterEnvironmentSensors => 'Sensores ambientais';

  @override
  String get worldMeshFilterFirmwareVersion => 'Versão do firmware';

  @override
  String get worldMeshFilterHardwareModel => 'Modelo de hardware';

  @override
  String get worldMeshFilterModemPreset => 'Preset do modem';

  @override
  String get worldMeshFilterNo => 'Não';

  @override
  String get worldMeshFilterNoOptions => 'Nenhuma opção disponível';

  @override
  String worldMeshFilterNodeCount(int filteredCount, int totalCount) {
    return '$filteredCount de $totalCount nós';
  }

  @override
  String get worldMeshFilterNodeRole => 'Função do nó';

  @override
  String worldMeshFilterNodesWithBattery(int count) {
    return '$count nós com dados de bateria';
  }

  @override
  String worldMeshFilterNodesWithSensors(int count) {
    return '$count nós com sensores';
  }

  @override
  String get worldMeshFilterRegion => 'Região';

  @override
  String get worldMeshFilterStatus => 'Estado';

  @override
  String get worldMeshFilterStatusActive => 'Ativo (≤2m)';

  @override
  String get worldMeshFilterStatusFading => 'Enfraquecendo (2-10m)';

  @override
  String get worldMeshFilterStatusInactive => 'Inativo (10-60m)';

  @override
  String get worldMeshFilterStatusUnknown => 'Desconhecido (>60m)';

  @override
  String get worldMeshFilterTitle => 'Filtrar nós';

  @override
  String get worldMeshFilterTooltip => 'Filtrar nós';

  @override
  String get worldMeshFilterYes => 'Sim';

  @override
  String get worldMeshFocus => 'Focar';

  @override
  String worldMeshFsplSubtitle(String db) {
    return 'FSPL: $db dB';
  }

  @override
  String get worldMeshHelp => 'Ajuda';

  @override
  String get worldMeshInfoAltitude => 'Altitude';

  @override
  String get worldMeshInfoCoordinates => 'Coordenadas';

  @override
  String get worldMeshInfoFirmware => 'Firmware';

  @override
  String get worldMeshInfoHardware => 'Hardware';

  @override
  String get worldMeshInfoLocalNodes => 'Nós locais';

  @override
  String get worldMeshInfoModem => 'Modem';

  @override
  String get worldMeshInfoPrecision => 'Precisão';

  @override
  String get worldMeshInfoRegion => 'Região';

  @override
  String get worldMeshInfoRole => 'Função';

  @override
  String worldMeshLastSeen(String time) {
    return 'Visto por último: $time';
  }

  @override
  String get worldMeshLegendActive => 'Ativo (<1h)';

  @override
  String get worldMeshLegendIdle => 'Inativo (1-24h)';

  @override
  String get worldMeshLegendOffline => 'Offline (>24h)';

  @override
  String get worldMeshLinkBudgetCopied =>
      'Link budget copiado para a área de transferência';

  @override
  String get worldMeshLoadingNodeInfo => 'Carregando info do nó...';

  @override
  String get worldMeshLongPressHint => 'Pressione e segure para ações';

  @override
  String get worldMeshLosAnalysis => 'Análise LOS';

  @override
  String worldMeshLosBulgeAndFresnel(String bulge, String fresnel) {
    return 'Curvatura: ${bulge}m · F1: ${fresnel}m';
  }

  @override
  String get worldMeshLosSubtitle =>
      'Curvatura da Terra + verificação da zona de Fresnel';

  @override
  String worldMeshLosVerdict(String verdict) {
    return 'LOS: $verdict';
  }

  @override
  String get worldMeshMapStyleDark => 'Mapa escuro';

  @override
  String get worldMeshMapStyleLight => 'Mapa claro';

  @override
  String get worldMeshMapStyleSatellite => 'Satélite';

  @override
  String get worldMeshMapStyleTerrain => 'Terreno';

  @override
  String get worldMeshMeasurePointA => 'A';

  @override
  String get worldMeshMeasurePointB => 'B';

  @override
  String get worldMeshMeasureTapA => 'Toque em um nó ou no mapa para o ponto A';

  @override
  String get worldMeshMeasureTapB => 'Toque em um nó ou no mapa para o ponto B';

  @override
  String get worldMeshMeasurementActions => 'Ações de medição';

  @override
  String get worldMeshMeasurementCopied =>
      'Medição copiada para a área de transferência';

  @override
  String worldMeshMoreGateways(int count) {
    return ' +$count mais';
  }

  @override
  String get worldMeshNewMeasurement => 'Nova medição';

  @override
  String get worldMeshNodeIdCopied => 'ID do nó copiado';

  @override
  String get worldMeshOpenMidpointInMaps => 'Abrir ponto médio no Mapas';

  @override
  String get worldMeshOpenMidpointSubtitle => 'Abrir em app de mapas externo';

  @override
  String get worldMeshRefresh => 'Atualizar';

  @override
  String get worldMeshRefreshing => 'Atualizando dados do world mesh...';

  @override
  String get worldMeshRemoveFromFavorites => 'Remover dos favoritos';

  @override
  String get worldMeshRemovedFromFavorites => 'Removido dos favoritos';

  @override
  String get worldMeshRetry => 'Tentar novamente';

  @override
  String get worldMeshRfLinkBudget => 'Orçamento de Ligação RF';

  @override
  String worldMeshRfLinkBudgetClipboard(
    String distance,
    String frequency,
    String pathLoss,
    String linkMargin,
  ) {
    return 'RF Link Budget (perda no espaço livre)\nDistância: $distance\nFrequência: $frequency\nPerda de percurso: $pathLoss\nMargem de enlace: $linkMargin';
  }

  @override
  String get worldMeshScrollForMore => 'Role para mais...';

  @override
  String get worldMeshSearchHint => 'Buscar um nó';

  @override
  String worldMeshSearchResultCount(int count) {
    return '$count resultados';
  }

  @override
  String get worldMeshSectionDevice => 'Dispositivo';

  @override
  String get worldMeshSectionDeviceMetrics => 'Métricas do dispositivo';

  @override
  String get worldMeshSectionEnvironment => 'Ambiente';

  @override
  String worldMeshSectionNeighbors(int count) {
    return 'Vizinhos ($count)';
  }

  @override
  String get worldMeshSectionPosition => 'Posição';

  @override
  String worldMeshSectionSeenBy(int count) {
    return 'Visto por ($count gateways)';
  }

  @override
  String get worldMeshStatsFiltered => 'filtrados';

  @override
  String get worldMeshStatsTotal => 'total';

  @override
  String get worldMeshStatsVisible => 'visíveis';

  @override
  String get worldMeshSwapAB => 'Trocar A ↔ B';

  @override
  String get worldMeshSwapSubtitle => 'Inverter direção da medição';

  @override
  String worldMeshTimeHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String get worldMeshTimeJustNow => 'agora mesmo';

  @override
  String worldMeshTimeMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String get worldMeshTitle => 'Mapa mundial';

  @override
  String worldMeshUptimeLabel(String uptime) {
    return 'Tempo Ativo: $uptime';
  }

  @override
  String get deepLinkLoadingSignal => 'Carregando sinal';

  @override
  String deepLinkErrorLoadingSignal(String error) {
    return 'Erro ao carregar sinal: $error';
  }

  @override
  String get deepLinkSignalNotFound => 'Sinal não encontrado';

  @override
  String get deepLinkLoadingFlight => 'Carregando voo';

  @override
  String deepLinkErrorLoadingFlight(String error) {
    return 'Erro ao carregar voo: $error';
  }

  @override
  String get deepLinkFlightNotFound => 'Voo não encontrado';

  @override
  String get deepLinkImportChannel => 'Importar canal';

  @override
  String deepLinkErrorLoadingChannel(String error) {
    return 'Erro ao carregar canal: $error';
  }

  @override
  String get deepLinkChannelNotAvailable => 'Canal não disponível';

  @override
  String get deepLinkChannelNotAvailableDescription =>
      'Você pode não ter acesso a este canal,\nou o proprietário precisa compartilhá-lo novamente.';

  @override
  String get deepLinkJoinChannel => 'Entrar no canal';

  @override
  String get deepLinkJoiningChannel => 'Entrando no canal...';

  @override
  String get deepLinkInviteExpired => 'Este convite expirou';

  @override
  String get deepLinkInviteRevoked => 'Este convite foi revogado';

  @override
  String get deepLinkInviteUsageLimitReached =>
      'Este convite atingiu o limite de uso';

  @override
  String get deepLinkInviteLinkInvalid => 'Link de convite inválido';

  @override
  String get deepLinkChannelNoLongerExists => 'Este canal não existe mais';

  @override
  String get deepLinkInviteNotFound => 'Convite não encontrado';

  @override
  String get deepLinkPleaseSignIn => 'Faça login para entrar';

  @override
  String get deepLinkFailedToJoinChannel => 'Falha ao entrar no canal';

  @override
  String get deepLinkLoadingWidget => 'Carregando widget';

  @override
  String deepLinkErrorLoadingWidget(String error) {
    return 'Erro ao carregar widget: $error';
  }

  @override
  String get deepLinkSomethingWentWrong => 'Algo deu errado';

  @override
  String deepLinkProfileTitle(String displayName) {
    return '@$displayName';
  }

  @override
  String get deepLinkCloudServicesNotAvailable =>
      'Serviços em nuvem ainda não disponíveis';

  @override
  String deepLinkErrorLookingUpUser(String error) {
    return 'Erro ao buscar usuário: $error';
  }

  @override
  String deepLinkUserNotFound(String displayName) {
    return 'Usuário \"@$displayName\" não encontrado';
  }

  @override
  String get blockedRouteDeviceRequired => 'Dispositivo necessário';

  @override
  String get blockedRouteConnectDevice =>
      'Conecte um dispositivo para acessar esta tela';

  @override
  String get blockedRouteDeviceReset => 'Dispositivo redefinido';

  @override
  String get blockedRouteDeviceNotConnected => 'Dispositivo não conectado';

  @override
  String get blockedRouteDeviceResetDescription =>
      'Seu dispositivo foi redefinido de fábrica ou substituído.\n\nVá em Ajustes → Bluetooth, esqueça o dispositivo Meshtastic e escaneie novamente.';

  @override
  String get blockedRouteScanForDevices => 'Buscar dispositivos';

  @override
  String get blockedRouteConnectDeviceButton => 'Conectar dispositivo';

  @override
  String get deepLinkWidgetNotFound => 'Widget não encontrado';

  @override
  String get deepLinkAlreadyHaveChannel => 'Você já possui este canal';

  @override
  String get transformableTextDeleteTitle => 'Excluir texto?';

  @override
  String get transformableTextDeleteMessage =>
      'Isso removerá a sobreposição de texto.';

  @override
  String get transformableTextDeleteConfirm => 'Excluir';

  @override
  String get transformableTextDone => 'Concluído';

  @override
  String get transformableTextHint => 'Digite algo...';

  @override
  String get qrSharePreparingLink => 'Preparando link de compartilhamento...';

  @override
  String get qrShareSharing => 'Compartilhando...';

  @override
  String get qrShareShareLink => 'Compartilhar link';

  @override
  String get qrShareCopyLink => 'Copiar link';

  @override
  String qrShareFailedToShare(String error) {
    return 'Falha ao compartilhar: $error';
  }

  @override
  String get qrShareLinkCopied => 'Link copiado para a área de transferência';

  @override
  String get legalDocumentTermsOfService => 'Termos de serviço';

  @override
  String get legalDocumentPrivacyPolicy => 'Política de privacidade';

  @override
  String get legalDocumentHelpAndSupport => 'Ajuda e suporte';

  @override
  String get legalDocumentDocumentation => 'Documentação';

  @override
  String get legalDocumentFaq => 'FAQ';

  @override
  String get legalDocumentDeleteAccount => 'Excluir conta';

  @override
  String get legalDocumentUnableToLoad => 'Não foi possível carregar a página';

  @override
  String get legalDocumentRequiresInternet =>
      'Este conteúdo requer conexão com a internet. Verifique sua conexão e tente novamente.';

  @override
  String get legalDocumentGoBack => 'Voltar';

  @override
  String get legalDocumentRefresh => 'Atualizar';

  @override
  String get channelKeyEncryptionKey => 'Chave de criptografia';

  @override
  String get channelKeyEnterBase64 => 'Insira a chave codificada em base64';

  @override
  String get channelKeyBase64Encoded => 'Codificada em base64';

  @override
  String get channelKeyHint => 'ex. AQ== ou AAAAAAAAAAAAAAAAAAAAAA==';

  @override
  String get channelKeyNoKeySet => '(nenhuma chave definida)';

  @override
  String get channelKeyHide => 'Ocultar';

  @override
  String get channelKeyShow => 'Mostrar';

  @override
  String get channelKeyEdit => 'Editar';

  @override
  String get channelKeyGenerate => 'Gerar';

  @override
  String get channelKeyNewGenerated => 'Nova chave gerada';

  @override
  String get channelKeyCopy => 'Copiar';

  @override
  String get channelKeyCopied => 'Chave copiada para a área de transferência';

  @override
  String get remoteAdminTitle => 'Administração remota';

  @override
  String get remoteAdminSearchHint => 'Buscar nós...';

  @override
  String get remoteAdminConnectedDevice => 'Dispositivo conectado';

  @override
  String get remoteAdminLocalVia => 'Local (via BLE/USB)';

  @override
  String get remoteAdminPkiEnabledNodes => 'NÓS COM PKI HABILITADO';

  @override
  String remoteAdminNodesAvailable(int count) {
    return '$count disponíveis';
  }

  @override
  String get remoteAdminRequiresPki =>
      'A administração remota requer que o nó de destino tenha sua chave pública nas chaves de admin.';

  @override
  String get remoteAdminNoNodes => 'Nenhum nó com PKI habilitado disponível';

  @override
  String remoteAdminNoMatchingNodes(String query) {
    return 'Nenhum nó corresponde a \"$query\"';
  }

  @override
  String get remoteAdminNodesNeedPki =>
      'Os nós precisam ter criptografia PKI habilitada\npara aceitar comandos admin remotos';

  @override
  String get remoteAdminPkiEnabled => '• PKI habilitado';

  @override
  String get contentModerationNotAllowedTitle => 'Conteúdo não permitido';

  @override
  String get contentModerationMayViolateTitle =>
      'O conteúdo pode violar as diretrizes';

  @override
  String get contentModerationBlockedMessage =>
      'Seu conteúdo viola nossas diretrizes da comunidade e não pode ser publicado.';

  @override
  String get contentModerationWarningMessage =>
      'Seu conteúdo pode violar nossas diretrizes da comunidade. Revise antes de publicar.';

  @override
  String get contentModerationIssuesDetected => 'Problemas detectados';

  @override
  String get contentModerationRepeatedViolations =>
      'Violações repetidas podem resultar em restrições da conta.';

  @override
  String get contentModerationPostingViolations =>
      'Publicar conteúdo que viola nossas diretrizes pode resultar na remoção do conteúdo e avisos na conta.';

  @override
  String get contentModerationEditContent => 'Editar conteúdo';

  @override
  String get contentModerationPostAnyway => 'Publicar mesmo assim';

  @override
  String get contentModerationSexualContent => 'Conteúdo sexual';

  @override
  String get contentModerationHateSpeech => 'Discurso de ódio';

  @override
  String get contentModerationViolence => 'Violência';

  @override
  String get contentModerationProfanity => 'Linguagem imprópria';

  @override
  String get contentModerationHarassment => 'Assédio';

  @override
  String get contentModerationSpam => 'Spam';

  @override
  String get contentModerationIllegalActivity => 'Atividade ilegal';

  @override
  String get contentModerationSelfHarm => 'Automutilação';

  @override
  String get contentModerationAdultContent => 'Conteúdo adulto';

  @override
  String get contentModerationSuggestiveContent => 'Conteúdo sugestivo';

  @override
  String contentModerationRemovedWithReason(String reason) {
    return 'Conteúdo removido — $reason';
  }

  @override
  String get contentModerationRemovedGeneric =>
      'Conteúdo removido — seu conteúdo violou nossas diretrizes da comunidade.';

  @override
  String get contentModerationLearnMore => 'Saiba mais';

  @override
  String get devicePrivacyLocationSharing =>
      'Compartilhamento de localização do dispositivo';

  @override
  String get devicePrivacySharingEnabled =>
      'Este dispositivo está configurado para compartilhar sua localização GPS.';

  @override
  String get devicePrivacySharingDisabled =>
      'Este dispositivo não compartilha dados de localização GPS.';

  @override
  String get devicePrivacyWhatThisMeans => 'O que isso significa';

  @override
  String get devicePrivacyPublicVisibility => 'Visibilidade pública';

  @override
  String get devicePrivacyPublicDescription =>
      'A localização do dispositivo será visível para todos os usuários na rede mesh e no mapa mundial do app.';

  @override
  String get devicePrivacyFollowerAccess => 'Acesso de seguidores';

  @override
  String get devicePrivacyFollowerDescription =>
      'Seus seguidores verão as atualizações de posição em tempo real deste dispositivo.';

  @override
  String get devicePrivacyUpdateFrequency => 'Frequência de atualização';

  @override
  String devicePrivacyUpdateFrequencyDescription(int seconds) {
    return 'Atualizações de localização a cada $seconds segundos.';
  }

  @override
  String get devicePrivacyPrivacyDependsNote =>
      'A privacidade da sua localização depende da configuração Meshtastic deste dispositivo. Para alterar as configurações de compartilhamento, atualize a configuração de posição do dispositivo.';

  @override
  String get devicePrivacyPrivacyProtected =>
      'Este dispositivo tem o compartilhamento de localização desabilitado. Sua privacidade está protegida.';

  @override
  String get devicePrivacyLinkDeviceLocationShared =>
      'Vincular dispositivo (localização compartilhada)';

  @override
  String get devicePrivacyLinkDevice => 'Vincular dispositivo';

  @override
  String get dateTimePickerMonthJanuary => 'Janeiro';

  @override
  String get dateTimePickerMonthFebruary => 'Fevereiro';

  @override
  String get dateTimePickerMonthMarch => 'Março';

  @override
  String get dateTimePickerMonthApril => 'Abril';

  @override
  String get dateTimePickerMonthMay => 'Maio';

  @override
  String get dateTimePickerMonthJune => 'Junho';

  @override
  String get dateTimePickerMonthJuly => 'Julho';

  @override
  String get dateTimePickerMonthAugust => 'Agosto';

  @override
  String get dateTimePickerMonthSeptember => 'Setembro';

  @override
  String get dateTimePickerMonthOctober => 'Outubro';

  @override
  String get dateTimePickerMonthNovember => 'Novembro';

  @override
  String get dateTimePickerMonthDecember => 'Dezembro';

  @override
  String get dateTimePickerMonthJan => 'Jan';

  @override
  String get dateTimePickerMonthFeb => 'Fev';

  @override
  String get dateTimePickerMonthMar => 'Mar';

  @override
  String get dateTimePickerMonthApr => 'Abr';

  @override
  String get dateTimePickerMonthMayShort => 'Mai';

  @override
  String get dateTimePickerMonthJun => 'Jun';

  @override
  String get dateTimePickerMonthJul => 'Jul';

  @override
  String get dateTimePickerMonthAug => 'Ago';

  @override
  String get dateTimePickerMonthSep => 'Set';

  @override
  String get dateTimePickerMonthOct => 'Out';

  @override
  String get dateTimePickerMonthNov => 'Nov';

  @override
  String get dateTimePickerMonthDec => 'Dez';

  @override
  String get dateTimePickerDateSection => 'Data';

  @override
  String get dateTimePickerTimeSection => 'Hora';

  @override
  String get dateTimePickerAm => 'AM';

  @override
  String get dateTimePickerPm => 'PM';

  @override
  String get actionConnect => 'Conectar';

  @override
  String get actionView => 'Visualizar';

  @override
  String albumRarityPageTitle(String rarity) {
    return 'Cartas $rarity';
  }

  @override
  String get actionSheetQuickMessage => 'Mensagem rápida';

  @override
  String get actionSheetTo => 'PARA';

  @override
  String get actionSheetAllNodes => 'Todos os nós';

  @override
  String get actionSheetBroadcastToAll => 'Transmitir para todos os nós';

  @override
  String get actionSheetBroadcastToEveryone => 'Transmitir para todos no canal';

  @override
  String get actionSheetSendTo => 'Enviar para';

  @override
  String get actionSheetQuickMessageLabel => 'MENSAGEM RÁPIDA';

  @override
  String get actionSheetOrTypeCustom => 'OU DIGITE PERSONALIZADO';

  @override
  String get actionSheetTypeMessage => 'Digite uma mensagem...';

  @override
  String get actionSheetBroadcast => 'Transmitir';

  @override
  String get actionSheetSend => 'Enviar';

  @override
  String actionSheetSentTo(String target) {
    return 'Enviado para $target';
  }

  @override
  String actionSheetSendFailed(String error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String get actionSheetPresetOnMyWay => 'Estou a caminho';

  @override
  String get actionSheetPresetRunningLate => 'Estou atrasado';

  @override
  String get actionSheetPresetCheckInOk => 'Check-in OK';

  @override
  String get actionSheetPresetNeedAssistance => 'Preciso de ajuda';

  @override
  String get actionSheetPresetAtDestination => 'No destino';

  @override
  String get actionSheetPresetWeatherAlert => 'Alerta climático';

  @override
  String get actionSheetEmergencySos => 'SOS de emergência';

  @override
  String get actionSheetThisWill => 'Isso irá:';

  @override
  String get actionSheetSosBroadcast =>
      'Transmitir uma mensagem de emergência para TODOS os nós';

  @override
  String get actionSheetSosLocation =>
      'Incluir sua localização atual se disponível';

  @override
  String get actionSheetSosIfttt => 'Acionar webhook IFTTT (se configurado)';

  @override
  String get actionSheetSosReady => 'Pronto para enviar alerta de emergência';

  @override
  String actionSheetSosCountdown(int seconds) {
    return 'Aguarde $seconds segundos...';
  }

  @override
  String get actionSheetSendSos => 'Enviar SOS';

  @override
  String get actionSheetSosSent =>
      'SOS de emergência enviado para todos os nós';

  @override
  String actionSheetSosFailed(String error) {
    return 'Falha ao enviar SOS: $error';
  }

  @override
  String get actionSheetTraceroute => 'Traceroute';

  @override
  String get actionSheetTracerouteTo => 'Traceroute para';

  @override
  String get actionSheetTracerouteInfo =>
      'O traceroute descobre o caminho que os pacotes percorrem para alcançar um nó pela rede mesh.';

  @override
  String get actionSheetTargetNode => 'NÓ DESTINO';

  @override
  String get actionSheetSelected => 'Selecionado';

  @override
  String get actionSheetTapToSelectNode => 'Toque para selecionar um nó';

  @override
  String get actionSheetTrace => 'Rastrear';

  @override
  String actionSheetTracerouteSent(String target) {
    return 'Traceroute enviado para $target — verifique o Histórico de traceroute para resultados';
  }

  @override
  String actionSheetTracerouteFailed(String error) {
    return 'Falha ao enviar traceroute: $error';
  }

  @override
  String get premiumPreviewAutomations =>
      'Modo prévia — Atualize para criar automações';

  @override
  String get premiumPreviewIfttt =>
      'Modo prévia — Atualize para conectar serviços';

  @override
  String get premiumPreviewWidgets =>
      'Modo prévia — Atualize para criar widgets';

  @override
  String get premiumPreviewRingtones =>
      'Modo prévia — Atualize para acessar a biblioteca completa';

  @override
  String get premiumPreviewThemes =>
      'Modo prévia — Atualize para desbloquear todas as cores';

  @override
  String get premiumUpgrade => 'Atualizar';

  @override
  String get premiumExample => 'Exemplo';

  @override
  String get premiumUnlockFeature => 'Desbloquear recurso';

  @override
  String get premiumNotNow => 'Agora não';

  @override
  String get premiumRestorePurchases => 'Restaurar compras';

  @override
  String get premiumOneTimePurchase => 'Compra única • Seu para sempre';

  @override
  String premiumUnlockFor(String price) {
    return 'Desbloquear por $price';
  }

  @override
  String get premiumPurchaseRequiresInternet =>
      'Compras requerem conexão com a internet.';

  @override
  String premiumPurchaseUnlocked(String name) {
    return '$name desbloqueado!';
  }

  @override
  String get premiumPurchaseFailed => 'Compra falhou. Tente novamente.';

  @override
  String get premiumPurchaseError => 'Algo deu errado. Tente novamente.';

  @override
  String get premiumRestoreRequiresInternet =>
      'Restaurar compras requer conexão com a internet.';

  @override
  String get premiumRestoreSuccess => 'Compras restauradas!';

  @override
  String get premiumRestoreNone => 'Nenhuma compra encontrada para restaurar';

  @override
  String get premiumRestoreFailed => 'Falha ao restaurar compras';

  @override
  String get premiumConfigSaved =>
      'Sua configuração foi salva. Após a compra, toque em salvar novamente.';

  @override
  String get premiumHeadlineAutomations => 'Automatize sua rede mesh';

  @override
  String get premiumHeadlineIfttt => 'Conecte tudo';

  @override
  String get premiumHeadlineThemes => 'Deixe do seu jeito';

  @override
  String get premiumHeadlineRingtones => 'Biblioteca de sons';

  @override
  String get premiumHeadlineWidgets => 'Seu painel';

  @override
  String get premiumHeadlineWidgetsAlt => 'Crie seu painel';

  @override
  String get premiumHeadlineRingtonesAlt => 'Desbloqueie a biblioteca de sons';

  @override
  String get premiumSubtitleAutomations =>
      'Salve esta automação e desbloqueie todo o poder de alertas automáticos, mensagens e gatilhos inteligentes.';

  @override
  String get premiumSubtitleIfttt =>
      'Conecte sua rede mesh a centenas de apps e serviços.';

  @override
  String get premiumSubtitleThemes =>
      'Expresse-se com 12 cores de destaque deslumbrantes.';

  @override
  String get premiumSubtitleRingtones =>
      'Acesse uma enorme biblioteca de sons de notificação.';

  @override
  String get premiumSubtitleWidgets =>
      'Crie painéis personalizados com visualizações de dados em tempo real.';

  @override
  String get premiumDescAutomations =>
      'Crie automações poderosas que acionam alertas, enviam mensagens e reagem automaticamente a eventos da rede mesh.';

  @override
  String get premiumDescIfttt =>
      'Conecte sua rede mesh a mais de 700 apps e serviços via webhooks IFTTT.';

  @override
  String get premiumDescWidgets =>
      'Crie widgets de painel personalizados com dados em tempo real, gráficos e monitoramento ao vivo.';

  @override
  String get premiumDescRingtones =>
      'Acesse mais de 7.000 toques, de melodias clássicas a temas de TV e trilhas sonoras.';

  @override
  String get premiumDescThemes =>
      'Personalize seu app com 12 cores de destaque deslumbrantes.';

  @override
  String get premiumBenefitUnlimitedAutomations => 'Automações ilimitadas';

  @override
  String get premiumBenefitUnlimitedAutomationsDesc =>
      'Crie quantas regras precisar';

  @override
  String get premiumBenefitSmartNotifications => 'Notificações inteligentes';

  @override
  String get premiumBenefitSmartNotificationsDesc =>
      'Receba alertas de bateria, nós offline e mais';

  @override
  String get premiumBenefitScheduledActions => 'Ações agendadas';

  @override
  String get premiumBenefitScheduledActionsDesc =>
      'Execute automações em horários específicos';

  @override
  String get premiumBenefitScheduledActionsShort =>
      'Execute em horários específicos';

  @override
  String get premiumBenefitGeofenceTriggers => 'Gatilhos de geofence';

  @override
  String get premiumBenefitGeofenceTriggersDesc =>
      'Reaja quando nós entram ou saem de áreas';

  @override
  String get premiumBenefitGeofenceTriggersShort =>
      'Reaja a eventos de localização';

  @override
  String get premiumBenefitConnect700 => 'Conecte mais de 700 serviços';

  @override
  String get premiumBenefitConnect700Desc =>
      'Casa inteligente, notificações, planilhas e mais';

  @override
  String get premiumBenefitSmartHome => 'Casa inteligente';

  @override
  String get premiumBenefitSmartHomeDesc =>
      'Controle luzes, fechaduras e dispositivos';

  @override
  String get premiumBenefitSmartHomeControl => 'Controle de casa inteligente';

  @override
  String get premiumBenefitSmartHomeControlDesc =>
      'Acione luzes, fechaduras e dispositivos';

  @override
  String get premiumBenefitCrossPlatform => 'Multiplataforma';

  @override
  String get premiumBenefitCrossPlatformDesc => 'Alertas Slack, Discord, email';

  @override
  String get premiumBenefitCrossPlatformAlerts => 'Alertas multiplataforma';

  @override
  String get premiumBenefitCrossPlatformAlertsDesc =>
      'Envie para Slack, Discord, email e mais';

  @override
  String get premiumBenefitLogging => 'Registro';

  @override
  String get premiumBenefitLoggingDesc => 'Salve eventos em planilhas';

  @override
  String get premiumBenefit12Colors => '12 cores premium';

  @override
  String get premiumBenefit12ColorsDesc => 'Personalize cada tela e botão';

  @override
  String get premiumBenefit15Colors => '15 cores';

  @override
  String get premiumBenefit15ColorsDesc => 'Opções de destaque premium';

  @override
  String get premiumBenefitExclusiveStyles => 'Estilos exclusivos';

  @override
  String get premiumBenefitExclusiveStylesDesc =>
      'Combinações de destaque únicas';

  @override
  String get premiumBenefitExclusive => 'Exclusivo';

  @override
  String get premiumBenefitExclusiveDesc => 'Combinações únicas';

  @override
  String get premiumBenefit7000Ringtones => 'Mais de 7.000 toques';

  @override
  String get premiumBenefit7000RingtonesDesc =>
      'Melodias clássicas, temas de TV, jogos e mais';

  @override
  String get premiumBenefit10000Tones => 'Mais de 10.000 sons';

  @override
  String get premiumBenefit10000TonesDesc => 'Enorme biblioteca pesquisável';

  @override
  String get premiumBenefitSearchableLibrary => 'Biblioteca pesquisável';

  @override
  String get premiumBenefitSearchableLibraryDesc =>
      'Encontre qualquer toque instantaneamente';

  @override
  String get premiumBenefitEasySearch => 'Busca fácil';

  @override
  String get premiumBenefitEasySearchDesc =>
      'Encontre qualquer toque instantaneamente';

  @override
  String get premiumBenefitCustomPresets => 'Predefinições personalizadas';

  @override
  String get premiumBenefitCustomPresetsDesc => 'Salve seus favoritos';

  @override
  String get premiumBenefitCustomDashboards => 'Painéis personalizados';

  @override
  String get premiumBenefitCustomDashboardsDesc =>
      'Crie seus próprios layouts de widgets';

  @override
  String get premiumBenefitLiveCharts => 'Gráficos e medidores ao vivo';

  @override
  String get premiumBenefitLiveChartsDesc =>
      'Visualize telemetria em tempo real';

  @override
  String get premiumBenefitLiveChartsAlt => 'Gráficos ao vivo';

  @override
  String get premiumBenefitLiveChartsAltDesc =>
      'Visualização de dados em tempo real';

  @override
  String get premiumBenefitBatterySensors => 'Bateria e sensores';

  @override
  String get premiumBenefitBatterySensorsDesc => 'Monitore tudo de relance';

  @override
  String get premiumBenefitMonitoring => 'Monitoramento';

  @override
  String get premiumBenefitMonitoringDesc => 'Bateria, sensores, telemetria';

  @override
  String get premiumBenefitCustomLayouts => 'Layouts personalizados';

  @override
  String get premiumBenefitCustomLayoutsDesc =>
      'Crie suas próprias visualizações';

  @override
  String get premiumBenefitSmartAlerts => 'Alertas inteligentes';

  @override
  String get premiumBenefitSmartAlertsDesc =>
      'Bateria fraca, nó offline e mais';

  @override
  String get settingsPremiumFeatureRequired => 'Este recurso requer uma compra';

  @override
  String get settingsPremiumViewUpgrades => 'Ver atualizações';

  @override
  String get settingsPremiumPro => 'PRO';

  @override
  String get settingsPremiumFeatureTitle => 'Recurso premium';

  @override
  String get settingsPremiumFeatureDescription =>
      'Este recurso requer uma compra para ser desbloqueado.';

  @override
  String settingsPremiumUnlockPrice(String price) {
    return 'Desbloquear \$$price';
  }

  @override
  String get glyphMatrixTitle => 'MATRIZ DE GLIFOS';

  @override
  String get glyphMatrixTurnOff => 'Desligar';

  @override
  String get glyphMatrixInitializing => 'INICIALIZANDO GLYPH MATRIX...';

  @override
  String get glyphMatrixInitFailed => 'INICIALIZAÇÃO FALHOU';

  @override
  String get glyphMatrixNotSupported => 'DISPOSITIVO NÃO SUPORTADO';

  @override
  String get glyphMatrixRequiresDevice =>
      'Glyph Matrix requer\nNothing Phone (3)';

  @override
  String get glyphMatrixSwipeToExecute => '← DESLIZE PARA EXECUTAR →';

  @override
  String batteryOptTitle(String oemName) {
    return 'Otimizar para $oemName';
  }

  @override
  String get batteryOptDescription =>
      'O fabricante do seu dispositivo pode limitar agressivamente apps em segundo plano. Siga estes passos para manter a conexão mesh ativa:';

  @override
  String get batteryOptOpenSettings => 'Abrir configurações de bateria';

  @override
  String get batteryOptDismiss => 'Ignorar';

  @override
  String get batteryOptDontShowAgain => 'Não mostrar novamente';

  @override
  String get batteryOptXiaomiStep1 =>
      'Abra Configurações > Apps > Gerenciar apps > Socialmesh.';

  @override
  String get batteryOptXiaomiStep2 => 'Toque em \"Início automático\" e ative.';

  @override
  String get batteryOptXiaomiStep3 =>
      'Volte e toque em \"Economia de bateria\".';

  @override
  String get batteryOptXiaomiStep4 =>
      'Selecione \"Sem restrições\" para Socialmesh.';

  @override
  String get batteryOptSamsungStep1 =>
      'Abra Configurações > Bateria e cuidados com o dispositivo > Bateria.';

  @override
  String get batteryOptSamsungStep2 =>
      'Toque em \"Limites de uso em segundo plano\".';

  @override
  String get batteryOptSamsungStep3 =>
      'Remova Socialmesh das listas \"Apps em suspensão\" e \"Apps em suspensão profunda\".';

  @override
  String get batteryOptSamsungStep4 =>
      'Opcionalmente, desative \"Bateria adaptável\" para melhores resultados.';

  @override
  String get batteryOptHuaweiStep1 =>
      'Abra Configurações > Bateria > Inicialização de apps.';

  @override
  String get batteryOptHuaweiStep2 =>
      'Encontre Socialmesh e defina como \"Gerenciar manualmente\".';

  @override
  String get batteryOptHuaweiStep3 =>
      'Ative as três opções: Início automático, Início secundário e Executar em segundo plano.';

  @override
  String get batteryOptOneplusStep1 =>
      'Abra Configurações > Apps > Gerenciamento de apps > Socialmesh.';

  @override
  String get batteryOptOneplusStep2 =>
      'Ative \"Início automático\" e \"Permitir atividade em segundo plano\".';

  @override
  String get batteryOptOneplusStep3 =>
      'No OnePlus 14+: verifique também Configurações > Bateria > Otimização de bateria > Socialmesh > \"Não otimizar\".';

  @override
  String get batteryOptGenericStep1 =>
      'Abra Configurações > Apps > Socialmesh > Bateria.';

  @override
  String get batteryOptGenericStep2 =>
      'Selecione \"Sem restrições\" ou \"Não otimizar\".';

  @override
  String get batteryOptGenericStep3 =>
      'Isso permite que Socialmesh mantenha a conexão mesh em segundo plano.';

  @override
  String get helpCenterNoResultsPrefix => 'Nenhum ';

  @override
  String get helpCenterNoResultsKeyword => 'resultado';

  @override
  String get helpCenterNoResultsSuffix => ' encontrado';

  @override
  String helpCenterReadingTime(int minutes) {
    return '$minutes min';
  }

  @override
  String helpCenterMoreTours(int count) {
    return '+ $count mais tours';
  }

  @override
  String helpCenterStepsCount(int count) {
    return '$count passos';
  }

  @override
  String get storeForwardTitle => 'Store & Forward';

  @override
  String get storeForwardSaveSuccess => 'Configuração Store & Forward salva';

  @override
  String get storeForwardLoadFailed => 'Falha ao carregar configuração';

  @override
  String storeForwardSaveFailed(String error) {
    return 'Falha ao salvar configuração: $error';
  }

  @override
  String get storeForwardSave => 'Salvar';

  @override
  String get storeForwardModuleSettings => 'Configurações do módulo';

  @override
  String get storeForwardServerSettings => 'Configurações do servidor';

  @override
  String get storeForwardInfoDescription =>
      'Permite que nós armazenem mensagens e as encaminhem para dispositivos que estavam offline. Um nó \"servidor\" armazena mensagens, enquanto nós \"cliente\" podem solicitar mensagens perdidas.';

  @override
  String get storeForwardEnable => 'Ativar Store & Forward';

  @override
  String get storeForwardEnableSubtitle => 'Participar da rede S&F';

  @override
  String get storeForwardActAsServer => 'Agir como servidor';

  @override
  String get storeForwardActAsServerSubtitle =>
      'Armazenar mensagens para outros nós (usa mais RAM)';

  @override
  String get storeForwardHeartbeat => 'Heartbeat';

  @override
  String get storeForwardHeartbeatSubtitle =>
      'Enviar anúncios periódicos para a mesh';

  @override
  String get storeForwardRecordsLimit => 'Limite de registros';

  @override
  String get storeForwardRecordsLimitSubtitle => 'Usar padrão do dispositivo';

  @override
  String get storeForwardAuto => 'Auto';

  @override
  String get storeForwardHistoryReturnMax => 'Máx. retorno do histórico';

  @override
  String storeForwardHistoryReturnMaxSubtitle(int count) {
    return 'Máx. $count mensagens por solicitação';
  }

  @override
  String get storeForwardHistoryWindow => 'Janela do histórico';

  @override
  String storeForwardHistoryWindowSubtitle(int hours) {
    return 'Manter mensagens por $hours horas';
  }

  @override
  String get geofenceTitle => 'Definir geofence';

  @override
  String get geofenceDone => 'Concluído';

  @override
  String get geofencePermissionDenied =>
      'Permissão de localização negada. Conceda acesso à localização para definir o centro do geofence.';

  @override
  String get geofenceOpenSettings => 'Abrir configurações';

  @override
  String geofenceLocationFailed(String error) {
    return 'Falha ao obter localização: $error';
  }

  @override
  String get geofenceTapToSet =>
      'Toque no mapa para definir o centro do geofence';

  @override
  String get geofenceTapToSetCenter =>
      'Toque para definir o centro do geofence';

  @override
  String get geofenceDragToAdjust =>
      'Arraste a borda do círculo para ajustar o raio';

  @override
  String geofenceNodesCount(int count) {
    return '$count nós';
  }

  @override
  String get geofenceMonitoredNode => 'Nó monitorado';

  @override
  String get geofenceRadius => 'Raio';

  @override
  String geofenceRadiusKm(String value) {
    return 'Raio: $value km';
  }

  @override
  String geofenceRadiusM(String value) {
    return 'Raio: $value m';
  }

  @override
  String get subscriptionFallbackRingtonePack => 'Pacote de toques';

  @override
  String get subscriptionFallbackThemePack => 'Pacote de temas';

  @override
  String get subscriptionFallbackWidgetPack => 'Pacote de widgets';

  @override
  String get subscriptionFallbackAutomations => 'Automações';

  @override
  String get subscriptionFallbackIfttt => 'IFTTT';

  @override
  String get subscriptionFallbackTranslationPack => 'Translation Pack';

  @override
  String get geofenceLocating => 'Localizando...';

  @override
  String get geofenceUseMyLocation => 'Usar minha localização';

  @override
  String get geofenceSetGeofence => 'Definir geofence';

  @override
  String get geofenceSelectNode => 'Selecionar nó';

  @override
  String get geofenceNoNodesWithGps => 'Nenhum nó com GPS';

  @override
  String get geofenceYou => 'VOCÊ';

  @override
  String get geofenceMonitored => 'Monitorado';

  @override
  String get geofenceMonitor => 'Monitorar';

  @override
  String get restorePurchasesTitle => 'Restaurar compras';

  @override
  String get restorePurchasesRequiresInternet =>
      'A restauração de compras requer conexão com a internet.';

  @override
  String get restorePurchasesSuccess => 'Compras restauradas com sucesso!';

  @override
  String get restorePurchasesAlreadyActive => 'Suas compras já estão ativas';

  @override
  String get restorePurchasesNone => 'Nenhuma compra encontrada para restaurar';

  @override
  String get bluetoothTitle => 'Bluetooth';

  @override
  String get bluetoothSave => 'Salvar';

  @override
  String get bluetoothSaveSuccess => 'Configuração Bluetooth salva';

  @override
  String bluetoothSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get bluetoothInvalidPin => 'Insira um PIN válido de 6 dígitos';

  @override
  String get bluetoothEnabled => 'Bluetooth ativado';

  @override
  String get bluetoothEnableSubtitle => 'Ativar conectividade Bluetooth';

  @override
  String get bluetoothPairingMode => 'MODO DE PAREAMENTO';

  @override
  String get bluetoothFixedPin => 'PIN FIXO';

  @override
  String get bluetoothPinHint =>
      'Insira um código PIN de 6 dígitos para o pareamento Bluetooth';

  @override
  String get bluetoothInfoDescription =>
      'As configurações de Bluetooth controlam como seu dispositivo pareia com telefones e outros dispositivos.';

  @override
  String get bluetoothModeRandom => 'PIN aleatório';

  @override
  String get bluetoothModeFixed => 'PIN fixo';

  @override
  String get bluetoothModeNone => 'Sem PIN';

  @override
  String get bluetoothModeUnknown => 'Desconhecido';

  @override
  String get bluetoothModeRandomDesc =>
      'Gerar PIN aleatório a cada inicialização';

  @override
  String get bluetoothModeFixedDesc => 'Usar um código PIN fixo';

  @override
  String get bluetoothModeNoneDesc => 'Nenhum PIN necessário (inseguro)';

  @override
  String get detectionSensorTitle => 'Sensor de detecção';

  @override
  String get detectionSensorSave => 'Salvar';

  @override
  String get detectionSensorSaveSuccess =>
      'Configuração do sensor de detecção salva';

  @override
  String detectionSensorSaveFailed(String error) {
    return 'Falha ao salvar configuração: $error';
  }

  @override
  String get detectionSensorBasicSettings => 'Configurações básicas';

  @override
  String get detectionSensorPinConfig => 'Configuração de pino';

  @override
  String get detectionSensorTiming => 'Temporização';

  @override
  String get detectionSensorClientOptions => 'Opções do cliente';

  @override
  String get detectionSensorInfoDescription =>
      'Monitore um pino GPIO e transmita mudanças de estado para a mesh. Use com sensores de movimento PIR, contatos de porta/janela ou outros sensores binários.';

  @override
  String get detectionSensorEnable => 'Ativar sensor de detecção';

  @override
  String get detectionSensorEnableSubtitle =>
      'Monitorar pino GPIO e transmitir mudanças de estado';

  @override
  String get detectionSensorName => 'Nome do sensor';

  @override
  String get detectionSensorNameHint =>
      'ex. Porta da frente, Sensor de movimento';

  @override
  String get detectionSensorGpioPin => 'Pino GPIO';

  @override
  String get detectionSensorGpioPinSubtitle =>
      'O número do pino GPIO a monitorar';

  @override
  String get detectionSensorTriggerType => 'Tipo de trigger';

  @override
  String get detectionSensorUsePullup => 'Usar pullup interno';

  @override
  String get detectionSensorUsePullupSubtitle =>
      'Ativar resistor de pullup interno no pino';

  @override
  String get detectionSensorSendBell => 'Enviar caractere bell';

  @override
  String get detectionSensorSendBellSubtitle =>
      'Enviar bell (\\a) nas mensagens de detecção';

  @override
  String get detectionSensorMinBroadcastInterval =>
      'Intervalo mínimo de transmissão';

  @override
  String detectionSensorMinBroadcastIntervalSubtitle(int seconds) {
    return 'Aguardar $seconds segundos entre transmissões';
  }

  @override
  String get detectionSensorStateBroadcastInterval =>
      'Intervalo de transmissão de estado';

  @override
  String detectionSensorStateBroadcastIntervalSubtitle(int minutes) {
    return 'Transmitir estado atual a cada $minutes minutos';
  }

  @override
  String get detectionSensorEnableNotifications => 'Ativar notificações';

  @override
  String get detectionSensorEnableNotificationsSubtitle =>
      'Mostrar notificações ao receber eventos do sensor';

  @override
  String get detectionSensorTriggerLogicLow =>
      'Nível lógico baixo (ativo quando pino é LOW)';

  @override
  String get detectionSensorTriggerLogicHigh =>
      'Nível lógico alto (ativo quando pino é HIGH)';

  @override
  String get detectionSensorTriggerFallingEdge =>
      'Borda de descida (trigger em HIGH→LOW)';

  @override
  String get detectionSensorTriggerRisingEdge =>
      'Borda de subida (trigger em LOW→HIGH)';

  @override
  String get detectionSensorTriggerEitherEdgeLow =>
      'Ambas as bordas (ativo LOW)';

  @override
  String get detectionSensorTriggerEitherEdgeHigh =>
      'Ambas as bordas (ativo HIGH)';

  @override
  String get subscriptionPremiumTitle => 'Premium';

  @override
  String get subscriptionOrBuyIndividually => 'ou compre individualmente';

  @override
  String get subscriptionIncludedFeatures => 'Recursos incluídos';

  @override
  String get subscriptionUnlockFeatures => 'Desbloquear recursos';

  @override
  String get subscriptionOneTimePurchases => 'Compras únicas, seus para sempre';

  @override
  String get subscriptionTerms => 'Termos';

  @override
  String get subscriptionPrivacy => 'Privacidade';

  @override
  String get subscriptionAllUnlocked => 'Todos os recursos desbloqueados';

  @override
  String get subscriptionThankYou => 'Obrigado pelo seu apoio!';

  @override
  String get subscriptionCompletePack => 'Pacote completo';

  @override
  String get subscriptionCompletePackSubtitle => 'Tudo. Para sempre. Um preço.';

  @override
  String subscriptionTones(String count) {
    return '$count toques';
  }

  @override
  String get subscriptionAccentColors => '12 cores de destaque';

  @override
  String get subscriptionUnlimitedWidgets =>
      'Widgets personalizados ilimitados';

  @override
  String get subscriptionTriggersSchedules => 'Gatilhos e agendamentos';

  @override
  String get subscriptionAppIntegrations => 'Mais de 700 integrações de apps';

  @override
  String get subscriptionTranslateMessages => 'One-tap message translation';

  @override
  String get subscriptionNewAddon => 'New Add-on';

  @override
  String get subscriptionFeaturedTranslationSubtitle =>
      'On-demand translation with smart caching, privacy controls, and BYO provider support';

  @override
  String get subscriptionGetTranslation => 'Get';

  @override
  String get subscriptionBestValue =>
      'Melhor custo-benefício - todos os recursos';

  @override
  String get subscriptionGetAll => 'Obter tudo';

  @override
  String get subscriptionOwned => 'ADQUIRIDO';

  @override
  String subscriptionSearchableTones(String count) {
    return '$count toques RTTTL pesquisáveis';
  }

  @override
  String get subscriptionView => 'Visualizar';

  @override
  String get subscriptionAllUnlockedCelebration =>
      'Todos os recursos desbloqueados!';

  @override
  String get subscriptionCelebrationMessage =>
      'Agora você tem acesso a tudo que o Socialmesh oferece. Obrigado pelo seu apoio!';

  @override
  String get subscriptionAwesome => 'Incrível!';

  @override
  String get cannedResponsesTitle => 'Respostas rápidas';

  @override
  String get cannedResponsesAddTooltip => 'Adicionar resposta';

  @override
  String get cannedResponsesDoneTooltip => 'Concluído';

  @override
  String get cannedResponsesReorderTooltip => 'Reordenar';

  @override
  String get cannedResponsesResetToDefaults => 'Restaurar padrões';

  @override
  String get cannedResponsesDeleteTitle => 'Excluir resposta';

  @override
  String cannedResponsesDeleteMessage(String text) {
    return 'Excluir \"$text\"?';
  }

  @override
  String get cannedResponsesDeleteConfirm => 'Excluir';

  @override
  String get cannedResponsesResetTitle => 'Restaurar padrões';

  @override
  String get cannedResponsesResetMessage =>
      'Isso removerá todas as respostas personalizadas e restaurará o conjunto padrão.';

  @override
  String get cannedResponsesResetConfirm => 'Restaurar';

  @override
  String get cannedResponsesDragToReorder =>
      'Arraste para reordenar as respostas';

  @override
  String get cannedResponsesTapToEdit =>
      'Toque para editar, deslize para excluir';

  @override
  String get cannedResponsesDefault => 'Padrão';

  @override
  String get cannedResponsesEditTitle => 'Editar resposta';

  @override
  String get cannedResponsesAddTitle => 'Adicionar resposta';

  @override
  String get cannedResponsesCreateSubtitle =>
      'Crie uma mensagem rápida para envio ágil';

  @override
  String get cannedResponsesMessageLabel => 'Mensagem';

  @override
  String get cannedResponsesMessageHint => 'ex. Estou a caminho';

  @override
  String get cannedResponsesSave => 'Salvar';

  @override
  String get cannedResponsesAdd => 'Adicionar';

  @override
  String get rangeTestTitle => 'Teste de alcance';

  @override
  String get rangeTestSave => 'Salvar';

  @override
  String get rangeTestSaveSuccess => 'Configuração do teste de alcance salva';

  @override
  String rangeTestSaveFailed(String error) {
    return 'Falha ao salvar configuração: $error';
  }

  @override
  String get rangeTestNoNodes => 'Nenhum outro nó disponível';

  @override
  String get rangeTestSelectTarget => 'Selecionar alvo';

  @override
  String get rangeTestConfiguration => 'Configuração';

  @override
  String rangeTestResultsCount(int count) {
    return 'Resultados ($count)';
  }

  @override
  String get rangeTestAbout => 'Sobre o teste de alcance';

  @override
  String get rangeTestRunning => 'Teste em andamento';

  @override
  String get rangeTestReady => 'Pronto para testar';

  @override
  String rangeTestPacketsReceived(int count) {
    return '$count pacotes recebidos';
  }

  @override
  String get rangeTestSelectNode => 'Selecionar nó';

  @override
  String get rangeTestStop => 'Parar';

  @override
  String get rangeTestStartTest => 'Iniciar teste';

  @override
  String get rangeTestEnableModule => 'Ativar módulo de teste de alcance';

  @override
  String get rangeTestEnableModuleSubtitle =>
      'Permitir que este dispositivo participe de testes de alcance';

  @override
  String get rangeTestSenderInterval => 'Intervalo de envio';

  @override
  String rangeTestSenderIntervalSubtitle(int seconds) {
    return 'Enviar pacote de teste a cada $seconds segundos';
  }

  @override
  String get rangeTestSaveResultsToSd => 'Salvar resultados no SD';

  @override
  String get rangeTestSaveResultsToSdSubtitle =>
      'Armazenar resultados do teste no cartão SD do dispositivo';

  @override
  String get rangeTestAvgSnr => 'SNR médio';

  @override
  String get rangeTestAvgRssi => 'RSSI médio';

  @override
  String get rangeTestMaxDist => 'Dist. máx.';

  @override
  String get rangeTestHowItWorks => 'Como funciona o teste de alcance';

  @override
  String get rangeTestHowItWorksDescription =>
      '1. Selecione um nó alvo para testar o alcance\n2. Inicie o teste para começar a enviar pacotes\n3. Visualize as métricas de sinal em tempo real (SNR, RSSI)\n4. Acompanhe a distância máxima alcançada\n\nAmbos os nós devem ter o módulo de teste de alcance ativado para melhores resultados.';

  @override
  String get rangeTestSelectTargetNode => 'Selecionar nó alvo';

  @override
  String get rangeTestSearchNodes => 'Buscar nós…';

  @override
  String rangeTestNoNodesMatch(String query) {
    return 'Nenhum nó corresponde a \"$query\"';
  }

  @override
  String get themeSettingsTitle => 'Configurações de tema';

  @override
  String get themeSettingsCurrentAccent => 'Cor de destaque atual';

  @override
  String get themeSettingsAccentColor => 'COR DE DESTAQUE';

  @override
  String get themeSettingsQrCodeStyle => 'ESTILO DO CÓDIGO QR';

  @override
  String get themeSettingsPreview => 'PRÉVIA';

  @override
  String themeSettingsCompletePackOnly(String colorName) {
    return '$colorName (somente pacote completo)';
  }

  @override
  String themeSettingsThemePack(String colorName) {
    return '$colorName (pacote de temas)';
  }

  @override
  String get themeSettingsPattern => 'Padrão';

  @override
  String get themeSettingsStyleDots => 'Pontos';

  @override
  String get themeSettingsStyleSmooth => 'Suave';

  @override
  String get themeSettingsStyleClassic => 'Clássico';

  @override
  String get themeSettingsStyleDotsDesc => 'Módulos circulares limpos';

  @override
  String get themeSettingsStyleSmoothDesc => 'Módulos líquidos premium';

  @override
  String get themeSettingsStyleClassicDesc => 'Máxima compatibilidade';

  @override
  String get themeSettingsUseAccentGradient => 'Usar gradiente de destaque';

  @override
  String get themeSettingsApplyAccentToQr =>
      'Aplicar cor de destaque aos códigos QR';

  @override
  String get themeSettingsButtons => 'Botões';

  @override
  String get themeSettingsPrimary => 'Primário';

  @override
  String get themeSettingsSecondary => 'Secundário';

  @override
  String get themeSettingsText => 'Texto';

  @override
  String get themeSettingsControls => 'Controles';

  @override
  String get themeSettingsProgress => 'Progresso';

  @override
  String get themeSettingsBadges => 'Emblemas';

  @override
  String get themeSettingsOnline => 'Online';

  @override
  String get themeSettingsNewCount => '5 novos';

  @override
  String get privacySettingsTitle => 'Privacidade';

  @override
  String get privacySettingsInfoDescription =>
      'O Socialmesh coleta dados mínimos para melhorar a estabilidade e o desempenho do app. Você pode controlar o que é compartilhado abaixo.';

  @override
  String get privacySettingsDataCollection => 'COLETA DE DADOS';

  @override
  String get privacySettingsUsageAnalytics => 'Análise de uso';

  @override
  String get privacySettingsUsageAnalyticsSubtitle =>
      'Nos ajuda a entender quais recursos são mais usados. Nenhum conteúdo de mensagem ou localização precisa é coletado.';

  @override
  String get privacySettingsCrashReporting => 'Relatório de falhas';

  @override
  String get privacySettingsCrashReportingSubtitle =>
      'Envia automaticamente dados de falha quando o app encontra um erro. Nos ajuda a corrigir bugs mais rápido.';

  @override
  String get privacySettingsDisableAnalyticsTitle =>
      'Desativar análise de uso?';

  @override
  String get privacySettingsDisableAnalyticsMessage =>
      'As análises de uso nos ajudam a entender como o app é usado e a identificar problemas. Nenhuma mensagem pessoal ou dado de localização é coletado.\n\nVocê pode reativar isso a qualquer momento.';

  @override
  String get privacySettingsDisable => 'Desativar';

  @override
  String get privacySettingsAnalyticsEnabled => 'Análises de uso ativadas';

  @override
  String get privacySettingsAnalyticsDisabled => 'Análises de uso desativadas';

  @override
  String get privacySettingsDisableCrashTitle =>
      'Desativar relatórios de falha?';

  @override
  String get privacySettingsDisableCrashMessage =>
      'Os relatórios de falha nos ajudam a corrigir bugs mais rápido. Nenhuma mensagem pessoal ou dado de localização é incluído nos relatórios de falha.\n\nVocê pode reativar isso a qualquer momento.';

  @override
  String get privacySettingsCrashEnabled => 'Relatórios de falha ativados';

  @override
  String get privacySettingsCrashDisabled => 'Relatórios de falha desativados';

  @override
  String get privacySettingsPrivacyPolicy => 'Política de Privacidade';

  @override
  String get privacySettingsThirdPartyServices => 'SERVIÇOS DE TERCEIROS';

  @override
  String get privacySettingsFirebaseCategories =>
      'Relatórios de falha, análises de uso (se ativadas)';

  @override
  String get privacySettingsRevenueCatCategories =>
      'Identificadores de compra, status da assinatura';

  @override
  String get privacySettingsSigilCategories =>
      'Identificadores de nó com hash para geração de artwork';

  @override
  String get appearanceTitle => 'Aparência e acessibilidade';

  @override
  String get appearanceResetTooltip => 'Restaurar padrões';

  @override
  String get appearanceLanguage => 'Idioma';

  @override
  String get appearanceLanguageSystemDefault => 'Padrão do sistema';

  @override
  String get appearanceLanguageEnglish => 'English';

  @override
  String get appearanceLanguageItalian => 'Italiano';

  @override
  String get appearanceLanguageRussian => 'Русский';

  @override
  String get appearanceLanguagePortuguese => 'Português';

  @override
  String get helpCategoryGettingStarted => 'Primeiros passos';

  @override
  String get helpCategoryMeshBasics => 'Fundamentos do mesh';

  @override
  String get helpCategoryChannels => 'Canais e criptografia';

  @override
  String get helpCategoryMessaging => 'Mensagens';

  @override
  String get helpCategoryNodes => 'Nós e funções';

  @override
  String get helpCategoryDevice => 'Dispositivo e rádio';

  @override
  String get helpCategoryNetwork => 'Rede e mapas';

  @override
  String get helpCategorySafety => 'Segurança e regras';

  @override
  String get flowNodeNodeOnline => 'Nó online';

  @override
  String get flowNodeNodeOffline => 'Nó offline';

  @override
  String get flowNodeBatteryLow => 'Bateria fraca';

  @override
  String get flowNodeBatteryFull => 'Bateria cheia';

  @override
  String get flowNodeMessageReceived => 'Mensagem recebida';

  @override
  String get flowNodePositionChanged => 'Posição alterada';

  @override
  String get flowNodeGeofenceEnter => 'Entrada no geofence';

  @override
  String get flowNodeGeofenceExit => 'Saída do geofence';

  @override
  String get flowNodeSendMessage => 'Enviar mensagem';

  @override
  String get flowNodePlaySound => 'Reproduzir som';

  @override
  String get flowNodeVibrate => 'Vibrar';

  @override
  String get flowNodePushNotification => 'Notificação push';

  @override
  String get flowNodeTriggerWebhook => 'Acionar webhook';

  @override
  String get flowNodeLogEvent => 'Registrar evento';

  @override
  String get flowNodeUpdateWidget => 'Atualizar widget';

  @override
  String get flowNodeSendToChannel => 'Enviar para canal';

  @override
  String get flowNodeTriggerShortcut => 'Acionar atalho';

  @override
  String get flowNodeGlyphPattern => 'Padrão de glifo';

  @override
  String get flowNodeTimeRange => 'Intervalo de tempo';

  @override
  String get flowNodeDayOfWeek => 'Dia da semana';

  @override
  String get flowNodeBatteryAbove => 'Bateria acima de';

  @override
  String get flowNodeBatteryBelow => 'Bateria abaixo de';

  @override
  String get flowNodeNodeIsOnline => 'Nó está online';

  @override
  String get flowNodeNodeIsOffline => 'Nó está offline';

  @override
  String get flowNodeWithinGeofence => 'Dentro do geofence';

  @override
  String get flowNodeOutsideGeofence => 'Fora do geofence';

  @override
  String get flowNodeGateAllMustPass => 'Todas as entradas devem passar';

  @override
  String get flowNodeGateAnyCanPass => 'Qualquer entrada pode passar';

  @override
  String get flowNodeGateInverts => 'Inverte o sinal';

  @override
  String get flowNodeGateDelays => 'Atrasa o sinal';

  @override
  String get flowSubgroupTriggers => 'Gatilhos';

  @override
  String get flowSubgroupConditions => 'Condições';

  @override
  String get flowSubgroupLogic => 'Lógica';

  @override
  String get flowSubgroupActions => 'Ações';

  @override
  String get flowSubgroupNodeDex => 'NodeDex';

  @override
  String get flowCompilerVisualFlow => 'Fluxo visual';

  @override
  String flowCompilerWhen(String trigger) {
    return 'Quando: $trigger';
  }

  @override
  String flowCompilerIf(String conditions) {
    return 'Se: $conditions';
  }

  @override
  String flowCompilerAfterDelay(String delay) {
    return 'Após: atraso de $delay';
  }

  @override
  String flowCompilerThen(String actions) {
    return 'Então: $actions';
  }

  @override
  String get glyphZoneA => 'Zona A';

  @override
  String get glyphZoneB => 'Zona B';

  @override
  String get glyphZoneC => 'Zona C';

  @override
  String get glyphZoneD => 'Zona D';

  @override
  String get glyphZoneE => 'Zona E';

  @override
  String get glyphZoneDescCamera => 'Câmera';

  @override
  String get glyphZoneDescDiagonal => 'Faixa diagonal';

  @override
  String get glyphZoneDescUsbc => 'Porta USB-C';

  @override
  String get glyphZoneDescLower => 'Faixa inferior';

  @override
  String get glyphZoneDescBattery => 'Bateria';

  @override
  String get appearanceFontBranded => 'Personalizada';

  @override
  String get appearanceFontBrandedDesc =>
      'JetBrainsMono - Nossa fonte monoespaçada exclusiva';

  @override
  String get appearanceFontSystem => 'Sistema';

  @override
  String get appearanceFontSystemDesc => 'A fonte padrão do seu dispositivo';

  @override
  String get appearanceFontAccessibility => 'Acessibilidade';

  @override
  String get appearanceFontAccessibilityDesc =>
      'Inter - Otimizada para legibilidade';

  @override
  String get appearanceTextScaleSystem => 'Padrão do sistema';

  @override
  String get appearanceTextScaleSystemDesc =>
      'Segue as configurações de acessibilidade do dispositivo';

  @override
  String get appearanceTextScaleDefault => 'Padrão';

  @override
  String get appearanceTextScaleDefaultDesc =>
      'Tamanho fixo, ignora as configurações do dispositivo';

  @override
  String get appearanceTextScaleLarge => 'Grande';

  @override
  String get appearanceTextScaleLargeDesc => '15% maior que o padrão';

  @override
  String get appearanceTextScaleExtraLarge => 'Extra grande';

  @override
  String get appearanceTextScaleExtraLargeDesc => '30% maior que o padrão';

  @override
  String get appearanceDensityCompact => 'Compacto';

  @override
  String get appearanceDensityCompactDesc =>
      'Interface mais densa, mais conteúdo visível';

  @override
  String get appearanceDensityComfortable => 'Confortável';

  @override
  String get appearanceDensityComfortableDesc =>
      'Espaçamento equilibrado (padrão)';

  @override
  String get appearanceDensityLargeTouch => 'Toque grande';

  @override
  String get appearanceDensityLargeTouchDesc =>
      'Áreas de toque maiores, mais fácil de usar';

  @override
  String get appearanceContrastNormal => 'Normal';

  @override
  String get appearanceContrastNormalDesc => 'Contraste de cores padrão';

  @override
  String get appearanceContrastHigh => 'Alto contraste';

  @override
  String get appearanceContrastHighDesc =>
      'Visibilidade aprimorada para texto e interface';

  @override
  String get appearanceMotionNormal => 'Normal';

  @override
  String get appearanceMotionNormalDesc => 'Todas as animações habilitadas';

  @override
  String get appearanceMotionReduced => 'Reduzido';

  @override
  String get appearanceMotionReducedDesc =>
      'Animações mínimas para acessibilidade';

  @override
  String get appearanceFont => 'Fonte';

  @override
  String get appearanceTextSize => 'Tamanho do texto';

  @override
  String get appearanceDisplayDensity => 'Densidade da tela';

  @override
  String get appearanceContrast => 'Contraste';

  @override
  String get appearanceMotion => 'Movimento';

  @override
  String get appearanceResetSuccess =>
      'Configurações restauradas para os padrões';

  @override
  String get appearanceLivePreview => 'Pré-visualização';

  @override
  String get appearanceChangesApplyInstantly =>
      'As alterações são aplicadas instantaneamente';

  @override
  String get appearanceSampleText =>
      'Texto de exemplo para pré-visualizar suas configurações. Ajuste as opções abaixo para encontrar o que funciona melhor para você.';

  @override
  String get appearanceHighContrast => 'Alto contraste';

  @override
  String get appearanceHighContrastDesc =>
      'Visibilidade aprimorada para texto e elementos da UI';

  @override
  String get appearanceElementalAtmosphere => 'Atmosfera elemental';

  @override
  String get appearanceElementalDisabled =>
      'Desativada enquanto Reduzir movimento está ativo';

  @override
  String get appearanceElementalDesc =>
      'Efeitos de partículas ambientais impulsionados pela atividade mesh';

  @override
  String get appearanceReduceMotion => 'Reduzir movimento';

  @override
  String get appearanceReduceMotionDesc => 'Minimizar animações em todo o app';

  @override
  String get appearanceResetToRecommended => 'Restaurar recomendados';

  @override
  String get appearanceRestoreDefaults => 'Restaurar configurações padrão';

  @override
  String get appearanceUsingRecommended => 'Usando configurações recomendadas';

  @override
  String get appearanceResetDialogTitle => 'Restaurar padrões?';

  @override
  String get appearanceResetDialogMessage =>
      'Isso restaurará todas as configurações de aparência e acessibilidade para os valores recomendados.';

  @override
  String get appearanceResetDialogCancel => 'Cancelar';

  @override
  String get appearanceResetDialogConfirm => 'Restaurar';

  @override
  String get appearanceTimeFormat => 'Formato de hora';

  @override
  String get appearanceTimeFormatSystem => 'Padrão do sistema';

  @override
  String get appearanceTimeFormatSystemDesc =>
      'Seguir a configuração de relógio do dispositivo';

  @override
  String get appearanceTimeFormat12h => '12 horas';

  @override
  String get appearanceTimeFormat12hDesc => '1:30 PM';

  @override
  String get appearanceTimeFormat24h => '24 horas';

  @override
  String get appearanceTimeFormat24hDesc => '13:30';

  @override
  String get settingsSectionProfile => 'PERFIL';

  @override
  String get settingsSectionFileTransfer => 'TRANSFERÊNCIA DE ARQUIVOS';

  @override
  String get settingsGlyphMatrixTest => 'Teste de matriz de glifos';

  @override
  String get cloudSyncUnableToLoad =>
      'Não foi possível carregar as opções de assinatura';

  @override
  String get cloudSyncTitle => 'Desbloquear Cloud Sync';

  @override
  String get cloudSyncDescription =>
      'Sincronize seus dados mesh entre dispositivos. Seus dados locais sempre permanecem gratuitos e acessíveis.';

  @override
  String get cloudSyncNodeDex => 'NodeDex — encontros, tags, notas';

  @override
  String get cloudSyncAutomations => 'Automações — regras e gatilhos';

  @override
  String get cloudSyncWidgets => 'Widgets personalizados — layouts e dados';

  @override
  String get cloudSyncOfflineNote => 'Funciona totalmente offline sem ele';

  @override
  String get cloudSyncAutoRenewNote =>
      'As assinaturas são renovadas automaticamente, a menos que sejam canceladas pelo menos 24 horas antes do final do período atual.';

  @override
  String get cloudSyncYearlySave => 'Anual (Economize 44%)';

  @override
  String get cloudSyncMonthly => 'Mensal';

  @override
  String get cloudSyncRequired => 'Cloud Sync necessário';

  @override
  String get cloudSyncSubscriptionRestored => 'Assinatura restaurada';

  @override
  String get cloudSyncNoSubscription =>
      'Nenhuma assinatura Cloud Sync encontrada';

  @override
  String get cloudSyncRestoreFailed => 'Falha na restauração. Tente novamente.';

  @override
  String get cloudSyncExpiredMessage =>
      'Sua assinatura Cloud Sync expirou. Seus dados são somente leitura.';

  @override
  String get cloudSyncRenew => 'Renovar';

  @override
  String get cloudSyncPaymentIssue =>
      'Há um problema com seu pagamento. Atualize seu método de pagamento.';

  @override
  String get signalSettingsTitle => 'Sinais';

  @override
  String get signalSettingsPrivacy => 'PRIVACIDADE DE SINAIS';

  @override
  String get signalSettingsLocationRadius => 'Raio de localização do sinal';

  @override
  String get signalSettingsRadiusDescription =>
      'Os sinais são arredondados para este raio, não um endereço exato';

  @override
  String get signalSettingsContent => 'CONTEÚDO DE SINAIS';

  @override
  String get signalSettingsMaxImages => 'Máx. de imagens por sinal';

  @override
  String get signalSettingsImageLimit => 'Limite: 1-4 imagens';

  @override
  String get signalSettingsNotifications => 'NOTIFICAÇÕES DE SINAIS';

  @override
  String get signalSettingsNotifySignals => 'Sinais';

  @override
  String get signalSettingsNotifySignalsSubtitle =>
      'Notificar quando alguém publicar um sinal';

  @override
  String get signalSettingsNotifyVotes => 'Votos';

  @override
  String get signalSettingsNotifyVotesSubtitle =>
      'Quando alguém votar positivamente nos seus comentários de sinais';

  @override
  String get adminFollowTitle => 'Admin social';

  @override
  String get adminFollowTabRequests => 'Solicitações de seguir';

  @override
  String get adminFollowTabSeedData => 'Dados de seed';

  @override
  String get adminFollowErrorLoading => 'Erro ao carregar solicitações';

  @override
  String get adminFollowNoPending => 'Nenhuma solicitação pendente';

  @override
  String get adminFollowApproved => 'Solicitação aprovada';

  @override
  String adminFollowApproveFailed(String error) {
    return 'Falha ao aprovar: $error';
  }

  @override
  String get adminFollowDeclined => 'Solicitação recusada';

  @override
  String adminFollowDeclineFailed(String error) {
    return 'Falha ao recusar: $error';
  }

  @override
  String adminFollowRequestedTime(String time) {
    return 'Solicitado $time';
  }

  @override
  String get adminFollowDecline => 'Recusar';

  @override
  String get adminFollowAccept => 'Aceitar';

  @override
  String get adminFollowJustNow => 'agora';

  @override
  String adminFollowMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String adminFollowHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String adminFollowDaysAgo(int days) {
    return '${days}d atrás';
  }

  @override
  String get adminFollowTestData => 'Dados de teste';

  @override
  String get adminFollowProfiles => 'Perfis';

  @override
  String get adminFollowPosts => 'Publicações';

  @override
  String get adminFollowStories => 'Histórias';

  @override
  String get adminFollowComments => 'Comentários';

  @override
  String get adminFollowDummyUsers => 'Usuários fictícios';

  @override
  String get adminFollowLog => 'Registo';

  @override
  String get adminFollowResetAndSeed => 'Resetar e popular';

  @override
  String get adminFollowSeedData => 'Popular dados';

  @override
  String get adminFollowSeedDescription =>
      'Resetar e popular: limpa todos os dados fictícios primeiro, depois popula novos.\nPopular dados: adiciona aos dados existentes (pode criar duplicatas).';

  @override
  String adminFollowSeededSummary(
    int users,
    int posts,
    int stories,
    int comments,
  ) {
    return 'Populados $users usuários, $posts posts, $stories stories, $comments comentários';
  }

  @override
  String get adminPostsTitle => 'Sinais';

  @override
  String get adminPostsDeleteAll => 'Excluir todos os sinais';

  @override
  String get adminPostsRefresh => 'Atualizar snapshot';

  @override
  String get adminPostsFilterHint => 'Filtrar por conteúdo ou ID do autor';

  @override
  String adminPostsLoadFailed(String error) {
    return 'Falha ao carregar posts: $error';
  }

  @override
  String get adminPostsNoMatched => 'Nenhum post correspondente';

  @override
  String get adminPostsFilterAll => 'Todos';

  @override
  String get adminPostsFilterSignals => 'Sinais';

  @override
  String get adminPostsFilterExpired => 'Expirados';

  @override
  String get adminPostsFilterLocation => 'Localização';

  @override
  String get adminPostsFilterMedia => 'Mídia';

  @override
  String get adminPostsDeletePostTitle => 'Excluir post?';

  @override
  String get adminPostsDeletePostMessage =>
      'Excluir um post o remove do Firebase imediatamente. Isso não pode ser desfeito.';

  @override
  String get adminPostsDeleteConfirm => 'Excluir';

  @override
  String get adminPostsDeleteSignalsTitle => 'Excluir sinais?';

  @override
  String adminPostsDeleteFilteredMessage(int filtered, int total) {
    return 'Excluir filtrados ($filtered) ou todos ($total) os sinais.';
  }

  @override
  String adminPostsDeleteAllMessage(int total) {
    return 'Excluir todos os $total sinais.';
  }

  @override
  String get adminPostsDeleteWarning =>
      'Isso não pode ser desfeito. Digite DELETE para confirmar.';

  @override
  String get adminPostsDeleteHint => 'APAGAR';

  @override
  String get adminPostsNoText => '(sem texto)';

  @override
  String adminPostsAuthor(String authorId) {
    return 'Autor $authorId';
  }

  @override
  String adminPostsStats(int comments, int likes) {
    return 'Comentários $comments · Curtidas $likes';
  }

  @override
  String get adminPostsDeletePostTooltip => 'Excluir post';

  @override
  String get bgConnDisableTitle => 'Desativar conexão em segundo plano?';

  @override
  String get bgConnDisableBody =>
      'A conexão mesh pode ser perdida quando o app está em segundo plano. Você não receberá notificações de novas mensagens.';

  @override
  String get bgConnDisableConfirm => 'Desativar';

  @override
  String get bgConnTitle => 'Conexão em segundo plano';

  @override
  String get bgConnSectionConnection => 'CONEXÃO';

  @override
  String get bgConnToggleTitle => 'Conexão em segundo plano';

  @override
  String get bgConnToggleSubtitle =>
      'Manter o rádio mesh conectado quando o app está em segundo plano';

  @override
  String get bgConnSectionNotifications => 'NOTIFICAÇÕES EM SEGUNDO PLANO';

  @override
  String get bgConnDirectMessages => 'Mensagens diretas';

  @override
  String get bgConnDirectMessagesSubtitle =>
      'Notificar para DMs recebidas em segundo plano';

  @override
  String get bgConnChannelMessages => 'Mensagens do canal';

  @override
  String get bgConnChannelMessagesSubtitle =>
      'Notificar para mensagens do canal em segundo plano';

  @override
  String get bgConnNodeDiscovery => 'Descoberta de nós';

  @override
  String get bgConnNodeDiscoverySubtitle =>
      'Notificar quando novos nós forem detectados';

  @override
  String get bgConnSectionPersistentNotification => 'NOTIFICAÇÃO PERSISTENTE';

  @override
  String get bgConnSectionBattery => 'BATERIA';

  @override
  String get bgConnBatteryGuide => 'Guia de otimização de bateria';

  @override
  String get bgConnBatteryGuideSubtitle =>
      'Instruções específicas do fabricante para operação confiável em segundo plano';

  @override
  String get bgConnStyleMinimal => 'Mínimo';

  @override
  String get bgConnStyleDetailed => 'Detalhado';

  @override
  String get bgConnNotificationStyle => 'Estilo da notificação';

  @override
  String get bgConnStyleMinimalDesc => 'Mostra \"Conectado a [dispositivo]\"';

  @override
  String get bgConnStyleDetailedDesc =>
      'Mostra o status da conexão com contagem de nós e hora da última mensagem';

  @override
  String get bgConnSectionLiveActivity => 'LIVE ACTIVITY';

  @override
  String get bgConnLiveActivityTitle => 'Dynamic Island & Lock Screen';

  @override
  String get bgConnLiveActivitySubtitle =>
      'Show device connection status on the Dynamic Island and Lock Screen';

  @override
  String get bgConnLiveActivityDisableTitle => 'End Live Activity?';

  @override
  String get bgConnLiveActivityDisableBody =>
      'The current Dynamic Island activity will be ended immediately. Connection status will no longer appear on your Lock Screen.';

  @override
  String get bgConnLiveActivityDisableConfirm => 'End Activity';

  @override
  String get linkedDevicesTitle => 'Dispositivos vinculados';

  @override
  String get linkedDevicesSignInRequired => 'Login necessário';

  @override
  String get linkedDevicesSignInBody =>
      'Faça login para vincular seus dispositivos Meshtastic ao seu perfil social.';

  @override
  String get linkedDevicesLinkDescription =>
      'Vincule seus dispositivos Meshtastic ao seu perfil para que outros possam encontrar e seguir você na lista de nós.';

  @override
  String get linkedDevicesNoDevices => 'Nenhum dispositivo vinculado';

  @override
  String get linkedDevicesNoDevicesBody =>
      'Conecte-se a um dispositivo Meshtastic e toque em \"Vincular dispositivo atual\" acima.';

  @override
  String get linkedDevicesLinkAnother =>
      'Para vincular outro dispositivo, desconecte-se do dispositivo atual e conecte-se ao novo.';

  @override
  String get linkedDevicesLoadFailed =>
      'Falha ao carregar dispositivos vinculados';

  @override
  String get linkedDevicesDeviceNotFound => 'Dispositivo não encontrado';

  @override
  String get linkedDevicesUnknownDevice => 'Dispositivo desconhecido';

  @override
  String get linkedDevicesLinked => 'Dispositivo vinculado ao seu perfil';

  @override
  String linkedDevicesLinkFailed(String error) {
    return 'Falha ao vincular dispositivo: $error';
  }

  @override
  String get linkedDevicesPrimaryUpdated => 'Dispositivo principal atualizado';

  @override
  String linkedDevicesSetPrimaryFailed(String error) {
    return 'Falha ao definir principal: $error';
  }

  @override
  String get linkedDevicesUnlinkTitle => 'Desvincular dispositivo';

  @override
  String get linkedDevicesUnlinkBody =>
      'Remover este dispositivo do seu perfil? Outros não verão mais seu perfil ao visualizar este nó.';

  @override
  String get linkedDevicesUnlinkConfirm => 'Desvincular';

  @override
  String get linkedDevicesUnlinked => 'Dispositivo desvinculado';

  @override
  String linkedDevicesUnlinkFailed(String error) {
    return 'Falha ao desvincular: $error';
  }

  @override
  String get linkedDevicesConnectedDevice => 'Dispositivo conectado';

  @override
  String get linkedDevicesLinkButton => 'Vincular';

  @override
  String get linkedDevicesPrimaryBadge => 'PRINCIPAL';

  @override
  String get linkedDevicesSendMessage => 'Enviar mensagem';

  @override
  String get linkedDevicesViewOnMap => 'Ver no mapa';

  @override
  String get linkedDevicesSetAsPrimary => 'Definir como principal';

  @override
  String get linkedDevicesSetAsPrimarySubtitle =>
      'Mostrar este dispositivo no seu perfil';

  @override
  String get homeWidgetsTitle => 'Widgets da tela inicial';

  @override
  String get homeWidgetsSectionAvailable => 'WIDGETS DISPONÍVEIS';

  @override
  String get homeWidgetsMeshStatus => 'Status da mesh';

  @override
  String get homeWidgetsMeshStatusDesc =>
      'Mostra a contagem de nós conectados e a saúde da mesh';

  @override
  String get homeWidgetsSizeSmall => 'Pequeno';

  @override
  String get homeWidgetsSizeMedium => 'Médio';

  @override
  String get homeWidgetsSizeLarge => 'Grande';

  @override
  String get homeWidgetsRecentMessages => 'Mensagens recentes';

  @override
  String get homeWidgetsRecentMessagesDesc =>
      'Exibe as últimas mensagens da sua mesh';

  @override
  String get homeWidgetsDeviceBattery => 'Bateria do dispositivo';

  @override
  String get homeWidgetsDeviceBatteryDesc =>
      'Mostra o nível de bateria do dispositivo conectado';

  @override
  String get homeWidgetsQuickMessage => 'Mensagem rápida';

  @override
  String get homeWidgetsQuickMessageDesc =>
      'Envie uma resposta predefinida com um toque';

  @override
  String get homeWidgetsLocationBeacon => 'Beacon de localização';

  @override
  String get homeWidgetsLocationBeaconDesc =>
      'Compartilhe sua localização com um único toque';

  @override
  String get homeWidgetsSectionHowTo => 'COMO ADICIONAR WIDGETS';

  @override
  String get homeWidgetsSectionTips => 'DICAS';

  @override
  String get homeWidgetsAddToHomeScreen =>
      'Adicione widgets à tela inicial para acesso rápido';

  @override
  String get homeWidgetsIosLongPress => 'Pressione e segure na tela inicial';

  @override
  String get homeWidgetsIosLongPressDesc =>
      'Pressione e segure em uma área vazia até os apps tremerem';

  @override
  String get homeWidgetsIosTapPlus => 'Toque no botão +';

  @override
  String get homeWidgetsIosTapPlusDesc =>
      'Localizado no canto superior esquerdo';

  @override
  String get homeWidgetsIosSearch => 'Pesquise \"Socialmesh\"';

  @override
  String get homeWidgetsIosSearchDesc =>
      'Ou role para encontrar nossos widgets';

  @override
  String get homeWidgetsIosChooseSize => 'Escolha um tamanho de widget';

  @override
  String get homeWidgetsIosChooseSizeDesc =>
      'Deslize para ver os tamanhos disponíveis, toque em \"Adicionar widget\"';

  @override
  String get homeWidgetsIosPosition => 'Posicione e toque em OK';

  @override
  String get homeWidgetsIosPositionDesc => 'Arraste para a posição desejada';

  @override
  String get homeWidgetsAndroidLongPress => 'Pressione e segure uma área vazia';

  @override
  String get homeWidgetsAndroidTapWidgets => 'Toque em \"Widgets\"';

  @override
  String get homeWidgetsAndroidTapWidgetsDesc => 'No menu que aparece';

  @override
  String get homeWidgetsAndroidLongPressDrag => 'Pressione e arraste';

  @override
  String get homeWidgetsAndroidLongPressDragDesc =>
      'Segure o widget e coloque na tela inicial';

  @override
  String get homeWidgetsIosInstructions => 'Instruções iOS';

  @override
  String get homeWidgetsAndroidInstructions => 'Instruções Android';

  @override
  String get homeWidgetsTipAutoUpdate =>
      'Os widgets atualizam automaticamente quando conectado';

  @override
  String get homeWidgetsTipOffline =>
      'Dados offline exibidos quando desconectado';

  @override
  String get homeWidgetsTipTapToOpen =>
      'Toque em qualquer widget para abrir o app';

  @override
  String get homeWidgetsTipAccentColor =>
      'As cores dos widgets seguem sua cor de destaque';

  @override
  String get radioConfigSaved => 'Configuração de rádio salva';

  @override
  String radioConfigSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get radioConfigTitle => 'Rádio';

  @override
  String get radioConfigHelp => 'Ajuda';

  @override
  String get radioConfigSave => 'Salvar';

  @override
  String get radioConfigSectionRegion => 'REGIÃO';

  @override
  String get radioConfigSectionModemPreset => 'PRESET DO MODEM';

  @override
  String get radioConfigSectionTransmission => 'TRANSMISSÃO';

  @override
  String get radioConfigTxEnabled => 'Transmissão habilitada';

  @override
  String get radioConfigTxEnabledSubtitle =>
      'Permitir que o dispositivo transmita';

  @override
  String get radioConfigHopLimit => 'Limite de hops';

  @override
  String get radioConfigHopLimitSubtitle =>
      'Número de vezes que as mensagens podem ser retransmitidas';

  @override
  String get radioConfigTxPowerOverride => 'Override de potência TX';

  @override
  String get radioConfigTxPowerDefault => 'Padrão';

  @override
  String get radioConfigTxPowerSubtitle =>
      'Substituir potência de transmissão (0 = padrão)';

  @override
  String get radioConfigSectionAdvanced => 'AVANÇADO';

  @override
  String get radioConfigUsePreset => 'Usar preset';

  @override
  String get radioConfigUsePresetSubtitle =>
      'Usar configurações de modem predefinidas em vez de personalizadas';

  @override
  String get radioConfigBandwidth => 'Largura de banda';

  @override
  String get radioConfigSpreadFactor => 'Fator de Dispersão';

  @override
  String get radioConfigCodingRate => 'Taxa de Codificação';

  @override
  String get radioConfigFrequencySlot => 'Slot de frequência';

  @override
  String get radioConfigFrequencySlotSubtitle =>
      'A frequência de operação é calculada a partir da região, preset do modem e este valor. A maioria dos usuários deve manter o valor padrão.';

  @override
  String get radioConfigRxBoostedGain => 'Ganho RX aumentado';

  @override
  String get radioConfigRxBoostedGainSubtitle =>
      'Habilitar ganho aumentado em receptores SX126x';

  @override
  String get radioConfigFrequencyOverride => 'Override de frequência';

  @override
  String get radioConfigFrequencyOverrideSubtitle =>
      'Substituir frequência em MHz (0 = desabilitado)';

  @override
  String get radioConfigIgnoreMqtt => 'Ignorar MQTT';

  @override
  String get radioConfigIgnoreMqttSubtitle =>
      'Ignorar mensagens via MQTT deste dispositivo';

  @override
  String get radioConfigOkToMqtt => 'Ok para MQTT';

  @override
  String get radioConfigOkToMqttSubtitle =>
      'A configuração pode ser enviada via uplink MQTT';

  @override
  String get radioConfigRegionUnset => 'Não definida';

  @override
  String get radioConfigRegionNotConfigured => 'Não configurada';

  @override
  String get radioConfigRegionSelectHint =>
      'Selecione a região correspondente às regulamentações do seu país';

  @override
  String get radioConfigRegionUs => 'US';

  @override
  String get radioConfigRegionEu433 => 'UE 433';

  @override
  String get radioConfigRegionEu868 => 'UE 868';

  @override
  String get radioConfigRegionChina => 'China';

  @override
  String get radioConfigRegionJapan => 'Japão';

  @override
  String get radioConfigRegionAnz => 'ANZ';

  @override
  String get radioConfigRegionKorea => 'Coreia';

  @override
  String get radioConfigRegionTaiwan => 'Taiwan';

  @override
  String get radioConfigRegionRussia => 'Rússia';

  @override
  String get radioConfigRegionIndia => 'Índia';

  @override
  String get radioConfigRegionNz865 => 'NZ 865';

  @override
  String get radioConfigRegionThailand => 'Tailândia';

  @override
  String get radioConfigRegionUkraine433 => 'Ucrânia 433';

  @override
  String get radioConfigRegionUkraine868 => 'Ucrânia 868';

  @override
  String get radioConfigRegionMalaysia433 => 'Malásia 433';

  @override
  String get radioConfigRegionMalaysia919 => 'Malásia 919';

  @override
  String get radioConfigRegionSingapore => 'Singapura';

  @override
  String get radioConfigRegionLora24 => 'LoRa 2.4GHz';

  @override
  String get radioConfigPresetLongFast => 'Longo Rápido';

  @override
  String get radioConfigPresetLongFastDesc =>
      'Melhor alcance com boa velocidade';

  @override
  String get radioConfigPresetLongSlow => 'Longo Lento';

  @override
  String get radioConfigPresetLongSlowDesc => 'Alcance máximo, mais lento';

  @override
  String get radioConfigPresetVeryLongSlow => 'Muito Longo Lento';

  @override
  String get radioConfigPresetVeryLongSlowDesc =>
      'Alcance extremo, muito lento';

  @override
  String get radioConfigPresetLongModerate => 'Longo Moderado';

  @override
  String get radioConfigPresetLongModerateDesc => 'Bom equilíbrio';

  @override
  String get radioConfigPresetMediumFast => 'Médio Rápido';

  @override
  String get radioConfigPresetMediumFastDesc => 'Alcance médio, rápido';

  @override
  String get radioConfigPresetMediumSlow => 'Médio Lento';

  @override
  String get radioConfigPresetMediumSlowDesc => 'Alcance médio, confiável';

  @override
  String get radioConfigPresetShortFast => 'Curto Rápido';

  @override
  String get radioConfigPresetShortFastDesc => 'Curto alcance, mais rápido';

  @override
  String get radioConfigPresetShortSlow => 'Curto Lento';

  @override
  String get radioConfigPresetShortSlowDesc => 'Curto alcance, confiável';

  @override
  String get radioConfigPresetShortTurbo => 'Short Turbo';

  @override
  String get radioConfigPresetShortTurboDesc => 'Short range with turbo speed';

  @override
  String get radioConfigPresetLongTurbo => 'Long Turbo';

  @override
  String get radioConfigPresetLongTurboDesc => 'Long range with turbo speed';

  @override
  String get radioConfigPresetMustMatch =>
      'Todos os dispositivos na rede mesh devem usar o mesmo preset';

  @override
  String get radioConfigRebootWarning =>
      'Alterar as configurações de rádio causará a reinicialização do dispositivo. Todos os dispositivos na rede mesh devem usar a mesma região e preset de modem.';

  @override
  String get cannedModuleTitle => 'Módulo de mensagens predefinidas';

  @override
  String get cannedModuleSaved =>
      'Configuração de mensagens predefinidas salva';

  @override
  String cannedModuleSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get cannedModuleSave => 'Salvar';

  @override
  String get cannedModuleSectionOptions => 'OPÇÕES';

  @override
  String get cannedModuleEnabled => 'Habilitado';

  @override
  String get cannedModuleEnabledSubtitle =>
      'Habilitar módulo de mensagens predefinidas no dispositivo';

  @override
  String get cannedModuleSendBell => 'Enviar campainha';

  @override
  String get cannedModuleSendBellSubtitle =>
      'Enviar caractere de campainha com as mensagens';

  @override
  String get cannedModuleSectionDeviceMessages => 'MENSAGENS DO DISPOSITIVO';

  @override
  String get cannedModuleMessages => 'Mensagens';

  @override
  String get cannedModuleMessagesHint => 'Mensagem 1|Mensagem 2|Mensagem 3';

  @override
  String get cannedModuleMessagesHelp =>
      'Separe as mensagens com | (pipe). Essas mensagens serão armazenadas no dispositivo e podem ser enviadas usando entradas de hardware.';

  @override
  String get cannedModulePresetManual => 'Configuração manual';

  @override
  String get cannedModulePresetManualDesc =>
      'GPIO personalizado e configurações de eventos';

  @override
  String get cannedModulePresetRak => 'Encoder rotativo RAK';

  @override
  String get cannedModulePresetRakDesc =>
      'Pré-configurado para o encoder rotativo RAK';

  @override
  String get cannedModulePresetM5Stack => 'M5 Stack Card KB';

  @override
  String get cannedModulePresetM5StackDesc =>
      'Pré-configurado para Card KB / RAK Keypad';

  @override
  String get cannedModuleSectionPreset => 'PRESET DE CONFIGURAÇÃO';

  @override
  String get cannedModuleSectionControlType => 'TIPO DE CONTROLE';

  @override
  String get cannedModuleControlRotary => 'Encoder rotativo';

  @override
  String get cannedModuleControlRotaryDesc =>
      'Encoder simples que envia pulsos nos pinos A/B';

  @override
  String get cannedModuleControlUpDown => 'Botões cima/baixo';

  @override
  String get cannedModuleControlUpDownDesc =>
      'Usa definições A/B/Press do broker de entrada';

  @override
  String get cannedModuleSectionGpio => 'ENTRADAS GPIO';

  @override
  String get cannedModuleGpioPinA => 'Pino A';

  @override
  String get cannedModuleGpioPinB => 'Pino B';

  @override
  String get cannedModuleGpioPressPin => 'Pino de pressão';

  @override
  String get cannedModuleGpioPinUnset => 'Não definido';

  @override
  String cannedModuleGpioPinLabel(int pin) {
    return 'Pino $pin';
  }

  @override
  String get cannedModuleEventNone => 'Nenhum';

  @override
  String get cannedModuleEventUp => 'Cima';

  @override
  String get cannedModuleEventDown => 'Baixo';

  @override
  String get cannedModuleEventLeft => 'Esquerda';

  @override
  String get cannedModuleEventRight => 'Direita';

  @override
  String get cannedModuleEventSelect => 'Selecionar';

  @override
  String get cannedModuleEventBack => 'Voltar';

  @override
  String get cannedModuleEventCancel => 'Cancelar';

  @override
  String get cannedModuleSectionKeyMapping => 'MAPEAMENTO DE TECLAS';

  @override
  String get cannedModuleClockwiseEvent => 'Evento sentido horário';

  @override
  String get cannedModuleCounterClockwiseEvent => 'Evento sentido anti-horário';

  @override
  String get cannedModulePressEvent => 'Evento de pressão';

  @override
  String get cannedModuleInfoCard =>
      'Configura o módulo de mensagens predefinidas no dispositivo, que permite enviar mensagens predefinidas usando entradas de hardware como encoders rotativos ou botões.';

  @override
  String get positionConfigLocationDisabled =>
      'Os serviços de localização estão desabilitados. Habilite o GPS nas configurações do dispositivo.';

  @override
  String get positionConfigOpenSettings => 'Abrir configurações';

  @override
  String get positionConfigPermissionDenied =>
      'Permissão de localização negada. Conceda acesso à localização para usar este recurso.';

  @override
  String get positionConfigPermissionPermanentlyDenied =>
      'Permissão de localização negada permanentemente. Habilite nas configurações do dispositivo.';

  @override
  String get positionConfigLocationUpdated =>
      'Localização atualizada pelo GPS do telefone';

  @override
  String positionConfigLocationFailed(String error) {
    return 'Falha ao obter a localização: $error';
  }

  @override
  String get positionConfigSaved => 'Configuração de posição salva';

  @override
  String positionConfigSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get positionConfigTitle => 'Posição';

  @override
  String get positionConfigSave => 'Salvar';

  @override
  String get positionConfigSectionGpsMode => 'MODO GPS';

  @override
  String get positionConfigSectionBroadcast => 'CONFIGURAÇÕES DE TRANSMISSÃO';

  @override
  String get positionConfigSmartBroadcast => 'Transmissão inteligente';

  @override
  String get positionConfigSmartBroadcastSubtitle =>
      'Transmitir apenas quando a posição mudar significativamente';

  @override
  String get positionConfigBroadcastInterval =>
      'Intervalo de transmissão de posição';

  @override
  String get positionConfigBroadcastIntervalSubtitle =>
      'Tempo máximo entre transmissões de posição';

  @override
  String get positionConfigGpsUpdateInterval => 'Intervalo de atualização GPS';

  @override
  String get positionConfigGpsUpdateIntervalSubtitle =>
      'Frequência de verificação de posição do GPS do dispositivo';

  @override
  String get positionConfigSectionFixed => 'POSIÇÃO FIXA';

  @override
  String get positionConfigUseFixed => 'Usar posição fixa';

  @override
  String get positionConfigUseFixedSubtitle =>
      'Definir posição manualmente em vez de usar o GPS';

  @override
  String get positionConfigLatitude => 'Latitude';

  @override
  String get positionConfigLongitude => 'Longitude';

  @override
  String get positionConfigAltitude => 'Altitude (metros)';

  @override
  String get positionConfigGettingLocation => 'Obtendo localização...';

  @override
  String get positionConfigUseCurrentLocation => 'Usar localização atual';

  @override
  String get positionConfigFixedInfo =>
      'A posição fixa é útil para instalações estacionárias como roteadores ou estações base.';

  @override
  String get positionConfigSectionSmartBroadcast =>
      'CONFIGURAÇÕES DE TRANSMISSÃO INTELIGENTE';

  @override
  String get positionConfigMinDistance => 'Distância mínima';

  @override
  String get positionConfigMinDistanceSubtitle =>
      'Distância mínima percorrida antes de transmitir';

  @override
  String get positionConfigMinInterval => 'Intervalo mínimo';

  @override
  String get positionConfigMinIntervalSubtitle =>
      'A velocidade máxima de envio de atualizações de posição se a distância mínima for satisfeita';

  @override
  String get positionConfigSectionFlags => 'FLAGS DE POSIÇÃO';

  @override
  String get positionConfigFlagsInfo =>
      'Campos opcionais para incluir nas mensagens de posição. Mais flags significa pacotes maiores.';

  @override
  String get positionConfigFlagAltitude => 'Incluir altitude';

  @override
  String get positionConfigFlagAltitudeDesc =>
      'Incluir altitude nos relatórios de posição';

  @override
  String get positionConfigFlagSatsInView => 'Incluir satélites visíveis';

  @override
  String get positionConfigFlagSatsInViewDesc =>
      'Incluir número de satélites visíveis';

  @override
  String get positionConfigFlagSeqNumber => 'Incluir número de sequência';

  @override
  String get positionConfigFlagSeqNumberDesc =>
      'Incluir número de sequência da posição';

  @override
  String get positionConfigFlagTimestamp => 'Incluir timestamp';

  @override
  String get positionConfigFlagTimestampDesc => 'Incluir timestamp do GPS';

  @override
  String get positionConfigFlagHeading => 'Incluir direção';

  @override
  String get positionConfigFlagHeadingDesc => 'Incluir direção de deslocamento';

  @override
  String get positionConfigFlagSpeed => 'Incluir velocidade';

  @override
  String get positionConfigFlagSpeedDesc => 'Incluir velocidade no solo';

  @override
  String get positionConfigFlagMsl => 'Altitude sobre o nível do mar';

  @override
  String get positionConfigFlagMslDesc =>
      'Reportar altitude como MSL em vez de HAE';

  @override
  String get positionConfigFlagGeoidalSep => 'Incluir separação geoidal';

  @override
  String get positionConfigFlagGeoidalSepDesc =>
      'Incluir valor de separação geoidal';

  @override
  String get positionConfigFlagDop => 'Incluir DOP';

  @override
  String get positionConfigFlagDopDesc => 'Incluir diluição da precisão (PDOP)';

  @override
  String get positionConfigFlagHvdop => 'Usar HDOP / VDOP';

  @override
  String get positionConfigFlagHvdopDesc =>
      'Enviar HDOP/VDOP separados em vez de PDOP';

  @override
  String get positionConfigSectionGpsGpio => 'GPIO GPS';

  @override
  String get positionConfigGpsRxGpio => 'GPIO RX GPS';

  @override
  String get positionConfigGpsRxGpioDesc => 'Pino GPIO para sinal RX do GPS';

  @override
  String get positionConfigGpsTxGpio => 'GPIO TX GPS';

  @override
  String get positionConfigGpsTxGpioDesc => 'Pino GPIO para sinal TX do GPS';

  @override
  String get positionConfigGpsEnableGpio => 'GPIO de habilitação GPS';

  @override
  String get positionConfigGpsEnableGpioDesc =>
      'Pino GPIO para controlar a alimentação do GPS';

  @override
  String get positionConfigGpioPinUnset => 'Não definido';

  @override
  String positionConfigGpioPinLabel(int pin) {
    return 'Pino $pin';
  }

  @override
  String get positionConfigGpsModeEnabled => 'Habilitado';

  @override
  String get positionConfigGpsModeEnabledDesc =>
      'O GPS está ativo e reporta a posição';

  @override
  String get positionConfigGpsModeDisabled => 'Desabilitado';

  @override
  String get positionConfigGpsModeDisabledDesc =>
      'O hardware GPS está presente mas desligado';

  @override
  String get positionConfigGpsModeNotPresent => 'Não presente';

  @override
  String get positionConfigGpsModeNotPresentDesc =>
      'Nenhum hardware GPS neste dispositivo';

  @override
  String get positionConfigIntervalNever => 'Nunca';

  @override
  String get positionConfigIntervalDefault => 'Padrão';

  @override
  String get positionConfigIntervalOnBoot => 'Apenas na inicialização';

  @override
  String get powerConfigSaved => 'Configuração de energia salva';

  @override
  String powerConfigSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get powerConfigDisabled => 'Desativado';

  @override
  String get powerConfigTitle => 'Energia';

  @override
  String get powerConfigSave => 'Salvar';

  @override
  String get powerConfigSectionPower => 'ENERGIA';

  @override
  String get powerConfigPowerSaving => 'Modo de economia de energia';

  @override
  String get powerConfigPowerSavingSubtitle =>
      'Reduzir consumo de energia quando ocioso';

  @override
  String get powerConfigShutdownOnPowerLoss => 'Desligar ao perder energia';

  @override
  String get powerConfigShutdownOnPowerLossSubtitle =>
      'Desligar dispositivo quando a energia externa for removida';

  @override
  String get powerConfigShutdownDelay => 'Atraso de desligamento';

  @override
  String get powerConfigShutdownDelaySubtitle =>
      'Tempo de espera antes de desligar após perda de energia';

  @override
  String get powerConfigSectionBattery => 'BATERIA';

  @override
  String get powerConfigAdcMultiplierOverride => 'Substituir multiplicador ADC';

  @override
  String get powerConfigAdcMultiplierOverrideSubtitle =>
      'Substituir razão do divisor de tensão para leitura da bateria';

  @override
  String get powerConfigAdcMultiplier => 'Multiplicador ADC';

  @override
  String get powerConfigAdcMultiplierHint =>
      'Razão do divisor de tensão (2.0 - 6.0)';

  @override
  String get powerConfigSectionSleep => 'CONFIGURAÇÕES DE SUSPENSÃO';

  @override
  String get powerConfigWaitBluetooth => 'Aguardar Bluetooth';

  @override
  String get powerConfigWaitBluetoothSubtitle =>
      'Tempo de espera por conexão Bluetooth antes de suspender';

  @override
  String get powerConfigLightSleep => 'Duração da suspensão leve';

  @override
  String get powerConfigLightSleepSubtitle =>
      'Duração da suspensão leve antes da suspensão profunda';

  @override
  String get powerConfigDeepSleep => 'Duração da suspensão profunda';

  @override
  String get powerConfigDeepSleepSubtitle =>
      'Duração da suspensão profunda (SDS)';

  @override
  String get powerConfigMinWakeTime => 'Tempo mínimo acordado';

  @override
  String get powerConfigMinWakeTimeSubtitle =>
      'Tempo mínimo que o dispositivo permanece ativo';

  @override
  String get powerConfigWarning =>
      'As configurações de energia afetam a duração da bateria e a capacidade de resposta do dispositivo. Configurações agressivas de suspensão podem causar atrasos no recebimento de mensagens.';

  @override
  String get networkConfigNoWifiTitle => 'Sem hardware WiFi';

  @override
  String get networkConfigNoWifiBody =>
      'Este dispositivo não possui hardware WiFi. Ativar o WiFi tornará o dispositivo inacessível via BLE. Continuar?';

  @override
  String get networkConfigSaveAnyway => 'Salvar mesmo assim';

  @override
  String get networkConfigSaved => 'Configuração de rede salva';

  @override
  String networkConfigSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get networkConfigTitle => 'Rede';

  @override
  String get networkConfigSave => 'Salvar';

  @override
  String get networkConfigSectionWifi => 'WI-FI';

  @override
  String get networkConfigNoWifiWarning =>
      'Este dispositivo não possui hardware WiFi. Ativar o WiFi tornará o dispositivo inacessível via Bluetooth.';

  @override
  String get networkConfigWifiEnabled => 'WiFi ativado';

  @override
  String get networkConfigWifiEnabledSubtitle => 'Conectar a uma rede WiFi';

  @override
  String get networkConfigSsid => 'Nome da rede (SSID)';

  @override
  String get networkConfigPassword => 'Senha';

  @override
  String get networkConfigSectionEthernet => 'ETHERNET';

  @override
  String get networkConfigEthernetEnabled => 'Ethernet ativado';

  @override
  String get networkConfigEthernetEnabledSubtitle =>
      'Usar conexão Ethernet com fio';

  @override
  String get networkConfigSectionIpAddress => 'ENDEREÇO IP';

  @override
  String get networkConfigSectionTimeSync => 'SINCRONIZAÇÃO DE HORÁRIO';

  @override
  String get networkConfigNtpServer => 'Servidor NTP';

  @override
  String get networkConfigNtpServerSubtitle =>
      'Servidor usado para sincronização de horário';

  @override
  String get networkConfigSectionUdpBroadcast => 'BROADCAST UDP';

  @override
  String get networkConfigUdpBroadcast => 'Broadcast UDP';

  @override
  String get networkConfigUdpBroadcastSubtitle =>
      'Transmitir pacotes pela rede local';

  @override
  String get networkConfigUdpBroadcastInfo =>
      'Habilita a transmissão de pacotes mesh via UDP pela rede local. Útil para conectar múltiplas instâncias.';

  @override
  String get networkConfigSectionLogging => 'LOG';

  @override
  String get networkConfigNoHardwareInfo =>
      'As configurações de rede estão disponíveis apenas em dispositivos com suporte a hardware WiFi ou Ethernet.';

  @override
  String get networkConfigIpModeDhcp => 'DHCP';

  @override
  String get networkConfigIpModeDhcpDesc => 'Obter endereço IP automaticamente';

  @override
  String get networkConfigIpModeStatic => 'Estático';

  @override
  String get networkConfigIpModeStaticDesc =>
      'Usar endereço IP configurado manualmente';

  @override
  String get networkConfigRsyslogServer => 'Servidor Rsyslog';

  @override
  String get networkConfigRsyslogServerSubtitle =>
      'Servidor syslog remoto para logs do dispositivo';

  @override
  String get ringtoneTitle => 'Toque';

  @override
  String get ringtoneDeviceRingtone => 'Toque do dispositivo';

  @override
  String get ringtoneCurrentlySet => 'Atualmente definido no dispositivo';

  @override
  String get ringtoneSaved => 'Toque salvo no dispositivo';

  @override
  String ringtoneSaveFailed(String error) {
    return 'Falha ao salvar toque: $error';
  }

  @override
  String get ringtoneAccessPremium => 'Acesse predefinições de toques premium';

  @override
  String get ringtoneCustomAdded => 'Toque personalizado adicionado';

  @override
  String get ringtoneRtttlGuideTitle => 'Guia do formato RTTTL';

  @override
  String get ringtoneRtttlWhat => 'O que é RTTTL?';

  @override
  String get ringtoneRtttlWhatContent =>
      'Ring Tone Text Transfer Language (RTTTL) é um formato desenvolvido pela Nokia para codificar toques como strings de texto.';

  @override
  String get ringtoneRtttlFormat => 'Formato';

  @override
  String get ringtoneRtttlHeader => 'Cabeçalho';

  @override
  String get ringtoneRtttlHeaderContent => 'nome:d=duração,o=oitava,b=bpm';

  @override
  String get ringtoneRtttlNotes => 'Notas';

  @override
  String get ringtoneRtttlNotesContent =>
      'duração, nota, oitava (ex. 8c5 = colcheia Dó na oitava 5)';

  @override
  String get ringtoneRtttlExample => 'Exemplo';

  @override
  String get ringtoneRtttlComposerTip =>
      'Experimente o Nokia Composer online para criar e ouvir strings RTTTL';

  @override
  String get ringtoneRtttlHelp => 'Ajuda RTTTL';

  @override
  String get ringtoneSave => 'Salvar';

  @override
  String get ringtoneSectionRtttl => 'STRING RTTTL';

  @override
  String get ringtoneRtttlHint => 'Cole ou selecione um toque RTTTL...';

  @override
  String get ringtoneStop => 'Parar';

  @override
  String get ringtonePreview => 'Pré-escuta';

  @override
  String get ringtoneClear => 'Limpar';

  @override
  String get ringtoneTapPreview =>
      'Toque em Pré-escuta para ouvir, depois Salvar no dispositivo';

  @override
  String get ringtoneSectionLibrary => 'BIBLIOTECA DE TOQUES';

  @override
  String ringtoneBrowseCount(int count) {
    return 'Explorar $count toques';
  }

  @override
  String get ringtoneBrowseSubtitle =>
      'Pesquise melodias clássicas, temas de TV, trilhas sonoras e mais';

  @override
  String get ringtoneSectionSelected => 'TOQUE SELECIONADO';

  @override
  String get ringtoneSectionBuiltIn => 'PREDEFINIÇÕES INTEGRADAS';

  @override
  String get ringtoneSectionCustom => 'PREDEFINIÇÕES PERSONALIZADAS';

  @override
  String get ringtoneAdd => 'Adicionar';

  @override
  String get ringtoneNoCustom => 'Nenhum toque personalizado';

  @override
  String get ringtoneNoCustomBody =>
      'Toque em \"Adicionar\" para criar suas predefinições';

  @override
  String get ringtoneFindDeviceTip => 'Dica: Encontre seu dispositivo';

  @override
  String get ringtoneFindDeviceBody =>
      'Envie uma mensagem com o emoji de sino (🔔) para fazer o dispositivo tocar.';

  @override
  String get ringtoneNameRequired => 'O nome é obrigatório';

  @override
  String get ringtoneDefaultDescription => 'Toque personalizado';

  @override
  String get ringtoneAddCustomTitle => 'Adicionar toque personalizado';

  @override
  String get ringtoneAddCustomSubtitle =>
      'Crie uma predefinição de toque RTTTL personalizada';

  @override
  String get ringtoneAddCustomName => 'Nome';

  @override
  String get ringtoneAddCustomRtttl => 'String RTTTL';

  @override
  String get ringtoneAddCustomDescription => 'Descrição (opcional)';

  @override
  String get ringtoneLibraryTitle => 'Biblioteca de toques';

  @override
  String get ringtoneLibrarySearchHint =>
      'Pesquise por música, artista ou tema...';

  @override
  String get ringtoneLibraryPopularPicks => 'Mais populares';

  @override
  String get ringtoneLibraryNoResults => 'Nenhum resultado encontrado';

  @override
  String get ringtoneLibraryStartTyping => 'Comece a digitar para pesquisar';

  @override
  String get ringtoneLibraryTryDifferent =>
      'Tente um termo de pesquisa diferente';

  @override
  String ringtoneLibrarySearchCount(int count) {
    return 'Pesquisar entre $count toques disponíveis';
  }

  @override
  String get ringtoneValidationEmpty => 'A string RTTTL não pode estar vazia';

  @override
  String ringtoneValidationTooLong(int length, int max) {
    return 'Muito longo: $length/$max caracteres. O toque será truncado.';
  }

  @override
  String get ringtoneValidationMissingColons =>
      'Formato inválido: dois-pontos ausentes. Esperado nome:padrões:notas';

  @override
  String get ringtoneValidationInvalidFormat =>
      'Formato inválido: esperado nome:padrões:notas';

  @override
  String get ringtoneValidationInvalidDefaults =>
      'Padrões inválidos: esperado d=duração, o=oitava, b=bpm';

  @override
  String get ringtoneValidationNoNotes =>
      'Nenhuma nota encontrada na string RTTTL';

  @override
  String ringtoneValidationInvalidNote(String note) {
    return 'Nota inválida: \"$note\"';
  }

  @override
  String get ringtoneValidationNoValidNotes => 'Nenhuma nota válida encontrada';

  @override
  String get accountSubTitle => 'Conta';

  @override
  String get accountSubSectionAccount => 'CONTA';

  @override
  String get accountSubSectionPremium => 'PREMIUM';

  @override
  String get accountSubSectionManage => 'GERENCIAR';

  @override
  String get accountSubGuestAccount => 'Conta de visitante';

  @override
  String get accountSubSignedIn => 'Conectado';

  @override
  String get accountSubLinkedAccounts => 'Contas vinculadas';

  @override
  String get accountSubLinkEmailPrompt =>
      'Vincule um e-mail para manter seus dados em vários dispositivos';

  @override
  String get accountSubLinkAccountBtn => 'Vincular conta';

  @override
  String get accountSubMfaRequiresInternet =>
      'A autenticação de dois fatores requer conexão com a internet.';

  @override
  String get accountSubSignOutBtn => 'Sair';

  @override
  String get accountSubSignInToSync =>
      'Entre para sincronizar entre dispositivos';

  @override
  String get accountSubLocalDataAvailable =>
      'Seus dados locais estão sempre disponíveis';

  @override
  String get accountSubContinueGoogle => 'Continuar com Google';

  @override
  String get accountSubContinueApple => 'Continuar com Apple';

  @override
  String get accountSubContinueGitHub => 'Continuar com GitHub';

  @override
  String get accountSubContinueX => 'Continuar com X';

  @override
  String get accountSubExpiresToday => 'Expira hoje';

  @override
  String get accountSubExpiresTomorrow => 'Expira amanhã';

  @override
  String accountSubExpiresDate(int day, String month) {
    return 'Expira em $day $month';
  }

  @override
  String accountSubCancelledExpires(String expiresText) {
    return 'Cancelado · $expiresText';
  }

  @override
  String get accountSubPaymentIssue =>
      'Problema no pagamento - atualize os dados';

  @override
  String get accountSubSignInToSyncShort => 'Entre para sincronizar';

  @override
  String get accountSubMonthlySubscription => 'Assinatura mensal';

  @override
  String get accountSubSubscriptionExpired => 'Assinatura expirada';

  @override
  String get accountSubSignInToEnable => 'Entre acima para ativar';

  @override
  String get accountSubSyncAllDevices =>
      'Sincronize em todos os seus dispositivos';

  @override
  String get accountSubBadgeCancelled => 'CANCELADO';

  @override
  String get accountSubBadgeActive => 'ATIVO';

  @override
  String get accountSubBadgeExpired => 'EXPIRADO';

  @override
  String get accountSubCloudSync => 'Sincronização na nuvem';

  @override
  String get accountSubWontRenew =>
      'Sua assinatura não será renovada. Você pode reassinar a qualquer momento.';

  @override
  String get accountSubFeatureNodedex => 'NodeDex — encontros, tags, notas';

  @override
  String get accountSubFeatureAutomations => 'Automações — regras e gatilhos';

  @override
  String get accountSubFeatureWidgets =>
      'Widgets personalizados — layouts e dados';

  @override
  String get accountSubFeatureBackup =>
      'Backup — restaure após reinstalação ou novo celular';

  @override
  String get accountSubFeatureOffline =>
      'Funciona totalmente offline sem assinatura';

  @override
  String get accountSubRenewSubscription => 'Renovar assinatura';

  @override
  String get accountSubManageSubscription => 'Gerenciar assinatura';

  @override
  String get accountSubSignInToSubscribe => 'Entre para assinar';

  @override
  String get accountSubSubRequiresInternet =>
      'Assinaturas requerem conexão com a internet.';

  @override
  String get accountSubRenew => 'Renovar';

  @override
  String get accountSubSubscribe => 'Assinar';

  @override
  String get accountSubCouldNotLoadStatus =>
      'Não foi possível carregar o status da assinatura';

  @override
  String get accountSubFeaturePacks => 'Pacotes de recursos';

  @override
  String get accountSubAllUnlocked => 'Todos os recursos desbloqueados!';

  @override
  String accountSubOneTimePurchases(int owned, int total) {
    return 'Compras únicas · $owned de $total';
  }

  @override
  String get accountSubViewFeatures => 'Ver recursos';

  @override
  String get accountSubPremiumRequiresInternet =>
      'Recursos premium requerem conexão com a internet para compra.';

  @override
  String get accountSubViewAndPurchase => 'Ver e comprar';

  @override
  String get accountSubRestorePurchases => 'Restaurar compras';

  @override
  String get accountSubRestorePurchasesSubtitle =>
      'Restaurar itens comprados anteriormente';

  @override
  String get accountSubRestoreRequiresInternet =>
      'A restauração de compras requer conexão com a internet.';

  @override
  String get accountSubPurchasesRestored => 'Compras restauradas com sucesso!';

  @override
  String get accountSubPurchasesAlreadyActive => 'Suas compras já estão ativas';

  @override
  String get accountSubNoPurchasesFound =>
      'Nenhuma compra encontrada para restaurar';

  @override
  String get accountSubTermsOfService => 'Termos de serviço';

  @override
  String get accountSubPrivacyPolicy => 'Política de privacidade';

  @override
  String get accountSubSignInRequiresInternet =>
      'O login requer conexão com a internet.';

  @override
  String get accountSubCannotConnectSignIn =>
      'Não foi possível conectar aos serviços de login. Verifique sua conexão com a internet e tente novamente.';

  @override
  String accountSubSignInFailed(String message) {
    return 'Falha no login: $message';
  }

  @override
  String get accountSubSignInFailedRetry => 'Falha no login. Tente novamente.';

  @override
  String get accountSubLinkGitHubTitle => 'Vincular conta GitHub';

  @override
  String accountSubAccountExistsLinking(String email, String provider) {
    return 'Já existe uma conta com $email usando $provider.\n\nEntrar com $provider para vincular sua conta GitHub?';
  }

  @override
  String accountSubSignInWithProvider(String provider) {
    return 'Entrar com $provider';
  }

  @override
  String get accountSubGitHubLinked => 'Conta GitHub vinculada com sucesso!';

  @override
  String get accountSubFailedLinkAccounts => 'Falha ao vincular contas';

  @override
  String get accountSubSignOutRequiresInternet =>
      'Sair requer conexão com a internet.';

  @override
  String get accountSubSignOutConfirmTitle => 'Sair';

  @override
  String get accountSubSignOutConfirmMsg => 'Tem certeza de que deseja sair?';

  @override
  String get accountSubSignedOutSuccess => 'Desconectado';

  @override
  String accountSubGenericError(String error) {
    return 'Erro: $error';
  }

  @override
  String get accountSubLinkAccountSheetTitle => 'Vincular conta';

  @override
  String get accountSubLinkSignInMethod =>
      'Vincule um método de login para manter seus dados';

  @override
  String get accountSubLinkWithGoogle => 'Vincular com Google';

  @override
  String get accountSubLinkWithApple => 'Vincular com Apple';

  @override
  String get accountSubLinkWithX => 'Vincular com X';

  @override
  String get accountSubManageSubRequiresInternet =>
      'O gerenciamento de assinaturas requer conexão com a internet.';

  @override
  String get accountSubIosManageHint =>
      'Vá em Ajustes > ID Apple > Assinaturas para gerenciar';

  @override
  String get accountSubAndroidManageHint =>
      'Vá em Play Store > Pagamentos e assinaturas para gerenciar';

  @override
  String get accountSubGuestName => 'Visitante';

  @override
  String get accountSubTapToEditProfile => 'Toque para editar perfil';

  @override
  String get accountSubSignInToCreateProfile => 'Entre para criar um perfil';

  @override
  String get accountSubTwoFactorAuth => 'Autenticação de dois fatores';

  @override
  String get accountSubBadgeOffline => 'Offline';

  @override
  String get accountSubBadgeUnavailable => 'Indisponível';

  @override
  String get accountSubBadgeOn => 'ON';

  @override
  String get accountSubSyncSyncing => 'Sincronizando';

  @override
  String get accountSubSyncSynced => 'Sincronizado';

  @override
  String get accountSubSyncError => 'Erro';

  @override
  String get accountSubSyncReady => 'Pronto';

  @override
  String get accountSubSyncOffline => 'Offline';

  @override
  String get accountSubMonthJanuary => 'Janeiro';

  @override
  String get accountSubMonthFebruary => 'Fevereiro';

  @override
  String get accountSubMonthMarch => 'Março';

  @override
  String get accountSubMonthApril => 'Abril';

  @override
  String get accountSubMonthMay => 'Maio';

  @override
  String get accountSubMonthJune => 'Junho';

  @override
  String get accountSubMonthJuly => 'Julho';

  @override
  String get accountSubMonthAugust => 'Agosto';

  @override
  String get accountSubMonthSeptember => 'Setembro';

  @override
  String get accountSubMonthOctober => 'Outubro';

  @override
  String get accountSubMonthNovember => 'Novembro';

  @override
  String get accountSubMonthDecember => 'Dezembro';

  @override
  String get accountSubUnlockCloudSync => 'Desbloquear Cloud Sync';

  @override
  String get accountSubSyncBackupAll =>
      'Sincronize e faça backup dos seus dados mesh em todos os dispositivos';

  @override
  String get accountSubCouldNotLoadPrices =>
      'Não foi possível carregar os preços';

  @override
  String get accountSubSubActivated => 'Assinatura ativada!';

  @override
  String get accountSubPurchaseFailed => 'Falha na compra';

  @override
  String get accountSubAutoRenewDisclaimer =>
      'As assinaturas são renovadas automaticamente, a menos que sejam canceladas pelo menos 24 horas antes do fim do período atual.';

  @override
  String get accountSubYearlySave => 'Anual (Economize 44%)';

  @override
  String get accountSubMonthlyProduct => 'Mensal';

  @override
  String get accountSubLinkingRequiresInternet =>
      'Vincular uma conta requer conexão com a internet.';

  @override
  String get accountSubConfirm => 'Confirmar';

  @override
  String get accountSubCancel => 'Cancelar';

  @override
  String get dataExportTitle => 'Exportar dados';

  @override
  String get dataExportSectionMessages => 'Mensagens';

  @override
  String get dataExportSectionTelemetry => 'Telemetria';

  @override
  String get dataExportSectionPositionData => 'Dados de posição';

  @override
  String get dataExportSectionAutomations => 'Automações';

  @override
  String get dataExportSectionNetwork => 'Rede';

  @override
  String get dataExportSectionCompleteExport => 'Exportação completa';

  @override
  String get dataExportSectionClearData => 'Limpar dados';

  @override
  String get dataExportAllMessages => 'Todas as mensagens';

  @override
  String get dataExportAllMessagesSubtitle =>
      'Exportar todas as mensagens de canal e diretas';

  @override
  String get dataExportDeviceMetrics => 'Métricas do dispositivo';

  @override
  String get dataExportDeviceMetricsSubtitle =>
      'Logs de bateria, voltagem, utilização';

  @override
  String get dataExportEnvironmentMetrics => 'Métricas ambientais';

  @override
  String get dataExportEnvironmentMetricsSubtitle =>
      'Logs de temperatura, umidade, pressão';

  @override
  String get dataExportAirQuality => 'Qualidade do ar';

  @override
  String get dataExportAirQualitySubtitle => 'Leituras de PM2.5, PM10, CO2';

  @override
  String get dataExportPowerMetrics => 'Métricas de energia';

  @override
  String get dataExportPowerMetricsSubtitle => 'Voltagem e corrente do canal';

  @override
  String get dataExportPositionHistory => 'Histórico de posições';

  @override
  String get dataExportPositionHistorySubtitle =>
      'Logs de posição GPS com marcações temporais';

  @override
  String get dataExportRoutes => 'Rotas';

  @override
  String get dataExportRoutesSubtitle => 'Rotas e trilhas gravadas';

  @override
  String get dataExportTraceroutes => 'Traceroutes';

  @override
  String get dataExportTraceroutesSubtitle => 'Análise de caminho de rede';

  @override
  String get dataExportAutomationRules => 'Regras de automação';

  @override
  String get dataExportAutomationRulesSubtitle =>
      'Todas as configurações de automação';

  @override
  String get dataExportExecutionLog => 'Log de execução';

  @override
  String get dataExportExecutionLogSubtitle =>
      'Histórico de gatilhos de automação com resultados';

  @override
  String get dataExportNodeList => 'Lista de nós';

  @override
  String get dataExportNodeListSubtitle =>
      'Todos os nós descobertos com detalhes';

  @override
  String get dataExportExportAll => 'Exportar todos os dados';

  @override
  String get dataExportExportAllSubtitle =>
      'Backup completo de todos os dados do app';

  @override
  String get dataExportClearAll => 'Limpar todos os dados';

  @override
  String get dataExportClearAllSubtitle =>
      'Excluir todos os dados de telemetria, rotas e logs';

  @override
  String get dataExportInfoText =>
      'Os arquivos exportados podem ser compartilhados por e-mail, AirDrop ou salvos em Arquivos. Toque no ícone de lixeira para limpar dados específicos.';

  @override
  String get dataExportFormatCsv => 'CSV';

  @override
  String get dataExportFormatGpx => 'GPX';

  @override
  String get dataExportFormatJson => 'JSON';

  @override
  String get dataExportTooltipClearData => 'Limpar dados';

  @override
  String get dataExportTooltipExport => 'Exportar';

  @override
  String dataExportClearConfirmTitle(String dataName) {
    return 'Limpar $dataName?';
  }

  @override
  String dataExportClearConfirmMsg(String dataName) {
    return 'Isso excluirá permanentemente todos os dados de $dataName. Esta ação não pode ser desfeita.';
  }

  @override
  String get dataExportClearConfirmBtn => 'Excluir';

  @override
  String get dataExportClearAllConfirmTitle => 'Limpar todos os dados?';

  @override
  String get dataExportClearAllConfirmMsg =>
      'Isso excluirá permanentemente TODOS os dados, incluindo telemetria, rotas e logs de automação. Esta ação não pode ser desfeita.';

  @override
  String get dataExportClearAllConfirmBtn => 'Excluir tudo';

  @override
  String dataExportExportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get dataExportDataCleared => 'Dados limpos';

  @override
  String dataExportClearFailed(String error) {
    return 'Falha ao limpar dados: $error';
  }

  @override
  String get dataExportAllDataCleared => 'Todos os dados limpos';

  @override
  String get dataExportNoRoutesToExport => 'Nenhuma rota para exportar';

  @override
  String get dataExportNoAutomationsToExport =>
      'Nenhuma automação para exportar';

  @override
  String get dataExportNoAutomationLogEntries =>
      'Nenhuma entrada no log de automação';

  @override
  String get dataExportClearAllMessages => 'todas as mensagens';

  @override
  String get dataExportClearDeviceMetrics => 'métricas do dispositivo';

  @override
  String get dataExportClearEnvironmentMetrics => 'métricas ambientais';

  @override
  String get dataExportClearAirQualityData => 'dados de qualidade do ar';

  @override
  String get dataExportClearPowerMetrics => 'métricas de energia';

  @override
  String get dataExportClearPositionHistory => 'histórico de posições';

  @override
  String get dataExportClearAllRoutes => 'todas as rotas';

  @override
  String get dataExportClearTracerouteData => 'dados de traceroute';

  @override
  String get dataExportClearAllAutomationRules =>
      'todas as regras de automação';

  @override
  String get dataExportClearAutomationLog => 'log de automação';

  @override
  String get dataExportShareSubjectMessages =>
      'Exportação de mensagens Socialmesh';

  @override
  String get dataExportShareSubjectDeviceMetrics =>
      'Exportação de métricas do dispositivo Socialmesh';

  @override
  String get dataExportShareSubjectEnvironmentMetrics =>
      'Exportação de métricas ambientais Socialmesh';

  @override
  String get dataExportShareSubjectAirQuality =>
      'Exportação de qualidade do ar Socialmesh';

  @override
  String get dataExportShareSubjectPowerMetrics =>
      'Exportação de métricas de energia Socialmesh';

  @override
  String get dataExportShareSubjectPositionHistory =>
      'Exportação de histórico de posições Socialmesh';

  @override
  String get dataExportShareSubjectRoutes => 'Exportação de rotas Socialmesh';

  @override
  String get dataExportShareSubjectTraceroutes =>
      'Exportação de traceroute Socialmesh';

  @override
  String get dataExportShareSubjectAutomations =>
      'Exportação de automações Socialmesh';

  @override
  String get dataExportShareSubjectAutomationLog =>
      'Exportação de log de automação Socialmesh';

  @override
  String get dataExportShareSubjectNodeList =>
      'Exportação de lista de nós Socialmesh';

  @override
  String get dataExportShareSubjectComplete => 'Exportação completa Socialmesh';

  @override
  String get dataExportUnknownSender => 'Desconhecido';

  @override
  String get dataExportSnrNotAvailable => 'N/D';

  @override
  String get deviceMgmtTitle => 'Gerenciamento do dispositivo';

  @override
  String deviceMgmtDefaultWarning(String action) {
    return 'Tem certeza que deseja $action? Esta ação não pode ser desfeita.';
  }

  @override
  String deviceMgmtSuccessDisconnect(String action) {
    return '$action - o dispositivo será desconectado';
  }

  @override
  String deviceMgmtSuccessCommandSent(String action) {
    return 'Comando $action enviado';
  }

  @override
  String deviceMgmtFailed(String error) {
    return 'Falha: $error';
  }

  @override
  String get deviceMgmtNotConnected =>
      'Dispositivo não conectado. Conecte um dispositivo para gerenciá-lo.';

  @override
  String get deviceMgmtSectionPower => 'ENERGIA';

  @override
  String get deviceMgmtSectionTime => 'HORA';

  @override
  String get deviceMgmtSectionReset => 'REDEFINIR';

  @override
  String get deviceMgmtSectionFirmware => 'FIRMWARE';

  @override
  String get deviceMgmtRebootTitle => 'Reiniciar dispositivo';

  @override
  String get deviceMgmtRebootSubtitle => 'Reiniciar o dispositivo';

  @override
  String get deviceMgmtRebootWarning =>
      'O dispositivo será reiniciado em 2 segundos. Você será brevemente desconectado durante a reinicialização.';

  @override
  String get deviceMgmtShutdownTitle => 'Desligar dispositivo';

  @override
  String get deviceMgmtShutdownSubtitle => 'Desligar o dispositivo';

  @override
  String get deviceMgmtShutdownWarning =>
      'O dispositivo será desligado em 2 segundos. Você precisará ligá-lo manualmente.';

  @override
  String get deviceMgmtSyncTimeTitle => 'Sincronizar hora';

  @override
  String get deviceMgmtSyncTimeSubtitle =>
      'Definir a hora do dispositivo para a hora atual';

  @override
  String get deviceMgmtResetNodeDbTitle => 'Redefinir banco de dados de nós';

  @override
  String get deviceMgmtResetNodeDbSubtitle =>
      'Limpar todos os nós conhecidos do dispositivo e do app';

  @override
  String get deviceMgmtResetNodeDbWarning =>
      'Isso limpará todos os nós descobertos do dispositivo e do app. Os nós serão redescobertos com o tempo.';

  @override
  String get deviceMgmtFactoryResetConfigTitle => 'Redefinir configuração';

  @override
  String get deviceMgmtFactoryResetConfigSubtitle =>
      'Redefinir tudo exceto o banco de dados de nós';

  @override
  String get deviceMgmtFactoryResetConfigWarning =>
      'Isso apagará canais, região e todas as configurações, mas preservará o banco de dados de nós.\n\nO dispositivo será reiniciado em 5 segundos. Você precisará configurar a região novamente.';

  @override
  String get deviceMgmtFullFactoryResetTitle => 'Redefinição completa';

  @override
  String get deviceMgmtFullFactoryResetSubtitle =>
      'Apagar tudo e redefinir o dispositivo';

  @override
  String get deviceMgmtFullFactoryResetWarning =>
      'ATENÇÃO: Isso apagará completamente o dispositivo, incluindo:\n· Toda a configuração\n· Todos os canais\n· Todos os nós conhecidos\n· Identidade do dispositivo\n\nO dispositivo será reiniciado em 5 segundos. Você precisará emparelhar e configurá-lo novamente.';

  @override
  String get deviceMgmtEnterDfuTitle => 'Entrar no modo DFU';

  @override
  String get deviceMgmtEnterDfuSubtitle =>
      'Iniciar no modo de atualização de firmware';

  @override
  String get deviceMgmtEnterDfuWarning =>
      'O dispositivo entrará no modo DFU (Device Firmware Update). Você precisará usar uma ferramenta de atualização de firmware para instalar um novo firmware ou redefinir o dispositivo.\n\nVocê será desconectado do dispositivo.';

  @override
  String get displayConfigTitle => 'Configuração do display';

  @override
  String get displayConfigSave => 'Salvar';

  @override
  String get displayConfigSectionScreen => 'TELA';

  @override
  String get displayConfigSectionTimeCompass => 'HORA E BÚSSOLA';

  @override
  String get displayConfigSectionOledType => 'TIPO DE TELA OLED';

  @override
  String get displayConfigSectionUnitsFormat => 'UNIDADES E FORMATO';

  @override
  String get displayConfigSectionDisplayMode => 'MODO DE EXIBIÇÃO';

  @override
  String get displayConfigScreenTimeoutAlwaysOn => 'Sempre ligada';

  @override
  String displayConfigScreenTimeoutSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String displayConfigScreenTimeoutLabel(String value) {
    return 'Tempo limite da tela: $value';
  }

  @override
  String get displayConfigScreenTimeoutDesc => 'Tempo antes da tela desligar';

  @override
  String get displayConfigAutoCarouselDisabled => 'Desabilitado';

  @override
  String get displayConfigAutoCarouselOff => 'Desligado';

  @override
  String displayConfigAutoCarouselLabel(String value) {
    return 'Carrossel automático: $value';
  }

  @override
  String get displayConfigAutoCarouselDesc =>
      'Alterna automaticamente entre as telas';

  @override
  String get displayConfigFlipScreen => 'Inverter tela';

  @override
  String get displayConfigFlipScreenSubtitle => 'Girar o display em 180°';

  @override
  String get displayConfigWakeOnTap => 'Despertar ao toque/movimento';

  @override
  String get displayConfigWakeOnTapSubtitle =>
      'Ligar a tela quando o dispositivo é movido';

  @override
  String get displayConfigLongNodeNames => 'Nomes longos de nós';

  @override
  String get displayConfigLongNodeNamesSubtitle =>
      'Mostrar nomes completos dos nós na tela do dispositivo';

  @override
  String get displayConfigMessageBubbles => 'Balões de mensagem';

  @override
  String get displayConfigMessageBubblesSubtitle =>
      'Exibir mensagens em formato de balão na tela';

  @override
  String get displayConfig12hClock => 'Relógio 12 horas';

  @override
  String get displayConfig12hClockSubtitle =>
      'Exibir hora no formato 12 horas (AM/PM)';

  @override
  String get displayConfigCompassNorth => 'Bússola sempre aponta norte';

  @override
  String get displayConfigCompassNorthSubtitle =>
      'A direção da bússola fora do círculo sempre aponta para o norte';

  @override
  String get displayConfigCompassOrientation => 'Orientação da bússola';

  @override
  String get displayConfigCompassOrientationDesc =>
      'Ajustar a rotação do display da bússola';

  @override
  String get displayConfigDeg0 => '0°';

  @override
  String get displayConfigDeg90 => '90°';

  @override
  String get displayConfigDeg180 => '180°';

  @override
  String get displayConfigDeg270 => '270°';

  @override
  String get displayConfigDeg0Inv => '0° Invertido';

  @override
  String get displayConfigDeg90Inv => '90° Invertido';

  @override
  String get displayConfigDeg180Inv => '180° Invertido';

  @override
  String get displayConfigDeg270Inv => '270° Invertido';

  @override
  String get displayConfigOledTypeTitle => 'Tipo OLED';

  @override
  String get displayConfigOledTypeDesc =>
      'Substituir detecção automática de OLED';

  @override
  String get displayConfigOledAuto => 'Auto';

  @override
  String get displayConfigOledAutoDesc =>
      'Detectar automaticamente o tipo de OLED';

  @override
  String get displayConfigOledSsd1306Desc => 'OLED 128x64 comum';

  @override
  String get displayConfigOledSh1106Desc => 'Controlador OLED 132x64';

  @override
  String get displayConfigOledSh1107Desc => 'OLED vertical 64x128';

  @override
  String get displayConfigOledSh1107_128Desc => 'OLED quadrado 128x128';

  @override
  String get displayConfigMeasurementUnits => 'Unidades de medida';

  @override
  String get displayConfigMetric => 'Métrico';

  @override
  String get displayConfigMetricDesc => 'Quilômetros, Celsius';

  @override
  String get displayConfigImperial => 'Imperial';

  @override
  String get displayConfigImperialDesc => 'Milhas, Fahrenheit';

  @override
  String get displayConfigBoldHeadings => 'Títulos em negrito';

  @override
  String get displayConfigBoldHeadingsSubtitle =>
      'Mostrar títulos da bússola em negrito';

  @override
  String get displayConfigDisplayModeTitle => 'Modo de exibição';

  @override
  String get displayConfigDisplayModeDesc =>
      'Escolha o modo de renderização do display';

  @override
  String get displayConfigModeDefault => 'Padrão';

  @override
  String get displayConfigModeDefaultDesc => 'Layout de exibição padrão';

  @override
  String get displayConfigModeTwoColor => 'Duas cores';

  @override
  String get displayConfigModeTwoColorDesc =>
      'Otimizado para displays de duas cores';

  @override
  String get displayConfigModeInverted => 'Invertido';

  @override
  String get displayConfigModeInvertedDesc => 'Fundo escuro, texto claro';

  @override
  String get displayConfigModeColor => 'Colorido';

  @override
  String get displayConfigModeColorDesc => 'Modo de exibição colorido';

  @override
  String get displayConfigSaved => 'Configuração de display salva';

  @override
  String displayConfigSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get extNotifTitle => 'Notificação externa';

  @override
  String get extNotifSave => 'Salvar';

  @override
  String get extNotifNotConnected =>
      'Conecte um dispositivo para configurar as notificações externas';

  @override
  String get extNotifSectionOptions => 'Opções';

  @override
  String get extNotifSectionPrimaryGpio => 'GPIO primário';

  @override
  String get extNotifSectionOptionalGpio => 'GPIO opcional';

  @override
  String get extNotifEnabled => 'Ativado';

  @override
  String get extNotifEnabledSubtitle => 'Ativar módulo de notificação externa';

  @override
  String get extNotifAlertOnBell => 'Alerta no campainha';

  @override
  String get extNotifAlertOnBellSubtitle =>
      'Disparar notificação ao receber um caractere de campainha';

  @override
  String get extNotifAlertOnMessage => 'Alerta na mensagem';

  @override
  String get extNotifAlertOnMessageSubtitle =>
      'Disparar notificação ao receber uma mensagem';

  @override
  String get extNotifUsePwm => 'Usar buzzer PWM';

  @override
  String get extNotifUsePwmSubtitle =>
      'Usar saída PWM para melodias em vez de on/off';

  @override
  String get extNotifUseI2s => 'Usar I2S como buzzer';

  @override
  String get extNotifUseI2sSubtitle =>
      'Usar saída de áudio I2S para melodias RTTTL (T-Watch, T-Deck)';

  @override
  String get extNotifActiveHigh => 'Ativo alto';

  @override
  String get extNotifActiveHighSubtitle =>
      'O pino de saída fica alto quando ativo';

  @override
  String get extNotifOutputGpioPin => 'Pino GPIO de saída';

  @override
  String get extNotifGpioUnset => 'Não definido';

  @override
  String extNotifGpioValue(int value) {
    return 'GPIO $value';
  }

  @override
  String extNotifGpioPinLabel(int pin) {
    return 'Pino $pin';
  }

  @override
  String get extNotifOutputDuration => 'Duração da saída';

  @override
  String get extNotifOutputDurationSubtitle => 'Tempo de ativação da saída';

  @override
  String get extNotifDurationDefault => 'Padrão';

  @override
  String get extNotifDuration100ms => '100ms';

  @override
  String get extNotifDuration250ms => '250ms';

  @override
  String get extNotifDuration500ms => '500ms';

  @override
  String get extNotifDuration1s => '1 segundo';

  @override
  String get extNotifDuration2s => '2 segundos';

  @override
  String get extNotifDuration5s => '5 segundos';

  @override
  String get extNotifNagTimeout => 'Tempo de repetição';

  @override
  String get extNotifNagTimeoutSubtitle =>
      'Frequência de repetição da notificação';

  @override
  String get extNotifTimeoutDisabled => 'Desativado';

  @override
  String get extNotifTimeout15s => '15 segundos';

  @override
  String get extNotifTimeout30s => '30 segundos';

  @override
  String get extNotifTimeout1m => '1 minuto';

  @override
  String get extNotifTimeout2m => '2 minutos';

  @override
  String get extNotifTimeout5m => '5 minutos';

  @override
  String get extNotifTimeout10m => '10 minutos';

  @override
  String get extNotifBuzzerOnBell => 'Buzzer na campainha';

  @override
  String get extNotifBuzzerOnBellSubtitle =>
      'Ativar buzzer GPIO ao receber uma campainha';

  @override
  String get extNotifVibraOnBell => 'Vibração na campainha';

  @override
  String get extNotifVibraOnBellSubtitle =>
      'Ativar motor de vibração ao receber uma campainha';

  @override
  String get extNotifBuzzerOnMsg => 'Buzzer na mensagem';

  @override
  String get extNotifBuzzerOnMsgSubtitle =>
      'Ativar buzzer GPIO ao receber uma mensagem';

  @override
  String get extNotifVibraOnMsg => 'Vibração na mensagem';

  @override
  String get extNotifVibraOnMsgSubtitle =>
      'Ativar motor de vibração ao receber uma mensagem';

  @override
  String get extNotifBuzzerGpioPin => 'Pino GPIO do buzzer';

  @override
  String get extNotifVibraGpioPin => 'Pino GPIO de vibração';

  @override
  String get extNotifSaved => 'Configurações de notificação externa salvas';

  @override
  String extNotifSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get extNotifLoadFailed => 'Falha ao carregar configuração';

  @override
  String get iftttConfigTitle => 'Integração IFTTT';

  @override
  String get iftttConfigSave => 'Salvar';

  @override
  String get iftttConfigPremiumTitle => 'Conecte a mais de 700 serviços';

  @override
  String get iftttConfigPremiumDesc =>
      'Acione dispositivos smart home, registre eventos em planilhas, envie mensagens no Discord/Slack e mais.';

  @override
  String get iftttConfigPremiumExampleTitle => 'Nó fica offline';

  @override
  String get iftttConfigPremiumExampleDesc =>
      'Acenda automaticamente uma luz smart ou envie uma notificação quando seu nó não for mais detectado.';

  @override
  String get iftttConfigSectionWebhook => 'WEBHOOK';

  @override
  String get iftttConfigSectionMessageTriggers => 'GATILHOS DE MENSAGEM';

  @override
  String get iftttConfigSectionNodeTriggers => 'GATILHOS DE STATUS DO NÓ';

  @override
  String get iftttConfigSectionTelemetryTriggers => 'GATILHOS DE TELEMETRIA';

  @override
  String get iftttConfigSectionGeofencing => 'GEOLIMITAÇÃO';

  @override
  String get iftttConfigEnable => 'Ativar IFTTT';

  @override
  String get iftttConfigEnableSubtitle =>
      'Enviar eventos para o serviço IFTTT Webhooks';

  @override
  String get iftttConfigDataSharingTitle => 'Compartilhamento de dados IFTTT';

  @override
  String get iftttConfigDataSharingMsg =>
      'Quando os Webhooks IFTTT estão ativados, dados de eventos mesh (mensagens, status de nós, posições, níveis de bateria) serão enviados aos servidores IFTTT através da sua chave webhook pessoal.\n\nO IFTTT é um serviço de terceiros com sua própria política de privacidade. Apenas os tipos de evento selecionados serão transmitidos.';

  @override
  String get iftttConfigIUnderstand => 'Entendi';

  @override
  String get iftttConfigWebhookKeyLabel => 'Chave Webhook';

  @override
  String get iftttConfigWebhookKeyHint => 'ex. cMcOnB_zaJTrZwsVvzVTHY';

  @override
  String get iftttConfigWebhookKeyHelper =>
      'Copie da URL dos Webhooks IFTTT após /use/';

  @override
  String get iftttConfigTesting => 'Testando...';

  @override
  String get iftttConfigTestConnection => 'Testar conexão';

  @override
  String get iftttConfigEnterKeyToEnable =>
      'Insira sua chave Webhook para ativar o IFTTT';

  @override
  String get iftttConfigEnterKeyFirst => 'Insira sua chave Webhook primeiro';

  @override
  String get iftttConfigTestSuccess =>
      'Webhook de teste enviado! Verifique seu applet IFTTT.';

  @override
  String get iftttConfigTestFailed =>
      'Falha ao enviar webhook de teste. Verifique sua chave.';

  @override
  String get iftttConfigMessageReceived => 'Mensagem recebida';

  @override
  String get iftttConfigMessageReceivedSubtitle =>
      'Disparar ao receber uma mensagem';

  @override
  String get iftttConfigSosEmergency => 'SOS / Emergência';

  @override
  String get iftttConfigSosEmergencySubtitle =>
      'Disparar com palavras-chave SOS, emergência, ajuda, mayday';

  @override
  String get iftttConfigNodeActive => 'Nó ativo';

  @override
  String get iftttConfigNodeActiveSubtitle =>
      'Disparar quando um nó foi detectado recentemente';

  @override
  String get iftttConfigNodeInactive => 'Nó inativo';

  @override
  String get iftttConfigNodeInactiveSubtitle =>
      'Disparar quando um nó não é detectado há algum tempo';

  @override
  String get iftttConfigBatteryLow => 'Bateria fraca';

  @override
  String get iftttConfigBatteryLowSubtitle =>
      'Disparar quando a bateria cai abaixo do limite';

  @override
  String get iftttConfigBatteryThreshold => 'Limite de bateria';

  @override
  String get iftttConfigTemperatureAlert => 'Alerta de temperatura';

  @override
  String get iftttConfigTemperatureAlertSubtitle =>
      'Disparar quando a temperatura excede o limite';

  @override
  String get iftttConfigTemperatureThreshold => 'Limite de temperatura';

  @override
  String get iftttConfigPositionUpdates => 'Atualizações de posição';

  @override
  String get iftttConfigPositionUpdatesSubtitle =>
      'Disparar quando o nó sai da área de geofence';

  @override
  String get iftttConfigGeofenceRadius => 'Raio do geofence';

  @override
  String get iftttConfigGeofenceRadiusHint => '1000';

  @override
  String get iftttConfigGeofenceUnitM => 'm';

  @override
  String get iftttConfigCenterLatitude => 'Latitude central';

  @override
  String get iftttConfigCenterLatHint => '-33.8688';

  @override
  String get iftttConfigCenterLongitude => 'Longitude central';

  @override
  String get iftttConfigCenterLonHint => '151.2093';

  @override
  String get iftttConfigMonitoredNode => 'Nó monitorado';

  @override
  String get iftttConfigNoNodeSelected =>
      'Nenhum nó selecionado. Todos os nós serão monitorados.';

  @override
  String get iftttConfigAlertCooldown => 'Intervalo de alertas';

  @override
  String get iftttConfigCooldown5min => '5 min';

  @override
  String get iftttConfigCooldown15min => '15 min';

  @override
  String get iftttConfigCooldown30min => '30 min';

  @override
  String get iftttConfigCooldown1hour => '1 hora';

  @override
  String get iftttConfigCooldown2hours => '2 horas';

  @override
  String get iftttConfigCooldown4hours => '4 horas';

  @override
  String get iftttConfigCooldown8hours => '8 horas';

  @override
  String get iftttConfigCooldown24hours => '24 horas';

  @override
  String get iftttConfigCooldownDesc =>
      'Tempo mínimo entre alertas de geofence para o mesmo nó';

  @override
  String get iftttConfigPickOnMap => 'Escolher no mapa';

  @override
  String get iftttConfigSetupGuide => 'Guia de configuração';

  @override
  String get iftttConfigStep1 => 'Crie uma conta em ifttt.com';

  @override
  String get iftttConfigStep2 => 'Procure o serviço \"Webhooks\" e conecte-o';

  @override
  String get iftttConfigStep3 =>
      'Acesse as configurações dos Webhooks para encontrar sua chave';

  @override
  String get iftttConfigStep4 => 'Crie applets com Webhooks como gatilho';

  @override
  String get iftttConfigEventNamesRef => 'Referência de nomes de evento';

  @override
  String get iftttConfigEventNamesSubtitle =>
      'Use estes nomes nos seus applets IFTTT';

  @override
  String get iftttConfigSaved => 'Configurações IFTTT salvas';

  @override
  String get iftttConfigSaveFailed => 'Falha ao salvar configurações IFTTT';

  @override
  String get webhookModeIfttt => 'Chave IFTTT';

  @override
  String get webhookModeCustomUrl => 'URL Personalizado';

  @override
  String get webhookConfigCustomUrlLabel => 'URL do Webhook';

  @override
  String get webhookConfigCustomUrlHint =>
      'http://192.168.1.100:8123/api/webhook/...';

  @override
  String get webhookConfigCustomUrlHelper =>
      'Enviar JSON via POST para qualquer endpoint HTTP/HTTPS. Endereços LAN suportados.';

  @override
  String get webhookConfigEnterUrlToEnable =>
      'Introduza um URL de webhook para ativar';

  @override
  String get webhookConfigEnterUrlFirst =>
      'Introduza primeiro um URL de webhook';

  @override
  String get mqttConfigTitle => 'MQTT';

  @override
  String get mqttConfigSave => 'Salvar';

  @override
  String mqttConfigDutyCycleWarning(String percent) {
    return 'Sua região tem um duty cycle de $percent%. MQTT não é recomendado com restrições de duty cycle — o tráfego extra sobrecarregará rapidamente sua rede LoRa.';
  }

  @override
  String get mqttConfigEnable => 'Ativar MQTT';

  @override
  String get mqttConfigEnableSubtitle =>
      'Conectar dispositivo a um broker MQTT para bridging mesh';

  @override
  String get mqttConfigNoWifiAdvisory =>
      'Este dispositivo não possui hardware WiFi. Ative o Proxy Client MQTT abaixo para que o app encaminhe mensagens em nome do dispositivo.';

  @override
  String get mqttConfigNoWifiTitle => 'Sem hardware WiFi';

  @override
  String get mqttConfigNoWifiMsg =>
      'Este dispositivo não possui hardware WiFi. Sem o Proxy Client MQTT ativado, o dispositivo não consegue acessar um broker MQTT por conta própria.\n\nSalvar mesmo assim sem proxy?';

  @override
  String get mqttConfigSaveAnyway => 'Salvar mesmo assim';

  @override
  String get mqttConfigSectionServer => 'SERVIDOR';

  @override
  String get mqttConfigSectionAuth => 'AUTENTICAÇÃO';

  @override
  String get mqttConfigSectionOptions => 'OPÇÕES';

  @override
  String get mqttConfigServerAddressLabel => 'Endereço do servidor';

  @override
  String get mqttConfigServerAddressHint => 'mqtt.meshtastic.org';

  @override
  String get mqttConfigTopicRootLabel => 'Tópico raiz';

  @override
  String get mqttConfigTopicRootHint => 'msh';

  @override
  String get mqttConfigUseTls => 'Usar TLS';

  @override
  String get mqttConfigUseTlsSubtitle => 'Criptografar conexão com o broker';

  @override
  String get mqttConfigUsernameLabel => 'Nome de usuário';

  @override
  String get mqttConfigOptionalHint => 'Opcional';

  @override
  String get mqttConfigPasswordLabel => 'Senha';

  @override
  String get mqttConfigEncryption => 'Criptografia';

  @override
  String get mqttConfigEncryptionSubtitle =>
      'Criptografar mensagens mesh via MQTT';

  @override
  String get mqttConfigJsonOutput => 'Saída JSON';

  @override
  String get mqttConfigJsonOutputSubtitle =>
      'Publicar mensagens em formato JSON';

  @override
  String get mqttConfigClientProxy => 'Proxy Client MQTT';

  @override
  String get mqttConfigClientProxySubtitle =>
      'Usar rede do celular para MQTT\n(Necessário para dispositivos sem WiFi)';

  @override
  String get mqttConfigMapReporting => 'Relatório de mapa';

  @override
  String get mqttConfigMapReportingSubtitle =>
      'Reportar posição no mapa mesh público';

  @override
  String get mqttConfigMapReportSettingsHeader =>
      'CONFIGURAÇÕES DE RELATÓRIO DE MAPA';

  @override
  String mqttConfigPublishInterval(int minutes) {
    return 'Intervalo de publicação: $minutes minutos';
  }

  @override
  String get mqttConfigPublishIntervalDesc =>
      'Frequência de envio da posição para o mapa';

  @override
  String get mqttConfigPositionPrecision => 'Precisão da posição';

  @override
  String get mqttConfigPositionPrecisionDesc =>
      'Precisão aproximada da localização no mapa';

  @override
  String get mqttConfigPrecisionWithin5_8km => 'Até 5,8 km';

  @override
  String get mqttConfigPrecisionWithin2_9km => 'Até 2,9 km';

  @override
  String get mqttConfigPrecisionWithin1_5km => 'Até 1,5 km';

  @override
  String get mqttConfigPrecisionWithin700m => 'Até 700 m';

  @override
  String get mqttConfigPrecisionUnknown => 'Desconhecida';

  @override
  String get mqttConfigInfoText =>
      'MQTT permite que seu dispositivo conecte a rede mesh local à internet. Isso possibilita a comunicação com nós fora do alcance direto do rádio.';

  @override
  String get mqttConfigSaved => 'Configuração MQTT salva';

  @override
  String mqttConfigSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get mqttProxySectionDiagnostics => 'CLIENT PROXY STATUS';

  @override
  String get mqttProxyStatusLabel => 'Status';

  @override
  String get mqttProxyStatusConnected => 'Connected';

  @override
  String get mqttProxyStatusDisconnected => 'Disconnected';

  @override
  String get mqttProxyBroker => 'Broker';

  @override
  String get mqttProxyTls => 'TLS';

  @override
  String get mqttProxyAuth => 'Auth';

  @override
  String get mqttProxyTopic => 'Topic';

  @override
  String get mqttProxyPublished => 'Published';

  @override
  String get mqttProxyRelayed => 'Relayed';

  @override
  String get mqttProxyLastError => 'Last Error';

  @override
  String get mqttProxyReconnects => 'Reconnects';

  @override
  String get mqttProxyEnabled => 'Enabled';

  @override
  String get mqttProxyDisabled => 'Disabled';

  @override
  String get mqttProxyConfigured => 'Configured';

  @override
  String get mqttProxyNone => 'None';

  @override
  String get mqttProxyNoneLabel => '–';

  @override
  String get mqttProxyLastConnectAttempt => 'Last Attempt';

  @override
  String get mqttProxyLastConnectedAt => 'Last Connected';

  @override
  String get mqttProxyCopyDiagnostics => 'Copy Diagnostics';

  @override
  String get mqttProxyDiagnosticsCopied => 'Diagnostics copied to clipboard';

  @override
  String get securityConfigTitle => 'Segurança';

  @override
  String get securityConfigSave => 'Salvar';

  @override
  String get securityConfigSectionDmKey => 'CHAVE DE MENSAGEM DIRETA';

  @override
  String get securityConfigSectionAdminKeys => 'CHAVES DE ADMIN';

  @override
  String get securityConfigSectionDeviceMgmt => 'GERENCIAMENTO DO DISPOSITIVO';

  @override
  String get securityConfigSectionAccessControls => 'CONTROLES DE ACESSO';

  @override
  String get securityConfigPublicKey => 'Chave pública';

  @override
  String get securityConfigNoKeySet => 'Nenhuma chave definida';

  @override
  String get securityConfigPublicKeyDesc =>
      'Sua chave pública é enviada a outros nós para mensagens seguras';

  @override
  String get securityConfigPrivateKey => 'Chave privada';

  @override
  String get securityConfigPrivateKeyHint =>
      'Chave de 32 bytes codificada em Base64';

  @override
  String get securityConfigPrivateKeyDesc =>
      'Usada para calcular o segredo compartilhado com dispositivos remotos';

  @override
  String get securityConfigRegenKeyPair => 'Regenerar par de chaves';

  @override
  String get securityConfigGenerating => 'Gerando...';

  @override
  String get securityConfigGenerate => 'Gerar';

  @override
  String get securityConfigRegenDesc =>
      'Gerar um novo par de chaves (a chave pública será derivada automaticamente)';

  @override
  String get securityConfigKeyBackup => 'Backup da chave';

  @override
  String get securityConfigBackupDesc =>
      'Faça backup da chave privada em armazenamento seguro para recuperação. As chaves são salvas no keychain do dispositivo com sincronização iCloud.';

  @override
  String get securityConfigBackupBtn => 'Backup';

  @override
  String get securityConfigRestoreBtn => 'Restaurar';

  @override
  String get securityConfigDeleteBackupTooltip => 'Excluir backup';

  @override
  String get securityConfigAdminKeysDesc =>
      'Chaves públicas autorizadas a enviar mensagens admin para este nó';

  @override
  String get securityConfigPrimaryAdminKey => 'Chave admin primária';

  @override
  String get securityConfigSecondaryAdminKey => 'Chave admin secundária';

  @override
  String get securityConfigTertiaryAdminKey => 'Chave admin terciária';

  @override
  String get securityConfigAdminKeyHint => 'Chave pública codificada em Base64';

  @override
  String get securityConfigManagedMode => 'Modo gerenciado';

  @override
  String get securityConfigManagedModeSubtitle =>
      'Dispositivo é gerenciado por um sistema externo';

  @override
  String get securityConfigSerialConsole => 'Console serial';

  @override
  String get securityConfigSerialConsoleSubtitle =>
      'Ativar acesso ao console serial USB';

  @override
  String get securityConfigDebugLogging => 'Log de depuração';

  @override
  String get securityConfigDebugLoggingSubtitle =>
      'Ativar saída detalhada de log de depuração';

  @override
  String get securityConfigAdminChannel => 'Canal admin';

  @override
  String get securityConfigAdminChannelSubtitle =>
      'Permitir administração remota via canal admin';

  @override
  String get securityConfigWarning =>
      'Desabilitar o console serial ou ativar o modo gerenciado pode dificultar a recuperação do dispositivo. Certifique-se de entender as implicações antes de fazer alterações.';

  @override
  String get securityConfigDeleteBackupTitle => 'Excluir backup?';

  @override
  String get securityConfigDeleteBackupMsg =>
      'A chave privada salva será excluída permanentemente do armazenamento seguro. Esta ação não pode ser desfeita.';

  @override
  String get securityConfigDeleteBtn => 'Excluir';

  @override
  String get securityConfigNewKeyPairGenerated => 'Novo par de chaves gerado';

  @override
  String securityConfigKeyGenFailed(String error) {
    return 'Falha ao gerar chave: $error';
  }

  @override
  String get securityConfigSaved => 'Configuração de segurança salva';

  @override
  String securityConfigSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get securityConfigInvalidPrivateKey =>
      'Formato de chave privada inválido';

  @override
  String get securityConfigInvalidAdminKey => 'Formato de chave admin inválido';

  @override
  String get securityConfigNoDevice => 'Nenhum dispositivo conectado';

  @override
  String get securityConfigBackedUp =>
      'Chave privada salva no armazenamento seguro';

  @override
  String securityConfigBackupFailed(String error) {
    return 'Falha ao fazer backup da chave: $error';
  }

  @override
  String get securityConfigNoBackupFound =>
      'Nenhum backup encontrado para este dispositivo';

  @override
  String get securityConfigRestored => 'Chave privada restaurada do backup';

  @override
  String securityConfigRestoreFailed(String error) {
    return 'Falha ao restaurar chave: $error';
  }

  @override
  String get securityConfigBackupDeleted => 'Backup excluído';

  @override
  String securityConfigDeleteBackupFailed(String error) {
    return 'Falha ao excluir backup: $error';
  }

  @override
  String get trafficMgmtTitle => 'Gerenciamento de tráfego';

  @override
  String get trafficMgmtSave => 'Salvar';

  @override
  String get trafficMgmtSectionGeneral => 'GERAL';

  @override
  String get trafficMgmtSectionPositionDedup => 'DEDUPLICAÇÃO DE POSIÇÃO';

  @override
  String get trafficMgmtSectionNodeinfoResponse => 'RESPOSTA DIRETA NODEINFO';

  @override
  String get trafficMgmtSectionRateLimit => 'LIMITAÇÃO DE TAXA';

  @override
  String get trafficMgmtSectionUnknownPackets => 'PACOTES DESCONHECIDOS';

  @override
  String get trafficMgmtSectionHopMgmt => 'GERENCIAMENTO DE HOP';

  @override
  String get trafficMgmtEnable => 'Ativar gerenciamento de tráfego';

  @override
  String get trafficMgmtEnableSubtitle =>
      'Controle principal para todas as funções de gerenciamento de tráfego';

  @override
  String get trafficMgmtPositionDedup => 'Deduplicação de posição';

  @override
  String get trafficMgmtPositionDedupSubtitle =>
      'Descartar pacotes de posição duplicados';

  @override
  String trafficMgmtPrecisionBits(int value) {
    return 'Bits de precisão: $value';
  }

  @override
  String get trafficMgmtPrecisionBitsDesc =>
      'Valores mais baixos significam deduplicação mais agressiva';

  @override
  String trafficMgmtPrecisionBitsLabel(int value) {
    return '$value bits';
  }

  @override
  String trafficMgmtMinInterval(int seconds) {
    return 'Intervalo mín: ${seconds}s';
  }

  @override
  String get trafficMgmtMinIntervalDesc =>
      'Segundos mínimos entre atualizações de posição';

  @override
  String get trafficMgmtDirectResponse => 'Resposta direta';

  @override
  String get trafficMgmtDirectResponseSubtitle =>
      'Responder diretamente às solicitações NodeInfo';

  @override
  String trafficMgmtMaxHops(int value) {
    return 'Hops máx: $value';
  }

  @override
  String get trafficMgmtMaxHopsDesc =>
      'Hops máximos para resposta direta NodeInfo';

  @override
  String get trafficMgmtPerNodeRateLimit => 'Limitação de taxa por nó';

  @override
  String get trafficMgmtPerNodeRateLimitSubtitle =>
      'Limitar a taxa de pacotes de nós individuais';

  @override
  String trafficMgmtWindow(int seconds) {
    return 'Janela: ${seconds}s';
  }

  @override
  String get trafficMgmtWindowDesc =>
      'Janela de tempo para cálculo do limite de taxa';

  @override
  String trafficMgmtMaxPackets(int value) {
    return 'Pacotes máx: $value';
  }

  @override
  String get trafficMgmtMaxPacketsDesc =>
      'Pacotes máximos por janela antes do descarte';

  @override
  String get trafficMgmtDropUnknown => 'Descartar pacotes desconhecidos';

  @override
  String get trafficMgmtDropUnknownSubtitle =>
      'Descartar pacotes de fontes desconhecidas';

  @override
  String trafficMgmtThreshold(int value) {
    return 'Limite: $value';
  }

  @override
  String get trafficMgmtThresholdDesc =>
      'Número de pacotes desconhecidos antes do descarte';

  @override
  String get trafficMgmtExhaustHopTelemetry => 'Esgotar hop em telemetria';

  @override
  String get trafficMgmtExhaustHopTelemetrySub =>
      'Definir limite de hop como 0 para telemetria retransmitida';

  @override
  String get trafficMgmtExhaustHopPosition => 'Esgotar hop em posição';

  @override
  String get trafficMgmtExhaustHopPositionSub =>
      'Definir limite de hop como 0 para posições retransmitidas';

  @override
  String get trafficMgmtPreserveRouterHops => 'Preservar hops do roteador';

  @override
  String get trafficMgmtPreserveRouterHopsSub =>
      'Preservar a contagem de hops para nós roteadores';

  @override
  String get trafficMgmtSaved =>
      'Configuração de gerenciamento de tráfego salva';

  @override
  String trafficMgmtSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get adminPanelTitle => 'Admin';

  @override
  String get adminPanelSectionShop => 'GERENCIAMENTO DA LOJA';

  @override
  String get adminPanelShopDashboard => 'Painel admin da loja';

  @override
  String get adminPanelShopDashboardSub =>
      'Gerenciar produtos, pedidos e inventário';

  @override
  String get adminPanelDeviceShop => 'Loja de dispositivos';

  @override
  String get adminPanelDeviceShopSub =>
      'Visualizar e gerenciar listagens de dispositivos';

  @override
  String get adminPanelSectionModeration => 'MODERAÇÃO DE CONTEÚDO';

  @override
  String get adminPanelBugReports => 'Relatórios de bugs';

  @override
  String get adminPanelBugReportsSub =>
      'Visualizar e responder aos relatórios de bugs dos usuários';

  @override
  String get adminPanelReviewMod => 'Moderação de avaliações';

  @override
  String get adminPanelReviewModSub =>
      'Aprovar ou rejeitar avaliações dos usuários';

  @override
  String get adminPanelReportedContent => 'Conteúdo denunciado';

  @override
  String get adminPanelReportedContentSub =>
      'Analisar publicações e comentários denunciados';

  @override
  String get adminPanelWidgetReview => 'Revisão do marketplace de widgets';

  @override
  String get adminPanelWidgetReviewSub => 'Aprovar envios de widgets pendentes';

  @override
  String get adminPanelSectionUsers => 'GERENCIAMENTO DE USUÁRIOS';

  @override
  String get adminPanelSocialSeeding => 'Social seeding';

  @override
  String get adminPanelSocialSeedingSub =>
      'Gerenciar solicitações de follow e conexões';

  @override
  String get adminPanelUserPurchases => 'Compras dos usuários';

  @override
  String get adminPanelUserPurchasesSub =>
      'Visualizar e gerenciar transações dos usuários';

  @override
  String get adminPanelSectionConfig => 'CONFIGURAÇÃO DO APP';

  @override
  String get adminPanelBroadcast => 'Notificação broadcast';

  @override
  String get adminPanelBroadcastSub =>
      'Enviar notificação push para todos os usuários';

  @override
  String get adminPanelQrStyles => 'Estilos de código QR';

  @override
  String get adminPanelQrStylesSub =>
      'Pré-visualizar designs de código QR personalizados';

  @override
  String get adminPanelSectionDiag => 'DIAGNÓSTICO DO DISPOSITIVO';

  @override
  String get adminPanelDiagHarness => 'Ferramenta de diagnóstico';

  @override
  String get adminPanelDiagHarnessSub =>
      'Executar sondas de protocolo e exportar pacote de debug';

  @override
  String get adminPanelConformance => 'Teste de conformidade';

  @override
  String get adminPanelConformanceSub =>
      'Testes de conformidade e stress do dispositivo vinculados ao provider';

  @override
  String get adminPanelStorageHealth => 'Saúde do Armazenamento';

  @override
  String get adminPanelStorageHealthSub =>
      'Verificar se o modo WAL está ativo em todos os bancos de dados SQLite';

  @override
  String get adminStorageHealthTitle => 'Saúde do Armazenamento';

  @override
  String get adminStorageHealthRefresh => 'Atualizar';

  @override
  String get adminStorageHealthChecking => 'A verificar bancos de dados…';

  @override
  String get adminStorageHealthAllPass =>
      'Todos os bancos de dados em modo WAL';

  @override
  String get adminStorageHealthSomeFail =>
      'Alguns bancos de dados não estão em modo WAL';

  @override
  String adminStorageHealthSummary(int pass, int fail, int total) {
    return '$pass aprovados · $fail falhados · $total total';
  }

  @override
  String get adminStorageStatusWal => 'WAL';

  @override
  String get adminStorageStatusUnknown => 'DESCONHECIDO';

  @override
  String get adminStorageStatusMissing => 'NÃO ABERTO';

  @override
  String get adminStorageStatusError => 'ERRO';

  @override
  String get adminStorageWalPresent => '-wal presente';

  @override
  String get adminStorageWalAbsent => '-wal ausente';

  @override
  String get adminStorageShmPresent => '-shm presente';

  @override
  String get adminStorageShmAbsent => '-shm ausente';

  @override
  String get adminStoragePathCopied =>
      'Caminho copiado para a área de transferência';

  @override
  String get adminPanelBadgeOverflow => '99+';

  @override
  String get adminBroadcastTitle => 'Notificação broadcast';

  @override
  String get adminBroadcastSignInRequired =>
      'Você precisa estar conectado para enviar notificações';

  @override
  String get adminBroadcastTestSentTitle => 'Teste enviado';

  @override
  String get adminBroadcastSentTitle => 'Broadcast enviado';

  @override
  String get adminBroadcastTestSentBody =>
      'Sua notificação de teste foi enviada para todos os admins.';

  @override
  String get adminBroadcastSentBody =>
      'Sua notificação foi enviada para todos os usuários Socialmesh.';

  @override
  String get adminBroadcastDone => 'Concluído';

  @override
  String adminBroadcastFailedDetailed(String code, String message) {
    return 'Falha ao enviar: $code - $message';
  }

  @override
  String adminBroadcastFailed(String error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String get adminBroadcastSelectDeepLink => 'Selecionar deep link';

  @override
  String get adminBroadcastSelectIcon => 'Selecionar ícone';

  @override
  String get adminBroadcastPreviewTitlePlaceholder => 'Título da notificação';

  @override
  String get adminBroadcastPreviewBodyPlaceholder =>
      'A mensagem da notificação aparecerá aqui...';

  @override
  String get adminBroadcastWarning =>
      'Isso enviará uma notificação push para todos os usuários Socialmesh. Use com moderação apenas para anúncios importantes.';

  @override
  String get adminBroadcastPlatformLabel => 'Plataforma alvo';

  @override
  String get adminBroadcastPlatformHelper =>
      'Escolha qual plataforma recebe esta notificação.';

  @override
  String get adminBroadcastPlatformAll => 'Todas';

  @override
  String get adminBroadcastPlatformAndroid => 'Android';

  @override
  String get adminBroadcastPlatformIos => 'iOS';

  @override
  String get adminBroadcastIconLabel => 'Ícone';

  @override
  String get adminBroadcastClear => 'Limpar';

  @override
  String get adminBroadcastFieldTitle => 'Título';

  @override
  String get adminBroadcastTitleHint => 'Título da notificação...';

  @override
  String get adminBroadcastTitleRequired => 'O título é obrigatório';

  @override
  String get adminBroadcastFieldMessage => 'Mensagem';

  @override
  String get adminBroadcastMessageHint => 'Mensagem da notificação...';

  @override
  String get adminBroadcastMessageRequired => 'A mensagem é obrigatória';

  @override
  String get adminBroadcastDeepLinkLabel => 'Deep link (opcional)';

  @override
  String get adminBroadcastDeepLinkHelper =>
      'Tela a abrir quando a notificação for tocada.';

  @override
  String get adminBroadcastDeepLinkNone => 'Nenhum';

  @override
  String get adminBroadcastSendingTest => 'Enviando teste...';

  @override
  String get adminBroadcastTestButton => 'Teste apenas para admins';

  @override
  String get adminBroadcastTestHint =>
      'Enviar uma notificação de teste para admins antes de enviar para todos os usuários.';

  @override
  String adminBroadcastCountdownCancel(int seconds) {
    return 'Cancelar — enviando em $seconds...';
  }

  @override
  String get adminBroadcastSending => 'Enviando...';

  @override
  String get adminBroadcastSendAll => 'Enviar para todos';

  @override
  String adminBroadcastSendHint(int seconds) {
    return 'Envia uma notificação push para todos os usuários Socialmesh. Uma contagem regressiva de ${seconds}s dá tempo para cancelar.';
  }

  @override
  String get adminBroadcastPreviewLabel => 'PRÉ-VISUALIZAÇÃO';

  @override
  String get adminBroadcastPreviewAppName => 'SOCIALMESH';

  @override
  String get adminBroadcastPreviewNow => 'agora';

  @override
  String get adminBroadcastIconCatGeneral => 'GERAL';

  @override
  String get adminBroadcastIconCatSocial => 'SOCIAL';

  @override
  String get adminBroadcastIconCatPremium => 'PREMIUM';

  @override
  String get adminBroadcastIconAnnouncement => 'Anúncio';

  @override
  String get adminBroadcastIconUpdate => 'Atualização do app';

  @override
  String get adminBroadcastIconFeature => 'Nova funcionalidade';

  @override
  String get adminBroadcastIconMaintenance => 'Manutenção';

  @override
  String get adminBroadcastIconAlert => 'Alerta';

  @override
  String get adminBroadcastIconCelebration => 'Celebração';

  @override
  String get adminBroadcastIconTip => 'Dica';

  @override
  String get adminBroadcastIconSignals => 'Sinais';

  @override
  String get adminBroadcastIconNodedex => 'NodeDex';

  @override
  String get adminBroadcastIconAether => 'Aether';

  @override
  String get adminBroadcastIconActivity => 'Atividade';

  @override
  String get adminBroadcastIconPresence => 'Presença';

  @override
  String get adminBroadcastIconCommunity => 'Comunidade';

  @override
  String get adminBroadcastIconWorldMap => 'Mapa mundial';

  @override
  String get adminBroadcastIconThemes => 'Pacote de temas';

  @override
  String get adminBroadcastIconRingtones => 'Pacote de toques';

  @override
  String get adminBroadcastIconWidgets => 'Widgets';

  @override
  String get adminBroadcastIconAutomations => 'Automações';

  @override
  String get adminBroadcastIconIfttt => 'Integração IFTTT';

  @override
  String get adminBroadcastDefTitleAnnouncement => 'Anúncio';

  @override
  String get adminBroadcastDefTitleUpdate => 'Atualização do app disponível';

  @override
  String get adminBroadcastDefTitleFeature => 'Nova funcionalidade';

  @override
  String get adminBroadcastDefTitleMaintenance => 'Manutenção programada';

  @override
  String get adminBroadcastDefTitleAlert => 'Alerta importante';

  @override
  String get adminBroadcastDefTitleCelebration => 'Celebração';

  @override
  String get adminBroadcastDefTitleTip => 'Dica profissional';

  @override
  String get adminBroadcastDefTitleSignals => 'Atualização Signals';

  @override
  String get adminBroadcastDefTitleNodedex => 'Atualização NodeDex';

  @override
  String get adminBroadcastDefTitleAether => 'Atualização Aether';

  @override
  String get adminBroadcastDefTitleActivity => 'Atualização de atividade';

  @override
  String get adminBroadcastDefTitlePresence => 'Atualização de presença';

  @override
  String get adminBroadcastDefTitleCommunity => 'Atualização da comunidade';

  @override
  String get adminBroadcastDefTitleWorldMap => 'Atualização do mapa mundial';

  @override
  String get adminBroadcastDefTitleThemes => 'Novo pacote de temas';

  @override
  String get adminBroadcastDefTitleRingtones => 'Novo pacote de toques';

  @override
  String get adminBroadcastDefTitleWidgets => 'Novos widgets';

  @override
  String get adminBroadcastDefTitleAutomations => 'Atualização de automações';

  @override
  String get adminBroadcastDefTitleIfttt => 'Integração IFTTT';

  @override
  String get adminBroadcastDefBodyAnnouncement =>
      'Temos um anúncio importante para a comunidade Socialmesh.';

  @override
  String get adminBroadcastDefBodyUpdate =>
      'Uma nova versão do Socialmesh está disponível com melhorias e correções.';

  @override
  String get adminBroadcastDefBodyFeature =>
      'Acabamos de lançar uma nova funcionalidade no Socialmesh. Confira!';

  @override
  String get adminBroadcastDefBodyMaintenance =>
      'Os serviços Socialmesh ficarão brevemente indisponíveis para manutenção programada.';

  @override
  String get adminBroadcastDefBodyAlert =>
      'Esteja ciente de um problema importante que afeta o Socialmesh.';

  @override
  String get adminBroadcastDefBodyCelebration =>
      'Temos algo empolgante para celebrar com a comunidade Socialmesh!';

  @override
  String get adminBroadcastDefBodyTip =>
      'Aqui vai uma dica útil para aproveitar ao máximo o Socialmesh.';

  @override
  String get adminBroadcastDefBodySignals =>
      'Confira as novidades no Signals, seu feed de presença mesh.';

  @override
  String get adminBroadcastDefBodyNodedex =>
      'O NodeDex tem novas funcionalidades para descobrir e rastrear nós mesh.';

  @override
  String get adminBroadcastDefBodyAether =>
      'Novas melhorias no compartilhamento de voos Aether estão disponíveis.';

  @override
  String get adminBroadcastDefBodyActivity =>
      'Veja o que está acontecendo no seu feed de Atividade.';

  @override
  String get adminBroadcastDefBodyPresence =>
      'A detecção de presença foi melhorada para maior percepção da rede mesh.';

  @override
  String get adminBroadcastDefBodyCommunity =>
      'Participe das últimas iniciativas da comunidade Socialmesh.';

  @override
  String get adminBroadcastDefBodyWorldMap =>
      'O mapa mundial mesh tem novas funcionalidades para explorar a cobertura mesh global.';

  @override
  String get adminBroadcastDefBodyThemes =>
      'Um novo pacote de temas está disponível na loja Socialmesh.';

  @override
  String get adminBroadcastDefBodyRingtones =>
      'Um novo pacote de toques está disponível para suas notificações mesh.';

  @override
  String get adminBroadcastDefBodyWidgets =>
      'Novos widgets para a tela inicial estão disponíveis para o Socialmesh.';

  @override
  String get adminBroadcastDefBodyAutomations =>
      'Novos gatilhos e ações de automação estão disponíveis.';

  @override
  String get adminBroadcastDefBodyIfttt =>
      'Conecte o Socialmesh aos seus serviços favoritos via IFTTT.';

  @override
  String get adminBroadcastDeepLinkCatCore => 'PRINCIPAL';

  @override
  String get adminBroadcastDeepLinkCatSocial => 'SOCIAL';

  @override
  String get adminBroadcastDeepLinkCatMesh => 'MESH';

  @override
  String get adminBroadcastDeepLinkCatPremium => 'PREMIUM';

  @override
  String get adminBroadcastLinkSettings => 'Configurações';

  @override
  String get adminBroadcastLinkAccount => 'Conta e assinaturas';

  @override
  String get adminBroadcastLinkScanner => 'Scanner';

  @override
  String get adminBroadcastLinkMessages => 'Mensagens';

  @override
  String get adminBroadcastLinkChannels => 'Canais';

  @override
  String get adminBroadcastLinkNodes => 'Nós';

  @override
  String get adminBroadcastLinkMap => 'Mapa';

  @override
  String get adminBroadcastLinkSignals => 'Sinais';

  @override
  String get adminBroadcastLinkNodedex => 'NodeDex';

  @override
  String get adminBroadcastLinkAether => 'Aether';

  @override
  String get adminBroadcastLinkActivity => 'Atividade';

  @override
  String get adminBroadcastLinkPresence => 'Presença';

  @override
  String get adminBroadcastLinkTimeline => 'Linha do Tempo';

  @override
  String get adminBroadcastLinkWorldMap => 'Mapa Mundial';

  @override
  String get adminBroadcastLinkGlobe => 'Globo 3D';

  @override
  String get adminBroadcastLinkReachability => 'Alcançabilidade';

  @override
  String get adminBroadcastLinkThemes => 'Pacote de Temas';

  @override
  String get adminBroadcastLinkRingtones => 'Pacote de Toques';

  @override
  String get adminBroadcastLinkWidgets => 'Widgets';

  @override
  String get adminBroadcastLinkAutomations => 'Automações';

  @override
  String get adminBroadcastLinkIfttt => 'Integração IFTTT';

  @override
  String get adminDiagTitle => 'Diagnóstico Admin';

  @override
  String get adminDiagTargetLocal => 'Dispositivo local';

  @override
  String adminDiagTargetRemote(String hexId) {
    return 'Remoto: $hexId';
  }

  @override
  String get adminDiagDescription =>
      'Execute sondas de diagnóstico no dispositivo conectado e exporte um pacote detalhado para depuração de problemas de protocolo/transporte.';

  @override
  String get adminDiagTargetLabel => 'Destino';

  @override
  String get adminDiagMyNodeLabel => 'Meu Nó';

  @override
  String get adminDiagStressToggle => 'Incluir testes de estresse';

  @override
  String get adminDiagStressToggleSub =>
      'Leituras em rajada e correlação fora de ordem';

  @override
  String get adminDiagWriteToggle => 'Incluir testes de escrita (reversíveis)';

  @override
  String get adminDiagWriteToggleSub =>
      'Escritas no-op com verificação de releitura';

  @override
  String get adminDiagRunButton => 'Executar Diagnóstico';

  @override
  String get adminDiagNoDevice => 'Nenhum dispositivo conectado';

  @override
  String adminDiagProbeProgress(int completed, int total) {
    return '$completed / $total sondas';
  }

  @override
  String get adminDiagCancel => 'Cancelar';

  @override
  String adminDiagResultSummary(int passed, int failed) {
    return '$passed aprovados, $failed falhos';
  }

  @override
  String get adminDiagExportBundle => 'Exportar Pacote';

  @override
  String get adminDiagCopySummary => 'Copiar Resumo para Área de Transferência';

  @override
  String get adminDiagRunAgain => 'Executar Novamente';

  @override
  String get adminDiagWriteTestsDialogTitle => 'Habilitar Testes de Escrita?';

  @override
  String get adminDiagWriteTestsDialogBody =>
      'Os testes de escrita executam escritas no-op (mesmo valor) para verificar o comportamento round-trip. Eles não alteram o estado do dispositivo, mas enviam comandos SET ao dispositivo.\n\nTem certeza de que deseja incluir testes de escrita?';

  @override
  String get adminDiagWriteTestsCancel => 'Cancelar';

  @override
  String get adminDiagWriteTestsEnable => 'Habilitar';

  @override
  String adminDiagExportFailed(String error) {
    return 'Exportação falhou: $error';
  }

  @override
  String get adminDiagCopiedToClipboard =>
      'Resumo copiado para a área de transferência';

  @override
  String get adminPurchasesTitle => 'Compras dos Usuários';

  @override
  String get adminPurchasesLabelTotal => ' TOTAL · ';

  @override
  String get adminPurchasesLabelPaying => ' PAGANTES · ';

  @override
  String get adminPurchasesLabelFree => ' GRATUITOS · ';

  @override
  String get adminPurchasesLabelRevenue => ' RECEITA';

  @override
  String get adminPurchasesLabelExcluded => ' EXCLUÍDOS';

  @override
  String get adminPurchasesStatTotalUsers => 'Total de Usuários';

  @override
  String get adminPurchasesStatPaying => 'Pagantes';

  @override
  String adminPurchasesStatExcludedCount(int count) {
    return '$count excluídos';
  }

  @override
  String get adminPurchasesStatFree => 'Gratuitos';

  @override
  String get adminPurchasesStatConversion => 'Conversão';

  @override
  String get adminPurchasesStatArpu => 'ARPU';

  @override
  String get adminPurchasesStatArpuTooltip => 'Receita Média Por Usuário';

  @override
  String get adminPurchasesStatGross => 'Receita Bruta';

  @override
  String get adminPurchasesStatExcluded => 'Excluídos';

  @override
  String get adminPurchasesStatNet => 'Receita Líquida';

  @override
  String get adminPurchasesStatNewUsers24h => 'Novos Usuários (24h)';

  @override
  String get adminPurchasesStatPurchases24h => 'Compras (24h)';

  @override
  String get adminPurchasesStatRevenue24h => 'Receita (24h)';

  @override
  String get adminPurchasesSearchHint => 'Buscar usuários...';

  @override
  String get adminPurchasesFilterAll => 'Todos';

  @override
  String get adminPurchasesFilterPaying => 'Pagantes';

  @override
  String get adminPurchasesFilterFree => 'Gratuitos';

  @override
  String get adminPurchasesFilterExcluded => 'Excluídos';

  @override
  String get adminPurchasesFilterAnonymous => 'Anônimos';

  @override
  String get adminPurchasesFilterDeleted => 'Excluídos';

  @override
  String get adminPurchasesBannerTitle =>
      'Mostra compras sincronizadas via login no app ou webhooks do RevenueCat.';

  @override
  String get adminPurchasesBannerSubtitle =>
      'Os usuários devem abrir o app enquanto logados para que suas compras apareçam aqui.';

  @override
  String get adminPurchasesErrorLoading => 'Erro ao carregar usuários';

  @override
  String get adminPurchasesRetry => 'Tentar Novamente';

  @override
  String get adminPurchasesNoSearchResults =>
      'Nenhum usuário corresponde à busca';

  @override
  String get adminPurchasesNoUsers => 'Nenhum usuário encontrado';

  @override
  String get adminPurchasesUnknownUser => 'Usuário Desconhecido';

  @override
  String get adminPurchasesAnonymousTag => 'Anônimo';

  @override
  String get adminPurchasesDeletedTag => 'Excluído';

  @override
  String get adminPurchasesAnonRcUser => 'Usuário RevenueCat Anônimo';

  @override
  String get adminPurchasesFallbackCloudSync => 'Sincronização Cloud';

  @override
  String get adminPurchasesSectionIds => 'Identificadores';

  @override
  String get adminPurchasesFirebaseUid => 'UID Firebase';

  @override
  String get adminPurchasesRevenueCatId => 'ID RevenueCat';

  @override
  String get adminPurchasesMemberSince => 'Membro Desde';

  @override
  String get adminPurchasesSectionPurchases => 'Compras';

  @override
  String adminPurchasesItemCount(int count) {
    return '$count itens';
  }

  @override
  String get adminPurchasesNoPurchases => 'Nenhuma compra';

  @override
  String get adminPurchasesCopied => 'Copiado para a área de transferência';

  @override
  String get adminPurchasesCopyTooltip => 'Copiar';

  @override
  String get adminQrStyleTitle => 'Estilos de Código QR';

  @override
  String get adminQrStyleHeading => 'Estilos de Código QR com Marca';

  @override
  String get adminQrStyleDescription =>
      'Pré-visualize diferentes estilos de código QR com o logo Socialmesh. Todos os estilos usam correção de erro Nível H para leitura confiável.';

  @override
  String get adminQrStyleSmooth => 'Suave';

  @override
  String get adminQrStyleSmoothDesc =>
      'Módulos modernos e arredondados tipo líquido. Visual premium.';

  @override
  String get adminQrStyleDots => 'Pontos';

  @override
  String get adminQrStyleDotsDesc =>
      'Módulos de pontos circulares. Visual limpo e minimalista.';

  @override
  String get adminQrStyleSquares => 'Quadrados';

  @override
  String get adminQrStyleSquaresDesc =>
      'Estilo QR clássico em blocos. Máxima compatibilidade.';

  @override
  String get adminQrStyleElevatedHeader => 'ESTILOS ELEVADOS';

  @override
  String adminQrStyleElevatedSub(String styleName) {
    return 'Tratamentos de cor premium com padrão $styleName';
  }

  @override
  String get adminQrStyleNeonGlow => 'Neon Glow';

  @override
  String get adminQrStyleFrostedGlass => 'Vidro Fosco';

  @override
  String get adminQrStyleInverted => 'Invertido';

  @override
  String get adminQrStyleHolographic => 'Holográfico';

  @override
  String get adminQrStyleAccentBranded => 'Destaque com Marca';

  @override
  String get adminQrStyleMinimal => 'Mínimo';

  @override
  String get adminQrStyleCyberpunk => 'Cyberpunk';

  @override
  String get adminQrStyleAccentGlow => 'Destaque Glow';

  @override
  String get adminQrStyleOcean => 'Oceano';

  @override
  String get adminQrStyleLuxury => 'Luxo';

  @override
  String adminQrStyleSelected(String styleName) {
    return 'Selecionado: $styleName';
  }

  @override
  String get adminQrStyleScanToVerify => 'Escaneie para verificar';

  @override
  String get adminBugReportsTitle => 'Relatórios de Bugs';

  @override
  String get adminBugReportsSearchHint => 'Buscar relatórios';

  @override
  String get adminBugReportsLoadError => 'Falha ao carregar relatórios';

  @override
  String get adminBugReportsMessageTooLong =>
      'A mensagem excede 2.000 caracteres.';

  @override
  String get adminBugReportsReplySent => 'Resposta enviada.';

  @override
  String adminBugReportsReplyFailed(String error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String get adminBugReportsResolved => 'Relatório resolvido.';

  @override
  String get adminBugReportsReopened => 'Relatório reaberto.';

  @override
  String adminBugReportsStatusFailed(String error) {
    return 'Falha ao atualizar status: $error';
  }

  @override
  String get adminBugReportsStatusOpen => 'ABERTO';

  @override
  String get adminBugReportsStatusUserReplied => 'RESPOSTA DO USUÁRIO';

  @override
  String get adminBugReportsStatusResponded => 'RESPONDIDO';

  @override
  String get adminBugReportsStatusResolved => 'RESOLVIDO';

  @override
  String get adminBugReportsTimeJustNow => 'agora';

  @override
  String adminBugReportsTimeMinutes(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String adminBugReportsTimeHours(int hours) {
    return '${hours}h atrás';
  }

  @override
  String adminBugReportsTimeDays(int days) {
    return '${days}d atrás';
  }

  @override
  String get adminBugReportsSectionDesc => 'DESCRIÇÃO';

  @override
  String get adminBugReportsSectionScreenshot => 'CAPTURA DE TELA';

  @override
  String get adminBugReportsSectionDetails => 'DETALHES';

  @override
  String get adminBugReportsDetailReportId => 'ID do Relatório';

  @override
  String get adminBugReportsDetailUserId => 'ID do Usuário';

  @override
  String get adminBugReportsAnonymousValue => 'anônimo';

  @override
  String get adminBugReportsDetailEmail => 'E-mail';

  @override
  String get adminBugReportsDetailDevice => 'Dispositivo';

  @override
  String get adminBugReportsDetailOs => 'Versão do SO';

  @override
  String get adminBugReportsDetailAppVer => 'Versão do App';

  @override
  String get adminBugReportsSectionConversation => 'CONVERSA';

  @override
  String get adminBugReportsThreadYou => 'Você';

  @override
  String get adminBugReportsThreadUser => 'Usuário';

  @override
  String get adminBugReportsReplyHint => 'Escreva uma resposta...';

  @override
  String get adminBugReportsReopen => 'Reabrir';

  @override
  String get adminBugReportsResolve => 'Resolver';

  @override
  String adminBugReportsCountdownCancel(int seconds) {
    return 'Cancelar · $seconds';
  }

  @override
  String get adminBugReportsSend => 'Enviar';

  @override
  String get adminBugReportsAnonNotice =>
      'Relatório anônimo — as respostas não podem ser entregues.';

  @override
  String get adminBugReportsEmptyFilter =>
      'Nenhum relatório corresponde ao filtro.';

  @override
  String get adminBugReportsEmptyAll => 'Nenhum relatório de bug ainda.';

  @override
  String get adminConformanceTitle => 'Teste de Conformidade';

  @override
  String get adminConformanceDescription =>
      'Teste de conformidade de dispositivo vinculado a providers. Todas as mutações passam pelos mesmos entrypoints de provider usados pelas telas reais.';

  @override
  String get adminConformanceTargetDevice => 'Dispositivo Alvo';

  @override
  String adminConformanceTargetRemote(String target) {
    return 'Remoto: $target';
  }

  @override
  String get adminConformanceTargetLocal => 'Dispositivo local';

  @override
  String adminConformanceNodesAvailable(int count) {
    return '$count nó(s) remoto(s) disponível(is)';
  }

  @override
  String get adminConformanceOtaPki => 'Admin over-the-air via PKI';

  @override
  String get adminConformanceNoNodes => 'Nenhum nó remoto com PKI';

  @override
  String get adminConformanceSwitchLocal => 'Mudar para Local';

  @override
  String get adminConformanceTestOptions => 'Opções de Teste';

  @override
  String get adminConformanceDestructive => 'Testes Destrutivos';

  @override
  String get adminConformanceDestructiveSub =>
      'Mutações aleatórias, estresse em rajada, reset do DB de nós. Pode alterar temporariamente a configuração.';

  @override
  String get adminConformanceRunRemoteDestructive =>
      'Executar Conformidade Remota (Destrutivo)';

  @override
  String get adminConformanceRunRemoteSafe =>
      'Executar Conformidade Remota (Seguro)';

  @override
  String get adminConformanceRunLocalDestructive =>
      'Executar Conformidade (Destrutivo)';

  @override
  String get adminConformanceRunLocalSafe => 'Executar Conformidade (Seguro)';

  @override
  String adminConformanceProgress(
    int completed,
    int total,
    int pass,
    int fail,
  ) {
    return '$completed / $total  (aprovados: $pass, falhos: $fail)';
  }

  @override
  String get adminConformanceCancel => 'Cancelar';

  @override
  String get adminConformanceAllPassed => 'Todos os Testes Aprovados';

  @override
  String get adminConformanceSomeFailed => 'Alguns Testes Falharam';

  @override
  String get adminConformanceLabelPassed => 'Aprovados';

  @override
  String get adminConformanceLabelFailed => 'Falhos';

  @override
  String get adminConformanceLabelSkipped => 'Ignorados';

  @override
  String get adminConformanceLabelTimeouts => 'Tempos limite';

  @override
  String get adminConformanceAnomalies => 'Anomalias:';

  @override
  String get adminConformanceTestResults => 'Resultados dos Testes';

  @override
  String get adminConformanceExportBundle => 'Exportar Pacote';

  @override
  String get adminConformanceRunAgain => 'Executar Novamente';

  @override
  String get adminConformanceInitializing => 'Inicializando';

  @override
  String get globalLayerDiagnosticsTitle => 'Diagnóstico';

  @override
  String get globalLayerCopyReportTooltip => 'Copiar relatório';

  @override
  String get globalLayerCheckResultsHeader => 'Resultados das Verificações';

  @override
  String get globalLayerConnectionDiagnosticsTitle => 'Diagnóstico de Conexão';

  @override
  String get globalLayerConnectionDiagnosticsDescription =>
      'Execute uma série de verificações para validar a conexão com o broker. Cada etapa testa uma camada diferente da pilha de conexão.';

  @override
  String globalLayerRunningChecksProgress(int passed, int total) {
    return 'Executando verificações... $passed/$total';
  }

  @override
  String get globalLayerRunAgain => 'Executar Novamente';

  @override
  String get globalLayerStartDiagnostics => 'Iniciar Diagnóstico';

  @override
  String get globalLayerSummaryHeader => 'Resumo';

  @override
  String globalLayerTotalTime(int milliseconds) {
    return 'Tempo total: ${milliseconds}ms';
  }

  @override
  String get globalLayerAllClearTitle => 'Tudo OK';

  @override
  String globalLayerAllChecksPassed(int count) {
    return 'Todas as $count verificações aprovadas';
  }

  @override
  String get globalLayerWarningsFoundTitle => 'Avisos Encontrados';

  @override
  String get globalLayerWarningsFoundMessage =>
      'Todas as verificações aprovadas, mas com avisos para revisar';

  @override
  String get globalLayerIssuesFoundTitle => 'Problemas Encontrados';

  @override
  String globalLayerChecksFailedCount(int failed, int total) {
    return '$failed de $total verificações falharam';
  }

  @override
  String get globalLayerDiagnosticsReportCopied =>
      'Relatório de diagnóstico copiado para a área de transferência';

  @override
  String get globalLayerChecking => 'Verificando...';

  @override
  String globalLayerSkippedBecauseFailed(String checkName) {
    return 'Ignorado porque $checkName falhou.';
  }

  @override
  String globalLayerFixCheckFirst(String checkName) {
    return 'Corrija $checkName primeiro, depois execute o diagnóstico novamente.';
  }

  @override
  String get globalLayerNoHostnameConfigured => 'Nenhum hostname configurado.';

  @override
  String get globalLayerEnterBrokerHostname =>
      'Insira um hostname do broker no assistente de configuração.';

  @override
  String globalLayerHostnameResolved(String host) {
    return 'Hostname \"$host\" resolvido com sucesso.';
  }

  @override
  String globalLayerTcpConnectionEstablished(String host, int port) {
    return 'Conexão TCP com $host:$port estabelecida.';
  }

  @override
  String get globalLayerTlsHandshakeCompleted =>
      'Handshake TLS concluído com sucesso.';

  @override
  String globalLayerAuthenticatedAs(String username) {
    return 'Autenticado como \"$username\".';
  }

  @override
  String get globalLayerAnonymousConnection =>
      'Conexão anônima aceita pelo broker.';

  @override
  String globalLayerSubscribedToTopics(int count) {
    return 'Inscrito em $count tópico(s) com sucesso.';
  }

  @override
  String get globalLayerSubscribeCapabilityVerified =>
      'Capacidade de inscrição verificada (nenhum tópico habilitado).';

  @override
  String get globalLayerPublishTestPassed =>
      'Mensagem de teste publicada e recebida no loopback.';

  @override
  String get globalLayerFailedToLoadConfig =>
      'Falha ao carregar configuração do Global Layer';

  @override
  String get globalLayerRetry => 'Tentar novamente';

  @override
  String get globalLayerCopyDiagnosticsTooltip => 'Copiar diagnóstico';

  @override
  String get globalLayerTopicExplorerTitle => 'Explorador de tópicos';

  @override
  String get globalLayerRunDiagnosticsMenuItem => 'Executar diagnóstico';

  @override
  String get globalLayerReconfigureMenuItem => 'Reconfigurar';

  @override
  String get globalLayerReset => 'Redefinir';

  @override
  String get globalLayerRecentActivityHeader => 'Atividade recente';

  @override
  String get globalLayerPausedSnackbar => 'Global Layer pausado';

  @override
  String get globalLayerResumedSnackbar => 'Global Layer retomado';

  @override
  String get globalLayerDiagnosticsCopiedSnackbar =>
      'Diagnóstico copiado para a área de transferência';

  @override
  String get globalLayerResetTitle => 'Redefinir Global Layer';

  @override
  String get globalLayerResetMessage =>
      'Isso apagará toda a configuração do broker, credenciais e histórico de conexões. Você precisará executar o assistente de configuração novamente.';

  @override
  String get globalLayerQuickActionsHeader => 'Ações rápidas';

  @override
  String get globalLayerDisconnectAction => 'Desconectar';

  @override
  String get globalLayerConnectAction => 'Conectar';

  @override
  String get globalLayerPauseAction => 'Pausar';

  @override
  String get globalLayerResumeAction => 'Retomar';

  @override
  String get globalLayerDiagnoseAction => 'Diagnosticar';

  @override
  String get globalLayerTopicsAction => 'Tópicos';

  @override
  String get globalLayerBrokerHeader => 'Broker';

  @override
  String get globalLayerHostLabel => 'Host';

  @override
  String get globalLayerPortLabel => 'Porta';

  @override
  String get globalLayerTlsLabel => 'TLS';

  @override
  String get globalLayerTlsEnabled => 'Ativado';

  @override
  String get globalLayerTlsDisabled => 'Desativado';

  @override
  String get globalLayerUserLabel => 'Usuário';

  @override
  String get globalLayerLastConnectedLabel => 'Última conexão';

  @override
  String get globalLayerTopicsLabel => 'Tópicos';

  @override
  String globalLayerActiveTopicsCount(int count) {
    return '$count ativos';
  }

  @override
  String get globalLayerJustNow => 'Agora';

  @override
  String globalLayerMinutesAgo(int minutes) {
    return '${minutes}m atrás';
  }

  @override
  String globalLayerHoursAgo(int hours) {
    return '${hours}h atrás';
  }

  @override
  String globalLayerDaysAgo(int days) {
    return '${days}d atrás';
  }

  @override
  String globalLayerSecondsAgo(int seconds) {
    return '${seconds}s atrás';
  }

  @override
  String globalLayerDateFormat(int day, int month, int year) {
    return '$day/$month/$year';
  }

  @override
  String globalLayerShortDateFormat(int month, int day) {
    return '$day/$month';
  }

  @override
  String get globalLayerHealthHeader => 'Saúde';

  @override
  String get globalLayerHealthy => 'Saudável';

  @override
  String get globalLayerUnhealthy => 'Com problemas';

  @override
  String get globalLayerPingLabel => 'Ping';

  @override
  String get globalLayerReconnectsLabel => 'Reconexões';

  @override
  String get globalLayerInboundLabel => 'Entrada';

  @override
  String get globalLayerOutboundLabel => 'Saída';

  @override
  String get globalLayerThroughputLabel => 'Throughput';

  @override
  String get globalLayerSessionLabel => 'Sessão';

  @override
  String globalLayerActiveErrors(int count) {
    return '$count erro(s) ativo(s)';
  }

  @override
  String get globalLayerPrivacyHeader => 'Privacidade';

  @override
  String get globalLayerPrivacyAllOff => 'Tudo desativado';

  @override
  String get globalLayerShareMessagesLabel => 'Compartilhar mensagens';

  @override
  String get globalLayerShareMessagesDescription =>
      'Encaminhar mensagens locais ao broker';

  @override
  String get globalLayerShareTelemetryLabel => 'Compartilhar telemetria';

  @override
  String get globalLayerShareTelemetryDescription =>
      'Publicar dados de saúde do dispositivo';

  @override
  String get globalLayerAcceptInboundLabel => 'Aceitar entrada';

  @override
  String get globalLayerAcceptInboundDescription =>
      'Receber mensagens do broker';

  @override
  String get globalLayerStatusOn => 'ON';

  @override
  String get globalLayerStatusOff => 'DESLIGADO';

  @override
  String get globalLayerAddFromTemplate => 'Adicionar de modelo';

  @override
  String get globalLayerAddCustomTopic => 'Adicionar tópico personalizado';

  @override
  String get globalLayerSubscriptionsHeader => 'Assinaturas';

  @override
  String get globalLayerAddButton => 'Adicionar';

  @override
  String get globalLayerRemoveTopicTitle => 'Remover tópico';

  @override
  String globalLayerRemoveTopicMessage(String label, String topic) {
    return 'Remover \"$label\" ($topic) das suas assinaturas? Você pode adicioná-lo novamente depois.';
  }

  @override
  String get globalLayerRemoveConfirm => 'Remover';

  @override
  String globalLayerRemovedSnackbar(String label) {
    return '\"$label\" removido';
  }

  @override
  String get globalLayerUndo => 'Desfazer';

  @override
  String globalLayerFailedToLoadTopics(String error) {
    return 'Falha ao carregar tópicos: $error';
  }

  @override
  String get globalLayerNoTopicSubscriptions => 'Nenhuma assinatura de tópico';

  @override
  String get globalLayerEmptyTopicsDescription =>
      'Adicione tópicos para controlar quais tipos de dados mesh passam pelo Global Layer. Cada tópico corresponde a uma categoria como chat, telemetria ou posição.';

  @override
  String get globalLayerFromTemplateButton => 'De modelo';

  @override
  String get globalLayerCustomButton => 'Personalizado';

  @override
  String get globalLayerTopicPaused => 'Pausado';

  @override
  String get globalLayerTopicListening => 'Escutando';

  @override
  String get globalLayerTopicOffline => 'Offline';

  @override
  String get globalLayerStatsTopics => 'Tópicos';

  @override
  String get globalLayerStatsActive => 'Ativos';

  @override
  String get globalLayerStatsMessages => 'Mensagens';

  @override
  String get globalLayerStatsRate => 'Taxa';

  @override
  String get globalLayerAddCustomTopicDescription =>
      'Assine um tópico MQTT personalizado. Curingas (+, #) são permitidos para tópicos de assinatura.';

  @override
  String get globalLayerLabelFieldLabel => 'Rótulo';

  @override
  String get globalLayerLabelFieldHint => 'ex. Boletins meteorológicos';

  @override
  String get globalLayerMqttTopicFieldLabel => 'Tópico MQTT';

  @override
  String get globalLayerMqttTopicFieldHint => 'ex. msh/weather/+';

  @override
  String get globalLayerAddSubscriptionButton => 'Adicionar assinatura';

  @override
  String get globalLayerAddFromTemplateDescription =>
      'Escolha um modelo de tópico predefinido. Os marcadores serão resolvidos usando os valores abaixo.';

  @override
  String get globalLayerChannelFieldLabel => 'Canal';

  @override
  String get globalLayerChannelFieldHint => 'LongFast';

  @override
  String get globalLayerNodeIdFieldLabel => 'ID do nó';

  @override
  String get globalLayerNodeIdFieldHint => '!a1b2c3d4';

  @override
  String get globalLayerTemplateAdded => 'Adicionado';

  @override
  String get adminFollowRequestFrom => 'DE';

  @override
  String get adminFollowRequestTo => 'PARA';

  @override
  String adminPostsFilteredCount(int count) {
    return 'Filtrados ($count)';
  }

  @override
  String get dashboardAddToFavorites => 'Adicionar aos favoritos';

  @override
  String get dashboardAddWidget => 'Adicionar widget';

  @override
  String get dashboardAddWidgets => 'Adicionar widgets';

  @override
  String get dashboardChUtilLabel => 'Util. canal';

  @override
  String get dashboardDone => 'Concluído';

  @override
  String get dashboardEditTitle => 'Editar painel';

  @override
  String get dashboardHealthConnection => 'Conexão';

  @override
  String get dashboardHealthNodes => 'Nós';

  @override
  String get dashboardHealthOffline => 'Offline';

  @override
  String get dashboardHealthOnline => 'Online';

  @override
  String get dashboardHealthSignal => 'Sinal';

  @override
  String get dashboardHelp => 'Ajuda';

  @override
  String get dashboardLastHour => 'Última hora';

  @override
  String get dashboardLive => 'AO VIVO';

  @override
  String get dashboardNoChannelsConfigured => 'Nenhum canal configurado';

  @override
  String get dashboardNoMessagesYet => 'Nenhuma mensagem ainda';

  @override
  String get dashboardNoNearbyNodes => 'Nenhum nó próximo detectado';

  @override
  String get dashboardNoSignalData => 'Nenhum dado de sinal disponível';

  @override
  String get dashboardNodesLabel => 'Nós';

  @override
  String get dashboardQuickMessage => 'Mensagem\nrápida';

  @override
  String get dashboardRemoveConfirm => 'Remover';

  @override
  String get dashboardRemoveFromFavorites => 'Remover dos favoritos';

  @override
  String get dashboardRemoveWidget => 'Remover widget';

  @override
  String dashboardRemoveWidgetMessage(String displayName) {
    return 'Deseja remover \"$displayName\" do painel?';
  }

  @override
  String get dashboardRemoveWidgetTitle => 'Remover widget?';

  @override
  String get dashboardRssiLabel => 'RSSI';

  @override
  String get dashboardSettings => 'Configurações';

  @override
  String get dashboardShareLocation => 'Compartilhar\nlocalização';

  @override
  String get dashboardSignalLabel => 'SINAL';

  @override
  String get dashboardSnrLabel => 'SNR';

  @override
  String get dashboardStatusLabel => 'Estado';

  @override
  String get dashboardStatusOffline => 'Offline';

  @override
  String get dashboardStatusOnline => 'Online';

  @override
  String get dashboardTitle => 'Painel';

  @override
  String get dashboardTraceroute => 'Traceroute';

  @override
  String get dashboardWidgetActiveNodes => 'Nós ativos';

  @override
  String get dashboardWidgetActiveNodesDesc => 'Nós detectados na última hora';

  @override
  String get dashboardWidgetAirtimeUsage => 'Uso de airtime';

  @override
  String get dashboardWidgetAirtimeUsageDesc =>
      'Tempo de transmissão do rádio e limites';

  @override
  String get dashboardWidgetChannelActivity => 'Atividade do canal';

  @override
  String get dashboardWidgetChannelActivityDesc =>
      'Atividade de mensagens por canal';

  @override
  String get dashboardWidgetGpsPosition => 'Posição GPS';

  @override
  String get dashboardWidgetGpsPositionDesc =>
      'Localização atual do dispositivo';

  @override
  String get dashboardWidgetMeshHealth => 'Saúde da mesh';

  @override
  String get dashboardWidgetMeshHealthDesc =>
      'Pontuação geral de saúde da rede mesh';

  @override
  String get dashboardWidgetMessages => 'Mensagens';

  @override
  String get dashboardWidgetMessagesDesc =>
      'Total de mensagens enviadas e recebidas';

  @override
  String get dashboardWidgetNetworkTopology => 'Topologia de rede';

  @override
  String get dashboardWidgetNetworkTopologyDesc => 'Grafo visual da rede mesh';

  @override
  String get dashboardWidgetNodes => 'Nós';

  @override
  String get dashboardWidgetNodesDesc =>
      'Total de nós descobertos na rede mesh';

  @override
  String get dashboardWidgetPacketStats => 'Estatísticas de pacotes';

  @override
  String get dashboardWidgetPacketStatsDesc =>
      'Contagem de pacotes enviados, recebidos e perdidos';

  @override
  String get dashboardWidgetQuickActions => 'Ações rápidas';

  @override
  String get dashboardWidgetQuickActionsDesc =>
      'Acesso rápido a funções comuns';

  @override
  String get dashboardWidgetRangeTest => 'Teste de alcance';

  @override
  String get dashboardWidgetRangeTestDesc =>
      'Teste o alcance do sinal com outros nós';

  @override
  String get dashboardWidgetRecentMessages => 'Mensagens recentes';

  @override
  String get dashboardWidgetRecentMessagesDesc =>
      'Últimas mensagens da rede mesh';

  @override
  String get dashboardWidgetSignalStrength => 'Intensidade do sinal';

  @override
  String get dashboardWidgetSignalStrengthDesc =>
      'Gráfico ao vivo de RSSI, SNR e utilização do canal';

  @override
  String get dashboardWidgetWeatherData => 'Dados meteorológicos';

  @override
  String get dashboardWidgetWeatherDataDesc =>
      'Leituras de sensores ambientais';

  @override
  String get discoveryFilterAllSources => 'Todas as fontes';

  @override
  String get draggableTextHint => 'Digite algo...';

  @override
  String get globalLayerAdvanced => 'AVANÇADO';

  @override
  String get globalLayerAuth => 'Autenticação';

  @override
  String get globalLayerAuthentication => 'AUTENTICAÇÃO';

  @override
  String get globalLayerBack => 'Voltar';

  @override
  String get globalLayerBrokerAddress => 'Endereço do broker';

  @override
  String get globalLayerClientId => 'ID do cliente';

  @override
  String get globalLayerClientIdHint => 'Gerado automaticamente se vazio';

  @override
  String get globalLayerConnection => 'CONEXÃO';

  @override
  String get globalLayerContinue => 'Continuar';

  @override
  String get globalLayerCustomiseConnection =>
      'Personalizar detalhes da conexão';

  @override
  String get globalLayerDataTypes => 'TIPOS DE DADOS';

  @override
  String get globalLayerEnable => 'Ativar Global Layer';

  @override
  String get globalLayerMqttNote =>
      'Internamente, isso usa um broker MQTT — um servidor de mensagens padrão da internet. Você não precisa saber como o MQTT funciona para usar o Global Layer.';

  @override
  String get globalLayerNext => 'Próximo';

  @override
  String get globalLayerOptional => 'Opcional';

  @override
  String get globalLayerPassword => 'Senha';

  @override
  String get globalLayerPort => 'Porta';

  @override
  String get globalLayerPreConfiguredAuth =>
      'Pré-configurado (credenciais públicas)';

  @override
  String get globalLayerServer => 'Servidor';

  @override
  String get globalLayerSetupTitle => 'Configuração do Global Layer';

  @override
  String globalLayerStepOf(String current, int total) {
    return 'Passo $current de $total';
  }

  @override
  String get globalLayerTopicRoot => 'RAIZ DO TÓPICO';

  @override
  String get globalLayerTopicRootDescription =>
      'O prefixo raiz para todos os tópicos. Altere para manter o tráfego mesh separado de outros no mesmo broker.';

  @override
  String get globalLayerTopicRootLabel => 'Raiz do tópico';

  @override
  String get globalLayerUsername => 'Nome de usuário';

  @override
  String get globalLayerWhatItDoes => 'O que faz';

  @override
  String get globalLayerWhatItDoesNot => 'O que NÃO faz';

  @override
  String helpCenterProgressLabel(int completed, int total) {
    return '$completed / $total';
  }

  @override
  String get mapControlsCenterOnMe => 'Centralizar em mim';

  @override
  String get mapControlsFitAll => 'Mostrar tudo';

  @override
  String get mapControlsResetNorth => 'Redefinir norte';

  @override
  String get mapNodeDrawerClosePanel => 'Fechar painel';

  @override
  String get nodeSelectorSearchHint => 'Buscar nós...';

  @override
  String get portalViewBroker => 'Broker';

  @override
  String get portalViewLocalMesh => 'Mesh local';

  @override
  String get portalViewRemote => 'Remoto';

  @override
  String get positionConfigAltitudeHint => 'ex. 100';

  @override
  String get positionConfigLatitudeHint => 'ex. 37.7749';

  @override
  String get positionConfigLongitudeHint => 'ex. -122.4194';

  @override
  String get privacySettingsFirebaseTitle => 'Firebase (Google)';

  @override
  String get privacySettingsRevenueCatTitle => 'RevenueCat';

  @override
  String get privacySettingsSigilTitle => 'Sigil API (Socialmesh)';

  @override
  String get profileDeleteConfirmLabel => 'Excluir';

  @override
  String get scannerFilteringByUuid => 'Filtrando por UUID Meshtastic';

  @override
  String get scannerScanningAllDevices =>
      'Escaneando todos os dispositivos (modo dev)';

  @override
  String get scannerShowAllBleDevices => 'Mostrar todos os dispositivos BLE';

  @override
  String get settingsGlyphMatrixTestSubtitle => 'Padrões LED Nothing Phone 3';

  @override
  String get signalQualityExcellent => 'Excelente';

  @override
  String get signalQualityFair => 'Razoável';

  @override
  String get signalQualityGood => 'Bom';

  @override
  String get signalQualityPoor => 'Fraco';

  @override
  String get signalQualityVeryGood => 'Muito bom';

  @override
  String get signalQualityWeak => 'Muito fraco';

  @override
  String themeSettingsError(String error) {
    return 'Erro: $error';
  }

  @override
  String get widgetWizardAdd => 'Adicionar';

  @override
  String get dashboardRequestPositions => 'Solicitar\nPosições';

  @override
  String adminPostsDeleteAllCount(int count) {
    return 'Excluir todos ($count)';
  }

  @override
  String get globalLayerAllowInboundChat => 'Permitir chat de entrada global';

  @override
  String get globalLayerDiagBrokerEmpty => 'O endereço do broker está vazio.';

  @override
  String globalLayerDiagUnexpectedError(String error) {
    return 'Erro inesperado: $error';
  }

  @override
  String get globalLayerDiagUsernameNoPassword =>
      'Nome de usuário fornecido, mas a senha está vazia.';

  @override
  String get globalLayerShareMessages =>
      'Compartilhar mensagens no Global Layer';

  @override
  String get globalLayerShareTelemetry => 'Compartilhar telemetria';

  @override
  String get aetherInFlight => 'Em voo';

  @override
  String get aetherLiveFlightData => 'Dados de voo em tempo real';

  @override
  String get aetherOnGround => 'Em solo';

  @override
  String globalLayerNodesSeenVia(int count) {
    return '$count nós vistos via Global Layer';
  }

  @override
  String get helpChannelCreationTitle => 'Criando um canal';

  @override
  String get helpChannelCreationDescription =>
      'Saiba como criar e configurar canais mesh';

  @override
  String get helpEncryptionLevelsTitle => 'Criptografia de canal';

  @override
  String get helpEncryptionLevelsDescription =>
      'Entendendo as opções de privacidade e criptografia';

  @override
  String get helpMessageRoutingTitle => 'Como as mensagens viajam';

  @override
  String get helpMessageRoutingDescription =>
      'Entendendo o roteamento mesh e os saltos das mensagens';

  @override
  String get helpNodesOverviewTitle => 'Sua rede mesh';

  @override
  String get helpNodesOverviewDescription =>
      'Entendendo os nós na sua rede mesh';

  @override
  String get helpNodeRolesTitle => 'Funções dos nós';

  @override
  String get helpNodeRolesDescription =>
      'CLIENT vs ROUTER vs REPEATER explicados';

  @override
  String get helpRegionSelectionTitle => 'Selecionando sua região';

  @override
  String get helpRegionSelectionDescription =>
      'Faixas de frequência e conformidade legal';

  @override
  String get helpDeviceConnectionTitle => 'Conectando seu dispositivo';

  @override
  String get helpDeviceConnectionDescription =>
      'BLE vs USB e processo de pareamento';

  @override
  String get helpGpsSettingsTitle => 'GPS e compartilhamento de posição';

  @override
  String get helpGpsSettingsDescription =>
      'Atualizações de localização e privacidade';

  @override
  String get helpSignalMetricsTitle => 'Entendendo a intensidade do sinal';

  @override
  String get helpSignalMetricsDescription => 'SNR, RSSI e o que significam';

  @override
  String get helpMapOverviewTitle => 'Mapa mesh';

  @override
  String get helpMapOverviewDescription => 'Veja sua rede mesh no mapa';

  @override
  String get helpChannelsOverviewTitle => 'Seus canais';

  @override
  String get helpChannelsOverviewDescription =>
      'Gerenciando canais de comunicação mesh';

  @override
  String get helpAutomationsOverviewTitle => 'Automações';

  @override
  String get helpAutomationsOverviewDescription =>
      'Ações automáticas para sua rede mesh';

  @override
  String get helpDashboardOverviewTitle => 'Seu Dashboard';

  @override
  String get helpDashboardOverviewDescription =>
      'Seu centro de comando mesh personalizável';

  @override
  String get helpWidgetBuilderOverviewTitle => 'Construtor de widgets';

  @override
  String get helpWidgetBuilderOverviewDescription =>
      'Crie seus próprios widgets personalizados';

  @override
  String get helpMarketplaceOverviewTitle => 'Marketplace de widgets';

  @override
  String get helpMarketplaceOverviewDescription =>
      'Descubra widgets feitos pela comunidade';

  @override
  String get helpSignalsOverviewTitle => 'Sinais';

  @override
  String get helpSignalsOverviewDescription =>
      'Transmita sinais efêmeros para sua rede mesh';

  @override
  String get helpSignalCreationTitle => 'Criando um sinal';

  @override
  String get helpSignalCreationDescription =>
      'Como compor e transmitir um sinal';

  @override
  String get helpSignalDetailTitle => 'Detalhes do sinal';

  @override
  String get helpSignalDetailDescription =>
      'Interagindo com um sinal e suas respostas';

  @override
  String get helpWorldMeshOverviewTitle => 'World Mesh';

  @override
  String get helpWorldMeshOverviewDescription =>
      'Visualização global da rede mesh';

  @override
  String get helpRoutesOverviewTitle => 'Rotas';

  @override
  String get helpRoutesOverviewDescription => 'Grave e compartilhe rotas GPS';

  @override
  String get helpPositionOverviewTitle => 'Histórico de posições';

  @override
  String get helpPositionOverviewDescription =>
      'Logs de posição GPS de todos os nós na sua rede mesh';

  @override
  String get helpSettingsOverviewTitle => 'Configurações';

  @override
  String get helpSettingsOverviewDescription =>
      'Configure seu app e dispositivo';

  @override
  String get helpProfileOverviewTitle => 'Seu perfil';

  @override
  String get helpProfileOverviewDescription => 'Gerencie sua identidade mesh';

  @override
  String get helpMesh3dOverviewTitle => 'Mesh 3D';

  @override
  String get helpMesh3dOverviewDescription =>
      'Visualização 3D da topologia de rede';

  @override
  String get helpGlobeOverviewTitle => 'Visão do globo';

  @override
  String get helpGlobeOverviewDescription => 'Globo 3D com sua rede mesh';

  @override
  String get helpTimelineOverviewTitle => 'Linha do Tempo';

  @override
  String get helpTimelineOverviewDescription => 'Histórico de atividades mesh';

  @override
  String get helpDeviceShopOverviewTitle => 'Loja de dispositivos';

  @override
  String get helpDeviceShopOverviewDescription => 'Explore hardware Meshtastic';

  @override
  String get helpOfflineMapsOverviewTitle => 'Mapas offline';

  @override
  String get helpOfflineMapsOverviewDescription =>
      'Configurações e controles de mapa';

  @override
  String get helpRadioConfigOverviewTitle => 'Configurações de rádio';

  @override
  String get helpRadioConfigOverviewDescription => 'Configure seu rádio LoRa';

  @override
  String get helpPresenceOverviewTitle => 'Presença dos nós';

  @override
  String get helpPresenceOverviewDescription =>
      'Monitore quais nós estão ativos na sua rede mesh';

  @override
  String get helpReachabilityOverviewTitle => 'Alcance mesh';

  @override
  String get helpReachabilityOverviewDescription =>
      'Entenda quais nós você pode alcançar';

  @override
  String get helpMeshHealthOverviewTitle => 'Saúde da rede mesh';

  @override
  String get helpMeshHealthOverviewDescription =>
      'Monitore a saúde da sua rede mesh';

  @override
  String get helpTracerouteOverviewTitle => 'Traceroute';

  @override
  String get helpTracerouteOverviewDescription =>
      'Descubra a rota dos pacotes pela sua rede mesh';

  @override
  String get helpNodedexOverviewTitle => 'Diário de campo NodeDex';

  @override
  String get helpNodedexOverviewDescription =>
      'Seu registro pessoal de cada nó descoberto na rede mesh';

  @override
  String get helpNodedexAlbumTitle => 'Álbum de colecionador';

  @override
  String get helpNodedexAlbumDescription =>
      'Uma visão em cards colecionáveis dos nós descobertos';

  @override
  String get helpNodedexConstellationTitle => 'Visão constelação';

  @override
  String get helpNodedexConstellationDescription =>
      'Uma visualização em mapa estelar das relações entre nós co-vistos';

  @override
  String get helpNodedexDetailTitle => 'Perfil do nó';

  @override
  String get helpNodedexDetailDescription =>
      'Entendendo a identidade completa e o histórico de um nó';

  @override
  String get helpCloudSyncOverviewTitle => 'Sincronização na Nuvem';

  @override
  String get helpCloudSyncOverviewDescription =>
      'Sincronização premium entre dispositivos para seus dados mesh';

  @override
  String get helpAetherOverviewTitle => 'Aether';

  @override
  String get helpAetherOverviewDescription =>
      'Rastreie nós Meshtastic em altitude';

  @override
  String get helpTakGatewayOverviewTitle => 'Gateway TAK';

  @override
  String get helpTakGatewayOverviewDescription =>
      'Conecte sua rede mesh ao ecossistema TAK';

  @override
  String get helpRadioComplianceTitle =>
      'Regras de rádio e suas responsabilidades';

  @override
  String get helpRadioComplianceDescription =>
      'Entenda suas obrigações legais ao usar dispositivos de rádio';

  @override
  String get helpAcceptableUseTitle => 'Uso aceitável e atividades proibidas';

  @override
  String get helpAcceptableUseDescription =>
      'O que você pode e não pode fazer com o Socialmesh';

  @override
  String get helpUserResponsibilityTitle => 'Seus dados, sua responsabilidade';

  @override
  String get helpUserResponsibilityDescription =>
      'Como o Socialmesh lida com dados e pelo que você é responsável';

  @override
  String get helpFileTransferOverviewTitle => 'Transferência de arquivos';

  @override
  String get helpFileTransferOverviewDescription =>
      'Envie arquivos pelo rádio mesh sem internet';

  @override
  String get helpFileTransferLimitsTitle => 'Por que apenas 8 KB?';

  @override
  String get helpFileTransferLimitsDescription =>
      'Orçamento de airtime e duty cycle LoRa explicados';

  @override
  String get helpChannelIntroBubble =>
      'Vamos criar um **canal**! É como um walkie-talkie. Só seus amigos que sabem o segredo podem ouvir.';

  @override
  String get helpChannelNameBubble =>
      'Primeiro, escolha um **nome** para seu canal. Algo fácil de lembrar, como \'Família\' ou \'Amigos de trilha\'.';

  @override
  String get helpPrivacyLevelBubble =>
      'Quão secreto deve ser seu canal?\\n\\n**OPEN**: Qualquer um pode ouvir.\\n**SHARED**: Como uma senha que todos conhecem.\\n**PRIVATE**: Apenas amigos que você convidar.\\n**MAXIMUM**: Super ultra secreto!';

  @override
  String get helpEncryptionKeyBubble =>
      'Eu criei uma **chave secreta** para você! Ela embaralha suas mensagens para que só seus amigos possam ler. Como um código secreto!';

  @override
  String get helpChannelCompleteBubble =>
      'Tudo pronto! Mostre aos seus amigos o **código QR** e eles podem entrar no seu canal. Muito fácil!';

  @override
  String get helpEncryptionIntroBubble =>
      'Deixe-me explicar os **níveis de criptografia**. É como escolher quão secretas são suas mensagens!';

  @override
  String get helpDefaultKeyBubble =>
      '**CHAVE PADRÃO** significa que todos na rede mesh podem ler suas mensagens. É público! Use para anúncios gerais ou testes.';

  @override
  String get helpPskEncryptionBubble =>
      '**PSK** (Pre-Shared Key) significa que você gera uma chave secreta aleatória. Apenas pessoas com essa chave exata podem decodificar suas mensagens. Muito mais privado!';

  @override
  String get helpPskSharingBubble =>
      'Compartilhe sua PSK via **código QR**! Quando alguém escaneia, recebe a chave e as configurações do canal. Muito fácil!';

  @override
  String get helpRoutingIntroBubble =>
      'Quer ver como eu funciono? Quando você envia uma mensagem, eu **salto de nó em nó** como um jogo de batata quente!';

  @override
  String get helpRoutingHopsBubble =>
      'Cada **salto** é quando um nó recebe sua mensagem e a encaminha. A maioria das mensagens precisa de **1-3 saltos** para chegar ao destino!';

  @override
  String get helpRoutingRouterRoleBubble =>
      'Nós **ROUTER** são os super-heróis da rede mesh — retransmitem mensagens para todos! Nós **CLIENT** apenas enviam/recebem suas próprias mensagens.';

  @override
  String get helpRoutingStoreForwardBubble =>
      '**Store & Forward** é incrível! Se o destinatário não foi ouvido recentemente, eu guardo a mensagem e a entrego quando um pacote chegar.';

  @override
  String get helpNodesIntroBubble =>
      'Esta é sua **rede mesh**! Cada dispositivo que você vê aqui é um nó que pode falar com você.';

  @override
  String get helpNodesStatusBubble =>
      '**Ponto verde** significa **Online** (ouvido recentemente). **Amarelo** significa **Visto recentemente**. **Cinza** significa **Offline**. LoRa não tem sinal offline — o status é inferido.';

  @override
  String get helpNodesInfoBubble =>
      'Cada card mostra o **nome** do nó, o **nível da bateria** e a **intensidade do sinal**. Toque em qualquer nó para ver mais detalhes!';

  @override
  String get helpNodesFiltersBubble =>
      'Use os **filtros** no topo para encontrar nós específicos. Você pode mostrar apenas nós **Online**, favoritos ou com GPS.';

  @override
  String get helpNodesActionsBubble =>
      'Toque em um nó para **enviar uma mensagem**, ver sua **localização no mapa** ou verificar seus **dados de telemetria**!';

  @override
  String get helpRolesIntroBubble =>
      'As **funções dos nós** determinam como seu dispositivo ajuda a rede mesh. Deixe-me explicar!';

  @override
  String get helpRoleClientBubble =>
      '**CLIENT**: Seu dispositivo envia e recebe mensagens, mas não retransmite para outros. Ótimo para a **vida útil da bateria**!';

  @override
  String get helpRoleRouterBubble =>
      '**ROUTER**: Você é um super-herói da rede mesh! Retransmite mensagens para todos. Usa mais bateria, mas fortalece a rede!';

  @override
  String get helpRoleRouterLateBubble =>
      '**ROUTER LATE**: Retransmite após outros roteadores. Estende a cobertura sem tomar saltos prioritários. Ótimo como relay de backup!';

  @override
  String get helpRoleClientBaseBubble =>
      '**CLIENT BASE**: Estação base para seus nós favoritos. Roteia os pacotes deles como um roteador, trata o resto como um client!';

  @override
  String get helpRegionIntroBubble =>
      'Isso é importante! Sua **região** determina quais frequências de rádio você pode usar legalmente.';

  @override
  String get helpRegionLegalBubble =>
      'Cada país tem regras diferentes. Usar a **frequência errada** pode ser ilegal! Sempre corresponda à sua localização física.';

  @override
  String get helpRegionBandsBubble =>
      'A maioria das regiões usa **915MHz** (Américas) ou **868MHz** (Europa). Algumas usam **433MHz**. O hardware do seu dispositivo deve suportar a frequência!';

  @override
  String get helpRegionWarningBubble =>
      'Região errada = **impossível comunicar** com os outros! Certifique-se de que todos na sua rede mesh usem a mesma configuração de região.';

  @override
  String get helpConnectionIntroBubble =>
      'Vamos conectar seu dispositivo Meshtastic! Existem duas formas: **Bluetooth** ou **USB**.';

  @override
  String get helpConnectionBleBubble =>
      '**BLUETOOTH** (BLE): Sem fio! Seu dispositivo aparece como **Meshtastic_XXXX**. Basta tocar para conectar. Funciona com o dispositivo no bolso!';

  @override
  String get helpConnectionUsbBubble =>
      '**USB**: Conecte com um cabo. Mais confiável, carrega o dispositivo, ligeiramente mais rápido. Ótimo para configuração!';

  @override
  String get helpConnectionPairingBubble =>
      'Primeira vez? Seu dispositivo precisa estar em **modo de pareamento**. Procure o ícone Bluetooth na tela ou pressione o botão!';

  @override
  String get helpConnectionTroubleshootBubble =>
      'Não encontra seu dispositivo? Verifique:\\n- **O Bluetooth está ligado**\\n- O dispositivo tem energia\\n- O dispositivo não está conectado em outro lugar\\n- Você está perto o suficiente (menos de 10m)';

  @override
  String get helpConnectionDisconnectBubble =>
      'Desconectando com frequência? Causas comuns:\\n- **Outro app** (ex. app Meshtastic) já está conectado a este nó\\n- No **TCP/IP (dispositivos ESP)**, apenas um cliente pode conectar por vez\\n- Tente fechar outros apps ou desconectar outros dispositivos primeiro';

  @override
  String get helpGpsIntroBubble =>
      'O **GPS** permite que outros vejam você no mapa! Deixe-me explicar como funciona.';

  @override
  String get helpGpsBroadcastBubble =>
      'Seu dispositivo transmite **atualizações de posição** a cada poucos minutos. Outros nós veem você aparecer no mapa deles!';

  @override
  String get helpGpsPrivacyBubble =>
      'A privacidade importa! Você pode **desativar o GPS** ou definir intervalos de atualização. Desative quando quiser ficar oculto!';

  @override
  String get helpGpsBatteryBubble =>
      'O GPS consome **bateria**! Intervalos de atualização maiores = melhor vida útil da bateria. Equilibre privacidade e utilidade!';

  @override
  String get helpMetricsIntroBubble =>
      'Vamos decodificar esses números do sinal! Eles dizem quão boa está sua conexão.';

  @override
  String get helpMetricsRssiBubble =>
      '**RSSI** (Received Signal Strength): Quão forte é o sinal. Mais alto é melhor! **-50 dBm** = excelente, **-120 dBm** = quase sumindo.';

  @override
  String get helpMetricsSnrBubble =>
      '**SNR** (Signal-to-Noise Ratio): Quão claro é o sinal. Positivo = bom, negativo = ruidoso! **+10 dB** = ótimo, **-10 dB** = com dificuldade.';

  @override
  String get helpMetricsPracticalBubble =>
      'Na prática: **Verde** = excelente, **amarelo** = razoável, **vermelho** = fraco. Aproxime-se ou encontre um ponto mais alto para melhorar!';

  @override
  String get helpMapIntroBubble =>
      'Bem-vindo ao **Mapa mesh**! Cada ponto que você vê é um nó com GPS. Todos fazem parte da sua rede!';

  @override
  String get helpMapMarkersBubble =>
      '**Toque em qualquer marcador** para ver quem é. Você pode enviar uma mensagem, verificar a bateria ou ver quando foi ouvido pela última vez!';

  @override
  String get helpMapFeaturesBubble =>
      'Experimente o **mapa de calor** para ver onde os nós se agrupam, ou as **linhas de conexão** para ver quem pode falar com quem!';

  @override
  String get helpMapMeasureBubble =>
      'Use o **modo de medição** para verificar distâncias entre pontos. Ótimo para planejar onde colocar um novo nó!';

  @override
  String get helpMapFiltersBubble =>
      'Use os **filtros** para mostrar apenas nós **Online** ou com GPS. Ajuda quando o mapa está cheio!';

  @override
  String get helpChannelsIntroBubble =>
      'Estes são seus **canais**! Pense neles como diferentes frequências de rádio. Cada um é uma conversa separada.';

  @override
  String get helpChannelsPrimaryBubble =>
      'O canal **Primário** é especial. Está sempre no slot 0 e não pode ser excluído. A maior parte do tráfego mesh passa por aqui!';

  @override
  String get helpChannelsSecondaryBubble =>
      '**Canais secundários** são para grupos privados. Crie um para sua família, grupo de trilha ou equipe de emergência!';

  @override
  String get helpChannelsEncryptionBubble =>
      'Vê o ícone do **cadeado**? Significa que o canal é criptografado. Apenas pessoas com a chave podem ler as mensagens!';

  @override
  String get helpChannelsShareBubble =>
      'Toque em um canal para ver seu **código QR**. Amigos podem escanear para entrar instantaneamente com as configurações corretas!';

  @override
  String get helpAutomationsIntroBubble =>
      '**Automações** tornam sua rede mesh mais inteligente! Configure regras e eu farei as coisas automaticamente para você.';

  @override
  String get helpAutomationsTriggersBubble =>
      'Toda automação começa com um **gatilho**. Como quando um nó fica inativo, a bateria fica baixa ou você entra em uma área!';

  @override
  String get helpAutomationsActionsBubble =>
      'Depois escolha uma **ação**! Enviar uma mensagem, tocar um som, mostrar uma notificação ou até acionar o IFTTT!';

  @override
  String get helpAutomationsExamplesBubble =>
      'Exemplo: **Me avise quando a bateria do pai ficar abaixo de 20%**. Ou **Envie \'Cheguei em casa!\' quando eu entrar no meu geofence**!';

  @override
  String get helpAutomationsToggleBubble =>
      'Use o **botão de alternância** para ativar ou desativar automações. Teste antes de usar pra valer!';

  @override
  String get helpDashboardIntroBubble =>
      'Bem-vindo ao seu **Dashboard**! Este é seu centro de comando personalizado. Tudo o que você precisa, de relance!';

  @override
  String get helpDashboardWidgetsBubble =>
      'Cada card é um **widget**. Eles mostram dados em tempo real da sua rede mesh — níveis de bateria, mensagens, clima e mais!';

  @override
  String get helpDashboardReorderBubble =>
      '**Toque e segure para arrastar** e reorganizar os widgets. Coloque seus favoritos no topo! Toque em **Editar** para adicionar ou remover.';

  @override
  String get helpDashboardTapBubble =>
      '**Toque em qualquer widget** para ver mais detalhes ou executar uma ação. Experimente tocar um widget de nó para ver todas as informações!';

  @override
  String get helpBuilderIntroBubble =>
      'Bem-vindo ao **Construtor de widgets**! Aqui você pode criar seus próprios widgets personalizados do zero!';

  @override
  String get helpBuilderTemplatesBubble =>
      'Comece com um **modelo** ou construa do zero. Os modelos oferecem medidores, gráficos e cards de status prontos para personalizar!';

  @override
  String get helpBuilderBindingsBubble =>
      'A mágica está nas **vinculações de dados**! Conecte qualquer elemento a dados mesh em tempo real — bateria, GPS, temperatura, intensidade do sinal!';

  @override
  String get helpBuilderPreviewBubble =>
      'Use a **Pré-visualização** para ver como seu widget fica com dados reais antes de salvar. Ajuste até ficar perfeito!';

  @override
  String get helpMarketplaceIntroBubble =>
      'Bem-vindo ao **Marketplace**! Explore widgets criados por outros entusiastas mesh ao redor do mundo!';

  @override
  String get helpMarketplaceBrowseBubble =>
      'Explore por **categoria** — encontre displays de status, gráficos, medidores ou designs criativos. Toque em qualquer widget para pré-visualizar!';

  @override
  String get helpMarketplaceInstallBubble =>
      'Encontrou um que gostou? **Toque em instalar** e ele é adicionado à sua coleção. Use no seu dashboard imediatamente!';

  @override
  String get helpMarketplaceShareBubble =>
      'Criou algo legal? **Compartilhe seus widgets** no marketplace e ajude a comunidade!';

  @override
  String get helpSignalsIntroBubble =>
      'Bem-vindo aos **Sinais**! Transmita momentos para sua rede mesh. Os sinais são **efêmeros** — você escolhe quanto duram, de **15 minutos** até **24 horas**.';

  @override
  String get helpSignalsCreateBubble =>
      'Toque no ícone do **sensor** para ficar ativo! Adicione texto, uma foto ou sua localização. Escolha seu TTL — tempos mais curtos são ótimos para check-ins rápidos.';

  @override
  String get helpSignalsProximityBubble =>
      'Os sinais mostram **emblemas de proximidade** — quantos saltos de distância do remetente. Sinais **Próximos** (0-1 saltos) aparecem primeiro!';

  @override
  String get helpSignalsFiltersBubble =>
      'Use os **filtros** para focar no que importa: sinais próximos, apenas mesh ou conteúdo com mídia. Alterne entre vistas de **lista** e **grade**!';

  @override
  String get helpSignalsPrivacyBubble =>
      'Os sinais são **mesh-first** — viajam pela rede de rádio. Quando desaparecem, se foram. Conteúdo efêmero real, off-grid!';

  @override
  String get helpCreateIntroBubble =>
      'Hora de **Ficar ativo**! Um sinal é uma transmissão efêmera — vive na rede mesh por um tempo determinado, depois desaparece. Vou te mostrar como funciona.';

  @override
  String get helpCreateTextBubble =>
      'Digite sua mensagem no campo principal — até **280 caracteres**. O contador circular no canto mostra quantos restam.';

  @override
  String get helpCreateImageBubble =>
      'Toque no ícone de **imagem** para anexar uma foto. As imagens são enviadas via nuvem quando você está online — não estão disponíveis no modo somente mesh.';

  @override
  String get helpCreateLocationBubble =>
      'Toque no **marcador de localização** para anexar a posição GPS do seu dispositivo. Sua localização é ofuscada para um raio configurável por privacidade. Toque novamente para remover.';

  @override
  String get helpCreateTtlBubble =>
      'O ícone do **timer** define seu TTL — quanto tempo o sinal fica ativo. Escolha de **15 minutos** até **24 horas**. Tempos mais curtos são ótimos para check-ins rápidos.';

  @override
  String get helpCreateIntentBubble =>
      'Escolha um **Intento de presença** para dizer à rede mesh o que você está fazendo — explorando, monitorando, ajudando ou apenas ouvindo. Adiciona contexto sem palavras extras.';

  @override
  String get helpCreateStatusBubble =>
      'O campo de **status curto** é uma linha que aparece como subtítulo no card do sinal. Pense nele como um humor ou legenda.';

  @override
  String get helpCreateSubmitBubble =>
      'Quando estiver pronto, pressione **Transmitir**! Seu sinal viaja primeiro pelo rádio mesh. Se a nuvem estiver disponível, sincroniza lá também para maior alcance.';

  @override
  String get helpDetailIntroBubble =>
      'Esta é a tela de **detalhes do sinal**. Você pode ler o conteúdo completo, ver onde foi publicado e navegar por todas as respostas.';

  @override
  String get helpDetailTtlBubble =>
      'A **barra de TTL** mostra quanto tempo o sinal ainda tem. Quando chega a zero, o sinal expira e esta tela fecha automaticamente.';

  @override
  String get helpDetailResponsesBubble =>
      'As respostas são **encadeadas**. Você pode responder diretamente ao sinal ou à resposta de outra pessoa. Respostas aninhadas são indentadas para acompanhar a conversa.';

  @override
  String get helpDetailVotingBubble =>
      'Toque na **seta para cima ou para baixo** em qualquer resposta para votar. Votos destacam as respostas mais úteis. Você pode mudar seu voto a qualquer momento.';

  @override
  String get helpDetailReplyBubble =>
      'Use a **barra de resposta** na parte inferior para responder. Toque no ícone de resposta em qualquer comentário para iniciar uma conversa encadeada com essa pessoa.';

  @override
  String get helpDetailActionsBubble =>
      'O **menu extra** (três pontos) permite **excluir** seu sinal ou **denunciar** o de outra pessoa. Apenas uma das opções aparece dependendo de você ser o autor do sinal.';

  @override
  String get helpWorldIntroBubble =>
      'Bem-vindo ao **World Mesh**! Veja toda a rede Meshtastic global. Cada ponto é um nó compartilhando sua localização!';

  @override
  String get helpWorldScopeBubble =>
      'Diminua o zoom para ver a **mesh mundial**, ou aumente para explorar clusters locais. É incrível quantos nós existem!';

  @override
  String get helpWorldDataBubble =>
      'Os dados vêm do **MQTT** — nós que optaram por compartilhar sua posição publicamente. Seus nós locais também aparecem!';

  @override
  String get helpWorldFiltersBubble =>
      'Use **filtros** para mostrar regiões específicas ou intervalos de tempo. Encontre meshes ativas perto dos lugares que você visita!';

  @override
  String get helpRoutesIntroBubble =>
      '**Rotas** permite gravar suas jornadas! Perfeito para trilhas, passeios de bike ou qualquer aventura fora da rede.';

  @override
  String get helpRoutesRecordBubble =>
      'Toque em **Gravar** para começar o rastreamento. Vou salvar seus pontos GPS enquanto você se move. Funciona mesmo sem sinal de celular!';

  @override
  String get helpRoutesGpxBubble =>
      '**Importe arquivos GPX** para seguir trilhas existentes. Exporte suas rotas para compartilhar ou usar em outros apps!';

  @override
  String get helpRoutesShareBubble =>
      'Compartilhe rotas com seus amigos de mesh! Ótimo para coordenar pontos de encontro ou mostrar suas trilhas favoritas.';

  @override
  String get helpPositionIntroBubble =>
      'O **Histórico de posições** registra cada posição GPS transmitida pelos nós na mesh. Pense nele como uma caixa preta para dados de localização!';

  @override
  String get helpPositionListMapBubble =>
      'Alterne entre **visualização em lista** e **visualização no mapa** usando o menu. O mapa desenha trilhas coloridas por nó para visualizar movimentos ao longo do tempo.';

  @override
  String get helpPositionFiltersBubble =>
      'Use os **chips de filtro** para refinar os resultados: hoje, esta semana, fix GPS bom, ou apenas seu nó. Combine com um **intervalo de datas personalizado** para filtragem precisa.';

  @override
  String get helpPositionSearchBubble =>
      'A **barra de pesquisa** filtra por nome do nó. Útil quando você tem dezenas de nós e quer rastrear um específico.';

  @override
  String get helpPositionMapNodesBubble =>
      'Na visualização do mapa, toque no botão **lista de nós** para selecionar um único nó. Cada nó tem sua própria trilha colorida com cálculos de distância entre pontos.';

  @override
  String get helpPositionExportBubble =>
      '**Exporte como CSV** pelo menu para análise em planilhas ou ferramentas GIS. Ótimo para documentar testes de cobertura!';

  @override
  String get helpPositionGoodFixBubble =>
      'O filtro **Fix bom** mostra apenas posições com 6+ satélites. Isso ajuda a ignorar fixes imprecisos internos e focar em dados externos confiáveis.';

  @override
  String get helpSettingsIntroBubble =>
      'Bem-vindo às **Configurações**! Aqui você pode personalizar tudo sobre seu app e dispositivo conectado.';

  @override
  String get helpSettingsDeviceBubble =>
      'As **configurações do dispositivo** permitem configurar seu rádio Meshtastic — nome, região, níveis de potência e módulos!';

  @override
  String get helpSettingsAppBubble =>
      'As **configurações do app** controlam temas, notificações, opções de privacidade e o comportamento do app.';

  @override
  String get helpSettingsCloudBubble =>
      '**Cloud Sync** é uma assinatura premium que sincroniza seu **NodeDex**, **automações**, **widgets** e **perfil** em todos os seus dispositivos. Também serve como **backup** — se você apagar o app ou trocar de celular, o Cloud Sync restaura tudo. Sem ele, todos os dados ficam apenas neste dispositivo e são perdidos se o app for removido.';

  @override
  String get helpProfileIntroBubble =>
      'Este é o **seu perfil**! Personalize sua identidade mesh com nome de exibição, indicativo e avatar.';

  @override
  String get helpProfileCustomizeBubble =>
      'Seu perfil é **opcional e privado por padrão**. Personalize-o para se destacar na mesh!';

  @override
  String get helpProfileShareBubble =>
      'Adicione um **indicativo**, um **avatar** e **links** para personalizar seu perfil.';

  @override
  String get helpProfileCloudBubble =>
      '**Cloud Sync** é um recurso premium que faz backup do seu perfil, NodeDex, automações e widgets na nuvem. Protege seus dados — se você apagar o app ou trocar de celular, tudo é **restaurado automaticamente** quando você fizer login novamente. Sem ele, seus dados existem apenas neste dispositivo.';

  @override
  String get helpMesh3dIntroBubble =>
      'Bem-vindo ao **Mesh 3D**! Veja toda a sua rede em três dimensões. Arraste para girar, belisque para dar zoom!';

  @override
  String get helpMesh3dNodesBubble =>
      'Cada esfera é um **nó**. As linhas mostram conexões baseadas na intensidade do sinal. Mais perto = sinal mais forte!';

  @override
  String get helpMesh3dColorsBubble =>
      'As cores mostram a **saúde do nó**. Verde = ativo, amarelo = enfraquecendo, cinza = inativo. O status é inferido do último contato.';

  @override
  String get helpMesh3dTapBubble =>
      '**Toque em qualquer nó** para selecioná-lo e ver detalhes. Ótimo para entender a topologia da sua rede!';

  @override
  String get helpGlobeIntroBubble =>
      'Gire o **Globo** para ver sua mesh do espaço! Cada ponto brilhante é um nó com coordenadas GPS.';

  @override
  String get helpGlobeInteractBubble =>
      '**Arraste para girar**, belisque para dar zoom. Toque em um nó para voar até sua localização e ver detalhes!';

  @override
  String get helpGlobeArcsBubble =>
      'Observe os **arcos de conexão** — eles mostram caminhos de mensagens viajando pela mesh em tempo real!';

  @override
  String get helpTimelineIntroBubble =>
      'A **Timeline** mostra tudo acontecendo na sua mesh. Mensagens, mudanças de nós, telemetria — tudo em ordem!';

  @override
  String get helpTimelineFilterBubble =>
      'Use **filtros** para focar em tipos de eventos específicos. Só mensagens? Apenas entradas de nós? Você controla a visualização!';

  @override
  String get helpTimelineTapBubble =>
      '**Toque em qualquer evento** para ver todos os detalhes. Ótimo para depuração ou para entender o que está acontecendo na rede!';

  @override
  String get helpShopIntroBubble =>
      'Bem-vindo à **Loja de dispositivos**! Navegue por rádios e acessórios compatíveis com Meshtastic.';

  @override
  String get helpShopCompareBubble =>
      '**Compare dispositivos** por alcance, bateria e recursos. Avaliei cada um para ajudar você a escolher!';

  @override
  String get helpShopLinksBubble =>
      'Toque em **Comprar** para visitar vendedores confiáveis. Preços e disponibilidade mostrados são de lojas reais!';

  @override
  String get helpOfflineIntroBubble =>
      'Os **Mapas offline** permitem usar o mapa sem internet! Essencial para aventuras fora da rede.';

  @override
  String get helpOfflineDownloadBubble =>
      '**Selecione uma região** e nível de zoom, depois toque em baixar. Vou salvar todos os tiles do mapa no seu dispositivo!';

  @override
  String get helpOfflineManageBubble =>
      'Gerencie seus downloads aqui — veja o armazenamento usado e **exclua** regiões antigas que não precisa mais.';

  @override
  String get helpRadioIntroBubble =>
      'As **configurações de rádio** controlam como seu dispositivo transmite. Região, potência e preset de modem são fundamentais!';

  @override
  String get helpRadioRegionBubble =>
      'Sua **região** determina as frequências legais. Configurar errado pode causar interferência com outros serviços!';

  @override
  String get helpRadioModemBubble =>
      'O **preset do modem** equilibra alcance e velocidade. Longo alcance = mais lento mas mais longe. Curto-rápido = rápido mas mais perto.';

  @override
  String get helpRadioPowerBubble =>
      'Maior **potência TX** significa mais alcance mas usa mais bateria. Encontre o equilíbrio ideal para suas necessidades!';

  @override
  String get helpPresenceIntroBubble =>
      '**Presença** mostra quais nós estão ativos, vistos recentemente ou inativos na sua rede mesh.';

  @override
  String get helpPresenceActiveBubble =>
      'Nós **online** (verde) foram ouvidos nas últimas 2 horas — correspondendo à definição de online do firmware Meshtastic.';

  @override
  String get helpPresenceRecentBubble =>
      'Nós **vistos recentemente** (amarelo) foram ouvidos há poucos minutos. Provavelmente ainda presentes.';

  @override
  String get helpPresenceInactiveBubble =>
      'Nós **offline** (cinza) não foram ouvidos há mais de 2 horas. Podem estar fora de alcance ou desligados.';

  @override
  String get helpPresenceChartBubble =>
      'O **gráfico de atividade** mostra a atividade recente dos nós ao longo do tempo. Veja a mesh ganhar vida!';

  @override
  String get helpReachabilityIntroBubble =>
      '**Alcançabilidade** estima a probabilidade de alcançar cada nó. Baseia-se em dados mesh observados passivamente.';

  @override
  String get helpReachabilityBetaBubble =>
      'Isto está em **BETA** — não enviamos pacotes de teste! Tudo é estimado a partir de mensagens que vemos fluindo pela mesh.';

  @override
  String get helpReachabilityHighBubble =>
      'Alcançabilidade **alta** (brilhante) significa que vimos muita comunicação com aquele nó. As mensagens provavelmente chegarão!';

  @override
  String get helpReachabilityMediumBubble =>
      'Alcançabilidade **média** (menos brilhante) significa alguma comunicação mas não consistente. As mensagens podem chegar.';

  @override
  String get helpReachabilityLowBubble =>
      'Alcançabilidade **baixa** (muito tênue) significa que raramente vemos comunicação. O nó pode estar muito longe ou atrás de obstáculos.';

  @override
  String get helpHealthIntroBubble =>
      '**Saúde da mesh** monitora sua rede para problemas como congestionamento, perda de pacotes e nós problemáticos.';

  @override
  String get helpHealthStatusBubble =>
      'O **indicador de status** mostra a saúde geral da mesh. Verde = saudável, amarelo = problemas detectados, vermelho = problemas críticos.';

  @override
  String get helpHealthMetricsBubble =>
      'As **métricas** mostram contagens de pacotes, retransmissões e contagens de hops. Atenção a taxas de retransmissão altas!';

  @override
  String get helpHealthUtilizationBubble =>
      'O **gráfico de utilização** mostra quão ocupada sua mesh está ao longo do tempo. Picos podem indicar problemas.';

  @override
  String get helpHealthIssuesBubble =>
      'A seção **Problemas** destaca problemas específicos e sugere correções. Verifique aqui se as coisas parecem lentas!';

  @override
  String get helpHealthMonitoringBubble =>
      'Use o botão **pausar** para parar o monitoramento e economizar bateria. Pressione **resetar** para limpar os dados e recomeçar!';

  @override
  String get helpTracerouteIntroBubble =>
      '**Traceroute** descobre o caminho real dos seus pacotes para alcançar outro nó. Revela quais relays estão encaminhando seus dados.';

  @override
  String get helpTracerouteHowBubble =>
      'Quando você envia um traceroute, cada relay no caminho se adiciona ao pacote. O destino o envia de volta para que você veja **ambas as direções**.';

  @override
  String get helpTracerouteSendBubble =>
      'Envie um traceroute da **ficha de detalhes do nó** (toque no ícone de rota) ou das **Ações rápidas do Dashboard** onde você pode escolher qualquer nó conhecido.';

  @override
  String get helpTracerouteCooldownBubble =>
      'Há um **intervalo de 30 segundos** entre traceroutes para respeitar a equidade do tempo de ar. Uma contagem regressiva visível mostra o tempo restante.';

  @override
  String get helpTracerouteResultsBubble =>
      'Os resultados mostram caminhos de hops de **ida** e **volta** com **SNR** (relação sinal-ruído) por hop. Isso permite correlacionar a qualidade da rota com o desempenho do link.';

  @override
  String get helpTracerouteHistoryBubble =>
      'Todos os traceroutes são salvos no **Histórico de traceroute** (Configurações > Logs de telemetria). Filtre por status de resposta, pesquise por nome do nó e compare execuções ao longo do tempo.';

  @override
  String get helpTracerouteExportBubble =>
      'Exporte seu histórico de traceroute como **CSV** para análise de tendências ou documentação. Use o menu na tela de histórico.';

  @override
  String get helpTracerouteTipsBubble =>
      '**Dica:** Execute traceroutes após reposicionar nós, trocar antenas ou ajustar canais para validar suas mudanças com dados de rota reais!';

  @override
  String get helpNodedexIntroBubble =>
      'Bem-vindo ao **NodeDex** — seu diário de campo da mesh! Cada nó descoberto é registrado aqui com um **Sigil** único e um **Traço** de personalidade.';

  @override
  String get helpNodedexSigilsBubble =>
      'Cada nó tem um **Sigil procedural** — um glifo geométrico gerado a partir de sua identidade. Nenhum nó compartilha o mesmo sigil. Pense nele como uma impressão digital visual da mesh!';

  @override
  String get helpNodedexTraitsBubble =>
      'Os nós ganham **Traços** baseados no comportamento real — **Andarilho** se move entre regiões, **Farol** está sempre online, **Fantasma** é raramente visto, **Sentinela** mantém posição fixa, **Relay** encaminha tráfego.';

  @override
  String get helpNodedexFiltersBubble =>
      'Use os **chips de filtro** para mostrar apenas traços específicos, nós descobertos recentemente ou nós que você marcou. A **barra de pesquisa** encontra nós por nome ou ID hexadecimal.';

  @override
  String get helpNodedexFieldJournalBubble =>
      'Conforme você observa mais nós, seu **diário de campo** se preenche — cada nó ganha uma **pontuação Patina** e um **overlay de identidade** baseado em encontros reais. Quanto mais observar, mais ricos os detalhes!';

  @override
  String get helpNodedexAlbumModeBubble =>
      'Toque no **alternador de visualização** na barra do app para mudar para o **modo Álbum** — uma grade de cards colecionáveis agrupados por traço, raridade ou região. Cada card mostra o sigil do nó com um brilho holográfico baseado na raridade!';

  @override
  String get helpNodedexAtmosphereBubble =>
      'Notou as sutis **partículas ambientais** atrás da tela? É a **Atmosfera Elemental** — chuva, brasas, névoa e luz estelar guiadas pelos seus dados mesh reais. Mais nós e atividade significam mais atmosfera!';

  @override
  String get helpNodedexCloudSyncBubble =>
      'Seu NodeDex é armazenado localmente em SQLite e sobrevive a reinicializações do app — mas **não** à desinstalação. Se você desinstalar o app ou trocar de celular, o NodeDex local é perdido. Com uma assinatura **Cloud Sync**, todo o diário — sigils, encontros, tags sociais, notas e links co-seen — é salvo na nuvem e **restaurado automaticamente** em qualquer dispositivo em que você fizer login.';

  @override
  String get helpNodedexExportBubble =>
      'Use o **menu** para **exportar** seu NodeDex como arquivo JSON para backup, ou **importar** um de outro dispositivo. Seu diário de campo viaja com você — mesmo sem Cloud Sync!';

  @override
  String get helpNodedexSigilBubble =>
      'Este é o **Sigil** do nó — um glifo procedural único gerado a partir de sua identidade. Nenhum nó compartilha o mesmo sigil. É como uma impressão digital visual!';

  @override
  String get helpNodedexTraitBubble =>
      'O **Traço** é uma personalidade inferida do comportamento do nó — padrões de movimento, consistência de sinal, frequência de encontros. A confiança cresce com mais dados.';

  @override
  String get helpNodedexAutoSummaryBubble =>
      'O **Resumo automático** calcula insights do histórico de encontros — distribuição por horário, sequências de observação e padrões dos dias mais movimentados. Tudo se atualiza automaticamente com novos encontros.';

  @override
  String get helpNodedexObservationTimelineBubble =>
      'A **Timeline de observações** visualiza a densidade de encontros deste nó ao longo do tempo, com rótulos relativos mostrando quão recentemente cada observação foi registrada.';

  @override
  String get helpNodedexDiscoveryBubble =>
      'As **estatísticas de descoberta** mostram quando você viu este nó pela primeira e última vez, quantos encontros teve e a menor distância registrada. Atualizam-se automaticamente.';

  @override
  String get helpNodedexSignalBubble =>
      'Os **registros de sinal** rastreiam os melhores e mais recentes valores de SNR e RSSI. Ajudam a entender a qualidade do link — SNR mais alto e RSSI menos negativo significam sinais mais fortes.';

  @override
  String get helpNodedexSocialTagBubble =>
      'A **Tag social** é um rótulo que você atribui para categorizar este nó — amigo, relay, estação base ou qualquer outra coisa. São seus metadados pessoais, nunca compartilhados na mesh.';

  @override
  String get helpNodedexNoteBubble =>
      'Sua **nota** é um campo de texto livre para qualquer coisa que você queira lembrar sobre este nó. Dicas de localização, nome do operador, tipo de antena — o que for útil.';

  @override
  String get helpNodedexRegionsBubble =>
      'O **histórico de regiões** registra cada região regulatória onde este nó foi observado. Útil para rastrear nós móveis em diferentes áreas.';

  @override
  String get helpNodedexEncountersBubble =>
      'Os **encontros recentes** são uma timeline de quando este nó apareceu na sua mesh. Cada entrada mostra timestamp, qualidade do sinal e distância se o GPS estava disponível.';

  @override
  String get helpNodedexActivityTimelineBubble =>
      'A **Timeline de atividades** é um feed cronológico unificado de tudo observado sobre este nó — encontros, mensagens, mudanças de presença, sinais e marcos.';

  @override
  String get helpNodedexCoseenBubble =>
      'Os **Links co-seen** mostram nós frequentemente observados na mesma sessão que este. Toque em qualquer link para ver o relacionamento completo — encontros compartilhados, contagem de mensagens e força da conexão.';

  @override
  String get helpNodedexDeviceBubble =>
      'As **informações do dispositivo** mostram telemetria em tempo real — nível de bateria, modelo de hardware, versão de firmware e uptime. Esses dados vêm diretamente do nó e se atualizam em tempo real.';

  @override
  String get helpAlbumIntroBubble =>
      'Bem-vindo ao **Álbum de coleção** — uma visualização de cards colecionáveis do seu NodeDex! Cada nó descoberto se torna um card com sigil, traço e nível de raridade.';

  @override
  String get helpAlbumCoverBubble =>
      'A **capa do álbum** é seu painel — mostra seu **título de Explorador**, total de nós, encontros, regiões exploradas e barra de distribuição de raridade. Veja sua coleção crescer!';

  @override
  String get helpAlbumGroupingBubble =>
      'Use os **chips de agrupamento** para organizar cards por **Traço** (Farol, Relay, Fantasma...), **Raridade** (de Comum a Lendário) ou **Região** (área geográfica). Cada grupo tem sua própria página no álbum.';

  @override
  String get helpAlbumRarityBubble =>
      'Os cards ganham **níveis de raridade** baseados na contagem de encontros e traço. Nós **Comuns** são recém-vistos, enquanto cards **Lendários** combinam traços raros com histórico profundo de observação. A raridade determina o brilho da borda e o efeito holográfico!';

  @override
  String get helpAlbumInteractionsBubble =>
      '**Toque** em um card para abrir o perfil completo do nó. **Pressione longo** para abrir a **Galeria de cards** — um carrossel em tela cheia onde você pode deslizar entre cards e tocar para virá-los e ver estatísticas!';

  @override
  String get helpAlbumGalleryBubble =>
      'Na **Galeria de cards**, deslize para a esquerda e direita para navegar. **Toque** em um card para virá-lo — o verso mostra estatísticas de descoberta, registros de sinal, contagem de encontros e pontuação patina. Deslize para baixo para fechar.';

  @override
  String get helpAlbumHolographicBubble =>
      'Cards de maior raridade brilham com um **efeito holográfico** — quanto mais raro o card, mais intenso o brilho. Este efeito respeita a configuração **reduzir movimento** e usa um painter otimizado para miniaturas na grade.';

  @override
  String get helpAlbumPersistenceBubble =>
      'Sua preferência de visualização do álbum e escolha de agrupamento são **salvas automaticamente**. Com **Cloud Sync**, toda a coleção — sigils, encontros, tags, notas — é salva e sincronizada em todos os seus dispositivos. Apague o app, troque de celular — sua coleção está segura e restaura ao fazer login.';

  @override
  String get helpConstellationIntroBubble =>
      'Bem-vindo à **Constelação** — um mapa estelar da sua rede mesh! Os nós aparecem como estrelas, e as linhas entre eles mostram **relações co-seen** — nós observados na mesma sessão.';

  @override
  String get helpConstellationLayoutBubble =>
      'O layout é **dirigido por forças** — nós frequentemente co-seen se agrupam, enquanto nós isolados se afastam para as bordas. O grafo estabiliza após um momento para que nada se mova enquanto você explora.';

  @override
  String get helpConstellationInteractionsBubble =>
      '**Toque** em um nó para destacar suas conexões. **Toque duplo** para dar zoom em um cluster. **Pressione longo** para abrir o perfil completo do nó. **Belisque** para ampliar e reduzir o mapa estelar.';

  @override
  String get helpConstellationEdgesBubble =>
      'Use o botão **densidade de arestas** na barra do app para controlar quantas conexões são mostradas. **Esparsas** mostra apenas os links mais fortes, **Todas** mostra tudo. A densidade ideal depende do tamanho da rede.';

  @override
  String get helpConstellationSearchBubble =>
      'O ícone **pesquisar** permite encontrar um nó específico por nome ou ID hexadecimal. A visualização automaticamente amplia e centraliza o nó correspondente com uma animação pulsante.';

  @override
  String get helpConstellationAtmosphereBubble =>
      'A constelação tem sua própria **Atmosfera Elemental** — sutis partículas estelares e névoa atrás do grafo, guiadas pelos seus dados mesh reais. Nunca obstrui a visualização.';

  @override
  String get helpConstellationDataBubble =>
      'Os dados co-seen são construídos **automaticamente** a partir dos seus encontros. Quanto mais sessões observar, mais rica a constelação se torna. Todos os dados relacionais são armazenados localmente — mas são **perdidos se você apagar o app**. Com **Cloud Sync**, toda a constelação é salva e restaurada em qualquer dispositivo em que você fizer login.';

  @override
  String get helpCloudSyncIntroBubble =>
      '**Cloud Sync** é uma assinatura premium que mantém seus dados mesh sincronizados em todos os dispositivos — e serve como **backup**. Sem ele, todos os dados ficam apenas no dispositivo e são perdidos permanentemente se você apagar o app ou perder o celular.';

  @override
  String get helpCloudSyncWhatSyncsBubble =>
      'O Cloud Sync faz backup do seu **NodeDex** (sigils, encontros, tags sociais, notas, links co-seen), **automações**, **widgets personalizados** e **perfil**. Reinstale o app, troque de celular ou faça login em um segundo dispositivo — toda a sua identidade mesh é restaurada automaticamente.';

  @override
  String get helpCloudSyncOfflineFirstBubble =>
      'O app é **offline-first**. As alterações são salvas localmente no SQLite imediatamente e enfileiradas em uma **outbox**. Quando você estiver online, a outbox é esvaziada automaticamente para a nuvem — sem sincronização manual necessária.';

  @override
  String get helpCloudSyncConflictBubble =>
      'Se você editar o mesmo nó em dois dispositivos, o Cloud Sync usa resolução de conflitos **last-write-wins** com timestamps por campo. Tags sociais e notas são resolvidas independentemente para que você nunca perca ambas as edições.';

  @override
  String get helpCloudSyncSubscriptionBubble =>
      'O Cloud Sync está disponível como assinatura **mensal** ou **anual**. Você pode assinar em **Configurações > Conta e assinatura**. Assinaturas canceladas continuam funcionando até o fim do período de cobrança.';

  @override
  String get helpCloudSyncWithoutBubble =>
      'Sem o Cloud Sync, todos os seus dados ficam apenas no dispositivo. Sobrevivem a reinicializações do app, mas **não** à desinstalação ou reset do celular. Você pode **exportar** o NodeDex como JSON para backup manual. O Cloud Sync automatiza isso e adiciona restauração multi-dispositivo — mas o app funciona totalmente offline sem ele.';

  @override
  String get helpAetherIntroBubble =>
      '**Aether** permite rastrear nós Meshtastic em altitude! A 10.000 m, sinais LoRa podem alcançar **mais de 400 km** — muito além do alcance típico ao nível do solo.';

  @override
  String get helpAetherScheduleBubble =>
      '**Agende um voo** antes de voar. Insira o número do voo, aeroportos, horário de partida e o ID do seu nó. Outros entusiastas de mesh podem acompanhar sua jornada e tentar receber seu sinal.';

  @override
  String get helpAetherActiveBubble =>
      'Os **voos ativos** mostram dados de posição em tempo real da API OpenSky Network. Você verá altitude, velocidade, direção e raio de cobertura estimado baseado em cálculos de horizonte de rádio.';

  @override
  String get helpAetherReportsBubble =>
      'Os **relatórios de recepção** permitem que estações terrestres reportem quando recebem seu sinal. Os relatórios incluem distância, RSSI e SNR. Todos são salvos no **ranking global**.';

  @override
  String get helpAetherLeaderboardBubble =>
      'O **ranking é global e permanente** — armazenado na nuvem, não no seu dispositivo. As posições sobrevivem a reinstalações do app e são visíveis para toda a comunidade Socialmesh. Os 3 primeiros recebem ouro, prata e bronze!';

  @override
  String get helpAetherTipsBubble =>
      '**Dicas**: Assentos na janela ajudam. Desligue brevemente o modo avião durante a altitude de cruzeiro (onde permitido). Estações terrestres com antenas elevadas têm mais chances. Boa sorte!';

  @override
  String get helpTakIntroBubble =>
      '**TAK Gateway** conecta sua mesh ao ecossistema Team Awareness Kit (TAK). Ele transmite entidades **Cursor-on-Target** ao vivo de um servidor TAK diretamente no seu mapa.';

  @override
  String get helpTakConnectBubble =>
      'Toque no **ícone de link** na barra do app para conectar ou desconectar. O card de status mostra a URL do gateway, o tempo de conexão e o total de eventos recebidos.';

  @override
  String get helpTakAffiliationsBubble =>
      'Cada entidade é colorida pela **afiliação padrão** — azul para amigo, vermelho para hostil, verde para neutro, amarelo para desconhecido. O ícone muda por dimensão também: terra, ar, mar ou espaço.';

  @override
  String get helpTakFilterBubble =>
      'Use os **chips de filtro** para restringir a lista por afiliação, ou digite um indicativo na **barra de pesquisa**. O chip stale alterna entre todos, apenas ativos e apenas stale.';

  @override
  String get helpTakDetailBubble =>
      'Toque em qualquer entidade para abrir a **tela de detalhes** — campos CoT completos, coordenadas, velocidade, curso e XML bruto. Use o ícone do mapa para ir direto à sua posição no mapa.';

  @override
  String get helpTakTrackingBubble =>
      '**Pressione longo** em um tile de entidade para ativar o rastreamento. Entidades rastreadas são destacadas no mapa e permanecem visíveis mesmo quando a tela TAK está fechada.';

  @override
  String get helpTakSettingsBubble =>
      'Abra as **configurações TAK** pelo menu para alterar a URL do gateway, ativar conexão automática e ajustar o timeout de stale. Todas as configurações persistem entre sessões.';

  @override
  String get helpRadioResponsibilityBubble =>
      '**Você** é responsável por garantir que seu equipamento de rádio é legal no seu país e que opera dentro das faixas de frequência e limites de potência permitidos.';

  @override
  String get helpRadioLicenceBubble =>
      'Algumas regiões exigem uma **licença de radioamador** antes de poder transmitir. Verifique com sua autoridade reguladora local — ex. ACMA na Austrália ou FCC nos EUA.';

  @override
  String get helpRadioInterferenceBubble =>
      'Nunca interfira com **comunicações de emergência** ou serviços licenciados. Violações podem resultar em multas ou penalidades criminais.';

  @override
  String get helpRadioTermsLinkBubble =>
      'Para detalhes completos, consulte a seção **Rádio e conformidade legal** nos nossos Termos de Serviço. Você encontra em Configurações sob Termos de Serviço.';

  @override
  String get helpUseIntroBubble =>
      'Socialmesh é uma ferramenta poderosa — automações, sinais e mensagens mesh dão muita capacidade. Com isso vem a responsabilidade!';

  @override
  String get helpUseLawfulBubble =>
      'Use o app apenas para **fins lícitos**. Não transmita conteúdo prejudicial, ameaçador ou abusivo pela rede mesh.';

  @override
  String get helpUseAutomationsBubble =>
      'Automações são ótimas para alertas e notificações, mas não as use para **spammar a mesh** ou inundar outros usuários com mensagens indesejadas.';

  @override
  String get helpUseImpersonationBubble =>
      'Não **se passe** por outras pessoas ou entidades na rede mesh. Seja você mesmo!';

  @override
  String get helpUseTermsLinkBubble =>
      'A lista completa de atividades proibidas está na seção **Uso do serviço** dos nossos Termos. Você pode consultá-la a qualquer momento nas Configurações.';

  @override
  String get helpResponsibilityIntroBubble =>
      'Socialmesh é projetado para ser **privacidade em primeiro lugar**. Suas mensagens e dados ficam no seu dispositivo — não os armazenamos em nenhum servidor.';

  @override
  String get helpResponsibilitySignalsBubble =>
      'Quando você cria um **Sinal**, ele é transmitido pela rede mesh. Qualquer pessoa ao alcance pode recebê-lo. Pense nele como uma transmissão de rádio pública.';

  @override
  String get helpResponsibilityContentBubble =>
      'Você é responsável por **tudo que transmite**. Não compartilhe informações pessoais, dados sensíveis ou conteúdo que possa prejudicar outros.';

  @override
  String get helpResponsibilityThirdPartyBubble =>
      'Alguns recursos usam **serviços de terceiros** como RevenueCat para compras e Firebase para relatórios de crash. Estes têm suas próprias políticas de privacidade.';

  @override
  String get helpResponsibilityTermsLinkBubble =>
      'Para detalhes completos, consulte nossos **Termos de Serviço** e **Política de Privacidade** nas Configurações. Eles explicam exatamente quais dados ficam locais e quais são compartilhados.';

  @override
  String get helpFtIntroBubble =>
      'A **Transferência de arquivos** permite enviar pequenos arquivos — texto, configs, coordenadas — diretamente via rádio LoRa. Sem internet, sem servidores.';

  @override
  String get helpFtHowBubble =>
      'Os arquivos são divididos em **blocos de ~200 bytes** e enviados um de cada vez pela mesh. O receptor os remonta automaticamente.';

  @override
  String get helpFtNackBubble =>
      'Perdeu um bloco? Sem problema. O receptor envia um **NACK** (confirmação negativa) para solicitar a retransmissão exata das peças faltantes.';

  @override
  String get helpFtLimitBubble =>
      'Os arquivos são limitados a **8 KB**. LoRa é um rádio lento, compartilhado e de baixa potência — uma única transferência pode ocupar o canal por até um minuto em configurações de longo alcance.';

  @override
  String get helpFtBetaBubble =>
      'Este recurso está em **BETA**. Ambos os nós devem estar executando Socialmesh no mesmo canal mesh. Nós Meshtastic padrão não podem receber estas transferências.';

  @override
  String get helpFtContactsBubble =>
      'Use a aba **Contatos** para escolher um nó, depois toque em **Enviar arquivo**. A aba Contatos mostra cada nó que seu dispositivo viu na mesh.';

  @override
  String get helpFtlSharedBubble =>
      'Os canais LoRa são **compartilhados e lentos**. Cada byte que você envia é tempo de ar tirado de todos os outros nós no alcance. Trate como uma frequência de walkie-talkie, não como WiFi.';

  @override
  String get helpFtlToaBubble =>
      'O **tempo no ar** por bloco depende do Spreading Factor (SF). SF7 (rápido, curto alcance): ~30 ms/bloco. SF12 (lento, longo alcance): ~1.500 ms/bloco.';

  @override
  String get helpFtlMathBubble =>
      '8 KB ÷ 200 bytes/bloco = **41 blocos**. Em SF7: ~1,2 segundos totais. Em SF12: **~62 segundos** de transmissão de rádio contínua.';

  @override
  String get helpFtlDutyBubble =>
      'EU868 e bandas similares impõem um **duty cycle de 1%** — seu rádio só pode transmitir por 36 segundos por hora. Em SF12, uma transferência de 8 KB quase esgota todo esse orçamento.';

  @override
  String get helpFtlCapBubble =>
      '8 KB é o **limite mais seguro** que mantém as transferências viáveis nos piores spreading factors sem violar regulações de duty cycle ou bloquear a mesh por minutos.';

  @override
  String get helpFtlUsbBubble =>
      'Transferências por BLE e USB não implicam risco de duty cycle de rádio. Em uma versão futura, limites maiores serão desbloqueados para conexões cabeadas diretas.';

  @override
  String get helpNodeDexSectionSigil =>
      'Um glifo procedural único gerado a partir da identidade deste nó. ';

  @override
  String get helpNodeDexSectionTrait =>
      'Um arquétipo de personalidade inferido de sinais comportamentais: ';

  @override
  String get helpNodeDexSectionAutoSummary =>
      'Insights calculados do histórico de encontros deste nó. A distribuição por horário ';

  @override
  String get helpNodeDexSectionObservationTimeline =>
      'Uma timeline visual do histórico de observações deste nó. A barra mostra ';

  @override
  String get helpNodeDexSectionDiscovery =>
      'Rastreia quando este nó foi visto pela primeira e última vez na mesh, o total ';

  @override
  String get helpNodeDexSectionSignal =>
      'Melhores e mais recentes valores de SNR (relação sinal-ruído) e RSSI ';

  @override
  String get helpNodeDexSectionSocialTag =>
      'Um rótulo pessoal que você atribui para categorizar este nó. Tags sociais são ';

  @override
  String get helpNodeDexSectionNote =>
      'Uma nota de texto livre para qualquer coisa que você queira lembrar sobre este nó. ';

  @override
  String get helpNodeDexSectionRegions =>
      'Cada região regulatória onde este nó foi observado. A região ';

  @override
  String get helpNodeDexSectionEncounters =>
      'Uma timeline cronológica de quando este nó apareceu na sua mesh. ';

  @override
  String get helpNodeDexSectionActivityTimeline =>
      'Um feed cronológico unificado de tudo observado sobre este nó: ';

  @override
  String get helpNodeDexSectionCoseen =>
      'Nós frequentemente observados na mesma sessão que este nó. ';

  @override
  String get helpNodeDexSectionDevice =>
      'Telemetria em tempo real do nó: porcentagem de bateria, modelo de hardware, ';

  @override
  String get helpNodeDexSectionAlbumRarity =>
      'Os níveis de raridade são calculados pela contagem de encontros e traço inferido. ';

  @override
  String get helpNodeDexSectionAlbumGrouping =>
      'Os cards podem ser agrupados por Traço (arquétipo comportamental), Raridade ';

  @override
  String get helpNodeDexSectionAlbumExplorerTitle =>
      'Seu título de Explorador reflete o progresso geral da sua coleção. ';

  @override
  String get helpNodeDexSectionAlbumHolographic =>
      'O brilho holográfico nos cards é um indicador visual de raridade. ';

  @override
  String get helpNodeDexSectionAlbumPatina =>
      'Patina é uma pontuação composta que reflete quão profundamente você observou ';

  @override
  String get helpNodeDexSectionAlbumCloudSync =>
      'Com uma assinatura Cloud Sync, todo o álbum NodeDex é salvo ';

  @override
  String get helpTakSectionStatus =>
      'O card de status mostra se a conexão WebSocket com o TAK ';

  @override
  String get helpTakSectionAffiliation =>
      'A afiliação descreve o relacionamento de uma entidade com ';

  @override
  String get helpTakSectionCotType =>
      'A string do tipo CoT codifica a afiliação, dimensão, ';

  @override
  String get helpTakSectionIdentity =>
      'O UID identifica exclusivamente esta entidade em todas as mensagens CoT. ';

  @override
  String get helpTakSectionPosition =>
      'Latitude e longitude em graus decimais WGS-84 conforme reportado no ';

  @override
  String get helpTakSectionMotion =>
      'Velocidade, curso e altitude extraídos do rastreamento e ';

  @override
  String get helpTakSectionTimestamps =>
      'A hora do evento é quando o evento CoT foi gerado. A hora de expiração é quando ';

  @override
  String get helpTakSectionTracking =>
      'Entidades rastreadas são fixadas e destacadas no mapa com um ';

  @override
  String get helpTakSectionRawPayload =>
      'O payload JSON bruto conforme recebido do WebSocket do TAK Gateway. ';

  @override
  String get helpTakSectionFilters =>
      'Os chips de filtro permitem restringir a lista de entidades por afiliação. O ';

  @override
  String get helpTakSectionSettings =>
      'As configurações TAK permitem configurar a URL do gateway, ativar conexão automática ';

  @override
  String get accessRestrictedTitle => 'Acesso restrito';

  @override
  String get goBack => 'Voltar';

  @override
  String get deviceNotConnected => 'Dispositivo não conectado';

  @override
  String get connectDevice => 'Conectar dispositivo';

  @override
  String get connectDeviceToUseFeature =>
      'Conecte o dispositivo para usar este recurso';

  @override
  String positionRequestedFrom(String name) {
    return 'Posição solicitada de $name';
  }

  @override
  String failedGeneric(String error) {
    return 'Falha: $error';
  }

  @override
  String failedToUpdateSignalLocationRadius(String error) {
    return 'Falha ao atualizar o raio de localização do sinal: $error';
  }

  @override
  String failedToSaveConfiguration(String error) {
    return 'Falha ao salvar a configuração: $error';
  }

  @override
  String automationActionError(int index, String error) {
    return 'Ação $index: $error';
  }

  @override
  String failedToPlay(String error) {
    return 'Falha ao reproduzir: $error';
  }

  @override
  String get whatsNewVersion190Subtitle => 'Versão 1.9.0';

  @override
  String get whatsNewReachabilityTitle => 'Alcançabilidade';

  @override
  String get whatsNewReachabilityDescription =>
      'Estime a probabilidade de alcançar cada nó na mesh — sem enviar um único pacote de teste.\\n\\nA alcançabilidade observa passivamente o tráfego na rede e atribui confiança Alta, Média ou Baixa a cada nó. Encontre no menu sob Mesh.';

  @override
  String get whatsNewVersion1100Subtitle => 'Versão 1.10.0';

  @override
  String get whatsNewWorldMapTitle => 'Mapa mundial';

  @override
  String get whatsNewWorldMapDescription =>
      'Veja toda a rede Meshtastic global em um único mapa. Cada ponto é um nó compartilhando sua localização — amplie, navegue e toque para explorar detalhes do nó, info de hardware e último contato.\\n\\nSem necessidade de conexão. O Mapa Mundial usa dados em tempo real do backend Socialmesh para explorar a mesh em qualquer lugar.';

  @override
  String get whatsNewVersion1101Subtitle => 'Versão 1.10.1';

  @override
  String get whatsNewPresenceTitle => 'Presença';

  @override
  String get whatsNewPresenceDescription =>
      'Veja quem está ativo na mesh de relance. Presença mostra atividade de nós em tempo real com indicadores de intenção — se alguém está monitorando, em movimento ou em uma estação base fixa.\\n\\nFiltre por nível de atividade, pesquise por nome e toque em qualquer nó para ver o perfil completo. Encontre no menu sob Social.';

  @override
  String get whatsNewVersion1110Subtitle => 'Versão 1.11.0';

  @override
  String get whatsNewSignalsTitle => 'Sinais';

  @override
  String get whatsNewSignalsDescription =>
      'Transmita momentos efêmeros para sua rede mesh. Sinais são posts de curta duração — compartilhe texto, uma foto ou sua localização com um TTL de 15 minutos até 24 horas.\\n\\nSinais próximos aparecem primeiro com badges de proximidade mostrando a contagem de hops. Quando desaparecem, se foram. Conteúdo efêmero, verdadeiramente off-grid.';

  @override
  String get whatsNewVersion1130Subtitle => 'Versão 1.13.0';

  @override
  String get whatsNewNodeDexTitle => 'NodeDex';

  @override
  String get whatsNewNodeDexDescription =>
      'Um diário de campo vivo do mundo mesh. Cada nó que você descobre é registrado automaticamente com um Sigil procedural único e um Traço de personalidade derivado do comportamento real.\\n\\nEncontre no menu lateral em Social. Filtre por traço, pesquise por nome ou ID hexadecimal e toque em qualquer entrada para explorar o perfil completo — histórico de sinal, cronologia de descoberta e mais.';

  @override
  String get whatsNewVersion1150Subtitle => 'Versão 1.15.0';

  @override
  String get whatsNewAetherTitle => 'Aether';

  @override
  String get whatsNewAetherDescription =>
      'Rastreie nós Meshtastic em altitude! Agende seu voo com seu nó mesh e deixe que estações terrestres ao redor do mundo captem seu sinal.\\n\\nA 35.000 pés, LoRa pode alcançar mais de 400 km. Reporte recepções, compita no ranking de distância e estabeleça novos recordes de alcance. Encontre no menu lateral em Social.';

  @override
  String get whatsNewVersion1160Subtitle => 'Versão 1.16.0';

  @override
  String get whatsNewTakGatewayTitle => 'Gateway TAK';

  @override
  String get whatsNewTakGatewayDescription =>
      'Conecte sua rede mesh ao ecossistema Team Awareness Kit (TAK). O Socialmesh agora se conecta a um TAK Gateway via WebSocket e transmite entidades Cursor-on-Target ao vivo no seu mapa.\\n\\nCada entidade é colorida por afiliação padrão e recebe um ícone específico por dimensão. Filtre por afiliação, pesquise indicativos, rastreie entidades com toque longo e toque em qualquer marcador para detalhes CoT completos. Encontre no menu lateral em Mesh.';

  @override
  String get whatsNewVersion1270Subtitle => 'Version 1.27.0';

  @override
  String get whatsNewTranslationPackTitle => 'Translation Pack';

  @override
  String get whatsNewTranslationPackDescription =>
      'Translate any mesh message on demand with smart caching and privacy controls. Includes a managed translation allowance, or bring your own OpenAI API key for extended use.\n\nLong-press any message and tap Translate to see the result inline — with smart caching so repeated translations are instant. Now included in the Complete Pack.';

  @override
  String get notificationNewNodeTitle => 'Novo nó descoberto';

  @override
  String notificationNewNodeBody(String nodeName, String shortCode) {
    return '$nodeName ($shortCode) entrou na rede mesh';
  }

  @override
  String notificationBatchedNodesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new nodes discovered',
      one: '1 new node discovered',
    );
    return '$_temp0';
  }

  @override
  String get notificationAetherFlightTitle => 'Voo Aether detectado';

  @override
  String notificationDetectionSensorTitle(String sensorName, String state) {
    return '$sensorName: $state';
  }

  @override
  String notificationDetectionSensorBody(String displayName) {
    return 'De $displayName';
  }

  @override
  String notificationEntityStaleTitle(String callsign) {
    return 'Entidade obsoleta: $callsign';
  }

  @override
  String notificationProximityAlertTitle(String callsign) {
    return 'Alerta de proximidade: $callsign';
  }

  @override
  String notificationDirectMessageTitle(String senderName, String shortCode) {
    return 'Mensagem de $senderName ($shortCode)';
  }

  @override
  String notificationChannelMessageTitle(
    String senderName,
    String shortCode,
    String channelName,
  ) {
    return '$senderName ($shortCode) em $channelName';
  }

  @override
  String get notificationChannelNodeDiscovery =>
      'Notificações para nós mesh recém-descobertos';

  @override
  String get notificationChannelAetherFlights =>
      'Notificações para eventos de detecção de voos Aether';

  @override
  String get notificationChannelDeviceAlerts =>
      'Notificações importantes do seu dispositivo Meshtastic';

  @override
  String get notificationChannelDetectionSensor =>
      'Notificações para eventos do sensor de detecção';

  @override
  String get notificationChannelTakStale =>
      'Notificações quando entidades TAK rastreadas ficam obsoletas';

  @override
  String get notificationChannelTakProximity =>
      'Notificações para alertas de proximidade de entidades TAK';

  @override
  String get notificationChannelDirectMessages =>
      'Notificações para mensagens mesh diretas';

  @override
  String get notificationChannelMessages =>
      'Notificações para mensagens mesh do canal';

  @override
  String get flowNodeEvent => 'Evento';

  @override
  String get flowNodeMessageContains => 'Mensagem contém';

  @override
  String get flowNodeNodeSilent => 'Nó silencioso';

  @override
  String get flowNodeScheduled => 'Agendado';

  @override
  String get flowNodeSignalWeak => 'Sinal fraco';

  @override
  String get flowNodeChannelActivity => 'Atividade do canal';

  @override
  String get flowNodeDetectionSensor => 'Sensor de detecção';

  @override
  String get flowNodeManual => 'Manual';

  @override
  String get flowNodeAllNodes => 'Todos os nós';

  @override
  String get flowNodeNodes => 'Nós';

  @override
  String get flowNodeTraitFilter => 'Filtro de traço';

  @override
  String get flowNodeDistanceFilter => 'Filtro de distância';

  @override
  String get flowNodeEncounterFilter => 'Filtro de encontros';

  @override
  String get flowNodeOnlineFilter => 'Filtro online';

  @override
  String get flowNodeBatteryFilter => 'Filtro de bateria';

  @override
  String get flowNodeNameFilter => 'Filtro de nome';

  @override
  String get flowNodeSort => 'Ordenar';

  @override
  String get flowNodeLimit => 'Limite';

  @override
  String get flowNodeInput => 'Entrada';

  @override
  String get flowNodeFiltered => 'Filtrado';

  @override
  String get flowNodeSorted => 'Ordenado';

  @override
  String get flowNodeLimited => 'Limitado';

  @override
  String get flowNodeExecute => 'Executar';

  @override
  String get flowNodeAnd => 'E';

  @override
  String get flowNodeOr => 'OR';

  @override
  String get flowNodeNot => 'NÃO';

  @override
  String get flowNodeDelay => 'Atraso';

  @override
  String get flowNodeAllMet => 'Todos atendidos';

  @override
  String get flowNodeAnyMet => 'Qualquer atendido';

  @override
  String get flowNodeInverted => 'Invertido';

  @override
  String get flowNodeDelayed => 'Atrasado';

  @override
  String get automationTemplateLowBatteryTitle => 'Alerta de bateria fraca';

  @override
  String get automationTemplateNodeOfflineTitle => 'Alerta de nó offline';

  @override
  String get automationTemplateWeatherReportTitle => 'Relatório meteorológico';

  @override
  String get automationTemplateWeatherReportDescription =>
      'Enviar dados meteorológicos periódicos dos sensores ambientais';

  @override
  String get automationTemplateChannelMonitorTitle => 'Monitor de canal';

  @override
  String get automationTemplateChannelMonitorDescription =>
      'Registrar atividade de um canal específico';

  @override
  String get automationTemplateEmergencyBeaconTitle => 'Beacon de emergência';

  @override
  String get automationTemplateEmergencyBeaconDescription =>
      'Transmitir posição de emergência a cada 5 minutos quando acionado';

  @override
  String get automationTemplateGeofenceExitTitle =>
      'Alerta de saída do geofence';

  @override
  String get automationTemplateSosTitle => 'Resposta SOS';

  @override
  String get automationTemplateDeadManTitle => 'Interruptor de homem morto';

  @override
  String get whatsNewCtaOpenWorldMap => 'Abrir mapa mundial';

  @override
  String get whatsNewCtaOpenPresence => 'Abrir Presença';

  @override
  String get whatsNewCtaOpenNodedex => 'Abrir NodeDex';

  @override
  String get whatsNewCtaOpenAether => 'Abrir Aether';

  @override
  String get whatsNewCtaOpenReachability => 'Abrir Alcançabilidade';

  @override
  String get whatsNewCtaOpenSignals => 'Abrir Sinais';

  @override
  String get whatsNewCtaOpenTakGateway => 'Abrir TAK Gateway';

  @override
  String get whatsNewHeadline => 'Novidades no Socialmesh';

  @override
  String get connectingStatusInitializing => 'Inicializando';

  @override
  String get connectingStatusScanning => 'Procurando dispositivo';

  @override
  String get connectingStatusConnecting => 'Conectando';

  @override
  String get connectingStatusAutoReconnecting => 'Reconectando automaticamente';

  @override
  String get connectingStatusConfiguring => 'Configurando dispositivo';

  @override
  String get connectingStatusConnected => 'Conectado';

  @override
  String get connectingStatusFailed => 'Falha na conexão';

  @override
  String get profileAvatarUpdated => 'Avatar atualizado';

  @override
  String get profileAvatarRemoved => 'Avatar removido';

  @override
  String get profileBannerUpdated => 'Banner atualizado';

  @override
  String get profileBannerRemoved => 'Banner removido';

  @override
  String get commonOpenSettings => 'Abrir Configurações';

  @override
  String get socialGuidelineNoViolentImagery =>
      'Sem imagens violentas ou gráficas';

  @override
  String get globalLayerConnectionTestLabel => 'TESTE DE CONEXÃO';

  @override
  String get commonSignIn => 'Entrar';

  @override
  String get onboardingSignalContentMike =>
      'Acampamento base montado. Pronto quando quiser.';

  @override
  String get onboardingSignalContentAlex => 'A caminho, chegada em 15 min';

  @override
  String get automationErrorSendMsgNotConfigured =>
      'Callback de envio de mensagem não configurado';

  @override
  String get automationErrorNoTargetNode => 'Nenhum nó de destino especificado';

  @override
  String get automationErrorSendChannelNotConfigured =>
      'Callback de envio ao canal não configurado';

  @override
  String get automationErrorNoTargetChannel =>
      'Nenhum canal de destino especificado';

  @override
  String get automationErrorNoSoundConfigured => 'Nenhum som configurado';

  @override
  String automationErrorPlaySoundFailed(String error) {
    return 'Falha ao reproduzir som: $error';
  }

  @override
  String get automationErrorNotificationsNotInit =>
      'Notificações não inicializadas';

  @override
  String get automationErrorNoWebhookEvent =>
      'Nenhum nome de evento webhook especificado';

  @override
  String get automationErrorIftttNotConfigured =>
      'IFTTT não configurado — ative o IFTTT e defina a chave webhook nas configurações';

  @override
  String get automationErrorWebhookFailed =>
      'Falha na requisição webhook — verifique a conexão de rede';

  @override
  String get automationErrorSendMsgFailed => 'Falha ao enviar mensagem';

  @override
  String get automationErrorSendChannelFailed => 'Falha ao enviar ao canal';

  @override
  String get automationErrorShortcutsIosOnly =>
      'Atalhos disponíveis apenas no iOS';

  @override
  String get automationErrorNoShortcutName =>
      'Nenhum nome de atalho especificado';

  @override
  String automationErrorShortcutLaunchFailed(String name) {
    return 'Não foi possível iniciar o atalho \"$name\"';
  }

  @override
  String automationErrorShortcutRunFailed(String error) {
    return 'Falha ao executar atalho: $error';
  }

  @override
  String get automationErrorGlyphNotAvailable =>
      'Interface de glifo não disponível';

  @override
  String automationErrorGlyphPatternFailed(String error) {
    return 'Falha ao exibir padrão de glifo: $error';
  }

  @override
  String get automationTemplateLowBatteryDesc =>
      'Notificar quando a bateria de um nó cair abaixo de 20%';

  @override
  String get automationTemplateNodeOfflineDesc =>
      'Notificar quando um nó ficar offline';

  @override
  String get automationTemplateGeofenceExitDesc =>
      'Alertar quando um nó sair de uma área designada';

  @override
  String get automationTemplateSosDesc =>
      'Resposta automática ao receber mensagem SOS';

  @override
  String get automationTemplateDeadManDesc =>
      'Alertar se nenhuma atividade do nó por 30 minutos';

  @override
  String get automationScheduledTitle => 'Automação agendada';

  @override
  String get automationScheduledBody =>
      'Toque para executar a automação agendada';

  @override
  String automationLogNode(String nodeName) {
    return 'Nó: $nodeName';
  }

  @override
  String automationLogBattery(int level) {
    return 'Bateria: $level%';
  }

  @override
  String automationLogMessage(String text) {
    return 'Mensagem: $text';
  }

  @override
  String get authErrorGoogleSignInCancelled => 'Login do Google cancelado';

  @override
  String get authErrorGoogleNoIdToken =>
      'O login do Google não retornou um token ID';

  @override
  String get authErrorNoCurrentUser => 'Nenhum usuário conectado no momento';

  @override
  String get authErrorGoogleReauthCancelled =>
      'Reautenticação do Google cancelada';

  @override
  String get authErrorNoSupportedProvider =>
      'Nenhum provedor compatível encontrado para reautenticação';

  @override
  String get authErrorNoUserSignedIn => 'Nenhum usuário conectado';

  @override
  String get authErrorSessionLost =>
      'Sessão do usuário perdida durante a reautenticação';

  @override
  String get authErrorVerificationCodeFailed =>
      'Falha ao enviar código de verificação';

  @override
  String get connectionErrorBluetoothDisabled => 'Bluetooth está desativado';

  @override
  String get connectionErrorDeviceNotFound => 'Dispositivo não encontrado';

  @override
  String get connectionErrorDeviceReset =>
      'O dispositivo foi redefinido ou substituído. Configure-o novamente.';

  @override
  String countdownTracerouteTo(String displayName) {
    return 'Traceroute para $displayName';
  }

  @override
  String get countdownRequestingPositions =>
      'Solicitando posições da rede mesh';

  @override
  String get countdownBroadcastingPosition =>
      'Transmitindo posição para a rede mesh';

  @override
  String countdownAwaitingAccept(String filename) {
    return 'Awaiting accept for $filename';
  }

  @override
  String countdownSendingFile(String filename) {
    return 'Sending $filename';
  }

  @override
  String countdownReceivingFile(String filename) {
    return 'Receiving $filename';
  }

  @override
  String get lifecycleAppNotActive => 'O app não está ativo';

  @override
  String get lifecycleCommandExpired => 'Comando expirado';

  @override
  String get nodedexMilestoneFirstDiscovered => 'Primeira descoberta';

  @override
  String nodedexMilestoneEncounterN(int count) {
    return 'Encontro #$count';
  }

  @override
  String meshHealthRssiDegraded(String rssi) {
    return 'RSSI médio degradou para $rssi dBm';
  }

  @override
  String offlineQueueMaxRetries(String error) {
    return 'Máximo de tentativas atingido: $error';
  }

  @override
  String get connectionAlreadyInProgress => 'Conexão já em andamento';

  @override
  String get connectionCancelled => 'Conexão cancelada';

  @override
  String get adminConformanceBundleTitle => 'Pacote de conformidade Socialmesh';

  @override
  String get adminDiagnosticBundleText =>
      'Pacote de diagnóstico administrativo do Socialmesh';

  @override
  String adminDiagnosticBundleSubject(String runId) {
    return 'Diagnóstico Socialmesh $runId';
  }

  @override
  String get onboardingSignalAuthorSarah => 'Sarah';

  @override
  String get onboardingSignalContentSarah =>
      'Acabei de chegar ao cume! O sinal está cristalino aqui em cima.';

  @override
  String get onboardingSignalAuthorMike => 'Mike';

  @override
  String get onboardingSignalAuthorAlex => 'Alex';

  @override
  String get globalLayerCopyExplainTitle => 'O que é a Camada Global?';

  @override
  String get globalLayerCopyExplainBody =>
      'Seu rádio mesh conecta dispositivos próximos por ondas de rádio — sem precisar de internet. A Camada Global estende esse alcance conectando sua rede mesh local a um servidor (chamado broker) pela internet.\n\nPense nela como um portal: mensagens da sua mesh podem viajar através do portal para alcançar outras redes mesh conectadas ao mesmo broker, em qualquer lugar do mundo.';

  @override
  String get globalLayerCopyExplainWhatItDoes =>
      'Conecta sua rede mesh local a redes mesh remotas via um servidor de internet.';

  @override
  String get globalLayerCopyExplainWhatItDoesNot =>
      'NÃO substitui seu rádio. A rede mesh local funciona independentemente mesmo se a Camada Global estiver offline.';

  @override
  String get globalLayerCopyBrokerTitle => 'Escolha um broker';

  @override
  String get globalLayerCopyBrokerBody =>
      'Escolha um broker para se conectar. A maioria dos usuários deve começar com o servidor oficial Meshtastic — funciona imediatamente sem necessidade de configuração.';

  @override
  String get globalLayerCopyTopicsTitle => 'Escolha o que compartilhar';

  @override
  String get globalLayerCopyTopicsBody =>
      'Os tópicos controlam quais tipos de dados passam pela Camada Global. Você pode ativar ou desativar cada tipo independentemente.';

  @override
  String get globalLayerCopyPrivacyTitle => 'Privacidade e segurança';

  @override
  String get globalLayerCopyPrivacyBody =>
      'A Camada Global é opcional. Nada é compartilhado até que você a ative explicitamente abaixo. Você pode alterar essas configurações a qualquer momento.';

  @override
  String get globalLayerCopyPrivacyBrokerTrustWarning =>
      'Seu broker pode ver todos os dados que você envia através dele. Conecte-se apenas a brokers de sua confiança.';

  @override
  String get globalLayerCopyTestTitle => 'Testar conexão';

  @override
  String get globalLayerCopyTestBody =>
      'Verificando se o broker está acessível e configurado corretamente.';

  @override
  String get globalLayerCopySummaryTitle => 'Pronto para conectar';

  @override
  String get globalLayerCopySummaryBody =>
      'Revise as configurações da Camada Global abaixo. Você pode alterá-las depois na tela de status da Camada Global.';

  @override
  String get mqttTopicChatLabel => 'Chat';

  @override
  String get mqttTopicChatDescription =>
      'Mensagens de texto trocadas entre nós mesh em um canal específico.';

  @override
  String get mqttTopicTelemetryLabel => 'Telemetria';

  @override
  String get mqttTopicTelemetryDescription =>
      'Dados de saúde do dispositivo como nível de bateria, voltagem e tempo ativo.';

  @override
  String get mqttTopicPositionLabel => 'Posição';

  @override
  String get mqttTopicPositionDescription =>
      'Coordenadas GPS reportadas pelos nós mesh (dado sensível de privacidade).';

  @override
  String get mqttTopicNodeInfoLabel => 'Info do nó';

  @override
  String get mqttTopicNodeInfoDescription =>
      'Transmissões de identidade do nó incluindo nome longo, nome curto e modelo de hardware.';

  @override
  String get mqttTopicMapReportsLabel => 'Relatórios de mapa';

  @override
  String get mqttTopicMapReportsDescription =>
      'Relatórios periódicos de posição para serviços públicos de mapeamento mesh.';

  @override
  String get mqttBrokerMeshtasticName => 'Meshtastic (Oficial)';

  @override
  String get mqttBrokerMeshtasticDescription =>
      'O servidor MQTT padrão do Meshtastic. Conecta você à rede mesh Meshtastic mundial. Nenhuma conta necessária.';

  @override
  String get mqttBrokerMeshtasticNote =>
      'As credenciais públicas são compartilhadas por todos os usuários Meshtastic.';

  @override
  String get mqttBrokerMosquittoName => 'Mosquitto Teste';

  @override
  String get mqttBrokerMosquittoDescription =>
      'Um broker de teste público gratuito mantido pelo projeto Eclipse Mosquitto. Bom para testar sua configuração antes de conectar a um broker de produção.';

  @override
  String get mqttBrokerMosquittoNote =>
      'Broker de teste — não para uso em produção. Pode ter indisponibilidade.';

  @override
  String get mqttBrokerCustomName => 'Broker personalizado';

  @override
  String get mqttBrokerCustomDescription =>
      'Insira os detalhes do seu broker manualmente.';

  @override
  String get globalLayerDiagConfigTitle => 'Configuração';

  @override
  String get globalLayerDiagConfigDescription =>
      'Verificando se o endereço, porta e raiz do tópico do broker estão formatados corretamente.';

  @override
  String get globalLayerDiagDnsTitle => 'Resolução DNS';

  @override
  String get globalLayerDiagDnsDescription =>
      'Consultando o nome do host do broker para encontrar seu endereço de rede.';

  @override
  String get globalLayerDiagTcpTitle => 'Conexão TCP';

  @override
  String get globalLayerDiagTcpDescription =>
      'Estabelecendo uma conexão de rede com o broker.';

  @override
  String get globalLayerDiagTlsTitle => 'Handshake TLS';

  @override
  String get globalLayerDiagTlsDescription =>
      'Negociando uma conexão segura (criptografada) com o broker.';

  @override
  String get globalLayerDiagAuthTitle => 'Autenticação';

  @override
  String get globalLayerDiagAuthDescription =>
      'Verificando seu nome de usuário e senha com o broker.';

  @override
  String get globalLayerDiagSubscribeTitle => 'Teste de inscrição';

  @override
  String get globalLayerDiagSubscribeDescription =>
      'Inscrevendo-se em um tópico de teste para verificar acesso de leitura.';

  @override
  String get globalLayerDiagPublishTitle => 'Teste de publicação';

  @override
  String get globalLayerDiagPublishDescription =>
      'Publicando uma mensagem de teste para verificar acesso de escrita.';

  @override
  String get globalLayerDiagSuggestionCorrectFields =>
      'Corrija os campos destacados e tente novamente.';

  @override
  String get globalLayerDiagSuggestionUnexpectedBehavior =>
      'Esses problemas podem não impedir a conexão, mas podem causar comportamentos inesperados.';

  @override
  String get globalLayerDiagConfigValid =>
      'Todos os campos de configuração são válidos.';

  @override
  String get globalLayerDiagSuggestionValidHostname =>
      'Insira um nome de host de broker válido.';

  @override
  String get globalLayerDiagSuggestionBothCredentials =>
      'Alguns brokers exigem nome de usuário e senha.';

  @override
  String globalLayerWizardDnsValid(String host) {
    return 'O hostname parece válido: $host';
  }

  @override
  String globalLayerWizardTcpReachable(String host, int port) {
    return 'Conexão TCP com $host:$port acessível.';
  }

  @override
  String get globalLayerWizardTlsAccepted =>
      'Parâmetros de handshake TLS aceitos.';

  @override
  String get globalLayerWizardCredentialsAccepted =>
      'Credenciais fornecidas e aceitas.';

  @override
  String get globalLayerWizardAnonymousAccess =>
      'Sem credenciais — usando acesso anônimo.';

  @override
  String get globalLayerWizardSubscribeVerified =>
      'Permissões de assinatura verificadas.';

  @override
  String get globalLayerWizardPublishVerified =>
      'Permissões de publicação verificadas.';

  @override
  String get globalLayerShareMessagesSubtitle =>
      'As mensagens de chat da sua mesh local serão encaminhadas ao broker para que outras meshes conectadas possam receber.';

  @override
  String get globalLayerShareTelemetrySubtitle =>
      'Nível de bateria, tensão e tempo de atividade do dispositivo serão publicados no broker.';

  @override
  String get globalLayerAllowInboundSubtitle =>
      'Mensagens de outras meshes conectadas ao mesmo broker serão entregues aos seus canais locais.';

  @override
  String get globalLayerBrokerTrust => 'Confiança do broker';

  @override
  String get globalLayerRunConnectionTest => 'Executar teste de conexão';

  @override
  String get globalLayerSkipTestHint =>
      'Você pode pular esta etapa e testar depois.';

  @override
  String get globalLayerWizardAllChecksPassed =>
      'Todas as verificações aprovadas';

  @override
  String get globalLayerPassedWithWarnings => 'Aprovado com avisos';

  @override
  String get globalLayerSomeChecksFailed => 'Algumas verificações falharam';

  @override
  String get globalLayerTestInProgress => 'Teste em andamento';

  @override
  String get globalLayerSummaryBrokerSection => 'BROKER';

  @override
  String get globalLayerSummaryTopicsSection => 'TÓPICOS';

  @override
  String get globalLayerSummaryPrivacySection => 'PRIVACIDADE';

  @override
  String get globalLayerSummaryAddress => 'Endereço';

  @override
  String get globalLayerSummaryPort => 'Porta';

  @override
  String get globalLayerSummaryTls => 'TLS';

  @override
  String get globalLayerSummaryTlsEnabled => 'Ativado';

  @override
  String get globalLayerSummaryTlsDisabled => 'Desativado';

  @override
  String get globalLayerSummaryAuth => 'Autenticação';

  @override
  String get globalLayerSummaryAuthCredentials => 'Credenciais configuradas';

  @override
  String get globalLayerSummaryAuthAnonymous => 'Anônimo';

  @override
  String get globalLayerSummaryRoot => 'Root';

  @override
  String get globalLayerSummaryTopicsEnabled => 'Ativados';

  @override
  String get globalLayerSummaryTopicsNone => 'Nenhum';

  @override
  String get globalLayerSummaryShareMessages => 'Compartilhar mensagens';

  @override
  String get globalLayerSummaryShareTelemetry => 'Compartilhar telemetria';

  @override
  String get globalLayerSummaryInboundGlobal => 'Global de entrada';

  @override
  String get globalLayerSummaryOn => 'ON';

  @override
  String get globalLayerSummaryOff => 'DESLIGADO';

  @override
  String get globalLayerAllSharingOff =>
      'Todo o compartilhamento está OFF. Os dados da sua mesh permanecem locais até você ativar o compartilhamento.';

  @override
  String get globalLayerNoTlsLabel => 'Sem TLS';

  @override
  String get tapbackPoop => 'Cocô';

  @override
  String get tapbackQuestion => 'Pergunta';

  @override
  String get tapbackExclamation => 'Exclamação';

  @override
  String get tapbackHaha => 'HaHa';

  @override
  String get tapbackThumbsDown => 'Negativo';

  @override
  String get tapbackThumbsUp => 'Positivo';

  @override
  String get tapbackHeart => 'Coração';

  @override
  String get tapbackWave => 'Aceno';

  @override
  String get cannedResponseThanks => 'Obrigado!';

  @override
  String get cannedResponseWaitForMe => 'Espere por mim';

  @override
  String get cannedResponseImSafe => 'Estou bem';

  @override
  String get cannedResponseNeedHelp => 'Preciso de ajuda';

  @override
  String get cannedResponseOnMyWay => 'Estou a caminho';

  @override
  String get cannedResponseNo => 'Não';

  @override
  String get cannedResponseYes => 'Sim';

  @override
  String get cannedResponseOk => 'OK';

  @override
  String get deepLinkUnableToOpenLink => 'Não foi possível abrir o link';

  @override
  String get deepLinkInvalidLegalDocumentLink =>
      'Link de documento legal inválido';

  @override
  String get deepLinkInvalidAetherFlightLink => 'Link de voo Aether inválido';

  @override
  String get deepLinkInvalidAutomationLink => 'Link de automação inválido';

  @override
  String get deepLinkInvalidLocationCoordinates =>
      'Coordenadas de localização inválidas';

  @override
  String get deepLinkInvalidPostLink => 'Link de publicação inválido';

  @override
  String get deepLinkInvalidWidgetLink => 'Link de widget inválido';

  @override
  String get deepLinkInvalidProfileLink => 'Link de perfil inválido';

  @override
  String get deepLinkSignInToJoinChannel =>
      'Faça login para entrar neste canal';

  @override
  String get deepLinkInvalidInviteLink =>
      'Link de convite inválido ou incompleto';

  @override
  String get deepLinkInvalidChannelData => 'Dados do canal inválidos';

  @override
  String get deepLinkConnectToImportChannel =>
      'Conecte um dispositivo para importar este canal';

  @override
  String get deepLinkUnableToLoadNode =>
      'Não foi possível carregar os dados do nó';

  @override
  String get deepLinkNodeAddedSuccess => 'Nó adicionado com sucesso';

  @override
  String get lifecycleActionCancelled => 'Ação cancelada';

  @override
  String get lifecycleActionExpiredBackground =>
      'Ação expirou enquanto o app estava em segundo plano';

  @override
  String get lifecycleActionCancelledBackground =>
      'Ação cancelada — o app está em segundo plano';

  @override
  String get commandErrorCheckInternet =>
      'Verifique sua conexão com a internet';

  @override
  String get commandErrorWaitingConfig =>
      'Aguardando configuração do dispositivo';

  @override
  String get commandErrorConnectDevice =>
      'Conecte seu dispositivo para usar este recurso';

  @override
  String get sipBadgeLabel => 'Socialmesh';

  @override
  String get sipIdentityStateUnverified => 'Não Verificado';

  @override
  String get sipIdentityStateVerifiedTofu => 'Verificado (TOFU)';

  @override
  String get sipIdentityStatePinned => 'Fixado';

  @override
  String get sipIdentityStateChangedKey => 'Chave Alterada';

  @override
  String get sipIdentityStateStale => 'Expirado';

  @override
  String get sipChangedKeyWarning =>
      'A chave de identidade deste par mudou. Verifique antes de confiar.';

  @override
  String get sipDisplayNameLabel => 'Nome SIP';

  @override
  String get sipPersonaIdLabel => 'ID Persona';

  @override
  String get sipDiscoveryTitle => 'Descoberta Socialmesh';

  @override
  String sipDiscoveryPeersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pares',
      one: 'par',
    );
    return '$count $_temp0 Socialmesh por perto';
  }

  @override
  String get sipDiscoveryNoPeers => 'Nenhum par Socialmesh detetado';

  @override
  String get sipDiscoveryNoPeersDescription =>
      'Pares Socialmesh aparecerão aqui quando detetados via beacon ou chamada.';

  @override
  String get sipDiscoveryScanButton => 'Pesquisar Socialmesh';

  @override
  String sipDiscoveryScanCooldown(int seconds) {
    return 'Pesquisa disponível em ${seconds}s';
  }

  @override
  String get sipDiscoveryPeerAnonymous => 'Par SIP';

  @override
  String sipDiscoveryDeviceClass(String deviceClass) {
    return 'Classe do dispositivo: $deviceClass';
  }

  @override
  String get sipHandshakeAction => 'Handshake';

  @override
  String get sipHandshakeInProgress => 'Handshake em progresso…';

  @override
  String get sipHandshakeComplete => 'Handshake concluído';

  @override
  String get sipHandshakeFailed => 'Handshake falhou';

  @override
  String get sipHandshakePendingLabel => 'Pedido Pendente';

  @override
  String get sipRequestIdentity => 'Solicitar Identidade';

  @override
  String get sipShareIdentity => 'Partilhar Identidade';

  @override
  String get sipDmTitle => 'DM Efémero';

  @override
  String sipDmExpiry(String time) {
    return 'Expira em $time';
  }

  @override
  String get sipDmPinned => 'Sessão fixada';

  @override
  String get sipDmInputHint => 'Mensagem…';

  @override
  String get sipDmSendButton => 'Enviar';

  @override
  String get sipDmEmptyState => 'Sem mensagens ainda';

  @override
  String get sipDmEmptyDescription =>
      'Envie uma mensagem para iniciar a conversa.';

  @override
  String get sipDmBudgetExhausted =>
      'Orçamento de tempo de antena esgotado. Tente mais tarde.';

  @override
  String get sipDmSessionClosed => 'Esta sessão foi encerrada.';

  @override
  String get sipDmPinAction => 'Fixar Sessão';

  @override
  String get sipDmUnpinAction => 'Desafixar Sessão';

  @override
  String get sipDmCloseAction => 'Fechar Sessão';

  @override
  String get sipDmOpenAction => 'Abrir DM';

  @override
  String get sipPeerDetailTitle => 'Detalhes do Par';

  @override
  String get sipPeerDetailNodeId => 'ID do Nó';

  @override
  String get sipPeerDetailDeviceClass => 'Classe do Dispositivo';

  @override
  String get sipPeerDetailFeatures => 'Funcionalidades';

  @override
  String get sipPeerDetailMtu => 'Dica de MTU';

  @override
  String get sipPeerDetailLastSeen => 'Visto pela Última Vez';

  @override
  String get sipPeerDetailJustNow => 'Agora mesmo';

  @override
  String sipPeerDetailMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'minutos',
      one: 'minuto',
    );
    return '$count $_temp0 atrás';
  }

  @override
  String sipPeerDetailHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return '$count $_temp0 atrás';
  }

  @override
  String get sipPeerDetailSupportsSip1 => 'Identidade e Handshake';

  @override
  String get sipPeerDetailSupportsSip3 => 'Micro-Troca';

  @override
  String get sipPeerDetailCapabilities => 'Capacidades';

  @override
  String get sipPeerDetailDeviceUnknown => 'Unknown';

  @override
  String get sipPeerDetailDevicePhone => 'Phone';

  @override
  String get sipPeerDetailDeviceTablet => 'Tablet';

  @override
  String get sipPeerDetailDeviceDesktop => 'Desktop';

  @override
  String sipPeerDetailDeviceType(int code) {
    return 'Type $code';
  }

  @override
  String get sipPeerDetailExpertToggle => 'Technical details';

  @override
  String get sipCountersTitle => 'Contadores de Debug SIP';

  @override
  String get sipHubTitle => 'Socialmesh';

  @override
  String get sipHubSectionPeers => 'Pares Próximos';

  @override
  String get sipHubSectionConversations => 'Conversas';

  @override
  String get sipHubSectionIncomingRequests => 'Pedidos Recebidos';

  @override
  String sipHubIncomingRequestFrom(String peerName) {
    return '$peerName quer ligar-se';
  }

  @override
  String get sipHubAccept => 'Aceitar';

  @override
  String get sipHubDecline => 'Recusar';

  @override
  String get sipHubEmptyTitle => 'Sem pares por perto';

  @override
  String get sipHubEmptyDescription =>
      'Toque em Pesquisar para procurar outros utilizadores Socialmesh na mesh.';

  @override
  String get sipHubScanningTitlePrefix => 'Sem pares ';

  @override
  String get sipHubScanningTitleKeyword => 'próximos';

  @override
  String get sipHubScanningTitleSuffix => '';

  @override
  String get sipHubScanningTagline1 =>
      'Escuta beacons Socialmesh na mesh rádio';

  @override
  String get sipHubScanningTagline2 =>
      'Toque em Pesquisar para enviar uma chamada — ativa pares próximos';

  @override
  String get sipHubScanningTagline3 =>
      'Os pares respondem anonimamente — sem conta necessária';

  @override
  String get sipHubScanningTagline4 =>
      'Encontrou um? Inicie um handshake para começar a conversar';

  @override
  String get sipHubHelp => 'Ajuda';

  @override
  String get helpSipHubOverviewTitle => 'Socialmesh';

  @override
  String get helpSipHubOverviewDescription =>
      'Descubra e converse com pares Socialmesh próximos';

  @override
  String get helpSipHubIntroBubble =>
      'Bem-vindo ao **Socialmesh**! Este é o seu hub de descoberta de pares. Dispositivos próximos com Socialmesh aparecem aqui quando emitem sinais ou respondem a uma chamada.';

  @override
  String get helpSipHubScanBubble =>
      'Toque no **ícone de pesquisa** para enviar um pedido de chamada. Os pares próximos responderão em segundos. A pesquisa automática dispara a cada 60 segundos em segundo plano.';

  @override
  String get helpSipHubHandshakeBubble =>
      'Quando vir um par, toque em **Handshake** para trocar identidade. Após o handshake pode abrir um **DM encriptado de ponta a ponta** — sem servidores, sem contas.';

  @override
  String get helpSipHubPrivacyBubble =>
      'Toda a descoberta é **anónima por padrão**. Os pares apenas revelam um ID ambiente rotativo de 4 bytes até que concordem mutuamente com um handshake.';

  @override
  String sipHubLastSeen(String time) {
    return 'Visto $time';
  }

  @override
  String get sipHubHandshaking => 'A fazer handshake…';

  @override
  String get sipHubReady => 'Pronto para conversar';

  @override
  String get sipHubConnected => 'Ligado';

  @override
  String sipHubMessagePreview(String name, String message) {
    return '$name: $message';
  }

  @override
  String sipHubSessionExpiry(String time) {
    return 'Expira em $time';
  }

  @override
  String get sipHubSessionPinned => 'Fixado';

  @override
  String get sipHubNoMessages => 'Sem mensagens ainda';

  @override
  String sipDmPeerName(String hexId) {
    return 'Par $hexId';
  }

  @override
  String get sipAutoScanEnabled => 'Pesquisa automática ativada';

  @override
  String get sipAutoScanDisabled => 'Pesquisa automática desativada';

  @override
  String get sipAutoScanToggle => 'Pesquisa automática';

  @override
  String get sipScanningIndicator => 'A pesquisar…';

  @override
  String get sipConnecting => 'A ligar…';

  @override
  String get sipDmReplyingTo => 'A responder a';

  @override
  String get sipDmSwipeToReply => 'Deslize para responder';

  @override
  String get sipDmActionReply => 'Responder';

  @override
  String get sipDmActionCopy => 'Copiar';

  @override
  String get sipDmActionDelete => 'Eliminar';

  @override
  String get sipDmMessageCopied => 'Mensagem copiada';

  @override
  String get sipDmDeleteConfirmTitle => 'Eliminar mensagem?';

  @override
  String get sipDmDeleteConfirmMessage =>
      'Isto eliminará a mensagem para si e para o destinatário.';

  @override
  String notificationSipDmTitle(String peerName) {
    return '$peerName';
  }

  @override
  String get notificationSipHandshakeTitle => 'Chat Seguro Pronto';

  @override
  String notificationSipHandshakeBody(String peerName) {
    return 'Pode agora enviar mensagens privadas com $peerName.';
  }

  @override
  String get notificationChannelSipMessages => 'Mensagens Efémeras';

  @override
  String get notificationChannelSipHandshake => 'Pedidos de Ligação';

  @override
  String get notificationSipHandshakeRequestTitle => 'Pedido de Chat';

  @override
  String notificationSipHandshakeRequestBody(String peerName) {
    return '$peerName quer iniciar uma conversa privada.';
  }

  @override
  String get notificationSipHandshakeDeclinedTitle => 'Ligação Recusada';

  @override
  String notificationSipHandshakeDeclinedBody(String peerName) {
    return '$peerName recusou o seu pedido de ligação.';
  }

  @override
  String get mrrpHarnessTitle => 'Harness de Protocolo';

  @override
  String get mrrpHarnessDrawerLabel => 'Harness de Protocolo';

  @override
  String get mrrpHarnessStatusSip => 'SIP';

  @override
  String get mrrpHarnessStatusMrrp => 'MRRP';

  @override
  String get mrrpHarnessStatusEnabled => 'Ativado';

  @override
  String get mrrpHarnessStatusDisabled => 'Desativado';

  @override
  String get mrrpHarnessRadioState => 'Rádio';

  @override
  String get mrrpHarnessRadioConnected => 'Ligado';

  @override
  String get mrrpHarnessRadioDisconnected => 'Desligado';

  @override
  String get mrrpHarnessChannel => 'Canal';

  @override
  String get mrrpHarnessChannelNone => 'Sem canal';

  @override
  String get mrrpHarnessSipPeers => 'Pares SIP';

  @override
  String get mrrpHarnessMrrpServices => 'Serviços MRRP';

  @override
  String get mrrpHarnessBudget => 'Orçamento';

  @override
  String mrrpHarnessBudgetValue(int remaining, int capacity) {
    return '$remaining/$capacity bytes';
  }

  @override
  String get mrrpHarnessScanPeers => 'Pesquisar Pares';

  @override
  String get mrrpHarnessBrowseServices => 'Explorar Serviços';

  @override
  String get mrrpHarnessOpenComposer => 'Abrir Compositor';

  @override
  String get mrrpHarnessOpenTraffic => 'Consola de Tráfego';

  @override
  String get mrrpHarnessSectionStatus => 'Estado do Protocolo';

  @override
  String get mrrpHarnessSectionActions => 'Ações Rápidas';

  @override
  String get mrrpHarnessPeerInspectorTitle => 'Inspetor de Pares';

  @override
  String mrrpHarnessPeerServices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'serviços',
      one: 'serviço',
    );
    return '$count $_temp0';
  }

  @override
  String mrrpHarnessPeerLastAdvert(String time) {
    return 'Último anúncio: $time';
  }

  @override
  String get mrrpHarnessRefreshDirectory => 'Atualizar Diretório';

  @override
  String get mrrpHarnessServiceBrowserTitle => 'Explorador de Serviços';

  @override
  String mrrpHarnessServiceVersion(int major, int minor) {
    return 'v$major.$minor';
  }

  @override
  String mrrpHarnessServiceFlags(String flags) {
    return 'Flags: $flags';
  }

  @override
  String get mrrpHarnessRawHex => 'Hex em bruto';

  @override
  String get mrrpHarnessComposerTitle => 'Compositor de Pedidos';

  @override
  String get mrrpHarnessSelectPeer => 'Selecionar par';

  @override
  String get mrrpHarnessSelectService => 'Selecionar serviço';

  @override
  String get mrrpHarnessSelectAction => 'Selecionar ação';

  @override
  String get mrrpHarnessPayloadPreset => 'Preset de carga útil';

  @override
  String get mrrpHarnessPayloadRawHex => 'Carga útil hex em bruto';

  @override
  String get mrrpHarnessRequestTtl => 'TTL do Pedido';

  @override
  String mrrpHarnessEncodedSize(int size) {
    return '$size bytes codificados';
  }

  @override
  String get mrrpHarnessSend => 'Enviar';

  @override
  String get mrrpHarnessResponseTitle => 'Resposta';

  @override
  String get mrrpHarnessResponsePending => 'A aguardar resposta…';

  @override
  String get mrrpHarnessResponseTimeout => 'Pedido expirou';

  @override
  String mrrpHarnessResponseStatus(String status) {
    return 'Estado: $status';
  }

  @override
  String mrrpHarnessResponseLatency(int ms) {
    return 'Latência: ${ms}ms';
  }

  @override
  String get mrrpHarnessResponseDuplicate => 'Resposta duplicada';

  @override
  String get mrrpHarnessResponseCached => 'Resposta em cache';

  @override
  String get mrrpHarnessSimLabTitle => 'Laboratório de Pares Simulados';

  @override
  String get mrrpHarnessSimCreate => 'Criar Par Simulado';

  @override
  String get mrrpHarnessSimBadge => 'SIM';

  @override
  String get mrrpHarnessSimResponseMode => 'Modo de resposta';

  @override
  String get mrrpHarnessSimModeNormal => 'Normal';

  @override
  String get mrrpHarnessSimModeDelayed => 'Atrasado';

  @override
  String get mrrpHarnessSimModeError => 'Erro';

  @override
  String get mrrpHarnessSimModeTimeout => 'Tempo limite';

  @override
  String get mrrpHarnessSimModeDuplicate => 'Duplicado';

  @override
  String get mrrpHarnessSimModeMalformed => 'Malformado';

  @override
  String get mrrpHarnessSimMaxPeers => 'Máximo 4 pares simulados';

  @override
  String get mrrpHarnessSimDeleteConfirm => 'Eliminar par simulado?';

  @override
  String get mrrpHarnessSimServices => 'Serviços';

  @override
  String get mrrpHarnessSimDelay => 'Atraso (segundos)';

  @override
  String get mrrpHarnessSimErrorCode => 'Código de estado de erro';

  @override
  String get mrrpHarnessTrafficTitle => 'Consola de Tráfego';

  @override
  String get mrrpHarnessTrafficEmpty => 'Sem tráfego MRRP ainda';

  @override
  String get mrrpHarnessTrafficEmptyDescription =>
      'Eventos MRRP aparecerão aqui conforme o tráfego flui.';

  @override
  String get mrrpHarnessTrafficFilterPeer => 'Filtrar por par';

  @override
  String get mrrpHarnessTrafficFilterType => 'Filtrar por tipo';

  @override
  String get mrrpHarnessTrafficFilterService => 'Filtrar por serviço';

  @override
  String get mrrpHarnessTrafficFilterAll => 'Todos';

  @override
  String get mrrpHarnessTrafficFilterRequest => 'Pedido';

  @override
  String get mrrpHarnessTrafficFilterResponse => 'Resposta';

  @override
  String get mrrpHarnessTrafficFilterError => 'Erro';

  @override
  String get mrrpHarnessTrafficFilterCancel => 'Cancelar';

  @override
  String get mrrpHarnessTrafficFilterAdvert => 'Anúncio';

  @override
  String get mrrpHarnessTrafficFilterDirReq => 'Pedido Dir';

  @override
  String get mrrpHarnessTrafficFilterDirResp => 'Resposta Dir';

  @override
  String get mrrpHarnessTrafficSearchHint => 'Pesquisar eventos...';

  @override
  String get mrrpHarnessComposerInfoText =>
      'Selecione um par descoberto, serviço e ação para compor um quadro de pedido MRRP. O campo de carga útil aceita bytes hex em bruto.';

  @override
  String get mrrpHarnessComposerSectionTarget => 'ALVO';

  @override
  String get mrrpHarnessComposerSectionPayload => 'CARGA ÚTIL';

  @override
  String get mrrpHarnessSimLabInfoText =>
      'Crie pares MRRP virtuais para testes. Cada par anuncia echo.test e pode simular diferentes modos de resposta, incluindo atrasos, erros e dados malformados.';

  @override
  String get mrrpHarnessResponseSectionRequest => 'PEDIDO';

  @override
  String get mrrpHarnessResponseSectionResult => 'RESULTADO';

  @override
  String get mrrpHarnessPeerInspectorInfoText =>
      'Pares descobertos a anunciar serviços MRRP sobre SIP. Expanda um par para ver o seu diretório de serviços e testar pedidos.';

  @override
  String get mrrpHarnessTrafficCopy => 'Copiar evento';

  @override
  String get mrrpHarnessTrafficExport => 'Exportar eventos';

  @override
  String mrrpHarnessTrafficDirection(String direction) {
    return '$direction';
  }

  @override
  String get mrrpHarnessBudgetTitle => 'Orçamento e Temporização';

  @override
  String get mrrpHarnessBudgetRemaining => 'Orçamento restante';

  @override
  String get mrrpHarnessBudgetBlocked => 'Envios bloqueados';

  @override
  String get mrrpHarnessBudgetDedupHits => 'Acertos de dedup';

  @override
  String get mrrpHarnessBudgetTimeouts => 'Tempos limite';

  @override
  String get mrrpHarnessBudgetAdvertCadence => 'Cadência de anúncio';

  @override
  String get mrrpHarnessBudgetLatency => 'Latência';

  @override
  String get mrrpHarnessNoPeers => 'Nenhum par MRRP descoberto';

  @override
  String get mrrpHarnessNoPeersDescription =>
      'Pares com capacidade MRRP aparecerão aqui quando forem descobertos.';

  @override
  String get mrrpHarnessNoServices => 'Sem serviços';

  @override
  String get mrrpHarnessTestRequest => 'Pedido de Teste';

  @override
  String get mrrpHarnessOpenSimLab => 'Pares Simulados';

  @override
  String get mrrpHarnessOpenFixtures => 'Replay de Fixtures';

  @override
  String get mrrpHarnessFixtureTitle => 'Replay de Fixtures';

  @override
  String get mrrpHarnessFixtureVectors => 'Vetores de Teste';

  @override
  String get mrrpHarnessFixtureFuzz => 'Casos Fuzz';

  @override
  String get mrrpHarnessFixtureReplay => 'Replay';

  @override
  String get mrrpHarnessFixtureReplayAll => 'Replay Tudo';

  @override
  String get mrrpHarnessFixturePass => 'PASSOU';

  @override
  String get mrrpHarnessFixtureFail => 'FALHOU';

  @override
  String get mrrpHarnessFixtureDecodeNull => 'Descodificação retornou nulo';

  @override
  String get mrrpHarnessFixtureDecodeOk => 'Descodificação OK';

  @override
  String get mrrpHarnessFixtureExpected => 'Esperado';

  @override
  String get mrrpHarnessFixtureActual => 'Real';

  @override
  String mrrpHarnessFixtureSummary(int passed, int total) {
    return '$passed/$total aprovados';
  }

  @override
  String mrrpHarnessFixtureBytes(int count) {
    return '$count bytes';
  }

  @override
  String mrrpHarnessFixtureFieldsMatch(int matched, int total) {
    return '$matched/$total campos correspondem';
  }

  @override
  String get mrrpHarnessFixtureRejected => 'Rejeitado (esperado)';

  @override
  String get mrrpHarnessFixtureNotRejected => 'Não rejeitado (inesperado)';

  @override
  String get mrrpHarnessFixtureEmpty => 'Nenhum fixture disponível';

  @override
  String get mrrpHarnessOpenQaRunner => 'Cenários QA';

  @override
  String get mrrpHarnessQaTitle => 'Executor de Cenários QA';

  @override
  String get mrrpHarnessQaScenarios => 'Cenários';

  @override
  String get mrrpHarnessQaRunAll => 'Executar Todos';

  @override
  String mrrpHarnessQaSteps(int count) {
    return '$count passos';
  }

  @override
  String get mrrpHarnessQaRunScenario => 'Executar';

  @override
  String get mrrpHarnessQaStepPass => 'PASSOU';

  @override
  String get mrrpHarnessQaStepFail => 'FALHOU';

  @override
  String get mrrpHarnessQaStepPending => 'Pendente';

  @override
  String get mrrpHarnessQaScenarioPass => 'APROVADO';

  @override
  String get mrrpHarnessQaScenarioFail => 'FALHOU';

  @override
  String mrrpHarnessQaSummary(int passed, int total) {
    return '$passed/$total cenários aprovados';
  }

  @override
  String get mrrpHarnessQaEmpty => 'Nenhum cenário definido';

  @override
  String get mrrpHarnessQaRunning => 'A executar...';

  @override
  String get mrrpHarnessQaExpected => 'Esperado';

  @override
  String get mrrpHarnessQaActual => 'Real';

  @override
  String get mrrpHarnessCountersSectionTraffic => 'Contadores de Tráfego';

  @override
  String get mrrpHarnessCountersSectionDedup => 'Dedup e Cache';

  @override
  String get mrrpHarnessCountersSectionErrors => 'Erros e Rejeições';

  @override
  String get mrrpHarnessCountersSectionHarness => 'Atividade do Harness';

  @override
  String get mrrpHarnessCountersReqSent => 'Pedidos Enviados';

  @override
  String get mrrpHarnessCountersReqRecv => 'Pedidos Recebidos';

  @override
  String get mrrpHarnessCountersRespSent => 'Respostas Enviadas';

  @override
  String get mrrpHarnessCountersRespRecv => 'Respostas Recebidas';

  @override
  String get mrrpHarnessCountersDirReqSent => 'Pedidos Dir Enviados';

  @override
  String get mrrpHarnessCountersDirReqRecv => 'Pedidos Dir Recebidos';

  @override
  String get mrrpHarnessCountersDirRespSent => 'Respostas Dir Enviadas';

  @override
  String get mrrpHarnessCountersDirRespRecv => 'Respostas Dir Recebidas';

  @override
  String get mrrpHarnessCountersDupReq => 'Pedidos Duplicados Ignorados';

  @override
  String get mrrpHarnessCountersDupResp => 'Respostas Duplicadas Ignoradas';

  @override
  String get mrrpHarnessCountersCachedResp => 'Respostas em Cache Servidas';

  @override
  String get mrrpHarnessCountersReqTimeouts => 'Tempos Limite de Pedidos';

  @override
  String get mrrpHarnessCountersRespTimeouts => 'Tempos Limite de Respostas';

  @override
  String get mrrpHarnessCountersCancellations => 'Cancelamentos';

  @override
  String get mrrpHarnessCountersErrSent => 'Erros Enviados';

  @override
  String get mrrpHarnessCountersErrRecv => 'Erros Recebidos';

  @override
  String get mrrpHarnessCountersPayloadReject => 'Carga Útil Demasiado Grande';

  @override
  String get mrrpHarnessCountersHarnessActions => 'Ações do Harness';

  @override
  String get mrrpHarnessCountersSimFaults => 'Falhas Simuladas';

  @override
  String get meshExplorerTitle => 'Mesh Explorer';

  @override
  String get meshExplorerDrawerLabel => 'Mesh Explorer';

  @override
  String get meshExplorerHeroConnected => 'Ligado à mesh';

  @override
  String get meshExplorerHeroDisconnected => 'Nenhum rádio ligado';

  @override
  String meshExplorerHeroPeersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pares próximos',
      one: '1 par próximo',
      zero: 'Sem pares próximos',
    );
    return '$_temp0';
  }

  @override
  String meshExplorerHeroServicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serviços',
      one: '1 serviço',
      zero: 'Sem serviços',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerSectionNearby => 'Próximos';

  @override
  String get meshExplorerSectionServices => 'Serviços';

  @override
  String get meshExplorerSectionBoard => 'Atividade do Quadro';

  @override
  String get meshExplorerScanningTitlePrefix => 'Sem pares ';

  @override
  String get meshExplorerScanningTitleKeyword => 'próximos';

  @override
  String get meshExplorerScanningTitleSuffix => '';

  @override
  String get meshExplorerScanningTagline1 =>
      'Pesquisa pares Socialmesh a transmitir na mesh';

  @override
  String get meshExplorerScanningTagline2 =>
      'Toque em Pesquisar para enviar uma chamada — ativa pares próximos';

  @override
  String get meshExplorerScanningTagline3 =>
      'Os pares aparecem anonimamente — faça handshake para identificá-los';

  @override
  String get meshExplorerScanningTagline4 =>
      'O alcance do rádio importa — tente aproximar-se da mesh';

  @override
  String get meshExplorerHelp => 'Ajuda';

  @override
  String get helpMeshExplorerOverviewTitle => 'Mesh Explorer';

  @override
  String get helpMeshExplorerOverviewDescription =>
      'Explore pares próximos e serviços mesh';

  @override
  String get helpMeshExplorerIntroBubble =>
      'Bem-vindo ao **Mesh Explorer**! Aqui são mostrados todos os pares com capacidade Socialmesh atualmente ao alcance do rádio. Pares anónimos aparecem instantaneamente — sem necessidade de handshake.';

  @override
  String get helpMeshExplorerPeersBubble =>
      'Cada bloco mostra o **sigilo ambiente de um par** e as suas capacidades. Toque num par para ver detalhes ou iniciar um **handshake SIP** para troca de identidade.';

  @override
  String get helpMeshExplorerServicesBubble =>
      'A secção **Serviços** mostra o que os pares próximos estão a oferecer — Quadros de Avisos, Perfis e mais. Toque num bloco de serviço para interagir.';

  @override
  String get helpMeshExplorerScanBubble =>
      'Toque no **ícone do sensor** para transmitir uma chamada à mesh. Os pares respondem em segundos. O explorador atualiza automaticamente quando novos pares são detetados.';

  @override
  String get meshExplorerScanningAction => 'Pesquisar agora';

  @override
  String get notificationSipPeerFoundTitle => 'Par encontrado nas proximidades';

  @override
  String get notificationSipPeerFoundBody =>
      'Um par Socialmesh está ao alcance. Abra o Mesh Explorer para ligar.';

  @override
  String get notificationChannelSipDiscovery => 'Descoberta de Pares';

  @override
  String get meshExplorerEmptyNearbyTitle => 'Sem pares próximos';

  @override
  String get meshExplorerEmptyNearbyBody =>
      'Os pares aparecerão quando dispositivos mesh estiverem ao alcance';

  @override
  String get meshExplorerEmptyServicesTitle => 'Nenhum serviço encontrado';

  @override
  String get meshExplorerEmptyServicesBody =>
      'Pares próximos anunciarão serviços aqui';

  @override
  String get meshExplorerEmptyBoardTitle => 'Sem atividade no quadro';

  @override
  String get meshExplorerEmptyBoardBody =>
      'Publicações de pares próximos aparecerão aqui';

  @override
  String get meshExplorerNotConnectedTitle => 'Rádio não ligado';

  @override
  String get meshExplorerNotConnectedBody =>
      'Ligue um rádio Meshtastic para descobrir a mesh à sua volta';

  @override
  String get meshExplorerPeerAnonymous => 'Par próximo';

  @override
  String get meshExplorerPeerHandshaked => 'Handshake feito';

  @override
  String get meshExplorerPeerVerified => 'Verificado';

  @override
  String get meshExplorerPeerPinned => 'Fixado';

  @override
  String meshExplorerHopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saltos',
      one: '1 salto',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerHopCountFar => '3+ saltos';

  @override
  String get meshExplorerHopCountUnknown => 'Nearby';

  @override
  String meshExplorerServiceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serviços',
      one: '1 serviço',
      zero: 'Sem serviços',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerActionHandshake => 'Handshake';

  @override
  String get meshExplorerActionView => 'Ver';

  @override
  String get meshExplorerActionRequestIdentity => 'Solicitar Identidade';

  @override
  String get meshExplorerActionOpenNodeDex => 'Abrir no NodeDex';

  @override
  String get meshExplorerActionBlock => 'Bloquear';

  @override
  String get meshExplorerActionPin => 'Fixar Par';

  @override
  String get meshExplorerActionUnpin => 'Desafixar Par';

  @override
  String get meshExplorerPeerDetail => 'Detalhe do Par';

  @override
  String get meshExplorerPeerDetailIdentity => 'Identidade';

  @override
  String get meshExplorerPeerDetailServices => 'Serviços Disponíveis';

  @override
  String get meshExplorerPeerDetailActions => 'Ações';

  @override
  String get meshExplorerServiceBulletinBoard => 'Quadro de Avisos';

  @override
  String get meshExplorerServiceBulletinBoardSub => 'Publicações mesh locais';

  @override
  String get meshExplorerServicePeerProfile => 'Perfil do Par';

  @override
  String get meshExplorerServicePeerProfileSub =>
      'Informação de identidade partilhada';

  @override
  String get meshExplorerServiceGeneric => 'Serviço';

  @override
  String get meshExplorerServiceGenericSub => 'Disponível nas proximidades';

  @override
  String get meshExplorerServiceOpenBoard => 'Abrir Quadro';

  @override
  String get meshExplorerServiceViewProfile => 'Ver Perfil';

  @override
  String get meshExplorerServiceDetails => 'Detalhes';

  @override
  String get meshExplorerServiceRequiresHandshake => 'Requer handshake';

  @override
  String get meshExplorerServiceRequiresIdentity => 'Requer identidade';

  @override
  String meshExplorerServicePeerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pares',
      one: '1 par',
    );
    return '$_temp0';
  }

  @override
  String get meshExplorerPrivacyTitle => 'Privacidade Mesh';

  @override
  String get meshExplorerPrivacySectionVisibility => 'Visibilidade';

  @override
  String get meshExplorerPrivacySectionSharing => 'Partilha';

  @override
  String get meshExplorerPrivacySectionActions => 'Ações';

  @override
  String get meshExplorerPrivacyDiscoverable => 'Descobrível';

  @override
  String get meshExplorerPrivacyDiscoverableSub =>
      'Transmitir a sua presença para pares mesh próximos';

  @override
  String get meshExplorerPrivacyProfileSharing => 'Partilha de Perfil';

  @override
  String get meshExplorerPrivacyProfileSharingSub =>
      'Responder a pedidos de perfil de pares';

  @override
  String get meshExplorerPrivacyDmAvailable => 'Mensagens Diretas';

  @override
  String get meshExplorerPrivacyDmAvailableSub =>
      'Permitir mensagens diretas de pares identificados';

  @override
  String get meshExplorerPrivacyClearCache => 'Limpar Cache de Proximidade';

  @override
  String get meshExplorerPrivacyClearCacheSub =>
      'Remover todos os dados de pares próximos descobertos';

  @override
  String get meshExplorerPrivacyCacheCleared => 'Cache de proximidade limpa';

  @override
  String get meshExplorerScanAction => 'Pesquisar';

  @override
  String get meshExplorerRefreshAction => 'Atualizar';

  @override
  String get meshExplorerChangedKey => 'Chave alterada';

  @override
  String get meshExplorerScanSent => 'A pesquisar pares próximos…';

  @override
  String get meshExplorerScanCooldown => 'Mesh ocupada, pesquisa bloqueada';

  @override
  String get meshExplorerHandshakeSent => 'Pedido de handshake enviado';

  @override
  String get meshExplorerHandshakeCooldown =>
      'Handshake em espera, tente novamente em breve';

  @override
  String get meshExplorerHandshakeInProgress => 'Em progresso…';

  @override
  String get meshExplorerHandshakeAccept => 'Accept';

  @override
  String get meshExplorerHandshakeDecline => 'Decline';

  @override
  String get meshExplorerHandshakeReceived => 'Handshake request received';

  @override
  String get meshExplorerStatusConnected => 'Connected to mesh';

  @override
  String meshExplorerStatusPeersAndServices(int peers, int services) {
    return '$peers nearby · $services live';
  }

  @override
  String get meshExplorerSectionLiveNow => 'Live now';

  @override
  String get meshExplorerSectionNearbyPeers => 'Nearby';

  @override
  String get meshExplorerCardOpen => 'Open';

  @override
  String get meshExplorerCardLive => 'LIVE';

  @override
  String get meshExplorerFreshnessJustNow => 'Just now';

  @override
  String meshExplorerFreshnessMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String meshExplorerFreshnessHours(int count) {
    return '${count}h ago';
  }

  @override
  String get meshExplorerEmptyTitle => 'Discover the mesh';

  @override
  String get meshExplorerEmptyBody =>
      'Things shared by nearby people will show up here. Updates, questions, checklists, alerts, and readings all travel over the local mesh.';

  @override
  String get meshExplorerEmptyAction => 'Share something';

  @override
  String get meshExplorerCreateLabel => 'Create';

  @override
  String get meshExplorerNotConnectedAction => 'Connect a radio';

  @override
  String get meshServicesDrawerLabel => 'Os Meus Serviços';

  @override
  String get meshServicesTitle => 'Os Meus Serviços';

  @override
  String get meshServicesEmpty => 'Sem serviços ainda';

  @override
  String get meshServicesEmptyDescription =>
      'Crie um serviço para partilhar algo útil na mesh';

  @override
  String get meshServicesCreateAction => 'Criar Serviço';

  @override
  String get meshServicesCreateTitle => 'Criar um Serviço';

  @override
  String get meshServicesCreateSubtitle =>
      'Escolha o que pretende partilhar na mesh';

  @override
  String get meshServicesTypeFeed => 'Updates';

  @override
  String get meshServicesTypeFeedDescription =>
      'Posts and updates people nearby can open and read';

  @override
  String get meshServicesTypeList => 'Checklists';

  @override
  String get meshServicesTypeListDescription =>
      'Lists, checklists, or supplies people nearby can work through together';

  @override
  String get meshServicesTypePoll => 'Questions';

  @override
  String get meshServicesTypePollDescription =>
      'Ask nearby people to pick an answer';

  @override
  String get meshServicesTypeSignal => 'Alerts';

  @override
  String get meshServicesTypeSignalDescription =>
      'Short-lived alerts or beacons that stand out nearby';

  @override
  String get meshServicesTypeSensor => 'Readings';

  @override
  String get meshServicesTypeSensorDescription =>
      'Live measurements or telemetry people nearby can check';

  @override
  String get meshServicesIntentFeed => 'Post an update';

  @override
  String get meshServicesIntentFeedDescription =>
      'Share news, status, or a notice people nearby can open.';

  @override
  String get meshServicesIntentList => 'Create a checklist';

  @override
  String get meshServicesIntentListDescription =>
      'Organize items, jobs, or supplies people nearby can work through together.';

  @override
  String get meshServicesIntentPoll => 'Ask a question';

  @override
  String get meshServicesIntentPollDescription =>
      'Put a multiple-choice question out to nearby people.';

  @override
  String get meshServicesIntentSignal => 'Send an alert';

  @override
  String get meshServicesIntentSignalDescription =>
      'Broadcast a short-lived alert, check-in, or beacon nearby.';

  @override
  String get meshServicesIntentSensor => 'Share a reading';

  @override
  String get meshServicesIntentSensorDescription =>
      'Publish a live reading, measurement, or status from a device.';

  @override
  String get meshServicesVisibilityOpen => 'Nearby';

  @override
  String get meshServicesTemplateBoard => 'Quadro de Avisos';

  @override
  String get meshServicesTemplateBoardDescription =>
      'Partilhe publicações curtas com pares próximos';

  @override
  String get meshServicesTemplateSignal => 'Farol de Sinal';

  @override
  String get meshServicesTemplateSignalDescription =>
      'Transmita um sinal para pares próximos';

  @override
  String get meshServicesTemplatePoll => 'Sondagem Rápida';

  @override
  String get meshServicesTemplatePollDescription =>
      'Faça uma pergunta com respostas de escolha múltipla';

  @override
  String get meshServicesTemplateChecklist => 'Lista Partilhada';

  @override
  String get meshServicesTemplateChecklistDescription =>
      'Colabore numa lista com pares próximos';

  @override
  String get meshServicesTemplateResourceList => 'Lista de Recursos';

  @override
  String get meshServicesTemplateResourceListDescription =>
      'Partilhe uma lista de recursos ou materiais úteis';

  @override
  String get meshServicesTemplateWeatherStation => 'Estação Meteorológica';

  @override
  String get meshServicesTemplateWeatherStationDescription =>
      'Partilhe leituras meteorológicas locais com pares próximos';

  @override
  String get meshServicesTemplateSensorNode => 'Nó Sensor';

  @override
  String get meshServicesTemplateSensorNodeDescription =>
      'Publique dados de sensor de um dispositivo ligado';

  @override
  String get meshServicesTemplateTaskBoard => 'Quadro de Tarefas';

  @override
  String get meshServicesTemplateTaskBoardDescription =>
      'Coordene tarefas com pares próximos';

  @override
  String get meshServicesTemplateTrailConditions => 'Condições de Trilho';

  @override
  String get meshServicesTemplateTrailConditionsDescription =>
      'Reporte condições de trilhos e rotas para outros';

  @override
  String get meshServicesTemplateLostAndFound => 'Perdidos e Achados';

  @override
  String get meshServicesTemplateLostAndFoundDescription =>
      'Publique itens perdidos ou encontrados para pares próximos';

  @override
  String get schemaFieldNoData => 'Sem dados';

  @override
  String get schemaFieldEmptyList => 'Lista vazia';

  @override
  String schemaFieldMoreItems(int count) {
    return '$count mais';
  }

  @override
  String get schemaFieldJustNow => 'Agora mesmo';

  @override
  String schemaFieldMinutesAgo(int count) {
    return '${count}m atrás';
  }

  @override
  String schemaFieldHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String schemaFieldDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String get serviceDetailUnknownTitle => 'Serviço Desconhecido';

  @override
  String serviceDetailUnknownBody(String serviceType) {
    return 'O tipo de serviço \"$serviceType\" não é reconhecido por esta versão da aplicação.';
  }

  @override
  String get serviceDetailMeshUnavailable =>
      'Mesh network is not available right now.';

  @override
  String serviceDetailActionSuccess(String actionName) {
    return '$actionName completed successfully.';
  }

  @override
  String serviceDetailActionFailed(String actionName) {
    return '$actionName could not be completed.';
  }

  @override
  String get meshServicesInteractionFailed =>
      'Could not update this share right now.';

  @override
  String get serviceDetailFetchingInstances => 'Loading what’s being shared…';

  @override
  String get serviceDetailFetchFailed =>
      'Could not reach this service. The peer may be out of range.';

  @override
  String serviceDetailFetchFailedRetried(int attempts) {
    return 'Could not reach this service after $attempts attempts. The peer may be out of range.';
  }

  @override
  String get serviceDetailNoInstances => 'No active instances';

  @override
  String get serviceDetailNoInstancesBody =>
      'This peer is not hosting any active services right now.';

  @override
  String get serviceDetailInstanceDescription => 'Description';

  @override
  String serviceDetailInstanceExpires(String time) {
    return 'Ends in $time';
  }

  @override
  String get serviceDetailInstanceNoExpiry => 'Stays live until removed';

  @override
  String get serviceDetailInstanceExpired => 'Expired';

  @override
  String get meshServicesFieldTitle => 'Título';

  @override
  String get meshServicesFieldDescription => 'Descrição';

  @override
  String get meshServicesDescriptionHint =>
      'Descreva o seu serviço para outros utilizadores da mesh…';

  @override
  String get meshServicesFieldDuration => 'Duração';

  @override
  String get meshServicesFieldQuestion => 'Pergunta';

  @override
  String meshServicesFieldOption(int index) {
    return 'Opção $index';
  }

  @override
  String get meshServicesFieldAddOption => 'Adicionar Opção';

  @override
  String meshServicesFieldItem(int index) {
    return 'Item $index';
  }

  @override
  String get meshServicesFieldAddItem => 'Adicionar Item';

  @override
  String get meshServicesPreviewTitle => 'Pré-visualização';

  @override
  String get meshServicesPreviewSubtitle =>
      'É isto que os pares próximos verão';

  @override
  String get meshServicesPublishAction => 'Publicar';

  @override
  String get meshServicesPublishSuccess => 'Serviço publicado';

  @override
  String get meshServicesCreatedHeadline => 'Your share is live';

  @override
  String get meshServicesCreatedDescription =>
      'People nearby can now discover it and open the full details.';

  @override
  String get meshServicesCreatedMeshHint =>
      'Sharing works best when other radios are active nearby.';

  @override
  String get meshServicesCreatedViewServices => 'See my shares';

  @override
  String get meshServicesCreatedCreateAnother => 'Share another';

  @override
  String get meshServicesStatusActive => 'Ativo';

  @override
  String get meshServicesStatusStopped => 'Parado';

  @override
  String get meshServicesStatusExpired => 'Expirado';

  @override
  String get meshServicesStopAction => 'Parar';

  @override
  String get meshServicesDeleteAction => 'Eliminar';

  @override
  String get meshServicesActionsLabel => 'Ações';

  @override
  String get meshServicesStopConfirm =>
      'Parar este serviço? Os pares próximos deixarão de o ver.';

  @override
  String get meshServicesDeleteConfirm =>
      'Eliminar este serviço? Esta ação não pode ser desfeita.';

  @override
  String get meshServicesDetailTitle => 'Detalhes do Serviço';

  @override
  String meshServicesRemainingTime(String duration) {
    return '$duration restante';
  }

  @override
  String meshServicesDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String meshServicesDurationHours(int count) {
    return '$count h';
  }

  @override
  String get meshServicesTitleRequired => 'Título é obrigatório';

  @override
  String get meshServicesMinOptions => 'Pelo menos 2 opções necessárias';

  @override
  String get meshServicesMinItems => 'Pelo menos 1 item necessário';

  @override
  String get meshServicesConfirmAction => 'Confirmar';

  @override
  String get meshServicesCancelAction => 'Cancelar';

  @override
  String get meshServicesSearchHint => 'Pesquisar serviços';

  @override
  String get meshServicesFilterAll => 'Todos';

  @override
  String get meshServicesFilterActive => 'Ativo';

  @override
  String get meshServicesFilterExpired => 'Expirado';

  @override
  String get meshServicesFilterStopped => 'Parado';

  @override
  String get meshServicesNoResults => 'Nenhum serviço correspondente';

  @override
  String get mapTerrainProfile => 'Perfil de Terreno';

  @override
  String get mapTerrainProfileSubtitle =>
      'Secção transversal de elevação + sobreposição LOS';

  @override
  String get mapTerrainProfileTitle => 'Perfil de Terreno';

  @override
  String get mapTerrainProfileLoading => 'A obter dados de elevação…';

  @override
  String get mapTerrainProfileOffline =>
      'Dados de elevação indisponíveis offline';

  @override
  String get mapTerrainProfileOfflineSubtitle =>
      'Ligue-se à internet para carregar a elevação do terreno.';

  @override
  String get mapTerrainProfileError =>
      'Não foi possível carregar dados de elevação';

  @override
  String get mapTerrainProfileErrorSubtitle =>
      'Verifique a sua ligação e tente novamente.';

  @override
  String get mapTerrainProfileNeedsAltitude => 'Sobreposição LOS indisponível';

  @override
  String get mapTerrainProfileNeedsAltitudeSubtitle =>
      'Um ou ambos os nós não têm altitude GPS. O perfil de terreno ainda é mostrado.';

  @override
  String get mapTerrainProfileUsingTerrainAltitude =>
      'Using terrain elevation for LOS';

  @override
  String get mapTerrainProfileUsingTerrainAltitudeSubtitle =>
      'No GPS altitude — ground level assumed for one or both points.';

  @override
  String mapTerrainProfileSampleCount(int count) {
    return '$count amostras de elevação';
  }

  @override
  String get mapTerrainProfile3DToggle => '3D view';

  @override
  String get mapTerrainProfile2DToggle => '2D chart';

  @override
  String mapTerrainLosVerdict(String verdict) {
    return 'LOS Terreno: $verdict';
  }

  @override
  String mapTerrainAdditionalClearance(String meters) {
    return 'Folga adicional necessária: ${meters}m';
  }

  @override
  String get mapTerrainRetry => 'Tentar novamente';

  @override
  String get mapTerrainAntennaHeightTitle => 'Antenna height above ground';

  @override
  String get mapTerrainAntennaHeightSubtitle =>
      'Set antenna height above ground level for points without GPS altitude to improve LOS accuracy.';

  @override
  String mapTerrainAntennaHeightPointLabel(String prefix, String name) {
    return 'Point $prefix: $name';
  }

  @override
  String mapTerrainAntennaHeightGroundLevel(int altitude) {
    return 'Ground: ${altitude}m AMSL';
  }

  @override
  String terrainLosExplanationObstructed(String depth) {
    return 'Terreno obstrui o caminho em ${depth}m no pior ponto.';
  }

  @override
  String get terrainLosExplanationMarginal =>
      'Caminho livre de terreno mas zona de Fresnel parcialmente obstruída. Sinal pode estar degradado.';

  @override
  String get terrainLosExplanationClear =>
      'LOS livre com ≥60% de folga da primeira zona de Fresnel ao longo do percurso.';

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
  String get losVerdictClear => 'Livre';

  @override
  String get losVerdictMarginal => 'Marginal';

  @override
  String get losVerdictObstructed => 'Obstruído';

  @override
  String get losVerdictUnknown => 'Desconhecido';

  @override
  String get losExplanationNoAltitude =>
      'Dados de altitude indisponíveis para um ou ambos os pontos.';

  @override
  String losExplanationObstructed(String depth) {
    return 'A curvatura terrestre obstrui o caminho em ${depth}m no ponto médio. Terreno/obstáculos não considerados.';
  }

  @override
  String losExplanationClear(String clearance) {
    return 'Linha de visão desobstruída com ${clearance}m de folga acima da curvatura terrestre. Terreno/obstáculos não considerados.';
  }

  @override
  String losExplanationMarginal(String clearance, String required) {
    return 'Folga marginal (${clearance}m) — abaixo dos ${required}m recomendados de folga Fresnel. Terreno/obstáculos não considerados.';
  }

  @override
  String get nodesScreenViewModeCards => 'Card View';

  @override
  String get nodesScreenViewModeCompact => 'Compact View';

  @override
  String nodesScreenUptimeLabel(String uptime) {
    return 'Up $uptime';
  }

  @override
  String get nodesScreenLegendTitle => 'Icon Legend';

  @override
  String get nodesScreenLegendStatusActive => 'Active — heard recently';

  @override
  String get nodesScreenLegendStatusFading => 'Fading — not heard for a while';

  @override
  String get nodesScreenLegendStatusStale => 'Stale — last heard long ago';

  @override
  String get nodesScreenLegendStatusUnknown => 'Unknown — never heard directly';

  @override
  String get nodesScreenLegendSignalStrong => 'Strong signal (≥ −70 dBm)';

  @override
  String get nodesScreenLegendSignalMedium => 'Medium signal (−70 to −85 dBm)';

  @override
  String get nodesScreenLegendSignalWeak => 'Weak signal (< −85 dBm)';

  @override
  String get nodesScreenLegendHopsDirect => 'Direct — no hops';

  @override
  String get nodesScreenLegendHops1 => '1 hop away';

  @override
  String get nodesScreenLegendHops2 => '2 hops away';

  @override
  String get nodesScreenLegendHops3 => '3 hops away';

  @override
  String get nodesScreenLegendHops4Plus => '4+ hops away';

  @override
  String get nodesScreenLegendTransportRf => 'Radio frequency (RF)';

  @override
  String get nodesScreenLegendTransportMqtt => 'Internet (MQTT)';

  @override
  String get nodesScreenLegendBatteryGood => 'Battery good (≥ 50%)';

  @override
  String get nodesScreenLegendBatteryLow => 'Battery low (20–49%)';

  @override
  String get nodesScreenLegendBatteryCritical => 'Battery critical (< 20%)';

  @override
  String get nodesScreenLegendSectionStatus => 'Status';

  @override
  String get nodesScreenLegendSectionSignal => 'Signal Strength';

  @override
  String get nodesScreenLegendSectionHops => 'Hop Count';

  @override
  String get nodesScreenLegendSectionTransport => 'Transport';

  @override
  String get nodesScreenLegendSectionBattery => 'Battery';

  @override
  String get servicePresentationBoardTitle => 'Bulletin Board';

  @override
  String get servicePresentationBoardSubtitle => 'Local mesh posts';

  @override
  String get servicePresentationBoardAction => 'Open Board';

  @override
  String get servicePresentationProfileTitle => 'Peer Profile';

  @override
  String get servicePresentationProfileSubtitle => 'Shared identity info';

  @override
  String get servicePresentationProfileAction => 'View Profile';

  @override
  String get servicePresentationMeetupTitle => 'Coordination';

  @override
  String get servicePresentationMeetupSubtitle => 'Rendezvous tokens';

  @override
  String get servicePresentationMeetupAction => 'Details';

  @override
  String get servicePresentationSignalsTitle => 'Signals';

  @override
  String get servicePresentationSignalsSubtitle =>
      'Anonymous status broadcasts';

  @override
  String get servicePresentationSignalsAction => 'View';

  @override
  String get servicePresentationMeshServicesTitle => 'Mesh Services';

  @override
  String get servicePresentationMeshServicesSubtitle => 'User-created services';

  @override
  String get servicePresentationMeshServicesAction => 'Browse';

  @override
  String get servicePresentationFallbackTitle => 'Service';

  @override
  String get servicePresentationFallbackSubtitle => 'Available nearby';

  @override
  String get servicePresentationFallbackAction => 'Details';

  @override
  String get voiceMessageSendButton => 'Voice';

  @override
  String get voiceMessageRecording => 'Recording…';

  @override
  String get voiceMessageRecordingHint => 'Hold to record';

  @override
  String get voiceMessageTooShort => 'Recording too short — hold longer';

  @override
  String get voiceMessageSent => 'Voice message sent';

  @override
  String get voiceMessageFailed => 'Voice message could not be sent';

  @override
  String get voiceMessagePermissionDenied =>
      'Microphone access is required to send voice messages';

  @override
  String get voiceMessagePermissionSettings => 'Open Settings';

  @override
  String get voiceMessagePlay => 'Play voice message';

  @override
  String get voiceMessageStop => 'Stop playback';

  @override
  String get voiceMessagePause => 'Pause';

  @override
  String voiceMessageDuration(int seconds) {
    return '${seconds}s';
  }

  @override
  String get voiceMessageAutoStopped => 'Maximum recording length reached';

  @override
  String get voiceRecordingTapToStop => 'Tap to stop recording';

  @override
  String get voiceRecordingStopButton => 'Stop';

  @override
  String get voiceRecordingLive => 'REC';

  @override
  String voiceRecordingMaxSeconds(String seconds) {
    return 'of ${seconds}s max';
  }

  @override
  String get voiceRecordingCancelButton => 'Cancel';

  @override
  String get voiceRecordingDiscardTitle => 'Discard recording?';

  @override
  String get voiceRecordingDiscardMessage => 'Your recording will be lost.';

  @override
  String get voiceRecordingDiscardConfirm => 'Discard';

  @override
  String get voiceRecordingRetakeButton => 'Retake';

  @override
  String get voiceRecordingSendButton => 'Send';

  @override
  String get voiceRecordingReadyToSend => 'Ready to send';

  @override
  String get voiceRecordingTapToPreview => 'Tap to preview';

  @override
  String get voiceRecordingTapToRecord => 'Tap to record';

  @override
  String get voiceRecordingPaused => 'PAUSED';

  @override
  String get voiceRecordingPauseButton => 'Pause';

  @override
  String get voiceRecordingResumeButton => 'Resume';

  @override
  String get voiceQualityExtended => 'Extended';

  @override
  String get voiceQualityStandard => 'Standard';

  @override
  String get voiceQualityHigh => 'High quality';

  @override
  String voiceQualityDuration(String seconds) {
    return '${seconds}s';
  }

  @override
  String get voiceQualityPickerTitle => 'Voice quality';

  @override
  String get voiceAttachmentCardTitle => 'Voice message';

  @override
  String get voiceAttachmentAnalysing => 'Analysing…';

  @override
  String get voiceAttachmentPlaybackFailed => 'Playback failed';

  @override
  String get voiceAttachmentMono => 'Mono';

  @override
  String get voiceAttachmentPause => 'Pause';

  @override
  String get fileTransferContactsSendVoice => 'Voice';

  @override
  String get stlSigningTitle => 'Trust Layer Signing';

  @override
  String get stlSigningSubtitle =>
      'Sign outbound transfers with your identity key';

  @override
  String get stlSignatureValid => 'Signature verified';

  @override
  String get stlSignatureInvalid => 'Invalid signature';

  @override
  String get tracerouteShowOnMap => 'Show on Map';

  @override
  String get tracerouteMapTitle => 'Traceroute Map';

  @override
  String get tracerouteShowRouteOnly => 'Show route only';

  @override
  String get tracerouteShowAllNodes => 'Show all nodes';

  @override
  String get mapControlsHeadingUp => 'Heading up';

  @override
  String get mapCompassUnavailable =>
      'Compass sensor not available on this device';

  @override
  String get takBridgeSectionTitle => 'Mesh Bridge';

  @override
  String get takBridgeEnableToggle => 'Enable TAK Mesh Bridge';

  @override
  String get takBridgeEnableSubtitle =>
      'Run an on-device TAK server for direct ATAK/iTAK connections over mesh';

  @override
  String get takBridgeServerPort => 'Server Port';

  @override
  String get takBridgeStatusRunning => 'Running';

  @override
  String get takBridgeStatusStopped => 'Stopped';

  @override
  String takBridgeConnectedClients(int count) {
    return '$count connected';
  }

  @override
  String get takBridgePacketsInbound => 'Mesh → TAK';

  @override
  String get takBridgePacketsOutbound => 'TAK → Mesh';

  @override
  String get takBridgeExportPackage => 'Export Data Package';

  @override
  String get takBridgeExportPackageSubtitle =>
      'Generate connection package for ATAK/iTAK clients';

  @override
  String get takBridgeStatsTitle => 'Bridge Statistics';

  @override
  String get takBridgeClientsTitle => 'Connected Clients';

  @override
  String get takBridgeNoClients => 'No TAK clients connected';

  @override
  String takBridgeClientDuration(String duration) {
    return 'Connected $duration';
  }

  @override
  String get takIdentityRegistryTitle => 'Identity Registry';

  @override
  String get takIdentityNoEntries => 'No identity mappings recorded';

  @override
  String get takIdentityMeshNode => 'Mesh Node';

  @override
  String get takIdentityTakClient => 'TAK Client';

  @override
  String get takIdentityOverrideCallsign => 'Override Callsign';

  @override
  String get takIdentityOverrideHint => 'Enter custom callsign';

  @override
  String get takScreenBridgeOnlyTitle => 'TAK Mesh Bridge';

  @override
  String get takScreenBridgeOnlyDescription =>
      'Use TAK Settings to configure and start the mesh bridge for ATAK/iTAK clients.';

  @override
  String get takScreenBridgeOnlyOpenSettings => 'Open TAK Settings';

  @override
  String get takVideoTitle => 'Live Streams';

  @override
  String get takVideoGoLive => 'Go Live';

  @override
  String get takVideoStreamName => 'Stream Name';

  @override
  String get takVideoCallsign => 'Callsign';

  @override
  String get takVideoStartStream => 'Start Streaming';

  @override
  String get takVideoStopStream => 'Stop Streaming';

  @override
  String get takVideoEndStream => 'End Stream';

  @override
  String get takVideoPreparing => 'Preparing camera...';

  @override
  String get takVideoRegistering => 'Registering stream...';

  @override
  String get takVideoLive => 'LIVE';

  @override
  String get takVideoReconnecting => 'Reconnecting...';

  @override
  String get takVideoFailed => 'Stream failed';

  @override
  String get takVideoEnded => 'Stream ended';

  @override
  String get takVideoIdle => 'Ready to stream';

  @override
  String get takVideoEmptyTitle => 'No Live Streams';

  @override
  String get takVideoEmptyDescription =>
      'There are no active video streams at the moment.';

  @override
  String get takVideoRefresh => 'Refresh';

  @override
  String get takVideoLoading => 'Loading streams...';

  @override
  String takVideoStreamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count live streams',
      one: '1 live stream',
    );
    return '$_temp0';
  }

  @override
  String get takVideoWatchStream => 'Watch Stream';

  @override
  String get takVideoPlayerTitle => 'Live Stream';

  @override
  String get takVideoPlayerLoading => 'Loading stream...';

  @override
  String get takVideoPlayerEnded => 'Stream has ended';

  @override
  String get takVideoPlayerError => 'Playback error';

  @override
  String get takVideoPermissionRequired =>
      'Camera and microphone permissions are required to stream.';

  @override
  String get takVideoAuthRequired => 'Sign in to use video streaming.';

  @override
  String takVideoStreamBy(String callsign) {
    return 'by $callsign';
  }

  @override
  String get takVideoRetry => 'Retry';

  @override
  String get takVideoNewStream => 'New Stream';

  @override
  String get deviceSheetNetwork => 'Network (TCP)';

  @override
  String get networkSectionTitle => 'Network';

  @override
  String get networkSavedEndpoints => 'Saved Endpoints';

  @override
  String get networkNoSavedEndpoints => 'No saved endpoints';

  @override
  String get networkNoSavedEndpointsDescription =>
      'Add an endpoint to connect to a Meshtastic device over the network.';

  @override
  String get networkAddEndpoint => 'Add Endpoint';

  @override
  String get networkHost => 'Host';

  @override
  String get networkHostHint => 'IP address or hostname';

  @override
  String get networkPort => 'Port';

  @override
  String get networkEndpointName => 'Name (optional)';

  @override
  String get networkEndpointNameHint => 'e.g. Living Room Node';

  @override
  String networkConnecting(String address) {
    return 'Connecting to $address...';
  }

  @override
  String networkConnectionFailed(String address) {
    return 'Connection to $address failed';
  }

  @override
  String get networkDnsResolutionFailed => 'Could not resolve hostname';

  @override
  String get networkConnectionTimeout => 'Connection timed out';

  @override
  String get networkConnectionRefused => 'Connection refused';

  @override
  String get networkHostRequired => 'Host is required';

  @override
  String get networkPortInvalid => 'Port must be between 1 and 65535';

  @override
  String get networkDeleteEndpoint => 'Delete Endpoint';

  @override
  String networkDeleteEndpointConfirm(String address) {
    return 'Remove $address from saved endpoints?';
  }

  @override
  String networkLastUsed(String time) {
    return 'Last used $time';
  }

  @override
  String get scannerTabBluetooth => 'Bluetooth';

  @override
  String get scannerTabNetwork => 'Network';

  @override
  String get mdnsDiscoveredRadios => 'Wi-Fi Radios';

  @override
  String get mdnsNoDevicesFound => 'No Wi-Fi radios found';

  @override
  String get mdnsNoDevicesDescription =>
      'Meshtastic devices with WiFi enabled will appear here automatically.';

  @override
  String get mdnsConnecting => 'Connecting…';

  @override
  String get mdnsTransportTcp => 'TCP';

  @override
  String get mdnsScanning => 'Scanning…';

  @override
  String get settingsNetworkEndpointsTitle => 'Network Endpoints';

  @override
  String get settingsTileNetworkEndpointsTitle => 'Network Endpoints';

  @override
  String get settingsTileNetworkEndpointsSubtitle =>
      'Manage saved TCP endpoints and discover Wi-Fi radios';

  @override
  String get navigationMeshIncidents => 'Mesh Incidents';

  @override
  String get meshIncidentListTitle => 'Mesh Incidents';

  @override
  String get meshIncidentDetailTitle => 'Incident Detail';

  @override
  String get meshIncidentComposerTitle => 'Report Incident';

  @override
  String get meshIncidentComposerUpdateTitle => 'Update Incident';

  @override
  String get meshIncidentComposerCorrectionTitle => 'Correct Report';

  @override
  String get meshIncidentEmptyTitle => 'No Mesh Incidents';

  @override
  String get meshIncidentEmptyDescription =>
      'Incident reports from the mesh network will appear here. Tap the button to create a new report.';

  @override
  String get meshIncidentEmptyTagline1 => 'Report incidents across the mesh';

  @override
  String get meshIncidentEmptyTagline2 => 'Coordinate responses in real-time';

  @override
  String get meshIncidentEmptyTagline3 => 'Track situation awareness off-grid';

  @override
  String get meshIncidentCreateButton => 'Create Report';

  @override
  String get meshIncidentSendButton => 'Send Report';

  @override
  String get meshIncidentSendUpdateButton => 'Send Update';

  @override
  String get meshIncidentSendCorrectionButton => 'Send Correction';

  @override
  String get meshIncidentClassificationLabel => 'Classification';

  @override
  String get meshIncidentPriorityLabel => 'Priority';

  @override
  String get meshIncidentConfidenceLabel => 'Confidence';

  @override
  String get meshIncidentRoleLabel => 'Your Role';

  @override
  String get meshIncidentBodyLabel => 'Summary';

  @override
  String get meshIncidentBodyHint => 'Describe the situation concisely';

  @override
  String get meshIncidentBodyRequired => 'Summary is required';

  @override
  String get meshIncidentLocationLabel => 'Include Location';

  @override
  String get meshIncidentConfidenceUnconfirmed => 'Unconfirmed';

  @override
  String get meshIncidentConfidenceProbable => 'Probable';

  @override
  String get meshIncidentConfidenceConfirmed => 'Confirmed';

  @override
  String get meshIncidentRoleObserver => 'Observer';

  @override
  String get meshIncidentRoleOperator => 'Operator';

  @override
  String get meshIncidentRoleSupervisor => 'Supervisor';

  @override
  String get meshIncidentRoleAdmin => 'Admin';

  @override
  String get meshIncidentStatusReported => 'Reported';

  @override
  String get meshIncidentStatusActive => 'Active';

  @override
  String get meshIncidentStatusContained => 'Contained';

  @override
  String get meshIncidentStatusResolved => 'Resolved';

  @override
  String get meshIncidentStatusCancelled => 'Cancelled';

  @override
  String get meshIncidentUpdateTypeInitial => 'Initial Report';

  @override
  String get meshIncidentUpdateTypeUpdate => 'Update';

  @override
  String get meshIncidentUpdateTypeCorrection => 'Correction';

  @override
  String get meshIncidentUpdateTypeClosure => 'Closure';

  @override
  String meshIncidentCaseId(String caseId) {
    return 'Case $caseId';
  }

  @override
  String meshIncidentReportCount(int count) {
    return '$count reports';
  }

  @override
  String meshIncidentContributors(int count) {
    return '$count contributors';
  }

  @override
  String get meshIncidentTimelineTitle => 'Timeline';

  @override
  String get meshIncidentSuperseded => 'Superseded';

  @override
  String get meshIncidentCorrectionBadge => 'Correction';

  @override
  String get meshIncidentSentSuccess => 'Report sent over mesh';

  @override
  String get meshIncidentSendFailed => 'Failed to send report';

  @override
  String meshIncidentPayloadSize(int bytes) {
    return '$bytes bytes';
  }

  @override
  String meshIncidentFromNode(String nodeId) {
    return 'Node $nodeId';
  }

  @override
  String get meshIncidentCloseCase => 'Close Case';

  @override
  String get meshIncidentAddUpdate => 'Add Update';

  @override
  String get meshIncidentCorrectReport => 'Correct Report';

  @override
  String get meshIncidentHandoffTitle => 'Handoff Summary';

  @override
  String get meshIncidentLocationCoarse => 'Approx. location';

  @override
  String get translateAction => 'Translate';

  @override
  String get translateLabel => 'Translated';

  @override
  String get translateLoading => 'Translating…';

  @override
  String get translateAuthRequired => 'Sign in or add an API key to translate';

  @override
  String get translateFailed => 'Translation failed';

  @override
  String get translateRateLimited =>
      'Too many translations — try again shortly';

  @override
  String get translateUnsupportedLanguage =>
      'Language not supported for translation';

  @override
  String get translateRetry => 'Retry';

  @override
  String get translateRequiresInternet => 'Translation requires internet';

  @override
  String translateFromLanguage(String language) {
    return 'Translated from $language';
  }

  @override
  String get premiumPreviewTranslation =>
      'Preview Mode — Upgrade to translate messages';

  @override
  String get premiumHeadlineTranslation => 'Translate Messages';

  @override
  String get premiumDescTranslation =>
      'Unlock on-demand message translation with smart caching and privacy controls — includes managed allowance, or bring your own API key';

  @override
  String get premiumSubtitleTranslation =>
      'Break language barriers on your mesh network';

  @override
  String get premiumBenefitInstantTranslation => 'One-Tap Translation';

  @override
  String get premiumBenefitInstantTranslationDesc =>
      'Translate any message in channels or DMs with a single tap';

  @override
  String get premiumBenefitAutoDetect => 'Auto-Detect Language';

  @override
  String get premiumBenefitAutoDetectDesc =>
      'Automatically detects the source language — no manual selection needed';

  @override
  String get premiumBenefitSmartCache => 'Smart Caching';

  @override
  String get premiumBenefitSmartCacheDesc =>
      'Translations are cached locally so you only pay for each message once';

  @override
  String get translateQuotaExhausted =>
      'Managed translation allowance used — switch to your own OpenAI API key in settings';

  @override
  String get translatePrivacyBlocked =>
      'Strict privacy mode blocks managed OpenAI translation';

  @override
  String get translateProviderDisabled => 'Translation provider is disabled';

  @override
  String get translateByoKeyMissing =>
      'BYO API key required — configure in settings';

  @override
  String get translateContentIneligible => 'This content cannot be translated';

  @override
  String get subscriptionFeaturedTranslationSubtitleRefactored =>
      'On-demand translation with smart caching, privacy controls, and BYO provider support';

  @override
  String get subscriptionTranslationWithAllowance =>
      'On-demand translation with managed allowance';

  @override
  String get subscriptionCompletePackSubtitleWithTranslation =>
      'Every feature, one price — including translation';

  @override
  String get translationSettingsTitle => 'Translation';

  @override
  String get translationSettingsProviderModeLabel => 'Provider Mode';

  @override
  String get translationSettingsProviderManaged => 'Managed';

  @override
  String get translationSettingsProviderManagedDesc =>
      'Managed OpenAI translation — included allowance';

  @override
  String get translationSettingsProviderByo => 'Bring Your Own Key';

  @override
  String get translationSettingsProviderByoDesc =>
      'Use your own OpenAI API key — unlimited';

  @override
  String get translationSettingsProviderDisabled => 'Disabled';

  @override
  String get translationSettingsProviderDisabledDesc =>
      'Translation is turned off';

  @override
  String get translationSettingsPrivacyModeLabel => 'Privacy Mode';

  @override
  String get translationSettingsPrivacyStandard => 'Standard';

  @override
  String get translationSettingsPrivacyStandardDesc =>
      'Cache translations locally for fast reuse';

  @override
  String get translationSettingsPrivacyPrivate => 'Private';

  @override
  String get translationSettingsPrivacyPrivateDesc =>
      'Cache channels only — DM translations are not stored';

  @override
  String get translationSettingsPrivacyStrict => 'Strict';

  @override
  String get translationSettingsPrivacyStrictDesc =>
      'BYO provider only — no caching, no managed server';

  @override
  String get translationSettingsByoKeyLabel => 'API Key';

  @override
  String get translationSettingsByoKeyHint => 'Enter your OpenAI API key';

  @override
  String get translationSettingsByoKeySaved => 'API key saved securely';

  @override
  String get translationSettingsByoKeyRemoved => 'API key removed';

  @override
  String get translationSettingsByoKeyStored => 'Key stored';

  @override
  String get translationSettingsByoKeyNone => 'No key set';

  @override
  String get translationSettingsByoKeyRemove => 'Remove Key';

  @override
  String get translationSettingsByoKeyRemoveConfirmTitle => 'Remove API Key?';

  @override
  String get translationSettingsByoKeyRemoveConfirmMessage =>
      'Your OpenAI API key will be permanently deleted from this device. You can add a new key at any time.';

  @override
  String get translationSettingsQuotaLabel => 'Managed Allowance';

  @override
  String translationSettingsQuotaRemaining(int used, int limit) {
    return '$used of $limit characters used';
  }

  @override
  String translationSettingsQuotaResetsAt(String date) {
    return 'Resets $date';
  }

  @override
  String get translationSettingsClearCache => 'Clear Translation Cache';

  @override
  String get translationSettingsCacheCleared => 'Translation cache cleared';

  @override
  String get translationSettingsSearchTitle => 'Translation Settings';

  @override
  String get translationSettingsSearchSubtitle =>
      'Provider mode, privacy, API key, cache';

  @override
  String get translationSettingsClearCacheConfirm =>
      'Clear all cached translations? This cannot be undone.';

  @override
  String get translationSettingsClearCacheConfirmAction => 'Clear Cache';

  @override
  String get translationSettingsByoTestConnection => 'Test OpenAI Connection';

  @override
  String get translationSettingsByoTestSuccess => 'OpenAI API key is valid';

  @override
  String get translationSettingsByoTestFailed => 'Invalid OpenAI API key';

  @override
  String get translationSettingsByoTestTesting => 'Testing…';

  @override
  String get translationSettingsQuotaOpenSettings => 'Open Settings';

  @override
  String avatarStackCoSeenLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recent co-seen nodes',
      one: '1 recent co-seen node',
    );
    return '$_temp0';
  }

  @override
  String avatarStackNodeTooltip(String name) {
    return '$name';
  }

  @override
  String avatarStackOverflowLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String get nodedexCoSeenCardTitle => 'Recent Co-Seen';

  @override
  String nodedexCoSeenCardSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes heard with this node recently',
      one: '1 node heard with this node recently',
    );
    return '$_temp0';
  }

  @override
  String get nodedexCoSeenCardViewAll => 'View recent links';

  @override
  String get nearbyTitle => 'Nearby';

  @override
  String get nearbySubtitle => 'People and devices on the mesh';

  @override
  String get nearbyScanButton => 'Look for people';

  @override
  String get nearbyScanningLabel => 'Looking for people nearby…';

  @override
  String nearbyScanCooldownLabel(int seconds) {
    return 'Scan again in ${seconds}s';
  }

  @override
  String get nearbyPersonAnonymous => 'Mesh User';

  @override
  String get nearbyStatusNow => 'Nearby now';

  @override
  String nearbyStatusMinutesAgo(int count) {
    return 'Seen $count min ago';
  }

  @override
  String nearbyStatusHoursAgo(int count) {
    return 'Seen ${count}h ago';
  }

  @override
  String get nearbyEmptyTitle => 'No one nearby yet';

  @override
  String get nearbyEmptyDescription =>
      'Tap “Look for people” to find other Socialmesh users on the mesh';

  @override
  String get nearbyEmptyTagline1 => 'Listening for nearby users…';

  @override
  String get nearbyEmptyTagline2 => 'Tap Look for people to send a signal…';

  @override
  String get nearbyEmptyTagline3 => 'Others will appear here when found…';

  @override
  String get nearbyEmptyTagline4 => 'Keep the app open to discover more…';

  @override
  String get nearbyDevicePhone => 'Phone';

  @override
  String get nearbyDeviceTablet => 'Tablet';

  @override
  String get nearbyDeviceDesktop => 'Desktop';

  @override
  String get nearbyDeviceUnknown => 'Device';

  @override
  String get nearbySectionPeople => 'People';

  @override
  String get nearbySectionConversations => 'Conversations';

  @override
  String get nearbySectionRequests => 'Connection requests';

  @override
  String get connectionRequestConnect => 'Connect';

  @override
  String get connectionStateConnecting => 'Connecting…';

  @override
  String get connectionStateConnected => 'Connected';

  @override
  String get connectionStatePending => 'Request sent';

  @override
  String get connectionStateDeclined => 'Declined';

  @override
  String get connectionStateFailed => 'Could not connect';

  @override
  String get connectionStateTimedOut => 'No response';

  @override
  String connectionIncomingTitle(String name) {
    return '$name wants to connect';
  }

  @override
  String get connectionAcceptButton => 'Accept';

  @override
  String get connectionDeclineButton => 'Decline';

  @override
  String get contactExchangeTitle => 'Share contact card';

  @override
  String get contactExchangeDescription =>
      'Exchange identity with a nearby person so you can message each other';

  @override
  String get contactExchangeShareButton => 'Share my contact';

  @override
  String get contactExchangeShared => 'Contact shared';

  @override
  String get meshConversationTitle => 'Mesh message';

  @override
  String meshConversationExpiry(String time) {
    return 'Expires in $time';
  }

  @override
  String get meshConversationPinned => 'Pinned';

  @override
  String get meshConversationInputHint => 'Message…';

  @override
  String get meshConversationBudgetExhausted =>
      'Sending paused — mesh bandwidth limit reached. Try again shortly.';

  @override
  String get meshConversationClosed => 'This conversation has ended.';

  @override
  String get meshConversationReadyToChat => 'Ready to chat';

  @override
  String get deliveryPhasePreparing => 'Preparing';

  @override
  String get deliveryPhasePreparingDesc =>
      'Getting your data ready to send over the mesh.';

  @override
  String get deliveryPhaseSending => 'Sending';

  @override
  String get deliveryPhaseSendingDesc => 'Sending to the mesh network.';

  @override
  String get deliveryPhaseSentToMesh => 'Sent to mesh';

  @override
  String get deliveryPhaseSentToMeshDesc =>
      'Your data is on the mesh and being relayed.';

  @override
  String get deliveryPhaseWaitingForPath => 'Waiting for path';

  @override
  String get deliveryPhaseWaitingForPathDesc =>
      'The mesh hasn’t found a route yet. Delivery will continue automatically.';

  @override
  String get deliveryPhaseDelivering => 'Delivering';

  @override
  String get deliveryPhaseDeliveringDesc =>
      'Your data is being relayed through the mesh.';

  @override
  String get deliveryPhasePartiallyDelivered => 'Partially delivered';

  @override
  String get deliveryPhasePartiallyDeliveredDesc =>
      'Some parts arrived. The rest will resume when the connection improves.';

  @override
  String get deliveryPhaseRetrying => 'Retrying';

  @override
  String get deliveryPhaseRetryingDesc =>
      'Retrying automatically — no action needed.';

  @override
  String get deliveryPhaseResuming => 'Resuming';

  @override
  String get deliveryPhaseResumingDesc => 'Picking up where it left off.';

  @override
  String get deliveryPhaseDelivered => 'Delivered';

  @override
  String get deliveryPhaseDeliveredDesc =>
      'Everything arrived at its destination.';

  @override
  String get deliveryPhaseVerified => 'Verified';

  @override
  String get deliveryPhaseVerifiedDesc =>
      'Everything arrived correctly and has been verified.';

  @override
  String get deliveryPhaseNeedsAttention => 'Needs attention';

  @override
  String get deliveryPhaseNeedsAttentionDesc =>
      'Something needs your attention to continue.';

  @override
  String get deliveryPhaseFailed => 'Failed';

  @override
  String get deliveryPhaseFailedDesc =>
      'The request timed out before a response was received.';

  @override
  String deliveryPhaseFailedDescRetried(int attempts) {
    return 'The request timed out after $attempts attempts.';
  }

  @override
  String get deliverySafeToClose =>
      'Safe to close — delivery continues in the background';

  @override
  String get deliverySafeToLeave => 'You can leave — transfer will continue';

  @override
  String deliveryProgressParts(int current, int total) {
    return '$current of $total parts';
  }

  @override
  String get deliveryExpertToggle => 'Show delivery details';

  @override
  String get guidedFlowNext => 'Next';

  @override
  String get guidedFlowBack => 'Back';

  @override
  String get guidedFlowDone => 'Done';

  @override
  String get guidedFlowCreate => 'Create';

  @override
  String get guidedFlowContinue => 'Write it';

  @override
  String get guidedFlowCancel => 'Cancel';

  @override
  String get serviceWizardTitle => 'Share on the mesh';

  @override
  String get serviceWizardStepWhat => 'Intent';

  @override
  String get serviceWizardStepPreset => 'Template';

  @override
  String get serviceWizardStepWho => 'Who';

  @override
  String get serviceWizardStepDetails => 'Details';

  @override
  String get serviceWizardStepReview => 'Preview';

  @override
  String get serviceWizardWhatTitle => 'What are you sharing?';

  @override
  String get serviceWizardWhatSubtitle =>
      'Start with the kind of thing you want to put out nearby.';

  @override
  String get serviceWizardPresetTitle => 'Choose a starting point';

  @override
  String get serviceWizardPresetSubtitle =>
      'Templates give you a head start without changing what the share can do.';

  @override
  String get serviceWizardPresetGeneric => 'Start from scratch';

  @override
  String get serviceWizardPresetGenericDescription =>
      'Use the basic layout and shape it yourself.';

  @override
  String get serviceWizardWhoTitle => 'Who can see it?';

  @override
  String get serviceWizardWhoSubtitle =>
      'Choose who will be able to discover and use your service';

  @override
  String get serviceWizardAudienceAnyone => 'Anyone nearby';

  @override
  String get serviceWizardAudienceAnyoneDesc =>
      'Anyone on the mesh can discover and use this';

  @override
  String get serviceWizardAudienceContacts => 'Approved contacts only';

  @override
  String get serviceWizardAudienceContactsDesc =>
      'Only people you’ve exchanged contacts with';

  @override
  String get serviceWizardReviewTitle => 'Before you write';

  @override
  String get serviceWizardReviewSubtitle =>
      'This is the shape of the share you’re about to compose.';

  @override
  String get serviceWizardReviewType => 'You’re sharing';

  @override
  String get serviceWizardReviewPreset => 'Starting point';

  @override
  String get serviceWizardReviewAudience => 'Audience';

  @override
  String get serviceWizardReviewMeshHint =>
      'People nearby will discover the headline first, then open the full details.';

  @override
  String get meshServicesPreviewCardTitle => 'Live preview';

  @override
  String get meshServicesPreviewCardDescription =>
      'This is the kind of card nearby people will open.';

  @override
  String get meshServicesPreviewPlaceholder => 'Your headline will show here';

  @override
  String get meshServicesPreviewNoDetails =>
      'Add a few details so people nearby know what this is.';

  @override
  String get meshServicesAdvancedDetails => 'Sharing details';

  @override
  String get meshServicesAdvancedDurationHint =>
      'You can change how long this stays visible on the mesh.';

  @override
  String get serviceDetailHeaderEyebrow => 'Shared nearby';

  @override
  String get serviceDetailHeaderBody =>
      'Open the items this nearby radio is sharing right now.';

  @override
  String get serviceDetailSectionLiveNow => 'Shared right now';

  @override
  String get meshServicesNetworkDetails => 'Network details';

  @override
  String meshServicesNetworkNode(String nodeId) {
    return 'From node $nodeId';
  }

  @override
  String meshServicesNetworkServiceType(String serviceType) {
    return 'Share type: $serviceType';
  }

  @override
  String meshServicesNetworkServiceId(String serviceId) {
    return 'Service ID: $serviceId';
  }

  @override
  String get meshServicesSharedByAnonymous => 'Shared by someone nearby';

  @override
  String meshServicesSharedByPerson(String name) {
    return 'Shared by $name';
  }

  @override
  String meshServicesVisibleFor(String time) {
    return 'Visible for $time';
  }

  @override
  String get meshServicesEyebrowFeed => 'Nearby update';

  @override
  String get meshServicesEyebrowList => 'Shared checklist';

  @override
  String get meshServicesEyebrowPoll => 'Nearby question';

  @override
  String get meshServicesEyebrowSignal => 'Active alert';

  @override
  String get meshServicesEyebrowSensor => 'Live reading';

  @override
  String get meshServicesOpenFeedAction => 'Read update';

  @override
  String get meshServicesOpenListAction => 'Open checklist';

  @override
  String get meshServicesOpenPollAction => 'Answer question';

  @override
  String get meshServicesOpenSignalAction => 'View alert';

  @override
  String get meshServicesOpenSensorAction => 'Check reading';

  @override
  String meshServicesItemsCount(int count) {
    return '$count items';
  }

  @override
  String meshServicesChoicesCount(int count) {
    return '$count choices';
  }

  @override
  String meshServicesListProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String meshServicesMoreItemsCount(int count) {
    return '$count more items';
  }

  @override
  String get meshServicesPollNoVotes => 'No votes yet';

  @override
  String meshServicesPollVotesCount(int count) {
    return '$count votes';
  }

  @override
  String get meshServicesSignalKindCheckIn => 'Check-in';

  @override
  String get meshServicesSignalKindNeedHelp => 'Need help';

  @override
  String get meshServicesSignalKindHazard => 'Hazard';

  @override
  String get meshServicesSignalKindMeetHere => 'Meet here';

  @override
  String get meshServicesSignalKindRelayActive => 'Relay active';

  @override
  String get meshServicesSignalActiveLabel => 'Active now';

  @override
  String get meshServicesFieldSensorName => 'Reading name';

  @override
  String get meshServicesFieldSensorValue => 'Reading';

  @override
  String get meshServicesSensorValueHint => '23.4';

  @override
  String get meshServicesMinSensorValue => 'Add a reading before sharing.';

  @override
  String get meshServicesFieldSensorUnit => 'Unit';

  @override
  String get meshServicesSensorUnitHint => '°C, %, m';

  @override
  String get meshServicesFieldSensorSource => 'Source';

  @override
  String get meshServicesSensorSourceHint => 'Trail marker, station, or node';

  @override
  String get meshServicesSensorUnknownValue => 'No reading yet';

  @override
  String meshServicesSensorUpdatedLabel(String time) {
    return 'Updated $time';
  }

  @override
  String get serviceWizardCompletionHeadline => 'Your service is live';

  @override
  String get serviceWizardCompletionDescription =>
      'Other mesh users can now discover and interact with your service. You can manage it from My Services.';

  @override
  String get serviceWizardCompletionViewServices => 'View my services';

  @override
  String get serviceWizardCompletionCreateAnother => 'Create another';

  @override
  String get peerDetailLastSeenJustNow => 'Just now';

  @override
  String get peerDetailCapabilities => 'What they support';

  @override
  String get peerDetailCapIdentity => 'Identity & secure connection';

  @override
  String get peerDetailCapExchange => 'Contact exchange';

  @override
  String get peerDetailDeviceType => 'Device type';

  @override
  String get nearbyAutoScanEnabled => 'Auto-discovery on';

  @override
  String get nearbyAutoScanDisabled => 'Auto-discovery off';

  @override
  String get disclosureBasic => 'Simple view';

  @override
  String get disclosureCurious => 'More detail';

  @override
  String get disclosureExpert => 'Full diagnostics';

  @override
  String get messagingWeekView => 'Week View';

  @override
  String get messageTimelineTitle => 'Message Activity';

  @override
  String get messageTimelineEmpty => 'No message activity this week';

  @override
  String get messageTimelineEmptyDescription =>
      'Messages and channel activity will appear here as they happen';

  @override
  String get messageTimelineShowAll => 'Show all activity';

  @override
  String get messageTimelineFilterDm => 'Direct';

  @override
  String get messageTimelineFilterChannel => 'Channels';

  @override
  String get messageTimelineFilterAll => 'All';

  @override
  String messageTimelineSessionMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String messageTimelineChannelPrefix(String name) {
    return 'Ch: $name';
  }

  @override
  String messageTimelineDmWith(String name) {
    return 'DM with $name';
  }

  @override
  String get messageTimelineDetailType => 'Type';

  @override
  String get messageTimelineDetailTypeDm => 'Direct message';

  @override
  String get messageTimelineDetailTypeChannel => 'Channel';

  @override
  String get messageTimelineDetailTime => 'Time';

  @override
  String get messageTimelineDetailDuration => 'Duration';

  @override
  String messageTimelineDetailDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String get messageTimelineDetailMessages => 'Messages';

  @override
  String get messageTimelineDetailParticipants => 'Participants';

  @override
  String get messageTimelineDetailOpenChat => 'Open conversation';
}
