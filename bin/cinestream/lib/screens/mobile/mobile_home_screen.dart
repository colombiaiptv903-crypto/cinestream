import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../main.dart' show appRouteObserver;
import '../../services/content_service.dart';
import '../../services/history_service.dart';
import '../../services/favorites_service.dart';
import '../../models/models.dart';
import '../../widgets/tv_player_widget.dart';
import '../player/player_screen.dart';
import '../player/event_player_screen.dart';
import '../player/web_event_player_screen.dart';
import '../profile/profile_screen.dart';
import '../../models/diary_model.dart';
import '../../services/diary_service.dart';
import 'pelota_libre_player_screen.dart';
import '../../services/ad_service.dart';
import '../../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/appwrite_config.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});
  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final service   = context.watch<ContentService>();
    final history   = context.watch<HistoryService>();
    final favorites = context.watch<FavoritesService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        titleSpacing: 12,
        title: Image.asset('assets/logo.png', height: 36,
            errorBuilder: (_, __, ___) => const Row(children: [
              Text('Cine', style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 20)),
              Text('Stream', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ])),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: service.refresh,
          ),
          // Botón perfil → navega a ProfileScreen
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white70),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: service.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : service.hasError
              ? _ErrorWidget(service: service)
              : IndexedStack(
                  index: _currentIndex,
                  children: [
                    _PeliculasTab(service: service, history: history),
                    _SeriesTab(service: service, history: history),
                    _CanalesTab(service: service, favorites: favorites, isActive: _currentIndex == 2),
                    _HistoryTab(history: history),
                    _EventosTab(
                      isActive: _currentIndex == 4,
                      onReturnToTab: () => setState(() => _currentIndex = 4),
                    ),
                    const _PelotaLibreTab(),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF111118),
        selectedItemColor: const Color(0xFFE50914),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie),        label: 'Películas'),
          BottomNavigationBarItem(icon: Icon(Icons.tv),           label: 'Series'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv),      label: 'TV en Vivo'),
          BottomNavigationBarItem(icon: Icon(Icons.history),      label: 'Continuar'),
          BottomNavigationBarItem(icon: Icon(Icons.event),        label: 'Eventos'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'Fútbol'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// TAB PELÍCULAS
// ═══════════════════════════════════════════
class _PeliculasTab extends StatefulWidget {
  final ContentService service;
  final HistoryService history;
  const _PeliculasTab({required this.service, required this.history});
  @override
  State<_PeliculasTab> createState() => _PeliculasTabState();
}

class _PeliculasTabState extends State<_PeliculasTab> {
  String _search = '';
  String _genre  = '';
  int    _year   = 0;
  int    _page   = 0;
  static const int _pageSize = 30;

  List<Pelicula> get _filtered => widget.service.peliculas.where((p) =>
    (_search.isEmpty || p.title.toLowerCase().contains(_search.toLowerCase())) &&
    (_genre.isEmpty  || p.genres.contains(_genre)) &&
    (_year == 0      || p.year == _year)
  ).toList();

  List<Pelicula> get _paginated {
    final all = _filtered;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, all.length);
    return start < all.length ? all.sublist(start, end) : [];
  }

  int get _totalPages => (_filtered.length / _pageSize).ceil().clamp(1, 9999);

  void _resetPage() => setState(() => _page = 0);

  @override
  Widget build(BuildContext context) {
    final cont = widget.history.peliculas.where((h) => h.progress < 0.95).take(10).toList();
    return Column(children: [
      const BannerAdWidget(), // ── Banner publicitario ──
      _SearchBar(onChanged: (v) => setState(() { _search = v; _page = 0; })),
      _FilterRow(
        genres: widget.service.genresPeliculas,
        years:  widget.service.yearsPeliculas,
        selectedGenre: _genre, selectedYear: _year,
        onGenreChanged: (g) => setState(() { _genre = g; _page = 0; }),
        onYearChanged:  (y) => setState(() { _year  = y; _page = 0; }),
      ),
      Expanded(child: CustomScrollView(slivers: [
        if (cont.isNotEmpty && _search.isEmpty && _genre.isEmpty && _year == 0)
          SliverToBoxAdapter(child: _ContinueRow(items: cont, type: 'pelicula')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final p = _paginated[i];
              return _MovieCard(
                title: p.title, imageUrl: p.image,
                progress: widget.history.getProgress(p.url)?.progress,
                onTap: () => _navigate(ctx, p.url, p.title, p.image, 'pelicula'),
              );
            }, childCount: _paginated.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.65),
          ),
        ),
        SliverToBoxAdapter(
          child: _PaginationBar(
            currentPage: _page,
            totalPages:  _totalPages,
            totalItems:  _filtered.length,
            onPrev: _page > 0
                ? () => setState(() { _page--; })
                : null,
            onNext: _page < _totalPages - 1
                ? () => setState(() { _page++; })
                : null,
            onPage: (p) => setState(() => _page = p),
          ),
        ),
      ])),
    ]);
  }
}

// ═══════════════════════════════════════════
// TAB SERIES
// ═══════════════════════════════════════════
class _SeriesTab extends StatefulWidget {
  final ContentService service;
  final HistoryService history;
  const _SeriesTab({required this.service, required this.history});
  @override
  State<_SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends State<_SeriesTab> {
  String _search = '';
  String _genre  = '';
  int    _page   = 0;
  static const int _pageSize = 30;

  List<Serie> get _filtered => widget.service.series.where((s) =>
    (_search.isEmpty || s.title.toLowerCase().contains(_search.toLowerCase())) &&
    (_genre.isEmpty  || s.genres.contains(_genre))
  ).toList();

  List<Serie> get _paginated {
    final all = _filtered;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, all.length);
    return start < all.length ? all.sublist(start, end) : [];
  }

  int get _totalPages => (_filtered.length / _pageSize).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    final cont = widget.history.series.where((h) => h.progress < 0.95).take(10).toList();
    return Column(children: [
      const BannerAdWidget(), // ── Banner publicitario ──
      _SearchBar(onChanged: (v) => setState(() { _search = v; _page = 0; })),
      _FilterRow(
        genres: widget.service.genresSeries, years: const [],
        selectedGenre: _genre, selectedYear: 0,
        onGenreChanged: (g) => setState(() { _genre = g; _page = 0; }),
        onYearChanged: (_) {},
      ),
      Expanded(child: CustomScrollView(slivers: [
        if (cont.isNotEmpty && _search.isEmpty && _genre.isEmpty)
          SliverToBoxAdapter(child: _ContinueRow(items: cont, type: 'serie')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final s = _paginated[i];
              return _MovieCard(
                title: s.title, imageUrl: s.image,
                progress: s.episodes.isNotEmpty
                    ? widget.history.getProgress(s.episodes.first.url)?.progress : null,
                onTap: () => _showEpisodes(ctx, s),
              );
            }, childCount: _paginated.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.65),
          ),
        ),
        SliverToBoxAdapter(
          child: _PaginationBar(
            currentPage: _page,
            totalPages:  _totalPages,
            totalItems:  _filtered.length,
            onPrev: _page > 0
                ? () => setState(() { _page--; })
                : null,
            onNext: _page < _totalPages - 1
                ? () => setState(() { _page++; })
                : null,
            onPage: (p) => setState(() => _page = p),
          ),
        ),
      ])),
    ]);
  }

  void _showEpisodes(BuildContext context, Serie serie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16),
              child: Text(serie.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          Expanded(child: ListView.builder(
            controller: scroll,
            itemCount: serie.episodes.length,
            itemBuilder: (ctx, i) {
              final ep   = serie.episodes[i];
              final prog = context.read<HistoryService>().getProgress(ep.url);
              return ListTile(
                leading: Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF0A0A0F), borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white70)))),
                title: Text(ep.title, style: const TextStyle(color: Colors.white)),
                subtitle: prog != null ? LinearProgressIndicator(
                    value: prog.progress, backgroundColor: Colors.white12, color: const Color(0xFFE50914)) : null,
                trailing: const Icon(Icons.play_circle, color: Color(0xFFE50914)),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigate(
                    context,
                    ep.url,
                    serie.title,
                    serie.image,
                    'serie',
                    episodes: serie.episodes.map((e) => {
                      'title': e.title,
                      'url':   e.url,
                      'qualities': e.qualities,
                    }).toList(),
                    episodeIndex: i,
                  );
                },
              );
            },
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// TAB TV EN VIVO — usa TvPlayerWidget (FFmpeg)
// Mini player fijo + scroll libre de canales
// ═══════════════════════════════════════════
class _CanalesTab extends StatefulWidget {
  final ContentService   service;
  final FavoritesService favorites;
  final bool             isActive;
  const _CanalesTab({required this.service, required this.favorites, this.isActive = true});
  @override
  State<_CanalesTab> createState() => _CanalesTabState();
}

