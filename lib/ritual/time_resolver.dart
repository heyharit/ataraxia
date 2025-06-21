import '../data/models/moment.dart';

TimeOfDayMoment resolveCurrentMoment() {
  final hour = DateTime.now().hour;

  if (hour >= 5 && hour < 12) {
    return TimeOfDayMoment.morning;
  } else if (hour >= 12 && hour < 18) {
    return TimeOfDayMoment.evening;
  } else {
    return TimeOfDayMoment.night;
  }
}
