/// Structured data contracts and serializers for specialized feedback categories.
///
/// Converts rich diagnostic and ideation fields into human-readable,
/// formatted narrative blocks compatible with the existing `FeedbackModel.message`
/// 5,000-character constraint.
library;

class BugReportPayload {
  final String module;
  final String title;
  final String description;
  final String stepsToReproduce;
  final String expectedBehavior;
  final String actualBehavior;
  final String? contactEmail;

  const BugReportPayload({
    required this.module,
    required this.title,
    required this.description,
    required this.stepsToReproduce,
    required this.expectedBehavior,
    required this.actualBehavior,
    this.contactEmail,
  });

  /// Serializes structured bug fields into a clean diagnostic narrative block.
  String toSerializedMessage() {
    final buffer = StringBuffer();

    buffer.writeln('[ISSUE TITLE]');
    buffer.writeln(title.trim());
    buffer.writeln();

    buffer.writeln('[PROBLEM DESCRIPTION]');
    buffer.writeln(description.trim());
    buffer.writeln();

    buffer.writeln('[STEPS TO REPRODUCE]');
    buffer.writeln(stepsToReproduce.trim());
    buffer.writeln();

    buffer.writeln('[EXPECTED BEHAVIOR]');
    buffer.writeln(expectedBehavior.trim());
    buffer.writeln();

    buffer.writeln('[ACTUAL BEHAVIOR]');
    buffer.writeln(actualBehavior.trim());

    return buffer.toString().trim();
  }

  /// Maps structured fields into draft storage payload.
  Map<String, dynamic> toDraftMap() {
    return {
      'title': title,
      'description': description,
      'stepsToReproduce': stepsToReproduce,
      'expectedBehavior': expectedBehavior,
      'actualBehavior': actualBehavior,
    };
  }

  /// Reconstructs payload from SharedPreferences draft map.
  static BugReportPayload fromDraft(Map<String, dynamic> data) {
    final extra = data['extraFields'] as Map<String, dynamic>?;
    return BugReportPayload(
      module: (data['module'] as String?) ?? 'general',
      title: (extra?['title'] as String?) ?? '',
      description: (extra?['description'] as String?) ?? (data['message'] as String? ?? ''),
      stepsToReproduce: (extra?['stepsToReproduce'] as String?) ?? '',
      expectedBehavior: (extra?['expectedBehavior'] as String?) ?? '',
      actualBehavior: (extra?['actualBehavior'] as String?) ?? '',
      contactEmail: data['contactEmail'] as String?,
    );
  }

  /// Validates all required fields. Returns null if valid, or a descriptive error.
  String? validate() {
    if (title.trim().isEmpty) {
      return 'Please provide a short issue title.';
    }
    if (title.trim().length > 150) {
      return 'Issue title must be 150 characters or less.';
    }
    if (description.trim().length < 10) {
      return 'Please provide at least 10 characters describing the problem.';
    }
    if (stepsToReproduce.trim().isEmpty) {
      return 'Please provide steps to reproduce the issue.';
    }
    if (expectedBehavior.trim().isEmpty) {
      return 'Please describe what you expected to happen.';
    }
    if (actualBehavior.trim().isEmpty) {
      return 'Please describe what actually happened.';
    }
    final serialized = toSerializedMessage();
    if (serialized.length > 5000) {
      return 'Complete bug report exceeds 5,000 characters limit. Please shorten details.';
    }
    return null;
  }
}

class FeatureRequestPayload {
  final String module;
  final String title;
  final String description;
  final String? benefit;
  final String? contactEmail;

  const FeatureRequestPayload({
    required this.module,
    required this.title,
    required this.description,
    this.benefit,
    this.contactEmail,
  });

  /// Serializes structured idea fields into a creative vision narrative block.
  String toSerializedMessage() {
    final buffer = StringBuffer();

    buffer.writeln('[FEATURE TITLE]');
    buffer.writeln(title.trim());
    buffer.writeln();

    buffer.writeln('[IDEA DESCRIPTION]');
    buffer.writeln(description.trim());

    if (benefit != null && benefit!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('[VALUE & BENEFIT]');
      buffer.writeln(benefit!.trim());
    }

    return buffer.toString().trim();
  }

  /// Maps structured fields into draft storage payload.
  Map<String, dynamic> toDraftMap() {
    return {
      'title': title,
      'description': description,
      'benefit': benefit,
    };
  }

  /// Reconstructs payload from SharedPreferences draft map.
  static FeatureRequestPayload fromDraft(Map<String, dynamic> data) {
    final extra = data['extraFields'] as Map<String, dynamic>?;
    return FeatureRequestPayload(
      module: (data['module'] as String?) ?? 'general',
      title: (extra?['title'] as String?) ?? '',
      description: (extra?['description'] as String?) ?? (data['message'] as String? ?? ''),
      benefit: extra?['benefit'] as String?,
      contactEmail: data['contactEmail'] as String?,
    );
  }

