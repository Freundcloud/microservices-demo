/**
 * Copyright 2024 Calitti Ltd.
 *
 * Unit tests for Currency Service
 *
 * Tests currency conversion logic and helper functions
 */

const { describe, it, expect, beforeAll } = require('@jest/globals');

// Helper functions to test (we'll extract them into a testable module)
const CurrencyService = require('../currency-logic');

describe('Currency Service', () => {
  let currencyData;

  beforeAll(() => {
    // Load currency data
    currencyData = require('../data/currency_conversion.json');
  });

  describe('getSupportedCurrencies', () => {
    it('should return all supported currency codes', () => {
      const currencies = CurrencyService.getSupportedCurrencies();
      expect(currencies).toBeDefined();
      expect(Array.isArray(currencies)).toBe(true);
      expect(currencies.length).toBeGreaterThan(0);
    });

    it('should include common currencies (USD, EUR, GBP)', () => {
      const currencies = CurrencyService.getSupportedCurrencies();
      expect(currencies).toContain('USD');
      expect(currencies).toContain('EUR');
      expect(currencies).toContain('GBP');
    });

    it('should include all currencies from currency_conversion.json', () => {
      const currencies = CurrencyService.getSupportedCurrencies();
      const expectedCurrencies = Object.keys(currencyData);
      expect(currencies).toEqual(expectedCurrencies);
    });
  });

  describe('_carry', () => {
    it('should handle basic carrying from nanos to units', () => {
      const result = CurrencyService._carry({
        units: 1,
        nanos: 1500000000 // 1.5 billion nanos = 1.5 units
      });
      expect(result.units).toBe(2);
      expect(result.nanos).toBe(500000000);
    });

    it('should handle fractional units', () => {
      const result = CurrencyService._carry({
        units: 1.5,
        nanos: 0
      });
      expect(result.units).toBe(1);
      expect(result.nanos).toBe(500000000);
    });

    it('should handle zero values', () => {
      const result = CurrencyService._carry({
        units: 0,
        nanos: 0
      });
      expect(result.units).toBe(0);
      expect(result.nanos).toBe(0);
    });

    it('should handle large nanos values', () => {
      const result = CurrencyService._carry({
        units: 5,
        nanos: 2000000000 // 2 billion nanos
      });
      expect(result.units).toBe(7);
      expect(result.nanos).toBe(0);
    });

    it('should handle negative fractional units', () => {
      const result = CurrencyService._carry({
        units: -1.5,
        nanos: 0
      });
      expect(result.units).toBe(-2);
      expect(result.nanos).toBe(500000000);
    });
  });

  describe('convertCurrency', () => {
    it('should convert USD to EUR correctly', () => {
      const from = { units: 100, nanos: 0, currency_code: 'USD' };
      const toCode = 'EUR';
      const result = CurrencyService.convertCurrency(from, toCode);

      expect(result).toBeDefined();
      expect(result.currency_code).toBe('EUR');
      expect(result.units).toBeGreaterThan(0);
      expect(typeof result.nanos).toBe('number');
    });

    it('should convert EUR to USD correctly', () => {
      const from = { units: 100, nanos: 0, currency_code: 'EUR' };
      const toCode = 'USD';
      const result = CurrencyService.convertCurrency(from, toCode);

      expect(result).toBeDefined();
      expect(result.currency_code).toBe('USD');
      expect(result.units).toBeGreaterThan(0);
    });

    it('should convert GBP to JPY correctly', () => {
      const from = { units: 50, nanos: 0, currency_code: 'GBP' };
      const toCode = 'JPY';
      const result = CurrencyService.convertCurrency(from, toCode);

      expect(result).toBeDefined();
      expect(result.currency_code).toBe('JPY');
      expect(result.units).toBeGreaterThan(0);
    });

    it('should handle zero amount conversion', () => {
      const from = { units: 0, nanos: 0, currency_code: 'USD' };
      const toCode = 'EUR';
      const result = CurrencyService.convertCurrency(from, toCode);

      expect(result).toBeDefined();
      expect(result.currency_code).toBe('EUR');
      expect(result.units).toBe(0);
      expect(result.nanos).toBe(0);
    });

    it('should handle fractional amounts with nanos', () => {
      const from = { units: 10, nanos: 500000000, currency_code: 'USD' };
      const toCode = 'EUR';
      const result = CurrencyService.convertCurrency(from, toCode);

      expect(result).toBeDefined();
      expect(result.currency_code).toBe('EUR');
      expect(result.units).toBeGreaterThan(0);
    });

    it('should maintain precision with nanos', () => {
      const from = { units: 1, nanos: 123456789, currency_code: 'USD' };
      const toCode = 'USD'; // Same currency
      const result = CurrencyService.convertCurrency(from, toCode);

      expect(result).toBeDefined();
      expect(result.currency_code).toBe('USD');
      // Should be approximately the same (allowing for rounding)
      const originalValue = from.units + from.nanos / 1000000000;
      const convertedValue = result.units + result.nanos / 1000000000;
      expect(Math.abs(originalValue - convertedValue)).toBeLessThan(0.01);
    });

    it('should throw error for invalid from currency', () => {
      const from = { units: 100, nanos: 0, currency_code: 'INVALID' };
      const toCode = 'USD';

      expect(() => {
        CurrencyService.convertCurrency(from, toCode);
      }).toThrow();
    });

    it('should throw error for invalid to currency', () => {
      const from = { units: 100, nanos: 0, currency_code: 'USD' };
      const toCode = 'INVALID';

      expect(() => {
        CurrencyService.convertCurrency(from, toCode);
      }).toThrow();
    });

    it('should handle conversion through EUR as intermediate', () => {
      // All conversions go through EUR
      const from = { units: 100, nanos: 0, currency_code: 'USD' };
      const toCode = 'GBP';
      const result = CurrencyService.convertCurrency(from, toCode);

      expect(result).toBeDefined();
      expect(result.currency_code).toBe('GBP');
      expect(result.units).toBeGreaterThan(0);
    });
  });

  describe('Currency data validation', () => {
    it('should have EUR in currency data', () => {
      expect(currencyData).toHaveProperty('EUR');
      expect(currencyData.EUR).toBe(1); // EUR is base currency
    });

    it('should have all exchange rates as positive numbers', () => {
      Object.values(currencyData).forEach(rate => {
        expect(typeof rate).toBe('number');
        expect(rate).toBeGreaterThan(0);
      });
    });

    it('should have exchange rate for USD', () => {
      expect(currencyData).toHaveProperty('USD');
      expect(currencyData.USD).toBeGreaterThan(0);
    });

    it('should have at least 30 currencies', () => {
      const currencyCount = Object.keys(currencyData).length;
      expect(currencyCount).toBeGreaterThanOrEqual(30);
    });
  });

  describe('Round-trip conversion', () => {
    it('should maintain value on USD -> EUR -> USD conversion', () => {
      const originalAmount = { units: 100, nanos: 0, currency_code: 'USD' };

      // Convert USD to EUR
      const euros = CurrencyService.convertCurrency(originalAmount, 'EUR');

      // Convert back to USD
      const backToUsd = CurrencyService.convertCurrency(euros, 'USD');

      // Should be approximately the same (allowing for rounding errors)
      expect(Math.abs(backToUsd.units - originalAmount.units)).toBeLessThanOrEqual(1);
    });

    it('should maintain value on GBP -> JPY -> GBP conversion', () => {
      const originalAmount = { units: 50, nanos: 0, currency_code: 'GBP' };

      const yen = CurrencyService.convertCurrency(originalAmount, 'JPY');
      const backToGbp = CurrencyService.convertCurrency(yen, 'GBP');

      // Should be approximately the same (allowing for rounding errors)
      expect(Math.abs(backToGbp.units - originalAmount.units)).toBeLessThanOrEqual(1);
    });
  });
});