class _CanalesTabState extends State<_CanalesTab> {
  String _search   = '';
  String _category = '';
  bool   _soloFavs = false;

  Canal?  _activeCanal;
  String  _resolvedUrl  = '';    // URL resuelta (m3u8 directo)
  String  _refererUrl   = '';    // URL fuente para Referer CDN
  bool    _resolvingUrl = false; // true mientras se resuelve una URL PHP
  // Key para forzar rebuild del TvPlayerWidget cuando cambia el canal
  Key     _playerKey = UniqueKey();

  List<Canal> get _filtered {
    var list = widget.service.canales;
    if (_soloFavs)            list = list.where((c) => widget.favorites.isFavorite(c.url)).toList();
    if (_category.isNotEmpty) list = list.where((c) => c.category == _category).toList();
    if (_search.isNotEmpty)   list = list.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();
    return list;
  }

  bool _isDirectStream(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('.mpd') ||
        lower.contains('.ts') || lower.contains(':8080') || lower.contains('/live/');
  }

  Future<void> _selectChannel(Canal canal) async {
    if (_activeCanal?.url == canal.url) return;
    final needsResolve = !_isDirectStream(canal.url);
    setState(() {
      _activeCanal  = canal;
      _resolvedUrl  = needsResolve ? '' : canal.url;
      _refererUrl   = '';
      _resolvingUrl = needsResolve;
    });

    if (needsResolve) {
      final resolved = await _resolveM3u8(canal.url);
      if (!mounted) return;
      setState(() {
        _resolvedUrl  = resolved.isNotEmpty ? resolved : canal.url;
        _refererUrl   = resolved.isNotEmpty ? canal.url : '';
        _resolvingUrl = false;
        _playerKey    = UniqueKey();
      });
    } else {
      setState(() { _playerKey = UniqueKey(); });
    }
  }

  // ── Extrae el stream m3u8 desde una página PHP ──────────────
  Future<String> _resolveM3u8(String phpUrl) async {
    try {
      final uri    = Uri.parse(phpUrl);
      final origin = '${uri.scheme}://${uri.host}';
      final res = await http.get(Uri.parse(phpUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer':    '$origin/',
        'Accept':     'text/html,application/xhtml+xml,*/*',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return '';
      final html = res.body;
      final m3u8Re = RegExp(r'''https?://[^\s"'<>]+\.m3u8[^\s"'<>]*''', caseSensitive: false);
      final match  = m3u8Re.firstMatch(html);
      if (match != null) return match.group(0)!;
      for (final p in ['playbackURL = "', 'playbackURL="', '"file":"', '"src":"']) {
        final idx = html.indexOf(p);
        if (idx >= 0) {
          final vs = idx + p.length;
          final ve = html.indexOf('"', vs);
          if (ve > vs) {
            final url = html.substring(vs, ve);
            if (url.startsWith('http')) return url;
          }
        }
      }
      return '';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final favCount = widget.favorites.favorites.length;

    return Column(children: [
      const BannerAdWidget(), // ── Banner publicitario ──

      // ── Mini player fijo — media_kit/FFmpeg ─────────────
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _activeCanal != null ? 215 : 0,
        color: Colors.black,
        child: _activeCanal == null
            ? null
            : _resolvingUrl
                ? const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                : TvPlayerWidget(
                    key:             _playerKey,
                    url:             _resolvedUrl,
                    channelName:     _activeCanal!.name,
                    isActive:        widget.isActive,
                    refererOverride: _refererUrl.isNotEmpty ? _refererUrl : null,
                  ),
      ),

      // ── Búsqueda ─────────────────────────────────────────
      _SearchBar(onChanged: (v) => setState(() => _search = v)),

      // ── Filtros ───────────────────────────────────────────
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            _Chip(label: 'Todos', selected: !_soloFavs && _category.isEmpty,
                onTap: () => setState(() { _soloFavs = false; _category = ''; })),
            _Chip(
              label: '⭐ Favoritos${favCount > 0 ? ' ($favCount)' : ''}',
              selected: _soloFavs,
              color: const Color(0xFFFFAA00),
              onTap: () => setState(() { _soloFavs = !_soloFavs; _category = ''; }),
            ),
            ...widget.service.categoriesCanales.map((c) => _Chip(
              label: _cap(c), selected: !_soloFavs && _category == c,
              onTap: () => setState(() { _soloFavs = false; _category = _category == c ? '' : c; }),
            )),
          ],
        ),
      ),

      // ── Lista canales — scroll libre, player NO se detiene ─
      Expanded(
        child: _filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_soloFavs ? Icons.star_border : Icons.search_off, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                Text(
                  _soloFavs
                      ? 'No tienes favoritos aún\nToca ⭐ en un canal para agregarlo'
                      : 'No se encontraron canales',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final canal    = _filtered[i];
                  final isActive = _activeCanal?.url == canal.url;
                  final isFav    = widget.favorites.isFavorite(canal.url);
                  return Card(
                    color: isActive ? const Color(0xFF1e0f0f) : const Color(0xFF1a1a2e),
                    margin: const EdgeInsets.only(bottom: 7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isActive
                          ? const BorderSide(color: Color(0xFFE50914), width: 1.5)
                          : isFav
                              ? const BorderSide(color: Color(0xFFFFAA00), width: 1)
                              : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      leading: Container(
                        width: 72, height: 48,
                        decoration: BoxDecoration(
                            color: const Color(0xFF0A0A0F), borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.all(4),
                        child: CachedNetworkImage(
                          imageUrl: canal.logo, fit: BoxFit.contain,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.tv, color: Colors.white38, size: 26),
                        ),
                      ),
                      title: Text(canal.name, style: TextStyle(
                          color: isActive ? const Color(0xFFE50914) : Colors.white,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13)),
                      subtitle: Text(canal.category,
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: () => widget.favorites.toggle(canal.url),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: isFav ? const Color(0xFFFFAA00) : Colors.white24,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        isActive
                            ? const Icon(Icons.graphic_eq, color: Color(0xFFE50914), size: 22)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFE50914),
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('EN VIVO',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                      ]),
                      onTap: () => _selectChannel(canal),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ═══════════════════════════════════════════
// TAB CONTINUAR VIENDO
// ═══════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  final HistoryService history;
  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.items.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history, color: Colors.white24, size: 64),
        SizedBox(height: 16),
        Text('No has visto nada aún', style: TextStyle(color: Colors.white38, fontSize: 16)),
        SizedBox(height: 8),
        Text('Las películas y series que veas\naparecerán aquí',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 13)),
      ]));
    }
    return Column(children: [
      const BannerAdWidget(), // ── Banner publicitario ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Continuar viendo',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1a1a2e),
                title: const Text('Limpiar historial', style: TextStyle(color: Colors.white)),
                content: const Text('¿Eliminar todo el historial?',
                    style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
                  TextButton(
                    onPressed: () { history.clear(); Navigator.pop(context); },
                    child: const Text('Eliminar', style: TextStyle(color: Color(0xFFE50914))),
                  ),
                ],
              ),
            ),
            child: const Text('Limpiar', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ]),
      ),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.62),
        itemCount: history.items.length,
        itemBuilder: (ctx, i) {
          final item = history.items[i];
          return _MovieCard(
            title: item.title, imageUrl: item.image, progress: item.progress,
            onTap: () => _navigate(ctx, item.url, item.title, item.image, item.type),
          );
        },
      )),
    ]);
  }
}

