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
  String get desktopBridgeRunning => '当前使用桌面进程桥接服务输出实时调音数据。';

  @override
  String get listeningStopped => '输入流已停止。';

  @override
  String get listeningPreparing => '正在启动音频桥接并等待首批稳定帧。';

  @override
  String get listeningStopping => '正在停止音频桥接。';

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
  String get bridgeDiagnosticsLabel => '桥接诊断';

  @override
  String get bridgeStateLabel => '桥接状态';

  @override
  String get bridgeBackendLabel => '后端';

  @override
  String get bridgeDeviceLabel => '设备';

  @override
  String get bridgeExitCodeLabel => '最近退出码';

  @override
  String get bridgeLastErrorLabel => '最近桥接错误';

  @override
  String get bridgeStderrLabel => '最近 stderr';

  @override
  String get bridgeStateIdle => '空闲';

  @override
  String get bridgeStateStarting => '启动中';

  @override
  String get bridgeStateListening => '监听中';

  @override
  String get bridgeStateStopping => '停止中';

  @override
  String get bridgeStateError => '错误';

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
  String get noPitchListeningMessage => '正在等待稳定音高。请清晰地拨动一根琴弦，并让它持续振动片刻。';

  @override
  String get weakSignalLabel => '信号较弱';

  @override
  String get weakSignalMessage => '当前音高输入不稳定。请延长拨弦时间或减少环境噪声。';

  @override
  String get weakSignalDetailedMessage => '已检测到音高，但仍不稳定。请延长发音时间、靠近麦克风或减少环境噪声。';

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
