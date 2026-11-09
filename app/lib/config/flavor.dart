enum Flavor { mock, real }

const _f = String.fromEnvironment('FLAVOR', defaultValue: 'mock');
final Flavor currentFlavor = _f == 'real' ? Flavor.real : Flavor.mock;
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000',
);