// ═══════════════════════════════════════════
// WIDGETS REUTILIZABLES
// ═══════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Buscar...',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white38),
        filled: true, fillColor: const Color(0xFF1a1a2e),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

class _FilterRow extends StatelessWidget {
  final List<String> genres;
  final List<int>    years;
  final String selectedGenre;
  final int    selectedYear;
  final ValueChanged<String> onGenreChanged;
  final ValueChanged<int>    onYearChanged;
  const _FilterRow({required this.genres, required this.years, required this.selectedGenre,
      required this.selectedYear, required this.onGenreChanged, required this.onYearChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        _Chip(label: 'Todos', selected: selectedGenre.isEmpty && selectedYear == 0,
            onTap: () { onGenreChanged(''); onYearChanged(0); }),
        ...genres.map((g) => _Chip(label: _cap(g), selected: selectedGenre == g,
            onTap: () => onGenreChanged(selectedGenre == g ? '' : g))),
        ...years.take(10).map((y) => _Chip(label: '$y', selected: selectedYear == y,
            onTap: () => onYearChanged(selectedYear == y ? 0 : y))),
      ],
    ),
  );
  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Chip extends StatelessWidget {
  final String label;
  final bool   selected;
  final Color? color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? (color ?? const Color(0xFFE50914)) : const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.white54, fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    ),
  );
}

class _ContinueRow extends StatelessWidget {
  final List<dynamic> items;
  final String        type;
  const _ContinueRow({required this.items, required this.type});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Text('▶  Continuar viendo',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
    SizedBox(height: 155, child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return GestureDetector(
          onTap: () => _navigate(ctx, item.url, item.title, item.image, type),
          child: Container(width: 105, margin: const EdgeInsets.only(right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: item.image, width: double.infinity, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1a1a2e),
                          child: const Icon(Icons.movie, color: Colors.white24)))),
                Positioned(bottom: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(value: item.progress,
                      backgroundColor: Colors.white24, color: const Color(0xFFE50914), minHeight: 3)),
              ])),
              const SizedBox(height: 3),
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
          ),
        );
      },
    )),
  ]);
}

class _MovieCard extends StatelessWidget {
  final String  title;
  final String  imageUrl;
  final double? progress;
  final VoidCallback onTap;
  const _MovieCard({required this.title, required this.imageUrl, required this.onTap, this.progress});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(imageUrl: imageUrl, width: double.infinity, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1a1a2e),
                  child: const Icon(Icons.movie, color: Colors.white24)))),
        if (progress != null && progress! > 0)
          Positioned(bottom: 0, left: 0, right: 0,
            child: LinearProgressIndicator(value: progress,
                backgroundColor: Colors.white24, color: const Color(0xFFE50914), minHeight: 3)),
      ])),
      const SizedBox(height: 4),
      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );
}

// ═══════════════════════════════════════════
// TAB EVENTOS DEPORTIVOS
// ═══════════════════════════════════════════
class _Evento {
  final String title;
  final String time;
  final String status;
  final String date;
  final String link;
  final String category;
  final String channelName;

  const _Evento({
    required this.title,
    required this.time,
    required this.status,
    required this.date,
    required this.link,
    required this.category,
    required this.channelName,
  });

  // Formato antiguo: { title, link, time, date, category, status }
  factory _Evento.fromJson(Map<String, dynamic> j) {
    final url = (j['link'] as String? ?? '').trim();
    String channelName = '';
    // Extraer canal desde ?stream=X o ?channel=X
    for (final param in ['stream=', 'channel=']) {
      final idx = url.indexOf(param);
      if (idx >= 0) {
        channelName = url.substring(idx + param.length);
        final ampIdx = channelName.indexOf('&');
        if (ampIdx >= 0) channelName = channelName.substring(0, ampIdx);
        break;
      }
    }
    return _Evento(
      title:       (j['title']    as String? ?? '').trim(),
      time:        (j['time']     as String? ?? '').trim(),
      status:      (j['status']   as String? ?? '').trim(),
      date:        (j['date']     as String? ?? '').trim(),
      link:        url,
      category:    (j['category'] as String? ?? '').trim(),
      channelName: channelName,
    );
  }

  // Formato nuevo con canal específico: { titulo, hora, fecha, categoria, canales:[{nombre,iframe}] }
  static String _clean(String s) =>
      s.replaceAll('\n', ' ').replaceAll('\r', '').replaceAll(RegExp(r' {2,}'), ' ').trim();

  factory _Evento.fromJsonNew(Map<String, dynamic> j, Map<String, dynamic> canal) {
    final isLive = j['fecha'] == null || (j['fecha'] as String? ?? '').isEmpty;
    return _Evento(
      title:       _clean(j['titulo']    as String? ?? ''),
      time:        _clean(j['hora']      as String? ?? ''),
      date:        _clean(j['fecha']     as String? ?? ''),
      status:      isLive ? 'En vivo' : 'Pronto',
      link:        _clean(canal['iframe'] as String? ?? ''),
      category:    _clean(j['categoria'] as String? ?? j['liga'] as String? ?? 'Deporte'),
      channelName: _clean(canal['nombre'] as String? ?? ''),
    );
  }
}

class _EventosTab extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onReturnToTab;
  const _EventosTab({this.isActive = true, this.onReturnToTab});
  @override
  State<_EventosTab> createState() => _EventosTabState();
}

class _EventosTabState extends State<_EventosTab> {
  List<_Evento> _eventos   = [];
  bool   _loading          = true;
  String _error            = '';
  String _search           = '';
  String _filter           = 'Todos';

  // ── Player embebido ──────────────────────────────────────────
  _Evento?      _playingEvento;
  bool          _embeddedActive   = true;
  bool          _useWebViewPlayer = false;
  List<_Evento> _matchChannels    = []; // todos los canales del mismo partido
  int           _channelIndex     = 0;  // canal que se está intentando

