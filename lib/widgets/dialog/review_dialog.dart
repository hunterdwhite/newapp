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

  // Static method to show the dialog properly
  static Future<String?> show(
    BuildContext context, {
    String initialComment = '',
    bool showDeleteButton = false,
  }) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) => ReviewDialog(
          initialComment: initialComment,
          showDeleteButton: showDeleteButton,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _ReviewDialogState extends State<ReviewDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String? _errorMessage; // For displaying any validation errors

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComment);
    _focusNode = FocusNode();
    
    // Auto-focus the text field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent dialog from closing when tapping inside
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: 300, // Fixed reasonable height
                margin: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFC0C0C0),
                  border: Border.all(color: Colors.black),
                  boxShadow: [
                    BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 0),
                    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Column(
                  children: [
                    // Title bar with save button
                    Container(
                      color: Colors.deepOrange,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Write/Edit Review',
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 12, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Delete button (if needed)
                          if (widget.showDeleteButton) ...[
                            GestureDetector(
                              onTap: _onDeletePressed,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          // Save button
                          GestureDetector(
                            onTap: _onOkPressed,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Close button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Your Review:',
                              style: TextStyle(
                                color: Colors.black, 
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  color: Colors.white,
                                ),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  maxLines: null,
                                  expands: true,
                                  style: TextStyle(color: Colors.black, fontSize: 14),
                                  textInputAction: TextInputAction.newline,
                                  onEditingComplete: _handleReturnKey,
                                  onChanged: _onTextChanged,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12.0),
                                    hintText: 'Write your review here...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade600, 
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700, 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}