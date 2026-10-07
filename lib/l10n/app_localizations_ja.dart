// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class LJa extends L {
  LJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'SANSLAB IoT Server';

  @override
  String get navOverview => '概要';

  @override
  String get navManage => '管理';

  @override
  String get navApps => 'アプリ';

  @override
  String get navBuild => 'ビルド';

  @override
  String get navDashboard => 'ダッシュボード';

  @override
  String get navProjects => 'プロジェクト';

  @override
  String get navOrders => '注文';

  @override
  String get navCustomers => '顧客';

  @override
  String get navProducts => '商品';

  @override
  String get navInbox => '受信箱';

  @override
  String get navBoard => 'ボード';

  @override
  String get navCalendar => 'カレンダー';

  @override
  String get navChat => 'チャット';

  @override
  String get navComponents => 'コンポーネント';

  @override
  String get navForms => 'フォーム';

  @override
  String get navWizard => 'ウィザード';

  @override
  String get navSettings => '設定';

  @override
  String get navProfile => 'プロフィール';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionDelete => '削除';

  @override
  String get actionEdit => '編集';

  @override
  String get actionRefresh => '更新';

  @override
  String get actionExport => '書き出し';

  @override
  String get actionSearch => '検索';

  @override
  String get actionClear => 'クリア';

  @override
  String get actionPrevious => '前へ';

  @override
  String get actionNext => '次へ';

  @override
  String get actionSignIn => 'サインイン';

  @override
  String get actionSignOut => 'サインアウト';

  @override
  String get signInTitle => 'サインイン';

  @override
  String get signInSubtitle => 'どのメールでも使えます — モックプロバイダです。';

  @override
  String get fieldEmail => 'メール';

  @override
  String get fieldPassword => 'パスワード';

  @override
  String get fieldName => '名前';

  @override
  String get forgotPassword => 'パスワードをお忘れですか？';

  @override
  String get noAccount => 'アカウントがありませんか？作成する';

  @override
  String get lightMode => 'ライトモード';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get accent => 'アクセント';

  @override
  String get emptyTitle => '条件に一致するものがありません';

  @override
  String get emptyMessage => '検索を消すか、別のステータスを選んでください。';

  @override
  String get errorTitle => '問題が発生しました';

  @override
  String get errorRetry => '再試行';

  @override
  String pageOf(int page, int pages) {
    return '$pages ページ中 $page ページ';
  }

  @override
  String rangeOfTotal(int first, int last, int total) {
    return '$total 件中 $first〜$last 件';
  }

  @override
  String get accountInfo => 'アカウント情報';

  @override
  String get accountSubtitle => 'このアカウントのIDとアクティブなセッション情報を表示します。';

  @override
  String get accountIdentityTitle => 'ID情報';

  @override
  String get accountUserId => 'ユーザーID (UUID)';

  @override
  String get accountEmail => 'アカウントメール';

  @override
  String get accountFullName => '氏名';

  @override
  String get accountRole => 'ゲートウェイロール';

  @override
  String get accountRoleUnassigned => 'ロール未割り当て';

  @override
  String get accountRoleNote => '権限はGoバックエンドでゲートウェイごとに動的に検証されます。';

  @override
  String get accountSessionTitle => 'セッションとセキュリティ';

  @override
  String get accountSessionStatus => 'セッション状態';

  @override
  String get accountStatusActive => 'アクティブ';

  @override
  String get accountAuthMethod => '認証方式';

  @override
  String get accountAuthMethodValue =>
      'Supabase Auth (GoTrue) · GoバックエンドローカルHS256検証';

  @override
  String get accountAdminNoteTitle => 'アカウント管理ポリシー';

  @override
  String get accountAdminNote => 'アカウントは管理者によって一元管理されています。';

  @override
  String get accountCopyId => 'IDをコピー';

  @override
  String get accountCopiedId => 'ユーザーIDをクリップボードにコピーしました';

  @override
  String get accountBackToDashboard => 'ダッシュボードに戻る';

  @override
  String get navGateways => 'ゲートウェイ';

  @override
  String get gatewayListTitle => 'ゲートウェイ管理';

  @override
  String get gatewayListSubtitle => 'アクセス可能なゲートウェイ一覧を表示します。';

  @override
  String get gatewayId => 'ゲートウェイID';

  @override
  String get gatewayName => '名前';

  @override
  String get gatewayDescription => '説明';

  @override
  String get gatewayRole => 'ロール';

  @override
  String get gatewayCreatedAt => '作成日時';

  @override
  String get gatewaySearchPlaceholder => 'ID、名前、説明で検索...';

  @override
  String get gatewayEmptyTitle => 'ゲートウェイがありません';

  @override
  String get gatewayEmptyMessage => '現在アクセス可能なゲートウェイが割り当てられていません。';

  @override
  String get gatewaySearchEmptyTitle => '一致する結果がありません';

  @override
  String get gatewaySearchEmptyMessage => '検索条件に一致するゲートウェイはありません。';

  @override
  String get gatewayRoleOwner => 'オーナー';

  @override
  String get gatewayRoleOperator => 'オペレーター';

  @override
  String get gatewayRoleViewer => '閲覧者';

  @override
  String get gatewayActionDetail => '詳細';

  @override
  String get gatewayDetailTitle => 'ゲートウェイ詳細';

  @override
  String get gatewayDetailSubtitle => 'ステーション構成と接続センサーの概要。';

  @override
  String get gatewayNotFoundTitle => 'ゲートウェイが見つかりません';

  @override
  String get gatewayNotFoundMessage => '指定されたゲートウェイが存在しないか、アクセス権限がありません。';

  @override
  String get gatewayInvalidIdMessage => 'ゲートウェイ識別子の形式が無効であるか、予約された識別子です。';

  @override
  String get gatewayBackToList => 'ゲートウェイ一覧に戻る';

  @override
  String get gatewaySectionMetadata => 'ゲートウェイ情報';

  @override
  String get gatewaySectionSensors => 'センサー一覧';

  @override
  String get sensorId => 'センサーID';

  @override
  String get sensorName => 'センサー名';

  @override
  String get sensorUnit => '単位';

  @override
  String get sensorCreatedAt => '作成日時';

  @override
  String get sensorEmptyTitle => 'センサーが登録されていません';

  @override
  String get sensorEmptyMessage => 'このゲートウェイにはまだセンサーが登録されていません。';

  @override
  String get sensorSearchPlaceholder => 'センサーID、名前、単位で検索...';

  @override
  String get sensorSearchEmptyTitle => '一致するセンサーがありません';

  @override
  String get sensorSearchEmptyMessage => '検索条件に一致するセンサーはありません。';

  @override
  String get sensorErrorTitle => 'センサーの取得に失敗しました';

  @override
  String get sensorErrorRetry => 'センサーを再読み込み';

  @override
  String get gatewayReadOnlyNotice => '読み取り専用モード（ステージ2）。リモート制御は有効化されていません。';
}
