import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../services/firestore_service.dart';

class AdminAlbumSelectionScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final Function(String albumId, Map<String, dynamic> albumData) onAlbumSelected;

  const AdminAlbumSelectionScreen({
    Key? key,
    required this.orderId,
    required this.orderData,
    required this.onAlbumSelected,
  }) : super(key: key);

  @override
  _AdminAlbumSelectionScreenState createState() => _AdminAlbumSelectionScreenState();
}

class _AdminAlbumSelectionScreenState extends State<AdminAlbumSelectionScreen> {
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
        for (var genre in genres) {
          if (genre.toString().toLowerCase() == _selectedGenre.toLowerCase()) {
            matchesGenre = true;
            break;
          }
        }
      }
      
      // Decade filter
      bool matchesDecade = _selectedDecade == 'All';
      if (!matchesDecade && releaseYear.isNotEmpty) {
        int year = int.tryParse(releaseYear) ?? 0;
        String decade = _getDecadeFromYear(year);
        matchesDecade = decade == _selectedDecade;
      }
      
      return matchesSearch && matchesGenre && matchesDecade;
    }).toList();
  }

  String _getDecadeFromYear(int year) {
    if (year >= 2020) return '2020s';
    if (year >= 2010) return '2010s';
    if (year >= 2000) return '2000s';
    if (year >= 1990) return '1990s';
    if (year >= 1980) return '1980s';
    if (year >= 1970) return '1970s';
    if (year >= 1960) return '1960s';
    if (year >= 1950) return '1950s';
    return 'All';
  }

  void _selectAlbum(DocumentSnapshot inventoryDoc) async {
    final inventoryData = inventoryDoc.data() as Map<String, dynamic>;
    final albumId = inventoryData['albumId'];
    
    if (albumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Album ID not found')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Album Selection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send this album to the customer?'),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: inventoryData['coverUrl'] != null && inventoryData['coverUrl'].isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            inventoryData['coverUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.music_note, size: 30);
                            },
                          ),
                        )
                      : const Icon(Icons.music_note, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inventoryData['albumName'] ?? 'Unknown Album',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(inventoryData['artist'] ?? 'Unknown Artist'),
                      if (inventoryData['releaseYear'] != null)
                        Text(inventoryData['releaseYear'].toString()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send Album'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onAlbumSelected(albumId, inventoryData);
      Navigator.of(context).pop(); // Return to admin dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Album from Inventory'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: GrainyBackgroundWidget(
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by artist or album name...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter Dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGenre,
                          decoration: InputDecoration(
                            labelText: 'Genre',
                            labelStyle: const TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white),
                            ),
                          ),
                          dropdownColor: Colors.black87,
                          style: const TextStyle(color: Colors.white),
                          items: _genres.map((genre) {
                            return DropdownMenuItem(
                              value: genre,
                              child: Text(genre, style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedGenre = value!;
                              _filterAlbums();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDecade,
                          decoration: InputDecoration(
                            labelText: 'Decade',
                            labelStyle: const TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white),
                            ),
                          ),
                          dropdownColor: Colors.black87,
                          style: const TextStyle(color: Colors.white),
                          items: _decades.map((decade) {
                            return DropdownMenuItem(
                              value: decade,
                              child: Text(decade, style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (value) {
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
            ),
            // Results Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredAlbums.length} albums available',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedGenre != 'All' || _selectedDecade != 'All')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _selectedGenre = 'All';
                          _selectedDecade = 'All';
                          _filterAlbums();
                        });
                      },
                      child: const Text('Clear Filters', style: TextStyle(color: Colors.orange)),
                    ),
                ],
              ),
            ),
            // Album Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAlbums.isEmpty
                      ? const Center(
                          child: Text(
                            'No albums found matching your criteria',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredAlbums.length,
                          itemBuilder: (context, index) {
                            final inventoryDoc = _filteredAlbums[index];
                            final inventoryData = inventoryDoc.data() as Map<String, dynamic>;
                            
                            return GestureDetector(
                              onTap: () => _selectAlbum(inventoryDoc),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Album Cover
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                          ),
                                          child: inventoryData['coverUrl'] != null && 
                                                 inventoryData['coverUrl'].isNotEmpty
                                              ? Image.network(
                                                  inventoryData['coverUrl'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[800],
                                                      child: const Icon(
                                                        Icons.music_note,
                                                        color: Colors.white,
                                                        size: 50,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: Colors.grey[800],
                                                  child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white,
                                                    size: 50,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    // Album Info
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inventoryData['albumName'] ?? 'Unknown Album',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              inventoryData['artist'] ?? 'Unknown Artist',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.8),
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                if (inventoryData['releaseYear'] != null)
                                                  Text(
                                                    inventoryData['releaseYear'].toString(),
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.6),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                Text(
                                                  'Qty: ${inventoryData['quantity'] ?? 0}',
                                                  style: TextStyle(
                                                    color: Colors.orange.withOpacity(0.8),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

