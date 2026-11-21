enum ProbeMethod(final String label) {
  head('HEAD'),
  get('GET');

  // Built once: the segmented button wants a Set, and `values` never changes.
  static final all = values.toSet();
}
