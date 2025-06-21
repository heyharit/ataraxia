// import '../data/models/moment.dart';
// import 'time_resolver.dart';

// final List<Moment> allMoments = [
//   Moment(
//     id: 'morning_1',
//     quote: 'Begin again. But more quietly.',
//     author: null,
//     imageKey: 'wallpapers/morning/morning_1.jpg',
//     time: TimeOfDayMoment.morning,
//   ),
//   Moment(
//     id: 'evening_1',
//     quote: 'What you resist, persists.',
//     author: 'Epictetus',
//     imageKey: 'wallpapers/evening/evening_1.jpg',
//     time: TimeOfDayMoment.evening,
//   ),
//   Moment(
//     id: 'night_1',
//     quote: 'You will leave this world.\nAct accordingly.',
//     author: 'Marcus Aurelius',
//     imageKey: 'wallpapers/night/night_1.jpg',
//     time: TimeOfDayMoment.night,
//   ),
// ];

// Moment selectMoment() {
//   final now = resolveCurrentMoment();
//   return allMoments.firstWhere(
//     (m) => m.time == now,
//     orElse: () => allMoments.first,
//   );
// }

// Moment selectMomentById(String id) {
//   return allMoments.firstWhere((m) => m.id == id, orElse: () => selectMoment());
// }
