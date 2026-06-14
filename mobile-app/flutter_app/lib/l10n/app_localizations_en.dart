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
}