  // JS: autoplay + skip ads + confirm dialogs (sin interferir con stream)
  // _playerJs eliminado — ya no se usa WebView para eventos

  @override
  void initState() {
    super.initState();
    _loadEventos();
  }

  static const List<String> _eventUrls = [
    // 1° — JSON propio (generado automaticamente cada dia por GitHub Actions)
    'https://raw.githubusercontent.com/colombiaiptv903-crypto/Eventos/refs/heads/main/agenda123.json',
    // 2° — CDN espejo del mismo repo (mas rapido en algunas regiones)
    'https://cdn.jsdelivr.net/gh/colombiaiptv903-crypto/Eventos@main/agenda123.json',
    // 3° — Fallback externo
    'https://la14hd.com/eventos/json/agenda123.json',
  ];

  // Fetch una URL y devuelve lista JSON o null si falla
  Future<List<dynamic>?> _fetchUrl(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
        'Accept':     'application/json, */*',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final decoded = json.decode(res.body);
      return decoded is List ? decoded as List<dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadEventos() async {
    setState(() { _loading = true; _error = ''; });
    try {
      // ── Carga paralela: todas las URLs a la vez, primera válida gana ──
      final completer = Completer<List<dynamic>?>();
      int pending = _eventUrls.length;
      for (final url in _eventUrls) {
        _fetchUrl(url).then((data) {
          if (data != null && !completer.isCompleted) {
            completer.complete(data);
          } else {
            pending--;
            if (pending == 0 && !completer.isCompleted) completer.complete(null);
          }
        });
      }
      final data = await completer.future
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (data != null) {
        final now      = DateTime.now();
        final todayStr = '${now.year}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';

        final List<_Evento> parsed = [];
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          final canales = item['canales'] as List<dynamic>?;
          if (canales != null && canales.isNotEmpty) {
            // Nuevo formato:
            // - fecha == null  → en vivo → mostrar
            // - fecha == hoy   → programado hoy → mostrar
            // - fecha == otro  → otro día → saltar
            final fecha = item['fecha'] as String?;
            if (fecha != null && fecha.isNotEmpty && fecha != todayStr) continue;
            for (final c in canales) {
              if (c is! Map<String, dynamic>) continue;
              final e = _Evento.fromJsonNew(item, c);
              if (e.link.isNotEmpty && e.title.isNotEmpty) parsed.add(e);
            }
          } else {
            // Formato antiguo — mostrar si es hoy o sin fecha (en vivo)
            final fecha = item['date'] as String?;
            if (fecha != null && fecha.isNotEmpty && fecha != todayStr) continue;
            final e = _Evento.fromJson(item);
            if (e.link.isNotEmpty && e.title.isNotEmpty) parsed.add(e);
          }
        }
        setState(() { _eventos = parsed; _loading = false; _updateCaches(); });
      } else {
        setState(() { _error = 'No se pudieron cargar eventos'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Extrae el stream real desde la página PHP del evento ─
  Future<String> _resolveM3u8(String phpUrl) async {
    try {
      // Usar el dominio de la página como Referer para evitar bloqueos
      final uri    = Uri.parse(phpUrl);
      final origin = '${uri.scheme}://${uri.host}';

      final res = await http.get(Uri.parse(phpUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer':    '$origin/',
        'Accept':     'text/html,application/xhtml+xml,*/*',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return '';
      final html = res.body;

      // 1. Buscar cualquier URL m3u8 directa con regex (más robusto)
      final m3u8Re = RegExp(
        r'''https?://[^\s"'<>]+\.m3u8[^\s"'<>]*''',
        caseSensitive: false,
      );
      final m3u8Match = m3u8Re.firstMatch(html);
      if (m3u8Match != null) return m3u8Match.group(0)!;

      // 2. Buscar src de iframe con URL de stream
      final iframeIdx = html.indexOf('<iframe');
      if (iframeIdx >= 0) {
        final srcIdx = html.indexOf('src="', iframeIdx);
        if (srcIdx >= 0) {
          final srcStart = srcIdx + 5;
          final srcEnd   = html.indexOf('"', srcStart);
          if (srcEnd > srcStart) {
            final src = html.substring(srcStart, srcEnd);
            if (src.contains('/live') || src.contains('stream') || src.contains('/hls')) {
              return src.startsWith('http') ? src : '$origin$src';
            }
          }
        }
      }

      // 3. Patrones JWPlayer / VideoJS / Clappr / playbackURL
      for (final p in [
        'playbackURL = "', 'playbackURL="', 'playbackURL = \'', "playbackURL='",
        '"file":"', "'file':'", '"src":"', 'source:"',
      ]) {
        final idx = html.indexOf(p);
        if (idx >= 0) {
          final quote = p.contains('"') ? '"' : "'";
          final vs = idx + p.length;
          final ve = html.indexOf(quote, vs);
          if (ve > vs) {
            final url = html.substring(vs, ve);
            if (url.startsWith('http')) return url;
          }
        }
      }

      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _selectEvento(_Evento ev) {
    WakelockPlus.enable().catchError((_) {});
    // Recopilar todos los canales del mismo partido (mismo título)
    final channels = _eventos
        .where((e) => e.title == ev.title && e.link.isNotEmpty)
        .toList();
    final idx = channels.indexWhere((e) => e.link == ev.link);
    setState(() {
      _playingEvento    = ev;
      _matchChannels    = channels;
      _channelIndex     = idx < 0 ? 0 : idx;
      _embeddedActive   = true;
      _useWebViewPlayer = false;
    });
  }

  void _closePlayer() {
    WakelockPlus.disable().catchError((_) {});
    setState(() {
      _playingEvento    = null;
      _matchChannels    = [];
      _channelIndex     = 0;
      _embeddedActive   = true;
      _useWebViewPlayer = false;
    });
  }

  void _onPlayerError() {
    if (!mounted) return;
    // Intentar siguiente canal del mismo partido
    final nextIdx = _channelIndex + 1;
    if (nextIdx < _matchChannels.length) {
      setState(() {
        _channelIndex     = nextIdx;
        _playingEvento    = _matchChannels[nextIdx];
        _useWebViewPlayer = false;
      });
    } else {
      // Todos los canales fallaron con ExoPlayer → WebView
      setState(() => _useWebViewPlayer = true);
    }
  }

  void _openFullscreen() {
    // El TvPlayerWidget ya tiene su propio botón de fullscreen integrado.
    // Este método queda como fallback si se necesita abrir desde otro lugar.
    if (_playingEvento == null || !mounted) return;
    final ev    = _playingEvento!;
    final title = ev.time.isNotEmpty ? '${ev.time} - ${ev.title}' : ev.title;
    setState(() => _embeddedActive = false);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebEventPlayerScreen(url: ev.link, title: title),
    )).then((_) {
      if (mounted) {
        setState(() => _embeddedActive = true);
        widget.onReturnToTab?.call();
      }
    });
  }

  // Mini-player: prueba cada canal del partido hasta que uno funcione
  Widget _buildEmbeddedPlayer() {
    final ev    = _playingEvento!;
    final title = ev.time.isNotEmpty ? '${ev.time} - ${ev.title}' : ev.title;

    return Column(mainAxisSize: MainAxisSize.min, children: [

      // ── Video player ───────────────────────────────────────
      Stack(children: [
        SizedBox(
          height: 220,
          child: _useWebViewPlayer
              ? _EmbeddedWebEventPlayer(
                  key: ValueKey('web_${ev.link}'),
                  url: ev.link, title: title,
                  onClose: _closePlayer, onFullscreen: _openFullscreen,
                )
              : TvPlayerWidget(
                  key: ValueKey('tv_${ev.link}_$_channelIndex'),
                  url: ev.link,
                  channelName: '${ev.channelName.isNotEmpty ? ev.channelName : title}',
                  isActive: widget.isActive && _embeddedActive,
                  onError: _onPlayerError,
                ),
        ),
        // Botón cerrar
        Positioned(
          top: 6, right: 6,
          child: GestureDetector(
            onTap: _closePlayer,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ),
        ),
      ]),

      // ── Selector de canales (si hay más de uno) ────────────
      if (_matchChannels.length > 1)
        Container(
          color: const Color(0xFF0A0A0F),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text('CANALES DISPONIBLES',
                  style: TextStyle(color: Colors.white38, fontSize: 9,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            SizedBox(
              height: 30,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _matchChannels.length,
                itemBuilder: (_, i) {
                  final ch      = _matchChannels[i];
                  final active  = i == _channelIndex;
                  return GestureDetector(
                    onTap: () {
                      if (active) return;
                      setState(() {
                        _channelIndex     = i;
                        _playingEvento    = ch;
                        _useWebViewPlayer = false;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFE50914) : const Color(0xFF1a1a2e),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? const Color(0xFFE50914) : Colors.white24),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (active)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.graphic_eq, color: Colors.white, size: 10),
                          ),
                        Text(
                          ch.channelName.isNotEmpty ? ch.channelName : 'Canal ${i + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
    ]);
  }

  // ── Parser de fecha robusto (YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY) ──
  DateTime? _parseEventDate(String raw) {
    if (raw.isEmpty) return null;
    // ISO: YYYY-MM-DD
    try { return DateTime.parse(raw.trim()); } catch (_) {}
    // DD/MM/YYYY
    final slash = raw.trim().split('/');
    if (slash.length == 3 && slash[2].length == 4) {
      try {
        return DateTime(int.parse(slash[2]), int.parse(slash[1]), int.parse(slash[0]));
      } catch (_) {}
    }
    // DD-MM-YYYY
    final dash = raw.trim().split('-');
    if (dash.length == 3 && dash[2].length == 4) {
      try {
        return DateTime(int.parse(dash[2]), int.parse(dash[1]), int.parse(dash[0]));
      } catch (_) {}
    }
    return null;
  }

  // ── Parser de hora robusto (HH:MM, HH:MM AM/PM) ──────────────
  DateTime? _parseEventTime(String raw, DateTime day) {
    if (raw.isEmpty) return null;
    try {
      String s = raw.trim().toUpperCase();
      final isPM = s.contains('PM');
      s = s.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = s.split(':');
      int h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPM && h < 12) h += 12;
      if (!isPM && h == 12) h = 0;
      return DateTime(day.year, day.month, day.day, h, m);
    } catch (_) {
      return null;
    }
  }

  // ── Cached computed lists (recomputed only when data/filter changes) ──
  List<_Evento> _filteredCache   = [];
  List<String>  _categoriesCache = [];

  List<_Evento> get _filtered   => _filteredCache;
  List<String>  get _categories => _categoriesCache;

  void _updateCaches() {
    // categories
    final cats = <String>{'Todos', ..._eventos.map((e) => e.category)};
    _categoriesCache = cats.toList();
    // filtered
    var list = _filter == 'Todos'
        ? _eventos
        : _eventos.where((e) => e.category == _filter).toList();
    final visible = list.where((e) {
      final st = e.status.toLowerCase();
      if (st == 'finalizado' || st == 'finished' || st == 'ended') return false;
      return true;
    }).toList();
    if (_search.isEmpty) {
      _filteredCache = visible;
      return;
    }
    final q = _search.toLowerCase();
    _filteredCache = visible.where((e) =>
      e.title.toLowerCase().contains(q) ||
      e.category.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Player embebido (visible cuando hay evento seleccionado) ──
      if (_playingEvento != null) ...[
        // Indicador del evento en reproducción
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: const Color(0xFF0D2B0D),
          child: Row(children: [
            const Icon(Icons.graphic_eq, color: Color(0xFF69F0AE), size: 14),
            const SizedBox(width: 6),
            const Text('REPRODUCIENDO: ',
                style: TextStyle(color: Color(0xFF69F0AE), fontSize: 10, fontWeight: FontWeight.bold)),
            Expanded(
              child: Text(
                _playingEvento!.title,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        _buildEmbeddedPlayer(),
      ],

      const BannerAdWidget(),

      // ── Cabecera ──────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(children: [
          const Icon(Icons.event, color: Color(0xFFE50914), size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Eventos en Vivo',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            onPressed: _loadEventos,
            tooltip: 'Actualizar',
          ),
        ]),
      ),

      // ── Buscador ──────────────────────────────────────────
      _SearchBar(onChanged: (v) => setState(() { _search = v; _updateCaches(); })),

      // ── Filtros de categoría ─────────────────────────────
      if (_eventos.isNotEmpty)
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            children: _categories.map((cat) {
              final selected = _filter == cat;
              return GestureDetector(
                onTap: () => setState(() { _filter = cat; _updateCaches(); }),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFE50914) : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? const Color(0xFFE50914) : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(cat, style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  )),
                ),
              );
            }).toList(),
          ),
        ),

      // ── Contenido con scroll libre ────────────────────────
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
    }
    if (_error.isNotEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off, color: Colors.white24, size: 56),
        const SizedBox(height: 12),
        Text('No se pudieron cargar los eventos\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
          onPressed: _loadEventos,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ]));
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off, color: Colors.white24, size: 56),
        const SizedBox(height: 12),
        Text(
          _search.isEmpty ? 'No hay eventos disponibles' : 'Sin resultados para "$_search"',
          style: const TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ]));
    }

    // Agrupar por categoría y construir lista plana para ListView.builder
    final Map<String, List<_Evento>> byCategory = {};
    for (final e in list) {
      byCategory.putIfAbsent(e.category, () => []).add(e);
    }

    // Lista plana: String = encabezado de categoría, _Evento = item
    final items = <Object>[];
    for (final cat in byCategory.keys) {
      items.add(cat);                    // encabezado
      items.addAll(byCategory[cat]!);    // eventos
    }
    items.add('__end__');                // padding final

    return RepaintBoundary(child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item == '__end__') return const SizedBox(height: 16);
        if (item is String) {
          // Encabezado de categoría
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Row(children: [
              Container(width: 3, height: 16, color: const Color(0xFFE50914),
                  margin: const EdgeInsets.only(right: 8)),
              Text(item, style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('(${byCategory[item]!.length})',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          );
        }
        // Tarjeta de evento
        final ev = item as _Evento;
        final isPlaying = _playingEvento?.link == ev.link;
        return _EventoCard(
          evento:   ev,
          isActive: isPlaying,
          onSelect: () => _selectEvento(ev),
        );
      },
    ));
  }
}

// ── Estado visual del evento ──────────────────────────────────────
enum _EvState { live, soon, finished, upcoming }

/// Devuelve true si el evento empieza dentro de los próximos [mins] minutos.
bool _startsWithin(String timeStr, int mins) {
  if (timeStr.isEmpty) return false;
  try {
    final parts = timeStr.split(':');
    if (parts.length < 2) return false;
    final h = int.parse(parts[0].trim());
    final m = int.parse(parts[1].trim().replaceAll(RegExp(r'[^0-9]'), ''));
    final now  = DateTime.now();
    final evDt = DateTime(now.year, now.month, now.day, h, m);
    final diff = evDt.difference(now).inMinutes;
    return diff >= 0 && diff <= mins;
  } catch (_) { return false; }
}

_EvState _evStateOf(_Evento ev) {
  final st = ev.status.toLowerCase();
  if (st.contains('vivo') || st.contains('live'))            return _EvState.live;
  if (st.contains('finaliz') || st.contains('finish') ||
      st.contains('ended'))                                   return _EvState.finished;
  if (st.contains('pronto') || st.contains('soon') ||
      _startsWithin(ev.time, 30))                            return _EvState.soon;
  return _EvState.upcoming;
}

Widget _buildEvBadge(_EvState state, String status) {
  switch (state) {
    case _EvState.live:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(5)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, color: Color(0xFF69F0AE), size: 7),
          SizedBox(width: 4),
          Text('EN VIVO',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
      );
    case _EvState.soon:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFF0D47A1), borderRadius: BorderRadius.circular(5)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.schedule_rounded, color: Colors.white70, size: 10),
          SizedBox(width: 4),
          Text('PRONTO',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
      );
    case _EvState.finished:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white12)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, color: Colors.white24, size: 10),
          SizedBox(width: 4),
          Text('FINALIZADO', style: TextStyle(color: Colors.white38, fontSize: 9)),
        ]),
      );
    case _EvState.upcoming:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.access_time, color: Colors.white38, size: 10),
          const SizedBox(width: 4),
          Text(status.isNotEmpty ? status : 'Próximo',
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ]),
      );
  }
}

