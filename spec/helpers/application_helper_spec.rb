require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#format_created_date' do
    context 'when datetime is present' do
      it 'returns formatted date string in YYYY-MM-DD format' do
        datetime = DateTime.new(2023, 12, 25, 14, 30, 0)
        result = helper.format_created_date(datetime)

        expect(result).to eq('2023-12-25')
      end

      it 'formats Time objects correctly' do
        time = Time.new(2024, 1, 1, 9, 15, 30)
        result = helper.format_created_date(time)

        expect(result).to eq('2024-01-01')
      end

      it 'formats Date objects correctly' do
        date = Date.new(2024, 6, 15)
        result = helper.format_created_date(date)

        expect(result).to eq('2024-06-15')
      end
    end

    context 'when datetime is nil' do
      it 'returns nil' do
        result = helper.format_created_date(nil)

        expect(result).to be_nil
      end
    end

    context 'when datetime is blank' do
      it 'returns nil for empty string' do
        result = helper.format_created_date('')

        expect(result).to be_nil
      end

      it 'returns nil for blank string' do
        result = helper.format_created_date('   ')

        expect(result).to be_nil
      end
    end

    context 'edge cases' do
      it 'handles leap year dates correctly' do
        datetime = DateTime.new(2024, 2, 29, 12, 0, 0)
        result = helper.format_created_date(datetime)

        expect(result).to eq('2024-02-29')
      end

      it 'handles single digit months and days with zero padding' do
        datetime = DateTime.new(2024, 3, 5, 8, 45, 0)
        result = helper.format_created_date(datetime)

        expect(result).to eq('2024-03-05')
      end
    end
  end

  describe '#format_count' do
    context 'when count is less than 1000' do
      it 'formats small numbers with delimiters' do
        expect(helper.format_count(123)).to eq('123')
      end

      it 'formats hundreds with delimiters' do
        expect(helper.format_count(567)).to eq('567')
      end

      it 'formats numbers close to 1000 with delimiters' do
        expect(helper.format_count(999)).to eq('999')
      end

      it 'handles zero' do
        expect(helper.format_count(0)).to eq('0')
      end

      it 'formats numbers with commas when needed' do
        expect(helper.format_count(1234)).to eq('1.2k')
      end
    end

    context 'when count is 1000 or more' do
      it 'formats thousands with one decimal place' do
        expect(helper.format_count(1000)).to eq('1.0k')
      end

      it 'formats thousands with decimal precision' do
        expect(helper.format_count(1200)).to eq('1.2k')
      end

      it 'formats thousands with rounding' do
        expect(helper.format_count(1567)).to eq('1.6k')
      end

      it 'formats large thousands' do
        expect(helper.format_count(45000)).to eq('45.0k')
      end

      it 'formats numbers close to millions' do
        expect(helper.format_count(999999)).to eq('1000.0k')
      end
    end

    context 'when count is 1 million or more' do
      it 'formats millions with one decimal place' do
        expect(helper.format_count(1000000)).to eq('1.0M')
      end

      it 'formats millions with decimal precision' do
        expect(helper.format_count(1250000)).to eq('1.3M')
      end

      it 'formats large millions' do
        expect(helper.format_count(12500000)).to eq('12.5M')
      end
    end

    context 'when count is 1 billion or more' do
      it 'formats billions with one decimal place' do
        expect(helper.format_count(1000000000)).to eq('1.0B')
      end

      it 'formats billions with decimal precision' do
        expect(helper.format_count(2500000000)).to eq('2.5B')
      end
    end

    context 'edge cases' do
      it 'handles exactly 1000' do
        expect(helper.format_count(1000)).to eq('1.0k')
      end

      it 'handles exactly 1000000' do
        expect(helper.format_count(1000000)).to eq('1.0M')
      end

      it 'handles exactly 1000000000' do
        expect(helper.format_count(1000000000)).to eq('1.0B')
      end
    end
  end

  describe '#formatted_scope_count' do
    it 'returns HTML-safe string with scopes-count class and title for small numbers' do
      result = helper.formatted_scope_count(123)

      expect(result).to eq('<span class="scopes-count" title="123">123</span>')
      expect(result).to be_html_safe
    end

    it 'returns HTML-safe string with scopes-count class and original number in title for thousands' do
      result = helper.formatted_scope_count(1200)

      expect(result).to eq('<span class="scopes-count" title="1,200">1.2k</span>')
      expect(result).to be_html_safe
    end

    it 'returns HTML-safe string with scopes-count class and original number in title for millions' do
      result = helper.formatted_scope_count(1500000)

      expect(result).to eq('<span class="scopes-count" title="1,500,000">1.5M</span>')
      expect(result).to be_html_safe
    end

    it 'returns HTML-safe string with scopes-count class and original number in title for billions' do
      result = helper.formatted_scope_count(2500000000)

      expect(result).to eq('<span class="scopes-count" title="2,500,000,000">2.5B</span>')
      expect(result).to be_html_safe
    end

    it 'handles zero count with title' do
      result = helper.formatted_scope_count(0)

      expect(result).to eq('<span class="scopes-count" title="0">0</span>')
      expect(result).to be_html_safe
    end

    it 'shows exact number in title for large numbers with commas' do
      result = helper.formatted_scope_count(1234567)

      expect(result).to eq('<span class="scopes-count" title="1,234,567">1.2M</span>')
      expect(result).to be_html_safe
    end
  end

  describe '#scope_with_formatted_count' do
    it 'returns HTML-safe string with label, formatted count and title for small numbers' do
      result = helper.scope_with_formatted_count('All', 123)

      expect(result).to eq('All <span class="scopes-count" title="123">123</span>')
      expect(result).to be_html_safe
    end

    it 'returns HTML-safe string with label, formatted count and original number in title for thousands' do
      result = helper.scope_with_formatted_count('Running', 1200)

      expect(result).to eq('Running <span class="scopes-count" title="1,200">1.2k</span>')
      expect(result).to be_html_safe
    end

    it 'returns HTML-safe string with label, formatted count and original number in title for millions' do
      result = helper.scope_with_formatted_count('Completed', 1500000)

      expect(result).to eq('Completed <span class="scopes-count" title="1,500,000">1.5M</span>')
      expect(result).to be_html_safe
    end

    it 'handles different label types with title' do
      result = helper.scope_with_formatted_count('Failed', 567)

      expect(result).to eq('Failed <span class="scopes-count" title="567">567</span>')
      expect(result).to be_html_safe
    end

    it 'handles empty label with title' do
      result = helper.scope_with_formatted_count('', 1000)

      expect(result).to eq(' <span class="scopes-count" title="1,000">1.0k</span>')
      expect(result).to be_html_safe
    end

    it 'handles zero count with label and title' do
      result = helper.scope_with_formatted_count('None', 0)

      expect(result).to eq('None <span class="scopes-count" title="0">0</span>')
      expect(result).to be_html_safe
    end

    it 'shows exact number with commas in title for large numbers' do
      result = helper.scope_with_formatted_count('All', 1234567)

      expect(result).to eq('All <span class="scopes-count" title="1,234,567">1.2M</span>')
      expect(result).to be_html_safe
    end
  end
end
