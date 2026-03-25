import 'package:flutter/material.dart';

import '../models/place_prediction.dart';

class SuggestionsList extends StatelessWidget {
  final bool isLoading;
  final List<PlacePrediction> suggestions;
  final ValueChanged<PlacePrediction> onSuggestionTap;

  const SuggestionsList({
    super.key,
    required this.isLoading,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Colors.black12,
          ),
        ],
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : suggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No suggestions found'),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];

                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    suggestion.mainText.isNotEmpty
                        ? suggestion.mainText
                        : suggestion.description,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: suggestion.secondaryText.isNotEmpty
                      ? Text(
                          suggestion.secondaryText,
                          style: const TextStyle(color: Colors.grey),
                        )
                      : null,
                  onTap: () => onSuggestionTap(suggestion),
                );
              },
            ),
    );
  }
}
