import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../services/firestore_service.dart';
import 'album_confirmation_screen.dart';

class DissonantLibraryScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const DissonantLibraryScreen({
    Key? key,
    required this.orderId,
    required this.orderData,
  }) : super(key: key);

  @override
  _DissonantLibraryScreenState createState() => _DissonantLibraryScreenState();
}

class _DissonantLibraryScreenState extends State<DissonantLibraryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  List<DocumentSnapshot> _allAlbums = [];
  List<DocumentSnapshot> _filteredAlbums = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedGenre = 'All';
  String _selectedDecade = 'All';
  
  final List<String> _genres = [
    'All', 'Rock', 'Pop', 'Hip Hop', 'Electronic', 'Jazz', 'Classical', 
    'Country', 'R&B', 'Reggae', 'Folk', 'Blues', 'Metal', 'Punk', 'Indie'
  ];
  
  final List<String> _decades = [
    'All', '2020s', '2010s', '2000s', '1990s', '1980s', '1970s', '1960s', '1950s'
  ];

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterAlbums();
    });
  }

  Future<void> _loadAlbums() async {
    try {
      _allAlbums = await _firestoreService.getAvailableInventory();
      _filterAlbums();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    }
  }

  void _filterAlbums() {
    _filteredAlbums = _allAlbums.where((inventoryDoc) {
      final inventoryData = inventoryDoc.data() as Map<String, dynamic>;
      final artist = (inventoryData['artist'] ?? '').toString().toLowerCase();
      final albumName = (inventoryData['albumName'] ?? '').toString().toLowerCase();
      final genres = inventoryData['genres'] ?? [];
      final releaseYear = inventoryData['releaseYear'] ?? '';
      
      // Search filter
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        matchesSearch = artist.contains(_searchQuery) || 
                      albumName.contains(_searchQuery);
      }
      
      // Genre filter - check if any genre in the array matches
      bool matchesGenre = _selectedGenre == 'All';
      if (!matchesGenre && genres is List) {
        for (final genre in genres) {
          if (genre.toString().toLowerCase() == _selectedGenre.toLowerCase()) {
            matchesGenre = true;
            break;
          }
        }
      }
      
      // Decade filter - improved logic
      bool matchesDecade = _selectedDecade == 'All';
      if (!matchesDecade && releaseYear != null && releaseYear.toString().isNotEmpty) {
        try {
          final year = int.parse(releaseYear.toString());
          final albumDecade = (year ~/ 10) * 10;
          
          // Convert selected decade (e.g., "2020s") to number (e.g., 2020)
          final selectedDecadeStr = _selectedDecade.replaceAll('s', '');
          final selectedDecadeNum = int.parse(selectedDecadeStr);
          
          matchesDecade = albumDecade == selectedDecadeNum;
        } catch (e) {
          // If year parsing fails, don't filter by decade
          matchesDecade = true;
        }
      }
      
      return matchesSearch && matchesGenre && matchesDecade;
    }).toList();
    
    // Sort by artist name, then album name
    _filteredAlbums.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final artistComparison = (aData['artist'] ?? '').toString().compareTo((bData['artist'] ?? '').toString());
      if (artistComparison != 0) return artistComparison;
      return (aData['albumName'] ?? '').toString().compareTo((bData['albumName'] ?? '').toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dissonant Library'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: GrainyBackgroundWidget(
        child: Column(
          children: [
            _buildSearchAndFilters(),
            _buildResultsHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAlbumsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        border: Border(
          bottom: BorderSide(color: Colors.white, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by artist or album name...',
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white60),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white60),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: const BorderSide(color: Colors.white, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: const BorderSide(color: Colors.white, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: const BorderSide(color: Colors.orangeAccent, width: 1),
              ),
              filled: true,
              fillColor: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Genre',
                  _selectedGenre,
                  _genres,
                  (value) {
                    setState(() {
                      _selectedGenre = value!;
                      _filterAlbums();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterDropdown(
                  'Decade',
                  _selectedDecade,
                  _decades,
                  (value) {
                    setState(() {
                      _selectedDecade = value!;
                      _filterAlbums();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1),
            color: Colors.black,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            isExpanded: true,
            underline: Container(),
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${_filteredAlbums.length} albums found',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (_searchQuery.isNotEmpty || _selectedGenre != 'All' || _selectedDecade != 'All')
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedGenre = 'All';
                  _selectedDecade = 'All';
                  _filterAlbums();
                });
              },
              child: const Text(
                'Clear Filters',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumsList() {
    if (_filteredAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_music,
              size: 64,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            const Text(
              'No albums found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAlbums.length,
      itemBuilder: (context, index) {
        final albumDoc = _filteredAlbums[index];
        final albumData = albumDoc.data() as Map<String, dynamic>;
        
        return _buildAlbumCard(albumDoc.id, albumData);
      },
    );
  }

  Widget _buildAlbumCard(String inventoryId, Map<String, dynamic> inventoryData) {
    final artist = inventoryData['artist'] ?? 'Unknown Artist';
    final albumName = inventoryData['albumName'] ?? 'Unknown Album';
    final releaseYear = inventoryData['releaseYear'] ?? '';
    final genres = inventoryData['genres'] ?? [];
    final genre = genres is List && genres.isNotEmpty ? genres[0].toString() : '';
    final coverUrl = inventoryData['coverUrl'] as String?;
    final albumId = inventoryData['albumId'] ?? inventoryId; // Use albumId from inventory or fallback to inventoryId

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
        child: InkWell(
        onTap: () => _selectAlbum(albumId, inventoryData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Album cover or placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.music_note,
                            color: Colors.white60,
                            size: 30,
                          );
                        },
                      )
                    : const Icon(
                        Icons.music_note,
                        color: Colors.white60,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 16),
              // Album info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      albumName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artist,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (releaseYear.isNotEmpty) ...[
                          _buildInfoChip(releaseYear),
                          const SizedBox(width: 8),
                        ],
                        if (genre.isNotEmpty) ...[
                          _buildInfoChip(genre),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Select button
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.orangeAccent,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.2),
        border: Border.all(color: Colors.orangeAccent, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.orangeAccent,
        ),
      ),
    );
  }

  void _selectAlbum(String albumId, Map<String, dynamic> albumData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumConfirmationScreen(
          orderId: widget.orderId,
          orderData: widget.orderData,
          albumId: albumId,
          albumData: albumData,
        ),
      ),
    );
  }

}
