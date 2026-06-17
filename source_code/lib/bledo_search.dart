import 'package:flutter/material.dart';

class BledoSearchEngine extends StatefulWidget {
  final String initialQuery;
  const BledoSearchEngine({super.key, this.initialQuery = ""});

  @override
  _BledoSearchEngineState createState() => _BledoSearchEngineState();
}

class _BledoSearchEngineState extends State<BledoSearchEngine> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      _hasSearched = true;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.8, -0.6),
              radius: 1.2,
              colors: [Color(0xFF0A192F), Color(0xFF080808)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _hasSearched ? _buildSearchResults() : _buildHomeView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: _hasSearched ? 40 : 80,
            child: const Text(
              "Bledo",
              style: TextStyle(
                color: Color(0xFF00BFFF),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.blueAccent, blurRadius: 10)],
              ),
            ),
          ),
          const SizedBox(width: 20),
          if (_hasSearched)
            Expanded(
              child: _buildSearchBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "EXPLORE THE VOID",
            style: TextStyle(color: Colors.white54, letterSpacing: 5, fontSize: 12),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _buildSearchBar(),
          ),
          const SizedBox(height: 50),
          _buildQuickLinks(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search without traces...",
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF00BFFF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onSubmitted: (val) {
          setState(() {
            _hasSearched = true;
          });
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 10,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 400 + (index * 100)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Result #$index for '${_searchController.text}'",
                  style: const TextStyle(color: Color(0xFF00BFFF), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  "https://Bledo-secure-result.io/data-point-xyz",
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
                const SizedBox(height: 10),
                const Text(
                  "This is a sample encrypted search result from the Bledo Privacy Engine. All trackers have been stripped and metadata has been neutralized.",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickLinks() {
    final links = [Icons.shield, Icons.vpn_lock, Icons.history, Icons.bookmark];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: links.map((icon) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withOpacity(0.1),
        ),
        child: Icon(icon, color: Colors.blueAccent, size: 24),
      )).toList(),
    );
  }
}
