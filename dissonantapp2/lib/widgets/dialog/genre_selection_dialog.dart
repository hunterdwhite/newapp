// lib/widgets/dialog/genre_selection_dialog.dart

import 'package:flutter/material.dart';

class GenreSelectionDialog extends StatefulWidget {
  final String? currentGenre; // Optional parameter to pre-select genre

  const GenreSelectionDialog({Key? key, this.currentGenre}) : super(key: key);

  @override
  _GenreSelectionDialogState createState() => _GenreSelectionDialogState();
}

class _GenreSelectionDialogState extends State<GenreSelectionDialog> {
  final genres = [
    'Rock',
    'Pop',
    'Jazz',
    'Classical',
    'Hip-hop',
    'Country',
    'Electronic',
    'Metal',
    'Folk',
    'Experimental',
    'Alternative',
    'R&B'
  ];

  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.currentGenre; // Initialize with currentGenre if provided
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Transparent to allow custom styling
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFC0C0C0), // Grey background consistent with Windows95
          border: Border.all(color: Colors.black),
          boxShadow: [
            BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 0),
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Bar
            Container(
              color: Colors.deepOrange, // Title bar color
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.currentGenre != null ? 'Edit Genre' : 'Select a Genre',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.white, size: 12),
                  ),
                ],
              ),
            ),
            // Content Area
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instruction Text
                  Text(
                    widget.currentGenre != null
                        ? 'Change your genre selection:'
                        : 'Pick a genre for this album:',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  SizedBox(height: 8),
                  // Genre Selection List
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      color: Color(0xFFF4F4F4), // Light grey background for list
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: genres.map((genre) {
                          return RadioListTile<String>(
                            title: Text(
                              genre,
                              style: TextStyle(color: Colors.black),
                            ),
                            value: genre,
                            groupValue: _selectedGenre,
                            onChanged: (val) {
                              setState(() {
                                _selectedGenre = val;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // OK Button
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(Color(0xFFD24407)),
                          elevation: MaterialStateProperty.all(0),
                          side: MaterialStateProperty.all(BorderSide(color: Colors.black, width: 2)),
                        ),
                        onPressed: _selectedGenre == null
                            ? null
                            : () {
                                Navigator.pop(context, _selectedGenre);
                              },
                        child: Text(
                          'OK',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Cancel Button
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(Color(0xFFD24407)),
                          elevation: MaterialStateProperty.all(0),
                          side: MaterialStateProperty.all(BorderSide(color: Colors.black, width: 2)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
