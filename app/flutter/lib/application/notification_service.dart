/// Notification platform (ADR-0013): provider abstraction + the in-app
/// provider. FCM/email/SMS/web-push are future [NotificationChannel]
/// implementations behind the same contract (delivery infrastructure
/// arrives with Firebase; unverifiable until then).
library;

import '../adaptive/model.dart';

enum NotificationKind {
  studyReminder,
  reviewDue,
  examCountdown,
  adaptiveRecommendation,
  importCompleted,
  reviewRequested,
  published,
  announcement,
}

class AppNotification {
  const AppNotification({
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
}

/// Delivery seam — one implementation per transport.
abstract class NotificationChannel {
  String get channelName;
  Future<void> deliver(AppNotification notification);
}

/// In-app channel: notifications land in an inbox the UI can watch.
/// The only channel that needs no external infrastructure.
class InAppNotificationChannel implements NotificationChannel {
  final List<AppNotification> inbox = [];

  @override
  String get channelName => 'in-app';

  @override
  Future<void> deliver(AppNotification notification) async =>
      inbox.add(notification);
}

/// Fans one notification out to every registered channel.
class NotificationService {
  const NotificationService(this.channels);

  final List<NotificationChannel> channels;

  Future<void> notify(AppNotification notification) async {
    for (final channel in channels) {
      await channel.deliver(notification);
    }
  }
}

/// Derives learner-facing notifications from the adaptive engine's
/// outputs — pure function, deterministic, tested.
List<AppNotification> buildStudyNotifications({
  required StudyPlan plan,
  required ReadinessReport readiness,
  required DateTime now,
}) => [
  if (plan.dueReviewCount > 0)
    AppNotification(
      kind: NotificationKind.reviewDue,
      title: 'Reviews due',
      body:
          '${plan.dueReviewCount} concept'
          '${plan.dueReviewCount == 1 ? " is" : "s are"} due for review '
          '(~${plan.estimatedMinutes} min).',
      createdAt: now,
    ),
  if (plan.recommendMockExam)
    AppNotification(
      kind: NotificationKind.adaptiveRecommendation,
      title: 'Ready for a mock exam',
      body:
          'Readiness is at ${(readiness.readiness * 100).round()}% — '
          'a timed mock exam is the best next step.',
      createdAt: now,
    ),
  if (plan.items.isNotEmpty && plan.dueReviewCount == 0)
    AppNotification(
      kind: NotificationKind.studyReminder,
      title: 'Today\'s study plan',
      body:
          '${plan.items.length} topics queued, '
          '~${plan.estimatedMinutes} minutes.',
      createdAt: now,
    ),
];
