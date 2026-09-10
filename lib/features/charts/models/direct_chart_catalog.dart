import 'chart.dart';

class DirectChartDefinition {
  const DirectChartDefinition(this.chart, [this.upstreamId = '']);
  final Chart chart;
  final String upstreamId;
}

List<DirectChartDefinition> directChartCatalog({
  required bool includeSpotify,
}) => [
  if (includeSpotify)
    for (final (id, name, description, playlist) in const [
      (
        'spotify-global-top',
        'Global Top 50',
        'Spotify 全球热门歌曲榜',
        '37i9dQZEVXbMDoHDwVN2tF',
      ),
      (
        'spotify-global-viral',
        'Viral 50 · Global',
        'Spotify 全球飙升歌曲榜',
        '5Th61R37SXj0VMRoUJm28c',
      ),
      (
        'spotify-hk-top',
        'Top 50 · 香港',
        'Spotify 香港热门歌曲榜',
        '37i9dQZEVXbLwpL8TjsxOG',
      ),
    ])
      DirectChartDefinition(
        Chart(
          id: id,
          name: name,
          description: description,
          kind: 'spotify-public',
        ),
        playlist,
      ),
  const DirectChartDefinition(
    Chart(
      id: 'family',
      name: '本机热播',
      kind: 'family',
      description: '最近 30 天在这台设备上最常听',
    ),
  ),
  for (final (id, name, playlist) in const [
    ('wy-hot', '热歌榜', '3778678'),
    ('wy-new', '新歌榜', '3779629'),
    ('wy-soar', '飙升榜', '19723756'),
    ('wy-origin', '原创榜', '2884035'),
  ])
    DirectChartDefinition(
      Chart(id: id, name: name, kind: 'netease', description: '网易云音乐官方$name'),
      playlist,
    ),
  for (final (id, name, topId) in const [
    ('qq-hot', '热歌榜', '26'),
    ('qq-new', '新歌榜', '27'),
    ('qq-soar', '飙升榜', '62'),
  ])
    DirectChartDefinition(
      Chart(id: id, name: name, kind: 'qq', description: 'QQ音乐巅峰$name'),
      topId,
    ),
  for (final (region, name) in const [
    ('cn', '中国'),
    ('us', '美国'),
    ('jp', '日本'),
    ('kr', '韩国'),
    ('tw', '台湾'),
    ('hk', '香港'),
  ])
    DirectChartDefinition(
      Chart(
        id: 'apple-$region',
        name: '热门歌曲 · $name',
        kind: 'apple',
        description: 'Apple Music $name区最热歌曲',
      ),
      region,
    ),
];
