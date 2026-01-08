// Jest setup file for Firebase Functions tests
// This runs before each test file

// Increase timeout for Firebase operations
jest.setTimeout(30000);

// Suppress console logs during tests (optional - comment out for debugging)
// global.console = {
//   ...console,
//   log: jest.fn(),
//   debug: jest.fn(),
//   info: jest.fn(),
//   warn: jest.fn(),
// };

// Clean up any pending handles after tests
afterAll(async () => {
  // Give Firebase time to clean up connections
  await new Promise(resolve => setTimeout(resolve, 1000));
});
