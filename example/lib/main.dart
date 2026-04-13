import 'package:flutter/material.dart';
import 'package:page_curl_effect/page_curl_effect.dart';

void main() {
  runApp(const PageCurlExampleApp());
}

/// Example application demonstrating the Page Curl Effect package.
class PageCurlExampleApp extends StatelessWidget {
  const PageCurlExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Curl Effect Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8B4513),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const PageCurlDemo(),
    );
  }
}

/// The main demo screen showing the page curl effect.
class PageCurlDemo extends StatefulWidget {
  const PageCurlDemo({super.key});

  @override
  State<PageCurlDemo> createState() => _PageCurlDemoState();
}

class _PageCurlDemoState extends State<PageCurlDemo>
    with TickerProviderStateMixin {
  late PageCurlController _controller;
  CurlAxis _selectedAxis = CurlAxis.horizontalWithVerticalElasticity;
  int _currentPageIndex = 0;
  bool _isCurlEnabled = true;

  static const _totalPages = 10;

  /// Sample page colours for visual distinction.
  static const _pageColors = [
    Color(0xFFFFF8E1), // Warm white
    Color(0xFFF3E5F5), // Light purple
    Color(0xFFE8F5E9), // Light green
    Color(0xFFE3F2FD), // Light blue
    Color(0xFFFCE4EC), // Light pink
    Color(0xFFFFF3E0), // Light orange
    Color(0xFFE0F7FA), // Light cyan
    Color(0xFFF1F8E9), // Light lime
    Color(0xFFEDE7F6), // Light deep purple
    Color(0xFFFBE9E7), // Light deep orange
  ];

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    // Note: Since PageCurlController extends PageController, we can
    // create one instance and use it for BOTH PageCurlView and PageView.
    _controller = PageCurlController(
      vsync: this,
      config: PageCurlConfig(
        animationDuration: const Duration(milliseconds: 500),
        animationCurve: Curves.easeInOut,
        hotspotRatio: 0.3,
        curlAxis: _selectedAxis,
      ),
      initialPage: _currentPageIndex,
      itemCount: _totalPages,
      onPageChanged: (page) {
        _currentPageIndex = page;
        if (mounted) setState(() {});
      },
    );
  }

  void _onAxisChanged(CurlAxis? newAxis) {
    if (newAxis == null || newAxis == _selectedAxis) return;
    // We recreate the controller only when physics (axis) changes.
    _controller.dispose();
    setState(() {
      _selectedAxis = newAxis;
      _initController();
    });
  }

  void _toggleCurlMode(bool? value) {
    if (value == null) return;
    setState(() {
      _isCurlEnabled = value;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C1810),
      appBar: AppBar(
        title: const Text('Page Curl Effect'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // UI to toggle between Curl and Standard scroll mode
          Row(
            children: [
              const Icon(Icons.auto_stories, size: 20, color: Colors.white70),
              Switch(
                value: _isCurlEnabled,
                onChanged: _toggleCurlMode,
                activeThumbColor: Colors.amber,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<CurlAxis>(
              value: _selectedAxis,
              dropdownColor: const Color(0xFF3E2723),
              underline: const SizedBox(),
              icon: const Icon(Icons.swap_vert, color: Colors.white70),
              style: const TextStyle(fontSize: 14, color: Colors.white),
              items: CurlAxis.values.map((axis) {
                return DropdownMenuItem(
                  value: axis,
                  child: Text(axis.name, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: _onAxisChanged,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _isCurlEnabled ? 'Mode: Realistic Curl' : 'Mode: Standard Scroll',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _isCurlEnabled
                    ? PageCurlView(
                        itemCount: _totalPages,
                        controller: _controller,
                        config: _controller.config,
                        itemBuilder: (context, index) => _buildPage(index),
                      )
                    : PageView.builder(
                        controller: _controller,
                        itemCount: _totalPages,
                        itemBuilder: (context, index) => _buildPage(index),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Page ${_controller.currentPage + 1} / $_totalPages',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _controller.currentPage > 0
                  ? () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _controller.currentPage < _totalPages - 1
                  ? () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single page with sample content.
  Widget _buildPage(int index) {
    final color = _pageColors[index % _pageColors.length];
    return Container(
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Chapter ${index + 1}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.brown.shade800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          Container(width: 120, height: 2, color: Colors.brown.shade300),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _sampleText(index),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.brown.shade700,
                fontFamily: 'serif',
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '— ${index + 1} —',
            style: TextStyle(
              fontSize: 14,
              color: Colors.brown.shade400,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns sample text for each page.
  String _sampleText(int index) {
    const texts = [
      'In the beginning was the Word, and the Word was with the reader, and the Word was the story itself.',
      'The pages turned like leaves in autumn, each one carrying the weight of a thousand untold stories.',
      'Between the lines of text, whole worlds were born — cities of letters, rivers of paragraphs.',
      'She traced her finger along the margin, where the author had left invisible notes of longing.',
      'The book smelled of old libraries and new adventures, a paradox bound in leather and thread.',
      'Chapter by chapter, the reader became the protagonist, walking through doors of imagination.',
      'The ink had dried centuries ago, but the words remained wet with the tears of their creator.',
      'At the edge of every page was a cliff, and turning it was an act of faith and curiosity.',
      'The library was infinite, and every book contained a map to the next unread volume.',
      'And so the story ended, not with a period, but with an ellipsis of endless possibility...',
    ];
    return texts[index % texts.length];
  }
}
