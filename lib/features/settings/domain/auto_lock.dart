enum AutoLockDelay {
  immediately(Duration.zero, 'Immediately'),
  seconds30(Duration(seconds: 30), 'After 30 seconds'),
  minute1(Duration(minutes: 1), 'After 1 minute'),
  minutes5(Duration(minutes: 5), 'After 5 minutes');

  const AutoLockDelay(this.duration, this.label);

  final Duration duration;
  final String label;
}
