enum MimicryProtocol {
  teams,
  shaparak,
  doh,
  https,
  google,
  zoom,
  facetime,
  vk,
  yandex,
  wechat,
}

extension MimicryProtocolExtension on MimicryProtocol {
  String get name {
    switch (this) {
      case MimicryProtocol.teams:
        return 'Microsoft Teams';
      case MimicryProtocol.shaparak:
        return 'Shaparak Banking';
      case MimicryProtocol.doh:
        return 'DNS over HTTPS';
      case MimicryProtocol.https:
        return 'HTTPS';
      case MimicryProtocol.google:
        return 'Google Workspace';
      case MimicryProtocol.zoom:
        return 'Zoom';
      case MimicryProtocol.facetime:
        return 'FaceTime';
      case MimicryProtocol.vk:
        return 'VK';
      case MimicryProtocol.yandex:
        return 'Yandex';
      case MimicryProtocol.wechat:
        return 'WeChat';
    }
  }

  String get endpoint {
    switch (this) {
      case MimicryProtocol.teams:
        return '/teams/messages';
      case MimicryProtocol.shaparak:
        return '/shaparak/transaction';
      case MimicryProtocol.doh:
        return '/dns-query';
      case MimicryProtocol.https:
        return '/';
      case MimicryProtocol.google:
        return '/google/';
      case MimicryProtocol.zoom:
        return '/zoom/';
      case MimicryProtocol.facetime:
        return '/facetime/';
      case MimicryProtocol.vk:
        return '/vk/';
      case MimicryProtocol.yandex:
        return '/yandex/';
      case MimicryProtocol.wechat:
        return '/wechat/';
    }
  }

  String get description {
    switch (this) {
      case MimicryProtocol.teams:
        return 'Disguises traffic as Microsoft Teams chat';
      case MimicryProtocol.shaparak:
        return 'Looks like Iranian banking transactions';
      case MimicryProtocol.doh:
        return 'Appears as DNS queries';
      case MimicryProtocol.https:
        return 'Generic HTTPS traffic';
      case MimicryProtocol.google:
        return 'Mimics Google Drive, Meet, Calendar';
      case MimicryProtocol.zoom:
        return 'Looks like Zoom video calls';
      case MimicryProtocol.facetime:
        return 'Appears as Apple FaceTime';
      case MimicryProtocol.vk:
        return 'Russian VK social network';
      case MimicryProtocol.yandex:
        return 'Russian Yandex services';
      case MimicryProtocol.wechat:
        return 'Chinese WeChat messaging';
    }
  }

  String get iconPath {
    return 'assets/icons/protocol_${name.toLowerCase()}.png';
  }

  // Which regions is this protocol best for?
  List<String> get recommendedRegions {
    switch (this) {
      case MimicryProtocol.shaparak:
        return ['IR']; // Iran only
      case MimicryProtocol.vk:
      case MimicryProtocol.yandex:
        return ['RU', 'BY', 'KZ']; // Russia, Belarus, Kazakhstan
      case MimicryProtocol.wechat:
        return ['CN']; // China
      case MimicryProtocol.teams:
      case MimicryProtocol.google:
      case MimicryProtocol.zoom:
        return ['*']; // Global
      default:
        return ['*'];
    }
  }
}
