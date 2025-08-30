import 'package:flutter/material.dart';

class ReviewDialog extends StatefulWidget {
  final String initialComment;
  final bool showDeleteButton;

  const ReviewDialog({
    Key? key,
    this.initialComment = '',
    this.showDeleteButton = false, // default is false
  }) : super(key: key);

  @override
  _ReviewDialogState createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late TextEditingController _controller;
  String? _errorMessage; // For displaying any validation errors

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onOkPressed() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Review cannot be empty.';
      });
      return;
    }
    Navigator.pop(context, text);
  }

  void _onCancelPressed() {
    Navigator.pop(context, null);
  }

  void _onDeletePressed() {
    // Return a special string so the parent knows this was a delete action
    Navigator.pop(context, '__DELETE_REVIEW__');
  }

  // Handle return key press - add new line instead of closing dialog
  void _handleReturnKey() {
    // Insert a new line at cursor position
    final currentText = _controller.text;
    final selection = _controller.selection;
    if (selection.isValid) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        '\n',
      );
      _controller.text = newText;
      // Move cursor to end of new line
      _controller.selection = TextSelection.collapsed(
        offset: selection.start + 1,
      );
    }
  }

  // Clear error message when user starts typing
  void _onTextChanged(String value) {
    if (_errorMessage != null && value.trim().isNotEmpty) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      // Make dialog resize when keyboard appears
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: Color(0xFFC0C0C0),
          border: Border.all(color: Colors.black),
          boxShadow: [
            BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 0),
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              color: Colors.deepOrange,
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Write/Edit Review',
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
            // Content - wrapped in SingleChildScrollView for keyboard handling
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your Review:',
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        color: Color(0xFFF4F4F4),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: 5,
                        style: TextStyle(color: Colors.black),
                        // Handle return key properly
                        textInputAction: TextInputAction.newline,
                        // Handle return key to add new lines
                        onEditingComplete: _handleReturnKey,
                        // Don't close dialog on return key
                        onSubmitted: (value) {
                          // Do nothing - keep dialog open
                        },
                        // Clear error message when user types
                        onChanged: _onTextChanged,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(8.0),
                          // Add hint text
                          hintText: 'Write your review here...',
                          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    ),
                    // Display error message if any
                    if (_errorMessage != null) ...[
                      SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    SizedBox(height: 16),
                    // Buttons row - moved to bottom for better keyboard handling
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Conditionally show "Delete" if user already has a review
                        if (widget.showDeleteButton) ...[
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.all(Color(0xFFD24407)),
                              elevation: MaterialStateProperty.all(0),
                              side: MaterialStateProperty.all(
                                  BorderSide(color: Colors.black, width: 2)),
                            ),
                            onPressed: _onDeletePressed,
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                        ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Color(0xFFD24407)),
                            elevation: MaterialStateProperty.all(0),
                            side: MaterialStateProperty.all(
                                BorderSide(color: Colors.black, width: 2)),
                          ),
                          onPressed: _onOkPressed,
                          child: Text('OK', style: TextStyle(color: Colors.white)),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Color(0xFFD24407)),
                            elevation: MaterialStateProperty.all(0),
                            side: MaterialStateProperty.all(
                                BorderSide(color: Colors.black, width: 2)),
                          ),
                          onPressed: _onCancelPressed,
                          child:
                              Text('Cancel', style: TextStyle(color: Colors.white)),
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
  }
}
