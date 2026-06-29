// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Bude Inventory';

  @override
  String get dashboard => 'Dashboard';

  @override
  String welcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String get scan => 'Scan';

  @override
  String get searchItems => 'Search Items';

  @override
  String get transfer => 'Transfer';

  @override
  String get receive => 'Receive';

  @override
  String get count => 'Count';

  @override
  String get settings => 'Settings';

  @override
  String get stockTransfer => 'Stock transfer';

  @override
  String get receiveStock => 'Receive stock';

  @override
  String get stockCount => 'Stock count';

  @override
  String get sourceWarehouse => 'Source warehouse';

  @override
  String get targetWarehouse => 'Target warehouse';

  @override
  String get warehouse => 'Warehouse';

  @override
  String get sourceLocation => 'Source location';

  @override
  String get targetLocation => 'Target location';

  @override
  String get countLocation => 'Count location';

  @override
  String locationsCount(int count) {
    return 'Locations ($count)';
  }

  @override
  String get scanToAdd => 'Scan to add';

  @override
  String get queueTransfer => 'Queue transfer';

  @override
  String get queueReceipt => 'Queue receipt';

  @override
  String get queueCount => 'Queue count';

  @override
  String get againstPo => 'Against PO (optional)';

  @override
  String get noItemsYet => 'No items yet — scan or add manually.';

  @override
  String get scanItemsToCount => 'Scan items to start counting.';

  @override
  String get pickWarehouseFirst => 'Pick a warehouse first.';

  @override
  String countedItems(int count) {
    return 'Counted items ($count)';
  }

  @override
  String items(int count) {
    return 'Items ($count)';
  }

  @override
  String get itemNotFound => 'No item found for this barcode';

  @override
  String transferQueued(String id) {
    return 'Transfer queued (op $id). Watch /sync for status.';
  }

  @override
  String receiptQueued(String id) {
    return 'Receipt queued (op $id). Watch /sync for status.';
  }

  @override
  String countQueued(String id) {
    return 'Count queued (op $id). Watch /sync for status.';
  }

  @override
  String get openSync => 'Open sync';

  @override
  String get sourceTargetMustDiffer => 'Source and target must differ.';

  @override
  String get changingWarehouseClearsCount =>
      'Changing this clears the current count.';

  @override
  String failedToLoadWarehouses(String error) {
    return 'Failed to load warehouses: $error';
  }

  @override
  String couldNotLoadPOs(String error) {
    return 'Could not load POs: $error';
  }

  @override
  String get offline => 'Offline';

  @override
  String get offlineMessage =>
      'You\'re offline — changes will sync when connected';

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncComplete => 'Synced';

  @override
  String pendingOps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending operations',
      one: '1 pending operation',
      zero: 'No pending operations',
    );
    return '$_temp0';
  }

  @override
  String get syncNonePending => 'Sync (none pending)';

  @override
  String syncPending(int count) {
    return 'Sync ($count pending)';
  }

  @override
  String get logout => 'Logout';

  @override
  String get signOut => 'Sign out';

  @override
  String get resetConnection => 'Reset connection';

  @override
  String get resetConnectionTitle => 'Reset connection?';

  @override
  String get resetConnectionMessage =>
      'This signs you out and removes the saved server. You will be sent back to setup.';

  @override
  String get cancel => 'Cancel';

  @override
  String get reset => 'Reset';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeSmall => 'S';

  @override
  String get textSizeMedium => 'M';

  @override
  String get textSizeLarge => 'L';

  @override
  String get highContrast => 'High contrast';

  @override
  String get connection => 'Connection';

  @override
  String get company => 'Company';

  @override
  String get erpUrl => 'ERP URL';

  @override
  String get connectedSince => 'Connected since';

  @override
  String get erpnextVersion => 'ERPNext';

  @override
  String get budeApiVersion => 'bude_api';

  @override
  String get defaults => 'Defaults';

  @override
  String get defaultSourceWarehouse => 'Default source warehouse';

  @override
  String get defaultTargetWarehouse => 'Default target warehouse';

  @override
  String get noneSelected => '— none —';

  @override
  String get scanning => 'Scanning';

  @override
  String get scanSound => 'Scan sound';

  @override
  String get scanVibration => 'Scan vibration';

  @override
  String get continuousScanMode => 'Continuous scan mode';

  @override
  String get syncAndOffline => 'Sync & Offline';

  @override
  String get syncInterval => 'Sync interval';

  @override
  String syncIntervalMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get wifiOnlySync => 'Sync on Wi-Fi only';

  @override
  String get forceFullResync => 'Force full resync';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get appVersion => 'App version';

  @override
  String get account => 'Account';

  @override
  String get currentConnection => 'Current connection';

  @override
  String get noConnectionConfigured => 'No connection configured.';

  @override
  String get setUpNow => 'Set up now';

  @override
  String get emptyQueue => 'No pending operations';

  @override
  String get emptyQueueSubtitle => 'All changes have been synced.';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get tryScanningBarcode =>
      'Try scanning a barcode or enter a different search term.';

  @override
  String get recentlyUsed => 'Recently used';

  @override
  String get autoLogoutDisabled => 'Disabled';

  @override
  String autoLogoutMinutes(int minutes) {
    return 'Auto-logout: $minutes min';
  }

  @override
  String get stockTab => 'Stock';

  @override
  String get historyTab => 'History';

  @override
  String get movementHistory => 'Movement history';

  @override
  String get noMovementHistory => 'No movement history';

  @override
  String get noMovementHistorySubtitle =>
      'Transactions will appear here once this item has been moved.';

  @override
  String balanceAfter(String qty) {
    return 'Balance after: $qty';
  }

  @override
  String get warehouses => 'Warehouses';

  @override
  String get warehouseStock => 'Warehouse stock';

  @override
  String get noWarehousesFound => 'No warehouses found';

  @override
  String get noWarehousesFoundSubtitle =>
      'Check your ERPNext connection or add warehouses in ERPNext.';

  @override
  String get noStockInWarehouse => 'No stock in this warehouse';

  @override
  String get noStockInWarehouseSubtitle =>
      'Items will appear here once stock has been received.';

  @override
  String totalItems(int count) {
    return 'Total items: $count';
  }

  @override
  String get actualQty => 'Actual';

  @override
  String get reservedQty => 'Reserved';

  @override
  String get projectedQty => 'Projected';

  @override
  String get scanSession => 'Scan session';

  @override
  String get startScanSession => 'Start scan session';

  @override
  String useNItems(int count) {
    return 'Use $count items';
  }

  @override
  String get scanningActive => 'Scanning…';

  @override
  String get resolving => 'Resolving…';

  @override
  String itemAdded(String name) {
    return 'Added: $name';
  }

  @override
  String get barcodeNotFound => 'Barcode not found';

  @override
  String get analytics => 'Analytics';

  @override
  String get stockAging => 'Stock Aging';

  @override
  String get stockAgingSubtitle => 'Items with no recent movement';

  @override
  String get thresholdDays => 'Idle threshold';

  @override
  String daysIdle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days idle',
      one: '1 day idle',
    );
    return '$_temp0';
  }

  @override
  String lastMovedDate(String date) {
    return 'Last moved $date';
  }

  @override
  String get neverMoved => 'Never moved';

  @override
  String get noIdleItems => 'No idle items';

  @override
  String get noIdleItemsSubtitle =>
      'All items moved within the selected threshold.';

  @override
  String get varianceDashboard => 'Variance Dashboard';

  @override
  String get varianceDashboardSubtitle => 'Reconciliation vs expected qty';

  @override
  String get reconciliationHistory => 'Reconciliation History';

  @override
  String get counted => 'Counted';

  @override
  String get expected => 'Expected';

  @override
  String get noReconciliations => 'No reconciliations found';

  @override
  String get noReconciliationsSubtitle =>
      'Submitted stock counts will appear here.';

  @override
  String get throughput => 'Throughput';

  @override
  String get throughputSubtitle => 'Operation activity over time';

  @override
  String get operationThroughput => 'Operation Throughput';

  @override
  String get totalOps => 'Total ops';

  @override
  String get successRate => 'Success rate';

  @override
  String get mostActiveDay => 'Most active day';

  @override
  String get last7Days => '7 days';

  @override
  String get last14Days => '14 days';

  @override
  String get last30Days => '30 days';

  @override
  String get noOpsYet => 'No operations yet';

  @override
  String get noOpsYetSubtitle =>
      'Queue a transfer, receipt, or count to see throughput data.';

  @override
  String get exportDataSubtitle => 'Download stock or ledger as CSV';

  @override
  String get exportData => 'Export Data';

  @override
  String get exportType => 'Export type';

  @override
  String get itemLedger => 'Item ledger';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exporting => 'Exporting…';

  @override
  String get exportComplete => 'Export ready';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get auditTrail => 'Audit Trail';

  @override
  String get auditTrailSubtitle => 'All submitted operations on this device';

  @override
  String get all => 'All';

  @override
  String get stockTransferLabel => 'Stock Transfer';

  @override
  String get goodsReceiptLabel => 'Goods Receipt';

  @override
  String get stockCountLabel => 'Stock Count';

  @override
  String get noAuditOps => 'No operations yet';

  @override
  String get noAuditOpsSubtitle => 'Completed operations will appear here.';

  @override
  String get viewInErp => 'View in ERP';

  @override
  String get activeCompany => 'Active Company';

  @override
  String get selectCompany => 'Select company';

  @override
  String get selectCompanyBeforeWarehouses =>
      'Select a company before choosing warehouses.';

  @override
  String get noCompanies => 'No companies found';

  @override
  String get varianceThreshold => 'Variance approval threshold (units)';

  @override
  String get varianceThresholdHint => '0 = disabled';

  @override
  String get autoLogout => 'Auto-logout';

  @override
  String get unlockApp => 'Unlock to continue';

  @override
  String get sessionLocked => 'Session Locked';

  @override
  String get approvalRequired => 'Supervisor Approval Required';

  @override
  String approvalRequiredSubtitle(String qty) {
    return 'Total variance of $qty units exceeds the approval threshold.';
  }

  @override
  String get approveWithBiometric => 'Approve with Biometric / PIN';

  @override
  String get approvalGranted => 'Approved — operation queued.';

  @override
  String get approvalFailed => 'Biometric failed — approval not granted.';

  @override
  String get pendingApprovalStatus => 'Awaiting Approval';

  @override
  String get filterItems => 'Filter items';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get loadMore => 'Load more';

  @override
  String get removeItem => 'Remove item';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get findItemFast => 'Find an item fast';

  @override
  String get searchWithinFilters => 'Search within filters';

  @override
  String get searchFilteredCatalogHint =>
      'Type a code, name, or barcode to search the filtered catalog.';

  @override
  String get searchItemsDetailedHint =>
      'Search by item code, item name, barcode, or scan from the camera.';

  @override
  String noItemsMatch(String query) {
    return 'No items match \"$query\"';
  }

  @override
  String get noItemsWithActiveFilters => 'No items match active filters';

  @override
  String get adjustSearchOrFilters => 'Try another term or adjust filters.';

  @override
  String get disabledStatus => 'Disabled';

  @override
  String get undoLastScan => 'Undo last scan';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get scanningActiveSubtitle =>
      'Keep scanning. New items will appear here instantly.';

  @override
  String get resolvingScan => 'Resolving scan';

  @override
  String get scannerReady => 'Scanner ready';

  @override
  String get cameraView => 'Camera view';

  @override
  String get hardwareStream => 'Hardware stream';

  @override
  String get totalQty => 'Total qty';

  @override
  String get lines => 'Lines';

  @override
  String get itemsLabel => 'Items';

  @override
  String get ready => 'Ready';

  @override
  String get needsDetails => 'Needs details';

  @override
  String get needsWarehouse => 'Needs warehouse';

  @override
  String get stockTransferSubtitle => 'Move scanned stock between warehouses.';

  @override
  String get receiveStockSubtitle =>
      'Receive scanned stock into a target warehouse.';

  @override
  String get stockCountSubtitle =>
      'Count scanned stock and review variance before queueing.';

  @override
  String get startScanTransferLines =>
      'Start a scan session to add transfer lines.';

  @override
  String get startScanReceiptLines => 'Start a scan session as goods arrive.';

  @override
  String get pickWarehouseFirstSubtitle =>
      'Choose the counting warehouse before scanning items.';

  @override
  String get startScanCountSubtitle =>
      'Start a scan session to build this count.';

  @override
  String get freeReceipt => 'Free receipt';

  @override
  String get purchaseOrderShort => 'PO';

  @override
  String expectedQtyShort(String qty) {
    return 'Expected $qty';
  }

  @override
  String varianceQtyShort(String qty) {
    return 'Variance $qty';
  }

  @override
  String get syncClear => 'Sync clear';

  @override
  String pendingCountShort(int count) {
    return '$count pending';
  }

  @override
  String get noAlerts => 'No alerts';

  @override
  String alertsCountShort(int count) {
    return '$count alerts';
  }

  @override
  String get noDefaultWarehouse => 'No default';

  @override
  String get itemActions => 'Item actions';

  @override
  String itemAddedToDraft(String item) {
    return 'Added $item to draft';
  }

  @override
  String alreadyInDraft(String item) {
    return '$item already in draft';
  }

  @override
  String pickWarehouseToCountItem(String item) {
    return 'Pick warehouse to count $item';
  }

  @override
  String get needsSource => 'Needs source';

  @override
  String get needsTarget => 'Needs target';

  @override
  String get needsItems => 'Needs items';

  @override
  String get poOptional => 'PO optional';

  @override
  String get fulfillment => 'Fulfillment';

  @override
  String get noSalesOrders => 'No Sales Orders to fulfill';

  @override
  String get noSalesOrdersSubtitle =>
      'Submitted Sales Orders with pending delivery quantities will appear here.';

  @override
  String dueDate(String date) {
    return 'Due $date';
  }

  @override
  String linesAndQty(int lines, String qty) {
    return '$lines lines / qty $qty';
  }

  @override
  String get pick => 'Pick';

  @override
  String get pack => 'Pack';

  @override
  String get dispatch => 'Dispatch';

  @override
  String get exact => 'Exact';

  @override
  String requiredQty(String qty) {
    return 'Required $qty';
  }

  @override
  String get exactPickRequired =>
      'Pick every line at the exact Sales Order quantity before packing.';

  @override
  String get continueToPack => 'Continue to pack';

  @override
  String get confirmPacked => 'Confirm packed';

  @override
  String get exactPackRequired =>
      'Pack every line at the exact picked quantity before dispatch.';

  @override
  String get readyToDispatch => 'Ready to dispatch';

  @override
  String readyToDispatchSubtitle(String salesOrder) {
    return 'Queue Delivery Note creation for $salesOrder.';
  }

  @override
  String get queueDispatch => 'Queue dispatch';

  @override
  String dispatchQueued(String id) {
    return 'Dispatch queued (op $id).';
  }

  @override
  String get tracking => 'Tracking';

  @override
  String get batch => 'Batch';

  @override
  String get expiry => 'Expiry';

  @override
  String get serials => 'Serials';

  @override
  String get oneSerialPerLine => 'One serial per line';

  @override
  String get batchRequired => 'Batch is required.';

  @override
  String get serialCountMustMatchQty => 'Serial count must match quantity.';

  @override
  String get lookupTitle => 'Scan / Lookup';

  @override
  String get lookupInputLabel => 'RFID EPC or barcode';

  @override
  String get lookupInputHint => 'Enter EPC, barcode, or item code';

  @override
  String get readRfid => 'Read RFID';

  @override
  String get resolveAction => 'Resolve';

  @override
  String get lookupResolving => 'Resolving…';

  @override
  String get lookupDemoBanner => 'Demo RFID reader active. Reads use sample EPC tags.';

  @override
  String get noRfidReader => 'No RFID reader is available.';

  @override
  String get noTagRead => 'No RFID tag was read.';

  @override
  String get tagNotRegistered => 'Tag not registered';

  @override
  String get bindEpcDescription => 'Bind this EPC to an existing record:';

  @override
  String get recordType => 'Record type';

  @override
  String get recordName => 'Record name';

  @override
  String get bindEpc => 'Bind EPC';

  @override
  String get openAsset => 'Open asset';

  @override
  String get openItem => 'Open item';

  @override
  String get lookupNetworkError => 'Unable to connect. Check your network and try again.';

  @override
  String get lookupFailed => 'Lookup failed';

  @override
  String get retry => 'Retry';

  @override
  String get assetLabel => 'Asset';

  @override
  String get serialNoLabel => 'Serial No';

  @override
  String get statusLabel => 'Status';

  @override
  String get locationLabel => 'Location';

  @override
  String get custodianLabel => 'Custodian';

  @override
  String get itemCode => 'Item code';
}
