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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
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
            // Content
            Padding(
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
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(8.0),
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
                  SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }
}
