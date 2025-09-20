import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final double rating;
  final int maxRating;
  final double size;
  final Color filledColor;
  final Color unfilledColor;
  final bool showRatingText;
  final int? totalReviews;
  final Function(int)? onRatingChanged;
  final bool isInteractive;

  const StarRatingWidget({
    Key? key,
    required this.rating,
    this.maxRating = 3,
    this.size = 16,
    this.filledColor = const Color(0xFFE46A14),
    this.unfilledColor = Colors.grey,
    this.showRatingText = true,
    this.totalReviews,
    this.onRatingChanged,
    this.isInteractive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(maxRating, (index) {
            return GestureDetector(
              onTap: isInteractive && onRatingChanged != null
                  ? () => onRatingChanged!(index + 1)
                  : null,
              child: Icon(
                index < rating.floor()
                    ? Icons.star
                    : (index < rating && rating % 1 != 0)
                        ? Icons.star_half
                        : Icons.star_border,
                color: index < rating ? filledColor : unfilledColor,
                size: size,
              ),
            );
          }),
        ),
        if (showRatingText) ...[
          const SizedBox(width: 4),
          Text(
            totalReviews != null
                ? '${rating.toStringAsFixed(1)} (${totalReviews})'
                : rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white70,
              fontSize: size * 0.75,
            ),
          ),
        ],
      ],
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  final int initialRating;
  final int maxRating;
  final double size;
  final Color filledColor;
  final Color unfilledColor;
  final Function(int) onRatingChanged;

  const InteractiveStarRating({
    Key? key,
    required this.onRatingChanged,
    this.initialRating = 0,
    this.maxRating = 3,
    this.size = 24,
    this.filledColor = const Color(0xFFE46A14),
    this.unfilledColor = Colors.grey,
  }) : super(key: key);

  @override
  _InteractiveStarRatingState createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.maxRating, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentRating = index + 1;
            });
            widget.onRatingChanged(_currentRating);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              index < _currentRating ? Icons.star : Icons.star_border,
              color: index < _currentRating ? widget.filledColor : widget.unfilledColor,
              size: widget.size,
            ),
          ),
        );
      }),
    );
  }
}
