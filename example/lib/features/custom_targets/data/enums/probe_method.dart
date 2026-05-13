enum ProbeMethod {
  head('HEAD'),
  get('GET');

  final String label;

  const ProbeMethod(this.label);
}