class _EventoCard extends StatelessWidget {
  final _Evento      evento;
  final bool         isActive;
  final VoidCallback onSelect;
  const _EventoCard({
    required this.evento,
    required this.isActive,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final state = isActive ? _EvState.live : _evStateOf(evento);

    // Colores según estado
    final (bgColor, borderColor, accentColor) = switch (state) {
      _EvState.live     => (const Color(0xFF071A07), const Color(0xFF2E7D32), const Color(0xFF4CAF50)),
      _EvState.soon     => (const Color(0xFF07091A), const Color(0xFF1565C0), const Color(0xFF42A5F5)),
      _EvState.finished => (const Color(0xFF111115), const Color(0xFF2A2A2A), Colors.white24),
      _EvState.upcoming => (const Color(0xFF1a1a2e), Colors.transparent,      const Color(0xFFE50914)),
    };

    return Card(
      color: isActive ? const Color(0xFF071A07) : bgColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActive
            ? const BorderSide(color: Color(0xFF4CAF50), width: 1.5)
            : borderColor != Colors.transparent
                ? BorderSide(color: borderColor, width: 1)
                : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: evento.link.isEmpty ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Icono del deporte
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.sports_soccer, color: accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            // Info del partido
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(evento.title,
                  style: TextStyle(
                    color: isActive ? const Color(0xFF69F0AE) : Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              if (evento.channelName.isNotEmpty)
                Row(children: [
                  const Icon(Icons.tv, color: Colors.white38, size: 11),
                  const SizedBox(width: 4),
                  Text(evento.channelName,
                      style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w500)),
                ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.access_time, color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text(evento.time, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (evento.date.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.calendar_today, color: Colors.white38, size: 12),
                  const SizedBox(width: 4),
                  Text(evento.date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ]),
            ])),
            const SizedBox(width: 8),
            // Badge estado + icono acción
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildEvBadge(state, evento.status),
              const SizedBox(height: 6),
              isActive
                  ? const Icon(Icons.graphic_eq, color: Color(0xFF4CAF50), size: 22)
                  : Icon(Icons.play_circle, color: accentColor, size: 22),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// MINI-PLAYER DE EVENTOS (video_player / ExoPlayer)
// ═══════════════════════════════════════════
class _EventoMiniPlayer extends StatefulWidget {
  final String url;
  final String title;
  final bool isActive;
  const _EventoMiniPlayer({super.key, required this.url, required this.title, this.isActive = true});
  @override
  State<_EventoMiniPlayer> createState() => _EventoMiniPlayerState();
}

class _EventoMiniPlayerState extends State<_EventoMiniPlayer> with RouteAware {
  static const String _ua =
      'Mozilla/5.0 (Linux; Android 10; K) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/114.0.0.0 Mobile Safari/537.36';

  static const Map<String, String> _headers = {
    'User-Agent':    _ua,
    'Referer':       'https://streamx550.com/',
    'Accept':        '*/*',
    'Cache-Control': 'no-cache, no-store',
    'Pragma':        'no-cache',
    'Connection':    'keep-alive',
  };

  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError    = false;
  String _errorMsg  = '';
  int _initToken    = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) WakelockPlus.enable().catchError((_) {});
    _initPlayer(widget.url);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  // Se abre una pantalla encima (ej: PlayerScreen de película/serie)
  @override
  void didPushNext() {
    _ctrl?.pause();
    WakelockPlus.disable().catchError((_) {});
  }

  // La pantalla encima se cerró — reanudar si el tab está activo
  @override
  void didPopNext() {
    if (widget.isActive && _initialized) {
      _ctrl?.play();
      WakelockPlus.enable().catchError((_) {});
    }
  }

  @override
  void didUpdateWidget(_EventoMiniPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _initPlayer(widget.url);
    } else if (old.isActive && !widget.isActive) {
      // Usuario cambió de tab — pausar y liberar wakelock
      _ctrl?.pause();
      WakelockPlus.disable().catchError((_) {});
    } else if (!old.isActive && widget.isActive) {
      // Usuario volvió a la tab de eventos — reanudar y activar wakelock
      if (_initialized) _ctrl?.play();
      WakelockPlus.enable().catchError((_) {});
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WakelockPlus.disable().catchError((_) {});
    _ctrl?.dispose();
    super.dispose();
  }

  VideoFormat _detectFormat(String url) {
    final path = url.toLowerCase().split('?').first;
    if (path.contains('.m3u8')) return VideoFormat.hls;
    if (path.contains('.mpd'))  return VideoFormat.dash;
    return VideoFormat.hls;
  }

  Future<void> _initPlayer(String url, {VideoFormat? forceFormat}) async {
    final myToken = ++_initToken;
    await _ctrl?.dispose();
    _ctrl = null;
    if (!mounted || myToken != _initToken) return;
    setState(() { _initialized = false; _hasError = false; _errorMsg = ''; });

    final format = forceFormat ?? _detectFormat(url);
    VideoPlayerController? ctrl;
    try {
      ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _headers,
        formatHint: format,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await ctrl.initialize().timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('timeout'),
      );

      if (!mounted || myToken != _initToken) { ctrl.dispose(); return; }
      if (ctrl.value.hasError) {
        final desc = ctrl.value.errorDescription ?? 'Error';
        ctrl.dispose();
        throw Exception(desc);
      }

      _ctrl = ctrl;
      _ctrl!.setLooping(false);
      // Solo reproducir si el tab de eventos sigue activo
      if (widget.isActive) {
        _ctrl!.play();
        WakelockPlus.enable().catchError((_) {});
      }
      if (mounted) setState(() => _initialized = true);

    } catch (e) {
      ctrl?.dispose();
      if (!mounted || myToken != _initToken) return;
      final errStr = e.toString();
      final isCodecOrSource = errStr.contains('ExoPlayback') ||
          errStr.contains('MediaCodec') || errStr.contains('ParserException') ||
          errStr.contains('UnrecognizedInputFormat');
      // Retry with VideoFormat.other on first attempt
      if (isCodecOrSource && forceFormat == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted || myToken != _initToken) return;
        await _initPlayer(url, forceFormat: VideoFormat.other);
        return;
      }
      if (mounted) setState(() {
        _hasError  = true;
        _errorMsg  = 'Sin señal';
      });
    }
  }

  void _openFullscreen() {
    _ctrl?.pause();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EventPlayerScreen(
        events: [EventItem(url: widget.url, title: widget.title)],
      ),
    )).then((_) {
      // Retomar mini-player al volver del fullscreen
      if (widget.isActive) WakelockPlus.enable().catchError((_) {});
      _initPlayer(widget.url);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.signal_wifi_off, color: Colors.white38, size: 36),
          const SizedBox(height: 8),
          Text(_errorMsg, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _initPlayer(widget.url),
            icon: const Icon(Icons.refresh, color: Color(0xFFE50914), size: 18),
            label: const Text('Reintentar', style: TextStyle(color: Color(0xFFE50914), fontSize: 12)),
          ),
        ]),
      );
    }

    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2),
          const SizedBox(height: 8),
          Text(widget.title,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ])),
      );
    }

    return GestureDetector(
      onTap: _openFullscreen,
      child: Stack(fit: StackFit.expand, children: [
        AspectRatio(
          aspectRatio: _ctrl!.value.aspectRatio,
          child: VideoPlayer(_ctrl!),
        ),
        // Overlay: badge EN VIVO + botón fullscreen
        Positioned(
          top: 6, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('EN VIVO',
                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ),
        Positioned(
          top: 4, right: 4,
          child: Icon(Icons.fullscreen, color: Colors.white.withValues(alpha: 0.8), size: 24),
        ),
        // Título en la parte inferior
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
            child: Text(widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w500, shadows: [Shadow(blurRadius: 4)]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ]),
    );
  }
}
class _ErrorWidget extends StatelessWidget {
  final ContentService service;
  const _ErrorWidget({required this.service});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.wifi_off, color: Colors.white38, size: 64),
    const SizedBox(height: 16),
    Text(service.errorMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
    const SizedBox(height: 24),
    ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
      onPressed: service.refresh,
      child: const Text('Reintentar'),
    ),
  ]));
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

