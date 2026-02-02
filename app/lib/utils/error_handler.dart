/// 錯誤處理工具類
/// 用於安全地處理和顯示錯誤訊息，避免洩露後端機密資訊
class ErrorHandler {
  /// 將錯誤轉換為用戶友好的錯誤訊息
  /// 不洩露後端詳細錯誤資訊
  static String getSafeErrorMessage(dynamic error) {
    if (error == null) {
      return '發生未知錯誤，請稍後再試';
    }

    final errorStr = error.toString().toLowerCase();

    // 網路相關錯誤
    if (errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return '網路連線失敗，請檢查網路連線後再試';
    }

    // 超時錯誤
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return '請求逾時，請稍後再試';
    }

    // HTTP 錯誤
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return '找不到請求的資源';
    }

    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return '未授權，請重新登入';
    }

    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return '沒有權限執行此操作';
    }

    if (errorStr.contains('500') || errorStr.contains('internal server error')) {
      return '伺服器錯誤，請稍後再試';
    }

    if (errorStr.contains('502') || errorStr.contains('bad gateway')) {
      return '伺服器暫時無法回應，請稍後再試';
    }

    if (errorStr.contains('503') || errorStr.contains('service unavailable')) {
      return '服務暫時無法使用，請稍後再試';
    }

    // 權限相關錯誤
    if (errorStr.contains('permission') ||
        errorStr.contains('rls') ||
        errorStr.contains('row-level security') ||
        errorStr.contains('42501')) {
      return '沒有權限執行此操作';
    }

    // 驗證相關錯誤
    if (errorStr.contains('invalid login') ||
        errorStr.contains('invalid_credentials') ||
        errorStr.contains('wrong password')) {
      return '帳號或密碼錯誤';
    }

    if (errorStr.contains('email not confirmed') ||
        errorStr.contains('email_not_confirmed')) {
      return '請先確認您的電子郵件';
    }

    // 資源不存在
    if (errorStr.contains('not found') ||
        errorStr.contains('不存在') ||
        errorStr.contains('找不到')) {
      return '找不到請求的資源';
    }

    // 重複資源
    if (errorStr.contains('duplicate') ||
        errorStr.contains('already exists') ||
        errorStr.contains('23505')) {
      return '此資源已存在';
    }

    // 請求過多
    if (errorStr.contains('too many requests') ||
        errorStr.contains('rate_limit')) {
      return '請求次數過多，請稍後再試';
    }

    // 預設錯誤訊息（不洩露詳細資訊）
    return '操作失敗，請稍後再試';
  }

  /// 檢查錯誤是否為網路錯誤
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout');
  }

  /// 檢查錯誤是否為權限錯誤
  static bool isPermissionError(dynamic error) {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission') ||
        errorStr.contains('rls') ||
        errorStr.contains('row-level security') ||
        errorStr.contains('42501') ||
        errorStr.contains('403') ||
        errorStr.contains('forbidden');
  }
}
