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
}
