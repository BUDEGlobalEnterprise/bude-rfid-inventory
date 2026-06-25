// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'بود للمخزون';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String welcome(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get scan => 'مسح';

  @override
  String get searchItems => 'البحث عن أصناف';

  @override
  String get transfer => 'نقل';

  @override
  String get receive => 'استلام';

  @override
  String get count => 'جرد';

  @override
  String get settings => 'الإعدادات';

  @override
  String get stockTransfer => 'نقل مخزون';

  @override
  String get receiveStock => 'استلام مخزون';

  @override
  String get stockCount => 'جرد المخزون';

  @override
  String get sourceWarehouse => 'مستودع المصدر';

  @override
  String get targetWarehouse => 'مستودع الهدف';

  @override
  String get warehouse => 'المستودع';

  @override
  String get scanToAdd => 'مسح للإضافة';

  @override
  String get queueTransfer => 'إضافة للطابور';

  @override
  String get queueReceipt => 'إضافة الاستلام للطابور';

  @override
  String get queueCount => 'إضافة الجرد للطابور';

  @override
  String get againstPo => 'أمر شراء (اختياري)';

  @override
  String get noItemsYet => 'لا توجد أصناف — امسح أو أضف يدوياً.';

  @override
  String get scanItemsToCount => 'امسح الأصناف لبدء الجرد.';

  @override
  String get pickWarehouseFirst => 'اختر مستودعاً أولاً.';

  @override
  String countedItems(int count) {
    return 'الأصناف المجرودة ($count)';
  }

  @override
  String items(int count) {
    return 'الأصناف ($count)';
  }

  @override
  String get itemNotFound => 'لم يُعثر على صنف لهذا الباركود';

  @override
  String transferQueued(String id) {
    return 'تمت إضافة النقل للطابور (op $id).';
  }

  @override
  String receiptQueued(String id) {
    return 'تمت إضافة الاستلام للطابور (op $id).';
  }

  @override
  String countQueued(String id) {
    return 'تمت إضافة الجرد للطابور (op $id).';
  }

  @override
  String get openSync => 'فتح المزامنة';

  @override
  String get sourceTargetMustDiffer => 'يجب أن يختلف المصدر والهدف.';

  @override
  String get changingWarehouseClearsCount => 'تغيير هذا سيمسح الجرد الحالي.';

  @override
  String failedToLoadWarehouses(String error) {
    return 'فشل تحميل المستودعات: $error';
  }

  @override
  String couldNotLoadPOs(String error) {
    return 'تعذّر تحميل أوامر الشراء: $error';
  }

  @override
  String get offline => 'غير متصل';

  @override
  String get offlineMessage => 'أنت غير متصل — ستتم المزامنة عند الاتصال';

  @override
  String get syncing => 'جارٍ المزامنة…';

  @override
  String get syncComplete => 'تمت المزامنة';

  @override
  String pendingOps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عمليات معلقة',
      one: 'عملية معلقة واحدة',
      zero: 'لا عمليات معلقة',
    );
    return '$_temp0';
  }

  @override
  String get syncNonePending => 'مزامنة (لا شيء معلق)';

  @override
  String syncPending(int count) {
    return 'مزامنة ($count معلق)';
  }

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get resetConnection => 'إعادة ضبط الاتصال';

  @override
  String get resetConnectionTitle => 'إعادة ضبط الاتصال؟';

  @override
  String get resetConnectionMessage =>
      'سيتم تسجيل خروجك وحذف الخادم المحفوظ. ستعود إلى صفحة الإعداد.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get reset => 'إعادة ضبط';

  @override
  String get appearance => 'المظهر';

  @override
  String get language => 'اللغة';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeSystem => 'تلقائي';

  @override
  String get textSize => 'حجم النص';

  @override
  String get textSizeSmall => 'ص';

  @override
  String get textSizeMedium => 'م';

  @override
  String get textSizeLarge => 'ك';

  @override
  String get highContrast => 'تباين عالٍ';

  @override
  String get connection => 'الاتصال';

  @override
  String get company => 'الشركة';

  @override
  String get erpUrl => 'رابط ERP';

  @override
  String get connectedSince => 'متصل منذ';

  @override
  String get erpnextVersion => 'إصدار ERPNext';

  @override
  String get budeApiVersion => 'إصدار bude_api';

  @override
  String get defaults => 'الإعدادات الافتراضية';

  @override
  String get defaultSourceWarehouse => 'مستودع المصدر الافتراضي';

  @override
  String get defaultTargetWarehouse => 'مستودع الهدف الافتراضي';

  @override
  String get noneSelected => '— لا شيء —';

  @override
  String get scanning => 'المسح الضوئي';

  @override
  String get scanSound => 'صوت المسح';

  @override
  String get scanVibration => 'اهتزاز المسح';

  @override
  String get continuousScanMode => 'وضع المسح المستمر';

  @override
  String get syncAndOffline => 'المزامنة وبدون اتصال';

  @override
  String get syncInterval => 'فترة المزامنة';

  @override
  String syncIntervalMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get wifiOnlySync => 'المزامنة عبر Wi-Fi فقط';

  @override
  String get forceFullResync => 'إعادة مزامنة كاملة';

  @override
  String get diagnostics => 'التشخيصات';

  @override
  String get appVersion => 'إصدار التطبيق';

  @override
  String get account => 'الحساب';

  @override
  String get currentConnection => 'الاتصال الحالي';

  @override
  String get noConnectionConfigured => 'لم يتم تكوين اتصال.';

  @override
  String get setUpNow => 'الإعداد الآن';

  @override
  String get emptyQueue => 'لا توجد عمليات معلقة';

  @override
  String get emptyQueueSubtitle => 'تمت مزامنة جميع التغييرات.';

  @override
  String get noItemsFound => 'لا توجد أصناف';

  @override
  String get tryScanningBarcode => 'حاول مسح باركود أو أدخل مصطلح بحث مختلف.';

  @override
  String get recentlyUsed => 'المستخدمة مؤخراً';

  @override
  String get autoLogoutDisabled => 'معطّل';

  @override
  String autoLogoutMinutes(int minutes) {
    return 'تسجيل خروج تلقائي: $minutes دقيقة';
  }

  @override
  String get stockTab => 'المخزون';

  @override
  String get historyTab => 'السجل';

  @override
  String get movementHistory => 'سجل الحركة';

  @override
  String get noMovementHistory => 'لا يوجد سجل حركة';

  @override
  String get noMovementHistorySubtitle =>
      'ستظهر المعاملات هنا بعد نقل هذا الصنف.';

  @override
  String balanceAfter(String qty) {
    return 'الرصيد بعد: $qty';
  }

  @override
  String get warehouses => 'المستودعات';

  @override
  String get warehouseStock => 'مخزون المستودع';

  @override
  String get noWarehousesFound => 'لم يتم العثور على مستودعات';

  @override
  String get noWarehousesFoundSubtitle =>
      'تحقق من اتصال ERPNext أو أضف مستودعات في ERPNext.';

  @override
  String get noStockInWarehouse => 'لا يوجد مخزون في هذا المستودع';

  @override
  String get noStockInWarehouseSubtitle =>
      'ستظهر الأصناف هنا بعد استلام المخزون.';

  @override
  String totalItems(int count) {
    return 'إجمالي الأصناف: $count';
  }

  @override
  String get actualQty => 'الفعلي';

  @override
  String get reservedQty => 'المحجوز';

  @override
  String get projectedQty => 'المتوقع';

  @override
  String get scanSession => 'جلسة المسح';

  @override
  String get startScanSession => 'بدء جلسة المسح';

  @override
  String useNItems(int count) {
    return 'استخدم $count أصناف';
  }

  @override
  String get scanningActive => 'جارٍ المسح…';

  @override
  String get resolving => 'جارٍ المعالجة…';

  @override
  String itemAdded(String name) {
    return 'أُضيف: $name';
  }

  @override
  String get barcodeNotFound => 'الباركود غير موجود';

  @override
  String get analytics => 'التحليلات';

  @override
  String get stockAging => 'تقادم المخزون';

  @override
  String get stockAgingSubtitle => 'الأصناف التي لم تُحرَّك مؤخراً';

  @override
  String get thresholdDays => 'حد التوقف';

  @override
  String daysIdle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days أيام بدون حركة',
      one: 'يوم واحد بدون حركة',
    );
    return '$_temp0';
  }

  @override
  String lastMovedDate(String date) {
    return 'آخر حركة $date';
  }

  @override
  String get neverMoved => 'لم تُحرَّك قط';

  @override
  String get noIdleItems => 'لا توجد أصناف متوقفة';

  @override
  String get noIdleItemsSubtitle => 'جميع الأصناف تحركت ضمن الحد المحدد.';

  @override
  String get varianceDashboard => 'لوحة الفروقات';

  @override
  String get varianceDashboardSubtitle => 'الجرد الفعلي مقابل الكميات المتوقعة';

  @override
  String get reconciliationHistory => 'سجل الجرد';

  @override
  String get counted => 'المحسوب';

  @override
  String get expected => 'المتوقع';

  @override
  String get noReconciliations => 'لم يتم العثور على عمليات جرد';

  @override
  String get noReconciliationsSubtitle => 'ستظهر عمليات الجرد المقدمة هنا.';

  @override
  String get throughput => 'الإنتاجية';

  @override
  String get throughputSubtitle => 'نشاط العمليات عبر الزمن';

  @override
  String get operationThroughput => 'إنتاجية العمليات';

  @override
  String get totalOps => 'إجمالي العمليات';

  @override
  String get successRate => 'معدل النجاح';

  @override
  String get mostActiveDay => 'أكثر يوم نشاطاً';

  @override
  String get last7Days => '٧ أيام';

  @override
  String get last14Days => '١٤ يوماً';

  @override
  String get last30Days => '٣٠ يوماً';

  @override
  String get noOpsYet => 'لا توجد عمليات بعد';

  @override
  String get noOpsYetSubtitle =>
      'قم بإضافة نقل أو استلام أو جرد لرؤية بيانات الإنتاجية.';

  @override
  String get exportDataSubtitle => 'تحميل بيانات المخزون أو السجل بصيغة CSV';

  @override
  String get exportData => 'تصدير البيانات';

  @override
  String get exportType => 'نوع التصدير';

  @override
  String get itemLedger => 'سجل الصنف';

  @override
  String get exportCsv => 'تصدير CSV';

  @override
  String get exporting => 'جارٍ التصدير…';

  @override
  String get exportComplete => 'التصدير جاهز';

  @override
  String get exportFailed => 'فشل التصدير';

  @override
  String get auditTrail => 'سجل المراجعة';

  @override
  String get auditTrailSubtitle => 'جميع العمليات المقدمة على هذا الجهاز';

  @override
  String get all => 'الكل';

  @override
  String get stockTransferLabel => 'تحويل المخزون';

  @override
  String get goodsReceiptLabel => 'استلام البضائع';

  @override
  String get stockCountLabel => 'جرد المخزون';

  @override
  String get noAuditOps => 'لا توجد عمليات بعد';

  @override
  String get noAuditOpsSubtitle => 'ستظهر العمليات المكتملة هنا.';

  @override
  String get viewInErp => 'عرض في ERP';

  @override
  String get activeCompany => 'الشركة النشطة';

  @override
  String get selectCompany => 'اختر شركة';

  @override
  String get noCompanies => 'لم يتم العثور على شركات';

  @override
  String get varianceThreshold => 'حد انحراف الموافقة (وحدات)';

  @override
  String get varianceThresholdHint => '0 = معطّل';

  @override
  String get autoLogout => 'تسجيل الخروج التلقائي';

  @override
  String get unlockApp => 'افتح القفل للمتابعة';

  @override
  String get sessionLocked => 'الجلسة مقفلة';

  @override
  String get approvalRequired => 'مطلوب موافقة المشرف';

  @override
  String approvalRequiredSubtitle(String qty) {
    return 'إجمالي الانحراف $qty وحدة يتجاوز حد الموافقة.';
  }

  @override
  String get approveWithBiometric => 'الموافقة بالبصمة / رمز PIN';

  @override
  String get approvalGranted => 'تمت الموافقة — العملية في قائمة الانتظار.';

  @override
  String get approvalFailed => 'فشلت البصمة — لم تُمنح الموافقة.';

  @override
  String get pendingApprovalStatus => 'في انتظار الموافقة';

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
}
