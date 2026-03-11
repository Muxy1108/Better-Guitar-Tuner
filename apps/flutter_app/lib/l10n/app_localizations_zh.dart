// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '更好的吉他调音器';

  @override
  String get tuningPresetLabel => '调弦预设';

  @override
  String get modeLabel => '模式';

  @override
  String get autoModeLabel => '自动';

  @override
  String get manualModeLabel => '手动';

  @override
  String get listeningLabel => '监听';

  @override
  String get startListeningLabel => '开始监听';

  @override
  String get stopListeningLabel => '停止监听';

  @override
  String get mockBridgeRunning => '当前使用模拟音频桥接服务输出开发数据。';

  @override
  String get nativeBridgeRunning => '当前使用原生音频桥接服务输出实时调音数据。';

  @override
  String get listeningStopped => '输入流已停止。';

  @override
  String get microphonePermissionDeniedTitle => '需要麦克风权限';

  @override
  String get microphonePermissionDeniedMessage =>
      '麦克风访问已被拒绝。请在 iOS 设置中启用权限后再进行实时调音。';

  @override
  String get listeningFailureTitle => '监听启动失败';

  @override
  String get listeningFailureMessage => '音频桥接服务无法开始或继续监听。';

  @override
  String get tunerReadingLabel => '当前读数';

  @override
  String get targetNoteLabel => '目标音';

  @override
  String get detectedFrequencyLabel => '检测频率';

  @override
  String get centsOffsetLabel => '音分偏移';

  @override
  String get tuningStatusLabel => '状态';

  @override
  String get centsMeterLabel => '音分表';

  @override
  String get noPitchLabel => '无音高';

  @override
  String get noPitchMessage => '暂未检测到清晰音高。请在靠近麦克风的位置重新拨动琴弦。';

  @override
  String get weakSignalLabel => '信号较弱';

  @override
  String get weakSignalMessage => '当前音高输入不稳定。请延长拨弦时间或减少环境噪声。';

  @override
  String get tooLowLabel => '偏低';

  @override
  String get inTuneLabel => '已调准';

  @override
  String get tooHighLabel => '偏高';

  @override
  String get unavailableValue => '不可用';

  @override
  String get errorLabel => '错误';

  @override
  String stringChipLabel(int index, String note) {
    return '弦 $index: $note';
  }
}
