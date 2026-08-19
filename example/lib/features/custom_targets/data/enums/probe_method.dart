enum ProbeMethod {
  head('HEAD'),
  get('GET');

  final String label;

  new(this.label);
}
