import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Bude Inventory'**
  String get appName;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcome(String name);

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search Items'**
  String get searchItems;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @count.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get count;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @stockTransfer.
  ///
  /// In en, this message translates to:
  /// **'Stock transfer'**
  String get stockTransfer;

  /// No description provided for @receiveStock.
  ///
  /// In en, this message translates to:
  /// **'Receive stock'**
  String get receiveStock;

  /// No description provided for @stockCount.
  ///
  /// In en, this message translates to:
  /// **'Stock count'**
  String get stockCount;

  /// No description provided for @sourceWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Source warehouse'**
  String get sourceWarehouse;

  /// No description provided for @targetWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Target warehouse'**
  String get targetWarehouse;

  /// No description provided for @warehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get warehouse;

  /// No description provided for @scanToAdd.
  ///
  /// In en, this message translates to:
  /// **'Scan to add'**
  String get scanToAdd;

  /// No description provided for @queueTransfer.
  ///
  /// In en, this message translates to:
  /// **'Queue transfer'**
  String get queueTransfer;

  /// No description provided for @queueReceipt.
  ///
  /// In en, this message translates to:
  /// **'Queue receipt'**
  String get queueReceipt;

  /// No description provided for @queueCount.
  ///
  /// In en, this message translates to:
  /// **'Queue count'**
  String get queueCount;

  /// No description provided for @againstPo.
  ///
  /// In en, this message translates to:
  /// **'Against PO (optional)'**
  String get againstPo;

  /// No description provided for @noItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet — scan or add manually.'**
  String get noItemsYet;

  /// No description provided for @scanItemsToCount.
  ///
  /// In en, this message translates to:
  /// **'Scan items to start counting.'**
  String get scanItemsToCount;

  /// No description provided for @pickWarehouseFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a warehouse first.'**
  String get pickWarehouseFirst;

  /// No description provided for @countedItems.
  ///
  /// In en, this message translates to:
  /// **'Counted items ({count})'**
  String countedItems(int count);

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items ({count})'**
  String items(int count);

  /// No description provided for @itemNotFound.
  ///
  /// In en, this message translates to:
  /// **'No item found for this barcode'**
  String get itemNotFound;

  /// No description provided for @transferQueued.
  ///
  /// In en, this message translates to:
  /// **'Transfer queued (op {id}). Watch /sync for status.'**
  String transferQueued(String id);

  /// No description provided for @receiptQueued.
  ///
  /// In en, this message translates to:
  /// **'Receipt queued (op {id}). Watch /sync for status.'**
  String receiptQueued(String id);

  /// No description provided for @countQueued.
  ///
  /// In en, this message translates to:
  /// **'Count queued (op {id}). Watch /sync for status.'**
  String countQueued(String id);

  /// No description provided for @openSync.
  ///
  /// In en, this message translates to:
  /// **'Open sync'**
  String get openSync;

  /// No description provided for @sourceTargetMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'Source and target must differ.'**
  String get sourceTargetMustDiffer;

  /// No description provided for @changingWarehouseClearsCount.
  ///
  /// In en, this message translates to:
  /// **'Changing this clears the current count.'**
  String get changingWarehouseClearsCount;

  /// No description provided for @failedToLoadWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Failed to load warehouses: {error}'**
  String failedToLoadWarehouses(String error);

  /// No description provided for @couldNotLoadPOs.
  ///
  /// In en, this message translates to:
  /// **'Could not load POs: {error}'**
  String couldNotLoadPOs(String error);

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — changes will sync when connected'**
  String get offlineMessage;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncComplete;

  /// No description provided for @pendingOps.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{No pending operations} =1{1 pending operation} other{{count} pending operations}}'**
  String pendingOps(int count);

  /// No description provided for @syncNonePending.
  ///
  /// In en, this message translates to:
  /// **'Sync (none pending)'**
  String get syncNonePending;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'Sync ({count} pending)'**
  String syncPending(int count);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @resetConnection.
  ///
  /// In en, this message translates to:
  /// **'Reset connection'**
  String get resetConnection;

  /// No description provided for @resetConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset connection?'**
  String get resetConnectionTitle;

  /// No description provided for @resetConnectionMessage.
  ///
  /// In en, this message translates to:
  /// **'This signs you out and removes the saved server. You will be sent back to setup.'**
  String get resetConnectionMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get textSizeSmall;

  /// No description provided for @textSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get textSizeMedium;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get textSizeLarge;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get highContrast;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// No description provided for @erpUrl.
  ///
  /// In en, this message translates to:
  /// **'ERP URL'**
  String get erpUrl;

  /// No description provided for @connectedSince.
  ///
  /// In en, this message translates to:
  /// **'Connected since'**
  String get connectedSince;

  /// No description provided for @erpnextVersion.
  ///
  /// In en, this message translates to:
  /// **'ERPNext'**
  String get erpnextVersion;

  /// No description provided for @budeApiVersion.
  ///
  /// In en, this message translates to:
  /// **'bude_api'**
  String get budeApiVersion;

  /// No description provided for @defaults.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get defaults;

  /// No description provided for @defaultSourceWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Default source warehouse'**
  String get defaultSourceWarehouse;

  /// No description provided for @defaultTargetWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Default target warehouse'**
  String get defaultTargetWarehouse;

  /// No description provided for @noneSelected.
  ///
  /// In en, this message translates to:
  /// **'— none —'**
  String get noneSelected;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanning;

  /// No description provided for @scanSound.
  ///
  /// In en, this message translates to:
  /// **'Scan sound'**
  String get scanSound;

  /// No description provided for @scanVibration.
  ///
  /// In en, this message translates to:
  /// **'Scan vibration'**
  String get scanVibration;

  /// No description provided for @continuousScanMode.
  ///
  /// In en, this message translates to:
  /// **'Continuous scan mode'**
  String get continuousScanMode;

  /// No description provided for @syncAndOffline.
  ///
  /// In en, this message translates to:
  /// **'Sync & Offline'**
  String get syncAndOffline;

  /// No description provided for @syncInterval.
  ///
  /// In en, this message translates to:
  /// **'Sync interval'**
  String get syncInterval;

  /// No description provided for @syncIntervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String syncIntervalMinutes(int minutes);

  /// No description provided for @wifiOnlySync.
  ///
  /// In en, this message translates to:
  /// **'Sync on Wi-Fi only'**
  String get wifiOnlySync;

  /// No description provided for @forceFullResync.
  ///
  /// In en, this message translates to:
  /// **'Force full resync'**
  String get forceFullResync;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @currentConnection.
  ///
  /// In en, this message translates to:
  /// **'Current connection'**
  String get currentConnection;

  /// No description provided for @noConnectionConfigured.
  ///
  /// In en, this message translates to:
  /// **'No connection configured.'**
  String get noConnectionConfigured;

  /// No description provided for @setUpNow.
  ///
  /// In en, this message translates to:
  /// **'Set up now'**
  String get setUpNow;

  /// No description provided for @emptyQueue.
  ///
  /// In en, this message translates to:
  /// **'No pending operations'**
  String get emptyQueue;

  /// No description provided for @emptyQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All changes have been synced.'**
  String get emptyQueueSubtitle;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @tryScanningBarcode.
  ///
  /// In en, this message translates to:
  /// **'Try scanning a barcode or enter a different search term.'**
  String get tryScanningBarcode;

  /// No description provided for @recentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get recentlyUsed;

  /// No description provided for @autoLogoutDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get autoLogoutDisabled;

  /// No description provided for @autoLogoutMinutes.
  ///
  /// In en, this message translates to:
  /// **'Auto-logout: {minutes} min'**
  String autoLogoutMinutes(int minutes);

  /// No description provided for @stockTab.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @movementHistory.
  ///
  /// In en, this message translates to:
  /// **'Movement history'**
  String get movementHistory;

  /// No description provided for @noMovementHistory.
  ///
  /// In en, this message translates to:
  /// **'No movement history'**
  String get noMovementHistory;

  /// No description provided for @noMovementHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions will appear here once this item has been moved.'**
  String get noMovementHistorySubtitle;

  /// No description provided for @balanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance after: {qty}'**
  String balanceAfter(String qty);

  /// No description provided for @warehouses.
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get warehouses;

  /// No description provided for @warehouseStock.
  ///
  /// In en, this message translates to:
  /// **'Warehouse stock'**
  String get warehouseStock;

  /// No description provided for @noWarehousesFound.
  ///
  /// In en, this message translates to:
  /// **'No warehouses found'**
  String get noWarehousesFound;

  /// No description provided for @noWarehousesFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your ERPNext connection or add warehouses in ERPNext.'**
  String get noWarehousesFoundSubtitle;

  /// No description provided for @noStockInWarehouse.
  ///
  /// In en, this message translates to:
  /// **'No stock in this warehouse'**
  String get noStockInWarehouse;

  /// No description provided for @noStockInWarehouseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items will appear here once stock has been received.'**
  String get noStockInWarehouseSubtitle;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total items: {count}'**
  String totalItems(int count);

  /// No description provided for @actualQty.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get actualQty;

  /// No description provided for @reservedQty.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get reservedQty;

  /// No description provided for @projectedQty.
  ///
  /// In en, this message translates to:
  /// **'Projected'**
  String get projectedQty;

  /// No description provided for @scanSession.
  ///
  /// In en, this message translates to:
  /// **'Scan session'**
  String get scanSession;

  /// No description provided for @startScanSession.
  ///
  /// In en, this message translates to:
  /// **'Start scan session'**
  String get startScanSession;

  /// No description provided for @useNItems.
  ///
  /// In en, this message translates to:
  /// **'Use {count} items'**
  String useNItems(int count);

  /// No description provided for @scanningActive.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanningActive;

  /// No description provided for @resolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving…'**
  String get resolving;

  /// No description provided for @itemAdded.
  ///
  /// In en, this message translates to:
  /// **'Added: {name}'**
  String itemAdded(String name);

  /// No description provided for @barcodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Barcode not found'**
  String get barcodeNotFound;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @stockAging.
  ///
  /// In en, this message translates to:
  /// **'Stock Aging'**
  String get stockAging;

  /// No description provided for @stockAgingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items with no recent movement'**
  String get stockAgingSubtitle;

  /// No description provided for @thresholdDays.
  ///
  /// In en, this message translates to:
  /// **'Idle threshold'**
  String get thresholdDays;

  /// No description provided for @daysIdle.
  ///
  /// In en, this message translates to:
  /// **'{days,plural, =1{1 day idle} other{{days} days idle}}'**
  String daysIdle(int days);

  /// No description provided for @lastMovedDate.
  ///
  /// In en, this message translates to:
  /// **'Last moved {date}'**
  String lastMovedDate(String date);

  /// No description provided for @neverMoved.
  ///
  /// In en, this message translates to:
  /// **'Never moved'**
  String get neverMoved;

  /// No description provided for @noIdleItems.
  ///
  /// In en, this message translates to:
  /// **'No idle items'**
  String get noIdleItems;

  /// No description provided for @noIdleItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All items moved within the selected threshold.'**
  String get noIdleItemsSubtitle;

  /// No description provided for @varianceDashboard.
  ///
  /// In en, this message translates to:
  /// **'Variance Dashboard'**
  String get varianceDashboard;

  /// No description provided for @varianceDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation vs expected qty'**
  String get varianceDashboardSubtitle;

  /// No description provided for @reconciliationHistory.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation History'**
  String get reconciliationHistory;

  /// No description provided for @counted.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get counted;

  /// No description provided for @expected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get expected;

  /// No description provided for @noReconciliations.
  ///
  /// In en, this message translates to:
  /// **'No reconciliations found'**
  String get noReconciliations;

  /// No description provided for @noReconciliationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted stock counts will appear here.'**
  String get noReconciliationsSubtitle;

  /// No description provided for @throughput.
  ///
  /// In en, this message translates to:
  /// **'Throughput'**
  String get throughput;

  /// No description provided for @throughputSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Operation activity over time'**
  String get throughputSubtitle;

  /// No description provided for @operationThroughput.
  ///
  /// In en, this message translates to:
  /// **'Operation Throughput'**
  String get operationThroughput;

  /// No description provided for @totalOps.
  ///
  /// In en, this message translates to:
  /// **'Total ops'**
  String get totalOps;

  /// No description provided for @successRate.
  ///
  /// In en, this message translates to:
  /// **'Success rate'**
  String get successRate;

  /// No description provided for @mostActiveDay.
  ///
  /// In en, this message translates to:
  /// **'Most active day'**
  String get mostActiveDay;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get last7Days;

  /// No description provided for @last14Days.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get last14Days;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get last30Days;

  /// No description provided for @noOpsYet.
  ///
  /// In en, this message translates to:
  /// **'No operations yet'**
  String get noOpsYet;

  /// No description provided for @noOpsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Queue a transfer, receipt, or count to see throughput data.'**
  String get noOpsYetSubtitle;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download stock or ledger as CSV'**
  String get exportDataSubtitle;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @exportType.
  ///
  /// In en, this message translates to:
  /// **'Export type'**
  String get exportType;

  /// No description provided for @itemLedger.
  ///
  /// In en, this message translates to:
  /// **'Item ledger'**
  String get itemLedger;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exporting;

  /// No description provided for @exportComplete.
  ///
  /// In en, this message translates to:
  /// **'Export ready'**
  String get exportComplete;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
