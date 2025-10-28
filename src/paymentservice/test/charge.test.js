/**
 * Copyright 2024 Calitti Ltd.
 *
 * Unit tests for Payment Service
 *
 * Tests payment charging logic and credit card validation
 */

const { describe, it, expect, beforeEach } = require('@jest/globals');
const charge = require('../charge');

describe('Payment Service - Charge Function', () => {
  let validVisaRequest;
  let validMastercardRequest;

  beforeEach(() => {
    // Valid VISA card request
    validVisaRequest = {
      amount: {
        currency_code: 'USD',
        units: 100,
        nanos: 500000000
      },
      credit_card: {
        credit_card_number: '4111111111111111', // Valid VISA test card
        credit_card_cvv: 123,
        credit_card_expiration_year: 2030,
        credit_card_expiration_month: 12
      }
    };

    // Valid Mastercard request
    validMastercardRequest = {
      amount: {
        currency_code: 'EUR',
        units: 50,
        nanos: 0
      },
      credit_card: {
        credit_card_number: '5555555555554444', // Valid Mastercard test card
        credit_card_cvv: 456,
        credit_card_expiration_year: 2029,
        credit_card_expiration_month: 6
      }
    };
  });

  describe('Successful charges', () => {
    it('should successfully charge a valid VISA card', () => {
      const result = charge(validVisaRequest);

      expect(result).toBeDefined();
      expect(result.transaction_id).toBeDefined();
      expect(typeof result.transaction_id).toBe('string');
      expect(result.transaction_id.length).toBeGreaterThan(0);
    });

    it('should successfully charge a valid Mastercard', () => {
      const result = charge(validMastercardRequest);

      expect(result).toBeDefined();
      expect(result.transaction_id).toBeDefined();
      expect(typeof result.transaction_id).toBe('string');
    });

    it('should generate unique transaction IDs', () => {
      const result1 = charge(validVisaRequest);
      const result2 = charge(validVisaRequest);

      expect(result1.transaction_id).not.toBe(result2.transaction_id);
    });

    it('should generate UUID format transaction IDs', () => {
      const result = charge(validVisaRequest);
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

      expect(result.transaction_id).toMatch(uuidRegex);
    });

    it('should handle small amounts', () => {
      const request = {
        ...validVisaRequest,
        amount: { currency_code: 'USD', units: 0, nanos: 100000 }
      };

      const result = charge(request);
      expect(result).toBeDefined();
      expect(result.transaction_id).toBeDefined();
    });

    it('should handle large amounts', () => {
      const request = {
        ...validVisaRequest,
        amount: { currency_code: 'USD', units: 999999, nanos: 999999999 }
      };

      const result = charge(request);
      expect(result).toBeDefined();
      expect(result.transaction_id).toBeDefined();
    });
  });

  describe('Invalid credit card validation', () => {
    it('should reject invalid credit card number', () => {
      const invalidRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '1234567890123456' // Invalid card number
        }
      };

      expect(() => charge(invalidRequest)).toThrow('Credit card info is invalid');
    });

    it('should reject credit card with invalid checksum', () => {
      const invalidRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '4111111111111112' // Invalid checksum
        }
      };

      expect(() => charge(invalidRequest)).toThrow('Credit card info is invalid');
    });

    it('should reject empty credit card number', () => {
      const invalidRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: ''
        }
      };

      expect(() => charge(invalidRequest)).toThrow();
    });

    it('should reject credit card with letters', () => {
      const invalidRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '411111111111ABCD'
        }
      };

      expect(() => charge(invalidRequest)).toThrow();
    });
  });

  describe('Card type validation', () => {
    it('should accept VISA cards', () => {
      const result = charge(validVisaRequest);
      expect(result).toBeDefined();
    });

    it('should accept Mastercard cards', () => {
      const result = charge(validMastercardRequest);
      expect(result).toBeDefined();
    });

    it('should reject American Express cards', () => {
      const amexRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '378282246310005' // Valid AMEX test card
        }
      };

      expect(() => charge(amexRequest)).toThrow('Sorry, we cannot process');
      expect(() => charge(amexRequest)).toThrow('Only VISA or MasterCard is accepted');
    });

    it('should reject Discover cards', () => {
      const discoverRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '6011111111111117' // Valid Discover test card
        }
      };

      expect(() => charge(discoverRequest)).toThrow('Only VISA or MasterCard is accepted');
    });
  });

  describe('Expiration date validation', () => {
    it('should reject expired cards (past year)', () => {
      const expiredRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_expiration_year: 2020,
          credit_card_expiration_month: 1
        }
      };

      expect(() => charge(expiredRequest)).toThrow('expired on');
    });

    it('should reject expired cards (past month, current year)', () => {
      const now = new Date();
      const currentYear = now.getFullYear();
      const currentMonth = now.getMonth() + 1;

      // Only run this test if we're not in January (to avoid edge case)
      if (currentMonth > 1) {
        const expiredRequest = {
          ...validVisaRequest,
          credit_card: {
            ...validVisaRequest.credit_card,
            credit_card_expiration_year: currentYear,
            credit_card_expiration_month: currentMonth - 1
          }
        };

        expect(() => charge(expiredRequest)).toThrow('expired on');
      }
    });

    it('should accept cards expiring in current month', () => {
      const now = new Date();
      const currentYear = now.getFullYear();
      const currentMonth = now.getMonth() + 1;

      const currentMonthRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_expiration_year: currentYear,
          credit_card_expiration_month: currentMonth
        }
      };

      const result = charge(currentMonthRequest);
      expect(result).toBeDefined();
    });

    it('should accept cards expiring in future', () => {
      const futureRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_expiration_year: 2099,
          credit_card_expiration_month: 12
        }
      };

      const result = charge(futureRequest);
      expect(result).toBeDefined();
    });

    it('should include card last 4 digits in expiration error', () => {
      const expiredRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '4111111111111111',
          credit_card_expiration_year: 2020,
          credit_card_expiration_month: 1
        }
      };

      try {
        charge(expiredRequest);
        fail('Should have thrown error');
      } catch (error) {
        expect(error.message).toContain('1111'); // Last 4 digits
      }
    });
  });

  describe('Amount validation', () => {
    it('should handle zero units amount', () => {
      const request = {
        ...validVisaRequest,
        amount: { currency_code: 'USD', units: 0, nanos: 500000000 }
      };

      const result = charge(request);
      expect(result).toBeDefined();
    });

    it('should handle zero nanos amount', () => {
      const request = {
        ...validVisaRequest,
        amount: { currency_code: 'USD', units: 100, nanos: 0 }
      };

      const result = charge(request);
      expect(result).toBeDefined();
    });

    it('should handle different currency codes', () => {
      const currencies = ['USD', 'EUR', 'GBP', 'JPY'];

      currencies.forEach(currency => {
        const request = {
          ...validVisaRequest,
          amount: { currency_code: currency, units: 100, nanos: 0 }
        };

        const result = charge(request);
        expect(result).toBeDefined();
      });
    });
  });

  describe('Error handling', () => {
    it('should throw error with status code 400 for invalid card', () => {
      const invalidRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '1234567890123456'
        }
      };

      try {
        charge(invalidRequest);
        fail('Should have thrown error');
      } catch (error) {
        expect(error.code).toBe(400);
      }
    });

    it('should throw error with status code 400 for expired card', () => {
      const expiredRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_expiration_year: 2020,
          credit_card_expiration_month: 1
        }
      };

      try {
        charge(expiredRequest);
        fail('Should have thrown error');
      } catch (error) {
        expect(error.code).toBe(400);
      }
    });

    it('should throw error with status code 400 for unaccepted card type', () => {
      const amexRequest = {
        ...validVisaRequest,
        credit_card: {
          ...validVisaRequest.credit_card,
          credit_card_number: '378282246310005'
        }
      };

      try {
        charge(amexRequest);
        fail('Should have thrown error');
      } catch (error) {
        expect(error.code).toBe(400);
      }
    });
  });
});