  /// Validates all required fields. Returns null if valid, or a descriptive error.
  String? validate() {
    if (title.trim().isEmpty) {
      return 'Please give your idea a title.';
    }
    if (title.trim().length > 120) {
      return 'Feature title must be 120 characters or less.';
    }
    if (description.trim().length < 10) {
      return 'Please provide at least 10 characters describing your idea.';
    }
    final serialized = toSerializedMessage();
    if (serialized.length > 5000) {
      return 'Complete suggestion exceeds 5,000 characters limit. Please shorten description.';
    }
    return null;
  }
}

/// Payload and serializer for General Conversational Feedback.
class GeneralFeedbackPayload {
  final String module;
  final String message;
  final String? selectedPrompt;
  final String? contactEmail;

  const GeneralFeedbackPayload({
    required this.module,
    required this.message,
    this.selectedPrompt,
    this.contactEmail,
  });

  /// Serializes conversational feedback into a readable narrative block.
  String toSerializedMessage() {
    final buffer = StringBuffer();

    if (selectedPrompt != null && selectedPrompt!.trim().isNotEmpty) {
      buffer.writeln('[TOPIC: ${selectedPrompt!.trim()}]');
      buffer.writeln();
    }

    buffer.writeln('[FEEDBACK]');
    buffer.writeln(message.trim());

    return buffer.toString().trim();
  }

  /// Maps structured fields into draft storage payload.
  Map<String, dynamic> toDraftMap() {
    return {
      'message': message,
      'selectedPrompt': selectedPrompt,
    };
  }

  /// Reconstructs payload from SharedPreferences draft map.
  static GeneralFeedbackPayload fromDraft(Map<String, dynamic> data) {
    final extra = data['extraFields'] as Map<String, dynamic>?;
    return GeneralFeedbackPayload(
      module: (data['module'] as String?) ?? 'general',
      message: (extra?['message'] as String?) ?? (data['message'] as String? ?? ''),
      selectedPrompt: extra?['selectedPrompt'] as String?,
      contactEmail: data['contactEmail'] as String?,
    );
  }

  /// Validates all required fields. Returns null if valid, or a descriptive error.
  String? validate() {
    if (message.trim().isEmpty) {
      return 'Please enter your thoughts before submitting.';
    }
    if (message.trim().length < 5) {
      return 'Please share at least a few words (minimum 5 characters).';
    }
    final serialized = toSerializedMessage();
    if (serialized.length > 5000) {
      return 'Feedback message exceeds the 5,000 character limit. Please shorten your message.';
    }
    return null;
  }
}

/// Payload and serializer for Rating submissions.
class RateArcPayload {
  final int rating;
  final String? writtenReview;
  final String module;
  final String? contactEmail;

  const RateArcPayload({
    required this.rating,
    this.writtenReview,
    this.module = 'general',
    this.contactEmail,
  });

  /// Returns contextual human-readable label for a star rating (1–5).
  static String getRatingLabel(int stars) {
    switch (stars) {
      case 1:
        return 'Poor — Needs major work';
      case 2:
        return 'Fair — Missing key features';
      case 3:
        return 'Good — Does the job';
      case 4:
        return 'Great — Very satisfied';
      case 5:
        return 'Loved it — Arc is indispensable!';
      default:
        return 'Unrated';
    }
  }

  /// Serializes rating and optional review into a clean narrative block.
  String toSerializedMessage() {
    final buffer = StringBuffer();
    buffer.writeln('[APP RATING]');
    buffer.writeln('$rating / 5 Stars (${getRatingLabel(rating)})');
    buffer.writeln();

    buffer.writeln('[WRITTEN REVIEW]');
    if (writtenReview != null && writtenReview!.trim().isNotEmpty) {
      buffer.writeln(writtenReview!.trim());
    } else {
      buffer.writeln('(No written review provided)');
    }

    return buffer.toString().trim();
  }

  /// Maps structured fields into draft storage payload.
  Map<String, dynamic> toDraftMap() {
    return {
      'rating': rating,
      'writtenReview': writtenReview,
    };
  }

  /// Reconstructs payload from SharedPreferences draft map.
  static RateArcPayload fromDraft(Map<String, dynamic> data) {
    final extra = data['extraFields'] as Map<String, dynamic>?;
    return RateArcPayload(
      rating: (extra?['rating'] as num?)?.toInt() ?? (data['rating'] as num?)?.toInt() ?? 0,
      writtenReview: (extra?['writtenReview'] as String?) ?? (data['message'] as String?),
      module: (data['module'] as String?) ?? 'general',
      contactEmail: data['contactEmail'] as String?,
    );
  }

  /// Validates all required fields. Returns null if valid, or a descriptive error.
  String? validate() {
    if (rating < 1 || rating > 5) {
      return 'Please tap a star to choose a rating between 1 and 5.';
    }
    if (writtenReview != null && writtenReview!.trim().length > 4500) {
      return 'Review comment exceeds character limit. Please shorten your review.';
    }
    final serialized = toSerializedMessage();
    if (serialized.length > 5000) {
      return 'Rating submission exceeds 5,000 characters limit.';
    }
    return null;
  }
}
