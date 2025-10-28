/**
 * Copyright 2024 Calitti Ltd.
 *
 * Currency Service Business Logic
 *
 * Extracted business logic for currency conversion
 * This module is testable without starting the gRPC server
 */

const currencyData = require('./data/currency_conversion.json');

/**
 * Helper function that handles decimal/fractional carrying
 * @param {Object} amount - Amount with units and nanos
 * @returns {Object} Carried amount
 */
function _carry(amount) {
  const fractionSize = Math.pow(10, 9);

  // Extract fractional part and convert to nanos
  // For negative numbers, we need to handle the fractional part specially
  let fractionalPart = amount.units % 1;
  if (fractionalPart < 0) {
    // Convert negative fractional to positive: -1.5 → floor(-1.5) = -2, fractional = 0.5
    fractionalPart += 1;
  }

  amount.nanos += fractionalPart * fractionSize;
  amount.units = Math.floor(amount.units) + Math.floor(amount.nanos / fractionSize);
  amount.nanos = amount.nanos % fractionSize;

  // Handle any remaining negative nanos
  if (amount.nanos < 0) {
    amount.units -= 1;
    amount.nanos += fractionSize;
  }

  return amount;
}

/**
 * Get list of supported currency codes
 * @returns {Array<string>} Array of currency codes
 */
function getSupportedCurrencies() {
  return Object.keys(currencyData);
}

/**
 * Convert currency from one to another
 * @param {Object} from - Source amount {units, nanos, currency_code}
 * @param {string} toCode - Target currency code
 * @returns {Object} Converted amount {units, nanos, currency_code}
 */
function convertCurrency(from, toCode) {
  // Validate currencies exist
  if (!currencyData[from.currency_code]) {
    throw new Error(`Invalid source currency: ${from.currency_code}`);
  }
  if (!currencyData[toCode]) {
    throw new Error(`Invalid target currency: ${toCode}`);
  }

  // Convert: from_currency --> EUR
  const euros = _carry({
    units: from.units / currencyData[from.currency_code],
    nanos: from.nanos / currencyData[from.currency_code]
  });

  euros.nanos = Math.round(euros.nanos);

  // Convert: EUR --> to_currency
  const result = _carry({
    units: euros.units * currencyData[toCode],
    nanos: euros.nanos * currencyData[toCode]
  });

  result.units = Math.floor(result.units);
  result.nanos = Math.floor(result.nanos);
  result.currency_code = toCode;

  return result;
}

module.exports = {
  _carry,
  getSupportedCurrencies,
  convertCurrency
};