void _navigate(BuildContext ctx, String url, String title, String image, String type,
    {List<Map<String, dynamic>> episodes = const [], int episodeIndex = 0}) {
  if (url.isEmpty) return;
  Navigator.push(ctx, MaterialPageRoute(
    builder: (_) => PlayerScreen(
      url:                  url,
      title:                title,
      image:                image,
      type:                 type,
      episodes:             episodes,
      currentEpisodeIndex:  episodeIndex,
    ),
  ));
}

// ═══════════════════════════════════════════
// PAGINACIÓN
// ═══════════════════════════════════════════
class _PaginationBar extends StatelessWidget {
  final int  currentPage;
  final int  totalPages;
  final int  totalItems;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final void Function(int) onPage;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPrev,
    required this.onNext,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    // Calcular páginas a mostrar (máx 5 botones alrededor de la actual)
    final List<int> pages = [];
    final start = (currentPage - 2).clamp(0, (totalPages - 5).clamp(0, totalPages));
    final end   = (start + 5).clamp(0, totalPages);
    for (int i = start; i < end; i++) pages.add(i);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(children: [
        // Contador de resultados
        Text(
          'Página ${currentPage + 1} de $totalPages  ·  $totalItems resultados',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
        // Controles de página
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Botón anterior
          _PageBtn(
            icon: Icons.chevron_left,
            onTap: onPrev,
            active: false,
          ),
          const SizedBox(width: 4),
          // Primera página si no está visible
          if (pages.isNotEmpty && pages.first > 0) ...[
            _PageBtn(label: '1', onTap: () => onPage(0), active: currentPage == 0),
            if (pages.first > 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Colors.white38)),
              ),
          ],
          // Páginas centrales
          ...pages.map((p) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _PageBtn(
              label: '${p + 1}',
              onTap: () => onPage(p),
              active: p == currentPage,
            ),
          )),
          // Última página si no está visible
          if (pages.isNotEmpty && pages.last < totalPages - 1) ...[
            if (pages.last < totalPages - 2)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Colors.white38)),
              ),
            _PageBtn(
              label: '$totalPages',
              onTap: () => onPage(totalPages - 1),
              active: currentPage == totalPages - 1,
            ),
          ],
          const SizedBox(width: 4),
          // Botón siguiente
          _PageBtn(
            icon: Icons.chevron_right,
            onTap: onNext,
            active: false,
          ),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String?      label;
  final IconData?    icon;
  final VoidCallback? onTap;
  final bool         active;

  const _PageBtn({this.label, this.icon, this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  36, height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE50914)
              : enabled ? const Color(0xFF1a1a2e) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? const Color(0xFFE50914)
                : enabled ? Colors.white12 : Colors.transparent,
          ),
        ),
        child: icon != null
            ? Icon(icon, color: enabled ? Colors.white70 : Colors.white24, size: 18)
            : Text(
                label ?? '',
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PELOTA LIBRE TAB — Agenda de fútbol en vivo (mobile)
// ══════════════════════════════════════════════════════════════════
class _PelotaLibreTab extends StatefulWidget {
  const _PelotaLibreTab();
  @override
  State<_PelotaLibreTab> createState() => _PelotaLibreTabState();
}

class _PelotaLibreTabState extends State<_PelotaLibreTab> {
  List<DiaryEvent> _events   = [];
  List<DiaryEvent> _filtered = [];
  List<String>     _categories = [];
  bool   _loading = true;
  String _error   = '';
  String _selectedCat = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final events = await DiaryService().fetchToday();
      final cats   = <String>['Todos', ...{
        ...events.map((e) => e.competition).where((c) => c.isNotEmpty)
      }];
      setState(() {
        _events     = events;
        _categories = cats;
        _loading    = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter([String? cat]) {
    final c = cat ?? _selectedCat;
    setState(() {
      _selectedCat = c;
      _filtered = c == 'Todos'
          ? _events
          : _events.where((e) => e.competition == c).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Color(0xFF00C853)),
          SizedBox(height: 12),
          Text('Cargando agenda...', style: TextStyle(color: Colors.white54)),
        ]),
      );
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sports_soccer, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            const Text('Error al cargar la agenda',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853)),
            ),
          ]),
        ),
      );
    }

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────
        Container(
          color: const Color(0xFF111118),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.sports_soccer,
                    color: Color(0xFF00C853), size: 18),
                const SizedBox(width: 8),
                const Text('PELOTA LIBRE',
                    style: TextStyle(
                        color: Color(0xFF00C853),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const Spacer(),
                Text('${_filtered.length} partidos hoy',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ]),
              const SizedBox(height: 10),
              // Chips de categorías
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final sel = cat == _selectedCat;
                    return GestureDetector(
                      onTap: () => _applyFilter(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00C853)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF00C853)
                                : Colors.white24,
                          ),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                color: sel ? Colors.white : Colors.white54,
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        // ── Lista ───────────────────────────────────────────
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.search_off,
                        color: Colors.white24, size: 40),
                    const SizedBox(height: 8),
                    Text('Sin partidos en "$_selectedCat"',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 14)),
                  ]),
                )
              : RefreshIndicator(
                  color: const Color(0xFF00C853),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) =>
                        _PLEventCard(event: _filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Tarjeta de evento mobile ─────────────────────────────────────
class _PLEventCard extends StatelessWidget {
  final DiaryEvent event;
  const _PLEventCard({required this.event});

  Color get _color {
    final c = event.competition.toLowerCase();
    if (c.contains('libertadores')) return const Color(0xFFFFD700);
    if (c.contains('sudamericana')) return const Color(0xFF4FC3F7);
    if (c.contains('champions'))    return const Color(0xFF9C27B0);
    if (c.contains('concacaf'))     return const Color(0xFFFF7043);
    if (c.contains('premier'))      return const Color(0xFF6A0DAD);
    if (c.contains('laliga') || c.contains('la liga')) return const Color(0xFFE50914);
    if (c.contains('mlb') || c.contains('nba') || c.contains('nfl')) return const Color(0xFF0066CC);
    return const Color(0xFF00C853);
  }

  @override
  Widget build(BuildContext context) {
    final hasStream = event.embeds.isNotEmpty;
    return GestureDetector(
      onTap: hasStream
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PelotaLibrePlayerScreen(event: event),
                ),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // Barra de color
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12)),
              ),
            ),
            // Hora
            SizedBox(
              width: 62,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(event.formattedHour,
                      style: TextStyle(
                          color: _color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const Text('hs',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            Container(width: 1, height: 44, color: Colors.white10),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.competition.isNotEmpty)
                      Text(event.competition.toUpperCase(),
                          style: TextStyle(
                              color: _color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1)),
                    const SizedBox(height: 2),
                    Text(event.matchName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (event.country != null)
                      Text(event.country!.name,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ),
            // Play / Schedule
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: hasStream
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00C853),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(height: 3),
                        Text('${event.embeds.length} HD',
                            style: const TextStyle(
                                color: Color(0xFF00C853),
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Icon(Icons.schedule,
                      color: Colors.white24, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _EmbeddedWebEventPlayer — Mini-player WebView para Eventos
// Igual que Pelota Libre: carga la página del stream en WebView.
// Funciona en WiFi y datos móviles sin depender de ExoPlayer.
// ══════════════════════════════════════════════════════════════════
class _EmbeddedWebEventPlayer extends StatefulWidget {
  final String url;
  final String title;
  final VoidCallback onClose;
  final VoidCallback onFullscreen;

  const _EmbeddedWebEventPlayer({
    super.key,
    required this.url,
    required this.title,
    required this.onClose,
    required this.onFullscreen,
  });

  @override
  State<_EmbeddedWebEventPlayer> createState() => _EmbeddedWebEventPlayerState();
}

class _EmbeddedWebEventPlayerState extends State<_EmbeddedWebEventPlayer> {
  WebViewController? _ctrl;
  bool _loading = true;

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';

  static const String _autoPlayJs = r'''
    (function() {
      if (window.__csEmbedInjected) return;
      window.__csEmbedInjected = true;

      // Ocultar chrome de la página
      var css = document.createElement('style');
      css.textContent =
        'body,html{margin:0!important;padding:0!important;background:#000!important;overflow:hidden!important}' +
        'header,footer,nav,aside,[class*="header"],[class*="footer"],[class*="navbar"],' +
        '[class*="social"],[class*="telegram"],[class*="banner"],[class*="ads"],' +
        '[class*="recargar"],[class*="reload"]{display:none!important}' +
        'video{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:9999!important;object-fit:contain!important}' +
        'iframe{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:9998!important;border:none!important}' +
        '[class*="player"],[id*="player"],[class*="video-wrap"],[class*="video-container"]{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:9997!important;background:#000!important}';
      document.head.appendChild(css);

      function tryPlay() {
        // 1. Videos directos
        document.querySelectorAll('video').forEach(function(v) {
          if (v.paused) {
            v.muted = false;
            v.play().catch(function() { v.muted = true; v.play().catch(function(){}); });
          }
        });
        // 2. Botones de play conocidos (JWPlayer, VideoJS, Flowplayer, genéricos)
        var selectors = [
          '.jw-icon-display','.jw-display-icon-container',
          '.vjs-big-play-button','.vjs-play-control',
          '.fp-play','.fp-ui [class*="play"]',
          'button[class*="play"]','[aria-label*="play" i]','[aria-label*="Play" i]',
          '[class*="play-btn"]','[class*="playBtn"]','[class*="playButton"]',
          '[class*="play-button"]','[id*="play-btn"]','[id*="playBtn"]',
          '.ytp-large-play-button','.plyr__control--overlaid',
          '[data-plyr="play"]','[class*="bigplay"]','[class*="big-play"]'
        ];
        for (var i = 0; i < selectors.length; i++) {
          var el = document.querySelector(selectors[i]);
          if (el) { try { el.click(); break; } catch(e){} }
        }
        // 3. postMessage para iframes cross-origin
        document.querySelectorAll('iframe').forEach(function(f) {
          try {
            f.contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}','*');
            f.contentWindow.postMessage(JSON.stringify({method:'play'}),'*');
          } catch(e) {}
        });
      }

      setTimeout(tryPlay, 500);
      setTimeout(tryPlay, 1500);
      setTimeout(tryPlay, 3000);
      setTimeout(tryPlay, 5000);
      // Seguir intentando cada 8 segundos por si el player carga tarde
      setInterval(function() {
        var playing = Array.from(document.querySelectorAll('video')).some(function(v){ return !v.paused; });
        if (!playing) tryPlay();
      }, 8000);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
    _initWebView();
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _initWebView() {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_ua)
      ..setBackgroundColor(Colors.black);

    if (ctrl.platform is AndroidWebViewController) {
      (ctrl.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    ctrl
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) { if (mounted) setState(() => _loading = true); },
        onPageFinished: (_) {
          ctrl.runJavaScript(_autoPlayJs).catchError((_) {});
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) { if (mounted) setState(() => _loading = false); },
        onNavigationRequest: (req) {
          final u = req.url.toLowerCase();
          if (req.isMainFrame &&
              (u.contains('doubleclick.net') ||
               u.contains('googlesyndication.com') ||
               u.contains('adservice.google'))) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));

    setState(() => _ctrl = ctrl);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 225,
      color: Colors.black,
      child: Stack(children: [

        // ── WebView ───────────────────────────────────────────
        if (_ctrl != null)
          WebViewWidget(controller: _ctrl!),

        // ── Spinner ───────────────────────────────────────────
        if (_loading)
          const Center(child: CircularProgressIndicator(
              color: Color(0xFFE50914), strokeWidth: 2)),

        // ── Barra inferior ────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('EN VIVO',
                    style: TextStyle(color: Colors.white,
                        fontSize: 8, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: widget.onFullscreen,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.fullscreen_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
